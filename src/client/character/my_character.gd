extends RefCounted

# The character this player wears (30 Oct 2026): the generated body is the default body, and the active character of character_store.gd decides which one.
# `--old-body` brings the old ragdoll back. The pages are scenes/character_select (first page of the launcher's "play" role) and scenes/creator_proto.

const Store := preload("res://src/client/character/character_store.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const LEGACY_PATH := "user://my_character.code"       # the single saved code of the first creator; still worn when no character has been made yet


static func generated_body_on() -> bool:
	return not OS.get_cmdline_user_args().has("--old-body")


# The active character's genome, or an empty Dictionary when there is none (the body then falls back to the average one).
static func genome() -> Dictionary:
	var one: Dictionary = Store.active()

	if not one.is_empty():
		return one["genome"]

	var legacy: String = FileAccess.get_file_as_string(LEGACY_PATH).strip_edges() if FileAccess.file_exists(LEGACY_PATH) else ""
	return Generator.decode(legacy) if legacy != "" else {}
