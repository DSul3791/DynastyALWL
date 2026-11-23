extends SceneTree

# Seasons by place (Dave: nothing is ever based on where spawn is; coordinator's season sweep, 23 Nov 2026). Every season, day of the year,
# sun and ice read goes by the row where the thing or the player is: across the equator the year is half a year on.
# 1. A guard over the game's source (src, scenes): no new code reads the starter row's calendar. A line that reads it on purpose (a fallback
#    with no place, a log line) carries a "starter-calendar:" comment. And the calls that take a row (Weather.state, air_c, temp_at, Ice.cover,
#    Ice.season, moat_cells, puddles, FrozenWater.look ...) pass it: a call that leaves the row out gets the starter's.
# 2. The helpers: season_stamp_at keeps the calendar's count on the starter's side (saved "taken this season" stamps keep their meaning),
#    two on across the equator; day_of_year_at, ice, the items' plant season, the animals' season, wolf pups and bare crowns by place.
#   godot --headless --path . --script res://src/worldgen/tools/test_season_by_place.gd

const Weather := preload("res://src/shared/weather.gd")
const Ice := preload("res://src/shared/ice.gd")
const GameClock := preload("res://src/shared/game_clock.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const FloraStoreScript := preload("res://src/stream/server_flora.gd")

const TILE_M := 15360.0
const EQUATOR_ROW := 0
const STARTER_Z := 71364.0      # the starter town's row (4)
const ACROSS_Z := -71364.0      # the same distance across the equator (row -5)
const DAY := 86400.0

const SKIP_FILES := ["res://src/shared/weather.gd", "res://src/shared/climate.gd", "res://src/shared/game_clock.gd"]
const TAG := "starter-calendar"

# Reads of the one calendar: the starter row's season, day and phase.
const CALENDAR_READS := [
	["game_clock\\.season\\(\\)", "the calendar's season"],
	["\\bseason_index\\(\\)", "the calendar's season index"],
	["\\bday_of_year\\(\\)", "the calendar's day of the year"],
	["\\byear_phase\\(", "the calendar's year phase (Weather.year_phase_at takes the row)"],
	["(?<![\\w.])season_of\\(", "the calendar's season (GameClock.season_of)"],
	["%\\s*365\\b", "a day of the year from the calendar"],
]
const STREAM_READS := [
	["season_now\\.call\\(\\)", "the server's calendar season (season_at takes the place)"],
	["season_stamp\\.call\\(\\)", "the server's calendar season count (season_stamp_at takes the place)"],
]

# Calls that take a row: [name, prefix regex (empty: only bare, in its own file), file that defines it, arguments with the row and equator].
const ROW_CALLS := [
	["state", "Weather\\w*\\.", "res://src/shared/weather.gd", 7],
	["air_c", "Weather\\w*\\.", "res://src/shared/weather.gd", 6],
	["snow_air_c", "Weather\\w*\\.", "res://src/shared/weather.gd", 6],
	["temp_at", "Weather\\w*\\.", "res://src/shared/weather.gd", 6],
	["snow_temp_at", "Weather\\w*\\.", "res://src/shared/weather.gd", 6],
	["year_phase_at", "(Weather\\w*|Ice\\w*\\.Weather)\\.", "res://src/shared/weather.gd", 3],
	["local_wind", "Weather\\w*\\.", "res://src/shared/weather.gd", 5],
	["slope_breeze_mps", "Weather\\w*\\.", "res://src/shared/weather.gd", 7],
	["sea_breeze_mps", "Weather\\w*\\.", "res://src/shared/weather.gd", 7],
	["sunrise_hour", "Weather\\w*\\.", "res://src/shared/weather.gd", 2],
	["cover", "Ice\\w*\\.", "res://src/shared/ice.gd", 7],
	["season", "Ice\\w*\\.", "res://src/shared/ice.gd", 7],
	["sea_cover", "Ice\\w*\\.", "res://src/shared/ice.gd", 5],
	["moat_cells", "(ice_moat|IceMoat\\w*)\\.", "res://src/shared/ice_moat.gd", 6],
	["set_ice_from", "puddles\\.", "res://src/client/puddles.gd", 5],
	["winter_share", "Puddles\\w*\\.", "res://src/client/puddles.gd", 3],
	["look", "FrozenWater\\.", "res://src/client/frozen_water.gd", 7],
]

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	_guard()
	_helpers()
	_items()
	_animals()
	_flora()
	print("season by place test: %d failures" % failures)
	quit(failures)


func _files(dir: String, out: Array) -> void:
	if dir.begins_with("res://src/worldgen/tools") or dir.begins_with("res://addons"):
		return

	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))

	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_files(dir.path_join(d), out)


# The code part of a line (a "#" outside a string starts the comment).
static func _code(line: String) -> String:
	var quote: String = ""

	for i in line.length():
		var c: String = line[i]

		if quote != "":
			if c == "\\":
				continue
			if c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "#":
			return line.substr(0, i)

	return line


