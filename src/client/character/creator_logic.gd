extends RefCounted

# The logic of the character creator (Sonny, plan 14 of CHARACTER_DESIGN_VISION.md Part 8; design in Part 5.7): a genome being edited, per-slider locks, a global dice
# button and one per section, undo and redo, archetype presets and the share code. No screens here, so it can be tested without a window
# (tools/check_creator_logic.gd). The screen is scenes/creator_proto/creator_proto.gd.
#
# Dice are gentle by default: values are drawn from a bell-shaped spread around the neutral body (so results look like people); "wild" draws from the whole range.
# A locked slider is never changed by any dice, and a section dice never touches another section. Every dice press and every edit can be undone.

const Generator := preload("res://src/client/character/body_generator.gd")

const SECTIONS := {
	"Body": ["height", "build", "muscle", "belly", "chest", "bust", "shoulders", "hips", "torso", "legs", "arms", "neck"],
	"Head and face": ["head", "jaw", "nose", "brow", "ears"],
	"Hands and feet": ["hands", "feet"],
	"Hair": ["hair_length"],
}
const COLOR_SECTIONS := {"Hair": ["hair"], "Skin": ["skin"], "Tunic": ["tunic"], "Trousers": ["trousers"], "Boots": ["boots"]}   # colours have their own dice in the Skin and Hair sections
const SKINS := [Color(0.93, 0.78, 0.66), Color(0.85, 0.66, 0.52), Color(0.72, 0.52, 0.38), Color(0.55, 0.38, 0.27), Color(0.42, 0.28, 0.2), Color(0.32, 0.21, 0.15)]
const HAIRS := [Color(0.08, 0.06, 0.05), Color(0.25, 0.16, 0.09), Color(0.45, 0.28, 0.12), Color(0.7, 0.55, 0.25), Color(0.55, 0.2, 0.1), Color(0.6, 0.58, 0.55), Color(0.85, 0.82, 0.75)]
const CLOTHS := [Color(0.36, 0.45, 0.3), Color(0.52, 0.34, 0.42), Color(0.35, 0.4, 0.5), Color(0.55, 0.42, 0.22), Color(0.5, 0.25, 0.2), Color(0.28, 0.25, 0.22), Color(0.62, 0.58, 0.5), Color(0.2, 0.2, 0.26)]
const COLOR_NAMES := ["skin", "hair", "tunic", "trousers", "boots"]       # the colours a person can set
const UNDO_LIMIT := 60
const GENTLE_SIGMA := 0.35
const WILD_SIGMA := 0.75

var genome: Dictionary = {}
var locks: Dictionary = {}          # slider or colour name -> true
var wild: bool = false
var _undo: Array = []
var _redo: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(start: Dictionary = {}, seed_value: int = -1) -> void:
	genome = start.duplicate(true) if not start.is_empty() else Generator.make_genome("average")

	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


# ---------------------------------------------------------------- edits (each one can be undone)

func _remember() -> void:
	_undo.append(genome.duplicate(true))

	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()

	_redo.clear()


# A drag on a slider is one undo step: begin_edit when the drag starts, then set_slider_live for every change during it.
func begin_edit() -> void:
	_remember()


func set_slider_live(name: String, value: float) -> void:
	if name in Generator.SLIDERS:
		genome[name] = clampf(value, -1.0, 1.0)


func set_color_live(name: String, color: Color) -> void:
	if name in COLOR_NAMES:
		genome[name] = color

		if name == "skin":
			genome["lips"] = color.lerp(Color(0.7, 0.25, 0.25), 0.5)


func set_slider(name: String, value: float) -> void:
	if not (name in Generator.SLIDERS):
		return

	_remember()
	genome[name] = clampf(value, -1.0, 1.0)


func set_color(name: String, color: Color) -> void:
	if not (name in COLOR_NAMES):
		return

	_remember()
	genome[name] = color

	if name == "skin":
		genome["lips"] = color.lerp(Color(0.7, 0.25, 0.25), 0.5)


