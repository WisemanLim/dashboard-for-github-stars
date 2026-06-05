# Test Results

**Date**: 2026-05-21 15:46:17
**Status**: ✅ All tests passed

## Summary

| | Count |
|---|---|
| ✅ Passed | 75 |
| ❌ Failed | 0 |
| Total | 75 |

## Test Details

- ✅ syntax: deploy.sh
- ✅ syntax: scripts/run_daily.sh
- ✅ syntax: scripts/run_claude_analysis.sh
- ✅ .env parse: SOURCE_ACCOUNT
- ✅ .env parse: DEPLOY_ACCOUNT
- ✅ .env parse: DEPLOY_REPO
- ✅ .env parse: SCHEDULE_TIME
- ✅ .env parse: CLAUDE_MODEL
- ✅ .env parse: APP_USER
- ✅ GIT_ASKPASS: username returns 'x-access-token'
- ✅ GIT_ASKPASS: password returns token from env
- ✅ limit detection: detected → 'Claude AI usage limit reached. Reset at 2026-05-22'
- ✅ limit detection: detected → 'You have exceeded your usage limit for today.'
- ✅ limit detection: detected → 'rate limit exceeded, please try again later'
- ✅ limit detection: detected → 'Too many requests — reset at 00:00 UTC'
- ✅ limit detection: no false positive → '## Analysis\nThis is a normal analysis of the repo'
- ✅ limit detection: no false positive → 'The code quality is high. No issues found.'
- ✅ limit detection: no false positive → '# Summary\nGreat project with active maintenance.'
- ✅ exit code 42 captured correctly
- ✅ step6 logic: exit 0 → success
- ✅ step6 logic: exit 1 → non-fatal
- ✅ step6 logic: exit 42 → abort
- ✅ _CLAUDE_LIMIT_EXIT=42 defined in run_claude_analysis.sh
- ✅ limit detection code present in run_claude_analysis.sh
- ✅ run_daily.sh: _pull_source() function defined
- ✅ run_daily.sh: GIT_ASKPASS token injection present
- ✅ run_daily.sh: DEPLOY_ACCOUNT verification before push
- ✅ run_daily.sh: _CLAUDE_LIMIT_EXIT=42 defined
- ✅ select_analysis_targets.py exists
- ✅ select_analysis_targets.py runs without error
- ✅ analysis_targets.json created
- ✅ target count = 18 (5+5+5+5 - 1 dupe - 1 skipped_real)
- ✅ priority order: top100 group first
- ✅ orgA/r0 (real HTML > 10KB) skipped
- ✅ orgA/r1 (empty placeholder HTML) re-selected
- ✅ dedupe across lists works (weekly skipped 1 dupe)
- ✅ run_claude_analysis.sh reads analysis_targets.json
- ✅ run_daily.sh calls select_analysis_targets.py
- ✅ deploy.sh --help works
- ✅ deploy.sh --schedule rejects bad time format
- ✅ deploy.sh: install_scheduler() function defined
- ✅ deploy.sh: show_scheduler_status() function defined
- ✅ deploy.sh: schedule-only branch present
- ✅ deploy.sh: systemd status check present
- ✅ deploy.sh: launchd status check present
- ✅ deploy.sh: cron status check present
- ✅ bash re-exec guard: deploy.sh
- ✅ bash re-exec guard: test.sh
- ✅ bash re-exec guard: scripts/run_daily.sh
- ✅ bash re-exec guard: scripts/run_claude_analysis.sh
- ✅ bash re-exec guard: scripts/bootstrap_server.sh
- ✅ bash re-exec guard: test/test_scripts.sh
- ✅ sh deploy.sh --help works (re-exec via bash)
- ✅ deploy.ps1: -ScheduleOnly parameter present
- ✅ deploy.ps1: Install-Scheduler function defined
- ✅ deploy.ps1: Show-SchedulerStatus function defined
- ✅ deploy.ps1: .env defaults loader present
- ✅ deploy.ps1: deploy remote configured separately
- ✅ run_daily.ps1: calls select_analysis_targets.py
- ✅ run_daily.ps1: handles Claude limit exit code
- ✅ run_daily.ps1: token injection for source pull
- ✅ run_daily.ps1: DEPLOY_ACCOUNT verification present
- ✅ run_daily.ps1: analysis HTML preservation present
- ✅ run_daily.ps1: separate deploy clone (DEPLOY repo)
- ✅ run_claude_analysis.ps1: reads analysis_targets.json
- ✅ run_claude_analysis.ps1: --dangerously-skip-permissions flag present
- ✅ run_claude_analysis.ps1: usage limit detection present
- ✅ run_claude_analysis.ps1: skip-HTML-if-all-failed present
- ✅ run_claude_analysis.ps1: Invoke-ClaudeSkill function defined
- ✅ run_daily.sh: analysis preservation block present
- ✅ run_claude_analysis.sh: skip-HTML-if-all-failed present
- ✅ preservation: copied 2 missing files (A, C)
- ✅ preservation: repoA.html preserved
- ✅ preservation: repoC.html preserved
- ✅ preservation: repoB.html not overwritten (today's content kept)

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
