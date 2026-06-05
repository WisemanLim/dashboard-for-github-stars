#!/usr/bin/env python3
"""Select analysis targets in priority order: top100 → daily → weekly → monthly.

Rules:
- Take top 5 of each list (top100 aggregated across categories, trending direct).
- Skip a repo if its analysis HTML already exists with real content.
  (Implicit "same as yesterday" check — yesterday's analysis HTML survives via
  run_daily.sh preservation logic, so existing HTML means no re-analysis needed.)
- Dedupe across lists (a repo appearing in multiple lists is analyzed once,
  retaining its first-encountered priority slot).
- Output ordered list — run_claude_analysis.sh processes sequentially so the
  highest-priority repos finish before any Claude usage-limit cutoff.
"""

import json
import os
from typing import Dict, List, Set

from analysis_status import is_complete

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(ROOT_DIR, "site", "assets")

LIST_ORDER = ["top100", "daily", "weekly", "monthly"]
TOP_N = 5


def load_json(path: str) -> dict:
    if not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def aggregated_top100(data: dict, n: int) -> List[Dict]:
    """Dedupe top100 entries across categories, return top N by stars."""
    seen: Dict[str, Dict] = {}
    for cat in data.get("categories", []):
        for r in cat.get("top100", []):
            fn = r.get("full_name", "")
            if not fn:
                continue
            if fn not in seen or r.get("stars", 0) > seen[fn].get("stars", 0):
                seen[fn] = r
    result = sorted(seen.values(), key=lambda x: -x.get("stars", 0))[:n]
    return [{**r, "period": "top100"} for r in result]


def trending_top(data: dict, period: str, n: int) -> List[Dict]:
    return [
        {**r, "period": period}
        for r in data.get("trending", {}).get(period, [])[:n]
    ]


def list_for(data: dict, key: str, n: int) -> List[Dict]:
    if key == "top100":
        return aggregated_top100(data, n)
    return trending_top(data, key, n)


def has_real_analysis(full_name: str) -> bool:
    """True only if a COMPLETE analysis HTML exists (all 3 tabs filled).

    Incomplete analyses — missing, fully empty, or partial (any tab still
    showing a "no result" sentinel) — return False so the repo is re-selected
    and the missing tabs get another pass. See analysis_status.is_complete.
    """
    return is_complete(full_name)


def main():
    current = load_json(os.path.join(ASSETS_DIR, "data.json"))

    targets: List[Dict] = []
    seen: Set[str] = set()
    summary_per_list: Dict[str, Dict[str, int]] = {}

    for list_key in LIST_ORDER:
        top_n = list_for(current, list_key, TOP_N)
        selected_in_list = 0
        skipped_existing = 0
        skipped_dupe = 0
        for repo in top_n:
            fn = repo.get("full_name", "")
            if not fn:
                continue
            if fn in seen:
                skipped_dupe += 1
                continue
            if has_real_analysis(fn):
                seen.add(fn)
                skipped_existing += 1
                continue
            seen.add(fn)
            targets.append(repo)
            selected_in_list += 1
        summary_per_list[list_key] = {
            "candidates": len(top_n),
            "selected": selected_in_list,
            "skipped_existing_analysis": skipped_existing,
            "skipped_duplicate": skipped_dupe,
        }

    result = {
        "generated_at": current.get("generated_at", ""),
        "list_order": LIST_ORDER,
        "top_n_per_list": TOP_N,
        "total_targets": len(targets),
        "summary": summary_per_list,
        "targets": targets,
    }

    out_path = os.path.join(ASSETS_DIR, "analysis_targets.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(
        f"[select_targets] {len(targets)} target(s) selected "
        f"(order: {' → '.join(LIST_ORDER)})"
    )
    for list_key in LIST_ORDER:
        s = summary_per_list.get(list_key, {})
        print(
            f"  {list_key:8s}: candidates={s.get('candidates', 0)} "
            f"selected={s.get('selected', 0)} "
            f"skipped_existing={s.get('skipped_existing_analysis', 0)} "
            f"skipped_dupe={s.get('skipped_duplicate', 0)}"
        )
    for r in targets:
        print(
            f"  → [{r.get('period')}] rank={r.get('rank', '?')} "
            f"{r.get('full_name')} ★{r.get('stars', 0):,}"
        )


if __name__ == "__main__":
    main()
