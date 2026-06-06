#!/usr/bin/env bash
# Run Claude Code CLI skills on selected analysis targets.
# Reads site/assets/analysis_targets.json (ordered: top100 → daily → weekly → monthly),
# clones each repo, runs the scoped skills, converts results to HTML, saves to
# site/analysis/{owner}_{name}.html.
#
# Scope (--scope, default "source"):
#   source  → analysis-source     → 📊 소스 분석 tab  (baseline, gates completeness)
#   indepth → in-depth-review     → 🔬 심층 분석 tab  (optional)
#   guide   → create-guide4junior → 📚 주니어 가이드 tab (optional)
#   Pass a comma list (--scope source,indepth) or "all" (--scope all = all three).
#   in-depth-review / create-guide4junior trip the usage limit far more often, so
#   they are off by default — run them explicitly when quota allows.
#
# Parallelism:
#   - Up to ANALYSIS_CONCURRENCY repos processed concurrently (default 3).
#   - Within each repo the scoped skills run concurrently.
#   - Peak claude processes ≈ ANALYSIS_CONCURRENCY × (skills in scope).
#   Priority order (top100→daily→weekly→monthly) is still the launch order, so
#   higher-priority repos start first; exact completion order is not guaranteed.
#
# Usage limit: any skill hitting a usage/rate limit touches a flag file. The main
#   loop stops launching new repos and the script exits 42 (caller stops pipeline).

# Re-exec under bash if invoked via 'sh ...' (dash lacks 'set -o pipefail').
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail
_CLAUDE_LIMIT_EXIT=42

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="${ROOT_DIR}/site/assets"
ANALYSIS_DIR="${ROOT_DIR}/site/analysis"
TEMPLATES_DIR="${ROOT_DIR}/templates"
CLAUDE_COMMANDS_DIR="${ROOT_DIR}/.claude/commands"
TMP_DIR="/tmp/github-dashboard-analysis"

# Allow .env to set ANALYSIS_CONCURRENCY (run_daily sources .env but does not export).
if [ -f "${ROOT_DIR}/.env" ]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
fi
ANALYSIS_CONCURRENCY="${ANALYSIS_CONCURRENCY:-3}"
case "${ANALYSIS_CONCURRENCY}" in ''|*[!0-9]*) ANALYSIS_CONCURRENCY=3 ;; esac
[ "${ANALYSIS_CONCURRENCY}" -lt 1 ] && ANALYSIS_CONCURRENCY=1

# Model used for analysis. Without this, `claude --print` falls back to the CLI's
# default model (often the heaviest), which burns the session/usage quota far
# faster and trips the limit. Default to the deploy-configured sonnet.
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-6}"

# --- Scope: which skills run this pass (default: source only) ---------------
# Also honored via ANALYSIS_SCOPE in .env; the --scope flag overrides it.
SCOPE_INPUT="${ANALYSIS_SCOPE:-source}"
while [ $# -gt 0 ]; do
  case "$1" in
    --scope) SCOPE_INPUT="${2:-}"; shift 2 ;;
    --scope=*) SCOPE_INPUT="${1#--scope=}"; shift ;;
    *) echo "[analysis] Unknown argument: $1" >&2
       echo "  Usage: $0 [--scope source,indepth,guide|all]" >&2
       exit 2 ;;
  esac
done
[ "${SCOPE_INPUT}" = "all" ] && SCOPE_INPUT="source,indepth,guide"

# Normalize comma list → validated, deduped, space-separated SCOPE_KEYS.
SCOPE_KEYS=""
_IFS_SAVE="${IFS}"; IFS=','
for _k in ${SCOPE_INPUT}; do
  case "${_k}" in
    source|indepth|guide)
      case " ${SCOPE_KEYS} " in *" ${_k} "*) : ;; *) SCOPE_KEYS="${SCOPE_KEYS} ${_k}" ;; esac ;;
    '') : ;;
    *) IFS="${_IFS_SAVE}"; echo "[analysis] Invalid --scope key: '${_k}' (allowed: source, indepth, guide, all)" >&2; exit 2 ;;
  esac
