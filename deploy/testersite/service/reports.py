#!/usr/bin/env python3
"""Dynasty tester reports: the small service behind the tester site's bug and idea forms (deploy/testersite/INSTALL.md).

Caddy checks the tester's login, then passes /api/* here with the login name in the X-Dynasty-User header (it overwrites any
header of that name the browser sent, so nobody can post as somebody else). This service:
  - saves every report in a SQLite file first, so a report is never lost if GitHub cannot be reached,
  - files it as an issue on the QA repo (same headings as its bug.yml / idea.yml forms) with the tester's name in it,
    and posts an attached game log or crash report as comments under the issue,
  - keeps the counts for the front page's high-score table.

Python standard library only (no pip installs). Settings come from environment variables (compose.yaml):
  GITHUB_REPO        owner/name of the QA repo                     default DSul3791/DynastyALWL-QA
  GITHUB_TOKEN_FILE  file holding a fine-grained token (Issues: read and write on that repo only)
  GITHUB_API         default https://api.github.com (the tests point it at a fake)
  DATA_DIR           where reports.db and pictures/ live (never inside the web site folder)
  SITE_URL           public address, used for picture links in issues
  TESTERS            comma-separated login names always shown on the high-score table, even at zero
  PORT               default 8080

Commands (docker exec dynasty-reports python /app/reports.py <command>):
  list               the last 30 reports and whether each reached GitHub
  remove <id>        take a report off the high-score table (the GitHub issue is not touched)
Waiting reports are retried every two minutes, and at once after `docker restart dynasty-reports`.
"""

import email.parser
import email.policy
import json
import os
import re
import sqlite3
import sys
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPO = os.environ.get("GITHUB_REPO", "DSul3791/DynastyALWL-QA")
TOKEN_FILE = os.environ.get("GITHUB_TOKEN_FILE", "/run/secrets/github_token")
API = os.environ.get("GITHUB_API", "https://api.github.com").rstrip("/")
DATA_DIR = os.environ.get("DATA_DIR", "/data")
SITE_URL = os.environ.get("SITE_URL", "https://hannibalshouse.duckdns.org").rstrip("/")
TESTERS = [t.strip() for t in os.environ.get("TESTERS", "").split(",") if t.strip()]
PORT = int(os.environ.get("PORT", "8080"))
USER_HEADER = "X-Dynasty-User"
FORM_HEADER = "X-Dynasty-Form"  # pages send it; another web site cannot without the browser asking first (stops forged posts)

MAX_REQUEST = 30 * 1024 * 1024       # whole form, pictures included
MAX_TEXT = 20000                     # one text box
MAX_TITLE = 120
MAX_LOG_CHARS = 360000               # keep the end of a long log: that is where the crash is
COMMENT_CHARS = 60000                # GitHub's limit is 65536 per comment
MAX_PICTURES = 4
MAX_PICTURE = 8 * 1024 * 1024
PER_HOUR = 20                        # reports per tester per hour
RETRY_SECONDS = 120

FORMS = {
    # kind: (title prefix, label, [(field, heading, required)], [file fields])
    "bug": ("[Bug] ", "bug", [
        ("build", "Build", True),
        ("what", "What happened?", True),
        ("expected", "What did you expect?", False),
        ("steps", "How can we make it happen again?", False),
        ("where", "Where and when", False),
    ], ["log", "crash"]),
    "idea": ("[Idea] ", "idea", [
        ("build", "Build", False),
        ("idea", "Your idea", True),
        ("why", "Why would it help?", False),
    ], []),
}
FILE_HEADINGS = {"log": "Game log (godot.log)", "crash": "Crash report"}
PICTURE_TYPES = {b"\x89PNG": "png", b"\xff\xd8\xff": "jpg", b"GIF8": "gif", b"RIFF": "webp"}

