extends RefCounted

# Shared by the robot play-testers' two halves (src/client/robot_play.gd in the client, src/server/robot_audit.gd in the server; 23 Nov 2026):
# the pack signature both sides print, so tools/robot_check.py can hold them against each other, and the animal speed and time helpers.
# Here in src/shared because the client package leaves src/server out.

static func signature(inv) -> String:
	if inv == null:
		return "none"

	var parts: PackedStringArray = PackedStringArray()

	for s in range(inv.numbers.size()):
		if int(inv.numbers[s]) != 0:
			parts.append("%d:%d:%d:%d" % [s, int(inv.numbers[s]), int(inv.counts[s]), int(inv.wear[s]) if s < inv.wear.size() else 0])

	return "%08x" % (",".join(parts).hash() & 0xffffffff)


static func used(inv) -> int:
	var n: int = 0

	if inv != null:
		for s in range(inv.numbers.size()):
			n += 1 if int(inv.numbers[s]) != 0 else 0

	return n


# A species row's fastest speed: every *_mps value in it and in its blocks one level down (a flight block's fly_mps).
static func top_speed(row: Dictionary) -> float:
	var top: float = 0.0

	for k in row:
		if str(k).ends_with("_mps") and (row[k] is float or row[k] is int):
			top = maxf(top, float(row[k]))
		elif row[k] is Dictionary:
			top = maxf(top, top_speed(row[k]))

	return top


# A young animal comes as its species number + 100 (server_animals.gd YOUNG_NUM).
static func species_of(num: int) -> int:
	return num - 100 if num >= 100 else num


static func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
