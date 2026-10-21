extends "res://src/stream/dialogue_provider.gd"

# Step C of the NPC system (items/NPC_DESIGN.md): sits between ServerDialogue and the providers. Today the only provider is the
# static one, so "auto" simply answers from data. When an AI provider is plugged in (set `ai`), it is tried first; failures feed a
# circuit breaker (3 in 30 s opens it for 60 s, one probe every 30 s while open) and while it is open the NPCs are unwell:
# one complaint, one or two small facts, then back to a bed or chair, and a short rest before talking again.
#
# Anti-flapping: the shown mode (static / ai / unwell) stays at least MIN_MODE_S seconds, and unwell is shown only after the
# breaker has been open UNWELL_AFTER_S seconds, so a hiccup never turns the whole town ill.
# mode (admin switch): "auto", "static" (never the AI), "ai" (AI or unwell, never silently static), "down" (pretend the AI is dead).

const FAILS_TO_OPEN := 3
const FAIL_WINDOW_S := 30.0
const OPEN_S := 60.0
const PROBE_S := 30.0
const MIN_MODE_S := 60.0
const UNWELL_AFTER_S := 10.0
const REST_MIN := 2.0       # game minutes before an unwell NPC talks again, +/- up to REST_MAX
const REST_MAX := 5.0

var static_provider         # StaticProvider, always there
var ai                      # a DialogueProvider or null (not built yet)
var mode: String = "auto"
var now_s: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0

var _fails: Array = []
var _outage_since: float = -1.0
var _open_since: float = -1.0
var _open_until: float = 0.0
var _last_probe: float = -1000.0
var _shown: String = "static"
var _shown_since: float = -1000.0
var _rest_until: Dictionary = {}   # "key|npc" -> game hour (float, may exceed 24) until which the NPC rests


func setup(provider) -> void:
	static_provider = provider


# The AI call reports how it went (the AI provider is async later; it calls this when a request ends or times out).
func report(ok: bool) -> void:
	var t: float = float(now_s.call())

	if ok:
		_fails.clear()
		_open_since = -1.0
		_open_until = 0.0
		return

	_fails.append(t)

	while not _fails.is_empty() and t - float(_fails[0]) > FAIL_WINDOW_S:
		_fails.pop_front()

	if _fails.size() >= FAILS_TO_OPEN and _open_since < 0.0:
		_open_since = t
		_open_until = t + OPEN_S


func breaker_open() -> bool:
	if mode == "down":
		return true

	return _open_since >= 0.0


# What players see now: "static", "ai" or "unwell", held for at least MIN_MODE_S.
func shown_mode() -> String:
	var t: float = float(now_s.call())

	if _shown_since < -999.0:
		_shown_since = t

	var down: bool = mode != "static" and (breaker_open() or (ai == null and (mode == "ai" or mode == "down")))

	if not down:
		_outage_since = -1.0
	elif _outage_since < 0.0:
		_outage_since = _open_since if _open_since >= 0.0 else t

	var want: String = "static"

	if mode == "static" or (ai == null and not down):
		want = "static"
	elif down:
		want = "unwell" if t - _outage_since >= UNWELL_AFTER_S else _shown
	else:
		want = "ai"

	if want != _shown and t - _shown_since >= MIN_MODE_S:
		_shown = want
		_shown_since = t

	return _shown


func bark(npc_id: String, kind: String, ctx: Dictionary) -> String:
	return static_provider.bark(npc_id, kind, ctx)


func is_unwell() -> bool:
	return shown_mode() == "unwell"


func _can_probe() -> bool:
	var t: float = float(now_s.call())

	if t >= _open_until and t - _last_probe >= PROBE_S:
		_last_probe = t
		return true

	return false


func open(npc_id: String, ctx: Dictionary) -> Dictionary:
	var shown: String = shown_mode()

	if shown == "ai" and ai != null:
		var line: Dictionary = ai.open(npc_id, ctx)

		if line.is_empty():
			report(false)
			return static_provider.open(npc_id, ctx)

		report(true)
		return line

	if shown == "unwell":
		if ai != null and breaker_open() and _can_probe() and not ai.open(npc_id, {"probe": true}).is_empty():
			report(true)

		return _unwell_line(npc_id, ctx)

	return static_provider.open(npc_id, ctx)


func choose(npc_id: String, node: String, choice: int, map: Array, ctx: Dictionary) -> Dictionary:
	if shown_mode() == "ai" and ai != null:
		var line: Dictionary = ai.choose(npc_id, node, choice, map, ctx)

		if not line.is_empty():
			return line

		report(false)

	return static_provider.choose(npc_id, node, choice, map, ctx)


# Unwell: a complaint plus one or two small facts, once, then a rest. Lines are authored per NPC role (barks complaint, info,
# cooldown in the NPC's dialogue file), never repeating within the last five.
func _unwell_line(npc_id: String, ctx: Dictionary) -> Dictionary:
	var hour: float = float(ctx.get("hour", 12.0))
	var rest_key: String = str(ctx.get("rest_key", npc_id))
	var until: float = float(_rest_until.get(rest_key, -1.0))
	var voice: String = str(static_provider.trees.get(npc_id, {}).get("voice", npc_id))

	if until > hour and until - hour < 6.0:
		return _bare(static_provider.bark(npc_id, "cooldown", ctx), voice)

	var text: String = static_provider.bark(npc_id, "complaint", ctx)
	var info: String = static_provider.bark(npc_id, "info", ctx)

	if info != "":
		text += " " + info

	if randf() < 0.4:
		var more: String = static_provider.bark(npc_id, "info", ctx)

		if more != "" and more != info:
			text += " " + more

	_rest_until[rest_key] = hour + randf_range(REST_MIN, REST_MAX) / 60.0
	return _bare(text, voice)


func _bare(text: String, voice: String) -> Dictionary:
	return {"text": text, "source": "static", "voice_id": voice, "choices": [], "map": [], "node": "", "end": true, "effects": []}
