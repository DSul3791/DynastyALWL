extends SceneTree

# Close blows from the models' own attacks (Dave 23 Nov 2026: "not all animals charge they actually have actions built in to them and I
# believe attacks are in there"; "make sure to use models that have the actions we need"). A warning that ends with the player already at the
# animal ends in its strike (a swipe, bite, horn, stomp) or, for a donkey or a goat, its kick behind, wound up where it stands; farther off it
# is the charge, as before. A player who stands still is struck once, windup_s after it began, for damage_x of the row's damage; one who steps
# back in the wind-up is not. Every kind with a strike or kick has the clip for it on every look (models.json), and the client times it from
# the same windup_s. Full ticks, as on the server.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_close_blows.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const AnimalContact := preload("res://src/shared/animal_contact.gd")
const AnimalView := preload("res://src/client/animal_view.gd")

var failures: int = 0
var hurt_log: Array = []
var players: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func make() -> Object:
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players
	a.player_stances = func(): return [0]
	a.wind = func(): return {"wind": 0.0, "wind_dir": 0.0}
	a.setup()
	a.traits = false

	for s in a.cfg["species"]:
		a.cfg["species"][s]["target_per_player"] = 0

	a.rng.seed = 11

	for s in a.cfg["species"]:
		if a.cfg["species"][s].get("defend", null) is Dictionary:
			a.cfg["species"][s]["defend"]["bluff_share"] = 0.0   # a bluff is always a charge that stops short: here every warning presses home

	a.big_game.player_info = func(): return [{"peer": 1, "pos": players[0], "stance": 0, "hp": 1.0}]
	a.big_game.hurt_player = func(peer, amount, _lethal, _cause, _from):
		hurt_log.append([peer, amount])
		return "hurt"
	return a


# A level 1 `sp` at the origin warned at a player `dist` m east; ticks `seconds`. `back_m` > 0: the player steps that far straight back the
# moment the close blow begins. Returns [states seen, seconds from the blow's start to the first hit (-1 none), its heading then, the animal].
func bout(a, sp: String, dist: float, back_m: float, seconds: float) -> Array:
	hurt_log = []
	players = [Vector3(dist, 10.0, 0.0)]
	a.animals.clear()
	var id: int = a.spawn(sp, 0.0, 0.0)
	var b: Dictionary = a.animals[id]
	b["temper"] = "defensive"
	b["protective"] = false
	b["level"] = 1
	b["cool"] = 0.0
	a.big_game.warn(b, players[0], 0.3, true)
	var states: Array = []
	var began: float = -1.0
	var first: float = -1.0
	var heading: float = 0.0
	var t: float = 0.0
	var dt: float = 0.025

	while t < seconds and a.animals.has(id):
		a.tick(dt)
		t += dt
		var st: int = int(b["state"])

		if states.is_empty() or int(states.back()) != st:
			states.append(st)

		if began < 0.0 and (st == a.big_game.STRIKE or st == a.big_game.KICK):
			began = t - dt
			heading = float(b["heading"])

			if back_m > 0.0:
				players[0] = players[0] + Vector3(back_m, 0.0, 0.0)

		if first < 0.0 and not hurt_log.is_empty():
			first = t - began if began >= 0.0 else -1.0

	return [states, first, heading, b]


