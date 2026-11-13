extends Node3D

# Far campfire smoke (TEST-011, Dave approved 13 Nov 2026: smoke seen up to 2 km so a camp can be found from a hill). The server sends the lit
# campfires past world_items' 100 m (terrain_net far_fires, protocol 114); each gets the tall smoke column only (BuildingLook's, so the same
# wind, rise and fade), no fire, light or sparks. Only those within the terrain's view distance (view_m), and only the "tall" far_max_fires
# nearest the camera, are drawn; fog and haze dim them as they do the ground.

const BuildingLook := preload("res://src/client/building_look.gd")

var view_m: Callable    # () -> float: how far the terrain is drawn (terrain_client: terrain.view_distance); unset = all that come
var _plumes: Dictionary = {}   # Vector3i (the fire's position to the decimetre) -> GPUParticles3D


static func key_of(pos: Vector3) -> Vector3i:
	return Vector3i(roundi(pos.x * 10.0), roundi(pos.y * 10.0), roundi(pos.z * 10.0))


# terrain_net.far_fires_received: the whole set, nearest first. Fires gone from it lose their plume; new ones get one.
func on_far_fires(points: PackedVector3Array, tiers: PackedByteArray) -> void:
	var keep: Dictionary = {}

	for i in range(points.size()):
		var key: Vector3i = key_of(points[i])
		var tier: int = clampi(int(tiers[i]) if i < tiers.size() else 2, 1, 3)
		keep[key] = true

		if _plumes.has(key) and int((_plumes[key] as Node).get_meta("tier", 0)) != tier:
			(_plumes[key] as Node).queue_free()
			_plumes.erase(key)

		if not _plumes.has(key):
			var plume: GPUParticles3D = BuildingLook.far_smoke_plume(tier)
			plume.set_meta("tier", tier)
			add_child(plume)
			plume.global_position = points[i] + Vector3(0.0, 0.5, 0.0)
			_plumes[key] = plume

	for key in _plumes.keys():
		if not keep.has(key):
			(_plumes[key] as Node).queue_free()
			_plumes.erase(key)

	refresh()


# The nearest far_max_fires within view_m draw; the rest are hidden (not simulated) and start again warm when they come back.
func refresh() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null

	if camera == null:
		return

	var eye: Vector3 = camera.global_position
	var reach: float = float(view_m.call()) if view_m.is_valid() else INF
	var ranked: Array = []

	for key in _plumes:
		var plume: GPUParticles3D = _plumes[key]
		var d: float = Vector2(plume.global_position.x - eye.x, plume.global_position.z - eye.z).length()

		if d <= reach:
			ranked.append([d, plume])
		elif plume.visible:
			plume.visible = false

	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var cap: int = int(BuildingLook.tall_tier("far_max_fires", 1))

	for i in range(ranked.size()):
		var plume: GPUParticles3D = ranked[i][1]
		var on: bool = i < cap

		if on != plume.visible:
			plume.visible = on

			if on:
				plume.restart()


func plume_count() -> int:
	return _plumes.size()


func shown_count() -> int:
	var shown: int = 0

	for key in _plumes:
		shown += 1 if (_plumes[key] as GPUParticles3D).visible else 0

	return shown


var _refresh_in: float = 1.0


func _process(delta: float) -> void:
	_refresh_in -= delta

	if _refresh_in <= 0.0:
		_refresh_in = 1.0
		refresh()   # the player walks: the nearest few change
