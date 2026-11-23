extends Control

# The status strip (Dave 23 Nov 2026: "the space left of the hotbar level with the hotbar with icons the same height as the hotbar would work
# well for a status window ... thirst and hunger icons down there with a percentage in them, a hurt leg symbol, effects symbols"; "I don't want
# any borders around it I just want the symbols in a row"; "keep all the hud down low and mostly minimalist"). One row of symbols ending just
# left of the hotbar's tray, the same height as its slots, with no plate or frame: hunger and thirst always, with their percentage, and a symbol
# for every state that slows, weakens or otherwise changes the player while it lasts. Hovering one (with the cursor free, the inventory open)
# gives a plain line saying what it is and what it does; a symbol that appears says its name above itself for a few seconds.
#
# The words, the glyph and the order of every symbol are one row of data/ui/status_strip.json. The state behind it is one read Callable:
#
#   client.status_icons.add("limp", func() -> Dictionary: return {} if items.limp_share >= 1.0 else {"vars": {"n": 50}})
#
# read() returns {} while the symbol is hidden, else {"value": "73%" (drawn under the glyph, optional), "tone": 0 plain, 1 warning, 2 danger,
# "vars": the {words} its hover line fills in}. A row id "food_effect:1" uses the data row "food_effect". Reads are asked four times a second,
# never every frame, and a symbol is redrawn only when what it shows changes. The older add_icon(name, texture, active) still works (a picture
# with no words).

const ArtKit := preload("res://src/client/ui/art_kit.gd")
const SPEC_PATH := "res://data/ui/status_strip.json"
const CHECK_SEC := 0.25
const CELL := float(ArtKit.HOT)                                     # the hotbar's slot height (76 px on the 1920 x 1080 canvas)
const GAP := 6.0
const MIN_CELL := 52.0                                              # many symbols at once shrink to this, then wrap into a row above
const LEFT_PX := 24.0
const RIGHT_PX := ArtKit.HOTBAR_TRAY.position.x - 14.0              # ends 14 px short of the hotbar's leather tray
const GLYPH_SHARE := 0.68                                           # with a value, the glyph takes the top of the cell and the value the rest
const NOTE_S := 4.0
const QUIET_MSEC := 5000                                          # after the strip is made: the hello state arrives in this time
const TONES := [ArtKit.CREAM, Color("#F2B84B"), Color("#E85A45")]   # plain, warning, danger
const MAX_ICONS := 24

var spec: Dictionary = {}                 # data row id -> row
var _entries: Dictionary = {}             # id -> {"read": Callable, "texture": Texture2D, "cell": Control, "state": Dictionary, "opacity": float}
var _order: Array = []
var _since: float = 0.0
var _quiet_until_msec: int = 0            # no name notes until the join's first state has come in (the strip is made before it)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(LEFT_PX, ArtKit.HOTBAR_STRIP.position.y)
	size = Vector2(RIGHT_PX - LEFT_PX, CELL)
	spec = load_spec()
	_quiet_until_msec = Time.get_ticks_msec() + QUIET_MSEC


static func load_spec() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
	var out: Dictionary = {}

	if typeof(parsed) == TYPE_DICTIONARY:
		var rank: int = 0

		for row in parsed.get("symbols", []):
			if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) != "":
				var copy: Dictionary = (row as Dictionary).duplicate()
				copy["rank"] = rank
				out[str(row["id"])] = copy
				rank += 1

	return out


# The data row of a symbol id ("food_effect:1" -> "food_effect").
func row_of(id: String) -> Dictionary:
	return spec.get(id.get_slice(":", 0), {})


func add(id: String, read: Callable, texture: Texture2D = null, opacity: float = 1.0) -> void:
	if not _entries.has(id) and _entries.size() >= MAX_ICONS:
		push_warning("StatusIcons: %d symbols already; '%s' not added" % [MAX_ICONS, id])
		return

	if not _entries.has(id):
		var cell: Control = Control.new()
		cell.name = "Status_" + id.replace(":", "_")
		cell.mouse_filter = Control.MOUSE_FILTER_STOP     # for its hover line; with the cursor captured nothing reaches it
		cell.visible = false
		cell.draw.connect(func() -> void: _draw_cell(id))
		add_child(cell)
		_entries[id] = {"cell": cell, "state": {}}
		_order.append(id)
		_sort()

	var entry: Dictionary = _entries[id]
	entry["read"] = read
	entry["texture"] = texture
	entry["opacity"] = opacity


