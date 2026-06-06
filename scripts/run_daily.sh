#!/usr/bin/env bash
# Daily orchestrator: collect → compare → build → analyze → deploy site/
#
# Usage:
#   run_daily.sh                 # full pipeline (steps 1-7)
#   run_daily.sh -p | --publish-only
#                                # skip steps 1-6, only deploy existing site/ to Pages

# Re-exec under bash if invoked via 'sh ...' (dash lacks 'set -o pipefail').
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# ─── Args ────────────────────────────────────────────────────────────────────
PUBLISH_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    -p|--publish-only) PUBLISH_ONLY=1; shift ;;
    -h|--help)
      sed -n '1,8p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Load env vars (DEPLOY_ACCOUNT, DEPLOY_REPO, GIT_USER_NAME, etc.)
if [ -f "${ROOT_DIR}/.env" ]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
fi

VENV="${ROOT_DIR}/.venv"
LOG_DIR="${ROOT_DIR}/logs"
LOG_FILE="${LOG_DIR}/run_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "${LOG_DIR}" site/assets site/analysis

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "========================================"
echo "[run_daily] Start: $(date '+%Y-%m-%d %H:%M:%S %Z')  mode=$([ "${PUBLISH_ONLY}" -eq 1 ] && echo publish-only || echo full)"
echo "========================================"

# ─── venv bootstrap ──────────────────────────────────────────────────────────
# Auto-create venv if missing. systemd runs with empty user-site, so missing
# venv = guaranteed ModuleNotFoundError. Fail hard if bootstrap fails.
_ensure_venv() {
  if [ -f "${VENV}/bin/activate" ]; then
    # shellcheck disable=SC1091
    source "${VENV}/bin/activate"
    return 0
  fi
  echo "[venv] not found at ${VENV} — bootstrapping"
  if ! command -v python3 &>/dev/null; then
    echo "[FATAL] python3 not found"; exit 1
  fi
  python3 -m venv "${VENV}" || { echo "[FATAL] venv create failed"; exit 1; }
  # shellcheck disable=SC1091
  source "${VENV}/bin/activate"
  pip install --upgrade pip -q || true
  if [ -f "${ROOT_DIR}/requirements.txt" ]; then
    pip install -r "${ROOT_DIR}/requirements.txt" -q \
      || { echo "[FATAL] pip install failed"; exit 1; }
  fi
  echo "[venv] ready"
}

# Publish-only mode skips data collection but still needs git push, no python deps required.
if [ "${PUBLISH_ONLY}" -eq 0 ]; then
  _ensure_venv
fi

# Return currently-active gh username from STORED creds (hosts.yml).
# Must NOT use `gh api user` — that uses $GH_TOKEN/$GITHUB_TOKEN env if set,
# which lies about the active stored account. Parse `gh auth status` instead:
# username sits at $(NF-1) on the "Logged in to github.com account NAME (backend)"
# line that precedes "Active account: true". Clear env tokens so gh reads hosts.yml.
_gh_active_user() {
  GH_TOKEN= GITHUB_TOKEN= gh auth status 2>&1 | awk '
    /Logged in to github.com account/ { user = $(NF-1) }
    /Active account: true/             { print user; exit }
  '
}

if [ "${PUBLISH_ONLY}" -eq 1 ]; then
  echo ""
  echo "[publish-only] skipping steps 1-6 (collect/build/analyze); deploying existing site/"
fi

# 1. Pull latest source code from SOURCE_ACCOUNT repo
#    Uses GIT_ASKPASS to inject SOURCE_ACCOUNT token directly — avoids gh credential-helper
#    conflicts when DEPLOY_ACCOUNT is the active gh session.
if [ "${PUBLISH_ONLY}" -eq 0 ]; then
echo ""
echo "[1/7] Pull latest source"

