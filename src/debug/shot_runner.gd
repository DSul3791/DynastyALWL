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
#   --shot-item=ITEM    a picture set of one item lying on the ground (id or name): give, drop, hide the player, HUD, grass and flora, then four views (front, side, top,
#                       diag) 0.2 to 1.5 m away aimed at it, each logged with the pose read back and the fill of the frame (FAILED under a third, exit code 1);
#                       --shot-item-at=X,Z drops it there instead of 1 m ahead of the shot position (item_cam.gd)
#   --shot-nograss      hide the grass; --shot-right puts the third-person camera on the body's right (look rig)
#
# yaw 0 faces -Z (north), 90 faces -X, -90 faces +X (Godot rotation about Y). Quits after the last shot.

const Net := preload("res://src/stream/terrain_net.gd")
const ItemCam := preload("res://src/debug/item_cam.gd")

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
var item_mode: bool = false        # --shot-item (see the header)
var item_at: Vector2 = Vector2(INF, INF)
var _item_built: bool = false
var _item_spot: Vector3 = Vector3.ZERO
var _item_failed: bool = false
var _item_box: AABB = AABB()
var _item_node: Node3D = null
var _item_views: Array = []
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
var _dig_pitch0: float = 0.0
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
var frametime_s: float = 0.0             # --shot-frametime=SECONDS: after a 10 s warm-up, measure frame times this long and print one "shot runner: frametime" line
var quality_set: int = -1                # --shot-quality=0..3 (0 = Low): set before the measurement
var _frame_times: PackedFloat32Array = PackedFloat32Array()
var _frame_state: int = 0                # 0 waiting, 1 measuring, 2 printed
var _frame_start_msec: int = 0
var build_label: String = ""             # --shot-build=: the commit the numbers belong to (printed in the frametime line)
var piece_names: PackedStringArray = PackedStringArray()    # --shot-pieces=wall_section,chest: one building piece of each in a row with name tags (structures.json keys)
var pieces_yaw_deg: float = 0.0    # --shot-pieces-yaw=N: the whole row turned N degrees
var _pieces_t: int = 0
var showroom_rows: PackedStringArray = PackedStringArray()   # --shot-showroom=all or row labels: one picture per admin showroom row (data/items/showroom.json)
var showroom_cam_height: float = -1.0    # --shot-showroom-height=M: the --showroom camera stands M m above the ground (default 1.6 + 0.25 x row length)
var showroom_look_down: float = 999.0    # --shot-showroom-look=DEG: its pitch (e.g. -35); default aims at the row from the height and distance
var showroom_spread: bool = false        # --shot-showroom-spread: name tags staggered in three heights, so neighbours do not overlap
var _showroom_t: int = 0
var _showroom_rows_chosen: Array = []
var _showroom_tagged: bool = false
var _showroom_tags: Array = []           # the Label3D name tags of the chosen rows (for the overlap count)
var flora_scale: float = 1.0       # --shot-flora-scale=N: draw the row N times its natural size (a check that a small plant is only hard to see)
var cam_above_m: float = -1.0       # --shot-cam-above=M: the camera stands M metres above the ground at the plant row (--flora); -1 keeps the --agl height
var views: Array = []                # --shot-views="name:dist:pitch:above;...": extra pictures of the same scene (see _parse_views)
var _view_i: int = 0
var _view_msec: int = 0              # when the current view was set up; 0 = not set up yet
var _subject: Vector3 = Vector3.ZERO # what the views look at: the middle of the --flora row, else 4 m ahead of the player
var _subject_set: bool = false
var flora_lift_m: float = 0.12     # --shot-flora: the row stands this far above the raycast ground (the drawn smooth ground can lie a little higher and hide a 0.2 m flower)
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
		elif argument.begins_with("--shot-frametime="):
			frametime_s = float(argument.trim_prefix("--shot-frametime="))
		elif argument.begins_with("--shot-build="):
			build_label = argument.trim_prefix("--shot-build=")
		elif argument.begins_with("--shot-quality="):
			quality_set = clampi(int(argument.trim_prefix("--shot-quality=")), 0, 3)
		elif argument.begins_with("--shot-views="):
			views = _parse_views(argument.trim_prefix("--shot-views="))
		elif argument.begins_with("--shot-flora-scale="):
			flora_scale = float(argument.trim_prefix("--shot-flora-scale="))
		elif argument.begins_with("--shot-cam-above="):
			cam_above_m = float(argument.trim_prefix("--shot-cam-above="))
		elif argument.begins_with("--shot-showroom-height="):
			showroom_cam_height = float(argument.trim_prefix("--shot-showroom-height="))
		elif argument.begins_with("--shot-showroom-look="):
			showroom_look_down = float(argument.trim_prefix("--shot-showroom-look="))
		elif argument == "--shot-showroom-spread":
			showroom_spread = true
		elif argument.begins_with("--shot-showroom="):
			showroom_rows = argument.trim_prefix("--shot-showroom=").split(",", false)
			no_grass = true
		elif argument.begins_with("--shot-pieces-yaw="):
			pieces_yaw_deg = float(argument.trim_prefix("--shot-pieces-yaw="))
		elif argument.begins_with("--shot-pieces="):
			piece_names = argument.trim_prefix("--shot-pieces=").split(",", false)
			no_grass = true

			if views.is_empty():
				views = [{"name": "wide", "dist": 9.0, "pitch": -8.0, "above": 1.5}, {"name": "close", "dist": 4.0, "pitch": -10.0, "above": 1.2}]
		elif argument.begins_with("--shot-flora="):
			flora_names = argument.trim_prefix("--shot-flora=").split(",", false)
		elif argument == "--shot-summer":
			summer = true
		elif argument.begins_with("--shot-give="):
			give_item = argument.trim_prefix("--shot-give=")

			if give_item.contains(":"):
				give_count = int(give_item.get_slice(":", 1))
				give_item = give_item.get_slice(":", 0)
		elif argument.begins_with("--shot-item-at="):
			var xz: PackedStringArray = argument.trim_prefix("--shot-item-at=").split(",")
			item_at = Vector2(float(xz[0]), float(xz[1]))
		elif argument.begins_with("--shot-item="):
			item_mode = true
			give_item = argument.trim_prefix("--shot-item=")
			give_count = 1
			drop_it = true
			no_grass = true
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


