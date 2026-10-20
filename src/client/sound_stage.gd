extends Node

# The first sound stage (client only; DESIGN_IDEAS Section 6.17, budget in
# ARCHITECTURE_BUDGET Section 9). Three things for now:
#
# - Wind: two looping layers, a broad low body and an airy top that whistles
#   in the gusts. Gust strength drifts slowly; the wind is louder up high,
#   softer among trees, rushes past while flying, and the grass sways with
#   the same gusts. Under water everything is muffled.
# - Footsteps: fired by the walking bob at each footfall (terrain_client.gd),
#   chosen by what is under the feet (the voxel's soil or rock, water depth),
#   heavier and louder when jogging or running, and a landing after a fall.
# - Grass: a soft swish against the boots with each step through grass,
#   louder in the tall patches and at speed.
#
# The sounds are made by assets/audio/make_sounds.py. Real recordings can
# replace them under the same names (name_N.ogg; every variant found is used).

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const AmbientScript := preload("res://src/client/ambient_life.gd")
const WeatherScript := preload("res://src/client/weather_sounds.gd")
const DigScript := preload("res://src/client/dig_sounds.gd")
const CaveScript := preload("res://src/client/cave_sounds.gd")
const HitScript := preload("res://src/client/hit_sounds.gd")
const TownScript := preload("res://src/client/town_sounds.gd")
const SwimScript := preload("res://src/client/swim_sounds.gd")
const UiScript := preload("res://src/client/ui_sounds.gd")
const CreatureScript := preload("res://src/client/creature_sounds.gd")
const GearScript := preload("res://src/client/gear_sounds.gd")
const InteriorScript := preload("res://src/client/interior_sounds.gd")
const SpearScript := preload("res://src/client/spear_sounds.gd")
const TreeScript := preload("res://src/client/tree_sounds.gd")
const FireScript := preload("res://src/client/fire_sounds.gd")
const ItemScript := preload("res://src/client/item_sounds.gd")
const OcclusionScript := preload("res://src/client/sound_occlusion.gd")
const WaterSoundsScript := preload("res://src/client/water_sounds.gd")
const AUDIO_DIR := "res://assets/audio/"
const RECORDED_DIR := "res://assets/audio/recorded/"
# Audio budget per quality tier Low, Mid, High (ARCHITECTURE_BUDGET.md section 9).
const WaterVolume := preload("res://src/shared/water_volume.gd")
const CoverScript := preload("res://src/shared/cover.gd")
const Presets := preload("res://src/client/sound_presets.gd")   # the per-tier mixer limits (voices, memory, layers)
const VOICES := 6                       # footstep and swish players, reused in turn
const FEET_M := 0.9                     # player origin to the soles (capsule half height)

