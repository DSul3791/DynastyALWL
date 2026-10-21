extends Node
# GPU cost probe (Art direction, 2026-10-20). Press Ctrl+Shift+G (or Esc > Advanced > GPU breakdown) while standing still in the scene you
# want to measure. It switches one thing off at a time (grass, trees and shrubs, ground, sea,
# sun shadows, SSAO, glow, fog, anti-aliasing), averages the GPU time over 40 frames for each
# and shows the table at the bottom left; the same table is printed to the log and saved to
# user://gpu_probe.txt. The saving next to each line is what that piece costs in this spot.
# Nothing runs until it is started.

const WARMUP := 20
const MEASURE := 40

var _client
var _label: Label
var _steps: Array = []
var _results: Array = []
var _at: int = -1
var _frame: int = 0
var _sum: float = 0.0
var _saved: Dictionary = {}


func setup(client) -> void:
	_client = client
	var layer: CanvasLayer = CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(20.0, 20.0)
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_label)
	add_child(layer)
	set_process(false)


# Starts the probe; while it runs, stops it; with the finished table up, closes it.
# The debug text is hidden while the table is up so every row fits on the screen.
func toggle() -> void:
	if _at >= 0:
		_finish(false)
		return

	if _label.text != "":
		_label.text = ""
		_client.hud.visible = true
		return

	_steps = [
		["everything on", Callable()],
		["grass off", func(on): _client.grass.visible = on],
		["trees off", func(on): _flora_kind(0, on)],
		["shrubs off", func(on): _flora_kind(1, on)],
		["plants off", func(on): _flora_kind(2, on)],
		["trees beyond 100 m off", func(on): _flora_far(100.0, on)],
		["trees beyond 200 m off", func(on): _flora_far(200.0, on)],
		["tree shadows off", func(on): _flora_shadows(on)],
		["ground off", func(on): _client.terrain.visible = on],
		["sea off", func(on): if _client.sea != null: _client.sea.visible = on],
		["sun shadows off", func(on): _client._sun.shadow_enabled = on],
		["SSAO off", func(on): _client._environment.ssao_enabled = on],
		["glow off", func(on): _client._environment.glow_enabled = on],
		["fog off", func(on): _client._environment.fog_enabled = on],
		["anti-aliasing off", func(on): _aa(on)],
		["3D at full window size", func(on): _scale(on, 1.0)],
		["3D at half the pixels (0.71)", func(on): _scale(on, 0.71)],
		["sky clouds at Low quality", func(on): _sky(on)],
	]
	_results = []
	_saved = {
		"grass": _client.grass.visible, "flora": _client.flora.visible, "terrain": _client.terrain.visible,
		"shadow": _client._sun.shadow_enabled, "ssao": _client._environment.ssao_enabled,
		"glow": _client._environment.glow_enabled, "fog": _client._environment.fog_enabled,
		"taa": get_viewport().use_taa, "aa": get_viewport().screen_space_aa,
		"sea": _client.sea.visible if _client.sea != null else true,
	}
	_at = -1
	_next_step()
	set_process(true)


# Every flora draw (one MultiMesh per chunk part and species) with its kind tag.
func _flora_draws() -> Array:
	var found: Array = []
	var pending: Array = [_client.flora]

	while not pending.is_empty():
		var node: Node = pending.pop_back()

		for child in node.get_children():
			if child is MultiMeshInstance3D and child.has_meta("kind"):
				found.append(child)
			else:
				pending.append(child)

	return found


func _flora_kind(kind: int, on: bool) -> void:
	for draw in _flora_draws():
		if int(draw.get_meta("kind")) == kind:
			draw.visible = on


# Trees whose chunk part is farther than metres from the player (the part's centre, so the
# cut is as coarse as the parts).
func _flora_far(metres: float, on: bool) -> void:
	var here: Vector3 = _client.body.global_position

	for draw in _flora_draws():
		if int(draw.get_meta("kind")) != 0:
			continue

		var centre: Vector3 = draw.global_transform * draw.get_aabb().get_center()
		draw.visible = on or centre.distance_to(here) <= metres


