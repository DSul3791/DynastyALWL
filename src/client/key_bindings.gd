extends RefCounted

# Rebindable keys (Dave 4 Nov 2026): one list of every keyboard action in the game, its default key, and the player's own choices,
# saved per user in user://key_bindings.json (only the changed ones). Esc > Settings > Controls lists them and changes them.
# Code asks `KeyBindings.matches(event, "interact")` for a key press, or `KeyBindings.held("move_forward")` for a held key,
# never a KEY_ constant. Mouse buttons, Esc and the hotbar number keys are fixed and shown in the list as such.
#
# A binding is a key plus optional Ctrl / Shift. The held (polled) actions take a plain key only.
# Two actions in the same context (world or inventory screen) must not share a binding; the Controls page warns and offers a swap.

const PATH := "user://key_bindings.json"

const CONTEXT_WORLD := "world"
const CONTEXT_PACK := "inventory screen"

# id, label, group, context, default key, ctrl, shift, polled (held keys and inventory-screen keys take a plain key only: Shift changes what some of them do)
const ACTIONS := [
	["move_forward", "Walk forward (double-tap: jog, with Run: run)", "Movement", CONTEXT_WORLD, KEY_W, false, false, true],
	["move_back", "Walk back", "Movement", CONTEXT_WORLD, KEY_S, false, false, true],
	["move_left", "Step left", "Movement", CONTEXT_WORLD, KEY_A, false, false, true],
	["move_right", "Step right", "Movement", CONTEXT_WORLD, KEY_D, false, false, true],
	["run", "Run (with forward) / fly faster", "Movement", CONTEXT_WORLD, KEY_SHIFT, false, false, true],
	["jump", "Jump / swim up / fly up", "Movement", CONTEXT_WORLD, KEY_SPACE, false, false, true],
	["down", "Dive / fly down", "Movement", CONTEXT_WORLD, KEY_CTRL, false, false, true],
	["crouch", "Crouch (toggle)", "Stances", CONTEXT_WORLD, KEY_C, false, false, false],
	["sit", "Sit (toggle)", "Stances", CONTEXT_WORLD, KEY_X, false, false, false],
	["lie", "Lie down (toggle; hold to sleep)", "Stances", CONTEXT_WORLD, KEY_Z, false, false, true],
	["interact", "Interact: gather, drink, talk, open (hold for the long action)", "Actions", CONTEXT_WORLD, KEY_E, false, false, true],
	["open", "Open a chest, fire store or station", "Actions", CONTEXT_WORLD, KEY_F, false, false, false],
	["put_down_log", "Put down the log on your shoulder", "Actions", CONTEXT_WORLD, KEY_Q, false, false, false],
	["blueprints", "Hammer in hand: blueprint list", "Actions", CONTEXT_WORLD, KEY_R, false, false, false],
	["delete_plan", "Hammer in hand: delete the blueprint you aim at", "Actions", CONTEXT_WORLD, KEY_DELETE, false, false, false],
	["auto_pickup", "Auto pickup on / off", "Actions", CONTEXT_WORLD, KEY_P, false, false, false],
	["inspect", "Inspection mode on / off", "Actions", CONTEXT_WORLD, KEY_SLASH, false, false, false],
	["ruler", "Inclination ruler on / off", "Actions", CONTEXT_WORLD, KEY_H, false, false, false],
	["inventory", "Crafting and inventory screen", "Screens", CONTEXT_WORLD, KEY_I, false, false, false],
	["character", "Character screen", "Screens", CONTEXT_WORLD, KEY_TAB, false, false, false],
	["photo", "Photo camera (toggle)", "Screens", CONTEXT_WORLD, KEY_K, false, false, false],
	["photo_up", "Photo camera: raise", "Screens", CONTEXT_WORLD, KEY_PAGEUP, false, false, true],
	["photo_down", "Photo camera: lower", "Screens", CONTEXT_WORLD, KEY_PAGEDOWN, false, false, true],
	["use_item", "Use / eat / hold the slot", "Inventory screen", CONTEXT_PACK, KEY_E, false, false, true],
	["drop_item", "Drop the stack (with Shift: one)", "Inventory screen", CONTEXT_PACK, KEY_D, false, false, true],
	["split_item", "Split the stack", "Inventory screen", CONTEXT_PACK, KEY_S, false, false, true],
	["repair_item", "Repair a worn tool", "Inventory screen", CONTEXT_PACK, KEY_R, false, false, true],
	["transfer_item", "Move the stack to or from a container", "Inventory screen", CONTEXT_PACK, KEY_T, false, false, true],
	["fly", "Admin: walk or fly", "Admin and debug", CONTEXT_WORLD, KEY_G, false, false, false],
	["quality", "Quality: Low, Medium, High, Ultra", "Admin and debug", CONTEXT_WORLD, KEY_F2, false, false, false],
	["debug_details", "Debug details on / off", "Admin and debug", CONTEXT_WORLD, KEY_F3, false, false, false],
	["sound_panel", "Sound panel", "Admin and debug", CONTEXT_WORLD, KEY_F3, false, true, false],
	["hud_text", "All screen text on / off", "Admin and debug", CONTEXT_WORLD, KEY_F4, false, false, false],
	["spring_up", "Spring flow up (tuning)", "Admin and debug", CONTEXT_WORLD, KEY_EQUAL, false, false, false],
	["spring_down", "Spring flow down (tuning)", "Admin and debug", CONTEXT_WORLD, KEY_MINUS, false, false, false],
	["starter_items", "Admin: starter items", "Admin and debug", CONTEXT_WORLD, KEY_BRACKETRIGHT, false, false, false],
	["admin_npc", "Admin: stand by the nearest NPC", "Admin and debug", CONTEXT_WORLD, KEY_N, true, false, false],
	["admin_rabbit", "Admin: put a rabbit where you aim", "Admin and debug", CONTEXT_WORLD, KEY_R, true, false, false],
	["admin_dig", "Admin: dig a hole where you aim", "Admin and debug", CONTEXT_WORLD, KEY_X, true, false, false],
	["jitter_test", "Float jitter test", "Admin and debug", CONTEXT_WORLD, KEY_J, false, false, false],
	["gpu_probe", "GPU probe", "Admin and debug", CONTEXT_WORLD, KEY_G, true, true, false],
	["water_hide", "Hide or show every river and lake", "Admin and debug", CONTEXT_WORLD, KEY_W, true, true, false],
	["water_debug", "Colour the water by what the shader sees", "Admin and debug", CONTEXT_WORLD, KEY_V, true, true, false],
]