# Soil ids (data/tables/soils.json) to footstep surfaces. Rock (MATERIAL_ROCK
# and above) is stone; water deeper than WATER_STEP_M splashes, a thinner
# film at the waterline sounds damp (mud).
const SOIL_SURFACE := {
	0: "stone", 1: "sand", 2: "gravel", 3: "dirt", 4: "dirt", 5: "dirt", 6: "mud", 7: "dirt",
	8: "leaves", 9: "gravel", 10: "dirt", 11: "snow", 12: "stone", 13: "sand", 14: "sand", 15: "sand",
	16: "mud",
}
const SURFACE_DB := {
	"grass": -15.0, "dirt": -10.0, "sand": -8.0, "gravel": -9.0, "stone": -8.0,
	"leaves": -6.0, "mud": -10.0, "snow": -11.0, "water": -10.0,
	"grass_tall": -14.0, "bushes": -13.0,
}
# Exposed rock under the soles (rock id = material - MATERIAL_ROCK; data/tables/rocks.json):
# [surface, dB, pitch]. Soft rock scuffs like loose ground, dense hard rock rings a little.
const ROCK_STEP := {
	1: ["gravel", -2.0, 0.95], 2: ["gravel", -1.0, 1.0], 3: ["stone", -1.0, 1.0], 4: ["stone", -4.0, 0.88],
	5: ["stone", 1.0, 1.03], 6: ["stone", 0.0, 1.05], 7: ["stone", 1.0, 1.02], 8: ["gravel", -3.0, 0.98],
	9: ["stone", 1.0, 1.05], 10: ["sand", -4.0, 0.95], 11: ["gravel", -3.0, 0.92],
}
# Ore showing in that rock (data/tables/resources.json ids): metals and gems ring, coal is dull,
# salt crunches, clay is sticky.
const ORE_STEP := {1: ["stone", -3.0, 0.9], 10: ["sand", 0.0, 1.05], 12: ["mud", 0.0, 1.0], 29: ["mud", -2.0, 0.9]}
const ORE_METAL := [2, 3, 4, 5, 6, 7, 8, 9, 15, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27]
# Soils with their own character: [dB, pitch] on top of their surface (data/tables/soils.json).
const SOIL_TUNE := {3: [-1.0, 0.95], 4: [0.0, 0.97], 12: [2.0, 1.1], 13: [0.0, 1.06], 14: [-3.0, 0.9]}
const RAIN_SOAK := 0.5                  # ground wetness from which loose dirt and leaves turn to wet mud steps
const SNOW_COVER := 0.35                # snow on the ground from which steps crunch
const PUDDLE_WET := 0.6                 # ground wetness from which steps on firm ground splash
const SNOW_SURFACES := ["grass", "grass_tall", "dirt", "leaves", "sand", "gravel", "bushes", "mud"]
const PUDDLE_SURFACES := ["grass", "grass_tall", "stone", "gravel", "sand", "bushes"]
const PUDDLE_DB := -13.0
# Esc > Settings mixer groups: name -> the buses it sets. Shares step through VOLUME_STEPS.
const MIX_GROUPS := {"wind": ["Wind"], "nature": ["Nature", "Weather"], "steps": ["Foley"]}
const SETTINGS_PATH := "user://sound_settings.cfg"
const EXPOSURE_RING_M := 70.0           # ground is read on this ring around the player
const EXPOSURE_FULL_M := 40.0           # this far above or below the ring's average is a full ridge or valley
const EXPOSURE_GAIN := 0.45             # ridge wind is this much stronger (valley this much weaker)
const EXPOSURE_EVERY_FRAMES := 6        # one ring point per this many frames
const GRASS_MIN := 0.35                 # grass thickness from which a step sounds like grass
const WATER_STEP_M := 0.12              # water above the soles that turns steps into splashes
const DAMP_M := 0.03                    # shallower film at the waterline: a damp, muddy step
const SWIM_M := 1.3                     # deeper than this: no footsteps
# Walk quiet, jog a little louder, run loud (owner 2026-10-19: build 47's run
# level was a bit too loud for running).
const GAIT_DB := [-25.0, -19.0, -13.0]   # walk, jog, run (owner 2026-10-20: a little quieter again, 3 dB down)
const GAIT_PITCH := [1.0, 1.03, 1.06]
const VOLUME_STEPS := [1.0, 0.75, 0.5, 0.25, 0.0]
# Owner (2026-10-20, a slight pause about once a second while moving): the shelter count
# was a sphere query of up to 64 trunks every second (3 to 10 ms a call). The wind shelter
# moves slowly, so it is asked for less often and stops counting at 16 trunks (14 is full shelter).
const SHELTER_MSEC := 2500
const SHELTER_HITS := 16

var steps_played: Dictionary = {}       # surface -> count (for the headless walk check)
var swishes_played: int = 0
var puddles_played: int = 0
var surface: String = ""                # what the feet were last on
var _stable: String = ""                # the surface being sounded (changes only after two steps)
var _pending: String = ""
var last_step: String = ""              # for the HUD: ground, soil id, water depth, file played
var wind_strength: float = 0.0          # the wind loudness measure now (HUD)
var exposure: float = 0.0               # -1 valley floor .. +1 ridge or hilltop (height against the ground around)
var gust: float = 0.0                   # 0 calm .. 1 strongest gust
var volume_index: int = 0
var levels: Dictionary = {"master": 1.0, "effects": 1.0, "ambient": 1.0, "interface": 1.0}   # Esc > Settings sliders, 0 to 1
var mix_index: Dictionary = {"wind": 0, "nature": 0, "steps": 0}   # per group, into VOLUME_STEPS
var tier: int = 2                       # quality index (0 Low); set_quality()
var voice_cap: int = 96                 # preset["voices"]
var preset: Dictionary = Presets.row(2) # this tier's mixer row (sound_presets.gd); layers read their limits here
var shed_count: int = 0                 # sounds cut to stay inside the voice cap (farthest and quietest first)
var voices_peak: int = 0                # most sounds playing together so far (HUD)
var _voice_count: int = 0               # sounds playing at the last count
var _count_left: float = 0.0
static var loaded_bytes: int = 0        # sound files read from disk so far (each counted once)
static var _loaded_paths: Dictionary = {}
static var memory_cap_bytes: int = 600 * 1048576
static var refused_loads: int = 0

