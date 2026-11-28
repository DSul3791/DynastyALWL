extends Node

# What the player holds (hotbar keys 1 to 9 and 0 choose the item in pack slots 0 to 9, the hotbar slots; the key again puts it away) and how it is used.
# Client only; the server decides what happens (throws are server actions).
#
# Spear (Dave, 2026-10-20): held and jabbed by default with the normal attack key (left click).
# Hold right click to aim a throw; then left click throws. Letting go of right click returns to
# the normal stance. The weapon is drawn as a simple first-person model until real art exists.

const GripScript := preload("res://src/client/character/dynasty_grip.gd")
const FeelKicks := preload("res://src/client/feel_kicks.gd")
const KeyBindings := preload("res://src/client/key_bindings.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")
# The held-item label sits 8 px over the hotbar tray (redesign section 9: the tray top is at y 948 of the 1080 canvas).
const LABEL_ABOVE := 1080.0 - ArtKit.HOTBAR_TRAY.position.y + 8.0
const Net := preload("res://src/stream/terrain_net.gd")
const BuildingLook := preload("res://src/client/building_look.gd")
const FireWeather := preload("res://src/client/fire_weather.gd")
const PlacementRules := preload("res://src/shared/placement_rules.gd")
const CaveSounds := preload("res://src/client/cave_sounds.gd")   # is_not_rock: what the ghost's ground probe looks through
const BasicLook := preload("res://src/client/basic_look.gd")
const FlameRules := preload("res://src/shared/flame_rules.gd")
const SurveyLine := preload("res://src/shared/survey_line.gd")
const StructureLookScript := preload("res://src/shared/structure_look.gd")
const ArmsView := preload("res://src/client/character/arms_view.gd")
const DynastyArmsScript := preload("res://src/client/character/dynasty_arms.gd")

const HOTBAR_FILE := "user://hotbar.txt"      # the chosen hotbar key is remembered between sessions
const REST := Vector3(0.38, -0.32, -0.55)       # model offset from the camera
const AIMED := Vector3(0.28, -0.12, -0.35)
const BOW_CANT_DEG := 10.0          # the raised bow's top tilts this far to the right
const BOW_IDLE_LEAN_DEG := 30.0     # lowered at the side: the upper limb leans this far forward
const BOW_DRAW_MAX_M := 0.7         # the nock point comes back at most this far from the braced string (a 28 inch draw)
const BOW_NOCK_ABOVE_M := 0.03      # the arrow sits on the bow hand, this far above the middle of the grip; the string's nock point is level with it
const BOW_ARROW_SIDE_M := 0.006     # the shaft lies along the stave's left side, this far from the bow's plane, straight ahead (Dave 10 Nov 2026: the arrow lines up with the crosshair)
const BOW_SIGHT_RIGHT_M := 0.06     # first person, the bow in hand: the arms (and so the bow, the string hand and the arrow) sit this far right of the eye, so the upper limb passes about 8.5 degrees right of the crosshair and the target stays in sight (Dave 26 Nov 2026, BugsList 180: "the bow should be slightly to the right of the crosshairs so the player can actually see the target"); the nocked arrow stays parallel to the view, about 5 cm right of the eye line, so on screen it runs in toward the crosshair; a loosed arrow flies from the eye along the crosshair as before
const ARROW_NOCK_M := 0.355         # the arrow mesh's nock end lies this far back from its origin (basic_look.gd "arrow")
# First-person arms (Art's ragdoll rig, assets/character/README.md): rooted at the chest a little below and behind the camera,
# pitched forward so a tool in the hand points ahead instead of hanging down. The tool goes to the hand on the viewer's right
# (the rig's hand_mount_r: the rig's right is +X, see assets/character/README.md), grip at the mount origin, its business end tipped
# up TOOL_TILT_DEG from the fingers. Rendered with software Vulkan and looked at (still frames of idle, jab, swing).
const ARMS_POS := Vector3(0.0, -0.1, -0.08)   # swinging pose: 7 cm further back than before so the shoulders stay out of view (Dave 2 Nov 2026)
const ARMS_PITCH_DEG := 50.0
const TOOL_TILT_DEG := 20.0
const TOOL_TILT_SLIGHT_DEG := 23.0  # first person, hand tools: up from the fingers; the resting arm points 40 degrees below level (REST_PITCH_DEG 50), so the head is about 17 degrees down
# Dave 2026-10-21: at rest the arms hang at the character's side, below the bottom of the screen, and the tool sits in the hand there,
# fixed to the body (the way you face, not the way you look): look down and you see it. Swinging, jabbing, using or aiming brings the
# arms up to the camera pose above and back. REST_* is the body pose: where the chest is under the eye and how far forward the arms hang.
const REST_DOWN_M := 0.3               # first-person arms at rest: root this far below the eye; the hands sit below a level view and show only when the player looks down about 30 to 45 degrees (Dave 2026-10-25)
const REST_BACK_M := 0.22               # back from the eye at rest: Dave saw his own shoulders (2 Nov 2026); the arms should only come into view when swinging, or when looking down while running
const REST_PITCH_DEG := 50.0           # forearms hang forward and low (was 8, straight down; 35 showed no hands at 30 degrees down): hands about 56 degrees below level, so they enter the view when the player looks down 25 to 30 degrees
const ARMS_FOLLOW_K := 9.0
const ARMS_SCALE := 0.85               # first-person arms a little slimmer and shorter (hands11/arms_fix pictures: they filled the lower corners); the tool is scaled back up so it keeps its size
const FIST_COLOR := Color(0.78, 0.62, 0.5)
const SHOULDER_LOG_FWD := 0.45            # metres ahead of the eye: the log's middle sits over the shoulder, not behind it (Dave 2026-10-23)
const SHOULDER_LOG_X := 0.5               # first person: the log's side of the body, metres right of the eye
const GRIP_ALONG_Y := {"axe": 0.25, "torch": 0.25, "knife": 0.05, "other": 0.3, "kit": 0.0}   # model +Y runs handle to head: the grip's distance from the model origin
const SPEAR_GRIP_Z := 0.3
const THIRD_LEAN_DEG := -17.0    # third person: head forward and 45 degrees down, as in first person (Dave 2026-10-25: first person hung down about 45 degrees but third person pointed up; the tool lies along the fingers there, the hand-mount's +Y is forward, so -17 turns the head forward and a little down; Dave: all held items point only slightly down)
const HELD_HOE_ROLL_DEG := 60.0       # first person: the hoe is rolled about its haft so the blade shows instead of hiding edge-on
const THIRD_ROD_PITCH_DEG := 22.0     # third person: a carried fishing rod points forward and up about 30 degrees (it lay horizontal and a little down at the default lean)
const THIRD_SAW_PITCH_DEG := -120.0   # third person: a saw carried by the handle, blade pointing down and back about 30 degrees
const THIRD_TORCH_RAISE_DEG := 35.0   # third person: a torch in the left hand points forward and 35 degrees up, its flame clear of the body (Dave 5 Nov: it lay along the arm by the hip)
const THIRD_CHOKE := 0.6         # the hand takes the handle this share of the way from the middle to the end, so less of the tool stands above the hand
const THIRD_FULL_GRIP := ["saw"]   # held right on the grip point, no choke: a saw's handle is its last third or less, so the choke put the hand on the blade (Dave 17 Nov 2026: "it is stabbed right through his hand")
# Third person, how a one-handed tool hangs from the hand at the side (picture checker, 26 Nov 2026, BugsList 181: axes, hammers, picks, swords,
# knives and sickles all lay level at the hip pointing forward, through the thigh). Mount frame: +Y forward, +Z up, +X to the body's right
# (outward for the right hand). An axe, hammer, pick, adze or mace hangs head-down along the outside of the leg, THIRD_HANG_FWD_DEG forward of
# straight down and THIRD_OUT_DEG out from the thigh, as a carried axe is held by the haft. A long one tips further forward so its head comes
# no more than THIRD_HANG_DROP_M below the hand (clear of the ground and the knee), at most to the old forward lean (a great axe, a maul).
# A blade (knife, chisel, sword, sickle) keeps the forward and slightly down lean (Dave 25 Oct 2026: "all held items point only slightly
# down") turned THIRD_OUT_DEG outward, clear of the thigh.
const THIRD_HANG_FWD_DEG := 15.0
const THIRD_OUT_DEG := 10.0
const THIRD_HANG_DROP_M := 0.5
const THIRD_HANG_CARRIES := ["axe", "hammer", "pick", "adze", "mace", "shovel"]
# A hoe (1.25 m) is carried upright like a staff along the open hand (copper hoe "misses the hand", parked 27 Nov, fixed 28 Nov): its haft lay 50 degrees below
# horizontal, 31 degrees off the hand's line and 34 out of the palm's plane (shot_held --measure, laptop 28 Nov), so it crossed the hand at one point and showed
# beside it; the hammer, 8 degrees off, reads as held. It now hangs on the hammer's line, the hand down the haft on its leather wrap so the blade's far end is
# THIRD_STAFF_REACH_M from the hand (clear of the ground), the blade turned forward, away from the shins.
const THIRD_STAFF_CARRIES := ["hoe"]
const THIRD_STAFF_REACH_M := 0.7
const THIRD_EDGE_CARRIES := ["knife", "chisel", "sword", "sickle"]
const THIRD_SHAPE_CARRY := {"axe": "axe", "hammer": "hammer", "pick": "pick", "mace": "mace", "club": "mace", "bone": "mace", "sword": "sword", "knife": "knife", "sickle": "sickle"}
# A tool with a stage-one look (data/items/looks.json) is held as the same mesh that lies on the ground (Dave 2026-10-24: the held tools
# looked like old placeholders). BasicLook tool meshes run handle to head along +X; HELD_LOOK_TURN turns that to the held convention
# (+Y handle to head, +Z up in hand) with the blade's cutting side down (axe, pick, hoe, knife) or the flat of a shovel facing up.
const HELD_LOOK_SCALE := 1.0      # real size against the body (Dave QA BUG-012: tools held at 1.4x, spear 1.6x, bow 1.8x looked too big)
const HELD_SPEAR_SCALE := 1.0
const BOW_AMMO := ["stone_arrow", "bone_arrow", "wooden_arrow", "fibre_arrow", "fire_arrow", "bronze_arrow", "iron_arrow", "steel_arrow"]   # the same as "ammo" in data/items/bow.json (test_slot_sounds checks)
const BowAim := preload("res://src/shared/bow_aim.gd")
const MeleeRules := preload("res://src/shared/melee_rules.gd")   # anything in hand is a weapon (data/items/melee.json, Dave 19 Nov 2026)
const BowReticle := preload("res://src/client/bow_reticle.gd")
const SAW_CATEGORY := "Carpenter's"   # the craft tab a left click with a saw opens (Dave 17 Nov 2026: "the carpenters category")
const HELD_FIXED_SCALE := {"rod": 1.0, "hoe": 1.0, "saw": 1.0, "bow": 1.0, "arrow": 1.0}   # held at ground size, not scaled to the 1 m cap or by 1.4x: the rod's cane and reel were lost, the hoe blade was tiny and the saw nearly 1 m long
const HELD_LOOK_MAX_M := 1.0      # no held tool longer than this (a big look size or a long hoe is scaled down to it)
const HELD_GRIP_FROM_END_M := 0.12
const HELD_LOOK_TURN := {
	"axe": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"pick": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),   # haft forward (+y), head vertical with the pointed pick DOWN and the chisel up (Dave 2026-10-25: flip it 180 degrees about the haft), both ends bending toward the grip in the haft-and-head plane, so from the front the head is one straight bar
	"hoe": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"knife": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"saw": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"scraper": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),   # like the knife: the blade end forward, the edge down
	"sickle": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),   # like the hoe: the blade curls round at the end of the handle
	"scythe": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"striker": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"hammer": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"hand_net": Basis.IDENTITY,   # the net hangs from the hand instead (_make_hanging_net_model); listed so it goes through the look path
	"shovel": Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)),
	"shaft": Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)),
	"rod": Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)),   # the fishing rod: butt to tip along +y, the reel underneath (-z), so the rod points forward and up in the hand
	"bow": Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)),   # the bow stands upright in the hand (limbs up and down, belly forward, string toward the archer)
	"arrow": Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)),
	"quiver": Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)),
	"mace": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),   # handle to head along +x like the axe: haft forward, stone head on top (items_check: stone_mace had no held model)
	"flanged_mace": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"club": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"candle": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),   # a candle is held upright, flame up
	"sword": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
}
const JAB_REACH := 0.7
const JAB_S := 0.28
const THROW_SPEED := 24.0
const THROW_GRAVITY := 9.8

var held_key: int = 0                     # the hotbar key (0 to 9) in the right hand; key k is pack slot k
var held_slot: int:                       # that key's pack slot (InventoryView.key_slot), -1 when it is empty
	get:
		return int(_inv.key_slot(held_key)) if _inv != null else -1
var holding: bool = true                  # false after the held slot's key is pressed again: hands empty
const HOTBAR_SLOTS := 10
var aiming: bool = false
const LANTERN_BAIL_M := 0.18             # basic_look.gd "lantern": the bail's top is this far above the look's middle; the fist holds the bail, the lantern hangs below
const TORCH_PLACE_M := 3.0                # how far the crosshair reaches to stick a torch in the ground or on a wall
var off_key: int = -1                     # the hotbar key carried in the left hand (items with "offhand": true: torch, shield), -1 for none
var off_slot: int:                        # that key's pack slot, -1 when it is empty or none
	get:
		return int(_inv.key_slot(off_key)) if _inv != null and off_key >= 0 else -1
var off_holding: bool = false             # false after its key is pressed again: left hand empty
var blocking: bool = false                # B held with a shield in the left hand (the combat rules read this)
var _off_model: Node3D
var _off_shown: int = 0

var _inv                                  # InventoryView
var _hanging_net: Mesh                    # the shore net as it hangs from the hand (BasicLook "hand_net_hanging"), built once
var _net
var report_now: Callable                  # () -> sends this client's position to the server now (terrain_client send_position_now), just before a blow
var seen_ms: Callable                     # () -> [server ms, server ms] the animals are drawn at (animal_view.seen_server_ms; protocol 155), sent with a blow
var _camera: Camera3D
var _root: Node3D
var _ground_below: Callable
var held_light_budget: Callable          # () -> true when the held light may be on beside a nearby fire light (not at Low)
var _model: Node3D
var _arms                                 # first-person arms (Ragdoll.new(true)) on the camera; the held tool sits in its right hand
var _stop_t: float = 0.0                  # hit stop left, seconds
var _shoulder_log: MeshInstance3D          # the log across the shoulder (set_shoulder)
var _shoulder_log_two: MeshInstance3D      # the second log beside it
var _arm_up: float = 0.0                  # 0 arms hang at the body's side, 1 raised to the camera pose (swing, jab, use, aim)
var water_depth_at: Callable = Callable()   # (x, z) -> metres of standing water there; set by the client scene, unset in tests
var variant_slot: int = -1               # the pack slot of the wall variant the wheel chose (doorway, window), -1 for the held one
var lift_steps: int = 0                  # a held foundation stands this many 0.1 m steps above the ground (mouse wheel, Dave 2026-10-22)
var _blueprint_yaw: int = 0               # the turn (degrees) the ghost will be placed at
var _first_person: bool = true
var _avatar_rig                          # the full body (ragdoll_body.gd) drawn in third person, or null
var carrying_log: bool = false             # a large log on the shoulder (terrain_client sets it every frame): the right hand steadies it, so its tool is put away and comes back when the log is laid down (TEST-010)
var _mounted: bool = false                # the model is in the hand: the arm animations move it, not the offsets below
var _label: Label
var _jab_t: float = -1.0
var _bow_cfg: Dictionary = {}               # data/items/bow.json, read on the first shot (the arrow sound follows its flight)
var _draw_t: float = -1.0                 # the bow up and drawing (Dave 10 Nov 2026: right mouse held): seconds since it went up, -1 when it is down
var _aim_dir: Vector3 = Vector3.ZERO      # where the drawn bow points now: the middle of the view, which the sway and the pull turn (bow_view_turn)
var _reticle = null                       # BowReticle: the cross while the bow is up
var animal_aim_rows: Callable = Callable()   # () -> [[position, heading, body_m], ...] of the animals drawn near; set by the client scene (aim assist)
var rig_drawing: bool = false              # the shot runner's --shot-draw (look rig only): the bow is held up and drawing as if right were held, so the crosshair, sway and loosed arrows can be pictured
var rig_keep_dark: bool = false            # the shot runner (look rig only), given a dark torch or lantern without --shot-lit: selecting it does not light it
var rig_lit: bool = false                  # the shot runner's --shot-lit (look rig only): the held flame's light stays on beside a fire light at Low
var bow_force: String = ""                 # the shot runner's bow pose, "STATE[:DRAW]" (idle, raised, drawn; draw 0 to 1), "" = from play
var _bow_up: bool = false                  # the bow is raised or drawn: the arms come up to the camera pose
var _flights: Array = []                  # local visuals of spears this player threw: {node, vel, age}
var _shown_number: int = 0
var _sound                                # SoundStage (hit sounds)
var shrub_near: Callable = Callable()   # (from, to) -> [chunk, id] of the bush or shrub the swing line passes through, or []; set by the client scene
var swath_cut: Callable                 # (held pack slot, tool class) -> radius: one sickle or scythe swing (harvest.gd swath; 0 when nothing was sent)
var _tree_near: Callable                  # (point) -> [chunk, id] of the tree trunk standing there, or []
var trunks_round: Callable                 # (point, radius) -> [[root, trunk radius, height]]: the ghost goes red over a standing tree (terrain_client _trunks_round)
var trunks_version: Callable               # () -> int, rising when the held trees change (a tree felled under a still ghost)
var _swing_t: float = -1.0
signal struck(side: float, weight: float)   # a tool blow reached its impact frame: the camera jolts (feel_kicks.gd)
var _caption_age: float = 1.0
var _caption_held: int = -1
var _caption_off: int = -1
var swing_serial: int = 0                  # +1 at every swing start: the third-person body restarts its chop clip on a change
var _pause_t: float = 0.0
var _swing_hit: bool = false
var _cover_at: Callable                   # (point) -> true when under a tree's crown
var spyglass_look: Callable = Callable()   # (on, pack slot, tier): the held spyglass up to the eye or down (the client scene's _spyglass_item)
var _spyglass_up: bool = false             # right mouse is held on a spyglass in hand
var _blueprint: Node3D
var _blueprint_kit: String = ""
var _ghost_state: int = -1   # the structure state the ghost model shows (a roof corner swaps between its 45 and 65 shapes, A-37)
var _ghost_material: StandardMaterial3D
var _blueprint_at: Vector3 = Vector3.ZERO
var _blueprint_ok: bool = false
var _ghost_on_base: bool = false           # the ghost is snapped to a base: a piece on a foundation, or a foundation beside another (the wheel does not lift it)
var _placement: Dictionary = {}              # structures.json: footprints, gaps, caps (shared with the server's rules)
var blueprint_state: String = ""            # what the ghost shows now: "open", "covered", "far", or a red reason of PlacementRules.reason_text / blocked(): "close", "overlap", "bed", "crowded", "camp", "steep", "float", "water", "shallow", "nofire", "notable", "taken", "nodoorway", "mismatch", "wheel_*" (tests read it)
var _door_shape: String = ""                # the opening of the doorway a door's ghost is aimed at ("" for any other piece or no doorway): the words of "mismatch" and "taken"
var _blueprint_shape: Vector2 = Vector2(-1.0, -1.0)
var _blueprint_next_msec: int = 0
var blueprints = HammerBlueprints.new()      # the hammer's blueprint list (R with a hammer in hand); the picked one is placed from the pack's materials, no kit item

const MotionExtra := preload("res://src/client/character/motion_extra.gd")
const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")
const SWING_S := MotionExtra.CHOP_LENGTH        # a chop is a whole swing: wind-up, wide stroke, impact, follow-through, recovery (31 Oct 2026: 0.95 s, was the 0.55 s hammer rhythm)
const PICK_SWING_S := MotionExtra.PICK_LENGTH
const SWING_PAUSE_S := 0.1                       # the short pause before the next swing when the button is held
const NET_THROW_M := 6.0                        # how far ahead the shore net lands looking level (server reach: fishing.json net.reach_m, 8 m)
const NET_NEAR_M := 2.0                         # the nearest a net is thrown, looking down at the water
const NET_FAR_M := 7.0                          # the furthest, inside the server's 8 m (it measures from the last reported position)
const HIT_STOP_S := 0.045
const HIT_AT := MotionExtra.CHOP_IMPACT_S / MotionExtra.CHOP_LENGTH     # share of the swing where the tool reaches the target (the swing_fp and chop clips' impact key, 0.5 s of 0.95); the thump and the server's hit are this same tick
const PICK_HIT_AT := MotionExtra.PICK_IMPACT_S / MotionExtra.PICK_LENGTH
const REACH_M := 3.0
const MISS_POINT_M := 2.5   # the point a swing at nothing reports (inside the server's MINE_REACH_M from the feet even looking straight up)


const FrameProbe := preload("res://src/debug/frame_probe.gd")
const HammerBlueprints := preload("res://src/client/hammer_blueprints.gd")
const FlameUp := preload("res://src/client/flame_up.gd")
const FarmRules := preload("res://src/shared/farm_rules.gd")   # the hoe's plant list and grid (plantables, grid_points, spacing_of)

func setup(inventory_view, terrain_net, camera: Camera3D, world_root: Node3D, hud_layer: CanvasLayer, ground_below: Callable, sound_stage = null, tree_near: Callable = Callable(), cover_at: Callable = Callable()) -> void:
	_cover_at = cover_at
	_hud_layer = hud_layer
	_sound = sound_stage
	_placement = PlacementRules.load_config()

	if FileAccess.file_exists(HOTBAR_FILE):
		held_key = clampi(int(FileAccess.get_file_as_string(HOTBAR_FILE)), 0, HOTBAR_SLOTS - 1)

	_tree_near = tree_near
	_inv = inventory_view
	blueprints.setup(_inv.table, _inv.inventory, hud_layer)

	if _inv.has_method("stock_fill"):
		blueprints.stock_count = _inv.stock_fill   # the hammer list counts what a build draws on: the pack and the craft stock in reach
	_net = terrain_net

	if _net != null and _net.has_signal("wheel_share_received"):
		_net.wheel_share_received.connect(_on_wheel_share)
	if _net != null:
		_net.road_marker_reached.connect(_on_road_marker_reached)
		_net.survey_refused_at.connect(_on_survey_refused)

		if _net.has_signal("hoe_verdict_got"):
			_net.hoe_verdict_got.connect(_on_hoe_verdict)
	_camera = camera
	_root = world_root
	_ground_below = ground_below
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.offset_bottom = -LABEL_ABOVE
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(_label)
	# Dave's own arms (dynasty_arms.gd) go with his body.
	_arms = DynastyArmsScript.new()
	_arms.name = "Arms"
	_arms.position = ARMS_POS
	_arms.rotation_degrees.x = ARMS_PITCH_DEG
	camera.add_child(_arms)
	_arms.play("idle")

	if not _arms.has_meta("own_hands"):    # Dave's hands have fingers of their own
		_make_fist(_arms.hand_mount_r, Vector3(0.0, 0.0, -0.02))     # a closed hand, so the handle goes into a fist
		_make_fist(_arms.hand_mount_l, Vector3(0.0, 0.0, -0.04))

	# Debug (Kathleen 2026-10-25: the first-person arms cast shadows but do not show): --arms-debug draws them in plain magenta, unlit and
	# on top of everything, so a picture tells whether the mesh is drawn at all (then it is a colour or occlusion fault) or not (then culling).
	if OS.get_cmdline_user_args().has("--arms-debug") and _arms.body_mesh != null:
		var debug_material: StandardMaterial3D = StandardMaterial3D.new()
		debug_material.albedo_color = Color(1.0, 0.0, 1.0)
		debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		debug_material.no_depth_test = true
		_arms.body_mesh.material_override = debug_material


# A small skin-coloured, slightly flattened ball at a hand mount: with a tool it is the fist round the handle, without one it
# gives the bare hand a shape.
func _make_fist(mount: Node3D, at: Vector3) -> void:
	ArmsView.make_fist(mount, at, FIST_COLOR)


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

		if _off_model != null and _off_model.get_parent() != null:
			_off_model.get_parent().remove_child(_off_model)
			_mount_off_model()


# The player's full body (third person), whose right hand carries the held model when the camera is out.
func set_avatar(avatar) -> void:
	_avatar_rig = avatar


func _arm_play(clip: String, seconds: float) -> void:
	if _arms != null and _arms.visible:
		var length: float = _arms.animation_player.get_animation(clip).length
		_arms.play(clip, length / maxf(seconds, 0.05))


# The item in a hotbar key's slot, 0 when it is empty.
func _key_number(key: int) -> int:
	var slot: int = int(_inv.key_slot(clampi(key, 0, HOTBAR_SLOTS - 1)))
	return _inv.inventory.numbers[slot] if slot >= 0 else 0


# A hotbar key (0 to 9): hold what is in its slot, or put it away when it is the one already held.
func press_slot(slot: int) -> void:
	# Food on the hotbar is eaten, not held (Dave's play test 19 Nov 2026); holding the key keeps eating (InventoryView.eat_from_hotbar).
	if _inv.edible_slot(int(_inv.key_slot(clampi(slot, 0, HOTBAR_SLOTS - 1)))) and _inv.eat_from_hotbar(clampi(slot, 0, HOTBAR_SLOTS - 1)):
		return

	# Torch and shield go in the left hand beside whatever the right hand holds (Dave 2026-10-23); the same key again stows it.
	if is_offhand(_key_number(slot)):
		slot = clampi(slot, 0, HOTBAR_SLOTS - 1)

		if off_holding and off_key == slot:
			off_holding = false
			blocking = false
			_relight_on_press(slot, true)
		else:
			off_key = slot
			off_holding = true
			_relight_on_press(slot)

		_inv.refresh_hotbar()

		if _sound != null:
			_sound.itemfx.hotbar(slot)

		return

	if holding and slot == held_key:
		holding = false
		aiming = false
		_inv.refresh_hotbar()

		if _sound != null:
			_sound.itemfx.hotbar(held_key)

		return

	select(slot)


# Use on a tool in the inventory (its key, InventoryView.equip_with_move): hold it, or put it away if it is already in hand.
func equip_toggle(slot: int) -> void:
	press_slot(clampi(slot, 0, HOTBAR_SLOTS - 1))


# A torch that went out lights again when its hotbar key is pressed, wherever you are (Dave 6 Nov 2026: it keeps its name and just goes out; nobody is stuck in
# a cave without light). The torch is an off-hand item, so press_slot calls this for it too; in rain or water it goes out again by the usual rules.
func _relight_on_press(slot: int, quiet: bool = false) -> void:
	var number: int = _key_number(slot)
	var row: Dictionary = _inv.table.entry(_inv.table.id_of(number)) if number != 0 else {}
	var relit: String = str(row.get("relit_item", ""))

	if relit == "" and number != 0 and _slot_out(int(_inv.key_slot(clampi(slot, 0, HOTBAR_SLOTS - 1)))):
		relit = _inv.table.id_of(number)   # a torch that went out is the same torch (Dave 16 Nov 2026): pulling it out lights it

	if relit == "":
		return

	if quiet or rig_keep_dark:
		return   # the same key again puts the torch away; the look rig pictures a dark one as it is

	# A lantern (buildables plan B4) burns behind its horn panes, so only water stops it lighting; a torch needs to be out of the rain too. Out of fuel, the
	# server loads a candle or lamp oil from the pack, or says there is none.
	var lit_row: Dictionary = _inv.table.entry(relit)
	var wet: String = str(light_block_fn.call()) if light_block_fn.is_valid() else ""

	if wet == "water" or (wet == "rain" and bool(lit_row.get("rain_douses", false))):
		if FlameRules.flame_word(lit_row) == "lantern":
			_inv._on_notice("It is too wet to light the lantern. Get out of the water first.")
		else:
			_inv._on_notice("It is too wet to light the torch. Get out of the water and the rain, or into a cave or under cover.")

		return

	_net.inventory_action.rpc_id(1, Net.ACT_RELIGHT, 0, int(_inv.key_slot(clampi(slot, 0, HOTBAR_SLOTS - 1))) + 1, 0, Vector3.ZERO)   # the pack slot plus one (0: the first one that went out)   # no fire needed (Dave 6 Nov 2026)


func select(slot: int) -> void:
	# A left-hand item picked this way (Use from the pack, a number key) goes in the left hand, never the right.
	if is_offhand(_key_number(slot)):
		off_key = clampi(slot, 0, HOTBAR_SLOTS - 1)
		off_holding = true
		_relight_on_press(off_key)
		_inv.refresh_hotbar()

		if _sound != null:
			_sound.itemfx.hotbar(off_key)

		return

	if _sound != null and (clampi(slot, 0, HOTBAR_SLOTS - 1) != held_key or not holding):
		_sound.itemfx.hotbar(clampi(slot, 0, HOTBAR_SLOTS - 1))

	held_key = clampi(slot, 0, HOTBAR_SLOTS - 1)
	holding = true
	aiming = false
	_inv.refresh_hotbar()
	var number: int = _key_number(held_key)
	_relight_on_press(held_key)

	if number != 0 and not is_holdable(number):
		_inv._on_notice("%s cannot be held in the hand (Use or Eat it from the inventory)" % _inv.table.name_of(number))

	var file: FileAccess = FileAccess.open(HOTBAR_FILE, FileAccess.WRITE)

	if file != null:
		file.store_string(str(held_key))


