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
const CharacterScreenScript := preload("res://src/client/character_screen.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
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
var _hover: int = -1                   # pack slot under the mouse (quick keys act on it, else on the selected slot)
var _chest_last: Array = []            # the last chest-screen slot the mouse was on (the Transfer button uses it)
var _chest_hover: Array = []           # [chest side (bool), slot] under the mouse in the chest screen
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
var fitness: int = 0                  # the character's fitness, -10 to 10: how slowly exertion rises (character screen)
var luck: int = 0                     # the character's luck, -10 to 10, fixed (character screen)
var thirst: int = 100                  # body water, percent (100 = full; 0 = parched)
var health: int = 100
var weight_kg: float = 75.0
var _vitals_cfg: Dictionary = {}
var _carry_cfg: Dictionary = {}
var _exertion_cfg: Dictionary = {}

# Over-exertion from the server (data/items/exertion.json). Sounds and Art read these:
#   strain       0 and up, 1.0 = over-exerted (no ceiling)
#   strain_state 0 normal, 1 over-exerted (10 percent slower, running on allowed), 2 fainted, 3 waking
#   strain_fade  0..1: fainted, how much of the faint is gone (vision fades over the first
#                vision_frac, then the heartbeat); waking, how much of the blackness is left
var strain: float = 0.0
var strain_state: int = 0
var strain_fade: float = 0.0
var stance_confirmed: int = 0                # the server's answer: 0 stand, 1 crouch, 2 sit, 3 lie (fainting forces 3)
var stance_event: Callable = Callable()      # (stance) when the server confirms or changes it
var reject_event: Callable = Callable()   # ("far" | "no_tool" | "full_pack" | "other") when the server refused an action
var strain_event: Callable = Callable()   # (strain, state, fade) whenever the server sends a change
var _strain_note: Label
var _eat_item: String = ""
var equip_requested: Callable = Callable()   # (slot) -> hold that tool, or put it away (the client wires it to the held item)
var held_slot_now: Callable = Callable()     # () -> the pack slot in hand, or -1 for empty hands
var hotbar_strip                              # HotbarStrip, set by the client
var heart_bpm: Callable = Callable()   # () -> the heart rate now (the heartbeat sound's), set by the client
var _character                         # CharacterScreen, built the first time Tab is pressed
var _panel_bars: Dictionary = {}       # "Health", "Exertion", "Hunger", "Thirst" -> ProgressBar at the top of the inventory screen (the only bars in the game)
var _vitals_back: Control
var _vitals_warning: Label
var _weight_label: Label
var _carry_bar: ProgressBar              # carried weight against what you can carry: green, yellow from 70 percent, red from 80
var plant_hint: String = ""            # set by the harvest prompt (harvest.gd)
var _crafting: int = 0                # recipe at the head of the server's queue (0 none); the work sounds follow it
var craft_entries: Array = []          # the server's crafting queue: [[recipe, crafts left], ...], head first
var _craft_head_end_msec: int = 0      # when the head craft finishes (from the server's time left)
var _queue_box: VBoxContainer
var _queue_head_button: Button
var _queue_next_msec: int = 0
var _world: Dictionary = {}        # id -> {node, number, count, pos}
var _prompt_next_msec: int = 0
var _notice_until_msec: int = 0
var _collide: Array = []              # [node, StaticBody3D] trunks whose collider is on only near the player
var _meshes: Dictionary = {}       # item number -> Mesh


const FrameProbe := preload("res://src/debug/frame_probe.gd")

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
	net.strain_received.connect(_on_strain)
	net.craft_queue_received.connect(_on_craft_queue)
	net.reject_received.connect(_on_reject)
	var exertion_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/exertion.json"))
	_exertion_cfg = exertion_parsed if typeof(exertion_parsed) == TYPE_DICTIONARY else {}
	_vitals_cfg = VitalsRules.load_config()
	_carry_cfg = CarryRules.load_config()
	_register_builtin_interactables()
	_build_vitals_hud()
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.offset_top = 90.0   # just below the crosshair
	_prompt.add_theme_font_size_override("font_size", 30)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_prompt)
	_strain_note = Label.new()
	_strain_note.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_strain_note.offset_top = 120.0
	_strain_note.offset_left = -300.0
	_strain_note.offset_right = 300.0
	_strain_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strain_note.add_theme_font_size_override("font_size", 28)
	_strain_note.add_theme_constant_override("outline_size", 6)
	_strain_note.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_strain_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_strain_note)
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

	if not open and character_open():
		_character.toggle()

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

	if character_open():
		toggle_character()


# The Tab character screen (src/client/character_screen.gd): health, exertion, heart, hunger, thirst, attributes, skills.
func toggle_character() -> void:
	if chest_mode:
		return

	if open:
		toggle()

	if _character == null:
		_character = CharacterScreenScript.new()
		_character.setup(self, _layer)

	_character.toggle()


# Called every frame by the client: the heart on the character screen beats.
func character_update(delta: float) -> void:
	if _character != null:
		_character.update(delta)


func exertion_threshold() -> float:
	return float(_exertion_cfg.get("faint_at", 1.4))


func carry_limit_kg() -> float:
	return CarryRules.cap_kg(weight_kg, _carry_cfg) if not _carry_cfg.is_empty() else 0.0


func character_open() -> bool:
	return _character != null and _character.open


func clear_prompt() -> void:
	_prompt.text = ""
	_notice_until_msec = 0
	_prompt_next_msec = Time.get_ticks_msec() + 400


# --- One interaction registry (Technical direction, 2026-10-20) ---
# E is the one interaction key. Everything E can act on registers a probe with a priority (lowest first);
# the first probe that finds something decides the single centre-screen prompt and what E does.
# A probe returns {} or {"prompt": text, "tap": Callable, "hold": Callable (optional)}. With a "hold",
# a tap acts on release and a hold (HOLD_E_S) does the other thing; without one the tap acts at once.
const HOLD_E_S: float = 0.6
var fuel_event: Callable = Callable()
var _interactables: Array = []
var _e_active: Dictionary = {}
var _e_start_msec: int = 0


func register_interactable(interactable_name: String, priority: int, probe: Callable) -> void:
	_interactables.append({"name": interactable_name, "priority": priority, "probe": probe})
	_interactables.sort_custom(func(x, y): return int(x["priority"]) < int(y["priority"]))


func current_interaction() -> Dictionary:
	for entry in _interactables:
		var found: Dictionary = entry["probe"].call()

		if not found.is_empty():
			return found

	return {}


func _register_builtin_interactables() -> void:
	register_interactable("pickup", 10, _probe_pickup)
	register_interactable("fire", 20, _probe_fire)
	register_interactable("structure", 30, _probe_structure)


# Dave 2026-10-21: the prompt is only "Press E to gather", and only for what lies in the general direction you look.
var view_direction: Callable = Callable()   # () -> where the camera looks; unset (tests) counts everything as in view
const VIEW_COS := 0.35                       # about 70 degrees either side of the view direction
const VIEW_ALWAYS_M := 0.8                   # and anything this close, whatever way you face
var _sweep_blocked: bool = false
var _sweep_asked: Dictionary = {}            # world id -> msec a held-E pick was asked for


func in_view(point: Vector3) -> bool:
	if not view_direction.is_valid():
		return true

	var to: Vector3 = point - _player_position.call()

	if to.length() <= VIEW_ALWAYS_M:
		return true

	var forward: Vector3 = view_direction.call()
	return forward.length() < 0.01 or to.normalized().dot(forward.normalized()) >= VIEW_COS


func _probe_pickup() -> Dictionary:
	var near: Array = _nearest(true)

	if near[0] == 0:
		return {}

	var id: int = near[0]
	return {"prompt": "Press E to gather", "tap": func():
		clear_prompt()
		net.inventory_action.rpc_id(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)}


# Held E (harvest.gd steps this): the nearest loose item within 2 m, wherever you look, one at a time. 0 when none, when
# the pack was refused as full (until E is let go), or for an item already asked for in the last 0.6 s.
func sweep_target(radius: float) -> Array:
	if _sweep_blocked:
		return [0, 99.0]

	var here: Vector3 = _player_position.call()
	var now: int = Time.get_ticks_msec()
	var best: Array = [0, radius + 1.0]

	for id in _world:
		if _world[id]["state"] != 0 or now - int(_sweep_asked.get(id, -100000)) < 600:
			continue

		var d: float = here.distance_to(_world[id]["pos"])

		if d <= radius and d < float(best[1]):
			best = [id, d]

	return best