func _process(delta: float) -> void:
	if client == null or client.body == null or client.connected_msec == 0:
		return

	if frametime_s > 0.0 and _frame_state < 2:
		_measure_frames(delta)

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

		if item_at.is_finite():
			var ig: float = _ground(item_at.x, item_at.y)
			at = Vector3(item_at.x, bp.y - 1.0 if is_nan(ig) else ig, item_at.y)

		_item_spot = at
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

	# A join still waiting for collision under the player (a slow stream: Mike's log, 46+ s) is waited for, up to 120 s after the welcome, before any shot is placed.
	if client.waiting_for_ground and client.connected_msec > 0 and now - client.connected_msec < 120000:
		return

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

				if _dig_i == 0 and _dig_pitch0 == 0.0:
					_dig_pitch0 = client.pitch

				if hit.is_empty() and client.pitch <= deg_to_rad(-88.0) + 0.001:
					# The hole is deeper than the spade reaches from here: one short step on to fresh ground (the 20 digs go on), looking as at the start.
					var fwd: Vector3 = -client.body.global_transform.basis.z
					var fx: float = client.body.global_position.x + fwd.x * 0.9
					var fz: float = client.body.global_position.z + fwd.z * 0.9
					var fg: float = _ground(fx, fz)
					client.body.global_position = Vector3(fx, client.body.global_position.y if is_nan(fg) else fg + shot_pos.y, fz)
					client.pitch = _dig_pitch0
					client.camera.rotation.x = client.pitch
					print("shot runner: dig %d: hole out of reach, stepped 0.9 m on (pitch %.0f)" % [_dig_i, rad_to_deg(client.pitch)])
					_dig_next_msec = now + 1500
					return

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

	if item_mode:
		client.flora.visible = false

		if not _item_built:
			if _dropped and now - _drop_msec > 3000:
				_build_item_views(now)

			return

	if not flora_names.is_empty() and _flora_t == 0:
		_show_flora(now)
		return

	if not showroom_rows.is_empty() and _showroom_t == 0:
		_show_showroom(now)
		return

	if _showroom_t != 0 and now - _showroom_t < 9000:
		return

	if _showroom_t != 0 and not _showroom_tagged:
		_showroom_tagged = true
		_tag_showroom()
		return

	if not piece_names.is_empty() and _pieces_t == 0:
		_show_pieces(now)
		return

	if (_flora_t != 0 and now - _flora_t < 6000) or (_pieces_t != 0 and now - _pieces_t < 4000):
		return

	if _view_i < views.size():
		_run_view(now)
		return

	_print_state()

	if not flora_names.is_empty():
		_print_flora_row()

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
		items["positions"].append(Vector3(x, g + flora_lift_m, z))
		items["heights"].append(h * flora_scale)
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

	client.flora.keep_all = true
	print("shot runner: flora row: cleared spots %d, lying logs %d, species known %d" % [client.flora.cleared.size(), client.flora.trunks.size(), client.flora._species.size()])
	var here: Vector2i = Vector2i(int(floor(p.x / client.flora.chunk_m)), int(floor((p.z - 2.4) / client.flora.chunk_m)))
	var empty: Dictionary = {"ids": PackedInt32Array(), "positions": PackedVector3Array(), "heights": PackedFloat32Array(), "yaws": PackedFloat32Array()}

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dz != 0:
				client.flora.set_chunk(here + Vector2i(dx, dz), empty.duplicate(true), p)

			client.rig_flora_hold[here + Vector2i(dx, dz)] = true

	client.flora.set_chunk(here, items, p)
	_flora_t = now

	if not items["positions"].is_empty():
		var spots: PackedVector3Array = items["positions"]
		var middle: Vector3 = Vector3.ZERO

		for spot in spots:
			middle += spot

		_subject = middle / float(spots.size())
		_subject_set = true

	if cam_above_m >= 0.0 and not items["positions"].is_empty():
		var subject: Vector3 = items["positions"][0]
		client.body.global_position.y = subject.y - flora_lift_m + cam_above_m - client.camera.position.y


