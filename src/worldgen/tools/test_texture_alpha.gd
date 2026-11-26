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
	var alpha_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(v.ALPHA_PATH))
	var absent: Array = alpha_file.get("absent", [])
	var unlisted: PackedStringArray = PackedStringArray()
	var come: PackedStringArray = PackedStringArray()
	var wrong: PackedStringArray = PackedStringArray()
	var compared: int = 0

	for path in named:
		if not table.has(path) and not absent.has(path):
			unlisted.append(path)      # the merge check (tools/check_texture_alpha.py) catches this without the pack
			continue

		if absent.has(path):
			if FileAccess.file_exists(path):
				come.append(path)      # listed as having no source image, but it is here now: its answer is wanted

			continue

		if not FileAccess.file_exists(path):
			continue      # the pack is not on this machine (the cloud, Lane B): nothing to compare

		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))

		if img == null or img.is_empty():
			continue

		if img.is_compressed():
			img.decompress()

		compared += 1

		if (img.detect_alpha() != Image.ALPHA_NONE) != bool(table[path]):
			wrong.append(path)

	check(unlisted.is_empty(), "every colour texture of models.json has an answer; run tools/texture_alpha.gd for: %s" % ", ".join(unlisted))
	check(come.is_empty(), "no texture listed as absent is here now; run tools/texture_alpha.gd for: %s" % ", ".join(come))
	check(wrong.is_empty(), "each answer matches its source image (%d compared): %s" % [compared, ", ".join(wrong)])

	if compared == 0:
		print("NOT COMPARED: no source image of the model pack loads here (the cloud, Lane B or LFS pointers): the answers were not checked")

	if not table.is_empty():
		var path: String = str(table.keys()[0])
		check(v._alpha_ready(path, null) and v._alpha_tasks.is_empty(), "the view takes a kept answer at once: no read back, no worker")
		check(bool(v._alpha_of[path]) == bool(table[path]), "with the kept answer")

	# _has_alpha (a model drawn where _scenes_ready did not test first: headless, tools) takes the kept answer too, not the pixels: a solid
	# 1 x 1 texture under a path the table calls see-through is see-through.
	var see_through_path: String = ""

	for p in table:
		if bool(table[p]):
			see_through_path = str(p)
			break

	if see_through_path != "":
		var solid: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		solid.fill(Color(0.5, 0.4, 0.3, 1.0))
		var tex: ImageTexture = ImageTexture.create_from_image(solid)
		tex.resource_path = see_through_path
		var w = AnimalViewScript.new()
		check(w._has_alpha(tex), "_has_alpha gives the kept answer, not the texture's own pixels")
		w.free()

	v.free()
	print("test_texture_alpha: %d failures" % failures)
	quit(1 if failures > 0 else 0)
