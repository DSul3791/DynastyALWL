extends SceneTree

# The first-person arms are cut out of their 38 MB file and skinned on a worker once the file has loaded (dynasty_arms.gd prebuild; lag run #242:
# "welcome: held item" 4.2 s on the main thread). Polls prebuild() each frame as the client does, then checks that the arms made afterwards take
# the finished meshes (fast, Dave's arms, not the old tube arms) and that settle() leaves no task behind.

const DynastyBody := preload("res://src/client/character/dynasty_body.gd")
const DynastyArms := preload("res://src/client/character/dynasty_arms.gd")

var failures: int = 0
var _start: int = 0
var _started_task: bool = false


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	_start = Time.get_ticks_msec()
	DynastyBody.warm()
	DynastyArms.prebuild()
	check(DynastyArms._prebuild_task < 0, "no prebuild starts before the file has loaded")


func _process(_delta: float) -> bool:
	if not ResourceLoader.exists(DynastyArms.PARTS_GLB):
		print("dynasty arms prebuild: the parts file is not imported here (run godot --import once): skipped")
		print("dynasty arms prebuild: 0 failures")
		return true

	DynastyArms.prebuild()
	_started_task = _started_task or DynastyArms._prebuild_task >= 0
	var done: bool = DynastyArms._prebuild_task >= 0 and WorkerThreadPool.is_task_completed(DynastyArms._prebuild_task)

	if not done and Time.get_ticks_msec() - _start < 90000:
		return false

	check(_started_task, "the prebuild started once the file had loaded")
	check(done, "the prebuild finished within 90 s")
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
	print("dynasty arms prebuild: %d failures" % failures)
	return true
