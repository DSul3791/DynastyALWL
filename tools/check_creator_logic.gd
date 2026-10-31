extends SceneTree

# Headless check of src/client/character/creator_logic.gd (Sonny, plan 14): locks, section dice, global dice, undo and redo, presets and the share code.
#   godot --headless --path . --script res://tools/check_creator_logic.gd
# Exit code 1 on any failure.

const Logic := preload("res://src/client/character/creator_logic.gd")
const Generator := preload("res://src/client/character/body_generator.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	_check_locks_and_sections()
	_check_ranges_and_wild()
	_check_undo()
	_check_presets()
	_check_code()
	_check_seed()
	_check_frames()
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


func _check_locks_and_sections() -> void:
	var c: RefCounted = Logic.new({}, 1)
	c.set_slider("height", 0.5)
	c.set_slider("jaw", -0.3)
	c.set_lock("height", true)
	_ok(c.is_locked("height") and not c.is_locked("jaw"), "a lock is remembered")

	for _i in range(20):
		c.dice_all()
		_ok(is_equal_approx(float(c.genome["height"]), 0.5), "the global dice never changes a locked slider")

	var before: Dictionary = c.genome.duplicate(true)
	var changed: Array = c.dice_section("Head and face")

	for key in Logic.SECTIONS["Body"]:
		_ok(is_equal_approx(float(c.genome[key]), float(before[key])), "the face dice does not touch the body slider " + key)

	for key in Logic.SECTIONS["Hands and feet"]:
		_ok(is_equal_approx(float(c.genome[key]), float(before[key])), "the face dice does not touch " + key)

	_ok((c.genome["skin"] as Color) == (before["skin"] as Color), "the face dice does not touch the skin colour")
	_ok(changed.size() == Logic.SECTIONS["Head and face"].size(), "the face dice changes every unlocked face slider (%d)" % changed.size())
	# The skin dice changes only the skin colour.
	var skin_before: Dictionary = c.genome.duplicate(true)
	var skin_changed: Array = c.dice_section("Skin")
	_ok(skin_changed == ["skin"], "the skin dice changes only the skin colour")

	for key in Generator.SLIDERS:
		_ok(is_equal_approx(float(c.genome[key]), float(skin_before[key])), "the skin dice does not touch slider " + key)

	# Everything locked: no change and no undo step.
	var all: RefCounted = Logic.new({}, 2)

	for key in Generator.SLIDERS:
		all.set_lock(key, true)

	for key in Logic.COLOR_NAMES:
		all.set_lock(key, true)

	var h: Dictionary = all.genome.duplicate(true)
	var undo_before: bool = all.can_undo()
	all.dice_all()
	_ok(all.genome.hash() == h.hash(), "with everything locked the dice change nothing")
	_ok(all.can_undo() == undo_before, "and make no undo step")


func _check_ranges_and_wild() -> void:
	var gentle: RefCounted = Logic.new({}, 3)
	var wild: RefCounted = Logic.new({}, 3)
	wild.wild = true
	var gentle_sum: float = 0.0
	var wild_sum: float = 0.0

	for _i in range(300):
		gentle.dice_section("Body")
		wild.dice_section("Body")

		for key in Logic.SECTIONS["Body"]:
			var gv: float = float(gentle.genome[key])
			var wv: float = float(wild.genome[key])
			_ok(gv >= -1.0 and gv <= 1.0 and wv >= -1.0 and wv <= 1.0, "dice values stay in -1 to 1")
			gentle_sum += absf(gv)
			wild_sum += absf(wv)

	_ok(gentle_sum < wild_sum * 0.7, "gentle dice stay closer to the neutral body than wild dice (%.0f vs %.0f)" % [gentle_sum, wild_sum])
	var c: RefCounted = Logic.new({}, 4)
	c.set_slider("height", 5.0)
	_ok(is_equal_approx(float(c.genome["height"]), 1.0), "a slider value is clamped to 1")
	c.set_slider("no_such_slider", 0.3)
	_ok(not c.genome.has("no_such_slider"), "an unknown slider name is ignored")


func _check_undo() -> void:
	var c: RefCounted = Logic.new({}, 5)
	var start: Dictionary = c.genome.duplicate(true)
	c.set_slider("build", 0.6)
	c.dice_all()
	var after_dice: Dictionary = c.genome.duplicate(true)
	c.dice_section("Body")
	_ok(c.undo(), "undo works")
	_ok(c.genome.hash() == after_dice.hash(), "one undo undoes only the last dice")
	_ok(c.can_redo() and c.redo(), "redo works")
	c.undo()
	c.undo()
	_ok(is_equal_approx(float(c.genome["build"]), 0.6), "undoing the global dice is one step (back to the slider edit)")
	c.undo()
	_ok(c.genome.hash() == start.hash(), "undo all the way gives the starting body")
	_ok(not c.undo(), "nothing left to undo")
	c.set_slider("legs", 0.2)
	_ok(not c.can_redo(), "a new edit clears redo")

	for i in range(Logic.UNDO_LIMIT + 20):
		c.set_slider("arms", float(i % 10) / 10.0)

	var steps: int = 0

	while c.undo():
		steps += 1

	_ok(steps == Logic.UNDO_LIMIT, "the undo history is limited to %d steps (%d)" % [Logic.UNDO_LIMIT, steps])


func _check_presets() -> void:
	var c: RefCounted = Logic.new({}, 6)
	c.set_slider("height", -0.8)
	c.set_lock("height", true)
	c.apply_preset("broad")
	_ok(is_equal_approx(float(c.genome["height"]), -0.8), "a preset keeps a locked slider")
	_ok(float(c.genome["shoulders"]) > 0.5, "a preset sets the others (broad shoulders)")
	c.apply_preset("no_such_preset")
	_ok(float(c.genome["shoulders"]) > 0.5, "an unknown preset is ignored")


func _check_code() -> void:
	var c: RefCounted = Logic.new({}, 7)
	c.dice_all()
	var text: String = c.code()
	var d: RefCounted = Logic.new({}, 8)
	_ok(d.load_code(text), "a share code loads")

	for key in Generator.SLIDERS:
		_ok(absf(float(d.genome[key]) - float(c.genome[key])) < 0.008, "the share code keeps slider " + key)

	_ok(absf((d.genome["skin"] as Color).r - (c.genome["skin"] as Color).r) < 0.005, "the share code keeps the skin colour")
	var before: Dictionary = d.genome.duplicate(true)
	_ok(not d.load_code("nonsense"), "a bad code is refused")
	_ok(d.genome.hash() == before.hash(), "and changes nothing")
	var e: RefCounted = Logic.new({}, 9)
	var e_start: Dictionary = e.genome.duplicate(true)
	e.load_code(text)
	_ok(e.genome.hash() != e_start.hash(), "loading a code changes the body")
	e.undo()
	_ok(e.genome.hash() == e_start.hash(), "loading a code is one undo step")


func _check_seed() -> void:
	var a: RefCounted = Logic.new({}, 99)
	var b: RefCounted = Logic.new({}, 99)
	a.dice_all()
	b.dice_all()
	_ok(a.genome.hash() == b.genome.hash(), "the same seed gives the same dice")
	var c: RefCounted = Logic.new({}, 100)
	c.dice_all()
	_ok(a.genome.hash() != c.genome.hash(), "a different seed gives a different result")


# Frames (Generator.FRAMES): starting values only; locks, undo and every slider and colour keep working; a version 1 share code still loads and its body has no chest.
func _check_frames() -> void:
	var Record = load("res://src/client/character/character_record.gd")

	for frame in ["feminine", "masculine", "neutral"]:
		var a: RefCounted = Logic.new({}, 5)
		a.apply_frame(frame)

		for key in Generator.FRAMES[frame]:
			_ok(a.genome[key] == Generator.FRAMES[frame][key], "frame %s sets %s" % [frame, key])

		_ok(a.can_undo(), "frame %s is one undo step" % frame)
		a.undo()
		_ok(float(a.genome["hips"]) == 0.0 and float(a.genome["chest"]) == Generator.CHEST_NONE, "undo takes frame %s back" % frame)

		a.apply_frame(frame)
		a.set_slider("hips", -0.9)
		a.set_color("tunic", Color(0.1, 0.2, 0.3))
		_ok(float(a.genome["hips"]) == -0.9 and (a.genome["tunic"] as Color).is_equal_approx(Color(0.1, 0.2, 0.3)), "after frame %s every slider and clothing colour can still be changed" % frame)
		a.dice_section("Body")
		_ok(float(a.genome["hips"]) != -0.9, "and the dice still work after frame %s" % frame)

	var locked: RefCounted = Logic.new({}, 6)
	locked.set_slider("hips", 0.2)
	locked.set_lock("hips", true)
	locked.set_lock("tunic", true)
	var tunic_before: Color = locked.genome["tunic"]
	locked.apply_frame("feminine")
	_ok(float(locked.genome["hips"]) == 0.2 and (locked.genome["tunic"] as Color).is_equal_approx(tunic_before) and float(locked.genome["chest"]) == 0.3, "a frame leaves locked values alone and sets the rest")
	_ok(Generator.FRAMES.keys().size() == 3 and Record.FRAMES.size() == 3, "three frames")
	_ok(Record.default_frame("woman") == "feminine" and Record.default_frame("man") == "masculine" and Record.default_frame("non_binary") == "neutral" and Record.default_frame("prefer_not_to_say") == "neutral", "gender picks its default frame")
	_ok(Record.default_pronouns("woman") == "she_her" and Record.default_pronouns("man") == "he_him" and Record.default_pronouns("non_binary") == "they_them" and Record.default_pronouns("prefer_not_to_say") == "they_them", "gender picks its default pronouns")

	# The chest: an old genome has none and its body does not change; a feminine frame adds a visible bump.
	var plain: Dictionary = Generator.make_genome("average")
	var bust: Dictionary = plain.duplicate(true)
	bust["chest"] = 0.6
	var rg: Dictionary = Generator.rig(plain)
	_ok(Generator.primitives(plain, rg, false).size() + 4 == Generator.primitives(bust, Generator.rig(bust), false).size(), "a chest value adds two primitives and their cloth and none leaves the body as it was")

	# Version 1 code: 18 sliders, no chest.
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(1)

	for i in range(Generator.SLIDERS_V1):
		bytes.append(128)

	for i in range(15):
		bytes.append(100)

	bytes.append(Generator._crc8(bytes))
	var old: Dictionary = Generator.decode(Marshalls.raw_to_base64(bytes))
	_ok(not old.is_empty() and float(old["chest"]) == Generator.CHEST_NONE and absf(float(old["height"])) < 0.01, "a version 1 share code still loads, with no chest")
	var again: Dictionary = Generator.decode(Generator.encode(Generator.make_genome("average")))
	_ok(not again.is_empty() and float(again["chest"]) == Generator.CHEST_NONE, "a version 2 code carries the chest")
	bust["chest"] = 0.6
	_ok(absf(float(Generator.decode(Generator.encode(bust))["chest"]) - 0.6) < 0.01, "and keeps its value")
