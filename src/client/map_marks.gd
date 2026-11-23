extends RefCounted

# The small inked pictures of the Map's landmarks (Dave 23 Nov 2026: "it can have writing on it like it might show a picture of a goblins
# face and say the clans name written under it"; "fruit trees should be marked with an image and writing"). No art was made for them: each
# is a few pen strokes drawn here, about 14 px across, in the sketch's ink, shaken a little by its place so no two look stamped. The page
# writes the name under the picture (map_page.gd). Kinds come from server_map.gd look_round (protocol 163); a kind with no picture here
# gets a plain cross-in-a-circle, so a new kind on the server never draws nothing.

const INK := Color(0.12, 0.11, 0.10)


static func draw_mark(canvas: CanvasItem, kind: String, at: Vector2) -> void:
	var ink: Color = Color(INK, 0.9)
	var base: String = kind.get_slice(":", 0)

	match base:
		"campfire":
			_campfire(canvas, at, ink)
		"cave":
			_cave(canvas, at, ink)
		"spring":
			_cave(canvas, at, ink)
			_ripple(canvas, at + Vector2(0, 7), ink)
		"bog_iron":
			_bog(canvas, at, ink)
		"fruit":
			_fruit_tree(canvas, at, ink)
		"fishing":
			_fish(canvas, at, ink)
		"goblin_camp":
			_goblin(canvas, at, ink)
		"bandit_camp":
			_tent(canvas, at, ink)
		"ore_rock":
			_rock(canvas, at, ink)
		_:
			canvas.draw_arc(at, 5.0, 0.0, TAU, 14, ink, 1.4, true)
			canvas.draw_line(at + Vector2(-3, -3), at + Vector2(3, 3), ink, 1.2, true)


# A shaken polyline: each point moved a little by its place (the same every frame).
static func _hand(canvas: CanvasItem, at: Vector2, pts: Array, ink: Color, width: float = 1.4) -> void:
	var line: PackedVector2Array = PackedVector2Array()

	for p in pts:
		var q: Vector2 = at + p
		line.append(q + Vector2(_n(q.x, q.y), _n(q.y + 17.0, q.x)) * 0.5)

	canvas.draw_polyline(line, ink, width, true)


static func _n(a: float, b: float) -> float:
	return sin(a * 1.7 + b * 0.9) * cos(b * 1.3 - a * 0.4)


# Three crossed sticks and a flame curl over them.
static func _campfire(c: CanvasItem, at: Vector2, ink: Color) -> void:
	_hand(c, at, [Vector2(-6, 5), Vector2(5, 1)], ink)
	_hand(c, at, [Vector2(-5, 1), Vector2(6, 5)], ink)
	_hand(c, at, [Vector2(-6, 4), Vector2(-3, 3), Vector2(0, 0), Vector2(2, -3), Vector2(1, -6), Vector2(3, -8)], ink, 1.3)
	_hand(c, at, [Vector2(0, 0), Vector2(-2, -3), Vector2(-1, -5)], ink, 1.1)


# A hill's dark mouth: an arch with its inside hatched.
static func _cave(c: CanvasItem, at: Vector2, ink: Color) -> void:
	var arch: Array = []

	for k in 9:
		var a: float = PI + PI * float(k) / 8.0
		arch.append(Vector2(cos(a) * 7.0, sin(a) * 6.0 + 3.0))

	_hand(c, at, arch, ink, 1.5)
	_hand(c, at, [Vector2(-9, 3), Vector2(9, 3)], ink, 1.2)

	for x in [-3.0, 0.0, 3.0]:
		_hand(c, at, [Vector2(x - 1.5, 3), Vector2(x + 1.5, -2)], Color(ink, ink.a * 0.7), 1.0)


static func _ripple(c: CanvasItem, at: Vector2, ink: Color) -> void:
	_hand(c, at, [Vector2(-6, 0), Vector2(-3, -1), Vector2(0, 0), Vector2(3, -1), Vector2(6, 0)], Color(ink, ink.a * 0.8), 1.1)


