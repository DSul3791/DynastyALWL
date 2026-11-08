extends SceneTree

# Creature check (MikeW, 7 Nov 2026): one creature model at a time, built by the game's own animal view (src/client/animal_view.gd
# _make_model), so what it shows is what the game draws. It writes a report and one picture strip per creature:
#   rest pose, then every role the model row names (graze 0, alert 3, warn 10, charge 11, recover 12, walk, run), each paused 40% into its clip,
#   side view on a ground plane with a 1 m grid, so size, facing, feet on the ground and a broken clip (a tube, a body in the floor) show at once.
# The report lists, per creature: file found, drawn from the model or the code body, length, the clip picked for each role, how tall
# the skeleton stands in each role against its rest pose, and the animal view's own notes (skin rebuilt, clip rescaled, clip refused).
# Needs a window (pictures): run without --headless.
#   godot --path . --script res://tools/creature_check.gd -- --kinds=bear,deer --out=E:/Software/godotDev/creature_check [--px=360] [--clips]
# --young builds the young animal (its young_model when the row has one).
# --id=N builds the animal with that id (a species with variants picks its look by id: --id=1 is the second look).
# --roles=clipA,clipB draws those clips (by name) instead of the row's roles: to compare candidate poses.
# --head draws a close-up of each head, front and three-quarter, with the head and eye bones marked and named: for eye_bones / eye_offset.
# --clips also lists every clip in the file (with its length), to pick the clip for each role in a new model row.

const AnimalView := preload("res://src/client/animal_view.gd")
const ROLE_ORDER := ["rest", "0", "3", "10", "11", "12", "15", "18", "19", "walk", "run", "swim"]
const ROLE_NAMES := {"rest": "rest pose", "0": "graze", "3": "alert", "10": "warn", "11": "charge", "12": "recover", "15": "fly", "18": "sit", "19": "lie", "swim": "swim", "walk": "walk", "run": "run"}


var role_clips: PackedStringArray = PackedStringArray()
var head_mode: bool = false


