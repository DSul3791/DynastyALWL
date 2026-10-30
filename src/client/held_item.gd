extends Node

# What the player holds (hotbar keys 1 to 9 and 0 choose pack slots 0 to 9; the key again puts it away) and how it is used.
# Client only; the server decides what happens (throws are server actions).
#
# Spear (Dave, 2026-10-20): held and jabbed by default with the normal attack key (left click).
# Hold right click to aim a throw; then left click throws. Letting go of right click returns to
# the normal stance. The weapon is drawn as a simple first-person model until real art exists.

const Net := preload("res://src/stream/terrain_net.gd")
const BuildingLook := preload("res://src/client/building_look.gd")
const PlacementRules := preload("res://src/shared/placement_rules.gd")
const BasicLook := preload("res://src/client/basic_look.gd")
const RagdollScript := preload("res://src/client/ragdoll_body.gd")
const ArmsView := preload("res://src/client/character/arms_view.gd")

const HOTBAR_FILE := "user://hotbar.txt"      # the chosen hotbar slot is remembered between sessions
const REST := Vector3(0.38, -0.32, -0.55)       # model offset from the camera
const AIMED := Vector3(0.28, -0.12, -0.35)
# First-person arms (Art's ragdoll rig, assets/character/README.md): rooted at the chest a little below and behind the camera,
# pitched forward so a tool in the hand points ahead instead of hanging down. The tool goes to the hand on the viewer's right
# (the rig's hand_mount_r: the rig's right is +X, see assets/character/README.md), grip at the mount origin, its business end tipped
# up TOOL_TILT_DEG from the fingers. Rendered with software Vulkan and looked at (still frames of idle, jab, swing).
const ARMS_POS := Vector3(0.0, -0.1, -0.15)
const ARMS_PITCH_DEG := 50.0
const TOOL_TILT_DEG := 20.0
const TOOL_TILT_SLIGHT_DEG := 23.0  # first person, hand tools: up from the fingers; the resting arm points 40 degrees below level (REST_PITCH_DEG 50), so the head is about 17 degrees down
# Dave 2026-10-21: at rest the arms hang at the character's side, below the bottom of the screen, and the tool sits in the hand there,
# fixed to the body (the way you face, not the way you look): look down and you see it. Swinging, jabbing, using or aiming brings the
# arms up to the camera pose above and back. REST_* is the body pose: where the chest is under the eye and how far forward the arms hang.
const REST_DOWN_M := 0.3               # first-person arms at rest: root this far below the eye; the hands sit below a level view and show only when the player looks down about 30 to 45 degrees (Dave 2026-10-25)
const REST_BACK_M := 0.05
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
const THIRD_CHOKE := 0.6         # the hand takes the handle this share of the way from the middle to the end, so less of the tool stands above the hand
# A tool with a stage-one look (data/items/looks.json) is held as the same mesh that lies on the ground (Dave 2026-10-24: the held tools
# looked like old placeholders). BasicLook tool meshes run handle to head along +X; HELD_LOOK_TURN turns that to the held convention
# (+Y handle to head, +Z up in hand) with the blade's cutting side down (axe, pick, hoe, knife) or the flat of a spade facing up.
const HELD_LOOK_SCALE := 1.4
const HELD_SPEAR_SCALE := 1.6
const HELD_FIXED_SCALE := {"rod": 1.2, "hoe": 1.0, "saw": 1.0, "bow": 1.8, "arrow": 2.2}   # held at ground size, not scaled to the 1 m cap or by 1.4x: the rod's cane and reel were lost, the hoe blade was tiny and the saw nearly 1 m long
const HELD_LOOK_MAX_M := 1.0      # no held tool longer than this (a big look size or a long hoe is scaled down to it)
const HELD_GRIP_FROM_END_M := 0.12
const HELD_LOOK_TURN := {
	"axe": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"pick": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),   # haft forward (+y), head vertical with the pointed pick DOWN and the chisel up (Dave 2026-10-25: flip it 180 degrees about the haft), both ends bending toward the grip in the haft-and-head plane, so from the front the head is one straight bar
	"hoe": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"knife": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"saw": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"hammer": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"spade": Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)),
	"shaft": Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)),
	"rod": Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)),   # the fishing rod: butt to tip along +y, the reel underneath (-z), so the rod points forward and up in the hand
	"bow": Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)),   # the bow stands upright in the hand (limbs up and down, belly forward, string toward the archer)
	"arrow": Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)),
	"quiver": Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)),
}
const JAB_REACH := 0.7
const JAB_S := 0.28
const THROW_SPEED := 24.0
const THROW_GRAVITY := 9.8

