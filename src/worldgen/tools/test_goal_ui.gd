extends SceneTree

# The client side of the goals (protocol 119; docs/design/PLAYER_JOURNAL_GOALS_UI.md, GOALS-REPAIR WP-GUIDE-UI): the goal book keeps the server's list,
# a rejoin's list is silent and a goal_done announces once; the upper-right Goals box shows the first two unfinished titles in the authored order (one
# when one is left, hidden when none); the Goal Achieved placard queues completions one at a time, fits a long name, finds Dave's art and the fanfare,
# and takes no input. Looks, motion and sound are for the eye and ear (NEEDS PLAYER VERIFICATION); this checks the logic.
#   godot --headless --path . --script res://src/worldgen/tools/test_goal_ui.gd

const GoalBook := preload("res://src/client/ui/goals/goal_book.gd")
const GoalsHud := preload("res://src/client/ui/goals/goals_hud.gd")
const GoalPlacard := preload("res://src/client/ui/goals/goal_placard.gd")
const Journal := preload("res://src/client/ui/goals/journal_view.gd")
const ViewScript := preload("res://src/client/inventory_view.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Bindings := preload("res://src/client/key_bindings.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func row(id: String, title: String, done: bool, after: Array = [], copper: int = 3) -> Array:
	return [id, title, "How to " + title, copper, "", 0, PackedStringArray(after), done]


func _key(code: int, ctrl: bool = false, shift: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.pressed = true
	return event


# Every Label's and Button's text under `node`.
func _collect(node: Node, into: Array) -> void:
	for child in node.get_children():
		if (child is Label or child is Button) and child.is_visible_in_tree():
			into.append(str(child.text))

		_collect(child, into)


func _init() -> void:
	var net: Node = Net.new()
	var methods: Array = net.get_method_list().map(func(m): return str(m["name"]))
	net.free()
	check(Net.PROTOCOL_VERSION >= 119 and methods.has("goals") and methods.has("goal_done"), "protocol 119 carries goals and goal_done (%d)" % Net.PROTOCOL_VERSION)

	# The book.
	var book = GoalBook.new()
	var heard: Array = []
	var changes: Array = [0]
	book.achieved.connect(func(r, copper): heard.append([r["id"], copper]))
	book.changed.connect(func(): changes[0] += 1)
	book.on_goals([row("drink", "Drink at the water", true), row("fibre", "Gather plant fibre", false), row("twine", "Twist twine", false, ["fibre"]), row("axe", "Make a Stone - Axe", false, ["twine"])])
	check(book.rows.size() == 4 and heard.is_empty() and changes[0] == 1, "the join's list fills the book silently, done goals included")
	check(GoalsHud.titles(book) == PackedStringArray(["Gather plant fibre", "Twist twine"]), "the box shows the first two unfinished goals in the authored order (%s)" % str(GoalsHud.titles(book)))
	book.on_done("twine", 0)
	check(heard == [["twine", 0]] and bool(book.row("twine")["done"]), "a goal_done out of order marks it done and announces it")
	check(GoalsHud.titles(book) == PackedStringArray(["Gather plant fibre", "Make a Stone - Axe"]), "and the box moves on to the next unfinished one (%s)" % str(GoalsHud.titles(book)))
	book.on_done("twine", 0)
	check(heard.size() == 1, "a repeated goal_done is not announced again")
	book.on_goals([row("drink", "Drink at the water", true), row("fibre", "Gather plant fibre", true), row("twine", "Twist twine", true), row("axe", "Make a Stone - Axe", false)])
	check(heard.size() == 1 and GoalsHud.titles(book) == PackedStringArray(["Make a Stone - Axe"]), "a rejoin's list replays nothing; one goal left shows one title")
	book.on_done("axe", 5)
	check(GoalsHud.titles(book).is_empty() and book.done_count() == 4, "with every goal done the box has nothing to show")
	book.on_done("unknown_goal", 2)
	check(heard[-1] == ["unknown_goal", 2], "a goal_done for a goal not in the list is still announced once (by its id)")
	check(book.row("twine")["after"] == PackedStringArray(["fibre"]) and str(book.row("twine")["howto"]) == "How to Twist twine", "a row keeps its how-to and the goals taught first (the Journal's links)")

	# The placard: in the tree, under a view that only lends its coin line and item table.
	var view = ViewScript.new()
	view.table = preload("res://src/shared/item_table.gd").load_default()
	var placard = GoalPlacard.new()
	root.add_child(placard)
	placard.setup(view, book)
	check(placard.mouse_filter == Control.MOUSE_FILTER_IGNORE and placard._card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the placard takes no mouse input")
	check(placard.get_child(0).get_child(0).texture != null, "Dave's blank Goal Achieved art loads (%s)" % GoalPlacard.ART)
	check(placard._fanfare != null, "the fanfare is found (assets/audio/ui/ui_goal_0.ogg)")
	var credits: String = FileAccess.get_file_as_string("res://assets/audio/CREDITS.csv")
	check(credits.contains("ui/ui_goal_*") and credits.contains("own-made"), "the fanfare has its own-made credits row")
	book.on_goals([row("a", "First", false), row("b", "Second", false), row("c", "Third", false, [], 0)])
	book.rows[2]["item"] = "stick"
	book.rows[2]["item_n"] = 4
	book.on_done("a", 3)
	book.on_done("b", 12)
	book.on_done("c", 0)
	check(placard.showing and placard.shown_count == 1 and placard.queue.size() == 2, "three completions at once: one placard shows, two wait their turn (%d shown, %d waiting)" % [placard.shown_count, placard.queue.size()])
	check(placard._name.text == "First", "the placard names the goal (%s)" % placard._name.text)
	check(str(placard.queue[1][2]) == "4 " + view.table.name_of(view.table.number_of("stick")), "an item reward is written out (%s)" % str(placard.queue[1][2]))
	placard._next()
	check(placard.shown_count == 2 and placard._name.text == "Second" and placard.queue.size() == 1, "the next one shows only when the first has gone")
	placard._next()
	placard._next()
	check(not placard.showing and placard.queue.is_empty() and placard.shown_count == 3, "each completion was shown exactly once")
	var face: Font = ArtKit.font("garamond_semibold")
	var box: Vector2 = GoalPlacard.NAME_BOX.size * 0.4
	var short_px: int = GoalPlacard.fit_px(face, "Drink", box, 26, 12)
	var long_px: int = GoalPlacard.fit_px(face, "Cross the camp at night with a torch and fill your winter store before the first snow", box, 26, 12)
	check(short_px == 26 and long_px < short_px, "a long name steps its text down to fit the band (%d against %d)" % [long_px, short_px])
	placard.queue_free()

	# The Journal: one window, J / G / M pages, Esc closes, view-only selection with prerequisite links and Back.
	var layer: CanvasLayer = CanvasLayer.new()
	root.add_child(layer)
	view._layer = layer
	var coins: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/coins.json"))
	view._coins_cfg = coins
	book.on_goals([row("drink", "Drink at the water", true), row("fibre", "Gather plant fibre", false), row("twine", "Twist twine", false, ["fibre"], 0),
		row("axe", "Make a Stone - Axe", false, ["twine"], 5)])
	var journal = Journal.new()
	journal.setup(view, layer, book)
	view.journal = journal
	journal.press_journal()
	check(journal.open and journal.page == Journal.INDEX and view.screen_open(), "J opens the Journal at its Index, and it counts as an open screen")
	var windows: int = layer.get_children().filter(func(c): return c.name == "Journal").size()
	journal.show_page(Journal.GOALS)
	check(journal.page == Journal.GOALS and journal.selected == "fibre", "G shows Goals with the first unfinished goal selected (%s)" % journal.selected)
	journal.show_page(Journal.MAP)
	check(journal.page == Journal.MAP and layer.get_children().filter(func(c): return c.name == "Journal").size() == windows and windows == 1, "M shows the Map in the same single window")
	journal.press_journal()
	check(journal.open and journal.page == Journal.INDEX, "J inside the Journal goes back to the Index")
	journal.press_journal()
	check(not journal.open and not view.screen_open(), "J on the Index closes it")
	journal.show_page(Journal.GOALS)
	view.close()
	check(not journal.open, "Esc (the view's close) closes the Journal")
	journal.show_page(Journal.GOALS)
	var done_before: int = book.done_count()
	journal.select("axe")
	journal.select("twine")
	check(journal.selected == "twine" and journal.history == ["fibre", "axe"], "selecting goals and links changes only what is shown (%s)" % str(journal.history))
	check(book.done_count() == done_before and heard.size() == 1, "looking at goals completes and announces nothing")
	journal.back()
	check(journal.selected == "axe", "Back returns to the goal looked at before")
	var text: Array = []
	_collect(layer, text)
	check(text.has("LEARN FIRST") and text.any(func(t): return str(t).contains("Twist twine")) and text.any(func(t): return str(t).begins_with("How to Make a Stone")), "the details show the how-to and a Learn first link to Twist twine")
	check(text.has("LEADS TO") == false, "the last goal leads nowhere, so there is no Leads to section")
	journal.select("fibre")
	text.clear()
	_collect(layer, text)
	check(text.has("LEADS TO") and text.any(func(t): return str(t).contains("Twist twine")), "Gather plant fibre leads to Twist twine")
	journal.show_page(Journal.MAP)
	text.clear()
	_collect(layer, text)
	check(text.any(func(t): return str(t).contains("not the finished Map")), "the Map page says plainly it is an interim page")
	journal.close()
	view.free()

	# The keys (after WP-KEYS freed plain J and G): plain J, G and M are the Journal's in the world; Ctrl+Shift+G stays Admin fly, plain G stays Store all on the inventory.
	Bindings.use_path("user://test_goal_ui_keys.json")   # no saved file here: the defaults
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_goal_ui_keys.json"))
	Bindings.forget_loaded()
	check(Bindings.matches(_key(KEY_J), "journal") and Bindings.matches(_key(KEY_G), "goals") and Bindings.matches(_key(KEY_M), "map"), "J, G and M are the Journal's keys")
	check(not Bindings.matches(_key(KEY_G, true, true), "goals") and Bindings.matches(_key(KEY_G, true, true), "fly"), "Ctrl+Shift+G is Admin fly, never Goals")
	check(not Bindings.matches(_key(KEY_J, true, true), "journal") and Bindings.matches(_key(KEY_G), "store_all"), "Ctrl+Shift+J is not the Journal; plain G is still Store all in the inventory context")
	check(Bindings.conflict("goals", KEY_G, false, false) == "" and Bindings.conflict("journal", KEY_J, false, false) == "" and Bindings.conflict("map", KEY_M, false, false) == "", "the Journal keys clash with no world action")
	print("goal ui: %d failures" % failures)
	quit(1 if failures > 0 else 0)
