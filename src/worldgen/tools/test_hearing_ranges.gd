extends SceneTree

# Who hears what, how far (hearing-range pass, 23 Nov 2026, the coordinator: "for each sound group, at what distance a second player and
# an animal should hear it, written into docs/SOUND_MAP.md and tested, so stalking and being stalked make sense").
# Animals: a loud action (an axe or pick blow, a cry of pain, a dig, craft work) carries past stance and cover for a few seconds
# (server_action_cues.gd loud_kinds -> server_animals.gd player_loud, animals.json senses.action_heard_x); quiet ones change nothing.
# Players: the reaches in the SOUND_MAP table are the ones in the code.
#   godot --headless --path . --script res://src/worldgen/tools/test_hearing_ranges.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const CuesScript := preload("res://src/stream/server_action_cues.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const SoundStage := preload("res://src/client/sound_stage.gd")
const SlotSounds := preload("res://src/client/slot_sounds.gd")
const SwimSounds := preload("res://src/client/swim_sounds.gd")
const FlameSounds := preload("res://src/client/flame_sounds.gd")
const HarvestSounds := preload("res://src/client/harvest_sounds.gd")
const DigSounds := preload("res://src/client/dig_sounds.gd")
const PlacedSounds := preload("res://src/client/placed_sounds.gd")
const TreeSounds := preload("res://src/client/tree_sounds.gd")
const FireSounds := preload("res://src/client/fire_sounds.gd")
const PlayersScript := preload("res://src/stream/server_players.gd")

var failures: int = 0


class FakeItems:
	var peers: Array = [1, 2]

	func peer_ids() -> Array:
		return peers

	func position_of(_peer: int) -> Variant:
		return Vector3.ZERO


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


# What a grazing deer at the origin does within 2.5 s of a player `dist` m off in stance `stance` who did `loud` ("" nothing): "flee",
# "alert" (it watched at some point) or "graze". 2.5 s: a deer about to run first stares, up to 1.75 s (reactions.startle_s).
func deer_does(dist: float, stance: int, loud: String) -> String:
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return [Vector3(dist, 10.0, 0.0)]
	a.player_stances = func(): return [stance]
	a.player_loud = func(): return [loud]
	a.wind = func(): return {"wind": 0.0, "wind_dir": 0.0}
	a.setup()
	a.traits = false

	for sp in a.cfg["species"]:
		a.cfg["species"][sp]["target_per_player"] = 0

	a.rng.seed = 5
	var id: int = a.spawn("deer", 0.0, 0.0)
	a.animals[id]["timer"] = 100.0
	a.animals[id]["protective"] = false
	var fled: bool = false
	var watched: bool = false

	for n in 50:
		a.tick(0.05)
		fled = fled or int(a.animals[id]["state"]) == AnimalsScript.FLEE
		watched = watched or int(a.animals[id]["state"]) == AnimalsScript.ALERT

	if fled:
		return "flee"

	return "alert" if watched else "graze"


# The SOUND_MAP row starting with `label`: its "another player hears it within" cell, as a number of metres (-1 when missing).
func doc_reach(doc: String, label: String) -> float:
	for line in doc.split("\n"):
		if line.begins_with("| " + label + " |"):
			return float(line.split("|")[2].strip_edges().split(" ")[0])

	return -1.0


