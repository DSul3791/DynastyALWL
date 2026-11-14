extends Node
const PieceLook := preload("res://src/client/piece_look.gd")
const RecipeFilter := preload("res://src/client/recipe_filter.gd")
const CraftStock := preload("res://src/shared/craft_stock.gd")
const DisplaySettingsScript := preload("res://src/client/display_settings.gd")
const CraftPlanner := preload("res://src/shared/craft_planner.gd")
const Interact := preload("res://src/shared/interact_rules.gd")
const HeldItem := preload("res://src/client/held_item.gd")   # HeldItem.HOTBAR_SLOTS: the one hotbar size
const BowAim := preload("res://src/shared/bow_aim.gd")
const CharacterKeys := preload("res://src/client/character/character_keys.gd")
const CharacterStore := preload("res://src/client/character/character_store.gd")
const LogLookScript := preload("res://src/client/log_look.gd")
const LookTable := preload("res://src/client/look_table.gd")
const PileLookScript := preload("res://src/client/pile_look.gd")
const CarcassLook := preload("res://src/client/carcass_look.gd")
const RockLook := preload("res://src/client/rock_look.gd")
const BuildingLook := preload("res://src/client/building_look.gd")
const BasicLook := preload("res://src/client/basic_look.gd")
const PlacementRules := preload("res://src/shared/placement_rules.gd")   # DOOR_TAKEN_M: a doorway frame and its door share one spot

# The client side of items: the inventory panel (I), things lying on the ground (E picks up
# the nearest within reach) and the player key. The server owns all of it; this only shows
# what the server says and asks. Nothing is built until the panel is first opened, and the
# world items are a handful of small meshes within 100 m (the server caps them per chunk).

const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const RecipeTableScript := preload("res://src/shared/recipe_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")
const StationUse := preload("res://src/client/ui/inventory/station_use.gd")

const VitalsRules := preload("res://src/shared/vitals_rules.gd")
const SmithingRules := preload("res://src/shared/smithing_rules.gd")   # sharpness, Tempered and craftsmanship (catalog Phase 2c)
const CharacterScreenScript := preload("res://src/client/character_screen.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const BagRules := preload("res://src/shared/bag_rules.gd")
const CoverScript := preload("res://src/shared/cover.gd")
const KeyBindings := preload("res://src/client/key_bindings.gd")
const FarmRules := preload("res://src/shared/farm_rules.gd")   # what E does on a tilled bed or garden plot (WP-R1B)
const CropLook := preload("res://src/client/crop_look.gd")   # PLACEHOLDER stage looks of a bed's crop
const KEY_FILE := "user://player_key.txt"
const STUCK_ARROW_BACK_M := 0.22         # an arrow stuck in a tree: its middle this far (model metres) back from the hit along its flight, the point just in the bark
const BASIC_DROP_SCALE := 1.8           # loose items with a stage-one look (basic_look.gd) are drawn this much bigger so they show in the grass
const MAX_FIRE_LIGHTS := 3              # at High and Ultra; fewer below (max_lights)

var _flame_lights: Array = []           # the lit fire lights that are on (nearest MAX_FIRE_LIGHTS), set by _update_fire_lights
var open: bool = false
var table
var inventory
var recipes
var net
var _layer: CanvasLayer
var _root: Node3D
var _player_position: Callable
var _ground_below: Callable
# The crafting and inventory screen's four parts (src/client/ui/inventory/; docs/design/INVENTORY_CRAFTING_REPORT.md step 1): each builds and
# refreshes its own controls, and the state they show stays on this view (the network, the quick keys and the tests read it here).
const RecipeListScript := preload("res://src/client/ui/inventory/recipe_list.gd")
const PackGridScript := preload("res://src/client/ui/inventory/pack_grid.gd")
const ContainerPanelScript := preload("res://src/client/ui/inventory/container_panel.gd")
const StorageDialogsScript := preload("res://src/client/ui/inventory/storage_dialogs.gd")   # the code lock and the Storage sign / Warehouse desk windows (catalog phase 9)
const FoodEffectsScript := preload("res://src/shared/food_effects.gd")
const FoodEffectsUIScript := preload("res://src/client/ui/inventory/food_effects_ui.gd")   # the food effect HUD lines and the replace question (catalog phase 7)
const CraftQueueScript := preload("res://src/client/ui/inventory/craft_queue.gd")
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")   # the window's look (steps B and C)
const PinnedRecipeScript := preload("res://src/client/ui/inventory/pinned_recipe.gd")
const GoalBookScript := preload("res://src/client/ui/goals/goal_book.gd")          # the goal list from the server (protocol 119)
const GoalsHudScript := preload("res://src/client/ui/goals/goals_hud.gd")           # the upper-right Goals box
const GoalPlacardScript := preload("res://src/client/ui/goals/goal_placard.gd")     # the Goal Achieved placard
const JournalScript := preload("res://src/client/ui/goals/journal_view.gd")         # the Journal: Index, Goals, Map (J, G, M)
const InventoryFrameScript := preload("res://src/client/ui/inventory/inventory_frame.gd")   # the redesign's three panels (step 3a)
const YouColumnScript := preload("res://src/client/ui/inventory/you_column.gd")             # the gear wells and the live character (step 3d)
const ArtKit := preload("res://src/client/ui/art_kit.gd")
var _recipe_part: RecipeListScript             # the Make column: search, tabs, recipes, the chosen recipe and Craft
var _pack_part: PackGridScript                 # the pack column: weight, sort, the slot grid and the action row
var _container_part: ContainerPanelScript      # the container screen: a chest's or a fire's store, in the Craft column under its Chest tab
var _storage_ui: StorageDialogsScript          # the code-lock window and the storage-view window
var _food_ui: FoodEffectsUIScript              # the food effect lines and the replace question
var _queue_part: CraftQueueScript              # the crafting queue under the recipe list
var _pinned_part: PinnedRecipeScript           # the pinned recipe's checklist card


func _init() -> void:
	_recipe_part = RecipeListScript.new(self)
	_pack_part = PackGridScript.new(self)
	_container_part = ContainerPanelScript.new(self)
	_storage_ui = StorageDialogsScript.new(self)
	_food_ui = FoodEffectsUIScript.new(self)
	_queue_part = CraftQueueScript.new(self)
	_pinned_part = PinnedRecipeScript.new(self)


var _panel: PanelContainer
var _frame: InventoryFrameScript       # the window's frame: backdrop, the three panels and their title plates (inventory_frame.gd)
var _you_box: VBoxContainer            # the You column's gear, live character and stats
var _craft_root: Control               # the Craft column's recipes and card (recipe_list.gd); an open container shows in its place (4.4)
var _craft_tabs: Array = []            # the Chest and Craft tabs on the Craft panel's title row, shown while a container is open
var _text_buttons: Array = []          # Text - and Text + on the same row, hidden while the tabs are there
var chest_tab: bool = true             # with a container open: true shows the container, false the recipes (Craft still works with it open)
var _you_part: YouColumnScript         # the gear wells and the live character (you_column.gd)
var _panel_values: Dictionary = {}     # stat name -> its value label in the You column
var _grid: GridContainer
var _buttons: Array = []
var _selected: int = -1
var _hover: int = -1                   # pack slot under the mouse (quick keys act on it, else on the selected slot)
var _chest_hover: Array = []           # [chest side (bool), slot] under the mouse in the chest screen
var _prompt: Label
var _site_list: RichTextLabel   # under the prompt on a blueprint site: the materials it still needs, green when you have them to hand and red when not (Dave 5 Nov 2026)
var cover_index                        # the client's Cover.Index: lean-to roofs are added to it
var tool_event: Callable               # ("broke" | "repaired") when a tool in the pack wears out or is mended (sounds)
var _block_next_msec: int = 0
var chest_event: Callable              # ("open" | "close" | "put" | "take", position) for the chest sounds
var chest_mode: bool = false           # the panel on screen is a chest, not the pack and recipes
var chest_inv                          # contents of the open chest (Inventory), from the server
var chest_id: int = 0
var chest_keep_out: bool = false        # the open container is ticked "keep out" (protocol 98 chest_info): crafting and blueprint sites leave it alone
var chest_may_keep_out: bool = false    # and this player owns it, so the tick may be changed (set_keep_out)
var reach_stock: Dictionary = {}        # item number -> count a craft may use besides the pack: loose stacks within 12 m and own containers within 12 m (craft_stock)
var _stock_sign: int = 0                # the pack as it was when the stock was last asked for; a changed pack asks again while the window is open
var _chest_panel: Control
const BOULDER_STATE := 10                 # the world-item row state of a boulder (server_items)
const BOG_STATE := 229                    # the world-item row state of a bog iron deposit (server_items._bog_rows_near)
var bogs: Dictionary = {}                 # bog deposit world id -> {"pos", "left", "total", "wet", "key"}: kept apart from _world; Kathleen's _show_bog draws them
var _boulders: Dictionary = {}            # boulder world id -> {node, shape, lump, pos, left, total, radius, now}
var crown_landed: Callable = Callable()   # (centre Vector3, radius m): a felled crown hit the ground there; the client flattens the grass (Dave 10 Nov 2026)
var boulder_budget: Callable = Callable()   # () -> how many boulders may be drawn at once (by quality, the client sets it)
var _boulder_mesh: ArrayMesh
var _boulder_rock: ShaderMaterial
var _outcrop_rock: Dictionary = {}       # the boulder row's "ore" -> its own ShaderMaterial (OUTCROP_LOOK)
# Outcrop boulders (Kathleen, 10 Nov 2026; Dave could not tell an ore boulder from a plain one). The server sends a boulder's "ore" (boulders.json ore:
# an ore body within reach, or the boulder's own limestone, chalk or marble); the client draws it in the same granite-and-moss shader with the stone tinted
# toward the ore's rock and mineral streaks through it, and the streaks keep the moss off. Subtle on purpose: read from about 10 m, not a neon tell.
# ore: [stone tint, tint share, streak colour, streak width (0..0.5 of the band), flat (0 steep veins, 1 flat seams), halo share, fleck share]
const OUTCROP_LOOK := {
	"copper": [Color(0.31, 0.34, 0.31), 0.35, Color(0.24, 0.46, 0.37), 0.1, 0.0, 0.45, 0.04],     # green malachite staining
	"tin": [Color(0.44, 0.42, 0.39), 0.45, Color(0.13, 0.1, 0.08), 0.16, 0.0, 0.2, 0.08],         # dark cassiterite veins in a pale quartz host
	"iron": [Color(0.36, 0.27, 0.21), 0.45, Color(0.4, 0.2, 0.09), 0.1, 0.0, 0.5, 0.03],           # rust
	"coal": [Color(0.21, 0.21, 0.21), 0.45, Color(0.05, 0.05, 0.05), 0.2, 1.0, 0.15, 0.0],         # flat black seams
	"salt": [Color(0.42, 0.4, 0.37), 0.4, Color(0.8, 0.78, 0.72), 0.16, 1.0, 0.2, 0.05],           # pale crusted beds
	"limestone": [Color(0.58, 0.55, 0.47), 0.7, Color(0.66, 0.63, 0.56), 0.04, 0.6, 0.0, 0.05],     # pale cream bedding
	"chalk": [Color(0.72, 0.71, 0.66), 0.75, Color(0.3, 0.3, 0.3), 0.03, 0.9, 0.0, 0.04],          # white, with dark flint bands
	"marble": [Color(0.64, 0.64, 0.62), 0.7, Color(0.42, 0.43, 0.45), 0.05, 0.3, 0.1, 0.0],         # grey veining
}
const OUTCROP_MOSS := 0.2   # an outcrop is a weathered, freshly broken face: little moss (plain boulders 0.65), so the host rock and its veins show (Dino's tin shot, 10 Nov: moss hid the pale quartz)
const OUTCROP_GLSL := """	vec3 rock = mix(stone, ore_tint, tint_share) * (0.85 + 0.3 * mottle);
	if (vein_amount > 0.0) {
		vec3 lp = world_pos - NODE_POSITION_WORLD;
		vec3 dir = normalize(mix(vec3(0.8, 0.45, 0.4), vec3(0.1, 1.0, 0.1), vein_flat));
		float band = dot(lp, dir) * 2.5 + 0.9 * sin(lp.y * 4.1 + lp.x * 2.7) * (1.0 - vein_flat) + 0.5 * sin(lp.z * 6.3 + lp.x * 1.3);
		float v = abs(sin(band * 3.14159));
		float streak = (1.0 - smoothstep(vein_width, vein_width * 2.0, v)) * vein_amount;
		float halo = (1.0 - smoothstep(vein_width * 2.0, 0.6, v)) * halo_share * (0.5 + 0.5 * mottle);
		float fleck = step(1.0 - fleck_share, fract(sin(dot(floor(lp * 22.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453));
		rock = mix(rock, vein_color, clamp(max(max(streak, halo), fleck * (1.0 - v)), 0.0, 1.0));
		moss *= 1.0 - streak;
	}
	ALBEDO = mix(rock, moss_color * (0.8 + 0.4 * mottle), moss);"""
var _chest_buttons: Array = []
var _pack_buttons: Array = []
var _pack_view: Array = []             # the chest screen's pack side: button index -> real pack slot (a fire shows only what it takes, A to Z)
const DRINK_WINDOW_MSEC := 3000        # a rise in thirst this soon after drink() is a mouthful at the water
var _drink_msec: int = 0
var pick_stamp: int = 0                       # msec of the latest pick-up or gather the player asked for: the Dynasty body bends to pick it up (avatar_driver.gd hook_clip)
var gather_event: Callable             # () when the player gathers something by hand (E): the arm reaches and the view dips a little
var eat_event: Callable                # (item id) when something eaten or applied takes effect (sounds)
var worn_event: Callable               # (changed item ids Array, all worn item ids Array) when what is worn changes; changed is empty for the first list after joining (sounds)
var skill_up_event: Callable           # () when a skills message shows a skill's level higher than the last one (sounds; not on the first list after joining)
var hurt_event: Callable               # (health lost int) when a vitals update drops health by HURT_MIN or more (a bite, a fall): sounds
var _vitals_seen: bool = false          # the first vitals after joining sets health; it is not a hurt
const HURT_MIN := 4                     # a smaller drop is a slow drain (hunger, cold, bleeding), not a blow
var hunger: int = 100                  # stomach, percent
var fitness: int = 0                  # the character's fitness, -10 to 10: how slowly exertion rises (character screen)
var training_today: int = 0           # today's training, percent of a fitness point (character screen; turns into fitness at game midnight)
var luck: int = 0                     # the character's luck, -10 to 10, fixed (character screen)
var thirst: int = 100                  # body water, percent (100 = full; 0 = parched)
var health: int = 100
var breath_ds: int = -1                 # air left under water in tenths of a second; -1 = head above the surface (the oxygen symbol hides)
var weight_kg: float = 75.0
var _vitals_cfg: Dictionary = {}
var _carry_cfg: Dictionary = {}
var _exertion_cfg: Dictionary = {}
var _path_cfg: Dictionary = {}          # data/path_speed.json: pace factors on a trodden path
var _path_cells: Dictionary = {}        # Vector2i (1 m ground cell) -> how many path patches have their centre in it

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
var lie_on_bed: Callable = Callable()        # (bed position, yaw degrees) after E on a bed: the client lays the player along it
var sit_on_seat: Callable = Callable()       # (seat position, yaw degrees, structures.json row) after E on a seat: the client sits the player on it
const SINK_M := 0.35                        # most the remains sink into the ground by day 7 (death.json sink_m)
const DEATH_FADE_S := 4.0                   # black, then waking, after a death (death.json respawn_delay_s)
var _death_msec: int = 0                    # when the last death arrived, 0 when none is being shown
var strength: int = 0                       # attributes the server sends with the skills (protocol 37)
var memory: int = 0
var bow_arrow: int = 0                     # the arrow item the bow is loaded with (dragged onto the bow on the hotbar, Dave 10 Nov 2026); 0 = the first one in the pack
var _skill_order: Array = []                # data/items/skills.json "skills" names, in the order the skill rows number them
var skill_rows: Array = []                  # [[skill index, working level, rusty], ...] in skills.json order
const InnerSettingsScript := preload("res://src/client/inner_voice_settings.gd")
var inner_settings = InnerSettingsScript.new()   # Esc > Settings > Inner voice: hints and dialogue switches (inner_voice_settings.gd)
var thought_event: Callable = Callable()     # (line id, kind) when the inner voice speaks: Sounds plays inner_voice/<line id>.ogg if it exists
var _thought_label: Label
var _thought_until_msec: int = 0
var worn: PackedInt32Array = PackedInt32Array()   # item number per worn position (clothing.json worn, "slot:layer"), 0 = nothing (protocols 40, 107)
var worn_inst: Dictionary = {}                    # worn position index -> the worn piece's instance data (protocol 106); absent = plain
var clothing_cfg: Dictionary = {}
const TrackingScript := preload("res://src/shared/tracking.gd")
var trail_mult: float = 1.0                 # Tracking skill -> trail life multiple, 1.0 to 6.0 (see _update_trail_mult)
var _tracking_index: int = -1               # position of "tracking" in skills.json order, found once
var _cooking_cfg: Dictionary = {}
var _structures_cfg: Dictionary = {}
var _crops_cfg: Dictionary = {}   # data/items/crops.json "crops", read once (_crop_cfg)
var remains_marks: Array = []                # [[position, seconds left, msec received], ...] the owner's remains with gear (protocol 39)
var sick_hours: int = 0                      # game hours of sickness left, 0 = well (protocol 38)
var _sick_label: Label
var _temp_label: Label
var air_c: float = NAN                      # outside air temperature, C, from the client weather (terrain_client._update_weather); NAN until known
var warmth: int = 100                       # body warmth, percent (protocol 36)
var energy: int = 100                       # the Energy pool, percent (job 95)
var forced_sleep: bool = false               # collapsed from exhaustion: asleep and cannot wake until rested (bit 8 of the stance)
var asleep: bool = false                     # the server says this character sleeps (bit 4 of the stance it sends, job 86)
var reject_event: Callable = Callable()   # ("far" | "no_tool" | "full_pack" | "other") when the server refused an action
var strain_event: Callable = Callable()   # (strain, state, fade) whenever the server sends a change
var _strain_note: Label
var _eat_item: String = ""
var equip_requested: Callable = Callable()   # (hotbar key) -> hold what is in that key's slot, or put it away (the client wires it to the held item)
var held_slot_now: Callable = Callable()     # () -> the pack slot in hand, or -1 for empty hands
var hotbar_strip                              # HotbarStrip, set by the client
var heart_pulse                               # HeartPulse (the line over the hotbar), set by the client
var heart_bpm: Callable = Callable()   # () -> the heart rate now (the heartbeat sound's), set by the client
var _character                         # CharacterScreen, built the first time Tab is pressed
var _panel_bars: Dictionary = {}       # "Health", "Exertion", "Food", "Water" -> ProgressBar at the top of the inventory screen (the only bars in the game)
var _vitals_back: Control
var _vitals_warning: Label
var _weight_label: Label
var _purse_label: RichTextLabel
var shoulder_id: String = ""                  # the large log on the shoulder (protocol 64), "" when none: Mandy shows the carry pose from this
var purse_copper: int = 0                      # the purse, in copper (protocol 61)
var rep_names: PackedStringArray = PackedStringArray()   # NPCs this player has a reputation with, and the points
var rep_points: PackedInt32Array = PackedInt32Array()
var _coins_cfg: Dictionary = {}
var _rep_cfg: Dictionary = {}
var _carry_bar: ProgressBar              # carried weight against what you can carry: green, yellow from 70 percent, red from 80
var plant_point: Vector3 = Vector3.ZERO   # where the plant to gather stands (harvest.gd), for the cursor choice
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
	inventory = InventoryScript.pack(table)
	recipes = RecipeTableScript.load_default(table)
	net.inventory_full_received.connect(func(...args): _timed("_on_full", _on_full, args))
	net.inventory_slots_received.connect(func(...args): _timed("_on_slots", _on_slots, args))
	net.world_items_received.connect(func(...args): _timed("_queue_world_items", _queue_world_items, args))
	net.notice_received.connect(func(...args): _timed("_on_notice", _on_notice, args))
	net.chest_received.connect(_on_chest)
	net.chest_info_received.connect(_on_chest_info)
	net.chest_lock_received.connect(_storage_ui.on_lock)
	net.storage_view_received.connect(_storage_ui.on_view)
	net.food_effects_received.connect(_food_ui.on_effects)
	net.food_ask_received.connect(_food_ui.on_ask)
	net.craft_stock_received.connect(_on_craft_stock)
	net.cart_pull_received.connect(func(id: int, pace_dms: int): pulling_id = id; pull_pace_mps = float(pace_dms) / 10.0)
	net.items_moved_received.connect(_on_items_moved)
	net.favourites_received.connect(_on_favourites)
	net.bulk_done_received.connect(_on_bulk_done)
	net.vitals_received.connect(func(...args): _timed("_on_vitals", _on_vitals, args))
	net.training_received.connect(func(percent: int):
		training_today = percent
		if _character != null:
			_character.refresh())
	net.energy_received.connect(_on_energy)
	net.warmth_received.connect(_on_warmth)
	net.comfort_received.connect(_on_comfort)
	net.sick_received.connect(_on_sick)
	net.body_received.connect(func(bpm, eta, phase): body_bpm = bpm; sleep_eta_s = eta; body_phase = phase)
	net.limp_received.connect(func(percent): limp_share = clampf(float(percent) / 100.0, 0.1, 1.0))
	net.remains_received.connect(_on_remains_marks)
	net.worn_received.connect(_on_worn)
	net.thought_received.connect(func(...args): _timed("_on_thought", _on_thought, args))
	net.skills_received.connect(func(...args): _timed("_on_skills", _on_skills, args))
	net.purse_received.connect(func(copper): purse_copper = copper; _refresh_purse())
	net.carry_received.connect(func(item_id):
		shoulder_id = item_id

		if chest_mode:
			_container_part.refresh()

		if _weight_label != null:
			_refresh_weight())
	net.reputation_received.connect(func(_ids, names, points): rep_names = names; rep_points = points)
	_setup_goals()
	var coins_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/coins.json"))
	_coins_cfg = coins_parsed if typeof(coins_parsed) == TYPE_DICTIONARY else {}
	var rep_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/reputation.json"))
	_rep_cfg = rep_parsed if typeof(rep_parsed) == TYPE_DICTIONARY else {}
	net.died_received.connect(_on_died)
	net.breath_received.connect(func(deciseconds: int) -> void: breath_ds = deciseconds)
	net.strain_received.connect(_on_strain)
	net.craft_queue_received.connect(func(...args): _timed("_on_craft_queue", _on_craft_queue, args))
	net.reject_received.connect(_on_reject)
	var exertion_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/exertion.json"))
	_exertion_cfg = exertion_parsed if typeof(exertion_parsed) == TYPE_DICTIONARY else {}
	var path_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/path_speed.json"))
	_path_cfg = path_parsed if typeof(path_parsed) == TYPE_DICTIONARY else {}
	_vitals_cfg = VitalsRules.load_config()
	_carry_cfg = CarryRules.load_config()
	_register_builtin_interactables()
	if DisplayServer.get_name() == "headless":
		_prewarm_loose_meshes()   # tests and headless runs: all at once, as before
	else:
		_start_loose_prewarm()    # a window: a few meshes each frame while the ground loads
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
	_site_list = RichTextLabel.new()
	_site_list.anchor_left = 0.0
	_site_list.anchor_right = 1.0
	_site_list.anchor_top = 0.5
	_site_list.anchor_bottom = 1.0
	_site_list.offset_top = 72.0
	_site_list.offset_bottom = 0.0
	_site_list.bbcode_enabled = true
	_site_list.scroll_active = false
	_site_list.add_theme_font_size_override("normal_font_size", 28)
	_site_list.add_theme_constant_override("outline_size", 6)
	_site_list.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_site_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_site_list.visible = false
	_layer.add_child(_site_list)
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

	for forgotten in CharacterKeys.take_forgotten():
		net.forget_character.rpc_id(1, str(forgotten))


# Public for the Esc > Advanced "Show my player key" button (admin.json lists these keys).
func player_key() -> String:
	return _player_key()


func _player_key() -> String:
	return CharacterKeys.key_for(str(CharacterStore.active().get("id", "")), _machine_key())


func _machine_key() -> String:
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
	hotbar_hover = -1   # a hover left over from the last time the window was open never acts on a hotbar slot

	if chest_mode:
		_close_chest()
		return

	if not open and character_open():
		_character.toggle()

	if not open and journal != null and journal.open:
		journal.close()   # one window at a time

	open = not open

	if not open and _recipe_search != null:
		_recipe_search.release_focus()   # the keys go back to the game
		_recipe_search.text = ""         # the filter lasts until the menu is closed

	if open:
		_build_panel()
		_stock_sign = 0   # the window opens: ask for the craft stock again
		_refresh()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif _panel != null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if _panel != null:
		_panel.visible = open

	if _you_part != null:
		_you_part.set_active(open)


# Esc in the search box (while it has focus and holds text) empties it instead of closing the menu. True when it did.
func search_escape() -> bool:
	if _recipe_search == null or not open or not _recipe_search.has_focus() or _recipe_search.text == "":
		return false

	_recipe_search.clear()
	_refresh()
	return true


func close() -> void:
	if _storage_ui.is_open():
		_storage_ui.close()
		return   # Esc shuts the lock or storage window first

	if _food_ui.is_open():
		_food_ui.close()
		return

	if dialogue_open and dialogue_close.is_valid():
		dialogue_close.call()

	if journal != null and journal.open:
		journal.close()

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

	if journal != null and journal.open:
		journal.close()

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

	if _site_list != null:
		_site_list.visible = false
	_notice_until_msec = 0
	_prompt_next_msec = Time.get_ticks_msec() + 400


# --- One interaction registry (Technical direction, 2026-10-20) ---
# E is the one interaction key. Everything E can act on registers a probe with a priority (lowest first);
# the first probe that finds something decides the single centre-screen prompt and what E does.
# A probe returns {} or {"prompt": text, "tap": Callable, "hold": Callable (optional)}. With a "hold",
# a tap acts on release and a hold (HOLD_E_S) does the other thing; without one the tap acts at once.
const HOLD_E_S: float = 0.3   # halved (Dave 5 Nov 2026: picking up twice as fast)
var fuel_event: Callable = Callable()
var _interactables: Array = []
var _e_active: Dictionary = {}
var _e_start_msec: int = 0


func register_interactable(interactable_name: String, priority: int, probe: Callable) -> void:
	_interactables.append({"name": interactable_name, "priority": priority, "probe": probe})
	_interactables.sort_custom(func(x, y): return int(x["priority"]) < int(y["priority"]))


# E does what the cursor is on (Dave 1 Nov 2026). A probe may return a "point" (the world spot it acts on). Of the probes that found something, the one
# whose point is aimed at (aimed_at) and best centred wins, whatever its priority; E then does that one action and nothing else nearby (a chopping block
# in the cursor does not also gather the wood lying around it). Only when the cursor is on nothing with an E action does the priority order decide, which
# is where the nearby pick-up and gather live. "aimed" is set on a result that won because of the cursor.
func current_interaction() -> Dictionary:
	if pulling_id != 0:   # both hands on the handle: E only lets go (catalog Phase 10)
		return {"kind": "structure", "prompt": "Press E to let go of the handcart", "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_CART, 0, CART_RELEASE, 0, Vector3.ZERO)}

	var first: Dictionary = {}
	var best: Dictionary = {}
	var best_cos: float = -2.0

	for entry in _interactables:
		var found: Dictionary = entry["probe"].call()

		if found.is_empty():
			continue

		if first.is_empty():
			first = found

		if not found.has("point") or not view_direction.is_valid() or not aimed_at(found["point"]):
			continue

		var aim_cos: float = aim_cos_of(found["point"])

		if aim_cos > best_cos + 0.0001:
			best_cos = aim_cos
			best = found

	if not best.is_empty():
		best["aimed"] = true
		return best

	return first


# The cosine between the view direction and the line from the eyes to a point.
func aim_cos_of(point: Vector3) -> float:
	var to: Vector3 = point - (_player_position.call() + Vector3(0.0, 1.6, 0.0))
	var forward: Vector3 = view_direction.call() if view_direction.is_valid() else Vector3.ZERO
	return 1.0 if forward.length() < 0.01 or to.length() < 0.01 else to.normalized().dot(forward.normalized())


# The E prompt line for an interaction (Dave 1 Nov 2026): shown only while inspection mode is on. With it off the screen carries no "Press E to..." text;
# E works the same. Messages that say why something failed (needs plant fibre, too heavy) are notices, not prompts, and show either way.
func prompt_text(interaction: Dictionary) -> String:
	if not (is_inspecting.is_valid() and bool(is_inspecting.call())) or bool(interaction.get("quiet", false)):
		return ""

	return KeyBindings.localize(str(interaction.get("prompt", "")))


# What the cursor is on: the kind of the E action it is aimed at ("pickup", "plant", "block", "fire", "structure", "npc"...), "" when it is on nothing.
func cursor_kind() -> String:
	var found: Dictionary = current_interaction()
	return str(found.get("kind", "")) if bool(found.get("aimed", false)) else ""


# Dave's three cases for E in every path, tap, hold and auto-pickup (1 Nov 2026):
#  1. the cursor is on a pickable item: that item and only that one;
#  2. the cursor is on something else with an E action (block, fire, bench, chest, door, tree, plant): that action and nothing else is picked up;
#  3. the cursor is on nothing specific: the nearby pick-up and gather may run.
# Held E calls this each step. True when the cursor is on something (the caller must not sweep the ground); the held action itself repeats here, at the server's pace.
# Dave 10 Nov 2026: a pickable item the reticle is on that is too heavy (or was refused) does not hold the sweep up: held E goes on to the nearest
# thing around that can be taken. After the reticle's own item has come up, held E waits reticle_pause_s before it does.
func hold_e_step() -> bool:
	var found: Dictionary = current_interaction()
	var now: int = Time.get_ticks_msec()
	var kind: String = str(found.get("kind", ""))

	if bool(found.get("aimed", false)) and not (kind == "pickup" and not liftable(int(found.get("id", 0)))):
		if kind in ["pickup", "plant"] and now >= _hold_next_msec:   # not a block: holding E on a chopping block picks it up
			_hold_next_msec = now + batch_every_ms()
			found["tap"].call()

		return true

	return _reticle_took_msec >= 0 and now - _reticle_took_msec < reticle_pause_ms()   # the pause after the reticle's item, then the sweep


var _hold_next_msec: int = 0


func _register_builtin_interactables() -> void:
	register_interactable("pickup", 10, _probe_pickup)
	register_interactable("fire", 20, _probe_fire)
	register_interactable("structure", 30, _probe_structure)


# Dave 2026-10-21: the prompt is only "Press E to gather", and only for what lies in the general direction you look.
var view_direction: Callable = Callable()   # () -> where the camera looks; unset (tests) counts everything as in view
const VIEW_COS := 0.35                       # about 70 degrees either side of the view direction
const VIEW_ALWAYS_M := 0.8                   # and anything this close, whatever way you face
var _sweep_asked: Dictionary = {}            # world id -> msec a held-E pick was asked for
# Dave 10 Nov 2026: held E takes what the reticle is on first; when that is too heavy (or will not fit) it goes on to the next nearest thing that can be
# taken, and says "too heavy" only when nothing in reach can be. After the reticle's item, it waits reticle_pause_s (data/items/pickup_batch.json) first.
const PICKUP_BATCH_PATH := "res://data/items/pickup_batch.json"
var _batch_cfg: Dictionary = {}
var _sweep_refused: Dictionary = {}          # world id -> true: the server refused it this hold (too heavy, no room): skipped until E is let go
var _sweep_heavy: int = 0                    # the nearest loose item the last sweep step skipped as too heavy, 0 none
var _sweep_said: bool = false                # the "too heavy" line was shown this hold
var _last_pick: int = 0                      # the world id E last asked for (a refusal is put down to it)
var _reticle_took_msec: int = -1             # when held E last took the item the reticle is on, -1 not this hold
var _pending_heavy: int = 0                  # E went down on a too heavy item: "too heavy" waits for the hold (something else may come up), said on release if nothing did
var _hold_took: bool = false                 # this press of E has taken something (an item, a plant, a branch)


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
	return {"kind": "pickup", "id": id, "point": _world[id]["pos"], "prompt": "Press E to gather", "quiet": not aimed_at(_world[id]["pos"]), "tap": func():
		clear_prompt()
		pick_stamp = Time.get_ticks_msec()

		if not liftable(id):   # too heavy: no "too heavy" yet, held E may find something lighter around (Dave 10 Nov 2026)
			_pending_heavy = id
			_sweep_heavy = id
			return

		_last_pick = id
		_hold_took = true

		if _world.has(id) and aimed_at(_world[id]["pos"]):
			_reticle_took_msec = pick_stamp   # the reticle's own item: held E waits reticle_pause_s before it goes on to what lies around

		if gather_event.is_valid():
			gather_event.call()

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


# Held E (harvest.gd steps this): the nearest loose item within 2 m that can be taken, wherever you look, one at a time. 0 when none, or for an
# item already asked for in the last batch_every_s. Too heavy ones (can_lift) and ones the server refused this hold are passed over; the nearest
# too heavy one is kept in _sweep_heavy so sweep_nothing can say why nothing came up.
func sweep_target(radius: float) -> Array:
	var here: Vector3 = _player_position.call()
	var now: int = Time.get_ticks_msec()
	var best: Array = [0, radius + 1.0]
	var heavy: Array = [0, radius + 1.0]

	for id in _world:
		if _world[id]["state"] != 0 or now - int(_sweep_asked.get(id, -100000)) < batch_every_ms():
			continue

		var d: float = here.distance_to(_world[id]["pos"])

		if d > radius:
			continue

		if not liftable(id):
			if d < float(heavy[1]):
				heavy = [id, d]
		elif d < float(best[1]):
			best = [id, d]

	_sweep_heavy = int(heavy[0])
	return best


func sweep_pick(id: int) -> void:
	_sweep_asked[id] = Time.get_ticks_msec()
	pick_stamp = _sweep_asked[id]
	_last_pick = id
	_hold_took = true
	net.inventory_action.rpc_id(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)


# Held E found nothing at all in reach to take (harvest.gd, after the loose items, plants and branches): when something was passed over as too heavy,
# say so once this hold, as the server would (Dave 10 Nov 2026: "too heavy" only when nothing in reach can be taken).
func sweep_nothing() -> void:
	if _sweep_said or _hold_took or _sweep_heavy == 0 or not _world.has(_sweep_heavy):
		return

	_say_too_heavy(_sweep_heavy)


func _say_too_heavy(id: int) -> void:
	_sweep_said = true
	var number: int = int(_world[id]["number"]) if _world.has(id) else 0
	_on_notice("Put your log down first (Q)." if _is_shoulder(number) and shoulder_id != "" else "Too heavy to carry any more")
	refuse_cue("full_pack")


# A plant or branch picked by held E (harvest.gd): something came up this press.
func note_hold_took() -> void:
	_hold_took = true


# E is up (harvest.gd calls this every frame then): a tap on a too heavy item that nothing else answered says so now.
func sweep_reset() -> void:
	if _pending_heavy != 0 and not _sweep_said and not _hold_took:
		_say_too_heavy(_pending_heavy)

	_pending_heavy = 0
	_hold_took = false
	_sweep_asked.clear()
	_sweep_refused.clear()
	_sweep_heavy = 0
	_sweep_said = false
	_reticle_took_msec = -1


# Whether the loose ground item `id` can be taken now, as the server will judge it: within the carry limit (data/items/weights.json, CarryRules) and,
# for a large log, with nothing on the shoulder already. Not one the server refused this hold. Without a carry config (tests) everything can.
func liftable(id: int) -> bool:
	if not _world.has(id) or int(_world[id]["state"]) != 0 or _sweep_refused.has(id):
		return false

	var number: int = int(_world[id]["number"])

	if _is_shoulder(number) and shoulder_id != "":
		return false

	if _carry_cfg.is_empty() or inventory == null:
		return true

	return CarryRules.fit_count(table.id_of(number), 1, carried_kg(), carry_body_kg(), _carry_cfg) > 0


func _is_shoulder(number: int) -> bool:
	return number > 0 and str(table.entry(table.id_of(number)).get("carry", "")) == "shoulder"


func pickup_batch_cfg() -> Dictionary:
	if _batch_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PICKUP_BATCH_PATH)) if FileAccess.file_exists(PICKUP_BATCH_PATH) else null
		_batch_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"batch_every_s": 0.3, "reticle_pause_s": 2.0}

	return _batch_cfg


