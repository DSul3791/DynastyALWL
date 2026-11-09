extends RefCounted

# The art kit of the inventory redesign (docs/ui/inventory_crafting_redesign.md sections 4, 6 and 8; Kathleen, 9 Nov 2026), step 2.
# Every piece of the window and the hotbar strip is drawn here, at canvas px of the 1920 x 1080 design canvas.
# Each piece looks for its painted PNG in ART_DIR (the art brief's file name) and uses it when it is there; until then it draws
# a placeholder in code from the brief's colours and sizes, so the layout lands before the art and the art drops in with no code change.
# The draw_* functions take the CanvasItem whose _draw() is running; the stylebox_* functions are for Godot controls (buttons, fields).

const ART_DIR := "res://assets/ui/inventory/"
const FONT_DIR := "res://assets/ui/fonts/"

# ---- layout (section 4; canvas px) ----
const MARGIN := 24
const GUTTER := 22
const FRAME := 14                                   # the leather edge; the inside starts FRAME + 6 in
const INSET := 20
const SLOT := 100
const SLOT_GAP := 10
const PACK := Rect2(24, 24, 690, 908)
const YOU := Rect2(736, 24, 448, 908)
const CRAFT := Rect2(1206, 24, 690, 908)
const HOT := 76                                     # hotbar slot (section 9): one control, in the world and under the window
const HOT_GAP := 10
const HOT_KEYS := 10
const HOTBAR_STRIP := Rect2(535, 964, 850, 76)
const HOTBAR_TRAY := Rect2(519, 948, 882, 108)
const ICON_SHARE := 0.8                             # an icon fills 80 % of its slot (6.7)

# ---- colours (6.4) ----
const BACKDROP := Color("#17150F")
const FIELD := Color("#231A12")
const RAISED := Color("#302419")
const RAISED_LIT := Color("#402F1F")
const RAISED_PRESSED := Color("#261B12")
const RAISED_EDGE := Color("#523E29")
const RAISED_EDGE_LIT := Color("#6E5436")
const RAISED_RIM := Color("#140D08")
const WELL := Color("#120C08")
const WELL_LIP := Color("#463626")
const LEATHER := Color("#3A2315")
const LEATHER_LINE := Color("#160C06")
const LEATHER_LIGHT := Color("#604028")
const STITCH := Color("#B89A68")
const BRASS_HI := Color("#F0CF82")
const BRASS := Color("#C9A054")
const BRASS_LO := Color("#7A5826")
const BRASS_DARK := Color("#4A3416")
const BRASS_TOP := Color("#FFECB4")
const GOLD_LINE := Color("#8C6933")
const GOLD_BRIGHT := Color("#FFD67A")
const HOVER_GLOW := Color(1.0, 0.702, 0.302, 0.43)  # #FFB34D at 43 %
const CREAM := Color("#F5E6BD")
const HEADING := Color("#F2C76B")
const DIM := Color("#8A7E68")
const DISABLED := Color("#6A6050")
const ENGRAVED := Color("#C9A869")
const GHOST := Color("#4A3C2E")
const INK := Color("#2B1B0B")
const BAD := Color("#BF2E24")
const OUTLINE := Color("#0A0604")
const WEAR_GOOD := Color("#8FA35A")
const WEAR_WORN := Color("#C9A054")
const HATCH := Color("#3A2C1F")
const CRAFT_GLOW := Color(1.0, 0.784, 0.392, 0.35)  # #FFC864 at 35 %

# The six stats, named as the game names them (Dave, 9 Nov: "the actual traits are Exertion and Energy"), warm fills and engraved glyphs.
const STAT_ORDER: Array[String] = ["Health", "Exertion", "Energy", "Temperature", "Food", "Water"]
const STAT_FILL := {
	"Health": Color("#A8452F"), "Exertion": Color("#C08F3E"), "Energy": Color("#9C7B52"),
	"Temperature": Color("#C86F35"), "Food": Color("#A88A44"), "Water": Color("#6F8A86"),
}
const STAT_GLYPH := {
	"Health": "heart", "Exertion": "bolt", "Energy": "moon", "Temperature": "flame", "Food": "bread", "Water": "drop",
}

# Glyph name -> the art brief's PNG (rows 18 and 20 to 24). A glyph with a file there is drawn from it.
const GLYPH_FILE := {
	"heart": "stat_health", "bolt": "stat_exertion", "moon": "stat_energy", "flame": "stat_warmth", "bread": "stat_food", "drop": "stat_water",
	"helmet": "ghost_head", "tunic": "ghost_body", "trousers": "ghost_legs", "boot": "ghost_feet", "glove": "ghost_hands",
	"pack": "ghost_back", "hand_axe": "ghost_right", "shield": "ghost_left",
	"all": "tab_all", "axe": "tab_tools", "spear": "tab_weapons", "house": "tab_building", "anvil": "tab_stations", "fire": "tab_fire",
	"bowl": "tab_food", "leaf": "tab_medicine", "shirt": "tab_clothing", "chest": "tab_storage", "planks": "tab_materials",
	"workbench": "station_workbench", "forge": "station_forge", "campfire": "station_campfire", "campfire_pot": "station_campfire_pot",
	"clay_hearth": "station_clay_hearth", "oven": "station_oven", "saw_mill": "station_saw_mill",
	"woodworking_table": "station_woodworking_table", "mark_chest": "mark_chest", "search": "glyph_search", "sort": "glyph_sort",
}

# The empty gear slots, in the order of the You column (left: head, body, legs, feet; right: hands, back, right hand, left hand).
const GEAR_GHOST := {
	"head": "helmet", "body": "tunic", "legs": "trousers", "feet": "boot",
	"hands": "glove", "back": "pack", "right": "hand_axe", "left": "shield",
}

# The 10 recipe categories of recipes.json, plus All, in tab order, with their glyphs.
const TAB_GLYPH := {
	"All": "all", "Tools": "axe", "Weapons": "spear", "Shelter and building": "house", "Workshops and stations": "anvil",
	"Fire and cooking": "fire", "Food and drink": "bowl", "Medicine": "leaf", "Clothing": "shirt",
	"Containers and furniture": "chest", "Materials": "planks",
}

