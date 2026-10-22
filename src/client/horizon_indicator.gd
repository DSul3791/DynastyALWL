extends Control

# A look-angle ruler at the crosshair (Dave 2026-10-22): shown only underground or in water, where there is no sky to tell whether
# you are looking level, up or down. A vertical line beside the centre of the screen with a tick every 5 degrees from -45 to +45
# (up is the top), a longer tick and a number every 15, and a marker that rides the line at the angle you are looking. An exception
# to "no bars on the main screen", like the server link bars.

const DEGREES := 45                       # the ruler runs from -DEGREES to +DEGREES
const TICKS := 9                          # ticks each side of zero (every 5 degrees)
const PX_PER_DEGREE := 4.0
const SIDE := 40.0                        # the ruler stands this far right of the aim point
const CHECK_SEC := 0.25
const PIT_M := 1.5                      # ground this much above the eyes all around: in a pit
const PIT_RING_M := 3.0
const ROOF_M := 1.2                       # ground this far above the head counts as underground
const LINE := Color(1.0, 1.0, 1.0, 0.8)
const MARK := Color(1.0, 0.85, 0.2, 0.95)

var pitch_rad: float = 0.0                # set every frame by the game: the camera's up/down angle
var _camera: Camera3D
var _in_water: Callable                   # () -> bool
var _shown_since_check: float = 0.0
var _active: bool = false


func setup(camera: Camera3D, in_water: Callable) -> void:
	_camera = camera
	_in_water = in_water
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(160.0, float(DEGREES) * 2.0 * PX_PER_DEGREE + 40.0)
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -size.x * 0.5 + SIDE + 40.0
	offset_right = offset_left + size.x
	offset_top = -size.y * 0.5
	offset_bottom = offset_top + size.y
	visible = false


func _process(delta: float) -> void:
	_shown_since_check += delta

	if _shown_since_check >= CHECK_SEC:
		_shown_since_check = 0.0
		_active = _underground() or (_in_water.is_valid() and bool(_in_water.call()))
		visible = _active

	if _active:
		queue_redraw()


# True when solid ground (not a tree or plant) lies over the head, or the player is down in a pit or shaft that is open to the sky:
# most of the ground 3 m around is at least PIT_M higher than the eyes.
func _underground() -> bool:
	if _camera == null or not _camera.is_inside_tree():
		return false

	var from: Vector3 = _camera.global_position
	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var higher: int = 0

	for k in range(8):
		var around: Vector3 = from + Vector3(cos(TAU * k / 8.0), 0.0, sin(TAU * k / 8.0)) * PIT_RING_M
		var down: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(around + Vector3.UP * 60.0, around + Vector3.DOWN * 4.0))

		if not down.is_empty() and not (down["collider"] as Object).has_meta("species_ids") and (down["position"] as Vector3).y >= from.y + PIT_M:
			higher += 1

	if higher >= 5:
		return true

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
	var middle: Vector2 = Vector2(SIDE, size.y * 0.5)
	var font: Font = ThemeDB.fallback_font
	draw_line(middle + Vector2(0.0, -float(DEGREES) * PX_PER_DEGREE), middle + Vector2(0.0, float(DEGREES) * PX_PER_DEGREE), LINE, 2.0)

	for step in range(-TICKS, TICKS + 1):
		var degrees: int = step * 5
		var y: float = middle.y - float(degrees) * PX_PER_DEGREE
		var long: bool = degrees % 15 == 0
		draw_line(Vector2(middle.x, y), Vector2(middle.x + (18.0 if long else 9.0), y), LINE, 3.0 if degrees == 0 else 2.0)

		if long:
			draw_string(font, Vector2(middle.x + 24.0, y + 7.0), ("%+d" % degrees) if degrees != 0 else "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, LINE)

	# The marker: a triangle pointing at the ruler at the angle the camera looks.
	var at: float = clampf(rad_to_deg(pitch_rad), -float(DEGREES), float(DEGREES))
	var y_mark: float = middle.y - at * PX_PER_DEGREE
	draw_colored_polygon(PackedVector2Array([Vector2(middle.x - 4.0, y_mark), Vector2(middle.x - 22.0, y_mark - 9.0), Vector2(middle.x - 22.0, y_mark + 9.0)]), MARK)
