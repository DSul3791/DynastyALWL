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
const SplashScript := preload("res://src/client/rain_splashes.gd")
const IceScript := preload("res://src/client/ice_sounds.gd")
const WindHoleScript := preload("res://src/client/wind_structures.gd")
const HitScript := preload("res://src/client/hit_sounds.gd")
const TownScript := preload("res://src/client/town_sounds.gd")
const SwimScript := preload("res://src/client/swim_sounds.gd")
const UiScript := preload("res://src/client/ui_sounds.gd")
const EmitterScript := preload("res://src/client/emitters.gd")
const CreatureScript := preload("res://src/client/creature_sounds.gd")
const GearScript := preload("res://src/client/gear_sounds.gd")
const InsectScript := preload("res://src/client/insect_bed.gd")
const StepFxScript := preload("res://src/client/step_fx.gd")
const WetSoundsScript := preload("res://src/client/wet_sounds.gd")
const LandingScript := preload("res://src/client/landing_sounds.gd")
const StanceScript := preload("res://src/client/stance_sounds.gd")
const InteriorScript := preload("res://src/client/interior_sounds.gd")
const SlotSoundsScript := preload("res://src/client/slot_sounds.gd")
const AmbienceSlotsScript := preload("res://src/client/ambience_slots.gd")
const SpearScript := preload("res://src/client/spear_sounds.gd")
const PlacedScript := preload("res://src/client/placed_sounds.gd")
const TreeWindScript := preload("res://src/client/tree_wind.gd")
const HarvestFxScript := preload("res://src/client/harvest_sounds.gd")
const WorkshopScript := preload("res://src/client/workshop_sounds.gd")
const FlameScript := preload("res://src/client/flame_sounds.gd")
const BreathScript := preload("res://src/client/breath_sounds.gd")
const TreeScript := preload("res://src/client/tree_sounds.gd")
const FireScript := preload("res://src/client/fire_sounds.gd")
const ItemScript := preload("res://src/client/item_sounds.gd")
const InnerVoiceScript := preload("res://src/client/inner_voice_sounds.gd")
const AirBands := preload("res://src/client/air_bands.gd")
const OcclusionScript := preload("res://src/client/sound_occlusion.gd")
const WaterSoundsScript := preload("res://src/client/water_sounds.gd")
const AUDIO_DIR := "res://assets/audio/"
const FLOORS_DIR := "res://assets/audio/floors/"   # generated built-floor steps (make_floors.py)
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
	"grass": -15.0, "dirt": -10.0, "sand": -11.0, "gravel": -9.0, "stone": -8.0,
	"leaves": -6.0, "mud": -10.0, "snow": -11.0, "ice": -9.0, "water": -10.0,
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
const SNOW_SURFACES := ["grass", "grass_tall", "dirt", "leaves", "sand", "gravel", "bushes", "mud", "path"]
# Built floors (hooks for the building system): plank, slab (stone slabs), carpet, thatch, path (a gravel path).
const FLOOR_SURFACES := {"plank": -9.0, "slab": -8.0, "carpet": -13.0, "thatch": -11.0, "path": -9.0}
const PUDDLE_SURFACES := ["grass", "grass_tall", "stone", "gravel", "sand", "bushes", "path", "slab"]
const PUDDLE_DB := -13.0
# Esc > Settings mixer groups: name -> the buses it sets. Shares step through VOLUME_STEPS.
const MIX_GROUPS := {"wind": ["Wind"], "nature": ["Nature", "Weather"], "steps": ["Foley"]}
const SETTINGS_PATH := "user://sound_settings.cfg"
const EXPOSURE_RING_M := 70.0           # ground is read on this ring around the player
const EXPOSURE_FULL_M := 40.0           # this far above or below the ring's average is a full ridge or valley
const EXPOSURE_GAIN := 0.45             # ridge wind is this much stronger (valley this much weaker)
const EXPOSURE_EVERY_FRAMES := 10       # one ring point per this many frames
const GRASS_MIN := 0.35                 # grass thickness from which a step sounds like grass
const WATER_STEP_M := 0.12              # water above the soles that turns steps into splashes
const DAMP_M := 0.03                    # shallower film at the waterline: a damp, muddy step
const SWIM_M := 1.3                     # deeper than this: no footsteps
# Walk quiet, jog a little louder, run loud (owner 2026-10-19: build 47's run
# level was a bit too loud for running).
const GAIT_DB := [-25.0, -19.0, -13.0]   # walk, jog, run (owner 2026-10-20: a little quieter again, 3 dB down)
const GAIT_PITCH := [1.0, 1.03, 1.06]
# Step loudness can be tweaked without code: data/sound/step_levels.json overrides SURFACE_DB, FLOOR_SURFACES values,
# GAIT_DB, GAIT_PITCH and PUDDLE_DB at start (job 76). The constants stay as the built-in fallback.
const STEP_LEVELS_PATH := "res://data/sound/step_levels.json"
var surface_db: Dictionary = SURFACE_DB.duplicate()
var floor_db: Dictionary = FLOOR_SURFACES.duplicate()
var gait_db: Array = GAIT_DB.duplicate()
var gait_pitch: Array = GAIT_PITCH.duplicate()
var surface_gait_db: Dictionary = {}     # surface -> [walk, jog, run] extra dB
var puddle_db: float = PUDDLE_DB
var step_levels_source: String = "built-in"
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
var floor_surface: String = ""          # a built floor under the feet (set_floor), "" for natural ground
var floor_under: Callable               # optional: (feet Vector3) -> floor surface name or "" (the building system sets it)
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
var _air_top: float = 0.0              # highest point of the current fall (landing_sounds.gd)
var _rng := RandomNumberGenerator.new()
var ambient                             # AmbientLife: birds, crickets, frogs by zone
var water                               # WaterSounds: brooks, rivers, pond shores, waterfalls
var weather                             # WeatherSounds: rain, gale, thunder, snow hush (set_weather)
var occlusion                           # SoundOcclusion: hills and forest muffle distant sounds
var hits                                # HitSounds: axe, pick, hammer, spade on wood, stone, soil (hit, hit_ground)
var flame                               # FlameSounds: the torch or lantern in the hand (set_held)
var breath                              # BreathSounds: breathing and heartbeat from exertion (set_exertion, stand-in follows the body)
var trees                               # TreeSounds: felling (watch the world rows, fall(), chips())
var fire                                # FireSounds: campfire loops by size, lit, put out, rain sizzle (set_fires)
var ground_below: Callable = Callable()   # terrain_client sets this: ground height under a point (NAN when not loaded)
var itemfx                              # ItemSounds: inventory cues (watch(items) every frame)
var inner                               # InnerVoiceSounds: the character's thoughts in the headset (speak(line_id, kind))
var workshop                            # WorkshopSounds: chopping block, plank drop and saw mill loops (hooks until workshops exist)
var harvestfx                           # HarvestSounds: plant picks (twist, pull, pluck, snap, snip) and the plant rustling; harvest.gd calls pick(row, at)
var treewind                            # TreeWind: pine hiss, leaf rustle, dry autumn leaves, bare winter branches by the trees near the player
var placed                              # PlacedSounds: lean-to and chest place/pick up, container, tool break and repair (hooks, watch_world)
var spear                               # SpearSounds: jab, throw, flight, hits on wood, stone, soil, flesh
var interior                            # InteriorSounds: inside a building, doors, chests, furniture (set_inside, object)
var stance                              # StanceSounds: crouch, sit, lie, rise and settle cloth sounds (set_stance); crouching softens steps
var gear                                # GearSounds: armour and clothing layers on the footsteps (set_worn, step_at)
var insects                             # InsectBed: summer insect chirring over meadows and water edges
var stepfx                              # StepFx: wet-shoe squelch and cloth rustle under footsteps
var slots                               # SlotSounds: Kathleen's batch 1 slots by name (doors by material, ladder, table, creature steps, water wheel; data/sound/batch1_slots.json)
var ambience                            # AmbienceSlots: Kathleen's batch 2 beds and one-shots by tags (data/sound/batch2_slots.json)
var wet                                 # WetSounds: drips and a trickle in a tunnel under water; the client feeds it the rock gap (drip_view.gap_m)
var landing                             # LandingSounds: thud and hard landing by fall height; signal hurt is the fall damage hook
var emitters                            # Emitters: sounds for server-owned entities (emit, sync); sound/EMITTER_API.md
var creatures                           # CreatureSounds: deer, rabbit, fox, wolf, bear calls (call_at, call_in_zone; wild = natural far calls)
var ui                                  # UiSounds: menu click, toggle and quality cues (play(name))
var swim                                # SwimSounds: splash, strokes, diving, the hum under water (driven by the body)
var town                                # TownSounds: fire, hammering, crowd, bell hooks (set_sources, ring_bell)
var windhole                           # WindStructures: whistle through a lean-to gap, moan at a cave mouth
var ice                                # IceSounds: frozen ponds (steps, cracks, groans)
var splashes                           # RainSplashes: single rain drops near the player, by ground
var cave                                # CaveSounds: reverb, muffling and drips under rock
var dig                                 # DigSounds: the sound of what is dug (dug(center, radius, listener))
var _sphere: PhysicsShapeQueryParameters3D


