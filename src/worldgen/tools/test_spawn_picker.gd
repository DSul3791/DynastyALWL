extends SceneTree

# The spawn picker (Stage E M1 step 4, docs/water/stage_e_readers_design.md 6e) on a small made-up valley: a river runs north-south down x 400,
# a floodplain 1 m over it on its east bank, a terrace 6 m over it beyond, a steep bank and a sea strip in the west. The pick must be dry,
# flat, over the floodplain, a short walk from the river and the nearest such spot to the bay head; without a river nothing passes. The
# shared reader: a starter section without spawn_picked gives OVERRIDE and no town shift, one with it gives the picked spot and the shift.
#   godot --headless --path . --script res://src/worldgen/tools/test_spawn_picker.gd

const PickerScript := preload("res://src/worldgen/tile/spawn_picker.gd")
const SpawnPointScript := preload("res://src/shared/spawn_point.gd")

const N := 160
const S := 8.0

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


# x in metres -> ground height and water class.
func valley(river: bool) -> Dictionary:
	var heights: PackedFloat32Array = PackedFloat32Array()
	var water: PackedByteArray = PackedByteArray()
	var surface: PackedFloat32Array = PackedFloat32Array()
	var flow: PackedFloat32Array = PackedFloat32Array()
	heights.resize(N * N)
	water.resize(N * N)
	surface.resize(N * N)
	flow.resize(N * N)

	for j in N:
		for i in N:
			var x: float = float(i) * S
			var k: int = j * N + i
			var h: float = 30.0
			var cls: int = 0

			if x < 80.0:
				h = 0.0
				cls = 1                                     # sea
			elif x < 160.0:
				h = lerpf(0.0, 30.0, (x - 80.0) / 80.0)     # steep bank up from the sea
			elif x < 392.0:
				h = 30.0                                    # west terrace (far from the bay head)
			elif x < 408.0:
				h = 9.0 if river else 30.0                  # the river bed
				cls = 3 if river else 0
			elif x < 520.0:
				h = 11.0                                    # floodplain: 1 m over the water
			elif x < 560.0:
				h = lerpf(11.0, 16.0, (x - 520.0) / 40.0)   # rise to the terrace
			else:
				h = 16.0                                    # east terrace: 6 m over the water

			heights[k] = h
			water[k] = cls
			surface[k] = 10.0 if cls == 3 else (0.0 if cls == 1 else NAN)
			flow[k] = 1000000.0 if cls == 3 else 0.0

	return {"heights": heights, "water": water, "surface": surface, "flow": flow, "n": N, "spacing": S, "origin": Vector2(1000.0, 2000.0)}


func _init() -> void:
	var rules: Dictionary = {"search_m": 2000.0}
	var bay: Vector2 = Vector2(1000.0 + 500.0, 2000.0 + 640.0)   # the bay head on the floodplain, east of the river
	var maps: Dictionary = valley(true)
	var r: Dictionary = PickerScript.pick(maps, bay, rules)
	var x: float = float(r["x"]) - 1000.0
	check(bool(r["ok"]), "a spawn is picked in the valley")
	check(x >= 560.0, "it is on the east terrace, not the floodplain 1 m over the river or the west bank (x %.0f)" % x)
	check(x - 408.0 <= 400.0 and x - 408.0 >= 40.0, "a short walk from the river (%.0f m)" % (x - 408.0))
	check(absf(float(r["ground"]) - 16.0) < 0.01, "on dry ground 6 m over the water (%.1f m)" % float(r["ground"]))
	check(absf(x - 560.0) <= 2.0 * S + 30.0 + S, "the nearest such spot to the bay head (x %.0f)" % x)
	var again: Dictionary = PickerScript.pick(maps, bay, rules)
	check(again["x"] == r["x"] and again["z"] == r["z"], "the pick is stable")

	# No river and no lake: no fresh water within a walk, so nothing passes.
	var none: Dictionary = PickerScript.pick(valley(false), bay, rules)
	check(not bool(none["ok"]) and int(none["candidates"]) == 0, "without fresh water nearby nothing passes (%d)" % int(none["candidates"]))

	# The shared reader.
	check(SpawnPointScript.from_starter({"spawn_point": [1.0, 2.0, 3.0]}) == SpawnPointScript.OVERRIDE, "a starter section without spawn_picked keeps OVERRIDE")
	SpawnPointScript.set_current(SpawnPointScript.from_starter({}))
	check(SpawnPointScript.town_shift() == Vector2.ZERO, "and the town does not move")
	SpawnPointScript.set_current(SpawnPointScript.from_starter({"spawn_picked": [53400.0, 31.0, 68000.0]}))
	check(SpawnPointScript.current() == Vector2(53400.0, 68000.0) and SpawnPointScript.town_shift() == Vector2(104.0, -80.0), "a picked spawn is the spawn and the town moves with it (%s)" % str(SpawnPointScript.town_shift()))
	SpawnPointScript.set_current(SpawnPointScript.OVERRIDE)

	print("test_spawn_picker: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
