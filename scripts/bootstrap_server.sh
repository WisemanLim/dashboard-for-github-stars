#!/usr/bin/env bash
# Bootstrap Linux server for github-stars-dashboard.
# Supports: Ubuntu 22.04, Oracle Linux (8/9), Amazon Linux 2023 (AL3)
# Run once as root or with sudo privileges after creating the VM.

# Re-exec under bash if invoked via 'sh ...' (dash lacks 'set -o pipefail').
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

APP_USER="${APP_USER:-ubuntu}"
APP_HOME="/home/${APP_USER}"
APP_DIR="${APP_HOME}/github-stars-dashboard"
REPO_URL="${REPO_URL:-}"
TZ_REGION="${TZ_REGION:-Asia/Seoul}"
SCHEDULE_TIME="${SCHEDULE_TIME:-02:00}"

if [ -z "${REPO_URL}" ]; then
  echo "ERROR: REPO_URL not set. Example:"
  echo "  REPO_URL=https://github.com/A_account/repo.git bash bootstrap_server.sh"
  exit 1
fi

# ─── Detect OS ────────────────────────────────────────────────────────────────
detect_os() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION_ID="${VERSION_ID:-}"
  else
    OS_ID="unknown"
    OS_VERSION_ID=""
  fi
  echo "=== [bootstrap] OS detected: ${OS_ID} ${OS_VERSION_ID} ==="
}

detect_os

# ─── Package manager abstraction ──────────────────────────────────────────────
pkg_update() {
  case "${OS_ID}" in
    ubuntu|debian)    apt-get update -qq ;;
    ol|rhel|centos)   dnf check-update -q || true ;;
    amzn)             dnf check-update -q || true ;;
    *)                apt-get update -qq 2>/dev/null || dnf check-update -q || true ;;
  esac
}

pkg_install() {
  case "${OS_ID}" in
    ubuntu|debian)
      apt-get install -y --no-install-recommends "$@" ;;
    ol|rhel|centos)
      dnf install -y "$@" 2>/dev/null || yum install -y "$@" ;;
    amzn)
      dnf install -y "$@" ;;
    *)
      apt-get install -y "$@" 2>/dev/null || dnf install -y "$@" || yum install -y "$@" ;;
  esac
}

# ─── Set timezone ─────────────────────────────────────────────────────────────
echo "=== [bootstrap] Setting timezone to ${TZ_REGION} ==="
if command -v timedatectl &>/dev/null; then
  timedatectl set-timezone "${TZ_REGION}"
else
  ln -sf "/usr/share/zoneinfo/${TZ_REGION}" /etc/localtime
  echo "${TZ_REGION}" > /etc/timezone
fi

# ─── Base packages ────────────────────────────────────────────────────────────
echo "=== [bootstrap] Installing base packages ==="
pkg_update

case "${OS_ID}" in
  ubuntu|debian)
    pkg_install git curl wget unzip jq build-essential \
      python3 python3-venv python3-pip pandoc ca-certificates
    ;;
  ol|rhel|centos)
    # Enable EPEL for pandoc
    pkg_install epel-release 2>/dev/null || true
    pkg_install git curl wget unzip jq gcc gcc-c++ make \
      python3 python3-pip pandoc ca-certificates
    ;;
  amzn)
    pkg_install git curl wget unzip jq gcc gcc-c++ make \
      python3 python3-pip pandoc ca-certificates
    ;;
esac

# ─── Node.js ──────────────────────────────────────────────────────────────────
echo "=== [bootstrap] Installing Node.js ==="
if ! command -v node &>/dev/null; then
  case "${OS_ID}" in
    ubuntu|debian)
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
      pkg_install nodejs
      ;;
    ol|rhel|centos)
      dnf module enable nodejs:20 -y 2>/dev/null || true
      pkg_install nodejs
      ;;
    amzn)
      # Amazon Linux 2023 ships Node.js in default repos
      pkg_install nodejs
      ;;
    *)
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
      pkg_install nodejs
      ;;
  esac
fi
echo "  node $(node --version)"

