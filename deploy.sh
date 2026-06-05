#!/usr/bin/env bash
# deploy.sh — Interactive setup for GitHub Stars Dashboard on a Linux server.
# Run once on the target server (Oracle Cloud, etc.) after cloning this repo.
#
# Usage:
#   deploy.sh                          # full interactive setup
#   deploy.sh --schedule HH:MM         # schedule-only mode (reuses existing .env)
#   deploy.sh --schedule HH:MM cron    # schedule-only + force scheduler type
#   deploy.sh -h | --help              # show this help

# Re-exec under bash if invoked via 'sh deploy.sh' (dash lacks 'set -o pipefail').
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()     { echo -e "${RED}[ERROR]${NC} $*"; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Argument parsing ────────────────────────────────────────────────────────
SCHEDULE_ONLY=0
SCHEDULE_ONLY_TIME=""
SCHEDULE_ONLY_TYPE=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  --schedule HH:MM [type]   Schedule-only mode. Skips package install / auth.
                            Reuses .env. 'type' is optional: systemd|cron|launchd|skip.
                            If omitted, prompts interactively.
  -h, --help                Show this help and exit.

Examples:
  $(basename "$0")                       # full interactive setup
  $(basename "$0") --schedule 02:00      # register schedule only at 02:00 KST
  $(basename "$0") --schedule 03:30 cron # schedule-only, force cron type
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --schedule)
      SCHEDULE_ONLY=1
      [ -n "${2:-}" ] && [[ "$2" =~ ^[0-9]{1,2}:[0-9]{2}$ ]] \
        || { err "--schedule requires HH:MM"; usage; exit 1; }
      SCHEDULE_ONLY_TIME="$2"
      shift 2
      if [ -n "${1:-}" ] && [[ "$1" =~ ^(systemd|cron|launchd|skip)$ ]]; then
        SCHEDULE_ONLY_TYPE="$1"
        shift
      fi
      ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

# ─── Detect OS ────────────────────────────────────────────────────────────────
if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
  OS_ID="darwin"
  OS_VERSION_ID="$(sw_vers -productVersion 2>/dev/null || echo '')"
elif [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_VERSION_ID="${VERSION_ID:-}"
else
  OS_ID="unknown"; OS_VERSION_ID=""
fi

pkg_install() {
  case "${OS_ID}" in
    darwin)
      brew install "$@" >/dev/null ;;
    ubuntu|debian)
      sudo apt-get install -y --no-install-recommends "$@" >/dev/null ;;
    ol|rhel|centos)
      sudo dnf install -y "$@" >/dev/null 2>&1 || sudo yum install -y "$@" >/dev/null ;;
    amzn)
      sudo dnf install -y "$@" >/dev/null ;;
    *)
      if command -v brew &>/dev/null; then brew install "$@" >/dev/null
      elif command -v apt-get &>/dev/null; then sudo apt-get install -y "$@" >/dev/null
      elif command -v dnf &>/dev/null; then sudo dnf install -y "$@" >/dev/null
      elif command -v yum &>/dev/null; then sudo yum install -y "$@" >/dev/null
      else err "No package manager found. Install $* manually."; fi ;;
  esac
}

# ─── Scheduler install / status (shared by full + --schedule modes) ───────────
PLIST_FILE=""

