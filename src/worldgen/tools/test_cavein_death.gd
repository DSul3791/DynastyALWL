extends SceneTree
# Headless check of the cave-in death sequence (src/client/cavein_death.gd): timing of the waves, the black, the skull, the lines and the
# hand-over to the respawn point.

const Sequence := preload("res://src/client/cavein_death.gd")

var failures: int = 0


class FakeClient:
	extends RefCounted
	var quake_view = null
	var sound = null
	var body = null
	var finished: int = 0
	var spawn: Vector3 = Vector3.ZERO

	func finish_cavein_death(at: Vector3) -> void:
		finished += 1
		spawn = at


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var seq = Sequence.new()
	root.add_child(seq)
	var client: FakeClient = FakeClient.new()
	seq.start(client, Vector3(1.0, 2.0, 3.0))
	_check(seq.active, "the sequence starts")
	seq._process(2.0)
	_check(seq._black.color.a < 0.01, "2 s: the picture is still clear (the roof is coming down)")
	seq._process(5.0)
	_check(seq._black.color.a > 0.1 and seq._black.color.a < 0.9, "7 s: the picture is darkening")
	seq._process(6.0)
	_check(seq._black.color.a > 0.99 and seq._skull.modulate.a < 0.5, "13 s: black, the skull is fading in")
	seq._process(4.0)
	_check(seq._skull.modulate.a > 0.95 and seq._text.text.begins_with("I tried to warn you"), "17 s: skull and the first line")
	seq._process(4.0)
	_check(seq._text.text.begins_with("Oh well"), "21 s: the second line")
	seq._process(3.0)
	_check(seq._text.text.begins_with("Better luck"), "24 s: the third line")
	seq._process(4.2)
	_check(client.finished == 1 and client.spawn == Vector3(1.0, 2.0, 3.0), "28 s: the character is handed to the respawn point once")
	seq._process(2.0)
	_check(not seq.active and not seq._layer.visible, "30 s: the sequence is over and the layer hidden")
	seq._process(1.0)
	_check(client.finished == 1, "and nothing is moved again")
	print("cave-in death: %d failures" % failures)
	quit(1 if failures > 0 else 0)
