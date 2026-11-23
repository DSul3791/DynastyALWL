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
const Generator := preload("res://src/client/character/body_generator.gd")
const KeyBindings := preload("res://src/client/key_bindings.gd")
const RobotRules := preload("res://src/shared/robot_rules.gd")   # the pack signature the server prints too

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
const GAME := [1, 2, 3, 4, 5, 7, 8, 14, 18, 19, 30, 31, 34, 35]   # ground game a new player goes after (animals.json numbers): rabbit, deer, wolf, moose, fox, horse, boar, bears, elk, cattle, goat, dog, ox

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
			_species[int(r[0])] = RobotRules.species_of(int(r[1])))


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
	_step = "joined"
	await _check_pack("joined")

	if plan == "rejoin":
		_rejoin_check()
		await _stances()
		await _watch(20.0)
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
			await _hunt(60.0)

		await _sleep()

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
	var at: Vector3 = here + Vector3.FORWARD.rotated(Vector3.UP, side) * 1.6
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

			if not known.has(id) and int(w.get("number", 0)) == _num("stick") and Vector2(w.get("pos", Vector3.INF).x - at.x, w.get("pos", Vector3.INF).z - at.z).length() < 1.5:
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


# Spear in hand, walk at the nearest animal the client draws and strike when close. Several robots started together go for the same one.
func _hunt(s: float) -> void:
	_step = "hunt"
	var spear: int = _slot_of("spear")

	if spear < 0:
		spear = _slot_of("wooden_spear")

	if spear < 0:
		_note("hunt", "no spear")
		return

	if spear != 0:
		client.net.inventory_action.rpc_id(1, NetScript.ACT_MOVE, spear, 0, 0, Vector3.ZERO)   # into slot 0: hotbar key 1, in hand
		await _check_pack("spear to hand")

	var end: int = Time.get_ticks_msec() + int(s * 1000.0)
	var strikes: int = 0
	var chased: Dictionary = {}

	while Time.get_ticks_msec() < end:
		var me: Vector3 = client.body.global_position
		var best: Array = []
		var best_d: float = INF

		for row in client._animal_view_node.drawn_positions():
			var sp: int = int(_species.get(int(row[0]), 0))

			if not GAME.has(sp):
				continue

			var d: float = (row[1] as Vector3).distance_to(me) - (30.0 if sp <= 3 else 0.0)   # rabbit, deer and wolf first

			if d < best_d:
				best_d = d
				best = row

		best_d = (best[1] as Vector3).distance_to(me) if not best.is_empty() else INF

		if best.is_empty() or best_d > 90.0:
			await _walk_for(Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU), 3.0)
			continue

		chased[int(best[0])] = int(_species.get(int(best[0]), 0))
		var to: Vector3 = (best[1] as Vector3) - me
		to.y = 0.0

		if best_d > 1.6:
			_face(to.normalized())
			_key("move_forward", true)
			_key("run", best_d > 8.0)
			await _wait(0.3)
			continue

		_key("move_forward", false)
		_key("run", false)
		_face(to.normalized())
		client.net.inventory_action.rpc_id(1, NetScript.ACT_STRIKE, 0, 0, 0, to.normalized())
		strikes += 1
		await _wait(0.8)

	_release_all()
	await _check_pack("hunt")
	print("ROBOT %s step hunt: %d strikes, chased %s" % [robot_name, strikes, str(chased)])


func _sleep() -> void:
	_step = "sleep"
	await _stance_to(StanceScript.LIE)
	client.net.inventory_action.rpc_id(1, NetScript.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	await _wait(6.0)
	client.net.inventory_action.rpc_id(1, NetScript.ACT_SLEEP, 0, 0, 0, Vector3.ZERO)
	await _wait(2.0)
	await _stance_to(StanceScript.STAND)
	print("ROBOT %s step sleep: lay down, slept, woke" % robot_name)


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
	_step = "craft lit"
	await _tap("inventory")
	await _wait(1.5)
	var lit: int = 0

	for number in view.recipes.numbers():
		var r: Dictionary = view.recipes.recipe(number)

		if r.is_empty() or not view.station_makes(r) or not (view._can_craft(number) and view._station_ok(r)):
			continue

		lit += 1
		var name: String = str(r.get("id", r.get("name", number)))
		var heard: int = _notices.size()
		var queued: int = _queue_msec
		view._start_craft(number, 1)
		var end: int = Time.get_ticks_msec() + 2500

		while Time.get_ticks_msec() < end and _queue_msec == queued and _notices.size() == heard:
			await get_tree().process_frame

		if _queue_msec != queued and _queue_left > 0:
			while _queue_left > 0:
				client.net.inventory_action.rpc_id(1, NetScript.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
				var was: int = _queue_msec
				var stop: int = Time.get_ticks_msec() + 2000

				while _queue_msec == was and Time.get_ticks_msec() < stop:
					await get_tree().process_frame

				await _wait(0.15)
		elif _notices.size() > heard:
			_fail("craft_lit", name, "%s: the Craft button is lit but the server said: %s" % [name, str(_notices.back())])
		elif _queue_msec == queued:
			_fail("craft_lit", name, "%s: the Craft button is lit but nothing happened (no queue, no words)" % name)

	print("ROBOT %s step craft lit: %d lit recipes pressed" % [robot_name, lit])
	await _check_pack("craft lit")

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

	# Quit with the screen open: the rejoin pass checks the pack came back.
	_step = "quit with the screen open"

	if not view.open:
		await _tap("inventory")
		await _wait(0.8)


# Stand and look around: the watchers keep checking the animals and players drawn.
func _watch(s: float) -> void:
	_step = "watch"
	await _wait(s)


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
	print("ROBOT %s done: %d fails, %d notes, %d drawn-animal ids seen, %d remote held items measured" % [robot_name, _fails, _notes, _species.size(), _held_looks])
	client.frames_left = 1   # the client quits the usual way (the server keeps the character, as when a player closes the game)
