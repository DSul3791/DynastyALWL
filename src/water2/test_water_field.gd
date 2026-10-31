extends SceneTree

# Dynasty water stage a: the core heightfield sim (Sonny, 31 Oct 2026). Settles, conserves, flows downhill, a spring fills a basin, fast flow runs without waves, thick liquids are slower, sleeping costs nothing.
#   godot --headless --path . --script res://src/water2/test_water_field.gd

const Field := preload("res://src/water2/water_field.gd")
const Traits := preload("res://src/water2/water_traits.gd")
const Rules := preload("res://src/water2/water_rules.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _flat(n: int, m: int, height: float = 0.0) -> PackedFloat32Array:
	var bed: PackedFloat32Array = PackedFloat32Array()
	bed.resize(n * m)
	bed.fill(height)
	return bed


func _run(f, seconds: float, step: float = 1.0) -> void:
	var t: float = 0.0

	while t < seconds:
		f.step(step)
		t += step


func _max_q(f) -> float:
	var m: float = 0.0

	for k in range(f.w * f.h):
		m = maxf(m, maxf(absf(f.qx[k]), absf(f.qy[k])))

	return m


func _centre_x(f) -> float:
	var sum: float = 0.0
	var total: float = 0.0

	for k in range(f.w * f.h):
		sum += f.depth[k] * float(k % f.w)
		total += f.depth[k]

	return sum / maxf(total, 1.0e-9)


func _init() -> void:
	# 1. dam break on a flat floor: settles flat, keeps its volume, goes to sleep
	var f = Field.new(48, 48, 2.0, _flat(48, 48))

	for j in range(18, 30):
		for i in range(18, 30):
			f.add_water(i, j, 1.0)

	var v0: float = f.volume_m3()
	_run(f, 600.0)
	var lo: float = 1.0e9
	var hi: float = -1.0e9

	for k in range(48 * 48):
		lo = minf(lo, f.depth[k])
		hi = maxf(hi, f.depth[k])

	_check(absf(f.volume_m3() - v0) / v0 < 1.0e-4, "closed box keeps its volume (%.3f of %.1f m3)" % [f.volume_m3(), v0])
	_check(hi - lo < 0.02, "dam break settles flat within 2 cm (spread %.4f m)" % (hi - lo))
	_check(_max_q(f) < 1.0e-3 and f.awake_blocks() == 0, "and goes to sleep (max q %.6f, awake blocks %d)" % [_max_q(f), f.awake_blocks()])
	f.step(1.0)
	_check(f.cells_stepped == 0, "a sleeping field costs no cells per step")

	# 2. a slope: water put at the top flows down, never up
	var ramp: PackedFloat32Array = _flat(64, 16)

	for j in range(16):
		for i in range(64):
			ramp[j * 64 + i] = 6.0 - 0.1 * i

	var g = Field.new(64, 16, 2.0, ramp)

	for j in range(4, 12):
		for i in range(2, 8):
			g.add_water(i, j, 0.5)

	var vol: float = g.volume_m3()
	var cx0: float = _centre_x(g)
	var prev: float = cx0
	var uphill: float = 0.0

	for s in range(120):
		g.step(1.0)
		var cx: float = _centre_x(g)
		uphill = maxf(uphill, prev - cx)
		prev = cx

	_check(prev > cx0 + 20.0, "water on a slope moves downhill (centre %.1f -> %.1f cells)" % [cx0, prev])
	_check(uphill < 0.05, "and the centre never moves uphill (worst %.4f cells in a second)" % uphill)
	_check(absf(g.volume_m3() - vol) / vol < 1.0e-4, "slope conserves volume")

	# 3. a spring fills a bowl: volume = rate x time, one level across the pool
	var bowl: PackedFloat32Array = _flat(33, 33)

	for j in range(33):
		for i in range(33):
			var r: float = Vector2(i - 16, j - 16).length()
			bowl[j * 33 + i] = minf(r * r * 0.02, 5.0)

	var b = Field.new(33, 33, 2.0, bowl)
	b.add_spring(16, 16, 20.0)
	_run(b, 300.0)
	_check(absf(b.volume_m3() - 6000.0) / 6000.0 < 0.001, "spring: 20 m3/s for 300 s is 6000 m3 in the bowl (%.0f)" % b.volume_m3())
	b.springs.clear()
	_run(b, 300.0)
	_check(absf(b.volume_m3() - 6000.0) / 6000.0 < 0.001, "and it keeps its volume once the spring is off")
	var centre_level: float = b.surface(16 * 33 + 16)
	var side_level: float = b.surface(16 * 33 + 20)
	_check(b.depth[16 * 33 + 16] > 1.0 and b.depth[16 * 33 + 20] > 0.5 and absf(centre_level - side_level) < 0.15, "the bowl rests at one level (%.2f at the spring, %.2f four cells away)" % [centre_level, side_level])

	# 4. fast flow without waves: a 4 percent chute, spring at the top, open end; steady, fast, surface holds still
	var chute: PackedFloat32Array = _flat(96, 9)

	for j in range(9):
		for i in range(96):
			var side: float = 0.0 if j >= 3 and j <= 5 else 3.0
			chute[j * 96 + i] = 10.0 - 0.16 * i + side

	var c = Field.new(96, 9, 4.0, chute)
	c.open_edges = true

	for j in range(3, 6):
		c.add_spring(2, j, 1.5)

	_run(c, 400.0)
	var mid: int = 4 * 96 + 48
	var lows: float = 1.0e9
	var highs: float = -1.0e9

	for s in range(120):
		c.step(0.5)
		lows = minf(lows, c.surface(mid))
		highs = maxf(highs, c.surface(mid))

	var sp: Vector2 = c.velocity(48, 4)
	var dmid: float = c.depth[mid]
	_check(sp.x > 1.0, "the chute runs fast (%.2f m/s, depth %.2f m)" % [sp.x, dmid])
	_check(highs - lows < 0.02 * maxf(dmid, 0.1) + 0.003, "and the surface holds still: no waves (swing %.4f m on %.3f m depth)" % [highs - lows, dmid])
	_check(absf(sp.y) < 0.1, "with no sideways drift (%.3f m/s)" % sp.y)

	# 5. thick liquids are slower: same slope and pulse, time for the front to reach 80 m
	var times: Dictionary = {}

	for kind in ["fresh", "swamp", "mud"]:
		var plane: PackedFloat32Array = _flat(80, 5)

		for j in range(5):
			for i in range(80):
				plane[j * 80 + i] = 8.0 - 0.1 * i

		var p = Field.new(80, 5, 2.0, plane, Traits.of(kind))

		for j in range(5):
			for i in range(3):
				p.add_water(i, j, 1.0)

		var t: float = 0.0

		while t < 900.0 and p.depth[2 * 80 + 40] < 0.05:
			p.step(1.0)
			t += 1.0

		times[kind] = t

	_check(float(times["fresh"]) < float(times["swamp"]) and float(times["swamp"]) < float(times["mud"]), "front reaches 80 m: fresh %.0f s, swamp %.0f s, mud %.0f s (thicker is slower)" % [times["fresh"], times["swamp"], times["mud"]])

	# 6. a sea held at a level wets a beach up to its height
	var beach: PackedFloat32Array = _flat(40, 4)

	for j in range(4):
		for i in range(40):
			beach[j * 40 + i] = -3.0 + 0.2 * i

	var s2 = Field.new(40, 4, 4.0, beach)

	for j in range(4):
		s2.fix_level(0, j, 0.0)

	_run(s2, 200.0)
	var shore_i: int = -1

	for i in range(40):
		if s2.depth[1 * 40 + i] > 0.01:
			shore_i = i

	_check(shore_i >= 14 and shore_i <= 15, "a held sea level wets the beach up to its height (last wet cell %d, expected 14 or 15)" % shore_i)

	# 7. rules
	var fresh = Traits.of("fresh")
	_check(Rules.state(0.0, 0.0, fresh)["mode"] == Rules.Mode.DRY, "rules: no depth is dry")
	_check(Rules.state(0.3, 0.2, fresh)["mode"] == Rules.Mode.WADE and float(Rules.state(0.3, 0.2, fresh)["speed_mult"]) < 1.0, "rules: knee deep is wading and slower")
	_check(Rules.state(0.6, 2.0, fresh)["swept"], "rules: 0.6 m at 2 m/s sweeps a walker off (depth x speed 1.2)")
	_check(not Rules.state(0.3, 2.0, fresh)["swept"], "rules: 0.3 m at 2 m/s does not (0.6)")
	_check(Rules.state(1.4, 0.0, fresh)["mode"] == Rules.Mode.SWIM and float(Rules.state(1.4, 0.0, fresh)["breath"]) > 0.0, "rules: deep water floats and breath refills")
	var under = Rules.state(3.0, 0.0, fresh, 1.8, true)
	_check(under["mode"] == Rules.Mode.UNDER and Rules.breath_after(Rules.BREATH_S, under, 30.0) == 0.0, "rules: diving drains the breath to drowning in 25 s")
	_check(float(Rules.state(0.5, 0.0, Traits.of("mud"))["speed_mult"]) < float(Rules.state(0.5, 0.0, fresh)["speed_mult"]), "rules: mud slows a wader more than water")
	_check(float(Rules.state(1.0, 0.0, Traits.of("lava"))["harm_per_s"]) > 0.0, "rules: lava harms")

	# 8. rain: falls on every cell, runs downhill into the low ground, volume = rain x time x area
	var hill: PackedFloat32Array = _flat(48, 16)

	for j in range(16):
		for i in range(48):
			hill[j * 48 + i] = 8.0 - 0.15 * float(i) if i < 40 else 2.0 - 0.15 * 40.0 + 6.0 * 0.0

	var r = Field.new(48, 16, 2.0, hill)
	r.rain_mps = 0.0005
	var area: float = 48.0 * 16.0 * 4.0
	_run(r, 400.0)
	var rained: float = 0.0005 * 400.0 * area
	_check(absf(r.volume_m3() - rained) / rained < 0.02, "rain: 0.5 mm a second for 400 s puts %.0f of %.0f m3 on the field" % [r.volume_m3(), rained])
	var low: float = 0.0

	for j in range(16):
		for i in range(40, 48):
			low += r.depth[j * 48 + i]

	var high: float = 0.0

	for j in range(16):
		for i in range(0, 8):
			high += r.depth[j * 48 + i]

	_check(low > 3.0 * high, "and runs off the slope into the low ground (%.1f vs %.1f m of depth summed)" % [low, high])
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)
