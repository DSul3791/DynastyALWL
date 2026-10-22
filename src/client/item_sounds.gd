extends Node

# Item sounds (client only): small cues for the inventory, on the Interface bus. Nothing here knows
# the item rules; it watches the inventory the Items thread keeps and hears what changed.
#
#   sound.itemfx.watch(items)      call every frame; plays the cue for what changed since last frame
#   sound.itemfx.play("item_pickup")   or any name below, directly
#
# While a craft runs (the panel's progress) the work sound of its recipe type plays from the start,
# `craft_<type>` (twine, knap, bind, carve, stack, pound, wrap), and stops when it finishes, then craft_done.
# The type comes from the recipe's own "sound" field when it has one, else from its id (WORK_TYPES, then
# a name prefix), else "knap". A new recipe only needs a "sound" field to get the right work sound.
# Cues: item_pickup (stacks grew), item_drop (stacks shrank), inv_open, inv_close, item_swap (slots
# rearranged), craft_done (a craft finished: the inventory's crafting number went back to 0).
# Also: hotbar_tick (a hotbar slot chosen, `hotbar(slot)` from held_item.select, pitch rises a little with the slot),
# craft_start (a craft begins) and the inventory open/close cue for the chest screen. All on the Interface bus,
# short and quiet; the world's sounds keep running while a panel is open.
# Cooking and eating: a roast that appears in the bag sizzles at the nearest fire (sound.fire.cook); wood
# used up within FUEL_WINDOW_MSEC of fuel_pressed() (the V key at a fire) plays sound.fire.fuel there.
#   sound.itemfx.eat("crunch")    eating: "crunch" (roast, nuts, roots), "soft" (berries, greens), "drink"
# Eating has no action yet: the Items thread calls eat() when it adds one (EAT_KINDS maps item ids).
# Sounds: generated in assets/audio/items/ (make_items.py); recordings in assets/audio/recorded/items/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/items/"
const RECORDED_DIR := "res://assets/audio/recorded/items/"
const CRAFT_DIR := "res://assets/audio/crafting/"
const CRAFT_RECORDED_DIR := "res://assets/audio/recorded/crafting/"
const NAMES := {"item_pickup_wood": -17.0, "item_pickup_stone": -17.0, "item_pickup_metal": -19.0, "item_pickup_cloth": -17.0, "item_pickup_soft": -17.0, "item_pickup_food": -17.0, "item_pickup_glass": -19.0, "item_pickup_bone": -17.0,
	"item_drop_wood": -17.0, "item_drop_stone": -17.0, "item_drop_metal": -19.0, "item_drop_cloth": -17.0, "item_drop_soft": -17.0, "item_drop_food": -17.0, "item_drop_glass": -19.0, "item_drop_bone": -17.0,
	"item_pickup": -17.0, "item_drop": -17.0, "inv_open": -20.0, "inv_close": -21.0, "item_swap": -20.0, "craft_done": -16.0, "hotbar_tick": -26.0, "craft_start": -22.0, "item_reject": -24.0}
const BasicLook := preload("res://src/client/basic_look.gd")
# Stage-one pick-up and put-down sounds by what the item is made of (make_items.py class_sound): the shape in data/items/looks.json says which.
const SHAPE_CLASS := {
	"planks": "wood", "beams": "wood", "bark": "wood", "shaft": "wood", "axe": "wood", "pick": "wood", "spade": "wood", "knife": "wood",
	"torch": "wood", "rod": "wood", "kit": "wood", "bucket": "wood", "bundle": "cloth", "sack": "cloth", "hide": "cloth", "coil": "cloth",
	"skin": "cloth", "feather": "cloth", "cloth": "cloth", "chunk": "stone", "ingot": "metal", "coin": "metal", "needle": "metal",
	"pile": "soft", "leaves": "soft", "fish": "food", "meat": "food", "loaf": "food", "fruit": "food", "bowl": "food", "skewer": "food",
	"bottle": "glass", "pot": "glass", "bone": "bone",
}
const MIN_GAP_MSEC := 60
const WORK_DB := -18.0
const WORK_TYPES := {"cordage": "twine", "stone_axe": "knap", "stone_knife": "knap", "wooden_spear": "carve", "spear": "bind", "torch": "bind", "campfire": "stack"}
const EAT := {"crunch": ["eat_crunch", -15.0], "soft": ["eat_soft", -17.0], "drink": ["drink_gulp", -16.0],
	"poultice": ["heal_poultice", -16.0], "bandage": ["heal_bandage", -16.0]}
