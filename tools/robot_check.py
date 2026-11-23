#!/usr/bin/env python3
"""Reads a robot run's logs (tools/robots.sh) and fails it on any broken invariant.

    python3 tools/robot_check.py /tmp/robots_XXXX

Invariants (src/client/robot_play.gd prints the client side, src/server/robot_audit.gd the server side):
  pack      every robot pack check (ROBOT ... CHECK pack) equals the server's pack for that peer at that moment (AUDIT pack)
  robot     every ROBOT ... FAIL line (craft, pickup, jump, inside, held, blocked, refusal, rejoin)
  server    every AUDIT jump (an animal moved farther in a step than its top speed allows) and AUDIT inside (an animal inside a player)
  errors    no SCRIPT ERROR, and no engine ERROR line outside tools/robot_known_errors.txt, in any log
  joined    every robot joined and printed its done line
Prints one line per finding and a summary; exit 0 all held, 1 a finding, 2 the run broke (nothing to read, a robot never joined).
"""
import collections
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def known_errors():
	path = os.path.join(HERE, "robot_known_errors.txt")
	pats = []

	if os.path.exists(path):
		for line in open(path, encoding="utf-8"):
			line = line.strip()

			if line and not line.startswith("#"):
				pats.append(re.compile(line))

	return pats


def main():
	if len(sys.argv) < 2 or not os.path.isdir(sys.argv[1]):
		print(__doc__)
		return 2

	d = sys.argv[1]
	server_log = os.path.join(d, "server.log")
	robot_logs = sorted(glob.glob(os.path.join(d, "robot*.log")))

	if not os.path.exists(server_log) or not robot_logs:
		print("robot_check: no server.log or robot logs in %s" % d)
		return 2

	findings = []
	broke = []
	server_pack = collections.defaultdict(list)   # peer -> [(ms, sig)]
	server_faults = collections.Counter()
	server_examples = {}
	audit_on = False

	for line in open(server_log, encoding="utf-8", errors="replace"):
		if line.startswith("AUDIT on"):
			audit_on = True
		elif line.startswith("AUDIT pack "):
			p = line.split()
			server_pack[int(p[2])].append((int(p[3]), p[4]))
		elif line.startswith("AUDIT jump ") or line.startswith("AUDIT inside "):
			p = line.split()
			key = "%s %s" % (p[1], p[3])   # kind, species
			server_faults[key] += 1
			server_examples.setdefault(key, line.strip())

	if not audit_on:
		broke.append("the server log has no 'AUDIT on' line: it was not started with --robot-audit")

	for key, n in sorted(server_faults.items()):
		findings.append("server %s: %d times, first: %s" % (key, n, server_examples[key]))

	known = known_errors()
	errors = collections.Counter()

	for path in [server_log] + robot_logs:
		for line in open(path, encoding="utf-8", errors="replace"):
			if "SCRIPT ERROR" in line or line.startswith("ERROR:"):
				text = line.strip()

				if "SCRIPT ERROR" not in text and any(k.search(text) for k in known):
					continue

				errors[(os.path.basename(path).split("_")[0], text[:220])] += 1

	for (where, text), n in sorted(errors.items()):
		findings.append("errors %s: %d x %s" % (where, n, text))

	checks = 0
	held_looks = 0
	play_logs = 0

	for path in robot_logs:
		name = os.path.basename(path)
		joined = done = False

		for line in open(path, encoding="utf-8", errors="replace"):
			if not line.startswith("ROBOT "):
				continue

			if " step joined:" in line:
				joined = True
			elif " done:" in line:
				done = True
				m = re.search(r"(\d+) remote held items measured", line)
				held_looks += int(m.group(1)) if m else 0
				play_logs += 1 if "_play" in name else 0
			elif " FAIL " in line:
				findings.append("robot %s: %s" % (name, line.strip()))
			elif " CHECK pack " in line:
				p = line.split(" CHECK pack ")[1].split()
				peer, ms, sig, step = int(p[0]), int(p[1]), p[2], " ".join(p[4:])
				checks += 1
				before = [s for s in server_pack.get(peer, []) if s[0] <= ms]

				if not before:
					findings.append("pack %s: check at %s, the server printed no pack for peer %d before it" % (name, step, peer))
					continue

				# The server's pack at that moment; one that changed in the last second may not have reached the client yet.
				ok = {before[-1][1]} | {s[1] for s in before[-3:-1] if ms - before[-1][0] < 1000}

				if sig not in ok:
					findings.append("pack %s: after %s the client's pack is %s, the server's is %s (peer %d)" % (name, step, sig, before[-1][1], peer))

		if not joined:
			broke.append("%s never joined" % name)
		elif not done:
			findings.append("robot %s: joined but never finished its plan (stuck, crashed or timed out)" % name)

	if play_logs >= 2 and held_looks == 0:
		findings.append("held: %d robots played together and no robot measured another's held item (the held check never ran)" % play_logs)

	for b in broke:
		print("BROKE " + b)

	for f in findings:
		print("FAIL " + f)

	print("robot_check: %d robot logs, %d pack checks, %d findings, %d broken%s" % (
		len(robot_logs), checks, len(findings), len(broke), "" if findings or broke else ": every invariant held"))
	return 2 if broke else (1 if findings else 0)


if __name__ == "__main__":
	sys.exit(main())
