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

	check(CpuBudget.throttled_usec("usage_usec 9000\nuser_usec 6000\nsystem_usec 3000\nnr_periods 40\nnr_throttled 3\nthrottled_usec 54100\n") == 54100, "cgroup v2 cpu.stat: paused 54.1 ms")
	check(CpuBudget.throttled_usec("nr_periods 40\nnr_throttled 3\nthrottled_time 54100000\n") == 54100, "cgroup v1 cpu.stat: throttled_time in ns")
	check(CpuBudget.throttled_usec("") == -1 and CpuBudget.throttled_usec("usage_usec 5\n") == -1, "no throttle count: -1")
	var stat_path: String = CpuBudget.throttle_stat_path()
	check(stat_path == "" or CpuBudget.throttled_usec(CpuBudget.read_text(stat_path)) >= 0, "this machine's throttle count reads (%s)" % (stat_path if stat_path != "" else "no CPU quota"))

	if OS.get_name() == "Linux":
		var online: String = CpuBudget.read_text("/sys/devices/system/cpu/online")
		check(CpuBudget.set_size(online) >= 1, "a kernel file reads (online CPUs %s)" % online.strip_edges())

	# The server's CPU setting (Dave 23 Nov 2026): --cpus=N wins over DYNASTY_SERVER_CPUS; none, 0 or junk is no setting.
	check(CpuBudget.setting(PackedStringArray(["--port=24600", "--cpus=4"]), "6") == 4, "--cpus=4 wins over the environment's 6")
	check(CpuBudget.setting(PackedStringArray(["--port=24600"]), "6") == 6, "DYNASTY_SERVER_CPUS=6 without --cpus")
	check(CpuBudget.setting(PackedStringArray(), "") == 0 and CpuBudget.setting(PackedStringArray(), "lots") == 0 and CpuBudget.setting(PackedStringArray(["--cpus=x"]), "4") == 0, "unset or not a number: no setting")
	check(CpuBudget.setting(PackedStringArray(["--cpus=-3"]), "") == 0, "a negative count is no setting")
	check(CpuBudget.allowed(12, 4) == 4 and CpuBudget.allowed(3, 4) == 3 and CpuBudget.allowed(12, 0) == 12, "the setting caps the usable CPUs, never raises them")
	check(CpuBudget.idle_threads_for(0, 2) == 2 and CpuBudget.idle_threads_for(4, 2) == 2 and CpuBudget.idle_threads_for(3, 2) == 1 and CpuBudget.idle_threads_for(2, 2) == 0 and CpuBudget.idle_threads_for(1, 2) == 0, "idle builders by the setting: 2 at 4 CPUs, 1 at 3, none at 1 or 2")

	var usable: int = CpuBudget.usable()
	check(usable >= 1 and usable <= maxi(OS.get_processor_count(), 1), "this machine: %d usable of %d" % [usable, OS.get_processor_count()])
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
