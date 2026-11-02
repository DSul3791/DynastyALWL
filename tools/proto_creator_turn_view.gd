extends SceneTree

# PROTOTYPE (Sonny, 2026-10-30): pictures of the character creator screen and of its preview body from the front, the side and the back. Needs a window.
#   godot --path . --resolution 1920x1080 --script res://tools/proto_creator_turn_view.gd -- --out=res://art/character_proto/creator2
# Writes screen_*.png (whole screen, turntable stopped) and head_*.png (a close view of the preview from the angle named).

const Scene := preload("res://scenes/creator_proto/creator_proto.tscn")

var _out: String = "res://art/character_proto/creator2"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)

	_run()


func _frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame

	await RenderingServer.frame_post_draw


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	root.size = Vector2i(1920, 1080)
	var screen: Control = Scene.instantiate()
	root.add_child(screen)
	screen.turntable = false
	await _frames(10)
	screen._open_section("Head and face")
	var angles: Dictionary = {"front": 180.0, "side": 90.0, "back": 0.0, "back_left": 35.0}

	for key in angles:
		screen._body.rotation_degrees.y = angles[key]
		screen._turn = angles[key]
		await _frames()
		var im: Image = root.get_viewport().get_texture().get_image()
		im.save_png(ProjectSettings.globalize_path(_out + "/screen_" + key + ".png"))
		var pv: Image = screen._preview.get_texture().get_image()
		pv.save_png(ProjectSettings.globalize_path(_out + "/preview_" + key + ".png"))

	quit(0)
