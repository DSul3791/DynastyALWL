extends RefCounted

# The character this player wears (30 Oct 2026): the generated body is the default body, and the active character of character_store.gd decides which one.
# `--old-body` brings the old ragdoll back. The pages are scenes/character_select (first page of the launcher's "play" role) and scenes/creator_proto.

const Store := preload("res://src/client/character/character_store.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const GeneratedBodyScript := preload("res://src/client/character/generated_body.gd")
const RagdollScript := preload("res://src/client/ragdoll_body.gd")
const DynastyBodyScript := preload("res://src/client/character/dynasty_body.gd")
const LEGACY_PATH := "user://my_character.code"       # the single saved code of the first creator; still worn when no character has been made yet


const SETTINGS_PATH := "user://input_settings.cfg"


# Dave's own body (assets/character/Humanoid/Dynasty_Base_Male.glb, src/client/character/dynasty_body.gd) is the player's body since 1 Nov 2026. `--oldbody` on the client, or the
# "Old body" switch in Esc > Settings > Gameplay (the next Play), brings back the body worn before it (the generated body; `--old-body` as below still gives the ragdoll).
static func dynasty_body_on(path: String = SETTINGS_PATH) -> bool:
	return not old_body(path)


static func old_body(path: String = SETTINGS_PATH) -> bool:
	if OS.get_cmdline_user_args().has("--oldbody"):
		return true

	var file: ConfigFile = ConfigFile.new()
	return file.load(path) == OK and bool(file.get_value("character", "old_body", false))


static func set_old_body(on: bool, path: String = SETTINGS_PATH) -> void:
	var file: ConfigFile = ConfigFile.new()
	file.load(path)
	file.set_value("character", "old_body", on)
	file.save(path)


# The body the player wears this run: Dave's Dynasty body when it is wanted and usable, else the generated body, else the old ragdoll (`--old-body`). A Dynasty glb that is not imported
# (a fresh checkout before `godot --import`) falls back to the generated body, so there is always a body with an AnimationPlayer.
static func make_avatar() -> Node3D:
	if dynasty_body_on() and DynastyBodyScript.available():
		return DynastyBodyScript.new()

	return GeneratedBodyScript.new(genome()) if generated_body_on() else RagdollScript.new()


static func generated_body_on() -> bool:
	return not OS.get_cmdline_user_args().has("--old-body")


# The active character's genome, or an empty Dictionary when there is none (the body then falls back to the average one).
static func genome() -> Dictionary:
	var one: Dictionary = Store.active()

	if not one.is_empty():
		return one["genome"]

	var legacy: String = FileAccess.get_file_as_string(LEGACY_PATH).strip_edges() if FileAccess.file_exists(LEGACY_PATH) else ""
	return Generator.decode(legacy) if legacy != "" else {}