# The right hand's item. Left-hand items (torch, shield: items.json "offhand") are never the right hand's: a torch that lands in the selected hotbar slot
# (crafted, picked up, dragged there) does nothing until its key is pressed, and then it goes in the LEFT hand (Dave, 7 Nov 2026).
func held_number() -> int:
	var slot: int = held_slot

	if not holding or slot < 0 or carrying_log:
		return 0

	var number: int = _inv.inventory.numbers[slot]
	return 0 if is_offhand(number) else number


# Tells the server what is in the hand when it changes (protocol 146 held_item, Dave 20 Nov 2026: goblins react to "a weapon in hand"), at most
# every HELD_REPORT_S; the server checks it against the pack.
const HELD_REPORT_S := 0.5
# From 159 with the left hand's item and what the hands are doing, for the other players to see (server_players.gd): a flag change goes at
# once (at most every HAND_REPORT_S), an item change at most every HELD_REPORT_S.
const HAND_REPORT_S := 0.1
const HAND_BOW_RAISED := 1
const HAND_BOW_DRAWN := 2
const HAND_SHIELD_UP := 4
const HAND_LADDER := 8
var _held_sent: Array = []
var _held_wait: float = 0.0


# The shield up, and the bow raised or drawn (protocol 162: drawn on the other players' screens, dynasty_body.gd _bow_aim; one send when the
# draw starts and one at full draw). The ladder bit is kept for its pose on other players (not made yet).
func hand_flags() -> int:
	var flags: int = HAND_SHIELD_UP if blocking else 0

	if _bow_posing():
		var state: String = bow_state()
		flags |= HAND_BOW_DRAWN if state == "drawn" else (HAND_BOW_RAISED if state == "raised" else 0)

	return flags


func _report_held(delta: float) -> void:
	_held_wait -= delta

	if not (_net is Node) or _held_wait > 0.0 or not _net.is_inside_tree():
		return

	var line: MultiplayerPeer = _net.multiplayer.multiplayer_peer

	if line == null or line.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or _net.multiplayer.get_unique_id() == 1:
		return   # no server to tell (offline, a headless check, a line closed on quitting, or this is the server)

	var now: Array = [held_number(), off_number(), hand_flags()]

	if now != _held_sent:
		var items_changed: bool = _held_sent.is_empty() or now[0] != _held_sent[0] or now[1] != _held_sent[1]
		_held_sent = now
		_held_wait = HELD_REPORT_S if items_changed else HAND_REPORT_S
		_net.held_item.rpc_id(1, int(now[0]), int(now[1]), int(now[2]))


func held_id() -> String:
	return _inv.table.id_of(held_number())


# Left-hand items: the item table marks them with "offhand": true (torch, shield, later a lantern).
# True while a placement blueprint (ghost) is held; auto pickup stays off then.
func placing() -> bool:
	return _blueprint != null


# A hammer or knife in hand and a blueprint picked from its list (R or right click): the ghost and the click work like a kit's, but the materials come from the pack.
func _blueprinting() -> bool:
	return holding and blueprints.picked > 0 and _build_tier() > 0


# The tool in hand that builds blueprints: "hammer", "knife" (Dave 15 Nov 2026: right click with a knife opens the knife's list, TREE_WOOD_TOOLS_DESIGN.md s1.4) or "".
func _build_tool() -> String:
	return "hammer" if _hammer_tier() > 0 else ("knife" if _is_knife() else "")


# The tier a picked blueprint is built with: the hammer in hand's; a knife builds every row of its list, so 1; 0 when nothing in hand builds.
func _build_tier() -> int:
	return _hammer_tier() if _hammer_tier() > 0 else (1 if _is_knife() else 0)


# The list follows the tool in hand: another tool's pick and open menu go (the hammer's rows are not the knife's).
func _sync_build_tool() -> void:
	var tool: String = _build_tool()

	if tool != "" and tool != blueprints.tool:
		blueprints.clear()
		blueprints.category = ""   # the other list has other groups
		blueprints.tool = tool
		_plan_queue.clear()


func _hoe_in_hand() -> bool:
	return holding and held_number() != 0 and str(_inv.table.entry(held_id()).get("tool_class", "")) == "hoe"


func _hammer_tier() -> int:
	var entry: Dictionary = _inv.table.entry(held_id())
	return int(entry.get("tier", 1)) if str(entry.get("tool_class", "")) == "hammer" else 0


# Repair (hammer menu, then left click): the server mends the piece you aim at from materials nearby (building_wear.json) and says what it did.
func _repair_here() -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * 8.0)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	# A blue blueprint site has no collider (it is walked through): with nothing hit, the point 4 m ahead finds it.
	var id: int = _inv.structure_id_near(hit["position"] if not hit.is_empty() else from - _camera.global_transform.basis.z * 4.0)

	if id == 0:
		_inv._on_notice("Aim at the wall, floor, roof or station you want to repair, or a blueprint to fill")
		return

	_arm_play("use", 0.6)
	_net.inventory_action.rpc_id(1, Net.ACT_REPAIR_STRUCT, id, held_slot + 1, 0, Vector3.ZERO)   # the hammer in hand (protocol 117)


# A boulder within swing reach under the aim (the hammer breaks it, _strike sends the blow like a pick's).
func _boulder_aimed() -> bool:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and _inv.boulder_near(hit["position"]) != 0


# Save building plan (hammer menu, then left click): keeps the building you aim at, every blueprint piece joined to it, as a plan in the menu.
func _save_plan_here() -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * 8.0)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		_inv._on_notice("Aim at the building you want to save")
		return

	var saved: Dictionary = blueprints.save_plan_near(_inv.structure_rows(), hit["position"])

	if not bool(saved["ok"]):
		_inv._on_notice("Too many saved plans: right click and pick one to place" if saved.get("why", "") == "full" else "No building there that a hammer can place. Aim at a wall, floor, roof or station")
		return

	var text: String = "Saved %s: %d pieces. Right click to place it" % [saved["name"], int(saved["pieces"])]

	if int(saved["skipped"]) > 0:
		text += " (%d pieces a hammer does not place are left out)" % int(saved["skipped"])

	_inv._on_notice(text)


# A saved plan placed: the anchor goes where the ghost is and the other pieces follow, one every PLAN_STEP_MSEC so nothing stalls a frame and
# the server has each piece in place before the next arrives. The server checks every piece (reach, ground, materials) as if placed by hand.
const PLAN_STEP_MSEC := 150
const PLACE_REACH_M := 6.0   # the server's PLACE_REACH_M (server_items.gd): a spot farther from the player's feet is refused
var _plan_queue: Array = []
var _plan_next_msec: int = 0


func _start_plan_place() -> void:
	var plan: Dictionary = blueprints.plans.plans[blueprints.plan_picked]
	_plan_queue = blueprints.placements_of(blueprints.plan_picked, _blueprint_at, float(_blueprint_yaw))
	var left_out: int = (plan["pieces"] as Array).size() - _plan_queue.size()   # pieces a knife builds now (an older plan): the hammer cannot place them
	_plan_next_msec = 0

	if _plan_queue.is_empty():
		_inv._on_notice("%s holds only pieces a knife builds now. Pick them from the knife's list" % plan["name"])
		return

	_plan_queue[0]["lift"] = lift_steps
	_inv._on_notice("Placing %s: %d pieces%s" % [plan["name"], _plan_queue.size(), " (%d left out: a knife builds them now)" % left_out if left_out > 0 else ""])


func _plan_step() -> void:
	if _plan_queue.is_empty():
		return

	var now: int = Time.get_ticks_msec()

	if now < _plan_next_msec:
		return

	_plan_next_msec = now + PLAN_STEP_MSEC
	var piece: Dictionary = _plan_queue.pop_front()
	_net.inventory_action.rpc_id(1, Net.ACT_PLACE_BLUEPRINT, int(piece["bp"]), int(piece.get("lift", 0)), int(piece["yaw"]), piece["pos"])


# Right click (or R) with a hammer or a knife in hand opens or shuts its blueprint list.
func toggle_blueprints() -> bool:
	if _build_tier() <= 0:
		return false

	_sync_build_tool()
	blueprints.toggle(_build_tier())
	return true


func is_offhand(number: int) -> bool:
	if number == 0:
		return false

	var entry: Dictionary = _inv.table.entry(_inv.table.id_of(number))
	return bool(entry.get("offhand", false))


func off_number() -> int:
	var slot: int = off_slot

	if not off_holding or slot < 0:
		return 0

	var number: int = _inv.inventory.numbers[slot]
	return number if is_offhand(number) else 0


func off_id() -> String:
	return _inv.table.id_of(off_number())


# The pack slot of a burning flame in either hand that water or rain can put out (a torch, items.json "goes_out"; a lantern, "doused_item"), or -1.
func flame_slot() -> int:
	if _inv == null:
		return -1

	for spec in [[held_number(), held_slot], [off_number(), off_slot]]:
		if int(spec[0]) != 0 and FlameRules.can_go_out(_inv.table.entry(_inv.table.id_of(int(spec[0])))) and not _slot_out(int(spec[1])):
			return int(spec[1])

	return -1


# The pack slot of a torch in either hand that can be placed (items.json places_as: burning or out), or -1.
func _torch_hand_slot() -> int:
	if _inv == null:
		return -1

	for spec in [[off_number(), off_slot], [held_number(), held_slot]]:
		if int(spec[0]) != 0 and _inv.table.entry(_inv.table.id_of(int(spec[0]))).has("places_as"):
			return int(spec[1])

	return -1


# True when the right hand holds nothing that has a right click of its own (a tool, a weapon, food).
func _right_hand_free() -> bool:
	if not holding or held_number() == 0:
		return true

	var entry: Dictionary = _inv.table.entry(held_id())
	return entry.has("places_as") or not (str(entry.get("kind", "")) in ["tool", "weapon"] or _inv.edible_slot(held_slot))


# Where the crosshair is within TORCH_PLACE_M: on ground or a floor the torch stands up facing the player, on a wall it faces out of the wall; the server checks the rest.
func _place_torch_here() -> void:
	var from: Vector3 = _camera.global_position
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * TORCH_PLACE_M))

	if hit.is_empty():
		_inv._on_notice("Aim at the ground or a wall close by to place the torch")
		return

	var normal: Vector3 = hit["normal"]
	var at: Vector3 = hit["position"]
	var on_wall: bool = absf(normal.y) <= 0.4

	if not on_wall and normal.y < 0.65:
		_inv._on_notice("Too steep for a torch there")
		return

	var facing: Vector3 = normal if on_wall else from - at
	var yaw_deg: int = int(round(rad_to_deg(atan2(facing.x, facing.z))))
	_arm_play("use", 0.5)
	_net.inventory_action.rpc_id(1, Net.ACT_PLACE_TORCH, _torch_hand_slot(), 1 if on_wall else 0, yaw_deg, at)


# Whether the camera is under cover from the rain (a tree's crown or a roof).
var light_block_fn: Callable   # () -> "water", "rain" or "": why a flame cannot be lit here (the client reads FlameRules at the key press; Dave 6 Nov 2026)


func flame_covered() -> bool:
	return _cover_at.is_valid() and bool(_cover_at.call(_camera.global_position))


func _off_class() -> String:
	return str(_inv.table.entry(_left_id()).get("tool_class", ""))


# What the left hand shows: the off hand's item, or, in third person, a torch held as the main item (Dave's torch carry infographic, 6 Nov 2026: the torch is
# always carried in the LEFT hand; #488's first look failed because a torch taken as the main item stayed in the right hand by the hip).
func _left_number() -> int:
	var number: int = off_number()

	if number != 0:
		return number

	if not _first_person and _avatar_rig != null and holding and _is_torch():
		return held_number()

	return 0


func _left_id() -> String:
	return _inv.table.id_of(_left_number())


func _bow_config() -> Dictionary:
	if _bow_cfg.is_empty():
		_bow_cfg = BowAim.load_config()

		if _bow_cfg.is_empty():
			_bow_cfg = {"speed_max": 45.0}

	return _bow_cfg


func _raise_bow() -> void:
	if not has_arrow():
		_inv._on_notice(BowAim.say(_bow_config(), held_id(), "say_no_ammo"))
		return

	_draw_t = 0.0
	_aim_dir = -_camera.global_transform.basis.z
	_arm_play("use", 0.6)

	if _sound != null:
		_sound.slots.play("bow_draw", _camera.global_position - _camera.global_transform.basis.z * 0.6)   # the limbs flex and the string creaks as it is pulled (make_bow.py)


func _lower_bow() -> void:
	_draw_t = -1.0


# Left click with the bow up: the arrow goes along the aim (the server turns it by the skill's spread). Still holding right, the next arrow is drawn.
func _loose() -> void:
	_aim_dir = -_camera.global_transform.basis.z   # through the cross in the middle of the screen
	var draw_ms: int = int(_draw_t * 1000.0)
	var arrow: int = arrow_to_shoot()
	_send_seen()
	_net.inventory_action.rpc_id(1, Net.ACT_SHOOT, held_slot, draw_ms, arrow, _aim_dir)

	if arrow != 0:
		if _sound != null:
			_sound.slots.play("bow_loose", _camera.global_position - _camera.global_transform.basis.z * 0.6)   # the twang and swish

		_arrow_flight(draw_ms, _aim_dir, arrow)

	_draw_t = 0.0 if _right_held() and has_arrow() else -1.0


# "idle" (the bow down), "raised" (up at sight, the string coming back) or "drawn" (full draw); the arms pose follows it (Kathleen's _pose_bow).
func bow_state() -> String:
	if _draw_t < 0.0:
		return "idle"

	return "drawn" if bow_draw() >= 1.0 else "raised"


# How far the string is back, 0 to 1 over bow.json draw_max_ms.
func bow_draw() -> float:
	if _draw_t < 0.0:
		return 0.0

	return clampf(_draw_t * 1000.0 / maxf(float(_bow_config().get("draw_max_ms", 1200)), 1.0), 0.0, 1.0)


# The aim's sway now in degrees (x yaw, y pitch): still for the skill's steady_s at full draw, then growing (bow.json aim).
func bow_wobble() -> Vector2:
	if bow_state() != "drawn":
		return Vector2.ZERO

	var cfg: Dictionary = _bow_config()
	var drawn_s: float = _draw_t - float(cfg.get("draw_max_ms", 1200)) / 1000.0
	return BowAim.wobble_offset(BowAim.wobble_deg(cfg, _inv.skill_level_of("hunting"), drawn_s), _draw_t, float(cfg.get("aim", {}).get("wobble_hz", 0.6)))


# Where the sway and the pull would take the aim from the unturned view: the view turned by the sway, then drawn toward a vital zone of an
# animal near the aim by the skill's pull. bow_view_turn turns the whole view this way, so the aim stays the middle of the screen.
func aim_direction() -> Vector3:
	var view: Basis = _camera.global_transform.basis
	var aim: Vector3 = BowAim.turned(-view.z, view.x, view.y, bow_wobble())
	var points: Array = []

	if animal_aim_rows.is_valid():
		for row in animal_aim_rows.call():
			points.append_array(BowAim.zone_points(_bow_config(), row[0], float(row[1])))

	return BowAim.assist(_bow_config(), _inv.skill_level_of("hunting"), _camera.global_position, aim, points)


# How far the drawn bow turns the whole view (degrees: x to the right, y up), the sway and the pull together (Dave 10 Nov 2026: "the
# crosshairs shouldnt move around like they do the whole screen should move like that but much less. it my aiming thats moving not just the
# crosshairs"). The client scene sets the eye camera back to the mouse's look first, then turns it by this; the cross stays in the middle and the
# arrow goes where it points. Zero with the bow down.
func bow_view_turn() -> Vector2:
	if _draw_t < 0.0 or _camera == null:
		return Vector2.ZERO

	var view: Basis = _camera.global_transform.basis
	return BowAim.turn_of(aim_direction(), -view.z, view.x, view.y)


# The view narrows a little as the bow comes up (bow.json aim.zoom_fov_share at full draw); 1 with the bow down. The client scene multiplies its field of view by it.
func aim_fov_share() -> float:
	return lerpf(1.0, float(_bow_config().get("aim", {}).get("zoom_fov_share", 0.85)), bow_draw())


# Right held, or the look rig holding it for the pictures (rig_drawing).
func _right_held() -> bool:
	return rig_drawing or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _update_bow(delta: float) -> void:
	if _draw_t >= 0.0 and (not _is_bow() or not _right_held() or _body_out()):   # passing out lowers it too (QA #19)
		_draw_t = -1.0   # the bow put away, or right let go outside the game window

	if rig_drawing and _draw_t < 0.0 and _is_bow() and holding and has_arrow() and _camera != null:
		_raise_bow()   # the rig keeps it up: drawn again after each loose

	if _draw_t >= 0.0:
		_draw_t += delta
		_aim_dir = -_camera.global_transform.basis.z   # the view is the aim: bow_view_turn already turned it

	if _reticle == null and _hud_layer != null:
		_reticle = BowReticle.new()
		_reticle.arm_px = float(_bow_config().get("aim", {}).get("reticle_px", 14))
		_hud_layer.add_child(_reticle)

	if _reticle != null:
		_reticle.visible = aim_cross_shown()
		_reticle.point = _reticle.global_position + _reticle.size * 0.5   # always the middle of the screen: the view moves, not the cross


# Whether the bow or spear cross is up: a drawn bow, or a spear in hand shows it by itself, for the throw and jab (Dave 22 Nov 2026); put away,
# it goes. The inspection + reads this too and hides while it is true (inspect_reticle.gd), worked out here so both agree in the same frame.
func aim_cross_shown() -> bool:
	return _draw_t >= 0.0 or (holding and _is_spear() and _model != null and _model.visible)


func _is_spear() -> bool:
	return str(_inv.table.entry(held_id()).get("weapon_class", "")) in ["spear", "fish_spear"]


# Held the way a spear is held (placement only; the jab, throw and crosshair stay the spear's): a spear, or in third person any "shaft" look
# (pike, lance, quarterstaff, halberd, javelin), whose mesh lies point to -Z, not handle to head along +Y. Laid along the fingers like a tool
# they sat 0.15-0.27 m off the hand (23 Nov 2026, the check in test_remote_players found it on other players; the player's own body had the
# same). First person keeps the hand clip's hold: a long shaft hung down from the view would swing its butt up past the eye.
func _held_as_shaft() -> bool:
	return _is_spear() or (not _first_person and not (_is_placeable() or _is_look_item()) and shaft_look(held_id()))


# A "shaft" look (looks.json shape): one rule for the player's own body and other players (player_view.gd held_kind).
static func shaft_look(item_id: String) -> bool:
	return str(BasicLook.entry(item_id).get("shape", "")) == "shaft"


# The Fishing spear (Part C): held and jabbed like a spear, only at water, and never thrown.
func _is_fish_spear() -> bool:
	return str(_inv.table.entry(held_id()).get("weapon_class", "")) == "fish_spear"


# Whether the pack holds an arrow the bow can shoot (the server's ammo list, data/items/bow.json), so a draw with
# no arrow lets go silently instead of twanging.
func has_arrow() -> bool:
	return arrow_to_shoot() != 0


# The arrow the next shot takes, as the server picks it: from a worn quiver if it holds one the bow takes, else from the pack; in each, the one
# the bow is loaded with while it is there, else the first of the bow's ammo there; 0 none.
func arrow_to_shoot() -> int:
	var quiver: Dictionary = _inv.quiver_counts() if _inv.has_method("quiver_counts") else {}
	var from_quiver: int = _arrow_in(func(number: int) -> int: return int(quiver.get(number, 0)))
	return from_quiver if from_quiver != 0 else _arrow_in(func(number: int) -> int: return _inv.inventory.count_of(number))


func _arrow_in(count_of: Callable) -> int:
	var loaded: int = int(_inv.bow_arrow)
	var ammo: Array = BowAim.ammo_for(_bow_config(), held_id())

	if loaded != 0 and int(count_of.call(loaded)) > 0 and ammo.has(_inv.table.id_of(loaded)):
		return loaded

	for id in ammo:
		var number: int = _inv.table.number_of(id)

		if number > 0 and int(count_of.call(number)) > 0:   # 0 = not in the table (0 is also an empty slot)
			return number

	return 0


# A spyglass item in hand (tool_class "spyglass", data/items/spyglass.json), not broken: right mouse held looks through it.
func _is_spyglass() -> bool:
	return str(_inv.table.entry(held_id()).get("tool_class", "")) == "spyglass" and not _inv.is_broken(held_slot)


func _look_spyglass(on: bool) -> void:
	if on == _spyglass_up:
		return

	_spyglass_up = on

	if spyglass_look.is_valid():
		spyglass_look.call(on, held_slot, int(_inv.table.entry(held_id()).get("tier", 1)) if on else 0)


func _is_bow() -> bool:
	return BowAim.shoots(_inv.table.entry(held_id())) and not _inv.is_broken(held_slot)   # a bow or a sling


func _is_placeable() -> bool:
	return str(_inv.table.entry(held_id()).get("kind", "")) == "placeable"


# True while a torch is the held item (the Dynasty body then crouch-walks with it, avatar_driver.gd).
# A torch in the left hand (the off hand's item is a torch): the third-person body takes the torch carry pose (Dave's infographic, 6 Nov 2026).
func torch_in_left() -> bool:
	return _inv != null and _left_number() != 0 and _off_class() == "torch"


func holding_torch() -> bool:
	return holding and _is_torch()


func _is_torch() -> bool:
	return str(_inv.table.entry(held_id()).get("tool_class", "")) == "torch"


# A torch that water or rain put out (its slot marked out, flame_rules.gd is_out): drawn as a torch with no flame or light.
func _held_torch_out() -> bool:
	return _is_torch() and _slot_out(held_slot)


# Whether the flame in a pack slot is out (a torch marked out, or a dark lantern).
func _slot_out(slot: int) -> bool:
	if _inv == null or slot < 0 or slot >= _inv.inventory.numbers.size() or _inv.inventory.numbers[slot] == 0:
		return false

	return FlameRules.is_out(_inv.table.entry(_inv.table.id_of(_inv.inventory.numbers[slot])), _inv.inventory.inst_of(slot))


# The pack slot of what the left hand shows (_left_number): the off hand's, or the main item drawn in the left hand.
func _left_slot() -> int:
	return off_slot if off_number() != 0 else held_slot


func _is_knife() -> bool:
	return str(_inv.table.entry(held_id()).get("tool_class", "")) == "knife"


# Any other tool or weapon (shovel, and every tool added later) is held too: it has a generic model and plays the "use" arm
# animation on left click, so nothing silently fails to be held.
func _is_other_tool() -> bool:
	var kind: String = str(_inv.table.entry(held_id()).get("kind", ""))
	var is_arrow: bool = str(BasicLook.entry(held_id()).get("shape", "")) == "arrow"   # arrows are "material" items but are held like a tool, not as a palm-sized look
	return (kind in ["tool", "weapon", "container"] or is_arrow) and not _is_spear() and not _is_torch() and not _is_knife() and not _is_axe()


func is_holdable(number: int) -> bool:
	if number == 0:
		return false

	var entry: Dictionary = _inv.table.entry(_inv.table.id_of(number))
	# Food of ANY item kind can be held and eaten: the check is on THIS item (it used the currently held slot, so crab apples, a "material", could not be taken in hand
	# unless something edible was already held: Dave, 31 Oct 2026).
	return str(entry.get("kind", "")) in ["tool", "weapon", "placeable", "container"] or _inv.is_edible_item(number) or entry.has("pipe_m") or entry.has("fitting")   # a pipe, tap or drip head is laid from the hand


# Food and small things with a stage-one look (data/items/looks.json) are carried in the palm, drawn as they lie on the ground.
func _is_look_item() -> bool:
	return BasicLook.has_look(held_id()) and not _is_spear() and not _is_axe() and not _is_torch() and not _is_knife() and not _is_other_tool() and not _is_placeable()


# An arrow in flight (Dave 10 Nov 2026: the shot showed nothing): the arrow's own look, its shaft (the look's x axis) turned to point along -Z,
# the way look_at aims a node.
func _make_arrow_model(arrow: int) -> Node3D:
	var root: Node3D = Node3D.new()
	var shaft: MeshInstance3D = MeshInstance3D.new()
	shaft.mesh = BasicLook.mesh_for(_inv.table.id_of(arrow))
	shaft.rotation = Vector3(0.0, PI * 0.5, 0.0)
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shaft)
	return root


func _make_look_model() -> Node3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = BasicLook.mesh_for(held_id())
	node.scale = Vector3.ONE * 1.8   # same enlargement as on the ground, so a berry is seen in the palm
	return node


# Anything in hand is a weapon (Dave 19 Nov 2026 play test: "I just tried to hit a pig with an axe and it is doing no damage"; "any thing in your
# hand should be able to be used as a weapon"): the animal drawn in front within the held item's reach (MeleeRules; the server's
# target_along rule: inside 0.6 m, or within about 35 degrees of the look), as [id, where it is drawn], else []. A left click then strikes it
# instead of the item's own use. `margin_m` asks for that much inside the reach (a predicted hit, _melee_strike).
var _melee_cfg: Dictionary = {}


func _animal_aimed(margin_m: float = 0.0) -> Array:
	var bare: bool = held_number() == 0   # empty hands punch (melee.json bare_hand, Dave 23 Nov 2026)

	if not animal_aim_rows.is_valid() or _camera == null or carrying_log or (not bare and _inv.is_broken(held_slot)):
		return []

	if _melee_cfg.is_empty():
		_melee_cfg = MeleeRules.load_config()

	var reach: float = float((_melee_cfg.get("bare_hand", {}) as Dictionary).get("reach_m", 1.8)) if bare else float(MeleeRules.blow(_inv.table.entry(held_id()), _melee_cfg)["reach_m"])
	var eye: Vector3 = _camera.global_position
	var look: Vector3 = -_camera.global_transform.basis.z
	var flat: Vector2 = Vector2(look.x, look.z).normalized()

	var best: Array = []
	var best_d: float = reach

	for row in animal_aim_rows.call():   # the nearest body, as server_animals.target_along takes
		var at: Vector3 = row[0]
		var to: Vector2 = Vector2(at.x - eye.x, at.z - eye.z)

		var body: float = float(row[2]) if (row as Array).size() > 2 else 0.0   # a blow reaches the body, not its middle (server_animals.target_along)
		var d: float = to.length() - body

		if d <= best_d and (to.length() < 0.6 or to.normalized().dot(flat) > 0.82) and absf(at.y - eye.y) < 3.5 and (row as Array).size() > 3:
			best_d = d
			best = [int(row[3]), at]

	if best.is_empty() or best_d > reach - margin_m:
		return []

	# A predicted blow is not shown through a wall, a fence or a roof (the server's blow_blocked drops it): anything solid between the eye and the body's middle.
	if margin_m > 0.0 and _camera.is_inside_tree():
		var mid: Vector3 = (best[1] as Vector3) + Vector3(0.0, PREDICT_MID_M, 0.0)

		if not _camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, mid)).is_empty():
			return []

	return best


# Feel (Dave 24 Nov 2026: "give as much control to the client as it takes to make them feel natural and fight like they should in a real great
# video game"; docs/design/ANIMAL_NETCODE.md "Plans" step 3): a blow this screen sees land shows at once. The client runs the server's own test
# (target_along, on the animals as drawn, which is where the server judges the blow: seen_ms) PREDICT_MARGIN_M inside the reach, at most once
# per the item's recover_ms and PREDICT_SLACK_MS (the server drops a faster blow unheard), with nothing solid in between, and emits blow_landing; the server's animal_hit for it then plays no
# second thud or flinch (animal_view.confirm_hit). The damage, the blood and the number still come only from the server.
const PREDICT_MARGIN_M := 0.2
const PREDICT_MID_M := 0.6        # the body's middle over its drawn point, for the wall check
const PREDICT_SLACK_MS := 100     # the server paces on arrival, not on the click: a blow just past recover_ms may reach it just inside after jitter
const STRIKE_RECOVER_MS := 600   # server_items STRIKE_COOLDOWN_MS: an item with no recover_ms of its own
signal blow_landing(id: int, at: Vector3)   # a blow this screen sees land on animal `id`, drawn at `at`
var _paced_ms: int = -100000   # when the last blow went that the server takes (it keeps the same clock: a blow inside recover_ms is dropped and does not restart it)


# One blow at the animal in front with whatever is in hand: the server checks the item, the reach and the pace, and answers a hit with hit_number.
func _melee_strike() -> void:
	var seen: Array = seen_ms.call() if seen_ms.is_valid() else [0, 0]   # protocol 155: the blow is judged where this screen showed the animals

	if report_now.is_valid():
		report_now.call()   # and from where we stand now, not the last report up to 0.2 s back (server_items strike_origin)

	_predict_blow()
	_net.inventory_action.rpc_id(1, Net.ACT_STRIKE, held_slot if held_number() != 0 else -1, int(seen[0]), int(seen[1]), -_camera.global_transform.basis.z)   # -1: a bare-handed punch


# The predicted landing of the blow being sent (see PREDICT_MARGIN_M): none for a rope or twine (it binds a bandit, server_items BIND_ITEMS) or
# inside the item's recover_ms of the last blow the server took, hit or miss.
func _predict_blow() -> void:
	if _melee_cfg.is_empty():
		_melee_cfg = MeleeRules.load_config()

	var bare: bool = held_number() == 0
	var recover: int = int((_melee_cfg.get("bare_hand", {}) as Dictionary).get("recover_ms", STRIKE_RECOVER_MS)) if bare else int(_inv.table.entry(held_id()).get("recover_ms", STRIKE_RECOVER_MS))
	var now: int = Time.get_ticks_msec()

	if now - _paced_ms < recover:
		return

	var slack: bool = now - _paced_ms < recover + PREDICT_SLACK_MS   # taken, but close enough to the pace that it may not be: not shown
	_paced_ms = now
	var aimed: Array = _animal_aimed(PREDICT_MARGIN_M)

	if not aimed.is_empty() and not slack and (bare or not held_id() in ["rope", "twine"]):
		blow_landing.emit(int(aimed[0]), aimed[1])