static var _art: Dictionary = {}
static var _fonts: Dictionary = {}


# ================================================================================================ files

# A painted piece from ART_DIR (file name without .png), or null while it is not painted yet.
static func art(file: String) -> Texture2D:
	if _art.has(file):
		return _art[file]

	var path: String = ART_DIR + file + ".png"
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_art[file] = texture
	return texture


# Forget what was looked up, so art added while the game runs (or by a test) is seen.
static func clear_cache() -> void:
	_art.clear()


# "cinzel", "cinzel_bold", "garamond" or "garamond_semibold".
static func font(which: String) -> Font:
	if _fonts.has(which):
		return _fonts[which]

	var file: String = {
		"cinzel": "Cinzel-Regular.ttf", "cinzel_bold": "Cinzel-Bold.ttf",
		"garamond": "EBGaramond-Regular.ttf", "garamond_semibold": "EBGaramond-SemiBold.ttf",
	}.get(which, "EBGaramond-Regular.ttf")
	var loaded: Font = load(FONT_DIR + file) as Font
	_fonts[which] = loaded
	return loaded


static func _nine(file: String, left: float, top: float, right: float, bottom: float) -> StyleBoxTexture:
	var texture: Texture2D = art(file)

	if texture == null:
		return null

	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = left
	box.texture_margin_top = top
	box.texture_margin_right = right
	box.texture_margin_bottom = bottom
	return box


# ================================================================================================ layout helpers

# The rect of slot `index` in a grid of `cols` columns of `size` with `gap` between, from `origin`.
static func grid_rect(origin: Vector2, cols: int, index: int, size: float, gap: float) -> Rect2:
	var col: int = index % cols
	var row: int = floori(float(index) / float(cols))
	return Rect2(origin + Vector2(col * (size + gap), row * (size + gap)), Vector2(size, size))


static func hotbar_slot(index: int) -> Rect2:
	return grid_rect(HOTBAR_STRIP.position, HOT_KEYS, index, HOT, HOT_GAP)


# The key shown on a hotbar slot: 1 to 9, then 0 (the key you press for the tenth).
static func hotbar_key_text(index: int) -> String:
	return str((index + 1) % 10)


static func wear_colour(share: float) -> Color:
	if share > 0.6:
		return WEAR_GOOD

	return WEAR_WORN if share > 0.3 else BAD


static func lighter(c: Color, by: float) -> Color:
	return Color(minf(1.0, c.r * (1.0 + by)), minf(1.0, c.g * (1.0 + by)), minf(1.0, c.b * (1.0 + by)), c.a)


static func darker(c: Color, by: float) -> Color:
	return Color(c.r * (1.0 - by), c.g * (1.0 - by), c.b * (1.0 - by), c.a)


# ================================================================================================ styleboxes for controls

# A recessed well (row 8, selected row 9) for fields and the quantity number.
static func stylebox_well(selected: bool = false) -> StyleBox:
	var painted: StyleBoxTexture = _nine("well_selected" if selected else "well", 10, 10, 10, 10)

	if painted != null:
		return painted

	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = WELL
	box.set_corner_radius_all(4)
	box.border_width_bottom = 1
	box.border_width_right = 1
	box.border_color = GOLD_BRIGHT if selected else WELL_LIP

	if selected:
		box.set_border_width_all(2)

	box.content_margin_left = 10
	box.content_margin_right = 10
	return box


# A raised plate (row 11): 0 normal, 1 lit (hover or selected), 2 pressed.
static func stylebox_raised(state: int = 0) -> StyleBox:
	var file: String = ["raised", "raised_lit", "raised_pressed"][clampi(state, 0, 2)]
	var painted: StyleBoxTexture = _nine(file, 10, 10, 10, 10)

	if painted != null:
		return painted

	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = [RAISED, RAISED_LIT, RAISED_PRESSED][clampi(state, 0, 2)]
	box.set_corner_radius_all(5)
	box.set_border_width_all(1)
	box.border_color = RAISED_RIM

	if state != 2:
		box.border_width_top = 1
		box.shadow_color = Color(0, 0, 0, 0.6)
		box.shadow_size = 3
		box.shadow_offset = Vector2(0, 3)

	box.content_margin_left = 12
	box.content_margin_right = 12
	return box


# The cast brass button (row 14).
static func stylebox_brass(pressed: bool = false) -> StyleBox:
	var painted: StyleBoxTexture = _nine("button_brass_pressed" if pressed else "button_brass", 16, 16, 16, 16)

	if painted != null:
		return painted

	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = darker(BRASS, 0.1) if pressed else BRASS
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	box.border_color = BRASS_DARK
	return box


# ================================================================================================ pieces

# The darkened world behind the window: the backdrop at 85 % (row 1), darker towards the edges.
static func draw_backdrop(ci: CanvasItem, rect: Rect2) -> void:
	var grain: Texture2D = art("backdrop_grain")

	if grain != null:
		ci.draw_texture_rect(grain, rect, true, Color(1, 1, 1, 0.85))
	else:
		ci.draw_rect(rect, Color(BACKDROP, 0.85))

	for i in 6:                                     # the vignette: six soft bands in from each edge
		var band: float = 18.0 + i * 18.0
		var shade: Color = Color(0, 0, 0, 0.06)
		ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, band)), shade)
		ci.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - band), Vector2(rect.size.x, band)), shade)
		ci.draw_rect(Rect2(rect.position, Vector2(band, rect.size.y)), shade)
		ci.draw_rect(Rect2(rect.position + Vector2(rect.size.x - band, 0), Vector2(band, rect.size.y)), shade)