func setup(terrain: VoxelLodTerrain, flora, grass) -> void:
	_load_step_levels()
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
	flame = FlameScript.new()
	flame.name = "Flame"
	add_child(flame)
	flame.setup(self)
	breath = BreathScript.new()
	breath.name = "Breath"
	add_child(breath)
	breath.setup(self)
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
	inner = InnerVoiceScript.new()
	inner.name = "InnerVoice"
	add_child(inner)
	inner.setup(self)
	spear = SpearScript.new()
	spear.name = "Spear"
	add_child(spear)
	spear.setup(self)
	placed = PlacedScript.new()
	placed.name = "Placed"
	add_child(placed)
	placed.setup(self)
	treewind = TreeWindScript.new()
	treewind.name = "TreeWind"
	add_child(treewind)
	treewind.setup(self)
	harvestfx = HarvestFxScript.new()
	harvestfx.name = "HarvestFx"
	add_child(harvestfx)
	harvestfx.setup(self)
	workshop = WorkshopScript.new()
	workshop.name = "Workshop"
	add_child(workshop)
	workshop.setup(self)
	interior = InteriorScript.new()
	interior.name = "Interior"
	add_child(interior)
	interior.setup(self)
	gear = GearScript.new()
	gear.name = "Gear"
	add_child(gear)
	gear.setup(self)
	stance = StanceScript.new()
	stance.name = "Stance"
	add_child(stance)
	stance.setup(self)
	creatures = CreatureScript.new()
	creatures.name = "Creatures"
	add_child(creatures)
	creatures.setup(self)
	insects = InsectScript.new()
	insects.name = "Insects"
	add_child(insects)
	insects.setup(self)
	stepfx = StepFxScript.new()
	stepfx.name = "StepFx"
	add_child(stepfx)
	stepfx.setup(self)
	slots = SlotSoundsScript.new()
	slots.name = "SlotSounds"
	add_child(slots)
	slots.setup(self)
	ambience = AmbienceSlotsScript.new()
	ambience.name = "AmbienceSlots"
	add_child(ambience)
	ambience.setup(self)
	wet = WetSoundsScript.new()
	wet.name = "WetSounds"
	add_child(wet)
	wet.setup(self)
	landing = LandingScript.new()
	landing.name = "Landing"
	add_child(landing)
	landing.setup(self)
	emitters = EmitterScript.new()
	emitters.name = "Emitters"
	add_child(emitters)
	emitters.setup(self)
	ui = UiScript.new()
	ui.name = "Ui"
	add_child(ui)
	ui.setup(self)
	swim = SwimScript.new()
	swim.name = "Swim"
	add_child(swim)
	swim.setup(self)
	splashes = SplashScript.new()
	splashes.name = "Splashes"
	add_child(splashes)
	splashes.setup(self)
	ice = IceScript.new()
	ice.name = "Ice"
	add_child(ice)
	ice.setup(self)
	windhole = WindHoleScript.new()
	windhole.name = "WindHole"
	add_child(windhole)
	windhole.setup(self)
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
	_build_warm_list()

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
var _slow_acc: float = 0.0
var _slow_skip: bool = false


