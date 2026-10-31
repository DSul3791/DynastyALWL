extends Node
const RecipeFilter := preload("res://src/client/recipe_filter.gd")
const CraftPlanner := preload("res://src/shared/craft_planner.gd")
const Interact := preload("res://src/shared/interact_rules.gd")
const LogLookScript := preload("res://src/client/log_look.gd")
const LookTable := preload("res://src/client/look_table.gd")
const PileLookScript := preload("res://src/client/pile_look.gd")
const CarcassLook := preload("res://src/client/carcass_look.gd")
const RockLook := preload("res://src/client/rock_look.gd")
const BuildingLook := preload("res://src/client/building_look.gd")
const BasicLook := preload("res://src/client/basic_look.gd")

# The client side of items: the inventory panel (I), things lying on the ground (E picks up
# the nearest within reach) and the player key. The server owns all of it; this only shows
# what the server says and asks. Nothing is built until the panel is first opened, and the
# world items are a handful of small meshes within 100 m (the server caps them per chunk).

const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const RecipeTableScript := preload("res://src/shared/recipe_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")
const AdminScript := preload("res://src/stream/server_admin.gd")

const VitalsRules := preload("res://src/shared/vitals_rules.gd")
const CharacterScreenScript := preload("res://src/client/character_screen.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const CoverScript := preload("res://src/shared/cover.gd")
const KEY_FILE := "user://player_key.txt"
const PICKUP_M := 3.0
const BASIC_DROP_SCALE := 1.8           # loose items with a stage-one look (basic_look.gd) are drawn this much bigger so they show in the grass
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
const BOULDER_STATE := 10                 # the world-item row state of a boulder (server_items)
var _boulders: Dictionary = {}            # boulder world id -> {node, shape, lump, pos, left, total, radius, now}
var boulder_budget: Callable = Callable()   # () -> how many boulders may be drawn at once (by quality, the client sets it)
var _boulder_mesh: ArrayMesh
var _boulder_rock: ShaderMaterial
var _chest_buttons: Array = []
var _pack_buttons: Array = []
const DRINK_WINDOW_MSEC := 3000        # a rise in thirst this soon after drink() is a mouthful at the water
var _drink_msec: int = 0
var eat_event: Callable                # (item id) when something eaten or applied takes effect (sounds)
var hunger: int = 100                  # stomach, percent
var fitness: int = 0                  # the character's fitness, -10 to 10: how slowly exertion rises (character screen)
var luck: int = 0                     # the character's luck, -10 to 10, fixed (character screen)
var thirst: int = 100                  # body water, percent (100 = full; 0 = parched)
var health: int = 100
var breath_ds: int = -1                 # air left under water in tenths of a second; -1 = head above the surface (the oxygen symbol hides)
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
var notice_event: Callable = Callable()      # (text) every notice line, for the sounds that follow a server line (the shore net)
var stance_event: Callable = Callable()      # (stance) when the server confirms or changes it
const SINK_M := 0.35                        # most the remains sink into the ground by day 7 (death.json sink_m)
const DEATH_FADE_S := 4.0                   # black, then waking, after a death (death.json respawn_delay_s)
var _death_msec: int = 0                    # when the last death arrived, 0 when none is being shown
var strength: int = 0                       # attributes the server sends with the skills (protocol 37)
var memory: int = 0
var skill_rows: Array = []                  # [[skill index, working level, rusty], ...] in skills.json order
const InnerSettingsScript := preload("res://src/client/inner_voice_settings.gd")
var inner_settings = InnerSettingsScript.new()   # Esc > Settings > Inner voice: hints and dialogue switches (inner_voice_settings.gd)
var thought_event: Callable = Callable()     # (line id, kind) when the inner voice speaks: Sounds plays inner_voice/<line id>.ogg if it exists
var _thought_label: Label
var _thought_until_msec: int = 0
var worn: PackedInt32Array = PackedInt32Array()   # item number per body slot (clothing.json order), 0 = nothing (protocol 40)
var clothing_cfg: Dictionary = {}
const TrackingScript := preload("res://src/shared/tracking.gd")
var trail_mult: float = 1.0                 # Tracking skill -> trail life multiple, 1.0 to 6.0 (see _update_trail_mult)
var _tracking_index: int = -1               # position of "tracking" in skills.json order, found once
var _cooking_cfg: Dictionary = {}
var _structures_cfg: Dictionary = {}
var remains_marks: Array = []                # [[position, seconds left, msec received], ...] the owner's remains with gear (protocol 39)
var sick_hours: int = 0                      # game hours of sickness left, 0 = well (protocol 38)
var _sick_label: Label
var warmth: int = 100                       # body warmth, percent (protocol 36)
var energy: int = 100                       # the Energy pool, percent (job 95)
var forced_sleep: bool = false               # collapsed from exhaustion: asleep and cannot wake until rested (bit 8 of the stance)
var asleep: bool = false                     # the server says this character sleeps (bit 4 of the stance it sends, job 86)
var reject_event: Callable = Callable()   # ("far" | "no_tool" | "full_pack" | "other") when the server refused an action
var strain_event: Callable = Callable()   # (strain, state, fade) whenever the server sends a change
var _strain_note: Label
var _eat_item: String = ""
var equip_requested: Callable = Callable()   # (slot) -> hold that tool, or put it away (the client wires it to the held item)
var held_slot_now: Callable = Callable()     # () -> the pack slot in hand, or -1 for empty hands
var hotbar_strip                              # HotbarStrip, set by the client
var heart_bpm: Callable = Callable()   # () -> the heart rate now (the heartbeat sound's), set by the client
var _character                         # CharacterScreen, built the first time Tab is pressed
var _panel_bars: Dictionary = {}       # "Health", "Exertion", "Food", "Water" -> ProgressBar at the top of the inventory screen (the only bars in the game)
var _vitals_back: Control
var _vitals_warning: Label
var _weight_label: Label
var _purse_label: RichTextLabel
var _shoulder_put: Button                     # chest window: puts the shoulder log in (ACT_CHEST_PUT slot -1)
var shoulder_id: String = ""                  # the large log on the shoulder (protocol 64), "" when none: Mandy shows the carry pose from this
var purse_copper: int = 0                      # the purse, in copper (protocol 61)
var rep_names: PackedStringArray = PackedStringArray()   # NPCs this player has a reputation with, and the points
var rep_points: PackedInt32Array = PackedInt32Array()
var _coins_cfg: Dictionary = {}
var _rep_cfg: Dictionary = {}
var _carry_bar: ProgressBar              # carried weight against what you can carry: green, yellow from 70 percent, red from 80
var plant_aimed: bool = true             # the plant to gather is straight ahead, within the prompt reach (harvest.gd)
var plant_hint: String = ""            # set by the harvest prompt (harvest.gd)
var _crafting: int = 0                # recipe at the head of the server's queue (0 none); the work sounds follow it
var craft_entries: Array = []          # the server's crafting queue: [[recipe, crafts left], ...], head first
var _craft_head_end_msec: int = 0      # when the head craft finishes (from the server's time left)
var _queue_box: VBoxContainer
var _queue_head_button: Button
var _queue_next_msec: int = 0
var _world: Dictionary = {}        # id -> {node, number, count, pos}
var ladders: Dictionary = {}       # id -> {pos, yaw} of every placed ladder (state 31), for ladder_climb.gd
var _prompt_next_msec: int = 0
var _notice_until_msec: int = 0
var _collide: Array = []              # [node, StaticBody3D] trunks whose collider is on only near the player
var _meshes: Dictionary = {}       # item number -> Mesh


const FrameProbe := preload("res://src/debug/frame_probe.gd")
const AutoPickupScript := preload("res://src/client/auto_pickup.gd")

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
	net.energy_received.connect(_on_energy)
	net.warmth_received.connect(_on_warmth)
	net.sick_received.connect(_on_sick)
	net.body_received.connect(func(bpm, eta, phase): body_bpm = bpm; sleep_eta_s = eta; body_phase = phase)
	net.limp_received.connect(func(percent): limp_share = clampf(float(percent) / 100.0, 0.1, 1.0))
	net.remains_received.connect(_on_remains_marks)
	net.worn_received.connect(_on_worn)
	net.thought_received.connect(_on_thought)
	net.skills_received.connect(_on_skills)
	net.purse_received.connect(func(copper): purse_copper = copper; _refresh_purse())
	net.carry_received.connect(func(item_id):
		shoulder_id = item_id

		if chest_mode:
			_refresh_chest()

		if _weight_label != null:
			_refresh_weight())
	net.reputation_received.connect(func(_ids, names, points): rep_names = names; rep_points = points)
	var coins_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/coins.json"))
	_coins_cfg = coins_parsed if typeof(coins_parsed) == TYPE_DICTIONARY else {}
	var rep_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/reputation.json"))
	_rep_cfg = rep_parsed if typeof(rep_parsed) == TYPE_DICTIONARY else {}
	net.died_received.connect(_on_died)
	net.breath_received.connect(func(deciseconds: int) -> void: breath_ds = deciseconds)
	net.strain_received.connect(_on_strain)
	net.craft_queue_received.connect(_on_craft_queue)
	net.reject_received.connect(_on_reject)
	var exertion_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/exertion.json"))
	_exertion_cfg = exertion_parsed if typeof(exertion_parsed) == TYPE_DICTIONARY else {}
	_vitals_cfg = VitalsRules.load_config()
	_carry_cfg = CarryRules.load_config()
	_register_builtin_interactables()
	_build_vitals_hud()
	auto_pickup = AutoPickupScript.new()
	_auto_label = Label.new()
	_auto_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_auto_label.anchor_top = 0.38
	_auto_label.anchor_bottom = 0.38
	_auto_label.offset_top = -30.0
	_auto_label.offset_bottom = 30.0
	_auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_auto_label.add_theme_font_size_override("font_size", 36)
	_auto_label.add_theme_constant_override("outline_size", 8)
	_auto_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_auto_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_auto_label)
	_prompt = Label.new()
	# Below the crosshair, top-aligned and wrapping downward; the name (terrain_client.gd _inspect_label) is bottom-aligned above the crosshair.
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = 0.0
	_prompt.offset_right = 0.0
	_prompt.offset_top = 24.0
	_prompt.offset_bottom = 0.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_thought_label = Label.new()
	_thought_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_thought_label.offset_top = -190.0
	_thought_label.offset_left = -520.0
	_thought_label.offset_right = 520.0
	_thought_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thought_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thought_label.add_theme_font_size_override("font_size", 28)
	_thought_label.add_theme_constant_override("outline_size", 6)
	_thought_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_thought_label.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))
	_thought_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_thought_label)
	net.hello.rpc_id(1, _player_key())


# Public for the Esc > Advanced "Show my player key" button (admin.json lists these keys).
func player_key() -> String:
	return _player_key()


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
	if dialogue_open and dialogue_close.is_valid():
		dialogue_close.call()

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
	return CarryRules.cap_kg(carry_body_kg(), _carry_cfg) if not _carry_cfg.is_empty() else 0.0


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
	return {"prompt": "Press E to gather", "quiet": not aimed_at(_world[id]["pos"]), "tap": func():
		clear_prompt()
		net.inventory_action.rpc_id(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)}


# Dave 2026-10-22: the pick text shows only for something you are looking straight at, within interact.json prompt_reach_m. E still
# picks up what is merely near (reach_m), without the text. Unset view direction (tests) counts as aimed.
func aimed_at(point: Vector3) -> bool:
	if not view_direction.is_valid():
		return true

	var eye: Vector3 = _player_position.call() + Vector3(0.0, 1.6, 0.0)
	var to: Vector3 = point - eye

	if Vector2(to.x, to.z).length() > Interact.prompt_reach_m():
		return false

	var forward: Vector3 = view_direction.call()
	return forward.length() < 0.01 or to.normalized().dot(forward.normalized()) >= Interact.aim_cos()


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

	if _lit_state(state):
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

	if state == 11 or state == 12:
		return {"prompt": "Press E to search the remains", "tap": func(): _ask_open(id)}

	if state == 6:
		return {"prompt": "Press F to open", "tap": func(): _ask_open(id), "hold": take_down}

	if state == 7:
		return {"prompt": "Press E to split firewood", "tap": pick_up_nearest}

	if state == 33:
		return {"prompt": "Press E to take the stones back (hold E to pick up the pile)", "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	if state == 26 or state == 28:
		return {"prompt": "Press E to open the door" if state == 26 else "Press E to close the door", "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	var station_def: Dictionary = _structure_by_state(state)

	if str(station_def.get("station", "")) != "":
		return {"prompt": "Press F to use the %s" % table.name_of(_world[id]["number"]).to_lower(), "tap": _open_station, "hold": take_down}

	return {"prompt": "Hold E to take down the %s" % table.name_of(_world[id]["number"]).to_lower(), "tap": func(): show_notice("Hold E to take it down"), "hold": take_down}


func press_e() -> bool:
	# In the crafting window, E over a recipe crafts one of it (Dave 2026-10-23).
	if open and not chest_mode and _hover_recipe != 0:
		if _can_craft(_hover_recipe):
			_start_craft(_hover_recipe, 1)
		else:
			_on_notice("You do not have what that needs")

		return true

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
		return "Press E to light"

	return "Press E to add wood"


# F (Dave 2026-10-22): opens the container you stand beside, your pack on the left and its contents on the right (T moves the selected stack across).
# True when a chest, remains, campfire or crafting station lay within reach and it was opened (a station opens the crafting screen).
# The id of the chest, station, fire or remains within reach of the player (0 when none): what F opens.
func _container_near() -> int:
	var here: Vector3 = _player_position.call()
	var best: int = 0
	var best_d: float = 3.0

	for id in _world:
		var state: int = int(_world[id]["state"])
		var is_station: bool = str(_structure_by_state(state).get("station", "")) != ""

		if (is_station or state == 6 or state == 11 or state == 12 or _lit_state(state) or state == 8 or state == 9) and here.distance_to(_world[id]["pos"]) <= best_d:
			best_d = here.distance_to(_world[id]["pos"])
			best = id

	return best


var _last_f_ms: int = -100000
var _carried_slot: Label      # the read-only "Carried" slot: the log on the shoulder, when there is one

const FPress := preload("res://src/client/f_press.gd")


# The F key: opens the chest, station, fire or remains beside you; with a log on the shoulder and nothing to open, F twice within 0.6 s puts the log down (the first F says so).
func press_f(now_ms: int) -> void:
	match FPress.decide(shoulder_id != "", _container_near() != 0, now_ms, _last_f_ms):
		"drop":
			_last_f_ms = -100000
			lay_down_shoulder()
		"hint":
			_last_f_ms = now_ms
			_on_notice("F again to put the log down")
		_:
			open_container()


func open_container() -> bool:
	var best: int = _container_near()

	if best == 0:
		return false

	if str(_structure_by_state(int(_world[best]["state"])).get("station", "")) != "":
		_open_station()
		return true

	_ask_open(best)
	return true


# A workbench or forge has no slots of its own: using it opens the crafting screen, which greys what the station cannot make.
func _open_station() -> void:
	if not open:
		toggle()


# True when something lay within reach and the server was asked for it.
func pick_up_nearest() -> bool:
	var id: int = _nearest()[0]

	if id == 0:
		id = _nearest_struct()

	if id == 0:
		return false

	if _world[id]["state"] == 6 and not Input.is_key_pressed(KEY_SHIFT):
		_ask_open(id)
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

	# The bigger stations also need clay and hides (stone forge, masonry forge).
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("clay"), 0, 10, Vector3.ZERO)
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("hide"), 0, 4, Vector3.ZERO)


