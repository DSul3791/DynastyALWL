extends RefCounted

# Goblin friendship, step 1 (docs/design/goblin_friendship_step1_design.md; goblin_ally_design.md, Dave 8 Nov 2026 decision 7): how much one
# band (the goblins of one cave, keyed by its mouth's lair key) trusts one player character. Gifts raise it once a game night, harm sets it to 0
# and makes the band wary for a while, and it is forgotten 1 step every forget_days game days without a gift. Saved in goblin_trust.json.

const ItemsScript := preload("res://src/stream/server_items.gd")
const DAY_S := 86400.0          # game seconds in a game day (GameClock.SECONDS_PER_DAY)
const SAVE_EVERY_S := 30.0      # real seconds between writes while something changed
const FILE := "goblin_trust.json"

var cfg: Dictionary = {}        # the goblin's "ally" block
var game_seconds: Callable      # () -> game seconds (the server clock)
var store_dir: String = ""      # "" = not saved (tests)
var records: Dictionary = {}    # band key -> {character key -> {trust, last_gift_s, wary_until_s, night, gift_day}}
var _dirty: bool = false
var _save_in: float = SAVE_EVERY_S


func _now() -> float:
	return float(game_seconds.call()) if game_seconds.is_valid() else 0.0


func _row(band: String, who: String) -> Dictionary:
	if not records.has(band):
		records[band] = {}

	if not records[band].has(who):
		records[band][who] = {"trust": 0.0, "last_gift_s": _now(), "wary_until_s": -1.0, "night": -1, "gift_day": -1}

	return records[band][who]


# Trust now, with forgetting worked out from the last gift.
func trust(band: String, who: String) -> float:
	if who == "" or not records.has(band) or not records[band].has(who):
		return 0.0

	var row: Dictionary = records[band][who]
	var forget_s: float = float(cfg.get("forget_days", 7.0)) * DAY_S
	var lost: float = floorf(maxf(_now() - float(row["last_gift_s"]), 0.0) / forget_s) if forget_s > 0.0 else 0.0
	return maxf(float(row["trust"]) - lost, 0.0)


# The step a player has reached with a band: "stranger", "tolerated", "known" or "trusted".
func step_of(band: String, who: String) -> String:
	var t: float = trust(band, who)
	var steps: Dictionary = cfg.get("steps", {})
	var out: String = "stranger"

	for step_name in ["tolerated", "known", "trusted"]:
		if steps.has(step_name) and t >= float(steps[step_name]):
			out = step_name

	return out


func at_least(band: String, who: String, step: String) -> bool:
	var order: Array = ["stranger", "tolerated", "known", "trusted"]
	return order.find(step_of(band, who)) >= order.find(step)


func wary(band: String, who: String) -> bool:
	return who != "" and records.has(band) and records[band].has(who) and float(records[band][who]["wary_until_s"]) > _now()


# A thing `who` dropped was taken by the band: +1 trust, once per game night (noon to noon).
func gift(band: String, who: String) -> void:
	if who == "":
		return

	var row: Dictionary = _row(band, who)
	var night: int = int(floorf((_now() + DAY_S * 0.5) / DAY_S))

	if int(row["night"]) == night:
		return

	row["trust"] = trust(band, who) + 1.0   # forgetting so far is settled before the new gift
	row["last_gift_s"] = _now()
	row["night"] = night
	_dirty = true


# `who` hurt one of the band: trust to 0 and the band wary of them for wary_days.
func harm(band: String, who: String) -> void:
	if who == "":
		return

	var row: Dictionary = _row(band, who)
	row["trust"] = 0.0
	row["last_gift_s"] = _now()
	row["wary_until_s"] = _now() + float(cfg.get("wary_days", 5.0)) * DAY_S
	_dirty = true


# Whether the band still owes `who` a return gift today; marks it given when `take` is true.
func return_gift_due(band: String, who: String, take: bool) -> bool:
	if not at_least(band, who, "known"):
		return false

	var row: Dictionary = _row(band, who)
	var day: int = int(floorf(_now() / DAY_S))

	if int(row["gift_day"]) == day:
		return false

	if take:
		row["gift_day"] = day
		_dirty = true

	return true


func tick(real_dt: float) -> void:
	_save_in -= real_dt

	if _dirty and _save_in <= 0.0:
		save()


func save() -> void:
	_save_in = SAVE_EVERY_S
	_dirty = false

	# A record that has forgotten to 0 and is not wary is dropped.
	for band in records.keys():
		for who in (records[band] as Dictionary).keys():
			if trust(band, who) <= 0.0 and not wary(band, who):
				records[band].erase(who)

		if (records[band] as Dictionary).is_empty():
			records.erase(band)

	if store_dir == "":
		return

	ItemsScript._write_file(store_dir + "/" + FILE, JSON.stringify({"version": 1, "bands": records}))   # .tmp, then renamed over (the save files' one writer)


func load_records() -> void:
	if store_dir == "" or not FileAccess.file_exists(store_dir + "/" + FILE):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(store_dir + "/" + FILE))

	if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("bands")) == TYPE_DICTIONARY:
		records = parsed["bands"]
