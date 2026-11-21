extends RefCounted

# The admin spyglass (Dave 9 Nov 2026: "for now I need an admin spyglass so I can watch animals from distance"; design
# docs/design/spyglass_design.md). Ctrl+Shift+L looks through it: the field of view narrows by the zoom, the mouse slows by the same factor,
# the wheel zooms 2x to 40x, and the animal nearest the centre dot is watched: the server keeps it living past the freeze line and
# sends its name, level, health and doings (animal_info, protocol 102), drawn under the dot. The server sends animals out to
# despawn_m while an admin looks; a player who is not an admin is refused (animal_info id -1) and the view closes.
# This file is the arithmetic and the overlay; terrain_client.gd sets the field of view and sends ACT_SPYGLASS.
# The player spyglass (tier 1 from 10 Nov 2026, data/items/spyglass.json): held in hand, right mouse held looks through the same view with the
# tier's zoom range, a fixed near blur and no readout (tier 3 will have one); the server checks the item and sends animals out to the tier's radius.

const MIN_ZOOM := 2.0
const MAX_ZOOM := 40.0
const START_ZOOM := 4.0
const ZOOM_STEP := 1.25          # each wheel notch multiplies or divides the zoom
const PICK_DEG := 3.0            # an animal within PICK_DEG / zoom degrees of the centre is watched
const MAX_M := 320.0             # farther than the server ever sends (despawn_m 300 and a margin)
const TIERS_PATH := "res://data/items/spyglass.json"

# Wire animal states (server_animals.gd, server_wolves.gd, server_big_game.gd, server_thieves.gd) as words for the readout.
const STATE_WORDS := {0: "grazing", 1: "moving", 2: "fleeing", 3: "alert", 6: "stalking", 7: "attacking", 8: "rolling in the grass", 9: "playing",
	10: "warning", 11: "charging", 12: "recovering", 13: "sneaking", 14: "running off with food", 15: "flying", 16: "warning", 20: "standing out the rain",
	21: "drinking"}

var active: bool = false
var zoom: float = START_ZOOM
var watched: int = 0              # the animal id nearest the centre (0 none)
var info: Dictionary = {}         # the server's last animal_info for `watched`
var tier: int = 0                 # 0 the admin spyglass (Ctrl+Shift+L), else the tier of the held spyglass item
var tier_cfg: Dictionary = {}     # spyglass.json tiers[tier] while an item is looked through
var zoom_min: float = MIN_ZOOM
var zoom_max: float = MAX_ZOOM


# The numbers of a spyglass item's tier (data/items/spyglass.json), {} for an unknown tier.
static func tier_config(item_tier: int) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TIERS_PATH)) if FileAccess.file_exists(TIERS_PATH) else null
	return (parsed.get("tiers", {}) as Dictionary).get(str(item_tier), {}) if typeof(parsed) == TYPE_DICTIONARY else {}


# Up to the eye through a held spyglass item of `item_tier` (cfg: its tier_config), or down. The admin glass is toggle() below.
func look_item(on: bool, item_tier: int, cfg: Dictionary) -> void:
	active = on
	watched = 0
	info = {}
	tier = item_tier if on else 0
	tier_cfg = cfg if on else {}
	var range_x: Array = cfg.get("zoom", [START_ZOOM, START_ZOOM]) if on else [MIN_ZOOM, MAX_ZOOM]
	zoom_min = float(range_x[0])
	zoom_max = float(range_x[range_x.size() - 1])
	zoom = zoom_min if on else START_ZOOM


# Whether the watched animal's readout is shown (the admin glass, or a tier with "readout").
func has_readout() -> bool:
	return tier == 0 or bool(tier_cfg.get("readout", false))


# Whether the wheel zooms (the admin glass, or a tier with a zoom range).
func can_zoom() -> bool:
	return zoom_max > zoom_min + 0.001


