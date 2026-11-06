extends SceneTree

# The title page (scenes/title/title.gd, Kathreen 5 Nov 2026). Checks: every painting file is there; each painting's four drawn buttons are inside the picture, in order
# top to bottom and not overlapping; the hit areas scale with the window; each showing moves to the next page of the story, the dragon battle last, then back to the start; the page
# builds, and Continue is dimmed and does nothing with no character, on with one; the Esc menu uses the same painted page; the menu fonts and look load. Uses user://characters_title_test, never the real characters.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_title_page.gd
const Title := preload("res://scenes/title/title_art.gd")   # the painted page: paintings, order, button areas
const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const TitleScene := preload("res://scenes/title/title.tscn")
const Store := preload("res://src/client/character/character_store.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const TEST_DIR := "user://characters_title_test"   # its own folder: the store check runs alongside

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


func _initialize() -> void:
	_run()


func _run() -> void:
	_check(Title.PAINTINGS.size() == 12, "all twelve paintings (%d)" % Title.PAINTINGS.size())
	var picture: Rect2 = Rect2(Vector2.ZERO, Title.IMAGE_SIZE)

	for p in Title.PAINTINGS:
		_check(FileAccess.file_exists(Title.DIR + p["file"]), "%s is in %s" % [p["file"], Title.DIR])
		var last_bottom: float = -1.0

		for action in Title.ACTIONS:
			var r: Rect2 = Title.button_rect(p, action)
			_check(picture.encloses(r), "%s %s inside the picture" % [p["file"], action])
			_check(r.position.y > last_bottom, "%s %s below the one before, no overlap" % [p["file"], action])
			last_bottom = r.end.y

	var r0: Rect2 = Title.button_rect(Title.PAINTINGS[0], "exit")
	var v: Rect2 = Title.to_view(r0, Title.IMAGE_SIZE * 2.0)
	_check(v.position.is_equal_approx(r0.position * 2.0) and v.size.is_equal_approx(r0.size * 2.0), "hit areas scale with the window")
	var order: Array = []

	for p in Title.PAINTINGS:
		order.append(str(p["file"]).substr(0, 2))

	_check(order == ["02", "03", "04", "05", "07", "08", "12", "13", "14", "15", "16", "11"], "story order, the dragon battle last (%s)" % [order])
	_check(Title.next_after("") == 0, "nothing shown yet: the first page")
	_check(Title.next_after("no_such.jpg") == 0, "an unknown name: the first page")
	_check(Title.next_after(Title.PAINTINGS[0]["file"]) == 1, "after the first: the second")
	_check(Title.next_after(Title.PAINTINGS[-1]["file"]) == 0, "after the last: back to the first")
	var n: int = Title.next_after("")
	var seen: Dictionary = {}

	for _k in range(Title.PAINTINGS.size()):
		seen[n] = true
		n = Title.next_after(Title.PAINTINGS[n]["file"])

	_check(seen.size() == Title.PAINTINGS.size() and n == 0, "one round shows every page once and comes back to the start")
	Store.dir = TEST_DIR
	_wipe()
	var page = TitleScene.instantiate()
	page.painting = 3
	root.add_child(page)
	await process_frame
	_check(page.art.texture_rect.texture != null, "the painting loads")
	_check(page.art.buttons["continue"].disabled and page.art._dims["continue"].visible, "no character: Continue dimmed")
	_check(not page.press("continue"), "no character: Continue does nothing")
	_check(not page.art.buttons["new_game"].disabled, "New Game is on")
	_check(Store.add("Tester", Generator.encode(Generator.make_genome("average"))) != "", "a test character is saved")
	page.refresh()
	_check(not page.art.buttons["continue"].disabled and not page.art._dims["continue"].visible, "a character: Continue on")
	page.press("settings")
	_check(page._settings.visible, "Settings opens its panel")
	page._settings.close()
	_check(not page._settings.visible, "Settings Back closes it")
	page.queue_free()
	# The Esc menu in game uses the same painted page and the paintings' look (Dave 6 Nov 2026).
	var menu_src: String = FileAccess.get_file_as_string("res://src/client/game_menu.gd")
	_check(menu_src.contains("TitleArt.new()") and menu_src.contains("func next_painting()"), "the Esc menu shows the painted front, the next painting each time")
	_check(FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd").contains("game_menu.next_painting()"), "opening the Esc menu moves the story on")
	_check(DynastyTheme.button_font() != null and DynastyTheme.text_font() != null and DynastyTheme.heading_font() != null, "the menu fonts load")
	var theme: Theme = DynastyTheme.make()
	_check((theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color.a == 1.0, "menu panels are solid")
	_check(theme.get_color("font_color", "Button") == DynastyTheme.CREAM, "button text is cream, not grey")
	_wipe()
	print("title page tests: %d failures" % _fails)
	quit(1 if _fails > 0 else 0)


func _wipe() -> void:
	if DirAccess.dir_exists_absolute(TEST_DIR):
		for file in DirAccess.get_files_at(TEST_DIR):
			DirAccess.remove_absolute(TEST_DIR + "/" + file)