# A soft shadow under a box: `steps` widening rounded boxes, each faint, offset `down`.
static func _soft_shadow(ci: CanvasItem, rect: Rect2, radius: float, blur: float, down: float, alpha: float) -> void:
	var steps: int = 4
	var box: StyleBoxFlat = StyleBoxFlat.new()

	for i in steps:
		var grow: float = blur * float(i + 1) / float(steps)
		box.bg_color = Color(0, 0, 0, alpha / float(steps))
		box.set_corner_radius_all(int(radius + grow))
		ci.draw_style_box(box, rect.grow(grow - blur * 0.5).grow_individual(0, -down, 0, down))


# One panel (rows 2 to 5): the shadow, the 14 px stitched leather edge, the parchment field with its gold line, the brass corners.
static func draw_panel(ci: CanvasItem, rect: Rect2) -> void:
	var shadow: StyleBoxTexture = _nine("panel_shadow", 32, 32, 32, 32)

	if shadow != null:
		ci.draw_style_box(shadow, rect.grow_individual(0, -8, 0, 8))
	else:
		_soft_shadow(ci, rect, 12, 14, 8, 0.75)

	var frame: StyleBoxTexture = _nine("frame_leather", 20, 20, 20, 20)

	if frame != null:
		ci.draw_style_box(frame, rect)
	else:
		var leather: StyleBoxFlat = StyleBoxFlat.new()
		leather.bg_color = LEATHER
		leather.set_corner_radius_all(12)
		leather.set_border_width_all(2)
		leather.border_color = LEATHER_LINE
		ci.draw_style_box(leather, rect)
		ci.draw_line(rect.position + Vector2(10, 2.5), rect.position + Vector2(rect.size.x - 10, 2.5), LEATHER_LIGHT, 1.0)
		_draw_stitches(ci, rect, 7.0, 24.0)

	var field: Rect2 = rect.grow(-FRAME)
	var parchment: Texture2D = art("field_parchment")

	if parchment != null:
		ci.draw_texture_rect(parchment, field, true)
	else:
		var flat: StyleBoxFlat = StyleBoxFlat.new()
		flat.bg_color = FIELD
		flat.set_corner_radius_all(5)
		ci.draw_style_box(flat, field)

	var line: StyleBoxFlat = StyleBoxFlat.new()
	line.draw_center = false
	line.set_border_width_all(1)
	line.border_color = Color(GOLD_LINE, 0.6)
	line.set_corner_radius_all(5)
	ci.draw_style_box(line, field)

	for i in 5:                                     # the 10 px shade under the top of the field
		ci.draw_rect(Rect2(field.position + Vector2(1, 1 + i * 2), Vector2(field.size.x - 2, 2)), Color(0, 0, 0, 0.1 * float(5 - i) / 5.0))

	draw_corner(ci, rect.position + Vector2(-4, -4), false, false)
	draw_corner(ci, rect.position + Vector2(rect.size.x - 42, -4), true, false)
	draw_corner(ci, rect.position + Vector2(-4, rect.size.y - 42), false, true)
	draw_corner(ci, rect.position + Vector2(rect.size.x - 42, rect.size.y - 42), true, true)


# A dashed stitch line `inset` px in from each edge, stopping `end_room` px short of the corners.
static func _draw_stitches(ci: CanvasItem, rect: Rect2, inset: float, end_room: float) -> void:
	var top: float = rect.position.y + inset
	var bottom: float = rect.end.y - inset
	var left: float = rect.position.x + inset
	var right: float = rect.end.x - inset
	var x: float = rect.position.x + end_room

	while x < rect.end.x - end_room:
		for y in [top, bottom]:
			ci.draw_line(Vector2(x, y + 1), Vector2(x + 5, y + 1), Color(0, 0, 0, 0.6), 1.5)
			ci.draw_line(Vector2(x, y), Vector2(x + 5, y), STITCH, 1.5)
		x += 9.0

	var y2: float = rect.position.y + end_room

	while y2 < rect.end.y - end_room:
		for sx in [left, right]:
			ci.draw_line(Vector2(sx + 1, y2), Vector2(sx + 1, y2 + 5), Color(0, 0, 0, 0.6), 1.5)
			ci.draw_line(Vector2(sx, y2), Vector2(sx, y2 + 5), STITCH, 1.5)
		y2 += 9.0


# A cast brass corner (row 5): 46 x 46, an L of two 15 px arms with a gusset and a rivet. `at` is its top left.
static func draw_corner(ci: CanvasItem, at: Vector2, flip_x: bool, flip_y: bool) -> void:
	var texture: Texture2D = art("corner_brass")
	var sx: float = -1.0 if flip_x else 1.0
	var sy: float = -1.0 if flip_y else 1.0
	var origin: Vector2 = at + Vector2(46.0 if flip_x else 0.0, 46.0 if flip_y else 0.0)

	if texture != null:
		ci.draw_set_transform(origin, 0.0, Vector2(sx, sy))
		ci.draw_texture_rect(texture, Rect2(0, 0, 46, 46), false)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var shape: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(37, 0), Vector2(46, 7.5), Vector2(37, 15), Vector2(30, 15), Vector2(15, 30),
		Vector2(15, 37), Vector2(7.5, 46), Vector2(0, 37),
	])
	var placed: PackedVector2Array = PackedVector2Array()
	var shadow: PackedVector2Array = PackedVector2Array()

	for p in shape:
		var q: Vector2 = origin + Vector2(p.x * sx, p.y * sy)
		placed.append(q)
		shadow.append(q + Vector2(1, 3))

	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	ci.draw_colored_polygon(placed, BRASS)
	var rim: PackedVector2Array = placed.duplicate()
	rim.append(placed[0])
	ci.draw_polyline(rim, BRASS_DARK, 1.0, true)
	ci.draw_line(placed[0] + Vector2(2 * sx, 1 * sy), placed[1] + Vector2(-2 * sx, 1 * sy), BRASS_HI, 1.0)
	ci.draw_line(placed[0] + Vector2(1 * sx, 2 * sy), placed[8] + Vector2(1 * sx, -2 * sy), BRASS_HI, 1.0)
	var rivet: Vector2 = origin + Vector2(8 * sx, 8 * sy)
	ci.draw_circle(rivet, 3.5, BRASS_DARK)
	ci.draw_circle(rivet + Vector2(-0.5, -0.5), 2.2, BRASS_HI)