# A control that draws itself (the comfort meter, src/client/ui/comfort_badge.gd: its flame eases and has its own hover) taken into the row
# as the symbol `id`: the strip places and scales it like its own symbols; `read` says when it shows ({} hides it).
func add_control(id: String, control: Control, read: Callable) -> void:
	if _entries.has(id):
		remove(id)

	if control.get_parent() != null:
		control.get_parent().remove_child(control)

	control.visible = false
	add_child(control)
	_entries[id] = {"cell": control, "state": {}, "read": read, "hosted": true}
	_order.append(id)
	_sort()


# The first status row (owner, 2026-10-20): a picture shown while `active` says so. Kept for callers that have no words yet.
func add_icon(icon_name: String, texture: Texture2D, active: Callable, opacity: float = 0.85) -> void:
	add(icon_name, func() -> Dictionary: return {"tone": 0} if bool(active.call()) else {}, texture, opacity)


func _sort() -> void:
	_order.sort_custom(func(a: String, b: String) -> bool:
		var ra: int = int(row_of(a).get("rank", 999))
		var rb: int = int(row_of(b).get("rank", 999))
		return ra < rb if ra != rb else a < b)


func remove(id: String) -> void:
	if not _entries.has(id):
		return

	(_entries[id]["cell"] as Control).queue_free()
	_entries.erase(id)
	_order.erase(id)
	_layout()


# Asks every symbol whether it shows and what it says (a few times a second); `force` asks at once.
func tick(delta: float, force: bool = false) -> void:
	_since += delta

	if _since < CHECK_SEC and not force:
		return

	_since = 0.0
	var moved: bool = false

	for id in _order:
		var entry: Dictionary = _entries[id]
		var cell: Control = entry["cell"]
		var read: Callable = entry["read"]
		var state: Variant = read.call() if read.is_valid() else {}

		if typeof(state) != TYPE_DICTIONARY:
			state = {}

		var show_it: bool = not (state as Dictionary).is_empty()

		if show_it != cell.visible:
			cell.visible = show_it
			moved = true

			if show_it and Time.get_ticks_msec() >= _quiet_until_msec and not bool(row_of(id).get("always", false)):
				_note(id)

		if show_it and state != entry["state"]:
			entry["state"] = state

			if not bool(entry.get("hosted", false)):   # a hosted control keeps its own hover and drawing
				cell.tooltip_text = tip_of(id)
				cell.queue_redraw()
		elif not show_it:
			entry["state"] = {}

	if moved:
		_layout()


# The ids showing now, left to right.
func shown() -> Array:
	return _order.filter(func(id: String) -> bool: return (_entries[id]["cell"] as Control).visible)


func cell_of(id: String) -> Control:
	return _entries[id]["cell"] if _entries.has(id) else null


# The hover line: the data row's line for the tone (lines {"1": ..., "2": ...} over line), its {words} filled from the read's vars.
func tip_of(id: String) -> String:
	var row: Dictionary = row_of(id)
	var state: Dictionary = _entries[id]["state"] if _entries.has(id) else {}
	var tone: String = str(int(state.get("tone", 0)))
	var lines: Dictionary = row.get("lines", {})
	var text: String = str(lines.get(tone, lines.get("0", row.get("line", "")))) if typeof(lines) == TYPE_DICTIONARY else str(row.get("line", ""))
	var vars: Dictionary = state.get("vars", {})
	return text.format(vars) if not vars.is_empty() else text


# The shown symbols, right-aligned against the hotbar, the same height as its slots. More than fit at full size shrink together down to
# MIN_CELL; past that they wrap, the newest rows stacking above (the bottom row, next to the hotbar, keeps the last ones: hunger and thirst).
func _layout() -> void:
	var ids: Array = shown()
	var count: int = ids.size()

	if count == 0:
		return

	var width: float = size.x
	var cell_px: float = clampf((width - GAP * float(count - 1)) / float(count), MIN_CELL, CELL)
	var per_row: int = maxi(int(floor((width + GAP) / (cell_px + GAP))), 1)

	for i in range(count):
		var from_end: int = count - 1 - i                     # 0 = the last symbol, next to the hotbar
		var row: int = floori(float(from_end) / float(per_row))
		var col: int = from_end % per_row                     # columns counted leftward from the strip's right end
		var cell: Control = _entries[ids[i]]["cell"]
		cell.position = Vector2(width - float(col + 1) * cell_px - float(col) * GAP, (CELL - cell_px) - float(row) * (cell_px + GAP))

		if bool(_entries[ids[i]].get("hosted", false)):
			cell.scale = Vector2.ONE * (cell_px / maxf(cell.size.x, 1.0))   # it draws at its own size: scaled to the row's
		else:
			cell.size = Vector2(cell_px, cell_px)
			cell.queue_redraw()


