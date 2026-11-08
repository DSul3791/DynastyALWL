extends SceneTree

# Item icon bake (docs/design/INVENTORY_CRAFTING_LOOK.md section 6; Kathleen 8 Nov 2026). Runs on Dave's PC only, never in the cloud:
# it needs the real renderer, so not --headless.
#   godot --path . --script res://tools/icon_bake.gd -- --out=C:/temp/item_icons --sheet=C:/temp/item_icon_sheet.png [--items=stone,flint] [--px=128]
#
# Every item in data/items/items.json that has a look (src/client/basic_look.gd mesh_for) is drawn alone in one fixed light rig and saved
# as <out>/<item id>.png: 128 px, transparent, a three-quarter view from above, one warm key light from the top left (the same for every
# icon), a thin cool rim light from behind so dark things (iron, charcoal) part from the wood, a low warm ambient (shadows warm brown,
# never grey), and a 2 px dark outline round the silhouette. Drawn at twice the size and scaled down, for clean edges.
# Items with no look, or only the grey placeholder chunk, are listed in <out>/NEEDS_PAINTING.txt for Dave (painted to the same rig later).
# --sheet also saves one picture of every icon on the inventory's slot colour, each beside its 32 px black silhouette (the silhouette
# test: every icon must read as a solid shape at 32 px), for Dave to look at in one go.
# Nothing is written into the project unless --out points there; commit the icons only after Dave has looked at the sheet.

const BasicLook := preload("res://src/client/basic_look.gd")
const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const ITEMS_PATH := "res://data/items/items.json"

const YAW_DEG := 35.0                 # three-quarter view
const PITCH_DEG := -30.0              # from above
const MARGIN := 1.14                  # room round the item for the outline
const KEY_COLOR := Color(1.0, 0.88, 0.7)
const KEY_ENERGY := 2.2
const KEY_ROT := Vector3(-40.0, -35.0, 0.0)     # in the camera's frame: from the upper left, toward the lower right
const RIM_COLOR := Color(0.6, 0.72, 1.0)
const RIM_ENERGY := 1.2
const RIM_ROT := Vector3(-25.0, 150.0, 0.0)     # from behind on the right, toward the camera
const AMBIENT := Color(0.42, 0.34, 0.27)
const AMBIENT_ENERGY := 0.55
const OUTLINE := Color(0.08, 0.05, 0.035)
const OUTLINE_PX := 2.0
const SILHOUETTE_PX := 32
const SHEET_COLS := 10


func _initialize() -> void:
	var out: String = "user://item_icons"
	var sheet: String = ""
	var px: int = 128
	var only: PackedStringArray = PackedStringArray()

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--sheet="):
			sheet = a.trim_prefix("--sheet=")
		elif a.begins_with("--px="):
			px = maxi(16, int(a.trim_prefix("--px=")))
		elif a.begins_with("--items="):
			only = a.trim_prefix("--items=").split(",", false)

	if DisplayServer.get_name() == "headless":
		push_error("icon_bake: needs the renderer; run it without --headless (on Dave's PC)")
		quit(2)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var ids: Array = _item_ids(only)
	var vp: SubViewport = _rig(px * 2)
	root.add_child(vp)
	var holder: MeshInstance3D = MeshInstance3D.new()
	vp.add_child(holder)
	var cam: Camera3D = vp.get_node("Camera") as Camera3D
	var baked: Array = []
	var missing: PackedStringArray = PackedStringArray()

	for id in ids:
		var item_id: String = str(id)
		var mesh: Mesh = _mesh_of(item_id)

		if mesh == null:
			missing.append(item_id)
			continue

		holder.mesh = mesh
		_frame(cam, mesh.get_aabb())
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		await process_frame
		await process_frame
		var image: Image = vp.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(px, px, Image.INTERPOLATE_LANCZOS)
		var icon: Image = outlined(image, OUTLINE_PX * float(px) / 128.0)
		icon.save_png(out.path_join(item_id + ".png"))
		baked.append([item_id, icon])

	var list: FileAccess = FileAccess.open(out.path_join("NEEDS_PAINTING.txt"), FileAccess.WRITE)

	if list != null:
		list.store_string("# Items with no look yet (or only the grey placeholder): paint these to the icon rig (look doc section 6).\n" + "\n".join(missing) + "\n")
		list.close()

	if sheet != "" and not baked.is_empty():
		_sheet(baked, px).save_png(sheet)
		print("icon_bake: sheet ", sheet)

	print("icon_bake: %d icons in %s, %d need painting (NEEDS_PAINTING.txt)" % [baked.size(), out, missing.size()])
	quit(0)


func _item_ids(only: PackedStringArray) -> Array:
	if not only.is_empty():
		return Array(only)

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))

	if typeof(parsed) != TYPE_DICTIONARY or not (parsed.get("items") is Dictionary):
		push_error("icon_bake: cannot read " + ITEMS_PATH)
		return []

	var ids: Array = (parsed["items"] as Dictionary).keys()
	ids.sort()
	return ids


