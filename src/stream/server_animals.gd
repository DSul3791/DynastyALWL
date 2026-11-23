extends RefCounted

# Animals, step B (data/animals/animals.json; design items/ANIMALS_DESIGN.md, Steve's plan 2026-10-21): the rabbit only.
# Records live on the server only (nothing is saved): spawned out of sight around each player, dropped when nobody is near.
# A rabbit grazes, hops a few metres now and then, and bolts away from a player who comes within spook_m. Movement uses the
# shared Steering module with NPCs. Ticks by distance to the nearest player (10 / 3 / 0.5 Hz), so far animals cost almost nothing.

const Steering := preload("res://src/shared/steering.gd")
const AnimalContact := preload("res://src/shared/animal_contact.gd")   # how near an animal comes to a player (keep_off_players)
const WolvesScript := preload("res://src/stream/server_wolves.gd")
const BigGameScript := preload("res://src/stream/server_big_game.gd")
const ThievesScript := preload("res://src/stream/server_thieves.gd")
const FlocksScript := preload("res://src/stream/server_flocks.gd")
const GoblinsScript := preload("res://src/stream/server_goblins.gd")
const CompanionsScript := preload("res://src/stream/server_companions.gd")
const FlightScript := preload("res://src/stream/server_flight.gd")
const WeatherRules := preload("res://src/shared/weather.gd")
const FogShape := preload("res://src/shared/fog_shape.gd")
const FogGroundScript := preload("res://src/shared/fog_ground.gd")

const GRAZE := 0
const HOP := 1
const FLEE := 2
const ALERT := 3
const WARN := 10                # big game standing its ground (head down), then 11 charge, 12 recover (server_big_game.gd)
const SNEAK := 13               # a thief creeping up on food, 14 running off with it (server_thieves.gd)
const HIDDEN := 5               # in its burrow: never sent, never hunted
const HIT_ZONES := ["body", "head", "chest", "hip", "leg"]   # animal_hit zone codes, the order of MikeW's animal_view HIT_ZONES (docs/design/hunt_feedback_server.md 3)
const HUNCH := 20               # wire only: a grazer standing out the rain, still, head low (animals_in_weather_design.md 6; GRAZE on the server)
const LIE := 19                 # wire only: a grazer bedded down outside its active hours, lying (the companions' LIE; protocol 148, docs/design/ANIMAL_RESTING.md)
const DRINK := 21               # wire only: a deer or stock animal at its drinking place, head down at the water (animals_at_water_server.md; GRAZE on the server)
const STAGGER := 4              # a quarter of the animals are looked at each tick

var cfg: Dictionary = {}
var animals: Dictionary = {}       # id int -> {id, sp, num, pos Vector3, heading, state, target Vector3, timer, acc, home}
var watched: Dictionary = {}       # id int -> true: watched by an admin through the spyglass (set by the server scene each send pass), kept living
var ground_height: Callable        # (x, z) -> height
var ground_edited: Callable        # (x, z) -> bool: a dig or fill touches the ground there (edited_ground.gd); unset: none
var springs_near: Callable         # (Vector3, reach m) -> PackedVector3Array: the ground springs (heads) within reach, from the tiles (unset: none)
var blocked: Callable              # (x, z) -> bool (deep water)
var ice_cover_at: Callable         # (Vector3) -> Ice.cover there (0 open .. 1 a 20 cm sheet; 0.5, 10 cm, bears a person); set by the server scene
var _ice_cache: Dictionary = {}    # animals on ice: Vector2i(1 km band of z, 5 m of height) -> [Ice.cover, msec worked out]
var ice_moat_at: Callable          # (Vector3) -> true in a thaw's shore moat (frozen_water_look.md 4, #729): open water though the sheet bears; unset: none
var spring_ice_x: Callable         # (Vector3) -> the ice's share by springs (Jamie #739): 0 on the open brook below a spring, 0.5 within 10 to 30 m of a spring mouth or inflow, else 1; unset: 1 (wired with #719 step 2's spring rows)
var thunder_between: Callable      # (t0, t1 game seconds, centre, reach m) -> Thunder.strikes there (src/shared/thunder.gd); set by the server scene
var game_seconds: Callable         # () -> the game clock's seconds (thunder)
var _thunder_t: float = NAN        # game second the thunder was last looked at
var _claps: Array = []             # thunder on its way: [strike point, real msec of the flash, ids already flushed]
var walls: Callable                # (x0, z0, x1, z1, margin) -> bool, a wall or heavy station on that step (server_items.structure_blocks_step)
var crossing: Callable             # Steering's `cross`: every walker of this module stops at walls
var player_positions: Callable     # () -> Array of Vector3
var player_stances: Callable       # () -> Array of stances in player_positions order (0 stand, 1 crouch, 2 sit, 3 lie)
var canopy: Callable               # (Vector3) -> bool, whether a spot is under a tree crown (forest for sight and habitat)
var canopy_ready: Callable         # (x, z) -> bool, whether the tree crowns round a spot are known yet (the flora chunks are made; a missing one is started on a worker)
var undergrowth: Callable          # (Vector3) -> bool, the spot is in bushes, ferns or tall grass (server_flora.in_undergrowth): moving through it rustles
var player_loud: Callable          # () -> Array of the loud thing each player did lately (server_action_cues.loud_kinds: "blow", "craft", "hurt", "dig" or ""), player_positions order
var player_stalk: Callable         # () -> Array of hunting skill factors (skills.json actions.stalk, 1.0 for a beginner) in player_positions order
var fires: Callable                # () -> Array of Vector3, burning fires and torch bearers (server_items._lit_fires; wolves read the same list)
var fire_radius: Callable          # (Vector3) -> how far animals keep from that fire (server_items.fire_protect_m: a campfire's tier, 9 m for a torch or lantern burning in hand, a placed light's protect_m)
var wind: Callable                 # () -> the weather dictionary ("wind" 0..1 and "wind_dir" radians, the way it blows toward)
var weather_at: Callable          # (pos) -> the weather over that spot (terrain_server _weather_here: its tile row and 10 m height band, cached a second); unset: the one weather
var weather_ahead: Callable        # (hours) -> the weather dictionary that many game hours from now (WeatherScript.state; animals_in_weather_design.md 3); tests
var weather_ahead_at: Callable     # (hours, pos) -> the weather over that spot's row that many game hours from now; set, it is used instead
var row_of: Callable               # (pos) -> the tile row a spot is in (the storm look-ahead is kept per row)
var died: Callable                 # (species, position, source peer) when an animal is killed
var send_hit: Callable             # (peer, animal id, zone, at): a hit, for every player within hit_send_m (hunt_feedback_server.md 3)
var ticks_run: int = 0
var trails = null                  # game trails (server_trails.gd): every step into a new cell wears the grass a little
var snare_pass: Callable            # (id, species, from, to): a step by an animal near a player, for the set traps it comes up to (server_traps.gd on_pass)
var ranges = null                  # animal places and their trails (server_ranges.gd): warrens, deer beds and feeding grounds; unset: no daily trips
var flocks = null                  # bird flocks on water (server_flocks.gd)
var water_level: Callable          # (x, z) -> water surface height, NAN on dry land (flocks float on it)
var fresh_water_m: Callable        # (x, z) -> distance (m) to perennial fresh water from the baked tile (Stage E), NAN when the tile has none
var thieves = null                 # opportunists (fox; server_thieves.gd): smell loose food, creep up, take it and run
var drop_loot: Callable            # (item number, count, position) when a thief is killed carrying food
var big_game = null                # defending big game (moose; server_big_game.gd): warn, dodgeable charge, recover
var biome_at: Callable             # (x, z) -> biome name of the ground there ("" unknown); species rows may list "biomes" weights (0 or missing = never)
var hour_now: Callable             # () -> hour of the game day 0..24 (the server's clock); species rows may list "active" {day, dusk, night} spawn chances 0..1
var sunrise_now: Callable          # () -> today's sunrise hour (weather.gd sunrise_hour, the sun the sky draws); unset keeps the fixed hours of period_of
var _sun: Array = [-1, 6.0]        # [msec read, sunrise hour]: the sunrise moves a few minutes a game day, read again every 5 s
var air_at: Callable               # (Vector3) -> Weather.air_c at that point: its zone's air at that height, this hour (docs/design/one_temperature.md); unset: temp_c less the lapse
var no_spawn: Callable                # (x, z) -> bool: true within no_spawn_m of something a player put down (server_items.spawn_blocked; Dave 17 Nov 2026): no animal is made there
var lair_guarded: Callable            # (x, z, radius) -> bool: true when a burning placed fire lies within radius of a lair's mouth (lair.guard_m), so no new group comes (Dave 8 Nov 2026, decision 13)
var _lair_state: Dictionary = {}   # mouth "x,z" -> {"made": a group has been made here, "empty_since": seconds when it was found empty, -1 while a group is there}
var lair_path: Callable              # (mouth x, z) -> PackedVector3Array: the cave floor path from that den mouth to the den (tile goblin_den_paths), empty when none
var berry_bushes: Callable           # (Vector3, radius) -> PackedVector3Array: standing berry plants near a point, from flora chunks already made (goblins forage at them)
var bandit_camps = null              # server_bandits.gd: camp bandits and tethered horses take their own step (docs/design/BANDIT_CAMPS.md stage 2)
var goblins = null                   # den life (server_goblins.gd): species with a "den_life" row sleep in the cave by day, watch fires and forage at night
var flight = null                    # single birds in flight (server_flight.gd, bird_flight_server_design.md): species with a "flight" row fly when they bolt
var companions = null                # companions (server_companions.gd): the stray a player befriends with food, then their dog (Dave 8 Nov 2026, decisions 5 and 6)
const CAVE_DEN_SPECIES := ["bear", "fox"]   # made at their cave dens by the top-up (TileTerrainData.ANIMAL_DEN_BY_SIZE); wolf packs take theirs in server_wolves
var cave_den_mouths: Callable         # (x, z, sp) -> PackedVector2Array: the mouths (world x, z) of the caves that species dens in, in the tile there (TileTerrainData.animal_den_mouths; bears, wolves, foxes, Dave 19 Nov 2026)
var lair_mouths: Callable             # (x, z) -> PackedVector2Array: the cave mouths (world x, z) of the tile there; species with a "lair" row spawn their groups at them (goblins, Dave 7 Nov 2026)
var season_now: Callable           # () -> "spring", "summer", "autumn" or "winter" (GameClock.season()); species rows may list "seasons" {name: {threat_x, spook_x}}
var traits: bool = true            # temperaments and young (Dave 6 Nov 2026); seeded tests that predate them turn this off, so every animal is born "defensive" with no young
var town: Vector2 = Vector2(INF, INF)   # the starter town (x, z): the middle of its NPC markers (server_npcs.gd town_point), the centre of the island level and of the stray dogs; never the spawn (Dave 9 Nov 2026)
var wolves = null                  # the pack brain (server_wolves.gd); wired by the server, tests may leave player_info unset
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var blood: Array = []              # drops [position Vector3, born msec] a wounded animal left, oldest first
var _next_id: int = 1
var _spawning_young: bool = false
const YOUNG_NUM := 100             # a young animal is sent as its species number + 100 (a calf, cub, fawn, piglet or foal: the client draws it smaller)
var _spawn_acc: float = 0.0
var _tick_no: int = 0
var _top_idx: int = 0
var _next_herd: int = 1
var _wind_s: float = 0.0
var _wind_dir: Vector2 = Vector2.ZERO
var _wx: Dictionary = {}           # this tick's weather (animals_in_weather_design.md 3): rain, snow, storm, wind, mist
# Where the valley fog lies (fog_ground.gd, the client's cold-air floor): one window per player, read from the world's tiles on a worker
# thread. fog_world {"tiles_dir", "tile_size_m"} is set by the host; empty (tests, no tiles) keeps the floor at sea level.
var fog_world: Dictionary = {}
var _fog_grounds: Array = []
const FOG_GROUNDS_MAX := 16        # windows kept (players together share one)
const CLEAR_SIGHT_M := 800.0      # in clear air with no fog the haze takes under FogShape's 53 % this near (about 900 m): sight needs no sums
var _water_spots: Dictionary = {}  # animals at water: Vector2i 50 m cell of the asker and reach -> [[stand spot, water point] or [], msec found]
var _storm_ahead: bool = false     # a storm (storm 0.5 or more) 12 to 24 game hours ahead: the falling pressure prey feel (lesson 4)
var _storm_rows: Dictionary = {}   # row -> its _storm_ahead (weather_ahead_at), looked at once a row every weather.ahead_every_s real seconds
var _ahead_acc: float = INF        # real seconds since weather_ahead was last sampled
var _dogs: Array = []              # this tick's companion dogs as a presence for wild animals: [animal id, position, barking] (dog_companion_design.md 11)
var _herds: Dictionary = {}       # herd id -> Array of animal ids (3 to 6 deer)
var _fire_cache: Array = []       # [Vector3 fire, keep-off metres] this tick (fires, fire_radius)
var _noise_acc: float = 0.0       # time since the last undergrowth sample (_sample_noise)
var _noise_from: Array = []       # player positions at the last sample
var _player_vel: Array = []       # per player (the _noise_from order): ground velocity (x, z) over the last noise sample, m/s
var _noisy: Array = []            # per player (player_positions order): how much farther they are sensed for rustling undergrowth (1.0 none)
var _heard: Array = []            # per player (player_positions order): how far a loud action carries (senses.action_heard_x; 0.0 none), past stance and cover


# True when the step from (x0, z0) to (x1, z1) goes through a wall or heavy station, grown by the body margin.
func _init() -> void:
	crossing = Callable(self, "crosses_wall")


func crosses_wall(x0: float, z0: float, x1: float, z1: float) -> bool:
	return walls.is_valid() and bool(walls.call(x0, z0, x1, z1, float(cfg.get("wall_margin_m", 0.3))))


# True when a wall or heavy station stands on the straight line between two points (no body margin): a blow never lands through one,
# either way (an enemy's charge at a player behind a wall, a player's jab at an animal behind one; coordinator's fight walk, 23 Nov 2026).
func wall_between(from: Vector3, to: Vector3) -> bool:
	return walls.is_valid() and bool(walls.call(from.x, from.z, to.x, to.z, 0.0))


func setup() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	# Every species' reaction distances live in one table (animals.json reactions, Dave 19 Nov 2026); the rows read them as alert_m, spook_m, safe_m.
	var reactions: Dictionary = cfg.get("reactions", {}).get("notice_flee_safe_m", {})

	for sp in reactions:
		var row: Variant = reactions[sp]

		if not (row is Array) or (row as Array).size() != 3:
			push_error("animals.json reactions.notice_flee_safe_m.%s: not [notice_m, flee_m, safe_m]" % sp)
		elif cfg.get("species", {}).has(sp):
			cfg["species"][sp]["alert_m"] = float(row[0])
			cfg["species"][sp]["spook_m"] = float(row[1])
			cfg["species"][sp]["safe_m"] = float(row[2])

	for sp in cfg.get("species", {}):
		if not reactions.has(sp):
			push_error("animals.json reactions.notice_flee_safe_m: no row for %s (it would never notice a player)" % sp)

	rng.randomize()   # luck-exempt: world wildlife placement, no player outcome
	wolves = WolvesScript.new()
	wolves.host = self
	big_game = BigGameScript.new()
	big_game.host = self
	thieves = ThievesScript.new()
	thieves.host = self
	flocks = FlocksScript.new()
	flocks.host = self
	goblins = GoblinsScript.new()
	goblins.host = self
	goblins.trust.cfg = species_def("goblin").get("ally", {})
	flight = FlightScript.new()
	flight.host = self
	companions = CompanionsScript.new()
	companions.host = self


func species_def(sp: String) -> Dictionary:
	return cfg.get("species", {}).get(sp, {})


# Admin and tests: put an animal down at once (x, z; the ground gives y). Returns its id or 0.
func spawn(sp: String, x: float, z: float) -> int:
	var def: Dictionary = species_def(sp)

	if def.is_empty() or animals.size() >= int(cfg.get("server_cap", 150)):
		return 0

	var y: float = float(ground_height.call(x, z)) if ground_height.is_valid() else 0.0

	if def.has("flock") and not bool(def["flock"].get("on_land", false)) and water_level.is_valid():
		y = float(water_level.call(x, z))   # a flock sits on the surface (a land flock, such as gulls on a beach, stands on the ground)
	elif swims(def):
		y = swim_height(def, x, z)   # a swimmer put down in water rides the surface

	if is_nan(y):
		return 0

	var id: int = _next_id
	_next_id += 1
	var pos: Vector3 = Vector3(x, y, z)
	animals[id] = {"id": id, "sp": sp, "num": int(def.get("number", 0)), "pos": pos, "heading": rng.randf() * TAU, "state": GRAZE,   # luck-exempt: which way a new animal faces
		"target": pos, "timer": _graze_time(def), "acc": 0.0, "home": pos, "hp": float(def.get("health", 5.0)), "herd": 0, "alarm": -1.0, "burst": 0.0, "alert": 0.0, "burrow": pos if float(def.get("burrow_m", 0.0)) > 0.0 else Vector3.INF, "to_burrow": false}

	if def.has("flock"):
		var span: Array = def["flock"].get("birds", [6, 14])
		animals[id]["birds"] = rng.randi_range(int(span[0]), int(span[1]))   # luck-exempt: how many birds in a flock

	if def.has("tame"):
		animals[id]["tame"] = rng.randf()   # luck-exempt: how tamable this horse is born (0 flighty, 1 friendly)

	if def.has("den"):
		animals[id]["den"] = pos   # where it spawned is its den (a bear's, near the river: habitat near_fresh_water_m); it ranges round it and defends it

	if traits:
		var span: Vector2i = level_span(x, z)
		animals[id]["level"] = rng.randi_range(span.x, span.y)   # luck-exempt: an animal's level, from where it lives on the island
		animals[id]["hp"] = float(animals[id]["hp"]) * level_x(animals[id], "hp")

	if traits and def.has("temperament") and not _spawning_young:
		animals[id]["temper"] = _draw_share(def["temperament"])   # its inherent temperament (passive, defensive, neutral, aggressive, friendly)

	if def.has("defend"):
		var share: float = float(def.get("protective_share", 0.3))

		if traits and def.has("young"):
			share = float(def["young"].get("share", 0.0)) if _young_season(def) else 0.0

		animals[id]["protective"] = share > 0.0 and not _spawning_young and rng.randf() < share   # luck-exempt: whether this animal has young with it
		animals[id]["cool"] = 0.0

		if traits and def.has("young") and bool(animals[id]["protective"]):
			_spawn_young(id)

	return id


# True where no animal may be made (no_spawn_m round anything a player put down). Asked for every member's own spot, not only a group's centre.
func no_spawn_at(x: float, z: float) -> bool:
	return no_spawn.is_valid() and bool(no_spawn.call(x, z))


# Young (Dave 6 Nov 2026): a mother with young runs from a player sooner, but a player who comes between her and them (near a young
# one) is attacked hard, torch or not. The young are animals of the same species that follow her at follow_m and run when she runs.
func _spawn_young(mother: int) -> void:
	var m: Dictionary = animals[mother]
	var y: Dictionary = species_def(m["sp"])["young"]
	var span: Array = y.get("count", [1, 2])
	var kids: Array = []
	_spawning_young = true

	for _kid_n in rng.randi_range(int(span[0]), int(span[1])):   # luck-exempt: how many young
		var ang: float = rng.randf() * TAU   # luck-exempt: where each young one keeps to
		var off: Vector3 = Vector3(cos(ang), 0.0, sin(ang)) * float(y.get("follow_m", 3.0))

		if no_spawn_at(m["pos"].x + off.x, m["pos"].z + off.z):
			continue

		var kid: int = spawn(m["sp"], m["pos"].x + off.x, m["pos"].z + off.z)

		if kid > 0 and animals.has(kid):
			animals[kid]["mother"] = mother
			animals[kid]["off"] = off
			animals[kid]["num"] = int(m["num"]) + YOUNG_NUM
			animals[kid]["hp"] = float(animals[kid]["hp"]) * float(y.get("hp_x", 0.3))
			animals[kid]["temper"] = "passive"
			animals[kid].erase("den")
			kids.append(kid)

	_spawning_young = false
	m["young"] = kids


# Whether young are about in the current season (young.seasons; every season without a clock).
func _young_season(def: Dictionary) -> bool:
	return not season_now.is_valid() or str(season_now.call()) in def["young"].get("seasons", ["spring", "summer"])


# A mother's living young (ids still in the map), or [].
func _young_of(a: Dictionary) -> Array:
	return (a.get("young", []) as Array).filter(func(k): return animals.has(k))


# One key from {key: share} weighted by its share (keys in sorted order so a seed gives the same draw).
func _draw_share(shares: Dictionary) -> String:
	var keys: Array = shares.keys()
	keys.sort()
	var total: float = 0.0

	for k in keys:
		total += maxf(float(shares[k]), 0.0)

	var r: float = rng.randf() * total   # luck-exempt: an animal's inherent temperament

	for k in keys:
		r -= maxf(float(shares[k]), 0.0)

		if r < 0.0:
			return str(k)

	return str(keys.back()) if not keys.is_empty() else "defensive"


# Temperament (Dave 6 Nov 2026): every animal has one. Passive animals hide or run at all costs and never attack; defensive ones run
# but attack a player inside their threat range; neutral ones ignore a player until it is inside their threat range; aggressive ones
# do not run and attack from twice as far; friendly ones come up to a player and never attack. The kinds are in animals.json "temperament".
func temper_of(a: Dictionary) -> String:
	return str(a.get("temper", "defensive"))


func _temper_row(a: Dictionary) -> Dictionary:
	return cfg.get("temperament", {}).get("kinds", {}).get(temper_of(a), {})


# The species' change for this season ({threat_x, spook_x}), e.g. a bear hungry after its winter sleep is bolder in spring.
func _season_row(def: Dictionary) -> Dictionary:
	if not def.has("seasons") or not season_now.is_valid():
		return {}

	return def["seasons"].get(str(season_now.call()), {})


# Whether this animal may attack at all (server_big_game.warn asks). The young never do; passive and friendly animals only when
# forced (a mother whose young a player has come between).
func may_attack(a: Dictionary, forced: bool = false) -> bool:
	if a.has("mother"):
		return false

	return forced or bool(_temper_row(a).get("attacks", true))


# A young animal keeps to its mother: walks where she walks (at its own spot beside her), runs when she runs.
func _step_young(a: Dictionary, dt: float) -> void:
	var m: Dictionary = animals[a["mother"]]
	var def: Dictionary = species_def(a["sp"])
	a["target"] = m["pos"] + a["off"]
	var far: float = Vector2(a["pos"].x - a["target"].x, a["pos"].z - a["target"].z).length()
	var running: bool = int(m["state"]) == FLEE or int(m["state"]) == WARN + 1   # charging
	a["state"] = FLEE if running else (HOP if far > 1.0 else GRAZE)

	if a["state"] == GRAZE:
		return

	var speed: float = float(def.get("flee_mps", 7.5)) if running else float(def.get("walk_mps", 1.5)) * (2.0 if far > 6.0 else 1.0)
	var ground_for: Callable = ground_height
	var blocked_for: Callable = blocked

	if ice_on():
		var moves: Array = ice_moves(def, str(a["sp"]))
		ground_for = moves[0]
		blocked_for = moves[1]

	if swims(def):      # a young swimmer (a moose calf) follows its mother into the water
		ground_for = func(x: float, z: float) -> float: return swim_height(def, x, z)
		blocked_for = Callable()

	var r: Dictionary = walk_step(a["pos"], a["target"], speed, dt, ground_for, blocked_for, 0.4, a["heading"], crossing)

	if r["moved"]:
		a["pos"] = r["pos"]
		a["heading"] = r["heading"]


