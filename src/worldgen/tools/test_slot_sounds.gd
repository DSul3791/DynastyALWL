extends SceneTree

# Kathleen's sound slots through SlotSounds: every slot has a clip, no clip twice in a row, cooldown and priority under the voice cap, and the call
# sites and the JSON agree both ways (a slot name used in code must exist; a door material in structures.json must have its open and close slots).

const SlotSounds := preload("res://src/client/slot_sounds.gd")
const Ambience := preload("res://src/client/ambience_slots.gd")
const AnimalView := preload("res://src/client/animal_view.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")
const SOURCES := ["res://scenes/terrain_client/terrain_client.gd", "res://src/client/placed_sounds.gd", "res://src/client/animal_view.gd", "res://src/client/sound_test_menu.gd"]

var failures: int = 0


class StubStage extends Node:
	var voice_cap: int = 3
	var playing: int = 0

	func has_room() -> bool:
		return playing < voice_cap

	func voices_playing() -> int:
		return playing


func check(ok: bool, what: String) -> void:
	print("%s: %s" % ["pass" if ok else "FAIL", what])
	failures += 0 if ok else 1


func _init() -> void:
	var stage: StubStage = StubStage.new()
	root.add_child(stage)
	var slots: SlotSounds = SlotSounds.new()
	stage.add_child(slots)
	slots.setup(stage)
	var names: Array = slots.slot_names()
	check(names.size() >= 18, "the JSON lists the batch 1 slots (%d)" % names.size())
	var clips: int = 0

	for slot in names:
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SlotSounds.SLOTS_PATH))["slots"][slot]
		var found: int = 0

		for path in parsed["files"]:
			found += 1 if FileAccess.file_exists(str(path)) else 0        # the file is in the project (git); whether the editor has imported it yet is checked below

		clips += found
		check(found >= 1, "slot %s has a clip (%d of %d files exist)" % [slot, found, parsed["files"].size()])

	# No clip twice in a row, whatever the draws are.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var last: int = -1
	var repeats: int = 0

	for n in 1000:
		var pick: int = SlotSounds.pick_index(3, last, rng.randi())
		repeats += 1 if pick == last else 0
		last = pick

	check(repeats == 0, "1000 draws of 3 clips never repeat back to back")

	# Playing needs the clips imported by the editor (a fresh clone has none until the project is opened once): skip the play checks with a clear line, never fail them.
	var imported: bool = ResourceLoader.exists("res://assets/audio/batch1/door_wood_open_0.ogg")

	if not imported:
		print("SKIP play checks: the batch 1 clips are not imported yet (open the project in the Godot editor once, then rerun)")
		_check_sites(names)
		return

	# One-shots: play, cooldown on the table group, skip beyond 30 m, voice cap and priority.
	var origin: Vector3 = Vector3.ZERO
	check(slots.play("door_wood_open", Vector3(2, 0, 0), origin), "a near door plays")
	check(not slots.play("door_wood_open", Vector3(40, 0, 0), origin), "a source beyond 30 m is skipped, not played quietly")
	check(slots.play("table_plane", Vector3(2, 0, 0), origin) and not slots.play("table_plane", Vector3(2, 0, 0), origin), "the table cooldown stops a second plane at once")
	stage.playing = 3
	check(not slots.play("wolf_step", Vector3(2, 0, 0), origin), "a creature step (low priority) waits when the voices are full")
	check(slots.play("door_iron_close", Vector3(2, 0, 0), origin), "a door (high priority) still plays when the voices are full")
	stage.playing = 0
	check(slots.loaded_clips > 0 and slots.loaded_bytes > 0, "clips load on first use (%d clips, %.2f MB)" % [slots.loaded_clips, float(slots.loaded_bytes) / 1048576.0])
	check(slots.loaded_clips < clips, "not every clip was loaded by touching a few slots (lazy)")

	# Loop hysteresis: starts inside 40 m, stays on until 45 m.
	slots.loop_near("water_wheel_loop", 1, Vector3(39, 0, 0), origin)
	check(slots.loops_playing() == 1, "the wheel loop starts at 39 m")
	slots.loop_near("water_wheel_loop", 1, Vector3(43, 0, 0), origin)
	check(slots.loops_playing() == 1, "and stays on at 43 m (hysteresis)")
	slots.loop_near("water_wheel_loop", 1, Vector3(46, 0, 0), origin)
	check(slots.loops_playing() == 0, "and stops past 45 m")
	slots.loop_near("water_wheel_loop", 2, Vector3(43, 0, 0), origin)
	check(slots.loops_playing() == 0, "a wheel first met at 43 m does not start")

	_check_sites(names)


