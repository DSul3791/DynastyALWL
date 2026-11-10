extends SceneTree

# The heartbeat (Dave 9 Nov 2026, docs/design/heartbeat_design.md): the Daggorath pulse always heard, 55 bpm at rest, faster with strain
# and eased, played at pitch 1 every 60 / bpm seconds, louder in proportion; a muted bus plays nothing but keeps the beat; and the pulse
# bar's colours and spread.
#   godot --headless --path . --script res://src/worldgen/tools/test_heartbeat.gd

const BreathScript := preload("res://src/client/breath_sounds.gd")
const PulseScript := preload("res://src/client/heart_pulse.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func run(breath, seconds: float, underwater: bool = false) -> void:
	for _n in int(seconds * 60.0):
		breath.update(1.0 / 60.0, underwater)


func _init() -> void:
	var breath: Node = BreathScript.new()
	get_root().add_child(breath)
	breath.setup(null)
	check(float(breath.heart.get("rest_bpm", 0.0)) == 55.0, "data/sound/heartbeat.json: rest 55 bpm")
	check(breath._heart.stream != null, "the Daggorath pulse loads (%s)" % str(breath.heart.get("sound", "")))
	var heard: Array = [0]
	breath.beat.connect(func(_bpm): heard[0] += 1)

	breath.set_exertion(0.0)
	run(breath, 6.0)
	check(absf(breath.bpm_now - 55.0) < 0.5, "at rest the heart beats 55 (%.1f)" % breath.bpm_now)
	check(breath.beats_played >= 5 and breath.beats_played <= 6 and heard[0] == breath.beats_played, "and is heard: %d beats in 6 s, each one signalled" % breath.beats_played)
	var before: int = breath.beats_played
	run(breath, 3.3, true)
	check(breath.beats_played - before >= 2, "under water too (%d beats in 3.3 s)" % (breath.beats_played - before))
	check(breath.heart_plays == 0 or is_equal_approx(breath._heart.pitch_scale, 1.0), "the pulse plays at pitch 1")

	breath.set_exertion(1.0)
	breath.bpm_step_max = 0.0
	run(breath, 5.0)
	var over: float = 55.0 + (175.0 - 55.0) / 1.4
	check(absf(breath.bpm_now - over) < 0.5, "over-exerted (strain 1.0) is about 141 (%.1f)" % breath.bpm_now)
	check(breath.bpm_step_max <= 40.0 / 60.0 + 0.01, "the rate eases, never a step (%.2f bpm a frame)" % breath.bpm_step_max)
	before = breath.beats_played
	run(breath, 6.0)
	var expect: float = 6.0 * over / 60.0
	check(absf(float(breath.beats_played - before) - expect) <= 1.0, "60 / bpm apart: %d beats in 6 s (%.1f)" % [breath.beats_played - before, expect])
	breath.set_exertion(0.0)
	run(breath, 1.0)
	check(breath.bpm_now > 90.0, "recovering, it slows gradually (%.0f after 1 s)" % breath.bpm_now)

	check(is_equal_approx(breath.heart_db(55.0), -30.0) and is_equal_approx(breath.heart_db(200.0), -8.0), "volume: -30 dB at rest, -8 dB at the peak")
	check(breath.heart_db(100.0) < breath.heart_db(140.0) and breath.heart_db(140.0) < breath.heart_db(175.0), "louder in proportion to the rate")
	check(is_equal_approx(breath.heart_db(44.0), -30.0), "a sleeping heart stays at the rest level")

	var body: int = AudioServer.get_bus_index("Body")
	AudioServer.set_bus_mute(body, true)
	var plays: int = breath.heart_plays
	before = breath.beats_played
	run(breath, 3.0)
	check(breath.heart_plays == plays and breath.beats_played > before, "a muted bus: nothing played, the beat kept (%d beats)" % (breath.beats_played - before))
	AudioServer.set_bus_mute(body, false)

	var pulse = PulseScript.new()
	pulse.configure(breath.heart.get("bar", {}))
	check(pulse.colour(55.0) == Color.html("#4cff6a"), "the bar is green at rest")
	check(pulse.colour(120.0) == Color.html("#ffd93a"), "yellow in the exercise range")
	check(pulse.colour(150.0) == Color.html("#ff8c1a"), "orange in the danger zone")
	check(pulse.colour(170.0) == Color.html("#ff2a1a"), "red near the faint")
	var interval: float = 60.0 / 55.0
	check(PulseScript.spread(0.0, interval, 0.09) == 0.0 and is_equal_approx(PulseScript.spread(0.09, interval, 0.09), 1.0), "it shoots out in 0.09 s")
	check(PulseScript.spread(0.5, interval, 0.09) > 0.3 and PulseScript.spread(interval - 0.01, interval, 0.09) < 0.02, "and eases back in by the next beat")
	check(is_equal_approx(PulseScript.spread(0.075, 0.3, 0.09), 1.0), "a fast heart (200 bpm) flicks out in a quarter of the beat")
	check(absf(pulse.position.x + pulse.size.x * 0.5 - 960.0) < 0.01, "centred on the hotbar")
	pulse.free()

	print("test_heartbeat: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
