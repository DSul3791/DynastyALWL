extends SceneTree

# Fighting animals from the player's side (the coordinator for Dave, 23 Nov 2026: "the basics come first: movement, weights, fighting
# animals"; Dave: fights must not be "almost impossible to hit"). The real server_items and server_animals, wired as terrain_server wires
# them, and a player who fights as a person would: the fight starts with a blow from within reach, the player strikes in reach, holds while
# the animal warns, steps aside and strikes again in the opening after its charge. The player sees the server dodge_view_ms plus half the
# link's round trip late and reacts REACT_S after that; their steps reach the server half a round trip later.
#   1. every animal that defends itself, with a spear at 0 and 120 ms: charges dodged by a player who steps aside only when they see the
#      charge, by one who reads the warning perfectly, and by one who steps aside as soon as the warning shows; the last must clear most
#      (every attack dodgeable: server_big_game.gd header; the warning is the cue);
#   2. a table per kind of each weapon tier and bare hands at 60 ms: blows, time, charges dodged, blows taken, health left, result;
#   3. one spear blow, then the animal runs off bleeding: it dies of it, and its blood leads a walking hunter to the body;
#   4. a hunter's chase of a sprinter over 120 ms lands its blow; 5. a wolf pack on a half-health player: one blow sends it off;
#   6. a player crippled at the floor is let go as they limp off; 7. two players on one animal: the one who hurt it last is hit.
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
	items.hit_animal = func(peer, origin, dir, reach, amount) -> Dictionary:   # terrain_server.gd's, without the tribe and the rewind
		var target: int = animals.target_along(origin, dir, reach)

		if target == 0:
			return {}

		var at: Vector3 = animals.animals[target]["pos"]
		animals.damage(target, amount, peer, "spear")
		return {"at": at}

	if OS.get_environment("FIGHT_ONE") != "":
		var parts: PackedStringArray = OS.get_environment("FIGHT_ONE").split(",")
		debug = true
		print(fight(parts[0], parts[1], int(parts[2]), int(parts[3]) if parts.size() > 3 else 0))
		quit(0)
		return

	animals.wolves.player_info = func(): return items.wolf_info()
	animals.wolves.notice = func(_p, _t): pass
	animals.wolves.hurt_player = func(peer, amount, lethal, cause, from):   # terrain_server.gd's: a wolf's floor is maim_hp
		var r: String = items.hurt_player(peer, amount, lethal, cause, float(animals.cfg.get("wolves", {}).get("maim_hp", 25.0)), "", 0.0, from)
		landed.append([clock, amount, r])
		return r
	animals.cfg["wolves"]["cell_share"] = 0.0   # no wild packs: the test makes its own

	if OS.get_environment("TWO_ONLY") != "":
		two_players()
		quit(0)
		return

	if OS.get_environment("FLOOR_ONLY") != "":
		at_the_floor()
		quit(0)
		return

	if OS.get_environment("WOLF_ONLY") != "":
		wolf_fights()
		quit(0)
		return

	if OS.get_environment("BLEED_ONLY") != "":
		bleeding()
		quit(0)
		return

	var kinds: Array = []

	for sp in animals.cfg["species"]:
		if animals.species_def(sp).has("defend") and not sp in ["goblin", "bandit"]:   # goblins and bandits: test_enemy_fights
			kinds.append(sp)

	# 0. Every animal that defends itself has the fair dodge and a charge that runs before its blow lands (a kind added later without them would
	# hit before any screen drew the lunge, and a step aside the player saw in time would not count).
	for sp in kinds:
		var d: Dictionary = animals.species_def(sp)["defend"]
		check(bool(d.get("fair_dodge", false)) and float(d.get("strike_min_s", animals.cfg.get("strike_min_s", 0.0))) >= 0.3, "a %s's charge has the fair dodge and strike_min_s" % sp)

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

		var still: Dictionary = fight(sp, "spear", 0, 3)   # a player who stands in its face and never steps aside is hit: the charges are real
		print("    stands still: %d hits of %d charges" % [int(still["hits"]), int(still["charges"])])

		if float(animals.species_def(sp)["defend"].get("bluff_share", 0.0)) == 0.0 and int(still["charges"]) > 0:   # a bluffer's one charge may stop short
			check(int(still["hits"]) > 0, "a %s's charge hits a player who stands still (%d hits of %d charges)" % [sp, int(still["hits"]), int(still["charges"])])

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

	chases(kinds)
	wolf_fights()
	at_the_floor()
	bleeding()
	two_players()

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

		if st in [BigGame.CHARGE, BigGame.STRIKE, BigGame.KICK] and last_state != st:   # a close strike or kick is an attack too (its blows are in landed)
			charges += 1

		last_state = st

		# What the player sees now: the animal as the server had it seen_lag ago (REACT_S of it is the person's own reaction).
		var view: Array = history[0]

		for h in history:
			if float(h[0]) <= clock - seen_lag:
				view = h

		var seen_state: int = int(view[1])
		var seen_pos: Vector3 = view[2]

		if seen_state == BigGame.CHARGE and not charge_seen and read != 3:   # read 3: the player never steps aside
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
		elif seen_state != BigGame.CHARGE and clock >= next_blow and read != 3:   # read 3 neither steps aside nor strikes
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


