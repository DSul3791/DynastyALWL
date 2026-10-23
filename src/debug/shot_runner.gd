extends Node

# Reference stills from the real world (cloud, lavapipe or a real GPU). The client creates this when
# started with --shots. Each shot: fly to a point, face a direction, freeze the game clock at an hour,
# optionally force the weather, wait for the ground and flora to stream in, save the 3D view as a PNG.
#
#   --shots="name:x,agl,z,yaw_deg,pitch_deg,hour[,weather];name2:..."   (weather: clear, storm, rain, snow)
#   an 8th number (m/s) shows the third-person body walking at that speed, seen from the side (e.g. 4 = walk, 8 = run)
#   agl is metres above the ground at x,z (a NEGATIVE y is an absolute height in metres instead): the runner first goes to 400 m above sea level there, waits until the
#   ground under it has loaded, then drops to the ground height plus agl
#   --shot-dir=DIR      where the PNGs go (default user://shots)
#   --shot-wait=S       seconds after connecting before the first shot (default 60)
#   --shot-settle=S     seconds per shot for streaming after the move (default 25)
#   --shot-cost         also print primitives, draw calls and objects with the sun shadows off and the flora hidden
#   --shot-admin        show the F3 debug lines in the pictures
#   --shot-nograss      hide the grass; --shot-right puts the third-person camera on the body's right (look rig)
#
# yaw 0 faces -Z (north), 90 faces -X, -90 faces +X (Godot rotation about Y). Quits after the last shot.

const Net := preload("res://src/stream/terrain_net.gd")

var client = null
var shots: Array = []
var dir: String = "user://shots"
var wait_s: float = 60.0
var settle_s: float = 25.0

var _index: int = -1
var _placed: bool = false
var _ground_wait_msec: int = 0
var _moved_msec: int = 0
var _hour: float = 12.0
var _weather: String = ""
var _busy: bool = false
var costs: bool = false
var admin_text: bool = false
var no_grass: bool = false
var give_item: String = ""      # --shot-give=ITEM[:N]: an admin give 8 s after connecting (a large log goes onto the shoulder)
var give_count: int = 1
var _given: bool = false
var drop_it: bool = false      # --shot-drop: then drop all of it onto the ground 2.2 m ahead (a real drop)
var _dropped: bool = false
var _drop_msec: int = 0
var dig_steps: int = 0         # --shot-dig=N: dig N times (Dave's recipe: spade in hand, look down, click, step forward, repeat), then turn round and look back along the trail
var _dig_i: int = 0
var _dig_next_msec: int = 0
var _dig_level: bool = false
var _dig_ballast: bool = false
var heavy: bool = false      # --shot-heavy: 400 stones in the pack first, so the dig yield spills onto the ground instead of going into the pack
var _dig_dropped: bool = false
var look_down_deg: float = -50.0      # --shot-lookdown=DEG: the pitch for ground tests (drop, dig, seeded pile); the spot fills the middle of the picture (TEST_RECIPE.md)
var back_m: float = 1.0               # --shot-back=M: the short step back before the picture
var drop_dist_m: float = 1.0          # --shot-drop-dist=M: where a --shot-drop lands ahead of the player
var expect: String = ""               # --shot-expect="text": written to the log with the state line
var ground_test: bool = false         # set by --shot-drop, --shot-dig or --shot-ground: step back and look down before the picture
var _finish_done: bool = false
var _spin_i: int = 0
var _spin_next_msec: int = 0
var _selected: bool = false
var flora_names: PackedStringArray = PackedStringArray()    # --shot-flora=raspberry,bramble: one plant of each in a row with name tags
var _flora_t: int = 0
var summer: bool = false      # --shot-summer: the plant row in its species green (the game draws every hardwood in autumn colours)
var side_dist: float = 2.8      # --shot-dist=M: third-person camera distance; under 2 m it aims at the held item
var side_sign: float = 1.0      # 1 = camera on the body's left side, -1 = right side (--shot-right)

const STORM := {"rain": 1.0, "snow": 0.0, "storm": 1.0, "cloud": 1.0, "sun": 0.0, "wind": 0.9, "wind_dir": 1.0, "temp_c": 8.0}
const RAIN := {"rain": 0.65, "snow": 0.0, "storm": 0.0, "cloud": 0.8, "sun": 0.0, "wind": 0.3, "wind_dir": 1.0, "temp_c": 9.0}
const SNOW := {"rain": 0.0, "snow": 0.6, "storm": 0.0, "cloud": 0.8, "sun": 0.0, "wind": 0.1, "wind_dir": 1.0, "temp_c": -3.0}
const CLEAR := {"rain": 0.0, "snow": 0.0, "storm": 0.0, "cloud": 0.15, "sun": 1.0, "wind": 0.1, "wind_dir": 1.0, "temp_c": 14.0}


