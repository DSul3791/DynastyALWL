extends RefCounted

# Trampled grass (owner, 2026-10-20: grass gets stomped down where someone walks through it and slowly
# comes back up after about 5 minutes of real time). Client only, look only. A 256 x 256 map of 1 m
# texels, world-aligned and wrapping (texel = world metre mod 256, so nothing scrolls), holds for every
# trodden metre the real time it was last trodden on (16 bits of seconds in R and G) and a flag in B. The
# grass shader (grass_view.gd) reads it once per card and shrinks the blades by how recently the ground
# was trodden, recovering fully after RECOVER_S, so no per-frame decay work happens on the CPU.
#
# stamp(position) is the one call: the local player's feet every step, and later every other player or
# creature the client can see. Columns and rows 128 m away from the player are cleared as the player
# moves, so a wrapped texel never shows a stamp from the far side of the map (grass reaches 90 m).

const SIZE := 256
const RECOVER_S := 300.0
const RADIUS_M := 1.1
var upload_msec: int = 100              # 200 on Low (set_trample_rate in grass_view.gd)

var texture: ImageTexture = null

var _image: Image = null
var _data: PackedByteArray = PackedByteArray()
var _dirty: bool = false
var _upload_msec: int = 0
var _tx: int = 1 << 30
var _tz: int = 1 << 30


func _init() -> void:
	_data.resize(SIZE * SIZE * 3)
	_data.fill(0)
	_image = Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, _data)
	texture = ImageTexture.create_from_image(_image)


# The clock the shader compares the stamps with: whole seconds of real time, 16 bits.
static func now_s() -> float:
	return fmod(floor(Time.get_unix_time_from_system()), 65536.0)


func stamp(position: Vector3) -> void:
	var now: int = int(now_s())
	var lo: int = now & 255
	var hi: int = (now >> 8) & 255
	var x0: int = int(floor(position.x - RADIUS_M))
	var x1: int = int(floor(position.x + RADIUS_M))
	var z0: int = int(floor(position.z - RADIUS_M))
	var z1: int = int(floor(position.z + RADIUS_M))

	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			# Texel centres within the radius.
			var dx: float = float(x) + 0.5 - position.x
			var dz: float = float(z) + 0.5 - position.z

			if dx * dx + dz * dz > RADIUS_M * RADIUS_M:
				continue

			var o: int = (posmod(z, SIZE) * SIZE + posmod(x, SIZE)) * 3
			_data[o] = lo
			_data[o + 1] = hi
			_data[o + 2] = 255

	_dirty = true
	_move_window(int(floor(position.x)), int(floor(position.z)))


# Clears the column and the row on the far side of the wrap whenever the player enters a new metre.
func _move_window(tx: int, tz: int) -> void:
	if tx != _tx:
		var column: int = posmod(tx + SIZE / 2, SIZE)

		for z in range(SIZE):
			_data[(z * SIZE + column) * 3 + 2] = 0

		_tx = tx

	if tz != _tz:
		var row: int = posmod(tz + SIZE / 2, SIZE)

		for x in range(SIZE):
			_data[(row * SIZE + x) * 3 + 2] = 0

		_tz = tz


# Call every frame: uploads the map at most ten times a second (five on Low), and only when something changed.
func flush() -> void:
	if not _dirty:
		return

	var now: int = Time.get_ticks_msec()

	if now - _upload_msec < upload_msec:
		return

	_upload_msec = now
	_dirty = false
	_image.set_data(SIZE, SIZE, false, Image.FORMAT_RGB8, _data)
	texture.update(_image)