func batch_every_ms() -> int:
	return int(float(pickup_batch_cfg().get("batch_every_s", 0.3)) * 1000.0)


func reticle_pause_ms() -> int:
	return int(float(pickup_batch_cfg().get("reticle_pause_s", 2.0)) * 1000.0)


# The refusal cue (a missing tool and the like), the same one the server's reject event plays.
func refuse_cue(reason: String) -> void:
	if reject_event.is_valid():
		reject_event.call(reason)


# The first pack slot holding a torch that water or rain put out (items.json "relit_item"), or -1.
func _doused_torch_slot() -> int:
	for slot in range(inventory.numbers.size()):
		if inventory.numbers[slot] != 0 and str(table.entry(table.id_of(inventory.numbers[slot])).get("relit_item", "")) != "":
			return slot

	return -1


func _probe_fire() -> Dictionary:
	var id: int = _nearest_fire()

	if id == 0:
		return {}

	var state: int = _world[id]["state"]

	if _lit_state(state) and _doused_torch_slot() >= 0:
		# A doused torch in the pack: E at a burning fire lights it again (Dave, 4 Nov 2026), instead of putting the fire out.
		return {"kind": "fire", "point": _world[id]["pos"] + Vector3(0.0, 0.3, 0.0), "prompt": "Press E to light your torch", "tap": func():
			net.inventory_action.rpc_id(1, Net.ACT_RELIGHT, id, 0, 0, Vector3.ZERO)}

	var found: Dictionary = {"kind": "fire", "point": _world[id]["pos"] + Vector3(0.0, 0.3, 0.0), "prompt": _fire_prompt(state), "tap": func():
		if state == 9 or state == StructureLook.FIRE_ASH:
			net.inventory_action.rpc_id(1, Net.ACT_LIGHT, id, 0, 0, Vector3.ZERO)
		elif _lit_state(state):
			net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO)   # E on a burning fire puts it out (Dave 2 Nov 2026)
		else:
			show_notice("Press F to put wood in the fire")}

	if not _lit_state(state):
		found["hold"] = pick_up_fire   # a fire that is not burning: hold E takes it up again (Dave 2 Nov 2026); wood and food go in with F, a burning fire cooks what is in its store

	return found


# A placed sawmill's look-at addition: "   (the wheel gives 62 %)" from its row's water wheel share, "" for every other piece.
func wheel_note(id: int) -> String:
	if not _world.has(id) or not _world[id].has("wheel"):
		return ""

	return "   (the wheel gives %d %%)" % int(_world[id]["wheel"])


func _probe_structure() -> Dictionary:
	# A fire has its own probe (_probe_fire), so it is left out here. Before, this probe found it too, aimed a little higher, and its "Hold E to take down"
	# line hid "Press E to light" and "Press F to add wood" (Dave 5 Nov, a campfire with no fuel).
	var near: int = _nearest_struct(true)
	var found: Dictionary = _probe_structure_for(near)

	if not found.is_empty():
		found["kind"] = "block" if int(_world[near]["state"]) == 7 else "structure"
		found["point"] = _world[near]["pos"] + Vector3(0.0, 0.4, 0.0)   # the middle of the thing, where the cursor rests

	return found