# Shown in the list but not rebindable.
const FIXED := [
	["Esc", "Menu / close the open screen"],
	["1 to 9, 0", "Hotbar slots (same key again puts the item away)"],
	["1 to 5", "Pick an answer when talking"],
	["Left click / Right click", "Use the held item / aim or eat"],
	["Mouse wheel", "Camera distance; hotbar scroll with some tools"],
]

const MODIFIER_KEYS := [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]

static var _changed: Dictionary = {}        # id -> {"key": int, "ctrl": bool, "shift": bool}
static var _loaded: bool = false
static var path: String = PATH              # tests point this at their own file with use_path() (use_path keeps the file, loaded choices and statics together)


static func use_path(new_path: String) -> void:
	path = new_path
	_loaded = false
	_changed = {}


static func _known(id: String) -> bool:
	for row in ACTIONS:
		if row[0] == id:
			return true

	return false


static func _row(id: String) -> Array:
	for row in ACTIONS:
		if row[0] == id:
			return row

	push_error("KeyBindings: unknown action '%s'" % id)
	return []


static func ensure_loaded() -> void:
	if _loaded:
		return

	_loaded = true
	_changed = {}

	if not FileAccess.file_exists(path):
		return

	var json: JSON = JSON.new()

	if json.parse(FileAccess.get_file_as_string(path)) != OK:   # a damaged file: the defaults, with no engine error printed
		return

	var parsed: Variant = json.data

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	for id in parsed:
		var entry: Variant = parsed[id]

		if not _known(str(id)) or typeof(entry) != TYPE_DICTIONARY:
			continue   # an action that no longer exists, or a damaged entry: ignored without an error

		var row: Array = _row(str(id))

		var key: int = int(entry.get("key", KEY_NONE))
		var ctrl: bool = bool(entry.get("ctrl", false)) and not bool(row[7])
		var shift: bool = bool(entry.get("shift", false)) and not bool(row[7])
		_changed[str(id)] = {"key": key, "ctrl": ctrl, "shift": shift}


