extends RefCounted

# Photo camera (Dave 1 Nov 2026, K key): a free third-person view that orbits the character and always looks at it. The mouse swings the
# camera round and tilts it (the character does not turn), the wheel zooms from nearly at the face out to 60 m, PageUp / PageDown raise and
# lower the camera, the movement keys walk relative to the camera. Only the drawn camera moves: the eye node, the aim and everything the
# server is told (position and speed, no facing) stay as they were. This file is the arithmetic; terrain_client.gd places the camera.

const MIN_M := 0.4              # almost at the character's face
const MAX_M := 60.0
const ZOOM_FACTOR := 1.18       # each wheel notch multiplies or divides the distance (equal steps whatever the distance)
const ZOOM_EASE := 9.0          # the drawn distance catches up with the wanted one at this rate per second
const ELEV_MIN := -0.35         # how far below the character's height the camera may swing (radians)
const ELEV_MAX := 1.5           # and above (nearly overhead)
const HEIGHT_MIN := -1.0        # raise and lower: metres on top of the orbit
const HEIGHT_MAX := 40.0
const RISE_MPS := 3.0           # raise speed, plus a share of the distance so a far camera rises as quickly as it looks
const RISE_PER_M := 0.25
const FOCUS_UP_M := 0.3         # the point looked at, above the middle of the body
const GROUND_CLEAR_M := 0.35    # the camera stays this far above the ground
const SENSITIVITY := 0.003
const START_M := 3.5

var active: bool = false
var yaw: float = 0.0            # the way the camera looks (Godot rotation_y: forward is -Z turned by yaw)
var elevation: float = 0.25     # radians the camera sits above the character's height
var distance: float = START_M   # wanted
var distance_now: float = START_M   # drawn
var height: float = 0.0


# K: into the photo view looking where the character looks, or back out. Returns whether it is on.
func toggle(body_yaw: float) -> bool:
	active = not active

	if active:
		yaw = body_yaw
		elevation = 0.25
		distance = clampf(distance, MIN_M, MAX_M)
		distance_now = distance
		height = 0.0

	return active


# Mouse movement in pixels: left and right swing the camera round the character, up and down tilt it.
func orbit(dx: float, dy: float) -> void:
	yaw = wrapf(yaw - dx * SENSITIVITY, -PI, PI)
	elevation = clampf(elevation + dy * SENSITIVITY, ELEV_MIN, ELEV_MAX)


# One wheel notch: out (true) or in.
func zoom(out: bool) -> void:
	distance = clampf(distance * ZOOM_FACTOR if out else distance / ZOOM_FACTOR, MIN_M, MAX_M)


# PageUp (+1) or PageDown (-1) held for `delta` seconds.
func raise(direction: float, delta: float) -> void:
	height = clampf(height + direction * (RISE_MPS + RISE_PER_M * distance_now) * delta, HEIGHT_MIN, HEIGHT_MAX)


# Each frame: the drawn distance eases toward the wanted one (smooth zoom, no jumps).
func step(delta: float) -> void:
	distance_now = lerpf(distance_now, distance, clampf(delta * ZOOM_EASE, 0.0, 1.0))

	if absf(distance_now - distance) < 0.001:
		distance_now = distance


# The point the camera looks at, from the character's middle.
func focus_point(body_position: Vector3) -> Vector3:
	return body_position + Vector3(0.0, FOCUS_UP_M, 0.0)


# Where the camera sits for a focus point, before the ground and walls are looked at.
func camera_position(focus: Vector3) -> Vector3:
	var back: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))   # opposite the way the camera looks
	return focus + back * (distance_now * cos(elevation)) + Vector3(0.0, distance_now * sin(elevation) + height, 0.0)


# The camera never sinks into the ground (NAN ground: nothing known below, left as it is).
func clamp_to_ground(position: Vector3, ground_y: float) -> Vector3:
	if is_nan(ground_y):
		return position

	return Vector3(position.x, maxf(position.y, ground_y + GROUND_CLEAR_M), position.z)


# The camera's transform: at the position, looking at the focus.
func camera_basis(position: Vector3, focus: Vector3) -> Basis:
	var to: Vector3 = focus - position

	if to.length() < 0.001:
		return Basis(Vector3.UP, yaw)

	return Basis.looking_at(to.normalized(), Vector3.UP)


# What the normal view looked like when the photo camera went on, so leaving puts every bit of it back (the first version left the drawn camera
# turned to the last photo angle, which tilted the head and stopped the player looking down).
static func snapshot(body: Node3D, eye: Node3D, drawn: Camera3D, pitch: float) -> Dictionary:
	return {"yaw": body.rotation.y, "pitch": pitch, "eye_rotation": eye.rotation, "drawn_transform": drawn.transform, "fov": drawn.fov}


# Back to the normal view: the body's heading, the eye's pitch and roll, the drawn camera hooked to the eye again with its old transform and field of view.
static func restore(saved: Dictionary, body: Node3D, eye: Node3D, drawn: Camera3D) -> void:
	body.rotation.y = float(saved["yaw"])
	eye.rotation = saved["eye_rotation"]
	drawn.top_level = false
	drawn.transform = saved["drawn_transform"]
	drawn.fov = float(saved["fov"])


# Movement keys (x: right, z: back, as the normal walk) turned by the camera's heading, not by the body.
func move_direction(input: Vector3) -> Vector3:
	return Basis(Vector3.UP, yaw) * input


# The heading (rotation_y) a character walking in `direction` should face; the current one when standing still.
func facing_for(direction: Vector3, current: float) -> float:
	if Vector2(direction.x, direction.z).length() < 0.01:
		return current

	return atan2(-direction.x, -direction.z)
