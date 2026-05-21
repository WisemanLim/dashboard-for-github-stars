#!/usr/bin/env bash
# Run Claude Code CLI skills on top 5 newly trending repos.
# Reads site/assets/new_trending.json, clones each repo, runs 3 skills,
# converts results to HTML, saves to site/analysis/{owner}_{name}.html
set -euo pipefail
_CLAUDE_LIMIT_EXIT=42

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

# Run a claude skill non-interactively: read template, inject args, capture output → write file
# Usage: run_skill <skill-name> <extra-args> <output-file> <cwd>
run_skill() {
  local skill_name="$1" extra_args="$2" out_file="$3" cwd="$4"
  local skill_file="${CLAUDE_COMMANDS_DIR}/${skill_name}.md"
  [ -f "${skill_file}" ] || { echo "    Skill not found: ${skill_file}"; return 1; }

  # Build prompt: substitute $ARGUMENTS in template (python handles special chars safely)
  local prompt
  prompt=$(python3 - "${skill_file}" "${cwd} ${extra_args}" <<'PY'
import sys
content = open(sys.argv[1]).read()
content = content.replace("$ARGUMENTS", sys.argv[2])
# Tell model to output ONLY the report markdown — no file writes needed
content += "\n\n---\nOUTPUT INSTRUCTION: Output ONLY the final report in markdown. Do not write any files. Do not include preamble. Start directly with the report content."
print(content)
PY
) || { echo "    Failed to build prompt for ${skill_name}"; return 1; }

  echo "    Running ${skill_name} (may take 1-3 min)..."
  local output
  if ! output=$(cd "${cwd}" && printf '%s' "${prompt}" | claude --print --dangerously-skip-permissions 2>&1); then
    if printf '%s' "${output}" | grep -qiE 'usage.?limit|rate.?limit|too many requests|reset at [0-9]|Claude AI usage'; then
      echo "    [FATAL] Claude usage limit detected — aborting analysis"
      exit ${_CLAUDE_LIMIT_EXIT}
    fi
    echo "    claude failed for ${skill_name}:"
    echo "${output}" | head -5
    return 1
  fi

  # Check successful response for embedded usage-limit messages
  if printf '%s' "${output}" | grep -qiE 'usage.?limit|rate.?limit|too many requests|reset at [0-9]|Claude AI usage'; then
    echo "    [FATAL] Claude usage limit detected — aborting analysis"
    exit ${_CLAUDE_LIMIT_EXIT}
  fi

  if [ -z "${output}" ]; then
    echo "    Empty response from ${skill_name}"
    return 1
  fi

  mkdir -p "$(dirname "${out_file}")"
  printf '%s\n' "${output}" > "${out_file}"
  echo "    Saved: ${out_file} ($(wc -l < "${out_file}") lines)"
}

# Read repo list (full_name entries) using python
# Note: argument must come BEFORE the heredoc redirect so python receives sys.argv[1]
REPO_LIST=$(python3 - "${NEW_TRENDING_JSON}" <<'EOF'
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
)

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

  # Run each skill: capture output and write review files
  run_skill "analysis-source"    "--review-result REVIEW.md"        "${review_dir}/REVIEW.md"        "${clone_dir}" || true
  run_skill "in-depth-review"    "--review-result REVIEW-InDepth.md" "${review_dir}/REVIEW-InDepth.md" "${clone_dir}" || true
  run_skill "create-guide4junior" ""                                  "${review_dir}/GUIDE4Junior.md"  "${clone_dir}" || true

  # Skip HTML write if all skills failed — preserves prior good HTML in DEPLOY_REPO
  if [ ! -f "${review_dir}/REVIEW.md" ] \
     && [ ! -f "${review_dir}/REVIEW-InDepth.md" ] \
     && [ ! -f "${review_dir}/GUIDE4Junior.md" ]; then
    echo "  All skills failed for ${full_name} — keeping existing HTML if any"
    return 0
  fi

  # Convert markdown results to HTML snippets
  local analysis_html=""
  local indepth_html=""
  local guide_html=""

  [ -f "${review_dir}/REVIEW.md" ] && analysis_html=$(md_to_html "${review_dir}/REVIEW.md")
  [ -f "${review_dir}/REVIEW-InDepth.md" ] && indepth_html=$(md_to_html "${review_dir}/REVIEW-InDepth.md")
  [ -f "${review_dir}/GUIDE4Junior.md" ] && guide_html=$(md_to_html "${review_dir}/GUIDE4Junior.md")

  # Render analysis HTML using python template
  # Export vars so the single-quoted heredoc (bash 3.2-safe) can read them
  export _PY_FULL_NAME="${full_name}"
  export _PY_REPO_NAME="${repo_name}"
  export _PY_OWNER="${owner}"
  export _PY_PERIOD="${period}"
  export _PY_STARS="${stars}"
  export _PY_DESC="${description}"
  export _PY_LANG="${language}"
  export _PY_STARS_GAINED="${stars_gained}"
  export _PY_REVIEW_DIR="${review_dir}"
  export _PY_OUT_HTML="${out_html}"
  export _PY_TMPL_DIR="${TEMPLATES_DIR}"

  python3 - <<'PYEOF'
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
    return markdown.markdown(text, extensions=["tables", "fenced_code", "toc"])

analysis_content = open(f"{review_dir}/REVIEW.md").read()         if os.path.exists(f"{review_dir}/REVIEW.md")         else "분석 결과 없음"
indepth_content  = open(f"{review_dir}/REVIEW-InDepth.md").read() if os.path.exists(f"{review_dir}/REVIEW-InDepth.md") else "심층 분석 결과 없음"
guide_content    = open(f"{review_dir}/GUIDE4Junior.md").read()   if os.path.exists(f"{review_dir}/GUIDE4Junior.md")   else "가이드 없음"

if os.path.exists(tmpl_path):
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
    with open(out_html, "w") as fout:
        fout.write(rendered)
    print(f"  Saved: {out_html}")
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
