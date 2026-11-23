extends SceneTree

# Fights against goblins and bandits, walked end to end (coordinator, 23 Nov 2026): the real server_items and server_animals wired as the
# server scene wires them (terrain_server.gd: hit_animal, the big game's hurt_player with its 10-health floor, the walls).
#   1. every melee weapon, by type and tier, against a wild goblin and a level 1 and level 5 camp bandit: it lands, it wears by each blow,
#      a higher tier of a type takes no more blows than the one below, and no fight takes a silly number of blows (a table is printed);
#   2. an enemy's attack is readable as the animals' are: a warning, a strike, a recovery, and no second strike inside the recovery; from
#      beside the player the strike is still drawn charging strike_min_s before it lands;
#   3. it never lands from out of reach (a player who steps aside) nor through a wall between them;
#   4. worn armour and a raised shield cut a bandit's blow, and both wear by it; a bandit's blow is his weapon's kind (a level 5 bandit's iron
#      sword cuts, so mail stops more of it than of a level 1 bandit's club);
#   5. a lost fight: blow after blow never takes the player under the floor nor kills them (death.json stop_at_1); they are told and limp;
#   6. a wild goblin killed drops what it stole.
# Camps resetting (a cleared bandit camp dissolves, a goblin lair fills again) are test_bandit_sites and test_goblin_camp's.
#   godot --headless --path . --script res://src/worldgen/tools/test_enemy_fights.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const BigGame := preload("res://src/stream/server_big_game.gd")
const BanditsScript := preload("res://src/stream/server_bandits.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DIR := "user://test_enemy_fights"
const DT := 0.05

var failures: int = 0
var items
var animals
var said: Array = []
var landed: Array = []   # [time, amount, result] of every enemy blow on the player
var clock: float = 0.0
var facing: float = 0.0
var camps


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
	items.send_notice = func(_p, t): said.append(str(t))
	items.ground_height = func(_x, _z): return 10.0
	items.yaw_of = func(_p): return facing
	items.setup(ItemTableScript.load_default(), DIR)
	items.peer_connected_hello(1, "enemyfights0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 1.0e6   # the pack's carry limit is not what is tested

	animals = AnimalsScript.new()
	animals.ground_height = func(_x, _z): return 10.0
	animals.blocked = func(_x, _z): return false
	animals.player_positions = func(): return items.peer_positions()
	animals.player_stances = func(): return [0]
	animals.setup()
	animals.traits = false

	for sp in animals.cfg["species"]:
		animals.cfg["species"][sp]["target_per_player"] = 0   # only the enemies put down here

	animals.cfg["senses"] = {}
	animals.rng.seed = 11
	animals.walls = func(x0, z0, x1, z1, margin): return items.structure_blocks_step(x0, z0, x1, z1, margin)
	animals.big_game.player_info = func(): return items.wolf_info()
	animals.big_game.hurt_player = func(peer, amount, lethal, cause, from):
		var r: String = items.hurt_player(peer, amount, lethal, cause, 10.0, "", 0.0, from)
		landed.append([clock, amount, r])
		return r
	camps = BanditsScript.new()
	camps.setup("")
	animals.big_game.weapon_of = camps.weapon_of   # as the server scene wires it: a bandit strikes with his level's weapon
	animals.big_game.hurt_armed = func(peer, amount, lethal, cause, from, weapon):
		var blow: Dictionary = ItemsScript.weapon_blow(items.table.entry(str(weapon)), {})
		var r: String = items.hurt_player(peer, amount, lethal, cause, 10.0, str(blow["mode"]), float(blow["pen"]), from)
		landed.append([clock, amount, r, str(weapon)])
		return r
	var dropped: Array = []
	animals.drop_loot = func(number, count, pos):
		dropped.append([number, count])
		items.drop_world_made(number, count, pos)
	items.hit_animal = func(_peer, origin, dir, reach, amount) -> Dictionary:   # terrain_server.gd's, without the goblin tribe and the rewind
		var target: int = animals.target_along(origin, dir, reach)

		if target == 0:
			return {}

		var at: Vector3 = animals.animals[target]["pos"]
		animals.damage(target, amount, 1, "spear")
		return {"at": at}

	_weapons()
	_readable()
	_reach_and_walls()
	_armour_and_shield()
	_lost_fight()
	_fair_dodge()

	# 6. A wild goblin that stole something drops it when it is killed.
	var g: int = animals.spawn("goblin", 1.2, 0.0)
	animals.animals[g]["loot"] = [n("flint"), 3]
	dropped.clear()
	animals.damage(g, 1000.0, 1)
	check(not animals.animals.has(g) and dropped == [[n("flint"), 3]], "a goblin killed drops the 3 flint it stole (%s)" % str(dropped))

	items._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


# An enemy of `sp` standing `d` m east of the player, calm, at `level`.
func enemy(sp: String, d: float, level: int = 1) -> int:
	animals.animals.clear()
	var id: int = animals.spawn(sp, d, 0.0)
	var a: Dictionary = animals.animals[id]
	a["level"] = level
	a["hp"] = float(animals.species_def(sp).get("health", 5.0)) * animals.level_x(a, "hp")
	a["heading"] = PI
	a["cool"] = 0.0
	return id


func tick(seconds: float) -> void:
	for k in int(round(seconds / DT)):
		clock += DT
		animals.tick(DT)


func fresh_player() -> void:
	var v: Dictionary = items.vitals_of(1)
	v["health"] = 100.0
	v.erase("limp")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	landed.clear()


# 1. Every melee weapon against each enemy kind: blows to bring it down (a bandit gives up under surrender_share; a goblin dies) and wear.
func _weapons() -> void:
	var weapons: Array = []

	for id in items.table.ids():
		var e: Dictionary = items.table.entry(id)

		if float(e.get("damage", 0.0)) > 0.0 and str(e.get("damage_mode", "")) != "projectile" and str(e.get("weapon_class", "")) != "":
			weapons.append(id)

	check(weapons.size() >= 30, "%d melee weapons found" % weapons.size())
	var by_class: Dictionary = {}
	var foes: Array = [["goblin", 1], ["bandit", 1], ["bandit", 5]]
	print("weapon                class    dmg  reach | goblin  bandit1  bandit5 | wear/blow")

	for id in weapons:
		var e: Dictionary = items.table.entry(id)
		var row: Array = []
		var wear_per: float = 0.0
		var all_land: bool = true

		for foe in foes:
			fresh_player()
			var inv = items.inventory_of(1)
			for s in inv.slot_count:
				inv.clear_slot(s)

			inv.add(n(id), 1)
			var slot: int = inv.numbers.find(n(id))
			var target: int = enemy(str(foe[0]), 1.2, int(foe[1]))
			var blows: int = 0
			var w0: int = inv.wear[slot]

			while blows < 200 and animals.animals.has(target) and not animals.animals[target].has("gave_up"):
				items._last_strike.clear()
				var hp0: float = float(animals.animals[target]["hp"])
				items._strike(1, inv, slot, Vector3(1.0, 0.0, 0.0))
				blows += 1

				if animals.animals.has(target) and float(animals.animals[target]["hp"]) >= hp0:
					all_land = false
					break

			row.append(blows)
			wear_per = float(inv.wear[slot] - w0) / float(maxi(blows, 1)) if inv.numbers[slot] == n(id) else wear_per

		var cls: String = str(e.get("weapon_class", ""))
		print("%-21s %-8s %4.0f  %4.1f | %6d  %7d  %7d | %.2f" % [id, cls, float(e["damage"]), float(e.get("reach_m", 0.0)), row[0], row[1], row[2], wear_per])
		check(all_land, "%s lands on every enemy kind" % id)
		check(wear_per > 0.0, "%s wears by its blows (%.2f a blow)" % [id, wear_per])
		check(row.max() <= 30, "%s brings a level 5 bandit down in at most 30 blows (%s)" % [id, str(row)])

		if not by_class.has(cls):
			by_class[cls] = []

		by_class[cls].append([id, float(e["damage"]), row])

	# A higher tier of the same type is never worse: the tier is in the name (wooden, stone, bone, bronze, iron, steel).
	var tiers: Array = ["wooden", "stone", "bone", "bronze", "iron", "steel"]

	for cls in by_class:
		for a in by_class[cls]:
			for b in by_class[cls]:
				var ta: int = tiers.find(str(a[0]).split("_")[0])
				var tb: int = tiers.find(str(b[0]).split("_")[0])

				if ta >= 0 and tb > ta and str(a[0]).split("_", true, 1)[-1] == str(b[0]).split("_", true, 1)[-1]:
					check(int(b[2][2]) <= int(a[2][2]), "%s takes no more blows than %s (%d against %d)" % [b[0], a[0], int(b[2][2]), int(a[2][2])])


# 2. Warning, strike, recovery: the time from the first warning to the blow is at least the row's warning, and nothing lands in the recovery.
func _readable() -> void:
	for sp in ["goblin", "bandit"]:
		fresh_player()
		var def: Dictionary = animals.species_def(sp)["defend"]
		var id: int = enemy(sp, 4.0)
		var a: Dictionary = animals.animals[id]
		var t0: float = clock
		check(animals.big_game.warn(a, Vector3(0.0, 10.0, 0.0), -1.0, true), "a %s takes the player on" % sp)
		var seen: Array = []
		var hit_at: float = -1.0

		for k in int(12.0 / DT):
			tick(DT)

			if not animals.animals.has(id):
				break

			var st: int = int(animals.animals[id]["state"])

			if seen.is_empty() or seen.back() != st:
				seen.append(st)

			if hit_at < 0.0 and not landed.is_empty():
				hit_at = float(landed[0][0])

		var warned: float = hit_at - t0
		check(seen.slice(0, 3) == [BigGame.WARN, BigGame.CHARGE, BigGame.RECOVER], "a %s warns, strikes and recovers (%s)" % [sp, str(seen)])
		check(hit_at > 0.0 and warned >= float(def["warn_s"]) - 0.01, "its blow lands %.2f s after the warning began (the warning is %.2f s)" % [warned, float(def["warn_s"])])
		var in_recovery: int = landed.filter(func(l): return float(l[0]) > hit_at and float(l[0]) < hit_at + float(def["recover_s"])).size()
		check(landed.size() >= 1 and in_recovery == 0, "and no second blow inside its %.1f s recovery (%d blows in all)" % [float(def["recover_s"]), landed.size()])


	# From right beside the player (the robots over a lossy link, 23 Nov 2026: a bandit warning from 1.4 m struck on the charge's first step,
	# so no client ever drew the charge): the strike is held strike_min_s, in the charge state, before the blow lands.
	for sp in ["goblin", "bandit"]:
		var def: Dictionary = animals.species_def(sp)["defend"]

		for d in [1.0, 1.4]:
			fresh_player()
			var id: int = enemy(sp, d)
			animals.big_game.warn(animals.animals[id], Vector3(0.0, 10.0, 0.0), -1.0, true)
			var charging: float = 0.0
			var closest: float = INF

			for k in int(4.0 / DT):
				tick(DT)

				if landed.is_empty() and animals.animals.has(id) and int(animals.animals[id]["state"]) == BigGame.CHARGE:
					charging += DT

				if animals.animals.has(id):
					closest = minf(closest, Vector2(animals.animals[id]["pos"].x, animals.animals[id]["pos"].z).length())

			check(landed.size() == 1 and charging >= float(def["strike_min_s"]) - 0.001, "a %s warning from %.1f m strikes once, after %.2f s drawn charging (at least %.2f)" % [sp, d, charging, float(def["strike_min_s"])])
			check(closest >= 0.3, "and never runs into the player meanwhile (nearest %.2f m)" % closest)


# 3. Out of reach and through walls.
func _reach_and_walls() -> void:
	for sp in ["goblin", "bandit"]:
		var def: Dictionary = animals.species_def(sp)["defend"]

		# Dodging: the player moves sideways from the moment the charge starts, at a walk (3.2 m/s, as with a shield raised) or a run
		# (9 m/s, terrain_client RUN_SPEED), from 6 m off or from 10 m; every attack must be dodgeable (Dave, server_big_game.gd header).
		var dodged: Array = []

		for style in [[3.2, 6.0], [9.0, 6.0], [3.2, 10.0], [9.0, 10.0]]:
			fresh_player()
			var id: int = enemy(sp, float(style[1]))
			animals.big_game.warn(animals.animals[id], Vector3(0.0, 10.0, 0.0), -1.0, true)
			var off: float = 0.0

			for k in int(8.0 / DT):
				if animals.animals.has(id) and int(animals.animals[id]["state"]) == BigGame.CHARGE:
					off += float(style[0]) * DT
					items.report_position(1, Vector3(0.0, 10.0, off))

				tick(DT)

			print("  %s from %.0f m, side step at %.1f m/s: %s" % [sp, float(style[1]), float(style[0]), "hit" if not landed.is_empty() else "dodged"])

			if landed.is_empty():
				dodged.append(style)

		check(not dodged.is_empty(), "a %s's charge can be dodged by stepping aside (%d of 4 ways; turn %.1f rad/s, hit_m %.1f)" % [sp, dodged.size(), float(def["turn_rad_s"]), float(def["hit_m"])])

	# A wall between: the enemy is stopped at it, and never strikes the player standing just behind it.
	var walls: Array = []

	for z in [-4.0, -2.0, 0.0, 2.0, 4.0]:   # five 2 m log walls, turned 90 degrees to run north and south: 10 m of wall, too long to go round
		walls.append(items.dev_place("log_wall@101.6,%.1f,90" % z))

	check(not walls.has(0) and items.structure_blocks_step(103.0, 0.0, 100.5, 0.0, 0.3), "a 10 m log wall stands across the way at x 101.6 (100 m east, clear of the other fights)")

	for sp in ["goblin", "bandit"]:
		fresh_player()
		items.report_position(1, Vector3(101.2, 10.0, 0.0))   # hard behind the wall (its far face at 101.475): within the enemy's reach of its near side
		var id: int = enemy(sp, 106.0)
		animals.big_game.warn(animals.animals[id], Vector3(101.2, 10.0, 0.0), -1.0, true)
		var closest: float = INF

		for k in int(12.0 / DT):
			tick(DT)

			if animals.animals.has(id):
				closest = minf(closest, float(animals.animals[id]["pos"].x))

		check(closest > 101.6 and closest < 103.0, "a %s's charge runs up to the wall and stops there (nearest x %.2f; the wall at 101.6)" % [sp, closest])
		check(landed.is_empty(), "and never strikes the player behind it (%d blows)" % landed.size())

	# Nor does the player's blow go through it: a bandit standing against the near side, an Iron sword (reach 2.5 m) from behind it.
	fresh_player()
	items.report_position(1, Vector3(101.2, 10.0, 0.0))
	var inv = items.inventory_of(1)
	items.give(1, n("iron_sword"), 1)
	var through: int = enemy("bandit", 102.0)
	var hp0: float = float(animals.animals[through]["hp"])
	items._last_strike.clear()
	items._strike(1, inv, inv.numbers.find(n("iron_sword")), Vector3(1.0, 0.0, 0.0))
	check(float(animals.animals[through]["hp"]) == hp0, "a sword blow from behind the wall never reaches the bandit 0.8 m off on its far side")
	items.report_position(1, Vector3(103.0, 10.0, 0.0))
	animals.animals[through]["heading"] = 0.0
	items._last_strike.clear()
	items._strike(1, inv, inv.numbers.find(n("iron_sword")), Vector3(-1.0, 0.0, 0.0))
	check(float(animals.animals[through]["hp"]) < hp0, "but on the same side it lands")
	inv.clear_slot(inv.numbers.find(n("iron_sword")))


# 4. Armour and a raised shield against a bandit's blow (blunt): each cuts it and wears.
func _armour_and_shield() -> void:
	var base: float = _bandit_blow()
	var inv = items.inventory_of(1)
	items.give(1, n("iron_shield"), 1)
	facing = -PI * 0.5   # facing 0 looks down -Z; this looks down +X, at the bandit
	items.report_held(1, 0, n("iron_shield"), ItemsScript.HAND_SHIELD_UP)
	var s: int = inv.numbers.find(n("iron_shield"))
	var w0: int = inv.wear[s]
	var shielded: float = _bandit_blow()
	check(shielded < base * 0.9 and inv.wear[s] > w0, "a raised Iron shield facing the bandit cuts his blow (%.1f to %.1f) and wears by it (%d)" % [base, shielded, inv.wear[s] - w0])
	facing = PI * 0.5
	var behind: float = _bandit_blow()
	check(absf(behind - base) < 0.01, "turned away, the shield stops nothing (%.1f)" % behind)
	items.report_held(1, 0, 0, 0)
	facing = 0.0
	var worn: Array = []

	for id in ["leather_cap", "leather_jerkin", "padded_gambeson", "iron_helm", "chainmail_shirt", "iron_breastplate"]:
		if items.table.has_id(id):
			items.give(1, n(id), 1)
			var slot: int = inv.numbers.find(n(id))

			if slot >= 0:
				items.action(1, Net.ACT_WEAR, slot, 0, 0, Vector3.ZERO)
				worn.append(id)

	var armoured: float = _bandit_blow()
	check(worn.size() > 0 and armoured < base * 0.95, "worn armour (%s) cuts a bandit's blow (%.1f to %.1f)" % [", ".join(worn), base, armoured])

	# A bandit's blow is his weapon's kind: mail (strong against cuts, weak against blows, master items 3.7 rule 3) stops more of a level 5
	# bandit's iron sword than of a level 1 bandit's wooden club.
	for k in inv.slot_count:
		inv.clear_slot(k)

	items._characters[items._peer_key[1]]["worn"] = items._clean_worn([])   # the outfit above off
	items.give(1, n("iron_mail_hauberk"), 1)
	items.action(1, Net.ACT_WEAR, inv.numbers.find(n("iron_mail_hauberk")), 0, 0, Vector3.ZERO)
	_bandit_blow(1)
	var club_share: float = 1.0 - (100.0 - float(items.vitals_of(1)["health"])) / float(landed[0][1])
	var club_with: String = str(landed[0][3]) if landed[0].size() > 3 else ""
	_bandit_blow(5)
	var sword_share: float = 1.0 - (100.0 - float(items.vitals_of(1)["health"])) / float(landed[0][1])
	var sword_with: String = str(landed[0][3]) if landed[0].size() > 3 else ""
	check(club_with == "wooden_club" and sword_with == "iron_sword", "a level 1 bandit strikes with a wooden club, a level 5 one with an iron sword (%s, %s)" % [club_with, sword_with])
	# A camp bandit's own row: one who threw his weapon down, or gave up, strikes with nothing (the plain blunt blow).
	var cell := Vector2i(3, 4)
	var probe: Dictionary = {"sp": "bandit", "id": 900, "camp": cell, "level": 5}
	camps._members[cell] = {900: {"armed": true, "level": 5, "horse": false}}
	var armed_with: String = camps.weapon_of(probe)
	camps._members[cell][900]["armed"] = false
	var thrown_down: String = camps.weapon_of(probe)
	camps._members[cell][900]["armed"] = true
	probe["gave_up"] = 1.0
	check(armed_with == "iron_sword" and thrown_down == "" and camps.weapon_of(probe) == "", "a camp bandit holding his sword strikes with it; one who threw it down or gave up strikes with none (%s, %s)" % [armed_with, thrown_down])
	camps._members.erase(cell)
	check(sword_share > club_share + 0.1, "a mail hauberk stops more of the sword's cut (%.0f%%) than of the club's blow (%.0f%%)" % [sword_share * 100.0, club_share * 100.0])


# The health one level 1 bandit's landed charge takes off a fresh player at the origin, from the east.
func _bandit_blow(level: int = 1) -> float:
	fresh_player()
	var id: int = enemy("bandit", 4.0, level)
	animals.big_game.warn(animals.animals[id], Vector3(0.0, 10.0, 0.0), -1.0, true)

	for k in int(4.0 / DT):
		tick(DT)

		if not landed.is_empty():
			break

	return 100.0 - float(items.vitals_of(1)["health"])


# 5. A lost fight: a level 5 bandit's blows again and again. Health stops at the floor, the player is never killed, is told and limps.
func _lost_fight() -> void:
	fresh_player()
	said.clear()
	var low: float = 100.0
	var results: Dictionary = {}

	for charge in 40:
		var id: int = enemy("bandit", 4.0, 5)
		animals.big_game.warn(animals.animals[id], Vector3(0.0, 10.0, 0.0), -1.0, true)

		for k in int(4.0 / DT):
			tick(DT)

		low = minf(low, float(items.vitals_of(1)["health"]))

	for l in landed:
		results[str(l[2])] = int(results.get(str(l[2]), 0)) + 1

	var v: Dictionary = items.vitals_of(1)
	check(landed.size() >= 30, "%d blows landed in 40 charges" % landed.size())
	check(low >= 10.0 - 0.01 and not results.has("dead"), "health never falls under the floor of 10 and nobody dies (lowest %.1f; %s)" % [low, str(results)])
	check(results.has("maimed") and float(v.get("limp", 0.0)) > 0.0 and said.any(func(t): return str(t).contains("badly hurt")), "the beaten player is told they are badly hurt and limps")


# 7. A fair dodge over the link (robots 23 Nov 2026, 60 and 120 ms with loss: 0 of 9 side-steps got clear). The player's screen draws the
# server dodge_view_ms behind and their step comes back a round trip later, so here the player starts stepping that long after the server's
# charge began, as their reports would reach it. The blow is judged that long after it would land, against where the player then is.
func _fair_dodge() -> void:
	var rtt: int = 240   # a 120 ms link each way
	animals.big_game.ping_ms = func(_peer): return rtt
	var late: float = (float(animals.cfg.get("dodge_view_ms", 350)) + float(rtt)) / 1000.0
	check(absf(animals.big_game.late_s(animals.species_def("goblin")["defend"], 1) - minf(late, float(animals.cfg.get("dodge_late_max_ms", 600)) / 1000.0)) < 0.001, "a goblin's blow is judged %.2f s late on a %d ms round trip" % [late, rtt])
	late = animals.big_game.late_s(animals.species_def("goblin")["defend"], 1)

	for sp in ["goblin", "bandit"]:
		for style in [[0.0, 1.4], [3.2, 1.4], [9.0, 1.4], [3.2, 6.0]]:   # stand, walk aside, run aside; from 1.4 m (a fight) and 6 m
			fresh_player()
			var id: int = enemy(sp, float(style[1]))
			animals.big_game.warn(animals.animals[id], Vector3(0.0, 10.0, 0.0), -1.0, true)
			var charge_at: float = -1.0
			var off: float = 0.0
			var closest: float = INF
			var held: bool = false

			for k in int(6.0 / DT):
				if animals.animals.has(id) and charge_at < 0.0 and int(animals.animals[id]["state"]) == BigGame.CHARGE:
					charge_at = clock

				if charge_at >= 0.0 and clock - charge_at >= late and float(style[0]) > 0.0 and off < 3.0:
					off += float(style[0]) * DT   # stepping aside, as the server hears it
					items.report_position(1, Vector3(0.0, 10.0, off))

				tick(DT)

				if animals.animals.has(id):
					held = held or animals.animals[id].has("late")
					var p: Vector3 = items.position_of(1)
					closest = minf(closest, Vector2(animals.animals[id]["pos"].x - p.x, animals.animals[id]["pos"].z - p.z).length())

			var what: String = "hit" if not landed.is_empty() else "dodged"
			print("  %s from %.1f m, the step aside at %.1f m/s starting %.2f s into the server's charge: %s" % [sp, float(style[1]), float(style[0]), late, what])

			if float(style[0]) == 0.0:
				check(landed.size() == 1 and held, "a %s's blow on a player who stands still lands, once, after the fair-dodge wait" % sp)
				check(landed.size() == 1 and float(landed[0][0]) - charge_at >= late - 0.001, "and it lands %.2f s after the charge began (the wait %.2f s)" % [float(landed[0][0]) - charge_at if not landed.is_empty() else -1.0, late])
			elif sp == "goblin" or float(style[0]) > 5.0:
				check(landed.is_empty(), "a %s's charge from %.1f m is dodged by a step aside at %.1f m/s begun when the player's screen showed the charge" % [sp, float(style[1]), float(style[0])])

			check(closest >= 0.3, "and it never stands inside the player meanwhile (nearest %.2f m)" % closest)

	animals.big_game.ping_ms = Callable()

	# A player walking into a goblin or a camp bandit at 5 m/s to strike (robots 23 Nov 2026: a goblin 0.21 to 0.25 m inside them): it gives
	# way at their pace, out of where they will be by its next step, so it is never caught inside between its tenth-of-a-second steps. A
	# bandit who gave up stays where he sits.
	for who in ["goblin", "bandit", "bandit gave up"]:
		var id: int = enemy(who.split(" ")[0], 0.0)
		var a: Dictionary = animals.animals[id]
		a["pos"] = Vector3(200.7, 10.0, 0.0)

		if who != "goblin":
			a["camp"] = Vector2i(0, 0)

		if who == "bandit gave up":
			a["gave_up"] = 0.0

		var p := Vector3(199.0, 10.0, 0.0)
		var nearest: float = INF

		for k in 10:
			p.x += 0.5   # 5 m/s, a tenth of a second
			animals._noise_from = [p]
			animals._player_vel = [Vector2(5.0, 0.0)]
			animals.make_way(a, p, 0.1, [p])
			nearest = minf(nearest, absf(a["pos"].x - (p.x + 0.5)))   # where the player is just before its next step

		if who == "bandit gave up":
			check(absf(a["pos"].x - 200.7) < 0.001, "a %s is not pushed about by a player walking into him" % who)
		else:
			check(nearest >= 0.35, "a %s a player walks into at 5 m/s gives way ahead of them: never inside between its steps (nearest %.2f m)" % [who, nearest])

	animals._noise_from = []
	animals._player_vel = []
