extends Node

# What the player holds (hotbar keys 1 to 9 and 0 choose pack slots 0 to 9; the key again puts it away) and how it is used.
# Client only; the server decides what happens (throws are server actions).
#
# Spear (Dave, 2026-10-20): held and jabbed by default with the normal attack key (left click).
# Hold right click to aim a throw; then left click throws. Letting go of right click returns to
# the normal stance. The weapon is drawn as a simple first-person model until real art exists.

const Net := preload("res://src/stream/terrain_net.gd")
const BuildingLook := preload("res://src/client/building_look.gd")
const PlacementRules := preload("res://src/shared/placement_rules.gd")
const RagdollScript := preload("res://src/client/ragdoll_body.gd")

const HOTBAR_FILE := "user://hotbar.txt"      # the chosen hotbar slot is remembered between sessions
const REST := Vector3(0.38, -0.32, -0.55)       # model offset from the camera
const AIMED := Vector3(0.28, -0.12, -0.35)
# First-person arms (Art's ragdoll rig, assets/character/README.md): rooted at the chest a little below and behind the camera,
# pitched forward so a tool in the hand points ahead instead of hanging down. The tool goes to the hand on the viewer's right
# (the rig's hand_mount_r: the rig's right is +X, see assets/character/README.md), grip at the mount origin, its business end tipped
# up TOOL_TILT_DEG from the fingers. Rendered with software Vulkan and looked at (still frames of idle, jab, swing).
const ARMS_POS := Vector3(0.0, -0.1, -0.15)
const ARMS_PITCH_DEG := 50.0
const TOOL_TILT_DEG := 20.0
# Dave 2026-10-21: at rest the arms hang at the character's side, below the bottom of the screen, and the tool sits in the hand there,
# fixed to the body (the way you face, not the way you look): look down and you see it. Swinging, jabbing, using or aiming brings the
# arms up to the camera pose above and back. REST_* is the body pose: where the chest is under the eye and how far forward the arms hang.
const REST_DOWN_M := 0.3
const REST_BACK_M := 0.05
const REST_PITCH_DEG := 8.0
const ARMS_FOLLOW_K := 9.0
const SHOULDER_LOG_FWD := 0.45            # metres ahead of the eye: the log's middle sits over the shoulder, not behind it (Dave 2026-10-23)
const SHOULDER_LOG_X := 0.5               # first person: the log's side of the body, metres right of the eye
const GRIP_ALONG_Y := {"axe": 0.25, "torch": 0.25, "knife": 0.05, "other": 0.3, "kit": 0.0}   # model +Y runs handle to head: the grip's distance from the model origin
const SPEAR_GRIP_Z := 0.3
const JAB_REACH := 0.7
const JAB_S := 0.28
const THROW_SPEED := 24.0
const THROW_GRAVITY := 9.8

var held_slot: int = 0
var holding: bool = true                  # false after the held slot's key is pressed again: hands empty
const HOTBAR_SLOTS := 10
var aiming: bool = false

var _inv                                  # InventoryView
var _net
var _camera: Camera3D
var _root: Node3D
var _ground_below: Callable
var held_light_budget: Callable          # () -> true when the held light may be on beside a nearby fire light (not at Low)
var _model: Node3D
var _arms                                 # first-person arms (Ragdoll.new(true)) on the camera; the held tool sits in its right hand
var _stop_t: float = 0.0                  # hit stop left, seconds
var _shoulder_log: MeshInstance3D          # the log across the shoulder (set_shoulder)
var _arm_up: float = 0.0                  # 0 arms hang at the body's side, 1 raised to the camera pose (swing, jab, use, aim)
var water_depth_at: Callable = Callable()   # (x, z) -> metres of standing water there; set by the client scene, unset in tests
var _blueprint_yaw: int = 0               # the turn (degrees) the ghost will be placed at
var _first_person: bool = true
var _avatar_rig                          # the full body (ragdoll_body.gd) drawn in third person, or null
var _mounted: bool = false                # the model is in the hand: the arm animations move it, not the offsets below
var _label: Label
var _jab_t: float = -1.0
var _flights: Array = []                  # local visuals of spears this player threw: {node, vel, age}
var _shown_number: int = 0
var _sound                                # SoundStage (hit sounds)
var _tree_near: Callable                  # (point) -> [chunk, id] of the tree trunk standing there, or []
var _swing_t: float = -1.0
var _swing_hit: bool = false
var _cover_at: Callable                   # (point) -> true when under a tree's crown
var _blueprint: Node3D
var _blueprint_kit: String = ""
var _ghost_material: StandardMaterial3D
var _blueprint_at: Vector3 = Vector3.ZERO
var _blueprint_ok: bool = false
var _placement: Dictionary = {}              # structures.json: footprints, gaps, caps (shared with the server's rules)
var blueprint_state: String = ""            # what the ghost shows now: "open", "covered", "close", "crowded" or "steep" (tests read it)
var _blueprint_shape: Vector2 = Vector2(-1.0, -1.0)
var _blueprint_next_msec: int = 0

const SWING_S := 0.55
const HIT_STOP_S := 0.045
const HIT_AT := 0.636                      # share of the swing where the tool reaches the target (the swing_fp clip's impact key, 0.35 s of 0.55); the thump and the server's hit are this same tick
const REACH_M := 3.0


const FrameProbe := preload("res://src/debug/frame_probe.gd")

func setup(inventory_view, terrain_net, camera: Camera3D, world_root: Node3D, hud_layer: CanvasLayer, ground_below: Callable, sound_stage = null, tree_near: Callable = Callable(), cover_at: Callable = Callable()) -> void:
	_cover_at = cover_at
	_sound = sound_stage
	_placement = PlacementRules.load_config()

	if FileAccess.file_exists(HOTBAR_FILE):
		held_slot = clampi(int(FileAccess.get_file_as_string(HOTBAR_FILE)), 0, HOTBAR_SLOTS - 1)

	_tree_near = tree_near
	_inv = inventory_view
	_net = terrain_net
	_camera = camera
	_root = world_root
	_ground_below = ground_below
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.offset_bottom = -60.0
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(_label)
	_arms = RagdollScript.new(true)
	_arms.name = "Arms"
	_arms.position = ARMS_POS
	_arms.rotation_degrees.x = ARMS_PITCH_DEG
	camera.add_child(_arms)
	_arms.play("idle")