_pull_source() {
  [ -n "${SOURCE_ACCOUNT:-}" ] \
    || { echo "  SOURCE_ACCOUNT not set — skipping pull"; return 0; }
  command -v gh &>/dev/null \
    || { echo "  gh CLI not found — skipping pull"; return 0; }
  git remote get-url origin &>/dev/null 2>&1 \
    || { echo "  No remote origin — skipping pull"; return 0; }

  # Resolve SOURCE_ACCOUNT token. CRITICAL: gh refuses `auth switch` when
  # GH_TOKEN/GITHUB_TOKEN env is set, and `gh auth token` then returns the
  # env-token's value (wrong account). So clear env for every gh call here.
  # We must ACTIVATE SOURCE_ACCOUNT and VERIFY it before grabbing the token —
  # a swallowed switch failure would otherwise hand us the previously-active
  # account's token and 404 on a private SOURCE_ACCOUNT repo ("Repository not found").
  local token active_before active_now
  active_before=$(_gh_active_user)

  # SOURCE_ACCOUNT must be authenticated at all.
  if ! GH_TOKEN= GITHUB_TOKEN= gh auth status 2>&1 | grep -qwF "${SOURCE_ACCOUNT}"; then
    echo "  SOURCE_ACCOUNT (${SOURCE_ACCOUNT}) not authenticated in gh — run: gh auth login (account ${SOURCE_ACCOUNT}). Skipping pull"
    return 0
  fi

  # Make SOURCE_ACCOUNT active (switch + verify) before taking its token.
  if [ "${active_before}" != "${SOURCE_ACCOUNT}" ]; then
    local _switch_err
    echo "  Switching gh ${active_before:-<none>} → ${SOURCE_ACCOUNT}"
    _switch_err=$(GH_TOKEN= GITHUB_TOKEN= gh auth switch -u "${SOURCE_ACCOUNT}" 2>&1) \
      || echo "  gh auth switch stderr: ${_switch_err}"
  fi

  active_now=$(_gh_active_user)
  if [ "${active_now}" != "${SOURCE_ACCOUNT}" ]; then
    echo "  [WARN] could not activate ${SOURCE_ACCOUNT} (still ${active_now:-<none>}) — skipping pull to avoid wrong-account 404"
    return 0
  fi

  token=$(GH_TOKEN= GITHUB_TOKEN= gh auth token 2>/dev/null || true)

  # Restore the account that was active before (token already captured for askpass).
  if [ -n "${active_before}" ] && [ "${active_before}" != "${SOURCE_ACCOUNT}" ]; then
    GH_TOKEN= GITHUB_TOKEN= gh auth switch -u "${active_before}" >/dev/null 2>&1 || true
  fi

  [ -n "${token:-}" ] \
    || { echo "  could not obtain token for ${SOURCE_ACCOUNT} — skipping pull"; return 0; }

  # Inject token via GIT_ASKPASS — credential not stored in URL or git config
  local askpass
  askpass=$(mktemp /tmp/git-askpass-XXXXXX)
  cat > "${askpass}" <<'ASKPASS'
#!/bin/sh
case "$1" in *sername*) printf 'x-access-token' ;; *) printf '%s' "${_GIT_TOKEN}" ;; esac
ASKPASS
  chmod 700 "${askpass}"

  echo "  Pulling origin main as ${SOURCE_ACCOUNT}..."
  _GIT_TOKEN="${token}" GIT_ASKPASS="${askpass}" GIT_TERMINAL_PROMPT=0 \
    git pull --rebase origin main 2>&1 \
    || echo "  git pull failed — continuing with local source"
  rm -f "${askpass}"
}

_pull_source

# Skip data collection (steps 2-5) when data.json was already collected today
# (KST date only — time ignored). Minimizes GitHub API load on same-day reruns,
# e.g. resuming analysis after a usage-limit abort. Step 6 reuses the existing
# data.json + analysis_targets.json.
_data_is_today() {
  local f="${ROOT_DIR}/site/assets/data.json"
  [ -f "${f}" ] || return 1
  python3 - "${f}" <<'PY'
import json, sys
from datetime import datetime, timezone, timedelta
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
iso = (d.get("generated_at_iso") or "")[:10]
ga  = (d.get("generated_at") or "")[:10]
date = iso if (len(iso) == 10 and iso[:4].isdigit()) else ga
today = datetime.now(timezone(timedelta(hours=9))).strftime("%Y-%m-%d")
sys.exit(0 if date == today else 1)
PY
}

