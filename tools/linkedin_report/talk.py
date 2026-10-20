"""Who-to-talk-to page for one person's own export.

Usage: python3 -I tools/linkedin_report/talk.py <export_dir>

Reads Connections.csv plus, when present, Jobs/Saved Jobs.csv, Company Follows.csv,
Invitations.csv, Education.csv and Positions.csv. Companies and titles are judged
by engine.py (rules, open data, cache, then Claude for the rest; Claude never sees
names). Writes <export_dir>/talk.html. Output names connections, who never signed
up, so it is for the export's owner only.
"""
import csv
import json
import os
import re
import sys
from datetime import date, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)  # python3 -I doesn't add the script's folder
from engine import has, judge, load_json, norm, org_key  # noqa: E402
from report import load_connections  # noqa: E402

# Goal tracks, inferred from saved-job titles.
TRACKS = {
    "swe": ("Software engineering", ["software", "engineer", "engineering", "developer", "full stack", "front end", "backend", "swe"]),
    "quant": ("Quant", ["quant", "quantitative", "trader", "trading"]),
    "ai": ("AI / ML", ["ai", "artificial intelligence", "machine learning", "ml", "data scientist", "deep learning"]),
    "markets": ("Markets & investing", ["summer analyst", "investment", "investing", "markets", "sales and trading", "investment banking", "private equity", "equity research", "asset"]),
    "startups": ("Startups", ["founder", "founding", "startup", "venture"]),
}
GENERIC = {"the", "university", "college", "program", "school", "of", "inc", "llc", "ltd", "corp", "corporation", "co"}


def read_csv(export_dir, name):
    path = os.path.join(export_dir, name)
    if not os.path.exists(path):
        return []
    with open(path, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def affiliations(export_dir):
    """Your own schools and orgs as (label, match terms) for shared-background hooks."""
    names = [r["School Name"] for r in read_csv(export_dir, "Education.csv")]
    names += [r["Company Name"] for r in read_csv(export_dir, "Positions.csv")]
    out = []
    for name in names:
        words = [w for w in norm(name).split() if w not in GENERIC]
        if not words:
            continue
        terms = [" ".join(words)]
        caps = "".join(w[0] for w in name.split() if w[:1].isupper())
        short = 3 <= len(caps) <= 4  # "United World College" -> "UWC"
        if short:
            terms.append(caps.lower())
        out.append((caps if short else re.sub(r"^The ", "", name), terms))
    return out


def shared_with(company, affs):
    return next((label for label, terms in affs if has(norm(company), terms)), None)


def build(export_dir):
    affs = affiliations(export_dir)
    school_cores = [t for _, terms in affs[:len(read_csv(export_dir, "Education.csv"))] for t in terms]
    saved = read_csv(export_dir, os.path.join("Jobs", "Saved Jobs.csv"))
    follows = read_csv(export_dir, "Company Follows.csv")
    connections = load_connections(export_dir)

    goal_counts = {k: sum(has(norm(j["Job Title"]), words) for j in saved) for k, (_, words) in TRACKS.items()}

    # Target companies: where you saved a job (strongest) or follow. Your own
    # schools and orgs are hooks, not targets.
    targets = {}
    for name, kind in [(r["Organization"], "follow") for r in follows] + [(r["Company Name"], "saved") for r in saved]:
        key = org_key(name)
        if not key or shared_with(name, affs) or "puzzle by linkedin" in name.lower():
            continue
        if kind == "saved" or key not in targets:
            targets[key] = {"name": name, "kind": kind}

    companies = [c.get("Company") or "" for c in connections] + [t["name"] for t in targets.values()]
    orgs, roles = judge(companies, [c.get("Position") or "" for c in connections], school_cores)

    invites = {}
    for inv in read_csv(export_dir, "Invitations.csv"):
        url = inv["inviterProfileUrl"] if inv["Direction"] == "INCOMING" else inv["inviteeProfileUrl"]
        invites[url.rstrip("/").lower()] = {"theyInvited": inv["Direction"] == "INCOMING", "note": bool(inv["Message"].strip())}

    unknown_org = {"kind": "unknown", "industry": "unknown", "hires": []}
    unknown_role = {"function": "unknown", "seniority": "unknown", "domains": []}
    people = []
    for c in connections:
        company = " ".join((c.get("Company") or "").split())
        position = " ".join((c.get("Position") or "").split())
        key = org_key(company)
        try:
            days = (date.today() - datetime.strptime(c["Connected On"], "%d %b %Y").date()).days
        except ValueError:
            days = None
        inv = invites.get(c["URL"].rstrip("/").lower(), {})
        people.append({
            "first": c["First Name"], "name": (c["First Name"] + " " + c["Last Name"]).strip(), "url": c["URL"],
            "company": company, "position": position, "orgKey": key, "titleKey": norm(position),
            "org": orgs.get(key, unknown_org), "role": roles.get(norm(position), unknown_role),
            "target": targets[key]["kind"] if key in targets else None,
            "shared": shared_with(company, affs), "days": days,
            "theyInvited": inv.get("theyInvited", False), "note": inv.get("note", False),
        })

    hidden = set(load_json(os.path.join(export_dir, "hidden.json"), []))
    for p in people:
        p["hidden"] = p["url"] in hidden  # shown under "Hidden" so they can be brought back
    return {
        "school": next((r["School Name"] for r in read_csv(export_dir, "Education.csv")), ""),
        "tracks": [{"key": k, "label": l, "count": goal_counts[k]} for k, (l, _) in TRACKS.items()],
        "people": people,
        "targets": [{"key": k, "name": t["name"], "kind": t["kind"], "hires": orgs.get(k, unknown_org)["hires"]}
                    for k, t in targets.items()],
        "total": len(connections),
    }


def main():
    export_dir = sys.argv[1]
    payload = json.dumps(build(export_dir)).replace("</", "<\\/")  # a name can't close <script>
    with open(os.path.join(HERE, "talk_template.html")) as f:
        page = f.read().replace("__DATA__", payload)
    out = os.path.join(export_dir, "talk.html")
    with open(out, "w") as f:
        f.write(page)
    print(out)


if __name__ == "__main__":
    main()