# Ctrl+Shift+L: into the spyglass or back out. Returns whether it is on.
func toggle() -> bool:
	active = not active
	watched = 0
	info = {}
	tier = 0
	tier_cfg = {}
	zoom_min = MIN_ZOOM
	zoom_max = MAX_ZOOM

	if active:
		zoom = START_ZOOM

	return active


# One wheel notch: out (true, less zoom) or in.
func wheel(out: bool) -> void:
	zoom = clampf(zoom / ZOOM_STEP if out else zoom * ZOOM_STEP, zoom_min, zoom_max)


# The field of view (degrees) through the glass for a normal view of `base_deg`.
func fov(base_deg: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(base_deg) * 0.5) / zoom))


# The mouse turns the view this much slower, so a target stays as easy to follow at any zoom.
func mouse_scale() -> float:
	return 1.0 / zoom


# The animal nearest the line of sight: `bodies` is [[id, position], ...]; 0 when none is within PICK_DEG / zoom degrees and MAX_M.
func pick(eye: Vector3, forward: Vector3, bodies: Array) -> int:
	var best: int = 0
	var best_cos: float = cos(deg_to_rad(PICK_DEG / zoom))
	var ahead: Vector3 = forward.normalized()

	for row in bodies:
		var to: Vector3 = (row[1] as Vector3) + Vector3(0.0, 0.6, 0.0) - eye   # aim at the body, not the feet
		var d: float = to.length()

		if d < 1.0 or d > MAX_M:
			continue

		var c: float = ahead.dot(to / d)

		if c > best_cos:
			best_cos = c
			best = int(row[0])

	return best


# The readout lines for the watched animal (empty when nothing is watched or nothing has come yet).
static func readout(data: Dictionary, distance_m: float) -> String:
	if data.is_empty():
		return ""

	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s%s" % [str(data.get("name", "?")), " (young)" if bool(data.get("young", false)) else ""])

	if data.has("level"):
		lines.append("Level %d" % int(data["level"]))

	lines.append("Health %d / %d" % [roundi(float(data.get("hp", 0.0))), roundi(float(data.get("hp_max", 0.0)))])
	lines.append(str(STATE_WORDS.get(int(data.get("state", 0)), "state %d" % int(data.get("state", 0)))))

	if str(data.get("temper", "")) != "":
		lines.append("Temperament: %s" % str(data["temper"]))

	if int(data.get("group", 0)) != 0:
		lines.append("%s %d" % ["Pack" if bool(data.get("pack", false)) else "Herd", int(data["group"])])

	lines.append("%d m" % roundi(distance_m))
	return "\n".join(lines)


# The overlay: a dark round vignette, a centre dot and the readout under it. Added to a CanvasLayer, hidden while the glass is down.
class Overlay extends Control:
	var text: String = ""

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.46
		var dark: Color = Color(0.0, 0.0, 0.0, 0.92)
		var ring: PackedVector2Array = PackedVector2Array()
		var steps: int = 64

		# Everything outside the circle is dark: the ring between the circle and a circle round the whole screen.
		var outer: float = size.length()

		for k in steps + 1:
			var ang: float = TAU * float(k) / float(steps)
			ring.append(centre + Vector2(cos(ang), sin(ang)) * radius)

		for k in range(steps, -1, -1):
			var ang: float = TAU * float(k) / float(steps)
			ring.append(centre + Vector2(cos(ang), sin(ang)) * outer)

		draw_colored_polygon(ring, dark)
		draw_arc(centre, radius, 0.0, TAU, steps, Color(0.05, 0.04, 0.03, 1.0), 6.0)
		draw_circle(centre, 2.5, Color(1.0, 0.25, 0.2, 0.9))

		if text != "":
			var font: Font = get_theme_default_font()
			var y: float = centre.y + 28.0

			for line in text.split("\n"):
				var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
				draw_string_outline(font, Vector2(centre.x - w * 0.5, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0.0, 0.0, 0.0, 0.85))
				draw_string(font, Vector2(centre.x - w * 0.5, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.97, 0.88))
				y += 22.0
