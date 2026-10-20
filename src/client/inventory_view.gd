extends Node

# The client side of items: the inventory panel (I), things lying on the ground (E picks up
# the nearest within reach) and the player key. The server owns all of it; this only shows
# what the server says and asks. Nothing is built until the panel is first opened, and the
# world items are a handful of small meshes within 100 m (the server caps them per chunk).

const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const RecipeTableScript := preload("res://src/shared/recipe_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const VitalsRules := preload("res://src/shared/vitals_rules.gd")
const CoverScript := preload("res://src/shared/cover.gd")
const KEY_FILE := "user://player_key.txt"
const PICKUP_M := 3.0
const COLUMNS := 6
const MAX_FIRE_LIGHTS := 3              # at High and Ultra; fewer below (max_lights)

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
var cover_index                        # the client's Cover.Index: lean-to roofs are added to it
var tool_event: Callable               # ("broke" | "repaired") when a tool in the pack wears out or is mended (sounds)
var _block_next_msec: int = 0
var chest_event: Callable              # ("open" | "close" | "put" | "take", position) for the chest sounds
var chest_mode: bool = false           # the panel on screen is a chest, not the pack and recipes
var chest_inv                          # contents of the open chest (Inventory), from the server
var chest_id: int = 0
var _chest_panel: PanelContainer
var _chest_buttons: Array = []
var _pack_buttons: Array = []
var eat_event: Callable                # (item id) when something eaten or applied takes effect (sounds)
var hunger: int = 100                  # stomach, percent
var health: int = 100
var weight_kg: float = 75.0
var _vitals_cfg: Dictionary = {}
var _eat_item: String = ""
var _hunger_bar: ColorRect
var _health_bar: ColorRect
var _vitals_back: Control
var _vitals_warning: Label
var _weight_label: Label
var plant_hint: String = ""            # set by the harvest prompt (harvest.gd)
var _crafting: int = 0                # recipe being made (0 none)
var _craft_done_msec: int = 0
var _craft_label: Label
var _world: Dictionary = {}        # id -> {node, number, count, pos}
var _prompt_next_msec: int = 0
var _notice_until_msec: int = 0
var _collide: Array = []              # [node, StaticBody3D] trunks whose collider is on only near the player
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
	net.notice_received.connect(_on_notice)
	net.chest_received.connect(_on_chest)
	net.vitals_received.connect(_on_vitals)
	_vitals_cfg = VitalsRules.load_config()
	_build_vitals_hud()
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
	if chest_mode:
		_close_chest()
		return

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
		id = _nearest_struct()

	if id == 0:
		return false

	if _world[id]["state"] == 6 and not Input.is_key_pressed(KEY_SHIFT):
		net.inventory_action.rpc_id(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
		return true

	if _world[id]["state"] == 7 and not Input.is_key_pressed(KEY_SHIFT):
		net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO)
		_block_next_msec = Time.get_ticks_msec() + 600
		return true

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
			var done: int = _crafting
			net.inventory_action.rpc_id(1, Net.ACT_CRAFT, done, 0, 0, Vector3.ZERO)
			_crafting = 0

			# The server's answer rewrites the inventory; the next craft starts once the pack shows the result.
			if _craft_queue > 0:
				_craft_queue -= 1
				get_tree().create_timer(0.3).timeout.connect(func(): _start_craft(done))

			if is_instance_valid(_craft_label):
				_craft_label.text = ""
		elif is_instance_valid(_craft_label):
			_craft_label.text = "Making... %.0f s" % ceilf(float(_craft_done_msec - now) / 1000.0)

	if now < _prompt_next_msec:
		return

	_prompt_next_msec = now + 200
	_update_fire_lights()
	_update_trunk_colliders()

	if now < _notice_until_msec:
		return
	var near: Array = _nearest()
	var fire: int = _nearest_fire()
	_prompt.text = "" if near[0] == 0 else "E: pick up %s x%d" % [table.name_of(near[1]), near[2]]

	var struct_id: int = _nearest_struct()

	if near[0] == 0 and fire != 0:
		_prompt.text = "C: roast food    V: add wood" if _world[fire]["state"] == 1 else "V: add wood to relight"
	elif near[0] == 0 and struct_id != 0:
		var st: int = _world[struct_id]["state"]
		_prompt.text = "E: open chest    Shift+E: take it down (empty only)" if st == 6 else ("E: split a log into firewood (hold E to keep going, needs an axe)    Shift+E: take it down" if st == 7 else "E: take down %s" % table.name_of(_world[struct_id]["number"]).to_lower())
	elif near[0] == 0:
		_prompt.text = plant_hint



# Holding E beside a chopping block keeps splitting logs at the server's pace. True when one is in reach.
func hold_use() -> bool:
	var id: int = _nearest_struct()

	if id == 0 or _world[id]["state"] != 7:
		return false

	var now: int = Time.get_ticks_msec()

	if now >= _block_next_msec:
		_block_next_msec = now + 600
		net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO)

	return true


# The id of the nearest placed structure (lean-to, chest) within 3 m, 0 when none.
func _nearest_struct() -> int:
	var here: Vector3 = _player_position.call()
	var best: int = 0
	var best_d: float = 3.0

	for id in _world:
		if _world[id]["state"] >= 5 and here.distance_to(_world[id]["pos"]) <= best_d:
			best_d = here.distance_to(_world[id]["pos"])
			best = id

	return best


# The id of the nearest fire (lit or out) within 3 m, 0 when none.
func _nearest_fire() -> int:
	var here: Vector3 = _player_position.call()
	var best: int = 0
	var best_d: float = 3.0

	for id in _world:
		if _world[id]["state"] in [1, 2] and here.distance_to(_world[id]["pos"]) <= best_d:
			best_d = here.distance_to(_world[id]["pos"])
			best = id

	return best


func cook_nearest() -> void:
	var fire: int = _nearest_fire()

	if fire != 0:
		net.inventory_action.rpc_id(1, Net.ACT_COOK, fire, 0, 0, Vector3.ZERO)


