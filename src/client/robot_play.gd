extends Node

# A robot play-tester (--robot=NAME; tools/robots.sh starts a server, a lossy link and several of these; tools/robot_check.py reads the logs).
# Build 9257's first hour on Dave's server (23 Nov 2026) found faults that one-machine tests never saw: animals teleporting and passing
# through players, another player's held spear floating, crouch-walking blocked near ferns, the pack not updating after a queued craft.
# This is the real client (headless, dummy renderer) driven like a new player: movement is real key presses through the client's own
# movement code; actions are the same requests the screens send. While it plays it checks, and prints one line per finding:
#   ROBOT <name> CHECK pack <peer> <unix ms> <signature> <slots> <step>   the client's pack after a quiet moment; robot_check.py holds it
#                                                                          against the server's AUDIT pack lines (src/server/robot_audit.gd)
#   ROBOT <name> FAIL <kind> <details>     a broken invariant: robot_check.py fails the run on any
#   ROBOT <name> NOTE <kind> <details>     worth a look, not a failure (an obstacle, a refusal that came with a message)
#   ROBOT <name> step <name> <details>     progress
# Kinds: craft (a finished craft is not in the pack), pickup, jump (a drawn animal or player moved farther in a frame than it can),
# inside (a drawn animal's middle inside this player's capsule), held (a remote player's hand mount away from its hand bone), blocked (keys held,
# no movement, in a stance where standing at the same spot moves), rejoin (the pack after
# quit and rejoin is not the pack before).
# Plans (--robot-plan=): first_hours (default: craft, drop and pick up, stances, forest crouch walk, hunt, sleep, quit), screens (every
# screen a tester opens, every lit Craft button pressed through the screen, split and drop, quit with a screen open; then rejoin), rejoin (join, check
# the pack against the one saved at quit, look around, quit), light (the live server: walk, stances, watch animals and players; changes
# nothing in the world). --robot-admin lets it ask for starting materials (the server needs --open-admin; never on a live server).
# Testing only: nothing here runs unless --robot= is given.

const NetScript := preload("res://src/stream/terrain_net.gd")
const StanceScript := preload("res://src/client/stance.gd")
const CharacterStore := preload("res://src/client/character/character_store.gd")
const BagRules := preload("res://src/shared/bag_rules.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const KeyBindings := preload("res://src/client/key_bindings.gd")
const RobotRules := preload("res://src/shared/robot_rules.gd")   # the pack signature the server prints too
const InventoryScript := preload("res://src/shared/inventory.gd")

const QUIET_S := 3.0             # a pack check waits until no pack message came for this long
const QUIET_LIMIT_S := 20.0
const JUMP_SLACK := 2.0          # a drawn step may be this much over the top speed (a frame hitch) before it counts
const JUMP_FLOOR_M := 1.5
const PLAYER_TOP_MPS := 9.5      # terrain_client RUN_SPEED 9.0
const FRESH_S := 1.5             # a body just drawn may still settle onto its first samples
const INSIDE_M := 0.3
const RESPAWN_M := 40.0          # a drawn player farther than this in one frame was moved on purpose (respawn, rescue), not a jump
const HAND_M := 0.25             # the hand mount this far from the hand bone (it sits about 0.11 m off it) has come loose
const SAVED_FILE := "user://robot_last_pack.txt"
const MID_FILE := "user://robot_mid_craft.txt"
const SPECIES_NAME := {1: "rabbit", 2: "deer", 3: "wolf", 4: "moose", 5: "fox", 8: "boar", 14: "bear", 17: "lynx", 18: "black_bear", 19: "elk", 20: "bighorn", 21: "mountain_goat", 22: "beaver", 23: "chamois", 24: "mink", 25: "raccoon", 26: "rat"}
const WILD_GROUND := [4, 5, 8, 14, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]   # data/animals/animals.json numbers: no birds, no town animals
const POSE_EVERY_S := 0.5        # POSE and SEES lines: how this robot stands and moves, and how it sees each other player (robot_check.py)

var client                       # terrain_client.gd
var robot_name: String = "Robot"
var plan: String = "first_hours"
var admin: bool = false

var _pack_msec: int = 0          # last pack message (full or slots) from the server
var _notice_msec: int = 0
var _notices: Array = []
var _queue_left: int = 0
var _queue_msec: int = 0
var _rejects: Array = []         # [reason, msec, step]
var _step: String = "join"
var _fails: int = 0
var _notes: int = 0
var _species: Dictionary = {}    # animal id -> species number (from the rows)
var _top_mps: Dictionary = {}    # species number -> fastest _mps
var _seen_animal: Dictionary = {}   # id -> [last drawn position, first seen msec]
var _seen_player: Dictionary = {}   # peer -> [last drawn position, first seen msec]
var _held_t: float = 0.0
var _held_bad: Dictionary = {}   # peer -> consecutive bad looks
var _held_looks: int = 0         # remote held items measured (the done line says so: 0 means the check never had anything to look at)
var _reported: Dictionary = {}   # "kind:id" -> true: each fault reported once per robot
var _keys_down: Dictionary = {}
var _recipes: Dictionary = {}
var _health: int = -1          # vitals() health as the server last sent it
var _hunger: int = -1
var _thirst: int = -1
var _lowest_health: int = 1 << 30
var _hits: Dictionary = {}       # animal id -> hits the server reported on it (animal_hit)
var _hp: Dictionary = {}         # animal id -> its health share last seen in the rows (1.0 unhurt)
var _fell: Dictionary = {}       # animal ids the client saw go down from a hit
var _pose_t: float = 0.0
var _died: int = 0
var last_touch: String = ""      # what the body touched at the end of the last _walk_for, keys still held


func prepare(name_arg: String, args: PackedStringArray) -> void:
	robot_name = name_arg.replace("_", " ")

	for a in args:
		if a.begins_with("--robot-plan="):
			plan = a.trim_prefix("--robot-plan=")
		elif a == "--robot-admin":
			admin = true

	# Its own character, picked before the client says hello (each robot runs with its own user data folder, tools/robots.sh).
	var mine: String = ""

	for c in CharacterStore.list():
		if str(c.get("name", "")) == robot_name:
			mine = str(c.get("id", ""))

	if mine == "":
		mine = CharacterStore.add(robot_name, Generator.encode(Generator.make_genome()))

	if mine == "" or not CharacterStore.set_active(mine):
		push_error("robot: could not make or pick the character %s" % robot_name)   # robot_check fails a run with this line
	print("ROBOT %s step prepare: plan %s, character %s" % [robot_name, plan, mine])


func _say(kind: String, text: String) -> void:
	print("ROBOT %s %s" % [robot_name, text])

	if kind == "FAIL":
		_fails += 1
	elif kind == "NOTE":
		_notes += 1


func _fail(kind: String, key: String, details: String) -> void:
	if _reported.has(kind + ":" + key):
		return

	_reported[kind + ":" + key] = true
	_say("FAIL", "FAIL %s %s (step %s, at %s)" % [kind, details, _step, str(client.body.global_position.round())])


func _note(kind: String, details: String) -> void:
	_say("NOTE", "NOTE %s %s (step %s, at %s)" % [kind, details, _step, str(client.body.global_position.round())])


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _now_ms() -> int:
	return RobotRules.now_ms()


# --- the watchers, every frame --------------------------------------------------------------------------------------------------------------

func _ready() -> void:
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))

	if cfg is Dictionary:
		for sp in cfg.get("species", {}):
			var row: Dictionary = cfg["species"][sp]
			var top: float = RobotRules.top_speed(row)

			_top_mps[int(row.get("number", 0))] = top

	var rec: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/recipes.json"))

	if rec is Dictionary:
		_recipes = rec.get("recipes", {})


func _hook() -> void:
	client.net.inventory_full_received.connect(func(_b): _pack_msec = Time.get_ticks_msec())
	client.net.inventory_slots_received.connect(func(_b): _pack_msec = Time.get_ticks_msec())
	client.net.notice_received.connect(func(t): _notice_msec = Time.get_ticks_msec(); _notices.append(str(t)))
	client.net.reject_received.connect(func(r): _rejects.append([int(r), Time.get_ticks_msec(), _step]))
	client.net.craft_queue_received.connect(func(entries, _ms): _queue_left = entries.size(); _queue_msec = Time.get_ticks_msec())
	client.net.animals_received.connect(func(rows, _ms):
		for r in rows:
			_species[int(r[0])] = RobotRules.species_of(int(r[1]))

			if r.size() > 6 and r[r.size() - 1] is float:
				_hp[int(r[0])] = float(r[r.size() - 1]))   # hurt: its health share is the last field (server_animals rows_near)
	client.net.animal_hit_received.connect(func(id, _zone): _hits[int(id)] = int(_hits.get(int(id), 0)) + 1)
	client.net.vitals_received.connect(func(hu, health, _w, th, _l, _f):
		_hunger = int(hu)
		_thirst = int(th)
		_health = int(health)
		_lowest_health = mini(_lowest_health, int(health)))
	client.net.died_received.connect(func(cause, _spawn):
		_died += 1
		_fail("died", str(_died), "the robot died (%s): the game does not want a player dead unless they do something deliberately stupid" % str(cause)))



# After joining (the animal view is made then): an animal that went down from a hit (animal_view.gd fell, sent with its last row's place).
func _hook_view() -> void:
	var view: Node = client._animal_view_node
	view.fell.connect(func(_kind, at, _small):
		for id in view._bodies:
			if (view._bodies[id]["target"] as Vector3).distance_to(at) < 0.01:
				_fell[int(id)] = true)


func _process(delta: float) -> void:
	if client == null or client.body == null or client.connected_msec == 0:
		return

	var now: int = Time.get_ticks_msec()
	var me: Vector3 = client.body.global_position
	var view: Node = client._animal_view_node
	var present: Dictionary = {}

	if view != null:
		for row in view.drawn_positions():
			var id: int = int(row[0])
			var pos: Vector3 = row[1]
			present[id] = true
			var num: int = int(_species.get(id, 0))

			if _seen_animal.has(id):
				var was: Array = _seen_animal[id]
				var step: float = Vector2(pos.x - was[0].x, pos.z - was[0].z).length()
				var allowed: float = maxf(float(_top_mps.get(num, 15.0)) * delta * JUMP_SLACK, JUMP_FLOOR_M)

				if now - int(was[1]) > int(FRESH_S * 1000.0) and step > allowed:
					_fail("jump", "animal%d" % id, "drawn animal %d (species %d) moved %.1f m in one %.0f ms frame (top speed %.1f m/s), %s -> %s" % [
						id, num, step, delta * 1000.0, float(_top_mps.get(num, 0.0)), str(was[0].round()), str(pos.round())])

				was[0] = pos
			else:
				_seen_animal[id] = [pos, now]

			if Vector2(pos.x - me.x, pos.z - me.z).length() < INSIDE_M and absf(pos.y - me.y) < 1.2:
				_fail("inside", "animal%d" % id, "drawn animal %d (species %d) %.2f m from this player's middle: inside the capsule" % [id, num, Vector2(pos.x - me.x, pos.z - me.z).length()])

	for id in _seen_animal.keys():
		if not present.has(id):
			_seen_animal.erase(id)

	var pv: Node = client._player_view

	if pv != null:
		var here: Dictionary = {}

		for row in pv.drawn():
			var peer: int = int(row["peer"])
			var pos: Vector3 = row["pos"]
			here[peer] = true

			if _seen_player.has(peer):
				var was: Array = _seen_player[peer]
				var step: float = Vector2(pos.x - was[0].x, pos.z - was[0].z).length()

				if step > RESPAWN_M:
					was[1] = now   # a respawn or a rescue moves a player far on purpose: treat it as a fresh body
				elif now - int(was[1]) > int(FRESH_S * 1000.0) and step > maxf(PLAYER_TOP_MPS * delta * JUMP_SLACK, JUMP_FLOOR_M):
					_fail("jump", "player%d" % peer, "drawn player %s moved %.1f m in one %.0f ms frame, %s -> %s" % [row["name"], step, delta * 1000.0, str(was[0].round()), str(pos.round())])

				was[0] = pos
			else:
				_seen_player[peer] = [pos, now]

		for peer in _seen_player.keys():
			if not here.has(peer):
				_seen_player.erase(peer)

		_held_t += delta

		if _held_t >= 0.5:
			_held_t = 0.0
			_check_held(pv)

	_check_refusals(now)
	_pose_lines(delta)


