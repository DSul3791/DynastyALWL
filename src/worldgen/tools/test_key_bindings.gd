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


# Writes a saved-bindings file the way an older build did (key, ctrl, shift per action) and makes the next lookup read it.
func _write(saved: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	Bindings.forget_loaded()


# ADMIN_KEYBINDINGS_POLICY.md: the default chord of every Admin and debug action.
func _admin_defaults() -> void:
	var table: Dictionary = {"fly": KEY_G, "quality": KEY_F2, "debug_details": KEY_F3, "sound_panel": KEY_F5, "hud_text": KEY_F4, "spring_up": KEY_EQUAL, "spring_down": KEY_MINUS,
		"starter_items": KEY_BRACKETRIGHT, "admin_npc": KEY_N, "admin_rabbit": KEY_R, "admin_dig": KEY_X, "admin_spyglass": KEY_L, "jitter_test": KEY_J, "gpu_probe": KEY_P,
		"water_hide": KEY_F7, "water_debug": KEY_F8}
	var seen: Dictionary = {}
	var count: int = 0

	for row in Bindings.ACTIONS:
		if row[2] != Bindings.ADMIN_GROUP:
			continue

		var id: String = row[0]
		var key: int = int(row[4])
		count += 1
		check(table.has(id) and key == int(table[id]), "%s default key is the policy key" % id)
		check(bool(row[5]) and bool(row[6]) and not bool(row[7]), "%s default needs Ctrl and Shift and is not a held action" % id)
		check(Bindings.matches(_key(key, true, true), id), "%s matches Ctrl+Shift+%s" % [id, OS.get_keycode_string(key)])
		check(not Bindings.matches(_key(key), id), "%s: the plain key does not match" % id)
		check(not Bindings.matches(_key(key, true), id), "%s: Ctrl alone does not match" % id)
		check(not Bindings.matches(_key(key, false, true), id), "%s: Shift alone does not match" % id)
		check(not seen.has(key), "%s: no other admin action has the same chord" % id)
		seen[key] = true

	check(count == table.size(), "the policy table covers every Admin and debug action (%d)" % count)


# The group rule on a saved file, rebinding, reset and swap; the inventory keys.
func _admin_rules() -> void:
	# An old file: bare G fly, Ctrl+N npc, Shift+F3 sound panel (F3 is Debug details now), a held key (W) as an admin key, a disabled action.
	_write({"fly": {"key": KEY_G}, "admin_npc": {"key": KEY_N, "ctrl": true}, "sound_panel": {"key": KEY_F3, "shift": true}, "admin_dig": {"key": KEY_W, "ctrl": true}, "admin_rabbit": {"key": KEY_NONE}})
	check(Bindings.label("fly") == "Ctrl+Shift+G" and Bindings.is_default("fly"), "an old bare-G fly becomes Ctrl+Shift+G (its default)")
	check(Bindings.label("admin_npc") == "Ctrl+Shift+N", "an old Ctrl+N npc becomes Ctrl+Shift+N")
	check(Bindings.label("sound_panel") == "Ctrl+Shift+F5" and Bindings.is_default("sound_panel"), "an old Shift+F3 sound panel would clash with Debug details, so it goes back to Ctrl+Shift+F5")
	check(Bindings.label("debug_details") == "Ctrl+Shift+F3", "Debug details keeps Ctrl+Shift+F3")
	check(Bindings.label("admin_dig") == "Ctrl+Shift+X", "a held key (W) cannot be an admin key: back to the default")
	check(Bindings.label("admin_rabbit") == "(none)", "a disabled admin action stays disabled")
	check(Bindings.conflicts().is_empty(), "the sanitized file leaves no clashes (found %s)" % str(Bindings.conflicts()))
	check(Bindings.matches(_key(KEY_G, true, true), "fly") and not Bindings.matches(_key(KEY_G), "fly"), "the migrated fly needs both modifiers")

	# Two old overrides on one key: the earlier action in the table goes back to its default, the other keeps the key (both with Ctrl+Shift).
	_write({"admin_npc": {"key": KEY_K, "ctrl": true}, "spring_up": {"key": KEY_K, "shift": true}})
	check(Bindings.label("admin_npc") == "Ctrl+Shift+K" and Bindings.label("spring_up") == "Ctrl+Shift+" + OS.get_keycode_string(KEY_EQUAL), "two old overrides on one key are resolved")
	check(Bindings.conflicts().is_empty(), "no duplicate admin chords after the file is read")
	_write({"jitter_test": {"key": KEY_K, "ctrl": false, "shift": false}})
	check(Bindings.label("jitter_test") == "Ctrl+Shift+K", "the player's own primary key is kept, both modifiers added")

	# Rebinding keeps both modifiers whatever was pressed; swap and reset too.
	Bindings.reset_all()
	check(Bindings.set_binding("fly", KEY_K, false, false) == "" and Bindings.label("fly") == "Ctrl+Shift+K", "rebinding fly to a plain K gives Ctrl+Shift+K")
	check(Bindings.conflict("quality", KEY_K, false, false) == "fly", "the clash check sees the forced Ctrl+Shift")
	check(Bindings.set_binding("quality", KEY_W, true, true) != "" and Bindings.set_binding("quality", KEY_E, true, true) != "", "an admin action cannot take a held key (W, E)")
	check(Bindings.set_binding("move_forward", KEY_N, false, false) != "", "a held action cannot take an admin key")
	Bindings.swap("quality", "fly", KEY_K, false, false)
	check(Bindings.label("quality") == "Ctrl+Shift+K" and Bindings.label("fly") == "Ctrl+Shift+F2", "swap between admin actions keeps both chords")
	Bindings.swap("crouch", "admin_npc", KEY_N, true, true)
	check(Bindings.label("crouch") == "Ctrl+Shift+N" and Bindings.label("admin_npc") == "Ctrl+Shift+C", "swap with a normal action gives the admin action Ctrl+Shift+their old key")
	Bindings.forget_loaded()
	check(Bindings.label("quality") == "Ctrl+Shift+K" and Bindings.label("admin_npc") == "Ctrl+Shift+C", "the new admin choices are saved and loaded back")
	Bindings.reset("quality")
	check(Bindings.label("quality") == "Ctrl+Shift+F2", "reset puts an admin chord back")
	Bindings.reset_all()

	# An admin chord never fires a normal action; plain G is still Store all in the inventory screen and plain G and J fire nothing in the world.
	check(Bindings.matches(_key(KEY_G), "store_all") and not Bindings.matches(_key(KEY_G, true, true), "store_all"), "plain G is Store all, Ctrl+Shift+G is not")
	check(Bindings.matches(_key(KEY_R), "repair_item") and not Bindings.matches(_key(KEY_R, true, true), "repair_item"), "plain R repairs, Ctrl+Shift+R does not")
	check(Bindings.matches(_key(KEY_D, false, true), "drop_item"), "Shift+D still drops one")
	check(not Bindings.matches(_key(KEY_G), "fly") and not Bindings.matches(_key(KEY_J), "jitter_test"), "plain G and J fire no admin action (they are free for the Journal)")
	check(Bindings.conflict("store_all", KEY_G, false, false) == "", "Store all on plain G clashes with nothing")


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	Bindings.use_path(TEMP)

	_admin_defaults()
	var ids: Dictionary = {}

	for row in Bindings.ACTIONS:
		check(not ids.has(row[0]), "action id %s is unique" % row[0])
		ids[row[0]] = true

	check(Bindings.conflicts().is_empty(), "the defaults have no clashes (found %s)" % str(Bindings.conflicts()))
	check(Bindings.matches(_key(KEY_E), "interact") and not Bindings.matches(_key(KEY_F), "interact"), "E interacts by default")
	check(Bindings.matches(_key(KEY_F), "open"), "F opens by default")
	check(Bindings.matches(_key(KEY_R, true, true), "admin_rabbit") and not Bindings.matches(_key(KEY_R), "admin_rabbit"), "Ctrl+Shift+R is the rabbit, plain R is not")
	check(Bindings.matches(_key(KEY_R), "blueprints") and not Bindings.matches(_key(KEY_R, true, true), "blueprints"), "plain R is blueprints, Ctrl+Shift+R is not")
	check(Bindings.matches(_key(KEY_D, false, true), "drop_item"), "Shift+D still drops one (inventory keys ignore Shift)")
	check(Bindings.matches(_key(KEY_H), "ruler"), "the inclination ruler has a key")
	check(Bindings.label("admin_rabbit") == "Ctrl+Shift+R", "label shows the Ctrl and Shift")

	check(Bindings.set_binding("interact", KEY_ESCAPE, false, false) != "", "Esc cannot be bound")
	check(Bindings.set_binding("interact", KEY_5, false, false) != "", "hotbar digits cannot be bound")
	check(Bindings.set_binding("open", KEY_SHIFT, false, false) != "", "a lone modifier is refused on a non-held action")
	check(Bindings.set_binding("run", KEY_ALT, false, false) == "", "a held action may take a lone modifier key")

	check(Bindings.conflict("open", KEY_E, false, false) == "interact", "F -> E clashes with interact")
	check(Bindings.conflict("use_item", KEY_E, false, false) == "", "E in the inventory screen does not clash with E in the world")
	check(Bindings.matches(_key(KEY_A), "take_all") and Bindings.matches(_key(KEY_G), "store_all") and Bindings.matches(_key(KEY_F), "sort_both") and Bindings.matches(_key(KEY_Q), "stack_nearby"), "a container's four bulk keys: A, G, F, Q")
	check(Bindings.conflict("take_all", KEY_T, false, false) == "transfer_item", "Take all cannot share T with transfer")
	check(Bindings.conflict("open", KEY_E, true, false) == "", "Ctrl+E is its own binding")

	check(Bindings.set_binding("interact", KEY_F, false, false) == "", "interact rebinds to F")
	check(Bindings.matches(_key(KEY_F), "interact") and not Bindings.matches(_key(KEY_E), "interact"), "the new key works and the old one does not")
	check(Bindings.conflicts().size() == 2, "interact and open now share F, both are reported")
	Bindings.reset("interact")   # the page swaps before it sets: interact holds E when the swap starts
	Bindings.swap("interact", "open", KEY_F, false, false)
	check(Bindings.label("interact") == "F" and Bindings.label("open") == "E", "swap gives the other action the old key")
	check(Bindings.conflicts().is_empty(), "no clash after the swap")

	Bindings.forget_loaded()
	check(Bindings.label("interact") == "F" and Bindings.label("open") == "E", "the choices are saved and loaded back")
	check(not Bindings.is_default("interact") and Bindings.is_default("crouch"), "only changed keys count as changed")

	Bindings.reset("interact")
	check(Bindings.label("interact") == "E", "reset puts one action back")
	Bindings.reset_all()
	Bindings.forget_loaded()
	check(Bindings.label("open") == "F" and Bindings.is_default("open") and Bindings.is_default("run"), "reset all puts everything back and saves it")

	Bindings.clear("ruler")
	check(not Bindings.matches(_key(KEY_H), "ruler") and Bindings.label("ruler") == "(none)", "an action can be left without a key")
	Bindings.reset_all()

	var file: FileAccess = FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_string("not json {{")
	file.close()
	Bindings.forget_loaded()
	check(Bindings.label("interact") == "E", "a damaged file falls back to the defaults")
	file = FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_string('{"nonsense": {"key": 65}, "crouch": {"key": 86, "ctrl": true}}')
	file.close()
	Bindings.forget_loaded()
	check(Bindings.label("crouch") == "Ctrl+V" and Bindings.label("interact") == "E", "unknown actions in the file are ignored")

	check(Bindings.localize("Press E to gather") == "Press E to gather", "prompts are untouched while the keys are the defaults")
	Bindings.set_binding("interact", KEY_Q, false, false)
	Bindings.set_binding("ruler", KEY_U, false, false)
	check(Bindings.localize("Press E to gather") == "Press Q to gather", "a prompt shows the bound key")
	check(Bindings.localize("Press E to light (hold E to pick it up, F for wood)") == "Press Q to light (hold Q to pick it up, F for wood)", "every E in a prompt follows the key, F stays while unchanged")
	check(Bindings.localize("Press H to show inclination") == "Press U to show inclination", "the ruler hint follows its key")
	check(Bindings.localize("Enter the Fire pit") == "Enter the Fire pit", "words that only contain a key letter are left alone")
	check(Bindings.localize("Press E on nettles or tall grass to get plant fibre.") == "Press Q on nettles or tall grass to get plant fibre.", "a server hint with 'press E on' shows the bound key")
	check(Bindings.localize("Stand at the water's edge and press E to drink.") == "Stand at the water's edge and press Q to drink.", "a hint in mid-sentence shows the bound key")
	check(Bindings.localize("Press E at a fruit tree to pick.") == "Press Q at a fruit tree to pick.", "'press E at' shows the bound key")
	check(Bindings.localize("Hold E.") == "Hold Q.", "a key at the end of a sentence shows the bound key")
	check(Bindings.localize("Press Enter at the gate") == "Press Enter at the gate", "a word that starts with a key letter is left alone")
	Bindings.reset_all()
	_admin_rules()
	Bindings.reset_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	Bindings.use_path(Bindings.PATH)
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
