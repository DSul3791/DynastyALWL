extends SkeletonModifier3D

# Subtle breathing on Dave's body where its clip holds still (Kathreen 5 Nov 2026; BACKLOG rank 5, Kathleen's P4; CHARACTER_DESIGN_VISION.md "sit / lie: static poses with
# breathing", "secondary motion: breathing ... the head stays level"). The standing "idle" is left alone: Dave's Idle clip already breathes (over its 4 s loop Spine1 and Spine2
# turn 14.7 degrees and the neck 22, read from the glb). The ground sit holds one still frame (_hold_first, #400/#409), so it gets an additive layer after the clip: the two upper
# spine bones rock a fraction of a degree on a slow breath (inhale a little quicker than exhale) and the neck turns back by the same amount, so the chest rises and falls while the
# eyes stay level. The posing itself is untouched. It eases in and out over half a second, so sitting down or standing up never pops. Every other clip is drawn exactly as it is.
# Made by dynasty_body.gd under the skeleton, after the Proportions modifier; `player` is the body's AnimationPlayer.

const P := "mixamorig_"
const PERIOD_S := 4.2                 # one breath at rest (about 14 a minute)
const FADE_S := 0.5                   # ease in and out when the body enters or leaves a breathing clip
const CLIPS := ["sit"]                # the clips that hold still (idle breathes in Dave's clip already)
# Bone -> peak turn in degrees about its own X (side-to-side) axis. The neck takes back the spine's turn so the head stays level.
const BONES := {"Spine1": 0.45, "Spine2": 0.6, "Neck": -1.05}

var player: AnimationPlayer
var weight: float = 0.0               # 0 = the clip as drawn, 1 = full breath
var _ids: Dictionary = {}             # bone name -> index, found on the first update
var _phase: float = 0.0               # a per-body offset, so two bodies side by side do not breathe in step


func _ready() -> void:
	_phase = float(get_instance_id() % 1000) / 1000.0


# The breath shape at time t (seconds): -1 .. 1, a quicker inhale (40% of the cycle) and a slower exhale.
static func breath(t: float) -> float:
	var u: float = fposmod(t / PERIOD_S, 1.0)
	return sin(PI * u / 0.4 - PI * 0.5) if u < 0.4 else sin(PI * (u - 0.4) / 0.6 + PI * 0.5)


# The eased weight after one frame: towards 1 in a breathing clip, towards 0 in anything else.
static func step_weight(w: float, clip: String, delta: float) -> float:
	var target: float = 1.0 if clip in CLIPS else 0.0
	return move_toward(w, target, delta / FADE_S)


func _process_modification_with_delta(delta: float) -> void:
	var s: Skeleton3D = get_skeleton()

	if s == null:
		return

	var clip: String = String(player.current_animation) if player != null else ""
	weight = step_weight(weight, clip, delta)

	if weight <= 0.0:
		return

	if _ids.is_empty():
		for bone in BONES:
			_ids[bone] = s.find_bone(P + bone)

	var b: float = breath(float(Time.get_ticks_msec()) / 1000.0 + _phase * PERIOD_S) * weight

	for bone in BONES:
		var i: int = int(_ids[bone])

		if i < 0:
			continue

		var turn := Quaternion(Vector3.RIGHT, deg_to_rad(float(BONES[bone])) * b)
		s.set_bone_pose_rotation(i, s.get_bone_pose_rotation(i) * turn)
