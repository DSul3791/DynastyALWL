#!/usr/bin/env python3
"""Picture checker: sends in-game pictures (all the views of one subject, the PNGs of one folder, in one request) to the Claude API and lists what looks wrong (floating or sunk animals and items,
a tool or weapon through a body, skin through clothes, feet off or in the ground, missing textures, broken meshes).
Dave, 26 Nov 2026: "ok make it" (his API credits, a one-off sweep; thread "Build an automatic picture checker").

Python standard library only, so it runs on Dave's PC with nothing installed (the Anthropic SDK is not there: raw HTTPS).
Godot is not involved: the pictures come from the lane's in-game tools (look_rig, body_pose_shot) on Dave's PC.

    python tools/picture_check.py C:/DynastyLane/logs/<job>/shots [more folders or .png files] [options]
      --about "text"      what every picture should show (also a file about.txt in a picture's folder, for that folder)
      --out DIR           where the report goes (default: the first folder): picture_check.md (the list) and picture_check.json
      --dry-run           count the pictures and the most they could cost; sends nothing, needs no key
      --max-requests N    send at most N requests this run (one request = all the views of one subject, the pictures of one folder)
      --time-limit T      send no new request after T, with its unit: 90s, 20m, 2h (default 1h)
      --cap USD           the spending cap, kept in the ledger (default 150; only lowered or raised by passing it)
      --recheck           ask again about pictures already checked (default: reuse the stored answer, no cost)

Spending: every request first reserves its worst case (all input as a cache write, all max_tokens as output) in the ledger;
the answer's real usage replaces the reservation. A request whose worst case would pass the cap is never sent. A run cut off
mid-request, or a request whose answer never came back, stays counted at its worst case, so the total can only read high.
One check runs at a time (a lock file in that folder). The ledger and the stored answers
live in C:/DynastyLane/picture_check (outside the clone; PICTURE_CHECK_HOME overrides).
Key: read only from C:/DynastyLane/picture_check_key.txt (PICTURE_CHECK_KEY_FILE overrides); never printed, logged or stored.
Stops between pictures when C:/DynastyLane/logs/queue/CANCEL exists (the lane's cancel file).
Exit: 0 every picture checked, 1 some subjects look wrong, 2 bad use or no key, 3 something not checked (stopped early by the
cap, time, cancel or API errors, or a group holding a picture that is not a PNG or is over 5 MB).
"""
import argparse
import base64
import hashlib
import json
import math
import os
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

MODEL = "claude-opus-5-5"
# US dollars per million tokens (claude-opus-5-5, 26 Nov 2026): input, output, cache write (5 min), cache read.
PRICE = {"input": 4.00, "output": 20.00, "cache_write": 5.00, "cache_read": 0.20}
MAX_TOKENS = 8000
API_URL = os.environ.get("PICTURE_CHECK_API_URL", "https://api.anthropic.com/v1/messages")
WIN = os.name == "nt"
HOME = os.environ.get("PICTURE_CHECK_HOME", "C:/DynastyLane/picture_check" if WIN else os.path.expanduser("~/.picture_check"))
KEY_FILE = os.environ.get("PICTURE_CHECK_KEY_FILE", "C:/DynastyLane/picture_check_key.txt" if WIN else os.path.join(HOME, "key.txt"))
CANCEL = os.environ.get("PICTURE_CHECK_CANCEL", "C:/DynastyLane/logs/queue/CANCEL" if WIN else os.path.join(HOME, "CANCEL"))
MAX_IMAGE_BYTES = 5 * 1024 * 1024
MAX_GROUP_PICTURES = 8                # views of one subject in one request
MAX_GROUP_BYTES = 20 * 1024 * 1024    # the API takes 32 MB a request; base64 adds a third
PROMPT_VERSION = "2"

