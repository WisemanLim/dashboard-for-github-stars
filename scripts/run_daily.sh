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

# 1. Pull latest source code from source repo (origin)
#    Only when active gh account matches SOURCE_ACCOUNT (origin owner).
#    Otherwise (e.g. logged in as DEPLOY_ACCOUNT) skip and use local source.
echo ""
echo "[1/7] Pull latest source"
_pull_restore_account=""
_pull_should_restore=0

_gh_active_account() {
  gh auth status 2>&1 \
    | awk '/Active account: true/{found=1; next} found && /Logged in to .* account/{print $7; exit}' \
    | tr -d '()'
}

_origin_owner() {
  # Extract <owner> from https://github.com/<owner>/<repo>.git or git@github.com:<owner>/<repo>.git
  local url="$1"
  echo "${url}" | sed -E 's#(https?://[^/]+/|git@[^:]+:)([^/]+)/.*#\2#'
}

if ! git remote get-url origin &>/dev/null 2>&1; then
  echo "  No remote origin configured — skipping pull (use local source)"
elif ! command -v gh &>/dev/null; then
  echo "  gh CLI not found — skipping pull (use local source)"
else
  ORIGIN_URL="$(git remote get-url origin)"
  ORIGIN_OWNER="$(_origin_owner "${ORIGIN_URL}")"
  EXPECTED_OWNER="${SOURCE_ACCOUNT:-${ORIGIN_OWNER}}"
  ACTIVE_ACCOUNT="$(_gh_active_account || true)"

  if [ -n "${SOURCE_ACCOUNT:-}" ] && [ -n "${ORIGIN_OWNER}" ] && [ "${ORIGIN_OWNER}" != "${SOURCE_ACCOUNT}" ]; then
    echo "  origin owner (${ORIGIN_OWNER}) != SOURCE_ACCOUNT (${SOURCE_ACCOUNT}) — skipping pull (use local source)"
  elif [ -z "${ACTIVE_ACCOUNT}" ]; then
    echo "  gh not authenticated — skipping pull (use local source)"
  elif [ "${ACTIVE_ACCOUNT}" != "${EXPECTED_OWNER}" ]; then
    # Try switching to SOURCE_ACCOUNT if it's known to gh (multi-account login)
    if gh auth status 2>&1 | grep -qwF "${EXPECTED_OWNER}"; then
      echo "  Active gh account (${ACTIVE_ACCOUNT}) != source (${EXPECTED_OWNER}) — switching for pull"
      if gh auth switch -u "${EXPECTED_OWNER}" >/dev/null 2>&1; then
        _pull_restore_account="${ACTIVE_ACCOUNT}"
        _pull_should_restore=1
        git pull --rebase origin main 2>&1 || \
          echo "  git pull failed — continuing with local source"
      else
        echo "  gh auth switch to ${EXPECTED_OWNER} failed — skipping pull (use local source)"
      fi
    else
      echo "  Active gh account (${ACTIVE_ACCOUNT}) is not source (${EXPECTED_OWNER}) and not logged in — skipping pull (use local source)"
    fi
  else
    git pull --rebase origin main 2>&1 || \
      echo "  git pull failed — continuing with local source"
  fi

  if [ "${_pull_should_restore}" -eq 1 ] && [ -n "${_pull_restore_account}" ]; then
    gh auth switch -u "${_pull_restore_account}" >/dev/null 2>&1 || \
      echo "  WARN: failed to restore gh auth back to ${_pull_restore_account}"
  fi
fi

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

# 6. Run Claude analysis (non-fatal: dashboard still ships without analysis)
echo ""
echo "[6/7] Run Claude analysis"
if command -v claude &>/dev/null; then
  bash scripts/run_claude_analysis.sh || echo "  Analysis step failed (non-fatal), continuing"
  # Rebuild to pick up new analysis links
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
