extends RefCounted

const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")

# The summits near the player, for the cap cloud (cap_cloud.gd) and the summit snow (ground_material.gd), art_weather_light.md
# 7.1 and 8.2.1. The server finds them in its baked tiles (server_coarse_ground.gd, from the coarse "low_height" map) and sends the
# highest round the player's tile (summits); the client has no tiles (server/client split A3). Asked again only when the player
# moves into another tile, or when an ask went unanswered for ASK_AGAIN_MSEC. With no answer there are no caps and no summit snow.

const ASK_AGAIN_MSEC := 15000

var tile_size_m: float = 15360.0
var list: Array = []                   # [Vector3(x, height, z)], highest first; empty until found
var ask: Callable                      # sends the server the tile (Vector2i) to search round
var _tile: Vector2i = Vector2i(1 << 30, 0)
var _asked_msec: int = 0


func setup(world: Dictionary, asker: Callable) -> void:
	tile_size_m = float(world.get("tile_size_m", 15360))
	ask = asker


# Every frame or so: asks for the summits when the player is in a new tile.
func update(at: Vector3) -> void:
	var tile: Vector2i = Vector2i(int(floor(at.x / tile_size_m)), int(floor(at.z / tile_size_m)))

	if tile == _tile and (_asked_msec == 0 or Time.get_ticks_msec() - _asked_msec < ASK_AGAIN_MSEC):
		return

	_tile = tile
	_asked_msec = Time.get_ticks_msec()
	ask.call(tile)


# The server's answer for `tile` (highest first); an answer for a tile the player has left is dropped.
func receive(tile: Vector2i, tops: PackedVector3Array) -> void:
	if tile != _tile:
		return

	_asked_msec = 0
	list = Array(tops)
	FreezeWatchScript.printer.line("Summits: %d found round tile %s, highest %.0f m" % [list.size(), str(tile), list[0].y if not list.is_empty() else 0.0])


# The highest summit within `within_m` of `at` (Vector3(x, height, z)), or Vector3.ZERO when none is known.
func highest_near(at: Vector3, within_m: float) -> Vector3:
	for top in list:
		var dx: float = float(top.x) - at.x
		var dz: float = float(top.z) - at.z

		if dx * dx + dz * dz <= within_m * within_m:
			return top

	return Vector3.ZERO