var _terrain: VoxelLodTerrain
var _flora
var _grass
var _tool: VoxelTool
var _height_tool: VoxelTool             # ray tool for the ground height ring (exposure)
var _ring_frames: int = 0
var _ring_at: int = 0
var _ring_heights: Dictionary = {}      # ring point -> ground height there
var _streams: Dictionary = {}           # sound name -> Array of AudioStream variants
var _last_variant: Dictionary = {}
var _recorded: Dictionary = {}          # sound names that come from assets/audio/recorded/
var _voices: Array = []
var _next_voice: int = 0
var _wind_low: AudioStreamPlayer
var _wind_gust: AudioStreamPlayer
var _wind_filter: AudioEffectLowPassFilter
var _muffle: AudioEffectLowPassFilter
var _gust_noise := FastNoiseLite.new()
var _time: float = 0.0
var _shelter: float = 0.0               # 0 open .. 1 deep in the trees
var _shelter_target: float = 0.0
var _shelter_msec: int = 0
var _air_time: float = 0.0
var _rng := RandomNumberGenerator.new()
var ambient                             # AmbientLife: birds, crickets, frogs by zone
var water                               # WaterSounds: brooks, rivers, pond shores, waterfalls
var weather                             # WeatherSounds: rain, gale, thunder, snow hush (set_weather)
var occlusion                           # SoundOcclusion: hills and forest muffle distant sounds
var hits                                # HitSounds: axe, pick, hammer, spade on wood, stone, soil (hit, hit_ground)
var trees                               # TreeSounds: felling (watch the world rows, fall(), chips())
var fire                                # FireSounds: campfire loops by size, lit, put out, rain sizzle (set_fires)
var ground_below: Callable = Callable()   # terrain_client sets this: ground height under a point (NAN when not loaded)
var itemfx                              # ItemSounds: inventory cues (watch(items) every frame)
var spear                               # SpearSounds: jab, throw, flight, hits on wood, stone, soil, flesh
var interior                            # InteriorSounds: inside a building, doors, chests, furniture (set_inside, object)
var gear                                # GearSounds: armour and clothing layers on the footsteps (set_worn, step_at)
var creatures                           # CreatureSounds: deer, rabbit, fox, wolf, bear calls (call_at, call_in_zone; wild = natural far calls)
var ui                                  # UiSounds: menu click, toggle and quality cues (play(name))
var swim                                # SwimSounds: splash, strokes, diving, the hum under water (driven by the body)
var town                                # TownSounds: fire, hammering, crowd, bell hooks (set_sources, ring_bell)
var cave                                # CaveSounds: reverb, muffling and drips under rock
var dig                                 # DigSounds: the sound of what is dug (dug(center, radius, listener))
var _sphere: PhysicsShapeQueryParameters3D


func setup(terrain: VoxelLodTerrain, flora, grass) -> void:
	_terrain = terrain
	_flora = flora
	_grass = grass
	_tool = terrain.get_voxel_tool()
	_height_tool = terrain.get_voxel_tool()
	_height_tool.channel = VoxelBuffer.CHANNEL_SDF
	_rng.randomize()
	_gust_noise.seed = 9
	_gust_noise.frequency = 0.02
	_gust_noise.fractal_octaves = 2
	var wind_bus: int = _make_bus("Wind")
	_wind_filter = AudioEffectLowPassFilter.new()
	_wind_filter.cutoff_hz = 4000.0
	AudioServer.add_bus_effect(wind_bus, _wind_filter)
	_make_bus("Foley")
	_make_bus("Nature")
	_make_bus("Weather")
	_muffle = AudioEffectLowPassFilter.new()
	_muffle.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(0, _muffle)

	_wind_low = _player("Wind", "wind_low")
	_wind_gust = _player("Wind", "wind_gust")

	for player in [_wind_low, _wind_gust]:
		if player.stream is AudioStreamOggVorbis:
			player.stream.loop = true

	for n in range(VOICES):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.bus = "Foley"
		add_child(voice)
		_voices.append(voice)

	ambient = AmbientScript.new()
	ambient.name = "Ambient"
	add_child(ambient)
	ambient.setup(self, _terrain, _flora, _grass)
	water = WaterSoundsScript.new()
	water.name = "Water"
	add_child(water)
	water.setup(_flora, _terrain)
	weather = WeatherScript.new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(self, ambient)
	dig = DigScript.new()
	dig.name = "Dig"
	add_child(dig)
	dig.setup(self)
	town = TownScript.new()
	town.name = "Town"
	add_child(town)
	town.setup(self)
	trees = TreeScript.new()
	trees.name = "Trees"
	add_child(trees)
	trees.setup(self)
	fire = FireScript.new()
	fire.name = "Fire"
	add_child(fire)
	fire.setup(self)
	itemfx = ItemScript.new()
	itemfx.name = "ItemFx"
	add_child(itemfx)
	itemfx.setup(self)
	spear = SpearScript.new()
	spear.name = "Spear"
	add_child(spear)
	spear.setup(self)
	interior = InteriorScript.new()
	interior.name = "Interior"
	add_child(interior)
	interior.setup(self)
	gear = GearScript.new()
	gear.name = "Gear"
	add_child(gear)
	gear.setup(self)
	creatures = CreatureScript.new()
	creatures.name = "Creatures"
	add_child(creatures)
	creatures.setup(self)
	ui = UiScript.new()
	ui.name = "Ui"
	add_child(ui)
	ui.setup(self)
	swim = SwimScript.new()
	swim.name = "Swim"
	add_child(swim)
	swim.setup(self)
	hits = HitScript.new()
	hits.name = "Hits"
	add_child(hits)
	hits.setup(self)
	cave = CaveScript.new()
	cave.name = "Cave"
	add_child(cave)
	cave.setup(self)
	occlusion = OcclusionScript.new()
	occlusion.name = "Occlusion"
	add_child(occlusion)
	occlusion.setup(self, _terrain)

	_load_settings()

	if _wind_low.stream != null:
		_wind_low.play()

	if _wind_gust.stream != null:
		_wind_gust.play(_rng.randf() * 20.0)