func fuel_nearest() -> void:
	var fire: int = _nearest_fire()

	if fire != 0:
		net.inventory_action.rpc_id(1, Net.ACT_FUEL, fire, 0, 0, Vector3.ZERO)


# [id, number, count] of the closest item within reach, or [0, 0, 0].
func _nearest() -> Array:
	var here: Vector3 = _player_position.call()
	var best: Array = [0, 0, 0]
	var best_d: float = PICKUP_M

	for id in _world:
		if _world[id]["state"] != 0:
			continue

		var d: float = here.distance_to(_world[id]["pos"])

		if d <= best_d:
			best_d = d
			best = [id, _world[id]["number"], _world[id]["count"]]

	return best


# The id of the felled trunk lying within 1.5 m of a point (the axe struck it), 0 when none.
func felled_trunk_near(point: Vector3) -> int:
	for id in _world:
		var entry: Dictionary = _world[id]

		if entry["state"] == 3 and is_instance_valid(entry["node"]):
			var extra: Dictionary = entry.get("extra", {})
			var yaw: float = float(extra.get("yaw", 0.0))
			var length: float = float(extra.get("length", 8.0))
			var along: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
			var t: float = clampf((point - entry["pos"]).dot(along), 0.0, length)
			var nearest: Vector3 = entry["pos"] + along * t

			if Vector2(point.x - nearest.x, point.z - nearest.z).length() < 1.5 + float(extra.get("radius", 0.3)):
				return id

	return 0


func show_notice(text: String) -> void:
	_on_notice(text)


# Condition of the item in a slot: 1.0 new down to 0.0 broken; 1.0 for items that do not wear.
func condition(slot: int) -> float:
	var durability: int = int(table.entry(table.id_of(inventory.numbers[slot])).get("durability", 0))
	return 1.0 if durability <= 0 else clampf(1.0 - float(inventory.wear[slot]) / float(durability), 0.0, 1.0)


func is_broken(slot: int) -> bool:
	return inventory.numbers[slot] != 0 and int(table.entry(table.id_of(inventory.numbers[slot])).get("durability", 0)) > 0 and condition(slot) <= 0.0


# Is a tool of this class on the hotbar (slots 1 to 8), the way the server checks it?
func has_tool_class(tool_class: String) -> bool:
	for slot in range(8):
		if inventory.numbers[slot] != 0 and str(table.entry(table.id_of(inventory.numbers[slot])).get("tool_class", "")) == tool_class and not is_broken(slot):
			return true

	return false


func _on_notice(text: String) -> void:
	_prompt.text = text
	_notice_until_msec = Time.get_ticks_msec() + 4000


# Trunks are solid, but only the ones near the player keep a collider (cost cap).
func _update_trunk_colliders() -> void:
	var here: Vector3 = _player_position.call()

	for pair in _collide:
		if is_instance_valid(pair[0]):
			pair[1].collision_layer = 1 if pair[0].global_position.distance_to(here) < 40.0 else 0


