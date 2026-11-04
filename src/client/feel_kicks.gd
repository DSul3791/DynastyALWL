extends RefCounted
# The weight of first-person actions (2 Nov 2026, feel lane): a landing dips the eye and it springs back, a tool blow lands with a short jolt, and a blow throws a few chips from the spot hit.
# Pure numbers (no nodes) except `chips`, so the springs are testable. The client adds `step()`'s result to the walking camera in terrain_client.gd (_update_bob).
# How other first-person games do it: a damped spring driven by an impulse (landing: dip scales with fall speed and is capped; melee: a small, fast kick on the impact frame, not on the swing start).

const STIFFNESS := 190.0              # spring pull back to rest, per second squared
const DAMPING := 17.0                 # critically damped is about 2 x sqrt(190) = 27.6; lower lets it overshoot once, which reads as weight
const LAND_MIN_SPEED := 3.0           # m/s downward: slower than this (a step off a kerb) is no landing
const LAND_DIP_M := 0.012             # eye drop impulse per m/s of fall speed over the minimum, before the spring
const LAND_MAX_M := 0.16              # the deepest the eye may be pushed
const STRIKE_DIP_M := 0.08            # eye drop of a tool blow
const STRIKE_ROLL_DEG := 0.5

const SETTINGS_PATH := "user://input_settings.cfg"   # the same file as the input settings: [feel] intensity = 0.0 to 1.5

var intensity: float = 1.0            # scales every camera effect: 1 as tuned, 0 none (for anyone bothered by head bob or shake)
var _y: float = 0.0                   # eye offset from the walking camera (metres, negative is down)
var _vy: float = 0.0
var _roll: float = 0.0                # degrees
var _vroll: float = 0.0


# A landing at `speed` m/s downward. Returns the strength 0..1 (0 when too soft to count), for a landing puff or sound.
func land(speed: float) -> float:
	if speed < LAND_MIN_SPEED:
		return 0.0

	var depth: float = minf((speed - LAND_MIN_SPEED + 1.0) * LAND_DIP_M * 6.0, LAND_MAX_M)
	_vy -= depth * 14.0
	return clampf(depth / LAND_MAX_M, 0.0, 1.0)


# A tool blow lands; `side` is -1..1 (which way the swing came from, so the roll follows it), `weight` scales it (an axe 1, a pick 1.2).
func strike(side: float = 1.0, weight: float = 1.0) -> void:
	_vy -= STRIKE_DIP_M * 14.0 * weight
	_vroll += side * STRIKE_ROLL_DEG * 14.0 * weight


# Health lost (a bite, a blow, a fall): a jolt that grows with the loss, capped; `side` leans the roll (-1..1).
func hurt(lost: float, side: float = 1.0) -> void:
	var k: float = clampf(lost / 20.0, 0.25, 1.0)
	_vy -= 0.12 * 14.0 * k
	_vroll += side * 2.5 * 14.0 * k


# The push off the ground: a small dip as the legs load, then the spring lifts the eye as the jump leaves the ground.
func jump() -> void:
	_vy -= 0.04 * 14.0


# A tree hits the ground `distance` metres away with `size` (about 0.2 to 1.6): the ground thumps the eye, felt within 30 m and strongest close by.
func thud(distance: float, size: float) -> void:
	var strength: float = clampf(size, 0.2, 1.5) * clampf(1.0 - distance / 30.0, 0.0, 1.0)

	if strength > 0.02:
		_vy -= 0.1 * 14.0 * strength
		_vroll += 1.2 * 14.0 * strength


func _init() -> void:
	var file: ConfigFile = ConfigFile.new()

	if file.load(SETTINGS_PATH) == OK:
		intensity = clampf(float(file.get_value("feel", "intensity", 1.0)), 0.0, 1.5)


# The Camera motion slider (Esc > Settings > Gameplay): takes effect at once and is kept in the settings file for the next run.
func set_intensity(value: float, path: String = SETTINGS_PATH) -> void:
	intensity = clampf(value, 0.0, 1.5)
	var file: ConfigFile = ConfigFile.new()
	file.load(path)
	file.set_value("feel", "intensity", intensity)
	file.save(path)


func step(delta: float) -> Dictionary:
	var dt: float = minf(delta, 0.05)
	_vy += (-STIFFNESS * _y - DAMPING * _vy) * dt
	_y += _vy * dt
	_vroll += (-STIFFNESS * _roll - DAMPING * _vroll) * dt
	_roll += _vroll * dt
	_y = clampf(_y, -LAND_MAX_M, 0.05)
	return {"y": _y * intensity, "roll": _roll * intensity}


# A few chips thrown from `point` away from the surface (normal), for the hit: wood chips for wood, grit for ground and stone. Frees itself when done.
static func chips(parent: Node, point: Vector3, normal: Vector3, wood: bool) -> void:
	var burst: CPUParticles3D = CPUParticles3D.new()
	burst.one_shot = true
	burst.amount = 10
	burst.lifetime = 0.7
	burst.explosiveness = 1.0
	burst.direction = normal if normal.length() > 0.1 else Vector3.UP
	burst.spread = 55.0
	burst.initial_velocity_min = 1.2
	burst.initial_velocity_max = 3.0
	burst.gravity = Vector3(0.0, -9.0, 0.0)
	burst.local_coords = false
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.025, 0.025)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.55, 0.34) if wood else Color(0.5, 0.45, 0.4)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material
	burst.mesh = mesh
	parent.add_child(burst)
	burst.global_position = point
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
