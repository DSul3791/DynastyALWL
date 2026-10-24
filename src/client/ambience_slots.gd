extends Node
# Kathleen's batch 2 ambience (data/sound/batch2_slots.json) as a game sound. Each slot carries tags (season, time, biome, near_water, altitude) and a layer:
# weather_bed and time_bed play one loop each at a time (crossfaded over FADE_S), positional beds play at a place (up to two), one-shots play at most
# two at once with a gap of 4 to 20 s, never the same clip twice in a row, pitch +/-5 percent. The context (hour, season, how much forest, meadow and
# water is around, height) comes from AmbientLife, which keeps its own scan. No file path lives in game code.
# What the client cannot tell yet is marked in the slot's tags and handled by name: canyon, volcano, desert, dry scrub, polar and ice biomes and lava have
# no client lookup, so those slots wait for `force_biome` / `set_anchor` (the sound test and the rig use them) until a biome lookup exists.
#   sound.ambience.update(delta, body)         every frame from the sound stage
#   sound.ambience.test_press()                the "Sound test: Batch 2" entry: each group in turn, each clip played three times back to back

const AmbientLife := preload("res://src/client/ambient_life.gd")
const Sound3D := preload("res://src/client/sound_3d.gd")
const SlotSounds := preload("res://src/client/slot_sounds.gd")
const SLOTS_PATH := "res://data/sound/batch2_slots.json"
const CHECK_SEC := 1.5
const FADE_S := 2.0
const SILENT_DB := -60.0
const GAP_S := [4.0, 20.0]
const PITCH_SPREAD := 0.05
const ONESHOT_DIST_M := [12.0, 45.0]
const ONESHOT_HEIGHT_M := {"birds": [3.0, 10.0], "night birds": [4.0, 9.0]}
const REPLACES := ["bird_whistle", "bird_trill", "owl_hoot", "frog_croak"]      # AmbientLife calls these slots take over (no doubled birds)
const DUSK_BEFORE_H := 1.0
const DARK_MARGIN_H := 0.5
const NEAR_WATER := 0.4                   # water zone weight from which a pond or the sea edge is near
const SEA_EDGE_M := 8.0
const TEST_REPS := 3
const TEST_ONESHOT_MAX_S := 6.0
const TEST_BED_MAX_S := 15.0

var enabled: bool = true
var force_biome: String = ""              # a biome name the client cannot read yet (canyon, volcano, desert ...): rig and test
var anchors: Dictionary = {}              # slot -> Vector3 where a positional bed sits (volcano crater, lava)
var played: Dictionary = {}               # slot -> one-shots played
var beds_started: Dictionary = {}         # slot -> times a bed was started (the rig reads this)
var test_note: String = ""
var current: Dictionary = {}              # layer -> slot name playing now ("" none)

var _stage
var _slots: Dictionary = {}
var _beds: Dictionary = {}                # layer -> {"slot", "player", "fading"}; fading ones are dropped when silent
var _fading: Array = []
var _positional: Dictionary = {}          # slot -> AudioStreamPlayer3D
var _check_left: float = 0.0
var _gap_left: float = 6.0
var _voices: Array = []
var _last_pick: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _ctx: Dictionary = {}
var _test_group: int = -1
var _test_token: int = 0
var _test_players: Array = []


func setup(stage, slots_path: String = SLOTS_PATH) -> void:
	_stage = stage
	_rng.randomize()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(slots_path))

	if typeof(parsed) == TYPE_DICTIONARY and parsed.get("slots") is Dictionary:
		_slots = parsed["slots"]

	if stage != null and stage.get("ambient") != null:
		stage.ambient.replaced = REPLACES.duplicate()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--biome="):
			force_biome = arg.get_slice("=", 1)


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


# The biomes the client can tell from what AmbientLife measures (trees, grass, water, height); `forced` adds one it cannot.
static func biomes_for(forest: float, meadow: float, water: float, height_m: float, forced: String = "") -> Array:
	var list: Array = []

	if forest >= 0.35:
		list.append_array(["temperate_forest", "boreal_forest", "woodland"])

	if meadow >= 0.35:
		list.append("grassland")

	if water >= NEAR_WATER and height_m < SEA_EDGE_M:
		list.append("beach")

	if forced != "":
		list.append(forced)

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


# ---------------------------------------------------------------- the running layer

func context(body: Node3D) -> Dictionary:
	var conditions: Dictionary = _stage.ambient.conditions
	var weights: Dictionary = _stage.ambient.weights
	var height: float = body.global_position.y
	return {
		"season": str(conditions.get("season", "autumn")),
		"time": time_class(float(conditions.get("hour", 14.0)), str(conditions.get("season", "autumn"))),
		"biomes": biomes_for(float(weights.get("forest", 0.0)), float(weights.get("meadow", 0.0)), float(weights.get("water", 0.0)), height, force_biome),
		"water": float(weights.get("water", 0.0)),
		"height": height,
		"lava": anchors.has("bed_lava_hiss"),
	}