# How many arguments a call has from its "(" at `open` (top-level commas; strings skipped). -1 if it never closes.
static func _arg_count(text: String, open: int) -> int:
	var depth: int = 0
	var commas: int = 0
	var any: bool = false
	var quote: String = ""
	var i: int = open

	while i < text.length():
		var c: String = text[i]

		if quote != "":
			if c == "\\":
				i += 1
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
			any = true
		elif c == "(" or c == "[" or c == "{":
			depth += 1
			if depth > 1:
				any = true
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
			if depth == 0:
				return commas + 1 if any else 0
		elif c == "," and depth == 1:
			commas += 1
		elif depth >= 1 and c.strip_edges() != "":
			any = true

		i += 1

	return -1


func _guard() -> void:
	var files: Array = []
	_files("res://src", files)
	_files("res://scenes", files)
	var reads: Array = []
	var stream_reads: Array = []

	for r in CALENDAR_READS:
		var re := RegEx.new()
		re.compile(r[0])
		reads.append([re, r[1]])

	for r in STREAM_READS:
		var re := RegEx.new()
		re.compile(r[0])
		stream_reads.append([re, r[1]])

	var starter := RegEx.new()
	starter.compile("\\bSTARTER_ROW\\b")
	var calls: Array = []

	for c in ROW_CALLS:
		var re := RegEx.new()
		re.compile("(?<![\\w.])(%s)?%s\\(" % [c[1], c[0]])
		calls.append([re, c])

	var bad: Array = []
	var short: Array = []
	var looked: int = 0

	for path in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		var code_lines: PackedStringArray = PackedStringArray()

		for line in lines:
			code_lines.append(_code(line))

		looked += 1

		if not path in SKIP_FILES:
			for n in lines.size():
				var code: String = code_lines[n]

				if lines[n].contains(TAG) or code.strip_edges() == "":
					continue

				for r in reads:
					if r[0].search(code) != null:
						bad.append("%s:%d %s: %s" % [path, n + 1, r[1], lines[n].strip_edges()])

				if path.begins_with("res://src/stream"):
					for r in stream_reads:
						if r[0].search(code) != null:
							bad.append("%s:%d %s: %s" % [path, n + 1, r[1], lines[n].strip_edges()])

				var is_def: bool = code.strip_edges().begins_with("func ") or code.strip_edges().begins_with("static func ")

				if starter.search(code) != null and not is_def:
					bad.append("%s:%d the starter row by name: %s" % [path, n + 1, lines[n].strip_edges()])

		# Row-taking calls that leave the row out (the comment parts blanked, so the text keeps its offsets for line numbers).
		var text: String = "\n".join(code_lines)

		for c in calls:
			var spec: Array = c[1]

			for m in c[0].search_all(text):
				var prefixed: bool = m.get_string(1) != ""

				if not prefixed and path != spec[2]:
					continue

				var start: int = m.get_start()
				var line_no: int = text.substr(0, start).count("\n")

				if code_lines[line_no].strip_edges().begins_with("func ") or code_lines[line_no].strip_edges().begins_with("static func "):
					continue

				if lines[line_no].contains(TAG):
					continue

				var n_args: int = _arg_count(text, m.get_end() - 1)

				if n_args >= 0 and n_args < int(spec[3]):
					short.append("%s:%d %s( with %d arguments, the row needs %d: %s" % [path, line_no + 1, spec[0], n_args, spec[3], lines[line_no].strip_edges()])

	for b in bad:
		print("  ", b)

	for s in short:
		print("  ", s)

	check(looked > 200, "the guard read the game's source (%d files)" % looked)
	check(bad.is_empty(), "no code reads the starter row's calendar (tag a deliberate fallback or log line '# %s: ...')" % TAG)
	check(short.is_empty(), "every call that takes a row passes the row and the equator")


func _row(z: float) -> int:
	return floori(z / TILE_M)


