extends Control

# One inventory slot as it looks and answers to the hand (docs/design/INVENTORY_CRAFTING_LOOK.md section 5; Kathleen 8 Nov 2026).
# The same slot serves the pack, a chest, a station and the hotbar strip. It only draws and reports: what a click or a drop does
# is the owner's (pack_grid, container_panel, the hotbar), which connects the signals and sets can_drop / on_drop.
#
#   slot.set_unit(u)                       u = text scale x window height / 1080 (inventory_view._px), so 64 px follows the text size
#   slot.set_item(icon, count)             null icon and count 0 is an empty slot
#   slot.set_wear(fraction)                1.0 whole: no bar; below that a 3 px bar, green -> amber -> red
#   slot.set_favourite(on)                 a gold wax seal, top-left (not on the hotbar)
#   slot.set_key_number(n)                 hotbar strip: its own key, small, top-left (-1 none)
#   slot.set_greyed(on)                    icon 70 % desaturated at 60 % opacity (a recipe ingredient you lack)
#   slot.flash_refused()                   a 150 ms heraldic-red flash for a drop that is refused
#   slot.flash_new()                       a gold shimmer fading over 2 s, the first time an item appears
#   slot.set_caption(text)                 the item's name, drawn small in the slot while it has no icon yet (icons come from tools/icon_bake.gd)
#   slot.set_marked(mode)                  0 plain, MARK_GOLD the held or selected slot (a bright gold edge), MARK_CREAM the off hand
#   slot.set_station_glow(on)              a golden glowing line round the well: the station you stand at can use it (Dave 10 Nov 2026;
#                                          colour and widths in data/ui/station_highlight.json)
# The top-right corner is kept free for a quality mark later (Morgan's call 6).
# Hover and keyboard focus look the same, so a controller later needs no new art. Each change eases in 80 ms; with
# Reduce motion (display_settings.reduce_motion) it is instant and the new-item shimmer is skipped.
# Sounds: the slot only emits cue(name). The owner plays it through slot_sounds once Dave has listened (flag off until then).

const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const DisplaySettings := preload("res://src/client/display_settings.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")

const SLOT_PX := 64.0            # at unit 1
const ICON_PX := 52.0            # the icon inside it (48 to 56)
const CORNER_PX := 4.0
const GLOW_PX := 6.0
const WEAR_PX := 3.0
const COUNT_PX := 15            # 24 px in a 100 px pack slot
const KEY_PX := 12
const SEAL_PX := 10.0
const EASE_S := 0.08
const REFUSED_S := 0.15
const NEW_S := 2.0
const HOVER_LIFT := 0.3          # the fill moves this far toward WOOD_LIT under the mouse
const DRAG_DIM := 0.5
const GREY_DESAT := 0.7
const GREY_ALPHA := 0.6
const CAPTION_PX := 12
const MARK_GOLD := 1
const MARK_CREAM := 2
const STATION_GLOW_PATH := "res://data/ui/station_highlight.json"

signal clicked(button: int, shift: bool)     # a single press: left, right (the owner opens the menu), middle
signal double_clicked                         # double-click: use
signal cue(sound: String)                     # "pick", "drop", "refused": the owner decides whether to play it
signal drag_started

var index: int = -1               # the owner's slot number
var unit: float = 1.0
var icon: Texture2D = null
var count: int = 0
var wear: float = 1.0
var favourite: bool = false
var key_number: int = -1
var greyed: bool = false
var caption: String = ""
var station_glow: bool = false
static var _glow_cfg: Dictionary = {}
var marked: int = 0
var dragging: bool = false        # this slot's item is being carried by the pointer
var can_drop: Callable            # (data: Variant) -> bool, set by the owner; unset means nothing drops here
var on_drop: Callable             # (data: Variant) -> void
var drag_data: Callable           # () -> Variant, set by the owner; unset or null means this slot cannot be dragged

var hover: float = 0.0            # 0 to 1, eased (read by the tests)
var refused: float = 0.0
var shimmer: float = 0.0

var _hovered: bool = false
var _focused: bool = false
var _pressed: bool = false
var _hover_tween: Tween
var _flash_tween: Tween
var _shimmer_tween: Tween
var _icon: TextureRect
var _over: Control