install_scheduler() {
  SCHED_HOUR="${SCHEDULE_TIME%%:*}"
  SCHED_MIN="${SCHEDULE_TIME##*:}"
  SCHED_HOUR="${SCHED_HOUR#0}"; SCHED_HOUR="${SCHED_HOUR:-0}"
  SCHED_MIN="${SCHED_MIN#0}";   SCHED_MIN="${SCHED_MIN:-0}"

  info "Setting up scheduler: ${SCHEDULER}"

  # systemd needs root. Try sudo if available; otherwise fall back to cron.
  local SUDO=""
  if [[ "${SCHEDULER}" == "systemd" ]] && [ "$(id -u)" -ne 0 ]; then
    if command -v sudo &>/dev/null; then
      info "systemd timer requires root — using sudo (may prompt for password)"
      SUDO="sudo"
    else
      warn "systemd timer requires root and sudo not available. Falling back to cron."
      SCHEDULER="cron"
    fi
  fi

  if [[ "${SCHEDULER}" == "launchd" ]]; then
    local PLIST_DIR="${HOME}/Library/LaunchAgents"
    PLIST_FILE="${PLIST_DIR}/com.github-dashboard.daily.plist"
    mkdir -p "${PLIST_DIR}" "${ROOT_DIR}/logs"
    cat > "${PLIST_FILE}" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.github-dashboard.daily</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${ROOT_DIR}/scripts/run_daily.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>${SCHED_HOUR}</integer>
    <key>Minute</key><integer>${SCHED_MIN}</integer>
  </dict>
  <key>WorkingDirectory</key><string>${ROOT_DIR}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key><string>${HOME}</string>
    <key>PATH</key><string>${ROOT_DIR}/.venv/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>StandardOutPath</key><string>${ROOT_DIR}/logs/launchd.log</string>
  <key>StandardErrorPath</key><string>${ROOT_DIR}/logs/launchd.err.log</string>
</dict>
</plist>
PLISTEOF
    launchctl unload "${PLIST_FILE}" 2>/dev/null || true
    launchctl load "${PLIST_FILE}"
    success "launchd agent loaded — runs at ${SCHEDULE_TIME} (system local time)"
    warn "Set macOS timezone: System Settings → General → Date & Time → Asia/Seoul"

  elif [[ "${SCHEDULER}" == "systemd" ]]; then
    # Use tee + ${SUDO} so redirects work when running as non-root with sudo.
    cat <<SVCEOF | ${SUDO} tee /etc/systemd/system/github-dashboard.service >/dev/null
[Unit]
Description=GitHub Stars Dashboard Daily Builder
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=${APP_USER}
WorkingDirectory=${ROOT_DIR}
EnvironmentFile=${ROOT_DIR}/.env
Environment=HOME=/home/${APP_USER}
Environment=PATH=${ROOT_DIR}/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/bin/bash ${ROOT_DIR}/scripts/run_daily.sh
StandardOutput=journal
StandardError=journal
SVCEOF

    cat <<TMREOF | ${SUDO} tee /etc/systemd/system/github-dashboard.timer >/dev/null
[Unit]
Description=GitHub Stars Dashboard daily at ${SCHEDULE_TIME} KST

[Timer]
OnCalendar=*-*-* ${SCHED_HOUR}:${SCHED_MIN}:00 Asia/Seoul
Persistent=true
Unit=github-dashboard.service

[Install]
WantedBy=timers.target
TMREOF

    ${SUDO} systemctl daemon-reload
    ${SUDO} systemctl enable github-dashboard.timer
    ${SUDO} systemctl start github-dashboard.timer
    success "systemd timer enabled — runs at ${SCHEDULE_TIME} KST daily"

  elif [[ "${SCHEDULER}" == "cron" ]]; then
    local CRON_LINE="${SCHED_MIN} ${SCHED_HOUR} * * * cd ${ROOT_DIR} && /bin/bash scripts/run_daily.sh >> logs/cron.log 2>&1"
    (crontab -l 2>/dev/null | grep -v "run_daily.sh"; echo "${CRON_LINE}") | crontab -
    success "Cron job installed: ${SCHED_MIN} ${SCHED_HOUR} * * * (system local time)"
    warn "Ensure system timezone is set to Asia/Seoul for KST scheduling"

  else
    warn "Scheduler setup skipped. Configure manually when ready:"
    echo "  cron    : ${SCHED_MIN} ${SCHED_HOUR} * * * cd ${ROOT_DIR} && bash scripts/run_daily.sh"
    echo "  systemd : see scripts/bootstrap_server.sh for service/timer templates"
    echo "  launchd : see plist template in deploy.sh (install_scheduler function)"
  fi
}

