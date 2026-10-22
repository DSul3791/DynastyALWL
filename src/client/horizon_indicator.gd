extends Control

# A small artificial horizon like an airplane's (Dave 2026-10-22): shown only underground or in water, where there is no sky to
# tell whether you are looking level, up or down. The ball is sky-coloured above the horizon line and earth-coloured below; looking
# up moves the line down, as in a cockpit. A fixed aircraft mark sits in the middle, rungs every 10 degrees. An exception to
# "no bars on the main screen", like the server link bars.

const RADIUS := 64.0
const DEGREES_SHOWN := 45.0               # pitch at which the horizon line reaches the edge of the ball
const CHECK_SEC := 0.25
const ROOF_M := 1.2                       # ground this far above the head counts as underground
const SKY := Color(0.36, 0.55, 0.78, 0.85)
const EARTH := Color(0.42, 0.29, 0.18, 0.85)
const LINE := Color(1.0, 1.0, 1.0, 0.9)

var pitch_rad: float = 0.0                # set every frame by the game: the camera's up/down angle
var _camera: Camera3D
var _in_water: Callable                   # () -> bool
var _shown_since_check: float = 0.0
var _active: bool = false


func setup(camera: Camera3D, in_water: Callable) -> void:
	_camera = camera
	_in_water = in_water
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(RADIUS * 2.0 + 8.0, RADIUS * 2.0 + 8.0)
	size = custom_minimum_size
	visible = false


func _process(delta: float) -> void:
	_shown_since_check += delta

	if _shown_since_check >= CHECK_SEC:
		_shown_since_check = 0.0
		_active = _underground() or (_in_water.is_valid() and bool(_in_water.call()))
		visible = _active

	if _active:
		queue_redraw()


# True when solid ground (not a tree or plant) lies over the head.
func _underground() -> bool:
	if _camera == null or not _camera.is_inside_tree():
		return false

	var from: Vector3 = _camera.global_position
	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var skip: Array[RID] = []

	for attempt in range(3):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 60.0)
		query.exclude = skip
		var hit: Dictionary = space.intersect_ray(query)

		if hit.is_empty():
			return false

		var collider: Object = hit["collider"]

		if collider is CollisionObject3D and not collider.has_meta("species_ids") and (hit["position"] as Vector3).y - from.y >= ROOF_M:
			return true

		if collider is CollisionObject3D:
			skip.append((collider as CollisionObject3D).get_rid())
		else:
			return false

	return false


func _draw() -> void:
	var centre: Vector2 = Vector2(size.x * 0.5, size.y * 0.5)
	var pitch_deg: float = rad_to_deg(pitch_rad)
	var offset: float = clampf(pitch_deg / DEGREES_SHOWN, -1.0, 1.0) * RADIUS   # looking up lowers the horizon line
	draw_circle(centre, RADIUS, SKY)
	var ratio: float = clampf(offset / RADIUS, -1.0, 1.0)
	var low: float = asin(ratio)
	var ground: PackedVector2Array = PackedVector2Array()
	var steps: int = 40

	for n in range(steps + 1):
		var angle: float = low + (PI - 2.0 * low) * float(n) / float(steps)
		ground.append(centre + Vector2(cos(angle), sin(angle)) * RADIUS)

	if ground.size() >= 3:
		draw_colored_polygon(ground, EARTH)

	# The horizon line and a rung every 10 degrees, clipped to the ball.
	for rung in range(-3, 4):
		var y: float = offset + float(rung) * 10.0 / DEGREES_SHOWN * RADIUS * -1.0
		var half: float = sqrt(maxf(RADIUS * RADIUS - y * y, 0.0))

		if absf(y) >= RADIUS - 2.0:
			continue

		var width: float = half if rung == 0 else minf(half, 16.0)
		draw_line(centre + Vector2(-width, y), centre + Vector2(width, y), LINE, 3.0 if rung == 0 else 2.0)

	draw_arc(centre, RADIUS, 0.0, TAU, 64, LINE, 3.0, true)
	# The aircraft mark, fixed: where you are looking.
	draw_line(centre + Vector2(-26.0, 0.0), centre + Vector2(-8.0, 0.0), Color(1.0, 0.85, 0.2), 4.0)
	draw_line(centre + Vector2(8.0, 0.0), centre + Vector2(26.0, 0.0), Color(1.0, 0.85, 0.2), 4.0)
	draw_circle(centre, 4.0, Color(1.0, 0.85, 0.2))
