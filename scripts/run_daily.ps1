#Requires -Version 7.0
# Daily orchestrator for Windows.
# Pipeline: pull source → backup → collect → select targets → build → analyze → deploy.
# Exit code 42 from run_claude_analysis.ps1 = Claude usage limit reached → stops here.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$CLAUDE_LIMIT_EXIT = 42

$RootDir    = Split-Path -Parent $PSScriptRoot
$VenvPython = "$RootDir\.venv\Scripts\python.exe"
$LogDir     = "$RootDir\logs"
$LogFile    = "$LogDir\run_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$EnvFile    = "$RootDir\.env"

New-Item -ItemType Directory -Path $LogDir, "$RootDir\site\assets", "$RootDir\site\analysis" -Force | Out-Null

Start-Transcript -Path $LogFile -Append | Out-Null

# Load .env into process scope
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^([A-Z_][A-Z0-9_]*)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
        }
    }
}

$SourceAccount = $env:SOURCE_ACCOUNT
$DeployAccount = $env:DEPLOY_ACCOUNT
$DeployRepo    = $env:DEPLOY_REPO

Write-Host "========================================"
Write-Host "[run_daily] Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "========================================"

# ─── Helpers ──────────────────────────────────────────────────────────────────
function Get-ActiveGhAccount {
    $status = (gh auth status 2>&1 | Out-String)
    if ($status -match 'Active account: true[\s\S]*?account ([^\s\)]+)') {
        return $matches[1].Trim('()')
    }
    return $null
}

function Get-AccountToken {
    # Returns token for $Account by switching gh active account if needed
    param([string]$Account)
    if (-not $Account) { return $null }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return $null }

    $active = Get-ActiveGhAccount
    $token  = $null
    if ($active -eq $Account) {
        $token = (gh auth token 2>$null)
    } elseif ((gh auth status 2>&1 | Out-String) -match [regex]::Escape($Account)) {
        gh auth switch -u $Account 2>$null | Out-Null
        $token = (gh auth token 2>$null)
        if ($active) { gh auth switch -u $active 2>$null | Out-Null }
    }
    if ($token) { return $token.Trim() }
    return $null
}

# ─── 1. Pull latest source ────────────────────────────────────────────────────
Write-Host "`n[1/7] Pull latest source"
$pullToken = Get-AccountToken -Account $SourceAccount
if (-not $SourceAccount) {
    Write-Host "  SOURCE_ACCOUNT not set — skipping pull"
} elseif (-not $pullToken) {
    Write-Host "  SOURCE_ACCOUNT ($SourceAccount) not authenticated — skipping pull"
} else {
    git -C $RootDir remote get-url origin 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  No remote origin — skipping pull"
    } else {
        Write-Host "  Pulling origin main as $SourceAccount..."
        $authHeader = "AUTHORIZATION: bearer $pullToken"
        $env:GIT_TERMINAL_PROMPT = "0"
        git -C $RootDir -c "http.extraheader=$authHeader" pull --rebase origin main 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  git pull failed — continuing with local source"
        }
        Remove-Item Env:GIT_TERMINAL_PROMPT -ErrorAction SilentlyContinue
    }
}

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
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $ghToken = gh auth token 2>$null
    if ($ghToken) { $env:GITHUB_TOKEN = $ghToken.Trim() }
}
& $VenvPython "$RootDir\scripts\collect_data.py"

# ─── 4. Select analysis targets ──────────────────────────────────────────────
Write-Host "`n[4/7] Select analysis targets"
& $VenvPython "$RootDir\scripts\select_analysis_targets.py"

# ─── 5. Build static dashboard ───────────────────────────────────────────────
Write-Host "`n[5/7] Build static dashboard"
& $VenvPython "$RootDir\scripts\build_dashboard.py"

# ─── 6. Run Claude analysis (handle exit 42 = usage limit) ───────────────────
Write-Host "`n[6/7] Run Claude analysis"
if (Get-Command claude -ErrorAction SilentlyContinue) {
    & powershell -ExecutionPolicy Bypass -File "$RootDir\scripts\run_claude_analysis.ps1"
    $analysisRc = $LASTEXITCODE
    if ($analysisRc -eq $CLAUDE_LIMIT_EXIT) {
        Write-Host "  [FATAL] Claude usage limit reached — stopping run_daily.ps1" -ForegroundColor Red
        Stop-Transcript | Out-Null
        exit $CLAUDE_LIMIT_EXIT
    } elseif ($analysisRc -ne 0) {
        Write-Warning "  Analysis step failed (rc=$analysisRc, non-fatal), continuing"
    }
    # Rebuild to pick up new analysis links (even if partial)
    & $VenvPython "$RootDir\scripts\build_dashboard.py"
} else {
    Write-Host "  claude CLI not found, skipping analysis"
}