func _probe_structure_for(id: int) -> Dictionary:
	if id == 0:
		return {}

	var state: int = _world[id]["state"]
	var take_down: Callable = func():
		clear_prompt()
		net.inventory_action.rpc_id(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)

	if _world[id].get("site") != null:   # a blueprint site: E deposits the materials, hold E takes it down and gives back what was put in
		return {"prompt": "Press E to deposit materials (hold E to take the blueprint down)", "lines": _site_lines(_world[id]["site"]), "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	if state == 11 or state == 12:
		return {"prompt": "Press E to search the remains", "tap": func(): _ask_open(id)}

	var cart_def: Dictionary = _structure_by_state(state)

	if cart_def.has("vehicle"):   # the Handcart (catalog Phase 10): E takes the handle, F opens its cargo, hold E takes it apart
		return {"prompt": "Press E to take the handle (F to open it, hold E to take it down)", "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_CART, id, CART_GRAB, 0, Vector3.ZERO), "hold": take_down}

	if bool(_world[id].get("on", false)):   # a crate riding on a cart: hold E sets it down beside the cart
		return {"prompt": "Press E to open (hold E to set it down off the handcart)", "tap": func(): _ask_open(id), "hold": func():
			clear_prompt()
			net.inventory_action.rpc_id(1, Net.ACT_CART, id, CART_UNLOAD, 0, Vector3.ZERO)}

	if bool(cart_def.get("cargo", false)) and _cart_near(_world[id]["pos"]):   # a crate beside a cart: hold E lifts it on, with what it holds
		return {"prompt": "Press E to open (hold E to lift it onto the handcart)", "tap": func(): _ask_open(id), "hold": func():
			clear_prompt()
			net.inventory_action.rpc_id(1, Net.ACT_CART, id, CART_LOAD, 0, Vector3.ZERO)}

	if str(_structure_by_state(state).get("use", "")) == "serve":   # a placed Serving Platter (catalog phase 8): E eats a portion of its board, or opens it to set one out
		var board: int = int(_world[id].get("board", 0))

		if board > 0:
			return {"prompt": "Press E to eat from the %s, %d left (hold E to take it up)" % [table.sentence_name(board), int(_world[id].get("portions", 0))], "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

		return {"prompt": "Press E to set a food board on the platter (hold E to take it up)", "tap": func(): _ask_open(id), "hold": take_down}

	if state == 7:   # tap splits, hold picks up, like the other structures (Dave 2 Nov 2026, bug 2); F chops logs from storage nearby (master s2.4)
		return {"prompt": "Press E to split firewood, F to chop logs from storage%s (hold E to pick up the block)" % _fill_note(id), "tap": func(): _use_block(id), "hold": take_down}

	var store_def: Dictionary = _structure_by_state(state)

	if str(store_def.get("use", "")) == "kiln":   # the Kiln (master s2.6): E lights it and puts it out, like a fire; F for its logs and charcoal
		return {"prompt": "Press E to %s, F for its logs and charcoal%s (hold E to take it down)" % ["put the kiln out" if bool(_world[id].get("lit", false)) else "light the kiln", _fill_note(id)], "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	if str(store_def.get("use", "")) == "smelt":   # a Smelter (master s2.7): F for its fuel and ore; E works the bellows of one that has them
		var smelt_tap: Callable = func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO)

		if not bool(store_def.get("smelt", {}).get("bellows", false)):
			smelt_tap = func(): _ask_open(id)

		return {"prompt": "Press %s for its fuel and ore%s (hold E to take it down)" % ["E to work the bellows, F" if bool(store_def.get("smelt", {}).get("bellows", false)) else "E or F", _fill_note(id)], "tap": smelt_tap, "hold": take_down}

	if str(store_def.get("station", "")) != "" and int(store_def.get("out_slots", 0)) > 0:   # a station with a store (master s2.5): E opens the store, F crafts
		return {"prompt": "Press E to open the %s%s, F to use it%s (hold E to take it down)" % [table.sentence_name(_world[id]["number"]), _fill_note(id), wheel_note(id)], "tap": func(): _ask_open(id), "hold": take_down}

	if _is_chest(state):
		return {"prompt": "Press E to open (hold E to take it down)", "tap": func(): _ask_open(id), "hold": take_down}

	if state == 33:
		return {"prompt": "Press E to take the stones back (hold E to pick up the pile)", "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	if str(_structure_by_state(state).get("piece_kind", "")) == "door":   # a door in a doorway (BUGLIST-002): a shut one has blocks_walk; the empty frame has no use and falls through to "take down"
		return {"prompt": "Press E to close the door" if not bool(_structure_by_state(state).get("blocks_walk", false)) else "Press E to open the door", "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	var station_def: Dictionary = _structure_by_state(state)

	if _is_bed_def(station_def):   # a tilled bed or garden plot (FARMING_SPEC.md steps 3 to 5): E sows, waters or harvests; a plot, which has a kit, still comes down with hold E
		return _bed_interaction(id, station_def, take_down)

	if str(station_def.get("use", "")) == "storage_view":   # a Storage sign or Warehouse desk (catalog phase 9): E shows what the containers round it hold
		return {"prompt": "Press E to see what is stored here (hold E to take it down)", "tap": func(): _storage_ui.ask_view(id), "hold": take_down}

	if str(station_def.get("use", "")) == "set_spawn":   # a bed: E lies down on it and makes it the spawn point (Dave 4 Nov 2026), hold E takes it down
		var bed: Dictionary = {"prompt": "Press E to lie down (hold E to take it down)", "hold": take_down}
		bed["tap"] = func():
			net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO)

			if lie_on_bed.is_valid() and _world.has(id):
				lie_on_bed.call(_world[id]["pos"], float(_world[id].get("yaw", 0.0)))

		return bed

	if str(station_def.get("use", "")) == "sit":   # a seat (docs/COMFORT_DESIGN.md 10.3; Dave 5 Nov 2026 "we need a sitting on a chair action"): E sits on it, hold E takes it down
		var seat: Dictionary = {"prompt": "Press E to sit (hold E to take it down)", "hold": take_down}
		seat["tap"] = func():
			if sit_on_seat.is_valid() and _world.has(id):
				sit_on_seat.call(_world[id]["pos"], float(_world[id].get("yaw", 0.0)), station_def)

		return seat

	# Water pieces (buildables plan section 6): E works a well or pump (E again stops), E at a trough, barrel or cistern drinks, or fills the container in hand.
	var water: Variant = station_def.get("water", {})

	if typeof(water) == TYPE_DICTIONARY and str(water.get("role", "")) == "source" and (water.has("pump") or bool(water.get("windlass", false))):
		return {"prompt": "Press E to work the %s, E again to stop (hold E to take it down)" % table.sentence_name(_world[id]["number"]), "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	if typeof(water) == TYPE_DICTIONARY and str(water.get("role", "")) == "tank":
		return {"prompt": "Press E to drink, or to fill what you hold (hold E to take it down)", "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_DRINK, held_container_slot(), 0, 0, Vector3.ZERO), "hold": take_down}

	if str(station_def.get("station", "")) != "":
		return {"prompt": "Press F to use the %s%s" % [table.sentence_name(_world[id]["number"]), wheel_note(id)], "tap": _open_station, "hold": take_down}

	# A light (a torch stuck in the ground or on a wall, a wall torch, a chandelier): E lights it with its fuel from the pack (a stick for a torch), hold E takes it down.
	if str(station_def.get("use", "")) == "light":
		var burning: bool = _world[id].get("light") != null
		var what: String = "the torch" if bool(station_def.get("hand_placed", false)) else "it"
		var tap: Callable = func():
			if burning:
				show_notice("Hold E to take it back")
			else:
				net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO)

		return {"prompt": ("Hold E to take %s back" % what) if burning else ("Press E to light %s with a %s (hold E to take it back)" % [what, table.sentence_name(table.number_of(str(station_def.get("fuel", "stick"))))]), "tap": tap, "hold": take_down}

	return {"prompt": "Hold E to take down the %s" % table.sentence_name(_world[id]["number"]), "tap": func(): show_notice("Hold E to take it down"), "hold": take_down}


func _is_bed_def(def: Dictionary) -> bool:
	return str(def.get("item", "")) == "tilled_bed" or bool(def.get("plot", false))


# crops.json, read once: the client's wording needs the crop names, seeds and harvest tools (the server rules on all of it).
func _crop_cfg() -> Dictionary:
	if _crops_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/crops.json"))
		_crops_cfg = parsed.get("crops", {}) if typeof(parsed) == TYPE_DICTIONARY else {"none": {}}

	return _crops_cfg


# The pack slot of the seed E would sow: the one in hand, else the first seed in the pack; -1 for none.
# PROVISIONAL (GOALS-REPAIR A-6): E on an empty bed sows the seed in hand, else the first seed in the pack (REPAIR_DECISIONS.md section 4).
func _seed_slot() -> int:
	var hand: int = _hand_slot()

	if hand >= 0 and hand < inventory.slot_count and inventory.numbers[hand] != 0 and FarmRules.crop_of_seed(_crop_cfg(), table.id_of(inventory.numbers[hand])) != "":
		return hand

	for slot in range(inventory.slot_count):
		if inventory.numbers[slot] != 0 and FarmRules.crop_of_seed(_crop_cfg(), table.id_of(inventory.numbers[slot])) != "":
			return slot

	return -1


# E on a bed: the one request FarmRules.bed_action words (sow the seed in hand or pack, water with the filled container in hand, harvest a ripe crop). The server does
# the checking; a refusal (not the season, not ripe, too far) comes back as its notice.
func _bed_interaction(id: int, def: Dictionary, take_down: Callable) -> Dictionary:
	var row: Dictionary = _world[id]
	var seed_slot: int = _seed_slot() if str(row.get("crop", "")) == "" else -1   # only an empty bed takes a seed (this probe runs every frame the bed is aimed at)
	var water_slot: int = held_container_slot() if held_container_has_water() else -1
	var plan: Dictionary = FarmRules.bed_action(_crop_cfg(), str(row.get("crop", "")), int(row.get("stage", 0)), seed_slot, table.sentence_name(inventory.numbers[seed_slot]) if seed_slot >= 0 else "", water_slot)
	var found: Dictionary = {"prompt": plan["prompt"], "tap": func(): _bed_tap(id, plan)}

	if str(def.get("kit", "")) != "":
		found["hold"] = take_down

	return found


# Sends the one request the bed's plan names (a block body in a lambda inside a dictionary literal does not parse with a match in it: hence a method).
func _bed_tap(id: int, plan: Dictionary) -> void:
	match str(plan["act"]):
		"sow":
			net.inventory_action.rpc_id(1, Net.ACT_SOW, id, int(plan["b"]), 0, Vector3.ZERO)   # b: the seed's pack slot
		"harvest":
			net.inventory_action.rpc_id(1, Net.ACT_HARVEST, id, 0, 0, Vector3.ZERO)
		"water":
			net.inventory_action.rpc_id(1, Net.ACT_WATER_BED, id, int(plan["b"]), 0, Vector3.ZERO)   # b: the container in hand, which the server draws the water from
		_:
			show_notice(str(plan["prompt"]))


# A bed's crop and stage from its world row (server_items.crop_row_extra): kept on the record for the E prompt, with its PLACEHOLDER stage look hung on the bed's node;
# swapped when the stage changes and dropped when the crop is gone (harvest, frost).
func _note_crop(id: int, row: Array) -> void:
	var extra: Dictionary = row[5] if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else {}
	var crop: String = str(extra.get("crop", ""))
	var stage: int = int(extra.get("stage", 0)) if crop != "" else -1
	var rec: Dictionary = _world[id]

	if str(rec.get("crop", "")) == crop and int(rec.get("stage", -1)) == stage:
		return

	if is_instance_valid(rec.get("crop_node")):
		(rec["crop_node"] as Node).queue_free()

	rec["crop"] = crop
	rec["stage"] = stage
	rec["crop_node"] = null

	if crop != "":
		var look: Node3D = CropLook.build(crop, stage, float(_structure_by_state(int(rec["state"])).get("footprint_x", 1.0)))
		(rec["node"] as Node3D).add_child(look)
		rec["crop_node"] = look


func press_e() -> bool:
	# In the crafting window, E over a recipe crafts it, as many as the quantity box says (Dave 2026-10-23; BUG-025, 4 Nov: a quantity of 20 made only 1).
	if open and not chest_mode and _hover_recipe != 0:
		if _can_craft(_hover_recipe):
			_start_craft(_hover_recipe, _recipe_part.chosen_quantity())
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
	if _e_active.is_empty() or not KeyBindings.held("interact"):
		return

	if Time.get_ticks_msec() - _e_start_msec < int(HOLD_E_S * 1000.0):
		return

	var found: Dictionary = _e_active
	_e_active = {}
	found["hold"].call()


# What E will do at a fire (Dave 2 Nov 2026): burning -> put out, loaded -> light, empty -> nothing (F puts wood in); hold E picks up a fire that is not burning.
func _fire_prompt(state: int) -> String:
	if state == 8:
		return "Press F to add wood (hold E to pick it up)"

	if state == StructureLook.FIRE_COALS:
		return "Glowing coals: press F to add wood, it catches by itself (hold E to pick it up)"

	if state == StructureLook.FIRE_ASH:
		return "Warm ash: press E to light with tinder and wood (hold E to pick it up, F for wood)"

	if state == 9:
		return "Press E to light (hold E to pick it up, F for wood)"

	return "Press E to put out (F for wood and food)"


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

		if (is_station or _is_chest(state) or state == 11 or state == 12 or _lit_state(state) or StructureLook.is_unlit_fire(state)) and here.distance_to(_world[id]["pos"]) <= best_d:
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

	var best_def: Dictionary = _structure_by_state(int(_world[best]["state"]))

	if str(best_def.get("use", "")) == "smelt":   # a Smelter: its store (hopper, input, rack); it crafts nothing
		_ask_open(best)
		return true

	if str(best_def.get("station", "")) != "" and int(best_def.get("out_slots", 0)) > 0:   # a station with a store: its window, on the Craft tab (the Kiln: on its store)
		_ask_open(best, str(best_def.get("use", "")) != "kiln")
		return true

	if str(best_def.get("station", "")) != "":
		_open_station()
		return true

	_ask_open(best)
	return true


# A workbench or forge has no slots of its own: using it opens the crafting screen, which greys what the station cannot make.
func _open_station() -> void:
	if not open:
		toggle()


# The pack slot in the right hand (-1 for empty hands or no client wired, as in tests): what a tool use at a station sends.
func _hand_slot() -> int:
	return int(held_slot_now.call()) if held_slot_now.is_valid() else -1


# E on the chopping block the cursor is on: split a log there, nothing else (the wood lying around stays where it is).
func _use_block(id: int) -> void:
	net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, _hand_slot() + 1, Vector3.ZERO)   # count: the axe in hand (protocol 117)
	_block_next_msec = Time.get_ticks_msec() + 600


# True when something lay within reach and the server was asked for it.
func pick_up_nearest() -> bool:
	var id: int = _nearest()[0]

	if id == 0:
		id = _nearest_struct()

	if id == 0:
		return false

	if _world[id]["state"] == 7 and not Input.is_key_pressed(KEY_SHIFT):   # before the chest test: the chopping block has a store now (master s2.4)
		net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, _hand_slot() + 1, Vector3.ZERO)   # count: the axe in hand (protocol 117)
		_block_next_msec = Time.get_ticks_msec() + 600
		return true

	if _is_chest(int(_world[id]["state"])) and not Input.is_key_pressed(KEY_SHIFT):
		_ask_open(id)
		return true

	pick_stamp = Time.get_ticks_msec()

	if gather_event.is_valid():
		gather_event.call()

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
	_flicker_flames()

	if not _warm_queue.is_empty():
		var tw: int = FrameProbe.start()
		_warm_step()
		FrameProbe.stop("inventory: loose mesh prewarm", tw)

	var t: int = FrameProbe.start()
	_drain_world_backlog()
	FrameProbe.stop("inventory: world items", t)   # the pieces of a 65 ms "inventory view" in the 5 Nov lag run's one HITCH
	var now: int = Time.get_ticks_msec()
	t = FrameProbe.start()
	_roll_tick(_delta, now)
	_glide_tick(_delta)
	_snap_tick(now)
	_hold_e_check()
	_auto_pickup_tick(now)
	FrameProbe.stop("inventory: roll, snap, hold E, pickup", t)

	if _thought_label != null and _thought_label.text != "" and now >= _thought_until_msec:
		_thought_label.text = ""

	if _strain_note != null:
		_strain_note.text = ("Exhausted: you sleep until you are rested, about %d min left%s" % [maxi(int(ceil(float(sleep_eta_s) / 60.0)), 1), "; hold Space to wake early" if energy >= 30 else " (hold Space to wake early once energy is 30 percent)"]) if forced_sleep else "Asleep: any key wakes you" if asleep else ("You are exhausted: slow down" if strain_state == 1 else "")

	if _queue_head_button != null and now >= _queue_next_msec:
		_queue_next_msec = now + 250
		_queue_head_button.text = _queue_part.queue_text(0)

	if now < _prompt_next_msec:
		return

	_prompt_next_msec = now + 200
	t = FrameProbe.start()
	_update_fire_lights()
	FrameProbe.stop("inventory: fire lights", t)
	t = FrameProbe.start()
	_update_trunk_colliders()
	FrameProbe.stop("inventory: trunk colliders", t)

	if now < _notice_until_msec:
		return
	t = FrameProbe.start()
	var interaction: Dictionary = current_interaction()
	_prompt.text = prompt_text(interaction)
	if _site_list != null:
		_site_list.text = str(interaction.get("lines", "")) if _prompt.text != "" else ""
		_site_list.visible = _site_list.text != ""
	FrameProbe.stop("inventory: prompt", t)

	if _prompt.text == "" and stance_confirmed == 3 and not asleep and strain_state < 2:
		_prompt.text = KeyBindings.localize("Hold Z to sleep")


# P (terrain_client.gd): auto pickup on or off, announced slightly above the middle of the screen.
var auto_pickup: RefCounted
var auto_pickup_blocked: Callable = Callable()   # () -> true while swimming or placing a blueprint (set by the terrain client)
var _auto_label: Label


func toggle_auto_pickup() -> void:
	_auto_label.text = auto_pickup.toggle(Time.get_ticks_msec())


func _auto_pickup_tick(now: int) -> void:
	if _auto_label != null and _auto_label.text != "":
		var left: int = auto_pickup.announce_until_msec - now
		_auto_label.self_modulate.a = clampf(float(left) / 500.0, 0.0, 1.0)

		if left <= 0:
			_auto_label.text = ""

	if not auto_pickup.enabled or asleep or screen_open() or now - _death_msec < 6000 or (auto_pickup_blocked.is_valid() and bool(auto_pickup_blocked.call())):
		return

	if not auto_pickup.due(now):
		return   # not this frame: skips the cursor check, hashing the whole pack and reading the player position every frame

	if cursor_kind() != "":
		return   # the cursor is on something specific: auto pickup stays out of it (case 3 only)

	var id: int = auto_pickup.next_pick(_world, _player_position.call(), Interact.reach_m(), now, hash(inventory.counts), in_view)

	if id != 0:
		net.inventory_action.rpc_id(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)


# Holding E beside a chopping block used to keep splitting logs. Now a hold picks the block up (Dave 2 Nov 2026), so there is nothing to repeat here.
func hold_use() -> bool:
	return false


# The id of the placed structure (lean-to, chest) within 3 m that the cursor is on, else the nearest one; 0 when none.
func _nearest_struct(skip_fires: bool = false) -> int:
	var here: Vector3 = _player_position.call()
	var ids: Array = []

	for id in _world:
		if skip_fires and int(_world[id]["state"]) in StructureLook.CAMPFIRE_STATES:
			continue

		if _world[id]["state"] >= 5 and _world[id]["state"] != 32 and here.distance_to(_world[id]["pos"]) <= 3.0:
			ids.append(id)

	return _aimed_or_nearest(_unframed(ids), here)


# A doorway frame with a door in it shares the door's spot: the door is the one E works (the frame is taken down after the door).
func _unframed(ids: Array) -> Array:
	var out: Array = []

	for id in ids:
		var def: Dictionary = _structure_by_state(int(_world[id]["state"]))
		var holds_door: bool = false

		if str(def.get("opening", "")) != "" and str(def.get("piece_kind", "")) != "door":
			for other in ids:
				holds_door = holds_door or (str(_structure_by_state(int(_world[other]["state"])).get("piece_kind", "")) == "door" and (_world[other]["pos"] as Vector3).distance_to(_world[id]["pos"]) < PlacementRules.DOOR_TAKEN_M)

		if not holds_door:
			out.append(id)

	return out


# Of some world ids: the best centred one when the cursor is on any of them, otherwise the nearest; 0 for none.
func _aimed_or_nearest(ids: Array, here: Vector3) -> int:
	var best: int = 0
	var best_d: float = 1.0e9
	var best_cos: float = -2.0

	for id in ids:
		var d: float = here.distance_to(_world[id]["pos"])

		if view_direction.is_valid() and aimed_at(_world[id]["pos"]):
			var aim_cos: float = aim_cos_of(_world[id]["pos"])

			if aim_cos > best_cos:
				best_cos = aim_cos
				best = id

		elif best_cos < -1.0 and d < best_d:
			best_d = d
			best = id

	return best


# The id of the fire (lit or out) within 3 m that the cursor is on, else the nearest one; 0 when none.
func _nearest_fire() -> int:
	var here: Vector3 = _player_position.call()
	var ids: Array = []

	for id in _world:
		if _world[id]["state"] in StructureLook.CAMPFIRE_STATES and here.distance_to(_world[id]["pos"]) <= 3.0:
			ids.append(id)

	return _aimed_or_nearest(ids, here)


func pick_up_fire() -> void:
	var fire: int = _nearest_fire()

	if fire != 0:
		clear_prompt()
		net.inventory_action.rpc_id(1, Net.ACT_PICKUP, fire, 0, 0, Vector3.ZERO)


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

		# The distance first: only the few items within 1.5 m pay for the item table lookups (this runs over every loose item on each blow that lands).
		if entry["pos"].distance_squared_to(point) >= 2.25:
			continue

		var item_id: String = table.id_of(int(entry["number"]))

		if item_id == "log" or str(table.entry(item_id).get("carry", "")) == "shoulder":
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


# Condition of the item in a slot: 1.0 new down to 0.0 broken, against its current maximum durability (the instance's max_d, else the row's);
# 1.0 for items that do not wear.
func condition(slot: int) -> float:
	var durability: int = inventory.max_durability(slot)
	return 1.0 if durability <= 0 else clampf(1.0 - float(inventory.wear[slot]) / float(durability), 0.0, 1.0)


func is_broken(slot: int) -> bool:
	return inventory.numbers[slot] != 0 and inventory.max_durability(slot) > 0 and condition(slot) <= 0.0


# Is a tool of this class in a hotbar slot, the way the server checks it?
func has_tool_class(tool_class: String) -> bool:
	for slot in range(inventory.slot_count):
		if inventory.on_hotbar(slot) and str(table.entry(table.id_of(inventory.numbers[slot])).get("tool_class", "")) == tool_class and not is_broken(slot):
			return true

	return false


func _on_notice(text: String) -> void:
	if notice_event.is_valid():
		notice_event.call(text)

	_prompt.text = KeyBindings.localize(text)

	if _site_list != null:
		_site_list.visible = false
	_notice_until_msec = Time.get_ticks_msec() + 4000


# Trunks are solid, but only the ones near the player keep a collider (cost cap).
func _update_trunk_colliders() -> void:
	var here: Vector3 = _player_position.call()

	for pair in _collide:
		if is_instance_valid(pair[0]):
			pair[1].collision_layer = 1 if pair[0].global_position.distance_to(here) < 40.0 else 0


# A felled trunk (lying along `yaw`, falling over when it first appears) or a stump.
# The bark of a felled trunk or stump: the standing trees' bark shader (src/flora/flora_view.gd) with the species texture and tint, so a lying log is not a flat dark drum (guide, 2026-10-31).
# One Shader shared by every felled trunk, stump and log: a new Shader per call made the GPU compile the same bark shader again on each cut of a fallen tree (the trunk is rebuilt when it
# gets shorter), a lock-up of about 2 s in the windowed game (Dave's bug 6, 2 Nov 2026; the server side of a cut costs under 30 ms with 3000 items).
static var _felled_bark_shader: Shader = null


func _felled_bark(species: String, radius: float, span: float) -> Material:
	var flora_script: GDScript = load("res://src/flora/flora_view.gd")
	var builder_script: GDScript = load("res://src/flora/tree_builder.gd")

	if _felled_bark_shader == null:
		_felled_bark_shader = Shader.new()
		_felled_bark_shader.code = flora_script.BARK_SHADER

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _felled_bark_shader
	var texture: String = "bark"

	if species.contains("birch"):
		texture = "bark_birch"
	elif species.contains("beech") or species.contains("fir"):
		texture = "bark_smooth"

	mat.set_shader_parameter("bark", load("res://assets/trees/%s.png" % texture))
	var tints: Dictionary = builder_script.get_script_constant_map()
	var tint: Color = tints.get("BARK_TINT_" + species.to_upper(), Color(0.46, 0.40, 0.34))

	if not tints.has("BARK_TINT_" + species.to_upper()):   # the species name has no tint constant of its own: softwoods take the brown softwood tint, as the standing conifers do (real game: a felled spruce read cool grey)
		for word in ["pine", "spruce", "larch", "cedar", "hemlock", "cypress", "juniper", "yew", "conifer"]:
			if species.contains(word):
				tint = tints.get("BARK_TINT_SOFT", tint)
				break
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("uv_scale", Vector2(maxf(radius * 4.0, 1.0), maxf(span / 1.6, 1.0)))
	mat.set_shader_parameter("foot_offset", span * 0.5)
	mat.set_shader_parameter("lift", Vector3(3.0, 2.0, 1.3))   # brighter and warmer: standing trunks carry baked warm shading (tree_builder _crown_shading), a plain felled one read cool grey
	return mat


func _make_felled(trunk: bool, extra: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var radius: float = float(extra.get("radius", 0.3))
	var length: float = float(extra.get("length", 8.0))
	var bark: Material = _felled_bark(str(extra.get("species", "")), radius, length if trunk else maxf(radius * 1.2, 0.5))
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

	if trunk and bool(extra.get("keywood", false)) and length > 3.0 * 1.2:   # the next cut line: a pale band round the trunk one log length from the far end
		var cut_at: float = (length - 3.0) / length
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
		band.position = Vector3(0.0, length * 0.5 - 3.0, 0.0)
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
		var circle: Array = extra.get("crown", [])

		if circle.size() >= 3:   # the crown lands: the grass under the whole canopy circle lies flat
			tween.tween_callback(func():
				if crown_landed.is_valid():
					crown_landed.call(Vector3(float(circle[0]), 0.0, float(circle[1])), float(circle[2])))

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
		var entry: Dictionary = _world[id]
		var light = entry["light"]

		if light != null:
			lit.append([here.distance_to(entry["pos"]), light])

	_flame_lights.clear()

	if lit.is_empty():
		return   # no fires or lanterns near: nothing to sort or flicker

	lit.sort_custom(func(a, b): return a[0] < b[0])
	var limit: int = int(max_lights.call()) if max_lights.is_valid() else MAX_FIRE_LIGHTS
	var ticks: float = float(Time.get_ticks_msec())

	for n in lit.size():
		var light: Light3D = lit[n][1]
		light.visible = n < limit

		if light.has_meta("flame_flicker"):
			if light.visible:
				_flame_lights.append(light)   # flickered every frame by _flicker_flames: its flame beats at 9 to 11 Hz, a 200 ms step would alias it
		else:
			light.light_energy = float(light.get_meta("base_energy", 1.4)) * (1.0 + 0.04 * sin(ticks * 0.004 + float(n) * 2.1) + 0.02 * sin(ticks * 0.0091 + float(n)))   # a lantern, coals or fixture: a gentle, slow flicker of a few percent


# The switched-on fire lights flicker with their flame, every frame (BUG-002): the energy and the colour together, a phase of each light's own so no two pulse together.
func _flicker_flames() -> void:
	var seconds: float = float(Time.get_ticks_msec()) * 0.001

	for light in _flame_lights:
		if is_instance_valid(light):
			var swing: float = BuildingLook.flame_flicker(seconds, float((light as Light3D).get_instance_id() % 628) * 0.01)
			(light as Light3D).light_energy = float(light.get_meta("base_energy")) * swing
			(light as Light3D).light_color = BuildingLook.flame_flicker_color(light.get_meta("base_color"), swing)


# Is a fire light that is switched on within `radius` of the point?
func fire_light_near(point: Vector3, radius: float) -> bool:
	for id in _world:
		var light: Light3D = _world[id]["light"]

		if light != null and light.visible and not light.has_meta("ember") and point.distance_to(_world[id]["pos"]) <= radius:   # glowing coals do not stand in for a torch light
			return true

	return false


# The whole pack: at hello, and whenever the pack grows or shrinks (protocol 116), so it is handled like a slot update of every slot.
func _on_full(bytes: PackedByteArray) -> void:
	var was: Array = []

	for slot in inventory.slot_count:
		was.append([inventory.numbers[slot], inventory.wear[slot], is_broken(slot), inventory.max_durability(slot)])

	if not inventory.from_bytes(bytes):
		return

	if _selected >= inventory.slot_count:
		_selected = -1   # the pack gave that slot back

	if _hover >= inventory.slot_count:
		_hover = -1

	for slot in mini(was.size(), inventory.slot_count):
		_tool_cue(slot, int(was[slot][0]), int(was[slot][1]), bool(was[slot][2]), int(was[slot][3]))

	_after_slots()


# Protocol 106: a count byte, 9 bytes per changed slot (slot, u32 number, u16 count, u16 wear), then the instance data of those slots (Inventory.inst_bytes).
const DISPOSABLE_BREAK_WEAR := 10   # one heavy use: rock wear 5 (drops.json tool_wear) x dull_wear_mult 2 (smithing.json)


func _on_slots(bytes: PackedByteArray) -> void:
	var n: int = mini(bytes[0], floori(float(bytes.size() - 1) / 9.0)) if not bytes.is_empty() else 0
	var insts: Dictionary = InventoryScript.inst_from_bytes(bytes, 1 + n * 9)

	for k in n:
		var at: int = 1 + k * 9
		var slot: int = bytes[at]

		if slot < inventory.slot_count:
			var was_broken: bool = is_broken(slot)
			var was_wear: int = inventory.wear[slot]
			var was_number: int = inventory.numbers[slot]
			var was_most: int = inventory.max_durability(slot)
			inventory.numbers[slot] = bytes.decode_u32(at + 1)
			inventory.counts[slot] = bytes.decode_u16(at + 5)
			inventory.wear[slot] = bytes.decode_u16(at + 7)
			inventory.inst[slot] = insts.get(slot, {}) if inventory.numbers[slot] != 0 else {}
			_tool_cue(slot, was_number, was_wear, was_broken, was_most)

	_after_slots()


# The break and repair sounds of a slot that just changed.
func _tool_cue(slot: int, was_number: int, was_wear: int, was_broken: bool, was_most: int) -> void:
	if not tool_event.is_valid():
		return

	if inventory.numbers[slot] == was_number and was_number != 0:
		if is_broken(slot) and not was_broken:
			tool_event.call("broke")
		elif inventory.wear[slot] < was_wear and int(table.entry(table.id_of(was_number)).get("durability", 0)) > 0:
			tool_event.call("repaired")
	elif was_number != 0 and inventory.numbers[slot] == 0 and SmithingRules.disposable(table.entry(table.id_of(was_number))) and was_wear + DISPOSABLE_BREAK_WEAR >= was_most:
		# shortcut: a disposable tool that leaves its slot within one heavy use of its end is taken as broken (the server clears it at zero); dropping one that worn plays the break sound too, revisit if that is heard in play
		tool_event.call("broke")


func _after_slots() -> void:
	_queue_refresh()
	_container_part.refresh()
	_storage_ui.refresh_view()   # the storage window's pack list follows the pack
	refresh_hotbar()


# Slot updates that arrive together (a pickup, a craft, a sale send several) rebuild the window once, at the end of the frame.
var _refresh_queued: bool = false


func _queue_refresh() -> void:
	if _refresh_queued:
		return

	_refresh_queued = true
	_flush_refresh.call_deferred()


func _flush_refresh() -> void:
	_refresh_queued = false
	_refresh()


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

	var kg: float = CarryRules.carried_kg(inventory, table, _carry_cfg)   # the large log is a pack item: its weight is already in

	for at in worn_inst:   # and what the worn bags hold, as the server counts it (catalog Phase 5)
		kg += CarryRules.bag_kg(worn_inst[at], table, _carry_cfg)

	return kg


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


# --- The Handcart (catalog Phase 10, M001-T17; server_carts.gd): the server moves carts, the client draws them gliding to each new place ---
const CART_GRAB := 0      # ACT_CART b values (server_carts.gd OP_*)
const CART_RELEASE := 1
const CART_LOAD := 2
const CART_UNLOAD := 3
const GLIDE_RATE := 10.0  # per second: a moved cart covers most of the way to its new place within a fifth of a second (the server's move rate)
var pulling_id: int = 0          # cart_pull: the cart this player holds the handle of, 0 none
var pull_pace_mps: float = 0.0   # and its pace: the walk is capped there (terrain_client)
var _gliding: Dictionary = {}    # world id -> true while its node is still on the way to its place


# True when a cart stands within 3 m of the point (a crate there can be lifted onto it).
func _cart_near(at: Vector3) -> bool:
	for id in _world:
		if _structure_by_state(int(_world[id].get("state", -1))).has("vehicle") and (_world[id]["pos"] as Vector3).distance_to(at) <= 3.0:
			return true

	return false


func _on_items_moved(ids: PackedInt32Array, positions: PackedVector3Array, yaws: PackedFloat32Array) -> void:
	for i in mini(ids.size(), mini(positions.size(), yaws.size())):
		if _world.has(ids[i]):
			_glide(ids[i], positions[i], yaws[i])


func _glide(id: int, to: Vector3, yaw_deg: float) -> void:
	_world[id]["pos"] = to
	_world[id]["yaw"] = yaw_deg
	_gliding[id] = true


func _glide_tick(delta: float) -> void:
	for id in _gliding.keys():
		if not _world.has(id) or not (_world[id].get("node") is Node3D):
			_gliding.erase(id)
			continue

		var node: Node3D = _world[id]["node"]
		var share: float = clampf(delta * GLIDE_RATE, 0.0, 1.0)
		node.position = node.position.lerp(_world[id]["pos"], share)
		node.rotation.y = lerp_angle(node.rotation.y, deg_to_rad(float(_world[id]["yaw"])), share)

		if node.position.distance_to(_world[id]["pos"]) < 0.01:
			node.position = _world[id]["pos"]
			_gliding.erase(id)


# The purse as words, richest coin first: "2 silver, 3 bronze, 4 copper" (copper = items.json value unit; Dave, playtest 12 Nov 2026 TEST-002:
# highest to lowest, left to right, everywhere, as the server's _coin_words). Used where only text fits (tooltips, notices); windows draw
# coin icons instead (fill_coin_line).
func coin_text(copper: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var left: int = copper
	var rows: Array = _coins_cfg.get("ladder", []).duplicate()

	rows.sort_custom(func(x, y): return int(x["copper"]) > int(y["copper"]))

	for row in rows:
		var each: int = maxi(int(row["copper"]), 1)

		if left >= each:
			@warning_ignore("integer_division")
			parts.append("%d %s" % [left / each, str(row["name"])])
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
# richest coin first (gold, silver, bronze, copper, left to right; TEST-002). A zero amount reads "nothing".
func fill_coin_line(label: RichTextLabel, segments: Array) -> void:
	label.clear()
	var px: int = int(label.get_meta("px", 24))
	var rows: Array = _coins_cfg.get("ladder", []).duplicate()
	rows.sort_custom(func(x, y): return int(x["copper"]) > int(y["copper"]))

	for segment in segments:
		if typeof(segment) == TYPE_STRING:
			label.add_text(segment)
			continue

		var left: int = int(segment)
		var amounts: Array = []

		for row in rows.duplicate():
			amounts.append([row, 0])

		for n in amounts.size():
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
		_carry_bar.get_theme_stylebox("fill").bg_color = InventoryLook.carry_color(fraction)


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


# On or within range_m (3 m) of a trodden path (Dave 3 Nov 2026): the pace factor for a gait ("walk" or "run") at a ground position, from data/path_speed.json; 1.0 off a path.
func path_pace_factor(pos: Vector3, gait: String) -> float:
	if _path_cells.is_empty():
		return 1.0

	var reach: int = ceili(float(_path_cfg.get("range_m", 3.0)))
	var cell: Vector2i = Vector2i(floori(pos.x), floori(pos.z))

	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			if int(_path_cells.get(Vector2i(cell.x + dx, cell.y + dz), 0)) > 0:
				return float(_path_cfg.get("%s_factor" % gait, 1.0))

	return 1.0


func _path_cell_add(pos: Vector3, amount: int) -> void:
	var cell: Vector2i = Vector2i(floori(pos.x), floori(pos.z))
	var now: int = int(_path_cells.get(cell, 0)) + amount

	if now > 0:
		_path_cells[cell] = now
	else:
		_path_cells.erase(cell)


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

	if _vitals_seen and health - new_health >= HURT_MIN and hurt_event.is_valid():
		hurt_event.call(health - new_health)

	_vitals_seen = true
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
	if slot < 0 or slot >= inventory.slot_count or inventory.numbers[slot] == 0:
		return 0

	return int(table.entry(table.id_of(inventory.numbers[slot])).get("capacity_ml", 0))


# The pack slot of the container in hand, or -1.
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
	return slot >= 0 and slot < inventory.slot_count and inventory.numbers[slot] != 0 and VitalsRules.edible(table.id_of(inventory.numbers[slot]), _vitals_cfg)


# Is this item number food, a drink or medicine by the vitals rules the server uses too (data/items/vitals.json)?
func is_edible_item(number: int) -> bool:
	return number > 0 and VitalsRules.edible(table.id_of(number), _vitals_cfg)


func equippable_slot(slot: int) -> bool:
	if slot < 0 or slot >= inventory.slot_count or inventory.numbers[slot] == 0:
		return false

	var entry: Dictionary = table.entry(table.id_of(inventory.numbers[slot]))
	return entry.has("tool_class") or entry.has("weapon_class") or str(entry.get("kind", "")) in ["tool", "weapon", "placeable", "container", "blueprint"]


# Hold a tool: one already in a hotbar slot is held by that key; one in the backpack first moves into the first empty hotbar slot (the
# hotbar is real slots, Dave's playtest 12 Nov 2026 TEST-008). With every hotbar slot taken it swaps with the key in hand (or key 0), so using
# a tool from deep in a full pack always works (moderator, 31 Oct 2026).
func equip_with_move(slot: int) -> void:
	if slot < 0 or slot >= inventory.slot_count or inventory.numbers[slot] == 0:
		return

	var key: int = slot

	if not inventory.on_hotbar(slot):
		key = inventory.numbers.slice(0, inventory.hotbar_slots).find(0)

		if key < 0:
			var in_hand: int = int(held_key_now.call()) if held_key_now.is_valid() else -1
			key = in_hand if in_hand >= 0 else HeldItem.HOTBAR_SLOTS - 1
			_on_notice("Hotbar full: key %s now holds it." % ("0" if key == 9 else str(key + 1)))

		var resting: bool = held_key_now.is_valid() and int(held_key_now.call()) == key
		move_slot(slot, key)
		inventory.move(slot, key)   # shown at once; the server's inventory_slots confirm it
		refresh_hotbar()

		# The hand may already rest on that key: then the tool is simply in hand, not toggled away.
		if resting:
			return

	equip_requested.call(key)


# Move a stack to another pack slot (dragging, or Use on a tool).
func move_slot(from_slot: int, to_slot: int) -> void:
	var last: int = inventory.slot_count if inventory.grows else inventory.slot_count - 1   # a full pack takes a move to just past its end (free_bag_slot)

	if from_slot == to_slot or from_slot < 0 or to_slot < 0 or from_slot >= inventory.slot_count or to_slot > last:
		return

	net.inventory_action.rpc_id(1, Net.ACT_MOVE, from_slot, to_slot, 0, Vector3.ZERO)
	_selected = -1


# E over a hotbar key (inventory open) moves its stack into the first empty backpack slot.
var hotbar_hover: int = -1
var held_key_now: Callable = Callable()      # () -> the hotbar key the right hand holds (0 to 9), -1 for empty hands; set by the client


func hotbar_to_pack(key: int) -> void:
	if key_slot(key) < 0:
		return

	var free: int = inventory.free_bag_slot()

	if free < 0:
		_on_notice("Your backpack is full.")
		return

	move_slot(key, free)


# The item in a hotbar key's slot, 0 for an empty one.
func key_number(key: int) -> int:
	return inventory.numbers[key] if key_slot(key) >= 0 else 0


# The pack slot of a hotbar key (keys 1 to 9 and 0 are slots 0 to 9), -1 when it is empty.
func key_slot(key: int) -> int:
	return inventory.key_slot(key) if inventory != null else -1


func refresh_hotbar() -> void:
	if hotbar_strip != null:
		hotbar_strip.refresh()


func hotbar_tip(key: int) -> String:
	var slot: int = key_slot(key)
	var key_name: String = "0" if key == 9 else str(key + 1)

	if slot >= 0:
		return _tooltip(inventory.numbers[slot], inventory.counts[slot], inventory.wear[slot], inventory.inst_of(slot)) + ("\nKeys: Use (E) moves it to the backpack" if open else "")

	return "Drag an item here from the inventory. Key %s holds it." % key_name


# Eat the food or apply the medicine in a pack slot. Herbs that look like something else must be identified first.
func eat_slot(slot: int) -> void:
	# Use on clothing or a pack puts it on.
	if slot >= 0 and slot < inventory.slot_count and inventory.numbers[slot] != 0 and clothing_slots().has(str(table.entry(table.id_of(inventory.numbers[slot])).get("slot", "-"))):
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
		_on_notice("You are not sure what %s really is. Hover it in inspection mode (/) before you use it." % table.sentence_name(number))
		return

	_eat_item = table.id_of(number)
	net.inventory_action.rpc_id(1, Net.ACT_EAT, slot, 0, 0, Vector3.ZERO)


# Asks the server to open a container. The server also pushes fresh contents while it is open (a fire eating wood); a push that arrives when
# no window is open and none was asked for in the last 2 s is ignored, so closing the window is not undone.
var _open_asked_msec: int = -100000
var _craft_first: bool = false   # the window being asked for is a station's: it opens on the Craft tab, its store one tab away


# A station store's row (master s2.5): its fill (server_items._store_fill) and, for a Kiln, whether it burns; kept when the row is sent again.
func _note_store(id: int, row: Array) -> void:
	if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("fill"):
		_world[id]["fill"] = int(row[5]["fill"])
		_world[id]["lit"] = bool(row[5].get("lit", false))


# A station store's fill for the look-at line (server_items._store_fill: 0 empty, 1 to 4 quarters), "" for anything else.
func _fill_note(id: int) -> String:
	if not _world.has(id) or not _world[id].has("fill"):
		return ""

	return " (%s)" % ["empty", "a quarter full", "half full", "three quarters full", "full"][clampi(int(_world[id]["fill"]), 0, 4)]


func _ask_open(id: int, craft_first: bool = false) -> void:
	_open_asked_msec = Time.get_ticks_msec()
	_craft_first = craft_first
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
		_panel.visible = true      # one window, the container in its Craft column (4.4)
		chest_tab = not _craft_first
		_craft_first = false
		_container_part.build()
		_show_tab()

		if _you_part != null:
			_you_part.set_active(true)

		_refresh()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		if chest_event.is_valid() and _world.has(id):
			chest_event.call("open", _world[id]["pos"])

	_container_part.refresh()


func _close_chest() -> void:
	net.inventory_action.rpc_id(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)

	if chest_event.is_valid() and _world.has(chest_id):
		chest_event.call("close", _world[chest_id]["pos"])

	chest_mode = false
	open = false
	_show_tab()

	if _you_part != null:
		_you_part.set_active(false)

	if _panel != null:
		_panel.visible = false

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Kept on the view for the tests: _container_part.is_fire (src/client/ui/inventory/container_panel.gd).
func _chest_is_fire() -> bool:
	return _container_part.is_fire()


# Kept on the view for the tests: _container_part.pack_slot (src/client/ui/inventory/container_panel.gd).
func _pack_slot(index: int) -> int:
	return _container_part.pack_slot(index)


# Kept on the view for the tests: _container_part.pack_view_slots (src/client/ui/inventory/container_panel.gd).
func _pack_view_slots(fire: bool) -> Array:
	return _container_part.pack_view_slots(fire)


# Kept on the view for the tests: _container_part.fire_takes (src/client/ui/inventory/container_panel.gd).
func fire_takes(item_id: String) -> bool:
	return _container_part.fire_takes(item_id)


# Finds a hitch (Dave's bug 6, 2 Nov 2026: "every time I cut a log off it pauses"): a message handler that takes over 20 ms prints one line, so the cause shows in the client log.
# `client slow: world_items took 120 ms`. Cheap: one clock read either side.
func _timed(label: String, handler: Callable, args: Array) -> void:
	var t0: int = Time.get_ticks_usec()
	handler.callv(args)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0

	if ms > 20.0:
		print("client slow: %s took %.0f ms" % [label, ms])

# Join stall (Dave 2 Nov 2026 log: "world items 1423 ms for 334 added"): a big list of world items was dressed in one frame. A list of more
# than WORLD_SLICE_MIN rows (or any list while an earlier one is still waiting, to keep the order) is queued and dressed in _process,
# WORLD_SLICE_USEC a frame (at least one row). Small updates (a log cut, an item dropped) still apply at once.
const WORLD_SLICE_MIN := 24
const WORLD_SLICE_USEC := 4000
var _world_backlog: Array = []        # rows to dress, and PackedInt32Array removals, in arrival order


func _queue_world_items(added: Array, removed: PackedInt32Array) -> void:
	if added.size() <= WORLD_SLICE_MIN and _world_backlog.is_empty():
		_on_world_items(added, removed)
		return

	for row in added:
		_world_backlog.append(row)

	if removed.size() > 0:
		_world_backlog.append(removed)


func _drain_world_backlog() -> void:
	if _world_backlog.is_empty():
		return

	var started: int = Time.get_ticks_usec()
	var done: int = 0

	while done < _world_backlog.size():
		var entry: Variant = _world_backlog[done]
		done += 1

		if entry is PackedInt32Array:
			_on_world_items([], entry)
		else:
			_on_world_items([entry], PackedInt32Array())

		if Time.get_ticks_usec() - started >= WORLD_SLICE_USEC:
			break

	_world_backlog = _world_backlog.slice(done)


func _on_world_items(added: Array, removed: PackedInt32Array) -> void:
	var prof: Dictionary = {}   # section -> microseconds (bug 6, 2 Nov 2026: _on_world_items took 939 ms on a log cut; the breakdown line below says where)
	var t_all: int = Time.get_ticks_usec()
	_slowest_row_usec = 0
	_slowest_row = ""
	var t_mark: int = t_all

	_forget_near()   # stations and logs may have come or gone

	for id in removed:
		_forget(id)

	prof["forget"] = Time.get_ticks_usec() - t_mark
	t_mark = Time.get_ticks_usec()

	var row_usec: int = 0
	var row_name: String = ""

	for row in added:
		# The slowest row, whatever path it takes (lag run 5 Nov: 44 ms for 1 added, none of it in the timed parts).
		_note_slowest_row(row_usec, row_name)
		row_usec = Time.get_ticks_usec()
		row_name = "%s state %d" % [table.id_of(int(row[1])), int(row[4]) if row.size() > 4 else 0]
		var id: int = row[0]
		var state: int = int(row[4]) if row.size() > 4 else 0

		if state == BOULDER_STATE:
			_show_boulder(id, row)
			continue

		if state == BOG_STATE:
			_note_bog(id, row)
			continue

		if _world.has(id):
			_world[id]["count"] = row[2]
			var t_a: int = Time.get_ticks_usec()
			_refresh_pile(id)
			prof["pile"] = int(prof.get("pile", 0)) + Time.get_ticks_usec() - t_a

			if int(_world[id]["state"]) == 0 and state == 0 and (row[3] as Vector3).distance_to(_world[id]["pos"]) > 0.05:
				_world[id]["pos"] = row[3]      # the server let it down onto the ground (after a dig): draw it there
				(_world[id]["node"] as Node3D).position = row[3] + Vector3(0.0, 0.12, 0.0)
				var t_b: int = Time.get_ticks_usec()
				_snap_loose(id)
				prof["snap"] = int(prof.get("snap", 0)) + Time.get_ticks_usec() - t_b

			if _world[id]["state"] == state and state >= 5 and row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("yaw"):
				_world[id]["on"] = bool(row[5].get("on", false))   # a crate lifted onto a cart or set down

				if (row[3] as Vector3).distance_to(_world[id]["pos"]) > 0.05:
					_glide(id, row[3], float(row[5]["yaw"]))   # a cart or a crate on it moved (the world sync after items_moved, or instead of a lost one)

			if _world[id]["state"] == state:
				if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("burn"):
					_world[id]["burn"] = float(row[5]["burn"])
					_world[id]["burn_at"] = Time.get_ticks_msec()

				if state == StructureLook.FIRE_COALS and _world[id].get("light") != null and row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("glow"):
					BuildingLook.coals_glow(_world[id]["light"], float(row[5]["glow"]))   # the coals dim as their time runs down

				_note_platter(id, row, state)
				_note_store(id, row)
				_note_crop(id, row)
				var shorter: bool = is_felled_state(state) and row.size() > 5 and absf(float((row[5] as Dictionary).get("length", 0.0)) - float((_world[id].get("extra", {}) as Dictionary).get("length", 0.0))) > 0.01

				var site_now: Variant = (row[5] as Dictionary).get("site") if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else null
				var site_was: Variant = _world[id].get("site")

				if site_now != null and site_was != null:
					_world[id]["site"] = site_now   # a deposit or a change in what you have to hand: the list updates, the blue piece stays
					continue

				if (site_now != null) != (site_was != null):
					shorter = true   # a site finished (drawn again as the real piece) or a piece that became a site

				if not shorter:
					continue

			_forget(id)   # a changed state, or a felled trunk with a log cut off: draw it again

		var node: Node3D
		var light: OmniLight3D = null

		if state >= 5 and not StructureLook.is_unlit_fire(state) and not _lit_state(state):   # 8 is a burnt-out fire, 9 a loaded one, 76 coals, 77 warm ash: the campfire model without flames
			var yaw: float = deg_to_rad(float(row[5].get("yaw", 0.0))) if row.size() > 5 else 0.0
			var t_c: int = Time.get_ticks_usec()
			node = _model_for_state(state, row[5] if row.size() > 5 else {})
			prof["model"] = int(prof.get("model", 0)) + Time.get_ticks_usec() - t_c
			node.position = row[3] - Vector3(0.0, SINK_M * float(row[5].get("age", 0.0)), 0.0) if (state == 11 or state == 12) and row.size() > 5 else row[3]
			node.rotation.y = yaw
			_root.add_child(node)
			var roof_key: int = -1
			var site_extra: Variant = (row[5] as Dictionary).get("site") if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else null

			if site_extra != null:
				_make_site_look(node)
			elif cover_index != null:
				# Any structure with a roof in structures.json (the lean-to, every tier's roof piece): the same box the server rules on (Cover.structure_roof).
				var roof_box: Array = CoverScript.structure_roof(_structure_by_state(state), row[3], yaw)

				if not roof_box.is_empty():
					roof_key = cover_index.add_roof(roof_box)

			var fixture_light: Light3D = null

			if row.size() > 5 and bool((row[5] as Dictionary).get("lit", false)):
				var fixture: Node3D = BuildingLook.lit_fixture(StructureLook.look_of(state))
				node.add_child(fixture)
				fixture_light = fixture.get_node_or_null("Light")
				var light_m: float = float(_structure_by_state(state).get("light_m", 0.0))   # structures.json light_m: the reach of its light (buildables plan, batch B4)

				if light_m > 0.0 and fixture_light is OmniLight3D:
					(fixture_light as OmniLight3D).omni_range = light_m
				elif light_m > 0.0 and fixture_light is SpotLight3D:
					(fixture_light as SpotLight3D).spot_range = light_m

			_world[id] = {"node": node, "number": row[1], "count": 1, "pos": row[3], "state": state, "light": fixture_light, "roof": roof_key, "yaw": rad_to_deg(yaw), "on": row.size() > 5 and bool((row[5] as Dictionary).get("on", false))}

			if site_extra != null:
				_world[id]["site"] = site_extra

			if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("wheel"):
				_world[id]["wheel"] = int(row[5]["wheel"])   # a sawmill's water wheel share in percent (server_items.wheel_percent)

			_note_store(id, row)

			_note_platter(id, row, state)
			_note_crop(id, row)

			if site_extra != null:
				pass   # a site is walked through and climbed by nobody until it is finished
			elif StructureLook.look_of(state) == "ladder":
				ladders[id] = {"pos": row[3], "yaw": rad_to_deg(yaw)}
			elif StructureLook.look_of(state) == "trodden_path":
				_path_cell_add(row[3], 1)

			continue

		if is_felled_state(state):   # only 3 (a trunk) and 4 (a stump): a loaded or burnt-out fire (8, 9) is NOT one, it was drawn as a stump (Dave, build 826)
			var extra: Dictionary = row[5] if row.size() > 5 else {}
			var felled_t0: int = Time.get_ticks_usec()
			node = _make_felled(state == 3, extra)
			prof["felled"] = int(prof.get("felled", 0)) + Time.get_ticks_usec() - felled_t0
			node.position = row[3]
			_root.add_child(node)
			_world[id] = {"node": node, "number": 0, "count": 1, "pos": row[3], "state": state, "light": null, "extra": extra}
			continue

		var t_d: int = Time.get_ticks_usec()

		if state == 0:
			var box: MeshInstance3D = MeshInstance3D.new()
			var real: Mesh = _natural_mesh(int(row[1]), int(row[0]))
			box.mesh = real if real != null else _mesh_for(row[1])
			node = box
			node.position = row[3] + Vector3(0.0, 0.12, 0.0)
			_dress_item(node, int(row[1]), int(row[0]), real != null)

			if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("rot_y"):   # a split log lies along the trunk it came from
				node.rotation.y = float(row[5]["rot_y"])

			if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("girth"):   # a split log is as thick as the trunk it came from (the mesh lies along x)
				var girth: float = float(row[5]["girth"])
				node.scale = Vector3(node.scale.x, node.scale.y * girth, node.scale.z * girth)

			if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("tilt"):   # an arrow stuck in a tree (Dave 10 Nov 2026)
				node.rotation = Vector3(0.0, float(row[5].get("rot_y", 0.0)), float(row[5]["tilt"]))
				node.position = row[3] - Basis.from_euler(node.rotation).x * STUCK_ARROW_BACK_M * node.scale.x   # the model lies along x, its point at +x
		else:
			var fire_extra: Dictionary = row[5] if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else {}
			node = BuildingLook.coals_fire(float(fire_extra.get("glow", 1.0))) if state == StructureLook.FIRE_COALS else _make_fire(_lit_state(state), state == 9, _fire_tier(state))
			node.position = row[3]
			light = node.get_node_or_null("Light")

		if light == null:
			light = node.get_node_or_null("Light")   # the forges glow

		_root.add_child(node)
		_world[id] = {"node": node, "number": row[1], "count": row[2], "pos": row[3], "state": state, "light": light}

		if state != 0 and row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("burn"):   # a fire: the burn time left (the label counts it down while it burns)
			_world[id]["burn"] = float(row[5]["burn"])
			_world[id]["burn_at"] = Time.get_ticks_msec()

		prof["loose_mesh"] = int(prof.get("loose_mesh", 0)) + Time.get_ticks_usec() - t_d
		var t_e: int = Time.get_ticks_usec()
		_refresh_pile(id)
		prof["pile"] = int(prof.get("pile", 0)) + Time.get_ticks_usec() - t_e
		t_e = Time.get_ticks_usec()
		_snap_loose(id)
		prof["snap"] = int(prof.get("snap", 0)) + Time.get_ticks_usec() - t_e

	_note_slowest_row(row_usec, row_name)
	var total_ms: float = float(Time.get_ticks_usec() - t_all) / 1000.0

	if total_ms > 30.0:
		var parts: Array = []

		for key in prof:
			parts.append("%s %.0f ms" % [key, float(prof[key]) / 1000.0])

		print("client slow: world items %.0f ms for %d added, %d removed: %s (slowest row: %s, %.0f ms)" % [total_ms, added.size(), removed.size(), ", ".join(parts), _slowest_row, float(_slowest_row_usec) / 1000.0])


var _slowest_row_usec: int = 0   # the slowest added row of the last world-items list, and what it was (the slow line)
var _slowest_row: String = ""


func _note_slowest_row(since_usec: int, row_name: String) -> void:
	if since_usec == 0:
		return

	var spent: int = Time.get_ticks_usec() - since_usec

	if spent > _slowest_row_usec:
		_slowest_row_usec = spent
		_slowest_row = row_name


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

	var on_fire: bool = _lit_state(int(entry.get("state", 0))) or StructureLook.is_unlit_fire(int(entry.get("state", 0)))   # a fire rests on the drawn ground too (it hung about a metre up where the drawn ground sits under the server's height field, Dave 2 Nov)

	if entry.is_empty() or (int(entry.get("state", 0)) != 0 and not on_fire) or not _ground_below.is_valid() or _rolling.has(id):
		_unsnapped.erase(id)
		return

	var at: Vector3 = entry["pos"]
	var ground: float = float(_ground_below.call(at - Vector3(0.0, 1.5, 0.0)))      # the probe starts 2 m above its point: 0.5 m above the item, so a tunnel roof is not hit

	if is_nan(ground) or ground > at.y + SNAP_UP_M or ground < at.y - SNAP_DOWN_M:
		_unsnapped[id] = tries - 1 if tries > 1 else 0
		return

	_unsnapped[id] = tries - 1
	var node: Node3D = entry["node"]
	node.position = Vector3(at.x, ground + (0.02 if on_fire else 0.12), at.z)


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


# The world id of the placed structure nearest `point` within `reach` metres, or 0 (the hammer's Repair mode aims with it).
func structure_id_near(point: Vector3, reach: float = 3.5) -> int:
	var best: int = 0
	var best_d: float = reach

	for id in _world:
		if _world[id].has("yaw") and int(_world[id]["state"]) >= 5:
			var d: float = (_world[id]["pos"] as Vector3).distance_to(point)

			if d <= best_d:
				best_d = d
				best = int(id)

	return best


# Every structure standing as {"pos", "state", "yaw" (degrees), "piece"}, for the hammer's "Save building plan".
func structure_rows() -> Array:
	var rows: Array = []

	for id in _world:
		if _world[id].has("yaw") and int(_world[id]["state"]) >= 5:
			var def: Dictionary = _structure_by_state(int(_world[id]["state"]))
			rows.append({"pos": _world[id]["pos"], "state": int(_world[id]["state"]), "yaw": float(_world[id]["yaw"]), "piece": bool(def.get("piece", false))})

	return rows


# Fires and structures standing in the world as {"pos", "state"} rows, for the placement ghost's blocked check.
func foundation_rows() -> Array:
	var rows: Array = []

	for id in _world:
		var state: int = int(_world[id]["state"])

		if state < 5 or not _world[id].has("yaw"):
			continue

		# Every foundation and building piece of every tier, as the server's _foundation_rows (was states 22 to 28 only: the ghost of a thatch,
		# log, stone or brick piece, or anything on a thatch or wooden foundation, did not snap where the server put it).
		var def: Dictionary = _structure_by_state(state)

		if bool(def.get("foundation", false)) or bool(def.get("piece", false)):
			rows.append({"pos": _world[id]["pos"], "state": state, "yaw": _world[id]["yaw"]})

	return rows


# A placed Serving Platter's row (catalog phase 8): the board on it and the portions left, 0 when empty.
func _note_platter(id: int, row: Array, state: int) -> void:
	if str(_structure_by_state(state).get("use", "")) != "serve":
		return

	var extra: Dictionary = row[5] if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else {}
	_world[id]["board"] = int(extra.get("board", 0))
	_world[id]["portions"] = int(extra.get("portions", 0))


# The table tops a Serving Platter's ghost may snap to: the placed structures of `states` (its attach_kinds) with their turn, as the server's _surface_rows.
func surface_rows(states: Dictionary) -> Array:
	var rows: Array = []

	for id in _world:
		if states.has(int(_world[id]["state"])) and _world[id].has("yaw") and _world[id].get("site") == null:
			rows.append({"pos": _world[id]["pos"], "state": int(_world[id]["state"]), "yaw": float(_world[id]["yaw"])})

	return rows


func placed_rows() -> Array:
	var rows: Array = []

	for id in _world:
		var state: int = int(_world[id]["state"])

		if _lit_state(state) or StructureLook.is_unlit_fire(state) or state == 5 or state == 6 or state == 7 or state == 13 or state == 14 or state == 15 or state == 16 or state == 17 or state == 18 or state == 20 or state == 21 or state == 38:
			rows.append({"pos": _world[id]["pos"], "state": state})

	return rows


# Removes a world row's node and, for a lean-to, its roof in the cover index.
# A bog iron deposit the server says is in sight (Sonny's water rules section 11): its spot, the ore left and its full size, and whether it lies under
# standing water. Kept, not drawn yet: Kathleen's look (_show_bog) builds on this entry and puts its node in "node".
func _note_bog(id: int, row: Array) -> void:
	var extra: Dictionary = row[5] if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else {}
	var entry: Dictionary = bogs.get(id, {})
	entry["pos"] = row[3]
	entry["left"] = int(row[2])
	entry["total"] = maxi(int(extra.get("total", row[2])), 1)
	entry["wet"] = bool(extra.get("wet", false))
	entry["key"] = str(extra.get("key", ""))
	bogs[id] = entry


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
uniform vec3 ore_tint = vec3(0.30, 0.29, 0.27);
uniform float tint_share = 0.0;
uniform vec3 vein_color = vec3(0.0);
uniform float vein_amount = 0.0;
uniform float vein_width = 0.1;
uniform float vein_flat = 0.0;
uniform float halo_share = 0.0;
uniform float fleck_share = 0.0;
uniform vec3 moss_color").replace("\tALBEDO = mix(stone * (0.85 + 0.3 * mottle), moss_color * (0.8 + 0.4 * mottle), moss);", OUTCROP_GLSL)
		_boulder_rock = ShaderMaterial.new()
		_boulder_rock.shader = shader
		_boulder_rock.set_shader_parameter("fade_start", 100000.0)
		_boulder_rock.set_shader_parameter("fade_end", 100001.0)

	var body: StaticBody3D = StaticBody3D.new()
	body.set_meta("boulder", true)   # the look label names it (terrain_client _inspect_target: it showed the soil under it, TEST-013)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	body.add_child(shape)
	var lump: MeshInstance3D = MeshInstance3D.new()
	lump.mesh = _boulder_mesh
	lump.material_override = _boulder_material(str(extra.get("ore", "")))
	body.add_child(lump)
	body.position = row[3]
	body.rotation.y = deg_to_rad(float(extra.get("yaw", 0.0)))
	_root.add_child(body)
	var entry: Dictionary = {"node": body, "shape": shape, "lump": lump, "pos": row[3], "left": left, "total": maxi(int(extra.get("total", left)), 1), "radius": float(extra.get("radius", 0.5))}
	_boulders[id] = entry
	_size_boulder(entry)


# The boulder material for a row's "ore": the plain granite for "" (or an ore with no OUTCROP_LOOK), else that ore's own copy, made once.
func _boulder_material(ore: String) -> ShaderMaterial:
	if not OUTCROP_LOOK.has(ore):
		return _boulder_rock

	if not _outcrop_rock.has(ore):
		var look: Array = OUTCROP_LOOK[ore]
		var m: ShaderMaterial = _boulder_rock.duplicate() as ShaderMaterial
		var tint: Color = look[0]
		var vein: Color = look[2]
		m.set_shader_parameter("ore_tint", Vector3(tint.r, tint.g, tint.b))
		m.set_shader_parameter("tint_share", look[1])
		m.set_shader_parameter("vein_color", Vector3(vein.r, vein.g, vein.b))
		m.set_shader_parameter("vein_amount", 1.0)
		m.set_shader_parameter("vein_width", look[3])
		m.set_shader_parameter("vein_flat", look[4])
		m.set_shader_parameter("halo_share", look[5])
		m.set_shader_parameter("fleck_share", look[6])
		m.set_shader_parameter("mossiness", OUTCROP_MOSS)
		_outcrop_rock[ore] = m

	return _outcrop_rock[ore]


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

	if bogs.has(id):
		if bogs[id].get("node") is Node3D:
			(bogs[id]["node"] as Node3D).queue_free()

		bogs.erase(id)
		return

	if not _world.has(id):
		return

	var entry: Dictionary = _world[id]

	if StructureLook.look_of(int(entry.get("state", 0))) == "trodden_path":
		_path_cell_add(entry["pos"], -1)

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


# Admin mode (Dave 2026-10-23; OFF by default since Dave 11 Nov 2026): the whole list is craftable free for an admin who switched it on; the
# server decides, this only matches its greying. The admin check being off (local play) no longer makes crafting free.
var admin_craft: bool = false   # Esc > Admin > Admin mode switch (off at every start)


func _free_craft() -> bool:
	return admin_craft


func _can_craft(number: int) -> bool:
	return _free_craft() or _stock_can_make(number) or _logs_cover(number) or bool(_parts_plan(number)["ok"])


# --- Crafting stock (docs/design/INVENTORY_CRAFTING_REPORT.md step 2; src/shared/craft_stock.gd): a craft may use the pack, loose stacks within 12 m
# and the player's own containers within 12 m that are not kept out. The server sends what lies outside the pack (craft_stock, protocol 98).

# How much of an ingredient a craft may use: the pack plus the stock in reach (any member of a group fills a group need, as in the pack).
func stock_fill(number: int) -> int:
	var total: int = inventory.count_fill(number) if inventory != null else 0

	for member in (inventory.fills_of(number) if inventory != null else PackedInt32Array([number])):
		total += int(reach_stock.get(int(member), 0))

	return total


# Recipe `number` is covered by the pack and the stock in reach (the station is checked on its own, as before).
func _stock_can_make(number: int) -> bool:
	var r: Dictionary = recipes.recipe(number)

	if r.is_empty():
		return false

	for need in r["needs"] + r["keeps"]:
		if stock_fill(int(need[0])) < int(need[1]):
			return false

	return true


func _on_craft_stock(numbers: PackedInt32Array, counts: PackedInt32Array) -> void:
	reach_stock.clear()

	for i in mini(numbers.size(), counts.size()):
		reach_stock[int(numbers[i])] = int(reach_stock.get(int(numbers[i]), 0)) + int(counts[i])

	_queue_refresh()


func _on_chest_info(id: int, keep_out: bool, may_set: bool) -> void:
	if id != chest_id:
		return

	chest_keep_out = keep_out
	chest_may_keep_out = may_set

	if chest_mode:
		_container_part.refresh()   # the lock on the plate and the tick follow the server's answer


# The open container's "keep out" tick (the owner only; the server checks and answers with chest_info).
func set_keep_out(on: bool) -> void:
	if chest_mode and chest_may_keep_out and net != null:
		net.inventory_action.rpc_id(1, Net.ACT_CHEST_KEEP_OUT, chest_id, 1 if on else 0, 0, Vector3.ZERO)


# Bulk buttons and favourites (docs/design/INVENTORY_CRAFTING_REPORT.md step 3; the server does the work and answers with bulk_done). Kinds as
# Net.ACT_BULK: 0 Take all, 1 Store all (both need an open container), 2 Stack to nearby, 3 Sort (the pack and an open chest, by sort_index).
var last_bulk: Dictionary = {}       # the last bulk_done: kind, stacks, containers, ids (for the toast and the glow)
var bulk_event: Callable             # (kind, stacks moved, container count, container ids): the look's toast and glow hook in here


func bulk(kind: int) -> void:
	if net == null or kind < 0 or kind > 3 or ((kind == 0 or kind == 1) and not chest_mode):
		return

	net.inventory_action.rpc_id(1, Net.ACT_BULK, kind, sort_index if kind == 3 else 0, 0, Vector3.ZERO)


# Marks a pack slot as a favourite (or not): bulk buttons and Sort leave it where it is. The server answers with favourites.
func set_favourite(slot: int, on: bool) -> void:
	if net != null and inventory != null and slot >= 0 and slot < inventory.slot_count and inventory.numbers[slot] != 0:
		net.inventory_action.rpc_id(1, Net.ACT_FAVOURITE, slot, 1 if on else 0, 0, Vector3.ZERO)


func _on_favourites(flags: PackedByteArray) -> void:
	if inventory == null:
		return

	for i in mini(flags.size(), inventory.slot_count):
		inventory.set_fav(i, flags[i] == 1)


# A bulk button's answer as a parchment toast, and each container that took something glows warm a moment (look doc section 9).
func _bulk_look(kind: int, stacks: int, containers: int, ids: PackedInt32Array) -> void:
	InventoryLook.toast(_layer, InventoryLook.bulk_text(kind, stacks, containers))
	var spots: Array = []

	for id in ids:
		if _world.has(int(id)):
			spots.append(_world[int(id)]["pos"])

	InventoryLook.glow_chests(_root, spots)


func _on_bulk_done(kind: int, stacks: int, containers: int, ids: PackedInt32Array) -> void:
	last_bulk = {"kind": kind, "stacks": stacks, "containers": containers, "ids": ids}

	if bulk_event.is_valid():
		bulk_event.call(kind, stacks, containers, ids)


# Asks the server for the craft stock when the window has just opened or the pack has changed since the last ask.
func _ask_stock() -> void:
	if net == null or inventory == null:
		return

	var pack_sign: int = hash([inventory.numbers, inventory.counts])

	if pack_sign == _stock_sign:
		return

	_stock_sign = pack_sign
	net.inventory_action.rpc_id(1, Net.ACT_CRAFT_STOCK, 0, 0, 0, Vector3.ZERO)


# Asks for the craft stock now, whatever the pack: with the hammer in hand what lies within 12 m changes as the player walks (held_item.gd decides
# when). a = 1 marks it a poll: the server answers from its sync grid, at most twice a second, and only when the stock changed.
func ask_stock_now() -> void:
	if net == null or inventory == null:
		return

	_stock_sign = hash([inventory.numbers, inventory.counts])
	net.inventory_action.rpc_id(1, Net.ACT_CRAFT_STOCK, 1, 0, 0, Vector3.ZERO)


# The log on the shoulder plus log items lying within 3 m of the player (the server uses them for a craft that needs logs: server_items.gd _pull_nearby_logs).
var _logs_memo: int = -1   # nearby_logs for this frame, -1 not worked out (cleared with station_near's memo)


func nearby_logs() -> int:
	_memo_frame()

	if _logs_memo < 0:
		_logs_memo = _nearby_logs_now()

	return _logs_memo


func _nearby_logs_now(group_id: String = "log") -> int:
	var total: int = 0   # the carried log is a pack item and counted with the pack
	var here: Vector3 = _player_position.call() if _player_position.is_valid() else Vector3.ZERO
	var members: PackedInt32Array = table.group_members(table.number_of(group_id))

	for id in _world:
		var entry: Dictionary = _world[id]

		if int(entry.get("state", -1)) == 0 and members.has(int(entry.get("number", 0))) and here.distance_to(entry["pos"]) <= 3.0:
			total += int(entry.get("count", 1))

	return total


# Is the recipe covered once the nearby logs are counted with the pack (everything else in the pack, the station near)?
func _logs_cover(number: int) -> bool:
	var r: Dictionary = recipes.recipe(number)
	var log_n: int = table.number_of("log")

	if r.is_empty() or log_n <= 0 or not _station_ok(r):
		return false

	var uses_log: bool = false
	var soft_n: int = table.number_of("log_spruce")
	var hard_n: int = table.number_of("log_oak")

	for need in r["needs"]:
		if int(need[0]) == log_n:
			uses_log = true
			if inventory.count_fill(log_n) + nearby_logs() < int(need[1]):
				return false
		elif int(need[0]) > 0 and (int(need[0]) == soft_n or int(need[0]) == hard_n):   # the saw recipes' Softwood and Hardwood logs (Mission 001 phase 2a)
			uses_log = true
			if inventory.count_fill(int(need[0])) + _nearby_logs_now("log_spruce" if int(need[0]) == soft_n else "log_oak") < int(need[1]):
				return false
		elif not inventory.has_fill(int(need[0]), int(need[1])):
			return false

	for keep in r["keeps"]:
		if not inventory.has_fill(int(keep[0]), int(keep[1])):
			return false

	return uses_log


var _plan_cache: Dictionary = {}   # recipe number -> its auto-make plan, cleared on every refresh


# What the server would queue if you picked this recipe short of a part it can make (Dave 25 Oct): {"ok", "made": [[item, count]], "ambiguous", "msg"}.
func _parts_plan(number: int) -> Dictionary:
	if _plan_cache.has(number):
		return _plan_cache[number]

	var plan: Dictionary = {"ok": false, "steps": [], "made": [], "ambiguous": 0, "msg": ""}

	if not _stock_can_make(number):
		var ctx: Dictionary = {
			"have": func(item: int) -> int: return stock_fill(item),
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


# A station recipe whose station is working within the crafting reach (12 m): crafting it moves you there (server_items._step_to_station).
# The real check, admin mode or not: the recipe list sorts these second, under what the hands make (Dave 10 Nov 2026).
func station_in_reach(r: Dictionary) -> bool:
	return str(r.get("station", "")) != "" and station_near(str(r["station"]), int(r.get("station_level", 1)), CraftStock.CRAFT_REACH_M)


# The station that makes a recipe, by name: the first structure whose own station serves it at the recipe's level (steel at brick forge level 3
# names the Advanced smithy, not the Improved one; GOALS-REPAIR R4), else one that carries it as an "also" station at that level.
func _station_label(r: Dictionary) -> String:
	var level: int = int(r.get("station_level", 1))

	for kind in _structure_kinds():
		if str(_structures_cfg[kind].get("station", "")) == str(r.get("station", "")) and int(_structures_cfg[kind].get("station_level", 1)) >= level and not bool(_structures_cfg[kind].get("retired", false)):
			return table.sentence_name(table.number_of(str(_structures_cfg[kind].get("item", ""))))

	for kind in _structure_kinds():
		if int(_structures_cfg[kind].get("also", {}).get(str(r.get("station", "")), 0)) >= level and not bool(_structures_cfg[kind].get("retired", false)):
			return table.sentence_name(table.number_of(str(_structures_cfg[kind].get("item", ""))))

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


# The Brick - Forge (the old Masonry forge, id blacksmithy), drawn in building_look.gd; a model of Dave's in assets/stations wins, its cut stone
# reskinned in brick (item system 10 Nov 2026: brick body, keep the hood and iron straps): every surface of the cut_stone material takes the
# brick walls' surface; the iron, firebrick, charcoal and fire keep Dave's.
func _make_smithy() -> Node3D:
	var model: Node3D = _forge_glb("forge_medium")

	if model == null:
		return BuildingLook.masonry_forge()

	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = child

		if mesh_node.mesh == null:
			continue

		for surface in mesh_node.mesh.get_surface_count():
			var material: Material = mesh_node.mesh.surface_get_material(surface)

			if material != null and material.resource_name == "cut_stone":
				mesh_node.set_surface_override_material(surface, PieceLook.brick_skin())

	return model


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
	body.set_meta("placed_structure", true)       # not rock: the cave module's enclosure rays skip it (BUG-027)
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
# A placed structure of `kind` within r that is lit (its world record carries the lit fixture light).
func _lit_structure_near(pos: Vector3, kind: String, r: float) -> bool:
	var state: int = int(_structures_cfg.get(kind, {}).get("state", -2))

	for id in _world:
		if int(_world[id]["state"]) == state and _world[id].get("light") != null and pos.distance_to(_world[id]["pos"]) <= r:
			return true

	return false


func _lit_fire_near(pos: Vector3, r: float) -> bool:
	for fire_id in _world:
		if _lit_state(int(_world[fire_id]["state"])) and pos.distance_to(_world[fire_id]["pos"]) <= r:
			return true

	return false


# What the open station can use (station_use.gd, Dave 10 Nov 2026): item number -> StationUse.FUEL or INPUT, for the pack's order and its
# golden line. Only while a station's own window is open (Dave 10 Nov 2026: "even when I open my inventory and Im not in the campfires
# inventory the wood is still highlighted which it shouldnt be"): the container on screen is a fire (any campfire state) or a structure with a
# "station", stations it stands in for ("also") or its own "fuel". {} with the pack open on its own, a plain chest open, or the window shut.
func station_use() -> Dictionary:
	if not open or not chest_mode or not _world.has(chest_id):
		return {}

	var state: int = int(_world[chest_id]["state"])
	var stations: Array = []
	var fire: bool = StructureLook.CAMPFIRE_STATES.has(state)
	var fuels: Array = []

	if fire:
		stations.append("campfire")
	else:
		var def: Dictionary = _structure_by_state(state)

		for station in [str(def.get("station", ""))] + (def.get("also", {}) as Dictionary).keys():
			if str(station) != "" and not stations.has(str(station)):
				stations.append(str(station))

		if str(def.get("fuel", "")) != "":
			fuels.append(str(def["fuel"]))

	if stations.is_empty() and fuels.is_empty():
		return {}

	if (fire or not fuels.is_empty()) and _cooking_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/cooking.json"))
		_cooking_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"raw_sick": {}}

	return StationUse.usable(stations, fire, fuels, recipes, table, _cooking_cfg)


# Is a placed station of this kind within its reach? Display only (the server decides): greys recipes that need one.
# `reach_m` above a station's own reach widens it (the crafting reach: a station recipe whose station is that near moves you to it, Dave 10 Nov 2026).
var _near_memo: Dictionary = {}     # "station|level|reach" -> station_near's answer, for one frame (cleared by _forget_near)
var _near_memo_frame: int = -1


# The craft list asked station_near several times per recipe, each a walk over every world row (stones, sticks, everything within 100 m):
# opening the window, a click or D stalled 2 to 3 s (Dave 10 Nov 2026). Answers now hold for the frame; a world change or a refresh drops them.
func _forget_near() -> void:
	_near_memo.clear()
	_logs_memo = -1


func _memo_frame() -> void:
	if Engine.get_process_frames() != _near_memo_frame:
		_near_memo_frame = Engine.get_process_frames()
		_forget_near()


func station_near(station: String, level: int = 1, reach_m: float = 0.0) -> bool:
	_memo_frame()
	var key: String = "%s|%d|%.2f" % [station, level, reach_m]

	if not _near_memo.has(key):
		_near_memo[key] = _station_near_now(station, level, reach_m)

	return bool(_near_memo[key])


func _station_near_now(station: String, level: int, reach_m: float) -> bool:
	var here: Vector3 = _player_position.call() if _player_position.is_valid() else Vector3.ZERO

	if station == "campfire":   # a lit campfire (state 1) within reach, or a clay hearth or oven beside you ("also")
		for fire_id in _world:
			if _lit_state(int(_world[fire_id]["state"])) and here.distance_to(_world[fire_id]["pos"]) <= maxf(4.5, reach_m):
				return true

	for id in _world:
		var def: Dictionary = _structure_by_state(int(_world[id]["state"]))

		if def.is_empty() or here.distance_to(_world[id]["pos"]) > maxf(float(def.get("reach_m", 3.0)), reach_m):
			continue

		if str(def.get("station", "")) == station and int(def.get("station_level", 1)) + _addons_near(id, station, float(def.get("addon_reach_m", 5.0))) >= level:
			if str(def.get("attach_to", "")) == "fire" and not _lit_fire_near(_world[id]["pos"], 0.3):
				continue   # the pot cooks only while the fire it hangs over is lit

			if str(def.get("attach_to", "")) == "fireplace" and not _lit_structure_near(_world[id]["pos"], str(def.get("attach_to", "")), float(def.get("attach_m", 2.5))):
				continue   # the cooking crane cooks only beside a burning fireplace (ServerItems.serving_station)

			return true

		if int(def.get("also", {}).get(station, 0)) >= level:
			return true

	return false


# The variant codes the recipe card offers here (SmithingRules.variants; the server checks again): +1/+2 beside a Master smithy that serves the
# recipe, Tempered with the temper add-on (the Quenching trough) beside a Smithy or Master smithy that serves it.
func craft_variants(r: Dictionary) -> Array:
	var gives: Array = r.get("gives", [0, 0])
	var made_id: String = table.id_of(int(gives[0])) if not gives.is_empty() else ""
	var station: String = str(r.get("station", ""))

	if station == "" or made_id == "":
		return [0]

	_memo_frame()   # the card asks several times a refresh; the world walk runs once a frame per recipe, like station_near
	var key: String = "variants|%d" % int(r.get("number", 0))

	if not _near_memo.has(key):
		var level: int = int(r.get("station_level", 1))
		var c: Dictionary = SmithingRules.cfg()
		# As the server: the nearest Master smithy and the nearest Smithy within reach (ServerItems.serving_station), each serving the recipe.
		var master_id: int = _nearest_serving(str(c.get("craft", {}).get("station", "master_smithy")))
		var temper_station: String = str(c.get("temper", {}).get("station", "brick_forge"))
		var smithy_id: int = _nearest_serving(temper_station, level if temper_station == station else 1)   # as the server: at the recipe's level
		var master: bool = master_id >= 0 and _def_serves(_structure_by_state(int(_world[master_id]["state"])), station, level)
		var trough: bool = false

		if smithy_id >= 0 and _def_serves(_structure_by_state(int(_world[smithy_id]["state"])), station, level):
			var addon_state: int = int(_structures_cfg.get(str(c.get("temper", {}).get("addon", "")), {}).get("state", -2))
			var reach: float = float(_structure_by_state(int(_world[smithy_id]["state"])).get("addon_reach_m", 5.0))

			for other in _world:
				if int(_world[other]["state"]) == addon_state and _world[smithy_id]["pos"].distance_to(_world[other]["pos"]) <= reach:
					trough = true

		_near_memo[key] = SmithingRules.variants(made_id, table.entry(made_id), int(gives[1]) if gives.size() > 1 else 1, master, trough)

	return _near_memo[key]


# The world id of the nearest placed structure within its reach that serves `station` (its own or "also") at `level` or above, or -1.
func _nearest_serving(station: String, level: int = 1) -> int:
	var here: Vector3 = _player_position.call() if _player_position.is_valid() else Vector3.ZERO
	var best: int = -1
	var best_d: float = INF

	for id in _world:
		var def: Dictionary = _structure_by_state(int(_world[id]["state"]))
		var d: float = here.distance_to(_world[id]["pos"])

		if not def.is_empty() and d <= float(def.get("reach_m", 3.0)) + 1.0 and d < best_d and _def_serves(def, station, level):
			best = int(id)
			best_d = d

	return best


func _def_serves(def: Dictionary, station: String, level: int) -> bool:
	return (str(def.get("station", "")) == station and int(def.get("station_level", 1)) >= level) or int(def.get("also", {}).get(station, 0)) >= level


func _addons_near(bench_id: int, station: String, reach: float) -> int:
	var kinds: Dictionary = {}

	for id in _world:
		var def: Dictionary = _structure_by_state(int(_world[id]["state"]))

		if not def.is_empty() and str(def.get("addon_of", "")) == station and _world[bench_id]["pos"].distance_to(_world[id]["pos"]) <= reach:
			kinds[int(_world[id]["state"])] = true

	return kinds.size()


# A chest of any kind: the woven chest (state 6) or any structure with storage slots, such as the plank chest (BUG-021: only state 6 opened).
func _is_chest(state: int) -> bool:
	return state == 6 or int(_structure_by_state(state).get("slots", 0)) > 0


# The seat nearest `at` within `reach` metres across the ground ({"pos", "yaw", "def"}), or {} (Dave 7 Nov 2026: X beside or inside a chair sat the body on the ground
# through the seat). The client's sit key sits on it instead of on the ground.
func seat_near(at: Vector3, reach: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = reach

	for id in _world:
		var row: Dictionary = _world[id]
		var def: Dictionary = _structure_by_state(int(row.get("state", -1)))

		if str(def.get("use", "")) != "sit" or not (row.get("pos") is Vector3):
			continue

		var pos: Vector3 = row["pos"]
		var d: float = Vector2(pos.x - at.x, pos.z - at.z).length()

		if d <= best_d and absf(pos.y - at.y) < 1.5:
			best_d = d
			best = {"pos": pos, "yaw": float(row.get("yaw", 0.0)), "def": def}

	return best


var _def_by_state: Dictionary = {}   # structure state -> its structures.json row, built once (the craft list asks for every world row, per recipe)


func _structure_by_state(state: int) -> Dictionary:
	if _structures_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))
		_structures_cfg = parsed.get("structures", {}) if typeof(parsed) == TYPE_DICTIONARY else {"none": {}}

	if _def_by_state.is_empty():
		for kind in _structures_cfg:
			var at: int = int(_structures_cfg[kind].get("state", -1))

			if not _def_by_state.has(at):   # the first kind with a state wins, as the old loop did
				_def_by_state[at] = _structures_cfg[kind]

	return _def_by_state.get(state, {})


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
		var piece: Node3D = LookTable.build(look)   # building pieces: one table in look_table.gd
		var surface: String = StructureLook.step_surface(state)

		if piece != null and surface != "":
			piece.set_meta("floor_sound", surface)   # footsteps on it (terrain_client sets sound.floor_under from the body under the feet)

		return piece

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


# The materials a blueprint site still needs, one line each: green when the pack, the ground beside you and containers within 30 m hold enough, red when not.
func _site_lines(site: Array) -> String:
	var lines: PackedStringArray = []

	for line in site:
		var need: int = int(line[1])

		if need <= 0:
			continue

		var colour: String = "#55ee66" if int(line[2]) >= need else "#ff5555"
		lines.append("[color=%s]%d %s  (%d to hand)[/color]" % [colour, need, table.cost_sentence(table.number_of(str(line[0]))), int(line[2])])

	return "[center]%s[/center]" % "\n".join(lines)


# A blueprint site is the real model drawn blue and 60 percent see-through, with nothing solid about it: you walk through it.
func _make_site_look(node: Node) -> void:
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.25, 0.5, 1.0, 0.6)
	blue.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blue_all(node, blue)


func _blue_all(node: Node, blue: Material) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).material_override = blue

	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0

	for child in node.get_children():
		_blue_all(child, blue)


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

		if id == "log" or id.begins_with("log_"):
			_meshes[number] = _log_mesh(id)      # a lying log: the standing trees' bark shader and a pale cut face at each end (guide 2026-10-31: logs were plain flat cylinders)
			return _meshes[number]

		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.roughness = 1.0
		var mesh: Mesh

		if id == "stick" or id == "plant_fibre" or id == "firewood" or id == "log" or id == "driftwood" or id.begins_with("log_"):
			var dims: Array = {"driftwood": [0.9, 0.06, 0.05, 0.01], "stick": [0.6, 0.02, 0.011, 0.07], "plant_fibre": [0.3, 0.012, 0.006, 0.05], "firewood": [0.4, 0.05, 0.045, 0.01]}.get(id, [3.0, 0.28, 0.22, 0.02])   # every log, the plain Log too, is the full-size 3.0 m length (drops.json log_length_m; Master 2.3.1 "3 m basic Log")
			material.albedo_color = {"stick": Color(0.38, 0.27, 0.17), "plant_fibre": Color(0.72, 0.68, 0.45), "firewood": Color(0.5, 0.36, 0.22), "driftwood": Color(0.62, 0.58, 0.5), "log": Color(0.33, 0.24, 0.16)}.get(id, LogLookScript.color_of(id))
			mesh = _branch_mesh(float(dims[0]), float(dims[1]), float(dims[2]), float(dims[3]))
		elif id == "stone":
			mesh = RockLook.mesh()      # a weathered field stone with its own vertex colours and grain (src/client/rock_look.gd)
			material = RockLook.material()      # the stone's own grain material: the mesh is shared with the rock piles, so it keeps the one material
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


# A cut log lying along X: bark on the sides (species texture and tint, as the felled trunk), pale cut faces with a darker heart at both ends. 3.0 m for every log, the plain Log too (drops.json log_length_m).
func _log_mesh(id: String) -> ArrayMesh:
	var plain: bool = id == "log"
	var length: float = 3.0
	var r0: float = 0.28
	var r1: float = 0.22
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = r1
	cyl.bottom_radius = r0
	cyl.height = length
	cyl.radial_segments = 10
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var turn: Transform3D = Transform3D(Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5)), Vector3.ZERO)   # the cylinder's axis y becomes x
	var mesh: ArrayMesh = ArrayMesh.new()
	var side: Array = cyl.get_mesh_arrays()
	var verts: PackedVector3Array = side[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = side[Mesh.ARRAY_NORMAL]

	for k in range(verts.size()):
		verts[k] = turn * verts[k]
		normals[k] = turn.basis * normals[k]

	side[Mesh.ARRAY_VERTEX] = verts
	side[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, side)
	mesh.surface_set_material(0, _felled_bark("" if plain else id.substr(4), r0, length))
	var cut: StandardMaterial3D = StandardMaterial3D.new()
	cut.albedo_color = Color(0.72, 0.58, 0.38)
	cut.roughness = 1.0
	var heart: StandardMaterial3D = StandardMaterial3D.new()
	heart.albedo_color = Color(0.5, 0.36, 0.2)
	heart.roughness = 1.0

	for end in [-1.0, 1.0]:
		var r_end: float = r1 if end > 0.0 else r0

		for layer in range(2):
			var disc: CylinderMesh = CylinderMesh.new()
			disc.top_radius = r_end * (0.97 if layer == 0 else 0.5)
			disc.bottom_radius = disc.top_radius
			disc.height = 0.006
			disc.radial_segments = 10
			disc.rings = 1
			var arrays: Array = disc.get_mesh_arrays()
			var dv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var dn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var place: Transform3D = Transform3D(Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5)), Vector3(end * (length * 0.5 + 0.002 + 0.001 * float(layer)), 0.0, 0.0))

			for k in range(dv.size()):
				dv[k] = place * dv[k]
				dn[k] = place.basis * dn[k]

			arrays[Mesh.ARRAY_VERTEX] = dv
			arrays[Mesh.ARRAY_NORMAL] = dn
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, cut if layer == 0 else heart)

	return mesh


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