show_scheduler_status() {
  echo ""
  info "Scheduler registration result:"
  case "${SCHEDULER}" in
    systemd)
      echo "  ▸ systemctl list-timers github-dashboard.timer:"
      systemctl list-timers github-dashboard.timer --no-pager 2>/dev/null \
        | sed 's/^/    /' \
        || warn "    Cannot read timer status (no systemctl or not registered)"
      echo ""
      echo "  ▸ systemctl is-enabled / is-active:"
      printf "    enabled : %s\n" "$(systemctl is-enabled github-dashboard.timer 2>/dev/null || echo 'unknown')"
      printf "    active  : %s\n" "$(systemctl is-active  github-dashboard.timer 2>/dev/null || echo 'unknown')"
      echo "  ▸ Inspect later : systemctl status github-dashboard.timer"
      echo "  ▸ Logs          : journalctl -u github-dashboard.service -n 100"
      ;;
    cron)
      echo "  ▸ crontab entries matching 'run_daily.sh':"
      crontab -l 2>/dev/null | grep --color=never "run_daily.sh" \
        | sed 's/^/    /' \
        || warn "    No matching crontab entry found"
      echo "  ▸ Inspect later : crontab -l"
      echo "  ▸ Logs          : tail -f ${ROOT_DIR}/logs/cron.log"
      ;;
    launchd)
      echo "  ▸ launchctl list (filter: github-dashboard):"
      local _ll
      _ll=$(launchctl list 2>/dev/null | grep --color=never "github-dashboard" || true)
      if [ -n "${_ll}" ]; then
        echo "${_ll}" | sed 's/^/    /'
      else
        warn "    No matching launchctl entry found"
      fi
      [ -n "${PLIST_FILE}" ] && [ -f "${PLIST_FILE}" ] && \
        echo "  ▸ plist file   : ${PLIST_FILE}"
      echo "  ▸ Inspect later : launchctl list | grep github-dashboard"
      echo "  ▸ Logs          : tail -f ${ROOT_DIR}/logs/launchd.log"
      ;;
    skip)
      echo "  Scheduler skipped — register manually later via: deploy.sh --schedule HH:MM"
      ;;
    *)
      warn "  Unknown scheduler type: ${SCHEDULER}"
      ;;
  esac
  echo ""
}

