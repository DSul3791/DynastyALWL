extends RefCounted

# How much slower than the reference PC this machine is right now (Tyler, 31 Oct 2026). Timing tests multiply their millisecond limits by scale(), so a PC that is
# busy with other work (thirty Godot jobs at once) does not make a false red, and a real slowdown on an idle PC still fails. The reference is the best of
# SAMPLES runs of a fixed loop of the kind of work the game ticks do (array reads, vector maths, dictionary lookups); the best of several runs ignores a moment
# of load. Never below 1.0: a fast machine does not get a tighter limit.
const SAMPLES := 9
const REFERENCE_MS := 15.0   # ESTIMATE: the best-of-nine on Dave's PC when idle (the animals test reads 2.0 to 2.4 ms there); measured 22 ms on 31 Oct under load. Re-set on an idle PC.

static var _cached: float = -1.0


static func _once() -> float:
	var data: PackedFloat32Array = PackedFloat32Array()
	data.resize(4096)
	var lookup: Dictionary = {}

	for k in range(256):
		lookup[k] = float(k)

	var acc: float = 0.0
	var v: Vector3 = Vector3(1.0, 2.0, 3.0)
	var begun: int = Time.get_ticks_usec()

	for n in range(60000):
		var k: int = n & 4095
		data[k] = data[k] * 0.5 + float(n & 255)
		v = (v + Vector3(data[k], 1.0, 0.5)).normalized() * 3.0
		acc += lookup[n & 255] + v.length()

	return float(Time.get_ticks_usec() - begun) / 1000.0 + acc * 0.0


# The factor to multiply a limit by (1.0 = the reference PC, idle). Measured once per run.
static func scale() -> float:
	if _cached >= 0.0:
		return _cached

	var best: float = INF

	for i in range(SAMPLES):
		best = minf(best, _once())

	_cached = maxf(best / REFERENCE_MS, 1.0)   # REFERENCE_MS: re-set it from an idle run of the loop in _once()
	return _cached