func _is_axe() -> bool:
	return str(_inv.table.entry(held_id()).get("tool_class", "")) in ["axe", "pick"] and not _inv.is_broken(held_slot)


# True while a tool action is going on (a swing, the pause between chained swings, the hit stop): nothing nearby is picked up meanwhile.
func tool_busy() -> bool:
	return _swing_t >= 0.0 or _pause_t > 0.0 or _stop_t > 0.0


# Passing out, fainted or waking (inventory_view.body_out): the hands are not the player's (Dave 25 Nov 2026, QA #19). A test's stand-in
# view without it is never out.
func _body_out() -> bool:
	return _inv != null and _inv.has_method("body_out") and _inv.body_out()


# One chop of an axe or pick. Holding the left button chains them (see _process): the next starts as the last one ends.
func _start_swing() -> void:
	if _body_out():
		return   # passing out, fainted or waking: no swing (Dave 25 Nov 2026, QA #19)

	_swing_t = 0.0
	_swing_hit = false
	_pause_t = 0.0
	swing_serial += 1
	_arm_play("swing_fp_down" if _aim_at_ground() else "swing_fp", _swing_length())   # no whoosh: only the blow sounds, when it lands (Dave 10 Nov 2026)


# True when the crosshair is on something lying on the ground (the ground, a log, a stump, a rock): the swing then comes overhead and down. A standing tree, or anything else upright, gets
# the sideways swing (Dave 2 Nov 2026). With nothing in reach it follows the look: well below the horizon is down.
func _aim_at_ground() -> bool:
	var from: Vector3 = _camera.global_position
	var look: Vector3 = -_camera.global_transform.basis.z
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + look * REACH_M))

	if hit.is_empty():
		return look.y < -0.5

	# A plant's collider carries its species (as in _dig_here): a standing tree or shrub is hit from the side. Everything else (the ground, a log, a stump, a rock) comes overhead.
	# No scan of the loaded plants here: that was done again at the impact and made each swing start cost as much as the blow.
	return not (hit["collider"] as Object).has_meta("species_ids")


# This tool's swing: the axe's wide chop, the pick axe's overhead arc (a hammer keeps its own short rhythm elsewhere).
func _swing_length() -> float:
	return PICK_SWING_S if _tool_class() == "pick" else SWING_S


func _hit_share() -> float:
	return PICK_HIT_AT if _tool_class() == "pick" else HIT_AT


# The tool's hit sounds (hit_sounds.gd TOOLS): a pick sounds as a pick, everything else that swings here as an axe.
func _hit_tool() -> String:
	return "pick" if _tool_class() == "pick" else "axe"


func _tool_class() -> String:
	return str(_inv.table.entry(held_id()).get("tool_class", ""))


# The clip the third-person body plays for the swing in progress ("" when none): `chop` for an axe, `pick_overhead` for a pick axe. Restart it when swing_serial changes.
# The seconds one swing lasts (the sound and the hit come at hit share of it); the third-person clip is played at clip length / this so it follows the swing's speed.
func work_seconds() -> float:
	return _swing_length()


func work_clip() -> String:
	if _swing_t < 0.0 or not holding:
		return ""

	return "pick_overhead" if _tool_class() == "pick" else "chop"



# Whether `kit` places a sloped roof panel (structures.json piece_kind "roof_panel"): its ghost rests on an edge and the wheel flips rise and fall.
func _is_roof_panel(kit: String) -> bool:
	return str(PlacementRules.structure_of_kit(_placement, kit).get("piece_kind", "")) == PlacementRules.ROOF_PANEL_KIND


# Whether `kit` places a roof corner (piece_kind "roof_hip", A-37): it rests where two edges meet and the wheel picks its 45 or 65 shape when no panel is beside it.
func _is_roof_hip(kit: String) -> bool:
	return str(PlacementRules.structure_of_kit(_placement, kit).get("piece_kind", "")) == PlacementRules.ROOF_HIP_KIND


# The mouse wheel while a foundation is held raises or lowers where it will stand, in 0.1 m steps. Returns true when it was used here.
func wheel(down: bool) -> bool:
	if _hoe_menu_open:
		_hoe_menu_index = posmod(_hoe_menu_index + (1 if down else -1), maxi(1, _hoe_menu_size()))
		_hoe_menu_refresh()
		return true

	if _hoe_grid_on():   # the hoe grid: the wheel turns it a little, "so you can line up your gardens" (Dave 14 Nov 2026)
		garden_yaw = posmod(garden_yaw + (FarmRules.GRID_TURN_DEG if down else -FarmRules.GRID_TURN_DEG), 360)
		_inv._on_notice("Hoe grid turned to %d degrees" % garden_yaw)
		return true

	if _blueprinting():
		var picked_def: Dictionary = PlacementRules.structure_of_kit(_placement, blueprints.kit_of(blueprints.picked))

		if bool(picked_def.get("foundation", false)):
			if _ghost_on_base:
				_inv._on_notice("This foundation matches the one beside it: the wheel only lifts a foundation with no neighbour")
				return true

			lift_steps = clampi(lift_steps + (-1 if down else 1), 0, PlacementRules.LIFT_MAX_STEPS)
			_inv._on_notice("Foundation raised %.1f m off the ground" % (float(lift_steps) * PlacementRules.LIFT_STEP_M))
			return true

		if str(picked_def.get("piece_kind", "")) == PlacementRules.ROOF_PANEL_KIND:
			lift_steps = 1 - clampi(lift_steps, 0, 1)   # the wheel flips which end rests on the edge: the low one (the panel rises from it) or the high one (it falls)
			_inv._on_notice("Roof panel rests on its %s end and %s from the edge" % [("high" if lift_steps == 1 else "low"), ("falls" if lift_steps == 1 else "rises")])
			return true

		if str(picked_def.get("piece_kind", "")) == PlacementRules.ROOF_HIP_KIND:
			lift_steps = 1 - clampi(lift_steps, 0, 1)   # the corner's shape where no panel stands beside it yet (a panel beside it decides)
			_inv._on_notice("Roof corner at %d degrees where no roof panel is beside it (a panel beside it sets the slope)" % (65 if lift_steps == 1 else 45))
			return true

		return false

	if not holding or not _is_placeable():
		return false

	var def: Dictionary = PlacementRules.structure_of_kit(_placement, held_id())

	if bool(def.get("foundation", false)):
		if _ghost_on_base:
			_inv._on_notice("This foundation matches the one beside it: the wheel only lifts a foundation with no neighbour")
			return true

		lift_steps = clampi(lift_steps + (-1 if down else 1), 0, PlacementRules.LIFT_MAX_STEPS)
		_inv._on_notice("Foundation raised %.1f m off the ground" % (float(lift_steps) * PlacementRules.LIFT_STEP_M))
		return true

	return _cycle_variant(def, down)


# Wall pieces of one group (wall, doorway, window) are one piece to the wheel: it turns through the kinds you carry, and the held tier is the
# one in the hotbar (Dave 2026-10-22). The ghost and the click use the chosen pack slot.
func _cycle_variant(def: Dictionary, down: bool) -> bool:
	var group: String = str(def.get("variant_group", ""))

	if group == "":
		return false

	var slots: Array = []

	for slot in range(_inv.inventory.numbers.size()):
		var other: Dictionary = PlacementRules.structure_of_kit(_placement, _inv.table.id_of(_inv.inventory.numbers[slot]))

		if not other.is_empty() and str(other.get("variant_group", "")) == group and (slot == held_slot or _inv.table.id_of(_inv.inventory.numbers[slot]) != held_id()):
			slots.append(slot)

	if slots.size() < 2:
		return true

	var at: int = maxi(slots.find(variant_slot if variant_slot >= 0 else held_slot), 0)
	variant_slot = slots[posmod(at + (-1 if down else 1), slots.size())]
	_inv._on_notice("Piece: %s" % _inv.table.name_of(_inv.inventory.numbers[variant_slot]))
	return true


# The pack slot the ghost and the place click use: the wheel's chosen variant while it still holds a piece of the held group, else the held slot.
func _place_slot() -> int:
	if variant_slot >= 0 and variant_slot < _inv.inventory.numbers.size() and _inv.inventory.numbers[variant_slot] != 0:
		var group: String = str(PlacementRules.structure_of_kit(_placement, held_id()).get("variant_group", ""))

		if group != "" and str(PlacementRules.structure_of_kit(_placement, _inv.table.id_of(_inv.inventory.numbers[variant_slot])).get("variant_group", "")) == group:
			return variant_slot

	variant_slot = -1
	return held_slot


func _placing_id() -> String:
	if _blueprinting():
		return blueprints.kit_of(blueprints.picked)

	return _inv.table.id_of(_inv.inventory.numbers[_place_slot()])


# A mouse button while playing. Returns true when it was used here.
func mouse_button(button: int, pressed: bool) -> bool:
	if button == MOUSE_BUTTON_RIGHT and pressed and held_number() != 0 and _inv.edible_slot(held_slot):   # nothing to eat in a hand that steadies a log
		_inv.eat_slot(held_slot)
		return true

	# Right click with a hammer or a knife opens its build screen (Dave 16 Nov 2026; the knife's list, Dave 15 Nov 2026); the screen takes the clicks
	# while it is open (hammer_blueprints.gd: a click on a row picks it, right click shuts it). Shift is left to other tools.
	if button == MOUSE_BUTTON_RIGHT and pressed and holding and _build_tier() > 0:
		toggle_blueprints()
		return true

	# Right click with a torch in the left hand and nothing in the right that uses right click: stick the torch in the ground or on a wall (Dave, 4 Nov 2026).
	if button == MOUSE_BUTTON_RIGHT and pressed and not blueprints.is_open and _right_hand_free() and _torch_hand_slot() >= 0:
		_place_torch_here()
		return true

	# A left click at an animal in reach strikes it with whatever is in hand (Dave 19 Nov 2026). The axe and pick strike at the impact of their
	# swing (_strike); a spear jabs and a bow shoots as before; placing a piece or a blueprint, the hoe's list and the build screen keep their click.
	if button == MOUSE_BUTTON_LEFT and pressed and not _is_axe() and not _is_spear() and not _is_bow() and not _blueprinting() and not _is_placeable() and not _pipe_hand() and not _hoe_menu_open and not blueprints.is_open and not _animal_aimed().is_empty():
		_arm_play("use", 0.6)
		_melee_strike()
		return true

	if _pipe_hand():
		return _pipe_click(button, pressed)

	if holding and _hammer_tier() > 0 and (blueprints.mode == "save" or blueprints.mode == "repair"):
		if button == MOUSE_BUTTON_LEFT and pressed:
			if blueprints.mode == "repair" and _boulder_aimed():   # Hammer/Repair Tool (Dave 15 Nov 2026): a boulder in reach is struck for stone and ore, never repaired
				if _swing_t < 0.0:
					_start_swing()
			elif blueprints.mode == "repair":
				_repair_here()
			else:
				_save_plan_here()

		return button == MOUSE_BUTTON_LEFT

	if _blueprinting():
		if button == MOUSE_BUTTON_LEFT and pressed and _blueprint_ok:
			if blueprints.plan_picked >= 0:
				_start_plan_place()
			else:
				_net.inventory_action.rpc_id(1, Net.ACT_PLACE_BLUEPRINT, blueprints.picked, lift_steps, _blueprint_yaw, _blueprint_at)
		elif button == MOUSE_BUTTON_LEFT and pressed:
			_say_why_not()

		return button == MOUSE_BUTTON_LEFT

	if _is_placeable():
		if button == MOUSE_BUTTON_LEFT and pressed and _blueprint_ok:
			_net.inventory_action.rpc_id(1, Net.ACT_PLACE, _place_slot(), lift_steps, _blueprint_yaw, _blueprint_at)
		elif button == MOUSE_BUTTON_LEFT and pressed:
			_say_why_not()

		return button == MOUSE_BUTTON_LEFT

	if _is_axe():
		if button == MOUSE_BUTTON_RIGHT and pressed:
			_net.inventory_action.rpc_id(1, Net.ACT_ICEHOLE, held_slot, 0, 0, Vector3.ZERO)
			_arm_play("use", 0.6)
			return true

		if button == MOUSE_BUTTON_LEFT and pressed and _swing_t < 0.0:
			_start_swing()

		return button == MOUSE_BUTTON_LEFT

	if holding and _is_spyglass():
		if button == MOUSE_BUTTON_RIGHT:
			_look_spyglass(pressed)
			return true

		return false

	if _is_bow():
		# Dave 10 Nov 2026: hold the right button to raise the bow to sight and draw; left click looses at the aim; letting right go lowers it, no shot.
		if button == MOUSE_BUTTON_RIGHT:
			if pressed:
				_raise_bow()
			else:
				_lower_bow()

			return true

		if button == MOUSE_BUTTON_LEFT:
			if pressed and _draw_t >= 0.0:
				_loose()

			return true

		return false

	if _is_other_tool():
		# The shore net (Dave 2 Nov 2026): a click throws it onto the water NET_THROW_M ahead; the server pulls it back after a few seconds
		# (walking off loses the throw). Releasing the button does nothing.
		if button == MOUSE_BUTTON_LEFT and str(_inv.table.entry(held_id()).get("tool_class", "")) == "net":
			if pressed:
				_arm_play("use", 0.6)
				_net.inventory_action.rpc_id(1, Net.ACT_NET, held_slot, 0, 0, net_landing(_camera.global_position, -_camera.global_transform.basis.z))

			return true

		# Right click with the shovel switches between Dig and Raise mode (Dave 2026-10-22).
		if button == MOUSE_BUTTON_RIGHT and pressed and str(_inv.table.entry(held_id()).get("tool_class", "")) == "shovel":
			raise_mode = not raise_mode
			_inv._on_notice("Raise mode: left click adds ground, using soil or stone from your pack" if raise_mode else "Dig mode: left click digs")
			return true

		# The garden hoe (Dave 2 Nov 2026): left click applies whatever mode the hoe is set to; right click opens a window to pick the mode
		# (wheel moves, left click chooses, right click closes). Shift + right click still sets grade points A and B in any mode.
		if (button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT) and str(_inv.table.entry(held_id()).get("tool_class", "")) == "hoe":
			if not pressed:
				return false

			if _hoe_menu_open:
				if button == MOUSE_BUTTON_LEFT:
					_hoe_menu_choose()   # closes the list, or goes on to the plant list
				else:
					_hoe_menu_back()   # the plant list goes back to the actions; the actions close

				return true

			if button == MOUSE_BUTTON_RIGHT:
				if Input.is_key_pressed(KEY_SHIFT):
					_arm_play("use", 0.6)
					_grade_point_here()
				else:
					_hoe_menu_open_now("garden" if hoe_mode == "garden" else "modes")   # Plant: right click goes back to choosing the plant (BugsList entry 6)

				return true

			_arm_play("use", 0.6)
			_hoe_apply()
			return true

		# Left click with a sickle or scythe (Dave 18 Nov 2026, BugsList_Current.md entry 7): one swing gathers the grasses and ripe grain and cuts down the
		# bushes round the player, within 1.5 m for the sickle and 3 m for the scythe (drops.json swath); the server rules on every plant.
		if button == MOUSE_BUTTON_LEFT and pressed and str(_inv.table.entry(held_id()).get("tool_class", "")) in ["sickle", "scythe"]:
			_arm_play("use", 0.6)

			if swath_cut.is_valid():
				swath_cut.call(held_slot, str(_inv.table.entry(held_id()).get("tool_class", "")))

			return true

		# Left click with a saw (Dave 17 Nov 2026): the crafting screen opens on the Carpenter's tab, what the saw makes; Craft takes the log from near you.
		if button == MOUSE_BUTTON_LEFT and pressed and str(_inv.table.entry(held_id()).get("tool_class", "")) == "saw":
			_inv.open_crafting_on(SAW_CATEGORY)
			return true

		if button == MOUSE_BUTTON_LEFT and pressed:
			_arm_play("use", 0.6)

			if str(_inv.table.entry(held_id()).get("tool_class", "")) == "shovel":
				if raise_mode:
					_fill_here()
				else:
					_dig_here()
			elif str(_inv.table.entry(held_id()).get("tool_class", "")) == "rod":
				_net.inventory_action.rpc_id(1, Net.ACT_FISH, held_slot, 0, 0, _camera.global_position - _camera.global_transform.basis.z * 4.0)
				_cast_at = _camera.global_position - _camera.global_transform.basis.z * 4.0   # where the line went in (the server's cast point)
				_cast_msec = Time.get_ticks_msec()

				if _sound != null:
					_sound.slots.play("net_cast", _camera.global_position - _camera.global_transform.basis.z * 2.0)   # shortcut: the shore-net throw clip stands in for the rod cast until a line-cast clip exists (Jason, 2 Nov 2026; to hear)
			else:
				_inv._on_notice(_other_tool_hint())

		return button == MOUSE_BUTTON_LEFT

	if _is_knife():
		if button == MOUSE_BUTTON_LEFT and pressed:
			var carcass: int = _inv.carcass_near(_camera.global_position)

			if carcass != 0:
				_arm_play("use", 0.6)

				if _sound != null:
					_sound.spear.hit("flesh", (_inv._world[carcass]["pos"] as Vector3) + Vector3(0.0, 0.3, 0.0), _sound.KNIFE_CUT_STRENGTH)   # the cut is heard (others hear it too: action_cue)

				_net.inventory_action.rpc_id(1, Net.ACT_PROCESS, carcass, 0, 0, Vector3(float(held_slot + 1), 0.0, 0.0))   # the knife in hand (protocol 117)
				return true

		return false

	# A dug-up bush (<species>_bush): left click plants it on the ground under the crosshair (Dave 2 Nov 2026).
	if holding and held_id().ends_with("_bush"):
		if button == MOUSE_BUTTON_LEFT and pressed:
			_plant_here()

		return button == MOUSE_BUTTON_LEFT

	if not _is_spear():
		aiming = false
		return false

	if button == MOUSE_BUTTON_RIGHT:
		aiming = pressed and not _is_fish_spear()
		return true

	if button == MOUSE_BUTTON_LEFT and pressed:
		if aiming:
			_throw()
		elif _jab_t < 0.0:
			_jab_t = 0.0
			_arm_play("jab", JAB_S)
			_net.inventory_action.rpc_id(1, Net.ACT_FISH, held_slot, 0, 0, _camera.global_position - _camera.global_transform.basis.z * 2.5 - Vector3(0.0, 1.2, 0.0))
			if not _is_fish_spear():
				var seen_b: Array = seen_ms.call() if seen_ms.is_valid() else [0, 0]   # protocol 155

				if report_now.is_valid():
					report_now.call()   # judged from where we stand now (server_items strike_origin)

				_predict_blow()
				_net.inventory_action.rpc_id(1, Net.ACT_STRIKE, held_slot, int(seen_b[0]), int(seen_b[1]), -_camera.global_transform.basis.z)

			if _sound != null:
				_sound.spear.jab(_camera.global_position - _camera.global_transform.basis.z)

		return true

	return false


# Where the rod's float sits, for the bite's splash (23 Nov 2026: it sounded 1.5 m in front of the angler): the last cast's point, at the
# feet's height (the water's face, near enough), while it is recent and near the angler at `feet_near`; INF otherwise.
func float_point(feet_near: Vector3) -> Vector3:
	if not _cast_at.is_finite() or Time.get_ticks_msec() - _cast_msec > CAST_KEEP_MS or Vector2(_cast_at.x - feet_near.x, _cast_at.z - feet_near.z).length() > CAST_NEAR_M:
		return Vector3.INF

	return Vector3(_cast_at.x, feet_near.y - 0.8, _cast_at.z)


# Just before a shot or a throw: the server ms this screen shows the animals at (ACT_SEEN), so the flight is judged where this player sees them.
func _send_seen() -> void:
	if seen_ms.is_valid():
		var seen: Array = seen_ms.call()
		_net.inventory_action.rpc_id(1, Net.ACT_SEEN, 0, int(seen[0]), int(seen[1]), Vector3.ZERO)


func _throw() -> void:
	_arm_play("throw", 0.8)
	var direction: Vector3 = -_camera.global_transform.basis.z
	_send_seen()
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


# The arrow seen leaving the bow and its thunk where it should come down: the server's flight (data/items/bow.json: power from the draw time,
# speed_max x power, gravity, range_m) followed here to draw it and to place and time the sound. A hit on an animal thuds through hit_number
# instead; the server's spread may turn the real arrow a little from this one.
const CAST_KEEP_MS := 180000        # a rod cast this long ago is still where the float is (float_point)
const CAST_NEAR_M := 8.0             # and only while the angler stands by it
var _cast_at: Vector3 = Vector3.INF
var _cast_msec: int = 0
const SEEN_ARROW_RANGE_M := 200.0   # another player's arrow: its bow is not known here, so it is flown until it lands (the 6 s cap)
const ARROW_STUCK_SHOW_S := 1.5   # the flown arrow stays where it hit this long; the server's stuck arrow is drawn by then


# The first solid thing (a tree trunk's collider, the ground, a wall) on a flight step, or {} (a physics ray, so it needs the world).
func _flight_hit(from: Vector3, to: Vector3) -> Dictionary:
	if _camera == null or not _camera.is_inside_tree() or from.distance_to(to) < 0.0001:
		return {}

	return _camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))


# Another player's arrow or thrown weapon (flight_seen, protocol 159): flown here like this player's own (gravity, the ground, an arrow
# stops in a trunk), look only. A thrown weapon (items.json kind "weapon") is drawn by its hand look, an arrow by its arrow model.
func add_seen_flight(number: int, from: Vector3, velocity: Vector3, fire: bool) -> void:
	if _root == null or not _root.is_inside_tree() or _inv == null or number <= 0 or velocity.length() < 0.1:
		return

	var id: String = _inv.table.id_of(number)
	var arrow: bool = str(_inv.table.entry(id).get("kind", "")) != "weapon"
	var node: Node3D = _make_arrow_model(number) if arrow else (look_tool_node(id) if BasicLook.has_look(id) and HELD_LOOK_TURN.has(str(BasicLook.entry(id).get("shape", ""))) else _make_arrow_model(number))
	_root.add_child(node)
	node.global_position = from + velocity.normalized() * 0.8

	if absf(velocity.normalized().y) < 0.99:
		node.look_at(node.global_position + velocity, Vector3.UP)

	if fire:
		var glow: OmniLight3D = OmniLight3D.new()   # as this player's own fire arrow
		glow.light_color = Color(1.0, 0.55, 0.15)
		glow.light_volumetric_fog_energy = 0.0   # a short glow on the wing: no orange flare in the volumetric fog
		glow.light_energy = 1.6
		glow.omni_range = 2.0
		glow.shadow_enabled = false
		node.add_child(glow)

	_flights.append({"node": node, "vel": velocity, "age": 0.0, "arrow": true})

	# Heard as well as seen (23 Nov 2026, the coordinator's silent-sounds pass: another player's shot or throw made no sound): the bow's
	# twang where it was loosed and the thunk where it comes down, or a thrown weapon's heave, its flight and its landing, as this
	# player's own. A hit on an animal thuds through animal_hit for everyone already.
	if _sound != null:
		if arrow:
			_sound.slots.play("bow_loose", from)
			var landed: Array = _arrow_landing(node.global_position, velocity, SEEN_ARROW_RANGE_M)
			_sound.spear.arrow(landed[0], landed[1], landed[2])
		else:
			var landing: Vector3 = _predict_landing(node.global_position, velocity)
			_sound.spear.throw(node.global_position, landing, velocity.length(), "wood" if _tree_near.is_valid() and not _tree_near.call(landing).is_empty() else "soil")


func _arrow_flight(draw_ms: int, direction: Vector3, arrow: int) -> void:
	_bow_config()
	var bow_id: String = held_id()
	var v: Vector3 = direction * BowAim.bow_speed_max(_bow_cfg, bow_id) * (1.0 if BowAim.full_power(_bow_cfg, bow_id) else bow_power(draw_ms, _bow_cfg))   # a crossbow leaves at full power
	var node: Node3D = _make_arrow_model(arrow)
	_root.add_child(node)
	node.global_position = _camera.global_position + direction * 0.8
	_flights.append({"node": node, "vel": v, "age": 0.0, "arrow": true})

	if bool(_inv.table.entry(_inv.table.id_of(arrow)).get("fire", false)) and _inv._lit_fire_near(_camera.global_position, float(_bow_cfg.get("fire_arrow", {}).get("light_m", 3.0))):
		var glow: OmniLight3D = OmniLight3D.new()   # a burning fire arrow (Part C plan 6): a stand-in orange glow until Kathleen's flame look
		glow.light_color = Color(1.0, 0.55, 0.15)
		glow.light_volumetric_fog_energy = 0.0   # a short glow on the wing: no orange flare in the volumetric fog
		glow.light_energy = 1.6
		glow.omni_range = 2.0
		glow.shadow_enabled = false
		node.add_child(glow)

	if _sound == null:
		return

	var landed: Array = _arrow_landing(_camera.global_position, v, BowAim.bow_range_m(_bow_cfg, bow_id))
	_sound.spear.arrow(landed[0], landed[1], landed[2])


# Where and when an arrow flown from `from` at `velocity` comes down (within range_m of flight, 6 s at most), and what it thunks into:
# [point, seconds, "wood" or "soil"]. Something upright on the way (a trunk's collider, a wall) stops it as wood.
func _arrow_landing(from: Vector3, velocity: Vector3, range_m: float) -> Array:
	var at: Vector3 = from
	var v: Vector3 = velocity
	var flown: float = 0.0
	var t: float = 0.0
	var into_wood: bool = false

	while t < 6.0 and flown < range_m:
		v.y -= THROW_GRAVITY * 0.05
		flown += (v * 0.05).length()
		var step_hit: Dictionary = _flight_hit(at, at + v * 0.05)

		if not step_hit.is_empty() and absf(float((step_hit["normal"] as Vector3).y)) < 0.7:   # something upright, a trunk: the arrow thunks into wood
			t += 0.05 * at.distance_to(step_hit["position"]) / maxf((v * 0.05).length(), 0.001)
			at = step_hit["position"]
			into_wood = true
			break

		at += v * 0.05
		t += 0.05
		var ground: float = _ground_below.call(at)

		if not is_nan(ground) and at.y <= ground:
			at.y = ground
			break

	return [at, t, "wood" if into_wood or (_tree_near.is_valid() and not _tree_near.call(at).is_empty()) else "soil"]


