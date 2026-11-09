extends Control

# The info strip under the pack grid (docs/ui/inventory_crafting_redesign.md section 4.1, v4; Kathleen, 9 Nov 2026), step 3b:
# an ornament rule, then the item under the pointer (or the selected one) in a 72 px well, its name in Cinzel Bold, one line of
# description and one line of facts. It is the one place to read about an item; nothing to show leaves a dim hint.

const ArtKit := preload("res://src/client/ui/art_kit.gd")

const HEIGHT := 92.0
const WELL := 72.0
const NAME_PX := 30
const BODY_PX := 18
const HINT := "Point at an item to read about it."

var icon: Texture2D = null
var title: String = ""
var description: String = ""
var facts: Array = []          # [label, value] pairs: the label dim, the value cream


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_item(texture: Texture2D, item_name: String, text: String, item_facts: Array) -> void:
	if texture == icon and item_name == title and text == description and item_facts == facts:
		return

	icon = texture
	title = item_name
	description = text
	facts = item_facts
	queue_redraw()


func clear() -> void:
	show_item(null, "", "", [])


func _draw() -> void:
	ArtKit.draw_rule(self, 0.0, size.x, 4.0)
	var top: float = 14.0

	if title == "":
		var dim: Font = ArtKit.font("garamond")
		draw_string(dim, Vector2(0.0, top + 40.0), HINT, HORIZONTAL_ALIGNMENT_CENTER, size.x, BODY_PX, ArtKit.DIM)
		return

	var well: Rect2 = Rect2(0.0, top, WELL, WELL)
	ArtKit.draw_well(self, well)
	ArtKit.draw_icon(self, icon, well)
	var x: float = WELL + 16.0
	var room: float = size.x - x
	var heading: Font = ArtKit.font("cinzel_bold")
	var px: int = NAME_PX

	while px > BODY_PX and heading.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
		px -= 2

	draw_string(heading, Vector2(x, top + 26.0), title, HORIZONTAL_ALIGNMENT_LEFT, room, px, ArtKit.HEADING)
	var body: Font = ArtKit.font("garamond")
	draw_string(body, Vector2(x, top + 48.0), _fit(body, description, room), HORIZONTAL_ALIGNMENT_LEFT, room, BODY_PX, ArtKit.CREAM)
	var strong: Font = ArtKit.font("garamond_semibold")
	var fx: float = x

	for fact in facts:
		var label: String = str(fact[0]) + " "
		var value: String = str(fact[1])
		var lw: float = body.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_PX).x
		var vw: float = strong.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_PX).x

		if fx + lw + vw > size.x:
			break

		draw_string(body, Vector2(fx, top + 70.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_PX, ArtKit.DIM)
		draw_string(strong, Vector2(fx + lw, top + 70.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_PX, ArtKit.CREAM)
		fx += lw + vw + 24.0


# The text cut to one line of `room` px, ending in an ellipsis when it was cut.
static func _fit(font: Font, text: String, room: float) -> String:
	var line: String = text.get_slice("\n", 0)

	if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_PX).x <= room:
		return line

	while line.length() > 1 and font.get_string_size(line + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_PX).x > room:
		line = line.left(line.length() - 1)

	return line.strip_edges() + "…"
