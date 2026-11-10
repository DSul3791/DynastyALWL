extends Node

# What the player holds (hotbar keys 1 to 9 and 0 choose the item each key points at, wherever it lies in the pack: inventory step 4; the key again puts it away) and how it is used.
# Client only; the server decides what happens (throws are server actions).
#
# Spear (Dave, 2026-10-20): held and jabbed by default with the normal attack key (left click).
# Hold right click to aim a throw; then left click throws. Letting go of right click returns to
# the normal stance. The weapon is drawn as a simple first-person model until real art exists.

const FeelKicks := preload("res://src/client/feel_kicks.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")
# The held-item label sits 8 px over the hotbar tray (redesign section 9: the tray top is at y 948 of the 1080 canvas).
const LABEL_ABOVE := 1080.0 - ArtKit.HOTBAR_TRAY.position.y + 8.0
const Net := preload("res://src/stream/terrain_net.gd")
const BuildingLook := preload("res://src/client/building_look.gd")
const FireWeather := preload("res://src/client/fire_weather.gd")
const PlacementRules := preload("res://src/shared/placement_rules.gd")
const BasicLook := preload("res://src/client/basic_look.gd")
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
const THIRD_SPADE_PITCH_DEG := -56.0   # third person: a carried spade points its blade down, 40 degrees from vertical in the hand frame (about 30 as seen: review 2026-10-25 said 60 read steeper than 30)
const THIRD_HOE_PITCH_DEG := -50.0     # third person: a hoe carried blade-down, haft about 50 degrees below horizontal (review 2026-10-25: it was nearly horizontal)
const THIRD_SAW_PITCH_DEG := -120.0   # third person: a saw carried by the handle, blade pointing down and back about 30 degrees
const THIRD_TORCH_RAISE_DEG := 35.0   # third person: a torch in the left hand points forward and 35 degrees up, its flame clear of the body (Dave 5 Nov: it lay along the arm by the hip)
const THIRD_CHOKE := 0.6         # the hand takes the handle this share of the way from the middle to the end, so less of the tool stands above the hand
# A tool with a stage-one look (data/items/looks.json) is held as the same mesh that lies on the ground (Dave 2026-10-24: the held tools
# looked like old placeholders). BasicLook tool meshes run handle to head along +X; HELD_LOOK_TURN turns that to the held convention
# (+Y handle to head, +Z up in hand) with the blade's cutting side down (axe, pick, hoe, knife) or the flat of a spade facing up.
const HELD_LOOK_SCALE := 1.0      # real size against the body (Dave QA BUG-012: tools held at 1.4x, spear 1.6x, bow 1.8x looked too big)
const HELD_SPEAR_SCALE := 1.0
const BOW_AMMO := ["stone_arrow", "bone_arrow", "wooden_arrow", "fibre_arrow"]   # the same as "ammo" in data/items/bow.json (test_slot_sounds checks)
const BowAim := preload("res://src/shared/bow_aim.gd")
const BowReticle := preload("res://src/client/bow_reticle.gd")
const HELD_FIXED_SCALE := {"rod": 1.0, "hoe": 1.0, "saw": 1.0, "bow": 1.0, "arrow": 1.0, "quern": 1.0}   # held at ground size, not scaled to the 1 m cap or by 1.4x: the rod's cane and reel were lost, the hoe blade was tiny and the saw nearly 1 m long
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
	"spade": Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)),
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
	"quern": Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)),   # the grinding stones are carried flat in the hand as they lie
}
const JAB_REACH := 0.7
const JAB_S := 0.28
const THROW_SPEED := 24.0
const THROW_GRAVITY := 9.8

var held_key: int = 0                     # the hotbar key (0 to 9) in the right hand; keys hold items, not slots (inventory step 4)
var held_slot: int:                       # the pack slot that key points at (InventoryView.key_slot), -1 for none
	get:
		return int(_inv.key_slot(held_key)) if _inv != null else -1
var holding: bool = true                  # false after the held slot's key is pressed again: hands empty
const HOTBAR_SLOTS := 10
var aiming: bool = false
const TORCH_PLACE_M := 3.0                # how far the crosshair reaches to stick a torch in the ground or on a wall
var off_key: int = -1                     # the hotbar key carried in the left hand (items with "offhand": true: torch, shield), -1 for none
var off_slot: int:                        # the pack slot that key points at, -1 for none
	get:
		return int(_inv.key_slot(off_key)) if _inv != null and off_key >= 0 else -1
var off_holding: bool = false             # false after its key is pressed again: left hand empty
var blocking: bool = false                # B held with a shield in the left hand (the combat rules read this)
var _off_model: Node3D
var _off_shown: int = 0

var _inv                                  # InventoryView
var _hanging_net: Mesh                    # the shore net as it hangs from the hand (BasicLook "hand_net_hanging"), built once
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
var variant_slot: int = -1               # the pack slot of the wall variant the wheel chose (doorway, window), -1 for the held one
var lift_steps: int = 0                  # a held foundation stands this many 0.1 m steps above the ground (mouse wheel, Dave 2026-10-22)
var _blueprint_yaw: int = 0               # the turn (degrees) the ghost will be placed at
var _first_person: bool = true
var _avatar_rig                          # the full body (ragdoll_body.gd) drawn in third person, or null
var _mounted: bool = false                # the model is in the hand: the arm animations move it, not the offsets below
var _label: Label
var _jab_t: float = -1.0
var _bow_cfg: Dictionary = {}               # data/items/bow.json, read on the first shot (the arrow sound follows its flight)
var _draw_t: float = -1.0                 # the bow up and drawing (Dave 10 Nov 2026: right mouse held): seconds since it went up, -1 when it is down
var _aim_dir: Vector3 = Vector3.ZERO      # where the drawn bow points now: the view turned by the sway and drawn to a vital zone (aim_direction)
var _reticle = null                       # BowReticle: the cross while the bow is up
var animal_aim_rows: Callable = Callable()   # () -> [[position, heading], ...] of the animals drawn near; set by the client scene (aim assist)
var bow_force: String = ""                 # the shot runner's bow pose, "STATE[:DRAW]" (idle, raised, drawn; draw 0 to 1), "" = from play
var _bow_up: bool = false                  # the bow is raised or drawn: the arms come up to the camera pose
var _flights: Array = []                  # local visuals of spears this player threw: {node, vel, age}
var _shown_number: int = 0
var _sound                                # SoundStage (hit sounds)
var shrub_near: Callable = Callable()   # (from, to) -> [chunk, id] of the bush or shrub the swing line passes through, or []; set by the client scene
var _tree_near: Callable                  # (point) -> [chunk, id] of the tree trunk standing there, or []
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
var _ghost_material: StandardMaterial3D
var _blueprint_at: Vector3 = Vector3.ZERO
var _blueprint_ok: bool = false
var _ghost_on_base: bool = false           # the ghost is snapped to a base: a piece on a foundation, or a foundation beside another (the wheel does not lift it)
var _placement: Dictionary = {}              # structures.json: footprints, gaps, caps (shared with the server's rules)
var blueprint_state: String = ""            # what the ghost shows now: "open", "covered", "close", "crowded" or "steep" (tests read it)
var _blueprint_shape: Vector2 = Vector2(-1.0, -1.0)
var _blueprint_next_msec: int = 0
var blueprints = HammerBlueprints.new()      # the hammer's blueprint list (R with a hammer in hand); the picked one is placed from the pack's materials, no kit item

