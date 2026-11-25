extends Node

# Creature calls (client only): the voices of the wild animals, as hooks for a later creature
# system. Nothing here knows an animal; a caller says which kind called, where, and in what mood.
#
#   sound.creatures.call_at("wolf", position, "idle")     one call at a place
#   sound.creatures.call_in_zone("forest", "idle")        a call from a random kind that lives in that
#                                                         zone, at a distance that suits it
#   sound.creatures.kinds_in(zone)                        the kinds that live in a zone
#   sound.creatures.wild = true                           far, natural calls by zone, hour and weather
#                                                         (off by default: no animals exist yet)
#
# Kinds: deer, rabbit, fox, wolf, bear, and "bird" (a songbird by day, crow alarm when alert or
# threat, played by ambient_life.gd). Moods: "idle" (a normal call), "alert" (it noticed something),
# "threat" (angry or hurt: a danger cue, always allowed even when the voice budget is full), "warn" (the low warning before an attack:
# the kind's "warn" call, else its "alert" one, allowed like a threat so a warning is never lost to a full budget).
# Sounds: generated in assets/audio/creatures/ (make_creatures.py); recordings in
# assets/audio/recorded/creatures/ win. Names: deer_grunt, deer_snort, rabbit_thump, rabbit_squeak,
# fox_bark, fox_scream, wolf_howl, wolf_growl, bear_growl, bear_roar, moose_grunt/snort/bellow, horse_snort/whinny, duck_quack, goblin_chitter,
# goblin_hiss (_N variants).

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/creatures/"
const RECORDED_DIR := "res://assets/audio/recorded/creatures/"

# calls: mood -> sound. db at the source, dist: how far a natural call sounds from the player,
# reach: furthest it is played at all, unit: attenuation size (bigger carries further),
# zones: weight of each zone the kind lives in, hours: when it calls by itself (from, to; wraps midnight),
# every: seconds between its natural calls, cutoff: far-distance muffling (Hz).
const KINDS := {
	"deer": {"calls": {"idle": "deer_grunt", "alert": "deer_snort", "threat": "deer_snort"}, "db": -2.0, "dist": [25.0, 110.0], "reach": 260.0, "unit": 10.0, "near_max": 4.0,
		"zones": {"meadow": 1.0, "forest": 0.6, "highland": 0.2, "water": 0.3}, "hours": [4.0, 22.0], "every": [160.0, 400.0], "cutoff": 7000.0},
	# deer db -2 (was -8, 23 Nov 2026 level pass, assets/audio/level_pass.py): a deer's alarm snort at 40 m was 9 dB under the winter forest bed; a real one carries
	# 100 m and more. Its unit stays 10, so rain and gales still mask it like a mid-sized sound (outdoor_air.gd small_share); near_max keeps its close-in
	# ceiling where it was (4 dB: the snort clip peaks at -7 dBFS, not -14).
	"rabbit": {"calls": {"idle": "rabbit_thump", "alert": "rabbit_thump", "threat": "rabbit_squeak"}, "db": -14.0, "dist": [6.0, 25.0], "reach": 45.0, "unit": 3.0,
		"zones": {"meadow": 1.0, "forest": 0.3}, "hours": [5.0, 21.0], "every": [300.0, 700.0], "cutoff": 6000.0},
	"fox": {"calls": {"idle": "fox_bark", "alert": "fox_bark", "threat": "fox_scream"}, "db": -8.0, "dist": [40.0, 170.0], "reach": 320.0, "unit": 12.0,
		"zones": {"forest": 1.0, "meadow": 0.6, "highland": 0.3}, "hours": [20.0, 5.0], "every": [200.0, 500.0], "cutoff": 8000.0, "seasons": {"winter": 1.3, "autumn": 1.0, "spring": 1.0, "summer": 0.8}},
	"wolf": {"calls": {"idle": "wolf_howl", "alert": "wolf_growl", "threat": "wolf_growl"}, "db": -5.0, "dist": [150.0, 520.0], "reach": 950.0, "unit": 40.0,
		"zones": {"highland": 1.0, "forest": 0.6, "meadow": 0.2}, "hours": [21.0, 5.0], "every": [240.0, 600.0], "cutoff": 6000.0, "seasons": {"winter": 1.6, "autumn": 1.0, "spring": 0.7, "summer": 0.4}},
	"moose": {"calls": {"idle": "moose_grunt", "alert": "moose_snort", "threat": "moose_bellow"}, "db": -4.0, "dist": [30.0, 120.0], "reach": 300.0, "unit": 14.0,
		"zones": {"forest": 0.8, "water": 0.8}, "hours": [5.0, 22.0], "every": [500.0, 1000.0], "cutoff": 6000.0},
	"horse": {"calls": {"idle": "horse_snort", "alert": "horse_snort", "threat": "horse_whinny"}, "db": -6.0, "dist": [20.0, 90.0], "reach": 220.0, "unit": 10.0,
		"zones": {"meadow": 1.0}, "hours": [5.0, 21.0], "every": [500.0, 1100.0], "cutoff": 7000.0},
	"duck": {"calls": {"idle": "duck_quack", "alert": "duck_quack", "threat": "duck_quack"}, "db": -10.0, "dist": [10.0, 50.0], "reach": 120.0, "unit": 6.0,
		"zones": {"water": 1.0}, "hours": [5.0, 21.0], "every": [300.0, 700.0], "cutoff": 7000.0},
	"goblin": {"calls": {"idle": "goblin_chitter", "alert": "goblin_chitter", "threat": "goblin_hiss"}, "db": -9.0, "dist": [10.0, 40.0], "reach": 90.0, "unit": 6.0,
		"zones": {}, "hours": [0.0, 24.0], "every": [600.0, 1200.0], "cutoff": 7000.0},   # camp goblins at a weapon in hand (npc_view.gd goblin_called, Dave 20 Nov 2026): never a natural call
	# Bears are near silent (Dave 25 Nov 2026: "the bear roaring constantly in the woods is unrealistic"; NPS, bear.org "Harmless Bluster",
	# NH Fish and Game "Bear talk": a bear that is not bothered makes no calls, a nervous one huffs, blows and pops its jaws, a roar is a fight):
	# no natural calls in the woods (zones empty, as the camp goblins), and mood_for below.
	"bear": {"calls": {"idle": "bear_growl", "alert": "bear_growl", "threat": "bear_roar"}, "db": -4.0, "dist": [30.0, 130.0], "reach": 320.0, "unit": 15.0,
		"zones": {}, "hours": [6.0, 20.0], "every": [420.0, 900.0], "cutoff": 5000.0},
}
# Kinds with no clips of their own that sound like one that has (stand-ins until their own recordings): an American black bear growls
# like a bear, an elk calls like a moose. Without these their warnings and charges were silent. The big cats, the hyena and the lynx growl
# and roar like the bear; the boar and warthog grunt and snort like the moose; the rhino, buffalo, elephant and mammoth snort and bellow like
# it (Dave 23 Nov 2026: animals growl before attacking; coordinator's ruling: stand-ins until Dave's recordings, listed in docs/SOUND_MAP.md).
const CALL_AS := {"black_bear": "bear", "elk": "moose", "lion": "bear", "tiger": "bear", "leopard": "bear", "puma": "bear", "lynx": "bear",
	"hyena": "bear", "boar": "moose", "warthog": "moose", "rhino": "moose", "buffalo": "moose", "elephant": "moose", "mammoth": "moose"}