# Samples the ground height on a ring around the player, one point every few frames, and
# eases `exposure` toward how far the player stands above (+) or below (-) its average.
func _sample_exposure(delta: float, body: CharacterBody3D, flying: bool) -> void:
	if flying:
		exposure = move_toward(exposure, 0.0, delta * 0.3)
		return

	_ring_frames += 1

	if _ring_frames % EXPOSURE_EVERY_FRAMES == 0:
		var points: int = int(preset["exposure_points"])
		_ring_at = (_ring_at + 1) % points
		var angle: float = TAU * float(_ring_at) / float(points)
		var at: Vector3 = body.global_position + Vector3(cos(angle), 0.0, sin(angle)) * EXPOSURE_RING_M
		var hit = _height_tool.raycast(at + Vector3(0.0, 120.0, 0.0), Vector3.DOWN, 400.0)

		if hit != null:
			_ring_heights[_ring_at] = at.y + 120.0 - float(hit.distance)

	var total: float = 0.0
	var count: int = 0

	for value in _ring_heights.values():
		total += float(value)
		count += 1

	if count >= 3:
		var target: float = clampf((body.global_position.y - total / float(count)) / EXPOSURE_FULL_M, -1.0, 1.0)
		exposure = move_toward(exposure, target, delta * 0.3)


# Each frame: wind loudness and colour, landing thumps, the underwater muffle.
func update(delta: float, body: CharacterBody3D, flying: bool, underwater: bool) -> void:
	_count_left -= delta

	if _count_left <= 0.0:
		_count_left = 0.25
		_voice_count = voices_playing()
		voices_peak = maxi(voices_peak, _voice_count)

		if _voice_count > voice_cap:
			_shed(body, _voice_count - voice_cap)

	ambient.update(delta, body, flying)
	water.update(delta, body, underwater)
	weather.update(delta, body, underwater)
	dig.update(delta)
	cave.update(delta, body, flying)
	town.update(delta, body)
	swim.update(delta, body, flying, underwater)
	creatures.update(delta)
	interior.update(delta)
	spear.update(delta)
	fire.update(delta, body)
	trees.update(delta)
	occlusion.update(delta, body, flying)
	_time += delta
	gust = clampf(0.5 + 0.8 * _gust_noise.get_noise_1d(_time), 0.0, 1.0)
	var position: Vector3 = body.global_position
	var now: int = Time.get_ticks_msec()

	if now >= _shelter_msec:
		_shelter_msec = now + SHELTER_MSEC
		_shelter_target = clampf(float(_trunks_near(body, 18.0)) / 14.0, 0.0, 1.0)

	_shelter = move_toward(_shelter, _shelter_target, delta * 0.5)
	var height: float = clampf((position.y - 10.0) / 300.0, 0.0, 1.0)   # higher is windier
	var rush: float = clampf(body.velocity.length() / 80.0, 0.0, 1.0) if flying else 0.0
	_sample_exposure(delta, body, flying)
	# The world's wind (src/shared/weather.gd, 0.15 calm to 1 storm) sets the mean and how much
	# the gusts add; a ridge or hilltop is windier than the valley floor (exposure -1 to +1).
	var wind: float = weather.world_wind
	var open: float = 1.0 + EXPOSURE_GAIN * exposure
	var strength: float = clampf((0.25 + 0.55 * wind + (0.3 + 0.5 * wind) * gust) * open + 0.2 * height - 0.45 * _shelter + rush, 0.05, 1.6)
	# A calm day (owner, 2026-10-19: the first version sounded like a storm by the sea).
	# Owner 2026-10-19, twice: still a windstorm. Now a faint breeze that only rises a little in gusts.
	# Build 51: the low layer still sounded like surf nearby; it is lower again.
	wind_strength = strength
	# Build 79: still like a river; lower again and the loops now have deep lulls between the swells.
	_wind_low.volume_db = linear_to_db(0.0035 + 0.006 * strength)
	_wind_gust.volume_db = linear_to_db(0.0025 + 0.012 * pow(strength, 1.6))
	_wind_filter.cutoff_hz = lerpf(1500.0, 7000.0, clampf(strength - 0.2 * _shelter, 0.0, 1.0)) * (1.0 + 0.25 * exposure)   # whistles on a ridge, hushed in a valley
	_muffle.cutoff_hz = 500.0 if underwater else 20000.0

	if _grass != null:
		_grass.set_wind(strength)

	# A landing after a short fall sounds like a heavy step.
	if flying or not body.is_on_floor():
		_air_time += delta
	else:
		if _air_time > 0.45:
			footstep(body, 2, 4.0)

		_air_time = 0.0