# A brass title plate (row 6) with the title engraved. `room` caps the width: a long name steps down 34, 30, 26 px.
# x is the left edge, or the centre when `centred`. Returns the plate's rect.
static func draw_title_plate(ci: CanvasItem, x: float, y: float, text: String, centred: bool = false, room: float = 100000.0) -> Rect2:
	var cinzel: Font = font("cinzel_bold")
	var px: int = 34
	var tracking: float = 3.0

	for step in [[34, 3.0], [30, 2.0], [26, 2.0]]:
		px = step[0]
		tracking = step[1]
		if tracked_width(cinzel, text, px, tracking) + 60.0 <= room:
			break

	var w: float = tracked_width(cinzel, text, px, tracking) + 60.0
	var rect: Rect2 = Rect2(x - (w * 0.5 if centred else 0.0), y, w, 46)
	var painted: StyleBoxTexture = _nine("title_plate", 24, 0, 24, 0)

	_soft_shadow(ci, rect, 5, 4, 3, 0.65)

	if painted != null:
		ci.draw_style_box(painted, rect)
	else:
		ci.draw_style_box(stylebox_brass(), rect)
		ci.draw_line(rect.position + Vector2(4, 2), rect.position + Vector2(w - 4, 2), BRASS_HI, 1.0)
		ci.draw_line(rect.position + Vector2(4, 44), rect.position + Vector2(w - 4, 44), BRASS_LO, 1.0)

		for rx in [rect.position.x + 10, rect.end.x - 10]:
			ci.draw_circle(Vector2(rx, y + 23), 3.5, BRASS_DARK)
			ci.draw_circle(Vector2(rx - 0.5, y + 22.5), 2.2, BRASS_HI)

	var base: float = y + 23.0 + (cinzel.get_ascent(px) - cinzel.get_descent(px)) * 0.5
	draw_tracked(ci, cinzel, Vector2(rect.get_center().x, base + 1), text, px, tracking, Color(0.98, 0.886, 0.627, 0.6))
	draw_tracked(ci, cinzel, Vector2(rect.get_center().x, base), text, px, tracking, INK)
	return rect


# A section rule with the engraved diamond in the middle (row 7).
static func draw_rule(ci: CanvasItem, x0: float, x1: float, y: float) -> void:
	ci.draw_line(Vector2(x0, y), Vector2(x1, y), Color(GOLD_LINE, 0.67), 1.0)
	var cx: float = (x0 + x1) * 0.5
	var diamond: Texture2D = art("rule_ornament")

	if diamond != null:
		ci.draw_texture(diamond, Vector2(cx - 12, y - 6))
		return

	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx, y - 5), Vector2(cx + 6, y), Vector2(cx, y + 5), Vector2(cx - 6, y)]), GOLD_LINE)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx, y - 2.5), Vector2(cx + 3, y), Vector2(cx, y + 2.5), Vector2(cx - 3, y)]), FIELD)


# A recessed well (row 8): a slot, field or bar track. `selected` adds the gold rim and inner glow (row 9), `hover` the warm glow round it (row 10).
static func draw_well(ci: CanvasItem, rect: Rect2, selected: bool = false, hover: bool = false) -> void:
	if hover:
		var glow: StyleBoxTexture = _nine("slot_hover", 18, 18, 18, 18)

		if glow != null:
			ci.draw_style_box(glow, rect.grow(8))
		else:
			_soft_shadow_coloured(ci, rect.grow(4), 8, 5, HOVER_GLOW)

	var painted: StyleBoxTexture = _nine("well_selected" if selected else "well", 10, 10, 10, 10)

	if painted != null:
		ci.draw_style_box(painted, rect)
		return

	var flat: StyleBoxFlat = StyleBoxFlat.new()
	flat.bg_color = WELL
	flat.set_corner_radius_all(4)
	ci.draw_style_box(flat, rect)

	for i in 7:                                     # the top inner shadow, 7 px, 75 % to 0
		ci.draw_rect(Rect2(rect.position + Vector2(2, i), Vector2(rect.size.x - 4, 1)), Color(0, 0, 0, 0.75 * float(7 - i) / 7.0))

	for i in 4:                                     # the left inner shadow, 4 px, 50 % to 0
		ci.draw_rect(Rect2(rect.position + Vector2(i, 2), Vector2(1, rect.size.y - 4)), Color(0, 0, 0, 0.5 * float(4 - i) / 4.0))

	ci.draw_line(Vector2(rect.position.x + 4, rect.end.y - 0.5), Vector2(rect.end.x - 4, rect.end.y - 0.5), WELL_LIP, 1.0)
	ci.draw_line(Vector2(rect.end.x - 0.5, rect.position.y + 4), Vector2(rect.end.x - 0.5, rect.end.y - 4), Color(WELL_LIP, 0.43), 1.0)

	if selected or hover:
		for i in 8:                                 # the inner glow, 55 % at the rim to 0 at 8 px in
			var ring: StyleBoxFlat = StyleBoxFlat.new()
			ring.draw_center = false
			ring.set_border_width_all(1)
			ring.border_color = Color(GOLD_BRIGHT, 0.55 * float(8 - i) / 8.0)
			ring.set_corner_radius_all(maxi(0, 4 - i))
			ci.draw_style_box(ring, rect.grow(-float(i)))

		var rim: StyleBoxFlat = StyleBoxFlat.new()
		rim.draw_center = false
		rim.set_border_width_all(2)
		rim.border_color = GOLD_BRIGHT
		rim.set_corner_radius_all(4)
		ci.draw_style_box(rim, rect)


static func _soft_shadow_coloured(ci: CanvasItem, rect: Rect2, radius: float, blur: float, colour: Color) -> void:
	var steps: int = 4
	var box: StyleBoxFlat = StyleBoxFlat.new()

	for i in steps:
		var grow: float = blur * float(i) / float(steps)
		box.bg_color = Color(colour, colour.a / float(steps))
		box.set_corner_radius_all(int(radius + grow))
		ci.draw_style_box(box, rect.grow(grow))


