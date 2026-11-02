extends SceneTree

# Headless check (Sonny, plan 22): the character record of src/client/character/character_record.gd. Rolls are repeatable, bounded and fair against the point pool; point buy
# cannot overspend; a server-style validation accepts good records and rejects bad ones; the text form round-trips. Draft numbers, no game connection.
#   godot --headless --path . --script res://tools/check_character_record.gd
# Exit code 1 on any failure.

const Record := preload("res://src/client/character/character_record.gd")
const Generator := preload("res://src/client/character/body_generator.gd")

const ANCESTRIES := ["human", "elf", "orc"]

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	_check_roll()
	_check_points()
	_check_validate()
	_check_text()
	_check_identity()
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


func _good() -> Dictionary:
	var rec: Dictionary = Record.blank()
	rec["name"] = "Hob Fennel"
	rec["ancestry"] = "human"
	rec["genome_code"] = Generator.encode(Generator.make_genome("average"))
	rec["background"] = "river_fisher"
	rec["fear"] = 2
	return rec


func _check_roll() -> void:
	var sum: float = 0.0
	var lowest: int = 1000
	var highest: int = -1000
	var thrown_again: int = 0
	var n: int = 3000

	for s in range(n):
		var r: Dictionary = Record.roll(s)
		var total: int = 0

		for a in Record.ATTRIBUTES:
			var v: int = int((r["base"] as Dictionary)[a])
			total += v
			lowest = mini(lowest, v)
			highest = maxi(highest, v)

		sum += float(total)
		thrown_again += 1 if int(r["tries"]) > 1 else 0
		_ok(total >= Record.ROLL_FLOOR and total <= Record.ROLL_CEILING, "seed %d: the rolled total %d is inside the floor and ceiling" % [s, total])

		if s < 50:
			_ok(Record.roll(s)["base"] == r["base"], "seed %d rolls the same twice" % s)

	var mean: float = sum / float(n)
	print("roll: mean total %.2f over %d rolls (point pool %d); each value from %d to %d; %d rolls were thrown again" % [mean, n, Record.POOL, lowest, highest, thrown_again])
	_ok(absf(mean - float(Record.POOL)) < 0.5, "a roll averages about the pool (%.2f vs %d)" % [mean, Record.POOL])
	_ok(lowest >= -1 and highest <= 5, "every rolled value stays in -1 to 5")
	_ok(Record.roll(1)["base"] != Record.roll(2)["base"], "different seeds roll differently")


func _check_points() -> void:
	_ok(Record.points_spent(Record.blank()["base"]) == 0, "a blank record spends nothing")
	var base: Dictionary = Record.blank()["base"]
	base["strength"] = 6
	_ok(Record.points_spent(base) == 9, "+6 costs 9 points (%d)" % Record.points_spent(base))
	base["courage"] = -3
	_ok(Record.points_spent(base) == 6, "-3 gives back 3 points (%d)" % Record.points_spent(base))
	_ok(Record.step_cost(0) == 1 and Record.step_cost(3) == 2 and Record.step_cost(5) == 2 and Record.step_cost(6) == -1 and Record.step_cost(-2) == 1, "step costs: 1 up to +3, 2 up to +6, none beyond")
	var rec: Dictionary = _good()
	var spend: Dictionary = rec["base"]
	spend["strength"] = 6
	spend["fitness"] = 3
	spend["luck"] = 2
	_ok(Record.points_spent(spend) == 14 and Record.validate(rec, ANCESTRIES).is_empty(), "exactly the whole pool (14) is accepted")
	spend["memory"] = 1
	_ok(not Record.validate(rec, ANCESTRIES).is_empty(), "one point more than the pool is refused")
	var attrs: Dictionary = Record.final_attributes(_good())
	_ok(int(attrs["wisdom"]) == 1 and int(attrs["strength"]) == 0, "the background adds its nudge (river fisher: wisdom +1)")
	var capped: Dictionary = _good()
	capped["background"] = "hermits_student"
	(capped["base"] as Dictionary)["wisdom"] = 6
	_ok(int(Record.final_attributes(capped)["wisdom"]) == 8, "the nudge adds on top of a bought value")