func _process(_delta: float) -> void:
	var t: int = FrameProbe.start()
	_process_body(_delta)
	FrameProbe.stop("inventory view", t)


func _process_body(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	_roll_tick(_delta, now)
	_snap_tick(now)
	_hold_e_check()
	_auto_pickup_tick(now)

	if _thought_label != null and _thought_label.text != "" and now >= _thought_until_msec:
		_thought_label.text = ""

	if _strain_note != null:
		_strain_note.text = ("Exhausted: you sleep until you are rested, about %d min left%s" % [maxi(int(ceil(float(sleep_eta_s) / 60.0)), 1), "; hold Space to wake early" if energy >= 30 else " (hold Space to wake early once energy is 30 percent)"]) if forced_sleep else "Asleep: any key wakes you" if asleep else ("You are exhausted: slow down" if strain_state == 1 else "")

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
	var interaction: Dictionary = current_interaction()
	_prompt.text = "" if bool(interaction.get("quiet", false)) else str(interaction.get("prompt", ""))

	if _prompt.text == "" and stance_confirmed == 3 and not asleep and strain_state < 2:
		_prompt.text = "Hold Z to sleep"



# P (terrain_client.gd): auto pickup on or off, announced slightly above the middle of the screen.
var auto_pickup: RefCounted
var auto_pickup_blocked: Callable = Callable()   # () -> true while swimming or placing a blueprint (set by the terrain client)
var _auto_label: Label


func toggle_auto_pickup() -> void:
	_auto_label.text = auto_pickup.toggle(Time.get_ticks_msec())


func _auto_pickup_tick(now: int) -> void:
	if _auto_label != null and _auto_label.text != "":
		var left: int = auto_pickup.announce_until_msec - now
		_auto_label.modulate.a = clampf(float(left) / 500.0, 0.0, 1.0)

		if left <= 0:
			_auto_label.text = ""

	if not auto_pickup.enabled or asleep or screen_open() or now - _death_msec < 6000 or (auto_pickup_blocked.is_valid() and bool(auto_pickup_blocked.call())):
		return

	var id: int = auto_pickup.next_pick(_world, _player_position.call(), Interact.reach_m(), now, inventory.counts.hash(), in_view)

	if id != 0:
		net.inventory_action.rpc_id(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)


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
		if _world[id]["state"] >= 5 and _world[id]["state"] != 32 and here.distance_to(_world[id]["pos"]) <= best_d:
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
	var best_d: float = Interact.reach_m()

	for id in _world:
		if _world[id]["state"] != 0 or (view_only and not in_view(_world[id]["pos"])):
			continue

		var d: float = here.distance_to(_world[id]["pos"])

		if d <= best_d:
			best_d = d
			best = [id, _world[id]["number"], _world[id]["count"]]

	return best


# The id of the felled trunk lying within 1.5 m of a point (the axe struck it), 0 when none.
# The nearest carcass within 3 m of a point (the knife works it), or 0.
func carcass_near(point: Vector3) -> int:
	var best: int = 0
	var best_d: float = 3.2

	for id in _world:
		var entry: Dictionary = _world[id]

		if entry["state"] == 19 and is_instance_valid(entry["node"]):
			var d: float = point.distance_to(entry["pos"])

			if d < best_d:
				best_d = d
				best = id

	return best


# A log lying loose on the ground within 1.5 m of the point (a short log or a large one put down), 0 when none: the axe chops it into wooden blocks.
func loose_log_near(point: Vector3) -> int:
	for id in _world:
		var entry: Dictionary = _world[id]

		if int(entry["state"]) != 0 or not entry.has("number") or int(entry["number"]) == 0:
			continue

		var item_id: String = table.id_of(int(entry["number"]))

		if (item_id == "log" or str(table.entry(item_id).get("carry", "")) == "shoulder") and entry["pos"].distance_to(point) < 1.5:
			return id

	return 0


# The id of a stump within reach of a point (the axe struck near it), 0 when none: the axe chops it up (server_items.gd _chop_stump).
func stump_near(point: Vector3) -> int:
	for id in _world:
		var entry: Dictionary = _world[id]

		if int(entry["state"]) == 4 and is_instance_valid(entry["node"]):
			var radius: float = float(entry.get("extra", {}).get("radius", 0.3))

			if Vector2(point.x - entry["pos"].x, point.z - entry["pos"].z).length() < radius + 0.9 and absf(point.y - entry["pos"].y) < 1.6:
				return id

	return 0


func felled_trunk_near(point: Vector3) -> int:
	for id in _world:
		var entry: Dictionary = _world[id]

		if entry["state"] == 3 and is_instance_valid(entry["node"]):
			var extra: Dictionary = entry.get("extra", {})
			var yaw: float = float(extra.get("yaw", 0.0))
			var length: float = float(extra.get("length", 8.0))
			var along: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
			var t: float = clampf((point - entry["pos"]).dot(along), 0.0, length * cos(float(extra.get("pitch", 0.0))))
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
	if notice_event.is_valid():
		notice_event.call(text)

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
	var orig_length: float = maxf(float(extra.get("orig_length", length)), length)
	cyl.top_radius = radius * ((1.0 - 0.45 * length / orig_length) if trunk else 0.95)   # a shortened trunk is thicker at its fresh cut end
	cyl.bottom_radius = radius
	cyl.height = length if trunk else maxf(radius * 1.2, 0.5)
	cyl.material = bark
	mesh_node.mesh = cyl
	root.add_child(mesh_node)
	# Looks (Kathleen, stage-1 pass): a pale cut face with a darker ring on the stump top and at both ends of the trunk, a few snapped branch stubs
	# along the trunk and root swell round the stump foot, so a felled tree is not a bare drum.
	var cut: StandardMaterial3D = StandardMaterial3D.new()
	cut.albedo_color = Color(0.72, 0.58, 0.38)
	var ring: StandardMaterial3D = StandardMaterial3D.new()
	ring.albedo_color = Color(0.5, 0.36, 0.2)

	for end in ([-1.0, 1.0] if trunk else [1.0]):
		var face: MeshInstance3D = MeshInstance3D.new()
		var disc: CylinderMesh = CylinderMesh.new()
		var r_end: float = cyl.top_radius if end > 0.0 else cyl.bottom_radius
		disc.top_radius = r_end * 0.93
		disc.bottom_radius = r_end * 0.93
		disc.height = 0.012
		disc.material = cut
		face.mesh = disc
		face.position = Vector3(0.0, end * cyl.height * 0.5 + end * 0.004, 0.0)
		mesh_node.add_child(face)
		var core: MeshInstance3D = MeshInstance3D.new()
		var inner: CylinderMesh = CylinderMesh.new()
		inner.top_radius = r_end * 0.55
		inner.bottom_radius = r_end * 0.55
		inner.height = 0.016
		inner.material = ring
		core.mesh = inner
		core.position = face.position + Vector3(0.0, end * 0.001, 0.0)
		mesh_node.add_child(core)

	if trunk and bool(extra.get("keywood", false)) and length > 2.44 * 1.2:   # the next cut line: a pale band round the trunk one log length from the far end
		var cut_at: float = (length - 2.44) / length
		var band: MeshInstance3D = MeshInstance3D.new()
		var band_cyl: CylinderMesh = CylinderMesh.new()
		var band_r: float = lerpf(cyl.bottom_radius, cyl.top_radius, cut_at) * 1.04
		band_cyl.top_radius = band_r
		band_cyl.bottom_radius = band_r
		band_cyl.height = 0.07
		var band_mat: StandardMaterial3D = StandardMaterial3D.new()
		band_mat.albedo_color = Color(0.92, 0.82, 0.55)
		band_mat.emission_enabled = true
		band_mat.emission = Color(0.35, 0.3, 0.15)
		band_cyl.material = band_mat
		band.mesh = band_cyl
		band.position = Vector3(0.0, length * 0.5 - 2.44, 0.0)
		mesh_node.add_child(band)

	var stub_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	stub_rng.seed = int(radius * 1000.0) + int(length)

	if trunk:
		for k in range(4):
			var stub: MeshInstance3D = MeshInstance3D.new()
			var twig: CylinderMesh = CylinderMesh.new()
			twig.top_radius = radius * 0.06
			twig.bottom_radius = radius * 0.12
			twig.height = radius * 1.1
			twig.material = bark
			stub.mesh = twig
			var along: float = stub_rng.randf_range(-0.35, 0.4) * cyl.height
			var ang: float = stub_rng.randf() * TAU
			var local_r: float = lerpf(cyl.bottom_radius, cyl.top_radius, along / cyl.height + 0.5)
			stub.position = Vector3(cos(ang) * local_r, along, sin(ang) * local_r)
			stub.rotation = Vector3(sin(ang) * 1.2, 0.0, -cos(ang) * 1.2)
			mesh_node.add_child(stub)

	if not trunk:
		mesh_node.position = Vector3(0.0, cyl.height * 0.5, 0.0)

		for k in range(5):
			var swell: MeshInstance3D = MeshInstance3D.new()
			var fin: BoxMesh = BoxMesh.new()
			fin.size = Vector3(radius * 0.9, radius * 0.35, radius * 0.22)
			fin.material = bark
			swell.mesh = fin
			var a2: float = TAU * float(k) / 5.0 + stub_rng.randf() * 0.5
			swell.position = Vector3(cos(a2) * radius * 0.95, radius * 0.1, sin(a2) * radius * 0.95)
			swell.rotation = Vector3(0.0, -a2, 0.0)
			root.add_child(swell)

		return root

	# Hinge at the stump: pivot turns from upright to lying, over about 1.5 s.
	root.rotation.y = float(extra.get("yaw", 0.0))
	var pivot: Node3D = Node3D.new()
	root.add_child(pivot)
	root.remove_child(mesh_node)
	pivot.add_child(mesh_node)
	mesh_node.position = Vector3(0.0, length * 0.5, 0.0)
	var lie: float = deg_to_rad(90.0)
	var pitch: float = float(extra.get("pitch", 0.0))   # the server's resting pitch (fell_pose.gd): rises with a slope, follows a falling one
	var has_pose: bool = extra.has("pitch")
	var rest: float = lie - pitch if has_pose else lie + asin(clampf(radius * 0.45 / maxf(length, 0.5), 0.0, 0.5))   # an older record keeps the level lie with the taper dip
	pivot.position.y = radius   # the axis rides one butt radius up, so the log rests ON the ground instead of sunk in it (collision is at this height)
	pivot.rotation.x = 0.0
	if bool(extra.get("landed", false)):
		pivot.rotation.x = rest      # already lying (a log was cut off it): no fall again
	else:
		var tween: Tween = pivot.create_tween()
		# The trunk tapers to 55 percent at the top: dip the far end by the lost radius so it lies on the ground along its whole length.
		tween.tween_property(pivot, "rotation:x", rest, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius * 0.8
	capsule.height = length
	shape.shape = capsule
	shape.rotation.x = rest
	shape.position = Vector3(0.0, radius + sin(pitch) * length * 0.5, cos(pitch) * length * 0.5)
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
				elif inventory.wear[slot] < was_wear and int(table.entry(table.id_of(was_number)).get("durability", 0)) > 0:
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
		lines.append("You are low on food")

	if thirst <= 0:
		lines.append("You are parched: you do not recover")
	elif thirst <= warn_thirst:
		lines.append("You are low on water")

	_vitals_warning.text = "\n".join(lines)

	if _weight_label != null:
		_refresh_weight()


# Kilograms in the pack (the server counts the same way).
func carried_kg() -> float:
	if _carry_cfg.is_empty():
		return 0.0

	return CarryRules.carried_kg(inventory, table, _carry_cfg) + (CarryRules.weight_of(shoulder_id, _carry_cfg) if shoulder_id != "" else 0.0)


# Q or D with nothing selected: lay the log on your shoulder down in front of you.
func lay_down_shoulder() -> void:
	if shoulder_id == "":
		_on_notice("You are not carrying a log.")
		return

	var here: Vector3 = _player_position.call()
	net.inventory_action.rpc_id(1, Net.ACT_DROP, -1, 0, 1, here)


# Walking speed multiplier for the load: 1 when comfortable, easing down past it.
var body_bpm: int = 0          # protocol 59: the heart in the ears, 0 awake
var sleep_eta_s: int = 0       # real seconds until awake (asleep or fainted)
var body_phase: int = 0        # 0 awake, 1 falling asleep, 2 out, 3 waking
var limp_share: float = 1.0   # server: a crippling injury slows the walker (protocol 58); Mandy reads this for the limping gait


func speed_factor() -> float:
	return (CarryRules.speed_factor(carried_kg(), carry_body_kg(), _carry_cfg) if not _carry_cfg.is_empty() else 1.0) * limp_share


# The purse as words, cheapest coin first: "4 copper, 3 bronze, 2 silver" (copper = items.json value unit). Used where only text fits
# (tooltips, notices); windows draw coin icons instead (fill_coin_line).
func coin_text(copper: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var left: int = copper
	var rows: Array = _coins_cfg.get("ladder", []).duplicate()

	rows.sort_custom(func(x, y): return int(x["copper"]) > int(y["copper"]))

	for row in rows:
		var each: int = maxi(int(row["copper"]), 1)

		if left >= each:
			@warning_ignore("integer_division")
			parts.insert(0, "%d %s" % [left / each, str(row["name"])])
			left = left % each

	return ", ".join(parts) if not parts.is_empty() else "nothing"


# Coin icons (Dave 2026-10-22): a small filled circle in the coin's colour, shown instead of the words copper, bronze, silver, gold.
const COIN_COLOURS := {"coin_copper": Color(0.78, 0.42, 0.22), "coin_bronze": Color(0.55, 0.40, 0.16), "coin_silver": Color(0.78, 0.80, 0.84), "coin_gold": Color(0.96, 0.76, 0.18)}
static var _coin_icons: Dictionary = {}


static func coin_icon(coin_id: String) -> Texture2D:
	if _coin_icons.has(coin_id):
		return _coin_icons[coin_id]

	var size: int = 32
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var fill: Color = COIN_COLOURS.get(coin_id, Color.WHITE)
	var rim: Color = fill.darkened(0.45)
	var centre: float = float(size) * 0.5 - 0.5

	for y in size:
		for x in size:
			var d: float = Vector2(float(x) - centre, float(y) - centre).length()

			if d <= 15.0:
				image.set_pixel(x, y, rim if d > 12.0 else fill.lightened(0.18) if d < 6.0 and float(x) < centre and float(y) < centre else fill)

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_coin_icons[coin_id] = texture
	return texture


# A label that can hold coin icons beside numbers and words.
func make_coin_label(px: int) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_PASS   # so a coin's hint (its name) shows on mouse-over
	label.custom_minimum_size = Vector2(0.0, float(px) * 1.4)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("normal_font_size", px)
	label.set_meta("px", px)
	return label


# Fills the label with segments: a String is text, an int is a coin amount in copper drawn as "4 (copper icon) 3 (bronze icon) ...",
# cheapest coin first (copper, bronze, silver, gold, left to right). A zero amount reads "nothing".
func fill_coin_line(label: RichTextLabel, segments: Array) -> void:
	label.clear()
	var px: int = int(label.get_meta("px", 24))
	var rows: Array = _coins_cfg.get("ladder", []).duplicate()
	rows.sort_custom(func(x, y): return int(x["copper"]) < int(y["copper"]))

	for segment in segments:
		if typeof(segment) == TYPE_STRING:
			label.add_text(segment)
			continue

		var left: int = int(segment)
		var amounts: Array = []

		for row in rows.duplicate():
			amounts.append([row, 0])

		for n in range(amounts.size() - 1, -1, -1):
			var each: int = maxi(int(amounts[n][0]["copper"]), 1)
			@warning_ignore("integer_division")
			amounts[n][1] = left / each
			left = left % each

		var any: bool = false

		for pair in amounts:
			if int(pair[1]) > 0:
				if any:
					label.add_text("  ")

				any = true
				label.push_hint("%s coin" % str(pair[0]["name"]).capitalize())
				label.add_text("%d " % int(pair[1]))
				label.add_image(coin_icon(str(pair[0]["id"])), int(px * 0.8), int(px * 0.8))
				label.pop()

		if not any:
			label.add_text("nothing")


func rank_word(points: int) -> String:
	var word: String = "Stranger"

	for row in _rep_cfg.get("ranks", []):
		if points >= int(row["at"]):
			word = str(row["name"])

	return word


func _refresh_purse() -> void:
	if _purse_label != null:
		fill_coin_line(_purse_label, ["Purse: ", purse_copper])


func _refresh_carried() -> void:
	if _carried_slot != null:
		_carried_slot.visible = shoulder_id != ""
		_carried_slot.text = ("Carried: %s   (F twice or Q puts it down)" % table.name_of(table.number_of(shoulder_id))) if shoulder_id != "" else ""


func _refresh_weight() -> void:
	_refresh_carried()
	_weight_label.text = _load_text() + "\nBody weight %.1f kg   (food %d%%, health %d)" % [weight_kg, hunger, health]

	if _carry_bar != null and not _carry_cfg.is_empty():
		var fraction: float = CarryRules.bar_fraction(carried_kg(), carry_body_kg(), _carry_cfg)
		_carry_bar.value = fraction * 100.0
		_carry_bar.get_theme_stylebox("fill").bg_color = CarryRules.bar_color(fraction)


func _load_text() -> String:
	var load_kg: float = carried_kg()
	var free: float = CarryRules.comfort_kg(carry_body_kg(), _carry_cfg)
	var limit: float = CarryRules.cap_kg(carry_body_kg(), _carry_cfg)
	var state: String = "" if load_kg <= free else ("   (heavy: you move slower)" if load_kg < limit else "   (at the limit)")
	return "Carrying %.1f kg of %.0f kg you can carry%s" % [load_kg, limit, state] + ("\nOn your shoulder: %s (Q lays it down)" % table.name_of(table.number_of(shoulder_id)) if shoulder_id != "" else "")


func _on_strain(strain_pm: int, state: int, fade_pm: int, stance: int) -> void:
	strain = float(strain_pm) / 1000.0
	strain_state = state
	strain_fade = float(fade_pm) / 1000.0
	stance_confirmed = stance & 3
	asleep = (stance & 4) != 0
	forced_sleep = (stance & 8) != 0
	_update_panel_bars()

	if _character != null:
		_character.refresh()

	if stance_event.is_valid():
		stance_event.call(stance & 3)

	if strain_event.is_valid():
		strain_event.call(strain, state, strain_fade)


# Ask the server for a stance (0 stand, 1 crouch, 2 sit, 3 lie). It answers through stance_confirmed / stance_event.
func request_stance(wanted: int) -> void:
	net.inventory_action.rpc_id(1, Net.ACT_STANCE, wanted, 0, 0, Vector3.ZERO)


# Ask to fall asleep (1) or wake (0); the server answers through the stance it sends (bit 4 = asleep).
func request_sleep(want: int) -> void:
	net.inventory_action.rpc_id(1, Net.ACT_SLEEP, want, 0, 0, Vector3.ZERO)


# Movement the over-exertion allows: -1 none (fainted or waking), else a speed cap in m/s (0 = no cap).
func move_cap() -> float:
	if strain_state >= 2 or forced_sleep:
		return -1.0

	# Over-exerted is only a slow-down (over_speed_factor, see over_pace_factor); running on is allowed until the blackout.
	return 0.0


# Over-exerted (Dave 2026-10-21): the pace is cut by about 10 percent but the player may keep running and keep pushing the
# exertion up until they black out.
func over_pace_factor() -> float:
	return float(_exertion_cfg.get("over_speed_factor", 0.9)) if strain_state == 1 else 1.0



# The picture's state name and progress for faint.set_state (Art's faint_effect.gd): vision fades over the
# first vision_frac of a faint ("fainting", progress 0 to 1), then "fainted" holds black while only the heart is heard.
func faint_state() -> Array:
	if _death_msec > 0:
		var t: float = float(Time.get_ticks_msec() - _death_msec) / (DEATH_FADE_S * 1000.0)

		if t < 0.25:
			return ["fainted", 1.0]

		if t < 1.0:
			return ["waking", 1.0 - (t - 0.25) / 0.75]

		_death_msec = 0

	if asleep and strain_state < 2:
		return ["sleeping", 1.0]

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

	# A mouthful at the water's edge (drink()) took effect: the gulp sound (Dave 2026-10-21: no sound when drinking).
	if new_thirst > thirst and _drink_msec > 0 and Time.get_ticks_msec() - _drink_msec < DRINK_WINDOW_MSEC and eat_event.is_valid():
		eat_event.call("drink")

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
	_drink_msec = Time.get_ticks_msec()
	net.inventory_action.rpc_id(1, Net.ACT_DRINK, held_container_slot(), 0, 0, Vector3.ZERO)


# Water containers (job 89): the container's water is kept in its slot's wear field (millilitres).
func container_cap(slot: int) -> int:
	if slot < 0 or slot >= inventory.SLOTS or inventory.numbers[slot] == 0:
		return 0

	return int(table.entry(table.id_of(inventory.numbers[slot])).get("capacity_ml", 0))


# The hotbar slot of the container in hand, or -1.
func held_container_slot() -> int:
	var slot: int = int(held_slot_now.call()) if held_slot_now.is_valid() else -1
	return slot if container_cap(slot) > 0 else -1


func held_container_has_room() -> bool:
	var slot: int = held_container_slot()
	return slot >= 0 and inventory.wear[slot] < container_cap(slot)


func held_container_has_water() -> bool:
	var slot: int = held_container_slot()
	return slot >= 0 and inventory.wear[slot] > 0


func _litres(ml: int) -> String:
	return "%.1f L" % (float(ml) / 1000.0) if ml >= 100 else "%d ml" % ml


# Can this item be eaten or applied (food or medicine in data/items/vitals.json)?
func edible_slot(slot: int) -> bool:
	return slot >= 0 and slot < inventory.SLOTS and inventory.numbers[slot] != 0 and VitalsRules.edible(table.id_of(inventory.numbers[slot]), _vitals_cfg)


func equippable_slot(slot: int) -> bool:
	if slot < 0 or slot >= inventory.SLOTS or inventory.numbers[slot] == 0:
		return false

	var entry: Dictionary = table.entry(table.id_of(inventory.numbers[slot]))
	return entry.has("tool_class") or entry.has("weapon_class") or str(entry.get("kind", "")) in ["tool", "weapon", "placeable", "container", "blueprint"]


# Hold a tool: from the hotbar slots straight away; from the rest of the pack it first moves into the first free hotbar slot
# (never replacing anything: a full hotbar says so), so a slot key can pick it up again.
func equip_with_move(slot: int) -> void:
	var target: int = slot

	if slot >= 10:
		target = -1

		for candidate in range(10):
			if inventory.numbers[candidate] == 0:
				target = candidate
				break

		if target < 0:
			_on_notice("Your hotbar is full. Clear a slot first.")
			return

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


# E over a hotbar slot (inventory open) puts it back in the first free pack slot after the hotbar.
var hotbar_hover: int = -1


func hotbar_to_pack(slot: int) -> void:
	if slot < 0 or slot >= 10 or inventory.numbers[slot] == 0:
		return

	for candidate in range(10, inventory.SLOTS):
		if inventory.numbers[candidate] == 0:
			move_slot(slot, candidate)
			return

	_on_notice("Your inventory is full. Make room first.")


func refresh_hotbar() -> void:
	if hotbar_strip != null:
		hotbar_strip.refresh()


func hotbar_tip(slot: int) -> String:
	return _tooltip(inventory.numbers[slot], inventory.counts[slot], inventory.wear[slot]) + ("\nKeys: Use (E) moves it into the inventory" if open else "") if inventory.numbers[slot] != 0 else "Drag an item here from the inventory. Key %s holds it." % ("0" if slot == 9 else str(slot + 1))


# Eat the food or apply the medicine in a pack slot. Herbs that look like something else must be identified first.
func eat_slot(slot: int) -> void:
	# Use on clothing or a pack puts it on.
	if slot >= 0 and slot < inventory.SLOTS and inventory.numbers[slot] != 0 and clothing_slots().has(str(table.entry(table.id_of(inventory.numbers[slot])).get("slot", "-"))):
		net.inventory_action.rpc_id(1, Net.ACT_WEAR, slot, 0, 0, Vector3.ZERO)
		return

	# Use on a tool, weapon or kit holds it in the hand (and again puts it away); on food or medicine it eats or applies it;
	# on a water container that holds water it takes a mouthful.
	if container_cap(slot) > 0 and inventory.wear[slot] > 0:
		_drink_msec = Time.get_ticks_msec()
		net.inventory_action.rpc_id(1, Net.ACT_EAT, slot, 0, 0, Vector3.ZERO)
		return

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


# Asks the server to open a container. The server also pushes fresh contents while it is open (a fire eating wood); a push that arrives when
# no window is open and none was asked for in the last 2 s is ignored, so closing the window is not undone.
var _open_asked_msec: int = -100000


func _ask_open(id: int) -> void:
	_open_asked_msec = Time.get_ticks_msec()
	net.inventory_action.rpc_id(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)


func _on_chest(id: int, bytes: PackedByteArray) -> void:
	if not chest_mode and Time.get_ticks_msec() - _open_asked_msec > 2000:
		return

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
	net.inventory_action.rpc_id(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)

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
	_shoulder_put = Button.new()
	_shoulder_put.text = "Put the log from your shoulder in"
	_shoulder_put.tooltip_text = "The large log on your shoulder goes into the container (take it out again the same way, one log at a time)"
	_style(_shoulder_put, BODY_PX)
	_shoulder_put.pressed.connect(func(): net.inventory_action.rpc_id(1, Net.ACT_CHEST_PUT, -1, chest_id, 1, Vector3.ZERO))
	_shoulder_put.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chest_outer.add_child(_shoulder_put)
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

	if _shoulder_put != null:
		_shoulder_put.visible = shoulder_id != ""

	var capacity: int = int(table.entry(table.id_of(int(_world.get(chest_id, {}).get("number", 0)))).get("slots", inventory.SLOTS))

	for i in inventory.SLOTS:
		_chest_buttons[i].visible = i < capacity

		for pair in [[_chest_buttons, chest_inv], [_pack_buttons, inventory]]:
			var button: Button = pair[0][i]
			var source = pair[1]
			var number: int = source.numbers[i]
			button.text = "" if number == 0 else "%s\nx%d" % [table.name_of(number), source.counts[i]]
			button.tooltip_text = _tooltip(number, source.counts[i], source.wear[i])


func _on_world_items(added: Array, removed: PackedInt32Array) -> void:
	for id in removed:
		_forget(id)

	for row in added:
		var id: int = row[0]
		var state: int = int(row[4]) if row.size() > 4 else 0

		if state == BOULDER_STATE:
			_show_boulder(id, row)
			continue

		if _world.has(id):
			_world[id]["count"] = row[2]
			_refresh_pile(id)

			if int(_world[id]["state"]) == 0 and state == 0 and (row[3] as Vector3).distance_to(_world[id]["pos"]) > 0.05:
				_world[id]["pos"] = row[3]      # the server let it down onto the ground (after a dig): draw it there
				(_world[id]["node"] as Node3D).position = row[3] + Vector3(0.0, 0.12, 0.0)
				_snap_loose(id)

			if _world[id]["state"] == state:
				var shorter: bool = is_felled_state(state) and row.size() > 5 and absf(float((row[5] as Dictionary).get("length", 0.0)) - float((_world[id].get("extra", {}) as Dictionary).get("length", 0.0))) > 0.01

				if not shorter:
					continue

			_forget(id)   # a changed state, or a felled trunk with a log cut off: draw it again

		var node: Node3D
		var light: OmniLight3D = null

		if state >= 5 and state != 8 and state != 9 and not _lit_state(state):   # 8 is a burnt-out fire, 9 a loaded one: the campfire model without flames, light or sound
			var yaw: float = deg_to_rad(float(row[5].get("yaw", 0.0))) if row.size() > 5 else 0.0
			node = _model_for_state(state, row[5] if row.size() > 5 else {})
			node.position = row[3] - Vector3(0.0, SINK_M * float(row[5].get("age", 0.0)), 0.0) if (state == 11 or state == 12) and row.size() > 5 else row[3]
			node.rotation.y = yaw
			_root.add_child(node)
			var roof_key: int = -1

			if state == 5 and cover_index != null:
				roof_key = cover_index.add_roof(CoverScript.box_roof(Vector2(row[3].x, row[3].z), 1.1, 0.95, yaw, row[3].y - 0.5, row[3].y + 2.1))
			elif state == 24 and cover_index != null:
				roof_key = cover_index.add_roof(CoverScript.box_roof(Vector2(row[3].x, row[3].z), 1.2, 1.2, yaw, row[3].y - 0.5, row[3].y + 2.6))

			_world[id] = {"node": node, "number": row[1], "count": 1, "pos": row[3], "state": state, "light": null, "roof": roof_key, "yaw": rad_to_deg(yaw)}

			if StructureLook.look_of(state) == "ladder":
				ladders[id] = {"pos": row[3], "yaw": rad_to_deg(yaw)}

			continue

		if is_felled_state(state):   # only 3 (a trunk) and 4 (a stump): a loaded or burnt-out fire (8, 9) is NOT one, it was drawn as a stump (Dave, build 826)
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
			node = _make_fire(_lit_state(state), state == 9, _fire_tier(state))
			node.position = row[3]
			light = node.get_node_or_null("Light")

		if light == null:
			light = node.get_node_or_null("Light")   # the forges glow

		_root.add_child(node)
		_world[id] = {"node": node, "number": row[1], "count": row[2], "pos": row[3], "state": state, "light": light}
		_refresh_pile(id)
		_snap_loose(id)


# The server places a loose item by the generated height field; the drawn ground is the voxel surface, up to about half a metre off, so a
# lump could hang in the air (Dave 2026-10-23, rig: 0.40 m). A loose item within 1 m of the drawn ground rests on it; one whose chunk is not
# drawn yet is tried again each second.
const SNAP_UP_M := 0.6               # the drawn ground may be this far above the server's height (a lump rests on a rim)
const SNAP_DOWN_M := 8.0             # and an item that hangs this far above the ground comes down to it (a deep shaft: the rig saw 1.6 and 4.3 m)
const SNAP_TRIES := 10               # looked at again each second this many times: the collision ground under a fresh dig or fill is rebuilt a moment later
var _snap_next_msec: int = 0
var _unsnapped: Dictionary = {}      # world item id -> tries left


func _snap_loose(id: int, tries: int = SNAP_TRIES) -> void:
	var entry: Dictionary = _world.get(id, {})

	if entry.is_empty() or int(entry.get("state", 0)) != 0 or not _ground_below.is_valid() or _rolling.has(id):
		_unsnapped.erase(id)
		return

	var at: Vector3 = entry["pos"]
	var ground: float = float(_ground_below.call(at - Vector3(0.0, 1.5, 0.0)))      # the probe starts 2 m above its point: 0.5 m above the item, so a tunnel roof is not hit

	if is_nan(ground) or ground > at.y + SNAP_UP_M or ground < at.y - SNAP_DOWN_M:
		_unsnapped[id] = tries - 1 if tries > 1 else 0
		return

	_unsnapped[id] = tries - 1
	var node: Node3D = entry["node"]
	node.position = Vector3(at.x, ground + 0.12, at.z)


func _snap_tick(now: int) -> void:
	if _unsnapped.is_empty() or now < _snap_next_msec:
		return

	_snap_next_msec = now + 1000

	for id in _unsnapped.keys():
		var left: int = int(_unsnapped[id])

		if not _world.has(id) or left <= 0:
			_unsnapped.erase(id)
		else:
			_snap_loose(id, left)


# A heap of six or more stones (or soil, clay, sand, gravel) is drawn as one pile built from its count (PileLook); fewer are single items.
func _refresh_pile(id: int) -> void:
	var entry: Dictionary = _world[id]
	var box: MeshInstance3D = entry["node"] as MeshInstance3D
	var item_id: String = table.id_of(int(entry["number"]))

	if box == null or int(entry.get("state", 0)) != 0:
		return

	if PileLookScript.is_pile(table.entry(item_id), int(entry["count"])):
		box.mesh = PileLookScript.mesh_for(item_id, table.entry(item_id), int(entry["count"]), id)
		box.scale = Vector3.ONE
		box.rotation = Vector3.ZERO
		entry["pile"] = true
	elif entry.get("pile", false):
		entry["pile"] = false
		box.mesh = _mesh_for(int(entry["number"]))



# Fires and structures standing in the world as {"pos", "state"} rows, for the placement ghost's blocked check.
func foundation_rows() -> Array:
	var rows: Array = []

	for id in _world:
		var state: int = int(_world[id]["state"])

		if state >= 22 and state <= 28 and _world[id].has("yaw"):
			rows.append({"pos": _world[id]["pos"], "state": state, "yaw": _world[id]["yaw"]})

	return rows


func placed_rows() -> Array:
	var rows: Array = []

	for id in _world:
		var state: int = int(_world[id]["state"])

		if _lit_state(state) or state == 5 or state == 6 or state == 7 or state == 8 or state == 9 or state == 13 or state == 14 or state == 15 or state == 16 or state == 17 or state == 18 or state == 20 or state == 21 or state == 38:
			rows.append({"pos": _world[id]["pos"], "state": state})

	return rows


# Removes a world row's node and, for a lean-to, its roof in the cover index.
# Boulders (Dave 2026-10-21): server-owned lumps of rock a pick breaks into stones. Drawn with Art's boulder mesh scaled to the
# radius the server sends and shrinking as stones come out; solid, so the strike ray hits them. Kept apart from _world so
# nothing that walks the world items (gathering, fires, structures) mistakes one for something else.
func _show_boulder(id: int, row: Array) -> void:
	var extra: Dictionary = row[5] if row.size() > 5 else {}
	var left: int = int(row[2])

	if _boulders.has(id):
		_boulders[id]["left"] = left
		_size_boulder(_boulders[id])
		return

	if boulder_budget.is_valid() and _boulders.size() >= int(boulder_budget.call()):
		return   # drawn up to the quality budget; the rest wait until some are gone

	if _boulder_mesh == null:
		_boulder_mesh = load("res://src/client/grass_view.gd")._make_boulder()
		# Granite with moss (Kathleen, white-sphere fix): the plain mid-grey material drew server boulders near white in full sun, big smooth pale eggs. The scenery
		# boulder shader of grass_view.gd (stone mottle, moss on the tops and north side) is used instead, with its per-instance custom data turned into
		# uniforms and its distance fade switched off (a boulder the server sends must not melt away at 18 m).
		var shader: Shader = Shader.new()
		shader.code = String(load("res://src/client/grass_view.gd").BOULDER_SHADER).replace("stone = INSTANCE_CUSTOM.rgb;", "stone = stone_color;").replace("mossy = INSTANCE_CUSTOM.a;", "mossy = mossiness;").replace("uniform vec3 moss_color", "uniform vec3 stone_color = vec3(0.30, 0.29, 0.27);
uniform float mossiness = 0.65;
uniform vec3 moss_color")
		_boulder_rock = ShaderMaterial.new()
		_boulder_rock.shader = shader
		_boulder_rock.set_shader_parameter("fade_start", 100000.0)
		_boulder_rock.set_shader_parameter("fade_end", 100001.0)

	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	body.add_child(shape)
	var lump: MeshInstance3D = MeshInstance3D.new()
	lump.mesh = _boulder_mesh
	lump.material_override = _boulder_rock
	body.add_child(lump)
	body.position = row[3]
	body.rotation.y = deg_to_rad(float(extra.get("yaw", 0.0)))
	_root.add_child(body)
	var entry: Dictionary = {"node": body, "shape": shape, "lump": lump, "pos": row[3], "left": left, "total": maxi(int(extra.get("total", left)), 1), "radius": float(extra.get("radius", 0.5))}
	_boulders[id] = entry
	_size_boulder(entry)


# Scale to the radius still left (the cube root of the stones left), sunk a fifth into the ground like Art's scenery boulders.
func _size_boulder(entry: Dictionary) -> void:
	var box: AABB = _boulder_mesh.get_aabb()
	var radius: float = float(entry["radius"]) * pow(float(entry["left"]) / float(entry["total"]), 1.0 / 3.0)
	var unit: float = maxf(maxf(box.size.x, box.size.z) * 0.5, 0.01)
	var scale: float = radius / unit
	entry["now"] = radius
	entry["lump"].scale = Vector3.ONE * scale
	entry["lump"].position = Vector3(0.0, -(box.position.y + box.size.y * 0.2) * scale, 0.0)
	entry["shape"].shape.radius = radius * 0.85
	entry["shape"].position = Vector3(0.0, radius * 0.5, 0.0)


# The boulder a strike at this point landed on (0 when none): within its radius and a little.
func boulder_near(point: Vector3) -> int:
	for id in _boulders:
		var entry: Dictionary = _boulders[id]
		var flat: float = Vector2(point.x - entry["pos"].x, point.z - entry["pos"].z).length()

		if flat <= float(entry.get("now", entry["radius"])) + 0.7 and absf(point.y - entry["pos"].y) < 2.5 + float(entry["radius"]):
			return id

	return 0


# Loose items roll a little when walked over (Dave 2026-10-23, keep-item-roll): a few times a second the loose singles within ROLL_TRIGGER_M of a
# moving player get a push away from them; each rolls on its own with friction, settles on the ground and turns as it goes. Drawing only:
# the server still knows the item at its spot (a roll never goes more than ROLL_MAX_M from it, inside pickup reach), so nothing is sent.
const ROLL_TRIGGER_M := 0.7
const ROLL_MAX_M := 0.8
const ROLL_FRICTION := 3.5
const ROLL_MIN_SPEED := 0.08
var _roll_last_msec: int = 0
var _roll_prev: Vector3 = Vector3.ZERO
var _roll_speed: float = 0.0
var _rolling: Dictionary = {}   # world id -> {"vel": Vector2, "off": Vector2}


func _roll_tick(delta: float, now: int) -> void:
	if not _player_position.is_valid() or _world.is_empty() and _rolling.is_empty():
		return

	if now - _roll_last_msec >= 100:
		var here: Vector3 = _player_position.call()
		var dt: float = float(now - _roll_last_msec) / 1000.0
		_roll_speed = Vector2(here.x - _roll_prev.x, here.z - _roll_prev.z).length() / maxf(dt, 0.001) if _roll_last_msec > 0 and dt < 1.0 else 0.0
		_roll_prev = here
		_roll_last_msec = now

		if _roll_speed > 0.5 and _roll_speed < 15.0:
			for id in _world:
				var entry: Dictionary = _world[id]

				if int(entry["state"]) != 0 or entry.get("pile", false) or int(entry["count"]) > 5 or _rolling.has(id):
					continue

				var apart: Vector2 = Vector2(entry["pos"].x - here.x, entry["pos"].z - here.z)

				if apart.length() < ROLL_TRIGGER_M:
					var away: Vector2 = apart.normalized() if apart.length() > 0.01 else Vector2(1.0, 0.0)
					_rolling[id] = {"vel": away * (0.9 + 0.35 * _roll_speed), "off": Vector2.ZERO}

	for id in _rolling.keys():
		var roll: Dictionary = _rolling[id]
		var entry: Dictionary = _world.get(id, {})

		if entry.is_empty():
			_rolling.erase(id)
			continue

		var node: Node3D = entry["node"]
		var vel: Vector2 = roll["vel"]
		var off: Vector2 = roll["off"] + vel * delta
		var travelled: float = off.length()

		if travelled > ROLL_MAX_M:
			off = off * (ROLL_MAX_M / travelled)
			vel = Vector2.ZERO

		vel *= exp(-ROLL_FRICTION * delta)
		roll["vel"] = vel
		roll["off"] = off
		var spot: Vector3 = entry["pos"] + Vector3(off.x, 0.0, off.y)
		var ground: float = float(_ground_below.call(spot)) if _ground_below.is_valid() else NAN
		node.position = Vector3(spot.x, (ground if not is_nan(ground) else entry["pos"].y) + 0.12, spot.z)

		if vel.length() > 0.01:
			node.rotate(Vector3(vel.y, 0.0, -vel.x).normalized(), vel.length() * delta / 0.12)

		if vel.length() < ROLL_MIN_SPEED:
			_rolling.erase(id)


func _forget(id: int) -> void:
	_rolling.erase(id)
	_unsnapped.erase(id)

	if _boulders.has(id):
		_boulders[id]["node"].queue_free()
		_boulders.erase(id)
		return

	if not _world.has(id):
		return

	var entry: Dictionary = _world[id]

	if int(entry.get("roof", -1)) >= 0 and cover_index != null:
		cover_index.remove_roof(int(entry["roof"]))

	entry["node"].queue_free()
	_world.erase(id)
	ladders.erase(id)


# The look of what is built lives in building_look.gd (Art direction); these keep the call sites and the "Light" child.
func _make_leanto() -> Node3D:
	return BuildingLook.leanto()


func _make_block() -> Node3D:
	return BuildingLook.block()


# A camp bench (placeholder look until Art draws it): a flat top on four legs, waist high, about 1.5 by 1 m.
# Add-ons (placeholder looks): a tool rack is two posts and a crossbar with pegs; a vice is a block with two jaws.
func _make_rack() -> Node3D:
	return BuildingLook.tool_rack()


func _make_vice() -> Node3D:
	return BuildingLook.vice()


# Admin mode (Dave 2026-10-23, on by default): the whole list is craftable free for an admin; the server decides, this only stops the list greying.
var admin_craft: bool = true    # Esc > Admin > Admin mode switch (on by default)


func _free_craft() -> bool:
	return admin_craft or not AdminScript.check_enabled()


func _can_craft(number: int) -> bool:
	return _free_craft() or recipes.can_make(number, inventory) or bool(_parts_plan(number)["ok"])


var _plan_cache: Dictionary = {}   # recipe number -> its auto-make plan, cleared on every refresh


# What the server would queue if you picked this recipe short of a part it can make (Dave 25 Oct): {"ok", "made": [[item, count]], "ambiguous", "msg"}.
func _parts_plan(number: int) -> Dictionary:
	if _plan_cache.has(number):
		return _plan_cache[number]

	var plan: Dictionary = {"ok": false, "steps": [], "made": [], "ambiguous": 0, "msg": ""}

	if not recipes.can_make(number, inventory):
		var ctx: Dictionary = {
			"have": func(item: int) -> int: return inventory.count_fill(item),
			"station_ok": func(r: Dictionary) -> bool: return _station_ok(r),
			"free": false,
		}
		plan = CraftPlanner.plan(recipes, table, number, 1, ctx)

		if bool(plan["ok"]) and (plan["steps"] as Array).size() < 2:
			plan["ok"] = false

	_plan_cache[number] = plan
	return plan


func _station_ok(r: Dictionary) -> bool:
	return _free_craft() or str(r.get("station", "")) == "" or station_near(str(r["station"]), int(r.get("station_level", 1)))


func _station_label(r: Dictionary) -> String:
	for kind in _structure_kinds():
		if str(_structures_cfg[kind].get("station", "")) == str(r.get("station", "")):
			return table.name_of(table.number_of(str(_structures_cfg[kind].get("item", "")))).to_lower()

	for kind in _structure_kinds():
		if _structures_cfg[kind].get("also", {}).has(str(r.get("station", ""))):
			return table.name_of(table.number_of(str(_structures_cfg[kind].get("item", "")))).to_lower()

	return str(r.get("station", "")).replace("_", " ")


func _structure_kinds() -> Array:
	_structure_by_state(-1)
	return _structures_cfg.keys()


func _make_bench() -> Node3D:
	return BuildingLook.camp_bench()


# The bigger stations (placeholder looks until Art draws them; medieval log and timber, stone and iron, nothing modern).
func _part(root: Node3D, size: Vector3, at: Vector3, color: Color, tilt: Vector3 = Vector3.ZERO) -> void:
	var piece: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	piece.mesh = box
	piece.material_override = material
	piece.position = at
	piece.rotation_degrees = tilt
	root.add_child(piece)




# Medium: a thick hewn top on two log trestles, a rack of pegs at the back and a wooden vice at one end, about 2 by 1 m.
func _make_log_bench() -> Node3D:
	return BuildingLook.log_bench()


# Large: a stone hearth with a hooded chimney, an anvil on a stump, a bellows of leather and wood, and a plank bench alongside.
func _make_forge() -> Node3D:
	var model: Node3D = _forge_glb("forge_basic")
	return model if model != null else BuildingLook.stone_forge()


# The Medium Forge (the old Masonry forge, id blacksmithy), drawn in building_look.gd; a model of Dave's in assets/stations wins.
func _make_smithy() -> Node3D:
	var model: Node3D = _forge_glb("forge_medium")
	return model if model != null else BuildingLook.masonry_forge()


# Large Forge (state 20) and Master Forge (state 21): Dave's models in assets/stations when present, else the Medium Forge scaled
# up as a stand-in until they arrive.
func _make_big_forge(state: int) -> Node3D:
	var file: String = "forge_large" if state == 20 else "forge_master"
	var model: Node3D = _forge_glb(file)

	if model != null:
		return model

	var stand_in: Node3D = BuildingLook.masonry_forge()
	stand_in.scale = Vector3.ONE * (1.2 if state == 20 else 1.45)
	return stand_in


var _forge_sizes: Dictionary = {}


# Dave's forge meshes (assets/stations/forge_basic, forge_medium, forge_large, forge_master .glb). They arrive Z up with the fire
# opening toward -Y and the middle of the base off the origin, so this stands them up (Y up, which leaves the opening toward +Z, the front
# of every building here: placed with the camera yaw it faces the player who put it down), puts the
# centre of the footprint at the pivot and the base on the ground, and takes the flame light and smoke from the Fire and Smoke empties
# in the file. Returns null when the file is not there yet.
func _forge_glb(file: String) -> Node3D:
	var path: String = "res://assets/stations/%s.glb" % file

	if not ResourceLoader.exists(path):
		return null

	var scene: Variant = load(path)

	if not (scene is PackedScene):
		return null

	var model: Node3D = (scene as PackedScene).instantiate() as Node3D
	var upright: Node3D = Node3D.new()
	upright.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	upright.add_child(model)
	var turned: Node3D = Node3D.new()
	turned.add_child(upright)
	var root: Node3D = Node3D.new()
	root.add_child(turned)
	var box: AABB = _bounds_in(model, root)
	var fit: float = _forge_scale(file)
	turned.scale = Vector3.ONE * fit
	turned.position = -Vector3(box.position.x + box.size.x * 0.5, box.position.y, box.position.z + box.size.z * 0.5) * fit
	box = AABB(box.position * fit, box.size * fit)
	var fire: Node3D = model.get_node_or_null("Fire") as Node3D
	var smoke: Node3D = model.get_node_or_null("Smoke") as Node3D
	var hook_fire: Variant = null
	var hook_smoke: Variant = null

	if fire != null:
		hook_fire = _local_to(fire, root)

	if smoke != null:
		hook_smoke = _local_to(smoke, root)

	var body: StaticBody3D = StaticBody3D.new()   # solid: you walk round a forge, not through it
	var shape: CollisionShape3D = CollisionShape3D.new()
	var solid: BoxShape3D = BoxShape3D.new()
	solid.size = Vector3(box.size.x, minf(box.size.y, 2.2), box.size.z)
	shape.shape = solid
	shape.position = Vector3(0.0, solid.size.y * 0.5, 0.0)
	body.add_child(shape)
	root.add_child(body)
	return BuildingLook.add_hooks(root, hook_fire, hook_smoke, clampf(fit, 0.3, 1.0))


# The uniform scale of a forge model as a share of the size Dave imported it at (data/stations/forge_sizes.json; 1 when missing).
func _forge_scale(file: String) -> float:
	if _forge_sizes.is_empty():
		var text: String = FileAccess.get_file_as_string("res://data/stations/forge_sizes.json")
		var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
		_forge_sizes = parsed if parsed is Dictionary else {"none": 0.0}

	var share: float = float(_forge_sizes.get(file, 0.0))
	return share if share > 0.0 else 1.0


# The box of every mesh under `node`, in the space of `space` (a Node3D above it), without needing the tree.
func _bounds_in(node: Node3D, space: Node3D) -> AABB:
	var found: Array = [null]
	_grow_bounds(node, space, found)
	return found[0] if found[0] != null else AABB()


func _grow_bounds(node: Node, space: Node3D, found: Array) -> void:
	if node is MeshInstance3D:
		var box: AABB = _chain_to(node as Node3D, space) * (node as MeshInstance3D).get_aabb()
		found[0] = box if found[0] == null else (found[0] as AABB).merge(box)

	for child in node.get_children():
		_grow_bounds(child, space, found)


func _chain_to(node: Node3D, space: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var cur: Node = node

	while cur != null and cur != space and cur is Node3D:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()

	return t


# Where a node sits in the space of an ancestor, without needing the tree.
func _local_to(node: Node3D, ancestor: Node3D) -> Vector3:
	return _chain_to(node, ancestor).origin


# Is a lit fire (any tier) within r metres of a point? Display only.
func _lit_fire_near(pos: Vector3, r: float) -> bool:
	for fire_id in _world:
		if _lit_state(int(_world[fire_id]["state"])) and pos.distance_to(_world[fire_id]["pos"]) <= r:
			return true

	return false


# Is a placed station of this kind within its reach? Display only (the server decides): greys recipes that need one.
func station_near(station: String, level: int = 1) -> bool:
	var here: Vector3 = _player_position.call() if _player_position.is_valid() else Vector3.ZERO

	if station == "campfire":   # a lit campfire (state 1) within reach, or a clay hearth or oven beside you ("also")
		for fire_id in _world:
			if _lit_state(int(_world[fire_id]["state"])) and here.distance_to(_world[fire_id]["pos"]) <= 4.5:
				return true

	for id in _world:
		var def: Dictionary = _structure_by_state(int(_world[id]["state"]))

		if def.is_empty() or here.distance_to(_world[id]["pos"]) > float(def.get("reach_m", 3.0)):
			continue

		if str(def.get("station", "")) == station and int(def.get("station_level", 1)) + _addons_near(id, station, float(def.get("addon_reach_m", 5.0))) >= level:
			if str(def.get("attach_to", "")) == "fire" and not _lit_fire_near(_world[id]["pos"], 0.3):
				continue   # the pot cooks only while the fire it hangs over is lit

			return true

		if int(def.get("also", {}).get(station, 0)) >= level:
			return true

	return false


func _addons_near(bench_id: int, station: String, reach: float) -> int:
	var kinds: Dictionary = {}

	for id in _world:
		var def: Dictionary = _structure_by_state(int(_world[id]["state"]))

		if not def.is_empty() and str(def.get("addon_of", "")) == station and _world[bench_id]["pos"].distance_to(_world[id]["pos"]) <= reach:
			kinds[int(_world[id]["state"])] = true

	return kinds.size()


func _structure_by_state(state: int) -> Dictionary:
	if _structures_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))
		_structures_cfg = parsed.get("structures", {}) if typeof(parsed) == TYPE_DICTIONARY else {"none": {}}

	for kind in _structures_cfg:
		if int(_structures_cfg[kind].get("state", -1)) == state:
			return _structures_cfg[kind]

	return {}


func _make_chest() -> Node3D:
	return BuildingLook.chest()


# Remains (protocol 34, placeholder look until Art draws it): a low dark body and its pack, greying to bone over the seven days.
# `age` is 0 fresh to 1 gone; the server sends it when the row is first seen or changes state.
# A dead animal lying on its side: a brown ellipsoid sized by species (rabbit 0.45 m).
func _make_carcass(species: String) -> Node3D:
	return CarcassLook.build(species)


func _make_remains(age: float) -> Node3D:
	return BuildingLook.remains(age)


# Only the nearest MAX_FIRE_LIGHTS lit fires keep their light on (cost cap at every quality).
# The model of a world state (structures.json "look", read through StructureLook): the same builders draw a placed thing and the placement ghost.
# `extra` is the row's extras (remains age, carcass species).
func _model_for_state(state: int, extra: Dictionary = {}) -> Node3D:
	var look: String = StructureLook.look_of(state)

	if LookTable.has_look(look):
		return LookTable.build(look)   # building pieces: one table in look_table.gd

	match look:
		"campfire":
			return _make_fire(false, state == 9)
		"lean_to":
			return _make_leanto()
		"chest":
			return _make_chest()
		"remains":
			return _make_remains(float(extra.get("age", 0.0)))
		"workbench":
			return _make_bench()
		"tool_rack":
			return _make_rack()
		"vice":
			return _make_vice()
		"log_workbench":
			return _make_log_bench()
		"stone_forge":
			return _make_forge()
		"blacksmithy":
			return _make_smithy()
		"big_forge":
			return _make_big_forge(state)
		"carcass":
			return _make_carcass(str(extra.get("sp", "")))

	return _make_block()   # the chopping block (and any name nobody drew yet) is a plain block


# The ghost's model: a lit campfire is shown cold.
func ghost_model(state: int) -> Node3D:
	return _model_for_state(state)


func _make_fire(lit: bool, loaded: bool = false, tier: int = 2) -> Node3D:
	return BuildingLook.fire(lit, loaded, tier)


# Lit fire states (cooking.json fire_tiers): 1 campfire, 40 survival fire, 41 bonfire.
# World-item states 3 (a felled trunk) and 4 (its stump) are drawn by _make_felled; every other state is a fire, a structure, a boulder or a loose item.
static func is_felled_state(state: int) -> bool:
	return state == 3 or state == 4


static func _lit_state(state: int) -> bool:
	return state == 1 or state == 40 or state == 41


static func _fire_tier(state: int) -> int:
	return 1 if state == 40 else (3 if state == 41 else 2)


# Loose items on the ground (Dave 2026-10-20: a stick must not look like a green box). One shared mesh per item
# kind; each lying item is turned and scaled a little by its world id (_dress_item), so no per-frame cost.
func _mesh_for(number: int) -> Mesh:
	if not _meshes.has(number):
		var id: String = table.id_of(number)

		if id == "chopping_block" or id == "chopping_block_kit":
			_meshes[number] = BuildingLook.block_mesh()      # the heavy block you carry is the placed model, nothing else
			return _meshes[number]

		var basic: Mesh = BasicLook.mesh_for(id)      # stage-one look from data/items/looks.json (src/client/basic_look.gd)

		if basic != null:
			_meshes[number] = basic
			return basic

		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.roughness = 1.0
		var mesh: Mesh

		if id == "stick" or id == "plant_fibre" or id == "firewood" or id == "log" or id == "driftwood" or id.begins_with("log_"):
			var dims: Array = {"driftwood": [0.9, 0.06, 0.05, 0.01], "stick": [0.6, 0.02, 0.011, 0.07], "plant_fibre": [0.3, 0.012, 0.006, 0.05], "firewood": [0.4, 0.05, 0.045, 0.01], "log": [1.0, 0.13, 0.11, 0.02]}.get(id, [2.5, 0.28, 0.22, 0.02])   # a species log is the full-size 2.5 m length
			material.albedo_color = {"stick": Color(0.38, 0.27, 0.17), "plant_fibre": Color(0.72, 0.68, 0.45), "firewood": Color(0.5, 0.36, 0.22), "driftwood": Color(0.62, 0.58, 0.5), "log": Color(0.33, 0.24, 0.16)}.get(id, LogLookScript.color_of(id))
			mesh = _branch_mesh(float(dims[0]), float(dims[1]), float(dims[2]), float(dims[3]))
		elif id == "stone":
			mesh = RockLook.mesh()      # an irregular faceted lump with its own vertex colours (src/client/rock_look.gd)
			material.vertex_color_use_as_albedo = true
			material.albedo_color = Color.WHITE
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

	if BasicLook.has_look(id):
		node.scale = Vector3.ONE * BASIC_DROP_SCALE      # big enough to find in the tall grass (the natural stones and sticks are 3 times)
		node.position.y += 0.04
		return

	if id == "stick" or id == "plant_fibre" or id == "firewood" or id == "log" or id == "driftwood":
		node.scale = Vector3(rng.randf_range(0.7, 1.3), 1.0, 1.0)
		node.position.y -= 0.08 if id != "log" and not id.begins_with("log_") else 0.0
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
const STICK_SIZE_SHARE := 0.75   # Dave 2026-10-21: sticks about 75 percent of that, lying on the ground
const STICK_SCALE := Vector2(2.0, 2.7) * PICKUP_SIZE_MULT * STICK_SIZE_SHARE
const STICK_TINT := Color(0.42, 0.29, 0.17)   # bark brown, multiplied into the mesh colours
const STONE_LIFT_M := 0.05 * PICKUP_SIZE_MULT
const PICKUP_BRIGHT := 0.9   # was 1.3 while the vertex colours were not used (flat white); with them on, 1.3 drew chalk-white stones in full sun
const PICKUP_GLOW := Color(0.02, 0.02, 0.02)
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
							# The glb material does not use the mesh's vertex colours on its own, so every stone drew as flat white (with the glow below): the "white sphere" in the rig
							# pictures. Vertex colours are switched on (Kathleen, 2026-10-30), which is what the tint and the brightness here were meant to multiply into.
							lit.vertex_color_use_as_albedo = true
							var bright: float = 1.05 if group == "stick" else (1.0 if group == "driftwood" else PICKUP_BRIGHT)   # the mesh colours are already stone grey, bark brown and bleached wood
							lit.albedo_color = Color(bright, bright, bright)
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
	@warning_ignore("integer_division")
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
		node.rotation = Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(0.0, TAU), rng.randf_range(-0.04, 0.04))
		node.position.y -= height * node.scale.y * rng.randf_range(0.1, 0.35)   # seated in the ground like the stones
		node.visibility_range_end = STICK_VIEW_M
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# The crafting and inventory screen, laid out like Ark's (Dave, 2026-10-20): recipes on the left,
# the inventory on the right, one search box filtering both. Recipes you can make now are lit and
# sit at the top; the rest are greyed out below, each group alphabetical. About 3/4 of the screen,
# with text sized for a 55 inch 4K TV at 1080p: sizes scale with the window height (1080 = 1.0).
const BODY_PX := 30
const TITLE_PX := 40

var _search: LineEdit
var _recipe_search: LineEdit             # the search box at the top of the Make list: filters recipes by name as you type
var _recipe_category: String = ""        # "" = All
var _category_buttons: Dictionary = {}   # category name -> its tab button
var _recipe_list: VBoxContainer
var _detail: VBoxContainer
var _selected_recipe: int = 0
var _hover_recipe: int = 0                 # the recipe under the mouse in the crafting list, 0 when none (E crafts it)
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

	for spec in [["Health", Color(0.85, 0.2, 0.2)], ["Exertion", Color(0.95, 0.8, 0.25)], ["Energy", Color(0.6, 0.45, 0.9)], ["Warmth", Color(0.45, 0.8, 0.95)], ["Food", Color(0.9, 0.55, 0.2)], ["Water", Color(0.3, 0.6, 0.95)]]:
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

	_sick_label = Label.new()
	_sick_label.add_theme_font_size_override("font_size", _px(BODY_PX - 6))
	_sick_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.3))
	row.add_child(_sick_label)
	_update_panel_bars()
	return row