func setup(owner_client, args: Array) -> void:
	client = owner_client

	for argument in args:
		if argument.begins_with("--shots="):
			for part in argument.trim_prefix("--shots=").split(";", false):
				var pieces: PackedStringArray = part.split(":", false)
				var numbers: PackedStringArray = pieces[1].split(",", false)
				shots.append({"name": pieces[0], "pos": Vector3(float(numbers[0]), float(numbers[1]), float(numbers[2])),
					"yaw": float(numbers[3]), "pitch": float(numbers[4]), "hour": float(numbers[5]) if numbers.size() > 5 else 12.0,
					"weather": numbers[6] if numbers.size() > 6 else "", "walk": float(numbers[7]) if numbers.size() > 7 else -1.0})
		elif argument.begins_with("--shot-dir="):
			dir = argument.trim_prefix("--shot-dir=")
		elif argument == "--shot-cost":
			costs = true
		elif argument.begins_with("--shot-dist="):
			side_dist = float(argument.trim_prefix("--shot-dist="))
		elif argument == "--shot-right":
			side_sign = -1.0
		elif argument.begins_with("--shot-flora="):
			flora_names = argument.trim_prefix("--shot-flora=").split(",", false)
		elif argument == "--shot-summer":
			summer = true
		elif argument.begins_with("--shot-give="):
			give_item = argument.trim_prefix("--shot-give=")

			if give_item.contains(":"):
				give_count = int(give_item.get_slice(":", 1))
				give_item = give_item.get_slice(":", 0)
		elif argument == "--shot-drop":
			drop_it = true
			ground_test = true
		elif argument.begins_with("--shot-lookdown="):
			look_down_deg = float(argument.trim_prefix("--shot-lookdown="))
		elif argument.begins_with("--shot-back="):
			back_m = float(argument.trim_prefix("--shot-back="))
		elif argument.begins_with("--shot-drop-dist="):
			drop_dist_m = float(argument.trim_prefix("--shot-drop-dist="))
		elif argument.begins_with("--shot-expect="):
			expect = argument.trim_prefix("--shot-expect=")
		elif argument == "--shot-heavy":
			heavy = true
		elif argument == "--shot-ground":
			ground_test = true
		elif argument.begins_with("--shot-dig="):
			dig_steps = int(argument.trim_prefix("--shot-dig="))
			ground_test = true
		elif argument == "--shot-nograss":
			no_grass = true      # hide the grass so a hand-held item or the body is not hidden by blades
		elif argument == "--shot-admin":
			admin_text = true      # keep the HUD and show the F3 debug lines in the pictures (look rig, tools/look_rig.sh)
			client.debug_hud.enabled = true
		elif argument.begins_with("--shot-wait="):
			wait_s = float(argument.trim_prefix("--shot-wait="))
		elif argument.begins_with("--shot-settle="):
			settle_s = float(argument.trim_prefix("--shot-settle="))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))


