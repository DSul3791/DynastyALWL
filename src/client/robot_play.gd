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
# nothing in the world), together (two robots on one basket, stack, crate site and door at once, a 20 s hold, one watching the other pass
# out; docs/ROBOT_PLAYTESTERS.md), cold, fights, kind_<species>. --robot-admin lets it ask for starting materials (the server needs --open-admin; never on a live server).
# Testing only: nothing here runs unless --robot= is given.

const NetScript := preload("res://src/stream/terrain_net.gd")
const StanceScript := preload("res://src/client/stance.gd")
const CharacterStore := preload("res://src/client/character/character_store.gd")
const BagRules := preload("res://src/shared/bag_rules.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const KeyBindings := preload("res://src/client/key_bindings.gd")
const RobotRules := preload("res://src/shared/robot_rules.gd")   # the pack signature the server prints too
const InventoryScript := preload("res://src/shared/inventory.gd")
const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")

const QUIET_S := 3.0             # a pack check waits until no pack message came for this long
const QUIET_LIMIT_S := 20.0
const JUMP_SLACK := 2.0          # a drawn step may be this much over the top speed (a frame hitch) before it counts
const JUMP_FLOOR_M := 1.5
const PLAYER_TOP_MPS := 9.5      # terrain_client RUN_SPEED 9.0
const FRESH_S := 1.5             # a body just drawn may still settle onto its first samples
const INSIDE_M := 0.3
const RESPAWN_M := 40.0          # a drawn player farther than this in one frame was moved on purpose (respawn, rescue), not a jump
const RESCUE_FILE := "rescued.txt"   # ROBOT_SHARE: "<peer> <unix ms>" per line, written by a robot the cold moved to a rescue spot
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
var _kind_sp: int = -1           # plan kind_<name>: the species measured (each frame's drawn steps, A lines for robot_kinds.py)
var _kstat: Dictionary = {}      # species number -> [frames, largest step m, largest step / (top speed x frame), steps over 1 m]
var _inside_other: int = 0       # plan kind_: frames a drawn animal of the kind was inside another drawn player's capsule
var _a_ms: int = 0
var _slide_was: Dictionary = {}  # plan kind_: animal id -> [drawn position, msec] at its last A sample (the ground speed over ~100 ms)
var _slide: Array = [0, 0, 0, 0, 0, 0, INF, 0.0]   # model samples, moving, standing clip while moving, rate at its top, rate at its bottom, feet off the ground speed, lowest and highest feet / ground
var _woke_at = null              # where the cold's pass-out moved this player (plan cold), null before
var last_touch: String = ""      # what the body touched at the end of the last _walk_for, keys still held
var _stretch: String = ""        # plan route: the stretch being timed ("" none), its frames and slow frames (_route_frame)
var _stretch_msec: int = 0
var _stretch_from: Vector3 = Vector3.ZERO
var _stretch_frames: int = 0
var _stretch_worst: float = 0.0
var _stretch_100: int = 0
var _stretch_500: int = 0
var _route_lines: PackedStringArray = PackedStringArray()
var _route_last_usec: int = 0          # the last frame's clock (_route_frame)


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
	FreezeWatchScript.printer.line("ROBOT %s step prepare: plan %s, character %s" % [robot_name, plan, mine])


func _say(kind: String, text: String) -> void:
	FreezeWatchScript.printer.line("ROBOT %s %s" % [robot_name, text])

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
		if _kind_sp >= 0 and _health > 0 and int(health) < _health:
			_kind_hurt(_health, int(health))

		_health = int(health)
		_lowest_health = mini(_lowest_health, int(health)))
	client.multiplayer.server_disconnected.connect(_on_lost)
	client.net.died_received.connect(func(cause, spawn):
		if str(cause) == "passed out":   # the cold's pass-out (server_items.gd _cold_pass_out): moved to a rescue spot, no death
			_woke_at = spawn
			FreezeWatchScript.printer.line("ROBOT %s step passed out at %d: moved to %s" % [robot_name, _now_ms(), str(spawn)])   # tools/robot_check.py: drawn lying before it is no wrong stance
			if _share(RESCUE_FILE) != "":   # the others' jump check: this move is the rescue's
				var f := FileAccess.open(_share(RESCUE_FILE), FileAccess.READ_WRITE) if FileAccess.file_exists(_share(RESCUE_FILE)) else FileAccess.open(_share(RESCUE_FILE), FileAccess.WRITE)
				if f != null:
					f.seek_end()
					f.store_line("%d %d" % [client.multiplayer.get_unique_id(), _now_ms()])
			return

		_died += 1
		_fail("died", str(_died), "the robot died (%s): the game does not want a player dead unless they do something deliberately stupid" % str(cause)))



# After joining (the animal view is made then): an animal that went down from a hit (animal_view.gd fell, sent with its last row's place).
func _hook_view() -> void:
	var view: Node = client._animal_view_node
	view.fell.connect(func(_what, at, _small):
		for id in view._bodies:
			if (view._bodies[id]["target"] as Vector3).distance_to(at) < 0.01:
				_fell[int(id)] = true)


func _process(delta: float) -> void:
	if client == null or client.body == null or client.connected_msec == 0:
		return

	_route_frame(delta)

	var now: int = Time.get_ticks_msec()
	var me: Vector3 = client.body.global_position
	var view: Node = client._animal_view_node
	var present: Dictionary = {}

	var a_now: bool = _kind_sp >= 0 and now - _a_ms >= KIND_A_MS

	if a_now:
		_a_ms = now
		FreezeWatchScript.printer.line("ROBOT %s P %d %.2f %.2f" % [robot_name, _now_ms(), me.x, me.z])

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

				if num == _kind_sp and now - int(was[1]) > int(FRESH_S * 1000.0):
					var st: Array = _kstat.get(num, [0, 0.0, 0.0, 0])
					st[0] = int(st[0]) + 1
					st[1] = maxf(float(st[1]), step)
					st[2] = maxf(float(st[2]), step / maxf(float(_top_mps.get(num, 15.0)) * delta, 0.001))
					st[3] = int(st[3]) + (1 if step > 1.0 else 0)
					_kstat[num] = st

				was[0] = pos
			else:
				_seen_animal[id] = [pos, now]

			if num == _kind_sp:
				_kind_frame(id, pos, a_now)

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

				if step > RESPAWN_M or (step > JUMP_FLOOR_M and _rescued(peer)):
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
	FreezeWatchScript.printer.line("ROBOT %s CHECK pack %d %d %s %d %s" % [robot_name, client.multiplayer.get_unique_id(), _now_ms(), _pack_sig(), RobotRules.used(inv), step])


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

	FreezeWatchScript.printer.line("ROBOT %s step joined: peer %d at %s" % [robot_name, client.multiplayer.get_unique_id(), str(client.body.global_position.round())])
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
	elif plan == "bear":
		await _bear_chase()
	elif plan == "bear_group":
		await _bear_group()
	elif plan == "cold":
		await _cold()
	elif plan == "fight_goblin" or plan == "fight_bandit":
		await _fight(plan.trim_prefix("fight_"))
	elif plan == "light":
		await _stances()
		await _forest_walk(40.0)
		await _watch(30.0)
	elif plan == "screens":
		await _screens()
	elif plan == "drop_back":
		await _drop_back()
	elif plan == "drop_freeze":
		await _drop_freeze()
	elif plan == "drop_twin1" or plan == "drop_twin2":
		await _drop_twin(plan == "drop_twin2")

		if plan == "drop_twin1":
			return
	elif plan.begins_with("drop_"):
		await _drop(plan.trim_prefix("drop_"))
		return
	elif plan == "together":
		await _together()
	elif plan.begins_with("kind_"):
		await _kind(plan.trim_prefix("kind_"))
	elif plan == "route":
		await _route()
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
		FreezeWatchScript.printer.line("ROBOT %s step rejoin: pack kept (%s)" % [robot_name, saved])


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
		FreezeWatchScript.printer.line("ROBOT %s step %s: +%d %s" % [robot_name, _step, got, gives])


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
		FreezeWatchScript.printer.line("ROBOT %s step pickup: dropped and picked up a stick" % robot_name)


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
	FreezeWatchScript.printer.line("ROBOT %s step stances: done" % robot_name)


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


# The middle of the thickest 8 m patch of hazel or elder (flora.json ids 11 and 34) within `radius` m, with its count, or [NAN spot, 0] when
# none is loaded (the bug thread, 23 Nov 2026: #1740 draws every shrub within 16 m at Low and Medium, so a thicket is the worst case there).
const THICKET_SPECIES := [11, 34]

func _thicket_spot(radius: float) -> Array:
	var cells: Dictionary = {}
	var here: Vector3 = client.body.global_position

	for chunk in client.flora._chunks:
		var held: Dictionary = client.flora._chunks[chunk].get("items", {})

		for n in range(held.get("ids", []).size()):
			if not (int(held["ids"][n]) >> 16) in THICKET_SPECIES:
				continue

			var p: Vector3 = held["positions"][n]

			if Vector2(p.x - here.x, p.z - here.z).length() < radius:
				var c: Vector2i = Vector2i(floori(p.x / 8.0), floori(p.z / 8.0))
				cells[c] = int(cells.get(c, 0)) + 1

	var best: Vector2i = Vector2i.ZERO
	var most: int = 0

	for c in cells:
		if int(cells[c]) > most:
			most = int(cells[c])
			best = c

	return [Vector3(NAN, NAN, NAN) if most == 0 else Vector3((float(best.x) + 0.5) * 8.0, here.y, (float(best.y) + 0.5) * 8.0), most]


# Through the thickest hazel or elder near the route, standing, back and forth across it for `s` seconds.
func _thicket_walk(s: float) -> void:
	var found: Array = _thicket_spot(250.0)
	var spot: Vector3 = found[0]

	if is_nan(spot.x):
		_note("thicket", "no hazel or elder loaded within 250 m")
		return

	var there: bool = await _run_to(spot, 60.0, 3.0)
	FreezeWatchScript.printer.line("ROBOT %s step thicket: %s, %d hazel or elder in its 8 m square" % [robot_name, "there" if there else "short of it", int(found[1])])
	var end: int = Time.get_ticks_msec() + int(s * 1000.0)
	var turn: int = 0

	while Time.get_ticks_msec() < end:
		await _walk_for(Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, PI * 0.5 * float(turn % 4)), 3.0)
		turn += 1


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
	FreezeWatchScript.printer.line("ROBOT %s step to the forest: %s, %d trees within 20 m" % [robot_name, "there" if there else "short of it", _trees_near(20.0).size()])
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
	FreezeWatchScript.printer.line("ROBOT %s step forest crouch: %.0f m in %.0f s past %d trunks, %d stops" % [robot_name, total, s, visited.size(), stuck])


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
			FreezeWatchScript.printer.line("ROBOT %s step hunt: after %s %d at %s" % [robot_name, SPECIES_NAME.get(sp, sp), target, str((drawn[target] as Vector3).round())])

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
		FreezeWatchScript.printer.line("ROBOT %s HUNT %s none 0 0 0 none %d %d %.0f found none" % [robot_name, SPECIES_NAME.get(sp, sp), health_before, _health, s])
		return false

	var down: bool = _fell.has(target)
	FreezeWatchScript.printer.line("ROBOT %s HUNT %s %d %d %d %.1f %s %d %d %.0f" % [robot_name, SPECIES_NAME.get(sp, sp), target, strikes, int(_hits.get(target, 0)),
		float(_hp.get(target, 1.0)), "down" if down else "up", health_before, _health, float(Time.get_ticks_msec() - start_ms) / 1000.0])
	return true


const WICKER_BASKET_BP := 157   # data/items/blueprints.json wicker_basket: 8 sticks, 4 twine, the knife (Dave 21 Nov 2026: the knife makes a 6-slot basket)


