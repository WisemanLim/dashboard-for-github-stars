#!/usr/bin/env python3
"""Build static dashboard HTML from data.json using Jinja2 template."""

import json
import os

from jinja2 import Environment, FileSystemLoader

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(ROOT_DIR, "site", "assets")
SITE_DIR = os.path.join(ROOT_DIR, "site")
TEMPLATES_DIR = os.path.join(ROOT_DIR, "templates")
ANALYSIS_DIR = os.path.join(SITE_DIR, "analysis")


def load_json(path: str) -> dict:
    if not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def repo_to_filename(full_name: str) -> str:
    return full_name.replace("/", "_")


def get_analyzed_repos() -> set:
    analyzed = set()
    if os.path.exists(ANALYSIS_DIR):
        for fname in os.listdir(ANALYSIS_DIR):
            if fname.endswith(".html"):
                analyzed.add(fname[:-5])
    return analyzed


def main():
    data = load_json(os.path.join(ASSETS_DIR, "data.json"))
    if not data:
        print("[build] WARNING: data.json not found, generating placeholder dashboard")
        data = {
            "generated_at": "N/A",
            "generated_at_iso": "",
            "categories": [],
            "trending": {"daily": [], "weekly": [], "monthly": []},
        }

    analyzed_repos = get_analyzed_repos()

    # Annotate trending repos with analysis availability
    for period in ("daily", "weekly", "monthly"):
        for repo in data.get("trending", {}).get(period, []):
            fn = repo_to_filename(repo.get("full_name", ""))
            repo["has_analysis"] = fn in analyzed_repos
            repo["analysis_file"] = f"analysis/{fn}.html"

    env = Environment(loader=FileSystemLoader(TEMPLATES_DIR), autoescape=False)
    template = env.get_template("dashboard.html.j2")

    rendered = template.render(
        data=data,
        categories=data.get("categories", []),
        trending=data.get("trending", {}),
        generated_at=data.get("generated_at", "N/A"),
        data_json=json.dumps(data, ensure_ascii=False),
    )

    out_path = os.path.join(SITE_DIR, "index.html")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(rendered)

    print(f"[build] Dashboard written → {out_path}")


if __name__ == "__main__":
    main()
