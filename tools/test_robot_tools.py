#!/usr/bin/env python3
"""Self-test for the robot play-testers' Python tools (no Godot): tools/lossy_link.py and tools/robot_check.py.

    python3 tools/test_robot_tools.py

1. lossy_link: a UDP echo server behind the relay; 300 packets through it must come back late by about twice the delay, a share lost
   near twice the loss (both ways), in order; a TCP echo through the block-line side must come back whole and late.
2. robot_check: hand-written logs that hold every invariant pass (exit 0); a client pack that is not the server's, a ROBOT FAIL line,
   an AUDIT jump, a SCRIPT ERROR and a robot that never finished each fail (exit 1); a missing join is a broken run (exit 2).
"""
import math
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
failures = []


def check(ok, what):
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures.append(what)


def free_port():
	s = socket.socket()
	s.bind(("127.0.0.1", 0))
	p = s.getsockname()[1]
	s.close()
	return p


def test_link():
	server_port = free_port()
	listen = free_port()

	# The relay's block line listens on listen + 1 and forwards to server_port + 1: both must be free.
	while True:
		try:
			for p in (listen + 1, server_port + 1):
				t = socket.socket()
				t.bind(("127.0.0.1", p))
				t.close()
			break
		except OSError:
			server_port, listen = free_port(), free_port()

	udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
	udp.bind(("127.0.0.1", server_port))
	tcp = socket.socket()
	tcp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
	tcp.bind(("127.0.0.1", server_port + 1))
	tcp.listen(1)
	stop = threading.Event()

	def udp_echo():
		udp.settimeout(0.2)

		while not stop.is_set():
			try:
				data, addr = udp.recvfrom(2048)
				udp.sendto(data, addr)
			except socket.timeout:
				pass

	def tcp_echo():
		tcp.settimeout(20)

		try:
			c, _ = tcp.accept()

			while True:
				data = c.recv(65536)

				if not data:
					break

				c.sendall(data)
			c.close()
		except OSError:
			pass

	threading.Thread(target=udp_echo, daemon=True).start()
	threading.Thread(target=tcp_echo, daemon=True).start()
	relay = subprocess.Popen([sys.executable, os.path.join(HERE, "lossy_link.py"), "--listen", str(listen), "--server-port", str(server_port),
		"--delay-ms", "40", "--jitter-ms", "10", "--loss", "0.05", "--seconds", "20"], stdout=subprocess.PIPE, text=True)
	check("LINK up" in relay.stdout.readline(), "lossy_link starts and prints its LINK up line")
	c = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
	c.settimeout(0.5)
	sent = {}
	got = []

	def receive():   # at the same time as the sending, so a reply's delay is not its wait in the socket buffer
		end = time.monotonic() + 4.0

		while time.monotonic() < end:
			try:
				data, _ = c.recvfrom(64)
				n = int.from_bytes(data, "big")
				got.append((n, (time.monotonic() - sent[n]) * 1000.0))
			except socket.timeout:
				if len(sent) == 300:
					break

	reader = threading.Thread(target=receive)
	reader.start()

	for n in range(300):
		sent[n] = time.monotonic()
		c.sendto(n.to_bytes(4, "big"), ("127.0.0.1", listen))
		time.sleep(0.003)

	reader.join()
	lost = 1.0 - len(got) / 300.0
	delays = sorted(d for _, d in got)
	order = [n for n, _ in got]
	check(0.02 <= lost <= 0.20, "about 10%% lost over the round trip at 5%% each way (got %.1f%%)" % (100 * lost))
	check(delays and 55.0 <= delays[len(delays) // 2] <= 140.0, "round trip about 80 ms at 40 ms each way (median %.0f ms)" % (delays[len(delays) // 2] if delays else -1))
	check(order == sorted(order), "packets keep their order without --reorder")
	t = socket.create_connection(("127.0.0.1", listen + 1), timeout=3)
	t0 = time.monotonic()
	blob = os.urandom(200000)
	t.sendall(blob)
	back = b""

	while len(back) < len(blob):
		chunk = t.recv(65536)

		if not chunk:
			break

		back += chunk

	took = (time.monotonic() - t0) * 1000.0
	t.close()
	check(back == blob, "the block line (TCP) carries 200 kB through whole")
	check(took >= 60.0, "the block line is delayed too (%.0f ms)" % took)
	relay.terminate()
	relay.wait(5)
	stop.set()


def test_link_cut():
	"""--control: "cut" kills the connections open now, both ways; a client that connects after it passes (plan drops)."""
	while True:
		server_port, listen = free_port(), free_port()

		try:
			for p in (listen + 1, server_port + 1):
				t = socket.socket()
				t.bind(("127.0.0.1", p))
				t.close()
			break
		except OSError:
			pass

	udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
	udp.bind(("127.0.0.1", server_port))
	tcp = socket.socket()
	tcp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
	tcp.bind(("127.0.0.1", server_port + 1))
	tcp.listen(4)

	def udp_echo():
		udp.settimeout(10)

		try:
			while True:
				data, addr = udp.recvfrom(64)
				udp.sendto(data, addr)
		except OSError:
			pass

	def tcp_echo(c):
		try:
			while True:
				data = c.recv(64)

				if not data:
					break

				c.sendall(data)
		except OSError:
			pass

	def tcp_accept():
		tcp.settimeout(10)

		try:
			while True:
				c, _ = tcp.accept()
				threading.Thread(target=tcp_echo, args=(c,), daemon=True).start()
		except OSError:
			pass

	threading.Thread(target=udp_echo, daemon=True).start()
	threading.Thread(target=tcp_accept, daemon=True).start()

	with tempfile.TemporaryDirectory() as d:
		ctl = os.path.join(d, "link_control.txt")
		relay = subprocess.Popen([sys.executable, os.path.join(HERE, "lossy_link.py"), "--listen", str(listen), "--server-port", str(server_port),
			"--delay-ms", "5", "--jitter-ms", "0", "--loss", "0", "--control", ctl, "--seconds", "10"], stdout=subprocess.PIPE, text=True)
		relay.stdout.readline()

		def udp_ask(s):
			s.settimeout(0.5)
			s.sendto(b"x", ("127.0.0.1", listen))

			try:
				return s.recvfrom(8)[0] == b"x"
			except socket.timeout:
				return False

		def tcp_ask(s):
			s.settimeout(0.5)
			s.sendall(b"y")

			try:
				return s.recv(8) == b"y"
			except socket.timeout:
				return False

		a = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
		ta = socket.create_connection(("127.0.0.1", listen + 1))
		before = [udp_ask(a), tcp_ask(ta)]

		with open(ctl, "w") as f:
			f.write("cut")

		time.sleep(0.8)
		after = [udp_ask(a), tcp_ask(ta)]
		b = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
		tb = socket.create_connection(("127.0.0.1", listen + 1))
		fresh = [udp_ask(b), tcp_ask(tb)]
		relay.terminate()
		relay.wait()
		check(before == [True, True], "lossy_link --control: udp and the block line pass before the cut (%s)" % before)
		check(after == [False, False], "lossy_link --control: after \"cut\" the open connections are dead both ways (%s)" % after)
		check(fresh == [True, True], "lossy_link --control: a client that connects after the cut passes (%s)" % fresh)
		check(open(ctl).read() == "done", "lossy_link --control: the control file says done after the cut")

	for s in (udp, tcp, a, b, ta, tb):
		s.close()


def write(d, name, lines):
	with open(os.path.join(d, name), "w") as f:
		f.write("\n".join(lines) + "\n")


def run_check(d):
	return subprocess.run([sys.executable, os.path.join(HERE, "robot_check.py"), d], capture_output=True, text=True)


def good_logs(d):
	write(d, "server.log", ["AUDIT on: robot audit lines follow", "AUDIT pack 7 1000 aaaa 0", "AUDIT pack 7 5000 bbbb 2", "AUDIT pack 7 9500 cccc 3"])
	write(d, "robot1_play.log", ["ROBOT Robot 1 step joined: peer 7 at (0, 0, 0)", "ROBOT Robot 1 CHECK pack 7 4000 aaaa 0 joined",
		"ROBOT Robot 1 CHECK pack 7 9000 bbbb 2 craft twine", "ROBOT Robot 1 CHECK pack 7 9800 bbbb 2 changed just before",
		"ROBOT Robot 1 NOTE obstacle a tree", "ROBOT Robot 1 done: 0 fails"])


def test_check():
	with tempfile.TemporaryDirectory() as d:
		good_logs(d)
		r = run_check(d)
		check(r.returncode == 0, "robot_check passes logs that hold every invariant (%s)" % r.stdout.strip().splitlines()[-1])

	cases = [
		("a client pack that is not the server's", "robot1_play.log", "ROBOT Robot 1 CHECK pack 7 9000 dddd 2 craft axe"),
		("a ROBOT FAIL line", "robot1_play.log", "ROBOT Robot 1 FAIL held remote player 9's held item is 0.8 m from its hand"),
		("an AUDIT jump", "server.log", "AUDIT jump 4 deer 6000 9.0 0.10 (0, 0, 0) (9, 0, 0) state 2"),
		("a SCRIPT ERROR", "server.log", "SCRIPT ERROR: Invalid call. Nonexistent function 'x'."),
		("a hunt of 12 strikes and no hit", "robot1_play.log", "ROBOT Robot 1 HUNT deer 4 12 0 1.0 up 100 100 30"),
		("a robot client that exited 134 (an abort)", "robot1_play.exit", "134"),
		("an engine ERROR not on the known list", "server.log", "ERROR: Cannot open file 'res://.godot/imported/x.scn'."),
	]

	for what, name, extra in cases:
		with tempfile.TemporaryDirectory() as d:
			good_logs(d)

			with open(os.path.join(d, name), "a") as f:
				f.write(extra + "\n")

			r = run_check(d)
			check(r.returncode == 1, "robot_check fails %s" % what)

	with tempfile.TemporaryDirectory() as d:
		good_logs(d)

		with open(os.path.join(d, "server.log"), "a") as f:
			f.write("ERROR: 5 resources still in use at exit (run with --verbose for details).\n")

		r = run_check(d)
		check(r.returncode == 0, "robot_check lets the known exit leak notice pass")

	with tempfile.TemporaryDirectory() as d:
		good_logs(d)
		write(d, "robot1_play.log", ["ROBOT Robot 1 step joined: peer 7 at (0, 0, 0)", "ROBOT Robot 1 done: plan first_hours, 0 fails, 0 notes, 3 drawn-animal ids seen, 0 remote held items measured"])
		write(d, "robot2_play.log", ["ROBOT Robot 2 step joined: peer 8 at (0, 0, 0)", "ROBOT Robot 2 done: plan first_hours, 0 fails, 0 notes, 3 drawn-animal ids seen, 0 remote held items measured"])
		r = run_check(d)
		check(r.returncode == 1 and "held check never ran" in r.stdout, "robot_check fails two first_hours robots that measured no held item")
		write(d, "robot1_play.log", ["ROBOT Robot 1 step joined: peer 7 at (0, 0, 0)", "ROBOT Robot 1 done: plan light, 0 fails, 0 notes, 3 drawn-animal ids seen, 0 remote held items measured"])
		write(d, "robot2_play.log", ["ROBOT Robot 2 step joined: peer 8 at (0, 0, 0)", "ROBOT Robot 2 done: plan light, 0 fails, 0 notes, 3 drawn-animal ids seen, 0 remote held items measured"])
		r = run_check(d)
		check(r.returncode == 0, "robot_check does not ask a light plan for held items")

	with tempfile.TemporaryDirectory() as d:
		good_logs(d)
		write(d, "robot2_play.log", ["ROBOT Robot 2 step joined: peer 8 at (0, 0, 0)"])
		r = run_check(d)
		check(r.returncode == 1 and "never finished" in r.stdout, "robot_check fails a robot that joined but never finished")

	with tempfile.TemporaryDirectory() as d:
		good_logs(d)
		write(d, "robot2_play.log", ["ROBOT Robot 2 step prepare: plan first_hours"])
		r = run_check(d)
		check(r.returncode == 2, "robot_check calls a robot that never joined a broken run (exit 2)")


def test_twin():
	"""Plan drops: the first of two clients of one character, dropped by the server on purpose, is excused only for that."""
	twin = ["ROBOT Robot 1 step joined: peer 5 at (0, 0, 0)", "ROBOT Robot 1 LOST the server at 3000 (step twin, notices [])",
		"ROBOT Robot 1 TWIN first dropped by the server", "ERROR: Trying to call an RPC via a multiplayer peer which is not connected."]
	same = "Peer 6 is the same character as peer 5: the older connection is dropped"

	for what, lines, code, server_extra, want in [
		("passes a twin the server dropped as the same character (exit 1, no done line, an error after)", twin, "1", [same], 0),
		("fails the same log when the server never said same character", twin, "1", [], 1),
		("fails a dropped twin that exited 134", twin, "134", [same], 1),
		("fails a twin log without the dropped line", twin[:1], "1", [same], 1),
		("passes a twin told by the server first (join refused notice, no LOST line)", twin[:1] + ["Terrain client: join refused: This character joined the server again from another game window or computer, so this one was closed. Nothing was lost."], "1", [same], 0),
		("still fails an engine ERROR in the server log beside an excused twin", twin, "1", [same, "ERROR: Cannot open file 'x'."], 1),
	]:
		with tempfile.TemporaryDirectory() as d:
			good_logs(d)

			with open(os.path.join(d, "server.log"), "a") as f:
				f.write("".join(x + "\n" for x in server_extra))

			write(d, "robot1_twin1.log", lines)

			with open(os.path.join(d, "robot1_twin1.exit"), "w") as f:
				f.write(code + "\n")

			r = run_check(d)
			check(r.returncode == want, "robot_check %s (%s)" % (what, r.stdout.strip().splitlines()[-1]))


def test_kinds():
	"""Plan kind_: robot_kinds.py reads both robots' A lines and the server's blows; the two clients' gap and the drawn-vs-server gap."""
	import importlib.util
	spec = importlib.util.spec_from_file_location("robot_kinds", os.path.join(os.path.dirname(os.path.abspath(__file__)), "robot_kinds.py"))
	rk = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(rk)

	with tempfile.TemporaryDirectory() as d:
		for n, peer, off in ((1, 11, 0.0), (2, 12, 2.0)):
			lines = ["ROBOT Robot %d step joined: peer %d at (0, 0, 0)" % (n, peer)]

			for i in range(40):
				ms = 10000 + i * 100
				lines.append("ROBOT Robot %d P %d %.2f 0.00" % (n, ms, i * 0.1))
				lines.append("ROBOT Robot %d A %d 7 %.2f 5.00 11" % (n, ms, i * 0.3 + off))

			lines.append("ROBOT Robot %d KIND boar 8 frames 40 largest_step 0.30 m largest_x 1.00 over_1m 0 inside_other 0 lowest_health 100" % n)
			write(d, "robot%d_play.log" % n, lines)

		write(d, "server.log", ["AUDIT enemy_hit 11 12000 boar from 9.00,5.00 player 2.00,0.00 gap 1.00 result hurt shield 0.00"])
		robots, hits = rk.read_run(d)
		one, two = robots["robot1"], robots["robot2"]
		check(len(one["a"][7]) == 40 and len(one["p"]) == 40 and one["peer"] == 11, "robot_kinds reads A, P and joined lines")
		check(abs(rk.at(two["a"][7], 12050)[0] - (6.15 + 2.0)) < 0.01, "robot_kinds interpolates the other robot's drawn place")
		check(len(hits) == 1 and hits[0]["peer"] == 11 and hits[0]["from"] == (9.0, 5.0), "robot_kinds reads AUDIT enemy_hit")
		drawn = rk.at(one["a"][7], hits[0]["ms"])
		check(abs(math.hypot(drawn[0] - 9.0, drawn[1] - 5.0) - 3.0) < 0.01, "the drawn-vs-server gap at a blow (drawn 6.0, server 9.0)")
		check(rk.at(one["a"][7], 99999) is None, "no drawn place long after the last row")


def watch_logs(d, jump=False, swing_clip="chop", still=False):
	"""A walker that walks 3 m/s east for 4 s from x 0, stops, swings, sleeps; a watcher drawing it 300 ms late every 20 ms."""
	ev = ["ROBOT Robot 1 step joined: peer 7 at (0, 0, 0)",
		"ROBOT Robot 1 EVENT walk 10000 0.00 0.00 0.00 1.00 0.00 walk", "ROBOT Robot 1 EVENT stop 14000 12.00 0.00 0.00 %s" % ("0.00" if still else "3.00"),
		"ROBOT Robot 1 EVENT swing 17500 12.00 0.00 0.00", "ROBOT Robot 1 EVENT sleep_on 20000 12.00 0.00 0.00",
		"ROBOT Robot 1 EVENT sleep_off 26000 12.00 0.00 0.00", "ROBOT Robot 1 EVENT end 30000 12.00 0.00 0.00", "ROBOT Robot 1 done: plan watch"]
	rows = []

	for ms in range(9000, 30000, 20):
		x = 0.0 if still else min(max((ms - 10300) * 0.003, 0.0), 12.0)

		if jump and 12000 <= ms < 12100:
			x += 1.0

		state = 16 if 20300 <= ms <= 26300 else 0
		clip = swing_clip if 17800 <= ms <= 18500 else "idle"
		rows.append("ROBOT Robot 2 W 7 %d %.3f 0.000 0.000 %d %s 0.110" % (ms, x, state, clip))

	write(d, "robot1_play.log", ev)
	write(d, "robot2_play.log", ["ROBOT Robot 2 step joined: peer 8 at (0, 0, 0)"] + rows)


def test_others():
	"""A runner at 9 m/s, pose lines 0.5 s apart, drawn on its path between them, passes; drawn 3 m off its path four times fails."""
	for what, off, want in [("a runner drawn between its pose lines passes", 0.0, 0), ("a player drawn 3 m off its path fails", 3.0, 1)]:
		with tempfile.TemporaryDirectory() as d:
			good_logs(d)
			poses = ["ROBOT Robot 2 POSE 8 %d 0 %.2f 0.00 0.00 9.00" % (1000 + 500 * i, 4.5 * i) for i in range(12)]
			sees = ["ROBOT Robot 1 SEES 8 %d 0 %.2f 0.00 %.2f run" % (1250 + 500 * i, 4.5 * i - 2.25, off) for i in range(2, 12)]
			poses += ["ROBOT Robot 1 POSE 7 %d 0 0.00 0.00 50.00 0.00" % (1000 + 500 * i) for i in range(12)]
			sees += ["ROBOT Robot 2 SEES 7 %d 0 0.00 0.00 50.00 idle" % (1250 + 500 * i) for i in range(2, 12)]

			with open(os.path.join(d, "robot1_play.log"), "a") as f:
				f.write("\n".join([l for l in sees if l.startswith("ROBOT Robot 1")] + [l for l in poses if l.startswith("ROBOT Robot 1")]) + "\n")

			write(d, "robot2_play.log", ["ROBOT Robot 2 step joined: peer 8 at (0, 0, 0)"] + [l for l in poses + sees if l.startswith("ROBOT Robot 2")] + ["ROBOT Robot 2 done: 0 fails"])
			r = run_check(d)
			check(r.returncode == want, "robot_check others: %s (%s)" % (what, r.stdout.strip().splitlines()[-1]))


def test_solo():
	"""One robot, a play pass and a rejoin pass (two peers, one name), no SEES lines: not a failed others check."""
	with tempfile.TemporaryDirectory() as d:
		good_logs(d)

		with open(os.path.join(d, "robot1_play.log"), "a") as f:
			f.write("ROBOT Robot 1 POSE 7 2000 0 0.00 0.00 0.00 0.00\n")

		write(d, "robot1_rejoin.log", ["ROBOT Robot 1 step joined: peer 9 at (0, 0, 0)", "ROBOT Robot 1 POSE 9 9600 0 0.00 0.00 0.00 0.00", "ROBOT Robot 1 done: 0 fails"])
		write(d, "server.log", ["AUDIT on: robot audit lines follow", "AUDIT pack 7 1000 aaaa 0", "AUDIT pack 7 5000 bbbb 2", "AUDIT pack 7 9500 cccc 3"])
		r = run_check(d)
		check("others:" not in r.stdout, "robot_check: a solo robot's play and rejoin passes are not two robots (%s)" % r.stdout.strip().splitlines()[-1])


def test_watch():
	for what, kw, want in [("a smooth walker passes", {}, 0), ("a 1 m jump fails", {"jump": True}, 1), ("a swing never shown fails", {"swing_clip": "idle"}, 1), ("a walker that never moved fails", {"still": True}, 1)]:
		with tempfile.TemporaryDirectory() as d:
			watch_logs(d, **kw)
			r = subprocess.run([sys.executable, os.path.join(HERE, "robot_watch.py"), d], capture_output=True, text=True)
			check(r.returncode == want, "robot_watch: %s (%s)" % (what, r.stdout.strip().splitlines()[-1] if r.stdout.strip() else r.stderr[-200:]))


if __name__ == "__main__":
	test_link()
	test_link_cut()
	test_check()
	test_others()
	test_solo()
	test_twin()
	test_kinds()
	test_watch()
	print("test_robot_tools: %d failures" % len(failures))
	sys.exit(1 if failures else 0)