func sweep_pick(id: int) -> void:
	_sweep_asked[id] = Time.get_ticks_msec()
	net.inventory_action.rpc_id(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)


func sweep_reset() -> void:
	_sweep_blocked = false
	_sweep_asked.clear()


# The refusal cue (a missing tool and the like), the same one the server's reject event plays.
func refuse_cue(reason: String) -> void:
	if reject_event.is_valid():
		reject_event.call(reason)


func _probe_fire() -> Dictionary:
	var id: int = _nearest_fire()

	if id == 0:
		return {}

	var state: int = _world[id]["state"]
	var found: Dictionary = {"prompt": _fire_prompt(state), "tap": func():
		if state == 9:
			net.inventory_action.rpc_id(1, Net.ACT_LIGHT, id, 0, 0, Vector3.ZERO)
		else:
			fuel_nearest()

			if fuel_event.is_valid():
				fuel_event.call()}

	if state == 1:
		found["hold"] = cook_nearest
	elif state == 9:
		found["hold"] = fuel_nearest

	return found


func _probe_structure() -> Dictionary:
	var id: int = _nearest_struct()

	if id == 0:
		return {}

	var state: int = _world[id]["state"]
	var take_down: Callable = func():
		clear_prompt()
		net.inventory_action.rpc_id(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)

	if state == 6:
		return {"prompt": "Press E to open the chest    (hold E: take it down, empty only)", "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO), "hold": take_down}

	if state == 7:
		return {"prompt": "Press E to split a log into firewood    (hold E to keep going, needs an axe; Shift+E: take it down)", "tap": pick_up_nearest}

	return {"prompt": "Hold E to take down the %s" % table.name_of(_world[id]["number"]).to_lower(), "tap": func(): show_notice("Hold E to take it down"), "hold": take_down}


func press_e() -> bool:
	var found: Dictionary = current_interaction()

	if found.is_empty():
		return false

	if found.has("hold"):
		_e_active = found
		_e_start_msec = Time.get_ticks_msec()
	else:
		found["tap"].call()

	return true


func release_e() -> void:
	if _e_active.is_empty():
		return

	var found: Dictionary = _e_active
	_e_active = {}
	found["tap"].call()


func _hold_e_check() -> void:
	if _e_active.is_empty() or not Input.is_key_pressed(KEY_E):
		return

	if Time.get_ticks_msec() - _e_start_msec < int(HOLD_E_S * 1000.0):
		return

	var found: Dictionary = _e_active
	_e_active = {}
	found["hold"].call()


# What E will do at a fire (Dave 2026-10-20): empty -> add firewood, loaded -> light, burning -> more wood.
func _fire_prompt(state: int) -> String:
	if state == 8:
		return "Press E to add firewood"

	if state == 9:
		return "Press E to light    (needs plant fibre; hold E: add more wood)"

	return "Press E to add wood    (hold E: roast food)"


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
	var t: int = FrameProbe.start()
	_process_body(_delta)
	FrameProbe.stop("inventory view", t)


func _process_body(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	_hold_e_check()

	if _strain_note != null:
		_strain_note.text = "You are exhausted: slow down" if strain_state == 1 else ""

	if _queue_head_button != null and now >= _queue_next_msec:
		_queue_next_msec = now + 250
		_queue_head_button.text = _queue_text(0)

	if now < _prompt_next_msec:
		return

	_prompt_next_msec = now + 200
	_update_fire_lights()
	_update_trunk_colliders()

	if now < _notice_until_msec:
		return
	_prompt.text = str(current_interaction().get("prompt", ""))



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
		if _world[id]["state"] in [1, 8, 9] and here.distance_to(_world[id]["pos"]) <= best_d:
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
func _nearest(view_only: bool = false) -> Array:
	var here: Vector3 = _player_position.call()
	var best: Array = [0, 0, 0]
	var best_d: float = PICKUP_M

	for id in _world:
		if _world[id]["state"] != 0 or (view_only and not in_view(_world[id]["pos"])):
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


# Is a tool of this class on the hotbar (slots 1 to 9 and 0), the way the server checks it?
func has_tool_class(tool_class: String) -> bool:
	for slot in range(10):
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
	refresh_hotbar()


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
	refresh_hotbar()


# --- The chest screen: the chest on the left, the pack on the right; a click moves a whole stack ---

# --- Hunger and health HUD, eating ---

func _build_vitals_hud() -> void:
	_vitals_back = Control.new()
	_vitals_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals_back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_layer.add_child(_vitals_back)
	_vitals_warning = Label.new()
	_vitals_warning.add_theme_font_size_override("font_size", 28)
	_vitals_warning.add_theme_constant_override("outline_size", 5)
	_vitals_warning.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_vitals_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals_back.add_child(_vitals_warning)
	_place_vitals()


func _place_vitals() -> void:
	var scale: float = maxf(_layer.get_viewport().get_visible_rect().size.y / 1080.0, 0.5)
	_vitals_back.position = Vector2(24.0 * scale, -(170.0 * scale))
	_vitals_warning.position = Vector2.ZERO
	var warn: int = int(_vitals_cfg.get("warn_hunger", 15))
	var warn_thirst: int = int(_vitals_cfg.get("warn_thirst", 15))
	var lines: Array = []

	if hunger <= 0:
		lines.append("You are starving: you recover slowly")
	elif hunger <= warn:
		lines.append("You are hungry")

	if thirst <= 0:
		lines.append("You are parched: you do not recover")
	elif thirst <= warn_thirst:
		lines.append("You are thirsty")

	_vitals_warning.text = "\n".join(lines)

	if _weight_label != null:
		_refresh_weight()


# Kilograms in the pack (the server counts the same way).
func carried_kg() -> float:
	return CarryRules.carried_kg(inventory, table, _carry_cfg) if not _carry_cfg.is_empty() else 0.0


# Walking speed multiplier for the load: 1 when comfortable, easing down past it.
func speed_factor() -> float:
	return CarryRules.speed_factor(carried_kg(), weight_kg, _carry_cfg) if not _carry_cfg.is_empty() else 1.0


func _refresh_weight() -> void:
	_weight_label.text = _load_text() + "\nBody weight %.1f kg   (hunger %d%%, health %d)" % [weight_kg, hunger, health]

	if _carry_bar != null and not _carry_cfg.is_empty():
		var fraction: float = CarryRules.bar_fraction(carried_kg(), weight_kg, _carry_cfg)
		_carry_bar.value = fraction * 100.0
		_carry_bar.get_theme_stylebox("fill").bg_color = CarryRules.bar_color(fraction)


func _load_text() -> String:
	var load_kg: float = carried_kg()
	var free: float = CarryRules.comfort_kg(weight_kg, _carry_cfg)
	var limit: float = CarryRules.cap_kg(weight_kg, _carry_cfg)
	var state: String = "" if load_kg <= free else ("   (heavy: you move slower)" if load_kg < limit else "   (at the limit)")
	return "Carrying %.1f kg of %.0f kg you can carry%s" % [load_kg, limit, state]


func _on_strain(strain_pm: int, state: int, fade_pm: int, stance: int) -> void:
	strain = float(strain_pm) / 1000.0
	strain_state = state
	strain_fade = float(fade_pm) / 1000.0
	stance_confirmed = stance
	_update_panel_bars()

	if _character != null:
		_character.refresh()

	if stance_event.is_valid():
		stance_event.call(stance)

	if strain_event.is_valid():
		strain_event.call(strain, state, strain_fade)


# Ask the server for a stance (0 stand, 1 crouch, 2 sit, 3 lie). It answers through stance_confirmed / stance_event.
func request_stance(wanted: int) -> void:
	net.inventory_action.rpc_id(1, Net.ACT_STANCE, wanted, 0, 0, Vector3.ZERO)


# Movement the over-exertion allows: -1 none (fainted or waking), else a speed cap in m/s (0 = no cap).
func move_cap() -> float:
	if strain_state >= 2:
		return -1.0

	# Over-exerted is only a slow-down (over_speed_factor, see over_pace_factor); running on is allowed until the blackout.
	return 0.0


# Over-exerted (Dave 2026-10-21): the pace is cut by about 10 percent but the player may keep running and keep pushing the
# exertion up until they black out.
func over_pace_factor() -> float:
	return float(_exertion_cfg.get("over_speed_factor", 0.9)) if strain_state == 1 else 1.0


# The blackout level, 0 to 1: rising while strain is over the faint threshold (slowly at the threshold, faster the further
# over it), 1 while fainted, falling as the character wakes. Sounds scale the heartbeat with it.
func blackout_level() -> float:
	if strain_state == 2:
		return 1.0

	return clampf(strain_fade, 0.0, 1.0) if strain_state == 1 or strain_state == 3 else 0.0


# The picture's state name and progress for faint.set_state (Art's faint_effect.gd): vision fades over the
# first vision_frac of a faint ("fainting", progress 0 to 1), then "fainted" holds black while only the heart is heard.
func faint_state() -> Array:
	if strain_state == 2:
		return ["fainted", 1.0]

	if strain_state == 1 and strain_fade > 0.001:
		return ["fainting", strain_fade]   # the blackout coming on, smoothly from 0 (Dave 2026-10-21)

	if strain_state == 3:
		return ["waking", strain_fade]

	return ["over_exerted" if strain_state == 1 else "normal", 0.0]


func _on_vitals(new_hunger: int, new_health: int, weight_dkg: int, new_thirst: int, new_luck: int, new_fitness: int) -> void:
	var ate: bool = new_hunger > hunger + 3 or new_health > health + 8

	if ate and _eat_item != "" and eat_event.is_valid():
		eat_event.call(_eat_item)
		_eat_item = ""

	hunger = new_hunger
	thirst = new_thirst
	luck = new_luck
	fitness = new_fitness
	health = new_health
	weight_kg = float(weight_dkg) / 10.0
	_place_vitals()
	_update_panel_bars()

	if _character != null:
		_character.refresh()


# Drink from the water at your feet (E at the water's edge; the server checks the water and paces the mouthfuls).
func drink() -> void:
	net.inventory_action.rpc_id(1, Net.ACT_DRINK, 0, 0, 0, Vector3.ZERO)


# Can this item be eaten or applied (food or medicine in data/items/vitals.json)?
func edible_slot(slot: int) -> bool:
	return slot >= 0 and slot < inventory.SLOTS and inventory.numbers[slot] != 0 and VitalsRules.edible(table.id_of(inventory.numbers[slot]), _vitals_cfg)


func equippable_slot(slot: int) -> bool:
	if slot < 0 or slot >= inventory.SLOTS or inventory.numbers[slot] == 0:
		return false

	var entry: Dictionary = table.entry(table.id_of(inventory.numbers[slot]))
	return entry.has("tool_class") or entry.has("weapon_class") or str(entry.get("kind", "")) in ["tool", "weapon", "placeable"]


# Hold a tool: from the hotbar slots straight away; from the rest of the pack it first moves into a free hotbar slot
# (or takes the place of what is in hand), so a slot key can pick it up again.
func equip_with_move(slot: int) -> void:
	var target: int = slot

	if slot >= 10:
		target = -1

		for candidate in range(10):
			if inventory.numbers[candidate] == 0:
				target = candidate
				break

		if target < 0:
			target = maxi(int(held_slot_now.call()), 0) if held_slot_now.is_valid() else 0

		move_slot(slot, target)

		# The hand may already rest on that (empty) slot: then the moved tool is simply in hand, not toggled away.
		if held_slot_now.is_valid() and int(held_slot_now.call()) == target:
			return

	equip_requested.call(target)


# Move a stack to another pack slot (dragging, or Use on a tool).
func move_slot(from_slot: int, to_slot: int) -> void:
	if from_slot == to_slot or from_slot < 0 or to_slot < 0 or from_slot >= inventory.SLOTS or to_slot >= inventory.SLOTS:
		return

	net.inventory_action.rpc_id(1, Net.ACT_MOVE, from_slot, to_slot, 0, Vector3.ZERO)
	_selected = -1


func refresh_hotbar() -> void:
	if hotbar_strip != null:
		hotbar_strip.refresh()


func hotbar_tip(slot: int) -> String:
	return _tooltip(inventory.numbers[slot], inventory.counts[slot]) if inventory.numbers[slot] != 0 else "Drag an item here from the inventory. Key %s holds it." % ("0" if slot == 9 else str(slot + 1))


# Eat the food or apply the medicine in a pack slot. Herbs that look like something else must be identified first.
func eat_slot(slot: int) -> void:
	# Use on a tool, weapon or kit holds it in the hand (and again puts it away); on food or medicine it eats or applies it.
	if not edible_slot(slot):
		if equippable_slot(slot) and equip_requested.is_valid():
			equip_with_move(slot)

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
	if _chest_panel == null:
		_chest_buttons.clear()
		_pack_buttons.clear()

	if _chest_panel != null:
		return

	_chest_panel = PanelContainer.new()
	_chest_panel.theme = _tooltip_theme()
	_chest_panel.anchor_left = 0.125
	_chest_panel.anchor_right = 0.875
	_chest_panel.anchor_top = 0.1
	_chest_panel.anchor_bottom = 0.9
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", _px(24))
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var chest_outer: VBoxContainer = VBoxContainer.new()
	chest_outer.add_theme_constant_override("separation", _px(10))
	_chest_panel.add_child(chest_outer)
	chest_outer.add_child(columns)

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
			button.mouse_entered.connect(func():
				_chest_hover = [chest_side, i]
				_chest_last = [chest_side, i])
			button.mouse_exited.connect(func(): _chest_hover = [] if _chest_hover == [chest_side, i] else _chest_hover)
			grid.add_child(button)
			(_chest_buttons if chest_side else _pack_buttons).append(button)

	var transfer: Button = Button.new()
	transfer.text = "Transfer (T)"
	transfer.tooltip_text = "Move the last stack you pointed at between your pack and the container (clicking a stack does the same)"
	_style(transfer, BODY_PX)
	transfer.pressed.connect(func():
		if _chest_last.size() == 2:
			_on_chest_slot(bool(_chest_last[0]), int(_chest_last[1])))
	transfer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chest_outer.add_child(transfer)
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
			var real: Mesh = _natural_mesh(int(row[1]), int(row[0]))
			box.mesh = real if real != null else _mesh_for(row[1])
			node = box
			node.position = row[3] + Vector3(0.0, 0.12, 0.0)
			_dress_item(node, int(row[1]), int(row[0]), real != null)
		else:
			node = _make_fire(state == 1, state == 9)
			node.position = row[3]
			light = node.get_node_or_null("Light")

		_root.add_child(node)
		_world[id] = {"node": node, "number": row[1], "count": row[2], "pos": row[3], "state": state, "light": light}


# Fires and structures standing in the world as {"pos", "state"} rows, for the placement ghost's blocked check.
func placed_rows() -> Array:
	var rows: Array = []

	for id in _world:
		var state: int = int(_world[id]["state"])

		if state == 1 or state == 5 or state == 6 or state == 7 or state == 8 or state == 9:
			rows.append({"pos": _world[id]["pos"], "state": state})

	return rows


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
func _make_fire(lit: bool, loaded: bool = false) -> Node3D:
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

	# A loaded, unlit fire: pale wood leaned together over the ring.
	if loaded:
		var wood_mesh: CylinderMesh = CylinderMesh.new()
		wood_mesh.top_radius = 0.04
		wood_mesh.bottom_radius = 0.05
		wood_mesh.height = 0.6
		var wood_material: StandardMaterial3D = StandardMaterial3D.new()
		wood_material.albedo_color = Color(0.55, 0.4, 0.24)
		wood_mesh.material = wood_material

		for n in range(4):
			var piece: MeshInstance3D = MeshInstance3D.new()
			piece.mesh = wood_mesh
			piece.rotation = Vector3(deg_to_rad(25.0), deg_to_rad(90.0 * float(n)), 0.0)
			piece.position = Vector3(0.0, 0.3, 0.0)
			fire.add_child(piece)

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


# Loose items on the ground (Dave 2026-10-20: a stick must not look like a green box). One shared mesh per item
# kind; each lying item is turned and scaled a little by its world id (_dress_item), so no per-frame cost.
func _mesh_for(number: int) -> Mesh:
	if not _meshes.has(number):
		var id: String = table.id_of(number)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.roughness = 1.0
		var mesh: Mesh

		if id == "stick" or id == "plant_fibre" or id == "firewood" or id == "log" or id == "driftwood":
			var dims: Array = {"driftwood": [0.9, 0.06, 0.05, 0.01], "stick": [0.6, 0.02, 0.011, 0.07], "plant_fibre": [0.3, 0.012, 0.006, 0.05], "firewood": [0.4, 0.05, 0.045, 0.01], "log": [1.0, 0.13, 0.11, 0.02]}[id]
			material.albedo_color = {"stick": Color(0.38, 0.27, 0.17), "plant_fibre": Color(0.72, 0.68, 0.45), "firewood": Color(0.5, 0.36, 0.22), "driftwood": Color(0.62, 0.58, 0.5), "log": Color(0.33, 0.24, 0.16)}[id]
			mesh = _branch_mesh(float(dims[0]), float(dims[1]), float(dims[2]), float(dims[3]))
		elif id == "stone":
			var rock: SphereMesh = SphereMesh.new()
			rock.radius = 0.11
			rock.height = 0.15
			rock.radial_segments = 8
			rock.rings = 4
			material.albedo_color = Color(0.47, 0.46, 0.44)
			mesh = rock
		elif str(table.entry(id).get("kind", "")) in ["placeable", "structure", "tool", "weapon"]:
			var crate: BoxMesh = BoxMesh.new()
			crate.size = Vector3(0.3, 0.12, 0.2)
			material.albedo_color = Color(0.45, 0.33, 0.2)
			mesh = crate
		else:
			# Plant parts, food and the rest: a small soft lump tinted by item.
			var lump: SphereMesh = SphereMesh.new()
			lump.radius = 0.08
			lump.height = 0.1
			lump.radial_segments = 8
			lump.rings = 4
			material.albedo_color = Color.from_hsv(fmod(float(number) * 0.137, 1.0), 0.45, 0.7)
			mesh = lump

		if mesh is PrimitiveMesh:
			mesh.material = material
		else:
			(mesh as ArrayMesh).surface_set_material(0, material)

		_meshes[number] = mesh

	return _meshes[number]


# A thin tapered, slightly bent branch lying along X (six sides, four segments), r0 at the base, r1 at the tip.
func _branch_mesh(length: float, r0: float, r1: float, bend: float) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 4
	var sides: int = 6
	var rings: Array = []

	for s in range(segments + 1):
		var t: float = float(s) / float(segments)
		var centre: Vector3 = Vector3((t - 0.5) * length, sin(t * PI) * bend, sin(t * PI * 1.3) * bend * 0.5)
		var radius: float = lerpf(r0, r1, t)
		var ring: Array = []

		for k in range(sides):
			var a: float = TAU * float(k) / float(sides)
			ring.append(centre + Vector3(0.0, cos(a) * radius, sin(a) * radius))

		rings.append(ring)

	for s in range(segments):
		for k in range(sides):
			var n: int = (k + 1) % sides
			var a0: Vector3 = rings[s][k]
			var b0: Vector3 = rings[s][n]
			var a1: Vector3 = rings[s + 1][k]
			var b1: Vector3 = rings[s + 1][n]

			for tri in [[a0, a1, b0], [b0, a1, b1]]:
				for v in tri:
					tool.add_vertex(v)

	tool.generate_normals()
	return tool.commit()


# Turns and scales a lying item by its world id so a heap of them does not look stamped. Sticks and logs lie flat,
# stones sit a little in the ground.
func _dress_item(node: Node3D, number: int, world_id: int, natural: bool = false) -> void:
	var id: String = table.id_of(number)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_id * 2654435761 + 17

	if natural:
		_dress_natural(node as MeshInstance3D, id, rng)
		return

	node.rotation = Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)

	if id == "stick" or id == "plant_fibre" or id == "firewood" or id == "log" or id == "driftwood":
		node.scale = Vector3(rng.randf_range(0.7, 1.3), 1.0, 1.0)
		node.position.y -= 0.08 if id != "log" else 0.0
	elif id == "stone":
		node.scale = Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.7, 1.1), rng.randf_range(0.8, 1.3))
		node.position.y -= 0.07


