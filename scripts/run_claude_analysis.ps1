#Requires -Version 5.1
# Run Claude Code CLI skills on top 5 newly trending repos (Windows version).
# Reads site/assets/new_trending.json, clones repos, runs 3 skills,
# converts results to HTML, saves to site/analysis/{owner}_{name}.html
Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"  # non-fatal per-repo errors

$RootDir          = Split-Path -Parent $PSScriptRoot
$VenvPython       = "$RootDir\.venv\Scripts\python.exe"
$AssetsDir        = "$RootDir\site\assets"
$AnalysisDir      = "$RootDir\site\analysis"
$TemplatesDir     = "$RootDir\templates"
$ClaudeCommandsDir = "$RootDir\.claude\commands"
$TmpDir           = "$env:TEMP\github-dashboard-analysis"
$NewTrendingJson  = "$AssetsDir\new_trending.json"

if (-not (Test-Path $NewTrendingJson)) {
    Write-Host "[analysis] new_trending.json not found, skipping analysis"
    exit 0
}

New-Item -ItemType Directory -Path $AnalysisDir, $TmpDir -Force | Out-Null

# Read repo list from new_trending.json
$trending = Get-Content $NewTrendingJson -Raw | ConvertFrom-Json
$repos    = $trending.new_repos | Where-Object { $_.full_name }

if (-not $repos) {
    Write-Host "[analysis] No repos to analyze"
    exit 0
}

function ConvertTo-Html-FromMd {
    param([string]$MdPath)
    if (-not (Test-Path $MdPath)) { return "" }
    if (Get-Command pandoc -ErrorAction SilentlyContinue) {
        return pandoc $MdPath --from markdown --to html 2>$null
    } else {
        # Fallback: python-markdown
        return & $VenvPython -c @"
import sys, markdown
content = open(r'$MdPath', encoding='utf-8').read()
print(markdown.markdown(content, extensions=['tables','fenced_code','toc']))
"@ 2>$null
    }
}

function Process-Repo {
    param($Repo)

    $fullName    = $Repo.full_name
    $period      = $Repo.period      ?? "daily"
    $stars       = $Repo.stars       ?? 0
    $description = ($Repo.description ?? "").Replace("|", " ")
    $language    = $Repo.language    ?? ""
    $starsGained = $Repo.stars_gained ?? ""

    $parts     = $fullName -split "/"
    $owner     = $parts[0]; $repoName = $parts[1]
    $safeName  = $fullName -replace "/", "_"
    $cloneDir  = "$TmpDir\$safeName"
    $reviewDir = "$cloneDir\.review"
    $outHtml   = "$AnalysisDir\$safeName.html"

    Write-Host "[analysis] Processing: $fullName ($period, *$stars)"

    # Clone or update (shallow)
    if (Test-Path "$cloneDir\.git") {
        Write-Host "  Updating existing clone..."
        git -C $cloneDir fetch --depth=1 origin HEAD 2>$null
    } else {
        Write-Host "  Cloning (shallow)..."
        git clone --depth=1 "https://github.com/$fullName.git" $cloneDir 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  Clone failed, skipping $fullName"
            return
        }
    }

    New-Item -ItemType Directory -Path $reviewDir, "$cloneDir\.claude\commands" -Force | Out-Null

    # Copy Claude commands into clone
    if (Test-Path "$ClaudeCommandsDir\*.md") {
        Copy-Item "$ClaudeCommandsDir\*.md" "$cloneDir\.claude\commands\" -Force 2>$null
    }

    # Run skills (non-interactive)
    Push-Location $cloneDir
    try {
        Write-Host "  Running /analysis-source..."
        claude --print "/analysis-source $cloneDir --review-result REVIEW.md" 2>$null
        Write-Host "  Running /in-depth-review..."
        claude --print "/in-depth-review $cloneDir --review-result REVIEW-InDepth.md" 2>$null
        Write-Host "  Running /create-guide4junior..."
        claude --print "/create-guide4junior $cloneDir" 2>$null
    } finally {
        Pop-Location
    }

    # Convert markdown results to HTML
    $analysisHtml = ConvertTo-Html-FromMd "$reviewDir\REVIEW.md"
    $indepthHtml  = ConvertTo-Html-FromMd "$reviewDir\REVIEW-InDepth.md"
    $guideHtml    = ConvertTo-Html-FromMd "$reviewDir\GUIDE4Junior.md"

    # Render via Jinja2 template
    $renderScript = @"
import sys
sys.path.insert(0, r'$($RootDir -replace "\\", "\\\\")')
import os, markdown
from jinja2 import Template

def md(path, fallback):
    if os.path.exists(path):
        return markdown.markdown(open(path, encoding='utf-8').read(),
                                 extensions=['tables','fenced_code','toc'])
    return fallback

tmpl_path = r'$($TemplatesDir -replace "\\", "\\\\")\analysis.html.j2'
review_dir = r'$($reviewDir -replace "\\", "\\\\")'
out_html   = r'$($outHtml -replace "\\", "\\\\")'

with open(tmpl_path, encoding='utf-8') as f:
    t = Template(f.read())

rendered = t.render(
    full_name='$fullName', repo_name='$repoName', owner='$owner',
    period='$period', stars='$stars', description=r'$description',
    language='$language', stars_gained='$starsGained',
    analysis_html=md(os.path.join(review_dir,'REVIEW.md'),        '분석 결과 없음'),
    indepth_html =md(os.path.join(review_dir,'REVIEW-InDepth.md'),'심층 분석 결과 없음'),
    guide_html   =md(os.path.join(review_dir,'GUIDE4Junior.md'),  '가이드 없음'),
)
with open(out_html, 'w', encoding='utf-8') as f:
    f.write(rendered)
print(f'  Saved: {out_html}')
"@

    & $VenvPython -c $renderScript 2>$null
    Write-Host "  Done: $fullName"
}

Write-Host "[analysis] Starting analysis for repos in new_trending.json"
foreach ($repo in $repos) {
    try { Process-Repo -Repo $repo }
    catch { Write-Warning "Failed processing $($repo.full_name): $_" }
}
Write-Host "[analysis] Complete. Results in $AnalysisDir"