# One drop of blood where a wounded animal is (a trail: every_m apart, at most max_drops per animal, max_total on the map,
# gone after life_s seconds).
func _drop_blood(a: Dictionary) -> void:
	var sp: Dictionary = cfg.get("blood", {})

	if int(a["drops"]) >= int(sp.get("max_drops", 24)):
		return

	a["drops"] = int(a["drops"]) + 1
	a["last_drop"] = a["pos"]
	blood.append([a["pos"], Time.get_ticks_msec()])

	while blood.size() > int(sp.get("max_total", 200)):
		blood.pop_front()


# Burrow spots (protocol 87, MikeW 3 Nov): the burrows of living animals within send_radius_m of a point, nearest first, at most
# burrows_sent (default 40). The client draws a small mound at each so a new player can see where rabbits live.
func burrows_near(point: Vector3) -> PackedVector3Array:
	var radius: float = float(cfg.get("send_radius_m", 120.0))
	var found: Array = []

	for id in animals:
		var b: Vector3 = animals[id].get("burrow", Vector3.INF)

		if b == Vector3.INF:
			continue

		var d: float = Vector2(b.x - point.x, b.z - point.z).length()

		if d <= radius:
			found.append([d, b])

	found.sort_custom(func(l, r): return l[0] < r[0])
	var out: PackedVector3Array = PackedVector3Array()

	for f in found.slice(0, int(cfg.get("burrows_sent", 40))):
		out.append(f[1])

	return out


# Inland bird nests (MikeW, 3 Nov; items side: Sal, data/items/nests.json): fixed spots, one chance per nests.cell_m square, so a
# nest is in the same place every visit and its id (kind and cell) stays the same for the robbed-nest record. A grouse nest lies on
# open ground of a grouse biome (heath, boreal forest, tundra); a songbird nest sits under trees or bushes of a songbird biome. The
# chance per cell is nests.<kind>_chance x the species' biome weight; slopes over slope_max never hold one.
func nests_near(point: Vector3, reach: float) -> Array:
	var ncfg: Dictionary = cfg.get("nests", {})
	var cell: float = float(ncfg.get("cell_m", 48.0))
	var out: Array = []
	_nest_pending = false

	if cell <= 0.0 or not ground_height.is_valid():
		return out

	var x0: int = int(floor((point.x - reach) / cell))
	var x1: int = int(floor((point.x + reach) / cell))
	var z0: int = int(floor((point.z - reach) / cell))
	var z1: int = int(floor((point.z + reach) / cell))

	for cz in range(z0, z1 + 1):
		for cx in range(x0, x1 + 1):
			for kind in ["grouse", "songbird"]:
				var spot: Variant = _nest_in_cell(kind, cx, cz, cell, ncfg)

				if spot != null and Vector2(spot.x - point.x, spot.z - point.z).length() <= reach:
					out.append({"id": "%s:%d:%d" % [kind, cx, cz], "kind": kind, "pos": spot})

	return out


# Nest spots for the client (protocol 91, MikeW 4 Nov): every grouse and songbird nest within send_radius_m of a point, as
# [PackedVector3Array positions, PackedByteArray kinds (0 grouse, 1 songbird)]. The answer only depends on the point's
# nest_send_cell_m square, so it is worked out once per square and kept (the spots never move).
var _nest_send_cache: Dictionary = {}
var _nest_pending: bool = false    # set by nests_near when some cell's tree crowns were not known yet: that answer is not kept


func nest_spots_near(point: Vector3) -> Array:
	var step: float = float(cfg.get("nests", {}).get("send_cell_m", 24.0))
	var key: Vector2i = Vector2i(int(floor(point.x / step)), int(floor(point.z / step)))

	if _nest_send_cache.has(key):
		return _nest_send_cache[key]

	var centre: Vector3 = Vector3((float(key.x) + 0.5) * step, point.y, (float(key.y) + 0.5) * step)
	var spots: PackedVector3Array = PackedVector3Array()
	var kinds: PackedByteArray = PackedByteArray()

	for nest in nests_near(centre, float(cfg.get("send_radius_m", 120.0))):
		spots.append(nest["pos"])
		kinds.append(0 if str(nest["kind"]) == "grouse" else 1)

	if _nest_pending:   # the flora round some cell is still being made: answer now, ask again next time (songbird nests were never kept, 5 Nov PC look)
		return [spots, kinds]

	if _nest_send_cache.size() >= 256:
		_nest_send_cache.clear()

	_nest_send_cache[key] = [spots, kinds]
	return _nest_send_cache[key]


# The nest of `kind` in one cell, or null. Deterministic: a hash of the kind and the cell picks the roll and the spot.
func _nest_in_cell(kind: String, cx: int, cz: int, cell: float, ncfg: Dictionary) -> Variant:
	var sp: String = "grouse" if kind == "grouse" else "songbirds"
	var def: Dictionary = species_def(sp)

	if def.is_empty():
		return null

	var h: int = hash([kind, cx, cz, int(ncfg.get("seed", 7))])
	var roll: float = float(h & 0xFFFF) / 65535.0
	var fx: float = float((h >> 16) & 0xFF) / 255.0
	var fz: float = float((h >> 24) & 0xFF) / 255.0
	var x: float = (float(cx) + 0.1 + 0.8 * fx) * cell
	var z: float = (float(cz) + 0.1 + 0.8 * fz) * cell

	if roll >= float(ncfg.get(kind + "_chance", 0.0)) * biome_weight(def, x, z):
		return null

	var y: float = float(ground_height.call(x, z))

	if is_nan(y) or (blocked.is_valid() and bool(blocked.call(x, z))):
		return null

	var steep: float = 0.0

	for d in [Vector2(3.0, 0.0), Vector2(0.0, 3.0)]:
		var other: float = float(ground_height.call(x + d.x, z + d.y))
		steep = maxf(steep, absf(other - y) / 3.0 if not is_nan(other) else 9.0)

	if steep > float(ncfg.get("slope_max", 0.5)):
		return null

	if canopy.is_valid() and canopy_ready.is_valid() and not bool(canopy_ready.call(x, z)):
		_nest_pending = true   # the crowns here are not in the cover index yet, so "under trees" cannot be told: no nest for now, not kept
		return null

	var under_trees: bool = canopy.is_valid() and bool(canopy.call(Vector3(x, y, z)))

	if kind == "songbird" and canopy.is_valid() and not under_trees:
		return null   # a songbird nests in a bush or low tree

	if kind == "grouse" and under_trees:
		return null   # a grouse nests on open ground, in heather or long grass

	return Vector3(x, y, z)


# The blood trail within send_radius_m of a point (nearest first, at most max_sent), dropping what has dried.
func blood_near(point: Vector3) -> PackedVector3Array:
	var life_ms: int = int(float(cfg.get("blood", {}).get("life_s", 240.0)) * 1000.0)
	var now: int = Time.get_ticks_msec()

	while not blood.is_empty() and now - int(blood[0][1]) > life_ms:
		blood.pop_front()

	var radius: float = float(cfg.get("send_radius_m", 120.0))
	var found: Array = []

	for drop in blood:
		var d: float = Vector2(drop[0].x - point.x, drop[0].z - point.z).length()

		if d <= radius:
			found.append([d, drop[0]])

	found.sort_custom(func(l, r): return l[0] < r[0])
	var out: PackedVector3Array = PackedVector3Array()

	for f in found.slice(0, int(cfg.get("blood", {}).get("max_sent", 80))):
		out.append(f[1])

	return out


# The one damage hook for animals (spears now, traps and others later): returns true when it killed. A hurt animal bolts.
func damage(id: int, amount: float, source_peer: int = -1, _kind: String = "spear") -> bool:
	if not animals.has(id) or amount <= 0.0:
		return false

	var a: Dictionary = animals[id]

	if companions != null and companions.owned_by(a, source_peer):
		return false   # its owner's blow does nothing to their own companion

	# A flock is one record: a hit that lands kills one bird (its carcass lies where it floats), the rest take off.
	if species_def(a["sp"]).has("flock"):
		a["birds"] = int(a.get("birds", 8)) - 1

		if died.is_valid():
			died.call(a["sp"], a["pos"], source_peer)

		if int(a["birds"]) <= 0:
			animals.erase(id)
		elif int(a["state"]) != flocks.TAKEOFF:
			flocks.take_off(a, a["pos"] + Vector3(1.0, 0.0, 0.0))

		return int(a.get("birds", 0)) <= 0

	if not a.has("hp_max"):
		a["hp_max"] = float(a["hp"])   # its full health, set aside at the first hit: the row's health share (hunt_feedback_server.md 2)

	a["hp"] -= amount

	if goblins != null and a.has("lair"):
		goblins.harm(a, source_peer)   # friendship: the band's trust in that player is gone, and it is wary of them

	if a["hp"] <= 0.0:
		animals.erase(id)

		if companions != null and companions.handles(a):
			companions.died(a)   # a companion's record keeps its death; a stray's player can win another

		if a.has("orphan") and wolves != null:
			wolves.orphan_gone(a)   # one orphan fewer at its den

		if a.has("pup_of") and wolves != null:
			wolves.pup_hurt(a, source_peer)   # a pup killed: its pack comes at once

		if a.has("loot") and drop_loot.is_valid():
			drop_loot.call(int(a["loot"][0]), int(a["loot"][1]), a["pos"])

		if a.has("pack") and wolves != null:
			wolves.on_death(id, a["pack"])

		if died.is_valid():
			died.call(a["sp"], a["pos"], source_peer)

		return true

	if a.has("loot") and drop_loot.is_valid():
		drop_loot.call(int(a["loot"][0]), int(a["loot"][1]), a["pos"])   # a hurt thief drops what it stole and runs
		a.erase("loot")

	if a.has("pup_of") and wolves != null:
		wolves.pup_hurt(a, source_peer)   # its pack comes at once

	a["wound"] = true
	a["hurt_by"] = source_peer
	a["drops"] = 0
	a["last_drop"] = a["pos"]
	_drop_blood(a)

	if bandit_camps != null and a.has("camp") and bandit_camps.hurt(a, source_peer):
		return false   # a camp bandit beaten down gives up (BANDIT_CAMPS.md stage 5): he neither fights back nor runs

	# Hurting a young one brings its mother at the hunter, if the hunter is near enough for her to reach.
	if a.has("mother") and animals.has(a["mother"]):
		var m: Dictionary = animals[a["mother"]]
		var reach: float = float(species_def(m["sp"]).get("young", {}).get("between_m", 8.0)) * 2.0

		for info in (big_game.player_info.call() if big_game.player_info.is_valid() else []):
			if int(info["peer"]) == source_peer and Vector2(info["pos"].x - m["pos"].x, info["pos"].z - m["pos"].z).length() <= reach:
				big_game.warn(m, info["pos"], float(species_def(m["sp"])["young"].get("warn_s", 0.6)), true)

	if a.has("pack"):
		wolves.on_hit(a)   # a wolf does not bolt: its pack decides
		return false

	# Wounded big game with the hunter close stands and fights (after a short warning, or at once if it was already warning); a distant
	# hunter it runs from (server_big_game.provoke).
	var defend: Dictionary = species_def(a["sp"]).get("defend", {})

	if not defend.is_empty():
		for info in (big_game.player_info.call() if big_game.player_info.is_valid() else []):
			if int(info["peer"]) == source_peer and Vector2(info["pos"].x - a["pos"].x, info["pos"].z - a["pos"].z).length() <= float(defend.get("provoked_m", 10.0)):
				if big_game.provoke(a, info["pos"], float(defend.get("provoked_warn_s", 0.8))):
					return false

	a["state"] = FLEE
	a["target"] = a["pos"] + Vector3(cos(a["heading"] + PI), 0.0, sin(a["heading"] + PI)) * float(species_def(a["sp"]).get("flee_run_m", 25.0))
	return false


# The animal a jab from `origin` along `dir` reaches: the nearest body (its middle less body_m) within reach and about 35 degrees of the aim; 0 for none.
func target_along(origin: Vector3, dir: Vector3, reach: float, seen_ms: int = -1, present_ms: int = -1) -> int:
	var flat: Vector2 = Vector2(dir.x, dir.z).normalized()
	var best: int = 0
	var best_d: float = reach

	for id in animals:
		if animals[id]["state"] == HIDDEN:
			continue

		var at: Vector3 = pos_at(animals[id], judged_ms(animals[id], seen_ms, present_ms))   # where the player saw it (protocol 155)
		var to: Vector2 = Vector2(at.x - origin.x, at.z - origin.z)
		var body: float = AnimalContact.body_m(str(animals[id]["sp"]))
		var d: float = to.length() - body   # to its body, not its middle: an animal held off a player at body_m + player_m (keep_off_players)
		# stays within reach of the blows (an elephant's middle 2.55 m off, out of a knife's 2.5 m and a punch's 1.8 m: robots 23 Nov 2026)

		if d <= best_d and (to.length() < 0.6 or to.normalized().dot(flat) > 0.82) and absf(at.y - origin.y) < 3.5 and not wall_between(origin, at):
			best_d = d
			best = id

	return best


# Where each animal was lately (protocol 155, docs/design/ANIMAL_NETCODE.md "Fair hits"): [server ms, position] at each move, the place it
# left first (held until `step_ms` before the move: the step's time), for a blow judged at the moment the player saw (pos_at). Kept for rewind_max_ms plus a little; a few entries an animal.
func note_past(a: Dictionary, was: Vector3, step_ms: int = 334) -> void:
	var now: int = int(a.get("moved_ms", Time.get_ticks_msec()))
	var past: Array = a.get("past", [])

	if past.is_empty() or (past[-1][1] as Vector3) != was or now - int(past[-1][0]) > step_ms:   # also after a stand: it was still there until this step began
		past.append([maxi(int(a.get("past_ms", now - 1)), now - step_ms), was])   # where it stood until this move began (`step_ms`, the step's own time)

	past.append([now, a["pos"]])
	a["past_ms"] = now
	var keep_ms: int = int(cfg.get("rewind_max_ms", 500)) + 250

	while past.size() > 2 and int(past[1][0]) < now - keep_ms:
		past.pop_front()

	a["past"] = past


# Where animal `a` was at server time `ms` (a blow from a player who saw it then; protocol 155): between the two moves either side, its
# place now when `ms` is after its last move or unknown (-1), its oldest kept place before that.
func pos_at(a: Dictionary, ms: int) -> Vector3:
	var past: Array = a.get("past", [])

	if ms < 0 or past.is_empty() or ms >= int(past[-1][0]):
		return a["pos"]

	if ms <= int(past[0][0]):
		return past[0][1]

	for i in range(past.size() - 1, 0, -1):
		if int(past[i - 1][0]) <= ms:
			var t0: int = int(past[i - 1][0])
			var t1: int = int(past[i][0])
			return (past[i - 1][1] as Vector3).lerp(past[i][1], float(ms - t0) / float(maxi(t1 - t0, 1)))

	return a["pos"]


# The server moment a blow from a player is judged at (protocol 155, Dave 23 Nov 2026: "battle was almost impossible"): the time the
# player's screen showed the animal (`seen_ms`, the client's row clock: a committed charge is drawn at `present_ms`), never more than
# rewind_max_ms ago, so a laggy or lying client cannot hit an animal that left long since. -1 when the client sent none (judged now).
func judged_ms(a: Dictionary, seen_ms: int, present_ms: int) -> int:
	if seen_ms <= 0:
		return -1

	var now: int = Time.get_ticks_msec()
	var ms: int = present_ms if int(a.get("state", 0)) in [WARN, 11, 12, 16] and present_ms > 0 else seen_ms
	return clampi(ms, now - int(cfg.get("rewind_max_ms", 500)), now)


# How far animal `id` has gone since the moment a blow from (`seen_ms`, `present_ms`) is judged at: a struck point found where the player
# saw it, plus this, is the same spot on the body now (its zone, the floating number and the hit report go there).
func moved_since(id: int, seen_ms: int, present_ms: int) -> Vector3:
	if not animals.has(id):
		return Vector3.ZERO

	return animals[id]["pos"] - pos_at(animals[id], judged_ms(animals[id], seen_ms, present_ms))


# The first animal whose chest sphere the segment from -> to passes through (a flying arrow): {"id", "at"} or {} when none. Hidden animals are skipped.
# `seen_ms` and `present_ms` (judged_ms): each animal is taken where the shooter's screen showed it then; "point" is moved onto the body now.
func target_on_segment(from: Vector3, to: Vector3, radius: float, chest_m: float, seen_ms: int = -1, present_ms: int = -1) -> Dictionary:
	var best: Dictionary = {}
	var best_t: float = INF
	var seg: Vector3 = to - from
	var len2: float = maxf(seg.length_squared(), 0.000001)

	for id in animals:
		if int(animals[id]["state"]) == HIDDEN:
			continue

		var body: Vector3 = pos_at(animals[id], judged_ms(animals[id], seen_ms, present_ms))
		var centre: Vector3 = body + Vector3(0.0, chest_m, 0.0)
		var t: float = clampf((centre - from).dot(seg) / len2, 0.0, 1.0)
		var r: float = float(species_def(str(animals[id]["sp"])).get("hit_radius_m", radius))

		if (from + seg * t).distance_to(centre) <= r and t < best_t:
			best_t = t
			best = {"id": int(id), "at": animals[id]["pos"], "point": from + seg * t + (animals[id]["pos"] - body)}
			best["zone"] = hit_zone(int(id), best["point"])

	return best


# Where on the body a hit at `p` landed (hunt_feedback_server.md 3, MikeW's client rule): 1 head, 2 chest, 3 hip, 4 leg, 0 unknown. The body
# is taken as twice the species' hit radius long.
func hit_zone(id: int, p: Vector3) -> int:
	if not animals.has(id):
		return 0

	var a: Dictionary = animals[id]
	var length: float = 2.0 * float(species_def(str(a["sp"])).get("hit_radius_m", 0.6))
	var fwd: Vector2 = Vector2.from_angle(float(a["heading"]))
	var along: float = clampf(Vector2(p.x - a["pos"].x, p.z - a["pos"].z).dot(fwd) / maxf(length * 0.5, 0.05), -1.0, 1.0)
	var up: float = (p.y - a["pos"].y) / maxf(length * 0.6, 0.05)

	if up < 0.3:
		return 4

	if along > 0.55 and up > 0.5:
		return 1

	return 3 if along < -0.45 else 2


# The point of a jab's aim line (from `origin` along `dir`, within `reach`) nearest the animal's chest centre.
func jab_point(id: int, origin: Vector3, dir: Vector3, reach: float, chest_m: float = 0.5, seen_ms: int = -1, present_ms: int = -1) -> Vector3:
	if not animals.has(id) or dir.length() < 0.001:
		return origin

	var centre: Vector3 = pos_at(animals[id], judged_ms(animals[id], seen_ms, present_ms)) + Vector3(0.0, chest_m, 0.0)
	var n: Vector3 = dir.normalized()
	return origin + n * clampf((centre - origin).dot(n), 0.0, reach)


# A hit landed on animal `id` (alive or just killed, at `at`): every player within hit_send_m of it is told which animal and where on the body.
func report_hit(id: int, zone: int, at: Vector3) -> void:
	if not send_hit.is_valid() or big_game == null or not big_game.player_info.is_valid():
		return

	var reach: float = float(cfg.get("hit_send_m", 60.0))

	for info in big_game.player_info.call():
		if (info["pos"] as Vector3).distance_to(at) <= reach:
			send_hit.call(int(info["peer"]), id, zone, at)


# A loud noise: every animal within `radius` of the point that is not already running bolts away from it.
func alarm_near(point: Vector3, radius: float) -> void:
	var kept: Array = [_wx, _wind_s, _wind_dir, _storm_ahead]   # called between ticks: each bolts by the sky over itself, then the one weather again

	for id in animals:
		var a: Dictionary = animals[id]

		if int(a["state"]) == HIDDEN or int(a["state"]) == FLEE or int(a["state"]) >= WARN or a["pos"].distance_to(point) > radius or a.has("pack"):
			continue

		_weather_for(a["pos"])   # a flushed bird flies by the wind and rain where it sits (server_flight)
		_bolt(a, point, species_def(str(a["sp"])))

	_wx = kept[0]
	_wind_s = kept[1]
	_wind_dir = kept[2]
	_storm_ahead = kept[3]


# One walking step of any animal of this module (Steering.step, the same arguments). Where a dig or fill touches the walker's spot or the half metre ahead, a
# hole's steep rim is a jump down of at most ground_step.drop_m or a scramble up of at most climb_m (data/animals/animals.json, provisional GS-1),
# so no animal is caught in a hole; natural ground keeps Steering's slope rule.
func walk_step(pos: Vector3, target: Vector3, speed: float, dt: float, ground: Callable, blocked_at: Callable, arrive_m: float = 0.4, heading: float = 0.0, cross: Callable = Callable()) -> Dictionary:
	var ahead: Vector2 = Vector2(target.x - pos.x, target.z - pos.z).limit_length(0.5)   # the next half metre: the step itself, never the far goal

	if ground_edited.is_valid() and (bool(ground_edited.call(pos.x, pos.z)) or bool(ground_edited.call(pos.x + ahead.x, pos.z + ahead.y))):
		var gs: Dictionary = cfg.get("ground_step", {})
		return Steering.step(pos, target, speed, dt, ground, blocked_at, arrive_m, heading, cross, float(gs.get("climb_m", 1.0)), float(gs.get("drop_m", 2.0)))

	return Steering.step(pos, target, speed, dt, ground, blocked_at, arrive_m, heading, cross)


# After a step from `was`: an animal that came nearer a player than its contact distance (data/animals/contact.json) is put back on that
# circle round the player, on its own side, so it stops at the player or slides round them, never through (Dave 23 Nov 2026, the real
# server: animals were "jumping right through us"). A step that takes it away is left alone (one already too near walks out). `players`:
# their feet, or the wolves' player infos ({pos}). Cost: one distance per player. Returns whether it was moved.
func keep_off_players(a: Dictionary, was: Vector3, players: Array) -> bool:
	if a.has("fly") or bool(a.get("perched", false)) or bool(a.get("in_cave", false)) or int(a.get("state", 0)) == HIDDEN:
		return false

	var m: float = AnimalContact.contact_m(str(a["sp"]))
	var kept: bool = false

	for p in players:
		var at: Vector3 = Vector3.INF

		if p is Vector3:
			at = p
		else:
			at = (p as Dictionary)["pos"]

		var now_d: float = Vector2(a["pos"].x - at.x, a["pos"].z - at.z).length()

		if now_d < m and now_d < Vector2(was.x - at.x, was.z - at.z).length():
			# A long step (a charge, a server that stepped late) can carry it across the player's middle: put on the circle on the far side
			# it went through them. It stops where it came to them instead (gate review of #1716).
			if absf(a["pos"].y - at.y) <= 2.0 and Vector2(a["pos"].x - at.x, a["pos"].z - at.z).dot(Vector2(was.x - at.x, was.z - at.z)) < 0.0:      # not under one on a ledge (keep_off leaves those too)
				a["pos"] = AnimalContact.stop_at(at, was, a["pos"], m)
			else:
				a["pos"] = AnimalContact.keep_off(a["pos"], at, m, was)

			kept = true

	# One player at a time can push it out of one body into another standing beside them (robot bear hunt 23 Nov 2026: two hunters 1.4 m
	# apart, a charging bear put on the second one's circle, inside the first, 0.22 m from their middle): ending inside anyone and nearer them
	# than it was, it stays where it was.
	if kept and (_deeper_in(a["pos"], was, players, m) or wall_between(was, a["pos"])):
		a["pos"] = was   # nor put out through a wall or a shut door behind it

	if kept and Vector2(a["pos"].x - was.x, a["pos"].z - was.z).length() < 0.05:
		a["pos"] = was   # held at the player: it stands there, not a few centimetres to and fro

	return kept