# ─── Schedule-only mode (--schedule HH:MM [type]) ────────────────────────────
# Skips packages/auth/git steps. Reuses .env for APP_USER/ROOT_DIR context.
if [ "${SCHEDULE_ONLY}" -eq 1 ]; then
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "   GitHub Stars Dashboard — Schedule-only mode"
  echo "═══════════════════════════════════════════════════════"
  echo ""

  if [ ! -f "${ROOT_DIR}/.env" ]; then
    err ".env not found at ${ROOT_DIR}/.env — run full 'deploy.sh' first"
    exit 1
  fi
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  APP_USER="${APP_USER:-${USER:-ubuntu}}"
  SCHEDULE_TIME="${SCHEDULE_ONLY_TIME}"

  if [ -n "${SCHEDULE_ONLY_TYPE}" ]; then
    SCHEDULER="${SCHEDULE_ONLY_TYPE}"
  else
    if [[ "${OS_ID}" == "darwin" ]]; then
      _OPT1="launchd"; _OPT1_DESC="launchd (macOS LaunchAgent, recommended)"
      _OPT2="cron";    _OPT2_DESC="cron"
    else
      _OPT1="systemd"; _OPT1_DESC="systemd timer (recommended, requires root)"
      _OPT2="cron";    _OPT2_DESC="cron (no root required)"
    fi
    echo "  Scheduler type:"
    echo "    1) ${_OPT1_DESC}  [default]"
    echo "    2) ${_OPT2_DESC}"
    echo "    3) Skip"
    read -rp "  Choose [1/2/3, default: 1]: " _SCHED_CHOICE || true
    case "${_SCHED_CHOICE:-1}" in
      2) SCHEDULER="cron" ;;
      3) SCHEDULER="skip" ;;
      *) SCHEDULER="${_OPT1}" ;;
    esac
  fi

  info "Schedule    : ${SCHEDULE_TIME} (KST)"
  info "Scheduler   : ${SCHEDULER}"
  info "App user    : ${APP_USER}"
  info "Root dir    : ${ROOT_DIR}"

  # Persist new schedule time to .env (replace SCHEDULE_TIME line)
  if grep -q '^SCHEDULE_TIME=' "${ROOT_DIR}/.env"; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' "s|^SCHEDULE_TIME=.*|SCHEDULE_TIME=${SCHEDULE_TIME}|" "${ROOT_DIR}/.env"
    else
      sed -i "s|^SCHEDULE_TIME=.*|SCHEDULE_TIME=${SCHEDULE_TIME}|" "${ROOT_DIR}/.env"
    fi
  else
    echo "SCHEDULE_TIME=${SCHEDULE_TIME}" >> "${ROOT_DIR}/.env"
  fi
  success ".env SCHEDULE_TIME updated → ${SCHEDULE_TIME}"

  install_scheduler
  show_scheduler_status
  echo "═══════════════════════════════════════════════════════"
  success "Schedule-only setup complete."
  echo "═══════════════════════════════════════════════════════"
  exit 0
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "   GitHub Stars Dashboard — Deployment Setup"
echo "═══════════════════════════════════════════════════════"
echo ""

# ─── Step 1: Collect user inputs ─────────────────────────────────────────────
# Load existing .env as defaults if present
_ENV_FILE="${ROOT_DIR}/.env"
_D_SOURCE_ACCOUNT=""; _D_DEPLOY_ACCOUNT=""; _D_DEPLOY_REPO=""
_D_SCHEDULE_TIME="02:00"; _D_CLAUDE_MODEL="claude-sonnet-4-6"; _D_APP_USER="${USER:-ubuntu}"
if [ -f "${_ENV_FILE}" ]; then
  info "Found existing .env — using as defaults"
  # shellcheck disable=SC1090
  _D_SOURCE_ACCOUNT=$(grep -E '^SOURCE_ACCOUNT=' "${_ENV_FILE}" | cut -d= -f2- | tr -d '"' || true)
  _D_DEPLOY_ACCOUNT=$(grep -E '^DEPLOY_ACCOUNT=' "${_ENV_FILE}" | cut -d= -f2- | tr -d '"' || true)
  _D_DEPLOY_REPO=$(grep -E '^DEPLOY_REPO=' "${_ENV_FILE}" | cut -d= -f2- | tr -d '"' || true)
  _D_SCHEDULE_TIME=$(grep -E '^SCHEDULE_TIME=' "${_ENV_FILE}" | cut -d= -f2- | tr -d '"' || echo "02:00")
  _D_CLAUDE_MODEL=$(grep -E '^CLAUDE_MODEL=' "${_ENV_FILE}" | cut -d= -f2- | tr -d '"' || echo "claude-sonnet-4-6")
  _D_APP_USER=$(grep -E '^APP_USER=' "${_ENV_FILE}" | cut -d= -f2- | tr -d '"' || echo "${USER:-ubuntu}")
fi

info "Collecting configuration (press Enter to accept defaults)"
echo ""