SYSTEM = """You check still pictures taken by an automatic tester inside a 3D game in development: Dynasty, a realistic \
medieval survival game made in Godot. One request holds the views of one test subject (a held tool, a worn piece of \
clothing, a row of building pieces, a scene), or one picture per subject when the description says so (an animal strip \
each). Find visible rendering and placement bugs, the kind a player would notice and report. You are not judging the art \
style, the art quality, the model detail or whether something looks AI-made: never report those.

Kinds of bug:
- floating: an animal, body, item or building piece hovers above the ground or a surface it should rest on (a gap or a \
missing contact shadow under feet, hooves, paws or the item).
- sunk: it sits too low: feet, hooves or the lower body inside the ground, an item buried, a wall or floor half inside the terrain.
- clipping: one thing passes through another: a tool or weapon through the body or a limb, a hand through a held item, \
two building pieces inside each other.
- skin_through_clothes: bare skin or the body mesh shows through worn clothing or armour where the clothing should cover it.
- held_wrong: a held item is not in the hand (floating beside it, at the wrong place, the wrong way round for how it is held).
- pose_wrong: a broken pose: limbs bent the wrong way, twisted joints, legs through each other, an animal in a pose no \
real animal makes.
- missing_texture: magenta or pink surfaces, a checkerboard, flat white or black surfaces where a texture belongs, \
white specks or holes in a surface.
- broken_mesh: stretched spikes, torn or exploded polygons, faces missing so the inside shows, a model with parts missing.
- wrong_scale: something clearly the wrong size against the things around it.
- lighting: a subject drawn fully black or burnt white when the scene around it is lit normally, or harsh flicker bands.
- other: any other plain rendering or placement bug a player would report.

What the tester does on purpose (never a bug):
- Every picture is a still: the body's animation is frozen at one moment. Standing (idle) bodies may stand with the feet \
apart or one foot ahead; walk and run stills are mid-stride. Only an impossible pose is a bug.
- The file name ends with the view: front, side, left, right, hand (a close view of the hand), wide, close, or a camera \
direction. A long item (spear, staff, tool handle) pointing toward the camera looks short or hidden: judge its length \
and grip from the side views, not the view that looks along it.
- In third-person views in the game world, the game itself cuts the grass short within about 1.4 m of the player so the \
feet show: a lower, flatter, plainer patch of ground round the player's feet is normal.
- Offline tools draw no world: a plain colour sky, a small flat green or grey ground plane with grid lines (0.5 m or 1 m \
apart) and a sun brighter than the game.
- Text in the corners and coloured name tags over items are the tester's labels. The HUD is hidden. Night or rain is \
dark when the description says so. The game's colours are realistic and muted.

How to judge:
- Look at all the views of a subject together before deciding.
- Verdict problem only when the bug shows in more than one view, or is unmistakable in one view (then say in "what" why \
one view is enough). A doubt seen in one view only, which another view does not confirm, makes the verdict unsure and \
goes in the problems list with confidence low. If nothing is wrong, the verdict is ok with no problems.
- Name the views each problem shows in (their file names) and where in the picture ("left hind hoof, lower middle").
- Severity high: a player notices at once; medium: on a closer look; low: small. Confidence: how sure you are it is a \
real bug and not the angle, the lighting or the picture's size.
- Keep every text field to one short sentence."""

KINDS = ["floating", "sunk", "clipping", "skin_through_clothes", "held_wrong", "pose_wrong", "missing_texture",
	"broken_mesh", "wrong_scale", "lighting", "other"]
LEVELS = ["low", "medium", "high"]
SCHEMA = {
	"type": "object",
	"additionalProperties": False,
	"required": ["subjects"],
	"properties": {"subjects": {"type": "array", "items": {
		"type": "object",
		"additionalProperties": False,
		"required": ["subject", "shows", "verdict", "confidence", "problems"],
		"properties": {
			"subject": {"type": "string", "description": "the subject's name, as in the description or the file name"},
			"shows": {"type": "string", "description": "what the views show, one sentence"},
			"verdict": {"type": "string", "enum": ["ok", "problem", "unsure"]},
			"confidence": {"type": "string", "enum": LEVELS},
			"problems": {"type": "array", "items": {
				"type": "object",
				"additionalProperties": False,
				"required": ["kind", "views", "where", "what", "severity", "confidence"],
				"properties": {
					"kind": {"type": "string", "enum": KINDS},
					"views": {"type": "array", "items": {"type": "string"}},
					"where": {"type": "string"},
					"what": {"type": "string"},
					"severity": {"type": "string", "enum": LEVELS},
					"confidence": {"type": "string", "enum": LEVELS},
				},
			}},
		},
	}}},
}


