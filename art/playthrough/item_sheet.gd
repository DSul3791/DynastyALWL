extends SceneTree

# Playthrough contact sheets, with the game's own look code and no world: every item as BasicLook.mesh_for() draws it (so an ART_OVERRIDES row that
# the game ignores is ignored here too), and every structure look as LookTable.build() draws it, on a plain ground with a name tag under each.
# Needs a window (real renderer), about 10 s a sheet:
#   godot --path . --script res://art/playthrough/item_sheet.gd -- --out=art/playthrough/sheets
#   options: --per=30 (items a sheet), --only=items|structures
# Writes sheet_NN_<group>.png and sheets.json (sheet -> item ids in row-major order, west to east, north to south).

const BasicLook := preload("res://src/client/basic_look.gd")
const LookTable := preload("res://src/client/look_table.gd")
const W := 1800
const H := 1000

var vp: SubViewport
var cam: Camera3D
var stage: Node3D
var out_dir: String = "art/playthrough/sheets"
var report: Array = []


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _init() -> void:
	var per: int = 30
	var only: String = ""

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a.begins_with("--per="):
			per = int(a.trim_prefix("--per="))
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://") + out_dir)
	vp = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.75)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(80, 80)
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.46, 0.26)
	plane.material = gm
	ground.mesh = plane
	vp.add_child(ground)
	stage = Node3D.new()
	vp.add_child(stage)
	cam = Camera3D.new()
	cam.fov = 38.0
	vp.add_child(cam)
	root.add_child(vp)
	await process_frame

	if only != "structures":
		await _items_sheets(per)

	if only != "items":
		await _structure_sheets()

	var f: FileAccess = FileAccess.open(ProjectSettings.globalize_path("res://") + out_dir + "/sheets.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, " "))
	f.close()
	print("sheets: wrote ", report.size(), " sheets to ", out_dir)
	quit()


func _label(text: String, pos: Vector3, size: int, color: Color) -> void:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.no_depth_test = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = color
	l.outline_size = 12
	l.position = pos
	stage.add_child(l)


func _clear() -> void:
	for c in stage.get_children():
		c.queue_free()


func _shoot(file: String, centre: Vector3, dist: float, pitch: float) -> void:
	cam.rotation_degrees = Vector3(pitch, 0, 0)
	cam.position = centre + cam.transform.basis.z * dist
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	await process_frame
	await process_frame
	var img: Image = vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://") + out_dir + "/" + file)


func _items_sheets(per: int) -> void:
	var items: Dictionary = _load("res://data/items/items.json").get("items", {})
	items.merge(_load("res://data/items/gathered.json").get("items", {}))
	var rows: Dictionary = {}
	var rows_text: String = FileAccess.get_file_as_string("res://art/playthrough/showroom/rows.json")
	var parsed: Variant = JSON.parse_string(rows_text)

	if typeof(parsed) == TYPE_DICTIONARY:
		rows = parsed

	var ids: Array = []

	for id in rows.keys():   # rows.json is already in chapter order
		if items.has(id):
			ids.append(id)

	var sheet: int = 0
	var cols: int = 6
	var sp: float = 1.3

	for start in range(0, ids.size(), per):
		_clear()
		await process_frame
		var chunk: Array = ids.slice(start, start + per)
		var nrows: int = int(ceil(float(chunk.size()) / float(cols)))

		for n in range(chunk.size()):
			var id: String = str(chunk[n])
			var x: float = (float(n % cols) - float(cols - 1) * 0.5) * sp
			var z: float = (float(n / cols) - float(nrows - 1) * 0.5) * sp
			var mesh: Mesh = BasicLook.mesh_for(id)
			var status: String = "ok"
			var entry: Dictionary = BasicLook.entry(id)

			var special: bool = id in ["stone", "stick", "log", "driftwood"] or id.begins_with("log_")

			if mesh == null and special:
				status = "special drawing (not looks.json)"
				var sbox: BoxMesh = BoxMesh.new()
				sbox.size = Vector3(0.08, 0.08, 0.08)
				mesh = sbox
			elif mesh == null:
				status = "NO LOOK"
				var box: BoxMesh = BoxMesh.new()
				box.size = Vector3(0.1, 0.1, 0.1)
				mesh = box
			elif mesh.get_aabb().size.length() < 0.005:
				status = "EMPTY MESH (draws nothing)"
			elif str(entry.get("shape", "")) == "chunk" and str(entry.get("color", "")) == "#8a8a8a":
				status = "grey placeholder"

			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = mesh
			mi.scale = Vector3.ONE * 2.2
			mi.position = Vector3(x, 0.1, z)
			stage.add_child(mi)
			_label(id if status == "ok" else id + "\n[" + status + "]", Vector3(x, 0.02, z + sp * 0.4), 26, Color(1, 1, 1) if status == "ok" or status.begins_with("special") else Color(1, 0.55, 0.45))

		sheet += 1
		var file: String = "items_%02d.png" % sheet
		var span_x: float = float(cols) * sp
		await _shoot(file, Vector3(0, 0, 0), maxf(span_x * 0.82, float(nrows) * sp * 1.6), -58.0)
		report.append({"file": file, "kind": "items", "ids": chunk})
		print("sheets: ", file, " ", chunk.size(), " items")


func _structure_sheets() -> void:
	var structures: Dictionary = _load("res://data/items/structures.json").get("structures", {})
	var names: Array = structures.keys()
	var inv_view: Node = load("res://src/client/inventory_view.gd").new()
	var sheet: int = 0

	for start in range(0, names.size(), 4):
		_clear()
		await process_frame
		var chunk: Array = names.slice(start, start + 4)
		var spacing: float = 5.0

		for n in range(chunk.size()):
			var kind: String = str(chunk[n])
			var spec: Dictionary = structures[kind]
			var look: String = str(spec.get("look", ""))
			var x: float = (float(n) - float(chunk.size() - 1) * 0.5) * spacing
			var status: String = "ok"
			var node: Node3D = null

			node = inv_view.ghost_model(int(spec.get("state", 0)))   # the game's own dispatcher: look table first, then the bench, forge and fire builders

			if node == null or node.find_children("*", "MeshInstance3D", true, false).is_empty():
				status = "DRAWS NOTHING (look '%s')" % look
				node = Node3D.new()
				var mi: MeshInstance3D = MeshInstance3D.new()
				var box: BoxMesh = BoxMesh.new()
				box.size = Vector3(float(spec.get("footprint_x", 1.0)), 0.3, float(spec.get("footprint_z", 1.0)))
				mi.mesh = box
				node.add_child(mi)

			node.position = Vector3(x, 0.0, 0.0)
			stage.add_child(node)
			_label("%s [look %s]%s" % [kind, look, "" if status == "ok" else "\n" + status], Vector3(x, 0.1, 2.6), 30, Color(1, 1, 1) if status == "ok" else Color(1, 0.5, 0.4))

		sheet += 1
		var file: String = "structures_%02d.png" % sheet
		await _shoot(file, Vector3(0, 1.0, 0), 19.0, -26.0)
		report.append({"file": file, "kind": "structures", "ids": chunk})
		print("sheets: ", file, " ", chunk)
