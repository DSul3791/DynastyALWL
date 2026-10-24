extends Node
# Kathleen's batch 2 ambience (data/sound/batch2_slots.json) as a game sound. Each slot carries tags (season, time, biome, near_water, altitude) and a layer:
# weather_bed and time_bed play one loop each at a time (crossfaded over FADE_S), positional beds play at a place (up to two), one-shots play at most
# two at once with a gap of 4 to 20 s, never the same clip twice in a row, pitch +/-5 percent. The context (hour, season, how much forest, meadow and
# water is around, height) comes from AmbientLife, which keeps its own scan. No file path lives in game code.
# The server sends the biome id under the player (protocol 76 zone, set_zone); data/sound/zone_tags.json maps it to the tag words (desert, polar, ice, ...).
# Canyon and lava have no data source yet (the volcano bed gets its vent anchor from the server, protocol 77, set_vent): those slots are "test_only" in the JSON and wait for `force_biome` /
# `set_anchor` (the sound test and the rig use them).
#   sound.ambience.update(delta, body)         every frame from the sound stage
#   sound.ambience.test_press()                the "Sound test: Batch 2" entry: each group in turn, each clip played three times back to back

const AmbientLife := preload("res://src/client/ambient_life.gd")
const Sound3D := preload("res://src/client/sound_3d.gd")
const SLOTS_PATH := "res://data/sound/batch2_slots.json"
const ZONE_TAGS_PATH := "res://data/sound/zone_tags.json"
const BIOMES_PATH := "res://data/tables/biomes.json"
const CHECK_SEC := 1.5
const FADE_S := 2.0
const SILENT_DB := -60.0
# Dave 24 Oct: a surf-like roar in the middle of a forest drowned the nature sounds. The forest beds are steady broadband noise at about
# -27 dB RMS (-31 winter), as loud as everything else in the forest together, so they sit this far under the other sounds.
const BED_TRIM_DB := {"bed_forest_day": 0.0, "bed_forest_winter": 0.0}   # was -12 for the old beds; Kathleen's new ones (kathleen-forest-bed f57c1bd9) are 15-20 dB quieter
const GAP_S := [4.0, 20.0]
const PITCH_SPREAD := 0.05
const ONESHOT_DIST_M := [12.0, 45.0]
const ONESHOT_HEIGHT_M := {"birds": [3.0, 10.0], "night birds": [4.0, 9.0]}
const REPLACES := ["bird_whistle", "bird_trill", "owl_hoot", "frog_croak"]      # AmbientLife calls these slots take over (no doubled birds)
const DUSK_BEFORE_H := 1.0
const DARK_MARGIN_H := 0.5
const NEAR_WATER := 0.4                   # water zone weight from which a pond or the sea edge is near
const SEA_EDGE_M := 8.0
const MAX_SHOTS := 2                      # one-shots playing at once
const SHOT_LENGTH_S := 4.0                # a one-shot counts as playing this long in the 60-second simulation
const WET_REFRESH_S := 2.0                # nearest_wet_point is looked up again after this long or after WET_REFRESH_M of walking
const WET_REFRESH_M := 10.0
const TEST_REPS := 3
const TEST_ONESHOT_MAX_S := 6.0
const TEST_BED_MAX_S := 15.0

var enabled: bool = true
var zone_biome: int = -1                  # the biome id the server last sent (-1 none yet)
var zone_tags: Array = []                 # its tag words
var test_only_count: int = 0              # slots marked "test_only" in the JSON: no client lookup for their place yet (open job in JOBS.md)
var force_biome: String = ""              # a biome name the client cannot read yet (canyon, volcano, desert ...): rig and test
var anchors: Dictionary = {}              # slot -> Vector3 where a positional bed sits (volcano crater, lava)
var played: Dictionary = {}               # slot -> one-shots played
var beds_started: Dictionary = {}         # slot -> times a bed was started (the rig reads this)
var test_note: String = ""
var current: Dictionary = {}              # layer -> slot name playing now ("" none)
var last: String = ""                     # the F4 sound line: the bed started, the one-shot played, or the test group heard

