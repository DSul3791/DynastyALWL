#!/usr/bin/env python3
"""Self-test for tools/picture_check.py with a fake API on this machine (no key, no credits, no Godot).

    python3 tools/test_picture_check.py

0. The pictures of one folder are one subject's views: one request each (at most 8 pictures). The first run ever sends one request only (to compare its cost with the Console before more).
1. Two subjects of two views each, one answered "ok" and one "problem": exit 1, the report lists the problem, the ledger holds the real cost
   of both answers (from the fake usage) and no reservation is left.
2. The same run again: both answers are reused, nothing is sent, the ledger does not move, exit 1.
3. A cap below one picture's worst case: nothing is sent, exit 3, the report says the cap stopped it.
4. A reservation left by a cut-off run counts as spent on the next start.
5. The key never appears in the report, the ledger or the stored answers.
6. --dry-run needs no key and sends nothing.
7. A 429 is retried and answered; a 504 is counted and not retried. A request whose connection drops with no answer is counted at its worst case and not retried; a second check while one
   runs (its lock file there) refuses to start.
8. picture_sweep.py with a stand-in Godot (a script that writes the pictures): --max-jobs 2 runs two held-item jobs, writes their
   about.txt, and a second --list counts them done (a resumed sweep skips them). An item shot_held.gd refuses goes to look_rig.sh. A job that runs past --job-limit is stopped with
   everything it started (a grandchild process too).
"""
import http.server
import json
import os
import struct
import subprocess
import sys
import tempfile
import threading
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
KEY = "sk-test-not-a-real-key-123"
failures = []
seen = []


def check(ok, what):
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


def png(path, w, h):
	raw = b"".join(b"\x00" + b"\x80\x80\x80" * w for _ in range(h))
	def chunk(kind, data):
		return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
	with open(path, "wb") as f:
		f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
			+ chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


class Fake(http.server.BaseHTTPRequestHandler):
	def do_POST(self):
		body = json.loads(self.rfile.read(int(self.headers["content-length"])))
		seen.append({"key": self.headers.get("x-api-key"), "body": body})
		label = text_of(body)
		if "drop" in label:
			self.close_connection = True
			return
		if "busy" in label and not any("busy" in text_of(x["body"]) for x in seen[:-1]):
			self.send_response(429)
			self.send_header("retry-after", "0")
			self.send_header("content-length", "2")
			self.end_headers()
			self.wfile.write(b"{}")
			return
		if "gate" in label:
			self.send_response(504)
			self.send_header("content-length", "2")
			self.end_headers()
			self.wfile.write(b"{}")
			return
		if "pair" in label:
			subjects = [{"subject": "fox", "shows": "a fox", "verdict": "ok", "confidence": "high", "problems": []},
				{"subject": "wolf", "shows": "a wolf", "verdict": "problem", "confidence": "medium", "problems": [{"kind": "sunk",
				"views": ["pair_wolf.png"], "where": "hind legs", "what": "the hind legs are in the ground", "severity": "high", "confidence": "high"}]}]
			subject = None
		elif "bad" in label:
			subject = {"subject": "deer_bad", "shows": "a deer", "verdict": "problem", "confidence": "high", "problems": [{"kind": "floating",
				"views": ["deer_bad_front.png", "deer_bad_side.png"], "where": "front hooves", "what": "the deer hovers 10 cm above the grass",
				"severity": "high", "confidence": "high"}]}
		else:
			subject = {"subject": "deer", "shows": "a deer", "verdict": "ok", "confidence": "high", "problems": []}
		reply = {"stop_reason": "end_turn", "content": [{"type": "text", "text": json.dumps({"subjects": subjects if subject is None else [subject]})}],
			"usage": {"input_tokens": 1000, "output_tokens": 500, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}}
		data = json.dumps(reply).encode()
		self.send_response(200)
		self.send_header("content-type", "application/json")
		self.send_header("content-length", str(len(data)))
		self.end_headers()
		self.wfile.write(data)

	def log_message(self, *a):
		pass


def text_of(body):
	return " ".join(c.get("text", "") for c in body["messages"][0]["content"] if c.get("type") == "text")