# 4. A hunter's chase of a runner (ANIMAL_BEHAVIOUR.md HB-2: running from a predator makes it worse): its blow is not judged late, so a sprinter
# over a 120 ms link it has caught is still hit (gate review of #1824: with the fair dodge on the chase, a sprinter beat every chase).
func chases(kinds: Array) -> void:
	print("\nCHASES (a player sprinting away at 9 m/s over a 120 ms link, the hunter charging from 4 m behind)")
	ping_now = 120

	for sp in kinds:
		if not animals.species_def(sp).has("hunter"):
			continue

		animals.animals.clear()
		landed.clear()
		var v: Dictionary = items.vitals_of(1)
		v["health"] = 100.0
		v.erase("limp")
		var me: Vector3 = Vector3(4.0 + AnimalContact.body_m(sp), 10.0, 0.0)
		items.report_position(1, me)
		var id: int = animals.spawn(sp, 0.0, 0.0)
		var a: Dictionary = animals.animals[id]
		a["level"] = 1
		a["cool"] = 0.0
		a["heading"] = 0.0
		var started: bool = animals.big_game.chase(a, me, float(animals.species_def(sp)["hunter"].get("run_m", 30.0)))
		var reports: Array = []

		for k in int(4.0 / DT):
			clock += DT
			me.x += 9.0 * DT
			reports.append([clock + 0.06, me])

			while not reports.is_empty() and float(reports[0][0]) <= clock:
				items.report_position(1, reports.pop_front()[1])

			animals.tick(DT)

			if not landed.is_empty():
				break

		print("  %-14s %s" % [sp, ("hit for %.0f" % float(landed[0][1])) if not landed.is_empty() else "never hit"])
		check(started and not landed.is_empty(), "a %s that chases a sprinter and catches them lands its blow at 120 ms" % sp)

	ping_now = 0