# A labelled row of building pieces (look rig --pieces): one of each named structure (data/items/structures.json key) 4 m ahead of the player, built by the
# game's own ghost_model (the builder a placed piece and the placement ghost use), spaced by their size, each with a name tag. One "shot runner: piece"
# line per piece is the pass/fail source: a piece that draws nothing says FAIL. Unknown names were already refused by tools/look_rig.sh.
func _show_pieces(now: int) -> void:
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))
	var defs: Dictionary = table.get("structures", {}) if typeof(table) == TYPE_DICTIONARY else {}
	var models: Array = []
	var p: Vector3 = client.body.global_position

	for piece_name in piece_names:
		var def: Dictionary = defs.get(piece_name, {})

		if def.is_empty():
			print("shot runner: piece %s FAIL not in structures.json" % piece_name)
			continue

		if bool(def.get("planned", false)):
			print("shot runner: piece %s skipped: planned, not built yet" % piece_name)
			continue

		var model: Node3D = client.items.ghost_model(int(def["state"]))

		if model == null:
			print("shot runner: piece %s FAIL no model for state %d" % [piece_name, int(def["state"])])
			continue

		client.add_child(model)
		model.rotation.y = deg_to_rad(pieces_yaw_deg)
		models.append([str(piece_name), def, model])

	var widths: Array = []
	var total: float = 0.0

	for entry in models:
		var box: AABB = _aabb_of(entry[2])
		var width: float = maxf(box.size.x, box.size.z) if box.size != Vector3.ZERO else 1.0
		widths.append(width)
		total += width + 1.0

	var x: float = p.x - (total - 1.0) * 0.5
	var z: float = p.z - 4.0
	var subject_y: float = p.y - 1.5

	for n in range(models.size()):
		var model: Node3D = models[n][2]
		x += float(widths[n]) * 0.5
		var g: float = _ground(x, z)

		if is_nan(g):
			g = p.y - 1.5

		model.global_position = Vector3(x, g, z)
		var box: AABB = _aabb_of(model)
		var height: float = box.size.y
		var tag: Label3D = Label3D.new()
		tag.text = str(models[n][0])
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.fixed_size = true
		tag.pixel_size = 0.0009
		tag.font_size = 40
		tag.outline_size = 10
		tag.no_depth_test = true
		tag.position = Vector3(x, g + maxf(height, 0.4) + 0.5, z)
		client.add_child(tag)
		print("shot runner: piece %s %s state %d look %s size %.2f x %.2f x %.2f at %s" % [models[n][0], "FAIL empty" if box.size == Vector3.ZERO else "ok", int(models[n][1]["state"]), str(models[n][1].get("look", "")), box.size.x, box.size.y, box.size.z, str(model.global_position)])
		x += float(widths[n]) * 0.5 + 1.0
		subject_y = g

	_subject = Vector3(p.x, subject_y, z)
	_subject_set = true
	_pieces_t = now