# Build a wicker basket with the knife in hand, put twine in, take it out: the pack, the basket's contents and the server agree each time.
# Builds a wicker basket beside the robot with the knife (gifts its sticks and twine): its world item id, or -1 (said why).
func _build_basket() -> int:
	_give("stick", 8)
	_give("twine", 4)
	await _check_pack("storage given")
	var knife: int = _slot_of("stone_knife")

	if knife < 0:
		_note("storage", "no knife")
		return -1

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

	return basket


func _storage() -> void:
	_step = "storage"
	var basket: int = await _build_basket()

	if basket < 0:
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
		FreezeWatchScript.printer.line("ROBOT %s step storage: built a wicker basket (%d slots), put 2 twine in and took them out" % [robot_name, int(contents[0].slot_count)])

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
		var asked: int = Time.get_ticks_msec()

		while _count("wild_apples") == 2 and Time.get_ticks_msec() - asked < 4000:   # the server's answer first: a quiet pack can still be the old one over a slow link
			await get_tree().process_frame

		await _check_pack("eat")

		if _count("wild_apples") != 1:
			_fail("eat", "apple", "ate a wild apple: %d left of 2" % _count("wild_apples"))
		else:
			FreezeWatchScript.printer.line("ROBOT %s step eat: hunger %d -> %d" % [robot_name, hunger_before, _hunger])

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
	FreezeWatchScript.printer.line("ROBOT %s step drink: %s water %.0f m away, thirst %d -> %d" % [robot_name, "at the" if there else "short of the", Vector2(water.x - client.body.global_position.x, water.z - client.body.global_position.z).length(), thirst_before, _thirst])

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
	FreezeWatchScript.printer.line("ROBOT %s step quit mid-craft: queue %d left, fibre and twine worth %d fibre" % [robot_name, _queue_left, worth])


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
		FreezeWatchScript.printer.line("ROBOT %s step rejoin mid-craft: nothing lost (worth %d fibre)" % [robot_name, worth])

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
	FreezeWatchScript.printer.line("ROBOT %s POSE %d %d %d %.2f %.2f %.2f %.2f" % [robot_name, client.multiplayer.get_unique_id(), _now_ms(), client.stance.stance, me.x, me.y, me.z, Vector2(v.x, v.z).length()])
	var pv: Node = client._player_view

	if pv == null:
		return

	for peer in pv._bodies:
		var b: Dictionary = pv._bodies[peer]
		var p: Vector3 = (b["node"] as Node3D).global_position
		var rig: Node3D = b["rig"]
		var clip: String = str(rig.current()) if rig.has_method("current") else ""
		FreezeWatchScript.printer.line("ROBOT %s SEES %d %d %d %.2f %.2f %.2f %s" % [robot_name, int(peer), _now_ms(), int(b["state"]) & 3, p.x, p.y, p.z, clip if clip != "" else "-"])


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
	FreezeWatchScript.printer.line("ROBOT %s step sleep: lay down, %s, woke" % [robot_name, "slept" if slept else "never fell asleep"])


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
	FreezeWatchScript.printer.line("ROBOT %s EVENT %s %d %.2f %.2f %.2f %s" % [robot_name, kind, _now_ms(), p.x, p.y, p.z, extra])


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

			FreezeWatchScript.printer.line("ROBOT %s W %d %d %.3f %.3f %.3f %d %s %.3f" % [robot_name, int(peer), _now_ms(), p.x, p.y, p.z, int(b["state"]), clip if clip != "" else "-", held_d])

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
	client.send_position_now()   # as a player's blow: a fresh position report just before it (held_item report_now)
	client.net.inventory_action.rpc_id(1, NetScript.ACT_STRIKE, 0, int(seen[0]), int(seen[1]), dir)
	var me: Vector3 = client.body.global_position
	var near: PackedStringArray = PackedStringArray()

	for row in client._animal_view_node.drawn_positions():
		var at: Vector3 = row[1]

		if Vector2(at.x - me.x, at.z - me.z).length() < 6.0:
			near.append("%d:%.1f,%.1f" % [int(row[0]), at.x, at.z])

	FreezeWatchScript.printer.line("ROBOT %s JAB %d %d me %.1f,%.1f fps %d drawn %s" % [robot_name, int(seen[0]), int(seen[1]), me.x, me.z, Engine.get_frames_per_second(), " ".join(near)])


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

	FreezeWatchScript.printer.line("ROBOT %s WOLVES outcome %s, rush %s, %d bites (gaps s: %s), %d strikes, %d hits on wolves, most wolves within 3 m %d, nearest drawn %.2f m, health %d -> %d, %.0f s" % [
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
			FreezeWatchScript.printer.line("ROBOT %s step screen %s: opened and closed" % [robot_name, id])

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

	FreezeWatchScript.printer.line("ROBOT %s step menu pages: %d shown" % [robot_name, pages.size()])

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

	FreezeWatchScript.printer.line("ROBOT %s step skills page: %d skill rows" % [robot_name, rows])
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
			FreezeWatchScript.printer.line("ROBOT %s step split and drop: one stack became two, one fibre dropped" % robot_name)

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

		FreezeWatchScript.printer.line("ROBOT %s build try %s at %s" % [robot_name, r["name"], str(spot.round())])

		if grew or _notices.slice(heard).any(func(t): return str(t).begins_with("Blueprint down")):
			placed += 1
		elif _notices.size() > heard:
			refused.append("%s: %s" % [r["name"], _notices.back()])
		else:
			_fail("build", str(r["name"]), "%s is shown as covered on the build screen, but placing it did nothing and said nothing" % r["name"])

		if k >= 25:
			break

	FreezeWatchScript.printer.line("ROBOT %s step build: %d covered rows tried, %d placed, %d refused with words" % [robot_name, k, placed, refused.size()])

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
	FreezeWatchScript.printer.line("ROBOT %s step stations: %d of %d put down (%s)" % [robot_name, built.size(), FIRST_STATIONS.size(), ", ".join(kinds)])

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
			FreezeWatchScript.printer.line("ROBOT %s step drag: %d fibre moved from slot %d to %d" % [robot_name, moved_n, from, to])
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

			FreezeWatchScript.printer.line("ROBOT %s step worn bag: opened, stored %d fibre, took all back" % [robot_name, stored])
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
	FreezeWatchScript.printer.line("ROBOT %s step worn: %s on and off" % [robot_name, ", ".join(FIRST_WORN)])


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

	FreezeWatchScript.printer.line("ROBOT %s step %s: %d lit recipes pressed" % [robot_name, step, lit])
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
		FreezeWatchScript.printer.line("ROBOT %s step basket: placed, opened, stored %d, took all, sorted, closed" % [robot_name, stored])

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

	while Time.get_ticks_msec() - t0 < (12000 if row0.is_empty() else 4000) and _tracking_row() == row0:   # the skills come back when they change; a skill's first row came later than 7 s (snares run, 23 Nov 2026)
		await get_tree().process_frame

	var xp: bool = _tracking_row() != row0
	var said: Array = _notices.slice(said_from)
	FreezeWatchScript.printer.line("ROBOT %s SNARE %s set %s at %s, tracking %s (%s -> %s)%s" % [robot_name, tag, "yes" if id >= 0 else "no", str(spot.snapped(Vector3.ONE * 0.1)),
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
	FreezeWatchScript.printer.line("ROBOT %s step snares: nearest %s trail point %.0f m off at %s" % [robot_name, best[0], best_d, str(on.round())])
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

	if bool(again.get("xp", false)) and bool(first.get("xp", false)):   # only when the first trained: a spotted sign or a first under snare_min is not this fault
		_fail("snare", "again", "a second snare 4 m from the first trained Tracking again (snare_spot_m 15 should stop it)")

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

	FreezeWatchScript.printer.line("ROBOT %s SNARE wait %.0f s: catch %s; tracking index %d, skill rows %s" % [robot_name, SNARE_WAIT_S, caught, int(client.items.get("_tracking_index")), str(client.items.skill_rows)])


# Stand and look around: the watchers keep checking the animals and players drawn.
# --- plans drop_<case>, drop_back, drop_freeze, drop_twin: the connection dies mid-action (players thread, 23 Nov 2026) -----------------------
# drop_<case> sets up the action (twine: 6 twine queued; chest: a basket open with 2 twine put in; asleep; wolf: in a wolf pack's rush),
# saves what must come back in DROP_FILE, and writes "cut" to the link's control file (tools/lossy_link.py --control): the link goes dead both
# ways with no goodbye, as when a player's internet drops, and the robot closes. tools/robots.sh then starts the same robot again at once
# (drop_back) while the server may still hold the dead connection: it must join, and get back what DROP_FILE says. drop_freeze stalls the
# main thread 10 s while walking (a hitch on a slow PC). drop_twin: two clients with one character (tools/robots.sh starts the second
# with the same user data 30 s after the first): the server keeps one and drops the other, never both in the world.
const DROP_FILE := "user://robot_drop.json"
const CONTROL_FILE := "link_control.txt"   # in ROBOT_SHARE, read by tools/lossy_link.py --control
const TWIN_FILE := "twin_second_joined.txt"
const FREEZE_MS := 10000


func _share(file: String) -> String:
	return OS.get_environment("ROBOT_SHARE").path_join(file) if OS.get_environment("ROBOT_SHARE") != "" else ""


func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if f != null:
		f.store_string(text)
		f.close()


# What the pack holds, item number -> count, as text: unlike the pack signature it does not change as food in it ages (the wolf case's meat).
func _pack_counts() -> String:
	var inv = client.items.inventory
	var c: Dictionary = {}

	for i in range(inv.slot_count):
		if int(inv.numbers[i]) > 0:
			c[int(inv.numbers[i])] = int(c.get(int(inv.numbers[i]), 0)) + int(inv.counts[i])

	var keys: Array = c.keys()
	keys.sort()
	return ",".join(keys.map(func(k): return "%d:%d" % [k, c[k]]))


func _drop(case: String) -> void:
	_step = "drop " + case

	if not admin:
		_note("drop", "the drop plans need --robot-admin (gifts and the wolf pack): nothing done")
		await _quit()
		return

	if _share(CONTROL_FILE) == "":
		_fail("drop", "share", "no ROBOT_SHARE folder: the link's control file cannot be reached (run through tools/robots.sh)")
		await _quit()
		return

	var saved: Dictionary = {"case": case}
	var skip := func(why: String) -> void:
		_write(DROP_FILE, JSON.stringify({"case": case, "skipped": why}))   # the back pass says so as a NOTE, not a missing file

	if case == "twine":
		_give("plant_fibre", 18)
		await _check_pack("drop twine given")
		saved["worth"] = _count("plant_fibre") + 3 * _count("twine")
		client.net.inventory_action.rpc_id(1, NetScript.ACT_CRAFT_QUEUE, int(_recipes["twine"]["number"]), 0, 6, Vector3(float(client.held.held_slot + 1), 0.0, 0.0))
		await _wait(3.5)   # one or two made, the rest queued
		saved["queue_left"] = _queue_left
	elif case == "chest":
		if _slot_of("stone_knife") < 0:
			_give("stone_knife", 1)

		await _run_to(client.body.global_position + Vector3(35.0, 0.0, 0.0), 20.0, 3.0)   # out of the starter camp's ground (no building near its tree)
		_release_all()
		await _wait(1.0)
		var basket: int = await _build_basket()

		if basket < 0:
			skip.call("no basket")
			await _quit()
			return

		var contents: Array = [null]
		var got := func(id: int, bytes: PackedByteArray) -> void:
			if id == basket:
				var inv = InventoryScript.new(client.items.table)
				inv.from_bytes(bytes)
				contents[0] = inv
		client.net.chest_received.connect(got)
		client.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_OPEN, basket, 0, 0, Vector3.ZERO)
		await _wait(1.5)
		client.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_PUT, _slot_of("twine"), basket, 2, Vector3.ZERO)
		await _check_pack("drop chest put")
		client.net.chest_received.disconnect(got)

		if contents[0] == null or int(contents[0].count_of(_num("twine"))) != 2:
			_note("drop", "the basket did not show 2 twine after putting them in: the chest case is not measured")
			skip.call("basket put")
			await _quit()
			return

		saved["basket"] = basket
		saved["box_twine"] = 2
	elif case == "asleep":
		await _stance_to(StanceScript.LIE)

		if not await _fall_asleep():
			skip.call("not asleep")
			await _quit()
			return
	elif case == "wolf":
		if not await _into_rush():
			skip.call("no bite")
			await _quit()
			return

	saved["sig"] = _pack_sig()
	saved["counts"] = _pack_counts()
	saved["health"] = _health
	var p: Vector3 = client.body.global_position
	saved["pos"] = [p.x, p.y, p.z]
	_write(DROP_FILE, JSON.stringify(saved))
	_write(_share(CONTROL_FILE), "cut")
	FreezeWatchScript.printer.line("ROBOT %s DROP %s %d link cut (%s, health %d, at %s)" % [robot_name, case, _now_ms(), saved["sig"], _health, str(p.round())])
	FreezeWatchScript.printer.line("ROBOT %s done: plan %s, %d fails, %d notes, %d drawn-animal ids seen, %d remote held items measured, lowest health %d (link cut)" % [robot_name, plan, _fails, _notes, _species.size(), _held_looks, _lowest_health])
	await _wait(1.0)   # the link reads its control file five times a second
	client.frames_left = 1   # gone: the goodbye the client sends on the way out dies on the cut link


# Run out past the town's keep, set a wolf pack, and stand still until the rush has bitten once (or 60 s). True when bitten.
func _into_rush() -> bool:
	_give("raw_meat", 3)
	await _check_pack("drop wolf meat")
	var start: Vector3 = client.body.global_position
	await _run_to(start + Vector3(0.0, 0.0, -WOLF_FAR_M), 120.0, 6.0)
	await _wait(2.0)
	client.net.admin_place.rpc_id(1, "animal", client.body.global_position - client.body.global_transform.basis.z * 12.0, "wolf")
	var h0: int = _health
	var end: int = Time.get_ticks_msec() + 150000   # a pack that finds food first feeds, then prowls and stalks (first drops run: 60 s of feed)

	while Time.get_ticks_msec() < end:
		if _health < h0:
			return true

		await get_tree().process_frame

	_note("drop", "no wolf bite in 150 s after setting the pack: the wolf case is not measured")
	return false


func _drop_back() -> void:
	_step = "drop back"
	var text: String = FileAccess.get_file_as_string(DROP_FILE) if FileAccess.file_exists(DROP_FILE) else ""
	var saved = JSON.parse_string(text) if text != "" else null

	if not (saved is Dictionary):
		_fail("drop", "back", "no %s from the drop pass to compare with" % DROP_FILE)
		return

	var case: String = str(saved.get("case", ""))
	_step = "back from " + case

	if saved.has("skipped"):
		_note("drop", "the %s drop was not measured (%s): nothing to compare" % [case, str(saved["skipped"])])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DROP_FILE))
		return
	var was: Array = saved.get("pos", [0.0, 0.0, 0.0])
	var moved: float = client.body.global_position.distance_to(Vector3(float(was[0]), float(was[1]), float(was[2])))
	FreezeWatchScript.printer.line("ROBOT %s BACK %s joined %.1f m from where the link died, health %d (was %d), asleep %s" % [robot_name, case, moved, _health, int(saved.get("health", -1)), str(client.items.asleep)])

	if _health < int(saved.get("health", -1)) - 5:
		_note("drop", "health %d when the link died, %d after rejoining: the body left in the world while the dead connection lasted was hurt (%s)" % [int(saved.get("health", -1)), _health, case])

	if case == "twine":
		var limit: int = Time.get_ticks_msec() + 40000

		while _queue_left > 0 and Time.get_ticks_msec() < limit:
			await get_tree().process_frame

		await _check_pack("back twine")
		var worth: int = _count("plant_fibre") + 3 * _count("twine")

		if worth != int(saved.get("worth", -1)):
			_fail("drop", "twine", "the link died with 6 twine queued: fibre + 3 x twine was %d, after rejoining %d (fibre %d, twine %d)" % [int(saved.get("worth", -1)), worth, _count("plant_fibre"), _count("twine")])
		else:
			FreezeWatchScript.printer.line("ROBOT %s BACK twine: nothing lost (worth %d fibre, %d queued at the cut, %d now)" % [robot_name, worth, int(saved.get("queue_left", -1)), _queue_left])
	else:
		await _check_pack("back " + case)

		if _pack_counts() != str(saved.get("counts", "")):
			_fail("drop", case + " pack", "the pack when the link died held %s; after rejoining %s" % [str(saved.get("counts", "")), _pack_counts()])

	if case == "chest":
		var basket: int = int(saved.get("basket", -1))
		var limit: int = Time.get_ticks_msec() + 15000

		while not client.items._world.has(basket) and Time.get_ticks_msec() < limit:
			await get_tree().process_frame

		if not client.items._world.has(basket):
			_fail("drop", "chest gone", "the basket (world item %d) open when the link died is not in the world after rejoining" % basket)
		else:
			var contents: Array = [null]
			var said_from: int = _notices.size()
			var got := func(id: int, bytes: PackedByteArray) -> void:
				if id == basket:
					var inv = InventoryScript.new(client.items.table)
					inv.from_bytes(bytes)
					contents[0] = inv
			client.net.chest_received.connect(got)
			client.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_OPEN, basket, 0, 0, Vector3.ZERO)
			await _wait(2.0)
			client.net.chest_received.disconnect(got)

			if contents[0] == null:
				_fail("drop", "chest open", "the basket open when the link died does not open after rejoining (%s)" % (str(_notices.slice(said_from)) if _notices.size() > said_from else "no words"))
			elif int(contents[0].count_of(_num("twine"))) != int(saved.get("box_twine", 0)):
				_fail("drop", "chest", "the basket held %d twine when the link died; after rejoining it shows %d" % [int(saved.get("box_twine", 0)), int(contents[0].count_of(_num("twine")))])
			else:
				FreezeWatchScript.printer.line("ROBOT %s BACK chest: the basket opens and still holds %d twine" % [robot_name, int(saved.get("box_twine", 0))])

			client.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_CLOSE, basket, 0, 0, Vector3.ZERO)
	elif case == "asleep" or case == "wolf":
		if _health <= 0:
			_fail("drop", case + " health", "back with health %d after the link died" % _health)

		await _stance_to(StanceScript.STAND)
		var from: Vector3 = client.body.global_position
		await _walk_for(Vector3.FORWARD, 2.0)
		var m: float = client.body.global_position.distance_to(from)

		if m < 0.5:
			_fail("drop", case + " stuck", "after rejoining (the link died %s), W for 2 s moved %.2f m (asleep %s, stance %d)" % [case, m, str(client.items.asleep), client.stance.stance])
		else:
			FreezeWatchScript.printer.line("ROBOT %s BACK %s: stands and walks (%.1f m in 2 s)" % [robot_name, case, m])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(DROP_FILE))


