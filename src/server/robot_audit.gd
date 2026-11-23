extends Node

# The server half of the robot play-testers (--robot-audit; tools/robots.sh, tools/robot_check.py; 23 Nov 2026).
# Build 9257's first hour on Dave's server found faults no one-machine test had: animals teleporting and passing through players,
# the pack not updating after a queued craft. With this flag the server prints what it believes, so tools/robot_check.py can hold each
# robot client's view against it:
#   AUDIT pack <peer> <unix ms> <signature> <slots used>   the pack's signature each time it changes (looked at every 0.25 s)
#   AUDIT sent <peer> <unix ms> full|slots                   each pack message sent
#   AUDIT reject <peer> <unix ms> <reason>                   each refusal sent (reject())
#   AUDIT jump <animal id> <species> <unix ms> <metres> <seconds> <from> <to>   an animal that moved farther in one step than its top speed allows
#   AUDIT inside <animal id> <species> <peer> <unix ms> <metres>   an animal's middle inside a player's capsule (closer than INSIDE_M, level with them)
# Nothing changes in the game itself: no protocol change, and with the flag off this node is never made.

const SIG_EVERY_S := 0.25
const ANIMAL_EVERY_S := 0.1
const INSIDE_M := 0.35          # a player capsule's radius is about 0.35 m; an animal's middle this close stands inside it
const JUMP_SLACK := 1.6         # an animal step may run this much over its top speed (a lunge, a server hitch) before it counts as a jump
const JUMP_FLOOR_M := 2.5       # steps shorter than this never count (a turn, a settle onto the ground)

var items          # server_items.gd
var animals        # server_animals.gd

var _sig: Dictionary = {}        # peer -> last printed signature
var _sig_t: float = 0.0
var _animal_t: float = 0.0
var _last: Dictionary = {}       # animal id -> [pos, unix ms]
var _top_mps: Dictionary = {}    # species number -> fastest _mps in animals.json
var _names: Dictionary = {}      # species number -> name


static func signature(inv) -> String:
	if inv == null:
		return "none"

	var parts: PackedStringArray = PackedStringArray()

	for s in range(inv.numbers.size()):
		if int(inv.numbers[s]) != 0:
			parts.append("%d:%d:%d:%d" % [s, int(inv.numbers[s]), int(inv.counts[s]), int(inv.wear[s]) if s < inv.wear.size() else 0])

	return "%08x" % (",".join(parts).hash() & 0xffffffff)


static func used(inv) -> int:
	var n: int = 0

	if inv != null:
		for s in range(inv.numbers.size()):
			n += 1 if int(inv.numbers[s]) != 0 else 0

	return n


# A species row's fastest speed: every *_mps value in it and in its blocks one level down (a flight block's fly_mps).
static func top_speed(row: Dictionary) -> float:
	var top: float = 0.0

	for k in row:
		if str(k).ends_with("_mps") and (row[k] is float or row[k] is int):
			top = maxf(top, float(row[k]))
		elif row[k] is Dictionary:
			top = maxf(top, top_speed(row[k]))

	return top


# A young animal comes as its species number + 100 (server_animals.gd YOUNG_NUM).
static func species_of(num: int) -> int:
	return num - 100 if num >= 100 else num


static func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func setup(server_items, server_animals) -> void:
	items = server_items
	animals = server_animals
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))

	if cfg is Dictionary:
		for sp in cfg.get("species", {}):
			var row: Dictionary = cfg["species"][sp]
			var top: float = top_speed(row)

			_top_mps[int(row.get("number", 0))] = top
			_names[int(row.get("number", 0))] = str(sp)

	var full: Callable = items.send_full
	var slots: Callable = items.send_slots
	var reject: Callable = items.send_reject
	items.send_full = func(peer, bytes):
		full.call(peer, bytes)
		print("AUDIT sent %d %d full" % [int(peer), now_ms()])
	items.send_slots = func(peer, bytes):
		slots.call(peer, bytes)
		print("AUDIT sent %d %d slots" % [int(peer), now_ms()])
	items.send_reject = func(peer, reason):
		reject.call(peer, reason)
		print("AUDIT reject %d %d %d" % [int(peer), now_ms(), int(reason)])
	print("AUDIT on: robot audit lines follow (src/server/robot_audit.gd)")


func _process(delta: float) -> void:
	if items == null:
		return

	_sig_t += delta

	if _sig_t >= SIG_EVERY_S:
		_sig_t = 0.0

		for peer in items.peer_ids():
			var inv = items.inventory_of(int(peer))
			var sig: String = signature(inv)

			if _sig.get(peer, "") != sig:
				_sig[peer] = sig
				print("AUDIT pack %d %d %s %d" % [int(peer), now_ms(), sig, used(inv)])

	_animal_t += delta

	if animals == null or _animal_t < ANIMAL_EVERY_S:
		return

	_animal_t = 0.0
	var now: int = now_ms()
	var players: Array = []

	for peer in items.peer_ids():
		var at: Variant = items.position_of(int(peer))

		if at != null:
			players.append([int(peer), at])

	var seen: Dictionary = {}

	for id in animals.animals:
		var a: Dictionary = animals.animals[id]
		var pos: Vector3 = a["pos"]
		var num: int = species_of(int(a.get("num", 0)))
		seen[id] = true

		# Only the animals near a player matter (the far ones are moved in big coarse steps by design).
		var near: bool = false

		for p in players:
			var d: float = Vector2(pos.x - p[1].x, pos.z - p[1].z).length()

			if d < 150.0:
				near = true

			if d < INSIDE_M and absf(pos.y - p[1].y) < 1.6 and int(a.get("state", 0)) != animals.HIDDEN:
				print("AUDIT inside %d %s %d %d %.2f" % [int(id), str(_names.get(num, num)), int(p[0]), now, d])

		# Measured from its last change of place, not from the last look: an animal farther off, or one the tick budget skipped, steps
		# less often and further each time (server_animals.gd hz_near, hz_mid, tick_budget_ms).
		if not _last.has(id):
			_last[id] = [pos, now]
		elif pos != _last[id][0]:
			var was: Array = _last[id]
			var dt: float = maxf(float(now - int(was[1])) / 1000.0, ANIMAL_EVERY_S)
			var step: float = Vector2(pos.x - was[0].x, pos.z - was[0].z).length()
			var allowed: float = float(_top_mps.get(num, 15.0)) * dt * JUMP_SLACK

			if near and step > maxf(allowed, JUMP_FLOOR_M) and int(a.get("state", 0)) != animals.HIDDEN:
				print("AUDIT jump %d %s %d %.1f %.2f %s %s state %d" % [int(id), str(_names.get(num, num)), now, step, dt, str(was[0].round()), str(pos.round()), int(a.get("state", 0))])

			_last[id] = [pos, now]

	for id in _last.keys():
		if not seen.has(id):
			_last.erase(id)
