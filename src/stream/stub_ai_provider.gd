extends "res://src/stream/dialogue_provider.gd"

# A stand-in AI provider (contract: /mnt/project-files/tech/AI_PROVIDER_CONTRACT.md). It answers from canned text but goes through
# the same request, guard and router path a real provider will, so the whole route can be tested before any AI exists.
# Set `fail` to simulate an outage, `reply_override` to feed odd replies to the guard. `requests` keeps what it was sent.

const Guard := preload("res://src/stream/ai_guard.gd")

var fail: bool = false
var reply_override: Dictionary = {}
var requests: Array = []
var persona_of: Callable          # (npc id) -> {name, role, persona, voice}; the server supplies it from data/npcs

var _canned: Dictionary = {
	"hob": ["Aye, the fire wants wood and the day is short.", "Mind the frost, friend. It bites the careless."],
	"edda": ["Keep your guard high and your temper low.", "Come back when your arm is steadier."]}
var _n: int = 0


func available() -> bool:
	return not fail


func open(npc_id: String, ctx: Dictionary) -> Dictionary:
	return _answer(npc_id, ctx, "")


func choose(npc_id: String, _node: String, choice: int, map: Array, ctx: Dictionary) -> Dictionary:
	return _answer(npc_id, ctx, str(ctx.get("choice_texts", [])[choice]) if choice >= 0 and choice < ctx.get("choice_texts", []).size() else "")


func _answer(npc_id: String, ctx: Dictionary, player_line: String) -> Dictionary:
	var persona: Dictionary = persona_of.call(npc_id) if persona_of.is_valid() else {"name": npc_id, "voice": npc_id}
	var request: Dictionary = Guard.build_request(npc_id, persona, ctx, player_line, ctx.get("recent_text", []))
	requests.append(request)

	if fail or ctx.has("probe") and fail:
		return {}

	if ctx.has("probe"):
		return {"text": "ok", "source": "ai", "voice_id": npc_id, "choices": [], "map": [], "node": "ai", "end": true, "effects": []}

	var reply: Dictionary = reply_override
	var lines: Array = _canned.get(npc_id, ["Hmm."])

	if reply.is_empty():
		_n += 1
		reply = {"text": lines[_n % lines.size()], "mood": "neutral", "choices": ["Farewell."], "end": false}

	return Guard.clean(request, reply)
