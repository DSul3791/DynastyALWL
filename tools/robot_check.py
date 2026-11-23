#!/usr/bin/env python3
"""Reads a robot run's logs (tools/robots.sh) and fails it on any broken invariant.

    python3 tools/robot_check.py /tmp/robots_XXXX

Invariants (src/client/robot_play.gd prints the client side, src/server/robot_audit.gd the server side):
  pack      every robot pack check (ROBOT ... CHECK pack) equals the server's pack for that peer at that moment (AUDIT pack)
  robot     every ROBOT ... FAIL line (craft, pickup, jump, inside, held, blocked, refusal, rejoin)
  server    every AUDIT jump (an animal moved farther in a step than its top speed allows) and AUDIT inside (an animal inside a player)
  errors    no SCRIPT ERROR, and no engine ERROR line outside tools/robot_known_errors.txt, in any log
  joined    every robot joined and printed its done line
  hunt      strikes from within reach that the server never counted as hits (the drawn animal is not where the server has it); the
            fights per animal (robots, strikes, hits, down or not) are printed for the record
  others    how each robot draws each other robot (SEES) against where that one really was (POSE): the stance it is drawn in, its clip,
            and the drawn body more than OTHERS_M from every place the real one stood in the second before
Prints one line per finding and a summary; exit 0 all held, 1 a finding, 2 the run broke (nothing to read, a robot never joined).
"""
import collections
import glob
import os
import re
import sys

OTHERS_M = 1.5          # a drawn player this far from everywhere the real one was in the last second is off its track
OTHERS_REPEAT = 4       # ... this many times for one pair before it is a finding (one late packet is not)
STEADY_MS = 2000        # a stance held this long must be the stance the others draw
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
		dropped = False   # plan drops: a twin the server dropped on purpose; its game's lines after that are not faults

		for line in open(path, encoding="utf-8", errors="replace"):
			dropped = dropped or "TWIN first dropped by the server" in line

			if dropped:
				continue

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
				play_logs += 1 if "plan first_hours" in line else 0   # only that plan holds items in view of the others
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

		exit_path = path[:-4] + ".exit"
		twin_dropped = "TWIN first dropped by the server" in open(path, encoding="utf-8", errors="replace").read()   # dropped on purpose: exit 1, no done line

		if twin_dropped:
			pass
		elif os.path.exists(exit_path) and open(exit_path).read().strip() not in ("0", ""):
			findings.append("robot %s: the client exited with code %s (0 after a clean quit; 134 is an abort, 124 the time limit)" % (name, open(exit_path).read().strip()))

		if not joined:
			broke.append("%s never joined" % name)
		elif not done and not twin_dropped:
			findings.append("robot %s: joined but never finished its plan (stuck, crashed or timed out)" % name)

	if play_logs >= 2 and held_looks == 0:
		findings.append("held: %d robots played together and no robot measured another's held item (the held check never ran)" % play_logs)

	findings += others(robot_logs)
	findings += hunts(robot_logs)

	for b in broke:
		print("BROKE " + b)

	for f in findings:
		print("FAIL " + f)

	print("robot_check: %d robot logs, %d pack checks, %d findings, %d broken%s" % (
		len(robot_logs), checks, len(findings), len(broke), "" if findings or broke else ": every invariant held"))
	return 2 if broke else (1 if findings else 0)


def lines(robot_logs, tag):
	for path in robot_logs:
		for line in open(path, encoding="utf-8", errors="replace"):
			if line.startswith("ROBOT ") and (" %s " % tag) in line:
				yield os.path.basename(path), line.split(" %s " % tag, 1)[0][6:], line.split(" %s " % tag, 1)[1].split()


def seg_dist(x, z, a, b):
	"""Ground distance from (x, z) to the segment between pose lines a and b."""
	ax, az, bx, bz = a[2], a[3], b[2], b[3]
	dx, dz = bx - ax, bz - az
	length2 = dx * dx + dz * dz
	t = 0.0 if length2 == 0.0 else max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / length2))
	return ((x - ax - t * dx) ** 2 + (z - az - t * dz) ** 2) ** 0.5


# One-shot clips (avatar_driver.gd HOOK_CLIPS) play over any stance: waking plays while the body still lies, drinking while it crouches.
ONE_SHOTS = {"wake_up", "drink", "sit_down", "stand_up"}