# Dave's real pickup meshes (assets/natural_pickups, glTF, metres, Y up, resting contact at Y=0, vertex colours).
# Three of each kind, shared by every loose item of that kind: a loose stone or stick picks one by its world id.
# The meshes carry generated levels of detail from the import, and each item is hidden beyond a short range, so a
# scatter of hundreds costs little. Falls back to the procedural shapes if a file is missing or not yet imported.
const PICKUP_DIR := "res://assets/natural_pickups/"
const PICKUP_FILES := {
	"stone_smooth": ["stone_smooth_01_river_grey", "stone_smooth_02_tan_flat", "stone_smooth_03_dark_oval"],
	"stone_rough": ["stone_rough_01_granite", "stone_rough_02_slate", "stone_rough_03_ochre"],
	"stick": ["stick_forest_01_twig", "stick_forest_02_snap", "stick_forest_03_crooked"],
	"driftwood": ["driftwood_01_bleached", "driftwood_02_forked", "driftwood_03_long"],
}
const STONE_VIEW_M := 75.0
const STICK_VIEW_M := 100.0
# Dave 2026-10-21: big enough to stand out in the tall thick grass (about 0.9 m, nearly full cover). Stones come out about
# 1 to 2 m across and sticks about 2.4 to 4.5 m long (three times the 2026-10-20 size, Dave 2026-10-21); sticks rest on top of the grass (a lift), stones sit in the soil
# but proud of the blades. A little extra brightness and a faint warm glow keep them readable in shade.
const PICKUP_SIZE_MULT := 3.0   # Dave, 2026-10-21: three times the earlier size
const STONE_SCALE := Vector2(2.4, 3.4) * PICKUP_SIZE_MULT
const STICK_SCALE := Vector2(2.0, 2.7) * PICKUP_SIZE_MULT
const STONE_LIFT_M := 0.05 * PICKUP_SIZE_MULT
const STICK_LIFT_M := 0.22 * PICKUP_SIZE_MULT
const PICKUP_BRIGHT := 1.3
const PICKUP_GLOW := Color(0.13, 0.11, 0.08)
var _pickup_meshes: Dictionary = {}   # group -> Array of Mesh (empty when the files are not there)


