extends SceneTree

# Sounds that were missing from the first hours of play (23 Nov 2026, the coordinator's pass: silent, wrong, heard only by the doer, or not
# from where it happens; Dave 23 Nov 2026: sound "very broad and hard to pinpoint"):
# - a lit kiln, smelter or smithy crackles where it stands (fire_sounds.gd station_fire, sync_world); its bellows or a smithy's flare roar up;
# - an iron or steel piece set in place clanks as metal (placed_sounds.gd "metal"), not the soft thump;
# - another player swimming by is heard stroking where they swim (player_view.gd stroked, swim_sounds.gd stroke_at);
# - a mouthful of water gulps (inventory_view.gd _on_vitals); food and drinks from the pack stay silent (Dave 17 Nov 2026);
# - another player drawing a bow is heard creaking at their shoulder (player_view.gd drew), and their burning torch or lantern flutters at
#   their hand, the two nearest within 10 m (player_view.gd flames_near, flame_sounds.gd hear_others);
# - a fish's bite splashes at the float, where the line went in (held_item.gd float_point), not 1.5 m in front of the angler.
#   godot --headless --path . --script res://src/worldgen/tools/test_world_sound_gaps.gd

const SoundStage := preload("res://src/client/sound_stage.gd")
const FireSounds := preload("res://src/client/fire_sounds.gd")
const PlacedSounds := preload("res://src/client/placed_sounds.gd")
const SwimSounds := preload("res://src/client/swim_sounds.gd")
const PlayerView := preload("res://src/client/player_view.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")
const InventoryView := preload("res://src/client/inventory_view.gd")
const FlameSounds := preload("res://src/client/flame_sounds.gd")
const HeldItem := preload("res://src/client/held_item.gd")

var failures: int = 0


