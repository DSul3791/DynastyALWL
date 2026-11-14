extends SceneTree

# The fog's drifting body (fog_volume.gd, Dave's fog instruction 14 Nov 2026): it costs, so it must stay off on Low and Medium, start
# on High and Ultra only in fog, not flicker at its threshold, follow a preset change, and keep its drift wrapped. Run:
# godot --headless --script res://src/worldgen/tools/test_fog_volume.gd

const FogVolumeScript := preload("res://src/client/fog_volume.gd")
const FogLook := preload("res://src/client/fog_look.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1

	print("%s %s" % ["ok  " if ok else "FAIL", what])


func _initialize() -> void:
	var parent: Node = Node.new()
	root.add_child(parent)
	var env: Environment = Environment.new()
	var body = FogVolumeScript.new(parent)
	var eye: Vector3 = Vector3(10.0, 5.0, 10.0)

	for quality in [0, 1]:
		body.update(0.1, env, quality, eye, 1.0, 1.0, 90.0, 6.0, 2.0, 0.0)
		_check(not body.on and not env.volumetric_fog_enabled and parent.get_child_count() == 0, "%s in full fog: no volumetric fog, nothing built" % FogLook.preset(quality)["name"])

	body.update(0.1, env, 2, eye, 0.0, 0.0, 0.0, 6.0, 0.0, 0.0)
	_check(not body.on and not env.volumetric_fog_enabled, "High in clear air: off")
	body.update(0.1, env, 2, eye, 0.5, 0.5, 90.0, 6.0, 2.0, 0.0)
	_check(body.on and env.volumetric_fog_enabled and is_equal_approx(env.volumetric_fog_length, float(FogLook.preset(2)["vol_length_m"])), "High in fog: on, its own reach")
	_check(is_zero_approx(env.volumetric_fog_density), "no even volumetric fog everywhere: the body is the box's")
	var box: FogVolume = parent.get_child(0) as FogVolume
	_check(box != null and box.top_level and box.position.is_equal_approx(Vector3(0.0, 5.0, 0.0)), "the box sits round the eye in 32 m steps, in world space")
	body.update(0.1, env, 3, eye, 0.5, 0.5, 90.0, 6.0, 2.0, 0.0)
	_check(is_equal_approx(env.volumetric_fog_length, float(FogLook.preset(3)["vol_length_m"])), "High to Ultra in fog: Ultra's reach at once")
	body.update(0.1, env, 3, eye, 0.015, 0.015, 90.0, 6.0, 2.0, 0.0)
	_check(body.on, "just under the start level: still on (no flicker)")
	body.update(0.1, env, 3, eye, 0.005, 0.005, 90.0, 6.0, 2.0, 0.0)
	_check(not body.on and not env.volumetric_fog_enabled, "fog gone: off")
	body.update(0.1, env, 3, eye, 0.015, 0.015, 90.0, 6.0, 2.0, 0.0)
	_check(not body.on, "just under the start level from off: stays off")
	body.update(0.1, env, 3, eye, 1.0, 1.0, 90.0, 6.0, 0.0, 0.0)
	var before: Vector2 = body.drift
	body.update(1.0, env, 3, eye, 1.0, 1.0, 90.0, 6.0, 0.0, 0.0)
	_check(body.drift.distance_to(before) > 0.1, "dead calm: the patches still creep")
	for i in range(200):
		body.update(10.0, env, 3, eye, 1.0, 1.0, 90.0, 6.0, 20.0, 0.7)
	_check(body.drift.x >= 0.0 and body.drift.x < FogVolumeScript.DRIFT_WRAP_M and body.drift.y >= 0.0 and body.drift.y < FogVolumeScript.DRIFT_WRAP_M, "the drift stays wrapped")
	body.update(0.1, env, 1, eye, 1.0, 1.0, 90.0, 6.0, 2.0, 0.0)
	_check(not body.on and not env.volumetric_fog_enabled, "down to Medium in fog: off")
	# With the body on, the depth fog's end is longer so the two together keep Dave's dense-fog distances (fog_look.gd DENSE_END_VOL_M).
	var shape: Vector3 = FogLook.depth(0.0009, 1.0, FogLook.dense_end(3))
	var total: Array = []
	for metres in [10.0, 20.0, 40.0]:
		total.append(1.0 - (1.0 - FogLook.amount(metres, shape)) * exp(-FogVolumeScript.VOL_DENSITY * metres))
	_check(total[0] < 0.15 and total[1] > 0.15 and total[1] < 0.45 and total[2] > 0.6 and total[2] < 0.9, "Ultra, full fog: 10 m %.2f, 20 m %.2f, 40 m %.2f (Dave's targets)" % total)
	print("test_fog_volume: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