func _draw_cell(id: String) -> void:
	var entry: Dictionary = _entries[id]
	var cell: Control = entry["cell"]
	var state: Dictionary = entry["state"]
	var row: Dictionary = row_of(id)
	var value: String = str(state.get("value", ""))
	var colour: Color = TONES[clampi(int(state.get("tone", 0)), 0, TONES.size() - 1)]
	colour.a *= float(entry.get("opacity", 1.0)) * float(row.get("opacity", 1.0))
	var s: float = cell.size.x
	var glyph_box: Rect2 = Rect2(Vector2(s * (1.0 - GLYPH_SHARE) * 0.5, 0.0), Vector2(s * GLYPH_SHARE, s * GLYPH_SHARE)) if value != "" else Rect2(Vector2(s * 0.08, s * 0.08), Vector2(s * 0.84, s * 0.84))
	var texture: Texture2D = entry.get("texture")

	if texture != null:
		cell.draw_texture_rect(texture, glyph_box, false, colour)
	else:
		draw_symbol(cell, str(row.get("glyph", "")), glyph_box, colour)

	if value != "":
		var font: Font = ArtKit.font("garamond_semibold")
		var px: int = maxi(int(round(s * 0.3)), 16)
		var base: Vector2 = Vector2(0.0, s - s * 0.06)
		cell.draw_string_outline(font, base, value, HORIZONTAL_ALIGNMENT_CENTER, s, px, 6, Color(0.0, 0.0, 0.0, 0.85 * colour.a))
		cell.draw_string(font, base, value, HORIZONTAL_ALIGNMENT_CENTER, s, px, colour)


# A glyph on the open world: a dark edge all round so it reads on snow and on night alike, then the glyph with its holes painted dark.
static func draw_symbol(ci: CanvasItem, glyph_name: String, rect: Rect2, colour: Color) -> void:
	var edge: Color = Color(ArtKit.OUTLINE.r, ArtKit.OUTLINE.g, ArtKit.OUTLINE.b, 0.8 * colour.a)
	var d: float = maxf(rect.size.x * 0.035, 1.5)

	for offset in [Vector2(-d, 0.0), Vector2(d, 0.0), Vector2(0.0, -d), Vector2(0.0, d)]:
		ArtKit.draw_glyph(ci, glyph_name, Rect2(rect.position + offset, rect.size), edge, edge, false)

	ArtKit.draw_glyph(ci, glyph_name, rect, colour, edge, false)


# The name above a symbol that has just appeared, fading after NOTE_S seconds (the injured leg nobody saw, Dave 23 Nov 2026).
func _note(id: String) -> void:
	for old in get_children():
		if old is Label and old.has_meta("for") and str(old.get_meta("for")) == id:
			old.queue_free()   # shown again quickly: one note, not two on top of each other

	var cell: Control = _entries[id]["cell"]
	var label: Label = Label.new()
	label.name = "StatusNote"
	label.set_meta("for", id)
	label.text = str(row_of(id).get("name", id))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", ArtKit.CREAM)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	add_child(label)
	label.reset_size()
	# Over its symbol once the row has settled, and kept on the canvas.
	var place: Callable = func() -> void:
		if is_instance_valid(label) and is_instance_valid(cell):
			label.position = Vector2(clampf(cell.position.x + cell.size.x * 0.5 - label.size.x * 0.5, -position.x, RIGHT_PX - LEFT_PX - label.size.x), cell.position.y - label.size.y - 4.0)
	place.call_deferred()
	var fade: Tween = label.create_tween()
	fade.tween_interval(NOTE_S)
	fade.tween_property(label, "modulate:a", 0.0, 0.8)
	fade.tween_callback(label.queue_free)