DB_LOCK = threading.Lock()
WAKE = threading.Event()
_db = None


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def db():
    global _db
    if _db is None:
        os.makedirs(os.path.join(DATA_DIR, "pictures"), exist_ok=True)
        _db = sqlite3.connect(os.path.join(DATA_DIR, "reports.db"), check_same_thread=False)
        _db.row_factory = sqlite3.Row
        _db.execute("PRAGMA journal_mode=WAL")
        _db.execute("""CREATE TABLE IF NOT EXISTS reports (
            id INTEGER PRIMARY KEY, kind TEXT, user TEXT, created TEXT, title TEXT, body TEXT,
            comments TEXT, comments_sent INTEGER DEFAULT 0, status TEXT DEFAULT 'waiting',
            issue_number INTEGER, issue_url TEXT, tries INTEGER DEFAULT 0, last_error TEXT)""")
        _db.commit()
    return _db


def query(sql, args=(), commit=False):
    with DB_LOCK:
        cur = db().execute(sql, args)
        rows = cur.fetchall()
        if commit:
            db().commit()
        return rows, cur.lastrowid


# ---------------------------------------------------------------- building the issue

def no_mentions(text):
    # A zero-width space after @ stops GitHub notifying whoever a tester happens to name.
    return re.sub(r"@(?=\w)", "@​", text)


def clean(text, limit):
    text = (text or "").replace("\r\n", "\n").replace("\x00", "").strip()
    return no_mentions(text[:limit])


def fence(text):
    return "````text\n" + text.replace("````", "` ` ` `") + "\n````"


def build_issue(kind, user, fields, files, picture_names):
    prefix, label, spec, _ = FORMS[kind]
    lines = [f"_Sent from the tester site by **{user}** on {now()}._", ""]
    for name, heading, _req in spec:
        value = fields.get(name) or "_No response_"
        lines += [f"### {heading}", "", value, ""]
    if kind == "bug":
        attached = [FILE_HEADINGS[k] for k in FORMS[kind][3] if files.get(k)]
        lines += ["### Your game log", "", ("Attached below as comments: " + ", ".join(attached) + ".")
                  if attached else "_No response_", ""]
    if picture_names:
        lines += ["### Screenshots", "", "On the tester site (log in with a tester name to see them):", ""]
        lines += [f"- {SITE_URL}/api/pictures/{p}" for p in picture_names]
        lines.append("")
    first = fields.get("title") or (fields.get("what") or fields.get("idea") or "").split("\n")[0]
    title = prefix + (first[:MAX_TITLE].strip() or "(no title)")
    comments = []
    for key, text in files.items():
        if not text:
            continue
        cut = len(text) > MAX_LOG_CHARS
        text = text[-MAX_LOG_CHARS:]
        parts = [text[i:i + COMMENT_CHARS] for i in range(0, len(text), COMMENT_CHARS)]
        for n, part in enumerate(parts, 1):
            head = f"**{FILE_HEADINGS[key]}**, part {n} of {len(parts)}"
            if cut and n == 1:
                head += " (the start was cut; this is the last part of the file)"
            comments.append(head + "\n\n" + fence(part))
    return title, "\n".join(lines), comments, label


# ---------------------------------------------------------------- sending to GitHub

def token():
    with open(TOKEN_FILE, encoding="utf-8") as f:
        return f.read().strip()