# Walking, then the main thread stalls 10 s (a long hitch): the server must keep this player, or drop it with words; nothing in the pack moves.
func _drop_freeze() -> void:
	_step = "freeze"
	await _check_pack("before the freeze")
	var sig: String = _pack_sig()
	var said_from: int = _notices.size()
	_key("move_forward", true)
	await _wait(2.0)
	var before: Vector3 = client.body.global_position
	var t0: int = _now_ms()
	OS.delay_msec(FREEZE_MS)   # the whole client stops: no frames, no network service
	FreezeWatchScript.printer.line("ROBOT %s FREEZE over at %d" % [robot_name, _now_ms()])
	_key("move_forward", false)
	await _wait(8.0)
	var still: bool = client.multiplayer.multiplayer_peer != null and client.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	var after: Vector3 = client.body.global_position
	FreezeWatchScript.printer.line("ROBOT %s FREEZE %d s at %d: still connected %s, moved %.1f m across it, notices %s" % [robot_name, int(FREEZE_MS * 0.001), t0, str(still), after.distance_to(before), str(_notices.slice(said_from))])

	if not still:
		return   # dropped: _on_lost said so

	await _check_pack("after the freeze")

	if _pack_sig() != sig:
		_fail("freeze", "pack", "the pack changed across a 10 s freeze: %s -> %s" % [sig, _pack_sig()])


# Two clients, one character (tools/robots.sh starts drop_twin1, then drop_twin2 with the same user data folder 30 s later): the server must
# drop the older connection with words (terrain_server.gd "the older connection is dropped"), never keep two bodies for one character.
func _drop_twin(second: bool) -> void:
	_step = "twin"
	var flag: String = _share(TWIN_FILE)

	if flag == "":
		_fail("twin", "share", "no ROBOT_SHARE folder")
		return

	if second:
		_write(flag, str(_now_ms()))
		FreezeWatchScript.printer.line("ROBOT %s TWIN second joined at %d as the same character (%s)" % [robot_name, _now_ms(), _pack_sig()])
		var first_sig: String = FileAccess.get_file_as_string(_share("twin_first_pack.txt")).strip_edges() if FileAccess.file_exists(_share("twin_first_pack.txt")) else ""

		if first_sig != "" and first_sig != _pack_sig():
			_fail("twin", "pack", "the second client of one character has pack %s; the first had %s" % [_pack_sig(), first_sig])

		await _wait(25.0)
		return

	_write(_share("twin_first_pack.txt"), _pack_sig())
	var t0: int = Time.get_ticks_msec()

	while not FileAccess.file_exists(flag) and Time.get_ticks_msec() - t0 < 150000:
		await get_tree().process_frame

	if not FileAccess.file_exists(flag):
		_note("twin", "the second client never joined: nothing measured")
		await _quit()   # run() returns after this plan without its own quit
		return

	FreezeWatchScript.printer.line("ROBOT %s TWIN first: the second is in, waiting to be dropped (%s)" % [robot_name, _pack_sig()])
	FreezeWatchScript.printer.line("ROBOT %s done: plan %s, %d fails, %d notes, %d drawn-animal ids seen, %d remote held items measured, lowest health %d (twin, to be dropped)" % [robot_name, plan, _fails, _notes, _species.size(), _held_looks, _lowest_health])
	t0 = Time.get_ticks_msec()

	while Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame

	_fail("twin", "both", "still connected 20 s after a second client joined as the same character: two bodies for one character")
	client.frames_left = 1


# The server ended this connection: said once, with the step. Expected for the first twin; a fault in the freeze plan (a 10 s hitch must not
# cost a player the game: the main gate allows a freeze up to 24.85 s).
func _on_lost() -> void:
	FreezeWatchScript.printer.line("ROBOT %s LOST the server at %d (step %s, notices %s)" % [robot_name, _now_ms(), _step, str(_notices.slice(-2))])

	if plan == "drop_twin1":
		FreezeWatchScript.printer.line("ROBOT %s done: plan %s, %d fails, %d notes, %d drawn-animal ids seen, %d remote held items measured, lowest health %d (twin, dropped)" % [robot_name, plan, _fails, _notes, _species.size(), _held_looks, _lowest_health])
		FreezeWatchScript.printer.line("ROBOT %s TWIN first dropped by the server" % robot_name)
	elif plan == "drop_freeze":
		_fail("freeze", "dropped", "the server dropped this client after a %d s main-thread freeze" % (int(FREEZE_MS * 0.001)))
