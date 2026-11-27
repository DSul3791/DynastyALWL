extends SceneTree

# Wider or merged rivers sound fuller (water_sounds.gd width_db): none at the river threshold, +4 dB per doubling up to a cap, and still below a pond.
# The current sets the level (flowing, speed_db; Dave 26 Nov 2026): slow water is silent, only fast water is loud, and rivers use the brook recording, not the windy noise.
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
	check(not WaterSounds.flowing(0.2, 0.0) and not WaterSounds.flowing(0.39, 0.1) and not WaterSounds.flowing(-1.0, 0.2), "slow water makes no sound")
	check(WaterSounds.flowing(0.4, 0.0) and WaterSounds.flowing(0.1, 0.6) and WaterSounds.flowing(-1.0, 0.6), "a current of 0.4 m/s or a steep reach is heard")
	check(absf(WaterSounds.speed_db(0.4) + WaterSounds.SLOW_DB) < 0.01 and WaterSounds.speed_db(0.6) < WaterSounds.speed_db(0.8), "barely flowing water is %.0f dB down and rises with speed (0.6: %.1f, 0.8: %.1f)" % [WaterSounds.SLOW_DB, WaterSounds.speed_db(0.6), WaterSounds.speed_db(0.8)])
	check(absf(WaterSounds.speed_db(1.0)) < 0.01 and WaterSounds.speed_db(4.0) <= 3.0 and WaterSounds.speed_db(-1.0) == 0.0, "1 m/s is the full level, faster adds at most 3 dB, an unknown steep reach counts as 1 m/s")
	check(WaterSounds.KINDS["river"]["file"] == "water_brook", "rivers play the brook recording, not the generated rush")
	print("water width: %d failures" % failures)
	quit(1 if failures > 0 else 0)
