extends RefCounted

# Animals, step B (data/animals/animals.json; design items/ANIMALS_DESIGN.md, Steve's plan 2026-10-21): the rabbit only.
# Records live on the server only (nothing is saved): spawned out of sight around each player, dropped when nobody is near.
# A rabbit grazes, hops a few metres now and then, and bolts away from a player who comes within spook_m. Movement uses the
# shared Steering module with NPCs. Ticks by distance to the nearest player (10 / 3 / 0.5 Hz), so far animals cost almost nothing.

const Steering := preload("res://src/shared/steering.gd")
const WolvesScript := preload("res://src/stream/server_wolves.gd")
const BigGameScript := preload("res://src/stream/server_big_game.gd")
const ThievesScript := preload("res://src/stream/server_thieves.gd")
const FlocksScript := preload("res://src/stream/server_flocks.gd")
const GoblinsScript := preload("res://src/stream/server_goblins.gd")
const CompanionsScript := preload("res://src/stream/server_companions.gd")
const FlightScript := preload("res://src/stream/server_flight.gd")

const GRAZE := 0
const HOP := 1
const FLEE := 2
const ALERT := 3
const WARN := 10                # big game standing its ground (head down), then 11 charge, 12 recover (server_big_game.gd)
const SNEAK := 13               # a thief creeping up on food, 14 running off with it (server_thieves.gd)
const HIDDEN := 5               # in its burrow: never sent, never hunted
const HUNCH := 20               # wire only: a grazer standing out the rain, still, head low (animals_in_weather_design.md 6; GRAZE on the server)
const STAGGER := 4              # a quarter of the animals are looked at each tick

