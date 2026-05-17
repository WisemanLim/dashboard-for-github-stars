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
echo ""
echo "[1/7] Pull latest source"
if git remote get-url origin &>/dev/null 2>&1; then
  git pull --rebase origin main 2>&1 || {
    echo "  git pull failed (offline or unrelated histories) — continuing with local source"
  }
else
  echo "  No remote origin configured — skipping pull"
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