static func save() -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify(_changed, "\t"))


# For tests: forget everything loaded and read the file again next time. (Not called reload: Script.reload() is an engine method that would run instead and reset the statics.)
static func forget_loaded() -> void:
	_loaded = false
	_changed = {}


static func binding(id: String) -> Dictionary:
	ensure_loaded()

	if _changed.has(id):
		return _changed[id]

	var row: Array = _row(id)
	return {"key": row[4], "ctrl": row[5], "shift": row[6]} if not row.is_empty() else {"key": KEY_NONE, "ctrl": false, "shift": false}


static func default_binding(id: String) -> Dictionary:
	var row: Array = _row(id)
	return {"key": row[4], "ctrl": row[5], "shift": row[6]} if not row.is_empty() else {"key": KEY_NONE, "ctrl": false, "shift": false}


static func is_default(id: String) -> bool:
	return not _changed.has(id)


static func key_label(bind: Dictionary) -> String:
	if int(bind["key"]) == KEY_NONE:
		return "(none)"

	var text: String = OS.get_keycode_string(int(bind["key"]))
	return ("Ctrl+" if bind["ctrl"] else "") + ("Shift+" if bind["shift"] else "") + text


static func label(id: String) -> String:
	return key_label(binding(id))


# True when this key-down event is the action's key (with the same Ctrl and Shift held). Extra Ctrl or Shift never match
# a plain binding, so Ctrl+R (rabbit) does not also fire R (blueprints).
static func matches(event: InputEventKey, id: String) -> bool:
	var bind: Dictionary = binding(id)

	if int(bind["key"]) == KEY_NONE or event.keycode != int(bind["key"]):
		return false

	var row: Array = _row(id)

	if not row.is_empty() and bool(row[7]):
		return true   # held-type actions ignore modifiers (Shift+W is run, not another key)

	return event.ctrl_pressed == bool(bind["ctrl"]) and event.shift_pressed == bool(bind["shift"])


# A held key (movement, interact hold, photo camera raise and lower).
static func held(id: String) -> bool:
	var bind: Dictionary = binding(id)
	return int(bind["key"]) != KEY_NONE and Input.is_key_pressed(int(bind["key"]))


static func released(event: InputEventKey, id: String) -> bool:
	return not event.pressed and int(binding(id)["key"]) != KEY_NONE and event.keycode == int(binding(id)["key"])


# Another action in the same context that already has this binding, or "" when it is free.
static func conflict(id: String, key: int, ctrl: bool, shift: bool) -> String:
	var mine: Array = _row(id)

	if mine.is_empty():
		return ""

	for row in ACTIONS:
		if row[0] == id or row[3] != mine[3]:
			continue

		var other: Dictionary = binding(row[0])

		if int(other["key"]) != key:
			continue

		var same_mods: bool = bool(other["ctrl"]) == ctrl and bool(other["shift"]) == shift

		# A held action ignores modifiers, so it clashes with any plain use of its key (a Ctrl or Shift combination is a different binding).
		var plain: bool = not (ctrl or shift or bool(other["ctrl"]) or bool(other["shift"]))

		if same_mods or ((bool(row[7]) or bool(mine[7])) and plain):
			return str(row[0])

	return ""