# Plan bear (animal thread, 23 Nov 2026: a drawn bear held at a robot, then snapped 42 m): Robot 1 sets a bear 20 m ahead of the spawn,
# every robot takes a spear and hunts it (2 or 3 robots on one bear). The inside and jump checks run every frame as in first_hours.
func _bear_chase() -> void:
	_step = "bear"

	if not admin:
		_note("bear", "the bear chase needs --robot-admin: nothing done")
		return

	_give("spear", 1)
	await _check_pack("bear spear")
	var spear: int = _slot_of("spear")

	if spear > 0:
		client.net.inventory_action.rpc_id(1, NetScript.ACT_MOVE, spear, 0, 0, Vector3.ZERO)
		await _check_pack("spear to hand")

	if robot_name.ends_with("1"):
		client.net.admin_place.rpc_id(1, "animal", client.body.global_position - client.body.global_transform.basis.z * 20.0, "bear")

	await _wait(3.0)
	_step = "hunt bear"
	var _found: bool = await _hunt(14, 90.0)


# --- plans fight_goblin, fight_bandit (survival-loop thread, 23 Nov 2026): one robot against a charging foe over the lossy link -------------
# The robot sets the foe 12 m ahead (admin), takes a spear and a wicker shield, closes and jabs once to start the fight, then stands. Every
# warning and charge the foe makes is logged as the robot drew it: ROBOT n ENEMY <hit|miss> <species> <id> warn <ms seen before the charge>
# charge <ms> gap <drawn m at the landing or the closest> dodge <yes|no> shield <up|down>. Every second charge it side-steps (A held 0.8 s
# from the drawn charge start), every other one it raises the shield (B). The server prints AUDIT enemy_hit with its own distance at the landing.
# A hit with no warning drawn before it, or drawn farther than the foe's hit_m + 1.5 m, fails.
const FIGHT_REACH := {"goblin": 1.0, "bandit": 1.6}   # data/animals/animals.json defend hit_m (survival-loop thread)
const FIGHT_S := 75.0
const ST_WARN := 10
const ST_CHARGE := 11
const ST_WARN_POP := 16


func _drawn_state(id: int) -> int:
	var bodies: Dictionary = client._animal_view_node._bodies
	return int(bodies[id].get("state", 0)) if bodies.has(id) else -1


# B with the shield in the left hand: held_item.gd raises it only with the mouse captured, which a headless client cannot do, so the robot
# sends what that raised shield sends (held_item.gd _report_held: the hand numbers and HAND_SHIELD_UP).
func _shield(up: bool) -> void:
	client.net.held_item.rpc_id(1, int(client.held.held_number()), int(client.held.off_number()), 4 if up else 0)


func _fight(kind: String) -> void:
	_step = "fight " + kind

	if not admin:
		_note("fight", "the fight plans need --robot-admin: nothing done")
		return

	var sp: int = 16 if kind == "goblin" else 52
	var reach: float = float(FIGHT_REACH.get(kind, 1.6))
	_give("spear", 1)
	_give("wicker_shield", 1)
	await _check_pack("fight gear")

	if _slot_of("spear") > 0:
		client.net.inventory_action.rpc_id(1, NetScript.ACT_MOVE, _slot_of("spear"), 0, 0, Vector3.ZERO)
		await _check_pack("spear to hand")

	var sh: int = _slot_of("wicker_shield")

	if sh > 0 and sh != 1:
		client.net.inventory_action.rpc_id(1, NetScript.ACT_MOVE, sh, 1, 0, Vector3.ZERO)
		await _check_pack("shield to slot 2")

	client.held.select(1)   # the shield goes to the left hand beside the spear (held_item.gd: offhand items)
	await _wait(0.5)
	client.held.select(0)
	await _wait(0.5)
	var me0: Vector3 = client.body.global_position
	var known: Dictionary = {}

	for row in client._animal_view_node.drawn_positions():
		known[int(row[0])] = true

	client.net.admin_place.rpc_id(1, "animal", me0 - client.body.global_transform.basis.z * 12.0, kind)
	var foe: int = -1
	var t0: int = Time.get_ticks_msec()

	while foe < 0 and Time.get_ticks_msec() - t0 < 10000:
		for row in client._animal_view_node.drawn_positions():
			if not known.has(int(row[0])) and int(_species.get(int(row[0]), 0)) == sp:
				foe = int(row[0])

		await get_tree().process_frame

	if foe < 0:
		_fail("fight", "foe", "no %s came after admin_place: nothing measured" % kind)
		return

	FreezeWatchScript.printer.line("ROBOT %s step fight: %s %d set, shield in the left hand %s" % [robot_name, kind, foe, str(client.held.off_id())])
	var end: int = Time.get_ticks_msec() + int(FIGHT_S * 1000.0)
	var started: bool = false
	var last_state: int = -1
	var warn_ms: int = -1
	var charge_ms: int = -1
	var closest: float = INF
	var charges: int = 0
	var hits: int = 0
	var h_before: int = _health
	var dodge: bool = false
	var shield_up: bool = false
	var raise_ms: int = -1           # when the shield went up (at the drawn warning, survival-loop thread 23 Nov 2026), -1 down
	var last_jab: int = 0
	var hit_now: bool = false        # this charge already landed (its end is not also a miss)
	var calm_since: int = 0          # the last charge ended: after 4 s with none, close in and jab again

	while Time.get_ticks_msec() < end and _health > 15:
		var drawn: Dictionary = {}

		for row in client._animal_view_node.drawn_positions():
			drawn[int(row[0])] = row[1]

		if not drawn.has(foe):
			break   # down or gone

		var me: Vector3 = client.body.global_position
		var at: Vector3 = drawn[foe]
		var gap: float = Vector2(at.x - me.x, at.z - me.z).length()
		var st: int = _drawn_state(foe)
		var now: int = Time.get_ticks_msec()

		if started and calm_since > 0 and now - calm_since > 4000 and st != ST_WARN and st != ST_WARN_POP and st != ST_CHARGE:
			started = false   # it stopped fighting: start it again
			calm_since = 0

		if not started:
			_face(at - me)

			if gap > 2.0:
				_key("move_forward", true)
				_key("run", gap > 5.0)   # a goblin runs off: catch up
			else:
				_key("move_forward", false)
				_key("run", false)

				if now - last_jab > 1000:
					_strike_at((at - me).normalized())   # again each second until it warns or charges (a jab can miss: the server judges from where it last had this player)
					last_jab = now

		if st != last_state:   # every warning and charge, also one that starts before the robot's jab
			if st == ST_WARN or st == ST_WARN_POP or st == ST_CHARGE:
				started = true
				_key("move_forward", false)
				_key("run", false)

			if st == ST_WARN or st == ST_WARN_POP:
				if warn_ms < 0:
					warn_ms = now

				if (charges + 1) % 2 == 1 and raise_ms < 0:   # odd charges: the shield goes up at the warning; even ones: a side step
					_face(at - me)
					_shield(true)
					raise_ms = now
			elif st == ST_CHARGE:
				charge_ms = now
				charges += 1
				hit_now = false
				closest = gap
				dodge = charges % 2 == 0
				shield_up = charges % 2 == 1
				_face(at - me)

				if dodge:
					_key("move_left", true)
					_key("run", charges % 4 == 0)   # every other side-step at run speed (a bandit's hit_m 1.6 needs a run to clear)

				if shield_up and raise_ms < 0:   # no warning drawn first: up now
					_shield(true)
					raise_ms = now
			elif last_state == ST_CHARGE:
				_key("move_left", false)
				_key("run", false)
				_shield(false)
				raise_ms = -1
				calm_since = now

				if not hit_now:
					FreezeWatchScript.printer.line("ROBOT %s ENEMY miss %s %d warn %d charge %d gap %.2f dodge %s shield %s" % [robot_name, kind, foe, (charge_ms - warn_ms) if warn_ms > 0 else -1, now - charge_ms, closest, ("run" if charges % 4 == 0 else "walk") if dodge else "no", "up" if shield_up else "down"])
				warn_ms = -1
			elif (last_state == ST_WARN or last_state == ST_WARN_POP) and st != ST_WARN and st != ST_WARN_POP:
				_shield(false)   # a warning that never became a charge: guard down, close in again after the calm
				raise_ms = -1
				warn_ms = -1
				calm_since = now

		if raise_ms > 0 and st != ST_CHARGE:
			_face(at - me)   # shield up: keep it toward the foe (protection.json shield_arc_deg 120)

		if st == ST_CHARGE:
			closest = minf(closest, gap)

			if dodge and now - charge_ms > 800:
				_key("move_left", false)
				_key("run", false)

		if _health < h_before:
			hits += 1
			hit_now = true
			var warned: int = (charge_ms - warn_ms) if warn_ms > 0 and charge_ms > 0 else -1
			var fwd: Vector3 = -client.body.global_transform.basis.z
			var facing: float = rad_to_deg(absf(Vector2(fwd.x, fwd.z).angle_to(Vector2(at.x - me.x, at.z - me.z))))   # 0 = facing the foe; the shield covers 60 either way
			FreezeWatchScript.printer.line("ROBOT %s ENEMY hit %s %d warn %d charge %d gap %.2f dodge %s shield %s raised %d ms before facing %.0f deg health %d -> %d state %d" % [robot_name, kind, foe, warned, (now - charge_ms) if charge_ms > 0 else -1, gap,
				("run" if charges % 4 == 0 else "walk") if dodge else "no", "up" if raise_ms > 0 else "down", (now - raise_ms) if raise_ms > 0 else -1, facing, h_before, _health, st])

			if charge_ms < 0 or now - charge_ms > 3000:
				_fail("fight", "unwarned:%d" % hits, "a %s hit (health %d -> %d) with no charge drawn before it (drawn state %d, warning drawn %s, %.2f m)" % [kind, h_before, _health, st, "yes" if warn_ms > 0 else "no", gap])
			elif gap > reach + 1.5:
				_fail("fight", "far:%d" % hits, "a %s hit from %.2f m as drawn (its hit_m %.1f)" % [kind, gap, reach])

			h_before = _health

		last_state = st
		await get_tree().process_frame

	_release_all()
	_shield(false)
	FreezeWatchScript.printer.line("ROBOT %s FIGHT %s: %d charges, %d hits, health %d at the end" % [robot_name, kind, charges, hits, _health])


# Plan bear_group (animal thread, 23 Nov 2026: two hunters 1.4 m apart, the server pushed the bear out of one and into the other): the robots
# stand in a tight group (each within 1.1 m of the others), face an admin bear set 2 m from the middle of the group, and only jab when it is within 2.5 m; they never
# step out of the group. The inside and jump checks run every frame.
const GROUP_SPOTS := [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(0.5, 0.0, 0.85)]


func _bear_group() -> void:
	_step = "bear group"

	if not admin:
		_note("bear", "the bear chase needs --robot-admin: nothing done")
		return

	_give("spear", 1)
	await _check_pack("bear spear")

	if _slot_of("spear") > 0:
		client.net.inventory_action.rpc_id(1, NetScript.ACT_MOVE, _slot_of("spear"), 0, 0, Vector3.ZERO)
		await _check_pack("spear to hand")

	var n: int = clampi(robot_name.to_int() - 1, 0, GROUP_SPOTS.size() - 1)
	var spot: Vector3 = Vector3(58170.0, 0.0, 71360.0) + GROUP_SPOTS[n]   # beside the spawn, the same ground for every robot
	await _go_to(spot, 30.0, 0.25)
	_release_all()
	FreezeWatchScript.printer.line("ROBOT %s step bear group: at %s (spot %d)" % [robot_name, str(client.body.global_position), n])
	await _wait(6.0 - float(n) * 2.0 + 2.0)   # all three in place

	if n == 0:
		client.net.admin_place.rpc_id(1, "animal", Vector3(58170.5, 0.0, 71358.2), "bear")   # 2 m from the middle of the group: in reach at once

	_step = "hunt bear group"
	var end: int = Time.get_ticks_msec() + 70000
	var last_jab: int = 0
	var bear: int = -1

	while Time.get_ticks_msec() < end:
		var me: Vector3 = client.body.global_position
		var at: Vector3 = Vector3.INF

		for row in client._animal_view_node.drawn_positions():
			if int(_species.get(int(row[0]), 0)) == 14 and (bear < 0 or int(row[0]) == bear) and (row[1] as Vector3).distance_to(me) < 60.0:
				bear = int(row[0])
				at = row[1]

		if bear >= 0 and not at.is_finite():
			break   # down or gone

		if at.is_finite():
			_face(at - me)

			if Vector2(at.x - me.x, at.z - me.z).length() < 2.5 and Time.get_ticks_msec() - last_jab > 1000:
				_strike_at((at - me).normalized())
				last_jab = Time.get_ticks_msec()

		await get_tree().process_frame

	FreezeWatchScript.printer.line("ROBOT %s step bear group: bear %d %s, health %d, %.2f m from its spot" % [robot_name, bear, "gone" if bear >= 0 else "never seen", _health, Vector2(client.body.global_position.x - spot.x, client.body.global_position.z - spot.z).length()])


