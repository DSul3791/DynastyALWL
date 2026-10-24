extends SceneTree

# Kathleen's sound slots through SlotSounds: every slot has a clip, no clip twice in a row, cooldown and priority under the voice cap, and the call
# sites and the JSON agree both ways (a slot name used in code must exist; a door material in structures.json must have its open and close slots).

const SlotSounds := preload("res://src/client/slot_sounds.gd")
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
			found += 1 if ResourceLoader.exists(str(path)) else 0

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