# Builds the shared meshes of the loose items that appear on every join (stones, sticks, driftwood, logs, firewood, fibre) while the client is still loading, so the first
# list of world items (282 items took 1070 ms, 961 ms of it here, PC log 2 Nov) only dresses nodes with meshes that already exist (bug 6/join freeze).
# Lag runs 5 Nov: building the loose item meshes all at once cost about 540 ms of the welcome frame (stones sticks and logs 346, trunk drops 191),
# the one freeze left at the join. In a window they are built a few each frame instead (WARM_BUDGET_USEC), in the order below, while the ground
# is still loading (2 s or more after the welcome). A mesh wanted before its turn is built on the spot by _mesh_for, as before any prewarm.
const WARM_BUDGET_USEC := 6000
var _warm_queue: Array = []        # item numbers still to build
var _warm_usec: int = 0            # time spent building them so far
var _warm_frames: int = 0


func _loose_prewarm_numbers() -> Array:
	var out: Array = []

	for id in table.ids():
		var item: String = str(id)

		if item == "stone" or item == "flint" or item == "stick" or item == "firewood" or item == "plant_fibre" or item == "driftwood" or item == "log" or item.begins_with("log_"):
			out.append(table.number_of(item))

	for drop in _trunk_drop_ids():
		if table.number_of(drop) > 0 and not out.has(table.number_of(drop)):
			out.append(table.number_of(drop))

	return out


