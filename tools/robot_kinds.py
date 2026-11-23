#!/usr/bin/env python3
"""Reads one or more kind runs (ROBOT_S=200 tools/robots.sh 2 kind_<species> [link]) and prints, per run, how the two robots drew the kind.

    python3 tools/robot_kinds.py /tmp/robots_XXXX [/tmp/robots_YYYY ...]

The robots (src/client/robot_play.gd _kind) print each frame's stats in a KIND line, and every 100 ms an A line per drawn body of the kind
(unix ms, id, x, z, state) and a P line for themselves; a health drop prints BITTEN with the nearest drawn body. The server prints
AUDIT enemy_hit for each goblin, bandit or big game blow, with where it had the animal (from) and the player. Both robots and the server run
on one machine, so their unix ms share a clock. Measures:
  jumps   per robot: the largest drawn step in one frame, that step against the kind's top speed x the frame, and steps over 1 m
  agree   the two robots' drawn places of the same animal at the same moment (the other robot's A rows interpolated): median, 95th, worst
  hits    per server blow: the drawn place of that animal on the struck robot at that moment against where the server had it, and the
          drawn gap to the robot; per BITTEN line (every blow, also wolves): the drawn gap and drawn state
  slides  per robot, the SLIDE line: samples of a bought-model body moving over 0.5 m/s with a standing clip, its rate held at the top or
          bottom, or its feet off the drawn ground speed by over a third (none without the models: cloud clones leave them out)
  shoved  per robot, its own body faster than SHOVE_MPS over half-second windows: a body pushing the player along (a player runs at 9 m/s: terrain_client RUN_SPEED)
  server  per robot, its drawn places against the server's own (AUDIT where every 0.5 s, plan kind_ asks for it), and near the robot the
          server's gap to it against the drawn gap (a drawn body pulled toward or round the robot, or a stale place)
  inside  FAIL inside lines (a body in this robot) and the KIND line's inside_other (a body in the other drawn robot), in frames
Exit 0 read, 2 nothing to read. It judges nothing: the numbers go to the animal thread.
"""
import bisect
import glob
import math
import os
import re
import statistics
import sys

SHOVE_WINDOW_MS = 500
SHOVE_MPS = 11.0   # terrain_client RUN_SPEED 9.0 m/s, with room for a frame hitch


def read_run(d):
	robots = {}

	for path in sorted(glob.glob(os.path.join(d, "robot*_play.log"))):
		r = {"p": [], "a": {}, "kind": None, "bitten": [], "inside": 0, "slide": None, "peer": None, "name": os.path.basename(path).split("_")[0]}

		for line in open(path, encoding="utf-8", errors="replace"):
			if not line.startswith("ROBOT "):
				continue

			p = line.split()

			if len(p) > 6 and p[3] == "P":
				r["p"].append((int(p[4]), float(p[5]), float(p[6])))
			elif len(p) > 8 and p[3] == "A":
				r["a"].setdefault(int(p[5]), []).append((int(p[4]), float(p[6]), float(p[7]), int(p[8])))
			elif len(p) > 4 and p[3] == "SLIDE":
				r["slide"] = line.split("SLIDE ", 1)[1].strip()
			elif len(p) > 4 and p[3] == "KIND":
				r["kind"] = line.split("KIND ", 1)[1].strip()
			elif len(p) > 4 and p[3] == "BITTEN":
				m = re.search(r"BITTEN (\d+) health (\d+) -> (\d+) by (-?\d+) drawn gap (\S+) state (-?\d+)", line)

				if m:
					r["bitten"].append({"ms": int(m[1]), "before": int(m[2]), "after": int(m[3]), "id": int(m[4]), "gap": float(m[5]), "state": int(m[6])})
			elif "FAIL inside" in line:
				r["inside"] += 1
			elif "step joined: peer" in line:
				r["peer"] = int(line.split("peer ")[1].split()[0])

		for rows in r["a"].values():
			rows.sort()

		robots[r["name"]] = r

	hits = []
	where = {}   # animal id -> [(unix ms, x, z, state)] where the server had it (AUDIT where, every 0.5 s)
	server = os.path.join(d, "server.log")

	if os.path.exists(server):
		for line in open(server, encoding="utf-8", errors="replace"):
			w = re.match(r"AUDIT where (\d+) (\d+) (\d+) ([-\d.]+) ([-\d.]+) (-?\d+)", line)

			if w:
				where.setdefault(int(w[1]), []).append((int(w[3]), float(w[4]), float(w[5]), int(w[6])))
				continue

			m = re.match(r"AUDIT enemy_hit (\d+) (\d+) (\S+) from ([-\d.]+),([-\d.]+) player ([-\d.]+),([-\d.]+) gap (\S+) result (\S+)", line)

			if m:
				hits.append({"peer": int(m[1]), "ms": int(m[2]), "cause": m[3], "from": (float(m[4]), float(m[5])), "player": (float(m[6]), float(m[7])),
					"gap": float(m[8]), "result": m[9]})

	robots["_where"] = where
	return robots, hits


