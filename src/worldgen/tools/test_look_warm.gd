extends SceneTree

# Looks made ahead of the welcome (src/client/look_warm.gd): the made waterfall mist, rain and snow are the looks the welcome would make
# (the same builders), take() hands each out once, and headless runs start no runner (they make everything at the welcome, unchanged).
# Run: godot --headless --path . --script res://src/worldgen/tools/test_look_warm.gd
const LookWarm := preload("res://src/client/look_warm.gd")
const WeatherLook := preload("res://src/client/weather_look.gd")
const FallMist := preload("res://src/client/fall_mist.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


func _init() -> void:
	LookWarm.start(self)
	_check(LookWarm._runner == null, "headless: no runner is started")
	_check(LookWarm.take("rain") == null, "nothing made: take gives null (the welcome makes its own)")
	_check(LookWarm._done.has("rain"), "a take of a look not made yet marks it done, so the runner never makes it later in play")
	LookWarm._done.clear()

	var rain: GPUParticles3D = LookWarm._make("rain") as GPUParticles3D
	_check(rain != null and rain.draw_pass_1 is ArrayMesh, "the made rain is a particle look with its streak mesh")

	if rain != null and rain.draw_pass_1 is ArrayMesh:
		var material: ShaderMaterial = (rain.draw_pass_1 as ArrayMesh).surface_get_material(0) as ShaderMaterial
		_check(material != null and material.shader != null and material.shader.code == WeatherLook.RAIN_SHADER_LIT, "its streaks wear the lit rain shader")
		_check(rain.process_material is ParticleProcessMaterial and (rain.process_material as ParticleProcessMaterial).particle_flag_align_y, "its drops align to their fall")

	var snow: GPUParticles3D = LookWarm._make("snow") as GPUParticles3D
	_check(snow != null and snow.draw_pass_1 is QuadMesh and (snow.draw_pass_1 as QuadMesh).material is StandardMaterial3D, "the made snow is a particle look with its flake material")

	var mist: Node3D = LookWarm._make("fall_mist") as Node3D
	_check(mist != null and mist.get_script() == FallMist and mist.get_child_count() == FallMist.FALLS, "the made mist has one emitter per fall (%d)" % (mist.get_child_count() if mist != null else -1))

	if mist != null:
		mist.set_quality(2)
		_check((mist.get_child(0) as GPUParticles3D).amount == FallMist.CARDS[2], "set_quality gives the made mist the game's cards per fall")

	LookWarm._made["rain"] = rain
	_check(LookWarm.take("rain") == rain and LookWarm.take("rain") == null, "a made look is handed out once")

	for node in [rain, snow, mist]:
		if node != null:
			node.free()

	print("look warm: %d failures" % _fails)
	quit(1 if _fails > 0 else 0)