func _start_loose_prewarm() -> void:
	var t0: int = Time.get_ticks_usec()

	for group in PICKUP_FILES:
		_pickup_group(group)

	_warm_queue = _loose_prewarm_numbers()
	_warm_usec = Time.get_ticks_usec() - t0
	_warm_frames = 0
	PieceLook.prewarm()
	_prewarm_felled()


func _warm_step() -> void:
	var t0: int = Time.get_ticks_usec()

	while not _warm_queue.is_empty() and Time.get_ticks_usec() - t0 < WARM_BUDGET_USEC:
		_mesh_for(int(_warm_queue.pop_front()))

	_warm_usec += Time.get_ticks_usec() - t0
	_warm_frames += 1

	if _warm_queue.is_empty():
		print("client prewarm: loose item meshes %.0f ms over %d frames" % [float(_warm_usec) / 1000.0, _warm_frames])


func _prewarm_loose_meshes() -> void:
	var t0: int = Time.get_ticks_usec()

	for group in PICKUP_FILES:
		_pickup_group(group)

	var t_pick: int = Time.get_ticks_usec()

	for id in table.ids():
		var item_key: String = str(id)

		if item_key == "stone" or item_key == "flint" or item_key == "stick" or item_key == "firewood" or item_key == "plant_fibre" or item_key == "driftwood" or item_key == "log" or item_key.begins_with("log_"):
			_mesh_for(table.number_of(item_key))

	var t_items: int = Time.get_ticks_usec()

	# What a felled trunk breaks into besides its logs (drops.json "trunk": branch sticks and leaves, small-blow kindling, bark, thatch, seeds, roots,
	# each species' own). Built on the first split otherwise, a pause of about a second as the trunk came apart (Dave 2 Nov: "it paused for about 1 second").
	for item_key in _trunk_drop_ids():
		if table.number_of(item_key) > 0:
			_mesh_for(table.number_of(item_key))

	var t_end: int = Time.get_ticks_usec()
	print("client prewarm: loose item meshes %.0f ms (pickup models %.0f, stones sticks and logs %.0f, trunk drops %.0f)" % [float(t_end - t0) / 1000.0, float(t_pick - t0) / 1000.0, float(t_items - t_pick) / 1000.0, float(t_end - t_items) / 1000.0])
	PieceLook.prewarm()   # the building material and trodden-path pictures, on a worker (about 170 ms on the main thread at the first piece or hoe stroke)
	_prewarm_felled()