# The shot's power from the draw time, as the server works it out (bow.json): a draw under draw_min_ms is weak_power, then
# min_power rising to 1 at draw_max_ms.
static func bow_power(draw_ms: int, cfg: Dictionary) -> float:
	var lo: float = float(cfg.get("draw_min_ms", 300))
	var hi: float = float(cfg.get("draw_max_ms", 1200))

	if draw_ms < lo:
		return float(cfg.get("weak_power", 0.25))

	var k: float = clampf((float(draw_ms) - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
	return lerpf(float(cfg.get("min_power", 0.5)), 1.0, k)


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
	_hang_net()
	_report_held(delta)

	_update_bow(delta)

	if _spyglass_up and (not holding or not _is_spyglass() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		_look_spyglass(false)   # put away, broken, or the button let go while the mouse was elsewhere

	_update_blueprint()
	_hammer_stock(delta)
	_plan_step()
	_garden_preview()
	_survey_line()
	_pipe_mode()
	_hoe_repeat(delta)

	if _sound != null:
		var flame_kind: String = "" if _slot_out(held_slot) else str(_inv.table.entry(held_id()).get("tool_class", ""))   # a torch that went out is silent

		if flame_kind not in ["torch", "lantern"]:
			flame_kind = "" if _slot_out(off_slot) else _off_class()

		var flame: bool = flame_kind in ["torch", "lantern"]
		var sheltered: bool = flame and _cover_at.is_valid() and bool(_cover_at.call(_camera.global_position))    # the cover lookup only when a flame is held
		_sound.flame.set_held(flame_kind if flame else "", not sheltered)

	_show_model()
	_show_off_model(delta)
	_caption_age += delta

	if _caption_age >= 0.1 or _caption_held != held_number() or _caption_off != off_number():
		_caption_age = 0.0
		_caption_held = held_number()
		_caption_off = off_number()
		_label.text = _caption()    # built ten times a second, not every frame (it reads the item table and builds strings)

	if _inv != null:
		_label.offset_bottom = -LABEL_ABOVE    # above the hotbar tray, which keeps its place at any text size (Dave, build 617: they overlapped)

	# The bow's pose from the draw (right button held: raised, then fully drawn over bow.json draw_max_ms): bow_state() and bow_draw(); _pose_bow is the one
	# entry point. The shot runner can set the pose (bow_force).
	# The arms are placed first, so the bow is put in the hands where they are this frame, not where they were the frame before (Dave, build 826: the bow sat
	# "awkwardly shaking").
	_place_arms(delta)
	_pose_bow(bow_state(), bow_draw(), delta)
	_aim_spear()

	if _arms != null and _arms.visible and _arms.current() != "idle" and not _arms.is_one_shot_playing() and not _bow_posing():
		_arms.play("idle")

	# Hit stop: the animation freezes for a moment at the impact (Tyler Report 26), then goes on.
	if _stop_t > 0.0:
		_stop_t -= delta

		if _stop_t <= 0.0 and _arms != null:
			_arms.animation_player.speed_scale = 1.0

	if _swing_t >= 0.0 and _body_out():
		_swing_t = -1.0   # a swing under way when the player passes out never lands (Dave 25 Nov 2026, QA #19: "they must stop the second ...")
		_stop_t = 0.0

		if _arms != null:
			_arms.animation_player.speed_scale = 1.0

	if _swing_t >= 0.0 and _stop_t <= 0.0:
		_swing_t += delta

		if not _swing_hit and _swing_t >= _swing_length() * _hit_share():
			_swing_hit = true
			_strike()
			_stop_t = HIT_STOP_S

			if _arms != null and _arms.visible:
				_arms.animation_player.speed_scale = 0.0

		if _swing_t >= _swing_length():
			_swing_t = -1.0
			_pause_t = SWING_PAUSE_S

	if _swing_t < 0.0 and _pause_t > 0.0:
		_pause_t -= delta

		# Dave 2026-10-21: holding the button keeps chopping, one swing after another (a short pause between, 31 Oct 2026).
		if _pause_t <= 0.0 and holding and (_is_axe() or (_hammer_tier() > 0 and blueprints.mode == "repair" and not blueprints.is_open and _boulder_aimed())) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_start_swing()

	# The jab runs on its own clock whatever draws the spear (TEST-004, 12 Nov 2026): it was only advanced in the no-arms branch below, so with
	# the arms (always) the first jab never ended and every later click was refused.
	var jab_u: float = -1.0

	if _jab_t >= 0.0:
		_jab_t += delta
		jab_u = clampf(_jab_t / JAB_S, 0.0, 1.0)

		if _jab_t >= JAB_S:
			_jab_t = -1.0

	if _model != null and _is_torch():
		var flicker: OmniLight3D = _model.get_node_or_null("Light")

		if flicker != null:
			# Own light: one, shadowless. At Low it gives way to a fire light within 8 m, so no more than one lamp lights the same spot.
			flicker.visible = rig_lit or not held_light_budget.is_valid() or held_light_budget.call() or not _inv.fire_light_near(_camera.global_position, 8.0)
			flicker.light_energy = FlameRules.TORCH_LIGHT_ENERGY + FlameRules.TORCH_LIGHT_FLICKER * sin(float(Time.get_ticks_msec()) * 0.017)

		if not _mounted:
			_model.position = _model.position.lerp(REST, clampf(delta * 14.0, 0.0, 1.0))
	elif _model != null and _mounted:
		pass   # in the hand: the arm animation moves it
	elif _model != null and _is_knife():
		_model.position = _model.position.lerp(REST, clampf(delta * 14.0, 0.0, 1.0))
	elif _model != null and _is_axe():
		var u: float = clampf(_swing_t / _swing_length(), 0.0, 1.0) if _swing_t >= 0.0 else 0.0
		var arc: float = sin(u * PI)
		_model.position = _model.position.lerp(REST + Vector3(-0.1 * arc, -0.15 * arc, -0.2 * arc), clampf(delta * 20.0, 0.0, 1.0))
		_model.rotation.x = lerpf(_model.rotation.x, deg_to_rad(70.0) * (1.0 - 2.0 * u) if _swing_t >= 0.0 else deg_to_rad(20.0), clampf(delta * 20.0, 0.0, 1.0))
	elif _model != null:
		var target: Vector3 = AIMED if aiming else REST
		var offset: Vector3 = target

		if _draw_t >= 0.0:
			offset += Vector3(0.0, 0.0, minf(_draw_t, 1.2) * 0.1)   # the hand comes back as the string is drawn

		if jab_u >= 0.0:
			offset += Vector3(0.0, 0.0, -JAB_REACH * sin(jab_u * PI))

		_model.position = _model.position.lerp(offset, clampf(delta * 14.0, 0.0, 1.0))
		_model.rotation.x = lerpf(_model.rotation.x, deg_to_rad(35.0) if aiming else 0.0, clampf(delta * 14.0, 0.0, 1.0))

	for flight in _flights.duplicate():
		if flight.has("stuck_left"):   # an arrow that hit something waits there until the server's stuck arrow is drawn
			flight["stuck_left"] = float(flight["stuck_left"]) - delta

			if float(flight["stuck_left"]) <= 0.0:
				flight["node"].queue_free()
				_flights.erase(flight)

			continue

		flight["vel"].y -= THROW_GRAVITY * delta
		var was: Vector3 = flight["node"].global_position
		flight["node"].global_position += flight["vel"] * delta
		flight["age"] += delta

		if bool(flight.get("arrow", false)):
			var hit: Dictionary = _flight_hit(was, flight["node"].global_position)

			if not hit.is_empty():   # a trunk or anything solid: the arrow stops in it, as the server's does (Dave 10 Nov 2026)
				flight["node"].global_position = hit["position"]
				flight["stuck_left"] = ARROW_STUCK_SHOW_S
				continue

		if bool(flight.get("arrow", false)) and (flight["vel"] as Vector3).length() > 0.1:
			flight["node"].look_at(flight["node"].global_position + flight["vel"], Vector3.UP)   # an arrow points along its flight
		var ground: float = _ground_below.call(flight["node"].global_position) if _ground_below.is_valid() else NAN

		if flight["age"] > 6.0 or (not is_nan(ground) and flight["node"].global_position.y <= ground):
			flight["node"].queue_free()
			_flights.erase(flight)


# The large log on the shoulder in first person (Dave 2026-10-21): across the right shoulder, fixed to the body (the way you face), so it
# shows at the edge of the view and when you look down.
# `second`: the colour of a second log carried beside it (TREE_WOOD_TOOLS_DESIGN.md s1.2, two logs at most), null for one.
func set_shoulder(on: bool, length: float, radius: float, color: Color = Color(0.32, 0.23, 0.15), second: Variant = null) -> void:
	if not on:
		if _shoulder_log != null:
			_shoulder_log.visible = false

		if _shoulder_log_two != null:
			_shoulder_log_two.visible = false

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
	(mesh.material as StandardMaterial3D).albedo_color = color
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = length
	_shoulder_log.visible = true
	var yaw: Basis = Basis(Vector3.UP, _camera.global_rotation.y)
	var at: Vector3 = _camera.global_position + yaw * Vector3(SHOULDER_LOG_X, -0.55, -SHOULDER_LOG_FWD)
	_shoulder_log.global_transform = Transform3D(yaw * Basis(Vector3.RIGHT, PI * 0.5 + 0.05), at)

	if not (second is Color):
		if _shoulder_log_two != null:
			_shoulder_log_two.visible = false

		return

	if _shoulder_log_two == null:
		_shoulder_log_two = MeshInstance3D.new()
		_shoulder_log_two.mesh = mesh
		_shoulder_log_two.material_override = StandardMaterial3D.new()
		_shoulder_log_two.top_level = true
		_shoulder_log_two.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_camera.add_child(_shoulder_log_two)

	(_shoulder_log_two.material_override as StandardMaterial3D).albedo_color = second
	_shoulder_log_two.visible = true
	var beside: Vector3 = _camera.global_position + yaw * Vector3(SHOULDER_LOG_X - radius * 2.2, -0.55, -SHOULDER_LOG_FWD)   # side by side, on the side toward the middle of the view
	_shoulder_log_two.global_transform = Transform3D(yaw * Basis(Vector3.RIGHT, PI * 0.5 + 0.05), beside)


# The arms follow the body at rest and the camera while working: blends the two poses by _arm_up.
func _place_arms(delta: float) -> void:
	if _arms == null or not _arms.visible:
		return

	var working: bool = _swing_t >= 0.0 or _jab_t >= 0.0 or aiming or _bow_up or _arms.is_one_shot_playing()
	_arm_up = ArmsView.next_arm_up(_arm_up, working, ARMS_FOLLOW_K, delta)
	_arms.transform = ArmsView.arms_transform(_camera.global_transform, _camera.global_rotation.y, _arm_up, REST_PITCH_DEG, REST_DOWN_M, REST_BACK_M, ARMS_POS, ARMS_PITCH_DEG, ARMS_SCALE)

	if _bow_up:
		_arms.transform.origin += Vector3(BOW_SIGHT_RIGHT_M * _arm_up, 0.0, 0.0)   # the bow off the line of sight, to the right (BugsList 180); _pose_bow places the bow at this hand


# The bow in the hands (Dave 10 Nov 2026: "have art department fix how its held because it isnt right"). A right-handed archer: the LEFT hand holds the grip, the right
# hand draws the string. state is "idle" (held, not in use), "raised" (the right hand on the string, drawing by `draw`) or "drawn" (the string at the jaw); draw is
# 0 to 1, how far the string is back. First person, in every state: both hands on the bow, ready to shoot (Dave 10 Nov 2026: "you should have an arrow notched
# holding the bow with both hands like you are ready to shoot", "before you draw back the string"). The arms hold bow_draw at `draw` (ragdoll_body.gd; idle is draw
# 0, the string at rest), the bow stands upright before the view with a slight cant at the left hand, the string's middle follows the right hand and the arrow is
# nocked. The pose is held still (seek every frame, no sway), the bow placed after the arms. Third person: the bow hangs at the side in the left hand, upright in
# the world (the body has no bow draw yet). Nothing else in this file reads the pose: Steve's bow code calls this with its own state.
func _pose_bow(state: String, draw: float, _delta: float) -> void:
	if bow_force != "":
		state = bow_force.get_slice(":", 0)
		draw = clampf(float(bow_force.get_slice(":", 1)) if bow_force.contains(":") else (1.0 if state == "drawn" else 0.0), 0.0, 1.0)

	var bow: bool = _model != null and _model.has_meta("bow") and _model.is_inside_tree()
	_bow_up = bow and _first_person

	if _off_model != null:
		_off_model.visible = not bow    # both hands are on the bow: a torch or shield in the left hand is put away while it is held

	if _arms != null and _arms.has_method("set_grip"):
		_arms.set_grip(bow and _first_person)   # Dave's hands close round the grip and hook the string (dynasty_arms.gd "grip"); open for anything else

	if not bow:
		return

	var mount: Node3D = _model.get_parent() as Node3D

	if mount == null or mount == _camera:
		return     # no arms: the bow keeps the plain spot before the camera

	if _first_person and _arms != null and _arms.visible:
		if _arms.current() != "bow_draw":
			_arms.play("bow_draw")   # held at the draw below: seek() every frame sets the pose, the clip's own play only blends it in

		_arms.animation_player.seek(clampf(draw if state != "idle" else 0.0, 0.0, 1.0) * _arms.animation_player.get_animation("bow_draw").length * 0.999, true)

	var view: Basis = _camera.global_basis.orthonormalized()
	var up: Vector3
	var back: Vector3      # the back of the bow faces the target

	if not _first_person:
		# Third person, lowered and relaxed: the bow hangs from the hand, the upper limb leaning forward along the way the body faces.
		var face: Vector3 = Vector3(-view.z.x, 0.0, -view.z.z)
		face = face.normalized() if face.length() > 0.001 else Vector3.FORWARD
		up = (Vector3.UP * cos(deg_to_rad(BOW_IDLE_LEAN_DEG)) + face * sin(deg_to_rad(BOW_IDLE_LEAN_DEG))).normalized()
		back = (face - up * face.dot(up)).normalized()
	else:
		# First person, ready or drawing: upright before the view at arm's length, the top canted a little to the right (an instinctive archer's cant).
		up = (view.y * cos(deg_to_rad(BOW_CANT_DEG)) + view.x * sin(deg_to_rad(BOW_CANT_DEG))).normalized()
		back = -view.z

	var across: Vector3 = back.cross(up).normalized()     # mesh y
	var frame: Basis = Basis(up, across, up.cross(across).normalized())   # mesh x along the limbs, z toward the target
	var grip: Vector3 = mount.global_position

	if _first_person and _arms != null and _arms.has_method("grip_point"):
		grip = _arms.grip_point("l")    # inside the closed fingers, not through the palm (Dave: "the bow going right through his hand")

	_model.global_transform = Transform3D(frame, grip - frame.z * BasicLook.BOW_BRACE_M)   # the grip in the fist, the string BOW_BRACE_M nearer the archer

	if not _first_person:
		_third_fist_on(_model).visible = true

	var nock: Vector3 = Vector3.ZERO
	var up_now: bool = _first_person and _arms != null and _arms.hand_mount_r != null

	if up_now:
		# The string's nock point is in the right hand, pulled straight back toward the archer (never pushed past the brace, at most a full draw). It stays in the
		# bow's own plane (Dave: "the string should always be inline with the bow wooden part"), a little above the grip where the arrow sits, and the arrow's width to
		# the left, where the arrow lies.
		var hook: Vector3 = _arms.grip_point("r") if _arms.has_method("grip_point") else _arms.hand_mount_r.global_position   # in the hooked fingers
		var pull: float = (_model.global_transform.affine_inverse() * hook).z
		nock = Vector3(BOW_NOCK_ABOVE_M, -BOW_ARROW_SIDE_M, clampf(pull, -BOW_DRAW_MAX_M, 0.0))

	_set_bow_string(_model, nock)
	_place_nocked_arrow(_model, nock, up_now and (_inv == null or has_arrow()))


# The nocked arrow: its nock (the arrow mesh's back end, x = -ARROW_NOCK_M) on the string at `nock`, its shaft straight toward the target (the bow's +z, which is the
# view's forward) along the left side of the stave over the bow hand. Parallel to the view, the shaft points at the crosshair from below (Dave 10 Nov 2026: "the
# bow and arrow should be adjusted so the arrow lines up with the crosshairs"); it no longer angles off to the left of it.
# The string's two cords (tips to the nock point) and the nocked arrow (hidden until shown) on a bow whose own space has the limbs along x
# and the back toward +z: the player's own bow (_make_look_tool_model) and another player's (player_view.gd _pose_bow, Lane A S8 23 Nov 2026).
static func add_bow_parts(bow: Node3D) -> void:
	if bow.get_node_or_null("StringTop") != null:
		return

	for cord_name in ["StringTop", "StringBottom"]:
		var cord: MeshInstance3D = MeshInstance3D.new()
		cord.name = cord_name
		var line: CylinderMesh = CylinderMesh.new()
		line.top_radius = BasicLook.BOW_STRING_R
		line.bottom_radius = BasicLook.BOW_STRING_R
		line.height = 1.0
		line.radial_segments = 4
		line.rings = 1
		var gut: StandardMaterial3D = StandardMaterial3D.new()
		gut.albedo_color = Color(0.85, 0.82, 0.72)
		gut.roughness = 0.8
		line.material = gut
		cord.mesh = line
		cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bow.add_child(cord)

	_set_bow_string(bow, Vector3.ZERO)
	# The arrow on the string while the bow is up (shown only with an arrow in the pack): its nock on the string, its shaft over the left side of the bow,
	# resting on the bow hand (Dave 10 Nov 2026: "you place the arrow over the left side and then draw back and sight along the arrow shaft").
	var nocked: MeshInstance3D = MeshInstance3D.new()
	nocked.name = "NockedArrow"
	nocked.mesh = BasicLook.mesh_for("stone_arrow")
	nocked.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nocked.visible = false
	bow.add_child(nocked)


static func _place_nocked_arrow(bow: Node3D, nock: Vector3, shown: bool) -> void:
	var arrow: MeshInstance3D = bow.get_node_or_null("NockedArrow") as MeshInstance3D

	if arrow == null:
		return

	arrow.visible = shown

	if not shown:
		return

	var along: Vector3 = Vector3(0.0, 0.0, 1.0)
	arrow.transform = Transform3D(Basis(along, Vector3.RIGHT.cross(along), along.cross(Vector3.RIGHT.cross(along))), nock + along * ARROW_NOCK_M)


func _bow_posing() -> bool:
	return _model != null and _model.has_meta("bow")


# The two halves of the bow's string, from each nock (the tips, mesh x = +-BOW_HALF_M) to the nock point `at` (the bow's own space).
static func _set_bow_string(bow: Node3D, at: Vector3) -> void:
	bow.set_meta("nock", at)

	for cord_name in ["StringTop", "StringBottom"]:
		var cord: MeshInstance3D = bow.get_node_or_null(cord_name) as MeshInstance3D

		if cord == null:
			continue

		var tip: Vector3 = Vector3(BasicLook.BOW_HALF_M if cord_name == "StringTop" else -BasicLook.BOW_HALF_M, 0.0, 0.0)
		var along: Vector3 = at - tip
		var length: float = maxf(along.length(), 0.001)
		var y_axis: Vector3 = along / length
		var x_axis: Vector3 = Vector3.FORWARD.cross(y_axis)
		x_axis = x_axis.normalized() if x_axis.length() > 0.001 else Vector3.RIGHT
		cord.transform = Transform3D(Basis(x_axis, y_axis * length, x_axis.cross(y_axis)), tip + along * 0.5)   # the unit cord stretched to the length


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


# The red ghost's reason in words; a door's carries the shape of the doorway it is aimed at (_door_shape).
func _reason() -> String:
	if blueprint_state == "water_say":
		return water_say.trim_suffix(".").left(1).to_lower() + water_say.trim_suffix(".").substr(1)   # the server's sentence, in the caption's lower-case style

	return PlacementRules.reason_text(blueprint_state, _door_shape)


# Whether the ghost stands over a standing tree's trunk (PlacementRules.over_trunk, as the server checks it). The trunks are listed only when the
# ghost has moved TREE_LOOK_M, turned, changed piece, or the trees changed (one felled under it) since the last look.
const TREE_LOOK_M := 0.1
var _tree_look_key: Vector4 = Vector4.INF
var _tree_look_over: bool = false
var _tree_look_kit: String = ""
var _tree_look_version: int = -1


func _over_tree(kit: String) -> bool:
	if not trunks_round.is_valid():
		return false

	var at: Vector3 = _blueprint.global_position
	var key: Vector4 = Vector4(at.x, at.y, at.z, float(_blueprint_yaw))
	var version: int = int(trunks_version.call()) if trunks_version.is_valid() else 0

	if not _tree_look_key.is_finite() or Vector3(key.x, key.y, key.z).distance_to(Vector3(_tree_look_key.x, _tree_look_key.y, _tree_look_key.z)) >= TREE_LOOK_M or key.w != _tree_look_key.w or kit != _tree_look_kit or version != _tree_look_version:
		_tree_look_key = key
		_tree_look_kit = kit
		_tree_look_version = version
		_tree_look_over = PlacementRules.over_trunk(_placement, kit, at, deg_to_rad(float(_blueprint_yaw)), trunks_round.call(at, PlacementRules.footprint_reach(_placement, kit)))

	return _tree_look_over


# The placement ghost for a held campfire: a ring on the ground where it would go, yellow in the open
# and green under a tree's crown (Dave, 2026-10-20: fires under cover survive rain, open ones go out).
# A left click on a red ghost says why it will not go down (Dave 5 Nov 2026: every placement that fails tells you the reason).
func _say_why_not() -> void:
	var why: String = str({
		"close": "Something is in the way.",
		"crowded": "Too many of these stand here already.",
		"steep": "The ground is too steep there.",
		"water": "You cannot build in water.",
		"nofire": "Lay a small fire first: the pot hangs over it.",
		"notable": "Set it on a table.",
		"far": "Too far to place that. Step closer.",
	}.get(blueprint_state, ""))

	if why == "" and _reason() != "":
		var reason: String = _reason()
		why = reason.left(1).to_upper() + reason.substr(1) + "."

	if why == "" and _blueprinting() and not blueprints.can_afford(_build_tier()):
		why = "You do not have all the materials for that."

	if why == "":
		why = "Aim at the ground where it should go."

	_inv._on_notice(why)


# With the hammer's list open or a blueprint picked, the craft stock (what lies within 12 m, protocol 98) is looked at every HAMMER_STOCK_S, so the
# list's counts and the ghost's colour follow the player as they walk; the list is redrawn with the newest counts at the same pace. It is asked
# for only when the player has moved HAMMER_STOCK_MOVE_M since the last ask, the pack changed, or HAMMER_STOCK_IDLE_S passed (someone else's
# stack or a chest may change): a player standing at a base asks once every few seconds, not every second.
const HAMMER_STOCK_S := 1.0
const HAMMER_STOCK_MOVE_M := 1.5
const HAMMER_STOCK_IDLE_S := 5.0
var _hammer_stock_age: float = HAMMER_STOCK_S
var _hammer_stock_idle: float = 0.0
var _hammer_stock_at: Vector3 = Vector3(INF, INF, INF)
var _hammer_stock_pack: int = 0


func _hammer_stock(delta: float) -> void:
	if not holding or _build_tier() <= 0 or not (blueprints.is_open or blueprints.picked > 0) or not _inv.has_method("ask_stock_now"):
		_hammer_stock_age = HAMMER_STOCK_S   # the first frame with the list open asks at once
		_hammer_stock_at = Vector3(INF, INF, INF)
		return

	_hammer_stock_age += delta
	_hammer_stock_idle += delta

	if _hammer_stock_age < HAMMER_STOCK_S:
		return

	_hammer_stock_age = 0.0
	blueprints.refresh(_build_tier())   # the counts the last answer brought
	var here: Vector3 = _camera.global_position if _camera != null else Vector3.ZERO
	var pack: int = hash([_inv.inventory.numbers, _inv.inventory.counts]) if _inv.inventory != null else 0
	var moved: bool = not _hammer_stock_at.is_finite() or here.distance_to(_hammer_stock_at) >= HAMMER_STOCK_MOVE_M

	if not moved and pack == _hammer_stock_pack and _hammer_stock_idle < HAMMER_STOCK_IDLE_S:
		return

	_hammer_stock_at = here
	_hammer_stock_pack = pack
	_hammer_stock_idle = 0.0
	_inv.ask_stock_now()


func _update_blueprint() -> void:
	_sync_build_tool()

	if (blueprints.picked > 0 or blueprints.is_open or blueprints.mode != blueprints.DEFAULT_MODE) and _build_tier() <= 0:
		blueprints.clear()   # the hammer or knife is put away: the pick and the list go with it
		_plan_queue.clear()

	if not _is_placeable() and not _blueprinting():
		if _blueprint != null:
			_blueprint.visible = false

		_blueprint_ok = false
		return

	var kit: String = _placing_id()
	var now: int = Time.get_ticks_msec()

	if now < _blueprint_next_msec:
		return

	_blueprint_next_msec = now + 100

	# The ghost is the placeable's own model, see-through and tinted: green where it can go, red where it cannot (Dave 2026-10-22).
	var footprint: Vector2 = PlacementRules.footprint(_placement, kit)

	if _blueprint == null or _blueprint_kit != kit:
		if _blueprint == null:
			_blueprint = Node3D.new()
			_root.add_child(_blueprint)
			_ghost_material = StandardMaterial3D.new()
			_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED

		if _is_roof_panel(_blueprint_kit) or _is_roof_panel(kit) or _is_roof_hip(_blueprint_kit) or _is_roof_hip(kit):
			lift_steps = 0   # a roof panel's mode (rise or fall) and a foundation's lift share the number: neither carries over to the other piece

		_blueprint_kit = kit

		for child in _blueprint.get_children():
			child.queue_free()

		var def: Dictionary = PlacementRules.structure_of_kit(_placement, kit)
		_ghost_state = int(def.get("state", 1))
		var model: Node3D = _inv.ghost_model(_ghost_state)
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

	var attach: String = str(PlacementRules.structure_of_kit(_placement, kit).get("attach_to", ""))
	var on_grid: Array = PlacementRules.snap(_placement, kit, hit["position"], posmod(int(round(rad_to_deg(_camera.global_rotation.y))), 360), _inv.placement_rows() if attach == "fire" else (_inv.surface_rows(PlacementRules.attach_states(_placement, kit)) if attach == "table" else _inv.foundation_rows()), clampi(lift_steps, 0, 1))
	_blueprint_at = on_grid[0]
	_blueprint_yaw = int(on_grid[1])

	if bool(PlacementRules.structure_of_kit(_placement, kit).get("foundation", false)) and not bool(on_grid[2]):
		_blueprint_at.y += float(lift_steps) * PlacementRules.LIFT_STEP_M
	_blueprint.global_position = _blueprint_at
	_blueprint.rotation.y = deg_to_rad(float(_blueprint_yaw)) if PlacementRules.structure_of_kit(_placement, kit).get("piece", false) else _camera.global_rotation.y
	var on_base: bool = bool(on_grid[2])
	_ghost_on_base = on_base
	blueprint_state = PlacementRules.blocked(_placement, kit, _blueprint_at, _inv.placement_rows(), float(_blueprint_yaw))   # every fire and structure, at the turn it goes down at, as the server checks them
	_door_shape = str(PlacementRules.doorway_fit(_placement, PlacementRules.structure_of_kit(_placement, kit), _blueprint_at, _inv.foundation_rows())["opening"]) if attach == PlacementRules.DOOR_ATTACH else ""

	if attach == "table" and not on_base:
		blueprint_state = "notable"   # a Serving Platter only goes on a table top (catalog phase 8)

	if _is_roof_hip(kit):
		var hip: Array = PlacementRules.roof_hip_pick(_placement, PlacementRules.structure_of_kit(_placement, kit), _blueprint_at, clampi(lift_steps, 0, 1), _inv.foundation_rows()) if on_base else []

		if hip.is_empty():
			blueprint_state = "nocorner"   # a roof corner only goes where two edges meet at a corner
		else:
			var shape_state: int = int(_placement["structures"].get(str(hip[2]), {}).get("state", _ghost_state))

			if shape_state != _ghost_state:   # the panel beside it, or the wheel, picked the other slope: show that shape
				for child in _blueprint.get_children():
					child.queue_free()

				_ghost_state = shape_state
				var shaped: Node3D = _inv.ghost_model(shape_state)
				_ghost_clean(shaped)
				_blueprint.add_child(shaped)

	if _is_roof_panel(kit):
		if not on_base:
			blueprint_state = "nopanel"   # a roof panel only rests on a wall top, a ceiling edge or another panel's end, never free on the ground
		elif blueprint_state == "":
			var panel_at: Vector3 = _blueprint_at
			var ground_probe: Callable = func(x: float, z: float) -> float: return _terrain_y(x, z, panel_at.y, 14.0)   # the terrain alone, as the server reads it (a 65 panel's low end can hang 10 m up)
			blueprint_state = "buried" if PlacementRules.roof_panel_buried(_placement, kit, _blueprint_at, _blueprint_yaw, ground_probe) else ""

	if blueprint_state == "" and not on_base:
		var ground_at: Vector3 = _blueprint_at
		var probe: Callable = func(x: float, z: float) -> float: return _terrain_y(x, z, ground_at.y, 6.0)
		blueprint_state = PlacementRules.steep(_placement, kit, _blueprint_at, deg_to_rad(float(_blueprint_yaw)), probe)   # the turn it is placed at, as the server samples it (the camera's turn sampled other corners: BUG-008)

		if blueprint_state == "" and PlacementRules.seats_low(_placement, kit):   # shown where the server sets it: at the lowest ground under its footprint
			var middle: float = float(probe.call(_blueprint_at.x, _blueprint_at.z))

			if not is_nan(middle):
				_blueprint.global_position.y = PlacementRules.seated_ground(_placement, kit, _blueprint_at, deg_to_rad(float(_blueprint_yaw)), probe, middle)

	if blueprint_state == "":
		var lifted: float = float(lift_steps) * PlacementRules.LIFT_STEP_M if (not on_base and bool(PlacementRules.structure_of_kit(_placement, kit).get("foundation", false))) else 0.0
		var terrain: float = _terrain_y(_blueprint_at.x, _blueprint_at.z, _blueprint_at.y, 14.0)   # 14 m reaches down past a stack of four foundations

		if not is_nan(terrain):
			blueprint_state = PlacementRules.off_ground(_placement, kit, _blueprint_at.y - lifted, terrain, on_base and attach != "table", on_grid.size() > 3)   # a platter's base is a table: the server snaps with foundation rows only, so no exemption

			if blueprint_state == "" and terrain < PlacementRules.WET_GROUND_M:
				blueprint_state = "wet"   # ground this low is shore mud: the server refuses it (server_items _place)

	if blueprint_state == "" and _over_tree(kit):
		blueprint_state = "tree"   # the server refuses it the same way (server_items _place)

	if blueprint_state == "" and not on_base and not PlacementRules.structure_of_kit(_placement, kit).has("needs_running_water") and water_depth_at.is_valid() and PlacementRules.over_water(_placement, kit, _blueprint_at, deg_to_rad(float(_blueprint_yaw)), water_depth_at):
		blueprint_state = "water"

	if blueprint_state == "" and PlacementRules.structure_of_kit(_placement, kit).has("needs_running_water"):
		blueprint_state = _wheel_state(kit)
	elif blueprint_state == "" and _carries_water(kit):
		blueprint_state = _water_piece_state(kit)

	if blueprint_state == "" and water_depth_at.is_valid() and PlacementRules.water_short(_placement, kit, _blueprint_at, water_depth_at):
		blueprint_state = "shallow"   # a fish trap off the water or in too little of it, as the server refuses

	if blueprint_state == "":
		var covered: bool = footprint != Vector2.ZERO or (_cover_at.is_valid() and _cover_at.call(_blueprint_at))
		blueprint_state = "covered" if covered else "open"

	# The server refuses a spot more than PLACE_REACH_M (6 m) from the player's feet; the ghost's ray starts at the camera, which in third person
	# is behind the body, so a green ghost could still be refused with "Too far to place that".
	if (blueprint_state == "open" or blueprint_state == "covered") and _inv._player_position.is_valid() and (_inv._player_position.call() as Vector3).distance_to(_blueprint_at) > PLACE_REACH_M:
		blueprint_state = "far"

	var blocked: bool = blueprint_state != "open" and blueprint_state != "covered"   # every reason is red, so a new one can never leave a green ghost that will not place
	_blueprint_ok = _blueprint_ok and not blocked and (not _blueprinting() or blueprints.plan_picked < 0 or blueprints.can_afford(_build_tier()))   # a single piece without the materials is set down as a blue blueprint site (Dave 5 Nov 2026); a saved plan still needs them all
	_ghost_material.albedo_color = Color(0.9, 0.2, 0.2, 0.5) if blocked else Color(0.3, 0.9, 0.3, 0.5)


# The terrain height under (x, z) as the placement rules read it: the first ground below `near_y` + 3 m and no deeper than `depth` m under `near_y`,
# not what stands on it (a player, a tree or bush, a placed piece), because the server checks the terrain alone. NAN with no ground there (unknown never blocks).
func _terrain_y(x: float, z: float, near_y: float, depth: float) -> float:
	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var skip: Array[RID] = []

	for i in 6:
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, near_y + 3.0, z), Vector3(x, near_y - depth, z))
		ray.exclude = skip
		var found: Dictionary = space.intersect_ray(ray)

		if found.is_empty():
			return NAN

		var collider: Object = found.get("collider")

		if collider != null and (collider is CharacterBody3D or CaveSounds.is_not_rock(collider)):
			skip.append(found["rid"])
			continue

		return float(found["position"].y)

	return NAN


# The sawmill ghost's water wheel (water rules section 10, protocol 105): the server works out what the wheel would give where the ghost stands
# (the same rule as placing) and the ghost shows it, "Sawmill: 62 %" in green or the reason in red. Asked again only when the ghost has moved a
# quarter metre or turned, at most every WHEEL_ASK_MS; until the answer for this spot comes the ghost keeps its other colour.
const WHEEL_ASK_MS := 300
const WHEEL_MOVE_M := 0.25

var _wheel_asked_at: Vector3 = Vector3(INF, INF, INF)
var _wheel_asked_yaw: int = -1
var _wheel_asked_msec: int = -100000
var _wheel_answer: Array = []            # [at, yaw degrees, percent, why] of the last answer
var _wheel_asked_kit: String = ""       # the kit the last ask was for: another kit at the same spot asks again (a water piece's answer is not a sawmill's)
var wheel_note: String = ""               # the ghost's caption line for a sawmill: "Sawmill: 62 %", or "" (tests read it)


func _wheel_state(kit: String) -> String:
	if kit != _wheel_asked_kit:
		_wheel_asked_kit = kit
		_wheel_asked_at = Vector3(INF, INF, INF)
		_wheel_answer = []   # the last answer was another piece's

	var moved: bool = _wheel_asked_at.distance_to(_blueprint_at) > WHEEL_MOVE_M or _wheel_asked_yaw != _blueprint_yaw

	if moved and Time.get_ticks_msec() - _wheel_asked_msec >= WHEEL_ASK_MS and _net != null:
		_wheel_asked_at = _blueprint_at
		_wheel_asked_yaw = _blueprint_yaw
		_wheel_asked_msec = Time.get_ticks_msec()
		_net.inventory_action.rpc_id(1, Net.ACT_WHEEL_ASK, _blueprint_yaw, _inv.table.number_of(kit), 0, _blueprint_at)

	wheel_note = ""

	if _wheel_answer.is_empty() or int(_wheel_answer[2]) == -1 or (_wheel_answer[0] as Vector3).distance_to(_blueprint_at) > WHEEL_MOVE_M or int(_wheel_answer[1]) != _blueprint_yaw:
		return ""   # no answer for this spot yet (a -1 answer is a water piece's)

	if str(_wheel_answer[3]) != "":
		return "wheel_" + str(_wheel_answer[3])

	wheel_note = "Sawmill: %d %%" % int(_wheel_answer[2])
	return ""


func _on_wheel_share(at: Vector3, yaw_deg: int, percent: int, why: String) -> void:
	_wheel_answer = [at, yaw_deg, percent, why]


# A water piece's ghost (a barrel, tank, well, trough...): the server's own refusal for this spot (a loop, too many sources, no ground water to
# reach) comes back as a wheel_share with percent -1 and the words; asked and kept exactly as the wheel's (_wheel_state). Until the answer for
# this spot comes the ghost keeps its other colour. Pipes laid from the hand have their own line (pipe_lay), not this ghost.
var water_say: String = ""   # the server's words for the red ghost ("water_say"), or ""


func _carries_water(kit: String) -> bool:
	var block: Variant = PlacementRules.structure_of_kit(_placement, kit).get("water", {})
	return typeof(block) == TYPE_DICTIONARY and not (block as Dictionary).is_empty()


func _water_piece_state(kit: String) -> String:
	_wheel_state(kit)   # the ask and the answer's spot check are the wheel's
	wheel_note = ""

	if _wheel_answer.is_empty() or int(_wheel_answer[2]) != -1 or (_wheel_answer[0] as Vector3).distance_to(_blueprint_at) > WHEEL_MOVE_M or int(_wheel_answer[1]) != _blueprint_yaw:
		return ""

	water_say = str(_wheel_answer[3])
	return "water_say" if water_say != "" else ""


# The blow lands: what is in reach decides the sound. (Chopping trees and digging stone come with
# tree-fall and the harvest of ground; for now the axe only swings and sounds.)
func _strike() -> void:
	if not _animal_aimed().is_empty():   # an animal in front takes the blow (Dave 19 Nov 2026: the axe did nothing to a pig)
		_melee_strike()
		return

	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		# A swing at nothing is still a swing and tires (BUG-001): tell the server (b = 1: struck nothing, protocol 118), with a point in the air, so it holds the tool's effort as it does for a blow that lands.
		_net.inventory_action.rpc_id(1, Net.ACT_MINE, held_slot + 1, 1, 0, from - _camera.global_transform.basis.z * MISS_POINT_M)
		return

	if _sound == null:
		return

	struck.emit(1.0, 1.2 if _tool_class() == "pick" else 1.0)
	var tree: Array = _tree_near.call(hit["position"]) if _tree_near.is_valid() else []
	var stump_id: int = _inv.stump_near(hit["position"])
	var boulder_id: int = _inv.boulder_near(hit["position"])
	var log_id: int = _inv.loose_log_near(hit["position"])
	FeelKicks.chips(_root, hit["position"], hit["normal"], log_id != 0 or stump_id != 0 or not tree.is_empty())
	var shrub: Array = shrub_near.call(from, hit["position"]) if shrub_near.is_valid() and tree.is_empty() else []   # an axe chops a bush up, a pickaxe digs it up whole (Dave 2 Nov 2026)

	if log_id != 0:
		_sound.hits.hit(_hit_tool(), "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_PROCESS, log_id, 0, 0, Vector3(float(held_slot + 1), 0.0, 0.0))   # wood work: the tool in hand, an axe or (slowly) a pick (protocol 115)
	elif boulder_id != 0:
		_sound.hits.hit(_hit_tool(), "stone", hit["position"], 1.0)   # a boulder is stone whatever the ground under it
		_net.inventory_action.rpc_id(1, Net.ACT_HIT, boulder_id, Net.HIT_BOULDER, held_slot + 1, Vector3.ZERO)   # the tool in hand does the work (TEST-013)
	elif stump_id != 0:
		_sound.hits.hit(_hit_tool(), "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_PROCESS, stump_id, 0, 0, Vector3(float(held_slot + 1), 0.0, 0.0))
	elif not tree.is_empty():
		_sound.hits.hit(_hit_tool(), "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_HIT, tree[1], tree[0].x, tree[0].y, Vector3(float(held_slot + 1), 0.0, 0.0))
	elif not shrub.is_empty():
		_sound.hits.hit(_hit_tool(), "wood", hit["position"], 0.7)
		_net.inventory_action.rpc_id(1, Net.ACT_HIT_SHRUB, shrub[1], shrub[0].x, shrub[0].y, Vector3(float(held_slot + 1), 0.0, 0.0))   # the tool in hand: a pick digs it up, an axe chops it (protocol 117)
	else:
		_sound.hits.hit_ground(_hit_tool(), hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_MINE, held_slot + 1, 0, 0, hit["position"])   # the pick or axe in hand (protocol 117)


# A shovel swing at the ground under the crosshair: the server checks the shovel and the reach, cuts the hole and tells
# everyone (the hole, the sound and the vanishing grass happen when it answers; DIGGING_DESIGN.md).
func _plant_here() -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit["collider"].has_meta("species_ids"):
		_inv._on_notice("Aim at the ground within reach to plant it")
		return

	_arm_play("use", 0.6)
	_net.inventory_action.rpc_id(1, Net.ACT_PLANT_BUSH, held_slot, 0, 0, hit["position"])


func _dig_here() -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit["collider"].has_meta("species_ids"):
		_inv._on_notice("Nothing to dig there: aim the shovel at the ground within reach")
		return

	_net.inventory_action.rpc_id(1, Net.ACT_DIG, held_slot, 0, 0, hit["position"])


# Holding the left button with the hoe in Level repeats the stroke every HOE_REPEAT_S (the server paces it at 0.5 s too, and keeps the height it started
# from for the whole hold: BugsList entry 1). Every other action is one click (Pathen: one level spot a click; the grids and the survey: one a click).
const HOE_REPEAT_S := 0.55
var _hoe_t: float = 0.0
var _hoe_menu_t: float = 0.0


func _hoe_repeat(delta: float) -> void:
	if _inv == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or held_number() == 0 or str(_inv.table.entry(held_id()).get("tool_class", "")) != "hoe":
		_hoe_t = 0.0
		_hoe_menu_close()
		return

	if _hoe_menu_open and _hoe_menu_page == "garden":
		_hoe_menu_t += delta

		if _hoe_menu_t >= 0.5:   # the plant list follows the stock in reach as it changes
			_hoe_menu_t = 0.0
			_hoe_menu_refresh()

	if _hoe_menu_open or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or hoe_mode != "smooth" or _body_out():   # passing out stops the levelling (QA #19)
		_hoe_t = 0.0
		return

	_hoe_t += delta

	if _hoe_t >= HOE_REPEAT_S:
		_hoe_t = 0.0
		_arm_play("use", 0.6)
		_hoe_apply()


# What the hoe does (BugsList_Current.md entry 5, Dave 18 Nov 2026: this order and these names). Right click opens the list; Shift + right click sets a
# survey marker in any mode.
const HOE_MODES := [
	{"id": "smooth", "name": "Level", "note": "hold the left button: the ground about 3 m round is cut or filled to the height of your feet (filling uses soil from your pack, the ground near you or your containers)"},
	{"id": "garden", "name": "Plant", "note": "choose a plant, then one left click fills the green grid as far as your supplies go (Alt + arrow keys: rows and columns; wheel: turn; right click: choose another plant)"},
	{"id": "till", "name": "Till Garden Grid - 20m Edge Blend", "note": "one left click levels the grid to its average height, tills it into garden soil and blends its edges into the land within 20 m (Alt + arrow keys: size; wheel: turn; red: something is in the way)"},
	{"id": "soil", "name": "Till Soil 2m", "note": "one left click levels a 2 m patch to its average height and tills it into garden soil (no edge blending)"},
	{"id": "path", "name": "Pathen", "note": "one left click makes one level spot of path"},
	{"id": "survey", "name": "Survey a Path", "note": "left click sets a marker; a green line runs from it to where you aim, at any distance (red: a building is in the way); click again and the road builds along it. Click the last marker again to end the survey (Shift + right click does the same in any mode)"},
	{"id": "trench", "name": "Irrigation Trench", "note": "one left click digs 2 m of trench where you aim, along the way you face; water from a pipe or channel end over it soaks the garden beds within 30 m that are not higher than it"},
]
# The list is a small plate above the hotbar and its caption (BugsList entry 4, Dave's play test 19 Nov 2026: it ran off the right edge and over the
# hotbar): short names, one to a line, the highlighted one marked; the highlighted one's explanation below them. Sizes are 1920 x 1080 canvas px
# before the player's text size (_inv.text_px), so the plate grows with the text and is still kept inside the window.
const HOE_MENU_WIDTH := 600.0      # the plate's width at text size 1.0; never more than the window less HOE_MENU_EDGE each side
const HOE_MENU_EDGE := 16.0        # kept clear at the window's edges and above the caption
const HOE_MENU_PX := {"title": 26, "row": 24, "help": 20, "keys": 18}
const HOE_HELP_BREAKS := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE   # the explanation's AUTOWRAP_WORD_SMART
var hoe_mode: String = "smooth"
var garden_pick: String = ""             # Plant: the item id picked to plant (seeds, a dug-up bush or a tree seed), "" for none (tests read it)
var _hoe_menu_page: String = "modes"     # "modes" (HOE_MODES) or "garden" (what can be planted: the pack and the stock in reach)
var _garden_rows: Array = []             # the plant list as shown: [{"id", "kind"}]
var _hoe_menu_grey: Array = []           # per shown row: true when it cannot be planted now (out of season, or winter), drawn dim and not picked
var season_now: Callable = Callable()    # -> "spring" | "summer" | "autumn" | "winter" (terrain_client: the season where the player stands, from the synced game clock); none: every row open
var _hoe_menu_open: bool = false
var _hoe_menu_index: int = 0
var _hoe_menu_panel: PanelContainer = null
var _hoe_menu_title: Label = null
var _hoe_menu_rows: VBoxContainer = null
var _hoe_menu_help: Label = null
var _hoe_menu_keys: Label = null
var _hud_layer: CanvasLayer = null


func _hoe_apply() -> void:
	if hoe_mode == "smooth":
		_hoe_here(Net.ACT_HOE_SMOOTH)
	elif hoe_mode == "till" or hoe_mode == "soil":
		_till_garden_here()   # one garden or patch a click
	elif hoe_mode == "survey":
		_grade_point_here()   # one marker a click, never repeated while the button is held
	elif hoe_mode == "garden":
		_garden_here()   # one planting a click
	elif hoe_mode == "trench":
		_hoe_here(Net.ACT_DIG_TRENCH, _facing_deg())   # one trench piece a click, along the way the player faces
	else:
		_hoe_here(Net.ACT_HOE_PATH)


# The way the camera faces as a structure's turn in whole degrees: the piece's length (its x) runs along the view (Godot's rotation about y).
func _facing_deg() -> int:
	var ahead: Vector3 = -_camera.global_transform.basis.z
	return posmod(roundi(rad_to_deg(atan2(-ahead.z, ahead.x))), 360)


func _hoe_menu_open_now(page: String = "modes") -> void:
	if _hud_layer == null:
		return

	if _hoe_menu_panel == null:
		_hoe_menu_build()

	_hoe_menu_page = "modes"
	_hoe_menu_index = 0

	for n in HOE_MODES.size():
		if str(HOE_MODES[n]["id"]) == hoe_mode:
			_hoe_menu_index = n

	_hoe_menu_open = true
	_hoe_menu_panel.visible = true

	if page == "garden":
		_garden_page()
	else:
		_hoe_menu_refresh()


# Plant's list (BugsList entry 6): what can be planted from the pack, the loose things near the player and their nearby containers (the crafting stock,
# asked for again as it opens), with how many of each.
func _garden_page() -> void:
	_inv.ask_stock_now()
	_hoe_menu_page = "garden"
	_garden_rows = _plantable_rows()
	_hoe_menu_index = 0

	for n in _garden_rows.size():
		if str(_garden_rows[n]["id"]) == garden_pick:
			_hoe_menu_index = n

	_hoe_menu_refresh()


func _plantable_rows() -> Array:
	var ids: Array = []

	for slot in range(_inv.inventory.slot_count):
		ids.append(_inv.table.id_of(_inv.inventory.numbers[slot]) if _inv.inventory.numbers[slot] != 0 else "")

	for number in _inv.reach_stock:
		if int(_inv.reach_stock[number]) > 0:
			ids.append(_inv.table.id_of(int(number)))

	return FarmRules.plantables(_inv.crop_table(), ids, "_bush", _inv.tree_seed_table())


func _hoe_menu_build() -> void:
	_hoe_menu_panel = PanelContainer.new()
	_hoe_menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Bottom centre: it grows up and both ways, so a list that comes out taller than worked out still stays above the hotbar.
	_hoe_menu_panel.anchor_left = 0.5
	_hoe_menu_panel.anchor_right = 0.5
	_hoe_menu_panel.anchor_top = 1.0
	_hoe_menu_panel.anchor_bottom = 1.0
	_hoe_menu_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hoe_menu_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var plate: StyleBox = ArtKit.stylebox_raised(0).duplicate()
	plate.content_margin_left = 18
	plate.content_margin_right = 18
	plate.content_margin_top = 12
	plate.content_margin_bottom = 12
	_hoe_menu_panel.add_theme_stylebox_override("panel", plate)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	_hoe_menu_panel.add_child(column)
	_hoe_menu_title = _hoe_menu_text("cinzel_bold", ArtKit.HEADING)
	column.add_child(_hoe_menu_title)
	_hoe_menu_rows = VBoxContainer.new()
	_hoe_menu_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hoe_menu_rows.add_theme_constant_override("separation", 0)
	column.add_child(_hoe_menu_rows)
	column.add_child(HSeparator.new())
	_hoe_menu_help = _hoe_menu_text("garamond", ArtKit.CREAM)
	_hoe_menu_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hoe_menu_help.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_hoe_menu_help.add_theme_constant_override("line_spacing", 0)   # its height is worked out from the font (_hoe_menu_show): no extra gap between lines
	column.add_child(_hoe_menu_help)
	_hoe_menu_keys = _hoe_menu_text("garamond", ArtKit.DIM)
	column.add_child(_hoe_menu_keys)
	_hud_layer.add_child(_hoe_menu_panel)


# One line of the plate: never wider than the plate (a long name ends in "..." instead of pushing the plate out).
func _hoe_menu_text(face: String, colour: Color) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", ArtKit.font(face))
	label.add_theme_color_override("font_color", colour)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	return label


func _hoe_menu_refresh() -> void:
	var title: String = "What should the hoe do?"
	var keys: String = "Wheel: move    Left click: choose    Right click: close"
	var rows: Array = []
	var help: String = ""

	if _hoe_menu_page == "garden":
		_garden_rows = _plantable_rows()
		_hoe_menu_index = clampi(_hoe_menu_index, 0, maxi(_garden_rows.size() - 1, 0))
		title = "What to plant?"
		keys = "Wheel: move    Left click: choose    Right click: back"

		if _garden_rows.is_empty():
			help = "Nothing to plant: carry seeds, a dug-up bush or a tree's seed, or put them in a container or on the ground near you."

	_hoe_menu_grey = []

	for n in _hoe_menu_size():
		rows.append(_hoe_menu_line(n))
		_hoe_menu_grey.append(_hoe_menu_page == "garden" and not _garden_row_open(n))

	if not rows.is_empty():
		help = _hoe_menu_note(_hoe_menu_index)

	_hoe_menu_show(title, rows, _hoe_menu_index, help, keys)


# Lays the plate out for the window as it is now: its width, the text sizes, how many rows fit (a long plant list shows a window of rows that follows
# the highlight, with "..." where more are hidden), and its place above the hotbar caption. The height is worked out here, not waited for.
func _hoe_menu_show(title: String, rows: Array, index: int, help: String, keys: String) -> void:
	var view: Vector2 = _hud_layer.get_viewport().get_visible_rect().size
	var px: Dictionary = {}

	for part in HOE_MENU_PX:
		px[part] = _inv.text_px(int(HOE_MENU_PX[part])) if _inv != null and _inv.has_method("text_px") else int(HOE_MENU_PX[part])

	var grow: float = float(px["row"]) / float(HOE_MENU_PX["row"])
	var width: float = minf(HOE_MENU_WIDTH * maxf(grow, 1.0), view.x - 2.0 * HOE_MENU_EDGE)
	var inner: float = width - 36.0   # the plate's side margins
	var bottom: float = _hoe_menu_bottom(view)
	var garamond: Font = ArtKit.font("garamond")
	var row_h: float = garamond.get_height(px["row"])
	var help_h: float = garamond.get_multiline_string_size(help, HORIZONTAL_ALIGNMENT_LEFT, inner, px["help"], -1, HOE_HELP_BREAKS).y + 2.0 if help != "" else 0.0
	var fixed: float = 24.0 + 4.0 * 6.0 + 4.0 + ArtKit.font("cinzel_bold").get_height(px["title"]) + help_h + garamond.get_height(px["keys"])
	var room: int = maxi(3, floori((bottom - HOE_MENU_EDGE - fixed) / row_h))
	var first: int = 0
	var count: int = rows.size()

	if count > room:   # a window of rows round the highlight; the end rows say "..." when more are hidden past them
		@warning_ignore("integer_division")
		first = clampi(index - room / 2, 0, count - room)
		count = room

	_hoe_menu_title.text = title
	_hoe_menu_title.add_theme_font_size_override("font_size", px["title"])
	_hoe_menu_keys.text = keys
	_hoe_menu_keys.add_theme_font_size_override("font_size", px["keys"])
	_hoe_menu_help.text = help
	_hoe_menu_help.visible = help != ""
	_hoe_menu_help.add_theme_font_size_override("font_size", px["help"])
	_hoe_menu_help.custom_minimum_size = Vector2(inner, help_h)

	while _hoe_menu_rows.get_child_count() < count:
		_hoe_menu_rows.add_child(_hoe_menu_text("garamond", ArtKit.CREAM))

	for n in _hoe_menu_rows.get_child_count():
		var label: Label = _hoe_menu_rows.get_child(n) as Label
		var at: int = first + n
		label.visible = n < count

		if not label.visible:
			continue

		var on: bool = at == index
		var more: bool = (n == 0 and first > 0) or (n == count - 1 and at < rows.size() - 1)
		label.text = "..." if more else str(rows[at])
		label.add_theme_font_override("font", ArtKit.font("garamond_semibold" if on else "garamond"))
		label.add_theme_stylebox_override("normal", _hoe_menu_mark(on))
		var grey: bool = not more and at < _hoe_menu_grey.size() and bool(_hoe_menu_grey[at])
		label.add_theme_color_override("font_color", ArtKit.DIM if grey else (ArtKit.GOLD_BRIGHT if on else (ArtKit.DIM if more else ArtKit.CREAM)))
		label.add_theme_font_size_override("font_size", px["row"])

	_hoe_menu_panel.offset_left = -width / 2.0
	_hoe_menu_panel.offset_right = width / 2.0
	_hoe_menu_panel.offset_bottom = bottom - view.y
	_hoe_menu_panel.offset_top = _hoe_menu_panel.offset_bottom - _hoe_menu_panel.get_combined_minimum_size().y


# The highlighted row sits on a lit band with a gold bar at its left; the others keep the same margins so no row moves when the highlight does.
func _hoe_menu_mark(on: bool) -> StyleBox:
	var box: StyleBox = StyleBoxEmpty.new()

	if on:
		var band: StyleBoxFlat = StyleBoxFlat.new()
		band.bg_color = ArtKit.RAISED_LIT
		band.border_color = ArtKit.GOLD_BRIGHT
		band.border_width_left = 4
		band.set_corner_radius_all(3)
		box = band

	box.content_margin_left = 12
	box.content_margin_right = 6
	return box


# The plate's lowest point: above the held-item caption, which sits above the hotbar tray (LABEL_ABOVE).
func _hoe_menu_bottom(view: Vector2) -> float:
	var caption_h: float = 0.0

	if _label != null and _label.text != "":
		caption_h = float(_label.text.split("\n").size()) * _label.get_theme_font("font").get_height(20)

	return view.y - LABEL_ABOVE - caption_h - 8.0


func _hoe_menu_size() -> int:
	return _garden_rows.size() if _hoe_menu_page == "garden" else HOE_MODES.size()


# A row's short name: the action's name, or the plant's name and how many there are.
func _hoe_menu_line(n: int) -> String:
	if _hoe_menu_page != "garden":
		return "%d. %s" % [n + 1, str(HOE_MODES[n]["name"])]

	var number: int = _inv.table.number_of(str(_garden_rows[n]["id"]))
	return "%s (%d)%s" % [_inv.table.name_of(number), _inv.stock_fill(number), "" if _garden_row_open(n) else "   not now"]


func _season_now() -> String:
	return str(season_now.call()) if season_now.is_valid() else ""


# Whether plant row n can go in now (FarmRules.plantable_now, the rule the server's sowing and planting refusals use).
func _garden_row_open(n: int) -> bool:
	var season: String = _season_now()

	if season == "" or n < 0 or n >= _garden_rows.size():
		return true

	return FarmRules.plantable_now(_inv.crop_table(), str(_garden_rows[n]["id"]), str(_garden_rows[n]["kind"]), season)


# Why plant row n cannot go in now.
func _garden_row_why(n: int) -> String:
	if _season_now() == "winter":
		return "The ground is frozen hard: nothing can be planted in winter."

	var seasons: Array = FarmRules.sow_seasons(_inv.crop_table().get(FarmRules.crop_of_seed(_inv.crop_table(), str(_garden_rows[n]["id"])), {})).filter(func(x): return str(x) != "winter")
	if seasons.is_empty():
		return "Out of season: it cannot be sown now."

	return "Out of season: sow it in %s (it is %s now)." % [" or ".join(PackedStringArray(seasons.map(func(x): return str(x)))), _season_now()]


# The highlighted row's explanation, shown under the list.
func _hoe_menu_note(n: int) -> String:
	if _hoe_menu_page != "garden":
		return "%s: %s." % [str(HOE_MODES[n]["name"]), str(HOE_MODES[n]["note"])]

	if not _garden_row_open(n):
		return _garden_row_why(n)

	return "Plant on tilled soil." if str(_garden_rows[n]["kind"]) == "seed" else "Plant in open ground."


# Left click in the hoe's list: on the first page it sets the action (Plant goes on to the list of what to plant); on the plant list it picks the plant.
func _hoe_menu_choose() -> void:
	if _hoe_menu_page == "garden":
		if _hoe_menu_index < _garden_rows.size() and not _garden_row_open(_hoe_menu_index):
			_inv._on_notice(_garden_row_why(_hoe_menu_index))   # greyed out: it stays unpicked and the list stays open
			return

		if _hoe_menu_index < _garden_rows.size():
			var row: Dictionary = _garden_rows[_hoe_menu_index]
			garden_pick = str(row["id"])
			_inv._on_notice("Hoe: plant %s" % _inv.table.name_of(_inv.table.number_of(garden_pick)).to_lower())

		_hoe_menu_close()
		return

	hoe_mode = str(HOE_MODES[_hoe_menu_index]["id"])

	if hoe_mode != "garden":
		_inv._on_notice("Hoe: %s" % str(HOE_MODES[_hoe_menu_index]["name"]))
		_hoe_menu_close()
		return

	_garden_page()


# Right click in the list: the plant list goes back to the hoe's actions; the actions close.
func _hoe_menu_back() -> void:
	if _hoe_menu_page == "garden":
		_hoe_menu_page = "modes"

		for n in HOE_MODES.size():
			if str(HOE_MODES[n]["id"]) == hoe_mode:
				_hoe_menu_index = n

		_hoe_menu_refresh()
		return

	_hoe_menu_close()


func _hoe_menu_close() -> void:
	_hoe_menu_open = false

	if _hoe_menu_panel != null:
		_hoe_menu_panel.visible = false


# Grade line points: the first click sets A, the next B, the next starts a new line at A. Stakes mark them; the server keeps its own copy.
var _grade_a: Vector3 = Vector3.ZERO
var _grade_has_a: bool = false
var _stakes: Array = []


# A survey stake (Kathleen, stage-1 pass): a 1 m wooden post with a sharpened foot and a small red-orange flag at the top, so a grade line reads as marked
# ground and not as a white pole. Origin in the middle of its height, like the old post.
func _make_stake() -> Node3D:
	var stake: Node3D = Node3D.new()
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.4, 0.22)
	wood.roughness = 1.0
	var shaft: MeshInstance3D = MeshInstance3D.new()
	var post: CylinderMesh = CylinderMesh.new()
	post.top_radius = 0.025
	post.bottom_radius = 0.028
	post.height = 0.8
	post.material = wood
	shaft.mesh = post
	shaft.position = Vector3(0.0, 0.1, 0.0)
	stake.add_child(shaft)
	var tip: MeshInstance3D = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.028
	cone.bottom_radius = 0.002
	cone.height = 0.2
	cone.material = wood
	tip.mesh = cone
	tip.position = Vector3(0.0, -0.4, 0.0)
	stake.add_child(tip)
	var flag: MeshInstance3D = MeshInstance3D.new()
	var cloth: BoxMesh = BoxMesh.new()
	cloth.size = Vector3(0.2, 0.12, 0.008)
	var red: StandardMaterial3D = StandardMaterial3D.new()
	red.albedo_color = Color(0.92, 0.28, 0.1)
	red.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.material = red
	flag.mesh = cloth
	flag.position = Vector3(0.11, 0.42, 0.0)
	stake.add_child(flag)
	return stake


# Surveyor mode (Dave 17 Nov 2026): after the first marker every new marker joins the one before it at any distance, straight through trees,
# stumps and rocks; only a building refuses it (SurveyLine, the line is red). Clicking the last marker again ends the survey; so does putting the hoe away.
const SURVEY_AIM_M := 150.0       # how far the crosshair can pick out ground for a marker (a ray this long; server_items SURVEY_REACH_M). Not a road limit: markers join at any distance
const SURVEY_END_M := 1.5         # a click this near the last marker ends the survey


func _survey_aim() -> Dictionary:
	var from: Vector3 = _camera.global_position
	return _camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * SURVEY_AIM_M))


func _grade_point_here() -> void:
	var hit: Dictionary = _survey_aim()

	if hit.is_empty():
		_inv._on_notice("No ground under the crosshair within %d m (as far as the hoe can aim): walk on and set the next marker, the road joins it at any distance" % int(SURVEY_AIM_M))
		return

	var at: Vector3 = hit["position"]   # a trunk, a rock or a log under the crosshair: the server takes the ground under that spot

	if _grade_has_a and Vector2(at.x - _grade_a.x, at.z - _grade_a.z).length() < SURVEY_END_M:
		_survey_end()
		_inv._on_notice("Survey ended: the next marker starts a new road")
		return

	if _grade_has_a and survey_blocked(_grade_a, at):
		_inv._on_notice("A building is in the way: survey the road round it")
		return

	var chained: bool = _grade_has_a
	_grade_has_a = true
	_net.inventory_action.rpc_id(1, Net.ACT_HOE_GRADE_POINT, held_slot, 1 if chained else 0, 0, at)
	_inv._on_notice("Marker set: the road builds along the line. Set the next, or click this marker again to end" if chained else "Marker 1 set: aim where the road goes and set the next marker")

	_grade_a = at
	var stake: Node3D = _make_stake()
	_root.add_child(stake)
	stake.global_position = at + Vector3(0.0, 0.5, 0.0)
	_stakes.append(stake)


func _survey_end() -> void:
	_grade_has_a = false


# True when a building the client knows of (StructureLook.survey_foot) stands in the road's way from a to b: the same question the server asks.
func survey_blocked(a: Vector3, b: Vector3) -> bool:
	var a2: Vector2 = Vector2(a.x, a.z)
	var b2: Vector2 = Vector2(b.x, b.z)
	var lo: Vector2 = Vector2(minf(a.x, b.x), minf(a.z, b.z))
	var hi: Vector2 = Vector2(maxf(a.x, b.x), maxf(a.z, b.z))

	for id in _inv._world:
		var row: Dictionary = _inv._world[id]
		var state: int = int(row.get("state", 0))

		if state in [0, 2, 4, 10]:
			continue   # loose things, stumps and rocks: the road goes through them

		var foot: Vector2 = StructureLookScript.survey_foot(state)

		if foot == Vector2.ZERO:
			continue

		var pos: Vector3 = row["pos"]
		var reach: float = foot.length() * 0.5 + SurveyLine.HALF_WIDTH_M

		if pos.x < lo.x - reach or pos.x > hi.x + reach or pos.z < lo.y - reach or pos.z > hi.y + reach:
			continue

		if SurveyLine.crosses(a2, b2, Vector2(pos.x, pos.z), float(row.get("yaw", 0.0)), foot):
			return true

	return false


# The survey line (Dave 17 Nov 2026): while a survey is going, a bright line runs over the ground from the last marker to the spot under the crosshair,
# green where the road can go, red when a building is in the way. Drawn on top of everything (no depth test) so it shows through grass and trees.
# Rebuilt ten times a second, only when the aim has moved; the ground under it is found with one ray every SURVEY_LINE_STEP_M (at most
# SURVEY_LINE_RAYS, further apart on a long line). Client side only: nobody else sees it.
const SURVEY_LINE_STEP_M := 1.0
const SURVEY_LINE_RAYS := 160
const SURVEY_LINE_WIDTH_M := 0.12
const SURVEY_LINE_LIFT_M := 0.08
var _survey_mesh: MeshInstance3D = null
var _survey_green: StandardMaterial3D = null
var _survey_red: StandardMaterial3D = null
var _survey_msec: int = 0
var _survey_to: Vector3 = Vector3.INF
var survey_line_red: bool = false   # what the line shows now (a test reads it)


func _survey_line() -> void:
	if _inv == null or _camera == null:
		return

	var on: bool = _grade_has_a and _hoe_in_hand() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	if not on:
		if not _hoe_in_hand():
			_survey_end()   # the hoe is put away: the survey is over (the server's road goes on building while a hoe is on the hotbar)

		if _survey_mesh != null:
			_survey_mesh.visible = false

		_survey_to = Vector3.INF
		return

	var now: int = Time.get_ticks_msec()

	if now < _survey_msec:
		return

	_survey_msec = now + 100
	var hit: Dictionary = _survey_aim()

	if hit.is_empty():
		if _survey_mesh != null:
			_survey_mesh.visible = false

		_survey_to = Vector3.INF
		return

	var to: Vector3 = hit["position"]

	if _survey_mesh != null and _survey_mesh.visible and to.distance_to(_survey_to) < 0.2:
		return

	_survey_to = to

	if _survey_mesh == null:
		_survey_mesh = MeshInstance3D.new()
		_survey_mesh.mesh = ImmediateMesh.new()
		_survey_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_survey_green = _survey_material(Color(0.2, 1.0, 0.25))
		_survey_red = _survey_material(Color(1.0, 0.15, 0.1))
		_root.add_child(_survey_mesh)

	survey_line_red = survey_blocked(_grade_a, to)
	var from: Vector3 = _grade_a
	var flat: float = Vector2(to.x - from.x, to.z - from.z).length()
	var n: int = clampi(int(ceil(flat / SURVEY_LINE_STEP_M)), 1, SURVEY_LINE_RAYS)
	var side: Vector3 = Vector3(-(to.z - from.z), 0.0, to.x - from.x).normalized() * (SURVEY_LINE_WIDTH_M * 0.5) if flat > 0.01 else Vector3(SURVEY_LINE_WIDTH_M * 0.5, 0.0, 0.0)
	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var mesh: ImmediateMesh = _survey_mesh.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _survey_red if survey_line_red else _survey_green)

	for k in range(n + 1):
		var t: float = float(k) / float(n)
		var p: Vector3 = from.lerp(to, t)

		var down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 60.0, 0.0), p - Vector3(0.0, 60.0, 0.0))

		for attempt in 3:   # a tree's trunk is looked through (the road goes through it); the top of a rock or a log is not: the line lies over it
			var ground: Dictionary = space.intersect_ray(down)

			if ground.is_empty():
				break

			if ground["collider"] != null and ground["collider"].has_meta("species_ids"):
				var skip: Array[RID] = down.exclude
				skip.append(ground["rid"])
				down.exclude = skip
				continue

			p.y = float(ground["position"].y)
			break

		p.y += SURVEY_LINE_LIFT_M
		mesh.surface_add_vertex(p - side)
		mesh.surface_add_vertex(p + side)

	mesh.surface_end()
	_survey_mesh.global_transform = Transform3D.IDENTITY
	_survey_mesh.visible = true


