#!/usr/bin/env python3
"""Checks the tester site's report service (deploy/testersite/service/reports.py) against a fake GitHub, with no network.

  python3 tools/test_tester_site.py

Covers: a bug with a log becomes an issue with the bug form's headings, the tester's name and the log as comments; an idea;
the high-score counts and order (highest total, then alphabetical); a report made while GitHub is down is kept and sent later;
no login = refused; a post without the site's form header = refused; a picture is stored and served; a wrong picture is refused.
"""

import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SERVICE = os.path.join(ROOT, "deploy", "testersite", "service", "reports.py")
PNG = b"\x89PNG\r\n\x1a\n" + b"\0" * 64


class FakeGitHub(BaseHTTPRequestHandler):
    issues, comments, up = [], [], True

    def log_message(self, *a):
        pass

    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if not FakeGitHub.up:
            self.send_response(503)
            self.end_headers()
            return
        assert self.headers["Authorization"] == "Bearer test-token", self.headers["Authorization"]
        if self.path == "/repos/o/qa/issues" and "REFUSE" in data["title"]:
            self.send_response(422)
            self.send_header("Content-Length", "2")
            self.end_headers()
            self.wfile.write(b"{}")
            return
        if self.path == "/repos/o/qa/issues":
            FakeGitHub.issues.append(data)
            n = len(FakeGitHub.issues)
            out = {"number": n, "html_url": f"https://github.com/o/qa/issues/{n}"}
        else:
            FakeGitHub.comments.append((self.path, data))
            out = {"id": len(FakeGitHub.comments)}
        body = json.dumps(out).encode()
        self.send_response(201)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def multipart(fields, files):
    b = uuid.uuid4().hex
    out = b""
    for k, v in fields.items():
        out += f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
    for k, name, data in files:
        out += (f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"; filename=\"{name}\"\r\n"
                f"Content-Type: application/octet-stream\r\n\r\n").encode() + data + b"\r\n"
    return out + f"--{b}--\r\n".encode(), "multipart/form-data; boundary=" + b


def call(port, path, user="slayervegeta", fields=None, files=(), form_header=True):
    headers = {}
    if user:
        headers["X-Dynasty-User"] = user
    data = None
    if fields is not None:
        data, ctype = multipart(fields, files)
        headers["Content-Type"] = ctype
        if form_header:
            headers["X-Dynasty-Form"] = "1"
    req = urllib.request.Request(f"http://127.0.0.1:{port}{path}", data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if r.headers["Content-Type"] == "application/json" else raw)
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