def png_size(data):
	"""Width and height of a PNG, or None when it is not one."""
	if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
		return None
	return struct.unpack(">II", data[16:24])


def image_tokens(width, height):
	"""Image input tokens, an over-estimate: about one token per 750 pixels after the API's scaling to 2576 px on the long edge."""
	scale = min(1.0, 2576.0 / max(width, height, 1))
	return int(width * scale * height * scale / 750.0) + 100


def worst_case(sizes, about=""):
	"""The most one request with pictures of these sizes could cost: every input token as a cache write, all max_tokens out."""
	tokens = sum(image_tokens(w, h) for w, h in sizes) + (len(SYSTEM) + len(about)) // 3 + 600
	return tokens * PRICE["cache_write"] / 1e6 + MAX_TOKENS * PRICE["output"] / 1e6


def cost_of(usage):
	return (usage.get("input_tokens", 0) * PRICE["input"] + usage.get("output_tokens", 0) * PRICE["output"]
		+ usage.get("cache_creation_input_tokens", 0) * PRICE["cache_write"]
		+ usage.get("cache_read_input_tokens", 0) * PRICE["cache_read"]) / 1e6


class Ledger:
	"""Money spent so far, saved after every change (write a temp file, then replace) so a cut-off run never loses a sum."""

	def __init__(self, path, cap):
		self.path = path
		self.data = {"cap_usd": 150.0, "spent_usd": 0.0, "reserved_usd": 0.0, "requests": 0, "pictures": 0}
		if os.path.exists(path):
			with open(path, encoding="utf-8") as f:
				self.data.update(json.load(f))
		# A reservation left by a run that was cut off stays counted as spent: it may have been billed.
		self.data["spent_usd"] += self.data["reserved_usd"]
		self.data["reserved_usd"] = 0.0
		if cap is not None:
			self.data["cap_usd"] = cap
		self.save()

	def total(self):
		return self.data["spent_usd"] + self.data["reserved_usd"]

	def left(self):
		return self.data["cap_usd"] - self.total()

	def reserve(self, usd):
		self.data["reserved_usd"] += usd
		self.save()

	def settle(self, reserved, usd, billed):
		self.data["reserved_usd"] = max(0.0, self.data["reserved_usd"] - reserved)
		self.data["spent_usd"] += usd
		if billed:
			self.data["requests"] += 1
		self.save()

	def save(self):
		os.makedirs(os.path.dirname(self.path), exist_ok=True)
		tmp = self.path + ".tmp"
		with open(tmp, "w", encoding="utf-8") as f:
			json.dump(self.data, f, indent=1)
		os.replace(tmp, self.path)


def read_key():
	try:
		with open(KEY_FILE, encoding="utf-8-sig") as f:
			key = f.read().strip()
	except OSError:
		return ""
	return key


def good_answer(answer):
	if not (isinstance(answer, dict) and isinstance(answer.get("subjects"), list) and answer["subjects"]):
		return False
	for sub in answer["subjects"]:
		if not (isinstance(sub, dict) and sub.get("verdict") in ("ok", "problem", "unsure") and isinstance(sub.get("problems"), list)):
			return False
		if not all(isinstance(p, dict) and all(k in p for k in ("kind", "views", "where", "what", "severity", "confidence")) for p in sub["problems"]):
			return False
	return True


