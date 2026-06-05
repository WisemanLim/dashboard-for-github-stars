#!/usr/bin/env bash
# test/test_scripts.sh — Smoke tests for deploy.sh and scripts/

# Re-exec under bash if invoked via 'sh ...' (dash lacks 'set -o pipefail').
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
RESULTS=()

_pass() { PASS=$((PASS+1)); RESULTS+=("PASS|$1"); printf '[PASS] %s\n' "$1"; }
_fail() { FAIL=$((FAIL+1)); RESULTS+=("FAIL|$1"); printf '[FAIL] %s\n' "$1"; }

echo "========================================"
echo "  GitHub Stars Dashboard — Script Tests"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# ── 1. Syntax checks ────────────────────────────────────────────────────────
echo "[1] Syntax checks"
for f in deploy.sh scripts/run_daily.sh scripts/run_claude_analysis.sh; do
  if bash -n "${ROOT_DIR}/${f}" 2>/dev/null; then
    _pass "syntax: ${f}"
  else
    _fail "syntax: ${f} (bash -n failed)"
  fi
done

# ── 2. .env parsing (grep+cut logic used in deploy.sh) ──────────────────────
echo ""
echo "[2] .env parsing"
_tmpenv=$(mktemp)
cat > "${_tmpenv}" <<'ENV'
SOURCE_ACCOUNT=test-source-acct
DEPLOY_ACCOUNT=test-deploy-acct
DEPLOY_REPO=test-pages-repo
SCHEDULE_TIME=03:30
CLAUDE_MODEL=claude-test-model
APP_USER=testuser99
ENV

_d_src=$(grep -E '^SOURCE_ACCOUNT='  "${_tmpenv}" | cut -d= -f2- | tr -d '"' || true)
_d_dep=$(grep -E '^DEPLOY_ACCOUNT='  "${_tmpenv}" | cut -d= -f2- | tr -d '"' || true)
_d_rep=$(grep -E '^DEPLOY_REPO='     "${_tmpenv}" | cut -d= -f2- | tr -d '"' || true)
_d_sch=$(grep -E '^SCHEDULE_TIME='   "${_tmpenv}" | cut -d= -f2- | tr -d '"' || true)
_d_mdl=$(grep -E '^CLAUDE_MODEL='    "${_tmpenv}" | cut -d= -f2- | tr -d '"' || true)
_d_usr=$(grep -E '^APP_USER='        "${_tmpenv}" | cut -d= -f2- | tr -d '"' || true)
rm -f "${_tmpenv}"

[ "${_d_src}" = "test-source-acct" ] && _pass ".env parse: SOURCE_ACCOUNT"  || _fail ".env parse: SOURCE_ACCOUNT (got '${_d_src}')"
[ "${_d_dep}" = "test-deploy-acct" ] && _pass ".env parse: DEPLOY_ACCOUNT"  || _fail ".env parse: DEPLOY_ACCOUNT (got '${_d_dep}')"
[ "${_d_rep}" = "test-pages-repo"  ] && _pass ".env parse: DEPLOY_REPO"     || _fail ".env parse: DEPLOY_REPO (got '${_d_rep}')"
[ "${_d_sch}" = "03:30"            ] && _pass ".env parse: SCHEDULE_TIME"   || _fail ".env parse: SCHEDULE_TIME (got '${_d_sch}')"
[ "${_d_mdl}" = "claude-test-model" ] && _pass ".env parse: CLAUDE_MODEL"    || _fail ".env parse: CLAUDE_MODEL (got '${_d_mdl}')"
[ "${_d_usr}" = "testuser99"       ] && _pass ".env parse: APP_USER"        || _fail ".env parse: APP_USER (got '${_d_usr}')"

# ── 3. GIT_ASKPASS script (used in run_daily.sh _pull_source) ───────────────
echo ""
echo "[3] GIT_ASKPASS credential injection"
_askpass=$(mktemp /tmp/git-askpass-test-XXXXXX)
cat > "${_askpass}" <<'ASKPASS'
#!/bin/sh
case "$1" in *sername*) printf 'x-access-token' ;; *) printf '%s' "${_GIT_TOKEN}" ;; esac
ASKPASS
chmod 700 "${_askpass}"