def at(rows, ms, slack=150):
	"""The drawn place at `ms` from A rows (ms, x, z, state), interpolated; None if no row within `slack` ms either side."""
	times = [r[0] for r in rows]
	i = bisect.bisect_left(times, ms)

	if 0 < i < len(rows) and rows[i][0] - rows[i - 1][0] <= 2 * slack:
		a, b = rows[i - 1], rows[i]
		t = (ms - a[0]) / max(b[0] - a[0], 1)
		return (a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)

	for j in (i - 1, i):
		if 0 <= j < len(rows) and abs(rows[j][0] - ms) <= slack:
			return (rows[j][1], rows[j][2])

	return None


def pct(xs, q):
	xs = sorted(xs)
	return xs[min(len(xs) - 1, int(q * len(xs)))]


def report(d):
	robots, hits = read_run(d)
	where = robots.pop("_where", {})

	if not robots:
		print("%s: no robot logs" % d)
		return False

	print("== %s" % d)

	for name, r in robots.items():
		print("  jumps %s: %s; inside this robot %d frames" % (name, r["kind"] or "no KIND line (the plan never finished)", r["inside"]))
		print("  slides %s: %s" % (name, r["slide"] or "no SLIDE line"))
		fast = []   # over windows of at least SHOVE_WINDOW_MS: a frame hitch's physics catch-up lands in the next sample, and two short samples would read as a burst
		j = 0

		for i, a in enumerate(r["p"]):
			j = max(j, i + 1)

			while j < len(r["p"]) and r["p"][j][0] - a[0] < SHOVE_WINDOW_MS:
				j += 1

			if j < len(r["p"]) and r["p"][j][0] - a[0] <= 2 * SHOVE_WINDOW_MS:
				b = r["p"][j]
				fast.append(math.hypot(b[1] - a[1], b[2] - a[2]) / ((b[0] - a[0]) / 1000.0))

		if fast:
			print("  shoved %s: its own body over %.0f m/s (faster than a player runs) in %d of %d samples, top %.1f m/s" % (name, SHOVE_MPS, sum(1 for v in fast if v > SHOVE_MPS), len(fast), max(fast)))

	names = sorted(robots)

	if len(names) >= 2:
		one, two = robots[names[0]], robots[names[1]]
		diffs = []

		for aid, rows in one["a"].items():
			other = two["a"].get(aid)

			if not other:
				continue

			for ms, x, z, _st in rows:
				o = at(other, ms)

				if o is not None:
					diffs.append(math.hypot(x - o[0], z - o[1]))

		if diffs:
			print("  agree: %d moments, median %.2f m, 95th %.2f m, worst %.2f m, %d over 1 m" % (len(diffs), statistics.median(diffs), pct(diffs, 0.95), max(diffs),
				sum(1 for x in diffs if x > 1.0)))
		else:
			print("  agree: the two robots never drew the same animal at the same moment")

	for name, r in robots.items():
		off, near_drawn, near_server = [], [], []

		for aid, rows in where.items():
			drawn = r["a"].get(aid)

			if not drawn:
				continue

			for ms, x, z, _st in rows:
				p = at(drawn, ms)
				me = at([(q[0], q[1], q[2], 0) for q in r["p"]], ms)

				if p is None:
					continue

				off.append(math.hypot(p[0] - x, p[1] - z))

				if me is not None and math.hypot(x - me[0], z - me[1]) < 10.0:
					near_server.append(math.hypot(x - me[0], z - me[1]))
					near_drawn.append(math.hypot(p[0] - me[0], p[1] - me[1]))

		if off:
			print("  server %s: drawn against the server's own place (AUDIT where): %d moments, median %.2f m, 95th %.2f m, worst %.2f m%s" % (name, len(off),
				statistics.median(off), pct(off, 0.95), max(off), "" if not near_server else "; within 10 m of this robot: server gap median %.2f m, drawn gap median %.2f m (%d moments)" % (
				statistics.median(near_server), statistics.median(near_drawn), len(near_server))))

	by_peer = {r["peer"]: r for r in robots.values() if r["peer"] is not None}

	for h in hits:
		r = by_peer.get(h["peer"])
		line = "  hit %s on %s: server gap %.2f, result %s" % (h["cause"], r["name"] if r else h["peer"], h["gap"], h["result"])

		kind = (r["kind"] or "").split(" ")[0] if r else ""

		if r and kind and h["cause"].split("/")[0] != kind:
			line += ", another kind (not the run's %s): its places are not drawn in A lines, so not measured" % kind
		elif r:
			best = None

			for aid, rows in r["a"].items():
				p = at(rows, h["ms"])

				if p is not None:
					off = math.hypot(p[0] - h["from"][0], p[1] - h["from"][1])

					if best is None or off < best[0]:
						best = (off, aid, p)

			if best:
				line += ", drawn %.2f m from the server's place (animal %d), drawn gap %.2f" % (best[0], best[1], math.hypot(best[2][0] - h["player"][0], best[2][1] - h["player"][1]))
			else:
				line += ", not drawn on that robot then"

		print(line)

	for name, r in robots.items():
		for b in r["bitten"]:
			print("  bitten %s: health %d -> %d by %d, drawn gap %.2f, drawn state %d" % (name, b["before"], b["after"], b["id"], b["gap"], b["state"]))

	if not hits and not any(r["bitten"] for r in robots.values()):
		print("  hits: none (the kind never struck a robot)")

	return True


def main():
	dirs = [d for d in sys.argv[1:] if os.path.isdir(d)]

	if not dirs:
		print(__doc__)
		return 2

	return 0 if all([report(d) for d in dirs]) else 2


if __name__ == "__main__":
	sys.exit(main())