func update(delta: float, body: CharacterBody3D, flying: bool, underwater: bool) -> void:
	_count_left -= delta

	if _count_left <= 0.0:
		_count_left = 0.25
		_voice_count = voices_playing()
		voices_peak = maxi(voices_peak, _voice_count)

		if _voice_count > voice_cap:
			_shed(body, _voice_count - voice_cap)

	if track_peaks:
		_track_peaks()

	# TD (2026-10-21, 1050-class pass): at Low the slow-moving sound pieces (ambience, weather, timers, ramps)
	# run every second frame with the time of both frames; the ones that answer to the player at once
	# (steps, swimming, breath, spear, dig, fire, torch, falls) still run every frame.
	var slow_delta: float = delta
	var slow_now: bool = true

	if tier == 0:
		_slow_acc += delta
		_slow_skip = not _slow_skip
		slow_now = not _slow_skip
		slow_delta = _slow_acc

		if slow_now:
			_slow_acc = 0.0

	if slow_now:
		ambient.update(slow_delta, body, flying)
		ambience.update(slow_delta, body)
		insects.update(slow_delta, underwater)
		weather.update(slow_delta, body, underwater)

	water.update(delta, body, underwater)

	splashes.update(delta, body, underwater)

	if slow_now:
		ice.update(slow_delta, body, underwater)
		windhole.update(slow_delta, underwater)

	dig.update(delta)

	if slow_now:
		cave.update(slow_delta, body, flying)
		town.update(slow_delta, body)

	swim.update(delta, body, flying, underwater)

	if slow_now:
		creatures.update(slow_delta)
		interior.update(slow_delta)

	spear.update(delta)
	fire.update(delta, body)

	if slow_now:
		treewind.update(slow_delta, body)
		workshop.update(slow_delta, body)
		trees.update(slow_delta)

	breath.follow_body(delta, body, flying, swim.swimming)
	breath.update(delta, underwater)
	stance.update(delta)
	stepfx.update(delta)
	flame.update(delta, body)

	if slow_now:
		occlusion.update(slow_delta, body, flying)

	_warm_one(delta)
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
	_wind_filter.cutoff_hz *= 1.0 - SNOW_HUSH_WIND_CUT * weather.snow_hush

	if absf(weather.snow_hush - _hush_applied) > 0.02 or absf(breath.world_mute - _faint_applied) > 0.02 or (breath.world_mute == 0.0 and _faint_applied != 0.0):
		_hush_applied = weather.snow_hush
		_faint_applied = breath.world_mute
		_apply_buses()

	if _grass != null:
		_grass.set_wind(strength)

	# A landing after a short fall sounds like a heavy step.
	if flying or not body.is_on_floor():
		if _air_time == 0.0:
			_air_top = body.global_position.y

		_air_top = maxf(_air_top, body.global_position.y)
		_air_time += delta
	else:
		if _air_time > 0.45:
			landing.land(body, _air_top - body.global_position.y)

		_air_time = 0.0


# Forget the height the body fell from (arrival at a new place): the next landing is measured from here.
func forget_fall(body: CharacterBody3D) -> void:
	_air_top = body.global_position.y
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
	emitters.set_tier(tier)


