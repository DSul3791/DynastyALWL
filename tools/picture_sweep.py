#!/usr/bin/env python3
"""Picture sweep: takes in-game pictures of everything for tools/picture_check.py, on Dave's PC lane only (Godot never runs in
the cloud). Dave, 26 Nov 2026: "ok make it" (thread "Build an automatic picture checker").

Run from the lane clone (C:/DynastyLane/clone), in the foreground. Every job is one run of an existing in-game picture tool
with a time limit; this script waits for it and stops its whole process tree (taskkill /T on Windows) when the limit passes,
when the lane's CANCEL file appears, or on Ctrl-C. Nothing it started is left running.
A job whose pictures are already there is skipped, so the sweep can run in slices between bug-fix tests and pick up where it
stopped (delete a job's folder to take its pictures again; a job cut off part way is taken again). Stops starting jobs after --time-limit.
Times take a unit (90s, 20m, 2h). After every job it also stops anything still running that the job started, found by the tag in
the job's own temp folder (look_rig's throwaway server is outside the process tree), and stops the sweep if one would not stop.

    python tools/picture_sweep.py --out C:/DynastyLane/logs/sweep [--groups animals,young,held,worn,pieces,tiers]
                                  [--max-jobs N] [--time-limit 2h] [--job-limit 5m] [--list]

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
Exit: 0 all jobs done, 3 stopped early (cancel, time, --max-jobs, something left running), 1 some jobs failed (listed in sweep_jobs.json).
"""
import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import time
import uuid

WIN = os.name == "nt"
GODOT = os.environ.get("GODOT_EXE", "C:/DynastyLane/godot/godot_lane_a.exe" if WIN else "godot")
CANCEL = os.environ.get("PICTURE_CHECK_CANCEL", "C:/DynastyLane/logs/queue/CANCEL" if WIN else "/tmp/picture_sweep_CANCEL")
GROUPS = ["animals", "young", "held", "worn", "pieces", "tiers"]
GIT_BASH = "C:/Program Files/Git/bin/bash.exe"
# Git bash, never the WSL bash.exe that a bare "bash" finds first in System32 (look_rig.sh would run in its Linux mode).
BASH = os.environ.get("BASH_EXE") or (GIT_BASH if WIN and os.path.isfile(GIT_BASH) else shutil.which("bash") or "bash")


def load(path):
	with open(path, encoding="utf-8") as f:
		return json.load(f)


def chunks(names, n):
	return [names[i:i + n] for i in range(0, len(names), n)]


def join(*parts):
	return "/".join(parts)   # forward slashes only: these paths go to Godot and Git bash as they are


def godot(script, args):
	return [GODOT, "--path", ".", "--script", "res://tools/%s" % script, "--"] + args


