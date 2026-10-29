extends Control
# A slide switch for the Esc menu (Dave 2026-10-23): the knob slides right and the track turns green for On, slides left and turns red
# for Off. Click it anywhere to flip. `toggled(on)` fires only for a click; set_on() moves it without the signal.

signal toggled(on: bool)

const GREEN := Color(0.2, 0.62, 0.28)
const RED := Color(0.7, 0.2, 0.2)

var on: bool = false
var _t: float = 0.0:
	set(value):
		_t = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(96.0, 44.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_on(value: bool) -> void:
	if value == on and is_equal_approx(_t, 1.0 if on else 0.0):
		return

	on = value

	if is_inside_tree() and is_visible_in_tree():
		create_tween().tween_property(self, "_t", 1.0 if on else 0.0, 0.12)
	else:
		_t = 1.0 if on else 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_on(not on)
		toggled.emit(on)
		accept_event()


func _draw() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, size)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = RED.lerp(GREEN, _t)
	style.set_corner_radius_all(int(size.y * 0.5))
	draw_style_box(style, box)
	var radius: float = size.y * 0.5 - 5.0
	var x: float = lerpf(radius + 5.0, size.x - radius - 5.0, _t)
	draw_circle(Vector2(x, size.y * 0.5), radius, Color(0.96, 0.96, 0.96))
