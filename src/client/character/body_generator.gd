extends RefCounted

# PROTOTYPE (Sonny, 2026-10-30): generates a stylised humanoid body from a small "genome" of sliders. See CHARACTER_DESIGN_VISION.md
# (Part 5.7, section 5.7.9 and Part 3.11.3). Nothing in the game uses this yet; tools/proto_body.gd builds pictures and a benchmark from it.
#
# Steps: genome -> skeleton (37 bones, Godot humanoid names, rest pose with the arms hanging down) -> primitives (round cones and
# ellipsoids, each on one bone) -> signed distance field with a smooth union, evaluated only near each primitive -> naive surface nets
# -> skin weights from the distance to each primitive (exponential falloff, then smoothing passes) -> one ArrayMesh with 4 bone
# influences per vertex and a vertex colour per primitive material (skin / hair).
#
# Conventions: metres, feet at y = 0, the body faces -Z, the character's right is +X (as in ragdoll_body.gd), "Left" bones are at -X.

const BONES := [
	["Hips", -1], ["Spine", 0], ["Chest", 1], ["Neck", 2], ["Head", 3],
	["LeftShoulder", 2], ["LeftUpperArm", 5], ["LeftLowerArm", 6], ["LeftHand", 7],
	["RightShoulder", 2], ["RightUpperArm", 9], ["RightLowerArm", 10], ["RightHand", 11],
	["LeftUpperLeg", 0], ["LeftLowerLeg", 13], ["LeftFoot", 14], ["LeftToes", 15],
	["RightUpperLeg", 0], ["RightLowerLeg", 17], ["RightFoot", 18], ["RightToes", 19],
	# Simplified hands (version 2): a thumb and three finger groups (index, middle and ring together, little), two bones each.
	["LeftThumbProximal", 8], ["LeftThumbDistal", 21], ["LeftIndexProximal", 8], ["LeftIndexDistal", 23],
	["LeftMiddleProximal", 8], ["LeftMiddleDistal", 25], ["LeftLittleProximal", 8], ["LeftLittleDistal", 27],
	["RightThumbProximal", 12], ["RightThumbDistal", 29], ["RightIndexProximal", 12], ["RightIndexDistal", 31],
	["RightMiddleProximal", 12], ["RightMiddleDistal", 33], ["RightLittleProximal", 12], ["RightLittleDistal", 35],
]

const MAT_SKIN := 0
const MAT_HAIR := 1
const MAT_LIPS := 2
const MAT_TUNIC := 3
const MAT_TROUSERS := 4
const MAT_BOOTS := 5
const HEM_REACH := 0.02      # how far (m) from a cloth edge the hem and cuff darkening fades out
const SMOOTH_K := 0.035                # smooth union band, metres
const WEIGHT_FALLOFF := 0.03           # skin weight falloff with distance to a primitive, metres
const WEIGHT_PASSES := 2
const GROUPS := 7                      # trunk and head, left arm, right arm, left leg, right leg, left hand, right hand
const HAND_VOXEL := 0.009              # the hands are meshed on their own finer grid (fingers are about 2 cm wide)
const HAND_K := 0.008
const HAND_FALLOFF := 0.007
const LOD_VOXELS := [0.03, 0.045, 0.07]  # detail levels 0 to 2: near, middle, far

# Slider names, each -1 .. +1 (0 is the neutral body). Archetype presets are just different numbers.
const SLIDERS := ["height", "build", "muscle", "belly", "shoulders", "hips", "torso", "legs", "arms", "neck", "head", "hands", "feet",
	"jaw", "nose", "brow", "ears", "hair_length"]

const PRESETS := {
	"average": {},
	"broad": {"height": 0.3, "build": 0.7, "muscle": 0.9, "belly": 0.2, "shoulders": 0.9, "hips": -0.2, "torso": 0.2, "legs": -0.2, "arms": 0.3, "neck": 0.8, "head": -0.1, "hands": 0.7, "feet": 0.4, "jaw": 0.8, "nose": 0.2, "brow": 0.6, "hair_length": -0.4},
	"lean": {"height": 0.6, "build": -0.6, "muscle": -0.3, "belly": -0.8, "shoulders": -0.3, "hips": -0.3, "torso": -0.1, "legs": 0.6, "arms": 0.4, "neck": 0.2, "head": -0.2, "hands": 0.1, "feet": 0.1, "jaw": -0.4, "nose": 0.3, "ears": 0.9, "hair_length": 0.6},
	"stocky": {"height": -0.7, "build": 0.6, "muscle": 0.3, "belly": 0.8, "shoulders": 0.4, "hips": 0.6, "torso": 0.3, "legs": -0.7, "arms": -0.4, "neck": -0.3, "head": 0.4, "hands": 0.5, "feet": 0.6, "jaw": 0.3, "nose": 0.7, "brow": 0.3, "hair_length": 0.2},
}


# Maps a slider value s (-1 .. 1) to lo .. hi, with 0 mapping to 1.0 when lo < 1 < hi.
static func m(s: float, lo: float, hi: float) -> float:
	return lerpf(1.0, hi, s) if s >= 0.0 else lerpf(1.0, lo, -s)


static func make_genome(preset: String = "average", skin: Color = Color(0.82, 0.62, 0.48), hair: Color = Color(0.25, 0.16, 0.09), tunic: Color = Color(0.36, 0.45, 0.3), trousers: Color = Color(0.3, 0.24, 0.18), boots: Color = Color(0.2, 0.13, 0.09)) -> Dictionary:
	var g: Dictionary = {}

	for key in SLIDERS:
		g[key] = 0.0

	for key in PRESETS.get(preset, {}):
		g[key] = float(PRESETS[preset][key])

	g["skin"] = skin
	g["hair"] = hair
	g["lips"] = skin.lerp(Color(0.7, 0.25, 0.25), 0.5)
	g["tunic"] = tunic
	g["trousers"] = trousers
	g["boots"] = boots
	return g


# ---------------------------------------------------------------- skeleton

