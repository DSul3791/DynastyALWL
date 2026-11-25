extends Control

# Server connection indicator: five bars at the top left of the screen like a phone's signal (soft white until the first server pulse, then green when good, amber, red). The bars drop when the round trip is long,
# packets are lost, or the server has been silent (it sends a small pulse four times a second, so a stalled server loses bars within
# a second). No bars and a cross when the connection is gone. The numbers are in the debug details and in the telemetry file.

const BARS := 5
const SILENCE_MSEC := [600, 1200, 2500, 5000, 9000]      # silence that caps the bars at 4, 3, 2, 1, 0
const RTT_MS := [60.0, 120.0, 200.0, 350.0]              # round trip below which the bars are 5, 4, 3, 2 (else 1)
const LOSS_PERCENT := [1.0, 3.0, 10.0]                   # loss above which the bars are at most 4, 3, 2
const SAY_SILENT_MSEC := 8000                            # silence this long puts a plain line under the bars (coordinator 23 Nov 2026: a server restarting or a long spike left the
                                                         # world frozen with no word until the line timed out, 60 to 120 s: net_settings.gd)

var bars: int = BARS
var rtt_ms: float = 0.0
var loss_percent: float = 0.0
var silence_msec: int = 0
var lost: bool = false
var heard: bool = false                                  # a server pulse has arrived (before that the bars stay soft white)
var on_drop: Callable                                    # (text) when the bars fall by two or more, or to 0

var _last_pulse_msec: int = 0
var _peer_of: Callable
var _next_check_msec: int = 0
var _note: Label = null


# What the line under the bars says after `silent_ms` of no word from the server ("" while it talks).
static func silence_words(silent_ms: int) -> String:
	if silent_ms < SAY_SILENT_MSEC:
		return ""

	@warning_ignore("integer_division")
	return "No word from the server for %d s. Waiting for it: it may be restarting, or the connection is slow." % (silent_ms / 1000)


# peer_of returns the ENetPacketPeer of the server (or null).
func setup(peer_of: Callable) -> void:
	_peer_of = peer_of
	_last_pulse_msec = Time.get_ticks_msec()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func pulse() -> void:
	if not heard:
		heard = true
		queue_redraw()

	_last_pulse_msec = Time.get_ticks_msec()


# A frame that took long means this client was the one that stalled, not the server: do not count that time as silence.
func client_stalled(delta: float) -> void:
	if delta > 0.4:
		_last_pulse_msec = Time.get_ticks_msec()


func set_lost() -> void:
	lost = true
	_say_silence("")   # the lost notice says it from here
	bars = 0
	queue_redraw()


func text() -> String:
	return "server link: %d bars, rtt %d ms, loss %.1f%%, silent %d ms%s" % [bars, int(rtt_ms), loss_percent, silence_msec, ", LOST" if lost else ""]


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()

	if lost or now < _next_check_msec:
		return

	_next_check_msec = now + 200
	var peer: ENetPacketPeer = _peer_of.call() if _peer_of.is_valid() else null
	silence_msec = now - _last_pulse_msec
	_say_silence(silence_words(silence_msec) if heard else "")
	var count: int = BARS

	if peer == null or peer.get_state() != ENetPacketPeer.STATE_CONNECTED:
		count = 0
	else:
		rtt_ms = peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
		loss_percent = peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) * 100.0 / 65536.0

		for n in range(RTT_MS.size()):
			if rtt_ms >= RTT_MS[n]:
				count = mini(count, BARS - 1 - n)

		count = maxi(count, 1)

		for n in range(LOSS_PERCENT.size()):
			if loss_percent > LOSS_PERCENT[n]:
				count = mini(count, BARS - 1 - n)

		for n in range(SILENCE_MSEC.size()):
			if silence_msec >= SILENCE_MSEC[n]:
				count = mini(count, BARS - 1 - n)

	if count != bars:
		if on_drop.is_valid() and (count == 0 or bars - count >= 2):
			on_drop.call("link bars %d to %d: %s" % [bars, count, text()])

		bars = count
		queue_redraw()


func _say_silence(words: String) -> void:
	if words == "" and _note == null:
		return

	if _note == null:
		_note = Label.new()
		_note.position = Vector2(0.0, size.y + 4.0)
		_note.add_theme_font_size_override("font_size", 18)
		_note.add_theme_color_override("font_outline_color", Color.BLACK)
		_note.add_theme_constant_override("outline_size", 6)
		_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_note)

	_note.text = words
	_note.visible = words != ""


func _draw() -> void:
	var unit: float = maxf(4.0, size.y / 12.0)
	var colour: Color = Color(1.0, 1.0, 1.0, 0.75)

	if bars <= 1:
		colour = Color(1.0, 0.25, 0.2, 0.95)
	elif bars <= 3:
		colour = Color(1.0, 0.8, 0.2, 0.95)
	elif heard:
		colour = Color(0.35, 0.85, 0.4, 0.95)

	for n in range(BARS):
		var height: float = unit * (1.0 + 1.6 * float(n))
		var rect: Rect2 = Rect2(float(n) * unit * 1.5, size.y - height, unit, height)
		draw_rect(rect, colour if n < bars else Color(1.0, 1.0, 1.0, 0.25))

	if bars == 0:
		var a: Vector2 = Vector2(unit * 8.0, size.y - unit * 5.0)
		draw_line(a, a + Vector2(unit * 3.0, unit * 3.0), Color(1.0, 0.25, 0.2), maxf(2.0, unit * 0.5))
		draw_line(a + Vector2(unit * 3.0, 0.0), a + Vector2(0.0, unit * 3.0), Color(1.0, 0.25, 0.2), maxf(2.0, unit * 0.5))