func _check_sites(names: Array) -> void:
	_check_ambience()
	# Call sites and JSON agree. Literal slot names in code must exist; computed names are checked from their data.
	var used: Dictionary = {}
	var pattern: RegEx = RegEx.new()
	pattern.compile("slots\\.play\\(\"([a-z_]+)\"")

	for path in SOURCES:
		for hit in pattern.search_all(FileAccess.get_file_as_string(path)):
			used[hit.get_string(1)] = true

	for slot in used:
		check(names.has(slot), "code plays slot %s: it is in the JSON" % slot)

	var doors: Dictionary = {}

	for state in StructureLook.table():
		if StructureLook.look_of(int(state)) in ["door_shut", "door_open"]:
			doors[StructureLook.material_of(int(state))] = true

	for material in doors:
		check(material != "" and names.has("door_%s_open" % material) and names.has("door_%s_close" % material), "door material '%s' has open and close slots" % material)

	for kind in AnimalView.KIND_OF_SPECIES.values():
		var slot: String = "rabbit_hop" if kind == "rabbit" else "%s_step" % kind
		check(names.has(slot), "animal kind %s maps to slot %s" % [kind, slot])

	var unused: Array = []

	for slot in names:
		if not used.has(slot) and not str(slot).begins_with("door_") and not str(slot).ends_with("_step") and slot != "rabbit_hop":
			unused.append(slot)

	print("slots with no call site yet (no event in the game): %s" % ", ".join(PackedStringArray(unused)))
	print("slot sounds test: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# Batch 2 (data/sound/batch2_slots.json): every slot has files that exist, the tag rules pick the right bed and one-shots, and the tag words are ones the rules know.
func _check_ambience() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Ambience.SLOTS_PATH))
	var slots: Dictionary = parsed["slots"]
	check(slots.size() >= 17, "the JSON lists the batch 2 slots (%d)" % slots.size())
	var known_layers: Array = ["weather_bed", "time_bed", "positional", "oneshot"]
	var known_near: Array = ["any", "pond", "sea_edge", "lava"]
	var known_altitude: Array = ["any", "below_800m", "below_1500m", "above_300m", "sea_level"]
	var known_time: Array = ["day", "night", "day_and_night", "dusk_and_night"]

	for slot in slots:
		var row: Dictionary = slots[slot]
		var found: int = 0

		for path in row["files"]:
			found += 1 if FileAccess.file_exists(str(path)) else 0

		check(found >= 1 and found == row["files"].size(), "batch 2 slot %s: all %d files exist" % [slot, row["files"].size()])
		var tags: Dictionary = row["tags"]
		check(known_layers.has(row["layer"]) and known_near.has(tags["near_water"]) and known_altitude.has(tags["altitude"]) and known_time.has(tags["time"]), "batch 2 slot %s: layer and tag words are known to the rules" % slot)

	var summer_forest: Dictionary = {"season": "summer", "time": "day", "biomes": ["temperate_forest", "woodland"], "water": 0.0, "height": 40.0}
	check(Ambience.choose_bed(slots, "weather_bed", summer_forest) == "bed_forest_day", "a summer forest day gets the forest day bed")
	var winter_forest: Dictionary = summer_forest.duplicate()
	winter_forest["season"] = "winter"
	check(Ambience.choose_bed(slots, "weather_bed", winter_forest) == "bed_forest_winter", "winter gets the winter forest bed")
	var night: Dictionary = summer_forest.duplicate()
	night["time"] = "night"
	check(Ambience.choose_bed(slots, "time_bed", night) == "bed_crickets", "a warm night over trees or grass gets crickets (the narrower slot)")
	night["season"] = "winter"
	check(Ambience.choose_bed(slots, "time_bed", night) == "bed_night", "a winter night gets the general night bed")
	check(Ambience.choose_bed(slots, "time_bed", summer_forest) == "", "no time bed by day")
	var beach: Dictionary = {"season": "summer", "time": "day", "biomes": ["beach"], "water": 0.8, "height": 2.0}
	check(Ambience.choose_bed(slots, "weather_bed", beach) == "bed_surf", "a beach at sea level gets the surf bed")
	beach["height"] = 30.0
	check(Ambience.choose_bed(slots, "weather_bed", beach) != "bed_surf", "and not the same water 30 m up")
	var canyon: Dictionary = {"season": "summer", "time": "day", "biomes": ["canyon"], "water": 0.0, "height": 120.0}
	check(Ambience.choose_bed(slots, "weather_bed", canyon) == "bed_canyon_wind" and Ambience.matching(slots, "oneshot", canyon).has("canyon_echo"), "a forced canyon gets its wind and its echo")
	var day_birds: Array = Ambience.matching(slots, "oneshot", summer_forest)
	check(day_birds.has("bird_tweet") and day_birds.has("bird_whistle") and not day_birds.has("owl_hoot") and not day_birds.has("frog_croak"), "day in a summer forest: birds, no owls, no frogs")
	var pond_dusk: Dictionary = {"season": "summer", "time": "dusk", "biomes": ["grassland"], "water": 0.9, "height": 20.0}
	check(Ambience.matching(slots, "oneshot", pond_dusk).has("frog_croak") and Ambience.matching(slots, "positional", pond_dusk).has("bed_pond"), "dusk by a pond: frogs and the pond bed")
	var autumn_pond: Dictionary = pond_dusk.duplicate()
	autumn_pond["season"] = "winter"
	check(not Ambience.matching(slots, "positional", autumn_pond).has("bed_pond"), "a frozen winter pond has no pond bed")
	check(Ambience.time_class(12.0, "summer") == "day" and Ambience.time_class(20.5, "summer") == "dusk" and Ambience.time_class(23.0, "summer") == "night" and Ambience.time_class(3.0, "winter") == "night", "time classes follow the season's sunrise and sunset")
	check(Ambience.biomes_for(0.8, 0.1, 0.0, 50.0).has("woodland") and Ambience.biomes_for(0.0, 0.9, 0.0, 50.0) == ["grassland"] and Ambience.biomes_for(0.0, 0.0, 0.9, 2.0).has("beach") and Ambience.biomes_for(0.0, 0.0, 0.0, 50.0, "canyon") == ["canyon"], "biomes the client can read from trees, grass and water, plus a forced one")
	for call_name in Ambience.REPLACES:
		check(slots.has(call_name), "ambient call %s that the slots take over has a slot" % call_name)

	var layers_seen: Dictionary = {}

	for slot in slots:
		layers_seen[slots[slot]["layer"]] = true

	check(layers_seen.size() == 4, "all four layers are used by the batch")
