extends SceneTree

# The hint card (R-HUD-HINT-BOX, Dave 28 Nov 2026): a guide hint or a "Goal done ... Next:" line waits for safety, shows until OK or Enter, steps
# aside when danger comes, and each line shows once (the server's 5-minute once-more too); passing lines are not the card's.
#   godot --headless --path . --script res://src/worldgen/tools/test_hint_card.gd      Prints "Test done: N pass, N fail".

const Card := preload("res://src/client/hint_card.gd")

var passes: int = 0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _initialize() -> void:
	var card = Card.new()
	card.mouse_free = false
	root.add_child(card)
	var drink: String = ""

	for hint in (JSON.parse_string(FileAccess.get_file_as_string(Card.HINTS_PATH)) as Dictionary).get("hints", []):
		if str(hint.get("id", "")) == "drink":
			drink = str(hint["text"])   # its words change with the wording passes: read, not copied

	check(drink != "", "the drink hint is in hints.json")
	var hotbar: String = "Drag the axe to the hotbar, then press its number key."
	var copper: String = "Goal done: Smelt copper. You earn 10 copper. Next: Find tin ore. This is a journey."
	check(card.wanted(drink) and card.wanted(hotbar), "a goal hint and a box-marked hint are the card's")
	check(card.wanted(copper), "a goal done with the next goal's how-to is the card's")
	check(not card.wanted("Walk with W A S D. Hold Shift to run.") and not card.wanted("F again to put the log down") and not card.wanted("Goal done: Smelt copper."),
		"a passing hint, a refusal and a goal done with nothing next stay passing lines")
	check(not card.offer("Too many trunks lie here."), "offer refuses a line that is not the card's (the caller shows it)")
	check(card.offer(drink) and card.offer(drink) and card.queue.size() == 1, "each line is queued once (the server's once-more is not a second card)")
	card.offer(copper)
	card.tick(false, 10000)
	check(card.showing == "" and card.queue.size() == 2, "not safe: nothing shows")
	card.tick(true, 10000)
	check(card.showing == drink and card.visible, "safe: the first line shows")
	card.tick(false, 10100)
	check(card.showing == "" and not card.visible and card.queue[0] == drink, "danger while it shows: it steps aside and goes back to the front")
	card.tick(true, 10200)
	check(card.showing == "", "it waits a moment before coming back")
	card.tick(true, 12000)
	check(card.showing == drink, "and comes back when safe again")
	check(not card.take_key(_key(KEY_SPACE)) and card.showing == drink, "Space (jump) does not close it")
	check(card.take_key(_key(KEY_ENTER)) and card.showing == "", "Enter is OK")
	card.tick(true, Time.get_ticks_msec() + 2000)
	check(card.showing == copper and Card.words(copper).contains("\n\nNext: Find tin ore."), "the next card follows, the next goal on its own lines")
	card.ok()
	check(card.showing == "" and card.queue.is_empty(), "OK closes the last one")
	card.offer(drink)
	check(card.queue.is_empty(), "a line already shown this run does not come back")
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
