#!/usr/bin/env python3
"""Self-test for tools/picture_check.py with a fake API on this machine (no key, no credits, no Godot).

    python3 tools/test_picture_check.py

1. Two pictures, one answered "ok" and one "problem": exit 1, the report lists the problem, the ledger holds the real cost
   of both answers (from the fake usage) and no reservation is left.
2. The same run again: both answers are reused, nothing is sent, the ledger does not move, exit 1.
3. A cap below one picture's worst case: nothing is sent, exit 3, the report says the cap stopped it.
4. A reservation left by a cut-off run counts as spent on the next start.
5. The key never appears in the report, the ledger or the stored answers.
6. --dry-run needs no key and sends nothing.
7. picture_sweep.py with a stand-in Godot (a script that writes the pictures): --max-jobs 2 runs two held-item jobs, writes their
   about.txt, and a second --list counts them done (a resumed sweep skips them).
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
		label = body["messages"][0]["content"][1]["text"]
		if "bad" in label:
			answer = {"shows": "a deer", "verdict": "problem", "problems": [{"kind": "floating", "where": "front hooves",
				"what": "the deer hovers 10 cm above the grass", "severity": "high", "confidence": "high"}]}
		else:
			answer = {"shows": "a deer", "verdict": "ok", "problems": []}
		reply = {"stop_reason": "end_turn", "content": [{"type": "text", "text": json.dumps(answer)}],
			"usage": {"input_tokens": 1000, "output_tokens": 500, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}}
		data = json.dumps(reply).encode()
		self.send_response(200)
		self.send_header("content-type", "application/json")
		self.send_header("content-length", str(len(data)))
		self.end_headers()
		self.wfile.write(data)

	def log_message(self, *a):
		pass


def run(env, *args):
	r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "picture_check.py")] + list(args), env=env,
		capture_output=True, text=True)
	return r.returncode, r.stdout + r.stderr


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
	png(os.path.join(shots, "deer_good.png"), 64, 36)
	png(os.path.join(shots, "deer_bad.png"), 64, 38)
	with open(os.path.join(shots, "about.txt"), "w") as f:
		f.write("a red deer standing on grass")
	env = dict(os.environ, PICTURE_CHECK_HOME=home, PICTURE_CHECK_KEY_FILE=key_file,
		PICTURE_CHECK_API_URL="http://127.0.0.1:%d/v1/messages" % server.server_port,
		PICTURE_CHECK_CANCEL=os.path.join(tmp, "CANCEL"))
	one = (1000 * 4.0 + 500 * 20.0) / 1e6

	code, out = run(env, shots, "--dry-run")
	check(code == 0 and not seen, "dry run exits 0 and sends nothing")

	code, out = run(env, shots)
	ledger = json.load(open(os.path.join(home, "spent.json")))
	report = open(os.path.join(shots, "picture_check.md")).read()
	check(code == 1, "a picture that looks wrong gives exit 1 (got %d)" % code)
	check(len(seen) == 2 and all(s["key"] == KEY for s in seen), "two requests sent with the key in the header")
	check(all("a red deer standing" in s["body"]["messages"][0]["content"][1]["text"] for s in seen), "about.txt reaches the request")
	check("floating" in report and "deer_bad.png" in report, "the report lists the floating deer")
	check(abs(ledger["spent_usd"] - 2 * one) < 1e-9 and ledger["reserved_usd"] == 0.0, "the ledger holds the real cost of two answers")

	code, out = run(env, shots)
	check(len(seen) == 2 and code == 1, "a second run reuses both answers and sends nothing")
	check(abs(json.load(open(os.path.join(home, "spent.json")))["spent_usd"] - 2 * one) < 1e-9, "the ledger did not move")

	png(os.path.join(shots, "deer_new.png"), 64, 40)
	code, out = run(env, shots, "--cap", "0.03")
	report = open(os.path.join(shots, "picture_check.md")).read()
	check(code == 3 and len(seen) == 2, "a cap below the worst case sends nothing and exits 3 (got %d)" % code)
	check("the cap" in report, "the report says the cap stopped it")

	led = json.load(open(os.path.join(home, "spent.json")))
	led["reserved_usd"] = 0.5
	led["cap_usd"] = 150.0
	json.dump(led, open(os.path.join(home, "spent.json"), "w"))
	code, out = run(env, shots, "--max-pictures", "0", "--dry-run")
	code, out = run(env, os.path.join(shots, "deer_good.png"))
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

	fake = os.path.join(tmp, "fake_godot.py")
	with open(fake, "w") as f:
		f.write("import sys, os\nargs = dict(a[2:].split('=', 1) for a in sys.argv if a.startswith('--') and '=' in a)\n"
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
	senv = dict(env, GODOT_EXE=godot)
	r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "picture_sweep.py"), "--out", sweep, "--groups", "held", "--max-jobs", "2"],
		env=senv, cwd=os.path.dirname(HERE), capture_output=True, text=True)
	made = [d for d in os.listdir(os.path.join(sweep, "held"))] if os.path.isdir(os.path.join(sweep, "held")) else []
	check(r.returncode == 3 and len(made) == 2, "the sweep ran two held-item jobs and stopped at --max-jobs (exit %d, %s)" % (r.returncode, made))
	check(all(os.path.isfile(os.path.join(sweep, "held", d, "about.txt")) for d in made), "each sweep folder has its about.txt")
	r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "picture_sweep.py"), "--out", sweep, "--groups", "held", "--list"],
		env=senv, cwd=os.path.dirname(HERE), capture_output=True, text=True)
	check(", 2 done," in r.stdout, "a second look counts those two jobs done: " + r.stdout.splitlines()[0])

	server.shutdown()
	print("%d failure(s)" % len(failures))
	return 1 if failures else 0


if __name__ == "__main__":
	sys.exit(main())