# Over the voice cap (loops and steps always play, so optional sounds can pile up): cuts the one-shot
# 3D sounds with the lowest priority, `count` of them. Order: far ambience first (Nature, Weather and
# Wind buses), then other world sounds, farthest and quietest first; the player's own actions (any
# Foley sound within OWN_M of the player: gear, hits, harvest, tools) go last. Danger cues (a threat
# call, the crow alarm) carry the meta "keep" and are never cut. The player's own footsteps, breath,
# heartbeat and the interface are not in the group world_sounds, so they are never candidates.
const OWN_M := 4.0
const AMBIENT_BUSES := ["Nature", "Weather", "Wind"]

func _shed(body: CharacterBody3D, count: int) -> void:
	var candidates: Array = []

	for player in get_tree().get_nodes_in_group("world_sounds"):
		if not is_instance_valid(player) or not player.playing or player.has_meta("keep"):
			continue

		if player.stream is AudioStreamOggVorbis and player.stream.loop:
			continue

		candidates.append([_shed_rank(player, body), player])

	candidates.sort_custom(func(a, b): return a[0] > b[0])

	for n in range(mini(count, candidates.size())):
		candidates[n][1].stop()
		candidates[n][1].queue_free()
		shed_count += 1


# Higher rank is cut sooner.
func _shed_rank(player: AudioStreamPlayer3D, body: CharacterBody3D) -> float:
	var distance: float = player.global_position.distance_to(body.global_position)
	var rank: float = distance - player.volume_db * 4.0              # far and quiet sorts last
	var bus: String = AirBands.parent_of(String(player.bus))

	if bus in AMBIENT_BUSES:
		rank += 1000.0
	elif bus == "Foley" and distance < OWN_M:
		rank -= 1000.0

	return rank


# Headless check (--voice-priority): fills the stage with far ambience and the player's own sounds,
# lowers the cap under what is playing and reports what survived the shed.
func test_priority(body: CharacterBody3D) -> String:
	var made: Array = []

	for k in range(10):
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.stream = AudioStreamGenerator.new()
		player.bus = "Nature" if k < 6 else "Foley"
		var own: bool = k >= 8
		add_child(player)
		player.add_to_group("world_sounds")
		player.global_position = body.global_position + Vector3(1.5 if own else 400.0 + k, 0.0, 0.0)
		player.volume_db = -20.0 if own else -6.0                       # the own sounds are the quiet ones
		player.play()
		made.append(player)

	var before: int = shed_count
	_shed(body, 6)
	var alive_own: int = 0
	var alive_ambient: int = 0

	for k in range(made.size()):
		if is_instance_valid(made[k]) and not made[k].is_queued_for_deletion():
			if k >= 8:
				alive_own += 1
			elif k < 6:
				alive_ambient += 1

	for player in made:
		if is_instance_valid(player):
			player.queue_free()

	return "shed %d of 10, own kept %d of 2, ambience left %d of 6" % [shed_count - before, alive_own, alive_ambient]


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

	return count + weather.voices_playing() + swim.voices_playing() + interior.voices_playing() + treewind.voices_playing() + workshop.loops_playing + insects.voices_playing()


# True while another optional sound (a call, a flush) fits in the voice budget.
func has_room() -> bool:
	return _voice_count < voice_cap


# The loudest sounds playing now, for the "what is that sound" Debug details list: one line per sound with
# its file name (recorded or generated), distance (flat sounds say "here") and level in dB at the source.
# Sorted loudest first (level minus 6 dB per doubling of distance from 2 m), at most `limit` lines.
func heard_text(body: CharacterBody3D, limit: int = 8) -> String:
	var rows: Array = []

	for player in [_wind_low, _wind_gust]:
		if player.playing and player.stream != null:
			rows.append([player.stream.resource_path.get_file().get_basename(), -1.0, player.volume_db, tag(player.stream)])

	for entry in weather.active_loops():
		rows.append([entry[0], -1.0, entry[1], "loop"])

	for player in get_tree().get_nodes_in_group("world_sounds"):
		if not is_instance_valid(player) or not player.playing or player.stream == null:
			continue

		var distance: float = player.global_position.distance_to(body.global_position)
		rows.append([player.stream.resource_path.get_file().get_basename(), distance, player.volume_db, tag(player.stream)])

	for row in rows:
		var d: float = maxf(float(row[1]), 2.0) if float(row[1]) >= 0.0 else 2.0
		row.append(float(row[2]) - 6.0 * log(d / 2.0) / log(2.0))

	rows.sort_custom(func(a, b): return a[4] > b[4])
	var lines: PackedStringArray = []

	for n in range(mini(limit, rows.size())):
		var row: Array = rows[n]
		lines.append("  %s %s %.0f dB %s" % [row[0], "here" if float(row[1]) < 0.0 else "%.0f m" % float(row[1]), float(row[2]), row[3]])

	return "sounds heard (%d):\n%s" % [rows.size(), "\n".join(lines)]


func wind_text() -> String:
	return "wind %.2f (world %.2f, exposure %+.2f: -1 valley, +1 ridge)" % [wind_strength, weather.world_wind, exposure]