done
IFS="${_IFS_SAVE}"
SCOPE_KEYS="${SCOPE_KEYS# }"
[ -z "${SCOPE_KEYS}" ] && { echo "[analysis] Empty --scope" >&2; exit 2; }

# True if key $1 is in the active scope.
_in_scope() { case " ${SCOPE_KEYS} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

TARGETS_JSON="${ASSETS_DIR}/analysis_targets.json"

if [ ! -f "${TARGETS_JSON}" ]; then
  echo "[analysis] analysis_targets.json not found, skipping analysis"
  exit 0
fi

mkdir -p "${ANALYSIS_DIR}" "${TMP_DIR}"

LIMIT_FLAG="${TMP_DIR}/.usage_limit"
LOG_LOCK="${TMP_DIR}/.loglock"
rm -f "${LIMIT_FLAG}"
rm -rf "${LOG_LOCK}"

# Match Claude CLI limit/quota messages. Covers both the older "usage limit /
# reset at" wording and the newer "You've hit your session limit · resets 3:50pm".
_LIMIT_RE='usage.?limit|rate.?limit|session.?limit|too many requests|hit your[^.]*limit|reset[s]?( at)? [0-9]|reset[s]?( at)? [0-9]*[ap]m|Claude AI usage'

# Flush a per-repo log buffer as one contiguous block (mkdir = atomic mutex so
# concurrent repos don't interleave their output mid-line).
flush_log() {
  local f="$1"
  [ -f "${f}" ] || return 0
  while ! mkdir "${LOG_LOCK}" 2>/dev/null; do sleep 0.05; done
  cat "${f}"
  rmdir "${LOG_LOCK}" 2>/dev/null || true
}

# Run a claude skill non-interactively: read template, inject args, capture output → write file.
# On usage limit: touch LIMIT_FLAG and return 42 (must NOT exit — runs in a backgrounded subshell).
# Usage: run_skill <skill-name> <extra-args> <output-file> <cwd>
run_skill() {
  local skill_name="$1" extra_args="$2" out_file="$3" cwd="$4"
  local skill_file="${CLAUDE_COMMANDS_DIR}/${skill_name}.md"
  [ -f "${skill_file}" ] || { echo "    Skill not found: ${skill_file}"; return 1; }

  # Build prompt: substitute $ARGUMENTS in template (python handles special chars safely)
  local prompt
  prompt=$(python3 - "${skill_file}" "${cwd} ${extra_args}" <<'PY'
import sys
content = open(sys.argv[1]).read()
content = content.replace("$ARGUMENTS", sys.argv[2])
# Tell model to output ONLY the report markdown — no file writes needed
content += "\n\n---\nOUTPUT INSTRUCTION: Output ONLY the final report in markdown. Do not write any files. Do not include preamble. Start directly with the report content."
print(content)
PY
) || { echo "    Failed to build prompt for ${skill_name}"; return 1; }

  echo "    Running ${skill_name} (may take 1-3 min)..."
  local output
  if ! output=$(cd "${cwd}" && printf '%s' "${prompt}" | claude --print --model "${CLAUDE_MODEL}" --dangerously-skip-permissions 2>&1); then
    if printf '%s' "${output}" | grep -qiE "${_LIMIT_RE}"; then
      echo "    [FATAL] Claude usage limit detected (${skill_name}) — flagging abort"
      touch "${LIMIT_FLAG}"
      return ${_CLAUDE_LIMIT_EXIT}
    fi
    echo "    claude failed for ${skill_name}:"
    echo "${output}" | head -5
    return 1
  fi

  # Check successful response for embedded usage-limit messages
  if printf '%s' "${output}" | grep -qiE "${_LIMIT_RE}"; then
    echo "    [FATAL] Claude usage limit detected (${skill_name}) — flagging abort"
    touch "${LIMIT_FLAG}"
    return ${_CLAUDE_LIMIT_EXIT}
  fi

  if [ -z "${output}" ]; then
    echo "    Empty response from ${skill_name}"
    return 1
  fi

  mkdir -p "$(dirname "${out_file}")"
  printf '%s\n' "${output}" > "${out_file}"
  echo "    Saved: ${out_file} ($(wc -l < "${out_file}") lines)"
}

# Read targets list (priority order preserved from analysis_targets.json)
REPO_LIST=$(python3 - "${TARGETS_JSON}" <<'EOF'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
for r in d.get("targets", []):
    fn = r.get("full_name", "")
    if fn:
        period = r.get("period", "daily")
        stars = r.get("stars", 0)
        desc = r.get("description", "").replace("|", " ")
        lang = r.get("language", "")
        stars_gained = r.get("stars_gained", "")
        print(f"{fn}|{period}|{stars}|{desc}|{lang}|{stars_gained}")
EOF
)

if [ -z "${REPO_LIST}" ]; then
  echo "[analysis] No repos to analyze"
  exit 0
fi

process_repo() {
  local full_name="$1"
  local period="$2"
  local stars="$3"
  local description="$4"
  local language="$5"
  local stars_gained="$6"

  local owner="${full_name%%/*}"
  local repo_name="${full_name##*/}"
  local safe_name="${full_name//\//_}"
  local clone_dir="${TMP_DIR}/${safe_name}"
  local review_dir="${clone_dir}/.review"
  local out_html="${ANALYSIS_DIR}/${safe_name}.html"
  local repo_log="${TMP_DIR}/.log_${safe_name}"

  # Buffer all output for this repo, then flush as one block (avoids interleaving).
  {
    if [ -f "${LIMIT_FLAG}" ]; then
      echo "[analysis] Skipping ${full_name} — usage limit already hit"
    elif _repo_complete "${full_name}"; then
      # Already finished (e.g. in a prior attempt before an account switch) —
      # makes the retry loop idempotent so we don't re-burn quota on done repos.
      echo "[analysis] ${full_name} already complete — skipping"
    else
      echo "[analysis] Processing: ${full_name} (${period}, ★${stars})"

      # Clone or update repo (shallow)
      local _ok=1
      if [ -d "${clone_dir}/.git" ]; then
        echo "  Updating existing clone..."
        git -C "${clone_dir}" fetch --depth=1 origin HEAD 2>/dev/null || true
      else
        echo "  Cloning (shallow)..."
        git clone --depth=1 "https://github.com/${full_name}.git" "${clone_dir}" 2>/dev/null || {
          echo "  Clone failed, skipping ${full_name}"
          _ok=0
        }
      fi

      if [ "${_ok}" -eq 1 ]; then
        mkdir -p "${review_dir}"

        # Clear this run's outputs first (only the scoped ones). The clone dir is
        # reused across runs (/tmp), so leftover .md from a prior run would
        # otherwise be re-rendered as if fresh — making a failed (e.g.
        # usage-limited) skill silently reuse stale content. Preservation of good
        # prior tabs is handled by panel_body_html (reads the deployed HTML), not
        # by these temp files.
        _in_scope source  && rm -f "${review_dir}/REVIEW-Source.md"
        _in_scope indepth && rm -f "${review_dir}/REVIEW-InDepth.md"
        _in_scope guide   && rm -f "${review_dir}/GUIDE4Junior.md"

        # Run the scoped skills concurrently; each writes its own review file.
        local pids=""
        if _in_scope source; then
          run_skill "analysis-source"     "--review-result REVIEW-Source.md"  "${review_dir}/REVIEW-Source.md"  "${clone_dir}" &
          pids="${pids} $!"
        fi
        if _in_scope indepth; then
          run_skill "in-depth-review"     "--review-result REVIEW-InDepth.md" "${review_dir}/REVIEW-InDepth.md" "${clone_dir}" &
          pids="${pids} $!"
        fi
        if _in_scope guide; then
          run_skill "create-guide4junior" ""                                  "${review_dir}/GUIDE4Junior.md"  "${clone_dir}" &
          pids="${pids} $!"
        fi
        for _p in ${pids}; do wait "${_p}" || true; done

        # Skip HTML write if no scoped skill produced output — preserves prior good HTML in DEPLOY_REPO
        if [ ! -f "${review_dir}/REVIEW-Source.md" ] && [ ! -f "${review_dir}/REVIEW-InDepth.md" ] && [ ! -f "${review_dir}/GUIDE4Junior.md" ]; then
          echo "  No skill output for ${full_name} — keeping existing HTML if any"
        else
          export _PY_FULL_NAME="${full_name}"
          export _PY_REPO_NAME="${repo_name}"
          export _PY_OWNER="${owner}"
          export _PY_PERIOD="${period}"
          export _PY_STARS="${stars}"
          export _PY_DESC="${description}"
          export _PY_LANG="${language}"
          export _PY_STARS_GAINED="${stars_gained}"
          export _PY_REVIEW_DIR="${review_dir}"
          export _PY_OUT_HTML="${out_html}"
          export _PY_TMPL_DIR="${TEMPLATES_DIR}"

          python3 - <<'PYEOF'
import os, sys, markdown
from jinja2 import Template

# stdin heredoc has no __file__; derive scripts/ from TEMPLATES_DIR (ROOT/templates).
sys.path.insert(0, os.path.join(os.path.dirname(os.environ["_PY_TMPL_DIR"]), "scripts"))
from analysis_status import panel_body_html

full_name    = os.environ["_PY_FULL_NAME"]
repo_name    = os.environ["_PY_REPO_NAME"]
owner        = os.environ["_PY_OWNER"]
period       = os.environ["_PY_PERIOD"]
stars        = os.environ["_PY_STARS"]
description  = os.environ["_PY_DESC"]
language     = os.environ["_PY_LANG"]
stars_gained = os.environ["_PY_STARS_GAINED"]
review_dir   = os.environ["_PY_REVIEW_DIR"]
out_html     = os.environ["_PY_OUT_HTML"]
tmpl_path    = os.environ["_PY_TMPL_DIR"] + "/analysis.html.j2"

def md(text):
    return markdown.markdown(text, extensions=["tables", "fenced_code", "toc"])

# Per tab: this run's skill output → md(). If the skill produced nothing this
# run, fall back to the prior analysis's tab (preserve good content, never
# overwrite it with an empty sentinel). Only when no prior content exists do we
# emit the "no result" sentinel.
def tab_html(md_file, panel, sentinel):
    path = f"{review_dir}/{md_file}"
    if os.path.exists(path):
        return md(open(path).read())
    prior = panel_body_html(full_name, panel)
    if prior:
        return prior
    return md(sentinel)

source_html  = tab_html("REVIEW-Source.md",  "source",  "소스 분석 결과 없음")
indepth_html = tab_html("REVIEW-InDepth.md", "indepth", "심층 분석 결과 없음")
guide_html   = tab_html("GUIDE4Junior.md",   "guide",   "가이드 없음")

if os.path.exists(tmpl_path):
    with open(tmpl_path) as f:
        t = Template(f.read())
    rendered = t.render(
        full_name=full_name, repo_name=repo_name, owner=owner,
        period=period, stars=stars, description=description,
        language=language, stars_gained=stars_gained,
        source_html=source_html,
        indepth_html=indepth_html,
        guide_html=guide_html,
    )
    with open(out_html, "w") as fout:
        fout.write(rendered)
    print(f"  Saved: {out_html}")
else:
    print("  Template not found, skipping HTML render")
PYEOF

          echo "  Done: ${full_name}"
        fi
      fi
    fi
  } > "${repo_log}" 2>&1

  flush_log "${repo_log}"
  rm -f "${repo_log}"
}

# Count currently-running background repo workers (bash 3.2-safe; no `wait -n`).
_running() { jobs -rp | grep -c . || true; }

# True if a repo's analysis HTML is already complete (both tabs filled).
_repo_complete() {
  python3 - "$1" <<'PY' >/dev/null 2>&1
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.environ["TEMPLATES_DIR_FOR_STATUS"]), "scripts"))
from analysis_status import is_complete
sys.exit(0 if is_complete(sys.argv[1]) else 1)
PY
}
export TEMPLATES_DIR_FOR_STATUS="${TEMPLATES_DIR}"

