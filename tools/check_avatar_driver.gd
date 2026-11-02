extends SceneTree

# Headless check of src/client/character/avatar_driver.gd (Sonny, plan 4): the moved avatar rules must behave exactly like the inline code they replaced
# in scenes/terrain_client/terrain_client.gd. The old formulas are repeated below as the reference.
#   godot --headless --path . --script res://tools/check_avatar_driver.gd
# Exit code 1 on any difference or when terrain_client.gd no longer compiles.

const Driver := preload("res://src/client/character/avatar_driver.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	_check_clips()
	_check_speed_scale()
	_check_tilt()
	_check_compiles()
	print("checked %d cases, %d differences" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _same(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


# The old code, unchanged: stance 0 stand, 1 crouch, 2 sit, 3 lie.
func _old_clip(stance: int, pace: float, current: String, carrying_item: bool) -> String:
	var clip: String = ["idle", "crouch", "sit", "lie"][stance]

	if stance == 0 and pace > 0.6:
		var jog_from: float = 2.2 if current != "jog" and current != "run" else 1.8
		var run_from: float = 5.0 if current != "run" else 4.4
		clip = "run" if pace > run_from else ("jog" if pace > jog_from else "walk")

	var carrying: bool = carrying_item and stance == 0

	if carrying:
		clip = "carry_walk" if pace > 0.6 else "carry_idle"

	return clip


func _check_clips() -> void:
	var currents: Array = ["idle", "walk", "jog", "run", "crouch", "carry_walk", ""]

	for stance in range(4):
		for current in currents:
			for carrying in [false, true]:
				var pace: float = 0.0

				while pace <= 9.0:
					_same(Driver.choose_clip(stance, pace, current, carrying) == _old_clip(stance, pace, current, carrying), "clip stance %d pace %.2f current '%s' carrying %s" % [stance, pace, current, str(carrying)])
					pace += 0.05

	# The limits themselves, with and without the margin.
	_same(Driver.choose_clip(0, 2.3, "walk", false) == "jog", "walk to jog above 2.2")
	_same(Driver.choose_clip(0, 2.0, "jog", false) == "jog", "a jogger stays jogging down to 1.8")
	_same(Driver.choose_clip(0, 2.0, "walk", false) == "walk", "a walker stays walking at 2.0")
	_same(Driver.choose_clip(0, 4.5, "run", false) == "run", "a runner stays running down to 4.4")


func _old_scale(clip: String, pace: float) -> float:
	return clampf(pace / 1.1, 0.6, 1.5) if clip == "carry_walk" else clampf(pace / 1.4, 0.5, 1.7) if clip == "walk" else (clampf(pace / 3.2, 0.8, 1.6) if clip == "jog" else (clampf(pace / 6.0, 0.8, 2.0) if clip == "run" else 1.0))


func _check_speed_scale() -> void:
	for clip in ["idle", "walk", "jog", "run", "crouch", "sit", "lie", "carry_idle", "carry_walk"]:
		var pace: float = 0.0

		while pace <= 12.0:
			_same(is_equal_approx(Driver.speed_scale(clip, pace), _old_scale(clip, pace)), "speed scale %s at %.2f" % [clip, pace])
			pace += 0.1


func _old_tilt(on_floor: bool, n: Vector3, pace: float, clip: String) -> float:
	var tilt: float = 0.0

	if on_floor and pace > 0.6 and clip != "idle":
		var angle: float = atan2(n.z, maxf(n.y, 0.1))
		tilt = clampf(angle, -0.1, 0.44) if angle > 0.0 else clampf(angle * 0.4, -0.1, 0.0)

	return tilt


func _check_tilt() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7

	for _i in range(500):
		var n: Vector3 = Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.3, 1.0), rng.randf_range(-0.7, 0.7)).normalized()
		var pace: float = rng.randf_range(0.0, 7.0)
		var clip: String = ["idle", "walk", "run"][rng.randi() % 3]
		var on_floor: bool = rng.randi() % 4 != 0
		_same(is_equal_approx(Driver.slope_tilt(on_floor, n, pace, clip), _old_tilt(on_floor, n, pace, clip)), "tilt %s %s %.2f" % [str(n), clip, pace])


func _check_compiles() -> void:
	var script: GDScript = load("res://scenes/terrain_client/terrain_client.gd") as GDScript
	_same(script != null and script.can_instantiate(), "scenes/terrain_client/terrain_client.gd compiles")
	var hold: GDScript = load("res://src/client/held_item.gd") as GDScript
	_same(hold != null and hold.can_instantiate(), "src/client/held_item.gd compiles")