# ─── GitHub CLI (gh) ──────────────────────────────────────────────────────────
echo "=== [bootstrap] Installing GitHub CLI (gh) ==="
if ! command -v gh &>/dev/null; then
  case "${OS_ID}" in
    ubuntu|debian)
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list
      apt-get update -q && pkg_install gh
      ;;
    ol|rhel|centos|amzn)
      dnf install -y 'dnf-command(config-manager)' 2>/dev/null || true
      dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      pkg_install gh
      ;;
    *)
      echo "  WARNING: Cannot auto-install gh. Install manually: https://cli.github.com"
      ;;
  esac
fi
command -v gh &>/dev/null && echo "  $(gh --version | head -1)"

# ─── Claude Code CLI ──────────────────────────────────────────────────────────
echo "=== [bootstrap] Installing Claude Code CLI ==="
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code
fi
echo "  claude $(claude --version 2>/dev/null || echo 'installed')"

# ─── Ensure app user exists ───────────────────────────────────────────────────
echo "=== [bootstrap] Ensuring user ${APP_USER} exists ==="
id -u "${APP_USER}" &>/dev/null || useradd -m -s /bin/bash "${APP_USER}"

# ─── Clone / update repository (Account A source) ────────────────────────────
echo "=== [bootstrap] Cloning source repo (Account A) ==="
if [ -d "${APP_DIR}/.git" ]; then
  sudo -u "${APP_USER}" git -C "${APP_DIR}" pull --rebase
else
  sudo -u "${APP_USER}" git clone "${REPO_URL}" "${APP_DIR}"
fi

# ─── Python venv ──────────────────────────────────────────────────────────────
echo "=== [bootstrap] Setting up Python venv ==="
sudo -u "${APP_USER}" python3 -m venv "${APP_DIR}/.venv"
sudo -u "${APP_USER}" bash -c "
  source '${APP_DIR}/.venv/bin/activate'
  pip install --upgrade pip -q
  pip install -r '${APP_DIR}/requirements.txt' -q
"

# ─── systemd service + timer ──────────────────────────────────────────────────
SCHED_HOUR="${SCHEDULE_TIME%%:*}"
SCHED_MIN="${SCHEDULE_TIME##*:}"
SCHED_HOUR="${SCHED_HOUR#0}"; SCHED_HOUR="${SCHED_HOUR:-0}"
SCHED_MIN="${SCHED_MIN#0}";   SCHED_MIN="${SCHED_MIN:-0}"

echo "=== [bootstrap] Creating systemd service + timer (${SCHEDULE_TIME} ${TZ_REGION}) ==="
cat > /etc/systemd/system/github-dashboard.service <<EOF
[Unit]
Description=GitHub Stars Dashboard Daily Builder
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=${APP_USER}
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/.env
Environment=HOME=${APP_HOME}
Environment=PATH=${APP_DIR}/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/bin/bash ${APP_DIR}/scripts/run_daily.sh
StandardOutput=journal
StandardError=journal
EOF

cat > /etc/systemd/system/github-dashboard.timer <<EOF
[Unit]
Description=Run GitHub Stars Dashboard daily at ${SCHEDULE_TIME} ${TZ_REGION}

[Timer]
OnCalendar=*-*-* ${SCHED_HOUR}:${SCHED_MIN}:00 ${TZ_REGION}
Persistent=true
Unit=github-dashboard.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable github-dashboard.timer
systemctl start github-dashboard.timer

echo ""
echo "=== [bootstrap] Complete ==="
echo "  OS          : ${OS_ID} ${OS_VERSION_ID}"
echo "  App dir     : ${APP_DIR}"
echo "  Schedule    : ${SCHEDULE_TIME} ${TZ_REGION} daily"
echo "  Manual run  : sudo systemctl start github-dashboard.service"
echo "  Timer status: systemctl list-timers --all | grep github-dashboard"
echo "  Logs        : journalctl -u github-dashboard.service -f"
echo ""
echo "  Next steps:"
echo "    1. sudo -u ${APP_USER} gh auth login         # Account A GitHub auth (for git push)"
echo "    2. sudo -u ${APP_USER} claude login           # Claude OAuth"
echo "    3. cp .env.example ${APP_DIR}/.env && nano ${APP_DIR}/.env"