func _flora_shadows(on: bool) -> void:
	for draw in _flora_draws():
		if int(draw.get_meta("kind")) == 0:
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (on and bool(draw.get_meta("casts"))) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _scale(on: bool, value: float) -> void:
	var vp: Viewport = get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if (on and _client._render_scale < 0.99) or (not on and value < 0.99) else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = _client._render_scale if on else value


func _sky(on: bool) -> void:
	_client.SkyClouds.set_quality(_client._environment.sky, _client.quality if on else 0)


func _aa(on: bool) -> void:
	get_viewport().use_taa = _saved["taa"] if on else false
	get_viewport().screen_space_aa = _saved["aa"] if on else Viewport.SCREEN_SPACE_AA_DISABLED


func _next_step() -> void:
	if _at >= 0 and _steps[_at][1].is_valid():
		_steps[_at][1].call(true)

	_at += 1

	if _at >= _steps.size():
		_finish(true)
		return

	if _steps[_at][1].is_valid():
		_steps[_at][1].call(false)

	_frame = 0
	_sum = 0.0


func _process(_delta: float) -> void:
	if _at < 0:
		return

	_frame += 1

	if _frame > WARMUP:
		_sum += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())

	if _frame >= WARMUP + MEASURE:
		_results.append([_steps[_at][0], _sum / float(MEASURE)])
		_show(false)
		_next_step()


func _show(done: bool) -> void:
	var win: Vector2i = get_window().size
	var text: String = "GPU probe (Ctrl+Shift+G)%s\n" % ("" if done else ", keep still: step %d of %d" % [_results.size() + 1, _steps.size()])
	text += "%s, %s, window %dx%d, 3D scale %.2f, quality %s\n" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name(), win.x, win.y, _client._render_scale, _client.QUALITY_NAMES[_client.quality]]

	# CPU side, so a frame that does not move with any switch below is recognised as CPU bound (owner table,
	# 2026-10-21: nothing saved more than 0.9 ms in tall grass): script time per frame, physics time, draw calls, triangles.
	text += "CPU: scripts %.1f ms, physics %.1f ms; %d draw calls, %.0f k triangles, %d fps\n" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0,
		int(Engine.get_frames_per_second())]

	for n in range(_results.size()):
		var gpu: float = float(_results[n][1])

		if n == 0:
			text += "%-26s %5.1f ms\n" % [_results[n][0], gpu]
		else:
			text += "%-26s %5.1f ms  (saves %.1f)\n" % [_results[n][0], gpu, float(_results[0][1]) - gpu]

	_label.text = text + "(press Ctrl+Shift+G again to close this table)"
	_client.hud.visible = false


func _finish(completed: bool) -> void:
	if _at >= 0 and _at < _steps.size() and _steps[_at][1].is_valid():
		_steps[_at][1].call(true)

	_client.grass.visible = _saved.get("grass", true)
	_client.flora.visible = _saved.get("flora", true)
	_flora_kind(0, true)
	_flora_kind(1, true)
	_flora_kind(2, true)
	_flora_far(0.0, true)
	_flora_shadows(true)
	_client.terrain.visible = _saved.get("terrain", true)
	_client._sun.shadow_enabled = _saved.get("shadow", true)
	_client._environment.ssao_enabled = _saved.get("ssao", false)
	_client._environment.glow_enabled = _saved.get("glow", false)
	_client._environment.fog_enabled = _saved.get("fog", true)

	if _client.sea != null:
		_client.sea.visible = _saved.get("sea", true)

	_aa(true)
	_scale(true, 1.0)
	_sky(true)
	_at = -1
	set_process(false)
	_show(completed)

	if completed:
		print(_label.text)
		var file: FileAccess = FileAccess.open("user://gpu_probe.txt", FileAccess.WRITE)

		if file != null:
			file.store_string(_label.text)