# 3. One spear blow and the animal runs off bleeding (Dave 23 Nov 2026: "I love the idea the animal is bleeding and if they bleed enough they die
# eventually"; "I like the blood trails"). Does it die, how far off, and could a hunter follow its trail to the body: the drops are every_m
# apart, at most max_drops an animal and gone after life_s, so the trail must still be there, end to end, by the time a walker gets along it.
func bleeding() -> void:
	var bcfg: Dictionary = animals.cfg.get("blood", {})
	print("\nBLEEDING (one spear blow, %.0f damage; bleeding its hit again over %.0f s, a drop every %.0f m, at most %d, each lasting %.0f s)" % [8.0, float(bcfg.get("bleed_s", 60.0)), float(bcfg.get("every_m", 3.0)), int(bcfg.get("max_drops", 40)), float(bcfg.get("life_s", 240.0))])
	print("  kind           health | dies after  away  | drops  trail ends short of the body | followable")
	var deaths: Array = []
	animals.died = func(sp, pos, _peer): deaths.append([sp, pos, clock])

	for sp in ["rabbit", "deer", "fox", "boar", "elk", "moose", "bear", "buffalo", "lion", "rhino", "elephant"]:
		animals.animals.clear()
		animals.blood.clear()
		deaths.clear()
		items.report_position(1, Vector3(0.0, 10.0, 0.0))
		var id: int = animals.spawn(sp, AnimalContact.body_m(sp) + 2.0, 0.0)
		var a: Dictionary = animals.animals[id]
		a["level"] = 1
		a["hp"] = float(animals.species_def(sp)["health"])
		a["cool"] = 0.0
		var start: float = clock
		animals.damage(id, 8.0, 1, "spear")
		var drops: Array = []   # [game time it fell, where]
		var seen: int = 0
		items.report_position(1, Vector3(-25.0, 10.0, 0.0))   # the hunter hangs back out of its reach: it runs and bleeds, not fights

		while deaths.is_empty() and clock - start < 3600.0:
			clock += 0.1
			animals.tick(0.1)

			while animals.blood.size() > seen:
				drops.append([clock, animals.blood[seen][0]])
				seen += 1

		var died: bool = not deaths.is_empty()
		var end_at: Vector3 = deaths[0][1] if died else (animals.animals[id]["pos"] if animals.animals.has(id) else Vector3.ZERO)
		var took: float = (float(deaths[0][2]) if died else clock) - start
		var away: float = Vector2(end_at.x, end_at.z).length()
		var short: float = Vector2(end_at.x - drops.back()[1].x, end_at.z - drops.back()[1].z).length() if not drops.is_empty() else away
		# A hunter who sets off along the trail as soon as it runs, at a walk: each drop must still be there when they reach it.
		var walked: float = 0.0
		var from: Vector3 = Vector3.ZERO
		var follow: bool = not drops.is_empty() and short <= 10.0

		for d in drops:
			walked += Vector2(d[1].x - from.x, d[1].z - from.z).length()
			from = d[1]

			if walked / WALK_MPS > float(d[0]) - start + float(bcfg.get("life_s", 240.0)):
				follow = false

		# What a player is actually sent (blood_near: within send_radius_m, the nearest max_sent): standing on any drop, the next one along is in it,
		# and standing at the body, the trail's end is. (Drops age on the real clock, and this whole run takes seconds, so none dry here.)
		for k in range(0, drops.size() - 1, 5):
			if not animals.blood_near(drops[k][1]).has(drops[k + 1][1]):
				follow = false

		if not drops.is_empty() and not animals.blood_near(end_at).has(drops.back()[1]):
			follow = false

		print("  %-14s %6.0f | %s %5.0f m | %5d %8.0f m | %s" % [sp, float(animals.species_def(sp)["health"]), ("%6.0f s" % took) if died else " lives", away, drops.size(), short, "yes" if follow and died else "no"])
		check(died and (away < 10.0 or follow), "a %s wounded by one blow bleeds to death, and its blood leads to the body" % sp)

	animals.died = Callable()


