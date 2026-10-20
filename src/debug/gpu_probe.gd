extends Node
# GPU cost probe (Art direction, 2026-10-20). Press F8 while standing still in the scene you
# want to measure. It switches one thing off at a time (grass, trees and shrubs, ground, sea,
# sun shadows, SSAO, glow, fog, anti-aliasing), averages the GPU time over 40 frames for each
# and shows the table at the bottom left; the same table is printed to the log and saved to
# user://gpu_probe.txt. The saving next to each line is what that piece costs in this spot.
# Nothing runs until F8 is pressed.

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
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_label.position += Vector2(10.0, -260.0)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_label)
	add_child(layer)
	set_process(false)


func toggle() -> void:
	if _at >= 0:
		_finish(false)
		return

	_steps = [
		["everything on", Callable()],
		["grass off", func(on): _client.grass.visible = on],
		["trees, shrubs, plants off", func(on): _client.flora.visible = on],
		["ground off", func(on): _client.terrain.visible = on],
		["sea off", func(on): if _client.sea != null: _client.sea.visible = on],
		["sun shadows off", func(on): _client._sun.shadow_enabled = on],
		["SSAO off", func(on): _client._environment.ssao_enabled = on],
		["glow off", func(on): _client._environment.glow_enabled = on],
		["fog off", func(on): _client._environment.fog_enabled = on],
		["anti-aliasing off", func(on): _aa(on)],
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
	var text: String = "GPU probe (F8)%s\n" % ("" if done else ", keep still: step %d of %d" % [_results.size() + 1, _steps.size()])

	for n in range(_results.size()):
		var gpu: float = float(_results[n][1])

		if n == 0:
			text += "%-26s %5.1f ms\n" % [_results[n][0], gpu]
		else:
			text += "%-26s %5.1f ms  (saves %.1f)\n" % [_results[n][0], gpu, float(_results[0][1]) - gpu]

	_label.text = text


func _finish(completed: bool) -> void:
	if _at >= 0 and _at < _steps.size() and _steps[_at][1].is_valid():
		_steps[_at][1].call(true)

	_client.grass.visible = _saved.get("grass", true)
	_client.flora.visible = _saved.get("flora", true)
	_client.terrain.visible = _saved.get("terrain", true)
	_client._sun.shadow_enabled = _saved.get("shadow", true)
	_client._environment.ssao_enabled = _saved.get("ssao", false)
	_client._environment.glow_enabled = _saved.get("glow", false)
	_client._environment.fog_enabled = _saved.get("fog", true)

	if _client.sea != null:
		_client.sea.visible = _saved.get("sea", true)

	_aa(true)
	_at = -1
	set_process(false)
	_show(completed)

	if completed:
		print(_label.text)
		var file: FileAccess = FileAccess.open("user://gpu_probe.txt", FileAccess.WRITE)

		if file != null:
			file.store_string(_label.text)