# A raised plate (row 11) with its shadow (row 12): buttons, tabs, the recipe card, the selected row.
static func draw_raised(ci: CanvasItem, rect: Rect2, lit: bool = false, shadow: bool = true) -> void:
	if shadow:
		var painted_shadow: StyleBoxTexture = _nine("raised_shadow", 16, 16, 16, 16)

		if painted_shadow != null:
			ci.draw_style_box(painted_shadow, rect.grow_individual(0, -3, 0, 3))
		else:
			_soft_shadow(ci, rect, 5, 6, 3, 0.6)

	var painted: StyleBoxTexture = _nine("raised_lit" if lit else "raised", 10, 10, 10, 10)

	if painted != null:
		ci.draw_style_box(painted, rect)
		return

	var base: Color = RAISED_LIT if lit else RAISED
	var flat: StyleBoxFlat = StyleBoxFlat.new()
	flat.bg_color = base
	flat.set_corner_radius_all(5)
	flat.set_border_width_all(1)
	flat.border_color = RAISED_RIM
	ci.draw_style_box(flat, rect)
	ci.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, rect.size.y * 0.5 - 1)), Color(1, 1, 1, 0.03))
	ci.draw_line(rect.position + Vector2(5, 1), rect.position + Vector2(rect.size.x - 5, 1), RAISED_EDGE_LIT if lit else RAISED_EDGE, 1.0)


# A keycap (row 17) at `at` (top left), 26 tall. Digits use EB Garamond SemiBold, because Cinzel's 1 reads as I. Returns its width.
static func draw_keycap(ci: CanvasItem, at: Vector2, key: String) -> float:
	var digits: bool = key.length() > 0 and key.substr(0, 1).to_upper() == key.substr(0, 1).to_lower()
	var face: Font = font("garamond_semibold" if digits else "cinzel_bold")
	var w: float = maxf(26.0, face.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 14.0)
	var rect: Rect2 = Rect2(at, Vector2(w, 26))
	draw_raised(ci, rect, false, false)
	ci.draw_line(at + Vector2(3, 26.5), at + Vector2(w - 3, 26.5), OUTLINE, 1.5)
	var base: float = at.y + 13.0 + (face.get_ascent(18) - face.get_descent(18)) * 0.5
	ci.draw_string(face, Vector2(at.x, base), key, HORIZONTAL_ALIGNMENT_CENTER, w, 18, HEADING)
	return w


# A stat or weight bar (row 19): a well track and a warm fill, lighter at the top, with a faint highlight.
static func draw_bar(ci: CanvasItem, rect: Rect2, share: float, fill: Color) -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = WELL
	track.set_corner_radius_all(int(rect.size.y * 0.5))
	ci.draw_style_box(track, rect)
	ci.draw_line(Vector2(rect.position.x + 3, rect.end.y), Vector2(rect.end.x - 3, rect.end.y), Color(WELL_LIP, 0.55), 1.0)
	var width: float = rect.size.x * clampf(share, 0.0, 1.0)

	if width < 4.0:
		return

	var filled: Rect2 = Rect2(rect.position, Vector2(width, rect.size.y))
	var painted: StyleBoxTexture = _nine("bar_fill", 5, 5, 5, 5)

	if painted != null:
		painted.modulate_color = fill
		ci.draw_style_box(painted, filled)
		return

	var lower: StyleBoxFlat = StyleBoxFlat.new()
	lower.bg_color = darker(fill, 0.2)
	lower.set_corner_radius_all(int(rect.size.y * 0.5))
	ci.draw_style_box(lower, filled)
	var upper: StyleBoxFlat = StyleBoxFlat.new()
	upper.bg_color = lighter(fill, 0.25)
	upper.set_corner_radius_all(int(rect.size.y * 0.5))
	upper.corner_radius_bottom_left = 0
	upper.corner_radius_bottom_right = 0
	ci.draw_style_box(upper, Rect2(filled.position, Vector2(width, rect.size.y * 0.5)))
	ci.draw_line(rect.position + Vector2(3, 1.5), rect.position + Vector2(width - 3, 1.5), Color(1.0, 0.94, 0.82, 0.27), 1.0)


# A durability bar (row 26) along the bottom of a slot: 4 px tall, 7 px in from each side, 6 to 10 px above the bottom.
static func draw_wear(ci: CanvasItem, slot: Rect2, share: float) -> void:
	var track: Rect2 = Rect2(slot.position.x + 7, slot.end.y - 10, slot.size.x - 14, 4)
	ci.draw_rect(track, OUTLINE)
	ci.draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(share, 0.0, 1.0), 4)), wear_colour(share))


# An item icon at 80 % of its slot with a 2 px soft shadow (6.7), or the missing-icon tile (row 27) when there is none.
static func draw_icon(ci: CanvasItem, icon: Texture2D, slot: Rect2, alpha: float = 1.0) -> void:
	var side: float = slot.size.x * ICON_SHARE
	var rect: Rect2 = Rect2(slot.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))

	if icon == null:
		draw_missing(ci, rect)
		return

	ci.draw_texture_rect(icon, Rect2(rect.position + Vector2(0, 2), rect.size), false, Color(0, 0, 0, 0.45 * alpha))
	ci.draw_texture_rect(icon, rect, false, Color(1, 1, 1, alpha))


