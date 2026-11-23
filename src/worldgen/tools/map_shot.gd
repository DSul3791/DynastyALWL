extends SceneTree

# A picture of the Journal's Map page (map_page.gd) for review, on a machine with a GPU (Lane A): the page drawn at 1600 x 900 from a
# made-up explored patch (the default: a coast with sea, a river, a lake, marsh, woods, hills, a road and a path, and one of each landmark),
# or from a server's saved map of one character (--map=<store>/maps/<file>.json, a COPY, never a live save). Written for Dave's 23 Nov 2026
# play test of the Map ("too digital and fake"); it only uses what the page and its store had before (knowledge, centre, zoom, follow), so
# the same file run on an older commit draws the "before" picture.
#   godot --path . --script res://src/worldgen/tools/map_shot.gd -- --out=C:/tmp/map_after.png [--zoom=1.5] [--q=40] [--map=<file>] [--at=x,z]
# Not headless: the page must really be drawn. Prints "map shot: <file>" when written.

const Codec := preload("res://src/shared/map_codec.gd")
const KnowledgeScript := preload("res://src/client/map_knowledge.gd")
const PageScript := preload("res://src/client/map_page.gd")

var page = null
var frames: int = 0
var idle_from: int = -1
var out_path: String = "user://map_shot.png"


func _init() -> void:
	var args: Dictionary = {}

	for a in OS.get_cmdline_user_args():
		var parts: PackedStringArray = str(a).trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"

	out_path = str(args.get("out", out_path))
	var knowledge = KnowledgeScript.new()
	var centre_m: Vector2 = Vector2(48.0, 32.0) * knowledge.cell_m

	if args.has("map"):
		centre_m = _load_map(knowledge, str(args["map"]))
	else:
		_demo(knowledge, int(args.get("q", "40")))

	if args.has("at"):
		var at: PackedStringArray = str(args["at"]).split(",")
		centre_m = Vector2(float(at[0]), float(at[1]))

	root.size = Vector2i(1600, 900)
	page = PageScript.new()
	page.size = Vector2(1600, 900)
	root.add_child(page)
	page.knowledge = knowledge
	page.follow = false
	page.zoom = float(args.get("zoom", "1.5"))
	page.where = func() -> Vector3: return Vector3(centre_m.x, 0.0, centre_m.y)
	page.centre = centre_m * (float(page.Sketch.PX) / knowledge.cell_m)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	frames += 1

	if frames < 20 or (frames < 3000 and (not page._dirty.is_empty() or page._job >= 0)):
		idle_from = -1
		return

	if idle_from < 0:
		idle_from = frames

	if frames < idle_from + 10:
		return   # a few frames more for the last block's texture to show

	var image: Image = root.get_texture().get_image()

	if image == null:
		push_error("map shot: nothing was drawn (run it with a window, not --headless)")
		quit(1)
		return

	image.save_png(out_path)
	print("map shot: %s" % ProjectSettings.globalize_path(out_path))
	quit(0)


# A block into the store, with its marks and paths where the store takes them (an older store takes the cells only).
func _put(knowledge, block: Vector2i, cells: Dictionary, marks: Array, paths: PackedInt32Array) -> void:
	for method in knowledge.get_method_list():
		if str(method["name"]) == "set_block":
			if (method["args"] as Array).size() >= 4:
				knowledge.set_block(block, cells, marks, paths)
			else:
				knowledge.set_block(block, cells)

			return


# A server's saved map of one character (server_map.gd _save_one): its blocks, marks and paths. Returns the middle of what it holds, in metres.
func _load_map(knowledge, path: String) -> Vector2:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("map shot: %s did not parse" % path)
		quit(1)
		return Vector2.ZERO

	var sum: Vector2 = Vector2.ZERO
	var count: int = 0

	for name in parsed.get("blocks", {}):
		var parts: PackedStringArray = str(name).split(",")
		var block: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
		var paths: PackedInt32Array = PackedInt32Array()

		for v in parsed.get("paths", {}).get(name, []):
			paths.append(int(v))

		_put(knowledge, block, Codec.decode(Marshalls.base64_to_raw(str(parsed["blocks"][name]))), parsed.get("marks", {}).get(name, []), paths)
		sum += (Vector2(block) + Vector2(0.5, 0.5)) * float(knowledge.block_cells) * knowledge.cell_m
		count += 1

	return sum / float(maxi(count, 1))


# The made-up explored patch: three blocks by two, an irregular explored outline.
func _demo(knowledge, q: int) -> void:
	var per: int = knowledge.block_cells
	var cm: float = knowledge.cell_m

	for bz in 2:
		for bx in 3:
			var cells: Dictionary = {}
			var paths: PackedInt32Array = PackedInt32Array()

			for idx in per * per:
				var gx: int = bx * per + idx % per
				var gz: int = bz * per + idx / per
				var dxe: float = float(gx - 48) / 44.0
				var dze: float = float(gz - 32) / 30.0

				if dxe * dxe + dze * dze > 1.0 + 0.15 * sin(gx * 0.3) * cos(gz * 0.2):
					continue

				var coast: float = 18.0 + 6.0 * sin(gz * 0.15) + 3.0 * sin(gz * 0.5)
				var h: float = (gx - coast) * 1.5 + 25.0 * sin(gx * 0.08) * cos(gz * 0.1)
				var w: int = Codec.WATER_NONE

				if gx < coast:
					w = Codec.WATER_SEA
					h = 0.0

				if absf(gx - (60.0 + 5.0 * sin(gz * 0.2))) < 0.6 and gz > 8:
					w = 3   # a river
				if Vector2(gx - 75, gz - 20).length() < 5.0 + sin(gz):
					w = Codec.WATER_INLAND
				if Vector2(gx - 40, gz - 50).length() < 4.0 and w == 0:
					w = 4   # marsh

				var t: int = 0

				if w == 0 and sin(gx * 0.12) * cos(gz * 0.17) > 0.2:
					t = 3 if sin(gx * 0.31 + gz * 0.2) > 0.0 else 2

				cells[idx] = [q, round(h), w, t]

				if gz == 30 + int(2.0 * sin(gx * 0.2)) and gx > 22 and gx < 70:
					paths.append(idx * 4 + 2)   # a road
				if gx == 45 + int(1.5 * sin(gz * 0.3)) and gz > 30 and gz < 50:
					paths.append(idx * 4 + 1)   # a path

			var marks: Array = []

			if bx == 1 and bz == 0:
				marks = [["campfire", 46.0 * cm, 28.0 * cm, ""], ["cave", 52.0 * cm, 12.0 * cm, "Cave"], ["fruit:apple", 40.0 * cm, 20.0 * cm, "Apple orchard"], ["spring", 36.0 * cm, 8.0 * cm, "Spring"]]
			elif bx == 1 and bz == 1:
				marks = [["goblin_camp", 55.0 * cm, 40.0 * cm, "Ragtooth"], ["bog_iron", 40.0 * cm, 54.0 * cm, "Bog iron"], ["ore_rock:copper", 50.0 * cm, 45.0 * cm, "Copper"]]
			elif bx == 0 and bz == 1:
				marks = [["fishing", 21.0 * cm, 40.0 * cm, "Good fishing"], ["fruit:cherry", 28.0 * cm, 52.0 * cm, "Cherry trees"]]
			elif bx == 2 and bz == 1:
				marks = [["bandit_camp", 80.0 * cm, 45.0 * cm, "Bandits"]]

			_put(knowledge, Vector2i(bx, bz), cells, marks, paths)