# Plan cold (the core rule, Dave 23 Nov 2026: the game does not want you dead; at 1 health you take no more damage; cold takes you to 1, you
# pass out and wake at the nearest goblin camp, bandit camp or town with a "traveler found you" message, the pack kept). The server's robot
# audit turns the weather to a hard frost and starts this player at health 6, warmth 15 (server_control.txt, --robot-audit only). The robot
# stands still and must: never read health 0 or die, pass out with words, be moved to a rescue spot, wake with words and health at least 10,
# keep every item, and stand and walk after. Then the 1-health floor under blows, in the world's own weather again: health set to 1, a
# goblin set 3 m off and jabbed each second; at least one blow must land (the server's AUDIT enemy_hit) and 40 s of them must leave health
# at 1 and no death.
const SERVER_CONTROL := "server_control.txt"


func _cold() -> void:
	_step = "cold"

	if not admin or _share(SERVER_CONTROL) == "":
		_fail("cold", "setup", "the cold plan needs --robot-admin and tools/robots.sh (ROBOT_SHARE): nothing measured")
		return

	_give("stone", 3)
	await _check_pack("cold given")
	var counts: String = _pack_counts()
	var lay: Vector3 = client.body.global_position
	var said_from: int = _notices.size()
	_write(_share(SERVER_CONTROL), "cold %d" % client.multiplayer.get_unique_id())
	var t0: int = Time.get_ticks_msec()
	var low: int = 1 << 30
	var out_said: bool = false

	while _woke_at == null and Time.get_ticks_msec() - t0 < 240000:
		if _health >= 0:
			low = mini(low, _health)

		await get_tree().process_frame

	await _wait(3.0)
	var said: Array = _notices.slice(said_from)

	for t in said:
		out_said = out_said or str(t).to_lower().contains("pass out")

	var found: bool = said.any(func(t): return str(t).to_lower().contains("found you") or str(t).to_lower().contains("brought you"))
	FreezeWatchScript.printer.line("ROBOT %s COLD lowest health %d, passed out %s after %.0f s, moved %.0f m to %s, health now %d, said %s" % [robot_name, low, str(_woke_at != null), float(Time.get_ticks_msec() - t0) * 0.001,
		client.body.global_position.distance_to(lay), str(_woke_at), _health, str(said)])

	if _woke_at == null:
		_fail("cold", "out", "a hard frost from health 6 never passed this player out in 240 s (lowest health %d, said %s)" % [low, str(said)])
		return

	if low < 1:
		_fail("cold", "floor", "health read %d in the cold (the floor is 1)" % low)

	if not out_said or not found:
		_fail("cold", "words", "passed out and moved without the words (pass out said %s, traveler said %s): %s" % [str(out_said), str(found), str(said)])

	if _health < 10:
		_fail("cold", "wake", "woke with health %d (wake_health 10)" % _health)

	await _check_pack("cold woke")

	if _pack_counts() != counts:
		_fail("cold", "pack", "the pack before the cold held %s; after waking %s" % [counts, _pack_counts()])

	var from: Vector3 = client.body.global_position
	var m: float = await _walk_for(Vector3.FORWARD, 2.0)

	if m < 0.5:
		_fail("cold", "stuck", "after waking, W for 2 s moved %.2f m (from %s)" % [m, str(from.round())])

	# The 1-health floor under blows.
	_step = "floor"
	_give("spear", 1)
	await _check_pack("floor spear")

	if _slot_of("spear") > 0:
		client.net.inventory_action.rpc_id(1, NetScript.ACT_MOVE, _slot_of("spear"), 0, 0, Vector3.ZERO)
		await _check_pack("spear to hand")

	await _run_to(client.body.global_position + Vector3(0.0, 0.0, -60.0), 20.0, 3.0)   # out of the town square (it woke there): foes there stood calm under jabs
	_release_all()
	_write(_share(SERVER_CONTROL), "warm %d" % client.multiplayer.get_unique_id())   # the world's own weather again: no second pass-out mid-fight
	await _wait(1.0)
	_write(_share(SERVER_CONTROL), "health %d 1" % client.multiplayer.get_unique_id())
	await _wait(2.0)
	var me: Vector3 = client.body.global_position
	var known: Dictionary = {}

	for row in client._animal_view_node.drawn_positions():
		known[int(row[0])] = true

	client.net.admin_place.rpc_id(1, "animal", me - client.body.global_transform.basis.z * 3.0, "goblin")   # a goblin fights back (a bear at 3 m never struck in two runs)
	var foe: int = -1
	var died_before: int = _died
	low = 1 << 30
	var h_seen: Array = []
	var last_jab: int = 0
	t0 = Time.get_ticks_msec()

	while Time.get_ticks_msec() - t0 < 40000:
		var at: Vector3 = Vector3.INF

		for row in client._animal_view_node.drawn_positions():
			if not known.has(int(row[0])) and int(_species.get(int(row[0]), 0)) == 16 and (foe < 0 or int(row[0]) == foe):
				foe = int(row[0])
				at = row[1]

		if _health >= 0:
			low = mini(low, _health)

			if h_seen.is_empty() or h_seen[-1] != _health:
				h_seen.append(_health)

		if at.is_finite():   # close in and jab once a second, so the goblin keeps fighting
			var to: Vector3 = at - client.body.global_position
			_face(to)
			_key("move_forward", Vector2(to.x, to.z).length() > 2.0)

			if Vector2(to.x, to.z).length() <= 2.5 and Time.get_ticks_msec() - last_jab > 1000:
				_strike_at(to.normalized())
				last_jab = Time.get_ticks_msec()

		await get_tree().process_frame

	_release_all()
	# The blows that landed, from the server's own audit (robot runs share its log folder): a blow at low health lands "maimed" and takes
	# nothing (the floor), so the robot's health alone cannot tell a blow from none (survival-loop thread, 23 Nov 2026).
	var blows: PackedStringArray = PackedStringArray()
	var log_text: String = FileAccess.get_file_as_string(_share("server.log")) if FileAccess.file_exists(_share("server.log")) else ""

	for line in log_text.split("\n"):
		if line.begins_with("AUDIT enemy_hit %d " % client.multiplayer.get_unique_id()) and line.contains("goblin"):
			blows.append(line.get_slice(" result ", 1).get_slice(" ", 0))

	FreezeWatchScript.printer.line("ROBOT %s FLOOR goblin %d, %d blows landed (%s), health seen %s, lowest %d, deaths %d" % [robot_name, foe, blows.size(), ",".join(blows), str(h_seen), low, _died - died_before])

	if not FileAccess.file_exists(_share("server.log")):
		_fail("floor", "log", "no server.log in ROBOT_SHARE: the server's blows cannot be counted")
	elif foe < 0:
		_fail("floor", "foe", "no goblin came after admin_place: the floor under blows is not measured")
	elif blows.is_empty():
		_fail("floor", "blows", "no goblin blow landed in 40 s (no AUDIT enemy_hit): the floor under blows is not measured")
	elif low < 1 or _died > died_before:
		_fail("floor", "below", "at health 1 a goblin took this player to %d (deaths %d): at 1 health no more damage" % [low, _died - died_before])
	elif low > 1:
		_fail("floor", "set", "health never read 1 after the control set it (lowest %d): the floor was not tested" % low)


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

	FreezeWatchScript.printer.line("ROBOT %s done: plan %s, %d fails, %d notes, %d drawn-animal ids seen, %d remote held items measured, lowest health %d (quit mid-craft)" % [robot_name, plan, _fails, _notes, _species.size(), _held_looks, _lowest_health])
	client.frames_left = 1


# Plan route (lag lane 23 Nov 2026, coordinator: "hitches while moving, which is how people really play"): a fixed route a new player takes,
# timed stretch by stretch: round the starter town, a long run north over many block borders, the thickest woods near there, the nearest
# river and along it, after the nearest wild animal with a spear, a chest built and opened, a full turn of the view. Each stretch prints
#   ROBOT <name> ROUTE <stretch>: <s> s, <frames> frames, worst <ms> ms, <n> over 100 ms, <n> over 500 ms, moved <m> m, at x,z
# and the game's own HITCH and FREEZE lines fall between its begin and end lines. Needs --robot-admin (the spear and the chest's makings).
# The same route at Low quality: --quality=0 on the client.
func _route() -> void:
	var start: Vector3 = client.body.global_position
	_route_begin("town")
	for corner in [Vector3(40.0, 0.0, 0.0), Vector3(40.0, 0.0, 40.0), Vector3(-40.0, 0.0, 40.0), Vector3(-40.0, 0.0, -30.0), Vector3(0.0, 0.0, 0.0)]:
		await _run_to(start + corner, 25.0, 4.0)
	_route_end()

	_route_begin("run north 600 m")
	await _run_to(start + Vector3(60.0, 0.0, -600.0), 120.0, 6.0)
	_route_end()

	_route_begin("woods")
	await _forest_walk(30.0)
	_route_end()

	_route_begin("thicket")
	await _thicket_walk(25.0)
	_route_end()

	_route_begin("to the river")
	var water: Vector3 = await _find_water()
	if is_nan(water.x):
		_note("route", "no water in a loaded chunk")
	else:
		await _run_to(water, 90.0, 6.0)
	_route_end()

	_route_begin("along the river")
	var along: Vector3 = client.body.global_position
	var came: Vector3 = _stretch_from
	for leg in range(4):
		var next: Vector3 = await _find_water_beyond(along, came, 30.0)
		if is_nan(next.x):
			break
		await _run_to(next, 30.0, 5.0)
		came = along
		along = next
	_route_end()

	_route_begin("past animals")
	_give("spear", 1)
	await _check_pack("route spear")
	await _hunt_all(25.0)
	_route_end()

	_route_begin("chest")
	_give("stone_knife", 1)
	await _storage()
	_route_end()

	_route_begin("view turn")
	var yaw: float = client.body.rotation.y
	for n in range(80):
		client.body.rotation.y = yaw + TAU * float(n + 1) / 80.0
		await get_tree().process_frame
	await _wait(2.0)
	_route_end()

	_route_begin("run back to town")
	await _run_to(start, 150.0, 8.0)
	_route_end()
	FreezeWatchScript.printer.line("ROBOT %s ROUTE summary:" % robot_name)
	for line in _route_lines:
		FreezeWatchScript.printer.line("ROBOT %s ROUTE = %s" % [robot_name, line])


# The wet corner of a loaded water grid nearest `from` that lies at least `beyond_m` from it and no nearer the route's last point than `from`
# (so the run goes on along the water, not back), or NAN; one chunk a frame, as _find_water.
func _find_water_beyond(from: Vector3, back: Vector3, beyond_m: float) -> Vector3:
	var best: Vector3 = Vector3(NAN, NAN, NAN)
	var best_d: float = INF
	var chunk_m: float = float(client.flora.chunk_m)
	var back_d: float = Vector2(from.x - back.x, from.z - back.z).length()

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
				var d: float = Vector2(x - from.x, z - from.z).length()

				if d >= beyond_m and d < best_d and Vector2(x - back.x, z - back.z).length() > back_d:
					best_d = d
					best = Vector3(x, float(levels[j * count + i]), z)

		await get_tree().process_frame

	return best