# A remote player's held item (player_view.gd _show_held) is a child of the right hand mount, so it can only float if the mount does: the mount
# must stay at the hand bone (dynasty_body.gd puts it GRIP_FROM_WRIST_M, about 0.11 m, from the wrist). Measured mount to hand bone.
func _check_held(pv: Node) -> void:
	for peer in pv._bodies:
		var b: Dictionary = pv._bodies[peer]
		var item: Node3D = b.get("held_node", null) as Node3D

		if item == null or not is_instance_valid(item) or not item.is_inside_tree():
			_held_bad.erase(peer)
			continue

		var rig: Node3D = b["rig"]
		var skel: Skeleton3D = rig.get("skeleton") as Skeleton3D
		var mount: Node3D = rig.get("hand_mount_r") as Node3D

		if skel == null or mount == null:
			continue

		var bone: int = skel.find_bone("RightHand")

		if bone < 0:
			bone = skel.find_bone("mixamorig_RightHand")

		if bone < 0:
			continue

		var hand: Vector3 = (skel.global_transform * skel.get_bone_global_pose(bone)).origin

		if mount is BoneAttachment3D:
			(mount as BoneAttachment3D).on_skeleton_update()   # the attachment follows the skeleton's deferred update, later in the frame: bring it to this pose first (players thread, 23 Nov 2026)

		var d: float = mount.global_position.distance_to(hand)
		_held_looks += 1

		if d > HAND_M or item.get_parent() != mount:
			_held_bad[peer] = int(_held_bad.get(peer, 0)) + 1

			if int(_held_bad[peer]) >= 4:   # two seconds running: not one frame of a swing
				_fail("held", "player%d" % peer, "remote player %d's held item (number %d): its hand mount is %.2f m from the right hand bone%s (hand %s, mount %s)" % [
					peer, int(b.get("held", 0)), d, "" if item.get_parent() == mount else ", and the item is not on the mount", str(hand.snapped(Vector3.ONE * 0.01)), str(mount.global_position.snapped(Vector3.ONE * 0.01))])
		else:
			_held_bad.erase(peer)


# A refusal the player hears only as a cue, with no words: "silent". Waits 1.5 s for a notice that explains it.
func _check_refusals(now: int) -> void:
	while not _rejects.is_empty() and now - int(_rejects[0][1]) > 1500:
		var r: Array = _rejects.pop_front()
		var why: String = ["far", "no_tool", "full_pack", "other"][clampi(int(r[0]), 0, 3)]
		var told: bool = _notice_msec >= int(r[1]) - 200 and _notice_msec <= int(r[1]) + 1500

		if told:
			_note("refusal", "refused (%s) with a message: %s" % [why, _notices.back() if not _notices.is_empty() else ""])
		else:
			_note("refusal", "the server refused (%s) during %s with only the refusal sound, no words" % [why, r[2]])   # a cue is the design for many refusals (inventory_view refuse_cue): listed, not failed


# --- pack checks ----------------------------------------------------------------------------------------------------------------------------

func _pack_sig() -> String:
	return RobotRules.signature(client.items.inventory)


func _quiet() -> void:
	await _wait(1.0)   # the answer to what was just sent is still on its way (a round trip is up to about 0.4 s on the robots' link)
	var start: int = Time.get_ticks_msec()

	while Time.get_ticks_msec() - start < int(QUIET_LIMIT_S * 1000.0):
		if Time.get_ticks_msec() - _pack_msec >= int(QUIET_S * 1000.0) and _queue_left == 0:
			return

		await get_tree().process_frame


func _check_pack(step: String) -> void:
	await _quiet()
	var inv = client.items.inventory
	print("ROBOT %s CHECK pack %d %d %s %d %s" % [robot_name, client.multiplayer.get_unique_id(), _now_ms(), _pack_sig(), RobotRules.used(inv), step])


func _num(item: String) -> int:
	return int(client.items.table.number_of(item))


func _count(item: String) -> int:
	return int(client.items.inventory.count_of(_num(item)))


func _slot_of(item: String) -> int:
	return client.items.inventory.numbers.find(_num(item))


func _give(item: String, count: int) -> void:
	client.net.inventory_action.rpc_id(1, NetScript.ACT_ADMIN_GIVE, _num(item), 0, count, Vector3.ZERO)


# --- keys -----------------------------------------------------------------------------------------------------------------------------------

func _key(id: String, down: bool) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = int(KeyBindings.binding(id)["key"]) as Key
	ev.physical_keycode = ev.keycode
	ev.pressed = down
	Input.parse_input_event(ev)

	if down:
		_keys_down[id] = true
	else:
		_keys_down.erase(id)


func _tap(id: String) -> void:
	_key(id, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_key(id, false)
	await get_tree().process_frame


func _release_all() -> void:
	for id in _keys_down.keys():
		_key(id, false)


func _face(dir: Vector3) -> void:
	client.body.rotation.y = atan2(-dir.x, -dir.z)


func _stance_to(want: int) -> void:
	if client.stance.stance == want:
		return

	var key: String = ["", "crouch", "sit", "lie"][want] if want > 0 else ["", "crouch", "sit", "lie"][client.stance.stance]
	await _tap(key)
	await _wait(0.4)

	if client.stance.stance != want:
		client._set_stance(want)   # the key did not take (a screen up?): the same call the key makes
		await _wait(0.3)


# Holds W toward `dir` for `s` seconds; returns the ground distance moved.
func _walk_for(dir: Vector3, s: float) -> float:
	_face(dir)
	var from: Vector3 = client.body.global_position
	_key("move_forward", true)
	await _wait(s)
	last_touch = _blocker()
	_key("move_forward", false)
	await _wait(0.2)
	var to: Vector3 = client.body.global_position
	return Vector2(to.x - from.x, to.z - from.z).length()


func _blocker() -> String:
	var parts: PackedStringArray = PackedStringArray()

	for i in range(client.body.get_slide_collision_count()):
		var c: KinematicCollision3D = client.body.get_slide_collision(i)
		var o: Object = c.get_collider()
		parts.append("%s at %s (normal %s)" % [str(o.get_path()) if o is Node else str(o), str(c.get_position().snapped(Vector3.ONE * 0.1)), str(c.get_normal().snapped(Vector3.ONE * 0.01))])

	# What a step further on would hit: the body's own shape, moved half a metre the way it faces.
	var hit: KinematicCollision3D = client.body.move_and_collide(-client.body.global_transform.basis.z * 0.5, true)

	if hit != null:
		var o2: Object = hit.get_collider()
		parts.append("ahead: %s at %s (normal %s)" % [str(o2.get_path()) if o2 is Node else str(o2), str(hit.get_position().snapped(Vector3.ONE * 0.1)), str(hit.get_normal().snapped(Vector3.ONE * 0.01))])

	return "nothing touched" if parts.is_empty() else "; ".join(parts)


# Crouched with W held and next to no movement: try the same spot and way standing. Standing moves and crouching does not = the fault.
func _compare_crouch(dir: Vector3, crouch_m: float, s: float) -> void:
	var spot: Vector3 = client.body.global_position
	var touched: String = last_touch
	await _stance_to(StanceScript.STAND)
	var stand_m: float = await _walk_for(dir, s)
	await _wait(0.3)

	var free_m: float = 0.5 * client.WALK_SPEED * s   # standing walked freely: half its pace or better

	if client.swimming or not client._water_here().is_empty():
		_note("obstacle", "in water: crouched %.2f m, standing %.2f m" % [crouch_m, stand_m])
	elif stand_m >= free_m and crouch_m < 0.25 * client.WALK_SPEED * float(StanceScript.SPEED[StanceScript.CROUCH]) * s:
		_fail("blocked", "%d,%d" % [int(spot.x), int(spot.z)], "crouched with W held for %.0f s moved %.2f m; standing at the same spot the same way moved %.2f m; crouched it touched %s" % [s, crouch_m, stand_m, touched])
	else:
		_note("obstacle", "crouched %.2f m, standing %.2f m: a real obstacle (%s)" % [crouch_m, stand_m, touched])

	# Walked back toward where it was (never set in place: the other players would see a jump), then crouch again.
	if stand_m > 0.3:
		await _walk_for(-dir, s)

	await _stance_to(StanceScript.CROUCH)


# --- the plan -------------------------------------------------------------------------------------------------------------------------------

func run() -> void:
	_hook()

	while client.connected_msec == 0:
		await get_tree().process_frame

	var t0: int = Time.get_ticks_msec()

	while client.waiting_for_ground and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame

	await _wait(8.0)
	t0 = Time.get_ticks_msec()

	# Landed and loaded before any step (watch run 2, 23 Nov 2026: a robot that walked while still gliding above the spawn moved at one height
	# through the air, and the others drew it jumping tens of metres).
	while (client._world_loading() or not client.body.is_on_floor()) and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame

	if not client.body.is_on_floor():
		_fail("landed", "join", "not on the ground 68 s after joining (at %s)" % str(client.body.global_position.round()))

	print("ROBOT %s step joined: peer %d at %s" % [robot_name, client.multiplayer.get_unique_id(), str(client.body.global_position.round())])
	_hook_view()
	_step = "joined"
	await _check_pack("joined")

	if plan == "rejoin":
		_rejoin_check()
		await _rejoin_mid_check()
		await _stances()
		await _watch(20.0)
	elif plan == "watch":
		if robot_name.ends_with("1"):
			await _walker()
		else:
			await _watcher()
	elif plan == "wolves" or plan == "wolves_alone":
		if robot_name.ends_with("1"):
			await _wolf_fight()
		else:
			await _wolf_second(plan == "wolves")
	elif plan == "snares":
		await _snares()
	elif plan == "light":
		await _stances()
		await _forest_walk(40.0)
		await _watch(30.0)
	elif plan == "screens":
		await _screens()
	else:
		if admin:
			await _craft_chain()
			await _drop_pickup()

		await _stances()
		await _forest_walk(45.0)

		if admin:
			await _hunt_all(50.0)
			await _storage()
			await _eat_drink()

		await _sleep()

		if admin:
			await _quit_mid_craft()
			_quit_at_once()
			return

	await _quit()


func _rejoin_check() -> void:
	_step = "rejoin"
	var saved: String = FileAccess.get_file_as_string(SAVED_FILE).strip_edges() if FileAccess.file_exists(SAVED_FILE) else ""

	if saved == "":
		_note("rejoin", "no pack saved at the last quit to compare with")
		return

	if saved != _pack_sig():
		_fail("rejoin", "pack", "the pack after rejoining (%s, %d slots) is not the pack at quit (%s)" % [_pack_sig(), RobotRules.used(client.items.inventory), saved])
	else:
		print("ROBOT %s step rejoin: pack kept (%s)" % [robot_name, saved])


func _craft(recipe: String, count: int) -> void:
	_step = "craft " + recipe
	var r: Dictionary = _recipes.get(recipe, {})

	if r.is_empty():
		_note("craft", "no recipe %s" % recipe)
		return

	var gives: String = str(r["gives"][0])
	var before: int = _count(gives)
	var hand: int = client.held.held_slot if client.held != null else -1
	client.net.inventory_action.rpc_id(1, NetScript.ACT_CRAFT_QUEUE, int(r["number"]), 0, count, Vector3(float(hand + 1), 0.0, 0.0))
	await _wait(1.0)
	var limit: int = Time.get_ticks_msec() + int((float(r.get("craft_s", 5.0)) * float(count) * 1.5 + 15.0) * 1000.0)

	while (_queue_left > 0 or Time.get_ticks_msec() - _queue_msec < 500) and Time.get_ticks_msec() < limit:
		await get_tree().process_frame

	await _check_pack(_step)
	var got: int = _count(gives) - before

	if got < int(r["gives"][1]) * count:
		_fail("craft", recipe, "queued %d x %s; the queue emptied but the pack shows %d more %s (wanted %d)" % [count, recipe, got, gives, int(r["gives"][1]) * count])
	else:
		print("ROBOT %s step %s: +%d %s" % [robot_name, _step, got, gives])


func _craft_chain() -> void:
	_step = "gear"
	_give("plant_fibre", 45)
	_give("stick", 14)
	_give("stone", 10)
	await _check_pack("given")
	await _craft("twine", 12)
	await _craft("stone_axe", 1)
	await _craft("stone_hammer", 1)
	await _craft("wooden_spear", 1)
	await _craft("spear", 1)
	await _craft("snare", 1)
	await _craft("stone_knife", 1)


func _drop_pickup() -> void:
	_step = "drop"
	var slot: int = _slot_of("stick")

	if slot < 0:
		_note("pickup", "no stick to drop")
		return

	var before: int = _count("stick")
	var known: Dictionary = client.items._world.duplicate()   # the items already lying about (other robots drop sticks here too)
	var here: Vector3 = client.body.global_position
	# Each robot drops on its own side (they all stand at one spawn), so none picks up another's stick.
	var side: float = TAU * float(robot_name.to_int() % 6) / 6.0
	var at: Vector3 = here + Vector3.FORWARD.rotated(Vector3.UP, side) * 3.0   # 3 m out, 3 m apart: the server joins a stick to one lying close
	client.net.inventory_action.rpc_id(1, NetScript.ACT_DROP, slot, 0, 1, Vector3(at.x, here.y - 0.9, at.z))
	await _check_pack("drop")

	if _count("stick") != before - 1:
		_fail("pickup", "drop", "dropped 1 stick: the pack went %d -> %d" % [before, _count("stick")])

	# The dropped stick as the client sees it, then picked up as E does.
	_step = "pickup"
	var found: int = -1
	var limit: int = Time.get_ticks_msec() + 8000

	while found < 0 and Time.get_ticks_msec() < limit:
		for id in client.items._world:
			var w: Dictionary = client.items._world[id]

			if not known.has(id) and int(w.get("number", 0)) == _num("stick") and Vector2(w.get("pos", Vector3.INF).x - at.x, w.get("pos", Vector3.INF).z - at.z).length() < 0.8:
				found = int(id)

		await get_tree().process_frame

	if found < 0:
		_fail("pickup", "seen", "the stick dropped at %s never showed in the client's world items" % str(at.round()))
		return

	client.net.inventory_action.rpc_id(1, NetScript.ACT_PICKUP, found, 0, 0, Vector3.ZERO)
	await _check_pack("pickup")

	if _count("stick") != before:
		_fail("pickup", "pick", "picked up world item %d: sticks %d, wanted %d" % [found, _count("stick"), before])
	else:
		print("ROBOT %s step pickup: dropped and picked up a stick" % robot_name)


# Every stance that walks, each way: keys held, the body must move. Crouched next to nothing while standing moves = the fault.
func _stances() -> void:
	for st in [StanceScript.STAND, StanceScript.CROUCH]:
		_step = "stance %s" % ["stand", "crouch"][st]
		await _stance_to(st)

		for k in range(4):
			var dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, PI * 0.5 * float(k) + 0.3)
			var s: float = 2.0 if st == StanceScript.STAND else 3.0
			var moved: float = await _walk_for(dir, s)
			var expected: float = client.WALK_SPEED * float(StanceScript.SPEED[st]) * s

			if moved < 0.25 * expected:
				if st == StanceScript.CROUCH:
					await _compare_crouch(dir, moved, s)
				else:
					_note("obstacle", "standing, W held %.0f s, moved %.2f m of about %.1f (%s)" % [s, moved, expected, last_touch])

	await _stance_to(StanceScript.STAND)
	print("ROBOT %s step stances: done" % robot_name)