# --showroom: turn Admin mode on so the server lays the showroom rows out as real world items, then one view per chosen row from the west side
# (the rows run north to south, start/step in metres east and south of the spawn point), looking east. _tag_showroom then puts a name tag over each
# item and prints one "shot runner: showroom row" line per row: how many of its items were found where they belong (world_item_name_near).
func _show_showroom(now: int) -> void:
	if client.showroom == null:
		return    # the client has not read the world's spawn yet: try again next frame

	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/showroom.json"))
	var rows: Array = table.get("rows", []) if typeof(table) == TYPE_DICTIONARY else []
	var origin: Vector3 = client.showroom.origin
	var chosen: Array = []

	for row in rows:
		var label: String = str(row.get("label", ""))
		var take: bool = showroom_rows.has("all")

		for want in showroom_rows:
			if label.to_lower().contains(want.to_lower()):
				take = true

		if take:
			chosen.append(row)

	if chosen.is_empty():
		var labels: PackedStringArray = PackedStringArray()

		for row in rows:
			labels.append(str(row.get("label", "")))

		print("shot runner: --showroom error: no row matches %s; rows: %s" % [str(showroom_rows), ", ".join(labels)])
		(Engine.get_main_loop() as SceneTree).quit(2)
		return

	client.items.admin_craft = true
	client.net.inventory_action.rpc_id(1, Net.ACT_ADMIN_MODE, 1, 0, 0, Vector3.ZERO)
	views = []

	for row in chosen:
		var start: Array = row.get("start", [0, 0])
		var step: Array = row.get("step", [0, 1.5])
		var items: Array = row.get("items", [])
		var length: float = Vector2(float(step[0]), float(step[1])).length() * float(maxi(items.size() - 1, 1))
		var mid_x: float = origin.x + float(start[0]) + float(step[0]) * float(items.size() - 1) * 0.5
		var mid_z: float = origin.z + float(start[1]) + float(step[1]) * float(items.size() - 1) * 0.5
		var dist: float = 3.0 + length * 0.9
		var above: float = showroom_cam_height if showroom_cam_height > 0.0 else 1.6 + length * 0.25
		var view_name: String = str(row.get("label", "row")).to_lower().replace(" ", "_").replace(":", "")
		views.append({"name": view_name, "dist": dist, "pitch": showroom_look_down if showroom_look_down <= 90.0 else -rad_to_deg(atan2(above, dist)) + 3.0, "above": above, "cam_x": mid_x - dist, "cam_z": mid_z, "yaw": -90.0})
		_showroom_rows_chosen.append(row)

	_showroom_t = now