# The missing-icon tile (row 27): hatching every 10 px, a dashed gold rim 6 px in, a "?" in Cinzel Bold.
static func draw_missing(ci: CanvasItem, rect: Rect2) -> void:
	var painted: Texture2D = art("icon_missing")

	if painted != null:
		ci.draw_texture_rect(painted, rect, false)
		return

	var k: float = -rect.size.y

	while k < rect.size.x:                          # 45 degree hatching, clipped to the rect
		var a: Vector2 = Vector2(k, rect.size.y)
		var b: Vector2 = Vector2(k + rect.size.y, 0)

		if a.x < 0.0:
			a = Vector2(0, rect.size.y + a.x)
		if b.x > rect.size.x:
			b = Vector2(rect.size.x, b.x - rect.size.x)

		ci.draw_line(rect.position + a, rect.position + b, HATCH, 1.0)
		k += 10.0

	var inner: Rect2 = rect.grow(-6)
	var corners: Array[Vector2] = [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]

	for i in 4:
		ci.draw_dashed_line(corners[i], corners[(i + 1) % 4], GOLD_LINE, 1.0, 6.0, false)

	var cinzel: Font = font("cinzel_bold")
	var px: int = maxi(12, int(rect.size.y * 0.375))
	var base: float = rect.get_center().y + (cinzel.get_ascent(px) - cinzel.get_descent(px)) * 0.5
	ci.draw_string(cinzel, Vector2(rect.position.x, base), "?", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, px, GOLD_LINE)


# A stack count bottom right of a slot: EB Garamond SemiBold 24 with a 1 px outline; it moves up 6 px when a bar is shown.
static func draw_count(ci: CanvasItem, slot: Rect2, count: int, has_bar: bool = false, px: int = 24) -> void:
	if count <= 1 and not has_bar:
		return

	var face: Font = font("garamond_semibold")
	var text: String = str(count)
	var at: Vector2 = Vector2(slot.position.x, slot.end.y - 8.0 - (6.0 if has_bar else 0.0))
	var width: float = slot.size.x - 8.0
	ci.draw_string_outline(face, at, text, HORIZONTAL_ALIGNMENT_RIGHT, width, px, 2, OUTLINE)
	ci.draw_string(face, at, text, HORIZONTAL_ALIGNMENT_RIGHT, width, px, CREAM)


# The hotbar tray (row 11a) under the strip: stitched leather with a cast brass end plate at each end.
static func draw_hotbar_tray(ci: CanvasItem, rect: Rect2 = HOTBAR_TRAY) -> void:
	var painted: StyleBoxTexture = _nine("hotbar_tray", 20, 20, 20, 20)
	_soft_shadow(ci, rect, 10, 10, 6, 0.7)

	if painted != null:
		ci.draw_style_box(painted, rect)
		return

	var leather: StyleBoxFlat = StyleBoxFlat.new()
	leather.bg_color = LEATHER
	leather.set_corner_radius_all(10)
	leather.set_border_width_all(2)
	leather.border_color = LEATHER_LINE
	ci.draw_style_box(leather, rect)
	ci.draw_line(rect.position + Vector2(10, 2.5), rect.position + Vector2(rect.size.x - 10, 2.5), LEATHER_LIGHT, 1.0)
	var x: float = rect.position.x + 26.0

	while x < rect.end.x - 30.0:
		for y in [rect.position.y + 6.0, rect.end.y - 6.0]:
			ci.draw_line(Vector2(x, y + 1), Vector2(x + 5, y + 1), Color(0, 0, 0, 0.6), 1.5)
			ci.draw_line(Vector2(x, y), Vector2(x + 5, y), STITCH, 1.5)
		x += 9.0

	for ex in [rect.position.x - 2.0, rect.end.x - 14.0]:
		var plate: Rect2 = Rect2(ex, rect.position.y + 8.0, 16.0, rect.size.y - 16.0)
		var brass: StyleBoxFlat = StyleBoxFlat.new()
		brass.bg_color = BRASS
		brass.set_corner_radius_all(3)
		brass.set_border_width_all(1)
		brass.border_color = BRASS_DARK
		ci.draw_style_box(brass, plate)

		for ry in [rect.position.y + 22.0, rect.end.y - 22.0]:
			ci.draw_circle(Vector2(ex + 8.0, ry), 3.5, BRASS_DARK)
			ci.draw_circle(Vector2(ex + 7.5, ry - 0.5), 2.2, BRASS_HI)


# A hotbar key number in the top left of its slot: EB Garamond SemiBold 18 with the outline.
static func draw_key_number(ci: CanvasItem, slot: Rect2, index: int) -> void:
	var face: Font = font("garamond_semibold")
	var at: Vector2 = slot.position + Vector2(6, 3 + face.get_ascent(18))
	ci.draw_string_outline(face, at, hotbar_key_text(index), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 2, OUTLINE)
	ci.draw_string(face, at, hotbar_key_text(index), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, HEADING)


# The Craft button (rows 14 to 16): cast brass, "CRAFT" engraved, a warm glow when the recipe can be made,
# and the hold ring at the left end filled to `hold` (0 to 1).
static func draw_craft_button(ci: CanvasItem, rect: Rect2, can_make: bool, pressed: bool = false, hold: float = 0.0, label: String = "CRAFT") -> void:
	if can_make:
		var glow: StyleBoxTexture = _nine("button_glow", 32, 32, 32, 32)

		if glow != null:
			ci.draw_style_box(glow, rect.grow(16))
		else:
			_soft_shadow_coloured(ci, rect.grow(2), 8, 10, CRAFT_GLOW)

	ci.draw_style_box(stylebox_brass(pressed), rect)

	if not pressed and art("button_brass") == null:
		ci.draw_line(rect.position + Vector2(6, 1.5), rect.position + Vector2(rect.size.x - 6, 1.5), BRASS_TOP, 1.0)

	draw_ring(ci, rect.position + Vector2(34, rect.size.y * 0.5), hold)
	var cinzel: Font = font("cinzel_bold")
	var base: float = rect.get_center().y + (cinzel.get_ascent(26) - cinzel.get_descent(26)) * 0.5
	draw_tracked(ci, cinzel, Vector2(rect.get_center().x, base), label, 26, 4.0, INK if can_make else Color(INK, 0.55))


static func tracked_width(face: Font, text: String, px: int, tracking: float) -> float:
	var total: float = 0.0

	for i in text.length():
		total += face.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + (tracking if i > 0 else 0.0)

	return total