var _stage
var _slots: Dictionary = {}
var _biome_names: Dictionary = {}         # biome id -> name (data/tables/biomes.json)
var _zone_rows: Dictionary = {}           # biome name -> tag words (data/sound/zone_tags.json)
var _beds: Dictionary = {}                # layer -> Array of {"slot", "level" 0..1, "target", "player"}: at most the fading ones and the wanted one
var _positional: Dictionary = {}          # slot -> {"level", "target", "player"}
var _check_left: float = 0.0
var _gap_left: float = 6.0
var _shot_count: int = 0                  # one-shots started; with the day number it seeds the next gap, clip, place and pitch
var _last_clip: String = ""               # "slot:index" of the last one-shot, kept across bed changes
var _voices: Array = []
var _wet_cache: Dictionary = {"from": Vector3.INF, "at": Vector3.INF, "age": 99.0}
var _ctx: Dictionary = {}
var _test_group: int = -1
var _test_token: int = 0
var _test_players: Array = []


func setup(stage, slots_path: String = SLOTS_PATH) -> void:
	_stage = stage
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(slots_path))

	if typeof(parsed) == TYPE_DICTIONARY and parsed.get("slots") is Dictionary:
		_slots = parsed["slots"]

	_biome_names = biome_names(BIOMES_PATH)
	_zone_rows = zone_rows(ZONE_TAGS_PATH)

	if stage != null and stage.get("ambient") != null:
		stage.ambient.replaced = REPLACES.duplicate()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--biome="):
			force_biome = arg.get_slice("=", 1)

	for slot_name in _slots:
		if bool(_slots[slot_name].get("test_only", false)):
			test_only_count += 1


# The biome the server says the player stands in (protocol 76): its tag words join the measured ones.
# The nearest volcanic vent the server knows within 1500 m (protocol 77), Vector3.INF when none: the volcano rumble bed sits there and the "volcano" tag is on.
func set_vent(at: Vector3) -> void:
	if at.is_finite():
		anchors["bed_volcano_rumble"] = at
		last = "vent at %d %d %d" % [int(at.x), int(at.y), int(at.z)]
	else:
		anchors.erase("bed_volcano_rumble")
		last = "vent gone"


func set_zone(biome_id: int) -> void:
	zone_biome = biome_id
	zone_tags = zone_tags_for(biome_id, _biome_names, _zone_rows)
	last = "zone %s -> %s" % [str(_biome_names.get(biome_id, "unknown %d" % biome_id)), ", ".join(PackedStringArray(zone_tags))]


static func biome_names(path: String) -> Dictionary:
	var names: Dictionary = {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) == TYPE_DICTIONARY:
		for entry in parsed.get("entries", []):
			names[int(entry["id"])] = str(entry["name"])

	return names


static func zone_rows(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed.get("tags", {}) as Dictionary) if typeof(parsed) == TYPE_DICTIONARY else {}


# The tag words of a biome id; an unknown id (or a biome with no row) gives none.
static func zone_tags_for(biome_id: int, names: Dictionary, rows: Dictionary) -> Array:
	return (rows.get(str(names.get(biome_id, "")), []) as Array).duplicate()


func slot_names() -> Array:
	return _slots.keys()


# ---------------------------------------------------------------- pure rules (tested without a scene)

# "day", "dusk" or "night" for an hour in a season (sunrise and sunset from AmbientLife.SUN).
static func time_class(hour: float, season: String) -> String:
	var sun: Array = AmbientLife.SUN.get(season, AmbientLife.SUN["autumn"])

	if hour < float(sun[0]) - DARK_MARGIN_H or hour >= float(sun[1]) + DARK_MARGIN_H:
		return "night"

	if hour >= float(sun[1]) - DUSK_BEFORE_H:
		return "dusk"

	return "day"


# The biomes the client can tell from what AmbientLife measures (trees, grass, water, height), plus `zone` (the server's biome, as tag words) and `forced` (rig).
static func biomes_for(forest: float, meadow: float, water: float, height_m: float, forced: String = "", zone: Array = []) -> Array:
	var list: Array = []

	if forest >= 0.35:
		list.append_array(["temperate_forest", "boreal_forest", "woodland"])

	if meadow >= 0.35:
		list.append("grassland")

	if water >= NEAR_WATER and height_m < SEA_EDGE_M:
		list.append("beach")

	if forced != "":
		list.append(forced)

	for tag in zone:
		if not list.has(tag):
			list.append(tag)

	return list


