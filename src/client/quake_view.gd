extends RefCounted
# What a player sees and reads while a tunnel they are in is about to fail (tech/EXCAVATION_BRACING_GROUND_DESIGN.md section 3; the
# sounds are in placed_sounds.gd). The server sends quake(stage, strength, point) twice a second to players near a working cluster;
# this turns those into camera shake that grows with the strength, falling dust, and a notice line: stage 3 "The earth groans.",
# stage 4 a warning every 5 s. When the messages stop (braced, or the window reset) the shake and dust fade out in about a second.
# Collapse itself stays off server side, so nothing here fires until it is switched on.

const SHAKE_M := 0.05                 # camera offset at full strength
const SHAKE_DEG := 1.6                # camera roll at full strength
const FADE_PER_S := 1.0
const HEARD_S := 1.2                  # a message is "current" this long
const GROAN_EVERY_S := 40.0
const THROES_EVERY_S := 5.0

var strength: float = 0.0             # the shake now, 0..1
var stage: int = 0
var _target: float = 0.0
var _heard_s: float = -100.0
var _clock_s: float = 0.0
var _groan_at: float = -100.0
var _throes_at: float = -100.0
var _dust: CPUParticles3D = null
var _client
var _noise_t: float = 0.0
var notices: Array = []               # what was said, for tests


func setup(client, camera: Camera3D) -> void:
	_client = client
	_dust = CPUParticles3D.new()
	_dust.emitting = false
	_dust.amount = 80
	_dust.lifetime = 2.0
	_dust.local_coords = false
	_dust.direction = Vector3.DOWN
	_dust.spread = 12.0
	_dust.initial_velocity_min = 0.2
	_dust.initial_velocity_max = 0.6
	_dust.gravity = Vector3(0.0, -0.8, 0.0)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(1.6, 0.1, 1.6)
	_dust.position = Vector3(0.0, 1.4, -0.5)
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.03, 0.03)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.38, 0.3, 0.7)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	_dust.mesh = mesh
	camera.add_child(_dust)


# From the server's quake message.
func on_quake(new_stage: int, new_strength: float) -> void:
	stage = new_stage
	_target = clampf(new_strength, 0.0, 1.0) if new_stage >= 3 else 0.0
	_heard_s = _clock_s

	if new_stage >= 3 and _clock_s - _groan_at >= GROAN_EVERY_S:
		_groan_at = _clock_s
		_say("The earth groans.")

	if new_stage >= 4 and _clock_s - _throes_at >= THROES_EVERY_S:
		_throes_at = _clock_s
		_say("The roof is giving way. Get out now!")


# Every frame. Returns the camera offset to add to its position and the roll to add (degrees).
func step(delta: float) -> Dictionary:
	_clock_s += delta

	if _clock_s - _heard_s > HEARD_S:
		_target = 0.0
		stage = 0

	strength = move_toward(strength, _target, FADE_PER_S * delta * (4.0 if _target > strength else 1.0))

	if _dust != null:
		_dust.emitting = strength > 0.05

	if strength <= 0.001:
		return {"offset": Vector3.ZERO, "roll": 0.0}

	_noise_t += delta * 37.0
	var a: float = sin(_noise_t) * cos(_noise_t * 0.63 + 1.0)
	var b: float = sin(_noise_t * 1.31 + 2.0)
	return {"offset": Vector3(a, b, 0.0) * SHAKE_M * strength, "roll": a * SHAKE_DEG * strength}


func _say(text: String) -> void:
	notices.append(text)

	if _client != null and _client.items != null:
		_client.items.show_notice(text)
