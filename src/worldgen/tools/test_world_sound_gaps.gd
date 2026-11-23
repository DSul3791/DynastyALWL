extends SceneTree

# Sounds that were missing from the first hours of play (23 Nov 2026, the coordinator's pass: silent, wrong, heard only by the doer, or not
# from where it happens; Dave 23 Nov 2026: sound "very broad and hard to pinpoint"):
# - a lit kiln, smelter or smithy crackles where it stands (fire_sounds.gd station_fire, sync_world); its bellows or a smithy's flare roar up;
# - an iron or steel piece set in place clanks as metal (placed_sounds.gd "metal"), not the soft thump;
# - another player swimming by is heard stroking where they swim (player_view.gd stroked, swim_sounds.gd stroke_at);
# - a drink eaten from the pack (fruit juice, a tea, a soup) gulps (inventory_view.gd _on_vitals: thirst rose after the item), as a mouthful
#   at the water or from a waterskin does; one gulp when both would.
#   godot --headless --path . --script res://src/worldgen/tools/test_world_sound_gaps.gd

const SoundStage := preload("res://src/client/sound_stage.gd")
const FireSounds := preload("res://src/client/fire_sounds.gd")
const PlacedSounds := preload("res://src/client/placed_sounds.gd")
const SwimSounds := preload("res://src/client/swim_sounds.gd")
const PlayerView := preload("res://src/client/player_view.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")
const InventoryView := preload("res://src/client/inventory_view.gd")

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
	var cases: Array = [["fruit_juice", 50, 50, 50, 62, ["drink"], "fruit juice gulps"],
		["blueberries", 50, 60, 50, 50, ["blueberries"], "berries are eaten as before (silent: no chewing clip)"],
		["", 50, 50, 50, 62, [], "thirst rising with nothing eaten from the pack is not a gulp here (the water's edge has its own)"]]

	for c in cases:
		said.clear()
		view._eat_item = str(c[0])
		view.hunger = int(c[1])
		view.thirst = int(c[3])
		view._on_vitals(int(c[2]), view.health, 0, int(c[4]), 0, 0)
		check(said == c[5], "%s (%s)" % [c[6], str(said)])

	said.clear()
	view._eat_item = "fruit_juice"
	view._drink_msec = Time.get_ticks_msec()             # a mouthful at the water just before
	view.thirst = 50
	view._on_vitals(view.hunger, view.health, 0, 62, 0, 0)
	check(said == ["drink"], "a drink from the pack and a mouthful at the water in one rise: one gulp (%s)" % str(said))

	view.free()
