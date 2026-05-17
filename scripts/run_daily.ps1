#Requires -Version 5.1
# Daily orchestrator for Windows: collect -> compare -> build -> analyze -> push
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot  # repo root (parent of scripts/)
$VenvPython = "$RootDir\.venv\Scripts\python.exe"
$LogDir  = "$RootDir\logs"
$LogFile = "$LogDir\run_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

New-Item -ItemType Directory -Path $LogDir, "$RootDir\site\assets", "$RootDir\site\analysis" -Force | Out-Null

# Tee output to log file
Start-Transcript -Path $LogFile -Append | Out-Null

Write-Host "========================================"
Write-Host "[run_daily] Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "========================================"

# ─── 1. Pull latest source ────────────────────────────────────────────────────
Write-Host "`n[1/7] Pull latest source"
try { git -C $RootDir pull --rebase origin main }
catch { Write-Warning "git pull failed (offline?), continuing with local source" }

# ─── 2. Backup previous data ─────────────────────────────────────────────────
Write-Host "`n[2/7] Backup previous data"
$dataJson = "$RootDir\site\assets\data.json"
if (Test-Path $dataJson) {
    Copy-Item $dataJson "$RootDir\site\assets\previous_data.json" -Force
    Write-Host "  Backed up data.json -> previous_data.json"
} else {
    Write-Host "  No previous data.json found"
}

# ─── 3. Collect GitHub data ───────────────────────────────────────────────────
Write-Host "`n[3/7] Collect GitHub data"
# Inject GitHub token from gh CLI for authenticated API calls
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $ghToken = gh auth token 2>$null
    if ($ghToken) { $env:GITHUB_TOKEN = $ghToken }
}
& $VenvPython "$RootDir\scripts\collect_data.py"

# ─── 4. Compare with previous ────────────────────────────────────────────────
Write-Host "`n[4/7] Compare with previous (find new trending)"
& $VenvPython "$RootDir\scripts\compare_with_previous.py"

# ─── 5. Build static dashboard ───────────────────────────────────────────────
Write-Host "`n[5/7] Build static dashboard"
& $VenvPython "$RootDir\scripts\build_dashboard.py"

# ─── 6. Run Claude analysis ───────────────────────────────────────────────────
Write-Host "`n[6/7] Run Claude analysis"
if (Get-Command claude -ErrorAction SilentlyContinue) {
    try {
        & "$RootDir\scripts\run_claude_analysis.ps1"
        # Rebuild to pick up new analysis links
        & $VenvPython "$RootDir\scripts\build_dashboard.py"
    } catch {
        Write-Warning "Analysis step failed (non-fatal): $_"
    }
} else {
    Write-Host "  claude CLI not found, skipping analysis"
}

# ─── 7. Commit and push ───────────────────────────────────────────────────────
Write-Host "`n[7/7] Commit and push"
git -C $RootDir add site/
$diffOutput = git -C $RootDir diff --cached --quiet 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Nothing to commit"
} else {
    $gitName  = if ($env:GIT_USER_NAME)  { $env:GIT_USER_NAME }  else { "dashboard-bot" }
    $gitEmail = if ($env:GIT_USER_EMAIL) { $env:GIT_USER_EMAIL } else { "dashboard-bot@users.noreply.github.com" }
    git -C $RootDir config user.name  $gitName
    git -C $RootDir config user.email $gitEmail
    $commitMsg = "chore: daily dashboard update $(Get-Date -Format 'yyyy-MM-dd HH:mm') KST"
    git -C $RootDir commit -m $commitMsg
    git -C $RootDir push origin main
    Write-Host "  Pushed to origin/main"
}

Write-Host "`n[run_daily] Done: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Stop-Transcript | Out-Null