# ctx: {"season", "time" (time_class), "biomes" (biomes_for), "water" 0..1, "height" m, "lava" bool}
static func matches(tags: Dictionary, ctx: Dictionary) -> bool:
	if not (tags.get("season", []) as Array).has(str(ctx.get("season", ""))):
		return false

	var clock: String = str(ctx.get("time", "day"))

	match str(tags.get("time", "day_and_night")):
		"day":
			if clock == "night":
				return false
		"night":
			if clock != "night":
				return false
		"dusk_and_night":
			if clock == "day":
				return false

	var biome_tags: Array = tags.get("biome", ["any"])

	if not (biome_tags.has("any") or biome_tags.has("any_except_desert_polar")):
		var found: bool = false

		for biome in ctx.get("biomes", []):
			found = found or biome_tags.has(biome)

		if not found:
			return false

	var water: float = float(ctx.get("water", 0.0))
	var height: float = float(ctx.get("height", 0.0))

	match str(tags.get("near_water", "any")):
		"pond":
			if water < NEAR_WATER:
				return false
		"sea_edge":
			if water < NEAR_WATER or height >= SEA_EDGE_M:
				return false
		"lava":
			if not bool(ctx.get("lava", false)):
				return false

	match str(tags.get("altitude", "any")):
		"below_800m":
			return height < 800.0
		"below_1500m":
			return height < 1500.0
		"above_300m":
			return height > 300.0
		"sea_level":
			return height < SEA_EDGE_M

	return true


# How narrow a slot's tags are (a slot that names a biome, water or height beats a general one for the same layer).
static func specificity(tags: Dictionary) -> int:
	var score: int = 0
	var biome_tags: Array = tags.get("biome", ["any"])
	score += 0 if biome_tags.has("any") or biome_tags.has("any_except_desert_polar") else 1
	score += 0 if str(tags.get("near_water", "any")) == "any" else 1
	score += 0 if str(tags.get("altitude", "any")) == "any" else 1
	return score


# The one bed for a layer ("weather_bed", "time_bed"): the most specific matching slot, ties by name; "" when none matches.
static func choose_bed(slots: Dictionary, layer: String, ctx: Dictionary) -> String:
	var best: String = ""
	var best_score: int = -1
	var names: Array = slots.keys()
	names.sort()

	for slot in names:
		var row: Dictionary = slots[slot]

		if str(row.get("layer", "")) != layer or str(row.get("status", "")) == "empty" or not matches(row.get("tags", {}), ctx):
			continue

		var score: int = specificity(row.get("tags", {}))

		if score > best_score:
			best_score = score
			best = str(slot)

	return best


# Every matching slot of a layer (one-shots and positional beds), sorted by name.
static func matching(slots: Dictionary, layer: String, ctx: Dictionary) -> Array:
	var list: Array = []
	var names: Array = slots.keys()
	names.sort()

	for slot in names:
		var row: Dictionary = slots[slot]

		if str(row.get("layer", "")) == layer and str(row.get("status", "")) != "empty" and matches(row.get("tags", {}), ctx):
			list.append(str(slot))

	return list


# ---------------------------------------------------------------- pure scheduler and crossfade rules (tested without a scene)

# The random stream of one-shot number `counter` on game day `day`: the same day and count give the same gap, clip, place and pitch (a recorded test reproduces).
static func shot_rng(day: int, counter: int, salt: String = "") -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%s" % [day, counter, salt])
	return rng


# The next one-shot: a slot from `options` and a clip of it, never the clip played last (`last_clip` is "slot:index"; it survives a bed change). Only a
# single clip with nothing else to play can repeat. Returns {"slot", "index", "clip"}.
static func pick_shot(slots: Dictionary, options: Array, last_clip: String, rng: RandomNumberGenerator) -> Dictionary:
	var slot: String = str(options[rng.randi() % options.size()])
	var count: int = maxi((slots[slot].get("files", []) as Array).size(), 1)
	var index: int = rng.randi() % count

	if "%s:%d" % [slot, index] == last_clip:
		if count > 1:
			index = (index + 1) % count
		elif options.size() > 1:
			slot = str(options[(options.find(slot) + 1) % options.size()])
			index = 0

	return {"slot": slot, "index": index, "clip": "%s:%d" % [slot, index]}


# One fade step for a bed: the level (0 silent, 1 full) moves toward its target in FADE_S seconds.
static func fade_level(level: float, target: float, delta: float) -> float:
	return move_toward(level, target, delta / FADE_S)


# Equal-power gain for a level: an outgoing bed (level falling from 1) and an incoming one (rising from 0) sum to constant power.
static func fade_gain(level: float) -> float:
	return sin(clampf(level, 0.0, 1.0) * PI * 0.5)


