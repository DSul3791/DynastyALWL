extends RefCounted

# How many CPUs this process may really use. OS.get_processor_count() counts the machine's logical CPUs, but a Linux container can be
# held to fewer: a CPU quota (docker --cpus, cgroup cpu.max) or a CPU set (docker --cpuset-cpus). David4's test container (15 Nov 2026)
# has a quota of 5 CPUs on 12 logical ones; the server started 11 streaming threads there, the kernel paused the whole group for part of
# every 100 ms, and a flora chunk took 30 to 60 times longer than alone (a join 66 s, against 12 s with 4 threads). Dave plans to host
# the server in a Docker container on that machine. On Windows and macOS, and on Linux without a limit, this is the processor count.
# shortcut: reads the process's own cgroup root (what Docker mounts for a container); a limit set only on a parent cgroup (docker --cgroupns=host,
# a systemd CPUQuota=) is not seen and the count stays as before. Revisit if the server is hosted that way.

const CGROUP2_MAX := "/sys/fs/cgroup/cpu.max"                    # "<quota us> <period us>" or "max <period>"
const CGROUP2_CPUSET := "/sys/fs/cgroup/cpuset.cpus.effective"   # "0-3,6"
const CGROUP1_QUOTA := "/sys/fs/cgroup/cpu/cpu.cfs_quota_us"     # -1 = no limit
const CGROUP1_PERIOD := "/sys/fs/cgroup/cpu/cpu.cfs_period_us"
const CGROUP1_CPUSET := "/sys/fs/cgroup/cpuset/cpuset.effective_cpus"


static func usable() -> int:
	var count: int = maxi(OS.get_processor_count(), 1)

	if OS.get_name() != "Linux":
		return count

	var quota: int = quota_cpus(read_text(CGROUP2_MAX))

	if quota == 0:
		quota = quota_cpus_v1(read_text(CGROUP1_QUOTA), read_text(CGROUP1_PERIOD))

	if quota > 0:
		count = mini(count, quota)

	var cpuset: String = read_text(CGROUP2_CPUSET)
	var in_set: int = set_size(cpuset if cpuset != "" else read_text(CGROUP1_CPUSET))

	if in_set > 0:
		count = mini(count, in_set)

	return count


# cgroup v2 cpu.max: "500000 100000" -> 5 (rounded up: 1.5 CPUs -> 2). 0 = no limit or unreadable.
static func quota_cpus(text: String) -> int:
	var parts: PackedStringArray = text.strip_edges().split(" ", false)

	if parts.size() < 2 or parts[0] == "max" or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return 0

	return _cpus(int(parts[0]), int(parts[1]))


# cgroup v1: cfs_quota_us (-1 = no limit) over cfs_period_us.
static func quota_cpus_v1(quota_text: String, period_text: String) -> int:
	var q: String = quota_text.strip_edges()
	var p: String = period_text.strip_edges()

	if not q.is_valid_int() or not p.is_valid_int():
		return 0

	return _cpus(int(q), int(p))


# A CPU list such as "0-3,6,8-9" -> 7. 0 = empty or unreadable.
static func set_size(text: String) -> int:
	var total: int = 0

	for part in text.strip_edges().split(",", false):
		var ends: PackedStringArray = part.strip_edges().split("-")

		if ends.size() == 1 and ends[0].is_valid_int():
			total += 1
		elif ends.size() == 2 and ends[0].is_valid_int() and ends[1].is_valid_int() and int(ends[1]) >= int(ends[0]):
			total += int(ends[1]) - int(ends[0]) + 1
		else:
			return 0

	return total


static func _cpus(quota_us: int, period_us: int) -> int:
	if quota_us <= 0 or period_us <= 0:
		return 0

	return maxi(int(ceil(float(quota_us) / float(period_us))), 1)


# Reads a small kernel file. Not get_as_text: it sizes the read by seeking to the end, which cgroup and /proc files do not allow (they read as "").
static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)

	if file == null:
		return ""

	var text: String = ""

	while not file.eof_reached():
		text += file.get_line() + "\n"

	return text