# The loaded trees (flora kind 0, as the chop test finds them): [[position, chunk, id], ...] within `radius` of the player.
func _trees_near(radius: float) -> Array:
	var out: Array = []
	var here: Vector3 = client.body.global_position

	for chunk in client.flora._chunks:
		var held: Dictionary = client.flora._chunks[chunk].get("items", {})

		for n in range(held.get("ids", []).size()):
			if client.flora._species.get(held["ids"][n] >> 16, {}).get("kind", 2) == 0:
				var p: Vector3 = held["positions"][n]

				if Vector2(p.x - here.x, p.z - here.z).length() < radius:
					out.append([p, chunk, held["ids"][n]])

	return out


# The middle of the thickest 16 m patch of trees within 150 m (the ferns grow under them), or NAN when none is loaded.
func _forest_spot() -> Vector3:
	var cells: Dictionary = {}

	for t in _trees_near(150.0):
		var c: Vector2i = Vector2i(floori(t[0].x / 16.0), floori(t[0].z / 16.0))
		cells[c] = int(cells.get(c, 0)) + 1

	var best: Vector2i = Vector2i.ZERO
	var most: int = 0

	for c in cells:
		if int(cells[c]) > most:
			most = int(cells[c])
			best = c

	return Vector3(NAN, NAN, NAN) if most == 0 else Vector3((float(best.x) + 0.5) * 16.0, client.body.global_position.y, (float(best.y) + 0.5) * 16.0)


# Walks (keys held, facing the target) until within `near_m` or `limit_s` runs out; sidesteps a quarter turn when stuck. True when there.
func _go_to(target: Vector3, limit_s: float, near_m: float = 2.0) -> bool:
	var end: int = Time.get_ticks_msec() + int(limit_s * 1000.0)

	while Time.get_ticks_msec() < end:
		var here: Vector3 = client.body.global_position
		var to: Vector3 = Vector3(target.x - here.x, 0.0, target.z - here.z)

		if to.length() < near_m:
			return true

		var moved: float = await _walk_for(to.normalized(), 1.0)

		if moved < 0.1 * client.WALK_SPEED * float(StanceScript.SPEED[client.stance.stance]):
			await _walk_for(to.normalized().rotated(Vector3.UP, PI * 0.5 * (1.0 if randf() < 0.5 else -1.0)), 1.5)

	return false


# Crouched through the thickest trees near the spawn, from trunk to trunk (the ferns are under them), as a player sneaking up on game does.
# Dave's friends, 23 Nov 2026: crouch-walking blocked about 90% of the way under trees near ferns, fine standing.
func _forest_walk(s: float) -> void:
	_step = "to the forest"
	var spot: Vector3 = _forest_spot()

	if is_nan(spot.x):
		_note("forest", "no trees loaded within 150 m")
		return

	var there: bool = await _go_to(spot, 60.0, 4.0)
	print("ROBOT %s step to the forest: %s, %d trees within 20 m" % [robot_name, "there" if there else "short of it", _trees_near(20.0).size()])
	_step = "forest crouch"
	await _stance_to(StanceScript.CROUCH)
	var end: int = Time.get_ticks_msec() + int(s * 1000.0)
	var total: float = 0.0
	var stuck: int = 0
	var visited: Dictionary = {}
	var crouch_step: float = client.WALK_SPEED * float(StanceScript.SPEED[StanceScript.CROUCH])

	while Time.get_ticks_msec() < end:
		# The nearest trunk not passed yet, aimed a metre to its side so the walk brushes its ferns.
		var here: Vector3 = client.body.global_position
		var next: Array = []
		var best_d: float = INF

		for t in _trees_near(25.0):
			var key: String = "%d" % int(t[2])
			var d: float = Vector2(t[0].x - here.x, t[0].z - here.z).length()

			if not visited.has(key) and d > 1.5 and d < best_d:
				best_d = d
				next = t

		var dir: Vector3 = Vector3(1.0, 0.0, 0.3).normalized()

		if not next.is_empty():
			visited["%d" % int(next[2])] = true
			var to: Vector3 = Vector3(next[0].x - here.x, 0.0, next[0].z - here.z)
			dir = (to + to.normalized().cross(Vector3.UP) * 1.0).normalized()

		var legs: int = clampi(int(best_d / (crouch_step * 2.0)) + 1, 1, 4)

		for leg in range(legs):
			var moved: float = await _walk_for(dir, 2.0)
			total += moved

			if moved < 0.25 * crouch_step * 2.0:
				stuck += 1
				await _compare_crouch(dir, moved, 2.0)
				break

	await _stance_to(StanceScript.STAND)
	print("ROBOT %s step forest crouch: %.0f m in %.0f s past %d trunks, %d stops" % [robot_name, total, s, visited.size(), stuck])


# Spear in hand, after one species at a time (rabbit, then deer, then wolf: the first hours' game). Every robot picks the same animal (the lowest
# id of that species it draws), so two or more are on one animal, as players hunting together. Prints a HUNT line per fight: strikes sent,
# hits the server reported on it, its health share last seen, whether it went down, this robot's health before and after.
# robot_check.py adds the robots' lines up per animal: a fight nobody can win, or one that kills a robot, is a finding.
func _hunt_all(s_each: float) -> void:
	var spear: int = _slot_of("spear")

	if spear < 0:
		spear = _slot_of("wooden_spear")

	if spear < 0:
		_note("hunt", "no spear")
		return

	if spear != 0:
		client.net.inventory_action.rpc_id(1, NetScript.ACT_MOVE, spear, 0, 0, Vector3.ZERO)   # into slot 0: hotbar key 1, in hand
		await _check_pack("spear to hand")

	var found: int = 0

	for sp in [1, 2, 3]:
		var ok: bool = await _hunt(sp, s_each)
		found += 1 if ok else 0

	if found == 0:   # none near this spawn this time: the nearest other wild ground animal, so the fight is still tried
		var me: Vector3 = client.body.global_position
		var best: int = -1
		var best_d: float = 120.0

		for row in client._animal_view_node.drawn_positions():
			var sp2: int = int(_species.get(int(row[0]), 0))
			var d: float = (row[1] as Vector3).distance_to(me)

			if sp2 in WILD_GROUND and d < best_d:
				best_d = d
				best = sp2

		if best > 0:
			var _tried: bool = await _hunt(best, s_each)

	await _check_pack("hunt")


func _hunt(sp: int, s: float) -> bool:
	_step = "hunt %s" % SPECIES_NAME.get(sp, str(sp))
	var end: int = Time.get_ticks_msec() + int(s * 1000.0)
	var strikes: int = 0
	var target: int = -1
	var health_before: int = _health
	var start_ms: int = Time.get_ticks_msec()
	var looked: int = 0

	while Time.get_ticks_msec() < end:
		var me: Vector3 = client.body.global_position
		var at: Vector3 = Vector3.INF
		var drawn: Dictionary = {}

		for row in client._animal_view_node.drawn_positions():
			drawn[int(row[0])] = row[1]

		if target >= 0 and not drawn.has(target):
			break   # gone: down (the fell signal says so), fled out of range or into its burrow

		if target < 0:
			for id in drawn:
				if int(_species.get(id, 0)) == sp and (drawn[id] as Vector3).distance_to(me) < 120.0 and (target < 0 or int(id) < target):
					target = int(id)

			if target < 0:
				if Time.get_ticks_msec() - start_ms > 15000:
					break   # none of this kind about: the plan goes on (a robot that looks the whole time runs out of its pass)

				looked += 1
				await _walk_for(Vector3.FORWARD.rotated(Vector3.UP, float(looked) * 2.4), 3.0)   # look about (the same turns for every robot)
				continue

			_hits[target] = 0
			print("ROBOT %s step hunt: after %s %d at %s" % [robot_name, SPECIES_NAME.get(sp, sp), target, str((drawn[target] as Vector3).round())])

		at = drawn[target]
		var to: Vector3 = at - me
		to.y = 0.0
		var d: float = to.length()

		if d > 1.6:
			_face(to.normalized())
			_key("move_forward", true)
			_key("run", d > 6.0)
			await _wait(0.25)
			continue

		_key("move_forward", false)
		_key("run", false)
		_face(to.normalized())
		_strike_at(to.normalized())
		strikes += 1
		await _wait(0.8)

	_release_all()
	await _wait(1.0)

	if target < 0:
		print("ROBOT %s HUNT %s none 0 0 0 none %d %d %.0f found none" % [robot_name, SPECIES_NAME.get(sp, sp), health_before, _health, s])
		return false

	var down: bool = _fell.has(target)
	print("ROBOT %s HUNT %s %d %d %d %.1f %s %d %d %.0f" % [robot_name, SPECIES_NAME.get(sp, sp), target, strikes, int(_hits.get(target, 0)),
		float(_hp.get(target, 1.0)), "down" if down else "up", health_before, _health, float(Time.get_ticks_msec() - start_ms) / 1000.0])
	return true