# Rust-coloured ground in black and white: a low wet hollow with small lumps of ore in it.
static func _bog(c: CanvasItem, at: Vector2, ink: Color) -> void:
	_hand(c, at, [Vector2(-8, 2), Vector2(-4, 4), Vector2(0, 4.5), Vector2(4, 4), Vector2(8, 2)], ink, 1.3)

	for p in [Vector2(-4, 0), Vector2(0, -1), Vector2(4, 0), Vector2(-1, 2)]:
		c.draw_circle(at + p, 1.3, ink)

	for x in [-6.0, 6.0]:
		_hand(c, at, [Vector2(x, 1), Vector2(x - 1, -4)], Color(ink, ink.a * 0.7), 1.0)
		_hand(c, at, [Vector2(x, 1), Vector2(x + 1.5, -3)], Color(ink, ink.a * 0.7), 1.0)


# A round tree with fruit hanging in it.
static func _fruit_tree(c: CanvasItem, at: Vector2, ink: Color) -> void:
	var crown: Array = []

	for k in 13:
		var a: float = TAU * float(k) / 12.0
		var r: float = 6.0 + 0.8 * sin(float(k) * 2.1)
		crown.append(Vector2(cos(a) * r, sin(a) * r * 0.85 - 3.0))

	_hand(c, at, crown, ink, 1.4)
	_hand(c, at, [Vector2(0, 2), Vector2(0.4, 8)], ink, 1.6)

	for p in [Vector2(-3, -4), Vector2(2, -6), Vector2(3, -1), Vector2(-1, -1)]:
		c.draw_circle(at + p, 1.2, ink)


# A fish, nose to the left.
static func _fish(c: CanvasItem, at: Vector2, ink: Color) -> void:
	_hand(c, at, [Vector2(5, -3), Vector2(1, -4), Vector2(-4, -3), Vector2(-7, 0), Vector2(-4, 3), Vector2(1, 4), Vector2(5, 3), Vector2(9, -3), Vector2(9, 3), Vector2(5, -3)], ink, 1.4)
	c.draw_circle(at + Vector2(-4, -1), 0.9, ink)


# A goblin's face: a lumpy head, long pointed ears, two eyes and a grin of crooked teeth.
static func _goblin(c: CanvasItem, at: Vector2, ink: Color) -> void:
	var head: Array = []

	for k in 13:
		var a: float = TAU * float(k) / 12.0
		var r: float = 6.0 + 0.7 * sin(float(k) * 3.0)
		head.append(Vector2(cos(a) * r * 0.9, sin(a) * r))

	_hand(c, at, head, ink, 1.5)
	_hand(c, at, [Vector2(-5, -2), Vector2(-12, -6), Vector2(-5, 1)], ink, 1.3)
	_hand(c, at, [Vector2(5, -2), Vector2(12, -6), Vector2(5, 1)], ink, 1.3)
	c.draw_circle(at + Vector2(-2.3, -1.5), 1.1, ink)
	c.draw_circle(at + Vector2(2.3, -1.5), 1.1, ink)
	_hand(c, at, [Vector2(-3.5, 2.5), Vector2(-2, 3.5), Vector2(0, 3.8), Vector2(2, 3.5), Vector2(3.5, 2.5)], ink, 1.2)

	for x in [-1.8, 1.2]:
		_hand(c, at, [Vector2(x, 3.4), Vector2(x + 0.5, 5.0), Vector2(x + 1.0, 3.6)], ink, 1.0)


# A rough tent: two poles meeting at the top, its sides, a dark door.
static func _tent(c: CanvasItem, at: Vector2, ink: Color) -> void:
	_hand(c, at, [Vector2(-8, 5), Vector2(0, -6), Vector2(8, 5), Vector2(-8, 5)], ink, 1.5)
	_hand(c, at, [Vector2(-1, -8), Vector2(0, -6), Vector2(1, -8)], ink, 1.2)
	_hand(c, at, [Vector2(-2, 5), Vector2(0, 0), Vector2(2, 5)], ink, 1.2)


# A broken rock: a lumpy outline with a crack down it and a chip off it.
static func _rock(c: CanvasItem, at: Vector2, ink: Color) -> void:
	_hand(c, at, [Vector2(-7, 4), Vector2(-6, -1), Vector2(-3, -5), Vector2(2, -5), Vector2(6, -2), Vector2(7, 4), Vector2(-7, 4)], ink, 1.5)
	_hand(c, at, [Vector2(0, -5), Vector2(-1, -1), Vector2(1, 1), Vector2(0, 4)], ink, 1.1)
	_hand(c, at, [Vector2(8, -5), Vector2(10, -4), Vector2(9, -2)], Color(ink, ink.a * 0.8), 1.0)