# How many pairs of name tags overlap on screen from the current camera (an estimate: a tag is about 0.45 x font size wide per letter, one font size
# high, drawn at fixed screen size). OVERLAP n = tags in the way of each other: raise --showroom-spread or the camera.
func _tag_overlaps() -> String:
	var boxes: Array = []
	var cam: Camera3D = client.camera

	for tag in _showroom_tags:
		var label: Label3D = tag
		var world: Vector3 = label.global_position

		if cam.is_position_behind(world):
			continue

		var at: Vector2 = cam.unproject_position(world)
		var size: Vector2 = Vector2(float(label.text.length()) * float(label.font_size) * 0.45, float(label.font_size))
		boxes.append(Rect2(at - size * 0.5, size))

	var pairs: int = 0

	for a in range(boxes.size()):
		for b in range(a + 1, boxes.size()):
			if (boxes[a] as Rect2).intersects(boxes[b]):
				pairs += 1

	return "%s (%d tags, %d overlapping pairs)" % ["ok" if pairs == 0 else "OVERLAP", boxes.size(), pairs]


func _tag_showroom() -> void:
	var origin: Vector3 = client.showroom.origin

	for row in _showroom_rows_chosen:
		var start: Array = row.get("start", [0, 0])
		var step: Array = row.get("step", [0, 1.5])
		var items: Array = row.get("items", [])
		var found: int = 0

		for n in range(items.size()):
			var x: float = origin.x + float(start[0]) + float(step[0]) * float(n)
			var z: float = origin.z + float(start[1]) + float(step[1]) * float(n)
			var g: float = _ground(x, z)

			if is_nan(g):
				g = origin.y

			if client.items.world_item_name_near(Vector3(x, g + 0.2, z), 0.9) != "":
				found += 1

			var tag: Label3D = Label3D.new()
			tag.text = str(items[n][0])
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.fixed_size = true
			tag.pixel_size = 0.0007
			tag.font_size = 36
			tag.outline_size = 10
			tag.no_depth_test = true
			tag.position = Vector3(x, g + 0.9 + (float(n % 3) * 0.45 if showroom_spread else 0.0), z)
			client.add_child(tag)
			_showroom_tags.append(tag)

		print("shot runner: showroom row %s %s items %d found %d" % [str(row.get("label", "")), "ok" if found == items.size() else "FAIL missing", items.size(), found])


# The box round every mesh under `node`, in world space (an empty AABB when nothing draws).
func _aabb_of(node: Node) -> AABB:
	var box: AABB = AABB()
	var found: bool = false
	var stack: Array = [node]

	while not stack.is_empty():
		var current: Node = stack.pop_back()

		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var world: AABB = (current as MeshInstance3D).global_transform * (current as MeshInstance3D).get_aabb()
			box = world if not found else box.merge(world)
			found = true

		stack.append_array(current.get_children())

	return box