var held_slot: int = 0
var holding: bool = true                  # false after the held slot's key is pressed again: hands empty
const HOTBAR_SLOTS := 10
var aiming: bool = false
var off_slot: int = -1                    # the hotbar slot carried in the left hand (items with "offhand": true: torch, shield), -1 for none
var off_holding: bool = false             # false after its key is pressed again: left hand empty
var blocking: bool = false                # B held with a shield in the left hand (the combat rules read this)
var _off_model: Node3D
var _off_shown: int = 0

var _inv                                  # InventoryView
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
var _draw_t: float = -1.0                 # a bow being drawn: seconds since the left button went down, -1 when not
var _flights: Array = []                  # local visuals of spears this player threw: {node, vel, age}
var _shown_number: int = 0
var _sound                                # SoundStage (hit sounds)
var _tree_near: Callable                  # (point) -> [chunk, id] of the tree trunk standing there, or []
var _swing_t: float = -1.0
var _swing_hit: bool = false
var _cover_at: Callable                   # (point) -> true when under a tree's crown
var _blueprint: Node3D
var _blueprint_kit: String = ""
var _ghost_material: StandardMaterial3D
var _blueprint_at: Vector3 = Vector3.ZERO
var _blueprint_ok: bool = false
var _placement: Dictionary = {}              # structures.json: footprints, gaps, caps (shared with the server's rules)
var blueprint_state: String = ""            # what the ghost shows now: "open", "covered", "close", "crowded" or "steep" (tests read it)
var _blueprint_shape: Vector2 = Vector2(-1.0, -1.0)
var _blueprint_next_msec: int = 0
var blueprints = HammerBlueprints.new()      # the hammer's blueprint list (R with a hammer in hand); the picked one is placed from the pack's materials, no kit item

const SWING_S := 0.55
const HIT_STOP_S := 0.045
const HIT_AT := 0.636                      # share of the swing where the tool reaches the target (the swing_fp clip's impact key, 0.35 s of 0.55); the thump and the server's hit are this same tick
const REACH_M := 3.0


const FrameProbe := preload("res://src/debug/frame_probe.gd")
const HammerBlueprints := preload("res://src/client/hammer_blueprints.gd")
const FlameUp := preload("res://src/client/flame_up.gd")

func setup(inventory_view, terrain_net, camera: Camera3D, world_root: Node3D, hud_layer: CanvasLayer, ground_below: Callable, sound_stage = null, tree_near: Callable = Callable(), cover_at: Callable = Callable()) -> void:
	_cover_at = cover_at
	_sound = sound_stage
	_placement = PlacementRules.load_config()

	if FileAccess.file_exists(HOTBAR_FILE):
		held_slot = clampi(int(FileAccess.get_file_as_string(HOTBAR_FILE)), 0, HOTBAR_SLOTS - 1)

	_tree_near = tree_near
	_inv = inventory_view
	blueprints.setup(_inv.table, _inv.inventory, hud_layer)
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
	_arms = RagdollScript.new(true)
	_arms.name = "Arms"
	_arms.position = ARMS_POS
	_arms.rotation_degrees.x = ARMS_PITCH_DEG
	camera.add_child(_arms)
	_arms.play("idle")
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