func _check_validate() -> void:
	_ok(Record.validate(_good(), ANCESTRIES).is_empty(), "a good record passes")
	var bad: Dictionary = _good()
	bad["name"] = ""
	_ok(not Record.validate(bad, ANCESTRIES).is_empty(), "an empty name is refused")
	bad = _good()
	bad["name"] = "X".repeat(Record.NAME_MAX + 1)
	_ok(not Record.validate(bad, ANCESTRIES).is_empty(), "a too long name is refused")
	bad = _good()
	bad["name"] = " Hob"
	_ok(not Record.validate(bad, ANCESTRIES).is_empty(), "a name with a stray space is refused")
	bad = _good()
	bad["ancestry"] = "dragon"
	_ok(not Record.validate(bad, ANCESTRIES).is_empty(), "an unknown ancestry is refused")
	bad = _good()
	bad["background"] = "king"
	_ok(not Record.validate(bad, ANCESTRIES).is_empty(), "an unknown background is refused")
	bad = _good()
	bad["fear"] = 99
	_ok(not Record.validate(bad, ANCESTRIES).is_empty(), "an unknown fear is refused")
	bad = _good()
	bad["genome_code"] = "not a code"
	_ok(not Record.validate(bad, ANCESTRIES).is_empty(), "a broken body code is refused")
	bad = _good()
	(bad["base"] as Dictionary).erase("courage")
	_ok(not Record.validate(bad, ANCESTRIES).is_empty(), "a missing attribute is refused")
	bad = _good()
	(bad["base"] as Dictionary)["strength"] = 9
	_ok(not Record.validate(bad, ANCESTRIES).is_empty(), "a bought value above the cap is refused")
	bad = _good()
	bad["method"] = "cheat"
	_ok(not Record.validate(bad, ANCESTRIES).is_empty(), "an unknown method is refused")
	var rolled: Dictionary = Record.with_roll(_good(), 77, 2)
	_ok(Record.validate(rolled, ANCESTRIES).is_empty(), "a rolled record with its seed passes")
	(rolled["base"] as Dictionary)["luck"] = int((rolled["base"] as Dictionary)["luck"]) + 1
	_ok(not Record.validate(rolled, ANCESTRIES).is_empty(), "a rolled record with an edited value is refused")
	var many: Dictionary = Record.with_roll(_good(), 77, 9)
	_ok(int(many["rerolls"]) == Record.MAX_REROLLS, "re-rolls are capped at %d" % Record.MAX_REROLLS)
	many["rerolls"] = 9
	_ok(not Record.validate(many, ANCESTRIES).is_empty(), "a record claiming too many re-rolls is refused")


func _check_text() -> void:
	var rec: Dictionary = Record.with_roll(_good(), 5, 1)
	var back: Dictionary = Record.from_text(Record.to_text(rec))
	_ok(back == rec, "the text form round-trips exactly")
	_ok(Record.validate(back, ANCESTRIES).is_empty(), "and the record read back still passes")
	_ok(Record.from_text("not json").is_empty() and Record.from_text("[1, 2]").is_empty() and Record.from_text("{}").is_empty(), "text that is not a record gives an empty one")


# Gender, pronouns and frame (format version 2); a version 1 file loads with the plain defaults.
func _check_identity() -> void:
	var rec: Dictionary = _good()
	_ok(int(rec["version"]) == Record.FORMAT_VERSION and rec["gender"] == "prefer_not_to_say" and rec["pronouns"] == "they_them" and rec["frame"] == "neutral", "a new record has the plain defaults")

	for g in Record.GENDERS:
		_ok(Record.GENDER_LABELS.has(g) and Record.PRONOUNS.has(Record.default_pronouns(g)) and Record.FRAMES.has(Record.default_frame(g)), "gender %s has a label, default pronouns and a default frame" % g)

	_ok(Record.GENDER_LABELS["woman"] == "Woman" and Record.GENDER_LABELS["man"] == "Man" and Record.GENDER_LABELS["non_binary"] == "Non-binary" and Record.GENDER_LABELS["prefer_not_to_say"] == "Prefer not to say", "the four gender labels")
	_ok(Record.describe(rec) == "Prefer not to say, they/them", "describe: " + Record.describe(rec))
	rec["gender"] = "woman"
	rec["pronouns"] = "he_him"
	_ok(Record.describe(rec) == "Woman, he/him" and Record.validate(rec, ANCESTRIES).is_empty(), "any pronouns go with any gender")

	for key in ["gender", "pronouns", "frame"]:
		var bad: Dictionary = _good()
		bad[key] = "nonsense"
		_ok(not Record.validate(bad, ANCESTRIES).is_empty(), "an unknown %s is refused" % key)

	var back: Dictionary = Record.from_text(Record.to_text(rec))
	_ok(back == rec, "gender, pronouns and frame round-trip")
	# A version 1 file: no version, gender, pronouns or frame.
	var old: Dictionary = _good()

	for key in ["version", "gender", "pronouns", "frame"]:
		old.erase(key)

	var loaded: Dictionary = Record.from_text(Record.to_text(old))
	_ok(int(loaded["version"]) == 1 and loaded["gender"] == "prefer_not_to_say" and loaded["pronouns"] == "they_them" and loaded["frame"] == "neutral", "a version 1 file loads with the plain defaults")
	_ok(Record.validate(loaded, ANCESTRIES).is_empty(), "and still passes the checks")
