extends SceneTree

# One picture of each creator section at 1920 x 1080 (Sonny, 31 Oct 2026), to see what is cut off: opens every accordion section in turn and saves a screenshot. Needs a window.
#   godot --path . --resolution 1920x1080 --script res://tools/proto_creator_sections_view.gd -- --out=res://art/character_proto/creator_1080

const Scene := preload("res://scenes/creator_proto/creator_proto.tscn")

var _out: String = "res://art/character_proto/creator_1080"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)

	_run()


func _frames(count: int = 4) -> void:
	for _i in range(count):
		await process_frame

	await RenderingServer.frame_post_draw


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	root.size = Vector2i(1920, 1080)
	var screen: Control = Scene.instantiate()
	root.add_child(screen)
	await _frames(8)
	var n: int = 0

	for title in screen._sections.keys():
		screen._open_section(String(title))
		await _frames()
		var im: Image = root.get_texture().get_image()
		im.convert(Image.FORMAT_RGB8)
		var name: String = String(title).to_lower().replace(" ", "_")
		print("section ", title, " size ", im.get_size(), " saved ", im.save_jpg("%s/%02d_%s.jpg" % [ProjectSettings.globalize_path(_out), n, name], 0.88))
		n += 1

	quit(0)
