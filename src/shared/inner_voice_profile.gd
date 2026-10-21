class_name InnerVoiceProfile
extends RefCounted

# Which voice a character's inner voice speaks with (Dave 2026-10-21): compiled from the character's gender and traits, no pick
# screen. DESIGN_IDEAS 6.14: a veteran steadies themselves or jokes, a nervous apprentice thinks differently; heirs do not inherit it.
# The set id is "<family>_<temperament>_<n>":
#   family       masculine or feminine, from the gender the character creator stores (man/woman; any other value takes one of
#                the two by the character id, so it stays the same for that character)
#   temperament  steady when the mean of the traits named in inner_voice_sets.json (boldness, wisdom; 0..1) reaches steady_at,
#                nervous below it
#   n            which of the family's voices, from the character id, so two bold men do not sound the same
# The audio for a set lives in assets/audio/inner_voice/<set id>/<line id>.ogg (tools/gen_inner_voice.py).
# Pure and deterministic: the same character always gets the same set, on the server and on every client.

const SETS_PATH := "res://data/items/inner_voice_sets.json"
const DEFAULT_SET := "masculine_steady_0"

static var _config: Dictionary = {}


static func _cfg() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETS_PATH))
		_config = parsed if typeof(parsed) == TYPE_DICTIONARY else {"families": {}}

	return _config


static func _hash(character_id: String) -> int:
	return character_id.md5_text().substr(0, 6).hex_to_int()


# traits: trait name -> 0..1 (missing traits count as 0.5). gender: whatever the character creator calls it.
static func set_id(gender: String, traits: Dictionary, character_id: String) -> String:
	var cfg: Dictionary = _cfg()
	var families: Dictionary = cfg.get("families", {})

	if families.is_empty():
		return DEFAULT_SET

	var family_map: Dictionary = cfg.get("gender_families", {})
	var h: int = _hash(character_id)
	var family: String = str(family_map.get(gender.to_lower(), "masculine" if h % 2 == 0 else "feminine"))

	if not families.has(family):
		family = "masculine"

	var names: Array = cfg.get("temperament", {}).get("traits", [])
	var sum: float = 0.0

	for trait_name in names:
		sum += clampf(float(traits.get(trait_name, 0.5)), 0.0, 1.0)

	var level: float = sum / float(names.size()) if not names.is_empty() else 0.5
	var temperament: String = "steady" if level >= float(cfg.get("temperament", {}).get("steady_at", 0.5)) else "nervous"
	var voices: Array = families[family][temperament]
	return "%s_%s_%d" % [family, temperament, (h / 2) % voices.size()]


# Every set id the data defines (the generator and the checks walk these).
static func all_set_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	var families: Dictionary = _cfg().get("families", {})

	for family in families:
		for temperament in families[family]:
			for n in range((families[family][temperament] as Array).size()):
				ids.append("%s_%s_%d" % [family, temperament, n])

	return ids