def ask(key, pictures, about):
	"""One subject's views to the API (pictures: list of (file name, PNG bytes)).
	Returns (answer dict or None, usage dict, error text, attempts that may have been billed unseen)."""
	content = []
	for label, data in pictures:
		content.append({"type": "text", "text": "View: %s" % label})
		content.append({"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": base64.b64encode(data).decode("ascii")}})
	text = "%d view(s) of one test subject (or one picture per subject if the description says so).\n" % len(pictures)
	if about:
		text += "They should show: %s\n" % about
	text += "Judge each subject across all its views, by the rules above."
	content.append({"type": "text", "text": text})
	body = {
		"model": MODEL,
		"max_tokens": MAX_TOKENS,
		"system": [{"type": "text", "text": SYSTEM, "cache_control": {"type": "ephemeral"}}],
		"output_config": {"effort": "low", "format": {"type": "json_schema", "schema": SCHEMA}},
		"messages": [{"role": "user", "content": content}],
	}
	payload = json.dumps(body).encode("utf-8")
	headers = {"content-type": "application/json", "x-api-key": key, "anthropic-version": "2026-10-21"}
	error, unseen = "", 0
	for attempt in range(4):
		request = urllib.request.Request(API_URL, data=payload, headers=headers, method="POST")
		try:
			with urllib.request.urlopen(request, timeout=300) as response:
				reply = json.loads(response.read().decode("utf-8"))
		except urllib.error.HTTPError as e:
			detail = ""
			try:
				detail = json.loads(e.read().decode("utf-8")).get("error", {}).get("message", "")
			except Exception:
				pass
			error = "HTTP %d %s" % (e.code, detail[:200])
			if e.code in (408, 504):   # a gateway timeout may have been billed with no answer back: counted, not retried
				return None, {}, error, unseen + 1
			if e.code in (409, 429, 500, 502, 503, 529) and attempt < 3:   # refused before any work: not billed, safe to retry
				wait = e.headers.get("retry-after") if e.headers else None
				time.sleep(min(60.0, float(wait)) if wait and wait.replace(".", "", 1).isdigit() else 5.0 * (attempt + 1))
				continue
			return None, {}, error, unseen
		except Exception as e:   # network, cut-off reply (IncompleteRead), bad JSON
			# The request may have reached the API and been billed with no answer back: counted at its worst case, never retried
			# (a retry would spend past the one reservation the cap check allowed).
			return None, {}, "network: %s" % type(e).__name__, unseen + 1
		usage = reply.get("usage", {})
		if reply.get("stop_reason") == "refusal":
			return None, usage, "the API declined these pictures", unseen
		if reply.get("stop_reason") == "max_tokens":
			return None, usage, "answer cut off (max_tokens)", unseen
		out = "".join(b.get("text", "") for b in reply.get("content", []) if b.get("type") == "text")
		try:
			answer = json.loads(out)
		except ValueError:
			return None, usage, "answer was not JSON", unseen
		if not good_answer(answer):
			return None, usage, "answer had the wrong shape", unseen
		return answer, usage, "", unseen
	return None, {}, error, unseen


def find_pictures(paths):
	found = []
	for p in paths:
		if os.path.isdir(p):
			for root, dirs, files in os.walk(p):
				dirs[:] = [d for d in dirs if not d.startswith("_")]   # the sweep's _home (the tools' own settings), not pictures
				for name in sorted(files):
					if name.lower().endswith(".png"):
						found.append(os.path.join(root, name))
		elif p.lower().endswith(".png") and os.path.isfile(p):
			found.append(p)
	return sorted(set(os.path.normpath(f) for f in found))


def about_for(path, about):
	note = os.path.join(os.path.dirname(path), "about.txt")
	parts = [about] if about else []
	if os.path.isfile(note):
		with open(note, encoding="utf-8-sig") as f:
			parts.append(f.read().strip())
	return " ".join(x for x in parts if x)