SKIP_COLLECT=0
if _data_is_today; then
  SKIP_COLLECT=1
  echo ""
  echo "[2-5/7] data.json already collected today — skipping backup/collect/select/build (reusing existing data + targets)"
fi

if [ "${SKIP_COLLECT}" -eq 0 ]; then
# 2. Backup previous data
echo ""
echo "[2/7] Backup previous data"
if [ -f site/assets/data.json ]; then
  cp site/assets/data.json site/assets/previous_data.json
  echo "  Backed up data.json → previous_data.json"
else
  echo "  No previous data.json found"
fi

# 3. Collect data
echo ""
echo "[3/7] Collect GitHub data"
if command -v gh &>/dev/null; then
  export GITHUB_TOKEN
  GITHUB_TOKEN=$(gh auth token 2>/dev/null || echo "")
fi
python3 scripts/collect_data.py

# 4. Select analysis targets (top5 of top100/daily/weekly/monthly, skip already-analyzed)
echo ""
echo "[4/7] Select analysis targets"
python3 scripts/select_analysis_targets.py

# 5. Build dashboard
echo ""
echo "[5/7] Build static dashboard"
python3 scripts/build_dashboard.py
fi  # end SKIP_COLLECT=0 (steps 2-5)

# 6. Run Claude analysis (non-fatal unless usage limit hit)
echo ""
echo "[6/7] Run Claude analysis"
_CLAUDE_LIMIT_EXIT=42

# Resolve claude binary. systemd's minimal PATH omits npm/nvm/local bin dirs,
# so `command -v claude` fails even when interactive shells find it. Search
# common install locations and prepend the dir to PATH for the child script.
_resolve_claude() {
  if command -v claude &>/dev/null; then return 0; fi
  local c
  shopt -s nullglob
  for c in \
    "${HOME}/.npm-global/bin/claude" \
    "${HOME}/.local/bin/claude" \
    "${HOME}/.local/state/fnm_multishells"/*/bin/claude \
    "${HOME}/.nvm/versions/node"/*/bin/claude \
    "${HOME}/.volta/bin/claude" \
    "${HOME}/.bun/bin/claude" \
    /usr/local/bin/claude \
    /opt/homebrew/bin/claude; do
    if [ -x "${c}" ]; then
      export PATH="$(dirname "${c}"):${PATH}"
      shopt -u nullglob
      return 0
    fi
  done
  shopt -u nullglob
  return 1
}

_LIMIT_HIT=0
if _resolve_claude; then
  _analysis_rc=0
  bash scripts/run_claude_analysis.sh || _analysis_rc=$?
  if [ "${_analysis_rc}" -eq "${_CLAUDE_LIMIT_EXIT}" ]; then
    # Usage limit hit. Do NOT exit yet — any repos already Saved this run are
    # partial-but-valid results. Fall through to rebuild + deploy so they reach
    # DEPLOY_REPO, then exit with the limit code at the end.
    echo "  [FATAL] Claude usage limit reached — deploying partial results then stopping"
    _LIMIT_HIT=1
  elif [ "${_analysis_rc}" -ne 0 ]; then
    echo "  Analysis step failed (non-fatal), continuing"
  fi
  # Rebuild to pick up new analysis links (even if partial)
  python3 scripts/build_dashboard.py
else
  echo "  claude CLI not found, skipping analysis"
fi
fi  # end PUBLISH_ONLY=0 (steps 1-6)