# Returns {names, parents, global (Vector3 per bone, rest positions), local (Vector3 per bone), dims}.
static func rig(g: Dictionary) -> Dictionary:
	var h: float = m(float(g["height"]), 0.9, 1.12)
	var legs: float = h * m(float(g["legs"]), 0.9, 1.12)
	var torso: float = h * m(float(g["torso"]), 0.9, 1.12)
	var arm: float = h * m(float(g["arms"]), 0.88, 1.15)
	var wide: float = m(float(g["shoulders"]), 0.85, 1.3)
	var hip_w: float = m(float(g["hips"]), 0.85, 1.25)
	var foot_k: float = m(float(g["feet"]), 0.85, 1.3)
	var ankle_y: float = 0.06 * h
	var shin: float = 0.40 * legs
	var thigh: float = 0.44 * legs
	var hips_y: float = ankle_y + shin + thigh + 0.05 * h
	var spine_y: float = hips_y + 0.12 * torso
	var chest_y: float = spine_y + 0.20 * torso
	var shoulder_y: float = chest_y + 0.18 * torso
	var neck_y: float = chest_y + 0.22 * torso
	var head_y: float = neck_y + 0.07 * h + 0.04 * float(g["neck"])
	var arm_x: float = 0.07 + 0.16 * wide * m(float(g["build"]), 0.9, 1.15)
	var hip_x: float = 0.108 * hip_w
	var pos: Array = []
	pos.resize(BONES.size())
	pos[0] = Vector3(0.0, hips_y, 0.0)
	pos[1] = Vector3(0.0, spine_y, 0.0)
	pos[2] = Vector3(0.0, chest_y, 0.0)
	pos[3] = Vector3(0.0, neck_y, 0.0)
	pos[4] = Vector3(0.0, head_y, 0.0)

	for side in [-1.0, 1.0]:
		var o: int = 5 if side < 0.0 else 9
		pos[o] = Vector3(0.06 * side, shoulder_y, 0.0)
		pos[o + 1] = Vector3(arm_x * side, shoulder_y, 0.0)
		pos[o + 2] = pos[o + 1] + Vector3(0.0, -0.29 * arm, 0.0)
		pos[o + 3] = pos[o + 2] + Vector3(0.0, -0.26 * arm, 0.0)
		var l: int = 13 if side < 0.0 else 17
		pos[l] = Vector3(hip_x * side, hips_y - 0.05 * h, 0.0)
		pos[l + 1] = pos[l] + Vector3(0.0, -thigh, 0.0)
		pos[l + 2] = pos[l + 1] + Vector3(0.0, -shin, 0.0)
		pos[l + 3] = pos[l + 2] + Vector3(0.0, -(ankle_y - 0.025 * h), -0.15 * foot_k)
		# Fingers hang from the wrist; "inner" is the side toward the body (the thumb side).
		var hk: float = m(float(g["hands"]), 0.8, 1.5)
		var inner: float = -side
		var hand: Vector3 = pos[o + 3]
		var f0: int = 21 if side < 0.0 else 29
		pos[f0] = hand + Vector3(inner * 0.03 * hk, -0.035 * hk, -0.018 * hk)
		pos[f0 + 1] = pos[f0] + Vector3(inner * 0.004 * hk, -0.03 * hk, -0.014 * hk)
		pos[f0 + 2] = hand + Vector3(inner * 0.027 * hk, -0.085 * hk, -0.004 * hk)
		pos[f0 + 3] = pos[f0 + 2] + Vector3(0.0, -0.036 * hk, 0.0)
		pos[f0 + 4] = hand + Vector3(inner * 0.002 * hk, -0.088 * hk, -0.004 * hk)
		pos[f0 + 5] = pos[f0 + 4] + Vector3(0.0, -0.04 * hk, 0.0)
		pos[f0 + 6] = hand + Vector3(-inner * 0.027 * hk, -0.083 * hk, -0.004 * hk)
		pos[f0 + 7] = pos[f0 + 6] + Vector3(0.0, -0.03 * hk, 0.0)

	var names: Array = []
	var parents: Array = []
	var locals: Array = []

	for i in range(BONES.size()):
		names.append(BONES[i][0])
		parents.append(BONES[i][1])
		locals.append(pos[i] if int(BONES[i][1]) < 0 else pos[i] - pos[int(BONES[i][1])])

	return {"names": names, "parents": parents, "global": pos, "local": locals,
		"dims": {"h": h, "legs": legs, "torso": torso, "arm": arm, "hips_y": hips_y, "head_y": head_y, "ankle_y": ankle_y}}


# ---------------------------------------------------------------- primitives

# A primitive: {t: "cone" | "ell", bone, mat, a, b, ra, rb (cone) | c, r (ellipsoid), cut_n, cut_c (optional plane: keep dot(n, p) >= c)}.
static func _cone(bone: int, a: Vector3, b: Vector3, ra: float, rb: float, mat: int = MAT_SKIN) -> Dictionary:
	return {"t": "cone", "bone": bone, "mat": mat, "grp": _group_of(bone), "a": a, "b": b, "ra": ra, "rb": rb}


static func _ell(bone: int, c: Vector3, r: Vector3, mat: int = MAT_SKIN) -> Dictionary:
	return {"t": "ell", "bone": bone, "mat": mat, "grp": _group_of(bone), "c": c, "r": r}


# Smooth blending happens only inside a group (trunk and head, each arm, each leg); different groups meet with a hard union, so an
# arm never webs onto the torso or a leg onto the other leg (the first picture showed that tearing when posed).
static func _group_of(bone: int) -> int:
	if bone <= 4:
		return 0

	if bone <= 7:
		return 1

	if bone == 8 or (bone >= 21 and bone <= 28):
		return 5

	if bone <= 11:
		return 2

	if bone == 12 or bone >= 29:
		return 6

	return 3 if bone <= 16 else 4