# A felled trunk (lying along `yaw`, falling over when it first appears) or a stump.
func _make_felled(trunk: bool, extra: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var radius: float = float(extra.get("radius", 0.3))
	var length: float = float(extra.get("length", 8.0))
	var bark: StandardMaterial3D = StandardMaterial3D.new()
	bark.albedo_color = Color(0.32, 0.23, 0.15)
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius * (0.55 if trunk else 0.95)
	cyl.bottom_radius = radius
	cyl.height = length if trunk else maxf(radius * 1.2, 0.5)
	cyl.material = bark
	mesh_node.mesh = cyl
	root.add_child(mesh_node)

	if not trunk:
		mesh_node.position = Vector3(0.0, cyl.height * 0.5, 0.0)
		return root

	# Hinge at the stump: pivot turns from upright to lying, over about 1.5 s.
	root.rotation.y = float(extra.get("yaw", 0.0))
	var pivot: Node3D = Node3D.new()
	root.add_child(pivot)
	root.remove_child(mesh_node)
	pivot.add_child(mesh_node)
	mesh_node.position = Vector3(0.0, length * 0.5, 0.0)
	var lie: float = deg_to_rad(90.0)
	pivot.rotation.x = 0.0
	var tween: Tween = pivot.create_tween()
	tween.tween_property(pivot, "rotation:x", lie, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius * 0.8
	capsule.height = length
	shape.shape = capsule
	shape.rotation.x = lie
	shape.position = Vector3(0.0, radius, length * 0.5)
	body.add_child(shape)
	root.add_child(body)
	_collide.append([root, body])
	return root


func _update_fire_lights() -> void:
	var here: Vector3 = _player_position.call()
	var lit: Array = []

	for id in _world:
		if _world[id]["light"] != null:
			lit.append([here.distance_to(_world[id]["pos"]), _world[id]["light"]])

	lit.sort_custom(func(a, b): return a[0] < b[0])

	for n in lit.size():
		var light: OmniLight3D = lit[n][1]
		light.visible = n < (int(max_lights.call()) if max_lights.is_valid() else MAX_FIRE_LIGHTS)
		light.light_energy = 1.6 + 0.35 * sin(float(Time.get_ticks_msec()) * 0.013 + float(n))


# Is a fire light that is switched on within `radius` of the point?
func fire_light_near(point: Vector3, radius: float) -> bool:
	for id in _world:
		var light: OmniLight3D = _world[id]["light"]

		if light != null and light.visible and point.distance_to(_world[id]["pos"]) <= radius:
			return true

	return false


func _on_full(bytes: PackedByteArray) -> void:
	inventory.from_bytes(bytes)
	_refresh()


func _on_slots(bytes: PackedByteArray) -> void:
	for at in range(0, bytes.size() - 8, 9):
		var slot: int = bytes[at]

		if slot < inventory.SLOTS:
			var was_broken: bool = is_broken(slot)
			var was_wear: int = inventory.wear[slot]
			var was_number: int = inventory.numbers[slot]
			inventory.numbers[slot] = bytes.decode_u32(at + 1)
			inventory.counts[slot] = bytes.decode_u16(at + 5)
			inventory.wear[slot] = bytes.decode_u16(at + 7)

			if tool_event.is_valid() and inventory.numbers[slot] == was_number and was_number != 0:
				if is_broken(slot) and not was_broken:
					tool_event.call("broke")
				elif inventory.wear[slot] < was_wear:
					tool_event.call("repaired")

	_refresh()
	_refresh_chest()


# --- The chest screen: the chest on the left, the pack on the right; a click moves a whole stack ---

# --- Hunger and health HUD, eating ---

func _build_vitals_hud() -> void:
	_vitals_back = Control.new()
	_vitals_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals_back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_layer.add_child(_vitals_back)
	_hunger_bar = _make_bar(Color(0.9, 0.65, 0.2))
	_health_bar = _make_bar(Color(0.85, 0.2, 0.2))
	_vitals_warning = Label.new()
	_vitals_warning.add_theme_font_size_override("font_size", 22)
	_vitals_warning.add_theme_constant_override("outline_size", 5)
	_vitals_warning.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_vitals_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals_back.add_child(_vitals_warning)
	_place_vitals()


func _make_bar(color: Color) -> ColorRect:
	var back: ColorRect = ColorRect.new()
	back.color = Color(0.0, 0.0, 0.0, 0.5)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals_back.add_child(back)
	var fill: ColorRect = ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	return fill


func _place_vitals() -> void:
	var scale: float = maxf(_layer.get_viewport().get_visible_rect().size.y / 1080.0, 0.5)
	var width: float = 240.0 * scale
	var height: float = 14.0 * scale
	var origin: Vector2 = Vector2(24.0 * scale, -(170.0 * scale))
	_vitals_back.position = origin

	for pair in [[_hunger_bar, hunger, 0.0], [_health_bar, health, 1.0]]:
		var fill: ColorRect = pair[0]
		var back: Control = fill.get_parent()
		back.position = Vector2(0.0, float(pair[2]) * (height + 6.0 * scale))
		back.size = Vector2(width, height)
		fill.position = Vector2(1.0, 1.0)
		fill.size = Vector2(maxf((width - 2.0) * float(pair[1]) / 100.0, 0.0), height - 2.0)

	_vitals_warning.position = Vector2(0.0, 2.0 * (height + 6.0 * scale))
	var warn: int = int(_vitals_cfg.get("warn_hunger", 15))
	_vitals_warning.text = "You are starving: you recover slowly" if hunger <= 0 else ("You are hungry" if hunger <= warn else "")

	if _weight_label != null:
		_weight_label.text = "Body weight %.1f kg   (hunger %d%%, health %d)" % [weight_kg, hunger, health]


func _on_vitals(new_hunger: int, new_health: int, weight_dkg: int) -> void:
	var ate: bool = new_hunger > hunger + 3 or new_health > health + 8

	if ate and _eat_item != "" and eat_event.is_valid():
		eat_event.call(_eat_item)
		_eat_item = ""

	hunger = new_hunger
	health = new_health
	weight_kg = float(weight_dkg) / 10.0
	_place_vitals()


# Can this item be eaten or applied (food or medicine in data/items/vitals.json)?
func edible_slot(slot: int) -> bool:
	return slot >= 0 and slot < inventory.SLOTS and inventory.numbers[slot] != 0 and VitalsRules.edible(table.id_of(inventory.numbers[slot]), _vitals_cfg)


# Eat the food or apply the medicine in a pack slot. Herbs that look like something else must be identified first.
func eat_slot(slot: int) -> void:
	if not edible_slot(slot):
		return

	var number: int = inventory.numbers[slot]
	var entry: Dictionary = table.entry(table.id_of(number))

	if knowledge != null and not entry.get("look_alikes", []).is_empty() and not knowledge.is_known("i%d" % number):
		_on_notice("You are not sure what %s really is. Hover it in inspection mode (/) before you use it." % table.name_of(number).to_lower())
		return

	_eat_item = table.id_of(number)
	net.inventory_action.rpc_id(1, Net.ACT_EAT, slot, 0, 0, Vector3.ZERO)


func _on_chest(id: int, bytes: PackedByteArray) -> void:
	if chest_inv == null:
		chest_inv = InventoryScript.new(table)

	chest_inv.from_bytes(bytes)
	chest_id = id

	if not chest_mode:
		chest_mode = true
		open = true
		_build_panel()
		_panel.visible = false
		_build_chest_panel()
		_chest_panel.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		if chest_event.is_valid() and _world.has(id):
			chest_event.call("open", _world[id]["pos"])

	_refresh_chest()


func _close_chest() -> void:
	if chest_event.is_valid() and _world.has(chest_id):
		chest_event.call("close", _world[chest_id]["pos"])

	chest_mode = false
	open = false

	if _chest_panel != null:
		_chest_panel.visible = false

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_chest_panel() -> void:
	if _chest_panel != null:
		return

	_chest_panel = PanelContainer.new()
	_chest_panel.anchor_left = 0.125
	_chest_panel.anchor_right = 0.875
	_chest_panel.anchor_top = 0.1
	_chest_panel.anchor_bottom = 0.9
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", _px(24))
	_chest_panel.add_child(columns)

	for side in ["Woven chest  (click a stack to take it)", "Your pack  (click a stack to put it in)"]:
		var box: VBoxContainer = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(box)
		var title: Label = Label.new()
		title.text = side
		_style(title, TITLE_PX)
		box.add_child(title)
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(scroll)
		var grid: GridContainer = GridContainer.new()
		grid.columns = 4
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", _px(8))
		grid.add_theme_constant_override("v_separation", _px(8))
		scroll.add_child(grid)
		var chest_side: bool = _chest_buttons.is_empty()

		for i in inventory.SLOTS:
			var button: Button = Button.new()
			button.custom_minimum_size = Vector2(0.0, _px(88))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.clip_text = true
			_style(button, BODY_PX - 4)
			button.pressed.connect(_on_chest_slot.bind(chest_side, i))
			grid.add_child(button)
			(_chest_buttons if chest_side else _pack_buttons).append(button)

	_layer.add_child(_chest_panel)


func _on_chest_slot(chest_side: bool, slot: int) -> void:
	if chest_side:
		if chest_inv.numbers[slot] != 0:
			net.inventory_action.rpc_id(1, Net.ACT_CHEST_TAKE, slot, chest_id, chest_inv.counts[slot], Vector3.ZERO)

			if chest_event.is_valid() and _world.has(chest_id):
				chest_event.call("take", _world[chest_id]["pos"])
	elif inventory.numbers[slot] != 0:
		net.inventory_action.rpc_id(1, Net.ACT_CHEST_PUT, slot, chest_id, inventory.counts[slot], Vector3.ZERO)

		if chest_event.is_valid() and _world.has(chest_id):
			chest_event.call("put", _world[chest_id]["pos"])


func _refresh_chest() -> void:
	if not chest_mode or _chest_panel == null:
		return

	var capacity: int = int(table.entry(table.id_of(int(_world.get(chest_id, {}).get("number", 0)))).get("slots", inventory.SLOTS))

	for i in inventory.SLOTS:
		_chest_buttons[i].visible = i < capacity

		for pair in [[_chest_buttons, chest_inv], [_pack_buttons, inventory]]:
			var button: Button = pair[0][i]
			var source = pair[1]
			var number: int = source.numbers[i]
			button.text = "" if number == 0 else "%s\nx%d" % [table.name_of(number), source.counts[i]]
			button.tooltip_text = _tooltip(number, source.counts[i])


func _on_world_items(added: Array, removed: PackedInt32Array) -> void:
	for id in removed:
		_forget(id)

	for row in added:
		var id: int = row[0]
		var state: int = int(row[4]) if row.size() > 4 else 0

		if _world.has(id):
			_world[id]["count"] = row[2]

			if _world[id]["state"] == state:
				continue

			_forget(id)

		var node: Node3D
		var light: OmniLight3D = null

		if state >= 5:
			var yaw: float = deg_to_rad(float(row[5].get("yaw", 0.0))) if row.size() > 5 else 0.0
			node = _make_leanto() if state == 5 else (_make_chest() if state == 6 else _make_block())
			node.position = row[3]
			node.rotation.y = yaw
			_root.add_child(node)
			var roof_key: int = -1

			if state == 5 and cover_index != null:
				roof_key = cover_index.add_roof(CoverScript.box_roof(Vector2(row[3].x, row[3].z), 1.1, 0.95, yaw, row[3].y - 0.5, row[3].y + 2.1))

			_world[id] = {"node": node, "number": row[1], "count": 1, "pos": row[3], "state": state, "light": null, "roof": roof_key}
			continue

		if state >= 3:
			var extra: Dictionary = row[5] if row.size() > 5 else {}
			node = _make_felled(state == 3, extra)
			node.position = row[3]
			_root.add_child(node)
			_world[id] = {"node": node, "number": 0, "count": 1, "pos": row[3], "state": state, "light": null, "extra": extra}
			continue

		if state == 0:
			var box: MeshInstance3D = MeshInstance3D.new()
			box.mesh = _mesh_for(row[1])
			node = box
			node.position = row[3] + Vector3(0.0, 0.12, 0.0)
		else:
			node = _make_fire(state == 1)
			node.position = row[3]
			light = node.get_node_or_null("Light")

		_root.add_child(node)
		_world[id] = {"node": node, "number": row[1], "count": row[2], "pos": row[3], "state": state, "light": light}


# Removes a world row's node and, for a lean-to, its roof in the cover index.
func _forget(id: int) -> void:
	if not _world.has(id):
		return

	var entry: Dictionary = _world[id]

	if int(entry.get("roof", -1)) >= 0 and cover_index != null:
		cover_index.remove_roof(int(entry["roof"]))

	entry["node"].queue_free()
	_world.erase(id)


# A lean-to shelter: a slanted roof of branches and leaves on two front poles, open at the front (+Z).
func _make_leanto() -> Node3D:
	var root: Node3D = Node3D.new()
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.25, 0.14)
	var leaf: StandardMaterial3D = StandardMaterial3D.new()
	leaf.albedo_color = Color(0.22, 0.34, 0.14)

	for x in [-1.0, 1.0]:
		var pole: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.06
		mesh.bottom_radius = 0.07
		mesh.height = 2.0
		mesh.material = wood
		pole.mesh = mesh
		pole.position = Vector3(x, 1.0, 0.85)
		root.add_child(pole)

	var roof: MeshInstance3D = MeshInstance3D.new()
	var roof_mesh: BoxMesh = BoxMesh.new()
	roof_mesh.size = Vector3(2.5, 0.1, 2.3)
	roof_mesh.material = leaf
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, 1.45, 0.0)
	roof.rotation.x = atan2(1.3, 1.9)       # high at the front, low at the back
	root.add_child(roof)
	var back: MeshInstance3D = MeshInstance3D.new()
	var back_mesh: BoxMesh = BoxMesh.new()
	back_mesh.size = Vector3(2.3, 0.9, 0.08)
	back_mesh.material = leaf
	back.mesh = back_mesh
	back.position = Vector3(0.0, 0.45, -0.9)
	root.add_child(back)
	return root


