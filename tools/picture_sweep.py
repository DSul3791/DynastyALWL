#!/usr/bin/env python3
"""Picture sweep: takes in-game pictures of everything for tools/picture_check.py, on Dave's PC lane only (Godot never runs in
the cloud). Dave, 26 Nov 2026: "ok make it" (thread "Build an automatic picture checker").

Run from the lane clone (C:/DynastyLane/clone), in the foreground. Every job is one Godot run of an existing in-game picture
tool with a time limit; this script waits for it and stops it when the limit passes (it started it). Nothing is left running.
A job whose pictures are already there is skipped, so the sweep can run in slices between bug-fix tests and pick up where it
stopped. Stops between jobs when the lane's CANCEL file exists or the --time-limit passes.

    python tools/picture_sweep.py --out C:/DynastyLane/logs/sweep [--groups animals,young,held,worn,pieces,tiers]
                                  [--max-jobs N] [--time-limit S] [--list]

Groups (each picture folder gets an about.txt that tells the checker what it should show):
  animals  tools/creature_check.gd, 6 species a run: one strip per species, rest pose then every role (graze, alert, wind-up,
           warn, charge, recover, lie, drink, walk, trot, run), side view on a 1 m grid      (data/animals/models.json)
  young    the same for the young animals
  held     tools/shot_held.gd: every tool and weapon (items.json kind tool or weapon) in the hand, 4 angles
  worn     tools/body_pose_shot.gd: every worn item (data/items/worn.json) on the body: idle front, idle side, walk side,
           run side
  pieces   tools/look_rig.sh --pieces: every structure (data/items/structures.json), 8 a run, wide and close, in the world
  tiers    tools/look_rig.sh --frametime 8 at the spawn on Low (quality 0) and High (3), four directions
Then:  python tools/picture_check.py C:/DynastyLane/logs/sweep --out C:/DynastyLane/logs/sweep
Exit: 0 all jobs done, 3 stopped early (cancel, time, --max-jobs), 1 some jobs failed (listed in sweep_jobs.json).
"""
import argparse
import json
import os
import subprocess
import sys
import time

WIN = os.name == "nt"
GODOT = os.environ.get("GODOT_EXE", "C:/DynastyLane/godot/godot_lane_a.exe" if WIN else "godot")
CANCEL = os.environ.get("PICTURE_CHECK_CANCEL", "C:/DynastyLane/logs/queue/CANCEL" if WIN else "/tmp/picture_sweep_CANCEL")
GROUPS = ["animals", "young", "held", "worn", "pieces", "tiers"]


def load(path):
	with open(path, encoding="utf-8") as f:
		return json.load(f)


def chunks(names, n):
	return [names[i:i + n] for i in range(0, len(names), n)]


def godot(script, args):
	return [GODOT, "--path", ".", "--script", "res://tools/%s" % script, "--"] + args


def jobs(out):
	"""Every job: (name, folder, command, time limit s, the pictures it must leave, about text)."""
	items = load("data/items/items.json")["items"]
	name_of = {k: v.get("name", k) for k, v in items.items()}
	species = list(load("data/animals/models.json")["species"])
	held = [k for k, v in items.items() if v.get("kind") in ("tool", "weapon")]
	worn = list(load("data/items/worn.json")["items"])
	pieces = list(load("data/items/structures.json")["structures"])
	strip = ("one picture strip per animal model, side view on a ground plane with a 1 m grid: the rest pose first, then each "
		"role the model has (graze, alert, wind-up, warn, charge, recover, lie, drink, walk, trot, run), each paused 40%% into "
		"its clip, a label under each. Every panel's feet, hooves or paws should touch the ground plane. Species: %s.")
	out_jobs = []
	for i, group in enumerate(chunks(species, 6)):
		folder = os.path.join(out, "animals", "%02d" % i)
		out_jobs.append(("animals_%02d" % i, folder, godot("creature_check.gd", ["--kinds=" + ",".join(group), "--out=" + folder]),
			900, [os.path.join(folder, k + ".png") for k in group], strip % ", ".join(group)))
	for i, group in enumerate(chunks(species, 6)):
		folder = os.path.join(out, "young", "%02d" % i)
		out_jobs.append(("young_%02d" % i, folder, godot("creature_check.gd", ["--young", "--kinds=" + ",".join(group), "--out=" + folder]),
			900, [os.path.join(folder, "young_" + k + ".png") for k in group], "Young animals: " + strip % ", ".join(group)))
	for item in held:
		folder = os.path.join(out, "held", item)
		out_jobs.append(("held_" + item, folder, godot("shot_held.gd", ["--item=" + item, "--out=" + folder, "--name=" + item]),
			180, [os.path.join(folder, "%s_%s.png" % (item, a)) for a in ("right", "left", "hand", "front")],
			"The game's player body standing in its idle pose on a flat test floor, holding a %s (%s) in its hand as the game "
			"holds it; the file name ends with the camera angle (right, left, hand = close on the hand, front). The item should "
			"sit in the hand, gripped, not through the body." % (name_of.get(item, item), item)))
	poses = [("idle_front", "idle", 180, ""), ("idle_side", "idle", 90, ""), ("walk_side", "walk", 90, "0,-1.4"), ("run_side", "run", 90, "0,-6")]
	for item in worn:
		folder = os.path.join(out, "worn", item)
		for pose, clip, yaw, move in poses:
			shot = os.path.join(folder, "%s_%s.png" % (item, pose))
			args = ["--clip=" + clip, "--yaw=%d" % yaw, "--worn=" + item, "--out=" + shot]
			if move:
				args.append("--move=" + move)
			out_jobs.append(("worn_%s_%s" % (item, pose), folder, godot("body_pose_shot.gd", args), 180, [shot],
				"The game's player body wearing %s (%s), on a small ground plane with 0.5 m grid lines; the file name says the "
				"pose (idle, walk or run, held mid-clip) and the side seen (front or side). The worn item should cover its part of "
				"the body with no skin showing through it, and the feet should be on the ground." % (name_of.get(item, item), item)))
	for i, group in enumerate(chunks(pieces, 8)):
		folder = os.path.join(out, "pieces", "%02d" % i)
		out_jobs.append(("pieces_%02d" % i, folder, ["bash", "tools/look_rig.sh", "--pieces", ",".join(group), "--name", "pieces_%02d" % i,
			"--out", folder], 900, [folder + "/"], "A labelled row of building pieces built by the game in the world, 4 m ahead: %s. "
			"Each piece should stand on the ground (not float or sink), whole, with its texture; the labels are the tester's." % ", ".join(group)))
	for quality, tier in ((0, "low"), (3, "high")):
		for yaw in (0, 90, 180, -90):
			name = "tiers_%s_yaw%d" % (tier, yaw)
			folder = os.path.join(out, "tiers", name)
			out_jobs.append((name, folder, ["bash", "tools/look_rig.sh", "--frametime", "8", "--quality", str(quality), "--yaw", str(yaw),
				"--name", name, "--out", folder], 900, [folder + "/"],
				"The game's own first-person view at the spawn on the %s graphics setting, facing %d degrees: ground, trees, grass, "
				"water and the camp as a new player sees them. The text in the corners is the tester's." % (tier.capitalize(), yaw)))
	return out_jobs


