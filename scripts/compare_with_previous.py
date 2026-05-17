#!/usr/bin/env python3
"""Compare current trending data with previous to find newly trending repos (top 5 for analysis)."""

import json
import os

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(ROOT_DIR, "site", "assets")

PERIOD_ORDER = {"daily": 0, "weekly": 1, "monthly": 2}


def load_json(path: str) -> dict:
    if not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def trending_repos(data: dict) -> dict:
    """Return {full_name: {repo_dict + period}} from all trending periods."""
    result = {}
    for period in ("daily", "weekly", "monthly"):
        for repo in data.get("trending", {}).get(period, []):
            fn = repo.get("full_name", "")
            if fn and fn not in result:
                result[fn] = {**repo, "period": period}
    return result


def main():
    current = load_json(os.path.join(ASSETS_DIR, "data.json"))
    previous = load_json(os.path.join(ASSETS_DIR, "previous_data.json"))

    cur_trending = trending_repos(current)
    prev_names = set(trending_repos(previous).keys())

    new_repos = [
        repo for full_name, repo in cur_trending.items() if full_name not in prev_names
    ]

    new_repos.sort(
        key=lambda r: (PERIOD_ORDER.get(r.get("period", "monthly"), 99), r.get("rank", 99))
    )

    top5 = new_repos[:5]

    # Fill to 5 with top daily if not enough new repos
    if len(top5) < 5:
        existing = {r["full_name"] for r in top5}
        for repo in current.get("trending", {}).get("daily", []):
            if len(top5) >= 5:
                break
            fn = repo.get("full_name", "")
            if fn and fn not in existing:
                top5.append({**repo, "period": "daily"})
                existing.add(fn)

    result = {
        "generated_at": current.get("generated_at", ""),
        "total_new": len(new_repos),
        "new_repos": top5,
    }

    out_path = os.path.join(ASSETS_DIR, "new_trending.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(f"[compare] {len(new_repos)} new trending repos found, top {len(top5)} selected for analysis")
    for r in top5:
        stars = r.get("stars", 0)
        print(f"  [{r.get('period')}] {r.get('full_name')} ★{stars:,}")


if __name__ == "__main__":
    main()