const WICKER_BASKET_BP := 157   # data/items/blueprints.json wicker_basket: 8 sticks, 4 twine, the knife (Dave 21 Nov 2026: the knife makes a 6-slot basket)


# Build a wicker basket with the knife in hand, put twine in, take it out: the pack, the basket's contents and the server agree each time.
func _storage() -> void:
	_step = "storage"
	_give("stick", 8)
	_give("twine", 4)
	await _check_pack("storage given")
	var knife: int = _slot_of("stone_knife")

	if knife < 0:
		_note("storage", "no knife")
		return

	if knife != 0:
		client.net.inventory_action.rpc_id(1, NetScript.ACT_MOVE, knife, 0, 0, Vector3.ZERO)
		await _check_pack("knife to hand")

	var known: Dictionary = client.items._world.duplicate()
	var said_from: int = _notices.size()
	var here: Vector3 = client.body.global_position
	var side: float = TAU * float(robot_name.to_int() % 6) / 6.0 + 0.5
	var spot: Vector3 = here + Vector3.FORWARD.rotated(Vector3.UP, side) * 2.5
	var ground: float = float(client.items._ground_below.call(spot))
	spot.y = ground if not is_nan(ground) else here.y - 0.9
	client.net.inventory_action.rpc_id(1, NetScript.ACT_PLACE_BLUEPRINT, WICKER_BASKET_BP, 0, 0, spot)
	await _check_pack("basket built")
	var basket: int = -1
	var limit: int = Time.get_ticks_msec() + 8000

	while basket < 0 and Time.get_ticks_msec() < limit:
		for id in client.items._world:
			var w: Dictionary = client.items._world[id]

			if not known.has(id) and Vector2(w.get("pos", Vector3.INF).x - spot.x, w.get("pos", Vector3.INF).z - spot.z).length() < 1.5:
				basket = int(id)

		await get_tree().process_frame

	if basket < 0:
		var said: Array = _notices.slice(said_from)

		if said.is_empty():
			_fail("storage", "built", "placed the wicker basket blueprint at %s with the knife in hand and its materials; no new world item came there, and no message said why" % str(spot.round()))
		else:
			_note("storage", "the basket was refused at %s: %s" % [str(spot.round()), str(said)])   # a spot the rules refuse (a tree, a slope), said in words

		return

	var contents: Array = [null]
	var got_contents := func(id: int, bytes: PackedByteArray) -> void:
		if id == basket:
			var inv = InventoryScript.new(client.items.table)
			inv.from_bytes(bytes)
			contents[0] = inv
	client.net.chest_received.connect(got_contents)
	client.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_OPEN, basket, 0, 0, Vector3.ZERO)
	await _wait(1.5)

	if contents[0] == null:
		_fail("storage", "open", "opened the basket (world item %d): no contents came" % basket)
		client.net.chest_received.disconnect(got_contents)
		return

	var twine_before: int = _count("twine")
	client.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_PUT, _slot_of("twine"), basket, 2, Vector3.ZERO)
	await _check_pack("put in basket")
	var in_box: int = int(contents[0].count_of(_num("twine")))

	if _count("twine") != twine_before - 2 or in_box != 2:
		_fail("storage", "put", "put 2 twine in the basket: pack twine %d -> %d, the basket shows %d" % [twine_before, _count("twine"), in_box])

	client.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_TAKE, contents[0].numbers.find(_num("twine")), basket, 2, Vector3.ZERO)
	await _check_pack("take from basket")

	if _count("twine") != twine_before or int(contents[0].count_of(_num("twine"))) != 0:
		_fail("storage", "take", "took 2 twine back: pack twine %d (wanted %d), the basket shows %d" % [_count("twine"), twine_before, int(contents[0].count_of(_num("twine")))])
	else:
		print("ROBOT %s step storage: built a wicker basket (%d slots), put 2 twine in and took them out" % [robot_name, int(contents[0].slot_count)])

	client.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_CLOSE, basket, 0, 0, Vector3.ZERO)
	client.net.chest_received.disconnect(got_contents)


# Walk to the nearest water the client knows (up to 60 s) and drink; eat a wild apple. The server's thirst and hunger must move.
func _eat_drink() -> void:
	_step = "eat"
	_give("wild_apples", 2)
	await _check_pack("food given")
	var hunger_before: int = _hunger
	var slot: int = _slot_of("wild_apples")

	if slot >= 0:
		client.net.inventory_action.rpc_id(1, NetScript.ACT_EAT, slot, 0, 0, Vector3.ZERO)
		await _check_pack("eat")

		if _count("wild_apples") != 1:
			_fail("eat", "apple", "ate a wild apple: %d left of 2" % _count("wild_apples"))
		else:
			print("ROBOT %s step eat: hunger %d -> %d" % [robot_name, hunger_before, _hunger])

	_step = "drink"
	var water: Vector3 = await _find_water()

	if is_nan(water.x):
		_note("drink", "no water in any loaded chunk")
		return

	var there: bool = await _go_to(water, 60.0, 2.5)
	var thirst_before: int = _thirst

	for n in range(3):
		client.net.inventory_action.rpc_id(1, NetScript.ACT_DRINK, -1, 0, 0, Vector3.ZERO)
		await _wait(1.0)

	await _wait(1.5)
	print("ROBOT %s step drink: %s water %.0f m away, thirst %d -> %d" % [robot_name, "at the" if there else "short of the", Vector2(water.x - client.body.global_position.x, water.z - client.body.global_position.z).length(), thirst_before, _thirst])

	if there and _thirst == thirst_before and thirst_before < 100:
		_note("drink", "drank 3 times at the water's edge and thirst stayed %d" % _thirst)


# The nearest wet corner of a loaded flora chunk's water grid (lag_run.gd _find_water), one chunk a frame.
func _find_water() -> Vector3:
	var here: Vector3 = client.body.global_position
	var best: Vector3 = Vector3(NAN, NAN, NAN)
	var best_d: float = INF
	var chunk_m: float = float(client.flora.chunk_m)

	for chunk in client.flora._chunks.keys():
		var grid: Dictionary = client.flora._chunks.get(chunk, {}).get("grid", {})

		if int(grid.get("wet", 0)) == 0:
			continue

		var spacing: float = float(grid["spacing"])
		var count: int = int(grid["count"])
		var levels = grid["levels"]

		for j in range(count):
			for i in range(count):
				if is_nan(float(levels[j * count + i])):
					continue

				var x: float = float(chunk.x) * chunk_m + float(i) * spacing
				var z: float = float(chunk.y) * chunk_m + float(j) * spacing
				var d: float = Vector2(x - here.x, z - here.z).length()

				if d < best_d:
					best_d = d
					best = Vector3(x, float(levels[j * count + i]), z)

		await get_tree().process_frame

	return best


# Quit in the middle of a queued craft (rejoin_mid then checks): nothing may be lost or made from nothing. The fibre and twine before the queue
# are saved; after rejoining, once the queue is done or gone, fibre + 3 x twine must be what it was (twine is 3 fibre, recipe 1).
func _quit_mid_craft() -> void:
	_step = "quit mid-craft"
	_give("plant_fibre", 18)
	await _check_pack("mid-craft given")
	var worth: int = _count("plant_fibre") + 3 * _count("twine")
	var f: FileAccess = FileAccess.open(MID_FILE, FileAccess.WRITE)

	if f != null:
		f.store_string(str(worth))
		f.close()

	client.net.inventory_action.rpc_id(1, NetScript.ACT_CRAFT_QUEUE, int(_recipes["twine"]["number"]), 0, 6, Vector3(float(client.held.held_slot + 1), 0.0, 0.0))
	await _wait(3.5)   # one or two of six twines made: the rest still queued
	print("ROBOT %s step quit mid-craft: queue %d left, fibre and twine worth %d fibre" % [robot_name, _queue_left, worth])


func _rejoin_mid_check() -> void:
	_step = "rejoin mid-craft"
	var saved: String = FileAccess.get_file_as_string(MID_FILE).strip_edges() if FileAccess.file_exists(MID_FILE) else ""

	if saved == "":
		return

	var limit: int = Time.get_ticks_msec() + 40000

	while _queue_left > 0 and Time.get_ticks_msec() < limit:
		await get_tree().process_frame

	await _check_pack("rejoin mid-craft")
	var worth: int = _count("plant_fibre") + 3 * _count("twine")

	if worth != int(saved):
		_fail("rejoin", "mid-craft", "quit with 6 twine queued: fibre + 3 x twine was %s, after rejoining %d (fibre %d, twine %d)" % [saved, worth, _count("plant_fibre"), _count("twine")])
	else:
		print("ROBOT %s step rejoin mid-craft: nothing lost (worth %d fibre)" % [robot_name, worth])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(MID_FILE))


# How this robot stands and moves (POSE) and how it draws every other player (SEES), twice a second, on the shared wall clock.
# robot_check.py joins them: the stance another robot is drawn in, its clip, and how far its drawn body is from where it really was.
func _pose_lines(delta: float) -> void:
	_pose_t += delta

	if _pose_t < POSE_EVERY_S:
		return

	_pose_t = 0.0
	var me: Vector3 = client.body.global_position
	var v: Vector3 = client.body.velocity
	print("ROBOT %s POSE %d %d %d %.2f %.2f %.2f %.2f" % [robot_name, client.multiplayer.get_unique_id(), _now_ms(), client.stance.stance, me.x, me.y, me.z, Vector2(v.x, v.z).length()])
	var pv: Node = client._player_view

	if pv == null:
		return

	for peer in pv._bodies:
		var b: Dictionary = pv._bodies[peer]
		var p: Vector3 = (b["node"] as Node3D).global_position
		var rig: Node3D = b["rig"]
		var clip: String = str(rig.current()) if rig.has_method("current") else ""
		print("ROBOT %s SEES %d %d %d %.2f %.2f %.2f %s" % [robot_name, int(peer), _now_ms(), int(b["state"]) & 3, p.x, p.y, p.z, clip if clip != "" else "-"])


func _sleep() -> void:
	_step = "sleep"
	await _stance_to(StanceScript.LIE)
	var slept: bool = await _fall_asleep()
	await _wait(6.0)
	client.net.inventory_action.rpc_id(1, NetScript.ACT_SLEEP, 0, 0, 0, Vector3.ZERO)
	await _wait(2.0)

	if slept and client.items.asleep:
		_fail("sleep", "wake", "still asleep 2 s after asking to wake")

	await _stance_to(StanceScript.STAND)
	print("ROBOT %s step sleep: lay down, %s, woke" % [robot_name, "slept" if slept else "never fell asleep"])