func _process(_delta: float) -> void:
	if client == null or client.body == null or client.connected_msec == 0:
		return

	# Hold the hour and weather every frame, whatever the server says.
	if _index >= 0 and _index < shots.size():
		var seconds: float = floorf(client.game_clock.seconds / 86400.0) * 86400.0 + _hour * 3600.0
		client.game_clock.seconds = seconds
		client.game_clock._sync_msec = -1

		match _weather:
			"storm": client.weather = STORM.duplicate()
			"rain": client.weather = RAIN.duplicate()
			"snow": client.weather = SNOW.duplicate()
			"clear": client.weather = CLEAR.duplicate()

		client.body.velocity = Vector3.ZERO

		if no_grass and client.grass != null and client.grass.enabled:
			client.grass.set_radius(0.0)      # the grass view draws nothing (a quality change may turn it back on)

		if client.held != null:
			client.held.set_first_person(false)

		if client._avatar != null and float(shots[_index]["walk"]) < 0.0:
			client._avatar.visible = false

	var now: int = Time.get_ticks_msec()

	if give_item != "" and not _given and now - client.connected_msec > 8000:
		_given = true
		client.items.net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, client.items.table.number_of(give_item), 0, give_count, Vector3.ZERO)

	if give_item != "" and _given and not _selected and now - client.connected_msec > 10000 and client.held != null:
		_selected = true
		client.held.select(0)      # slot 0 = key 1: hold what was given

	if drop_it and _given and not _dropped and _placed and now - _moved_msec > 3000:      # only once the player stands on the real ground (a drop before that fell from the spawn height)
		_dropped = true
		_drop_msec = now
		var bp: Vector3 = client.body.global_position
		var gy: float = _ground(bp.x, bp.z - drop_dist_m)
		var at: Vector3 = Vector3(bp.x, bp.y - 1.0 if is_nan(gy) else gy, bp.z - drop_dist_m)
		client.items.net.inventory_action.rpc_id(1, Net.ACT_DROP, 0, 0, give_count, at)

	# Dig rig: a heavy pack (so the yield spills onto the ground, as in play), then the dig-and-step loop.
	if dig_steps > 0 and heavy and not _dig_ballast and now - client.connected_msec > 9000:
		_dig_ballast = true
		client.items.net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, client.items.table.number_of("stone"), 0, 400, Vector3.ZERO)

	if _busy:
		return

	if _index == -1:
		if now - client.connected_msec < int(wait_s * 1000.0):
			return

		_next(now)
		return

	if _index >= shots.size():
		return

	var shot_pos: Vector3 = shots[_index]["pos"]
	_side_view(float(shots[_index]["walk"]))

	if not _placed:
		var ground: float = _ground(shot_pos.x, shot_pos.z)

		if is_nan(ground) and now - _ground_wait_msec < 300000:
			client.body.global_position = Vector3(shot_pos.x, 400.0, shot_pos.z)
			return

		_placed = true
		_moved_msec = now
		client.body.global_position = Vector3(shot_pos.x, -shot_pos.y if shot_pos.y < 0.0 else (shot_pos.y if is_nan(ground) else ground + shot_pos.y), shot_pos.z)
		return

	if now - _moved_msec < int(settle_s * 1000.0):
		return

	if dig_steps > 0 and now - client.connected_msec > 12000:
		if _dig_i < dig_steps:
			if now >= _dig_next_msec:
				# The spade reaches 3 m: as the hole deepens the ray runs out, so a player looks steeper (a real player would too).
				var eye: Vector3 = client.camera.global_position
				var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, eye - client.camera.global_transform.basis.z * 3.0)
				query.exclude = [client.body.get_rid()]
				var hit: Dictionary = client.camera.get_world_3d().direct_space_state.intersect_ray(query)

				if hit.is_empty() and client.pitch > deg_to_rad(-88.0):
					client.pitch = maxf(client.pitch - deg_to_rad(6.0), deg_to_rad(-88.0))
					client.camera.rotation.x = client.pitch
					print("shot runner: dig %d: nothing in reach, looking steeper (pitch %.0f)" % [_dig_i, rad_to_deg(client.pitch)])
					_dig_next_msec = now + 300
					return

				print("shot runner: dig %d: pitch %.0f, ray hit %s" % [_dig_i, rad_to_deg(client.pitch), str(hit["position"]) if not hit.is_empty() else "none"])
				client.held._dig_here()
				_dig_i += 1
				_dig_next_msec = now + 900

			return

		if not _dig_dropped:
			# Dirt on the ground by a real drop: a stack of what the digs gave goes on the ground 1.2 m ahead, beside the hole (Dave 2026-10-23).
			_dig_dropped = true
			var inv = client.items.inventory
			var soil_slot: int = inv.numbers.find(client.items.table.number_of("soil"))
			var bp: Vector3 = client.body.global_position
			var ahead: Vector3 = -client.body.global_transform.basis.z
			var spot_x: float = bp.x + ahead.x * 1.2
			var spot_z: float = bp.z + ahead.z * 1.2
			var spot_ground: float = _ground(spot_x, spot_z)

			if soil_slot >= 0:
				client.items.net.inventory_action.rpc_id(1, Net.ACT_DROP, soil_slot, 0, int(inv.counts[soil_slot]), Vector3(spot_x, bp.y - 1.0 if is_nan(spot_ground) else spot_ground, spot_z))
			else:
				print("shot runner: no soil in the pack to drop")

			_dig_next_msec = now + 3000
			return

		if not _dig_level:
			if now < _dig_next_msec:
				return

			_dig_level = true
			var back: Vector3 = client.body.global_transform.basis.z      # a very short step back (back_m), then look down at the hole and the dirt
			var back_x: float = client.body.global_position.x + back.x * back_m
			var back_z: float = client.body.global_position.z + back.z * back_m
			var back_ground: float = _ground(back_x, back_z)
			client.body.global_position = Vector3(back_x, client.body.global_position.y if is_nan(back_ground) else back_ground + shot_pos.y, back_z)
			client.pitch = deg_to_rad(look_down_deg)      # look down, then spin a full turn with a picture every quarter
			client.camera.rotation.x = client.pitch
			_spin_next_msec = now + 4000
			_moved_msec = now
			return

		if _spin_i < 4:
			if now >= _spin_next_msec:
				var spin_image: Image = get_viewport().get_texture().get_image()
				spin_image.save_png("%s/%s_spin%d.png" % [dir, shots[_index]["name"], _spin_i])
				print("shot runner: saved spin %d" % _spin_i)
				_spin_i += 1
				client.body.rotation.y -= PI * 0.5
				_spin_next_msec = now + 2500

			return

		if _spin_i == 4:
			_spin_i = 5
			client.pitch = deg_to_rad(look_down_deg)
			client.camera.rotation.x = client.pitch
			_moved_msec = now
			return

	# A drop or a seeded pile: a short step back, then look down at the spot (TEST_RECIPE.md), settle, then the picture.
	if ground_test and dig_steps == 0 and not _finish_done and now - client.connected_msec > 13000 and (not drop_it or (_dropped and now - _drop_msec > 3000)):
		_finish_done = true
		var behind: Vector3 = client.body.global_transform.basis.z
		var bx: float = client.body.global_position.x + behind.x * back_m
		var bz: float = client.body.global_position.z + behind.z * back_m
		var bg: float = _ground(bx, bz)
		client.body.global_position = Vector3(bx, client.body.global_position.y if is_nan(bg) else bg + shot_pos.y, bz)
		client.pitch = deg_to_rad(look_down_deg)
		client.camera.rotation.x = client.pitch
		_moved_msec = now
		return

	if not flora_names.is_empty() and _flora_t == 0:
		_show_flora(now)
		return

	if _flora_t != 0 and now - _flora_t < 6000:
		return

	_print_state()
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [dir, shots[_index]["name"]]
	image.save_png(path)
	var p: Vector3 = client.body.global_position
	if client.held != null and give_item != "":
		print("shot runner: held id %s holding %s model %s mounted %s" % [client.held.held_id(), str(client.held.holding), str(client.held._model != null), str(client.held._mounted)])
		var hm = client.held._model
		if hm != null:
			var aabb: AABB = AABB()
			for ch in hm.get_children():
				if ch is MeshInstance3D:
					aabb = (ch as MeshInstance3D).get_aabb()
			var mi: MeshInstance3D = hm as MeshInstance3D
			print("shot runner: held is MeshInstance3D %s mesh %s aabb %s scale %s" % [str(mi != null), str(mi.mesh) if mi != null else "-", str(mi.mesh.get_aabb().size) if mi != null and mi.mesh != null else "-", str(hm.scale)])
			var cam: Camera3D = client.camera
			print("shot runner: camera at %s forward %s, model offset from camera %s, dot with forward %.2f, view_cam at %s" % [str(cam.global_position), str(-cam.global_transform.basis.z), str(hm.global_position - cam.global_position), (hm.global_position - cam.global_position).dot(-cam.global_transform.basis.z), str(client.view_cam.global_position) if client.view_cam != null else "-"])
			print("shot runner: held model at %s visible %s in tree %s parent %s children %d first aabb %s; body at %s" % [str(hm.global_position), str(hm.visible), str(hm.is_visible_in_tree()), str(hm.get_parent().name), hm.get_child_count(), str(aabb.size), str(client.body.global_position)])

	print("shot runner: saved %s (%dx%d) at %s, ground %.1f" % [path, image.get_width(), image.get_height(), str(p), _ground(p.x, p.z)])
	var falls: Array = client.flora.fall_list()
	falls.sort_custom(func(a, b): return (a["base"] as Vector3).distance_to(p) < (b["base"] as Vector3).distance_to(p))

	for n in range(mini(falls.size(), 12)):
		var fall: Dictionary = falls[n]
		print("shot runner: fall %d top %s base %s flow %.1f width %.1f" % [n, str(fall["top"]), str(fall["base"]), float(fall["flow"]), float(fall["width"])])

	_cost_then_next(now)


