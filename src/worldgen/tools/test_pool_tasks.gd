extends SceneTree

# PoolTasks: every pool task an owner starts is waited for by finish(), and nothing starts after it (main gate, 21 Nov 2026: the dedicated
# server crashed in engine teardown after a clean stop while its own pool tasks could still be running).
#   godot --headless --path . --script res://src/worldgen/tools/test_pool_tasks.gd

const PoolTasksScript := preload("res://src/shared/pool_tasks.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const ServerScript := preload("res://scenes/terrain_server/terrain_server.gd")

var failures: int = 0
var done: int = 0
var done_mutex: Mutex = Mutex.new()


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _slow_job() -> void:
	OS.delay_msec(30)
	done_mutex.lock()
	done += 1
	done_mutex.unlock()


func _init() -> void:
	var tasks = PoolTasksScript.new()

	for n in range(12):
		check(tasks.add(_slow_job, "test job"), "add() starts a task before finish()")

	check(tasks.busy() > 0, "busy() counts the tasks not finished yet (%d)" % tasks.busy())
	tasks.finish()
	check(tasks.busy() == 0, "and none after finish()")
	check(done == 12, "finish() waits for every task (%d of 12 done)" % done)
	check(tasks.running() == 0, "and keeps none")
	check(not tasks.add(_slow_job, "late job"), "add() after finish() starts nothing")
	OS.delay_msec(60)
	check(done == 12, "so the late job never ran (%d)" % done)

	# Finished tasks are waited for as new ones start, so the list stays short.
	var short = PoolTasksScript.new()

	for n in range(5):
		short.add(func() -> void: pass)
		OS.delay_msec(20)

	check(short.running() <= 2, "finished tasks leave the list (%d kept)" % short.running())
	short.finish()

	# Lag lane 23 Nov 2026 (the join): tile prefetches on the high-priority threads; flora leaves one server worker for the ground.
	check(not PoolTasksScript.new().high_priority, "a PoolTasks starts low priority")
	check(GeneratorScript.new()._prefetch_tasks.high_priority, "the generator's tile prefetches run high priority")
	check(ServerScript.flora_may_start(0, 3) and ServerScript.flora_may_start(1, 3), "flora takes 2 of 3 workers")
	check(not ServerScript.flora_may_start(2, 3), "and leaves the third for the ground")
	check(ServerScript.flora_may_start(0, 2) and not ServerScript.flora_may_start(1, 2), "1 of 2")
	check(ServerScript.flora_may_start(0, 1) and ServerScript.flora_may_start(1, 1), "one worker in all takes flora too")

	print("test_pool_tasks: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(1 if failures > 0 else 0)
