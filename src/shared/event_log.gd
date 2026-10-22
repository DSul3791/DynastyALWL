extends RefCounted

# A small own log file (user://<name>) that is flushed line by line, for finding why a game or server stops: connection
# events, main-thread stalls, peer statistics. It is cut back to its last lines when it grows, and a new run starts it afresh.

var _file: FileAccess
var _path: String
var _lines: int = 0
var _last_tick_msec: int = 0
var _next_state_msec: int = 0
var _max_gap_msec: int = 0


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
		event("max gap %d ms | %s" % [_max_gap_msec, String(state.call())])
		_max_gap_msec = 0


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
