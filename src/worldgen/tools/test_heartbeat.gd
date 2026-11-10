extends SceneTree

# The heartbeat (Dave 9 Nov 2026, docs/design/heartbeat_design.md): the Daggorath pulse always heard, 55 bpm at rest, faster with strain
# and eased, played at pitch 1 every 60 / bpm seconds, louder in proportion; a muted bus plays nothing but keeps the beat; and the pulse
# bar's colours and spread; passing out fades the whole HUD but the line (10 Nov).
#   godot --headless --path . --script res://src/worldgen/tools/test_heartbeat.gd

const BreathScript := preload("res://src/client/breath_sounds.gd")
const PulseScript := preload("res://src/client/heart_pulse.gd")
const HudFadeScript := preload("res://src/client/hud_fade.gd")

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

	_check_faint_hud()
	print("test_heartbeat: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)


# Passing out (Dave 10 Nov 2026): the whole HUD fades with the faint's blackout, hotbar and all; only the heartbeat line (and the black itself) stays.
func _check_faint_hud() -> void:
	var cfg: Dictionary = BreathScript.load_heart().get("faint_hud", {})
	check(float(cfg.get("gone_at_black", 0.0)) > 0.0 and float(cfg.get("fade_s", 0.0)) > 0.0, "heartbeat.json faint_hud: gone_at_black and fade_s set")
	check(HudFadeScript.black_of(2, 0.3, false) == 1.0, "fainted: all black, whatever part of the faint is gone")
	check(is_equal_approx(HudFadeScript.black_of(1, 0.4, false), 0.4) and is_equal_approx(HudFadeScript.black_of(3, 0.2, false), 0.2), "going down and waking: the black the server sends")
	check(HudFadeScript.black_of(1, 0.0, false) == 0.0 and HudFadeScript.black_of(0, 0.7, false) == 0.0, "over-exerted with no black, or normal: the HUD stays")
	check(HudFadeScript.black_of(0, 1.0, true) == 0.0 and HudFadeScript.black_of(1, 1.0, true) == 0.0, "asleep: the sleep fade keeps the HUD")
	check(HudFadeScript.target(0.0, 0.5) == 1.0 and is_equal_approx(HudFadeScript.target(0.25, 0.5), 0.5) and HudFadeScript.target(0.6, 0.5) == 0.0, "the HUD is gone when the black reaches gone_at_black")

	var layer: CanvasLayer = CanvasLayer.new()
	get_root().add_child(layer)
	var hotbar: HBoxContainer = HBoxContainer.new()
	var vitals: Label = Label.new()
	var line: Control = Control.new()
	var black_rect: ColorRect = ColorRect.new()

	for node in [hotbar, vitals, line, black_rect]:
		layer.add_child(node)

	var fade: Node = HudFadeScript.new()
	fade.setup(layer, [line, black_rect], {"gone_at_black": 0.5, "fade_s": 0.8})
	fade.step(0.1, 0.0)
	check(hotbar.modulate.a == 1.0 and fade.shown == 1.0, "awake: nothing changes")

	for _n in 4:
		fade.step(0.1, 1.0)

	check(absf(hotbar.modulate.a - 0.5) < 0.01 and absf(vitals.modulate.a - 0.5) < 0.01, "passing out: the hotbar and the rest half gone after 0.4 s of 0.8 (%.2f)" % hotbar.modulate.a)

	for _n in 10:
		fade.step(0.1, 1.0)

	var late: Label = Label.new()
	layer.add_child(late)
	fade.step(0.1, 1.0)
	check(hotbar.modulate.a == 0.0 and vitals.modulate.a == 0.0 and late.modulate.a == 0.0, "out: the whole HUD is gone, a line shown during the faint too")
	check(line.modulate.a == 1.0 and black_rect.modulate.a == 1.0, "the heartbeat line and the black stay")
	fade.step(0.1, 0.4)
	check(fade.shown < 0.15, "waking: the HUD comes back as the black lifts, smoothly (%.2f at black 0.4)" % fade.shown)

	for _n in 20:
		fade.step(0.1, 0.0)

	check(hotbar.modulate.a == 1.0 and vitals.modulate.a == 1.0 and late.modulate.a == 1.0, "awake again: all of it back")
	layer.free()
	fade.free()