# A chopping block: a stump stood on end with a chopped top and an axe cut across it.
func _make_block() -> Node3D:
	var root: Node3D = Node3D.new()
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.28, 0.16)
	var top: StandardMaterial3D = StandardMaterial3D.new()
	top.albedo_color = Color(0.62, 0.48, 0.3)
	var body: MeshInstance3D = MeshInstance3D.new()
	var body_mesh: CylinderMesh = CylinderMesh.new()
	body_mesh.top_radius = 0.3
	body_mesh.bottom_radius = 0.34
	body_mesh.height = 0.55
	body_mesh.material = wood
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.275, 0.0)
	root.add_child(body)
	var face: MeshInstance3D = MeshInstance3D.new()
	var face_mesh: CylinderMesh = CylinderMesh.new()
	face_mesh.top_radius = 0.29
	face_mesh.bottom_radius = 0.29
	face_mesh.height = 0.02
	face_mesh.material = top
	face.mesh = face_mesh
	face.position = Vector3(0.0, 0.56, 0.0)
	root.add_child(face)
	return root


# A woven chest: a wicker basket box of twine and sticks with a lid band.
func _make_chest() -> Node3D:
	var root: Node3D = Node3D.new()
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.62, 0.5, 0.28)      # wicker: pale woven twigs
	var band: StandardMaterial3D = StandardMaterial3D.new()
	band.albedo_color = Color(0.4, 0.3, 0.16)
	var body: MeshInstance3D = MeshInstance3D.new()
	var body_mesh: BoxMesh = BoxMesh.new()
	body_mesh.size = Vector3(0.9, 0.55, 0.55)
	body_mesh.material = wood
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.275, 0.0)
	root.add_child(body)
	var lid: MeshInstance3D = MeshInstance3D.new()
	var lid_mesh: BoxMesh = BoxMesh.new()
	lid_mesh.size = Vector3(0.94, 0.08, 0.6)
	lid_mesh.material = band
	lid.mesh = lid_mesh
	lid.position = Vector3(0.0, 0.58, 0.0)
	root.add_child(lid)
	return root


