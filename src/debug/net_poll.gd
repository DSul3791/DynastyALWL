extends Node

# The client's network poll, timed (Lane A 26 Nov 2026, r4 route at Low on 4 cores: 10 of 14 hitches were 69-118 ms of "physics step and poll"
# with "physics max 0 ms" and no PHYSICS slow line, so the time is in the multiplayer poll: Godot's SceneTree polls the multiplayer before
# any _process, and every message's unpacking, its RPC and the handlers its signal runs happen inside it, unnamed). Godot's own poll is
# turned off and this node polls instead from the process_frame signal, connected before any await of it (Godot polls just before emitting
# it, so the poll still comes before resumed awaits, the deferred calls and every _process), as the piece "net poll". It listens last on
# every signal of the terrain messages node (TerrainNet), so each mark falls when a message's handlers are done: a message's share runs from
# the mark before it (or the poll's start) to its own mark, and "after" is the rest (ENet, messages that raise no signal). A poll over NET_SLOW_MS prints a NET slow line with the longest shares (only there: as frame pieces they
# would sit nested in "net poll" and crowd the HITCH lines). The signal also comes while the game is paused (the lost-connection notice).
# Diagnostics: the messages handled and their order are the same.

const Probe := preload("res://src/debug/frame_probe.gd")
const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")
const NET_SLOW_MS := 30.0
const NET_SLOW_EVERY_MSEC := 2000
const NET_SLOW_NAMES := 8
const RELISTEN_FRAMES := 60   # how often the marks are moved back behind handlers connected since
const JOIN_FRAMES := 600      # and every JOIN_EVERY frames before this, while the welcome connects the views' handlers
const JOIN_EVERY := 10

var net: Node = null
var _polling: bool = false
var _names: PackedStringArray = PackedStringArray()
var _at: PackedInt64Array = PackedInt64Array()
var _marks: Dictionary = {}   # signal name: the Callable connected for it (every signal of net, made at the first listen)
var _frames: int = 0
var _next_slow_msec: int = 0


func _init(messages: Node = null) -> void:
	net = messages


func _ready() -> void:
	get_tree().multiplayer_poll = false
	get_tree().process_frame.connect(_poll)


func _exit_tree() -> void:
	get_tree().process_frame.disconnect(_poll)
	get_tree().multiplayer_poll = true   # the next scene polls the usual way
	_polling = false


func mark(message: String) -> void:
	if _polling:
		_names.append(message)
		_at.append(Time.get_ticks_usec())


# Every signal of `net` gets a mark connected after its other handlers; one whose mark is no longer last (a handler connected since, such as
# the animal and player views at the welcome) is connected again at the end.
func listen() -> void:
	if net == null or not is_instance_valid(net):
		return

	if _marks.is_empty():
		var source: Script = net.get_script()

		if source == null:
			return

		for info in source.get_script_signal_list():   # the messages' own signals, not Node's
			_marks[String(info["name"])] = mark.bind(String(info["name"])).unbind((info["args"] as Array).size())

	for sig in _marks:
		var connections: Array = net.get_signal_connection_list(sig)
		var callable: Callable = _marks[sig]

		if not connections.is_empty() and Callable(connections[connections.size() - 1]["callable"]) == callable:
			continue

		if net.is_connected(sig, callable):
			net.disconnect(sig, callable)

		net.connect(sig, callable)


func _poll() -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if _frames % RELISTEN_FRAMES == 0 or (_frames < JOIN_FRAMES and _frames % JOIN_EVERY == 0):
		listen()

	_frames += 1
	_names.clear()
	_at.clear()
	_polling = true
	var t0: int = Probe.start()
	multiplayer.poll()
	_polling = false
	var end: int = Time.get_ticks_usec()
	Probe.stop("net poll", t0)
	var ms: float = float(end - t0) / 1000.0

	if ms > NET_SLOW_MS and Time.get_ticks_msec() >= _next_slow_msec:
		_next_slow_msec = Time.get_ticks_msec() + NET_SLOW_EVERY_MSEC
		FreezeWatchScript.printer.line("NET slow: poll %.0f ms, %d messages; %s" % [ms, _names.size(), text(split(_names, _at, t0, end))])


# {name: [count, usec]}: each message from the mark before it (or the poll's start) to its own mark, "after" from the last mark to the end.
static func split(names: PackedStringArray, at: PackedInt64Array, t0: int, end: int) -> Dictionary:
	var spans: Dictionary = {}
	var from: int = t0

	for i in names.size():
		var entry: Array = spans.get(names[i], [0, 0])
		entry[0] += 1
		entry[1] += at[i] - from
		spans[names[i]] = entry
		from = at[i]

	spans["after"] = [0, end - from]
	return spans


# "flora_received x6 80 ms, after 2 ms, ..." the longest first, at most NET_SLOW_NAMES.
static func text(spans: Dictionary) -> String:
	var keys: Array = spans.keys()
	keys.sort_custom(func(a, b): return int(spans[a][1]) > int(spans[b][1]))
	var parts: PackedStringArray = PackedStringArray()

	for kind in keys.slice(0, NET_SLOW_NAMES):
		var entry: Array = spans[kind]
		parts.append("%s%s %.0f ms" % [kind, " x%d" % int(entry[0]) if int(entry[0]) > 1 else "", float(entry[1]) / 1000.0])

	return ", ".join(parts)
