#!/usr/bin/env bash
# test.sh — Automated smoke test for deploy.sh on macOS.
# Loads current .env values, pipes all inputs non-interactively.
# Skips scheduler, skips first run, skips auth if already logged in.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${ROOT_DIR}/logs"
LOG_FILE="${LOG_DIR}/test_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "${LOG_DIR}"

# ─── Load current .env for default values ────────────────────────────────────
if [ -f "${ROOT_DIR}/.env" ]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
fi
SOURCE_ACCOUNT="${SOURCE_ACCOUNT:-WisemanLim}"
DEPLOY_ACCOUNT="${DEPLOY_ACCOUNT:-ClaroPessoas}"
DEPLOY_REPO="${DEPLOY_REPO:-Dashboard4Stars}"
SCHEDULE_TIME="${SCHEDULE_TIME:-02:00}"
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-6}"
APP_USER="${USER:-wise}"

echo "════════════════════════════════════════════════"
echo "  deploy.sh smoke test — $(date '+%Y-%m-%d %H:%M:%S')"
echo "════════════════════════════════════════════════"
echo "  Source   : ${SOURCE_ACCOUNT}"
echo "  Deploy   : ${DEPLOY_ACCOUNT}/${DEPLOY_REPO}"
echo "  Schedule : ${SCHEDULE_TIME} (scheduler: skip)"
echo "  Log      : ${LOG_FILE}"
echo ""

# ─── Pre-condition checks ─────────────────────────────────────────────────────
PREFAIL=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; PREFAIL=1; }
warn_chk() { echo "  [WARN] $1 — deploy.sh will handle this"; }

echo "--- Pre-condition checks (hard) ---"
# These must exist; deploy.sh cannot install them
command -v git     &>/dev/null && pass "git installed"     || fail "git installed"
command -v python3 &>/dev/null && pass "python3 installed" || fail "python3 installed"
command -v node    &>/dev/null && pass "node installed"    || fail "node installed"
command -v claude  &>/dev/null && pass "claude installed"  || fail "claude installed"
if [[ "$(uname -s)" == "Darwin" ]]; then
  command -v brew &>/dev/null && pass "brew installed" || fail "brew installed (required on macOS)"
fi
echo ""

echo "--- Pre-condition checks (soft — deploy.sh handles) ---"
# gh: deploy.sh installs if missing; auth: may require manual interaction
if [[ "$(uname -s)" == "Darwin" ]]; then
  brew list --formula gh &>/dev/null && pass "gh installed (Homebrew)" || warn_chk "gh not in Homebrew → will install"
else
  command -v gh &>/dev/null && pass "gh installed" || warn_chk "gh not found → will install"
fi
if gh auth status &>/dev/null; then
  pass "gh authenticated"
  GH_AUTH_OK=1
else
  warn_chk "gh not authenticated → 'gh auth login' will run interactively"
  GH_AUTH_OK=0
fi
echo ""

if [ "${PREFAIL}" -ne 0 ]; then
  echo "Hard pre-condition checks FAILED. Fix issues above before running deploy.sh."
  exit 1
fi

if [ "${GH_AUTH_OK}" -eq 0 ]; then
  echo "NOTE: gh is not authenticated. deploy.sh will run 'gh auth login' interactively."
  echo "      The piped-input test may pause at that step."
  echo "      Press Ctrl-C now and run 'gh auth login' first, or proceed and authenticate manually."
  echo ""
  read -rp "  Continue anyway? [y/N]: " _CONT
  [[ "${_CONT:-N}" =~ ^[Yy]$ ]] || exit 0
fi

# ─── Build piped inputs ───────────────────────────────────────────────────────
# Matches read prompts in deploy.sh in order:
#  1. Source GitHub account
#  2. Deploy GitHub account
#  3. Deploy repo name
#  4. Scheduler time        (empty → default 02:00)
#  5. Claude model          (empty → default)
#  6. App user              (empty → default ${USER})
#  7. Scheduler choice      → 3 = skip
#  8. Proceed               → Y
#  9. Claude already logged in? → y (skip claude login)
# 10. Run now?              → n
INPUTS=$(printf '%s\n' \
  "${SOURCE_ACCOUNT}" \
  "${DEPLOY_ACCOUNT}" \
  "${DEPLOY_REPO}"    \
  ""                  \
  ""                  \
  ""                  \
  "3"                 \
  "Y"                 \
  "y"                 \
  "n"                 \
)

# ─── Run deploy.sh with piped inputs, tee to log ─────────────────────────────
echo "--- Running deploy.sh ---"
echo ""
set +e
echo "${INPUTS}" | bash "${ROOT_DIR}/deploy.sh" 2>&1 | tee "${LOG_FILE}"
DEPLOY_EXIT="${PIPESTATUS[1]}"
set -e

# ─── deploy.sh result ────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════"
if [ "${DEPLOY_EXIT}" -eq 0 ]; then
  echo "  DEPLOY : PASS (exit ${DEPLOY_EXIT})"
else
  echo "  DEPLOY : FAIL (exit ${DEPLOY_EXIT})"
  echo ""
  echo "  Last 20 lines of log:"
  tail -20 "${LOG_FILE}"
  echo "  Log    : ${LOG_FILE}"
  echo "════════════════════════════════════════════════"
  exit "${DEPLOY_EXIT}"
fi
echo "  Log    : ${LOG_FILE}"
echo "════════════════════════════════════════════════"

# ─── Run daily pipeline ───────────────────────────────────────────────────────
echo ""
echo "--- Running scripts/run_daily.sh ---"
echo ""
# Source .env so DEPLOY_ACCOUNT / DEPLOY_REPO are available
# shellcheck disable=SC1091
[ -f "${ROOT_DIR}/.env" ] && source "${ROOT_DIR}/.env"

set +e
bash "${ROOT_DIR}/scripts/run_daily.sh"
DAILY_EXIT="$?"
set -e

# Find the latest run log
LATEST_RUN_LOG=$(ls -t "${ROOT_DIR}/logs/run_"*.log 2>/dev/null | head -1 || true)

echo ""
echo "════════════════════════════════════════════════"
if [ "${DAILY_EXIT}" -eq 0 ]; then
  echo "  PIPELINE: PASS (exit ${DAILY_EXIT})"
  echo ""
  # Verify expected outputs
  pass() { echo "  [OK]   $1"; }
  miss() { echo "  [MISS] $1"; }
  [ -f "${ROOT_DIR}/site/assets/data.json" ]        && pass "site/assets/data.json"        || miss "site/assets/data.json"
  [ -f "${ROOT_DIR}/site/assets/new_trending.json" ] && pass "site/assets/new_trending.json" || miss "site/assets/new_trending.json"
  [ -f "${ROOT_DIR}/site/index.html" ]               && pass "site/index.html"               || miss "site/index.html"
  ANALYSIS_COUNT=$(ls "${ROOT_DIR}/site/analysis/"*.html 2>/dev/null | wc -l | tr -d ' ')
  echo "  [INFO] site/analysis/ HTML files: ${ANALYSIS_COUNT}"
else
  echo "  PIPELINE: FAIL (exit ${DAILY_EXIT})"
  if [ -n "${LATEST_RUN_LOG}" ]; then
    echo ""
    echo "  Last 20 lines of run log:"
    tail -20 "${LATEST_RUN_LOG}"
    echo "  Run log : ${LATEST_RUN_LOG}"
  fi
fi
echo "════════════════════════════════════════════════"

# Overall exit: fail if either step failed
[ "${DEPLOY_EXIT}" -eq 0 ] && [ "${DAILY_EXIT}" -eq 0 ] && exit 0 || exit 1