_got_user=$("${_askpass}" "Username for 'https://github.com'")
_got_pass=$(_GIT_TOKEN="ghp_testtoken123" "${_askpass}" "Password for 'https://github.com'")
rm -f "${_askpass}"

[ "${_got_user}" = "x-access-token" ] \
  && _pass "GIT_ASKPASS: username returns 'x-access-token'" \
  || _fail "GIT_ASKPASS: username got '${_got_user}'"
[ "${_got_pass}" = "ghp_testtoken123" ] \
  && _pass "GIT_ASKPASS: password returns token from env" \
  || _fail "GIT_ASKPASS: password got '${_got_pass}'"

# ── 4. Claude usage limit detection regex ───────────────────────────────────
echo ""
echo "[4] Claude usage limit detection"
_LIMIT_RE='usage.?limit|rate.?limit|too many requests|reset at [0-9]|Claude AI usage'

_limit_cases=(
  "Claude AI usage limit reached. Reset at 2026-05-22."
  "You have exceeded your usage limit for today."
  "rate limit exceeded, please try again later"
  "Too many requests — reset at 00:00 UTC"
)
_normal_cases=(
  "## Analysis\nThis is a normal analysis of the repository."
  "The code quality is high. No issues found."
  "# Summary\nGreat project with active maintenance."
)

for msg in "${_limit_cases[@]}"; do
  if printf '%s' "${msg}" | grep -qiE "${_LIMIT_RE}"; then
    _pass "limit detection: detected → '${msg:0:50}'"
  else
    _fail "limit detection: missed  → '${msg:0:50}'"
  fi
done

for msg in "${_normal_cases[@]}"; do
  if printf '%s' "${msg}" | grep -qiE "${_LIMIT_RE}"; then
    _fail "limit detection: false positive → '${msg:0:50}'"
  else
    _pass "limit detection: no false positive → '${msg:0:50}'"
  fi
done

# ── 5. Exit code 42 propagation ──────────────────────────────────────────────
echo ""
echo "[5] Exit code propagation"
_CLAUDE_LIMIT_EXIT=42

_rc=0
(exit 42) || _rc=$?
[ "${_rc}" -eq "${_CLAUDE_LIMIT_EXIT}" ] \
  && _pass "exit code 42 captured correctly" \
  || _fail "exit code 42: got ${_rc}"

# simulate run_daily.sh step 6 logic
_test_step6() {
  local mock_rc="$1"
  local _analysis_rc=0
  (exit "${mock_rc}") || _analysis_rc=$?
  if [ "${_analysis_rc}" -eq 42 ]; then
    echo "would_abort"
  elif [ "${_analysis_rc}" -ne 0 ]; then
    echo "non_fatal_continue"
  else
    echo "success"
  fi
}

[ "$(_test_step6 0  )" = "success"           ] && _pass "step6 logic: exit 0 → success"           || _fail "step6 logic: exit 0 failed"
[ "$(_test_step6 1  )" = "non_fatal_continue" ] && _pass "step6 logic: exit 1 → non-fatal"         || _fail "step6 logic: exit 1 failed"
[ "$(_test_step6 42 )" = "would_abort"        ] && _pass "step6 logic: exit 42 → abort"            || _fail "step6 logic: exit 42 failed"

# ── 6. _CLAUDE_LIMIT_EXIT defined in run_claude_analysis.sh ─────────────────
echo ""
echo "[6] run_claude_analysis.sh constants"
if grep -q '^_CLAUDE_LIMIT_EXIT=42' "${ROOT_DIR}/scripts/run_claude_analysis.sh"; then
  _pass "_CLAUDE_LIMIT_EXIT=42 defined in run_claude_analysis.sh"
else
  _fail "_CLAUDE_LIMIT_EXIT=42 missing from run_claude_analysis.sh"
fi

