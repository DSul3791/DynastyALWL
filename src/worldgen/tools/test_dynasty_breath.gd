extends SceneTree

# Breathing on the still sit frame (src/client/character/dynasty_breath.gd, Kathreen 5 Nov 2026). Checks the pure parts, no glb needed: the breath stays within -1 .. 1 and has no
# jump (at the inhale-exhale turn or the wrap); the weight eases to 1 in "sit" over the fade and stays 0 in the clips that already move (idle, walk); leaving sit eases it back
# to 0; the neck takes back the spine's whole turn, so the head stays level.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_dynasty_breath.gd
const Breath := preload("res://src/client/character/dynasty_breath.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


func _init() -> void:
	var lo: float = 1.0
	var hi: float = -1.0
	var jump: float = 0.0
	var last: float = Breath.breath(0.0)

	for k in range(1, 2001):
		var b: float = Breath.breath(Breath.PERIOD_S * 2.0 * float(k) / 2000.0)
		lo = minf(lo, b)
		hi = maxf(hi, b)
		jump = maxf(jump, absf(b - last))
		last = b

	_check(lo >= -1.0001 and hi <= 1.0001 and hi - lo > 1.9, "breath spans -1 .. 1 (%.3f .. %.3f)" % [lo, hi])
	_check(jump < 0.02, "breath has no jump over two cycles (largest step %.4f)" % jump)

	var w: float = 0.0

	for k in range(10):
		w = Breath.step_weight(w, "sit", Breath.FADE_S / 10.0)

	_check(absf(w - 1.0) < 0.001, "sit: weight reaches 1 after the fade (%.3f)" % w)
	_check(Breath.step_weight(0.0, "sit", 0.016) < 0.1, "sit: the first frame eases in, no pop")
	_check(Breath.step_weight(1.0, "walk", 0.016) > 0.9, "leaving sit eases out, no pop")
	_check(Breath.step_weight(0.0, "idle", 1.0) == 0.0, "idle: no extra breath (Dave's clip already breathes)")
	_check(Breath.step_weight(0.0, "walk", 1.0) == 0.0, "walk: no breath")
	_check(Breath.step_weight(0.0, "lie", 1.0) == 0.0, "lie: no breath (only the clips listed)")

	var total: float = 0.0

	for bone in Breath.BONES:
		total += float(Breath.BONES[bone])

	_check(absf(total) < 0.001, "the neck takes back the spine's turn, the head stays level (sum %.3f)" % total)
	_check(absf(float(Breath.BONES["Spine1"])) + absf(float(Breath.BONES["Spine2"])) < 1.5, "subtle: under 1.5 degrees of spine turn at the peak")
	print("dynasty breath tests: %d failures" % _fails)
	quit(1 if _fails > 0 else 0)