# A campfire: a ring of stones, charred sticks and, while lit, a flame and a warm light.
# Only the nearest MAX_FIRE_LIGHTS lit fires keep their light on (cost cap at every quality).
func _make_fire(lit: bool) -> Node3D:
	var fire: Node3D = Node3D.new()
	var stone_material: StandardMaterial3D = StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.42, 0.42, 0.44)

	for n in range(7):
		var stone: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 0.13
		mesh.height = 0.2
		mesh.material = stone_material
		stone.mesh = mesh
		var angle: float = TAU * float(n) / 7.0
		stone.position = Vector3(cos(angle) * 0.42, 0.08, sin(angle) * 0.42)
		fire.add_child(stone)

	var log_mesh: CylinderMesh = CylinderMesh.new()
	log_mesh.top_radius = 0.05
	log_mesh.bottom_radius = 0.05
	log_mesh.height = 0.7
	var char_material: StandardMaterial3D = StandardMaterial3D.new()
	char_material.albedo_color = Color(0.12, 0.09, 0.07) if not lit else Color(0.25, 0.15, 0.08)
	log_mesh.material = char_material

	for n in range(3):
		var stick: MeshInstance3D = MeshInstance3D.new()
		stick.mesh = log_mesh
		stick.rotation = Vector3(deg_to_rad(90.0), 0.0, deg_to_rad(60.0 * float(n)))
		stick.position = Vector3(0.0, 0.1, 0.0)
		fire.add_child(stick)

	if lit:
		var flame: MeshInstance3D = MeshInstance3D.new()
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.2
		cone.height = 0.7
		var glow: StandardMaterial3D = StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.55, 0.15)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.5, 0.1)
		glow.emission_energy_multiplier = 2.0
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cone.material = glow
		flame.mesh = cone
		flame.position = Vector3(0.0, 0.45, 0.0)
		fire.add_child(flame)
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Light"
		light.light_color = Color(1.0, 0.62, 0.3)
		light.omni_range = 12.0
		light.light_energy = 1.6
		light.shadow_enabled = false
		light.position = Vector3(0.0, 0.8, 0.0)
		light.visible = false
		fire.add_child(light)

	return fire


func _mesh_for(number: int) -> Mesh:
	if not _meshes.has(number):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.28, 0.2, 0.28)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color.from_hsv(fmod(float(number) * 0.137, 1.0), 0.5, 0.8)
		mesh.material = material
		_meshes[number] = mesh

	return _meshes[number]


# The crafting and inventory screen, laid out like Ark's (Dave, 2026-10-20): recipes on the left,
# the inventory on the right, one search box filtering both. Recipes you can make now are lit and
# sit at the top; the rest are greyed out below, each group alphabetical. About 3/4 of the screen,
# with text sized for a 55 inch 4K TV at 1080p: sizes scale with the window height (1080 = 1.0).
const BODY_PX := 30
const TITLE_PX := 40

var _search: LineEdit
var _recipe_list: VBoxContainer
var _detail: VBoxContainer
var _selected_recipe: int = 0
var _quantity: SpinBox
var _qty: int = 1
var knowledge                          # InspectionKnowledge (set by the client): item names follow what the character knows
var max_lights: Callable               # () -> how many fire lights the quality tier allows
var is_inspecting: Callable            # () -> true while inspection mode is on
var _craft_queue: int = 0             # crafts still to do after the one running
var _slot_scroll: ScrollContainer


func _px(size: int) -> int:
	return int(round(float(size) * maxf(_layer.get_viewport().get_visible_rect().size.y / 1080.0, 0.5)))


func _style(control: Control, size: int) -> void:
	control.add_theme_font_size_override("font_size", _px(size))