read -rp "  Source GitHub account (code repo owner)      [${_D_SOURCE_ACCOUNT}]: " SOURCE_ACCOUNT || true
SOURCE_ACCOUNT="${SOURCE_ACCOUNT:-${_D_SOURCE_ACCOUNT}}"
read -rp "  Deploy GitHub account (GitHub Pages owner)   [${_D_DEPLOY_ACCOUNT}]: " DEPLOY_ACCOUNT || true
DEPLOY_ACCOUNT="${DEPLOY_ACCOUNT:-${_D_DEPLOY_ACCOUNT}}"
read -rp "  Deploy repo name                              [${_D_DEPLOY_REPO}]: " DEPLOY_REPO || true
DEPLOY_REPO="${DEPLOY_REPO:-${_D_DEPLOY_REPO}}"
read -rp "  Scheduler time KST, HH:MM                    [${_D_SCHEDULE_TIME}]: " SCHEDULE_TIME || true
SCHEDULE_TIME="${SCHEDULE_TIME:-${_D_SCHEDULE_TIME}}"
read -rp "  Claude model                                  [${_D_CLAUDE_MODEL}]: " CLAUDE_MODEL || true
CLAUDE_MODEL="${CLAUDE_MODEL:-${_D_CLAUDE_MODEL}}"
read -rp "  App user                                      [${_D_APP_USER}]: " APP_USER || true
APP_USER="${APP_USER:-${_D_APP_USER}}"

# Scheduler selection
if [[ "${OS_ID}" == "darwin" ]]; then
  _OPT1="launchd"; _OPT1_DESC="launchd (macOS LaunchAgent, recommended)"
  _OPT2="cron";    _OPT2_DESC="cron"
else
  _OPT1="systemd"; _OPT1_DESC="systemd timer (recommended, requires root)"
  _OPT2="cron";    _OPT2_DESC="cron (no root required)"
fi
echo ""
echo "  Scheduler:"
echo "    1) ${_OPT1_DESC}  [default]"
echo "    2) ${_OPT2_DESC}"
echo "    3) Skip (configure manually later)"
read -rp "  Choose [1/2/3, default: 1]: " _SCHED_CHOICE || true
case "${_SCHED_CHOICE:-1}" in
  2) SCHEDULER="cron" ;;
  3) SCHEDULER="skip" ;;
  *) SCHEDULER="${_OPT1}" ;;
esac

# Pre-check gh auth for summary accuracy
_GH_LOGGED_IN=$(gh auth status 2>&1 | grep -oE "account [^ ]+" | awk '{print $2}' | tr '\n' ' ' | xargs 2>/dev/null || true)
if echo "${_GH_LOGGED_IN}" | grep -qwF "${DEPLOY_ACCOUNT}" 2>/dev/null; then
  _GH_AUTH_SUMMARY="already authenticated as ${DEPLOY_ACCOUNT}"
elif [ -n "${_GH_LOGGED_IN}" ]; then
  _GH_AUTH_SUMMARY="logged in as ${_GH_LOGGED_IN}— will add ${DEPLOY_ACCOUNT}"
else
  _GH_AUTH_SUMMARY="'gh auth login' will run for ${DEPLOY_ACCOUNT}"
fi

echo ""
info "Summary:"
echo "  Source account    : ${SOURCE_ACCOUNT}"
echo "  Deploy account    : ${DEPLOY_ACCOUNT}"
echo "  Deploy repo       : ${DEPLOY_REPO}"
echo "  Schedule (KST)    : ${SCHEDULE_TIME}"
echo "  Scheduler         : ${SCHEDULER}"
echo "  Claude model      : ${CLAUDE_MODEL}"
echo "  GitHub auth       : ${_GH_AUTH_SUMMARY}"
echo "  Claude auth       : 'claude login' (will prompt unless already logged in)"
echo "  App user          : ${APP_USER}"
echo ""
read -rp "  Proceed? [Y/n]: " CONFIRM || true
CONFIRM="${CONFIRM:-Y}"
if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
  err "Aborted."
  exit 1
fi

# ─── Step 2: Write .env ───────────────────────────────────────────────────────
info "Writing .env"
cat > "${ROOT_DIR}/.env" <<EOF
# GitHub Stars Dashboard environment variables
# Generated by deploy.sh on $(date '+%Y-%m-%d %H:%M:%S')