# First person shows the arms; third person (the body is drawn instead) hides them and stops their animation.
func set_first_person(on: bool) -> void:
	if _arms != null and _arms.visible != on:
		_arms.visible = on
		_arms.animation_player.active = on

	if _first_person != on:
		_first_person = on

		# The held model moves between the first-person hand and the body's own hand (Dave 2026-10-22: the torch vanished in third person).
		if _model != null and _model.get_parent() != null:
			_model.get_parent().remove_child(_model)
			_mount_model()


# The player's full body (third person), whose right hand carries the held model when the camera is out.
func set_avatar(avatar) -> void:
	_avatar_rig = avatar


func _arm_play(clip: String, seconds: float) -> void:
	if _arms != null and _arms.visible:
		var length: float = _arms.animation_player.get_animation(clip).length
		_arms.play(clip, length / maxf(seconds, 0.05))


# A hotbar key: hold that slot, or put it away when it is the one already held.
func press_slot(slot: int) -> void:
	if holding and slot == held_slot:
		holding = false
		aiming = false
		_inv.refresh_hotbar()

		if _sound != null:
			_sound.itemfx.hotbar(held_slot)

		return

	select(slot)


# Use on a tool in the inventory: hold it, or put it away if it is already in hand.
func equip_toggle(slot: int) -> void:
	press_slot(clampi(slot, 0, HOTBAR_SLOTS - 1))


func select(slot: int) -> void:
	if _sound != null and (clampi(slot, 0, HOTBAR_SLOTS - 1) != held_slot or not holding):
		_sound.itemfx.hotbar(clampi(slot, 0, HOTBAR_SLOTS - 1))

	held_slot = clampi(slot, 0, HOTBAR_SLOTS - 1)
	holding = true
	aiming = false
	_inv.refresh_hotbar()
	var number: int = _inv.inventory.numbers[held_slot]

	if number != 0 and not is_holdable(number):
		_inv._on_notice("%s cannot be held in the hand (Use or Eat it from the inventory)" % _inv.table.name_of(number))

	var file: FileAccess = FileAccess.open(HOTBAR_FILE, FileAccess.WRITE)

	if file != null:
		file.store_string(str(held_slot))


func held_number() -> int:
	return _inv.inventory.numbers[held_slot] if holding else 0


func held_id() -> String:
	return _inv.table.id_of(held_number())


func _is_spear() -> bool:
	return str(_inv.table.entry(held_id()).get("weapon_class", "")) == "spear"


func _is_placeable() -> bool:
	return str(_inv.table.entry(held_id()).get("kind", "")) == "placeable"


func _is_torch() -> bool:
	return str(_inv.table.entry(held_id()).get("tool_class", "")) == "torch"


func _is_knife() -> bool:
	return str(_inv.table.entry(held_id()).get("tool_class", "")) == "knife"


# Any other tool or weapon (spade, and every tool added later) is held too: it has a generic model and plays the "use" arm
# animation on left click, so nothing silently fails to be held.
func _is_other_tool() -> bool:
	var kind: String = str(_inv.table.entry(held_id()).get("kind", ""))
	return kind in ["tool", "weapon", "container"] and not _is_spear() and not _is_torch() and not _is_knife() and not _is_axe()


func is_holdable(number: int) -> bool:
	if number == 0:
		return false

	var entry: Dictionary = _inv.table.entry(_inv.table.id_of(number))
	return str(entry.get("kind", "")) in ["tool", "weapon", "placeable", "container"] or _inv.edible_slot(held_slot)


func _is_axe() -> bool:
	return str(_inv.table.entry(held_id()).get("tool_class", "")) in ["axe", "pick"] and not _inv.is_broken(held_slot)


# One chop of an axe or pick. Holding the left button chains them (see _process): the next starts as the last one ends.
func _start_swing() -> void:
	_swing_t = 0.0
	_swing_hit = false
	_arm_play("swing_fp", SWING_S)



