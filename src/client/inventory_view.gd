extends Node

# The client side of items: the inventory panel (I), things lying on the ground (E picks up
# the nearest within reach) and the player key. The server owns all of it; this only shows
# what the server says and asks. Nothing is built until the panel is first opened, and the
# world items are a handful of small meshes within 100 m (the server caps them per chunk).

const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const RecipeTableScript := preload("res://src/shared/recipe_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const KEY_FILE := "user://player_key.txt"
const PICKUP_M := 3.0
const COLUMNS := 6

var open: bool = false
var table
var inventory
var recipes
var net
var _layer: CanvasLayer
var _root: Node3D
var _player_position: Callable
var _ground_below: Callable
var _panel: PanelContainer
var _grid: GridContainer
var _buttons: Array = []
var _selected: int = -1
var _prompt: Label
var _craft_buttons: Dictionary = {}   # recipe number -> Button
var _crafting: int = 0                # recipe being made (0 none)
var _craft_done_msec: int = 0
var _craft_label: Label
var _world: Dictionary = {}        # id -> {node, number, count, pos}
var _prompt_next_msec: int = 0
var _meshes: Dictionary = {}       # item number -> Mesh


func setup(terrain_net, hud_layer: CanvasLayer, world_root: Node3D, player_position: Callable, ground_below: Callable) -> void:
	net = terrain_net
	_layer = hud_layer
	_root = world_root
	_player_position = player_position
	_ground_below = ground_below
	table = ItemTableScript.load_default()
	inventory = InventoryScript.new(table)
	recipes = RecipeTableScript.load_default(table)
	net.inventory_full_received.connect(_on_full)
	net.inventory_slots_received.connect(_on_slots)
	net.world_items_received.connect(_on_world_items)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_prompt.offset_bottom = -120.0
	_prompt.add_theme_font_size_override("font_size", 30)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_prompt)
	net.hello.rpc_id(1, _player_key())


func _player_key() -> String:
	if FileAccess.file_exists(KEY_FILE):
		var saved: String = FileAccess.get_file_as_string(KEY_FILE).strip_edges()

		if saved.length() >= 8:
			return saved

	var crypto: Crypto = Crypto.new()
	var key: String = crypto.generate_random_bytes(12).hex_encode()
	var file: FileAccess = FileAccess.open(KEY_FILE, FileAccess.WRITE)

	if file != null:
		file.store_string(key)

	return key


func toggle() -> void:
	open = not open

	if open:
		_build_panel()
		_refresh()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif _panel != null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if _panel != null:
		_panel.visible = open


func close() -> void:
	if open:
		toggle()


# True when something lay within reach and the server was asked for it.
func pick_up_nearest() -> bool:
	var id: int = _nearest()[0]

	if id == 0:
		return false

	net.inventory_action.rpc_id(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
	return true


# Admin test tool: a starter set so the panel and pick-up can be tried before harvesting exists.
func admin_give_test_set() -> void:
	for id in ["stone", "stick", "plant_fibre", "log"]:
		net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of(id), 0, 10, Vector3.ZERO)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()

	if _crafting != 0:
		if now >= _craft_done_msec:
			net.inventory_action.rpc_id(1, Net.ACT_CRAFT, _crafting, 0, 0, Vector3.ZERO)
			_crafting = 0
			_craft_label.text = ""
		elif _craft_label != null:
			_craft_label.text = "Making... %.0f s" % ceilf(float(_craft_done_msec - now) / 1000.0)

	if now < _prompt_next_msec:
		return

	_prompt_next_msec = now + 200
	var near: Array = _nearest()
	_prompt.text = "" if near[0] == 0 else "E: pick up %s x%d" % [table.name_of(near[1]), near[2]]


# [id, number, count] of the closest item within reach, or [0, 0, 0].
func _nearest() -> Array:
	var here: Vector3 = _player_position.call()
	var best: Array = [0, 0, 0]
	var best_d: float = PICKUP_M

	for id in _world:
		var d: float = here.distance_to(_world[id]["pos"])

		if d <= best_d:
			best_d = d
			best = [id, _world[id]["number"], _world[id]["count"]]

	return best


func _on_full(bytes: PackedByteArray) -> void:
	inventory.from_bytes(bytes)
	_refresh()


func _on_slots(bytes: PackedByteArray) -> void:
	for at in range(0, bytes.size() - 6, 7):
		var slot: int = bytes[at]

		if slot < inventory.SLOTS:
			inventory.numbers[slot] = bytes.decode_u32(at + 1)
			inventory.counts[slot] = bytes.decode_u16(at + 5)

	_refresh()


func _on_world_items(added: Array, removed: PackedInt32Array) -> void:
	for id in removed:
		if _world.has(id):
			_world[id]["node"].queue_free()
			_world.erase(id)

	for row in added:
		var id: int = row[0]

		if _world.has(id):
			_world[id]["count"] = row[2]
			continue

		var node: MeshInstance3D = MeshInstance3D.new()
		node.mesh = _mesh_for(row[1])
		node.position = row[3] + Vector3(0.0, 0.12, 0.0)
		_root.add_child(node)
		_world[id] = {"node": node, "number": row[1], "count": row[2], "pos": row[3]}


func _mesh_for(number: int) -> Mesh:
	if not _meshes.has(number):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.28, 0.2, 0.28)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color.from_hsv(fmod(float(number) * 0.137, 1.0), 0.5, 0.8)
		mesh.material = material
		_meshes[number] = mesh

	return _meshes[number]


