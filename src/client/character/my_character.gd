extends RefCounted

# The character this player wears (30 Oct 2026): Dave's Dynasty body (the generated body when its glb is not imported), shaped by the active character of character_store.gd.
# Since 8 Nov 2026 (Dave: "lets turn them all on and get rid of that code") there is no old body to go back to. The pages are scenes/character_select (first page of the launcher's "play" role) and scenes/creator_proto.

const Store := preload("res://src/client/character/character_store.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const GeneratedBodyScript := preload("res://src/client/character/generated_body.gd")
const DynastyBodyScript := preload("res://src/client/character/dynasty_body.gd")
const LEGACY_PATH := "user://my_character.code"       # the single saved code of the first creator; still worn when no character has been made yet



# The body the player wears this run: Dave's Dynasty body (assets/character/Humanoid/Dynasty_Base_Male.glb, dynasty_body.gd, since 1 Nov 2026). A Dynasty glb that is not imported
# (a fresh checkout before `godot --import`) falls back to the generated body, so there is always a body with an AnimationPlayer.
static func make_avatar() -> Node3D:
	if DynastyBodyScript.available():
		var body: Node3D = DynastyBodyScript.new()
		body.set_proportions(genome())      # the creator's sliders shape Dave's body too (dynasty_proportions.gd)
		return body

	return GeneratedBodyScript.new(genome())


# The active character's genome, or an empty Dictionary when there is none (the body then falls back to the average one).
static func genome() -> Dictionary:
	var one: Dictionary = Store.active()

	if not one.is_empty():
		return one["genome"]

	var legacy: String = FileAccess.get_file_as_string(LEGACY_PATH).strip_edges() if FileAccess.file_exists(LEGACY_PATH) else ""
	return Generator.decode(legacy) if legacy != "" else {}