static var _grey_shader: Shader
static var _tip_theme: Theme


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	theme = tooltip_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)
	mouse_entered.connect(func() -> void: _set_hovered(true, _focused))
	mouse_exited.connect(func() -> void: _set_hovered(false, _focused))
	focus_entered.connect(func() -> void: _set_hovered(_hovered, true))
	focus_exited.connect(func() -> void: _set_hovered(_hovered, false))
	resized.connect(_lay_out)
	set_unit(1.0)


func set_unit(u: float) -> void:
	unit = maxf(u, 0.1)
	custom_minimum_size = Vector2(SLOT_PX, SLOT_PX) * unit
	_lay_out()


func set_item(texture: Texture2D, amount: int) -> void:
	icon = texture
	count = amount
	_icon.texture = texture
	_refresh()


func set_wear(fraction: float) -> void:
	wear = clampf(fraction, 0.0, 1.0)
	_refresh()


func set_favourite(on: bool) -> void:
	favourite = on
	_refresh()


func set_key_number(n: int) -> void:
	key_number = n
	_refresh()


func set_greyed(on: bool) -> void:
	greyed = on
	_refresh()


func set_caption(text: String) -> void:
	caption = text
	_over.queue_redraw()


func set_marked(mode: int) -> void:
	marked = mode
	queue_redraw()


func set_station_glow(on: bool) -> void:
	if on != station_glow:
		station_glow = on
		queue_redraw()


# data/ui/station_highlight.json, read once: colour, line_px, glow_px, glow_alpha.
static func glow_cfg() -> Dictionary:
	if _glow_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATION_GLOW_PATH)) if FileAccess.file_exists(STATION_GLOW_PATH) else null
		_glow_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
		_glow_cfg["_read"] = true

	return _glow_cfg


func set_dragging(on: bool) -> void:
	dragging = on
	_refresh()


func is_empty() -> bool:
	return icon == null and count == 0


# A refused drop: a short red flash and the dull knock.
func flash_refused() -> void:
	cue.emit("refused")

	if _flash_tween != null:
		_flash_tween.kill()

	if DisplaySettings.reduce_motion or not is_inside_tree():
		refused = 0.0
		queue_redraw()
		return

	refused = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_refused, 1.0, 0.0, REFUSED_S)


# The first time an item lands here: a gold shimmer that fades. Reduce motion skips it.
func flash_new() -> void:
	if _shimmer_tween != null:
		_shimmer_tween.kill()

	if DisplaySettings.reduce_motion or not is_inside_tree():
		shimmer = 0.0
		_over.queue_redraw()
		return

	shimmer = 1.0
	_shimmer_tween = create_tween()
	_shimmer_tween.tween_method(_set_shimmer, 1.0, 0.0, NEW_S)


# The key text for a key number: 1 to 9, then 0 for the tenth.
static func key_text(n: int) -> String:
	return "0" if n == 9 else str(n + 1)


# ---- input ----

func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton

	if press == null:
		if event.is_action_pressed("ui_accept"):
			clicked.emit(MOUSE_BUTTON_LEFT, Input.is_key_pressed(KEY_SHIFT))
			accept_event()
		return

	if press.button_index != MOUSE_BUTTON_LEFT and press.button_index != MOUSE_BUTTON_RIGHT and press.button_index != MOUSE_BUTTON_MIDDLE:
		return

	_pressed = press.pressed and press.button_index == MOUSE_BUTTON_LEFT
	queue_redraw()

	if not press.pressed:
		return

	if press.double_click and press.button_index == MOUSE_BUTTON_LEFT:
		double_clicked.emit()
	else:
		clicked.emit(press.button_index, press.shift_pressed)

	accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_data.is_valid() or is_empty():
		return null

	var data: Variant = drag_data.call()

	if data == null:
		return null

	_pressed = false
	set_dragging(true)
	cue.emit("pick")
	drag_started.emit()
	set_drag_preview(_make_preview())
	return data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return can_drop.is_valid() and bool(can_drop.call(data))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if on_drop.is_valid():
		on_drop.call(data)
		cue.emit("drop")


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and dragging:
		set_dragging(false)


# Item text shows on the art kit's card, not the engine's grey box (redesign section 6). The pack's wells have no tooltip:
# the info strip under the pack shows the slot under the pointer (4.1), so nothing covers the slots next to it.
func _make_custom_tooltip(for_text: String) -> Object:
	return ArtKit.card_from_text(for_text) if for_text != "" else null