func budget_text() -> String:
	return "sounds %d/%d playing (peak %d), %.1f/%d MB loaded (%s)" % [_voice_count, voice_cap, voices_peak, float(loaded_bytes) / 1048576.0, int(preset["memory_mb"]), Presets.NAMES[tier]]


# Hook for the building system: the built floor the player stands on ("plank", "slab", "carpet", "thatch",
# "path"), "" back on natural ground. Or set `floor_under` to a Callable(feet) -> name for a per-step query.
func set_floor(sound_name: String) -> void:
	floor_surface = sound_name if FLOOR_SURFACES.has(sound_name) else ""


# One footfall at gait 0 walk, 1 jog, 2 run; `boost_db` makes it louder (landings).
# `foot` is "left" or "right" (recorded sets have one of each).
func footstep(body: CharacterBody3D, gait: int, boost_db: float = 0.0, foot: String = "left") -> void:
	boost_db += stance.step_db()                                  # crouched steps are softer, and the gear with them
	var feet: Vector3 = body.global_position - Vector3(0.0, FEET_M, 0.0)
	var water_here: float = _flora.water_surface_at(feet.x, feet.z)

	if feet.y < 0.0 and (is_nan(water_here) or water_here < 0.0):
		water_here = 0.0                                              # the sea

	var depth: float = water_here - feet.y if not is_nan(water_here) else -1.0

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

	if depth > DAMP_M and ice.walkable():
		surface = "ice"                                          # a frozen pond bears the step
		thick = 0.0
	elif depth > WATER_STEP_M:
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

	# A built floor under the soles replaces the ground (not in water).
	var built: String = floor_surface

	if built == "" and floor_under.is_valid():
		built = str(floor_under.call(feet))

	if built != "" and FLOOR_SURFACES.has(built) and depth <= DAMP_M:
		surface = built
		tune = [0.0, 1.0]
		thick = 0.0

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
	var sound_name: String = "step_" + surface

	if _variants(sound_name).is_empty() and _variants(sound_name + "_" + foot).is_empty():
		sound_name = "step_grass"

	var recorded: bool = _recorded.has(sound_name + "_" + foot) or _recorded.has(sound_name)
	var pitch: float = float(gait_pitch[gait]) * _rng.randf_range(0.96, 1.04) * tune[1]
	last_step = "%s (soil %d, water %.2f m, %s)" % [surface, soil, depth, sound_name + "_" + foot if recorded else sound_name + " generated"]
	var step_db: float = step_level_db(surface, gait) + float(tune[0]) + boost_db + SNOW_HUSH_STEP_DB * _hush_applied + _rng.randf_range(-1.5, 1.0)
	_play(sound_name, step_db, pitch, foot)
	steps_played[surface] = int(steps_played.get(surface, 0)) + 1
	gear.step(gait, boost_db, surface)
	stepfx.step(gait, step_db, surface, 0.0 if surface == "ice" else depth)

	if wet.stage_now > 0:
		wet.step(body.global_position)

	if surface == "ice":
		ice.step(feet, gait, boost_db)

	# Wet ground: a puddle splash joins most steps on grass, stone, gravel and sand.
	if weather != null and weather.ground_wet >= PUDDLE_WET and surface in PUDDLE_SURFACES and _rng.randf() < weather.ground_wet * 0.7:
		puddles_played += 1
		_play("step_water", puddle_db + float(gait_db[gait]) - float(gait_db[0]) + _rng.randf_range(-2.0, 1.0), _rng.randf_range(0.95, 1.15) * float(gait_pitch[gait]), foot)

	# The recorded grass, tall grass and bush steps carry the swish of the blades themselves.


# Reads data/sound/step_levels.json over the built-in numbers; a missing or broken file leaves them as they were.
func _load_step_levels(path: String = STEP_LEVELS_PATH) -> void:
	if not FileAccess.file_exists(path):
		return

	var data = JSON.parse_string(FileAccess.get_file_as_string(path))

	if not data is Dictionary:
		push_warning("step_levels.json is not a table; using the built-in step levels")
		return

	for key in ["surface_db", "floor_db"]:
		if data.get(key) is Dictionary:
			var target: Dictionary = surface_db if key == "surface_db" else floor_db

			for sound_name in data[key]:
				target[str(sound_name)] = float(data[key][sound_name])

	if data.get("gait_db") is Array and data["gait_db"].size() == 3:
		gait_db = data["gait_db"].map(func(v): return float(v))

	if data.get("gait_pitch") is Array and data["gait_pitch"].size() == 3:
		gait_pitch = data["gait_pitch"].map(func(v): return float(v))

	if data.get("surface_gait_db") is Dictionary:
		surface_gait_db = data["surface_gait_db"].duplicate()

	if data.has("puddle_db"):
		puddle_db = float(data["puddle_db"])

	step_levels_source = "data/sound/step_levels.json"


# The level of one step (before boosts, tune and randomness): surface or built floor plus gait plus the table's extra.
func step_level_db(surface_kind: String, gait: int) -> float:
	var g: int = clampi(gait, 0, 2)
	var base: float = float(surface_db.get(surface_kind, floor_db.get(surface_kind, -9.0)))
	var extra: Array = surface_gait_db.get(surface_kind, [0.0, 0.0, 0.0])
	return base + float(gait_db[g]) + float(extra[g] if extra.size() == 3 else 0.0)


