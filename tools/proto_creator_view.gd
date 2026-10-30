extends SceneTree

# PROTOTYPE (Sonny, 2026-10-30), plan 14: opens the creator screen, plays a few actions as a person would (a dice, a lock, a body type, a slider, undo) and saves screenshots.
#   godot --path . --resolution 1280x720 --script res://tools/proto_creator_view.gd -- --out=res://art/character_proto/creator
# Needs a window.

const Scene := preload("res://scenes/creator_proto/creator_proto.tscn")

var _out: String = "res://art/character_proto/creator"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)

	_run()


func _frames(count: int = 3) -> void:
	for _i in range(count):
		await process_frame

	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await _frames()
	var im: Image = root.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	im.save_png("%s/%s.png" % [_out, name])
	print("saved ", name, " ", im.get_size())


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	root.size = Vector2i(1280, 720)
	var screen: Control = Scene.instantiate()
	root.add_child(screen)
	await _frames(6)
	screen.turntable = false
	screen._body.rotation_degrees.y = 20.0
	await _shot("1_start")
	# Lock the height, roll everything, look at the result.
	screen.logic.set_lock("height", true)
	screen.logic.set_slider("height", 0.4)
	screen.logic.dice_all()
	screen._changed("Rolled everything (locked values kept)")
	screen._rebuild_body()
	await _shot("2_dice_everything_height_locked")
	# A body type, then a face dice.
	screen.logic.apply_preset("broad")
	screen.logic.dice_section("Head and face")
	screen._changed("Body type: broad, then the face dice")
	screen._rebuild_body()
	await _shot("3_broad_then_face_dice")
	# Undo twice.
	screen.logic.undo()
	screen.logic.undo()
	screen._changed("Undone twice")
	screen._rebuild_body()
	await _shot("4_undo_twice")
	print("done")
	quit()