static func primitives(g: Dictionary, rg: Dictionary, fingers: bool = true) -> Array:
	var p: Array = rg["global"]
	var d: Dictionary = rg["dims"]
	var h: float = d["h"]
	var torso: float = d["torso"]
	var b: float = m(float(g["build"]), 0.8, 1.3)
	var mu: float = m(float(g["muscle"]), 0.9, 1.22)
	var wide: float = m(float(g["shoulders"]), 0.85, 1.3)
	var hip_w: float = m(float(g["hips"]), 0.85, 1.25)
	var belly: float = m(float(g["belly"]), 0.85, 1.55)
	var hs: float = m(float(g["head"]), 0.85, 1.4)
	var hand_k: float = m(float(g["hands"]), 0.8, 1.5)
	var foot_k: float = m(float(g["feet"]), 0.85, 1.3)
	var neck_r: float = 0.05 * m(float(g["neck"]), 0.8, 1.4) * sqrt(b)
	var jaw: float = m(float(g["jaw"]), 0.85, 1.25)
	var nose: float = m(float(g["nose"]), 0.7, 1.9)
	var ear: float = m(float(g["ears"]), 0.8, 2.4)
	var hair_len: float = m(float(g["hair_length"]), 0.2, 2.0)
	var out: Array = []
	var hips_c: Vector3 = p[0]
	var head_c: Vector3 = p[4]
	# Trunk
	out.append(_ell(0, hips_c + Vector3(0.0, 0.0, 0.0), Vector3(0.165 * b * hip_w, 0.14, 0.12 * b)))
	out.append(_ell(1, p[1] + Vector3(0.0, 0.02 * torso, -0.01), Vector3(0.155 * b, 0.15 * torso, 0.12 * b * belly)))
	out.append(_ell(2, p[2] + Vector3(0.0, 0.08 * torso, -0.005), Vector3(0.155 * b * wide, 0.2 * torso, 0.12 * b * mu)))
	out.append(_cone(3, p[3] + Vector3(0.0, -0.02, 0.0), head_c + Vector3(0.0, 0.03, 0.0), neck_r, neck_r * 0.92))
	# Head, face and hair
	out.append(_ell(4, head_c + Vector3(0.0, 0.14 * hs, 0.0), Vector3(0.095 * hs, 0.118 * hs, 0.108 * hs)))
	out.append(_ell(4, head_c + Vector3(0.0, 0.065 * hs, -0.022 * hs), Vector3(0.074 * hs * jaw, 0.07 * hs, 0.082 * hs)))
	out.append(_ell(4, head_c + Vector3(0.0, 0.115 * hs, -0.108 * hs), Vector3(0.017 * nose, 0.03 * nose, 0.026 * nose)))
	out.append(_ell(4, head_c + Vector3(0.0, 0.052 * hs, -0.097 * hs), Vector3(0.026 * hs, 0.007 * hs, 0.013 * hs), MAT_LIPS))

	for side in [-1.0, 1.0]:
		out.append(_ell(4, head_c + Vector3(0.099 * hs * side, 0.135 * hs, 0.005 * hs), Vector3(0.012, 0.03 * ear, 0.019)))

	var cap: Dictionary = _ell(4, head_c + Vector3(0.0, 0.158 * hs, 0.012 * hs), Vector3(0.101 * hs, 0.122 * hs, 0.116 * hs), MAT_HAIR)
	cap["cut_n"] = Vector3(0.0, 1.0, -0.12)
	cap["cut_c"] = head_c.y + 0.19 * hs
	out.append(cap)
	var back: Dictionary = _ell(4, head_c + Vector3(0.0, 0.09 * hs - 0.05 * (hair_len - 1.0), 0.052 * hs), Vector3(0.095 * hs, 0.1 * hs * hair_len, 0.07 * hs), MAT_HAIR)
	back["cut_n"] = Vector3(0.0, 0.0, 1.0)
	back["cut_c"] = 0.012 * hs
	out.append(back)

	# Arms and hands
	for side in [-1.0, 1.0]:
		var o: int = 5 if side < 0.0 else 9
		out.append(_cone(o, p[2] + Vector3(0.0, 0.17 * torso, 0.0), p[o + 1], 0.05 * mu, 0.05 * mu))
		out.append(_cone(o + 1, p[o + 1], p[o + 2], 0.052 * mu * sqrt(b), 0.042 * mu))
		out.append(_cone(o + 2, p[o + 2], p[o + 3], 0.042 * mu, 0.032))
		var f: int = 21 if side < 0.0 else 29
		out.append(_ell(o + 3, p[o + 3] + Vector3(0.0, -0.047 * hand_k, 0.0), Vector3(0.038 * hand_k, 0.046 * hand_k, 0.017 * hand_k)))
		if fingers:
			out.append(_cone(f, p[f], p[f + 1], 0.0125 * hand_k, 0.0105 * hand_k))
			out.append(_cone(f + 1, p[f + 1], p[f + 1] + Vector3(0.0, -0.025 * hand_k, -0.012 * hand_k), 0.0105 * hand_k, 0.008 * hand_k))
			out.append(_cone(f + 2, p[f + 2], p[f + 3], 0.0115 * hand_k, 0.0095 * hand_k))
			out.append(_cone(f + 3, p[f + 3], p[f + 3] + Vector3(0.0, -0.03 * hand_k, 0.0), 0.0095 * hand_k, 0.0075 * hand_k))
			out.append(_cone(f + 4, p[f + 4], p[f + 5], 0.0165 * hand_k, 0.0135 * hand_k))
			out.append(_cone(f + 5, p[f + 5], p[f + 5] + Vector3(0.0, -0.034 * hand_k, 0.0), 0.0135 * hand_k, 0.0105 * hand_k))
			out.append(_cone(f + 6, p[f + 6], p[f + 7], 0.0105 * hand_k, 0.009 * hand_k))
			out.append(_cone(f + 7, p[f + 7], p[f + 7] + Vector3(0.0, -0.026 * hand_k, 0.0), 0.009 * hand_k, 0.007 * hand_k))

	# Legs and feet
	for side in [-1.0, 1.0]:
		var l: int = 13 if side < 0.0 else 17
		out.append(_cone(l, p[l], p[l + 1], 0.085 * sqrt(b) * mu * hip_w, 0.062 * mu))
		out.append(_cone(l + 1, p[l + 1], p[l + 2], 0.058 * mu, 0.041))
		var foot_c: Vector3 = p[l + 2] + Vector3(0.0, -0.025 * h, -0.065 * foot_k)
		out.append(_ell(l + 2, foot_c, Vector3(0.05 * foot_k, 0.04, 0.115 * foot_k)))
		out.append(_ell(l + 3, p[l + 3] + Vector3(0.0, 0.0, -0.01), Vector3(0.045 * foot_k, 0.03, 0.04 * foot_k)))

	_dress(out)
	return out


