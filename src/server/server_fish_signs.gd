extends RefCounted

# Fish you can see (plan D, docs/mirror/design/FISH_AND_FISHING_PLAN.md section 3; Dave 24 Nov 2026: "are fish pools actually a thing in the
# rivers yet because I have never seen any"). The schools of server_fish.gd were only a hidden factor on the catch; nothing told a player where
# they were. Now, once a tick_ms, the server rolls each school near any player for a jump and sends fish_jump (where, size and kind, a seed for
# the look) to the players within reach_m of it: a splash, ripple rings and a silver flash at a point inside the school, heard as a positional
# splash. And every shadow_every_ms each player is sent the schools within shadow_m in shallow water (fish_shadows), drawn as dark fish just
# under the surface; only when the list changed. The catch odds are not touched (the coordinator for Dave: visible schools are the fix).
#
# Rates (plan 3.1): a school of big_size fish jumps jump_per_s once a second on average, scaled by its size, the hour (hour_mult, night_mult)
# and the weather over it (rain x1.2, storm x0.3, cold x0.6): one jump every 10 to 30 s near a big school. A player is sent at most one jump
# per player_gap_ms. Frozen water and schools with no fish make none.
# Cost (plan 6): one pass a second over the 128 m cells round the players (3 x 3 each, shared), each cell's schools from server_fish.gd
# (placements cached per cell and day; a drift check reads the water kind, cached 20 s per 8 m), one distance test per school per player.
# Sent: a jump is about 30 bytes, at most one per player_gap_ms per player (about 1 a second at the very most, typically one per 10 to 30 s);
# shadows about 20 bytes a school, only on change (a school drifts up to 12 m each way over 6 game hours, about 15 real minutes, so with
# centres snapped to 2 m a standing player near a school gets a new list every half minute or so, a walking one as schools come in and out of
# 40 m). Cells on a tile not yet in memory are skipped (ready_at) so the pass never reads a tile on the main thread.

const SIZE_SMALL := 0
const SIZE_MID := 1
const SIZE_BIG := 2

var items                          # ServerItems: peer_ids, position_of, fish_stock, _fish_schools, _now_game_s, _season_of, _weather_here, _on_ice, water_kind_at, game_seconds
var surface_at: Callable           # (x, z) -> the water surface height there, NAN where dry (terrain_server _water_at)
var ready_at: Callable             # (x, z) -> whether the tile there is in memory (asks for it when not); unset: always ready
var send_jump: Callable            # (peer, at: Vector3, kind: int, seed: int): kind = size class * 4 + group (group 0 small fish, 1 big)
var send_shadows: Callable         # (peer, rows: PackedFloat32Array): [x, y, z, radius, size class] per school, nearest first; empty: none
var now_ms: Callable = func() -> int: return Time.get_ticks_msec()
var cfg: Dictionary = {}
var jumps_sent: int = 0            # fish_jump messages sent (one per receiver), for checks
var shadows_sent: int = 0          # fish_shadows messages sent, for checks
var last_tick_usec: int = 0        # how long the last pass took, for the cost check

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_ms: int = 0
var _next_shadows_ms: int = 0
var _last_jump_ms: Dictionary = {}   # peer -> ms of the last jump it was sent
var _last_shadows: Dictionary = {}   # peer -> the last rows it was sent


func _init(config: Dictionary = {}) -> void:
	cfg = config

	if cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/fish_schools.json"))
		cfg = (parsed as Dictionary).get("signs", {}) if typeof(parsed) == TYPE_DICTIONARY else {}

	_rng.randomize()


func seed_rng(value: int) -> void:
	_rng.seed = value


# A player left: forget what it was sent.
func forget(peer: int) -> void:
	_last_jump_ms.erase(peer)
	_last_shadows.erase(peer)


