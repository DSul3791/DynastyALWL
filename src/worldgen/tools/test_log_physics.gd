extends SceneTree

# Loose logs are real physics (Dave 16 Nov 2026: "I just want normal physics to work for logs. they should fall and roll like normal logs would";
# "If I walk into a log I should collide and at the same time I should push the log. the log will stop me but I should be able to push against it.
# it might stop me going up hill but I should be able to roll it on the flat or downhill. and sprinting should push harder"; "if you 1/4 into the log
# it will turn and push"). TREE_WOOD_TOOLS_DESIGN.md s5 "Rolling", W-31; server_items.gd _roll_tick, log_physics.gd, lying_logs.gd.
# The server's log space is stepped by the engine, so every case here waits real physics frames (about 40 s in all).
#   godot --headless --path . --script res://src/worldgen/tools/test_log_physics.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const LyingLogs := preload("res://src/shared/lying_logs.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DT := 1.0 / 60.0
const WALK := 3.2      # terrain_client WALK_SPEED
const SPRINT := 9.0    # terrain_client RUN_SPEED
const P_R := 0.35      # the walker's capsule (terrain_client _make_player)
const P_H := 1.8

var failures: int = 0
var worst_sink: float = 0.0     # the deepest any log's underside went into the ground, over every step of every case
var worst_case: String = ""     # the case it was in
var case_name: String = ""
var worst_overlap: float = 0.0  # the deepest a walker stood inside a log after its move was corrected


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String, ground: Callable):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_carry = func(_p, _id): pass
	items.send_notice = func(_p, _text): pass
	items.ground_height = ground
	items.game_seconds = func(): return 5000.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "logphysics01")
	items.report_position(1, Vector3(0.0, 50.0, 300.0))   # far off until a case walks
	return items


func drop(w, item: String, at: Vector3, turn: float) -> int:
	var id: int = w._next_id
	w.drop_in_world(w.table.number_of(item), 1, at, 0, 0.0, turn)
	return id if w._items.has(id) else 0


func centre(w, id: int) -> Vector3:
	return w._items[id]["pos"] + Vector3(0.0, w._log_r(w._items[id]), 0.0)


func axis(w, id: int) -> Vector3:
	var it: Dictionary = w._items[id]
	return LyingLogs.basis_of(float(it.get("rot_y", 0.0)), float(it.get("pitch", 0.0)), float(it.get("spin", 0.0))) * Vector3.RIGHT


# The underside of a log at its middle and both ends against the ground: the most it sinks in (0 when clear).
func sink(w, id: int) -> float:
	var r: float = w._log_r(w._items[id])
	var c: Vector3 = centre(w, id)
	var a: Vector3 = axis(w, id) * (LyingLogs.LOG_HALF_M - r)
	var worst: float = 0.0

	for p in [c, c + a, c - a]:
		var g: float = float(w.ground_height.call(p.x, p.z))
		worst = maxf(worst, g - (p.y - r))

	return worst


func step(w, frames: int) -> void:
	for n in range(frames):
		await physics_frame
		w._roll_tick(DT)

		for id in w._logs.ids():
			if w._items.has(id):
				note_sink(sink(w, id))


func asleep(w, id: int) -> bool:
	return not w._logs.has(id) or w._logs.asleep(id)


# A walker on the ground walking along `dir` at `speed` from `feet` for `seconds`: stopped at the log by lying_logs.walker_touch, as the client does,
# and pushing it with ACT_PUSH_LOG every 0.1 s while they walk into it (the client's encoding, LyingLogs.push_args). Returns where the walker ends.
func walk(w, id: int, feet: Vector3, dir: Vector3, speed: float, sprint: bool, seconds: float) -> Vector3:
	var at: Vector3 = feet
	var send_in: float = 0.0
	var frames: int = int(seconds / DT)

	for n in range(frames):
		at += dir * speed * DT
		at.y = float(w.ground_height.call(at.x, at.z))
		var it: Dictionary = w._items[id]
		var touch: Dictionary = LyingLogs.walker_touch(at, P_R, P_H, centre(w, id), axis(w, id), LyingLogs.LOG_HALF_M, w._log_r(it))
		send_in -= DT

		if not touch.is_empty():
			at += touch["out"]
			var into: Vector3 = -(touch["n"] as Vector3)
			var square: float = dir.dot(into)

			if square > 0.05 and send_in <= 0.0:
				send_in = 0.1
				var args: Array = LyingLogs.push_args(sprint, square, into)
				w.action(1, Net.ACT_PUSH_LOG, id, int(args[0]), int(args[1]), touch["at"])

			var after: Dictionary = LyingLogs.walker_touch(at, P_R, P_H, centre(w, id), axis(w, id), LyingLogs.LOG_HALF_M, w._log_r(it))

			if not after.is_empty():
				worst_overlap = maxf(worst_overlap, (after["out"] as Vector3).length())

		w.report_position(1, at)
		await physics_frame
		w._roll_tick(DT)
		note_sink(sink(w, id))

	return at