func _survey_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1
	return mat


# The server refused the last marker (a building it knows of that this client does not, or too many waiting): the line goes on from the survey's last kept marker.
func _on_survey_refused(last: Vector3) -> void:
	if not _grade_has_a or not _hoe_in_hand():
		return   # the survey was ended (or the hoe put away) meanwhile

	_grade_a = last
	_grade_has_a = true
	_survey_to = Vector3.INF


# The server says the road builder has reached (or dropped) a marker: its red flag comes down.
func _on_road_marker_reached(at: Vector3) -> void:
	for stake in _stakes.duplicate():
		if not is_instance_valid(stake):
			_stakes.erase(stake)
		elif Vector2(stake.global_position.x - at.x, stake.global_position.z - at.z).length() < 0.6:
			stake.queue_free()
			_stakes.erase(stake)


# A hoe stroke (path or smooth) at the ground under the crosshair; the server checks the hoe, the reach and the pace.
func _hoe_here(action: int, b: int = 0) -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit["collider"].has_meta("species_ids"):
		_inv._on_notice("Nothing to work there: aim the hoe at the ground within reach")
		return

	_net.inventory_action.rpc_id(1, action, held_slot, b, 0, hit["position"])

	# The hoe was silent (first-day tool audit, 3 Nov 2026): a soft scrape of the blade on the soil (a garden till is firmer, _till_garden_here). Played when the click is sent, like the
	# shovel fill (the server may still refuse). It borrows the shovel-on-soil clips (no hoe recording yet).
	if _sound != null:
		_sound.hits.hit("shovel", "soil", hit["position"], 0.4)


