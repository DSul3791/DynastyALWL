extends SkeletonModifier3D

# Body proportions for Dave's character (dynasty_body.gd, Kathreen 3 Nov 2026): the creator's sliders (body_generator.gd SLIDERS) scale bones of the Mixamo rig after the animation
# has posed it, so every clip keeps playing and the body only changes shape. Dave's QA answer (pic-creator-front, 2 Nov): "use our new character mesh and allow us to adjust his
# proportions".
#
# A bone's scale also scales everything below it, so each scaled bone is undone on the next bone down: the Legs slider scales the thigh bone and undoes it on the foot, so the thigh and
# shin grow longer and the foot keeps its size. The hips are lifted by what the legs gained so the feet stay on the ground. Height is the whole model's scale (dynasty_body.gd).
# Factors use the generated body's ranges where a bone scale can carry them; widths (build, muscle, belly, chest, hips) need shape keys or a non-uniform scale that would shear under
# animation, so they are not done here yet.

const Generator := preload("res://src/client/character/body_generator.gd")
const P := "mixamorig_"

# Slider -> [low, high] at -1 and +1 (0 is 1.0).
const RANGES := {
	"height": [0.9, 1.12],
	"legs": [0.9, 1.12],
	"torso": [0.9, 1.12],
	"arms": [0.88, 1.15],
	"shoulders": [0.85, 1.25],
	"neck": [0.85, 1.2],
	"head": [0.9, 1.1],
	"hands": [0.88, 1.15],
	"feet": [0.9, 1.15],
}

var factors: Dictionary = {}          # slider -> factor; set_genome fills it
var _scales: Array = []               # [bone index, scale] written every frame
var _hips: int = -1
var _hips_lift: float = 0.0           # skeleton units (centimetres on Dave's rig)
var _written_hips: Vector3 = Vector3.INF
var _base_hips: Vector3 = Vector3.ZERO
var _dirty: bool = true               # the bone list is built on the first frame with a skeleton


static func factor(g: Dictionary, key: String) -> float:
	var r: Array = RANGES[key]
	return Generator.m(clampf(float(g.get(key, 0.0)), -1.0, 1.0), float(r[0]), float(r[1]))


# The factors of a genome (an empty genome is the plain body). Call again whenever a slider moves; it is cheap.
func set_genome(g: Dictionary) -> void:
	factors.clear()

	for key in RANGES:
		factors[key] = factor(g, key)

	_dirty = true


func _rebuild() -> void:
	_scales.clear()
	_hips_lift = 0.0
	var s: Skeleton3D = get_skeleton()

	if s == null or factors.is_empty():
		return

	var legs: float = factors["legs"]
	var torso: float = factors["torso"]
	var arms: float = factors["arms"]
	var shoulders: float = factors["shoulders"]
	var neck: float = factors["neck"]
	var head: float = factors["head"]
	var hands: float = factors["hands"]
	var feet: float = factors["feet"]
	# Each bone's own scale, so that its global scale is the product down the chain: Spine carries the torso, Neck and Shoulder undo it, Arm undoes the shoulder, and so on.
	_add(s, "Spine", torso)
	_add(s, "Neck", neck / torso)
	_add(s, "Head", head / neck)

	for side in ["Left", "Right"]:
		_add(s, side + "Shoulder", shoulders / torso)
		_add(s, side + "Arm", arms / shoulders)
		_add(s, side + "Hand", hands / arms)
		_add(s, side + "UpLeg", legs)
		_add(s, side + "Foot", feet / legs)

	_hips = s.find_bone(P + "Hips")
	var knee: int = s.find_bone(P + "LeftLeg")
	var ankle: int = s.find_bone(P + "LeftFoot")
	var leg_length: float = 0.0

	if knee >= 0 and ankle >= 0:
		leg_length = s.get_bone_rest(knee).origin.length() + s.get_bone_rest(ankle).origin.length()

	# The hips lift by what the thigh and shin gained, and a little for a bigger foot (the ankle sits higher).
	var ankle_height: float = 0.0

	if ankle >= 0:
		ankle_height = s.get_bone_global_rest(ankle).origin.y

	_hips_lift = (legs - 1.0) * leg_length + (feet - 1.0) * ankle_height * 0.5


func _add(s: Skeleton3D, bone: String, k: float) -> void:
	var i: int = s.find_bone(P + bone)

	if i >= 0:      # kept even at 1.0, so a slider moved back to 0 puts the bone back
		_scales.append([i, k])


func _process_modification_with_delta(_delta: float) -> void:
	var s: Skeleton3D = get_skeleton()

	if s == null:
		return

	if _dirty:
		_dirty = false
		_rebuild()

	for row in _scales:
		s.set_bone_pose_scale(int(row[0]), Vector3.ONE * float(row[1]))

	if _hips >= 0:
		# The clip writes the hips every frame; if nothing wrote them since our last frame (a paused or missing track), start from the same base so the lift never adds up.
		var now: Vector3 = s.get_bone_pose_position(_hips)
		_base_hips = _base_hips if now.is_equal_approx(_written_hips) else now
		_written_hips = _base_hips + Vector3(0.0, _hips_lift, 0.0)
		s.set_bone_pose_position(_hips, _written_hips)