# Sets the audio budget for a quality tier (0 Low, 1 Mid, 2 High).
func set_quality(quality: int) -> void:
	tier = clampi(quality, 0, Presets.ROWS.size() - 1)
	preset = Presets.row(tier)
	voice_cap = int(preset["voices"])
	memory_cap_bytes = int(preset["memory_mb"]) * 1048576
	ambient.max_voices = int(preset["nature_calls"])
	cave.set_tier(tier)
	town.set_tier(tier)
	creatures.set_tier(tier)


# Over the voice cap (loops and steps always play, so optional sounds can pile up): cuts the one-shot
# 3D sounds with the lowest priority, the farthest and quietest first, `count` of them. Danger cues
# (a threat call, the crow alarm) carry the meta "keep" and are never cut.
func _shed(body: CharacterBody3D, count: int) -> void:
	var candidates: Array = []

	for player in get_tree().get_nodes_in_group("world_sounds"):
		if not is_instance_valid(player) or not player.playing or player.has_meta("keep"):
			continue

		if player.stream is AudioStreamOggVorbis and player.stream.loop:
			continue

		var distance: float = player.global_position.distance_to(body.global_position)
		candidates.append([distance - player.volume_db * 4.0, player])         # far and quiet sorts last

	candidates.sort_custom(func(a, b): return a[0] > b[0])

	for n in range(mini(count, candidates.size())):
		candidates[n][1].stop()
		candidates[n][1].queue_free()
		shed_count += 1


# Every sound playing right now, all layers (the budget counts these).
func voices_playing() -> int:
	var count: int = 0

	for player in [_wind_low, _wind_gust] + _voices:
		if player.playing:
			count += 1

	# Every positioned sound is in the group world_sounds (calls, water, town, tools, digging, creatures, drips).
	for player in get_tree().get_nodes_in_group("world_sounds"):
		if is_instance_valid(player) and player.playing:
			count += 1

	return count + weather.voices_playing() + swim.voices_playing() + interior.voices_playing()


# True while another optional sound (a call, a flush) fits in the voice budget.
func has_room() -> bool:
	return _voice_count < voice_cap


func wind_text() -> String:
	return "wind %.2f (world %.2f, exposure %+.2f: -1 valley, +1 ridge)" % [wind_strength, weather.world_wind, exposure]


func budget_text() -> String:
	return "sounds %d/%d playing (peak %d), %.1f/%d MB loaded (%s)" % [_voice_count, voice_cap, voices_peak, float(loaded_bytes) / 1048576.0, int(preset["memory_mb"]), Presets.NAMES[tier]]