# The hoe grid (Dave 14 Nov 2026; BugsList_Current.md entry 6, 18 Nov 2026): one grid of markers for Plant, Till Garden Grid and Till Soil 2m, garden_w across by
# garden_d along (Alt + arrow keys, 1 to FarmRules.GRID_MAX_SIDE; Till Soil 2m is always 2 by 2), turned garden_yaw degrees (the wheel). Unturned, a 1 m grid sits on
# the world's metre cells; aimed at a bed, a seed grid lines up on that bed. The server decides every marker: the preview asks it (a check request, answered by
# hoe_verdict) whenever the grid changes, and colours the markers by the answer, neon green where the click will work and red where it will not (a tree, a large
# rock, a building or the ground round it, too steep for the blend; for a plant: no tilled soil for a crop, a bed for a bush). One left click then does the whole
# grid on the server. Before the first answer the markers are green.
var garden_w: int = 1
var garden_d: int = 1
var garden_yaw: int = 0                  # degrees, the way a structure's yaw turns
var _garden_box: BoxMesh = null           # the till grid's square marks
var _garden_dot: SphereMesh = null        # the Plant grid's dots
var _grid_yaw: int = 0                    # the turn the grid was last drawn at (garden_yaw, or a bed's)
var _garden_centre: Vector2 = Vector2.ZERO   # the last plan's grid centre (the click sends it)
var _verdict: Dictionary = {}            # the server's last hoe_verdict: {"kind", "code", "at", "state", "why", "cells"}
var _asked: Array = []                   # the last check sent: [kind, code, at]
var _asked_msec: int = 0
const GARDEN_ASK_MSEC := 300             # a changed grid is asked about at most this often (the server answers at most every 250 ms)
const GARDEN_REASK_MSEC := 1500          # and an unchanged one again this often (the world round it changes)
const GARDEN_COUNTDOWN_MS := 20000       # Dave: after a garden, 20 s before the next Garden Grid
var _garden_ready_msec: int = 0
var _countdown_label: Label = null


# What the click would send now for the grid round `aim`: {"kind" (ACT_TILL_GARDEN or ACT_PLANT_GRID), "code", "at", "number" (the plant's item), "points"
# (in the server's FarmRules.grid_points order), "step"}; {} when Plant has nothing picked or none of it left.
func _grid_request(aim: Vector3) -> Dictionary:
	var step: float = 1.0
	var w: int = garden_w
	var d: int = garden_d
	var kind: String = "till"
	var number: int = 0

	if hoe_mode == "soil":
		w = 2
		d = 2
	elif hoe_mode == "garden":
		number = _inv.table.number_of(garden_pick) if garden_pick != "" else 0
		var picked: Array = FarmRules.plantables(_inv.crop_table(), [garden_pick] if number > 0 and _inv.stock_fill(number) > 0 else [], "_bush", _inv.tree_seed_table())

		if picked.is_empty():
			return {}

		kind = str(picked[0]["kind"])
		step = FarmRules.spacing_of(kind, _inv.crop_table().get(FarmRules.crop_of_seed(_inv.crop_table(), garden_pick), {}) if kind == "seed" else {})

	var flat_aim: Vector2 = Vector2(aim.x, aim.z)
	var anchor: Variant = null
	var yaw: int = garden_yaw

	if kind == "seed":
		var beds: Array = _inv.bed_rows(aim, Vector2(float(w), float(d)).length() * step + 3.0)
		var under: int = _inv.bed_in(beds, aim)

		for row in beds:
			if int(row[0]) == under and under != 0:
				anchor = Vector2(row[1].x, row[1].z)   # line up on the bed aimed at...
				yaw = posmod(roundi(float(row[3])), 360)   # ...and turn with it, so a turned garden's beds and the seed grid match (tester report, QA #8)

	if anchor == null and (kind == "seed" or kind == "till") and yaw == 0 and is_equal_approx(step, roundf(step)):
		anchor = Vector2(floor(aim.x) + 0.5, floor(aim.z) + 0.5)   # unturned: on the world's metre cells, like the beds the server snaps

	# The grid's bottom left point at the crosshair (or the bed or metre cell under it), the grid running forward and to the right (Dave 24 Nov 2026):
	# centred on the aim, a big grid reached back behind the player where it could not be seen.
	_grid_yaw = yaw
	var corner: Vector2 = flat_aim

	if typeof(anchor) == TYPE_VECTOR2:
		corner = anchor

	var eye: Vector3 = _camera.global_position if _camera != null else aim
	_garden_centre = FarmRules.grid_from_corner(w, d, step, corner, yaw, Vector2(aim.x - eye.x, aim.z - eye.z))
	var at: Vector3 = Vector3(_garden_centre.x, aim.y, _garden_centre.y)

	if hoe_mode == "garden":
		return {"kind": Net.ACT_PLANT_GRID, "code": yaw * 10000 + w * 100 + d, "at": at, "number": number, "points": FarmRules.grid_points(w, d, step, _garden_centre, yaw), "step": step, "yaw": yaw}

	return {"kind": Net.ACT_TILL_GARDEN, "code": (10000 if hoe_mode == "soil" else 0) + w * 100 + d, "at": at, "number": 0, "points": FarmRules.grid_points(w, d, 1.0, _garden_centre, yaw), "step": 1.0, "yaw": yaw}


func _send_grid(request: Dictionary, check: bool) -> void:
	var code: int = int(request["code"]) + (10000000 if check else 0)

	if int(request["kind"]) == Net.ACT_PLANT_GRID:
		_net.inventory_action.rpc_id(1, Net.ACT_PLANT_GRID, held_slot, int(request["number"]), code, request["at"])
	else:
		_net.inventory_action.rpc_id(1, Net.ACT_TILL_GARDEN, held_slot, int(request.get("yaw", garden_yaw)), code, request["at"])


# The server's answer for the grid as `request` asks it, {} when it has not answered that one yet.
func _verdict_for(request: Dictionary) -> Dictionary:
	if _verdict.is_empty() or int(_verdict["kind"]) != int(request["kind"]) or int(_verdict["code"]) != int(request["code"]):
		return {}

	var at: Vector3 = _verdict["at"]
	return _verdict if Vector2(at.x - request["at"].x, at.z - request["at"].z).length() < 0.03 else {}


func _on_hoe_verdict(kind: int, code: int, at: Vector3, state: int, why: String, cells: PackedByteArray) -> void:
	_verdict = {"kind": kind, "code": code, "at": at, "state": state, "why": why, "cells": cells}

	if state == 2 and kind == Net.ACT_TILL_GARDEN and floori(float(code) / 10000.0) == 0:
		_garden_ready_msec = Time.get_ticks_msec() + GARDEN_COUNTDOWN_MS   # the garden is taken on: the grid gives way to the countdown


func garden_countdown_s() -> int:
	return maxi(ceili(float(_garden_ready_msec - Time.get_ticks_msec()) / 1000.0), 0)


# Plant (left click): the whole grid goes to the server, which plants every usable point from the supplies (server_items.plant_grid).
func _garden_here() -> void:
	var hit: Dictionary = _ground_under_crosshair()

	if hit.is_empty():
		_inv._on_notice("Aim the hoe at the ground or a bed within reach to plant")
		return

	var request: Dictionary = _grid_request(hit["position"])

	if request.is_empty():
		_inv._on_notice("Nothing to plant: right click and choose what to plant" if garden_pick == "" else "No %s left to plant: right click and choose another plant" % _inv.table.name_of(_inv.table.number_of(garden_pick)).to_lower())
		return

	_send_grid(request, false)
	_arm_play("use", 0.6)


# Till Garden Grid and Till Soil 2m (left click): the grid goes to the server, which checks the whole area, then levels, blends and tills it (server_items.till_garden).
func _till_garden_here() -> void:
	if hoe_mode == "till" and garden_countdown_s() > 0:
		_inv._on_notice("The next garden grid is ready in %d s" % garden_countdown_s())
		return

	var hit: Dictionary = _ground_under_crosshair()

	if hit.is_empty():
		_inv._on_notice("Aim the hoe at the ground within reach to mark out a garden")
		return

	var request: Dictionary = _grid_request(hit["position"])
	var known: Dictionary = _verdict_for(request)

	if not known.is_empty() and int(known["state"]) == 0 and str(known["why"]) != "":
		_inv._on_notice(str(known["why"]))   # the server would refuse it: say why without asking again
		return

	_send_grid(request, false)
	_arm_play("use", 0.6)

	if _sound != null:
		_sound.hits.hit("shovel", "soil", hit["position"], 0.7)


# Alt + arrow keys (KeyBindings garden_*): the hoe grid one point wider or narrower (`across`), longer or shorter (`along`). Returns true when it was used here.
func garden_resize(across: int, along: int) -> bool:
	if not _hoe_grid_on():
		return false

	if hoe_mode == "soil":
		_inv._on_notice("Till Soil 2m is always a 2 m patch")
		return true

	# across: Alt + Right / Left, the grid's reach to the player's right; along: Alt + Up / Down, its reach forward. The corner at the crosshair stays put and the
	# grid grows or shrinks away from it (Dave 24 Nov 2026), so the keys go to whichever of the grid's sides points right and forward as the player looks.
	var look: Vector3 = -_camera.global_transform.basis.z if _camera != null else Vector3(0.0, 0.0, -1.0)

	if FarmRules.across_is_right(_grid_yaw, Vector2(look.x, look.z)):   # the turn the grid is drawn at (a seed grid on a bed takes the bed's)
		garden_w = clampi(garden_w + across, 1, FarmRules.GRID_MAX_SIDE)
		garden_d = clampi(garden_d + along, 1, FarmRules.GRID_MAX_SIDE)
	else:
		garden_w = clampi(garden_w + along, 1, FarmRules.GRID_MAX_SIDE)
		garden_d = clampi(garden_d + across, 1, FarmRules.GRID_MAX_SIDE)

	_inv._on_notice("Hoe grid: %d by %d" % [garden_w, garden_d])
	return true


# Whether the hoe's grid is out (in hand, a tilling mode, or Plant with something picked, its list shut).
func _hoe_grid_on() -> bool:
	return _hoe_in_hand() and not _hoe_menu_open and (hoe_mode == "till" or hoe_mode == "soil" or (hoe_mode == "garden" and garden_pick != ""))


# The ground point under the crosshair within reach, {} for none (or a plant's collider).
func _ground_under_crosshair() -> Dictionary:
	var from: Vector3 = _camera.global_position
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M))
	return {} if hit.is_empty() or hit["collider"].has_meta("species_ids") else hit


# The grid preview: a flat marker on every point of the grid, neon green where the next click will work, red where it will not, faint green where a plant would
# go but the supplies run out first; after a garden, the countdown in its place. Redrawn ten times a second while a grid is out. PLACEHOLDER look.
var _garden_marks: Array = []            # MeshInstance3D pool
var _garden_mark_ok: StandardMaterial3D = null
var _garden_mark_bad: StandardMaterial3D = null
var _garden_mark_short: StandardMaterial3D = null
var _garden_preview_msec: int = 0
var garden_preview_cells: int = 0        # how many markers show now (tests read it)


func _garden_preview() -> void:
	_show_countdown()
	var on: bool = _hoe_grid_on() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not (hoe_mode == "till" and garden_countdown_s() > 0)

	if not on:
		if garden_preview_cells > 0:
			for mark in _garden_marks:
				mark.visible = false

			garden_preview_cells = 0

		return

	var now: int = Time.get_ticks_msec()

	if now < _garden_preview_msec:
		return

	_garden_preview_msec = now + 100
	var hit: Dictionary = _ground_under_crosshair()
	var request: Dictionary = _grid_request(hit["position"]) if not hit.is_empty() else {}
	var points: Array = request.get("points", [])

	if not request.is_empty():
		var key: Array = [int(request["kind"]), int(request["code"]), Vector2(request["at"].x, request["at"].z).snapped(Vector2(0.05, 0.05))]

		if (key != _asked and now - _asked_msec >= GARDEN_ASK_MSEC) or now - _asked_msec >= GARDEN_REASK_MSEC:
			if hoe_mode == "garden" and key == _asked:
				_inv.ask_stock_now()   # the supplies in reach change as the player walks: the plant count follows

			_asked = key
			_asked_msec = now
			_send_grid(request, true)

	var known: Dictionary = _verdict_for(request) if not request.is_empty() else {}

	if _garden_mark_ok == null:
		_garden_mark_ok = StandardMaterial3D.new()
		_garden_mark_ok.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_garden_mark_ok.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_garden_mark_ok.albedo_color = Color(0.25, 1.0, 0.2, 0.6)   # neon green (Dave)
		_garden_mark_bad = _garden_mark_ok.duplicate()
		_garden_mark_bad.albedo_color = Color(0.95, 0.2, 0.15, 0.55)
		_garden_mark_short = _garden_mark_ok.duplicate()
		_garden_mark_short.albedo_color = Color(0.25, 1.0, 0.2, 0.2)

	var side: float = minf(float(request.get("step", 1.0)), 1.0) * 0.8

	if _garden_box == null:
		_garden_box = BoxMesh.new()
		_garden_box.size = Vector3(1.0, 0.04, 1.0)
		_garden_dot = SphereMesh.new()   # Plant: a dot exactly where each seed or plant goes (Dave 24 Nov 2026), not a square
		_garden_dot.radius = 0.07
		_garden_dot.height = 0.14
		_garden_dot.radial_segments = 8   # a hundred dots stay cheap
		_garden_dot.rings = 4

	var dots: bool = hoe_mode == "garden"

	while _garden_marks.size() < points.size():
		var mark: MeshInstance3D = MeshInstance3D.new()
		mark.mesh = _garden_box
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(mark)
		_garden_marks.append(mark)

	var cells: PackedByteArray = known.get("cells", PackedByteArray())

	for n in _garden_marks.size():
		var mark: MeshInstance3D = _garden_marks[n]
		var flat: Vector2 = points[n] if n < points.size() else Vector2.ZERO
		var y: float = _terrain_y(flat.x, flat.y, hit["position"].y, 3.0) if n < points.size() else NAN
		mark.visible = n < points.size() and not is_nan(y)

		if not mark.visible:
			continue

		var on_bed: bool = _inv.bed_id_at(Vector3(flat.x, y, flat.y)) != 0
		mark.global_position = Vector3(flat.x, y + ((0.3 if on_bed else 0.08) if dots else (0.35 if on_bed else 0.05)), flat.y)   # over a bed or plot: above its frame
		mark.rotation.y = deg_to_rad(float(request.get("yaw", garden_yaw)))   # square with the grid (a seed grid turns with the bed it is on)
		if dots:
			mark.mesh = _garden_dot
		else:
			mark.mesh = _garden_box

		mark.scale = Vector3.ONE if dots else Vector3(side, 1.0, side)
		var state: int = 1

		if not known.is_empty():
			state = int(cells[n]) if n < cells.size() else (1 if int(known["state"]) != 0 else 0)

		if dots:
			mark.material_override = _garden_mark_ok if state == 1 else _garden_mark_bad   # green where the seeds reach, red past them (and where nothing can go)
		else:
			mark.material_override = _garden_mark_ok if state == 1 else (_garden_mark_short if state == 2 else _garden_mark_bad)

	garden_preview_cells = points.size()


# After a Garden Grid (Dave 18 Nov 2026): a 20 s countdown in medium red numbers at the middle of the screen takes the grid's place while the hoe is out in that
# mode; the next garden waits for it wherever the player goes.
func _show_countdown() -> void:
	var left: int = garden_countdown_s()
	var show: bool = left > 0 and _hoe_in_hand() and hoe_mode == "till" and not _hoe_menu_open and _hud_layer != null

	if show and _countdown_label == null:
		_countdown_label = Label.new()
		_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
		_countdown_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_countdown_label.grow_vertical = Control.GROW_DIRECTION_BOTH
		_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_countdown_label.add_theme_font_size_override("font_size", 44)
		_countdown_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.08))
		_countdown_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		_countdown_label.add_theme_constant_override("outline_size", 6)
		_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_layer.add_child(_countdown_label)

	if _countdown_label != null:
		_countdown_label.visible = show

		if show:
			_countdown_label.text = str(left)


# A shovel fill at the ground under the crosshair (right click): the server spends a shovelful and puts the ground back.
func _fill_here() -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit["collider"].has_meta("species_ids"):
		_inv._on_notice("Nothing to fill there: aim the shovel at the ground within reach")
		return

	_net.inventory_action.rpc_id(1, Net.ACT_FILL, held_slot, 0, 0, hit["position"])

	if _sound != null:
		_sound.placed.shovel_load(fill_is_stony(_fill_order(), func(n: String) -> int: return _inv.inventory.count_of(_inv.table.number_of(n))), hit["position"])   # played when the click is sent (the server may still refuse)


const STONY_FILL := ["gravel", "stone"]   # these scoop with the stone sound, soil, sand and clay with the soil one
var _fill_names: Array = []


# What the server fills with: the first of digging.json "fill" the pack holds (server_items._fill takes the same order).
static func fill_is_stony(order: Array, count_of: Callable) -> bool:
	for item in order:
		if int(count_of.call(str(item))) > 0:
			return STONY_FILL.has(str(item))

	return false


func _fill_order() -> Array:
	if _fill_names.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/digging.json"))
		_fill_names = (parsed.get("fill", []) as Array) if typeof(parsed) == TYPE_DICTIONARY else []

	return _fill_names


var raise_mode: bool = false              # the shovel raises ground (Dave 2026-10-22); false digs


func _other_tool_hint() -> String:
	match str(_inv.table.entry(held_id()).get("tool_class", "")):
		"rod":
			return "Click at the water to cast, and click again when something bites"
		"net":
			return "Stand at the water's edge facing the water and hold the left button for about 20 seconds"
		"hoe":
			return "The hoe does what its mode says (left click; now: %s). Right click opens a window to pick: path, smooth, till a garden, survey a path, plant something (seeds, a dug-up bush or a tree's seed from your pack) or dig an irrigation trench. With a garden grid out, Alt + arrow keys size it and the wheel turns it. Only planting uses items" % _hoe_mode_name()
		"hammer":
			return "Right click opens the hammer menu: pick a blueprint, then left click places it"
		"shovel":
			return "The shovel digs roots and bulbs (press E at a plant), digs the ground (left click) or raises it in Raise mode (right click switches; each raise uses soil, sand, gravel, clay or stone from your pack)"

	return "%s: nothing to use it on yet" % _inv.table.name_of(held_number())


# The line over the hotbar. Dave 10 Nov 2026: it does not name what is in hand ("it doesnt need to say wooden bow in hand. or anything"), so it
# shows only a state the player has to know: the picked blueprint and why it is red, the hammer's mode, why a placement is red, and the
# shovel's or hoe's mode. Empty otherwise.
func _caption() -> String:
	if held_number() == 0:
		return ""

	if _blueprinting():
		var short: bool = not blueprints.can_afford(_build_tier())
		var text: String = "%s blueprint" % blueprints.name_of(blueprints.picked) if blueprints.plan_picked < 0 else "%s (%d pieces)" % [blueprints.plans.plans[blueprints.plan_picked]["name"], blueprints.plans.plans[blueprints.plan_picked]["pieces"].size()]

		if _reason() != "":
			return text + "   (red: %s)" % _reason()

		if wheel_note != "":
			text += "   (%s)" % wheel_note

		if short and blueprints.plan_picked >= 0:
			return text + "   (red: not enough materials; right click: the list)"

		return text + "   (left click: set down a blue blueprint, then hit it with a hammer to add the materials; right click: the list)"   # placing never takes materials (Dave 18 Nov 2026)

	if _hammer_tier() > 0 and blueprints.mode == "repair":
		return "Repair: left click a worn piece to mend it, or a blueprint to fill it from all around you; right click: the menu"

	if _hammer_tier() > 0 and blueprints.mode == "save":
		return "Save building plan: left click a building to keep it; right click: the menu"

	if _is_placeable() and _reason() != "":
		return "Red: %s" % _reason()

	if _is_placeable() and wheel_note != "":
		return wheel_note

	var tool_class: String = str(_inv.table.entry(held_id()).get("tool_class", "")) if _is_other_tool() else ""

	if tool_class == "shovel":
		return "%s (right click switches)" % ("Raise" if raise_mode else "Dig")

	if _pipe_hand():
		return _pipe_caption()

	if tool_class == "hoe":
		return "%s (right click: choose what it does)" % _hoe_mode_name()

	return ""


func _hoe_mode_name() -> String:
	if hoe_mode == "garden":
		return "Plant %s, %d by %d, turned %d degrees (Alt + arrows: rows and columns; wheel: turn)" % [_inv.table.name_of(_inv.table.number_of(garden_pick)).to_lower(), garden_w, garden_d, garden_yaw] if garden_pick != "" else "Plant: choose what to plant"

	if hoe_mode == "till":
		return "Till Garden Grid - 20m Edge Blend, %d by %d, turned %d degrees (Alt + arrows: size; wheel: turn)%s" % [garden_w, garden_d, garden_yaw, "; ready in %d s" % garden_countdown_s() if garden_countdown_s() > 0 else ""]

	for mode in HOE_MODES:
		if str(mode["id"]) == hoe_mode:
			return str(mode["name"])

	return "Level"


