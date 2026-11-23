extends SceneTree

# A clip's bone positions in other units than its skeleton (animal_view._fit_clip_units): a centimetre clip on a metre skeleton is
# scaled to it; a clip already in the skeleton's units is left alone; a clip whose positions are nearly all zero (the elephant's hit
# clips, about a millionth: Lane A tall check, 23 Nov 2026) keeps its turns and loses its positions, instead of being blown up a
# millionfold and drawn four times the elephant's height.
#   godot --headless --path . --script res://src/worldgen/tools/test_clip_units.gd

const AnimalViewScript := preload("res://src/client/animal_view.gd")
const RESTS := [Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.5, 0.2), Vector3(0.0, 0.3, 0.1), Vector3(0.1, 0.4, 0.0)]

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _clip(scale: float) -> Animation:
	var anim: Animation = Animation.new()

	for i in RESTS.size():
		var t: int = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(t, NodePath("Skeleton:b%d" % i))
		anim.position_track_insert_key(t, 0.0, (RESTS[i] as Vector3) * scale)

	var r: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(r, NodePath("Skeleton:b1"))
	anim.rotation_track_insert_key(r, 0.0, Quaternion(Vector3.RIGHT, 0.4))
	return anim


func _init() -> void:
	var v = AnimalViewScript.new()
	var base: Node3D = Node3D.new()
	var sk: Skeleton3D = Skeleton3D.new()
	sk.name = "Skeleton"
	base.add_child(sk)

	for i in RESTS.size():
		sk.add_bone("b%d" % i)
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, RESTS[i]))

	var player: AnimationPlayer = AnimationPlayer.new()
	base.add_child(player)      # root_node ".." is base, where the skeleton is

	var cm: Animation = _clip(0.01)
	v._fit_clip_units(player, cm, "test", "cm")
	check((cm.track_get_key_value(0, 0) as Vector3).is_equal_approx(RESTS[0]) and cm.get_track_count() == 5, "a centimetre clip is scaled up to the skeleton (x100)")

	var same: Animation = _clip(1.0)
	v._fit_clip_units(player, same, "test", "same")
	check((same.track_get_key_value(1, 0) as Vector3).is_equal_approx(RESTS[1]) and same.get_track_count() == 5, "a clip in the skeleton's units is left alone")

	var tiny: Animation = _clip(0.00001)      # a hundred-thousandth (the elephant's are about a millionth; a key under 1e-6 m is not counted at all)
	v._fit_clip_units(player, tiny, "test", "tiny")
	check(tiny.get_track_count() == 1 and tiny.track_get_type(0) == Animation.TYPE_ROTATION_3D, "a clip a hundred-thousandth of its skeleton keeps only its turns (%d tracks left)" % tiny.get_track_count())

	base.free()
	v.free()
	preload("res://src/debug/freeze_watch.gd").printer.drain()      # the model notes are printed on a worker
	print("test_clip_units: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
