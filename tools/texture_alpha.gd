extends SceneTree

# Writes data/animals/texture_alpha.json: for every colour texture named in data/animals/models.json ("albedo"), whether it has
# see-through pixels. The game reads the answer from there (animal_view.gd _alpha_ready) instead of reading each texture back from the
# graphics card when a kind's files come in (Lane A r4 at Low, 26 Nov 2026: 38 read backs of 23 ms on average, up to 170 ms, in the frame).
# Worked out from each texture's source image, as the game's own test would from the imported one (detect_alpha, nothing left at 255 alone).
# Run it again after adding a texture to models.json (test_texture_alpha says so):
#   godot --headless --path . --script res://tools/texture_alpha.gd

const MODELS_PATH := "res://data/animals/models.json"
const OUT_PATH := "res://data/animals/texture_alpha.json"


func _init() -> void:
	var textures: Dictionary = {}
	var missing: int = 0

	for path in albedo_paths(JSON.parse_string(FileAccess.get_file_as_string(MODELS_PATH))):
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path)) if FileAccess.file_exists(path) else null

		if img == null or img.is_empty():
			print("texture_alpha: %s has no source image here: left out (the game tests it itself)" % path)
			missing += 1
			continue

		if img.is_compressed():
			img.decompress()

		textures[path] = img.detect_alpha() != Image.ALPHA_NONE

	var keys: Array = textures.keys()
	keys.sort()
	var sorted: Dictionary = {}

	for k in keys:
		sorted[k] = textures[k]

	var out: Dictionary = {"about": "Whether each animal colour texture has see-through pixels; made by tools/texture_alpha.gd from models.json.", "textures": sorted}
	var f: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t") + "\n")
	f.close()
	print("texture_alpha: %d textures written to %s (%d see-through), %d without a source image" % [sorted.size(), OUT_PATH, sorted.values().count(true), missing])
	quit(0)


# Every "albedo" path in the models file, each once, in order.
static func albedo_paths(data: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var stack: Array = [data]

	while not stack.is_empty():
		var item: Variant = stack.pop_back()

		if item is Dictionary:
			for k in (item as Dictionary):
				if str(k) == "albedo" and item[k] is String and str(item[k]) != "" and not out.has(str(item[k])):
					out.append(str(item[k]))
				else:
					stack.append(item[k])
		elif item is Array:
			stack.append_array(item as Array)

	out.sort()
	return out