# ---- drawing ----

func _draw() -> void:
	# The redesign's recessed well (art_kit.gd, brief rows 8 to 10): the selected or held slot has the gold rim and inner glow,
	# the slot under the pointer the warm glow round it; the off hand a cream rim; a refused drop flashes red; a press darkens it.
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	ArtKit.draw_well(self, r, marked == MARK_GOLD, hover > 0.5)

	if hover > 0.0 and hover <= 0.5:                 # the glow easing in or out
		draw_rect(r.grow(2.0), Color(ArtKit.HOVER_GLOW, ArtKit.HOVER_GLOW.a * hover), false, 2.0)

	if marked == MARK_CREAM:
		draw_rect(r.grow(-1.0), ArtKit.CREAM, false, 2.0)

	if station_glow:   # the golden line, with its glow fading inward over glow_px
		var cfg: Dictionary = glow_cfg()
		var gold: Color = Color.html(str(cfg.get("colour", "#ffc83a")))
		var line: float = float(cfg.get("line_px", 2.0)) * unit
		var glow: float = float(cfg.get("glow_px", 6.0)) * unit
		var steps: int = maxi(1, ceili(glow / maxf(line, 1.0)))

		for k in range(steps, 0, -1):
			var inset: float = line + glow * float(k) / float(steps)
			draw_rect(r.grow(-inset + line * 0.5), Color(gold, float(cfg.get("glow_alpha", 0.5)) * (1.0 - float(k) / float(steps + 1))), false, line)

		draw_rect(r.grow(-line * 0.5), gold, false, line)

	if _pressed:
		draw_rect(r, Color(0.0, 0.0, 0.0, 0.25))

	if refused > 0.0:
		draw_rect(r, Color(ArtKit.BAD, 0.45 * refused))
		draw_rect(r.grow(-1.0), Color(ArtKit.BAD, refused), false, 2.0)


# Above the icon: shimmer, wear bar, count, seal, key numbers.
func _draw_over() -> void:
	var s: Vector2 = _over.size

	if shimmer > 0.0:
		_over.draw_rect(Rect2(Vector2.ZERO, s), Color(DynastyTheme.GOLD_BRIGHT, 0.35 * shimmer))

	if is_empty():
		_draw_key(Vector2(3.0, 2.0) * unit, DynastyTheme.CREAM_DIM)
		return

	if wear < 1.0:
		var h: float = maxf(2.0, WEAR_PX * unit)
		var pad: float = 4.0 * unit
		_over.draw_rect(Rect2(pad, s.y - pad - h, s.x - pad * 2.0, h), ArtKit.OUTLINE)
		_over.draw_rect(Rect2(pad, s.y - pad - h, (s.x - pad * 2.0) * wear, h), ArtKit.wear_colour(wear))

	var cinzel: Font = DynastyTheme.heading_font()
	var garamond: Font = DynastyTheme.text_font()

	if icon == null and caption != "" and garamond != null:
		var cpx: int = maxi(8, roundi(CAPTION_PX * unit))
		var pad_x: float = 4.0 * unit
		var top: float = s.y * 0.5 - float(cpx) * 0.6
		_over.draw_multiline_string(garamond, Vector2(pad_x, top), caption, HORIZONTAL_ALIGNMENT_CENTER, s.x - pad_x * 2.0, cpx, 2, DynastyTheme.CREAM)

	if count > 1:
		# The stack count, bottom right: EB Garamond SemiBold (24 px in a 100 px slot) with a dark outline; up 4 px over a wear bar.
		var counts: Font = ArtKit.font("garamond_semibold")
		var px: int = maxi(10, roundi(COUNT_PX * unit))
		var text: String = str(count)
		var w: float = counts.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var at: Vector2 = Vector2(s.x - w - 5.0 * unit, s.y - (9.0 if wear < 1.0 else 5.0) * unit)
		_over.draw_string_outline(counts, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(2, roundi(2.0 * unit)), ArtKit.OUTLINE)
		_over.draw_string(counts, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ArtKit.CREAM)

	if key_number >= 0:
		_draw_key(Vector2(3.0, 2.0) * unit, DynastyTheme.CREAM_DIM)
	elif favourite:
		# A gold wax seal: a filled disc with a darker ring and a small bright mark.
		var c: Vector2 = Vector2(SEAL_PX * 0.5 + 3.0, SEAL_PX * 0.5 + 3.0) * unit
		var radius: float = SEAL_PX * 0.5 * unit
		_over.draw_circle(c, radius + maxf(1.0, unit), DynastyTheme.GOLD_DIM.darkened(0.3))
		_over.draw_circle(c, radius, DynastyTheme.GOLD)
		_over.draw_circle(c + Vector2(-0.25, -0.25) * radius, radius * 0.3, DynastyTheme.GOLD_BRIGHT)


