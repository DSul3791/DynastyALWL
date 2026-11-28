extends SceneTree

# The status strip left of the hotbar (Dave 23 Nov 2026; src/client/status_icons.gd, data/ui/status_strip.json): every data row has a glyph
# the art kit draws and words for each tone; symbols show and hide from their reads, line up right-aligned against the hotbar, never reach
# its tray or leave the canvas even with every symbol at once; the hover words fill in their numbers; a symbol that appears names itself,
# but not in the first seconds after joining; food and water only below 10%; the older add_icon still works. On the server, soak (protocol 165) is sent at hello, again
# when the clothes get wetter in steps of 10, and not while nothing changes.
#   godot --headless --path . --script res://src/worldgen/tools/test_status_strip.gd

const StatusIcons := preload("res://src/client/status_icons.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")
const ComfortBadge := preload("res://src/client/ui/comfort_badge.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	_client_side()
	_server_side()
	print("Test done: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _client_side() -> void:
	var strip = StatusIcons.new()
	var spec: Dictionary = strip.spec
	check(spec.size() >= 16, "the data has a row for each symbol (%d)" % spec.size())
	var no_glyph: Array = []
	var no_words: Array = []

	for id in spec:
		var row: Dictionary = spec[id]

		if id != "inspection" and not ArtKit.has_glyph(str(row.get("glyph", ""))):
			no_glyph.append(id)

		if str(row.get("name", "")) == "" or (str(row.get("line", "")) == "" and (row.get("lines", {}) as Dictionary).is_empty()):
			no_words.append(id)

	check(no_glyph.is_empty(), "every symbol's glyph is drawn by the art kit (missing: %s)" % str(no_glyph))
	check(int(spec["hunger"].get("show_below", 0)) == 10 and int(spec["thirst"].get("show_below", 0)) == 10 and not bool(spec["hunger"].get("always", false)), "food and water show only below 10%")
	check(str(spec["load"]["lines"]["1"]).contains("{p}% of what you can carry"), "the heavy load's number is the load's share of what you can carry, not the speed")
	check(ArtKit.has_glyph("comfort_fire") and str(spec["comfort"].get("glyph", "")) == "comfort_fire", "the comfort meter is a campfire, not a drop")
	check(no_words.is_empty(), "every symbol has a name and hover words (missing: %s)" % str(no_words))
	check(strip.position.x + strip.size.x <= ArtKit.HOTBAR_TRAY.position.x and is_equal_approx(strip.size.y, float(ArtKit.HOT)) and is_equal_approx(strip.position.y, ArtKit.HOTBAR_STRIP.position.y),
		"the strip ends left of the hotbar's tray, level with its slots and as tall")

	var state: Dictionary = {"hunger": 8, "thirst": 5, "limp": 1.0, "picture": false}
	strip.add("hunger", func() -> Dictionary: return {} if int(state["hunger"]) >= 10 else {"value": "%d%%" % state["hunger"], "tone": 1, "vars": {"n": state["hunger"]}})
	strip.add("thirst", func() -> Dictionary: return {} if int(state["thirst"]) >= 10 else {"value": "%d%%" % state["thirst"], "tone": 1, "vars": {"n": state["thirst"]}})
	strip.add("limp", func() -> Dictionary: return {} if float(state["limp"]) >= 1.0 else {"tone": 1, "vars": {"n": int(round(float(state["limp"]) * 100.0)), "min": 10, "heal": 60}})
	strip.add_icon("inspection", ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8)), func() -> bool: return bool(state["picture"]))
	strip.tick(0.0, true)
	check(strip.shown() == ["hunger", "thirst"], "at first only hunger and thirst show (%s)" % str(strip.shown()))
	check(strip.get_children().filter(func(n: Node) -> bool: return n is Label).is_empty(), "the first look after joining names nothing")
	check(strip.tip_of("thirst") == "Water 5%: you are low on water. Drink fresh water soon.", "the hover words take the tone and the number ('%s')" % strip.tip_of("thirst"))
	check(strip.cell_of("hunger").tooltip_text == "Food 8%: you are low on food. Eat soon.", "and are the symbol's tooltip")
	var thirst_cell: Control = strip.cell_of("thirst")
	check(is_equal_approx(thirst_cell.position.x + thirst_cell.size.x, strip.size.x) and is_equal_approx(thirst_cell.size.y, float(ArtKit.HOT)), "thirst sits next to the hotbar at full height")

	strip._quiet_until_msec = 0   # the join's first state is in
	state["limp"] = 0.5
	strip.tick(0.1)
	check(strip.shown() == ["hunger", "thirst"], "a read is not asked again within a quarter second")
	strip.tick(0.2)
	check(strip.shown() == ["limp", "hunger", "thirst"], "the injured leg shows, left of hunger and thirst (%s)" % str(strip.shown()))
	var tip: String = strip.tip_of("limp")
	check(tip.contains("50%") and tip.contains("splint") and not tip.contains("{"), "its hover line says how slow and what fixes it ('%s')" % tip)
	var notes: Array = strip.get_children().filter(func(n: Node) -> bool: return n is Label)
	check(notes.size() == 1 and (notes[0] as Label).text == "Injured leg", "and it names itself as it appears")
	state["limp"] = 1.0
	state["hunger"] = 6
	strip.tick(0.0, true)
	check(strip.shown() == ["hunger", "thirst"] and strip.tip_of("hunger").begins_with("Food 6%"), "healed, it goes; hunger follows its number")
	state["hunger"] = 40
	strip.tick(0.0, true)
	check(strip.shown() == ["thirst"], "food at 10% or more is not shown (Dave 24 Nov 2026)")
	state["hunger"] = 8
	strip.tick(0.0, true)
	state["picture"] = true
	strip.tick(0.0, true)
	check(strip.shown().has("inspection"), "add_icon still shows a picture while its test says so")

	# The comfort meter draws itself: the strip takes it into the row, just left of hunger and thirst.
	var badge: Control = ComfortBadge.new()
	strip.add_control("comfort", badge, func() -> Dictionary: return {"tone": 0})
	strip.tick(0.0, true)
	var order: Array = strip.shown()
	check(badge.get_parent() == strip and order.slice(order.size() - 3) == ["comfort", "hunger", "thirst"], "the comfort meter sits in the row before hunger and thirst (%s)" % str(order))

	# Every symbol at once: all of them stay between the canvas edge and the hotbar's tray, none on another; past one row they wrap upward.
	state["limp"] = 0.5
	for id in spec:
		if not strip._entries.has(id):
			strip.add(id, func() -> Dictionary: return {"value": "99%", "tone": 2, "vars": {}})

	strip.tick(0.0, true)
	var ids: Array = strip.shown()
	var inside: bool = true
	var rects: Array = []

	for id in ids:
		var cell: Control = strip.cell_of(id)
		var rect: Rect2 = Rect2(strip.position + cell.position, cell.size * cell.scale)
		inside = inside and rect.position.x >= 0.0 and rect.end.x <= ArtKit.HOTBAR_TRAY.position.x and rect.position.y >= 0.0 and rect.end.y <= ArtKit.HOTBAR_STRIP.end.y and cell.size.x * cell.scale.x >= StatusIcons.MIN_CELL - 0.01

		for other in rects:
			inside = inside and not (other as Rect2).intersects(rect)

		rects.append(rect)

	var bottom: Control = strip.cell_of("thirst")
	check(ids.size() == spec.size() and inside and is_equal_approx(bottom.position.y + bottom.size.y, float(ArtKit.HOT)),
		"all %d symbols at once fit left of the tray, none on another, thirst still in the bottom row (%.0f px each)" % [ids.size(), bottom.size.x])
	strip.free()