# Whether `to` is inside one of `players` (closer than `m` on the ground, within 2 m up or down) and nearer them than `from` was.
static func _deeper_in(to: Vector3, from: Vector3, players: Array, m: float) -> bool:
	for p in players:
		var at: Vector3 = Vector3.INF

		if p is Vector3:
			at = p
		else:
			at = (p as Dictionary)["pos"]

		var d: float = Vector2(to.x - at.x, to.z - at.z).length()

		if d < m - 0.01 and d < Vector2(from.x - at.x, from.z - at.z).length() - 0.01 and absf(to.y - at.y) <= 2.0:
			return true

	return false


# An animal a player at `at` has walked or run into steps out of their body at up to half its flee speed (its walking pace at least; a
# goblin or bandit, defend give_way "player", at the player's pace), `dt` s of it, away from them; not into ground it cannot walk on. Birds
# in the air or on a perch, animals in a burrow or cave, a bandit camp's tied horses and a bandit who gave up stay. True when it moved.
func make_way(a: Dictionary, at: Vector3, dt: float, others: Array = []) -> bool:
	if at == Vector3.INF or a.has("fly") or (a.has("camp") and (a.has("gave_up") or str(species_def(str(a["sp"])).get("defend", {}).get("give_way", "")) != "player")) or bool(a.get("perched", false)) or bool(a.get("in_cave", false)) or int(a.get("state", 0)) == HIDDEN:
		return false

	# Big game warning, charging or recovering is stepped out too (Lane B 23 Nov 2026: a deer that warned at a player it stood inside struck
	# from inside them and stayed there): it is then on the contact circle, where a charge's stop_at holds it, so it does not flap.

	var def: Dictionary = species_def(str(a["sp"]))

	if swims(def):
		return false   # a swimmer in the water keeps its line (its height is the water's)

	var out: Vector3 = AnimalContact.keep_off(a["pos"], at, AnimalContact.contact_m(str(a["sp"])))
	# At up to half its flee speed (robots 23 Nov 2026: a dog a running player chased stayed 0.1 to 0.3 m inside them for 0.66 s at walking pace).
	var pace_mps: float = maxf(float(def.get("walk_mps", 1.5)), 0.5 * float(def.get("flee_mps", 0.0)))

	# A fighter (defend give_way "player": goblins and bandits) gives way as fast as the player pushes, a little more, and out of where the
	# player will be by its next step, not where they are (robots 23 Nov 2026: a goblin 0.21 to 0.25 m inside a player who walked into it
	# to strike, giving way at 2.75 m/s against the player's 5, one step every tenth of a second).
	if str(def.get("defend", {}).get("give_way", "")) == "player":
		var push: Vector2 = player_velocity_at(at)
		pace_mps = maxf(pace_mps, push.length() + 1.0)
		out = AnimalContact.keep_off(a["pos"], at + Vector3(push.x, 0.0, push.y) * dt, AnimalContact.contact_m(str(a["sp"])))
	var step: Vector3 = Vector3(out.x - a["pos"].x, 0.0, out.z - a["pos"].z).limit_length(pace_mps * dt)

	if step.length() < 0.01 or (blocked.is_valid() and bool(blocked.call(a["pos"].x + step.x, a["pos"].z + step.z))):
		return false

	var to: Vector3 = a["pos"] + step

	if ground_height.is_valid():
		to.y = float(ground_height.call(to.x, to.z))

	if _deeper_in(to, a["pos"], others, AnimalContact.contact_m(str(a["sp"]))):
		return false   # not out of one player into another beside them (`others`: every player's feet or infos)

	if wall_between(a["pos"], to):
		return false   # not through a wall or a shut door: a player who pins it against one does not push it out the other side

	a["pos"] = to   # its sent heading stays; the client draws it facing the way it steps while it steps. Tick stamps it moving (moved_ms) as for any step
	return true


# A dig or fill changed the ground round `centre` (terrain_server _dig_ground / _fill_ground): every animal standing there comes to rest on
# the ground as it is now, so one dug out from under drops and one buried under a fill climbs onto it (Dave 19 Nov 2026 play test). Animals in
# the air, on a perch, in a burrow, in a cave or on water keep their height. Cost: one pass over the animals and a ground read for each one there.
func ground_changed(centre: Vector3, radius: float) -> void:
	if not ground_height.is_valid():
		return

	for id in animals:
		var a: Dictionary = animals[id]
		var p: Vector3 = a["pos"]

		if Vector2(p.x - centre.x, p.z - centre.z).length() > radius + 1.0:
			continue

		if a["state"] == HIDDEN or a.has("fly") or bool(a.get("perched", false)) or bool(a.get("in_cave", false)):
			continue

		if in_water(species_def(str(a["sp"])), p):
			continue   # on or in water (a swimmer, a flock resting on a lake, an animal on ice): the water holds it, not the bed

		var y: float = float(ground_height.call(p.x, p.z))

		if not is_nan(y) and absf(y - p.y) > 0.05:
			a["pos"] = Vector3(p.x, y, p.z)


# The animals a snare can reach: [{id, sp, pos}] within radius of the point (flat distance), burrowed ones left out.
func list_near(point: Vector3, radius: float) -> Array:
	var out: Array = []

	for id in animals:
		var a: Dictionary = animals[id]

		if int(a["state"]) != HIDDEN and Vector2(a["pos"].x - point.x, a["pos"].z - point.z).length() <= radius:
			out.append({"id": id, "sp": str(a["sp"]), "pos": a["pos"]})

	return out


# A snare draws the animal (its run, or bait): a calm one moves its home to the point and hops there. Its burrow stays where it was.
func lure_to(id: int, point: Vector3) -> bool:
	if not animals.has(id):
		return false

	var a: Dictionary = animals[id]

	if int(a["state"]) != GRAZE and int(a["state"]) != HOP:
		return false

	a["home"] = point
	a["target"] = point
	a["state"] = HOP
	a.erase("trip")

	if a.has("place"):
		a["lured"] = wants_out(a)   # it stays at the snare until its clock turns (then it goes home or out as usual)

	return true


# A snare closes on the animal: it leaves the world without a death (the snare module lays the carcass). One bird of a flock goes.
func snare(id: int) -> bool:
	if not animals.has(id):
		return false

	var a: Dictionary = animals[id]

	if a.has("companion_id") or a.has("pup_of") or a.has("orphan"):
		return false   # a companion or a pup at a den steps over snares

	if species_def(str(a["sp"])).has("flock"):
		a["birds"] = int(a.get("birds", 8)) - 1

		if int(a["birds"]) > 0:
			return true

	animals.erase(id)

	if trails != null:
		trails.forget(id)

	return true


# The starter island's level at a point, 0 to 1 (Dave 6 Nov 2026: low-level content near the starter town, rising as a gradient to
# medium on the far side; DESIGN_IDEAS 4.13). 0 within island_level.town_m of the town point (the middle of the town's NPC markers,
# docs/design/no_spawn_placement_design.md 3), 1 at far_m (about the far coast of tile 3,4) and beyond; 0 everywhere with no town. Off the
# starter island the world danger map is to take over (not built: one starter island for now).
func island_level(x: float, z: float) -> float:
	if town.x == INF:
		return 0.0

	var il: Dictionary = cfg.get("island_level", {})
	var centre: Vector2 = town
	var near_m: float = float(il.get("town_m", 800.0))
	var far_m: float = maxf(float(il.get("far_m", 8000.0)), near_m + 1.0)
	return clampf((Vector2(x, z).distance_to(centre) - near_m) / (far_m - near_m), 0.0, 1.0)


# An animal's level at a point (Dave 6 Nov 2026: every animal, creature and NPC has a level; near the starter town about 1 to 5, half way
# across 5 to 10, the far side 10 to 20). The span blends from island_level.levels.town through middle to far with the island level.
func level_span(x: float, z: float) -> Vector2i:
	var lv: Dictionary = cfg.get("island_level", {}).get("levels", {})
	var t: float = island_level(x, z)
	var lo: Array = lv.get("town", [1, 5]) if t < 0.5 else lv.get("middle", [5, 10])
	var hi: Array = lv.get("middle", [5, 10]) if t < 0.5 else lv.get("far", [10, 20])
	var u: float = t * 2.0 if t < 0.5 else (t - 0.5) * 2.0
	return Vector2i(roundi(lerpf(float(lo[0]), float(hi[0]), u)), roundi(lerpf(float(lo[1]), float(hi[1]), u)))


# How much stronger an animal is for its level: 1 at level 1, plus island_level.levels.<what>_per_level for each level above ("hp" or
# "damage"). Animals born without a level (traits off) are level 1.
func level_x(a: Dictionary, what: String) -> float:
	var per: float = float(cfg.get("island_level", {}).get("levels", {}).get("%s_per_level" % what, 0.0))
	return 1.0 + per * float(maxi(int(a.get("level", 1)) - 1, 0))


func _graze_time(def: Dictionary) -> float:
	var span: Array = def.get("graze_s", [3.0, 10.0])
	return rng.randf_range(float(span[0]), float(span[1]))   # luck-exempt: how long an animal grazes


func tick(delta: float) -> void:
	var players: Array = player_positions.call() if player_positions.is_valid() else []
	var active_r: float = float(cfg.get("active_radius_m", 200.0))
	var near_m: float = float(cfg.get("near_m", 60.0))
	var mid_m: float = float(cfg.get("mid_m", 120.0))
	var despawn_m: float = float(cfg.get("despawn_m", 300.0))
	var budget_us: int = int(float(cfg.get("tick_budget_ms", 1.0)) * 1000.0)
	var started: int = Time.get_ticks_usec()
	var gone: Array = []
	_tick_no += 1
	var ids: Array = animals.keys()
	var count: int = ids.size()
	var stances: Array = player_stances.call() if player_stances.is_valid() else []
	var weather: Dictionary = wind.call() if wind.is_valid() else {}
	_wind_s = float(weather.get("wind", 0.0))
	_wind_dir = Vector2.from_angle(float(weather.get("wind_dir", 0.0)))
	_read_weather(weather, delta)
	var wx_all: Dictionary = _wx
	var wind_all: float = _wind_s
	var dir_all: Vector2 = _wind_dir
	var storm_all: bool = _storm_ahead
	_fog_ground_tick(players)
	_thunder_tick(players)
	_wx = wx_all   # the thunder's flushed birds took the sky over themselves (_weather_for): the one weather until the animals' steps
	_wind_s = wind_all
	_wind_dir = dir_all
	_storm_ahead = storm_all
	_dogs = _dog_presences()
	_sample_noise(players, delta)
	_fire_cache = []

	for at in (fires.call() if fires.is_valid() else []):
		_fire_cache.append([at, float(fire_radius.call(at)) if fire_radius.is_valid() else 10.0])

	# A quarter of the animals per tick (id mod 4), each one's elapsed time kept in acc so its step still gets the true dt; if the
	# tick's AI budget runs out the rest wait for the next one (the rotating start keeps that fair).
	for k in count:
		var id: int = int(ids[(k + _tick_no * 7) % count])
		var a: Dictionary = animals[id]
		a["acc"] += delta

		if (id + _tick_no) % STAGGER != 0:
			continue

		if k > 0 and Time.get_ticks_usec() - started > budget_us:
			continue   # out of budget: this one waits (its acc keeps growing, so its next step is longer, not lost)

		_weather_for(a["pos"])   # its own sky: what it senses and does by (rain, snow, wind, fog, cold) is the weather where it stands

		var near_d: float = INF
		var near_p: Vector3 = Vector3.INF
		var seen_d: float = INF   # the distance as the animal perceives it: wind, stance and cover stretch or shrink it
		var seen_p: Vector3 = Vector3.INF
		var def_s: Dictionary = species_def(a["sp"])
		var reach_m: float = maxf(float(def_s.get("alert_m", 0.0)), float(def_s.get("spook_m", 14.0))) * float(cfg.get("senses", {}).get("far_factor", 1.5))

		for pi in players.size():
			var p: Vector3 = players[pi]
			var d: float = Vector2(p.x - a["pos"].x, p.z - a["pos"].z).length()

			if d < near_d:
				near_d = d
				near_p = p

			if d <= reach_m:
				var sensed: float = d / _sense_factor(a, def_s, p, d, int(stances[pi]) if pi < stances.size() else 0, float(_noisy[pi]) if pi < _noisy.size() else 1.0, float(_heard[pi]) if pi < _heard.size() else 0.0)

				if sensed < seen_d:
					seen_d = sensed
					seen_p = p

		if seen_p == Vector3.INF:
			seen_d = near_d
			seen_p = near_p

		if near_d > despawn_m and not (bandit_camps != null and a.has("camp") and bandit_camps.is_held(a)):   # a captive waits for his parked captor
			gone.append(id)
			continue

		# A companion stays with its owner (server_companions), and the animal an admin watches through the spyglass keeps living: never
		# frozen, never sent off for the hour.
		var kept: bool = a.has("companion_id") or watched.has(id) or a.has("camp")   # a bandit camp's people and horses keep the camp's hours

		# An animal whose hours are over (a songbird at night, a boar at noon: its activity chance is at most off_hours_chance) leaves once no player is close to it.
		if not kept and near_d > float(cfg.get("off_hours_despawn_m", 80.0)) and hour_now.is_valid() and activity_chance(species_def(str(a["sp"]))) <= float(cfg.get("off_hours_chance", 0.05)):
			gone.append(id)
			continue

		if near_d > active_r and not kept:
			a["acc"] = 0.0
			a["moving"] = false   # standing while frozen: rows_near (the spyglass sends out to 300 m) stamps it with the send time
			continue   # frozen: nothing runs until a player comes within active_radius_m

		if a.has("pack"):
			a["acc"] = 0.0
			continue   # the pack brain moves wolves (tick below)

		var hz: float = float(cfg.get("hz_near", 10.0)) if near_d <= near_m else (float(cfg.get("hz_mid", 3.0)) if near_d <= mid_m else float(cfg.get("hz_far", 0.5)))

		if watched.has(id):
			hz = maxf(hz, float(cfg.get("hz_mid", 3.0)))   # watched through the spyglass: smooth enough to follow

		if a["acc"] < 1.0 / hz:
			continue

		var dt: float = minf(a["acc"], 1.0)
		a["acc"] = 0.0
		var was: Vector3 = a["pos"]
		_step(a, dt, near_d, near_p, seen_d, seen_p)

		if animals.has(id) and a["pos"] != was:
			keep_off_players(a, was, players)   # never into a player's body (Dave 23 Nov 2026: "jumping right through us")

			if near_p != Vector3.INF and Vector2(a["pos"].x - near_p.x, a["pos"].z - near_p.z).length() < AnimalContact.contact_m(str(a["sp"])) - 0.01:
				make_way(a, near_p, dt, players)   # a grazer's small step a player ran into is kept by keep_off: it still steps out of them (gate review of #1670)
		elif animals.has(id) and near_d < AnimalContact.contact_m(str(a["sp"])):
			make_way(a, near_p, dt, players)   # a player walked into it standing: it steps aside (robot play-testers 23 Nov 2026: a dog 0.02 m from a player)

		if animals.has(id) and a["pos"] != was:
			a["moved_ms"] = Time.get_ticks_msec()   # when it got here, sent with its row (rows_near) so the client draws it on the server's timeline
			a["moving"] = true
			note_past(a, was, int(dt * 1000.0))
		else:
			a["moving"] = false   # standing: rows_near stamps its row with the send time

		if trails != null and int(a.get("state", 0)) != HIDDEN and not bool(a.get("in_cave", false)) and not a.has("fly") and not bool(a.get("perched", false)):
			trails.note(id, str(a["sp"]), a["pos"])

		# Last, as it may take the animal out of the world: a set trap it walked up to (Dave 22 Nov 2026: traps cost nothing until an animal comes by).
		if snare_pass.is_valid() and animals.has(id) and a["pos"] != was and int(a.get("state", 0)) != HIDDEN and not bool(a.get("in_cave", false)) and not a.has("fly") and not bool(a.get("perched", false)):
			snare_pass.call(id, str(a["sp"]), was, a["pos"])

	_wx = wx_all   # the one weather again after the animals' own steps
	_wind_s = wind_all
	_wind_dir = dir_all
	_storm_ahead = storm_all

	for id in gone:
		if trails != null:
			trails.forget(id)

		if companions != null and companions.handles(animals[id]):
			companions.forget(animals[id])   # its record stays; a live one is made again beside its owner

		if animals[id].has("loot") and goblins != null and species_def(str(animals[id]["sp"])).has("den_life"):
			goblins.stash(animals[id])   # a goblin dropped with no player near is taken to have got home: its loot goes on the den pile

		if animals[id].has("pack") and wolves != null and wolves.packs.has(animals[id]["pack"]):
			wolves.packs[animals[id]["pack"]]["ids"].erase(id)

		animals.erase(id)

	if goblins != null:
		goblins.trust.tick(delta)

	if companions != null:
		companions.tick(delta)

	if wolves != null:   # wild packs are always on, so the wolves always tick (they place packs round the players)
		wolves.tick(delta)   # each pack by the weather at its centre (server_wolves._think)

	_spawn_acc += delta

	# One player's share is looked at per pass, so with 20 players each is still topped up every spawn_every_s but never in one tick.
	if not players.is_empty() and _spawn_acc >= float(cfg.get("spawn_every_s", 2.0)) / float(players.size()):
		_spawn_acc = 0.0
		_top_idx = (_top_idx + 1) % players.size()
		_weather_for(players[_top_idx])   # who turns up round a player (wind, storm) by the sky over that player
		_top_up(players, _top_idx)

	_wx = wx_all   # the one weather again for what reads it between ticks (alarms, hits)
	_wind_s = wind_all
	_wind_dir = dir_all
	_storm_ahead = storm_all


# How close a player may come before this animal runs: the species' spook_m, scaled by a horse's own tame value (a flighty one
# runs from far off, a friendly one lets you close).
func _spook_m(a: Dictionary, def: Dictionary) -> float:
	var spook: float = float(def["flight"].get("flush_m", def.get("spook_m", 14.0))) if str(def.get("flight", {}).get("kind", "")) == "flush" else float(def.get("spook_m", 14.0))   # a flusher sits tight
	var base: float = spook * (float(cfg.get("rest", {}).get("spook_share", 0.6)) if resting(def) else 1.0)

	if def.has("tame") and a.has("tame"):
		var scale: Array = def["tame"].get("spook_scale", [1.0, 1.0])
		var run_at: float = base * lerpf(float(scale[0]), float(scale[1]), float(a["tame"]))

		if float(a["tame"]) >= float(def["tame"].get("curious_min", 0.7)):
			run_at = minf(run_at, float(def["tame"].get("stop_m", 9.0)) * 0.6)   # a curious horse only shies when you are right on it

		base = run_at

	# Temperament, season and young: a neutral or aggressive animal does not run (0), a mother with young runs sooner.
	base *= float(_temper_row(a).get("spook_x", 1.0)) * float(_season_row(def).get("spook_x", 1.0)) * weather_spook_x(def)

	if def.has("young") and not _young_of(a).is_empty():
		base *= float(def["young"].get("spook_x", 1.4))

	return base


# A friendly horse (tame value at curious_min or more) is not wary of a player within curious_m: it watches and ambles over.
# A friendly-tempered animal is curious the same way, within its temperament's curious_m.
func _curious(a: Dictionary, def: Dictionary, seen_d: float) -> bool:
	if temper_of(a) == "friendly":
		return seen_d <= float(_temper_row(a).get("curious_m", 25.0))

	return def.has("tame") and float(a.get("tame", 0.0)) >= float(def["tame"].get("curious_min", 0.7)) and seen_d <= float(def["tame"].get("curious_m", 45.0))


# Whether a hunter that may attack (its temperament; never a passive or friendly one) sees a player inside hunter.chase_m running away
# from it at senses.run_ms or faster (Dave 21 Nov 2026, docs/design/ANIMAL_BEHAVIOUR.md: a big cat or a bear chases what runs).
func _chases_runner(a: Dictionary, def: Dictionary, seen_p: Vector3, seen_d: float) -> bool:
	if seen_d > float(def["hunter"].get("chase_m", 0.0)) or not may_attack(a):
		return false

	var away: Vector2 = Vector2(seen_p.x - a["pos"].x, seen_p.z - a["pos"].z).normalized()
	return player_velocity_at(seen_p).dot(away) >= float(cfg.get("senses", {}).get("run_ms", 5.0))


# How far short of a player a curious animal stops.
func _stop_m(a: Dictionary, def: Dictionary) -> float:
	if temper_of(a) == "friendly":
		return float(_temper_row(a).get("stop_m", 5.0))

	return float(def.get("tame", {}).get("stop_m", 9.0))


