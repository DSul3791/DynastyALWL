extends Node

const AirBands := preload("res://src/client/air_bands.gd")
const OutdoorAir := preload("res://src/client/outdoor_air.gd")

# Muffling for sounds in the world (client only): a call, a stream or a dig sound behind a hill
# or far off through dense forest loses its high end, the way it does in real life.
#
# Every world sound (a 3D player in the group "world_sounds") gets a low-pass cutoff:
# - Forest: a share of the trees around the player (AmbientLife.weights["forest"]) times how
#   far the source is dulls it (the trunks and leaves in between), down to 45 % of the cutoff.
# - Hills (Mid and High only): one voxel ray from the head to the source; ground in the way drops
#   the cutoff to HILL_HZ. Low skips the ray: it has the forest filter only.
# Updated every SCAN_SEC and eased, so nothing jumps. Nothing is done while flying (admin tool).
# A voxel ray reads the loaded ground data, so it works past the distance with physics colliders.
# --sound-outdoors (docs/design/sound_outdoors_design.md): the open air moves each voice too (outdoor_air.gd: wind direction, night
# carry, forest level, cold and fog). The level goes through unit_size (the voice's own size kept in the meta "air_unit"), never
# volume_db, which the sound modules write; a new voice gets its level at once (node_added), not at the next scan.

const EASE_TICK_SEC := 0.05            # the cutoff easing runs at 20 Hz
const SCAN_SEC := 0.5
const OPEN_HZ := 9000.0                 # the distance filter's cutoff for a clear path
const HILL_HZ := 700.0                  # behind a hill
const FOREST_FLOOR := 0.45              # dense forest at long range: this share of the cutoff
const FOREST_FULL_M := 80.0             # distance at which the forest dulling is full
const NEAR_M := 8.0                     # closer than this nothing is muffled
const MARGIN_M := 1.5                   # ground this close to the source does not count as in the way
const EASE_PER_SEC := 3.0               # of the way to the target cutoff per second

var occluded: int = 0                   # sources behind a hill at the last scan (HUD)
var filtered: int = 0                   # sources with a cutoff below open at the last scan
var air_counts: Dictionary = {}         # band bus -> voices on it at the last scan (falls, fires; air_bands.gd)

var _stage                              # SoundStage (tier, ambient weights)
var _tool: VoxelTool
var _ease_acc: float = 0.0
var _scan_left: float = 0.0
var _targets: Dictionary = {}           # player instance id -> target cutoff

const AIR_EASE_DB_PER_SEC := 6.0
var outdoors: bool = false              # --sound-outdoors
var air: Dictionary = {"wind": 0.0, "toward": Vector2.ZERO, "gust": 0.0, "night": 0.0, "calm": 0.0, "fog": 0.0, "temp_c": 10.0, "forest": 0.0}
var air_shadowed: int = 0               # voices 3 dB or more down for the wind at the last scan (HUD)
var air_carried: int = 0                # voices 1 dB or more up at the last scan
var air_masked: int = 0                 # small voices hidden by rain or a gale at the last scan
var _air_targets: Dictionary = {}       # player instance id -> target dB
var _head: Vector3 = Vector3.INF


func setup(stage, terrain: VoxelLodTerrain) -> void:
	_stage = stage
	_tool = terrain.get_voxel_tool()
	_tool.channel = VoxelBuffer.CHANNEL_SDF
	outdoors = OS.get_cmdline_user_args().has("--sound-outdoors")
	_hook()


func _enter_tree() -> void:
	_hook()


func _hook() -> void:
	if outdoors and is_inside_tree() and not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


# Once a second from terrain_client.gd: the world weather (weather.gd state), the sun's height (sin), the hour and the fog look 0..1.
func set_air(state: Dictionary, elevation: float, hour: float, fog: float) -> void:
	var wind: float = float(state.get("wind", 0.0))
	var heading: float = float(state.get("wind_dir", 0.0))
	air["wind"] = wind
	air["toward"] = Vector2(cos(heading), sin(heading))
	air["night"] = OutdoorAir.night_share(elevation, hour)
	air["calm"] = OutdoorAir.calm_share(float(state.get("cloud", 0.0)), wind)
	air["fog"] = clampf(fog, 0.0, 1.0)
	air["temp_c"] = float(state.get("temp_c", 10.0))


func update(delta: float, body: CharacterBody3D, flying: bool) -> void:
	_scan_left -= delta

	if _scan_left <= 0.0:
		_scan_left = SCAN_SEC
		_scan(body, flying)

	_ease_acc += delta

	if _ease_acc < EASE_TICK_SEC:
		return

	var ease_k: float = clampf(_ease_acc * EASE_PER_SEC, 0.0, 1.0)
	_ease_acc = 0.0

	for node in get_tree().get_nodes_in_group("world_sounds"):
		var player: AudioStreamPlayer3D = node as AudioStreamPlayer3D

		if player != null and _targets.has(player.get_instance_id()):
			player.attenuation_filter_cutoff_hz = lerpf(player.attenuation_filter_cutoff_hz, float(_targets[player.get_instance_id()]), ease_k)

		if player != null and _air_targets.has(player.get_instance_id()):
			var now_db: float = move_toward(float(player.get_meta("air_db", 0.0)), float(_air_targets[player.get_instance_id()]), AIR_EASE_DB_PER_SEC * ease_k / EASE_PER_SEC)
			_set_air_db(player, now_db)