# Clothes: a slightly larger copy of the covered body parts with a cloth material, in the same group, so the surface shows the cloth
# where it covers and the skin elsewhere (hands, forearms, head). Tunic on the trunk and upper arms, trousers on hips and legs, boots below the calf.
static func _dress(out: Array) -> void:
	var extra: Array = []

	for q in out:
		if int(q["mat"]) != MAT_SKIN:
			continue

		var bone: int = int(q["bone"])
		var c: Dictionary = q.duplicate()

		if q["t"] == "ell":
			var r: Vector3 = q["r"]

			if bone == 0:
				c["mat"] = MAT_TROUSERS
				c["r"] = r * 1.07 + Vector3(0.006, 0.006, 0.006)
			elif bone == 1 or bone == 2:
				c["mat"] = MAT_TUNIC
				c["r"] = r * 1.06 + Vector3(0.007, 0.007, 0.007)
			elif bone == 15 or bone == 19:
				c["mat"] = MAT_BOOTS
				c["r"] = r * 1.12 + Vector3(0.006, 0.006, 0.006)
			else:
				continue
		else:
			var a: Vector3 = q["a"]
			var b2: Vector3 = q["b"]

			if bone == 5 or bone == 9:
				c["mat"] = MAT_TUNIC
				c["ra"] = float(q["ra"]) + 0.012
				c["rb"] = float(q["rb"]) + 0.012
			elif bone == 6 or bone == 10:
				c["mat"] = MAT_TUNIC
				c["b"] = a.lerp(b2, 0.72)
				c["rb"] = lerpf(float(q["ra"]), float(q["rb"]), 0.72)
				c["ra"] = float(q["ra"]) + 0.012
				c["rb"] = float(c["rb"]) + 0.012
			elif bone == 13 or bone == 17:
				c["mat"] = MAT_TROUSERS
				c["ra"] = float(q["ra"]) + 0.013
				c["rb"] = float(q["rb"]) + 0.013
			elif bone == 14 or bone == 18:
				c["mat"] = MAT_TROUSERS
				c["b"] = a.lerp(b2, 0.5)
				c["rb"] = lerpf(float(q["ra"]), float(q["rb"]), 0.5)
				c["ra"] = float(q["ra"]) + 0.013
				c["rb"] = float(c["rb"]) + 0.013
				var boot: Dictionary = q.duplicate()
				boot["mat"] = MAT_BOOTS
				boot["a"] = a.lerp(b2, 0.5)
				boot["ra"] = lerpf(float(q["ra"]), float(q["rb"]), 0.5) + 0.016
				boot["rb"] = float(q["rb"]) + 0.016
				extra.append(boot)
			else:
				continue

		extra.append(c)

	out.append_array(extra)