var cfg: Dictionary = {}
var animals: Dictionary = {}       # id int -> {id, sp, num, pos Vector3, heading, state, target Vector3, timer, acc, home}
var ground_height: Callable        # (x, z) -> height
var blocked: Callable              # (x, z) -> bool (deep water)
var walls: Callable                # (x0, z0, x1, z1, margin) -> bool, a wall or heavy station on that step (server_items.structure_blocks_step)
var crossing: Callable             # Steering's `cross`: every walker of this module stops at walls
var player_positions: Callable     # () -> Array of Vector3
var player_stances: Callable       # () -> Array of stances in player_positions order (0 stand, 1 crouch, 2 sit, 3 lie)
var canopy: Callable               # (Vector3) -> bool, whether a spot is under a tree crown (forest for sight and habitat)
var canopy_ready: Callable         # (x, z) -> bool, whether the tree crowns round a spot are known yet (the flora chunks are made; a missing one is started on a worker)
var undergrowth: Callable          # (Vector3) -> bool, the spot is in bushes, ferns or tall grass (server_flora.in_undergrowth): moving through it rustles
var player_stalk: Callable         # () -> Array of hunting skill factors (skills.json actions.stalk, 1.0 for a beginner) in player_positions order
var fires: Callable                # () -> Array of Vector3, burning fires and torch bearers (server_items._lit_fires; wolves read the same list)
var fire_radius: Callable          # (Vector3) -> how far animals keep from that fire (server_items.fire_protect_m: a campfire's tier, 8 m for a torch)
var wind: Callable                 # () -> the weather dictionary ("wind" 0..1 and "wind_dir" radians, the way it blows toward)
var weather_ahead: Callable        # (hours) -> the weather dictionary that many game hours from now (WeatherScript.state; animals_in_weather_design.md 3)
var died: Callable                 # (species, position, source peer) when an animal is killed
var ticks_run: int = 0
var trails = null                  # game trails (server_trails.gd): every step into a new cell wears the grass a little
var flocks = null                  # bird flocks on water (server_flocks.gd)
var water_level: Callable          # (x, z) -> water surface height, NAN on dry land (flocks float on it)
var fresh_water_m: Callable        # (x, z) -> distance (m) to perennial fresh water from the baked tile (Stage E), NAN when the tile has none
var thieves = null                 # opportunists (fox; server_thieves.gd): smell loose food, creep up, take it and run
var drop_loot: Callable            # (item number, count, position) when a thief is killed carrying food
var big_game = null                # defending big game (moose; server_big_game.gd): warn, dodgeable charge, recover
var biome_at: Callable             # (x, z) -> biome name of the ground there ("" unknown); species rows may list "biomes" weights (0 or missing = never)
var hour_now: Callable             # () -> hour of the game day 0..24 (the server's clock); species rows may list "active" {day, dusk, night} spawn chances 0..1
var lair_guarded: Callable            # (x, z, radius) -> bool: true when a burning placed fire lies within radius of a lair's mouth (lair.guard_m), so no new group comes (Dave 8 Nov 2026, decision 13)
var _lair_state: Dictionary = {}   # mouth "x,z" -> {"made": a group has been made here, "empty_since": seconds when it was found empty, -1 while a group is there}
var lair_path: Callable              # (mouth x, z) -> PackedVector3Array: the cave floor path from that den mouth to the den (tile goblin_den_paths), empty when none
var berry_bushes: Callable           # (Vector3, radius) -> PackedVector3Array: standing berry plants near a point, from flora chunks already made (goblins forage at them)
var goblins = null                   # den life (server_goblins.gd): species with a "den_life" row sleep in the cave by day, watch fires and forage at night
var flight = null                    # single birds in flight (server_flight.gd, bird_flight_server_design.md): species with a "flight" row fly when they bolt
var companions = null                # companions (server_companions.gd): the stray a player befriends with food, then their dog (Dave 8 Nov 2026, decisions 5 and 6)
var lair_mouths: Callable             # (x, z) -> PackedVector2Array: the cave mouths (world x, z) of the tile there; species with a "lair" row spawn their groups at them (goblins, Dave 7 Nov 2026)
var season_now: Callable           # () -> "spring", "summer", "autumn" or "winter" (GameClock.season()); species rows may list "seasons" {name: {threat_x, spook_x}}
var traits: bool = true            # temperaments and young (Dave 6 Nov 2026); seeded tests that predate them turn this off, so every animal is born "defensive" with no young
var starter: Vector2 = Vector2(INF, INF)   # the real spawn point (x, z) from the starter tile: the town point of the island level (island_level) when set
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
var _storm_ahead: bool = false     # a storm (storm 0.5 or more) 12 to 24 game hours ahead: the falling pressure prey feel (lesson 4)
var _ahead_acc: float = INF        # real seconds since weather_ahead was last sampled
var _dogs: Array = []              # this tick's companion dogs as a presence for wild animals: [animal id, position, barking] (dog_companion_design.md 11)
var _herds: Dictionary = {}       # herd id -> Array of animal ids (3 to 6 deer)
var _fire_cache: Array = []       # [Vector3 fire, keep-off metres] this tick (fires, fire_radius)
var _noise_acc: float = 0.0       # time since the last undergrowth sample (_sample_noise)
var _noise_from: Array = []       # player positions at the last sample
var _player_vel: Array = []       # per player (the _noise_from order): ground velocity (x, z) over the last noise sample, m/s
var _noisy: Array = []            # per player (player_positions order): how much farther they are sensed for rustling undergrowth (1.0 none)


# True when the step from (x0, z0) to (x1, z1) goes through a wall or heavy station, grown by the body margin.
func _init() -> void:
	crossing = Callable(self, "crosses_wall")


func crosses_wall(x0: float, z0: float, x1: float, z1: float) -> bool:
	return walls.is_valid() and bool(walls.call(x0, z0, x1, z1, float(cfg.get("wall_margin_m", 0.3))))


func setup() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
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

	if swims(def):      # a young swimmer (a moose calf) follows its mother into the water
		ground_for = func(x: float, z: float) -> float: return swim_height(def, x, z)
		blocked_for = Callable()

	var r: Dictionary = Steering.step(a["pos"], a["target"], speed, dt, ground_for, blocked_for, 0.4, a["heading"], crossing)

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

	# Wounded big game with the hunter close stands and fights (after a short warning); a distant hunter it runs from.
	var defend: Dictionary = species_def(a["sp"]).get("defend", {})

	if not defend.is_empty():
		for info in (big_game.player_info.call() if big_game.player_info.is_valid() else []):
			if int(info["peer"]) == source_peer and Vector2(info["pos"].x - a["pos"].x, info["pos"].z - a["pos"].z).length() <= float(defend.get("provoked_m", 10.0)):
				if big_game.warn(a, info["pos"], float(defend.get("provoked_warn_s", 0.8))):
					return false

	a["state"] = FLEE
	a["target"] = a["pos"] + Vector3(cos(a["heading"] + PI), 0.0, sin(a["heading"] + PI)) * float(species_def(a["sp"]).get("flee_run_m", 25.0))
	return false