func _show_model() -> void:
	var number: int = held_number() if _inv != null else 0

	if not _is_spear() and not _is_axe() and not _is_torch() and not _is_knife() and not _is_other_tool() and not _is_placeable() and not _is_look_item():
		number = 0

	if number != 0 and _left_number() == number and off_number() == 0:
		number = 0      # a torch taken as the main item is drawn in the left hand in third person (_left_number)

	if number != 0 and _held_torch_out():
		number = -number   # the same torch out is drawn again, without its flame

	if number == _shown_number:
		return

	_shown_number = number

	if _model != null:
		_model.queue_free()
		_model = null

	if number != 0:
		_model = _make_look_model() if _is_look_item() else _make_kit_model() if _is_placeable() else _make_spear_model() if _is_spear() else (_make_torch_model("", _held_torch_out()) if _is_torch() else (_make_knife_model() if _is_knife() else (_make_other_model() if _is_other_tool() else _make_axe_model())))
		_mount_model()


# Put the model in the hand: its business end leads along the fingers (-Z of the mount) and the grip sits in the palm.
# Falls back to the old spot in front of the camera when there are no arms.
func _mount_model() -> void:
	_mounted = _arms != null
	var third_fist: Node3D = _model.get_node_or_null(THIRD_FIST_NAME) as Node3D

	if third_fist != null:
		third_fist.visible = false      # shown again by _mount_model_third
	var kind: String = "kit" if (_is_placeable() or _is_look_item()) else "spear" if _held_as_shaft() else ("torch" if _is_torch() else ("knife" if _is_knife() else ("axe" if _is_axe() else "other")))

	if not _mounted:
		_camera.add_child(_model)
		_model.position = REST
		return

	# The bow is held in the left hand (a right-handed archer: the left arm holds the bow out, the right hand draws the string). _pose_bow places it every frame.
	if _model.has_meta("bow"):
		var bow_hand: Node3D = _avatar_rig.hand_mount_l if not _first_person and _avatar_rig != null and _avatar_rig.hand_mount_l != null else _arms.hand_mount_l
		bow_hand.add_child(_model)
		return

	if not _first_person and _avatar_rig != null and _avatar_rig.hand_mount_r != null:
		_mount_model_third(kind)
		return

	_arms.hand_mount_r.add_child(_model)

	if kind == "spear":
		_aim_spear()   # placed every frame from the view, not along the fingers
		return

	var tilt: Basis = Basis(Vector3.RIGHT, deg_to_rad(TOOL_TILT_DEG if kind == "kit" else TOOL_TILT_SLIGHT_DEG))
	var turn: Basis = Basis.IDENTITY
	var grip: Vector3

	if kind == "kit":
		grip = Vector3(0.0, -0.03, -0.14)   # carried in the palm, a little ahead of the hand
	else:
		turn = Basis(Vector3.RIGHT, deg_to_rad(-90.0))   # +Y (handle to head) becomes -Z (along the fingers)

		if str(_inv.table.entry(held_id()).get("tool_class", "")) == "hoe":
			turn = turn * Basis(Vector3.UP, deg_to_rad(HELD_HOE_ROLL_DEG))   # roll the hoe about its haft so the blade face shows in the frame (Tyler: first person read as a stick)
		grip = Vector3(0.0, 0.0, -float(_model.get_meta("grip_y", GRIP_ALONG_Y[kind])))

		if _model.has_meta("held_pitch_deg"):
			turn = Basis(Vector3.RIGHT, deg_to_rad(float(_model.get_meta("held_pitch_deg")))) * turn   # point the tip up into the view
			grip.y += 0.05

	_model.basis = (tilt * turn).scaled(Vector3.ONE / ARMS_SCALE)      # the hand mount is scaled with the arms
	_model.position = tilt * grip / ARMS_SCALE


# Head-down along the outside of the leg (pitch about the mount's X, then roll about its forward +Y): the model's +Y (handle to head) points down, THIRD_HANG_FWD_DEG forward (more for a head reach metres
# from the hand longer than THIRD_HANG_DROP_M, never past the forward lean, 90 + THIRD_LEAN_DEG) and THIRD_OUT_DEG out (+X).
static func third_hang_turn(reach: float) -> Basis:
	var forward: float = THIRD_HANG_FWD_DEG

	if reach > THIRD_HANG_DROP_M:
		forward = clampf(rad_to_deg(acos(THIRD_HANG_DROP_M / reach)), THIRD_HANG_FWD_DEG, 90.0 + THIRD_LEAN_DEG)

	return Basis(Vector3.UP, deg_to_rad(-THIRD_OUT_DEG)) * Basis(Vector3.RIGHT, deg_to_rad(forward - 90.0))


# The carry class third_hold reads: the item's tool_class, or for a weapon without one, its look's shape (a sword, mace or war hammer).
static func third_carry(item_id: String, tool_class: String) -> String:
	if tool_class != "":
		return tool_class

	return str(THIRD_SHAPE_CARRY.get(str(BasicLook.entry(item_id).get("shape", "")), ""))


# The share of the grip distance (middle to grip point) the third-person hand takes on a tool of this tool_class.
static func third_choke(tool_class: String) -> float:
	return 1.0 if tool_class in THIRD_FULL_GRIP else THIRD_CHOKE


# Third person: the hand hangs at the side (mount -Z down the fingers, +Y forward, +Z up), so a tool is turned to stand up and a little forward.
func _mount_model_third(kind: String) -> void:
	_avatar_rig.hand_mount_r.add_child(_model)

	if kind == "spear":
		_aim_spear()
		return

	third_hold(_model, kind, third_carry(held_id(), str(_inv.table.entry(held_id()).get("tool_class", ""))))

	if kind != "kit":
		_third_fist().visible = true


# The held model's place in the third-person hand mount (mount -Z down the fingers, +Y forward, +Z up). Static so tools/shot_held.gd poses a
# held item exactly as the game does.
static func third_hold(model: Node3D, kind: String, carried: String) -> void:
	var turn: Basis = Basis(Vector3.RIGHT, deg_to_rad(THIRD_LEAN_DEG))
	var grip: Vector3 = Vector3(0.0, float(model.get_meta("grip_y", GRIP_ALONG_Y.get(kind, 0.0))) * third_choke(carried), 0.0)   # the hand sits grip below the model middle, on the handle end (Dave 2026-10-22: it was held by the head)
	var reach: float = grip.y + float(model.get_meta("head_m", 0.0))   # hand to the head's far end

	if carried in THIRD_STAFF_CARRIES and model.has_meta("head_m"):
		grip.y = clampf(THIRD_STAFF_REACH_M - float(model.get_meta("head_m")), 0.03, grip.y / maxf(third_choke(carried), 0.01))   # on the haft, never past its grip end
		turn = third_hang_turn(0.0) * Basis(Vector3.UP, PI)   # the blade (model -Z) turned to face forward
	elif carried in THIRD_HANG_CARRIES and model.has_meta("head_m"):
		turn = third_hang_turn(reach)
	elif carried in THIRD_HANG_CARRIES or carried in THIRD_EDGE_CARRIES:
		turn = Basis(Vector3.BACK, deg_to_rad(-THIRD_OUT_DEG)) * turn   # about the mount's up axis: the head turns out to +X

	if carried == "saw":
		turn = Basis(Vector3.RIGHT, deg_to_rad(THIRD_SAW_PITCH_DEG))
	elif carried == "rod":
		turn = Basis(Vector3.RIGHT, deg_to_rad(THIRD_ROD_PITCH_DEG))

	if kind == "kit":
		turn = Basis.IDENTITY
		grip = Vector3(0.0, -0.03, -0.14)

	model.basis = turn
	model.position = turn * grip


# A spear is held as a spear, not a knife (TEST-004, Dave's playtest 12 Nov 2026): the shaft runs through the fist pointing ahead, the hand
# SPEAR_GRIP_Z behind the model's middle, whatever the hand bone's own angle (the jab clip is a punch, which turned a spear laid along the
# fingers into a dagger grip). Third person: the body's facing (the avatar root faces -Z, as the game does), lifted SPEAR_LIFT_DEG. First
# person: the facing tipped down SPEAR_REST_DOWN_DEG at rest, so the spear hangs below the view with the arms (Dave 21 and 25 Oct: the arms
# show only when working or looking down), turning to the view as the arms come up to jab or aim (_arm_up). Placed every frame after the arms.
const SPEAR_LIFT_DEG := 8.0
const SPEAR_REST_DOWN_DEG := 35.0


func _aim_spear() -> void:
	if _model == null or not _mounted or not _held_as_shaft() or not _model.is_inside_tree():
		return

	var mount: Node3D = _model.get_parent() as Node3D
	var lift: Vector3 = Vector3.UP * tan(deg_to_rad(SPEAR_LIFT_DEG))
	var tip: Vector3

	if _first_person:
		var rest: Vector3 = Basis(Vector3.UP, _camera.global_rotation.y) * Basis(Vector3.RIGHT, -deg_to_rad(SPEAR_REST_DOWN_DEG)) * Vector3.FORWARD
		tip = rest.slerp(-_camera.global_transform.basis.z, clampf(_arm_up, 0.0, 1.0))
	else:
		var avatar: Node3D = _avatar_rig as Node3D

		if avatar == null:
			return

		var front: Vector3 = avatar.global_basis * Vector3.FORWARD
		front.y = 0.0

		if front.length_squared() < 1e-12:
			return

		tip = (front.normalized() + lift).normalized()

	var z: Vector3 = -tip                                          # the spear's point is its model -Z
	var x: Vector3 = (Vector3.UP if absf(tip.y) < 0.99 else Vector3.BACK).cross(z).normalized()
	_model.global_transform = Transform3D(Basis(x, z.cross(x), z), mount.global_position + tip * SPEAR_GRIP_Z)

	if not _first_person:
		_third_fist().visible = true


# Third person (Dave 5 Nov, decision card): the body's hand has no finger bones and hung open under the handle, so a closed fist is drawn round the grip. It is a child of
# the held model (it goes when the tool goes) placed back at the hand mount's origin, where the handle crosses the hand (dynasty_body.gd GRIP_FROM_WRIST_M), and long
# enough along the fingers to hide the open hand. First person has its own fists on the arms (_make_fist), so this one is hidden there.
const THIRD_FIST_NAME := "ThirdFist"
const THIRD_FIST_SCALE := Vector3(1.0, 0.85, 1.6)     # 10 cm across, 8.5 cm thick, 16 cm along the fingers (the hand mesh runs 0 to 19 cm from the wrist)


func _third_fist() -> MeshInstance3D:
	return _third_fist_on(_model)


# The same closed fist on any held model (the left-hand torch too).
func _third_fist_on(model: Node3D) -> MeshInstance3D:
	return third_fist_on(model, _third_skin_color())


static func third_fist_on(model: Node3D, skin_color: Color) -> MeshInstance3D:
	var fist: MeshInstance3D = model.get_node_or_null(THIRD_FIST_NAME) as MeshInstance3D

	if fist == null:
		fist = MeshInstance3D.new()
		fist.name = THIRD_FIST_NAME
		var ball: SphereMesh = SphereMesh.new()
		ball.radius = 0.05
		ball.height = 0.1
		ball.radial_segments = 12
		ball.rings = 6
		var skin: StandardMaterial3D = StandardMaterial3D.new()
		skin.albedo_color = skin_color
		skin.roughness = 0.64          # the body's own skin roughness (Dave's glb, the metallic-roughness texture's median)
		skin.metallic_specular = 0.35
		ball.material = skin
		fist.mesh = ball
		model.add_child(fist)

	fist.transform = model.transform.affine_inverse() * Transform3D(Basis.from_scale(THIRD_FIST_SCALE), Vector3.ZERO)

	if not fist.has_meta("ball"):
		fist.set_meta("ball", fist.mesh)

	var on: Node = model.get_parent()

	if on != null and int(fist.get_meta("closes_on", 0)) != on.get_instance_id():
		fist.set_meta("closes_on", on.get_instance_id())   # looked up once per hand the model is on (the spear refits its fist every frame; a model can move from the arms to the body)
		fist.set_meta("hand_closes", hand_closes(model))

	var mesh: Mesh = null if bool(fist.get_meta("hand_closes", false)) else fist.get_meta("ball")   # a body that closes its own hand on the grip (dynasty_grip.gd, BugsList 177) needs no ball

	if fist.mesh != mesh:
		fist.mesh = mesh
	return fist


# Whether the body holding `model` closes its own hand round the grip (dynasty_body.gd's Grip modifier, BugsList 177), so the ball fist is not drawn. A body
# without one (no glb, the old bodies) keeps the ball. The model must be on its hand mount already.
static func hand_closes(model: Node3D) -> bool:
	if not GripScript.closes:
		return false

	var at: Node = model.get_parent()

	while at != null:
		if at.get("grip") is SkeletonModifier3D:
			return true

		at = at.get_parent()

	return false


# The third-person fist's colour (Dino's #488 look, 6 Nov 2026: the grip read as a pale blob): the body's painted skin, not the first-person arms' FIST_COLOR.
# THIRD_SKIN is the median of Dave's skin texture (Dynasty_Base_Male.glb, sRGB), times the skin tint the body wears for this character (dynasty_body.gd dress).
const THIRD_SKIN := Color(0.718, 0.498, 0.376)


func _third_skin_color() -> Color:
	var tint: Color = Color.WHITE
	var worn: Variant = _avatar_rig.get("_skin_material") if _avatar_rig != null else null

	if worn is BaseMaterial3D:
		tint = (worn as BaseMaterial3D).albedo_color

	return Color(THIRD_SKIN.r * tint.r, THIRD_SKIN.g * tint.g, THIRD_SKIN.b * tint.b)


# The left-hand item: a torch (with its light) or a shield, mounted on the left hand; B (KeyBindings "block") raises a shield.
func _show_off_model(delta: float) -> void:
	var number: int = _left_number() if _inv != null else 0
	blocking = number != 0 and _off_class() == "shield" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and KeyBindings.held("block")
	var shown: int = -number if number != 0 and _slot_out(_left_slot()) else number   # a torch that went out is drawn again, without its flame

	if shown != _off_shown:
		_off_shown = shown

		if _off_model != null:
			_off_model.queue_free()
			_off_model = null

		if number != 0:
			_off_model = _make_shield_model() if _off_class() == "shield" else (_make_lantern_model(_left_id()) if _lantern_in_left() else _make_torch_model(_left_id(), _slot_out(_left_slot())))
			_mount_off_model()

	if _off_model == null:
		return

	var flicker: OmniLight3D = _off_model.get_node_or_null("Light")
	var lantern: bool = _lantern_in_left()

	if flicker != null:
		flicker.visible = rig_lit or not held_light_budget.is_valid() or held_light_budget.call() or not _inv.fire_light_near(_camera.global_position, 8.0)
		# A lantern's flame is behind horn: it barely flickers.
		flicker.light_energy = (1.6 + 0.06 * sin(float(Time.get_ticks_msec()) * 0.011)) if lantern else FlameRules.TORCH_LIGHT_ENERGY + FlameRules.TORCH_LIGHT_FLICKER * sin(float(Time.get_ticks_msec()) * 0.017)

	if lantern:
		_hang_lantern()

	if _off_class() == "torch" and not _first_person and _avatar_rig != null and _off_model.get_parent() == _avatar_rig.hand_mount_l:
		_stand_torch_upright()

	if _off_class() == "shield":
		var lift: float = 1.0 if blocking else 0.0
		_off_model.position = _off_model.position.lerp(_off_rest + Vector3(0.0, 0.0, -0.18 * lift), clampf(delta * 16.0, 0.0, 1.0))


var _off_rest: Vector3 = Vector3.ZERO


# A carried lantern in the left hand (items.json tool_class "lantern", or "lantern_dark" when it is out).
func _lantern_in_left() -> bool:
	return _inv != null and _left_number() != 0 and _off_class().begins_with("lantern")


# A lantern hangs straight down from the fist by its bail whatever the hand's angle (first person and third): the model sits at the hand mount, upright in
# the world. In first person without arms it stays at its rest spot by the camera.
func _hang_lantern() -> void:
	if not _off_model.is_inside_tree():
		return

	if _off_model.get_parent() != _camera:
		_off_model.position = Vector3.ZERO

	_off_model.global_basis = Basis.IDENTITY
	var fist: Node3D = _off_model.get_node_or_null(THIRD_FIST_NAME) as Node3D

	if fist != null and fist.visible:
		_third_fist_on(_off_model)   # the fist stays on the hand mount, round the bail

const TORCH_LEAN := 0.12      # third-person torch carry: the shaft leans this much forward and this much out to the left per metre up (about 7 degrees each)


# Third person, torch in the left hand (Dave's torch carry infographic, 6 Nov 2026): the torch stands upright in the world, leaning a little forward and out
# from the body, whatever the hand's own angle, with the grip in the fist. The arm pose that puts the hand up in front is the body's (dynasty_body.gd _torch_carry).
func _stand_torch_upright() -> void:
	if stand_torch(_off_model, _avatar_rig):
		_third_fist_on(_off_model).visible = true


# The same for any torch `model` in `rig`'s left hand (another player's too: player_view.gd).
static func stand_torch(model: Node3D, rig: Node3D) -> bool:
	var skel: Node3D = rig.get("skeleton") as Node3D if rig != null else null
	var mount: Node3D = rig.get("hand_mount_l") as Node3D if rig != null else null

	if skel == null or mount == null or model == null or not mount.is_inside_tree():
		return false

	var front: Vector3 = skel.global_basis * Vector3.BACK      # the Dynasty skeleton faces +Z, its left is +X
	var left: Vector3 = skel.global_basis * Vector3.RIGHT
	front.y = 0.0
	left.y = 0.0

	if front.length() < 0.001 or left.length() < 0.001:
		return false

	front = front.normalized()
	left = left.normalized()
	var shaft: Vector3 = (Vector3.UP + front * TORCH_LEAN + left * TORCH_LEAN).normalized()
	var across: Vector3 = shaft.cross(front).normalized()
	var upright: Basis = Basis(across, shaft, across.cross(shaft).normalized())
	var grip: float = float(model.get_meta("grip_y", GRIP_ALONG_Y["torch"])) * THIRD_CHOKE
	model.global_transform = Transform3D(upright, mount.global_position + shaft * grip)
	var fist: Node3D = model.get_node_or_null(THIRD_FIST_NAME) as Node3D

	if fist != null:
		fist.transform = model.transform.affine_inverse() * Transform3D(Basis.from_scale(THIRD_FIST_SCALE), Vector3.ZERO)

	return true


# Same grips as the right hand, on the left mount (first person arms, or the body in third person).
func _mount_off_model() -> void:
	var shield: bool = _off_class() == "shield"
	var mount = null

	if not _first_person and _avatar_rig != null:
		mount = _avatar_rig.hand_mount_l
	elif _arms != null:
		mount = _arms.hand_mount_l

	if mount == null:
		_camera.add_child(_off_model)
		_off_rest = Vector3(-0.35, -0.3, -0.55)
		_off_model.position = _off_rest
		return

	mount.add_child(_off_model)
	var grip: float = 0.0 if shield else float(GRIP_ALONG_Y["torch"])
	var third_fist: Node3D = _off_model.get_node_or_null(THIRD_FIST_NAME) as Node3D

	if third_fist != null:
		third_fist.visible = false      # first person has the arms' own fist

	if not _first_person and _avatar_rig != null:
		# Dave's body's hand mount: +Y forward, +Z up the forearm (dynasty_body.gd _mount). The old 60 degrees (set for the ragdoll body) laid the torch
		# along the forearm, its head and flame hidden by the hip (Dave 5 Nov, K camera shot). It now points forward and THIRD_TORCH_RAISE_DEG up, clear of the body,
		# and the hand closes round it as round a right-hand tool.
		var stand: Basis = Basis.IDENTITY if shield else Basis(Vector3.RIGHT, deg_to_rad(THIRD_TORCH_RAISE_DEG))
		_off_model.basis = stand
		_off_rest = stand * Vector3(0.0, grip * THIRD_CHOKE, 0.0)

		if not shield:
			_off_model.position = _off_rest
			_third_fist_on(_off_model).visible = true
	else:
		var tilt: Basis = Basis(Vector3.RIGHT, deg_to_rad(TOOL_TILT_DEG))
		var turn: Basis = Basis.IDENTITY if shield else Basis(Vector3.RIGHT, deg_to_rad(-90.0))
		_off_model.basis = tilt * turn
		_off_rest = tilt * Vector3(0.0, 0.0, -grip)

	_off_model.position = _off_rest


# A plain round shield (placeholder until art supplies one): a wooden disc with an iron boss, face along -Z of the hand.
func _make_shield_model() -> Node3D:
	var node: Node3D = Node3D.new()
	var disc: MeshInstance3D = MeshInstance3D.new()
	var plate: CylinderMesh = CylinderMesh.new()
	plate.top_radius = 0.28
	plate.bottom_radius = 0.28
	plate.height = 0.035
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.32, 0.18)
	plate.material = wood
	disc.mesh = plate
	disc.rotation.x = deg_to_rad(90.0)
	node.add_child(disc)
	var boss: MeshInstance3D = MeshInstance3D.new()
	var dome: SphereMesh = SphereMesh.new()
	dome.radius = 0.07
	dome.height = 0.09
	var iron: StandardMaterial3D = StandardMaterial3D.new()
	iron.albedo_color = Color(0.4, 0.4, 0.42)
	iron.metallic = 0.7
	dome.material = iron
	boss.mesh = dome
	boss.position = Vector3(0.0, 0.0, -0.03)
	node.add_child(boss)
	return node


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

	if id == "mortar_pestle":
		var bowl: MeshInstance3D = MeshInstance3D.new()   # the stone bowl with its pestle, carried at 70 percent (MORTAR_PESTLE.md MP-1: a placed station, carried like a kit)
		bowl.mesh = BasicLook.mesh_for(id)
		bowl.scale = Vector3.ONE * 0.7
		node.add_child(bowl)
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


# How far the hand sits from a held look's origin, toward its handle end (-x): a little in from that end (looks.json grip_from_end_m: on a model's own handle).
static func look_grip_y(held: Mesh, def: Dictionary, held_scale: float) -> float:
	return maxf(-held.get_aabb().position.x * held_scale - float(def.get("grip_from_end_m", HELD_GRIP_FROM_END_M)), 0.03)


# A tool or weapon whose look has no hand pose of its own (HELD_LOOK_TURN: a crossbow, a sling, a whetstone, a griddle, a needle,
# a bone club) is held as its own ground look, length along the hand's +Y like an axe's haft, near its -x end. Before, it got the grey box on a
# stick (_make_other_model's last resort), which read as a hammer: the picture checker's held sweep, 26 Nov 2026 (10 items). A grey placeholder
# look (BasicLook._is_placeholder) keeps the old stick: it is no better.
const PLAIN_HELD_TURN := Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
const PLAIN_HELD_KINDS := ["tool", "weapon"]   # not containers: a pot, bucket or skin stands up along its mesh +Y, and the own hand draws them as _make_container_model


static func holds_plain_look(item_id: String, kind: String) -> bool:
	var def: Dictionary = BasicLook.entry(item_id)
	return kind in PLAIN_HELD_KINDS and not def.is_empty() and not HELD_LOOK_TURN.has(str(def.get("shape", ""))) and not BasicLook._is_placeholder(def)


# A held look tool's model: its ground mesh turned and sized for the hand, the grip distance in the "grip_y" meta (see _mount_model). Static so
# tools/shot_held.gd builds the same model; the bow and the net add their own parts in _make_look_tool_model.
static func look_tool_node(item_id: String) -> Node3D:
	var def: Dictionary = BasicLook.entry(item_id)
	var shape: String = str(def.get("shape", ""))
	var held: Mesh = BasicLook.mesh_for(item_id)
	var length: float = held.get_aabb().size.x
	var held_scale: float = HELD_SPEAR_SCALE if shape == "shaft" else (HELD_FIXED_SCALE[shape] if HELD_FIXED_SCALE.has(shape) else minf(HELD_LOOK_SCALE, HELD_LOOK_MAX_M / maxf(length, 0.01)))
	var node: Node3D = Node3D.new()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = held
	mesh.basis = (HELD_LOOK_TURN.get(shape, PLAIN_HELD_TURN) as Basis) * Basis.from_scale(Vector3(1.0, 2.0, 2.0) * held_scale if shape == "arrow" else Vector3.ONE * held_scale)   # an arrow's shaft is drawn twice as thick in hand, or it is a hairline on screen
	node.add_child(mesh)
	node.set_meta("grip_y", look_grip_y(held, def, held_scale))
	node.set_meta("head_m", maxf(held.get_aabb().end.x, 0.0) * held_scale)   # model origin to the head's far end along the hand (third_hold: how low a hanging head comes)
	return node


# Any other tool: a handle with a flat blade (a shovel) or a plain head, until the tool has its own model.
# The ground mesh of a held tool, turned and sized for the hand, or null when the item has no tool look (it keeps its old model).
# The grip distance from the model middle goes in the "grip_y" meta (see _mount_model).
func _make_look_tool_model() -> Node3D:
	var def: Dictionary = BasicLook.entry(held_id())
	var shape: String = str(def.get("shape", ""))

	if not HELD_LOOK_TURN.has(shape):
		return null

	if shape == "hand_net":
		return _make_hanging_net_model(def)

	var node: Node3D = look_tool_node(held_id())
	var mesh: MeshInstance3D = node.get_child(0) as MeshInstance3D

	if shape == "bow":
		node.set_meta("grip_y", 0.03)   # a bow is held at its middle
		# The hand's bow has no string in its mesh: two thin cords from the tips to the nock point, which follows the drawing hand (_pose_bow).
		mesh.mesh = BasicLook.mesh("bow", Color.html(str(def.get("color", "#a8804a"))), float(def.get("size", 1.0)), (def.get("bits", []) as Array) + ["held"])
		mesh.basis = Basis.IDENTITY
		node.set_meta("bow", true)
		node.set_meta("nock", Vector3.ZERO)   # the nock point in the bow's own space (mesh axes: limbs along x, back of the bow toward +z)

		add_bow_parts(node)

	if shape == "arrow":
		node.set_meta("held_pitch_deg", 30.0)
		node.set_meta("grip_y", 0.1)   # an arrow is held about its middle, so the head and the shaft show in the view

	return node


# The shore net in the hand (Kathleen's check 4 Nov, net_held_right.png: held sideways and small): the hand closes on the coil and the bell hangs below it on its line,
# mouth down, at its real size. The model's "hang" meta makes _hang_net keep it upright with the world every frame, turned only with the view.
func _make_hanging_net_model(def: Dictionary) -> Node3D:
	if _hanging_net == null:
		_hanging_net = BasicLook.mesh("hand_net_hanging", Color.html(str(def.get("color", "#8a8a8a"))), float(def.get("size", 1.0)), def.get("bits", []))

	var node: Node3D = Node3D.new()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = _hanging_net
	node.add_child(mesh)
	node.set_meta("grip_y", 0.0)     # the coil is at the model's origin, in the hand
	node.set_meta("hang", true)
	return node


func _hang_net() -> void:
	if _model == null or not _model.has_meta("hang") or not _model.is_inside_tree() or _camera == null:
		return

	_model.global_basis = Basis(Vector3.UP, _camera.global_rotation.y)


func _make_other_model() -> Node3D:
	if str(_inv.table.entry(held_id()).get("kind", "")) == "container":
		return _make_container_model()

	var look: Node3D = _make_look_tool_model()

	if look != null:
		return look

	if holds_plain_look(held_id(), str(_inv.table.entry(held_id()).get("kind", ""))):
		return look_tool_node(held_id())

	var tool_class: String = str(_inv.table.entry(held_id()).get("tool_class", ""))
	var node: Node3D = Node3D.new()
	var handle: MeshInstance3D = MeshInstance3D.new()
	var rod: CylinderMesh = CylinderMesh.new()
	rod.top_radius = 0.02
	rod.bottom_radius = 0.025
	rod.height = 0.9 if tool_class == "shovel" else 0.6
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.16)
	rod.material = wood
	handle.mesh = rod
	node.add_child(handle)
	var head: MeshInstance3D = MeshInstance3D.new()
	var block: BoxMesh = BoxMesh.new()
	block.size = Vector3(0.16, 0.22, 0.025) if tool_class == "shovel" else Vector3(0.06, 0.1, 0.1)
	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_color = Color(0.5, 0.42, 0.3) if tool_class == "shovel" else Color(0.5, 0.5, 0.52)
	block.material = metal
	head.mesh = block
	head.position = Vector3(0.0, rod.height * 0.5 + (0.0 if tool_class == "shovel" else 0.0), 0.0)
	node.add_child(head)
	return node


# A lantern in the left hand (buildables plan B4): its look (basic_look.gd "lantern", Kathleen's) hanging from the bail, which is the model's origin. While it
# burns its horn panes glow warm and it gives one light of the item's light_m (items.json: 8 m wooden, 14 m iron); a lantern that is out is the look alone.
func _make_lantern_model(id: String) -> Node3D:
	var row: Dictionary = _inv.table.entry(id)
	var lantern: Node3D = Node3D.new()
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = BasicLook.mesh_for(id)
	body.position = Vector3(0.0, -LANTERN_BAIL_M, 0.0)
	body.layers = 2      # like the torch: its own light does not over-light it at arm's length
	lantern.add_child(body)

	if not bool(row.get("flame", false)):
		return lantern

	# The candle or oil flame seen through the horn: a thin warm shell just outside the look's horn box (0.15 x 0.17 x 0.15), the frame standing proud of it.
	var horn_glow: MeshInstance3D = MeshInstance3D.new()
	var shell: BoxMesh = BoxMesh.new()
	shell.size = Vector3(0.152, 0.172, 0.152)
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.65, 0.15, 0.45)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.65, 0.15)
	glow.emission_energy_multiplier = 0.6
	shell.material = glow
	horn_glow.mesh = shell
	horn_glow.position = body.position
	horn_glow.layers = 2
	horn_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lantern.add_child(horn_glow)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.65, 0.3)
	light.omni_range = float(row.get("light_m", 8.0))
	light.shadow_enabled = false
	light.light_cull_mask = 0xFFFFFFFD
	light.position = body.position
	lantern.add_child(light)
	FireWeather.register(light, 1.0, true)   # reach and halo follow fog and snow, as a torch's; in the hand it never lights the volumetric fog
	return lantern