static func prim_sdf(q: Dictionary, x: Vector3) -> float:
	var dist: float

	if q["t"] == "cone":
		var a: Vector3 = q["a"]
		var ab: Vector3 = (q["b"] as Vector3) - a
		var t: float = clampf((x - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
		dist = (x - (a + ab * t)).length() - lerpf(float(q["ra"]), float(q["rb"]), t)
	else:
		var r: Vector3 = q["r"]
		var v: Vector3 = x - (q["c"] as Vector3)
		var k0: float = Vector3(v.x / r.x, v.y / r.y, v.z / r.z).length()
		var k1: float = Vector3(v.x / (r.x * r.x), v.y / (r.y * r.y), v.z / (r.z * r.z)).length()
		dist = k0 * (k0 - 1.0) / maxf(k1, 0.000001)

	if q.has("cut_n"):
		dist = maxf(dist, float(q["cut_c"]) - (q["cut_n"] as Vector3).dot(x))

	return dist


static func _bounds(q: Dictionary) -> AABB:
	if q["t"] == "cone":
		var r: float = maxf(float(q["ra"]), float(q["rb"]))
		var box: AABB = AABB(q["a"], Vector3.ZERO).expand(q["b"])
		return box.grow(r)

	var c: Vector3 = q["c"]
	var rr: Vector3 = q["r"]
	return AABB(c - rr, rr * 2.0)


static func _smin(a: float, b: float, k: float) -> float:
	var h: float = maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * k * 0.25


# ---------------------------------------------------------------- mesh

# Returns {arrays (for ArrayMesh), vertex_count, triangle_count, timings (ms), rig}.
# Each group (trunk and head, each arm, each leg) is meshed on its own, so a hanging arm never fuses with the torso into a stretchy
# membrane (the first two pictures showed that); the pieces overlap where limbs join and render as one body.
static func build(g: Dictionary, voxel: float = 0.03, fingers: bool = true) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var rg: Dictionary = rig(g)
	var prims: Array = primitives(g, rg, fingers)
	var verts: PackedVector3Array = PackedVector3Array()
	var tris: PackedInt32Array = PackedInt32Array()
	var vgroup: PackedInt32Array = PackedInt32Array()
	var t_field: int = 0
	var t_surface: int = 0
	var grid_cells: int = 0

	for gi in range(GROUPS):
		var gp: Array = []
		var vox: float = minf(voxel, HAND_VOXEL * voxel / 0.03) if gi >= 5 else voxel
		var kk: float = HAND_K if gi >= 5 else SMOOTH_K

		for q in prims:
			if int(q["grp"]) == gi:
				gp.append(q)

		var ta: int = Time.get_ticks_usec()
		var bounds: AABB = AABB()
		var first: bool = true

		for q in gp:
			var qb: AABB = _bounds(q)
			bounds = qb if first else bounds.merge(qb)
			first = false

		bounds = bounds.grow(kk + vox * 2.0)
		var origin: Vector3 = bounds.position
		var nx: int = ceili(bounds.size.x / vox)
		var ny: int = ceili(bounds.size.y / vox)
		var nz: int = ceili(bounds.size.z / vox)
		var sx: int = nx + 1
		var sxy: int = sx * (ny + 1)
		var field: PackedFloat32Array = PackedFloat32Array()
		field.resize(sxy * (nz + 1))
		field.fill(1.0)
		grid_cells += nx * ny * nz

		for q in gp:
			var qb2: AABB = _bounds(q).grow(kk + vox)
			var lo: Vector3 = (qb2.position - origin) / vox
			var hi: Vector3 = (qb2.end - origin) / vox

			for iz in range(maxi(0, floori(lo.z)), mini(nz, ceili(hi.z)) + 1):
				for iy in range(maxi(0, floori(lo.y)), mini(ny, ceili(hi.y)) + 1):
					for ix in range(maxi(0, floori(lo.x)), mini(nx, ceili(hi.x)) + 1):
						var idx: int = ix + iy * sx + iz * sxy
						field[idx] = _smin(field[idx], prim_sdf(q, origin + Vector3(ix, iy, iz) * vox), kk)

		var tb: int = Time.get_ticks_usec()
		var gv: PackedVector3Array = PackedVector3Array()
		var gt: PackedInt32Array = PackedInt32Array()
		_surface_nets(field, nx, ny, nz, origin, vox, gv, gt)
		var tc: int = Time.get_ticks_usec()
		t_field += tb - ta
		t_surface += tc - tb
		var offset: int = verts.size()
		verts.append_array(gv)

		for index in gt:
			tris.append(index + offset)

		for _v in range(gv.size()):
			vgroup.append(gi)

	var t3: int = Time.get_ticks_usec()
	var normals: PackedVector3Array = _normals(verts, tris)
	var skinning: Dictionary = _weights(verts, tris, prims, vgroup, g)
	var t4: int = Time.get_ticks_usec()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = skinning["colors"]
	arrays[Mesh.ARRAY_INDEX] = tris
	arrays[Mesh.ARRAY_BONES] = skinning["bones"]
	arrays[Mesh.ARRAY_WEIGHTS] = skinning["weights"]
	@warning_ignore("integer_division")   # whole triangles
	var triangle_count: int = tris.size() / 3
	return {"arrays": arrays, "rig": rg, "vertex_count": verts.size(), "triangle_count": triangle_count,
		"grid": Vector3i(grid_cells, 0, 0),
		"ms": {"rig_prims": float(t3 - t0 - t_field - t_surface) / 1000.0, "field": float(t_field) / 1000.0, "surface": float(t_surface) / 1000.0,
			"weights": float(t4 - t3) / 1000.0, "total": float(t4 - t0) / 1000.0}}


static func _surface_nets(field: PackedFloat32Array, nx: int, ny: int, nz: int, origin: Vector3, vs: float, verts: PackedVector3Array, tris: PackedInt32Array) -> void:
	var sx: int = nx + 1
	var sxy: int = sx * (ny + 1)
	var cell_vertex: PackedInt32Array = PackedInt32Array()
	cell_vertex.resize(nx * ny * nz)
	cell_vertex.fill(-1)
	var corner: Array = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
	var edges: Array = [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	var values: PackedFloat32Array = PackedFloat32Array()
	values.resize(8)

	for z in range(nz):
		for y in range(ny):
			for x in range(nx):
				var mask: int = 0

				for c in range(8):
					var o: Vector3i = corner[c]
					var v: float = field[(x + o.x) + (y + o.y) * sx + (z + o.z) * sxy]
					values[c] = v

					if v < 0.0:
						mask |= 1 << c

				if mask == 0 or mask == 255:
					continue

				var sum: Vector3 = Vector3.ZERO
				var count: int = 0

				for e in edges:
					var ca: int = e[0]
					var cb: int = e[1]
					var va: float = values[ca]
					var vb: float = values[cb]

					if (va < 0.0) != (vb < 0.0):
						var tt: float = va / (va - vb)
						var oa: Vector3i = corner[ca]
						var ob: Vector3i = corner[cb]
						sum += Vector3(oa).lerp(Vector3(ob), tt)
						count += 1

				cell_vertex[x + y * nx + z * nx * ny] = verts.size()
				verts.append(origin + (Vector3(x, y, z) + sum / float(count)) * vs)

	# One quad for every grid edge that crosses the surface, wound so the normal points out of the body (toward positive field).
	for z in range(1, nz):
		for y in range(1, ny):
			for x in range(1, nx):
				var f0: float = field[x + y * sx + z * sxy]

				for axis in range(3):
					var step: int = 1 if axis == 0 else (sx if axis == 1 else sxy)
					var limit_ok: bool = (axis == 0 and x < nx) or (axis == 1 and y < ny) or (axis == 2 and z < nz)

					if not limit_ok:
						continue

					var f1: float = field[x + y * sx + z * sxy + step]

					if (f0 < 0.0) == (f1 < 0.0):
						continue

					var q: Array = []

					if axis == 0:
						q = [Vector3i(x, y - 1, z - 1), Vector3i(x, y, z - 1), Vector3i(x, y, z), Vector3i(x, y - 1, z)]
					elif axis == 1:
						q = [Vector3i(x - 1, y, z - 1), Vector3i(x - 1, y, z), Vector3i(x, y, z), Vector3i(x, y, z - 1)]
					else:
						q = [Vector3i(x - 1, y - 1, z), Vector3i(x, y - 1, z), Vector3i(x, y, z), Vector3i(x - 1, y, z)]

					var ids: Array = []

					for cell in q:
						ids.append(cell_vertex[cell.x + cell.y * nx + cell.z * nx * ny])

					if ids.has(-1):
						continue

					var outward: Vector3 = Vector3.ZERO
					outward[axis] = 1.0 if f0 < 0.0 else -1.0
					var n: Vector3 = (verts[ids[1]] - verts[ids[0]]).cross(verts[ids[2]] - verts[ids[0]]) + (verts[ids[2]] - verts[ids[0]]).cross(verts[ids[3]] - verts[ids[0]])

					if n.dot(outward) > 0.0:       # Godot's front face is clockwise seen from outside, so the triangles are wound against the outward direction
						ids.reverse()

					tris.append_array(PackedInt32Array([ids[0], ids[1], ids[2], ids[0], ids[2], ids[3]]))


static func _normals(verts: PackedVector3Array, tris: PackedInt32Array) -> PackedVector3Array:
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(verts.size())

	for i in range(0, tris.size(), 3):
		var a: int = tris[i]
		var b: int = tris[i + 1]
		var c: int = tris[i + 2]
		var n: Vector3 = (verts[c] - verts[a]).cross(verts[b] - verts[a])       # clockwise winding: this points outward
		normals[a] += n
		normals[b] += n
		normals[c] += n

	for i in range(normals.size()):
		normals[i] = normals[i].normalized()

	return normals


# Skin weights: each vertex takes exp(-distance / falloff) from every primitive, summed per bone, smoothed over the mesh neighbours, then the best 4 bones are kept.
static func _weights(verts: PackedVector3Array, tris: PackedInt32Array, prims: Array, vgroup: PackedInt32Array, g: Dictionary) -> Dictionary:
	var count: int = verts.size()
	var bone_count: int = BONES.size()
	var w: PackedFloat32Array = PackedFloat32Array()
	w.resize(count * bone_count)
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(count)

	# The primitives and bones of each group: a vertex only looks at its own group's primitives (a hand has 9 bones, a leg 4), not all of them.
	var group_prims: Array = []
	var group_bones: Array = []

	for _gi in range(GROUPS):
		group_prims.append([])
		group_bones.append([])

	for q in prims:
		(group_prims[int(q["grp"])] as Array).append(q)
		var list: Array = group_bones[int(q["grp"])]

		if not list.has(int(q["bone"])):
			list.append(int(q["bone"]))

	for i in range(count):
		var best: float = 1000.0
		var best_mat: int = MAT_SKIN
		var mat_best: Dictionary = {}
		var gp: Array = group_prims[vgroup[i]]
		var dists: PackedFloat32Array = PackedFloat32Array()
		dists.resize(gp.size())
		var fall: float = HAND_FALLOFF if vgroup[i] >= 5 else WEIGHT_FALLOFF
		var v: Vector3 = verts[i]

		for k in range(gp.size()):
			var q: Dictionary = gp[k]
			var d: float = prim_sdf(q, v)
			dists[k] = d
			var mat: int = q["mat"]
			# Hair, lips and cloth win a tie with the skin under them.
			var shown: float = d - (0.0 if mat == MAT_SKIN else 0.006)

			mat_best[mat] = minf(float(mat_best.get(mat, 1000.0)), shown)

			if shown < best:
				best = shown
				best_mat = mat

			# Only the primitives of the vertex's own group give it weight, so a torso vertex beside an arm never follows the arm.
			w[i * bone_count + int(q["bone"])] += exp(-maxf(d, 0.0) / fall)

		var shown_color: Color = _material_color(best_mat, g)
		# The material id rides in alpha (opaque materials ignore it); GeneratedBody uses it to recolour. The fraction of alpha carries how far inside its cloth a
		# vertex lies (0.05 at a hem, cuff or collar edge where the skin is nearly as close as the cloth, 0.95 well inside); the shader darkens the low end.
		var inside: float = 0.5

		if best_mat >= MAT_TUNIC:
			var other: float = 1000.0     # the nearest different material: skin at a hem, the tunic at a waist, the boot at a trouser cuff

			for m in mat_best:
				if int(m) != best_mat:
					other = minf(other, float(mat_best[m]))

			inside = clampf((other - best) / HEM_REACH, 0.0, 1.0)

		shown_color.a = (float(best_mat) + 0.05 + 0.9 * inside) / 8.0
		colors[i] = shown_color

	var neighbours: Array = []
	neighbours.resize(count)

	for i in range(count):
		neighbours[i] = PackedInt32Array()

	for i in range(0, tris.size(), 3):
		for k in range(3):
			var a: int = tris[i + k]
			var b: int = tris[i + (k + 1) % 3]
			(neighbours[a] as PackedInt32Array).append(b)
			(neighbours[b] as PackedInt32Array).append(a)

	for _pass in range(WEIGHT_PASSES):
		var next: PackedFloat32Array = w.duplicate()

		for i in range(count):
			var nb: PackedInt32Array = neighbours[i]

			if nb.is_empty():
				continue

			var same: PackedInt32Array = PackedInt32Array()

			for n in nb:
				if vgroup[n] == vgroup[i]:
					same.append(n)

			if same.is_empty():
				continue

			for j in group_bones[vgroup[i]]:
				var s: float = 0.0

				for n in same:
					s += w[n * bone_count + j]

				next[i * bone_count + j] = 0.5 * w[i * bone_count + j] + 0.5 * s / float(same.size())

		w = next

	var bones: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	bones.resize(count * 4)
	weights.resize(count * 4)

	for i in range(count):
		var best_bones: Array = [0, 0, 0, 0]
		var best_w: Array = [0.0, 0.0, 0.0, 0.0]

		for j in group_bones[vgroup[i]]:
			var v: float = w[i * bone_count + j]

			for s in range(4):
				if v > float(best_w[s]):
					best_w.insert(s, v)
					best_bones.insert(s, j)
					best_w.pop_back()
					best_bones.pop_back()
					break

		var total: float = float(best_w[0]) + float(best_w[1]) + float(best_w[2]) + float(best_w[3])

		for s in range(4):
			bones[i * 4 + s] = int(best_bones[s])
			weights[i * 4 + s] = float(best_w[s]) / maxf(total, 0.000001)

	return {"bones": bones, "weights": weights, "colors": colors}


static func _material_color(mat: int, g: Dictionary) -> Color:
	match mat:
		MAT_HAIR:
			return g["hair"]
		MAT_LIPS:
			return g["lips"]
		MAT_TUNIC:
			return g["tunic"]
		MAT_TROUSERS:
			return g["trousers"]
		MAT_BOOTS:
			return g["boots"]

	return g["skin"]


# ---------------------------------------------------------------- scene objects

# Builds a Skeleton3D with the generated skinned mesh (and simple eyes). The result is a Node3D whose child "Skeleton3D" holds the bones.
static var _jobs: Dictionary = {}           # key -> a started worker-thread build (see prewarm)
static var _mesh_cache: Dictionary = {}     # genome hash, voxel and fingers -> {mesh, skin, triangle_count}; bodies with the same genome share one mesh


# The skinned mesh of a body type at one detail level; the bones are the same at every level, so a mesh from here fits any skin made for this genome. With
# use_cache the mesh is shared between bodies of the same genome, voxel and fingers, and a mesh started by prewarm is used. Returns {mesh, triangle_count, from_cache,
# (from_job), ms}.
static func mesh_for(g: Dictionary, voxel: float, fingers: bool, use_cache: bool, rg: Dictionary = {}) -> Dictionary:
	var key: String = "%d|%.4f|%s" % [g.hash(), voxel, str(fingers)]

	if use_cache and _mesh_cache.has(key):
		var hit: Dictionary = _mesh_cache[key]
		return {"mesh": hit["mesh"], "rig": rg if not rg.is_empty() else rig(g), "triangle_count": hit["triangle_count"], "from_cache": true, "ms": {"total": 0.0}}

	var built: Dictionary = {}

	if use_cache and _jobs.has(key):
		built = finish_build(_jobs[key])      # started earlier by prewarm: only the mesh is made here
		built["from_job"] = true
		_jobs.erase(key)
	else:
		built = build(g, voxel, fingers)

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built["arrays"])
	mesh.custom_aabb = AABB(Vector3(-1.5, -0.3, -1.5), Vector3(3.0, 3.0, 3.0))
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85
	mesh.surface_set_material(0, material)
	built["mesh"] = mesh

	if use_cache:
		_mesh_cache[key] = {"mesh": mesh, "triangle_count": built["triangle_count"]}

	return built


static func make_node(g: Dictionary, voxel: float = 0.03, fingers: bool = true, use_cache: bool = false) -> Dictionary:
	var rg: Dictionary = rig(g)
	var root: Node3D = Node3D.new()
	var skeleton: Skeleton3D = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	root.add_child(skeleton)
	var names: Array = rg["names"]

	for i in range(names.size()):
		skeleton.add_bone(names[i])
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, (rg["local"] as Array)[i]))

		if int((rg["parents"] as Array)[i]) >= 0:
			skeleton.set_bone_parent(i, int((rg["parents"] as Array)[i]))

	skeleton.reset_bone_poses()
	var skin: Skin = Skin.new()

	for i in range(names.size()):
		skin.add_bind(i, skeleton.get_bone_global_rest(i).affine_inverse())

	var built: Dictionary = mesh_for(g, voxel, fingers, use_cache, rg)
	var mesh: ArrayMesh = built["mesh"]
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mesh
	body.skin = skin
	body.skeleton = NodePath("..")
	skeleton.add_child(body)
	root.set_meta("face", make_face(g, skeleton))
	return {"node": root, "skeleton": skeleton, "built": built}