func _step(a: Dictionary, dt: float, near_d: float, near_p: Vector3, seen_d: float, seen_p: Vector3) -> void:
	ticks_run += 1
	var def: Dictionary = species_def(a["sp"])

	if def.has("flock"):
		flocks.step(a, dt, seen_d, seen_p)
		return

	if flight != null and flight.handles(a):
		flight.step(a, dt, seen_d, seen_p)   # in the air, or sitting on a perch (bird_flight_server_design.md)
		return

	if def.has("thief") and thieves.handles(a):
		thieves.step(a, dt)
		return

	if a.has("pup_of") and wolves != null:
		wolves.step_pup(a, dt)   # a wolf pup at its pack's den: plays, hides from a standing player (wolf_packs_and_pups_design.md)
		return

	if companions != null and companions.handles(a):
		companions.step(a, dt)   # a stray near the town, an orphan pup, or a player's companion: its own step (no wild fear, defence or bleeding)
		return

	# Den life (goblins): in the cave it moves only along the cave path, warnings included; at night on the surface it may watch a fire or forage.
	if def.has("den_life") and goblins != null:
		if bool(a.get("in_cave", false)) and bleed(a, dt):
			return

		if goblins.step(a, dt, seen_d, seen_p):
			return

	if def.has("defend"):
		big_game.cool_down(a, dt)

		if big_game.handles(a):
			big_game.step(a, dt)
			return

	if bandit_camps != null and a.has("camp") and bandit_camps.step(a, dt):
		return

	if bleed(a, dt):
		return

	if a["state"] == HIDDEN:
		a["timer"] -= dt

		if a["timer"] <= 0.0:
			if seen_d > _spook_m(a, def) * 1.5:
				a["state"] = GRAZE
				a["timer"] = _graze_time(def)
			else:
				a["timer"] = 3.0   # a player is still close to the burrow: stay down a little longer

		return

	if a.has("mother"):
		if animals.has(a["mother"]):
			_step_young(a, dt)
			return

		a.erase("mother")   # orphaned: from now on an ordinary (passive) animal

	if a["alarm"] >= 0.0:
		a["alarm"] -= dt

		if a["alarm"] < 0.0 and a["state"] != FLEE:
			a["alarm"] = -1.0
			_bolt(a, near_p, def)

			if a.has("fly"):
				return   # alarmed into the air

	# A player who has come between a mother and her young (near one of them) is attacked at once, torch or not.
	if def.has("defend") and def.has("young") and seen_p != Vector3.INF:
		for kid in _young_of(a):
			if Vector2(seen_p.x - animals[kid]["pos"].x, seen_p.z - animals[kid]["pos"].z).length() <= float(def["young"].get("between_m", 8.0)):
				if big_game.warn(a, seen_p, float(def["young"].get("warn_s", 0.6)), true):
					return

				break

	# Fire (Dave 6 Nov 2026): wild animals keep away from a burning fire or a torch bearer, out of its keep-off radius (the wolves' rule),
	# unless trapped; a bear at its den does not give way to a torch.
	var in_den: bool = _in_den(a, def)
	var fire_at: Vector3 = Vector3.INF if in_den or a.has("pack") else _fire_guard(a["pos"])

	if fire_at != Vector3.INF and a["state"] != FLEE:
		_bolt(a, fire_at, def)
		return

	# A player's dog (dog_companion_design.md 11, MikeW's DOG_REACTIONS.md): prey flee it from farther than from a walking player, big game stands to it.
	if def.has("dog") and _dog_react(a, def, seen_d):   # at its den too: a bear stands to a dog there
		return

	# Threat range (Dave 6 Nov 2026, for most animals): a player inside spook_m makes an animal want to run; a player who gets inside its
	# threat_m (a surprise up close, a chase that catches it, a walk into its den) makes it feel threatened, and it attacks: a short warning,
	# then the dodgeable charge (server_big_game.gd). A player standing in a fire's or a torch's keep-off radius is left alone, except at
	# the den. The distance is the one the animal perceives, so a hunter who sneaks up unnoticed is not charged until it notices.
	if def.has("defend") and seen_p != Vector3.INF and seen_d <= _threat_m(a, def) and (in_den or _fire_guard(seen_p) == Vector3.INF):
		if big_game.warn(a, seen_p, float(def["defend"].get("threat_warn_s", 0.8))):
			return

	# Hunters (docs/design/ANIMAL_BEHAVIOUR.md; Dave 21 Nov 2026: "Agressive animals should be aggressive"): a predator that may attack
	# gives chase to a player running away from it inside hunter.chase_m (running "may trigger an instinct to chase", Panthera): a charge
	# at once, up to hunter.run_m. One born aggressive walks in on a player it has noticed until the threat range above warns and charges;
	# it breaks off while it cools down after a charge. Never into a fire's light, never out of its hours.
	var stalk_mps: float = -1.0

	if def.has("hunter") and def.has("defend") and seen_p != Vector3.INF and a["state"] != FLEE and not resting(def) and _fire_guard(seen_p) == Vector3.INF:
		if _chases_runner(a, def, seen_p, seen_d) and big_game.chase(a, seen_p, float(def["hunter"].get("run_m", 30.0))):
			return

		if bool(_temper_row(a).get("stalks", false)) and float(a.get("cool", 0.0)) <= 0.0 and seen_d <= float(def.get("alert_m", 40.0)) and seen_d > _threat_m(a, def):
			var gap: Vector3 = Vector3(seen_p.x - a["pos"].x, 0.0, seen_p.z - a["pos"].z)
			a["target"] = a["pos"] + gap.normalized() * maxf(gap.length() - _threat_m(a, def) * 0.5, 0.0)
			a["state"] = HOP
			stalk_mps = float(def["hunter"].get("stalk_mps", 1.0))

	# A protective animal (defending young) does not bolt: it warns a player who comes too close, and only then charges.
	# With its young modelled (traits on) it runs sooner instead, and fights only for them (above).
	var stands: bool = def.has("defend") and bool(a.get("protective", false)) and a["state"] != FLEE and not (traits and def.has("young"))

	if stands and seen_d <= float(def["defend"].get("warn_m", 20.0)):
		if big_game.warn(a, seen_p):
			return
	elif seen_d <= _spook_m(a, def) and a["state"] != FLEE and not stands:
		_bolt(a, seen_p, def)

		# The sentinel (the first to notice) alarms the herd: each mate follows after a short random moment.
		_alarm_herd(a, def)

	if a.has("fly"):
		return   # it took off: the flight moves it from the next step (server_flight.gd)

	var alert_m: float = float(def.get("alert_m", 0.0)) * weather_spook_x(def)

	if a["state"] == ALERT:
		a["alert"] -= dt

		if seen_d <= _spook_m(a, def):
			_bolt(a, seen_p, def)
		elif a["alert"] <= 0.0 or seen_d > alert_m * 1.3:
			a["state"] = GRAZE
			a["timer"] = _graze_time(def)

		return

	if a["state"] != FLEE and alert_m > 0.0 and seen_d <= alert_m and a["alert"] <= 0.0 and not _curious(a, def, seen_d) and seen_d > _spook_m(a, def) and bool(_temper_row(a).get("alert", true)):
		var span2: Array = def.get("alert_s", [1.0, 2.0])
		a["state"] = ALERT
		a["alert"] = rng.randf_range(float(span2[0]), float(span2[1]))   # luck-exempt: how long an animal watches
		a["heading"] = atan2(seen_p.z - a["pos"].z, seen_p.x - a["pos"].x)
		return

	if a["state"] == GRAZE and seen_d > alert_m:
		a["alert"] = 0.0   # it forgets once the player is well away

	if a["state"] == GRAZE:
		if def.has("thief") and thieves.try_sneak(a, dt):
			return

		a["timer"] -= dt
		_weather_graze(a, def, dt)

		if a["herd"] != 0 and float(def.get("herd_pull_m", 0.0)) > 0.0 and not a.has("place"):   # a herd with a place keeps together at its spots
			var centre: Vector3 = _herd_centre(a["herd"])

			if centre != Vector3.INF and not a.has("drink_home") and a["home"].distance_to(centre) > float(def.get("herd_pull_m", 12.0)) * fog_herd_x(def):
				a["home"] = a["home"].lerp(centre, 0.5)

		if a["timer"] <= 0.0 and routine_trip(a):
			return   # its clock says it is time to go home or out: it walks the trail

		if a["timer"] <= 0.0 and resting(def):
			a["timer"] = _graze_time(def) * float(cfg.get("rest", {}).get("graze_x", 3.0))   # out of its hours it beds down: stays put, longer
			return

		if a["timer"] <= 0.0 and _wind_goes_down(a, def):
			return

		if a["timer"] <= 0.0 and _weather_wander(a, def):
			return

		if a["timer"] <= 0.0 and _drink_wander(a, def):
			return

		if a["timer"] <= 0.0:
			var wander: float = float(def.get("wander_m", 6.0)) * weather_wander_x(def, str(a["sp"]))
			var angle: float = rng.randf() * TAU   # luck-exempt: where a grazing animal hops next
			angle = _upwind_angle(def, angle)
			a["target"] = a["home"] + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(1.0, wander)   # luck-exempt: as above

			if fog_edge_wanted(def):
				for _try in int(_fog_cfg().get("edge_tries", 3)) - 1:
					if fog_edge_ok(a["target"]):
						break

					var again: float = _upwind_angle(def, rng.randf() * TAU)   # luck-exempt: another try along the wood edge in fog
					a["target"] = a["home"] + Vector3(cos(again), 0.0, sin(again)) * rng.randf_range(1.0, wander)   # luck-exempt: as above

			if a["herd"] != 0 and _groups_on():
				a["target"] = _group_target(a, def)   # herd groups: the leader drifts, the rest keep their place round it

			if a.has("den"):
				a["target"] = _den_target(a, def)

			if _fire_guard(a["target"]) != Vector3.INF and not _in_den(a, def, a["target"]):
				a["target"] = a["pos"]   # never wanders into a fire's light

			# A friendly horse is curious: it ambles toward a player it can see until it is stop_m away.
			if _curious(a, def, seen_d) and seen_d > _stop_m(a, def):
				var toward: Vector3 = Vector3(seen_p.x - a["pos"].x, 0.0, seen_p.z - a["pos"].z).normalized()
				a["target"] = a["pos"] + toward * minf(wander, seen_d - _stop_m(a, def))
				a["home"] = a["target"]

			a["state"] = HOP

		return

	var speed: float = float(def.get("walk_mps", 1.5))

	if stalk_mps > 0.0:
		speed = stalk_mps   # a hunter walking in on a player, low and steady

	if a["state"] == FLEE:
		# Sprint for burst_s seconds, then trot: an animal cannot outrun a chase for ever.
		a["burst"] += dt
		speed = float(def.get("flee_mps", 7.5)) * (1.0 if a["burst"] <= float(def.get("burst_s", 3.0)) else float(def.get("trot_share", 0.5)))
	var ground_for: Callable = ground_height
	var blocked_for: Callable = blocked

	if ice_on():   # animals on ice (animals_on_ice_server.md): deer and boar keep off it, wolves cross a sheet that bears
		var moves: Array = ice_moves(def, str(a["sp"]))
		ground_for = moves[0]
		blocked_for = moves[1]

	if swims(def):
		# A swimmer goes into deep water (nothing blocks it) and rides the surface there; in water it moves at swim_mps.
		ground_for = func(x: float, z: float) -> float: return swim_height(def, x, z)
		blocked_for = Callable()

		if in_water(def, a["pos"]):
			speed = float(def["water"].get("swim_mps", speed)) * (1.0 if a["state"] == FLEE else 0.4)      # cruising slowly, bolting at full speed

	if a["state"] == HOP and a.has("trip"):
		_trip_ahead(a)   # on a trail: the next point before this one is reached, so it never stops between points

	var r: Dictionary = walk_step(a["pos"], a["target"], speed, dt, ground_for, blocked_for, 0.4, a["heading"], crossing)

	if r["moved"]:
		a["pos"] = r["pos"]
		a["heading"] = r["heading"]

		if a.get("wound", false) and a["pos"].distance_to(a["last_drop"]) >= float(cfg.get("blood", {}).get("every_m", 2.5)):
			_drop_blood(a)

	if (a["state"] == FLEE or a["state"] == HOP) and a["to_burrow"] and (r["arrived"] or not r["moved"]):
		a["to_burrow"] = false

		if r["arrived"]:
			var hide: Array = def.get("hide_s", [20.0, 40.0])
			a["state"] = HIDDEN
			a["pos"] = a["burrow"]
			a["timer"] = rng.randf_range(float(hide[0]), float(hide[1]))   # luck-exempt: how long an animal stays in its burrow
			return

	if a["state"] == HOP and a.has("trip") and _trip_step(a, r):
		return

	if r["arrived"] or not r["moved"]:
		if a["state"] == FLEE and near_d < float(def.get("safe_m", 35.0)):
			# Big game cornered (it cannot get away and the player is right there) stands and fights: warn first, always.
			if def.has("defend") and not r["moved"] and near_d <= float(def["defend"].get("corner_m", 7.0)) and big_game.warn(a, near_p, float(def["defend"].get("corner_warn_s", 1.2))):
				return

			# Still too close: keep running away from the player.
			var away: Vector2 = Vector2(a["pos"].x - near_p.x, a["pos"].z - near_p.z).normalized()

			if not r["moved"]:
				away = away.rotated(rng.randf_range(-1.2, 1.2))   # luck-exempt: which way a cornered animal breaks

			a["target"] = a["pos"] + _zig(away, def) * float(def.get("zig_leg_m", float(def.get("flee_run_m", 25.0))))
			_to_burrow(a, away, def)
			return

		if a["state"] == FLEE:
			a["home"] = a["pos"]

		a["state"] = GRAZE
		a["timer"] = _graze_time(def)


# A wounded animal bleeds: it runs, rests and finally dies where it stands, at the end of its trail. True when it died.
func bleed(a: Dictionary, dt: float) -> bool:
	if not a.get("wound", false):
		return false

	a["hp"] -= float(cfg.get("blood", {}).get("bleed_hp_per_s", 0.0)) * dt

	if a["hp"] > 0.0:
		return false

	animals.erase(a["id"])

	if a.has("loot") and drop_loot.is_valid():
		drop_loot.call(int(a["loot"][0]), int(a["loot"][1]), a["pos"])   # what it carried falls where it died

	if a.has("pack") and wolves != null:
		wolves.on_death(int(a["id"]), a["pack"])

	if died.is_valid():
		died.call(a["sp"], a["pos"], a.get("hurt_by", -1))

	return true


# Alarm groups (ANIMAL_SPEC.md, 8 Nov 2026): a bolting animal flushes every animal of its alarm_group within alarm_group_m, of any species or
# herd, each after its own alarm_s moment (a crow taking off sends the pheasants and grouse beside it up too).
func _alarm_group(a: Dictionary, def: Dictionary) -> void:
	var group: String = str(def["alarm_group"])
	var reach: float = float(def.get("alarm_group_m", 15.0))

	for id in animals:
		var o: Dictionary = animals[id]

		if id == a["id"] or int(o["state"]) == FLEE or int(o["state"]) == HIDDEN or float(o["alarm"]) >= 0.0:
			continue

		var odef: Dictionary = species_def(str(o["sp"]))

		if str(odef.get("alarm_group", "")) != group or Vector2(o["pos"].x - a["pos"].x, o["pos"].z - a["pos"].z).length() > reach:
			continue

		var span: Array = odef.get("alarm_s", [0.2, 0.9])
		o["alarm"] = rng.randf_range(float(span[0]), float(span[1]))   # luck-exempt: how fast a neighbouring bird reacts


# The fire whose keep-off radius covers a point (a burning fire or a torch bearer this tick), or Vector3.INF.
func _fire_guard(p: Vector3) -> Vector3:
	for f in _fire_cache:
		var at: Vector3 = f[0]

		if Vector2(at.x - p.x, at.z - p.z).length() <= float(f[1]):
			return at

	return Vector3.INF


# Whether an animal (or a point, when given) is at its den: within den.den_m of where it spawned. Only species with a den block.
func _in_den(a: Dictionary, def: Dictionary, at: Vector3 = Vector3.INF) -> bool:
	if not a.has("den"):
		return false

	var p: Vector3 = a["pos"] if at == Vector3.INF else at
	var den_m: float = float(def["den"].get("den_m", 15.0))

	# The vertical check matters only where the den is far above or below (a goblin den inside a cave): a player on the hill over it is not in it.
	return Vector2(p.x - a["den"].x, p.z - a["den"].z).length() <= den_m and absf(p.y - a["den"].y) <= den_m


# How close a player may come before this animal feels threatened and attacks: defend.threat_m, den.threat_m at its den.
# Scaled by the season (a hungry spring bear is bolder) and, away from a den, by its temperament (0 for passive and friendly ones).
func _threat_m(a: Dictionary, def: Dictionary) -> float:
	var season_x: float = float(_season_row(def).get("threat_x", 1.0))

	if _in_den(a, def):
		return float(def["den"].get("threat_m", 15.0)) * season_x

	return float(def["defend"].get("threat_m", 0.0)) * season_x * float(_temper_row(a).get("threat_x", 1.0))


# Where a den animal goes next (Dave 6 Nov 2026: a bear wanders round the river near its den and spends most of its time fishing,
# foraging berries or sleeping): within den.range_m of its den; fish_share of the time to the water's edge (a dry spot with water
# a few metres off), else somewhere in its range to forage. Sleeping is its rest hours (active, rest.graze_x).
func _den_target(a: Dictionary, def: Dictionary) -> Vector3:
	var den_cfg: Dictionary = def["den"]
	var den: Vector3 = a.get("den_out", a["den"])   # a cave-den goblin out at night ranges round the mouth it came out of
	var range_m: float = float(den_cfg.get("range_m", 80.0))

	if water_level.is_valid() and rng.randf() < float(den_cfg.get("fish_share", 0.5)):   # luck-exempt: whether a bear goes fishing next
		# It walks out from its den along a few random bearings, 2 m at a time, and stops at the first dry spot with water 3 m ahead:
		# the near bank of the river (a random point in the range almost never lands on the thin strip along the bank).
		for _try in 8:
			var ang: float = rng.randf() * TAU   # luck-exempt: which way it looks for a fishing spot
			var dir: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
			var dist: float = 2.0

			while dist <= range_m:
				var spot: Vector3 = den + dir * dist

				if not is_nan(float(water_level.call(spot.x, spot.z))):
					break   # already in water: this way has no dry bank before it

				var ahead: Vector3 = spot + dir * 3.0

				if not is_nan(float(water_level.call(ahead.x, ahead.z))):
					a["fishing"] = true
					return spot

				dist += 2.0

	a["fishing"] = false
	var angle: float = rng.randf() * TAU   # luck-exempt: where it forages next
	return den + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(2.0, range_m)   # luck-exempt: as above


# Keep each player's share topped up: new animals out of sight (spawn_min_m..spawn_max_m away), never near any player.
func _top_up(players: Array, only: int) -> void:
	for hid in _herds.keys():
		var alive: Array = []

		for mate_id in _herds[hid]:
			if animals.has(mate_id):
				alive.append(mate_id)

		if alive.is_empty():
			_herds.erase(hid)
		else:
			_herds[hid] = alive

	var per_player: int = int(cfg.get("per_player_cap", 30))
	var never: float = float(cfg.get("never_within_m", 60.0))

	for p in [players[only]]:
		# One pass over the animals counts them all near this player, by species (it was one pass per species: 22 species x 150
		# animals each top-up once species 17 to 22 came in, Tyler 7 Nov 2026: tick 1.89 -> 2.14 ms).
		var spawn_max_sq: float = pow(float(cfg.get("spawn_max_m", 250.0)), 2.0)
		var near_by_sp: Dictionary = {}
		var all_near: int = 0

		for id in animals:
			var at: Vector3 = animals[id]["pos"]

			if (at.x - p.x) * (at.x - p.x) + (at.z - p.z) * (at.z - p.z) <= spawn_max_sq:
				all_near += 1
				near_by_sp[animals[id]["sp"]] = int(near_by_sp.get(animals[id]["sp"], 0)) + 1

		var counted: int = animals.size()

		for sp in cfg.get("species", {}):
			all_near += animals.size() - counted      # what the species before spawned this pass (all within spawn_max_m of this player)
			counted = animals.size()
			var def: Dictionary = species_def(sp)

			if not bool(def.get("model", true)):
				continue   # waiting for a model: never spawned, so nothing invisible (or a stand-in rabbit) appears

			if def.has("lair"):
				_top_up_lair(sp, def, p, players)
				continue

			var have: int = int(near_by_sp.get(sp, 0))

			if have >= int(def.get("target_per_player", 6)) or all_near >= per_player or animals.size() >= int(cfg.get("server_cap", 150)):
				continue

			if def.has("spawn_share") and rng.randf() > float(def["spawn_share"]):   # luck-exempt: rare species turn up on some top-ups only
				continue

			if rng.randf() > activity_chance(def):   # luck-exempt: night animals rarely turn up by day and the other way round
				continue

			# A cave den near the player comes first (Dave 19 Nov 2026): the animal is made at the mouth, its den.
			var den_mouth: Vector2 = cave_den_spot(sp, def, p, players) if CAVE_DEN_SPECIES.has(sp) else Vector2(INF, INF)

			if den_mouth.x != INF:
				spawn(sp, den_mouth.x, den_mouth.y)   # a species with a "den" row (the bear) takes its spawn spot, the mouth, as its den
				continue

			# A species with a daily clock is made at its places (a warren, a deer range) once the ground round the player is worked out.
			if _place_spawn(sp, def, p, players, per_player - all_near):
				continue

			# A few candidate spots; the first the species can live on wins, a forest animal takes a spot under trees if one turns up.
			var x: float = 0.0
			var z: float = 0.0
			var best: float = -1.0

			for attempt in int(def.get("tries", cfg.get("habitat_tries", 6))):
				var angle: float = rng.randf() * TAU   # luck-exempt: where wildlife appears
				var dist: float = rng.randf_range(float(cfg.get("spawn_min_m", 150.0)), float(cfg.get("spawn_max_m", 250.0)))   # luck-exempt: as above

				if rng.randf() < float(cfg.get("near_share", 0.0)):   # luck-exempt: some wildlife turns up close, so a new player sees animals
					dist = rng.randf_range(float(cfg.get("near_min_m", 60.0)), float(cfg.get("near_max_m", 120.0)))   # luck-exempt: where wildlife appears near a player, no outcome for the player
				var cx: float = p.x + cos(angle) * dist
				var cz: float = p.z + sin(angle) * dist
				var too_near: bool = false

				too_near = _near_any(cx, cz, players, never if cfg.has("near_share") else maxf(never, float(cfg.get("spawn_min_m", 150.0)) * 0.9))

				too_near = too_near or no_spawn_at(cx, cz)

				if too_near or ((not def.has("flock") or bool(def["flock"].get("on_land", false))) and blocked.is_valid() and bool(blocked.call(cx, cz))) or crosses_wall(cx, cz, cx, cz):
					continue

				var weight: float = biome_weight(def, cx, cz)

				if weight <= 0.0 or (weight < 1.0 and rng.randf() > weight):   # luck-exempt: biome suits the species this much
					continue

				var score: float = _habitat_score(def, cx, cz, p.y)

				if score > best:
					best = score
					x = cx
					z = cz

					if score >= 2.0:
						break

			if best < 0.0:
				continue

			if def.has("flock") and not bool(def["flock"].get("on_land", false)) and ice_on():
				var edge: Vector2 = ice_edge_spot(x, z, sp)   # on a frozen pond the flock stands on the ice at the open water's edge, or is not there

				if edge.x == INF:
					continue

				x = edge.x
				z = edge.y

				if no_spawn_at(x, z) or _near_any(x, z, players, never):   # the edge can be nearer a player than the spot was
					continue

			var herd: Array = def.get("herd", [])

			if herd.is_empty():
				spawn(sp, x, z)
				continue

			var members: int = clampi(rng.randi_range(int(herd[0]), int(herd[1])), 1, maxi(per_player - all_near, 1))   # luck-exempt: how many deer in a herd
			var hid: int = _next_herd
			_next_herd += 1
			_herds[hid] = []

			for k in members:
				var hx: float = x + rng.randf_range(-6.0, 6.0)   # luck-exempt: herd spread
				var hz: float = z + rng.randf_range(-6.0, 6.0)   # luck-exempt: herd spread
				if _near_any(hx, hz, players, never) or no_spawn_at(hx, hz):   # a member spread toward a player is never made inside never_within_m either
					continue

				var id: int = spawn(sp, hx, hz)

				if id != 0:
					animals[id]["herd"] = hid
					_herds[hid].append(id)


# Whether any player stands within `m` of (x, z) on the ground plan.
func _near_any(x: float, z: float, players: Array, m: float) -> bool:
	for q in players:
		if Vector2(q.x - x, q.z - z).length() < m:
			return true

	return false


