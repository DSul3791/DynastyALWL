extends Node

const SelfTimeoutScript := preload("res://src/shared/self_timeout.gd")

# A protocol-only player for load tests (tools/bots.sh): joins the server, walks, asks for ground, digs now and then, and prints
# how the server treated it (heartbeat gaps, how long blocks took to arrive). No world, no rendering; the node is named Main with a
# TerrainNet child like the real client so the RPC paths match. Blocks come by RPC here (the real client also has the block line).
#   --server=HOST --port=N --name=NAME --seconds=S --dig-every=SECONDS (0 = never)

const NetScript := preload("res://src/stream/terrain_net.gd")
const NetSettings := preload("res://src/shared/net_settings.gd")
const BLOCK_M := 16.0

var _net
var _host: String = "127.0.0.1"
var _port: int = 24600
var _name: String = "bot"
var _seconds: float = 60.0
var _dig_every: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _position: Vector3 = Vector3.ZERO
var _heading: float = 0.0
var _heading_until: float = 0.0
var _joined_msec: int = 0
var _started_msec: int = 0
var _welcome_msec: int = 0
var _last_pulse_msec: int = 0
var _pulses: int = 0
var _worst_gap_ms: int = 0
var _gaps_over_500: int = 0
var _asked: Dictionary = {}          # block key -> msec asked
var _latencies: Array = []
var _blocks: int = 0
var _bytes: int = 0
var _last_block: Vector3i = Vector3i(1 << 20, 0, 0)
var _next_report_msec: int = 0
var _next_dig_msec: int = 0
var _done: bool = false


func _ready() -> void:
	SelfTimeoutScript.install(self, OS.get_cmdline_user_args())   # testing only: --timeout=S / --watch-parent=PID, no flag = no limit
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--server="):
			_host = argument.trim_prefix("--server=")
		elif argument.begins_with("--port="):
			_port = int(argument.trim_prefix("--port="))
		elif argument.begins_with("--name="):
			_name = argument.trim_prefix("--name=")
		elif argument.begins_with("--seconds="):
			_seconds = float(argument.trim_prefix("--seconds="))
		elif argument.begins_with("--dig-every="):
			_dig_every = float(argument.trim_prefix("--dig-every="))

	_rng.seed = hash(_name)
	_net = $TerrainNet
	_net.welcome_received.connect(_on_welcome)
	_net.blocks_received.connect(_on_blocks)
	_net.pulse_received.connect(_on_pulse)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

	if peer.create_client(_host, _port) != OK:
		print("BOT %s: cannot connect" % _name)
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func():
		NetSettings.apply(peer.get_peer(1))
		_net.hello.rpc_id(1, "bot_" + _name))
	multiplayer.server_disconnected.connect(func():
		print("BOT %s: server left" % _name)
		_finish())
	_started_msec = Time.get_ticks_msec()


func _on_welcome(info: Dictionary) -> void:
	_welcome_msec = Time.get_ticks_msec()
	_joined_msec = _welcome_msec
	_position = Vector3(info.get("spawn", Vector3.ZERO)) + Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-6.0, 6.0))
	_next_dig_msec = _welcome_msec + int(_dig_every * 1000.0) if _dig_every > 0.0 else 0


func _on_pulse() -> void:
	var now: int = Time.get_ticks_msec()

	if _last_pulse_msec > 0:
		var gap: int = now - _last_pulse_msec
		_worst_gap_ms = maxi(_worst_gap_ms, gap)
		_gaps_over_500 += 1 if gap > 500 else 0

	_last_pulse_msec = now
	_pulses += 1


func _on_blocks(keys: PackedInt32Array, payloads: Array) -> void:
	var now: int = Time.get_ticks_msec()

	for n in range(payloads.size()):
		var key: Vector4i = Vector4i(keys[4 * n], keys[4 * n + 1], keys[4 * n + 2], keys[4 * n + 3])
		_blocks += 1
		_bytes += (payloads[n] as PackedByteArray).size()

		if _asked.has(key):
			_latencies.append(now - int(_asked[key]))
			_asked.erase(key)


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_msec()

	if _welcome_msec == 0:
		if now - _started_msec > 60000:
			print("BOT %s: no welcome in 60 s" % _name)
			_finish()

		return

	if float(now - _joined_msec) * 0.001 >= _seconds:
		_finish()
		return

	var t: float = float(now - _joined_msec) * 0.001

	if t >= _heading_until:
		_heading = _rng.randf() * TAU
		_heading_until = t + _rng.randf_range(5.0, 15.0)

	_position += Vector3(cos(_heading), 0.0, sin(_heading)) * 3.2 * delta
	var block: Vector3i = Vector3i(int(floor(_position.x / BLOCK_M)), int(floor(_position.y / BLOCK_M)), int(floor(_position.z / BLOCK_M)))

	if block != _last_block:
		_last_block = block
		_ask_around(block, now)

	if now >= _next_report_msec:
		_next_report_msec = now + 200
		_net.report_position.rpc_id(1, _position, Vector3(cos(_heading), 0.0, sin(_heading)) * 3.2)

	if _next_dig_msec > 0 and now >= _next_dig_msec:
		_next_dig_msec = now + int(_dig_every * 1000.0)
		_net.inventory_action.rpc_id(1, NetScript.ACT_DIG, 0, 0, 0, _position + Vector3(1.0, -1.0, 0.0))


func _ask_around(block: Vector3i, now: int) -> void:
	var keys: PackedInt32Array = PackedInt32Array()

	for dz in range(-2, 3):
		for dx in range(-2, 3):
			for dy in range(-1, 2):
				var key: Vector4i = Vector4i(block.x + dx, block.y + dy, block.z + dz, 0)

				if not _asked.has(key):
					_asked[key] = now
					keys.append_array(PackedInt32Array([key.x, key.y, key.z, 0]))

	if not keys.is_empty():
		_net.request_blocks.rpc_id(1, keys, mini(9, keys.size() / 4))


func _finish() -> void:
	if _done:
		return

	_done = true
	_latencies.sort()
	var count: int = _latencies.size()
	var median: int = int(_latencies[count / 2]) if count > 0 else -1
	var p95: int = int(_latencies[mini(int(count * 0.95), count - 1)]) if count > 0 else -1
	print("BOT %s: welcome %d ms after start; pulses %d, worst heartbeat gap %d ms, gaps over 500 ms %d; blocks %d (%d KB), asked %d, still unanswered %d, block wait median %d ms p95 %d ms worst %d ms" % [
		_name, _welcome_msec - _started_msec, _pulses, _worst_gap_ms, _gaps_over_500, _blocks, int(_bytes / 1024.0), _blocks + _asked.size(), _asked.size(), median, p95, int(_latencies[count - 1]) if count > 0 else -1])
	get_tree().quit(0)