# Esc > Settings mixer: steps one group (wind, nature, steps) through 100, 75, 50, 25 % and off.
# Returns the new share. Saved for the next run.
func mix_step(group: String) -> float:
	mix_index[group] = (int(mix_index[group]) + 1) % VOLUME_STEPS.size()
	_apply_mix(group)
	_save_settings()
	return float(VOLUME_STEPS[int(mix_index[group])])


# Headless loudness table (job 67, --mix-levels): the highest peak seen on each bus since tracking began.
const MIX_BUSES := ["Master", "Wind", "Foley", "Nature", "Weather", "Interface", "Body"]
var track_peaks: bool = false
var bus_peaks: Dictionary = {}          # bus -> highest peak in dB
var bus_sums: Dictionary = {}           # bus -> [sum of peak dB while above -60, samples]


func _track_peaks() -> void:
	for bus_name in MIX_BUSES:
		var index: int = AudioServer.get_bus_index(bus_name)

		if index < 0:
			continue

		var peak: float = maxf(AudioServer.get_bus_peak_volume_left_db(index, 0), AudioServer.get_bus_peak_volume_right_db(index, 0))
		bus_peaks[bus_name] = maxf(float(bus_peaks.get(bus_name, -200.0)), peak)

		if peak > -60.0:
			var sums: Array = bus_sums.get(bus_name, [0.0, 0])
			bus_sums[bus_name] = [float(sums[0]) + peak, int(sums[1]) + 1]


# F3 meters (job 86): one line per bus, a bar from -60 to 0 dB, the peak now and the highest in the last HOLD_SEC. Built only when
# Debug details is shown (terrain_client._debug_text), so it costs nothing otherwise: one bus peak read per bus per call.
const METER_BUSES := ["Master", "Wind", "Foley", "Nature", "Weather", "Interface", "Body", "World"]
const METER_CELLS := 20
const HOLD_SEC := 3.0
var meters_calls: int = 0
var _meter_hold: Dictionary = {}        # bus -> [peak dB, msec when set]


func meters_text() -> String:
	meters_calls += 1
	var now: int = Time.get_ticks_msec()
	var lines: Array = ["sound meters (peak dB, bar -60..0, hold %d s):" % int(HOLD_SEC)]

	for bus_name in METER_BUSES:
		var index: int = AudioServer.get_bus_index(bus_name)

		if index < 0:
			continue

		var peak: float = maxf(AudioServer.get_bus_peak_volume_left_db(index, 0), AudioServer.get_bus_peak_volume_right_db(index, 0))
		var held: Array = _meter_hold.get(bus_name, [-200.0, now])

		if peak >= float(held[0]) or float(now - int(held[1])) > HOLD_SEC * 1000.0:
			held = [peak, now]

		_meter_hold[bus_name] = held
		var filled: int = clampi(int(round((clampf(peak, -60.0, 0.0) + 60.0) / 60.0 * METER_CELLS)), 0, METER_CELLS)
		lines.append("  %-9s [%s%s] %6.1f  hold %6.1f%s" % [bus_name, "#".repeat(filled), ".".repeat(METER_CELLS - filled), maxf(peak, -99.9), maxf(float(held[0]), -99.9), "  CLIPPING" if peak > -0.5 else ""])

	lines.append("  audio output latency %.0f ms, mix rate %d Hz" % [AudioServer.get_output_latency() * 1000.0, int(AudioServer.get_mix_rate())])
	return "\n".join(lines)


func mix_table() -> String:
	var parts: Array = []

	for bus_name in MIX_BUSES:
		var sums: Array = bus_sums.get(bus_name, [0.0, 0])
		var mean: float = float(sums[0]) / float(sums[1]) if int(sums[1]) > 0 else -99.0
		parts.append("%s peak %.1f mean %.1f" % [bus_name, float(bus_peaks.get(bus_name, -99.0)), mean])

	return "; ".join(parts)


func _apply_mix(_group: String = "") -> void:
	_apply_buses()


# Esc > Settings sliders (build 151): master, effects (footsteps, tools, items, fire, town), ambient
# (wind, nature, weather) and interface, each 0 to 1, saved in the same file as the mixer steps.
# A bus plays at its slider times its mixer step (wind, nature, steps) and Master also times the
# old stepped volume. 0 mutes the bus.
func set_level(sound_name: String, value: float) -> void:
	if not levels.has(sound_name):
		return

	levels[sound_name] = clampf(value, 0.0, 1.0)
	_apply_buses()
	_save_settings()


# Snow hush (job 51): at full hush wind is 3 dB and nature 4 dB quieter, the wind filter closes 30 percent and
# steps lose 3 dB (snow steps are already the soft crunch). Eases with `weather.snow_hush` (4 s).
const SNOW_HUSH_BUS_DB := {"Wind": -3.0, "Nature": -4.0}
const SNOW_HUSH_STEP_DB := -3.0
const SNOW_HUSH_WIND_CUT := 0.3
var _hush_applied: float = 0.0

