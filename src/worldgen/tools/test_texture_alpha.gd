extends SceneTree

# The see-through answers kept with the animal models (data/animals/texture_alpha.json, made by tools/texture_alpha.gd; Lane A r4 at Low,
# 26 Nov 2026: reading each texture back from the graphics card held the frame 23 ms on average, up to 170 ms): every colour texture named
# in models.json has one, each matches its source image where the image is here, and the animal view takes the answer without reading the
# texture back or starting a worker.
#   godot --headless --path . --script res://src/worldgen/tools/test_texture_alpha.gd

const AnimalViewScript := preload("res://src/client/animal_view.gd")
const TextureAlphaTool := preload("res://tools/texture_alpha.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var v = AnimalViewScript.new()
	var table: Dictionary = v._alpha_table()
	check(not table.is_empty(), "the table is there (%d textures)" % table.size())
	var named: PackedStringArray = TextureAlphaTool.albedo_paths(JSON.parse_string(FileAccess.get_file_as_string(v.MODELS_PATH)))
	var unlisted: PackedStringArray = PackedStringArray()
	var wrong: PackedStringArray = PackedStringArray()
	var compared: int = 0

	for path in named:
		if not FileAccess.file_exists(path):
			continue      # a texture the pack does not have here: models.json names it, the game leaves it out

		if not table.has(path):
			unlisted.append(path)
			continue

		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))

		if img == null or img.is_empty():
			continue

		if img.is_compressed():
			img.decompress()

		compared += 1

		if (img.detect_alpha() != Image.ALPHA_NONE) != bool(table[path]):
			wrong.append(path)

	check(unlisted.is_empty(), "every colour texture of models.json has an answer; run tools/texture_alpha.gd for: %s" % ", ".join(unlisted))
	check(wrong.is_empty(), "each answer matches its source image (%d compared): %s" % [compared, ", ".join(wrong)])

	if not table.is_empty():
		var path: String = str(table.keys()[0])
		check(v._alpha_ready(path, null) and v._alpha_tasks.is_empty(), "the view takes a kept answer at once: no read back, no worker")
		check(bool(v._alpha_of[path]) == bool(table[path]), "with the kept answer")

	v.free()
	print("test_texture_alpha: %d failures" % failures)
	quit(1 if failures > 0 else 0)
