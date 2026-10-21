extends SceneTree

# The AI provider contract (tech/AI_PROVIDER_CONTRACT.md): the stub goes through request, guard and router like a real provider.
#   godot --headless --path . --script res://src/worldgen/tools/test_ai_contract.gd

const StaticProvider := preload("res://src/stream/static_provider.gd")
const Router := preload("res://src/stream/dialogue_router.gd")
const Stub := preload("res://src/stream/stub_ai_provider.gd")
const Guard := preload("res://src/stream/ai_guard.gd")

var failures: int = 0
var clock: float = 1000.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var statics = StaticProvider.new()
	statics.load_dir()
	var router = Router.new()
	router.setup(statics)
	router.now_s = func(): return clock
	var stub = Stub.new()
	stub.persona_of = func(id): return {"name": id.capitalize(), "role": "smith", "persona": "gruff, honest", "voice": id}
	router.ai = stub
	var ctx: Dictionary = {"flags": {"met": true}, "hour": 9.0, "recent": [], "facts": ["raining"], "allowed_actions": [{"set_flag": "ai_friend"}]}

	# Same shape: an AI line and a prebaked line carry the same keys, so the speech path cannot tell them apart.
	router.mode = "auto"
	var static_line: Dictionary = statics.open("hob", ctx)
	router.shown_mode()
	clock += 120.0
	var ai_line: Dictionary = router.open("hob", ctx)
	check(ai_line.get("source", "") == "ai", "auto mode with an AI plugged in asks the AI")

	for key in static_line:
		check(ai_line.has(key), "an AI line has the key %s every static line has" % key)

	check(ai_line["voice_id"] == "hob" and float(ai_line["speed"]) == 1.0, "voice id is the NPC's own, speed 1.0 by default")
	var req: Dictionary = stub.requests[0]
	check(req["npc"]["id"] == "hob" and req["world"]["hour"] == 9.0 and req["flags"].has("met") and req["allowed_actions"].size() == 1, "the request carries persona, flags, hour and allowed actions")

	# The guard.
	var base: Dictionary = Guard.build_request("hob", {"name": "Hob", "voice": "hob"}, ctx, "hello", [])
	check(Guard.clean(base, {"text": "Visit www.example.com now"}).is_empty(), "links are dropped")
	check(Guard.clean(base, {"text": "As an AI I cannot"}).is_empty(), "out of world talk is dropped")
	check(Guard.clean(base, {"text": ""}).is_empty() and Guard.clean(base, {"text": "x".repeat(400)}).is_empty(), "empty and too long lines are dropped")
	var wild: Dictionary = Guard.clean(base, {"text": "Fine day.", "voice_id": "evil", "speed": 5.0, "pitch": 0.1, "mood": "furious", "effects": [{"give_item": ["gold", 99]}, {"set_flag": "ai_friend"}]})
	check(wild["voice_id"] == "hob", "a provider cannot pick another voice")
	check(wild["speed"] == 1.15 and wild["pitch"] == 0.92 and wild["mood"] == "neutral", "speed and pitch are clamped, unknown moods become neutral")
	check(wild["effects"] == [{"set_flag": "ai_friend"}], "only actions the request allowed survive (no free items)")

	# Outage: failures open the breaker and the town is unwell, then recovery.
	stub.fail = true

	for i in 3:
		clock += 5.0
		var l: Dictionary = router.open("hob", ctx)
		check(l.get("source", "") != "ai", "an outage never shows an AI line")

	check(router.breaker_open(), "three failures open the breaker")
	clock += 200.0
	router.open("hob", ctx)
	check(router.is_unwell(), "after the outage grace the NPCs are unwell")
	stub.fail = false
	clock += 70.0
	router.open("hob", ctx)
	clock += 70.0
	router.open("hob", ctx)
	check(not router.breaker_open(), "a successful probe closes the breaker")

	print("ai contract: %d failures" % failures)
	quit(failures)
