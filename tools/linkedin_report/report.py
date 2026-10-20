"""Private LinkedIn graph + gap report for one person's own export.

Usage: python3 -I tools/linkedin_report/report.py <export_dir> [targets.json]

Reads only Connections.csv from the export. Output is for the export's owner
only: it names connections, who never signed up for anything.
"""
import csv
import json
import os
import re
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))


def load_connections(export_dir):
    path = os.path.join(export_dir, "Connections.csv")
    with open(path, newline="", encoding="utf-8-sig") as f:
        lines = f.read().splitlines()
    # LinkedIn puts a "Notes:" preamble above the real header.
    start = next(i for i, line in enumerate(lines) if line.startswith("First Name"))
    return list(csv.DictReader(lines[start:]))


def tags(text, groups):
    """Names of the keyword groups that match text as whole words."""
    text = (text or "").lower()
    return [
        name for name, words in groups.items()
        if any(re.search(r"\b" + re.escape(w.lower()) + r"\b", text) for w in words)
    ]


def main():
    export_dir = sys.argv[1]
    targets_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "targets.json")
    with open(targets_path) as f:
        targets = json.load(f)

    people = load_connections(export_dir)
    strong, sector_only, role_only = [], [], []
    sector_counts, role_counts, companies = Counter(), Counter(), Counter()

    for p in people:
        company, position = p.get("Company", ""), p.get("Position", "")
        if company:
            companies[company] += 1
        s = [t for t in tags(company, targets["sectors"]) if t in targets["strong_route"]["sectors"]]
        r = [t for t in tags(position, targets["roles"]) if t in targets["strong_route"]["roles"]]
        sector_counts.update(s)
        role_counts.update(r)
        row = (p["First Name"] + " " + p["Last Name"], position, company, s + r)
        if s and r:
            strong.append(row)
        elif s:
            sector_only.append(row)
        elif r:
            role_only.append(row)

    print("# Your graph (private)\n")
    print(f"{len(people)} connections, {len(companies)} companies.\n")

    print("## Top companies")
    for name, n in companies.most_common(10):
        print(f"- {name}: {n}")

    print("\n## By target sector")
    for name in targets["strong_route"]["sectors"]:
        print(f"- {name}: {sector_counts[name]}")

    print("\n## By target role")
    for name in targets["strong_route"]["roles"]:
        print(f"- {name}: {role_counts[name]}")

    print(f"\n## Strong routes: target sector AND target role ({len(strong)})")
    for name, pos, co, t in strong:
        print(f"- {name}: {pos} @ {co}  [{', '.join(t)}]")

    print(f"\n## Partial: right role, other company ({len(role_only)})")
    print("Founders and researchers at companies we don't recognize land here; many are startups.")
    for name, pos, co, t in role_only:
        print(f"- {name}: {pos} @ {co}  [{', '.join(t)}]")

    print(f"\n## Partial: right sector, other role ({len(sector_only)})")
    print("Not shown individually; these are people who could intro you inside the company.")

    print("\n## The gap")
    for name in targets["strong_route"]["sectors"] + targets["strong_route"]["roles"]:
        if sector_counts[name] + role_counts[name] == 0:
            print(f"- No one in {name}.")
    print(f"- Personal fit: 0 of {len(targets['personal'])} traits checkable from the export "
          f"({', '.join(targets['personal'])}). These only come from people joining.")


if __name__ == "__main__":
    main()