# 5. A wolf pack's rush on a hurt lone player (wolves have no defend row: server_wolves.gd's battle ring). One wolf at a time winds up
# (windup_s, the crouch), lunges in for one bite and stands in reach recover_s (the opening); one blow that lands sends the whole pack off
# (on_hit: the pack is hurt). A player at half health who faces them and strikes whatever is in reach, over a 60 ms link: how many bites
# before the first blow lands, and does the pack go.
func wolf_fights() -> void:
	print("\nWOLVES (a pack rushes a player at half health; the player faces it and strikes what is in reach, 60 ms)")
	print("  weapon         | bites taken  health  | first blow landed  | the pack")
	var ping: int = 60
	ping_now = ping

	for weapon in ["", "stone_knife", "stone_axe", "bronze_sword", "iron_sword"]:
		animals.animals.clear()
		animals.wolves.packs.clear()
		landed.clear()
		var v: Dictionary = items.vitals_of(1)
		v["health"] = 50.0
		v.erase("limp")
		var inv = items.inventory_of(1)

		for s in inv.slot_count:
			inv.clear_slot(s)

		var slot: int = -1

		if weapon != "":
			inv.add(n(weapon), 1)
			slot = inv.numbers.find(n(weapon))

		var me: Vector3 = Vector3(0.0, 10.0, 0.0)
		items.report_position(1, me)
		var pid: int = animals.wolves.spawn_pack(40.0, 0.0)
		animals.wolves.packs[pid]["den"] = Vector3(5000.0, 0.0, 0.0)   # far from its den: no extra boldness
		var seen_lag: float = (float(animals.cfg.get("dodge_view_ms", 350)) + float(ping) * 0.5) / 1000.0 + REACT_S
		var history: Array = []   # [time, {id: pos}]
		var start: float = clock
		var first_blow: float = -1.0
		var bites_before: int = 0
		var rushed: bool = false
		var next_blow: float = 0.0
		var reach: float = melee_reach(weapon)
		var gone: String = "still on the player"

		while clock - start < 120.0:
			clock += DT
			var now: Dictionary = {}

			for id in animals.animals:
				if str(animals.animals[id]["sp"]) == "wolf":
					now[id] = animals.animals[id]["pos"]

			history.append([clock, now])
			var view: Dictionary = history[0][1]

			for h in history:
				if float(h[0]) <= clock - seen_lag:
					view = h[1]

			var phase: String = str(animals.wolves.packs[pid]["phase"]) if animals.wolves.packs.has(pid) else "gone"
			rushed = rushed or phase == "rush"

			if rushed and phase != "rush":
				gone = "left (%s) after %.0f s" % [phase, clock - start]
				break

			# Strike the nearest wolf the player sees within reach.
			var best: int = 0
			var best_d: float = INF

			for id in view:
				var d: float = Vector2(view[id].x - me.x, view[id].z - me.z).length() - AnimalContact.body_m("wolf")

				if d < best_d and animals.animals.has(id):
					best_d = d
					best = int(id)

			if best != 0 and best_d <= reach - 0.1 and clock >= next_blow:
				var to: Vector3 = view[best] - me
				to.y = 0.0
				facing = atan2(-to.x, -to.z)
				next_blow = clock + recover_s(weapon)
				items._last_strike.clear()
				var before: float = float(animals.animals[best]["hp"])
				items._strike(1, inv, slot, to.normalized())

				if first_blow < 0.0 and (not animals.animals.has(best) or float(animals.animals[best]["hp"]) < before):
					first_blow = clock - start
					bites_before = landed.size()

			animals.tick(DT)

		print("  %-14s | %5d  %10.0f  | %s | %s" % [weapon if weapon != "" else "bare hands", landed.size(), float(v["health"]), ("after %d bites, %.0f s" % [bites_before, first_blow]) if first_blow >= 0.0 else "never", gone])
		check(rushed or first_blow >= 0.0, "a pack rushes a lone player at half health, or is struck first while it stalks (%s)" % weapon)
		check(first_blow >= 0.0 and bites_before <= 3, "a player facing the pack with %s lands a blow within three bites" % (weapon if weapon != "" else "bare hands"))

	ping_now = 0
	animals.wolves.packs.clear()   # no pack left over for the sections after


# 6. At the floor (the big game's 10): a player an animal has crippled limps off (vitals limp: half speed). Does the animal let them go, or
# charge them again and again while they cannot get away?
func at_the_floor() -> void:
	print("\nAT THE FLOOR (a player at 11 health in a provoked animal's face, limping away at the speed given, 60 s)")
	print("  kind           | walking away 1.6 m/s    | running away 4.5 m/s")

	for sp in ["boar", "moose", "bear", "buffalo", "lion", "rhino", "elephant", "warthog", "hyena"]:
		var cells: Array = []

		for mps in [1.6, 4.5]:
			animals.animals.clear()
			landed.clear()
			var v: Dictionary = items.vitals_of(1)
			v["health"] = 11.0
			v.erase("limp")
			var me: Vector3 = Vector3(0.0, 10.0, 0.0)
			items.report_position(1, me)
			var id: int = animals.spawn(sp, AnimalContact.body_m(sp) + 2.5, 0.0)
			var a: Dictionary = animals.animals[id]
			a["level"] = 1
			a["cool"] = 0.0
			a["heading"] = PI
			animals.big_game.provoke(a, me, 1.0)
			var first: float = -1.0
			var start: float = clock

			while clock - start < 60.0:
				clock += DT

				if not landed.is_empty():
					if first < 0.0:
						first = clock
					me.x -= mps * DT
					items.report_position(1, me)

				animals.tick(DT)

			var after: int = maxi(landed.size() - 1, 0)
			check((landed.is_empty() and float(animals.species_def(sp)["defend"].get("bluff_share", 0.0)) > 0.0) or (not landed.is_empty() and after == 0), "a %s lets a player it crippled limp off at %.1f m/s (%d more blows)" % [sp, mps, after])
			cells.append("%d more blows, %.0f m off" % [after, Vector2(animals.animals[id]["pos"].x - me.x, animals.animals[id]["pos"].z - me.z).length() if animals.animals.has(id) else -1.0])

		print("  %-14s | %-23s | %s" % [sp, cells[0], cells[1]])


