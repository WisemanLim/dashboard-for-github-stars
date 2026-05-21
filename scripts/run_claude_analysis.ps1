#Requires -Version 7.0
# Run Claude Code CLI skills on selected analysis targets (Windows version).
# Reads site/assets/analysis_targets.json (ordered: top100 → daily → weekly → monthly),
# clones each repo, runs 3 skills sequentially (no parallel — token budget priority),
# converts results to HTML, saves to site/analysis/{owner}_{name}.html.
#
# Exit codes:
#   0  — success (or partial; HTML preserved for repos with no new content)
#   42 — Claude usage limit detected (caller should NOT retry; stop pipeline)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$CLAUDE_LIMIT_EXIT = 42
$LIMIT_REGEX       = 'usage.?limit|rate.?limit|too many requests|reset at [0-9]|Claude AI usage'

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

function Test-LimitMessage {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    return [bool]([regex]::IsMatch($Text, $LIMIT_REGEX, 'IgnoreCase'))
}

function Invoke-ClaudeSkill {
    # Returns: hashtable @{ Ok=$true/$false; Output=$string; LimitHit=$true/$false }
    param(
        [string]$SkillName,
        [string]$ExtraArgs,
        [string]$OutFile,
        [string]$Cwd
    )

    $skillFile = "$ClaudeCommandsDir\$SkillName.md"
    if (-not (Test-Path $skillFile)) {
        Write-Host "    Skill not found: $skillFile"
        return @{ Ok=$false; LimitHit=$false; Output="" }
    }

    # Build prompt: substitute $ARGUMENTS, append output instruction
    $template = Get-Content $skillFile -Raw
    $prompt   = $template.Replace('$ARGUMENTS', "$Cwd $ExtraArgs")
    $prompt  += "`n`n---`nOUTPUT INSTRUCTION: Output ONLY the final report in markdown. Do not write any files. Do not include preamble. Start directly with the report content."

    Write-Host "    Running $SkillName (may take 1-3 min)..."
    Push-Location $Cwd
    try {
        $output = $prompt | & claude --print --dangerously-skip-permissions 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    if (Test-LimitMessage -Text $output) {
        Write-Host "    [FATAL] Claude usage limit detected — aborting analysis" -ForegroundColor Red
        return @{ Ok=$false; LimitHit=$true; Output=$output }
    }

    if ($exitCode -ne 0) {
        Write-Host "    claude failed for $SkillName (exit=$exitCode)" -ForegroundColor Yellow
        $output.Split("`n") | Select-Object -First 5 | ForEach-Object { Write-Host "      $_" }
        return @{ Ok=$false; LimitHit=$false; Output=$output }
    }

    if ([string]::IsNullOrWhiteSpace($output)) {
        Write-Host "    Empty response from $SkillName" -ForegroundColor Yellow
        return @{ Ok=$false; LimitHit=$false; Output=$output }
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $OutFile) -Force | Out-Null
    Set-Content -Path $OutFile -Value $output -Encoding UTF8
    $lineCount = ($output -split "`n").Length
    Write-Host "    Saved: $OutFile ($lineCount lines)"
    return @{ Ok=$true; LimitHit=$false; Output=$output }
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

    # Run 3 skills sequentially
    $reviewMd   = "$reviewDir\REVIEW.md"
    $indepthMd  = "$reviewDir\REVIEW-InDepth.md"
    $guideMd    = "$reviewDir\GUIDE4Junior.md"

    foreach ($skill in @(
        @{ Name="analysis-source";    Args="--review-result REVIEW.md";        Out=$reviewMd  },
        @{ Name="in-depth-review";    Args="--review-result REVIEW-InDepth.md"; Out=$indepthMd },
        @{ Name="create-guide4junior"; Args="";                                 Out=$guideMd   }
    )) {
        $result = Invoke-ClaudeSkill -SkillName $skill.Name -ExtraArgs $skill.Args -OutFile $skill.Out -Cwd $cloneDir
        if ($result.LimitHit) { exit $CLAUDE_LIMIT_EXIT }
    }

    # Skip HTML write if all 3 skills failed — preserves prior good HTML in DEPLOY_REPO
    if (-not (Test-Path $reviewMd) -and -not (Test-Path $indepthMd) -and -not (Test-Path $guideMd)) {
        Write-Host "  All skills failed for $fullName — keeping existing HTML if any"
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

analysis_content = open(f"{review_dir}/REVIEW.md", encoding="utf-8").read()         if os.path.exists(f"{review_dir}/REVIEW.md")         else "분석 결과 없음"
indepth_content  = open(f"{review_dir}/REVIEW-InDepth.md", encoding="utf-8").read() if os.path.exists(f"{review_dir}/REVIEW-InDepth.md") else "심층 분석 결과 없음"
guide_content    = open(f"{review_dir}/GUIDE4Junior.md", encoding="utf-8").read()   if os.path.exists(f"{review_dir}/GUIDE4Junior.md")   else "가이드 없음"

if os.path.exists(tmpl_path):
    with open(tmpl_path, encoding="utf-8") as f:
        t = Template(f.read())
    rendered = t.render(
        full_name=full_name, repo_name=repo_name, owner=owner,
        period=period, stars=stars, description=description,
        language=language, stars_gained=stars_gained,
        analysis_html=md(analysis_content),
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

Write-Host "[analysis] Starting sequential analysis (top100 → daily → weekly → monthly)"
foreach ($repo in $repos) {
    try { Invoke-RepoAnalysis -Repo $repo | Out-Null }
    catch { Write-Warning "Failed processing $($repo.full_name): $_" }
}
Write-Host "[analysis] Complete. Results in $AnalysisDir"
