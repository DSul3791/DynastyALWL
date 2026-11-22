extends RefCounted

# The thaw's open shore moat on the server (Kathleen frozen_water_look.md 4, #729; ice_walk_feel.md 5): in a thaw the client leaves the ice sheet's
# quads within IceFeel.moat_cells(thaw) collider cells (8 m) of a dry point out, so the player sees open water at the shore. The server's ice rule
# (_on_ice: drinking and filling without a hole, fishing, animals on ice) asks this so it agrees (coordinator 22 Nov 2026). Cheap: the thaw is kept
# per 1 km band of z and 5 m of height for one game hour, and the dry test (at most 25 water reads) runs only while a moat is open.

const Ice := preload("res://src/shared/ice.gd")
const FrozenWater := preload("res://src/client/frozen_water.gd")
const IceFeel := preload("res://src/client/ice_feel.gd")

const CELL_M := 8.0            # the client's collider cells (IceFeel.moat_cells counts these)
const POND_DEPTH_M := 3.0      # the depth the client's thaw is worked out at (terrain_client ICE_POND_DEPTH_M)
const KEEP_S := 3600.0         # game seconds a band's moat width is kept

var _bands: Dictionary = {}    # Vector2i(z band, height band) -> [moat cells, game seconds until]


# Whether `pos` (on the water) lies in the open moat: `moat` cells, and some point within moat * CELL_M of it (the 8 m grid round it) is dry.
static func in_moat(pos: Vector3, moat: int, water_near: Callable) -> bool:
	if moat <= 0 or not water_near.is_valid():
		return false

	for dj in range(-moat, moat + 1):
		for di in range(-moat, moat + 1):
			if (di != 0 or dj != 0) and not bool(water_near.call(pos + Vector3(float(di) * CELL_M, 0.0, float(dj) * CELL_M), 0.0)):
				return true

	return false


# The moat width in cells at `pos` now, as the client works it out (Ice.season at the pond depth, FrozenWater.thaw_of, IceFeel.moat_cells).
func moat_cells(pos: Vector3, game_s: float, zone_group: String, seed_value: int) -> int:
	var key: Vector2i = Vector2i(floori(pos.z / 1000.0), roundi(maxf(pos.y, 0.0) / 5.0))
	var kept: Array = _bands.get(key, [])

	if kept.size() == 2 and game_s < float(kept[1]) and game_s >= float(kept[1]) - KEEP_S:
		return int(kept[0])

	if _bands.size() > 256:
		_bands.clear()

	var season: Dictionary = Ice.season(game_s, zone_group, maxf(pos.y, 0.0), POND_DEPTH_M, seed_value)
	var moat: int = IceFeel.moat_cells(FrozenWater.thaw_of(float(season["cover"]), float(season["peak"])))
	_bands[key] = [moat, game_s + KEEP_S]
	return moat
