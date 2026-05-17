#!/usr/bin/env bash
# Run Claude Code CLI skills on top 5 newly trending repos.
# Reads site/assets/new_trending.json, clones each repo, runs 3 skills,
# converts results to HTML, saves to site/analysis/{owner}_{name}.html
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="${ROOT_DIR}/site/assets"
ANALYSIS_DIR="${ROOT_DIR}/site/analysis"
TEMPLATES_DIR="${ROOT_DIR}/templates"
CLAUDE_COMMANDS_DIR="${ROOT_DIR}/.claude/commands"
TMP_DIR="/tmp/github-dashboard-analysis"

NEW_TRENDING_JSON="${ASSETS_DIR}/new_trending.json"

if [ ! -f "${NEW_TRENDING_JSON}" ]; then
  echo "[analysis] new_trending.json not found, skipping analysis"
  exit 0
fi

mkdir -p "${ANALYSIS_DIR}" "${TMP_DIR}"

# Read repo list (full_name entries) using python
REPO_LIST=$(python3 - <<'EOF'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
for r in d.get("new_repos", []):
    fn = r.get("full_name", "")
    if fn:
        period = r.get("period", "daily")
        stars = r.get("stars", 0)
        desc = r.get("description", "").replace("|", " ")
        lang = r.get("language", "")
        stars_gained = r.get("stars_gained", "")
        print(f"{fn}|{period}|{stars}|{desc}|{lang}|{stars_gained}")
EOF
"${NEW_TRENDING_JSON}")

if [ -z "${REPO_LIST}" ]; then
  echo "[analysis] No repos to analyze"
  exit 0
fi

# Build markdown-to-html converter function (uses python-markdown if pandoc unavailable)
md_to_html() {
  local input_md="$1"
  if command -v pandoc &>/dev/null; then
    pandoc "${input_md}" --from markdown --to html --standalone 2>/dev/null || cat "${input_md}"
  else
    python3 -c "
import sys, markdown, html
content = open(sys.argv[1]).read()
print(markdown.markdown(content, extensions=['tables','fenced_code','toc']))
" "${input_md}" 2>/dev/null || cat "${input_md}"
  fi
}

process_repo() {
  local full_name="$1"
  local period="$2"
  local stars="$3"
  local description="$4"
  local language="$5"
  local stars_gained="$6"

  local owner="${full_name%%/*}"
  local repo_name="${full_name##*/}"
  local safe_name="${full_name//\//_}"
  local clone_dir="${TMP_DIR}/${safe_name}"
  local review_dir="${clone_dir}/.review"
  local out_html="${ANALYSIS_DIR}/${safe_name}.html"

  echo "[analysis] Processing: ${full_name} (${period}, ★${stars})"

  # Clone or update repo (shallow)
  if [ -d "${clone_dir}/.git" ]; then
    echo "  Updating existing clone..."
    git -C "${clone_dir}" fetch --depth=1 origin HEAD 2>/dev/null || true
  else
    echo "  Cloning (shallow)..."
    git clone --depth=1 "https://github.com/${full_name}.git" "${clone_dir}" 2>/dev/null || {
      echo "  Clone failed, skipping ${full_name}"
      return
    }
  fi

  mkdir -p "${review_dir}"

  # Copy commands to repo's .claude directory so skills can be invoked
  mkdir -p "${clone_dir}/.claude/commands"
  cp "${CLAUDE_COMMANDS_DIR}"/*.md "${clone_dir}/.claude/commands/" 2>/dev/null || true

  # Run each skill (non-interactive, capture review files)
  echo "  Running /analysis-source..."
  (cd "${clone_dir}" && claude --print "/analysis-source ${clone_dir} --review-result REVIEW.md" 2>/dev/null) || true

  echo "  Running /in-depth-review..."
  (cd "${clone_dir}" && claude --print "/in-depth-review ${clone_dir} --review-result REVIEW-InDepth.md" 2>/dev/null) || true

  echo "  Running /create-guide4junior..."
  (cd "${clone_dir}" && claude --print "/create-guide4junior ${clone_dir}" 2>/dev/null) || true

  # Convert markdown results to HTML snippets
  local analysis_html=""
  local indepth_html=""
  local guide_html=""

  [ -f "${review_dir}/REVIEW.md" ] && analysis_html=$(md_to_html "${review_dir}/REVIEW.md")
  [ -f "${review_dir}/REVIEW-InDepth.md" ] && indepth_html=$(md_to_html "${review_dir}/REVIEW-InDepth.md")
  [ -f "${review_dir}/GUIDE4Junior.md" ] && guide_html=$(md_to_html "${review_dir}/GUIDE4Junior.md")

  # Render analysis HTML using python template
  python3 - <<PYEOF
import sys, html as html_lib

full_name   = ${full_name@Q}
repo_name   = ${repo_name@Q}
owner       = ${owner@Q}
period      = ${period@Q}
stars       = "${stars}"
description = ${description@Q}
language    = ${language@Q}
stars_gained = ${stars_gained@Q}

analysis_content  = open("${review_dir}/REVIEW.md").read()        if __import__('os').path.exists("${review_dir}/REVIEW.md")        else "분석 결과 없음"
indepth_content   = open("${review_dir}/REVIEW-InDepth.md").read() if __import__('os').path.exists("${review_dir}/REVIEW-InDepth.md") else "심층 분석 결과 없음"
guide_content     = open("${review_dir}/GUIDE4Junior.md").read()   if __import__('os').path.exists("${review_dir}/GUIDE4Junior.md")   else "가이드 없음"

import markdown
def md(text):
    return markdown.markdown(text, extensions=["tables","fenced_code","toc"])

tmpl_path = "${TEMPLATES_DIR}/analysis.html.j2"
if __import__('os').path.exists(tmpl_path):
    from jinja2 import Template
    with open(tmpl_path) as f:
        t = Template(f.read())
    rendered = t.render(
        full_name=full_name, repo_name=repo_name, owner=owner,
        period=period, stars=stars, description=description,
        language=language, stars_gained=stars_gained,
        analysis_html=md(analysis_content),
        indepth_html=md(indepth_content),
        guide_html=md(guide_content),
    )
    with open("${out_html}", "w") as fout:
        fout.write(rendered)
    print(f"  Saved: ${out_html}")
else:
    print("  Template not found, skipping HTML render")
PYEOF

  echo "  Done: ${full_name}"
}

echo "[analysis] Starting analysis for repos in new_trending.json"
while IFS='|' read -r full_name period stars description language stars_gained; do
  [ -z "${full_name}" ] && continue
  process_repo "${full_name}" "${period}" "${stars}" "${description}" "${language}" "${stars_gained}" || true
done <<< "${REPO_LIST}"

echo "[analysis] Complete. Results in ${ANALYSIS_DIR}"
