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


func setup(inventory_view, terrain_net, camera: Camera3D, world_root: Node3D, hud_layer: CanvasLayer, ground_below: Callable) -> void:
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


# A mouse button while playing. Returns true when it was used here.
func mouse_button(button: int, pressed: bool) -> bool:
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


func _process(delta: float) -> void:
	_show_model()
	_label.text = _caption()

	if _model != null:
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


func _caption() -> String:
	var number: int = held_number()

	if number == 0:
		return ""

	var text: String = _inv.table.name_of(number)

	if _is_spear():
		text += "   (left click: jab; hold right click to aim, then left click to throw)"

	return text


func _show_model() -> void:
	var number: int = held_number() if _inv != null else 0

	if not _is_spear():
		number = 0

	if number == _shown_number:
		return

	_shown_number = number

	if _model != null:
		_model.queue_free()
		_model = null

	if number != 0:
		_model = _make_spear_model()
		_camera.add_child(_model)
		_model.position = REST


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