# --shot-views="name:dist:pitch:above;name2:...": extra pictures of the placed scene from other cameras, all in one start. dist = metres from the
# subject (south of it, looking north), pitch = degrees, above = camera metres above the ground there. Names must be unique: the frames are
# <shot name>_<view name>.png. Anything wrong in the text stops the run with a clear line (exit code 2).
func _parse_views(text: String) -> Array:
	var list: Array = []
	var seen: Dictionary = {}

	for part in text.split(";", false):
		var pieces: PackedStringArray = part.split(":", false)
		var problem: String = ""

		if pieces.size() != 4:
			problem = "'%s' needs 4 parts name:dist:pitch:above" % part
		elif seen.has(pieces[0]):
			problem = "name '%s' is used twice" % pieces[0]
		elif not (pieces[1].is_valid_float() and pieces[2].is_valid_float() and pieces[3].is_valid_float()):
			problem = "'%s' dist, pitch and above must be numbers" % part
		elif float(pieces[1]) < 0.0 or float(pieces[3]) < 0.0:
			problem = "'%s' dist and above cannot be negative" % part

		if problem != "":
			print("shot runner: --views error: %s" % problem)
			(Engine.get_main_loop() as SceneTree).quit(2)
			return []

		seen[pieces[0]] = true
		list.append({"name": pieces[0], "dist": float(pieces[1]), "pitch": float(pieces[2]), "above": float(pieces[3])})

	return list


# --shot-item: finds the dropped item, measures it and makes the four views (the normal view loop then takes the pictures). Gives up (FAILED) after 25 s.
func _build_item_views(now: int) -> void:
	var best: Dictionary = {}
	var best_d: float = INF

	for id in client.items._world:
		var it: Dictionary = client.items._world[id]

		if client.items.table.id_of(int(it["number"])) != client.items.table.id_of(client.items.table.number_of(give_item)):
			continue

		var d: float = (it["pos"] as Vector3).distance_to(_item_spot)

		if d < best_d and it.get("node") != null:
			best = it
			best_d = d

	if best.is_empty() or best_d > 3.0:
		if now - _drop_msec > 25000:
			_item_failed = true
			_item_built = true
			print("shot runner: FAILED no ground at this spot: item %s never showed up on the ground near %s (water, or the ground there is not loaded)" % [give_item, str(_item_spot)])

		return

	_item_node = best["node"]
	_item_box = _node_aabb(_item_node)

	if _item_box.size == Vector3.ZERO:
		_item_box = AABB((best["pos"] as Vector3) - Vector3(0.1, 0.0, 0.1), Vector3(0.2, 0.2, 0.2))

	var centre: Vector3 = _item_box.get_center()
	var ground: float = _ground(centre.x, centre.z)
	var size: Vector2 = get_viewport().get_visible_rect().size
	views = ItemCam.views(_item_box, client.camera.fov, _item_box.position.y if is_nan(ground) else ground, size.x / maxf(size.y, 1.0))
	_item_views = views
	_subject = centre
	_subject_set = true
	_item_built = true
	print("shot runner: item %s at %s, box %s, %d views" % [give_item, str(centre), str(_item_box.size), views.size()])


# The item may still have been settling when its box was first measured (it tumbles or snaps to the ground): each view measures the box again just before it is
# set up and aims at where the item really is now.
func _remake_item_view(view: Dictionary) -> Dictionary:
	_item_box = _node_aabb(_item_node)
	var centre: Vector3 = _item_box.get_center()
	var ground: float = _ground(centre.x, centre.z)
	var size: Vector2 = get_viewport().get_visible_rect().size
	var fresh: Array = ItemCam.views(_item_box, client.camera.fov, _item_box.position.y if is_nan(ground) else ground, size.x / maxf(size.y, 1.0))

	for v in fresh:
		if v["name"] == view["name"]:
			views[_view_i] = v
			return v

	return view


func _node_aabb(node: Node) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	var stack: Array = [node]

	while not stack.is_empty():
		var n: Node = stack.pop_back()

		if n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree():
			var part: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
			box = part if first else box.merge(part)
			first = false

		stack.append_array(n.get_children())

	return box


