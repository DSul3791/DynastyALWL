extends SceneTree

# Sullivan water live: the dig windows the server hub runs (src/sullivan_water/live/dig_windows.gd), on made-up ground. A river runs along
# z 40 to 48 m (bed -1 m, water at 0.5 m in the hub's 8 m levels). A ditch is dug from the river northward: the window opens there, the
# river cells on its border are held at the hub's level, water runs into the ditch, and publish() draws it into the 8 m levels.
#   godot --headless --path . --script res://src/worldgen/tools/test_sullivan_water_live.gd

const DigWindows := preload("res://src/sullivan_water/live/dig_windows.gd")

var failures: int = 0


class Ground:
	extends RefCounted
	var digs: Array = []   # [centre, radius]

	func top(_x: float, z: float) -> float:
		return -1.0 if z >= 40.0 and z < 48.0 else 1.0

	func sdf(p: Vector3) -> float:
		var d: float = p.y - top(p.x, p.z)

		for op in digs:
			d = maxf(d, float(op[1]) - (p - Vector3(op[0])).length())
		return d

	func is_loaded(_box: AABB) -> bool:
		return true

	func scan_range(_x: float, _z: float) -> Vector2:
		return Vector2(-10.0, 10.0)

	func forget(_box: AABB) -> void:
		pass


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var ground = Ground.new()
	var live = DigWindows.new()
	live.source = ground
	var samples: int = 32
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(samples * samples)

	for sj in range(samples):
		for si in range(samples):
			var z: float = sj * 8.0
			levels[sj * samples + si] = 0.5 if z >= 40.0 and z < 48.0 else NAN

	var level_at: Callable = func(x: float, z: float) -> float:
		var si: int = int(round(x / 8.0))
		var sj: int = int(round(z / 8.0))
		return levels[sj * samples + si] if si >= 0 and sj >= 0 and si < samples and sj < samples else NAN

	# The ditch, dug the way the client's --dig-ditch does it: a 1.5 m sphere centred on the ground surface every 1.5 m, from the river bank
	# (z 40) north to about z 20, along x 100. That is a 3 m wide ditch whose axis lies on a cell edge, as at the game's check spot.
	for step in range(14):
		var c: Vector3 = Vector3(100.0, 1.0, 40.0 - step * 1.5)
		ground.digs.append([c, 1.5])
		live.dig(c, 1.5, false)

	live.update(1.0, level_at)
	_check(live.windows.size() == 1, "one window opened for the ditch (%d)" % live.windows.size())
	var grid = live.windows[0]["grid"]
	var adapter = live.windows[0]["adapter"]
	_check(grid.fixed.size() > 0, "the river cells on the window border are held at the river level (%d)" % grid.fixed.size())

	var ditch_i: int = int((100.0 - adapter.origin.x) / 2.0)
	var ditch_j: int = int((30.0 - adapter.origin.y) / 2.0)
	_check(grid.bed[grid.index(ditch_i, ditch_j)] < 0.0, "the ditch is in the window's ground (bed %.2f m)" % grid.bed[grid.index(ditch_i, ditch_j)])

	for _s in range(120):
		live.update(1.0, level_at)

	var d: float = grid.depth(ditch_i, ditch_j)
	_check(d > 0.2, "river water ran up the ditch (%.2f m deep at z 30)" % d)
	_check(absf(grid.ledger_residual()) < 1.0e-6 * maxf(grid.total_volume(), 1.0), "window ledger balances with the border in and out (%s)" % String.num_scientific(grid.ledger_residual()))

	var drawn: PackedFloat32Array = levels.duplicate()
	var changed: bool = live.publish(drawn, samples, 0.0, 0.0)
	var k: int = 4 * samples + 12   # the 8 m sample covering x 96..104, z 32..40
	_check(changed and not is_nan(drawn[k]), "publish draws the ditch water into the 8 m levels (%.2f m at z 32)" % drawn[k])

	# The ditch goes on north past z 0, the edge of the 96 m tile: the region joins the next tile in one grid, with every cubic metre
	# copied, and the water keeps running up the ditch across the old edge (guide 26.1: one owner per face, no seam).
	var before_m3: float = grid.total_volume()

	for step in range(14, 44):
		var c: Vector3 = Vector3(100.0, 1.0, 40.0 - step * 1.5)
		ground.digs.append([c, 1.5])
		live.dig(c, 1.5, false)

	live.update(0.0, level_at)
	_check(live.windows.size() == 1 and live.windows[0]["tiles"].get_area() == 2, "the ditch past the tile edge joined one region of 2 tiles (%d regions, %s)" % [live.windows.size(), str(live.windows[0]["tiles"])])
	_check(live.joined == 1 and live.last_copied_m3 == before_m3, "the join copied every m3 of the old region (%.6f of %.6f)" % [live.last_copied_m3, before_m3])
	grid = live.windows[0]["grid"]
	adapter = live.windows[0]["adapter"]

	for _s in range(300):
		live.update(1.0, level_at)

	var far_i: int = int((100.0 - adapter.origin.x) / 2.0)
	var far_j: int = int((-19.0 - adapter.origin.y) / 2.0)
	var far_d: float = grid.depth(far_i, far_j)
	_check(far_d > 0.2, "river water ran up the ditch past the old tile edge (%.2f m deep at z -19)" % far_d)
	_check(absf(grid.ledger_residual()) < 1.0e-6 * maxf(grid.total_volume(), 1.0), "joined region ledger balances (%s)" % String.num_scientific(grid.ledger_residual()))

	# Sleep and wake (guide 26.2): a dig far away needs all 4 tiles (its reach crosses a tile corner), so the ditch's region sleeps with
	# all its water; a dig back in the ditch wakes it, and the new grid starts from exactly that water.
	var kept_m3: float = grid.total_volume()
	ground.digs.append([Vector3(288.0, 1.0, 288.0), 1.5])
	live.dig(Vector3(288.0, 1.0, 288.0), 1.5, false)
	live.update(0.0, level_at)
	_check(live.windows.size() == 1 and live.sleeping.size() == 1 and live.sleeping[0]["grid"].total_volume() == kept_m3, "the ditch region sleeps with all %.3f m3 when the far dig needs the tiles" % kept_m3)

	ground.digs.append([Vector3(100.0, 1.0, 30.0), 1.5])
	live.dig(Vector3(100.0, 1.0, 30.0), 1.5, false)
	live.update(0.0, level_at)
	_check(live.sleeping.size() == 1 and live.windows.size() == 1 and live.windows[0]["tiles"].get_area() == 2, "a dig in the ditch wakes its region (the far one sleeps instead)")
	_check(live.last_copied_m3 == kept_m3 and live.closed_m3 == 0.0, "woken with exactly the water it slept with (%.6f of %.6f m3), none dropped" % [live.last_copied_m3, kept_m3])

	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)