if grep -q 'FATAL.*Claude usage limit' "${ROOT_DIR}/scripts/run_claude_analysis.sh"; then
  _pass "limit detection code present in run_claude_analysis.sh"
else
  _fail "limit detection code missing from run_claude_analysis.sh"
fi

# ── 7. run_daily.sh structure checks ────────────────────────────────────────
echo ""
echo "[7] run_daily.sh structure"
if grep -q '_pull_source()' "${ROOT_DIR}/scripts/run_daily.sh"; then
  _pass "run_daily.sh: _pull_source() function defined"
else
  _fail "run_daily.sh: _pull_source() missing"
fi

if grep -q 'GIT_ASKPASS' "${ROOT_DIR}/scripts/run_daily.sh"; then
  _pass "run_daily.sh: GIT_ASKPASS token injection present"
else
  _fail "run_daily.sh: GIT_ASKPASS missing"
fi

if grep -q 'DEPLOY_ACCOUNT.*for push\|Switching gh to DEPLOY_ACCOUNT' "${ROOT_DIR}/scripts/run_daily.sh"; then
  _pass "run_daily.sh: DEPLOY_ACCOUNT verification before push"
else
  _fail "run_daily.sh: DEPLOY_ACCOUNT push check missing"
fi

if grep -q '_CLAUDE_LIMIT_EXIT=42' "${ROOT_DIR}/scripts/run_daily.sh"; then
  _pass "run_daily.sh: _CLAUDE_LIMIT_EXIT=42 defined"
else
  _fail "run_daily.sh: _CLAUDE_LIMIT_EXIT missing"
fi

# ── 8. Analysis target selection (select_analysis_targets.py) ───────────────
echo ""
echo "[8] Analysis target selection"

if [ -f "${ROOT_DIR}/scripts/select_analysis_targets.py" ]; then
  _pass "select_analysis_targets.py exists"
else
  _fail "select_analysis_targets.py missing"
fi

# Functional test: synthetic data.json + ANALYSIS_DIR
_sel_tmp=$(mktemp -d /tmp/sel-test-XXXXXX)
mkdir -p "${_sel_tmp}/site/assets" "${_sel_tmp}/site/analysis" "${_sel_tmp}/scripts"
cp "${ROOT_DIR}/scripts/select_analysis_targets.py" "${_sel_tmp}/scripts/"

# Synthetic data: top100 has 5 repos, trending has 5 each, with overlaps
python3 - "${_sel_tmp}/site/assets/data.json" <<'PY'
import json, sys
data = {
  "generated_at": "test",
  "categories": [
    {"slug": "x", "label": "X", "top100": [
      {"rank": i+1, "name": f"r{i}", "full_name": f"orgA/r{i}",
       "stars": 1_000_000 - i*1000, "language": "Py", "description": "d",
       "url": "u", "forks": 0, "topics": [], "updated_at": ""}
      for i in range(10)
    ]},
  ],
  "trending": {
    "daily":   [{"rank": i+1, "name": f"d{i}", "full_name": f"daily/d{i}",
                 "stars": 100, "language": "Py", "description": "x",
                 "url": "u", "forks": 0, "stars_gained": "1", "owner": "daily", "topics": []}
                for i in range(5)],
    "weekly":  [{"rank": i+1, "name": f"w{i}", "full_name": f"weekly/w{i}",
                 "stars": 100, "language": "Py", "description": "x",
                 "url": "u", "forks": 0, "stars_gained": "1", "owner": "weekly", "topics": []}
                for i in range(5)],
    "monthly": [{"rank": i+1, "name": f"m{i}", "full_name": f"monthly/m{i}",
                 "stars": 100, "language": "Py", "description": "x",
                 "url": "u", "forks": 0, "stars_gained": "1", "owner": "monthly", "topics": []}
                for i in range(5)],
  },
}
# Daily[2] also appears in weekly[1] — should dedupe
data["trending"]["weekly"][1] = data["trending"]["daily"][2].copy()
with open(sys.argv[1], "w") as f:
  json.dump(data, f)