# Close by (Godot caps a voice's volume_db plus its distance gain at max_db, default 3): with 3 a wolf growl (-5 dB, unit 40 m) was
# equally loud anywhere within 16 m and a bear roar within 7 m, so near and far could not be told apart. A call may now rise
# NEAR_RISE_DB over its own level (the level stops rising at a quarter of its unit size: a wolf 10 m, a bear 4 m), never past
# NEAR_MAX_DB (the clips peak near -14 dBFS, so -5 dBFS at most).
# Which call an animal's drawn state gives (animal_view state_changed: 2 flee, 3 alert, 7 a wolf's attack, 10 warn, 11 charge, 16 the jaw-pop,
# 25 a close blow, 26 a kick); "" is silent. docs/design/ANIMAL_SCENARIOS.md gap 4 (research: flight is silent; the alarm call is the
# species' own; cats hiss and growl, black bears huff and pop their jaws, neither roars):
# - every flight is silent;
# - a look-up (3) calls only for kinds with an alarm call of their own (deer snort, rabbit thump, fox bark, horse snort, duck quack, wolf),
#   and animal_view plays it on an animal's first look only; a kind that borrows another's voice (CALL_AS) looks up in silence;
# - warnings by kind ("warn": never dropped by a full voice budget, Dave 23 Nov 2026 "growl before attacking"): the bears and the cats
#   growl low (the stand-in for a huff or a hiss), the boar and warthog snort, not bellow;
# - the black bear, lynx and puma never roar: their charge and blow are the low growl ("warn") too. The rest keep "threat".
const ALARM_KINDS := ["deer", "rabbit", "fox", "horse", "duck", "wolf", "goblin"]
const LOW_WARN := ["bear", "black_bear", "lion", "tiger", "leopard", "puma", "lynx", "boar", "warthog"]
const NEVER_ROARS := ["black_bear", "lynx", "puma"]