func update(delta: float, body: Node3D) -> void:
	if not enabled or _slots.is_empty() or _stage == null:
		return

	_fade_all(delta)
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
		_gap_left = _rng.randf_range(float(GAP_S[0]), float(GAP_S[1]))
		_one_shot(body)


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
	var now: String = str(_beds.get(layer, {}).get("slot", ""))
	current[layer] = now

	if slot == now:
		return

	if _beds.has(layer):
		_fading.append(_beds[layer]["player"])
		_beds.erase(layer)

	current[layer] = ""

	if slot == "" or not _stage.has_room():
		return

	var stream: AudioStream = _stream(slot)

	if stream == null:
		return

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = _looped(stream)
	player.bus = "Nature"
	player.volume_db = SILENT_DB
	add_child(player)
	player.play()
	_beds[layer] = {"slot": slot, "player": player}
	current[layer] = slot
	beds_started[slot] = int(beds_started.get(slot, 0)) + 1


func _set_positional(body: Node3D) -> void:
	var wanted: Dictionary = {}

	for slot in matching(_slots, "positional", _ctx):
		if wanted.size() >= 2:
			break

		var at: Vector3 = Vector3.INF

		if anchors.has(slot):
			at = anchors[slot]
		elif str(_slots[slot].get("tags", {}).get("near_water", "")) == "pond":
			at = _stage.ambient.nearest_wet_point(body.global_position)

		if at != Vector3.INF:
			wanted[slot] = at

	for slot in _positional.keys():
		if not wanted.has(slot):
			_fading.append(_positional[slot])
			_positional.erase(slot)

	for slot in wanted:
		if _positional.has(slot):
			_positional[slot].global_position = wanted[slot]
			continue

		var stream: AudioStream = _stream(slot)

		if stream == null or not _stage.has_room():
			continue

		var player: AudioStreamPlayer3D = Sound3D.make(self, "Nature", 10.0, 90.0)
		player.stream = _looped(stream)
		player.volume_db = SILENT_DB
		player.global_position = wanted[slot]
		player.play()
		_positional[slot] = player
		beds_started[slot] = int(beds_started.get(slot, 0)) + 1


func _fade_all(delta: float) -> void:
	for layer in _beds:
		var player: AudioStreamPlayer = _beds[layer]["player"]
		player.volume_db = move_toward(player.volume_db, 0.0, 60.0 / FADE_S * delta)

	for slot in _positional:
		var player3d: AudioStreamPlayer3D = _positional[slot]
		player3d.volume_db = move_toward(player3d.volume_db, 0.0, 60.0 / FADE_S * delta)

	for n in range(_fading.size() - 1, -1, -1):
		var gone = _fading[n]

		if not is_instance_valid(gone):
			_fading.remove_at(n)
			continue

		gone.volume_db = move_toward(gone.volume_db, SILENT_DB, 60.0 / FADE_S * delta)

		if gone.volume_db <= SILENT_DB + 0.5:
			gone.queue_free()
			_fading.remove_at(n)


func _one_shot(body: Node3D) -> void:
	if _voices.size() >= 2 or not _stage.has_room():
		return

	var options: Array = matching(_slots, "oneshot", _ctx)

	if options.is_empty():
		return

	var slot: String = options[_rng.randi() % options.size()]
	var files: Array = _slots[slot].get("files", [])
	var pick: int = SlotSounds.pick_index(files.size(), int(_last_pick.get(slot, -1)), _rng.randi())
	_last_pick[slot] = pick
	var stream: AudioStream = _stream(slot, pick)

	if stream == null:
		return

	var angle: float = _rng.randf() * TAU
	var distance: float = _rng.randf_range(float(ONESHOT_DIST_M[0]), float(ONESHOT_DIST_M[1]))
	var band: Array = ONESHOT_HEIGHT_M.get(str(_slots[slot].get("group", "")), [0.0, 0.0])
	var at: Vector3 = body.global_position + Vector3(cos(angle) * distance, _rng.randf_range(float(band[0]), float(band[1])) - 0.9, sin(angle) * distance)
	var player: AudioStreamPlayer3D = Sound3D.make(self, "Nature", 8.0, 120.0)
	player.stream = stream
	player.pitch_scale = 1.0 + _rng.randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	_voices.append(player)
	played[slot] = int(played.get(slot, 0)) + 1


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
