extends Control

# Temporary admin compass (owner, 2026-10-19): a strip along the top of the screen that
# scrolls as the player turns, with N, NE, E, SE, S, SW, W, NW and a tick every 10 degrees.
# North is -z, east is +x (world_sketch.gd). Set `heading` (degrees, 0 north, 90 east).

const SPAN_DEG := 180.0          # degrees shown across the strip
const WIDTH := 900.0
const HEIGHT := 64.0
const FONT_SIZE := 32            # owner (2026-10-19): 32 pt, centered at the top
const NAMES := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}

var heading: float = 0.0:
	set(value):
		heading = fposmod(value, 360.0)
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# Kept centered at the top of the window every frame, whatever the window size.
func _process(_delta: float) -> void:
	position = Vector2((get_viewport_rect().size.x - WIDTH) * 0.5, 6.0)


# The heading a camera looks along (degrees, 0 north, 90 east).
static func heading_of(camera: Node3D) -> float:
	var forward: Vector3 = -camera.global_transform.basis.z
	return fposmod(rad_to_deg(atan2(forward.x, -forward.z)), 360.0)


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var px_per_deg: float = WIDTH / SPAN_DEG
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.35))
	var first: int = int(floor((heading - SPAN_DEG * 0.5) / 10.0)) * 10

	for mark in range(first, int(heading + SPAN_DEG * 0.5) + 10, 10):
		var x: float = WIDTH * 0.5 + (float(mark) - heading) * px_per_deg

		if x < 0.0 or x > WIDTH:
			continue

		var deg: int = posmod(mark, 360)
		var named: bool = NAMES.has(deg)
		var tall: float = 18.0 if named else (12.0 if deg % 30 == 0 else 7.0)
		draw_line(Vector2(x, HEIGHT - tall), Vector2(x, HEIGHT), Color(1, 1, 1, 0.9), 2.0 if named else 1.0)
		var text: String = NAMES[deg] if named else (str(deg) if deg % 30 == 0 else "")

		if text != "":
			var font_size: int = FONT_SIZE if named else FONT_SIZE - 12
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var color: Color = Color(1.0, 0.85, 0.3) if deg == 0 else Color(1, 1, 1, 0.95 if named else 0.7)
			draw_string(font, Vector2(x - width * 0.5, 34.0 if named else 28.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	# The pointer: where the player is looking, with the exact heading.
	draw_line(Vector2(WIDTH * 0.5, 0.0), Vector2(WIDTH * 0.5, HEIGHT), Color(1.0, 0.3, 0.2), 2.0)
	var readout: String = "%03d" % (int(round(heading)) % 360)
	var readout_w: float = font.get_string_size(readout, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, Vector2(WIDTH * 0.5 - readout_w * 0.5, HEIGHT + 32.0), readout, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1.0, 0.45, 0.35))
