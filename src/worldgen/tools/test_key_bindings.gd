extends SceneTree

# Rebindable keys (Esc > Settings > Controls): defaults, matching, saving per user, conflicts, swap, reset.
#   godot --headless --path . --script res://src/worldgen/tools/test_key_bindings.gd      Prints "Test done: N pass, N fail".

const Bindings := preload("res://src/client/key_bindings.gd")
const TEMP := "user://test_key_bindings.json"

var passes: int = 0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _key(code: int, ctrl: bool = false, shift: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	return event


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	Bindings.path = TEMP
	Bindings.reload()

	var ids: Dictionary = {}

	for row in Bindings.ACTIONS:
		check(not ids.has(row[0]), "action id %s is unique" % row[0])
		ids[row[0]] = true

	check(Bindings.conflicts().is_empty(), "the defaults have no clashes (found %s)" % str(Bindings.conflicts()))
	check(Bindings.matches(_key(KEY_E), "interact") and not Bindings.matches(_key(KEY_F), "interact"), "E interacts by default")
	check(Bindings.matches(_key(KEY_F), "open"), "F opens by default")
	check(Bindings.matches(_key(KEY_R, true), "admin_rabbit") and not Bindings.matches(_key(KEY_R), "admin_rabbit"), "Ctrl+R is the rabbit, plain R is not")
	check(Bindings.matches(_key(KEY_R), "blueprints") and not Bindings.matches(_key(KEY_R, true), "blueprints"), "plain R is blueprints, Ctrl+R is not")
	check(Bindings.matches(_key(KEY_D, false, true), "drop_item"), "Shift+D still drops one (inventory keys ignore Shift)")
	check(Bindings.matches(_key(KEY_H), "ruler"), "the inclination ruler has a key")
	check(Bindings.label("admin_rabbit") == "Ctrl+R", "label shows the Ctrl")

	check(Bindings.set_binding("interact", KEY_ESCAPE, false, false) != "", "Esc cannot be bound")
	check(Bindings.set_binding("interact", KEY_5, false, false) != "", "hotbar digits cannot be bound")
	check(Bindings.set_binding("open", KEY_SHIFT, false, false) != "", "a lone modifier is refused on a non-held action")
	check(Bindings.set_binding("run", KEY_ALT, false, false) == "", "a held action may take a lone modifier key")

	check(Bindings.conflict("open", KEY_E, false, false) == "interact", "F -> E clashes with interact")
	check(Bindings.conflict("use_item", KEY_E, false, false) == "", "E in the inventory screen does not clash with E in the world")
	check(Bindings.conflict("open", KEY_E, true, false) == "", "Ctrl+E is its own binding")

	check(Bindings.set_binding("interact", KEY_F, false, false) == "", "interact rebinds to F")
	check(Bindings.matches(_key(KEY_F), "interact") and not Bindings.matches(_key(KEY_E), "interact"), "the new key works and the old one does not")
	check(Bindings.conflicts().size() == 2, "interact and open now share F, both are reported")
	Bindings.reset("interact")   # the page swaps before it sets: interact holds E when the swap starts
	Bindings.swap("interact", "open", KEY_F, false, false)
	check(Bindings.label("interact") == "F" and Bindings.label("open") == "E", "swap gives the other action the old key")
	check(Bindings.conflicts().is_empty(), "no clash after the swap")

	Bindings.reload()
	check(Bindings.label("interact") == "F" and Bindings.label("open") == "E", "the choices are saved and loaded back")
	check(not Bindings.is_default("interact") and Bindings.is_default("crouch"), "only changed keys count as changed")

	Bindings.reset("interact")
	check(Bindings.label("interact") == "E", "reset puts one action back")
	Bindings.reset_all()
	Bindings.reload()
	check(Bindings.label("open") == "F" and Bindings.is_default("open") and Bindings.is_default("run"), "reset all puts everything back and saves it")

	Bindings.clear("ruler")
	check(not Bindings.matches(_key(KEY_H), "ruler") and Bindings.label("ruler") == "(none)", "an action can be left without a key")
	Bindings.reset_all()

	var file: FileAccess = FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_string("not json {{")
	file.close()
	Bindings.reload()
	check(Bindings.label("interact") == "E", "a damaged file falls back to the defaults")
	file = FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_string('{"nonsense": {"key": 65}, "crouch": {"key": 86, "ctrl": true}}')
	file.close()
	Bindings.reload()
	check(Bindings.label("crouch") == "Ctrl+V" and Bindings.label("interact") == "E", "unknown actions in the file are ignored")

	check(Bindings.localize("Press E to gather") == "Press E to gather", "prompts are untouched while the keys are the defaults")
	Bindings.set_binding("interact", KEY_Q, false, false)
	Bindings.set_binding("ruler", KEY_U, false, false)
	check(Bindings.localize("Press E to gather") == "Press Q to gather", "a prompt shows the bound key")
	check(Bindings.localize("Press E to light (hold E to pick it up, F for wood)") == "Press Q to light (hold Q to pick it up, F for wood)", "every E in a prompt follows the key, F stays while unchanged")
	check(Bindings.localize("Press H to show inclination") == "Press U to show inclination", "the ruler hint follows its key")
	check(Bindings.localize("Enter the Fire pit") == "Enter the Fire pit", "words that only contain a key letter are left alone")
	Bindings.reset_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	Bindings.path = Bindings.PATH
	Bindings.reload()
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