func _build_panel() -> void:
	if _panel != null:
		return

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.125
	_panel.anchor_right = 0.875
	_panel.anchor_top = 0.1
	_panel.anchor_bottom = 0.9
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color(0.07, 0.07, 0.08, 0.93)
	back.set_corner_radius_all(10)
	back.set_content_margin_all(_px(18))
	_panel.add_theme_stylebox_override("panel", back)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", _px(10))
	_panel.add_child(box)
	var top: HBoxContainer = HBoxContainer.new()
	box.add_child(top)
	var title: Label = Label.new()
	title.text = "Crafting and inventory"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(title, TITLE_PX)
	top.add_child(title)
	_search = LineEdit.new()
	_search.placeholder_text = "Search recipes and items"
	_search.custom_minimum_size = Vector2(_px(560), 0.0)
	_search.clear_button_enabled = true
	_style(_search, BODY_PX)
	_search.text_changed.connect(func(_text): _refresh())
	top.add_child(_search)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", _px(24))
	box.add_child(columns)

	# Left: recipes, then the chosen recipe's needs and the Craft button.
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	columns.add_child(left)
	var left_title: Label = Label.new()
	left_title.text = "Make"
	_style(left_title, TITLE_PX - 6)
	left.add_child(left_title)
	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(list_scroll)
	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_recipe_list)
	_detail = VBoxContainer.new()
	left.add_child(_detail)

	# Right: the inventory slots.
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	columns.add_child(right)
	var right_title: Label = Label.new()
	right_title.text = "Inventory"
	_style(right_title, TITLE_PX - 6)
	right.add_child(right_title)
	_weight_label = Label.new()
	_style(_weight_label, BODY_PX - 6)
	_weight_label.text = "Body weight %.1f kg" % weight_kg
	right.add_child(_weight_label)
	_slot_scroll = ScrollContainer.new()
	_slot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_slot_scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", _px(8))
	_grid.add_theme_constant_override("v_separation", _px(8))
	_slot_scroll.add_child(_grid)

	for i in inventory.SLOTS:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0.0, _px(88))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		_style(button, BODY_PX - 4)
		button.pressed.connect(_on_slot_pressed.bind(i))
		_grid.add_child(button)
		_buttons.append(button)
		var bar: ColorRect = ColorRect.new()          # condition bar along the bottom of a worn tool's slot
		bar.name = "Condition"
		bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = -_px(8)
		bar.offset_left = _px(4)
		bar.offset_bottom = -_px(3)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		button.add_child(bar)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(12))
	right.add_child(row)

	var split: Button = Button.new()
	split.text = "Split half"
	_style(split, BODY_PX)
	split.pressed.connect(_split_selected)
	row.add_child(split)

	var eat: Button = Button.new()
	eat.text = "Eat / use"
	_style(eat, BODY_PX)
	eat.pressed.connect(func(): eat_slot(_selected))
	row.add_child(eat)

	var repair: Button = Button.new()
	repair.text = "Repair"
	_style(repair, BODY_PX)
	repair.pressed.connect(_repair_selected)
	row.add_child(repair)

	for whole in [true, false]:
		var drop: Button = Button.new()
		drop.text = "Drop stack" if whole else "Drop one"
		_style(drop, BODY_PX)
		drop.pressed.connect(_drop_selected.bind(whole))
		row.add_child(drop)

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


func _select_recipe(number: int) -> void:
	_selected_recipe = number
	_refresh()


# Craft the chosen recipe `quantity` times, one at a time (each takes its craft_s).
func _craft_selected() -> void:
	if _crafting != 0 or _selected_recipe == 0 or not recipes.can_make(_selected_recipe, inventory):
		return

	_craft_queue = int(_quantity.value) - 1 if _quantity != null else 0
	_start_craft(_selected_recipe)


func _start_craft(number: int) -> void:
	if _crafting != 0 or not recipes.can_make(number, inventory):
		return

	for item in recipes.recipe(number).get("identify", []):
		if knowledge != null and not knowledge.is_known("i%d" % item):
			_on_notice("You are not sure what %s really is. Hover it in inspection mode (/) before you use it." % table.name_of(item).to_lower())
			_craft_queue = 0
			return

	_crafting = number
	_craft_done_msec = Time.get_ticks_msec() + int(recipes.recipe(number)["craft_s"] * 1000.0)


func _repair_selected() -> void:
	if _selected < 0 or inventory.wear[_selected] <= 0:
		return

	net.inventory_action.rpc_id(1, Net.ACT_REPAIR, _selected, 0, 0, Vector3.ZERO)


func _split_selected() -> void:
	if _selected < 0 or inventory.counts[_selected] < 2:
		return

	net.inventory_action.rpc_id(1, Net.ACT_SPLIT, _selected, 0, inventory.counts[_selected] / 2, Vector3.ZERO)
	_selected = -1


# Hover text for a slot. In inspection mode the name follows what the character knows (the truth,
# "Unknown", or a sticky wrong guess drawn from the item's look-alike list); otherwise it is the plain name.
# The item's name as this character sees it: plain, or in inspection mode the truth, "Unknown" or a
# sticky wrong guess drawn from the look-alike list. Items with no look-alikes are always known.
func _item_label(number: int) -> String:
	var name: String = table.name_of(number)
	var entry: Dictionary = table.entry(table.id_of(number))

	if knowledge != null and is_inspecting.is_valid() and bool(is_inspecting.call()) and not entry.get("look_alikes", []).is_empty():
		return knowledge.reveal("i%d" % number, name, int(entry.get("familiarity", 100)), "horticulture", entry.get("look_alikes", []))

	return name


func _tooltip(number: int, count: int) -> String:
	if number == 0:
		return ""

	var entry: Dictionary = table.entry(table.id_of(number))
	var name: String = _item_label(number)

	var text: String = "%s x%d\n%s, stacks to %d" % [name, count, str(entry.get("kind", "item")), table.stack_of(number)]

	var kcal: int = VitalsRules.food_value(table.id_of(number), _vitals_cfg)
	var heal: int = VitalsRules.heal_value(table.id_of(number), _vitals_cfg)

	if kcal > 0:
		text += "\n%d kcal  (right click when held, or Eat / use)" % kcal

	if heal > 0:
		text += "\nrestores %d health  (right click when held, or Eat / use)" % heal

	if int(entry.get("durability", 0)) > 0:
		text += "\nlasts %d uses; repair: " % int(entry["durability"])
		var parts: PackedStringArray = PackedStringArray()

		for cost in entry.get("repair", []):
			parts.append("%d %s" % [int(cost[1]), table.name_of(table.number_of(str(cost[0]))).to_lower()])

		text += ", ".join(parts)

	return text