# One line of facts so pass or fail is not by eye only: where the player is, what the pack holds, and every loose world item within 6 m
# with its height above the ground under it (a gap over 0.15 m is floating).
func _print_state() -> void:
	if client.items == null:
		return

	var p: Vector3 = client.body.global_position
	var rows: PackedStringArray = PackedStringArray()

	for id in client.items._world:
		var it: Dictionary = client.items._world[id]
		var at: Vector3 = it["pos"]

		if Vector2(at.x - p.x, at.z - p.z).length() > 6.0:
			continue

		var floor_y: float = _ground(at.x, at.z)
		var drawn_y: float = (it["node"] as Node3D).position.y - 0.12      # where the node is drawn (the client snaps loose items to the ground); loose nodes sit 0.12 above their point
		var phys_y: float = client._ground_below(at + Vector3(0.0, 0.5, 0.0))      # what the client snaps to (the collision ground)
		rows.append("%s x%d server y %.2f drawn y %.2f collision ground %.2f voxel ground %s gap %s dist %.1f" % [client.items.table.id_of(int(it["number"])), int(it["count"]), at.y, drawn_y, phys_y, "?" if is_nan(floor_y) else "%.2f" % floor_y, "?" if is_nan(floor_y) else "%.2f" % (drawn_y - floor_y), Vector2(at.x - p.x, at.z - p.z).length()])

	print("shot runner: state: expect \"%s\"; player %s pitch %.0f; %d loose items within 6 m: %s" % [expect, str(p), rad_to_deg(client.pitch), rows.size(), "; ".join(rows)])


