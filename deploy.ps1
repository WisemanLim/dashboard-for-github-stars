#Requires -Version 5.1
# deploy.ps1 — Interactive setup for GitHub Stars Dashboard on Windows.
#
# Usage:
#   .\deploy.ps1                           # full interactive setup
#   .\deploy.ps1 -ScheduleOnly 02:00       # schedule-only mode (reuses .env)
#   .\deploy.ps1 -h | -Help                # show usage
#
# Requirements: Windows 10 1709+ with winget, PowerShell 5.1+

[CmdletBinding()]
param(
    [string]$ScheduleOnly = "",
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Info    { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Success { param($msg) Write-Host "[OK]   $msg" -ForegroundColor Green }
function Warn    { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Err     { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

function Show-Usage {
    Write-Host @"
Usage: .\deploy.ps1 [options]

Options:
  -ScheduleOnly HH:MM   Schedule-only mode. Skips packages/auth.
                        Reuses .env. Updates SCHEDULE_TIME and re-registers task.
  -Help                 Show this help and exit.

Examples:
  .\deploy.ps1                       # full interactive setup
  .\deploy.ps1 -ScheduleOnly 02:00   # change schedule to 02:00 only
"@
}

if ($Help) { Show-Usage; exit 0 }

if ($ScheduleOnly -and -not ($ScheduleOnly -match '^\d{1,2}:\d{2}$')) {
    Err "-ScheduleOnly requires HH:MM format (e.g. 02:00)"
}

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $RootDir ".env"

# ─── Load .env defaults if present ───────────────────────────────────────────
function Read-EnvDefault {
    param([string]$Key, [string]$Default)
    if (-not (Test-Path $EnvFile)) { return $Default }
    $line = Select-String -Path $EnvFile -Pattern "^${Key}=" -SimpleMatch:$false |
            Select-Object -First 1
    if ($line) {
        $val = ($line.Line -replace "^${Key}=", "").Trim('"')
        if ($val) { return $val }
    }
    return $Default
}

$DefSourceAccount = Read-EnvDefault "SOURCE_ACCOUNT" ""
$DefDeployAccount = Read-EnvDefault "DEPLOY_ACCOUNT" ""
$DefDeployRepo    = Read-EnvDefault "DEPLOY_REPO" ""
$DefScheduleTime  = Read-EnvDefault "SCHEDULE_TIME" "02:00"
$DefClaudeModel   = Read-EnvDefault "CLAUDE_MODEL"  "claude-sonnet-4-6"

# ─── Scheduler functions (shared by full + schedule-only modes) ──────────────
$TaskName = "GitHubStarsDashboard"

function Install-Scheduler {
    param([string]$ScheduleTime)

    $parts   = $ScheduleTime -split ":"
    $hour    = [int]$parts[0]
    $min     = [int]$parts[1]
    $trigAt  = "{0:D2}:{1:D2}" -f $hour, $min
    $scriptPath = Join-Path $RootDir "scripts\run_daily.ps1"

    $action    = New-ScheduledTaskAction -Execute "powershell.exe" `
                     -Argument "-NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`"" `
                     -WorkingDirectory $RootDir
    $trigger   = New-ScheduledTaskTrigger -Daily -At $trigAt
    $settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
                     -RestartCount 1 -RestartInterval (New-TimeSpan -Minutes 10)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Force | Out-Null
    Success "Task Scheduler registered — daily at $ScheduleTime (system local time)"
    Warn "Set Windows timezone to (UTC+09:00) Seoul for KST scheduling"
}

function Show-SchedulerStatus {
    Write-Host ""
    Info "Scheduler registration result:"
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $task) {
        Warn "  Task '$TaskName' not found"
        return
    }
    Write-Host "  TaskName       : $($task.TaskName)"
    Write-Host "  State          : $($task.State)"
    $trig = $task.Triggers | Select-Object -First 1
    if ($trig) {
        Write-Host "  Trigger start  : $($trig.StartBoundary)"
        Write-Host "  Days interval  : $($trig.DaysInterval)"
    }
    $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($info) {
        Write-Host "  Last run time  : $($info.LastRunTime)"
        Write-Host "  Last result    : $($info.LastTaskResult)"
        Write-Host "  Next run time  : $($info.NextRunTime)"
    }
    Write-Host "  Inspect later  : Get-ScheduledTask -TaskName '$TaskName'"
    Write-Host "  Run now        : Start-ScheduledTask -TaskName '$TaskName'"
    Write-Host "  Disable        : Disable-ScheduledTask -TaskName '$TaskName'"
    Write-Host "  Remove         : Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
    Write-Host ""
}

function Set-EnvScheduleTime {
    param([string]$NewTime)
    if (-not (Test-Path $EnvFile)) {
        Err ".env not found at $EnvFile — run full deploy first"
    }
    $content = Get-Content $EnvFile -Raw
    if ($content -match "(?m)^SCHEDULE_TIME=") {
        $content = $content -replace "(?m)^SCHEDULE_TIME=.*$", "SCHEDULE_TIME=$NewTime"
    } else {
        $content += "`nSCHEDULE_TIME=$NewTime`n"
    }
    Set-Content -Path $EnvFile -Value $content -Encoding UTF8 -NoNewline
    Success ".env SCHEDULE_TIME updated → $NewTime"
}

# ─── Schedule-only mode ──────────────────────────────────────────────────────
if ($ScheduleOnly) {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor White
    Write-Host "   GitHub Stars Dashboard — Schedule-only mode"
    Write-Host "======================================================="
    Write-Host ""
    Info "Schedule time : $ScheduleOnly"
    Info "Root dir      : $RootDir"

    Set-EnvScheduleTime -NewTime $ScheduleOnly
    Install-Scheduler   -ScheduleTime $ScheduleOnly
    Show-SchedulerStatus

    Write-Host "=======================================================" -ForegroundColor White
    Success "Schedule-only setup complete."
    Write-Host "======================================================="
    exit 0
}

# ─── Full interactive setup ──────────────────────────────────────────────────
Write-Host ""
Write-Host "=======================================================" -ForegroundColor White
Write-Host "   GitHub Stars Dashboard — Windows Deployment Setup"
Write-Host "======================================================="
Write-Host ""

if (Test-Path $EnvFile) {
    Info "Found existing .env — using as defaults"
}

Info "Collecting configuration (press Enter to accept defaults)"
Write-Host ""

$SourceAccount  = Read-Host "  Source GitHub account (A)                       [$DefSourceAccount]"
if ([string]::IsNullOrWhiteSpace($SourceAccount)) { $SourceAccount = $DefSourceAccount }
$DeployAccount  = Read-Host "  Deploy GitHub account (B - GitHub Pages owner)  [$DefDeployAccount]"
if ([string]::IsNullOrWhiteSpace($DeployAccount)) { $DeployAccount = $DefDeployAccount }
$DeployRepo     = Read-Host "  Deploy repo name (in account B)                 [$DefDeployRepo]"
if ([string]::IsNullOrWhiteSpace($DeployRepo))    { $DeployRepo    = $DefDeployRepo }
$ScheduleTime   = Read-Host "  Scheduler time KST, HH:MM                       [$DefScheduleTime]"
if ([string]::IsNullOrWhiteSpace($ScheduleTime))  { $ScheduleTime  = $DefScheduleTime }
$ClaudeModel    = Read-Host "  Claude model                                    [$DefClaudeModel]"
if ([string]::IsNullOrWhiteSpace($ClaudeModel))   { $ClaudeModel   = $DefClaudeModel }

Write-Host ""
Info "Summary:"
Write-Host "  Source account (A) : $SourceAccount"
Write-Host "  Deploy account (B) : $DeployAccount"
Write-Host "  Deploy repo        : $DeployRepo"
Write-Host "  Schedule (KST)     : $ScheduleTime"
Write-Host "  Claude model       : $ClaudeModel"
Write-Host "  GitHub auth        : via 'gh auth login' (prompted after install)"
Write-Host "  Claude auth        : via 'claude login' (OAuth - prompted after install)"
Write-Host ""
$confirm = Read-Host "  Proceed? [Y/n]"
if ($confirm -notin @("", "Y", "y")) { Err "Aborted." }

# ─── Step 2: Write .env ───────────────────────────────────────────────────────
Info "Writing .env"
$envContent = @"
# GitHub Stars Dashboard environment variables
# Generated by deploy.ps1 on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

CLAUDE_MODEL=$ClaudeModel
SOURCE_ACCOUNT=$SourceAccount
DEPLOY_ACCOUNT=$DeployAccount
DEPLOY_REPO=$DeployRepo
SCHEDULE_TIME=$ScheduleTime
GIT_USER_NAME=dashboard-bot
GIT_USER_EMAIL=dashboard-bot@users.noreply.github.com
"@
Set-Content -Path $EnvFile -Value $envContent -Encoding UTF8
Success ".env written"

# ─── Step 3: Check / install packages via winget ─────────────────────────────
Info "Checking required packages (winget)"

function Install-WingetPkg {
    param($Id, $Name)
    $check = Get-Command $Name -ErrorAction SilentlyContinue
    if ($check) {
        Success "$Name already installed"
    } else {
        Warn "$Name not found — installing via winget..."
        winget install --id $Id --silent --accept-package-agreements --accept-source-agreements
        Success "$Name installed"
    }
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Err "winget not found. Install from https://aka.ms/getwinget or use Windows 11."
}

Install-WingetPkg "Git.Git"           "git"
Install-WingetPkg "Python.Python.3.12" "python"
Install-WingetPkg "GitHub.cli"        "gh"
Install-WingetPkg "OpenJS.NodeJS.LTS" "node"
Install-WingetPkg "JohnMacFarlane.Pandoc" "pandoc"

# Refresh PATH so newly installed tools are available
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")

# ─── Step 4: Install Claude Code CLI ─────────────────────────────────────────
Info "Installing Claude Code CLI"
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Success "claude already installed"
} else {
    npm install -g @anthropic-ai/claude-code
    Success "claude CLI installed"
}

$claudeSkip = Read-Host "  Already logged in to Claude Code? Skip login? [y/N]"
if ($claudeSkip -in @("Y","y")) {
    Success "Claude login skipped (already authenticated)"
} else {
    Info "Logging in to Claude (claude login) — follow the prompts"
    claude login
    Success "Claude login complete"
}

# ─── Step 5: Authenticate GitHub CLI ─────────────────────────────────────────
Info "Authenticating GitHub CLI (gh auth login)"
$ghStatus = (gh auth status 2>&1 | Out-String)
if ($ghStatus -match [regex]::Escape($DeployAccount)) {
    Success "gh already authenticated as $DeployAccount"
} else {
    Write-Host "  Log in as $DeployAccount (push access required)"
    gh auth login
}
gh auth setup-git
Success "GitHub CLI authenticated — git push will use gh credentials"

# ─── Step 6: Verify / create deploy repo ─────────────────────────────────────
Info "Checking deploy repository: $DeployAccount/$DeployRepo"
gh repo view "$DeployAccount/$DeployRepo" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Success "Repo $DeployAccount/$DeployRepo exists"
} else {
    Warn "Repo $DeployAccount/$DeployRepo not found — creating..."
    gh repo create "$DeployAccount/$DeployRepo" --public `
        --description "GitHub Stars Dashboard — automated daily snapshot"
    Success "Repo created: https://github.com/$DeployAccount/$DeployRepo"
}

# ─── Step 7: Deploy Claude skills ────────────────────────────────────────────
Info "Deploying Claude skills to .claude\commands\"
New-Item -ItemType Directory -Path "$RootDir\.claude\commands" -Force | Out-Null
$skills = Get-ChildItem "$RootDir\.claude\commands\*.md" -ErrorAction SilentlyContinue
if ($skills) { Success "Skills found in .claude\commands\" }
else { Warn "No skill files found in .claude\commands\" }

# ─── Step 8: Python venv + dependencies ──────────────────────────────────────
Info "Setting up Python virtual environment"
python -m venv "$RootDir\.venv"
& "$RootDir\.venv\Scripts\python.exe" -m pip install --upgrade pip -q
& "$RootDir\.venv\Scripts\pip.exe" install -r "$RootDir\requirements.txt" -q
Success "Python venv ready at $RootDir\.venv"

# ─── Step 9: Configure git remotes (origin = SOURCE, deploy = DEPLOY) ───────
Info "Configuring git remotes"
$sourceUrl = "https://github.com/$SourceAccount/dashboard-for-github-stars.git"
$deployUrl = "https://github.com/$DeployAccount/$DeployRepo.git"

git -C $RootDir rev-parse --git-dir 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Info "Initializing git repository..."
    git -C $RootDir init
    git -C $RootDir checkout -b main 2>$null
}

git -C $RootDir remote get-url origin 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { git -C $RootDir remote set-url origin $sourceUrl }
else                     { git -C $RootDir remote add origin $sourceUrl }

git -C $RootDir remote get-url deploy 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { git -C $RootDir remote set-url deploy $deployUrl }
else                     { git -C $RootDir remote add deploy $deployUrl }

git -C $RootDir config user.name  "dashboard-bot"
git -C $RootDir config user.email "dashboard-bot@users.noreply.github.com"
Success "git origin → $sourceUrl"
Success "git deploy → $deployUrl"

# ─── Step 10: Register Task Scheduler ────────────────────────────────────────
Info "Registering Windows Task Scheduler task"
Install-Scheduler -ScheduleTime $ScheduleTime
Show-SchedulerStatus

# ─── Step 11: Make scripts accessible ────────────────────────────────────────
Info "Setting PowerShell execution policy (CurrentUser)"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Success "Execution policy set to RemoteSigned"

# ─── Step 12: Optional first run ─────────────────────────────────────────────
Write-Host ""
$runNow = Read-Host "  Run the pipeline now (first test)? [Y/n]"
if ($runNow -in @("", "Y", "y")) {
    Info "Running pipeline now..."
    & "$RootDir\scripts\run_daily.ps1"
    Success "First run complete. Check $RootDir\site\index.html"
}

Write-Host ""
Write-Host "=======================================================" -ForegroundColor White
Success "Deployment setup complete!"
Write-Host ""
Write-Host "  Dashboard URL  : https://$DeployAccount.github.io/$DeployRepo/"
Write-Host "  Schedule       : $ScheduleTime daily (set timezone to KST)"
Write-Host "  Manual run     : .\scripts\run_daily.ps1"
Write-Host "  Logs           : $RootDir\logs\"
Write-Host "  Task status    : Get-ScheduledTask -TaskName '$TaskName'"
Write-Host "  Change schedule: .\deploy.ps1 -ScheduleOnly HH:MM"
Write-Host "======================================================="
Write-Host ""