# The animal a jab from `origin` along `dir` reaches: nearest within reach and about 35 degrees of the aim; 0 for none.
func target_along(origin: Vector3, dir: Vector3, reach: float) -> int:
	var flat: Vector2 = Vector2(dir.x, dir.z).normalized()
	var best: int = 0
	var best_d: float = reach

	for id in animals:
		if animals[id]["state"] == HIDDEN:
			continue

		var to: Vector2 = Vector2(animals[id]["pos"].x - origin.x, animals[id]["pos"].z - origin.z)
		var d: float = to.length()

		if d <= best_d and (d < 0.6 or to.normalized().dot(flat) > 0.82) and absf(animals[id]["pos"].y - origin.y) < 3.5:
			best_d = d
			best = id

	return best


# The first animal whose chest sphere the segment from -> to passes through (a flying arrow): {"id", "at"} or {} when none. Hidden animals are skipped.
func target_on_segment(from: Vector3, to: Vector3, radius: float, chest_m: float) -> Dictionary:
	var best: Dictionary = {}
	var best_t: float = INF
	var seg: Vector3 = to - from
	var len2: float = maxf(seg.length_squared(), 0.000001)

	for id in animals:
		if int(animals[id]["state"]) == HIDDEN:
			continue

		var centre: Vector3 = animals[id]["pos"] + Vector3(0.0, chest_m, 0.0)
		var t: float = clampf((centre - from).dot(seg) / len2, 0.0, 1.0)
		var r: float = float(species_def(str(animals[id]["sp"])).get("hit_radius_m", radius))

		if (from + seg * t).distance_to(centre) <= r and t < best_t:
			best_t = t
			best = {"id": int(id), "at": animals[id]["pos"]}

	return best