const MotionExtra := preload("res://src/client/character/motion_extra.gd")
const SWING_S := MotionExtra.CHOP_LENGTH        # a chop is a whole swing: wind-up, wide stroke, impact, follow-through, recovery (31 Oct 2026: 0.95 s, was the 0.55 s hammer rhythm)
const PICK_SWING_S := MotionExtra.PICK_LENGTH
const SWING_PAUSE_S := 0.1                       # the short pause before the next swing when the button is held
const NET_THROW_M := 6.0                        # how far ahead the shore net lands (server reach: fishing.json net.reach_m, 8 m)
const HIT_STOP_S := 0.045
const HIT_AT := MotionExtra.CHOP_IMPACT_S / MotionExtra.CHOP_LENGTH     # share of the swing where the tool reaches the target (the swing_fp and chop clips' impact key, 0.5 s of 0.95); the thump and the server's hit are this same tick
const PICK_HIT_AT := MotionExtra.PICK_IMPACT_S / MotionExtra.PICK_LENGTH
const REACH_M := 3.0


const FrameProbe := preload("res://src/debug/frame_probe.gd")
const HammerBlueprints := preload("res://src/client/hammer_blueprints.gd")
const FlameUp := preload("res://src/client/flame_up.gd")

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
	_net = terrain_net
	if _net != null:
		_net.road_marker_reached.connect(_on_road_marker_reached)
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


# The item a hotbar key points at in the pack, 0 when the key is empty or none of its item is in the pack.
func _key_number(key: int) -> int:
	var slot: int = int(_inv.key_slot(clampi(key, 0, HOTBAR_SLOTS - 1)))
	return _inv.inventory.numbers[slot] if slot >= 0 else 0


# A hotbar key (0 to 9): hold what it points at, or put it away when it is the one already held.
func press_slot(slot: int) -> void:
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

	if number == 0 or str(_inv.table.entry(_inv.table.id_of(number)).get("relit_item", "")) == "":
		return

	if quiet:
		return   # the same key again puts the torch away

	if light_block_fn.is_valid() and str(light_block_fn.call()) != "":
		_inv._on_notice("It is too wet to light the torch. Get out of the water and the rain, or into a cave or under cover.")
		return

	_net.inventory_action.rpc_id(1, Net.ACT_RELIGHT, 0, int(_inv.key_slot(clampi(slot, 0, HOTBAR_SLOTS - 1))) + 1, 0, Vector3.ZERO)   # the pack slot plus one (0: the first doused torch)   # no fire needed (Dave 6 Nov 2026)


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

	if not holding or slot < 0:
		return 0

	var number: int = _inv.inventory.numbers[slot]
	return 0 if is_offhand(number) else number


func held_id() -> String:
	return _inv.table.id_of(held_number())


# Left-hand items: the item table marks them with "offhand": true (torch, shield, later a lantern).
# True while a placement blueprint (ghost) is held; auto pickup stays off then.
func placing() -> bool:
	return _blueprint != null


# A hammer in hand and a blueprint picked from its list (R): the ghost and the click work like a kit's, but the materials come from the pack.
func _blueprinting() -> bool:
	return holding and blueprints.picked > 0 and _hammer_tier() > 0


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
	_net.inventory_action.rpc_id(1, Net.ACT_REPAIR_STRUCT, id, 0, 0, Vector3.ZERO)


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
		text += " (%d pieces made from kits are left out)" % int(saved["skipped"])

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
	_plan_next_msec = 0
	_plan_queue[0]["lift"] = lift_steps
	_inv._on_notice("Placing %s: %d pieces" % [plan["name"], _plan_queue.size()])


func _plan_step() -> void:
	if _plan_queue.is_empty():
		return

	var now: int = Time.get_ticks_msec()

	if now < _plan_next_msec:
		return

	_plan_next_msec = now + PLAN_STEP_MSEC
	var piece: Dictionary = _plan_queue.pop_front()
	_net.inventory_action.rpc_id(1, Net.ACT_PLACE_BLUEPRINT, int(piece["bp"]), int(piece.get("lift", 0)), int(piece["yaw"]), piece["pos"])


# Delete with the hammer menu open removes the highlighted saved plan. Returns true when it was used.
func delete_plan() -> bool:
	if not blueprints.is_open:
		return false

	var gone: String = blueprints.delete_highlighted(_hammer_tier())

	if gone != "":
		_inv._on_notice("Removed %s" % gone)

	return true


# The left and right arrows with the hammer menu open step through the groups of blueprints. Returns true when it was used.
func step_blueprint_group(forward: bool) -> bool:
	if not blueprints.is_open:
		return false

	blueprints.cycle_category(forward, _hammer_tier())
	return true


# Right click (or R) with a hammer in hand opens or shuts its blueprint list.
func toggle_blueprints() -> bool:
	if _hammer_tier() <= 0:
		return false

	blueprints.toggle(_hammer_tier())
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


# The pack slot of a burning flame in either hand that water or rain can put out (a torch; a lantern later: items.json "doused_item"), or -1.
func flame_slot() -> int:
	if _inv == null:
		return -1

	for spec in [[held_number(), held_slot], [off_number(), off_slot]]:
		if int(spec[0]) != 0 and str(_inv.table.entry(_inv.table.id_of(int(spec[0]))).get("doused_item", "")) != "":
			return int(spec[1])

	return -1


# The pack slot of a torch in either hand that can be placed (items.json places_as: burning or doused), or -1.
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

	if not _first_person and _avatar_rig != null and holding and (_is_torch() or _is_doused_torch()):
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
		_inv._on_notice(str(_bow_config().get("say_no_ammo", "You have no arrows.")))
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
	var draw_ms: int = int(_draw_t * 1000.0)
	var arrow: int = arrow_to_shoot()
	_net.inventory_action.rpc_id(1, Net.ACT_SHOOT, held_slot, draw_ms, arrow, _aim_dir)

	if arrow != 0:
		if _sound != null:
			_sound.slots.play("bow_loose", _camera.global_position - _camera.global_transform.basis.z * 0.6)   # the twang and swish

		_arrow_flight(draw_ms, _aim_dir, arrow)

	_draw_t = 0.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and has_arrow() else -1.0


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


# Where the drawn bow points: the view turned by the sway, then drawn toward a vital zone of an animal near the aim by the skill's pull.
func aim_direction() -> Vector3:
	var view: Basis = _camera.global_transform.basis
	var aim: Vector3 = BowAim.turned(-view.z, view.x, view.y, bow_wobble())
	var points: Array = []

	if animal_aim_rows.is_valid():
		for row in animal_aim_rows.call():
			points.append_array(BowAim.zone_points(_bow_config(), row[0], float(row[1])))

	return BowAim.assist(_bow_config(), _inv.skill_level_of("hunting"), _camera.global_position, aim, points)


