#Requires -Version 7.0
# Run Claude Code CLI skills on selected analysis targets (Windows version).
# Reads site/assets/analysis_targets.json (ordered: top100 → daily → weekly → monthly),
# clones each repo, runs 2 skills (in-depth-review + create-guide4junior),
# converts results to HTML, saves to site/analysis/{owner}_{name}.html.
#
# Parallelism: the 2 skills run concurrently within each repo (ForEach-Object
#   -Parallel). Repos themselves are processed sequentially on Windows; full
#   repo-level parallelism lives in the Linux/macOS run_claude_analysis.sh.
#
# (analysis-source skill was removed — its "소스 분석" tab is no longer produced.)
#
# Exit codes:
#   0  — success (or partial; HTML preserved for repos with no new content)
#   42 — Claude usage limit detected (caller should NOT retry; stop pipeline)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$CLAUDE_LIMIT_EXIT = 42
# Covers older "usage limit / reset at" wording and newer "You've hit your
# session limit · resets 3:50pm".
$LIMIT_REGEX       = 'usage.?limit|rate.?limit|session.?limit|too many requests|hit your[^.]*limit|reset[s]?( at)? [0-9]|reset[s]?( at)? [0-9]*[ap]m|Claude AI usage'

# Model for analysis. Without --model, `claude --print` uses the CLI default
# (often the heaviest model), burning session/usage quota faster. Default sonnet.
$ClaudeModel       = if ($env:CLAUDE_MODEL) { $env:CLAUDE_MODEL } else { "claude-sonnet-4-6" }

$RootDir           = Split-Path -Parent $PSScriptRoot
$VenvPython        = "$RootDir\.venv\Scripts\python.exe"
$AssetsDir         = "$RootDir\site\assets"
$AnalysisDir       = "$RootDir\site\analysis"
$TemplatesDir      = "$RootDir\templates"
$ClaudeCommandsDir = "$RootDir\.claude\commands"
$TmpDir            = "$env:TEMP\github-dashboard-analysis"
$TargetsJson       = "$AssetsDir\analysis_targets.json"

if (-not (Test-Path $TargetsJson)) {
    Write-Host "[analysis] analysis_targets.json not found, skipping analysis"
    exit 0
}

New-Item -ItemType Directory -Path $AnalysisDir, $TmpDir -Force | Out-Null

$payload = Get-Content $TargetsJson -Raw | ConvertFrom-Json
$repos   = $payload.targets | Where-Object { $_.full_name }

if (-not $repos) {
    Write-Host "[analysis] No targets to analyze"
    exit 0
}

function Convert-MdToHtml {
    param([string]$MdPath)
    if (-not (Test-Path $MdPath)) { return "" }
    if (Get-Command pandoc -ErrorAction SilentlyContinue) {
        return (pandoc $MdPath --from markdown --to html 2>$null | Out-String)
    } else {
        return & $VenvPython -c @"
import sys, markdown
content = open(r'$MdPath', encoding='utf-8').read()
print(markdown.markdown(content, extensions=['tables','fenced_code','toc']))
"@ 2>$null
    }
}