# Bug 6 (Dave, 2 Nov 2026 16:51: "a big pause when you first cut it ... sometimes it doesn't even appear for five seconds and then poof a tree
# appears and falls over"): the first felled trunk of a session built the bark shader and the cut-face materials, and the GPU compiled them right
# then. One trunk and one stump are made here, out of sight under the world, so that compile happens during loading; they go after 5 s.
var _felled_warm: Array = []


func _prewarm_felled() -> void:
	if _root == null:
		return

	var t0: int = Time.get_ticks_usec()
	var extra: Dictionary = {"species": "oak", "radius": 0.3, "length": 8.0, "yaw": 0.0, "pitch": 0.0, "landed": true, "keywood": true}

	for trunk in [true, false]:
		var node: Node3D = _make_felled(trunk, extra)
		node.position = Vector3(0.0, -10000.0, 0.0)
		_root.add_child(node)
		_felled_warm.append(node)

	if is_inside_tree():
		get_tree().create_timer(5.0).timeout.connect(_drop_felled_warm)

	print("client prewarm: felled trunk and stump %.0f ms" % (float(Time.get_ticks_usec() - t0) / 1000.0))


func _drop_felled_warm() -> void:
	for node in _felled_warm:
		if is_instance_valid(node):
			node.queue_free()

	_felled_warm.clear()


# The item ids a felled trunk can drop besides its logs (data/items/drops.json "trunk").
func _trunk_drop_ids() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
	var trunk: Dictionary = (parsed as Dictionary).get("trunk", {}) if typeof(parsed) == TYPE_DICTIONARY else {}
	var ids: Array = ["bark", "thatch", "seed_bundle", "kindling", "leaves"]

	for key in ["branch", "small"]:
		for row in trunk.get(key, []):
			ids.append(str(row[0]))

	var roots: Array = trunk.get("roots", [])

	if not roots.is_empty():
		ids.append(str(roots[0]))

	for species in trunk.get("by_species", {}):
		for row in trunk["by_species"][species]:
			ids.append(str(row[0]))

	var out: Array = []

	for id in ids:
		if not out.has(id):
			out.append(id)

	return out


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
# Dave 2026-11-05: loose stones were 1 to 2 m across, "they look like boulders in the caves"; they must be about the size of a character's fist.
# The meshes are 10 to 15 cm across, so a scale near 1 gives 8 to 16 cm. Cave floor stones are the same item and use this too. Boulders are separate.
const STONE_SCALE := Vector2(0.85, 1.1)
const STICK_SIZE_SHARE := 0.75   # Dave 2026-10-21: sticks about 75 percent of that, lying on the ground
const STICK_SCALE := Vector2(2.0, 2.7) * PICKUP_SIZE_MULT * STICK_SIZE_SHARE
const STONE_LIFT_M := 0.01
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
const FONT_FLOOR_PX := 16                # no text under 16 px on the 1920 x 1080 canvas (_px)
const TITLE_PX := 40

var _search: LineEdit
var _recipe_search: LineEdit             # the search box at the top of the Make list: filters recipes by name as you type
var _recipe_list: VBoxContainer
var _selected_recipe: int = 0
var _hover_recipe: int = 0                 # the recipe under the mouse in the crafting list, 0 when none (E crafts it)
var knowledge                          # InspectionKnowledge (set by the client): item names follow what the character knows
var max_lights: Callable               # () -> how many fire lights the quality tier allows
var is_inspecting: Callable            # () -> true while inspection mode is on


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

	# The window is rebuilt at the new size, an open container's column with it.
	if _chest_panel != null:
		_chest_panel.queue_free()
		_chest_panel = null
		_chest_buttons.clear()
		_pack_buttons.clear()

	if _panel != null:
		var was_open: bool = open
		_panel.queue_free()
		_panel = null
		_frame = null
		_you_box = null
		_you_part = null
		_craft_root = null
		_buttons.clear()

		if was_open:
			_build_panel()

			if chest_mode:
				_container_part.build()
				_show_tab()

			_refresh()

			if _you_part != null:
				_you_part.set_active(true)


func text_px(size: int) -> int:
	return _px(size)


func _px(size: int) -> int:
	var canvas: float = maxf(_layer.get_viewport().get_visible_rect().size.y / 1080.0, 0.5)
	var scaled: int = int(round(float(size) * text_scale * canvas))

	# A size of 16 or more is a font (or a box sized to one): it never goes under the 16 px floor of the 1920 x 1080 canvas, at any
	# text step (Dave's readability rule; the texttest audit reads it). Gaps and borders, under 16, scale freely.
	return maxi(scaled, int(round(FONT_FLOOR_PX * canvas))) if size >= FONT_FLOOR_PX else scaled


# A plain tooltip (a button's or a tick's) looks like the art kit's card: the raised plate, Garamond 18 in cream (audit, job 82:
# never the engine's small grey box). Item wells make their own card (item_slot.gd _make_custom_tooltip).
func _tooltip_theme() -> Theme:
	var themed: Theme = Theme.new()
	var plate: StyleBox = ArtKit.stylebox_raised(0).duplicate()
	plate.content_margin_top = 8
	plate.content_margin_bottom = 8
	themed.set_stylebox("panel", "TooltipPanel", plate)
	themed.set_font("font", "TooltipLabel", ArtKit.font("garamond"))
	themed.set_font_size("font_size", "TooltipLabel", 18)
	themed.set_color("font_color", "TooltipLabel", ArtKit.CREAM)
	return themed


# Health, exertion, hunger and thirst, side by side at the top of the inventory screen: the only bars in the game (Dave
# 2026-10-21: no bars on the main screen). Exertion is the strain as a share of the blackout threshold.
func _build_bars_row() -> VBoxContainer:
	# The You column's stats (redesign 4.2 and 6.4): six rows, each an engraved glyph, the name, a warm bar in a recessed track and the
	# value right-aligned. The names are the game's own (Exertion and Energy); the fills are the warm set the HUD bars share.
	var row: VBoxContainer = VBoxContainer.new()
	# A fixed 6 px between the rows: the rows themselves grow with the text, so the six still fit the 820 px You column at text
	# step 1.2 (with the gap scaled too it was 837 px, texttest 9 Nov).
	row.add_theme_constant_override("separation", 6)
	_panel_bars.clear()
	_panel_values.clear()

	for stat in ArtKit.STAT_ORDER:
		var cell: HBoxContainer = HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 10)
		var glyph: Control = Control.new()
		glyph.custom_minimum_size = Vector2(26.0, 26.0)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glyph_name: String = str(ArtKit.STAT_GLYPH[stat])
		glyph.draw.connect(func() -> void: ArtKit.draw_glyph(glyph, glyph_name, Rect2(Vector2.ZERO, glyph.size), ArtKit.ENGRAVED, ArtKit.FIELD))
		cell.add_child(glyph)
		var label: Label = Label.new()
		label.text = stat
		label.add_theme_font_override("font", ArtKit.font("garamond"))
		_style(label, BODY_PX - 12)
		label.add_theme_color_override("font_color", ArtKit.CREAM)
		label.custom_minimum_size = Vector2(_px(110), 0.0)
		cell.add_child(label)
		var bar: ProgressBar = ProgressBar.new()
		bar.show_percentage = false
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(60.0, 10.0)
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = ArtKit.STAT_FILL[stat]
		fill.set_corner_radius_all(5)
		fill.border_width_top = 1
		fill.border_color = ArtKit.lighter(ArtKit.STAT_FILL[stat], 0.25)
		bar.add_theme_stylebox_override("fill", fill)
		var empty: StyleBoxFlat = StyleBoxFlat.new()
		empty.bg_color = ArtKit.WELL
		empty.set_corner_radius_all(5)
		empty.border_width_bottom = 1
		empty.border_color = Color(ArtKit.WELL_LIP, 0.55)
		bar.add_theme_stylebox_override("background", empty)
		cell.add_child(bar)
		var value: Label = Label.new()
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(_px(76), 0.0)
		value.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
		_style(value, BODY_PX - 12)
		value.add_theme_color_override("font_color", ArtKit.CREAM)
		value.add_theme_color_override("font_outline_color", ArtKit.OUTLINE)
		value.add_theme_constant_override("outline_size", 2)
		cell.add_child(value)

		if stat == "Temperature":
			_temp_label = value      # the body temperature reads here; the air is its tooltip
		else:
			var unit: String = " %" if stat in ["Exertion", "Food", "Water"] else ""
			value.text = "0" + unit
			bar.value_changed.connect(func(v: float) -> void: value.text = "%d%s" % [int(round(v)), unit])

		row.add_child(cell)
		_panel_bars[stat] = bar
		_panel_values[stat] = value

	_sick_label = Label.new()
	_sick_label.add_theme_font_size_override("font_size", _px(BODY_PX - 12))
	_sick_label.add_theme_color_override("font_color", ArtKit.BAD)
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
	var rose: bool = not skill_rows.is_empty() and skill_rose(skill_rows, rows)
	skill_rows = rows
	_update_trail_mult()

	if rose and skill_up_event.is_valid():
		skill_up_event.call()

	if _character != null:
		_character.refresh()


