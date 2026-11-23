extends SceneTree

# Another player as this client draws them (src/client/player_view.gd), photographed in seconds with no server, no second client and no world:
# PlayerView is fed the same messages the server sends (player_look once, then players rows every 125 ms, as server_players.gd SEND_S) for one
# player standing or walking north, holding an item, and a camera round that body takes one PNG per angle. For Lane A's confirmation pictures
# (23 Nov 2026: a two-window session cannot be run unattended). Not the game's lighting, terrain or grass.
#
#   godot --path . --script res://tools/shot_remote.gd -- --item=wooden_spear --out=E:/Software/godotDev/DynastyALWL_Evidence/shots
#   options: --item=ID       the item in the other player's hand (omit for an empty hand)
#            --body=body_1   the body model (body_1 = Body A, body_2 = Body B)
#            --walk=M_PER_S  walks north (-Z) at this speed (0 = standing, 1.6 = walk, 4 = jog, 6 = run); the camera keeps pace
#            --stance=N      0 standing, 1 crouched, 2 sitting, 3 lying (stance.gd; the state byte)
#            --left=ID       the item in the left hand (torch, lantern, shield); --lit: a torch burning; --night: dark sky, no sun (to see its light)
#            --asleep        the asleep bit (with --stance=3: a sleeping player)
#            --swing         a blow before each picture (the swing count moves on), taken SWING_LEAD_S into the remote clip: the impact
#            --angles="name:deg:dist;..."  camera deg round the body from its front (0 front, 90 its left, -90 its right, 180 behind), dist m away;
#                            under 2 m it aims at the held item, else at the chest (default right:-90:2.4;left:90:2.4;front:0:2.4;hand:-90:1.0)
#            --name=NAME     file prefix (default remote_<item or hand>): NAME_<angle>.png
#            --settle=S      seconds of rows before the first picture (default 2.5)
# Needs a window and a GPU like tools/shot_held.gd; under --headless nothing is drawn and it exits 4.
# Prints one "shot remote: saved PATH" line per picture and "shot remote: N picture(s) in T s"; exit 4 when a picture was not saved, 2 on a bad option.