static func label_of_action(id: String) -> String:
	var row: Array = _row(id)
	return str(row[1]) if not row.is_empty() else id


# Why a key cannot be bound to this action, or "" when it can.
static func refusal(id: String, key: int) -> String:
	if key == KEY_ESCAPE or (key >= KEY_0 and key <= KEY_9):   # the menu and the hotbar
		return "%s is kept for the menu and the hotbar." % OS.get_keycode_string(key)

	if key in MODIFIER_KEYS and not bool(_row(id)[7]):
		return "Shift, Ctrl, Alt are only used as part of a combination here. Press the key you want with them held."

	return ""


# Sets a binding. Returns "" when done, else the refusal text. Held actions ignore Ctrl and Shift.
static func set_binding(id: String, key: int, ctrl: bool, shift: bool) -> String:
	ensure_loaded()
	var row: Array = _row(id)

	if row.is_empty():
		return "Unknown action."

	var why: String = refusal(id, key)

	if why != "":
		return why

	if bool(row[7]):
		ctrl = false
		shift = false

	var bind: Dictionary = {"key": key, "ctrl": ctrl, "shift": shift}

	if bind == default_binding(id):
		_changed.erase(id)
	else:
		_changed[id] = bind

	save()
	return ""


# Gives this action the key and the other one this action's old key (or none when that would be a second clash).
static func swap(id: String, other: String, key: int, ctrl: bool, shift: bool) -> void:
	var old: Dictionary = binding(id)
	set_binding(id, key, ctrl, shift)
	var held_kind: bool = bool(_row(other)[7])
	set_binding(other, int(old["key"]), bool(old["ctrl"]) and not held_kind, bool(old["shift"]) and not held_kind)


static func clear(id: String) -> void:
	ensure_loaded()
	_changed[id] = {"key": KEY_NONE, "ctrl": false, "shift": false}
	save()


static func reset(id: String) -> void:
	ensure_loaded()
	_changed.erase(id)
	save()


static func reset_all() -> void:
	ensure_loaded()
	_changed = {}
	save()


# Every action that clashes with another in the same context right now (after a hand edit of the file, say).
static func conflicts() -> Array:
	ensure_loaded()
	var found: Array = []

	for row in ACTIONS:
		var bind: Dictionary = binding(row[0])

		if int(bind["key"]) == KEY_NONE:
			continue

		var other: String = conflict(row[0], int(bind["key"]), bool(bind["ctrl"]), bool(bind["shift"]))

		if other != "":
			found.append([row[0], other])

	return found


# Which action each key letter in the game's built-in prompt texts stands for ("Press E to gather", "hold E", "F for wood"). The server's
# notices and hints (hints.json: "press E on nettles", "Press F at the fire") come through localize on the client too.
const PROMPT_LETTERS := {"E": "interact", "F": "open", "Z": "lie", "H": "ruler"}
static var _prompt_regex: RegEx = null


# Rewrites the default key letters in a prompt or notice to the keys the player has bound: "Press E to gather" becomes
# "Press Q to gather" when interact is Q. Text without these patterns, and unchanged keys, come back as they were.
static func localize(text: String) -> String:
	ensure_loaded()

	if _changed.is_empty() or text == "":
		return text

	if _prompt_regex == null:
		_prompt_regex = RegEx.create_from_string("\\b(?:(?:[Pp]ress|[Hh]old|[Tt]ap) |(?<=, )|(?<=\\())([EFZH])\\b(?= to |,|\\)| twice| for | on | at | near | again|\\.|$)")

	var found: Array[RegExMatch] = _prompt_regex.search_all(text)
	found.reverse()

	for hit in found:
		var letter: String = hit.get_string(1)
		text = text.substr(0, hit.get_start(1)) + label(PROMPT_LETTERS[letter]) + text.substr(hit.get_end(1))

	return text