# The character died (protocol 34): a message and a fade out and in over death.json respawn_delay_s. The terrain client moves the body.
func _on_died(cause: String, _spawn: Vector3) -> void:
	if cause != "cave-in":   # the cave-in has its own long sequence (cavein_death.gd)
		_death_msec = Time.get_ticks_msec()

	show_notice("You died: %s" % cause)


func _on_skills(attributes: PackedInt32Array, rows: Array) -> void:
	strength = attributes[0] if attributes.size() > 0 else 0
	memory = attributes[1] if attributes.size() > 1 else 0
	skill_rows = rows
	_update_trail_mult()

	if _character != null:
		_character.refresh()


# The inner voice (protocol 38): the text as a subtitle for a few seconds; Sounds plays the line's recording when there is one.
func _on_thought(line_id: String, text: String, kind: String) -> void:
	if not inner_settings.allows(kind):
		return      # the player switched this kind of line off (the symptom message itself is not a line of the voice)

	_thought_label.text = "(%s)" % text
	_thought_until_msec = Time.get_ticks_msec() + 5500

	if thought_event.is_valid():
		thought_event.call(line_id, kind)


# Tracking (Dave 2026-10-21): how many times longer trampled grass trails stay down on THIS client (1.0 untrained, 6.0 at 100).
# Mandy's trail drawing multiplies its trail lifetime by trail_mult (base 5 real minutes, data/items/tracking.json). It uses the
# effective (working) level, so a rusty tracker sees less. Set whenever the skills message arrives.
func _update_trail_mult() -> void:
	if _tracking_index < 0:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/skills.json"))
		_tracking_index = (parsed.get("skills", {}) as Dictionary).keys().find("tracking") if typeof(parsed) == TYPE_DICTIONARY else -1

	trail_mult = 1.0

	for row in skill_rows:
		if int(row[0]) == _tracking_index:
			trail_mult = TrackingScript.multiplier(int(row[6]) if row.size() > 6 else int(row[1]))