# 7. Two players on one animal, spears, from opposite sides, each striking it whenever it is in their reach (no lag): who does it hurt,
# and how long does it take.
func two_players() -> void:
	print("\nTWO PLAYERS (spears, from opposite sides, 0 ms)")
	print("  kind           | result          | blows on A  B | A's and B's health")
	items.peer_connected_hello(2, "animalfights002")
	items.vitals_of(2)["weight"] = 1.0e6

	for sp in ["boar", "moose", "bear", "buffalo", "lion", "rhino", "elephant", "warthog", "hyena", "tiger"]:
		animals.animals.clear()
		landed.clear()
		var hurt_of: Dictionary = {1: 0, 2: 0}
		var keep: Callable = animals.big_game.hurt_player
		animals.big_game.hurt_player = func(peer, amount, lethal, cause, from):
			hurt_of[peer] = int(hurt_of[peer]) + 1
			return keep.call(peer, amount, lethal, cause, from)
		var invs: Array = []

		for peer in [1, 2]:
			items.vitals_of(peer)["health"] = 100.0
			items.vitals_of(peer).erase("limp")
			var inv = items.inventory_of(peer)

			for s in inv.slot_count:
				inv.clear_slot(s)

			inv.add(n("spear"), 1)
			invs.append(inv)

		var body: float = AnimalContact.body_m(sp)
		var reach: float = melee_reach("spear")
		var pos: Array = [Vector3(-(body + reach - 0.4), 10.0, 0.0), Vector3(body + reach - 0.4, 10.0, 0.0)]
		var id: int = animals.spawn(sp, 0.0, 0.0)
		animals.animals[id]["level"] = 1
		animals.animals[id]["cool"] = 0.0
		var next: Array = [0.0, 0.3]
		var start: float = clock
		var result: String = "time up"

		while clock - start < 120.0:
			clock += DT

			if not animals.animals.has(id):
				result = "killed %.0f s" % (clock - start)
				break

			var at: Vector3 = animals.animals[id]["pos"]

			for k in 2:
				var to: Vector3 = at - pos[k]
				to.y = 0.0

				if to.length() - body > reach - 0.3:
					pos[k] += to.normalized() * minf(WALK_MPS * DT, to.length() - body - (reach - 0.4))
				elif animals.animals.has(id) and clock >= float(next[k]) and int(animals.animals[id]["state"]) != BigGame.CHARGE:
					facing = atan2(-to.x, -to.z)
					next[k] = clock + recover_s("spear")
					items._last_strike.clear()
					items._strike(k + 1, invs[k], invs[k].numbers.find(n("spear")), to.normalized())

				items.report_position(k + 1, pos[k])

			animals.tick(DT)

			if float(items.vitals_of(1)["health"]) <= 10.01 and float(items.vitals_of(2)["health"]) <= 10.01:
				result = "both down"
				break

		animals.big_game.hurt_player = keep
		check(result.begins_with("killed") and int(hurt_of[2]) > 0, "two players kill a %s, and the one who hurt it last is hit (%d and %d blows)" % [sp, int(hurt_of[1]), int(hurt_of[2])])
		print("  %-14s | %-15s | %5d %3d    | %3.0f %3.0f" % [sp, result, int(hurt_of[1]), int(hurt_of[2]), float(items.vitals_of(1)["health"]), float(items.vitals_of(2)["health"])])


func melee_reach(weapon: String) -> float:
	if weapon == "":
		return float(items._melee_cfg.get("bare_hand", {}).get("reach_m", 1.8))

	return float(items.MeleeRules.blow(items.table.entry(weapon), items._melee_cfg)["reach_m"])


func recover_s(weapon: String) -> float:
	if weapon == "":
		return float(items._melee_cfg.get("bare_hand", {}).get("recover_ms", 600)) / 1000.0

	return float(items.table.entry(weapon).get("recover_ms", items.STRIKE_COOLDOWN_MS)) / 1000.0