func _pickup_group(group: String) -> Array:
	if not _pickup_meshes.has(group):
		var meshes: Array = []

		for file in PICKUP_FILES[group]:
			var packed: Variant = load(PICKUP_DIR + file + ".glb") if ResourceLoader.exists(PICKUP_DIR + file + ".glb") else null

			if packed is PackedScene:
				var instance: Node = packed.instantiate()
				var found: Array = instance.find_children("*", "MeshInstance3D", true, false)

				if not found.is_empty():
					var mesh: Mesh = (found[0] as MeshInstance3D).mesh

					for surface in mesh.get_surface_count():
						var base: Material = mesh.surface_get_material(surface)

						if base is StandardMaterial3D:
							var lit: StandardMaterial3D = base.duplicate()
							lit.albedo_color = Color(PICKUP_BRIGHT, PICKUP_BRIGHT, PICKUP_BRIGHT)
							lit.emission_enabled = true
							lit.emission = PICKUP_GLOW
							mesh.surface_set_material(surface, lit)

					meshes.append(mesh)

				instance.free()

		_pickup_meshes[group] = meshes if meshes.size() == 3 else []

	return _pickup_meshes[group]


# The real mesh for a loose stone or stick, or null (any other item, or the files are missing).
func _natural_mesh(number: int, world_id: int) -> Mesh:
	var id: String = table.id_of(number)
	var pick: int = int(((world_id * 2654435761) >> 8) & 0xffff)
	var group: String = ""

	if id == "stone":
		group = "stone_smooth" if pick % 100 < 55 else "stone_rough"
	elif id == "stick":
		group = "stick"
	elif id == "driftwood":
		group = "driftwood"
	else:
		return null

	var meshes: Array = _pickup_group(group)
	return null if meshes.is_empty() else meshes[(pick / 100) % 3]


# Turn, size, tilt and bury each loose item a little (by its world id, set once): stones sit part in the soil, sticks
# lie with a slight tilt and a hand's breadth of grass over them. Mesh origin is the resting contact (Y=0).
func _dress_natural(node: MeshInstance3D, id: String, rng: RandomNumberGenerator) -> void:
	var height: float = node.mesh.get_aabb().size.y
	node.position.y -= 0.12   # undo the placeholder lift: the real meshes rest on y = 0

	if id == "stone":
		var size: float = rng.randf_range(STONE_SCALE.x, STONE_SCALE.y)
		node.scale = Vector3(size * rng.randf_range(0.9, 1.15), size * rng.randf_range(0.75, 1.0), size * rng.randf_range(0.9, 1.15))
		node.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, TAU), rng.randf_range(-0.3, 0.3))
		node.position.y += STONE_LIFT_M - height * node.scale.y * rng.randf_range(0.05, 0.4)
		node.visibility_range_end = STONE_VIEW_M
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var size: float = rng.randf_range(STICK_SCALE.x, STICK_SCALE.y)
		node.scale = Vector3(size, size, size)
		node.rotation = Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(0.0, TAU), rng.randf_range(-0.08, 0.08))
		node.position.y += STICK_LIFT_M - rng.randf_range(0.0, 0.03)
		node.visibility_range_end = STICK_VIEW_M
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
var _slot_scroll: ScrollContainer