# Hours of sickness for eating this raw (cooking.json raw_sick), 0 when it is safe.
func _raw_sick_hours(item_id: String) -> float:
	if _cooking_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/cooking.json"))
		_cooking_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"raw_sick": {}}

	var cfg: Dictionary = _cooking_cfg.get("raw_sick", {})

	if cfg.get("by_id", {}).has(item_id):
		return float(cfg["by_id"][item_id])

	for suffix in cfg.get("by_suffix", {}):
		if item_id.ends_with(str(suffix)):
			return float(cfg["by_suffix"][suffix])

	return 0.0


# What lies on the ground within r metres of a point, named plainly (inspection mode): remains, kits, structures, loose items.
func world_item_name_near(point: Vector3, r: float) -> String:
	var best: float = r
	var label: String = ""

	for id in _world:
		var d: float = point.distance_to(_world[id]["pos"])

		if d < best and int(_world[id]["number"]) > 0:
			best = d
			var number: int = int(_world[id]["number"])
			label = "Your remains" if int(_world[id]["state"]) >= 11 else _item_label(number)

	return label


func _on_worn(numbers: PackedInt32Array) -> void:
	worn = numbers

	if _weight_label != null:
		_refresh_weight()

	if _character != null:
		_character.refresh()


func clothing_slots() -> Array:
	if clothing_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/clothing.json"))
		clothing_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"slots": []}

	return clothing_cfg.get("slots", [])