func _init() -> void:
	var kinds: PackedStringArray = PackedStringArray()
	var out: String = "user://creature_check"
	var px: int = 360
	var list_clips: bool = false
	var look_id: int = 0
	var young: bool = false

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kinds="):
			kinds = a.trim_prefix("--kinds=").split(",", false)
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--id="):
			look_id = int(a.trim_prefix("--id="))
		elif a == "--young":
			young = true
		elif a == "--clips":
			list_clips = true
		elif a.begins_with("--roles="):
			role_clips = a.trim_prefix("--roles=").split(",", false)
		elif a == "--head":
			head_mode = true
		elif a.begins_with("--px="):
			px = int(a.trim_prefix("--px="))

	DirAccess.make_dir_recursive_absolute(out)
	var number_of: Dictionary = {}

	for n in AnimalView.KIND_OF_SPECIES:
		number_of[AnimalView.KIND_OF_SPECIES[n]] = int(n)

	var report: PackedStringArray = PackedStringArray()

	for kind in kinds:
		var lines: PackedStringArray = await _check(kind, int(number_of.get(kind, -1)), out, px, list_clips, look_id, young)
		report.append_array(lines)
		report.append("")

	var f: FileAccess = FileAccess.open(out + "/report.txt", FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	print("\n".join(report))
	print("creature check: report and pictures in ", out)
	quit()


func _check(kind: String, number: int, out: String, px: int, list_clips: bool = false, look_id: int = 0, young: bool = false) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["== %s (species %d)" % [kind, number]])

	if number < 0:
		lines.append("FAIL no species number for this kind in animal_view.gd KIND_OF_SPECIES")
		return lines

	var view: Node3D = AnimalView.new()
	var row: Dictionary = view._model_rows().get(kind, {})

	if young and row.get("young_model", null) is Dictionary:
		row = row.duplicate()
		row.merge(row["young_model"], true)

	if row.is_empty():
		lines.append("FAIL no row in data/animals/models.json")
		return lines

	lines.append("file %s: %s" % [str(row.get("scene", "")), "found" if ResourceLoader.exists(str(row.get("scene", ""))) else "MISSING (run tools/install_animal_models.py, then import)"])
	var probe: Node3D = view._make_model(number, look_id, young)

	if probe == null:
		lines.append("FAIL not drawn from the model: the code body is drawn")
		lines.append_array(_notes(view, kind))
		view.free()
		return lines

	var roles: Dictionary = {}

	if probe.has_meta("player"):
		roles = (probe.get_meta("player") as AnimationPlayer).get_meta("roles", {})

		if list_clips:
			var all: PackedStringArray = PackedStringArray()

			for full in (probe.get_meta("player") as AnimationPlayer).get_animation_list():
				all.append("%s %.1f" % [str(full).get_slice("|", str(full).count("|")), (probe.get_meta("player") as AnimationPlayer).get_animation(full).length])

			lines.append("clips (%d): %s" % [all.size(), ", ".join(all)])

	var wanted: Array = ["rest"]

	for r in ROLE_ORDER:
		if r != "rest" and ((row.get("clips", {}) as Dictionary).has(r) or roles.has(r)):
			wanted.append(r)

	if not role_clips.is_empty():
		wanted = ["rest"]

		for c in role_clips:
			wanted.append("clip:" + c)

	if head_mode:
		probe.free()
		return await _head_sheet(view, kind, number, row, out, px, look_id, lines)

	probe.free()

	if row.has("flock_of"):
		var flock: Node3D = view._make_for_species(number, 7)
		lines.append("flock: %s birds from the model (row asks %s)" % [str((flock.get_meta("flock_birds", []) as Array).size()) if flock != null else "no", str(row["flock_of"])])

		if flock != null:
			flock.free()

	# One model per column, each built fresh so every column plays only its own clip.
	var cell: float = maxf(float(row.get("length_m", 1.5)), float(row.get("height_m", 0.0))) * 1.35 + 0.4
	var cols: int = wanted.size()
	var vp: SubViewport = _stage(cols, cell, px)
	var rest_h: float = 0.0

	for c in cols:
		var role: String = wanted[c]
		var model: Node3D = view._make_model(number, look_id, young)
		var cx: float = (float(c) - float(cols - 1) * 0.5) * cell
		model.position = Vector3(cx, 0.0, 0.0)
		model.rotation.y = -PI * 0.5      # faces -Z in the game: turned to face the left of the picture
		vp.add_child(model)
		var label_text: String = ROLE_NAMES.get(role, role)
		var rig: Node3D = model.get_node("Rig")

		if model.has_meta("player"):
			var player: AnimationPlayer = model.get_meta("player")
			var clip: String = str((player.get_meta("roles", {}) as Dictionary).get(role, ""))

			if role.begins_with("clip:"):
				clip = view._clip_full(player, row, role.trim_prefix("clip:"))

			if role == "rest":
				player.stop()
				rest_h = view._clip_height(player, null, rig)
				lines.append("rest pose stands %.2f (skeleton height, model units)" % rest_h)
			elif clip == "":
				label_text += " (none)"
				lines.append("role %-7s NO CLIP (row asks for %s): rest pose is drawn" % [ROLE_NAMES.get(role, role), str((row.get("clips", {}) as Dictionary).get(role, "-"))])
			else:
				var anim: Animation = player.get_animation(clip)
				player.play(clip)
				player.seek(anim.length * 0.4, true)
				player.speed_scale = 0.0
				var h: float = view._clip_height(player, anim, rig)
				lines.append("role %-7s %s  %.1f s  stands %.0f%% of rest" % [ROLE_NAMES.get(role, role), clip.get_slice("|", clip.count("|")), anim.length, 100.0 * h / maxf(rest_h, 0.0001)])
				label_text += "\n" + clip.get_slice("|", clip.count("|"))

		var label: Label3D = Label3D.new()
		label.text = label_text
		label.font_size = 36
		label.pixel_size = cell / 420.0
		label.outline_size = 8
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.position = Vector3(cx, 0.01, cell * 0.38)
		vp.add_child(label)

	lines.append_array(_notes(view, kind))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE

	for i in 4:
		await process_frame

	var image: Image = vp.get_texture().get_image()
	var path: String = "%s/%s%s%s.png" % [out, "young_" if young else "", kind, "" if look_id == 0 else "_%d" % look_id]
	image.save_png(path)
	lines.append("picture %s" % path)
	vp.queue_free()
	view.free()
	return lines


