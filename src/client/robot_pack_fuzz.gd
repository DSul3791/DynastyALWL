extends RefCounted

# Plan pack_fuzz (coordinator 23 Nov 2026, "the hands-on screens during play"): two robots use the pack, the hotbar and one shared Wicker
# basket the way a player does, at random and without waiting for answers. Each action goes through the screen's own code: a drop on a pack
# well (drag, swap, merge), a click to pick up and a click to put down, shift-click into the basket, a drag onto a basket well, a click
# on a basket well to take, split, drop on the ground and pick up, the four bulk buttons, a craft queued while moving, closing and opening
# the basket, the hotbar, and the window closed mid-drag. Both robots work the same basket at once.
# Checked: after every FUZZ_CHECK_EVERY actions, the pack (CHECK pack) and the basket (CHECK chest) as the client shows them are what the
# server holds (tools/robot_check.py, AUDIT pack / chest); after a closed window no drag is left on the cursor; and over the whole run
# nothing is doubled or lost: AUDIT total (every pack, container and loose item of the counted kinds) never goes past what was there plus
# what was given (ROBOT ... GAVE), and comes back to exactly that at the end (robot_check.py; twine counts as its 3 plant fibre).
#   ROBOT_S=600 tools/robots.sh 2 pack_fuzz
# Testing only: made by robot_play.gd for this plan.

const NetScript := preload("res://src/stream/terrain_net.gd")
const RobotRules := preload("res://src/shared/robot_rules.gd")
const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")
const NpcCamp := preload("res://src/shared/npc_camp.gd")
const FUZZ_ACTIONS := 900
const FUZZ_CHECK_EVERY := 75
const GAP_MS := 260                # each action after 0 to this many ms: faster than the answers come back on the robots' link
const COUNTED := ["stick", "stone", "plant_fibre", "twine", "firewood", "clay"]
const GIVES := [["stick", 60], ["stone", 60], ["plant_fibre", 90], ["firewood", 24], ["clay", 60]]

var r                              # robot_play.gd
var view                           # inventory_view.gd
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var basket: int = -1
var counts: Dictionary = {}        # action name -> times done
var _chest_msec: int = 0           # the last chest contents from the server


func _init(robot) -> void:
	r = robot
	view = robot.client.items
	rng.seed = hash(robot.robot_name) ^ RobotRules.now_ms()
	robot.client.net.chest_received.connect(func(_id, _b): _chest_msec = Time.get_ticks_msec())


func _line(text: String) -> void:
	FreezeWatchScript.printer.line("ROBOT %s %s" % [r.robot_name, text])


func _wait_file(name: String, s: float) -> String:
	var path: String = r._share(name)
	var end: int = Time.get_ticks_msec() + int(s * 1000.0)

	while Time.get_ticks_msec() < end:
		if path != "" and FileAccess.file_exists(path):
			var text: String = FileAccess.get_file_as_string(path).strip_edges()

			if text != "":
				return text

		await r.get_tree().process_frame

	return ""