# Size class of a school of `size` fish: 0 small, 1 mid, 2 big.
func size_class(size: int) -> int:
	if size >= int(cfg.get("size_big", 9)):
		return SIZE_BIG

	return SIZE_MID if size >= int(cfg.get("size_mid", 5)) else SIZE_SMALL


# 0 small fish (trout, perch, herring ...), 1 big ones (salmon, pike, carp, cod): a bigger splash and flash.
func group_of(species: String) -> int:
	return 1 if (cfg.get("big_species", []) as Array).has(species) else 0


# How likely the school is to jump in one second (plan 3.1).
func jump_chance(size: int, hour: float, weather: Dictionary) -> float:
	var p: float = float(cfg.get("jump_per_s", 0.067)) * float(size) / maxf(float(cfg.get("big_size", 12)), 1.0)
	var tod: float = float(cfg.get("night_mult", 0.5)) if (hour < 5.0 or hour >= 21.0) else 1.0

	for band in cfg.get("hour_mult", []):
		if hour >= float(band[0]) and hour < float(band[1]):
			tod = float(band[2])

	p *= tod

	if float(weather.get("storm", 0.0)) > 0.3:
		p *= float(cfg.get("storm_mult", 0.3))
	elif float(weather.get("rain", 0.0)) > 0.0:
		p *= float(cfg.get("rain_mult", 1.2))

	if float(weather.get("temp_c", 15.0)) < float(cfg.get("cold_c", 5.0)):
		p *= float(cfg.get("cold_mult", 0.6))

	return clampf(p, 0.0, 1.0)


func tick() -> void:
	var now: int = int(now_ms.call())

	if now < _next_ms or items == null or not items.water_kind_at.is_valid():
		return

	var started: int = Time.get_ticks_usec()
	var step_ms: int = int(cfg.get("tick_ms", 1000))
	_next_ms = now + step_ms
	var peers: Dictionary = {}   # peer -> Vector2 (x, z)

	for peer in items.peer_ids():
		var pos: Variant = items.position_of(peer)

		if pos is Vector3:
			peers[peer] = Vector2(pos.x, pos.z)

	for gone in _last_shadows.keys():
		if not peers.has(gone):
			forget(gone)

	if peers.is_empty():
		last_tick_usec = Time.get_ticks_usec() - started
		return

	var reach: float = float(cfg.get("reach_m", 100.0))
	var all: Array = _schools_near(peers)   # [{species, size, centre, radius}]
	var hour: float = fposmod(items._now_game_s(), 86400.0) / 3600.0
	var dt: float = float(step_ms) / 1000.0

	for s in all:
		var centre: Vector2 = s["centre"]
		var near: Array = []

		for peer in peers:
			if (peers[peer] as Vector2).distance_to(centre) <= reach:
				near.append(peer)

		if near.is_empty():
			continue

		var sky: Variant = items.position_of(near[0])   # the sky over the water where a player stands (a mountain lake in snow is not the coast's rain)
		var chance: float = 1.0 - pow(1.0 - jump_chance(int(s["size"]), hour, items._weather_here(sky if sky is Vector3 else Vector3(centre.x, 0.0, centre.y))), dt)

		if _rng.randf() >= chance:
			continue

		var spot: Vector2 = centre + Vector2(sqrt(_rng.randf()) * float(s["radius"]) * 0.8, 0.0).rotated(_rng.randf() * TAU)
		var y: float = float(surface_at.call(spot.x, spot.y)) if surface_at.is_valid() else NAN

		if is_nan(y) or items._on_ice(Vector3(spot.x, y, spot.y)):
			continue   # the jump point is dry (the school's edge on a bank) or the water is frozen: no jump this time

		var kind: int = size_class(int(s["size"])) * 4 + group_of(str(s["species"]))
		var seed_value: int = _rng.randi() & 0x7fffffff
		var gap: int = int(cfg.get("player_gap_ms", 3000))

		for peer in near:
			if now - int(_last_jump_ms.get(peer, -1000000)) < gap:
				continue

			_last_jump_ms[peer] = now
			jumps_sent += 1

			if send_jump.is_valid():
				send_jump.call(peer, Vector3(spot.x, y, spot.y), kind, seed_value)

	if now >= _next_shadows_ms:
		_next_shadows_ms = now + int(cfg.get("shadow_every_ms", 2000))
		_send_shadows(peers, all)

	last_tick_usec = Time.get_ticks_usec() - started


