extends Node

# Item sounds (client only): small cues for the inventory, on the Interface bus. Nothing here knows
# the item rules; it watches the inventory the Items thread keeps and hears what changed.
#
#   sound.itemfx.watch(items)      call every frame; plays the cue for what changed since last frame
#   sound.itemfx.play("item_pickup")   or any name below, directly
#
# Cues: item_pickup (stacks grew), item_drop (stacks shrank), inv_open, inv_close, item_swap (slots
# rearranged), craft_done (a craft finished: the inventory's crafting number went back to 0).
# Sounds: generated in assets/audio/items/ (make_items.py); recordings in assets/audio/recorded/items/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/items/"
const RECORDED_DIR := "res://assets/audio/recorded/items/"
const NAMES := {"item_pickup": -17.0, "item_drop": -17.0, "inv_open": -20.0, "inv_close": -21.0, "item_swap": -20.0, "craft_done": -16.0}
const MIN_GAP_MSEC := 60

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


func setup(_stage) -> void:
	_rng.randomize()
	SoundStage._make_bus("Interface")
	_player = AudioStreamPlayer.new()
	_player.bus = "Interface"
	add_child(_player)


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

	if _was_crafting != 0 and crafting == 0:
		play("craft_done")

	_was_crafting = crafting


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
	last = "%s_%d" % [name, pick]
	return true


func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = SoundStage._find(RECORDED_DIR, name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, name)

	_streams[name] = list
	return list