var sort_index: int = 0                # 0 unsorted (order picked up), 1 name, 2 weight, 3 value
var sort_changed: Callable = Callable()   # (index): the owner saves the choice
var _first_seen: Dictionary = {}       # item number -> order it was first picked up (while held)
var _seen_counter: int = 0
var _sort_menu: OptionButton
var text_step: Callable = Callable()   # (direction -1 or 1): the owner changes and saves the text size
var text_scale: float = 0.85           # crafting and inventory text size (Esc > Settings, saved in display_settings.cfg)


# Resizes the crafting and inventory screen's text: the panel is rebuilt at the new size.
func set_text_scale(scale: float) -> void:
	text_scale = scale

	# The chest screen is rebuilt on its next opening at the new size.
	if _chest_panel != null:
		_chest_panel.queue_free()
		_chest_panel = null
		_chest_buttons.clear()
		_pack_buttons.clear()

	if _panel != null:
		var was_open: bool = open
		_panel.queue_free()
		_panel = null
		_buttons.clear()

		if was_open:
			_build_panel()
			_refresh()


func text_px(size: int) -> int:
	return _px(size)


func _px(size: int) -> int:
	return int(round(float(size) * text_scale * maxf(_layer.get_viewport().get_visible_rect().size.y / 1080.0, 0.5)))


# Tooltips pop up in the engine's small default font; the window's theme makes them as large as the body text (audit, job 82).
func _tooltip_theme() -> Theme:
	var themed: Theme = Theme.new()
	themed.set_font_size("font_size", "TooltipLabel", _px(BODY_PX - 6))
	return themed


# Health, exertion, hunger and thirst, side by side at the top of the inventory screen: the only bars in the game (Dave
# 2026-10-21: no bars on the main screen). Exertion is the strain as a share of the blackout threshold.
func _build_bars_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(28))
	_panel_bars.clear()

	for spec in [["Health", Color(0.85, 0.2, 0.2)], ["Exertion", Color(0.95, 0.8, 0.25)], ["Hunger", Color(0.9, 0.55, 0.2)], ["Thirst", Color(0.3, 0.6, 0.95)]]:
		var cell: HBoxContainer = HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", _px(10))
		var label: Label = Label.new()
		label.text = spec[0]
		_style(label, BODY_PX - 6)
		cell.add_child(label)
		var bar: ProgressBar = ProgressBar.new()
		bar.show_percentage = false
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(_px(60), _px(22))
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = spec[1]
		bar.add_theme_stylebox_override("fill", fill)
		var empty: StyleBoxFlat = StyleBoxFlat.new()
		empty.bg_color = Color(0.0, 0.0, 0.0, 0.5)
		bar.add_theme_stylebox_override("background", empty)
		cell.add_child(bar)
		row.add_child(cell)
		_panel_bars[spec[0]] = bar

	_update_panel_bars()
	return row


func _update_panel_bars() -> void:
	if _panel_bars.is_empty() or not is_instance_valid(_panel_bars["Health"]):
		return

	var threshold: float = maxf(float(_exertion_cfg.get("faint_at", 1.4)), 0.1)
	_panel_bars["Health"].value = float(health)
	_panel_bars["Exertion"].value = clampf(strain / threshold, 0.0, 1.0) * 100.0
	_panel_bars["Hunger"].value = float(hunger)
	_panel_bars["Thirst"].value = float(thirst)


func _style(control: Control, size: int) -> void:
	control.add_theme_font_size_override("font_size", _px(size))


func _build_panel() -> void:
	if _panel != null:
		return

	_buttons.clear()   # a rebuilt panel starts with a fresh list; never keep freed buttons

	_panel = PanelContainer.new()
	_panel.theme = _tooltip_theme()
	_panel.anchor_left = 0.05
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.05
	_panel.anchor_bottom = 0.95
	_panel.clip_contents = true   # the window keeps its size whatever the text size; contents scroll or wrap
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
	title.size_flags_stretch_ratio = 1.4
	title.clip_text = true
	_style(title, TITLE_PX)
	top.add_child(title)

	# Text size buttons (Dave 2026-10-20); terrain_client keeps and saves the choice.
	for step in [[-1, "Text -"], [1, "Text +"]]:
		var size_button: Button = Button.new()
		size_button.text = step[1]
		_style(size_button, BODY_PX - 6)
		size_button.pressed.connect(func(): text_step.call(step[0]) if text_step.is_valid() else null)
		top.add_child(size_button)

	_search = LineEdit.new()
	_search.placeholder_text = "Search recipes and items"
	_search.custom_minimum_size = Vector2(_px(120), 0.0)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.size_flags_stretch_ratio = 1.0
	_search.clear_button_enabled = true
	_style(_search, BODY_PX)
	_search.text_changed.connect(func(_text): _refresh())
	top.add_child(_search)
	box.add_child(_build_bars_row())
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
	list_scroll.size_flags_stretch_ratio = 1.6
	left.add_child(list_scroll)
	_queue_box = VBoxContainer.new()
	_queue_box.visible = false
	left.add_child(_queue_box)
	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_recipe_list)

	# The chosen recipe's detail scrolls in its own area so it never overlaps the recipe list.
	var detail_scroll: ScrollContainer = ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_stretch_ratio = 1.0
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail)

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
	_weight_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_weight_label)
	_carry_bar = ProgressBar.new()
	_carry_bar.show_percentage = false
	_carry_bar.max_value = 100.0
	_carry_bar.custom_minimum_size = Vector2(0.0, _px(22))
	_carry_bar.add_theme_stylebox_override("fill", StyleBoxFlat.new())
	var carry_empty: StyleBoxFlat = StyleBoxFlat.new()
	carry_empty.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	_carry_bar.add_theme_stylebox_override("background", carry_empty)
	right.add_child(_carry_bar)
	_sort_menu = OptionButton.new()
	_style(_sort_menu, BODY_PX - 6)

	for sort_name in ["Sort: unsorted (picked up order)", "Sort: name", "Sort: weight (ascending)", "Sort: weight (descending)", "Sort: value (ascending)", "Sort: value (descending)"]:
		_sort_menu.add_item(sort_name)

	_sort_menu.select(sort_index)
	_sort_menu.item_selected.connect(func(index):
		sort_index = index
		_arrange_slots()

		if sort_changed.is_valid():
			sort_changed.call(index))
	right.add_child(_sort_menu)
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
		button.mouse_entered.connect(func(): _hover = i)
		button.mouse_exited.connect(func(): _hover = -1 if _hover == i else _hover)
		button.set_drag_forwarding(_slot_drag.bind(i), _slot_can_drop.bind(i), _slot_drop.bind(i))
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

	var row: HFlowContainer = HFlowContainer.new()   # wraps onto a second line when the text is large
	row.add_theme_constant_override("h_separation", _px(12))
	row.add_theme_constant_override("v_separation", _px(6))
	right.add_child(row)

	# One row; each button carries its key (the same keys work on the slot under the mouse).
	for spec in [["Split (S)", "Split the selected stack in half", _split_selected], ["Drop (D)", "Drop the whole stack. Shift+D drops one", _drop_selected.bind(true)], ["Use (E)", "Eat the food, apply the medicine, or hold a tool in your hand (again to put it away)", func(): eat_slot(_selected)], ["Repair (R)", "Repair a worn tool with its materials", _repair_selected]]:
		var action: Button = Button.new()
		action.text = spec[0]
		action.tooltip_text = spec[1]
		_style(action, BODY_PX)
		action.pressed.connect(spec[2])
		row.add_child(action)

	_layer.add_child(_panel)


# True while the crafting and inventory screen or a chest screen is on screen.
func screen_open() -> bool:
	return open or chest_mode or character_open()


# Quick keys while the screen is open: E use (eat or apply), D drop (Shift+D one), S split, R repair, T transfer
# between the pack and an open container. They act on the slot under the mouse, else the selected slot. True when the key
# was one of them (the caller then skips its other bindings). Outside this screen E is the interact key.
func quick_key(event: InputEventKey) -> bool:
	var slot: int = _hover if _hover >= 0 else _selected

	match event.keycode:
		KEY_E:
			if slot >= 0 and not chest_mode:
				eat_slot(slot)

			return true
		KEY_D:
			if slot >= 0 and not chest_mode:
				_selected = slot
				_drop_selected(not event.shift_pressed)

			return true
		KEY_R:
			if slot >= 0 and not chest_mode:
				_selected = slot
				_repair_selected()

			return true
		KEY_S:
			if slot >= 0 and not chest_mode:
				_selected = slot
				_split_selected()

			return true
		KEY_T:
			if chest_mode and _chest_hover.size() == 2:
				_on_chest_slot(bool(_chest_hover[0]), int(_chest_hover[1]))

			return true

	return false


