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

	for key in ["skin", "hair"]:
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