func mood_for(kind: String, state: int) -> String:
	if state == 2:
		return ""

	if state == 3:
		return "alert" if kind in ALARM_KINDS else ""

	if (state == 10 or state == 16) and kind in LOW_WARN:
		return "warn"

	if kind in NEVER_ROARS:
		return "warn"

	return "threat"


const NEAR_RISE_DB := 12.0
const NEAR_MAX_DB := 9.0
# A pack rushing in sends every wolf to attack in one row: threat calls skip the voice budget and are never shed, so at most
# THREAT_VOICES of them sound at once, and one kind's threat call at most every THREAT_EVERY_MS.
const THREAT_VOICES := 3
const THREAT_EVERY_MS := 400
const BIRD_IDLE := ["bird_whistle", "bird_feebee", "bird_trill", "bird_chirp"]

var tier: int = 2
var wild: bool = true                   # natural far calls on their own (Dave Q6: birds and small game plus wolf and bear); false silences them
var calls_played: Dictionary = {}       # kind -> count
var last: String = ""                   # kind, mood, file and distance for the HUD

var _stage                              # SoundStage (ambient weights, hour, weather, voice budget)
var _streams: Dictionary = {}
var _voices: Array = []
var _threat_until: Dictionary = {}      # kind -> ticks msec before which it calls no threat again
var _next: Dictionary = {}              # kind -> seconds until its next natural call
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


func set_tier(new_tier: int) -> void:
	tier = new_tier


# The kinds that live in a zone (forest, meadow, water, highland), commonest first.
func kinds_in(zone: String) -> Array:
	var found: Array = []

	for kind in KINDS:
		var weight: float = float(KINDS[kind]["zones"].get(zone, 0.0))

		if weight > 0.0:
			found.append([weight, kind])

	found.sort_custom(func(a, b): return a[0] > b[0])
	return found.map(func(entry): return entry[1])


# One call by `kind` at `at` in `mood`. False when nothing played (unknown kind, no sound,
# too far to be heard, or the voice budget is full and the call is not a threat).
func call_at(kind: String, at: Vector3, mood: String = "idle") -> bool:
	var listener: Vector3 = get_viewport().get_camera_3d().global_position if get_viewport().get_camera_3d() != null else Vector3.ZERO

	if kind == "bird":
		return _bird(at, mood)

	kind = str(CALL_AS.get(kind, kind))

	if not KINDS.has(kind):
		return false

	var info: Dictionary = KINDS[kind]
	var distance: float = listener.distance_to(at)

	if distance > float(info["reach"]):
		return false

	_prune()

	var danger: bool = mood == "threat" or mood == "warn"   # a danger cue: never lost to a full budget

	if not danger and (_voices.size() >= int(_stage.preset["creature_voices"]) or not _stage.has_room()):
		return false

	if danger:
		var now: int = Time.get_ticks_msec()
		var threats: int = _voices.filter(func(v) -> bool: return is_instance_valid(v) and v.has_meta("keep")).size()

		if threats >= THREAT_VOICES or now < int(_threat_until.get(kind, 0)):
			return false

		_threat_until[kind] = now + THREAT_EVERY_MS

	var sound_name: String = str(info["calls"].get(mood, info["calls"].get("alert", info["calls"]["idle"]) if mood == "warn" else info["calls"]["idle"]))
	var list: Array = _variants(sound_name)

	if list.is_empty():
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[pick]
	player.bus = "Nature"
	player.volume_db = float(info["db"]) + _rng.randf_range(-1.5, 1.0)
	player.pitch_scale = _rng.randf_range(0.95, 1.05)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = float(info["unit"])
	player.max_distance = float(info["reach"]) * 1.2
	player.attenuation_filter_cutoff_hz = float(info["cutoff"])
	player.max_db = minf(player.volume_db + NEAR_RISE_DB, float(info.get("near_max", NEAR_MAX_DB)))
	add_child(player)
	player.add_to_group("world_sounds")

	if danger:
		player.set_meta("keep", true)                            # a danger cue: never shed

	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	_voices.append(player)
	calls_played[kind] = int(calls_played.get(kind, 0)) + 1
	last = "%s %s %s_%d (%s) at %.0f m" % [kind, mood, sound_name, pick, SoundStage.tag(list[pick]), distance]
	return true


# A call from a random kind of the zone, at a distance that suits it, in a random direction.
func call_in_zone(zone: String, mood: String = "idle") -> bool:
	var kinds: Array = kinds_in(zone)

	if kinds.is_empty():
		return false

	var weights: Array = kinds.map(func(k): return float(KINDS[k]["zones"][zone]))
	var roll: float = _rng.randf() * weights.reduce(func(a, b): return a + b, 0.0)

	for n in range(kinds.size()):
		roll -= weights[n]

		if roll <= 0.0 or n == kinds.size() - 1:
			return call_nearby(kinds[n], mood)

	return false