func _build_panel() -> void:
	if _panel != null:
		return

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box: VBoxContainer = VBoxContainer.new()
	_panel.add_child(box)
	var title: Label = Label.new()
	title.text = "Inventory   (click a slot, then another to move; Drop sends the selected stack to the ground)"
	box.add_child(title)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	box.add_child(_grid)

	for i in inventory.SLOTS:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(110.0, 64.0)
		button.pressed.connect(_on_slot_pressed.bind(i))
		_grid.add_child(button)
		_buttons.append(button)

	var craft_title: Label = Label.new()
	craft_title.text = "Make by hand"
	box.add_child(craft_title)

	for number in recipes.numbers():
		var r: Dictionary = recipes.recipe(number)

		if not r["known"]:
			continue

		var needs: Array = []

		for need in r["needs"]:
			needs.append("%d %s" % [need[1], table.name_of(need[0])])

		var make: Button = Button.new()
		make.text = "%s   (%s)" % [r["name"], ", ".join(needs)]
		make.pressed.connect(_start_craft.bind(number))
		box.add_child(make)
		_craft_buttons[number] = make

	_craft_label = Label.new()
	box.add_child(_craft_label)
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	var drop: Button = Button.new()
	drop.text = "Drop stack"
	drop.pressed.connect(_drop_selected.bind(true))
	row.add_child(drop)
	var drop_one: Button = Button.new()
	drop_one.text = "Drop one"
	drop_one.pressed.connect(_drop_selected.bind(false))
	row.add_child(drop_one)
	_layer.add_child(_panel)


func _on_slot_pressed(slot: int) -> void:
	if _selected < 0:
		if inventory.numbers[slot] != 0:
			_selected = slot
	else:
		if slot != _selected:
			net.inventory_action.rpc_id(1, Net.ACT_MOVE, _selected, slot, 0, Vector3.ZERO)

		_selected = -1

	_refresh()


func _start_craft(number: int) -> void:
	if _crafting != 0 or not recipes.can_make(number, inventory):
		return

	_crafting = number
	_craft_done_msec = Time.get_ticks_msec() + int(recipes.recipe(number)["craft_s"] * 1000.0)


func _drop_selected(whole: bool) -> void:
	if _selected < 0 or inventory.numbers[_selected] == 0:
		return

	var here: Vector3 = _player_position.call()
	var ground: float = _ground_below.call(here)
	var at: Vector3 = Vector3(here.x, ground if not is_nan(ground) else here.y - 1.0, here.z)
	net.inventory_action.rpc_id(1, Net.ACT_DROP, _selected, 0, inventory.counts[_selected] if whole else 1, at)
	_selected = -1


func _refresh() -> void:
	if _panel == null:
		return

	for i in inventory.SLOTS:
		var button: Button = _buttons[i]
		var number: int = inventory.numbers[i]
		button.text = "" if number == 0 else "%s\nx%d" % [table.name_of(number), inventory.counts[i]]
		button.modulate = Color(1.0, 0.9, 0.5) if i == _selected else Color.WHITE

	for number in _craft_buttons:
		_craft_buttons[number].disabled = not recipes.can_make(number, inventory)


# Headless check (--items): give, drop, pick up, and print what the server says.
func run_test() -> void:
	await get_tree().create_timer(2.0).timeout
	admin_give_test_set()
	await get_tree().create_timer(1.0).timeout
	print("Items test: after give, stone %d" % inventory.count_of(table.number_of("stone")))
	var here: Vector3 = _player_position.call()
	net.inventory_action.rpc_id(1, Net.ACT_DROP, 0, 0, 4, here)
	await get_tree().create_timer(3.0).timeout
	print("Items test: after drop, stone %d, %d on the ground" % [inventory.count_of(table.number_of("stone")), _world.size()])
	pick_up_nearest()
	await get_tree().create_timer(1.0).timeout
	print("Items test: after pick up, stone %d, %d on the ground" % [inventory.count_of(table.number_of("stone")), _world.size()])
	net.inventory_action.rpc_id(1, Net.ACT_CRAFT, 1, 0, 0, Vector3.ZERO)
	net.inventory_action.rpc_id(1, Net.ACT_CRAFT, 2, 0, 0, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	print("Items test: crafted, cordage %d, stone axe %d, fibre %d" % [inventory.count_of(table.number_of("cordage")), inventory.count_of(table.number_of("stone_axe")), inventory.count_of(table.number_of("plant_fibre"))])


# Headless check (--gather): stand next to the nearest shrub or plant that drops something and gather it.
func run_gather_test(client) -> void:
	await get_tree().create_timer(6.0).timeout
	var best: Array = []
	var here: Vector3 = _player_position.call()

	for chunk in client.flora._chunks:
		var held: Dictionary = client.flora._chunks[chunk]["items"]

		for n in range(held["ids"].size()):
			var sid: int = held["ids"][n] >> 16

			if client.flora._species.get(sid, {}).get("kind", 0) == 1:
				var d: float = held["positions"][n].distance_to(here)

				if best.is_empty() or d < best[0]:
					best = [d, held["positions"][n]]

	if best.is_empty():
		print("Gather test: no shrub loaded")
		return

	client.body.global_position = best[1] + Vector3(0.5, 1.0, 0.0)
	client.body.velocity = Vector3.ZERO
	await get_tree().create_timer(3.0).timeout
	var sticks: int = table.number_of("stick")
	var before: int = inventory.count_of(sticks)
	client._gather_nearest()
	await get_tree().create_timer(2.0).timeout
	print("Gather test: sticks %d -> %d; loose things in view %d" % [before, inventory.count_of(sticks), _world.size()])
