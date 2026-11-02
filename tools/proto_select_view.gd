extends SceneTree

# PROTOTYPE (Sonny, 30 Oct 2026): pictures of the character select page with no characters (it goes to the creator, with the name box open), one and three. Needs a window.
#   godot --path . --resolution 1920x1080 --script res://tools/proto_select_view.gd -- --out=res://art/character_proto/select
# Uses user://characters_test, never the real characters.

const Store := preload("res://src/client/character/character_store.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const Select := preload("res://scenes/character_select/character_select.tscn")
const Creator := preload("res://scenes/creator_proto/creator_proto.tscn")

var _out: String = "res://art/character_proto/select"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)

	_run()


func _frames(count: int = 6) -> void:
	for _i in range(count):
		await process_frame

	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await _frames()
	var im: Image = root.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	im.save_png(ProjectSettings.globalize_path("%s/%s.png" % [_out, name]))
	print("saved ", name, " ", im.get_size())


func _wipe() -> void:
	if DirAccess.dir_exists_absolute(Store.dir):
		for file in DirAccess.get_files_at(Store.dir):
			DirAccess.remove_absolute(Store.dir + "/" + file)


func _run() -> void:
	Store.dir = "user://characters_test"
	_wipe()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	root.size = Vector2i(1920, 1080)
	# 0 characters: the page hands over to the creator; "Save and play" asks for a name.
	var creator: Control = Creator.instantiate()
	root.add_child(creator)
	creator.turntable = false
	await _frames(10)
	creator._body.rotation_degrees.y = 180.0
	creator._ask_name()
	creator._name_edit.text = "Hob Fennel"
	await _shot("0_none_goes_to_creator_name_box")
	creator.queue_free()
	await _frames(2)
	Store.add("Hob Fennel", Generator.encode(Generator.make_genome("average")))
	var page: Control = Select.instantiate()
	page.auto_creator = false
	root.add_child(page)
	await _frames(8)
	await _shot("1_one_character")
	Store.add("Wren Ash", Generator.encode(Generator.make_genome("lean", Color(0.45, 0.3, 0.22), Color(0.08, 0.06, 0.05))))
	Store.add("Brock", Generator.encode(Generator.make_genome("broad", Color(0.93, 0.78, 0.66), Color(0.7, 0.55, 0.25))))
	page.refresh()
	await _frames(8)
	await _shot("3_three_characters")
	page._press_delete()
	await _shot("3_delete_confirm")
	_wipe()
	quit(0)
