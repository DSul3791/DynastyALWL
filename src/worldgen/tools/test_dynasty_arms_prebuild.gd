extends SceneTree

# The first-person arms are cut out of their 38 MB file and skinned on a worker once the file has loaded (dynasty_arms.gd prebuild; lag run #242:
# "welcome: held item" 4.2 s on the main thread). Polls prebuild() each frame as the client does, then checks that the arms made afterwards take
# the finished meshes (fast, Dave's arms, not the old tube arms) and that settle() leaves no task behind.

const DynastyBody := preload("res://src/client/character/dynasty_body.gd")
const DynastyArms := preload("res://src/client/character/dynasty_arms.gd")

var failures: int = 0
var _start: int = 0
var _started_task: bool = false
var _early = null
var _early_ms: float = 0.0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	_start = Time.get_ticks_msec()
	DynastyBody.warm()
	DynastyArms.prebuild()
	check(DynastyArms._prebuild_task < 0, "no prebuild starts before the file has loaded")
	# The welcome before the file has loaded (Dave's PC log 4 Nov 2026: 44 ms after connecting, "welcome: held item" 843 ms): the arms made
	# then do not build on the main thread; they wait and prebuild() gives them their meshes.
	var t0: int = Time.get_ticks_usec()
	_early = DynastyArms.new()
	_early_ms = float(Time.get_ticks_usec() - t0) / 1000.0


func _process(_delta: float) -> bool:
	if not ResourceLoader.exists(DynastyArms.PARTS_GLB):
		print("dynasty arms prebuild: the parts file is not imported here (run godot --import once): skipped")
		print("dynasty arms prebuild: 0 failures")
		return true

	DynastyArms.prebuild()
	_started_task = _started_task or DynastyArms._prebuild_task >= 0
	var done: bool = _early.find_children("Dynasty_*", "MeshInstance3D", true, false).size() == 2

	if not done and Time.get_ticks_msec() - _start < 90000:
		return false

	print("arms made before the file had loaded in %.1f ms" % _early_ms)
	check(_early_ms < 300.0, "arms made while the file still loads take under 300 ms (they wait for the worker)")
	check(_started_task, "the prebuild started once the file had loaded")
	check(done, "the waiting arms got both meshes from the prebuild within 90 s")
	check(_early.has_meta("own_hands") and not _early.body_mesh.visible, "the waiting arms are Dave's arms (no tube arms)")
	check(DynastyArms._waiting.is_empty() and DynastyArms._prebuild_task < 0, "nothing is left waiting")
	var t0: int = Time.get_ticks_usec()
	var arms = DynastyArms.new()
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("arms made after the prebuild in %.1f ms" % ms)
	check(ms < 300.0, "making the arms after the prebuild takes under 300 ms (was about 2000 ms on the main thread)")
	check(arms.has_meta("own_hands"), "they are Dave's arms, not the old tube arms")
	check(arms.find_children("Dynasty_*", "MeshInstance3D", true, false).size() == 2, "both arm meshes are on the rig")
	DynastyArms.settle()
	check(DynastyArms._prebuild_task < 0, "settle leaves no task behind")
	arms.free()
	_early.free()
	print("dynasty arms prebuild: %d failures" % failures)
	return true