# The body weight the carry limit is worked out from: the real weight plus what a worn pack adds (the server does the same).
func carry_body_kg() -> float:
	var bonus: float = 0.0

	for number in worn:
		if number > 0:
			bonus += float(table.entry(table.id_of(number)).get("carry_bonus_kg", 0.0))

	return weight_kg + bonus / maxf(float(_carry_cfg.get("carry_kg_per_body_kg", 0.7)), 0.01)


func _on_remains_marks(rows: Array) -> void:
	remains_marks = []
	var now: int = Time.get_ticks_msec()

	for row in rows:
		remains_marks.append([row[0], int(row[1]), now])

	if _character != null:
		_character.refresh()


func _on_sick(hours: int) -> void:
	sick_hours = hours
	_update_panel_bars()

	if _character != null:
		_character.refresh()


func _on_warmth(percent: int) -> void:
	warmth = percent
	_update_panel_bars()

	if _character != null:
		_character.refresh()


func _on_energy(percent: int) -> void:
	energy = percent
	_update_panel_bars()

	if _character != null:
		_character.refresh()


func _update_panel_bars() -> void:
	if _panel_bars.is_empty() or not is_instance_valid(_panel_bars["Health"]):
		return

	var threshold: float = maxf(float(_exertion_cfg.get("faint_at", 1.4)), 0.1)
	_panel_bars["Health"].value = float(health)
	_panel_bars["Exertion"].value = clampf(strain / threshold, 0.0, 1.0) * 100.0
	_panel_bars["Energy"].value = float(energy)
	_panel_bars["Warmth"].value = float(warmth)

	if _sick_label != null and is_instance_valid(_sick_label):
		_sick_label.text = ("Health: ill, about %d h left" % sick_hours) if sick_hours > 0 else ""
	_panel_bars["Food"].value = float(hunger)
	_panel_bars["Water"].value = float(thirst)


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
	_panel.anchor_top = 0.04
	_panel.anchor_bottom = 0.89   # leaves the whole hotbar visible underneath (Dave)
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
		size_button.pressed.connect(func():
			if text_step.is_valid():
				text_step.call(step[0]))
		top.add_child(size_button)

	_search = LineEdit.new()
	_search.placeholder_text = "Search items"
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
	left.add_child(_build_recipe_filter())
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
	_purse_label = make_coin_label(_px(BODY_PX - 6))
	right.add_child(_purse_label)
	_refresh_purse()
	_carry_bar = ProgressBar.new()
	_carry_bar.show_percentage = false
	_carry_bar.max_value = 100.0
	_carry_bar.custom_minimum_size = Vector2(0.0, _px(22))
	_carry_bar.add_theme_stylebox_override("fill", StyleBoxFlat.new())
	var carry_empty: StyleBoxFlat = StyleBoxFlat.new()
	carry_empty.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	_carry_bar.add_theme_stylebox_override("background", carry_empty)
	right.add_child(_carry_bar)
	_carried_slot = Label.new()
	_style(_carried_slot, BODY_PX - 6)
	_carried_slot.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	right.add_child(_carried_slot)
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
# An NPC talk (src/client/dialogue_view.gd) counts as a screen: it frees the mouse, stops walking, and Esc closes it.
var dialogue_open: bool = false
var dialogue_key: Callable = Callable()     # (event) -> bool: digit keys pick a choice
var dialogue_close: Callable = Callable()