# A faint (breath.world_mute 0..1): these buses fade to silence, the "Body" bus (heartbeat) stays.
const FAINT_BUSES := ["Wind", "Foley", "Nature", "Weather", "Interface"]
const FAINT_BUS_DB := -60.0
var _faint_applied: float = 0.0


func _apply_buses() -> void:
	var shares: Dictionary = {
		"Master": float(levels["master"]) * float(VOLUME_STEPS[volume_index]),
		"Foley": float(levels["effects"]) * float(VOLUME_STEPS[int(mix_index["steps"])]),
		"Wind": float(levels["ambient"]) * float(VOLUME_STEPS[int(mix_index["wind"])]),
		"Nature": float(levels["ambient"]) * float(VOLUME_STEPS[int(mix_index["nature"])]),
		"Weather": float(levels["ambient"]) * float(VOLUME_STEPS[int(mix_index["nature"])]),
		"Interface": float(levels["interface"]),
		"Body": float(levels["effects"]) * float(VOLUME_STEPS[int(mix_index["steps"])]),
	}

	for bus_name in shares:
		var index: int = AudioServer.get_bus_index(bus_name)

		if index >= 0:
			var share: float = shares[bus_name]
			AudioServer.set_bus_mute(index, share <= 0.001)
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(share, 0.001)) + float(SNOW_HUSH_BUS_DB.get(bus_name, 0.0)) * _hush_applied + (FAINT_BUS_DB if bus_name in FAINT_BUSES else 0.0) * _faint_applied)


# Sound files are loaded the first time a layer needs them, which cost 5 to 20 ms frames (first rain, first
# creak). After the first WARM_START_SEC the common ones are loaded one per frame instead.
const WARM_START_SEC := 3.0
var _warm: Array = []                   # [module, name] still to load
var _warm_wait: float = 0.0


func _build_warm_list() -> void:
	for event in ambient.EVENTS:
		_warm.append([ambient, str(event["name"])])

	for kind in water.KINDS:
		_warm.append([water, str(water.KINDS[kind]["file"])])

	for tool in hits.TOOLS:
		for material in hits.MATERIALS:
			_warm.append([hits, "hit_%s_%s" % [tool, material]])

	for sound_name in ["fire_small", "fire_large", "fire_rain", "fire_light", "fire_out"]:
		_warm.append([fire, sound_name])

	for sound_name in ["flame_torch", "flame_lantern"]:
		_warm.append([flame, sound_name])

	for sound_name in ["tree_creak", "tree_leaves", "tree_crash", "stump_chips"]:
		_warm.append([trees, sound_name])

	for sound_name in ["item_pickup", "item_drop", "inv_open", "inv_close", "item_swap", "craft_done"]:
		_warm.append([itemfx, sound_name])

	for sound_name in ["breath_in", "breath_out", "breath_gasp", "heartbeat"]:
		_warm.append([breath, sound_name])


func _warm_one(delta: float) -> void:
	_warm_wait += delta

	if _warm_wait < WARM_START_SEC or _warm.is_empty():
		return

	var entry: Array = _warm.pop_front()
	entry[0]._variants(entry[1])


func _load_settings() -> void:
	var file: ConfigFile = ConfigFile.new()

	if file.load(SETTINGS_PATH) == OK:
		for group in MIX_GROUPS:
			mix_index[group] = clampi(int(file.get_value("mixer", group, 0)), 0, VOLUME_STEPS.size() - 1)

		for sound_name in levels:
			levels[sound_name] = clampf(float(file.get_value("levels", sound_name, 1.0)), 0.0, 1.0)

	_apply_buses()


func _save_settings() -> void:
	var file: ConfigFile = ConfigFile.new()

	for group in MIX_GROUPS:
		file.set_value("mixer", group, int(mix_index[group]))

	for sound_name in levels:
		file.set_value("levels", sound_name, float(levels[sound_name]))

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


# What the rain falls on under the player, for the rain loops: "snow" when snow lies, "stone" on rock, a
# built stone, plank or path floor, "mud" on mud and soaked loose soil, "litter" on leaf litter, else "soft".
# The ground a rain drop near the player lands on, for rain_splashes.gd: stone, gravel, grass, dirt, sand, mud or litter;
# "" while snow lies (no drops).
func splash_ground(body: CharacterBody3D) -> String:
	if weather.ground_snow >= SNOW_COVER:
		return ""

	if floor_surface in ["slab", "plank", "path"]:
		return "stone"

	var feet: Vector3 = body.global_position - Vector3(0.0, FEET_M, 0.0)
	var soil: int = _ground_under(feet)

	if soil < 0 or soil >= Layout.MATERIAL_ROCK:
		return "stone"

	var surface_kind: String = str(SOIL_SURFACE.get(soil, "dirt"))

	if surface_kind == "mud" or (surface_kind in ["dirt", "leaves"] and weather.ground_wet >= RAIN_SOAK):
		return "mud"

	if surface_kind == "dirt" and _grass != null and _grass.grass_at(feet.x, feet.z, soil).x > 0.3:
		return "grass"

	return {"leaves": "litter", "stone": "stone", "sand": "sand", "gravel": "gravel"}.get(surface_kind, "dirt")