# The mouth of a cave the species dens in where a new one may be made now (Vector2(INF, INF) for none): within spawn_max_m of the player and no
# nearer than never_within_m to any player, its den empty (no animal of the species within cave_den_claim_m of the mouth), and the mouth not
# blocked, walled off or in a no-spawn zone. The first such mouth in the tile's order wins, so the choice does not hang on the roll.
func cave_den_spot(sp: String, def: Dictionary, p: Vector3, players: Array) -> Vector2:
	if not cave_den_mouths.is_valid():
		return Vector2(INF, INF)

	var reach: float = float(cfg.get("spawn_max_m", 250.0))
	var never: float = float(cfg.get("never_within_m", 60.0))
	var claim: float = float(cfg.get("cave_den_claim_m", 40.0))

	for mouth in cave_den_mouths.call(p.x, p.z, sp):
		var m: Vector2 = mouth

		if Vector2(p.x - m.x, p.z - m.y).length() > reach:
			continue

		var taken: bool = false

		for q in players:
			taken = taken or Vector2(q.x - m.x, q.z - m.y).length() < never

		for id in animals:
			var other: Dictionary = animals[id]

			if other["sp"] != sp:
				continue

			var home: Vector3 = other.get("den", other["pos"])   # a bear ranging out from its den still holds it
			taken = taken or Vector2(other["pos"].x - m.x, other["pos"].z - m.y).length() <= claim or Vector2(home.x - m.x, home.z - m.y).length() <= claim

		if taken or no_spawn_at(m.x, m.y) or (blocked.is_valid() and bool(blocked.call(m.x, m.y))) or crosses_wall(m.x, m.y, m.x, m.y):
			continue

		if biome_weight(def, m.x, m.y) <= 0.0 or _habitat_score(def, m.x, m.y, p.y) < 0.0:
			continue   # the mouth must be ground the species lives on (a bear's forest by fresh water), as any spawn spot

		return m

	return Vector2(INF, INF)


# The first mouth of a cave the species dens in inside a world rectangle (a wolf pack's 2 km cell), Vector2(INF, INF) for none. The cell may cross a
# tile edge, so the tiles under its middle and corners are asked.
func cave_den_in(cell: Rect2, sp: String) -> Vector2:
	if not cave_den_mouths.is_valid():
		return Vector2(INF, INF)

	for at in [cell.get_center(), cell.position, cell.position + Vector2(cell.size.x, 0.0), cell.position + Vector2(0.0, cell.size.y), cell.end]:
		for mouth in cave_den_mouths.call(at.x, at.y, sp):
			if cell.has_point(mouth):
				return mouth

	return Vector2(INF, INF)


# Lair species (goblins, Dave 7 Nov 2026): a group of lair.group[0]..group[1] lives at a cave mouth near a player, beside a river (caves are
# only at river starts), and never in a cave that already has a bear in or near it (lair.avoid within lair.avoid_m). They are made whatever the
# hour: by day they sleep in the den, at night they range round the mouth (den.range_m). Each mouth holds one group at a time: the group's
# goblins carry the mouth's key ("lair"), so a group 100 m inside still holds its cave. The group is a herd, so when one bolts the others follow.
# With a den_life row and a cave path (lair_path; docs/design/goblin_den_life_design.md) the den is the den node in the cave and a group made by
# day is made there; without a path (a tile baked before it, or a cave whose den is not joined to the mouth) the den is the mouth, as before.
func _top_up_lair(sp: String, def: Dictionary, p: Vector3, players: Array) -> void:
	if not lair_mouths.is_valid():
		return

	var lair: Dictionary = def["lair"]
	var group: Array = lair.get("group", [2, 5])
	var range_m: float = float(lair.get("range_m", 200.0))
	var never: float = float(cfg.get("never_within_m", 60.0))

	for mouth in lair_mouths.call(p.x, p.z):
		var m: Vector2 = mouth

		if Vector2(p.x - m.x, p.z - m.y).length() > range_m:
			continue

		var taken: bool = false
		var key: String = "%d,%d" % [int(m.x), int(m.y)]
		var state: Dictionary = _lair_state.get(key, {"made": false, "empty_since": -1.0})
		var now_s: float = float(Time.get_ticks_msec()) / 1000.0
		var has_group: bool = false

		for gid in animals:
			has_group = has_group or (animals[gid]["sp"] == sp and (str(animals[gid].get("lair", "")) == key or Vector2(animals[gid]["pos"].x - m.x, animals[gid]["pos"].z - m.y).length() <= float(lair.get("claim_m", 40.0))))

		taken = has_group

		# Respawn (Dave 7 Nov 2026: a killed group "eventually" comes back, depending on patrols or buildings): a mouth that had a group and found it
		# gone waits lair.respawn_s before it makes another, and not at all while lair_guarded says a patrol or buildings hold the area.
		if has_group:
			state["empty_since"] = -1.0
		elif bool(state["made"]):
			if float(state["empty_since"]) < 0.0:
				state["empty_since"] = now_s

			taken = now_s - float(state["empty_since"]) < float(lair.get("respawn_s", 1800.0)) or (lair_guarded.is_valid() and bool(lair_guarded.call(m.x, m.y, float(lair.get("guard_m", 100.0)))))

		_lair_state[key] = state
		var path: PackedVector3Array = lair_path.call(m.x, m.y) if lair_path.is_valid() and def.has("den_life") and not taken else PackedVector3Array()

		for q in players:
			taken = taken or Vector2(q.x - m.x, q.z - m.y).length() < never

			# A group made by day is made asleep in the den: never in front of a player who has walked in that far.
			taken = taken or (path.size() >= 2 and resting(def) and (q as Vector3).distance_to(path[path.size() - 1]) < never)

		for id in animals:
			var other: Dictionary = animals[id]
			var d: float = Vector2(other["pos"].x - m.x, other["pos"].z - m.y).length()
			taken = taken or (other["sp"] == sp and d <= float(lair.get("claim_m", 40.0)))
			taken = taken or ((lair.get("avoid", []) as Array).has(other["sp"]) and d <= float(lair.get("avoid_m", 120.0)))

		if taken or (blocked.is_valid() and bool(blocked.call(m.x, m.y))) or crosses_wall(m.x, m.y, m.x, m.y) or no_spawn_at(m.x, m.y):
			continue

		if path.size() >= 2 and resting(def) and no_spawn_at(path[path.size() - 1].x, path[path.size() - 1].z):
			continue   # made by day they would wake up in a den a player has built beside

		var members: int = clampi(rng.randi_range(int(group[0]), int(group[1])), 1, maxi(int(cfg.get("per_player_cap", 30)) - animals.size(), 1))   # luck-exempt: how many goblins in a group
		var spots: Array = []

		for _k in members:
			var spot: Vector2 = m + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))   # luck-exempt: group spread

			if not no_spawn_at(spot.x, spot.y):
				spots.append(spot)

		if spots.is_empty():
			continue   # every spot fell inside a no-spawn zone: the mouth is not counted as made

		state["made"] = true
		state["empty_since"] = -1.0
		_lair_state[key] = state
		var hid: int = _next_herd
		_next_herd += 1
		_herds[hid] = []
		var den_at: Vector3 = Vector3.INF

		for at in spots:
			var id: int = spawn(sp, at.x, at.y)

			if id != 0:
				animals[id]["herd"] = hid
				animals[id]["lair"] = key
				den_at = animals[id]["pos"] if den_at == Vector3.INF else den_at   # one shared den: the first goblin's spot
				animals[id]["den"] = den_at
				animals[id]["home"] = den_at
				_herds[hid].append(id)

				if path.size() >= 2:
					animals[id]["cave_path"] = path
					animals[id]["den"] = path[path.size() - 1]   # the den in the cave; at night they range round the mouth (den_out)
					animals[id]["den_out"] = den_at

					if resting(def):
						goblins.place_in_den(animals[id])   # made by day: asleep in the den

		return   # one new group per top-up


# The period of the game day for a clock hour: "dusk" for the hours around sunrise (5 to 8) and sunset (18 to 21), "day" between, "night" otherwise.
static func period_of(hour: float) -> String:
	if hour >= 8.0 and hour < 18.0:
		return "day"

	if (hour >= 5.0 and hour < 8.0) or (hour >= 18.0 and hour < 21.0):
		return "dusk"

	return "night"


# Today's sunrise hour (6 without a sun); sunset is as far after noon as sunrise is before it.
func sunrise_hour() -> float:
	if not sunrise_now.is_valid():
		return 6.0

	if _sun[0] < 0 or Time.get_ticks_msec() - int(_sun[0]) > 5000:
		_sun = [Time.get_ticks_msec(), float(sunrise_now.call())]

	return float(_sun[1])


# An animal's period on the real sun (stage 2a, D-TRAP-3; docs/design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md): dawn from an hour before
# sunrise to two after, dusk from sunset to three after, day between, night the rest. At the equinox (sunrise 6) these are period_of's
# fixed hours, so the "active" rows keep their meaning; in winter the deer's dusk comes at 17:00, in summer after 19:00. Bandits and
# companions keep period_of. (Sunrise stays between about 4 and 8 at any row a player lives on, so the windows never cross midnight.)
func period_now(hour: float) -> String:
	if not sunrise_now.is_valid():
		return period_of(hour)

	var rise: float = sunrise_hour()
	var fall: float = 24.0 - rise

	if hour >= rise + 2.0 and hour < fall:
		return "day"

	if (hour >= rise - 1.0 and hour < rise + 2.0) or (hour >= fall and hour < fall + 3.0):
		return "dusk"

	return "night"


# The chance (0..1) that a top-up may spawn this species now: the row's "active" value for the current period, 1 without a clock or a row.
func activity_chance(def: Dictionary) -> float:
	if not def.has("active") or not hour_now.is_valid():
		return clampf(weather_activity_x(def), 0.0, 1.0)

	return clampf(float((def["active"] as Dictionary).get(fog_period(def, float(hour_now.call())), 1.0)) * weather_activity_x(def), 0.0, 1.0)


# The same at a given game hour (a snare's time away, server_traps.gd check_away): the row's "active" value for that hour's period.
func activity_at(def: Dictionary, hour: float) -> float:
	if not def.has("active"):
		return clampf(weather_activity_x(def), 0.0, 1.0)

	return clampf(float((def["active"] as Dictionary).get(fog_period(def, hour), 1.0)) * weather_activity_x(def), 0.0, 1.0)


# Resting (MikeW 2026-11-02, Dave's behaviour list): outside its active hours (its "active" chance for the period at or under rest.below)
# an animal beds down where it is: it does not wander, and a player gets closer (rest.spook_share of spook_m) before it wakes and runs.
# Before a storm (animals_in_weather_design.md 8) feeding animals skip their daytime rest.
func resting(def: Dictionary) -> bool:
	if _feeding_before_storm(def):
		return false

	return def.has("active") and hour_now.is_valid() and activity_chance(def) <= float(cfg.get("rest", {}).get("below", 0.1))


func _feeding_before_storm(def: Dictionary) -> bool:
	return _storm_ahead and _wx_on() and str(def.get("weather", "")) in ["bird", "small", "deer"] and hour_now.is_valid() and period_now(float(hour_now.call())) == "day"


# Lying down (docs/design/ANIMAL_RESTING.md, protocol 148): a resting animal lies; otherwise a standing grazer lies when its own fixed
# draw (from its id) is at or over its active chance now, so a deer herd by day (0.4) is about 60% bedded and 40% feeding, and at dusk
# (1.0) all are up. No new number: the "active" rows say how much of the time a species is up.
func lies_down(a: Dictionary, def: Dictionary) -> bool:
	if not def.has("active") or not hour_now.is_valid() or _feeding_before_storm(def):
		return false

	return resting(def) or fposmod(float(a["id"]) * 0.6180339, 1.0) >= activity_chance(def)


# The weight (0..1+) of the biome at a spot for this species: 1 without a "biomes" row or a lookup, 0 for a biome the row does not list.
func biome_weight(def: Dictionary, x: float, z: float) -> float:
	if not def.has("biomes") or not biome_at.is_valid():
		return 1.0

	return float((def["biomes"] as Dictionary).get(str(biome_at.call(x, z)), 0.0))


# Swimmers (a row's "water": {"swim": true, ...}; docs/design/ALLIGATOR_SWIMMING.md, Dave 8 Nov 2026): they cross and stay in water
# no other animal enters, riding the surface surface_sink_m low, and live on the bank within bank_m of fresh water.
func swims(def: Dictionary) -> bool:
	return def.get("water", null) is Dictionary and bool(def["water"].get("swim", false))


# Whether a spot is water a swimmer is in (a water surface there).
func in_water(_def: Dictionary, pos: Vector3) -> bool:
	return water_level.is_valid() and not is_nan(float(water_level.call(pos.x, pos.z)))


# The height a swimmer stands at: on water its surface less surface_sink_m, on land the ground.
func swim_height(def: Dictionary, x: float, z: float) -> float:
	var level: float = float(water_level.call(x, z)) if water_level.is_valid() else NAN

	var ground: float = float(ground_height.call(x, z)) if ground_height.is_valid() else NAN

	if not is_nan(level):
		# It sinks to surface_sink_m only where the water is that deep, so wading in from the bank is a smooth slope.
		var depth: float = level - ground if not is_nan(ground) else 99.0
		return level - minf(float(def["water"].get("surface_sink_m", 0.25)), maxf(depth, 0.0))

	return ground if not is_nan(ground) else 0.0


# Optional habitat keys from the guiding document (docs/design/GUIDING_DOCUMENT.md section 5, 7 Nov 2026) are accepted in a
# row's "habitat" and not used yet, so data can be written ahead of the terrain that answers them (R6): altitude_m [min, max],
# slope_deg [min, max], rock, water_kind, cave, canopy, sea_depth_m [min, max], sky, lair, season. A row with them spawns and
# scores exactly as one without (test_habitat_keys.gd).
const HABITAT_KEYS_LATER := ["altitude_m", "slope_deg", "rock", "water_kind", "cave", "canopy", "sea_depth_m", "sky", "lair", "season"]


# How well a spot suits a species: -1 when it cannot live there (too steep, a summit far above the player, at the water's edge),
# 1 for open ground, 2 under trees for a species that likes forest ("forest": true in its habitat).
func _habitat_score(def: Dictionary, x: float, z: float, player_y: float) -> float:
	var hab: Dictionary = def.get("habitat", {})

	if def.has("flock") and not bool(def["flock"].get("on_land", false)):
		var level: float = float(water_level.call(x, z)) if water_level.is_valid() else NAN
		if bool(def["flock"].get("fresh_only", false)) and biome_at.is_valid() and str(biome_at.call(x, z)) == "ocean":
			return -1.0   # ducks keep to rivers and lakes, not the open sea

		return 2.0 if not is_nan(level) and blocked.is_valid() and bool(blocked.call(x, z)) else -1.0   # open deep water only

	if swims(def):
		# A swimmer lives in fresh water and on the bank within water.bank_m of it (the alligator, Dave 8 Nov 2026).
		var level_here: float = float(water_level.call(x, z)) if water_level.is_valid() else NAN

		if biome_at.is_valid() and str(biome_at.call(x, z)) == "ocean":
			return -1.0

		if not is_nan(level_here):
			return 2.0 if not bool(def["water"].get("lives_on_land", false)) else 1.0

		# lives_on_land (moose, goose): water is open to it, but on land its own habitat rules apply as before.
		if not bool(def["water"].get("lives_on_land", false)):
			return 1.0 if _fresh_near(x, z, float(def["water"].get("bank_m", 6.0))) else -1.0

	if hab.is_empty() or not ground_height.is_valid():
		return 1.0

	var h: float = float(ground_height.call(x, z))

	if is_nan(h) or h > player_y + float(hab.get("above_player_m", 250.0)):
		return -1.0

	var run: float = float(hab.get("slope_run_m", 6.0))
	var steepest: float = 0.0

	for d in [Vector2(run, 0.0), Vector2(-run, 0.0), Vector2(0.0, run), Vector2(0.0, -run)]:
		var other: float = float(ground_height.call(x + d.x, z + d.y))
		steepest = maxf(steepest, absf(other - h) / run if not is_nan(other) else 9.0)

	if steepest > float(hab.get("slope_max", 0.6)):
		return -1.0

	var edge: float = float(hab.get("water_edge_m", 0.0))

	if edge > 0.0 and blocked.is_valid():
		for d in [Vector2(edge, 0.0), Vector2(-edge, 0.0), Vector2(0.0, edge), Vector2(0.0, -edge)]:
			if bool(blocked.call(x + d.x, z + d.y)):
				return -1.0

	var near: float = float(hab.get("near_fresh_water_m", 0.0))

	if near > 0.0 and not _fresh_near(x, z, near):
		return -1.0   # a frog lives by a stream, pond or lake, never deep in a dry wood or on a sea shore

	var sea: float = float(hab.get("near_ocean_m", 0.0))

	if sea > 0.0 and biome_at.is_valid() and not _water_near(x, z, sea, true):
		return -1.0   # gulls and seals keep to the coast: a salt marsh or rocks by the sea, not one inland

	if bool(hab.get("forest", false)) and canopy.is_valid() and bool(canopy.call(Vector3(x, h, z))):
		return 2.0

	return 1.0


# Whether water lies within radius of a spot: the spot itself, then eight directions at half and full radius. ocean false: fresh
# water (a water surface that is not on ocean ground). ocean true: ocean ground.
# Whether perennial fresh water (a river or lake) is within `radius`. The baked distance (the water as the bake made it, the same for every
# server run) when the tile has it; otherwise the live water probe, which also sees ditches and puddles and nothing before the sim settles.
func _fresh_near(x: float, z: float, radius: float) -> bool:
	if fresh_water_m.is_valid():
		var d: float = float(fresh_water_m.call(x, z))

		if not is_nan(d):
			return d <= radius

	return not water_level.is_valid() or _water_near(x, z, radius, false)   # no water source at all (a test without water): no rule, as before


func _water_near(x: float, z: float, radius: float, ocean: bool) -> bool:
	for ring in [0.0, radius * 0.5, radius]:
		for i in (1 if ring == 0.0 else 8):
			var a: float = TAU * float(i) / 8.0
			var px: float = x + cos(a) * ring
			var pz: float = z + sin(a) * ring

			var is_ocean: bool = biome_at.is_valid() and str(biome_at.call(px, pz)) == "ocean"

			if ocean:
				if is_ocean:
					return true

				continue

			if is_nan(float(water_level.call(px, pz))) or is_ocean:
				continue

			return true

	return false


# Rows [id, species number, position, heading radians, state] within send_radius_m of a point, nearest first, at most per_player_cap.
# An animal warning at, charging or recovering from a dog (states 10 to 12 with foe_dog, dog_companion_design.md 11) adds a sixth field:
# the dog's position, so the client looks at the dog and not the player (MikeW, 8 Nov 2026). Rows without it are unchanged.
# radius_m and cap above 0 replace send_radius_m and per_player_cap (an admin looking through the spyglass: "spyglass" in animals.json).
func rows_near(point: Vector3, radius_m: float = -1.0, cap: int = -1) -> Array:
	var radius: float = radius_m if radius_m > 0.0 else float(cfg.get("send_radius_m", 120.0))
	var found: Array = []

	for id in animals:
		var a: Dictionary = animals[id]
		var d: float = Vector2(a["pos"].x - point.x, a["pos"].z - point.z).length()

		if d <= radius and a["state"] != HIDDEN:
			# Field 5 (protocol 147): the server milliseconds it was at this position: its step's time (tick), or now for a move made
			# elsewhere (the pack brain, a companion). The client draws each animal on these times, not on when the rows came (Dave 21 Nov
			# 2026 play test: "animals are still teleporting and not actually running"). Protocol 154 (Dave 23 Nov 2026, the real server):
			# a standing animal's row carries the send time, every send, so the client knows it stood until just before it moved. It used to
			# guess a stand from a gap in arrivals, and over the internet a lost batch looks the same: the animal stood, then jumped.
			if a.get("row_pos") != a["pos"]:
				a["row_pos"] = a["pos"]
				a["row_ms"] = int(a["moved_ms"]) if int(a.get("moved_ms", -1)) > int(a.get("row_ms", -1)) else Time.get_ticks_msec()
			elif not bool(a.get("moving", false)):
				a["row_ms"] = Time.get_ticks_msec()

			var row: Array = [id, a["num"], a["pos"], snappedf(a["heading"], 0.01), _wire_state(a), int(a["row_ms"])]

			if a.has("foe_dog") and int(a["state"]) >= 10 and int(a["state"]) <= 12 and animals.has(int(a["foe_dog"])):
				row.append(animals[int(a["foe_dog"])]["pos"])

			if a.has("hp_max") and float(a["hp"]) < float(a["hp_max"]):
				row.append(maxf(snappedf(float(a["hp"]) / maxf(float(a["hp_max"]), 0.01), 0.1), 0.1))   # hurt: its health share, always the last field and a float

			found.append([d, row])

	found.sort_custom(func(l, r): return l[0] < r[0])
	var rows: Array = []

	for f in found.slice(0, cap if cap > 0 else int(cfg.get("per_player_cap", 30))):
		rows.append(f[1])

	return rows


# The state an animal is sent with: GRAZE shows as DRINK at its drinking place, HUNCH standing out the rain.
func _wire_state(a: Dictionary) -> int:
	if a["state"] == GRAZE and bool(a.get("drinking", false)):
		return DRINK

	if a["state"] == GRAZE and (bool(a.get("hunch", false)) or bool(a.get("sheltered", false))):
		return HUNCH

	# Bedded down (lies_down: out of its hours, or its share of the herd at rest), an animal is drawn lying, not grazing (Dave 21 Nov 2026: "relaxing" first among the
	# situations; protocol 148). Birds and flocks stay as they are: they perch or float.
	if a["state"] == GRAZE and not a.has("fly") and not bool(a.get("perched", false)) and not a.has("companion_id"):
		var def: Dictionary = species_def(str(a["sp"]))

		if not def.has("flock") and not def.has("flight") and lies_down(a, def):
			return LIE

	return int(a["state"])


# What the admin spyglass shows of one animal (Dave 9 Nov 2026, docs/design/spyglass_design.md): {} when it is gone or in its burrow.
func info_of(id: int) -> Dictionary:
	if not animals.has(id) or animals[id]["state"] == HIDDEN:
		return {}

	var a: Dictionary = animals[id]
	var def: Dictionary = species_def(str(a["sp"]))
	var out: Dictionary = {"name": str(def.get("name", a["sp"])), "young": int(a["num"]) >= YOUNG_NUM, "hp": snappedf(float(a["hp"]), 0.1),
		"hp_max": snappedf(float(a.get("hp_max", a["hp"])), 0.1), "state": _wire_state(a), "group": int(a.get("pack", a.get("herd", 0))), "pack": a.has("pack")}

	if a.has("level"):
		out["level"] = int(a["level"])

	if a.has("temper"):
		out["temper"] = str(a["temper"])

	return out


func _bolt(a: Dictionary, from: Vector3, def: Dictionary) -> void:
	if def.has("flight") and flight != null:
		flight.take_off(a, from)   # a bird with a flight row flies instead of running (bird_flight_server_design.md)
		return

	var away: Vector2 = Vector2(a["pos"].x - from.x, a["pos"].z - from.z).normalized()

	if away == Vector2.ZERO:
		away = Vector2.from_angle(a["heading"])

	# Herd groups (HERD_GROUPS.md): the herd scatters, each member breaking up to groups.scatter_deg either side of straight away.
	if a["herd"] != 0 and _groups_on():
		var slot: int = (_herds.get(a["herd"], []) as Array).find(a["id"])

		if slot > 0:
			var side: float = 1.0 if slot % 2 == 1 else -1.0
			away = away.rotated(side * deg_to_rad(float(cfg["groups"].get("scatter_deg", 25.0))) * minf(ceilf(float(slot) / 2.0) / 2.0, 1.0))

	a["state"] = FLEE
	a["burst"] = 0.0
	a["alert"] = 0.0
	a.erase("trip")
	a.erase("lured")
	a.erase("hunch")
	a.erase("sheltered")
	a["target"] = a["pos"] + _zig(away, def) * float(def.get("zig_leg_m", float(def.get("flee_run_m", 25.0))))
	_to_burrow(a, away, def)


