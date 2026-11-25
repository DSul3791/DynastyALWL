extends SceneTree

# The welcome card (Dave 25 Nov 2026): once per character on this computer, the player's own keys in its words, Enter or Esc closes it.
#   godot --headless --path . --script res://src/worldgen/tools/test_welcome_card.gd      Prints "Test done: N pass, N fail".

const Card := preload("res://src/client/welcome_card.gd")
const Bindings := preload("res://src/client/key_bindings.gd")
const KEYS := "user://test_welcome_keys.json"
const SEEN := "user://test_welcome_seen.cfg"

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
	DirAccess.remove_absolute(KEYS)
	DirAccess.remove_absolute(SEEN)
	Bindings.use_path(KEYS)

	var text: String = "\n".join(Card.lines())
	check(text.begins_with("Welcome to Dynasty."), "it welcomes the player")
	check(text.contains("Press E to use what you look at") and text.contains("Press F to open a chest"), "E and F by their default keys")
	check(text.contains("Press / (the key with ? on it) to turn inspection mode on or off"), "inspection mode by its key, the plain / (Dave's ? key): %s" % text)
	check(text.contains("Leave it off for a cleaner screen") and text.contains("Esc > Settings > Controls"), "a cleaner screen with it off, and where the other keys are")

	check(Bindings.set_binding("interact", KEY_Y, false, false) == "", "Y is free for E")
	check(Bindings.set_binding("inspect", KEY_PERIOD, false, false) == "", ". is free for inspection")
	text = "\n".join(Card.lines())
	check(text.contains("Press Y to use what you look at") and text.contains("Press . to turn inspection mode"), "a rebound key is named as bound: %s" % text)
	Bindings.reset_all()

	var card = Card.new()
	card.seen_path = SEEN
	root.add_child(card)
	check(card.offer("character_a") and card.showing, "a new character sees it")
	check(not card.take_key(_key(KEY_W)) and card.showing, "walking does not close it")
	check(card.take_key(_key(KEY_ENTER)) and not card.showing, "Enter closes it")
	check(not card.offer("character_a") and not card.showing, "the same character never sees it again")
	check(card.offer("character_b"), "another new character sees it")
	check(card.take_key(_key(KEY_ESCAPE)) and not card.showing, "Esc closes it too")
	check(not card.take_key(_key(KEY_ESCAPE)), "with it closed Esc is the menu's again")
	check(not card.offer(""), "no character: no card")

	card.free()
	DirAccess.remove_absolute(KEYS)
	DirAccess.remove_absolute(SEEN)
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