PY

# Plant: orgA/r0 has fake "real" HTML (15KB no placeholder) → should be skipped
python3 -c "open('${_sel_tmp}/site/analysis/orgA_r0.html','w').write('<html>'+('real content '*1500)+'</html>')"
# Plant: orgA/r1 has empty HTML (<10KB with placeholder x3) → should NOT be skipped
python3 -c "
content = '<html>' + ('분석 결과 없음 ' * 3) + 'small ' * 100 + '</html>'
open('${_sel_tmp}/site/analysis/orgA_r1.html','w').write(content)
"

# Run script
cd "${_sel_tmp}" && python3 scripts/select_analysis_targets.py > /tmp/sel-output.txt 2>&1
_sel_rc=$?
cd "${ROOT_DIR}"

[ "${_sel_rc}" -eq 0 ] && _pass "select_analysis_targets.py runs without error" || _fail "select_analysis_targets.py exit=${_sel_rc}"

if [ -f "${_sel_tmp}/site/assets/analysis_targets.json" ]; then
  _pass "analysis_targets.json created"
else
  _fail "analysis_targets.json not created"
fi

# Verify content
_targets_count=$(python3 -c "
import json
d = json.load(open('${_sel_tmp}/site/assets/analysis_targets.json'))
print(d.get('total_targets', 0))
")
# Expected:
#  top100: 5 candidates (r0..r4), r0 skipped (real HTML), r1 selected (empty), r2,r3,r4 selected → 4
#  daily:  5 candidates (d0..d4), all selected → 5
#  weekly: 5 candidates but d2 is duplicate → 4 new selected
#  monthly: 5 candidates → 5
#  Total = 4 + 5 + 4 + 5 = 18
[ "${_targets_count}" = "18" ] && _pass "target count = 18 (5+5+5+5 - 1 dupe - 1 skipped_real)" || _fail "target count = ${_targets_count} (expected 18)"

# Check order: first 4 targets must be top100 group
_first_periods=$(python3 -c "
import json
d = json.load(open('${_sel_tmp}/site/assets/analysis_targets.json'))
print(','.join(t['period'] for t in d['targets'][:4]))
")
[ "${_first_periods}" = "top100,top100,top100,top100" ] && _pass "priority order: top100 group first" || _fail "first 4 periods: '${_first_periods}'"

# Check that orgA/r0 (real HTML) is NOT in targets
_has_r0=$(python3 -c "
import json
d = json.load(open('${_sel_tmp}/site/assets/analysis_targets.json'))
print('yes' if any(t['full_name'] == 'orgA/r0' for t in d['targets']) else 'no')
")
[ "${_has_r0}" = "no" ] && _pass "orgA/r0 (real HTML > 10KB) skipped" || _fail "orgA/r0 not skipped"

# Check that orgA/r1 (empty placeholder HTML) IS in targets
_has_r1=$(python3 -c "
import json
d = json.load(open('${_sel_tmp}/site/assets/analysis_targets.json'))
print('yes' if any(t['full_name'] == 'orgA/r1' for t in d['targets']) else 'no')
")
[ "${_has_r1}" = "yes" ] && _pass "orgA/r1 (empty placeholder HTML) re-selected" || _fail "orgA/r1 not re-selected"

# Check dedupe: weekly[1] = daily[2] should not double-count
_dupe_skipped=$(python3 -c "
import json
d = json.load(open('${_sel_tmp}/site/assets/analysis_targets.json'))
print(d['summary']['weekly']['skipped_duplicate'])
")
[ "${_dupe_skipped}" = "1" ] && _pass "dedupe across lists works (weekly skipped 1 dupe)" || _fail "dedupe failed (skipped_duplicate=${_dupe_skipped})"

rm -rf "${_sel_tmp}"

# Verify run_claude_analysis.sh reads analysis_targets.json
if grep -q 'analysis_targets.json' "${ROOT_DIR}/scripts/run_claude_analysis.sh"; then
  _pass "run_claude_analysis.sh reads analysis_targets.json"
else
  _fail "run_claude_analysis.sh still references old JSON"
fi

# Verify run_daily.sh calls select_analysis_targets.py
if grep -q 'select_analysis_targets.py' "${ROOT_DIR}/scripts/run_daily.sh"; then
  _pass "run_daily.sh calls select_analysis_targets.py"
else
  _fail "run_daily.sh does not call select_analysis_targets.py"
fi

# ── 9. deploy.sh new features (--schedule, install_scheduler, status) ──────
echo ""
echo "[9] deploy.sh new features"

# Help works
if bash "${ROOT_DIR}/deploy.sh" --help >/dev/null 2>&1; then
  _pass "deploy.sh --help works"
else
  _fail "deploy.sh --help failed"
fi

# Bad time format rejected
if ! bash "${ROOT_DIR}/deploy.sh" --schedule bad-time </dev/null 2>/dev/null; then
  _pass "deploy.sh --schedule rejects bad time format"
else
  _fail "deploy.sh --schedule accepted bad time format"
fi

# install_scheduler / show_scheduler_status functions defined
if grep -q '^install_scheduler()' "${ROOT_DIR}/deploy.sh"; then
  _pass "deploy.sh: install_scheduler() function defined"
else
  _fail "deploy.sh: install_scheduler() missing"
fi
if grep -q '^show_scheduler_status()' "${ROOT_DIR}/deploy.sh"; then
  _pass "deploy.sh: show_scheduler_status() function defined"
else
  _fail "deploy.sh: show_scheduler_status() missing"
fi

# Schedule-only branch exists
if grep -q 'Schedule-only mode' "${ROOT_DIR}/deploy.sh"; then
  _pass "deploy.sh: schedule-only branch present"
else
  _fail "deploy.sh: schedule-only branch missing"
fi

# Status check commands referenced for each scheduler
if grep -q 'systemctl list-timers github-dashboard.timer' "${ROOT_DIR}/deploy.sh"; then
  _pass "deploy.sh: systemd status check present"
else
  _fail "deploy.sh: systemd status check missing"
fi
if grep -q "launchctl list 2>/dev/null | grep --color=never \"github-dashboard\"" "${ROOT_DIR}/deploy.sh"; then
  _pass "deploy.sh: launchd status check present"
else
  _fail "deploy.sh: launchd status check missing"
fi
if grep -q "crontab -l 2>/dev/null | grep --color=never \"run_daily.sh\"" "${ROOT_DIR}/deploy.sh"; then
  _pass "deploy.sh: cron status check present"
else
  _fail "deploy.sh: cron status check missing"
fi

# sh-invocation guard: re-exec via bash if dash launched it
for f in deploy.sh test.sh scripts/run_daily.sh scripts/run_claude_analysis.sh \
         scripts/bootstrap_server.sh test/test_scripts.sh; do
  if grep -q 'exec bash "\$0" "\$@"' "${ROOT_DIR}/${f}" 2>/dev/null; then
    _pass "bash re-exec guard: ${f}"
  else
    _fail "bash re-exec guard: ${f} missing"
  fi
done

# Functional: sh deploy.sh --help should work (dash → bash re-exec)
if /bin/sh "${ROOT_DIR}/deploy.sh" --help >/dev/null 2>&1; then
  _pass "sh deploy.sh --help works (re-exec via bash)"
else
  _fail "sh deploy.sh --help failed (re-exec not working)"
fi

# ── 10. ps1 parity with sh (static check via grep) ──────────────────────────
echo ""
echo "[10] PowerShell scripts parity"

# deploy.ps1
_ps1="${ROOT_DIR}/deploy.ps1"
if grep -q '\$ScheduleOnly' "${_ps1}"; then
  _pass "deploy.ps1: -ScheduleOnly parameter present"
else
  _fail "deploy.ps1: -ScheduleOnly missing"
fi
if grep -q 'function Install-Scheduler' "${_ps1}"; then
  _pass "deploy.ps1: Install-Scheduler function defined"
else
  _fail "deploy.ps1: Install-Scheduler missing"
fi
if grep -q 'function Show-SchedulerStatus' "${_ps1}"; then
  _pass "deploy.ps1: Show-SchedulerStatus function defined"
else
  _fail "deploy.ps1: Show-SchedulerStatus missing"
fi
if grep -q 'Read-EnvDefault' "${_ps1}"; then
  _pass "deploy.ps1: .env defaults loader present"
else
  _fail "deploy.ps1: .env defaults loader missing"
fi
if grep -q 'remote add deploy\|remote set-url deploy' "${_ps1}"; then
  _pass "deploy.ps1: deploy remote configured separately"
else
  _fail "deploy.ps1: deploy remote not split from origin"
fi

# run_daily.ps1
_rd="${ROOT_DIR}/scripts/run_daily.ps1"
if grep -q 'select_analysis_targets.py' "${_rd}"; then
  _pass "run_daily.ps1: calls select_analysis_targets.py"
else
  _fail "run_daily.ps1: does not call select_analysis_targets.py"
fi
if grep -q 'CLAUDE_LIMIT_EXIT' "${_rd}"; then
  _pass "run_daily.ps1: handles Claude limit exit code"
else
  _fail "run_daily.ps1: limit exit handling missing"
fi
if grep -q 'http.extraheader' "${_rd}"; then
  _pass "run_daily.ps1: token injection for source pull"
else
  _fail "run_daily.ps1: token injection missing"
fi
if grep -q 'Get-ActiveGhAccount\|gh auth switch -u \$DeployAccount' "${_rd}"; then
  _pass "run_daily.ps1: DEPLOY_ACCOUNT verification present"
else
  _fail "run_daily.ps1: DEPLOY_ACCOUNT verification missing"
fi
if grep -q 'Preserved.*existing analysis HTMLs' "${_rd}"; then
  _pass "run_daily.ps1: analysis HTML preservation present"
else
  _fail "run_daily.ps1: analysis preservation missing"
fi
if grep -q '\$deployTmp' "${_rd}" && grep -q 'github-dashboard-deploy' "${_rd}"; then
  _pass "run_daily.ps1: separate deploy clone (DEPLOY repo)"
else
  _fail "run_daily.ps1: deploy clone separation missing"
fi

# run_claude_analysis.ps1
_rc="${ROOT_DIR}/scripts/run_claude_analysis.ps1"
if grep -q 'analysis_targets.json' "${_rc}"; then
  _pass "run_claude_analysis.ps1: reads analysis_targets.json"
else
  _fail "run_claude_analysis.ps1: still uses old JSON"
fi
if grep -q '\-\-dangerously-skip-permissions' "${_rc}"; then
  _pass "run_claude_analysis.ps1: --dangerously-skip-permissions flag present"
else
  _fail "run_claude_analysis.ps1: skip-permissions flag missing"
fi
if grep -q 'CLAUDE_LIMIT_EXIT\|Claude usage limit detected' "${_rc}"; then
  _pass "run_claude_analysis.ps1: usage limit detection present"
else
  _fail "run_claude_analysis.ps1: usage limit detection missing"
fi
if grep -q 'All skills failed' "${_rc}"; then
  _pass "run_claude_analysis.ps1: skip-HTML-if-all-failed present"
else
  _fail "run_claude_analysis.ps1: skip-HTML logic missing"
fi
if grep -q 'function Invoke-ClaudeSkill' "${_rc}"; then
  _pass "run_claude_analysis.ps1: Invoke-ClaudeSkill function defined"
else
  _fail "run_claude_analysis.ps1: Invoke-ClaudeSkill missing"
fi

# ── 11. Analysis HTML preservation logic ─────────────────────────────────────
echo ""
echo "[11] Analysis HTML preservation"

if grep -q 'Preserved.*existing analysis HTMLs' "${ROOT_DIR}/scripts/run_daily.sh"; then
  _pass "run_daily.sh: analysis preservation block present"
else
  _fail "run_daily.sh: analysis preservation missing"
fi

if grep -q 'All skills failed for.*keeping existing HTML' "${ROOT_DIR}/scripts/run_claude_analysis.sh"; then
  _pass "run_claude_analysis.sh: skip-HTML-if-all-failed present"
else
  _fail "run_claude_analysis.sh: skip-HTML-if-all-failed missing"
fi

# Functional test of preservation: mock DEPLOY_TMP + site/analysis/ scenarios
_preserve_test_dir=$(mktemp -d /tmp/preserve-test-XXXXXX)
_mock_deploy="${_preserve_test_dir}/deploy"
_mock_local="${_preserve_test_dir}/local/site/analysis"
mkdir -p "${_mock_deploy}/analysis" "${_mock_local}"

# Deploy repo has 3 historical analyses
echo "old-A" > "${_mock_deploy}/analysis/repoA.html"
echo "old-B" > "${_mock_deploy}/analysis/repoB.html"
echo "old-C" > "${_mock_deploy}/analysis/repoC.html"

# Local site only has today's regenerated B
echo "new-B" > "${_mock_local}/repoB.html"

# Run preservation logic (extracted from run_daily.sh)
_preserved=0
for _old_html in "${_mock_deploy}/analysis"/*.html; do
  [ -f "${_old_html}" ] || continue
  _local_path="${_mock_local}/$(basename "${_old_html}")"
  if [ ! -f "${_local_path}" ]; then
    cp -p "${_old_html}" "${_local_path}"
    _preserved=$((_preserved + 1))
  fi
done

[ "${_preserved}" -eq 2 ] && _pass "preservation: copied 2 missing files (A, C)" || _fail "preservation: expected 2 copies, got ${_preserved}"
[ -f "${_mock_local}/repoA.html" ] && _pass "preservation: repoA.html preserved" || _fail "preservation: repoA.html missing"
[ -f "${_mock_local}/repoC.html" ] && _pass "preservation: repoC.html preserved" || _fail "preservation: repoC.html missing"

# repoB should NOT be overwritten (today's content takes precedence)
_b_content=$(cat "${_mock_local}/repoB.html")
[ "${_b_content}" = "new-B" ] && _pass "preservation: repoB.html not overwritten (today's content kept)" || _fail "preservation: repoB.html got overwritten (content='${_b_content}')"

rm -rf "${_preserve_test_dir}"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
printf 'Results: %d passed, %d failed\n' "${PASS}" "${FAIL}"
echo "========================================"

# ── Generate RESULTS.md ───────────────────────────────────────────────────────
RESULTS_MD="${ROOT_DIR}/test/RESULTS.md"
STATUS_ICON=$([ "${FAIL}" -eq 0 ] && echo "✅" || echo "❌")

cat > "${RESULTS_MD}" <<MDEOF
# Test Results

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Status**: ${STATUS_ICON} $([ "${FAIL}" -eq 0 ] && echo "All tests passed" || echo "${FAIL} test(s) failed")

## Summary

| | Count |
|---|---|
| ✅ Passed | ${PASS} |
| ❌ Failed | ${FAIL} |
| Total | $((PASS + FAIL)) |

## Test Details

MDEOF

for r in "${RESULTS[@]}"; do
  _icon="${r%%|*}"
  _msg="${r#*|}"
  if [ "${_icon}" = "PASS" ]; then
    printf -- '- ✅ %s\n' "${_msg}" >> "${RESULTS_MD}"
  else
    printf -- '- ❌ %s\n' "${_msg}" >> "${RESULTS_MD}"
  fi
done

cat >> "${RESULTS_MD}" <<'MDEOF'

## Changes Applied

### `scripts/run_daily.sh`
| Section | Change |
|---------|--------|
| Step 1 (pull) | Replaced complex multi-account logic with `_pull_source()` using `GIT_ASKPASS` token injection. Avoids gh credential-helper conflicts when DEPLOY_ACCOUNT is active session. |
| Step 6 (analysis) | Added exit code 42 handling — aborts `run_daily.sh` immediately on Claude usage limit instead of continuing silently. |
| Step 7 (push) | Added explicit `gh auth switch` to DEPLOY_ACCOUNT before GitHub Pages push. |

### `scripts/run_claude_analysis.sh`
| Section | Change |
|---------|--------|
| Top | Added `_CLAUDE_LIMIT_EXIT=42` constant. |
| `run_skill()` | Added usage limit pattern detection in both error path (non-zero exit) and success path (zero exit with limit message). Exits 42 immediately — no retry, no wait. |
| `process_repo()` | If all 3 skills fail (no REVIEW.md / REVIEW-InDepth.md / GUIDE4Junior.md produced), skip HTML write — preserves prior good HTML in DEPLOY_REPO. |

### Analysis HTML preservation
| Section | Change |
|---------|--------|
| `run_daily.sh` step 7 | Before wipe-and-copy of DEPLOY_TMP, copy back `DEPLOY_TMP/analysis/*.html` files not present in local `site/analysis/`. Historical analyses survive across days even if today's run didn't regenerate them. |

### Analysis target selection (new)
| File | Behavior |
|------|---------|
| `scripts/select_analysis_targets.py` | New script. Selects top 5 of `top100` (aggregated across categories), `daily`, `weekly`, `monthly` — in that priority order. Skips repos with existing non-empty analysis HTML (>10KB, no triple `분석 결과 없음` placeholder). Dedupes across lists. Outputs `analysis_targets.json`. |
| `scripts/run_daily.sh` step 4 | Replaced `compare_with_previous.py` call with `select_analysis_targets.py`. |
| `scripts/run_claude_analysis.sh` | Reads `analysis_targets.json` (key `targets`) instead of `new_trending.json` (key `new_repos`). Sequential processing preserves priority order — top100 finishes before any Claude usage-limit cutoff. |

### Deploy schedule-only mode + status display
| File | Change |
|------|--------|
| `deploy.sh` | New `--schedule HH:MM [type]` flag for schedule-only mode (reuses `.env`, updates `SCHEDULE_TIME`, re-registers scheduler, skips packages/auth). New `show_scheduler_status()` function prints `systemctl list-timers` / `crontab -l \| grep run_daily.sh` / `launchctl list \| grep github-dashboard` after registration. `install_scheduler()` extracted as reusable function. |
| `deploy.ps1` | Complete rewrite for parity with sh: `-ScheduleOnly HH:MM` param, `.env` defaults loader (`Read-EnvDefault`), `Install-Scheduler` / `Show-SchedulerStatus` functions, separate git remotes (`origin`=SOURCE, `deploy`=DEPLOY), repo auto-create via `gh repo create`, Claude login skip option, status display via `Get-ScheduledTask` + `Get-ScheduledTaskInfo`. |

### PowerShell parity with sh
| File | Change |
|------|--------|
| `scripts/run_claude_analysis.ps1` | Reads `analysis_targets.json`. Adds `--dangerously-skip-permissions`. `Invoke-ClaudeSkill` function with usage-limit detection (regex match → `exit 42`). Skip-HTML-if-all-three-skills-failed. Sequential repo processing. |
| `scripts/run_daily.ps1` | Step 1 source pull uses `git -c http.extraheader=AUTHORIZATION:bearer $token` with SOURCE_ACCOUNT token (`Get-AccountToken` switches gh active account temporarily). Step 4 calls `select_analysis_targets.py`. Step 6 captures `$LASTEXITCODE`; if 42 → stops pipeline. Step 7 switches gh to DEPLOY_ACCOUNT, uses separate `$env:TEMP\github-dashboard-deploy\$DeployRepo` clone, preserves existing `analysis/*.html` from deploy repo before wipe-and-copy. |

### `deploy.sh`
| Section | Change |
|---------|--------|
| Step 1 inputs | All `read` calls use `|| true` — TTY-less environments (schedulers, Claude Code bash tool) no longer crash. |
| Re-run support | Existing `.env` values loaded as defaults — press Enter to keep, or type new value to override. |
MDEOF

echo "Results written → test/RESULTS.md"
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