# The body's own measures in metres, from its sliders (the same numbers the body parts are built from), for clothing builders that fit themselves instead of using
# worn_fit: half widths and depths, radii and lengths of limbs, hand and finger sizes. For the neutral genome these are the values the old worn pieces were written for
# (limbs run down -Y, front is -Z, right is +X). Stored on a generated body as the meta "worn_measures".
static func measures(g: Dictionary) -> Dictionary:
	var rg: Dictionary = rig(g)
	var d: Dictionary = rg["dims"]
	var b: float = m(float(g["build"]), 0.8, 1.3)
	var mu: float = m(float(g["muscle"]), 0.9, 1.22)
	var wide: float = m(float(g["shoulders"]), 0.85, 1.3)
	var hip_w: float = m(float(g["hips"]), 0.85, 1.25)
	var hk: float = m(float(g["hands"]), 0.8, 1.5)
	var fk: float = m(float(g["feet"]), 0.85, 1.3)
	var hs: float = m(float(g["head"]), 0.85, 1.4)
	var torso: float = float(d["torso"])
	return {
		"chest_half_width": 0.155 * b * wide, "chest_half_depth": 0.12 * b * mu, "chest_height": 0.4 * torso,
		"waist_half_width": 0.155 * b, "waist_half_depth": 0.12 * b * m(float(g["belly"]), 0.85, 1.55),
		"hips_half_width": 0.165 * b * hip_w, "hips_half_depth": 0.12 * b,
		"upper_arm_radius": 0.052 * sqrt(b) * mu, "upper_arm_length": 0.29 * float(d["arm"]),
		"forearm_radius": 0.042 * mu, "forearm_length": 0.26 * float(d["arm"]),
		"thigh_radius": 0.085 * sqrt(b) * mu * hip_w, "thigh_length": 0.44 * float(d["legs"]),
		"shin_radius": 0.058 * mu, "shin_length": 0.40 * float(d["legs"]),
		"hand_length": 0.15 * hk, "hand_half_width": 0.038 * hk, "hand_half_thickness": 0.017 * hk,
		"finger_count": 4, "finger_radius": 0.011 * hk, "finger_length": 0.066 * hk, "thumb_length": 0.056 * hk,
		"foot_length": 0.23 * fk, "foot_half_width": 0.05 * fk, "head_scale": hs,
	}