# A loud noise: every animal within `radius` of the point that is not already running bolts away from it.
func alarm_near(point: Vector3, radius: float) -> void:
	for id in animals:
		var a: Dictionary = animals[id]

		if int(a["state"]) == HIDDEN or int(a["state"]) == FLEE or int(a["state"]) >= WARN or a["pos"].distance_to(point) > radius or a.has("pack"):
			continue

		_bolt(a, point, species_def(str(a["sp"])))


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
# medium on the far side; DESIGN_IDEAS 4.13). 0 within island_level.town_m of the town point (the real spawn until the starter town
# is placed), 1 at far_m (about the far coast of tile 3,4) and beyond. Off the starter island the world danger map is to take over
# (not built: one starter island for now).
func island_level(x: float, z: float) -> float:
	var il: Dictionary = cfg.get("island_level", {})
	var town: Array = il.get("town", [53301.0, 68427.0])
	var centre: Vector2 = starter if starter.x != INF else Vector2(float(town[0]), float(town[1]))
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
				var sensed: float = d / _sense_factor(a, def_s, p, d, int(stances[pi]) if pi < stances.size() else 0, float(_noisy[pi]) if pi < _noisy.size() else 1.0)

				if sensed < seen_d:
					seen_d = sensed
					seen_p = p

		if seen_p == Vector3.INF:
			seen_d = near_d
			seen_p = near_p

		if near_d > despawn_m:
			gone.append(id)
			continue

		var kept: bool = a.has("companion_id")   # a companion stays with its owner: never frozen, never sent off for the hour (server_companions)

		# An animal whose hours are over (a songbird at night, a boar at noon: its activity chance is at most off_hours_chance) leaves once no player is close to it.
		if not kept and near_d > float(cfg.get("off_hours_despawn_m", 80.0)) and hour_now.is_valid() and activity_chance(species_def(str(a["sp"]))) <= float(cfg.get("off_hours_chance", 0.05)):
			gone.append(id)
			continue

		if near_d > active_r and not kept:
			a["acc"] = 0.0
			continue   # frozen: nothing runs until a player comes within active_radius_m

		if a.has("pack"):
			a["acc"] = 0.0
			continue   # the pack brain moves wolves (tick below)

		var hz: float = float(cfg.get("hz_near", 10.0)) if near_d <= near_m else (float(cfg.get("hz_mid", 3.0)) if near_d <= mid_m else float(cfg.get("hz_far", 0.5)))

		if a["acc"] < 1.0 / hz:
			continue

		var dt: float = minf(a["acc"], 1.0)
		a["acc"] = 0.0
		_step(a, dt, near_d, near_p, seen_d, seen_p)

		if trails != null and int(a.get("state", 0)) != HIDDEN and not bool(a.get("in_cave", false)) and not a.has("fly") and not bool(a.get("perched", false)):
			trails.note(id, str(a["sp"]), a["pos"])

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

	if wolves != null and (not wolves.packs.is_empty() or not wolves.dens.is_empty() or bool(wolves.cfgw().get("natural", false))):
		wolves.tick(delta)

	_spawn_acc += delta

	# One player's share is looked at per pass, so with 20 players each is still topped up every spawn_every_s but never in one tick.
	if not players.is_empty() and _spawn_acc >= float(cfg.get("spawn_every_s", 2.0)) / float(players.size()):
		_spawn_acc = 0.0
		_top_idx = (_top_idx + 1) % players.size()
		_top_up(players, _top_idx)


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

		if a["herd"] != 0 and float(def.get("herd_pull_m", 0.0)) > 0.0:
			var centre: Vector3 = _herd_centre(a["herd"])

			if centre != Vector3.INF and a["home"].distance_to(centre) > float(def.get("herd_pull_m", 12.0)):
				a["home"] = a["home"].lerp(centre, 0.5)

		if a["timer"] <= 0.0 and resting(def):
			a["timer"] = _graze_time(def) * float(cfg.get("rest", {}).get("graze_x", 3.0))   # out of its hours it beds down: stays put, longer
			return

		if a["timer"] <= 0.0 and _wind_goes_down(a, def):
			return

		if a["timer"] <= 0.0 and _weather_wander(a, def):
			return

		if a["timer"] <= 0.0:
			var wander: float = float(def.get("wander_m", 6.0)) * weather_wander_x(def)
			var angle: float = rng.randf() * TAU   # luck-exempt: where a grazing animal hops next
			angle = _upwind_angle(def, angle)
			a["target"] = a["home"] + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(1.0, wander)   # luck-exempt: as above

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

	if a["state"] == FLEE:
		# Sprint for burst_s seconds, then trot: an animal cannot outrun a chase for ever.
		a["burst"] += dt
		speed = float(def.get("flee_mps", 7.5)) * (1.0 if a["burst"] <= float(def.get("burst_s", 3.0)) else float(def.get("trot_share", 0.5)))
	var ground_for: Callable = ground_height
	var blocked_for: Callable = blocked

	if swims(def):
		# A swimmer goes into deep water (nothing blocks it) and rides the surface there; in water it moves at swim_mps.
		ground_for = func(x: float, z: float) -> float: return swim_height(def, x, z)
		blocked_for = Callable()

		if in_water(def, a["pos"]):
			speed = float(def["water"].get("swim_mps", speed)) * (1.0 if a["state"] == FLEE else 0.4)      # cruising slowly, bolting at full speed

	var r: Dictionary = Steering.step(a["pos"], a["target"], speed, dt, ground_for, blocked_for, 0.4, a["heading"], crossing)

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

				for q in players:
					too_near = too_near or Vector2(q.x - cx, q.z - cz).length() < (never if cfg.has("near_share") else maxf(never, float(cfg.get("spawn_min_m", 150.0)) * 0.9))

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

			var herd: Array = def.get("herd", [])

			if herd.is_empty():
				spawn(sp, x, z)
				continue

			var members: int = clampi(rng.randi_range(int(herd[0]), int(herd[1])), 1, maxi(per_player - all_near, 1))   # luck-exempt: how many deer in a herd
			var hid: int = _next_herd
			_next_herd += 1
			_herds[hid] = []

			for k in members:
				var id: int = spawn(sp, x + rng.randf_range(-6.0, 6.0), z + rng.randf_range(-6.0, 6.0))   # luck-exempt: herd spread

				if id != 0:
					animals[id]["herd"] = hid
					_herds[hid].append(id)


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

		if taken or (blocked.is_valid() and bool(blocked.call(m.x, m.y))) or crosses_wall(m.x, m.y, m.x, m.y):
			continue

		state["made"] = true
		state["empty_since"] = -1.0
		_lair_state[key] = state
		var members: int = clampi(rng.randi_range(int(group[0]), int(group[1])), 1, maxi(int(cfg.get("per_player_cap", 30)) - animals.size(), 1))   # luck-exempt: how many goblins in a group
		var hid: int = _next_herd
		_next_herd += 1
		_herds[hid] = []
		var den_at: Vector3 = Vector3.INF

		for _k in members:
			var id: int = spawn(sp, m.x + rng.randf_range(-3.0, 3.0), m.y + rng.randf_range(-3.0, 3.0))   # luck-exempt: group spread

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