# A rabbit with its burrow in reach and away from the threat runs for it and goes to ground there.
func _to_burrow(a: Dictionary, away: Vector2, def: Dictionary) -> void:
	a["to_burrow"] = false

	if a["burrow"] == Vector3.INF:
		return

	var to_b: Vector2 = Vector2(a["burrow"].x - a["pos"].x, a["burrow"].z - a["pos"].z)

	if to_b.length() <= float(def.get("burrow_m", 0.0)) and (to_b.length() < 2.0 or to_b.normalized().dot(away) > 0.0):
		a["target"] = a["burrow"]
		a["to_burrow"] = true


# How much each player rustles the undergrowth, sampled every senses.noise_sample_s (player positions arrive at the network rate, so
# not per frame). Only a little (Dave 5 Nov 2026: legs brushing the bushes, not a lot, and it never means the animal hears you
# outright): a player moving through bushes, ferns or tall grass (undergrowth) is sensed 1 + brush_noise_per_ms x speed farther,
# so about 13 percent walking (3.2 m/s, the walk since 10 Nov 2026; 6 percent at the old 1.4) and 36 percent running flat out (9 m/s); crouched, brush_crouch_share of
# that. The hunting skill quietens it: the extra is divided by the square of the stalk factor (1.0 for a beginner, about 1.5 at
# hunting 100, so a master makes under half the noise). A change in the player count resets the sample (the order may have changed).
func _sample_noise(players: Array, delta: float) -> void:
	var sen: Dictionary = cfg.get("senses", {})
	_noise_acc += delta

	if _noise_acc < float(sen.get("noise_sample_s", 0.25)):
		return

	var stances: Array = player_stances.call() if player_stances.is_valid() else []
	var stalk: Array = player_stalk.call() if player_stalk.is_valid() else []
	var loud: Array = player_loud.call() if player_loud.is_valid() else []
	var fresh: Array = []
	var heard: Array = []
	var vel: Array = []

	for pi in players.size():
		var noise: float = 1.0
		var moved: Vector2 = Vector2.ZERO

		if players.size() == _noise_from.size():
			var was0: Vector3 = _noise_from[pi]
			moved = Vector2(players[pi].x - was0.x, players[pi].z - was0.z) / _noise_acc

		vel.append(moved)

		# A running player is seen and heard from farther off (run_ms, run_x; Dave 19 Nov 2026: animals did not react to him running past); walking is 3.2 m/s.
		# Two samples running, so two position updates landing in one sample never make a walk count as a run.
		var before: float = (_player_vel[pi] as Vector2).length() if pi < _player_vel.size() else 0.0

		if minf(moved.length(), before) >= float(sen.get("run_ms", 5.0)):
			noise *= float(sen.get("run_x", 1.5))

		if players.size() == _noise_from.size() and undergrowth.is_valid():
			var p: Vector3 = players[pi]
			var speed: float = moved.length()

			if speed >= float(sen.get("brush_moving_ms", 0.5)) and bool(undergrowth.call(p)):
				var extra: float = float(sen.get("brush_noise_per_ms", 0.04)) * minf(speed, 12.0)
				var skill: float = maxf(float(stalk[pi]) if pi < stalk.size() else 1.0, 1.0)

				if pi < stances.size() and int(stances[pi]) == 1:
					extra *= float(sen.get("brush_crouch_share", 0.5))

				noise *= 1.0 + extra / (skill * skill)

		fresh.append(noise)
		heard.append(heard_x(str(loud[pi])) if pi < loud.size() else 0.0)

	_noisy = fresh
	_heard = heard
	_player_vel = vel
	_noise_from = players.duplicate()
	_noise_acc = 0.0


# The ground velocity (x, z, m/s) of the player standing nearest a point, from the last noise sample (Vector2.ZERO when unknown): big game
# reads it during a warning, because a player who runs away is chased (docs/design/bear_threat_design.md).
func player_velocity_at(p: Vector3) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_d: float = INF

	for pi in mini(_noise_from.size(), _player_vel.size()):
		var d: float = Vector2(_noise_from[pi].x - p.x, _noise_from[pi].z - p.z).length()

		if d < best_d:
			best_d = d
			best = _player_vel[pi]

	return best if best_d <= float(cfg.get("senses", {}).get("velocity_match_m", 4.0)) else Vector2.ZERO


# How far a loud action named `name` carries to animals (senses.action_heard_x; server_action_cues LOUD_RANK names), 0.0 for "" or a quiet one.
func heard_x(name: String) -> float:
	return float(cfg.get("senses", {}).get("action_heard_x", {}).get(name, 0.0))


# How much farther or nearer a player seems to an animal: downwind of the player it smells them from farther off, upwind it does
# not; a crouching or lying player is harder to see; with the ground in the way only scent and sound are left. A player rustling
# through undergrowth (noise, _sample_noise: a little, more the faster they go, less the better a hunter) is sensed a little farther
# off. It is added last, so it also carries where the animal can't see the player. A loud action (heard: a blow, a cry, craft work;
# senses.action_heard_x, _sample_noise) carries that far whatever the stance and cover: a crouching woodcutter in the trees is still heard.
func _sense_factor(a: Dictionary, def: Dictionary, p: Vector3, d: float, stance: int, noise: float = 1.0, heard: float = 0.0) -> float:
	var sen: Dictionary = cfg.get("senses", {})
	var f: float = 1.0

	# Stances 4 and 5 are lying on a covered rough bed and lying in a closed room (server_items.peer_stances, bed.json): lying, and harder to sense.
	if stance >= 4:
		f *= float(sen.get("bed_mult", 0.7)) if stance == 4 else float(sen.get("hidden_mult", 0.05))
		stance = 3

	if _wind_s > 0.0 and d > 0.01:
		var to_animal: Vector2 = Vector2(a["pos"].x - p.x, a["pos"].z - p.z) / d
		var along: float = _wind_s * to_animal.dot(_wind_dir)   # 1 straight downwind of the player in a full wind, -1 straight upwind
		# Downwind it smells the player from farther off; upwind it loses only the scent, not its eyes and ears, so it shrinks less (scent_loss, Dave 19 Nov 2026).
		f *= maxf(1.0 + float(sen.get("scent_gain", 0.5)) * along if along >= 0.0 else 1.0 + float(sen.get("scent_loss", 0.25)) * along, 0.5)   # times the bed's, never in place of it

	if stance == 1:
		f *= float(sen.get("crouch_factor", 0.6))
	elif stance == 3:
		f *= float(sen.get("lie_factor", 0.5))
	elif stance == 2:
		f *= float(sen.get("sit_factor", 0.8))

	if d > float(sen.get("always_notice_m", 8.0)):
		var sight: float = _sight(a, def, p, d, stance == 1 or stance == 3)

		if sight < 1.0:
			f *= lerpf(float(sen.get("blind_factor", 0.35)), 1.0, sight)

	return maxf(f * noise, heard)


# How much of the player an animal can see, 0 to 1: 0 when the ground is in the way; otherwise less the more of the line runs under
# tree crowns (trunks and undergrowth: forest_block is the loss in a line wholly under trees). Fog cuts it by distance (animals_in_fog_server.md 4.1).
func _sight(a: Dictionary, def: Dictionary, p: Vector3, d: float, low: bool) -> float:
	if not fog_on():
		return _sight_clear(a, def, p, d, low)

	var clear: float = _sight_clear(a, def, p, d, low)
	var strength: float = fog_strength_between(a["pos"], p) if clear > 0.0 else 0.0
	var haze: float = WeatherRules.fog_haze_density(_wx)

	if clear <= 0.0 or (strength <= 0.0 and haze <= WeatherRules.VIS_HAZE_DENSITY and d < CLEAR_SIGHT_M):
		return clear     # the ground is in the way, or clear air well inside the haze's own reach (the common case, no sums)

	var fc: Dictionary = _fog_cfg()
	return clear * fog_sight_share(d, FogShape.depth(haze, strength), float(fc.get("sight_full_fog", 0.53)), float(fc.get("sight_gone_fog", 0.78)))


func _sight_clear(a: Dictionary, def: Dictionary, p: Vector3, d: float, low: bool) -> float:
	if not ground_height.is_valid():
		return 1.0

	var sen: Dictionary = cfg.get("senses", {})
	var eye_a: float = a["pos"].y + float(def.get("eye_m", 0.5))
	var eye_p: float = p.y + (1.0 if low else 1.6)
	var n: int = clampi(int(d / float(sen.get("los_step_m", 4.0))), 1, 24)
	var under: int = 0
	var looked: int = 0

	for i in range(1, n):
		var t: float = float(i) / float(n)
		var x: float = lerpf(a["pos"].x, p.x, t)
		var z: float = lerpf(a["pos"].z, p.z, t)
		var h: float = float(ground_height.call(x, z))

		if not is_nan(h) and h > lerpf(eye_a, eye_p, t) + 0.15:
			return 0.0

		if canopy.is_valid() and i % 2 == 0:
			looked += 1
			under += 1 if bool(canopy.call(Vector3(x, h, z))) else 0

	return 1.0 - float(sen.get("forest_block", 0.45)) * (float(under) / float(looked) if looked > 0 else 0.0)


# One leg of a zigzag away from the threat: the away direction turned by up to zig_deg either way.
func _zig(away: Vector2, def: Dictionary) -> Vector3:
	var turn: float = deg_to_rad(float(def.get("zig_deg", 0.0))) * rng.randf_range(-1.0, 1.0)   # luck-exempt: which way a fleeing animal jinks
	var dir: Vector2 = away.rotated(turn)
	return Vector3(dir.x, 0.0, dir.y)


# Herd groups (docs/design/HERD_GROUPS.md; animals.json "groups", on since Dave's 8 Nov ruling). A herd has one leader, its first living member that
# is on the ground (a bird flying or perched is passed over). The leader drifts groups.drift_m per graze step on a slow wander, turned
# by the weather's _upwind_angle (deer and hunters into a light wind, not in a gale, with weather.on); the leader alone keeps any
# weather cover its home has. Every other member keeps a place round the leader on a spiral (golden angle, spacing x sqrt of its
# place), so the herd grazes and moves as one. With weather.on, spacing shrinks in rain and wind (animals_in_weather_design.md: herds
# bunch): x (1 - rain_bunch x rain - wind_bunch x wind), not below min_bunch. On alarm the herd scatters (_bolt) and, once safe,
# each member's next graze step takes it back to its place: the herd regroups where it stopped.
func _groups_on() -> bool:
	return bool((cfg.get("groups", {}) as Dictionary).get("enabled", false))


# Whether a herd member (not the leader) is far from the herd with groups on: more than three times its spacing plus 4 m from the
# leader. A scattered herd regroups before it stands a rain spell out.
func _group_strayed(a: Dictionary, def: Dictionary) -> bool:
	if a["herd"] == 0 or not _groups_on():
		return false

	var lead_id: int = _group_leader(a["herd"])

	if lead_id == 0 or lead_id == int(a["id"]):
		return false

	var spacing: float = float(def.get("group_spacing_m", (cfg["groups"] as Dictionary).get("spacing_m", 3.0)))
	return Vector2(a["pos"].x - animals[lead_id]["pos"].x, a["pos"].z - animals[lead_id]["pos"].z).length() > spacing * 3.0 + 4.0


func _group_leader(hid: int) -> int:
	for id in _herds.get(hid, []):
		if animals.has(id) and not animals[id].has("fly") and not bool(animals[id].get("perched", false)):
			return int(id)

	return 0


func _group_target(a: Dictionary, def: Dictionary) -> Vector3:
	var g: Dictionary = cfg["groups"]
	var lead_id: int = _group_leader(a["herd"])

	if lead_id == 0:
		return a["target"]

	var bunch: float = 1.0

	if _wx_on():
		var wet: float = maxf(float(_wx.get("rain", 0.0)), float(_wx.get("snow", 0.0)))
		bunch = clampf(1.0 - float(g.get("rain_bunch", 0.35)) * wet - float(g.get("wind_bunch", 0.25)) * float(_wx.get("wind", 0.0)), float(g.get("min_bunch", 0.5)), 1.0)

	var spacing: float = float(def.get("group_spacing_m", g.get("spacing_m", 3.0))) * bunch

	if lead_id == int(a["id"]):
		var dir: float = float(a.get("drift_dir", rng.randf() * TAU)) + rng.randf_range(-0.6, 0.6)   # luck-exempt: a slow wander
		dir = _upwind_angle(def, dir)
		var drift: float = float(g.get("drift_m", 2.0))
		var next_home: Vector3 = a["home"] + Vector3(cos(dir), 0.0, sin(dir)) * drift

		# In fog the leader's drift keeps to the wood edge too (animals_in_fog_server.md 4.5), as a lone deer's grazing hop does.
		if fog_edge_wanted(def):
			for _try in int(_fog_cfg().get("edge_tries", 3)) - 1:
				if fog_edge_ok(next_home):
					break

				dir = _upwind_angle(def, rng.randf() * TAU)   # luck-exempt: another heading along the wood edge in fog
				next_home = a["home"] + Vector3(cos(dir), 0.0, sin(dir)) * drift

		a["drift_dir"] = dir
		a["home"] = next_home
		return a["home"] + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))   # luck-exempt: where the leader stops

	var lead: Dictionary = animals[lead_id]
	var slot: int = maxi((_herds.get(a["herd"], []) as Array).find(a["id"]), 1)
	var angle: float = float(slot) * 2.39996 + float(lead.get("drift_dir", 0.0))
	a["home"] = lead["pos"] + Vector3(cos(angle), 0.0, sin(angle)) * spacing * sqrt(float(slot))
	return a["home"] + Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))   # luck-exempt: a little either way


func _herd_centre(hid: int) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0

	for mate_id in _herds.get(hid, []):
		if animals.has(mate_id):
			sum += animals[mate_id]["pos"]
			n += 1

	return sum / float(n) if n > 0 else Vector3.INF


# --- animals in weather, step 1 (docs/design/animals_in_weather_design.md; research docs/knowledge/animals-in-weather.md, Jamie) ---
# Weather tilts what an animal does through multipliers on rows that already exist; a species row's "weather" role picks which. Calm, dry
# weather (or a row with no role, or weather.on false) is exactly the behaviour without this.

func _wx_rules() -> Dictionary:
	return cfg.get("weather", {})


func _wx_on() -> bool:
	return bool(_wx_rules().get("on", false))


# The weather over an animal's spot for its step (weather_at, Dave's rule that nothing is based on where the spawn is: not the starter row
# at sea level, weather and seasons walk 23 Nov 2026): Weather.state's own dictionary, read as _wx (the same keys), and its wind. Without
# weather_at (tests) the tick's one weather stays. Cost: one cached lookup an animal step.
func _weather_for(pos: Vector3) -> void:
	if not weather_at.is_valid():
		return

	var here: Dictionary = weather_at.call(pos)

	if not is_same(here, _wx):   # the same dictionary: the last animal's row and band, nothing to change
		_wx = here
		_wind_s = float(here.get("wind", 0.0))
		_wind_dir = Vector2.from_angle(float(here.get("wind_dir", 0.0)))

	if not weather_ahead_at.is_valid() or not row_of.is_valid() or not _wx_on():
		return

	var row: int = int(row_of.call(pos))

	if not _storm_rows.has(row):
		_storm_rows[row] = _storm_in(func(hours): return weather_ahead_at.call(hours, pos))

	_storm_ahead = bool(_storm_rows[row])


# True when a storm (weather.storm_from) is due on one of weather.ahead_hours (12 to 24 game hours) by `ahead` ((hours) -> weather).
func _storm_in(ahead: Callable) -> bool:
	for hours in _wx_rules().get("ahead_hours", [12, 15, 18, 21, 24]):
		if float((ahead.call(float(hours)) as Dictionary).get("storm", 0.0)) >= float(_wx_rules().get("storm_from", 0.5)):
			return true

	return false


# This tick's weather, and every weather.ahead_every_s real seconds a look 12 to 24 game hours ahead for a storm.
func _read_weather(weather: Dictionary, delta: float) -> void:
	_wx = {"rain": float(weather.get("rain", 0.0)), "snow": float(weather.get("snow", 0.0)), "storm": float(weather.get("storm", 0.0)),
		"wind": float(weather.get("wind", 0.0)), "mist": float(weather.get("mist", 0.0)), "temp_c": float(weather.get("temp_c", 10.0)),
		"mist_depth_m": float(weather.get("mist_depth_m", 0.0)), "sea_fog_land": float(weather.get("sea_fog_land", 0.0)),
		"sea_fog_top_m": float(weather.get("sea_fog_top_m", 0.0))}
	_ahead_acc += delta

	if not _wx_on() or not (weather_ahead.is_valid() or weather_ahead_at.is_valid()) or _ahead_acc < float(_wx_rules().get("ahead_every_s", 2.5)):
		return

	_ahead_acc = 0.0
	_storm_rows.clear()   # each row looks ahead again when an animal there steps next (_weather_for)
	_storm_ahead = _storm_in(weather_ahead) if weather_ahead.is_valid() else false


# True in a storm or a heavy snowfall: most animals bed down (lesson 5).
func _wx_stormy() -> bool:
	var r: Dictionary = _wx_rules()
	return float(_wx.get("storm", 0.0)) >= float(r.get("storm_from", 0.5)) or float(_wx.get("snow", 0.0)) >= float(r.get("snowfall_from", 0.5))


# Spook and alert distances: prey are jumpier in wind (lesson 3: vigilance about doubles), x1.2 at wind 0.3, x1.4 at 0.6; mist shortens them.
func weather_spook_x(def: Dictionary) -> float:
	if not _wx_on():
		return 1.0

	var r: Dictionary = _wx_rules()
	var x: float = 1.0

	if str(def.get("weather", "")) in r.get("jumpy_roles", ["deer", "stock", "small", "bird"]):
		x *= lerpf(1.0, float(r.get("wind_spook_max", 1.4)), clampf(float(_wx.get("wind", 0.0)) / float(r.get("wind_spook_at", 0.6)), 0.0, 1.0))

	return x   # in fog the sight share does it (animals_in_fog_server.md 4.2): an unseen player is sensed by hearing and smell only


# The activity chance (spawns, rest): small animals stay in in wind, hunters hunt more in wind, a storm beds most animals down, and
# feeding animals are busier before a storm.
func weather_activity_x(def: Dictionary) -> float:
	var role: String = str(def.get("weather", ""))

	if not _wx_on() or role == "":
		return 1.0

	var r: Dictionary = _wx_rules()
	var w: float = float(_wx.get("wind", 0.0))
	var x: float = 1.0

	if role == "small":
		x *= 1.0 - (float(r.get("small_wind_cut_high", 0.65)) if w > float(r.get("small_wind_high", 0.35)) else (float(r.get("small_wind_cut", 0.25)) if w > float(r.get("small_wind_from", 0.25)) else 0.0))
	elif role == "hunter" and w > float(r.get("small_wind_from", 0.25)):
		x *= float(r.get("hunter_wind_x", 1.25))

	if _wx_stormy():
		x *= float(r.get("storm_activity_x", 0.3))
	elif _storm_ahead and role in ["bird", "small", "deer"]:
		x *= float(r.get("ahead_feed_x", 1.4))

	return x


# How far an animal wanders: a storm or a heavy snowfall keeps them close (lesson 5).
func weather_wander_x(def: Dictionary, sp: String = "") -> float:
	var x: float = fog_wander_x(def, sp)

	if not _wx_on() or str(def.get("weather", "")) == "" or not _wx_stormy():
		return x

	return minf(x, float(_wx_rules().get("storm_wander_x", 0.3)))


# --- animals in fog (docs/design/animals_in_fog_server.md; Jamie docs/knowledge/fog-and-visibility.md; MikeW ANIMAL_FOG.md; Dave's fog
# instruction 14 Nov 2026: fog cuts their sight, never their hearing) ---
# The fog at a point is Weather.fog_shape: the depth fog the client draws (rain, snow, storm, and how deep the point is in the valley fog
# over the cold-air floor or in the sea fog over the land), so server and client see one fog. V is where it takes 95 %.

func _fog_cfg() -> Dictionary:
	return _wx_rules().get("fog", {})


func fog_on() -> bool:
	return _wx_on()


# Cold-air floor windows (fog_ground.gd) round the players: a player inside a window's rebuild reach shares it, so players together read
# the tiles once; a player outside every one moves a window nobody is using, or opens a new one (at most FOG_GROUNDS_MAX).
func _fog_ground_tick(players: Array) -> void:
	if fog_world.is_empty():
		return

	# First the windows some player is already inside, then a window for each player left outside them all.
	var used: Array = []
	used.resize(_fog_grounds.size())
	used.fill(false)
	var outside: Array = []

	for p in players:
		var here: Vector2 = Vector2(p.x, p.z)
		var inside: bool = false

		for i in range(_fog_grounds.size()):
			if here.distance_to(_fog_grounds[i].centre()) < FogGroundScript.REBUILD_M:
				used[i] = true
				inside = true

		if not inside:
			outside.append(p)

	for p in outside:
		var here: Vector2 = Vector2(p.x, p.z)
		var have: int = -1

		for i in range(_fog_grounds.size()):      # a window moved for an earlier player this tick may hold this one too
			if used[i] and here.distance_to(_fog_grounds[i].centre()) < FogGroundScript.REBUILD_M:
				have = i
				break

		if have == -1:
			for i in range(_fog_grounds.size()):
				if not used[i] and not _fog_grounds[i].busy():
					have = i
					break

		if have == -1 and _fog_grounds.size() < FOG_GROUNDS_MAX:
			var ground = FogGroundScript.new()
			ground.tiles_dir = str(fog_world.get("tiles_dir", ground.tiles_dir)).trim_suffix("/")
			ground.tile_size_m = float(fog_world.get("tile_size_m", ground.tile_size_m))
			ground.who = "server"
			_fog_grounds.append(ground)
			used.append(false)
			have = _fog_grounds.size() - 1

		if have != -1:
			used[have] = true
			_fog_grounds[have].update(p)     # starts a read centred on this player (a moved window keeps its old floor until it lands)

	for ground in _fog_grounds:
		ground.poll()


# The server is closing: wait for a read still running.
func fog_ground_finish() -> void:
	for ground in _fog_grounds:
		ground.finish()


# The cold-air floor under a point: from the window it lies deepest inside (a window's edge cells see only part of the low ground
# round them); sea level where no window holds it (the old single layer).
func fog_floor(pos: Vector3) -> float:
	var best: float = -1.0
	var floor_m: float = 0.0

	for ground in _fog_grounds:
		var margin: float = FogGroundScript.margin(ground.grid, pos.x, pos.z)

		if margin > best:
			best = margin
			floor_m = FogGroundScript.sample(ground.grid, "floor", pos.x, pos.z, 0.0)

	return floor_m