func _draw_key(top_left: Vector2, colour: Color) -> void:
	var cinzel: Font = DynastyTheme.heading_font()

	if key_number < 0 or cinzel == null:
		return

	var kpx: int = maxi(8, roundi(KEY_PX * unit))
	var at: Vector2 = top_left + Vector2(0.0, cinzel.get_ascent(kpx))
	_over.draw_string_outline(cinzel, at, key_text(key_number), HORIZONTAL_ALIGNMENT_LEFT, -1, kpx, maxi(2, roundi(2.0 * unit)), Color(0.0, 0.0, 0.0, 0.85))
	_over.draw_string(cinzel, at, key_text(key_number), HORIZONTAL_ALIGNMENT_LEFT, -1, kpx, colour)


# ---- state ----

func _set_hovered(mouse: bool, focus: bool) -> void:
	_hovered = mouse
	_focused = focus
	var target: float = 1.0 if (mouse or focus) else 0.0

	if not mouse:
		_pressed = false

	if _hover_tween != null:
		_hover_tween.kill()

	if DisplaySettings.reduce_motion or not is_inside_tree():
		_set_hover(target)
		return

	_hover_tween = create_tween()
	_hover_tween.tween_method(_set_hover, hover, target, EASE_S * absf(target - hover))


func _set_hover(value: float) -> void:
	hover = value
	queue_redraw()


func _set_refused(value: float) -> void:
	refused = value
	queue_redraw()


func _set_shimmer(value: float) -> void:
	shimmer = value
	_over.queue_redraw()


func _refresh() -> void:
	_icon.modulate = Color(1.0, 1.0, 1.0, (GREY_ALPHA if greyed else 1.0) * (DRAG_DIM if dragging else 1.0))
	_icon.material = _grey_material() if greyed else null
	queue_redraw()
	_over.queue_redraw()


func _lay_out() -> void:
	var side: float = minf(size.x, size.y) if size.x > 0.0 else SLOT_PX * unit
	var icon_side: float = side * ICON_PX / SLOT_PX
	_icon.position = (size - Vector2(icon_side, icon_side)) * 0.5
	_icon.size = Vector2(icon_side, icon_side)
	_over.position = Vector2.ZERO
	_over.size = size


# The icon under the pointer while dragging: 90 % size, a soft drop shadow under it.
func _make_preview() -> Control:
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side: float = ICON_PX * unit * 0.9
	var shadow: TextureRect = TextureRect.new()
	shadow.texture = icon
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.45)
	shadow.size = Vector2(side, side)
	shadow.position = Vector2(-side * 0.5, -side * 0.5) + Vector2(3.0, 5.0) * unit
	holder.add_child(shadow)
	var picture: TextureRect = TextureRect.new()
	picture.texture = icon
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size = Vector2(side, side)
	picture.position = Vector2(-side * 0.5, -side * 0.5)
	holder.add_child(picture)
	return holder


# The engine puts a custom tooltip inside its own grey "TooltipPanel" box. An empty one here lets only the card show;
# every other theme item still comes from the window's theme above.
static func tooltip_theme() -> Theme:
	if _tip_theme == null:
		_tip_theme = Theme.new()
		_tip_theme.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())

	return _tip_theme


static func _grey_material() -> ShaderMaterial:
	if _grey_shader == null:
		_grey_shader = Shader.new()
		_grey_shader.code = "shader_type canvas_item;\nuniform float desat = %.2f;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tfloat g = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(mix(c.rgb, vec3(g), desat), c.a);\n}\n" % GREY_DESAT

	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _grey_shader
	return m