class VitalsOnly extends "res://src/client/inventory_view.gd":
	func _place_vitals() -> void:
		pass   # the bars are drawn by setup's layer in the game; only the sounds are checked here


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var stage: SoundStage = SoundStage.new()
	world.add_child(stage)

	for wind in ["_wind_low", "_wind_gust"]:                # set up by setup() in the game; its _exit_tree stops them
		var bed: AudioStreamPlayer = AudioStreamPlayer.new()
		stage.add_child(bed)
		stage.set(wind, bed)

	_stations(stage)
	_metal(stage)
	_strokes(world, stage)
	_drinks()
	_others_hands(world, stage)
	_float()
	print("world sound gaps: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _stations(stage: SoundStage) -> void:
	check(FireSounds.station_fire({"fill": 2, "lit": true}) == FireSounds.STATION_COALS, "a lit kiln or smelter crackles small")
	check(FireSounds.station_fire({"fill": 2, "lit": true, "bellows": 1}) == FireSounds.STATION_ROAR, "its bellows worked: it roars up")
	check(FireSounds.station_fire({"fill": 0, "forge": 1}) == FireSounds.STATION_COALS and FireSounds.station_fire({"fill": 0, "forge": 2}) == FireSounds.STATION_ROAR,
			"a smithy's red coals crackle, its flare roars")
	check(FireSounds.station_fire({"fill": 3, "lit": false}) == 0.0 and FireSounds.station_fire({"fill": 0, "forge": 0}) == 0.0, "a cold station is silent")
	check(FireSounds.station_fire({"lit": true}) == 0.0, "a row that is not a station store (a lantern's lit) is no fire")
	var fire: FireSounds = FireSounds.new()
	stage.add_child(fire)
	fire.setup(stage)
	var kiln: Vector3 = Vector3(3.0, 0.0, 4.0)
	fire.sync_world({11: {"state": 188, "pos": kiln, "fill": 2, "lit": true}, 12: {"state": 188, "pos": kiln + Vector3(5, 0, 0), "fill": 1, "lit": false},
		13: {"state": 1, "pos": Vector3.ZERO, "fill": 1, "lit": true}})
	var listed: Array = fire._fires.map(func(f: Dictionary) -> int: return int(f["id"]))
	listed.sort()
	check(listed == [11, 13], "the lit kiln is a fire to hear, the cold one is not, a campfire once only (%s)" % str(listed))
	var kiln_fire: Array = fire._fires.filter(func(f: Dictionary) -> bool: return int(f["id"]) == 11)
	check(kiln_fire.size() == 1 and bool(kiln_fire[0]["lit"]) and not bool(kiln_fire[0]["open"]) and (kiln_fire[0]["at"] as Vector3) == kiln, "lit, under its own dome (no rain sizzle), where it stands")


func _metal(stage: SoundStage) -> void:
	var placed: PlacedSounds = PlacedSounds.new()
	stage.add_child(placed)
	placed.setup(stage)
	var metal_states: Array = StructureLook.table().keys().filter(func(state: int) -> bool: return StructureLook.sound_of(state) == "metal")
	check(metal_states.size() > 0, "iron and steel pieces have the metal place sound (%d)" % metal_states.size())
	var at: Vector3 = Vector3(-2.0, 0.0, 6.0)
	var count: int = placed.get_child_count()
	check(placed.place("metal", at) and int(placed.played.get("place_metal", 0)) == 1 and placed.last.begins_with("place_metal") and placed.get_child_count() == count + 1,
			"an iron piece set in place clanks (%s)" % placed.last)
	var voice: AudioStreamPlayer3D = placed.get_child(count) as AudioStreamPlayer3D
	check(voice != null and voice.stream != null and voice.global_position.is_equal_approx(at) and voice.stream.resource_path.contains("item_drop_metal"),
			"the metal clank, where the piece stands (%s)" % (voice.stream.resource_path if voice != null and voice.stream != null else "none"))


func _strokes(world: Node3D, stage: SoundStage) -> void:
	var view = PlayerView.new()
	world.add_child(view)
	var node: Node3D = Node3D.new()
	world.add_child(node)
	node.position = Vector3(6.0, 0.5, -2.0)
	var heard: Array = []
	view.stroked.connect(func(where: Vector3) -> void: heard.append(where))
	var stepped: Array = []
	view.stepped.connect(func(where: Vector3, _gait: int, _crouched: bool) -> void: stepped.append(where))
	var cases: Array = [[2.0, 10.0, 3], [4.0, 10.0, 5], [0.3, 10.0, 0], [2.0, PlayerView.STEP_HEAR_M + 5.0, 0]]

	for c in cases:
		heard.clear()
		var b: Dictionary = {"node": node, "state": PlayerView.SWIM}

		for n in 60:                                                   # 3 s
			view._count_steps(b, Vector3(float(c[0]), 0.0, 0.0), 0.05, float(c[1]))

		var at_body: bool = heard.all(func(where: Vector3) -> bool: return where.is_equal_approx(node.global_position))
		check(heard.size() == int(c[2]) and at_body, "another player swimming %.1f m/s at %.0f m: %d strokes where they swim (heard %d)" % [c[0], c[1], c[2], heard.size()])

	check(stepped.is_empty(), "and no footsteps while swimming (%d)" % stepped.size())
	var swim: SwimSounds = SwimSounds.new()
	stage.add_child(swim)
	swim.setup(stage)
	var count: int = swim.get_child_count()
	var at: Vector3 = Vector3(8.0, 0.2, -3.0)
	check(swim.stroke_at(at) and swim.others_strokes == 1, "the stroke plays")
	var made: Array = swim.get_children().slice(count).filter(func(n: Node) -> bool: return n is AudioStreamPlayer3D)
	check(made.size() == 1 and (made[0] as AudioStreamPlayer3D).global_position.is_equal_approx(at) and (made[0] as AudioStreamPlayer3D).is_in_group("world_sounds")
			and (made[0] as AudioStreamPlayer3D).max_distance == SwimSounds.OTHER_STROKE_REACH_M, "positional, where they swim, with a reach")
	var played: int = 1

	while stage.other_step_room() and played < 50:
		played += int(swim.stroke_at(at))

	check(not stage.other_step_room() and not swim.stroke_at(at) and played == SoundStage.OTHER_STEP_VOICES,
			"strokes count with the other players' steps: at most %d at once (%d)" % [SoundStage.OTHER_STEP_VOICES, played])


func _drinks() -> void:
	var view = VitalsOnly.new()
	var said: Array = []
	view.eat_event = func(what: String) -> void: said.append(what)
	# [eaten from the pack, a mouthful at the water just asked, hunger before, after, thirst before, after, sounds, what]
	var cases: Array = [["fruit_juice", false, 50, 50, 50, 62, [], "fruit juice from the pack is silent (Dave 17 Nov 2026: no sound for eating or drinking food)"],
		["blueberries", false, 50, 60, 50, 50, ["blueberries"], "berries are handed on as before (silent in ItemSounds)"],
		["", true, 50, 50, 50, 62, ["drink"], "a mouthful at the water or from a waterskin gulps"],
		["", false, 50, 50, 50, 62, [], "thirst rising with nothing asked is no gulp"]]

	for c in cases:
		said.clear()
		view._eat_item = str(c[0])
		view._drink_msec = Time.get_ticks_msec() if bool(c[1]) else 0
		view.hunger = int(c[2])
		view.thirst = int(c[4])
		view._on_vitals(int(c[3]), view.health, 0, int(c[5]), 0, 0)
		check(said == c[6], "%s (%s)" % [c[7], str(said)])

	view.free()


func _others_hands(world: Node3D, stage: SoundStage) -> void:
	var view = PlayerView.new()
	world.add_child(view)
	var node: Node3D = Node3D.new()
	world.add_child(node)
	node.position = Vector3(3.0, 1.0, 0.0)
	view._bodies[7] = {"node": node, "samples": [], "more": 0}
	var drawn: Array = []
	view.drew.connect(func(where: Vector3) -> void: drawn.append(where))
	var row: Callable = func(more: int) -> void:
		view.on_rows(PackedInt32Array([7]), PackedVector3Array([node.position]), PackedFloat32Array([0.0]), PackedByteArray([0]), PackedInt32Array([0]),
				PackedInt32Array([1000 + drawn.size() * 10 + more]), PackedInt32Array([0]), PackedByteArray([more]))
	row.call(PlayerView.MORE_BOW_DRAWN)
	row.call(PlayerView.MORE_BOW_DRAWN)
	row.call(0)
	row.call(PlayerView.MORE_BOW_DRAWN)
	check(drawn.size() == 2 and (drawn[0] as Vector3).is_equal_approx(node.position + Vector3(0.0, PlayerView.DRAW_UP_M, 0.0)), "another player drawing a bow: one creak each time the string is pulled, at the shoulder (%d)" % drawn.size())
	view._bodies[7]["more"] = PlayerView.MORE_LIT
	view._bodies[7]["held_kind"] = "torch"
	var far: Node3D = Node3D.new()
	world.add_child(far)
	far.position = Vector3(30.0, 1.0, 0.0)
	view._bodies[8] = {"node": far, "samples": [], "more": PlayerView.MORE_LIT, "left_kind": "lantern"}
	var near: Array = view.flames_near(Vector3.ZERO, FlameSounds.OTHERS_REACH_M)
	check(near.size() == 1 and str(near[0][1]) == "torch", "a burning torch 3 m off is near, a lantern 30 m off is not (%s)" % str(near))
	check(view.flames_near(Vector3(29.0, 1.0, 0.0), FlameSounds.OTHERS_REACH_M).map(func(f: Array) -> String: return str(f[1])) == ["lantern"], "and the lantern is heard by one beside it")
	var flame: FlameSounds = FlameSounds.new()
	stage.add_child(flame)
	flame.setup(stage)
	var at: Vector3 = Vector3(2.0, 1.5, 1.0)
	flame.hear_others([[at, "torch"], [at + Vector3(1, 0, 0), "lantern"], [at + Vector3(2, 0, 0), "torch"]])
	var loops: Array = flame.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer3D)
	check(flame.others_heard == FlameSounds.OTHERS_MOST and loops.size() == FlameSounds.OTHERS_MOST and (loops[0] as AudioStreamPlayer3D).global_position.is_equal_approx(at)
			and (loops[0] as AudioStreamPlayer3D).playing, "the two nearest flames flutter where they are carried (%d)" % flame.others_heard)
	flame.hear_others([[at + Vector3(0, 0, 4), "torch"]])
	check(flame.others_heard == 1 and (flame._other_loops[0][0] as AudioStreamPlayer3D).global_position.is_equal_approx(at + Vector3(0, 0, 4)), "a carried torch's flutter moves with it, the rest stop")
	flame.hear_others([[at, "torch"], [at + Vector3(1, 0, 0), "torch"]])
	var second: AudioStreamPlayer3D = flame._other_loops[1][0]
	flame.hear_others([[at, "lantern"], [at + Vector3(1, 0, 0), "torch"]])
	var kinds: Array = flame._other_loops.map(func(l: Array) -> String: return str(l[1]))
	flame.hear_others([[at, "lantern"], [at + Vector3(1, 0, 0), "torch"]])
	var steady: bool = flame._other_loops.size() == 2 and flame._other_loops.map(func(l: Array) -> String: return str(l[1])) == ["lantern", "torch"]
	check(kinds == ["lantern", "torch"] and steady and second.is_queued_for_deletion() == true,
			"a lantern carrier coming nearest: each loop plays its own flame's clip, and stays put on the next look (%s)" % str(kinds))
	flame.hear_others([])
	check(flame.others_heard == 0, "none near: silent")
	view._bodies.clear()   # stand-in bodies with no rig: the view's frame must not draw them


func _float() -> void:
	var held = HeldItem.new()
	var feet: Vector3 = Vector3(10.0, 5.0, 10.0)
	check(not held.float_point(feet).is_finite(), "no cast: no float")
	held._cast_at = Vector3(13.0, 6.5, 10.0)
	held._cast_msec = Time.get_ticks_msec()
	check(held.float_point(feet).is_equal_approx(Vector3(13.0, 4.2, 10.0)), "a bite splashes at the float, where the line went in (%s)" % str(held.float_point(feet)))
	check(not held.float_point(feet + Vector3(20.0, 0.0, 0.0)).is_finite(), "an angler who walked off: back to in front of them")
	held._cast_msec = Time.get_ticks_msec() - HeldItem.CAST_KEEP_MS - 1
	check(not held.float_point(feet).is_finite(), "an old cast is forgotten")
	held.free()