# A hotbar key: hold that slot, or put it away when it is the one already held.
func press_slot(slot: int) -> void:
	# Torch and shield go in the left hand beside whatever the right hand holds (Dave 2026-10-23); the same key again stows it.
	if is_offhand(_inv.inventory.numbers[clampi(slot, 0, HOTBAR_SLOTS - 1)]):
		slot = clampi(slot, 0, HOTBAR_SLOTS - 1)

		if off_holding and off_slot == slot:
			off_holding = false
			blocking = false
		else:
			off_slot = slot
			off_holding = true

		_inv.refresh_hotbar()

		if _sound != null:
			_sound.itemfx.hotbar(slot)

		return

	if holding and slot == held_slot:
		holding = false
		aiming = false
		_inv.refresh_hotbar()

		if _sound != null:
			_sound.itemfx.hotbar(held_slot)

		return

	select(slot)


# Use on a tool in the inventory: hold it, or put it away if it is already in hand.
func equip_toggle(slot: int) -> void:
	press_slot(clampi(slot, 0, HOTBAR_SLOTS - 1))


func select(slot: int) -> void:
	if _sound != null and (clampi(slot, 0, HOTBAR_SLOTS - 1) != held_slot or not holding):
		_sound.itemfx.hotbar(clampi(slot, 0, HOTBAR_SLOTS - 1))

	held_slot = clampi(slot, 0, HOTBAR_SLOTS - 1)
	holding = true
	aiming = false
	_inv.refresh_hotbar()
	var number: int = _inv.inventory.numbers[held_slot]

	if number != 0 and not is_holdable(number):
		_inv._on_notice("%s cannot be held in the hand (Use or Eat it from the inventory)" % _inv.table.name_of(number))

	var file: FileAccess = FileAccess.open(HOTBAR_FILE, FileAccess.WRITE)

	if file != null:
		file.store_string(str(held_slot))


func held_number() -> int:
	return _inv.inventory.numbers[held_slot] if holding else 0


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


# R with a hammer in hand opens or shuts its blueprint list.
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
	if not off_holding or off_slot < 0:
		return 0

	var number: int = _inv.inventory.numbers[off_slot]
	return number if is_offhand(number) else 0


func off_id() -> String:
	return _inv.table.id_of(off_number())


func _off_class() -> String:
	return str(_inv.table.entry(off_id()).get("tool_class", ""))


func _is_spear() -> bool:
	return str(_inv.table.entry(held_id()).get("weapon_class", "")) == "spear"


func _is_bow() -> bool:
	return str(_inv.table.entry(held_id()).get("weapon_class", "")) == "bow" and not _inv.is_broken(held_slot)


func _is_placeable() -> bool:
	return str(_inv.table.entry(held_id()).get("kind", "")) == "placeable"


func _is_torch() -> bool:
	return str(_inv.table.entry(held_id()).get("tool_class", "")) == "torch"


func _is_knife() -> bool:
	return str(_inv.table.entry(held_id()).get("tool_class", "")) == "knife"


# Any other tool or weapon (spade, and every tool added later) is held too: it has a generic model and plays the "use" arm
# animation on left click, so nothing silently fails to be held.
func _is_other_tool() -> bool:
	var kind: String = str(_inv.table.entry(held_id()).get("kind", ""))
	var is_arrow: bool = str(BasicLook.entry(held_id()).get("shape", "")) == "arrow"   # arrows are "material" items but are held like a tool, not as a palm-sized look
	return (kind in ["tool", "weapon", "container"] or is_arrow) and not _is_spear() and not _is_torch() and not _is_knife() and not _is_axe()


func is_holdable(number: int) -> bool:
	if number == 0:
		return false

	var entry: Dictionary = _inv.table.entry(_inv.table.id_of(number))
	return str(entry.get("kind", "")) in ["tool", "weapon", "placeable", "container"] or _inv.edible_slot(held_slot)