# Text centred on `centre.x` with `tracking` px between the letters (the brief's letter-spaced titles); `centre.y` is the baseline.
static func draw_tracked(ci: CanvasItem, face: Font, centre: Vector2, text: String, px: int, tracking: float, colour: Color) -> void:
	var widths: Array[float] = []
	var total: float = 0.0

	for i in text.length():
		var w: float = face.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		widths.append(w)
		total += w + (tracking if i > 0 else 0.0)

	var x: float = centre.x - total * 0.5

	for i in text.length():
		ci.draw_string(face, Vector2(x, centre.y), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, colour)
		x += widths[i] + tracking


# The hold ring (row 16): a 36 px track with a dark arc filled clockwise from the top.
static func draw_ring(ci: CanvasItem, centre: Vector2, share: float) -> void:
	ci.draw_arc(centre, 16.0, 0.0, TAU, 48, BRASS_LO, 4.0, true)

	if share > 0.0:
		ci.draw_arc(centre, 16.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(share, 0.0, 1.0), 48, INK, 4.0, true)


# ================================================================================================ glyphs

# An engraved glyph (rows 18, 20 to 24) filling `rect`, in `colour`, with a 1 px shadow under it at 70 %.
# `cut` is the colour of the surface under the glyph: the placeholder shapes cut their holes in it.
static func draw_glyph(ci: CanvasItem, glyph_name: String, rect: Rect2, colour: Color, cut: Color = FIELD, shadow: bool = true) -> void:
	var texture: Texture2D = art(GLYPH_FILE.get(glyph_name, glyph_name))

	if texture != null:
		if shadow:
			ci.draw_texture_rect(texture, Rect2(rect.position + Vector2(0, 1), rect.size), false, Color(0, 0, 0, 0.7))
		ci.draw_texture_rect(texture, rect, false, colour)
		return

	var ops: Array = glyph_shapes(glyph_name)

	if shadow:
		_draw_ops(ci, ops, Rect2(rect.position + Vector2(0, 1), rect.size), Color(0, 0, 0, 0.7), Color(0, 0, 0, 0), false)

	_draw_ops(ci, ops, rect, colour, cut, true)


static func has_glyph(glyph_name: String) -> bool:
	return not glyph_shapes(glyph_name).is_empty()


# The placeholder shapes of a glyph in a unit square (the same shapes as the mockup script).
# Each op is [kind, ...numbers]: "poly" points, "ell" x0 y0 x1 y1, "ring" x0 y0 x1 y1 width, "line" x0 y0 x1 y1 width,
# "rect" x0 y0 x1 y1, "chord" x0 y0 x1 y1 from_deg to_deg, "arc" x0 y0 x1 y1 from_deg to_deg width.
# A kind ending in "-" is a hole, drawn in the cut colour.
static func glyph_shapes(glyph_name: String) -> Array:
	match glyph_name:
		"heart":
			return [["ell", 0.12, 0.2, 0.52, 0.58], ["ell", 0.48, 0.2, 0.88, 0.58], ["poly", 0.14, 0.46, 0.86, 0.46, 0.5, 0.88]]
		"bolt":
			return [["poly", 0.58, 0.06, 0.22, 0.54, 0.46, 0.54, 0.38, 0.94, 0.78, 0.4, 0.53, 0.4]]
		"moon":
			return [["ell", 0.14, 0.12, 0.86, 0.84], ["ell-", 0.36, 0.04, 1.0, 0.7]]
		"flame", "fire":
			return [["poly", 0.5, 0.04, 0.74, 0.36, 0.82, 0.62, 0.7, 0.86, 0.5, 0.94, 0.3, 0.86, 0.18, 0.62, 0.3, 0.42, 0.38, 0.56, 0.42, 0.3],
				["poly-", 0.5, 0.52, 0.62, 0.7, 0.58, 0.84, 0.5, 0.88, 0.42, 0.84, 0.4, 0.7]]
		"bread":
			return [["chord", 0.08, 0.26, 0.92, 1.0, 180, 360], ["rect", 0.08, 0.6, 0.92, 0.78],
				["line-", 0.26, 0.42, 0.36, 0.56, 0.05], ["line-", 0.44, 0.42, 0.54, 0.56, 0.05], ["line-", 0.62, 0.42, 0.72, 0.56, 0.05]]
		"drop":
			return [["poly", 0.5, 0.06, 0.76, 0.5, 0.24, 0.5], ["ell", 0.22, 0.34, 0.78, 0.92]]
		"helmet":
			return [["chord", 0.16, 0.14, 0.84, 0.86, 180, 360], ["rect", 0.12, 0.48, 0.88, 0.58], ["rect", 0.46, 0.5, 0.54, 0.8]]
		"tunic", "shirt":
			return [["poly", 0.3, 0.1, 0.42, 0.1, 0.5, 0.2, 0.58, 0.1, 0.7, 0.1, 0.94, 0.32, 0.84, 0.46, 0.74, 0.38, 0.74, 0.92,
				0.26, 0.92, 0.26, 0.38, 0.16, 0.46, 0.06, 0.32]]
		"trousers":
			return [["poly", 0.24, 0.08, 0.76, 0.08, 0.84, 0.92, 0.58, 0.92, 0.5, 0.38, 0.42, 0.92, 0.16, 0.92]]
		"boot":
			return [["poly", 0.28, 0.06, 0.58, 0.06, 0.58, 0.56, 0.86, 0.66, 0.9, 0.88, 0.2, 0.88, 0.24, 0.56]]
		"glove":
			return [["rect", 0.26, 0.42, 0.74, 0.92], ["rect", 0.27, 0.18, 0.37, 0.5], ["rect", 0.39, 0.12, 0.49, 0.5],
				["rect", 0.51, 0.12, 0.61, 0.5], ["rect", 0.63, 0.18, 0.73, 0.5], ["poly", 0.26, 0.6, 0.1, 0.42, 0.16, 0.36, 0.3, 0.5]]
		"pack":
			return [["rect", 0.2, 0.2, 0.8, 0.92], ["arc", 0.34, 0.04, 0.66, 0.36, 180, 360, 0.07], ["rect-", 0.3, 0.5, 0.7, 0.74]]
		"axe", "hand_axe":
			return [["line", 0.2, 0.88, 0.72, 0.18, 0.08], ["poly", 0.58, 0.08, 0.9, 0.3, 0.82, 0.46, 0.62, 0.34]]
		"shield":
			return [["poly", 0.16, 0.12, 0.84, 0.12, 0.84, 0.46, 0.5, 0.92, 0.16, 0.46], ["rect-", 0.46, 0.2, 0.54, 0.76]]
		"all":
			return [["rect", 0.12, 0.12, 0.46, 0.46], ["rect", 0.54, 0.12, 0.88, 0.46], ["rect", 0.12, 0.54, 0.46, 0.88], ["rect", 0.54, 0.54, 0.88, 0.88]]
		"spear":
			return [["line", 0.14, 0.86, 0.7, 0.3, 0.06], ["poly", 0.62, 0.3, 0.9, 0.1, 0.7, 0.38]]
		"house":
			return [["poly", 0.08, 0.48, 0.5, 0.1, 0.92, 0.48], ["rect", 0.18, 0.46, 0.82, 0.9], ["rect-", 0.42, 0.62, 0.58, 0.9]]
		"anvil", "forge":
			return [["poly", 0.06, 0.26, 0.84, 0.26, 0.94, 0.36, 0.72, 0.46, 0.62, 0.62, 0.76, 0.86, 0.24, 0.86, 0.38, 0.62, 0.3, 0.46, 0.1, 0.4]]
		"bench", "workbench", "woodworking_table":
			return [["rect", 0.06, 0.3, 0.94, 0.44], ["rect", 0.14, 0.42, 0.24, 0.9], ["rect", 0.76, 0.42, 0.86, 0.9], ["line", 0.18, 0.66, 0.82, 0.66, 0.06]]
		"bowl", "campfire_pot":
			return [["chord", 0.08, 0.12, 0.92, 0.88, 0, 180], ["rect", 0.34, 0.84, 0.66, 0.92],
				["arc", 0.3, 0.08, 0.42, 0.42, 120, 240, 0.05], ["arc", 0.46, 0.08, 0.58, 0.42, 120, 240, 0.05], ["arc", 0.62, 0.08, 0.74, 0.42, 120, 240, 0.05]]
		"leaf":
			return [["chord", 0.12, 0.08, 0.88, 0.92, 225, 405], ["line-", 0.22, 0.78, 0.74, 0.26, 0.05]]
		"chest", "mark_chest":
			return [["rect", 0.08, 0.38, 0.92, 0.88], ["chord", 0.08, 0.12, 0.92, 0.64, 180, 360], ["rect-", 0.08, 0.4, 0.92, 0.46], ["rect-", 0.44, 0.46, 0.56, 0.6]]
		"planks", "saw_mill":
			return [["rect", 0.08, 0.16, 0.92, 0.34], ["rect", 0.12, 0.42, 0.88, 0.6], ["rect", 0.16, 0.68, 0.84, 0.86]]
		"campfire":
			return [["poly", 0.5, 0.08, 0.72, 0.4, 0.7, 0.66, 0.5, 0.74, 0.3, 0.66, 0.28, 0.4], ["line", 0.12, 0.92, 0.88, 0.72, 0.08], ["line", 0.12, 0.72, 0.88, 0.92, 0.08]]
		"clay_hearth", "oven":
			return [["chord", 0.1, 0.18, 0.9, 1.3, 180, 360], ["rect", 0.1, 0.72, 0.9, 0.9], ["chord-", 0.32, 0.5, 0.68, 0.98, 180, 360]]
		"search":
			return [["ring", 0.1, 0.1, 0.66, 0.66, 0.1], ["line", 0.58, 0.58, 0.9, 0.9, 0.12]]
		"sort":
			return [["rect", 0.1, 0.16, 0.9, 0.28], ["rect", 0.1, 0.44, 0.68, 0.56], ["rect", 0.1, 0.72, 0.46, 0.84]]

	return []