# A mouse button while playing. Returns true when it was used here.
func mouse_button(button: int, pressed: bool) -> bool:
	if button == MOUSE_BUTTON_RIGHT and pressed and holding and _inv.edible_slot(held_slot):
		_inv.eat_slot(held_slot)
		return true

	if _is_placeable():
		if button == MOUSE_BUTTON_LEFT and pressed and _blueprint_ok:
			_net.inventory_action.rpc_id(1, Net.ACT_PLACE, held_slot, 0, _blueprint_yaw, _blueprint_at)

		return button == MOUSE_BUTTON_LEFT

	if _is_axe():
		if button == MOUSE_BUTTON_RIGHT and pressed:
			_net.inventory_action.rpc_id(1, Net.ACT_ICEHOLE, held_slot, 0, 0, Vector3.ZERO)
			_arm_play("use", 0.6)
			return true

		if button == MOUSE_BUTTON_LEFT and pressed and _swing_t < 0.0:
			_start_swing()

		return button == MOUSE_BUTTON_LEFT

	if _is_other_tool():
		# Right click with the spade switches between Dig and Raise mode (Dave 2026-10-22).
		if button == MOUSE_BUTTON_RIGHT and pressed and str(_inv.table.entry(held_id()).get("tool_class", "")) == "spade":
			raise_mode = not raise_mode
			_inv._on_notice("Raise mode: left click adds ground, using soil or stone from your pack" if raise_mode else "Dig mode: left click digs")
			return true

		# The garden hoe: left click treads a path, right click smooths the ground (it moves dirt from the high spots to the low ones; no items).
		if pressed and (button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT) and str(_inv.table.entry(held_id()).get("tool_class", "")) == "hoe":
			_arm_play("use", 0.6)
			_hoe_here(Net.ACT_HOE_PATH if button == MOUSE_BUTTON_LEFT else Net.ACT_HOE_SMOOTH)
			return true

		if button == MOUSE_BUTTON_LEFT and pressed:
			_arm_play("use", 0.6)

			if str(_inv.table.entry(held_id()).get("tool_class", "")) == "spade":
				if raise_mode:
					_fill_here()
				else:
					_dig_here()
			elif str(_inv.table.entry(held_id()).get("tool_class", "")) == "rod":
				_net.inventory_action.rpc_id(1, Net.ACT_FISH, held_slot, 0, 0, _camera.global_position - _camera.global_transform.basis.z * 4.0)
			else:
				_inv._on_notice(_other_tool_hint())

		return button == MOUSE_BUTTON_LEFT

	if _is_knife():
		if button == MOUSE_BUTTON_LEFT and pressed:
			var carcass: int = _inv.carcass_near(_camera.global_position)

			if carcass != 0:
				_arm_play("use", 0.6)
				_net.inventory_action.rpc_id(1, Net.ACT_PROCESS, carcass, 0, 0, Vector3.ZERO)
				return true

		return false

	if not _is_spear():
		aiming = false
		return false

	if button == MOUSE_BUTTON_RIGHT:
		aiming = pressed
		return true

	if button == MOUSE_BUTTON_LEFT and pressed:
		if aiming:
			_throw()
		elif _jab_t < 0.0:
			_jab_t = 0.0
			_arm_play("jab", JAB_S)
			_net.inventory_action.rpc_id(1, Net.ACT_FISH, held_slot, 0, 0, _camera.global_position - _camera.global_transform.basis.z * 2.5 - Vector3(0.0, 1.2, 0.0))
			_net.inventory_action.rpc_id(1, Net.ACT_STRIKE, held_slot, 0, 0, -_camera.global_transform.basis.z)

			if _sound != null:
				_sound.spear.jab(_camera.global_position - _camera.global_transform.basis.z)

		return true

	return false


func _throw() -> void:
	_arm_play("throw", 0.8)
	var direction: Vector3 = -_camera.global_transform.basis.z
	_net.inventory_action.rpc_id(1, Net.ACT_THROW, held_slot, 0, 0, direction)
	aiming = false
	var node: Node3D = _make_spear_model()
	_root.add_child(node)
	node.global_position = _camera.global_position + direction * 0.8
	node.look_at(node.global_position + direction, Vector3.UP)
	_flights.append({"node": node, "vel": direction * THROW_SPEED, "age": 0.0})

	if _sound != null:
		var landing: Vector3 = _predict_landing(node.global_position, direction * THROW_SPEED)
		var material: String = "wood" if _tree_near.is_valid() and _tree_near.call(landing) else "soil"
		_sound.spear.throw(node.global_position, landing, THROW_SPEED, material)


# Where a thrown spear comes down: the same flight as _process steps it (gravity, ground below), for the sound.
func _predict_landing(from: Vector3, velocity: Vector3) -> Vector3:
	var at: Vector3 = from
	var v: Vector3 = velocity
	var t: float = 0.0

	while t < 6.0:
		v.y -= THROW_GRAVITY * 0.05
		at += v * 0.05
		t += 0.05
		var ground: float = _ground_below.call(at)

		if not is_nan(ground) and at.y <= ground:
			break

	return at


func _process(delta: float) -> void:
	var t: int = FrameProbe.start()
	_process_body(delta)
	FrameProbe.stop("held item", t)


func _process_body(delta: float) -> void:
	_update_blueprint()
	_hoe_repeat(delta)

	if _sound != null:
		var flame_kind: String = str(_inv.table.entry(held_id()).get("tool_class", ""))
		var sheltered: bool = _cover_at.is_valid() and bool(_cover_at.call(_camera.global_position))
		_sound.flame.set_held(flame_kind if flame_kind in ["torch", "lantern"] else "", not sheltered)

	_show_model()
	_label.text = _caption()
	if _inv != null:
		_label.offset_bottom = -float(_inv.text_px(78 + 14 + 8))    # above the hotbar at any text size (Dave, build 617: they overlapped)
	_place_arms(delta)

	if _arms != null and _arms.visible and _arms.current() != "idle" and not _arms.is_one_shot_playing():
		_arms.play("idle")

	# Hit stop: the animation freezes for a moment at the impact (Tyler Report 26), then goes on.
	if _stop_t > 0.0:
		_stop_t -= delta

		if _stop_t <= 0.0 and _arms != null:
			_arms.animation_player.speed_scale = 1.0

	if _swing_t >= 0.0 and _stop_t <= 0.0:
		_swing_t += delta

		if not _swing_hit and _swing_t >= SWING_S * HIT_AT:
			_swing_hit = true
			_strike()
			_stop_t = HIT_STOP_S

			if _arms != null and _arms.visible:
				_arms.animation_player.speed_scale = 0.0

		if _swing_t >= SWING_S:
			_swing_t = -1.0

			# Dave 2026-10-21: holding the button keeps chopping, one swing after another (no gap, no clicking).
			if holding and _is_axe() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_start_swing()

	if _model != null and _is_torch():
		var flicker: OmniLight3D = _model.get_node_or_null("Light")

		if flicker != null:
			# Own light: one, shadowless. At Low it gives way to a fire light within 8 m, so no more than one lamp lights the same spot.
			flicker.visible = not held_light_budget.is_valid() or held_light_budget.call() or not _inv.fire_light_near(_camera.global_position, 8.0)
			flicker.light_energy = 1.4 + 0.3 * sin(float(Time.get_ticks_msec()) * 0.017)

		if not _mounted:
			_model.position = _model.position.lerp(REST, clampf(delta * 14.0, 0.0, 1.0))
	elif _model != null and _mounted:
		pass   # in the hand: the arm animation moves it
	elif _model != null and _is_knife():
		_model.position = _model.position.lerp(REST, clampf(delta * 14.0, 0.0, 1.0))
	elif _model != null and _is_axe():
		var u: float = clampf(_swing_t / SWING_S, 0.0, 1.0) if _swing_t >= 0.0 else 0.0
		var arc: float = sin(u * PI)
		_model.position = _model.position.lerp(REST + Vector3(-0.1 * arc, -0.15 * arc, -0.2 * arc), clampf(delta * 20.0, 0.0, 1.0))
		_model.rotation.x = lerpf(_model.rotation.x, deg_to_rad(70.0) * (1.0 - 2.0 * u) if _swing_t >= 0.0 else deg_to_rad(20.0), clampf(delta * 20.0, 0.0, 1.0))
	elif _model != null:
		var target: Vector3 = AIMED if aiming else REST
		var offset: Vector3 = target

		if _jab_t >= 0.0:
			_jab_t += delta
			var u: float = clampf(_jab_t / JAB_S, 0.0, 1.0)
			offset += Vector3(0.0, 0.0, -JAB_REACH * sin(u * PI))

			if _jab_t >= JAB_S:
				_jab_t = -1.0

		_model.position = _model.position.lerp(offset, clampf(delta * 14.0, 0.0, 1.0))
		_model.rotation.x = lerpf(_model.rotation.x, deg_to_rad(35.0) if aiming else 0.0, clampf(delta * 14.0, 0.0, 1.0))

	for flight in _flights.duplicate():
		flight["vel"].y -= THROW_GRAVITY * delta
		flight["node"].global_position += flight["vel"] * delta
		flight["age"] += delta
		var ground: float = _ground_below.call(flight["node"].global_position)

		if flight["age"] > 6.0 or (not is_nan(ground) and flight["node"].global_position.y <= ground):
			flight["node"].queue_free()
			_flights.erase(flight)


