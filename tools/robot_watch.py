#!/usr/bin/env python3
"""Reads a robot watch run (tools/robots.sh 2 watch ...) and prints a PASS or FAIL per measure of how one player draws another.

    python3 tools/robot_watch.py /tmp/robots_XXXX

Robot 1 (the walker) prints EVENT lines: walk, stop (with its real speed over the leg), swing, sleep_on, sleep_off, end. Robot 2 (the
watcher) prints a W line every frame for each other player: peer, unix ms, drawn x y z, state byte, clip, held item to hand mount (m, -1 none).
Both run on one machine, so their unix ms share a clock. The measures (players thread, 23 Nov 2026; test_remote_players.gd _check_lossy is
the same maths offline):
  jumps      per leg, the fastest drawn speed over any 50 ms window, against the walker's real speed: FAIL above 1.5 times
  stalls     per leg, 50 ms windows under 0.3 m/s while the drawn body should be walking (between its first move and its stop): FAIL on any
  overshoot  per stop, the farthest the drawn body goes past the stop point along the leg: FAIL above speed x 0.8 s + 0.3 m;
             and it settles within 0.15 m of the stop point within 3 s
  held       the held item within 0.25 m of a hand mount in every frame it is drawn
  swing      after each swing, the watcher's clip is chop, pick_overhead or jab within 1 s
  sleep      the asleep bit (state & 16) shows while the walker sleeps
Exit 0 all PASS, 1 a FAIL, 2 nothing to read.
"""
import glob
import math
import os
import sys

WINDOW_MS = 50
JUMP_X = 1.5
STALL_MPS = 0.3
OVERSHOOT_S = 0.8
OVERSHOOT_M = 0.3
SETTLE_M = 0.15
SETTLE_MS = 3000
HELD_M = 0.25
SWING_MS = 1000
SWING_CLIPS = ("chop", "pick_overhead", "jab")
ASLEEP = 16
MIN_LEGS = 4    # of the walker's 6


def read(d):
	events, rows, walker_peer = [], [], None

	for path in sorted(glob.glob(os.path.join(d, "robot*_play.log"))):
		for line in open(path, encoding="utf-8", errors="replace"):
			if not line.startswith("ROBOT "):
				continue

			p = line.split()

			if len(p) > 4 and p[3] == "EVENT":
				events.append({"kind": p[4], "ms": int(p[5]), "pos": (float(p[6]), float(p[8])), "extra": p[9:]})
			elif len(p) > 4 and p[3] == "W":
				rows.append({"peer": int(p[4]), "ms": int(p[5]), "pos": (float(p[6]), float(p[8])), "state": int(p[9]), "clip": p[10], "held": float(p[11])})
			elif "step joined: peer" in line and p[1] + p[2] == "Robot1":
				walker_peer = int(line.split("peer ")[1].split()[0])

	if walker_peer is not None:
		rows = [r for r in rows if r["peer"] == walker_peer]

	rows.sort(key=lambda r: r["ms"])
	return events, rows


def dist(a, b):
	return math.hypot(a[0] - b[0], a[1] - b[1])


def windows(rows):
	"""(start ms, end ms, m/s) over spans of at least WINDOW_MS, one starting at each frame."""
	out = []
	j = 0

	for i in range(len(rows)):
		j = max(j, i + 1)

		while j < len(rows) and rows[j]["ms"] - rows[i]["ms"] < WINDOW_MS:
			j += 1

		if j >= len(rows):
			break

		dt = (rows[j]["ms"] - rows[i]["ms"]) / 1000.0

		if dt <= 0.4:   # a gap this long is a frame hitch of the watcher, not a drawn speed
			out.append((rows[i]["ms"], rows[j]["ms"], dist(rows[i]["pos"], rows[j]["pos"]) / dt))

	return out