# 7. Deploy site/ to GitHub Pages repo (deploy remote — separate clone)
_publish_to_pages() {
  echo ""
  echo "[7/7] Deploy site/ to GitHub Pages"

  DEPLOY_ACCOUNT="${DEPLOY_ACCOUNT:-}"
  DEPLOY_REPO="${DEPLOY_REPO:-}"

  if [ -z "${DEPLOY_ACCOUNT}" ] || [ -z "${DEPLOY_REPO}" ]; then
    echo "  DEPLOY_ACCOUNT or DEPLOY_REPO not set in .env — skipping deploy"
    return 0
  fi

  if [ ! -d "${ROOT_DIR}/site" ]; then
    echo "  No site/ directory — nothing to publish"
    return 0
  fi

  # ── Resolve DEPLOY_ACCOUNT token (switch + verify, with token fallback) ──
  # CRITICAL: gh refuses to `auth switch` when GH_TOKEN/GITHUB_TOKEN env is set
  # ("cannot switch ... authenticated via env"), and `gh api user` returns the
  # env-token's user instead of stored-active user. Step 3 (collect_data) exports
  # GITHUB_TOKEN, which under systemd persists into step 7 — hence the "switch
  # appeared to succeed but active stayed WisemanLim" symptom. Unset here.
  unset GH_TOKEN GITHUB_TOKEN

  local deploy_token=""
  if command -v gh &>/dev/null; then
    local active_before active_now switch_err
    active_before=$(_gh_active_user)
    echo "  gh active account (before): ${active_before:-<none>}"
    echo "  Required deploy account    : ${DEPLOY_ACCOUNT}"

    if [ "${active_before}" != "${DEPLOY_ACCOUNT}" ]; then
      if gh auth status 2>&1 | grep -qwF "${DEPLOY_ACCOUNT}"; then
        echo "  Switching gh → ${DEPLOY_ACCOUNT}"
        switch_err=$(gh auth switch -u "${DEPLOY_ACCOUNT}" 2>&1) \
          || echo "  gh auth switch stderr: ${switch_err}"
      else
        echo "  [FATAL] ${DEPLOY_ACCOUNT} not authenticated in gh."
        echo "  Run: gh auth login   (and pick account ${DEPLOY_ACCOUNT})"
        return 1
      fi
    fi

    active_now=$(_gh_active_user)
    if [ "${active_now}" != "${DEPLOY_ACCOUNT}" ]; then
      echo "  [FATAL] Could not activate ${DEPLOY_ACCOUNT} (still ${active_now:-<none>})"
      echo "  Hint: if running under systemd, ensure 'gh auth switch' works manually as ${APP_USER:-the service user}."
      echo "        Headless servers without keyring: re-run 'gh auth login' for ${DEPLOY_ACCOUNT}"
      echo "        with token-based auth so hosts.yml stores the token in plaintext."
      return 1
    fi
    echo "  gh active account (now)    : ${active_now} ✓"
    deploy_token=$(gh auth token 2>/dev/null || true)
  fi

  if [ -z "${deploy_token}" ]; then
    echo "  [FATAL] Could not obtain token for ${DEPLOY_ACCOUNT}"
    return 1
  fi

  local DEPLOY_URL="https://github.com/${DEPLOY_ACCOUNT}/${DEPLOY_REPO}.git"
  local DEPLOY_TMP="/tmp/github-dashboard-deploy/${DEPLOY_REPO}"

  mkdir -p "$(dirname "${DEPLOY_TMP}")"

  # GIT_ASKPASS injects DEPLOY_ACCOUNT token — bypasses credential-helper cache
  # that may still hold SOURCE_ACCOUNT creds even after `gh auth switch`.
  local askpass
  askpass=$(mktemp /tmp/git-askpass-deploy-XXXXXX)
  cat > "${askpass}" <<'ASKPASS'
#!/bin/sh
case "$1" in *sername*) printf 'x-access-token' ;; *) printf '%s' "${_GIT_TOKEN}" ;; esac
ASKPASS
  chmod 700 "${askpass}"
  # shellcheck disable=SC2064
  trap "rm -f '${askpass}'" RETURN

  export _GIT_TOKEN="${deploy_token}"
  export GIT_ASKPASS="${askpass}"
  export GIT_TERMINAL_PROMPT=0

  if [ -d "${DEPLOY_TMP}/.git" ]; then
    echo "  Updating existing deploy clone..."
    git -C "${DEPLOY_TMP}" remote set-url origin "${DEPLOY_URL}"
    git -C "${DEPLOY_TMP}" pull --rebase 2>&1 || true
  else
    echo "  Cloning deploy repo: ${DEPLOY_URL}"
    if ! git clone "${DEPLOY_URL}" "${DEPLOY_TMP}" 2>&1; then
      echo "  Clone failed — initializing empty deploy repo"
      rm -rf "${DEPLOY_TMP}"
      mkdir -p "${DEPLOY_TMP}"
      git -C "${DEPLOY_TMP}" init
      git -C "${DEPLOY_TMP}" checkout -b main 2>/dev/null || true
      git -C "${DEPLOY_TMP}" remote add origin "${DEPLOY_URL}"
    fi
  fi

  # Preserve historical analysis/*.html from deploy repo before wipe.
  if [ -d "${DEPLOY_TMP}/analysis" ]; then
    mkdir -p "${ROOT_DIR}/site/analysis"
    local _preserved=0
    for _old_html in "${DEPLOY_TMP}/analysis"/*.html; do
      [ -f "${_old_html}" ] || continue
      local _local_path="${ROOT_DIR}/site/analysis/$(basename "${_old_html}")"
      if [ ! -f "${_local_path}" ]; then
        cp -p "${_old_html}" "${_local_path}"
        _preserved=$((_preserved + 1))
      fi
    done
    [ "${_preserved}" -gt 0 ] && echo "  Preserved ${_preserved} existing analysis HTMLs from deploy repo"
  fi

  find "${DEPLOY_TMP}" -maxdepth 1 ! -name '.git' ! -path "${DEPLOY_TMP}" -exec rm -rf {} + 2>/dev/null || true
  cp -rp "${ROOT_DIR}/site/." "${DEPLOY_TMP}/"

  git -C "${DEPLOY_TMP}" config user.name  "${GIT_USER_NAME:-dashboard-bot}"
  git -C "${DEPLOY_TMP}" config user.email "${GIT_USER_EMAIL:-dashboard-bot@users.noreply.github.com}"
  git -C "${DEPLOY_TMP}" add .

  if git -C "${DEPLOY_TMP}" diff --cached --quiet; then
    echo "  Nothing to deploy (site/ unchanged)"
  else
    git -C "${DEPLOY_TMP}" commit -m "chore: daily dashboard update $(date '+%Y-%m-%d %H:%M KST')"
    if ! git -C "${DEPLOY_TMP}" push -u origin main 2>&1; then
      echo "  [FATAL] Push failed — verify ${DEPLOY_ACCOUNT} has write access to ${DEPLOY_ACCOUNT}/${DEPLOY_REPO}"
      return 1
    fi
    echo "  Deployed → https://github.com/${DEPLOY_ACCOUNT}/${DEPLOY_REPO}"
    echo "  Pages   → https://${DEPLOY_ACCOUNT}.github.io/${DEPLOY_REPO}/"
  fi

  unset _GIT_TOKEN GIT_ASKPASS GIT_TERMINAL_PROMPT
}

_publish_to_pages

# If analysis stopped on a usage limit, partial results are now deployed —
# exit with the limit code so callers (cron/systemd) see the abort.
if [ "${_LIMIT_HIT:-0}" -eq 1 ]; then
  echo ""
  echo "[run_daily] Stopped: Claude usage limit reached (partial results deployed) $(date '+%Y-%m-%d %H:%M:%S %Z')"
  exit "${_CLAUDE_LIMIT_EXIT}"
fi

echo ""
echo "[run_daily] Done: $(date '+%Y-%m-%d %H:%M:%S %Z')"
