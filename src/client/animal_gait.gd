extends RefCounted

# Which leg clip a drawn animal plays and how fast, so its legs keep up with the ground (Dave 21 Nov 2026: animals "shouldn't be
# teleporting around or running without moving their feet or legs"; docs/design/ANIMAL_GAIT.md).
#
# Three things made the feet slide or stop:
# - The ground speed was taken afresh every frame from how far the body was drawn. It jumps at every sent point and drops to nothing on a
#   late send, so the clip flicked between stand, walk and run and restarted its blend each time. It is now smoothed over SMOOTH_S, and a
#   clip changes only past a margin (MOVE_ON / MOVE_OFF, RUN_BAND): no flicker at the edge.
# - Some in-place clips were measured at a fifth of their real speed (the lynx walk 0.26 m/s, the guineafowl run 0.20; Dave's game log,
#   21 Nov 2026), and the playing rate stopped at twice the clip's speed: such an animal glided along with its legs barely moving. A
#   measurement more than TRUST_X away from the row's own speed is not trusted (stride_ok), and the rate may go to RATE_MAX.
# - A model with only one moving clip (a walk but no run) stood in its idle pose while it moved: it now plays the moving clip it has.

const SMOOTH_S := 0.15          # the drawn ground speed is eased over this long
const SNAP_MPS := 40.0          # faster than this between two frames is a body put somewhere at once, not a speed
const MOVE_ON := 0.45           # m/s: a standing animal starts its walk clip above this
const MOVE_OFF := 0.25          # m/s: a walking animal stands below this
const RUN_BAND := 0.1           # the switch between walk and run sits this share either side of half way between the two clip speeds
const RATE_MIN := 0.4           # the slowest a walk or run clip plays (a very slow amble still moves its legs)
const RATE_MAX := 2.5           # the fastest (a sprint past the run clip's own speed)
const TRUST_X := 3.0            # a measured clip speed this many times off the model row's speed is a failed measurement


# The ground speed to animate by: `was` eased toward this frame's `raw` speed. A jump (a body put somewhere at once) keeps `was`.
static func smooth(was: float, raw: float, delta: float) -> float:
	if raw > SNAP_MPS or delta <= 0.0:
		return was

	return lerpf(was, raw, 1.0 - exp(-delta / SMOOTH_S))


# "walk", "trot", "run" or "" (standing) for an animal moving at `speed`, given the moving clip it played last frame (`was`) and the speeds
# its walk, run and trot clips were made at. With no trot (trot_mps 0, or not between the walk and the run) it walks or runs only. A wolf
# backing off at 5 m/s played its walk at the top rate (2.5 x 1.5 m/s) and slid; it trots now (Dave 23 Nov 2026: "really bad animatronics").
static func role(speed: float, was: String, walk_mps: float, run_mps: float, trot_mps: float = 0.0) -> String:
	if speed < (MOVE_OFF if was != "" else MOVE_ON):
		return ""

	if trot_mps <= walk_mps or trot_mps >= run_mps:
		var mid: float = (walk_mps + run_mps) * 0.5

		if was == "run":
			return "run" if speed > mid * (1.0 - RUN_BAND) else "walk"

		return "run" if speed > mid * (1.0 + RUN_BAND) else "walk"

	var high: float = (trot_mps + run_mps) * 0.5
	var low: float = (walk_mps + trot_mps) * 0.5

	if speed > high * ((1.0 - RUN_BAND) if was == "run" else (1.0 + RUN_BAND)):
		return "run"

	if speed > low * ((1.0 - RUN_BAND) if was == "trot" or was == "run" else (1.0 + RUN_BAND)):
		return "trot"

	return "walk"


# The rate to play a moving clip made for `ref` m/s at `speed` m/s (1 with no reference).
static func rate(speed: float, ref: float) -> float:
	return clampf(speed / ref, RATE_MIN, RATE_MAX) if ref > 0.0 else 1.0


# Whether a clip speed measured from its feet can be believed against the model row's speed for that clip (`typed`, m/s).
static func stride_ok(measured: float, typed: float) -> bool:
	if measured <= 0.0:
		return false

	if typed <= 0.0:
		return true

	return measured <= typed * TRUST_X and measured >= typed / TRUST_X


# The clip for a moving role: the role's own, else the nearest other moving clip (a trot falls back to the walk, then the run), else the
# standing clip ("0"), else "".
static func moving_clip(roles: Dictionary, which: String) -> String:
	if roles.has(which):
		return str(roles[which])

	var others: Array = ["trot", "walk"]      # a run with no run clip

	if which == "trot":
		others = ["walk", "run"]
	elif which == "walk":
		others = ["trot", "run"]

	for other in others:
		if roles.has(other):
			return str(roles[other])

	return str(roles.get("0", ""))