# The schools of the 128 m cells round every player (3 x 3 cells each, each cell once).
func _schools_near(peers: Dictionary) -> Array:
	var fish = items._fish_schools()
	var cell_m: float = float(fish.cell_m)
	var day: int = int(floor(items._now_game_s() / 86400.0))
	var cells: Dictionary = {}
	var reach: float = float(cfg.get("reach_m", 100.0))
	var span: int = int(ceil(reach / cell_m))

	for peer in peers:
		var p: Vector2 = peers[peer]
		var home: Vector2i = Vector2i(int(floor(p.x / cell_m)), int(floor(p.y / cell_m)))

		for dz in range(-span, span + 1):
			for dx in range(-span, span + 1):
				cells[home + Vector2i(dx, dz)] = true

	var out: Array = []

	for cell in cells:
		if not _cell_ready(cell, cell_m):
			continue   # its tile is being read: no schools there this pass (never an empty placement cached for the day)

		var middle: Vector3 = Vector3((float(cell.x) + 0.5) * cell_m, 0.0, (float(cell.y) + 0.5) * cell_m)
		out.append_array(fish.schools(cell, day, items._season_of(middle), int(items.fish_stock(cell)), items._now_game_s()))

	return out


# Whether every tile a cell's schools can touch (the cell and the drift round it) is in memory.
func _cell_ready(cell: Vector2i, cell_m: float) -> bool:
	if not ready_at.is_valid():
		return true

	var pad: float = 16.0
	var ok: bool = true

	for corner in [Vector2(-pad, -pad), Vector2(cell_m + pad, -pad), Vector2(-pad, cell_m + pad), Vector2(cell_m + pad, cell_m + pad)]:
		ok = bool(ready_at.call(float(cell.x) * cell_m + corner.x, float(cell.y) * cell_m + corner.y)) and ok   # asks for each missing tile

	return ok


# Each player's schools within shadow_m in water no deeper than shadow_depth_max_m, nearest first, at most shadow_max; sent when they changed.
func _send_shadows(peers: Dictionary, all: Array) -> void:
	var near_m: float = float(cfg.get("shadow_m", 40.0))
	var deep: float = float(cfg.get("shadow_depth_max_m", 2.0))
	var most: int = int(cfg.get("shadow_max", 6))

	for peer in peers:
		var p: Vector2 = peers[peer]
		var picked: Array = []

		for s in all:
			var d: float = p.distance_to(s["centre"])

			if d <= near_m + float(s["radius"]):
				picked.append([d, s])

		picked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var rows: PackedFloat32Array = PackedFloat32Array()

		for row in picked:
			if rows.size() >= most * 5:
				break

			var s: Dictionary = row[1]
			var centre: Vector2 = s["centre"]
			var water: Dictionary = items.water_kind_at.call(centre.x, centre.y)
			var y: float = float(surface_at.call(centre.x, centre.y)) if surface_at.is_valid() else NAN

			if is_nan(y) or float(water.get("depth", 0.0)) > deep:
				continue   # deep water hides its fish (plan 6.4)

			rows.append_array(PackedFloat32Array([snappedf(centre.x, 2.0), snappedf(y, 0.1), snappedf(centre.y, 2.0), snappedf(float(s["radius"]), 0.1), float(size_class(int(s["size"])))]))

		if _last_shadows.has(peer) and _last_shadows[peer] == rows:
			continue

		_last_shadows[peer] = rows
		shadows_sent += 1

		if send_shadows.is_valid():
			send_shadows.call(peer, rows)