# Dragging a stack from one slot to another (also onto the hotbar strip on screen).
func _slot_drag(_at: Vector2, slot: int) -> Variant:
	if inventory.numbers[slot] == 0:
		return null

	var preview: Label = Label.new()
	preview.text = table.name_of(inventory.numbers[slot])
	preview.add_theme_font_size_override("font_size", _px(BODY_PX - 4))
	_buttons[slot].set_drag_preview(preview)
	return {"slot": slot}


func _slot_can_drop(_at: Vector2, data: Variant, _slot: int) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("slot")


func _slot_drop(_at: Vector2, data: Variant, slot: int) -> void:
	move_slot(int(data["slot"]), slot)


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


# Queue the chosen recipe `quantity` times. The server takes the ingredients now and makes the crafts in order.
func _craft_selected() -> void:
	if _selected_recipe == 0:
		return

	_start_craft(_selected_recipe, int(_quantity.value) if _quantity != null else 1)


func _start_craft(number: int, count: int = 1) -> void:
	if not recipes.can_make(number, inventory):
		return

	for item in recipes.recipe(number).get("identify", []):
		if knowledge != null and not knowledge.is_known("i%d" % item):
			_on_notice("You are not sure what %s really is. Hover it in inspection mode (/) before you use it." % table.name_of(item).to_lower())
			return

	net.inventory_action.rpc_id(1, Net.ACT_CRAFT_QUEUE, number, 0, count, Vector3.ZERO)


func _on_reject(reason: int) -> void:
	_sweep_blocked = _sweep_blocked or reason == 2   # a full pack ends a held-E sweep until E is let go
	refuse_cue(["far", "no_tool", "full_pack", "other"][clampi(reason, 0, 3)])


# A hard landing (sound.landing.hurt): tell the server how far it was; the server decides the damage.
func report_fall(drop_m: float, _severity: float = 0.0) -> void:
	net.inventory_action.rpc_id(1, Net.ACT_FALL, int(round(drop_m * 100.0)), 0, 0, Vector3.ZERO)


func _on_craft_queue(entries: Array, left_ms: int) -> void:
	craft_entries = entries
	_crafting = int(entries[0][0]) if not entries.is_empty() else 0
	_craft_head_end_msec = Time.get_ticks_msec() + left_ms
	_rebuild_queue()


func _queue_text(index: int) -> String:
	var entry: Array = craft_entries[index]
	var text: String = str(recipes.recipe(int(entry[0])).get("name", "?"))

	if int(entry[1]) > 1:
		text += "  x%d" % int(entry[1])

	if index == 0:
		text += "   %.0f s" % ceilf(maxf(float(_craft_head_end_msec - Time.get_ticks_msec()) / 1000.0, 0.0))

	return text


# One button per queued craft; pressing it cancels the entry and the server hands back what it cost.
func _rebuild_queue() -> void:
	if _queue_box == null:
		return

	for child in _queue_box.get_children():
		child.queue_free()

	_queue_head_button = null

	if craft_entries.is_empty():
		_queue_box.visible = false
		return

	_queue_box.visible = true
	var title: Label = Label.new()
	title.text = "Crafting queue  (press one to cancel it)"
	_style(title, BODY_PX - 4)
	_queue_box.add_child(title)

	for i in craft_entries.size():
		var button: Button = Button.new()
		button.text = _queue_text(i)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		_style(button, BODY_PX - 4)
		var index: int = i
		button.pressed.connect(func(): net.inventory_action.rpc_id(1, Net.ACT_CRAFT_CANCEL, index, 0, 0, Vector3.ZERO))
		_queue_box.add_child(button)

		if i == 0:
			_queue_head_button = button


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
	text += "\n%s" % str(entry.get("description", "A plant material you gathered."))

	var kcal: int = VitalsRules.food_value(table.id_of(number), _vitals_cfg)
	var heal: int = VitalsRules.heal_value(table.id_of(number), _vitals_cfg)

	if not _carry_cfg.is_empty():
		var each_kg: float = CarryRules.weight_of(table.id_of(number), _carry_cfg)
		text += "\n%s each" % (("%.0f g" % (each_kg * 1000.0)) if each_kg < 0.1 else ("%.2f kg" % each_kg))

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


# The slot buttons keep their slot (clicks, moves and the hotbar are unchanged); only where they sit in the grid
# changes. Empty slots go last. Unsorted is the order the item kinds were picked up in.
func _arrange_slots() -> void:
	if _panel == null or _buttons.is_empty():
		return

	var order: Array = range(inventory.SLOTS)
	var cfg: Dictionary = _carry_cfg

	var key: Callable = func(slot: int) -> Variant:
		var number: int = inventory.numbers[slot]
		var count: int = inventory.counts[slot]

		match sort_index:
			1:
				return table.name_of(number).to_lower()
			2:
				return CarryRules.weight_of(table.id_of(number), cfg) * float(count)
			3:
				return -CarryRules.weight_of(table.id_of(number), cfg) * float(count)
			4:
				return table.value_of(number) * count
			5:
				return -table.value_of(number) * count

		return int(_first_seen.get(number, 0))

	order.sort_custom(func(a, b):
		var empty_a: bool = inventory.numbers[a] == 0
		var empty_b: bool = inventory.numbers[b] == 0

		if empty_a != empty_b:
			return empty_b

		if empty_a:
			return a < b

		var ka: Variant = key.call(a)
		var kb: Variant = key.call(b)
		return a < b if ka == kb else ka < kb)

	for position in range(order.size()):
		_grid.move_child(_buttons[order[position]], position)


# Remembers the order item kinds first appeared in the pack (for the unsorted view).
func _note_acquired() -> void:
	var present: Dictionary = {}

	for slot in range(inventory.SLOTS):
		var number: int = inventory.numbers[slot]

		if number != 0:
			present[number] = true

			if not _first_seen.has(number):
				_seen_counter += 1
				_first_seen[number] = _seen_counter

	for number in _first_seen.keys():
		if not present.has(number):
			_first_seen.erase(number)


func _refresh() -> void:
	if _panel == null:
		_note_acquired()
		return

	_note_acquired()
	_arrange_slots()

	if _weight_label != null:
		_refresh_weight()

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
		entry.modulate = Color(0.55, 1.0, 0.55) if makeable else Color(0.55, 0.55, 0.55, 0.6)
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
	heading.text = str(r["name"])
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
	make.disabled = not recipes.can_make(_selected_recipe, inventory)
	make.custom_minimum_size = Vector2(_px(240), _px(64))
	_style(make, BODY_PX)
	make.pressed.connect(_craft_selected)
	row.add_child(make)


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
# Headless check (--arrival): the ground appears under the gliding body, it is set down just above the surface, and
# nothing hurts: health stays 100 and the character is not fainted.
func run_arrival_test(client) -> void:
	var waited: float = 0.0

	while client.arrival_protect_until_msec == 0 and waited < 90.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5

	var ground: float = client._ground_below(client.body.global_position)
	var above: float = client.body.global_position.y - ground if not is_nan(ground) else -1.0
	await get_tree().create_timer(10.0).timeout
	print("Arrival test: ground found %s, set down %.1f m above it, health %d, strain state %s" % [str(client.arrival_protect_until_msec > 0), above, health, str(strain_state)])


# Headless check (--strainrun with --walk --runspeed=11): the body runs and the strain the server sends must climb.
func run_strain_test(client) -> void:
	var waited: float = 0.0

	while client.arrival_protect_until_msec == 0 and waited < 90.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5

	var start_strain: float = strain
	var start_pos: Vector3 = client.body.global_position
	var covered_total: float = 0.0
	await get_tree().create_timer(25.0).timeout
	var covered: float = Vector2(client.body.global_position.x - start_pos.x, client.body.global_position.z - start_pos.z).length()
	print("Strain test: ran %.0f m in 25 s, strain %.2f -> %.2f, state %d" % [covered, start_strain, strain, strain_state])

	# The server's walk from normal to over-exerted to blackout is proven in test_server_items; here the client's side of it:
	# over-exerted is a 10 percent slow-down with no speed cap and running still allowed, fainted locks movement.
	var real_state: int = strain_state
	var factors: Array = []

	for forced in [0, 1, 2]:
		strain_state = forced
		factors.append("%d: pace x%s cap %s" % [forced, str(snappedf(over_pace_factor(), 0.001)), str(move_cap())])

	strain_state = real_state
	print("Strain test: %s" % " | ".join(factors))