def github(method, path, payload):
    req = urllib.request.Request(API + path, data=json.dumps(payload).encode(), method=method, headers={
        "Authorization": "Bearer " + token(), "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "dynasty-tester-site", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read() or b"{}")


def send_one(row):
    rid = row["id"]
    number, url = row["issue_number"], row["issue_url"]
    if number is None:
        label = FORMS[row["kind"]][1]
        issue = github("POST", f"/repos/{REPO}/issues",
                       {"title": row["title"], "body": row["body"], "labels": [label, "tester-site"]})
        number, url = issue["number"], issue["html_url"]
        query("UPDATE reports SET issue_number=?, issue_url=? WHERE id=?", (number, url, rid), commit=True)
    comments = json.loads(row["comments"] or "[]")
    for i in range(row["comments_sent"], len(comments)):
        github("POST", f"/repos/{REPO}/issues/{number}/comments", {"body": comments[i]})
        query("UPDATE reports SET comments_sent=? WHERE id=?", (i + 1, rid), commit=True)
    query("UPDATE reports SET status='sent', last_error=NULL WHERE id=?", (rid,), commit=True)


def send_waiting():
    rows, _ = query("SELECT * FROM reports WHERE status='waiting' ORDER BY id")
    for row in rows:
        try:
            send_one(row)
        except Exception as e:  # anything: keep the report, try again later
            detail = str(e)
            if isinstance(e, urllib.error.HTTPError):
                detail = f"GitHub said {e.code}: {e.read()[:300].decode(errors='replace')}"
            query("UPDATE reports SET tries=tries+1, last_error=? WHERE id=?", (detail[:500], row["id"]), commit=True)
            print(f"report {row['id']} not sent yet: {detail}", flush=True)
            return  # GitHub is down or the token is wrong; the rest wait too


def sender():
    while True:
        try:
            send_waiting()
        except Exception as e:
            print("sender:", e, flush=True)
        WAKE.wait(RETRY_SECONDS)
        WAKE.clear()


# ---------------------------------------------------------------- reading the form

def parse_form(content_type, body):
    msg = email.parser.BytesParser(policy=email.policy.HTTP).parsebytes(
        b"Content-Type: " + content_type.encode() + b"\r\n\r\n" + body)
    fields, uploads = {}, {}
    if not msg.is_multipart():
        return fields, uploads
    for part in msg.iter_parts():
        name = part.get_param("name", header="content-disposition")
        if not name:
            continue
        data = part.get_payload(decode=True) or b""
        if part.get_filename() is not None:
            if data:
                uploads.setdefault(name, []).append(data)
        else:
            fields[name] = data.decode("utf-8", errors="replace")
    return fields, uploads


def picture_ext(data):
    for magic, ext in PICTURE_TYPES.items():
        if data.startswith(magic) and (ext != "webp" or data[8:12] == b"WEBP"):
            return ext
    return None


def take_report(kind, user, fields, uploads):
    """Checks and saves one report. Returns (status code, answer)."""
    _, _, spec, file_keys = FORMS[kind]
    values = {"title": clean(fields.get("title"), MAX_TITLE)}
    for name, heading, required in spec:
        values[name] = clean(fields.get(name), 200 if name in ("build", "where") else MAX_TEXT)
        if required and not values[name]:
            return 400, {"error": f"Please fill in \"{heading}\"."}
    files = {}
    for key in file_keys:
        blobs = uploads.get(key) or []
        if blobs:
            files[key] = blobs[0].decode("utf-8", errors="replace").replace("\x00", "")
    pictures = [p for p in uploads.get("pictures", []) if p][:MAX_PICTURES]
    for p in pictures:
        if len(p) > MAX_PICTURE or not picture_ext(p):
            return 400, {"error": "Pictures must be PNG, JPG, GIF or WebP, up to 8 MB each."}
    hour_ago = datetime.fromtimestamp(time.time() - 3600, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    rows, _ = query("SELECT COUNT(*) AS n FROM reports WHERE user=? AND created>?", (user, hour_ago))
    if rows[0]["n"] >= PER_HOUR:
        return 429, {"error": "That is a lot of reports in one hour. Please wait a little and send the rest."}

    _, rid = query("INSERT INTO reports (kind, user, created) VALUES (?, ?, ?)", (kind, user, now()), commit=True)
    names = []
    for n, p in enumerate(pictures, 1):
        name = f"{rid}-{n}.{picture_ext(p)}"
        with open(os.path.join(DATA_DIR, "pictures", name), "wb") as f:
            f.write(p)
        names.append(name)
    title, body, comments, _ = build_issue(kind, user, values, files, names)
    query("UPDATE reports SET title=?, body=?, comments=? WHERE id=?", (title, body, json.dumps(comments), rid), commit=True)
    WAKE.set()
    # Give GitHub a moment so the tester usually sees the issue link straight away.
    for _ in range(40):
        time.sleep(0.25)
        rows, _ = query("SELECT status, issue_url, tries FROM reports WHERE id=?", (rid,))
        if rows[0]["status"] == "sent" or rows[0]["tries"] > 0:
            break
    row = rows[0]
    return 200, {"id": rid, "sent": row["status"] == "sent", "issue_url": row["issue_url"]}


def scores():
    rows, _ = query("SELECT user, kind, COUNT(*) AS n FROM reports WHERE status != 'removed' GROUP BY user, kind")
    table = {t: {"user": t, "bugs": 0, "ideas": 0} for t in TESTERS}
    for r in rows:
        entry = table.setdefault(r["user"], {"user": r["user"], "bugs": 0, "ideas": 0})
        entry["bugs" if r["kind"] == "bug" else "ideas"] += r["n"]
    players = list(table.values())
    for p in players:
        p["total"] = p["bugs"] + p["ideas"]
    players.sort(key=lambda p: (-p["total"], p["user"].lower()))
    recent, _ = query("SELECT kind, user, created, title, issue_url FROM reports "
                      "WHERE status != 'removed' AND title IS NOT NULL ORDER BY id DESC LIMIT 8")
    waiting, _ = query("SELECT COUNT(*) AS n FROM reports WHERE status='waiting'")
    return {"players": players, "recent": [dict(r) for r in recent], "waiting": waiting[0]["n"]}


# ---------------------------------------------------------------- the web side

class Handler(BaseHTTPRequestHandler):
    server_version = "dynasty-reports"

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} {self.headers.get(USER_HEADER, '-')} " + fmt % args, flush=True)

    def answer(self, code, payload, ctype="application/json", extra=None):
        data = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def user(self):
        name = (self.headers.get(USER_HEADER) or "").strip()
        return name if 0 < len(name) <= 64 and "{" not in name else None

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/api/health":
            return self.answer(200, {"ok": True})
        user = self.user()
        if not user:
            return self.answer(401, {"error": "No tester login came through."})
        if path == "/api/me":
            return self.answer(200, {"user": user})
        if path == "/api/scores":
            return self.answer(200, scores())
        m = re.fullmatch(r"/api/pictures/(\d+-\d\.(png|jpg|gif|webp))", path)
        if m:
            fn = os.path.join(DATA_DIR, "pictures", m.group(1))
            if os.path.isfile(fn):
                with open(fn, "rb") as f:
                    kind = {"jpg": "jpeg"}.get(m.group(2), m.group(2))
                    return self.answer(200, f.read(), "image/" + kind)
        return self.answer(404, {"error": "Not found."})

    def do_POST(self):
        path = self.path.split("?")[0]
        kind = {"/api/bug": "bug", "/api/idea": "idea"}.get(path)
        if not kind:
            return self.answer(404, {"error": "Not found."})
        user = self.user()
        if not user:
            return self.answer(401, {"error": "No tester login came through."})
        if self.headers.get(FORM_HEADER) != "1":
            return self.answer(403, {"error": "Please send reports from the tester site's own form."})
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0 or length > MAX_REQUEST:
            return self.answer(413, {"error": "That is too big to send (30 MB at most, pictures included)."})
        body = self.rfile.read(length)
        ctype = self.headers.get("Content-Type", "")
        if not ctype.startswith("multipart/form-data"):
            return self.answer(400, {"error": "Unexpected form."})
        fields, uploads = parse_form(ctype, body)
        code, payload = take_report(kind, user, fields, uploads)
        return self.answer(code, payload)


def command(args):
    if args[0] == "list":
        rows, _ = query("SELECT id, kind, user, created, status, issue_url, last_error FROM reports ORDER BY id DESC LIMIT 30")
        for r in rows:
            print(f"{r['id']:>5} {r['created']} {r['kind']:4} {r['user']:<24} {r['status']:<8} "
                  f"{r['issue_url'] or ''} {r['last_error'] or ''}")
    elif args[0] == "remove" and len(args) == 2:
        query("UPDATE reports SET status='removed' WHERE id=?", (int(args[1]),), commit=True)
        print(f"Report {args[1]} is off the high-score table.")
    else:
        print(__doc__)


def main():
    if len(sys.argv) > 1:
        return command(sys.argv[1:])
    db()
    if not os.path.isfile(TOKEN_FILE):
        print(f"No GitHub token at {TOKEN_FILE}: reports are saved and wait until it is there.", flush=True)
    threading.Thread(target=sender, daemon=True).start()
    print(f"dynasty-reports on port {PORT}, filing issues on {REPO}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