func screen_open() -> bool:
	return open or chest_mode or character_open() or dialogue_open


# Quick keys while the screen is open: E use (eat or apply), D drop (Shift+D one), S split, R repair, T transfer
# between the pack and an open container. They act on the slot under the mouse, else the selected slot. True when the key
# was one of them (the caller then skips its other bindings). Outside this screen E is the interact key.
func quick_key(event: InputEventKey) -> bool:
	if dialogue_open and dialogue_key.is_valid():
		return bool(dialogue_key.call(event))

	var slot: int = _hover if _hover >= 0 else _selected

	match event.keycode:
		KEY_E:
			if hotbar_hover >= 0 and _hover < 0:
				hotbar_to_pack(hotbar_hover)
				return true

			if slot >= 0 and not chest_mode:
				eat_slot(slot)

			return true
		KEY_D:
			if slot < 0 and shoulder_id != "" and not chest_mode:
				lay_down_shoulder()
				return true

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
	if not _can_craft(number):
		return

	for item in recipes.recipe(number).get("identify", []):
		if knowledge != null and not knowledge.is_known("i%d" % item):
			_on_notice("You are not sure what %s really is. Hover it in inspection mode (/) before you use it." % table.name_of(item).to_lower())
			return

	net.inventory_action.rpc_id(1, Net.ACT_CRAFT_QUEUE, number, 0, count, Vector3.ZERO)


func _on_reject(reason: int) -> void:
	auto_pickup.note_refused(_player_position.call(), inventory.counts.hash())
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
	var item_name: String = table.name_of(number)
	var entry: Dictionary = table.entry(table.id_of(number))

	if knowledge != null and is_inspecting.is_valid() and bool(is_inspecting.call()) and not entry.get("look_alikes", []).is_empty():
		return knowledge.reveal("i%d" % number, item_name, int(entry.get("familiarity", 100)), "horticulture", entry.get("look_alikes", []))

	return item_name


func _freshness_word(f: float) -> String:
	return "fresh" if f > 0.6 else ("going off" if f > 0.25 else "nearly rotten")


