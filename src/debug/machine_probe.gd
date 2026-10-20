extends Node

# "Measure this machine" (Esc > Advanced): for the 1050-class test. Steps through Low, Medium and
# High while the player stands still and slowly turns, and for each tier reports the average
# frame rate, the 1% low (the slowest 1% of frames), the worst frame, CPU and GPU time, draw
# calls and video memory. The table shows on screen, is printed to the log and saved to
# user://machine_run.txt. The quality tier and the HUD are put back afterwards.
# Nothing runs until it is started.

const TIERS := [0, 1, 2]
const WARMUP_SEC := 8.0            # ground, trees and shaders catch up after a tier change
const MEASURE_SEC := 12.0
const TURN_DEG_PER_SEC := 15.0

var _client
var _label: Label
var _at: int = -1                  # index into TIERS, -1 when not running
var _phase_start: float = 0.0
var _measuring: bool = false
var _ms: Array = []
var _gpu: Array = []
var _cpu: Array = []
var _draws: Array = []
var _rows: Array = []
var _start_quality: int = 2
var _head: String = ""


func setup(client) -> void:
	_client = client
	var layer: CanvasLayer = CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(20.0, 20.0)
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_label)
	add_child(layer)
	set_process(false)


func running() -> bool:
	return _at >= 0


# Starts the run; while it runs, stops it; with the finished table up, closes it.
func toggle() -> void:
	if running():
		_finish(false)
		return

	if _label.text != "":
		_label.text = ""
		_client.hud.visible = true
		return

	_start_quality = _client.quality
	_rows = []
	_head = "%s, %s, %s, %d MB RAM\nwindow %dx%d, 3D %dx%d, vsync %s" % [
		RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name(),
		OS.get_processor_name(), int(OS.get_memory_info().get("physical", 0)) / 1048576,
		get_window().size.x, get_window().size.y, int(_client.display.BASE.x * _client._render_scale), int(_client.display.BASE.y * _client._render_scale),
		["on", "adaptive", "off"][clampi([DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_DISABLED].find(DisplayServer.window_get_vsync_mode()), 0, 2)]]
	_client.hud.visible = false
	_begin_tier(0)
	set_process(true)


func _begin_tier(index: int) -> void:
	_at = index
	_client.quality = TIERS[index]
	_client._apply_quality()
	_phase_start = Time.get_ticks_msec() / 1000.0
	_measuring = false
	_ms = []
	_gpu = []
	_cpu = []
	_draws = []


func _process(delta: float) -> void:
	if not running():
		return

	var now: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = now - _phase_start

	# Turn slowly so the view changes; no other input is needed.
	_client.body.rotate_y(deg_to_rad(TURN_DEG_PER_SEC) * delta)

	if not _measuring and elapsed >= WARMUP_SEC:
		_measuring = true
		_phase_start = now
		elapsed = 0.0

	if _measuring:
		var vp: RID = get_viewport().get_viewport_rid()
		_ms.append(delta * 1000.0)
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
		_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

		if elapsed >= MEASURE_SEC:
			_rows.append(_row())

			if _at + 1 < TIERS.size():
				_begin_tier(_at + 1)
			else:
				_finish(true)
				return

	_show("")


func _row() -> String:
	var sorted: Array = _ms.duplicate()
	sorted.sort()
	var avg_ms: float = _mean(_ms)
	var slow: float = float(sorted[mini(int(float(sorted.size()) * 0.99), sorted.size() - 1)])
	return "%-6s %5.1f fps  1%% low %5.1f fps  worst %6.1f ms  gpu %5.1f ms  cpu %5.1f ms  draws %5d  VRAM %5d MB" % [
		_client.QUALITY_NAMES[TIERS[_at]], 1000.0 / maxf(avg_ms, 0.001), 1000.0 / maxf(slow, 0.001), sorted[sorted.size() - 1],
		_mean(_gpu), _mean(_cpu), int(_mean(_draws)), int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)]


static func _mean(values: Array) -> float:
	var total: float = 0.0

	for value in values:
		total += float(value)

	return total / maxf(float(values.size()), 1.0)


func _show(footer: String) -> void:
	var text: String = "Measure this machine\n" + _head + "\n"

	for row in _rows:
		text += row + "\n"

	if running():
		text += "%s: %s... keep still, do not touch anything (%s)\n" % [
			_client.QUALITY_NAMES[TIERS[_at]], "measuring" if _measuring else "settling",
			"press Esc > Advanced > Measure again to stop"]

	_label.text = text + footer


func _finish(completed: bool) -> void:
	_at = -1
	set_process(false)
	_client.quality = _start_quality
	_client._apply_quality()
	_show("\n" + ("Done. Saved to user://machine_run.txt (press Esc > Advanced > Measure again to close)" if completed else "Stopped."))

	if completed:
		print(_label.text)
		var file: FileAccess = FileAccess.open("user://machine_run.txt", FileAccess.WRITE)

		if file != null:
			file.store_string(_label.text)
