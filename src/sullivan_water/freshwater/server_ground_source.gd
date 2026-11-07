extends RefCounted

# Sullivan water, milestone M3 second half: the server's real ground as a source for the terrain adapter and the edit coordinator
# (Sonny, 7 Nov 2026). Guide sections 4.1, 17 and 24.
#
# In this game the server owns the ground (docs/water/runtime_inventory.md, section 4): a dig is a sphere written to the server's edit log
# (server_block_store.edit_sphere), and every block is the generated ground with the logged digs and fills cut again on top
# (server_block_store.load_block). So the water reads exactly the ground the players get, after their edits, never a client's mesh or
# collision (guide 17, fail condition "sampler reading stale collision").
#
# sdf(p): the SDF channel of the LOD 0 block holding p (16 m blocks, loaded through store.load_block and kept until an edit touches them),
#   interpolated linearly in y between the voxel above and below, so the adapter's bisection finds the surface between voxels.
#   Negative is solid (terrain_layout.gd).
# scan_range(x, z): the generator's surface height there, plus SCAN_UP_M and minus SCAN_DOWN_M, so a column is scanned over 48 m, not the
#   whole world height. A fill higher than SCAN_UP_M or a pit deeper than SCAN_DOWN_M reads as UNKNOWN, and the edit is refused, never
#   guessed.
# is_loaded(box): the server can build any block of the world, so "loaded" means inside the world's tiles.
# edit_sphere(center, radius, add): the server's own dig or fill (store.dig_sphere / fill_sphere). The blocks it touched are dropped from
#   the cache, so the next read sees the edit.
#
# Not here yet: undo. The server's edit log has no undo, so an edit that roofs over standing water freezes the region with an error
# (terrain_water_edit_coordinator.gd) instead of being undone. Roofing water with a sphere fill is rare, and the freeze makes it loud.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

const BLOCK := 16
const SCAN_UP_M := 4.0         # first try: generated ground plus a small fill (a 19.7 s build of 4 tiles on Dave's PC, 7 Nov, came mostly from
                               # loading air blocks 16 m up). A column still solid there is scanned again up to SCAN_UP_WIDE_M (scan_range_wide).
const SCAN_UP_WIDE_M := 16.0
const SCAN_DOWN_M := 32.0
const FILL_MATERIAL := 0       # the soil number a water-side fill uses; the caller can set `fill_material`

var store                      # server_block_store.gd
var fill_material: int = FILL_MATERIAL
var _blocks: Dictionary = {}   # Vector3i -> VoxelBuffer
var blocks_loaded: int = 0     # how many blocks were read (a cost measure)


func _init(p_store) -> void:
	store = p_store


func sdf(p: Vector3) -> float:
	var x: int = floori(p.x)
	var z: int = floori(p.z)
	var y0: int = floori(p.y)
	var t: float = p.y - float(y0)
	var a: float = _voxel(x, y0, z)

	if t <= 0.0:
		return a

	return lerpf(a, _voxel(x, y0 + 1, z), t)


func scan_range(x: float, z: float) -> Vector2:
	var surface: float = float(store.generator.surface_height(x, z))
	return Vector2(surface - SCAN_DOWN_M, surface + SCAN_UP_M)


func scan_range_wide(x: float, z: float) -> Vector2:
	var surface: float = float(store.generator.surface_height(x, z))
	return Vector2(surface - SCAN_DOWN_M, surface + SCAN_UP_WIDE_M)


# sdf() reads the voxel at floor(x), floor(z), so every point in one 1 m square reads the same column: the adapter reads it once.
func column_key(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x), floori(z))


func is_loaded(box: AABB) -> bool:
	var size: float = float(store.generator.tile_size_m) * float(store.generator.tile_count)
	return box.position.x >= 0.0 and box.position.z >= 0.0 and box.end.x <= size and box.end.z <= size


func edit_sphere(center: Vector3, radius: float, add: bool) -> bool:
	if add:
		store.fill_sphere(center, radius, fill_material)
	else:
		store.dig_sphere(center, radius)

	forget(AABB(center - Vector3.ONE * (radius + 1.0), Vector3.ONE * 2.0 * (radius + 1.0)))
	return true


# Drops the cached blocks inside `box`, so the next read loads them again (after any edit, from anywhere).
func forget(box: AABB) -> void:
	var lo: Vector3i = Vector3i(floori(box.position.x / BLOCK), floori(box.position.y / BLOCK), floori(box.position.z / BLOCK))
	var hi: Vector3i = Vector3i(floori(box.end.x / BLOCK), floori(box.end.y / BLOCK), floori(box.end.z / BLOCK))

	for bx in range(lo.x, hi.x + 1):
		for by in range(lo.y, hi.y + 1):
			for bz in range(lo.z, hi.z + 1):
				_blocks.erase(Vector3i(bx, by, bz))


func _voxel(x: int, y: int, z: int) -> float:
	var block: Vector3i = Vector3i(floori(float(x) / BLOCK), floori(float(y) / BLOCK), floori(float(z) / BLOCK))
	var buffer: VoxelBuffer = _blocks.get(block)

	if buffer == null:
		buffer = Layout.make_buffer(BLOCK)
		store.load_block(buffer, block, 0)
		_blocks[block] = buffer
		blocks_loaded += 1

	return buffer.get_voxel_f(x - block.x * BLOCK, y - block.y * BLOCK, z - block.z * BLOCK, Layout.CHANNEL_SDF)
