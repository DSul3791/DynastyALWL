extends Control

# The Journal's Map page (docs/design/PLAYER_JOURNAL_GOALS_UI.md, PLAYER_CARTOGRAPHY_MAP_DESIGN.md s1.6): one paper surface showing the
# charcoal sketch of what THIS character has surveyed, nothing else. A fresh character sees a blank page. The Journal (journal_view.gd)
# puts this control in its Map panel and sets `knowledge` (map_knowledge.gd) and `where` (the body's position, for the small cross).
# The snares and Bird traps this character has set are marked on it (protocol 150, map_knowledge.traps). Mouse wheel zooms, dragging
# pans; nothing else on the page. Block sketches are cached and only changed blocks (and their neighbours,
# whose edges read them) are drawn again, one at a time on a worker thread (a block is about 55 ms of work, David4 14 Nov 2026: on the
# main thread every opening of a big map would stutter); the main thread only copies a block's cells out and makes the texture.

const Sketch := preload("res://src/client/map_sketch.gd")

const PAPER := Color(0.86, 0.81, 0.69)
const ZOOM_MIN := 0.5
const ZOOM_MAX := 6.0

var knowledge = null: set = set_knowledge
var where: Callable                 # () -> Vector3, the body's position
var tracking: Callable              # () -> the character's Tracking level: at knowledge.trails_tracking and up the game trails are drawn
var _trails_on: bool = false
var player_at: Vector3 = Vector3.ZERO
var zoom: float = 1.5               # screen pixels per sketch pixel
var centre: Vector2 = Vector2.ZERO  # the world sketch pixel at the middle of the page
var follow: bool = true             # stays on the player until the page is dragged

var _textures: Dictionary = {}      # Vector2i block -> ImageTexture
var _dirty: Dictionary = {}         # Vector2i block -> true
var _dragging: bool = false
var _job: int = -1                  # the WorkerThreadPool task drawing _job_block, -1 none
var _job_block: Vector2i = Vector2i.ZERO
var _job_out: Array = [null]        # the task's Image


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

	if knowledge != null and knowledge.traps_changed.is_connected(queue_redraw):
		knowledge.traps_changed.disconnect(queue_redraw)

	if knowledge != null and knowledge.trails_changed.is_connected(queue_redraw):
		knowledge.trails_changed.disconnect(queue_redraw)

	knowledge = store
	_textures.clear()
	_dirty.clear()
	_job_out = [null]   # a block still being drawn from the old store is dropped when it finishes

	if knowledge != null:
		knowledge.block_changed.connect(_on_block_changed)
		knowledge.traps_changed.connect(queue_redraw)
		knowledge.trails_changed.connect(queue_redraw)

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

	var trails_on: bool = tracking.is_valid() and float(tracking.call()) >= float(knowledge.trails_tracking)

	if trails_on != _trails_on:
		_trails_on = trails_on
		queue_redraw()

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

	if _job >= 0:
		if not WorkerThreadPool.is_task_completed(_job):
			return

		WorkerThreadPool.wait_for_task_completion(_job)
		_job = -1

		if knowledge.blocks.has(_job_block) and _job_out[0] != null:
			_textures[_job_block] = ImageTexture.create_from_image(_job_out[0])
			queue_redraw()

	# The dirty block nearest the middle of the page next.
	var size_px: float = float(knowledge.block_cells * Sketch.PX)
	var mid: Vector2 = centre / size_px - Vector2(0.5, 0.5)

	while not _dirty.is_empty():
		var best: Vector2i = _dirty.keys()[0]

		for block in _dirty:
			if Vector2(block).distance_squared_to(mid) < Vector2(best).distance_squared_to(mid):
				best = block

		_dirty.erase(best)

		if not knowledge.blocks.has(best):
			_textures.erase(best)
			queue_redraw()
			continue

		var side: int = knowledge.block_cells * Sketch.PX
		var grid: Dictionary = Sketch.gather(knowledge, Vector2i(best.x * side, best.y * side), Vector2i(side, side))
		var out: Array = [null]
		_job_out = out
		_job_block = best
		_job = WorkerThreadPool.add_task(func() -> void: out[0] = Sketch.paint(grid), false, "map sketch")
		return


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _job >= 0:
		WorkerThreadPool.wait_for_task_completion(_job)   # a task is never left running on a freed page


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

	# Game trails (Dave 23 Nov 2026), once Tracking reaches knowledge.trails_tracking: a thin dashed charcoal line, only where surveyed.
	if _trails_on:
		var page: Rect2 = Rect2(Vector2.ZERO, size).grow(8.0)

		var per_m: float = float(Sketch.PX) / knowledge.cell_m
		var view: Rect2 = Rect2((centre - middle / zoom) / per_m, size / zoom / per_m)   # the page in world metres

		for step in knowledge.surveyed_trail_steps(view):
			var a: Vector2 = middle + (_world_to_sketch(Vector3(step[0].x, 0.0, step[0].y)) - centre) * zoom
			var b: Vector2 = middle + (_world_to_sketch(Vector3(step[1].x, 0.0, step[1].y)) - centre) * zoom

			if page.has_point(a) or page.has_point(b):
				draw_dashed_line(a, b, Color(Sketch.INK, 0.55), 1.2, 4.0)

	# The traps this character has set: a snare is a noose on its stake, a Bird trap a little cage.
	for trap in knowledge.traps:
		var spot: Vector2 = middle + (_world_to_sketch(Vector3(trap[0].x, 0.0, trap[0].y)) - centre) * zoom

		if Rect2(Vector2.ZERO, size).grow(12.0).has_point(spot):
			_draw_trap(spot, str(trap[1]))

	# Where you are: a small charcoal cross.
	var me: Vector2 = middle + (_world_to_sketch(player_at) - centre) * zoom
	draw_line(me + Vector2(-5, -5), me + Vector2(5, 5), Color(Sketch.INK, 0.85), 2.0)
	draw_line(me + Vector2(-5, 5), me + Vector2(5, -5), Color(Sketch.INK, 0.85), 2.0)
	_draw_legend()