def others(robot_logs):
	pose = collections.defaultdict(list)   # peer -> [(ms, stance, x, z, speed)]
	names = {}

	for _, who, p in lines(robot_logs, "POSE"):
		pose[int(p[0])].append((int(p[1]), int(p[2]), float(p[3]), float(p[5]), float(p[6])))
		names[int(p[0])] = who

	off = collections.Counter()
	worst = {}
	stance_bad = collections.Counter()
	clip_bad = collections.Counter()
	example = {}
	seen = 0

	for _, who, p in lines(robot_logs, "SEES"):
		peer, ms, stance, x, z, clip = int(p[0]), int(p[1]), int(p[2]), float(p[3]), float(p[5]), p[6]
		track = [q for q in pose.get(peer, []) if ms - 1000 <= q[0] <= ms]
		# steady from STEADY_MS before the look to one pose line after it: a stance taken and left between two pose lines is not steady
		before = [q for q in pose.get(peer, []) if ms - STEADY_MS <= q[0] <= ms + 600]

		if not track:
			continue

		seen += 1
		key = (who, names.get(peer, str(peer)))
		# The nearest point of the path it walked (between consecutive pose lines, 0.5 s apart: a runner's lines lie 4.5 m apart)
		path = sorted(q for q in pose.get(peer, []) if ms - 1500 <= q[0] <= ms + 600)   # and the pose line after the look (gate review of #1701)
		d = min([seg_dist(x, z, a, b) for a, b in zip(path, path[1:])] + [((x - q[2]) ** 2 + (z - q[3]) ** 2) ** 0.5 for q in track])

		if d > OTHERS_M:
			off[key] += 1
			worst[key] = max(worst.get(key, 0.0), d)

		if len(before) >= 3 and len({q[1] for q in before}) == 1:
			real = before[0][1]

			if stance != real:
				stance_bad[key] += 1
				example.setdefault(("stance",) + key, "drawn in stance %d while it had been in stance %d for %d s" % (stance, real, STEADY_MS // 1000))
			elif clip != "-" and clip not in ONE_SHOTS:
				family = {1: "crouch", 2: "sit", 3: "lie"}.get(real, "")
				wrong = (family and family not in clip) or (not family and any(f in clip for f in ("crouch", "sit", "lie")))

				if wrong:
					clip_bad[key] += 1
					example.setdefault(("clip",) + key, "playing clip %s while in stance %d" % (clip, real))

	out = []

	for key, n in sorted(off.items()):
		if n >= OTHERS_REPEAT:
			out.append("others %s draws %s off its track %d times (worst %.1f m from anywhere it was in the second before)" % (key[0], key[1], n, worst[key]))

	for key, n in sorted(stance_bad.items()):
		if n >= OTHERS_REPEAT:
			out.append("others %s draws %s in the wrong stance %d times: %s" % (key[0], key[1], n, example[("stance",) + key]))

	for key, n in sorted(clip_bad.items()):
		if n >= OTHERS_REPEAT:
			out.append("others %s draws %s with the wrong clip %d times: %s" % (key[0], key[1], n, example[("clip",) + key]))

	print("robot_check: %d views of other robots compared with where they were" % seen)

	robots = set(names.values())   # by name: one robot's play and rejoin passes are two peers, not two robots (bug-fix thread, 23 Nov 2026)

	if len(robots) >= 2 and seen == 0:
		out.append("others: %d robots played together and no robot's view of another matched its pose lines (the others check never ran)" % len(robots))

	return out


def hunts(robot_logs):
	fights = collections.defaultdict(lambda: {"robots": [], "strikes": 0, "hits": 0, "hp": 1.0, "down": False, "secs": 0.0})
	out = []

	for name, who, p in lines(robot_logs, "HUNT"):
		if p[1] == "none":
			print("robot_check: hunt %s found no %s within 120 m" % (who, p[0]))
			continue

		f = fights[(p[0], int(p[1]))]
		f["robots"].append("%s (health %s->%s)" % (who, p[6], p[7]))
		f["strikes"] += int(p[2])
		f["hits"] += int(p[3])
		f["hp"] = min(f["hp"], float(p[4]))
		f["down"] = f["down"] or p[5] == "down"
		f["secs"] = max(f["secs"], float(p[8]))

	for (sp, id_), f in sorted(fights.items()):
		print("robot_check: fight %s %d: %d robots, %d strikes, %d hits, health share %.1f, %s after %.0f s: %s" % (
			sp, id_, len(f["robots"]), f["strikes"], f["hits"], f["hp"], "DOWN" if f["down"] else "not down", f["secs"], ", ".join(f["robots"])))

		if f["strikes"] >= 10 and f["hits"] == 0:
			out.append("hunt %s %d: %d strikes from within 1.6 m of the drawn animal and the server counted no hit" % (sp, id_, f["strikes"]))

	return out


if __name__ == "__main__":
	sys.exit(main())
