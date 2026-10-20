extends Node

# What the player holds (hotbar keys 1 to 8 choose inventory slots 0 to 7) and how it is used.
# Client only; the server decides what happens (throws are server actions).
#
# Spear (Dave, 2026-10-20): held and jabbed by default with the normal attack key (left click).
# Hold right click to aim a throw; then left click throws. Letting go of right click returns to
# the normal stance. The weapon is drawn as a simple first-person model until real art exists.

const Net := preload("res://src/stream/terrain_net.gd")

const REST := Vector3(0.38, -0.32, -0.55)       # model offset from the camera
const AIMED := Vector3(0.28, -0.12, -0.35)
const JAB_REACH := 0.7
const JAB_S := 0.28
const THROW_SPEED := 24.0
const THROW_GRAVITY := 9.8

var held_slot: int = 0
var aiming: bool = false

var _inv                                  # InventoryView
var _net
var _camera: Camera3D
var _root: Node3D
var _ground_below: Callable
var _model: Node3D
var _label: Label
var _jab_t: float = -1.0
var _flights: Array = []                  # local visuals of spears this player threw: {node, vel, age}
var _shown_number: int = 0
var _sound                                # SoundStage (hit sounds)
var _tree_near: Callable                  # (point) -> [chunk, id] of the tree trunk standing there, or []
var _swing_t: float = -1.0
var _swing_hit: bool = false
var _cover_at: Callable                   # (point) -> true when under a tree's crown
var _blueprint: MeshInstance3D
var _blueprint_at: Vector3 = Vector3.ZERO
var _blueprint_ok: bool = false
var _blueprint_next_msec: int = 0

const SWING_S := 0.55
const REACH_M := 3.0


func setup(inventory_view, terrain_net, camera: Camera3D, world_root: Node3D, hud_layer: CanvasLayer, ground_below: Callable, sound_stage = null, tree_near: Callable = Callable(), cover_at: Callable = Callable()) -> void:
	_cover_at = cover_at
	_sound = sound_stage
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


func select(slot: int) -> void:
	held_slot = clampi(slot, 0, 7)
	aiming = false


func held_number() -> int:
	return _inv.inventory.numbers[held_slot]


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


func _is_axe() -> bool:
	return str(_inv.table.entry(held_id()).get("tool_class", "")) == "axe"


# A mouse button while playing. Returns true when it was used here.
func mouse_button(button: int, pressed: bool) -> bool:
	if _is_placeable():
		if button == MOUSE_BUTTON_LEFT and pressed and _blueprint_ok:
			_net.inventory_action.rpc_id(1, Net.ACT_PLACE, held_slot, 0, 0, _blueprint_at)

		return button == MOUSE_BUTTON_LEFT

	if _is_axe():
		if button == MOUSE_BUTTON_LEFT and pressed and _swing_t < 0.0:
			_swing_t = 0.0
			_swing_hit = false

		return button == MOUSE_BUTTON_LEFT

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

			if _sound != null:
				_sound.spear.jab(_camera.global_position - _camera.global_transform.basis.z)

		return true

	return false


func _throw() -> void:
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
	_update_blueprint()
	_show_model()
	_label.text = _caption()

	if _swing_t >= 0.0:
		_swing_t += delta

		if not _swing_hit and _swing_t >= SWING_S * 0.5:
			_swing_hit = true
			_strike()

		if _swing_t >= SWING_S:
			_swing_t = -1.0

	if _model != null and _is_torch():
		var flicker: OmniLight3D = _model.get_node_or_null("Light")

		if flicker != null:
			flicker.light_energy = 1.4 + 0.3 * sin(float(Time.get_ticks_msec()) * 0.017)

		_model.position = _model.position.lerp(REST, clampf(delta * 14.0, 0.0, 1.0))
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

	if _blueprint == null:
		_blueprint = MeshInstance3D.new()
		var ring: CylinderMesh = CylinderMesh.new()
		ring.top_radius = 0.6
		ring.bottom_radius = 0.6
		ring.height = 0.06
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material = material
		_blueprint.mesh = ring
		_root.add_child(_blueprint)

	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * 5.0)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	_blueprint.visible = not hit.is_empty()
	_blueprint_ok = not hit.is_empty()

	if hit.is_empty():
		return

	_blueprint_at = hit["position"]
	_blueprint.global_position = _blueprint_at + Vector3(0.0, 0.04, 0.0)
	var covered: bool = _cover_at.is_valid() and _cover_at.call(_blueprint_at)
	(_blueprint.mesh.material as StandardMaterial3D).albedo_color = Color(0.3, 0.9, 0.3, 0.55) if covered else Color(0.95, 0.85, 0.2, 0.55)


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

	if trunk_id != 0:
		_sound.hits.hit("axe", "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_PROCESS, trunk_id, 0, 0, Vector3.ZERO)
	elif not tree.is_empty():
		_sound.hits.hit("axe", "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_HIT, tree[1], tree[0].x, tree[0].y, Vector3.ZERO)
	else:
		_sound.hits.hit_ground("pick", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_MINE, 0, 0, 0, hit["position"])


func _caption() -> String:
	var number: int = held_number()

	if number == 0:
		return ""

	var text: String = _inv.table.name_of(number)

	if _is_placeable():
		text += "   (left click: place; green = under cover, yellow = open)"
	elif _is_torch():
		text += "   (lights the way while held)"
	elif _is_axe():
		text += "   (left click: swing)"
	elif _is_spear():
		text += "   (left click: jab; hold right click to aim, then left click to throw)"

	return text


func _show_model() -> void:
	var number: int = held_number() if _inv != null else 0

	if not _is_spear() and not _is_axe() and not _is_torch() and not _is_knife():
		number = 0

	if number == _shown_number:
		return

	_shown_number = number

	if _model != null:
		_model.queue_free()
		_model = null

	if number != 0:
		_model = _make_spear_model() if _is_spear() else (_make_torch_model() if _is_torch() else (_make_knife_model() if _is_knife() else _make_axe_model()))
		_camera.add_child(_model)
		_model.position = REST


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