def jobs(out):
	"""Every job: (name, folder, commands, time limit s, the pictures it must leave, about text). The second command, if any, runs
	only when the first exits 2 with no pictures (shot_held.gd refuses bows, spears, nets, shields, torches...: look_rig.sh holds those)."""
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
		folder = join(out, "animals", "%02d" % i)
		out_jobs.append(("animals_%02d" % i, folder, godot("creature_check.gd", ["--kinds=" + ",".join(group), "--out=" + folder]),
			900, [join(folder, k + ".png") for k in group], strip % ", ".join(group)))
	for i, group in enumerate(chunks(species, 6)):
		folder = join(out, "young", "%02d" % i)
		out_jobs.append(("young_%02d" % i, folder, godot("creature_check.gd", ["--young", "--kinds=" + ",".join(group), "--out=" + folder]),
			900, [join(folder, "young_" + k + ".png") for k in group], "Young animals: " + strip % ", ".join(group)))
	for item in held:
		folder = join(out, "held", item)
		out_jobs.append(("held_" + item, folder, [godot("shot_held.gd", ["--item=" + item, "--out=" + folder, "--name=" + item]),
			[BASH, "tools/look_rig.sh", "--item", item, "--angles", "right:-90:1.6;left:90:1.6;hand:-90:0.7;front:0:1.6", "--name", item,
			"--out", folder]], 900, [folder + "/%s_%s.png" % (item, a) for a in ("right", "left", "hand", "front")],
			"The game's player body standing in its idle pose (on a flat test floor, or in the world at the spawn), holding a %s (%s) in its hand as the game "
			"holds it; the file name ends with the camera angle (right, left, hand = close on the hand, front). The item should "
			"sit in the hand, gripped, not through the body." % (name_of.get(item, item), item)))
	poses = [("idle_front", "idle", 180, ""), ("idle_side", "idle", 90, ""), ("walk_side", "walk", 90, "0,-1.4"), ("run_side", "run", 90, "0,-6")]
	for item in worn:
		folder = join(out, "worn", item)
		for pose, clip, yaw, move in poses:
			shot = join(folder, "%s_%s.png" % (item, pose))
			args = ["--clip=" + clip, "--yaw=%d" % yaw, "--worn=" + item, "--out=" + shot]
			if move:
				args.append("--move=" + move)
			out_jobs.append(("worn_%s_%s" % (item, pose), folder, godot("body_pose_shot.gd", args), 180, [shot],
				"The game's player body wearing %s (%s), on a small ground plane with 0.5 m grid lines; the file name says the "
				"pose (idle, walk or run, held mid-clip) and the side seen (front or side). The worn item should cover its part of "
				"the body with no skin showing through it, and the feet should be on the ground." % (name_of.get(item, item), item)))
	for i, group in enumerate(chunks(pieces, 8)):
		folder = join(out, "pieces", "%02d" % i)
		out_jobs.append(("pieces_%02d" % i, folder, [BASH, "tools/look_rig.sh", "--pieces", ",".join(group), "--name", "pieces_%02d" % i,
			"--out", folder], 900, [folder + "/"], "A labelled row of building pieces built by the game in the world, 4 m ahead: %s. "
			"Each piece should stand on the ground (not float or sink), whole, with its texture; the labels are the tester's." % ", ".join(group)))
	for quality, tier in ((0, "low"), (3, "high")):
		for yaw in (0, 90, 180, -90):
			name = "tiers_%s_yaw%d" % (tier, yaw)
			folder = join(out, "tiers", name)
			out_jobs.append((name, folder, [BASH, "tools/look_rig.sh", "--frametime", "8", "--quality", str(quality), "--yaw", str(yaw),
				"--name", name, "--out", folder], 900, [folder + "/"],
				"The game's own first-person view at the spawn on the %s graphics setting, facing %d degrees: ground, trees, grass, "
				"water and the camp as a new player sees them. The text in the corners is the tester's." % (tier.capitalize(), yaw)))
	# every job's commands as a list of commands
	return [(n, f, c if isinstance(c[0], list) else [c], t, m, a) for n, f, c, t, m, a in out_jobs]


def stop_tree(proc):
	"""Stop a run this script started and everything it started (look_rig.sh starts a Godot server and client)."""
	if proc.poll() is not None:
		return
	if WIN:
		subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
	else:
		try:
			os.killpg(proc.pid, signal.SIGKILL)
		except OSError:
			pass
	try:
		proc.wait(timeout=30)
	except subprocess.TimeoutExpired:
		proc.kill()


def duration(text):
	"""A time with its unit: 90s, 5m or 2h. A bare number is refused: a job limit of "5" once meant 5 minutes to the lane and
	5 seconds to this script."""
	units = {"s": 1, "m": 60, "h": 3600}
	try:
		if text[-1:] in units and float(text[:-1]) > 0:
			return float(text[:-1]) * units[text[-1]]
	except ValueError:
		pass
	raise argparse.ArgumentTypeError("give a time with its unit, like 90s, 20m or 2h (got %r)" % text)


def tagged(tag):
	"""Process ids whose command line (or, on Linux, environment) holds this job's tag: everything the job started, also what
	escaped its process tree (look_rig.sh's throwaway server runs in the background of Git bash, out of taskkill /T's reach)."""
	if WIN:
		ps = ("Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*%s*' } | "
			"ForEach-Object { $_.ProcessId }" % tag)
		try:
			r = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", ps], capture_output=True, text=True, timeout=60)
		except (OSError, subprocess.TimeoutExpired) as e:
			raise RuntimeError("could not list processes: %s" % type(e).__name__)
		if r.returncode != 0:
			raise RuntimeError("could not list processes: powershell exit %d %s" % (r.returncode, r.stderr.strip()[:200]))
		return [int(x) for x in r.stdout.split() if x.isdigit()]
	found = []
	for pid in os.listdir("/proc"):
		if not pid.isdigit() or int(pid) == os.getpid():
			continue
		for part in ("cmdline", "environ"):
			try:
				with open("/proc/%s/%s" % (pid, part), "rb") as f:
					if tag.encode() in f.read():
						found.append(int(pid))
						break
			except OSError:
				pass
	return found