# True when some skill's whole working level (row[1]) is higher in `new_rows` than in `old_rows`. Rust (a drop) and new rows do not count.
static func skill_rose(old_rows: Array, new_rows: Array) -> bool:
	var before: Dictionary = {}

	for row in old_rows:
		before[int(row[0])] = int(row[1])

	for row in new_rows:
		if before.has(int(row[0])) and int(row[1]) > int(before[int(row[0])]):
			return true

	return false


# The inner voice (protocol 38): the text as a subtitle for a few seconds; Sounds plays the line's recording when there is one.
func _on_thought(line_id: String, text: String, kind: String) -> void:
	if not inner_settings.allows(kind):
		return      # the player switched this kind of line off (the symptom message itself is not a line of the voice)

	_thought_label.text = "(%s)" % KeyBindings.localize(text)   # hints from the server name the default keys ("press E to drink"): show the bound ones (#319)
	_thought_until_msec = Time.get_ticks_msec() + 5500

	if thought_event.is_valid():
		thought_event.call(line_id, kind)


# A skill's working level (0..100, the server's working_level) from the last skills message; 0 when it has never been practised.
func skill_level_of(skill: String) -> float:
	if _skill_order.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/skills.json"))
		_skill_order = (parsed.get("skills", {}) as Dictionary).keys() if typeof(parsed) == TYPE_DICTIONARY else ["-"]

	var index: int = _skill_order.find(skill)

	for row in skill_rows:
		if int(row[0]) == index:
			return float(row[1])

	return 0.0


var _bow_cfg_cache: Dictionary = {}   # bow.json, read once


func _bow_cfg() -> Dictionary:
	if _bow_cfg_cache.is_empty():
		_bow_cfg_cache = BowAim.load_config()

	return _bow_cfg_cache


# True when `number` is ammunition the shooter `bow_number` takes (bow.json "bows" ammo, as the server reads it; a sling takes sling stones).
func is_ammo_for(number: int, bow_number: int) -> bool:
	return BowAim.ammo_for(_bow_cfg(), table.id_of(bow_number)).has(table.id_of(number))


# Arrows dragged onto the bow on the hotbar load it with that arrow (Dave 10 Nov 2026); the next shots take that kind while the pack holds it.
func load_bow(number: int, bow_number: int = 0) -> bool:
	var bow_id: String = table.id_of(bow_number)

	if not is_ammo_for(number, bow_number):
		_on_notice(BowAim.say(_bow_cfg(), bow_id, "say_not_ammo"))
		return false

	bow_arrow = number
	_on_notice(BowAim.say(_bow_cfg(), bow_id, "say_load") % table.sentence_name(number))
	return true


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
			label = "Your remains" if StructureLook.look_of(int(_world[id]["state"])) == "remains" else _fire_label(_world[id], number)

	return label


# "Campfire 00:04:00 Burn time": the fuel left in the fire (a lit one counts down, a laid one shows what its wood would burn).
func _fire_label(entry: Dictionary, number: int) -> String:
	if not entry.has("burn"):
		return _item_label(number)

	var state: int = int(entry["state"])
	var left: float = float(entry["burn"])

	if _lit_state(state):
		left -= float(Time.get_ticks_msec() - int(entry.get("burn_at", Time.get_ticks_msec()))) / 1000.0

	if state == StructureLook.FIRE_COALS:
		return "%s, glowing coals" % _item_label(number) + (" and wood catching" if left > 0.0 else "")

	if state == StructureLook.FIRE_ASH:
		return "%s, warm ash" % _item_label(number)

	if state == 8 or left <= 0.0:
		return "%s, no fuel" % _item_label(number)

	var total: int = int(ceil(left))
	var size: String = ", %s fire" % ["small", "medium", "large"][_fire_tier(state) - 1] if _lit_state(state) else ""
	return "%s %02d:%02d:%02d Burn time%s" % [_item_label(number), floori(float(total) / 3600.0), floori(float(total) / 60.0) % 60, total % 60, size]


func _on_worn(numbers: PackedInt32Array, insts: PackedByteArray = PackedByteArray()) -> void:
	worn_inst = InventoryScript.inst_from_bytes(insts, 0)
	var first: bool = worn.is_empty()
	var changed: Array = []
	var ids: Array = []

	for i in numbers.size():
		var before: int = worn[i] if i < worn.size() else 0

		if numbers[i] != 0:
			ids.append(table.id_of(numbers[i]))

		if not first and numbers[i] != before:
			changed.append(table.id_of(numbers[i] if numbers[i] != 0 else before))

	worn = numbers

	if chest_mode and chest_id < 0 and BagRules.slots_of(table, _container_part.container_number()) <= 0:
		_close_chest()   # the open bag was taken off
	elif chest_mode and chest_id < 0 and _container_part.container_number() != _container_part.opened_bag:
		_ask_open(chest_id)   # another bag was put on in its place: show what that one holds

	if worn_event.is_valid():
		worn_event.call(changed, ids)

	if _weight_label != null:
		_refresh_weight()

	if _character != null:
		_character.refresh()


func clothing_slots() -> Array:
	if clothing_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/clothing.json"))
		clothing_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"slots": []}

	return clothing_cfg.get("slots", [])


# The worn positions ("slot:layer"), in the order of `worn` (clothing.json worn, protocol 107).
func worn_places() -> Array:
	clothing_slots()
	return clothing_cfg.get("worn", [])


# The worn position showing on a body slot: its outermost worn layer (`skip` leaves layers out, as the You column's own Outer well), -1 for none.
func worn_top(slot: String, skip: Array = []) -> int:
	var places: Array = worn_places()
	var layers: Array = clothing_cfg.get("layers", {}).get(slot, [])

	for k in range(layers.size() - 1, -1, -1):
		var at: int = places.find("%s:%s" % [slot, str(layers[k])])

		if not skip.has(str(layers[k])) and at >= 0 and at < worn.size() and worn[at] != 0:
			return at

	return -1


# The body weight the carry limit is worked out from (the server does the same): the real weight plus what the worn pack's weight spreading
# adds (items.json carry_bonus_kg; DESIGN-001, BUGLIST-001), so the comfortable load and the limit both rise by it.
func carry_body_kg() -> float:
	return CarryRules.carry_body_kg(weight_kg, worn, table, _carry_cfg)


# Opens the bag worn at a worn position beside the pack (the container screen); the server answers with its contents.
func open_bag(place: int) -> void:
	if place >= 0 and place < worn.size() and BagRules.slots_of(table, int(worn[place])) > 0:
		_ask_open(-1 - place)


# Arrows (item number -> count) in the worn quiver, which the bow draws from first (the server's _worn_quiver).
func quiver_counts() -> Dictionary:
	var out: Dictionary = {}

	for at in worn_inst:
		if at < worn.size() and str(table.entry(table.id_of(int(worn[at]))).get("bag_takes", "")) == "arrow":
			for row in worn_inst[at].get("bag", []):
				out[int(row[0])] = int(out.get(int(row[0]), 0)) + int(row[1])

			return out

	return out


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


# The comfort line (protocol 80): "Comfort 7" and, while the buff runs, "Rested 38 min", small at the top right; hidden at comfort 0 with no buff.
var comfort_level: int = 0
var rested_level: int = 0
var rested_minutes: int = 0
var _comfort_label: Label
var comfort_tip: String = ""


func _on_comfort(level: int, rested_tier_level: int, minutes: int, tip: String = "") -> void:
	comfort_level = level
	rested_level = rested_tier_level
	rested_minutes = minutes

	if _comfort_label == null:
		_comfort_label = Label.new()
		_comfort_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_comfort_label.anchor_left = 1.0
		_comfort_label.anchor_right = 1.0
		_comfort_label.offset_left = -420.0
		_comfort_label.offset_right = -20.0
		_comfort_label.offset_top = 18.0
		_comfort_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_comfort_label.add_theme_font_size_override("font_size", 26)
		_comfort_label.add_theme_constant_override("outline_size", 6)
		_comfort_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		_comfort_label.mouse_filter = Control.MOUSE_FILTER_STOP   # hover it (inventory open, cursor free) for the tooltip
		_layer.add_child(_comfort_label)

	_comfort_label.text = comfort_text(level, rested_tier_level, minutes)
	_comfort_label.tooltip_text = tip
	comfort_tip = tip
	_comfort_label.visible = _comfort_label.text != ""
	_comfort_label.self_modulate = Color(1.0, 0.85, 0.55) if level >= 2 else Color(0.7, 0.7, 0.7)


# Goals (protocol 119; docs/design/PLAYER_JOURNAL_GOALS_UI.md): the server's list and completions feed one book; the upper-right Goals box sits on the HUD
# layer under the comfort line, and the placard on its own layer above every window (it takes no input).
var goal_book
var goals_hud: Control
var goal_placard: Control
var journal


func _setup_goals() -> void:
	goal_book = GoalBookScript.new()
	net.goals_received.connect(goal_book.on_goals)
	net.goal_done_received.connect(goal_book.on_done)
	goals_hud = GoalsHudScript.new()
	_layer.add_child(goals_hud)
	goals_hud.setup(self, goal_book)
	var top: CanvasLayer = CanvasLayer.new()
	top.name = "GoalPlacardLayer"
	top.layer = _layer.layer + 5
	_layer.add_child(top)
	goal_placard = GoalPlacardScript.new()
	top.add_child(goal_placard)
	goal_placard.setup(self, goal_book)
	journal = JournalScript.new()
	journal.setup(self, _layer, goal_book)


# The words of the comfort line: "" when there is nothing to say.
static func comfort_text(level: int, rested_tier_level: int, minutes: int) -> String:
	var parts: PackedStringArray = PackedStringArray()

	if level > 0:
		parts.append("Comfort %d" % level)

	if rested_tier_level > 0 and minutes > 0:
		parts.append("Rested %d min" % minutes)

	return "   ".join(parts)


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
	_panel_bars["Temperature"].value = float(warmth)
	if _temp_label != null and is_instance_valid(_temp_label):
		_temp_label.text = DisplaySettingsScript.temp_text(float(warmth))
		_temp_label.tooltip_text = "Body temperature" + ("" if is_nan(air_c) else ". Air " + DisplaySettingsScript.air_text(air_c))

	if _sick_label != null and is_instance_valid(_sick_label):
		_sick_label.text = ("Health: ill, about %d h left" % sick_hours) if sick_hours > 0 else ""
	_panel_bars["Food"].value = float(hunger)
	_panel_bars["Water"].value = float(thirst)


func _style(control: Control, size: int) -> void:
	control.add_theme_font_size_override("font_size", _px(size))


func _build_panel() -> void:
	if _panel != null:
		return

	# The redesign's window (docs/ui/inventory_crafting_redesign.md section 4, step 3a): the frame draws the backdrop and three solid
	# panels at fixed canvas px, Pack, You and Craft, ending at y 932 so the hotbar strip shows underneath. The parts build into its columns.
	_panel = PanelContainer.new()
	_panel.theme = _tooltip_theme()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_frame = InventoryFrameScript.new()
	_panel.add_child(_frame)

	if not bulk_event.is_valid():
		bulk_event = _bulk_look

	_search = LineEdit.new()
	_search.placeholder_text = "Search the pack"
	_search.custom_minimum_size = Vector2(232.0, 0.0)
	_search.clear_button_enabled = true
	_style(_search, BODY_PX - 12)
	_search.text_changed.connect(func(_text): _refresh())
	_frame.header.add_child(_search)

	# The Chest and Craft tabs (4.4), shown while a container is open, then the text size buttons (Dave 2026-10-20; terrain_client keeps
	# and saves the choice). They share the Craft panel's title row.
	_craft_tabs = [_craft_tab("Chest", true), _craft_tab("Craft", false)]
	_text_buttons.clear()

	for tab in _craft_tabs:
		_frame.craft_header.add_child(tab)

	for step in [[-1, "Text -"], [1, "Text +"]]:
		var size_button: Button = Button.new()
		size_button.text = step[1]
		_style(size_button, BODY_PX - 12)
		size_button.pressed.connect(func():
			if text_step.is_valid():
				text_step.call(step[0]))
		_frame.craft_header.add_child(size_button)
		_text_buttons.append(size_button)

	_frame.set_title(1, _you_title())

	# You: the gear wells and the live character, an ornament rule, then the six stats.
	_you_box = VBoxContainer.new()
	_you_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_you_box.add_theme_constant_override("separation", 12)
	_you_part = YouColumnScript.new(self)
	_you_box.add_child(_you_part.build())
	var you_rule: Control = Control.new()
	you_rule.custom_minimum_size = Vector2(0.0, 12.0)
	you_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	you_rule.draw.connect(func() -> void: ArtKit.draw_rule(you_rule, 0.0, you_rule.size.x, 6.0))
	_you_box.add_child(you_rule)
	_you_box.add_child(_build_bars_row())
	_frame.you_column.add_child(_you_box)

	# Pack and Craft: each part builds its own column (src/client/ui/inventory/).
	_queue_part.build()
	var pack_root: Control = _pack_part.build()
	pack_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.pack_column.add_child(pack_root)
	_craft_root = _recipe_part.build(_queue_part.root)
	_craft_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.craft_column.add_child(_craft_root)
	_layer.add_child(_panel)

	# The hotbar strip stays on top of the window's backdrop, in its place, so it can be read and dropped on with the window up (section 9).
	if hotbar_strip != null and hotbar_strip._row != null and is_instance_valid(hotbar_strip._row) and hotbar_strip._row.get_parent() == _layer:
		_layer.move_child(hotbar_strip._row, -1)

	if heart_pulse != null and is_instance_valid(heart_pulse) and heart_pulse.get_parent() == _layer:
		_layer.move_child(heart_pulse, -1)     # the pulse line with it, over the backdrop


# Chest mode (redesign 4.4): with a container open the Craft column shows it, named on the plate, or the recipes, by the Chest and
# Craft tabs on the title row. With no container the tabs go and the column is Craft again.
func _show_tab() -> void:
	var chest: bool = chest_mode and chest_tab

	if _chest_panel != null and is_instance_valid(_chest_panel):
		_chest_panel.visible = chest

	if _craft_root != null and is_instance_valid(_craft_root):
		_craft_root.visible = not chest

	if not chest:
		_chest_hover = []      # a hidden slot sends no mouse_exited

	for i in _craft_tabs.size():
		var tab: Button = _craft_tabs[i]
		tab.visible = chest_mode
		var lit: bool = (i == 0) == chest
		tab.add_theme_stylebox_override("normal", ArtKit.stylebox_raised(1 if lit else 0))
		tab.add_theme_color_override("font_color", ArtKit.HEADING if lit else ArtKit.CREAM)

	for button in _text_buttons:
		(button as Control).visible = not chest_mode

	if _frame != null and is_instance_valid(_frame):
		_frame.set_title(2, _container_part.title() if chest else "CRAFT")


# A tab on the Craft panel's title row (4.4): a raised plate of 118 x 36, the word in Cinzel; lit when it is the one showing.
func _craft_tab(text: String, shows_chest: bool) -> Button:
	var tab: Button = Button.new()
	tab.text = text
	tab.custom_minimum_size = Vector2(118.0, 36.0)
	tab.focus_mode = Control.FOCUS_NONE
	tab.visible = false
	tab.add_theme_font_override("font", ArtKit.font("cinzel_bold"))
	tab.add_theme_font_size_override("font_size", 18)
	tab.add_theme_color_override("font_hover_color", ArtKit.HEADING)
	tab.add_theme_stylebox_override("normal", ArtKit.stylebox_raised(0))
	tab.add_theme_stylebox_override("hover", ArtKit.stylebox_raised(1))
	tab.add_theme_stylebox_override("pressed", ArtKit.stylebox_raised(2))
	tab.pressed.connect(func() -> void:
		chest_tab = shows_chest
		_show_tab())
	return tab


func _you_title() -> String:
	var who: String = str(CharacterStore.active().get("name", "")).strip_edges()
	return who.to_upper() if who != "" else "YOU"


# True while the crafting and inventory screen or a chest screen is on screen.
# An NPC talk (src/client/dialogue_view.gd) counts as a screen: it frees the mouse, stops walking, and Esc closes it.
var dialogue_open: bool = false
var dialogue_key: Callable = Callable()     # (event) -> bool: digit keys pick a choice
var dialogue_close: Callable = Callable()


func screen_open() -> bool:
	return open or chest_mode or character_open() or (journal != null and journal.open) or dialogue_open or _storage_ui.is_open() or _food_ui.is_open()


const CHEST_KEYS := [["take_all", 0], ["store_all", 1], ["stack_nearby", 2], ["sort_both", 3]]    # action id, Net.ACT_BULK kind


# Quick keys while the screen is open: E use (eat or apply), D drop (Shift+D one), S split, R repair, T transfer
# between the pack and an open container. They act on the slot under the mouse, else the selected slot. With a container open
# A takes all, G stores all, F sorts both and Q stacks into my chests. True when the key was one of them (the caller then skips
# its other bindings). Outside this screen E is the interact key.
func quick_key(event: InputEventKey) -> bool:
	if dialogue_open and dialogue_key.is_valid():
		return bool(dialogue_key.call(event))

	if _storage_ui.is_open():
		return true   # the lock or storage window has the keys (its code and search fields)

	var slot: int = _hover if _hover >= 0 else (key_slot(hotbar_hover) if hotbar_hover >= 0 else _selected)   # a hotbar box is a pack slot too (TEST-008)

	if KeyBindings.matches(event, "use_item"):
		if hotbar_hover >= 0 and _hover < 0:
			hotbar_to_pack(hotbar_hover)
			return true

		if slot >= 0 and not chest_mode:
			eat_slot(slot)

		return true

	if KeyBindings.matches(event, "drop_item"):
		if slot < 0 and shoulder_id != "" and not chest_mode:
			lay_down_shoulder()
			return true

		if slot >= 0 and not chest_mode:
			_selected = slot
			_drop_selected(not event.shift_pressed)

		return true

	if KeyBindings.matches(event, "repair_item"):
		if slot >= 0 and not chest_mode:
			_selected = slot
			_repair_selected()

		return true

	if KeyBindings.matches(event, "split_item"):
		if slot >= 0 and not chest_mode:
			_selected = slot
			_split_selected()

		return true

	if KeyBindings.matches(event, "transfer_item"):
		if chest_mode and _chest_hover.size() == 2:
			_container_part.on_slot(bool(_chest_hover[0]), int(_chest_hover[1]))

		return true

	# A container open: Take all, Store all, Sort both, Stack into my chests (redesign 4.4), the same as the key hints in its column.
	if chest_mode:
		for spec in CHEST_KEYS:
			if KeyBindings.matches(event, str(spec[0])):
				bulk(int(spec[1]))
				return true

	return false


# `variant`: the SmithingRules code chosen on the recipe card (0 plain); the server checks it again.
func _start_craft(number: int, count: int = 1, variant: int = 0) -> void:
	if not _can_craft(number):
		return

	for item in recipes.recipe(number).get("identify", []):
		if knowledge != null and not knowledge.is_known("i%d" % item):
			_on_notice("You are not sure what %s really is. Hover it in inspection mode (/) before you use it." % table.sentence_name(item))
			return

	net.inventory_action.rpc_id(1, Net.ACT_CRAFT_QUEUE, number, variant, count, Vector3.ZERO)


func _on_reject(reason: int) -> void:
	auto_pickup.note_refused(_player_position.call(), hash(inventory.counts))
	if reason == 2 and _last_pick != 0:
		_sweep_refused[_last_pick] = true   # too heavy or no room: held E passes it over and goes on to the next nearest (Dave 10 Nov 2026)
	refuse_cue(["far", "no_tool", "full_pack", "other"][clampi(reason, 0, 3)])


# A hard landing (sound.landing.hurt): tell the server how far it was; the server decides the damage.
func report_fall(drop_m: float, _severity: float = 0.0) -> void:
	net.inventory_action.rpc_id(1, Net.ACT_FALL, int(round(drop_m * 100.0)), 0, 0, Vector3.ZERO)


func _on_craft_queue(entries: Array, left_ms: int) -> void:
	craft_entries = entries
	_crafting = int(entries[0][0]) if not entries.is_empty() else 0
	_craft_head_end_msec = Time.get_ticks_msec() + left_ms
	_queue_part.rebuild()


func _repair_selected() -> void:
	if _selected < 0 or (inventory.wear[_selected] <= 0 and inventory.sharpness_used(_selected) <= 0):   # R also sharpens a dull edge tool
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


# An item's name with its enhancements ("Tempered Steel - Axe +2"; master s2.9 item 5: the name shows the instance's actual enhancements).
func inst_label(number: int, item_inst: Dictionary) -> String:
	var craft: int = int(item_inst.get("craft", 0))
	return ("Tempered " if int(item_inst.get("temper", 0)) == 1 else "") + _item_label(number) + (" +%d" % craft if craft > 0 else "")


# The instance lines of a tooltip: the edge's sharpness, and each filled magical slot; empty slots stay hidden (master s2.9 item 1).
func inst_lines(item_inst: Dictionary, number: int = 0) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var entry: Dictionary = table.entry(table.id_of(number)) if number != 0 else {}

	if SmithingRules.dull_at(entry, item_inst) > 0:
		out.append("Sharpness %d %%%s" % [int(round(SmithingRules.sharpness(entry, item_inst) * 100.0)), " (dull: it wears faster; R sharpens it)" if SmithingRules.is_dull(entry, item_inst) else ""])

	for effect in item_inst.get("magic", []):
		if str(effect) != "":
			out.append("Enchanted: %s" % str(effect))

	return out


func _freshness_word(f: float) -> String:
	return "fresh" if f > 0.6 else ("going off" if f > 0.25 else "nearly rotten")