# The large log on the shoulder in first person (Dave 2026-10-21): across the right shoulder, fixed to the body (the way you face), so it
# shows at the edge of the view and when you look down.
func set_shoulder(on: bool, length: float, radius: float) -> void:
	if not on:
		if _shoulder_log != null:
			_shoulder_log.visible = false

		return

	if _shoulder_log == null:
		_shoulder_log = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.radial_segments = 12
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.32, 0.23, 0.15)
		cyl.material = material
		_shoulder_log.mesh = cyl
		_shoulder_log.top_level = true
		_shoulder_log.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_camera.add_child(_shoulder_log)

	var mesh: CylinderMesh = _shoulder_log.mesh as CylinderMesh
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = length
	_shoulder_log.visible = true
	var yaw: Basis = Basis(Vector3.UP, _camera.global_rotation.y)
	var at: Vector3 = _camera.global_position + yaw * Vector3(SHOULDER_LOG_X, -0.55, -SHOULDER_LOG_FWD)
	_shoulder_log.global_transform = Transform3D(yaw * Basis(Vector3.RIGHT, PI * 0.5 + 0.05), at)


# The arms follow the body at rest and the camera while working: blends the two poses by _arm_up.
func _place_arms(delta: float) -> void:
	if _arms == null or not _arms.visible:
		return

	var working: bool = _swing_t >= 0.0 or _jab_t >= 0.0 or aiming or _arms.is_one_shot_playing()
	_arm_up = lerpf(_arm_up, 1.0 if working else 0.0, 1.0 - exp(-ARMS_FOLLOW_K * delta))
	var eye: Transform3D = _camera.global_transform
	var yaw: Basis = Basis(Vector3.UP, _camera.global_rotation.y)
	var body_pose: Transform3D = Transform3D(yaw * Basis(Vector3.RIGHT, deg_to_rad(REST_PITCH_DEG)), eye.origin + Vector3(0.0, -REST_DOWN_M, 0.0) + yaw * Vector3(0.0, 0.0, REST_BACK_M))
	var side: Transform3D = eye.affine_inverse() * body_pose
	var up_pos: Vector3 = ARMS_POS
	var up_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(ARMS_PITCH_DEG))
	_arms.transform = Transform3D(Basis(side.basis.get_rotation_quaternion().slerp(up_basis.get_rotation_quaternion(), _arm_up)), side.origin.lerp(up_pos, _arm_up))


# Makes a world model a ghost: solid bodies, lights, particles and sounds go, every mesh takes the one see-through material.
func _ghost_clean(node: Node) -> void:
	for child in node.get_children():
		if child is StaticBody3D or child is Light3D or child is GPUParticles3D or child is AudioStreamPlayer3D or child is CPUParticles3D:
			node.remove_child(child)
			child.queue_free()
			continue

		if child is MeshInstance3D:
			child.material_override = _ghost_material
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		_ghost_clean(child)


