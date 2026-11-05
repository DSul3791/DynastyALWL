extends SceneTree

# The title page (scenes/title/title.gd, Kathreen 5 Nov 2026). Checks: every painting file is there; each painting's four drawn buttons are inside the picture, in order
# top to bottom and not overlapping; the hit areas scale with the window; the random pick never shows the same painting twice in a row and reaches all of them; the page
# builds, and Continue is dimmed and does nothing with no character, on with one. Uses user://characters_title_test, never the real characters.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_title_page.gd
const Title := preload("res://scenes/title/title.gd")
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
	_check(Title.PAINTINGS.size() == 11, "eleven paintings with drawn buttons (%d)" % Title.PAINTINGS.size())
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
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var last: int = -1
	var seen: Dictionary = {}
	var repeats: int = 0

	for k in range(400):
		var n: int = Title.pick(Title.PAINTINGS.size(), last, rng)
		repeats += 1 if n == last else 0
		_check(n >= 0 and n < Title.PAINTINGS.size(), "pick in range (%d)" % n)
		seen[n] = true
		last = n

	_check(repeats == 0, "never the same painting twice in a row (%d repeats)" % repeats)
	_check(seen.size() == Title.PAINTINGS.size(), "every painting comes up (%d of %d)" % [seen.size(), Title.PAINTINGS.size()])
	_check(Title.pick(1, 0, rng) == 0, "one painting: always that one")
	Store.dir = TEST_DIR
	_wipe()
	var page = TitleScene.instantiate()
	page.painting = 3
	root.add_child(page)
	await process_frame
	_check(page._art.texture != null, "the painting loads")
	_check(page.buttons["continue"].disabled and page._dim.visible, "no character: Continue dimmed")
	_check(not page.press("continue"), "no character: Continue does nothing")
	_check(not page.buttons["new_game"].disabled, "New Game is on")
	_check(Store.add("Tester", Generator.encode(Generator.make_genome("average"))) != "", "a test character is saved")
	page.refresh()
	_check(not page.buttons["continue"].disabled and not page._dim.visible, "a character: Continue on")
	page.press("settings")
	_check(page._settings.visible, "Settings opens its panel")
	page._settings.close()
	_check(not page._settings.visible, "Settings Back closes it")
	page.queue_free()
	_wipe()
	print("title page tests: %d failures" % _fails)
	quit(1 if _fails > 0 else 0)


func _wipe() -> void:
	if DirAccess.dir_exists_absolute(TEST_DIR):
		for file in DirAccess.get_files_at(TEST_DIR):
			DirAccess.remove_absolute(TEST_DIR + "/" + file)
