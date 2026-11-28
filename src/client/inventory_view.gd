extends Node
const PieceLook := preload("res://src/client/piece_look.gd")
const BuildStamp := preload("res://src/shared/build_stamp.gd")
const RecipeFilter := preload("res://src/client/recipe_filter.gd")
const CraftStock := preload("res://src/shared/craft_stock.gd")
const LyingLogs := preload("res://src/shared/lying_logs.gd")
const BoulderWear := preload("res://src/shared/boulder_wear.gd")
const BoulderFall := preload("res://src/shared/boulder_fall.gd")   # how long a dug-under rock takes to drop (boulders step 2)
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
const NpcCamp := preload("res://src/shared/npc_camp.gd")   # whose camp fire it is (owner_near)
const PlacementRules := preload("res://src/shared/placement_rules.gd")   # DOOR_TAKEN_M: a doorway frame and its door share one spot
const PipeRules := preload("res://src/shared/pipe_rules.gd")   # a laid pipe run is reached and aimed at along its whole length

# The client side of items: the inventory panel (I), things lying on the ground (E picks up
# the nearest within reach) and the player key. The server owns all of it; this only shows
# what the server says and asks. Nothing is built until the panel is first opened, and the
# world items are a handful of small meshes within 100 m (the server caps them per chunk).

const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const RecipeTableScript := preload("res://src/shared/recipe_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")
const BinRules := preload("res://src/shared/bin_rules.gd")   # resource bins: the resource surface (_note_bin, GOALS-REPAIR R6)
const StationUse := preload("res://src/client/ui/inventory/station_use.gd")
const StoreRules := preload("res://src/shared/store_rules.gd")   # what a store takes (the server's rule)

