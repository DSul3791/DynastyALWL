#!/usr/bin/env python3
"""Smoke test, part 2: one real terrain server (headless), then one real terrain client (headless) per self-test flag, each playing a piece of the first hour
(gather, chop, fire, lean-to, cook, sleep, spear, creatures, plantpick, chest, arrival...). Every line of server and client output is kept in
art/playthrough/smoke/logs/<name>.log; smoke_report.py turns the logs into SMOKE_TEST.md.   python art/playthrough/smoke_clients.py [flag,flag,...]"""
import os
import subprocess
import sys
import tempfile
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GODOT = os.environ.get("GODOT_EXE", "C:/GodotInstaller/godot.windows.editor.x86_64.exe")
LOGS = os.path.join(ROOT, "art", "playthrough", "smoke", "logs")
os.makedirs(LOGS, exist_ok=True)
PLAN = [("arrival", ["--arrival"], 2600), ("gather", ["--gather"], 12000), ("plantpick", ["--plantpick"], 6000), ("chop", ["--chop"], 8000),
        ("fire", ["--fire"], 6000), ("cook", ["--cook"], 6000), ("leanto", ["--leanto"], 4000), ("sleep", ["--sleep"], 6000), ("spear", ["--spear"], 6000),
        ("creatures", ["--creatures"], 6000), ("snare", ["--snare"], 6000), ("chest", ["--chest"], 3500), ("quickkeys", ["--quickkeys"], 3500), ("eat", ["--eat"], 7000),
        ("placed", ["--placed"], 5000), ("walk", ["--walk"], 5000)]
only = set(sys.argv[1].split(",")) if len(sys.argv) > 1 else None
store = tempfile.mkdtemp(prefix="smoke_store_")
port = 7990
server_log = open(os.path.join(LOGS, "server.log"), "w", encoding="utf8")
server = subprocess.Popen([GODOT, "--headless", "--path", ROOT, "res://scenes/terrain_server/terrain_server.tscn", "--", "--port=%d" % port, "--store=" + store, "--open-admin"], stdout=server_log, stderr=subprocess.STDOUT)
print("server started, waiting 60 s", flush=True)
time.sleep(60)
try:
    for name, flags, frames in PLAN:
        if only and name not in only:
            continue
        started = time.time()
        try:
            out = subprocess.run([GODOT, "--headless", "--path", ROOT, "res://scenes/terrain_client/terrain_client.tscn", "--", "--server=127.0.0.1", "--port=%d" % port, "--frames=%d" % frames] + flags,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf8", errors="replace", timeout=420).stdout
            status = "ran"
        except subprocess.TimeoutExpired as e:
            out = (e.stdout.decode("utf8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")) + "\nSMOKE: TIMEOUT after 420 s"
            status = "timeout"
        open(os.path.join(LOGS, "client_%s.log" % name), "w", encoding="utf8").write(out)
        print("%s: %s in %.0f s, %d lines" % (name, status, time.time() - started, out.count("\n")), flush=True)
finally:
    server.kill()
    server_log.close()