CLAUDE_MODEL=${CLAUDE_MODEL}
SOURCE_ACCOUNT=${SOURCE_ACCOUNT}
DEPLOY_ACCOUNT=${DEPLOY_ACCOUNT}
DEPLOY_REPO=${DEPLOY_REPO}
SCHEDULE_TIME=${SCHEDULE_TIME}
APP_USER=${APP_USER}
GIT_USER_NAME=dashboard-bot
GIT_USER_EMAIL=dashboard-bot@users.noreply.github.com
EOF
chmod 600 "${ROOT_DIR}/.env"
success ".env written (permissions 600)"

# ─── Step 3: Check / install system packages ─────────────────────────────────
info "Checking required system packages"

check_or_install() {
  local cmd="$1"; local pkg="${2:-$1}"
  if command -v "${cmd}" &>/dev/null; then
    success "${cmd} already installed"
  else
    warn "${cmd} not found — installing ${pkg}..."
    pkg_install "${pkg}"
  fi
}

info "OS: ${OS_ID} ${OS_VERSION_ID}"
check_or_install git
check_or_install python3

case "${OS_ID}" in
  ubuntu|debian) check_or_install pip3 python3-pip; pkg_install python3-venv; check_or_install pandoc ;;
  ol|rhel|centos)
    # EPEL needed for pandoc on Oracle/RHEL
    sudo dnf install -y epel-release >/dev/null 2>&1 || true
    check_or_install pip3 python3-pip; check_or_install pandoc ;;
  amzn) check_or_install pip3 python3-pip; check_or_install pandoc ;;
  *) check_or_install pip3 python3-pip; check_or_install pandoc ;;
esac

# GitHub CLI (gh)
# macOS: check via Homebrew (not PATH) — bundled gh binaries from other apps can pollute PATH
if [[ "${OS_ID}" == "darwin" ]]; then
  if ! brew list --formula gh &>/dev/null; then
    warn "gh not installed via Homebrew — installing..."
    brew install gh
    success "gh CLI installed via Homebrew ($(gh --version | head -1))"
  else
    success "gh already installed via Homebrew ($(gh --version | head -1))"
  fi
else
  if ! command -v gh &>/dev/null; then
    warn "gh not found — installing GitHub CLI..."
    case "${OS_ID}" in
      ubuntu|debian)
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
          | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
          | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
        sudo apt-get update -q && sudo apt-get install -y gh >/dev/null ;;
      ol|rhel|centos|amzn)
        sudo dnf install -y 'dnf-command(config-manager)' >/dev/null 2>&1 || true
        sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo >/dev/null
        pkg_install gh ;;
      *)
        err "Cannot auto-install gh — install manually: https://cli.github.com" ;;
    esac
    success "gh CLI installed ($(gh --version | head -1))"
  else
    success "gh already installed ($(gh --version | head -1))"
  fi
fi

# Node.js for Claude CLI
if ! command -v node &>/dev/null; then
  warn "Node.js not found — installing..."
  case "${OS_ID}" in
    darwin)
      brew install node >/dev/null ;;
    ubuntu|debian)
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - >/dev/null
      sudo apt-get install -y nodejs >/dev/null ;;
    ol|rhel|centos)
      sudo dnf module enable nodejs:20 -y >/dev/null 2>&1 || true
      pkg_install nodejs ;;
    amzn)
      pkg_install nodejs ;;
    *)
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - >/dev/null
      sudo apt-get install -y nodejs >/dev/null ;;
  esac
  success "Node.js installed"
else
  success "Node.js already installed ($(node --version))"
fi

# ─── Step 4: Install Claude Code CLI ─────────────────────────────────────────
info "Installing Claude Code CLI"
if command -v claude &>/dev/null; then
  success "claude CLI already installed ($(claude --version 2>/dev/null || echo 'version unknown'))"
else
  sudo npm install -g @anthropic-ai/claude-code >/dev/null
  success "claude CLI installed"
fi

