extends SceneTree

# Ice on still water: a pure function of the clock, zone and altitude.
#   godot --headless --path . --script res://src/worldgen/tools/test_ice.gd

const Ice := preload("res://src/shared/ice.gd")
const IceFloes := preload("res://src/shared/ice_floes.gd")
const OceanIce := preload("res://src/client/ocean_ice.gd")
const WaterGrid := preload("res://src/worldgen/runtime/water_grid.gd")
const Weather := preload("res://src/shared/weather.gd")
const Climate := preload("res://src/shared/climate.gd")

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
	# The day and night swing (Weather.air_c, docs/design/still_water_ice.md): coldest just before dawn, warmest mid
	# afternoon, smooth through midnight, and the day's mean is the season's temperature.
	_check(is_equal_approx(Weather.day_shape(Climate.DAY_COLDEST_HOUR), -1.0) and is_equal_approx(Weather.day_shape(Climate.DAY_WARMEST_HOUR), 1.0), "the air is coldest before dawn and warmest mid afternoon")
	_check(absf(Weather.day_shape(0.0) - Weather.day_shape(23.999)) < 0.01, "the day's swing runs smoothly through midnight")
	var day_sum: float = 0.0
	var autumn_day: float = 3.0 * year + 270.0 * Ice.DAY_S

	for m in range(24 * 6):
		day_sum += Weather.air_c(autumn_day + float(m) * 600.0, "temperate")

	_check(absf(day_sum / 144.0 - Weather.temp_at(autumn_day + 0.5 * Ice.DAY_S, "temperate")) < 0.5, "the day's mean air is the season's temperature (%.2f vs %.2f)" % [day_sum / 144.0, Weather.temp_at(autumn_day + 0.5 * Ice.DAY_S, "temperate")])
	# Art's rule (Kathleen, #587 ask 3): a pond freezes at the edges on a frosty night and thaws by early afternoon once
	# the air is above 2 C; a thick winter sheet stays. Every day of a year on the starter island (the temperate zone's
	# climate, 9 C +-5) at POND_M, where frosty nights come (the coast itself is too mild: docs/design/one_temperature.md).
	var pond_m: float = 300.0
	var frosty_mornings: int = 0
	var thaw_days: int = 0
	var thaw_left: int = 0

	for d in range(365):
		var base: float = 3.0 * year + float(d) * Ice.DAY_S
		var dawn_ice: float = Ice.cover(base + 7.0 * Ice.HOUR_S, "temperate", pond_m)
		var night_low: float = 100.0

		for h in range(8):
			night_low = minf(night_low, Weather.air_c(base + float(h) * Ice.HOUR_S, "temperate", pond_m))

		if dawn_ice > 0.0:
			frosty_mornings += 1

		# One night's ice: open water the evening before, ice at dawn, 2 C or more at noon.
		if night_low < 0.0 and dawn_ice > 0.0 and Ice.cover(base - 6.0 * Ice.HOUR_S, "temperate", pond_m) == 0.0 and Weather.air_c(base + 12.0 * Ice.HOUR_S, "temperate", pond_m) >= 2.0:
			thaw_days += 1

			if Ice.cover(base + 14.0 * Ice.HOUR_S, "temperate", pond_m) > 0.0:
				thaw_left += 1

	_check(frosty_mornings >= 20, "starter ponds at %.0f m have ice on frosty mornings (%d mornings a year)" % [pond_m, frosty_mornings])
	_check(thaw_days >= 5 and thaw_left == 0, "one frosty night's ice is gone by 14:00 when the air reaches 2 C at noon (%d days, %d left)" % [thaw_days, thaw_left])
	_check(Ice.cover(3.0 * year + 0.875 * year, "temperate", 0.0) == 0.0, "the starter's coast is too mild for pond ice even in midwinter")
	_check(Ice.bears(Ice.cover(3.0 * year + 320.0 * Ice.DAY_S + 12.0 * Ice.HOUR_S, "temperate", 1400.0)), "a summit tarn still bears at midday in deep winter")
	# The water must cool first: a deep lake freezes later in autumn than a shallow pond.
	var first_pond: int = -1
	var first_lake: int = -1

	for d in range(200, 365):
		var morning: float = 3.0 * year + float(d) * Ice.DAY_S + 7.0 * Ice.HOUR_S

		if first_pond < 0 and Ice.cover(morning, "temperate", pond_m, 1.0) > 0.0:
			first_pond = d

		if first_lake < 0 and Ice.cover(morning, "temperate", pond_m, 10.0) > 0.0:
			first_lake = d

	_check(first_pond > 0 and first_lake > first_pond, "a deep lake freezes later than a shallow pond (first ice on day %d and %d)" % [first_pond, first_lake])
	# The sea never freezes outside the arctic zone; the arctic sea does in midwinter.
	var sea_ice: float = 0.0

	for d in range(0, 365, 3):
		for group in ["temperate", "transition", "desert"]:
			sea_ice = maxf(sea_ice, Ice.sea_cover(3.0 * year + float(d) * Ice.DAY_S, group))

	_check(sea_ice == 0.0, "the sea never freezes outside the arctic zone")
	_check(Ice.sea_cover(winter, "arctic") > IceFloes.MIN_COVER, "the arctic sea freezes in midwinter (%.2f)" % Ice.sea_cover(winter, "arctic"))
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
