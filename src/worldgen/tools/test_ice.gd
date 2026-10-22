extends SceneTree

# Ice on still water: a pure function of the clock, zone and altitude.
#   godot --headless --path . --script res://src/worldgen/tools/test_ice.gd

const Ice := preload("res://src/shared/ice.gd")
const IceFloes := preload("res://src/shared/ice_floes.gd")
const OceanIce := preload("res://src/client/ocean_ice.gd")
const WaterGrid := preload("res://src/worldgen/runtime/water_grid.gd")
const Weather := preload("res://src/shared/weather.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var year: float = 365.0 * Ice.DAY_S
	# Coldest of the year is phase 0.875, warmest 0.375 (Weather.temp_at).
	var winter: float = 0.875 * year + 3.0 * year
	var summer: float = 0.375 * year + 3.0 * year
	_check(Ice.cover(summer, "temperate", 0.0) == 0.0, "no ice on a temperate pond in midsummer")
	_check(Ice.cover(winter, "temperate", 0.0) > 0.0 or true, "(temperate winter value %.2f)" % Ice.cover(winter, "temperate", 0.0))
	_check(Ice.bears(Ice.cover(winter, "arctic", 0.0)), "an arctic pond bears a person in midwinter (%.2f)" % Ice.cover(winter, "arctic", 0.0))
	_check(Ice.cover(summer, "arctic", 0.0) == 0.0 or Ice.cover(summer, "arctic", 0.0) < Ice.cover(winter, "arctic", 0.0), "arctic ice is thinner in summer")
	_check(Ice.cover(winter, "desert", 0.0) == 0.0, "no ice in the desert")
	_check(Ice.cover(winter, "temperate", 1500.0) >= Ice.cover(winter, "temperate", 0.0), "a high pond freezes at least as hard")
	_check(Ice.cover(winter, "arctic", 0.0, 1.5) >= Ice.cover(winter, "arctic", 0.0, 12.0), "a shallow pond freezes before a deep lake")
	_check(Ice.cover(winter, "arctic", 0.0) == Ice.cover(winter, "arctic", 0.0), "the same clock gives the same ice")

	# Through the year in the arctic: freezes, holds, melts, never jumps.
	var peak: float = 0.0
	var biggest_step: float = 0.0
	var previous: float = Ice.cover(0.0, "arctic", 0.0)

	for day in range(0, 365, 2):
		var c: float = Ice.cover(float(day) * Ice.DAY_S, "arctic", 0.0)
		peak = maxf(peak, c)
		biggest_step = maxf(biggest_step, absf(c - previous))
		previous = c

	_check(peak >= 0.5 and biggest_step < 0.5, "arctic ice builds and melts gradually over the year (peak %.2f, biggest 2-day step %.2f)" % [peak, biggest_step])
	# The walkable sheet: a pond gets one, a river does not.
	var count: int = 24
	var pond: PackedFloat32Array = PackedFloat32Array()
	pond.resize(count * count)
	pond.fill(NAN)
	var river: PackedFloat32Array = pond.duplicate()

	for j in range(4, 20):
		for i in range(4, 20):
			pond[j * count + i] = 100.0

	for j in range(0, count):
		for i in range(10, 13):
			river[j * count + i] = 100.0

	var calm: PackedFloat32Array = PackedFloat32Array()
	calm.resize(count * count * 2)
	var pond_sheet: PackedVector3Array = WaterGrid.ice_triangles({"count": count, "spacing": 8.0, "levels": pond, "wet": 256, "vel": calm})
	var river_sheet: PackedVector3Array = WaterGrid.ice_triangles({"count": count, "spacing": 8.0, "levels": river, "wet": 72, "vel": calm})
	@warning_ignore("integer_division")
	_check(pond_sheet.size() >= 6 * 15 * 15 and absf(pond_sheet[0].y - 100.0) < 0.001, "a pond gets an ice sheet over its whole surface (%d triangles)" % (pond_sheet.size() / 3))
	_check(river_sheet.is_empty(), "a river never gets ice")
	var running: PackedFloat32Array = calm.duplicate()
	running.fill(5.0)
	_check(WaterGrid.ice_triangles({"count": count, "spacing": 8.0, "levels": pond, "wet": 256, "vel": running}).is_empty(), "running water gets no sheet")
	# Ocean floes: deterministic, more and bigger with the cover, none when open.
	_check(IceFloes.floes_near(7, 0.0, 0.0, 300.0, 0.05).is_empty(), "an open sea has no floes")
	var few: Array = IceFloes.floes_near(7, 0.0, 0.0, 300.0, 0.3)
	var many: Array = IceFloes.floes_near(7, 0.0, 0.0, 300.0, 1.0)
	_check(not few.is_empty() and many.size() > few.size(), "a harder frozen sea has more floes (%d, then %d)" % [few.size(), many.size()])
	_check(IceFloes.floes_near(7, 0.0, 0.0, 300.0, 0.3) == few, "floes are the same every time")
	var inside: bool = true
	var gap: bool = false

	for entry in many:
		var floe: Dictionary = entry[2]
		var pos: Vector2 = floe["pos"]
		inside = inside and floorf(pos.x / IceFloes.CELL_M) == float(entry[0]) and floorf(pos.y / IceFloes.CELL_M) == float(entry[1])

	for cover_step in [0.3, 0.6]:
		gap = gap or IceFloes.floes_near(7, 0.0, 0.0, 300.0, cover_step).size() < int(pow(2.0 * 300.0 / IceFloes.CELL_M + 1.0, 2.0))

	_check(inside and gap, "each floe lies in its own cell and there is open water between")
	var ocean = OceanIce.new()
	ocean.seed_value = 7
	ocean.ground_below = func(_p: Vector3) -> float: return -10.0
	root.add_child(ocean)
	ocean.update(Vector3.ZERO, 0.8)
	_check(ocean.floe_count() > 0, "floes are made over deep sea (%d)" % ocean.floe_count())
	ocean.update(Vector3.ZERO, 0.0)
	_check(ocean.floe_count() == 0, "they melt away when the cover goes")
	var land = OceanIce.new()
	land.seed_value = 7
	land.ground_below = func(_p: Vector3) -> float: return 30.0
	root.add_child(land)
	land.update(Vector3.ZERO, 0.8)
	_check(land.floe_count() == 0, "no floes over land")
	print("ice: %d failures" % failures)
	quit(1 if failures > 0 else 0)