func run_gather_test(client) -> void:
	await get_tree().create_timer(6.0).timeout
	var real_view: Callable = view_direction
	view_direction = Callable()   # the prompt checks below stand wherever the test camera happens to look
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

	# Held E (Dave 2026-10-21): one item a step from anything within 2 m, in view or not; the prompt only for what you look toward.
	client.body.global_position = here + Vector3(0.0, 1.0, 0.0)
	client.body.velocity = Vector3.ZERO
	await get_tree().create_timer(1.0).timeout
	var spot: Vector3 = _player_position.call()
	var stone_n: int = table.number_of("stone")
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, stone_n, 0, 4, Vector3.ZERO)
	await get_tree().create_timer(0.6).timeout

	for offset in [Vector3(1.4, 0.0, 0.0), Vector3(-1.4, 0.0, 0.0), Vector3(0.0, 0.0, 1.4), Vector3(0.0, 0.0, -1.4)]:
		net.inventory_action.rpc_id(1, Net.ACT_DROP, inventory.numbers.find(stone_n), 0, 1, spot + offset)
		await get_tree().create_timer(0.4).timeout

	view_direction = func(): return Vector3(1.0, 0.0, 0.0)
	var east_in: bool = in_view(spot + Vector3(1.4, 0.0, 0.0))
	var west_in: bool = in_view(spot + Vector3(-1.4, 0.0, 0.0))
	print("Hold test: looking east, stone to the east in view %s, stone to the west in view %s, prompt \"%s\"" % [str(east_in), str(west_in), str(_probe_pickup().get("prompt", ""))])
	view_direction = Callable()
	var held_before: int = inventory.count_of(stone_n)
	var deltas: Array = []
	for step in range(24):   # plants within 2 m that are nearer go first, so allow for them
		client.harvest.update(0.4, true)   # one held-E step (the real per-frame update lets go between the test's calls)
		await get_tree().create_timer(0.3).timeout
		var now_count: int = inventory.count_of(stone_n)
		deltas.append(now_count - held_before)
		held_before = now_count

	client.harvest.update(0.0, false)
	print("Hold test: stones gained per held-E step %s" % str(deltas))
	var most: int = 0
	var total: int = 0

	for gained in deltas:
		most = maxi(most, gained)
		total += gained

	print("Hold test: most in one step %d, total %d, last two steps %d" % [most, total, deltas[deltas.size() - 1] + deltas[deltas.size() - 2]])
	view_direction = real_view

	for look in ["stick", "stone", "log", "plant_fibre", "roast_forage"]:
		var shape: Mesh = _mesh_for(table.number_of(look))
		print("Item look: %s is a %s, %.2f x %.2f x %.2f m" % [look, shape.get_class(), shape.get_aabb().size.x, shape.get_aabb().size.y, shape.get_aabb().size.z])

	for look in ["stick", "stone", "driftwood"]:
		var seen: Dictionary = {}

		for world_id in range(1, 40):
			var real: Mesh = _natural_mesh(table.number_of(look), world_id)

			if real != null:
				seen[real.get_rid().get_id()] = real

		var sizes: Array = []

		for real in seen.values():
			sizes.append("%.2f m" % real.get_aabb().size.x)

		print("Natural look: %s uses %d real meshes (%s)" % [look, seen.size(), ", ".join(sizes)])

		var smallest: float = 99.0
		var largest: float = 0.0
		var lowest: float = 99.0
		var highest: float = -99.0

		for world_id in range(1, 40):
			var dressed: MeshInstance3D = MeshInstance3D.new()
			dressed.mesh = _natural_mesh(table.number_of(look), world_id)

			if dressed.mesh == null:
				continue

			_dress_item(dressed, table.number_of(look), world_id, true)
			var box: AABB = dressed.mesh.get_aabb()
			var longest: float = maxf(box.size.x, maxf(box.size.z, box.size.y)) * maxf(dressed.scale.x, maxf(dressed.scale.y, dressed.scale.z))
			smallest = minf(smallest, longest)
			largest = maxf(largest, longest)
			lowest = minf(lowest, dressed.position.y + 0.12)
			highest = maxf(highest, dressed.position.y + 0.12)
			dressed.free()

		print("Natural size: %s lies %.2f to %.2f m long, centre %.2f to %.2f m above its spot" % [look, smallest, largest, lowest, highest])


# Headless check (--quickkeys): D drops, S splits and E eats the stack under the mouse.
func run_quickkey_test(client) -> void:
	await get_tree().create_timer(6.0).timeout
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("stone"), 0, 6, Vector3.ZERO)
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("roast_forage"), 0, 2, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	toggle()
	var stone: int = table.number_of("stone")
	var roast: int = table.number_of("roast_forage")
	var slot: int = inventory.numbers.find(stone)
	var before: int = inventory.count_of(stone)
	_hover = slot

	var press: Callable = func(code: int, shift: bool = false) -> bool:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.shift_pressed = shift
		event.pressed = true
		return quick_key(event)

	var handled: bool = press.call(KEY_S)
	await get_tree().create_timer(1.0).timeout
	print("Quick key test: S handled %s, stacks of stone %d -> %d" % [str(handled), 1, _stone_stacks(stone)])
	_hover = inventory.numbers.find(stone)
	press.call(KEY_D, true)
	await get_tree().create_timer(1.0).timeout
	print("Quick key test: Shift+D dropped one, stones %d -> %d" % [before, inventory.count_of(stone)])
	_hover = inventory.numbers.find(roast)
	var roasts: int = inventory.count_of(roast)
	press.call(KEY_E)
	await get_tree().create_timer(1.0).timeout
	print("Quick key test: E ate, roasts %d -> %d" % [roasts, inventory.count_of(roast)])
	print("Quick key test: T outside a container handled %s, nothing moved" % str(press.call(KEY_T)))


func _stone_stacks(number: int) -> int:
	var stacks: int = 0

	for slot in range(inventory.SLOTS):
		if inventory.numbers[slot] == number:
			stacks += 1

	return stacks


# Headless check (--texttest): press Text - and Text + several times with the screen open; nothing may
# touch a freed button.
func run_text_test(client) -> void:
	await get_tree().create_timer(6.0).timeout
	toggle()
	var valid: bool = true
	var filled_ok: bool = true
	var sizes: Dictionary = {}
	var fits: bool = true
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("stone"), 0, 3, Vector3.ZERO)
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("stick"), 0, 3, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout

	for direction in [-1, -1, -1, 1, 1, 1, 1, -1, -1, -1, 1]:
		text_step.call(direction)

		# Right after the press (before any frame passes): the list must hold only the new, shown buttons.
		valid = valid and _buttons.size() == inventory.SLOTS

		for slot in range(mini(_buttons.size(), inventory.SLOTS)):
			valid = valid and is_instance_valid(_buttons[slot]) and _buttons[slot].get_parent() == _grid

			if inventory.numbers[slot] != 0 and _buttons[slot].text == "":
				filled_ok = false

		await get_tree().process_frame
		_refresh()
		await get_tree().process_frame
		await get_tree().process_frame
		sizes[snappedf(_panel.size.x, 1.0) * 10000 + snappedf(_panel.size.y, 1.0)] = text_scale
		var need: Vector2 = _panel.get_combined_minimum_size()
		fits = fits and need.x <= _panel.size.x + 1.0 and need.y <= _panel.size.y + 1.0

		for button in _buttons:
			valid = valid and is_instance_valid(button)

		# Every slot that holds something must show it after each press.
		for slot in range(inventory.SLOTS):
			if inventory.numbers[slot] != 0 and valid and _buttons[slot].text == "":
				filled_ok = false

		for mode in [1, 2, 3, 4, 5, 0]:
			sort_index = mode
			_arrange_slots()

	_audit_text()
	toggle_character()
	await get_tree().process_frame
	await get_tree().process_frame
	_character.refresh()
	print("Character screen: ", _character.report(), "; inventory closed ", str(not open), "; screen_open ", str(screen_open()))
	toggle_character()
	print("Text test: scale %.2f, %d slot buttons, all valid %s, every item shown %s, panel open %s, window sizes seen %d, contents fit %s" % [text_scale, _buttons.size(), str(valid), str(filled_ok), str(open), sizes.size(), str(fits)])