# Lying down: full energy cannot sleep (server_items _sleep, Dave 21 Oct 2026), so an admin robot is made tired first. True once the server
# says it sleeps (items.asleep). A refusal without a reason is a FAIL only when the robot was tired.
func _fall_asleep() -> bool:
	if admin:
		client.net.inventory_action.rpc_id(1, NetScript.ACT_ADMIN_ENERGY, 0, 0, 40, Vector3.ZERO)
		await _wait(1.0)

	client.net.inventory_action.rpc_id(1, NetScript.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	var t0: int = Time.get_ticks_msec()

	while Time.get_ticks_msec() - t0 < 4000:
		if client.items.asleep:
			return true

		await get_tree().process_frame

	if admin:
		_fail("sleep", "asleep", "lying, energy set to 40, asked to sleep: not asleep after 4 s (notices: %s)" % str(_notices.slice(-3)))
	else:
		_note("sleep", "not asleep after 4 s (full energy cannot sleep)")

	return false


# --- plan watch: Robot 1 walks, stops, runs, swings and sleeps; Robot 2 stands and logs how it draws Robot 1 every frame (W lines).
# tools/robot_watch.py reads the two logs (same machine, same clock) and prints a PASS or FAIL per measure (players thread, 23 Nov 2026).

func _event(kind: String, extra: String = "") -> void:
	var p: Vector3 = client.body.global_position
	print("ROBOT %s EVENT %s %d %.2f %.2f %.2f %s" % [robot_name, kind, _now_ms(), p.x, p.y, p.z, extra])


func _walker() -> void:
	_step = "walker"
	var t0: int = Time.get_ticks_msec()

	while client._player_view == null or client._player_view._bodies.is_empty():
		if Time.get_ticks_msec() - t0 > 60000:
			_fail("watch", "nobody", "the watcher never came in sight within 60 s")
			return

		await _wait(0.5)

	await _wait(4.0)   # the watcher settles after its own join

	if admin and _slot_of("stone_axe") < 0:
		_give("stone_axe", 1)   # an empty pack: slot 0, in hand, so the others draw it and its chop
		await _check_pack("axe in hand")

	for leg in [[Vector3.RIGHT, 4.0, false], [Vector3.FORWARD, 6.0, false], [Vector3.BACK, 6.0, false], [Vector3.FORWARD, 4.0, true], [Vector3.BACK, 4.0, true], [Vector3.LEFT, 4.0, false]]:
		var dir: Vector3 = leg[0]
		_face(dir)
		var from: Vector3 = client.body.global_position
		var ms0: int = _now_ms()
		_event("walk", "%.2f %.2f %s" % [dir.x, dir.z, "run" if bool(leg[2]) else "walk"])
		_key("run", bool(leg[2]))
		_key("move_forward", true)
		await _wait(float(leg[1]))
		_key("move_forward", false)
		_key("run", false)
		var to: Vector3 = client.body.global_position
		_event("stop", "%.2f" % (Vector2(to.x - from.x, to.z - from.z).length() / maxf(float(_now_ms() - ms0) / 1000.0, 0.1)))
		await _wait(3.5)

	for i in range(3):
		_event("swing")
		client.net.inventory_action.rpc_id(1, NetScript.ACT_HIT, 0, NetScript.HIT_BOULDER, 1, Vector3.ZERO)   # a blow at nothing: the server counts the swing (server_players note_action) and refuses the hit
		await _wait(2.5)

	await _stance_to(StanceScript.LIE)
	var _slept: bool = await _fall_asleep()
	_event("sleep_on")
	await _wait(6.0)
	client.net.inventory_action.rpc_id(1, NetScript.ACT_SLEEP, 0, 0, 0, Vector3.ZERO)
	_event("sleep_off")
	await _wait(2.0)
	await _stance_to(StanceScript.STAND)
	await _wait(2.0)
	_event("end")


func _watcher() -> void:
	_step = "watcher"
	var seen: bool = false
	var gone_ms: int = 0
	var t0: int = Time.get_ticks_msec()

	while Time.get_ticks_msec() - t0 < 240000:
		await get_tree().process_frame
		var pv: Node = client._player_view

		if pv == null:
			continue

		if pv._bodies.is_empty():
			if seen and gone_ms == 0:
				gone_ms = Time.get_ticks_msec()

			if seen and Time.get_ticks_msec() - gone_ms > 3000:
				break

			continue

		seen = true
		gone_ms = 0

		for peer in pv._bodies:
			var b: Dictionary = pv._bodies[peer]
			var p: Vector3 = (b["node"] as Node3D).global_position
			var rig: Node3D = b["rig"]
			var clip: String = str(rig.current()) if rig.has_method("current") else ""
			var held_d: float = -1.0
			var item: Node3D = b.get("held_node", null) as Node3D

			if item != null and is_instance_valid(item) and item.is_inside_tree():
				held_d = INF

				for m in ["hand_mount_r", "hand_mount_l"]:
					var mount: Node3D = rig.get(m) as Node3D

					if mount != null:
						held_d = minf(held_d, item.global_position.distance_to(mount.global_position))

			print("ROBOT %s W %d %d %.3f %.3f %.3f %d %s %.3f" % [robot_name, int(peer), _now_ms(), p.x, p.y, p.z, int(b["state"]), clip if clip != "" else "-", held_d])

	if not seen:
		_fail("watch", "nobody", "the walker never came in sight")


# --- plan wolves: the battle ring (#1664). Robot 1 carries raw meat alone more than town_keep_m from the town, an admin pack is placed
# 25 m off; once the rush begins it is given a spear and fights back. Robot 2 stays at the spawn (wolves_alone) or waits 40 m short of it and runs in 3 s into the rush
# (wolves) to see whether a second player breaks it. Robot 1 writes the rush to ROBOT_SHARE/wolves_rush.txt for Robot 2 (robots.sh sets it).
const WOLF := 3
const WOLF_FAR_M := 380.0     # beyond server_wolves town_keep_m (300 m) from the town, whose middle is near the spawn
const MAIM_HP := 25           # animals.json wolf maim_hp: bites stop taking health below this
const RUSH_FILE := "wolves_rush.txt"


func _share_path() -> String:
	return OS.get_environment("ROBOT_SHARE").path_join(RUSH_FILE) if OS.get_environment("ROBOT_SHARE") != "" else ""


# Runs (shift and W) toward `target`, aiming again every half second, a sidestep when stuck. True when within `near_m`.
func _run_to(target: Vector3, limit_s: float, near_m: float = 3.0) -> bool:
	var end: int = Time.get_ticks_msec() + int(limit_s * 1000.0)
	_key("run", true)

	while Time.get_ticks_msec() < end:
		var here: Vector3 = client.body.global_position
		var to: Vector3 = Vector3(target.x - here.x, 0.0, target.z - here.z)

		if to.length() < near_m:
			_release_all()
			return true

		_face(to.normalized())
		_key("move_forward", true)
		await _wait(0.5)

		if Vector2(client.body.global_position.x - here.x, client.body.global_position.z - here.z).length() < 0.5:
			_face(to.normalized().rotated(Vector3.UP, PI * 0.5 * (1.0 if randf() < 0.5 else -1.0)))
			await _wait(1.0)

	_release_all()
	return false


# One jab with the slot-0 item, judged where this screen drew the animals (protocol 155, held_item.gd _melee_strike): the server's lag
# allowance, as a player's own blow gets it. Prints `JAB <seen> <present> me x z` and each animal drawn within 6 m (id:x,z) to set beside
# the server's AUDIT strike line of the same seen time.
func _strike_at(dir: Vector3) -> void:
	var seen: Array = client._animal_view_node.seen_server_ms() if client._animal_view_node != null else [0, 0]
	client.net.inventory_action.rpc_id(1, NetScript.ACT_STRIKE, 0, int(seen[0]), int(seen[1]), dir)
	var me: Vector3 = client.body.global_position
	var near: PackedStringArray = PackedStringArray()

	for row in client._animal_view_node.drawn_positions():
		var at: Vector3 = row[1]

		if Vector2(at.x - me.x, at.z - me.z).length() < 6.0:
			near.append("%d:%.1f,%.1f" % [int(row[0]), at.x, at.z])

	print("ROBOT %s JAB %d %d me %.1f,%.1f fps %d drawn %s" % [robot_name, int(seen[0]), int(seen[1]), me.x, me.z, Engine.get_frames_per_second(), " ".join(near)])


func _wolves_drawn() -> Dictionary:
	var out: Dictionary = {}

	for row in client._animal_view_node.drawn_positions():
		if int(_species.get(int(row[0]), 0)) == WOLF:
			out[int(row[0])] = row[1]

	return out


func _wolf_fight() -> void:
	_step = "wolves out"

	if not admin:
		_note("wolves", "the wolf fight needs --robot-admin (raw meat, the pack and the spear are admin gifts): nothing done")
		return

	var start: Vector3 = client.body.global_position
	_give("raw_meat", 3)
	await _check_pack("raw meat")
	var far: Vector3 = start + Vector3(0.0, 0.0, -WOLF_FAR_M)
	await _run_to(far, 120.0, 6.0)
	var out_m: float = Vector2(client.body.global_position.x - start.x, client.body.global_position.z - start.z).length()

	if out_m < 320.0:
		_note("wolves", "only %.0f m from the spawn after 120 s of running: the pack may keep off (town_keep_m)" % out_m)

	await _wait(2.0)
	_step = "wolves"
	var me: Vector3 = client.body.global_position
	var facing: Vector3 = -client.body.global_transform.basis.z
	client.net.admin_place.rpc_id(1, "animal", me + facing * 25.0, "wolf")
	_event("pack_placed", "%.0f" % out_m)
	var h0: int = _health
	var last_h: int = _health
	var bites: Array = []            # unix ms of each bite (health fell)
	var strikes: int = 0
	var strike_ms: int = 0
	var most_close: int = 0
	var closest: float = INF         # the nearest any wolf was drawn during the rush
	var rush_ms: int = 0
	var armed: bool = false
	var quiet_since: int = 0
	var notices_from: int = _notices.size()
	var outcome: String = "no rush"
	var end: int = Time.get_ticks_msec() + 120000

	while Time.get_ticks_msec() < end:
		await _wait(0.1)
		var now: int = _now_ms()
		me = client.body.global_position

		if _health >= 0 and last_h >= 0 and _health < last_h:
			bites.append(now)

		last_h = _health

		for i in range(notices_from, _notices.size()):
			var t: String = str(_notices[i]).to_lower()

			if "wolves" in t and rush_ms == 0 and ("coming" in t or "rush" in t):
				rush_ms = now
				_event("rush", "\"%s\"" % str(_notices[i]).replace(" ", "_"))
				var f: FileAccess = FileAccess.open(_share_path(), FileAccess.WRITE) if _share_path() != "" else null

				if f != null:
					f.store_string("%f %f %f" % [me.x, me.y, me.z])
					f.close()

		notices_from = _notices.size()

		if rush_ms > 0 and not armed:
			armed = true
			_give("spear", 1)
			await _wait(0.6)
			var sp: int = _slot_of("spear")

			if sp > 0:
				client.net.inventory_action.rpc_id(1, NetScript.ACT_MOVE, sp, 0, 0, Vector3.ZERO)   # into slot 0: in hand

		var wolves: Dictionary = _wolves_drawn()
		var close: int = 0
		var nearest: Vector3 = Vector3.INF

		for id in wolves:
			var d: float = Vector2(wolves[id].x - me.x, wolves[id].z - me.z).length()
			close += 1 if d < 3.0 else 0

			if nearest == Vector3.INF or d < Vector2(nearest.x - me.x, nearest.z - me.z).length():
				nearest = wolves[id]

		most_close = maxi(most_close, close)

		if rush_ms > 0 and nearest != Vector3.INF:
			closest = minf(closest, Vector2(nearest.x - me.x, nearest.z - me.z).length())

		var gap: float = Vector2(nearest.x - me.x, nearest.z - me.z).length() if nearest != Vector3.INF else INF

		if armed and gap < 4.0 and now - strike_ms > 1000:   # the spear recovers (server_items recover_ms): a faster jab is dropped unheard
			strike_ms = now   # as a player would: a step in when it is just out of reach, then the jab
			var to: Vector3 = Vector3(nearest.x - me.x, 0.0, nearest.z - me.z).normalized()
			_face(to)

			if gap > 2.5:   # step in, then jab only if the drawn wolf is now within 2.5 m (spear reach 3.0): a jab from farther is a fair miss
				_key("move_forward", true)
				await _wait(0.2)
				_key("move_forward", false)
				var again: Dictionary = _wolves_drawn()
				me = client.body.global_position
				gap = INF

				for id in again:
					gap = minf(gap, Vector2(again[id].x - me.x, again[id].z - me.z).length())

				if gap <= 2.5:
					_strike_at(to)
			else:
				_strike_at(to)
			strikes += 1 if gap <= 2.5 else 0

		if _health >= 0 and _health <= MAIM_HP:
			outcome = "maimed"
			break

		var near_any: bool = nearest != Vector3.INF and Vector2(nearest.x - me.x, nearest.z - me.z).length() < 20.0

		if rush_ms > 0:
			if near_any:
				quiet_since = 0
			elif quiet_since == 0:
				quiet_since = now
			elif now - quiet_since > 8000:
				outcome = "pack gone"
				break

	var wolf_hits: int = 0

	for id in _hits:
		wolf_hits += int(_hits[id]) if int(_species.get(int(id), 0)) == WOLF else 0

	var gaps: PackedStringArray = PackedStringArray()

	for i in range(1, bites.size()):
		gaps.append("%.1f" % (float(bites[i] - bites[i - 1]) / 1000.0))

	print("ROBOT %s WOLVES outcome %s, rush %s, %d bites (gaps s: %s), %d strikes, %d hits on wolves, most wolves within 3 m %d, nearest drawn %.2f m, health %d -> %d, %.0f s" % [
		robot_name, outcome, "yes" if rush_ms > 0 else "no", bites.size(), ",".join(gaps) if not gaps.is_empty() else "-", strikes, wolf_hits, most_close, closest, h0, _health,
		float(_now_ms() - (rush_ms if rush_ms > 0 else _now_ms())) / 1000.0])
	await _wait(3.0)


# The second player: stays at the spawn (come = false), or waits 40 m short of Robot 1 and, 3 s into the rush, runs to it.
func _wolf_second(come: bool) -> void:
	_step = "wolves second"
	var end: int = Time.get_ticks_msec() + 240000
	var path: String = _share_path()

	if come:   # out after Robot 1, waiting 40 m short of it (well beyond the pack's group_m 10 m), so it can come in a few seconds into the rush
		await _run_to(client.body.global_position + Vector3(0.0, 0.0, -(WOLF_FAR_M - 40.0)), 120.0, 6.0)

	while Time.get_ticks_msec() < end and (path == "" or not FileAccess.file_exists(path)):
		await _wait(1.0)

	if not come or path == "" or not FileAccess.file_exists(path):
		await _wait(60.0)
		return

	var p: PackedStringArray = FileAccess.get_file_as_string(path).split(" ")
	await _wait(3.0)
	_event("coming")
	var there: bool = await _run_to(Vector3(float(p[0]), float(p[1]), float(p[2])), 90.0, 5.0)
	_event("arrived" if there else "not_there")
	await _wait(30.0)


# --- screens (23 Nov 2026: the client side a tester touches in the first hours) --------------------------------------------------------------

func _esc() -> void:
	for down in [true, false]:
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = down
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame


func _screens() -> void:
	var view = client.items

	if admin:
		_step = "screens kit"
		for kit in [["plant_fibre", 60], ["stick", 30], ["stone", 20], ["firewood", 10], ["rock", 6]]:
			_give(str(kit[0]), int(kit[1]))

		await _check_pack("given")

	# Each screen opens on its key and closes on Esc, and nothing is left open.
	for id in ["inventory", "character", "journal", "goals", "map"]:
		_step = "screen " + id
		await _tap(id)
		await _wait(1.0)

		if not view.screen_open():
			_fail("screen", id, "the %s key opened no screen" % id)

		await _esc()
		await _wait(0.6)

		if view.screen_open():
			_fail("screen", id + "_close", "Esc did not close the %s screen" % id)
			await _esc()
		else:
			print("ROBOT %s step screen %s: opened and closed" % [robot_name, id])

	_step = "screen menu"
	await _esc()
	await _wait(0.8)

	if not client.game_menu.root.visible:
		_fail("screen", "menu", "Esc in the world opened no game menu")

	await _esc()
	await _wait(0.6)

	if client.game_menu.root.visible:
		_fail("screen", "menu_close", "Esc did not close the game menu")

	# Every page of the game menu (Settings, Display, Sound, Controls, ...) builds and shows without a script error.
	_step = "menu pages"
	await _esc()
	await _wait(0.5)
	var pages: Array = client.game_menu._pages.keys()

	for page in pages:
		client.game_menu.show_page(str(page))
		await _wait(0.3)

	client.game_menu.show_page("main")
	await _esc()
	await _wait(0.5)

	if client.game_menu.root.visible:
		_fail("screen", "menu_pages_close", "Esc did not close the game menu after its pages")
		await _esc()

	print("ROBOT %s step menu pages: %d shown" % [robot_name, pages.size()])

	# The skills page (Dave 23 Nov 2026): every skill reads "value / cap" with the cap a band top (25, 50, 75, 100) and the value under it.
	_step = "skills page"
	await _tap("character")
	await _wait(1.5)
	var rows: int = 0
	var shape: RegEx = RegEx.create_from_string("^(\\d+) / (\\d+)$")
	var pending: Array = [view._character._panel] if view._character != null and view._character._panel != null else []

	while not pending.is_empty():
		var n: Node = pending.pop_back()
		pending.append_array(n.get_children())

		if n is Label:
			var m: RegExMatch = shape.search((n as Label).text)

			if m != null:
				rows += 1
				var value: int = int(m.get_string(1))
				var cap: int = int(m.get_string(2))

				if not cap in [25, 50, 75, 100] or value > cap or (cap == 25 and value > 24):
					_fail("skills", (n as Label).text, "the skills page shows %s: the cap is not a band top or the value is over it" % (n as Label).text)

	if rows == 0:
		_note("skills", "no \"value / cap\" rows found on the character screen")

	print("ROBOT %s step skills page: %d skill rows" % [robot_name, rows])
	await _esc()
	await _wait(0.5)

	# Every recipe whose Craft button is lit, pressed through the screen: it must queue, or the server must say why not.
	await _press_lit(view, "craft lit", func(_r: Dictionary) -> bool: return true, 180.0)

	# Split and drop through the screen.
	_step = "split"
	var slot: int = _slot_of("plant_fibre")

	if slot >= 0 and client.items.inventory.counts[slot] >= 2:
		var total: int = _count("plant_fibre")
		var stacks: int = 0

		for k in client.items.inventory.slot_count:
			stacks += 1 if client.items.inventory.numbers[k] == _num("plant_fibre") else 0

		view._selected = slot
		view._split_selected()
		await _check_pack("split")
		var after: int = 0

		for k in client.items.inventory.slot_count:
			after += 1 if client.items.inventory.numbers[k] == _num("plant_fibre") else 0

		if _count("plant_fibre") != total or after != stacks + 1:
			_fail("pack", "split", "split: %d fibre in %d stacks became %d in %d" % [total, stacks, _count("plant_fibre"), after])

		_step = "drop one"
		total = _count("plant_fibre")
		view._selected = _slot_of("plant_fibre")
		view._drop_selected(false)
		await _check_pack("drop one")

		if _count("plant_fibre") != total - 1:
			_fail("pack", "drop_one", "dropping one fibre left %d of %d" % [_count("plant_fibre"), total])
		else:
			print("ROBOT %s step split and drop: one stack became two, one fibre dropped" % robot_name)

	# A container the first hours give (the knife's Wicker basket): placed, opened, Store all, Take all, Sort, closed on Esc.
	if admin:
		await _container_round(view)

	# The hammer's build screen: opens on R with a hammer in hand, and every row it shows as covered is placed or refused with words.
	if admin:
		await _build_round()

	# Stations the first hours make (workbench, food preparation table, tailor's table, drying rack): built, then every lit recipe made there pressed.
	if admin:
		await _station_round(view)

	# Worn slots and a worn bag: put on, the bag opened, Store all and Take all through it, taken off; nothing lost.
	if admin:
		await _worn_round(view)

	# Quit with the screen open: the rejoin pass checks the pack came back.
	_step = "quit with the screen open"

	if not view.open and not view.chest_mode:
		await _tap("inventory")
		await _wait(0.8)


func _build_round() -> void:
	_step = "build screen"
	var view = client.items

	if view.open or view.chest_mode:
		await _esc()
		await _wait(0.5)

	for kit in [["stone_hammer", 1], ["stick", 80], ["twine", 40], ["thatch", 120], ["log", 0]]:
		if int(kit[1]) > 0:
			_give(str(kit[0]), int(kit[1]))

	await _check_pack("build given")
	var hammer: int = _slot_of("stone_hammer")

	if hammer < 0 or hammer > 9:
		_note("build", "the hammer is in slot %d, not on the hotbar: build round skipped" % hammer)
		return

	client.held.press_slot(hammer)
	await _wait(0.8)
	await _tap("blueprints")
	await _wait(1.0)

	if not client.held.blueprints.is_open:
		_fail("build", "open", "R with a hammer in hand opened no build screen")
		return

	var rows: Array = client.held.blueprints.rows(1).filter(func(r): return bool(r["can"]) and str(r["station"]) == "")
	await _tap("blueprints")   # R shuts it again
	await _wait(0.5)

	if client.held.blueprints.is_open:
		_fail("build", "close", "R did not shut the build screen")

	# Away from Edda and Hob's camp (no building there) onto open ground, then one piece at a time 3 m ahead, stepping aside between them.
	_step = "build walk"
	await _go_to(client.body.global_position + Vector3(0.0, 0.0, 30.0), 25.0, 3.0)
	var fwd: Vector3 = Vector3(0.0, 0.0, 1.0)
	_face(fwd)
	var side: Vector3 = fwd.cross(Vector3.UP)
	var placed: int = 0
	var refused: Array = []
	var k: int = 0

	for r in rows:
		_step = "build " + str(r["name"])
		if k > 0:
			var stepped: float = await _walk_for(side if floori(k / 6.0) % 2 == 0 else -side, 1.2)

			if stepped < 1.0:
				_note("build", "stepping aside between pieces moved only %.2f m" % stepped)

		var spot: Vector3 = client.body.global_position + fwd * 3.0
		spot.y = client.body.global_position.y - 0.9
		k += 1
		var before: Dictionary = {}

		for id in view._world:
			before[id] = true

		var heard: int = _notices.size()
		client.net.inventory_action.rpc_id(1, NetScript.ACT_PLACE_BLUEPRINT, int(r["number"]), 0, 0, spot)
		var end: int = Time.get_ticks_msec() + 2500
		var grew: bool = false

		while Time.get_ticks_msec() < end and not grew and _notices.size() == heard:
			for id in view._world:
				if not before.has(id):
					grew = true
					break

			await get_tree().process_frame

		await _wait(0.4)   # the site's world row and its words can come a frame apart

		for id in view._world:
			if not before.has(id):
				grew = true
				break

		print("ROBOT %s build try %s at %s" % [robot_name, r["name"], str(spot.round())])

		if grew or _notices.slice(heard).any(func(t): return str(t).begins_with("Blueprint down")):
			placed += 1
		elif _notices.size() > heard:
			refused.append("%s: %s" % [r["name"], _notices.back()])
		else:
			_fail("build", str(r["name"]), "%s is shown as covered on the build screen, but placing it did nothing and said nothing" % r["name"])

		if k >= 25:
			break

	print("ROBOT %s step build: %d covered rows tried, %d placed, %d refused with words" % [robot_name, k, placed, refused.size()])

	for line in refused:
		_note("build", "refused: %s" % line)


# The first stations, put down a few metres apart away from the camp: the knife's three stand at once, the hammer's workbench is a site
# hit until built. Then every recipe lit at one of them is pressed (_press_lit). A station that never stands is a fault.
const FIRST_STATIONS := [[33, "workbench"], [210, "food_preparation_table"], [206, "tailors_table"], [152, "drying_rack"]]


func _station_round(view) -> void:
	_step = "stations"

	if view.open or view.chest_mode:
		await _esc()
		await _wait(0.5)

	for item in [["stone_knife", 1], ["stone_hammer", 1], ["stick", 40], ["twine", 20], ["stone", 12], ["log", 8], ["fibre_cloth", 6]]:   # the blueprints, then cloth for the tailor (nothing that spoils: the rejoin check holds the pack to the one at quit)
		if _count(item[0]) < int(item[1]):
			_give(item[0], int(item[1]) - _count(item[0]))

	await _check_pack("stations given")
	var here: Vector3 = client.body.global_position
	var built: Array = []

	for n in FIRST_STATIONS.size():
		var number: int = int(FIRST_STATIONS[n][0])
		var kind: String = str(FIRST_STATIONS[n][1])
		var spot: Vector3 = here + Vector3(-4.5 + 3.0 * float(n), 0.0, -3.0)   # in a row 3 m apart (stations keep gap_m 2.5), all within the 6 m reach, behind the build round's pieces
		spot.y = here.y - 0.9
		var before: Dictionary = {}

		for id in view._world:
			before[id] = true

		var heard: int = _notices.size()
		client.net.inventory_action.rpc_id(1, NetScript.ACT_PLACE_BLUEPRINT, number, 0, 0, spot)
		await _wait(1.5)
		var id: int = -1

		for w in view._world:
			if not before.has(w) and (view._world[w]["pos"] as Vector3).distance_to(spot) < 3.0:
				id = int(w)

		if id < 0:
			_note("stations", "%s not put down: %s" % [kind, str(_notices.slice(heard))])
			continue

		# A site: the hammer in hand fills it (Dave 18 Nov 2026); a few hits from beside it.
		if view._world[id].get("site") != null:
			var hammer: int = _slot_of("stone_hammer")

			if hammer < 0 or hammer >= client.items.inventory.hotbar_slots:
				_note("stations", "%s: a site, but the hammer is not on the hotbar (slot %d): not hit" % [kind, hammer])
				continue

			if client.held.held_slot != hammer:
				client.held.press_slot(hammer)
				await _wait(0.5)

			await _go_to(spot, 10.0, 1.8)

			for hit in range(12):
				if not view._world.has(id) or view._world[id].get("site") == null:
					break

				client.net.inventory_action.rpc_id(1, NetScript.ACT_REPAIR_STRUCT, id, client.held.held_slot + 1, 0, Vector3.ZERO)
				await _wait(0.6)

			await _go_to(here, 10.0, 1.0)   # back where the row is measured from: the next spot stays within the place reach

			if view._world.has(id) and view._world[id].get("site") != null:
				_fail("stations", kind, "%s: its blueprint site was hit 12 times with the hammer and is still a site (%s)" % [kind, str(_notices.slice(heard))])
				continue

		built.append([id, kind])

	await _go_to(here, 10.0, 1.0)
	await _wait(1.0)
	var kinds: Array = built.map(func(b): return str(b[1]))
	print("ROBOT %s step stations: %d of %d put down (%s)" % [robot_name, built.size(), FIRST_STATIONS.size(), ", ".join(kinds)])

	if built.is_empty():
		_fail("stations", "none", "no first station could be put down")
		return

	var pressed: int = await _press_lit(view, "station lit", func(r: Dictionary) -> bool: return str(r.get("station", "")) in kinds, 150.0)

	if pressed == 0:
		_note("stations", "no recipe lit at %s" % ", ".join(kinds))

	if view.open:
		await _esc()
		await _wait(0.5)


# Puts on a skirt, sandals and the Fibre shoulder bag (the first clothes and bag), opens the bag, stores and takes the pack's fibre through it,
# and takes all three off. Each must land in a worn position and come back to the pack; the fibre must all still be there.
const FIRST_WORN := ["grass_skirt", "fibre_sandals", "fibre_shoulder_bag"]


func _worn_place(view, item: String) -> int:
	var number: int = _num(item)

	for place in view.worn.size():
		if int(view.worn[place]) == number:
			return place

	return -1


func _worn_round(view) -> void:
	_step = "worn"

	if view.chest_mode or view.screen_open():
		await _esc()
		await _wait(0.5)

	for item in FIRST_WORN:
		if _worn_place(view, item) < 0 and _count(item) == 0:
			_give(item, 1)

	if _count("plant_fibre") < 6:
		_give("plant_fibre", 6)   # something for the bag to hold

	await _check_pack("worn given")

	for item in FIRST_WORN:
		if _worn_place(view, item) >= 0:
			continue

		var heard: int = _notices.size()
		view.wear_slot(_slot_of(item))
		var end: int = Time.get_ticks_msec() + 3000

		while (_worn_place(view, item) < 0 or _count(item) != 0) and Time.get_ticks_msec() < end:
			await get_tree().process_frame   # the worn row and the pack come in two messages

		if _worn_place(view, item) < 0:
			_fail("worn", item + "_on", "%s: put on from the pack, but it never showed as worn (words: %s)" % [item, str(_notices.slice(heard))])
		elif _count(item) != 0:
			_fail("worn", item + "_pack", "%s: worn, but still %d in the pack" % [item, _count(item)])

	await _check_pack("worn on")
	var bag_at: int = _worn_place(view, "fibre_shoulder_bag")

	# Drag: the fibre moved to an empty slot past the hotbar (the same move a drag sends; Store all leaves the hotbar alone).
	_step = "drag"
	var inv = client.items.inventory
	var from: int = _slot_of("plant_fibre")
	var to: int = -1

	for k in range(inv.hotbar_slots, inv.slot_count):
		if int(inv.numbers[k]) == 0:
			to = k
			break

	var total: int = _count("plant_fibre")

	if from >= 0 and to >= 0 and from < inv.hotbar_slots:
		var moved_n: int = int(inv.counts[from])
		view.move_slot(from, to)
		await _check_pack("drag")

		if int(inv.numbers[to]) != _num("plant_fibre") or int(inv.counts[to]) != moved_n or _count("plant_fibre") != total:
			_fail("drag", "move", "fibre dragged from slot %d to empty slot %d: slot %d now holds %d x %d, fibre in the pack %d (was %d)" % [from, to, to, int(inv.counts[to]), int(inv.numbers[to]), _count("plant_fibre"), total])
		else:
			print("ROBOT %s step drag: %d fibre moved from slot %d to %d" % [robot_name, moved_n, from, to])
	else:
		_note("drag", "not tried: fibre in slot %d, first empty slot past the hotbar %d" % [from, to])

	if bag_at >= 0:
		_step = "worn bag"
		var fibre: int = _count("plant_fibre")
		var outside: int = 0
		var ahead: int = 0   # other stacks Store all reaches first (it goes in slot order; the bag holds bag_slots stacks)

		for k in range(inv.hotbar_slots, inv.slot_count):
			if int(inv.numbers[k]) == _num("plant_fibre") and not inv.is_fav(k):
				outside += int(inv.counts[k])
			elif outside == 0 and int(inv.numbers[k]) != 0 and not inv.is_fav(k):
				ahead += 1
		view.open_bag(bag_at)
		var end2: int = Time.get_ticks_msec() + 4000

		while not view.chest_mode and Time.get_ticks_msec() < end2:
			await get_tree().process_frame

		if not view.chest_mode:
			_fail("worn", "bag_open", "the worn Fibre shoulder bag did not open")
		else:
			view.bulk(1)   # Store all
			await _check_pack("bag store all")
			var stored: int = view.chest_inv.count_of(_num("plant_fibre")) if view.chest_inv != null else 0

			if _count("plant_fibre") + stored != fibre:
				_fail("worn", "bag_store", "Store all into the worn bag: %d fibre became %d in the pack and %d in the bag" % [fibre, _count("plant_fibre"), stored])
			elif outside > 0 and stored == 0 and ahead < BagRules.slots_of(client.items.table, _num("fibre_shoulder_bag")):
				_fail("worn", "bag_store", "Store all into the worn bag stored nothing, with %d fibre past the hotbar" % outside)

			view.bulk(0)   # Take all
			await _check_pack("bag take all")

			if _count("plant_fibre") != fibre:
				_fail("worn", "bag_take", "Take all from the worn bag: the pack has %d fibre, had %d" % [_count("plant_fibre"), fibre])

			print("ROBOT %s step worn bag: opened, stored %d fibre, took all back" % [robot_name, stored])
			await _esc()
			await _wait(0.6)

	_step = "worn off"

	for item in FIRST_WORN:
		var place: int = _worn_place(view, item)

		if place < 0:
			continue

		var heard2: int = _notices.size()
		view.take_off(place)
		var end3: int = Time.get_ticks_msec() + 3000

		while (_worn_place(view, item) >= 0 or _count(item) != 1) and Time.get_ticks_msec() < end3:
			await get_tree().process_frame

		if _worn_place(view, item) >= 0 or _count(item) != 1:
			_fail("worn", item + "_off", "%s: taken off, but worn %s and %d in the pack (words: %s)" % [item, str(_worn_place(view, item) >= 0), _count(item), str(_notices.slice(heard2))])

	await _check_pack("worn off")
	print("ROBOT %s step worn: %s on and off" % [robot_name, ", ".join(FIRST_WORN)])


# Opens the inventory and presses every recipe whose Craft button is lit and that `pick` takes (a recipe row): each must queue (then is cancelled)
# or get words from the server; lit and refused, or lit and silent, is a fault (the yellow-but-won't-craft class, Dave). Returns how many were pressed.
func _press_lit(view, step: String, pick: Callable, limit_s: float) -> int:
	_step = step

	if not view.open:
		await _tap("inventory")
		await _wait(1.5)

	var lit: int = 0
	var craft_end: int = Time.get_ticks_msec() + int(limit_s * 1000.0)

	for number in view.recipes.numbers():
		var r: Dictionary = view.recipes.recipe(number)

		if r.is_empty() or not view.station_makes(r) or not (view._can_craft(number) and view._station_ok(r)) or not bool(pick.call(r)):
			continue

		if not bool(r.get("known", false)) and not view._free_craft():
			continue   # the list hides recipes this character does not know (recipe_list.gd): a player cannot press them

		if Time.get_ticks_msec() > craft_end:
			_note("craft_lit", "%s: stopped after %d lit recipes: out of time" % [step, lit])
			break

		lit += 1
		var label: String = str(r.get("name", number))
		var heard: int = _notices.size()
		var queued: int = _queue_msec
		view._start_craft(number, 1)
		var end: int = Time.get_ticks_msec() + 2500

		while Time.get_ticks_msec() < end and _queue_msec == queued and _notices.size() == heard:
			await get_tree().process_frame

		await _wait(0.4)   # the queue and a notice can come a frame apart: classify once both had time to land, the queue first
		var words: Array = _notices.slice(heard).filter(func(t): return not str(t).begins_with("You work out how to make"))

		if _queue_msec != queued and _queue_left > 0:
			var tries: int = 0

			while _queue_left > 0 and tries < 20:
				tries += 1
				client.net.inventory_action.rpc_id(1, NetScript.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
				var was: int = _queue_msec
				var stop: int = Time.get_ticks_msec() + 2000

				while _queue_msec == was and Time.get_ticks_msec() < stop:
					await get_tree().process_frame

				await _wait(0.15)

			if _queue_left > 0:
				_fail("craft_lit", label + "_cancel", "%s: queued, but 20 cancels left %d entries" % [label, _queue_left])
		elif not words.is_empty():
			# A lit Craft button is a promise: any refusal words for it are a fault (the yellow-but-won't-craft class, Dave).
			_fail("craft_lit", label, "%s: the Craft button is lit but the server said: %s" % [label, str(words.back())])
		elif _queue_msec == queued:
			_fail("craft_lit", label, "%s: the Craft button is lit but nothing happened (no queue, no words)" % label)

	print("ROBOT %s step %s: %d lit recipes pressed" % [robot_name, step, lit])
	await _check_pack(step)
	return lit


func _container_round(view) -> void:
	_step = "basket place"

	if view.open:
		await _esc()
		await _wait(0.5)

	# The knife's blueprint (blueprints.json 157, Dave 21 Nov 2026: the knife makes the Wicker basket; the old kit is retired).
	_give("stone_knife", 1)
	_give("twine", 4)
	_give("stick", 8)
	await _check_pack("basket given")

	var fwd: Vector3 = -client.body.global_transform.basis.z
	var spot: Vector3 = client.body.global_position + Vector3(fwd.x, 0.0, fwd.z).normalized() * 1.6
	spot.y = client.body.global_position.y - 0.9
	var before: Dictionary = {}

	for id in view._world:
		before[id] = true

	client.net.inventory_action.rpc_id(1, NetScript.ACT_PLACE_BLUEPRINT, 157, 0, 0, spot)
	await _check_pack("basket placed")
	var basket: int = -1
	var best: float = 4.0

	for id in view._world:
		if not before.has(id) and view._is_chest(int(view._world[id].get("state", -1))) and (view._world[id]["pos"] as Vector3).distance_to(spot) < best:
			best = (view._world[id]["pos"] as Vector3).distance_to(spot)
			basket = int(id)

	if basket < 0:
		var new_rows: Array = []

		for id in view._world:
			if not before.has(id):
				new_rows.append([id, view._world[id].get("number", 0), view._world[id].get("state", -1), view._world[id].get("pos", Vector3.ZERO)])

		_note("container", "new world rows after placing: %s; last words: %s; world rows %d" % [str(new_rows), str(_notices.slice(maxi(_notices.size() - 3, 0))), view._world.size()])

	if basket < 0:
		_fail("container", "place", "the Wicker basket placed from its blueprint never showed in the world")
		return

	_step = "basket open"
	view._ask_open(basket)
	var end: int = Time.get_ticks_msec() + 4000

	while not view.chest_mode and Time.get_ticks_msec() < end:
		await get_tree().process_frame

	if not view.chest_mode:
		_fail("container", "open", "the Wicker basket did not open")
		return

	var fibre: int = _count("plant_fibre")
	view.bulk(1)   # Store all
	await _check_pack("basket store all")
	var stored: int = view.chest_inv.count_of(_num("plant_fibre")) if view.chest_inv != null else 0

	if _count("plant_fibre") + stored != fibre:
		_fail("container", "store_all", "Store all: %d fibre became %d in the pack and %d in the basket" % [fibre, _count("plant_fibre"), stored])

	view.bulk(0)   # Take all
	await _check_pack("basket take all")

	if _count("plant_fibre") != fibre:
		_fail("container", "take_all", "Take all: the pack has %d fibre, had %d" % [_count("plant_fibre"), fibre])

	view.bulk(3)   # Sort
	await _check_pack("basket sort")

	if _count("plant_fibre") != fibre:
		_fail("container", "sort", "Sort changed the fibre: %d, had %d" % [_count("plant_fibre"), fibre])

	await _esc()
	await _wait(0.6)

	if view.chest_mode or view.screen_open():
		_fail("container", "close", "Esc did not close the basket")
		await _esc()
	else:
		print("ROBOT %s step basket: placed, opened, stored %d, took all, sorted, closed" % [robot_name, stored])

	# Open again and quit with it open: the rejoin pass checks the pack.
	view._ask_open(basket)
	await _wait(1.5)


# --- plan snares: set on a game trail, set again beside it, set off any trail (Dave's rulings: no limit; on a trail a chance, off a trail
# none; a snare set on a trail trains Tracking, not twice at one spot). Then wait by them for a catch. Prints `SNARE` lines.
const SNARE_WAIT_S := 150.0

func _tracking_row() -> Array:
	var idx: int = int(client.items.get("_tracking_index"))

	for row in client.items.skill_rows:
		if int(row[0]) == idx:
			return (row as Array).duplicate()

	return []


func _route_points() -> Array:
	var out: Array = []   # [kind, point] every 2 m along every known route (the routes are polylines with few points)

	for block in client.trail_signs.routes:
		for route in client.trail_signs.routes[block]:
			var pts: PackedVector2Array = route[1]

			for i in range(pts.size() - 1):
				var n: int = maxi(1, int(pts[i].distance_to(pts[i + 1]) / 2.0))

				for k in range(n):
					out.append([str(route[0]), pts[i].lerp(pts[i + 1], float(k) / float(n))])

			if not pts.is_empty():
				out.append([str(route[0]), pts[pts.size() - 1]])

	return out


func _wet(p: Vector2) -> bool:
	var wet: Callable = client.trail_signs.wet
	return wet.is_valid() and bool(wet.call(p.x, p.y))


func _set_snare(tag: String, spot: Vector3) -> Dictionary:
	var slot: int = _slot_of("snare")

	if slot < 0:
		_fail("snare", tag, "no snare left in the pack to set")
		return {}

	var ground: float = float(client.items._ground_below.call(spot))
	spot.y = ground if not is_nan(ground) else client.body.global_position.y - 0.9
	var row0: Array = _tracking_row()
	var said_from: int = _notices.size()
	client.net.inventory_action.rpc_id(1, NetScript.ACT_PLACE, slot, 0, 0, spot)
	await _wait(3.0)
	var id: int = client.items._smoke_row_near(spot, "snare_trap", 2.0)

	if id < 0:
		id = client.items._smoke_row_near(spot, "snare", 2.0)

	var t0: int = Time.get_ticks_msec()

	while Time.get_ticks_msec() - t0 < 4000 and _tracking_row() == row0:   # the skills come back when they change
		await get_tree().process_frame

	var xp: bool = _tracking_row() != row0
	var said: Array = _notices.slice(said_from)
	print("ROBOT %s SNARE %s set %s at %s, tracking %s (%s -> %s)%s" % [robot_name, tag, "yes" if id >= 0 else "no", str(spot.snapped(Vector3.ONE * 0.1)),
		"trained" if xp else "not trained", str(row0), str(_tracking_row()), "" if said.is_empty() else ", said " + str(said)])

	if id < 0 and said.is_empty():
		_fail("snare", tag, "a snare set at %s did not appear and no message said why" % str(spot.round()))

	return {"id": id, "xp": xp, "spot": spot}


func _snares() -> void:
	_step = "snares"

	if not admin:
		_note("snares", "the snare plan needs --robot-admin (the snares are admin gifts): nothing done")
		return

	_give("snare", 7)
	await _check_pack("snares given")
	var t0: int = Time.get_ticks_msec()

	while _route_points().is_empty() and Time.get_ticks_msec() - t0 < 30000:
		await _wait(1.0)

	var me: Vector3 = client.body.global_position
	var best: Array = []
	var best_d: float = 600.0

	for attempt in range(2):   # run toward the nearest known trail, then look again (the blocks near it send their routes on arrival)
		me = client.body.global_position
		best = []
		best_d = 600.0

		for rp in _route_points():
			var d: float = Vector2(rp[1].x - me.x, rp[1].y - me.z).length()

			if d < best_d and d > 3.0 and not _wet(rp[1]):   # a trail runs down to the water: a snare goes on its dry stretch
				best_d = d
				best = rp

		if best.is_empty() or best_d < 60.0 or attempt == 1:
			break

		var toward: Vector3 = Vector3(best[1].x, me.y, best[1].y)
		await _run_to(toward + (me - toward).normalized() * 30.0, 90.0, 4.0)
		await _wait(4.0)

	if best.is_empty():
		var nearest: float = INF

		for rp in _route_points():
			nearest = minf(nearest, Vector2(rp[1].x - me.x, rp[1].y - me.z).length())

		_note("snares", "no game trail within 600 m of %s (%d route points known, the nearest %.0f m)" % [str(me.round()), _route_points().size(), nearest])
		return

	var on: Vector3 = Vector3(best[1].x, me.y, best[1].y)
	print("ROBOT %s step snares: nearest %s trail point %.0f m off at %s" % [robot_name, best[0], best_d, str(on.round())])
	await _run_to(on + (me - on).normalized() * 1.5, 90.0, 1.0)
	var first: Dictionary = await _set_snare("on_trail", on)

	# Four more along trails within 80 m, 15 m apart, dry: the server prints each one's trail share (AUDIT snare).
	var probes: Array = [Vector2(on.x, on.z)]

	for rp in _route_points():
		if probes.size() >= 5:
			break

		var far_enough: bool = true

		for q in probes:
			far_enough = far_enough and (q as Vector2).distance_to(rp[1]) >= 15.0

		if far_enough and (rp[1] as Vector2).distance_to(Vector2(on.x, on.z)) < 80.0 and not _wet(rp[1]):
			probes.append(rp[1])

	for i in range(1, probes.size()):
		var at: Vector3 = Vector3(probes[i].x, client.body.global_position.y, probes[i].y)
		await _run_to(at + Vector3(1.5, 0.0, 0.0), 40.0, 1.0)
		await _set_snare("probe%d" % i, at)

	await _run_to(on + Vector3(1.5, 0.0, 0.0), 40.0, 1.0)
	var again: Dictionary = await _set_snare("again", on + Vector3(4.0, 0.0, 0.0))

	if not first.is_empty() and not bool(first.get("xp", false)):
		_note("snares", "a snare set on a %s trail point trained no Tracking (the server's worn-trail strength there may be under snare_min 0.5)" % best[0])

	if bool(again.get("xp", false)):
		_fail("snare", "again", "a second snare 2 m from the first trained Tracking again (snare_spot_m 15 should stop it)")

	# Off any trail: 40 m or more from every route point, on one of eight bearings from the trail spot.
	var off: Vector3 = Vector3.INF

	for k in range(8):
		var c: Vector3 = on + Vector3.FORWARD.rotated(Vector3.UP, TAU * float(k) / 8.0) * 45.0
		var clear: bool = not _wet(Vector2(c.x, c.z))

		for rp in _route_points():
			clear = clear and Vector2(rp[1].x - c.x, rp[1].y - c.z).length() >= 40.0

		if clear:
			off = c
			break

	if off == Vector3.INF:
		_note("snares", "no spot 40 m from every trail near %s" % str(on.round()))
	else:
		await _run_to(off, 60.0, 1.5)
		var o: Dictionary = await _set_snare("off_trail", client.body.global_position + (-client.body.global_transform.basis.z) * 1.5)

		if bool(o.get("xp", false)):
			_fail("snare", "off", "a snare off every trail trained Tracking")

	# Wait 20 m from the trail snare (animals step only near players), watching for a carcass by any snare.
	await _run_to(on + Vector3(20.0, 0.0, 0.0), 40.0, 3.0)
	var caught: String = "none"
	var end: int = Time.get_ticks_msec() + int(SNARE_WAIT_S * 1000.0)

	while Time.get_ticks_msec() < end and caught == "none":
		await _wait(5.0)

		for d in [first, again]:
			if not d.is_empty() and client.items._smoke_row_near(d["spot"], "carcass", 3.0) >= 0:
				caught = "by the trail snare"

	print("ROBOT %s SNARE wait %.0f s: catch %s; tracking index %d, skill rows %s" % [robot_name, SNARE_WAIT_S, caught, int(client.items.get("_tracking_index")), str(client.items.skill_rows)])


# Stand and look around: the watchers keep checking the animals and players drawn.
func _watch(s: float) -> void:
	_step = "watch"
	await _wait(s)


# Gone mid-action: no quiet wait, no pack check (rejoin_mid checks what came back).
func _quit_at_once() -> void:
	_release_all()
	var f: FileAccess = FileAccess.open(SAVED_FILE, FileAccess.WRITE)

	if f != null:
		f.store_string("")   # the pack is still changing: the plain rejoin compare is off for this quit
		f.close()

	print("ROBOT %s done: plan %s, %d fails, %d notes, %d drawn-animal ids seen, %d remote held items measured, lowest health %d (quit mid-craft)" % [robot_name, plan, _fails, _notes, _species.size(), _held_looks, _lowest_health])
	client.frames_left = 1


func _quit() -> void:
	_step = "quit"
	_release_all()
	await _check_pack("quit")
	var f: FileAccess = FileAccess.open(SAVED_FILE, FileAccess.WRITE)

	if f != null:
		f.store_string(_pack_sig())
		f.close()

	await _wait(1.6)   # the last refusals get their 1.5 s for a message
	_check_refusals(Time.get_ticks_msec() + 5000)
	print("ROBOT %s done: plan %s, %d fails, %d notes, %d drawn-animal ids seen, %d remote held items measured, lowest health %d" % [robot_name, plan, _fails, _notes, _species.size(), _held_looks, _lowest_health])
	client.frames_left = 1   # the client quits the usual way (the server keeps the character, as when a player closes the game)