func _tooltip(number: int, count: int, fill_ml: int = 0) -> String:
	if number == 0:
		return ""

	var entry: Dictionary = table.entry(table.id_of(number))
	var item_name: String = _item_label(number)

	var text: String = "%s x%d\n%s, stacks to %d" % [item_name, count, str(entry.get("kind", "item")), table.stack_of(number)]
	text += "\n%s" % str(entry.get("description", "A plant material you gathered."))

	if int(entry.get("capacity_ml", 0)) > 0:
		text += "\nHolds %s of %s. Use (E) drinks from it; at the water, E fills it." % [_litres(fill_ml), _litres(int(entry["capacity_ml"]))]

	var kcal: int = VitalsRules.food_value(table.id_of(number), _vitals_cfg)
	var heal: int = VitalsRules.heal_value(table.id_of(number), _vitals_cfg)

	if not _carry_cfg.is_empty():
		var each_kg: float = CarryRules.weight_of(table.id_of(number), _carry_cfg)
		text += "\n%s each" % (("%.0f g" % (each_kg * 1000.0)) if each_kg < 0.1 else ("%.2f kg" % each_kg))

	if str(entry.get("slot", "")) != "":
		text += "\nWorn on the %s. Use (E) puts it on." % str(entry["slot"])

		if float(entry.get("warmth", 0.0)) > 0.0:
			text += " Keeps %d%% of your body heat in." % int(round(float(entry["warmth"]) * 100.0))

		if float(entry.get("carry_bonus_kg", 0.0)) > 0.0:
			text += " Lets you carry %.0f kg more." % float(entry["carry_bonus_kg"])

	if _raw_sick_hours(table.id_of(number)) > 0.0:
		text += "\nEaten raw it ruins your health for a day. Cook it at a fire first."

	if kcal > 0:
		text += "\n%d kcal  (right click when held, or Eat / use)" % kcal

	if heal > 0:
		text += "\nrestores %d health  (right click when held, or Eat / use)" % heal

	var cure: Dictionary = VitalsRules.medicine(table.id_of(number), _vitals_cfg)

	if not cure.is_empty():
		text += "\nTakes away %d hours of ill health  (right click when held, or Eat / use)" % int(cure.get("cure_h", 0))

	if table.shelf_units(number) > 0:
		var f: float = table.freshness(number, fill_ml)
		text += "\n%s (%d%% fresh). Spoils; keep it in a chest, in the cold or dry it." % [_freshness_word(f).capitalize(), int(f * 100.0)]

	if int(entry.get("value", 0)) > 0 and str(entry.get("kind", "")) != "coin":
		text += "\nWorth about %s" % coin_text(int(entry["value"]) * count) + (" (%s each)" % coin_text(int(entry["value"])) if count > 1 else "")

	text += "\nKeys: Split (S), Drop (D), Use (E)"

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
	auto_pickup.note_drop(inventory.numbers[_selected], at, Time.get_ticks_msec())   # auto pickup leaves it alone for 15 s
	net.inventory_action.rpc_id(1, Net.ACT_DROP, _selected, 0, inventory.counts[_selected] if whole else 1, at)
	_selected = -1


# The search box and the category tabs at the top of the Make list (Dave 25 Oct). Search matches the recipe's name; a tab shows one category.
func _build_recipe_filter() -> Control:
	var holder: VBoxContainer = VBoxContainer.new()
	_recipe_search = LineEdit.new()
	_recipe_search.placeholder_text = "Search what you can make"
	_recipe_search.clear_button_enabled = true
	_recipe_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(_recipe_search, BODY_PX)
	_recipe_search.text_changed.connect(func(_text): _refresh())
	holder.add_child(_recipe_search)
	var tabs: HFlowContainer = HFlowContainer.new()
	holder.add_child(tabs)
	_category_buttons.clear()

	for label in [""] + RecipeFilter.CATEGORIES:
		var tab: Button = Button.new()
		tab.text = "All" if label == "" else str(label)
		tab.toggle_mode = true
		_style(tab, BODY_PX - 6)
		tab.pressed.connect(func():
			_recipe_category = str(label)
			_refresh())
		tabs.add_child(tab)
		_category_buttons[str(label)] = tab

	return holder


func _recipe_shown(r: Dictionary) -> bool:
	return RecipeFilter.shown(r, _recipe_category, _recipe_search.text if _recipe_search != null else "")


func _matches(text: String, filter: String) -> bool:
	return filter == "" or text.to_lower().contains(filter)



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
	_plan_cache.clear()
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
		var is_worn: bool = number != 0 and int(table.entry(table.id_of(number)).get("durability", 0)) > 0 and inventory.wear[i] > 0
		var perishable: bool = number != 0 and table.shelf_units(number) > 0
		bar.visible = is_worn or perishable

		if perishable:
			var f: float = table.freshness(number, inventory.wear[i])
			bar.anchor_right = maxf(f, 0.04)
			bar.color = Color(0.85, 0.2, 0.15) if f <= 0.25 else (Color(0.9, 0.7, 0.2) if f <= 0.5 else Color(0.35, 0.8, 0.3))
			bar.anchor_left = 0.0
			bar.offset_right = -_px(4)
			button.text += "   %s" % _freshness_word(f)
		elif is_worn:
			var c: float = condition(i)
			bar.anchor_right = maxf(c, 0.04)
			bar.color = Color(0.85, 0.2, 0.15) if c <= 0.0 else Color(1.0 - c, 0.2 + 0.7 * c, 0.15)
			bar.anchor_left = 0.0
			bar.offset_right = -_px(4)
			button.text += "   BROKEN" if is_broken(i) else "   %d%%" % int(c * 100.0)
		button.modulate = Color(1.0, 0.9, 0.5) if i == _selected else Color.WHITE
		button.visible = filter == "" or (number != 0 and _matches(table.name_of(number), filter))
		button.tooltip_text = _tooltip(number, inventory.counts[i], inventory.wear[i])

		if number != 0 and container_cap(i) > 0:
			button.text += "   %s" % _litres(inventory.wear[i])

	# Recipes: makeable first, then the rest, each alphabetical.
	_hover_recipe = 0

	for child in _recipe_list.get_children():
		child.queue_free()

	var can: Array = []
	var cannot: Array = []

	for tab_name in _category_buttons:
		(_category_buttons[tab_name] as Button).button_pressed = str(tab_name) == _recipe_category

	for number in recipes.numbers():
		var r: Dictionary = recipes.recipe(number)

		if (not r["known"] and not _free_craft()) or not _recipe_shown(r):
			continue

		(can if _can_craft(number) and _station_ok(r) else cannot).append(r)

	# One alphabetical list, case-insensitive by display name (Dave 24 Oct); the green and grey colours say what can be made now.
	var by_name: Callable = func(a, b): return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0
	var shown_recipes: Array = can + cannot
	shown_recipes.sort_custom(by_name)
	can.sort_custom(by_name)
	cannot.sort_custom(by_name)

	if _selected_recipe == 0 or recipes.recipe(_selected_recipe).is_empty():
		_selected_recipe = can[0]["number"] if not can.is_empty() else (cannot[0]["number"] if not cannot.is_empty() else 0)

	for r in shown_recipes:
		var makeable: bool = _can_craft(r["number"]) and _station_ok(r)
		var entry: Button = Button.new()
		entry.text = str(r["name"]) + (("   (needs %s)" % _station_label(r)) if not _station_ok(r) else "")
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.custom_minimum_size = Vector2(0.0, _px(64))
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.modulate = Color(0.55, 1.0, 0.55) if makeable else Color(0.55, 0.55, 0.55, 0.6)
		entry.flat = r["number"] != _selected_recipe
		_style(entry, BODY_PX)
		entry.pressed.connect(_select_recipe.bind(r["number"]))
		entry.mouse_entered.connect(func(): _hover_recipe = int(r["number"]))
		entry.mouse_exited.connect(func(): _hover_recipe = 0 if _hover_recipe == int(r["number"]) else _hover_recipe)
		_recipe_list.add_child(entry)

	_add_admin_builds()
	_refresh_detail()


# The Admin heading at the bottom of the list (Dave 2026-10-22): the building pieces to test plus the other placeables, free and unlocked. Click one to get it; put it in a quick key
# and it is the usual placement blueprint (left click places one). Shown while the admin check is off (local play) .
func _add_admin_builds() -> void:
	if AdminScript.check_enabled():
		return

	var head: Label = Label.new()
	head.text = "Admin"
	_style(head, BODY_PX)
	head.modulate = Color(1.0, 0.8, 0.4)
	_recipe_list.add_child(head)

	var admin_ids: Array = ["foundation_section_kit", "wall_section_kit", "doorway_section_kit", "window_section_kit", "floor_section_kit", "roof_section_kit", "ladder_kit", "campfire_kit", "lean_to_kit", "chest_kit", "workbench_kit", "rough_bed_kit", "thatch_wall_kit", "campfire_pot_kit", "clay_hearth_kit", "oven_kit"]
	admin_ids.sort_custom(func(a, b): return table.name_of(table.number_of(str(a))).naturalnocasecmp_to(table.name_of(table.number_of(str(b)))) < 0)

	for id in admin_ids:
		var number: int = table.number_of(id)

		if number == 0:
			continue

		var entry: Button = Button.new()
		entry.text = table.name_of(number)
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.custom_minimum_size = Vector2(0.0, _px(64))
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.modulate = Color(1.0, 0.85, 0.5)
		_style(entry, BODY_PX)
		entry.pressed.connect(func(): net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, number, 0, 1, Vector3.ZERO))
		_recipe_list.add_child(entry)


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

	if str(r.get("station", "")) != "":
		var where: Label = Label.new()
		where.text = ("Made at a %s (you are near one)" if _station_ok(r) else "Needs a %s within reach") % _station_label(r)
		where.modulate = Color(0.55, 1.0, 0.55) if _station_ok(r) else Color(1.0, 0.8, 0.4)
		_style(where, BODY_PX)
		_detail.add_child(where)

	var parts: Dictionary = _parts_plan(_selected_recipe)

	if bool(parts["ok"]):
		var made: Array = (parts["made"] as Array).map(func(m): return "%d %s" % [m[1], table.name_of(m[0]).to_lower()])
		var auto_line: Label = Label.new()
		auto_line.text = "Makes %s first" % " and ".join(made)
		auto_line.modulate = Color(0.55, 1.0, 0.55)
		_style(auto_line, BODY_PX)
		_detail.add_child(auto_line)
	elif int(parts["ambiguous"]) != 0:
		var choose_line: Label = Label.new()
		choose_line.text = str(parts["msg"])
		choose_line.modulate = Color(1.0, 0.8, 0.4)
		_style(choose_line, BODY_PX)
		_detail.add_child(choose_line)

	for need in r["needs"] + r["keeps"]:
		var kept: bool = r["keeps"].has(need)
		var have: int = inventory.count_of(need[0]) if kept else inventory.count_fill(need[0])
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
	make.disabled = not (_can_craft(_selected_recipe) and _station_ok(r))
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
	_recipe_search.text = "stone"
	_refresh()
	var shown: int = 0

	for child in _recipe_list.get_children():
		if not child.is_queued_for_deletion():
			shown += 1

	print("Items test: panel open, recipes shown for 'stone' %d, selected %d" % [shown, _selected_recipe])
	_recipe_search.text = ""
	_refresh()
	toggle()
	print("Items test: crafted, twine %d, stone axe %d, fibre %d" % [inventory.count_of(table.number_of("twine")), inventory.count_of(table.number_of("stone_axe")), inventory.count_of(table.number_of("plant_fibre"))])


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

	# Ground can take a while to load, so the scripted walk starts late: time the 25 s from the first steps.
	var spawn_pos: Vector3 = client.body.global_position
	waited = 0.0

	while Vector2(client.body.global_position.x - spawn_pos.x, client.body.global_position.z - spawn_pos.z).length() < 40.0 and waited < 90.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5

	var start_strain: float = strain
	var start_pos: Vector3 = client.body.global_position
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
	await get_tree().create_timer(14.0).timeout
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
func run_quickkey_test(_client) -> void:
	var stone: int = table.number_of("stone")
	var roast: int = table.number_of("roast_forage")
	await get_tree().create_timer(6.0).timeout

	# A slow join (cold server) drops a give sent too early: ask again, but only every 30 s and then wait for the pack to catch up. (Asking every 3 s gave the stones
	# again and again on a busy PC, where the pack arrives late: 63 stones instead of 6 and a failed check, 31 Oct.)
	for attempt in range(30):
		if attempt % 10 == 0:
			net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, stone, 0, 6, Vector3.ZERO)
			net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, roast, 0, 2, Vector3.ZERO)

		await get_tree().create_timer(3.0).timeout

		if inventory.count_of(stone) > 0 and inventory.count_of(roast) > 0:
			break

	toggle()
	var slot: int = inventory.numbers.find(stone)
	var before: int = inventory.count_of(stone)
	_hover = slot

	var press: Callable = func(code: int, shift: bool = false) -> bool:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code as Key
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
	_finish_early(client)


# Job 82: every control in the inventory window, read at the current text scale: the smallest font in use, the labels a
# player sees (buttons, sort options, hints) and the key letters on the action buttons. Printed as "Audit:" lines.
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
		var still: bool = true

		# A cold server answers late (its item step can stall for seconds): wait up to 8 s for the plant to leave the flora.
		for wait in range(16):
			await get_tree().create_timer(0.5).timeout
			var held_now: Dictionary = client.flora._chunks.get(spot[3], {}).get("items", {})
			still = held_now.has("ids") and held_now["ids"].find(spot[2]) >= 0

			if not still:
				break

		print("Plant test: %s %s" % [client.harvest._flora_by_id.get(int(spot[2]) >> 16, {}).get("name", "?"), "STILL THERE" if still else "gone"])
		gone += 0 if still else 1

	print("Plant test: tried %d, gone %d, still standing %d, skipped (nothing pickable) %d" % [tried, gone, tried - gone, skipped])


# Headless check (--leanto): place a lean-to ahead of the player and look for its row and its roof.
func run_leanto_test(_client) -> void:
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