func _drop_selected(whole: bool) -> void:
	if _selected < 0 or inventory.numbers[_selected] == 0:
		return

	var here: Vector3 = _player_position.call()
	var ground: float = _ground_below.call(here)
	var at: Vector3 = Vector3(here.x, ground if not is_nan(ground) else here.y - 1.0, here.z)
	net.inventory_action.rpc_id(1, Net.ACT_DROP, _selected, 0, inventory.counts[_selected] if whole else 1, at)
	_selected = -1


func _matches(text: String, filter: String) -> bool:
	return filter == "" or text.to_lower().contains(filter)


func _recipe_matches(r: Dictionary, filter: String) -> bool:
	if _matches(str(r["name"]), filter) or _matches(table.name_of(r["gives"][0]), filter):
		return true

	for need in r["needs"] + r["keeps"]:
		if _matches(table.name_of(need[0]), filter):
			return true

	return false


func _refresh() -> void:
	if _panel == null:
		return

	var filter: String = _search.text.strip_edges().to_lower() if _search != null else ""

	# Inventory slots: with a search, only slots that match; otherwise every slot.
	for i in inventory.SLOTS:
		var button: Button = _buttons[i]
		var number: int = inventory.numbers[i]
		button.text = "" if number == 0 else "%s\nx%d" % [_item_label(number), inventory.counts[i]]
		var bar: ColorRect = button.get_node("Condition")
		var worn: bool = number != 0 and int(table.entry(table.id_of(number)).get("durability", 0)) > 0 and inventory.wear[i] > 0
		bar.visible = worn

		if worn:
			var c: float = condition(i)
			bar.anchor_right = maxf(c, 0.04)
			bar.color = Color(0.85, 0.2, 0.15) if c <= 0.0 else Color(1.0 - c, 0.2 + 0.7 * c, 0.15)
			bar.anchor_left = 0.0
			bar.offset_right = -_px(4)
			button.text += "   BROKEN" if is_broken(i) else "   %d%%" % int(c * 100.0)
		button.modulate = Color(1.0, 0.9, 0.5) if i == _selected else Color.WHITE
		button.visible = filter == "" or (number != 0 and _matches(table.name_of(number), filter))
		button.tooltip_text = _tooltip(number, inventory.counts[i])

	# Recipes: makeable first, then the rest, each alphabetical.
	for child in _recipe_list.get_children():
		child.queue_free()

	var can: Array = []
	var cannot: Array = []

	for number in recipes.numbers():
		var r: Dictionary = recipes.recipe(number)

		if not r["known"] or not _recipe_matches(r, filter):
			continue

		(can if recipes.can_make(number, inventory) else cannot).append(r)

	var by_name: Callable = func(a, b): return str(a["name"]) < str(b["name"])
	can.sort_custom(by_name)
	cannot.sort_custom(by_name)

	if _selected_recipe == 0 or recipes.recipe(_selected_recipe).is_empty():
		_selected_recipe = can[0]["number"] if not can.is_empty() else (cannot[0]["number"] if not cannot.is_empty() else 0)

	for r in can + cannot:
		var makeable: bool = recipes.can_make(r["number"], inventory)
		var entry: Button = Button.new()
		entry.text = str(r["name"])
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.custom_minimum_size = Vector2(0.0, _px(64))
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.modulate = Color.WHITE if makeable else Color(1.0, 1.0, 1.0, 0.38)
		entry.flat = r["number"] != _selected_recipe
		_style(entry, BODY_PX)
		entry.pressed.connect(_select_recipe.bind(r["number"]))
		_recipe_list.add_child(entry)

	_refresh_detail()


# The chosen recipe: what it needs (have / need), how many, and the Craft button.
func _refresh_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()

	_quantity = null
	var r: Dictionary = recipes.recipe(_selected_recipe)

	if r.is_empty():
		return

	var heading: Label = Label.new()
	heading.text = "%s  ->  %s" % [r["name"], table.name_of(r["gives"][0])]
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style(heading, BODY_PX)
	_detail.add_child(heading)

	for need in r["needs"] + r["keeps"]:
		var kept: bool = r["keeps"].has(need)
		var have: int = inventory.count_of(need[0])
		var line: Label = Label.new()
		line.text = "%s   %d / %d%s" % [_item_label(need[0]), have, need[1], "  (kept)" if kept else ""]
		line.modulate = Color(0.6, 1.0, 0.6) if have >= need[1] else Color(1.0, 0.55, 0.5)
		_style(line, BODY_PX)
		_detail.add_child(line)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(12))
	_detail.add_child(row)
	var times: Label = Label.new()
	times.text = "How many:"
	_style(times, BODY_PX)
	row.add_child(times)
	_quantity = SpinBox.new()
	_quantity.min_value = 1
	_quantity.max_value = 20
	_quantity.value = _qty
	_quantity.value_changed.connect(func(v): _qty = int(v))
	_quantity.get_line_edit().add_theme_font_size_override("font_size", _px(BODY_PX))
	row.add_child(_quantity)
	var make: Button = Button.new()
	make.text = "Craft  (%.0f s)" % float(r["craft_s"])
	make.disabled = not recipes.can_make(_selected_recipe, inventory) or _crafting != 0
	make.custom_minimum_size = Vector2(_px(240), _px(64))
	_style(make, BODY_PX)
	make.pressed.connect(_craft_selected)
	row.add_child(make)
	_craft_label = Label.new()
	_style(_craft_label, BODY_PX)
	_detail.add_child(_craft_label)


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
	toggle()
	_search.text = "stone"
	_refresh()
	var shown: int = 0

	for child in _recipe_list.get_children():
		if not child.is_queued_for_deletion():
			shown += 1

	print("Items test: panel open, recipes shown for 'stone' %d, selected %d" % [shown, _selected_recipe])
	_search.text = ""
	_refresh()
	toggle()
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
	await get_tree().create_timer(0.6).timeout
	print("Gather test: prompt \"%s\"" % plant_hint)
	client.harvest.tap()
	await get_tree().create_timer(2.0).timeout
	print("Gather test: sticks %d -> %d; loose things in view %d" % [before, inventory.count_of(sticks), _world.size()])
	var after_tap: int = inventory.count_of(sticks)
	client.harvest.update(0.0, true)
	client.harvest.update(0.5, true)
	client.harvest.update(0.3, true)
	await get_tree().create_timer(1.5).timeout
	print("Gather test: sweep, sticks %d -> %d (a picked-bare shrub is skipped); prompt \"%s\"" % [after_tap, inventory.count_of(sticks), plant_hint])


