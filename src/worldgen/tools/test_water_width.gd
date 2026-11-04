extends SceneTree

# Wider or merged rivers sound fuller (water_sounds.gd width_db): none at the river threshold, +4 dB per doubling up to a cap, and still below a pond.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_width.gd

const WaterSounds := preload("res://src/client/water_sounds.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	check(WaterSounds.width_db(0) == 0.0 and WaterSounds.width_db(WaterSounds.RIVER_AROUND) == 0.0, "a river at the threshold gets no extra level")
	check(WaterSounds.width_db(12) > 0.0 and WaterSounds.width_db(12) < WaterSounds.width_db(15), "wider is louder (12: %.2f dB, 15: %.2f dB)" % [WaterSounds.width_db(12), WaterSounds.width_db(15)])
	check(absf(WaterSounds.width_db(16) - WaterSounds.WIDTH_DB_PER_OCTAVE) < 0.01, "a doubling adds 4 dB")
	check(WaterSounds.width_db(25) <= WaterSounds.WIDTH_MAX_DB, "capped at %.0f dB" % WaterSounds.WIDTH_MAX_DB)
	print("water width: %d failures" % failures)
	quit(1 if failures > 0 else 0)