# Point the layer's beds at `slot` ("" for none): the wanted bed (kept if it is still fading out, so it resumes from its current level, never from 0) gets
# target 1, every other target 0. Returns true when a new entry (level 0) was added and needs a player.
static func retarget(entries: Array, slot: String) -> bool:
	var found: bool = false

	for entry in entries:
		if str(entry["slot"]) == slot:
			entry["target"] = 1.0
			found = true
		else:
			entry["target"] = 0.0

	if slot != "" and not found:
		entries.append({"slot": slot, "level": 0.0, "target": 1.0})
		return true

	return false


# Move every entry's level on; entries that are silent and heading for silence are removed (returned, so the caller can free their players).
static func advance(entries: Array, delta: float) -> Array:
	var gone: Array = []

	for n in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[n]
		entry["level"] = fade_level(float(entry["level"]), float(entry["target"]), delta)

		if float(entry["level"]) <= 0.0 and float(entry["target"]) <= 0.0:
			gone.append(entry)
			entries.remove_at(n)

	return gone


# Whether nearest_wet_point is looked up again: after WET_REFRESH_S, or after walking WET_REFRESH_M since the last lookup.
static func wet_needs_refresh(age_s: float, moved_m: float) -> bool:
	return age_s >= WET_REFRESH_S or moved_m >= WET_REFRESH_M


# `seconds` of the one-shot scheduler on game day `day` in a context, with no engine: how many of each slot play, the most playing together, and the
# beds a place of this kind holds (one weather bed, one time bed, up to two positional) - the voices ambience needs at the busiest moment.
static func simulate(slots: Dictionary, ctx: Dictionary, seconds: float, day: int) -> Dictionary:
	var options: Array = matching(slots, "oneshot", ctx)
	var counts: Dictionary = {}
	var live: Array = []
	var busiest: int = 0
	var clock: float = 0.0
	var counter: int = 0
	var last_clip: String = ""
	var repeats: int = 0
	var order: Array = []

	while not options.is_empty():
		var rng: RandomNumberGenerator = shot_rng(day, counter)
		clock += rng.randf_range(float(GAP_S[0]), float(GAP_S[1]))

		if clock >= seconds:
			break

		live = live.filter(func(end): return float(end) > clock)

		if live.size() < MAX_SHOTS:
			var shot: Dictionary = pick_shot(slots, options, last_clip, rng)
			repeats += 1 if str(shot["clip"]) == last_clip else 0
			last_clip = str(shot["clip"])
			order.append(last_clip)
			counts[shot["slot"]] = int(counts.get(shot["slot"], 0)) + 1
			live.append(clock + SHOT_LENGTH_S)
			busiest = maxi(busiest, live.size())

		counter += 1

	var beds: int = (1 if choose_bed(slots, "weather_bed", ctx) != "" else 0) + (1 if choose_bed(slots, "time_bed", ctx) != "" else 0) + mini(2, matching(slots, "positional", ctx).size())
	return {"counts": counts, "order": order, "shots_busiest": busiest, "beds": beds, "voices_busiest": busiest + beds, "repeats": repeats}


# ---------------------------------------------------------------- the running layer

func context(body: Node3D) -> Dictionary:
	var conditions: Dictionary = _stage.ambient.conditions
	var weights: Dictionary = _stage.ambient.weights
	var height: float = body.global_position.y
	var biomes: Array = biomes_for(float(weights.get("forest", 0.0)), float(weights.get("meadow", 0.0)), float(weights.get("water", 0.0)), height, force_biome, zone_tags)

	if anchors.has("bed_volcano_rumble") and not biomes.has("volcano"):
		biomes.append("volcano")

	return {
		"season": str(conditions.get("season", "autumn")),
		"time": time_class(float(conditions.get("hour", 14.0)), str(conditions.get("season", "autumn"))),
		"biomes": biomes,
		"water": float(weights.get("water", 0.0)),
		"height": height,
		"lava": anchors.has("bed_lava_hiss"),
	}


func update(delta: float, body: Node3D) -> void:
	if not enabled or _slots.is_empty() or _stage == null:
		return

	_advance_all(delta)
	_check_left -= delta

	if _check_left <= 0.0:
		_check_left = CHECK_SEC
		_ctx = context(body)

		for layer in ["weather_bed", "time_bed"]:
			_set_bed(layer, choose_bed(_slots, layer, _ctx))

		_set_positional(body)

	_voices = _voices.filter(func(v): return is_instance_valid(v) and v.playing)
	_gap_left -= delta

	if _gap_left <= 0.0 and not _ctx.is_empty():
		_gap_left = shot_rng(_day(), _shot_count).randf_range(float(GAP_S[0]), float(GAP_S[1]))
		_one_shot(body)