def stop_tagged(tag):
	"""Stop every process of this job by its tag; the ids still running after three tries (none, normally), or a text when the
	processes could not be listed (unknown counts as left running: the sweep stops)."""
	try:
		return stop_tagged_or_raise(tag)
	except RuntimeError as e:
		return str(e)


def stop_tagged_or_raise(tag):
	left = []
	for _ in range(3):
		left = tagged(tag)
		if not left:
			return []
		for pid in left:
			if WIN:
				subprocess.run(["taskkill", "/F", "/T", "/PID", str(pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
			else:
				try:
					os.kill(pid, signal.SIGKILL)
				except OSError:
					pass
		time.sleep(2.0)
	return [pid for pid in tagged(tag) if WIN or not zombie(pid)]


def zombie(pid):
	try:
		with open("/proc/%d/stat" % pid) as f:
			return f.read().rsplit(")", 1)[1].split()[0] == "Z"
	except OSError:
		return True


def run_one(command, limit, log, env):
	"""Run one command in the foreground; stop its whole tree at the time limit, when CANCEL appears, or on Ctrl-C."""
	extra = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if WIN else {"start_new_session": True}
	proc = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, env=env, **extra)
	t0 = time.time()
	try:
		while proc.poll() is None:
			if time.time() - t0 > limit:
				stop_tree(proc)
				return "timeout %d s" % limit
			if os.path.exists(CANCEL):
				stop_tree(proc)
				return "cancelled"
			time.sleep(1.0)
		return proc.returncode
	finally:
		stop_tree(proc)   # Ctrl-C or any error: nothing this script started stays running


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
	ap.add_argument("--time-limit", type=duration, default=3 * 3600.0, help="start no job after this, like 90m or 2h")
	ap.add_argument("--job-limit", type=duration, default=0, help="at most this long a job, like 90s or 5m (lower than its own limit)")
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
	args.out = os.path.abspath(args.out).replace("\\", "/")
	todo = [j for j in jobs(args.out) if j[0].split("_")[0] in wanted]
	record_path = os.path.join(args.out, "sweep_jobs.json")
	record = load(record_path) if os.path.isfile(record_path) else {}
	# done: recorded ok, or pictures there from before the record; a job cut off part way is taken again
	left = [j for j in todo if not ((record.get(j[0], {}).get("ok") or j[0] not in record) and done(j[4]))]
	print("picture sweep: %d jobs in %s, %d done, %d to run" % (len(todo), ",".join(wanted), len(todo) - len(left), len(left)))
	if args.list:
		for j in left:
			print("  " + j[0])
		return 0
	started = time.time()
	stopped, ran = "", 0
	for name, folder, commands, limit, must, about in left:
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
		# The job's own temp folder carries a tag: look_rig.sh makes its rig (and the server's --store) in it, so whatever the job
		# started can be found and stopped by that tag after it, also a server outside the process tree.
		tag = "sweeprig" + uuid.uuid4().hex[:12]
		tmp = join(home, tag)
		os.makedirs(tmp, exist_ok=True)
		env = dict(os.environ, APPDATA=home, TEMP=tmp, TMP=tmp, TMPDIR=tmp)   # the tool's own settings, never Dave's
		t0 = time.time()
		with open(os.path.join(folder, "run.log"), "w", encoding="utf-8") as log:
			try:
				for command in commands:
					code = run_one(command, min(limit, args.job_limit or limit), log, env)
					if code != 2 or done(must):
						break
			finally:
				survivors = stop_tagged(tag)
				shutil.rmtree(tmp, ignore_errors=True)
		if survivors:
			stopped = "job %s: processes it started may still run (%s); look on the PC before the next run" % (name, survivors)
			code = "left running %s" % survivors
		if code == "cancelled":
			stopped = "the lane's CANCEL file is there (job %s stopped)" % name
		ok = code == 0 and done(must)
		record[name] = {"ok": ok, "exit": code, "seconds": round(time.time() - t0, 1)}
		with open(record_path + ".tmp", "w", encoding="utf-8") as f:
			json.dump(record, f, indent=1)
		os.replace(record_path + ".tmp", record_path)
		ran += 1
		print("picture sweep: %s %s (exit %s, %.0f s)" % (name, "ok" if ok else "FAIL", code, time.time() - t0))
		if stopped:
			break
	names = {j[0] for j in todo}
	failed = [n for n, r in record.items() if n in names and not r["ok"]]
	print("picture sweep: ran %d, %d failed so far%s" % (ran, len(failed), "; stopped: " + stopped if stopped else ""))
	if stopped:
		return 3
	return 1 if failed else 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
