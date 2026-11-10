extends SceneTree

# Fire smoke (docs/design/fire_smoke_wind_design.md): campfire smoke, and smoke and sparks that follow the wind, from Jamie's fire page #668.
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
	var small_1: Vector3 = BuildingLook.plume_velocity(1.0, 0.0, BuildingLook.smoke_tier("rise_m_s", 1), 0.0)
	var large_1: Vector3 = BuildingLook.plume_velocity(1.0, 0.0, BuildingLook.smoke_tier("rise_m_s", 3), 0.0)
	_check(absf(_height_at(small_1, 10.0) - 3.0) < 0.1 and absf(_height_at(large_1, 10.0) - 5.3) < 0.1, "1 m/s: smoke 3.0 m (small) and 5.3 m (large) up at 10 m downwind (Jamie's Briggs table)")
	var medium_2: Vector3 = BuildingLook.plume_velocity(2.0, 0.0, BuildingLook.smoke_tier("rise_m_s", 2), 0.0)
	_check(_height_at(medium_2, 10.0) < 2.2, "2 m/s: at head height 10 m downwind (%.1f m)" % _height_at(medium_2, 10.0))
	var south: Vector3 = BuildingLook.plume_velocity(5.0, PI * 0.5, 0.39, 0.0)
	_check(south.z > 4.9 and absf(south.x) < 0.01 and Vector2(south.x, south.z).length() > south.length() * 0.5, "it blows the way the wind blows, never upwind, and low in a fresh wind")
	var calm: Vector3 = BuildingLook.plume_velocity(0.0, 0.0, 0.30, 0.0)
	_check(calm.y >= float(BuildingLook.smoke_cfg()["calm_rise_m_s"]) and Vector2(calm.x, calm.z).length() < 0.001, "a calm: a column")
	var night: Vector3 = BuildingLook.plume_velocity(0.2, 0.0, 0.30, 1.0)
	var brake: float = BuildingLook.night_brake(1.0)
	var top: float = night.y * night.y / (2.0 * -brake)
	_check(absf(top - float(BuildingLook.smoke_cfg()["night_top_m"])) < 1.5, "a still clear night: it stops at about 12 m and spreads (%.1f m)" % top)
	_check(BuildingLook.night_brake(0.0) == 0.0, "no brake by day")

	# Dave 10 Nov 2026, "its hovering around like flies. it should be drifting away with the breeze": nothing steers the puffs at random, they keep
	# the wind and rise, slowing as they go, spread and fade, and last long enough to drift well clear.
	var cfg: Dictionary = BuildingLook.smoke_cfg()
	var probe: Node3D = BuildingLook.fire(true, false, 2)
	var plume: GPUParticles3D = probe.get_node_or_null("Smoke") as GPUParticles3D
	var mat: ParticleProcessMaterial = plume.process_material as ParticleProcessMaterial
	_check(not mat.turbulence_enabled and mat.damping_max == 0.0, "no turbulence or damping steals the plume's rise and wind")
	BuildingLook.set_fire_air(2.0, 0.0, 0.0)
	var v: Vector3 = mat.direction * (mat.initial_velocity_min + mat.initial_velocity_max) * 0.5
	var life: float = plume.lifetime
	var end_y: float = v.y + mat.gravity.y * life
	var end_x: float = v.x + mat.gravity.x * life
	_check(v.x > 0.0 and v.x < 1.0 and absf(v.z) < 0.05, "a fresh puff rises on its heat with a little of the 2 m/s breeze (%.2f m/s)" % v.x)
	_check(absf(end_x - 2.0) < 0.1 and absf(mat.gravity.z) < 0.01, "and the breeze takes it fully by the end: the plume bends over more the higher it gets (%.2f m/s)" % end_x)
	_check(end_y > 0.0 and end_y < v.y and absf(end_y / v.y - float(cfg["rise_end_share"])) < 0.02, "it keeps rising, slower with height (%.2f to %.2f m/s)" % [v.y, end_y])
	var drift: float = v.x * life + 0.5 * mat.gravity.x * life * life
	_check(drift >= 24.0, "it drifts well clear of the fire: %.0f m downwind over its life" % drift)
	_check(absf(life - float(cfg["life_s"])) < 0.001 and plume.preprocess == life, "life and warm start from data/look/fire_smoke.json")
	var grow: Curve = (mat.scale_curve as CurveTexture).curve
	_check(absf(grow.sample(1.0) / grow.sample(0.0) - float(cfg["grow_to"])) < 0.05, "each puff spreads %.1f times as it goes" % (grow.sample(1.0) / grow.sample(0.0)))
	var ramp: Gradient = (mat.color_ramp as GradientTexture1D).gradient
	_check(ramp.sample(1.0).a < 0.01, "and fades out")
	# Dave 10 Nov 2026, "make fire smoke actually look and act more like fire smoke": one continuous plume, dark and dense low, light and thin high,
	# narrow at the fire and wide up high, wavering as one column.
	var gap_m: float = BuildingLook.smoke_tier("rise_m_s", 1) * life / float(BuildingLook.smoke_tier("amount", 1))
	_check(gap_m < 0.5 * BuildingLook.smoke_tier("puff_m", 1), "puffs overlap into one plume even for a small fire (%.2f m apart, %.2f m wide)" % [gap_m, BuildingLook.smoke_tier("puff_m", 1)])
	_check(ramp.sample(0.1).a > ramp.sample(0.5).a and ramp.sample(0.5).a > ramp.sample(0.9).a, "dense at the fire, thinning as it rises")
	var look: ShaderMaterial = plume.draw_pass_1.surface_get_material(0) as ShaderMaterial
	_check(look != null and float(look.get_shader_parameter("near_grey")) < float(look.get_shader_parameter("far_grey")), "darker at the fire, lighter higher up")
	_check(look != null and float(look.get_shader_parameter("waver_m")) > 0.0 and look.shader.code.contains("INSTANCE_CUSTOM.y"), "the column wavers more the older the smoke")
	_check(BuildingLook.smoke_tier("amount", 3) > BuildingLook.smoke_tier("amount", 1) and BuildingLook.smoke_tier("rise_m_s", 3) > BuildingLook.smoke_tier("rise_m_s", 1), "a bigger fire smokes more and higher")
	BuildingLook.set_fire_air(0.0, 0.0, 0.0)
	var up: Vector3 = mat.direction
	_check(up.is_equal_approx(Vector3.UP) and mat.initial_velocity_min >= float(cfg["calm_rise_m_s"]) * 0.85, "calm air: straight up")
	var forge: GPUParticles3D = BuildingLook._smoke_plume()
	_check(not (forge.process_material as ParticleProcessMaterial).turbulence_enabled, "the forge's smoke drifts the same way")
	forge.free()
	probe.free()

	var gale: Vector3 = BuildingLook.spark_gravity(15.0, 0.0)
	_check(gale.x > 8.0 and BuildingLook.spark_direction(15.0, 0.0).x > 0.8, "sparks stream downwind in a gale, never straight up")
	_check(BuildingLook.spark_gravity(0.0, 0.0).is_equal_approx(Vector3(0.0, 0.25, 0.0)) and BuildingLook.spark_direction(0.0, 0.0).is_equal_approx(Vector3.UP), "in a calm they rise as before")
	var carry: float = 0.5 * BuildingLook.spark_gravity(4.0, 0.0).x * 1.8 * 1.8
	_check(carry >= 2.0 and carry <= 5.0, "4 m/s carries sparks 2 to 5 m (%.1f)" % carry)

	_check(absf(WeatherLook.fire_wind_ms(0.3) - 4.18) < 0.05 and WeatherLook.fire_wind_ms(1.0) == 20.0, "wind 0.3 is about 4.2 m/s (#637)")
	_check(WeatherLook.still_night(-0.4, 23.0, 0.1, 0.1) > 0.99 and WeatherLook.still_night(-0.4, 23.0, 0.8, 0.1) < 0.01 and WeatherLook.still_night(0.7, 13.0, 0.0, 0.0) < 0.01, "still clear night: only at night, clear and calm")

	var smoky: Node3D = BuildingLook.fire(true, false, 3)
	var smoke: GPUParticles3D = smoky.get_node_or_null("Smoke") as GPUParticles3D
	_check(smoke != null and smoke.amount == int(BuildingLook.smoke_tier("amount", 3)), "every lit campfire smokes")
	smoky.free()
	var cold: Node3D = BuildingLook.fire(false, true, 2)
	_check(cold.get_node_or_null("Smoke") == null, "an unlit fire does not")
	cold.free()
	var embers: Node3D = BuildingLook.coals_fire(0.8)
	var wisp: GPUParticles3D = embers.get_node_or_null("Smoke") as GPUParticles3D
	var wisp_ramp: Gradient = ((wisp.process_material as ParticleProcessMaterial).color_ramp as GradientTexture1D).gradient if wisp != null else null
	_check(wisp != null and wisp.amount < int(BuildingLook.smoke_tier("amount", 1)) and wisp_ramp.sample(0.05).a < ramp.sample(0.05).a, "glowing coals give a thin wisp, less than any fire")
	embers.free()

	print("test_fire_smoke: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