# The chance (0..1) that a top-up may spawn this species now: the row's "active" value for the current period, 1 without a clock or a row.
func activity_chance(def: Dictionary) -> float:
	if not def.has("active") or not hour_now.is_valid():
		return clampf(weather_activity_x(def), 0.0, 1.0)

	return clampf(float((def["active"] as Dictionary).get(period_of(float(hour_now.call())), 1.0)) * weather_activity_x(def), 0.0, 1.0)


# Resting (MikeW 2026-11-02, Dave's behaviour list): outside its active hours (its "active" chance for the period at or under rest.below)
# an animal beds down where it is: it does not wander, and a player gets closer (rest.spook_share of spook_m) before it wakes and runs.
# Before a storm (animals_in_weather_design.md 8) feeding animals skip their daytime rest.
func resting(def: Dictionary) -> bool:
	if _storm_ahead and _wx_on() and str(def.get("weather", "")) in ["bird", "small", "deer"] and hour_now.is_valid() and period_of(float(hour_now.call())) == "day":
		return false

	return def.has("active") and hour_now.is_valid() and activity_chance(def) <= float(cfg.get("rest", {}).get("below", 0.1))


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
func rows_near(point: Vector3) -> Array:
	var radius: float = float(cfg.get("send_radius_m", 120.0))
	var found: Array = []

	for id in animals:
		var a: Dictionary = animals[id]
		var d: float = Vector2(a["pos"].x - point.x, a["pos"].z - point.z).length()

		if d <= radius and a["state"] != HIDDEN:
			var row: Array = [id, a["num"], a["pos"], snappedf(a["heading"], 0.01), HUNCH if a["state"] == GRAZE and (bool(a.get("hunch", false)) or bool(a.get("sheltered", false))) else a["state"]]

			if a.has("foe_dog") and int(a["state"]) >= 10 and int(a["state"]) <= 12 and animals.has(int(a["foe_dog"])):
				row.append(animals[int(a["foe_dog"])]["pos"])

			found.append([d, row])

	found.sort_custom(func(l, r): return l[0] < r[0])
	var rows: Array = []

	for f in found.slice(0, int(cfg.get("per_player_cap", 30))):
		rows.append(f[1])

	return rows


func _bolt(a: Dictionary, from: Vector3, def: Dictionary) -> void:
	if def.has("flight") and flight != null:
		flight.take_off(a, from)   # a bird with a flight row flies instead of running (bird_flight_server_design.md)
		return

	var away: Vector2 = Vector2(a["pos"].x - from.x, a["pos"].z - from.z).normalized()

	if away == Vector2.ZERO:
		away = Vector2.from_angle(a["heading"])

	a["state"] = FLEE
	a["burst"] = 0.0
	a["alert"] = 0.0
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
# so about 6 percent walking (1.4 m/s), 13 percent jogging and 36 percent running flat out (9 m/s); crouched, brush_crouch_share of
# that. The hunting skill quietens it: the extra is divided by the square of the stalk factor (1.0 for a beginner, about 1.5 at
# hunting 100, so a master makes under half the noise). A change in the player count resets the sample (the order may have changed).
func _sample_noise(players: Array, delta: float) -> void:
	var sen: Dictionary = cfg.get("senses", {})
	_noise_acc += delta

	if _noise_acc < float(sen.get("noise_sample_s", 0.25)):
		return

	var stances: Array = player_stances.call() if player_stances.is_valid() else []
	var stalk: Array = player_stalk.call() if player_stalk.is_valid() else []
	var fresh: Array = []
	var vel: Array = []

	for pi in players.size():
		var noise: float = 1.0
		var moved: Vector2 = Vector2.ZERO

		if players.size() == _noise_from.size():
			var was0: Vector3 = _noise_from[pi]
			moved = Vector2(players[pi].x - was0.x, players[pi].z - was0.z) / _noise_acc

		vel.append(moved)

		if players.size() == _noise_from.size() and undergrowth.is_valid():
			var p: Vector3 = players[pi]
			var speed: float = moved.length()

			if speed >= float(sen.get("brush_moving_ms", 0.5)) and bool(undergrowth.call(p)):
				var extra: float = float(sen.get("brush_noise_per_ms", 0.04)) * minf(speed, 12.0)
				var skill: float = maxf(float(stalk[pi]) if pi < stalk.size() else 1.0, 1.0)

				if pi < stances.size() and int(stances[pi]) == 1:
					extra *= float(sen.get("brush_crouch_share", 0.5))

				noise = 1.0 + extra / (skill * skill)

		fresh.append(noise)

	_noisy = fresh
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