def write_report(out_dir, rows, ledger, stopped):
	"""rows: one per request group: {"folder", "pictures": [...], "answer" or "error", "usd"}."""
	os.makedirs(out_dir, exist_ok=True)
	with open(os.path.join(out_dir, "picture_check.json"), "w", encoding="utf-8") as f:
		json.dump({"model": MODEL, "rows": rows, "spent_usd": round(ledger.total(), 4), "cap_usd": ledger.data["cap_usd"],
			"stopped": stopped}, f, indent=1)
	rank = {"high": 0, "medium": 1, "low": 2}
	subjects = [(r, s) for r in rows for s in (r.get("answer") or {}).get("subjects", [])]
	bad = [(r, s) for r, s in subjects if s.get("verdict") == "problem"]
	bad.sort(key=lambda rs: (min([rank.get(p.get("severity"), 3) for p in rs[1]["problems"]] or [3]), rank.get(rs[1].get("confidence"), 3), rs[0]["folder"]))
	unsure = [(r, s) for r, s in subjects if s.get("verdict") == "unsure"]
	missed = [r for r in rows if not r.get("answer")]
	lines = ["# Picture check", "",
		"%d subjects in %d pictures: %d look wrong, %d unsure, %d ok; %d picture groups not checked. Spent so far $%.2f of the $%.2f cap. Model %s."
		% (len(subjects), sum(len(r["pictures"]) for r in rows), len(bad), len(unsure), len(subjects) - len(bad) - len(unsure), len(missed),
		ledger.total(), ledger.data["cap_usd"], MODEL)]
	if stopped:
		lines += ["", "Stopped early: " + stopped]

	def problem_lines(sub):
		return ["  - %s (%s, sure: %s) in %s: %s. Where: %s." % (p["kind"], p["severity"], p["confidence"], ", ".join(map(str, p["views"])) or "?",
			str(p["what"]).rstrip("."), str(p["where"]).rstrip(".")) for p in sub["problems"]]

	lines += ["", "## What looks wrong (most serious first)", ""]
	if not bad:
		lines.append("Nothing.")
	for r, sub in bad:
		lines += ["- **%s** (sure: %s) `%s`: %s" % (sub.get("subject", "?"), sub.get("confidence", "?"), r["folder"], sub.get("shows", ""))] + problem_lines(sub)
	if unsure:
		lines += ["", "## Unsure (look by hand)", ""]
		for r, sub in unsure:
			lines += ["- **%s** `%s`: %s" % (sub.get("subject", "?"), r["folder"], sub.get("shows", ""))] + problem_lines(sub)
	if missed:
		lines += ["", "## Not checked", ""] + ["- `%s` (%d pictures): %s" % (r["folder"], len(r["pictures"]), r.get("error", "")) for r in missed]
	with open(os.path.join(out_dir, "picture_check.md"), "w", encoding="utf-8") as f:
		f.write("\n".join(lines) + "\n")