# Launch one full pass over REPO_LIST with bounded concurrency, then wait.
# Repos already complete (prior pass) are skipped inside process_repo.
run_targets() {
  while IFS='|' read -r full_name period stars description language stars_gained; do
    [ -z "${full_name}" ] && continue
    [ -f "${LIMIT_FLAG}" ] && { echo "[analysis] Usage limit hit — not launching further repos"; break; }
    # Throttle: wait for a free slot before launching the next repo.
    while [ "$(_running)" -ge "${ANALYSIS_CONCURRENCY}" ]; do
      sleep 0.5
      [ -f "${LIMIT_FLAG}" ] && break
    done
    [ -f "${LIMIT_FLAG}" ] && { echo "[analysis] Usage limit hit — not launching further repos"; break; }
    process_repo "${full_name}" "${period}" "${stars}" "${description}" "${language}" "${stars_gained}" &
  done <<< "${REPO_LIST}"
  wait
}

# On usage limit: offer an interactive Claude account switch (logout → login),
# then resume. 5s timeout, default No. Needs a TTY — unattended runs (cron/
# systemd, no /dev/tty) fall through to abort. Returns 0 if switched (retry), 1 otherwise.
_prompt_switch_account() {
  # Probe by actually opening /dev/tty — a perms test (-r/-w) passes even when
  # there is no controlling terminal (cron/systemd), where the open then fails
  # with "Device not configured". Suppress that noise and fall through to abort.
  if ! { true >/dev/tty; } 2>/dev/null; then
    echo "  No TTY available — cannot prompt for account switch."
    return 1
  fi
  local ans=""
  printf '  Claude usage limit reached. Switch Claude account and retry? [y/N] (5s): ' > /dev/tty
  read -t 5 -r ans < /dev/tty || true
  printf '\n' > /dev/tty
  case "${ans}" in
    y|Y|yes|YES)
      echo "  Switching Claude account (logout → login)..."
      claude auth logout < /dev/tty > /dev/tty 2>&1 || true
      if ! claude auth login --claudeai < /dev/tty > /dev/tty 2>&1; then
        echo "  claude auth login failed — aborting."
        return 1
      fi
      if claude auth status > /dev/null 2>&1; then
        echo "  New account active — resuming analysis."
        return 0
      fi
      echo "  auth status check failed after login — aborting."
      return 1 ;;
    *)
      echo "  No account switch (declined / timed out) — aborting."
      return 1 ;;
  esac
}

echo "[analysis] Starting parallel analysis (scope=${SCOPE_KEYS// /,}, concurrency=${ANALYSIS_CONCURRENCY}, order top100 → daily → weekly → monthly)"

# Safety cap on account-switch retries to avoid an unbounded loop.
_MAX_SWITCHES=5
_switches=0
while : ; do
  run_targets

  [ -f "${LIMIT_FLAG}" ] || break   # no limit this pass → done (success/partial)

  # Limit hit this pass.
  if [ "${_switches}" -ge "${_MAX_SWITCHES}" ]; then
    rm -f "${LIMIT_FLAG}"
    echo "[analysis] Aborted: usage limit persists after ${_MAX_SWITCHES} account switch(es)"
    exit ${_CLAUDE_LIMIT_EXIT}
  fi

  if _prompt_switch_account; then
    _switches=$((_switches + 1))
    rm -f "${LIMIT_FLAG}"
    echo "[analysis] Retrying remaining repos after account switch (#${_switches})..."
    continue
  fi

  rm -f "${LIMIT_FLAG}"
  echo "[analysis] Aborted: Claude usage limit reached"
  exit ${_CLAUDE_LIMIT_EXIT}
done

echo "[analysis] Complete. Results in ${ANALYSIS_DIR}"
