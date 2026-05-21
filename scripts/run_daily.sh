#!/usr/bin/env bash
# Daily orchestrator: collect → compare → build → analyze → deploy site/
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

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
echo "[run_daily] Start: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "========================================"

# Activate venv
if [ -f "${VENV}/bin/activate" ]; then
  source "${VENV}/bin/activate"
else
  echo "[WARN] venv not found at ${VENV} — run deploy.sh first to set up dependencies"
fi

# 1. Pull latest source code from SOURCE_ACCOUNT repo
#    Uses GIT_ASKPASS to inject SOURCE_ACCOUNT token directly — avoids gh credential-helper
#    conflicts when DEPLOY_ACCOUNT is the active gh session.
echo ""
echo "[1/7] Pull latest source"

_pull_source() {
  [ -n "${SOURCE_ACCOUNT:-}" ] \
    || { echo "  SOURCE_ACCOUNT not set — skipping pull"; return 0; }
  command -v gh &>/dev/null \
    || { echo "  gh CLI not found — skipping pull"; return 0; }
  git remote get-url origin &>/dev/null 2>&1 \
    || { echo "  No remote origin — skipping pull"; return 0; }

  # Get SOURCE_ACCOUNT token (switch temporarily if needed, then restore)
  local token active_before
  active_before=$(gh auth status 2>&1 \
    | awk '/Active account: true/{f=1;next} f && /account/{print $NF;exit}' \
    | tr -d '()' || true)

  if [ "${active_before}" = "${SOURCE_ACCOUNT}" ]; then
    token=$(gh auth token 2>/dev/null || true)
  elif gh auth status 2>&1 | grep -qwF "${SOURCE_ACCOUNT}"; then
    gh auth switch -u "${SOURCE_ACCOUNT}" >/dev/null 2>&1 || true
    token=$(gh auth token 2>/dev/null || true)
    [ -n "${active_before}" ] && gh auth switch -u "${active_before}" >/dev/null 2>&1 || true
  fi

  [ -n "${token:-}" ] \
    || { echo "  SOURCE_ACCOUNT (${SOURCE_ACCOUNT}) not authenticated — skipping pull"; return 0; }

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

# 4. Compare with previous
echo ""
echo "[4/7] Compare with previous (find new trending)"
python3 scripts/compare_with_previous.py

# 5. Build dashboard
echo ""
echo "[5/7] Build static dashboard"
python3 scripts/build_dashboard.py

# 6. Run Claude analysis (non-fatal unless usage limit hit)
echo ""
echo "[6/7] Run Claude analysis"
_CLAUDE_LIMIT_EXIT=42
if command -v claude &>/dev/null; then
  _analysis_rc=0
  bash scripts/run_claude_analysis.sh || _analysis_rc=$?
  if [ "${_analysis_rc}" -eq "${_CLAUDE_LIMIT_EXIT}" ]; then
    echo "  [FATAL] Claude usage limit reached — stopping run_daily.sh"
    exit "${_CLAUDE_LIMIT_EXIT}"
  elif [ "${_analysis_rc}" -ne 0 ]; then
    echo "  Analysis step failed (non-fatal), continuing"
  fi
  # Rebuild to pick up new analysis links (even if partial)
  python3 scripts/build_dashboard.py
else
  echo "  claude CLI not found, skipping analysis"
fi

# 7. Deploy site/ to GitHub Pages repo (deploy remote — separate clone)
echo ""
echo "[7/7] Deploy site/ to GitHub Pages"

DEPLOY_ACCOUNT="${DEPLOY_ACCOUNT:-}"
DEPLOY_REPO="${DEPLOY_REPO:-}"

if [ -z "${DEPLOY_ACCOUNT}" ] || [ -z "${DEPLOY_REPO}" ]; then
  echo "  DEPLOY_ACCOUNT or DEPLOY_REPO not set in .env — skipping deploy"
else
  # Ensure DEPLOY_ACCOUNT is active gh session before push
  if command -v gh &>/dev/null; then
    _deploy_active=$(gh auth status 2>&1 \
      | awk '/Active account: true/{f=1;next} f && /account/{print $NF;exit}' \
      | tr -d '()' || true)
    if [ "${_deploy_active}" != "${DEPLOY_ACCOUNT}" ]; then
      echo "  Switching gh to DEPLOY_ACCOUNT (${DEPLOY_ACCOUNT}) for push..."
      gh auth switch -u "${DEPLOY_ACCOUNT}" >/dev/null 2>&1 \
        || echo "  WARN: could not switch to ${DEPLOY_ACCOUNT} — push may fail"
    else
      echo "  Active gh account: ${DEPLOY_ACCOUNT} ✓"
    fi
  fi

  DEPLOY_URL="https://github.com/${DEPLOY_ACCOUNT}/${DEPLOY_REPO}.git"
  DEPLOY_TMP="/tmp/github-dashboard-deploy/${DEPLOY_REPO}"

  mkdir -p "$(dirname "${DEPLOY_TMP}")"

  # Clone or update the deploy repo into a temp directory
  if [ -d "${DEPLOY_TMP}/.git" ]; then
    echo "  Updating existing deploy clone..."
    git -C "${DEPLOY_TMP}" pull --rebase 2>&1 || true
  else
    echo "  Cloning deploy repo: ${DEPLOY_URL}"
    if ! git clone "${DEPLOY_URL}" "${DEPLOY_TMP}" 2>&1; then
      # Empty or new repo: init fresh
      echo "  Clone failed — initializing empty deploy repo"
      rm -rf "${DEPLOY_TMP}"
      mkdir -p "${DEPLOY_TMP}"
      git -C "${DEPLOY_TMP}" init
      git -C "${DEPLOY_TMP}" checkout -b main 2>/dev/null || true
      git -C "${DEPLOY_TMP}" remote add origin "${DEPLOY_URL}"
    fi
  fi

  # Preserve historical analysis/*.html from deploy repo before wipe.
  # Files not regenerated today are copied back to local site/analysis/
  # so the wipe-and-copy below carries them forward.
  if [ -d "${DEPLOY_TMP}/analysis" ]; then
    mkdir -p "${ROOT_DIR}/site/analysis"
    _preserved=0
    for _old_html in "${DEPLOY_TMP}/analysis"/*.html; do
      [ -f "${_old_html}" ] || continue
      _local_path="${ROOT_DIR}/site/analysis/$(basename "${_old_html}")"
      if [ ! -f "${_local_path}" ]; then
        cp -p "${_old_html}" "${_local_path}"
        _preserved=$((_preserved + 1))
      fi
    done
    [ "${_preserved}" -gt 0 ] && echo "  Preserved ${_preserved} existing analysis HTMLs from deploy repo"
  fi

  # Replace deploy dir contents with generated site/ (preserve .git)
  find "${DEPLOY_TMP}" -maxdepth 1 ! -name '.git' ! -path "${DEPLOY_TMP}" -exec rm -rf {} + 2>/dev/null || true
  cp -rp "${ROOT_DIR}/site/." "${DEPLOY_TMP}/"

  # Commit and push
  git -C "${DEPLOY_TMP}" config user.name  "${GIT_USER_NAME:-dashboard-bot}"
  git -C "${DEPLOY_TMP}" config user.email "${GIT_USER_EMAIL:-dashboard-bot@users.noreply.github.com}"
  git -C "${DEPLOY_TMP}" add .

  if git -C "${DEPLOY_TMP}" diff --cached --quiet; then
    echo "  Nothing to deploy (site/ unchanged)"
  else
    git -C "${DEPLOY_TMP}" commit -m "chore: daily dashboard update $(date '+%Y-%m-%d %H:%M KST')"
    git -C "${DEPLOY_TMP}" push -u origin main 2>&1 || {
      echo "  Push failed — check: gh auth status, access to ${DEPLOY_ACCOUNT}/${DEPLOY_REPO}"
      false
    }
    echo "  Deployed → https://github.com/${DEPLOY_ACCOUNT}/${DEPLOY_REPO}"
    echo "  Pages   → https://${DEPLOY_ACCOUNT}.github.io/${DEPLOY_REPO}/"
  fi
fi

echo ""
echo "[run_daily] Done: $(date '+%Y-%m-%d %H:%M:%S %Z')"