# The pose the camera really has against the one asked for, and how much of the frame the item fills (a third at least). A miss marks the run failed.
func _check_item_view(view: Dictionary) -> void:
	var cam: Camera3D = client.camera
	var forward: Vector3 = -cam.global_transform.basis.z
	var want_pos: Vector3 = view["cam"]
	var pos_err: float = cam.global_position.distance_to(want_pos)
	var yaw_err: float = absf(wrapf(rad_to_deg(atan2(-forward.x, -forward.z)) - float(view["yaw"]), -180.0, 180.0)) if absf(float(view["pitch"])) < 80.0 else 0.0
	var pitch_err: float = absf(rad_to_deg(asin(clampf(forward.y, -1.0, 1.0))) - float(view["pitch"]))
	var size: Vector2 = get_viewport().get_visible_rect().size
	if _item_node != null and is_instance_valid(_item_node):
		_item_box = _node_aabb(_item_node)      # where the item is now, not where it was when the view was set up

	var stats: Dictionary = ItemCam.frame_stats(_item_box, cam.global_position, forward, cam.global_transform.basis.y, cam.fov, size.x / maxf(size.y, 1.0))
	var fill: float = stats["fill"]
	var off: float = stats["off"]
	var inside: bool = stats["inside"]
	var ok: bool = pos_err <= 0.1 and yaw_err <= 2.0 and pitch_err <= 2.0 and fill >= 0.32 and off <= 0.1 and inside

	if not ok:
		_item_failed = true

	print("shot runner: item view %s %s: pose off by %.2f m, yaw %.1f, pitch %.1f degrees; item fills %.0f %% of the frame, centre %.0f %% off, %s" % [view["name"], "ok" if ok else "FAILED", pos_err, yaw_err, pitch_err, fill * 100.0, off * 100.0, "all inside the frame" if inside else "PART OUTSIDE THE FRAME"])


# One view per call: set the camera, let it settle 2 s, save the frame, go on to the next; the normal picture follows the last view.
func _run_view(now: int) -> void:
	var view: Dictionary = views[_view_i]

	if _view_msec == 0 and item_mode and _item_node != null and is_instance_valid(_item_node):
		view = _remake_item_view(view)

	if _view_msec == 0:
		if not _subject_set:
			var p: Vector3 = client.body.global_position
			_subject = Vector3(p.x, _ground(p.x, p.z - 4.0), p.z - 4.0)
			_subject_set = true

		var cam_x: float = float(view["cam_x"]) if view.has("cam_x") else _subject.x
		var cam_z: float = float(view["cam_z"]) if view.has("cam_z") else _subject.z + float(view["dist"])
		var ground: float = _ground(cam_x, cam_z)
		client.body.rotation.y = deg_to_rad(float(view.get("yaw", 0.0)))
		client.body.global_position = Vector3(cam_x, (_subject.y if is_nan(ground) else ground) + float(view["above"]) - client.camera.position.y, cam_z)
		client.pitch = deg_to_rad(float(view["pitch"]))
		client.camera.rotation.x = client.pitch
		_view_msec = now
		return

	if now - _view_msec < 2000:
		return

	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%s.png" % [dir, shots[_index]["name"], view["name"]]
	image.save_png(path)

	if not flora_names.is_empty():
		_print_flora_row()   # the drawn pieces and vertex counts at this distance (near, mid, far models)

	if not _showroom_tags.is_empty():
		print("shot runner: tag overlap view %s %s" % [view["name"], _tag_overlaps()])

	if item_mode:
		_check_item_view(view)

	print("shot runner: view %s saved %s build %d dist %.1f pitch %.0f above %.2f camera %s subject %s" % [view["name"], path, client.BUILD, float(view["dist"]), float(view["pitch"]), float(view["above"]), str(client.camera.global_position), str(_subject)])
	_view_i += 1
	_view_msec = 0