# One footfall at gait 0 walk, 1 jog, 2 run; `boost_db` makes it louder (landings).
# `foot` is "left" or "right" (recorded sets have one of each).
func footstep(body: CharacterBody3D, gait: int, boost_db: float = 0.0, foot: String = "left") -> void:
	var feet: Vector3 = body.global_position - Vector3(0.0, FEET_M, 0.0)
	var water: float = _flora.water_surface_at(feet.x, feet.z)

	if feet.y < 0.0 and (is_nan(water) or water < 0.0):
		water = 0.0                                              # the sea

	var depth: float = water - feet.y if not is_nan(water) else -1.0

	if depth > SWIM_M:
		return

	var soil: int = _ground_under(feet)
	var tune: Array = [0.0, 1.0]                                 # dB and pitch for this ground's character
	var thick: float = 0.0
	var tall: float = 0.0

	if _grass != null and soil >= 0 and soil < Layout.MATERIAL_ROCK:
		var grass: Vector2 = _grass.grass_at(feet.x, feet.z, soil)
		thick = grass.x
		tall = grass.y

	if depth > WATER_STEP_M:
		surface = "water"
		thick = 0.0
	elif depth > DAMP_M:
		surface = "mud"                                          # wet ground at the waterline
		thick = 0.0
	elif soil < 0:
		surface = "stone"
	elif soil >= Layout.MATERIAL_ROCK:
		var rock: Array = ROCK_STEP.get(soil - Layout.MATERIAL_ROCK, ["stone", 0.0, 1.0])
		var ore: int = _ore_under(feet)
		var found: Array = ORE_STEP.get(ore, ["stone", 1.0, 1.07] if ore in ORE_METAL else rock)
		surface = found[0]
		tune = [found[1], found[2]]
	elif _in_bush(feet):
		surface = "bushes"
	elif thick >= GRASS_MIN and soil != 8:
		surface = "grass_tall" if tall > 0.35 else "grass"
	else:
		surface = str(SOIL_SURFACE.get(soil, "dirt"))
		tune = SOIL_TUNE.get(soil, [0.0, 1.0])

		if surface in ["dirt", "leaves"] and weather != null and weather.ground_wet >= RAIN_SOAK:
			surface = "mud"                                      # soaked ground
			tune = [-2.0, 1.0]

	# Snow lying on the ground (it fell, and has not melted): any loose ground crunches.
	if weather != null and weather.ground_snow >= SNOW_COVER and surface in SNOW_SURFACES:
		surface = "snow"
		tune = [0.0, 1.0]

	# Steady ground: a different surface must show on two steps in a row before the sound
	# changes, so one odd sample (a bush, a patch edge) never flips it back and forth.
	if _stable == "":
		_stable = surface
	elif surface == _stable:
		_pending = ""
	elif surface == _pending:
		_stable = surface
		_pending = ""
	else:
		_pending = surface

	surface = _stable
	# Sets without their own sounds borrow one (generated grass for tall grass and bushes).
	var name: String = "step_" + surface

	if _variants(name).is_empty() and _variants(name + "_" + foot).is_empty():
		name = "step_grass"

	var recorded: bool = _recorded.has(name + "_" + foot) or _recorded.has(name)
	var pitch: float = GAIT_PITCH[gait] * _rng.randf_range(0.96, 1.04) * tune[1]
	last_step = "%s (soil %d, water %.2f m, %s)" % [surface, soil, depth, name + "_" + foot if recorded else name + " generated"]
	_play(name, float(SURFACE_DB.get(surface, -9.0)) + float(tune[0]) + GAIT_DB[gait] + boost_db + _rng.randf_range(-1.5, 1.0), pitch, foot)
	steps_played[surface] = int(steps_played.get(surface, 0)) + 1
	gear.step(gait, boost_db, surface)

	# Wet ground: a puddle splash joins most steps on grass, stone, gravel and sand.
	if weather != null and weather.ground_wet >= PUDDLE_WET and surface in PUDDLE_SURFACES and _rng.randf() < weather.ground_wet * 0.7:
		puddles_played += 1
		_play("step_water", PUDDLE_DB + GAIT_DB[gait] - float(GAIT_DB[0]) + _rng.randf_range(-2.0, 1.0), _rng.randf_range(0.95, 1.15) * GAIT_PITCH[gait], foot)

	# The recorded grass, tall grass and bush steps carry the swish of the blades themselves.


# Esc > Settings mixer: steps one group (wind, nature, steps) through 100, 75, 50, 25 % and off.
# Returns the new share. Saved for the next run.
func mix_step(group: String) -> float:
	mix_index[group] = (int(mix_index[group]) + 1) % VOLUME_STEPS.size()
	_apply_mix(group)
	_save_settings()
	return float(VOLUME_STEPS[int(mix_index[group])])


func _apply_mix(_group: String = "") -> void:
	_apply_buses()


# Esc > Settings sliders (build 151): master, effects (footsteps, tools, items, fire, town), ambient
# (wind, nature, weather) and interface, each 0 to 1, saved in the same file as the mixer steps.
# A bus plays at its slider times its mixer step (wind, nature, steps) and Master also times the
# old stepped volume. 0 mutes the bus.
func set_level(name: String, value: float) -> void:
	if not levels.has(name):
		return

	levels[name] = clampf(value, 0.0, 1.0)
	_apply_buses()
	_save_settings()


