#!/usr/bin/env python3
"""Picture checker: sends in-game pictures to the Claude API and lists what looks wrong (floating or sunk animals and items,
a tool or weapon through a body, skin through clothes, feet off or in the ground, missing textures, broken meshes).
Dave, 26 Nov 2026: "ok make it" (his API credits, a one-off sweep; thread "Build an automatic picture checker").

Python standard library only, so it runs on Dave's PC with nothing installed (the Anthropic SDK is not there: raw HTTPS).
Godot is not involved: the pictures come from the lane's in-game tools (look_rig, body_pose_shot) on Dave's PC.

    python tools/picture_check.py C:/DynastyLane/logs/<job>/shots [more folders or .png files] [options]
      --about "text"      what every picture should show (also a file about.txt in a picture's folder, for that folder)
      --out DIR           where the report goes (default: the first folder): picture_check.md (the list) and picture_check.json
      --dry-run           count the pictures and the most they could cost; sends nothing, needs no key
      --max-pictures N    check at most N new pictures this run
      --time-limit S      stop starting new pictures after S seconds (default 3600)
      --cap USD           the spending cap, kept in the ledger (default 150; only lowered or raised by passing it)
      --recheck           ask again about pictures already checked (default: reuse the stored answer, no cost)

Spending: every request first reserves its worst case (all input as a cache write, all max_tokens as output) in the ledger;
the answer's real usage replaces the reservation. A request whose worst case would pass the cap is never sent. A run cut off
mid-request, or a request whose answer never came back, stays counted at its worst case, so the total can only read high.
One check runs at a time (a lock file in that folder). The ledger and the stored answers
live in C:/DynastyLane/picture_check (outside the clone; PICTURE_CHECK_HOME overrides).
Key: read only from C:/DynastyLane/picture_check_key.txt (PICTURE_CHECK_KEY_FILE overrides); never printed, logged or stored.
Stops between pictures when C:/DynastyLane/logs/queue/CANCEL exists (the lane's cancel file).
Exit: 0 every picture checked, 1 some pictures look wrong, 2 bad use or no key, 3 stopped early (cap, time, cancel, API errors).
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
import urllib.request

MODEL = "claude-opus-5-5"
# US dollars per million tokens (claude-opus-5-5, 26 Nov 2026): input, output, cache write (5 min), cache read.
PRICE = {"input": 4.00, "output": 20.00, "cache_write": 5.00, "cache_read": 0.20}
MAX_TOKENS = 4000
API_URL = os.environ.get("PICTURE_CHECK_API_URL", "https://api.anthropic.com/v1/messages")
WIN = os.name == "nt"
HOME = os.environ.get("PICTURE_CHECK_HOME", "C:/DynastyLane/picture_check" if WIN else os.path.expanduser("~/.picture_check"))
KEY_FILE = os.environ.get("PICTURE_CHECK_KEY_FILE", "C:/DynastyLane/picture_check_key.txt" if WIN else os.path.join(HOME, "key.txt"))
CANCEL = os.environ.get("PICTURE_CHECK_CANCEL", "C:/DynastyLane/logs/queue/CANCEL" if WIN else os.path.join(HOME, "CANCEL"))
MAX_IMAGE_BYTES = 5 * 1024 * 1024
PROMPT_VERSION = "1"

SYSTEM = """You check still pictures taken by an automatic tester inside a 3D game in development: Dynasty, a realistic \
medieval survival game made in Godot. Each picture shows one test subject (an animal, the player's body, a held tool, worn \
clothing, a building piece, a plant, an item on the ground). Your job is to find visible rendering and placement bugs, the \
kind a player would notice and report. You are not judging the art style, the art quality, the model detail or whether \
something looks AI-made: never report those.

Report these kinds of bug:
- floating: an animal, body, item or building piece hovers above the ground or a surface it should rest on (look for a gap \
or a missing contact shadow under feet, hooves, paws or the item).
- sunk: it sits too low: feet, hooves or the lower body inside the ground, an item buried, a wall or floor half inside the terrain.
- clipping: one thing passes through another: a tool or weapon through the body or a limb, a hand through a held item, \
an animal's body through a tree or rock, two building pieces inside each other.
- skin_through_clothes: bare skin or the body mesh shows through worn clothing or armour where the clothing should cover it.
- held_wrong: a held item is not in the hand (floating beside it, at the wrong place, pointing the wrong way for how it is held).
- pose_wrong: a broken pose: limbs bent the wrong way, twisted joints, legs crossed through each other, feet placed \
impossibly for a standing, walking or running body, an animal in a pose no real animal makes.
- missing_texture: magenta or pink surfaces, a checkerboard, flat white or black surfaces where a texture belongs, \
white specks or holes in a surface.
- broken_mesh: stretched spikes, torn or exploded polygons, faces missing so the inside shows, a model with parts missing.
- wrong_scale: something clearly the wrong size against the things around it (a rabbit as big as a deer, a mug as big as a chest).
- lighting: a subject drawn fully black or burnt white when the scene around it is lit normally, or harsh flicker bands.
- other: any other plain rendering or placement bug a player would report.

Expected things that are not bugs: text in the corners and coloured name tags over items are the tester's own labels; \
grid lines on a flat test floor; a plain sky, an empty test floor or no world behind a subject; night or rain darkness \
when the description says night or rain; grass partly covering feet or small items (say so only if the subject itself is \
plainly wrong); motion poses that are normal mid-stride; the game's realistic, muted colours.

Be specific and honest. Report only what you can actually see in this picture; if a part is too small, dark or hidden \
to judge, say unsure rather than guess. Say where in the picture the bug is (for example "left hind hoof, lower middle"). \
Use severity high for a bug a player would notice at once, medium for one seen on a closer look, low for a small one. \
Use confidence to say how sure you are that it is a real bug and not the lighting, the angle or the picture's size. \
If nothing is wrong, the verdict is ok with no problems. Keep every text field short: one sentence."""

KINDS = ["floating", "sunk", "clipping", "skin_through_clothes", "held_wrong", "pose_wrong", "missing_texture",
	"broken_mesh", "wrong_scale", "lighting", "other"]
LEVELS = ["low", "medium", "high"]
SCHEMA = {
	"type": "object",
	"additionalProperties": False,
	"required": ["shows", "verdict", "problems"],
	"properties": {
		"shows": {"type": "string", "description": "what the picture shows, one sentence"},
		"verdict": {"type": "string", "enum": ["ok", "problem", "unsure"]},
		"problems": {"type": "array", "items": {
			"type": "object",
			"additionalProperties": False,
			"required": ["kind", "where", "what", "severity", "confidence"],
			"properties": {
				"kind": {"type": "string", "enum": KINDS},
				"where": {"type": "string"},
				"what": {"type": "string"},
				"severity": {"type": "string", "enum": LEVELS},
				"confidence": {"type": "string", "enum": LEVELS},
			},
		}},
	},
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


def worst_case(width, height):
	tokens = image_tokens(width, height) + len(SYSTEM) // 3 + 400
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


def ask(key, data, label, about):
	"""One picture to the API. Returns (answer dict or None, usage dict, error text, attempts that may have been billed unseen)."""
	text = "Picture: %s\n" % label
	if about:
		text += "It should show: %s\n" % about
	text += "List every visible bug of the kinds above in this picture."
	body = {
		"model": MODEL,
		"max_tokens": MAX_TOKENS,
		"system": [{"type": "text", "text": SYSTEM, "cache_control": {"type": "ephemeral"}}],
		"output_config": {"effort": "low", "format": {"type": "json_schema", "schema": SCHEMA}},
		"messages": [{"role": "user", "content": [
			{"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": base64.b64encode(data).decode("ascii")}},
			{"type": "text", "text": text},
		]}],
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
			return None, usage, "the API declined this picture", unseen
		if reply.get("stop_reason") == "max_tokens":
			return None, usage, "answer cut off (max_tokens)", unseen
		out = "".join(b.get("text", "") for b in reply.get("content", []) if b.get("type") == "text")
		try:
			return json.loads(out), usage, "", unseen
		except ValueError:
			return None, usage, "answer was not JSON", unseen
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
	os.makedirs(out_dir, exist_ok=True)
	with open(os.path.join(out_dir, "picture_check.json"), "w", encoding="utf-8") as f:
		json.dump({"model": MODEL, "rows": rows, "spent_usd": round(ledger.total(), 4), "cap_usd": ledger.data["cap_usd"],
			"stopped": stopped}, f, indent=1)
	rank = {"high": 0, "medium": 1, "low": 2}
	found = [(r, p) for r in rows for p in (r.get("answer") or {}).get("problems", [])]
	found.sort(key=lambda rp: (rank.get(rp[1]["severity"], 3), rank.get(rp[1]["confidence"], 3), rp[0]["picture"]))
	lines = ["# Picture check", "",
		"%d pictures, %d look wrong, %d unsure, %d not checked. Spent so far $%.2f of the $%.2f cap. Model %s."
		% (len(rows), sum(1 for r in rows if (r.get("answer") or {}).get("verdict") == "problem"),
		sum(1 for r in rows if (r.get("answer") or {}).get("verdict") == "unsure"),
		sum(1 for r in rows if not r.get("answer")), ledger.total(), ledger.data["cap_usd"], MODEL)]
	if stopped:
		lines += ["", "Stopped early: " + stopped]
	lines += ["", "## What looks wrong (most serious first)", ""]
	if not found:
		lines.append("Nothing.")
	for r, p in found:
		lines.append("- **%s** (%s, sure: %s) `%s`: %s. Where: %s." % (p["kind"], p["severity"], p["confidence"], r["picture"],
			p["what"].rstrip("."), p["where"].rstrip(".")))
	unsure = [r for r in rows if (r.get("answer") or {}).get("verdict") == "unsure"]
	if unsure:
		lines += ["", "## Unsure (look by hand)", ""] + ["- `%s`: %s" % (r["picture"], r["answer"].get("shows", "")) for r in unsure]
	missed = [r for r in rows if not r.get("answer")]
	if missed:
		lines += ["", "## Not checked", ""] + ["- `%s`: %s" % (r["picture"], r.get("error", "")) for r in missed]
	with open(os.path.join(out_dir, "picture_check.md"), "w", encoding="utf-8") as f:
		f.write("\n".join(lines) + "\n")


def main(argv):
	ap = argparse.ArgumentParser(description="Send in-game pictures to the Claude API and list what looks wrong.")
	ap.add_argument("paths", nargs="+")
	ap.add_argument("--about", default="")
	ap.add_argument("--out", default="")
	ap.add_argument("--dry-run", action="store_true")
	ap.add_argument("--max-pictures", type=int, default=0)
	ap.add_argument("--time-limit", type=float, default=3600.0)
	ap.add_argument("--cap", type=float, default=None)
	ap.add_argument("--recheck", action="store_true")
	args = ap.parse_args(argv)
	if args.cap is not None and not (math.isfinite(args.cap) and args.cap >= 0):
		print("picture check: --cap must be a dollar amount")
		return 2
	if not (API_URL.startswith("https://") or API_URL.startswith("http://127.0.0.1:")):
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

	plan = []
	for path in pictures:
		with open(path, "rb") as f:
			data = f.read()
		size = png_size(data)
		digest = hashlib.sha256(data + about_for(path, args.about).encode("utf-8")).hexdigest() + ":" + PROMPT_VERSION
		plan.append((path, data, size, digest))
	new = [p for p in plan if args.recheck or p[3] not in answers]
	sendable = [p for p in new if p[2] and len(p[1]) <= MAX_IMAGE_BYTES]
	most = sum(worst_case(*p[2]) for p in sendable[:args.max_pictures or None])
	print("picture check: %d pictures, %d already checked, %d to send, at most $%.2f (worst case)"
		% (len(plan), len(plan) - len(new), min(len(sendable), args.max_pictures or len(sendable)), most))
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
		return run(args, plan, key, answers, answers_path, out_dir, started)
	finally:
		os.remove(lock)


def run(args, plan, key, answers, answers_path, out_dir, started):
	ledger = Ledger(os.path.join(HOME, "spent.json"), args.cap)
	print("picture check: spent so far $%.2f of the $%.2f cap" % (ledger.total(), ledger.data["cap_usd"]))
	if any(args.recheck or p[3] not in answers for p in plan) and not key:
		print("picture check: no API key in %s (the one-time command is in docs/PICTURE_CHECK.md)" % KEY_FILE)
		return 2

	rows, stopped, sent, errors_in_row = [], "", 0, 0
	for path, data, size, digest in plan:
		label = os.path.basename(path)
		row = {"picture": path.replace("\\", "/")}
		about = about_for(path, args.about)
		if about:
			row["about"] = about
		if not args.recheck and digest in answers:
			row["answer"] = answers[digest]
			rows.append(row)
			continue
		if stopped:
			row["error"] = "not sent: " + stopped
		elif not size:
			row["error"] = "not a PNG"
		elif len(data) > MAX_IMAGE_BYTES:
			row["error"] = "larger than 5 MB, the API's limit"
		else:
			reason = ""
			worst = worst_case(*size)
			if os.path.exists(CANCEL):
				reason = "the lane's CANCEL file is there"
			elif time.time() - started > args.time_limit:
				reason = "time limit %d s" % args.time_limit
			elif args.max_pictures and sent >= args.max_pictures:
				reason = "--max-pictures %d reached" % args.max_pictures
			elif worst > ledger.left():
				reason = "the cap: $%.2f spent of $%.2f, the next picture could cost $%.2f" % (ledger.total(), ledger.data["cap_usd"], worst)
			if reason:
				stopped = reason
				row["error"] = "not sent: " + reason
			else:
				ledger.reserve(worst)
				answer, usage, error, unseen = ask(key, data, label, about)
				usd = cost_of(usage) + unseen * worst
				ledger.settle(worst, usd, bool(usage))
				sent += 1
				row["usd"] = round(usd, 4)
				if answer is not None:
					row["answer"] = answer
					answers[digest] = answer
					ledger.data["pictures"] += 1
					ledger.save()
					tmp = answers_path + ".tmp"
					with open(tmp, "w", encoding="utf-8") as f:
						json.dump(answers, f)
					os.replace(tmp, answers_path)
					errors_in_row = 0
				else:
					row["error"] = error
					errors_in_row += 1
					if errors_in_row >= 5:
						stopped = "5 API errors in a row (last: %s)" % error
				verdict = (answer or {}).get("verdict", "not checked")
				print("picture check: %s %s ($%.3f, total $%.2f)" % (label, verdict if answer else "not checked: " + error, usd, ledger.total()))
		rows.append(row)

	write_report(out_dir, rows, ledger, stopped)
	wrong = sum(1 for r in rows if (r.get("answer") or {}).get("verdict") == "problem")
	print("picture check: %d of %d look wrong; report %s; spent $%.2f of the $%.2f cap%s"
		% (wrong, len(rows), os.path.join(out_dir, "picture_check.md"), ledger.total(), ledger.data["cap_usd"],
		"; stopped: " + stopped if stopped else ""))
	if stopped or any(not r.get("answer") for r in rows):
		return 3
	return 1 if wrong else 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
