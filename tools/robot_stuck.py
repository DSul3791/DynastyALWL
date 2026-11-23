#!/usr/bin/env python3
"""Stuck animals in one or more robot runs: counts per kind and per game day (animals thread, coordinator 23 Nov 2026: animals stuck
against walls, fences, rocks, steep ground, water edges and each other, standing in fires, a flight stopped dead at a blocker).

    python3 tools/robot_stuck.py /tmp/robots_XXXX [/tmp/robots_YYYY ...]

Reads each run's server.log (the server runs with --robot-audit, src/server/robot_audit.gd):
  AUDIT stuck <id> <species> <unix ms> <x> <z> <state> to <m> ahead <what>   an animal near a player with somewhere to go that kept within
                                                                            0.5 m of one spot for 6 s; what lay 1.5 m toward its target
  AUDIT stuck_end <id> <species> <unix ms> <seconds>                         it moved on, stopped wanting to, or was gone
  AUDIT near <unix ms> <species>:<count> ...                                 the animals near a player each minute, by kind
Prints per kind: animal-hours watched, stuck spells, spells per game day (a game day is one real hour: src/shared/game_clock.gd RATIO
24) per animal watched, the median and longest spell, what lay ahead, and the first few spots. Exit 0 read (also with stuck animals:
it judges nothing, the numbers go to the animal thread), 2 nothing to read.
"""
import os
import statistics
import sys


def read_run(d):
	near = {}       # species -> animal-minutes
	spells = {}     # (id) -> spell dict, open or closed
	done = []

	path = os.path.join(d, "server.log")

	if not os.path.exists(path):
		return None

	for line in open(path, encoding="utf-8", errors="replace"):
		p = line.split()

		if len(p) < 3 or p[0] != "AUDIT":
			continue

		if p[1] == "near":
			for part in p[3:]:
				sp, _, n = part.rpartition(":")

				if sp and n.isdigit():
					near[sp] = near.get(sp, 0) + int(n)
		elif p[1] == "stuck" and len(p) >= 12:
			spells[p[2]] = {"id": p[2], "sp": p[3], "ms": int(p[4]), "x": float(p[5]), "z": float(p[6]), "state": int(p[7]),
				"to": float(p[9]), "ahead": p[11], "s": None}
		elif p[1] == "stuck_end" and len(p) >= 6 and p[2] in spells:
			s = spells.pop(p[2])
			s["s"] = float(p[5])
			done.append(s)

	return {"near": near, "spells": done + list(spells.values())}


def summary(runs):
	near = {}
	spells = []

	for r in runs:
		for sp, n in r["near"].items():
			near[sp] = near.get(sp, 0) + n

		spells += r["spells"]

	rows = []

	for sp in sorted(set(near) | set(s["sp"] for s in spells)):
		mine = [s for s in spells if s["sp"] == sp]
		hours = near.get(sp, 0) / 60.0
		lengths = [s["s"] for s in mine if s["s"] is not None]
		ahead = {}

		for s in mine:
			ahead[s["ahead"]] = ahead.get(s["ahead"], 0) + 1

		rows.append({"sp": sp, "hours": hours, "spells": len(mine), "per_day": len(mine) / hours if hours > 0 else float("nan"),
			"median_s": statistics.median(lengths) if lengths else None, "longest_s": max(lengths) if lengths else None,
			"open": sum(1 for s in mine if s["s"] is None), "ahead": ahead, "spots": mine[:3]})

	return rows


def main(argv):
	runs = [r for r in (read_run(d) for d in argv) if r is not None]

	if not runs:
		print("robot_stuck: no server.log in %s" % " ".join(argv))
		return 2

	rows = summary(runs)
	total = sum(r["spells"] for r in rows)
	print("robot_stuck: %d runs, %d stuck spells" % (len(runs), total))

	for r in rows:
		ahead = ", ".join("%s %d" % kv for kv in sorted(r["ahead"].items(), key=lambda kv: -kv[1])) or "-"
		spots = "; ".join("%s at %.0f,%.0f state %d to %.0f m" % (s["id"], s["x"], s["z"], s["state"], s["to"]) for s in r["spots"])
		med = "%.0f s" % r["median_s"] if r["median_s"] is not None else "-"
		longest = "%.0f s" % r["longest_s"] if r["longest_s"] is not None else "-"
		print("  %-14s watched %6.2f animal-hours, stuck %3d (%.2f per animal per game day), median %s, longest %s, still stuck at the end %d; ahead: %s%s"
			% (r["sp"], r["hours"], r["spells"], r["per_day"], med, longest, r["open"], ahead, ("; first: " + spots) if spots else ""))

	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