# The placement ghost for a held campfire: a ring on the ground where it would go, yellow in the open
# and green under a tree's crown (Dave, 2026-10-20: fires under cover survive rain, open ones go out).
func _update_blueprint() -> void:
	if not _is_placeable():
		if _blueprint != null:
			_blueprint.visible = false

		_blueprint_ok = false
		return

	var now: int = Time.get_ticks_msec()

	if now < _blueprint_next_msec:
		return

	_blueprint_next_msec = now + 100

	# The ghost is the placeable's own model, see-through and tinted: green where it can go, red where it cannot (Dave 2026-10-22).
	var footprint: Vector2 = PlacementRules.footprint(_placement, held_id())

	if _blueprint == null or _blueprint_kit != held_id():
		if _blueprint == null:
			_blueprint = Node3D.new()
			_root.add_child(_blueprint)
			_ghost_material = StandardMaterial3D.new()
			_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED

		_blueprint_kit = held_id()

		for child in _blueprint.get_children():
			child.queue_free()

		var def: Dictionary = PlacementRules.structure_of_kit(_placement, held_id())
		var model: Node3D = _inv.ghost_model(int(def.get("state", 1)))
		_ghost_clean(model)
		_blueprint.add_child(model)
		_blueprint_shape = footprint

	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * 5.0)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	_blueprint.visible = not hit.is_empty()
	_blueprint_ok = not hit.is_empty()

	if hit.is_empty():
		return

	var on_grid: Array = PlacementRules.snap(_placement, held_id(), hit["position"], posmod(int(round(rad_to_deg(_camera.global_rotation.y))), 360), _inv.foundation_rows())
	_blueprint_at = on_grid[0]
	_blueprint_yaw = int(on_grid[1])
	_blueprint.global_position = _blueprint_at
	_blueprint.rotation.y = deg_to_rad(float(_blueprint_yaw)) if PlacementRules.structure_of_kit(_placement, held_id()).get("piece", false) else _camera.global_rotation.y
	var on_base: bool = bool(on_grid[2])
	blueprint_state = PlacementRules.blocked(_placement, held_id(), _blueprint_at, _inv.placed_rows())

	if blueprint_state == "" and not on_base:
		var ground_at: Vector3 = _blueprint_at
		var probe: Callable = func(x: float, z: float) -> float:
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, ground_at.y + 3.0, z), Vector3(x, ground_at.y - 3.0, z))
			var found: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(ray)
			return float(found["position"].y) if not found.is_empty() else NAN
		blueprint_state = PlacementRules.steep(_placement, held_id(), _blueprint_at, _camera.global_rotation.y, probe)

	if blueprint_state == "" and not on_base and water_depth_at.is_valid() and PlacementRules.over_water(_placement, held_id(), _blueprint_at, deg_to_rad(float(_blueprint_yaw)), water_depth_at):
		blueprint_state = "water"

	if blueprint_state == "":
		var covered: bool = footprint != Vector2.ZERO or (_cover_at.is_valid() and _cover_at.call(_blueprint_at))
		blueprint_state = "covered" if covered else "open"

	var blocked: bool = blueprint_state == "close" or blueprint_state == "crowded" or blueprint_state == "steep" or blueprint_state == "water"
	_blueprint_ok = _blueprint_ok and not blocked
	_ghost_material.albedo_color = Color(0.9, 0.2, 0.2, 0.5) if blocked else Color(0.3, 0.9, 0.3, 0.5)