# Ground below sea level here cut off from the open sea (fog_ground.gd under_land, from the window the point lies deepest inside): not the
# sea (the fen flats, Lane A 22 Nov 2026). False where no window holds it: the old rule, all ground at or under 0 m is sea.
func sea_cut_off(x: float, z: float) -> bool:
	var best: float = -1.0
	var cut: bool = false

	for ground in _fog_grounds:
		var margin: float = FogGroundScript.margin(ground.grid, x, z)

		if margin > best:
			best = margin
			cut = ground.under_land(x, z)

	return cut


# The fog's shape at a point (fog_shape.gd).
func fog_shape_at(pos: Vector3) -> Vector3:
	return WeatherRules.fog_shape(_wx, pos.y, fog_floor(pos))


# The fog's strength along a line of sight (Weather.fog_strength_along: the share of the line under each layer's top; the floor is
# the animal's end, the nearer one): a deer in the valley fog looking up at a player on the clear slope sees through only the fog
# below the top.
func fog_strength_between(from_pos: Vector3, to_pos: Vector3) -> float:
	return WeatherRules.fog_strength_along(_wx, from_pos.y, to_pos.y, fog_floor(from_pos))


func fog_shape_between(from_pos: Vector3, to_pos: Vector3) -> Vector3:
	return FogShape.depth(WeatherRules.fog_haze_density(_wx), fog_strength_between(from_pos, to_pos))


# V at a point (rain and snow thicken it too). Vector3.INF: the fog's own V deep inside it, from the valley or sea fog alone, for the
# rules with no animal position (activity, wander), so heavy rain alone does not make deer keep fog hours.
func fog_v(pos: Vector3 = Vector3.INF) -> float:
	if pos == Vector3.INF:
		return WeatherRules.visibility_m({"mist": float(_wx.get("mist", 0.0)), "mist_depth_m": 0.0, "sea_fog_land": float(_wx.get("sea_fog_land", 0.0)), "sea_fog_top_m": 0.0}, -1.0e9)

	return FogShape.visibility(fog_shape_at(pos))


# How much of a player an animal can make out at distance d through fog of this shape (Jamie lesson 1, on Dave's fog): all of it while
# the fog takes under `full` of the view (detail), none once it takes `gone` (it can no longer tell a person from a stump), straight
# between. In full fog that is all to about 31 m and nothing past about 42 m, his "silhouettes at 20 to 40 m".
static func fog_sight_share(d: float, shape: Vector3, full: float = 0.53, gone: float = 0.78) -> float:
	return FogShape.sight_share(d, shape, full, gone)


# Wander in fog (4.4 and 4.6): birds sit it out under sit_below_m, herds stay close under deer_v_m.
func fog_wander_x(def: Dictionary, sp: String = "") -> float:
	if not fog_on():
		return 1.0

	var fc: Dictionary = _fog_cfg()
	var role: String = str(def.get("weather", ""))
	var v: float = fog_v()

	if (role == "bird" or sp in fc.get("sit_species", ["goose", "duck", "seabird"])) and v < float(fc.get("sit_below_m", 180.0)):
		return float(fc.get("bird_wander_x", 0.15))

	if role in ["stock", "deer"] and v < float(fc.get("deer_v_m", 1000.0)):
		return float(fc.get("herd_x", 0.5))

	return 1.0


# A herd's pull to its centre in fog (4.6): stock and deer keep half their clear-day distance.
func fog_herd_x(def: Dictionary) -> float:
	if not fog_on() or not str(def.get("weather", "")) in ["stock", "deer"] or fog_v() >= float(_fog_cfg().get("deer_v_m", 1000.0)):
		return 1.0

	return float(_fog_cfg().get("herd_x", 0.5))


# A perched bird sits out thick fog (4.4); server_flight asks this before it comes down.
func fog_grounded(pos: Vector3) -> bool:
	return fog_on() and fog_v(pos) < float(_fog_cfg().get("sit_below_m", 180.0))


# The ring a shadowing wolf pack keeps (4.3): min(stalk_m, max(V/2, wolf_min_m)) at the player.
func fog_stalk_m(stalk_m: float, at: Vector3) -> float:
	return fog_ring_m(stalk_m, fog_v(at), float(_fog_cfg().get("wolf_min_m", 10.0))) if fog_on() else stalk_m


static func fog_ring_m(stalk_m: float, v: float, min_m: float) -> float:
	return minf(stalk_m, maxf(v * 0.5, min_m))


# Deer keep their dawn hours longer on a foggy morning (4.5): 08:00 to 08:00 + deer_late_h count as dusk while the fog's V is under deer_v_m.
func fog_period(def: Dictionary, hour: float) -> String:
	var period: String = period_now(hour)

	if period != "day" or not fog_on() or str(def.get("weather", "")) != "deer" or fog_v() >= float(_fog_cfg().get("deer_v_m", 1000.0)):
		return period

	var day_from: float = sunrise_hour() + 2.0   # 08:00 at the equinox
	return "dusk" if hour >= day_from and hour < day_from + float(_fog_cfg().get("deer_late_h", 1.5)) else period


# A deer's grazing hop in fog keeps to the wood edge (4.5): open ground with tree crowns within edge_m in one of four directions.
func fog_edge_ok(target: Vector3) -> bool:
	if not canopy.is_valid() or bool(canopy.call(target)):
		return false

	var m: float = float(_fog_cfg().get("edge_m", 15.0))

	for off in [Vector3(m, 0.0, 0.0), Vector3(-m, 0.0, 0.0), Vector3(0.0, 0.0, m), Vector3(0.0, 0.0, -m)]:
		if bool(canopy.call(target + off)):
			return true

	return false


func fog_edge_wanted(def: Dictionary) -> bool:
	return fog_on() and canopy.is_valid() and str(def.get("weather", "")) == "deer" and fog_v() < float(_fog_cfg().get("deer_v_m", 1000.0))


# Deer and hunters graze and travel facing into a light or moderate wind (lesson 2): most wander targets lie within upwind_spread of upwind.
func _upwind_angle(def: Dictionary, angle: float) -> float:
	var r: Dictionary = _wx_rules()

	if not _wx_on() or not str(def.get("weather", "")) in ["deer", "hunter"] or _wind_s <= 0.0 or _wind_s >= float(r.get("gale_from", 0.6)):
		return angle

	if rng.randf() >= float(r.get("upwind_share", 0.7)):   # luck-exempt: whether this hop goes into the wind
		return angle

	var spread: float = deg_to_rad(float(r.get("upwind_spread_deg", 40.0)))
	return _wind_dir.angle() + PI + rng.randf_range(-spread, spread)   # luck-exempt: as above


# A small animal in wind goes down its burrow when its grazing spell ends, with the chance its activity was cut by (lesson 3).
func _wind_goes_down(a: Dictionary, def: Dictionary) -> bool:
	if not _wx_on() or str(def.get("weather", "")) != "small" or a.get("burrow", Vector3.INF) == Vector3.INF:
		return false

	var r: Dictionary = _wx_rules()
	var w: float = float(_wx.get("wind", 0.0))
	var cut: float = float(r.get("small_wind_cut_high", 0.65)) if w > float(r.get("small_wind_high", 0.35)) else (float(r.get("small_wind_cut", 0.25)) if w > float(r.get("small_wind_from", 0.25)) else 0.0)

	if cut <= 0.0 or rng.randf() >= cut:   # luck-exempt: whether a rabbit stays in out of the wind
		return false

	var to_b: Vector2 = Vector2(a["burrow"].x - a["pos"].x, a["burrow"].z - a["pos"].z)

	if to_b.length() > float(def.get("burrow_m", 0.0)) * 2.0:
		return false

	a["target"] = a["burrow"]
	a["to_burrow"] = true
	a["state"] = HOP
	return true



# The sentinel (the first to notice) alarms the herd: each mate follows after a short random moment; and its alarm group (ground birds).
func _alarm_herd(a: Dictionary, def: Dictionary) -> void:
	if a["herd"] != 0:
		var span: Array = def.get("alarm_s", [0.2, 0.9])

		for mate_id in _herds.get(a["herd"], []):
			if mate_id != a["id"] and animals.has(mate_id) and animals[mate_id]["state"] != FLEE and animals[mate_id]["state"] != HIDDEN and animals[mate_id]["alarm"] < 0.0:
				animals[mate_id]["alarm"] = rng.randf_range(float(span[0]), float(span[1]))   # luck-exempt: how fast a herd mate reacts

	if def.has("alarm_group"):
		_alarm_group(a, def)


# --- the player's dog as a presence (dog_companion_design.md 11; MikeW, docs/design/DOG_REACTIONS.md) ---

# The companion dogs out in the world this tick: [animal id, position, barking (it barked within dogs.bark_s)].
func _dog_presences() -> Array:
	var out: Array = []
	var bark_ms: int = int(float(cfg.get("dogs", {}).get("bark_s", 3.0)) * 1000.0)
	var now_ms: int = Time.get_ticks_msec()

	for id in animals:
		var d: Dictionary = animals[id]

		if d.has("companion_id") and str(d["sp"]) in cfg.get("dogs", {}).get("species", ["dog"]) and not bool(d.get("young", false)):
			out.append([int(id), d["pos"], now_ms - int(d.get("bark_ms", -1000000)) < bark_ms])

	return out


# The nearest dog as this animal senses it (the wind's scent and the ground as for a player, never crouched; a barking dog is heard
# dogs.bark_x farther): [sensed distance, position, dog id, barking], or [] for none within reach.
func _dog_sensed(a: Dictionary, def: Dictionary, reach: float) -> Array:
	var best: Array = []
	var bark_x: float = float(cfg.get("dogs", {}).get("bark_x", 2.0))

	for dog in _dogs:
		var p: Vector3 = dog[1]
		var d: float = Vector2(p.x - a["pos"].x, p.z - a["pos"].z).length()

		if d > reach * bark_x or d < 0.01:
			continue

		var sensed: float = d / (_sense_factor(a, def, p, d, 0) * (bark_x if bool(dog[2]) else 1.0))

		if best.is_empty() or sensed < float(best[0]):
			best = [sensed, p, int(dog[0]), bool(dog[2])]

	return best


# How a wild animal meets a dog, by its species' dog row: "flee" (within flee_m it bolts, alarming its herd; within notice_m it watches),
# "stand" (within notice_m it warns at the dog, and charges it once the dog comes within attack_m: big_game with the dog as the foe;
# young_only: only a mother with young stands, otherwise it flees). True when the dog decided this step.
func _dog_react(a: Dictionary, def: Dictionary, seen_d: float = INF) -> bool:
	if _dogs.is_empty() or a["state"] == FLEE or a["state"] == HIDDEN or seen_d <= _spook_m(a, def):
		return false   # a player close enough to spook it comes first

	var row: Dictionary = def["dog"]
	var notice: float = float(row.get("notice_m", 30.0))
	var near: Array = _dog_sensed(a, def, notice)

	if near.is_empty() or float(near[0]) > notice:
		return false

	var at: Vector3 = near[1]
	var reaction: String = str(row.get("reaction", "flee"))

	if reaction == "stand" and bool(row.get("young_only", false)) and _young_of(a).is_empty():
		reaction = "flee"

	if reaction == "stand" and big_game != null:
		if big_game.warn(a, at, float(row.get("warn_s", -1.0)), true):
			a["foe_dog"] = int(near[2])
			return true

		return false

	if float(near[0]) <= float(row.get("flee_m", notice * 0.66)):
		_bolt(a, at, def)
		_alarm_herd(a, def)
		return true

	if a["state"] == GRAZE or a["state"] == HOP or a["state"] == ALERT:
		a["state"] = ALERT   # it watches the dog while it is within notice_m (a player near is still handled by the ALERT rules next step)
		a["alert"] = maxf(float(a.get("alert", 0.0)), 1.0)
		a["heading"] = atan2(at.z - a["pos"].z, at.x - a["pos"].x)
		return true

	return false


# The barking dogs within `radius` of a point (goblins back off from them): [[position, dog id], ...].
func barking_dogs_near(point: Vector3, radius: float) -> Array:
	var out: Array = []

	for dog in _dogs:
		var p: Vector3 = dog[1]

		if bool(dog[2]) and Vector2(p.x - point.x, p.z - point.z).length() <= radius:
			out.append([p, int(dog[0])])

	return out


# --- animals in weather, step 2: rain cover, the hunch, gales (animals_in_weather_design.md 6 and 7) ---

func _raining() -> bool:
	return _wx_on() and float(_wx.get("rain", 0.0)) >= float(_wx_rules().get("rain_from", 0.4))


func _gale() -> bool:
	return _wx_on() and (float(_wx.get("wind", 0.0)) >= float(_wx_rules().get("gale_from", 0.6)) or float(_wx.get("storm", 0.0)) >= float(_wx_rules().get("storm_from", 0.5)))


# Whether this animal looks for cover now: deer always in rain or a gale, and in the cold (to conifers); stock in rain half of them (by id:
# the same half every time), and all of them in midday heat (to shade).
# With herd groups on (MikeW's HERD_GROUPS.md, #663), only the herd's leader (its first living member) picks the cover; the rest keep their
# places round it and so come along.
func _seeks_cover(a: Dictionary, def: Dictionary) -> bool:
	var role: String = str(def.get("weather", ""))

	if int(a.get("herd", 0)) != 0 and bool((cfg.get("groups", {}) as Dictionary).get("enabled", false)):
		for id in _herds.get(a["herd"], []):
			if animals.has(id):
				if int(id) != int(a["id"]):
					return false

				break

	if role == "deer":
		return _raining() or _gale() or _cold(a)

	return role == "stock" and ((_raining() and int(a["id"]) % 2 == 0) or _hot(a))


# The air at an animal (step 3): the weather's seasonal temperature less the lapse with its height (no day and night swing on the server
# side of animals yet).
func _air_c(a: Dictionary) -> float:
	if air_at.is_valid():   # the one temperature (#620): the zone's own air at the animal's height, less the rain's cooling as in Weather.state
		return float(air_at.call(a["pos"])) - WeatherRules.RAIN_COOL_C * float(_wx.get("rain", 0.0))

	if weather_at.is_valid():
		return float(_wx.get("temp_c", 10.0))   # weather_at's air is the air at the animal's own height band already

	return float(_wx.get("temp_c", 10.0)) - maxf(a["pos"].y, 0.0) * float(_wx_rules().get("lapse_c_per_m", 0.0065))


# Cold for deer (design 9, lesson 2): air below cold_c (-5 C), or snow falling at snow_cold_from or more (lying snow has no server model yet:
# Sonny's A4 baked snow window will give it).
func _cold(a: Dictionary) -> bool:
	return _wx_on() and (_air_c(a) < float(_wx_rules().get("cold_c", -5.0)) or float(_wx.get("snow", 0.0)) >= float(_wx_rules().get("snow_cold_from", 0.3)))


# Midday heat for stock (design 9, lesson 8): air above hot_c (22 C) between heat_hours (11 to 16).
func _hot(a: Dictionary) -> bool:
	if not _wx_on() or _air_c(a) <= float(_wx_rules().get("hot_c", 22.0)) or not hour_now.is_valid():
		return false

	var hours: Array = _wx_rules().get("heat_hours", [11.0, 16.0])
	var h: float = float(hour_now.call())
	return h >= float(hours[0]) and h < float(hours[1])


# Every grazing step: stock in a gale face downwind (rumps to the wind); one game hour (cover_return_s real seconds) after the weather that
# sent it to cover has passed, an animal walks back to its old home.
func _weather_graze(a: Dictionary, def: Dictionary, dt: float) -> void:
	if not _wx_on() or str(def.get("weather", "")) == "":
		return

	if str(def.get("weather", "")) == "stock" and _gale() and _wind_s > 0.0:
		a["heading"] = _wind_dir.angle()

	if a.has("dry_home"):
		if _seeks_cover(a, def):
			a["dry_s"] = 0.0
		else:
			a["dry_s"] = float(a.get("dry_s", 0.0)) + dt

			if float(a["dry_s"]) >= float(_wx_rules().get("cover_return_s", 150.0)):
				a["home"] = a["dry_home"]
				a.erase("dry_home")
				a.erase("dry_s")

	if a.has("hunch") and not _raining():
		a.erase("hunch")

	# HUNCH in cover (design 11, MikeW's ANIMAL_WEATHER_LOOKS.md): a deer or stock animal grazing in its cover stands hunched for as long as the
	# rain, a gale or the cold lasts: within cover_stand_m of the cover home it moved to, or under tree crowns (a herd follower round its
	# leader). Midday heat in the shade is not a hunch.
	var role: String = str(def.get("weather", ""))
	var foul: bool = role in ["deer", "stock"] and (_raining() or _gale() or _cold(a))
	var stand_m: float = float(_wx_rules().get("cover_stand_m", 8.0))
	var at_cover: bool = a.has("dry_home") and Vector2(a["pos"].x - a["home"].x, a["pos"].z - a["home"].z).length() <= stand_m

	if foul and (at_cover or (canopy.is_valid() and bool(canopy.call(a["pos"])))):
		a["sheltered"] = true
	else:
		a.erase("sheltered")


# When a grazing spell ends in bad weather. True when the weather chose what it does next:
#   rain: deer and stock spend hunch_share of their spells standing still (HUNCH on the wire) instead of moving on (lesson 1: -62% feeding);
#   rain or a gale: an animal that seeks cover moves its home to the nearest spot under tree crowns within cover_m (deer in a gale with no
#     trees: the lowest ground), once a spell of weather;
#   a gale: stock drift downwind at drift_mps, rumps to the wind (lesson 7).
func _weather_wander(a: Dictionary, def: Dictionary) -> bool:
	var role: String = str(def.get("weather", ""))

	if not _wx_on() or not role in ["deer", "stock"]:
		return false

	var r: Dictionary = _wx_rules()

	if _seeks_cover(a, def) and not a.has("dry_home"):
		var cold: bool = role == "deer" and _cold(a) and not _raining() and not _gale()
		var cover: Vector3 = _cover_near(a, role == "deer" and (_gale() or cold), cold)

		if cover != Vector3.INF:
			a["dry_home"] = a["home"]
			a["dry_s"] = 0.0
			a["home"] = cover
			a["target"] = cover
			a["state"] = HOP
			a.erase("hunch")
			return true

	if role == "stock" and _gale() and _wind_s > 0.0:
		a["timer"] = _graze_time(def)
		a["target"] = a["pos"] + Vector3(_wind_dir.x, 0.0, _wind_dir.y) * float(r.get("drift_mps", 0.05)) * float(a["timer"])
		a["home"] = a["target"]
		a["state"] = HOP
		a.erase("hunch")
		return true

	if _raining() and not _group_strayed(a, def):   # a herd member far from its place goes back to the herd first, rain or not (HERD_GROUPS.md)
		a["hunch"] = rng.randf() < float(r.get("hunch_share", 0.6))   # luck-exempt: whether a wet grazer stands this spell out

		if bool(a["hunch"]):
			a["timer"] = _graze_time(def)
			return true

	return false


# The nearest spot under tree crowns in 8 directions at 25, 50, 75 and 100 m (cover_m); with `conifer`, only crowns in a conifer biome
# (weather.conifer_biomes); with `or_low`, the lowest of those spots when none is under trees. Vector3.INF for none.
func _cover_near(a: Dictionary, or_low: bool, conifer: bool = false) -> Vector3:
	var conifers: Array = _wx_rules().get("conifer_biomes", ["boreal_forest", "mixed_forest"])
	var reach: float = float(_wx_rules().get("cover_m", 100.0))
	var low: Vector3 = Vector3.INF

	for ring in 4:
		var d: float = reach * float(ring + 1) / 4.0

		for k in 8:
			var dir: Vector2 = Vector2.from_angle(TAU * float(k) / 8.0)
			var p: Vector3 = Vector3(a["pos"].x + dir.x * d, 0.0, a["pos"].z + dir.y * d)
			p.y = float(ground_height.call(p.x, p.z)) if ground_height.is_valid() else a["pos"].y

			if blocked.is_valid() and bool(blocked.call(p.x, p.z)):
				continue

			if canopy.is_valid() and bool(canopy.call(p)) and (not conifer or (biome_at.is_valid() and str(biome_at.call(p.x, p.z)) in conifers)):
				return p

			if or_low and p.y < a["pos"].y - 1.0 and (low == Vector3.INF or p.y < low.y):
				low = p

	return low


# --- animals at water (docs/design/animals_at_water_server.md; MikeW ANIMAL_DRINK.md; Steve's drinking_water_design.md, #719) ---
# Behind animals.json drink.on. At dawn and dusk (the "dusk" period) a deer or stock animal walks, with the chance drink.chance once a
# twilight, to the nearest fresh water's edge within reach_m of its home, stands there stand_s drinking (DRINK on the wire, GRAZE here),
# then goes home. A wolf pack prowls at the water nearest its home at those hours, where the prey must come.

func _drink_cfg() -> Dictionary:
	return cfg.get("drink", {})


func drink_on() -> bool:
	return water_level.is_valid()


func _twilight() -> bool:
	return hour_now.is_valid() and period_now(float(hour_now.call())) == "dusk"


# Fresh open water at a spot: a water surface over ground above the sea (salt water is never a drink, #719).
func _fresh_wet(x: float, z: float) -> bool:
	var level: float = float(water_level.call(x, z))

	if is_nan(level) or not ground_height.is_valid():
		return false

	var ground: float = float(ground_height.call(x, z))
	return not is_nan(ground) and ground > 0.0 and level > ground + float(_drink_cfg().get("wet_m", 0.05))


# The nearest fresh water's edge from `from` within `reach` m: rings ring_m apart in `bearings` directions, the first wet sample on the
# nearest ring, then stepped back toward `from` 2 m at a time (up to a ring) to dry ground. [stand spot, water point], or [] for none. Kept per 50 m
# cell for cache_s real seconds (one search serves a herd).
func drink_spot(from: Vector3, reach: float) -> Array:
	var dc: Dictionary = _drink_cfg()
	var key: Vector3i = Vector3i(floori(from.x / 50.0), floori(from.z / 50.0), floori(reach))
	var now: int = Time.get_ticks_msec()

	if _water_spots.has(key) and now - int(_water_spots[key][1]) < int(float(dc.get("cache_s", 600.0)) * 1000.0):
		return _water_spots[key][0]

	var found: Array = _spring_spot(from, reach, dc)   # a spring first (spring_heads_lower_design.md 3): a runnel is too narrow for the rings
	var ring_m: float = maxf(float(dc.get("ring_m", 25.0)), 5.0)
	var bearings: int = maxi(int(dc.get("bearings", 8)), 4)

	for ring in (range(1, int(reach / ring_m) + 1) if found.is_empty() else []):
		for b in bearings:
			var ang: float = TAU * float(b) / float(bearings)
			var dir: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
			var wet: Vector3 = from + dir * ring_m * float(ring)

			if not _fresh_wet(wet.x, wet.z):
				continue

			var stand: Vector3 = wet

			for _hop in int(ceil(ring_m / 2.0)) + 1:
				stand -= dir * 2.0

				if not _fresh_wet(stand.x, stand.z):
					stand.y = float(ground_height.call(stand.x, stand.z))
					found = [stand, wet]
					break

			if not found.is_empty():
				break

		if not found.is_empty():
			break

	_water_spots[key] = [found, now]
	return found


