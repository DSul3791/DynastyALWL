extends RefCounted

# A small own log file (user://<name>) that is flushed line by line, for finding why a game or server stops: connection
# events, main-thread stalls, peer statistics. It is cut back to its last lines when it grows, and a new run starts it afresh.

var _file: FileAccess
var _path: String
var _lines: int = 0
var _last_tick_msec: int = 0
var _next_state_msec: int = 0
var _max_gap_msec: int = 0
var _mutex: Mutex = Mutex.new()
var _phase: String = ""                 # what the main thread is in (mark()), read by the watchdog thread
var _phase_since_msec: int = 0
var _phase_max: Dictionary = {}         # phase -> longest ms this second
var _watchdog: Thread
var _stop: bool = false


# The file goes into the project's crash_reports folder (the one the game is played from, so it shows up in GitHub Desktop);
# user:// when that folder cannot be written.
func start(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://crash_reports"))
	_path = "res://crash_reports/" + name
	_file = FileAccess.open(_path, FileAccess.WRITE)

	if _file == null:
		_path = "user://" + name
		_file = FileAccess.open(_path, FileAccess.WRITE)


func event(text: String) -> void:
	_mutex.lock()
	_write(text)
	_mutex.unlock()


func _write(text: String) -> void:
	if _file == null:
		return

	var t: Dictionary = Time.get_time_dict_from_system()
	_file.store_line("[%02d:%02d:%02d.%03d] %s" % [t["hour"], t["minute"], t["second"], Time.get_ticks_msec() % 1000, text])
	_file.flush()
	_lines += 1

	if _lines > 1200:
		_cut()


# Call every frame: logs a stall when the main thread was away more than `stall_msec`, and `state` (a Callable returning text) every `every_msec`.
func tick(state: Callable, every_msec: int, stall_msec: int) -> void:
	var now: int = Time.get_ticks_msec()

	if _last_tick_msec > 0 and now - _last_tick_msec > stall_msec:
		event("STALL: the main thread did not run for %d ms" % (now - _last_tick_msec))

	if _last_tick_msec > 0:
		_max_gap_msec = maxi(_max_gap_msec, now - _last_tick_msec)

	_last_tick_msec = now

	if now >= _next_state_msec:
		_next_state_msec = now + every_msec
		event("max gap %d ms%s | %s" % [_max_gap_msec, _slowest_phases(), String(state.call())])
		_max_gap_msec = 0
		_phase_max.clear()


# The main thread says where it is (one call between the steps of a frame). The time since the last mark goes to the step
# that just ended; the slowest steps of the second are printed in the state line, and the watchdog names the step a frozen
# main thread is stuck in.
func mark(phase: String) -> void:
	var now: int = Time.get_ticks_msec()

	if _phase != "":
		_phase_max[_phase] = maxi(int(_phase_max.get(_phase, 0)), now - _phase_since_msec)

	_phase = phase
	_phase_since_msec = now


func _slowest_phases() -> String:
	var parts: PackedStringArray = PackedStringArray()

	for phase in _phase_max:
		if int(_phase_max[phase]) >= 50:
			parts.append("%s %d" % [phase, int(_phase_max[phase])])

	return " (slow steps ms: %s)" % ", ".join(parts) if not parts.is_empty() else ""


# A thread that writes a line each second while the main thread has not run for 3 s, naming the step it is stuck in.
func start_watchdog() -> void:
	_watchdog = Thread.new()
	_watchdog.start(_watch)


func stop_watchdog() -> void:
	_stop = true

	if _watchdog != null and _watchdog.is_started():
		_watchdog.wait_to_finish()


func _watch() -> void:
	while not _stop:
		OS.delay_msec(1000)
		var silent: int = Time.get_ticks_msec() - _last_tick_msec

		if _last_tick_msec > 0 and silent > 3000:
			event("WATCHDOG: the main thread has been silent for %d s, in step '%s' for %d s" % [int(silent / 1000.0), _phase, int((Time.get_ticks_msec() - _phase_since_msec) / 1000.0)])


func _cut() -> void:
	_file.close()
	var lines: PackedStringArray = FileAccess.get_file_as_string(_path).split("\n")
	var kept: PackedStringArray = lines.slice(maxi(lines.size() - 600, 0))
	_file = FileAccess.open(_path, FileAccess.WRITE)
	_file.store_string("\n".join(kept))
	_file.flush()
	_lines = kept.size()


# Statistics of one ENet peer: round trip, packet loss, state.
static func peer_stats(enet_peer: ENetPacketPeer) -> String:
	if enet_peer == null:
		return "no peer"

	return "rtt %d ms (last %d), loss %d, state %d, loss variance %d" % [
		int(enet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)), int(enet_peer.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME)),
		int(enet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)), enet_peer.get_state(), int(enet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS_VARIANCE))
	]


# Traffic of an ENet host: packets and bytes sent and received so far (the reader subtracts lines to get a rate).
static func host_stats(multiplayer_peer: MultiplayerPeer) -> String:
	var enet: ENetMultiplayerPeer = multiplayer_peer as ENetMultiplayerPeer

	if enet == null or enet.host == null:
		return "no host"

	return "in the last second: sent %d pkts %d KB, received %d pkts %d KB" % [
		int(enet.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS)), int(enet.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / 1024.0),
		int(enet.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS)), int(enet.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA) / 1024.0)
	]
