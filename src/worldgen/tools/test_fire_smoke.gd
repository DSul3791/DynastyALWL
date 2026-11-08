extends SceneTree

# --fire-smoke (docs/design/fire_smoke_wind_design.md): campfire smoke, and smoke and sparks that follow the wind, from Jamie's fire page #668.
# Run: godot --headless --script res://src/worldgen/tools/test_fire_smoke.gd

const BuildingLook := preload("res://src/client/building_look.gd")
const WeatherLook := preload("res://src/client/weather_look.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1

	print("%s %s" % ["ok  " if ok else "FAIL", what])


static func _height_at(v: Vector3, x: float) -> float:
	return x * v.y / maxf(Vector2(v.x, v.z).length(), 0.001)


func _init() -> void:
	var small_1: Vector3 = BuildingLook.plume_velocity(1.0, 0.0, BuildingLook.CAMP_SMOKE_RISE[1], 0.0)
	var large_1: Vector3 = BuildingLook.plume_velocity(1.0, 0.0, BuildingLook.CAMP_SMOKE_RISE[3], 0.0)
	_check(absf(_height_at(small_1, 10.0) - 3.0) < 0.1 and absf(_height_at(large_1, 10.0) - 5.3) < 0.1, "1 m/s: smoke 3.0 m (small) and 5.3 m (large) up at 10 m downwind (Jamie's Briggs table)")
	var medium_2: Vector3 = BuildingLook.plume_velocity(2.0, 0.0, BuildingLook.CAMP_SMOKE_RISE[2], 0.0)
	_check(_height_at(medium_2, 10.0) < 2.2, "2 m/s: at head height 10 m downwind (%.1f m)" % _height_at(medium_2, 10.0))
	var south: Vector3 = BuildingLook.plume_velocity(5.0, PI * 0.5, 0.39, 0.0)
	_check(south.z > 4.9 and absf(south.x) < 0.01 and Vector2(south.x, south.z).length() > south.length() * 0.5, "it blows the way the wind blows, never upwind, and low in a fresh wind")
	var calm: Vector3 = BuildingLook.plume_velocity(0.0, 0.0, 0.30, 0.0)
	_check(calm.y >= BuildingLook.CALM_RISE and Vector2(calm.x, calm.z).length() < 0.001, "a calm: a column")
	var night: Vector3 = BuildingLook.plume_velocity(0.2, 0.0, 0.30, 1.0)
	var brake: float = BuildingLook.night_brake(1.0)
	var top: float = night.y * night.y / (2.0 * -brake)
	_check(absf(top - BuildingLook.NIGHT_TOP_M) < 1.5, "a still clear night: it stops at about 12 m and spreads (%.1f m)" % top)
	_check(BuildingLook.night_brake(0.0) == 0.0, "no brake by day")

	var gale: Vector3 = BuildingLook.spark_gravity(15.0, 0.0)
	_check(gale.x > 8.0 and BuildingLook.spark_direction(15.0, 0.0).x > 0.8, "sparks stream downwind in a gale, never straight up")
	_check(BuildingLook.spark_gravity(0.0, 0.0).is_equal_approx(Vector3(0.0, 0.25, 0.0)) and BuildingLook.spark_direction(0.0, 0.0).is_equal_approx(Vector3.UP), "in a calm they rise as before")
	var carry: float = 0.5 * BuildingLook.spark_gravity(4.0, 0.0).x * 1.8 * 1.8
	_check(carry >= 2.0 and carry <= 5.0, "4 m/s carries sparks 2 to 5 m (%.1f)" % carry)

	_check(absf(WeatherLook.fire_wind_ms(0.3) - 4.18) < 0.05 and WeatherLook.fire_wind_ms(1.0) == 20.0, "wind 0.3 is about 4.2 m/s (#637)")
	_check(WeatherLook.still_night(-0.4, 23.0, 0.1, 0.1) > 0.99 and WeatherLook.still_night(-0.4, 23.0, 0.8, 0.1) < 0.01 and WeatherLook.still_night(0.7, 13.0, 0.0, 0.0) < 0.01, "still clear night: only at night, clear and calm")

	BuildingLook.fire_smoke_on = false
	var plain: Node3D = BuildingLook.fire(true, false, 2)
	_check(plain.get_node_or_null("Smoke") == null, "without the switch no smoke, as before")
	plain.free()
	BuildingLook.fire_smoke_on = true
	var smoky: Node3D = BuildingLook.fire(true, false, 3)
	var smoke: GPUParticles3D = smoky.get_node_or_null("Smoke") as GPUParticles3D
	_check(smoke != null and smoke.amount == int(BuildingLook.CAMP_SMOKE_AMOUNT[3]), "with it every lit campfire smokes")
	smoky.free()
	var cold: Node3D = BuildingLook.fire(false, true, 2)
	_check(cold.get_node_or_null("Smoke") == null, "an unlit fire does not")
	cold.free()

	print("test_fire_smoke: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