func _server_side() -> void:
	var dir: String = "user://test_status_strip"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var weather: Array = [{"temp_c": 15.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}]
	var sent: Array = []
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.send_warmth = func(_p, _pct): pass
	items.send_sick = func(_p, _h): pass
	items.send_thought = func(_p, _id, _text, _kind): pass
	items.send_soak = func(p, percent, windy): sent.append([p, percent, windy])
	items.weather_now = func(): return weather[0]
	items.setup(ItemTableScript.load_default(), dir)
	items._hints_loaded = true
	items._hints = []
	items.peer_connected_hello(1, "strip0000001")
	items.report_position(1, Vector3(10.0, 0.0, 10.0))
	check(sent.size() == 1 and sent[0] == [1, 0, false], "hello sends dry clothes (%s)" % str(sent))
	var v: Dictionary = items.vitals_of(1)
	items._warmth_tick(1, v, 1.0, 1.0)
	check(sent.size() == 1, "nothing more while nothing changes")
	weather[0] = {"temp_c": 15.0, "wind": 0.0, "rain": 1.0, "snow": 0.0}
	items._warmth_tick(1, v, 60.0, 600.0)
	check(sent.size() == 2 and int(sent[1][1]) > 0 and int(sent[1][1]) % 10 == 0, "rain on an open player sends a wetter soak in steps of 10 (%s)" % str(sent))
	items._soak[1] = 0.62
	items._sync_soak(1, false)
	var count: int = sent.size()
	items._soak[1] = 0.64
	items._sync_soak(1, false)
	check(sent.size() == count and int(sent[-1][1]) == 60, "a change inside the same step of 10 sends nothing")