# Headless check (--leanto): place a lean-to ahead of the player and look for its row and its roof.
func run_leanto_test(client) -> void:
	await get_tree().create_timer(6.0).timeout
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("lean_to_kit"), 0, 1, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	var here: Vector3 = _player_position.call()
	var ground: float = float(_ground_below.call(here + Vector3(2.0, 0.0, 0.0)))
	var spot: Vector3 = Vector3(here.x + 2.0, ground, here.z)
	var slot: int = inventory.numbers.find(table.number_of("lean_to_kit"))
	net.inventory_action.rpc_id(1, Net.ACT_PLACE, slot, 0, 0, spot)
	await get_tree().create_timer(2.0).timeout
	var seen: int = 0

	for id in _world:
		if _world[id]["state"] == 5:
			seen += 1

	var under: Vector3 = spot + Vector3(0.0, 1.0, 0.0)
	print("Lean-to test: %d lean-to rows in view, cover under it %s, in the open %s" % [seen, str(CoverScript.at(under, cover_index)), str(CoverScript.at(under + Vector3(8.0, 0.0, 0.0), cover_index))])


# Headless check (--eat): eat a roast and apply a poultice.
func run_eat_test(client) -> void:
	await get_tree().create_timer(6.0).timeout
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("roast_forage"), 0, 2, Vector3.ZERO)
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("poultice"), 0, 1, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	print("Eat test: start hunger %d health %d weight %.1f; edible slot 0 %s" % [hunger, health, weight_kg, str(edible_slot(0))])
	eat_slot(inventory.numbers.find(table.number_of("roast_forage")))
	await get_tree().create_timer(1.0).timeout
	print("Eat test: after a roast, hunger %d, roasts left %d" % [hunger, inventory.count_of(table.number_of("roast_forage"))])
	eat_slot(inventory.numbers.find(table.number_of("poultice")))
	await get_tree().create_timer(1.0).timeout
	print("Eat test: poultice left %d, health %d" % [inventory.count_of(table.number_of("poultice")), health])


# Headless check (--chest): place a chest, open it, put stones in, take them out.
func run_chest_test(client) -> void:
	await get_tree().create_timer(6.0).timeout
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("chest_kit"), 0, 1, Vector3.ZERO)
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("stone"), 0, 10, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	var here: Vector3 = _player_position.call()
	var spot: Vector3 = Vector3(here.x + 2.0, float(_ground_below.call(here + Vector3(2.0, 0.0, 0.0))), here.z)
	net.inventory_action.rpc_id(1, Net.ACT_PLACE, inventory.numbers.find(table.number_of("chest_kit")), 0, 0, spot)
	await get_tree().create_timer(2.0).timeout
	var id: int = 0

	for k in _world:
		if _world[k]["state"] == 6:
			id = k

	net.inventory_action.rpc_id(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	var stone: int = table.number_of("stone")
	net.inventory_action.rpc_id(1, Net.ACT_CHEST_PUT, inventory.numbers.find(stone), id, 7, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	print("Chest test: chest row %d, screen open %s, stones in chest %d, in pack %d" % [id, str(chest_mode), chest_inv.count_of(stone) if chest_inv != null else -1, inventory.count_of(stone)])
	net.inventory_action.rpc_id(1, Net.ACT_CHEST_TAKE, chest_inv.numbers.find(stone), id, 7, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	print("Chest test: after taking out, stones in chest %d, in pack %d" % [chest_inv.count_of(stone), inventory.count_of(stone)])


# Headless check (--chop): stand by the nearest tree with an axe and chop it down.
func run_chop_test(client) -> void:
	await get_tree().create_timer(6.0).timeout
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	var here: Vector3 = _player_position.call()
	var best: Array = []

	for chunk in client.flora._chunks:
		var held: Dictionary = client.flora._chunks[chunk]["items"]

		for n in range(held["ids"].size()):
			if client.flora._species.get(held["ids"][n] >> 16, {}).get("kind", 2) == 0:
				var d: float = held["positions"][n].distance_to(here)

				if best.is_empty() or d < best[0]:
					best = [d, chunk, held["ids"][n], held["positions"][n]]

	if best.is_empty():
		print("Chop test: no tree loaded")
		return

	client.body.global_position = best[3] + Vector3(1.5, 1.0, 0.0)
	client.body.velocity = Vector3.ZERO
	await get_tree().create_timer(3.0).timeout
	var blows: int = 0

	for n in range(60):
		net.inventory_action.rpc_id(1, Net.ACT_HIT, best[2], best[1].x, best[1].y, Vector3.ZERO)
		blows += 1
		await get_tree().create_timer(0.45).timeout
		var states: Array = []

		for id in _world:
			if _world[id]["state"] >= 3:
				states.append(_world[id]["state"])

		if not states.is_empty():
			break

	var kinds: Array = []

	for id in _world:
		if _world[id]["state"] >= 3:
			kinds.append(_world[id]["state"])

	print("Chop test: %d blows, felled states in view %s" % [blows, str(kinds)])
