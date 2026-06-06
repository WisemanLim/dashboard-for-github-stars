#!/usr/bin/env python3
"""Shared analysis-completeness check.

An analysis HTML is "complete" when the baseline 소스 분석 (analysis-source) tab
carries real content. The 심층 분석 / 주니어 가이드 tabs are optional (run only
via run_claude_analysis.sh --scope indepth,guide) and do NOT gate completeness.
Used by:
  - select_analysis_targets.py → re-analyze incomplete repos (don't skip them)
  - build_dashboard.py        → only show "분석 보기" for complete analyses

Why per-tab and not a global string count:
  run_claude_analysis.sh writes an "empty" sentinel into any tab whose skill
  failed. The sentinels overlap as substrings ("심층 분석 결과 없음" contains
  "분석 결과 없음"), so a single global count is ambiguous — a fully-empty file
  could look complete. Scoping the check to each panel removes that ambiguity
  and lets is_complete() gate on just the baseline tab.
"""

import os
import re
from typing import Dict, List

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANALYSIS_DIR = os.path.join(ROOT_DIR, "site", "analysis")

# Minimum real-text length (tags stripped) for a tab to count as filled.
# Sentinels render to ~6-12 chars; real analyses are hundreds+.
MIN_TAB_TEXT = 60

# Panels in template order, with the "no result" sentinels each may contain.
# Covers both the run_claude_analysis.sh fallbacks and the j2 empty-notices.
_PANEL_MARKERS: Dict[str, List[str]] = {
    "source": ["소스 분석 결과 없음", "소스 분석 결과가 없습니다"],
    "indepth": ["심층 분석 결과 없음", "심층 분석 결과가 없습니다"],
    "guide": ["가이드 없음", "주니어 가이드가 없습니다"],
}

# Baseline tab that gates completeness. The others are optional (--scope).
_BASELINE_PANEL = "source"

_TAG_RE = re.compile(r"<[^>]+>")
# md output (python-markdown) has no nested <div>, so non-greedy stops at the
# md-body's own closing tag — not the panel's.
_MDBODY_RE = re.compile(r'<div class="md-body">(.*?)</div>', re.S)


def analysis_path(full_name: str) -> str:
    safe = full_name.replace("/", "_")
    return os.path.join(ANALYSIS_DIR, f"{safe}.html")


def _panel_inner(html: str, panel: str) -> str:
    """Inner HTML of one panel, from its opening div to the next panel/footer."""
    m = re.search(
        r'id="panel-%s"\s*>(.*?)(?=<div class="panel"|<footer)' % re.escape(panel),
        html,
        re.S,
    )
    return m.group(1) if m else ""


def _tab_filled(html: str, panel: str) -> bool:
    inner = _panel_inner(html, panel)
    if not inner:
        return False
    for marker in _PANEL_MARKERS[panel]:
        if marker in inner:
            return False
    text = _TAG_RE.sub("", inner).strip()
    return len(text) >= MIN_TAB_TEXT


def tab_status(full_name: str) -> Dict[str, bool]:
    """Per-tab filled-state. Missing file → all False."""
    path = analysis_path(full_name)
    if not os.path.exists(path):
        return {p: False for p in _PANEL_MARKERS}
    try:
        with open(path, "r", encoding="utf-8") as f:
            html = f.read()
    except OSError:
        return {p: False for p in _PANEL_MARKERS}
    return {p: _tab_filled(html, p) for p in _PANEL_MARKERS}


def is_complete(full_name: str) -> bool:
    """True if the baseline (소스 분석) tab has real content.

    Optional tabs (심층 분석 / 주니어 가이드) don't gate completeness — they're
    run only on demand via run_claude_analysis.sh --scope.
    """
    return tab_status(full_name)[_BASELINE_PANEL]


def panel_body_html(full_name: str, panel: str) -> str:
    """Inner md-body HTML of a FILLED tab from the existing analysis, else "".

    Lets a re-analysis run preserve a tab whose skill succeeded previously but
    failed this run — so re-filling missing tabs never wipes good ones.
    """
    path = analysis_path(full_name)
    if not os.path.exists(path):
        return ""
    try:
        with open(path, "r", encoding="utf-8") as f:
            html = f.read()
    except OSError:
        return ""
    if not _tab_filled(html, panel):
        return ""
    inner = _panel_inner(html, panel)
    m = _MDBODY_RE.search(inner)
    return m.group(1).strip() if m else ""
