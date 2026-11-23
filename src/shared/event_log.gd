extends RefCounted

# A small own log file (user://<name>) that is flushed line by line, for finding why a game or server stops: connection
# events, main-thread stalls, peer statistics. It is cut back to its last lines when it grows, and a new run starts it afresh.
# The lines are written on a worker (LineWriter): a flush on the main thread stalled the client 200 to 500 ms (lag while running, 21 Nov 2026).

const LineWriterScript := preload("res://src/shared/line_writer.gd")

var _writer = LineWriterScript.new()
var _last_tick_msec: int = 0
var _next_state_msec: int = 0
var _max_gap_msec: int = 0
var _phase: String = ""                 # what the main thread is in (mark()), read by the watchdog thread
var _phase_since_msec: int = 0
var _phase_max: Dictionary = {}         # phase -> longest ms this second
var _watchdog: Thread
var _stop: bool = false
# Load tests (server --profile=S, tools/load_test.sh): every S seconds a PROFILE line with each step's total and longest time in
# microseconds since the last line, so a load test can say which step grows with players. 0 = off (no extra clock reads).
var profile_every_msec: int = 0
var profile_frame_phase: String = ""  # the step each frame starts with: a frame is counted (and the line written) when it comes round
var _profile_sum: Dictionary = {}       # phase -> usec this window
var _profile_max: Dictionary = {}       # phase -> longest usec this window
var _profile_frames: int = 0
var _profile_since_usec: int = 0
var _phase_since_usec: int = 0


# The file goes into the project's crash_reports folder (the one the game is played from, so it shows up in GitHub Desktop),
# or `folder` (a dedicated server's store); user:// when that folder cannot be written.
func start(name: String, folder: String = "res://crash_reports") -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if not _writer.open(folder + "/" + name, 1200, 600):
		_writer.open("user://" + name, 1200, 600)


func event(text: String) -> void:
	var t: Dictionary = Time.get_time_dict_from_system()
	var line: String = "[%02d:%02d:%02d.%03d] %s" % [t["hour"], t["minute"], t["second"], Time.get_ticks_msec() % 1000, text]
	_writer.add(line)

	if profile_every_msec > 0:
		print("TELEMETRY ", line)   # load tests read the whole run from the output; the file keeps only its last lines


# Writes the queued lines now (before something reads the file, or the process ends).
func drain() -> void:
	_writer.drain()


# Writes what is queued, waits for the writer's last worker task and closes the file; later lines are dropped. The last call of a
# node's _exit_tree: a line logged after it (a peer that drops as the network closes, during engine teardown) would otherwise start a
# worker task while the engine shuts its worker pool down, and a task still running when the log is freed (main gate, 21 Nov 2026: the
# dedicated server exited 132 after a clean stop in 3 of 8 stops on Lane B).
func close() -> void:
	_writer.close()


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

	if profile_every_msec > 0:
		_profile_mark(phase)

	_phase = phase
	_phase_since_msec = now


func _profile_mark(phase: String) -> void:
	var now: int = Time.get_ticks_usec()

	if _phase != "" and _phase_since_usec > 0:
		var used: int = now - _phase_since_usec
		_profile_sum[_phase] = int(_profile_sum.get(_phase, 0)) + used
		_profile_max[_phase] = maxi(int(_profile_max.get(_phase, 0)), used)

	_phase_since_usec = now

	if _profile_since_usec == 0:
		_profile_since_usec = now
	elif phase == profile_frame_phase:
		_profile_frames += 1

		if now - _profile_since_usec >= profile_every_msec * 1000:
			var parts: PackedStringArray = PackedStringArray()

			for name in _profile_sum:
				parts.append("%s=%d/%d" % [name, int(_profile_sum[name]), int(_profile_max[name])])

			event("PROFILE window_us=%d frames=%d | %s" % [now - _profile_since_usec, _profile_frames, " ; ".join(parts)])
			_profile_sum.clear()
			_profile_max.clear()
			_profile_frames = 0
			_profile_since_usec = now


func _slowest_phases() -> String:
	var parts: PackedStringArray = PackedStringArray()

	for phase in _phase_max:
		if int(_phase_max[phase]) >= 50:
			parts.append("%s %d" % [phase, int(_phase_max[phase])])

	return " (slow steps ms: %s)" % ", ".join(parts) if not parts.is_empty() else ""


# Optional, called on the watchdog thread (so it must be safe from any thread); its text ends each WATCHDOG line.
var watch_extra: Callable = Callable()


# A thread that writes a line each second while the main thread has not run for 3 s, naming the step it is stuck in.
func start_watchdog() -> void:
	_watchdog = Thread.new()
	_watchdog.start(_watch)


func stop_watchdog() -> void:
	_stop = true

	if _watchdog != null and _watchdog.is_started():
		_watchdog.wait_to_finish()

	_writer.drain()


func _watch() -> void:
	while not _stop:
		OS.delay_msec(1000)
		var silent: int = Time.get_ticks_msec() - _last_tick_msec

		if _last_tick_msec > 0 and silent > 3000:
			event("WATCHDOG: the main thread has been silent for %d s, in step '%s' for %d s%s" % [int(silent / 1000.0), _phase, int((Time.get_ticks_msec() - _phase_since_msec) / 1000.0),
				"; " + str(watch_extra.call()) if watch_extra.is_valid() else ""])


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