def images_of(body):
	return sum(1 for c in body["messages"][0]["content"] if c.get("type") == "image")


def run(env, *args):
	r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "picture_check.py")] + list(args), env=env,
		capture_output=True, text=True)
	return r.returncode, r.stdout + r.stderr


def subject(root, name, views, h=36, about="a red deer standing on grass"):
	folder = os.path.join(root, name)
	os.makedirs(folder, exist_ok=True)
	for i, view in enumerate(views):
		png(os.path.join(folder, "%s_%s.png" % (name, view)), 64, h + i)
	if about:
		with open(os.path.join(folder, "about.txt"), "w") as f:
			f.write(about)
	return folder


def main():
	server = http.server.HTTPServer(("127.0.0.1", 0), Fake)
	threading.Thread(target=server.serve_forever, daemon=True).start()
	tmp = tempfile.mkdtemp(prefix="picture_check_")
	home = os.path.join(tmp, "home")
	shots = os.path.join(tmp, "shots")
	os.makedirs(home)
	os.makedirs(shots)
	key_file = os.path.join(tmp, "key.txt")
	with open(key_file, "w") as f:
		f.write(KEY + "\n")
	good = subject(shots, "deer_good", ["front", "side"], 36)
	subject(shots, "deer_bad", ["front", "side"], 40)
	env = dict(os.environ, PICTURE_CHECK_HOME=home, PICTURE_CHECK_KEY_FILE=key_file,
		PICTURE_CHECK_API_URL="http://127.0.0.1:%d/v1/messages" % server.server_port,
		PICTURE_CHECK_CANCEL=os.path.join(tmp, "CANCEL"))
	one = (1000 * 4.0 + 500 * 20.0) / 1e6

	code, out = run(env, shots, "--dry-run")
	check(code == 0 and not seen and "4 pictures in 2 subject groups" in out, "dry run: two folders are two subjects, nothing sent")
	many = subject(os.path.join(tmp, "many"), "rock", ["v%d" % i for i in range(10)], 20, "")
	code, out = run(env, many, "--dry-run")
	check("2 requests to send (10 pictures)" in out, "ten views of one subject go in two requests of at most 8")

	code, out = run(env, shots)
	check(code == 3 and len(seen) == 1 and "first run ever" in out, "the first run ever sends one request only (exit %d, %d sent)" % (code, len(seen)))
	code, out = run(env, shots)
	ledger = json.load(open(os.path.join(home, "spent.json")))
	report = open(os.path.join(shots, "picture_check.md")).read()
	check(code == 1, "a subject that looks wrong gives exit 1 (got %d)" % code)
	check(len(seen) == 2 and all(s["key"] == KEY for s in seen), "two requests sent with the key in the header")
	check(all(images_of(s["body"]) == 2 for s in seen), "each request carries both views of its subject")
	check(all("View: deer_" in text_of(s["body"]) and "_side.png" in text_of(s["body"]) for s in seen), "each view goes with its file name")
	check(all("a red deer standing" in text_of(s["body"]) for s in seen), "about.txt reaches the request")
	check("floating" in report and "deer_bad_front.png, deer_bad_side.png" in report, "the report lists the floating deer and the views it shows in")
	check(abs(ledger["spent_usd"] - 2 * one) < 1e-9 and ledger["reserved_usd"] == 0.0, "the ledger holds the real cost of two answers")

	code, out = run(env, shots)
	check(len(seen) == 2 and code == 1, "a second run reuses both answers and sends nothing")
	check(abs(json.load(open(os.path.join(home, "spent.json")))["spent_usd"] - 2 * one) < 1e-9, "the ledger did not move")

	subject(shots, "deer_new", ["front"], 50)
	code, out = run(env, shots, "--cap", "0.03")
	report = open(os.path.join(shots, "picture_check.md")).read()
	check(code == 3 and len(seen) == 2, "a cap below the worst case sends nothing and exits 3 (got %d)" % code)
	check("the cap" in report, "the report says the cap stopped it")

	led = json.load(open(os.path.join(home, "spent.json")))
	led["reserved_usd"] = 0.5
	led["cap_usd"] = 150.0
	json.dump(led, open(os.path.join(home, "spent.json"), "w"))
	code, out = run(env, good)
	led = json.load(open(os.path.join(home, "spent.json")))
	check(abs(led["spent_usd"] - (2 * one + 0.5)) < 1e-9 and led["reserved_usd"] == 0.0, "a left reservation counts as spent")

	open(os.path.join(tmp, "CANCEL"), "w").close()
	code, out = run(env, shots)
	check(code == 3 and len(seen) == 2, "the CANCEL file stops it before sending")
	os.remove(os.path.join(tmp, "CANCEL"))

	leaked = []
	for root, _d, files in os.walk(tmp):
		for name in files:
			if name != "key.txt" and KEY.encode() in open(os.path.join(root, name), "rb").read():
				leaked.append(name)
	check(not leaked, "the key is in no file but its own (%s)" % ", ".join(leaked))

	drop = subject(os.path.join(tmp, "drop"), "deer_drop", ["front"], 20)
	before = len(seen)
	spent_before = json.load(open(os.path.join(home, "spent.json")))["spent_usd"]
	code, out = run(env, drop)
	led = json.load(open(os.path.join(home, "spent.json")))
	check(code == 3 and len(seen) == before + 1, "a dropped connection is sent once, not retried (exit %d, %d sent)" % (code, len(seen) - before))
	check(led["spent_usd"] - spent_before > 0.05 and led["reserved_usd"] == 0.0, "and is counted at its worst case ($%.3f)" % (led["spent_usd"] - spent_before))
	busy = os.path.join(tmp, "busy")
	subject(busy, "deer_busy", ["front"], 22)
	subject(busy, "deer_gate", ["front"], 24)
	before = len(seen)
	code, out = run(env, busy)
	check(len(seen) == before + 3, "a 429 is retried once and answered, a 504 is sent once (%d sent)" % (len(seen) - before))
	check("deer_busy (1 pictures): deer ok" in out and "HTTP 504" in out, "the retried subject is checked, the 504 one is listed not checked")
	before = len(seen)
	open(os.path.join(home, "lock"), "w").close()
	code, out = run(env, shots, "--recheck")
	check(code == 2 and "another check is running" in out and len(seen) == before, "a second check refuses to start while the lock is there")
	os.remove(os.path.join(home, "lock"))

	before = len(seen)
	code, out = run(env, many)
	check([images_of(x["body"]) for x in seen[before:]] == [5, 5], "ten views go as two even requests of 5 (%s)" % [images_of(x["body"]) for x in seen[before:]])
	odd = subject(os.path.join(tmp, "odd"), "stone", ["front", "side"], 30)
	open(os.path.join(odd, "stone_top.png"), "wb").write(b"not a png")
	before = len(seen)
	code, out = run(env, odd)
	check(code == 3 and len(seen) == before and "not a PNG: stone_top.png" in open(os.path.join(odd, "picture_check.md")).read(),
		"a group with a file that is not a PNG is listed not checked and nothing is sent")
	pair = os.path.join(tmp, "pair")
	os.makedirs(pair)
	png(os.path.join(pair, "pair_fox.png"), 40, 20)
	png(os.path.join(pair, "pair_wolf.png"), 40, 22)
	code, out = run(env, pair)
	report = open(os.path.join(pair, "picture_check.md")).read()
	check(code == 1 and "**wolf**" in report and "sunk" in report and "1 look wrong, 0 unsure, 1 ok" in report, "two subjects in one folder are reported each on its own")
	os.rename(os.path.join(pair, "pair_wolf.png"), os.path.join(pair, "pair_wolf2.png"))
	before = len(seen)
	code, out = run(env, pair, "--dry-run")
	check("1 requests to send" in out, "a renamed view is a new question (the answer names views by file name)")

	fake = os.path.join(tmp, "fake_godot.py")
	with open(fake, "w") as f:
		f.write("import sys, os, subprocess, time\n"
			"if os.environ.get('FAKE_SLEEP'):\n"
			"    child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(120)'])\n"
			"    open(os.environ['FAKE_SLEEP'], 'w').write(str(child.pid))\n"
			"    time.sleep(120)\n"
			"rig = 'tools/look_rig.sh' in sys.argv\n"
			"if os.environ.get('FAKE_REFUSE') and not rig:\n"
			"    sys.exit(2)\n"
			"args = dict(a[2:].split('=', 1) for a in sys.argv if a.startswith('--') and '=' in a)\n"
			"if rig:\n"
			"    args = dict(zip([a[2:] for a in sys.argv[2::2]], sys.argv[3::2]))\n"
			"    open(os.environ['FAKE_REFUSE'], 'w').write('look_rig ran')\n"
			"os.makedirs(args['out'], exist_ok=True)\n"
			"[open(os.path.join(args['out'], '%s_%s.png' % (args['name'], n)), 'wb').write(b'x') for n in ('right', 'left', 'hand', 'front')]\n")
	if os.name == "nt":
		godot = fake.replace(".py", ".cmd")
		open(godot, "w").write('@"%s" "%s" %%*\n' % (sys.executable, fake))
	else:
		godot = fake.replace(".py", ".sh")
		open(godot, "w").write('#!/bin/sh\nexec "%s" "%s" "$@"\n' % (sys.executable, fake))
		os.chmod(godot, 0o755)
	sweep = os.path.join(tmp, "sweep")
	senv = dict(env, GODOT_EXE=godot, BASH_EXE=godot)
	r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "picture_sweep.py"), "--out", sweep, "--groups", "held", "--max-jobs", "2"],
		env=senv, cwd=os.path.dirname(HERE), capture_output=True, text=True)
	made = [d for d in os.listdir(os.path.join(sweep, "held"))] if os.path.isdir(os.path.join(sweep, "held")) else []
	check(r.returncode == 3 and len(made) == 2, "the sweep ran two held-item jobs and stopped at --max-jobs (exit %d, %s)" % (r.returncode, made))
	check(all(os.path.isfile(os.path.join(sweep, "held", d, "about.txt")) for d in made), "each sweep folder has its about.txt")
	r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "picture_sweep.py"), "--out", sweep, "--groups", "held", "--list"],
		env=senv, cwd=os.path.dirname(HERE), capture_output=True, text=True)
	check(", 2 done," in r.stdout, "a second look counts those two jobs done: " + r.stdout.splitlines()[0])
	rig_mark = os.path.join(tmp, "rig_ran")
	r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "picture_sweep.py"), "--out", sweep, "--groups", "held", "--max-jobs", "1"],
		env=dict(senv, FAKE_REFUSE=rig_mark), cwd=os.path.dirname(HERE), capture_output=True, text=True)
	check(os.path.isfile(rig_mark) and " ok (exit 0" in r.stdout, "an item shot_held refuses (exit 2) is taken by look_rig.sh instead: " + r.stdout.strip().splitlines()[-2])
	pid_file = os.path.join(tmp, "grandchild.pid")
	r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "picture_sweep.py"), "--out", sweep, "--groups", "held", "--max-jobs", "1",
		"--job-limit", "3"], env=dict(senv, FAKE_SLEEP=pid_file), cwd=os.path.dirname(HERE), capture_output=True, text=True, timeout=90)
	alive = True
	if os.path.isfile(pid_file):
		pid = int(open(pid_file).read())
		if os.name == "nt":
			alive = str(pid) in subprocess.run(["tasklist", "/FI", "PID eq %d" % pid], capture_output=True, text=True).stdout
		else:
			try:
				os.kill(pid, 0)
				alive = open("/proc/%d/stat" % pid).read().split()[2] != "Z" if os.path.exists("/proc/%d/stat" % pid) else True
			except OSError:
				alive = False
	check("timeout 3 s" in r.stdout and not alive, "a job past --job-limit is stopped with its grandchild (%s)" % r.stdout.strip().splitlines()[-2:])

	server.shutdown()
	print("%d failure(s)" % len(failures))
	return 1 if failures else 0


if __name__ == "__main__":
	sys.exit(main())
