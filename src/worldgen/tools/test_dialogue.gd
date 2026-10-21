extends SceneTree

# Classic NPC talk, step B: validates every dialogue file (reachable nodes, valid effects and conditions, short sentences, a
# complaint pool of eight for the unwell fallback) and plays Hob's quest through the server.
#   godot --headless --path . --script res://src/worldgen/tools/test_dialogue.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const NpcsScript := preload("res://src/stream/server_npcs.gd")
const DialogueScript := preload("res://src/stream/server_dialogue.gd")
const SkillWebScript := preload("res://src/shared/skill_web.gd")
const StaticProvider := preload("res://src/stream/static_provider.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const COND_KEYS := ["flag", "flag_not", "hour_between", "has_item", "can_train"]
const EFFECT_KEYS := ["set_flag", "clear_flag", "give_item", "take_item", "train_skill"]
const BARKS := ["greeting", "farewell", "idle", "complaint", "cooldown"]

var failures: int = 0
var said: Array = []
var hour: float = 12.5


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func words_ok(text: String) -> bool:
	for sentence in text.replace("!", ".").replace("?", ".").split("."):
		if sentence.strip_edges().split(" ", false).size() > 14:
			return false

	return true


func validate(table) -> void:
	var provider = StaticProvider.new()
	provider.load_dir()
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/npcs.json"))

	for npc in cfg["npcs"]:
		var id: String = str(npc["id"])
		check(provider.has_npc(id), "%s has a dialogue file" % id)

		if not provider.has_npc(id):
			continue

		var tree: Dictionary = provider.trees[id]

		for kind in BARKS:
			check(not tree.get("barks", {}).get(kind, []).is_empty(), "%s has %s barks" % [id, kind])
			for line in tree.get("barks", {}).get(kind, []):
				check(words_ok(str(line)) and str(line).length() <= 100, "%s bark short enough: %s" % [id, line])

		check(tree.get("barks", {}).get("complaint", []).size() >= 8, "%s has a complaint pool of eight or more" % id)
		var nodes: Dictionary = tree.get("nodes", {})
		var seen: Dictionary = {}
		var queue: Array = []

		for root in tree.get("roots", []):
			check(nodes.has(str(root.get("node", ""))), "%s root node exists" % id)
			queue.append(str(root.get("node", "")))

			for key in root.get("if", {}):
				check(COND_KEYS.has(key), "%s root condition %s is known" % [id, key])

		while not queue.is_empty():
			var node_id: String = queue.pop_back()

			if seen.has(node_id) or not nodes.has(node_id):
				continue

			seen[node_id] = true

			for c in nodes[node_id].get("choices", []):
				var go: String = str(c.get("goto", "end"))
				check(go == "end" or nodes.has(go), "%s.%s goes to a real node (%s)" % [id, node_id, go])
				queue.append(go)

				for key in c.get("if", {}):
					check(COND_KEYS.has(key), "%s.%s condition %s is known" % [id, node_id, key])

		for node_id in nodes:
			var node: Dictionary = nodes[node_id]
			check(seen.has(node_id), "%s.%s is reachable" % [id, node_id])
			check(bool(node.get("end", false)) or not node.get("choices", []).is_empty(), "%s.%s is not a dead end" % [id, node_id])
			var raw: Variant = node.get("text", "")

			for line in (raw if typeof(raw) == TYPE_ARRAY else [raw]):
				check(str(line).begins_with("$") or (words_ok(str(line)) and str(line).length() <= 140), "%s.%s line short enough" % [id, node_id])

			for e in node.get("effects", []):
				var known: bool = false

				for k in EFFECT_KEYS:
					known = known or e.has(k)

				check(known, "%s.%s effect is known" % [id, node_id])

				for k in ["give_item", "take_item"]:
					if e.has(k):
						check(table.number_of(str(e[k][0])) > 0 and int(e[k][1]) >= 1 and int(e[k][1]) <= 5, "%s.%s %s is a real item, 1 to 5" % [id, node_id, k])


func _init() -> void:
	var table = ItemTableScript.load_default()
	validate(table)

	var dir: String = "user://test_dialogue"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(table, dir)
	items.peer_connected_hello(1, "talk-key-000001")
	var npcs = NpcsScript.new()
	NpcsScript.test_hold_off = true
	npcs.hour_now = func(): return hour
	npcs.ground_height = func(_x, _z): return 10.0
	npcs.player_positions = func(): return items.peer_positions()
	npcs.setup(dir)
	var talk = DialogueScript.new()
	talk.items = items
	talk.npcs = npcs
	talk.hour_now = func(): return hour
	talk.send_say = func(peer, id, npc_name, text, voice, choices, ends): said.append({"peer": peer, "id": id, "name": npc_name, "text": text, "voice": voice, "choices": choices, "ends": ends})
	talk.setup(dir)

	# Far from everyone nothing is placed; the player walks up to Hob's chair at 12:30.
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	npcs.tick(0.2)
	talk.talk(1, "hob", -1)
	check(said.is_empty(), "too far from the NPC: no answer")
	items.report_position(1, Vector3(npcs.markers["chair_1"]["x"] + 1.0, 10.0, npcs.markers["chair_1"]["z"]))
	npcs.tick(0.2)
	npcs.tick(0.2)
	check(npcs.npcs["hob"]["placed"], "Hob is placed once the player is near")
	talk.talk(1, "nobody", -1)
	check(said.is_empty(), "an unknown NPC gets no answer")
	talk.talk(1, "hob", -1)
	check(said.size() == 1 and str(said[0]["text"]).contains("Hob") and said[0]["choices"].size() == 3 and not said[0]["ends"], "the first talk introduces Hob with three choices")
	check(talk.flags_of("talk-key-000001", "hob").has("met"), "meeting him sets the flag")
	talk.talk(1, "hob", 0)
	check(said.size() == 1, "a second request inside a quarter second is ignored")
	talk._last_msec.clear()
	talk.talk(1, "hob", 2)
	check(said.size() == 2 and bool(said[1]["ends"]) and str(said[1]["text"]) != "", "Goodbye ends with a farewell bark")

	# Second visit: the shorter greeting and the quest choices.
	talk._last_msec.clear()
	talk.talk(1, "hob", -1)
	var again: Dictionary = said.back()
	check(again["choices"].size() == 4 and str(again["choices"][2]).contains("help"), "a known visitor is offered the quest")
	talk._last_msec.clear()
	talk.talk(1, "hob", 2)
	check(talk.flags_of("talk-key-000001", "hob").has("quest_firewood"), "taking the quest sets its flag")
	talk._last_msec.clear()
	talk.talk(1, "hob", 0)   # I will.
	talk._last_msec.clear()
	talk.talk(1, "hob", -1)
	var texts: Array = []

	for choice in said.back()["choices"]:
		texts.append(str(choice))

	check(texts.has("About the firewood...") and not texts.has("I have your firewood.") and not texts.has("Can I help with anything?"), "with the quest open and no wood he only reminds you (%s)" % str(texts))

	# Hand over the wood.
	items.action(1, Net.ACT_ADMIN_GIVE, table.number_of("firewood"), 0, 3, Vector3.ZERO)
	talk._last_msec.clear()
	talk.talk(1, "hob", 0)
	talk._last_msec.clear()
	talk.talk(1, "hob", -1)
	var idx: int = -1
	var c: Array = said.back()["choices"]

	for i in c.size():
		if str(c[i]) == "I have your firewood.":
			idx = i

	check(idx >= 0, "with three firewood the handing-over choice appears")
	talk._last_msec.clear()
	talk.talk(1, "hob", idx)
	check(items.count_for(1, "firewood") == 0 and items.count_for(1, "roast_forage") == 2, "he takes three firewood and gives two roasted forage")
	check(talk.flags_of("talk-key-000001", "hob").has("quest_firewood_done"), "the quest is marked done")
	talk._last_msec.clear()
	talk.talk(1, "hob", 0)
	talk._last_msec.clear()
	talk.talk(1, "hob", -1)
	check(not str(said.back()["choices"]).contains("help") and not str(said.back()["choices"]).contains("firewood"), "after it is done the quest does not come back")

	# Trainer: Hob teaches trades once the pupil is near the cap, for three stones.
	talk._last_msec.clear()
	talk.talk(1, "hob", -1)
	check(not str(said.back()["choices"]).contains("Teach me"), "a beginner is not offered the lesson")
	var rec: Dictionary = items._skill_records(1)
	rec["trades"] = {"p": SkillWebScript.units_for(items._skills_cfg, "trades", 22.0), "peak": 0.0, "t": 0}
	check(items.npc_train(1, "trades", 1, "stone", 3, true) == "not enough to pay", "near the cap but no stones: cannot pay")
	items.action(1, Net.ACT_ADMIN_GIVE, table.number_of("stone"), 0, 3, Vector3.ZERO)
	check(items.npc_train(1, "trades", 0, "stone", 3, true) != "", "a trainer who only teaches level 0 refuses")
	talk._last_msec.clear()
	talk.talk(1, "hob", -1)
	var tidx: int = -1

	for i in said.back()["choices"].size():
		if str(said.back()["choices"][i]) == "Teach me the trade.":
			tidx = i

	check(tidx >= 0, "with the stones and the skill the lesson is offered")
	talk._last_msec.clear()
	talk.talk(1, "hob", tidx)
	check(int(items._skill_records(1)["trades"]["t"]) == 1 and items.count_for(1, "stone") == 0, "the lesson raises the training level and takes the stones")
	check(items.npc_train(1, "trades", 1, "stone", 3, true) != "", "training twice in a row is refused")

	# Flags survive a restart.
	var talk2 = DialogueScript.new()
	talk2.items = items
	talk2.npcs = npcs
	talk2.setup(dir)
	check(talk2.flags_of("talk-key-000001", "hob").has("quest_firewood_done"), "flags are saved")

	# A pick from a stale line (no session) is ignored; walking away drops the talk.
	talk._sessions.clear()
	var before: int = said.size()
	talk._last_msec.clear()
	talk.talk(1, "hob", 0)
	check(said.size() == before, "a choice with no open talk is ignored")

	# Barks are not repeated within the last five.
	var provider = talk.provider
	var ctx: Dictionary = {"recent": []}
	var seen: Dictionary = {}

	for n in 4:
		seen[provider.bark("hob", "greeting", ctx)] = true

	check(seen.size() == 4, "four greetings in a row are four different lines (%d)" % seen.size())

	# The router (step C): static while no AI, unwell when the AI is down (after the anti-flap wait), complaint then rest.
	var router = talk.router
	var clock: Array = [1000.0]
	router.now_s = func() -> float: return clock[0]
	check(router.shown_mode() == "static" and not router.is_unwell(), "with no AI the router answers from data")
	router.mode = "down"
	check(router.shown_mode() == "static", "a fresh outage is not shown at once (anti-flap)")
	clock[0] += 61.0
	check(router.shown_mode() == "unwell" and router.is_unwell(), "after the wait the NPCs are unwell")
	var sick: Dictionary = router.open("hob", {"recent": [], "hour": 10.0, "rest_key": "hob|a"})
	var complaints: Array = router.static_provider.trees["hob"]["barks"]["complaint"]
	var said: bool = false

	for line_text in complaints:
		said = said or str(sick["text"]).begins_with(str(line_text))

	check(said and bool(sick["end"]) and sick["choices"].is_empty(), "unwell: a complaint, no choices, the talk ends")
	var again_line: Dictionary = router.open("hob", {"recent": [], "hour": 10.01, "rest_key": "hob|a"})
	check(router.static_provider.trees["hob"]["barks"]["cooldown"].has(again_line["text"]), "and he rests before talking again")
	var later: Dictionary = router.open("hob", {"recent": [], "hour": 10.2, "rest_key": "hob|a"})
	check(not router.static_provider.trees["hob"]["barks"]["cooldown"].has(later["text"]), "after a few game minutes he talks again")
	router.mode = "auto"
	clock[0] += 5.0
	check(router.shown_mode() == "unwell", "recovery waits out the minimum mode time too")
	clock[0] += 61.0
	check(router.shown_mode() == "static", "then he is well again")

	# The breaker: 3 failures in 30 s open it, a success closes it.
	var ai_stub = load("res://src/stream/dialogue_provider.gd").new()
	router.ai = ai_stub
	router.report(false)
	router.report(false)
	check(not router.breaker_open(), "two failures do not open it")
	router.report(false)
	check(router.breaker_open(), "three failures in 30 s open it")
	router.report(true)
	check(not router.breaker_open(), "a success closes it")
	clock[0] += 100.0
	router.report(false)
	clock[0] += 31.0
	router.report(false)
	router.report(false)
	check(not router.breaker_open(), "failures older than 30 s do not count")

	print("dialogue tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
