extends SceneTree
# Headless check of canopy drip after rain (--canopy-drip, docs/design/canopy_drip_design.md, Jamie #675): the crowns drip by how much
# rain fell and by tree kind, and the drip sound goes on after the rain.

const RainDrips := preload("res://src/client/rain_drips.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


# Game minutes until the store is empty after the rain, stepping one game minute.
func _drip_minutes(start_mm: float, wind: float, sun: float, cap: float) -> int:
	var mm: float = start_mm

	for minute in range(600):
		mm = RainDrips.store_mm_step(mm, 1.0 / 60.0, 0.0, wind, sun, cap)

		if mm <= 0.0:
			return minute + 1

	return 600


func _init() -> void:
	var conifer_cap: float = RainDrips.cap_mm(1.0, false)
	var broad_cap: float = RainDrips.cap_mm(0.0, false)
	_check(is_equal_approx(conifer_cap, 3.0) and is_equal_approx(broad_cap, 1.5) and is_equal_approx(RainDrips.cap_mm(0.0, true), 0.5), "capacity: conifer 3 mm, broadleaf 1.5, bare winter 0.5")

	# 1. A two-minute shower against a day of rain.
	var shower: float = 0.0

	for minute in range(2):
		shower = RainDrips.store_mm_step(shower, 1.0 / 60.0, 0.3, 0.0, 0.0, broad_cap)

	_check(shower < 0.15, "a two-minute shower (rain 0.3) leaves under 0.15 mm (%.3f)" % shower)
	_check(_drip_minutes(shower, 0.0, 0.0, broad_cap) <= 5, "and it is dry within about 4 minutes (%d)" % _drip_minutes(shower, 0.0, 0.0, broad_cap))
	var soaked: float = RainDrips.store_mm_step(0.0, 1.0, 0.65, 0.0, 0.0, conifer_cap)
	_check(is_equal_approx(soaked, 3.0), "an hour of steady rain fills a conifer to its 3 mm")

	# 2. Conifer against broadleaf.
	var conifer_min: int = _drip_minutes(3.0, 0.0, 0.0, conifer_cap)
	var broad_min: int = _drip_minutes(1.5, 0.0, 0.0, broad_cap)
	_check(conifer_min >= 50 and conifer_min <= 62, "a full conifer drips about 56 game minutes on a still grey day (%d)" % conifer_min)
	_check(broad_min >= 27 and broad_min <= 36, "a full broadleaf about 32 (%d)" % broad_min)
	var light_min: int = _drip_minutes(0.75, 0.0, 0.0, broad_cap)
	_check(light_min >= 14 and light_min <= 20, "a light shower's 0.75 mm about 17 (%d): Jamie's 15 to 60" % light_min)

	# 3. A sunny breeze dries them fast.
	_check(_drip_minutes(3.0, 0.5, 1.0, conifer_cap) <= 15, "sun and a breeze: a conifer is dry within 15 game minutes (%d)" % _drip_minutes(3.0, 0.5, 1.0, conifer_cap))

	# The closed form: one long step lands where many short ones do.
	var stepped: float = 3.0

	for n in range(20):
		stepped = RainDrips.store_mm_step(stepped, 1.0 / 60.0, 0.0, 0.0, 0.0, conifer_cap)

	_check(absf(stepped - RainDrips.store_mm_step(3.0, 20.0 / 60.0, 0.0, 0.0, 0.0, conifer_cap)) < 0.001, "20 one-minute steps match one 20-minute step")
	_check(is_equal_approx(RainDrips.drip_strength(3.0), 1.0) and is_equal_approx(RainDrips.drip_strength(0.75), 0.5), "drip strength min(mm / 1.5, 1)")

	print("canopy drip: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
