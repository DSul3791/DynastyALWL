extends RefCounted

# The player's stance (owner, 2026-10-20): standing, crouching (C), sitting (X) and lying
# down (Z), each key a toggle. Any movement key stands the player up from sitting or lying;
# crouching is kept while moving, slowly. Sitting or lying drops exertion to 0 (the server's
# exertion code, owner Items, reads the stance; the client sends it when it changes, see
# `changed`).
#
# This class only holds the state and the smooth eye height and body shape; the client
# (terrain_client.gd) feeds it keys and applies `eye_y` to the camera.

enum { STAND, CROUCH, SIT, LIE }

const NAMES := ["standing", "crouching", "sitting", "lying down"]
const EYE_Y := [0.7, 0.2, -0.05, -0.55]          # camera height above the body's centre
const SHAPE_HEIGHT := [1.8, 1.2, 1.0, 0.7]       # collision capsule height (feet stay on the ground)
const SPEED := [1.0, 0.45, 0.0, 0.0]             # share of walking pace
const EYE_RATE := 5.0                            # per second, how fast the eye height follows

signal changed(stance: int)

var stance: int = STAND
var eye_y: float = 0.7


func moves() -> bool:
	return SPEED[stance] > 0.0


# Toggles `wanted` (back to standing when already in it). Returns whether the stance changed.
func toggle(wanted: int) -> bool:
	return set_stance(STAND if stance == wanted else wanted)


func set_stance(wanted: int) -> bool:
	if wanted == stance:
		return false

	stance = wanted
	changed.emit(stance)
	return true


# A movement key was pressed: up from sitting or lying (crouching stays).
func moved() -> void:
	if stance == SIT or stance == LIE:
		set_stance(STAND)


# Smooth eye height; call every frame.
func step(delta: float) -> void:
	eye_y = lerpf(eye_y, float(EYE_Y[stance]), clampf(EYE_RATE * delta, 0.0, 1.0))


# The collision capsule for the stance, its centre shifted so the feet stay where they are.
func apply_shape(shape: CollisionShape3D) -> void:
	var capsule: CapsuleShape3D = shape.shape as CapsuleShape3D
	var height: float = float(SHAPE_HEIGHT[stance])
	capsule.height = height
	shape.position.y = -(float(SHAPE_HEIGHT[STAND]) - height) * 0.5