def main():
    gh_port, port = free_port(), free_port()
    gh = ThreadingHTTPServer(("127.0.0.1", gh_port), FakeGitHub)
    threading.Thread(target=gh.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory() as tmp:
        token = os.path.join(tmp, "token")
        with open(token, "w") as f:
            f.write("test-token\n")
        env = dict(os.environ, GITHUB_REPO="o/qa", GITHUB_TOKEN_FILE=token, GITHUB_API=f"http://127.0.0.1:{gh_port}",
                   DATA_DIR=os.path.join(tmp, "data"), PORT=str(port), TESTERS="Zed,alice,slayervegeta")
        proc = subprocess.Popen([sys.executable, SERVICE], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        failures = []

        def check(cond, what):
            print(("ok   " if cond else "FAIL ") + what)
            if not cond:
                failures.append(what)

        try:
            for _ in range(50):
                try:
                    if call(port, "/api/health", user=None)[0] == 200:
                        break
                except OSError:
                    time.sleep(0.1)

            code, j = call(port, "/api/scores")
            check(code == 200 and [p["user"] for p in j["players"]] == ["alice", "slayervegeta", "Zed"]
                  and all(p["total"] == 0 for p in j["players"]), "everyone listed at zero, alphabetical")

            log = ("line\n" * 30000 + "ERROR: the end ``` of the log @dave\n").encode()
            code, j = call(port, "/api/bug", fields={"build": "Build 9250", "title": "Froze in inventory",
                                                     "what": "It froze, ask @dave"},
                            files=[("files", "godot.log", log), ("files", "shot.png", PNG)])
            check(code == 200 and j["sent"] and j["issue_url"].endswith("/issues/1"), "bug filed straight away")
            check(j["score"] == {"bugs": 1, "ideas": 0, "total": 1}, "the answer carries the tester's new score")
            issue = FakeGitHub.issues[0]
            check(issue["title"] == "[Bug] Froze in inventory" and issue["labels"] == ["bug", "tester-site"], "bug title and labels")
            check("**slayervegeta**" in issue["body"] and "### What happened?" in issue["body"]
                  and "`godot.log`" in issue["body"] and "/api/pictures/1-1.png" in issue["body"], "bug body has the form's headings and the name")
            check("@​dave" in issue["body"], "@mentions cannot ping")
            logs = [c for c in FakeGitHub.comments if c[0] == "/repos/o/qa/issues/1/comments"]
            check(len(logs) == 6 and all(len(c[1]["body"]) < 65536 for c in logs)
                  and "ERROR: the end" in logs[-1][1]["body"], "log posted as comments under GitHub's size limit, end kept")

            code, j = call(port, "/api/bug", fields={"build": "", "what": "x"})
            check(code == 400 and "Build" in j["error"], "bug without a build is refused")
            code, _ = call(port, "/api/bug", user=None, fields={"build": "1", "what": "x"})
            check(code == 401, "no login is refused")
            code, _ = call(port, "/api/bug", fields={"build": "1", "what": "x"}, form_header=False)
            check(code == 403, "post from outside the site's form is refused")
            code, j = call(port, "/api/bug", fields={"build": "1", "what": "x"}, files=[("files", "x.zip", b"PK\x03\x04\x00\x01")])
            check(code == 400 and "x.zip" in j["error"], "a file that is neither text nor a picture is refused")

            FakeGitHub.up = False
            code, j = call(port, "/api/idea", user="alice", fields={"idea": "Name my horse"},
                            files=[("files", "a.png", PNG)])
            check(code == 200 and not j["sent"], "idea kept while GitHub is down")
            code, j = call(port, "/api/scores")
            check(j["waiting"] == 1 and [(p["user"], p["total"]) for p in j["players"]][:2] == [("alice", 1), ("slayervegeta", 1)],
                  "a waiting report already counts; equal totals alphabetical")
            code, pic = call(port, "/api/pictures/1-1.png")
            check(code == 200 and pic == PNG, "picture stored and served")
            FakeGitHub.up = True
            # The sender retries on a timer; nudge it with another report rather than wait two minutes.
            code, j = call(port, "/api/idea", user="Zed", fields={"idea": "More rivers"})
            for _ in range(40):
                if len(FakeGitHub.issues) >= 3:
                    break
                time.sleep(0.25)
            titles = [i["title"] for i in FakeGitHub.issues]
            check(titles[1:] == ["[Idea] Name my horse", "[Idea] More rivers"], "the waiting idea went first once GitHub was back")
            check("Screenshots" not in FakeGitHub.issues[1]["body"], "the idea form takes no files")
            code, j = call(port, "/api/scores")
            check(j["waiting"] == 0 and j["players"][0]["user"] == "alice" and len(j["recent"]) == 3, "scores and latest list")
            n_before = len(FakeGitHub.issues)
            call(port, "/api/idea", user="Zed", fields={"title": "REFUSE me", "idea": "x"})
            call(port, "/api/idea", user="Zed", fields={"idea": "After the refused one"})
            for _ in range(40):
                if len(FakeGitHub.issues) > n_before:
                    break
                time.sleep(0.25)
            check(FakeGitHub.issues[-1]["title"] == "[Idea] After the refused one",
                  "a report GitHub refuses (422) does not hold up the ones after it")
            code, j = call(port, "/api/me", user="DungeonMaster")
            check(j == {"user": "DungeonMaster"}, "/api/me gives the login name")
        finally:
            proc.terminate()
            out = proc.communicate(timeout=10)[0]
        gh.shutdown()
        if failures:
            print(out)
            print(f"{len(failures)} check(s) failed")
            return 1
        print("all tester-site checks passed")
        return 0


if __name__ == "__main__":
    sys.exit(main())
