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
# Plans (--robot-plan=): first_hours (default: craft, drop and pick up, stances, forest crouch walk, hunt, sleep, quit), rejoin (join, check
# the pack against the one saved at quit, look around, quit), light (the live server: walk, stances, watch animals and players; changes
# nothing in the world). --robot-admin lets it ask for starting materials (the server needs --open-admin; never on a live server).
# Testing only: nothing here runs unless --robot= is given.

const NetScript := preload("res://src/stream/terrain_net.gd")
const StanceScript := preload("res://src/client/stance.gd")
const CharacterStore := preload("res://src/client/character/character_store.gd")
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
const SPECIES_NAME := {1: "rabbit", 2: "deer", 3: "wolf"}
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
	print("ROBOT %s step joined: peer %d at %s" % [robot_name, client.multiplayer.get_unique_id(), str(client.body.global_position.round())])
	_hook_view()
	_step = "joined"
	await _check_pack("joined")

	if plan == "rejoin":
		_rejoin_check()
		await _rejoin_mid_check()
		await _stances()
		await _watch(20.0)
	elif plan == "light":
		await _stances()
		await _forest_walk(40.0)
		await _watch(30.0)
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

	for sp in [1, 2, 3]:
		await _hunt(sp, s_each)

	await _check_pack("hunt")


func _hunt(sp: int, s: float) -> void:
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
		client.net.inventory_action.rpc_id(1, NetScript.ACT_STRIKE, 0, 0, 0, to.normalized())
		strikes += 1
		await _wait(0.8)

	_release_all()
	await _wait(1.0)

	if target < 0:
		print("ROBOT %s HUNT %s none 0 0 0 none %d %d %.0f found none" % [robot_name, SPECIES_NAME.get(sp, sp), health_before, _health, s])
		return

	var down: bool = _fell.has(target)
	print("ROBOT %s HUNT %s %d %d %d %.1f %s %d %d %.0f" % [robot_name, SPECIES_NAME.get(sp, sp), target, strikes, int(_hits.get(target, 0)),
		float(_hp.get(target, 1.0)), "down" if down else "up", health_before, _health, float(Time.get_ticks_msec() - start_ms) / 1000.0])


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
		_fail("storage", "built", "placed the wicker basket blueprint at %s with the knife in hand and its materials; no new world item came there" % str(spot.round()))
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
	client.net.inventory_action.rpc_id(1, NetScript.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	await _wait(6.0)
	client.net.inventory_action.rpc_id(1, NetScript.ACT_SLEEP, 0, 0, 0, Vector3.ZERO)
	await _wait(2.0)
	await _stance_to(StanceScript.STAND)
	print("ROBOT %s step sleep: lay down, slept, woke" % robot_name)


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
