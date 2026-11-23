extends SceneTree

# Fighting animals from the player's side (the coordinator for Dave, 23 Nov 2026: "the basics come first: movement, weights, fighting
# animals"). The real server_items and server_animals, wired as terrain_server wires them, and a player who fights as a person would. For
# every animal that defends itself, with bare hands and each weapon tier, a player at each link delay closes in, strikes in reach, waits out
# a warning, steps aside from a charge and strikes again in the opening after it. One table per kind: blows to bring it down, the time it
# took, the blows taken, the health left, and how many charges were dodged. A fight lost or a charge that could not be dodged is listed.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_fights.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const BigGame := preload("res://src/stream/server_big_game.gd")
const AnimalContact := preload("res://src/shared/animal_contact.gd")

const DIR := "user://test_animal_fights"
const DT := 0.05
const REACT_S := 0.25        # a person's reaction to a charge they see start
const RUN_MPS := 6.0         # the side step: a run with a weapon out
const WALK_MPS := 3.5        # closing in
const FIGHT_S := 120.0
const WEAPONS := ["", "stone_knife", "stone_axe", "wooden_spear", "wooden_club", "stone_mace", "spear", "bronze_sword", "bronze_spear", "iron_sword", "iron_spear", "steel_sword", "steel_spear"]

var failures: int = 0
var items
var animals
var clock: float = 0.0
var landed: Array = []       # [time, amount, result] of each blow on the player
var facing: float = 0.0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func n(id: String) -> int:
	return items.table.number_of(id)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.yaw_of = func(_p): return facing
	items.setup(ItemTableScript.load_default(), DIR)
	items.peer_connected_hello(1, "animalfights001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 1.0e6

	animals = AnimalsScript.new()
	animals.ground_height = func(_x, _z): return 10.0
	animals.blocked = func(_x, _z): return false
	animals.player_positions = func(): return items.peer_positions()
	animals.player_stances = func(): return [0]
	animals.setup()
	animals.traits = false

	for sp in animals.cfg["species"]:
		animals.cfg["species"][sp]["target_per_player"] = 0

	animals.rng.seed = 5
	animals.big_game.player_info = func(): return items.wolf_info()
	animals.big_game.hurt_player = func(peer, amount, lethal, cause, from):   # terrain_server.gd's: the big game's floor is 10
		var r: String = items.hurt_player(peer, amount, lethal, cause, 10.0, "", 0.0, from)
		landed.append([clock, amount, r])
		return r
	animals.big_game.ping_ms = func(_p): return ping_now
	items.hit_animal = func(_peer, origin, dir, reach, amount) -> Dictionary:   # terrain_server.gd's, without the tribe and the rewind
		var target: int = animals.target_along(origin, dir, reach)

		if target == 0:
			return {}

		var at: Vector3 = animals.animals[target]["pos"]
		animals.damage(target, amount, 1, "spear")
		return {"at": at}

	if OS.get_environment("FIGHT_ONE") != "":
		var parts: PackedStringArray = OS.get_environment("FIGHT_ONE").split(",")
		debug = true
		print(fight(parts[0], parts[1], int(parts[2]), int(parts[3]) if parts.size() > 3 else 0))
		quit(0)
		return

	var kinds: Array = []

	for sp in animals.cfg["species"]:
		if animals.species_def(sp).has("defend") and not sp in ["goblin", "bandit"]:   # goblins and bandits: test_enemy_fights
			kinds.append(sp)

	# 1. Can a charge be dodged? Each kind, with a spear, at 0 and 120 ms: a player who steps aside only when they see the charge itself, one who
	# reads the warning perfectly, and one who steps aside as soon as they see the warning start. Every attack must be dodgeable (Dave,
	# server_big_game.gd header): the warning is the cue, so the last of these must get clear of most charges at any ordinary link.
	print("\nDODGING (a spear; charges dodged of charges, and the fight's result)")
	print("  kind           | on the charge 0/120 ms | read perfectly 0/120 ms | when the warning shows 0/120 ms")

	for sp in kinds:
		var cells: Array = []
		var warned_charges: int = 0
		var warned_dodged: int = 0

		for read in [0, 1, 2]:
			for ping in [0, 120]:
				var r: Dictionary = fight(sp, "spear", ping, read)
				cells.append("%d/%d %s" % [int(r["dodged"]), int(r["charges"]), RESULT[str(r["result"])]])

				if read == 2:
					warned_charges += int(r["charges"])
					warned_dodged += int(r["dodged"])

		print("  %-14s | %-10s %-10s | %-10s %-10s | %-10s %-10s" % [sp, cells[0], cells[1], cells[2], cells[3], cells[4], cells[5]])

		if warned_charges > 0:
			check(float(warned_dodged) >= 0.6 * float(warned_charges), "a %s's charges can be dodged by stepping aside when its warning shows (%d of %d, at 0 and 120 ms)" % [sp, warned_dodged, warned_charges])

	print("  (W the player won, L the player went down to the floor, R it ran off, T two minutes up)")

	# 2. The fight with each weapon, at 60 ms, by a player who steps aside when the warning shows and strikes in the openings.
	var lost: Array = []

	for sp in kinds:
		var def: Dictionary = animals.species_def(sp)["defend"]
		print("\n%s: health %.0f, blow %.0f, warning %.1f s (provoked %.1f s), charge %.0f m/s, hit within %.1f m, recovers %.1f s" % [sp, float(animals.species_def(sp)["health"]), float(def["damage"]), float(def["warn_s"]), float(def.get("provoked_warn_s", 0.8)), float(def["charge_mps"]), float(def["hit_m"]), float(def["recover_s"])])
		print("  weapon         | blows  time   | charges dodged | blows taken  health | result")

		for weapon in WEAPONS:
			var r: Dictionary = fight(sp, weapon, 60, 2)
			print("  %-14s | %5d %5.0f s  | %7d %6d | %11d %7.0f | %s" % [weapon if weapon != "" else "bare hands", int(r["blows"]), float(r["time"]), int(r["charges"]), int(r["dodged"]), int(r["hits"]), float(r["health"]), str(r["result"])])

			if str(r["result"]) == "player down":
				lost.append("%s with %s" % [sp, weapon if weapon != "" else "bare hands"])

	print("\nfights lost at 60 ms by a player who steps aside when warned: %d" % lost.size())

	for l in lost:
		print("  " + l)

	items._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


const RESULT := {"killed": "W", "player down": "L", "it got away": "R", "time up": "T"}
var ping_now: int = 0
var debug: bool = false


# One fight: a level 1 animal of `sp` 8 m east, calm; the player at the origin with `weapon` in hand (none: bare hands), seeing the server
# `ping` ms round trip behind (plus the row clock's draw delay, animals.json dodge_view_ms) and stepping with a reaction of REACT_S.
# `read`: 0 the player steps aside when they see the charge; 1 they read the warning perfectly (their step reaches the server 0.15 s after the
# charge sets off); 2 they step aside as soon as they see the warning start (a person's reaction after it is drawn), and keep going 1.4 s.
func fight(sp: String, weapon: String, ping: int, read: int = 0) -> Dictionary:
	ping_now = ping
	animals.animals.clear()
	landed.clear()
	var v: Dictionary = items.vitals_of(1)
	v["health"] = 100.0
	v.erase("limp")
	var inv = items.inventory_of(1)

	for s in inv.slot_count:
		inv.clear_slot(s)

	var slot: int = -1

	if weapon != "":
		inv.add(n(weapon), 1)
		slot = inv.numbers.find(n(weapon))

	var body0: float = AnimalContact.body_m(sp)
	var id: int = animals.spawn(sp, body0 + melee_reach(weapon) - 0.4, 0.0)   # the fight starts with a blow from within reach (an ambush or a cornered animal)
	var a: Dictionary = animals.animals[id]
	a["level"] = 1
	a["hp"] = float(animals.species_def(sp)["health"])
	a["heading"] = PI
	a["cool"] = 0.0
	var def: Dictionary = animals.species_def(sp)["defend"]
	var me: Vector3 = Vector3(0.0, 10.0, 0.0)
	items.report_position(1, me)
	var seen_lag: float = (float(animals.cfg.get("dodge_view_ms", 350)) + float(ping) * 0.5) / 1000.0 + REACT_S   # from the server's charge to the player's step

	if read == 1:
		seen_lag = maxf(0.15 - float(ping) * 0.0005, 0.0)   # a player who reads the warning: their step reaches the server 0.15 s after the charge sets off
	var up_lag: float = float(ping) * 0.5 / 1000.0                                                               # the step's trip up to the server
	var history: Array = []    # [time, state, pos, dir] of the animal as the server had it
	var reports: Array = []    # [time it reaches the server, position]
	var dodge_until: float = -1.0
	var dodge_dir: Vector3 = Vector3.ZERO
	var charge_seen: bool = false
	var warn_seen: bool = false
	var charges: int = 0
	var dodged: int = 0
	var blows: int = 0
	var start: float = clock
	var reach: float = melee_reach(weapon)
	var last_state: int = -1
	var next_blow: float = 0.0
	var result: String = "time up"

	while clock - start < FIGHT_S:
		clock += DT

		if not animals.animals.has(id):
			result = "killed"
			break

		a = animals.animals[id]
		history.append([clock, int(a["state"]), a["pos"], float(a.get("dir", a["heading"]))])

		# The server's own count of charges (a charge that landed no blow is a dodge).
		var st: int = int(a["state"])

		if st == BigGame.CHARGE and last_state != BigGame.CHARGE:
			charges += 1

		last_state = st

		# What the player sees now: the animal as the server had it seen_lag ago (REACT_S of it is the person's own reaction).
		var view: Array = history[0]

		for h in history:
			if float(h[0]) <= clock - seen_lag:
				view = h

		var seen_state: int = int(view[1])
		var seen_pos: Vector3 = view[2]

		if seen_state == BigGame.CHARGE and not charge_seen:
			charge_seen = true
			var dir: Vector3 = Vector3(cos(float(view[3])), 0.0, sin(float(view[3])))
			dodge_dir = Vector3(-dir.z, 0.0, dir.x)   # square across its line, away from the side it is on
			dodge_dir *= -1.0 if dodge_dir.dot(me - seen_pos) < 0.0 else 1.0
			dodge_until = clock + 0.9

		if seen_state != BigGame.CHARGE:
			charge_seen = false

		if read == 2 and (seen_state == BigGame.WARN or seen_state == BigGame.WARN_POP) and not warn_seen:
			warn_seen = true
			var line: Vector3 = me - seen_pos
			line.y = 0.0
			dodge_dir = Vector3(-line.z, 0.0, line.x).normalized()
			dodge_until = clock + 1.4

		if seen_state != BigGame.WARN and seen_state != BigGame.WARN_POP:
			warn_seen = false

		var to: Vector3 = seen_pos - me
		to.y = 0.0
		var body: float = AnimalContact.body_m(sp)

		if clock < dodge_until:
			me += dodge_dir * RUN_MPS * DT
		elif seen_state == BigGame.WARN or seen_state == BigGame.WARN_POP:
			pass   # it is warning: the player holds, ready to step aside (a blow now would only bring the charge at once)
		elif to.length() - body > reach - 0.3:
			me += to.normalized() * minf(WALK_MPS * DT, to.length() - body - (reach - 0.4))
		elif seen_state != BigGame.CHARGE and clock >= next_blow:
			facing = atan2(-to.x, -to.z)
			next_blow = clock + recover_s(weapon)   # the weapon's own recovery, on the game clock (the server's guard is real time)
			items._last_strike.clear()
			var before: float = float(a["hp"])
			items._strike(1, inv, slot, to.normalized())

			if float(a.get("hp", before)) < before or not animals.animals.has(id):
				blows += 1

		if debug and (fmod(clock - start, 1.0) < DT or st == BigGame.CHARGE or seen_state == BigGame.WARN or clock < dodge_until):
			print("    t %.0f state %d seen %d d %.2f body %.2f reach %.2f hp %.1f me %s it %s" % [clock - start, st, seen_state, to.length(), body, reach, float(a["hp"]), str(me), str(a["pos"])])

		reports.append([clock + up_lag, me])

		while not reports.is_empty() and float(reports[0][0]) <= clock:
			items.report_position(1, reports.pop_front()[1])

		animals.tick(DT)

		if float(v["health"]) <= 10.0 + 0.01:
			result = "player down"
			break

		if animals.animals.has(id) and Vector2(animals.animals[id]["pos"].x - me.x, animals.animals[id]["pos"].z - me.z).length() > 60.0:
			result = "it got away"
			break

	dodged = charges - landed.size()   # every blow on the player is a charge's; a charge cut short by the kill landed nothing
	return {"blows": blows, "time": clock - start, "charges": charges, "dodged": dodged, "hits": landed.size(), "health": float(v["health"]), "result": result}


func melee_reach(weapon: String) -> float:
	if weapon == "":
		return float(items._melee_cfg.get("bare_hand", {}).get("reach_m", 1.8))

	return float(items.MeleeRules.blow(items.table.entry(weapon), items._melee_cfg)["reach_m"])


func recover_s(weapon: String) -> float:
	if weapon == "":
		return float(items._melee_cfg.get("bare_hand", {}).get("recover_ms", 600)) / 1000.0

	return float(items.table.entry(weapon).get("recover_ms", items.STRIKE_COOLDOWN_MS)) / 1000.0