def make_groups(pictures, about):
	"""The pictures of one folder are the views of one subject: one request each, at most MAX_GROUP_PICTURES pictures (a bigger
	folder is split evenly, 9 views as 5 + 4) and MAX_GROUP_BYTES. The bytes are read here for the digest and dropped (read
	again just before sending, so a sweep's thousand pictures are never all in memory).
	Returns (folder, [(path, bytes on disk, (w, h) or None)], about text, digest, why not sendable or "")."""
	by_folder = {}
	for path in pictures:
		by_folder.setdefault(os.path.dirname(path), []).append(path)
	groups = []
	for folder in sorted(by_folder):
		paths = sorted(by_folder[folder])
		per = -(-len(paths) // -(-len(paths) // MAX_GROUP_PICTURES))   # even shares of at most MAX_GROUP_PICTURES
		text = about_for(paths[0], about)
		chunk, chunk_bytes, chunks = [], 0, []
		for path in paths:
			with open(path, "rb") as f:
				head = f.read(24)
			size_on_disk = os.path.getsize(path)
			if chunk and (len(chunk) >= per or chunk_bytes + size_on_disk > MAX_GROUP_BYTES):
				chunks.append(chunk)
				chunk, chunk_bytes = [], 0
			chunk.append((path, size_on_disk, png_size(head)))
			chunk_bytes += size_on_disk
		if chunk:
			chunks.append(chunk)
		for chunk in chunks:
			h = hashlib.sha256(text.encode("utf-8"))
			for path, _n, _s in chunk:
				h.update(os.path.basename(path).encode("utf-8") + b"\0")   # the answer names its views by file name
				with open(path, "rb") as f:
					h.update(f.read())
			why = ""
			if any(not s for _p, _n, s in chunk):
				why = "not a PNG: " + ", ".join(os.path.basename(p) for p, _n, s in chunk if not s)
			elif any(n > MAX_IMAGE_BYTES for _p, n, _s in chunk):
				why = "larger than 5 MB, the API's limit: " + ", ".join(os.path.basename(p) for p, n, _s in chunk if n > MAX_IMAGE_BYTES)
			groups.append((folder.replace("\\", "/"), chunk, text, h.hexdigest() + ":" + PROMPT_VERSION, why))
	return groups


def duration(text):
	"""A time with its unit (90s, 20m, 2h), the same as tools/picture_sweep.py; a bare number is refused."""
	units = {"s": 1, "m": 60, "h": 3600}
	try:
		if text[-1:] in units and float(text[:-1]) > 0:
			return float(text[:-1]) * units[text[-1]]
	except ValueError:
		pass
	raise argparse.ArgumentTypeError("give a time with its unit, like 90s, 20m or 2h (got %r)" % text)


def main(argv):
	ap = argparse.ArgumentParser(description="Send in-game pictures to the Claude API and list what looks wrong.")
	ap.add_argument("paths", nargs="+")
	ap.add_argument("--about", default="")
	ap.add_argument("--out", default="")
	ap.add_argument("--dry-run", action="store_true")
	ap.add_argument("--max-requests", type=int, default=0)
	ap.add_argument("--time-limit", type=duration, default=3600.0)
	ap.add_argument("--cap", type=float, default=None)
	ap.add_argument("--recheck", action="store_true")
	args = ap.parse_args(argv)
	if args.max_requests < 0:
		print("picture check: --max-requests must be 0 (no limit) or more")
		return 2
	if args.cap is not None and not (math.isfinite(args.cap) and args.cap >= 0):
		print("picture check: --cap must be a dollar amount")
		return 2
	url = urllib.parse.urlsplit(API_URL)
	if not (url.scheme == "https" or (url.scheme == "http" and url.hostname == "127.0.0.1" and not url.username)):
		print("picture check: the API address must be https (the key goes in its header)")
		return 2
	started = time.time()
	pictures = find_pictures(args.paths)
	if not pictures:
		print("picture check: no .png pictures in %s" % " ".join(args.paths))
		return 2
	out_dir = args.out or (args.paths[0] if os.path.isdir(args.paths[0]) else os.path.dirname(args.paths[0])) or "."
	answers_path = os.path.join(HOME, "answers.json")
	answers = {}
	if os.path.exists(answers_path):
		with open(answers_path, encoding="utf-8") as f:
			answers = json.load(f)

	groups = make_groups(pictures, args.about)
	new = [g for g in groups if (args.recheck or g[3] not in answers) and not g[4]]
	new = new[:args.max_requests or None]
	most = sum(worst_case([s for _p, _n, s in g[1]], g[2]) for g in new)
	print("picture check: %d pictures in %d subject groups, %d groups already checked, %d requests to send (%d pictures), at most $%.2f (worst case)"
		% (len(pictures), len(groups), sum(1 for g in groups if g[3] in answers and not args.recheck), len(new), sum(len(g[1]) for g in new), most))
	if args.dry_run:
		return 0
	key = read_key()
	if os.path.exists(answers_path) and not os.path.exists(os.path.join(HOME, "spent.json")) and args.cap is None:
		print("picture check: answers are stored but the spending ledger %s is gone; pass --cap with what is really left" % os.path.join(HOME, "spent.json"))
		return 2
	lock = os.path.join(HOME, "lock")
	os.makedirs(HOME, exist_ok=True)
	try:
		os.close(os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY))
	except FileExistsError:
		print("picture check: another check is running (or one was cut off: delete %s once none runs)" % lock)
		return 2
	try:
		return run(args, groups, key, answers, answers_path, out_dir, started)
	finally:
		os.remove(lock)