# Look rig diagnostics for --shot-flora: what the flora view holds for the row's chunk (level bits, drawn pieces and instances), per chunk.
func _print_flora_row() -> void:
	var p: Vector3 = _subject if _subject_set else client.body.global_position - Vector3(0.0, 0.0, 2.4)   # the row's own spot: the camera of a --views picture may stand far off
	var here: Vector2i = Vector2i(int(floor(p.x / client.flora.chunk_m)), int(floor(p.z / client.flora.chunk_m)))
	var entry: Dictionary = client.flora._chunks.get(here, {})

	if entry.is_empty():
		print("shot runner: flora row: chunk %s is not held" % str(here))
		return

	var node: Node3D = entry.get("node")
	var pieces: int = 0
	var instances: int = 0

	if node != null:
		for child in node.get_children():
			if child is MultiMeshInstance3D:
				pieces += 1
				var mmi: MultiMeshInstance3D = child as MultiMeshInstance3D
				instances += mmi.multimesh.instance_count
				var mesh: Mesh = mmi.multimesh.mesh
				var verts: int = 0

				for surface in range(mesh.get_surface_count()):
					verts += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

				var first: Transform3D = mmi.multimesh.get_instance_transform(0)
				var cam: Vector3 = client.camera.global_position
				print("shot runner: flora piece: %s tier %s kind %s verts %d aabb %s instance0 at %s scale %s camera %s in tree %s range_end %.0f" % [str(mmi.get_meta("species", "")), str(mmi.get_meta("tier", -1)), str(mmi.get_meta("kind", -1)), verts, str(mesh.get_aabb()), str(first.origin), str(first.basis.get_scale()), str(cam), str(mmi.is_visible_in_tree()), mmi.visibility_range_end])

	print("shot runner: flora row: chunk %s items %d level %d ground %s visible %s pieces %d instances %d setup_done %s" % [str(here), (entry["items"]["ids"] as PackedInt32Array).size(), int(entry["level"]), str(entry.get("ground")), ("no node" if node == null else str(node.visible)), pieces, instances, str(client.flora._setup_done)])


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


# --shot-frametime: set the quality, wait 10 s after connecting (the first frames build the world), then collect every frame time for frametime_s seconds
# and print the average, the 95th percentile and the worst frame in ms (the always-playable check: Low should stay under 33 ms).
func _measure_frames(delta: float) -> void:
	var now: int = Time.get_ticks_msec()

	if _frame_state == 0:
		if now - client.connected_msec < 10000:
			return

		if quality_set >= 0 and client.quality != quality_set:
			client.quality = quality_set
			client._apply_quality()

		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)   # vsync snaps frame times to 16.7 ms steps
		_frame_state = 1
		_frame_start_msec = now

	_frame_times.append(delta * 1000.0)

	if now - _frame_start_msec >= int(frametime_s * 1000.0):
		_frame_state = 2
		var sorted: PackedFloat32Array = _frame_times.duplicate()
		sorted.sort()
		var total: float = 0.0
		var over_50: int = 0
		var over_100: int = 0

		for value in sorted:
			total += value
			over_50 += 1 if value > 50.0 else 0
			over_100 += 1 if value > 100.0 else 0

		var p95: float = sorted[int(float(sorted.size()) * 0.95)]
		var p99: float = sorted[int(float(sorted.size()) * 0.99)]
		var verdict: String = "FAIL" if (p95 >= 33.0 or over_100 > 0) else ("WARN p99 over 50 ms" if p99 > 50.0 else "OK")
		var spot: Vector3 = client.body.global_position
		print("shot runner: frametime build %s quality %s spot %.0f,%.0f frames %d avg %.1f p95 %.1f p99 %.1f max %.1f ms over50 %d over100 %d [%s] machine: %s, %s, window %dx%d, vsync off" % [
			build_label, client.QUALITY_NAMES[client.quality], spot.x, spot.z, sorted.size(), total / float(sorted.size()), p95, p99, sorted[sorted.size() - 1], over_50, over_100, verdict,
			RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name(), get_window().size.x, get_window().size.y])


func _next(now: int) -> void:
	_index += 1

	if _index >= shots.size():
		print("shot runner: done%s" % (" (item pictures FAILED)" if _item_failed else ""))
		get_tree().quit(1 if _item_failed else 0)
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