# The nearest ground spring within reach of `from` as [stand spot, the head]: the stand is spring_stand_m out from the head toward `from`,
# on the dry side. [] when there is none (or no springs are known).
func _spring_spot(from: Vector3, reach: float, dc: Dictionary) -> Array:
	if not springs_near.is_valid():
		return []

	var best: Vector3 = Vector3.INF
	var best_d: float = INF

	for head in springs_near.call(from, reach):
		var d: float = Vector2(head.x - from.x, head.z - from.z).length()

		if d <= reach and d < best_d:
			best_d = d
			best = head

	if best == Vector3.INF:
		return []

	var back: Vector3 = Vector3(from.x - best.x, 0.0, from.z - best.z)
	back = back.normalized() if back.length() > 0.01 else Vector3.RIGHT
	var stand: Vector3 = best + back * float(dc.get("spring_stand_m", 4.0))
	stand.y = float(ground_height.call(stand.x, stand.z)) if ground_height.is_valid() else best.y
	return [stand, best, true]


func _drink_done(a: Dictionary) -> void:
	a["home"] = a["drink_home"]

	for key in ["drink_home", "drink_at", "drink_to", "drinking", "drink_legs", "drink_spring"]:
		a.erase(key)


# Daily trips (docs/design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md; data/animals/ranges.json clock): an animal made at a place (a warren, a
# deer range) has a home spot and an out spot and the trail between them. At its species' hours it walks the trail out (a rabbit to its
# grazing, a deer to its feeding ground) and back home, point by point with the normal step, so it never slides or jumps. The daily
# shares of lying and feeding at each spot stay the "active" rows'. In a herd group the leader's clock decides for all, so they go
# together, one after another as each one's grazing pause ends (single file along the trail).
func _clock(sp: String) -> Dictionary:
	if ranges == null or not ranges.on():
		return {}

	return (ranges.cfg.get("clock", {}) as Dictionary).get(sp, {})


# Whether the clock has this animal (or its herd group's leader) out now, on its own fixed share of jitter_h either side.
func wants_out(a: Dictionary) -> bool:
	var who: Dictionary = a

	if a["herd"] != 0 and _groups_on():
		var lead: int = _group_leader(a["herd"])

		if lead != 0:
			who = animals[lead]

	var ck: Dictionary = _clock(str(who["sp"]))

	if ck.is_empty() or not hour_now.is_valid():
		return false

	var hour: float = float(hour_now.call())
	var shift: float = (fposmod(float(who["id"]) * 0.7548776, 1.0) - 0.5) * 2.0 * float(ck.get("jitter_h", 0.0))
	var out_h: float = float(ck.get("out_hour", 18.0))
	var home_h: float = float(ck.get("home_hour", 8.0))

	if sunrise_now.is_valid() and ck.has("out_after_sunset_h") and ck.has("home_after_sunrise_h"):   # on the real sun (stage 2a)
		out_h = 24.0 - sunrise_hour() + float(ck["out_after_sunset_h"])
		home_h = sunrise_hour() + float(ck["home_after_sunrise_h"])

	out_h = fposmod(out_h + shift, 24.0)
	home_h = fposmod(home_h + shift, 24.0)

	if out_h > home_h:
		return hour >= out_h or hour < home_h

	return hour >= out_h and hour < home_h


# Starts the walk home or out when the clock asks and the animal is not already there: the trail from its point nearest the animal
# to the spot, then a few metres off the end (its own spot there, so a group does not stand in one place). True when it set off.
func routine_trip(a: Dictionary) -> bool:
	if not a.has("place") or not hour_now.is_valid() or a.has("drink_home"):
		return false   # a deer gone to the water finishes its drink first (its home comes back with it)

	var out: bool = wants_out(a)

	if a.has("lured"):
		if bool(a["lured"]) == out:
			return false   # still at the snare that drew it until its clock turns

		a.erase("lured")

	var pl: Dictionary = a["place"]

	if out and pl.has("rounds"):   # a fox: tonight's round, a different one from last night's (it keeps no fixed trail, stage 2b)
		var rounds: Array = pl["rounds"]
		pl["route"] = rounds[posmod(_night() + int(hash(str(pl["id"]))), rounds.size())]   # by the night, so midnight does not send it on a second round

	var route: PackedVector2Array = pl["route"]
	var goal: Vector2 = route[route.size() - 1] if out else route[0]
	var near_m: float = float((ranges.cfg.get("clock", {}) as Dictionary).get("near_m", 10.0))

	if Vector2(a["home"].x, a["home"].z).distance_to(goal) <= near_m:
		return false

	var at: Vector2 = Vector2(a["pos"].x, a["pos"].z)
	var nearest: int = 0
	var best: float = INF

	for i in route.size():
		var d: float = at.distance_squared_to(route[i])

		if d < best:
			best = d
			nearest = i

	var trip: PackedVector2Array = PackedVector2Array()

	if out:
		for i in range(nearest, route.size()):
			trip.append(route[i])
	else:
		for i in range(nearest, -1, -1):
			trip.append(route[i])

	var spread: float = float(species_def(str(a["sp"])).get("group_spacing_m", 2.0)) * 1.5
	var turn: float = fposmod(float(a["id"]) * 2.39996, TAU)
	trip.append(goal + Vector2(cos(turn), sin(turn)) * spread * fposmod(float(a["id"]) * 0.381966, 1.0))
	a["trip"] = trip
	a["trip_i"] = 0
	_trip_next(a)
	return true


func _trip_next(a: Dictionary) -> void:
	var p: Vector2 = a["trip"][int(a["trip_i"])]
	var y: float = float(ground_height.call(p.x, p.y)) if ground_height.is_valid() else a["pos"].y
	a["target"] = Vector3(p.x, a["pos"].y if is_nan(y) else y, p.y)
	a["trip_at"] = a["target"]
	a["state"] = HOP


# Within a metre of the trail point it is making for, it makes for the next one instead: the walk flows on along the trail without the
# stop an arrival would make (Steering stands still the step it arrives).
func _trip_ahead(a: Dictionary) -> void:
	if a.get("trip_at", Vector3.INF) != a["target"]:
		return

	var trip: PackedVector2Array = a["trip"]

	while int(a["trip_i"]) < trip.size() - 1 and Vector2(a["pos"].x - a["target"].x, a["pos"].z - a["target"].z).length() <= 1.0:
		a["trip_i"] = int(a["trip_i"]) + 1
		_trip_next(a)


# A step of a trip ended: on to the next trail point, or home at the end (or where it is, when something stopped it). True while
# the trip goes on. A target set by anything else (a lure, a stalk) ends the trip.
func _trip_step(a: Dictionary, r: Dictionary) -> bool:
	if a.get("trip_at", Vector3.INF) != a["target"]:
		a.erase("trip")
		return false

	if r["arrived"]:
		a["trip_i"] = int(a["trip_i"]) + 1

		if int(a["trip_i"]) < (a["trip"] as PackedVector2Array).size():
			_trip_next(a)
			return true

	elif r["moved"]:
		return true

	a.erase("trip")
	a["home"] = a["pos"]   # there (or stopped by a wall or water on the way: it grazes here and tries again later)
	return false


# The game day (0 without a clock): which run a warren's or a range's group takes.
func _day() -> int:
	return int(floor(float(game_seconds.call()) / 86400.0)) if game_seconds.is_valid() else 0


# The game night, turning at noon (0 without a clock): which round a fox walks, the same one from dusk to dawn across midnight.
func _night() -> int:
	return int(floor((float(game_seconds.call()) - 43200.0) / 86400.0)) if game_seconds.is_valid() else 0


# Makes a group of a species with a daily clock at a free place near the player: at its home spot or out spot as its clock has it,
# outside never_within_m of every player and off settled ground. True when the ground round the player is worked out (whether or not
# a place was free), so the species is then only ever made at its places; false to let the old random spot do (no ranges, not ready).
func _place_spawn(sp: String, def: Dictionary, p: Vector3, players: Array, room: int) -> bool:
	if _clock(sp).is_empty() or not ranges.is_ready(ranges.block_of(p.x, p.z)):
		return false

	var never: float = float(cfg.get("never_within_m", 60.0))
	var taken: Dictionary = {}

	for id in animals:
		if animals[id].has("place"):
			taken[str(animals[id]["place"]["id"])] = true

	var day: int = _day()

	for place in ranges.places_near(sp, p, float(cfg.get("spawn_max_m", 250.0))):
		var routes: Array = place["routes"]
		var run: int = posmod((day if bool(place.get("drawn", true)) else _night()) + int(hash(str(place["id"]))), routes.size())   # a warren's group takes a different run each day, a fox tonight's round

		if taken.has(str(place["id"])):
			continue   # one group a place

		var route: PackedVector2Array = routes[run]
		var probe: Dictionary = {"id": _next_id, "sp": sp, "herd": 0}
		var spot: Vector2 = route[route.size() - 1] if wants_out(probe) else route[0]
		var clear: bool = not no_spawn_at(spot.x, spot.y) and not (blocked.is_valid() and bool(blocked.call(spot.x, spot.y)))

		for q in players:
			clear = clear and Vector2(q.x - spot.x, q.z - spot.y).length() >= never

		# Out of sight as a rule (spawn_min_m), now and then nearer (near_share), as the random spots do.
		if clear and Vector2(p.x - spot.x, p.z - spot.y).length() < float(cfg.get("spawn_min_m", 150.0)) and rng.randf() >= float(cfg.get("near_share", 0.0)):   # luck-exempt: where wildlife appears, no outcome for the player
			continue

		if not clear:
			continue

		var herd: Array = def.get("herd", [])
		var members: int = clampi(rng.randi_range(int(herd[0]), int(herd[1])), 1, maxi(room, 1)) if not herd.is_empty() else 1   # luck-exempt: how many in a group
		var hid: int = 0

		if members > 1:
			hid = _next_herd
			_next_herd += 1
			_herds[hid] = []

		var warren: Vector2 = route[0]

		for k in members:
			var sx: float = spot.x + rng.randf_range(-3.0, 3.0)   # luck-exempt: where each of the group stands
			var sz: float = spot.y + rng.randf_range(-3.0, 3.0)   # luck-exempt: as above

			if no_spawn_at(sx, sz):
				continue

			var id: int = spawn(sp, sx, sz)

			if id == 0:
				continue

			animals[id]["place"] = {"id": str(place["id"]), "route": route}

			if not bool(place.get("drawn", true)):
				animals[id]["place"]["rounds"] = routes   # a fox: one of its rounds each night

			animals[id]["home"] = animals[id]["pos"]

			if animals[id]["burrow"] != Vector3.INF:
				var bx: float = warren.x + rng.randf_range(-2.0, 2.0)   # luck-exempt: which hole of the warren is its own
				var bz: float = warren.y + rng.randf_range(-2.0, 2.0)   # luck-exempt: as above
				var by: float = float(ground_height.call(bx, bz)) if ground_height.is_valid() else animals[id]["pos"].y
				animals[id]["burrow"] = Vector3(bx, animals[id]["pos"].y if is_nan(by) else by, bz)

			if hid != 0:
				animals[id]["herd"] = hid
				_herds[hid].append(id)

		return true

	return true



# A grazing spell has ended: start, continue or end a walk to water (true when it set the next target or stand).
func _drink_wander(a: Dictionary, def: Dictionary) -> bool:
	var dc: Dictionary = _drink_cfg()

	if not drink_on() or not str(def.get("weather", "")) in dc.get("roles", ["deer", "stock"]) or a.has("companion_id"):
		return false

	if not _twilight():
		a.erase("drank")

		if a.has("drink_home"):
			_drink_done(a)

		return false

	if a.has("drink_home"):
		var spot: Vector3 = a["drink_at"]

		if bool(a.get("drinking", false)) or int(a.get("drink_legs", 0)) >= int(dc.get("max_legs", 12)):
			_drink_done(a)   # drunk its fill, or it cannot get there: home
			return false

		if Vector2(a["pos"].x - spot.x, a["pos"].z - spot.z).length() <= float(dc.get("near_m", 4.0)):
			var to: Vector3 = a["drink_to"]
			var stand: Array = dc.get("stand_s", [60.0, 180.0])
			a["drinking"] = true
			a["state"] = GRAZE
			a["target"] = a["pos"]
			a["heading"] = atan2(to.z - a["pos"].z, to.x - a["pos"].x)
			a["timer"] = rng.randf_range(float(stand[0]), float(stand[1]))   # luck-exempt: how long an animal stands at the water

			if bool(a.get("drink_spring", false)):
				var graze: Array = dc.get("spring_graze_s", [120.0, 300.0])
				a["timer"] += rng.randf_range(float(graze[0]), float(graze[1]))   # luck-exempt: the green round a spring holds it to graze a while
			return true

		a["drink_legs"] = int(a.get("drink_legs", 0)) + 1
		a["target"] = spot
		a["state"] = HOP
		return true

	if a.has("drank"):
		return false

	a["drank"] = true

	if rng.randf() >= float(dc.get("chance", 0.7)):   # luck-exempt: whether an animal goes to water this twilight
		return false

	var found: Array = drink_spot(a["home"], float(dc.get("reach_m", 300.0)))

	if found.is_empty():
		return false

	# Spread along the bank, across the line to the water, and never into it (a jitter toward the water stood some in it).
	var to_water: Vector3 = found[1] - found[0]
	to_water.y = 0.0
	var along: Vector3 = Vector3(-to_water.z, 0.0, to_water.x).normalized() if to_water.length() > 0.01 else Vector3.RIGHT
	var stand_at: Vector3 = found[0] + along * rng.randf_range(-2.0, 2.0)   # luck-exempt: where along the bank each one stands

	if _fresh_wet(stand_at.x, stand_at.z):
		stand_at = found[0]
	else:
		stand_at.y = float(ground_height.call(stand_at.x, stand_at.z))

	a["drink_home"] = a["home"]
	a["drink_at"] = stand_at
	a["drink_to"] = found[1]
	a["drink_spring"] = found.size() > 2
	a["home"] = a["drink_at"]
	a["target"] = a["drink_at"]
	a["state"] = HOP
	a.erase("hunch")
	return true


# Where a prowling wolf pack wanders: at dawn and dusk, wait_m back from the water nearest its home within wolf_water_m (the prey's drinking
# place); otherwise its home. Vector3.INF when there is no such water or the rule is off.
func wolf_wait_point(home: Vector3) -> Vector3:
	if not drink_on() or not _twilight():
		return Vector3.INF

	var dc: Dictionary = _drink_cfg()
	var found: Array = drink_spot(home, float(dc.get("wolf_water_m", 500.0)))

	if found.is_empty():
		return Vector3.INF

	var stand: Vector3 = found[0]
	var back: Vector3 = Vector3(stand.x - found[1].x, 0.0, stand.z - found[1].z).normalized()
	var at: Vector3 = stand + back * float(dc.get("wolf_back_m", 15.0))
	at.y = float(ground_height.call(at.x, at.z)) if ground_height.is_valid() else stand.y
	return at

# --- animals on ice (docs/design/animals_on_ice_server.md; MikeW ANIMAL_WEATHER_LOOKS.md ice; Kathleen frozen_water_look.md #729) ---
# Behind animals.json ice.on. The ice is the server's Ice.cover (3 m pond depth, as server_items._on_ice), open in a thaw's shore moat.

func _ice_cfg() -> Dictionary:
	return cfg.get("ice", {})


func ice_on() -> bool:
	return ice_cover_at.is_valid() and water_level.is_valid()


# The ice cover on the water at (x, z): 0 on dry land, on open water and in a thaw moat.
func ice_at(x: float, z: float) -> float:
	var level: float = float(water_level.call(x, z))

	if is_nan(level):
		return 0.0

	var at: Vector3 = Vector3(x, level, z)

	if ice_moat_at.is_valid() and bool(ice_moat_at.call(at)):
		return 0.0

	# Ice.cover runs an hourly loop over weeks, so it is kept per 1 km band of z (the zone rows are tiles) and 5 m of height for cache_s.
	var key: Vector2i = Vector2i(floori(z / 1000.0), roundi(level / 5.0))
	var now: int = Time.get_ticks_msec()

	if not _ice_cache.has(key) or now - int(_ice_cache[key][1]) > int(float(_ice_cfg().get("cache_s", 60.0)) * 1000.0):
		_ice_cache[key] = [float(ice_cover_at.call(at)), now]

	# By a spring (Jamie #739): its brook stays open for its open length, and the ice is half as thick near a mouth or an inflow, so the
	# open water below springs is where animals and water birds gather in a freeze.
	return float(_ice_cache[key][0]) * (clampf(float(spring_ice_x.call(at)), 0.0, 1.0) if spring_ice_x.is_valid() else 1.0)


# Whether ice at (x, z) holds an animal of `mass` kg for sure (Jamie #736, from the Minnesota DNR table): mass <= sure_k (0.9) x h^2, with
# h the thickness in cm (cover x 20). Animals keep off doubtful ice (judged), so the chance band up to 3.5 h^2 is not used here.
func ice_holds(x: float, z: float, mass: float) -> bool:
	var h_cm: float = ice_at(x, z) * 20.0
	return h_cm > 0.0 and mass <= float(_ice_cfg().get("sure_k", 0.9)) * h_cm * h_cm


# An animal's mass for the ice (ice.mass_kg, Jamie #736's table), or NAN for a species the table leaves out (it keeps the plain rules).
func ice_mass(sp: String) -> float:
	var masses: Dictionary = _ice_cfg().get("mass_kg", {})
	return float(masses[sp]) if masses.has(sp) else NAN


# [ground, blocked] callables for a walker this tick: a skirting animal (deer role, skirt_species: deer fall on bare ice, Jamie #736) is
# also blocked by any ice it could see (skirt_cover, skim and up), even over shallows it would wade; any other animal with a mass in
# ice.mass_kg walks on ice that holds it for sure, at the water's surface, and only open deep water blocks it; the rest keep the plain rules.
func ice_moves(def: Dictionary, sp: String) -> Array:
	var ic: Dictionary = _ice_cfg()
	var base_blocked: Callable = blocked
	var base_ground: Callable = ground_height
	var me = self

	if str(def.get("weather", "")) == "deer" or sp in ic.get("skirt_species", ["boar", "warthog"]):
		var skirt: float = float(ic.get("skirt_cover", 0.1))
		return [base_ground, func(x: float, z: float) -> bool: return (base_blocked.is_valid() and bool(base_blocked.call(x, z))) or me.ice_at(x, z) >= skirt]

	var mass: float = ice_mass(sp)

	if not is_nan(mass):
		return [ice_ground(base_ground, mass), ice_blocked(base_blocked, mass)]

	return [base_ground, base_blocked]


# A walker's ground on ice: the water's surface where the ice holds `mass` for sure, else the ground.
func ice_ground(base_ground: Callable, mass: float) -> Callable:
	var me = self
	var ground: Callable = func(x: float, z: float) -> float:
		if me.ice_holds(x, z, mass):
			return float(me.water_level.call(x, z))

		return float(base_ground.call(x, z)) if base_ground.is_valid() else 0.0

	return ground


# A walker's block on ice: deep water only where the ice does not hold `mass` for sure.
func ice_blocked(base_blocked: Callable, mass: float) -> Callable:
	var me = self
	return func(x: float, z: float) -> bool: return base_blocked.is_valid() and bool(base_blocked.call(x, z)) and not me.ice_holds(x, z, mass)


# Where a water flock settles at (x, z) (Jamie #736: water birds stand at the ice edge by open water and leave a pond frozen over): there when
# the ice would not hold one of them for sure (open water or a skim it swims through); on ice that holds it, the nearest such water within
# edge_search_m (8 bearings, 4 m steps), the flock standing edge_back_m back from it on the ice; Vector2(INF, INF) when the pond is shut.
func ice_edge_spot(x: float, z: float, sp: String) -> Vector2:
	var ic: Dictionary = _ice_cfg()
	var mass: float = ice_mass(sp)

	if is_nan(mass):
		mass = float(ic.get("flock_mass_kg", 1.2))

	if not ice_holds(x, z, mass):
		return Vector2(x, z)

	var back: float = float(ic.get("edge_back_m", 2.0))

	for step in range(1, int(float(ic.get("edge_search_m", 40.0)) / 4.0) + 1):
		for b in 8:
			var dir: Vector2 = Vector2.from_angle(TAU * float(b) / 8.0)
			var p: Vector2 = Vector2(x, z) + dir * 4.0 * float(step)

			if not is_nan(float(water_level.call(p.x, p.y))) and not ice_holds(p.x, p.y, mass):
				return p - dir * back

	return Vector2(INF, INF)


# --- birds and thunder (docs/design/birds_and_thunder_server.md; MikeW's ask) ---
# Always on: no switch since 9 Nov, because the client plays the same strikes (#849). Strikes come from the shared Thunder schedule
# (seed, game time, storm), so the client hears the clap the birds flush at. When the sound reaches a bird within flush_m of the strike (sound_mps),
# a flying-kind bird (a flight row) or a water flock takes off away from it: state 15 on the wire.

func _thunder_cfg() -> Dictionary:
	return cfg.get("thunder", {})


const THUNDER_ASK_MS := 250
var _thunder_asked_ms: int = -THUNDER_ASK_MS


func _thunder_tick(players: Array) -> void:
	var tc: Dictionary = _thunder_cfg()

	if not thunder_between.is_valid() or not game_seconds.is_valid():
		return

	var now_g: float = float(game_seconds.call())
	var now_ms: int = Time.get_ticks_msec()
	var flush_m: float = float(tc.get("flush_m", 800.0))
	# The strikes are asked for THUNDER_ASK_MS apart, over the whole game time since the last ask (none is missed; a clap starts up to that much
	# later): asking for every player every frame took an eighth of the server's main thread at 16 players (load test 23 Nov 2026).
	var ask: bool = now_ms - _thunder_asked_ms >= THUNDER_ASK_MS

	if ask and not is_nan(_thunder_t) and now_g > _thunder_t:
		var seen: Dictionary = {}

		for p in players:
			for s in thunder_between.call(_thunder_t, now_g, p, flush_m + float(cfg.get("active_radius_m", 200.0))):
				var key: String = "%d,%d,%d" % [int(s[0].x), int(s[0].z), int(s[1])]

				if not seen.has(key):
					seen[key] = true
					_claps.append([s[0], now_ms, {}])

	if ask:
		_thunder_t = now_g
		_thunder_asked_ms = now_ms

	var kept: Array = []
	var sound_mps: float = float(tc.get("sound_mps", 343.0))

	for clap in _claps:
		var heard_m: float = sound_mps * float(now_ms - int(clap[1])) / 1000.0
		var at: Vector3 = clap[0]

		for id in animals:
			var a: Dictionary = animals[id]

			if clap[2].has(id) or int(a["state"]) == 15 or int(a["state"]) == 17:
				continue

			var d: float = Vector2(a["pos"].x - at.x, a["pos"].z - at.z).length()

			if d > flush_m or d > heard_m:
				continue

			clap[2][id] = true

			if flight != null and species_def(str(a["sp"])).has("flight"):
				if a.has("fly"):
					continue

				a.erase("perched")
				_weather_for(a["pos"])   # how far it flies in a gale: the wind where it sits
				flight.take_off(a, Vector3(at.x, a["pos"].y, at.z))
			elif flocks != null and flocks.handles(a):
				flocks.take_off(a, Vector3(at.x, a["pos"].y, at.z))

		if heard_m <= flush_m:
			kept.append(clap)

	_claps = kept