# A small key in the page's lower left corner (coordinator 23 Nov 2026: what the marks mean, on the map itself). The game-trail row only shows
# once the trails are drawn; the trap rows always (a tester reads what a mark will be before setting one).
const LEGEND_PX := 14
const LEGEND_ROW := 20.0


func _draw_legend() -> void:
	var font: Font = get_theme_default_font()
	var rows: Array = [["you", "You"], ["snare_trap", "Snare"], ["bird_trap_set", "Bird trap"]]

	if _trails_on:
		rows.append(["trail", "Game trail"])

	var width: float = 0.0

	for row in rows:
		width = maxf(width, font.get_string_size(str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_PX).x)

	width += 30.0   # the mark's column (the Journal's footer already says wheel to zoom, drag to move)
	var box: Rect2 = Rect2(Vector2(10.0, size.y - 10.0 - LEGEND_ROW * rows.size() - 8.0), Vector2(width + 16.0, LEGEND_ROW * rows.size() + 8.0))
	draw_rect(box, Color(PAPER.lightened(0.08), 0.92))
	draw_rect(box, Color(Sketch.INK, 0.35), false, 1.0)
	var ink: Color = Color(Sketch.INK, 0.85)

	for i in range(rows.size()):
		var y: float = box.position.y + 4.0 + LEGEND_ROW * (i + 0.5)
		var mark: Vector2 = Vector2(box.position.x + 16.0, y)
		match str(rows[i][0]):
			"you":
				draw_line(mark + Vector2(-5, -5), mark + Vector2(5, 5), ink, 2.0)
				draw_line(mark + Vector2(-5, 5), mark + Vector2(5, -5), ink, 2.0)
			"trail":
				draw_dashed_line(mark + Vector2(-8, 0), mark + Vector2(8, 0), Color(Sketch.INK, 0.55), 1.2, 4.0)
			_:
				_draw_trap(mark + Vector2(0, -2), str(rows[i][0]))
		draw_string(font, Vector2(box.position.x + 32.0, y + LEGEND_PX * 0.35), str(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_PX, ink)


# One trap mark at `spot`.
func _draw_trap(spot: Vector2, kind: String) -> void:
	var ink: Color = Color(Sketch.INK, 0.9)

	if kind == "bird_trap_set":
		draw_polyline(PackedVector2Array([spot + Vector2(-5, 4), spot + Vector2(0, -5), spot + Vector2(5, 4), spot + Vector2(-5, 4)]), ink, 1.6)
		draw_line(spot + Vector2(0, -5), spot + Vector2(0, 4), ink, 1.2)
	else:
		draw_arc(spot + Vector2(0, -2), 4.0, 0.0, TAU, 14, ink, 1.6)
		draw_line(spot + Vector2(0, 2), spot + Vector2(0, 8), ink, 2.0)


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