const EAT_KINDS := {"roast_forage": "crunch", "tree_roots": "crunch", "seed_bundle": "crunch"}   # by item id; other food is soft
# An item id ending in one of these is crunchy (nuts, roots, hard fruit); "sap" is drunk; poultices and bandages heal.
const CRUNCHY := ["nuts", "roots", "bulbs", "apples", "pears", "acorns", "chestnuts", "walnuts", "hazelnuts", "beechnuts", "coconuts", "dates", "roast_forage"]
const DRINKS := ["sap", "water"]
const GROWL_DB := -20.0
const GROWL_EVERY_SEC := [50.0, 110.0]  # while hungry (hunger at or under growl_from); starving growls twice as often
const GROWL_FROM := 15
const COOKING_DIR := "res://assets/audio/cooking/"
const COOKING_RECORDED_DIR := "res://assets/audio/recorded/cooking/"
const FUEL_WINDOW_MSEC := 1500
const WORK_PREFIXES := {"poultice": "pound", "bandage": "wrap"}

var played: int = 0
var last: String = ""

var _streams: Dictionary = {}
var _player: AudioStreamPlayer
var _last_msec: int = -1000
var _rng := RandomNumberGenerator.new()
var _was_open: bool = false
var _was_chest: bool = false
var hotbar_played: int = 0
var _total: int = -1
var _numbers: PackedInt32Array = PackedInt32Array()
var _was_crafting: int = 0
var _work: AudioStreamPlayer
var work_played: int = 0
var eat_played: int = 0
var growls_played: int = 0
var _growl_left: float = 60.0
var _mouth: AudioStreamPlayer
var _fuel_msec: int = -100000
var _counts_by_number: Dictionary = {}  # item number -> count in the bag, last watch
var last_work: String = ""


func setup(_stage) -> void:
	_rng.randomize()
	SoundStage._make_bus("Interface")
	_player = AudioStreamPlayer.new()
	_player.bus = "Interface"
	add_child(_player)
	_work = AudioStreamPlayer.new()
	_work.bus = "Foley"
	add_child(_work)
	_mouth = AudioStreamPlayer.new()
	_mouth.bus = "Foley"
	add_child(_mouth)


# A hotbar slot chosen (0 to 7): a quiet tick, a touch higher for the higher slots.
# THE CALL POINT for refused actions (Items job 62 sends the server's reject event: too far, no tool, pack full):
#   sound.itemfx.reject("far" | "no_tool" | "full_pack" | anything else)
# A soft double knock; the reason only changes the pitch a little ("far" higher, "full_pack" lower) so repeats differ.
# Rate limited to one per REJECT_GAP_MSEC so a held key never nags. Returns whether it played.
const REJECT_GAP_MSEC := 600
const REJECT_PITCH := {"far": 1.08, "no_tool": 1.0, "full_pack": 0.9}
var rejects_played: int = 0
var _last_reject_msec: int = -100000


func reject(reason: String = "") -> bool:
	var now: int = Time.get_ticks_msec()

	if now - _last_reject_msec < REJECT_GAP_MSEC:
		return false

	_last_reject_msec = now

	if not play("item_reject", float(REJECT_PITCH.get(reason, 1.0))):
		return false

	rejects_played += 1
	return true


func hotbar(slot: int) -> void:
	hotbar_played += 1
	play("hotbar_tick", 0.94 + 0.02 * float(clampi(slot, 0, 7)))


# "item_pickup" or "item_drop" with the material class of the item that changed (its own sound when it has one, else the plain cue).
func _class_sound(base: String, inv, items, gained: bool) -> String:
	var counts: Dictionary = {}

	for i in inv.numbers.size():
		if inv.numbers[i] != 0:
			counts[inv.numbers[i]] = int(counts.get(inv.numbers[i], 0)) + int(inv.counts[i])

	for number in (counts if gained else _counts_by_number):
		var before: int = int(_counts_by_number.get(number, 0))
		var after: int = int(counts.get(number, 0))

		if (after > before) if gained else (after < before):
			var shape: String = str(BasicLook.entry(str(items.table.id_of(int(number)))).get("shape", ""))
			var named: String = "%s_%s" % [base, SHAPE_CLASS.get(shape, "")]

			if SHAPE_CLASS.has(shape) and NAMES.has(named):
				return named

			break

	return base