func _apply_buses() -> void:
	var shares: Dictionary = {
		"Master": float(levels["master"]) * float(VOLUME_STEPS[volume_index]),
		"Foley": float(levels["effects"]) * float(VOLUME_STEPS[int(mix_index["steps"])]),
		"Wind": float(levels["ambient"]) * float(VOLUME_STEPS[int(mix_index["wind"])]),
		"Nature": float(levels["ambient"]) * float(VOLUME_STEPS[int(mix_index["nature"])]),
		"Weather": float(levels["ambient"]) * float(VOLUME_STEPS[int(mix_index["nature"])]),
		"Interface": float(levels["interface"]),
	}

	for bus_name in shares:
		var index: int = AudioServer.get_bus_index(bus_name)

		if index >= 0:
			var share: float = shares[bus_name]
			AudioServer.set_bus_mute(index, share <= 0.001)
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(share, 0.001)))


func _load_settings() -> void:
	var file: ConfigFile = ConfigFile.new()

	if file.load(SETTINGS_PATH) == OK:
		for group in MIX_GROUPS:
			mix_index[group] = clampi(int(file.get_value("mixer", group, 0)), 0, VOLUME_STEPS.size() - 1)

		for name in levels:
			levels[name] = clampf(float(file.get_value("levels", name, 1.0)), 0.0, 1.0)

	_apply_buses()


func _save_settings() -> void:
	var file: ConfigFile = ConfigFile.new()

	for group in MIX_GROUPS:
		file.set_value("mixer", group, int(mix_index[group]))

	for name in levels:
		file.set_value("levels", name, float(levels[name]))

	file.save(SETTINGS_PATH)


# Esc > Settings "Sound volume": 100, 75, 50, 25 % and off. Returns the new share.
func step_volume() -> float:
	volume_index = (volume_index + 1) % VOLUME_STEPS.size()
	_apply_buses()
	return VOLUME_STEPS[volume_index]


# Tree trunks within `radius` metres (their colliders, which exist near the
# player): the shelter from the wind.
func _trunks_near(body: CharacterBody3D, radius: float) -> int:
	if _sphere == null:
		_sphere = PhysicsShapeQueryParameters3D.new()
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = radius
		_sphere.shape = shape

	_sphere.transform = Transform3D(Basis.IDENTITY, body.global_position)
	_sphere.exclude = [body.get_rid()]
	var count: int = 0

	for hit in body.get_world_3d().direct_space_state.intersect_shape(_sphere, SHELTER_HITS):
		if hit["collider"] != null and hit["collider"].has_meta("species_ids"):
			count += 1

	return count


# 1.0 when the player stands under a tree's canopy, else 0.0 (owner 2026-10-20: any spot under a canopy
# counts, any tree): the shared Cover.at query (src/shared/cover.gd, tech/COVER_QUERY.md) on the flora's
# crown index. Rain, leaf drips and a dry ground all read this one function.
func under_cover(body: CharacterBody3D) -> float:
	if _flora == null or _flora.get("cover") == null:
		return 0.0

	return CoverScript.at(body.global_position, _flora.cover)


# The draw-material id under the soles: a soil id, MATERIAL_ROCK + rock id for
# bare rock, or -1 when the ground is not loaded.
func ground_at(feet: Vector3) -> int:
	return _ground_under(feet)


# The soil or rock id (CHANNEL_MATERIAL) at a point, -1 where the ground is not loaded.
func material_at(point: Vector3) -> int:
	_tool.channel = Layout.CHANNEL_MATERIAL
	var cell: Vector3i = Vector3i(point.floor())
	return _tool.get_voxel(cell) if _tool.is_area_editable(AABB(Vector3(cell), Vector3.ONE)) else -1


# The ore id (CHANNEL_RESOURCE) at a point, 0 when none.
func resource_at(point: Vector3) -> int:
	_tool.channel = Layout.CHANNEL_RESOURCE
	var cell: Vector3i = Vector3i(point.floor())
	return _tool.get_voxel(cell) if _tool.is_area_editable(AABB(Vector3(cell), Vector3.ONE)) else 0


# The water surface height above a point (NAN when there is no water there).
func water_level_at(point: Vector3) -> float:
	return _flora.water_surface_at(point.x, point.z)


# Water depth over the ground at a point by the shared WaterVolume rules (0 under MIN_DEPTH_M: a film is wet ground).
func water_depth_at(point: Vector3) -> float:
	var surface: float = water_level_at(point)
	var ground: float = ground_below.call(point) if ground_below.is_valid() else NAN
	var depth: float = WaterVolume.depth(surface, ground)
	return depth if depth >= WaterVolume.MIN_DEPTH_M else 0.0