# Job 82: every control in the inventory window, read at the current text scale: the smallest font in use, the labels a
# player sees (buttons, sort options, hints) and the key letters on the action buttons. Printed as "Audit:" lines.
const MIN_FONT_PX := 24
const ACTION_BUTTON_LABELS := ["Split (S)", "Drop (D)", "Use (E)", "Repair (R)"]


func _audit_text() -> void:
	var smallest: int = 999
	var smallest_name: String = ""
	var labels: Array = []
	var stack: Array = [_panel]

	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())

		if not (node is Label or node is Button or node is LineEdit or node is SpinBox):
			continue

		var control: Control = node as Control

		if node is SpinBox:
			control = (node as SpinBox).get_line_edit()

		if not control.is_visible_in_tree():
			continue

		var size: int = control.get_theme_font_size("font_size")

		if size < smallest and (str(control.get("text")) != "" or node is OptionButton):
			smallest = size
			smallest_name = "%s %s" % [node.get_class(), str(control.get("text")).left(24)]

		if node is Button and str(control.get("text")) != "" and not _buttons.has(node):
			labels.append(str(control.get("text")))

	var tooltip_px: int = _panel.theme.get_font_size("font_size", "TooltipLabel") if _panel.theme != null else 16
	var missing: Array = []

	for key_label in ACTION_BUTTON_LABELS:
		if not labels.has(key_label):
			missing.append(key_label)

	print("Audit: carry bar %s" % str(_carry_bar != null and _carry_bar.is_inside_tree()))
	print("Audit: smallest font %d px (%s), tooltip font %d px, sort options %d, button labels %s, key buttons missing %s, panel bars %d, main-screen bars %d" % [smallest, smallest_name, tooltip_px, _sort_menu.item_count, str(labels), str(missing), _panel_bars.size(), (1 if _vitals_back.find_children("*", "ColorRect", true, false).size() > 0 else 0)])


# Headless check (--plantpick): pick several plants (kind 2, flowers and herbs) and see whether each one is gone
# from the client's flora afterwards.
func run_plant_test(client) -> void:
	await get_tree().create_timer(6.0).timeout
	var spots: Array = []
	var here: Vector3 = _player_position.call()

	for chunk in client.flora._chunks:
		var held: Dictionary = client.flora._chunks[chunk]["items"]

		for n in range(held["ids"].size()):
			if client.flora._species.get(held["ids"][n] >> 16, {}).get("kind", 0) == 2:
				spots.append([held["positions"][n].distance_to(here), held["positions"][n], held["ids"][n], chunk])

	spots.sort_custom(func(a, b): return a[0] < b[0])
	var tried: int = 0
	var gone: int = 0
	var skipped: int = 0

	for spot in spots.slice(0, 40):
		if tried >= 8:
			break

		client.body.global_position = spot[1] + Vector3(0.4, 1.0, 0.0)
		client.body.velocity = Vector3.ZERO
		await get_tree().create_timer(1.2).timeout
		var picked: bool = false

		for c in client.harvest._candidates(2.5):
			if int(c["id"]) == int(spot[2]) and c["ok"]:
				picked = true

		if not picked:
			skipped += 1
			continue

		client.harvest._pick(client.harvest._candidates(2.5).filter(func(c): return int(c["id"]) == int(spot[2]))[0])
		tried += 1
		await get_tree().create_timer(1.0).timeout
		var held_now: Dictionary = client.flora._chunks.get(spot[3], {}).get("items", {})
		var still: bool = held_now.has("ids") and held_now["ids"].find(spot[2]) >= 0
		print("Plant test: %s %s" % [client.harvest._flora_by_id.get(int(spot[2]) >> 16, {}).get("name", "?"), "STILL THERE" if still else "gone"])
		gone += 0 if still else 1

	print("Plant test: tried %d, gone %d, still standing %d, skipped (nothing pickable) %d" % [tried, gone, tried - gone, skipped])


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

	# Sort view: the grid order follows the choice while every button keeps its own slot.
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("stone"), 0, 3, Vector3.ZERO)
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("log"), 0, 1, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	toggle()

	for mode in [1, 2, 3, 4, 5, 0]:
		sort_index = mode
		_arrange_slots()
		var names: Array = []

		for position in range(4):
			var slot: int = _buttons.find(_grid.get_child(position))
			names.append(table.name_of(inventory.numbers[slot]) if inventory.numbers[slot] != 0 else "-")

		print("Sort test: mode %d first four: %s" % [mode, ", ".join(names)])

	# Crafting queue: three cordage line up, the screen shows the entry, pressing it cancels and refunds.
	var fibre: int = table.number_of("plant_fibre")
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, fibre, 0, 12, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	var fibre_before: int = inventory.count_of(fibre)
	_selected_recipe = 1
	_craft_selected()
	await get_tree().create_timer(1.0).timeout
	var shown: int = _queue_box.get_child_count() - 1 if _queue_box.visible else 0
	print("Queue test: entries %d, fibre %d -> %d, buttons shown %d, head \"%s\"" % [craft_entries.size(), fibre_before, inventory.count_of(fibre), shown, _queue_head_button.text if _queue_head_button != null else ""])
	_queue_head_button.pressed.emit()
	await get_tree().create_timer(1.0).timeout
	print("Queue test: after cancel entries %d, fibre %d, queue strip hidden %s" % [craft_entries.size(), inventory.count_of(fibre), str(not _queue_box.visible)])

	# Tools: Use holds a tool, again puts it away; a tool deep in the pack moves onto the hotbar first.
	var axe: int = table.number_of("stone_axe")
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, axe, 0, 1, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	var axe_slot: int = inventory.numbers.find(axe)

	if int(held_slot_now.call()) == axe_slot:
		equip_requested.call(axe_slot)   # the saved hotbar slot can be this one: start with empty hands

	eat_slot(axe_slot)
	await get_tree().create_timer(0.5).timeout
	var in_hand: int = held_slot_now.call() if held_slot_now.is_valid() else -2
	print("Hotbar test: axe in slot %d, Use holds slot %d (matches %s), strip boxes %d" % [axe_slot, in_hand, str(in_hand == axe_slot), hotbar_strip._cells.size() if hotbar_strip != null else 0])
	var model = client.held._model
	print("Arms test: axe model in the right hand %s, arms shown %s" % [str(model != null and client.held._mounted and model.get_parent() == client.held._arms.hand_mount_r), str(client.held._arms.visible)])
	eat_slot(axe_slot)
	await get_tree().create_timer(0.5).timeout
	print("Hotbar test: Use again, hand slot %d (-1 = empty)" % [held_slot_now.call()])
	net.inventory_action.rpc_id(1, Net.ACT_MOVE, axe_slot, 20, 0, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	eat_slot(20)
	await get_tree().create_timer(1.0).timeout
	var moved_to: int = held_slot_now.call()
	equip_requested.call(moved_to)   # empty hands again
	print("Hotbar test: axe parked in slot 20, Use moved it to slot %d and holds it (%s), on hotbar %s" % [moved_to, str(moved_to >= 0 and inventory.numbers[moved_to] == axe), str(moved_to >= 0 and moved_to < 10)])

	# Every tool and weapon in the table can be held from the hotbar, with a model, and does something on left click.
	var tool_ids: Array = []

	for id in table._by_id:
		if str(table._by_id[id].get("kind", "")) in ["tool", "weapon"] and not bool(table._by_id[id].get("future", false)):
			tool_ids.append(id)

	var held_ok: int = 0
	var modelled: int = 0

	for id in tool_ids:
		net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of(id), 0, 1, Vector3.ZERO)
		await get_tree().create_timer(0.6).timeout
		var tool_slot: int = inventory.numbers.find(table.number_of(id))

		if tool_slot >= 10:
			move_slot(tool_slot, 9)
			await get_tree().create_timer(0.6).timeout
			tool_slot = 9

		client.held.select(tool_slot)
		await get_tree().create_timer(0.3).timeout
		held_ok += 1 if client.held.held_id() == id else 0
		modelled += 1 if client.held._model != null else 0

		if client.held.held_id() != id or client.held._model == null:
			print("Tools test: NOT held or no model: %s" % id)

	print("Tools test: %d tools and weapons, held %d, with a model %d" % [tool_ids.size(), held_ok, modelled])


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

	# Quick key T moves the hovered pack stack into the open chest.
	var stone_slot: int = inventory.numbers.find(stone)
	_chest_hover = [false, stone_slot]
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_T
	press.pressed = true
	quick_key(press)
	await get_tree().create_timer(1.0).timeout
	print("Chest test: quick key T, stones in chest %d, in pack %d" % [chest_inv.count_of(stone), inventory.count_of(stone)])


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
