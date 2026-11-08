extends Node

# Frozen ponds (client only, job 88). When the air stays below freezing a still pond or lake freezes over
# (weather.ice_cover, 0 open .. 1 frozen; sheet thick enough to walk on from ICE_WALK):
#   - footsteps on it use the "ice" surface (sound_stage.footstep): a hard tap and a hollow tock;
#   - now and then a step cracks (crack(): more often when running or landing hard);
#   - from the shore the ice groans and pings now and then (a long low sweep every GROAN_EVERY seconds, more in the
#     cold), in place of the laps and the fish of the open water (water_sounds.gd and ambient_life.gd go quiet);
#   - rivers and brooks keep running: only still water freezes.
# One-shots in the group world_sounds on the Nature bus (the crack on Foley); both ask has_room() first.
# Sounds: assets/audio/ice/ice_crack_N, ice_groan_N (make_ice.py) and floors/step_ice_N (make_floors.py);
# recordings in recorded/ice/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const IceFeel := preload("res://src/client/ice_feel.gd")   # bands by thickness (docs/design/ice_walk_feel.md)
const GENERATED_DIR := "res://assets/audio/ice/"
const RECORDED_DIR := "res://assets/audio/recorded/ice/"

const ICE_WALK := 0.5                   # ice_cover from which a pond bears steps (and the open-water sounds stop)
const GROAN_EVERY := [25.0, 70.0]       # seconds between groans at the edge of full ice
const GROAN_REACH_M := 60.0
const GROAN_DB := -16.0
const CRACK_DB := -8.0
# Ice walk feel (ice_walk_feel.md section 3): the zing runs off a crack, the boom comes from a thick sheet, skim and film break under a wader.
const ZING_DB := -12.0
const ZING_REACH_M := 60.0
const ZING_AWAY_M := [15.0, 40.0]
const BOOM_DB := -14.0
const BOOM_REACH_M := 200.0
const SKIM_DB := -14.0
const FILM_DB := -10.0
const PLUNGE_DB := -6.0

var cracks_played: int = 0
var groans_played: int = 0
var last: String = ""
var groan_scale: float = 1.0            # --ice-test shortens the wait
var zings_played: int = 0
var booms_played: int = 0
var breaks_played: int = 0
var hour: float = 12.0                  # the game hour (terrain_client sets it with the weather): booms come at dawn and dusk

var _stage                              # SoundStage (budget, weather, water)
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _groan_left: float = 4.0
var _live: Array = []


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


# True when the water under the player's feet is a frozen pond that bears weight.
func walkable() -> bool:
	return _stage.weather.ice_cover >= ICE_WALK and _stage.water.still_near()


func update(delta: float, body: CharacterBody3D, underwater: bool) -> void:
	_groan_left -= delta

	if _groan_left > 0.0:
		return

	var cover: float = _stage.weather.ice_cover
	_groan_left = _rng.randf_range(float(GROAN_EVERY[0]), float(GROAN_EVERY[1])) * groan_scale / maxf(cover, 0.5)

	if cover < ICE_WALK or underwater or not _stage.water.still_near() or not _stage.has_room():
		return

	var shore: Array = _stage.water.shore_squares()
	var square: Dictionary = shore[_rng.randi_range(0, mini(shore.size(), 4) - 1)]
	var near: float = Vector2(square["at"].x - body.global_position.x, square["at"].z - body.global_position.z).length()

	if _rng.randf() < IceFeel.boom_share(IceFeel.band_of(cover), hour):
		if near <= BOOM_REACH_M and play("ice_boom", square["at"], BOOM_DB + _rng.randf_range(-3.0, 2.0), 6.0, BOOM_REACH_M * 1.5, "Nature"):
			booms_played += 1
			print(IceFeel.log_line(IceFeel.band_of(cover), "boom", last, 1.0, INF))

		return

	if near <= GROAN_REACH_M:
		play("ice_groan", square["at"], GROAN_DB + _rng.randf_range(-3.0, 2.0), 3.0, GROAN_REACH_M * 1.5, "Nature")
		groans_played += 1


# A step on the ice may crack. `gait` 0 walk, 1 jog, 2 run; `boost_db` above 0 is a hard landing. The chance follows the
# band (a thin sheet cracks more, a thick one less; a hard landing on a thin sheet always cracks) and a crack may run off as a zing ahead of
# `toward` (the walking direction; zero: any way).
func step(feet: Vector3, gait: int, boost_db: float, toward: Vector3 = Vector3.ZERO) -> bool:
	var band: int = IceFeel.band_of(_stage.weather.ice_cover)
	var chance: float = 1.0 if band == IceFeel.Band.THIN and boost_db > 0.0 else IceFeel.crack_chance(band, gait, boost_db > 0.0)

	if _rng.randf() >= chance or not _stage.has_room():
		return false

	var cracked: bool = play("ice_crack", feet, CRACK_DB + _rng.randf_range(-3.0, 2.0) + boost_db, 4.0, 40.0, "Foley")

	if cracked and _rng.randf() < IceFeel.zing_share(band):
		var way: Vector3 = Vector3(toward.x, 0.0, toward.z)
		way = way.normalized() if way.length() > 0.1 else Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
		way = way.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
		var at: Vector3 = feet + way * _rng.randf_range(float(ZING_AWAY_M[0]), float(ZING_AWAY_M[1]))

		if play("ice_zing", at, ZING_DB + _rng.randf_range(-3.0, 2.0), 8.0, ZING_REACH_M, "Nature"):
			zings_played += 1
			print(IceFeel.log_line(band, "zing", last, 1.0, INF))

	return cracked


# A wading step through skim or film (no collider under it). `first` is the step that breaks through from the bank or a sheet.
# Returns the sound name played, or "".
func skim_step(feet: Vector3, band: int, first: bool) -> String:
	if not _stage.has_room():
		return ""

	var sound_name: String = "ice_plunge" if band == IceFeel.Band.FILM and first else ("ice_film" if band == IceFeel.Band.FILM else "ice_skim")

	if band != IceFeel.Band.SKIM and band != IceFeel.Band.FILM:
		return ""

	var db: float = PLUNGE_DB if sound_name == "ice_plunge" else (FILM_DB if band == IceFeel.Band.FILM else SKIM_DB)

	if play(sound_name, feet, db + _rng.randf_range(-2.0, 1.5), 3.0, 30.0, "Foley"):
		breaks_played += 1
		return sound_name

	return ""


func play(sound_name: String, at: Vector3, db: float, unit: float, reach: float, bus: String) -> bool:
	_live = _live.filter(func(p): return is_instance_valid(p))
	var list: Array = _variants(sound_name)

	if list.is_empty() or _live.size() >= 3:
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[pick]
	player.bus = bus
	player.volume_db = db
	player.pitch_scale = _rng.randf_range(0.9, 1.12)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = unit
	player.max_distance = reach
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	_live.append(player)

	if sound_name == "ice_crack":
		cracks_played += 1

	last = "%s_%d (%s)" % [sound_name, pick, SoundStage.tag(player.stream)]
	return true


# Headless checks: ends every live sound at once.
func test_release() -> void:
	for p in _live:
		if is_instance_valid(p):
			p.stop()
			p.queue_free()

	_live.clear()


func voices_playing() -> int:
	_live = _live.filter(func(p): return is_instance_valid(p))
	return _live.size()


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var list: Array = SoundStage._find(RECORDED_DIR, sound_name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, sound_name)

	_streams[sound_name] = list
	return list


func _exit_tree() -> void:
	_streams.clear()
