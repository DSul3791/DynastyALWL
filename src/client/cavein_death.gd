extends Node
# The cave-in death sequence (Dave 2026-10-23, tech/CAVE_IN_DEATH_DESIGN.md): instead of an instant black screen the roof comes down in waves
# (shaking, rumble), the picture darkens and goes black, a grey skull and crossbones fades in, three lines show as subtitles, everything fades and
# the character comes back at the respawn point. Other deaths keep the simple screen. v1 uses placeholder subtitles (no voice, no stings yet) and a
# drawn skull; Kathleen's art and voice drop in by replacing the draw and sound calls. About 30 s in all; the player cannot move meanwhile and the
# client stops reporting its position (the server has already put the character at the respawn point).

const WAVES := [0.0, 1.4, 2.8, 4.2, 5.6]    # when a wave of rock comes down (seconds)
const DARKEN := Vector2(3.0, 12.0)          # the picture goes from clear to black between these times
const SKULL_IN := Vector2(12.0, 16.0)
const SKULL_OUT := Vector2(25.0, 28.0)
const COME_BACK_S := 28.0                   # the body is moved to the respawn point here, the black clears over CLEAR_S after
const CLEAR_S := 2.0
const LINES := [
	[16.0, 20.0, "I tried to warn you, but would you listen? Oh no..."],
	[20.5, 23.0, "Oh well, now you're dead."],
	[23.5, 26.5, "Better luck next time, eh?"],
]

var active: bool = false

var _client
var _spawn: Vector3 = Vector3.ZERO
var _t: float = 0.0
var _wave: int = 0
var _moved: bool = false
var _layer: CanvasLayer
var _black: ColorRect
var _skull: Control
var _text: Label


# `client` is the terrain client (body, quake_view, sound); `spawn_point` is where the character comes back.
func start(client, spawn_point: Vector3) -> void:
	if active:
		return

	_client = client
	_spawn = spawn_point
	_t = 0.0
	_wave = 0
	_moved = false
	active = true

	if _layer == null:
		_build()

	_layer.visible = true
	_black.color.a = 0.0
	_skull.modulate.a = 0.0
	_text.text = ""


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 95
	add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0, 0.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)
	_skull = Control.new()
	_skull.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skull.draw.connect(_draw_skull)
	_layer.add_child(_skull)
	_text = Label.new()
	_text.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_text.anchor_top = 0.82
	_text.anchor_bottom = 0.95
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override("font_size", 44)
	_text.add_theme_color_override("font_color", Color(0.86, 0.86, 0.86))
	_text.add_theme_color_override("font_outline_color", Color.BLACK)
	_text.add_theme_constant_override("outline_size", 10)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_text)


func _process(delta: float) -> void:
	if not active:
		return

	_t += delta

	# The roof comes down in waves: each one shakes the picture and rumbles (the quake view and sound of the shaking stage).
	while _wave < WAVES.size() and _t >= float(WAVES[_wave]):
		_wave += 1

		if _client != null and _client.quake_view != null:
			_client.quake_view.on_quake(4, 1.0)

		if _client != null and _client.sound != null and _client.sound.placed != null and _client.body != null:
			_client.sound.placed.quake(4, 1.0, _client.body.global_position)

	if _t > WAVES[WAVES.size() - 1] + 4.0 and _client != null and _client.quake_view != null:
		_client.quake_view.on_quake(0, 0.0)   # the shaking dies away; the rumble tail goes with the picture

	var dark: float = smoothstep(DARKEN.x, DARKEN.y, _t)

	if _t >= COME_BACK_S:
		dark = 1.0 - clampf((_t - COME_BACK_S) / CLEAR_S, 0.0, 1.0)

	_black.color.a = dark
	_skull.modulate.a = smoothstep(SKULL_IN.x, SKULL_IN.y, _t) * (1.0 - smoothstep(SKULL_OUT.x, SKULL_OUT.y, _t))
	_skull.queue_redraw()
	var line: String = ""

	for row in LINES:
		if _t >= float(row[0]) and _t < float(row[1]):
			line = str(row[2])

	_text.text = line
	_text.modulate.a = 1.0 - smoothstep(SKULL_OUT.x, SKULL_OUT.y, _t)

	if not _moved and _t >= COME_BACK_S:
		_moved = true

		if _client != null:
			_client.finish_cavein_death(_spawn)

	if _t >= COME_BACK_S + CLEAR_S:
		active = false
		_layer.visible = false


# A grey translucent skull and crossbones, about 75 percent of the screen height, centred. Drawn from simple shapes (placeholder art).
func _draw_skull() -> void:
	var size: Vector2 = _skull.size
	var centre: Vector2 = size * 0.5 + Vector2(0.0, -size.y * 0.02)
	var unit: float = size.y * 0.75 / 2.2
	var bone: Color = Color(0.62, 0.62, 0.64, 0.8)
	var dark: Color = Color(0.0, 0.0, 0.0, 0.9)

	for dir in [-1.0, 1.0]:
		var a: Vector2 = centre + Vector2(-0.95 * dir, 0.62) * unit
		var b: Vector2 = centre + Vector2(0.95 * dir, 1.0) * unit
		_skull.draw_line(a, b, bone, unit * 0.2, true)
		_skull.draw_circle(a + Vector2(-0.06 * dir, -0.08) * unit, unit * 0.14, bone)
		_skull.draw_circle(a + Vector2(0.06 * dir, 0.1) * unit, unit * 0.14, bone)
		_skull.draw_circle(b + Vector2(0.06 * dir, 0.08) * unit, unit * 0.14, bone)
		_skull.draw_circle(b + Vector2(-0.06 * dir, -0.1) * unit, unit * 0.14, bone)

	_skull.draw_circle(centre + Vector2(0.0, -0.18) * unit, unit * 0.78, bone)
	_skull.draw_rect(Rect2(centre + Vector2(-0.4, 0.2) * unit, Vector2(0.8, 0.55) * unit), bone)

	for side in [-1.0, 1.0]:
		_skull.draw_circle(centre + Vector2(0.3 * side, -0.12) * unit, unit * 0.22, dark)

	_skull.draw_colored_polygon(PackedVector2Array([centre + Vector2(0.0, 0.04) * unit, centre + Vector2(-0.1, 0.26) * unit, centre + Vector2(0.1, 0.26) * unit]), dark)

	for k in range(-2, 3):
		_skull.draw_line(centre + Vector2(0.14 * float(k), 0.5) * unit, centre + Vector2(0.14 * float(k), 0.75) * unit, dark, unit * 0.025)

	_skull.draw_line(centre + Vector2(-0.4, 0.5) * unit, centre + Vector2(0.4, 0.5) * unit, dark, unit * 0.025)
