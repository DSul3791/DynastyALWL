extends RefCounted

# The ground, water and geology answers for one scatter cell, bound to the tile under it (server_items._cell_reads, wired in terrain_server.gd).
# Each answer is the same one the server's general callables give (items.ground_height, water_near, water_depth_at, ore_near), but the tile is
# looked up once for the cell instead of once per read: generator.get_tile takes the generator's lock, which the block and flora workers hold
# thousands of times a second while a player runs into new ground, and a main-thread read waiting on it stalled every animal and world update
# (Dave's PC, 21 Nov 2026: one cell's copper and tin rocks took 409 ms, the same cell 3 ms on an idle server). A read off the bound tile (a
# probe reaching past the tile edge) takes the general path, so every answer stays exact.

const DrinkRulesScript := preload("res://src/shared/drink_rules.gd")


# {"ground": (x, z) -> height, "water_near": (pos, reach) -> bool, "water_depth_at": (pos) -> metres, "ore_near": (pos, reach, names, depth) -> ore}
# for the tile under (x, z). `water_live` may be null (no running water yet): the depth is then 0, as _water_at gives. `cut_off` as water_at's.
static func bound(generator, water_live, x: float, z: float, cut_off: Callable = Callable()) -> Dictionary:
	var tile: Vector2i = generator.tile_of(x, z)
	var data = generator.get_tile(tile)
	var water_data = water_live.data_of(tile) if water_live != null else null
	var tile_for: Callable = func(px: float, pz: float):   # the bound tile when the point is on it, else the point's own (the general path)
		var own: Vector2i = generator.tile_of(px, pz)
		return data if own == tile else generator.get_tile(own)

	var ground: Callable = func(px: float, pz: float) -> float: return generator.surface_height_on(data, px, pz)
	var near: Callable = func(pos: Vector3, reach: float) -> bool: return DrinkRulesScript.water_near(tile_for.call(pos.x, pos.z), pos, reach, false)
	var ore: Callable = func(pos: Vector3, reach: float, names: Dictionary, depth_m: float) -> String: return tile_for.call(pos.x, pos.z).ore_at(pos, reach, names, depth_m)
	var depth: Callable = func(pos: Vector3) -> float:   # water_at below, written out: a lambda in a static func calls no other static func of the script
		var own: Vector2i = generator.tile_of(pos.x, pos.z)
		var own_water = water_data if own == tile else (water_live.data_of(own) if water_live != null else null)
		var ground_y: float = generator.surface_height_on(tile_for.call(pos.x, pos.z), pos.x, pos.z)
		var surface: float = NAN

		if ground_y <= 0.0 and not (cut_off.is_valid() and bool(cut_off.call(pos.x, pos.z))):
			surface = 0.0
		elif water_live != null:
			var sim: PackedFloat32Array = own_water.sim_snapshot() if own_water != null else PackedFloat32Array()

			if not sim.is_empty():
				surface = sim[own_water.nearest(pos.x, pos.z)]

		return 0.0 if is_nan(surface) else maxf(surface - ground_y, 0.0)

	return {"ground": ground, "water_near": near, "water_depth_at": depth, "ore_near": ore}


# [water surface or NAN, ground] at a position, on its tile `data` and the running water's tile `water_data` (terrain_server._water_at reads
# through here; bound()'s depth writes the same out): the sea at 0 over ground at or under 0, else the live sim's level, NAN with no sim (or no running water at all, has_live false).
# `cut_off` (x, z) -> bool, optional: true where ground below sea level is cut off from the open sea (fog_ground.gd under_land, the fen
# flats, Lane A 22 Nov 2026); there it is not the sea, and the live sim's level stands instead, as on land.
static func water_at(generator, data, water_data, has_live: bool, position: Vector3, cut_off: Callable = Callable()) -> Array:
	var ground: float = generator.surface_height_on(data, position.x, position.z)
	var surface: float = NAN

	if ground <= 0.0 and not (cut_off.is_valid() and bool(cut_off.call(position.x, position.z))):
		surface = 0.0
	elif has_live:
		var sim: PackedFloat32Array = water_data.sim_snapshot() if water_data != null else PackedFloat32Array()

		if not sim.is_empty():
			surface = sim[water_data.nearest(position.x, position.z)]

	return [surface, ground]