func rain_ground(body: CharacterBody3D) -> String:
	if weather.ground_snow >= SNOW_COVER:
		return "snow"

	if floor_surface in ["slab", "plank", "path"]:
		return "stone"

	var soil: int = _ground_under(body.global_position - Vector3(0.0, FEET_M, 0.0))

	if soil < 0 or soil >= Layout.MATERIAL_ROCK:
		return "stone"

	var ground: String = str(SOIL_SURFACE.get(soil, "dirt"))

	if ground == "stone":
		return "stone"

	if ground == "mud" or (ground in ["dirt", "leaves"] and weather.ground_wet >= RAIN_SOAK):
		return "mud"

	if ground == "leaves":
		return "litter"

	return "soft"


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
	var surface_kind: float = water_level_at(point)
	var ground: float = ground_below.call(point) if ground_below.is_valid() else NAN
	var depth: float = WaterVolume.depth(surface_kind, ground)
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
func _play(sound_name: String, volume_db: float, pitch: float, foot: String = "") -> void:
	var list: Array = _variants(sound_name + "_" + foot) if foot != "" else []

	if list.is_empty():
		list = _variants(sound_name)

	if list.is_empty():
		return

	# A different variant from last time, so steps never repeat back to back.
	var pick: int = _rng.randi_range(0, list.size() - 1)

	if list.size() > 1 and pick == int(_last_variant.get(sound_name, -1)):
		pick = (pick + 1) % list.size()

	_last_variant[sound_name] = pick
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = list[pick]
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	voice.play()


func _player(bus: String, sound_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus
	var list: Array = _variants(sound_name)
	player.stream = list[0] if not list.is_empty() else null
	add_child(player)
	return player


# Every variant of a sound: name.ogg, or name_0.ogg, name_1.ogg ... Real
# recordings in assets/audio/recorded/ win over the generated ones in
# assets/audio/ (assets/audio/README.md says where to get them).
func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var list: Array = _find(RECORDED_DIR, sound_name)

	if list.is_empty():
		list = _find(AUDIO_DIR, sound_name)

		if list.is_empty() and sound_name.begins_with("step_"):
			list = _find(FLOORS_DIR, sound_name)
	else:
		_recorded[sound_name] = true

	_streams[sound_name] = list
	return list


# "recorded" or "generated" for a loaded sound, for the last-sound line.
static func tag(stream: Resource) -> String:
	return "recorded" if stream != null and stream.resource_path.contains("/recorded/") else "generated"


static func _find(folder: String, sound_name: String) -> Array:
	var single: AudioStream = _load(folder, sound_name)

	if single != null:
		return [single]

	var list: Array = []

	while true:
		var stream: AudioStream = _load(folder, "%s_%d" % [sound_name, list.size()])

		if stream == null:
			break

		list.append(stream)

	return list


# The imported sound, or else straight from the file (headless runs have no imports).
# Takes name.ogg, or name.wav for a recording dropped in as it came.
# Memory audit (--load-all-sounds): loads one file the way a layer would, counting it against the cap.
func load_for_audit(folder: String, sound_name: String) -> AudioStream:
	return _load(folder, sound_name)


func audit_text() -> String:
	return "%.1f MB read from disk, %d refused (cap %d MB at %s)" % [float(loaded_bytes) / 1048576.0, refused_loads, int(preset["memory_mb"]), Presets.NAMES[tier]]


# Called with a text when a first load of a sound file took long (the crash report names it; set by the client). Dave 2026-10-21: audit of
# anything that could block the main thread: every sound is a prepared file read from disk, nothing is synthesized while playing.
static var slow_load: Callable = Callable()
const SLOW_LOAD_MS := 25


static func _load(folder: String, sound_name: String) -> AudioStream:
	var started: int = Time.get_ticks_msec()
	var stream: AudioStream = _load_file(folder, sound_name)
	var took: int = Time.get_ticks_msec() - started

	if took >= SLOW_LOAD_MS and slow_load.is_valid():
		slow_load.call("SLOW AUDIO LOAD: %s%s took %d ms" % [folder, sound_name, took])

	return stream


static func _load_file(folder: String, sound_name: String) -> AudioStream:
	for extension in ["ogg", "wav"]:
		var path: String = folder + sound_name + "." + extension

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
			if extension == "ogg":
				return AudioStreamOggVorbis.load_from_file(path)
			return AudioStreamWAV.load_from_file(path)

	return null


static func _make_bus(sound_name: String) -> int:
	var index: int = AudioServer.get_bus_index(sound_name)

	if index >= 0:
		return index

	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, sound_name)
	AudioServer.set_bus_send(index, "Master")
	return index


# The buses and filters live in the audio server, which outlasts this scene.
func _exit_tree() -> void:
	for player in [_wind_low, _wind_gust] + _voices:
		player.stop()
		player.stream = null

	_streams.clear()

	AirBands.remove_all()

	for sound_name in ["Wind", "Foley", "Nature", "Weather", "World"]:
		var index: int = AudioServer.get_bus_index(sound_name)

		if index >= 0:
			AudioServer.remove_bus(index)

	for n in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		if AudioServer.get_bus_effect(0, n) == _muffle:
			AudioServer.remove_bus_effect(0, n)