# Login to Claude via OAuth (claude login opens the full TUI)
info "Claude Code authentication"
read -rp "  Already logged in to Claude Code? Skip login? [y/N]: " _CLAUDE_SKIP || true
if [[ "${_CLAUDE_SKIP:-N}" =~ ^[Yy]$ ]]; then
  success "Claude login skipped (already authenticated)"
else
  echo "  Running 'claude login' — opens Claude Code TUI."
  echo "  Headless server: use the URL shown, authenticate, paste the token back."
  claude login
  success "Claude login complete"
fi

# ─── Step 5: Authenticate GitHub CLI (must be as DEPLOY_ACCOUNT) ─────────────
_GH_ACCTS=$(gh auth status 2>&1 | grep -oE "account [^ ]+" | awk '{print $2}' | tr '\n' ' ' | xargs 2>/dev/null || true)
if echo "${_GH_ACCTS}" | grep -qwF "${DEPLOY_ACCOUNT}" 2>/dev/null; then
  success "GitHub CLI authenticated as deploy account (${DEPLOY_ACCOUNT})"
else
  if [ -n "${_GH_ACCTS}" ]; then
    warn "Authenticated as: ${_GH_ACCTS}"
    info "Deploy account ${DEPLOY_ACCOUNT} not authenticated — logging in"
  else
    info "Authenticating GitHub CLI as deploy account: ${DEPLOY_ACCOUNT}"
  fi
  echo "  Log in as ${DEPLOY_ACCOUNT} (push access to github.com/${DEPLOY_ACCOUNT}/${DEPLOY_REPO})"
  gh auth login
  success "GitHub CLI authenticated for ${DEPLOY_ACCOUNT}"
fi
gh auth setup-git

# ─── Step 6: Verify / create deploy repo ─────────────────────────────────────
info "Checking deploy repository: ${DEPLOY_ACCOUNT}/${DEPLOY_REPO}"
if gh repo view "${DEPLOY_ACCOUNT}/${DEPLOY_REPO}" &>/dev/null; then
  success "Repo ${DEPLOY_ACCOUNT}/${DEPLOY_REPO} exists"
else
  warn "Repo ${DEPLOY_ACCOUNT}/${DEPLOY_REPO} not found — creating..."
  gh repo create "${DEPLOY_ACCOUNT}/${DEPLOY_REPO}" --public \
    --description "GitHub Stars Dashboard — automated daily snapshot"
  success "Repo created: https://github.com/${DEPLOY_ACCOUNT}/${DEPLOY_REPO}"
fi

# ─── Step 7: Deploy Claude skills ────────────────────────────────────────────
info "Deploying Claude skills"
LOCAL_CMDS="${ROOT_DIR}/.claude/commands"
GLOBAL_CMDS="${HOME}/.claude/commands"

# If the analysis skills already exist globally, skip installation
# (analysis-source is no longer used by the pipeline; only these two are required)
if ls "${GLOBAL_CMDS}/in-depth-review.md" \
      "${GLOBAL_CMDS}/create-guide4junior.md" &>/dev/null 2>&1; then
  success "Claude skills already in ${GLOBAL_CMDS} — skipping"