func _route_begin(stretch: String) -> void:
	_step = "route " + stretch
	_stretch = stretch
	_stretch_msec = Time.get_ticks_msec()
	_stretch_from = client.body.global_position
	_stretch_frames = 0
	_stretch_worst = 0.0
	_stretch_100 = 0
	_stretch_500 = 0
	FreezeWatchScript.printer.line("ROBOT %s ROUTE begin %s at %.0f,%.0f" % [robot_name, stretch, _stretch_from.x, _stretch_from.z])


func _route_end() -> void:
	var here: Vector3 = client.body.global_position
	var line: String = "%s: %.1f s, %d frames, worst %.0f ms, %d over 100 ms, %d over 500 ms, moved %.0f m, at %.0f,%.0f" % [_stretch,
		float(Time.get_ticks_msec() - _stretch_msec) / 1000.0, _stretch_frames, _stretch_worst, _stretch_100, _stretch_500,
		Vector2(here.x - _stretch_from.x, here.z - _stretch_from.z).length(), here.x, here.z]
	FreezeWatchScript.printer.line("ROBOT %s ROUTE %s" % [robot_name, line])
	_route_lines.append(line)
	_stretch = ""


# A frame's length from the clock, not delta: Lane A's route plays (23 Nov 2026) never showed a frame over 150 ms while their FREEZE lines
# had 1-2 s gaps, so the engine's delta is held at about 150 ms and cannot show a stall.
func _route_frame(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - _route_last_usec) / 1000.0 if _route_last_usec > 0 else 0.0
	_route_last_usec = now
	if _stretch == "":
		return

	_stretch_frames += 1
	_stretch_worst = maxf(_stretch_worst, ms)
	_stretch_100 += 1 if ms > 100.0 else 0
	_stretch_500 += 1 if ms > 500.0 else 0


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
	FreezeWatchScript.printer.line("ROBOT %s done: plan %s, %d fails, %d notes, %d drawn-animal ids seen, %d remote held items measured, lowest health %d" % [robot_name, plan, _fails, _notes, _species.size(), _held_looks, _lowest_health])
	client.frames_left = 1   # the client quits the usual way (the server keeps the character, as when a player closes the game)


# --- plan kind_<species> (animal thread, 23 Nov 2026): every animal kind in a fight, drawn by two robots over the lossy link ---------------
# Robot 1 places one of the kind (a wolf is a pack) 15 m ahead of itself; both robots take a spear and hunt it for up to KIND_S, then Robot 1
# places another, KIND_ROUNDS times. Each frame, for the kind's drawn bodies: the step since the last frame against the kind's top speed
# (_kstat), the body inside this player (the inside FAIL) or inside another drawn player (counted). Every KIND_A_MS each robot prints
# ROBOT n A <unix ms> <id> <x> <z> <state> for each body of the kind and ROBOT n P <unix ms> <x> <z> for itself; a health drop prints a
# BITTEN line with the nearest drawn body. tools/robot_kinds.py compares the two robots' A lines (do both clients draw the same?) and
# the server's AUDIT enemy_hit lines (the drawn gap from where the server had the animal when it struck). Feet against ground (slides)
# needs the bought models, which cloud clones leave out (tools/skip_models.sh): the code-built bodies step by the ground speed itself.
const KIND_S := 70.0
const KIND_ROUNDS := 2
const KIND_A_MS := 100

func _kind(kind_name: String) -> void:
	_step = "kind %s" % kind_name
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))
	var sp: int = int(((cfg as Dictionary).get("species", {}) as Dictionary).get(kind_name, {}).get("number", -1)) if cfg is Dictionary else -1

	if not admin or sp < 0:
		_fail("kind", kind_name, "no such species in data/animals/animals.json, or no --robot-admin: nothing measured")
		return

	_kind_sp = sp

	if robot_name.ends_with("1") and _share(SERVER_CONTROL) != "":
		_write(_share(SERVER_CONTROL), "where %d" % sp)   # the server's own place of the kind every 0.5 s (AUDIT where; robot_kinds.py)
	_give("spear", 1)
	await _check_pack("kind spear")
	var spear: int = _slot_of("spear")

	if spear > 0:
		client.net.inventory_action.rpc_id(1, NetScript.ACT_MOVE, spear, 0, 0, Vector3.ZERO)
		await _check_pack("spear to hand")

	for round_n in KIND_ROUNDS:
		if robot_name.ends_with("1"):
			client.net.admin_place.rpc_id(1, "animal", client.body.global_position - client.body.global_transform.basis.z * 15.0, kind_name)

		await _wait(3.0)
		var _found: bool = await _hunt(sp, KIND_S)
		await _wait(2.0)

	var st: Array = _kstat.get(sp, [0, 0.0, 0.0, 0])
	FreezeWatchScript.printer.line("ROBOT %s KIND %s %d frames %d largest_step %.2f m largest_x %.2f over_1m %d inside_other %d lowest_health %d" % [
		robot_name, kind_name, sp, int(st[0]), float(st[1]), float(st[2]), int(st[3]), _inside_other, _lowest_health])
	FreezeWatchScript.printer.line("ROBOT %s SLIDE %s model_samples %d moving %d standing_clip %d rate_top %d rate_bottom %d feet_off %d feet_ground %.2f..%.2f%s" % [
		robot_name, kind_name, int(_slide[0]), int(_slide[1]), int(_slide[2]), int(_slide[3]), int(_slide[4]), int(_slide[5]),
		float(_slide[6]) if int(_slide[1]) > 0 else 0.0, float(_slide[7]), "" if int(_slide[0]) > 0 else " (no bought models here: code-built bodies step by the ground speed)"])

	if int(st[0]) == 0:
		_fail("kind", kind_name, "no %s was ever drawn near: nothing measured" % kind_name)


func _kind_frame(id: int, pos: Vector3, a_now: bool) -> void:
	var pv: Node = client._player_view

	if pv != null:
		for row in pv.drawn():
			var p: Vector3 = row["pos"]

			if Vector2(pos.x - p.x, pos.z - p.z).length() < INSIDE_M and absf(pos.y - p.y) < 1.2:
				_inside_other += 1

	if a_now:
		var b: Dictionary = client._animal_view_node._bodies.get(id, {})
		_slide_sample(id, pos, b)
		FreezeWatchScript.printer.line("ROBOT %s A %d %d %.2f %.2f %d" % [robot_name, _now_ms(), id, pos.x, pos.z, int(b.get("state", -1))])


func _kind_hurt(before: int, after: int) -> void:
	var me: Vector3 = client.body.global_position
	var best: int = -1
	var gap: float = INF

	for row in client._animal_view_node.drawn_positions():
		var d: float = Vector2((row[1] as Vector3).x - me.x, (row[1] as Vector3).z - me.z).length()

		if int(_species.get(int(row[0]), 0)) == _kind_sp and d < gap:
			gap = d
			best = int(row[0])

	var b: Dictionary = client._animal_view_node._bodies.get(best, {})
	FreezeWatchScript.printer.line("ROBOT %s BITTEN %d health %d -> %d by %d drawn gap %.2f state %d at %.2f %.2f" % [robot_name, _now_ms(), before, after, best, gap, int(b.get("state", -1)), me.x, me.z])


# Feet against ground, every A sample of a body drawn with a bought model (an AnimationPlayer; none in cloud clones, tools/skip_models.sh).
# The ground speed is the drawn body's own over the last sample (~100 ms). The feet: the moving clip's foot speed (its travel_mps, measured
# from the feet, docs/design/FOOT_SLIDING.md) x the rate it plays at; a clip with no travel_mps plays at speed / its row speed, so its feet
# match the eased speed (animal_view.gd) unless the rate is held at AnimalGait's top or bottom. Counted while the body moves over 0.5 m/s:
# a standing clip (feet still), the rate at its top (feet slower than the ground) or bottom, feet off the ground speed by over a third.
func _slide_sample(id: int, pos: Vector3, b: Dictionary) -> void:
	var now: int = Time.get_ticks_msec()
	var was: Array = _slide_was.get(id, [])
	_slide_was[id] = [pos, now]

	if was.is_empty() or now - int(was[1]) <= 0 or now - int(was[1]) > 400 or b.is_empty() or not (b["node"] as Node3D).has_meta("player"):
		return

	var player: AnimationPlayer = (b["node"] as Node3D).get_meta("player")
	_slide[0] = int(_slide[0]) + 1
	var ground: float = Vector2(pos.x - (was[0] as Vector3).x, pos.z - (was[0] as Vector3).z).length() / (float(now - int(was[1])) * 0.001)

	if ground < 0.5:
		return

	_slide[1] = int(_slide[1]) + 1
	var role: String = str(b.get("gait_role", ""))

	if role == "" or player.current_animation == "":
		_slide[2] = int(_slide[2]) + 1
		_slide[6] = minf(float(_slide[6]), 0.0)
		_slide[5] = int(_slide[5]) + 1
		return

	if player.speed_scale >= 2.49:
		_slide[3] = int(_slide[3]) + 1
	elif player.speed_scale <= 0.41:
		_slide[4] = int(_slide[4]) + 1

	var anim: Animation = player.get_animation(player.current_animation) if player.has_animation(player.current_animation) else null
	var feet: float = player.speed_scale * float(anim.get_meta("travel_mps")) if anim != null and anim.has_meta("travel_mps") else float(b.get("spd", 0.0))
	var ratio: float = feet / ground
	_slide[6] = minf(float(_slide[6]), ratio)
	_slide[7] = maxf(float(_slide[7]), ratio)

	if ratio < 0.67 or ratio > 1.5:
		_slide[5] = int(_slide[5]) + 1


# --- plan together (players thread, 23 Nov 2026): two robots on the same thing in the same second, over the lossy link -------------------
# Both robots stand at the spawn. Robot 1 builds a wicker basket; both open it. Then, each on one agreed unix ms (_tg_go: both write when
# they are ready, both start TG_LEAD_MS after the later one): both put 2 twine in; both take 4 twine out; Robot 1 drops 3 stones and both pick
# the stack up; Robot 2's link is held 20 s (lossy_link "hold <its port> 20": packets dropped both ways, the connection kept) while Robot 1
# puts in and takes out of the open basket; then Robot 2 is back. After each, once quiet: the item's count over both packs, the basket (as
# Robot 1's open window shows it) and the ground within TG_GROUND_M of Robot 1 must equal the count before (_tg_total, Robot 1 checks);
# each robot's open window must equal the server's (AUDIT chest, the robot audit prints each open container's signature on a change).
const TG_LEAD_MS := 1500
const TG_GROUND_M := 8.0
const TG_HOLD_S := 20.0

var _tg_chest_id: int = -1
var _tg_chest = null              # this robot's open window on the basket (chest_received)
var _tg_chest_ms: int = 0


