extends SceneTree

# Other players' work is heard where it happens (protocol 156, src/stream/server_action_cues.gd; Dave 23 Nov 2026: sound "very broad and hard
# to pinpoint"). Server: a blow, a pick and a craft each send one cue to the other players within its earshot (never the one who did it),
# at the point struck or the hands in front of the body, naming the tool (a knife on a carcass: flesh, where it lies); a craft again every
# CRAFT_EVERY_MS while it is worked; a miss, a ground point out of reach and a second cue within GAP_MS send
# nothing. Client: SoundStage.other_action plays the cue as a positional voice there (the own clips: hit_sounds, harvest_sounds, the craft work).
#   godot --headless --path . --script res://src/worldgen/tools/test_action_cues.gd

const Cues := preload("res://src/stream/server_action_cues.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const SoundStage := preload("res://src/client/sound_stage.gd")
const HitSounds := preload("res://src/client/hit_sounds.gd")
const HarvestSounds := preload("res://src/client/harvest_sounds.gd")
const ItemSounds := preload("res://src/client/item_sounds.gd")
const SpearSounds := preload("res://src/client/spear_sounds.gd")
const PlacedSounds := preload("res://src/client/placed_sounds.gd")
const InteriorSounds := preload("res://src/client/interior_sounds.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


class StubTable extends RefCounted:
	func id_of(number: int) -> String:
		return {11: "stone_pickaxe", 12: "stone_axe"}.get(number, "")

	func entry(id: String) -> Dictionary:
		return {"stone_pickaxe": {"tool_class": "pick"}, "stone_axe": {"tool_class": "axe"}}.get(id, {})


class StubItems extends RefCounted:
	var table: StubTable = StubTable.new()
	var pos: Dictionary = {}
	var held: Dictionary = {}
	var kinds: Dictionary = {}

	func peer_ids() -> Array:
		return pos.keys()

	func position_of(peer: int) -> Variant:
		return pos.get(peer, null)

	func held_number(peer: int) -> int:
		return int(held.get(peer, 0))

	func struct_kind_of(id: int) -> String:
		return str(kinds.get(id, ""))

	var open: Dictionary = {}     # peer -> container open (server_items _chest_viewer)
	var totals: Dictionary = {}   # container id -> things in it

	func open_store_of(peer: int) -> int:
		return int(open.get(peer, 0))

	func store_total(id: int) -> int:
		return int(totals.get(id, -1))

	func item_pos_of(id: int) -> Variant:
		if kinds.has(id):
			return Vector3(1, 0, 1)

		return null


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_server_checks()
	_client_checks()
	print("action cues: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _server_checks() -> void:
	var items: StubItems = StubItems.new()
	items.pos = {1: Vector3(0, 1, 0), 2: Vector3(10, 1, 0), 3: Vector3(100, 1, 0), 4: Vector3(0, 1, 28)}
	items.held = {1: 12}
	items.kinds = {77: "carcass", 78: "log", 79: "iron_chest", 80: "wooden_barrel", 81: "stone_wall"}
	var cues = Cues.new()
	cues.items = items
	var clock: Array = [1000]
	cues.now_ms = func() -> int: return int(clock[0])
	cues.yaw_of = func(_peer: int) -> float: return PI / 2.0   # facing -X
	var got: Array = []
	cues.send_cue = func(receiver: int, about: int, cue: int, detail: int, at: Vector3) -> void: got.append([receiver, about, cue, detail, at])

	# An axe blow on a tree: heard by 2 (10 m) and 4 (28 m), not by 1 itself nor 3 (100 m), at the hands (0.8 m in front, 0.3 m up).
	cues.note_action(1, Net.ACT_HIT, 5, 3, 4, Vector3(13, 0, 0))
	var to: Array = got.map(func(g: Array) -> int: return int(g[0]))
	to.sort()
	check(to == [2, 4], "a blow goes to the players within earshot only, not the one who struck (%s)" % str(to))
	check(not got.is_empty() and int(got[0][1]) == 1 and int(got[0][2]) == Cues.CUE_BLOW and int(got[0][3]) == 0 * 8 + Cues.MATERIALS.find("wood"), "an axe on wood, about player 1 (%s)" % str(got[0] if not got.is_empty() else []))
	check(not got.is_empty() and (got[0][4] as Vector3).is_equal_approx(Vector3(-Cues.HANDS_OUT_M, 1.0 + Cues.HANDS_UP_M, 0.0)), "at the hands in front along the facing (%s)" % str(got[0][4] if not got.is_empty() else null))

	# Too soon after the last: nothing.
	got.clear()
	clock[0] += Cues.GAP_MS - 10
	cues.note_action(1, Net.ACT_HIT, 5, 3, 4, Vector3.ZERO)
	check(got.is_empty(), "a second cue within %d ms is held back" % Cues.GAP_MS)

	# A pick on a boulder, then on the ground at the point struck; a miss sends nothing, a knife on a carcass is flesh.
	items.held[1] = 11
	clock[0] += 200
	got.clear()
	cues.note_action(1, Net.ACT_HIT, 9, Net.HIT_BOULDER, 1, Vector3.ZERO)
	check(got.size() == 2 and int(got[0][3]) == 1 * 8 + Cues.MATERIALS.find("stone"), "a pick on a boulder rings as stone (%s)" % str(got))
	clock[0] += 200
	got.clear()
	cues.note_action(1, Net.ACT_MINE, 1, 0, 0, Vector3(2, 0.5, 3))
	check(got.size() == 2 and int(got[0][3]) == 8 + Cues.MATERIALS.find("ground") and (got[0][4] as Vector3).is_equal_approx(Vector3(2, 0.5, 3)), "a blow on the ground is at the point struck (%s)" % str(got))
	clock[0] += 200
	got.clear()
	cues.note_action(1, Net.ACT_MINE, 1, 0, 0, Vector3(10, 1, 0))
	check(got.is_empty(), "a blow on the ground far from the player (beside another) is not sent (%d)" % got.size())
	clock[0] += 200
	got.clear()
	cues.note_action(1, Net.ACT_MINE, 1, 1, 0, Vector3(2, 0.5, 3))
	cues.note_action(1, Net.ACT_PICKUP, 3, 0, 0, Vector3.ZERO)
	check(got.is_empty(), "a swing at nothing and a pickup send nothing (%d)" % got.size())
	cues.note_action(1, Net.ACT_PROCESS, 77, 0, 0, Vector3(1, 0, 0))
	check(got.size() == 2 and int(got[0][3]) == Cues.MATERIALS.find("flesh") and (got[0][4] as Vector3).is_equal_approx(Vector3(1, Cues.HANDS_UP_M, 1)), "a knife on a carcass is flesh, where the carcass lies (%s)" % str(got))
	clock[0] += 200
	got.clear()
	cues.note_action(1, Net.ACT_PROCESS, 78, 0, 0, Vector3(1, 0, 0))
	check(got.size() == 2 and int(got[0][3]) == 8 + Cues.MATERIALS.find("wood"), "a blow on a loose log is wood (%s)" % str(got))

	# A pick is heard within 30 m, a craft within 25 m: player 4 at 28 m hears the pick, not the craft.
	clock[0] += 200
	got.clear()
	check(cues.cue(1, Cues.CUE_PICK, 42, Vector3(0, 1, 0)), "a pick is sent")
	to = got.map(func(g: Array) -> int: return int(g[0]))
	to.sort()
	check(to == [2, 4] and int(got[0][3]) == 42, "a pick reaches 30 m with the species (%s)" % str(got))
	clock[0] += 200
	got.clear()
	cues.craft_working(1, 7)
	check(got.size() == 1 and int(got[0][0]) == 2 and int(got[0][2]) == Cues.CUE_CRAFT and int(got[0][3]) == 7, "a craft is heard within 25 m only, naming the recipe (%s)" % str(got))
	var crafts: int = 0

	for tick in 40:                                     # 10 s of server craft ticks (0.25 s) while it is worked
		got.clear()
		clock[0] += 250
		cues.craft_working(1, 7)
		crafts += got.size()

	check(crafts == 2, "the craft is heard again as each work clip ends: 2 more in 10 s (%d)" % crafts)
	got.clear()
	clock[0] += 250
	cues.craft_working(1, 8)
	check(got.size() == 1 and int(got[0][3]) == 8, "a new recipe is heard at once (%s)" % str(got))
	clock[0] += 200
	got.clear()
	check(not cues.cue(1, Cues.CUE_PICK, 1, Vector3(NAN, 0, 0)) and got.is_empty(), "a point that is not a number sends nothing")

	# A container (23 Nov 2026), heard within 25 m (player 2, not 4 at 27 m) and only once the server let the action through: a chest's lid
	# opening and shutting, things put in and taken out, at the container; a barrel only its contents.
	var lid_at: Vector3 = Vector3(1, Cues.HANDS_UP_M, 1)
	items.totals = {79: 3, 80: 0}
	var store_cases: Array = [
		[Net.ACT_CHEST_OPEN, 79, 0, true, Cues.STORE_OPEN + Cues.STORE_LID, "a chest opened: its lid"],
		[Net.ACT_CHEST_OPEN, 79, 0, true, -1, "the window already open asked again: no second creak"],
		[Net.ACT_CHEST_PUT, 4, 79, true, Cues.STORE_PUT + Cues.STORE_LID, "something put in the chest"],
		[Net.ACT_CHEST_TAKE, 0, 79, true, Cues.STORE_TAKE + Cues.STORE_LID, "something taken out"],
		[Net.ACT_CHEST_PUT, 4, 79, false, -1, "a put the server refused (a take-only store, an empty slot): nothing moved, nothing heard"],
		[Net.ACT_CHEST_CLOSE, 0, 0, true, Cues.STORE_CLOSE + Cues.STORE_LID, "the chest shut (the close names no container: the one opened)"],
		[Net.ACT_CHEST_CLOSE, 0, 0, true, -1, "a close with nothing open"],
		[Net.ACT_CHEST_PUT, 2, 80, true, Cues.STORE_PUT, "something put in a barrel: no lid"],
		[Net.ACT_CHEST_OPEN, 79, 0, false, -1, "an open the server refused (locked, too far, broken): no lid"],
		[Net.ACT_CHEST_PUT, 4, 81, true, -1, "a put naming a wall or any other thing that is no container"],
		[Net.ACT_CHEST_OPEN, -3, 0, true, -1, "a worn bag (the player's own back)"],
	]

	for c in store_cases:
		clock[0] += 200
		got.clear()
		_store_act(cues, items, int(c[0]), int(c[1]), int(c[2]), bool(c[3]))

		if int(c[4]) < 0:
			check(got.is_empty(), "%s: nothing (%s)" % [c[5], str(got)])
		else:
			check(got.size() == 1 and int(got[0][0]) == 2 and int(got[0][2]) == Cues.CUE_STORE and int(got[0][3]) == int(c[4]) and (got[0][4] as Vector3).is_equal_approx(lid_at), "%s (%s)" % [c[5], str(got)])

	items.open.erase(1)
	items.pos[1] = Vector3(30, 1, 0)                     # however it came through, a chest 29 m off is not this player's
	clock[0] += 200
	got.clear()
	_store_act(cues, items, Net.ACT_CHEST_OPEN, 79, 0, true)
	check(got.is_empty(), "a chest far from the player is not heard opening (%d)" % got.size())
	items.pos[1] = Vector3(0, 1, 0)
	check(cues.store_before(1, Net.ACT_HIT, 0).is_empty(), "any other action takes no store look")
	cues.forget(1)
	check(cues.cue(1, Cues.CUE_PICK, 1, Vector3.ZERO), "forgotten on leaving")


# One container action as terrain_server.gd runs it: the store looked at, the server's action (let through or refused), then the cue.
func _store_act(cues, items: StubItems, kind: int, a: int, b: int, let_through: bool) -> void:
	var before: Array = cues.store_before(1, kind, b)

	if let_through:
		match kind:
			Net.ACT_CHEST_OPEN:
				if a > 0 and items.kinds.has(a):
					items.open[1] = a
			Net.ACT_CHEST_CLOSE:
				items.open.erase(1)
			Net.ACT_CHEST_PUT:
				if items.totals.has(b):
					items.totals[b] += 1
			Net.ACT_CHEST_TAKE:
				if items.totals.has(b):
					items.totals[b] -= 1

	cues.store_after(1, kind, a, b, before)


func _client_checks() -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var stage: SoundStage = SoundStage.new()
	world.add_child(stage)

	for wind in ["_wind_low", "_wind_gust"]:                # set up by setup() in the game; its _exit_tree stops them
		var bed: AudioStreamPlayer = AudioStreamPlayer.new()
		stage.add_child(bed)
		stage.set(wind, bed)

	stage.hits = HitSounds.new()
	stage.add_child(stage.hits)
	stage.hits.setup(stage)
	stage.harvestfx = HarvestSounds.new()
	stage.add_child(stage.harvestfx)
	stage.harvestfx.setup(stage)
	stage.itemfx = ItemSounds.new()
	stage.add_child(stage.itemfx)
	stage.itemfx.setup(stage)
	stage.spear = SpearSounds.new()
	stage.add_child(stage.spear)
	stage.spear.setup(stage)
	stage.interior = InteriorSounds.new()
	stage.add_child(stage.interior)
	stage.interior.setup(stage)
	stage.placed = PlacedSounds.new()
	stage.add_child(stage.placed)
	stage.placed.setup(stage)
	var at: Vector3 = Vector3(5.0, 1.0, -4.0)

	var cases: Array = [
		[Cues.CUE_BLOW, 0 * 8 + Cues.MATERIALS.find("wood"), {}, {}, stage.hits, "an axe on wood"],
		[Cues.CUE_BLOW, 1 * 8 + Cues.MATERIALS.find("stone"), {}, {}, stage.hits, "a pick on stone"],
		[Cues.CUE_BLOW, 0 * 8 + Cues.MATERIALS.find("brush"), {}, {}, stage.hits, "an axe on a bush"],
		[Cues.CUE_PICK, 3, {"name": "blueberry", "yields": ["blueberries"], "shape": "bush"}, {}, stage.harvestfx, "a berry pick"],
		[Cues.CUE_BLOW, Cues.MATERIALS.find("flesh"), {}, {}, stage.spear, "a knife on a carcass"],
		[Cues.CUE_CRAFT, 2, {}, {"id": "stone_axe"}, stage, "a craft's work"],
		[Cues.CUE_STORE, Cues.STORE_OPEN + Cues.STORE_LID, {}, {}, stage.interior, "a chest's lid opening"],
		[Cues.CUE_STORE, Cues.STORE_CLOSE + Cues.STORE_LID, {}, {}, stage.interior, "a chest's lid shutting"],
		[Cues.CUE_STORE, Cues.STORE_PUT, {}, {}, stage.placed, "something put in a barrel"],
		[Cues.CUE_STORE, Cues.STORE_TAKE + Cues.STORE_LID, {}, {}, stage.placed, "something taken out of a chest"],
	]

	for c in cases:
		var host: Node = c[4]
		var before: Array = host.get_children()
		var played: bool = stage.other_action(int(c[0]), int(c[1]), at, c[2], c[3])
		var made: Array = host.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer3D and not before.has(n))
		check(played and made.size() >= 1, "%s plays (%s, %d voices)" % [c[5], str(played), made.size()])

		for voice in made:
			var v: AudioStreamPlayer3D = voice
			check(v.global_position.is_equal_approx(at) and v.max_distance > 0.0 and v.attenuation_model != AudioStreamPlayer3D.ATTENUATION_DISABLED and v.is_in_group("world_sounds"),
					"%s: positional at the place, with falloff and a reach (unit %.1f m, reach %.0f m), in world_sounds" % [c[5], v.unit_size, v.max_distance])

	check(stage.others_actions == cases.size(), "counted (%d)" % stage.others_actions)
	check(not stage.other_action(9, 0, at) and not stage.other_action(Cues.CUE_CRAFT, 1, at), "an unknown cue or a recipe not known plays nothing")
	check(not stage.other_action(Cues.CUE_STORE, Cues.STORE_OPEN, at), "a barrel opening has no sound of its own")
	check(Cues.CUE_BLOW == SoundStage.CUE_BLOW and Cues.CUE_PICK == SoundStage.CUE_PICK and Cues.CUE_CRAFT == SoundStage.CUE_CRAFT and Cues.CUE_STORE == SoundStage.CUE_STORE,
			"the client reads the server's cue numbers")