func _init() -> void:
	# Cues: which actions mark a player loud, and for how long.
	var clock: Array = [1000]
	var cues = CuesScript.new()
	cues.items = FakeItems.new()
	cues.now_ms = func() -> int: return int(clock[0])
	cues.send_cue = func(_to, _about, _cue, _detail, _at): pass
	check(cues.loud_kinds() == ["", ""], "nobody is loud at first")
	cues.cue(1, CuesScript.CUE_BLOW, 0 * 8 + CuesScript.MATERIALS.find("wood"), Vector3.ZERO)
	check(cues.loud_kinds() == ["blow", ""], "an axe blow on wood marks its player loud, nobody else")
	clock[0] += CuesScript.LOUD_HOLD_MS + 1
	check(cues.loud_kinds() == ["", ""], "and it wears off after LOUD_HOLD_MS")
	cues.cue(2, CuesScript.CUE_BLOW, CuesScript.MATERIALS.find("flesh"), Vector3.ZERO)
	cues.cue(1, CuesScript.CUE_PICK, 3, Vector3.ZERO)
	check(cues.loud_kinds() == ["", ""], "a knife cut on a carcass and a plant pick are quiet")
	clock[0] += 200
	cues.hurt(2, 10.0)
	cues.before_action(1, Net.ACT_DIG, 0, 0)
	check(cues.loud_kinds() == ["dig", "hurt"], "a dig and a cry of pain are loud")
	clock[0] += CuesScript.LOUD_HOLD_MS + 1
	cues.cue(1, CuesScript.CUE_CRAFT, 4, Vector3.ZERO)
	check(cues.loud_kinds()[0] == "craft", "craft work is loud")
	cues.forget(1)
	cues.cue(1, CuesScript.CUE_PICK, 3, Vector3.ZERO)
	cues.note_action(1, Net.ACT_HIT, 7, 0, 0, Vector3.ZERO)
	check(cues.loud_kinds()[0] == "blow", "a tree blow just after a pick (inside the gap) still marks its player loud")
	cues.hurt(1, 10.0)
	check(cues.loud_kinds()[0] == "blow", "a cry between blows does not lower the blow's reach")
	clock[0] += 3000
	cues.cue(1, CuesScript.CUE_CRAFT, 4, Vector3.ZERO)
	clock[0] += 2500
	cues.cue(1, CuesScript.CUE_CRAFT, 4, Vector3.ZERO)
	check(cues.loud_kinds()[0] == "craft", "crafting after one blow is craft work once the blow's hold is up (a quieter thing never stretches it)")
	check(CuesScript.LOUD_HOLD_MS >= CuesScript.CRAFT_EVERY_MS, "a craft's repeating cue keeps its worker loud between cues")
	cues.forget(1)
	check(cues.loud_kinds()[0] == "", "a player who left is not loud")

	# Animals: the deer's notice and flee distances (60 and 35 m) stretched by the loud action, past stance and cover.
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))
	var sen: Dictionary = cfg["senses"]
	var heard: Dictionary = sen["action_heard_x"]
	var deer: Array = cfg["reactions"]["notice_flee_safe_m"]["deer"]
	var all_under: bool = true

	for k in heard:
		all_under = all_under and float(heard[k]) > 1.0 and float(heard[k]) <= float(sen["far_factor"])

	check(all_under, "every action_heard_x is above 1 and at most far_factor (past it no player is sensed)")
	check(heard.has("blow") and heard.has("hurt") and heard.has("dig") and heard.has("craft"), "every loud cue has its distance")
	var ranked: bool = true

	for x in heard:
		for y in heard:
			if int(CuesScript.LOUD_RANK.get(x, 0)) > int(CuesScript.LOUD_RANK.get(y, 0)):
				ranked = ranked and float(heard[x]) > float(heard[y])

	check(ranked and CuesScript.LOUD_RANK.size() == heard.size(), "LOUD_RANK orders the loud names as action_heard_x does")
	check(deer == [60.0, 35.0, 70.0], "the deer row is the one these checks are worked out from")
	check(deer_does(70.0, 0, "") == "graze", "a quiet player standing 70 m off: the deer keeps grazing")
	check(deer_does(70.0, 0, "blow") == "alert", "an axe blow at 70 m: the deer looks up (70 / 1.4 = 50 m)")
	check(deer_does(95.0, 0, "blow") == "graze", "an axe blow at 95 m, past the deer's 90 m reach: nothing")
	check(deer_does(45.0, 1, "") == "graze", "crouched and quiet at 45 m: unnoticed (45 / 0.6 = 75 m)")
	check(deer_does(45.0, 1, "blow") == "flee", "crouched and chopping at 45 m: it runs (45 / 1.4 = 32 m)")
	check(deer_does(45.0, 0, "") == "alert", "standing at 45 m: it watches but stays")
	check(deer_does(45.0, 0, "pick") == "alert", "a name with no distance (a pick) changes nothing")
	check(deer_does(20.0, 1, "craft") == "flee", "craft work at 20 m, crouched: it runs (20 / 1.1 = 18 m)")
	check(deer_does(40.0, 1, "craft") == "alert", "craft work at 40 m, crouched: it looks up but stays (40 / 1.1 = 36 m; quiet and crouched it would not notice, 40 / 0.6 = 67 m)")

	# A startle (a missed arrow, a tree crash: alarm_near) sends a grazing deer off, but never changes big game standing its ground, charging
	# or recovering (the animals thread's charge code owns those states).
	var st = AnimalsScript.new()
	st.ground_height = func(_x, _z): return 10.0
	st.blocked = func(_x, _z): return false
	st.player_positions = func(): return []
	st.setup()
	var grazer: int = st.spawn("deer", 0.0, 0.0)
	var held: Array = []

	for s in [AnimalsScript.WARN, AnimalsScript.WARN + 1, AnimalsScript.WARN + 2]:
		var id: int = st.spawn("deer", 3.0, float(s))
		st.animals[id]["state"] = s
		held.append(id)

	st.alarm_near(Vector3(1.0, 10.0, 1.0), 12.0)
	check(int(st.animals[grazer]["state"]) == AnimalsScript.FLEE, "a startle within its radius sends a grazing deer running")
	check(held.all(func(id): return int(st.animals[id]["state"]) == AnimalsScript.WARN + held.find(id)), "and leaves big game standing its ground, charging or recovering as it was")

	# Players: the SOUND_MAP table matches the code.
	var doc: String = FileAccess.get_file_as_string("res://docs/SOUND_MAP.md")
	check(doc.contains("## Who hears what, how far"), "SOUND_MAP has the hearing table")
	var rows: Dictionary = {
		"Footsteps, walking or running": SoundStage.OTHER_STEP_REACH_M,
		"Footsteps, crouched (6 dB softer)": SoundStage.OTHER_STEP_REACH_M,
		"Swimming strokes": SwimSounds.OTHER_STROKE_REACH_M,
		"Axe or pick blow (tree, log, stump, bush, boulder, ground)": CuesScript.HEAR_M[CuesScript.CUE_BLOW],
		"Cry of pain (an attack landed)": CuesScript.HEAR_M[CuesScript.CUE_HURT],
		"Shovel dig, fill or trench": DigSounds.MAX_DISTANCE_M,
		"Craft work (knapping, carving, twine)": CuesScript.HEAR_M[CuesScript.CUE_CRAFT],
		"Knife on a carcass": CuesScript.HEAR_M[CuesScript.CUE_BLOW],
		"Plant picked, cut by sickle or scythe": minf(CuesScript.HEAR_M[CuesScript.CUE_PICK], HarvestSounds.MAX_DISTANCE_M),
		"Chest lid, things put in or taken out": CuesScript.HEAR_M[CuesScript.CUE_STORE],
		"Mouthful of water": CuesScript.HEAR_M[CuesScript.CUE_DRINK],
		"Thing picked up off the ground": CuesScript.HEAR_M[CuesScript.CUE_PICKUP],
		"Carried torch or lantern": FlameSounds.OTHERS_REACH_M,
		"Bow drawn": SlotSounds.SKIP_M,
		"Arrow or spear loosed and landing": PlayersScript.NEAR_M,
		"Tree falling": TreeSounds.MAX_DISTANCE_M,
		"Building piece set or taken down": PlacedSounds.MAX_DISTANCE_M,
		"Campfire": FireSounds.REACH_M,
	}

	for label in rows:
		var got: float = doc_reach(doc, label)
		check(is_equal_approx(got, float(rows[label])), "SOUND_MAP: %s within %s m (code %s m)" % [label, got, rows[label]])

	check(doc.contains("| 1.4 (deer") and is_equal_approx(float(heard["blow"]), 1.4), "SOUND_MAP gives the blow's 1.4 as animals.json does")
	check(doc_reach(doc, "Footsteps, walking or running") <= SlotSounds.CREATURE_STEP_REACH_M, "an animal's steps carry at least as far as a player's (being stalked is heard)")

	print("test_hearing_ranges: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)