func _day() -> int:
	return _stage.ambient.day_number()


func _stream(slot: String, index: int = 0) -> AudioStream:
	var files: Array = _slots[slot].get("files", [])

	if files.is_empty() or not ResourceLoader.exists(str(files[index % files.size()])):
		return null

	return load(str(files[index % files.size()]))


func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis:
		var copy: AudioStream = stream.duplicate()
		copy.loop = true
		return copy

	return stream


func _set_bed(layer: String, slot: String) -> void:
	var entries: Array = _beds.get(layer, [])
	var wanted: String = slot if slot == "" or _stage.has_room() or _has_entry(entries, slot) else ""
	var added: bool = retarget(entries, wanted)
	_beds[layer] = entries

	if added:
		var entry: Dictionary = entries[entries.size() - 1]
		var stream: AudioStream = _stream(wanted)

		if stream == null:
			entries.pop_back()
			wanted = ""
		else:
			var player: AudioStreamPlayer = AudioStreamPlayer.new()
			player.stream = _looped(stream)
			player.bus = "Wind" if wanted.contains("wind") else "Nature"   # the wind beds (desert, canyon) follow the Wind slider, not Nature (Dave 24 Oct)
			player.volume_db = SILENT_DB
			add_child(player)
			player.play()
			entry["player"] = player
			beds_started[wanted] = int(beds_started.get(wanted, 0)) + 1
			last = "bed %s (%s)" % [wanted, layer]

	current[layer] = wanted


func _has_entry(entries: Array, slot: String) -> bool:
	for entry in entries:
		if str(entry["slot"]) == slot:
			return true

	return false


func _set_positional(body: Node3D) -> void:
	var wanted: Dictionary = {}

	for slot in matching(_slots, "positional", _ctx):
		if wanted.size() >= 2:
			break

		var at: Vector3 = Vector3.INF

		if anchors.has(slot):
			at = anchors[slot]
		elif str(_slots[slot].get("tags", {}).get("near_water", "")) == "pond":
			at = _nearest_wet(body.global_position)

		if at != Vector3.INF:
			wanted[slot] = at

	for slot in _positional:
		_positional[slot]["target"] = 1.0 if wanted.has(slot) else 0.0

	for slot in wanted:
		if _positional.has(slot):
			_positional[slot]["player"].global_position = wanted[slot]
			continue

		var stream: AudioStream = _stream(slot)

		if stream == null or not _stage.has_room():
			continue

		var player: AudioStreamPlayer3D = Sound3D.make(self, "Nature", 10.0, 90.0)
		player.stream = _looped(stream)
		player.volume_db = SILENT_DB
		player.global_position = wanted[slot]
		player.play()
		_positional[slot] = {"slot": slot, "level": 0.0, "target": 1.0, "player": player}
		beds_started[slot] = int(beds_started.get(slot, 0)) + 1
		last = "bed %s (positional)" % slot


# AmbientLife's nearest water square, looked up again only every WET_REFRESH_S or after WET_REFRESH_M of walking (the scan itself is every 1.5 s).
func _nearest_wet(from: Vector3) -> Vector3:
	_wet_cache["age"] = float(_wet_cache["age"]) + CHECK_SEC
	var moved: float = from.distance_to(_wet_cache["from"]) if _wet_cache["from"] != Vector3.INF else INF

	if wet_needs_refresh(float(_wet_cache["age"]), moved):
		_wet_cache["age"] = 0.0
		_wet_cache["from"] = from
		_wet_cache["at"] = _stage.ambient.nearest_wet_point(from)

	return _wet_cache["at"]


