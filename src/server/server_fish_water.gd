extends RefCounted

# Water kind for fishing (plan B, design/FISH_AND_FISHING_PLAN.md): water_kind_at(x, z) answers {"kind": brook | river | lake | pond |
# sea_shallow | sea_mid | sea_deep, "depth": metres of water} or kind "" where there is no water (land is never water).
# It shares the land-type map's baked class numbers and wet depth (LandType.BAKED_*, WET_M) instead of a second classifier. Pure function over
# a probe: `probe.call(x, z)` -> [water surface (NAN dry), ground height, baked water_class]. Read only; dug or filled ground and rising water
# are respected because the probe reads the live hooks, and an answer is kept for cache_ttl_s so a school module can ask every second.

const LandType := preload("res://src/water/land_type.gd")

const SEA_BAKED := 1

var probe: Callable
var cfg: Dictionary = {}
var _cache: Dictionary = {}     # cell key -> [msec, kind, depth]
var _cfg_loaded: bool = false


func _init(probe_fn: Callable = Callable(), config: Dictionary = {}) -> void:
	probe = probe_fn
	cfg = config


func _value(key: String, fallback: Variant) -> Variant:
	if cfg.is_empty() and not _cfg_loaded:
		_cfg_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/water/fish_water.json"))
		cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	return cfg.get(key, fallback)


func clear() -> void:
	_cache.clear()


func water_kind_at(x: float, z: float, now_msec: int = -1) -> Dictionary:
	if not probe.is_valid():
		return {"kind": "", "depth": 0.0}

	if now_msec < 0:
		now_msec = Time.get_ticks_msec()

	var step: float = float(_value("step_m", 8.0))
	var key: Vector2i = Vector2i(int(floor(x / step)), int(floor(z / step)))
	var hit: Array = _cache.get(key, [])

	if not hit.is_empty() and float(now_msec - int(hit[0])) < float(_value("cache_ttl_s", 20.0)) * 1000.0:
		return {"kind": hit[1], "depth": hit[2]}

	if _cache.size() >= int(_value("cache_max", 20000)):
		_cache.clear()

	var answer: Dictionary = _classify(key, step)
	_cache[key] = [now_msec, answer["kind"], answer["depth"]]
	return answer


# Metres of water at the middle of a grid cell, 0 when dry.
func _depth(key: Vector2i, step: float) -> float:
	var at: Array = _read(key, step)
	return 0.0 if is_nan(float(at[0])) else maxf(float(at[0]) - float(at[1]), 0.0)


func _read(key: Vector2i, step: float) -> Array:
	return probe.call((float(key.x) + 0.5) * step, (float(key.y) + 0.5) * step)


func _wet(key: Vector2i, step: float) -> bool:
	return _depth(key, step) >= LandType.WET_M


func _classify(key: Vector2i, step: float) -> Dictionary:
	var at: Array = _read(key, step)
	var depth: float = 0.0 if is_nan(float(at[0])) else maxf(float(at[0]) - float(at[1]), 0.0)

	if depth < LandType.WET_M:
		return {"kind": "", "depth": 0.0}

	var baked: int = int(at[2])

	if baked == SEA_BAKED or float(at[1]) <= 0.0:
		var kind: String = "sea_shallow" if depth < float(_value("sea_shallow_max_m", 5.0)) else ("sea_mid" if depth < float(_value("sea_mid_max_m", 30.0)) else "sea_deep")
		return {"kind": kind, "depth": depth}

	if baked == LandType.BAKED_RIVER:
		var brook: bool = _narrowest_run(key, step) * step <= float(_value("brook_max_width_m", 8.0)) and depth < float(_value("river_min_depth_m", 1.0))
		return {"kind": "brook" if brook else "river", "depth": depth}

	# A baked lake, or loose water with no baked class (a dug hole, a flood): small is a pond.
	return {"kind": "pond" if _joined(key, step) <= int(_value("pond_max_cells", 40)) else "lake", "depth": depth}


# Wet cells in a row through the cell along x and along z (capped by width_scan_cells each way); the smaller one is the stream's width in cells.
func _narrowest_run(key: Vector2i, step: float) -> int:
	var reach: int = int(_value("width_scan_cells", 6))
	var best: int = 1 << 20

	for axis in [Vector2i(1, 0), Vector2i(0, 1)]:
		var run: int = 1

		for dir in [-1, 1]:
			for k in range(1, reach + 1):
				if _wet(key + axis * (dir * k), step):
					run += 1
				else:
					break

		best = mini(best, run)

	return best


# Size of the group of joined wet cells around the cell, counted up to pond_max_cells + 1 (more than that is a lake).
func _joined(key: Vector2i, step: float) -> int:
	var cap: int = int(_value("pond_max_cells", 40)) + 1
	var seen: Dictionary = {key: true}
	var queue: Array = [key]

	while not queue.is_empty() and seen.size() < cap:
		var at: Vector2i = queue.pop_back()

		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = at + d

			if not seen.has(n) and _wet(n, step):
				seen[n] = true
				queue.append(n)

				if seen.size() >= cap:
					break

	return seen.size()