func _together() -> void:
	_step = "together"
	var one: bool = robot_name.ends_with("1")

	if not admin or _share("x") == "":
		_fail("together", "setup", "plan together needs --robot-admin and tools/robots.sh (ROBOT_SHARE): nothing measured")
		return

	client.net.chest_received.connect(func(id: int, bytes: PackedByteArray):
		if id == _tg_chest_id:
			var inv = InventoryScript.new(client.items.table)
			inv.from_bytes(bytes)
			_tg_chest = inv
			_tg_chest_ms = Time.get_ticks_msec())

	# Out of the starter camp's ground (no building near its tree), both the same way; then the basket: Robot 1 builds it, both open it.
	var _out: bool = await _run_to(Vector3(58202.0, client.body.global_position.y, 71364.0), 25.0, 2.0)
	_release_all()

	if one:
		_give("stone_knife", 1)
		await _check_pack("together knife")
		var basket: int = await _build_basket()
		_write(_share("tg_basket.txt"), str(basket))

		if basket < 0:
			_fail("together", "basket", "Robot 1 could not build the basket: nothing measured")
			return

	var said: String = await _tg_read("tg_basket.txt", 60.0)

	if said == "" or int(said) < 0:
		_fail("together", "basket", "no basket from Robot 1 in 60 s")
		return

	_tg_chest_id = int(said)
	await _tg_near_basket()
	_give("twine", 4)
	await _check_pack("together twine")
	client.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_OPEN, _tg_chest_id, 0, 0, Vector3.ZERO)
	await _wait(2.0)

	if _tg_chest == null:
		_fail("together", "open", "opened the basket (world item %d): no contents came" % _tg_chest_id)
		return

	var twine: int = _num("twine")
	var stone: int = _num("stone")
	var twine_all: int = await _tg_total("open", twine)

	# 1. Both put 2 twine in, in the same second.
	await _tg_go("put")
	client.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_PUT, _slot_of("twine"), _tg_chest_id, 2, Vector3.ZERO)
	await _tg_after("put", twine, twine_all, "both put 2 twine in")

	# 2. Both take 4 twine out (there are 4 in): one gets them, or both get 2; none is made or lost.
	await _tg_go("take")
	var slot: int = _tg_chest.numbers.find(twine) if _tg_chest != null else -1
	client.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_TAKE, maxi(slot, 0), _tg_chest_id, 4, Vector3.ZERO)
	await _tg_after("take", twine, twine_all, "both took 4 twine out")

	# 3. One dropped stack, both pick it up at once.
	var stack: int = -1

	if one:
		_give("stone", 3)
		await _check_pack("together stones")
		var here: Vector3 = client.body.global_position
		var known: Dictionary = client.items._world.duplicate()
		client.net.inventory_action.rpc_id(1, NetScript.ACT_DROP, _slot_of("stone"), 0, 3, Vector3(here.x + 1.0, here.y - 0.9, here.z))
		var until: int = Time.get_ticks_msec() + 8000

		while stack < 0 and Time.get_ticks_msec() < until:
			for id in client.items._world:
				if not known.has(id) and int(client.items._world[id].get("number", 0)) == stone:
					stack = int(id)

			await get_tree().process_frame

		_write(_share("tg_stack.txt"), str(stack))

	said = await _tg_read("tg_stack.txt", 30.0)
	stack = int(said) if said != "" else -1

	if stack < 0:
		_fail("together", "stack", "Robot 1's dropped stones never showed as a world item")
	else:
		var until2: int = Time.get_ticks_msec() + 8000

		while not client.items._world.has(stack) and Time.get_ticks_msec() < until2:
			await get_tree().process_frame

		var stones_all: int = await _tg_total("stones", stone)
		await _tg_go("pick")
		client.net.inventory_action.rpc_id(1, NetScript.ACT_PICKUP, stack, 0, 0, Vector3.ZERO)
		await _tg_after("pick", stone, stones_all, "both picked up the same 3 stones")

	# 4. Robot 2's link held 20 s while Robot 1 changes the open basket; then Robot 2 must see the basket as it is.
	await _tg_go("hold")

	if not one:
		var port: int = (client.multiplayer.multiplayer_peer as ENetMultiplayerPeer).host.get_local_port()
		_write(_share(CONTROL_FILE), "hold %d %d" % [port, int(TG_HOLD_S)])
		FreezeWatchScript.printer.line("ROBOT %s step together: link held %.0f s (udp port %d)" % [robot_name, TG_HOLD_S, port])
		var was_ms: int = _tg_chest_ms
		await _wait(TG_HOLD_S + 2.0)
		var until3: int = Time.get_ticks_msec() + 8000

		while _tg_chest_ms == was_ms and Time.get_ticks_msec() < until3:
			await get_tree().process_frame

		FreezeWatchScript.printer.line("ROBOT %s step together: back after the hold, connected %s, the basket window %s" % [robot_name,
			str(client.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED), "updated" if _tg_chest_ms != was_ms else "never updated"])
	else:
		await _wait(4.0)   # Robot 2 is held now
		_give("twine", 3)
		await _check_pack("together twine while held")
		client.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_PUT, _slot_of("twine"), _tg_chest_id, 3, Vector3.ZERO)
		await _check_pack("put while the other is held")
		await _wait(TG_HOLD_S)

	var held_total: int = await _tg_total("held", twine)

	if one and held_total != twine_all + 3:
		_fail("together", "held", "Robot 1 put 3 more twine in while Robot 2 was held: twine over both packs, the basket and the ground %d, wanted %d" % [held_total, twine_all + 3])

	await _tg_go("after_hold")
	await _tg_window("after_hold")
	client.net.inventory_action.rpc_id(1, NetScript.ACT_CHEST_CLOSE, _tg_chest_id, 0, 0, Vector3.ZERO)
	await _tg_site()
	await _tg_door()
	await _tg_seen()
	FreezeWatchScript.printer.line("ROBOT %s step together: done" % robot_name)


const TG_CRATE_BP := 168      # data/items/blueprints.json wooden_crate: 5 lumber, 8 copper nails
const TG_FRAME_BP := 5        # doorway_section: 4 lumber, 1 twine
const TG_DOOR_BP := 276       # rustic_door: 5 lumber (hangs in a doorway_section)
const TG_SWINGS := 4          # Robot 2's blows while Robot 1 watches
const TG_SPOTS := [Vector3(0.0, 0.0, -3.0), Vector3(0.0, 0.0, 3.0), Vector3(-3.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0), Vector3(-3.0, 0.0, -3.0), Vector3(3.0, 0.0, 3.0)]   # where Robot 1 tries a blueprint, from its own place


# The hammer in hand (pack slot 0), given first.
func _tg_hammer() -> void:
	if _slot_of("stone_hammer") < 0:
		_give("stone_hammer", 1)
		await _check_pack("together hammer")

	if _slot_of("stone_hammer") > 0:
		client.net.inventory_action.rpc_id(1, NetScript.ACT_MOVE, _slot_of("stone_hammer"), 0, 0, Vector3.ZERO)
		await _check_pack("hammer to hand")


# Robot 1 sets a blueprint down with the hammer at the first of `offsets` (from its own place) the server takes: its world id (a new world
# item there), or -1; written to `file` for Robot 2. A spot refused (something in the way) moves on to the next.
func _tg_place(bp: int, offsets: Array, file: String) -> int:
	var id: int = -1
	var said_from: int = _notices.size()
	var tried: Array = []

	for off in offsets:
		var spot: Vector3 = client.body.global_position + (off as Vector3)
		var ground: float = float(client.items._ground_below.call(spot))
		spot.y = ground if not is_nan(ground) else client.body.global_position.y - 0.9
		tried.append(str(spot.round()))
		var known: Dictionary = client.items._world.duplicate()
		var heard: int = _notices.size()
		client.net.inventory_action.rpc_id(1, NetScript.ACT_PLACE_BLUEPRINT, bp, 0, 0, spot)
		var until: int = Time.get_ticks_msec() + 6000

		while id < 0 and Time.get_ticks_msec() < until and not _notices.slice(heard).any(func(t): return str(t).contains("in the way")):   # a spot refused moves on; any other word waits the 6 s out
			for w in client.items._world:
				if not known.has(w) and Vector2(client.items._world[w]["pos"].x - spot.x, client.items._world[w]["pos"].z - spot.z).length() < 1.5:
					id = int(w)

			await get_tree().process_frame

		if id >= 0:
			break

	if id < 0:
		_fail("together", "place:%d" % bp, "blueprint %d at %s: no new world item came (said %s)" % [bp, str(tried), str(_notices.slice(said_from))])

	_write(_share(file), str(id))
	return id


# The other robot as this client draws it (player_view.gd _bodies, the one other player): its row, or {}.
func _tg_other() -> Dictionary:
	var pv: Node = client._player_view

	if pv == null:
		return {}

	for peer in pv._bodies:
		if int(peer) != client.multiplayer.get_unique_id():
			return pv._bodies[peer]

	return {}


# 7. Robot 1 watches Robot 2 (players thread, #1788): Robot 2 swings TG_SWINGS times, and Robot 1's rows for it must show its swing count
# change; then Robot 2 is passed out by the cold (server_control.txt), and Robot 1 must draw it lying (stance 3) and, after it wakes, standing.
func _tg_seen() -> void:
	var one: bool = robot_name.ends_with("1")
	await _tg_go("swing")

	if not one:
		for _n in TG_SWINGS:
			_strike_at(-client.body.global_transform.basis.z)
			await _wait(1.2)
	else:
		var changes: int = 0
		var was: int = int(_tg_other().get("swings", -1))
		var until: int = Time.get_ticks_msec() + int(TG_SWINGS * 1200 + 3000)

		while Time.get_ticks_msec() < until:
			var now: int = int(_tg_other().get("swings", -1))

			if now != was and now >= 0 and was >= 0:
				changes += 1

			was = now
			await get_tree().process_frame

		FreezeWatchScript.printer.line("ROBOT %s TOGETHER seen swings: Robot 2 swung %d times, its swing count changed %d times in Robot 1's rows" % [robot_name, TG_SWINGS, changes])

		if changes == 0:
			_fail("together", "seen_swing", "Robot 2 swung %d times beside Robot 1; Robot 1's rows never showed its swing count change" % TG_SWINGS)

	await _tg_go("out")

	if not one:
		_write(_share(SERVER_CONTROL), "cold %d" % client.multiplayer.get_unique_id())
		var t0: int = Time.get_ticks_msec()

		while _woke_at == null and Time.get_ticks_msec() - t0 < 240000:
			await get_tree().process_frame

		_write(_share(SERVER_CONTROL), "warm %d" % client.multiplayer.get_unique_id())
		await _wait(1.0)
		_write(_share("tg_woke.txt"), "%s %.1f %.1f %.1f" % [str(_woke_at != null), client.body.global_position.x, client.body.global_position.y, client.body.global_position.z])
		var _done: String = await _tg_read("tg_seen_done.txt", 30.0)   # stay in the world while Robot 1 looks
		return

	var lying_ms: int = 0
	var stances: Dictionary = {}
	var standing: int = -1   # the stance drawn after it lay: 0 once it is drawn standing again
	var t1: int = Time.get_ticks_msec()
	var woke_ms: int = -1

	while Time.get_ticks_msec() - t1 < 250000 and (woke_ms < 0 or (standing != 0 and Time.get_ticks_msec() - woke_ms < 8000)):
		var b: Dictionary = _tg_other()

		if woke_ms < 0 and _tg_read_now("tg_woke.txt") != "":
			woke_ms = Time.get_ticks_msec()

		if not b.is_empty():
			var st: int = int(b.get("state", 0)) & 3
			stances[st] = int(stances.get(st, 0)) + 1

			if st == 3:
				lying_ms += int(get_process_delta_time() * 1000.0)
			elif stances.has(3):
				standing = st

		await get_tree().process_frame

	var woke: String = _tg_read_now("tg_woke.txt")
	_write(_share("tg_seen_done.txt"), "done")

	FreezeWatchScript.printer.line("ROBOT %s TOGETHER seen out: Robot 2 woke %s; stances drawn (stance: frames) %s, lying %d ms; after waking drawn stance %d" % [robot_name, woke, str(stances), lying_ms, standing])
	_write(_share(SERVER_CONTROL), "warm %d" % client.multiplayer.get_unique_id())

	if not woke.begins_with("true"):
		_fail("together", "seen_out", "Robot 2 never passed out from the cold in 240 s: nothing to watch")
	elif not stances.has(3):
		_fail("together", "seen_lying", "Robot 2 passed out; Robot 1 never drew it lying down (stance 3): stances drawn %s" % str(stances))
	elif standing != 0:
		_fail("together", "seen_stand", "Robot 2 woke; Robot 1 still draws stance %d for it 8 s later (wanted standing, 0; -1: not drawn)" % standing)