# Food and small things with a stage-one look (data/items/looks.json) are carried in the palm, drawn as they lie on the ground.
func _is_look_item() -> bool:
	return BasicLook.has_look(held_id()) and not _is_spear() and not _is_axe() and not _is_torch() and not _is_knife() and not _is_other_tool() and not _is_placeable()


func _make_look_model() -> Node3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = BasicLook.mesh_for(held_id())
	node.scale = Vector3.ONE * 1.8   # same enlargement as on the ground, so a berry is seen in the palm
	return node


func _is_axe() -> bool:
	return str(_inv.table.entry(held_id()).get("tool_class", "")) in ["axe", "pick"] and not _inv.is_broken(held_slot)


# One chop of an axe or pick. Holding the left button chains them (see _process): the next starts as the last one ends.
func _start_swing() -> void:
	_swing_t = 0.0
	_swing_hit = false
	_arm_play("swing_fp", SWING_S)



# The mouse wheel while a foundation is held raises or lowers where it will stand, in 0.1 m steps. Returns true when it was used here.
func wheel(down: bool) -> bool:
	if blueprints.is_open:
		blueprints.move(down, _hammer_tier())
		return true

	if _blueprinting():
		var picked_def: Dictionary = PlacementRules.structure_of_kit(_placement, blueprints.kit_of(blueprints.picked))

		if bool(picked_def.get("foundation", false)):
			lift_steps = clampi(lift_steps + (-1 if down else 1), 0, PlacementRules.LIFT_MAX_STEPS)
			_inv._on_notice("Foundation raised %.1f m off the ground" % (float(lift_steps) * PlacementRules.LIFT_STEP_M))
			return true

		return false

	if not holding or not _is_placeable():
		return false

	var def: Dictionary = PlacementRules.structure_of_kit(_placement, held_id())

	if bool(def.get("foundation", false)):
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

	if blueprints.is_open:
		if button == MOUSE_BUTTON_LEFT and pressed:
			blueprints.choose(_hammer_tier())

		return button == MOUSE_BUTTON_LEFT

	if _blueprinting():
		if button == MOUSE_BUTTON_LEFT and pressed and _blueprint_ok:
			_net.inventory_action.rpc_id(1, Net.ACT_PLACE_BLUEPRINT, blueprints.picked, lift_steps, _blueprint_yaw, _blueprint_at)

		return button == MOUSE_BUTTON_LEFT

	if _is_placeable():
		if button == MOUSE_BUTTON_LEFT and pressed and _blueprint_ok:
			_net.inventory_action.rpc_id(1, Net.ACT_PLACE, _place_slot(), lift_steps, _blueprint_yaw, _blueprint_at)

		return button == MOUSE_BUTTON_LEFT

	if _is_axe():
		if button == MOUSE_BUTTON_RIGHT and pressed:
			_net.inventory_action.rpc_id(1, Net.ACT_ICEHOLE, held_slot, 0, 0, Vector3.ZERO)
			_arm_play("use", 0.6)
			return true

		if button == MOUSE_BUTTON_LEFT and pressed and _swing_t < 0.0:
			_start_swing()

		return button == MOUSE_BUTTON_LEFT

	if _is_bow():
		# The bow: hold the left button to draw, let go to loose the arrow along the view; the server clamps the draw time (data/items/bow.json).
		if button == MOUSE_BUTTON_LEFT:
			if pressed:
				_draw_t = 0.0
				_arm_play("use", 0.6)
			elif _draw_t >= 0.0:
				_net.inventory_action.rpc_id(1, Net.ACT_SHOOT, held_slot, int(_draw_t * 1000.0), 0, -_camera.global_transform.basis.z)
				_draw_t = -1.0

			return true

		return false

	if _is_other_tool():
		# The shore net: hold the left button at the water's edge (about 20 s); letting go cancels (the server also cancels when you walk off).
		if button == MOUSE_BUTTON_LEFT and str(_inv.table.entry(held_id()).get("tool_class", "")) == "net":
			if pressed:
				_arm_play("use", 0.6)

			_net.inventory_action.rpc_id(1, Net.ACT_NET, held_slot, 0 if pressed else 1, 0, _camera.global_position - _camera.global_transform.basis.z * 2.5 - Vector3(0.0, 1.2, 0.0))
			return true

		# Right click with the spade switches between Dig and Raise mode (Dave 2026-10-22).
		if button == MOUSE_BUTTON_RIGHT and pressed and str(_inv.table.entry(held_id()).get("tool_class", "")) == "spade":
			raise_mode = not raise_mode
			_inv._on_notice("Raise mode: left click adds ground, using soil or stone from your pack" if raise_mode else "Dig mode: left click digs")
			return true

		# The garden hoe: left click treads a path, right click smooths the ground (it moves dirt from the high spots to the low ones; no items).
		if pressed and (button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT) and str(_inv.table.entry(held_id()).get("tool_class", "")) == "hoe":
			_arm_play("use", 0.6)

			if Input.is_key_pressed(KEY_SHIFT):
				# Shift + right click sets point A, then point B; Shift + left click (held) grades the ground along the line.
				if button == MOUSE_BUTTON_RIGHT:
					_grade_point_here()
				else:
					_hoe_here(Net.ACT_HOE_GRADE)
			else:
				_hoe_here(Net.ACT_HOE_PATH if button == MOUSE_BUTTON_LEFT else Net.ACT_HOE_SMOOTH)

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
	if _draw_t >= 0.0:
		_draw_t = _draw_t + delta if _is_bow() else -1.0   # putting the bow away lets the draw go

	_update_blueprint()
	_hoe_repeat(delta)

	if _sound != null:
		var flame_kind: String = str(_inv.table.entry(held_id()).get("tool_class", ""))

		if flame_kind not in ["torch", "lantern"]:
			flame_kind = _off_class()

		var sheltered: bool = _cover_at.is_valid() and bool(_cover_at.call(_camera.global_position))
		_sound.flame.set_held(flame_kind if flame_kind in ["torch", "lantern"] else "", not sheltered)

	_show_model()
	_show_off_model(delta)
	_label.text = _caption()
	if _inv != null:
		_label.offset_bottom = -float(_inv.text_px(78 + 14 + 8))    # above the hotbar at any text size (Dave, build 617: they overlapped)
	_place_arms(delta)

	if _arms != null and _arms.visible and _arms.current() != "idle" and not _arms.is_one_shot_playing():
		_arms.play("idle")

	# Hit stop: the animation freezes for a moment at the impact (Tyler Report 26), then goes on.
	if _stop_t > 0.0:
		_stop_t -= delta

		if _stop_t <= 0.0 and _arms != null:
			_arms.animation_player.speed_scale = 1.0

	if _swing_t >= 0.0 and _stop_t <= 0.0:
		_swing_t += delta

		if not _swing_hit and _swing_t >= SWING_S * HIT_AT:
			_swing_hit = true
			_strike()
			_stop_t = HIT_STOP_S

			if _arms != null and _arms.visible:
				_arms.animation_player.speed_scale = 0.0

		if _swing_t >= SWING_S:
			_swing_t = -1.0

			# Dave 2026-10-21: holding the button keeps chopping, one swing after another (no gap, no clicking).
			if holding and _is_axe() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_start_swing()

	if _model != null and _is_torch():
		var flicker: OmniLight3D = _model.get_node_or_null("Light")

		if flicker != null:
			# Own light: one, shadowless. At Low it gives way to a fire light within 8 m, so no more than one lamp lights the same spot.
			flicker.visible = not held_light_budget.is_valid() or held_light_budget.call() or not _inv.fire_light_near(_camera.global_position, 8.0)
			flicker.light_energy = 1.4 + 0.3 * sin(float(Time.get_ticks_msec()) * 0.017)

		if not _mounted:
			_model.position = _model.position.lerp(REST, clampf(delta * 14.0, 0.0, 1.0))
	elif _model != null and _mounted:
		pass   # in the hand: the arm animation moves it
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

	var working: bool = _swing_t >= 0.0 or _jab_t >= 0.0 or aiming or _arms.is_one_shot_playing()
	_arm_up = ArmsView.next_arm_up(_arm_up, working, ARMS_FOLLOW_K, delta)
	_arms.transform = ArmsView.arms_transform(_camera.global_transform, _camera.global_rotation.y, _arm_up, REST_PITCH_DEG, REST_DOWN_M, REST_BACK_M, ARMS_POS, ARMS_PITCH_DEG, ARMS_SCALE)


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
func _update_blueprint() -> void:
	if (blueprints.picked > 0 or blueprints.is_open) and _hammer_tier() <= 0:
		blueprints.clear()   # the hammer is put away: the pick and the list go with it

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

	var blocked: bool = blueprint_state == "close" or blueprint_state == "crowded" or blueprint_state == "steep" or blueprint_state == "water" or blueprint_state == "nofire" or blueprint_state == "taken"
	_blueprint_ok = _blueprint_ok and not blocked and (not _blueprinting() or blueprints.can_afford(_hammer_tier()))
	_ghost_material.albedo_color = Color(0.9, 0.2, 0.2, 0.5) if blocked else Color(0.3, 0.9, 0.3, 0.5)


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
	var boulder_id: int = _inv.boulder_near(hit["position"])
	var log_id: int = _inv.loose_log_near(hit["position"])

	if log_id != 0:
		_sound.hits.hit("axe", "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_PROCESS, log_id, 0, 0, Vector3.ZERO)
	elif boulder_id != 0:
		_sound.hits.hit_ground("pick", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_HIT, boulder_id, Net.HIT_BOULDER, 0, Vector3.ZERO)
	elif trunk_id != 0:
		_sound.hits.hit("axe", "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_PROCESS, trunk_id, 0, 0, Vector3.ZERO)
	elif not tree.is_empty():
		_sound.hits.hit("axe", "wood", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_HIT, tree[1], tree[0].x, tree[0].y, Vector3.ZERO)
	else:
		_sound.hits.hit_ground("pick", hit["position"], 1.0)
		_net.inventory_action.rpc_id(1, Net.ACT_MINE, 0, 0, 0, hit["position"])


# A spade swing at the ground under the crosshair: the server checks the spade and the reach, cuts the hole and tells
# everyone (the hole, the sound and the vanishing grass happen when it answers; DIGGING_DESIGN.md).
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
		return

	var left: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if not left and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_hoe_t = 0.0
		return

	_hoe_t += delta

	if _hoe_t >= HOE_REPEAT_S:
		_hoe_t = 0.0
		_arm_play("use", 0.6)

		if Input.is_key_pressed(KEY_SHIFT):
			if left:
				_hoe_here(Net.ACT_HOE_GRADE)
		else:
			_hoe_here(Net.ACT_HOE_PATH if left else Net.ACT_HOE_SMOOTH)


# Grade line points: the first click sets A, the next B, the next starts a new line at A. Stakes mark them; the server keeps its own copy.
var _grade_a: Vector3 = Vector3.ZERO
var _grade_has_a: bool = false
var _grade_has_b: bool = false
var _stakes: Array = []


func _grade_point_here() -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit["collider"].has_meta("species_ids"):
		_inv._on_notice("Aim the hoe at the ground within reach to set a point")
		return

	var setting_b: bool = _grade_has_a and not _grade_has_b

	if setting_b:
		_grade_has_b = true
	else:
		_grade_has_a = true
		_grade_has_b = false

	_net.inventory_action.rpc_id(1, Net.ACT_HOE_GRADE_POINT, held_slot, 1 if setting_b else 0, 0, hit["position"])
	_inv._on_notice("Point B set: hold Shift and left click along the line to grade it" if setting_b else "Point A set: Shift + right click again for point B")

	for stake in _stakes:
		if is_instance_valid(stake):
			stake.queue_free()

	_stakes.clear()

	if not setting_b:
		_grade_a = hit["position"]

	for point in ([_grade_a, hit["position"]] if setting_b else [hit["position"]]):
		var stake: MeshInstance3D = MeshInstance3D.new()
		var post: CylinderMesh = CylinderMesh.new()
		post.top_radius = 0.03
		post.bottom_radius = 0.03
		post.height = 1.0
		stake.mesh = post
		_root.add_child(stake)
		stake.global_position = point + Vector3(0.0, 0.5, 0.0)
		_stakes.append(stake)


# A hoe stroke (path or smooth) at the ground under the crosshair; the server checks the hoe, the reach and the pace.
func _hoe_here(action: int) -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit["collider"].has_meta("species_ids"):
		_inv._on_notice("Nothing to work there: aim the hoe at the ground within reach")
		return

	_net.inventory_action.rpc_id(1, action, held_slot, 0, 0, hit["position"])


# A spade fill at the ground under the crosshair (right click): the server spends a shovelful and puts the ground back.
func _fill_here() -> void:
	var from: Vector3 = _camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - _camera.global_transform.basis.z * REACH_M)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty() or hit["collider"].has_meta("species_ids"):
		_inv._on_notice("Nothing to fill there: aim the spade at the ground within reach")
		return

	_net.inventory_action.rpc_id(1, Net.ACT_FILL, held_slot, 0, 0, hit["position"])


var raise_mode: bool = false              # the spade raises ground (Dave 2026-10-22); false digs


func _other_tool_hint() -> String:
	match str(_inv.table.entry(held_id()).get("tool_class", "")):
		"rod":
			return "Click at the water to cast, and click again when something bites"
		"net":
			return "Stand at the water's edge facing the water and hold the left button for about 20 seconds"
		"hoe":
			return "The hoe treads a path (left click) and smooths the ground by moving dirt from high spots to low ones (right click). It uses no items, only its own wear"
		"spade":
			return "The spade digs roots and bulbs (press E at a plant), digs the ground (left click) or raises it in Raise mode (right click switches; each raise uses soil, sand, gravel, clay or stone from your pack)"

	return "%s: nothing to use it on yet" % _inv.table.name_of(held_number())


func _caption() -> String:
	var number: int = held_number()

	if number == 0:
		return _off_caption()

	var text: String = _inv.table.name_of(number)

	if _blueprinting():
		var short: bool = not blueprints.can_afford(_hammer_tier())
		text = "%s blueprint" % blueprints.name_of(blueprints.picked)

		if PlacementRules.reason_text(blueprint_state) != "":
			text += "   (red: %s)" % PlacementRules.reason_text(blueprint_state)
		elif short:
			text += "   (red: not enough materials; R: the list)"
		else:
			text += "   (left click: build it with the materials in your pack; R: the list)"
	elif _is_placeable() and PlacementRules.reason_text(blueprint_state) != "":
		text += "   (red: %s)" % PlacementRules.reason_text(blueprint_state)
	elif _is_placeable():
		text += "   (left click: place; under a tree it keeps dry, in the open rain puts it out)" if _blueprint_shape == Vector2.ZERO else "   (left click: place, it faces you)"
	elif _is_torch():
		text += "   (lights the way while held)"
	elif _is_axe():
		text += "   (left click: swing)"
	elif _is_spear():
		text += "   (left click: jab; hold right click to aim, then left click to throw)"
	elif _is_other_tool() and str(_inv.table.entry(held_id()).get("tool_class", "")) == "spade":
		text += "   (%s; right click switches)" % ("Raise" if raise_mode else "Dig")
	elif _is_other_tool():
		text += "   (in hand)"

	var off: String = _off_caption()
	return text if off == "" else "%s\n%s" % [text, off]


# The left-hand line under the right-hand one.
func _off_caption() -> String:
	if off_number() == 0:
		return ""

	var text: String = "Left hand: %s" % _inv.table.name_of(off_number())

	if _off_class() == "shield":
		text += "   (hold B to block)"

	return text


func _show_model() -> void:
	var number: int = held_number() if _inv != null else 0

	if not _is_spear() and not _is_axe() and not _is_torch() and not _is_knife() and not _is_other_tool() and not _is_placeable() and not _is_look_item():
		number = 0

	if number == _shown_number:
		return

	_shown_number = number

	if _model != null:
		_model.queue_free()
		_model = null

	if number != 0:
		_model = _make_look_model() if _is_look_item() else _make_kit_model() if _is_placeable() else _make_spear_model() if _is_spear() else (_make_torch_model() if _is_torch() else (_make_knife_model() if _is_knife() else (_make_other_model() if _is_other_tool() else _make_axe_model())))
		_mount_model()


# Put the model in the hand: its business end leads along the fingers (-Z of the mount) and the grip sits in the palm.
# Falls back to the old spot in front of the camera when there are no arms.
func _mount_model() -> void:
	_mounted = _arms != null
	var kind: String = "kit" if (_is_placeable() or _is_look_item()) else "spear" if _is_spear() else ("torch" if _is_torch() else ("knife" if _is_knife() else ("axe" if _is_axe() else "other")))

	if not _mounted:
		_camera.add_child(_model)
		_model.position = REST
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


# The left-hand item: a torch (with its light) or a shield, mounted on the left hand; B raises a shield.
func _show_off_model(delta: float) -> void:
	var number: int = off_number() if _inv != null else 0
	blocking = number != 0 and _off_class() == "shield" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_key_pressed(KEY_B)

	if number != _off_shown:
		_off_shown = number

		if _off_model != null:
			_off_model.queue_free()
			_off_model = null

		if number != 0:
			_off_model = _make_shield_model() if _off_class() == "shield" else _make_torch_model(off_id())
			_mount_off_model()

	if _off_model == null:
		return

	var flicker: OmniLight3D = _off_model.get_node_or_null("Light")

	if flicker != null:
		flicker.visible = not held_light_budget.is_valid() or held_light_budget.call() or not _inv.fire_light_near(_camera.global_position, 8.0)
		flicker.light_energy = 1.4 + 0.3 * sin(float(Time.get_ticks_msec()) * 0.017)

	if _off_class() == "shield":
		var lift: float = 1.0 if blocking else 0.0
		_off_model.position = _off_model.position.lerp(_off_rest + Vector3(0.0, 0.0, -0.18 * lift), clampf(delta * 16.0, 0.0, 1.0))


var _off_rest: Vector3 = Vector3.ZERO


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

	if not _first_person and _avatar_rig != null:
		var stand: Basis = Basis.IDENTITY if shield else Basis(Vector3.RIGHT, deg_to_rad(60.0))
		_off_model.basis = stand
		_off_rest = stand * Vector3(0.0, grip, 0.0)
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

	if shape == "arrow":
		node.set_meta("held_pitch_deg", 30.0)
		node.set_meta("grip_y", 0.1)   # an arrow is held about its middle, so the head and the shaft show in the view

	return node


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
	var torch: Node3D = Node3D.new()
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.3, 0.17)
	wood.emission_enabled = true
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
	wrap_material.emission_enabled = true   # a trace of warm light of its own so the head is brown, not black, in the dark (and not orange at noon)
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
	char_material.emission_enabled = true
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
