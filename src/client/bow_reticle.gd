extends Control

# The bow's cross (Dave 10 Nov 2026: "a cross reticle in the middle of the screen showing where you are aiming"): drawn while the bow is up, at the
# screen point the aim goes through (held_item.gd sets `point`: the middle of the screen, moved by the sway and the pull toward a vital zone).
# A thin light cross with a dark edge so it reads on snow and on forest alike; a gap in the middle leaves the target clear.

var point: Vector2 = Vector2.ZERO:
	set(value):
		point = value
		queue_redraw()
var arm_px: float = 14.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _draw() -> void:
	var gap: float = arm_px * 0.3
	var at: Vector2 = point - global_position

	for line_width in [3.0, 1.0]:
		var color: Color = Color(0.0, 0.0, 0.0, 0.55) if line_width > 2.0 else Color(1.0, 0.97, 0.88, 0.95)

		for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(at + axis * gap, at + axis * arm_px, color, line_width, true)