func watch(items) -> void:
	if items == null or items.inventory == null:
		return

	var inv = items.inventory
	var total: int = 0

	for c in inv.counts:
		total += c

	if _total >= 0:
		if total > _total:
			play(_class_sound("item_pickup", inv, items, true))
		elif total < _total:
			play(_class_sound("item_drop", inv, items, false))
		elif inv.numbers != _numbers:
			play("item_swap")

	_total = total
	_numbers = inv.numbers.duplicate()

	if items.open != _was_open:
		_was_open = items.open
		play("inv_open" if items.open else "inv_close")

	if bool(items.chest_mode) != _was_chest:
		_was_chest = bool(items.chest_mode)
		play("inv_open" if _was_chest else "inv_close")               # the chest screen, besides the chest's own creak (placed_sounds)

	_watch_wear(items, inv)

	var crafting: int = int(items.get("_crafting"))

	if _was_crafting == 0 and crafting != 0:
		play("craft_start")
		_start_work(items, crafting)

	if _was_crafting != 0 and crafting == 0:
		_work.stop()
		play("craft_done")

	_was_crafting = crafting
	_watch_fire(items, inv)


# A log gone and firewood come in at the same moment (the server split one at the chopping block): the block
# nearest the player rings with the split.
# A tool in the pack wearing under WARN_CONDITION (same tool in the slot as last time) complains once, the warning
# before it breaks. Condition 1 new down to 0 broken (items.condition).
const WARN_CONDITION := 0.2
var _condition: Dictionary = {}         # slot -> [item number, condition] last watch
var warns_played: int = 0


func _watch_wear(items, inv) -> void:
	for slot in range(inv.numbers.size()):
		var number: int = inv.numbers[slot]

		if number == 0 or int(items.table.entry(items.table.id_of(number)).get("durability", 0)) <= 0:
			_condition.erase(slot)
			continue

		var now_condition: float = items.condition(slot)
		var before: Array = _condition.get(slot, [])
		_condition[slot] = [number, now_condition]

		if before.size() == 2 and before[0] == number and float(before[1]) > WARN_CONDITION and now_condition <= WARN_CONDITION and now_condition > 0.0:
			if get_parent().placed.tool_warn(items._player_position.call()):
				warns_played += 1


func _watch_block(items, counts: Dictionary) -> void:
	var log_n: int = items.table.number_of("log")
	var wood_n: int = items.table.number_of("firewood")

	if int(counts.get(log_n, 0)) >= int(_counts_by_number.get(log_n, 0)) or int(counts.get(wood_n, 0)) <= int(_counts_by_number.get(wood_n, 0)):
		return

	var here: Vector3 = items._player_position.call()
	var best: Vector3 = here
	var best_d: float = 5.0

	for id in items._world:
		var row: Dictionary = items._world[id]

		if int(row["state"]) == 7 and here.distance_to(row["pos"]) < best_d:
			best_d = here.distance_to(row["pos"])
			best = row["pos"]

	if best_d < 5.0:
		get_parent().workshop.chop(best, true)


# A hungry stomach growls now and then (hunger 0 to 100, the Items thread's `hunger`): every 50 to 110 s at or
# under 15 percent, twice as often when starving; quiet, at the player, never while swimming or the like.
func watch_vitals(hunger: int, delta: float) -> void:
	if hunger > GROWL_FROM:
		_growl_left = _rng.randf_range(float(GROWL_EVERY_SEC[0]), float(GROWL_EVERY_SEC[1]))
		return

	_growl_left -= delta * (2.0 if hunger <= 0 else 1.0)

	if _growl_left > 0.0:
		return

	_growl_left = _rng.randf_range(float(GROWL_EVERY_SEC[0]), float(GROWL_EVERY_SEC[1]))
	var list: Array = _variants("stomach_growl")

	if list.is_empty():
		return

	var pick: int = _rng.randi_range(0, list.size() - 1)
	_mouth.stream = list[pick]
	_mouth.volume_db = GROWL_DB + _rng.randf_range(-1.0, 1.0)
	_mouth.pitch_scale = _rng.randf_range(0.95, 1.05)
	_mouth.play()
	growls_played += 1
	last = "stomach_growl_%d (%s)" % [pick, SoundStage.tag(list[pick])]


# The V key at a fire: wood used up in the next moments was laid on it.
func fuel_pressed() -> void:
	_fuel_msec = Time.get_ticks_msec()


# The eating kind of an item id: "poultice", "bandage", "drink", "crunch" or "soft".
static func eat_kind(item_id: String) -> String:
	if item_id.begins_with("poultice"):
		return "poultice"

	if item_id.begins_with("bandage"):
		return "bandage"

	if EAT_KINDS.has(item_id):
		return str(EAT_KINDS[item_id])

	for word in DRINKS:
		if item_id.ends_with(word):
			return "drink"

	for word in CRUNCHY:
		if item_id.ends_with(word):
			return "crunch"

	return "soft"