# Whether a robot wrote that the cold moved `peer` to a rescue spot in the last 5 s (RESCUE_FILE): read only after a big drawn step.
func _rescued(peer: int) -> bool:
	if _share(RESCUE_FILE) == "" or not FileAccess.file_exists(_share(RESCUE_FILE)):
		return false

	for line in FileAccess.get_file_as_string(_share(RESCUE_FILE)).split("\n"):
		var p: PackedStringArray = line.split(" ")

		if p.size() == 2 and int(p[0]) == peer and absi(_now_ms() - int(p[1])) < 5000:
			return true

	return false


# A share file's text now ("" when it is not there yet).
func _tg_read_now(file: String) -> String:
	var f := FileAccess.open(_share(file), FileAccess.READ)
	return f.get_as_text().strip_edges() if f != null else ""


# Up to `near_m` of a world item, so a hammer blow or E reaches it.
func _tg_near(id: int) -> void:
	var until: int = Time.get_ticks_msec() + 5000

	while not client.items._world.has(id) and Time.get_ticks_msec() < until:
		await get_tree().process_frame

	if client.items._world.has(id):
		var _near: bool = await _go_to(client.items._world[id]["pos"], 10.0, 1.6)


# One look at a world item as this client draws it: its item number and state (a site, a standing piece, a door shut or open).
func _tg_look(id: int) -> String:
	var w: Dictionary = client.items._world.get(id, {})
	return "gone" if w.is_empty() else "%d/%d%s" % [int(w.get("number", 0)), int(w.get("state", 0)), " site" if w.get("site") != null else ""]


# Both robots' looks at one world item 2.5 s after a step: they must be the same (each writes its own, Robot 1 compares). Robot 1's look.
func _tg_same_look(step: String, id: int) -> String:
	await _wait(2.5)
	var me: String = "1" if robot_name.ends_with("1") else "2"
	_write(_share("tg_look_%s_%s.txt" % [step, me]), _tg_look(id))

	if me != "1":
		return ""

	var them: String = await _tg_read("tg_look_%s_2.txt" % step, 60.0)
	FreezeWatchScript.printer.line("ROBOT %s TOGETHER look %s: world item %d, mine %s, Robot 2 %s" % [robot_name, step, id, _tg_look(id), them])

	if them != _tg_look(id):
		_fail("together", "look:%s" % step, "world item %d: Robot 1 draws it %s, Robot 2 %s (2.5 s after)" % [id, _tg_look(id), them])

	return _tg_look(id)


# 5. One crate site hammered by both at once, each with part of what it needs: exactly its cost goes in (5 lumber, 8 nails), once.
func _tg_site() -> void:
	var one: bool = robot_name.ends_with("1")
	await _tg_hammer()
	_give("lumber", 3 if one else 4)

	if not one:
		_give("copper_nails", 10)

	var lumber: int = _num("lumber")
	var nails: int = _num("copper_nails")
	var wood_all: int = await _tg_total("site_wood", lumber)
	var nails_all: int = await _tg_total("site_nails", nails)
	var site: int = await _tg_place(TG_CRATE_BP, TG_SPOTS, "tg_site.txt") if one else -1
	var said: String = await _tg_read("tg_site.txt", 60.0)   # Robot 1 may try all six spots (6 s each)
	site = int(said) if said != "" else -1

	if site < 0:
		return

	await _tg_near(site)
	await _tg_go("hammer")

	for _n in 8:   # both hammer it, a blow each 0.8 s
		client.net.inventory_action.rpc_id(1, NetScript.ACT_REPAIR_STRUCT, site, 1, 0, Vector3.ZERO)
		await _wait(0.8)

	var wood_now: int = await _tg_total("site_wood_after", lumber)
	var nails_now: int = await _tg_total("site_nails_after", nails)

	if one and (wood_all - wood_now != 5 or nails_all - nails_now != 8):
		_fail("together", "site", "both hammered one crate site: %d lumber went in (its cost 5), %d nails (8)" % [wood_all - wood_now, nails_all - nails_now])

	var look: String = await _tg_same_look("site", site)

	if one:
		FreezeWatchScript.printer.line("ROBOT %s step together: crate site hammered by both, %d lumber and %d nails went in, drawn %s" % [robot_name, wood_all - wood_now, nails_all - nails_now, look])


# 6. One door: Robot 1 builds a doorway frame and hangs a rustic door; both use it at once (the ruling: it toggles twice, so it ends as it
# began), then each in turn: both must draw it the same each time.
func _tg_door() -> void:
	var one: bool = robot_name.ends_with("1")
	var door: int = -1

	if one:
		_give("lumber", 12)
		_give("twine", 2)
		await _check_pack("together door wood")
		var frame: int = await _tg_place(TG_FRAME_BP, TG_SPOTS, "tg_frame.txt")
		var at: Vector3 = client.items._world.get(frame, {}).get("pos", client.body.global_position)
		await _tg_near(frame)

		for _n in 8:
			client.net.inventory_action.rpc_id(1, NetScript.ACT_REPAIR_STRUCT, frame, 1, 0, Vector3.ZERO)
			await _wait(0.6)

		await _wait(1.5)
		var fpos: Vector3 = client.items._world.get(frame, {}).get("pos", at)
		var known: Dictionary = client.items._world.duplicate()
		client.net.inventory_action.rpc_id(1, NetScript.ACT_PLACE_BLUEPRINT, TG_DOOR_BP, 0, 0, fpos + Vector3(0.1, 0.4, 0.15))
		var until: int = Time.get_ticks_msec() + 8000

		while door < 0 and Time.get_ticks_msec() < until:
			for w in client.items._world:
				if not known.has(w) and int(w) != frame and Vector2(client.items._world[w]["pos"].x - fpos.x, client.items._world[w]["pos"].z - fpos.z).length() < 2.0:
					door = int(w)

			await get_tree().process_frame

		for _n in 8:
			if door >= 0:
				client.net.inventory_action.rpc_id(1, NetScript.ACT_REPAIR_STRUCT, door, 1, 0, Vector3.ZERO)

			await _wait(0.6)

		if door < 0:
			_fail("together", "door", "the rustic door blueprint at the doorway frame (%d, drawn %s) gave no world item: %s" % [frame, _tg_look(frame), str(_notices.slice(-3))])

		_write(_share("tg_door.txt"), str(door))

	var said: String = await _tg_read("tg_door.txt", 90.0)
	door = int(said) if said != "" else -1

	if door < 0:
		return

	await _tg_near(door)
	FreezeWatchScript.printer.line("ROBOT %s TOGETHER door %d drawn %s, %.1f m off" % [robot_name, door, _tg_look(door), client.body.global_position.distance_to(client.items._world.get(door, {}).get("pos", Vector3.ZERO))])

	var start: String = await _tg_same_look("door_start", door)
	await _tg_go("door_both")
	client.net.inventory_action.rpc_id(1, NetScript.ACT_USE_STRUCT, door, 0, 0, Vector3.ZERO)
	var both: String = await _tg_same_look("door_both", door)

	if one and both != start:
		_fail("together", "door_both", "both used the door at once: it went %s -> %s (two uses toggle twice and end as it began)" % [start, both])

	for who in ["1", "2"]:
		await _tg_go("door_%s" % who)

		if robot_name.ends_with(who):
			client.net.inventory_action.rpc_id(1, NetScript.ACT_USE_STRUCT, door, 0, 0, Vector3.ZERO)

		var after: String = await _tg_same_look("door_%s" % who, door)

		if one:
			FreezeWatchScript.printer.line("ROBOT %s step together: Robot %s used the door: %s" % [robot_name, who, after])


# Both robots near the basket (Robot 2 walks to it): CHEST_REACH_M on the server.
func _tg_near_basket() -> void:
	var w: Dictionary = {}
	var until: int = Time.get_ticks_msec() + 8000

	while w.is_empty() and Time.get_ticks_msec() < until:
		w = client.items._world.get(_tg_chest_id, {})
		await get_tree().process_frame

	if not w.is_empty() and Vector2(w["pos"].x - client.body.global_position.x, w["pos"].z - client.body.global_position.z).length() > 1.8:
		var _there: bool = await _go_to(w["pos"], 15.0, 1.5)


func _tg_read(file: String, s: float) -> String:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)

	while Time.get_ticks_msec() < until:
		if FileAccess.file_exists(_share(file)):
			var t: String = FileAccess.get_file_as_string(_share(file)).strip_edges()

			if t != "":
				return t

		await get_tree().process_frame

	return ""


# Both ready, then both go on one unix ms: TG_LEAD_MS after the later robot said ready.
func _tg_go(step: String) -> void:
	_step = "together %s" % step
	var me: String = "1" if robot_name.ends_with("1") else "2"
	var other: String = "2" if me == "1" else "1"
	_write(_share("tg_ready_%s_%s.txt" % [step, me]), str(_now_ms()))
	var them: String = await _tg_read("tg_ready_%s_%s.txt" % [step, other], 120.0)

	if them == "":
		_fail("together", step, "the other robot never got to %s in 120 s" % step)
		return

	var go: int = maxi(int(FileAccess.get_file_as_string(_share("tg_ready_%s_%s.txt" % [step, me]))), int(them)) + TG_LEAD_MS

	while _now_ms() < go:
		await get_tree().process_frame


# The count of one item: this robot's pack, written for the other; Robot 1 adds the other's pack, its basket window and the ground near it.
func _tg_total(step: String, number: int) -> int:
	await _quiet()
	await _wait(1.5)
	var me: String = "1" if robot_name.ends_with("1") else "2"
	_write(_share("tg_count_%s_%s.txt" % [step, me]), str(int(client.items.inventory.count_of(number))))

	if me != "1":
		return 0

	var them: String = await _tg_read("tg_count_%s_2.txt" % step, 60.0)
	var ground: int = 0

	for id in client.items._world:
		var w: Dictionary = client.items._world[id]

		if int(w.get("number", 0)) == number and Vector2(w["pos"].x - client.body.global_position.x, w["pos"].z - client.body.global_position.z).length() < TG_GROUND_M:
			ground += int(w.get("count", 1))

	var in_box: int = int(_tg_chest.count_of(number)) if _tg_chest != null else 0
	var total: int = int(client.items.inventory.count_of(number)) + int(them) + in_box + ground
	FreezeWatchScript.printer.line("ROBOT %s TOGETHER %s %s: packs %d + %s, basket %d, ground %d = %d" % [robot_name, step, client.items.table.id_of(number), int(client.items.inventory.count_of(number)), them, in_box, ground, total])
	return total


# After a step: the totals as before (Robot 1), and this robot's basket window against the server's.
func _tg_after(step: String, number: int, before: int, what: String) -> void:
	var total: int = await _tg_total(step, number)

	if robot_name.ends_with("1") and total != before:
		_fail("together", step, "%s: %s over both packs, the basket and the ground went %d -> %d" % [what, client.items.table.id_of(number), before, total])

	await _tg_window(step)


func _tg_window(step: String) -> void:
	var server: String = ""
	var text: String = ""
	var log_file := FileAccess.open(_share("server.log"), FileAccess.READ) if FileAccess.file_exists(_share("server.log")) else null

	if log_file != null:   # the tail only: the newest AUDIT chest line is near the end, and a whole log read is a hitch
		log_file.seek(maxi(0, log_file.get_length() - 400000))
		text = log_file.get_buffer(log_file.get_length() - log_file.get_position()).get_string_from_utf8()

	for line in text.split("\n"):
		if line.begins_with("AUDIT chest %d " % _tg_chest_id):
			server = line.split(" ")[4]

	var mine: String = RobotRules.signature(_tg_chest) if _tg_chest != null else "none"
	FreezeWatchScript.printer.line("ROBOT %s TOGETHER window %s: mine %s, server %s" % [robot_name, step, mine, server])

	if server == "":
		_fail("together", "window:%s" % step, "no AUDIT chest line for basket %d in the server log: its contents never printed" % _tg_chest_id)
	elif mine != server:
		_fail("together", "window:%s" % step, "this robot's open basket window (%s) is not the server's (%s) once quiet" % [mine, server])