# The blow lands: what is in reach decides the sound. (Chopping trees and digging stone come with
# tree-fall and the harvest of ground; for now the axe only swings and sounds.)
func _strike() -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or _sound == null:
		return

	var tree: Array = _tree_near.call(hit["position"]) if _tree_near.is_valid() else []
	var trunk_id: int = _inv.felled_trunk_near(hit["position"])
	var boulder_id: int = _inv.boulder_near(hit["position"])
	var log_id: int = _inv.loose_log_near(hit["position"])

	if log_id != 0:
		_sound.hits.hit("axe", "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_PROCESS, log_id, 0, 0, Vector3.ZERO)
	elif boulder_id != 0:
		_sound.hits.hit_ground("pick", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_HIT, boulder_id, Net.HIT_BOULDER, 0, Vector3.ZERO)
	elif trunk_id != 0:
		_sound.hits.hit("axe", "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_PROCESS, trunk_id, 0, 0, Vector3.ZERO)
	elif not tree.is_empty():
		_sound.hits.hit("axe", "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_HIT, tree[1], tree[0].x, tree[0].y, Vector3.ZERO)
	else:
		_sound.hits.hit_ground("pick", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_MINE, 0, 0, 0, hit["position"])


# A spade swing at the ground under the crosshair: the server checks the spade and the reach, cuts the hole and tells
# everyone (the hole, the sound and the vanishing grass happen when it answers; DIGGING_DESIGN.md).
func _dig_here() -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit["collider"].has_meta("species_ids"):
		_inv._on_notice("Nothing to dig there: aim the spade at the ground within reach")
		return

	_net.inventory_action.rpc_id(1, Net.ACT_DIG, held_slot, 0, 0, hit["position"])


# Holding a mouse button with the hoe repeats the stroke every HOE_REPEAT_S (the server paces it at 0.5 s too), so a road is one drag.
const HOE_REPEAT_S := 0.55
var _hoe_t: float = 0.0


func _hoe_repeat(delta: float) -> void:
	if _inv == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or held_number() == 0 or str(_inv.table.entry(held_id()).get("tool_class", "")) != "hoe":
		_hoe_t = 0.0
		return

	var left: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if not left and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_hoe_t = 0.0
		return

	_hoe_t += delta

	if _hoe_t >= HOE_REPEAT_S:
		_hoe_t = 0.0
		_arm_play("use", 0.6)
		_hoe_here(Net.ACT_HOE_PATH if left else Net.ACT_HOE_SMOOTH)


# A hoe stroke (path or smooth) at the ground under the crosshair; the server checks the hoe, the reach and the pace.
func _hoe_here(action: int) -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit["collider"].has_meta("species_ids"):
		_inv._on_notice("Nothing to work there: aim the hoe at the ground within reach")
		return

	_net.inventory_action.rpc_id(1, action, held_slot, 0, 0, hit["position"])


# A spade fill at the ground under the crosshair (right click): the server spends a shovelful and puts the ground back.
func _fill_here() -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit["collider"].has_meta("species_ids"):
		_inv._on_notice("Nothing to fill there: aim the spade at the ground within reach")
		return

	_net.inventory_action.rpc_id(1, Net.ACT_FILL, held_slot, 0, 0, hit["position"])


var raise_mode: bool = false              # the spade raises ground (Dave 2026-10-22); false digs


func _other_tool_hint() -> String:
	match str(_inv.table.entry(held_id()).get("tool_class", "")):
		"rod":
			return "Click at the water to cast, and click again when something bites"
		"hoe":
			return "The hoe treads a path (left click) and smooths the ground by moving dirt from high spots to low ones (right click). It uses no items, only its own wear"
		"spade":
			return "The spade digs roots and bulbs (press E at a plant), digs the ground (left click) or raises it in Raise mode (right click switches; each raise uses soil, sand, gravel, clay or stone from your pack)"

	return "%s: nothing to use it on yet" % _inv.table.name_of(held_number())


func _caption() -> String:
	var number: int = held_number()

	if number == 0:
		return ""

	var text: String = _inv.table.name_of(number)

	if _is_placeable() and PlacementRules.reason_text(blueprint_state) != "":
		text += "   (red: %s)" % PlacementRules.reason_text(blueprint_state)
	elif _is_placeable():
		text += "   (left click: place; under a tree it keeps dry, in the open rain puts it out)" if _blueprint_shape == Vector2.ZERO else "   (left click: place, it faces you)"
	elif _is_torch():
		text += "   (lights the way while held)"
	elif _is_axe():
		text += "   (left click: swing)"
	elif _is_spear():
		text += "   (left click: jab; hold right click to aim, then left click to throw)"
	elif _is_other_tool() and str(_inv.table.entry(held_id()).get("tool_class", "")) == "spade":
		text += "   (%s; right click switches)" % ("Raise" if raise_mode else "Dig")
	elif _is_other_tool():
		text += "   (in hand)"

	return text


func _show_model() -> void:
	var number: int = held_number() if _inv != null else 0

	if not _is_spear() and not _is_axe() and not _is_torch() and not _is_knife() and not _is_other_tool() and not _is_placeable():
		number = 0

	if number == _shown_number:
		return

	_shown_number = number

	if _model != null:
		_model.queue_free()
		_model = null

	if number != 0:
		_model = _make_kit_model() if _is_placeable() else _make_spear_model() if _is_spear() else (_make_torch_model() if _is_torch() else (_make_knife_model() if _is_knife() else (_make_other_model() if _is_other_tool() else _make_axe_model())))
		_mount_model()


# Put the model in the hand: its business end leads along the fingers (-Z of the mount) and the grip sits in the palm.
# Falls back to the old spot in front of the camera when there are no arms.
func _mount_model() -> void:
	_mounted = _arms != null
	var kind: String = "kit" if _is_placeable() else "spear" if _is_spear() else ("torch" if _is_torch() else ("knife" if _is_knife() else ("axe" if _is_axe() else "other")))

	if not _mounted:
		_camera.add_child(_model)
		_model.position = REST
		return

	if not _first_person and _avatar_rig != null and _avatar_rig.hand_mount_r != null:
		_mount_model_third(kind)
		return

	_arms.hand_mount_r.add_child(_model)
	var tilt: Basis = Basis(Vector3.RIGHT, deg_to_rad(TOOL_TILT_DEG))
	var turn: Basis = Basis.IDENTITY
	var grip: Vector3 = Vector3(0.0, 0.0, -SPEAR_GRIP_Z)

	if kind == "kit":
		grip = Vector3(0.0, -0.03, -0.14)   # carried in the palm, a little ahead of the hand
	elif kind != "spear":
		turn = Basis(Vector3.RIGHT, deg_to_rad(-90.0))   # +Y (handle to head) becomes -Z (along the fingers)
		grip = Vector3(0.0, 0.0, -float(GRIP_ALONG_Y[kind]))

	_model.basis = tilt * turn
	_model.position = tilt * grip


# Third person: the hand hangs at the side (mount -Z down the fingers, +Y forward, +Z up), so a tool is turned to stand up and a little forward.
func _mount_model_third(kind: String) -> void:
	_avatar_rig.hand_mount_r.add_child(_model)
	var turn: Basis = Basis(Vector3.RIGHT, deg_to_rad(60.0))
	var grip: Vector3 = Vector3(0.0, float(GRIP_ALONG_Y.get(kind, 0.0)), 0.0)   # the hand sits grip below the model middle, on the handle end (Dave 2026-10-22: it was held by the head)

	if kind == "spear":
		turn = Basis(Vector3.RIGHT, deg_to_rad(150.0))
		grip = Vector3(0.0, 0.0, -SPEAR_GRIP_Z)
	elif kind == "kit":
		turn = Basis.IDENTITY
		grip = Vector3(0.0, -0.03, -0.14)

	_model.basis = turn
	_model.position = turn * grip


# A placeable kit in the hand (Items job 3 of refill 10): a small bundle the size of what it makes, shared meshes and materials,
# no light, nothing per frame. Lean-to: a leafy bundle of sticks tied with cord; chests: a little box; campfire: sticks over stones;
# chopping block: a short log. Art can swap these for finished models through the same hook (_make_kit_model).
func _make_kit_model() -> Node3D:
	var id: String = held_id()
	var node: Node3D = Node3D.new()

	if id == "chest_kit" or id == "plank_chest_kit":
		var box: MeshInstance3D = MeshInstance3D.new()
		var shape: BoxMesh = BoxMesh.new()
		shape.size = Vector3(0.22, 0.14, 0.15)
		shape.material = _kit_material(Color(0.55, 0.45, 0.28) if id == "chest_kit" else Color(0.5, 0.36, 0.22))
		box.mesh = shape
		node.add_child(box)
		return node

	if id == "tool_rack_kit" or id == "vice_kit":
		var piece: MeshInstance3D = MeshInstance3D.new()
		var chunk: BoxMesh = BoxMesh.new()
		chunk.size = Vector3(0.3, 0.1, 0.1) if id == "tool_rack_kit" else Vector3(0.14, 0.14, 0.12)
		chunk.material = _kit_material(Color(0.4, 0.29, 0.18))
		piece.mesh = chunk
		node.add_child(piece)
		return node

	if id == "workbench_kit":
		var plank: MeshInstance3D = MeshInstance3D.new()
		var slab: BoxMesh = BoxMesh.new()
		slab.size = Vector3(0.32, 0.05, 0.2)
		slab.material = _kit_material(Color(0.45, 0.33, 0.2))
		plank.mesh = slab
		node.add_child(plank)
		return node

	# The bigger stations in the hand: a log bench is a short beam on trestles, the forge a block of stone with a bar of iron on it,
	# the blacksmithy a rolled plan under a timber peg (the heavy parts are delivered where it is raised).
	if id == "log_workbench_kit" or id == "stone_forge_kit" or id == "blacksmithy_kit" or id == "large_forge_kit" or id == "master_forge_kit":
		var body: MeshInstance3D = MeshInstance3D.new()
		var lump: BoxMesh = BoxMesh.new()
		lump.size = Vector3(0.3, 0.07, 0.14) if id == "log_workbench_kit" else (Vector3(0.18, 0.14, 0.14) if id == "stone_forge_kit" else Vector3(0.26, 0.04, 0.2))
		lump.material = _kit_material(Color(0.36, 0.26, 0.16) if id != "stone_forge_kit" else Color(0.45, 0.44, 0.42))
		body.mesh = lump
		node.add_child(body)
		var mark: MeshInstance3D = MeshInstance3D.new()
		var bar: BoxMesh = BoxMesh.new()
		bar.size = Vector3(0.2, 0.04, 0.05) if id != "blacksmithy_kit" and id != "large_forge_kit" and id != "master_forge_kit" else Vector3(0.03, 0.14, 0.03)
		bar.material = _kit_material(Color(0.2, 0.2, 0.22) if id != "blacksmithy_kit" and id != "large_forge_kit" and id != "master_forge_kit" else Color(0.4, 0.28, 0.17) if id != "master_forge_kit" else Color(0.75, 0.6, 0.2))
		mark.mesh = bar
		mark.position = Vector3(0.0, 0.08, 0.0)
		node.add_child(mark)
		return node

	if id == "chopping_block":
		var model: Node3D = BuildingLook.block()       # the same model as the placed block, carried at 30 percent so it fits the hand
		model.scale = Vector3.ONE * 0.3
		node.add_child(model)
		return node

	# Lean-to and campfire: a bundle of sticks across the hand; the lean-to is tied and leafy, the fire has stones at one end.
	for n in 5:
		var stick: MeshInstance3D = MeshInstance3D.new()
		var rod: CylinderMesh = CylinderMesh.new()
		rod.top_radius = 0.012
		rod.bottom_radius = 0.016
		rod.height = 0.34
		rod.material = _kit_material(Color(0.4, 0.28, 0.16))
		stick.mesh = rod
		stick.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		stick.position = Vector3(0.025 * float(n - 2), 0.012 * float(n % 2), 0.0)
		node.add_child(stick)

	var extra: MeshInstance3D = MeshInstance3D.new()

	if id == "lean_to_kit":
		var leaves: BoxMesh = BoxMesh.new()
		leaves.size = Vector3(0.16, 0.05, 0.12)
		leaves.material = _kit_material(Color(0.27, 0.42, 0.2))
		extra.mesh = leaves
		extra.position = Vector3(0.0, 0.05, -0.05)
	else:
		var rock: SphereMesh = SphereMesh.new()
		rock.radius = 0.045
		rock.height = 0.07
		rock.material = _kit_material(Color(0.47, 0.46, 0.44))
		extra.mesh = rock
		extra.position = Vector3(0.0, 0.0, 0.2)

	node.add_child(extra)
	return node


var _kit_materials: Dictionary = {}


func _kit_material(color: Color) -> StandardMaterial3D:
	if not _kit_materials.has(color):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		_kit_materials[color] = material

	return _kit_materials[color]


# A water container: a plain drum, wider for the bigger ones, until Art draws them (job 89).
func _make_container_model() -> Node3D:
	var id: String = held_id()
	var cap: float = float(_inv.table.entry(id).get("capacity_ml", 500))
	var node: Node3D = Node3D.new()
	var body: MeshInstance3D = MeshInstance3D.new()
	var drum: CylinderMesh = CylinderMesh.new()
	drum.top_radius = 0.05 + 0.025 * pow(cap / 1000.0, 0.5)
	drum.bottom_radius = drum.top_radius * 0.85
	drum.height = 0.08 + 0.05 * pow(cap / 1000.0, 0.5)
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	skin.albedo_color = Color(0.62, 0.38, 0.24) if id == "clay_pot" else (Color(0.55, 0.42, 0.3) if id == "waterskin" else Color(0.5, 0.36, 0.2))
	drum.material = skin
	body.mesh = drum
	node.add_child(body)
	return node


# Any other tool: a handle with a flat blade (a spade) or a plain head, until the tool has its own model.
func _make_other_model() -> Node3D:
	if str(_inv.table.entry(held_id()).get("kind", "")) == "container":
		return _make_container_model()

	var tool_class: String = str(_inv.table.entry(held_id()).get("tool_class", ""))
	var node: Node3D = Node3D.new()
	var handle: MeshInstance3D = MeshInstance3D.new()
	var rod: CylinderMesh = CylinderMesh.new()
	rod.top_radius = 0.02
	rod.bottom_radius = 0.025
	rod.height = 0.9 if tool_class == "spade" else 0.6
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.16)
	rod.material = wood
	handle.mesh = rod
	node.add_child(handle)
	var head: MeshInstance3D = MeshInstance3D.new()
	var block: BoxMesh = BoxMesh.new()
	block.size = Vector3(0.16, 0.22, 0.025) if tool_class == "spade" else Vector3(0.06, 0.1, 0.1)
	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_color = Color(0.5, 0.42, 0.3) if tool_class == "spade" else Color(0.5, 0.5, 0.52)
	block.material = metal
	head.mesh = block
	head.position = Vector3(0.0, rod.height * 0.5 + (0.0 if tool_class == "spade" else 0.0), 0.0)
	node.add_child(head)
	return node


# A torch in hand: a stick with a glowing head and one warm light (only while it is held).
func _make_torch_model() -> Node3D:
	var torch: Node3D = Node3D.new()
	var stick: MeshInstance3D = MeshInstance3D.new()
	var rod: CylinderMesh = CylinderMesh.new()
	rod.top_radius = 0.025
	rod.bottom_radius = 0.03
	rod.height = 0.6
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.27, 0.14)
	rod.material = wood
	stick.mesh = rod
	torch.add_child(stick)
	var flame: MeshInstance3D = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.07
	cone.height = 0.22
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.6, 0.2)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.5, 0.1)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone.material = glow
	flame.mesh = cone
	flame.position = Vector3(0.0, 0.4, 0.0)
	torch.add_child(flame)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.65, 0.3)
	light.omni_range = float(_inv.table.entry(held_id()).get("light_m", 9.0))
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.55, 0.0)
	torch.add_child(light)
	return torch