static func _ellipse_points(box: Rect2, from_deg: float, to_deg: float, steps: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var centre: Vector2 = box.get_center()
	var radius: Vector2 = box.size * 0.5

	for i in steps + 1:
		var a: float = deg_to_rad(lerpf(from_deg, to_deg, float(i) / float(steps)))
		points.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y))

	return points


static func _draw_ops(ci: CanvasItem, ops: Array, rect: Rect2, colour: Color, cut: Color, with_holes: bool) -> void:
	var s: Vector2 = rect.size
	var o: Vector2 = rect.position

	for op in ops:
		var kind: String = op[0]
		var hole: bool = kind.ends_with("-")

		if hole and not with_holes:
			continue

		var c: Color = cut if hole else colour
		kind = kind.trim_suffix("-")

		if kind == "poly":
			var points: PackedVector2Array = PackedVector2Array()

			for i in range(1, op.size(), 2):
				points.append(o + Vector2(float(op[i]) * s.x, float(op[i + 1]) * s.y))

			ci.draw_colored_polygon(points, c)
			continue

		var box: Rect2 = Rect2(o + Vector2(float(op[1]) * s.x, float(op[2]) * s.y), Vector2((float(op[3]) - float(op[1])) * s.x, (float(op[4]) - float(op[2])) * s.y))

		match kind:
			"ell":
				var round_points: PackedVector2Array = _ellipse_points(box, 0.0, 360.0, 32)
				round_points.remove_at(round_points.size() - 1)
				ci.draw_colored_polygon(round_points, c)
			"ring":
				ci.draw_polyline(_ellipse_points(box, 0.0, 360.0, 32), c, float(op[5]) * s.x, true)
			"rect":
				ci.draw_rect(box, c)
			"line":
				ci.draw_line(box.position, box.end, c, float(op[5]) * s.x, true)
			"chord":
				ci.draw_colored_polygon(_ellipse_points(box, float(op[5]), float(op[6]), 24), c)
			"arc":
				ci.draw_polyline(_ellipse_points(box, float(op[5]), float(op[6]), 16), c, float(op[7]) * s.x, true)