# Threaded build (Plan 17): `build` uses only maths, arrays and resources made from them, no nodes, so it can run on a worker thread. start_build returns a handle;
# poll with build_done and take the result with finish_build (which waits if needed). The result is the same as `build(g, voxel, fingers)`.
static func start_build(g: Dictionary, voxel: float = 0.03, fingers: bool = true) -> Dictionary:
	var job: Dictionary = {"genome": g.duplicate(true), "voxel": voxel, "fingers": fingers, "result": {}}
	job["task"] = WorkerThreadPool.add_task(func() -> void: job["result"] = build(job["genome"], job["voxel"], job["fingers"]), false, "generated body")
	return job


static func build_done(job: Dictionary) -> bool:
	return bool(job.get("finished", false)) or WorkerThreadPool.is_task_completed(int(job["task"]))


static func finish_build(job: Dictionary) -> Dictionary:
	if not bool(job.get("finished", false)):
		WorkerThreadPool.wait_for_task_completion(int(job["task"]))
		job["finished"] = true

	return job["result"]


# Starts building a body type on a worker thread so that the first make_node(use_cache) of it does not wait (Plan 17). Does nothing if it is cached or already started.
static func prewarm(g: Dictionary, voxel: float = 0.03, fingers: bool = true) -> void:
	var key: String = "%d|%.4f|%s" % [g.hash(), voxel, str(fingers)]

	if not _mesh_cache.has(key) and not _jobs.has(key):
		_jobs[key] = start_build(g, voxel, fingers)