# The item's look, or null when it has none or only the grey placeholder chunk.
func _mesh_of(item_id: String) -> Mesh:
	var row: Dictionary = BasicLook.entry(item_id)

	if row.is_empty() or (str(row.get("shape", "")) == "chunk" and str(row.get("color", "")).to_lower() == "#8a8a8a"):
		return null

	return BasicLook.mesh_for(item_id)


# The fixed rig: a transparent square picture, a warm low ambient, the key and rim lights carried by the camera so they keep their
# place on screen whatever the item.
func _rig(side: int) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(side, side)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX      # the game's tone mapping (look_settings.gd)
	env.tonemap_exposure = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = env
	vp.add_child(world)
	var cam: Camera3D = Camera3D.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(PITCH_DEG, YAW_DEG, 0.0)
	vp.add_child(cam)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.light_color = KEY_COLOR
	key.light_energy = KEY_ENERGY
	key.rotation_degrees = KEY_ROT
	cam.add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.light_color = RIM_COLOR
	rim.light_energy = RIM_ENERGY
	rim.rotation_degrees = RIM_ROT
	cam.add_child(rim)
	return vp


# Aims the camera at the item's middle and sizes the view so the item just fills it, whatever its shape.
func _frame(cam: Camera3D, box: AABB) -> void:
	var basis: Basis = Basis.from_euler(Vector3(deg_to_rad(PITCH_DEG), deg_to_rad(YAW_DEG), 0.0))
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)

	for n in 8:
		var corner: Vector3 = box.get_endpoint(n)
		var seen: Vector2 = Vector2(corner.dot(basis.x), corner.dot(basis.y))
		lo = lo.min(seen)
		hi = hi.max(seen)

	var centre: Vector3 = box.get_center()
	var across: Vector2 = Vector2((lo.x + hi.x) * 0.5 - centre.dot(basis.x), (lo.y + hi.y) * 0.5 - centre.dot(basis.y))
	cam.size = maxf(maxf(hi.x - lo.x, hi.y - lo.y) * MARGIN, 0.01)
	cam.position = centre + basis.x * across.x + basis.y * across.y + basis.z * (box.size.length() + 2.0)
	cam.near = 0.01
	cam.far = box.size.length() * 2.0 + 4.0


# A dark outline round the silhouette: the alpha spread by `width` px, laid under the picture.
static func outlined(image: Image, width: float) -> Image:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var out: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var reach: int = ceili(width)

	for y in h:
		for x in w:
			var spread: float = 0.0

			for dy in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var d: float = sqrt(float(dx * dx + dy * dy))

					if d > width + 0.5:
						continue

					var sx: int = x + dx
					var sy: int = y + dy

					if sx < 0 or sy < 0 or sx >= w or sy >= h:
						continue

					spread = maxf(spread, image.get_pixel(sx, sy).a * clampf(width + 0.5 - d, 0.0, 1.0))

			var top: Color = image.get_pixel(x, y)
			var under: Color = Color(OUTLINE, spread)
			var alpha: float = top.a + under.a * (1.0 - top.a)
			var rgb: Color = (Color(top.r, top.g, top.b) * top.a + Color(under.r, under.g, under.b) * under.a * (1.0 - top.a)) / maxf(alpha, 0.0001)
			out.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, alpha))

	return out


# Every icon on the slot colour, each with its 32 px black silhouette beside it.
func _sheet(baked: Array, px: int) -> Image:
	var cell: Vector2i = Vector2i(px + SILHOUETTE_PX + 12, px + 8)
	var cols: int = mini(SHEET_COLS, baked.size())
	var rows: int = ceili(float(baked.size()) / float(cols))
	var sheet: Image = Image.create(cols * cell.x, rows * cell.y, false, Image.FORMAT_RGBA8)
	sheet.fill(DynastyTheme.SLOT_BG)
	var pale: Image = Image.create(SILHOUETTE_PX, SILHOUETTE_PX, false, Image.FORMAT_RGBA8)

	for n in baked.size():
		var icon: Image = baked[n][1]
		var at: Vector2i = Vector2i((n % cols) * cell.x + 4, floori(float(n) / float(cols)) * cell.y + 4)
		sheet.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), at)
		var small: Image = icon.duplicate() as Image
		small.resize(SILHOUETTE_PX, SILHOUETTE_PX, Image.INTERPOLATE_BILINEAR)
		pale.fill(DynastyTheme.PARCHMENT)

		for y in SILHOUETTE_PX:
			for x in SILHOUETTE_PX:
				if small.get_pixel(x, y).a > 0.5:
					pale.set_pixel(x, y, Color.BLACK)

		sheet.blit_rect(pale, Rect2i(0, 0, SILHOUETTE_PX, SILHOUETTE_PX), at + Vector2i(px + 4, floori(float(px - SILHOUETTE_PX) * 0.5)))

	return sheet
