extends RefCounted

# The AI provider contract in code (/mnt/project-files/tech/AI_PROVIDER_CONTRACT.md; limits in data/npcs/ai_rules.json).
# build_request() is everything the game sends an AI provider; clean() is the only door an AI line passes through before it
# looks like any other line. A provider never touches the game: it gets a request dictionary and returns a line dictionary.

const RULES_PATH := "res://data/npcs/ai_rules.json"

static var _rules: Dictionary = {}


static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if typeof(parsed) == TYPE_DICTIONARY else {"max_chars": 320}

	return _rules


# What the game sends. Facts only, no secrets: persona and voice from data, what this NPC remembers of this player (flags and
# recent lines), what is around (hour, weather word, who else is near), the actions the server would accept right now, and the
# player's line (a chosen button text, or typed text later).
static func build_request(npc_id: String, persona: Dictionary, ctx: Dictionary, player_line: String, memory: Array) -> Dictionary:
	var r: Dictionary = rules()
	var facts: Array = ctx.get("facts", [])
	return {
		"version": 1,
		"npc": {"id": npc_id, "name": str(persona.get("name", npc_id)), "role": str(persona.get("role", "")), "persona": str(persona.get("persona", "")), "voice_id": str(persona.get("voice", npc_id))},
		"memory": memory.slice(maxi(memory.size() - int(r.get("max_memory_lines", 6)), 0)),
		"flags": ctx.get("flags", {}).keys(),
		"world": {"hour": float(ctx.get("hour", 12.0)), "facts": facts.slice(0, int(r.get("max_context_facts", 8)))},
		"allowed_actions": ctx.get("allowed_actions", []),
		"player_line": player_line.substr(0, 200),
	}


# Checks one AI reply against the request that produced it. Returns the clean line in the normal line shape, or {} when it must be
# dropped. Text is trimmed and stripped of control characters; the voice is always the NPC's own; speed and pitch (from mood or
# given) are clamped; effects survive only if the request listed exactly that action as allowed.
static func clean(request: Dictionary, reply: Dictionary) -> Dictionary:
	var r: Dictionary = rules()
	var text: String = ""

	for c in str(reply.get("text", "")):
		if c.unicode_at(0) >= 32 or c == " ":
			text += c

	text = text.strip_edges()
	var lower: String = text.to_lower()

	if text == "" or text.length() > int(r.get("max_chars", 320)) or text.split(" ", false).size() > int(r.get("max_words", 60)):
		return {}

	for bad in r.get("banned", []):
		if lower.contains(str(bad)):
			return {}

	var voice: String = str(request["npc"]["voice_id"])
	var mood: String = str(reply.get("mood", "neutral"))

	if not r.get("moods", ["neutral"]).has(mood):
		mood = "neutral"

	var span_s: Array = r.get("speed", [0.85, 1.15])
	var span_p: Array = r.get("pitch", [0.92, 1.08])
	var choices: Array = []

	for c in reply.get("choices", []):
		var label: String = str(c).strip_edges()

		if label != "" and label.length() <= int(r.get("max_choice_chars", 60)) and choices.size() < int(r.get("max_choices", 4)):
			choices.append(label)

	var effects: Array = []
	var allowed: Array = request.get("allowed_actions", [])

	for e in reply.get("effects", []):
		if allowed.has(e) and effects.size() < int(r.get("max_effects", 2)):
			effects.append(e)

	var ends: bool = bool(reply.get("end", choices.is_empty()))
	var map: Array = []

	for i in choices.size():
		map.append("ai")

	return {"text": text, "source": "ai", "voice_id": voice, "choices": choices, "map": map, "node": "ai", "end": ends or choices.is_empty(),
		"effects": effects, "mood": mood, "speed": clampf(float(reply.get("speed", 1.0)), float(span_s[0]), float(span_s[1])), "pitch": clampf(float(reply.get("pitch", 1.0)), float(span_p[0]), float(span_p[1]))}