const VitalsRules := preload("res://src/shared/vitals_rules.gd")
const SmithingRules := preload("res://src/shared/smithing_rules.gd")   # sharpness, Tempered and craftsmanship (catalog Phase 2c)
const CharacterScreenScript := preload("res://src/client/character_screen.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const FlameRules := preload("res://src/shared/flame_rules.gd")   # a torch that went out (is_out)
const BagRules := preload("res://src/shared/bag_rules.gd")
const CoverScript := preload("res://src/shared/cover.gd")
const KeyBindings := preload("res://src/client/key_bindings.gd")
const FarmRules := preload("res://src/shared/farm_rules.gd")   # what E does on a tilled bed or garden plot (WP-R1B)
const CropLook := preload("res://src/client/crop_look.gd")   # the stage looks of a bed's crop
const TrackLook := preload("res://src/client/track_look.gd")   # boot prints to a bandit camp's pit
const KEY_FILE := "user://player_key.txt"
const STUCK_ARROW_BACK_M := 0.22         # an arrow stuck in a tree: its middle this far (model metres) back from the hit along its flight, the point just in the bark
const BASIC_DROP_SCALE := 1.8           # loose items with a stage-one look (basic_look.gd) are drawn this much bigger so they show in the grass
const MAX_FIRE_LIGHTS := 32             # Dave 18 Nov 2026: a fire always lights its ground, at any distance; was 1 to 3 by quality, so a fire went dark once 3 nearer lights (fires, lanterns, lit stations) took the slots. Shadowless omnis, culled by the engine off screen

var _flame_lights: Array = []           # the lit fire lights that are on (nearest MAX_FIRE_LIGHTS), set by _update_fire_lights
var open: bool = false
var _station_screen: int = 0   # the world id of the station, fire or container whose window is open: its Craft list shows only what it makes; 0 for your own inventory
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
const JournalScript := preload("res://src/client/ui/goals/journal_view.gd")         # the Journal: Index, Goals, Skills, Map (J, G, M)
const InventoryFrameScript := preload("res://src/client/ui/inventory/inventory_frame.gd")   # the redesign's three panels (step 3a)
const YouColumnScript := preload("res://src/client/ui/inventory/you_column.gd")             # the worn wells (R-HUD-INVENTORY-WORN)
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
var _you_box: VBoxContainer            # the You column's worn wells and stats
var _craft_root: Control               # the Craft column's recipes and card (recipe_list.gd); an open container shows in its place (4.4)
var _craft_tabs: Array = []            # the Chest and Craft tabs on the Craft panel's title row, shown while a container is open
var _text_buttons: Array = []          # Text - and Text + on the same row, hidden while the tabs are there
var chest_tab: bool = true             # with a container open: true shows the container, false the recipes (Craft still works with it open)
var _you_part: YouColumnScript         # the worn wells (you_column.gd)
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
var chest_autoload: int = 0             # the open container's standing autoload item, 0 none (protocol 139 autoload_info)
var reach_stock: Dictionary = {}        # item number -> count a craft may use besides the pack: loose stacks within 12 m and own containers within 12 m (craft_stock)
var _stock_sign: int = 0                # the pack as it was when the stock was last asked for; a changed pack asks again while the window is open
var _chest_panel: Control
const BOULDER_STATE := 10                 # the world-item row state of a boulder (server_items)
const BOG_STATE := 229                    # the world-item row state of a bog iron deposit (server_items._bog_rows_near)
var bogs: Dictionary = {}                 # bog patch world id -> {"pos", "left", "total", "r", "key", "lumps", "node"}: kept apart from _world; _show_bog draws the lumps
var bogs_rev: int = 0                     # moves on when a patch comes, goes or changes (terrain_client then hands them to the ground shader)
const BOG_LUMPS := 4                      # ore lumps on a full patch
var _boulders: Dictionary = {}            # boulder world id -> {node, shape, lump, pos, left, total, radius, now, shrink (the running ease, if any)}
var crown_landed: Callable = Callable()   # (centre Vector3, radius m): a felled crown hit the ground there; the client flattens the grass (Dave 10 Nov 2026)
var _boulder_mesh: ArrayMesh
var _skirt_meshes: Array = []        # the rocky ground's talus skirts (_skirt_mesh), SKIRT_VARIANTS of them, made once
var _skirt_hulls_made: Dictionary = {}   # their chunks' convex hulls by variant and size (_skirt_hulls)
var _rock_cells: Dictionary = {}    # 32 m cell -> {id: true}: the server rocks lying there
var _rock_draws: Dictionary = {}    # drawing block (ROCK_BLOCK cells a side) -> its MultiMeshInstance3D nodes (_rock_refill)
var _rock_dirty: Dictionary = {}    # blocks to draw again
var _field_rock: ShaderMaterial = null
var _rock_low: bool = false         # Low quality: lighter rocks (set_rock_quality)
var _rock_near: Dictionary = {}     # ids of the rocks with a body of their own (a server boulder without one has node, shape and lump null)
var _rock_added_frame: int = 0      # collision shapes made this frame (ROCK_SHAPES_PER_FRAME)
var _rock_look_msec: int = 0
var _rock_look_more: bool = false   # the last look ran out of its frame budget
var _boulder_rock: ShaderMaterial
var _boulder_cracks: ShaderMaterial   # the cracks drawn over a worked boulder (BugsList entry 3), one material, its depth per boulder (instance uniforms)
var _outcrop_rock: Dictionary = {}       # the boulder row's "ore" -> its own ShaderMaterial (OUTCROP_LOOK)
const OreRockLook := preload("res://src/client/ore_rock_look.gd")
const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")
# Outcrop boulders (Kathleen, 10 Nov 2026; Dave could not tell an ore boulder from a plain one). The server sends a boulder's "ore" (boulders.json ore:
# an ore body within reach, or the boulder's own limestone, chalk or marble); the client draws it in the same granite-and-moss shader with the stone tinted
# toward the ore's rock and mineral streaks through it, and the streaks keep the moss off. Subtle on purpose: read from about 10 m, not a neon tell.
# Copper, tin and iron are not here: they are their own rocks (OreRockLook, Dave's photos and words 16, 17 and 19 Nov 2026).
# ore: [stone tint, tint share, streak colour, streak width (0..0.5 of the band), flat (0 steep veins, 1 flat seams), halo share, fleck share]
const OUTCROP_LOOK := {
	"coal": [Color(0.07, 0.07, 0.07), 0.85, Color(0.015, 0.015, 0.015), 0.25, 1.0, 0.3, 0.0],    # near-black, flat black bands: a seam reads as coal (coordinator for Dave 22 Nov 2026: resources read as what they are)
	"salt": [Color(0.42, 0.4, 0.37), 0.4, Color(0.8, 0.78, 0.72), 0.16, 1.0, 0.2, 0.05],           # pale crusted beds
	"limestone": [Color(0.58, 0.55, 0.47), 0.7, Color(0.66, 0.63, 0.56), 0.04, 0.6, 0.0, 0.05],     # pale cream bedding
	"chalk": [Color(0.72, 0.71, 0.66), 0.75, Color(0.3, 0.3, 0.3), 0.03, 0.9, 0.0, 0.04],          # white, with dark flint bands
	"marble": [Color(0.64, 0.64, 0.62), 0.7, Color(0.42, 0.43, 0.45), 0.05, 0.3, 0.1, 0.0],         # grey veining
	# Pocket rocks a dig opens (resource distribution stage 2, boulders.json distribution pockets): small, freshly dug, so a clear tell.
	"gold": [Color(0.78, 0.76, 0.7), 0.6, Color(0.86, 0.66, 0.16), 0.08, 0.2, 0.0, 0.25],          # white quartz with gold specks
	"silver": [Color(0.36, 0.36, 0.37), 0.5, Color(0.78, 0.79, 0.82), 0.1, 0.3, 0.1, 0.15],         # dark rock with bright grey streaks
	"amethyst": [Color(0.55, 0.5, 0.58), 0.55, Color(0.55, 0.3, 0.75), 0.14, 0.4, 0.2, 0.2],       # a hollow lined with violet crystal
	"garnet": [Color(0.4, 0.38, 0.38), 0.5, Color(0.55, 0.08, 0.12), 0.06, 0.5, 0.0, 0.3],         # dark schist with red specks
	"agate": [Color(0.6, 0.5, 0.42), 0.55, Color(0.78, 0.46, 0.26), 0.12, 0.9, 0.1, 0.05],         # banded orange nodule
	"quartz": [Color(0.8, 0.8, 0.78), 0.65, Color(0.92, 0.95, 0.96), 0.1, 0.3, 0.1, 0.1],           # clear quartz crystals
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

# Holding E on a food, drink or medicine in the pack keeps using it (Dave 17 Nov 2026: "when you hold e on an item like a food or raspberries it
# should just keep eating them at a good speed"). One bite goes at a time: the next is sent only after the server has applied the last one
# (the slot changed), so the server checks every bite as for a tap and nothing can over-eat. The pace is the server's own (vitals.json
# eat_pace_ms, provisional EH-1 60 ms; drink_pace_ms for a water container) plus EAT_HOLD_SLACK_MSEC, since the server silently drops a bite
# sooner than that: about 9 bites a second (Dave 17 Nov: "the speed should be at least 3 times faster" than 2.5 a second). A bite the slot
# shows no sign of within EAT_HOLD_REFUSED_MSEC of its turn counts as refused. No resend: a resent refusal would repeat the server's notice.
const EAT_HOLD_SLACK_MSEC := 50   # room for network jitter: a bite that arrives too soon is dropped and ends the hold (press E again)
const EAT_HOLD_REFUSED_MSEC := 1000   # no change in the slot this long after a bite: the server said no (full, not known), stop
var _eat_hold_slot: int = -1          # the pack slot being eaten from while E is held, -1 when none
var _eat_hold_still: Callable = Callable()   # () -> true while the hold goes on: E on the same pack slot, or the hotbar key or click (eat_from_hotbar)
var _eat_hold_sign: Array = []        # the slot's number, count and wear when the last bite was sent
var _eat_hold_sent_msec: int = 0
var gather_event: Callable             # () when the player gathers something by hand (E): the view dips a little (no arm or body clip: Dave 17 Nov 2026)
var eat_event: Callable                # (item id) when something eaten or applied takes effect (sounds)
var bellows_event: Callable            # (where) each stroke of a smelter's worked bellows (sounds)
var worn_event: Callable               # (changed item ids Array, all worn item ids Array) when what is worn changes; changed is empty for the first list after joining (sounds)
var skill_up_event: Callable           # () when a skills message shows a skill's level higher than the last one (sounds; not on the first list after joining)
var hurt_event: Callable               # (health lost int) when a vitals update drops health by HURT_MIN or more (a bite, a fall): sounds
var _vitals_seen: bool = false          # the first vitals after joining sets health; it is not a hurt
const HURT_MIN := 4                     # a smaller drop is a slow drain (hunger, cold, bleeding), not a blow
var hunger: int = 100                  # stomach, percent
var fitness: int = 50                 # the character's fitness, 0 to 100 (50 average): how slowly exertion rises (character screen)
var training_today: int = 0           # today's training, percent of a fitness point (character screen; turns into fitness at game midnight)
var luck: int = 50                    # the character's luck, 0 to 100 (50 neutral), fixed (character screen)
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
var passing_out: bool = false                # the server's strain stance bit 16: past the faint threshold, falling (body_out)
var stance_confirmed: int = 0                # the server's answer: 0 stand, 1 crouch, 2 sit, 3 lie (fainting forces 3)
var notice_event: Callable = Callable()      # (text) every notice line, for the sounds that follow a server line (the shore net)
var hint_card = null                         # terrain_client's hint card (hint_card.gd): a guide hint goes on it, not on the passing line
var stance_event: Callable = Callable()      # (stance) when the server confirms or changes it
var lie_on_bed: Callable = Callable()        # (bed position, yaw degrees, structures.json row) after E on a bed: the client lays the player along it
var on_bed: Callable = Callable()            # () -> true while the player lies on a bed (E then gets them up)
var sit_on_seat: Callable = Callable()       # (seat position, yaw degrees, structures.json row) after E on a seat: the client sits the player on it
const SINK_M := 0.35                        # most the remains sink into the ground by day 7 (death.json sink_m)
const DEATH_FADE_S := 4.0                   # black, then waking, after a death (death.json respawn_delay_s)
var _death_msec: int = 0                    # when the last death arrived, 0 when none is being shown
var strength: int = 50                      # attributes the server sends with the skills (protocol 37), 0 to 100, 50 average
var memory: int = 50
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
var _moist_cfg: Dictionary = {}   # data/items/crops.json "moisture", read with it (_crop_cfg)
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
var pick_hand: Callable = Callable()         # (hotbar key 0-9) -> takes that key in hand, as the number keys do in the world (HeldItem.press_slot)
var hotbar_strip                              # HotbarStrip, set by the client
var status_strip                              # StatusIcons, the status strip left of the hotbar, set by the client
var heart_pulse                               # HeartPulse (the line over the hotbar), set by the client
var heart_bpm: Callable = Callable()   # () -> the heart rate now (the heartbeat sound's), set by the client
var _character                         # CharacterScreen, built the first time Tab is pressed
var _panel_bars: Dictionary = {}       # "Health", "Exertion", "Food", "Water" -> ProgressBar at the top of the inventory screen (the only bars in the game)
var _weight_label: Label
var _purse_label: RichTextLabel
var shoulder_id: String = ""                  # the first large log on the shoulder (protocol 64), "" when none: Mandy shows the carry pose from this; shoulder_logs() counts them all in the pack
var purse_copper: int = 0                      # the purse's worth in copper (what can be afforded)
var purse_coins: Dictionary = {}               # the purse as held, {coin id: count} (protocol 123): coins keep the denomination they came in until a trader changes them
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
	var ts_table: int = FrameProbe.start()
	table = ItemTableScript.load_default()
	FrameProbe.stop("items setup: item table", ts_table)
	var ts_recipes: int = FrameProbe.start()
	inventory = InventoryScript.pack(table)
	recipes = RecipeTableScript.load_default(table)
	FrameProbe.stop("items setup: inventory and recipe table", ts_recipes)
	net.inventory_full_received.connect(func(...args): _timed("_on_full", _on_full, args))
	net.inventory_slots_received.connect(func(...args): _timed("_on_slots", _on_slots, args))
	net.world_items_received.connect(func(...args): _timed("_queue_world_items", _queue_world_items, args))
	net.notice_received.connect(func(...args): _timed("_on_notice", _on_notice, args))
	net.chest_received.connect(_on_chest)
	net.chest_info_received.connect(_on_chest_info)
	net.autoload_info_received.connect(_on_autoload_info)
	net.chest_lock_received.connect(_storage_ui.on_lock)
	net.storage_view_received.connect(_storage_ui.on_view)
	net.food_effects_received.connect(_food_ui.on_effects)
	net.food_ask_received.connect(_food_ui.on_ask)
	net.craft_stock_received.connect(_on_craft_stock)
	net.cart_pull_received.connect(func(id: int, pace_dms: int): pulling_id = id; pull_pace_mps = float(pace_dms) / 10.0)
	net.items_moved_received.connect(_on_items_moved)
	net.logs_moved_received.connect(_on_logs_moved)
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
	net.soak_received.connect(func(percent: int, windy: bool): soak_percent = clampi(percent, 0, 100); soak_wind = windy)
	net.remains_received.connect(_on_remains_marks)
	net.worn_received.connect(_on_worn)
	net.thought_received.connect(func(...args): _timed("_on_thought", _on_thought, args))
	net.skills_received.connect(func(...args): _timed("_on_skills", _on_skills, args))
	net.purse_received.connect(_on_purse)
	net.carry_received.connect(func(item_id):
		shoulder_id = item_id

		if chest_mode:
			_container_part.refresh()

		if _weight_label != null:
			_refresh_weight())
	net.reputation_received.connect(func(_ids, names, points): rep_names = names; rep_points = points)
	var ts_goals: int = FrameProbe.start()
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
	FrameProbe.stop("items setup: goals and rule files", ts_goals)
	var ts_inter: int = FrameProbe.start()
	_register_builtin_interactables()
	FrameProbe.stop("items setup: interactables", ts_inter)
	var ts_warm: int = FrameProbe.start()
	if DisplayServer.get_name() == "headless":
		_prewarm_loose_meshes()   # tests and headless runs: all at once, as before
	else:
		_start_loose_prewarm()    # a window: a few meshes each frame while the ground loads
	FrameProbe.stop("items setup: loose mesh prewarm start", ts_warm)
	var ts_labels: int = FrameProbe.start()
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
	FrameProbe.stop("items setup: labels", ts_labels)
	net.hello.rpc_id(1, _player_key(), BuildStamp.stamped_build())   # a stamped server refuses another build (protocol 133)
	var me: Dictionary = CharacterStore.active()
	net.my_look.rpc_id(1, str(me.get("name", "")), str(me.get("body", "")), str(me.get("code", "")))   # protocol 151: how the other players see this character

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
	if _modal_up():
		return   # I over a talk, trade, lock-code or food prompt would stack a second window and capture the mouse from under it

	hotbar_hover = -1   # a hover left over from the last time the window was open never acts on a hotbar slot

	if chest_mode:
		_close_chest()
		return

	if not open and character_open():
		_character.toggle()

	if not open and journal != null and journal.open:
		journal.close()   # one window at a time

	open = not open

	if not open:
		_recipe_part.stop()   # a half-worked recipe list is dropped; the next open starts again
		_station_screen = 0   # the next open is your own inventory unless a station opens it

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

	if not open:
		_end_drag()


# Esc in the search box (while it has focus and holds text) empties it instead of closing the menu. True when it did.
func search_escape() -> bool:
	if _recipe_search == null or not open or not _recipe_search.has_focus() or _recipe_search.text == "":
		return false

	_recipe_search.clear()
	_refresh()
	return true


# A window that must be answered or shut first: a talk or trade, the lock-code or storage window, the food-replace prompt.
func _modal_up() -> bool:
	return dialogue_open or _storage_ui.is_open() or _food_ui.is_open()


func close() -> void:
	if _storage_ui.is_open():
		_storage_ui.close()
		return   # Esc shuts the lock or storage window first

	if _food_ui.is_open():
		_food_ui.close()
		_storage_ui._release_mouse()   # Esc on the food prompt alone gives the camera back, as the storage window does
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
	if chest_mode or _modal_up():
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
# whose point is inside the aim cone (in_aim) and best centred wins, whatever its priority (Dave 21 Nov 2026: "it should always effect whatever is closest
# to my reticle first"; every probe offers its own best centred thing, not its nearest, see reticle_index); E then does that one action and nothing else nearby (a chopping block
# in the cursor does not also gather the wood lying around it). Only when the cursor is on nothing with an E action does the priority order decide, which
# is where the nearby pick-up and gather live. "aimed" is set on a result that won because of the cursor.
func current_interaction() -> Dictionary:
	if pulling_id != 0:   # both hands on the handle: E only lets go (catalog Phase 10)
		return {"kind": "structure", "prompt": "Press E to let go of the %s" % str(_structure_by_state(int(_world.get(pulling_id, {}).get("state", -1))).get("vehicle", {}).get("noun", "cart")), "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_CART, 0, CART_RELEASE, 0, Vector3.ZERO)}

	var first: Dictionary = {}
	var best: Dictionary = {}
	var best_cos: float = -2.0

	for entry in _interactables:
		var found: Dictionary = entry["probe"].call()

		if found.is_empty():
			continue

		if first.is_empty():
			first = found

		if not found.has("point") or not view_direction.is_valid() or not in_aim(found["point"]):
			continue

		var aim_cos: float = aim_cos_of(found["point"])

		if aim_cos > best_cos + 0.0001:
			best_cos = aim_cos
			best = found

	if not best.is_empty():
		best["aimed"] = true
		return best

	return first


# Whether a point lies inside the aim cone round the reticle (interact.json aim_cos, about 25 degrees). Only the angle counts: each probe has already kept
# to its own reach, so a thing in reach and in the cone takes part whatever its distance (aimed_at, which also needs prompt_reach_m, decides only whether
# the "Press E" line shows). Unset view direction (tests) counts as in the cone.
func in_aim(point: Vector3) -> bool:
	return not view_direction.is_valid() or aim_cos_of(point) >= Interact.aim_cos()


# Of some aim points, the index of the one nearest the reticle (best centred inside the aim cone), -1 when none is in the cone or no view direction is
# known. Every probe chooses its thing with this, so E and the prompt act on what the reticle is on, never on the nearest thing beside it.
func reticle_index(points: Array) -> int:
	if not view_direction.is_valid():
		return -1

	var best: int = -1
	var best_cos: float = -2.0

	for n in range(points.size()):
		var aim_cos: float = aim_cos_of(points[n])

		if aim_cos >= Interact.aim_cos() and aim_cos > best_cos:
			best_cos = aim_cos
			best = n

	return best


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
	var id: int = _reticle_item()

	if id == 0:
		return {}

	return {"kind": "pickup", "id": id, "point": _world[id]["pos"], "prompt": "Press E to gather", "quiet": not aimed_at(_world[id]["pos"]), "tap": func():
		clear_prompt()
		var asked_msec: int = Time.get_ticks_msec()

		if not liftable(id):   # too heavy: no "too heavy" yet, held E may find something lighter around (Dave 10 Nov 2026)
			_pending_heavy = id
			_sweep_heavy = id
			return

		_last_pick = id
		_hold_took = true

		if _world.has(id) and aimed_at(_world[id]["pos"]):
			_reticle_took_msec = asked_msec   # the reticle's own item: held E waits reticle_pause_s before it goes on to what lies around

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
	_on_notice(CarryRules.logs_full_say(_carry_cfg) if _is_shoulder(number) and _logs_full() else "Too heavy to carry any more")
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
# for a large log, with fewer than two on the shoulder already. Not one the server refused this hold. Without a carry config (tests) everything can.
func liftable(id: int) -> bool:
	if not _world.has(id) or int(_world[id]["state"]) != 0 or _sweep_refused.has(id):
		return false

	var number: int = int(_world[id]["number"])

	if _is_shoulder(number) and _logs_full():
		return false

	if _carry_cfg.is_empty() or inventory == null:
		return true

	return CarryRules.fit_count(table.id_of(number), 1, carried_kg(), carry_body_kg(), _carry_cfg) > 0


func _is_shoulder(number: int) -> bool:
	return number > 0 and str(table.entry(table.id_of(number)).get("carry", "")) == "shoulder"


# A loose log the server's physics moves (server_items._rolls_item: the shoulder logs and the plain Log).
func _is_log(number: int) -> bool:
	return _is_shoulder(number) or (number > 0 and table.id_of(number) == "log")


# A log row's pose [rot_y, pitch, spin] (lying_logs.gd); a log the server has not turned yet lies at the turn it will give it (its id's golden angle).
func _row_pose(row: Array) -> Vector3:
	var extra: Dictionary = row[5] if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else {}
	return Vector3(float(extra.get("rot_y", fposmod(float(row[0]) * GOLDEN_ANGLE, TAU))), float(extra.get("pitch", 0.0)), float(extra.get("spin", 0.0)))


const GOLDEN_ANGLE := 2.399963   # as server_items.gd


# Walking into loose logs (Dave 16 Nov 2026: "If I walk into a log I should collide and at the same time I should push the log. the log will stop me
# but I should be able to push against it"; "sprinting should push harder"; "if you 1/4 into the log it will turn and push"). Called after the walker
# moves: `feet` the bottom of their upright capsule (radius p_r, height p_h), `move` the level way they are walking (m/s). Returns the level move that
# puts them clear of every log they walked into (they stop at it, and slide along it when they meet it slantwise), and asks the server to push each
# log they walk into, at the touching point, at most every PUSH_EVERY_MSEC a log. The logs are their drawn nodes (where the server's physics put them).
const PUSH_EVERY_MSEC := 100
const PUSH_NEAR_M := 4.0          # logs whose middle is this close are looked at
var _push_last: Dictionary = {}   # world id -> msec of the last push sent
var _logs_near: Array = []        # world ids of the logs near the walker, refreshed every LOGS_NEAR_MSEC
var _logs_near_msec: int = -100000
const LOGS_NEAR_MSEC := 250


func walker_logs(feet: Vector3, p_r: float, p_h: float, move: Vector3, sprint: bool) -> Vector3:
	var now: int = Time.get_ticks_msec()

	if now - _logs_near_msec >= LOGS_NEAR_MSEC:
		_logs_near_msec = now
		_logs_near = []

		for id in _world:
			var entry: Dictionary = _world[id]

			if entry.get("log", false) and not _falling.has(id) and Vector2(entry["pos"].x - feet.x, entry["pos"].z - feet.z).length() <= PUSH_NEAR_M:
				_logs_near.append(id)

	var out: Vector3 = Vector3.ZERO
	var level: Vector3 = Vector3(move.x, 0.0, move.z)

	for id in _logs_near:
		var entry: Dictionary = _world.get(id, {})

		if entry.is_empty() or not (entry.get("node") is Node3D) or _falling.has(id):
			continue

		var node: Node3D = entry["node"]
		var r: float = LyingLogs.LOG_R * float(entry.get("girth", 1.0))
		var touch: Dictionary = LyingLogs.walker_touch(feet + out, p_r, p_h, node.position, (node.quaternion * Vector3.RIGHT).normalized(), LyingLogs.LOG_HALF_M, r)

		if touch.is_empty():
			continue

		out += touch["out"]
		var into: Vector3 = -(touch["n"] as Vector3)
		var square: float = level.normalized().dot(into) if level.length() > PUSH_MIN_MPS else 0.0

		if square > 0.05 and now - int(_push_last.get(id, -100000)) >= PUSH_EVERY_MSEC and net != null:
			_push_last[id] = now
			var args: Array = LyingLogs.push_args(sprint, square, into)
			net.inventory_action.rpc_id(1, Net.ACT_PUSH_LOG, int(id), int(args[0]), int(args[1]), touch["at"])

	return out


const PUSH_MIN_MPS := 0.3   # slower than this the walker leans on the log without pushing it


# The item ids of the large logs in the pack, slot order: what is on the shoulders (up to weights.json shoulder_logs_max, as the server keeps it; protocol 64 names the first).
func shoulder_logs() -> Array:
	return CarryRules.shoulder_logs(inventory, table) if inventory != null else []


func _logs_full() -> bool:
	return shoulder_logs().size() >= CarryRules.shoulder_max(_carry_cfg)


# "Oak log, Beech log": the names of what is on the shoulder, for the weight line and the carried label.
func _carried_names() -> String:
	var names: PackedStringArray = PackedStringArray()

	for id in shoulder_logs():
		names.append(table.name_of(table.number_of(id)))

	return ", ".join(names)


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


# The first pack slot holding a torch that water or rain put out (flame_rules.gd is_out: marked out, or a dark lantern), or -1.
func _out_flame_slot() -> int:
	for slot in range(inventory.numbers.size()):
		if inventory.numbers[slot] != 0 and FlameRules.is_out(table.entry(table.id_of(inventory.numbers[slot])), inventory.inst_of(slot)):
			return slot

	return -1


func _probe_fire() -> Dictionary:
	var id: int = _nearest_fire()

	if id == 0:
		return {}

	var state: int = _world[id]["state"]

	if _lit_state(state) and _out_flame_slot() >= 0:
		# A torch that went out in the pack: E at a burning fire lights it again (Dave, 4 Nov 2026), instead of putting the fire out.
		return {"kind": "fire", "point": aim_point(id, _player_position.call()), "prompt": "Press E to light your torch", "tap": func():
			net.inventory_action.rpc_id(1, Net.ACT_RELIGHT, id, 0, 0, Vector3.ZERO)}

	var found: Dictionary = {"kind": "fire", "point": aim_point(id, _player_position.call()), "prompt": _fire_prompt(state), "tap": func():
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
		found["point"] = aim_point(near, _player_position.call())   # the middle of the thing, where the cursor rests: the spot _nearest_struct chose it by

	return found


func _probe_structure_for(id: int) -> Dictionary:
	if id == 0:
		return {}

	var state: int = _world[id]["state"]
	var take_down: Callable = func():
		clear_prompt()
		net.inventory_action.rpc_id(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)

	if _world[id].get("site") != null:   # a blueprint site: only a hammer hit adds the materials (Dave 18 Nov 2026); hold E takes it down and gives back what was put in
		return {"prompt": "Hit it with a hammer to add materials (hold E to take the blueprint down)", "lines": _site_lines(_world[id]["site"]), "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	if state == 11 or state == 12:
		return {"prompt": "Press E to search the remains", "tap": func(): _ask_open(id)}

	var cart_def: Dictionary = _structure_by_state(state)

	if cart_def.has("vehicle"):   # the Handcart, Small log sled and Small wagon (catalog Phase 10, W-14): E takes the handle, F opens its cargo, hold E takes it apart
		return {"prompt": "Press E to take the handle (F to open it, hold E to take it down)", "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_CART, id, CART_GRAB, 0, Vector3.ZERO), "hold": take_down}

	if bool(_world[id].get("on", false)):   # a crate riding on a cart: hold E sets it down beside the cart
		return {"prompt": "Press E to open (hold E to set it down off the cart)", "tap": func(): _ask_open(id), "hold": func():
			clear_prompt()
			net.inventory_action.rpc_id(1, Net.ACT_CART, id, CART_UNLOAD, 0, Vector3.ZERO)}

	if bool(cart_def.get("cargo", false)) and _cart_near(_world[id]["pos"]):   # a crate beside a cart: hold E lifts it on, with what it holds
		return {"prompt": "Press E to open (hold E to lift it onto the cart)", "tap": func(): _ask_open(id), "hold": func():
			clear_prompt()
			net.inventory_action.rpc_id(1, Net.ACT_CART, id, CART_LOAD, 0, Vector3.ZERO)}

	if str(_structure_by_state(state).get("use", "")) == "serve":   # a placed Serving Platter (catalog phase 8): E eats a portion of its board, or opens it to set one out
		var board: int = int(_world[id].get("board", 0))

		if board > 0:
			return {"prompt": "Press E to eat from the %s, %d left (hold E to take it up)" % [table.sentence_name(board), int(_world[id].get("portions", 0))], "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

		return {"prompt": "Press E to set a food board on the platter (hold E to take it up)", "tap": func(): _ask_open(id), "hold": take_down}

	if state == 7:   # tap splits, hold picks up, like the other structures (Dave 2 Nov 2026, bug 2); F chops logs from storage nearby (master s2.4)
		return {"prompt": "Press E to split a wooden block into firewood, F for its store%s (hold E to pick up the block)" % _fill_note(id), "tap": func(): _use_block(id), "hold": take_down}

	var store_def: Dictionary = _structure_by_state(state)

	if str(store_def.get("use", "")) == "kiln":   # a kiln (master s2.6; Primitive, Improved, Advanced): E lights it and puts it out, like a fire; F for its wood and charcoal
		return {"prompt": "Press E to %s, F for its wood and charcoal%s (hold E to take it down)" % ["put the kiln out" if bool(_world[id].get("lit", false)) else "light the kiln", _fill_note(id)], "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	if str(store_def.get("use", "")) == "smelt":   # a Smelter, like a campfire (Dave 17 Nov 2026): E lights it, E puts it out, F opens its store
		var use_tap: Callable = func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO)

		if not bool(_world[id].get("lit", false)):
			return {"prompt": "Press E to light", "tap": use_tap, "hold": take_down}   # Dave: "it should say Press E to light. thats it."

		if bool(store_def.get("smelt", {}).get("bellows", false)):   # the Improved smelter: E works its bellows or leaves them (the row's "bellows"), hold E puts it out
			var at_bellows: int = int(_world[id].get("bellows", 0))
			var bellows_line: String = "Press E to stop using the bellows" if at_bellows == 2 else ("Someone else is working the bellows" if at_bellows == 1 else "Press E to work the bellows")   # Dave 21 Nov 2026
			return {"prompt": bellows_line + " (hold E to put it out)", "tap": use_tap, "hold": func():
				clear_prompt()
				net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 1, 0, Vector3.ZERO)}

		return {"prompt": "Press E to put out", "tap": use_tap}

	if str(store_def.get("station", "")) != "" and (int(store_def.get("out_slots", 0)) > 0 or bool(store_def.get("one_store", false))):   # a station with a store (master s2.5): E opens the store, F crafts
		return {"prompt": "Press E to open the %s%s, F to use it%s (hold E to take it down)" % [table.sentence_name(_world[id]["number"]), _fill_note(id), wheel_note(id)], "tap": func(): _ask_open(id), "hold": take_down}

	if str(_structure_by_state(state).get("use", "")) == "tap":   # a Copper - Tap (Dave 19 Nov 2026): E drinks, F opens its slots where water containers fill
		return {"prompt": "Press E to take a drink, F to fill water containers (hold E to take it down)", "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	if _is_chest(state) and bool(_structure_by_state(state).get("fills_containers", false)):   # a Water barrel (Dave 22 Nov 2026): E drinks or fills what you hold, F opens its 3 slots where water containers fill
		return {"prompt": "Press E to drink, or to fill what you hold, F to fill water containers (%d L in it; hold E to take it down)" % int(_world[id].get("water_l", 0)), "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_DRINK, held_container_slot(), 0, 0, Vector3.ZERO), "hold": take_down}

	if _is_chest(state):
		return {"prompt": "Press E to open (hold E to take it down)", "tap": func(): _ask_open(id), "hold": take_down}

	if state == 33:
		return {"prompt": "Press E to take the stones back (hold E to pick up the pile)", "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	if str(_structure_by_state(state).get("piece_kind", "")) == "door":   # a door in a doorway (BUGLIST-002): a shut one has blocks_walk; the empty frame has no use and falls through to "take down"
		return {"prompt": "Press E to close the door" if not bool(_structure_by_state(state).get("blocks_walk", false)) else "Press E to open the door", "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	var station_def: Dictionary = _structure_by_state(state)

	if _is_bed_def(station_def):   # a tilled bed or garden plot (FARMING_SPEC.md steps 3 to 5): E waters or harvests; a plot, which has a kit, still comes down with hold E
		return _bed_interaction(id, station_def, take_down)

	if str(station_def.get("use", "")) == "storage_view":   # a Storage sign or Warehouse desk (catalog phase 9): E shows what the containers round it hold
		return {"prompt": "Press E to see what is stored here (hold E to take it down)", "tap": func(): _storage_ui.ask_view(id), "hold": take_down}

	if str(station_def.get("use", "")) == "set_spawn":   # a bed: E lies down on it and makes it the spawn point (Dave 4 Nov 2026), hold E takes it down
		if on_bed.is_valid() and bool(on_bed.call()):   # lying on it already: E gets up (Dave 18 Nov 2026, "lay on it"; Z and the movement keys still get up too)
			return {"prompt": "Press E to get up", "tap": func(): lie_on_bed.call(Vector3.ZERO, 0.0, {})}

		var bed: Dictionary = {"prompt": "Press E to lie down (hold E to take it down)", "hold": take_down}
		bed["tap"] = func():
			net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO)

			if lie_on_bed.is_valid() and _world.has(id):
				lie_on_bed.call(_world[id]["pos"], float(_world[id].get("yaw", 0.0)), station_def)

		return bed

	if str(station_def.get("use", "")) == "sit":   # a seat (docs/COMFORT_DESIGN.md 10.3; Dave 5 Nov 2026 "we need a sitting on a chair action"): E sits on it, hold E takes it down
		var seat: Dictionary = {"prompt": "Press E to sit (hold E to take it down)", "hold": take_down}
		seat["tap"] = func():
			if sit_on_seat.is_valid() and _world.has(id):
				sit_on_seat.call(_world[id]["pos"], float(_world[id].get("yaw", 0.0)), station_def)

		return seat

	# Water pieces (buildables plan section 6): E works a well (E again stops), E at a trough, barrel or cistern drinks, or fills the container in hand.
	var water: Variant = station_def.get("water", {})

	if typeof(water) == TYPE_DICTIONARY and str(water.get("role", "")) == "source" and bool(water.get("windlass", false)):
		return {"prompt": "Press E to work the %s, E again to stop (hold E to take it down)" % table.sentence_name(_world[id]["number"]), "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	if str(station_def.get("use", "")) == "water_gate":   # a Sluice or Tap (plumbing PR 2): E opens or shuts it; the open twin has water "open" true
		var is_open: bool = typeof(water) == TYPE_DICTIONARY and bool(water.get("open", true))
		return {"prompt": "Press E to %s the %s (hold E to take it down)" % ["shut" if is_open else "open", table.sentence_name(_world[id]["number"])], "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

	if typeof(water) == TYPE_DICTIONARY and str(water.get("role", "")) == "tank":
		return {"prompt": "Press E to drink, or to fill what you hold (hold E to take it down)", "tap": func(): net.inventory_action.rpc_id(1, Net.ACT_DRINK, held_container_slot(), 0, 0, Vector3.ZERO), "hold": take_down}

	if str(station_def.get("station", "")) != "":
		return {"prompt": "Press E or F to use the %s%s" % [table.sentence_name(_world[id]["number"]), wheel_note(id)], "tap": _open_station.bind(id), "hold": take_down}

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

	var item: String = str(station_def.get("item", ""))

	if item in TRAP_ITEMS:   # a snare or bird trap: one holding its catch offers it (Dave 25 Nov 2026: E collects the animal and resets the snare)
		var trap_name: String = "snare" if item == "snare_trap" else "bird trap"
		var held: int = catch_in(id)

		if held != 0 and bool(_world[held].get("whole", false)):
			return {"prompt": "Press E to collect the %s and reset the %s (hold E to take the %s down)" % [CarcassLook.dead_name(str(_world[held].get("sp", ""))).to_lower(), trap_name, trap_name], "tap": func():
				clear_prompt()
				net.inventory_action.rpc_id(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO), "hold": take_down}

		if held != 0:
			return {"prompt": "Finish cutting the %s with your knife (hold E to take the %s down)" % [CarcassLook.dead_name(str(_world[held].get("sp", ""))).to_lower(), trap_name], "tap": func(): show_notice("Finish it with your knife"), "hold": take_down}

	if state == CARCASS_STATE:   # a carcass: a trap's catch put down again is taken whole; anything else is cut with a knife where it lies
		if bool(_world[id].get("whole", false)):
			return {"prompt": "Press E to pick up the %s" % CarcassLook.dead_name(str(_world[id].get("sp", ""))).to_lower(), "tap": func():
				clear_prompt()
				net.inventory_action.rpc_id(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)}

		return {"prompt": "Cut the %s with a knife" % CarcassLook.dead_name(str(_world[id].get("sp", ""))).to_lower(), "tap": func(): show_notice("Cut it with a knife")}

	return {"prompt": "Hold E to take down the %s" % table.sentence_name(_world[id]["number"]), "tap": func(): show_notice("Hold E to take it down"), "hold": take_down}


func _is_bed_def(def: Dictionary) -> bool:
	return str(def.get("item", "")) == "tilled_bed" or bool(def.get("plot", false))


# The tilled bed or garden plot whose square footprint holds `point` (flat), 0 for none: the hoe's Garden mode sows it (held_item._garden_here).
func bed_id_at(point: Vector3) -> int:
	return bed_in(bed_rows(), point)


# Every bed and plot standing (not a blueprint site) as [id, position, half footprint + 5 cm, yaw degrees], read once for a whole hoe grid (held_item._grid_request).
func bed_rows(near: Vector3 = Vector3.INF, radius: float = 0.0) -> Array:   # `near`/`radius`: only the beds within that flat distance (the hoe grid's area)
	var rows: Array = []

	for id in _world:
		if not _world[id].has("yaw") or int(_world[id]["state"]) < 5 or _world[id].get("site") != null:   # a plot's blueprint site is not a bed yet (the server refuses it)
			continue

		if near.is_finite() and Vector2(_world[id]["pos"].x - near.x, _world[id]["pos"].z - near.z).length() > radius:
			continue

		var def: Dictionary = _structure_by_state(int(_world[id]["state"]))

		if _is_bed_def(def):
			rows.append([int(id), _world[id]["pos"], float(def.get("footprint_x", 1.0)) * 0.5 + 0.05, float(_world[id]["yaw"])])

	return rows


static func bed_in(rows: Array, point: Vector3) -> int:
	for row in rows:
		if FarmRules.on_square(Vector2(point.x, point.z), Vector2(row[1].x, row[1].z), float(row[2]), float(row[3]) if row.size() > 3 else 0.0):   # a turned bed or plot by its own square
			return int(row[0])

	return 0


# The crop on a bed from its world row ("" for an empty bed or an unknown id); on a plot of several square metres, the crop of the one nearest `at`.
func bed_crop(id: int, at: Vector3 = Vector3.INF) -> String:
	var rec: Dictionary = _world.get(id, {})
	var cells: Array = rec.get("cells", [])

	if cells.is_empty() or at == Vector3.INF:
		return str(rec.get("crop", "")) if cells.is_empty() else ""

	var k: int = bed_cell_index(id, at)
	return str(cells[k][0]) if k >= 0 and k < cells.size() else ""


# Which square metre of a bed `at` falls on (0 for a 1 m bed, a pot or a planter; -1 for an unknown id), in the server's _bed_cells order.
func bed_cell_index(id: int, at: Vector3) -> int:
	if not _world.has(id):
		return -1

	var rec: Dictionary = _world[id]
	var n: int = FarmRules.bed_side(_structure_by_state(int(rec["state"])))
	var best: int = 0
	var spots: Array = FarmRules.grid_points(n, n, 1.0, Vector2(rec["pos"].x, rec["pos"].z), int(round(float(rec["yaw"]))))

	for k in spots.size():
		if (spots[k] as Vector2).distance_to(Vector2(at.x, at.z)) < (spots[best] as Vector2).distance_to(Vector2(at.x, at.z)):
			best = k

	return best


# The crops.json table, for the hoe's Garden list (which seeds sow a crop).
func crop_table() -> Dictionary:
	return _crop_cfg()


# The tree seeds, item id -> species (drops.json trunk.felled_seeds by_species, read once), for the hoe's Garden list.
func tree_seed_table() -> Dictionary:
	if _tree_seeds.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
		var by: Dictionary = (((parsed as Dictionary).get("trunk", {}) as Dictionary).get("felled_seeds", {}) as Dictionary).get("by_species", {}) if typeof(parsed) == TYPE_DICTIONARY else {}

		for species in by:
			if not _tree_seeds.has(str(by[species])):
				_tree_seeds[str(by[species])] = str(species)

		if _tree_seeds.is_empty():
			_tree_seeds = {"": ""}   # read once even when there are none

	return _tree_seeds


var _tree_seeds: Dictionary = {}


# crops.json, read once: the client's wording needs the crop names, seeds and harvest tools (the server rules on all of it).
func _crop_cfg() -> Dictionary:
	if _crops_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/crops.json"))
		_crops_cfg = parsed.get("crops", {}) if typeof(parsed) == TYPE_DICTIONARY else {"none": {}}
		_moist_cfg = parsed.get("moisture", {}) if typeof(parsed) == TYPE_DICTIONARY else {}   # the look-at line's words for the soil (FarmRules.soil_words)

	return _crops_cfg


# E on a bed: the one request FarmRules.bed_action words (water with the filled container in hand, harvest a ripe crop; never a sow: that is the hoe's Plant grid). The
# server does the checking; a refusal (not ripe, too far) comes back as its notice.
func _bed_interaction(id: int, def: Dictionary, take_down: Callable) -> Dictionary:
	var row: Dictionary = _world[id]
	var water_slot: int = held_container_slot() if held_container_has_water() else -1
	var plan: Dictionary = FarmRules.bed_action(_crop_cfg(), str(row.get("crop", "")), int(row.get("stage", 0)), water_slot, int(row.get("moist", -1)), _moist_cfg)
	var found: Dictionary = {"prompt": plan["prompt"], "tap": func(): _bed_tap(id, plan)}

	if str(def.get("kit", "")) != "":
		found["hold"] = take_down

	return found


# Sends the one request the bed's plan names (a block body in a lambda inside a dictionary literal does not parse with a match in it: hence a method).
func _bed_tap(id: int, plan: Dictionary) -> void:
	match str(plan["act"]):
		"harvest":
			net.inventory_action.rpc_id(1, Net.ACT_HARVEST, id, 0, 0, Vector3.ZERO)
		"water":
			net.inventory_action.rpc_id(1, Net.ACT_WATER_BED, id, int(plan["b"]), 0, Vector3.ZERO)   # b: the container in hand, which the server draws the water from
		_:
			show_notice(str(plan["prompt"]))


# A bed's crop and stage from its world row (server_items.crop_row_extra): kept on the record for the E prompt, with its stage look (CropLook: the wild plant's own model
# where flora.json has one, else a PLACEHOLDER) hung on the bed's node; swapped when the stage changes and dropped when the crop is gone (harvest, frost). A look made while the
# flora models were still being built is a placeholder for now: the bed waits in _crop_looks_waiting and is drawn again once they are (_redo_crop_looks).
var crop_model: Callable = Callable()        # (crop id, share of height, spots) -> Node3D or null: FloraView.crop_model, set by the client; unset (tests) gives placeholders
var crop_models_ready: Callable = Callable()  # () -> true once every wild plant's model is built (FloraView.models_ready)
var _crop_looks_waiting: Dictionary = {}     # bed world id -> true: drawn with a placeholder while the flora models were not all built
var _crop_looks_msec: int = 0


func _note_crop(id: int, row: Array, again: bool = false) -> void:
	var extra: Dictionary = row[5] if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else {}
	var crop: String = str(extra.get("crop", ""))
	var stage: int = int(extra.get("stage", 0)) if crop != "" else -1
	var cells: Array = extra.get("cells", [])   # a plot of several square metres: one crop each (server_items.crop_row_extra)
	var rec: Dictionary = _world[id]

	if not again:
		rec["moist"] = int(extra.get("moist", -1))   # the soil's moisture for the E prompt (FarmRules.soil_words); a redrawn look's row may be older

	if not again and str(rec.get("crop", "")) == crop and int(rec.get("stage", -1)) == stage and str(rec.get("cells", [])) == str(cells):
		return

	if is_instance_valid(rec.get("crop_node")):
		(rec["crop_node"] as Node).queue_free()

	rec["crop"] = crop
	rec["stage"] = stage
	rec["cells"] = cells
	rec["crop_node"] = null
	rec["crop_row"] = row
	_crop_looks_waiting.erase(id)
	var bed_def: Dictionary = _structure_by_state(int(rec["state"]))
	var looks: Array = []

	if not cells.is_empty():
		var holder: Node3D = Node3D.new()   # a crop look on each square metre, laid out as the server's _bed_cells (the bed's node is already turned)
		var n: int = FarmRules.bed_side(bed_def)
		var spots: Array = FarmRules.grid_points(n, n, 1.0, Vector2.ZERO, 0)

		for k in mini(cells.size(), spots.size()):
			if str(cells[k][0]) != "":
				var one: Node3D = CropLook.build(str(cells[k][0]), int(cells[k][1]), 1.0, crop_model)
				one.position = Vector3(spots[k].x, float(bed_def.get("soil_y", 0.0)), spots[k].y)
				holder.add_child(one)
				looks.append(one)

		(rec["node"] as Node3D).add_child(holder)
		rec["crop_node"] = holder
	elif crop != "":
		var look: Node3D = CropLook.build(crop, stage, minf(float(bed_def.get("footprint_x", 1.0)), float(bed_def.get("footprint_z", bed_def.get("footprint_x", 1.0)))), crop_model)
		look.position.y = float(bed_def.get("soil_y", 0.0))   # a planter's soil is raised (structures.json soil_y); a bed or plot grows from the ground
		(rec["node"] as Node3D).add_child(look)
		rec["crop_node"] = look
		looks.append(look)

	if crop_models_ready.is_valid() and not bool(crop_models_ready.call()) and looks.any(func(l): return bool(l.get_meta("placeholder", false))):
		_crop_looks_waiting[id] = true


# Once a second while some bed waits: when the flora models are all built, its crop look is made again (the wild plant's model where there is one).
func _redo_crop_looks() -> void:
	if _crop_looks_waiting.is_empty() or Time.get_ticks_msec() < _crop_looks_msec:
		return

	_crop_looks_msec = Time.get_ticks_msec() + 1000

	if crop_models_ready.is_valid() and not bool(crop_models_ready.call()):
		return

	var waiting: Array = _crop_looks_waiting.keys()
	_crop_looks_waiting.clear()

	for id in waiting:
		if _world.has(id) and _world[id].has("crop_row") and is_instance_valid(_world[id].get("node")):
			_note_crop(id, _world[id]["crop_row"], true)


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

	if body_out():
		_e_active = {}   # passing out, fainted or waking: an E begun before does not go off (QA #19)
		return

	var found: Dictionary = _e_active
	_e_active = {}
	found["tap"].call()


func _hold_e_check() -> void:
	if _e_active.is_empty() or not KeyBindings.held("interact"):
		return

	if body_out():
		_e_active = {}   # passing out: a hold E begun before does not finish (QA #19)
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
# The id of the chest, station, fire or remains within reach of the player (0 when none): what F opens. Like E, the one nearest the reticle when any is
# in the aim cone, otherwise the nearest (Dave 21 Nov 2026), so E and F work the same thing of two side by side.
func _container_near() -> int:
	var here: Vector3 = _player_position.call()
	var ids: Array = []

	for id in _world:
		var state: int = int(_world[id]["state"])
		var is_station: bool = str(_structure_by_state(state).get("station", "")) != ""

		if (is_station or _is_chest(state) or state == 11 or state == 12 or _lit_state(state) or StructureLook.is_unlit_fire(state)) and not _world[id].get("camp", false) and here.distance_to(_world[id]["pos"]) <= PIECE_REACH_M:
			ids.append(id)

	return _aimed_or_nearest(ids, here)


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

	if str(best_def.get("station", "")) != "" and (int(best_def.get("out_slots", 0)) > 0 or bool(best_def.get("one_store", false))):   # a station with a store: its window, on the Craft tab (the Kiln: on its store)
		_ask_open(best, str(best_def.get("use", "")) != "kiln")
		return true

	if str(best_def.get("station", "")) != "":
		_open_station(best)
		return true

	_ask_open(best)
	return true


# A workbench or forge has no slots of its own: using it opens the crafting screen, which lists only what that station makes (station_makes).
func _open_station(id: int) -> void:
	_station_screen = id
	_recipe_part.show_category("")   # a station's list starts on All: a tab left from before (the saw's Carpenter's) would show it empty

	if not open:
		toggle()
	else:
		_refresh()


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
	_redo_crop_looks()
	_flicker_flames()

	if _recipe_part.running():
		var t_list: int = FrameProbe.start()
		_recipe_part.step()
		FrameProbe.stop("inventory: recipe list", t_list)

	if not _warm_queue.is_empty():
		var tw: int = FrameProbe.start()
		_warm_step()
		FrameProbe.stop("inventory: loose mesh prewarm", tw)

	if not _hull_queue.is_empty():
		var th: int = FrameProbe.start()
		_hull_step()
		FrameProbe.stop("inventory: rock hull prewarm", th)

	if not _rock_dirty.is_empty() or not _rock_near.is_empty() or not _rock_cells.is_empty():
		var t_rocks: int = FrameProbe.start()
		_rock_tick()
		FrameProbe.stop("inventory: rocks near and drawn", t_rocks)

	var t: int = FrameProbe.start()
	_drain_world_backlog()
	FrameProbe.stop("inventory: world items", t)   # the pieces of a 65 ms "inventory view" in the 5 Nov lag run's one HITCH
	var now: int = Time.get_ticks_msec()
	_hotbar_press_tick(now)
	_eat_hold_tick(now)
	t = FrameProbe.start()
	_roll_tick(_delta, now)
	_glide_tick(_delta)
	_snap_tick(now)
	_hold_e_check()
	_auto_pickup_tick(now)
	FrameProbe.stop("inventory: roll, snap, hold E, pickup", t)

	if _thought_label != null and _thought_label.text != "" and now >= _thought_until_msec:
		_thought_label.text = ""

	# Over-exerted is the status strip's symbol now (its hover line says why and what to do): this note keeps only what to press while asleep.
	if _strain_note != null:
		_strain_note.text = KeyBindings.localize("Exhausted: you sleep until you are rested, about %d min left%s" % [maxi(int(ceil(float(sleep_eta_s) / 60.0)), 1), "; hold Space to wake early" if energy >= 30 else " (hold Space to wake early once energy is 30 percent)"]) if forced_sleep else "Asleep: any key wakes you" if asleep else ""

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

	if _prompt.text == "" and stance_confirmed == 3 and not asleep and not body_out():
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
		if (skip_fires and int(_world[id]["state"]) in StructureLook.CAMPFIRE_STATES) or _world[id].get("camp", false):
			continue   # Edda and Hob's fire is never offered

		if _world[id]["state"] >= 5 and _world[id]["state"] != 32 and here.distance_to(reach_pos(id, here)) <= PIECE_REACH_M:
			ids.append(id)

	return _aimed_or_nearest(_untrapped(_unframed(ids)), here)


# A trap's catch lies in the trap (Dave 25 Nov 2026): E works the trap (collect the catch and set it again), so the carcass a trap among the
# candidates holds (its row's "catch", from the server) is left out.
const TRAP_ITEMS := ["snare_trap", "bird_trap_set"]   # traps.json kinds (as map_knowledge.gd TRAP_KINDS)
const CARCASS_STATE := 19


func _untrapped(ids: Array) -> Array:
	var held: Dictionary = {}

	for id in ids:
		if int(_world[id].get("catch", 0)) != 0:
			held[int(_world[id]["catch"])] = true

	if held.is_empty():
		return ids

	var out: Array = []

	for id in ids:
		if not held.has(int(id)):
			out.append(id)

	return out


# A structure row's trap and carcass extras (server_items _struct_extra): a trap's "catch" (absent: it holds none), a carcass's animal and
# whether E takes it whole. Kept on the row's entry when it is first drawn and each time it is re-sent.
func _note_catch(id: int, extra: Variant, state: int) -> void:
	if typeof(extra) != TYPE_DICTIONARY:
		return

	if (extra as Dictionary).has("catch"):
		_world[id]["catch"] = int(extra["catch"])
	else:
		_world[id].erase("catch")

	if state == CARCASS_STATE:
		_world[id]["sp"] = str(extra.get("sp", ""))
		_world[id]["whole"] = bool(extra.get("whole", false))


# The carcass lying in trap `trap` (the server's link), 0 for none.
func catch_in(trap: int) -> int:
	var c: int = int(_world[trap].get("catch", 0))
	return c if _world.has(c) else 0


# Where a world piece is reached from `here`: a laid pipe run's nearest point (PLUMBING_DESIGN s9: a 30 m run is taken down from anywhere along it),
# otherwise its spot.
func reach_pos(id: int, here: Vector3) -> Vector3:
	var row: Dictionary = _world[id]

	if not row.has("len"):
		return row["pos"]

	var e: Array = PipeRules.ends(row["pos"], float(row.get("yaw", 0.0)), float(row.get("pitch", 0.0)), float(row["len"]))
	return PipeRules.closest_on(e[0], e[1], here)


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


# Of some world ids: the one nearest the reticle (reticle_index on their aim points) when any is in the aim cone, otherwise the nearest; 0 for none.
func _aimed_or_nearest(ids: Array, here: Vector3) -> int:
	var points: Array = []

	for id in ids:
		points.append(aim_point(id, here))

	var aimed: int = reticle_index(points)

	if aimed >= 0:
		return ids[aimed]

	var best: int = 0
	var best_d: float = 1.0e9

	for id in ids:
		var d: float = here.distance_to(reach_pos(id, here))

		if d < best_d:
			best_d = d
			best = id

	return best


# The spot of a fire or placed piece the reticle is judged against, the same one its probe offers the E contest: a fire a little above its pit, any other
# piece the middle of it (its reach_pos, raised to where the cursor rests).
func aim_point(id: int, here: Vector3) -> Vector3:
	return reach_pos(id, here) + Vector3(0.0, 0.3 if int(_world[id]["state"]) in StructureLook.CAMPFIRE_STATES else 0.4, 0.0)


# The loose item E acts on: of the items in view, the one nearest the reticle (in the aim cone) out to PIECE_REACH_M, as far as fires and placed pieces are
# offered, so a fire or station beside it never wins only because the item is a little farther away (the server allows Interact.server_reach_m()).
# With none in the cone, the nearest within reach_m, as before. 0 for none.
func _reticle_item() -> int:
	var here: Vector3 = _player_position.call()
	var ids: Array = []
	var points: Array = []

	for id in _world:
		if _world[id]["state"] == 0 and here.distance_to(_world[id]["pos"]) <= PIECE_REACH_M and in_view(_world[id]["pos"]):
			ids.append(id)
			points.append(_world[id]["pos"])

	var aimed: int = reticle_index(points)
	return ids[aimed] if aimed >= 0 else int(_nearest(true)[0])


const PIECE_REACH_M := 3.0   # how far E reaches a fire or placed piece on the client (and an item the reticle is on); the server allows Interact.server_reach_m()


# The id of the fire (lit or out) within 3 m that the cursor is on, else the nearest one; 0 when none. Never Edda and Hob's fire: players cannot use it.
func _nearest_fire() -> int:
	var here: Vector3 = _player_position.call()
	var ids: Array = []

	for id in _world:
		if _world[id]["state"] in StructureLook.CAMPFIRE_STATES and not _world[id].get("camp", false) and here.distance_to(_world[id]["pos"]) <= PIECE_REACH_M:
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


# The nearest carcass within 3 m of a point (the knife works it), or 0.
func carcass_near(point: Vector3) -> int:
	var best: int = 0
	var best_d: float = 3.2

	for id in _world:
		var entry: Dictionary = _world[id]

		if entry["state"] == CARCASS_STATE and is_instance_valid(entry["node"]):
			var d: float = point.distance_to(entry["pos"])

			if d < best_d:
				best_d = d
				best = id

	return best


# A log or wooden block lying loose on the ground within 1.5 m of the point, the nearest, 0 when none: the axe splits a block into firewood and says to saw a log
# first (TREE_WOOD_TOOLS_DESIGN.md); a pick tears a log into kindling.
func loose_log_near(point: Vector3) -> int:
	var best: int = 0
	var best_d2: float = 2.25

	for id in _world:
		var entry: Dictionary = _world[id]

		if int(entry["state"]) != 0 or not entry.has("number") or int(entry["number"]) == 0:
			continue

		# The distance first: only the few items within 1.5 m pay for the item table lookups (this runs over every loose item on each blow that lands).
		var d2: float = entry["pos"].distance_squared_to(point)

		if d2 >= best_d2:
			continue

		var item_id: String = table.id_of(int(entry["number"]))

		if item_id == "log" or item_id == "wooden_block" or str(table.entry(item_id).get("carry", "")) == "shoulder":
			best = id
			best_d2 = d2

	return best


# The id of a stump within reach of a point (the axe struck near it), 0 when none: the axe chops it up (server_items.gd _chop_stump).
func stump_near(point: Vector3) -> int:
	for id in _world:
		var entry: Dictionary = _world[id]

		if int(entry["state"]) == 4 and is_instance_valid(entry["node"]):
			var radius: float = float(entry.get("extra", {}).get("radius", 0.3))

			if Vector2(point.x - entry["pos"].x, point.z - entry["pos"].z).length() < radius + 0.9 and absf(point.y - entry["pos"].y) < 1.6:
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

	if hint_card != null and hint_card.offer(text):
		return   # it waits for its OK box (R-HUD-HINT-BOX)

	_prompt.text = KeyBindings.localize(text)
	_prompt.move_to_front()   # over the inventory window, which is built later on the same layer: a refusal while crafting was hidden under it (Dave 23 Nov 2026)

	if _site_list != null:
		_site_list.visible = false
	_notice_until_msec = Time.get_ticks_msec() + 4000


# Trunks are solid, but only the ones near the player keep a collider (cost cap).
func _update_trunk_colliders() -> void:
	var here: Vector3 = _player_position.call()

	for pair in _collide:
		if is_instance_valid(pair[0]):
			pair[1].collision_layer = 1 if pair[0].global_position.distance_to(here) < 40.0 else 0


# The bark of a stump: the standing trees' bark shader (src/flora/flora_view.gd) with the species texture and tint, so a lying log is not a flat dark drum (guide, 2026-10-31).
# One Shader shared by every stump and log: a new Shader per call made the GPU compile the same bark shader again on each cut of a fallen tree (the old trunk was rebuilt when it
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


# A stump (state 4): a short bark drum with a pale cut face and a darker ring on top and root swell round its foot. A felled tree's logs are ordinary loose
# items (_swing_down brings them down). A stump the server still marks "fresh" belongs to a tree that is falling now: its crown's grass lies flat once the
# tree is down (FALL_S).
func _make_felled(extra: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var radius: float = float(extra.get("radius", 0.3))
	var height: float = maxf(radius * 1.2, 0.5)
	var bark: Material = _felled_bark(str(extra.get("species", "")), radius, height)
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius * 0.95
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.material = bark
	mesh_node.mesh = cyl
	mesh_node.position = Vector3(0.0, height * 0.5, 0.0)
	root.add_child(mesh_node)
	# Looks (Kathleen, stage-1 pass): a pale cut face with a darker ring on the stump top and root swell round its foot, so a stump is not a bare drum.
	var cut: StandardMaterial3D = StandardMaterial3D.new()
	cut.albedo_color = Color(0.72, 0.58, 0.38)
	var ring: StandardMaterial3D = StandardMaterial3D.new()
	ring.albedo_color = Color(0.5, 0.36, 0.2)
	var face: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = cyl.top_radius * 0.93
	disc.bottom_radius = cyl.top_radius * 0.93
	disc.height = 0.012
	disc.material = cut
	face.mesh = disc
	face.position = Vector3(0.0, height * 0.5 + 0.004, 0.0)
	mesh_node.add_child(face)
	var core: MeshInstance3D = MeshInstance3D.new()
	var inner: CylinderMesh = CylinderMesh.new()
	inner.top_radius = cyl.top_radius * 0.55
	inner.bottom_radius = cyl.top_radius * 0.55
	inner.height = 0.016
	inner.material = ring
	core.mesh = inner
	core.position = face.position + Vector3(0.0, 0.001, 0.0)
	mesh_node.add_child(core)
	var stub_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	stub_rng.seed = int(radius * 1000.0) + int(float(extra.get("length", 8.0)))

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

	var circle: Array = extra.get("crown", [])

	if bool(extra.get("fresh", false)) and circle.size() >= 3:   # the crown lands: the grass under the whole canopy circle lies flat
		var tween: Tween = root.create_tween()
		tween.tween_interval(clampf(float(extra.get("fall_left", FALL_S)), 0.0, FALL_S))   # a stump seen late: the crown lands with the logs
		tween.tween_callback(func():
			if crown_landed.is_valid():
				crown_landed.call(Vector3(float(circle[0]), 0.0, float(circle[1])), float(circle[2])))

	return root


const FALL_S := 1.5   # a felled tree's pieces swing down this long (server_items FALL_S, tree_sounds FALL_S)
var _falling: Dictionary = {}   # world id -> true while a felled tree's piece swings down (_swing_down); _snap_loose leaves it alone


# A piece of a felled tree coming down (the row's fall extra: the hinge at the stump, the fall's turn, the seconds left): it swings down round the stump with
# the rest of the tree, from standing up to where it lies, easing in as the old whole trunk did, so the tree falls already in its logs. The whole lying
# transform is turned about the hinge line, so the logs keep their places end to end all the way down. A row that arrives late starts part way down.
func _swing_down(id: int, node: Node3D, fall: Array) -> void:
	var left: float = minf(float(fall[4]), FALL_S)

	if left <= 0.05:
		return

	var hinge: Vector3 = Vector3(float(fall[0]), float(fall[1]), float(fall[2]))
	var toward: Vector3 = Vector3(sin(float(fall[3])), 0.0, cos(float(fall[3])))
	var axis: Vector3 = toward.cross(Vector3.UP).normalized()   # turning `toward` about this by +90 degrees points it straight up
	var rest: Transform3D = node.transform
	_falling[id] = true
	var swing: Callable = func(u: float) -> void:
		var lift: float = PI * 0.5 * (1.0 - u * u)   # quad ease in: slow at first, fastest as it lands
		node.transform = Transform3D(Basis(axis, lift), hinge) * Transform3D(Basis.IDENTITY, -hinge) * rest
	var down: Callable = func() -> void:
		node.transform = rest
		_falling.erase(id)
		_snap_loose(id)
	swing.call(1.0 - left / FALL_S)   # up at once: no frame lying before it stands
	var tween: Tween = node.create_tween()
	tween.tween_method(swing, 1.0 - left / FALL_S, 1.0, left)
	tween.tween_callback(down)


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
	var ticks: float = float(Time.get_ticks_msec())

	for n in lit.size():
		var light: Light3D = lit[n][1]
		light.visible = n < MAX_FIRE_LIGHTS

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
	var t: int = FrameProbe.start()
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

	FrameProbe.stop("inventory: slots and their sounds", t)   # Lane A r4: one slot message took 134 ms with no chest open; named to find which step
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


# Lag fix (26 Nov 2026, Lane A Low route): opening a chest sent three slot messages in one poll and each redrew the chest screen, the
# storage window and the hotbar on the spot (185, 98 and 109 ms). They now wait with the window for the end of the frame and redraw once.
func _after_slots() -> void:
	_slots_dirty = true
	_queue_refresh()


# Slot updates that arrive together (a pickup, a craft, a sale send several) rebuild the window once, at the end of the frame.
var _refresh_queued: bool = false
var _slots_dirty: bool = false   # a slot message came: the chest screen, the storage window and the hotbar redraw too


func _queue_refresh() -> void:
	if _refresh_queued:
		return

	_refresh_queued = true
	_flush_refresh.call_deferred()


func _flush_refresh() -> void:
	_refresh_queued = false
	var t: int = FrameProbe.start()
	_refresh()
	FrameProbe.stop("inventory: window after slots", t)

	if not _slots_dirty:
		return

	_slots_dirty = false
	t = FrameProbe.start()
	_container_part.refresh()
	FrameProbe.stop("inventory: chest screen after slots", t)
	t = FrameProbe.start()
	_storage_ui.refresh_view()   # the storage window's pack list follows the pack
	FrameProbe.stop("inventory: storage window after slots", t)
	t = FrameProbe.start()
	refresh_hotbar()
	FrameProbe.stop("inventory: hotbar after slots", t)


# --- The chest screen: the chest on the left, the pack on the right; a click moves a whole stack ---

# --- Hunger and health HUD, eating ---
# Hunger, thirst and the rest are symbols in the status strip left of the hotbar (src/client/status_icons.gd, Dave 23 Nov 2026); the
# old warning words at the bottom left ("You are low on food") are its hover lines now, so nothing is said twice.

func _place_vitals() -> void:
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


# Q or D with nothing selected: lay a log from your shoulder down in front of you (one at a time).
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
var soak_percent: int = 0      # server (protocol 165): how rain-soaked the clothes are, in steps of 10 (warmth.json soak_*), for the status strip
var soak_wind: bool = false    # and soaked in the wind, the case that cools fastest (body_703 wet_wind_say_*)


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


# True when a cart with a bed for crates stands within 3 m of the point (a crate there can be lifted onto it; a sled has no bed).
func _cart_near(at: Vector3) -> bool:
	for id in _world:
		if not _structure_by_state(int(_world[id].get("state", -1))).get("vehicle", {}).get("crate_spots", []).is_empty() and (_world[id]["pos"] as Vector3).distance_to(at) <= 3.0:
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


# Loose logs the server's physics moved (protocol 125): each glides to its new spot and pose (lying_logs.gd).
func _on_logs_moved(ids: PackedInt32Array, positions: PackedVector3Array, poses: PackedVector3Array) -> void:
	for i in mini(ids.size(), mini(positions.size(), poses.size())):
		if _world.has(ids[i]) and _world[ids[i]].get("log", false):
			_world[ids[i]]["pos"] = positions[i]
			_world[ids[i]]["pose"] = poses[i]
			_gliding[ids[i]] = true


# A loose log's drawn centre and turn: the point under its middle lifted by its radius, the pose [rot_y, pitch, spin] (lying_logs.gd).
func _log_target(entry: Dictionary) -> Transform3D:
	var pose: Vector3 = entry.get("pose", Vector3.ZERO)
	return Transform3D(Basis(LyingLogs.basis_of(pose.x, pose.y, pose.z).get_rotation_quaternion()), entry["pos"] + Vector3(0.0, LyingLogs.LOG_R * float(entry.get("girth", 1.0)) + float(entry.get("lift", 0.0)), 0.0))


func _glide_tick(delta: float) -> void:
	for id in _gliding.keys():
		if not _world.has(id) or not (_world[id].get("node") is Node3D):
			_gliding.erase(id)
			continue

		if _falling.has(id):
			continue   # still swinging down: it glides on from where it lands (_swing_down's end snaps it to the new spot)

		var node: Node3D = _world[id]["node"]
		var share: float = clampf(delta * GLIDE_RATE, 0.0, 1.0)

		if _world[id].get("log", false):   # a log the server's physics moves: its centre and its whole turn, so it is seen to roll
			var aim: Transform3D = _log_target(_world[id])
			node.position = node.position.lerp(aim.origin, share)
			node.quaternion = node.quaternion.slerp(aim.basis.get_rotation_quaternion(), share)

			if node.position.distance_to(aim.origin) < 0.01 and node.quaternion.angle_to(aim.basis.get_rotation_quaternion()) < 0.01:
				node.position = aim.origin
				node.quaternion = aim.basis.get_rotation_quaternion()
				_gliding.erase(id)
				_snap_loose(id)

			continue

		var loose: bool = int(_world[id]["state"]) == 0   # a loose item rests 12 cm over its ground point, as _snap_loose puts it
		var target: Vector3 = _world[id]["pos"] + (Vector3(0.0, 0.12, 0.0) if loose else Vector3.ZERO)
		node.position = node.position.lerp(target, share)
		node.rotation.y = lerp_angle(node.rotation.y, deg_to_rad(float(_world[id]["yaw"])), share)

		if node.position.distance_to(target) < 0.01:
			node.position = target
			_gliding.erase(id)

			if loose:
				_snap_loose(id)   # onto the drawn ground, which can differ a little from the server's height


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


# Fills the label with segments: a String is text, a Dictionary {coin id: count} is coins as held (the purse), an int is an amount in copper
# drawn as its fewest coins, "4 (gold icon) 3 (silver icon) ...",
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

		var amounts: Array = []

		for row in rows.duplicate():
			amounts.append([row, 0])

		if typeof(segment) == TYPE_DICTIONARY:   # coins as held {coin id: count} (the purse): shown as they are, not changed into bigger coins
			for pair in amounts:
				pair[1] = int(segment.get(str(pair[0]["id"]), 0))
		else:   # a price or sum in copper: the fewest coins
			var left: int = int(segment)

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


# The purse (protocol 123): counts in coins.json ladder order.
func _on_purse(counts: PackedInt32Array) -> void:
	var ladder: Array = _coins_cfg.get("ladder", [])
	purse_coins = {}
	purse_copper = 0

	for i in mini(counts.size(), ladder.size()):
		if counts[i] > 0:
			purse_coins[str(ladder[i]["id"])] = counts[i]
			purse_copper += counts[i] * int(ladder[i]["copper"])

	_refresh_purse()


func _refresh_purse() -> void:
	if _purse_label != null:
		fill_coin_line(_purse_label, ["Purse: ", purse_coins])


func _refresh_carried() -> void:
	if _carried_slot != null:
		_carried_slot.visible = shoulder_id != ""
		_carried_slot.text = ("Carried: %s   (F twice or Q puts one down)" % _carried_names()) if shoulder_id != "" else ""


func _refresh_weight() -> void:
	_refresh_carried()
	_weight_label.text = _load_text() + "\nBody weight %.1f kg   (food %d%%, health %d)" % [weight_kg, hunger, health]

	if _carry_bar != null and not _carry_cfg.is_empty():
		var fraction: float = CarryRules.bar_fraction(carried_kg(), carry_body_kg(), _carry_cfg)
		_carry_bar.value = fraction * 100.0
		_carry_bar.get_theme_stylebox("fill").bg_color = InventoryLook.carry_color(fraction)


func _load_text() -> String:
	var load_kg: float = carried_kg()
	var limit: float = CarryRules.cap_kg(carry_body_kg(), _carry_cfg)
	var state: String = ["", "   (heavy: you move slower)", "   (at the limit)", "   (over the limit: put something down)"][CarryRules.load_state(load_kg, carry_body_kg(), _carry_cfg)]   # CarryRules.load_state, the thresholds the HUD load symbol uses too
	return "Carrying %.1f kg of %.1f kg you can carry%s" % [load_kg, limit, state] + ("\nOn your shoulder: %s (Q lays one down)" % _carried_names() if shoulder_id != "" else "")


func _on_strain(strain_pm: int, state: int, fade_pm: int, stance: int) -> void:
	strain = float(strain_pm) / 1000.0
	strain_state = state
	strain_fade = float(fade_pm) / 1000.0
	stance_confirmed = stance & 3
	asleep = (stance & 4) != 0
	forced_sleep = (stance & 8) != 0
	passing_out = (stance & 16) != 0
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


# The body is out of the player's hands: passing out, fainted or waking (Dave 25 Nov 2026, QA #19: "they must stop the second the
# game determines its time to pass out"). No movement, no tool, no E, no stance key until the faint is over.
func body_out() -> bool:
	return strain_state >= 2 or passing_out


# Movement the over-exertion allows: -1 none (passing out, fainted or waking), else a speed cap in m/s (0 = no cap).
func move_cap() -> float:
	if body_out() or forced_sleep:
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
		eat_event.call(_eat_item)   # a medicine's sound; food and drinks from the pack are silent (Dave 17 Nov 2026: "doesnt need sound for eating"; ItemSounds.eat_kind)
		_eat_item = ""

	# A mouthful at the water's edge or from a water container (drink(), eat_slot) took effect: the gulp sound (Dave 2026-10-21 reported there was no sound when drinking).
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
		_on_notice("Your inventory is full.")
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
		return _tooltip(inventory.numbers[slot], inventory.counts[slot], inventory.wear[slot], inventory.inst_of(slot)) + ("\nKeys: Use (%s) moves it to the inventory" % KeyBindings.label("use_item") if open else "")

	return "Drag an item here from the inventory. Key %s holds it." % key_name


# The body slot ("back", "head", ...) of the wearable piece in a pack slot, "" for none (an empty slot or a piece nobody wears).
func wear_slot_of(slot: int) -> String:
	if slot < 0 or slot >= inventory.slot_count or inventory.numbers[slot] == 0:
		return ""

	var body: String = str(table.entry(table.id_of(inventory.numbers[slot])).get("slot", ""))
	return body if clothing_slots().has(body) else ""


# Put on the piece in a pack slot; the server picks its position and says why when it cannot (ACT_WEAR, server_items.gd _wear).
func wear_slot(slot: int) -> void:
	net.inventory_action.rpc_id(1, Net.ACT_WEAR, slot, 0, 0, Vector3.ZERO)


# Take off the piece at a worn position into the pack (ACT_UNWEAR, server_items.gd _unwear; refused with a notice when something hangs on it).
func take_off(place: int) -> void:
	net.inventory_action.rpc_id(1, Net.ACT_UNWEAR, place, 0, 0, Vector3.ZERO)


# Eat the food or apply the medicine in a pack slot. Herbs that look like something else must be identified first.
# True when a bite or mouthful went to the server (what holding E repeats); wearing or holding a tool is false.
func eat_slot(slot: int) -> bool:
	# Use on clothing or a pack puts it on.
	if wear_slot_of(slot) != "":
		wear_slot(slot)
		return false

	# Use on a tool, weapon or kit holds it in the hand (and again puts it away); on food or medicine it eats or applies it;
	# on a water container that holds water it takes a mouthful.
	if container_cap(slot) > 0 and inventory.wear[slot] > 0:
		_drink_msec = Time.get_ticks_msec()
		net.inventory_action.rpc_id(1, Net.ACT_EAT, slot, 0, 0, Vector3.ZERO)
		return true

	if not edible_slot(slot):
		if equippable_slot(slot) and equip_requested.is_valid():
			equip_with_move(slot)

		return false

	var number: int = inventory.numbers[slot]
	var entry: Dictionary = table.entry(table.id_of(number))

	if knowledge != null and not entry.get("look_alikes", []).is_empty() and not knowledge.is_known("i%d" % number):
		_on_notice("You are not sure what %s really is. Hover it in inspection mode (/) before you use it." % table.sentence_name(number))
		return false

	_eat_item = table.id_of(number)
	net.inventory_action.rpc_id(1, Net.ACT_EAT, slot, 0, 0, Vector3.ZERO)
	return true


func _start_eat_hold(slot: int, still: Callable) -> void:
	_eat_hold_slot = slot
	_eat_hold_still = still
	_eat_hold_sign = _eat_sign(slot)
	_eat_hold_sent_msec = Time.get_ticks_msec()


# Food, drink or medicine on the hotbar is eaten straight from it, never taken in hand (Dave's play test 19 Nov 2026: "if you click on food in a
# hotbar or hold down the hotbar key on a food item it should just eat the food and keep eating it like holding E in the inventory"). Its number
# key (HeldItem.press_slot, in the world or with the screen open) or a left click on its hotbar box (on release, _hotbar_press_tick) eats one bite, and holding the key or the button
# keeps eating through the same hold as E in the pack (_eat_hold_tick: one bite at a time at the server's pace, every bite checked by the server).
# The hand keeps what it held. Provisional (Dave to confirm): a quick tap eats one bite; the empty slot simply leaves the hotbar.
# `by_click`: the hold follows the left button and the pointer staying on that box; otherwise it follows the key's own number key.
# True when the slot was food and a bite went (or was refused with the usual notice): the caller does nothing else with it.
func eat_from_hotbar(key: int, by_click: bool = false) -> bool:
	var slot: int = key_slot(key)

	if slot < 0 or not edible_slot(slot):
		return false

	if by_click:
		_hotbar_press = [key, Time.get_ticks_msec()]   # the bite waits for the release or HOTBAR_PRESS_HOLD_MSEC, so a drag off the hotbar eats nothing
		return true

	if eat_slot(slot):
		var number_key: Key = KEY_0 if key == 9 else (KEY_1 + key) as Key
		_start_eat_hold(slot, func() -> bool: return Input.is_key_pressed(number_key))

	return true


# A press on a food box (eat_from_hotbar by_click): let go on the box without dragging and it is a click, one bite; still down after
# HOTBAR_PRESS_HOLD_MSEC and it is a hold, the first bite and then the E hold while the button stays down on the box. A drag, the pointer
# leaving the box or the screen closing first eats nothing (provisional: moving food about on the hotbar never eats it).
const HOTBAR_PRESS_HOLD_MSEC := 200
var _hotbar_press: Array = []   # [hotbar key, msec] of a press on a food box not yet a bite, [] when none


func _hotbar_press_tick(now: int) -> void:
	if _hotbar_press.is_empty():
		return

	var key: int = int(_hotbar_press[0])

	if not open or hotbar_hover != key or (is_inside_tree() and get_viewport().gui_is_dragging()):
		_hotbar_press = []
		return

	var down: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if down and now - int(_hotbar_press[1]) < HOTBAR_PRESS_HOLD_MSEC:
		return

	_hotbar_press = []
	var slot: int = key_slot(key)

	if slot < 0 or not edible_slot(slot) or not eat_slot(slot) or not down:
		return

	_start_eat_hold(slot, func() -> bool: return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and open and hotbar_hover == key and not (is_inside_tree() and get_viewport().gui_is_dragging()))


# The server's gap between bites (server_items._eat) or mouthfuls (_drink_from_container), plus slack.
func _eat_hold_pace(slot: int) -> int:
	if container_cap(slot) > 0:
		return int((_vitals_cfg.get("thirst", {}) as Dictionary).get("drink_pace_ms", 900)) + EAT_HOLD_SLACK_MSEC

	return int(_vitals_cfg.get("eat_pace_ms", 800)) + EAT_HOLD_SLACK_MSEC


func _eat_sign(slot: int) -> Array:
	return [inventory.numbers[slot], inventory.counts[slot], inventory.wear[slot]]


# Each frame while E is held on a slot: the next bite once the last one landed and the pace allows; stop on release, an empty or changed slot,
# the pointer leaving it, the screen closing or a container opening, or a bite the server refused.
func _eat_hold_tick(now: int) -> void:
	if _eat_hold_slot < 0:
		return

	var slot: int = _eat_hold_slot

	if not bool(_eat_hold_still.call()) or slot >= inventory.slot_count or inventory.numbers[slot] != int(_eat_hold_sign[0]):
		_eat_hold_slot = -1
		return

	var pace: int = _eat_hold_pace(slot)

	if _eat_sign(slot) == _eat_hold_sign:
		if now - _eat_hold_sent_msec >= pace + EAT_HOLD_REFUSED_MSEC:
			_eat_hold_slot = -1   # the last bite never landed: refused

		return

	if now - _eat_hold_sent_msec < pace:
		return

	if not eat_slot(slot):
		_eat_hold_slot = -1
		return

	_eat_hold_sign = _eat_sign(slot)
	_eat_hold_sent_msec = now


# Asks the server to open a container. The server also pushes fresh contents while it is open (a fire eating wood); a push that arrives when
# no window is open and none was asked for in the last 2 s is ignored, so closing the window is not undone.
var _open_asked_msec: int = -100000
var _craft_first: bool = false   # the window being asked for is a station's: it opens on the Craft tab, its store one tab away


# A station store's row (master s2.5): its fill (server_items._store_fill) and, for a Kiln, whether it burns; kept when the row is sent again.
# A smelter's row also says who works its bellows (server_smelter.bellows_peer: 2 this player, 1 another, absent nobody): while they are
# worked its fire burns brighter, its smoke puffs and the bellows blow with each stroke, for everyone near (Dave 21 Nov 2026).
func _note_store(id: int, row: Array) -> void:
	if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("fill"):
		var lit_now: bool = bool(row[5].get("lit", false))
		var redrawn: bool = _world[id].has("lit") and bool(_world[id]["lit"]) != lit_now   # lit or put out: this model goes and the new one takes the bellows
		_world[id]["fill"] = int(row[5]["fill"])
		_world[id]["lit"] = lit_now
		_world[id]["forge"] = int(row[5].get("forge", -1))   # a smithy's fire: 0 cold, 1 red coals, 2 the flare
		var at_bellows: int = int(row[5].get("bellows", 0))

		if at_bellows != int(_world[id].get("bellows", 0)) and not redrawn and _world[id].get("node") is Node3D:
			BuildingLook.show_forge_bellows(_world[id]["node"], at_bellows > 0, _bellows_blew)

		_world[id]["bellows"] = at_bellows


func _bellows_blew(at: Vector3) -> void:
	if bellows_event.is_valid():
		bellows_event.call(at)


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
		_station_screen = id   # any container's window is not your own inventory: its Craft list shows only what it makes (station_makes)
		_recipe_part.show_category("")   # on All, as _open_station
		open = true
		_build_panel()
		_panel.visible = true      # one window, the container in its Craft column (4.4)
		chest_tab = not _craft_first
		_craft_first = false
		_container_part.build()
		_show_tab()

		_refresh()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		if chest_event.is_valid() and _world.has(id):
			chest_event.call("open", _world[id]["pos"])

	_container_part.refresh()


func _close_chest() -> void:
	net.inventory_action.rpc_id(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	_open_asked_msec = -100000   # contents still on their way (another player's change, sent before the close arrived) must not open the window again:
	                             # the server has it closed, so that window would never be brought up to date (hands-on screens fuzz, 23 Nov 2026)

	if chest_event.is_valid() and _world.has(chest_id):
		chest_event.call("close", _world[chest_id]["pos"])

	chest_mode = false
	open = false
	_station_screen = 0
	_recipe_part.stop()   # the window shut: a half-worked recipe list is dropped
	_show_tab()

	if _panel != null:
		_panel.visible = false

	_end_drag()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# A stack still on the pointer when the window closes goes back where it was (nothing is moved until a drop): without this the engine
# kept the drag going over the game, the stack's picture on the cursor until the next click (hands-on screens fuzz, 23 Nov 2026).
func _end_drag() -> void:
	if is_inside_tree() and get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()


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
		FreezeWatchScript.printer.line("client slow: %s took %.0f ms" % [label, ms])

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

	if chest_mode and chest_id >= 0 and removed.has(chest_id):
		_close_chest()   # the open container went (another player took it down, or it is out of sight): its window shows nothing stale

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

			if _world[id].get("log", false) and state == 0 and not _falling.has(id) and ((row[3] as Vector3).distance_to(_world[id]["pos"]) > 0.05 or _row_pose(row) != _world[id].get("pose", Vector3.ZERO)):
				_world[id]["pos"] = row[3]      # a log moved (the world sync after logs_moved, or instead of a lost one): it glides there
				_world[id]["pose"] = _row_pose(row)
				_gliding[id] = true
			elif int(_world[id]["state"]) == 0 and state == 0 and not _gliding.has(id) and not _world[id].get("log", false) and (row[3] as Vector3).distance_to(_world[id]["pos"]) > 0.05:
				_world[id]["pos"] = row[3]      # the server let it down onto the ground (after a dig): draw it there
				(_world[id]["node"] as Node3D).position = row[3] + Vector3(0.0, 0.12, 0.0)
				var t_b: int = Time.get_ticks_usec()
				_snap_loose(id)
				prof["snap"] = int(prof.get("snap", 0)) + Time.get_ticks_usec() - t_b

			if _world[id]["state"] == state and state >= 5 and row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("yaw"):
				_world[id]["on"] = bool(row[5].get("on", false))   # a crate lifted onto a cart or set down

				if (row[3] as Vector3).distance_to(_world[id]["pos"]) > 0.05 and not (row[5] as Dictionary).has("len"):   # a pipe run that moved was split: drawn again below
					_glide(id, row[3], float(row[5]["yaw"]))   # a cart or a crate on it moved (the world sync after items_moved, or instead of a lost one)

			if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("water_l"):
				_world[id]["water_l"] = int(row[5]["water_l"])

			if _world[id]["state"] == state and state >= 5 and row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("yaw"):
				_note_catch(id, row[5], state)   # a trap that caught or was emptied, a catch cut with the knife: re-sent with the same state

			var pipe_moved: bool = row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("len") and (absf(float(row[5]["len"]) - float(_world[id].get("len", 0.0))) > 0.001 or (row[3] as Vector3).distance_to(_world[id]["pos"]) > 0.001)   # a run split by a junction: drawn again

			if _world[id]["state"] == state and not pipe_moved:
				if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("burn"):
					_world[id]["burn"] = float(row[5]["burn"])
					_world[id]["burn_at"] = Time.get_ticks_msec()

				if state == StructureLook.FIRE_COALS and _world[id].get("light") != null and row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("glow"):
					BuildingLook.coals_glow(_world[id]["light"], float(row[5]["glow"]))   # the coals dim as their time runs down

				# A Smelter or kiln lit or put out is drawn again: its fire and light are set only when its model is built (_forge_fire, _make_primitive_kiln).
				var smelter_lit_changed: bool = str(_structure_by_state(state).get("use", "")) in ["smelt", "kiln"] and row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and bool(row[5].get("lit", false)) != bool(_world[id].get("lit", false))
				# A smithy that takes fuel, runs out, starts or stops working is drawn again too (its coals, flare and light are set as its model is built).
				smelter_lit_changed = smelter_lit_changed or (row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and int(row[5].get("forge", -1)) != int(_world[id].get("forge", -1)))
				_note_platter(id, row, state)
				_note_store(id, row)
				_note_crop(id, row)
				_note_bin(id, row, state)
				var site_now: Variant = (row[5] as Dictionary).get("site") if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else null
				var site_was: Variant = _world[id].get("site")

				if site_now != null and site_was != null:
					_world[id]["site"] = site_now   # a deposit or a change in what you have to hand: the list updates, the blue piece stays
					continue

				if (site_now != null) == (site_was != null) and not smelter_lit_changed:
					continue   # only a site finished (drawn again as the real piece) or a piece that became a site is drawn again

			_forget(id)   # a changed state, or a site finished or begun: draw it again

		var node: Node3D
		var light: OmniLight3D = null

		if state >= 5 and not StructureLook.is_unlit_fire(state) and not _lit_state(state):   # 8 is a burnt-out fire, 9 a loaded one, 76 coals, 77 warm ash: the campfire model without flames
			var yaw: float = deg_to_rad(float(row[5].get("yaw", 0.0))) if row.size() > 5 else 0.0
			var t_c: int = Time.get_ticks_usec()
			node = _model_for_state(state, ((row[5] as Dictionary).merged({"at": row[3]}) if state == CARCASS_STATE else row[5]) if row.size() > 5 else {})   # a carcass: where it lies (animal_view dead_body)
			prof["model"] = int(prof.get("model", 0)) + Time.get_ticks_usec() - t_c
			node.position = row[3] - Vector3(0.0, SINK_M * float(row[5].get("age", 0.0)), 0.0) if (state == 11 or state == 12) and row.size() > 5 else row[3]
			node.rotation.y = yaw

			if row.size() > 5 and (row[5] as Dictionary).has("pitch"):
				node.rotation.z = deg_to_rad(float(row[5]["pitch"]))   # a pipe run tilts along its own axis (PipeRules.axis_of: Y then Z, Godot's YXZ order)
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

			if row.size() > 5 and bool((row[5] as Dictionary).get("lit", false)) and str(_structure_by_state(state).get("use", "")) == "smelt":
				fixture_light = node.get_node_or_null("Light")   # a lit Smelter: its forge's own fire light (_forge_fire shows its flames)
			elif row.size() > 5 and bool((row[5] as Dictionary).get("lit", false)) and node.has_meta("coal_glow"):
				fixture_light = node.get_node_or_null("Light")   # a lit Primitive kiln: its own light at its mouth (_make_primitive_kiln)
			elif row.size() > 5 and int((row[5] as Dictionary).get("forge", 0)) >= 1:
				fixture_light = node.get_node_or_null("Light")   # a smithy with fuel: its coals' glow or its flare (BuildingLook.forge_state)
			elif row.size() > 5 and bool((row[5] as Dictionary).get("lit", false)):
				var fixture: Node3D = BuildingLook.lit_fixture(StructureLook.look_of(state))
				node.add_child(fixture)
				fixture_light = fixture.get_node_or_null("Light")
				var light_m: float = float(_structure_by_state(state).get("light_m", 0.0))   # structures.json light_m: the reach of its light (buildables plan, batch B4)

				if light_m > 0.0 and fixture_light is OmniLight3D:
					(fixture_light as OmniLight3D).omni_range = light_m
				elif light_m > 0.0 and fixture_light is SpotLight3D:
					(fixture_light as SpotLight3D).spot_range = light_m

			_world[id] = {"node": node, "number": row[1], "count": 1, "pos": row[3], "state": state, "light": fixture_light, "roof": roof_key, "yaw": rad_to_deg(yaw), "on": row.size() > 5 and bool((row[5] as Dictionary).get("on", false))}
			_note_first_shown(int(row[1]), state)

			if row.size() > 5 and (row[5] as Dictionary).has("len"):
				_world[id]["len"] = float(row[5]["len"])   # a pipe run (PLUMBING_DESIGN s9): its ends are PipeRules.ends(pos, yaw, pitch, len)
				_world[id]["pitch"] = float(row[5].get("pitch", 0.0))

			if row.size() > 5:
				_note_catch(id, row[5], state)

			if row.size() > 5 and (row[5] as Dictionary).has("water_l"):
				_world[id]["water_l"] = int(row[5]["water_l"])   # a barrel's water: E drinks from it instead of opening it

			if site_extra != null:
				_world[id]["site"] = site_extra

			if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("wheel"):
				_world[id]["wheel"] = int(row[5]["wheel"])   # a sawmill's water wheel share in percent (server_items.wheel_percent)

			_note_store(id, row)

			_note_platter(id, row, state)
			_note_crop(id, row)
			_note_bin(id, row, state)

			if site_extra != null:
				pass   # a site is walked through and climbed by nobody until it is finished
			elif StructureLook.look_of(state) == "ladder":
				ladders[id] = {"pos": row[3], "yaw": rad_to_deg(yaw)}
			elif StructureLook.look_of(state) == "trodden_path":
				_path_cell_add(row[3], 1)

				if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and bool((row[5] as Dictionary).get("road", false)):
					_world[id]["road"] = true   # a surveyed road's patch: the grass is kept off 2 m either side (terrain_client _sync_cleared)

			continue

		if is_felled_state(state):   # only 4 (a stump): a loaded or burnt-out fire (8, 9) is NOT one, it was drawn as a stump (Dave, build 826)
			var extra: Dictionary = row[5] if row.size() > 5 else {}
			var felled_t0: int = Time.get_ticks_usec()
			node = _make_felled(extra)
			prof["felled"] = int(prof.get("felled", 0)) + Time.get_ticks_usec() - felled_t0
			node.position = row[3]
			_root.add_child(node)
			_world[id] = {"node": node, "number": 0, "count": 1, "pos": row[3], "state": state, "light": null, "extra": extra}
			_note_first_shown(0, state)
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

			if _is_log(int(row[1])):   # a loose log lies as the server's physics left it (lying_logs.gd): its centre a radius over its point, its whole turn
				var log_entry: Dictionary = {"pos": row[3], "pose": _row_pose(row), "girth": float(row[5].get("girth", 1.0)) if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else 1.0}
				var aim: Transform3D = _log_target(log_entry)
				node.position = aim.origin
				node.quaternion = aim.basis.get_rotation_quaternion()
		else:
			var fire_extra: Dictionary = row[5] if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else {}

			if bool(fire_extra.get("marks", false)):
				node = Node3D.new()   # a bandit camp's boot prints leading off the road, no pit (docs/design/BANDIT_CAMPS.md stage 3)
			else:
				node = BuildingLook.coals_fire(float(fire_extra.get("glow", 1.0))) if state == StructureLook.FIRE_COALS else _make_fire(_lit_state(state), state == 9, _fire_tier(state))

			node.position = row[3]

			if fire_extra.get("tracks") is Array:
				node.add_child(TrackLook.make(fire_extra["tracks"]))
			light = node.get_node_or_null("Light")

		if light == null:
			light = node.get_node_or_null("Light")   # the forges glow

		_root.add_child(node)
		_world[id] = {"node": node, "number": row[1], "count": row[2], "pos": row[3], "state": state, "light": light}
		_note_first_shown(int(row[1]), state)

		if state == 0 and _is_log(int(row[1])):
			_world[id]["log"] = true
			_world[id]["pose"] = _row_pose(row)
			_world[id]["girth"] = float(row[5].get("girth", 1.0)) if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else 1.0

		if state != 0 and row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("burn"):   # a fire: the burn time left (the label counts it down while it burns)
			_world[id]["burn"] = float(row[5]["burn"])
			_world[id]["burn_at"] = Time.get_ticks_msec()

		if state != 0 and row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("camp"):
			_world[id]["camp"] = true   # Edda and Hob's fire (PROTOCOL.md, world-item rows): no prompt, no store, no burn time
			_world[id]["bandits"] = int((row[5] as Dictionary)["camp"]) == 2   # a bandit camp's fire (docs/design/BANDIT_CAMPS.md)
			_world[id]["marks"] = bool((row[5] as Dictionary).get("marks", false))   # its boot prints off the road (stage 3), no fire

		prof["loose_mesh"] = int(prof.get("loose_mesh", 0)) + Time.get_ticks_usec() - t_d
		var t_e: int = Time.get_ticks_usec()
		_refresh_pile(id)
		prof["pile"] = int(prof.get("pile", 0)) + Time.get_ticks_usec() - t_e
		t_e = Time.get_ticks_usec()
		_snap_loose(id)
		prof["snap"] = int(prof.get("snap", 0)) + Time.get_ticks_usec() - t_e

		if state == 0 and row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY and (row[5] as Dictionary).has("fall"):
			_swing_down(id, node, row[5]["fall"])   # a piece of a tree coming down: it falls with the rest from the stump

	_note_slowest_row(row_usec, row_name)
	_forget_near()   # and again once the rows are in: nothing kept while they went in (the placed list) outlives them
	var total_ms: float = float(Time.get_ticks_usec() - t_all) / 1000.0

	if total_ms > 30.0:
		var parts: Array = []

		for key in prof:
			parts.append("%s %.0f ms" % [key, float(prof[key]) / 1000.0])

		FreezeWatchScript.printer.line("client slow: world items %.0f ms for %d added, %d removed: %s (slowest row: %s, %.0f ms)" % [total_ms, added.size(), removed.size(), ", ".join(parts), _slowest_row, float(_slowest_row_usec) / 1000.0])


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

	if entry.is_empty() or (int(entry.get("state", 0)) != 0 and not on_fire) or not _ground_below.is_valid() or _rolling.has(id) or _falling.has(id):
		_unsnapped.erase(id)
		return

	var at: Vector3 = entry["pos"]

	if entry.get("log", false):
		_snap_log(id, entry, tries)
		return

	var ground: float = float(_ground_below.call(at - Vector3(0.0, 1.5, 0.0)))      # the probe starts 2 m above its point: 0.5 m above the item, so a tunnel roof is not hit

	if is_nan(ground) or ground > at.y + SNAP_UP_M or ground < at.y - SNAP_DOWN_M:
		_unsnapped[id] = tries - 1 if tries > 1 else 0
		return

	_unsnapped[id] = tries - 1
	var node: Node3D = entry["node"]
	node.position = Vector3(at.x, ground + (0.02 if on_fire else 0.12), at.z)


# A loose log is drawn as the server's physics laid it (stacked on another log, tilted on a rock): it is only lifted where the drawn ground, which can
# differ a little from the server's height, comes up over its underside at its middle or either end, so it never shows sunk into the ground.
func _snap_log(id: int, entry: Dictionary, tries: int) -> void:
	var node: Node3D = entry["node"]
	var r: float = LyingLogs.LOG_R * float(entry.get("girth", 1.0))
	var axis: Vector3 = node.quaternion * Vector3(LyingLogs.LOG_HALF_M - r, 0.0, 0.0)
	var base: Vector3 = node.position - Vector3(0.0, float(entry.get("lift", 0.0)), 0.0)   # where the server put it
	var lift: float = 0.0
	var probed: bool = false

	for end in [Vector3.ZERO, axis, -axis]:
		var under: Vector3 = base + end - Vector3(0.0, r, 0.0)
		var ground: float = float(_ground_below.call(under - Vector3(0.0, 1.5, 0.0)))   # the probe starts 2 m above the underside

		if not is_nan(ground) and ground <= under.y + SNAP_UP_M:
			probed = true
			lift = maxf(lift, ground - under.y)

	if not probed:
		_unsnapped[id] = tries - 1 if tries > 1 else 0   # the ground under it is not drawn yet: tried again
		return

	_unsnapped[id] = tries - 1
	entry["lift"] = lift   # kept while it glides on (_log_target), so a rolling log is not drawn sunk between settles
	node.position = base + Vector3(0.0, lift, 0.0)


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

	var unit_kg: float = CarryRules.weight_of(item_id, _carry_cfg) if not _carry_cfg.is_empty() else 0.0

	if PileLookScript.is_pile(table.entry(item_id), int(entry["count"])):
		box.mesh = PileLookScript.mesh_for(item_id, table.entry(item_id), int(entry["count"]), id, unit_kg)
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


# Every foundation and building piece standing as {"pos", "state", "yaw"}: what new pieces snap to and stand on.
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


# A resource bin's row (GOALS-REPAIR R6; row extras "res": the item it holds, -1 mixed from before R6, and "fill_pm": its fill in per mille):
# its resource surface, one flat layer inside the walls that rises with the fill and is gone when empty (master s2.5, BinRules.surface_height).
# PLACEHOLDER look: a plain slab in a colour for what it holds, until the art pipeline draws the resources.
func _note_bin(id: int, row: Array, state: int) -> void:
	var def: Dictionary = _structure_by_state(state)

	if not BinRules.is_bin(def) or _world.get(id, {}).get("node") == null:
		return

	var extra: Dictionary = row[5] if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else {}
	var node: Node3D = _world[id]["node"]
	var surface: MeshInstance3D = node.get_node_or_null("ResourceSurface")
	var side: float = float(def.get("footprint_x", 1.0))
	var y: float = BinRules.surface_height(float(extra.get("fill_pm", 0)) / 1000.0, 0.06, PieceLook.bin_wall_m(side) - 0.05)

	if y < 0.0 or extra.get("site") != null:
		if surface != null:
			surface.visible = false

		return

	if surface == null:
		surface = MeshInstance3D.new()
		surface.name = "ResourceSurface"
		var slab: BoxMesh = BoxMesh.new()
		slab.size = Vector3(side - 0.1, 0.04, side - 0.1)
		surface.mesh = slab
		node.add_child(surface)

	surface.position = Vector3(0.0, y, 0.0)
	surface.material_override = _bin_material(int(extra.get("res", 0)))
	surface.visible = true


var _bin_materials: Dictionary = {}   # item number -> the placeholder surface material (_note_bin)


func _bin_material(number: int) -> StandardMaterial3D:
	if not _bin_materials.has(number):
		var colours: Dictionary = {"stone": Color(0.5, 0.5, 0.48), "cobblestone": Color(0.45, 0.44, 0.42), "gravel": Color(0.56, 0.54, 0.5), "flint": Color(0.3, 0.3, 0.32), "clay": Color(0.62, 0.36, 0.25), "sand": Color(0.85, 0.75, 0.5), "soil": Color(0.35, 0.25, 0.15), "charcoal": Color(0.08, 0.08, 0.08), "coal": Color(0.1, 0.1, 0.11), "copper_ore": Color(0.42, 0.55, 0.4), "tin_ore": Color(0.6, 0.6, 0.62), "iron_ore": Color(0.5, 0.28, 0.18), "bog_iron_ore": Color(0.48, 0.22, 0.1)}
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = colours.get(table.id_of(number) if number > 0 else "", Color(0.5, 0.45, 0.4))
		m.roughness = 1.0
		_bin_materials[number] = m

	return _bin_materials[number]


# The table tops a Serving Platter's ghost may snap to: the placed structures of `states` (its attach_kinds) with their turn, as the server's _surface_rows.
func surface_rows(states: Dictionary) -> Array:
	var rows: Array = []

	for id in _world:
		if states.has(int(_world[id]["state"])) and _world[id].has("yaw") and _world[id].get("site") == null:
			rows.append({"pos": _world[id]["pos"], "state": int(_world[id]["state"]), "yaw": float(_world[id]["yaw"])})

	return rows


# Every fire and every structure standing as {"pos", "state", "yaw" (degrees)}: the placement ghost checks a new piece against all of them, as the server does
# (PlacementRules.blocked, keeps_off), so a green ghost always places. Was a short list of states, so stations, walls and foundations never turned it red.
func placement_rows() -> Array:
	var rows: Array = []

	for id in _world:
		var state: int = int(_world[id]["state"])

		if StructureLook.CAMPFIRE_STATES.has(state) or (state >= 5 and _world[id].has("yaw") and not _structure_by_state(state).is_empty()):
			rows.append({"pos": _world[id]["pos"], "state": state, "yaw": float(_world[id].get("yaw", 0.0))})

	return rows


# Removes a world row's node and, for a lean-to, its roof in the cover index.
# A bog iron patch the server says is in sight (Sonny's water rules section 11): its centre on the ground as generated, the ore left, its full size
# and its radius. The rust is the ground's own colour (terrain_client hands bogs to ground_material.gd set_bogs, fading with the ore left);
# _show_bog draws its lumps; terrain_client keeps the grass off it. bogs_rev moves on whenever what the shader needs changes.
func _note_bog(id: int, row: Array) -> void:
	var extra: Dictionary = row[5] if row.size() > 5 and typeof(row[5]) == TYPE_DICTIONARY else {}
	var entry: Dictionary = bogs.get(id, {})
	var was: String = str([entry.get("pos"), entry.get("left"), entry.get("total"), entry.get("r")])
	entry["pos"] = row[3]
	entry["left"] = int(row[2])
	entry["total"] = maxi(int(extra.get("total", row[2])), 1)
	entry["r"] = float(extra.get("r", 3.0))
	entry["key"] = str(extra.get("key", ""))
	bogs[id] = entry

	if was != str([entry["pos"], entry["left"], entry["total"], entry["r"]]):
		bogs_rev += 1

	_show_bog(id)


# A patch's ore lumps (PieceLook.bog_iron_lumps): up to BOG_LUMPS of them, fewer as its ore is dug, none when it is empty. Rebuilt only when
# that count changes; no collision; turned by the key's hash so neighbours differ.
func _show_bog(id: int) -> void:
	var entry: Dictionary = bogs.get(id, {})

	if entry.is_empty() or _root == null:
		return

	var count: int = ceili(float(BOG_LUMPS) * float(clampi(int(entry["left"]), 0, int(entry["total"]))) / float(entry["total"]))

	if entry.has("lumps") and int(entry["lumps"]) == count:
		if entry.get("node") is Node3D:
			(entry["node"] as Node3D).position = entry["pos"]

		return

	if entry.get("node") is Node3D:
		(entry["node"] as Node3D).queue_free()

	entry.erase("node")
	entry["lumps"] = count

	if count <= 0:
		return

	var at: Vector3 = entry["pos"]
	var yaw: float = float(absi(hash(str(entry["key"]))) % 360) * PI / 180.0
	var ground: Callable = Callable()

	if _ground_below.is_valid():   # each lump on the ground: the patch's frame turned by yaw, from its origin
		ground = func(x: float, z: float) -> float:
			var spot: Vector3 = at + Vector3(x, 0.0, z).rotated(Vector3.UP, yaw)
			var y: float = float(_ground_below.call(spot))
			return 0.0 if is_nan(y) else y - at.y

	var node: Node3D = PieceLook.bog_iron_lumps(count, 0.45 * float(entry["r"]), ground)
	node.position = at
	node.rotation.y = yaw
	_root.add_child(node)
	entry["node"] = node


# Boulders (Dave 2026-10-21): server-owned lumps of rock a pick breaks into stones. Drawn with Art's boulder mesh scaled to the
# radius the server sends and shrinking as stones come out; solid, so the strike ray hits them. Kept apart from _world so
# nothing that walks the world items (gathering, fires, structures) mistakes one for something else.
func _show_boulder(id: int, row: Array) -> void:
	var extra: Dictionary = row[5] if row.size() > 5 else {}
	var left: int = int(row[2])

	if _boulders.has(id):
		var known: Dictionary = _boulders[id]
		var was_worked: bool = int(known["left"]) < int(known["total"])
		var from: Vector3 = known["pos"]
		var moved: bool = not from.is_equal_approx(row[3])
		var skirt_now: Array = extra.get("skirt", [])
		var reskirt: bool = skirt_now != (known["skirt"] as Array)   # the server took a talus field off under a new building, or kept it where it lay as the rock fell

		if moved:
			_rock_cell_dirty(id)   # the cell it lay in draws again without it

		known["left"] = left
		known["pos"] = row[3]   # a boulder dug under comes down (server settle_loose_near)

		var had_body: bool = known["node"] != null

		if reskirt:
			known["skirt"] = skirt_now
			known["variant"] = int(absi(id)) % SKIRT_VARIANTS + (SKIRT_VARIANTS if skirt_now.size() >= 4 else 0)
			_rock_unbody(id)   # its body's chunk shapes are made again from the new talus (never changed in the tree)

		# Dug under (boulders step 2, Dave 27 Nov 2026 "if you dig out under them they should fall on your head or in the hole"): it drops into the
		# hole as a falling rock, never a jump (no teleporting); out of its block's MultiMesh while it falls.
		var to: Vector3 = row[3]
		var drop: float = from.y - to.y
		var falls: bool = moved and drop > 0.05 and Vector2(from.x - to.x, from.z - to.z).length() < 0.3

		if known["node"] == null and (left < int(known["total"]) or falls or (reskirt and had_body)):
			_rock_body(id)   # first blow on a rock that was only drawn (a blow is struck from near, so this is rare), a rock that falls, a new talus
		elif known["node"] != null:
			(known["node"] as Node3D).position = row[3]
			(known["lump"] as MeshInstance3D).visible = left < int(known["total"])   # a worked rock draws itself, cracks and all
			_size_boulder(known)

		if falls and known["node"] != null:
			_rock_fall(id, from, drop)

		if moved or reskirt or was_worked != (left < int(known["total"])):
			_rock_cell_dirty(id)
			_rock_dirty.erase(_rock_block_of(_rock_cell_of(known)))
			_rock_refill(_rock_block_of(_rock_cell_of(known)))   # at once: the whole rock of the MultiMesh must not hide the worked one under it

		return

	if _boulder_mesh == null:
		_boulder_mesh = load("res://src/client/grass_view.gd")._make_boulder()

	if _boulder_rock == null:
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

	var ore_rock: bool = OreRockLook.has_look(str(extra.get("ore", "")))   # copper, tin and iron: Dave's photos
	var ang: float = float(extra.get("ang", -1.0))   # how broken the rock is (the resource landscape, Dave 21 Nov 2026): round by the shore, jagged inland
	var field: bool = int(extra.get("field", 0)) == 1 and not ore_rock   # a rock of the rocky ground (PR #1988): broken grey rock, as tall as wide
	var entry: Dictionary = {"node": null, "shape": null, "lump": null, "pos": row[3], "left": left, "total": maxi(int(extra.get("total", left)), 1), "radius": float(extra.get("radius", 0.5)),
		"ore": str(extra.get("ore", "")),   # what its look shows (a copper rock is green): the robot play-tester picks the rock for the ore it needs
		"mesh": OreRockLook.mesh_for(float(extra.get("yaw", 0.0)), ang) if ore_rock or field or OreRockLook.shape_of(ang) == 2 else _boulder_mesh,
		"material": OreRockLook.material(str(extra.get("ore", ""))) if ore_rock else (_field_rock_material() if field else _boulder_material(str(extra.get("ore", "")))),
		"tall": FIELD_TALL if field and OreRockLook.shape_of(ang) != 0 else 1.0,
		"yaw": float(extra.get("yaw", 0.0)), "tilt": extra.get("tilt", []), "skirt": extra.get("skirt", []),
		"variant": int(absi(id)) % SKIRT_VARIANTS + (SKIRT_VARIANTS if (extra.get("skirt", []) as Array).size() >= 4 else 0)}   # 4 values: the foot band's boulder field
	_boulders[id] = entry
	_rock_cell_dirty(id)

	# Drawn in its cell's MultiMesh (_rock_refill); a body of its own only near the player (_rock_tick) or once worked. With no player (a test
	# scene) every rock gets its body at once, as before.
	if not _player_position.is_valid() or left < int(entry["total"]) or ((row[3] as Vector3).distance_to(_player_position.call()) < ROCK_NEAR_M and _rock_added_frame < ROCK_SHAPES_PER_FRAME):
		_rock_body(id)


# Big rocks the way the Godot community draws many of them (PR #1988, boulders/PLAN_big_boulders.md, Dave 27 Nov 2026 "yes"): a server boulder
# is drawn in its ROCK_BLOCK_M block's MultiMeshes, one draw a mesh and material a block (rocks8 at 32 m cells: about 13 meshes a cell, several
# hundred draws in range, +2.2 ms at Low), refilled only when a rock of the block comes, goes, moves or is first worked (ROCK_REFILL_PER_FRAME
# blocks a frame); rocks are listed by 32 m cell for the near look; collision only near the player: a rock within ROCK_NEAR_M gets a StaticBody3D of its own (its hull and
# its talus chunks' convex hulls, made before it enters the tree and never changed in it, at most ROCK_SHAPES_PER_FRAME shapes a frame), freed again past
# ROCK_FAR_M. A worked rock keeps its body and draws itself (cracks, shrinking). Drawn to ROCK_DRAW_M; past it the ground's rock texture carries
# the mountain.
const ROCK_NEAR_M := 40.0
const ROCK_FAR_M := 50.0
const ROCK_DRAW_M := 160.0
const ROCK_CELL_M := 32.0
const ROCK_BLOCK := 3        # cells a side of a drawing block (96 m)
const ROCK_SKIRT_DRAW_M := 70.0    # talus chunks are small: drawn nearer than the rocks
const ROCK_SKIRT_LOW_M := 30.0     # Low: talus only round the blocks nearest the player
const ROCK_LOW_SMALL_R := 0.8      # Low: rocks smaller than this radius drawn only to ROCK_FULL_M
const ROCK_FULL_M := 70.0          # nearer than this (block middle) whole rocks are drawn full (320 faces) with shadows; farther, 80 faces and none
# (rocks10: +1.5 ms at Low against dev, with every rocky-ground rock at 320 faces and casting shadows to 160 m)
const FIELD_TALL := 1.4      # a rocky-ground rock stands taller than the flat ore-rock mesh (coordinator on rocks8: "tall not flat")
const ROCK_SHAPES_PER_FRAME := 64   # collision shapes made a frame (rocks14: a run into a foot field built up to 6 rocks of 37 shapes a frame, 7 frames over 50 ms)
const ROCK_REFILL_PER_FRAME := 4
const ROCK_LOOK_S := 0.25


# The cell a rock is drawn in.
func _rock_cell_of(entry: Dictionary) -> Vector2i:
	var p: Vector3 = entry["pos"]
	return Vector2i(int(floor(p.x / ROCK_CELL_M)), int(floor(p.z / ROCK_CELL_M)))


# Quality change (terrain_client _apply_quality): at Low every rock is the light 80-face copy, rocks under ROCK_LOW_SMALL_R radius are drawn
# only near, and the talus only round the nearest blocks; the big boulders keep their full reach. Every block draws again.
func set_rock_quality(quality: int) -> void:
	if _rock_low == (quality == 0):
		return

	_rock_low = quality == 0

	for cell in _rock_cells:
		_rock_dirty[_rock_block_of(cell)] = true


func _rock_block_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / ROCK_BLOCK), floori(float(cell.y) / ROCK_BLOCK))


# Lists a rock in the cell it lies in and marks that cell's block to draw again (its old cell drops it at the old block's refill).
func _rock_cell_dirty(id: int) -> void:
	var cell: Vector2i = _rock_cell_of(_boulders[id])

	if not _rock_cells.has(cell):
		_rock_cells[cell] = {}

	_rock_cells[cell][id] = true
	_rock_dirty[_rock_block_of(cell)] = true


# The rocky ground's rock: the granite with a little moss on its tops only (rocks8: the boulder granite's moss turned every rock seen from above
# into a dark green pad), a lighter grey.
func _field_rock_material() -> ShaderMaterial:
	if _field_rock == null:
		_field_rock = _boulder_rock.duplicate() as ShaderMaterial
		_field_rock.set_shader_parameter("stone_color", Vector3(0.40, 0.39, 0.37))
		_field_rock.set_shader_parameter("mossiness", 0.28)

	return _field_rock


# The rock's own place and turn: at its spot, turned by its yaw, leaning with a steep face when it is a crag.
func _rock_basis(entry: Dictionary) -> Basis:
	var turn: Basis = Basis(Vector3.UP, deg_to_rad(float(entry["yaw"])))
	var tilt: Array = entry["tilt"]

	if tilt.size() >= 2:   # a crag on a steep mountainside leans with the face (PR #1988): its up is the ground's normal, from its fall per metre along x and z
		return Basis(Quaternion(Vector3.UP, Vector3(-float(tilt[0]), 1.0, -float(tilt[1])).normalized())) * turn

	return turn


# A whole rock's drawn mesh within its place: scaled to its radius and sunk a fifth, as _size_boulder sizes the lump.
func _rock_lump_xf(entry: Dictionary) -> Transform3D:
	var box: AABB = (entry["mesh"] as Mesh).get_aabb()
	var size_k: float = float(entry["radius"]) / maxf(maxf(box.size.x, box.size.z) * 0.5, 0.01)
	var tall_k: float = size_k * float(entry["tall"])
	return Transform3D(Basis.from_scale(Vector3(size_k, tall_k, size_k)), Vector3(0.0, -(box.position.y + box.size.y * 0.2) * tall_k, 0.0))


# The talus skirt's place: on the ground under the rock's middle, lying with the slope.
func _rock_skirt_xf(entry: Dictionary) -> Transform3D:
	var skirt: Array = entry["skirt"]
	var up: Vector3 = Vector3(-float(skirt[0]), 1.0, -float(skirt[1])).normalized()   # the ground's normal from its fall per metre
	return Transform3D(Basis(Quaternion(Vector3.UP, up)), (entry["pos"] as Vector3) + Vector3(0.0, float(skirt[2]), 0.0))


# Gives a rock its body: its hull (sized by _size_boulder), its lump (drawn only once worked) and its talus chunks' hulls, all made before the body
# enters the tree.
func _rock_body(id: int) -> void:
	var entry: Dictionary = _boulders[id]

	if entry["node"] != null:
		return

	_rock_added_frame += 1 + ((_skirt_mesh(int(entry["variant"]))[1] as Array).size() if (entry["skirt"] as Array).size() >= 3 else 0)
	var body: StaticBody3D = StaticBody3D.new()
	body.set_meta("boulder", true)   # the look label names it (terrain_client _inspect_target: it showed the soil under it, TEST-013)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = ConvexPolygonShape3D.new()   # the drawn rock's own hull (_size_boulder)
	body.add_child(shape)
	var lump: MeshInstance3D = MeshInstance3D.new()
	lump.mesh = entry["mesh"]
	lump.material_override = entry["material"]
	lump.visible = int(entry["left"]) < int(entry["total"])   # a whole rock is drawn by its cell; a worked one draws itself
	body.add_child(lump)   # the crack overlay comes with the first blow (_size_boulder)
	body.transform = Transform3D(_rock_basis(entry), entry["pos"])
	# A shape that would come into being round the player (a rock that turns solid where the player already stands: a join, a teleport, a
	# body made late) is left open until the player is clear of it, so nobody is ever shut inside a rock or pushed down through the ground by
	# it (rocks15: a run that began inside a boulder field fell 1.4 m under the ground). [shape, middle, reach] in entry "open".
	var player: Vector3 = _player_position.call() if _player_position.is_valid() else Vector3.INF
	var left_open: Array = []
	var radius: float = float(entry["radius"])

	if _rock_round_player((entry["pos"] as Vector3) + Vector3(0.0, radius * 0.3, 0.0), radius * 1.1, player):
		shape.disabled = true
		left_open.append([shape, (entry["pos"] as Vector3) + Vector3(0.0, radius * 0.3, 0.0), radius * 1.1])

	if (entry["skirt"] as Array).size() >= 3:
		var skirt_xf: Transform3D = _rock_skirt_xf(entry)
		var local: Transform3D = body.transform.affine_inverse() * skirt_xf
		var r: float = snappedf(radius, 0.1)
		var spheres: Array = _skirt_mesh(int(entry["variant"]))[3]
		var hulls: Array = _skirt_hulls(int(entry["variant"]), radius)

		for n in hulls.size():
			var chunk: CollisionShape3D = CollisionShape3D.new()
			chunk.shape = hulls[n]
			chunk.transform = local
			var middle: Vector3 = skirt_xf * ((spheres[n][0] as Vector3) * r)

			if _rock_round_player(middle, float(spheres[n][1]) * r, player):
				chunk.disabled = true
				left_open.append([chunk, middle, float(spheres[n][1]) * r])

			body.add_child(chunk)

	if not left_open.is_empty():
		entry["open"] = left_open

	entry["node"] = body
	entry["shape"] = shape
	entry["lump"] = lump
	entry.erase("now")
	_size_boulder(entry)
	_root.add_child(body)
	_rock_near[id] = true


# A dug-under rock drops from `from` onto its new spot (its node is already there) as a falling body does, in BoulderFall.fall_s.
func _rock_fall(id: int, from: Vector3, drop: float) -> void:
	var entry: Dictionary = _boulders[id]
	var body: Node3D = entry["node"]
	var to: Vector3 = entry["pos"]

	if entry.get("fall") is Tween and (entry["fall"] as Tween).is_valid():
		(entry["fall"] as Tween).kill()   # a second dig while it still falls: it drops on from the last spot

	(entry["lump"] as MeshInstance3D).visible = true   # it draws itself while it falls
	body.position = from

	if not body.is_inside_tree():
		body.position = to
		return

	var fall: Tween = body.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(body, "position", to, BoulderFall.fall_s(drop))
	fall.tween_callback(_rock_landed.bind(id))
	entry["fall"] = fall


# The fall is over: a whole rock goes back into its block's MultiMesh.
func _rock_landed(id: int) -> void:
	var entry: Dictionary = _boulders.get(id, {})

	if entry.is_empty():
		return

	entry.erase("fall")

	if entry["lump"] != null:
		(entry["lump"] as MeshInstance3D).visible = int(entry["left"]) < int(entry["total"])

	_rock_cell_dirty(id)


# True when the player's capsule (its middle `player`, about 1 m round it) reaches into a sphere of `reach` round `middle`.
func _rock_round_player(middle: Vector3, reach: float, player: Vector3) -> bool:
	return player.is_finite() and player.distance_to(middle) < reach + 1.0


func _rock_unbody(id: int) -> void:
	var entry: Dictionary = _boulders[id]
	_rock_near.erase(id)

	if entry["node"] == null:
		return

	(entry["node"] as Node).queue_free()
	entry["node"] = null
	entry["shape"] = null
	entry["lump"] = null
	entry.erase("now")
	entry.erase("open")

	if entry.has("fall"):   # freed while it fell (its tween goes with it): drawn by its block again
		entry.erase("fall")
		_rock_cell_dirty(id)


# Each frame: a few dirty cells drawn again; every ROCK_LOOK_S the rocks round the player get their bodies (at most ROCK_SHAPES_PER_FRAME shapes a frame;
# a full talus round a player arriving at a run takes three frames) and the whole ones gone past ROCK_FAR_M lose theirs. Only the cells within
# reach of the player and the rocks with bodies are looked at, never every rock.
func _rock_tick() -> void:
	_rock_added_frame = 0
	var refilled: int = 0

	for cell in _rock_dirty.keys():
		if refilled >= ROCK_REFILL_PER_FRAME:
			break

		_rock_dirty.erase(cell)
		_rock_refill(cell)
		refilled += 1

	if not _player_position.is_valid():
		return

	var now: int = Time.get_ticks_msec()

	if now - _rock_look_msec < int(ROCK_LOOK_S * 1000.0) and not _rock_look_more:
		return

	_rock_look_msec = now
	_rock_look_more = false
	var at: Vector3 = _player_position.call()

	for id in _rock_near.keys():
		var entry: Dictionary = _boulders.get(id, {})

		if entry.is_empty():
			_rock_near.erase(id)
		elif int(entry["left"]) >= int(entry["total"]) and not entry.has("fall") and (entry["pos"] as Vector3).distance_to(at) > ROCK_FAR_M:
			_rock_unbody(id)
		elif entry.has("open"):
			var still: Array = []

			for gap in entry["open"]:   # a shape left open round the player turns solid once the player is clear of it
				if _rock_round_player(gap[1], float(gap[2]), at):
					still.append(gap)
				elif is_instance_valid(gap[0]):
					(gap[0] as CollisionShape3D).disabled = false

			if still.is_empty():
				entry.erase("open")
			else:
				entry["open"] = still

	var mid: Vector2i = Vector2i(int(floor(at.x / ROCK_CELL_M)), int(floor(at.z / ROCK_CELL_M)))
	var reach: int = int(ceil(ROCK_NEAR_M / ROCK_CELL_M))

	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			for id in _rock_cells.get(mid + Vector2i(dx, dz), {}):
				var entry: Dictionary = _boulders.get(id, {})

				if entry.is_empty() or entry["node"] != null or (entry["pos"] as Vector3).distance_to(at) >= ROCK_NEAR_M:
					continue

				if _rock_added_frame >= ROCK_SHAPES_PER_FRAME:
					_rock_look_more = true   # the rest next frame
					return

				_rock_body(id)


# Draws a block's whole rocks and talus skirts again: one MultiMeshInstance3D per mesh and material, the block's old ones freed. A rock gone or
# moved out of a cell of the block is dropped from that cell's list here.
func _rock_refill(block: Vector2i) -> void:
	for node in _rock_draws.get(block, []):
		(node as Node).queue_free()

	var groups: Dictionary = {}   # [mesh, material, shadows, range] key -> [mesh, material, shadows, range, transforms]

	for bx in ROCK_BLOCK:
		for bz in ROCK_BLOCK:
			var cell: Vector2i = block * ROCK_BLOCK + Vector2i(bx, bz)

			if not _rock_cells.has(cell):
				continue

			var ids: Dictionary = _rock_cells[cell]

			for id in ids.keys():
				if not _boulders.has(id) or _rock_cell_of(_boulders[id]) != cell:
					ids.erase(id)
					continue

				var entry: Dictionary = _boulders[id]

				if (entry["skirt"] as Array).size() >= 3:
					var skirt: Array = _skirt_mesh(int(entry["variant"]))
					var skirt_place: Transform3D = _rock_skirt_xf(entry) * Transform3D(Basis.from_scale(Vector3.ONE * snappedf(float(entry["radius"]), 0.1)), Vector3.ZERO)   # the size its collision has

					if int(entry["variant"]) >= SKIRT_VARIANTS:   # a foot band's boulder field: seen as far as the rocks, light past the near blocks
						_rock_group(groups, skirt[0], _field_rock_material(), not _rock_low, ROCK_SKIRT_LOW_M if _rock_low else ROCK_FULL_M).append(skirt_place)
						_rock_group(groups, skirt[2], _field_rock_material(), false, ROCK_DRAW_M, ROCK_SKIRT_LOW_M if _rock_low else ROCK_FULL_M).append(skirt_place)
					else:
						_rock_group(groups, skirt[0], _field_rock_material(), false, ROCK_SKIRT_LOW_M if _rock_low else ROCK_SKIRT_DRAW_M).append(skirt_place)

				if int(entry["left"]) >= int(entry["total"]) and not entry.has("fall"):   # a worked or falling rock draws itself
					var place: Transform3D = Transform3D(_rock_basis(entry), entry["pos"]) * _rock_lump_xf(entry)
					if _rock_low:   # every rock light (Low has no sun shadows anyway); the small ones only near, the big ones as far as ever
						_rock_group(groups, OreRockLook.low_of(entry["mesh"]), entry["material"], false, ROCK_DRAW_M if float(entry["radius"]) >= ROCK_LOW_SMALL_R else ROCK_FULL_M).append(place)
					else:
						_rock_group(groups, entry["mesh"], entry["material"], true, ROCK_FULL_M).append(place)
						_rock_group(groups, OreRockLook.low_of(entry["mesh"]), entry["material"], false, ROCK_DRAW_M, ROCK_FULL_M).append(place)

			if ids.is_empty():
				_rock_cells.erase(cell)

	var nodes: Array = []

	for key in groups:
		var group: Array = groups[key]
		var transforms: Array = group[4]
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = group[0]
		multi.instance_count = transforms.size()

		for n in range(transforms.size()):
			multi.set_instance_transform(n, transforms[n])

		var drawn: MultiMeshInstance3D = MultiMeshInstance3D.new()
		drawn.multimesh = multi
		drawn.material_override = group[1]
		drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(group[2]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drawn.visibility_range_end = float(group[3]) + ROCK_CELL_M * ROCK_BLOCK * 0.5   # measured from the block's middle

		if float(group[5]) > 0.0:
			drawn.visibility_range_begin = float(group[5]) + ROCK_CELL_M * ROCK_BLOCK * 0.5   # the far copy takes over where the full one ends
			drawn.visibility_range_begin_margin = 10.0
		drawn.visibility_range_end_margin = 10.0   # hysteresis, no alpha fade (an alpha fade draws transparent: the HLOD docs' cost warning)
		_root.add_child(drawn)
		nodes.append(drawn)

	if nodes.is_empty():
		_rock_draws.erase(block)
	else:
		_rock_draws[block] = nodes


func _rock_group(groups: Dictionary, mesh: Mesh, material: Material, shadows: bool, reach: float, from: float = 0.0) -> Array:
	var key: String = "%d:%d:%s:%.0f:%.0f" % [mesh.get_instance_id(), material.get_instance_id(), str(shadows), from, reach]   # reach too: at Low small and big rocks share a mesh but not a reach

	if not groups.has(key):
		groups[key] = [mesh, material, shadows, reach, [], from]

	return groups[key][4]



const SKIRT_VARIANTS := 4   # talus variants; the next SKIRT_VARIANTS are the foot band's boulder fields
const FOOT_CHUNKS := 36     # big broken boulders in a foot field round a rock (Dave 27 Nov 2026: "multiply the boulders numbers by like 30 and make them bigger the lower they go")
const SKIRT_STONES := 16   # small broken stones in a skirt, SKIRT_NEAR to SKIRT_FAR radii out
const SKIRT_CHUNKS := 14   # broken chunks round the rock (Dave 27 Nov 2026: "broken rocks and smaller 1-3m chunks in between and on the ground around them")


# The talus round a big mountain rock of radius 1 (PR #1988): SKIRT_CHUNKS angular chunks 0.25 to 0.7 radii in size, 1.1 to 2.6 radii out, packed
# against the rock and each other without overlapping, set a third into the ground, with SKIRT_STONES small broken stones between them; all on
# the ground plane (y 0). Seeded by `variant`, so every skirt of a variant is the same mesh. [mesh, each chunk's points at unit radius (its convex
# hull, scaled per rock by _skirt_hulls)]. Two chunks either touch or leave a gap of half a radius or more: a gap a foot could stick in is not made
# (the physics engines' advice on walking over rubble, boulders/PLAN_big_boulders.md).
# A foot field reaches up to 4.5 radii from its rock, past the server's keep_clear_m round it: a building put up inside one takes that rock's talus
# off (server_items _bare_skirts_near), and the client draws and builds it again without.
func _skirt_mesh(variant: int) -> Array:
	while _skirt_meshes.size() < SKIRT_VARIANTS * 2:
		var foot: bool = _skirt_meshes.size() >= SKIRT_VARIANTS   # a foot field: FOOT_CHUNKS chunks 0.35 to 0.95 radii, out to 4.5 radii
		var chunks: int = FOOT_CHUNKS if foot else SKIRT_CHUNKS
		var pebble: ArrayMesh = load("res://src/client/grass_view.gd")._make_pebble()
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 9100 + _skirt_meshes.size()
		var tool: SurfaceTool = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var far: SurfaceTool = SurfaceTool.new()   # the same chunks of 20 faces, drawn past the near blocks
		far.begin(Mesh.PRIMITIVE_TRIANGLES)
		var hulls: Array = []
		var spheres: Array = []
		var low: Array = []   # three small-chunk shapes of 80 faces (rocks8: 9 chunks of 320 faces a skirt drew over a million triangles in range)

		var lowest: Array = []

		for k in 3:
			low.append(OreRockLook.make_mesh(201 + k * 17, 8, 0.3, 0.4, 1.25, 1))
			lowest.append(OreRockLook.make_mesh(201 + k * 17, 8, 0.3, 0.4, 1.25, 0))

		var placed: Array = [[0.0, 0.0, 1.0]]   # [x, z, size]: the rock itself, then each chunk

		for n in range(chunks * 8):   # tries: a chunk that would overlap another is left out
			if placed.size() > chunks:
				break

			var angle: float = rng.randf() * TAU
			var size: float = lerpf(0.35, 0.95, pow(rng.randf(), 1.2)) if foot else lerpf(0.25, 0.7, pow(rng.randf(), 1.4))
			var out: float = (lerpf(1.1, 4.5, sqrt(rng.randf())) if foot else lerpf(1.1, 2.6, rng.randf())) + size * 0.5
			var at: Vector2 = Vector2(cos(angle), sin(angle)) * out
			var clear: bool = true

			for q in placed:
				var gap: float = at.distance_to(Vector2(float(q[0]), float(q[1]))) - size - float(q[2])
				if foot:   # a field hard to cross: packed, touching or a gap of at least 0.2 radii (0.4 m at the smallest foot rock)
					clear = clear and gap > -(size + float(q[2])) * 0.25 and (gap < 0.0 or gap >= 0.2)
				else:
					clear = clear and gap > -(size + float(q[2])) * 0.15 and (gap < 0.0 or gap >= 0.5)   # a little into each other, or well apart

			if not clear:
				continue

			placed.append([at.x, at.y, size])
			var pick: int = rng.randi() % low.size()
			var chunk: ArrayMesh = low[pick]   # fresh, angular
			var box: AABB = chunk.get_aabb()
			var unit: float = maxf(maxf(box.size.x, box.size.z) * 0.5, 0.01)
			var place: Transform3D = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3(1.0, 0.0, 0.0), rng.randf_range(-0.35, 0.35)).scaled(Vector3.ONE * (size / unit)),
				Vector3(at.x, -(box.position.y + box.size.y * 0.35) * (size / unit), at.y))   # a third set into the ground
			tool.append_from(chunk, 0, place)
			far.append_from(lowest[pick], 0, place)
			var points: PackedVector3Array = PackedVector3Array()

			for v in chunk.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				points.append(place * v)

			hulls.append(points)
			var bounds: AABB = AABB(points[0], Vector3.ZERO)

			for v in points:
				bounds = bounds.expand(v)

			spheres.append([bounds.get_center(), bounds.size.length() * 0.5])   # a sphere round the chunk (the open-round-the-player test)

		for n in range(SKIRT_STONES):
			var angle: float = rng.randf() * TAU
			var out: float = lerpf(1.05, 3.0, pow(rng.randf(), 1.3))
			var size: float = lerpf(0.06, 0.18, rng.randf())
			tool.append_from(pebble, 0, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(cos(angle) * out, -0.25 * size, sin(angle) * out)))

		_skirt_meshes.append([tool.commit(), hulls, far.commit(), spheres])

	return _skirt_meshes[variant]


# The collision of a skirt's chunks at `radius` (a talus field to climb over, not walk through): a convex hull a chunk (cheaper than one concave
# mesh for Jolt), one set a variant and size, shared by every rock of that size (to 0.1 m).
func _skirt_hulls(variant: int, radius: float) -> Array:
	var r: float = snappedf(radius, 0.1)
	var key: String = "%d:%.1f" % [variant, r]

	if not _skirt_hulls_made.has(key):
		var made: Array = []

		for points in _skirt_mesh(variant)[1]:
			var scaled: PackedVector3Array = PackedVector3Array()

			for v in points:
				scaled.append(v * r)

			var hull: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
			hull.points = scaled
			made.append(hull)

		_skirt_hulls_made[key] = made

	return _skirt_hulls_made[key]


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


const SHRINK_EASE_S := 0.15   # how long a blow takes to ease a boulder down to its new size (look only; PROVISIONAL BW-3)


var _boulder_hulls: Dictionary = {}   # rock mesh -> its convex hull points (unscaled), made once per mesh
var _hull_queue: Array = []           # rock meshes whose hulls are still to make, one a frame from the join (_queue_rock_hulls)


# Lag lane 23 Nov 2026 (robot route, cloud): each rock mesh's hull took 43-67 ms on the main thread the first time a boulder of that shape was
# drawn, so walking into new ground hitched 50-200 ms ("world items ... slowest row: state 10"). The ten rock meshes' hulls are made at the
# join instead, one a frame while the ground loads.
func _queue_rock_hulls() -> void:
	if _boulder_mesh == null:
		_boulder_mesh = load("res://src/client/grass_view.gd")._make_boulder()

	OreRockLook.mesh_for(0.0)   # builds every rock shape (7 ms)
	_hull_queue = [_boulder_mesh]

	for shape in OreRockLook._meshes:
		_hull_queue.append_array(shape)


func _hull_step() -> void:
	var mesh: Mesh = _hull_queue.pop_front()
	_boulder_hull(mesh)

	if _hull_queue.is_empty():
		FreezeWatchScript.printer.line("client prewarm: rock hulls made (%d)" % _boulder_hulls.size())


func _boulder_hull(mesh: Mesh) -> PackedVector3Array:
	if not _boulder_hulls.has(mesh):
		var convex: ConvexPolygonShape3D = mesh.create_convex_shape(true, true)
		_boulder_hulls[mesh] = convex.points if convex != null else PackedVector3Array()

	return _boulder_hulls[mesh]


# Scale to the radius still left (BoulderWear: in a straight line with the stones left, from the first blow), sunk a fifth into the ground like Art's scenery boulders.
func _size_boulder(entry: Dictionary) -> void:
	var box: AABB = (entry["lump"].mesh as Mesh).get_aabb()
	var radius: float = BoulderWear.radius_now(float(entry["radius"]), int(entry["left"]), int(entry["total"]))
	var unit: float = maxf(maxf(box.size.x, box.size.z) * 0.5, 0.01)
	var scale: float = radius / unit
	var was: float = float(entry.get("now", -1.0))
	entry["now"] = radius
	var sizes: Vector3 = Vector3(scale, scale * float(entry.get("tall", 1.0)), scale)
	var lump_at: Vector3 = Vector3(0.0, -(box.position.y + box.size.y * 0.2) * sizes.y, 0.0)
	var lump_node: MeshInstance3D = entry["lump"]

	# A blow eases the rock down to its new size over SHRINK_EASE_S (smooth motion; a small rock loses a big share a blow). The first draw sets it.
	if was >= 0.0 and is_equal_approx(was, radius) and entry.get("shrink") is Tween and (entry["shrink"] as Tween).is_valid():
		pass   # same size (a settle or a resend): leave an ease that is still running to finish
	elif was >= 0.0 and not is_equal_approx(was, radius) and lump_node.is_inside_tree():
		if entry.get("shrink") is Tween:
			(entry["shrink"] as Tween).kill()   # a quick second blow starts from where the last ease had got to

		var shrink: Tween = lump_node.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		shrink.tween_property(lump_node, "scale", sizes, SHRINK_EASE_S)
		shrink.tween_property(lump_node, "position", lump_at, SHRINK_EASE_S)
		entry["shrink"] = shrink
	else:
		lump_node.scale = sizes
		lump_node.position = lump_at

	# The collider is the drawn rock's hull at its new size (world audit 23 Nov 2026: a sphere of 0.85 x the radius half a radius up stood 0.65 of a
	# radius above the drawn top, about 1.35 against 0.7, so a player stood on air over every boulder, and its sides were inside the rock at the shins).
	# Rebuilt only when the size changed (a resend or a settle keeps it); a mesh with no hull keeps a sphere at the drawn height.
	if not (was >= 0.0 and is_equal_approx(was, radius)):
		var hull: PackedVector3Array = _boulder_hull(entry["lump"].mesh as Mesh)

		if hull.is_empty():
			push_warning("boulder mesh has no convex hull: a sphere collider instead")
			var ball: SphereShape3D = SphereShape3D.new()
			ball.radius = radius * 0.6
			entry["shape"].shape = ball
			entry["shape"].position = Vector3(0.0, radius * 0.1, 0.0)
		else:
			var points: PackedVector3Array = PackedVector3Array()
			points.resize(hull.size())

			for k in hull.size():
				points[k] = hull[k] * sizes + lump_at

			var convex: ConvexPolygonShape3D = entry["shape"].shape as ConvexPolygonShape3D

			if convex == null:
				convex = ConvexPolygonShape3D.new()
				entry["shape"].shape = convex
				entry["shape"].position = Vector3.ZERO

			convex.points = points
	var crack: float = BoulderWear.crack(int(entry["left"]), int(entry["total"]))
	lump_node.material_overlay = _crack_material() if crack >= 0.01 else null   # the overlay draws nothing under 0.01 (CRACK_SHADER discards): a whole rock skips that second pass
	lump_node.set_instance_shader_parameter("crack", crack)   # cracks from the first blow, more and wider as the rock is used up
	lump_node.set_instance_shader_parameter("crack_scale", 1.0 / unit)


# Cracks over a worked boulder (BugsList entry 3, Dave 18 Nov 2026: a rock must visibly use up as it is mined). Drawn as an overlay on whatever rock
# material the boulder has (granite, copper, tin): dark Voronoi cell edges in the rock's own space, none on a whole rock, a few fine ones once it is worked,
# more and wider ones as it nears its end. PLACEHOLDER look: not visually checked.
const CRACK_SHADER := """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;
instance uniform float crack = 0.0;
instance uniform float crack_scale = 1.0;
varying vec3 obj;
void vertex() { obj = VERTEX; }
vec3 h3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}
void fragment() {
	if (crack < 0.01) { discard; }
	vec3 p = obj * crack_scale * (1.5 + crack * 4.0);
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int x = -1; x <= 1; x++) { for (int y = -1; y <= 1; y++) { for (int z = -1; z <= 1; z++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 r = g + h3(i + g) - f;
		float d = dot(r, r);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	} } }
	float width = 0.015 + 0.06 * crack;
	float edge = sqrt(d2) - sqrt(d1);
	ALBEDO = vec3(0.03, 0.025, 0.02);
	ALPHA = (1.0 - smoothstep(width * 0.3, width, edge)) * clamp(crack * 4.0, 0.0, 0.9);
}
"""


func _crack_material() -> ShaderMaterial:
	if _boulder_cracks == null:
		var shader: Shader = Shader.new()
		shader.code = CRACK_SHADER
		_boulder_cracks = ShaderMaterial.new()
		_boulder_cracks.shader = shader

	return _boulder_cracks


# A boulder worked down to its last stones breaks apart where it stood (BugsList entry 3): a few fragments of its rock fly out and shrink away in under a
# second. Drawing only; the server has already taken the rock out of the world. PLACEHOLDER look: not visually checked.
func _crumble_boulder(entry: Dictionary) -> void:
	if entry["node"] == null:
		return   # only drawn in its cell (never worked here): nothing to break apart

	var lump: MeshInstance3D = entry["lump"]
	var at: Vector3 = (entry["node"] as Node3D).global_position + Vector3(0.0, float(entry.get("now", 0.3)) * 0.5, 0.0)

	for n in 6:
		var bit: MeshInstance3D = MeshInstance3D.new()
		bit.mesh = lump.mesh
		bit.material_override = lump.material_override
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(bit)
		bit.global_position = at
		bit.scale = lump.scale * 0.3
		var out: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * float(n) / 6.0) * (0.4 + float(entry.get("now", 0.3)))
		var tween: Tween = bit.create_tween().set_parallel(true)
		tween.tween_property(bit, "global_position", at + out + Vector3(0.0, -0.2, 0.0), 0.8).set_ease(Tween.EASE_OUT)
		tween.tween_property(bit, "scale", Vector3.ONE * 0.001, 0.8).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(bit.queue_free)


# The boulder a strike at this point landed on (0 when none): within its radius and a little; of rocks lying together (scree, rocky ground)
# the one whose edge is nearest the point, so a blow lands on the rock struck, not on a neighbour listed first.
func boulder_near(point: Vector3) -> int:
	var best: int = 0
	var best_gap: float = INF

	for id in _boulders:
		var entry: Dictionary = _boulders[id]
		var flat: float = Vector2(point.x - entry["pos"].x, point.z - entry["pos"].z).length()

		var now: float = float(entry.get("now", entry["radius"]))

		# A small copper rock gets a small margin, so a blow at a trunk or the ground beside it is not taken as a blow on the rock.
		if flat <= now + minf(0.7, 0.2 + now * 2.0) and absf(point.y - entry["pos"].y) < 2.5 + float(entry["radius"]) and flat - now < best_gap:
			best = id
			best_gap = flat - now

	return best


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

				if int(entry["state"]) != 0 or entry.get("log", false) or entry.get("pile", false) or int(entry["count"]) > 5 or _rolling.has(id) or _gliding.has(id) or _falling.has(id):   # a log is a body in the server's physics (pushed by walking into it, walker_logs); a falling piece is moved by _swing_down
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
	_falling.erase(id)
	_unsnapped.erase(id)

	if _boulders.has(id):
		var gone: Dictionary = _boulders[id]

		if int(gone["left"]) <= maxi(3, int(float(gone["total"]) * 0.03)) and _player_position.is_valid() and (gone["pos"] as Vector3).distance_to(_player_position.call()) < 30.0:
			_crumble_boulder(gone)   # mined out, not just out of range

		_rock_cell_dirty(id)   # its cell draws again without it
		_rock_unbody(id)
		_boulders.erase(id)
		return

	if bogs.has(id):
		if bogs[id].get("node") is Node3D:
			(bogs[id]["node"] as Node3D).queue_free()

		bogs.erase(id)
		bogs_rev += 1
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


# A locked recipe (recipes.json "locked": a chain it needs does not exist yet) is never lit: the server would refuse it.
func _can_craft(number: int) -> bool:
	if not _free_craft() and bool(recipes.recipe(number).get("locked", false)):
		return false

	return _free_craft() or (hand_tool_ok(number) and (_stock_can_make(number) or _logs_cover(number) or (bool(_parts_plan(number)["ok"]) and hand_tool_short(number) == "")))


# A recipe that keeps a tool crafts only with that tool, unbroken, in the pack or on the hotbar (CraftStock.has_tool, Dave 24 Nov 2026); the server checks it again.
func hand_tool_ok(number: int) -> bool:
	return CraftStock.has_tool(recipes.recipe(number), table, inventory)   # anywhere in the pack or on the hotbar (Dave 24 Nov 2026)


# The words for the tool the recipe, or a part its auto-make plan makes on the way (a Wooden block sawn for a carved Wooden bowl), needs and the
# pack lacks ("any saw"); "" when none.
func hand_tool_short(number: int) -> String:
	if not hand_tool_ok(number):
		return CraftStock.hand_words(recipes.recipe(number), table)

	if _stock_can_make(number):
		return ""

	for step in _parts_plan(number)["steps"]:
		if not hand_tool_ok(int(step["recipe"])):
			return CraftStock.hand_words(recipes.recipe(int(step["recipe"])), table)

	return ""


# Left click with a saw in hand (Dave 17 Nov 2026): the crafting screen opens on the Carpenter's tab, what a saw makes; Craft then draws the logs
# from the ground near you as any craft does.
func open_crafting_on(category: String) -> void:
	if chest_mode:
		_close_chest()

	_recipe_part.show_category(category)

	if open:
		_refresh()
	else:
		toggle()


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


func _on_autoload_info(id: int, number: int) -> void:
	if id != chest_id:
		return

	chest_autoload = number

	if chest_mode:
		_container_part.refresh()


# Autoload (protocol 139): what lies loose on the ground within AUTOLOAD_M of the open container that it takes, from the items this client was
# sent (every item within 100 m of the player): [[item number, total count, nearest metres], ...], nearest first. The server checks it all again.
const AUTOLOAD_M := 30.0   # server_items.gd AUTOLOAD_M


func autoload_choices(takes: Callable) -> Array:
	if not chest_mode or not _world.has(chest_id):
		return []

	var here: Vector3 = _world[chest_id]["pos"]
	var found: Dictionary = {}   # number -> [number, total, nearest]

	for id in _world:
		var w: Dictionary = _world[id]

		if int(w["state"]) != 0 or int(w["number"]) <= 0 or id == chest_id:
			continue

		var d: float = here.distance_to(w["pos"])

		if d > AUTOLOAD_M or not bool(takes.call(int(w["number"]))):
			continue

		var row: Array = found.get(int(w["number"]), [int(w["number"]), 0, d])
		row[1] = int(row[1]) + int(w["count"])
		row[2] = minf(float(row[2]), d)
		found[int(w["number"])] = row

	var out: Array = found.values()
	out.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	return out


# Loads the open container with `number` from the ground round it; `keep`: and keep loading it every 10 minutes. 0 stops the standing autoload.
func autoload(number: int, keep: bool) -> void:
	if chest_mode and chest_id >= 0 and net != null:
		net.inventory_action.rpc_id(1, Net.ACT_AUTOLOAD, chest_id, number, 1 if keep else 0, Vector3.ZERO)


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


# The saw recipes' Softwood and Hardwood logs lying within 3 m, kept like station_near's answers (each saw recipe asked for a walk over the world).
func _nearby_logs_of(group_id: String) -> int:
	_memo_frame()
	var key: String = "logs|" + group_id

	if not _near_memo.has(key):
		_near_memo[key] = _nearby_logs_now(group_id)

	return int(_near_memo[key])


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
			if inventory.count_fill(int(need[0])) + _nearby_logs_of("log_spruce" if int(need[0]) == soft_n else "log_oak") < int(need[1]):
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


var _label_memo: Dictionary = {}   # "station|level" -> _station_label's answer (structures.json does not change while the game runs)


# The station that makes a recipe, by name: the first structure whose own station serves it at the recipe's level (steel at brick forge level 3
# names the Advanced smithy, not the Improved one; GOALS-REPAIR R4), else one that carries it as an "also" station at that level.
# Each recipe row asked this twice, each a walk over all 346 structure kinds; the answer is kept per station and level.
func _station_label(r: Dictionary) -> String:
	var key: String = "%s|%d" % [str(r.get("station", "")), int(r.get("station_level", 1))]

	if not _label_memo.has(key):
		_label_memo[key] = _station_label_now(r)

	return _label_memo[key]


func _station_label_now(r: Dictionary) -> String:
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
# Drawn for the Primitive and Improved smelters; also the Primitive smithy's stand-in when its own model (_make_primitive_smithy) is missing,
# then with a rough stone anvil beside its fire (Dave 17 Nov 2026: "a flat topped carved rough stone beside it for hammering on materials"),
# the forge moved aside so the two sit centred.
func _make_forge(state: int) -> Node3D:
	var model: Node3D = _forge_glb("forge_basic")

	if model == null:
		return BuildingLook.stone_forge()   # the stand-in already has an anvil

	if str(_structure_by_state(state).get("use", "")) != "smelt":
		BuildingLook.add_stone_anvil(model, FORGE_ASIDE_M, ANVIL_AT_M)

	return model


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


# The Improved smithy: Dave's model (21 Nov 2026), forge, bellows, anvil on a stump and a bench on a flagstone floor, 3 m wide ("sized so it
# fits in 3/4 of the width of a foundation"). Its coals are painted in its emission texture, so this drops the shared coals and gives the
# model its own copy of the material, whose glow BuildingLook.forge_state sets: cold ash, dim coals when idle, really bright while it works (no
# flames: Dave 22 Nov 2026). The brick forge stands in when the file is missing.
const IMPROVED_SMITHY_TONGUES := 0.3   # the (never shown) flame tongues' size on this model; the Flames node stays for the light and smoke hooks


func _make_improved_smithy() -> Node3D:
	var model: Node3D = _forge_glb("improved_smithy", false)

	if model == null:
		return _make_smithy()

	_painted_fire(model, IMPROVED_SMITHY_TONGUES)
	model.set_meta("coal_glow", _own_glow(model))
	return model


# The Primitive smithy: Dave's model (21 Nov 2026), a clay and field-stone forge at the back, a flat-topped stone anvil in front of its mouth and
# a rough bench beside it, on a patch of trodden ground, 3 m long front to back and 2.35 m wide (Dave: most things "fit neatly into 3/4 or half
# of a foundation size"; 3/4 suits it: the anvil stone's top is then at working height, about 0.78 m). Its coals are painted cold, so it
# keeps the shared coals, shrunk to its mouth, dim when idle and really bright while it works (no flames: Dave 22 Nov 2026); the lit paint
# inside the mouth glows with them (BuildingLook.forge_state). The basic forge with its stone anvil stands in when the file is missing. PROVISIONAL (PS-5, PS-6).
const PRIMITIVE_SMITHY_FLAMES := 0.5   # the shared coals' size in its mouth (about half a metre across)


func _make_primitive_smithy(state: int) -> Node3D:
	var model: Node3D = _forge_glb("primitive_smithy", false)

	if model == null:
		return _make_forge(state)

	var flames: Node3D = model.get_node_or_null("Flames") as Node3D

	if flames != null:
		flames.scale = Vector3.ONE * PRIMITIVE_SMITHY_FLAMES

	model.set_meta("coal_glow", _own_glow(model))
	return model


# A station model with painted coals or embers (tools/stations/prepare_station_model.py): its shared coals dropped and its flame tongues
# shrunk by `tongues` to stand in its own hearth.
func _painted_fire(model: Node3D, tongues: float) -> void:
	var flames: Node3D = model.get_node_or_null("Flames") as Node3D

	if flames != null:
		flames.scale = Vector3.ONE * tongues
		var coals: Node = flames.get_node_or_null("Coals")

		if coals != null:
			coals.free()


# Each glowing material of the model, copied so that this one's glow is its own (one smithy flaring or kiln lit lights no other).
func _own_glow(model: Node3D) -> Array:
	var glow: Array = []

	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = child

		if mesh_node.mesh == null:
			continue

		for surface in mesh_node.mesh.get_surface_count():
			var own: BaseMaterial3D = mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D

			if own != null and own.emission_enabled:
				var copy: BaseMaterial3D = own.duplicate() as BaseMaterial3D
				mesh_node.set_surface_override_material(surface, copy)
				glow.append(copy)

	return glow


# The Primitive kiln: Dave's model (21 Nov 2026), a long low tunnel of clay and field stones, its mouth at the front (+Z) and its chimney at the
# back, "sized so its longest side is a minimum 2.74 meters" (2.74 m long, 0.98 m wide and high). Its embers are painted in its emission
# texture: dark when cold; while lit they glow really bright, with the light at its mouth and smoke from the chimney, and no flames (Dave 22 Nov
# 2026: "the forges and kilns dont really need flames just glowing coals ... glowing really bright while busy"; a kiln is busy whenever it is
# lit). The Improved and Advanced kilns keep the brick kiln (PieceLook.kiln), which also stands in when the file is missing. Values PROVISIONAL (PK-3).
const KILN_EMBERS := 4.0          # the embers' glow while lit (0 cold)
const KILN_LIGHT := [2.0, 6.0]    # its light while lit: [energy, range m]


func _make_primitive_kiln(lit: bool) -> Node3D:
	var model: Node3D = _forge_glb("primitive_kiln", false)

	if model == null:
		return LookTable.build("kiln")

	var flames: Node = model.get_node_or_null("Flames")

	if flames != null:
		flames.free()   # its painted embers are the fire: no shared coals or flame tongues

	var glow: Array = _own_glow(model)

	for embers in glow:
		(embers as BaseMaterial3D).emission_energy_multiplier = KILN_EMBERS if lit else 0.0

	model.set_meta("coal_glow", glow)
	var light: OmniLight3D = model.get_node_or_null("Light") as OmniLight3D

	if light != null:
		light.light_energy = float(KILN_LIGHT[0])
		light.omni_range = float(KILN_LIGHT[1])
		light.set_meta("base_energy", light.light_energy)   # the nearest-lights pass flickers it round this
		light.set_meta("base_range", light.omni_range)   # FireWeather scales the reach from this in fog and snow

	BuildingLook.show_forge_fire(model, lit)
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
const FORGE_ASIDE_M := -0.25   # the Primitive smithy stand-in's forge moved along x to make room for its stone anvil (PS-2, now the stand-in only)
const ANVIL_AT_M := 0.45       # where the anvil stands along x, beside the fire


# Dave's forge meshes (assets/stations/forge_basic, forge_medium, forge_large, forge_master .glb). They arrive Z up with the fire
# opening toward -Y and the middle of the base off the origin, so this stands them up (Y up, which leaves the opening toward +Z, the front
# of every building here: placed with the camera yaw it faces the player who put it down), puts the
# centre of the footprint at the pivot and the base on the ground, and takes the flame light and smoke from the Fire and Smoke empties
# in the file. Returns null when the file is not there yet. A model made Y up already (improved_smithy.glb, from
# tools/stations/prepare_station_model.py) passes z_up false and is not turned.
func _forge_glb(file: String, z_up: bool = true) -> Node3D:
	var path: String = "res://assets/stations/%s.glb" % file

	if not ResourceLoader.exists(path):
		return null

	var scene: Variant = load(path)

	if not (scene is PackedScene):
		return null

	var model: Node3D = (scene as PackedScene).instantiate() as Node3D
	var upright: Node3D = Node3D.new()
	upright.rotation_degrees = Vector3(-90.0 if z_up else 0.0, 0.0, 0.0)
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

	for id in _placed():
		if int(_world[id]["state"]) == state and _world[id].get("light") != null and pos.distance_to(_world[id]["pos"]) <= r:
			return true

	return false


func _lit_fire_near(pos: Vector3, r: float) -> bool:
	for fire_id in _placed():
		if _lit_state(int(_world[fire_id]["state"])) and pos.distance_to(_world[fire_id]["pos"]) <= r:
			return true

	return false


# What the open station can use (station_use.gd, Dave 10 Nov 2026): item number -> StationUse.FUEL or INPUT, for the pack's order and its
# golden line. Only while a station's own window is open (Dave 10 Nov 2026: "even when I open my inventory and Im not in the campfires
# inventory the wood is still highlighted which it shouldnt be"): the container on screen is a fire (any campfire state), a structure that names
# what it takes ("takes" / "takes_kinds"), or one with a "station", stations it stands in for ("also") or its own "fuel". What a store takes is
# the server's rule (store_rules.gd). {} with the pack open on its own, a plain chest open, or the window shut.
func station_use() -> Dictionary:
	if not open or not chest_mode or not _world.has(chest_id):
		return {}

	var state: int = int(_world[chest_id]["state"])
	var stations: Array = []
	var fire: bool = StructureLook.CAMPFIRE_STATES.has(state)
	var fuels: Array = []
	var def: Dictionary = {}

	if fire:
		stations.append("campfire")
	else:
		def = _structure_by_state(state)

		for station in [str(def.get("station", ""))] + (def.get("also", {}) as Dictionary).keys():
			if str(station) != "" and not stations.has(str(station)):
				stations.append(str(station))

		if str(def.get("fuel", "")) != "":
			fuels.append(str(def["fuel"]))

		if str(def.get("fuel_slot", "")) != "":
			fuels.append(str(def["fuel_slot"]))   # a smithy's fuel slot (Coal or Charcoal)

	if stations.is_empty() and fuels.is_empty() and not StoreRules.limited(def):
		return {}

	if _cooking_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/cooking.json"))
		_cooking_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"raw_sick": {}}

	return StationUse.usable(stations, fire, fuels, recipes, table, _cooking_cfg, str(def.get("state", "")), def)


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
	if _recipe_part.running():
		return   # the recipe list works over several frames (recipe_list.gd step): its answers hold for the whole pass, until the world changes

	if Engine.get_process_frames() != _near_memo_frame:
		_near_memo_frame = Engine.get_process_frames()
		_forget_near()


# The world ids of placed things (every row with a state: structures, fires, stations; loose items are state 0), kept like the answers above.
# The station checks walked every world row, thousands of loose stones included, once per station asked (about 50 ms a pass on David4).
func _placed() -> Array:
	_memo_frame()

	if not _near_memo.has("placed"):
		var ids: Array = []

		for id in _world:
			if int(_world[id]["state"]) != 0:
				ids.append(id)

		_near_memo["placed"] = ids

	return _near_memo["placed"]


func station_near(station: String, level: int = 1, reach_m: float = 0.0) -> bool:
	_memo_frame()
	var key: String = "%s|%d|%.2f" % [station, level, reach_m]

	if not _near_memo.has(key):
		_near_memo[key] = _station_near_now(station, level, reach_m)

	return bool(_near_memo[key])


func _station_near_now(station: String, level: int, reach_m: float) -> bool:
	var here: Vector3 = _player_position.call() if _player_position.is_valid() else Vector3.ZERO

	if station == "campfire":   # a lit campfire (state 1) within reach, or a clay hearth or oven beside you ("also")
		for fire_id in _placed():
			if _lit_state(int(_world[fire_id]["state"])) and not _world[fire_id].get("camp", false) and here.distance_to(_world[fire_id]["pos"]) <= maxf(4.5, reach_m):
				return true

	for id in _placed():
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
# recipe, Tempered beside a temper.station that serves it (the Master smithy, its quenching trough built in).
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
		# As the server: the nearest craft.station and temper.station within reach (ServerItems.serving_station), each serving the recipe.
		var master_id: int = _nearest_serving(str(c.get("craft", {}).get("station", "master_smithy")))
		var temper_station: String = str(c.get("temper", {}).get("station", "master_smithy"))
		var temper_id: int = _nearest_serving(temper_station, level if temper_station == station else 1)   # as the server: at the recipe's level
		var master: bool = master_id >= 0 and _def_serves(_structure_by_state(int(_world[master_id]["state"])), station, level)
		var temper: bool = temper_id >= 0 and _def_serves(_structure_by_state(int(_world[temper_id]["state"])), station, level)
		_near_memo[key] = SmithingRules.variants(made_id, table.entry(made_id), int(gives[1]) if gives.size() > 1 else 1, master, temper)

	return _near_memo[key]


# The world id of the nearest placed structure within its reach that serves `station` (its own or "also") at `level` or above, or -1.
func _nearest_serving(station: String, level: int = 1) -> int:
	var here: Vector3 = _player_position.call() if _player_position.is_valid() else Vector3.ZERO
	var best: int = -1
	var best_d: float = INF

	for id in _placed():
		var def: Dictionary = _structure_by_state(int(_world[id]["state"]))
		var d: float = here.distance_to(_world[id]["pos"])

		if not def.is_empty() and d <= float(def.get("reach_m", 3.0)) + 1.0 and d < best_d and _def_serves(def, station, level):
			best = int(id)
			best_d = d

	return best


func _def_serves(def: Dictionary, station: String, level: int) -> bool:
	return (str(def.get("station", "")) == station and int(def.get("station_level", 1)) >= level) or int(def.get("also", {}).get(station, 0)) >= level


# Whether the station window open lists recipe r (Dave 17 Nov 2026: "when you open an inventory other than yours like the workstation or the
# primative smithy it should only list the crafting recipes for stuff that station makes"). Only your own inventory lists everything; a chest none.
# A station lists the recipes it serves at its level, its add-ons (a vice) counted as station_near and the server count them, and those of the stations it
# stands in for ("also": a smithy is also a level 1 forge); a fire lists campfire recipes; a Sawbuck the recipes it speeds (Wooden block).
func station_makes(r: Dictionary) -> bool:
	if _station_screen == 0 or not _world.has(_station_screen):
		return true

	var station: String = str(r.get("station", ""))
	var state: int = int(_world[_station_screen]["state"])

	if StructureLook.CAMPFIRE_STATES.has(state):
		return station == "campfire"

	var def: Dictionary = _structure_by_state(state)

	if _makes_nothing(def):
		return false   # a chest or smelter makes nothing: no recipes (provisional SR-2)

	if station == "":
		return bool(r.get("sawbuck", false)) and str(def.get("station", "")) == "sawbuck"

	var level: int = int(r.get("station_level", 1))

	if str(def.get("station", "")) == station:
		_memo_frame()   # the add-ons walk the world once per refresh, not once per recipe
		var key: String = "addons|%d" % _station_screen

		if not _near_memo.has(key):
			_near_memo[key] = _addons_near(_station_screen, station, float(def.get("addon_reach_m", 5.0)))

		return int(def.get("station_level", 1)) + int(_near_memo[key]) >= level

	return int(def.get("also", {}).get(station, 0)) >= level


func _addons_near(bench_id: int, station: String, reach: float) -> int:
	var kinds: Dictionary = {}

	for id in _placed():
		var def: Dictionary = _structure_by_state(int(_world[id]["state"]))

		if not def.is_empty() and str(def.get("addon_of", "")) == station and bool(def.get("adds_level", true)) and _world[bench_id]["pos"].distance_to(_world[id]["pos"]) <= reach:
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


# A bed (a structure that sets the spawn: rough, straw, feather or canopy bed) under a body whose feet are at `feet`: its middle within BED_UNDER_M
# across and a little height of them. Another player lying there is drawn asleep, not crawling (player_view.gd lie_rest).
const BED_UNDER_M := 1.2   # bed.json reach_m: the server's "lying on a bed" reach


func bed_near(feet: Vector3) -> bool:
	for id in _world:
		var row: Dictionary = _world[id]

		if not (row.get("pos") is Vector3) or str(_structure_by_state(int(row.get("state", -1))).get("use", "")) != "set_spawn":
			continue

		var pos: Vector3 = row["pos"]

		if Vector2(pos.x - feet.x, pos.z - feet.z).length() <= BED_UNDER_M and absf(pos.y - feet.y) < 1.5:
			return true

	return false


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


# The animal's own model lying dead (animal_view dead_body: the body that fell there, or its look drawn in its last pose; Dave 26 Nov 2026,
# the hand-built body "look terrible"); the hand-built body (carcass_look.gd) only where no model file is there. `at`: where the row lies.
var dead_body: Callable            # (kind, look, num, at) -> Node3D or null (terrain_client: animal_view.dead_body)

func _make_carcass(extra: Dictionary) -> Node3D:
	var species: String = str(extra.get("sp", ""))
	var body: Node3D = dead_body.call(species, int(extra.get("look", -1)), int(extra.get("num", 0)), extra.get("at", Vector3.INF)) if dead_body.is_valid() and species != "" else null
	return body if body != null else CarcassLook.build(species)


# Remains (protocol 34, placeholder look until Art draws it): a low dark body and its pack, greying to bone over the seven days.
# `age` is 0 fresh to 1 gone; the server sends it when the row is first seen or changes state.
func _make_remains(age: float) -> Node3D:
	return BuildingLook.remains(age)


# A piece whose model is drawn wider than its old solid (structures.json "solid_drawn": the rock pile's stones spread past its 1 m box) blocks where it
# is drawn (coordinator 23 Nov 2026, physical world audit round 5): one more box of the drawn size, inside its footprint (widened in data to the drawn
# size), up to the drawn top or its "solid_top_m" (the rock pile's rim, low enough to step onto), at most 2.2 m. Kept before _model_for_state: the look
# name check reads the dispatcher in the 6,000 characters after that line.
func _add_drawn_solid(model: Node3D, def: Dictionary) -> void:
	if not bool(def.get("solid_drawn", false)):
		return

	var box: AABB = _bounds_in(model, model)
	var scale: float = maxf(model.scale.x, 0.01)
	var half: Vector2 = Vector2(float(def.get("footprint_x", box.size.x * scale)), float(def.get("footprint_z", box.size.z * scale))) * 0.5 / scale
	var top: float = minf(box.end.y, float(def.get("solid_top_m", 2.2)) / scale)
	var lo: Vector3 = Vector3(maxf(box.position.x, -half.x), maxf(box.position.y, 0.0), maxf(box.position.z, -half.y))
	var hi: Vector3 = Vector3(minf(box.end.x, half.x), minf(top, 2.2 / scale), minf(box.end.z, half.y))

	if hi.x <= lo.x or hi.y <= lo.y or hi.z <= lo.z:
		return

	var body: StaticBody3D = StaticBody3D.new()
	body.set_meta("placed_structure", true)   # not rock: the cave module's enclosure rays skip it (BUG-027)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var solid: BoxShape3D = BoxShape3D.new()
	solid.size = hi - lo
	shape.shape = solid
	shape.position = (lo + hi) * 0.5
	body.add_child(shape)
	model.add_child(body)


# Only the nearest MAX_FIRE_LIGHTS lit fires keep their light on (the same cap at every quality).
# The model of a world state (structures.json "look", read through StructureLook): the same builders draw a placed thing and the placement ghost.
# `extra` is the row's extras (remains age, carcass species).
func _model_for_state(state: int, extra: Dictionary = {}) -> Node3D:
	var look: String = StructureLook.look_of(state)

	var sized: float = float(_structure_by_state(state).get("look_scale", 1.0))

	var model: Node3D = PieceLook.pipe_run(str(LookTable.LOOKS[look]["args"][0]), float(extra["len"])) if extra.has("len") and LookTable.LOOKS.has(look) else _model_for_look(look, state, extra)   # a pipe run at its own length (PLUMBING_DESIGN s9)

	if model == null:
		return null

	if sized != 1.0:   # a look shared by pieces of different sizes (chests by slot count, Dave 18 Nov 2026), drawn and its ghost at their own size
		model.scale = Vector3.ONE * sized   # uniform, so any collision box in it scales true

	_add_missing_solid(model, _structure_by_state(state))
	_add_drawn_solid(model, _structure_by_state(state))

	# A blueprint never burns (Dave 17 Nov 2026: the Primitive smithy's blueprint "has a fire ... burning before you make it"): the one place every
	# forge, smithy and smelter look's flames and smoke are put out for a placement ghost or a site waiting for materials. Lights stay off unlit.
	if extra.has("ghost") or extra.has("site"):
		BuildingLook.show_forge_fire(model, false)

	return model


# Looks drawn with no solid of their own that a player must walk round, not through (physical world audit round 5, 23 Nov 2026: a Workbench and a
# Grindstone are "blocks_walk" on the server but had no solid on the client; chests, the chopping block, tool racks, the vice and the bellows were
# walked through too). Pieces that hang on a fire, table or wall (attach_to) stay as they are.
const SOLID_LOOKS := ["chest", "workbench", "chopping_block", "tool_rack", "vice"]


# Gives a model with no solid one box of its drawn size (inside its footprint, at most 2.2 m tall) when its piece blocks the way (SOLID_LOOKS or
# structures.json blocks_walk). A model that has a solid keeps it. The piece's own "look" is asked, not the look it is drawn with: a pipe or tap
# with no look of its own is drawn as the chopping block for now, and it must stay walk-over.
func _add_missing_solid(model: Node3D, def: Dictionary) -> void:
	if def.is_empty() or str(def.get("attach_to", "")) != "" or not (str(def.get("look", "")) in SOLID_LOOKS or bool(def.get("blocks_walk", false))) or _has_solid(model):
		return

	var box: AABB = _bounds_in(model, model)

	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return

	var scale: float = maxf(model.scale.x, 0.01)   # the box is in the model's own (unscaled) space: footprint and height limit scaled into it
	var half: Vector2 = Vector2(float(def.get("footprint_x", box.size.x * scale)), float(def.get("footprint_z", box.size.z * scale))) * 0.5 / scale
	var lo: Vector3 = Vector3(maxf(box.position.x, -half.x), maxf(box.position.y, 0.0), maxf(box.position.z, -half.y))
	var hi: Vector3 = Vector3(minf(box.end.x, half.x), minf(box.end.y, 2.2 / scale), minf(box.end.z, half.y))

	if hi.x <= lo.x or hi.y <= lo.y or hi.z <= lo.z:
		return

	var body: StaticBody3D = StaticBody3D.new()
	body.set_meta("placed_structure", true)   # not rock: the cave module's enclosure rays skip it (BUG-027)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var solid: BoxShape3D = BoxShape3D.new()
	solid.size = hi - lo
	shape.shape = solid
	shape.position = (lo + hi) * 0.5
	body.add_child(shape)
	model.add_child(body)


static func _has_solid(node: Node) -> bool:
	if node is CollisionObject3D:
		return true

	for child in node.get_children():
		if _has_solid(child):
			return true

	return false


func _model_for_look(look: String, state: int, extra: Dictionary) -> Node3D:
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
			# the Primitive smithy has Dave's own model (21 Nov 2026); the Primitive and Improved smelters keep the basic forge
			return _forge_fire(_make_primitive_smithy(state) if str(_structure_by_state(state).get("item", "")) == "stone_forge" else _make_forge(state), state, extra)
		"blacksmithy":
			# the Improved smithy has Dave's own model (21 Nov 2026); the Advanced smithy keeps the brick forge
			return _forge_fire(_make_improved_smithy() if str(_structure_by_state(state).get("item", "")) == "blacksmithy" else _make_smithy(), state, extra)
		"big_forge":
			return _forge_fire(_make_big_forge(state), state, extra)
		"primitive_kiln":
			return _make_primitive_kiln(bool(extra.get("lit", false)))
		"carcass":
			return _make_carcass(extra)

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


# A Smelter's forge model burns only while its row says lit, never cold (Dave 17 Nov 2026). A smithy shows its row's "forge": cold with no fuel,
# red coals when idle, the flare while a craft is worked (Dave 21 Nov 2026). No blueprint burns (_model_for_state).
func _forge_fire(model: Node3D, state: int, extra: Dictionary) -> Node3D:
	var def: Dictionary = _structure_by_state(state)

	if str(def.get("use", "")) == "smelt":
		BuildingLook.show_forge_fire(model, bool(extra.get("lit", false)))
	elif str(def.get("fuel_slot", "")) != "":
		BuildingLook.forge_state(model, int(extra.get("forge", 0)))

	return model


# The ghost's model: a lit campfire is shown cold, a forge with no fire.
func ghost_model(state: int) -> Node3D:
	return _model_for_state(state, {"ghost": true})


func _make_fire(lit: bool, loaded: bool = false, tier: int = 2) -> Node3D:
	return BuildingLook.fire(lit, loaded, tier)


# Lit fire states (cooking.json fire_tiers): 1 campfire, 40 survival fire, 41 bonfire.
# World-item state 4 (a stump) is drawn by _make_felled; every other state is a fire, a structure, a boulder or a loose item. A felled tree has no
# trunk state: it comes down as its logs (16 Nov 2026).
static func is_felled_state(state: int) -> bool:
	return state == 4


static func _lit_state(state: int) -> bool:
	return state == 1 or state == 40 or state == 41


static func _fire_tier(state: int) -> int:
	return 1 if state == 40 else (3 if state == 41 else 2)


# The first world item of each kind and state this session is named on the next slow frame's line (FrameProbe.first_shown, BugsList 108).
func _note_first_shown(number: int, state: int) -> void:
	var key: String = "i%d_%d" % [number, state]

	if FrameProbe.is_new(key):
		FrameProbe.first_shown("item %s state %d" % [table.id_of(number) if number > 0 else "stump", state], key)


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
		node.scale = Vector3.ONE * (1.0 if str(BasicLook.entry(id).get("shape", "")) == "board" else BASIC_DROP_SCALE)      # big enough to find in the tall grass (the natural stones and sticks are 3 times); a sawn board is drawn at its real 8 ft
		node.position.y += 0.04
		return

	if id == "stick" or id == "plant_fibre" or id == "firewood" or id == "driftwood":
		node.scale = Vector3(rng.randf_range(0.7, 1.3), 1.0, 1.0)   # a log keeps its 3 m: it is that long in the server's physics
		node.position.y -= 0.08
	elif id == "stone":
		node.scale = Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.7, 1.1), rng.randf_range(0.8, 1.3))
		node.position.y -= 0.07


# Builds the shared meshes of the loose items that appear on every join (stones, sticks, driftwood, logs, firewood, fibre) while the client is still loading, so the first
# list of world items (282 items took 1070 ms, 961 ms of it here, PC log 2 Nov) only dresses nodes with meshes that already exist (bug 6/join freeze).
# Lag runs 5 Nov: building the loose item meshes all at once cost about 540 ms of the welcome frame (stones sticks and logs 346, trunk drops 191),
# the one freeze left at the join. In a window they are built a few each frame instead (WARM_BUDGET_USEC), in the order below, while the ground
# is still loading (2 s or more after the welcome). A mesh wanted before its turn is built on the spot by _mesh_for, as before any prewarm.
const WARM_BUDGET_USEC := 6000
const SLOW_WARM_MS := 50.0         # a single loose mesh slower than this is named in the log
var _warm_queue: Array = []        # item numbers still to build
var _warm_usec: int = 0            # time spent building them so far
var _warm_frames: int = 0


func _loose_prewarm_numbers() -> Array:
	var out: Array = []

	for id in table.ids():
		var item: String = str(id)

		if item == "stone" or item == "flint" or item == "stick" or item == "firewood" or item == "plant_fibre" or item == "driftwood" or item == "log" or item.begins_with("log_"):
			out.append(table.number_of(item))

	for drop in _trunk_drop_ids() + _rock_drop_ids():
		if table.number_of(drop) > 0 and not out.has(table.number_of(drop)):
			out.append(table.number_of(drop))

	return out


# What lies loose by the rivers or comes off a broken rock (boulders.json ore items, finds and rocks: copper, tin and iron ore, iron chunks,
# coal, salt, limestone, the pocket finds). Lane A r4 Low route (26 Nov 2026): the first copper ore, iron ore and iron chunk seen in play
# each took 57 to 64 ms to build, inside a world items message.
func _rock_drop_ids() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/boulders.json"))
	var ore: Variant = (parsed as Dictionary).get("ore", {}) if parsed is Dictionary else {}
	var out: Array = []

	if not ore is Dictionary:
		return out

	for part in ["items", "finds", "rocks"]:
		var names: Variant = (ore as Dictionary).get(part, {})

		if names is Dictionary:
			for item in (names as Dictionary).values():
				if not out.has(str(item)):
					out.append(str(item))

	return out


func _start_loose_prewarm() -> void:
	var tq_rocks: int = FrameProbe.start()
	_queue_rock_hulls()
	FrameProbe.stop("loose prewarm start: rock shapes", tq_rocks)
	var t0: int = Time.get_ticks_usec()

	var tq_pick: int = FrameProbe.start()

	for group in PICKUP_FILES:
		_pickup_group(group)

	FrameProbe.stop("loose prewarm start: pickup models", tq_pick)
	var tq_nums: int = FrameProbe.start()
	_warm_queue = _loose_prewarm_numbers()
	FrameProbe.stop("loose prewarm start: item list", tq_nums)
	var tq_models: int = FrameProbe.start()
	BasicLook.warm_models()   # the handsaw models' files, on a loader thread
	FrameProbe.stop("loose prewarm start: model loads asked", tq_models)
	_warm_usec = Time.get_ticks_usec() - t0
	_warm_frames = 0
	var tq_piece: int = FrameProbe.start()
	PieceLook.prewarm()
	FrameProbe.stop("loose prewarm start: piece pictures", tq_piece)
	var tq_felled: int = FrameProbe.start()
	_prewarm_felled()
	FrameProbe.stop("loose prewarm start: stump", tq_felled)
	var tq_fires: int = FrameProbe.start()
	_prewarm_fires()
	FrameProbe.stop("loose prewarm start: fires", tq_fires)


func _warm_step() -> void:
	var t0: int = Time.get_ticks_usec()

	while not _warm_queue.is_empty() and Time.get_ticks_usec() - t0 < WARM_BUDGET_USEC:
		var number: int = int(_warm_queue.pop_front())
		var t_one: int = Time.get_ticks_usec()
		_mesh_for(number)
		var one_ms: float = float(Time.get_ticks_usec() - t_one) / 1000.0

		if one_ms > SLOW_WARM_MS:   # Lane A 25 Nov 2026: one warm-up step held the main thread 896 ms; this names the item
			FreezeWatchScript.printer.line("client prewarm: loose mesh %s took %.0f ms" % [table.id_of(number), one_ms])

	_warm_usec += Time.get_ticks_usec() - t0
	_warm_frames += 1

	if _warm_queue.is_empty():
		FreezeWatchScript.printer.line("client prewarm: loose item meshes %.0f ms over %d frames" % [float(_warm_usec) / 1000.0, _warm_frames])


func _prewarm_loose_meshes() -> void:
	_queue_rock_hulls()
	var t0: int = Time.get_ticks_usec()

	for group in PICKUP_FILES:
		_pickup_group(group)

	BasicLook.warm_models()   # the handsaw models' files, read before anyone takes one in hand
	var t_pick: int = Time.get_ticks_usec()

	for id in table.ids():
		var item_key: String = str(id)

		if item_key == "stone" or item_key == "flint" or item_key == "stick" or item_key == "firewood" or item_key == "plant_fibre" or item_key == "driftwood" or item_key == "log" or item_key.begins_with("log_"):
			_mesh_for(table.number_of(item_key))

	var t_items: int = Time.get_ticks_usec()

	# What a felled trunk breaks into besides its logs (drops.json "trunk": branch sticks and leaves, small-blow kindling, bark, thatch, seeds, roots,
	# each species' own). Built on the first split otherwise, a pause of about a second as the trunk came apart (Dave 2 Nov: "it paused for about 1 second").
	for item_key in _trunk_drop_ids() + _rock_drop_ids():
		if table.number_of(item_key) > 0:
			_mesh_for(table.number_of(item_key))

	var t_end: int = Time.get_ticks_usec()
	FreezeWatchScript.printer.line("client prewarm: loose item meshes %.0f ms (pickup models %.0f, stones sticks and logs %.0f, trunk drops %.0f)" % [float(t_end - t0) / 1000.0, float(t_pick - t0) / 1000.0, float(t_items - t_pick) / 1000.0, float(t_end - t_items) / 1000.0])
	PieceLook.prewarm()   # the building material and trodden-path pictures, on a worker (about 170 ms on the main thread at the first piece or hoe stroke)
	_prewarm_felled()
	_prewarm_fires()


# Bug 6 (Dave, 2 Nov 2026 16:51: "a big pause when you first cut it ... sometimes it doesn't even appear for five seconds and then poof a tree
# appears and falls over"): the first felled trunk of a session built the bark shader and the cut-face materials, and the GPU compiled them right
# then. One stump is made here, out of sight under the world, so that compile happens during loading; they go after 5 s.
var _felled_warm: Array = []


func _prewarm_felled() -> void:
	if _root == null:
		return

	var t0: int = Time.get_ticks_usec()
	var extra: Dictionary = {"species": "oak", "radius": 0.3, "length": 8.0, "yaw": 0.0}
	var node: Node3D = _make_felled(extra)
	node.position = Vector3(0.0, -10000.0, 0.0)
	_root.add_child(node)
	_felled_warm.append(node)

	if is_inside_tree():
		get_tree().create_timer(5.0).timeout.connect(_drop_felled_warm)

	FreezeWatchScript.printer.line("client prewarm: stump %.0f ms" % (float(Time.get_ticks_usec() - t0) / 1000.0))


# Lag lane 23 Nov 2026: the first lit fire of a session (the starter town's bonfire, campfire_kit state 41, in every join's first world items)
# took 975-1800 ms of the main thread on Dave's PC ("client slow: world items ... loose_mesh", 5 of 5 cold-play and first-load logs), 22 ms
# headless: its flame, smoke and spark materials (cached for the session) are first made for the GPU then. One lit and one unlit fire of each
# size are made here, out of sight with the stump (dropped with it after 5 s), so that cost falls in the welcome's loading, not in play.
func _prewarm_fires() -> void:
	if _root == null:
		return

	var t0: int = Time.get_ticks_usec()

	for tier in [1, 2, 3]:
		for lit in [true, false]:
			var fire: Node3D = _make_fire(lit, false, tier)
			fire.position = Vector3(0.0, -10000.0, 0.0)
			_root.add_child(fire)
			_felled_warm.append(fire)

	FreezeWatchScript.printer.line("client prewarm: fires %.0f ms" % (float(Time.get_ticks_usec() - t0) / 1000.0))


func _drop_felled_warm() -> void:
	for node in _felled_warm:
		if is_instance_valid(node):
			node.queue_free()

	_felled_warm.clear()


# The item ids a felled trunk can drop besides its logs (data/items/drops.json "trunk").
func _trunk_drop_ids() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
	var trunk: Dictionary = (parsed as Dictionary).get("trunk", {}) if typeof(parsed) == TYPE_DICTIONARY else {}
	var ids: Array = ["bark", "thatch", "seed_bundle", "kindling", "leaves", "firewood"]   # a small tree breaks into Firewood (trunk.small_tree)

	for key in ["branch", "small"]:
		for row in trunk.get(key, []):
			ids.append(str(row[0]))

	var roots: Array = trunk.get("roots", [])

	if not roots.is_empty():
		ids.append(str(roots[0]))

	for species in trunk.get("by_species", {}):
		for row in trunk["by_species"][species]:
			ids.append(str(row[0]))

	var seeds: Dictionary = (trunk.get("felled_seeds", {}) as Dictionary).get("by_species", {})

	for species in seeds:   # every felled tree drops its seed (gardening, 14 Nov 2026)
		ids.append(str(seeds[species]))

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


# The natural pickup models (stones, sticks, driftwood...) start loading on loader threads as the client starts (terrain_client.gd _ready), so the
# welcome only takes the finished files: Lane A Low (26 Nov 2026) read them on the main thread in the welcome's one frame, 406 ms
# ("loose prewarm start: pickup models"). Headless loads them on the main thread at the welcome, as before (the dummy renderer's stores
# are not thread safe, dynasty_body.gd warm).
static func warm_pickups() -> void:
	if DisplayServer.get_name() == "headless":
		return

	for group in PICKUP_FILES:
		for file in PICKUP_FILES[group]:
			var path: String = PICKUP_DIR + file + ".glb"

			if ResourceLoader.exists(path) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				ResourceLoader.load_threaded_request(path, "", true)


# A pickup file: the loader thread's, when warm_pickups started it (waiting only if it is still loading), else read here.
static func _pickup_file(path: String) -> Resource:
	var status: int = ResourceLoader.load_threaded_get_status(path)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS or status == ResourceLoader.THREAD_LOAD_LOADED:
		var got: Resource = ResourceLoader.load_threaded_get(path)

		if got != null:
			return got

	return load(path)


func _pickup_group(group: String) -> Array:
	if not _pickup_meshes.has(group):
		var meshes: Array = []

		for file in PICKUP_FILES[group]:
			var packed: Variant = _pickup_file(PICKUP_DIR + file + ".glb") if ResourceLoader.exists(PICKUP_DIR + file + ".glb") else null

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
		_recipe_part.panel_gone()   # the rows and the card go with the panel; a running pass would build for a list that is gone
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
	if cause == "cave-in survived":
		return   # dug out alive: the cave-in sequence plays and the server says what happened (death.json stop_at_1)

	# The cave-in has its own long sequence (cavein_death.gd). Passed out from cold or water: the server's waking stage brings the sight
	# back (strain state 3, R-CORE-PASS-OUT), so no fade of its own here.
	if cause != "cave-in" and cause != "passed out":
		_death_msec = Time.get_ticks_msec()

	if cause != "passed out" and cause != "rescued":   # rescued from a cave's rock (server_items _stuck_rescue), or passed out from cold (server_items.gd _cold_out_tick): the same fade, and the server says where they woke
		show_notice("You died: %s" % cause)


func _on_skills(attributes: PackedInt32Array, rows: Array) -> void:
	strength = attributes[0] if attributes.size() > 0 else 50
	memory = attributes[1] if attributes.size() > 1 else 50
	var rose: bool = not skill_rows.is_empty() and skill_rose(skill_rows, rows)
	skill_rows = rows
	_update_trail_mult()

	if rose and skill_up_event.is_valid():
		skill_up_event.call()

	if _character != null:
		_character.refresh()

	if journal != null:
		journal.refresh_skills()   # the Journal's Skills page, when it is on show


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
			if int(_world[id]["state"]) == CARCASS_STATE:   # named for the animal it was (Dave 25 Nov 2026: "it should say Dead WhateverAnimalItwas")
				label = CarcassLook.dead_name(str(_world[id].get("sp", "")))
			else:
				label = "Your remains" if StructureLook.look_of(int(_world[id]["state"])) == "remains" else _fire_label(_world[id], number)

	return label


# "Campfire 00:04:00 Burn time": the fuel left in the fire (a lit one counts down, a laid one shows what its wood would burn).
func _fire_label(entry: Dictionary, number: int) -> String:
	if entry.get("marks", false):
		return "Boot prints"

	if entry.get("bandits", false):
		return "Bandits' campfire"

	if entry.get("camp", false):   # a camp fire (Edda and Hob's, or a goblin tribe's): named for whose it is
		var whose: String = NpcCamp.owner_near(entry.get("pos", Vector3.ZERO))
		return whose.left(1).to_upper() + whose.substr(1) + " campfire"

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


# The comfort meter (protocol 164, src/client/ui/comfort_badge.gd): one small borderless flame and its level, left of the hotbar; hover for the tooltip.
const ComfortBadgeScript := preload("res://src/client/ui/comfort_badge.gd")
var comfort_level: int = 0       # the whole level shown, 0..10
var comfort_tenths: int = 0      # the meter in tenths, 0..100
var comfort_target: int = 0      # the level it heads for
var comfort_trend: int = 0       # -1 falling, 0 steady, 1 rising
var comfort_tip: String = ""
var comfort_badge: Control       # the status strip beside the hotbar may reparent it into its row


func _on_comfort(tenths: int, target: int, trend: int, tip: String = "") -> void:
	comfort_tenths = clampi(tenths, 0, 100)
	comfort_level = ComfortBadgeScript.level_of(comfort_tenths)
	comfort_target = target
	comfort_trend = trend

	if tip != "":
		comfort_tip = tip

	if comfort_badge == null:
		comfort_badge = ComfortBadgeScript.new()
		_layer.add_child(comfort_badge)

		if status_strip != null and is_instance_valid(status_strip):   # one symbol in the status strip's row (Dave: the symbols in a row)
			status_strip.add_control("comfort", comfort_badge, func() -> Dictionary: return {"tone": 0})
			status_strip.tick(0.0, true)

	comfort_badge.set_meter(comfort_tenths, target, trend, tip)


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
	net.goal_progress_received.connect(goal_book.on_progress)
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

	# You: the worn wells, an ornament rule, then the six stats.
	_you_box = VBoxContainer.new()
	_you_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_you_box.add_theme_constant_override("separation", 6)   # with the gear wells 6 apart, the stats fit the column at text 1.2 (was 12: 43 px over)
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

	if status_strip != null and is_instance_valid(status_strip) and status_strip.get_parent() == _layer:
		_layer.move_child(status_strip, -1)   # the status strip beside it too, so its hover lines can be read with the window up

	if heart_pulse != null and is_instance_valid(heart_pulse) and heart_pulse.get_parent() == _layer:
		_layer.move_child(heart_pulse, -1)     # the pulse line with it, over the backdrop


# Chest mode (redesign 4.4): with a container open the Craft column shows it, named on the plate, or the recipes, by the Chest and
# Craft tabs on the title row. With no container the tabs go and the column is Craft again.
func _show_tab() -> void:
	var both: bool = _store_with_recipes()
	var store_only: bool = _store_only()
	var chest: bool = chest_mode and (chest_tab or both or store_only)

	if _chest_panel != null and is_instance_valid(_chest_panel):
		_chest_panel.visible = chest
		_container_part.set_compact(both)

	if _craft_root != null and is_instance_valid(_craft_root):
		_craft_root.visible = not chest or both

	if not chest:
		_chest_hover = []      # a hidden slot sends no mouse_exited

	for i in _craft_tabs.size():
		var tab: Button = _craft_tabs[i]
		tab.visible = chest_mode and not both and not store_only
		var lit: bool = (i == 0) == chest
		tab.add_theme_stylebox_override("normal", ArtKit.stylebox_raised(1 if lit else 0))
		tab.add_theme_color_override("font_color", ArtKit.HEADING if lit else ArtKit.CREAM)

	for button in _text_buttons:
		(button as Control).visible = not chest_mode

	if _frame != null and is_instance_valid(_frame):
		_frame.set_title(2, _container_part.title() if chest else "CRAFT")


# A crafting station's store window shows its store under its recipe list, no Chest and Craft tabs (Dave 17 Nov 2026: "I just used the
# primative smithy and didnt like the way there is a separate chest inventory. it should be combined so when it makes items they appear so the
# player can see them"; "in a station that has an inventory there should only be on inventory"): a structures.json "one_store" station. The Kiln
# (a batch of logs), the chopping block (E splits, no recipes), chests, fires and smelters keep their tabs.
func _store_with_recipes() -> bool:
	if not chest_mode or not _world.has(chest_id):
		return false

	return bool(_structure_by_state(int(_world[chest_id]["state"])).get("one_store", false))


# A container that makes nothing (chests, shelves, racks, carts, smelters: no station, no "also", not a fire) shows only its store, no Craft tab, list or
# buttons (Dave 18 Nov 2026: "get rid of the craft button/window in the chests"). Its Craft list was already empty (station_makes, SR-2).
func _store_only() -> bool:
	if not chest_mode or not _world.has(chest_id):
		return false

	var state: int = int(_world[chest_id]["state"])

	if StructureLook.CAMPFIRE_STATES.has(state):
		return false

	return _makes_nothing(_structure_by_state(state))


func _makes_nothing(def: Dictionary) -> bool:
	return str(def.get("station", "")) == "" and (def.get("also", {}) as Dictionary).is_empty()


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

		if slot >= 0 and not chest_mode and eat_slot(slot):
			var hover: int = _hover   # the pointer moving to another slot (or off) stops it
			var e_key: Key = int(KeyBindings.binding("use_item")["key"]) as Key
			_start_eat_hold(slot, func() -> bool: return Input.is_key_pressed(e_key) and open and not chest_mode and _hover == hover)

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

	# The number keys take a hotbar key in hand with the screen open, as in the world (added for the 17 Nov in-hand rule; since 24 Nov a craft's
	# tool counts from the pack). The search box keeps its own digits.
	var key: int = event.keycode - KEY_1 if event.keycode >= KEY_1 and event.keycode <= KEY_9 else (9 if event.keycode == KEY_0 else -1)

	if key >= 0 and pick_hand.is_valid():
		pick_hand.call(key)
		_refresh()
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

	net.inventory_action.rpc_id(1, Net.ACT_CRAFT_QUEUE, number, variant, count, Vector3(float(_hand_slot() + 1), 0.0, 0.0))   # at.x: the hand slot + 1 (126; no longer needed: a kept tool counts from the pack)


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

	if FlameRules.is_out(entry, item_inst) and str(entry.get("relit_item", "")) == "":
		out.append("Out: press its key to light it again")   # a torch that went out is the same torch (Dave 16 Nov 2026)

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
		text += "\nHolds %s of %s. Use (%s) drinks from it; at the water, %s fills it." % [_litres(fill_ml), _litres(int(entry["capacity_ml"])), KeyBindings.label("use_item"), KeyBindings.label("interact")]

	if table.wood_class(number) != "" and fill_ml > 0:   # wet wood: the slot's wear is its drying left in tenths of a game hour (cooking.json wet_wood)
		text += "\nWet: dry in about %d game hours, faster by a fire. Wet wood smokes, burns slower and gives less heat." % maxi(int(ceil(float(fill_ml) / 10.0)), 1)

	var kcal: int = VitalsRules.food_value(table.id_of(number), _vitals_cfg)
	var heal: int = VitalsRules.heal_value(table.id_of(number), _vitals_cfg)

	if not _carry_cfg.is_empty():
		var each_kg: float = CarryRules.weight_of(table.id_of(number), _carry_cfg)
		text += "\n%s each" % CarryRules.weight_text(each_kg) + (", %s in all" % CarryRules.weight_text(each_kg * float(count)) if count > 1 else "")

	if str(entry.get("slot", "")) != "":
		var layer: String = str(entry.get("wear_layer", "base"))
		text += "\nWorn on the %s%s. Use (%s) puts it on." % [str(entry["slot"]), "" if layer in ["base", "footwear"] else ", %s layer" % layer, KeyBindings.label("use_item")]

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
		var fed: int = VitalsRules.eaten_kcal(kcal, table.freshness(number, fill_ml))   # what eating it gives now: stale food feeds less (server_items._eat)
		text += "\n%d kcal%s  (right click when held, or Eat / use)" % [fed, " (%d fresh)" % kcal if fed < kcal else ""]

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

	text += "\nKeys: Split (%s), Drop (%s), Use (%s)" % [KeyBindings.label("split_item"), KeyBindings.label("drop_item"), KeyBindings.label("use_item")]

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
	FreezeWatchScript.printer.line("Items test: after give, stone %d" % inventory.count_of(table.number_of("stone")))
	var here: Vector3 = _player_position.call()
	net.inventory_action.rpc_id(1, Net.ACT_DROP, 0, 0, 4, here)
	await get_tree().create_timer(3.0).timeout
	FreezeWatchScript.printer.line("Items test: after drop, stone %d, %d on the ground" % [inventory.count_of(table.number_of("stone")), _world.size()])
	pick_up_nearest()
	await get_tree().create_timer(1.0).timeout
	FreezeWatchScript.printer.line("Items test: after pick up, stone %d, %d on the ground" % [inventory.count_of(table.number_of("stone")), _world.size()])
	net.inventory_action.rpc_id(1, Net.ACT_CRAFT, 1, 0, 0, Vector3.ZERO)
	net.inventory_action.rpc_id(1, Net.ACT_CRAFT, 2, 0, 0, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	toggle()
	_recipe_search.text = "stone"
	_refresh()
	_recipe_part.finish_now()
	var shown: int = 0

	for child in _recipe_list.get_children():
		if not child.is_queued_for_deletion():
			shown += 1

	FreezeWatchScript.printer.line("Items test: panel open, recipes shown for 'stone' %d, selected %d" % [shown, _selected_recipe])
	_recipe_search.text = ""
	_refresh()
	toggle()
	FreezeWatchScript.printer.line("Items test: crafted, twine %d, stone axe %d, fibre %d" % [inventory.count_of(table.number_of("twine")), inventory.count_of(table.number_of("stone_axe")), inventory.count_of(table.number_of("plant_fibre"))])


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
	FreezeWatchScript.printer.line("Arrival test: ground found %s, set down %.1f m above it, health %d, strain state %s" % [str(client.arrival_protect_until_msec > 0), above, health, str(strain_state)])
	_finish_early(client)


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
	FreezeWatchScript.printer.line("Strain test: ran %.0f m in 25 s, strain %.2f -> %.2f, state %d" % [covered, start_strain, strain, strain_state])
	FreezeWatchScript.printer.line("Strain test: peak strain %.2f" % peak_strain)

	# The server's walk from normal to over-exerted to blackout is proven in test_server_items; here the client's side of it:
	# over-exerted is a 10 percent slow-down with no speed cap and running still allowed, fainted locks movement.
	var real_state: int = strain_state
	var factors: Array = []

	for forced in [0, 1, 2]:
		strain_state = forced
		factors.append("%d: pace x%s cap %s" % [forced, str(snappedf(over_pace_factor(), 0.001)), str(move_cap())])

	strain_state = real_state
	FreezeWatchScript.printer.line("Strain test: %s" % " | ".join(factors))


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
		FreezeWatchScript.printer.line("Gather test: no shrub loaded")
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
		FreezeWatchScript.printer.line("Gather test: prompt \"%s\"" % plant_hint)
		client.harvest.tap()
		await get_tree().create_timer(2.0).timeout

		if _pack_items() > items_before:
			break

	FreezeWatchScript.printer.line("Gather test: pack items %d -> %d" % [items_before, _pack_items()])
	FreezeWatchScript.printer.line("Gather test: sticks %d -> %d; loose things in view %d" % [before, inventory.count_of(sticks), _world.size()])
	var after_tap: int = inventory.count_of(sticks)
	client.harvest.update(0.0, true)
	client.harvest.update(0.5, true)
	client.harvest.update(0.3, true)
	await get_tree().create_timer(1.5).timeout
	FreezeWatchScript.printer.line("Gather test: sweep, sticks %d -> %d (a picked-bare shrub is skipped); prompt \"%s\"" % [after_tap, inventory.count_of(sticks), plant_hint])

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
	FreezeWatchScript.printer.line("Hold test: looking east, stone to the east in view %s, stone to the west in view %s, prompt \"%s\"" % [str(east_in), str(west_in), str(_probe_pickup().get("prompt", ""))])
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
	FreezeWatchScript.printer.line("Hold test: stones gained per held-E step %s" % str(deltas))
	var most: int = 0
	var total: int = 0

	for gained in deltas:
		most = maxi(most, gained)
		total += gained

	FreezeWatchScript.printer.line("Hold test: most in one step %d, total %d, last two steps %d" % [most, total, deltas[deltas.size() - 1] + deltas[deltas.size() - 2]])
	view_direction = real_view

	for look in ["stick", "stone", "log", "plant_fibre", "roast_forage"]:
		var shape: Mesh = _mesh_for(table.number_of(look))
		FreezeWatchScript.printer.line("Item look: %s is a %s, %.2f x %.2f x %.2f m" % [look, shape.get_class(), shape.get_aabb().size.x, shape.get_aabb().size.y, shape.get_aabb().size.z])

	for look in ["stick", "stone", "driftwood"]:
		var seen: Dictionary = {}

		for world_id in range(1, 40):
			var real: Mesh = _natural_mesh(table.number_of(look), world_id)

			if real != null:
				seen[real.get_rid().get_id()] = real

		var sizes: Array = []

		for real in seen.values():
			sizes.append("%.2f m" % real.get_aabb().size.x)

		FreezeWatchScript.printer.line("Natural look: %s uses %d real meshes (%s)" % [look, seen.size(), ", ".join(sizes)])

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

		FreezeWatchScript.printer.line("Natural size: %s lies %.2f to %.2f m long, centre %.2f to %.2f m above its spot" % [look, smallest, largest, lowest, highest])


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

	FreezeWatchScript.printer.line("Quick key test: pack ready after the give, stone %d, roast %d" % [inventory.count_of(stone), inventory.count_of(roast)])
	toggle()
	FreezeWatchScript.printer.line("Quick key test: window open %s, %d slots" % [str(open), _buttons.size()])
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
	FreezeWatchScript.printer.line("Quick key test: S handled %s, stacks of stone %d -> %d" % [str(handled), stacks_before, _stone_stacks(stone)])
	FreezeWatchScript.printer.line("Quick key test: S added stacks %d" % (_stone_stacks(stone) - stacks_before))
	_hover = inventory.numbers.find(stone)
	var stones_now: int = inventory.count_of(stone)
	press.call(KEY_D, true)
	await get_tree().create_timer(1.0).timeout
	FreezeWatchScript.printer.line("Quick key test: Shift+D dropped one, stones %d -> %d" % [before, inventory.count_of(stone)])
	FreezeWatchScript.printer.line("Quick key test: Shift+D dropped %d" % (stones_now - inventory.count_of(stone)))
	_hover = inventory.numbers.find(roast)
	var roasts: int = inventory.count_of(roast)
	press.call(KEY_E)
	await get_tree().create_timer(1.0).timeout
	FreezeWatchScript.printer.line("Quick key test: E ate, roasts %d -> %d" % [roasts, inventory.count_of(roast)])
	FreezeWatchScript.printer.line("Quick key test: E ate %d" % (roasts - inventory.count_of(roast)))
	FreezeWatchScript.printer.line("Quick key test: T outside a container handled %s, nothing moved" % str(press.call(KEY_T)))


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
		FreezeWatchScript.printer.line("Text step %d: scale %.2f, window %dx%d needs %dx%d; columns: %s" % [step, text_scale, _panel.size.x, _panel.size.y, need.x, need.y, _frame.fit_report()])

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
	FreezeWatchScript.printer.line("Character screen: " + str(_character.report()) + "; inventory closed " + str(not open) + "; screen_open " + str(screen_open()))
	toggle_character()
	FreezeWatchScript.printer.line("Text test: scale %.2f, %d slot buttons, all valid %s, every item shown %s, panel open %s, window sizes seen %d, contents fit %s" % [text_scale, _buttons.size(), str(valid), str(filled_ok), str(open), sizes.size(), str(fits)])
	_finish_early(client)


# Job 82: every control in the inventory window, read at the current text scale: the smallest font in use, the labels a
# player sees (buttons, sort options, hints) and the key letters on the action buttons. Printed as "Audit:" lines.
# The action buttons name the bound keys (Split (S), Drop (D), Use (E), Repair (R) by default).
func _action_button_labels() -> Array:
	return ["Split (%s)" % KeyBindings.label("split_item"), "Drop (%s)" % KeyBindings.label("drop_item"), "Use (%s)" % KeyBindings.label("use_item"), "Repair (%s)" % KeyBindings.label("repair_item")]


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

	for key_label in _action_button_labels():
		if not labels.has(key_label):
			missing.append(key_label)

	FreezeWatchScript.printer.line("Audit: carry bar %s" % str(_carry_bar != null and _carry_bar.is_inside_tree()))
	FreezeWatchScript.printer.line("Audit: smallest font %d px (%s), tooltip font %d px, sort options %d, button labels %s, key buttons missing %s, panel bars %d, main-screen bars %d" % [smallest, smallest_name, tooltip_px, _sort_menu.item_count, str(labels), str(missing), _panel_bars.size(), (1 if status_strip != null and status_strip.find_children("*", "ColorRect", true, false).size() > 0 else 0)])


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

		FreezeWatchScript.printer.line("Plant test: %s %s" % [client.harvest._flora_by_id.get(int(spot[2]) >> 16, {}).get("name", "?"), "bare until next season" if bare else ("STILL THERE" if still else "gone")])
		still = still and not bare
		gone += 0 if still else 1

	FreezeWatchScript.printer.line("Plant test: tried %d, gone %d, still standing %d, skipped (nothing pickable) %d" % [tried, gone, tried - gone, skipped])


# The self-tests build with the hammer (or the knife for the Wicker basket, a knife row; the Wicker - Chest it replaced was retired 21 Nov 2026), as players do since kits left the game (4 Nov 2026): data/items/blueprints.json numbers and costs.
# The hammer or knife goes on a hotbar key by itself when it comes into the pack (inventory step 4).
const CHEST_BLUEPRINT := 157   # the Wicker basket, 6 slots: the knife's store since the Wicker - Chest was retired (Dave 21 Nov 2026)
const CHEST_STATE := 195   # its row state (structures.json wicker_basket)
const CHEST_MATERIALS := [["stone_knife", 1], ["stick", 8], ["twine", 4]]
const LEAN_TO_BLUEPRINT := 25
const LEAN_TO_MATERIALS := [["stone_hammer", 1], ["stick", 30], ["leaves", 100], ["leaves", 100], ["twine", 10]]


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
	FreezeWatchScript.printer.line("Lean-to test: %d lean-to rows in view, cover under it %s, in the open %s" % [seen, str(CoverScript.at(under, cover_index)), str(CoverScript.at(under + Vector3(8.0, 0.0, 0.0), cover_index))])


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
	FreezeWatchScript.printer.line("SHOOT TEST: bow in slot %d, arrows %d" % [bow_slot, arrows_before])

	if bow_slot < 0 or arrows_before < 1:
		FreezeWatchScript.printer.line("SHOOT TEST FAILED: the pack did not get the bow or the arrows")
		return

	var camera: Camera3D = client.camera
	var level: Vector3 = -camera.global_transform.basis.z
	var forward: Vector3 = (Vector3(level.x, 0.0, level.z).normalized() + Vector3(0.0, -0.12, 0.0)).normalized()   # a little downward: lands about 30 m off, inside the rows the server sends
	var started: int = Time.get_ticks_msec()
	await get_tree().create_timer(1.2).timeout      # a full draw
	net.inventory_action.rpc_id(1, Net.ACT_SHOOT, bow_slot, Time.get_ticks_msec() - started, 0, forward)
	await get_tree().create_timer(1.5).timeout
	var arrows_after: int = inventory.count_of(table.number_of("stone_arrow"))
	FreezeWatchScript.printer.line("SHOOT TEST: arrows %d -> %d after the shot" % [arrows_before, arrows_after])
	await get_tree().create_timer(15.0).timeout     # flight, landing and the world-item update
	var landed: int = 0
	var nearest: float = -1.0
	var here: Vector3 = _player_position.call()

	for id in _world:
		if _world[id]["number"] == table.number_of("stone_arrow"):
			var d: float = (_world[id]["pos"] as Vector3).distance_to(here)
			landed += 1 if d < 90.0 else 0
			nearest = d if nearest < 0.0 or d < nearest else nearest

	FreezeWatchScript.printer.line("SHOOT TEST: %d arrow(s) lying within 90 m after the flight, nearest %.1f m, %d world rows in all (an arrow can break, so 0 is possible; a stone arrow breaks about a fifth of the time)" % [landed, nearest, _world.size()])
	FreezeWatchScript.printer.line("SHOOT TEST %s" % ("PASS" if arrows_after == arrows_before - 1 else "FAILED: the shot did not take an arrow"))


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
		FreezeWatchScript.printer.line("FOUNDATION TEST FAILED: no thatch floor kit in the pack")
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
	FreezeWatchScript.printer.line("FOUNDATION TEST: spot %s, kit left %d, world rows %d -> %d, near the spot: %s" % [str(spot), kit_left, rows_before, _world.size(), str(near)])
	FreezeWatchScript.printer.line("FOUNDATION TEST %s" % ("PASS" if kit_left == 0 and not near.is_empty() else "FAILED: the floor was not placed"))


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
			FreezeWatchScript.printer.line("COOK TEST FAILED: the pack did not get %s" % str(pair[0]))
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

	FreezeWatchScript.printer.line("COOK TEST: fire row %d, state %s" % [fire, str(_world[fire]["state"]) if fire >= 0 else "none"])

	if fire < 0:
		FreezeWatchScript.printer.line("COOK TEST FAILED: the fire was not laid")
		return

	for n in 3:   # a damp tinder can fail: up to three tries
		if _lit_state(int(_world[fire]["state"])):
			break

		net.inventory_action.rpc_id(1, Net.ACT_LIGHT, fire, 0, 0, Vector3.ZERO)
		await get_tree().create_timer(2.0).timeout

	if not _lit_state(int(_world[fire]["state"])):
		FreezeWatchScript.printer.line("COOK TEST FAILED: the fire did not light (state %s)" % str(_world[fire]["state"]))
		return

	net.inventory_action.rpc_id(1, Net.ACT_COOK, fire, 0, 0, Vector3.ZERO)
	await get_tree().create_timer(2.5).timeout
	var roast: int = table.number_of("roast_meat")
	FreezeWatchScript.printer.line("COOK TEST: raw meat %d -> %d, roast meat %d" % [2, inventory.count_of(meat), inventory.count_of(roast)])

	if inventory.count_of(roast) < 1:
		FreezeWatchScript.printer.line("COOK TEST FAILED: nothing was roasted")
		return

	var fed_before: int = hunger
	eat_slot(inventory.numbers.find(roast))
	await get_tree().create_timer(2.0).timeout
	FreezeWatchScript.printer.line("COOK TEST: hunger %d -> %d, roast meat left %d" % [fed_before, hunger, inventory.count_of(roast)])
	FreezeWatchScript.printer.line("COOK TEST %s" % ("PASS" if inventory.count_of(roast) == 0 and hunger >= fed_before else "FAILED: the roast was not eaten"))


# Headless check (--sleep): a rough bed is set down beside the player, they lie on it, fall asleep for a few seconds and wake. Prints SLEEP TEST lines.
func run_sleep_test(client) -> void:
	await get_tree().create_timer(6.0).timeout

	if not await _wait_inventory_ready():
		FreezeWatchScript.printer.line("SLEEP TEST FAILED: the pack never arrived")
		return


	if not await _smoke_give("rough_bed_kit", 1):
		FreezeWatchScript.printer.line("SLEEP TEST FAILED: the pack did not get the rough bed")
		return

	var forward: Vector3 = -client.camera.global_transform.basis.z
	var here: Vector3 = _player_position.call()
	var ahead: Vector3 = here + Vector3(forward.x, 0.0, forward.z).normalized() * 0.9
	var spot: Vector3 = Vector3(ahead.x, float(_ground_below.call(ahead)), ahead.z)
	net.inventory_action.rpc_id(1, Net.ACT_PLACE, inventory.numbers.find(table.number_of("rough_bed_kit")), 0, 0, spot)
	await get_tree().create_timer(2.5).timeout
	var bed: int = _smoke_row_near(spot, "rough_bed", 2.0)
	FreezeWatchScript.printer.line("SLEEP TEST: bed row %d (no roof here is fine: it then behaves as ground)" % bed)

	if bed < 0:
		FreezeWatchScript.printer.line("SLEEP TEST FAILED: the bed was not set down")
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
	FreezeWatchScript.printer.line("SLEEP TEST: lying %d, asleep %s, energy %d -> %d, after waking asleep %s" % [stance_in_sleep, str(slept), energy_before, energy, str(asleep)])
	FreezeWatchScript.printer.line("SLEEP TEST %s" % ("PASS" if slept and not asleep and energy >= energy_before else "FAILED: sleep did not start, did not end, or energy fell"))


# Headless check (--snare): a snare is set down and left; passes when a carcass lies by it (server checks every 30 s; run the server with traps.json test_chance above 0,
# otherwise this only waits for a rabbit to walk by). Prints SNARE TEST lines.
func run_snare_test(client) -> void:
	await get_tree().create_timer(6.0).timeout

	if not await _wait_inventory_ready():
		FreezeWatchScript.printer.line("SNARE TEST FAILED: the pack never arrived")
		return


	if not await _smoke_give("snare", 1):
		FreezeWatchScript.printer.line("SNARE TEST FAILED: the pack did not get a snare (are Sal's snare items in this build?)")
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

	FreezeWatchScript.printer.line("SNARE TEST: snare row %d" % snare)

	if snare < 0:
		FreezeWatchScript.printer.line("SNARE TEST FAILED: the snare was not set down")
		return

	for n in 40:   # up to 200 s: the server looks every 30 s
		await get_tree().create_timer(5.0).timeout

		if _smoke_row_near(spot, "carcass", 3.0) >= 0:
			FreezeWatchScript.printer.line("SNARE TEST: a carcass lies by the snare after %d s" % ((n + 1) * 5))
			FreezeWatchScript.printer.line("SNARE TEST PASS")
			return

	FreezeWatchScript.printer.line("SNARE TEST FAILED: no catch in 200 s (the server needs traps.json test_chance above 0 for a sure run)")


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

	FreezeWatchScript.printer.line("Eat test: start hunger %d health %d weight %.1f; edible slot 0 %s" % [hunger, health, weight_kg, str(edible_slot(inventory.numbers.find(table.number_of("roast_forage"))))])
	var roasts_before: int = inventory.count_of(table.number_of("roast_forage"))
	eat_slot(inventory.numbers.find(table.number_of("roast_forage")))
	await get_tree().create_timer(1.0).timeout
	FreezeWatchScript.printer.line("Eat test: after a roast, hunger %d, roasts left %d" % [hunger, inventory.count_of(table.number_of("roast_forage"))])
	FreezeWatchScript.printer.line("Eat test: roasts eaten %d" % (roasts_before - inventory.count_of(table.number_of("roast_forage"))))   # a delta: the pack may hold more than was given
	eat_slot(inventory.numbers.find(table.number_of("poultice")))
	await get_tree().create_timer(1.0).timeout
	FreezeWatchScript.printer.line("Eat test: poultice left %d, health %d" % [inventory.count_of(table.number_of("poultice")), health])

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

		FreezeWatchScript.printer.line("Sort test: mode %d first four: %s" % [mode, ", ".join(names)])

	# Crafting queue: three twine line up, the screen shows the entry, pressing it cancels and refunds.
	var fibre: int = table.number_of("plant_fibre")
	net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, fibre, 0, 12, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	var fibre_before: int = inventory.count_of(fibre)
	_selected_recipe = 1
	_recipe_part.craft_selected()
	await get_tree().create_timer(1.0).timeout
	var shown: int = _queue_box.get_child_count() - 1 if _queue_box.visible else 0
	FreezeWatchScript.printer.line("Queue test: entries %d, fibre %d -> %d, buttons shown %d, head \"%s\"" % [craft_entries.size(), fibre_before, inventory.count_of(fibre), shown, _queue_head_button.text if _queue_head_button != null else ""])
	_queue_head_button.pressed.emit()
	await get_tree().create_timer(1.0).timeout
	FreezeWatchScript.printer.line("Queue test: after cancel entries %d, fibre %d, queue strip hidden %s" % [craft_entries.size(), inventory.count_of(fibre), str(not _queue_box.visible)])

	# Boulders: a server row draws a solid boulder that shrinks as stones come out, and a strike ray finds it.
	var spot: Vector3 = _player_position.call() + Vector3(6.0, 0.0, 0.0)
	_on_world_items([[987654, 0, 4000, spot, BOULDER_STATE, {"radius": 1.0, "yaw": 0.0, "total": 4000}]], PackedInt32Array())
	await get_tree().create_timer(0.5).timeout
	var full_radius: float = float(_boulders[987654]["now"]) if _boulders.has(987654) else -1.0
	_on_world_items([[987654, 0, 500, spot, BOULDER_STATE, {"radius": 1.0, "yaw": 0.0, "total": 4000}]], PackedInt32Array())
	var eighth_radius: float = float(_boulders[987654]["now"]) if _boulders.has(987654) else -1.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(spot + Vector3(0.0, 4.0, 0.0), spot + Vector3(0.0, -4.0, 0.0))
	var ray: Dictionary = _root.get_world_3d().direct_space_state.intersect_ray(query)
	FreezeWatchScript.printer.line("Boulder test: radius %.2f, at an eighth of the stones %.2f, found by a strike %s, solid to a ray %s" % [full_radius, eighth_radius, str(boulder_near(spot) == 987654), str(not ray.is_empty() and ray["collider"] == _boulders[987654]["node"])])
	_on_world_items([], PackedInt32Array([987654]))
	FreezeWatchScript.printer.line("Boulder test: gone when the server drops it %s" % str(not _boulders.has(987654)))

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
	FreezeWatchScript.printer.line("Hotbar test: axe in slot %d, Use holds slot %d (matches %s), strip boxes %d" % [axe_slot, in_hand, str(in_hand == axe_slot), hotbar_strip._cells.size() if hotbar_strip != null else 0])
	var model = client.held._model
	FreezeWatchScript.printer.line("Arms test: axe model in the right hand %s, arms shown %s" % [str(model != null and client.held._mounted and model.get_parent() == client.held._arms.hand_mount_r), str(client.held._arms.visible)])
	eat_slot(axe_slot)
	await get_tree().create_timer(0.5).timeout
	FreezeWatchScript.printer.line("Hotbar test: Use again, hand slot %d (-1 = empty)" % [held_slot_now.call()])
	net.inventory_action.rpc_id(1, Net.ACT_MOVE, axe_slot, 20, 0, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	eat_slot(20)
	await get_tree().create_timer(1.0).timeout
	var moved_to: int = held_slot_now.call()
	var on_key: bool = moved_to >= 0 and inventory.on_hotbar(moved_to)
	equip_requested.call(int(held_key_now.call()))   # empty hands again
	FreezeWatchScript.printer.line("Hotbar test: axe parked in slot 20, Use moves it to the hotbar and holds it, slot %d (%s), on hotbar %s, slot 20 now empty %s" % [moved_to, str(moved_to >= 0 and inventory.numbers[moved_to] == axe), str(on_key), str(inventory.numbers[20] != axe)])

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
		# A torch or shield goes in the left hand (items.json "offhand", 7 Nov 2026). A dark lantern lights again when its key is pressed
		# (held_item.gd _relight_on_press), so in hand it is its "relit_item", the burning lantern.
		var as_held: Array = [id, str(table.entry(id).get("relit_item", id))]
		var in_left: bool = as_held.has(client.held.off_id())
		var held_here: bool = client.held.held_id() == id or in_left
		var drawn: bool = client.held._off_model != null if in_left else client.held._model != null
		held_ok += 1 if held_here else 0
		modelled += 1 if drawn else 0

		if not held_here or not drawn:
			FreezeWatchScript.printer.line("Tools test: NOT held or no model: %s" % id)

		# Put it down: 190 tools in the pack outweigh the carrying limit, and the last heavy ones (the quern) were then never given (31 Oct 2026).
		net.inventory_action.rpc_id(1, Net.ACT_DROP, tool_slot, 0, 1, _player_position.call() + Vector3(0.0, 0.0, 2.0))
		await get_tree().create_timer(0.2).timeout

	FreezeWatchScript.printer.line("Tools test: %d tools and weapons, held %d, with a model %d" % [tool_ids.size(), held_ok, modelled])


# Headless check (--chest): place a chest, open it, put stones in, take them out.
# Self-tests on a shared server start before the pack has arrived: wait for it (up to 30 s) so none reads `inventory.numbers` on Nil (Dino's finding, chest test).
func _wait_inventory_ready() -> bool:
	for wait in 100:
		if inventory != null:
			return true

		await get_tree().create_timer(0.3).timeout

	return inventory != null


func run_chest_test(client) -> void:
	# Wait until the body has landed: a fixed 14 s wait ended the run before the ground's collision was in (W-27). Up to 300 s, as a cold-cache join took
	# 223 s on David4 (15 Nov 2026); how fast the ground comes is the arrival step's check (90 s), this one checks the chest.
	var waited: float = 0.0

	while client.arrival_protect_until_msec == 0 and waited < 300.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5

	if client.arrival_protect_until_msec == 0:
		FreezeWatchScript.printer.line("Chest test: the player never landed on the ground in 300 s")
		_finish_early(client)
		return

	FreezeWatchScript.printer.line("Chest test: landed after %.1f s" % waited)

	if not await _wait_inventory_ready():
		FreezeWatchScript.printer.line("Chest test: the pack never arrived")
		_finish_early(client)
		return

	_give_blueprint_kit(CHEST_MATERIALS)   # kits left the game (4 Nov 2026): the Wicker basket is built with the knife from its blueprint (a knife row, W-9)
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
				if _world[k]["state"] == CHEST_STATE:
					id = k

			if id != 0:
				break

			await get_tree().create_timer(0.1).timeout

		if id != 0:
			break

	if id == 0:
		FreezeWatchScript.printer.line("Chest test: no chest was placed (no ground or the place was refused)")
		_finish_early(client)
		return

	_ask_open(id)

	for wait in 60:   # the cloud is slow: give the chest up to 6 s to open
		if chest_inv != null:
			break

		await get_tree().create_timer(0.1).timeout

	if chest_inv == null:
		FreezeWatchScript.printer.line("Chest test: the chest did not open (no contents arrived)")
		_finish_early(client)
		return

	var stone: int = table.number_of("stone")
	net.inventory_action.rpc_id(1, Net.ACT_CHEST_PUT, inventory.numbers.find(stone), id, 7, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	FreezeWatchScript.printer.line("Chest test: chest row %d, screen open %s, stones in chest %d, in pack %d" % [id, str(chest_mode), chest_inv.count_of(stone) if chest_inv != null else -1, inventory.count_of(stone)])

	if chest_inv == null:
		FreezeWatchScript.printer.line("Chest test: the chest closed before the take")
		_finish_early(client)
		return

	net.inventory_action.rpc_id(1, Net.ACT_CHEST_TAKE, chest_inv.numbers.find(stone), id, 7, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout
	FreezeWatchScript.printer.line("Chest test: after taking out, stones in chest %d, in pack %d" % [chest_inv.count_of(stone) if chest_inv != null else -1, inventory.count_of(stone)])

	# Quick key T moves the hovered pack stack into the open chest.
	var stone_slot: int = inventory.numbers.find(stone)
	_chest_hover = [false, _pack_view.find(stone_slot)]
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_T
	press.pressed = true
	quick_key(press)
	await get_tree().create_timer(1.0).timeout
	FreezeWatchScript.printer.line("Chest test: quick key T, stones in chest %d, in pack %d" % [chest_inv.count_of(stone) if chest_inv != null else -1, inventory.count_of(stone)])
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
		FreezeWatchScript.printer.line("Chop test: no tree loaded")
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

	FreezeWatchScript.printer.line("Chop test: %d blows, felled states in view %s" % [blows, str(kinds)])


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PieceLook.finish_prewarm()     # the pictures worker started by the prewarm never outlives the view
