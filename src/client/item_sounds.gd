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
const NAMES := {"item_pickup": -17.0, "item_drop": -17.0, "inv_open": -20.0, "inv_close": -21.0, "item_swap": -20.0, "craft_done": -16.0}
const MIN_GAP_MSEC := 60
const WORK_DB := -18.0
const WORK_TYPES := {"cordage": "twine", "stone_axe": "knap", "stone_knife": "knap", "wooden_spear": "carve", "spear": "bind", "torch": "bind", "campfire": "stack"}
const EAT := {"crunch": ["eat_crunch", -15.0], "soft": ["eat_soft", -17.0], "drink": ["drink_gulp", -16.0]}
const EAT_KINDS := {"roast_forage": "crunch", "tree_roots": "crunch", "seed_bundle": "crunch"}   # by item id; other food is soft
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
var _total: int = -1
var _numbers: PackedInt32Array = PackedInt32Array()
var _was_crafting: int = 0
var _work: AudioStreamPlayer
var work_played: int = 0
var eat_played: int = 0
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


func watch(items) -> void:
	if items == null or items.inventory == null:
		return

	var inv = items.inventory
	var total: int = 0

	for c in inv.counts:
		total += c

	if _total >= 0:
		if total > _total:
			play("item_pickup")
		elif total < _total:
			play("item_drop")
		elif inv.numbers != _numbers:
			play("item_swap")

	_total = total
	_numbers = inv.numbers.duplicate()

	if items.open != _was_open:
		_was_open = items.open
		play("inv_open" if items.open else "inv_close")

	var crafting: int = int(items.get("_crafting"))

	if _was_crafting == 0 and crafting != 0:
		_start_work(items, crafting)

	if _was_crafting != 0 and crafting == 0:
		_work.stop()
		play("craft_done")

	_was_crafting = crafting
	_watch_fire(items, inv)


# A log gone and firewood come in at the same moment (the server split one at the chopping block): the block
# nearest the player rings with the split.
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


# The V key at a fire: wood used up in the next moments was laid on it.
func fuel_pressed() -> void:
	_fuel_msec = Time.get_ticks_msec()


# Eating: "crunch", "soft" or "drink", or an item id (EAT_KINDS, else soft).
func eat(kind: String) -> bool:
	var entry: Array = EAT.get(kind, EAT.get(EAT_KINDS.get(kind, "soft")))
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


func play(name: String) -> bool:
	if not NAMES.has(name):
		return false

	var now: int = Time.get_ticks_msec()

	if now - _last_msec < MIN_GAP_MSEC:
		return false

	var list: Array = _variants(name)

	if list.is_empty():
		return false

	_last_msec = now
	var pick: int = _rng.randi_range(0, list.size() - 1)
	_player.stream = list[pick]
	_player.volume_db = float(NAMES[name]) + _rng.randf_range(-1.0, 1.0)
	_player.pitch_scale = _rng.randf_range(0.96, 1.04)
	_player.play()
	played += 1
	last = "%s_%d (%s)" % [name, pick, SoundStage.tag(list[pick])]
	return true


func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var crafting: bool = name.begins_with("craft_") and name != "craft_done"
	var eating: bool = name.begins_with("eat_") or name == "drink_gulp"
	var list: Array = SoundStage._find(CRAFT_RECORDED_DIR if crafting else (COOKING_RECORDED_DIR if eating else RECORDED_DIR), name)

	if list.is_empty():
		list = SoundStage._find(CRAFT_DIR if crafting else (COOKING_DIR if eating else GENERATED_DIR), name)

	_streams[name] = list
	return list