func set_lock(name: String, on: bool) -> void:
	if on:
		locks[name] = true
	else:
		locks.erase(name)


func is_locked(name: String) -> bool:
	return locks.has(name)


func apply_preset(preset: String) -> void:
	if not Generator.PRESETS.has(preset):
		return

	_remember()
	var fresh: Dictionary = Generator.make_genome(preset, genome["skin"], genome["hair"])

	# Locked sliders keep their value.
	for key in Generator.SLIDERS:
		if not locks.has(key):
			genome[key] = fresh[key]


# Forgets undo and redo (the starting frame of a new creator is not a step to undo).
func clear_history() -> void:
	_undo.clear()
	_redo.clear()


# A body frame (Generator.FRAMES): sets hips, chest, bust, shoulders, belly and neck and the default clothing colours as a starting point. Locked values keep theirs. One undo step.
func apply_frame(frame: String) -> void:
	if not Generator.FRAMES.has(frame):
		return

	_remember()

	for key in Generator.FRAMES[frame]:
		if not locks.has(key):
			genome[key] = Generator.FRAMES[frame][key]


func set_hair_style(index: int) -> void:
	if index < 0 or index >= Generator.HAIR_STYLES.size() or index == int(genome.get("hair_style", 0)):
		return

	_remember()
	genome["hair_style"] = index


func _draw() -> float:
	return clampf(_rng.randfn(0.0, WILD_SIGMA if wild else GENTLE_SIGMA), -1.0, 1.0)


# One dice for one section ("Body", "Head and face", "Hands and feet", "Hair", "Skin"); unlocked values only. Returns the names that changed.
func dice_section(section: String) -> Array:
	var changed: Array = []
	_remember()

	if SECTIONS.has(section):
		for key in SECTIONS[section]:
			if not locks.has(key):
				genome[key] = _draw()
				changed.append(key)

	if section == "Hair" and not locks.has("hair_style"):
		genome["hair_style"] = _rng.randi() % Generator.HAIR_STYLES.size()
		changed.append("hair_style")

	if COLOR_SECTIONS.has(section):
		for key in COLOR_SECTIONS[section]:
			if not locks.has(key):
				var palette: Array = SKINS if key == "skin" else (HAIRS if key == "hair" else CLOTHS)
				genome[key] = palette[_rng.randi() % palette.size()]
				changed.append(key)

				if key == "skin":
					genome["lips"] = (genome["skin"] as Color).lerp(Color(0.7, 0.25, 0.25), 0.5)

	if changed.is_empty():
		_undo.pop_back()       # nothing changed (all locked): no undo step

	return changed


# The global dice: every section.
func dice_all() -> Array:
	var changed: Array = []
	_remember()
	var before: int = _undo.size()

	for section in SECTIONS:
		changed.append_array(_dice_without_undo(section))

	for section in COLOR_SECTIONS:
		changed.append_array(_dice_without_undo(section))

	if changed.is_empty() and _undo.size() == before:
		_undo.pop_back()

	return changed


func _dice_without_undo(section: String) -> Array:
	var saved_undo: Array = _undo.duplicate()
	var changed: Array = dice_section(section)
	_undo = saved_undo       # the global dice is one undo step, made by dice_all
	return changed


# ---------------------------------------------------------------- undo and redo

func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false

	_redo.append(genome.duplicate(true))
	genome = _undo.pop_back()
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false

	_undo.append(genome.duplicate(true))
	genome = _redo.pop_back()
	return true


# ---------------------------------------------------------------- share code

func code() -> String:
	return Generator.encode(genome)


# Loads a share code; false (and nothing changed) when the text is not a valid code. Slider values come back to within 1/127.
func load_code(text: String) -> bool:
	var loaded: Dictionary = Generator.decode(text)

	if loaded.is_empty():
		return false

	_remember()
	genome = loaded

	# Colours the code does not carry keep their current value.
	for key in ["tunic", "trousers", "boots"]:
		if not genome.has(key):
			genome[key] = Generator.make_genome("average")[key]

	return true