const PlayerViewScript := preload("res://src/client/player_view.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

const SIZE := Vector2i(1280, 720)
const FOV := 75.0
const FEET_M := 0.9     # player_view.gd FEET_M: a players row carries the standing body's middle, 0.9 m over the feet (stance.gd; the game's own report)
const CHEST_Y := 0.45   # the chest over that middle
const LOW_Y := -0.55    # a sitting or lying body's middle-ish over that middle
const ROW_MS := 125
const PEER := 7

var _view: Node3D
var _at: Vector3 = Vector3(0.0, FEET_M, 0.0)   # feet on the floor at y 0 (Lane A, 23 Nov 2026: at y 0 the body stood 0.9 m sunk in the floor)
var _server_ms: int = 10000
var _walk: float = 0.0
var _stance: int = 0
var _held: int = 0
var _asleep: bool = false
var _left: int = 0
var _lit: bool = false
var _swings: int = 0


func _init() -> void:
	var started: int = Time.get_ticks_msec()
	var item: String = ""
	var out: String = "user://shots"
	var prefix: String = ""
	var body: String = "body_1"
	var swing: bool = false
	var night: bool = false
	var left_id: String = ""
	var settle: float = 2.5
	var angles_text: String = "right:-90:2.4;left:90:2.4;front:0:2.4;hand:-90:1.0"

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--item="):
			item = a.trim_prefix("--item=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--name="):
			prefix = a.trim_prefix("--name=")
		elif a.begins_with("--body="):
			body = a.trim_prefix("--body=")
		elif a.begins_with("--walk="):
			_walk = float(a.trim_prefix("--walk="))
		elif a.begins_with("--stance="):
			_stance = clampi(int(a.trim_prefix("--stance=")), 0, 3)
		elif a.begins_with("--left="):
			left_id = a.trim_prefix("--left=")
		elif a == "--lit":
			_lit = true
		elif a == "--night":
			night = true
		elif a == "--asleep":
			_asleep = true
		elif a == "--swing":
			swing = true
		elif a.begins_with("--settle="):
			settle = maxf(float(a.trim_prefix("--settle=")), 0.5)
		elif a.begins_with("--angles="):
			angles_text = a.trim_prefix("--angles=")

	if DisplayServer.get_name() == "headless":
		print("shot remote: FAIL needs a window and a GPU (headless draws nothing)")
		quit(4)
		return

	var table = ItemTableScript.load_default()

	if item != "":
		_held = int(table.number_of(item))

		if _held <= 0:
			print("shot remote: FAIL no item %s" % item)
			quit(2)
			return

	if left_id != "":
		_left = int(table.number_of(left_id))

		if _left <= 0:
			print("shot remote: FAIL no item %s" % left_id)
			quit(2)
			return

	if prefix == "":
		prefix = "remote_" + (item if item != "" else "hand")

	DirAccess.make_dir_recursive_absolute(out)
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68) if not night else Color(0.04, 0.05, 0.08)

	if night:
		env.background_color = Color(0.01, 0.015, 0.03)
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.shadow_enabled = true
	sun.visible = not night
	vp.add_child(sun)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(400, 400)
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.32, 0.42, 0.22)
	plane.material = floor_material
	floor_mesh.mesh = plane
	vp.add_child(floor_mesh)
	root.add_child(vp)
	var cam: Camera3D = Camera3D.new()
	cam.fov = FOV
	vp.add_child(cam)
	cam.current = true
	cam.position = Vector3(0.0, 1.6, 3.0)
	_view = PlayerViewScript.new()
	_view.table = table
	vp.add_child(_view)
	_view.on_look(PEER, "Remote " + body, body, "", PackedInt32Array())

	for i in range(600):   # the body files load on loader threads (on_look warms them)
		if PlayerViewScript._can_make({"body": body, "code": ""}):
			break

		await process_frame

	var next_row: int = Time.get_ticks_msec()
	var ready_at: int = Time.get_ticks_msec() + int(settle * 1000.0)
	var saved: int = 0
	var wanted: int = 0
	var parts: PackedStringArray = angles_text.split(";", false)
	var shot: int = -1   # -1: settling

	var give_up: int = ready_at + 60000

	while shot < parts.size():
		if Time.get_ticks_msec() > give_up:
			print("shot remote: FAIL timed out (drawn %s)" % str(not _view._bodies.is_empty()))
			break

		if Time.get_ticks_msec() >= next_row:
			_send_row()
			next_row += ROW_MS

		var drawn: Dictionary = _view._bodies.get(PEER, {})
		await process_frame

		if drawn.is_empty():
			continue

		if Time.get_ticks_msec() < ready_at:
			cam.position = (drawn["node"] as Node3D).position + Vector3(0.0, 0.7, 3.0)   # keeps pace: full-rate animation (player_view.gd FULL_M)
			cam.look_at((drawn["node"] as Node3D).position + Vector3(0.0, _aim_y(), 0.0), Vector3.UP)
			continue

		if shot == -1:
			shot = 0
			continue

		var bits: PackedStringArray = parts[shot].split(":", false)
		shot += 1

		if bits.size() != 3 or not bits[1].is_valid_float() or not bits[2].is_valid_float():
			print("shot remote: --angles error: %s is not name:deg:dist" % parts[shot - 1])
			continue

		wanted += 1

		if swing:
			_swings += 1
			_send_row()
			var impact_at: int = Time.get_ticks_msec() + int(PlayerViewScript.SWING_LEAD_S * 1000.0)

			while Time.get_ticks_msec() < impact_at:
				if Time.get_ticks_msec() >= next_row:
					_send_row()
					next_row += ROW_MS

				await process_frame

		var node: Node3D = drawn["node"]
		var held_node: Node3D = drawn.get("held_node", null) as Node3D
		var deg: float = deg_to_rad(float(bits[1]))
		var dist: float = float(bits[2])
		var aim: Vector3 = held_node.global_position if dist < 2.0 and held_node != null and is_instance_valid(held_node) else node.global_position + Vector3(0.0, _aim_y(), 0.0)
		var side: Vector3 = node.global_transform.basis * Vector3(-sin(deg), 0.0, -cos(deg))
		cam.global_position = aim + side * dist + Vector3(0.0, 0.1, 0.0)
		cam.look_at(aim, Vector3.UP)
		await RenderingServer.frame_post_draw
		var image: Image = vp.get_texture().get_image()
		var path: String = "%s/%s_%s.png" % [out, prefix, bits[0]]
		var clip: String = str(drawn["rig"].call("current")) if drawn["rig"].has_method("current") else "?"

		if image != null and image.save_png(path) == OK:
			saved += 1
			print("shot remote: saved %s (angle %s, %.2f m, body %s, walk %.1f m/s, clip %s, held %s)" % [path, bits[1], dist, body, _walk, clip, str(drawn.get("held_kind", ""))])
		else:
			print("shot remote: FAILED to save %s" % path)

	if _view._bodies.is_empty():
		print("shot remote: FAIL the other player was never drawn (body files not loaded?)")

	print("shot remote: %d picture(s) in %.1f s" % [saved, float(Time.get_ticks_msec() - started) / 1000.0])
	quit(0 if saved == wanted and saved > 0 else 4)


func _aim_y() -> float:
	return CHEST_Y if _stance <= 1 else LOW_Y


# One players row, as the server sends it: position (walking north at _walk m/s), facing north (rotation.y 0), state, held item, server ms.
func _send_row() -> void:
	_server_ms += ROW_MS
	_at += Vector3(0.0, 0.0, -_walk * float(ROW_MS) / 1000.0)
	_view.on_rows(PackedInt32Array([PEER]), PackedVector3Array([_at]), PackedFloat32Array([0.0]), PackedByteArray([_stance | (PlayerViewScript.ASLEEP if _asleep else 0) | ((_swings & 7) << PlayerViewScript.SWING_SHIFT)]), PackedInt32Array([_held]), PackedInt32Array([_server_ms]), PackedInt32Array([_left]), PackedByteArray([PlayerViewScript.MORE_LIT if _lit else 0]))
