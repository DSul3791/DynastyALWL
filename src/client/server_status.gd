extends RefCounted

# Asks one server for its status for the server pick page (docs/design/SERVER_PICK_PAGE.md "Status of each server"), without joining it:
# looks the name up in the background (a dynamic-DNS name is looked up fresh every time), opens the block line (game port + 1, TCP), sends a
# STATUS frame and reads the answer (block_link_server.gd KIND_STATUS). Call poll() every frame until done; never blocks the page.
#   state: "checking" | "online" | "no_details" (the line opened but the server sent no status: an older server) | "no_answer" | "not_found" | "bad_address"

const ServerList := preload("res://src/client/server_list.gd")
const KIND_STATUS := 2
const LIMIT_MSEC := 5000

var state: String = "checking"
var info: Dictionary = {}           # the server's own answer: name, message, build, stamped, protocol, players, max_players, locked
var ping_ms: int = -1
var ip: String = ""
var error: String = ""              # bad_address: the plain-words reason

var _host: String = ""
var _port: int = 0
var _lookup: int = -1
var _looking: bool = false
var _tcp: StreamPeerTCP = null
var _asked_msec: int = 0
var _started_msec: int = 0
var _sent: bool = false
var _reply: PackedByteArray = PackedByteArray()


func _init(address: String) -> void:
	_started_msec = Time.get_ticks_msec()
	var parsed: Dictionary = ServerList.normalise(address)

	if parsed.has("error"):
		state = "bad_address"
		error = str(parsed["error"])
		return

	_host = str(parsed["host"])
	_port = int(parsed["port"])
	_lookup = ServerList.lookup_start(_host)
	_looking = true


func done() -> bool:
	return state != "checking"


func poll() -> void:
	if done():
		return

	if Time.get_ticks_msec() - _started_msec > LIMIT_MSEC:
		_finish("no_details" if _sent else "no_answer")
		return

	if _looking:
		var found: Dictionary = ServerList.lookup_result(_host, _lookup)

		if found["state"] == "waiting":
			return

		_looking = false

		if found["state"] == "not_found":
			_finish("not_found")
			return

		ip = str(found["ip"])
		_tcp = StreamPeerTCP.new()

		if _tcp.connect_to_host(ip, _port + 1) != OK:
			_finish("no_answer")
			return

		_asked_msec = Time.get_ticks_msec()

	_tcp.poll()
	var status: int = _tcp.get_status()

	if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
		_finish("no_details" if _sent else "no_answer")
		return

	if status != StreamPeerTCP.STATUS_CONNECTED:
		return

	if not _sent:
		var frame: PackedByteArray = PackedByteArray()
		frame.resize(8)
		frame.encode_u32(0, 4)
		frame.encode_u32(4, KIND_STATUS)
		_tcp.put_data(frame)
		_sent = true

	var available: int = _tcp.get_available_bytes()

	if available > 0:
		_reply.append_array(_tcp.get_data(available)[1])

	if _reply.size() < 8 or _reply.size() < 4 + int(_reply.decode_u32(0)):
		return

	ping_ms = Time.get_ticks_msec() - _asked_msec
	var parsed: Variant = JSON.parse_string(_reply.slice(8, 4 + int(_reply.decode_u32(0))).get_string_from_utf8()) if _reply.decode_u32(4) == KIND_STATUS else null

	if parsed is Dictionary:
		info = parsed
		_finish("online")
	else:
		_finish("no_details")


func cancel() -> void:
	if not done():
		_finish("no_answer")


func _finish(new_state: String) -> void:
	state = new_state

	if _looking and _lookup >= 0:
		IP.erase_resolve_item(_lookup)

	_looking = false

	if _tcp != null:
		_tcp.disconnect_from_host()
		_tcp = null


# What the Status column says, and its colour group: "ok" (white/grey), "warn" (amber: up but not joinable now), "down" (red).
static func words(status, my_build: int, my_protocol: int) -> Array:
	match status.state:
		"checking":
			return ["Checking…", "ok"]
		"bad_address":
			return [status.error, "down"]
		"not_found":
			return ["Name not found: check the spelling", "down"]
		"no_answer":
			return ["No answer: may be down", "down"]
		"no_details":
			return ["Online (no details: an older server)", "ok"]

	var server_build: int = int(status.info.get("build", 0))
	var server_protocol: int = int(status.info.get("protocol", my_protocol))

	if bool(status.info.get("stamped", false)) and my_build > 0 and server_build != my_build:
		if server_build > my_build:
			return ["Needs update (server is %d, you have %d)" % [server_build, my_build], "warn"]

		return ["Server is older (%d): its owner must update it" % server_build, "warn"]

	if server_protocol != my_protocol:
		return ["Needs update (other game version)" if server_protocol > my_protocol else "Server is older: its owner must update it", "warn"]

	if int(status.info.get("max_players", 0)) > 0 and int(status.info.get("players", 0)) >= int(status.info.get("max_players", 0)):
		return ["Full", "warn"]

	return ["Online", "ok"]