# The view narrows a little as the bow comes up (bow.json aim.zoom_fov_share at full draw); 1 with the bow down. The client scene multiplies its field of view by it.
func aim_fov_share() -> float:
	return lerpf(1.0, float(_bow_config().get("aim", {}).get("zoom_fov_share", 0.85)), bow_draw())


func _update_bow(delta: float) -> void:
	if _draw_t >= 0.0 and (not _is_bow() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		_draw_t = -1.0   # the bow put away, or right let go outside the game window

	if _draw_t >= 0.0:
		_draw_t += delta
		_aim_dir = aim_direction()

	if _reticle == null and _hud_layer != null:
		_reticle = BowReticle.new()
		_reticle.arm_px = float(_bow_config().get("aim", {}).get("reticle_px", 14))
		_hud_layer.add_child(_reticle)

	if _reticle != null:
		_reticle.visible = _draw_t >= 0.0

		if _reticle.visible and not _camera.is_position_behind(_camera.global_position + _aim_dir * 30.0):
			_reticle.point = _camera.unproject_position(_camera.global_position + _aim_dir * 30.0)


func _is_spear() -> bool:
	return str(_inv.table.entry(held_id()).get("weapon_class", "")) == "spear"


# Whether the pack holds an arrow the bow can shoot (the server's ammo list, data/items/bow.json), so a draw with
# no arrow lets go silently instead of twanging.
func has_arrow() -> bool:
	return arrow_to_shoot() != 0


# The arrow the next shot takes, as the server picks it: the one the bow is loaded with while the pack holds it, else the first of BOW_AMMO there; 0 none.
func arrow_to_shoot() -> int:
	var loaded: int = int(_inv.bow_arrow)

	if loaded != 0 and _inv.inventory.count_of(loaded) > 0:
		return loaded

	for id in BOW_AMMO:
		var number: int = _inv.table.number_of(id)

		if number > 0 and _inv.inventory.count_of(number) > 0:   # 0 = not in the table (0 is also an empty slot)
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
	return str(_inv.table.entry(held_id()).get("weapon_class", "")) == "bow" and not _inv.is_broken(held_slot)


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


# A torch that water or rain put out (items.json "relit_item"): drawn as a torch with no flame or light.
func _is_doused_torch() -> bool:
	return str(_inv.table.entry(held_id()).get("relit_item", "")) != ""


func _is_knife() -> bool:
	return str(_inv.table.entry(held_id()).get("tool_class", "")) == "knife"


# Any other tool or weapon (spade, and every tool added later) is held too: it has a generic model and plays the "use" arm
# animation on left click, so nothing silently fails to be held.
func _is_other_tool() -> bool:
	var kind: String = str(_inv.table.entry(held_id()).get("kind", ""))
	var is_arrow: bool = str(BasicLook.entry(held_id()).get("shape", "")) == "arrow"   # arrows are "material" items but are held like a tool, not as a palm-sized look
	return (kind in ["tool", "weapon", "container"] or is_arrow) and not _is_spear() and not _is_torch() and not _is_doused_torch() and not _is_knife() and not _is_axe()


func is_holdable(number: int) -> bool:
	if number == 0:
		return false

	var entry: Dictionary = _inv.table.entry(_inv.table.id_of(number))
	# Food of ANY item kind can be held and eaten: the check is on THIS item (it used the currently held slot, so crab apples, a "material", could not be taken in hand
	# unless something edible was already held: Dave, 31 Oct 2026).
	return str(entry.get("kind", "")) in ["tool", "weapon", "placeable", "container"] or _inv.is_edible_item(number)


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


func _is_axe() -> bool:
	return str(_inv.table.entry(held_id()).get("tool_class", "")) in ["axe", "pick"] and not _inv.is_broken(held_slot)


# E gathers something by hand: the arm reaches down, takes hold and draws back (its own "gather" clip, ragdoll_body.gd _gather), unless a swing or another action is already playing.
func play_gather() -> void:
	if _swing_t < 0.0 and _jab_t < 0.0 and not aiming and _arms != null and _arms.visible and not _arms.is_one_shot_playing():
		_arm_play("gather" if _arms.animation_player.has_animation("gather") else "use", 0.3)


# True while a tool action is going on (a swing, the pause between chained swings, the hit stop): nothing nearby is picked up meanwhile.
func tool_busy() -> bool:
	return _swing_t >= 0.0 or _pause_t > 0.0 or _stop_t > 0.0


# One chop of an axe or pick. Holding the left button chains them (see _process): the next starts as the last one ends.
func _start_swing() -> void:
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



# The mouse wheel while a foundation is held raises or lowers where it will stand, in 0.1 m steps. Returns true when it was used here.
func wheel(down: bool) -> bool:
	if _hoe_menu_open:
		_hoe_menu_index = posmod(_hoe_menu_index + (1 if down else -1), HOE_MODES.size())
		_hoe_menu_refresh()
		return true

	if blueprints.is_open:
		blueprints.move(down, _hammer_tier())
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
	if button == MOUSE_BUTTON_RIGHT and pressed and holding and _inv.edible_slot(held_slot):
		_inv.eat_slot(held_slot)
		return true

	# Right click with a hammer opens its menu (or shuts it); left click in the menu picks (Dave 3 Nov 2026). Shift is left to other tools.
	if button == MOUSE_BUTTON_RIGHT and pressed and holding and _hammer_tier() > 0:
		blueprints.toggle(_hammer_tier())
		return true

	# Right click with a torch in the left hand and nothing in the right that uses right click: stick the torch in the ground or on a wall (Dave, 4 Nov 2026).
	if button == MOUSE_BUTTON_RIGHT and pressed and not blueprints.is_open and _right_hand_free() and _torch_hand_slot() >= 0:
		_place_torch_here()
		return true

	if blueprints.is_open:
		if button == MOUSE_BUTTON_LEFT and pressed:
			blueprints.choose(_hammer_tier())

		return button == MOUSE_BUTTON_LEFT

	if holding and _hammer_tier() > 0 and (blueprints.mode == "save" or blueprints.mode == "repair"):
		if button == MOUSE_BUTTON_LEFT and pressed:
			if blueprints.mode == "repair":
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
				var ahead: Vector3 = -_camera.global_transform.basis.z
				ahead = Vector3(ahead.x, 0.0, ahead.z).normalized()
				_net.inventory_action.rpc_id(1, Net.ACT_NET, held_slot, 0, 0, _camera.global_position + ahead * NET_THROW_M - Vector3(0.0, 1.6, 0.0))

			return true

		# Right click with the spade switches between Dig and Raise mode (Dave 2026-10-22).
		if button == MOUSE_BUTTON_RIGHT and pressed and str(_inv.table.entry(held_id()).get("tool_class", "")) == "spade":
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
					hoe_mode = str(HOE_MODES[_hoe_menu_index]["id"])
					_inv._on_notice("Hoe: %s" % str(HOE_MODES[_hoe_menu_index]["name"]))

				_hoe_menu_close()
				return true

			if button == MOUSE_BUTTON_RIGHT:
				if Input.is_key_pressed(KEY_SHIFT):
					_arm_play("use", 0.6)
					_grade_point_here()
				else:
					_hoe_menu_open_now()

				return true

			_arm_play("use", 0.6)
			_hoe_apply()
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
				_net.inventory_action.rpc_id(1, Net.ACT_PROCESS, carcass, 0, 0, Vector3.ZERO)
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


# The arrow seen leaving the bow and its thunk where it should come down: the server's flight (data/items/bow.json: power from the draw time,
# speed_max x power, gravity, range_m) followed here to draw it and to place and time the sound. A hit on an animal thuds through hit_number
# instead; the server's spread may turn the real arrow a little from this one.
func _arrow_flight(draw_ms: int, direction: Vector3, arrow: int) -> void:
	_bow_config()
	var v: Vector3 = direction * float(_bow_cfg.get("speed_max", 45.0)) * bow_power(draw_ms, _bow_cfg)
	var node: Node3D = _make_arrow_model(arrow)
	_root.add_child(node)
	node.global_position = _camera.global_position + direction * 0.8
	_flights.append({"node": node, "vel": v, "age": 0.0, "arrow": true})

	if _sound == null:
		return

	var at: Vector3 = _camera.global_position
	var flown: float = 0.0
	var t: float = 0.0
	var range_m: float = float(_bow_cfg.get("range_m", 80.0))

	while t < 6.0 and flown < range_m:
		v.y -= THROW_GRAVITY * 0.05
		flown += (v * 0.05).length()
		at += v * 0.05
		t += 0.05
		var ground: float = _ground_below.call(at)

		if not is_nan(ground) and at.y <= ground:
			at.y = ground
			break

	_sound.spear.arrow(at, t, "wood" if _tree_near.is_valid() and _tree_near.call(at) else "soil")


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

	_update_bow(delta)

	if _spyglass_up and (not holding or not _is_spyglass() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		_look_spyglass(false)   # put away, broken, or the button let go while the mouse was elsewhere

	_update_blueprint()
	_plan_step()
	_hoe_repeat(delta)

	if _sound != null:
		var flame_kind: String = str(_inv.table.entry(held_id()).get("tool_class", ""))

		if flame_kind not in ["torch", "lantern"]:
			flame_kind = _off_class()

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

	if _arms != null and _arms.visible and _arms.current() != "idle" and not _arms.is_one_shot_playing() and not _bow_posing():
		_arms.play("idle")

	# Hit stop: the animation freezes for a moment at the impact (Tyler Report 26), then goes on.
	if _stop_t > 0.0:
		_stop_t -= delta

		if _stop_t <= 0.0 and _arms != null:
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
		if _pause_t <= 0.0 and holding and _is_axe() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_start_swing()

	if _model != null and _is_torch():
		var flicker: OmniLight3D = _model.get_node_or_null("Light")

		if flicker != null:
			# Own light: one, shadowless. At Low it gives way to a fire light within 8 m, so no more than one lamp lights the same spot.
			flicker.visible = not held_light_budget.is_valid() or held_light_budget.call() or not _inv.fire_light_near(_camera.global_position, 8.0)
			flicker.light_energy = 2.0 + 0.4 * sin(float(Time.get_ticks_msec()) * 0.017)

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

		if bool(flight.get("arrow", false)) and (flight["vel"] as Vector3).length() > 0.1:
			flight["node"].look_at(flight["node"].global_position + flight["vel"], Vector3.UP)   # an arrow points along its flight
		var ground: float = _ground_below.call(flight["node"].global_position)

		if flight["age"] > 6.0 or (not is_nan(ground) and flight["node"].global_position.y <= ground):
			flight["node"].queue_free()
			_flights.erase(flight)


# The large log on the shoulder in first person (Dave 2026-10-21): across the right shoulder, fixed to the body (the way you face), so it
# shows at the edge of the view and when you look down.
func set_shoulder(on: bool, length: float, radius: float, color: Color = Color(0.32, 0.23, 0.15)) -> void:
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
	(mesh.material as StandardMaterial3D).albedo_color = color
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

	var working: bool = _swing_t >= 0.0 or _jab_t >= 0.0 or aiming or _bow_up or _arms.is_one_shot_playing()
	_arm_up = ArmsView.next_arm_up(_arm_up, working, ARMS_FOLLOW_K, delta)
	_arms.transform = ArmsView.arms_transform(_camera.global_transform, _camera.global_rotation.y, _arm_up, REST_PITCH_DEG, REST_DOWN_M, REST_BACK_M, ARMS_POS, ARMS_PITCH_DEG, ARMS_SCALE)


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
		"taken": "That fire already has a pot.",
		"far": "Too far to place that. Step closer.",
	}.get(blueprint_state, ""))

	if why == "" and _blueprinting() and not blueprints.can_afford(_hammer_tier()):
		why = "You do not have all the materials for that."

	if why == "":
		why = "Aim at the ground where it should go."

	_inv._on_notice(why)


