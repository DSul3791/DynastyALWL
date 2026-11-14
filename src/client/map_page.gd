extends Control

# The Journal's Map page (docs/design/PLAYER_JOURNAL_GOALS_UI.md, PLAYER_CARTOGRAPHY_MAP_DESIGN.md s1.6): one paper surface showing the
# charcoal sketch of what THIS character has surveyed, nothing else. A fresh character sees a blank page. The Journal (journal_view.gd)
# puts this control in its Map panel and sets `knowledge` (map_knowledge.gd) and `where` (the body's position, for the small cross).
# Mouse wheel zooms, dragging pans; nothing else on the page. Block sketches are cached and only changed blocks (and their neighbours,
# whose edges read them) are drawn again, a few milliseconds a frame while the page is visible.

const Sketch := preload("res://src/client/map_sketch.gd")

const PAPER := Color(0.86, 0.81, 0.69)
const BUDGET_USEC := 6000          # sketch work per frame while visible
const ZOOM_MIN := 0.5
const ZOOM_MAX := 6.0

var knowledge = null: set = set_knowledge
var where: Callable                 # () -> Vector3, the body's position
var player_at: Vector3 = Vector3.ZERO
var zoom: float = 1.5               # screen pixels per sketch pixel
var centre: Vector2 = Vector2.ZERO  # the world sketch pixel at the middle of the page
var follow: bool = true             # stays on the player until the page is dragged

var _textures: Dictionary = {}      # Vector2i block -> ImageTexture
var _dirty: Dictionary = {}         # Vector2i block -> true
var _dragging: bool = false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(func() -> void:
		_dragging = false   # a drag cut off by closing the Journal never carries over
		if is_visible_in_tree():
			follow = true)
	tree_exited.connect(func() -> void: _dragging = false)


func set_knowledge(store) -> void:
	if knowledge != null and knowledge.block_changed.is_connected(_on_block_changed):
		knowledge.block_changed.disconnect(_on_block_changed)

	knowledge = store
	_textures.clear()
	_dirty.clear()

	if knowledge != null:
		knowledge.block_changed.connect(_on_block_changed)

		for block in knowledge.blocks:
			_dirty[block] = true

	queue_redraw()


# A changed block, and its eight neighbours: their edge pixels read its cells.
func _on_block_changed(block: Vector2i) -> void:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var b: Vector2i = block + Vector2i(dx, dz)

			if b == block or knowledge.blocks.has(b) or _textures.has(b):
				_dirty[b] = true

	queue_redraw()


func _world_to_sketch(at: Vector3) -> Vector2:
	var per_m: float = float(Sketch.PX) / knowledge.cell_m
	return Vector2(at.x * per_m, at.z * per_m)


func _process(_delta: float) -> void:
	if knowledge == null or not is_visible_in_tree():
		return

	if where.is_valid():
		var at: Vector3 = where.call()

		if at.distance_squared_to(player_at) > 0.01:
			player_at = at
			queue_redraw()

	if follow:
		var want: Vector2 = _world_to_sketch(player_at)

		if want.distance_to(centre) > 0.5:
			centre = want
			queue_redraw()

	if _dirty.is_empty():
		return

	# Nearest the middle of the page first, within the frame budget.
	var started: int = Time.get_ticks_usec()
	var size_px: float = float(knowledge.block_cells * Sketch.PX)
	var order: Array = _dirty.keys()
	order.sort_custom(func(a, b): return (Vector2(a) + Vector2(0.5, 0.5)).distance_squared_to(centre / size_px) < (Vector2(b) + Vector2(0.5, 0.5)).distance_squared_to(centre / size_px))

	for block in order:
		_dirty.erase(block)

		if knowledge.blocks.has(block):
			_textures[block] = ImageTexture.create_from_image(Sketch.render_block(knowledge, block))
		else:
			_textures.erase(block)

		if Time.get_ticks_usec() - started > BUDGET_USEC:
			break

	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)

	if knowledge == null:
		return

	var size_px: float = float(knowledge.block_cells * Sketch.PX)
	var middle: Vector2 = size * 0.5

	for block in _textures:
		var top_left: Vector2 = middle + (Vector2(block) * size_px - centre) * zoom
		var rect: Rect2 = Rect2(top_left, Vector2(size_px, size_px) * zoom)

		if rect.intersects(Rect2(Vector2.ZERO, size)):
			draw_texture_rect(_textures[block], rect, false)

	if knowledge.is_empty():
		var font: Font = get_theme_default_font()
		var text: String = "Nothing mapped yet. Explore to fill this page."
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, middle - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Sketch.INK, 0.6))

	# Where you are: a small charcoal cross.
	var me: Vector2 = middle + (_world_to_sketch(player_at) - centre) * zoom
	draw_line(me + Vector2(-5, -5), me + Vector2(5, 5), Color(Sketch.INK, 0.85), 2.0)
	draw_line(me + Vector2(-5, 5), me + Vector2(5, -5), Color(Sketch.INK, 0.85), 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event

		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			zoom = clampf(zoom * 1.15, ZOOM_MIN, ZOOM_MAX)
			queue_redraw()
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			zoom = clampf(zoom / 1.15, ZOOM_MIN, ZOOM_MAX)
			queue_redraw()
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		follow = false
		centre -= (event as InputEventMouseMotion).relative / zoom
		queue_redraw()
		accept_event()