# How much farther or nearer a player seems to an animal: downwind of the player it smells them from farther off, upwind it does
# not; a crouching or lying player is harder to see; with the ground in the way only scent and sound are left. A player rustling
# through undergrowth (noise, _sample_noise: a little, more the faster they go, less the better a hunter) is sensed a little farther
# off. It is added last, so it also carries where the animal can't see the player.
func _sense_factor(a: Dictionary, def: Dictionary, p: Vector3, d: float, stance: int, noise: float = 1.0) -> float:
	var sen: Dictionary = cfg.get("senses", {})
	var f: float = 1.0

	# Stances 4 and 5 are lying on a covered rough bed and lying in a closed room (server_items.peer_stances, bed.json): lying, and harder to sense.
	if stance >= 4:
		f *= float(sen.get("bed_mult", 0.7)) if stance == 4 else float(sen.get("hidden_mult", 0.05))
		stance = 3

	if _wind_s > 0.0 and d > 0.01:
		var to_animal: Vector2 = Vector2(a["pos"].x - p.x, a["pos"].z - p.z) / d
		f *= maxf(1.0 + float(sen.get("scent_gain", 0.5)) * _wind_s * to_animal.dot(_wind_dir), 0.5)   # times the bed's, never in place of it

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

	return f * noise


# How much of the player an animal can see, 0 to 1: 0 when the ground is in the way; otherwise less the more of the line runs under
# tree crowns (trunks and undergrowth: forest_block is the loss in a line wholly under trees). Mist cuts it (animals_in_weather_design.md 10).
func _sight(a: Dictionary, def: Dictionary, p: Vector3, d: float, low: bool) -> float:
	return _sight_clear(a, def, p, d, low) * (1.0 - float(_wx_rules().get("mist_sight", 0.6)) * float(_wx.get("mist", 0.0)) if _wx_on() else 1.0)


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


# This tick's weather, and every weather.ahead_every_s real seconds a look 12 to 24 game hours ahead for a storm.
func _read_weather(weather: Dictionary, delta: float) -> void:
	_wx = {"rain": float(weather.get("rain", 0.0)), "snow": float(weather.get("snow", 0.0)), "storm": float(weather.get("storm", 0.0)),
		"wind": float(weather.get("wind", 0.0)), "mist": float(weather.get("mist", 0.0)), "temp_c": float(weather.get("temp_c", 10.0))}
	_ahead_acc += delta

	if not _wx_on() or not weather_ahead.is_valid() or _ahead_acc < float(_wx_rules().get("ahead_every_s", 2.5)):
		return

	_ahead_acc = 0.0
	_storm_ahead = false

	for hours in _wx_rules().get("ahead_hours", [12, 15, 18, 21, 24]):
		var later: Dictionary = weather_ahead.call(float(hours))

		if float(later.get("storm", 0.0)) >= float(_wx_rules().get("storm_from", 0.5)):
			_storm_ahead = true
			return


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

	return x * (1.0 - float(r.get("mist_spook", 0.3)) * float(_wx.get("mist", 0.0)))


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
func weather_wander_x(def: Dictionary) -> float:
	if not _wx_on() or str(def.get("weather", "")) == "" or not _wx_stormy():
		return 1.0

	return float(_wx_rules().get("storm_wander_x", 0.3))


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
			if mate_id != a["id"] and animals.has(mate_id) and animals[mate_id]["state"] != FLEE and animals[mate_id]["alarm"] < 0.0:
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

	if _raining():
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