func _update_blueprint() -> void:
	if (blueprints.picked > 0 or blueprints.is_open or blueprints.mode != "place") and _hammer_tier() <= 0:
		blueprints.clear()   # the hammer is put away: the pick and the list go with it
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

		_blueprint_kit = kit

		for child in _blueprint.get_children():
			child.queue_free()

		var def: Dictionary = PlacementRules.structure_of_kit(_placement, kit)
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

	var on_grid: Array = PlacementRules.snap(_placement, kit, hit["position"], posmod(int(round(rad_to_deg(_camera.global_rotation.y))), 360), _inv.placed_rows() if str(PlacementRules.structure_of_kit(_placement, kit).get("attach_to", "")) == "fire" else _inv.foundation_rows())
	_blueprint_at = on_grid[0]
	_blueprint_yaw = int(on_grid[1])

	if bool(PlacementRules.structure_of_kit(_placement, kit).get("foundation", false)) and not bool(on_grid[2]):
		_blueprint_at.y += float(lift_steps) * PlacementRules.LIFT_STEP_M
	_blueprint.global_position = _blueprint_at
	_blueprint.rotation.y = deg_to_rad(float(_blueprint_yaw)) if PlacementRules.structure_of_kit(_placement, kit).get("piece", false) else _camera.global_rotation.y
	var on_base: bool = bool(on_grid[2])
	_ghost_on_base = on_base
	blueprint_state = PlacementRules.blocked(_placement, kit, _blueprint_at, _inv.placed_rows())

	if blueprint_state == "" and not on_base:
		var ground_at: Vector3 = _blueprint_at
		var probe: Callable = func(x: float, z: float) -> float:
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, ground_at.y + 3.0, z), Vector3(x, ground_at.y - 3.0, z))
			var found: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(ray)
			return float(found["position"].y) if not found.is_empty() else NAN
		blueprint_state = PlacementRules.steep(_placement, kit, _blueprint_at, _camera.global_rotation.y, probe)

	if blueprint_state == "" and not on_base and not PlacementRules.structure_of_kit(_placement, kit).has("needs_running_water") and water_depth_at.is_valid() and PlacementRules.over_water(_placement, kit, _blueprint_at, deg_to_rad(float(_blueprint_yaw)), water_depth_at):
		blueprint_state = "water"

	if blueprint_state == "":
		var covered: bool = footprint != Vector2.ZERO or (_cover_at.is_valid() and _cover_at.call(_blueprint_at))
		blueprint_state = "covered" if covered else "open"

	# The server refuses a spot more than PLACE_REACH_M (6 m) from the player's feet; the ghost's ray starts at the camera, which in third person
	# is behind the body, so a green ghost could still be refused with "Too far to place that".
	if (blueprint_state == "open" or blueprint_state == "covered") and _inv._player_position.is_valid() and (_inv._player_position.call() as Vector3).distance_to(_blueprint_at) > PLACE_REACH_M:
		blueprint_state = "far"

	var blocked: bool = blueprint_state == "close" or blueprint_state == "crowded" or blueprint_state == "steep" or blueprint_state == "water" or blueprint_state == "nofire" or blueprint_state == "taken" or blueprint_state == "far"
	_blueprint_ok = _blueprint_ok and not blocked and (not _blueprinting() or blueprints.plan_picked < 0 or blueprints.can_afford(_hammer_tier()))   # a single piece without the materials is set down as a blue blueprint site (Dave 5 Nov 2026); a saved plan still needs them all
	_ghost_material.albedo_color = Color(0.9, 0.2, 0.2, 0.5) if blocked else Color(0.3, 0.9, 0.3, 0.5)