func _make_knife_model() -> Node3D:
	var knife: Node3D = Node3D.new()
	var handle: MeshInstance3D = MeshInstance3D.new()
	var rod: CylinderMesh = CylinderMesh.new()
	rod.top_radius = 0.02
	rod.bottom_radius = 0.02
	rod.height = 0.16
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.27, 0.14)
	rod.material = wood
	handle.mesh = rod
	knife.add_child(handle)
	var blade: MeshInstance3D = MeshInstance3D.new()
	var edge: BoxMesh = BoxMesh.new()
	edge.size = Vector3(0.015, 0.14, 0.05)
	var flint: StandardMaterial3D = StandardMaterial3D.new()
	flint.albedo_color = Color(0.5, 0.5, 0.52)
	edge.material = flint
	blade.mesh = edge
	blade.position = Vector3(0.0, 0.15, 0.0)
	knife.add_child(blade)
	return knife


func _make_axe_model() -> Node3D:
	var axe: Node3D = Node3D.new()
	var handle: MeshInstance3D = MeshInstance3D.new()
	var rod: CylinderMesh = CylinderMesh.new()
	rod.top_radius = 0.02
	rod.bottom_radius = 0.025
	rod.height = 0.7
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.16)
	rod.material = wood
	handle.mesh = rod
	axe.add_child(handle)
	var head: MeshInstance3D = MeshInstance3D.new()
	var block: BoxMesh = BoxMesh.new()
	block.size = Vector3(0.05, 0.14, 0.2)
	var stone: StandardMaterial3D = StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.5, 0.52)
	block.material = stone
	head.mesh = block
	head.position = Vector3(0.0, 0.32, -0.06)
	axe.add_child(head)
	return axe