else
  # Install to global commands dir so skills are available in any repo context
  mkdir -p "${GLOBAL_CMDS}"
  if ls "${LOCAL_CMDS}"/*.md &>/dev/null 2>&1; then
    cp "${LOCAL_CMDS}"/*.md "${GLOBAL_CMDS}/"
    success "Claude skills installed → ${GLOBAL_CMDS}"
  else
    warn "No skill .md files found in ${LOCAL_CMDS}"
  fi
fi

# ─── Step 8: Python venv + dependencies ──────────────────────────────────────
info "Setting up Python virtual environment"
python3 -m venv --upgrade-deps "${ROOT_DIR}/.venv"
# Use the venv's own pip explicitly — never rely on PATH (a pipless venv would
# otherwise fall through to system pip3 and hit PEP 668 externally-managed).
VENV_PIP="${ROOT_DIR}/.venv/bin/pip"
[ -x "${VENV_PIP}" ] || { err "venv has no pip — install python3-venv and re-run."; exit 1; }
"${VENV_PIP}" install --upgrade pip -q
"${VENV_PIP}" install -r "${ROOT_DIR}/requirements.txt" -q
success "Python venv ready at ${ROOT_DIR}/.venv"

# ─── Step 9: Configure git remotes ───────────────────────────────────────────
# origin = source repo (pull script updates)
# deploy = deploy repo (push generated site/ only)
info "Configuring git remotes"
SOURCE_URL="https://github.com/${SOURCE_ACCOUNT}/dashboard-for-github-stars.git"
DEPLOY_URL="https://github.com/${DEPLOY_ACCOUNT}/${DEPLOY_REPO}.git"

# Initialize git repo if this directory is not one yet
if ! git -C "${ROOT_DIR}" rev-parse --git-dir &>/dev/null 2>&1; then
  info "Initializing git repository..."
  git -C "${ROOT_DIR}" init
  git -C "${ROOT_DIR}" checkout -b main 2>/dev/null || true
  git -C "${ROOT_DIR}" add -A
  git -C "${ROOT_DIR}" -c user.name="dashboard-bot" \
    -c user.email="dashboard-bot@users.noreply.github.com" \
    commit -m "chore: initial commit"
  success "Git repository initialized"
fi

# origin → source repo (for pulling script updates)
if git -C "${ROOT_DIR}" remote get-url origin &>/dev/null; then
  git -C "${ROOT_DIR}" remote set-url origin "${SOURCE_URL}"
else
  git -C "${ROOT_DIR}" remote add origin "${SOURCE_URL}"
fi

# deploy → GitHub Pages repo (run_daily.sh pushes site/ here)
if git -C "${ROOT_DIR}" remote get-url deploy &>/dev/null; then
  git -C "${ROOT_DIR}" remote set-url deploy "${DEPLOY_URL}"
else
  git -C "${ROOT_DIR}" remote add deploy "${DEPLOY_URL}"
fi

git -C "${ROOT_DIR}" config user.name "dashboard-bot"
git -C "${ROOT_DIR}" config user.email "dashboard-bot@users.noreply.github.com"
success "git origin → ${SOURCE_URL}"
success "git deploy → ${DEPLOY_URL}"

# ─── Step 10: Install scheduler ──────────────────────────────────────────────
install_scheduler
show_scheduler_status

# ─── Step 11: Make scripts executable ───────────────────────────────────────
info "Setting script permissions"
chmod +x "${ROOT_DIR}/scripts/"*.sh "${ROOT_DIR}/deploy.sh"
success "Scripts are executable"

# ─── Step 12: Optional first run ─────────────────────────────────────────────
echo ""
read -rp "  Run the pipeline now (first test)? [Y/n]: " RUN_NOW || true
RUN_NOW="${RUN_NOW:-Y}"
if [[ "${RUN_NOW}" =~ ^[Yy]$ ]]; then
  info "Running pipeline now..."
  source "${ROOT_DIR}/.env" 2>/dev/null || true
  bash "${ROOT_DIR}/scripts/run_daily.sh"
  success "First run complete. Check ${ROOT_DIR}/site/index.html"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
success "Deployment setup complete!"
echo ""
echo "  Dashboard URL    : https://${DEPLOY_ACCOUNT}.github.io/${DEPLOY_REPO}/"
echo "  Schedule         : ${SCHEDULE_TIME} KST daily"
echo "  Manual run       : bash ${ROOT_DIR}/scripts/run_daily.sh"
echo "  Logs             : ${ROOT_DIR}/logs/"
if command -v systemctl &>/dev/null && systemctl is-active github-dashboard.timer &>/dev/null 2>&1; then
  echo "  Timer status     : systemctl list-timers --all | grep github"
fi
echo "═══════════════════════════════════════════════════════"
echo ""