func _init() -> void:
	var a = make()
	var models: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/models.json"))["species"]
	var kinds: Array = []

	for sp in a.cfg["species"]:
		var def: Dictionary = a.species_def(sp).get("defend", {})

		if def.has("strike") or def.has("kick"):
			kinds.append(sp)

	check(kinds.size() >= 12, "kinds with a close blow: %s" % str(kinds))

	for sp in kinds:
		var def: Dictionary = a.species_def(sp)["defend"]
		var how: String = "kick" if def.has("kick") else "strike"
		var row: Dictionary = def[how]
		var state: int = a.big_game.KICK if how == "kick" else a.big_game.STRIKE
		var contact: float = AnimalContact.contact_m(sp)
		check(float(row["start_m"]) < float(row["reach_m"]), "a %s's %s begins inside its reach (%.1f against %.1f m), so it never swings at the air" % [sp, how, float(row["start_m"]), float(row["reach_m"])])

		# 1. Standing still at it: the close blow, once, windup_s in, for damage_x of the row's damage.
		var r: Array = bout(a, sp, contact + float(row["start_m"]) - 0.1, 0.0, 3.0)
		var states: Array = r[0]
		check(states.has(state) and not states.has(a.big_game.CHARGE), "a %s warning a player %.1f m off %ss instead of charging (states %s)" % [sp, contact + float(row["start_m"]) - 0.1, how, str(states)])
		check(hurt_log.size() == 1 and absf(float(r[1]) - float(row["windup_s"])) <= 0.06, "it lands once, %.2f s into the wind-up (windup_s %.2f; %d blows)" % [float(r[1]), float(row["windup_s"]), hurt_log.size()])
		var want: float = float(def.get("damage", 25.0)) * float(row.get("damage_x", 1.0)) * a.level_x(r[3], "damage")
		check(hurt_log.size() == 1 and absf(float(hurt_log[0][1]) - want) < 0.01, "for %.1f (damage %.0f times %.1f)" % [float(hurt_log[0][1]) if not hurt_log.is_empty() else -1.0, float(def.get("damage", 25.0)), float(row.get("damage_x", 1.0))])
		var back: float = angle_difference(float(r[2]), 0.0)
		check((how == "kick" and absf(back) > PI * 0.9) or (how == "strike" and absf(back) < 0.1), "a %s faces the player for a strike, turns its back for a kick (heading %.2f)" % [sp, float(r[2])])
		check(states.has(a.big_game.RECOVER), "and recovers after it (states %s)" % str(states))

		# 2. Stepping straight back in the wind-up: out of reach when it lands.
		bout(a, sp, contact + float(row["start_m"]) - 0.1, float(row["reach_m"]) - float(row["start_m"]) + 0.4, 3.0)
		check(hurt_log.is_empty(), "a player who steps back %.1f m in a %s's wind-up is not struck" % [float(row["reach_m"]) - float(row["start_m"]) + 0.4, sp])

		# 3. Farther off: the charge, as before.
		r = bout(a, sp, contact + float(row["start_m"]) + 2.0, 0.0, 1.5)
		check((r[0] as Array).has(a.big_game.CHARGE) and not (r[0] as Array).has(state), "a %s warning a player %.1f m off still charges (states %s)" % [sp, contact + float(row["start_m"]) + 2.0, str(r[0])])

		# 4. Every look has the clip for it, and the client times it from the same wind-up.
		var mrow: Dictionary = models.get(sp, {})
		var looks: Array = (mrow.get("variants", []) as Array) if not (mrow.get("variants", []) as Array).is_empty() else [{}]

		for look in looks:
			var clips: Dictionary = mrow.get("clips", {}).duplicate()
			clips.merge((look as Dictionary).get("clips", {}), true)

			for k in ["strike", "kick"]:
				if def.has(k):
					check(clips.has(k), "a %s look (%s) has a %s clip" % [sp, str((look as Dictionary).get("scene", mrow.get("scene", ""))).get_file(), k])

			if def.has("strike"):
				check(absf(AnimalView.windup_s(sp, "strike") - float(def["strike"]["windup_s"])) < 0.001, "the client times a %s's strike from its windup_s" % sp)

	# 5. A donkey's kick lands behind it: a player in front of a donkey turned to kick is not struck.
	var donkey_kick: Dictionary = a.species_def("donkey")["defend"]["kick"]
	var probe: Dictionary = {"sp": "donkey", "pos": Vector3(0.0, 10.0, 0.0), "heading": PI, "dir": PI, "attack": "kick"}
	var behind: Vector3 = Vector3(AnimalContact.contact_m("donkey") + 0.5, 10.0, 0.0)
	check(a.big_game.in_reach(probe, donkey_kick, behind) and not a.big_game.in_reach(probe, donkey_kick, Vector3(-behind.x, 10.0, 0.0)), "a kick reaches behind the donkey, not in front of it")

	# 6. The models with no attack clip are no longer drawn (Dave 23 Nov 2026: "make sure to use models that have the actions we need").
	var scenes: Array = []

	for sp in ["wolf", "fox", "donkey", "lion", "boar", "bear"]:
		scenes.append(str(models[sp]["scene"]))

		for look in models[sp].get("variants", []):
			scenes.append(str((look as Dictionary).get("scene", "")))

	check(not scenes.any(func(s: String) -> bool: return s.contains("/wolf/") or s.contains("/fox/") or s.contains("/donkey/") or s.contains("/lioness/") or s.contains("/boar_2/")), "the wolf, fox, donkey, lioness and second boar looks with no attack are gone (%s)" % str(scenes))
	check(str(models["bear"]["variants"][0]["scene"]).contains("/bear_2/"), "the bear with the melee attacks is the first bear look")

	print("test_animal_close_blows: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
