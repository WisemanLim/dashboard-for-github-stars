#!/usr/bin/env python3
"""Collect GitHub Stars data: Top 100 per category + Trending (daily/weekly/monthly)"""

import json
import os
import sys
import time
from datetime import datetime, timezone, timedelta

import requests
from bs4 import BeautifulSoup

KST = timezone(timedelta(hours=9))
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(ROOT_DIR, "site", "assets")

CATEGORIES = [
    {"slug": "python", "label": "Python"},
    {"slug": "javascript", "label": "JavaScript"},
    {"slug": "typescript", "label": "TypeScript"},
    {"slug": "go", "label": "Go"},
    {"slug": "rust", "label": "Rust"},
    {"slug": "java", "label": "Java"},
    {"slug": "cpp", "label": "C++"},
    {"slug": "machine-learning", "label": "Machine Learning"},
    {"slug": "deep-learning", "label": "Deep Learning"},
    {"slug": "llm", "label": "LLM"},
    {"slug": "ai", "label": "AI"},
    {"slug": "web", "label": "Web"},
    {"slug": "mobile", "label": "Mobile"},
    {"slug": "devops", "label": "DevOps"},
    {"slug": "cloud", "label": "Cloud"},
    {"slug": "database", "label": "Database"},
    {"slug": "security", "label": "Security"},
    {"slug": "blockchain", "label": "Blockchain"},
    {"slug": "game", "label": "Game Dev"},
    {"slug": "data-science", "label": "Data Science"},
]

TRENDING_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml",
    "Accept-Language": "en-US,en;q=0.9",
}


def api_headers():
    h = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "github-stars-dashboard/1.0",
    }
    if GITHUB_TOKEN:
        h["Authorization"] = f"token {GITHUB_TOKEN}"
    return h


def collect_top100(category_slug: str) -> list:
    url = "https://api.github.com/search/repositories"
    params = {
        "q": f"topic:{category_slug}",
        "sort": "stars",
        "order": "desc",
        "per_page": 100,
    }
    for attempt in range(2):
        resp = requests.get(url, headers=api_headers(), params=params, timeout=30)
        if resp.status_code == 403 and attempt == 0:
            reset = int(resp.headers.get("X-RateLimit-Reset", time.time() + 60))
            wait = max(reset - int(time.time()), 10)
            print(f"    Rate limited, waiting {wait}s...")
            time.sleep(wait)
            continue
        resp.raise_for_status()
        break

    items = resp.json().get("items", [])
    return [
        {
            "rank": i + 1,
            "name": r["name"],
            "full_name": r["full_name"],
            "description": r.get("description") or "",
            "url": r["html_url"],
            "stars": r["stargazers_count"],
            "forks": r["forks_count"],
            "language": r.get("language") or "",
            "topics": r.get("topics", []),
            "updated_at": r["updated_at"],
        }
        for i, r in enumerate(items)
    ]


def scrape_trending(since: str = "daily") -> list:
    since_param = {"daily": "", "weekly": "weekly", "monthly": "monthly"}
    url = "https://github.com/trending"
    params = {}
    val = since_param.get(since, "")
    if val:
        params["since"] = val

    resp = requests.get(url, headers=TRENDING_HEADERS, params=params, timeout=30)
    resp.raise_for_status()

    soup = BeautifulSoup(resp.text, "html.parser")
    repos = []

    for i, article in enumerate(soup.select("article.Box-row")):
        try:
            a_tag = article.select_one("h2 a")
            if not a_tag:
                continue
            full_name = a_tag.get("href", "").strip("/")
            parts = full_name.split("/")
            if len(parts) < 2:
                continue
            owner, name = parts[0], parts[1]

            desc_tag = article.select_one("p")
            description = desc_tag.get_text(strip=True) if desc_tag else ""

            lang_tag = article.select_one("span[itemprop='programmingLanguage']")
            language = lang_tag.get_text(strip=True) if lang_tag else ""

            stars, forks = 0, 0
            for link in article.select("a.Link--muted"):
                href = link.get("href", "")
                text = link.get_text(strip=True).replace(",", "")
                try:
                    if "stargazers" in href:
                        stars = int(text)
                    elif "forks" in href:
                        forks = int(text)
                except ValueError:
                    pass

            gained_tag = article.select_one("span.d-inline-block.float-sm-right")
            stars_gained = gained_tag.get_text(strip=True) if gained_tag else ""

            repos.append(
                {
                    "rank": i + 1,
                    "name": name,
                    "full_name": full_name,
                    "owner": owner,
                    "description": description,
                    "url": f"https://github.com/{full_name}",
                    "stars": stars,
                    "forks": forks,
                    "language": language,
                    "stars_gained": stars_gained,
                    "topics": [],
                }
            )
        except Exception as e:
            print(f"    Parse error at trending #{i}: {e}")

    return repos


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    now_kst = datetime.now(KST)
    generated_at = now_kst.strftime("%Y-%m-%d %H:%M:%S KST")
    print(f"[collect_data] Starting at {generated_at}")

    categories = []
    for cat in CATEGORIES:
        print(f"  → Top 100: {cat['label']}")
        try:
            top100 = collect_top100(cat["slug"])
            categories.append({"slug": cat["slug"], "label": cat["label"], "top100": top100})
            time.sleep(1.5)
        except Exception as e:
            print(f"    ERROR: {e}")
            categories.append({"slug": cat["slug"], "label": cat["label"], "top100": []})

    trending = {}
    for period in ["daily", "weekly", "monthly"]:
        print(f"  → Trending: {period}")
        try:
            trending[period] = scrape_trending(period)
            time.sleep(2)
        except Exception as e:
            print(f"    ERROR: {e}")
            trending[period] = []

    data = {
        "generated_at": generated_at,
        "generated_at_iso": now_kst.isoformat(),
        "source": {"top100": "GitHub Search API", "trending": "GitHub Trending"},
        "categories": categories,
        "trending": trending,
    }

    out_path = os.path.join(OUTPUT_DIR, "data.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"[collect_data] Saved → {out_path}")
    total_top = sum(len(c["top100"]) for c in categories)
    print(
        f"  categories={len(categories)}, top100_total={total_top}, "
        f"daily={len(trending.get('daily', []))}, "
        f"weekly={len(trending.get('weekly', []))}, "
        f"monthly={len(trending.get('monthly', []))}"
    )


if __name__ == "__main__":
    main()