# A body type from a number: sliders drawn around the neutral body (a bell-shaped spread, so most people are ordinary and a few are extreme), a skin tone and a
# hair colour from small palettes. The same seed always gives the same genome; used for NPC variety.
static func genome_from_seed(seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var skins: Array = [Color(0.85, 0.66, 0.52), Color(0.72, 0.52, 0.38), Color(0.55, 0.38, 0.27), Color(0.93, 0.78, 0.66), Color(0.42, 0.28, 0.2)]
	var hairs: Array = [Color(0.25, 0.16, 0.09), Color(0.08, 0.06, 0.05), Color(0.7, 0.55, 0.25), Color(0.55, 0.2, 0.1), Color(0.6, 0.58, 0.55)]
	var g: Dictionary = make_genome("average", skins[rng.randi() % skins.size()], hairs[rng.randi() % hairs.size()])

	for key in SLIDERS:
		g[key] = clampf(rng.randfn(0.0, 0.4), -0.9, 0.9)

	return g


# How worn pieces are scaled to this body: bone name -> (width, length, depth) factors on the sizes and places written for the neutral body. For the neutral
# genome every factor is 1, so nothing changes. Used by worn_look.gd through the rig meta "worn_fit" (Plan 15).
static func worn_fit(g: Dictionary) -> Dictionary:
	var h: float = m(float(g["height"]), 0.9, 1.12)
	var b: float = m(float(g["build"]), 0.8, 1.3)
	var mu: float = m(float(g["muscle"]), 0.9, 1.22)
	var wide: float = m(float(g["shoulders"]), 0.85, 1.3)
	var hip_w: float = m(float(g["hips"]), 0.85, 1.25)
	var torso: float = h * m(float(g["torso"]), 0.9, 1.12)
	var legs: float = h * m(float(g["legs"]), 0.9, 1.12)
	var arm: float = h * m(float(g["arms"]), 0.88, 1.15)
	var hs: float = m(float(g["head"]), 0.85, 1.4)
	var hk: float = m(float(g["hands"]), 0.8, 1.5)
	var fk: float = m(float(g["feet"]), 0.85, 1.3)
	var limb: float = sqrt(b) * mu
	return {
		"Hips": Vector3(b * hip_w, h, b),
		"Chest": Vector3(b * wide, torso, b * mu),
		"Head": Vector3(hs, hs, hs),
		"LeftUpperArm": Vector3(limb, arm, limb), "RightUpperArm": Vector3(limb, arm, limb),
		"LeftLowerArm": Vector3(limb, arm, limb), "RightLowerArm": Vector3(limb, arm, limb),
		"LeftHand": Vector3(hk, hk, hk), "RightHand": Vector3(hk, hk, hk),
		"LeftUpperLeg": Vector3(limb * hip_w, legs, limb), "RightUpperLeg": Vector3(limb * hip_w, legs, limb),
		"LeftLowerLeg": Vector3(limb, legs, limb), "RightLowerLeg": Vector3(limb, legs, limb),
		"LeftFoot": Vector3(fk, fk, fk), "RightFoot": Vector3(fk, fk, fk),
	}


# ---------------------------------------------------------------- face (eyes and brows that can move; no mesh rebuild)

# Adds a BoneAttachment3D "Face" on the Head bone with two eyes (a white and a dark sphere each, squashed to blink or stretched to widen) and two brows
# (hair colour, raised or lowered). No lip-sync and no jaw: the expression comes from the eyes, the brows and the body (CHARACTER_DESIGN_VISION.md 4.6).
static func make_face(g: Dictionary, skeleton: Skeleton3D) -> Node3D:
	var attach: BoneAttachment3D = BoneAttachment3D.new()
	attach.name = "Face"
	skeleton.add_child(attach)
	attach.bone_name = "Head"
	var hs: float = m(float(g["head"]), 0.85, 1.4)
	var brow_k: float = m(float(g["brow"]), 0.5, 2.0)

	for side in [-1.0, 1.0]:
		var tag: String = "L" if side < 0.0 else "R"
		var eye: Node3D = Node3D.new()
		eye.name = "Eye" + tag
		eye.position = Vector3(0.037 * hs * side, 0.148 * hs, -0.093 * hs)
		attach.add_child(eye)
		var white: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.021 * hs
		sphere.height = 0.042 * hs
		sphere.radial_segments = 12
		sphere.rings = 6
		white.mesh = sphere
		var wm: StandardMaterial3D = StandardMaterial3D.new()
		wm.albedo_color = Color(0.96, 0.95, 0.92)
		white.material_override = wm
		eye.add_child(white)
		var pupil: MeshInstance3D = MeshInstance3D.new()
		var ps: SphereMesh = SphereMesh.new()
		ps.radius = 0.0105 * hs
		ps.height = 0.021 * hs
		ps.radial_segments = 10
		ps.rings = 5
		pupil.mesh = ps
		var pm: StandardMaterial3D = StandardMaterial3D.new()
		pm.albedo_color = Color(0.08, 0.06, 0.05)
		pupil.material_override = pm
		pupil.position = Vector3(0.0, 0.0, -0.0155 * hs)
		eye.add_child(pupil)
		var brow: MeshInstance3D = MeshInstance3D.new()
		brow.name = "Brow" + tag
		var bs: SphereMesh = SphereMesh.new()
		bs.radius = 0.5
		bs.height = 1.0
		bs.radial_segments = 10
		bs.rings = 5
		brow.mesh = bs
		brow.scale = Vector3(0.045 * hs, 0.012 * hs * brow_k, 0.022 * hs)
		var bm: StandardMaterial3D = StandardMaterial3D.new()
		bm.albedo_color = g["hair"]
		brow.material_override = bm
		brow.position = Vector3(0.037 * hs * side, 0.183 * hs, -0.088 * hs)
		brow.set_meta("base_y", brow.position.y)
		brow.set_meta("hs", hs)
		attach.add_child(brow)

	return attach


# open: 0 shut (a blink) to 1 normal to 1.3 wide with surprise; brow_raise: -1 lowered (anger, effort) to 1 raised (surprise).
static func set_expression(face: Node3D, open: float, brow_raise: float) -> void:
	for tag in ["L", "R"]:
		var eye: Node3D = face.get_node("Eye" + tag)
		eye.scale = Vector3(1.0, clampf(open, 0.05, 1.4), 1.0)
		var brow: Node3D = face.get_node("Brow" + tag)
		brow.position.y = float(brow.get_meta("base_y")) + brow_raise * 0.022 * float(brow.get_meta("hs"))


# ---------------------------------------------------------------- share code and detail levels

const CODE_VERSION := 1
const COLOR_KEYS := ["skin", "hair", "tunic", "trousers", "boots"]


static func _crc8(bytes: PackedByteArray) -> int:
	var crc: int = 0

	for b in bytes:
		crc ^= int(b)

		for _i in range(8):
			crc = ((crc << 1) ^ 0x07) & 0xFF if (crc & 0x80) != 0 else (crc << 1) & 0xFF

	return crc


# A genome as a short text code: a version byte, one byte per slider, three bytes per colour and a check byte, in Base64. Slider values are stored,
# not mesh results, so the generator can improve without breaking saved characters (CHARACTER_DESIGN_VISION.md 5.7.9).
static func encode(g: Dictionary) -> String:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(CODE_VERSION)

	for key in SLIDERS:
		bytes.append(clampi(roundi((clampf(float(g[key]), -1.0, 1.0) + 1.0) * 127.5), 0, 255))

	for key in COLOR_KEYS:
		var c: Color = g[key]
		bytes.append(clampi(roundi(c.r * 255.0), 0, 255))
		bytes.append(clampi(roundi(c.g * 255.0), 0, 255))
		bytes.append(clampi(roundi(c.b * 255.0), 0, 255))

	bytes.append(_crc8(bytes))
	return Marshalls.raw_to_base64(bytes)


# Returns the genome, or an empty dictionary when the code is damaged, has the wrong length or another version. Never executes anything from the text.
static func decode(code: String) -> Dictionary:
	var bytes: PackedByteArray = Marshalls.base64_to_raw(code.strip_edges())
	var expected: int = 1 + SLIDERS.size() + COLOR_KEYS.size() * 3 + 1

	if bytes.size() != expected or bytes[0] != CODE_VERSION:
		return {}

	var body: PackedByteArray = bytes.slice(0, expected - 1)

	if _crc8(body) != int(bytes[expected - 1]):
		return {}

	var g: Dictionary = {}
	var at: int = 1

	for key in SLIDERS:
		g[key] = float(bytes[at]) / 127.5 - 1.0
		at += 1

	for key in COLOR_KEYS:
		g[key] = Color(float(bytes[at]) / 255.0, float(bytes[at + 1]) / 255.0, float(bytes[at + 2]) / 255.0)
		at += 3

	g["lips"] = (g["skin"] as Color).lerp(Color(0.7, 0.25, 0.25), 0.5)
	return g


# The voxel size for a detail level (0 near, 1 middle, 2 far).
static func lod_voxel(level: int) -> float:
	return float(LOD_VOXELS[clampi(level, 0, LOD_VOXELS.size() - 1)])
