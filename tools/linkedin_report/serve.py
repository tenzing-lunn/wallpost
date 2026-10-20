"""Serve the who-to-talk-to page locally and save "Not right?" corrections.

Usage: python3 -I tools/linkedin_report/serve.py <export_dir>   then open http://127.0.0.1:8765

Company and title fixes go to data/cache/corrections.json (shared: no names).
"Not useful to me" goes to <export_dir>/hidden.json (yours only). "undo" reverses either.
Rebuilds the page on start so saved corrections take effect.
"""
import json
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from engine import CACHE_DIR, load_json, save_json  # noqa: E402

EXPORT_DIR = sys.argv[1]
FIXES = os.path.join(CACHE_DIR, "corrections.json")
HIDDEN = os.path.join(EXPORT_DIR, "hidden.json")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/", "/talk.html"):
            self.send_error(404)
            return
        with open(os.path.join(EXPORT_DIR, "talk.html"), "rb") as f:
            body = f.read()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path != "/correct":
            self.send_error(404)
            return
        fix = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if fix["type"] == "person":
            hidden = load_json(HIDDEN, [])
            hidden.append(fix["key"])
            save_json(HIDDEN, sorted(set(hidden)))
        elif fix["type"] in ("orgs", "titles"):
            fixes = load_json(FIXES, {"orgs": {}, "titles": {}})
            fixes[fix["type"]][fix["key"]] = {**fix["value"], "source": "user"}
            save_json(FIXES, fixes)
        elif fix["type"] == "undo":
            if fix["value"]["kind"] == "person":
                save_json(HIDDEN, [u for u in load_json(HIDDEN, []) if u != fix["key"]])
            else:
                fixes = load_json(FIXES, {"orgs": {}, "titles": {}})
                fixes[fix["value"]["kind"]].pop(fix["key"], None)
                save_json(FIXES, fixes)
        else:
            self.send_error(400)
            return
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    subprocess.run([sys.executable, "-I", os.path.join(HERE, "talk.py"), EXPORT_DIR], check=True)
    print("Open http://127.0.0.1:8765")
    HTTPServer(("127.0.0.1", 8765), Handler).serve_forever()
