extends SceneTree

# Headless check (Sonny, 30 Oct 2026): the Chest slider (rib cage, pectorals, V-taper) changes the torso on all four body types and every frame; the Bust slider (the soft bump)
# does not change the rib cage; Muscle does not do the chest's width or taper; share codes of versions 1, 2 and 3 decode (a version 2 "chest" becomes the bust).
#   godot --headless --path . --script res://tools/check_chest.gd
# Exit code 1 on any failure.

const Generator := preload("res://src/client/character/body_generator.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	for preset in ["average", "broad", "lean", "stocky"]:
		_check_chest(preset, "")

	for frame in ["feminine", "masculine", "neutral"]:
		_check_chest("average", frame)

	_check_bust_and_muscle()
	_check_codes()
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


func _genome(preset: String, frame: String, chest: float) -> Dictionary:
	var g: Dictionary = Generator.make_genome(preset)

	if frame != "":
		for key in Generator.FRAMES[frame]:
			g[key] = Generator.FRAMES[frame][key]

	g["chest"] = chest
	return g


# The first ellipsoid of a bone (the rib cage is bone 2, the waist bone 1).
func _ell_of(g: Dictionary, bone: int) -> Dictionary:
	var rg: Dictionary = Generator.rig(g)

	for q in Generator.primitives(g, rg, false):
		if q["t"] == "ell" and int(q["bone"]) == bone and int(q["mat"]) == 0:
			return q

	return {}


func _front(g: Dictionary) -> float:
	var built: Dictionary = Generator.build(g, 0.03, false)
	var verts: PackedVector3Array = built["arrays"][Mesh.ARRAY_VERTEX]
	var cy: float = (built["rig"]["global"][2] as Vector3).y + 0.08 * float(built["rig"]["dims"]["torso"])
	var z: float = 0.0

	for v in verts:
		if absf(v.x) < 0.07 and absf(v.y - cy) < 0.04:
			z = minf(z, v.z)

	return -z


func _check_chest(preset: String, frame: String) -> void:
	var tag: String = "%s%s" % [preset, (" " + frame + " frame") if frame != "" else ""]
	var low: Dictionary = _genome(preset, frame, -1.0)
	var mid: Dictionary = _genome(preset, frame, 0.0)
	var high: Dictionary = _genome(preset, frame, 1.0)
	var rl: Dictionary = _ell_of(low, 2)
	var rm: Dictionary = _ell_of(mid, 2)
	var rh: Dictionary = _ell_of(high, 2)
	var wl: float = float((rl["r"] as Vector3).x)
	var wm: float = float((rm["r"] as Vector3).x)
	var wh: float = float((rh["r"] as Vector3).x)
	var dl: float = float((rl["r"] as Vector3).z)
	var dm: float = float((rm["r"] as Vector3).z)
	var dh: float = float((rh["r"] as Vector3).z)
	_ok(wl < wm and wm < wh and wh - wl > 0.03, "%s: the rib cage widens with Chest (%.3f / %.3f / %.3f)" % [tag, wl, wm, wh])
	_ok(dl < dm and dm < dh and dh - dl > 0.03, "%s: the rib cage deepens with Chest (%.3f / %.3f / %.3f)" % [tag, dl, dm, dh])
	# V-taper: the waist-to-chest width ratio falls as Chest rises.
	var tl: float = float((_ell_of(low, 1)["r"] as Vector3).x) / wl
	var th: float = float((_ell_of(high, 1)["r"] as Vector3).x) / wh
	_ok(th < tl - 0.1, "%s: a V-taper: waist over chest width %.2f at -1 and %.2f at +1" % [tag, tl, th])
	_ok(_front(high) > _front(low) + 0.03, "%s: the front of the mesh moves forward with Chest (%.3f to %.3f)" % [tag, _front(low), _front(high)])
	_ok(float(Generator.measures(high)["chest_half_width"]) > float(Generator.measures(low)["chest_half_width"]) + 0.03, "%s: the worn-clothing measures follow" % tag)
	_ok(float(Generator.worn_fit(high)["Chest"].x) > float(Generator.worn_fit(low)["Chest"].x), "%s: and the worn-fit chest scale" % tag)


func _check_bust_and_muscle() -> void:
	for frame in ["feminine", "masculine", "neutral"]:
		var a: Dictionary = _genome("average", frame, 0.3)
		var b: Dictionary = a.duplicate(true)
		a["bust"] = -1.0
		b["bust"] = 1.0
		var ra: Dictionary = _ell_of(a, 2)
		var rb: Dictionary = _ell_of(b, 2)
		_ok((ra["r"] as Vector3).is_equal_approx(rb["r"]) and (ra["c"] as Vector3).is_equal_approx(rb["c"]), "%s frame: Bust does not change the rib cage" % frame)
		_ok((_ell_of(a, 1)["r"] as Vector3).is_equal_approx(_ell_of(b, 1)["r"]), "%s frame: or the waist" % frame)
		_ok(Generator.primitives(b, Generator.rig(b), false).size() > Generator.primitives(a, Generator.rig(a), false).size(), "%s frame: Bust does add the soft bump" % frame)

	# Muscle is whole-body: it thickens the limbs but does not do the chest's width or the taper.
	var lo: Dictionary = _genome("average", "", 0.0)
	var hi: Dictionary = lo.duplicate(true)
	lo["muscle"] = -1.0
	hi["muscle"] = 1.0
	var taper_lo: float = float((_ell_of(lo, 1)["r"] as Vector3).x) / float((_ell_of(lo, 2)["r"] as Vector3).x)
	var taper_hi: float = float((_ell_of(hi, 1)["r"] as Vector3).x) / float((_ell_of(hi, 2)["r"] as Vector3).x)
	_ok(absf(taper_lo - taper_hi) < 0.001 and float((_ell_of(lo, 2)["r"] as Vector3).x) == float((_ell_of(hi, 2)["r"] as Vector3).x), "Muscle changes neither the rib cage width nor the taper")
	var arm_lo: float = 0.0
	var arm_hi: float = 0.0

	for q in Generator.primitives(lo, Generator.rig(lo), false):
		if q["t"] == "cone" and int(q["bone"]) == 6:
			arm_lo = float(q["ra"])

	for q in Generator.primitives(hi, Generator.rig(hi), false):
		if q["t"] == "cone" and int(q["bone"]) == 6:
			arm_hi = float(q["ra"])

	_ok(arm_hi > arm_lo + 0.005, "while Muscle thickens the arms (%.3f to %.3f)" % [arm_lo, arm_hi])


func _code(version: int, sliders: Array, colours: int = 15) -> String:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(version)

	for v in sliders:
		bytes.append(roundi((float(v) + 1.0) * 127.5))

	for i in range(colours):
		bytes.append(100)

	bytes.append(Generator._crc8(bytes))
	return Marshalls.raw_to_base64(bytes)


func _check_codes() -> void:
	var base: Array = []

	for i in range(18):
		base.append(0.0)

	var v1: Dictionary = Generator.decode(_code(1, base))
	_ok(not v1.is_empty() and float(v1["chest"]) == 0.0 and float(v1["bust"]) == Generator.BUST_NONE, "a version 1 code: rib cage as it was, no bust")
	var v2: Dictionary = Generator.decode(_code(2, base + [0.6]))
	_ok(not v2.is_empty() and float(v2["chest"]) == 0.0 and absf(float(v2["bust"]) - 0.6) < 0.01, "a version 2 code: its old chest value is the bust, the rib cage as it was")
	var v3: Dictionary = Generator.decode(_code(3, base + [0.4, -0.5]))
	_ok(not v3.is_empty() and absf(float(v3["chest"]) - 0.4) < 0.01 and absf(float(v3["bust"]) + 0.5) < 0.01, "a version 3 code carries both")
	var g: Dictionary = Generator.make_genome("average")
	g["chest"] = -0.7
	g["bust"] = 0.2
	var back: Dictionary = Generator.decode(Generator.encode(g))
	_ok(absf(float(back["chest"]) + 0.7) < 0.01 and absf(float(back["bust"]) - 0.2) < 0.01, "new codes round-trip chest and bust")
	# A version 2 character looks as it did: its body from the v2 code equals the v3 genome with chest 0 and that bust.
	var same: Dictionary = Generator.make_genome("average")
	same["bust"] = float(v2["bust"])

	for i in range(18):
		same[Generator.SLIDERS[i]] = float(v2[Generator.SLIDERS[i]])

	var pa: Array = Generator.primitives(same, Generator.rig(same), false)
	var pb: Array = Generator.primitives(v2, Generator.rig(v2), false)
	_ok(pa.size() == pb.size(), "a version 2 body has the same primitives as before the split")
	_ok(Generator.CODE_VERSION == 4, "new codes are version 4 (3 and 2 and 1 still decode)")