# A call by `kind` somewhere around the player at the kind's natural distance.
func call_nearby(kind: String, mood: String = "idle", distance_m: float = -1.0) -> bool:
	if not KINDS.has(kind):
		return false

	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return false

	var range_m: Array = KINDS[kind]["dist"]
	var distance: float = distance_m if distance_m >= 0.0 else _rng.randf_range(float(range_m[0]), float(range_m[1]))
	var angle: float = _rng.randf() * TAU
	var origin: Vector3 = camera.global_position
	var at: Vector3 = origin + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3(0.0, 80.0, 0.0), at - Vector3(0.0, 120.0, 0.0))
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	at.y = float(hit["position"].y) + 1.0 if not hit.is_empty() else origin.y

	return call_at(kind, at, mood)


func voices_playing() -> int:
	_prune()
	return _voices.size()


# Forgets voices that finished (their players free themselves).
func _prune() -> void:
	var live: Array = []

	for voice in _voices:
		if is_instance_valid(voice) and voice.playing:
			live.append(voice)

	_voices = live


func update(delta: float) -> void:
	if not wild:
		return

	var hour: float = float(_stage.ambient.conditions["hour"])
	var zone: String = _main_zone()

	for kind in KINDS:
		if not _next.has(kind):
			_next[kind] = _rng.randf_range(0.2, 1.0) * float(KINDS[kind]["every"][0])

		_next[kind] = float(_next[kind]) - delta * _stage.ambient.time_scale

		if float(_next[kind]) > 0.0:
			continue

		var every: Array = KINDS[kind]["every"]
		_next[kind] = _rng.randf_range(float(every[0]), float(every[1]))
		var hours: Array = KINDS[kind]["hours"]
		var open: bool = hour >= float(hours[0]) and hour < float(hours[1]) if float(hours[0]) < float(hours[1]) else hour >= float(hours[0]) or hour < float(hours[1])

		if open and _rng.randf() < float(KINDS[kind]["zones"].get(zone, 0.0)) * _stage.ambient.weather_calls * season_factor(kind):
			call_nearby(kind, "idle")


# How much the season favours this kind's natural calls (wolves howl most in winter), 1 when the table says nothing.
func season_factor(kind: String) -> float:
	return float(KINDS[kind].get("seasons", {}).get(str(_stage.ambient.conditions["season"]), 1.0))


func _main_zone() -> String:
	var best: String = "meadow"
	var top: float = -1.0

	for zone in _stage.ambient.weights:
		if zone == "wetland":
			continue                                   # wet ground under the open sky, wood or meadow: those still name the animals

		if float(_stage.ambient.weights[zone]) > top:
			top = float(_stage.ambient.weights[zone])
			best = str(zone)

	return best


# A bird bursting up into flight (animal_view.took_off, the server's FLY state), heard where it rose: the game birds' whirr of wings
# (ambient_life.flush, medium wings; the big slow flaps only after a crow's alarm, Dave 3 Nov 2026), a crow caws its alarm and flaps off.
# Birds with no flight of their own (ducks, geese, gulls, hens run) and every other animal: nothing. False when nothing played.
# Heard within TAKE_OFF_REACH_M, while the voice budget has room, one kind at most every TAKE_OFF_EVERY_MS (a covey flushing together is one whirr).
const TAKE_OFF := {"grouse": "medium", "pheasant": "medium", "guineafowl": "medium", "crow": "crow"}
const TAKE_OFF_REACH_M := 80.0
const TAKE_OFF_EVERY_MS := 1500
var _take_off_until: Dictionary = {}     # kind -> msec before which its next take-off is not heard


func took_off(kind: String, at: Vector3) -> bool:
	if not TAKE_OFF.has(kind) or _stage == null or _stage.get("ambient") == null or not at.is_finite() or not _stage.has_room():
		return false

	var camera: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null

	if camera != null and camera.global_position.distance_to(at) > TAKE_OFF_REACH_M:
		return false

	var now: int = Time.get_ticks_msec()

	if now < int(_take_off_until.get(kind, 0)):
		return false

	var played: bool = _stage.ambient.alarm(at) if str(TAKE_OFF[kind]) == "crow" else _stage.ambient.flush(at, 0.0, str(TAKE_OFF[kind]))

	if played:
		_take_off_until[kind] = now + TAKE_OFF_EVERY_MS   # only a take-off heard holds the next one back

	return played


func _bird(at: Vector3, mood: String) -> bool:
	if mood == "idle":
		return _stage.ambient.call_named(BIRD_IDLE[_rng.randi_range(0, BIRD_IDLE.size() - 1)], at)

	return _stage.ambient.alarm(at)


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var list: Array = SoundStage._find(RECORDED_DIR, sound_name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, sound_name)

	_streams[sound_name] = list
	return list
