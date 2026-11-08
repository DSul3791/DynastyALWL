extends RefCounted

# The pose library (docs/design/POSE_LIBRARY.md, MikeW 8 Nov 2026): Dave's preference, rigged models fixed by posing the skeleton in
# code. One table of poses by body part, resolved on each rig to its own bones, so a model with no clip for a state still shows it.
# The parts come from the row (its look bones are the neck and head, its feet chains the legs) and from bone names (the spine);
# the angles are degrees about the row's pose_axis (default x, the WildMesh rigs' pitch), times pose_sign. The poses are keyed by
# Steve's state numbers: 3 alert, 18 sit, 19 lie, 20 hunch, 21 drink (Steve's DRINK, #734), -1 sleep (the
# client's own sleep key, POSED_STATES.md); groom is a named pose for the idle table.

# pose -> {part: degrees, ..., "blend_s": seconds}. Parts: neck (each neck bone), head, spine (each spine bone), front (each front leg's
# upper and lower bone), hind (each hind leg's upper and lower bone), neck_yaw and head_yaw (a turn about the bone's own y).
const POSES := {
	"alert": {"neck": -8.0, "head": 4.0, "blend_s": 0.25},
	"hunch": {"neck": 12.0, "head": -4.0, "spine": 4.0, "blend_s": 0.8},
	"drink": {"neck": 22.0, "head": -10.0, "front": -6.0, "blend_s": 0.6},
	"sleep": {"neck": 25.0, "head": -6.0, "front": -45.0, "hind": 45.0, "spine": 6.0, "blend_s": 1.5},
	"lie": {"neck": 6.0, "head": -2.0, "front": -60.0, "hind": 60.0, "blend_s": 1.0},
	"sit": {"neck": -6.0, "spine": -10.0, "hind": 55.0, "blend_s": 0.8},
	"groom": {"neck": 10.0, "neck_yaw": 25.0, "head_yaw": 15.0, "head": 8.0, "blend_s": 0.5},
}

# Steve's states and the client's sleep key -> pose name.
const STATE_POSES := {"3": "alert", "18": "sit", "19": "lie", "20": "hunch", "21": "drink", "-1": "sleep"}

# The clip role the row would use for each pose's state (a row with that clip keeps its clip).
const CLIP_ROLE := {"3": "3", "18": "18", "19": "19", "20": "20", "21": "21", "-1": "sleep"}


# The parts of a rig: {neck [names], head name, spine [names], front [[upper, lower]], hind [[upper, lower]]}.
static func parts(sk: Skeleton3D, row: Dictionary) -> Dictionary:
	var look: Array = (row.get("look", {}) as Dictionary).get("bones", [])
	var neck: Array = []
	var head: String = ""

	for i in look.size():
		if sk.find_bone(str(look[i])) < 0:
			continue

		if i == look.size() - 1:
			head = str(look[i])
		else:
			neck.append(str(look[i]))

	var spine: Array = []

	for i in sk.get_bone_count():
		var low: String = sk.get_bone_name(i).to_lower()

		if low.contains("spine") and spine.size() < 3:
			spine.append(sk.get_bone_name(i))

	var front: Array = []
	var hind: Array = []
	var feet: Array = row.get("feet", [])

	for k in feet.size():
		var chain: Array = feet[k]

		if chain.size() >= 2 and sk.find_bone(str(chain[0])) >= 0 and sk.find_bone(str(chain[1])) >= 0:
			(front if k < 2 else hind).append([str(chain[0]), str(chain[1])])      # feet rows list the front legs first

	return {"neck": neck, "head": head, "spine": spine, "front": front, "hind": hind}


# A state pose for bone_offsets.setup_poses ({bones {name: [x, y, z]}}) from a library pose on these parts, or {} when the rig has
# none of the parts the pose moves.
static func build(pose_name: String, p: Dictionary, row: Dictionary) -> Dictionary:
	var spec: Dictionary = POSES.get(pose_name, {})
	var axis: int = {"x": 0, "y": 1, "z": 2}.get(str(row.get("pose_axis", "x")), 0)
	var sgn: float = float(row.get("pose_sign", 1.0))
	var bones: Dictionary = {}

	var put := func(bone: String, deg: float, along: int) -> void:
		var v: Array = bones.get(bone, [0.0, 0.0, 0.0])
		v[along] = float(v[along]) + deg
		bones[bone] = v

	for b in p["neck"]:
		if spec.has("neck"):
			put.call(b, sgn * float(spec["neck"]) / maxf(float(p["neck"].size()), 1.0) * 2.0, axis)
		if spec.has("neck_yaw"):
			put.call(b, float(spec["neck_yaw"]) / maxf(float(p["neck"].size()), 1.0), 1)

	if str(p["head"]) != "":
		if spec.has("head"):
			put.call(p["head"], sgn * float(spec["head"]), axis)
		if spec.has("head_yaw"):
			put.call(p["head"], float(spec["head_yaw"]), 1)

	for b in p["spine"]:
		if spec.has("spine"):
			put.call(b, sgn * float(spec["spine"]), axis)

	for leg in p["front"]:
		if spec.has("front"):
			put.call(leg[0], sgn * float(spec["front"]), axis)
			put.call(leg[1], -sgn * float(spec["front"]) * 1.2, axis)

	for leg in p["hind"]:
		if spec.has("hind"):
			put.call(leg[0], sgn * float(spec["hind"]), axis)
			put.call(leg[1], -sgn * float(spec["hind"]) * 1.2, axis)

	return {"bones": bones} if not bones.is_empty() else {}


static func blend_s(pose_name: String) -> float:
	return float((POSES.get(pose_name, {}) as Dictionary).get("blend_s", 0.25))