func _scan(body: CharacterBody3D, flying: bool) -> void:
	_targets.clear()
	occluded = 0
	filtered = 0
	air_counts.clear()
	var head: Vector3 = body.global_position + Vector3(0.0, 0.6, 0.0)
	var forest: float = float(_stage.ambient.weights["forest"])
	_air_targets.clear()
	air_shadowed = 0
	air_carried = 0
	air_masked = 0
	_head = Vector3.INF if flying else head
	air["forest"] = forest
	air["gust"] = float(_stage.gust)

	if _stage.weather != null:                    # step 2: masking and fresh snow, from the weather sounds' own eased levels
		air["rain"] = float(_stage.weather.rain)
		air["leaves"] = float(_stage.weather.covered)
		air["snow_fresh"] = float(_stage.weather.snow_fresh)
		air["ground_snow"] = float(_stage.weather.ground_snow)

	for node in get_tree().get_nodes_in_group("world_sounds"):
		var player: AudioStreamPlayer3D = node as AudioStreamPlayer3D

		if player == null or not player.playing:
			continue

		var to: Vector3 = player.global_position - head
		var distance: float = to.length()
		var cutoff: float = OPEN_HZ
		var hill: bool = false

		if distance > NEAR_M and not flying:
			cutoff *= lerpf(1.0, FOREST_FLOOR, forest * clampf(distance / FOREST_FULL_M, 0.0, 1.0))

			if _stage.preset["occlusion_rays"]:
				var hit = _tool.raycast(head, to / distance, distance)

				if hit != null and hit.distance < distance - MARGIN_M:
					cutoff *= HILL_HZ / OPEN_HZ
					occluded += 1
					hill = true

		var air_cut: float = 1.0

		if outdoors and not flying and _moves(player):
			var own_unit: float = float(player.get_meta("air_unit")) if player.has_meta("air_unit") and is_equal_approx(player.unit_size, float(player.get_meta("air_set", -1.0))) else player.unit_size
			var effect: Vector2 = OutdoorAir.total(head, player.global_position, own_unit, air)
			var open_air: float = 1.0 - smoothstep(0.3, 0.7, float(_stage.cave.enclosure))   # in a cave the open air has no say
			effect = Vector2(effect.x * open_air, lerpf(1.0, effect.y, open_air))

			if bool(player.get_meta("air_line", false)):   # a river reach (water_sounds.gd): a line, not a point (3.7)
				effect.x += OutdoorAir.line_db(distance, own_unit)
			_air_targets[player.get_instance_id()] = effect.x
			air_cut = effect.y
			air_shadowed += 1 if effect.x <= -3.0 else 0
			air_carried += 1 if effect.x >= 1.0 else 0
			air_masked += 1 if OutdoorAir.mask_db(distance, minf(OutdoorAir.rain_mask_m(float(air.get("rain", 0.0)), float(air.get("leaves", 0.0))), OutdoorAir.gale_mask_m(float(air["wind"]))), own_unit) <= -6.0 else 0

		cutoff *= air_cut

		if player.has_meta("air_kind"):                   # big far sounds are dulled by shared band buses, not this voice's filter
			var kind: String = str(player.get_meta("air_kind"))
			var effective: float = distance * AirBands.stretch(distance, forest, hill, float(_stage.weather.roofed), float(_stage.cave.enclosure))

			if outdoors:
				effective *= OutdoorAir.band_stretch(float(air["temp_c"])) / maxf(air_cut, 0.3)

			var band: int = AirBands.band_for(kind, effective, int(player.get_meta("air_band", 0)))
			player.set_meta("air_band", band)
			player.bus = AirBands.bus_for(kind, band)
			air_counts[player.bus] = int(air_counts.get(player.bus, 0)) + 1
			cutoff = OPEN_HZ

		if cutoff < OPEN_HZ - 1.0:
			filtered += 1

		_targets[player.get_instance_id()] = cutoff


# A voice the open air may move: positional with falloff (far thunder keeps its own level).
static func _moves(player: AudioStreamPlayer3D) -> bool:
	return player.attenuation_model != AudioStreamPlayer3D.ATTENUATION_DISABLED and player.is_in_group("world_sounds")


# A module that reuses a player may give it a new unit_size (water_sounds.gd turns a river voice into a fall): a size that is not the
# one written here last is taken as the voice's own again.
static func _set_air_db(player: AudioStreamPlayer3D, db: float) -> void:
	if not player.has_meta("air_unit") or not is_equal_approx(player.unit_size, float(player.get_meta("air_set", -1.0))):
		player.set_meta("air_unit", player.unit_size)

	player.set_meta("air_db", db)
	player.unit_size = float(player.get_meta("air_unit")) * db_to_linear(db)
	player.set_meta("air_set", player.unit_size)


func _on_node_added(node: Node) -> void:
	if node is AudioStreamPlayer3D:
		_first_look.call_deferred(node)


# A new voice starts at its level for the air now (a howl upwind starts low), not 0.5 s later.
func _first_look(player: AudioStreamPlayer3D) -> void:
	if not is_instance_valid(player) or _head == Vector3.INF or not _moves(player) or player.has_meta("air_unit"):
		return

	var db: float = OutdoorAir.total(_head, player.global_position, player.unit_size, air).x * (1.0 - smoothstep(0.3, 0.7, float(_stage.cave.enclosure)))

	if bool(player.get_meta("air_line", false)):
		db += OutdoorAir.line_db(_head.distance_to(player.global_position), player.unit_size)

	_set_air_db(player, db)
