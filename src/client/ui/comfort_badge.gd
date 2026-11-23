extends Control
# The comfort meter on the HUD (Dave 23 Nov 2026; protocol 164): one small borderless symbol with its number, down low in the row left of the
# hotbar, the same height as the hotbar (Dave: "keep all the hud down low and mostly minimalist", "no borders, just the symbols in a row").
# A flame that warms from grey to amber with the level, the whole level 0 to 10 beside it, and a small arrow while it rises or falls.
# Hover (cursor free) for the server's list of what counts and what is missing. View only: the server owns the meter. The status strip
# beside the hotbar may take this control into its own row (inventory_view.gd comfort_badge).

const ArtKit := preload("res://src/client/ui/art_kit.gd")
const SIZE := Vector2(76.0, 76.0)
const GAP := 12.0
const COLD := Color(0.55, 0.55, 0.55, 0.9)
const WARM := Color(1.0, 0.66, 0.25, 1.0)

var tenths: int = 0      # the meter, 0..100 (10 = full)
var target: int = 0      # the level it heads for
var trend: int = 0       # -1 falling, 0 steady, 1 rising
var _shown: float = 0.0  # eased toward tenths so the symbol changes gradually


func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	position = Vector2(ArtKit.HOTBAR_TRAY.position.x - GAP - SIZE.x, ArtKit.HOTBAR_STRIP.position.y)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func set_meter(new_tenths: int, new_target: int, new_trend: int, tip: String) -> void:
	tenths = clampi(new_tenths, 0, 100)
	target = new_target
	trend = new_trend

	if tip != "":
		tooltip_text = tip

	set_process(true)
	queue_redraw()


static func level_of(meter_tenths: int) -> int:
	return clampi(int(floor(float(meter_tenths) / 10.0)), 0, 10)


func _process(delta: float) -> void:
	_shown = move_toward(_shown, float(tenths), delta * 20.0)
	queue_redraw()

	if is_equal_approx(_shown, float(tenths)):
		set_process(false)


func _draw() -> void:
	var share: float = clampf(_shown / 100.0, 0.0, 1.0)
	var colour: Color = COLD.lerp(WARM, share)
	# The flame: a teardrop of points, its tip up, in the left half.
	var c: Vector2 = Vector2(20.0, 46.0)
	var pts: PackedVector2Array = PackedVector2Array()

	for i in 24:
		var a: float = TAU * float(i) / 24.0
		var r: float = 14.0
		var p: Vector2 = Vector2(sin(a) * r, cos(a) * r)

		if p.y < 0.0:
			p = Vector2(p.x * (1.0 + p.y / r * 0.85), p.y * 2.0)   # narrow and stretch the top into a tip

		pts.append(c + p)

	draw_colored_polygon(pts, colour)
	draw_circle(c + Vector2(0.0, 5.0), 5.0, colour.lightened(0.45))
	var font: Font = get_theme_default_font()
	var text: String = str(level_of(tenths))
	draw_string_outline(font, Vector2(38.0, 58.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, 6, Color(0.0, 0.0, 0.0, 0.85))
	draw_string(font, Vector2(38.0, 58.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, colour.lightened(0.2))

	if trend != 0:   # a small arrow over the number: green rising, red falling
		var up: bool = trend > 0
		var tri: PackedVector2Array = PackedVector2Array([Vector2(46.0, 24.0 if up else 16.0), Vector2(58.0, 24.0 if up else 16.0), Vector2(52.0, 14.0 if up else 26.0)])
		draw_colored_polygon(tri, Color(0.6, 0.9, 0.5) if up else Color(0.95, 0.55, 0.45))