def done(must):
	for path in must:
		if path.endswith("/"):
			if not (os.path.isdir(path) and any(n.lower().endswith(".png") for n in os.listdir(path))):
				return False
		elif not os.path.isfile(path):
			return False
	return True


def main(argv):
	ap = argparse.ArgumentParser(description="Take in-game pictures of everything for tools/picture_check.py (Dave's PC lane only).")
	ap.add_argument("--out", required=True)
	ap.add_argument("--groups", default=",".join(GROUPS))
	ap.add_argument("--max-jobs", type=int, default=0)
	ap.add_argument("--time-limit", type=float, default=3 * 3600.0)
	ap.add_argument("--list", action="store_true", help="print the jobs and how many are done; run nothing")
	args = ap.parse_args(argv)
	if not os.path.isfile("project.godot"):
		print("picture sweep: run it from the clone (C:/DynastyLane/clone)")
		return 2
	wanted = [g for g in args.groups.split(",") if g]
	bad = [g for g in wanted if g not in GROUPS]
	if bad:
		print("picture sweep: unknown group %s (groups: %s)" % (",".join(bad), ",".join(GROUPS)))
		return 2
	todo = [j for j in jobs(args.out) if j[0].split("_")[0] in wanted]
	left = [j for j in todo if not done(j[4])]
	print("picture sweep: %d jobs in %s, %d done, %d to run" % (len(todo), ",".join(wanted), len(todo) - len(left), len(left)))
	if args.list:
		for j in left:
			print("  " + j[0])
		return 0
	started = time.time()
	record_path = os.path.join(args.out, "sweep_jobs.json")
	record = load(record_path) if os.path.isfile(record_path) else {}
	stopped, ran = "", 0
	for name, folder, command, limit, must, about in left:
		if os.path.exists(CANCEL):
			stopped = "the lane's CANCEL file is there"
		elif time.time() - started > args.time_limit:
			stopped = "time limit %d s" % args.time_limit
		elif args.max_jobs and ran >= args.max_jobs:
			stopped = "--max-jobs %d reached" % args.max_jobs
		if stopped:
			break
		os.makedirs(folder, exist_ok=True)
		with open(os.path.join(folder, "about.txt"), "w", encoding="utf-8") as f:
			f.write(about + "\n")
		home = os.path.join(args.out, "_home")
		os.makedirs(home, exist_ok=True)
		env = dict(os.environ, APPDATA=home, TEMP=home, TMP=home)   # the tool's own settings, never Dave's
		t0 = time.time()
		with open(os.path.join(folder, "run.log"), "w", encoding="utf-8") as log:
			try:
				code = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, env=env, timeout=limit).returncode
			except subprocess.TimeoutExpired:   # subprocess.run stops the run it started, then returns here
				code = "timeout %d s" % limit
		ok = done(must)
		record[name] = {"ok": ok, "exit": code, "seconds": round(time.time() - t0, 1)}
		with open(record_path, "w", encoding="utf-8") as f:
			json.dump(record, f, indent=1)
		ran += 1
		print("picture sweep: %s %s (exit %s, %.0f s)" % (name, "ok" if ok else "FAIL", code, time.time() - t0))
	failed = [n for n, r in record.items() if not r["ok"]]
	print("picture sweep: ran %d, %d failed so far%s" % (ran, len(failed), "; stopped: " + stopped if stopped else ""))
	if stopped:
		return 3
	return 1 if failed else 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