func run() -> void:
	var first: bool = r.robot_name.ends_with("1")
	r._step = "fuzz basket"

	if r._share("x") == "":
		r._fail("fuzz", "share", "no ROBOT_SHARE folder: run it with tools/robots.sh 2 pack_fuzz")
		return

	# The basket first (it uses sticks and twine), before the counting starts.
	if first:
		await _leave_camp()
		r._give("stone_knife", 1)
		await r._check_pack("fuzz knife")
		basket = await r._build_basket()

		if basket < 0:
			r._fail("fuzz", "basket", "no Wicker basket to share")
			r._write(r._share("fuzz_basket.txt"), "-1")
			return

		r._write(r._share("fuzz_basket.txt"), str(basket))
		var spot: Vector3 = r.client.body.global_position
		r._write(r._share("server_control.txt"), "count %.1f %.1f %s\n" % [spot.x, spot.z, " ".join(COUNTED)])
		await r._wait(2.0)   # the server prints its first total before anything is given
		r._write(r._share("fuzz_go.txt"), "go")
	else:
		basket = int(await _wait_file("fuzz_basket.txt", 240.0))

		if basket < 0:
			r._note("fuzz", "the first robot made no basket")
			return

		if await _wait_file("fuzz_go.txt", 60.0) == "":
			r._fail("fuzz", "go", "the first robot never started the count")
			return

	var at: Vector3 = (view._world.get(basket, {}) as Dictionary).get("pos", r.client.body.global_position)
	await r._go_to(at, 30.0, 1.6)

	r._step = "fuzz given"

	for g in GIVES:
		r._give(str(g[0]), int(g[1]))
		_line("GAVE %s %d %d" % [str(g[0]), int(g[1]), RobotRules.now_ms()])

	await r._check_pack("fuzz given")
	r._write(r._share("fuzz_given_%s.txt" % r.robot_name), "1")
	await _wait_file("fuzz_given_Robot_%d.txt" % (2 if first else 1), 60.0)

	await r._tap("inventory")
	await r._wait(0.6)

	if not view.open:
		r._fail("fuzz", "open", "the inventory key opened no pack")
		return

	await _open_basket()

	for n in range(FUZZ_ACTIONS):
		r._step = "fuzz %d" % n
		await _one()
		await r._wait(rng.randf() * GAP_MS / 1000.0)

		if (n + 1) % FUZZ_CHECK_EVERY == 0:
			await _check("fuzz %d" % (n + 1))

	# The end: whatever is on the ground near comes back, the queue empties, and one last look.
	r._step = "fuzz end"
	await _pick_up_all()
	var limit: int = Time.get_ticks_msec() + 30000

	while r._queue_left > 0 and Time.get_ticks_msec() < limit:
		await r.get_tree().process_frame

	await _check("fuzz end")
	_line("step fuzz: %d actions %s" % [FUZZ_ACTIONS, str(counts)])
	r._write(r._share("fuzz_done_%s.txt" % r.robot_name), "1")
	await _wait_file("fuzz_done_Robot_%d.txt" % (2 if first else 1), 120.0)   # the other robot's last moves may still change the basket
	await _check("fuzz both done")

	if view.chest_mode:
		view._close_chest()

	await r._esc()


# Out of Edda and Hob's keep-off ring (nothing may be put down there: the basket would be refused), wherever this robot stands.
func _leave_camp() -> void:
	var here: Vector3 = r.client.body.global_position
	var tree: Vector2 = NpcCamp.tree_spot()
	var keep: float = float(NpcCamp.cfg().get("keep_m", 0.0))
	var flat: Vector2 = Vector2(here.x, here.z) - tree

	if NpcCamp.keep_reason(here) == "" and flat.length() > keep + 4.0:
		return

	var away: Vector2 = tree + (flat.normalized() if flat.length() > 0.5 else Vector2.RIGHT) * (keep + 8.0)
	await r._go_to(Vector3(away.x, here.y, away.y), 60.0, 2.0)
	_line("step fuzz: moved %.0f m out of the camp's ring to %s (%s)" % [Vector2(r.client.body.global_position.x, r.client.body.global_position.z).distance_to(Vector2(here.x, here.z)), str(r.client.body.global_position.round()), NpcCamp.keep_reason(r.client.body.global_position)])


func _open_basket() -> void:
	if view.chest_mode:
		return

	view._ask_open(basket)
	var end: int = Time.get_ticks_msec() + 4000

	while not view.chest_mode and Time.get_ticks_msec() < end:
		await r.get_tree().process_frame

	if not view.chest_mode:
		r._note("fuzz", "the basket did not open (%s)" % str(r._notices.slice(maxi(r._notices.size() - 2, 0))))


func _check(step: String) -> void:
	await r._check_pack(step)
	_chest_line(step)
	await r._wait(2.5)
	_chest_line(step + " again")   # the same view a little later: a slow answer has come by now, a stale view has not


func _chest_line(step: String) -> void:
	if view.chest_mode and view.chest_inv != null:
		var gap: float = r.client.body.global_position.distance_to((view._world.get(view.chest_id, {}) as Dictionary).get("pos", Vector3.INF))
		_line("CHECK chest %d %d %s %d %s (%.1f m away, last contents %d ms ago)" % [view.chest_id, RobotRules.now_ms(), RobotRules.signature(view.chest_inv), RobotRules.used(view.chest_inv), step, gap, Time.get_ticks_msec() - _chest_msec])


func _slot(full: bool) -> int:
	var inv = view.inventory
	var picks: Array = []

	for s in range(inv.slot_count):
		if (inv.numbers[s] != 0) == full:
			picks.append(s)

	return -1 if picks.is_empty() else int(picks[rng.randi() % picks.size()])


