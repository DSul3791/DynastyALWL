extends RefCounted

# Dave's own character for now (30 Oct 2026): the generated body is the default body, and the creator saves one share code that the game wears.
# `--old-body` brings the old ragdoll back. The creator is the first page of the launcher's "play" role until a real account flow exists.

const Generator := preload("res://src/client/character/body_generator.gd")
const PATH := "user://my_character.code"


static func generated_body_on() -> bool:
	return not OS.get_cmdline_user_args().has("--old-body")


static func save_code(code: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)

	if file != null:
		file.store_string(code)


static func saved_code() -> String:
	return FileAccess.get_file_as_string(PATH).strip_edges() if FileAccess.file_exists(PATH) else ""


# The saved genome, or an empty Dictionary when there is none (or it no longer decodes).
static func genome() -> Dictionary:
	var code: String = saved_code()
	return Generator.decode(code) if code != "" else {}