func _make_spear_model() -> Node3D:
	var spear: Node3D = Node3D.new()
	var shaft: MeshInstance3D = MeshInstance3D.new()
	var rod: CylinderMesh = CylinderMesh.new()
	rod.top_radius = 0.018
	rod.bottom_radius = 0.022
	rod.height = 1.9
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.16)
	rod.material = wood
	shaft.mesh = rod
	shaft.rotation.x = deg_to_rad(90.0)
	spear.add_child(shaft)
	var tip: MeshInstance3D = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.04
	cone.height = 0.2
	var flint: StandardMaterial3D = StandardMaterial3D.new()
	flint.albedo_color = Color(0.5, 0.5, 0.52)
	cone.material = flint
	tip.mesh = cone
	tip.rotation.x = deg_to_rad(-90.0)
	tip.position = Vector3(0.0, 0.0, -1.0)
	spear.add_child(tip)
	return spear


# Headless check (--spear): make a spear, jab, aim, throw, and see it land.
func run_test() -> void:
	await get_tree().create_timer(3.0).timeout
	var table = _inv.table
	_net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("stick"), 0, 2, Vector3.ZERO)
	_net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("stone"), 0, 3, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	_net.inventory_action.rpc_id(1, Net.ACT_CRAFT, 5, 0, 0, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout

	for slot in range(8):
		if _inv.inventory.numbers[slot] == table.number_of("wooden_spear"):
			select(slot)

	print("Spear test: holding %s" % held_id())
	var jabbed: bool = mouse_button(MOUSE_BUTTON_LEFT, true)
	await get_tree().create_timer(0.5).timeout
	mouse_button(MOUSE_BUTTON_RIGHT, true)
	var aimed: bool = aiming
	mouse_button(MOUSE_BUTTON_LEFT, true)
	await get_tree().create_timer(5.0).timeout
	print("Spear test: jab %s, aimed %s, still aiming %s, spears in pack %d, things on ground %d" % [jabbed, aimed, aiming, _inv.inventory.count_of(table.number_of("wooden_spear")), _inv._world.size()])
	_net.inventory_action.rpc_id(1, Net.ACT_CRAFT, 2, 0, 0, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout

	for slot in range(8):
		if _inv.inventory.numbers[slot] == table.number_of("stone_axe"):
			select(slot)

	var swung: bool = mouse_button(MOUSE_BUTTON_LEFT, true)
	await get_tree().create_timer(1.0).timeout
	print("Spear test: holding %s, swung %s, last hit sound '%s'" % [held_id(), swung, _sound.hits.last_hit if _sound != null else "none"])
	_net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("campfire_kit"), 0, 1, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	var kit_slot: int = -1

	for slot in range(inv_slots()):
		if _inv.inventory.numbers[slot] == table.number_of("campfire_kit"):
			kit_slot = slot

	var feet: Vector3 = _inv._player_position.call()
	var ground: float = _ground_below.call(feet)
	var spot: Vector3 = Vector3(feet.x + 2.0, _ground_below.call(feet + Vector3(2.0, 0.0, 0.0)), feet.z)
	_net.inventory_action.rpc_id(1, Net.ACT_PLACE, kit_slot, 0, 0, spot)
	await get_tree().create_timer(3.0).timeout
	var lit: int = 0
	var states: Array = []

	for id in _inv._world:
		if _inv._world[id]["state"] != 0:
			lit += 1
			states.append(_inv._world[id]["state"])

	print("Spear test: campfire kit slot %d, ground %s, fires in view %d, states %s" % [kit_slot, str(ground), lit, str(states)])


func inv_slots() -> int:
	return _inv.inventory.SLOTS