def main():
	if len(sys.argv) < 2 or not os.path.isdir(sys.argv[1]):
		print(__doc__)
		return 2

	events, rows = read(sys.argv[1])

	if not events or not rows:
		print("robot_watch: no walker EVENT lines or no watcher W lines")
		return 2

	results = []

	def say(ok, what):
		results.append(ok)
		print(("PASS " if ok else "FAIL ") + what)

	frame_ms = sorted(b["ms"] - a["ms"] for a, b in zip(rows, rows[1:]))
	print("watch: %d watcher frames, median frame %d ms, slowest %d ms" % (len(rows), frame_ms[len(frame_ms) // 2], frame_ms[-1]))
	legs = []

	for i, e in enumerate(events):
		if e["kind"] == "walk":
			stop = next((s for s in events[i + 1:] if s["kind"] == "stop"), None)

			if stop:
				nxt = next((s for s in events[i + 1:] if s["kind"] in ("walk", "swing", "sleep_on", "end")), None)
				legs.append((e, stop, nxt["ms"] if nxt else stop["ms"] + 3500))

	measured = 0

	for n, (walk, stop, after_ms) in enumerate(legs, 1):
		speed = float(stop["extra"][0])
		name = "leg %d (%s, real %.2f m/s)" % (n, walk["extra"][2] if len(walk["extra"]) > 2 else "walk", speed)
		seg = [r for r in rows if walk["ms"] <= r["ms"] <= after_ms]

		if len(seg) < 4 or speed < 0.5:
			print("SKIP %s: %d frames drawn, the walker barely moved" % (name, len(seg)))
			continue

		measured += 1

		moved = next((r for r in seg if dist(r["pos"], walk["pos"]) > 0.2), None)
		arrived = next((r for r in seg if dist(r["pos"], stop["pos"]) < max(0.5, speed * 0.15)), None)
		win = windows(seg)
		top = max((w[2] for w in win), default=0.0)
		say(top <= speed * JUMP_X, "jumps %s: fastest drawn %.2f m/s over %d ms windows (%.2fx)" % (name, top, WINDOW_MS, top / speed))

		if moved and arrived:
			lo, hi = moved["ms"] + 200, arrived["ms"] - 200
			stalls = [w for w in win if w[0] >= lo and w[1] <= hi and w[2] < STALL_MPS]
			say(not stalls, "stalls %s: %d windows under %.1f m/s between its first move and its stop (drawn %d ms behind)%s" % (
				name, len(stalls), STALL_MPS, moved["ms"] - walk["ms"], "" if not stalls else ", first at +%d ms" % (stalls[0][0] - walk["ms"])))
		else:
			say(False, "stalls %s: the drawn body never %s" % (name, "moved" if not moved else "reached the stop point"))

		ux, uz = float(walk["extra"][0]), float(walk["extra"][1])
		post = [r for r in rows if stop["ms"] <= r["ms"] <= stop["ms"] + SETTLE_MS]
		past = max([(r["pos"][0] - stop["pos"][0]) * ux + (r["pos"][1] - stop["pos"][1]) * uz for r in post] + [0.0])
		limit = speed * OVERSHOOT_S + OVERSHOOT_M
		say(past <= limit, "overshoot %s: %.2f m past the stop (limit %.2f)" % (name, past, limit))
		end = post[-1] if post else None
		off = dist(end["pos"], stop["pos"]) if end else float("inf")
		say(off <= SETTLE_M, "settle %s: %.2f m from the stop point %d ms after it" % (name, off, (end["ms"] - stop["ms"]) if end else -1))

	need = max(1, min(MIN_LEGS, len(legs)))
	say(measured >= need, "legs: %d of %d legs measured (at least %d: a walker that never moved, or a watcher that drew nothing, is not a pass)" % (measured, len(legs), need))
	held = [r for r in rows if r["held"] >= 0.0]
	bad = [r for r in held if r["held"] > HELD_M]
	say(bool(held) and not bad, "held: %d frames with the item drawn, %d over %.2f m from a hand mount, farthest %.2f m" % (
		len(held), len(bad), HELD_M, max((r["held"] for r in held), default=-1.0)))

	for e in [e for e in events if e["kind"] == "swing"]:
		shown = next((r for r in rows if e["ms"] <= r["ms"] <= e["ms"] + SWING_MS and any(c in r["clip"] for c in SWING_CLIPS)), None)
		say(shown is not None, "swing at %d: %s" % (e["ms"], "shown as %s after %d ms" % (shown["clip"], shown["ms"] - e["ms"]) if shown else
			"no work clip within %d ms (clips seen: %s)" % (SWING_MS, ", ".join(sorted({r["clip"] for r in rows if e["ms"] <= r["ms"] <= e["ms"] + SWING_MS})))))

	on = next((e for e in events if e["kind"] == "sleep_on"), None)
	off_e = next((e for e in events if e["kind"] == "sleep_off"), None)

	if on and off_e:
		asleep = [r for r in rows if on["ms"] <= r["ms"] <= off_e["ms"] + 1000 and r["state"] & ASLEEP]
		first = asleep[0]["ms"] - on["ms"] if asleep else -1
		say(bool(asleep), "sleep: asleep bit shown %s" % ("after %d ms, %d frames" % (first, len(asleep)) if asleep else "never"))
	else:
		say(False, "sleep: the walker never slept")

	print("robot_watch: %d PASS, %d FAIL" % (results.count(True), results.count(False)))
	return 0 if all(results) else 1


if __name__ == "__main__":
	sys.exit(main())