# ─── 7. Deploy site/ to GitHub Pages repo (separate clone, preserve analyses) ─
Write-Host "`n[7/7] Deploy site/ to GitHub Pages"

if (-not $DeployAccount -or -not $DeployRepo) {
    Write-Host "  DEPLOY_ACCOUNT or DEPLOY_REPO not set — skipping deploy"
    Write-Host "`n[run_daily] Done: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Stop-Transcript | Out-Null
    exit 0
}

# Ensure DEPLOY_ACCOUNT is active gh session for push
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $deployActive = Get-ActiveGhAccount
    if ($deployActive -ne $DeployAccount) {
        Write-Host "  Switching gh to DEPLOY_ACCOUNT ($DeployAccount) for push..."
        gh auth switch -u $DeployAccount 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  Could not switch to $DeployAccount — push may fail"
        }
    } else {
        Write-Host "  Active gh account: $DeployAccount [OK]"
    }
}

$deployUrl = "https://github.com/$DeployAccount/$DeployRepo.git"
$deployTmp = "$env:TEMP\github-dashboard-deploy\$DeployRepo"
New-Item -ItemType Directory -Path (Split-Path -Parent $deployTmp) -Force | Out-Null

if (Test-Path "$deployTmp\.git") {
    Write-Host "  Updating existing deploy clone..."
    git -C $deployTmp pull --rebase 2>&1 | Out-Null
} else {
    Write-Host "  Cloning deploy repo: $deployUrl"
    git clone $deployUrl $deployTmp 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Clone failed — initializing empty deploy repo"
        if (Test-Path $deployTmp) { Remove-Item -Recurse -Force $deployTmp }
        New-Item -ItemType Directory -Path $deployTmp -Force | Out-Null
        git -C $deployTmp init
        git -C $deployTmp checkout -b main 2>$null
        git -C $deployTmp remote add origin $deployUrl
    }
}

# Preserve historical analysis/*.html — copy back files not regenerated today
if (Test-Path "$deployTmp\analysis") {
    New-Item -ItemType Directory -Path "$RootDir\site\analysis" -Force | Out-Null
    $preserved = 0
    Get-ChildItem "$deployTmp\analysis\*.html" -ErrorAction SilentlyContinue | ForEach-Object {
        $localPath = Join-Path "$RootDir\site\analysis" $_.Name
        if (-not (Test-Path $localPath)) {
            Copy-Item $_.FullName $localPath -Force
            $preserved++
        }
    }
    if ($preserved -gt 0) {
        Write-Host "  Preserved $preserved existing analysis HTMLs from deploy repo"
    }
}

# Wipe deploy contents (except .git) and copy fresh site/
Get-ChildItem $deployTmp -Force | Where-Object { $_.Name -ne '.git' } | ForEach-Object {
    Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue
}
Copy-Item "$RootDir\site\*" $deployTmp -Recurse -Force

# Configure git identity for the deploy clone
$gitName  = if ($env:GIT_USER_NAME)  { $env:GIT_USER_NAME }  else { "dashboard-bot" }
$gitEmail = if ($env:GIT_USER_EMAIL) { $env:GIT_USER_EMAIL } else { "dashboard-bot@users.noreply.github.com" }
git -C $deployTmp config user.name  $gitName
git -C $deployTmp config user.email $gitEmail
git -C $deployTmp add .

git -C $deployTmp diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Nothing to deploy (site/ unchanged)"
} else {
    $commitMsg = "chore: daily dashboard update $(Get-Date -Format 'yyyy-MM-dd HH:mm') KST"
    git -C $deployTmp commit -m $commitMsg
    git -C $deployTmp push -u origin main 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  Push failed — check: gh auth status, access to $DeployAccount/$DeployRepo"
    } else {
        Write-Host "  Deployed → https://github.com/$DeployAccount/$DeployRepo"
        Write-Host "  Pages   → https://$DeployAccount.github.io/$DeployRepo/"
    }
}

Write-Host "`n[run_daily] Done: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Stop-Transcript | Out-Null
