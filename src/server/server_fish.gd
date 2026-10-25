extends RefCounted

# Fish schools (plan C, design/FISH_AND_FISHING_PLAN.md sections 2 and 4). A school is a computed record, not an entity and not saved: a hash of
# (cell, slot, game day) says how many schools a 128 m water cell holds, where each sits (only on water whose kind suits its species, from
# server_fish_water.gd's `kind_fn`), and how its centre drifts. The cell's hidden stock (fish_stock) gives the size, so catching shrinks the schools.
# `factor_at` is the school factor for a cast or a net: 1.0 inside a school's radius, 0.5 within 2x, 0.15 outside, and 1.0 where the module has nothing to say
# (no water kind function, dry point, or a kind with no species).

var kind_fn: Callable            # (x, z) -> {"kind": String, "depth": float}
var has_item: Callable           # (species) -> bool; a species with no item yet is left out
var cell_m: float = 128.0
var cfg: Dictionary = {}
var _cache: Dictionary = {}      # [cell, day, season] -> placements


func _init(kind: Callable = Callable(), item_ok: Callable = Callable(), config: Dictionary = {}, cell_size: float = 128.0) -> void:
	kind_fn = kind
	has_item = item_ok
	cfg = config
	cell_m = cell_size

	if cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/fish_schools.json"))
		cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# A stable 31-bit hash of four ints (no engine hash: placement must never change between runs or engine versions).
static func mix(a: int, b: int, c: int, d: int) -> int:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791) ^ (d * 2654435761)
	h = h & 0x7fffffff
	h = (h ^ (h >> 15)) * 2246822519 & 0x7fffffff
	h = (h ^ (h >> 13)) * 3266489917 & 0x7fffffff
	return h ^ (h >> 16)


static func unit(h: int) -> float:
	return float(h & 0xffff) / 65536.0


func _species_for(kind: String, season: String, roll: float) -> String:
	var rows: Array = []
	var total: float = 0.0
	var only_in: Dictionary = cfg.get("only_in", {})

	for row in cfg.get("species_by_kind", {}).get(kind, []):
		var name: String = str(row[0])

		if only_in.has(name) and not (only_in[name] as Array).has(season):
			continue

		if has_item.is_valid() and not bool(has_item.call(name)):
			continue

		rows.append([name, float(row[1])])
		total += float(row[1])

	if rows.is_empty():
		return ""

	var acc: float = 0.0

	for row in rows:
		acc += float(row[1]) / total

		if roll <= acc:
			return str(row[0])

	return str(rows[rows.size() - 1][0])


func _kind_at(x: float, z: float) -> String:
	return str((kind_fn.call(x, z) as Dictionary).get("kind", "")) if kind_fn.is_valid() else ""


# Where the cell's schools sit today: [{species, weight, base: Vector2, radius, phase}] (sizes and drift are added by schools()).
func placements(cell: Vector2i, day: int, season: String) -> Array:
	var key: Array = [cell, day, season]

	if _cache.has(key):
		return _cache[key]

	if _cache.size() >= int(cfg.get("cache_max", 2000)):
		_cache.clear()

	var out: Array = []

	if kind_fn.is_valid():
		var weights: Array = cfg.get("count_weights", [0.25, 0.35, 0.25, 0.15])
		var roll: float = unit(mix(cell.x, cell.y, day, 1))
		var count: int = 0
		var acc: float = 0.0

		for i in weights.size():
			acc += float(weights[i])

			if roll <= acc:
				count = i
				break

			count = i

		var radius_range: Array = cfg.get("radius_m", [3.0, 8.0])
		var raw: Array = []

		for slot in count:
			var h0: int = mix(cell.x, cell.y, day, 100 + slot)
			var placed: Dictionary = {}

			for attempt in int(cfg.get("place_tries", 6)):
				var x: float = (float(cell.x) + unit(mix(cell.x, cell.y, day, 200 + slot * 16 + attempt))) * cell_m
				var z: float = (float(cell.y) + unit(mix(cell.x, cell.y, day, 300 + slot * 16 + attempt))) * cell_m
				var kind: String = _kind_at(x, z)

				if kind == "":
					continue

				var species: String = _species_for(kind, season, unit(h0))

				if species != "":
					placed = {"species": species, "base": Vector2(x, z), "radius": lerpf(float(radius_range[0]), float(radius_range[1]), unit(h0 >> 4)), "phase": unit(h0 >> 8) * TAU, "weight": 0.5 + unit(h0 >> 12)}
					break

			if not placed.is_empty():
				raw.append(placed)

		var total: float = 0.0

		for p in raw:
			total += float(p["weight"])

		for p in raw:
			p["weight"] = float(p["weight"]) / total
			out.append(p)

	_cache[key] = out
	return out


# The cell's schools now: sizes are shares of `stock` (their sum never exceeds it), centres drifted with game time and kept on suitable water.
func schools(cell: Vector2i, day: int, season: String, stock: int, now_s: float) -> Array:
	var out: Array = []

	for p in placements(cell, day, season):
		var size: int = int(floor(float(stock) * float(p["weight"])))

		if size <= 0:
			continue

		var base: Vector2 = p["base"]
		var period: float = maxf(float(cfg.get("drift_period_game_s", 21600.0)), 1.0)
		var angle: float = now_s / period * TAU + float(p["phase"])
		var centre: Vector2 = base + Vector2(sin(angle), cos(angle * 0.7)) * float(cfg.get("drift_m", 12.0))
		var kind_there: String = _kind_at(centre.x, centre.y)

		if kind_there == "" or _species_for(kind_there, season, 0.0) == "" or not _lives_in(str(p["species"]), kind_there):
			centre = base

		out.append({"species": p["species"], "size": size, "centre": centre, "radius": p["radius"]})

	return out


func _lives_in(species: String, kind: String) -> bool:
	for row in cfg.get("species_by_kind", {}).get(kind, []):
		if str(row[0]) == species:
			return true

	return false


# The school factor at a point: {"factor", "species" of the school it is in or near ("" when none), "active"}. stock_fn: (cell) -> int.
func factor_at(x: float, z: float, day: int, season: String, now_s: float, stock_fn: Callable) -> Dictionary:
	var f: Dictionary = cfg.get("factor", {})
	var kind: String = _kind_at(x, z)

	if kind == "" or not cfg.get("species_by_kind", {}).has(kind):
		return {"factor": 1.0, "species": "", "active": false}

	var home: Vector2i = Vector2i(int(floor(x / cell_m)), int(floor(z / cell_m)))
	var best: float = float(f.get("far", 0.15))
	var species: String = ""
	var best_d: float = INF
	var at: Vector2 = Vector2(x, z)

	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var cell: Vector2i = home + Vector2i(dx, dz)

			for s in schools(cell, day, season, int(stock_fn.call(cell)), now_s):
				var d: float = at.distance_to(s["centre"])
				var radius: float = float(s["radius"])
				var got: float = float(f.get("far", 0.15))

				if d <= radius:
					got = float(f.get("inside", 1.0))
				elif d <= radius * float(f.get("near_radii", 2.0)):
					got = float(f.get("near", 0.5))

				if got > best or (got == best and got > float(f.get("far", 0.15)) and d < best_d):
					best = got
					best_d = d
					species = str(s["species"]) if got > float(f.get("far", 0.15)) else species

	return {"factor": best, "species": species, "active": true}