# A torch in hand: a stick with a glowing head and one warm light (only while it is held).
func _make_torch_model(id: String = "", out: bool = false) -> Node3D:
	var lit: bool = bool(_inv.table.entry(id if id != "" else held_id()).get("flame", false)) and not out   # a torch that went out: no flame, no glow, no light
	var torch: Node3D = Node3D.new()
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.3, 0.17)
	wood.emission_enabled = lit
	wood.emission = Color(0.5, 0.3, 0.12)
	wood.emission_energy_multiplier = 0.12
	var grime: StandardMaterial3D = StandardMaterial3D.new()   # the top of the stick is dark with handling and smoke
	grime.albedo_color = Color(0.2, 0.14, 0.09)
	var stick: MeshInstance3D = MeshInstance3D.new()
	var rod: CylinderMesh = CylinderMesh.new()
	rod.top_radius = 0.017
	rod.bottom_radius = 0.025
	rod.height = 0.6
	rod.radial_segments = 16
	rod.material = wood
	stick.mesh = rod
	torch.add_child(stick)
	# The top of the stick darkens with handling and smoke in three steps, so there is no hard seam.
	for step in range(3):
		var soot: MeshInstance3D = MeshInstance3D.new()
		var soot_mesh: CylinderMesh = CylinderMesh.new()
		var soot_y: float = 0.12 + 0.08 * float(step)
		soot_mesh.top_radius = 0.0218 - 0.01333 * (soot_y + 0.04)   # a hair wider than the stick at that height
		soot_mesh.bottom_radius = 0.0218 - 0.01333 * (soot_y - 0.04)
		soot_mesh.height = 0.08
		soot_mesh.radial_segments = 16
		var shade: StandardMaterial3D = StandardMaterial3D.new()
		shade.albedo_color = Color(0.42, 0.3, 0.17).lerp(Color(0.2, 0.14, 0.09), 0.3 + 0.35 * float(step))
		soot_mesh.material = shade
		soot.mesh = soot_mesh
		soot.position = Vector3(0.0, soot_y, 0.0)
		torch.add_child(soot)

	# The head: rag or bark wound round the top of the stick and bound with twine, about 2.5 times the stick's width and 15 cm long; dark
	# brown, the top third charred and glowing. The same colours as the unlit torch on the ground (basic_look.gd).
	var wrap_material: StandardMaterial3D = StandardMaterial3D.new()
	wrap_material.albedo_color = Color(0.26, 0.17, 0.1)
	wrap_material.roughness = 1.0   # matte
	wrap_material.emission_enabled = lit   # a trace of warm light of its own so the head is brown, not black, in the dark (and not orange at noon)
	wrap_material.emission = Color(0.5, 0.22, 0.08)
	wrap_material.emission_energy_multiplier = 0.2
	var head: MeshInstance3D = MeshInstance3D.new()
	var wrapping: CylinderMesh = CylinderMesh.new()
	wrapping.top_radius = 0.052
	wrapping.bottom_radius = 0.04
	wrapping.height = 0.15
	wrapping.material = wrap_material
	head.mesh = wrapping
	head.position = Vector3(0.0, 0.325, 0.0)
	torch.add_child(head)
	var char_material: StandardMaterial3D = StandardMaterial3D.new()
	char_material.albedo_color = Color(0.16, 0.1, 0.065)
	char_material.roughness = 1.0
	char_material.emission_enabled = lit
	char_material.emission = Color(0.9, 0.3, 0.05)
	char_material.emission_energy_multiplier = 0.35
	var charred: MeshInstance3D = MeshInstance3D.new()
	var char_mesh: CylinderMesh = CylinderMesh.new()
	char_mesh.top_radius = 0.0525
	char_mesh.bottom_radius = 0.0485
	char_mesh.height = 0.05
	char_mesh.material = char_material
	charred.mesh = char_mesh
	charred.position = Vector3(0.0, 0.375, 0.0)
	torch.add_child(charred)
	var twine_material: StandardMaterial3D = StandardMaterial3D.new()
	twine_material.albedo_color = Color(0.34, 0.26, 0.17)   # dark rope, not cream
	twine_material.roughness = 1.0

	for band_y in [0.28, 0.335]:
		var band: MeshInstance3D = MeshInstance3D.new()
		var ring: CylinderMesh = CylinderMesh.new()
		ring.top_radius = 0.054 if band_y > 0.3 else 0.046
		ring.bottom_radius = ring.top_radius
		ring.height = 0.013
		ring.material = twine_material
		band.mesh = ring
		band.position = Vector3(0.0, band_y, 0.0)
		torch.add_child(band)

	if not lit:
		for child in torch.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).layers = 2

		return torch

	# The flame rises from the top of the head whichever way the stick points (flame_up.gd): about 25 cm tall and 8 cm across at the base, a slim teardrop, a
	# teardrop of three emissive cones, orange at the base to yellow at the tip with a short pale core.
	# The two upper cones sway slowly so it does not read as one solid shape.
	var rig: Node3D = Node3D.new()
	rig.set_script(FlameUp)
	rig.head_local = Vector3(0.0, 0.4, 0.0)
	torch.add_child(rig)
	var flames: Array = []
	var layers: Array = [[0.062, 0.3, Color(1.0, 0.45, 0.08, 0.2), 0.0], [0.042, 0.22, Color(1.0, 0.38, 0.06, 0.85), 0.0], [0.034, 0.27, Color(1.0, 0.68, 0.14, 0.9), 0.006], [0.019, 0.14, Color(1.0, 0.95, 0.65, 1.0), -0.004]]

	for n in range(layers.size()):
		var layer: Array = layers[n]
		var glow: StandardMaterial3D = StandardMaterial3D.new()
		glow.albedo_color = layer[2]
		glow.emission_enabled = true
		glow.emission = layer[2]
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA   # the outer cones are see-through so the inner ones show through; the core glows added

		if n == 3 or n == 0:
			glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

		var tongue: Node3D = Node3D.new()   # pivots at the base so the sway leans the tip
		var mesh_node: MeshInstance3D = MeshInstance3D.new()
		glow.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_node.mesh = _teardrop_mesh(float(layer[1]), float(layer[0]), glow)
		tongue.add_child(mesh_node)
		tongue.name = "Flame%d" % n
		tongue.position = Vector3(float(layer[3]), 0.0, 0.0)
		rig.add_child(tongue)

		if n == 1 or n == 2:
			flames.append(tongue)

	for n in range(flames.size() if _root != null else 0):
		var sway: Tween = _root.create_tween().set_loops()
		sway.bind_node(flames[n])
		var lean: float = 0.12 + 0.05 * float(n)
		var span: float = 0.55 + 0.17 * float(n)
		sway.tween_property(flames[n], "rotation:z", lean, span).set_trans(Tween.TRANS_SINE)
		sway.tween_property(flames[n], "rotation:z", -lean, span).set_trans(Tween.TRANS_SINE)

	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.65, 0.3)
	light.omni_range = float(_inv.table.entry(id if id != "" else held_id()).get("light_m", 9.0)) * FlameRules.TORCH_REACH_MULT
	light.omni_attenuation = FlameRules.TORCH_LIGHT_ATTENUATION
	light.shadow_enabled = false
	light.light_cull_mask = 0xFFFFFFFD   # the torch's own meshes (layer 2) are not lit by its own lights: they were over-lit orange at arm's length
	light.position = Vector3(0.0, 0.62, 0.0)
	torch.add_child(light)
	FireWeather.register(light, 1.0, true)   # reach and halo follow fog and snow; in the hand it never lights the volumetric fog
	var hand_light: OmniLight3D = OmniLight3D.new()   # a short warm light low on the stick so the hand holding it is lit by the flame, not black
	hand_light.name = "HandLight"
	hand_light.light_color = Color(1.0, 0.6, 0.28)
	hand_light.omni_range = FlameRules.TORCH_HAND_RANGE_M
	hand_light.light_energy = FlameRules.TORCH_HAND_ENERGY
	hand_light.shadow_enabled = false
	hand_light.light_volumetric_fog_energy = 0.0   # no glowing ball in the fog around the hand
	hand_light.light_cull_mask = 0xFFFFFFFD
	hand_light.position = Vector3(0.0, -0.05, 0.12)
	torch.add_child(hand_light)

	for child in torch.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).layers = 2   # see the light cull masks above

	return torch


# A flame's teardrop: round and fullest about a third of the way up, closing to a point at the tip and to a point at the base.
func _teardrop_mesh(height: float, radius: float, material: Material) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: int = 12
	var sides: int = 16

	for ring in range(rings):
		var t0: float = float(ring) / float(rings)
		var t1: float = float(ring + 1) / float(rings)
		var r0: float = radius * sin(PI * pow(t0, 0.7))
		var r1: float = radius * sin(PI * pow(t1, 0.7))

		for side in range(sides):
			var a0: float = TAU * float(side) / float(sides)
			var a1: float = TAU * float(side + 1) / float(sides)
			var p00: Vector3 = Vector3(cos(a0) * r0, t0 * height, sin(a0) * r0)
			var p10: Vector3 = Vector3(cos(a1) * r0, t0 * height, sin(a1) * r0)
			var p01: Vector3 = Vector3(cos(a0) * r1, t1 * height, sin(a0) * r1)
			var p11: Vector3 = Vector3(cos(a1) * r1, t1 * height, sin(a1) * r1)

			for corner in [p00, p10, p11, p00, p11, p01]:
				surface.add_vertex(corner)

	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()
	mesh.surface_set_material(0, material)
	return mesh


func _make_knife_model() -> Node3D:
	var look: Node3D = _make_look_tool_model()

	if look != null:
		return look

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
	var look: Node3D = _make_look_tool_model()

	if look != null:
		return look

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
	var look: Node3D = _make_look_tool_model()

	if look != null:
		return look

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
# Headless check (--net, BUG-022: "swinging the shore net makes more nets"): give a fishing net, hold it, left-click with it the way the
# mouse does (mouse_button), first as it stands (usually at dry ground) and then a few more times, and print the pack before and after.
func run_net_test() -> void:
	await get_tree().create_timer(6.0).timeout
	var table = _inv.table
	var net_n: int = table.number_of("shore_net")
	_net.inventory_action.rpc_id(1, Net.ACT_ADMIN_GIVE, net_n, 0, 1, Vector3.ZERO)
	await get_tree().create_timer(2.0).timeout
	FreezeWatchScript.printer.line("NET TEST: pack before: %s" % _net_test_pack())

	for slot in range(8):
		if _inv.inventory.numbers[slot] == net_n:
			select(slot)

	FreezeWatchScript.printer.line("NET TEST: holding %s in slot %d" % [held_id(), held_slot])

	for n in 4:
		var used: bool = mouse_button(MOUSE_BUTTON_LEFT, true)
		await get_tree().create_timer(0.3).timeout
		mouse_button(MOUSE_BUTTON_LEFT, false)
		await get_tree().create_timer(9.0).timeout   # the net sinks for hold_s (6 s) and is hauled back
		FreezeWatchScript.printer.line("NET TEST: click %d (used %s): nets in pack %d, nets on the ground %d; pack %s" % [n + 1, used, _inv.inventory.count_of(net_n), _net_test_ground(net_n), _net_test_pack()])

	FreezeWatchScript.printer.line("NET TEST: %s" % ("PASS: still one net" if _inv.inventory.count_of(net_n) == 1 and _net_test_ground(net_n) == 0 else "FAIL: the net count changed"))


func _net_test_pack() -> String:
	var parts: Array = []

	for slot in range(_inv.inventory.numbers.size()):
		if _inv.inventory.numbers[slot] != 0:
			parts.append("%d:%s x%d" % [slot, _inv.table.id_of(_inv.inventory.numbers[slot]), _inv.inventory.counts[slot]])

	return ", ".join(parts)


func _net_test_ground(net_n: int) -> int:
	var found: int = 0

	for id in _inv._world:
		if int(_inv._world[id].get("number", 0)) == net_n:
			found += 1

	return found


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

	FreezeWatchScript.printer.line("Spear test: holding %s" % held_id())
	var jabbed: bool = mouse_button(MOUSE_BUTTON_LEFT, true)
	await get_tree().create_timer(0.5).timeout
	mouse_button(MOUSE_BUTTON_RIGHT, true)
	var aimed: bool = aiming
	mouse_button(MOUSE_BUTTON_LEFT, true)
	await get_tree().create_timer(5.0).timeout
	FreezeWatchScript.printer.line("Spear test: jab %s, aimed %s, still aiming %s, spears in pack %d, things on ground %d" % [jabbed, aimed, aiming, _inv.inventory.count_of(table.number_of("wooden_spear")), _inv._world.size()])
	_net.inventory_action.rpc_id(1, Net.ACT_CRAFT, 2, 0, 0, Vector3.ZERO)
	await get_tree().create_timer(1.0).timeout

	for slot in range(8):
		if _inv.inventory.numbers[slot] == table.number_of("stone_axe"):
			select(slot)

	var swung: bool = mouse_button(MOUSE_BUTTON_LEFT, true)
	await get_tree().create_timer(1.0).timeout
	FreezeWatchScript.printer.line("Spear test: holding %s, swung %s, last hit sound '%s'" % [held_id(), swung, _sound.hits.last_hit if _sound != null else "none"])
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

	FreezeWatchScript.printer.line("Spear test: campfire kit slot %d, ground %s, fires in view %d, states %s" % [kit_slot, str(ground), lit, str(states)])


func inv_slots() -> int:
	return _inv.inventory.slot_count


# --- Laying pipe from the hand (docs/design/PLUMBING_DESIGN.md s9, Dave 19 Nov 2026; values PROVISIONAL PV-3) ---
# With a pipe in hand every laid pipe near by glows bright blue and every point a pipe can start from shows a glowing ring: a barrel's bottom centre, a
# trough's or cistern's outlet, a well's or pump's spout. The aim takes the nearest ring, or the nearest point along a blue pipe (a dot slides along it
# as you look). The first left click starts a run there; a line then follows the aim, green while the pipe in the pack covers it (in reach, at most
# 30 m), red when it does not. The second click lays the run (pipe_lay, protocol 138): to a ring or a pipe, or ending in the open air ahead. Right click,
# or putting the pipe away, drops the start. With a tap or drip head in hand the open pipe ends show as rings and a click fits it on the one aimed at.
# The server checks it all again (server_items.pipe_lay). Client side only: nobody else sees the rings, the blue or the line.
const PipeRules := preload("res://src/shared/pipe_rules.gd")
const PIPE_SEE_M := 40.0          # rings and blue pipes are shown this near the player (looked for twice a second)
const PIPE_AIM_M := 8.0           # the aim takes a ring or a pipe at most this far from the eye
const PIPE_PICK_M := 0.4          # and passing at most this near it
const PIPE_FREE_M := 6.0          # nothing taken: a run ends on the ground or what the aim hits first within this (the server's PLACE_REACH_M), else this far along the aim (Dave 19 Nov 2026 20:31Z: lay the far end on the ground)
const PIPE_SCAN_MSEC := 500
const PIPE_RING_R_M := 0.14
var pipe_start: Vector3 = Vector3.INF     # the run's first point, INF until the first click (tests read these)
var pipe_aim: Vector3 = Vector3.INF       # the point a click sets now
var pipe_aim_kind: String = ""            # what it is on: "ring", "pipe", "air" or ""
var pipe_line_red: bool = false
var _pipe_rings_at: Array = []            # the points shown as rings: [[point, world id]]
var _pipe_runs_near: Array = []           # the laid runs near by: [[end a, end b, world id]]
var _pipe_scan_next: int = 0
var _pipe_lit: Dictionary = {}            # world id -> the pipe's node, given the blue overlay
var _pipe_ring_nodes: Array = []          # MeshInstance3D rings, reused
var _pipe_dot: MeshInstance3D = null
var _pipe_line: MeshInstance3D = null
var _pipe_mat: Dictionary = {}            # "blue", "ring", "green", "red", "dot"
var _pipe_shown: bool = false             # the rings and blue are up (put away once when the pipe leaves the hand)


func _pipe_piece_m() -> float:
	return float(_inv.table.entry(held_id()).get("pipe_m", 0.0)) if held_number() != 0 else 0.0


func _pipe_fitting() -> String:
	return str(_inv.table.entry(held_id()).get("fitting", "")) if held_number() != 0 else ""


func _pipe_hand() -> bool:
	return _inv != null and holding and (_pipe_piece_m() > 0.0 or _pipe_fitting() != "")


func _pipe_caption() -> String:
	if _pipe_fitting() != "":
		return "Left click a pipe's end or joint (a glowing ring) to fit it"

	if not pipe_start.is_finite():
		return "Left click a glowing ring or a blue pipe to start a pipe"

	if pipe_line_red:
		return "Red: too far, or not enough pipe in your pack (right click: start again)"

	var length: float = pipe_start.distance_to(pipe_aim) if pipe_aim.is_finite() else 0.0
	return "%.1f m, %d pipe (left click: lay it; right click: start again)" % [length, PipeRules.pieces_for(length, _pipe_piece_m())]


func _pipe_click(button: int, pressed: bool) -> bool:
	if not pressed:
		return button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT

	if button == MOUSE_BUTTON_RIGHT:
		if pipe_start.is_finite():
			pipe_start = Vector3.INF
			_inv._on_notice("Pipe start cleared")

		return true

	if button != MOUSE_BUTTON_LEFT:
		return false

	if _pipe_fitting() != "":
		if pipe_aim_kind != "ring":
			_inv._on_notice("Aim at a pipe's end or joint (a glowing ring)")
		else:
			_arm_play("use", 0.6)
			_net.pipe_lay.rpc_id(1, held_slot, pipe_aim, pipe_aim)

		return true

	if not pipe_start.is_finite():
		if pipe_aim_kind != "ring" and pipe_aim_kind != "pipe":
			_inv._on_notice("Start a pipe at a glowing ring or a blue pipe")
		else:
			pipe_start = pipe_aim

		return true

	if pipe_line_red or not pipe_aim.is_finite():
		_inv._on_notice("Too far, or not enough pipe in your pack")
		return true

	_arm_play("use", 0.6)
	_net.pipe_lay.rpc_id(1, held_slot, pipe_start, pipe_aim)
	pipe_start = Vector3.INF
	return true


# Every frame: the rings and blue pipes (looked for again twice a second), the aimed point and dot, and the line from the start.
func _pipe_mode() -> void:
	if _inv == null or _camera == null:
		return

	if not _pipe_hand():
		if _pipe_shown:
			_pipe_off()

		return

	_pipe_shown = true
	var now: int = Time.get_ticks_msec()

	if now >= _pipe_scan_next:
		_pipe_scan_next = now + PIPE_SCAN_MSEC
		_pipe_scan()

	var eye: Vector3 = _camera.global_position
	var dir: Vector3 = -_camera.global_transform.basis.z
	var best_d: float = PIPE_PICK_M
	pipe_aim = Vector3.INF
	pipe_aim_kind = ""

	for ring in _pipe_rings_at:
		var near: Array = PipeRules.ray_nearest(eye, dir, ring[0], ring[0])

		if float(near[2]) <= PIPE_AIM_M and float(near[1]) - 0.05 < best_d:   # a ring wins a tie with the pipe it sits on
			best_d = float(near[1]) - 0.05
			pipe_aim = ring[0]
			pipe_aim_kind = "ring"

	if _pipe_fitting() == "":
		for run in _pipe_runs_near:
			var near: Array = PipeRules.ray_nearest(eye, dir, run[0], run[1])

			if float(near[2]) <= PIPE_AIM_M and float(near[1]) < best_d:
				best_d = float(near[1])
				pipe_aim = near[0]
				pipe_aim_kind = "pipe"

				for end in [run[0], run[1]]:
					if pipe_aim.distance_to(end) <= PipeRules.SNAP_M:
						pipe_aim = end   # this near an end is that end (the server's rule)

	if pipe_aim_kind == "" and pipe_start.is_finite():
		var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + dir * PIPE_FREE_M))
		pipe_aim = hit["position"] if not hit.is_empty() else eye + dir * PIPE_FREE_M
		pipe_aim_kind = "air"

	_pipe_show_dot()
	_pipe_show_line()


# The rings and runs within PIPE_SEE_M (InventoryView's world rows): runs get the blue overlay; a pipe in hand rings every start point, a fitting in
# hand rings the open run ends.
func _pipe_scan() -> void:
	var here: Vector3 = _camera.global_position
	var fitting: bool = _pipe_fitting() != ""
	var rings: Array = []
	var runs: Array = []
	var ends_taken: Array = []   # the points something else sits on (a tap, a drip head, a ring): a run end there is not open
	var seen: Dictionary = {}

	for id in _inv._world:
		var row: Dictionary = _inv._world[id]

		if int(row.get("state", 0)) < 5 or row.get("site") != null or (row["pos"] as Vector3).distance_to(here) > PIPE_SEE_M + 15.0:   # a run's middle is at most 15 m from its ends
			continue

		var def: Dictionary = _inv._structure_by_state(int(row["state"]))
		var water: Variant = def.get("water", {})

		if typeof(water) != TYPE_DICTIONARY or (water as Dictionary).is_empty():
			continue

		var yaw: float = deg_to_rad(float(row.get("yaw", 0.0)))

		if str(def.get("hand_laid", "")) == "pipe" and row.has("len"):
			var e: Array = PipeRules.ends(row["pos"], float(row.get("yaw", 0.0)), float(row.get("pitch", 0.0)), float(row["len"]))
			runs.append([e[0], e[1], id, float(_inv.table.entry(str(def.get("item", ""))).get("pipe_m", 0.0))])
			seen[id] = true
			continue

		if str(def.get("hand_laid", "")) == "fitting":
			ends_taken.append(row["pos"])
			continue

		var keys: Array = ["outlet", "level_port"] if str(water.get("role", "")) == "tank" else (["outlet"] if str(water.get("role", "")) == "source" else [])

		for key in keys:
			if typeof(water.get(key)) == TYPE_ARRAY and (water[key] as Array).size() == 3:
				var v: Array = water[key]
				var point: Vector3 = (row["pos"] as Vector3) + Vector3(float(v[0]), float(v[1]), float(v[2])).rotated(Vector3.UP, yaw)
				ends_taken.append(point)

				if not fitting and point.distance_to(here) <= PIPE_SEE_M and (rings.is_empty() or rings[rings.size() - 1][1] != id or (rings[rings.size() - 1][0] as Vector3).distance_to(point) > 0.05):   # a barrel's outlet and bottom point are one ring
					rings.append([point, id])

	if fitting:   # each run's ends and joints (Dave 19 Nov 2026 20:31Z: each segment has a connection point) that no fitting or water point takes
		for run in runs:
			for point in [run[0], run[1]] + PipeRules.joints(run[0], run[1], float(run[3])):
				var free: bool = (point as Vector3).distance_to(here) <= PIPE_SEE_M

				for taken in ends_taken:
					free = free and (point as Vector3).distance_to(taken) > PipeRules.SNAP_M

				for ring in rings:
					free = free and (point as Vector3).distance_to(ring[0]) > 0.05   # two runs' ends at one joint are one ring

				if free:
					rings.append([point, run[2]])

	_pipe_rings_at = rings
	_pipe_runs_near = runs

	for id in _pipe_lit.keys():
		if not seen.has(id) or not _inv._world.has(id) or not is_instance_valid(_pipe_lit[id]) or _inv._world[id]["node"] != _pipe_lit[id]:   # gone, or drawn again (a run split)
			_pipe_glow(_pipe_lit[id], false)
			_pipe_lit.erase(id)

	for id in seen:
		if not _pipe_lit.has(id):
			_pipe_lit[id] = _inv._world[id]["node"]
			_pipe_glow(_pipe_lit[id], true)

	_pipe_show_rings()


func _pipe_glow(node: Variant, on: bool) -> void:
	if not is_instance_valid(node):
		return

	var stack: Array = [node]

	while not stack.is_empty():
		var n: Node = stack.pop_back()

		if n is GeometryInstance3D:
			(n as GeometryInstance3D).material_overlay = _pipe_material("blue") if on else null

		stack.append_array(n.get_children())


func _pipe_material(which: String) -> StandardMaterial3D:
	if not _pipe_mat.has(which):
		var colours: Dictionary = {"blue": Color(0.2, 0.55, 1.0, 0.55), "ring": Color(0.35, 0.85, 1.0), "dot": Color(1.0, 1.0, 1.0), "green": Color(0.2, 1.0, 0.25), "red": Color(1.0, 0.15, 0.1)}
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = colours[which]
		mat.emission_enabled = true
		mat.emission = colours[which]
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

		if which == "blue":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.grow = true
			mat.grow_amount = 0.01
		else:
			mat.no_depth_test = true   # a ring, the dot and the line show through walls and the barrel itself
			mat.render_priority = 1

		_pipe_mat[which] = mat

	return _pipe_mat[which]


func _pipe_show_rings() -> void:
	while _pipe_ring_nodes.size() < _pipe_rings_at.size():
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = PIPE_RING_R_M - 0.025
		torus.outer_radius = PIPE_RING_R_M
		ring.mesh = torus
		ring.material_override = _pipe_material("ring")
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(ring)
		_pipe_ring_nodes.append(ring)

	for n in _pipe_ring_nodes.size():
		var ring: MeshInstance3D = _pipe_ring_nodes[n]
		ring.visible = n < _pipe_rings_at.size()

		if ring.visible:
			ring.global_position = _pipe_rings_at[n][0]


func _pipe_show_dot() -> void:
	if _pipe_dot == null:
		_pipe_dot = MeshInstance3D.new()
		var ball: SphereMesh = SphereMesh.new()
		ball.radius = 0.05
		ball.height = 0.1
		_pipe_dot.mesh = ball
		_pipe_dot.material_override = _pipe_material("dot")
		_pipe_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(_pipe_dot)

	_pipe_dot.visible = pipe_aim_kind == "ring" or pipe_aim_kind == "pipe"

	if _pipe_dot.visible:
		_pipe_dot.global_position = pipe_aim


func _pipe_show_line() -> void:
	var on: bool = pipe_start.is_finite() and pipe_aim.is_finite() and pipe_start.distance_to(pipe_aim) > 0.01

	if not on:
		pipe_line_red = false

		if _pipe_line != null:
			_pipe_line.visible = false

		return

	if _pipe_line == null:
		_pipe_line = MeshInstance3D.new()
		var rod: CylinderMesh = CylinderMesh.new()
		rod.top_radius = 0.025
		rod.bottom_radius = 0.025
		rod.height = 1.0
		rod.radial_segments = 6
		rod.rings = 1
		_pipe_line.mesh = rod
		_pipe_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(_pipe_line)

	var length: float = pipe_start.distance_to(pipe_aim)
	var feet: Vector3 = _inv._player_position.call() if _inv._player_position.is_valid() else _camera.global_position
	var have: int = _inv.inventory.count_of(held_number())
	pipe_line_red = length > PipeRules.MAX_RUN_M or length < PipeRules.MIN_RUN_M or feet.distance_to(pipe_aim) > PLACE_REACH_M or have < PipeRules.pieces_for(length, _pipe_piece_m())
	_pipe_line.material_override = _pipe_material("red" if pipe_line_red else "green")
	var up: Vector3 = (pipe_aim - pipe_start) / length   # the rod's own +Y runs from the start to the aim
	var side: Vector3 = up.cross(Vector3.UP) if absf(up.y) < 0.99 else up.cross(Vector3.RIGHT)
	side = side.normalized()
	var back: Vector3 = side.cross(up).normalized()
	_pipe_line.global_transform = Transform3D(Basis(side, up * length, back), (pipe_start + pipe_aim) * 0.5)
	_pipe_line.visible = true


# The pipe is put away: the start is dropped and the rings, dot, line and blue go.
func _pipe_off() -> void:
	_pipe_shown = false
	_pipe_scan_next = 0
	pipe_start = Vector3.INF
	pipe_aim = Vector3.INF
	pipe_aim_kind = ""
	pipe_line_red = false

	for id in _pipe_lit:
		_pipe_glow(_pipe_lit[id], false)

	_pipe_lit.clear()
	_pipe_rings_at = []
	_pipe_runs_near = []
	_pipe_show_rings()

	if _pipe_dot != null:
		_pipe_dot.visible = false

	if _pipe_line != null:
		_pipe_line.visible = false


# Where a thrown shore net lands: where the look meets the water about the feet's height (camera 1.6 m up), NET_NEAR_M to NET_FAR_M away, so a
# player can throw it onto a splash or a school's dark fish (24 Nov 2026, Dave: "will we also be able to thow the net at the school of fish").
# Looking level or up, it lands NET_THROW_M ahead as before.
static func net_landing(eye: Vector3, look: Vector3) -> Vector3:
	var flat: Vector3 = Vector3(look.x, 0.0, look.z)

	if flat.length() < 0.001:
		flat = Vector3(0.0, 0.0, -1.0)

	var dist: float = NET_THROW_M

	if look.y < -0.05:
		dist = clampf(1.6 / -look.y * flat.length(), NET_NEAR_M, NET_FAR_M)

	return eye + flat.normalized() * dist - Vector3(0.0, 1.6, 0.0)