function Invoke-RepoAnalysis {
    param($Repo)

    $fullName    = $Repo.full_name
    $period      = if ($Repo.PSObject.Properties.Match('period').Count -gt 0      -and $Repo.period)       { $Repo.period }       else { "daily" }
    $stars       = if ($Repo.PSObject.Properties.Match('stars').Count -gt 0       -and $Repo.stars)        { $Repo.stars }        else { 0 }
    $description = if ($Repo.PSObject.Properties.Match('description').Count -gt 0 -and $Repo.description)  { ($Repo.description -replace '\|', ' ') } else { "" }
    $language    = if ($Repo.PSObject.Properties.Match('language').Count -gt 0    -and $Repo.language)     { $Repo.language }     else { "" }
    $starsGained = if ($Repo.PSObject.Properties.Match('stars_gained').Count -gt 0 -and $Repo.stars_gained) { $Repo.stars_gained } else { "" }

    $parts     = $fullName -split "/"
    $owner     = $parts[0]; $repoName = $parts[1]
    $safeName  = $fullName -replace "/", "_"
    $cloneDir  = "$TmpDir\$safeName"
    $reviewDir = "$cloneDir\.review"
    $outHtml   = "$AnalysisDir\$safeName.html"

    Write-Host "[analysis] Processing: $fullName ($period, *$stars)"

    if (Test-Path "$cloneDir\.git") {
        Write-Host "  Updating existing clone..."
        git -C $cloneDir fetch --depth=1 origin HEAD 2>$null
    } else {
        Write-Host "  Cloning (shallow)..."
        git clone --depth=1 "https://github.com/$fullName.git" $cloneDir 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  Clone failed, skipping $fullName"
            return $false
        }
    }

    New-Item -ItemType Directory -Path $reviewDir -Force | Out-Null

    # Run the 2 skills concurrently. Each parallel runspace is self-contained
    # (no access to script functions), so prompt build + claude call + file
    # write are inlined here. $using: pulls in the values it needs.
    $indepthMd = "$reviewDir\REVIEW-InDepth.md"
    $guideMd   = "$reviewDir\GUIDE4Junior.md"

    $skills = @(
        @{ Name="in-depth-review";    Args="--review-result REVIEW-InDepth.md"; Out=$indepthMd },
        @{ Name="create-guide4junior"; Args="";                                 Out=$guideMd   }
    )

    $results = $skills | ForEach-Object -Parallel {
        $skill            = $_
        $commandsDir      = $using:ClaudeCommandsDir
        $cwd              = $using:cloneDir
        $limitRegex       = $using:LIMIT_REGEX
        $model            = $using:ClaudeModel

        $skillFile = "$commandsDir\$($skill.Name).md"
        if (-not (Test-Path $skillFile)) {
            return @{ Name=$skill.Name; Ok=$false; LimitHit=$false }
        }

        $template = Get-Content $skillFile -Raw
        $prompt   = $template.Replace('$ARGUMENTS', "$cwd $($skill.Args)")
        $prompt  += "`n`n---`nOUTPUT INSTRUCTION: Output ONLY the final report in markdown. Do not write any files. Do not include preamble. Start directly with the report content."

        Push-Location $cwd
        try {
            $output   = $prompt | & claude --print --model $model --dangerously-skip-permissions 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        if (-not [string]::IsNullOrEmpty($output) -and [regex]::IsMatch($output, $limitRegex, 'IgnoreCase')) {
            return @{ Name=$skill.Name; Ok=$false; LimitHit=$true }
        }
        if ($exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($output)) {
            return @{ Name=$skill.Name; Ok=$false; LimitHit=$false }
        }

        New-Item -ItemType Directory -Path (Split-Path -Parent $skill.Out) -Force | Out-Null
        Set-Content -Path $skill.Out -Value $output -Encoding UTF8
        return @{ Name=$skill.Name; Ok=$true; LimitHit=$false }
    } -ThrottleLimit 2

    foreach ($r in $results) {
        if ($r.Ok)       { Write-Host "    Saved skill: $($r.Name)" }
        elseif ($r.LimitHit) { Write-Host "    [FATAL] Claude usage limit ($($r.Name))" -ForegroundColor Red }
        else             { Write-Host "    Skill produced no output: $($r.Name)" -ForegroundColor Yellow }
    }
    if ($results | Where-Object { $_.LimitHit }) { exit $CLAUDE_LIMIT_EXIT }

    # Skip HTML write if both skills failed — preserves prior good HTML in DEPLOY_REPO
    if (-not (Test-Path $indepthMd) -and -not (Test-Path $guideMd)) {
        Write-Host "  Both skills failed for $fullName — keeping existing HTML if any"
        return $true
    }

    # Render HTML via python template (uses sh version's exact rendering logic)
    $env:_PY_FULL_NAME    = $fullName
    $env:_PY_REPO_NAME    = $repoName
    $env:_PY_OWNER        = $owner
    $env:_PY_PERIOD       = $period
    $env:_PY_STARS        = "$stars"
    $env:_PY_DESC         = $description
    $env:_PY_LANG         = $language
    $env:_PY_STARS_GAINED = $starsGained
    $env:_PY_REVIEW_DIR   = $reviewDir
    $env:_PY_OUT_HTML     = $outHtml
    $env:_PY_TMPL_DIR     = $TemplatesDir

    $renderScript = @'
import os, markdown
from jinja2 import Template

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
    return markdown.markdown(text, extensions=["tables","fenced_code","toc"])

indepth_content  = open(f"{review_dir}/REVIEW-InDepth.md", encoding="utf-8").read() if os.path.exists(f"{review_dir}/REVIEW-InDepth.md") else "심층 분석 결과 없음"
guide_content    = open(f"{review_dir}/GUIDE4Junior.md", encoding="utf-8").read()   if os.path.exists(f"{review_dir}/GUIDE4Junior.md")   else "가이드 없음"

if os.path.exists(tmpl_path):
    with open(tmpl_path, encoding="utf-8") as f:
        t = Template(f.read())
    rendered = t.render(
        full_name=full_name, repo_name=repo_name, owner=owner,
        period=period, stars=stars, description=description,
        language=language, stars_gained=stars_gained,
        indepth_html=md(indepth_content),
        guide_html=md(guide_content),
    )
    with open(out_html, "w", encoding="utf-8") as fout:
        fout.write(rendered)
    print(f"  Saved: {out_html}")
else:
    print("  Template not found, skipping HTML render")
'@

    & $VenvPython -c $renderScript
    Write-Host "  Done: $fullName"
    return $true
}

Write-Host "[analysis] Starting analysis (skills run concurrently per repo; top100 → daily → weekly → monthly)"
foreach ($repo in $repos) {
    try { Invoke-RepoAnalysis -Repo $repo | Out-Null }
    catch { Write-Warning "Failed processing $($repo.full_name): $_" }
}
Write-Host "[analysis] Complete. Results in $AnalysisDir"