func note_sink(depth: float) -> void:
	if depth > worst_sink:
		worst_sink = depth
		worst_case = case_name


func _initialize() -> void:
	_run()


func _run() -> void:
	# --- 1. The pose: turn, pitch and spin round-trip; the long axis is the basis x ---
	var round_ok: bool = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7

	for n in range(50):
		var want: Vector3 = Vector3(rng.randf_range(0.0, TAU), rng.randf_range(-1.2, 1.2), rng.randf_range(-PI, PI))
		var got: Vector3 = LyingLogs.angles_of(LyingLogs.basis_of(want.x, want.y, want.z))
		round_ok = round_ok and LyingLogs.basis_of(got.x, got.y, got.z).is_equal_approx(LyingLogs.basis_of(want.x, want.y, want.z))

	check(round_ok and (LyingLogs.basis_of(PI * 0.5, 0.0, 0.0) * Vector3.RIGHT).is_equal_approx(Vector3(0.0, 0.0, -1.0)), "a log's pose (rot_y, pitch, spin) round-trips through its basis; rot_y 0 lies along x")

	# --- 2. The walker against a log: stopped beside it, free on top of it ---
	var side: Dictionary = LyingLogs.walker_touch(Vector3(-0.5, 0.0, 0.0), P_R, P_H, Vector3(0.0, 0.25, 0.0), Vector3(0.0, 0.0, 1.0), 1.5, 0.25)
	check(not side.is_empty() and (side["out"] as Vector3).x < -0.09 and is_equal_approx((side["out"] as Vector3).y, 0.0) and (side["n"] as Vector3).is_equal_approx(Vector3(-1.0, 0.0, 0.0)), "a walker 0.5 m from a log's middle is put back clear of it, level (%s)" % str(side.get("out")))
	check(LyingLogs.walker_touch(Vector3(-1.0, 0.0, 0.0), P_R, P_H, Vector3(0.0, 0.25, 0.0), Vector3(0.0, 0.0, 1.0), 1.5, 0.25).is_empty(), "a metre off it they are apart")
	check(LyingLogs.walker_touch(Vector3(0.0, 0.5, 0.0), P_R, P_H, Vector3(0.0, 0.25, 0.0), Vector3(0.0, 0.0, 1.0), 1.5, 0.25).is_empty(), "standing on it is not walking into it")
	var quarter: Dictionary = LyingLogs.walker_touch(Vector3(-0.5, 0.0, 0.75), P_R, P_H, Vector3(0.0, 0.25, 0.0), Vector3(0.0, 0.0, 1.0), 1.5, 0.25)
	check(not quarter.is_empty() and absf((quarter["at"] as Vector3).z - 0.75) < 0.01, "a quarter along, the touch is a quarter along (z %.2f)" % float((quarter["at"] as Vector3).z if not quarter.is_empty() else 0.0))
	check(LyingLogs.push_args(true, 0.5, Vector3(0.0, 0.0, 1.0)) == [1050, 90] and LyingLogs.push_args(false, 1.0, Vector3(-1.0, 0.0, 0.0)) == [100, 180], "the push says sprint, how square and the heading")

	var across: float = PI * 0.5   # the log lies along z, so it rolls along x

	# --- 3. On flat ground a dropped log lies still and goes to sleep ---
	case_name = "flat drop"
	var flat = make("user://test_log_physics_flat", func(_x, _z): return 10.0)
	var lying: int = drop(flat, "log_oak", Vector3(0.0, 10.0, 0.0), across)
	check(lying != 0 and flat._logs.has(lying), "a dropped log is a body in the log physics")
	await step(flat, 90)
	var rest: Vector3 = flat._items[lying]["pos"]
	check(asleep(flat, lying) and absf(rest.y - 10.0) < 0.05 and Vector2(rest.x, rest.z).length() < 0.1 and absf(float(flat._items[lying].get("pitch", 0.0))) < 0.05, "on the flat it lies where it fell and sleeps (%s)" % str(rest))
	await step(flat, 30)
	check(not flat._logs.has(lying) and flat._logs.cell_count() == 0, "asleep with nothing awake near, it leaves the space (and the ground copy goes)")

	# A stone is never a body.
	flat.drop_in_world(flat.table.number_of("stone"), 1, Vector3(5.0, 10.0, 0.0))
	check(flat._logs.count() == 0, "other items are never put in the log physics")

	# --- 4. Walking and sprinting into it on the flat: the walker stops at it and rolls it ---
	case_name = "walk flat"
	flat.report_position(1, Vector3(-1.0, 10.0, 0.0))
	var walker: Vector3 = await walk(flat, lying, Vector3(-1.2, 10.0, 0.0), Vector3(1.0, 0.0, 0.0), WALK, false, 2.0)
	await step(flat, 180)
	var walked: float = float(flat._items[lying]["pos"].x)
	check(walked > 0.8, "walking into it on the flat rolls it ahead (%.2f m)" % walked)
	check(walker.x < walked - 0.45, "and the walker is stopped by it, never through it (walker x %.2f, log x %.2f)" % [walker.x, walked])
	check(asleep(flat, lying), "it stops again once the walker stops")
	flat._logs.clear()
	flat._finish_writer()

	var flat_s = make("user://test_log_physics_flat_s", func(_x, _z): return 10.0)
	var lying_s: int = drop(flat_s, "log_oak", Vector3(0.0, 10.0, 0.0), across)
	await step(flat_s, 30)
	await walk(flat_s, lying_s, Vector3(-1.2, 10.0, 0.0), Vector3(1.0, 0.0, 0.0), SPRINT, true, 2.0)
	await step(flat_s, 90)
	var sprinted: float = float(flat_s._items[lying_s]["pos"].x)
	check(sprinted > walked + 0.5, "sprinting pushes harder: it goes further (%.2f m against %.2f)" % [sprinted, walked])
	flat_s._logs.clear()
	flat_s._finish_writer()

	# --- 5. A quarter along the log it turns as well as rolling; met in the middle it does not ---
	case_name = "quarter push"
	var q = make("user://test_log_physics_quarter", func(_x, _z): return 10.0)
	var turned: int = drop(q, "log_oak", Vector3(0.0, 10.0, 0.0), across)
	await step(q, 30)
	var yaw0: float = float(q._items[turned]["rot_y"])
	await walk(q, turned, Vector3(-1.2, 10.0, 0.75), Vector3(1.0, 0.0, 0.0), WALK, false, 2.0)
	await step(q, 60)
	var quarter_turn: float = absf(angle_difference(float(q._items[turned]["rot_y"]), yaw0))
	var middle_turn: float = absf(angle_difference(float(flat_s._items[lying_s]["rot_y"]), across)) if flat_s._items.has(lying_s) else 0.0
	check(quarter_turn > deg_to_rad(8.0) and quarter_turn > middle_turn + deg_to_rad(5.0), "pushed a quarter along it turns (%.0f degrees) and pushed in the middle it hardly does (%.0f)" % [rad_to_deg(quarter_turn), rad_to_deg(middle_turn)])
	check(float(q._items[turned]["pos"].x) > 0.3, "and it still moves on (%.2f m)" % float(q._items[turned]["pos"].x))
	q._logs.clear()
	q._finish_writer()

	# --- 6. Uphill a walker's push is held by the hill; a sprint rolls it up. Downhill it runs on further than on the flat ---
	case_name = "uphill and downhill"
	var hill_y: Callable = func(x, _z): return 10.0 + 0.27 * x   # rises along +x
	var up_walk = make("user://test_log_physics_up", hill_y)
	var up_id: int = drop(up_walk, "log_oak", Vector3(0.0, 10.0, 0.0), across)
	await step(up_walk, 60)
	var up_from: float = float(up_walk._items[up_id]["pos"].x)
	check(absf(up_from) < 0.2, "a log lies still across a gentle hill (0.27) (x %.2f)" % up_from)
	walker = await walk(up_walk, up_id, Vector3(-1.2, 9.7, 0.0), Vector3(1.0, 0.0, 0.0), WALK, false, 2.5)
	var up_walked: float = float(up_walk._items[up_id]["pos"].x) - up_from
	check(up_walked < 0.4, "walking uphill into it, the hill holds it (moved %.2f m)" % up_walked)
	check(walker.x < float(up_walk._items[up_id]["pos"].x) - 0.45, "and the walker is stopped by it (walker x %.2f)" % walker.x)
	up_walk._logs.clear()
	up_walk._finish_writer()

	var up_run = make("user://test_log_physics_up_s", hill_y)
	var up_s: int = drop(up_run, "log_oak", Vector3(0.0, 10.0, 0.0), across)
	await step(up_run, 60)
	var up_s_from: float = float(up_run._items[up_s]["pos"].x)
	await walk(up_run, up_s, Vector3(-1.2, 9.7, 0.0), Vector3(1.0, 0.0, 0.0), SPRINT, true, 2.5)
	var up_sprinted: float = float(up_run._items[up_s]["pos"].x) - up_s_from
	check(up_sprinted > 0.5 and up_sprinted > up_walked + 0.3, "sprinting uphill into it rolls it up the hill (%.2f m)" % up_sprinted)
	up_run._logs.clear()
	up_run._finish_writer()

	var down = make("user://test_log_physics_down", hill_y)
	var down_id: int = drop(down, "log_oak", Vector3(0.0, 10.0, 0.0), across)
	await step(down, 60)
	await walk(down, down_id, Vector3(1.2, 10.3, 0.0), Vector3(-1.0, 0.0, 0.0), WALK, false, 2.0)
	await step(down, 180)
	var down_went: float = -float(down._items[down_id]["pos"].x)
	check(down_went > walked + 0.3, "walking downhill into it rolls it further than on the flat (%.2f m against %.2f)" % [down_went, walked])
	down._logs.clear()
	down._finish_writer()

	# --- 7. A steep hill rolls a log down by itself; a log lying along the hill stays; a rock stops it, and it rests against the rock ---
	case_name = "steep hill and rock"
	var steep_y: Callable = func(x, _z): return 10.0 + 0.5 * x
	var steep = make("user://test_log_physics_steep", steep_y)
	var rock_id: int = 930000
	steep._items[rock_id] = {"number": steep.table.number_of("stone"), "count": 1, "pos": Vector3(-6.0, 7.0, 0.0), "left": 1.0e9, "boulder": {"radius": 0.8}}
	var roller: int = drop(steep, "log_oak", Vector3(0.0, 10.0, 0.0), across)
	var along_id: int = drop(steep, "log_oak", Vector3(0.0, 10.0, 12.0), 0.0)
	await step(steep, 240)
	var stopped: Vector3 = steep._items[roller]["pos"]
	var r_oak: float = steep._log_r(steep._items[roller])
	var core: Vector3 = axis(steep, roller) * (LyingLogs.LOG_HALF_M - r_oak)
	var near: Array = LyingLogs.closest_on_segments(Vector3(-6.0, 7.0 + 0.32, 0.0), Vector3(-6.0, 7.0 + 0.32, 0.0), centre(steep, roller) - core, centre(steep, roller) + core)
	var gap: float = (near[0] as Vector3).distance_to(near[1])
	check(stopped.x < -3.0, "a log across a steep hill (0.5) rolls down by itself (x %.2f)" % stopped.x)
	check(stopped.x > -6.0 and gap > 0.8 + r_oak - 0.1, "and the rock in its way stops it on the uphill side; it never goes into the rock (x %.2f, %.2f m from its middle)" % [stopped.x, gap])
	check(asleep(steep, roller), "it comes to rest against the rock")
	check(Vector2(steep._items[along_id]["pos"].x, steep._items[along_id]["pos"].z - 12.0).length() < 0.3, "a log lying along the steep hill stays (moved %.2f m)" % Vector2(steep._items[along_id]["pos"].x, steep._items[along_id]["pos"].z - 12.0).length())

	# Its pose is saved and comes back.
	var before: Dictionary = steep._items[roller].duplicate()
	steep.save()
	steep._logs.clear()
	steep._finish_writer()
	var back = make_again("user://test_log_physics_steep", steep_y)
	var kept: Dictionary = {}

	for k in back._items:
		if int(back._items[k]["number"]) == back.table.number_of("log_oak") and (back._items[k]["pos"] as Vector3).distance_to(before["pos"]) < 0.01:
			kept = back._items[k]

	check(not kept.is_empty() and absf(float(kept.get("rot_y", -9.0)) - float(before["rot_y"])) < 0.001 and absf(float(kept.get("pitch", -9.0)) - float(before.get("pitch", 0.0))) < 0.001 and absf(float(kept.get("spin", -9.0)) - float(before.get("spin", 0.0))) < 0.001, "its spot, turn, pitch and spin are saved (%s)" % str(kept.get("pos")))
	back._logs.clear()
	back._finish_writer()

	# --- 8. Logs stack and rest on each other and on rocks: one laid on two lying side by side (chocked by a rock each side, as a woodpile is) rests
	# on them; one dropped across another rests with its middle on it and an end on the ground ---
	case_name = "stack"
	var pile = make("user://test_log_physics_pile", func(_x, _z): return 10.0)
	pile._items[932000] = {"number": pile.table.number_of("stone"), "count": 1, "pos": Vector3(-0.85, 10.0, 0.0), "left": 1.0e9, "boulder": {"radius": 0.3}}
	pile._items[932001] = {"number": pile.table.number_of("stone"), "count": 1, "pos": Vector3(0.85, 10.0, 0.0), "left": 1.0e9, "boulder": {"radius": 0.3}}
	var low_a: int = drop(pile, "log_oak", Vector3(-0.26, 10.0, 0.0), across)
	var low_b: int = drop(pile, "log_oak", Vector3(0.26, 10.0, 0.0), across)
	await step(pile, 30)
	var top: int = drop(pile, "log_oak", Vector3(0.0, 10.0 + 0.5, 0.0), across)
	check(top != 0 and pile._logs.has(top), "a log laid on two others is in the log physics too (it lies on logs)")
	await step(pile, 300)
	var top_y: float = centre(pile, top).y
	check(top_y > 10.0 + 0.25 + 0.3, "it rests on the two below, which rest against the rocks (its middle %.2f m up; 0.25 on the ground)" % (top_y - 10.0))
	check(asleep(pile, top) and asleep(pile, low_a) and asleep(pile, low_b), "and all three settle")
	var under: int = drop(pile, "log_oak", Vector3(0.0, 10.0, 20.0), 0.0)   # along x
	await step(pile, 30)
	var cross: int = drop(pile, "log_oak", Vector3(0.6, 10.0 + 0.55, 20.0), across)   # along z, over it a little off its middle
	await step(pile, 240)
	check(centre(pile, cross).y > 10.0 + 0.25 + 0.08 and absf(float(pile._items[cross].get("pitch", 0.0))) > deg_to_rad(4.0), "one dropped across another rests on it, tilted, an end down (middle %.2f m up, pitch %.0f degrees)" % [centre(pile, cross).y - 10.0, rad_to_deg(float(pile._items[cross].get("pitch", 0.0)))])
	check(asleep(pile, cross) and asleep(pile, under), "and both settle")
	pile._logs.clear()
	pile._finish_writer()

	# --- 9. A log is never stood on end by a push: sprinting into its end, then slantwise ---
	case_name = "end-on push"
	var ends = make("user://test_log_physics_ends", func(_x, _z): return 10.0)
	var end_id: int = drop(ends, "log_birch", Vector3(0.0, 10.0, 0.0), 0.0)   # the lightest log, lying along x
	await step(ends, 30)
	await walk(ends, end_id, Vector3(-2.2, 10.0, 0.0), Vector3(1.0, 0.0, 0.0), SPRINT, true, 1.5)
	await walk(ends, end_id, Vector3(float(ends._items[end_id]["pos"].x) - 2.0, 10.0, -1.5), Vector3(1.0, 0.0, 1.0).normalized(), SPRINT, true, 1.5)
	await step(ends, 120)
	check(absf(float(ends._items[end_id].get("pitch", 0.0))) < deg_to_rad(30.0), "pushed end-on and slantwise it still lies down (pitch %.0f degrees)" % rad_to_deg(float(ends._items[end_id].get("pitch", 0.0))))
	ends._logs.clear()
	ends._finish_writer()

	# --- 10. A felled tree's logs land, roll off what they come down on and settle ---
	case_name = "felled tree"
	var fall = make("user://test_log_physics_fell", func(_x, _z): return 10.0)
	var stump: int = fall._next_id
	fall._fell_record(Vector2i(0, 0), {"name": "oak", "position": Vector3(0.0, 10.0, 0.0), "height": 14.0, "trunk": 0.3}, Vector2(1.0, 0.0))
	var felled: Array = []

	for k in fall._items:
		if int(fall._items[k]["number"]) == fall.table.number_of("log_oak"):
			felled.append(k)

	check(felled.size() == 4 and fall._items.has(stump), "a 14 m oak comes down in 4 logs")
	var second: Vector3 = fall._items[felled[1]]["pos"]
	var under_id: int = 931000
	fall._items[under_id] = {"number": fall.table.number_of("stone"), "count": 1, "pos": Vector3(second.x, 10.0, second.z) + Vector3(0.0, 0.0, 0.3).rotated(Vector3.UP, float(fall._items[felled[1]]["rot_y"])), "left": 1.0e9, "boulder": {"radius": 0.5}}
	fall._fall_tick(ItemsScript.FALL_S)
	check(felled.all(func(k): return fall._logs.has(k)), "landed, its logs are bodies in the log physics")
	await step(fall, 240)
	var flat_ok: bool = true

	for k in felled:
		flat_ok = flat_ok and absf(float(fall._items[k].get("pitch", 0.0))) < deg_to_rad(35.0) and sink(fall, k) < 0.06

	check(flat_ok, "they settle lying down, none in the ground")
	var rock_at: Vector3 = fall._items[under_id]["pos"] + Vector3(0.0, 0.2, 0.0)
	var hit_r: float = fall._log_r(fall._items[felled[1]])
	var hit_core: Vector3 = axis(fall, felled[1]) * (LyingLogs.LOG_HALF_M - hit_r)
	var on_rock: Array = LyingLogs.closest_on_segments(rock_at, rock_at, centre(fall, felled[1]) - hit_core, centre(fall, felled[1]) + hit_core)
	check((on_rock[0] as Vector3).distance_to(on_rock[1]) > 0.5 + hit_r - 0.12, "the log that came down on the boulder is pushed off it (%.2f m from the rock)" % (on_rock[0] as Vector3).distance_to(on_rock[1]))
	fall._logs.clear()
	fall._finish_writer()

	# --- 11. A push from too far off, or at something that is not a log, does nothing; players who see a moving log are told its pose ---
	case_name = "far push"
	var far = make("user://test_log_physics_far", func(_x, _z): return 10.0)
	var far_id: int = drop(far, "log_oak", Vector3(0.0, 10.0, 0.0), across)
	var moved: Array = []
	far.send_logs_moved = func(p, ids, at, poses): moved.append([p, ids, at, poses])
	far._known[1] = {far_id: 1}
	await step(far, 60)
	far.report_position(1, Vector3(-6.0, 10.0, 0.0))

	for n in range(20):
		far.action(1, Net.ACT_PUSH_LOG, far_id, 1100, 0, Vector3(-0.25, 10.25, 0.0))
		await step(far, 6)

	check(absf(float(far._items[far_id]["pos"].x)) < 0.05, "a push from 6 m away is not taken")
	var stone_id: int = far._next_id
	far.drop_in_world(far.table.number_of("stone"), 1, Vector3(-5.5, 10.0, 0.0))
	far.action(1, Net.ACT_PUSH_LOG, stone_id, 1100, 0, Vector3(-5.5, 10.0, 0.0))
	check(far._logs.count() <= 1 and not far._logs.has(stone_id), "a stone is not pushed")
	check(not moved.is_empty() and int(moved[0][0]) == 1 and (moved[0][1] as PackedInt32Array).has(far_id) and (moved[-1][3] as PackedVector3Array).size() == (moved[-1][1] as PackedInt32Array).size(), "the player who sees it is told where it is and how it lies (%d messages)" % moved.size())
	far._logs.clear()
	far._finish_writer()

	check(worst_sink < 0.06, "no log ever sank into the ground, in any case (deepest %.3f m, %s)" % [worst_sink, worst_case])
	check(worst_overlap < 0.02, "no walker ever stood inside a log (deepest %.3f m)" % worst_overlap)
	print("log physics: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# The same store opened again (a restart): its items as saved.
func make_again(dir: String, ground: Callable):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = ground
	items.setup(ItemTableScript.load_default(), dir)
	return items