# Eating or applying: "crunch", "soft", "drink", "poultice", "bandage", or an item id (the Items thread calls
# this from `eat_event` when the server confirms the food or medicine took effect).
func eat(kind: String) -> bool:
	var entry: Array = EAT.get(kind, EAT.get(eat_kind(kind)))
	var list: Array = _variants(str(entry[0]))

	if list.is_empty():
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	_mouth.stream = list[pick]
	_mouth.volume_db = float(entry[1]) + _rng.randf_range(-1.0, 1.0)
	_mouth.pitch_scale = _rng.randf_range(0.95, 1.05)
	_mouth.play()
	eat_played += 1
	last = "%s_%d (%s)" % [entry[0], pick, SoundStage.tag(list[pick])]
	return true


# A roast that appeared, or wood that went into a fire, sounds at the nearest fire.
func _watch_fire(items, inv) -> void:
	var counts: Dictionary = {}

	for n in range(inv.numbers.size()):
		counts[inv.numbers[n]] = int(counts.get(inv.numbers[n], 0)) + int(inv.counts[n])

	if not _counts_by_number.is_empty():
		_watch_block(items, counts)

	if not _counts_by_number.is_empty() and items.has_method("_nearest_fire"):
		var roast: int = items.table.number_of("roast_forage")
		var wood: Array = [items.table.number_of("stick"), items.table.number_of("log")]
		var cooked: bool = int(counts.get(roast, 0)) > int(_counts_by_number.get(roast, 0))
		var fuelled: bool = false

		if Time.get_ticks_msec() - _fuel_msec < FUEL_WINDOW_MSEC:
			for number in wood:
				fuelled = fuelled or int(counts.get(number, 0)) < int(_counts_by_number.get(number, 0))

		if cooked or fuelled:
			var fire: int = items._nearest_fire()

			if fire != 0 and items._world.has(fire):
				if cooked:
					_stage_fire().cook(items._world[fire]["pos"])

				if fuelled:
					_fuel_msec = -100000
					_stage_fire().fuel(items._world[fire]["pos"])

	_counts_by_number = counts


func _stage_fire():
	return get_parent().fire


func work_type(recipe: Dictionary) -> String:
	if recipe.has("sound"):
		return str(recipe["sound"])

	var id: String = str(recipe.get("id", ""))

	if WORK_TYPES.has(id):
		return WORK_TYPES[id]

	for prefix in WORK_PREFIXES:
		if id.begins_with(prefix):
			return WORK_PREFIXES[prefix]

	return "knap"


func _start_work(items, number: int) -> void:
	var kind: String = work_type(items.recipes.recipe(number))
	var list: Array = _variants("craft_" + kind)

	if list.is_empty():
		list = _variants("craft_knap")

	if list.is_empty():
		return

	var pick: int = _rng.randi_range(0, list.size() - 1)
	_work.stream = list[pick]
	_work.volume_db = WORK_DB + _rng.randf_range(-1.0, 1.0)
	_work.pitch_scale = _rng.randf_range(0.97, 1.03)
	_work.play()
	work_played += 1
	last_work = "craft_%s_%d (%s)" % [kind, pick, SoundStage.tag(list[pick])]
	last = last_work


func play(sound_name: String, pitch: float = 1.0) -> bool:
	if not NAMES.has(sound_name):
		return false

	var now: int = Time.get_ticks_msec()

	if now - _last_msec < MIN_GAP_MSEC:
		return false

	var list: Array = _variants(sound_name)

	if list.is_empty():
		return false

	_last_msec = now
	var pick: int = _rng.randi_range(0, list.size() - 1)
	_player.stream = list[pick]
	_player.volume_db = float(NAMES[sound_name]) + _rng.randf_range(-1.0, 1.0)
	_player.pitch_scale = pitch * _rng.randf_range(0.96, 1.04)
	_player.play()
	played += 1
	last = "%s_%d (%s)" % [sound_name, pick, SoundStage.tag(list[pick])]
	return true


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var crafting: bool = sound_name.begins_with("craft_") and sound_name != "craft_done"
	var eating: bool = sound_name.begins_with("eat_") or sound_name == "drink_gulp" or sound_name.begins_with("heal_") or sound_name == "stomach_growl"
	var list: Array = SoundStage._find(CRAFT_RECORDED_DIR if crafting else (COOKING_RECORDED_DIR if eating else RECORDED_DIR), sound_name)

	if list.is_empty():
		list = SoundStage._find(CRAFT_DIR if crafting else (COOKING_DIR if eating else GENERATED_DIR), sound_name)

	_streams[sound_name] = list
	return list