def run(args, groups, key, answers, answers_path, out_dir, started):
	if os.path.exists(answers_path):   # read again inside the lock: a run that finished meanwhile may have added answers
		with open(answers_path, encoding="utf-8") as f:
			answers = json.load(f)
	ledger = Ledger(os.path.join(HOME, "spent.json"), args.cap)
	if ledger.data["requests"] == 0 and args.max_requests != 1:
		args.max_requests = 1
		print("picture check: first run ever: one request only. Compare its cost with the Claude Console's usage, then run again.")
	print("picture check: spent so far $%.2f of the $%.2f cap" % (ledger.total(), ledger.data["cap_usd"]))
	if any((args.recheck or g[3] not in answers) and not g[4] for g in groups) and not key:
		print("picture check: no API key in %s (the one-time command is in docs/PICTURE_CHECK.md)" % KEY_FILE)
		return 2

	rows, stopped, sent, errors_in_row = [], "", 0, 0
	for folder, chunk, about, digest, why in groups:
		row = {"folder": folder, "pictures": [p.replace("\\", "/") for p, _n, _s in chunk]}
		if about:
			row["about"] = about
		if not args.recheck and digest in answers:
			row["answer"] = answers[digest]
			rows.append(row)
			continue
		if stopped:
			row["error"] = "not sent: " + stopped
		elif why:
			row["error"] = why
		else:
			reason = ""
			worst = worst_case([s for _p, _n, s in chunk], about)
			if os.path.exists(CANCEL):
				reason = "the lane's CANCEL file is there"
			elif time.time() - started > args.time_limit:
				reason = "time limit %d s" % args.time_limit
			elif args.max_requests and sent >= args.max_requests:
				reason = "--max-requests %d reached" % args.max_requests
			elif worst > ledger.left():
				reason = "the cap: $%.2f spent of $%.2f, the next request could cost $%.2f" % (ledger.total(), ledger.data["cap_usd"], worst)
			views = []
			if not reason:
				try:
					for p, n, size in chunk:
						with open(p, "rb") as f:
							data = f.read()
						if len(data) != n or png_size(data[:24]) != size:
							raise ValueError(os.path.basename(p))
						views.append((os.path.basename(p), data))
				except (OSError, ValueError) as e:
					views = []
					row["error"] = "not sent: a picture changed or went while checking (%s); check again when the sweep is done" % e
			if reason:
				stopped = reason
				row["error"] = "not sent: " + reason
			elif not views:
				pass
			else:
				ledger.reserve(worst)
				answer, usage, error, unseen = ask(key, views, about)
				del views
				usd = cost_of(usage) + unseen * worst
				ledger.settle(worst, usd, bool(usage))
				sent += 1
				row["usd"] = round(usd, 4)
				if answer is not None:
					row["answer"] = answer
					answers[digest] = answer
					ledger.data["pictures"] += len(chunk)
					ledger.save()
					tmp = answers_path + ".tmp"
					with open(tmp, "w", encoding="utf-8") as f:
						json.dump(answers, f)
					os.replace(tmp, answers_path)
					errors_in_row = 0
					said = ", ".join("%s %s" % (s.get("subject", "?"), s.get("verdict")) for s in answer["subjects"])
				else:
					row["error"] = error
					errors_in_row += 1
					if errors_in_row >= 5:
						stopped = "5 API errors in a row (last: %s)" % error
					said = "not checked: " + error
				print("picture check: %s (%d pictures): %s ($%.3f, total $%.2f)" % (folder, len(chunk), said, usd, ledger.total()))
		rows.append(row)

	write_report(out_dir, rows, ledger, stopped)
	wrong = sum(1 for r in rows for s in (r.get("answer") or {}).get("subjects", []) if s.get("verdict") == "problem")
	print("picture check: %d subjects look wrong; report %s; spent $%.2f of the $%.2f cap%s"
		% (wrong, os.path.join(out_dir, "picture_check.md"), ledger.total(), ledger.data["cap_usd"], "; stopped: " + stopped if stopped else ""))
	if stopped or any(not r.get("answer") for r in rows):
		return 3
	return 1 if wrong else 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
