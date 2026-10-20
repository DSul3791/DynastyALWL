extends RefCounted

# Where the canopy shelters the ground (owner, 2026-10-20: rain soaks the ground everywhere
# but stays dry under trees; Q8: simple, anywhere under a tree's crown diameter counts, any
# tree, any season, one fixed value). A small map around the player, one texel per metre,
# 255 under a crown and 0 in the open, redrawn from the flora view's trees when the player has
# moved or the trees changed. The ground shader reads it (no wet or snow under a canopy), the
# rain streaks vanish over it, and cover_at() is the shared query for sound and later fire and
# building (client only, no network).

const SIZE_PX := 128
const METRES := 128.0                    # the map covers this many metres, centred on the player
const REBUILD_M := 12.0                  # redraw when the player is this far from the last centre
const MIN_INTERVAL_MSEC := 400

var texture: ImageTexture
var origin: Vector2 = Vector2.ZERO       # world x, z of the map's corner
var discs: int = 0                       # crowns drawn in the last rebuild

var _data: PackedByteArray = PackedByteArray()
var _image: Image
var _centre: Vector2 = Vector2(INF, INF)
var _version: int = -1
var _last_msec: int = -100000


func _init() -> void:
	_data.resize(SIZE_PX * SIZE_PX)
	_image = Image.create_from_data(SIZE_PX, SIZE_PX, false, Image.FORMAT_R8, _data)
	texture = ImageTexture.create_from_image(_image)


# Call every frame (cheap when nothing changed). `flora` is the FloraView.
func update(flora, centre: Vector2) -> void:
	var now: int = Time.get_ticks_msec()
	var moved: bool = centre.distance_to(_centre) >= REBUILD_M
	var changed: bool = flora.canopy_version != _version

	if not (moved or changed) or now - _last_msec < MIN_INTERVAL_MSEC:
		return

	_last_msec = now
	_version = flora.canopy_version
	_centre = centre
	origin = (centre - Vector2(METRES, METRES) * 0.5).floor()
	_data.fill(0)
	var list: Array = flora.canopy_discs(centre.x, centre.y, METRES * 0.75)
	discs = list.size()

	for disc in list:
		_stamp(float(disc[0]) - origin.x, float(disc[1]) - origin.y, float(disc[2]))

	_image.set_data(SIZE_PX, SIZE_PX, false, Image.FORMAT_R8, _data)
	texture.update(_image)


func _stamp(cx: float, cz: float, radius: float) -> void:
	var x0: int = maxi(int(floor(cx - radius)), 0)
	var x1: int = mini(int(ceil(cx + radius)), SIZE_PX - 1)
	var z0: int = maxi(int(floor(cz - radius)), 0)
	var z1: int = mini(int(ceil(cz + radius)), SIZE_PX - 1)
	var r2: float = radius * radius

	for z in range(z0, z1 + 1):
		var dz: float = float(z) + 0.5 - cz

		for x in range(x0, x1 + 1):
			var dx: float = float(x) + 0.5 - cx

			if dx * dx + dz * dz <= r2:
				_data[z * SIZE_PX + x] = 255


# Cover at a world point, 0 (open) to 1 (under a crown); 0 outside the map.
func cover_at(x: float, z: float) -> float:
	var px: int = int(floor(x - origin.x))
	var pz: int = int(floor(z - origin.y))

	if px < 0 or pz < 0 or px >= SIZE_PX or pz >= SIZE_PX:
		return 0.0

	return float(_data[pz * SIZE_PX + px]) / 255.0