# A labelled row of plants (look rig): one of each named species 4 m ahead of the player, drawn by the real flora view.
func _show_flora(now: int) -> void:
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))
	var by_name: Dictionary = {}

	for entry in table["entries"]:
		by_name[str(entry["name"])] = entry

	if summer:
		for species_id in client.flora._species:
			client.flora._species[species_id]["hardwood"] = false

	var p: Vector3 = client.body.global_position
	var items: Dictionary = {"ids": PackedInt32Array(), "positions": PackedVector3Array(), "heights": PackedFloat32Array(), "yaws": PackedFloat32Array()}
	var n: int = flora_names.size()

	for i in range(n):
		var entry: Dictionary = by_name.get(flora_names[i], {})

		if entry.is_empty():
			continue

		var x: float = p.x + (float(i) - float(n - 1) * 0.5) * 1.5
		var z: float = p.z - 2.4
		var g: float = _ground(x, z)

		if is_nan(g):
			g = p.y - 1.5

		var range_m: Variant = entry.get("height_m", 1.0)
		var h: float = (float(range_m[0]) + float(range_m[1])) * 0.5 if range_m is Array else float(range_m)
		items["ids"].append((int(entry["id"]) << 16) | (i + 1))   # species id << 16 | a number unique in the chunk (the flora view reads ids >> 16)
		items["positions"].append(Vector3(x, g, z))
		items["heights"].append(h)
		items["yaws"].append(0.0)
		var tag: Label3D = Label3D.new()
		tag.text = str(entry.get("display", flora_names[i]))
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.fixed_size = true
		tag.pixel_size = 0.0009
		tag.font_size = 40
		tag.outline_size = 10
		tag.no_depth_test = true
		tag.position = Vector3(x, g + h + 0.5, z)
		client.add_child(tag)

	var here: Vector2i = Vector2i(int(floor(p.x / client.flora.chunk_m)), int(floor((p.z - 2.4) / client.flora.chunk_m)))
	var empty: Dictionary = {"ids": PackedInt32Array(), "positions": PackedVector3Array(), "heights": PackedFloat32Array(), "yaws": PackedFloat32Array()}

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dz != 0:
				client.flora.set_chunk(here + Vector2i(dx, dz), empty.duplicate(true), p)

	client.flora.set_chunk(here, items, p)
	_flora_t = now


# A walking body from the side: the drawn camera 2.8 m to the body's left, level with its chest.
func _side_view(walk: float) -> void:
	client.debug_pace = walk

	if walk < 0.0 or client._avatar == null or client.view_cam == null:
		return

	client.third_person = true
	var origin: Vector3 = client._avatar.global_position + Vector3(0.0, 0.95, 0.0)
	var left: Vector3 = client.body.global_transform.basis * Vector3(-1.0, 0.0, 0.0)
	var aim: Vector3 = origin

	if side_dist < 2.0 and client.held != null and client.held._model != null:
		aim = client.held._model.global_position

	client.view_cam.global_position = aim + left * side_dist * side_sign + Vector3(0.0, 0.1, 0.0)
	client.view_cam.look_at(aim, Vector3.UP)


