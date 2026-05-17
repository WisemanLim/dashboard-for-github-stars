#!/usr/bin/env bash
# Daily orchestrator: collect → compare → build → analyze → push
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

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
fi

# 1. Pull latest source code
echo ""
echo "[1/7] Pull latest source"
git pull --rebase origin main || {
  echo "  git pull failed (offline?), continuing with local source"
}

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
# Inject GitHub token from gh CLI so Python can call the API with auth
if command -v gh &>/dev/null; then
  export GITHUB_TOKEN=$(gh auth token 2>/dev/null || echo "")
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
  # Rebuild dashboard to pick up new analysis links
  python3 scripts/build_dashboard.py
else
  echo "  claude CLI not found, skipping analysis"
fi

# 7. Commit and push
echo ""
echo "[7/7] Commit and push"
git add site/ || true
if git diff --cached --quiet; then
  echo "  Nothing to commit"
else
  git config user.name  "${GIT_USER_NAME:-dashboard-bot}"
  git config user.email "${GIT_USER_EMAIL:-dashboard-bot@users.noreply.github.com}"
  git commit -m "chore: daily dashboard update $(date '+%Y-%m-%d %H:%M KST')"
  git push origin main
  echo "  Pushed to origin/main"
fi

echo ""
echo "[run_daily] Done: $(date '+%Y-%m-%d %H:%M:%S %Z')"
