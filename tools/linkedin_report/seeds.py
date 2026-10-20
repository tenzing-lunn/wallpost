"""Build the shared company seed table from open data, once.

Usage: python3 -I tools/linkedin_report/seeds.py

Downloads (if missing) into data/seeds/ and writes data/seeds/orgs_seed.json:
{normalized key: {"name", "kind", "hires": [tracks]}}. Only company names and
categories are kept; the SimplifyJobs and YC files have no license, so the raw
files stay local and are never redistributed.
"""
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from engine import SEED_DIR, org_key  # noqa: E402

SOURCES = {
    "simplify_internships.json": "https://raw.githubusercontent.com/SimplifyJobs/Summer2027-Internships/dev/.github/scripts/listings.json",
    "simplify_newgrad.json": "https://raw.githubusercontent.com/SimplifyJobs/New-Grad-Positions/dev/.github/scripts/listings.json",
    "universities.json": "https://raw.githubusercontent.com/Hipo/university-domains-list/master/world_universities_and_domains.json",
    "yc.json": "https://yc-oss.github.io/api/companies/all.json",
}
# SimplifyJobs categories -> our goal tracks.
CATEGORY_TRACK = {
    "Software": "swe", "Software Engineering": "swe",
    "AI/ML/Data": "ai", "Data Science, AI & Machine Learning": "ai",
    "Quant": "quant", "Quantitative Finance": "quant",
}


def load(name):
    path = os.path.join(SEED_DIR, name)
    if not os.path.exists(path):
        print("downloading", name)
        urllib.request.urlretrieve(SOURCES[name], path)
    with open(path) as f:
        return json.load(f)


def main():
    os.makedirs(SEED_DIR, exist_ok=True)
    orgs = {}

    def add(name, kind, track=None):
        key = org_key(name)
        if not key:
            return
        org = orgs.setdefault(key, {"name": name, "kind": kind, "hires": []})
        if track and track not in org["hires"]:
            org["hires"].append(track)

    for u in load("universities.json"):
        add(u["name"], "school")
    for c in load("yc.json"):
        for name in [c["name"]] + (c.get("former_names") or []):
            add(name, "startup")
    for f in ("simplify_internships.json", "simplify_newgrad.json"):
        for job in load(f):
            add(job["company_name"], "firm", CATEGORY_TRACK.get(job.get("category")))

    out = os.path.join(SEED_DIR, "orgs_seed.json")
    with open(out, "w") as f:
        json.dump(orgs, f)
    print(out, len(orgs), "orgs")


if __name__ == "__main__":
    main()