# The blow lands: what is in reach decides the sound. (Chopping trees and digging stone come with
# tree-fall and the harvest of ground; for now the axe only swings and sounds.)
func _strike() -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or _sound == null:
		return

	struck.emit(1.0, 1.2 if _tool_class() == "pick" else 1.0)
	var tree: Array = _tree_near.call(hit["position"]) if _tree_near.is_valid() else []
	var trunk_id: int = _inv.felled_trunk_near(hit["position"])
	var stump_id: int = _inv.stump_near(hit["position"]) if trunk_id == 0 else 0
	var boulder_id: int = _inv.boulder_near(hit["position"])
	var log_id: int = _inv.loose_log_near(hit["position"])
	FeelKicks.chips(_root, hit["position"], hit["normal"], log_id != 0 or trunk_id != 0 or stump_id != 0 or not tree.is_empty())
	var shrub: Array = shrub_near.call(from, hit["position"]) if shrub_near.is_valid() and tree.is_empty() else []   # an axe chops a bush up, a pickaxe digs it up whole (Dave 2 Nov 2026)

	if log_id != 0:
		_sound.hits.hit(_hit_tool(), "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_PROCESS, log_id, 0, 0, Vector3.ZERO)
	elif boulder_id != 0:
		_sound.hits.hit(_hit_tool(), "stone", hit["position"], 1.0)   # a boulder is stone whatever the ground under it
		_net.inventory_action.rpc_id(1, Net.ACT_HIT, boulder_id, Net.HIT_BOULDER, 0, Vector3.ZERO)
	elif trunk_id != 0:
		_sound.hits.hit(_hit_tool(), "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_PROCESS, trunk_id, 0, 0, Vector3.ZERO)
	elif stump_id != 0:
		_sound.hits.hit(_hit_tool(), "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_PROCESS, stump_id, 0, 0, Vector3.ZERO)
	elif not tree.is_empty():
		_sound.hits.hit(_hit_tool(), "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_HIT, tree[1], tree[0].x, tree[0].y, Vector3.ZERO)
	elif not shrub.is_empty():
		_sound.hits.hit(_hit_tool(), "wood", hit["position"], 0.7)
		_net.inventory_action.rpc_id(1, Net.ACT_HIT_SHRUB, shrub[1], shrub[0].x, shrub[0].y, Vector3(1.0 if _tool_class() == "pick" else 0.0, 0.0, 0.0))
	else:
		_sound.hits.hit_ground(_hit_tool(), hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_MINE, 0, 0, 0, hit["position"])


# A spade swing at the ground under the crosshair: the server checks the spade and the reach, cuts the hole and tells
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
		_inv._on_notice("Nothing to dig there: aim the spade at the ground within reach")
		return

	_net.inventory_action.rpc_id(1, Net.ACT_DIG, held_slot, 0, 0, hit["position"])


# Holding a mouse button with the hoe repeats the stroke every HOE_REPEAT_S (the server paces it at 0.5 s too), so a road is one drag.
const HOE_REPEAT_S := 0.55
var _hoe_t: float = 0.0


func _hoe_repeat(delta: float) -> void:
	if _inv == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or held_number() == 0 or str(_inv.table.entry(held_id()).get("tool_class", "")) != "hoe":
		_hoe_t = 0.0
		_hoe_menu_close()
		return

	if _hoe_menu_open or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_hoe_t = 0.0
		return

	_hoe_t += delta

	if _hoe_t >= HOE_REPEAT_S and hoe_mode == "survey":
		_hoe_t = 0.0   # a held click sets one marker, not a line of them
	elif _hoe_t >= HOE_REPEAT_S:
		_hoe_t = 0.0
		_arm_play("use", 0.6)
		_hoe_apply()


# What the hoe's mode does (left click, held). Grade needs points A and B (Shift + right click); Shift + left click grades in any mode.
const HOE_MODES := [
	{"id": "path", "name": "Path", "note": "averages the ground about 2 m round and treads a soft brown patch"},
	{"id": "smooth", "name": "Smooth", "note": "moves dirt from high spots to low ones, no path"},
	{"id": "till", "name": "Till", "note": "tills a metre of ground into a bed for sowing"},
	{"id": "survey", "name": "Survey a path", "note": "left click sets a marker; walk on and set the next, the road builds behind you (Shift + right click does the same in any mode)"},
]
var hoe_mode: String = "path"
var _hoe_menu_open: bool = false
var _hoe_menu_index: int = 0
var _hoe_menu_panel: PanelContainer = null
var _hoe_menu_label: Label = null
var _hud_layer: CanvasLayer = null


func _hoe_apply() -> void:
	if hoe_mode == "smooth":
		_hoe_here(Net.ACT_HOE_SMOOTH)
	elif hoe_mode == "till":
		_hoe_here(Net.ACT_TILL)
	elif hoe_mode == "survey":
		_grade_point_here()   # one marker a click, never repeated while the button is held
	else:
		_hoe_here(Net.ACT_HOE_PATH)


func _hoe_menu_open_now() -> void:
	if _hud_layer == null:
		return

	if _hoe_menu_panel == null:
		_hoe_menu_panel = PanelContainer.new()
		_hoe_menu_panel.set_anchors_preset(Control.PRESET_CENTER)
		_hoe_menu_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_hoe_menu_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		_hoe_menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hoe_menu_label = Label.new()
		_hoe_menu_label.add_theme_font_size_override("font_size", 26)
		_hoe_menu_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hoe_menu_panel.add_child(_hoe_menu_label)
		_hud_layer.add_child(_hoe_menu_panel)

	_hoe_menu_index = 0

	for n in HOE_MODES.size():
		if str(HOE_MODES[n]["id"]) == hoe_mode:
			_hoe_menu_index = n

	_hoe_menu_open = true
	_hoe_menu_panel.visible = true
	_hoe_menu_refresh()


func _hoe_menu_refresh() -> void:
	var text: String = "What should the hoe do?   (wheel: move, left click: choose, right click: close)\n\n"

	for n in HOE_MODES.size():
		text += "%s %s: %s\n" % ["->" if n == _hoe_menu_index else "    ", str(HOE_MODES[n]["name"]), str(HOE_MODES[n]["note"])]

	_hoe_menu_label.text = text


func _hoe_menu_close() -> void:
	_hoe_menu_open = false

	if _hoe_menu_panel != null:
		_hoe_menu_panel.visible = false


# Grade line points: the first click sets A, the next B, the next starts a new line at A. Stakes mark them; the server keeps its own copy.
var _grade_a: Vector3 = Vector3.ZERO
var _grade_has_a: bool = false
var _grade_has_b: bool = false
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


func _grade_point_here() -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit["collider"].has_meta("species_ids"):
		_inv._on_notice("Aim the hoe at the ground within reach to set a point")
		return

	# Surveyor mode: after the first marker every new marker joins to the one before it, and the server builds the road behind the player.
	# A marker more than 40 m from the last one starts a new road.
	var chained: bool = _grade_has_a and _grade_a.distance_to(hit["position"]) <= 40.0

	_grade_has_a = true
	_grade_has_b = chained
	_net.inventory_action.rpc_id(1, Net.ACT_HOE_GRADE_POINT, held_slot, 1 if chained else 0, 0, hit["position"])
	_inv._on_notice("Marker set: the road builds behind you. Shift + right click to carry on" if chained else "Marker 1 set: walk on and Shift + right click again, the road builds behind you")

	_grade_a = hit["position"]
	var stake: Node3D = _make_stake()
	_root.add_child(stake)
	stake.global_position = hit["position"] + Vector3(0.0, 0.5, 0.0)
	_stakes.append(stake)


# The server says the road builder has reached (or dropped) a marker: its red flag comes down.
func _on_road_marker_reached(at: Vector3) -> void:
	for stake in _stakes.duplicate():
		if not is_instance_valid(stake):
			_stakes.erase(stake)
		elif Vector2(stake.global_position.x - at.x, stake.global_position.z - at.z).length() < 0.6:
			stake.queue_free()
			_stakes.erase(stake)


# A hoe stroke (path or smooth) at the ground under the crosshair; the server checks the hoe, the reach and the pace.
func _hoe_here(action: int) -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit["collider"].has_meta("species_ids"):
		_inv._on_notice("Nothing to work there: aim the hoe at the ground within reach")
		return

	_net.inventory_action.rpc_id(1, action, held_slot, 0, 0, hit["position"])

	# The hoe was silent (first-day tool audit, 3 Nov 2026): a soft scrape of the blade on the soil, firmer for tilling. Played when the click is sent, like the
	# shovel fill (the server may still refuse). It borrows the spade-on-soil clips (no hoe recording yet).
	if _sound != null:
		_sound.hits.hit("spade", "soil", hit["position"], 0.7 if action == Net.ACT_TILL else 0.4)


# A spade fill at the ground under the crosshair (right click): the server spends a shovelful and puts the ground back.
func _fill_here() -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit["collider"].has_meta("species_ids"):
		_inv._on_notice("Nothing to fill there: aim the spade at the ground within reach")
		return

	_net.inventory_action.rpc_id(1, Net.ACT_FILL, held_slot, 0, 0, hit["position"])

	if _sound != null:
		_sound.placed.shovel_load(false, hit["position"])   # shortcut: always the soil scoop, played when the click is sent (the server may still refuse); revisit when the fill result carries its material


var raise_mode: bool = false              # the spade raises ground (Dave 2026-10-22); false digs


func _other_tool_hint() -> String:
	match str(_inv.table.entry(held_id()).get("tool_class", "")):
		"rod":
			return "Click at the water to cast, and click again when something bites"
		"net":
			return "Stand at the water's edge facing the water and hold the left button for about 20 seconds"
		"hoe":
			return "The hoe does what its mode says (left click; now: %s). Right click opens a window to pick: path, smooth, till or survey a path. It uses no items, only its own wear" % hoe_mode
		"hammer":
			return "Right click opens the hammer menu: pick a blueprint, then left click places it"
		"spade":
			return "The spade digs roots and bulbs (press E at a plant), digs the ground (left click) or raises it in Raise mode (right click switches; each raise uses soil, sand, gravel, clay or stone from your pack)"

	return "%s: nothing to use it on yet" % _inv.table.name_of(held_number())


# The line over the hotbar. Dave 10 Nov 2026: it does not name what is in hand ("it doesnt need to say wooden bow in hand. or anything"), so it
# shows only a state the player has to know: the picked blueprint and why it is red, the hammer's mode, why a placement is red, and the
# spade's or hoe's mode. Empty otherwise.
func _caption() -> String:
	if held_number() == 0:
		return ""

	if _blueprinting():
		var short: bool = not blueprints.can_afford(_hammer_tier())
		var text: String = "%s blueprint" % blueprints.name_of(blueprints.picked) if blueprints.plan_picked < 0 else "%s (%d pieces)" % [blueprints.plans.plans[blueprints.plan_picked]["name"], blueprints.plans.plans[blueprints.plan_picked]["pieces"].size()]

		if PlacementRules.reason_text(blueprint_state) != "":
			return text + "   (red: %s)" % PlacementRules.reason_text(blueprint_state)

		if short and blueprints.plan_picked >= 0:
			return text + "   (red: not enough materials; right click: the list)"

		if short:
			return text + "   (left click: set down a blue blueprint, then E on it to deposit materials; right click: the list)"

		return text + "   (left click: build it with the materials in your pack; right click: the list)"

	if _hammer_tier() > 0 and blueprints.mode == "repair":
		return "Repair: left click a worn piece to mend it, or a blueprint to fill it from all around you; right click: the menu"

	if _hammer_tier() > 0 and blueprints.mode == "save":
		return "Save building plan: left click a building to keep it; right click: the menu"

	if _is_placeable() and PlacementRules.reason_text(blueprint_state) != "":
		return "Red: %s" % PlacementRules.reason_text(blueprint_state)

	var tool_class: String = str(_inv.table.entry(held_id()).get("tool_class", "")) if _is_other_tool() else ""

	if tool_class == "spade":
		return "%s (right click switches)" % ("Raise" if raise_mode else "Dig")

	if tool_class == "hoe":
		return "%s (right click: choose what it does)" % _hoe_mode_name()

	return ""


func _hoe_mode_name() -> String:
	for mode in HOE_MODES:
		if str(mode["id"]) == hoe_mode:
			return str(mode["name"])

	return "Path"


func _show_model() -> void:
	var number: int = held_number() if _inv != null else 0

	if not _is_spear() and not _is_axe() and not _is_torch() and not _is_doused_torch() and not _is_knife() and not _is_other_tool() and not _is_placeable() and not _is_look_item():
		number = 0

	if number != 0 and _left_number() == number and off_number() == 0:
		number = 0      # a torch taken as the main item is drawn in the left hand in third person (_left_number)

	if number == _shown_number:
		return

	_shown_number = number

	if _model != null:
		_model.queue_free()
		_model = null

	if number != 0:
		_model = _make_look_model() if _is_look_item() else _make_kit_model() if _is_placeable() else _make_spear_model() if _is_spear() else (_make_torch_model() if _is_torch() or _is_doused_torch() else (_make_knife_model() if _is_knife() else (_make_other_model() if _is_other_tool() else _make_axe_model())))
		_mount_model()


# Put the model in the hand: its business end leads along the fingers (-Z of the mount) and the grip sits in the palm.
# Falls back to the old spot in front of the camera when there are no arms.
func _mount_model() -> void:
	_mounted = _arms != null
	var third_fist: Node3D = _model.get_node_or_null(THIRD_FIST_NAME) as Node3D

	if third_fist != null:
		third_fist.visible = false      # shown again by _mount_model_third
	var kind: String = "kit" if (_is_placeable() or _is_look_item()) else "spear" if _is_spear() else ("torch" if _is_torch() else ("knife" if _is_knife() else ("axe" if _is_axe() else "other")))

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
	var tilt: Basis = Basis(Vector3.RIGHT, deg_to_rad(TOOL_TILT_DEG if kind in ["spear", "kit"] else TOOL_TILT_SLIGHT_DEG))
	var turn: Basis = Basis.IDENTITY
	var grip: Vector3 = Vector3(0.0, 0.0, -SPEAR_GRIP_Z)

	if kind == "kit":
		grip = Vector3(0.0, -0.03, -0.14)   # carried in the palm, a little ahead of the hand
	elif kind != "spear":
		turn = Basis(Vector3.RIGHT, deg_to_rad(-90.0))   # +Y (handle to head) becomes -Z (along the fingers)

		if str(_inv.table.entry(held_id()).get("tool_class", "")) == "hoe":
			turn = turn * Basis(Vector3.UP, deg_to_rad(HELD_HOE_ROLL_DEG))   # roll the hoe about its haft so the blade face shows in the frame (Tyler: first person read as a stick)
		grip = Vector3(0.0, 0.0, -float(_model.get_meta("grip_y", GRIP_ALONG_Y[kind])))

		if _model.has_meta("held_pitch_deg"):
			turn = Basis(Vector3.RIGHT, deg_to_rad(float(_model.get_meta("held_pitch_deg")))) * turn   # point the tip up into the view
			grip.y += 0.05

	_model.basis = (tilt * turn).scaled(Vector3.ONE / ARMS_SCALE)      # the hand mount is scaled with the arms
	_model.position = tilt * grip / ARMS_SCALE


# Third person: the hand hangs at the side (mount -Z down the fingers, +Y forward, +Z up), so a tool is turned to stand up and a little forward.
func _mount_model_third(kind: String) -> void:
	_avatar_rig.hand_mount_r.add_child(_model)
	var turn: Basis = Basis(Vector3.RIGHT, deg_to_rad(THIRD_LEAN_DEG))
	var grip: Vector3 = Vector3(0.0, float(_model.get_meta("grip_y", GRIP_ALONG_Y.get(kind, 0.0))) * THIRD_CHOKE, 0.0)   # the hand sits grip below the model middle, on the handle end (Dave 2026-10-22: it was held by the head)

	var carried: String = str(_inv.table.entry(held_id()).get("tool_class", ""))

	if carried == "spade":
		turn = Basis(Vector3.RIGHT, deg_to_rad(THIRD_SPADE_PITCH_DEG))
	elif carried == "hoe":
		turn = Basis(Vector3.RIGHT, deg_to_rad(THIRD_HOE_PITCH_DEG))
	elif carried == "saw":
		turn = Basis(Vector3.RIGHT, deg_to_rad(THIRD_SAW_PITCH_DEG))
	elif carried == "rod":
		turn = Basis(Vector3.RIGHT, deg_to_rad(THIRD_ROD_PITCH_DEG))

	if kind == "spear":
		turn = Basis(Vector3.RIGHT, deg_to_rad(150.0))
		grip = Vector3(0.0, 0.0, -SPEAR_GRIP_Z)
	elif kind == "kit":
		turn = Basis.IDENTITY
		grip = Vector3(0.0, -0.03, -0.14)

	_model.basis = turn
	_model.position = turn * grip

	if kind != "kit":
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
		skin.albedo_color = _third_skin_color()
		skin.roughness = 0.64          # the body's own skin roughness (Dave's glb, the metallic-roughness texture's median)
		skin.metallic_specular = 0.35
		ball.material = skin
		fist.mesh = ball
		model.add_child(fist)

	fist.transform = model.transform.affine_inverse() * Transform3D(Basis.from_scale(THIRD_FIST_SCALE), Vector3.ZERO)
	return fist


# The third-person fist's colour (Dino's #488 look, 6 Nov 2026: the grip read as a pale blob): the body's painted skin, not the first-person arms' FIST_COLOR.
# THIRD_SKIN is the median of Dave's skin texture (Dynasty_Base_Male.glb, sRGB), times the skin tint the body wears for this character (dynasty_body.gd dress).
const THIRD_SKIN := Color(0.718, 0.498, 0.376)


func _third_skin_color() -> Color:
	var tint: Color = Color.WHITE
	var worn: Variant = _avatar_rig.get("_skin_material") if _avatar_rig != null else null

	if worn is BaseMaterial3D:
		tint = (worn as BaseMaterial3D).albedo_color

	return Color(THIRD_SKIN.r * tint.r, THIRD_SKIN.g * tint.g, THIRD_SKIN.b * tint.b)


# The left-hand item: a torch (with its light) or a shield, mounted on the left hand; B raises a shield.
func _show_off_model(delta: float) -> void:
	var number: int = _left_number() if _inv != null else 0
	blocking = number != 0 and _off_class() == "shield" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_key_pressed(KEY_B)

	if number != _off_shown:
		_off_shown = number

		if _off_model != null:
			_off_model.queue_free()
			_off_model = null

		if number != 0:
			_off_model = _make_shield_model() if _off_class() == "shield" else _make_torch_model(_left_id())
			_mount_off_model()

	if _off_model == null:
		return

	var flicker: OmniLight3D = _off_model.get_node_or_null("Light")

	if flicker != null:
		flicker.visible = not held_light_budget.is_valid() or held_light_budget.call() or not _inv.fire_light_near(_camera.global_position, 8.0)
		flicker.light_energy = 2.0 + 0.4 * sin(float(Time.get_ticks_msec()) * 0.017)

	if _off_class() == "torch" and not _first_person and _avatar_rig != null and _off_model.get_parent() == _avatar_rig.hand_mount_l:
		_stand_torch_upright()

	if _off_class() == "shield":
		var lift: float = 1.0 if blocking else 0.0
		_off_model.position = _off_model.position.lerp(_off_rest + Vector3(0.0, 0.0, -0.18 * lift), clampf(delta * 16.0, 0.0, 1.0))


var _off_rest: Vector3 = Vector3.ZERO

const TORCH_LEAN := 0.12      # third-person torch carry: the shaft leans this much forward and this much out to the left per metre up (about 7 degrees each)


# Third person, torch in the left hand (Dave's torch carry infographic, 6 Nov 2026): the torch stands upright in the world, leaning a little forward and out
# from the body, whatever the hand's own angle, with the grip in the fist. The arm pose that puts the hand up in front is the body's (dynasty_body.gd _torch_carry).
func _stand_torch_upright() -> void:
	var skel: Node3D = _avatar_rig.get("skeleton") as Node3D
	var mount: Node3D = _avatar_rig.hand_mount_l as Node3D

	if skel == null or mount == null or not mount.is_inside_tree():
		return

	var front: Vector3 = skel.global_basis * Vector3.BACK      # the Dynasty skeleton faces +Z, its left is +X
	var left: Vector3 = skel.global_basis * Vector3.RIGHT
	front.y = 0.0
	left.y = 0.0

	if front.length() < 0.001 or left.length() < 0.001:
		return

	front = front.normalized()
	left = left.normalized()
	var shaft: Vector3 = (Vector3.UP + front * TORCH_LEAN + left * TORCH_LEAN).normalized()
	var across: Vector3 = shaft.cross(front).normalized()
	var upright: Basis = Basis(across, shaft, across.cross(shaft).normalized())
	var grip: float = float(_off_model.get_meta("grip_y", GRIP_ALONG_Y["torch"])) * THIRD_CHOKE
	_off_model.global_transform = Transform3D(upright, mount.global_position + shaft * grip)
	_third_fist_on(_off_model).visible = true


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
# The ground mesh of a held tool, turned and sized for the hand, or null when the item has no tool look (it keeps its old model).
# The grip distance from the model middle goes in the "grip_y" meta (see _mount_model).
func _make_look_tool_model() -> Node3D:
	var def: Dictionary = BasicLook.entry(held_id())
	var shape: String = str(def.get("shape", ""))

	if not HELD_LOOK_TURN.has(shape):
		return null

	if shape == "hand_net":
		return _make_hanging_net_model(def)

	var held: Mesh = BasicLook.mesh_for(held_id())
	var length: float = held.get_aabb().size.x
	var held_scale: float = HELD_SPEAR_SCALE if shape == "shaft" else (HELD_FIXED_SCALE[shape] if HELD_FIXED_SCALE.has(shape) else minf(HELD_LOOK_SCALE, HELD_LOOK_MAX_M / maxf(length, 0.01)))
	var node: Node3D = Node3D.new()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = held
	mesh.basis = (HELD_LOOK_TURN[shape] as Basis) * Basis.from_scale(Vector3(1.0, 2.0, 2.0) * held_scale if shape == "arrow" else Vector3.ONE * held_scale)   # an arrow's shaft is drawn twice as thick in hand, or it is a hairline on screen
	node.add_child(mesh)
	node.set_meta("grip_y", maxf(-held.get_aabb().position.x * held_scale - HELD_GRIP_FROM_END_M, 0.03))   # the hand sits a little in from the handle end

	if shape == "bow":
		node.set_meta("grip_y", 0.03)   # a bow is held at its middle
		# The hand's bow has no string in its mesh: two thin cords from the tips to the nock point, which follows the drawing hand (_pose_bow).
		mesh.mesh = BasicLook.mesh("bow", Color.html(str(def.get("color", "#a8804a"))), float(def.get("size", 1.0)), (def.get("bits", []) as Array) + ["held"])
		mesh.basis = Basis.IDENTITY
		node.set_meta("bow", true)
		node.set_meta("nock", Vector3.ZERO)   # the nock point in the bow's own space (mesh axes: limbs along x, back of the bow toward +z)

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
			node.add_child(cord)

		_set_bow_string(node, Vector3.ZERO)
		# The arrow on the string while the bow is up (shown only with an arrow in the pack): its nock on the string, its shaft over the left side of the bow,
		# resting on the bow hand (Dave 10 Nov 2026: "you place the arrow over the left side and then draw back and sight along the arrow shaft").
		var nocked: MeshInstance3D = MeshInstance3D.new()
		nocked.name = "NockedArrow"
		nocked.mesh = BasicLook.mesh_for("stone_arrow")
		nocked.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nocked.visible = false
		node.add_child(nocked)

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
func _make_torch_model(id: String = "") -> Node3D:
	var lit: bool = bool(_inv.table.entry(id if id != "" else held_id()).get("flame", false))   # a doused torch: no flame, no glow, no light
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
	light.omni_range = float(_inv.table.entry(id if id != "" else held_id()).get("light_m", 9.0))
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.0
	light.light_cull_mask = 0xFFFFFFFD   # the torch's own meshes (layer 2) are not lit by its own lights: they were over-lit orange at arm's length
	light.position = Vector3(0.0, 0.62, 0.0)
	torch.add_child(light)
	FireWeather.register(light)   # reach and halo follow fog and snow
	var hand_light: OmniLight3D = OmniLight3D.new()   # a short warm light low on the stick so the hand holding it is lit by the flame, not black
	hand_light.name = "HandLight"
	hand_light.light_color = Color(1.0, 0.6, 0.28)
	hand_light.omni_range = 1.6
	hand_light.light_energy = 0.7
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
	print("NET TEST: pack before: %s" % _net_test_pack())

	for slot in range(8):
		if _inv.inventory.numbers[slot] == net_n:
			select(slot)

	print("NET TEST: holding %s in slot %d" % [held_id(), held_slot])

	for n in 4:
		var used: bool = mouse_button(MOUSE_BUTTON_LEFT, true)
		await get_tree().create_timer(0.3).timeout
		mouse_button(MOUSE_BUTTON_LEFT, false)
		await get_tree().create_timer(9.0).timeout   # the net sinks for hold_s (6 s) and is hauled back
		print("NET TEST: click %d (used %s): nets in pack %d, nets on the ground %d; pack %s" % [n + 1, used, _inv.inventory.count_of(net_n), _net_test_ground(net_n), _net_test_pack()])

	print("NET TEST: %s" % ("PASS: still one net" if _inv.inventory.count_of(net_n) == 1 and _net_test_ground(net_n) == 0 else "FAIL: the net count changed"))


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