# The ore id showing in the rock under the soles, 0 when none.
func _ore_under(feet: Vector3) -> int:
	_tool.channel = Layout.CHANNEL_RESOURCE

	for drop in [0.3, 0.8]:
		var cell: Vector3i = Vector3i((feet - Vector3(0.0, drop, 0.0)).floor())

		if _tool.is_area_editable(AABB(Vector3(cell), Vector3.ONE)):
			var ore: int = _tool.get_voxel(cell)

			if ore > 0:
				return ore

	return 0


func _ground_under(feet: Vector3) -> int:
	_tool.channel = Layout.CHANNEL_MATERIAL

	for drop in [0.3, 0.8]:
		var cell: Vector3i = Vector3i((feet - Vector3(0.0, drop, 0.0)).floor())

		if _tool.is_area_editable(AABB(Vector3(cell), Vector3.ONE)):
			return _tool.get_voxel(cell)

	return -1


# A shrub within reach of the feet (walking through a bush).
func _in_bush(feet: Vector3) -> bool:
	var id: int = _flora.species_near(feet, 0.9)
	return id >= 0 and int(_flora._species.get(id, {}).get("kind", -1)) == _flora.KIND_SHRUB


# Plays a variant of `name`; with `foot`, the foot's own set (name_left_N) when there is one.
func _play(name: String, volume_db: float, pitch: float, foot: String = "") -> void:
	var list: Array = _variants(name + "_" + foot) if foot != "" else []

	if list.is_empty():
		list = _variants(name)

	if list.is_empty():
		return

	# A different variant from last time, so steps never repeat back to back.
	var pick: int = _rng.randi_range(0, list.size() - 1)

	if list.size() > 1 and pick == int(_last_variant.get(name, -1)):
		pick = (pick + 1) % list.size()

	_last_variant[name] = pick
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = list[pick]
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	voice.play()


func _player(bus: String, name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus
	var list: Array = _variants(name)
	player.stream = list[0] if not list.is_empty() else null
	add_child(player)
	return player


# Every variant of a sound: name.ogg, or name_0.ogg, name_1.ogg ... Real
# recordings in assets/audio/recorded/ win over the generated ones in
# assets/audio/ (assets/audio/README.md says where to get them).
func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = _find(RECORDED_DIR, name)

	if list.is_empty():
		list = _find(AUDIO_DIR, name)
	else:
		_recorded[name] = true

	_streams[name] = list
	return list


# "recorded" or "generated" for a loaded sound, for the last-sound line.
static func tag(stream: Resource) -> String:
	return "recorded" if stream != null and stream.resource_path.contains("/recorded/") else "generated"


static func _find(folder: String, name: String) -> Array:
	var single: AudioStream = _load(folder, name)

	if single != null:
		return [single]

	var list: Array = []

	while true:
		var stream: AudioStream = _load(folder, "%s_%d" % [name, list.size()])

		if stream == null:
			break

		list.append(stream)

	return list


# The imported sound, or else straight from the file (headless runs have no imports).
# Takes name.ogg, or name.wav for a recording dropped in as it came.
static func _load(folder: String, name: String) -> AudioStream:
	for extension in ["ogg", "wav"]:
		var path: String = folder + name + "." + extension

		if not _loaded_paths.has(path) and loaded_bytes >= memory_cap_bytes and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
			refused_loads += 1                                       # over the tier's memory budget
			return null

		if not _loaded_paths.has(path) and FileAccess.file_exists(path):
			_loaded_paths[path] = true
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)

			if file != null:
				loaded_bytes += file.get_length()

		if ResourceLoader.exists(path):
			var imported: AudioStream = load(path) as AudioStream

			if imported != null:
				return imported

		if FileAccess.file_exists(path):
			return AudioStreamOggVorbis.load_from_file(path) if extension == "ogg" else AudioStreamWAV.load_from_file(path)

	return null


static func _make_bus(name: String) -> int:
	var index: int = AudioServer.get_bus_index(name)

	if index >= 0:
		return index

	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, name)
	AudioServer.set_bus_send(index, "Master")
	return index


# The buses and filters live in the audio server, which outlasts this scene.
func _exit_tree() -> void:
	for player in [_wind_low, _wind_gust] + _voices:
		player.stop()
		player.stream = null

	_streams.clear()

	for name in ["Wind", "Foley", "Nature", "Weather"]:
		var index: int = AudioServer.get_bus_index(name)

		if index >= 0:
			AudioServer.remove_bus(index)

	for n in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		if AudioServer.get_bus_effect(0, n) == _muffle:
			AudioServer.remove_bus_effect(0, n)
