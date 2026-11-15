extends SceneTree

# cpu_budget reads a container's CPU limit (cgroup quota or CPU set) so the server sizes its threads to it (David4, 15 Nov 2026: a 5 CPU
# quota on 12 logical CPUs and 11 server threads made a join 5 times slower).
#   godot --headless --path . --script res://src/worldgen/tools/test_cpu_budget.gd

const CpuBudget := preload("res://src/shared/cpu_budget.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	check(CpuBudget.quota_cpus("500000 100000\n") == 5, "cgroup v2 quota of 5 CPUs (David4)")
	check(CpuBudget.quota_cpus("150000 100000") == 2, "a quota of 1.5 CPUs rounds up to 2")
	check(CpuBudget.quota_cpus("max 100000") == 0, "no quota")
	check(CpuBudget.quota_cpus("") == 0 and CpuBudget.quota_cpus("junk") == 0, "an empty or odd file is no limit")
	check(CpuBudget.quota_cpus_v1("-1", "100000") == 0, "cgroup v1 without a quota")
	check(CpuBudget.quota_cpus_v1("300000\n", "100000\n") == 3, "cgroup v1 quota of 3 CPUs")
	check(CpuBudget.set_size("0-11\n") == 12, "a CPU set 0-11")
	check(CpuBudget.set_size("0-3,6,8-9") == 7, "a CPU set 0-3,6,8-9")
	check(CpuBudget.set_size("") == 0 and CpuBudget.set_size("3-1") == 0, "an empty or odd CPU set is no limit")
	var usable: int = CpuBudget.usable()
	check(usable >= 1 and usable <= maxi(OS.get_processor_count(), 1), "this machine: %d usable of %d" % [usable, OS.get_processor_count()])
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