# What the frame draws, in the same units as the probe table (primitives include the shadow passes). With
# --shot-cost the runner also reads it with the sun's shadows off, the flora hidden, and both.
func _info(label: String) -> void:
	for i in range(3):
		await get_tree().process_frame

	var prims: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var calls: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	print("shot runner: cost %s: %d k primitives, %d draw calls, %d objects" % [label, prims / 1000, calls, objects])


func _cost_then_next(now: int) -> void:
	_busy = true
	await _info("normal")

	if costs:
		_tally(client.flora, client.camera.global_position)
		client._sun.shadow_enabled = false
		await _info("sun shadows off")
		client._sun.shadow_enabled = true
		client.flora.visible = false
		await _info("flora hidden")
		client.flora.visible = true

	_busy = false
	_next(Time.get_ticks_msec())


# Instances in range by triangles per instance and shadow casting (sorted by chunk-centre distance, so approximate).
func _tally(root: Node, eye: Vector3) -> void:
	var buckets: Dictionary = {}
	var top: Array = []
	var stack: Array = [root]

	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())

		if not (node is MultiMeshInstance3D) or not (node as Node3D).is_visible_in_tree():
			continue

		var mmi: MultiMeshInstance3D = node
		var mm: MultiMesh = mmi.multimesh

		if mm == null or mm.mesh == null or mmi.visibility_range_end <= 0.0 and false:
			continue

		var d: float = eye.distance_to(mmi.global_position + mmi.get_aabb().get_center())

		if mmi.visibility_range_end > 0.0 and d > mmi.visibility_range_end:
			continue

		var tris: int = 0

		for surface in range(mm.mesh.get_surface_count()):
			var arrays: Array = mm.mesh.surface_get_arrays(surface)
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += index.size() / 3 if index.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3

		var cls: String = ("tris/instance %5d+" % (1000 if tris >= 1000 else (200 if tris >= 200 else (30 if tris >= 30 else 0)))) + (" casts" if mmi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else " no-shadow") + (" kind%d" % int(mmi.get_meta("kind", -1)))
		buckets[cls] = buckets.get(cls, 0) + tris * mm.instance_count
		top.append([tris * mm.instance_count, "%s x%d at %d m, %d tris each, range %d, %s" % [mmi.get_parent().name, mm.instance_count, int(d), tris, int(mmi.visibility_range_end), "casts" if mmi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else "no-shadow"]])

	var keys: Array = buckets.keys()
	keys.sort()

	top.sort_custom(func(a, b): return a[0] > b[0])

	for n in range(mini(top.size(), 14)):
		print("shot runner: biggest %d k: %s" % [int(top[n][0]) / 1000, top[n][1]])

	for key in keys:
		print("shot runner: tally %s: %d k triangles in range (before shadow passes)" % [key, int(buckets[key]) / 1000])


# The ground height under x, z from the voxel data (no collision needed), NAN while it is not loaded.
func _ground(x: float, z: float) -> float:
	var tool = client.terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_SDF
	var hit = tool.raycast(Vector3(x, 1500.0, z), Vector3.DOWN, 2000.0)
	return float(hit.position.y) if hit != null else NAN


func _next(now: int) -> void:
	_index += 1

	if _index >= shots.size():
		print("shot runner: done")
		get_tree().quit()
		return

	var shot: Dictionary = shots[_index]
	client.flying = true
	_placed = false
	_ground_wait_msec = now
	client.body.global_position = Vector3(shot["pos"].x, 400.0, shot["pos"].z)
	client.body.rotation = Vector3(0.0, deg_to_rad(float(shot["yaw"])), 0.0)
	client.pitch = deg_to_rad(float(shot["pitch"]))
	client.camera.rotation.x = client.pitch
	client.third_person = false
	_hour = float(shot["hour"])
	_weather = str(shot["weather"])
	_moved_msec = now

	if client.hud != null and not admin_text:
		client.hud.visible = false

	if client.compass != null:
		client.compass.visible = false

	if client.held != null and client.held._arms != null:
		client.held._arms.visible = false

	if client._avatar != null:
		client._avatar.visible = false

	for child in client.get_children():
		if child is CanvasLayer and not (admin_text and client.hud != null and child == client.hud.get_parent()):
			child.visible = false

	if client.hotbar_strip != null and client.hotbar_strip.has_method("hide"):
		client.hotbar_strip.hide()
