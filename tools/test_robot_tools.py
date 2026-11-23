#!/usr/bin/env python3
"""Self-test for the robot play-testers' Python tools (no Godot): tools/lossy_link.py and tools/robot_check.py.

    python3 tools/test_robot_tools.py

1. lossy_link: a UDP echo server behind the relay; 300 packets through it must come back late by about twice the delay, a share lost
   near twice the loss (both ways), in order; a TCP echo through the block-line side must come back whole and late.
2. robot_check: hand-written logs that hold every invariant pass (exit 0); a client pack that is not the server's, a ROBOT FAIL line,
   an AUDIT jump, a SCRIPT ERROR and a robot that never finished each fail (exit 1); a missing join is a broken run (exit 2).
"""
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


if __name__ == "__main__":
	test_link()
	test_check()
	print("test_robot_tools: %d failures" % len(failures))
	sys.exit(1 if failures else 0)