func _notes(view: Node3D, kind: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()

	for key in view._model_notes:
		if str(key).begins_with(kind):
			lines.append("note " + str(key).trim_prefix(kind))

	return lines


# A sky, a sun and a ground plane with a metre grid; the camera looks along -Z from the south, a little from above.
func _stage(cols: int, cell: float, px: int) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(cols * px, int(px * 1.1))
	vp.own_world_3d = true
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(float(cols) * cell + 4.0, cell * 3.0)
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.34, 0.44, 0.24)
	plane.material = gm
	ground.mesh = plane
	vp.add_child(ground)
	var grid: MeshInstance3D = MeshInstance3D.new()
	var im: ImmediateMesh = ImmediateMesh.new()
	var lm: StandardMaterial3D = StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.2, 0.26, 0.14)
	im.surface_begin(Mesh.PRIMITIVE_LINES, lm)
	var half_x: float = float(cols) * cell * 0.5 + 2.0

	for i in range(-int(half_x), int(half_x) + 1):
		im.surface_add_vertex(Vector3(float(i), 0.005, -cell * 1.5))
		im.surface_add_vertex(Vector3(float(i), 0.005, cell * 1.5))

	im.surface_end()
	grid.mesh = im
	vp.add_child(grid)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = cell * 1.1
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	cam.position = Vector3(0.0, cell * 0.3 + 20.0 * sin(deg_to_rad(10.0)), 20.0 * cos(deg_to_rad(10.0)))
	vp.add_child(cam)
	root.add_child(vp)
	return vp


# Head close-ups (--head): the model in its rest pose, two cameras on the head bone (front and three-quarter), every bone whose
# name says head or eye marked with a small red ball and its name, so eye_bones or an eye_offset can be read off the picture.
func _head_sheet(view: Node3D, kind: String, number: int, row: Dictionary, out: String, px: int, look_id: int, lines: PackedStringArray) -> PackedStringArray:
	var model: Node3D = view._make_model(number, look_id)
	var sks: Array = model.find_children("*", "Skeleton3D", true, false)

	if sks.is_empty():
		lines.append("head: no skeleton")
		model.free()
		return lines

	var sk: Skeleton3D = sks[0]
	var vp: SubViewport = _stage(2, 1.0, px)
	vp.add_child(model)
	await process_frame
	var head_pos: Vector3 = model.global_position
	var marks: PackedStringArray = PackedStringArray()

	for i in sk.get_bone_count():
		var bone_name: String = sk.get_bone_name(i)
		var low: String = bone_name.to_lower()

		if not (low.contains("head") or low.contains("eye")):
			continue

		var at: Vector3 = sk.global_transform * sk.get_bone_global_pose(i).origin
		var ball: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.006
		sphere.height = 0.012
		ball.mesh = sphere
		var red: StandardMaterial3D = StandardMaterial3D.new()
		red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		red.albedo_color = Color(1.0, 0.1, 0.1)
		red.no_depth_test = true
		ball.material_override = red
		vp.add_child(ball)
		ball.global_position = at
		var tag: Label3D = Label3D.new()
		tag.text = bone_name
		tag.font_size = 24
		tag.pixel_size = 0.0004
		tag.no_depth_test = true
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		vp.add_child(tag)
		tag.global_position = at + Vector3(0.0, 0.015, 0.0)
		marks.append("%s at %s" % [bone_name, str(at.snapped(Vector3.ONE * 0.001))])

		if low.contains("head") and not low.contains("end"):
			head_pos = at

	for cam_old in vp.find_children("*", "Camera3D", true, false):
		cam_old.queue_free()

	lines.append("head bones: " + "; ".join(marks))
	var shots: Array = [["front", Vector3(0.0, 0.0, -1.0)], ["three_quarter", Vector3(0.7, 0.2, -0.7).normalized()]]
	var span: float = float(row.get("length_m", 1.0)) * 0.25 + 0.15

	for shot in shots:
		var cam: Camera3D = Camera3D.new()
		cam.fov = 30.0
		vp.add_child(cam)
		cam.global_position = head_pos + (shot[1] as Vector3) * span * 2.0
		cam.look_at(head_pos, Vector3.UP)
		cam.current = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE

		for i in 3:
			await process_frame

		var path: String = "%s/head_%s_%s.png" % [out, kind, shot[0]]
		vp.get_texture().get_image().save_png(path)
		lines.append("picture " + path)
		cam.queue_free()
		await process_frame

	vp.queue_free()
	return lines