func _tooltip(number: int, count: int, fill_ml: int = 0, item_inst: Dictionary = {}) -> String:
	if number == 0:
		return ""

	var entry: Dictionary = table.entry(table.id_of(number))
	var item_name: String = inst_label(number, item_inst)

	var text: String = "%s x%d\n%s, %s" % [item_name, count, str(entry.get("kind", "item")), "does not stack" if table.stack_of(number) <= 1 else "stacks without limit (weight is your limit)"]

	for line in inst_lines(item_inst, number):
		text += "\n" + line

	text += "\n%s" % str(entry.get("description", "A plant material you gathered."))

	if int(entry.get("capacity_ml", 0)) > 0:
		text += "\nHolds %s of %s. Use (E) drinks from it; at the water, E fills it." % [_litres(fill_ml), _litres(int(entry["capacity_ml"]))]

	if table.wood_class(number) != "" and fill_ml > 0:   # wet wood: the slot's wear is its drying left in tenths of a game hour (cooking.json wet_wood)
		text += "\nWet: dry in about %d game hours, faster by a fire. Wet wood smokes, burns slower and gives less heat." % maxi(int(ceil(float(fill_ml) / 10.0)), 1)

	var kcal: int = VitalsRules.food_value(table.id_of(number), _vitals_cfg)
	var heal: int = VitalsRules.heal_value(table.id_of(number), _vitals_cfg)

	if not _carry_cfg.is_empty():
		var each_kg: float = CarryRules.weight_of(table.id_of(number), _carry_cfg)
		text += "\n%s each" % (("%.0f g" % (each_kg * 1000.0)) if each_kg < 0.1 else ("%.2f kg" % each_kg))

	if str(entry.get("slot", "")) != "":
		var layer: String = str(entry.get("wear_layer", "base"))
		text += "\nWorn on the %s%s. Use (E) puts it on." % [str(entry["slot"]), "" if layer in ["base", "footwear"] else ", %s layer" % layer]

		if float(entry.get("warmth", 0.0)) > 0.0:
			text += " Keeps %d%% of your body heat in." % int(round(float(entry["warmth"]) * 100.0))

		if float(entry.get("carry_bonus_kg", 0.0)) > 0.0:
			text += " Spreads the weight: you can carry %.0f kg more." % float(entry["carry_bonus_kg"])

		if BagRules.slots_of(table, number) > 0:
			var held: int = (item_inst.get("bag", []) as Array).filter(func(row: Array) -> bool: return int(row[0]) != 0).size()
			text += " Holds %d slots of its own (%d in use); open it from the Tab screen or its gear well. Its load still counts toward what you can carry." % [BagRules.slots_of(table, number), held]

	if _raw_sick_hours(table.id_of(number)) > 0.0:
		text += "\nEaten raw it ruins your health for a day. Cook it at a fire first."

	if kcal > 0:
		text += "\n%d kcal  (right click when held, or Eat / use)" % kcal

	if heal > 0:
		text += "\nrestores %d health  (right click when held, or Eat / use)" % heal

	var cure: Dictionary = VitalsRules.medicine(table.id_of(number), _vitals_cfg)

	if not cure.is_empty():
		text += "\nTakes away %d hours of ill health  (right click when held, or Eat / use)" % int(cure.get("cure_h", 0))

	var food_fx: Dictionary = FoodEffectsScript.profile(table.id_of(number), _food_ui.cfg)

	if not food_fx.is_empty():   # its food effect (catalog phase 7): one group slot, refreshed by the same group, never stacked
		var fx_group: String = str(food_fx["group"])
		text += "\n%s, tier %d: %s for %s game hours" % [FoodEffectsScript.group_name(fx_group, _food_ui.cfg), int(food_fx["tier"]), FoodEffectsScript.describe(fx_group, int(food_fx["tier"]), table.id_of(number), _food_ui.cfg), str(FoodEffectsScript.tier_row(fx_group, int(food_fx["tier"]), _food_ui.cfg).get("h", 0))]

	if table.shelf_units(number) > 0:
		var f: float = table.freshness(number, fill_ml)
		text += "\n%s (%d%% fresh). Spoils; keep it in a chest, in the cold or dry it." % [_freshness_word(f).capitalize(), int(f * 100.0)]

	if int(entry.get("value", 0)) > 0 and str(entry.get("kind", "")) != "coin":
		text += "\nWorth about %s" % coin_text(int(entry["value"]) * count) + (" (%s each)" % coin_text(int(entry["value"])) if count > 1 else "")

	text += "\nKeys: Split (S), Drop (D), Use (E)"

	if int(entry.get("durability", 0)) > 0:
		text += "\nlasts %d uses; " % SmithingRules.max_of(entry, item_inst)

		if SmithingRules.disposable(entry):
			text += "cannot be mended: it is gone when it breaks"
		else:
			var parts: PackedStringArray = PackedStringArray()

			for cost in entry.get("repair", []):
				parts.append("%d %s" % [int(cost[1]), table.cost_sentence(table.number_of(str(cost[0])))])

			text += "repair: " + ", ".join(parts)

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


# Remembers the order item kinds first appeared in the pack (for the unsorted view).
func _note_acquired() -> void:
	var present: Dictionary = {}

	for slot in range(inventory.slot_count):
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
	if _pinned_part.number != 0:
		_pinned_part.refresh()   # the pinned checklist ticks as you gather, window open or shut

	if _panel == null:
		_note_acquired()
		return

	_note_acquired()
	_plan_cache.clear()
	_forget_near()

	# Lag fix (Sal, 2 Nov 2026): with the window shut (or the chest screen up instead) nobody sees the slot buttons or the recipe list, and rebuilding
	# them cost 55 to 87 ms on every pickup. The window rebuilds in toggle() when it opens; only the weight HUD is kept current.
	if not open or _recipe_list == null:   # nothing built yet: nothing to redraw
		if _weight_label != null:
			_refresh_weight()

		return

	_ask_stock()
	_pack_part.refresh()
	_recipe_part.refresh()

	if _you_part != null:
		_you_part.refresh()


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
	var peak_strain: float = strain

	for sample in 50:   # the highest strain seen during the run, not only the last value: it does not depend on how fast the frames came on a busy PC
		await get_tree().create_timer(0.5).timeout
		peak_strain = maxf(peak_strain, strain)

	var covered: float = Vector2(client.body.global_position.x - start_pos.x, client.body.global_position.z - start_pos.z).length()
	print("Strain test: ran %.0f m in 25 s, strain %.2f -> %.2f, state %d" % [covered, start_strain, strain, strain_state])
	print("Strain test: peak strain %.2f" % peak_strain)

	# The server's walk from normal to over-exerted to blackout is proven in test_server_items; here the client's side of it:
	# over-exerted is a 10 percent slow-down with no speed cap and running still allowed, fainted locks movement.
	var real_state: int = strain_state
	var factors: Array = []

	for forced in [0, 1, 2]:
		strain_state = forced
		factors.append("%d: pace x%s cap %s" % [forced, str(snappedf(over_pace_factor(), 0.001)), str(move_cap())])

	strain_state = real_state
	print("Strain test: %s" % " | ".join(factors))


func _pack_items() -> int:
	var total: int = 0

	for slot in range(inventory.slot_count):
		total += inventory.counts[slot] if inventory.numbers[slot] != 0 else 0

	return total


func run_gather_test(client) -> void:
	await get_tree().create_timer(14.0).timeout
	var real_view: Callable = view_direction
	view_direction = Callable()   # the prompt checks below stand wherever the test camera happens to look
	var shrubs: Array = []
	var here: Vector3 = _player_position.call()

	for chunk in client.flora._chunks:
		var held: Dictionary = client.flora._chunks[chunk]["items"]

		for n in range(held["ids"].size()):
			var sid: int = held["ids"][n] >> 16

			if client.flora._species.get(sid, {}).get("kind", 0) in [1, 2]:   # shrubs and plants: whatever is in season at the test clock gives something
				shrubs.append([held["positions"][n].distance_to(here), held["positions"][n]])

	if shrubs.is_empty():
		print("Gather test: no shrub loaded")
		return

	shrubs.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var sticks: int = table.number_of("stick")
	var before: int = inventory.count_of(sticks)
	var items_before: int = _pack_items()

	# A shrub out of season gives nothing (the server refuses it quietly): try the nearest few until one gives sticks, so the check does not depend on the season of the test clock.
	for candidate in range(mini(shrubs.size(), 14)):
		client.body.global_position = shrubs[candidate][1] + Vector3(0.5, 1.0, 0.0)
		client.body.velocity = Vector3.ZERO
		await get_tree().create_timer(3.0).timeout
		await get_tree().create_timer(0.6).timeout
		print("Gather test: prompt \"%s\"" % plant_hint)
		client.harvest.tap()
		await get_tree().create_timer(2.0).timeout

		if _pack_items() > items_before:
			break

	print("Gather test: pack items %d -> %d" % [items_before, _pack_items()])
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

	print("Quick key test: pack ready after the give, stone %d, roast %d" % [inventory.count_of(stone), inventory.count_of(roast)])
	toggle()
	print("Quick key test: window open %s, %d slots" % [str(open), _buttons.size()])
	var slot: int = inventory.numbers.find(stone)
	var before: int = inventory.count_of(stone)
	_hover = slot

	var press: Callable = func(code: int, shift: bool = false) -> bool:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code as Key
		event.shift_pressed = shift
		event.pressed = true
		return quick_key(event)

	# Deltas, not absolute counts: the pack may hold more than was given (late syncs, stones picked up by themselves at the spawn).
	var stacks_before: int = _stone_stacks(stone)
	var handled: bool = press.call(KEY_S)
	await get_tree().create_timer(1.0).timeout
	print("Quick key test: S handled %s, stacks of stone %d -> %d" % [str(handled), stacks_before, _stone_stacks(stone)])
	print("Quick key test: S added stacks %d" % (_stone_stacks(stone) - stacks_before))
	_hover = inventory.numbers.find(stone)
	var stones_now: int = inventory.count_of(stone)
	press.call(KEY_D, true)
	await get_tree().create_timer(1.0).timeout
	print("Quick key test: Shift+D dropped one, stones %d -> %d" % [before, inventory.count_of(stone)])
	print("Quick key test: Shift+D dropped %d" % (stones_now - inventory.count_of(stone)))
	_hover = inventory.numbers.find(roast)
	var roasts: int = inventory.count_of(roast)
	press.call(KEY_E)
	await get_tree().create_timer(1.0).timeout
	print("Quick key test: E ate, roasts %d -> %d" % [roasts, inventory.count_of(roast)])
	print("Quick key test: E ate %d" % (roasts - inventory.count_of(roast)))
	print("Quick key test: T outside a container handled %s, nothing moved" % str(press.call(KEY_T)))


func _stone_stacks(number: int) -> int:
	var stacks: int = 0

	for slot in range(inventory.slot_count):
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

	var step: int = 0

	for direction in [-1, -1, -1, 1, 1, 1, 1, -1, -1, -1, 1]:
		step += 1
		text_step.call(direction)

		# Right after the press (before any frame passes): the list must hold only the new, shown buttons.
		valid = valid and _buttons.size() == inventory.slot_count

		for slot in range(mini(_buttons.size(), inventory.slot_count)):
			valid = valid and is_instance_valid(_buttons[slot]) and _buttons[slot].get_parent() == _grid

			if inventory.numbers[slot] != 0 and _buttons[slot].is_empty():   # an item slot (item_slot.gd) shows its stack, not text
				filled_ok = false

		await get_tree().process_frame
		_refresh()
		await get_tree().process_frame
		await get_tree().process_frame
		sizes[snappedf(_panel.size.x, 1.0) * 10000 + snappedf(_panel.size.y, 1.0)] = text_scale
		var need: Vector2 = _panel.get_combined_minimum_size()
		fits = fits and need.x <= _panel.size.x + 1.0 and need.y <= _panel.size.y + 1.0 and _frame.columns_fit()
		print("Text step %d: scale %.2f, window %dx%d needs %dx%d; columns: %s" % [step, text_scale, _panel.size.x, _panel.size.y, need.x, need.y, _frame.fit_report()])

		for button in _buttons:
			valid = valid and is_instance_valid(button)

		# Every slot that holds something must show it after each press.
		for slot in range(inventory.slot_count):
			if inventory.numbers[slot] != 0 and valid and _buttons[slot].is_empty():
				filled_ok = false

		for mode in [1, 2, 3, 4, 5, 0]:
			sort_index = mode
			_pack_part.arrange_slots()

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
# from the client's flora afterwards. A harvest plant (drops.json harvest_yield or berry_yield, such as yarrow) is picked by design when it
# stands bare until its next season (the server's _stripped, the client's flora.is_stripped), so it counts as picked, not as still standing.
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
		var bare: bool = false

		# A cold server answers late (its item step can stall for seconds): wait up to 8 s for the plant to leave the flora.
		for wait in range(16):
			await get_tree().create_timer(0.5).timeout
			var held_now: Dictionary = client.flora._chunks.get(spot[3], {}).get("items", {})
			still = held_now.has("ids") and held_now["ids"].find(spot[2]) >= 0
			bare = still and client.flora.is_stripped(spot[3], int(spot[2]))

			if not still or bare:
				break

		print("Plant test: %s %s" % [client.harvest._flora_by_id.get(int(spot[2]) >> 16, {}).get("name", "?"), "bare until next season" if bare else ("STILL THERE" if still else "gone")])
		still = still and not bare
		gone += 0 if still else 1

	print("Plant test: tried %d, gone %d, still standing %d, skipped (nothing pickable) %d" % [tried, gone, tried - gone, skipped])


# The self-tests build with the hammer, as players do since kits left the game (4 Nov 2026): data/items/blueprints.json numbers and costs.
# The wooden hammer goes on a hotbar key by itself when it comes into the pack (inventory step 4).
const CHEST_BLUEPRINT := 26
const CHEST_MATERIALS := [["wooden_hammer", 1], ["stick", 10], ["twine", 4]]
const LEAN_TO_BLUEPRINT := 25
const LEAN_TO_MATERIALS := [["wooden_hammer", 1], ["stick", 30], ["leaves", 100], ["leaves", 100], ["twine", 10]]


func _give_blueprint_kit(materials: Array) -> void:
	for row in materials:
		net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of(str(row[0])), 0, int(row[1]), Vector3.ZERO)


func _has_blueprint_kit(materials: Array) -> bool:
	var need: Dictionary = {}

	for row in materials:
		need[str(row[0])] = int(need.get(str(row[0]), 0)) + int(row[1])

	for item_id in need:
		if inventory.count_of(table.number_of(item_id)) < int(need[item_id]):
			return false

	return true


# Headless check (--leanto): place a lean-to ahead of the player and look for its row and its roof.
func run_leanto_test(_client) -> void:
	await get_tree().create_timer(6.0).timeout
	_give_blueprint_kit(LEAN_TO_MATERIALS)   # kits left the game (4 Nov 2026): the lean-to is built with the hammer from its blueprint

	for wait in 30:   # a cold join gets its pack late: poll up to 15 s for the hammer and the materials
		await get_tree().create_timer(0.5).timeout

		if _has_blueprint_kit(LEAN_TO_MATERIALS):
			break

		if wait == 16:   # still not all there after 8 s: the give was lost, send it once more
			_give_blueprint_kit(LEAN_TO_MATERIALS)

	var here: Vector3 = _player_position.call()
	var ground: float = float(_ground_below.call(here + Vector3(2.0, 0.0, 0.0)))
	var spot: Vector3 = Vector3(here.x + 2.0, ground, here.z)
	net.inventory_action.rpc_id(1, Net.ACT_PLACE_BLUEPRINT, LEAN_TO_BLUEPRINT, 0, 0, spot)
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

	if not await _wait_inventory_ready():
		print("SLEEP TEST FAILED: the pack never arrived")
		return


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

	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_ENERGY, 0, 0, 60, Vector3.ZERO)   # a rested character cannot sleep: start tired
	await get_tree().create_timer(1.5).timeout
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

	if not await _wait_inventory_ready():
		print("SNARE TEST FAILED: the pack never arrived")
		return


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

	for wait in 30:   # a cold join gets its pack late: poll up to 15 s for both, and ask once more after 8 s if nothing came
		await get_tree().create_timer(0.5).timeout

		if inventory.numbers.has(table.number_of("roast_forage")) and inventory.numbers.has(table.number_of("poultice")):
			break

		if wait == 16 and inventory.count_of(table.number_of("roast_forage")) == 0:
			net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("roast_forage"), 0, 2, Vector3.ZERO)
			net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("poultice"), 0, 1, Vector3.ZERO)

	print("Eat test: start hunger %d health %d weight %.1f; edible slot 0 %s" % [hunger, health, weight_kg, str(edible_slot(inventory.numbers.find(table.number_of("roast_forage"))))])
	var roasts_before: int = inventory.count_of(table.number_of("roast_forage"))
	eat_slot(inventory.numbers.find(table.number_of("roast_forage")))
	await get_tree().create_timer(1.0).timeout
	print("Eat test: after a roast, hunger %d, roasts left %d" % [hunger, inventory.count_of(table.number_of("roast_forage"))])
	print("Eat test: roasts eaten %d" % (roasts_before - inventory.count_of(table.number_of("roast_forage"))))   # a delta: the pack may hold more than was given
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
		_pack_part.arrange_slots()
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
	_recipe_part.craft_selected()
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

	# Tools: Use holds a tool, again puts it away; a tool in the backpack first moves into a hotbar slot (the hotbar is real slots, TEST-008).
	var axe: int = table.number_of("stone_axe")
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, axe, 0, 1, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	var axe_slot: int = inventory.numbers.find(axe)

	if int(held_slot_now.call()) == axe_slot:
		equip_requested.call(int(held_key_now.call()))   # the saved hotbar key can be its slot: start with empty hands

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
	var on_key: bool = moved_to >= 0 and inventory.on_hotbar(moved_to)
	equip_requested.call(int(held_key_now.call()))   # empty hands again
	print("Hotbar test: axe parked in slot 20, Use moves it to the hotbar and holds it, slot %d (%s), on hotbar %s, slot 20 now empty %s" % [moved_to, str(moved_to >= 0 and inventory.numbers[moved_to] == axe), str(on_key), str(inventory.numbers[20] != axe)])

	# Every tool and weapon in the table can be held from the hotbar, with a model, and does something on left click.
	var tool_ids: Array = []

	for id in table._by_id:
		if str(table._by_id[id].get("kind", "")) in ["tool", "weapon"] and not bool(table._by_id[id].get("future", false)):
			tool_ids.append(id)

	var held_ok: int = 0
	var modelled: int = 0

	for id in tool_ids:
		net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of(id), 0, 1, Vector3.ZERO)

		for poll in 20:   # the give can be late (a heavy item such as the quern may also be refused by weight: then it never arrives and is reported)
			await get_tree().create_timer(0.3).timeout

			if inventory.numbers.has(table.number_of(id)):
				break

		var tool_slot: int = inventory.numbers.find(table.number_of(id))

		if tool_slot >= 0 and tool_slot != 9:
			move_slot(tool_slot, 9)   # into hotbar slot 0 (key 0), as a player would drag it

			for poll in 10:
				await get_tree().create_timer(0.1).timeout

				if inventory.numbers[9] == table.number_of(id):
					break

		await get_tree().create_timer(0.3).timeout
		client.held.select(9)
		await get_tree().create_timer(0.3).timeout
		# A torch or shield goes in the left hand (items.json "offhand", 7 Nov 2026). A doused torch lights again when its key is pressed
		# (held_item.gd _relight_on_press), so in hand it is its "relit_item", the burning torch.
		var as_held: Array = [id, str(table.entry(id).get("relit_item", id))]
		var in_left: bool = as_held.has(client.held.off_id())
		var held_here: bool = client.held.held_id() == id or in_left
		var drawn: bool = client.held._off_model != null if in_left else client.held._model != null
		held_ok += 1 if held_here else 0
		modelled += 1 if drawn else 0

		if not held_here or not drawn:
			print("Tools test: NOT held or no model: %s" % id)

		# Put it down: 190 tools in the pack outweigh the carrying limit, and the last heavy ones (the quern) were then never given (31 Oct 2026).
		net.inventory_action.rpc_id(1, Net.ACT_DROP, tool_slot, 0, 1, _player_position.call() + Vector3(0.0, 0.0, 2.0))
		await get_tree().create_timer(0.2).timeout

	print("Tools test: %d tools and weapons, held %d, with a model %d" % [tool_ids.size(), held_ok, modelled])


# Headless check (--chest): place a chest, open it, put stones in, take them out.
# Self-tests on a shared server start before the pack has arrived: wait for it (up to 30 s) so none reads `inventory.numbers` on Nil (Dino's finding, chest test).
func _wait_inventory_ready() -> bool:
	for wait in 100:
		if inventory != null:
			return true

		await get_tree().create_timer(0.3).timeout

	return inventory != null


func run_chest_test(client) -> void:
	await get_tree().create_timer(14.0).timeout

	if not await _wait_inventory_ready():
		print("Chest test: the pack never arrived")
		_finish_early(client)
		return

	_give_blueprint_kit(CHEST_MATERIALS)   # kits left the game (4 Nov 2026): the chest is built with the hammer from its blueprint
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, table.number_of("stone"), 0, 10, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	var id: int = 0

	# Place the chest and wait for it; a slow cloud world may not have the ground or the chest yet, so try again up to four times (the 04:18 rig run never saw the chest and then read a null chest_inv).
	for attempt in 4:
		var here: Vector3 = _player_position.call()
		var ground: float = float(_ground_below.call(here + Vector3(2.0, 0.0, 0.0)))

		if is_nan(ground):
			await get_tree().create_timer(2.0).timeout
			continue

		if not _has_blueprint_kit(CHEST_MATERIALS):
			_give_blueprint_kit(CHEST_MATERIALS)
			await get_tree().create_timer(1.0).timeout

		net.inventory_action.rpc_id(1, Net.ACT_PLACE_BLUEPRINT, CHEST_BLUEPRINT, 0, 0, Vector3(here.x + 2.0 + float(attempt), ground, here.z))

		for wait in 40:
			for k in _world:
				if _world[k]["state"] == 6:
					id = k

			if id != 0:
				break

			await get_tree().create_timer(0.1).timeout

		if id != 0:
			break

	if id == 0:
		print("Chest test: no chest was placed (no ground or the place was refused)")
		_finish_early(client)
		return

	_ask_open(id)

	for wait in 60:   # the cloud is slow: give the chest up to 6 s to open
		if chest_inv != null:
			break

		await get_tree().create_timer(0.1).timeout

	if chest_inv == null:
		print("Chest test: the chest did not open (no contents arrived)")
		_finish_early(client)
		return

	var stone: int = table.number_of("stone")
	net.inventory_action.rpc_id(1, Net.ACT_CHEST_PUT, inventory.numbers.find(stone), id, 7, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	print("Chest test: chest row %d, screen open %s, stones in chest %d, in pack %d" % [id, str(chest_mode), chest_inv.count_of(stone) if chest_inv != null else -1, inventory.count_of(stone)])

	if chest_inv == null:
		print("Chest test: the chest closed before the take")
		_finish_early(client)
		return

	net.inventory_action.rpc_id(1, Net.ACT_CHEST_TAKE, chest_inv.numbers.find(stone), id, 7, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	print("Chest test: after taking out, stones in chest %d, in pack %d" % [chest_inv.count_of(stone) if chest_inv != null else -1, inventory.count_of(stone)])

	# Quick key T moves the hovered pack stack into the open chest.
	var stone_slot: int = inventory.numbers.find(stone)
	_chest_hover = [false, _pack_view.find(stone_slot)]
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_T
	press.pressed = true
	quick_key(press)
	await get_tree().create_timer(1.0).timeout
	print("Chest test: quick key T, stones in chest %d, in pack %d" % [chest_inv.count_of(stone) if chest_inv != null else -1, inventory.count_of(stone)])
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
		net.inventory_action.rpc_id(1, Net.ACT_HIT, best[2], best[1].x, best[1].y, Vector3(float(inventory.numbers.find(table.number_of("stone_axe")) + 1), 0.0, 0.0))   # the given axe is the one in hand (protocol 115)
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PieceLook.finish_prewarm()     # the pictures worker started by the prewarm never outlives the view