func _helpers() -> void:
	var row: int = _row(STARTER_Z)
	var across: int = _row(ACROSS_Z)
	check(row == Weather.STARTER_ROW, "the starter town is on the starter row (%d)" % row)
	var clock = GameClock.new()
	var same: bool = true
	var two_on: bool = true
	var days_ok: bool = true

	for day in range(0, 730, 3):
		var s: float = float(day) * DAY + 3600.0
		clock.seconds = s
		var calendar: int = clock.year() * 4 + clock.season_index()   # what the 9257 save's stamps were made from

		if Weather.season_stamp_at(s, row, EQUATOR_ROW) != calendar:
			same = false

		if Weather.season_stamp_at(s, across, EQUATOR_ROW) != calendar + 2:
			two_on = false

		var doy: int = clock.day_of_year()
		var doy_across: int = Weather.day_of_year_at(s, across, EQUATOR_ROW)

		if Weather.day_of_year_at(s, row, EQUATOR_ROW) != doy or absi(posmod(doy_across - doy, GameClock.DAYS_PER_YEAR) - GameClock.DAYS_PER_YEAR / 2) > 1:
			days_ok = false

	check(same, "on the starter's row the season count is the calendar's, year x 4 + season (saved stamps keep their meaning)")
	check(two_on, "across the equator the season count is two on (half a year)")
	check(days_ok, "the day of the year is the calendar's on the starter's row and half a year on across the equator")
	var winter_s: float = 0.0
	for day in range(0, 365):
		if Weather.season_at(float(day) * DAY, STARTER_Z, TILE_M, EQUATOR_ROW) == "winter":
			winter_s = (float(day) + 30.0) * DAY + 6.0 * 3600.0
			break

	check(Weather.season_at(winter_s, STARTER_Z, TILE_M, EQUATOR_ROW) == "winter" and Weather.season_at(winter_s, ACROSS_Z, TILE_M, EQUATOR_ROW) == "summer",
		"midwinter on the starter's row is midsummer across the equator")
	check(Weather.season_of_row(winter_s, across, EQUATOR_ROW) == "summer", "season_of_row agrees with season_at")
	var cold: float = Ice.cover(winter_s, "arctic", 300.0, 0.3, 0, row, EQUATOR_ROW)
	var warm: float = Ice.cover(winter_s, "arctic", 300.0, 0.3, 0, across, EQUATOR_ROW)
	check(cold > warm, "midwinter ice on the starter's row is more than the summer's across the equator (%.3f, %.3f)" % [cold, warm])
	check(Weather.temp_at(winter_s, "temperate", 0.0, 0, across, EQUATOR_ROW) > Weather.temp_at(winter_s, "temperate", 0.0, 0, row, EQUATOR_ROW),
		"the day's air is warmer across the equator in the starter's winter")
	_winter_s = winter_s


var _winter_s: float = 0.0


func _items() -> void:
	var items = ItemsScript.new()
	items.season_at = func(pos: Vector3): return Weather.season_at(_winter_s, pos.z, TILE_M, EQUATOR_ROW)
	items.season_stamp_at = func(pos: Vector3): return Weather.season_stamp_at(_winter_s, _row(pos.z), EQUATOR_ROW)
	var home: String = "%d,%d" % [floori(58160.0 / ItemsScript.FLORA_CHUNK_M), floori(STARTER_Z / ItemsScript.FLORA_CHUNK_M)]
	var far: String = "%d,%d" % [floori(58160.0 / ItemsScript.FLORA_CHUNK_M), floori(ACROSS_Z / ItemsScript.FLORA_CHUNK_M)]
	check(items._plant_season(home + ",17") == "winter", "a plant by the starter town has the starter's winter")
	check(items._plant_season(far + ",17") == "summer", "a plant across the equator has its own summer")
	check(items._stamp_at(items._chunk_middle(far)) == items._stamp_at(items._chunk_middle(home)) + 2, "a chunk across the equator counts its seasons two on")
	var clock = GameClock.new()
	clock.seconds = _winter_s
	check(items._stamp_at(Vector3(58160.0, 0.0, STARTER_Z)) == clock.year() * 4 + clock.season_index(), "a stamp by the starter town is the calendar's count")


func _animals() -> void:
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return []
	a.player_stances = func(): return []
	a.setup()
	a.season_now = func(): return "winter"
	a.season_at = func(pos: Vector3): return Weather.season_at(_winter_s, pos.z, TILE_M, EQUATOR_ROW)
	a.row_of = func(pos: Vector3): return _row(pos.z)
	a.equator_row = EQUATOR_ROW
	a._weather_for(Vector3(58160.0, 10.0, ACROSS_Z))
	check(a._season_here() == "summer", "an animal across the equator has its own summer")
	a._weather_for(Vector3(58160.0, 10.0, STARTER_Z))
	check(a._season_here() == "winter", "an animal by the starter town has the starter's winter")
	var w = a.wolves
	var pups_day: float = 0.0

	for day in range(0, 365):   # a day in the starter's pup season whose day across the equator is out of it
		var s: float = float(day) * DAY + 12.0 * 3600.0
		w.game_seconds = func(): return s
		if w.pup_season(Vector3(58160.0, 10.0, STARTER_Z)) and not w.pup_season(Vector3(58160.0, 10.0, ACROSS_Z)):
			pups_day = s
			break

	check(pups_day > 0.0, "wolf pups come in each den's own season: in season by the starter town on a day out of season across the equator")


func _flora() -> void:
	var flora = FloraStoreScript.new()
	flora.season_at = func(pos: Vector3): return Weather.season_at(_winter_s, pos.z, TILE_M, EQUATOR_ROW)
	flora.covered(Vector3(58160.0, 10.0, STARTER_Z))
	check(flora.cover.leafless, "the starter's winter: deciduous crowns there are bare (shelter)")
	flora.covered(Vector3(58160.0, 10.0, ACROSS_Z))
	check(not flora.cover.leafless, "across the equator in its summer the crowns are in leaf")