func _any_slot() -> int:
	return rng.randi() % view.inventory.slot_count


func _did(what: String) -> void:
	counts[what] = int(counts.get(what, 0)) + 1


func _one() -> void:
	var roll: int = rng.randi() % 100
	var a: int = _slot(true)

	if a < 0:
		await _pick_up_all()
		return

	if roll < 18:   # drag a pack stack onto another well: a move, a swap or a merge
		var b: int = _any_slot()

		if b != a and b < view._buttons.size() and view._buttons[b].can_drop.call({"slot": a}):
			view._buttons[b].on_drop.call({"slot": a})
			_did("drag")
	elif roll < 26:   # click it up, click it down
		var b2: int = _any_slot()
		view._pack_part._on_look_click(a, MOUSE_BUTTON_LEFT, false)
		view._pack_part._on_look_click(b2, MOUSE_BUTTON_LEFT, false)
		_did("click_move")
	elif roll < 38:   # shift-click into the basket
		if view.chest_mode:
			view._pack_part._on_look_click(a, MOUSE_BUTTON_LEFT, true)
			_did("shift_put")
	elif roll < 46:   # drag onto a basket well
		if view.chest_mode and not view._chest_buttons.is_empty():
			var well: int = rng.randi() % view._chest_buttons.size()
			view._chest_buttons[well].on_drop.call({"slot": a})
			_did("drag_put")
	elif roll < 58:   # click a basket well to take
		if view.chest_mode and view.chest_inv != null and view.chest_inv.slot_count > 0:
			view._container_part.on_slot(true, rng.randi() % view.chest_inv.slot_count)
			_did("take")
	elif roll < 64:
		view._selected = a
		view._split_selected()
		_did("split")
	elif roll < 68:
		view._selected = a
		view._drop_selected(rng.randf() < 0.5)
		_did("drop")
	elif roll < 72:
		await _pick_up_all()
		_did("pickup")
	elif roll < 78:
		view.bulk(rng.randi() % 4)
		_did("bulk")
	elif roll < 82:
		var twine: Dictionary = r._recipes.get("twine", {})

		if not twine.is_empty():
			r.client.net.inventory_action.rpc_id(1, NetScript.ACT_CRAFT_QUEUE, int(twine["number"]), 0, 1 + rng.randi() % 3, Vector3.ZERO)
			_did("craft")
	elif roll < 87:
		if view.chest_mode:
			view._close_chest()
			await r._wait(rng.randf() * 0.3)

		await _open_basket()
		_did("reopen")
	elif roll < 92:
		view.hotbar_to_pack(rng.randi() % 10)
		_did("hotbar")
	else:
		await _drag_then_close(a)
		_did("drag_close")


# A stack picked up by the pointer and the window closed under it (the inventory key): no drag may stay on the cursor, and the stack stays where it was.
func _drag_then_close(slot: int) -> void:
	if slot >= view._buttons.size():
		return

	var button = view._buttons[slot]
	var data: Variant = button.drag_data.call() if button.drag_data.is_valid() else null

	if data == null:
		return

	button.force_drag(data, null)
	await r.get_tree().process_frame
	var dragging: bool = r.client.get_viewport().gui_is_dragging()
	await r._tap("inventory")   # the basket and the pack close together

	for i in 3:
		await r.get_tree().process_frame

	if r.client.get_viewport().gui_is_dragging():
		r._fail("cursor", "drag_close", "a stack dragged from pack slot %d (drag started: %s) is still on the cursor after the inventory key closed the window" % [slot, str(dragging)])
		r.client.get_viewport().gui_cancel_drag()

	if view.screen_open():
		await r._esc()

	await r._tap("inventory")
	await r._wait(0.4)
	await _open_basket()


# Every loose item of the counted kinds within reach goes back in the pack (ACT_PICKUP, as E does), one each.
func _pick_up_all() -> void:
	var here: Vector3 = r.client.body.global_position

	for id in view._world.keys():
		var w: Dictionary = view._world[id]

		if int(w.get("state", -1)) == 0 and COUNTED.has(view.table.id_of(int(w.get("number", 0)))) and (w.get("pos", Vector3.INF) as Vector3).distance_to(here) < 3.0:
			r.client.net.inventory_action.rpc_id(1, NetScript.ACT_PICKUP, int(id), 0, 0, Vector3.ZERO)
