extends SceneTree

# A shallow river reach does not flicker (owner 2026-10-21: near the ocean the rivers were
# blotchy, patches switching between water and bank). Channel water drawn last publish stays
# drawn until thinner than HOLD_M.
#   godot --headless --path . --script res://src/worldgen/tools/test_river_hold.gd

const WaterLive := preload("res://src/water/water_live.gd")
const WaterSim := preload("res://src/water/water_sim.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var n: int = 9
	var ground: PackedFloat32Array = PackedFloat32Array()
	ground.resize(n * n)
	ground.fill(10.0)
	var sim = WaterSim.new()
	sim.setup(n, 8.0, ground)
	var channel: PackedInt32Array = PackedInt32Array([4 * n + 3, 4 * n + 4, 4 * n + 5])
	var held: PackedByteArray = PackedByteArray()
	held.resize(3)
	var depth: PackedFloat32Array = PackedFloat32Array()
	depth.resize(n * n)

	# Publish 1: the reach is 0.2 m deep, drawn.
	for k in channel:
		depth[k] = 0.2

	sim.set_depth(depth)
	var levels: PackedFloat32Array = sim.level_map()
	WaterLive._hold_channel(sim, levels, channel, held)
	_check(not is_nan(levels[channel[1]]) and held[1] == 1, "deep enough: drawn")

	# Publish 2: it sloshes to 0.08 m (under the 12 cm draw depth): still drawn.
	for k in channel:
		depth[k] = 0.08

	sim.set_depth(depth)
	levels = sim.level_map()
	var plain: bool = is_nan(levels[channel[1]])
	WaterLive._hold_channel(sim, levels, channel, held)
	_check(plain and not is_nan(levels[channel[1]]), "slosh under 12 cm: the ribbon holds")

	# Publish 3: truly dry (0.01 m): gone, and it has to rise past 12 cm to come back.
	for k in channel:
		depth[k] = 0.01

	sim.set_depth(depth)
	levels = sim.level_map()
	WaterLive._hold_channel(sim, levels, channel, held)
	_check(is_nan(levels[channel[1]]) and held[1] == 0, "dried out: not drawn")

	for k in channel:
		depth[k] = 0.08

	sim.set_depth(depth)
	levels = sim.level_map()
	WaterLive._hold_channel(sim, levels, channel, held)
	_check(is_nan(levels[channel[1]]), "thin water does not start a ribbon")
	print("river hold: %d failures" % failures)
	quit(1 if failures > 0 else 0)