# Headless check (--shoot): get a bow and arrows, draw fully and loose one arrow along the view, then say what the pack and the ground show.
# Prints SHOOT TEST lines; the last one is PASS or FAILED. No key presses, no animals needed (a hit is checked by test_bow on the server).
func run_shoot_test(client) -> void:
	await get_tree().create_timer(6.0).timeout
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("wooden_bow"), 0, 1, Vector3.ZERO)
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("stone_arrow"), 0, 3, Vector3.ZERO)

	for n in 30:   # a cold join gets its pack late: poll up to 15 s
		await get_tree().create_timer(0.5).timeout

		if inventory.numbers.has(table.number_of("wooden_bow")) and inventory.count_of(table.number_of("stone_arrow")) >= 3:
			break

		if n == 16 and not inventory.numbers.has(table.number_of("wooden_bow")) and inventory.count_of(table.number_of("stone_arrow")) == 0:   # still nothing after 8 s: the give was lost, send it once more
			net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("wooden_bow"), 0, 1, Vector3.ZERO)
			net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("stone_arrow"), 0, 3, Vector3.ZERO)

	var bow_slot: int = inventory.numbers.find(table.number_of("wooden_bow"))
	var arrows_before: int = inventory.count_of(table.number_of("stone_arrow"))
	print("SHOOT TEST: bow in slot %d, arrows %d" % [bow_slot, arrows_before])

	if bow_slot < 0 or arrows_before < 1:
		print("SHOOT TEST FAILED: the pack did not get the bow or the arrows")
		return

	var camera: Camera3D = client.camera
	var level: Vector3 = -camera.global_transform.basis.z
	var forward: Vector3 = (Vector3(level.x, 0.0, level.z).normalized() + Vector3(0.0, -0.12, 0.0)).normalized()   # a little downward: lands about 30 m off, inside the rows the server sends
	var started: int = Time.get_ticks_msec()
	await get_tree().create_timer(1.2).timeout      # a full draw
	net.inventory_action.rpc_id(1, Net.ACT_SHOOT, bow_slot, Time.get_ticks_msec() - started, 0, forward)
	await get_tree().create_timer(1.5).timeout
	var arrows_after: int = inventory.count_of(table.number_of("stone_arrow"))
	print("SHOOT TEST: arrows %d -> %d after the shot" % [arrows_before, arrows_after])
	await get_tree().create_timer(15.0).timeout     # flight, landing and the world-item update
	var landed: int = 0
	var nearest: float = -1.0
	var here: Vector3 = _player_position.call()

	for id in _world:
		if _world[id]["number"] == table.number_of("stone_arrow"):
			var d: float = (_world[id]["pos"] as Vector3).distance_to(here)
			landed += 1 if d < 90.0 else 0
			nearest = d if nearest < 0.0 or d < nearest else nearest

	print("SHOOT TEST: %d arrow(s) lying within 90 m after the flight, nearest %.1f m, %d world rows in all (an arrow can break, so 0 is possible; a stone arrow breaks about a fifth of the time)" % [landed, nearest, _world.size()])
	print("SHOOT TEST %s" % ("PASS" if arrows_after == arrows_before - 1 else "FAILED: the shot did not take an arrow"))


# Headless check (--place-foundation): a hand-made foundation (thatch floor) is given and placed 3 m ahead; says what the world shows there.
# Prints FOUNDATION TEST lines; the last one is PASS or FAILED.
func run_foundation_test(client) -> void:
	await get_tree().create_timer(6.0).timeout
	var kit: int = table.number_of("thatch_floor_kit")
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, kit, 0, 1, Vector3.ZERO)

	for n in 30:   # a cold join gets its pack late: poll up to 15 s
		await get_tree().create_timer(0.5).timeout

		if inventory.numbers.has(kit):
			break

		if n == 16:   # still nothing after 8 s: the give was lost, send it once more
			net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, kit, 0, 1, Vector3.ZERO)

	var slot: int = inventory.numbers.find(kit)

	if slot < 0:
		print("FOUNDATION TEST FAILED: no thatch floor kit in the pack")
		return

	var forward: Vector3 = -client.camera.global_transform.basis.z
	var here: Vector3 = _player_position.call()
	var ahead: Vector3 = here + Vector3(forward.x, 0.0, forward.z).normalized() * 3.0
	var spot: Vector3 = Vector3(ahead.x, float(_ground_below.call(ahead)), ahead.z)
	var rows_before: int = _world.size()
	net.inventory_action.rpc_id(1, Net.ACT_PLACE, slot, 0, 0, spot)
	await get_tree().create_timer(2.5).timeout
	var near: Array = []

	for id in _world:
		if (_world[id]["pos"] as Vector3).distance_to(spot) < 2.5:
			near.append(table.id_of(int(_world[id]["number"])))

	var kit_left: int = inventory.count_of(kit)
	print("FOUNDATION TEST: spot %s, kit left %d, world rows %d -> %d, near the spot: %s" % [str(spot), kit_left, rows_before, _world.size(), str(near)])
	print("FOUNDATION TEST %s" % ("PASS" if kit_left == 0 and not near.is_empty() else "FAILED: the floor was not placed"))


# Waits up to 15 s for `count` of an item to show in the pack after an admin give; the give is sent once more at 8 s when nothing came
# (a cold join on a busy server loses the first). Returns true when it arrived.
func _smoke_give(id: String, count: int) -> bool:
	var number: int = table.number_of(id)
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, number, 0, count, Vector3.ZERO)

	for n in 30:
		await get_tree().create_timer(0.5).timeout

		if inventory.count_of(number) >= count:
			return true

		if n == 16 and inventory.count_of(number) == 0:
			net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, number, 0, count, Vector3.ZERO)

	return false


# The nearest world row within `reach` of a spot with a given item id (and, when states is not empty, one of those states): its id, or -1.
func _smoke_row_near(spot: Vector3, item_id: String, reach: float, states: Array = []) -> int:
	var best: int = -1
	var best_d: float = reach

	for id in _world:
		if table.id_of(int(_world[id]["number"])) != item_id or (not states.is_empty() and not states.has(int(_world[id]["state"]))):
			continue

		var d: float = (_world[id]["pos"] as Vector3).distance_to(spot)

		if d <= best_d:
			best = id
			best_d = d

	return best


# Headless check (--cook): a campfire is laid and lit, raw meat is roasted on it and eaten. Prints COOK TEST lines; the last one is PASS or FAILED.
func run_cook_test(client) -> void:
	await get_tree().create_timer(6.0).timeout
	var meat: int = table.number_of("raw_meat")

	for pair in [["campfire_kit", 1], ["plant_fibre", 3], ["raw_meat", 2]]:
		if not await _smoke_give(str(pair[0]), int(pair[1])):
			print("COOK TEST FAILED: the pack did not get %s" % str(pair[0]))
			return

	var forward: Vector3 = -client.camera.global_transform.basis.z
	var here: Vector3 = _player_position.call()
	var ahead: Vector3 = here + Vector3(forward.x, 0.0, forward.z).normalized() * 2.0
	var spot: Vector3 = Vector3(ahead.x, float(_ground_below.call(ahead)), ahead.z)
	net.inventory_action.rpc_id(1, Net.ACT_PLACE, inventory.numbers.find(table.number_of("campfire_kit")), 0, 0, spot)
	await get_tree().create_timer(2.5).timeout
	var fire: int = -1

	for id in _world:
		if (_world[id]["pos"] as Vector3).distance_to(spot) < 2.0 and int(_world[id]["state"]) in [9, 1, 40, 41]:
			fire = id

	print("COOK TEST: fire row %d, state %s" % [fire, str(_world[fire]["state"]) if fire >= 0 else "none"])

	if fire < 0:
		print("COOK TEST FAILED: the fire was not laid")
		return

	for n in 3:   # a damp tinder can fail: up to three tries
		if _lit_state(int(_world[fire]["state"])):
			break

		net.inventory_action.rpc_id(1, Net.ACT_LIGHT, fire, 0, 0, Vector3.ZERO)
		await get_tree().create_timer(2.0).timeout

	if not _lit_state(int(_world[fire]["state"])):
		print("COOK TEST FAILED: the fire did not light (state %s)" % str(_world[fire]["state"]))
		return

	net.inventory_action.rpc_id(1, Net.ACT_COOK, fire, 0, 0, Vector3.ZERO)
	await get_tree().create_timer(2.5).timeout
	var roast: int = table.number_of("roast_meat")
	print("COOK TEST: raw meat %d -> %d, roast meat %d" % [2, inventory.count_of(meat), inventory.count_of(roast)])

	if inventory.count_of(roast) < 1:
		print("COOK TEST FAILED: nothing was roasted")
		return

	var fed_before: int = hunger
	eat_slot(inventory.numbers.find(roast))
	await get_tree().create_timer(2.0).timeout
	print("COOK TEST: hunger %d -> %d, roast meat left %d" % [fed_before, hunger, inventory.count_of(roast)])
	print("COOK TEST %s" % ("PASS" if inventory.count_of(roast) == 0 and hunger >= fed_before else "FAILED: the roast was not eaten"))


# Headless check (--sleep): a rough bed is set down beside the player, they lie on it, fall asleep for a few seconds and wake. Prints SLEEP TEST lines.
func run_sleep_test(client) -> void:
	await get_tree().create_timer(6.0).timeout

	if not await _smoke_give("rough_bed_kit", 1):
		print("SLEEP TEST FAILED: the pack did not get the rough bed")
		return

	var forward: Vector3 = -client.camera.global_transform.basis.z
	var here: Vector3 = _player_position.call()
	var ahead: Vector3 = here + Vector3(forward.x, 0.0, forward.z).normalized() * 0.9
	var spot: Vector3 = Vector3(ahead.x, float(_ground_below.call(ahead)), ahead.z)
	net.inventory_action.rpc_id(1, Net.ACT_PLACE, inventory.numbers.find(table.number_of("rough_bed_kit")), 0, 0, spot)
	await get_tree().create_timer(2.5).timeout
	var bed: int = _smoke_row_near(spot, "rough_bed", 2.0)
	print("SLEEP TEST: bed row %d (no roof here is fine: it then behaves as ground)" % bed)

	if bed < 0:
		print("SLEEP TEST FAILED: the bed was not set down")
		return

	var energy_before: int = energy
	request_stance(3)
	await get_tree().create_timer(1.5).timeout
	net.inventory_action.rpc_id(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	await get_tree().create_timer(6.0).timeout
	var slept: bool = asleep
	var stance_in_sleep: int = stance_confirmed
	net.inventory_action.rpc_id(1, Net.ACT_SLEEP, 0, 0, 0, Vector3.ZERO)
	await get_tree().create_timer(2.0).timeout
	request_stance(0)
	await get_tree().create_timer(1.5).timeout
	print("SLEEP TEST: lying %d, asleep %s, energy %d -> %d, after waking asleep %s" % [stance_in_sleep, str(slept), energy_before, energy, str(asleep)])
	print("SLEEP TEST %s" % ("PASS" if slept and not asleep and energy >= energy_before else "FAILED: sleep did not start, did not end, or energy fell"))


# Headless check (--snare): a snare is set down and left; passes when a carcass lies by it (server checks every 30 s; run the server with traps.json test_chance above 0,
# otherwise this only waits for a rabbit to walk by). Prints SNARE TEST lines.
func run_snare_test(client) -> void:
	await get_tree().create_timer(6.0).timeout

	if not await _smoke_give("snare", 1):
		print("SNARE TEST FAILED: the pack did not get a snare (are Sal's snare items in this build?)")
		return

	var forward: Vector3 = -client.camera.global_transform.basis.z
	var here: Vector3 = _player_position.call()
	var ahead: Vector3 = here + Vector3(forward.x, 0.0, forward.z).normalized() * 3.0
	var spot: Vector3 = Vector3(ahead.x, float(_ground_below.call(ahead)), ahead.z)
	net.inventory_action.rpc_id(1, Net.ACT_PLACE, inventory.numbers.find(table.number_of("snare")), 0, 0, spot)
	await get_tree().create_timer(2.5).timeout
	var snare: int = _smoke_row_near(spot, "snare_trap", 2.0)

	if snare < 0:
		snare = _smoke_row_near(spot, "snare", 2.0)

	print("SNARE TEST: snare row %d" % snare)

	if snare < 0:
		print("SNARE TEST FAILED: the snare was not set down")
		return

	for n in 40:   # up to 200 s: the server looks every 30 s
		await get_tree().create_timer(5.0).timeout

		if _smoke_row_near(spot, "carcass", 3.0) >= 0:
			print("SNARE TEST: a carcass lies by the snare after %d s" % ((n + 1) * 5))
			print("SNARE TEST PASS")
			return

	print("SNARE TEST FAILED: no catch in 200 s (the server needs traps.json test_chance above 0 for a sure run)")


# Headless check (--eat): eat a roast and apply a poultice.
func run_eat_test(client) -> void:
	await get_tree().create_timer(6.0).timeout
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("roast_forage"), 0, 2, Vector3.ZERO)
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("poultice"), 0, 1, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	print("Eat test: start hunger %d health %d weight %.1f; edible slot 0 %s" % [hunger, health, weight_kg, str(edible_slot(inventory.numbers.find(table.number_of("roast_forage"))))])
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

	# Crafting queue: three twine line up, the screen shows the entry, pressing it cancels and refunds.
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

	# Boulders: a server row draws a solid boulder that shrinks as stones come out, and a strike ray finds it.
	var spot: Vector3 = _player_position.call() + Vector3(6.0, 0.0, 0.0)
	_on_world_items([[987654, 0, 4000, spot, BOULDER_STATE, {"radius": 1.0, "yaw": 0.0, "total": 4000}]], PackedInt32Array())
	await get_tree().create_timer(0.5).timeout
	var full_radius: float = float(_boulders[987654]["now"]) if _boulders.has(987654) else -1.0
	_on_world_items([[987654, 0, 500, spot, BOULDER_STATE, {"radius": 1.0, "yaw": 0.0, "total": 4000}]], PackedInt32Array())
	var eighth_radius: float = float(_boulders[987654]["now"]) if _boulders.has(987654) else -1.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(spot + Vector3(0.0, 4.0, 0.0), spot + Vector3(0.0, -4.0, 0.0))
	var ray: Dictionary = _root.get_world_3d().direct_space_state.intersect_ray(query)
	print("Boulder test: radius %.2f, at an eighth of the stones %.2f, found by a strike %s, solid to a ray %s" % [full_radius, eighth_radius, str(boulder_near(spot) == 987654), str(not ray.is_empty() and ray["collider"] == _boulders[987654]["node"])])
	_on_world_items([], PackedInt32Array([987654]))
	print("Boulder test: gone when the server drops it %s" % str(not _boulders.has(987654)))

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
	await get_tree().create_timer(14.0).timeout
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

	_ask_open(id)

	for wait in 60:   # the cloud is slow: give the chest up to 6 s to open
		if chest_inv != null:
			break

		await get_tree().create_timer(0.1).timeout

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
	_finish_early(client)


# A headless check that has printed everything ends the run on the next frame instead of waiting out --frames, which
# takes minutes at the cloud's very low frame rate.
func _finish_early(client) -> void:
	if client.frames_left > 1:
		client.frames_left = 1


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