func _advance_all(delta: float) -> void:
	for layer in _beds:
		var entries: Array = _beds[layer]

		for gone in advance(entries, delta):
			if is_instance_valid(gone.get("player")):
				gone["player"].queue_free()

		for entry in entries:
			entry["player"].volume_db = linear_to_db(maxf(fade_gain(float(entry["level"])), 0.0001)) + float(BED_TRIM_DB.get(str(entry["slot"]), 0.0))

	var dead: Array = []

	for slot in _positional:
		var entry: Dictionary = _positional[slot]
		entry["level"] = fade_level(float(entry["level"]), float(entry["target"]), delta)
		entry["player"].volume_db = linear_to_db(maxf(fade_gain(float(entry["level"])), 0.0001))

		if float(entry["level"]) <= 0.0 and float(entry["target"]) <= 0.0:
			entry["player"].queue_free()
			dead.append(slot)

	for slot in dead:
		_positional.erase(slot)


func _one_shot(body: Node3D) -> void:
	var counter: int = _shot_count
	_shot_count += 1

	if _voices.size() >= MAX_SHOTS or not _stage.has_room():
		return

	var options: Array = matching(_slots, "oneshot", _ctx)

	if options.is_empty():
		return

	var rng: RandomNumberGenerator = shot_rng(_day(), counter)
	rng.randf()            # the gap draw of this count, so the clip draws below follow it as in simulate()
	var shot: Dictionary = pick_shot(_slots, options, _last_clip, rng)
	var slot: String = str(shot["slot"])
	var stream: AudioStream = _stream(slot, int(shot["index"]))

	if stream == null:
		return

	_last_clip = str(shot["clip"])
	var angle: float = rng.randf() * TAU
	var distance: float = rng.randf_range(float(ONESHOT_DIST_M[0]), float(ONESHOT_DIST_M[1]))
	var band: Array = ONESHOT_HEIGHT_M.get(str(_slots[slot].get("group", "")), [0.0, 0.0])
	var at: Vector3 = body.global_position + Vector3(cos(angle) * distance, rng.randf_range(float(band[0]), float(band[1])) - 0.9, sin(angle) * distance)
	var player: AudioStreamPlayer3D = Sound3D.make(self, "Nature", 8.0, 120.0)
	player.stream = stream
	player.pitch_scale = 1.0 + shot_rng(_day(), counter, slot).randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	_voices.append(player)
	played[slot] = int(played.get(slot, 0)) + 1
	last = "%s_%d" % [slot, int(shot["index"])]


# ---------------------------------------------------------------- the sound test

# Groups in file order, each once.
func groups() -> Array:
	var list: Array = []

	for slot in _slots:
		var group: String = str(_slots[slot].get("group", ""))

		if not list.has(group):
			list.append(group)

	return list


func slots_in_group(group: String) -> Array:
	var list: Array = []

	for slot in _slots:
		if str(_slots[slot].get("group", "")) == group:
			list.append(str(slot))

	return list


# One press starts the sequence at the first group; each press after that jumps to the next group; past the last it stops.
# Every clip of the group plays TEST_REPS times back to back (a bed is cut at TEST_BED_MAX_S per play), flat in the headset.
func test_press() -> String:
	var all: Array = groups()
	_test_token += 1
	_test_group += 1

	for old in _test_players:
		if is_instance_valid(old):
			old.queue_free()

	_test_players.clear()

	if _test_group >= all.size():
		_test_group = -1
		test_note = "Batch 2 test finished (%d groups). Press again to start over." % all.size()
		return test_note

	var group: String = str(all[_test_group])
	last = "test group %d of %d: %s" % [_test_group + 1, all.size(), group]
	test_note = "Batch 2 group %d of %d: %s (%s), every clip %d times back to back. Press for the next group." % [_test_group + 1, all.size(), group, ", ".join(slots_in_group(group)), TEST_REPS]
	_run_group(_test_token, group)
	return test_note


func _run_group(token: int, group: String) -> void:
	for slot in slots_in_group(group):
		var row: Dictionary = _slots[slot]
		var is_bed: bool = bool(row.get("loop", false))

		for index in range((row.get("files", []) as Array).size()):
			var stream: AudioStream = _stream(slot, index)

			if stream == null:
				continue

			for rep in range(TEST_REPS):
				if token != _test_token or not is_inside_tree():
					return

				var player: AudioStreamPlayer = AudioStreamPlayer.new()
				player.stream = stream
				player.bus = "Nature"
				add_child(player)
				_test_players.append(player)
				player.play()
				print("sound test batch 2: %s clip %d play %d of %d" % [slot, index + 1, rep + 1, TEST_REPS])
				var length: float = minf(stream.get_length(), TEST_BED_MAX_S if is_bed else TEST_ONESHOT_MAX_S)
				await get_tree().create_timer(length + 0.2).timeout
				player.queue_free()
