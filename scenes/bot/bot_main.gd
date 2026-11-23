extends Node

const SelfTimeoutScript := preload("res://src/shared/self_timeout.gd")

# A protocol-only player for load tests (tools/bots.sh): joins the server, walks, asks for ground, digs now and then, and prints
# how the server treated it (heartbeat gaps, how long blocks took to arrive). No world, no rendering; the node is named Main with a
# TerrainNet child like the real client so the RPC paths match. Blocks come by RPC here (the real client also has the block line).
#   --server=HOST --port=N --name=NAME --seconds=S --dig-every=SECONDS (0 = never) --work
#   --spread=M --fight --build (server load tests, tools/load_test.sh, 23 Nov 2026):
#   --spread=M  the bot starts at a random spot up to M metres from the spawn (spread-out players make the server build more ground and flora)
#   --fight     with --work: it is given a spear and chases and strikes the nearest animal within 40 m (trees again when none is near)
#   --build     with --work: it is given a stone hammer, stone and clay and lays a Sturdy foundation blueprint beside itself every 20 s
# Many bots can share one process (scenes/bot/bot_swarm.gd): the swarm sets `preset_args` before the bot enters the tree and listens to
# `finished` instead of the bot quitting the process.
# --work (load tests, 22 Nov 2026): the bot works like an early player. It is given a wooden shovel, a stone axe and plant fibre (the
# server needs --open-admin), digs with the shovel in hand at the real ground height, queues twine crafts, asks for the trees around it,
# walks to the nearest and chops it with the axe, then the next. The final line adds how many digs, blows and crafts it sent.
# --probe-animals (Dave 23 Nov 2026, the real server: animals "teleporting and jumping right through us"; tools/animal_net_probe.sh): the
# bot draws the animals sent to it through the client's MotionBuffer and prints a PROBE line (src/worldgen/tools/animal_net_probe.gd).
#   --lag=MS,JITTER_MS,LOSS_PERCENT  its connection goes through an in-process relay with that delay, jitter and loss, both ways
#   --old-draw                       the drawing before protocol 154 (delay of one arrival gap + 0.15 s, a stand guessed from gaps, no smoothing)
#   --old-throttle                   ENet's default packet throttle (drops unreliable packets when the ping wobbles) on this connection
#   --stand-after=S                  stands still after S seconds (animals come near a still player)
#   --spawn=SP,SP                    (server with --open-admin) places one of each species 15 to 25 m away at the start

const NetScript := preload("res://src/stream/terrain_net.gd")
const NetSettings := preload("res://src/shared/net_settings.gd")
const BuildStamp := preload("res://src/shared/build_stamp.gd")
const ServerAuthScript := preload("res://src/shared/server_auth.gd")
const BLOCK_M := 16.0
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const FLORA_CHUNK_M := 256.0      # flora_placer chunk_m (no rules override)
const CRAFT_EVERY_MS := 30000
const TWINE_RECIPE := 1           # Twine: 3 plant fibre, by hand
const ProbeScript := preload("res://src/worldgen/tools/animal_net_probe.gd")
const FOUNDATION_BLUEPRINT := 4   # Sturdy - Foundation: 16 stone, 2 clay, a hammer (data/items/blueprints.json)
const BUILD_EVERY_MS := 20000
const PREY_REACH_M := 40.0
const STRIKE_EVERY_MS := 900

signal finished(lines: PackedStringArray)

var preset_args: PackedStringArray = PackedStringArray()   # the swarm's arguments for this bot; empty = the command line
var in_swarm: bool = false

var _net
var _host: String = "127.0.0.1"
var _auth = null
var _password: String = ""
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
var _work: bool = false
var _table = null
var _inv = null
var _ground_y: float = NAN
var _surface_asked_msec: int = 0
var _trees: Array = []               # [chunk, id, position] of tall flora near the bot (the server says whether each is a tree)
var _tried: Dictionary = {}          # "cx,cz,id" -> true: chopped or given up
var _target: Array = []
var _target_since_msec: int = 0
var _flora_chunk: Vector2i = Vector2i(1 << 20, 0)
var _next_hit_msec: int = 0
var _next_craft_msec: int = 0
var _gave: bool = false
var _digs: int = 0
var _hits: int = 0
var _crafts: int = 0
var _probe = null                    # --probe-animals: ProbeScript.Probe
var _relay = null                    # --lag: ProbeScript.Relay
var _old_throttle: bool = false
var _stand_after: float = -1.0
var _spawn: PackedStringArray = PackedStringArray()
var _spread: float = 0.0
var _fight: bool = false
var _build: bool = false
var _animals: Array = []             # the server's last animal rows near the bot
var _prey: Array = []                # [id, position] chased now
var _next_strike_msec: int = 0
var _next_build_msec: int = 0
var _strikes: int = 0
var _builds: int = 0
var _animals_heard: int = 0


func _ready() -> void:
	SelfTimeoutScript.install(self, OS.get_cmdline_user_args())   # testing only: --timeout=S / --watch-parent=PID, no flag = no limit
	for argument in (preset_args if not preset_args.is_empty() else OS.get_cmdline_user_args()):
		if argument.begins_with("--server="):
			_host = argument.trim_prefix("--server=")
		elif argument.begins_with("--port="):
			_port = int(argument.trim_prefix("--port="))
		elif argument.begins_with("--name="):
			_name = argument.trim_prefix("--name=")
		elif argument.begins_with("--seconds="):
			_seconds = float(argument.trim_prefix("--seconds="))
		elif argument.begins_with("--password="):
			_password = argument.trim_prefix("--password=")
		elif argument.begins_with("--dig-every="):
			_dig_every = float(argument.trim_prefix("--dig-every="))
		elif argument == "--work":
			_work = true
		elif argument == "--probe-animals":
			_probe = ProbeScript.Probe.new()
		elif argument == "--old-draw":
			_probe = _probe if _probe != null else ProbeScript.Probe.new()
			_probe.old_draw = true
		elif argument == "--old-throttle":
			_old_throttle = true
		elif argument.begins_with("--stand-after="):
			_stand_after = float(argument.trim_prefix("--stand-after="))
		elif argument.begins_with("--spawn="):
			_spawn = argument.trim_prefix("--spawn=").split(",", false)
		elif argument.begins_with("--lag="):
			var parts: PackedStringArray = argument.trim_prefix("--lag=").split(",")
			_relay = ProbeScript.Relay.new()
			_relay.lag_ms = int(parts[0])
			_relay.jitter_ms = int(parts[1]) if parts.size() > 1 else 0
			_relay.loss = float(parts[2]) / 100.0 if parts.size() > 2 else 0.0
		elif argument.begins_with("--spread="):
			_spread = float(argument.trim_prefix("--spread="))
		elif argument == "--fight":
			_fight = true
		elif argument == "--build":
			_build = true

	_rng.seed = hash(_name)
	_net = $TerrainNet
	_net.welcome_received.connect(_on_welcome)
	_net.blocks_received.connect(_on_blocks)
	_net.pulse_received.connect(_on_pulse)

	if _probe != null:
		_net.animals_received.connect(_probe.on_rows)

	if _work:
		_table = ItemTableScript.load_default()
		_inv = InventoryScript.pack(_table)
		_net.inventory_full_received.connect(func(bytes: PackedByteArray) -> void: _inv.from_bytes(bytes))
		_net.inventory_slots_received.connect(_on_slots)
		_net.surface_received.connect(_on_surface)
		_net.flora_received.connect(_on_flora)
		_net.animals_received.connect(func(rows: Array, _server_ms: int) -> void:
			_animals = rows
			_animals_heard += 1)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	# Every server runs the join handshake (server_auth.gd); --password= answers a server that has one, once.
	_auth = ServerAuthScript.new()
	_auth.password_needed.connect(func(_left: int, wrong: bool) -> void:
		if wrong or _password == "":
			print("BOT %s: the server wants a password%s" % [_name, " (wrong)" if wrong else ""])
			_finish()
		else:
			_auth.submit(_password))
	_auth.refused.connect(func(reason: String) -> void:
		print("BOT %s: password refused (%s)" % [_name, reason])
		_finish())
	_auth.attach_client(multiplayer as SceneMultiplayer)
	multiplayer.peer_authentication_failed.connect(func(_peer: int) -> void:
		print("BOT %s: the join handshake failed (%s)" % [_name, "dropped" if _auth.heard else "the server never answered it: another build?"])
		_finish())

	var host: String = _host
	var port: int = _port

	if _relay != null:
		Engine.max_fps = 250   # the relay is polled each frame: 4 ms is its finest step
		port = _port + 1000 + _rng.randi_range(0, 400)

		if not _relay.start(port, _host, _port):
			print("BOT %s: cannot start the lag relay on %d" % [_name, port])
			get_tree().quit(1)
			return

		host = "127.0.0.1"

	if peer.create_client(host, port) != OK:
		print("BOT %s: cannot connect" % _name)
		_finish()
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func():
		NetSettings.apply(peer.get_peer(1))

		if _old_throttle:
			peer.get_peer(1).throttle_configure(5000, 2, 2)   # ENet's defaults; ENet tells the server's end too
		_net.hello.rpc_id(1, "loadbot_" + _name, BuildStamp.stamped_build())   # 8 to 64 characters (server_items _valid_key): "bot_b1" was refused, so no bot was ever a player
		_net.my_look.rpc_id(1, "Bot " + _name, "", ""))   # protocol 151: players see a bot as a plain body with its name
	multiplayer.server_disconnected.connect(func():
		print("BOT %s: server left" % _name)
		_finish())
	_started_msec = Time.get_ticks_msec()


func _on_welcome(info: Dictionary) -> void:
	_welcome_msec = Time.get_ticks_msec()
	_joined_msec = _welcome_msec
	_position = Vector3(info.get("spawn", Vector3.ZERO)) + Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-6.0, 6.0))

	if _spread > 0.0:
		var angle: float = _rng.randf() * TAU
		var away: float = sqrt(_rng.randf()) * _spread   # even over the disc
		_position += Vector3(cos(angle), 0.0, sin(angle)) * away

	if _old_throttle:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1).throttle_configure(5000, 2, 2)   # again, after the server set its own

	for sp in _spawn:
		var bearing: float = _rng.randf() * TAU
		_net.admin_place.rpc_id(1, "animal", _position + Vector3(cos(bearing), 0.0, sin(bearing)) * _rng.randf_range(15.0, 25.0), sp)
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

	if _relay != null:
		_relay.poll()

	if _probe != null:
		_probe.tick(delta)

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

	if _work:
		_work_step(now)

	var goal: Variant = _prey[1] if not _prey.is_empty() else (_target[2] if not _target.is_empty() else null)

	if goal != null:
		var to: Vector3 = Vector3(goal) - _position
		to.y = 0.0
		_heading = atan2(to.z, to.x)
		_heading_until = t + 1.0

	var near_tree: bool = goal != null and Vector2(_position.x - goal.x, _position.z - goal.z).length() < (1.5 if not _prey.is_empty() else 2.0)
	near_tree = near_tree or (_stand_after >= 0.0 and t >= _stand_after)   # --stand-after: still from then on
	_position += Vector3.ZERO if near_tree else Vector3(cos(_heading), 0.0, sin(_heading)) * 3.2 * delta
	var block: Vector3i = Vector3i(int(floor(_position.x / BLOCK_M)), int(floor(_position.y / BLOCK_M)), int(floor(_position.z / BLOCK_M)))

	if block != _last_block:
		_last_block = block
		_ask_around(block, now)

	if now >= _next_report_msec:
		_next_report_msec = now + 200
		_net.report_position.rpc_id(1, _position, Vector3(cos(_heading), 0.0, sin(_heading)) * 3.2, atan2(-cos(_heading), -sin(_heading)))   # protocol 151: facing as rotation.y (forward is -Z)

	if _next_dig_msec > 0 and now >= _next_dig_msec:
		_next_dig_msec = now + int(_dig_every * 1000.0)

		if not _work:
			_net.inventory_action.rpc_id(1, NetScript.ACT_DIG, 0, 0, 0, _position + Vector3(1.0, -1.0, 0.0))
		elif not is_nan(_ground_y) and _slot_of("wooden_shovel") >= 0:
			_net.inventory_action.rpc_id(1, NetScript.ACT_DIG, _slot_of("wooden_shovel"), 0, 0, Vector3(_position.x + 1.0, _ground_y - 0.2, _position.z))
			_digs += 1


# --work: gifts once, the ground height every 2 s, the trees of the flora chunk it is in, chopping the nearest, crafts every 30 s.
func _work_step(now: int) -> void:
	if not _gave and now - _welcome_msec > 2000:
		_gave = true

		var gifts: Array = [["wooden_shovel", 1], ["stone_axe", 1], ["plant_fibre", 100], ["plant_fibre", 100]]
		gifts += [["spear", 1]] if _fight else []
		gifts += [["stone_hammer", 1], ["stone", 100], ["stone", 100], ["clay", 20]] if _build else []

		for row in gifts:
			_net.inventory_action.rpc_id(1, NetScript.ACT_ADMIN_GIVE, _table.number_of(row[0]), 0, row[1], Vector3.ZERO)

		_next_craft_msec = now + 3000
		_next_build_msec = now + 5000 + _rng.randi_range(0, BUILD_EVERY_MS)

	if now - _surface_asked_msec > 2000:
		_surface_asked_msec = now
		_net.request_surface.rpc_id(1, _position.x, _position.z)

	var chunk: Vector2i = Vector2i(floori(_position.x / FLORA_CHUNK_M), floori(_position.z / FLORA_CHUNK_M))

	if chunk != _flora_chunk:
		_flora_chunk = chunk
		_net.request_flora.rpc_id(1, PackedInt32Array([chunk.x, chunk.y, 1]))   # the full list, as a real client asks for the chunk it stands in

	if _next_craft_msec > 0 and now >= _next_craft_msec:
		_next_craft_msec = now + CRAFT_EVERY_MS
		_net.inventory_action.rpc_id(1, NetScript.ACT_CRAFT_QUEUE, TWINE_RECIPE, 0, 5, Vector3.ZERO)
		_crafts += 5

	if _target.is_empty() or now - _target_since_msec > 40000:
		if not _target.is_empty():
			_tried["%d,%d,%d" % [_target[0].x, _target[0].y, _target[1]]] = true

		_target = _nearest_tree()
		_target_since_msec = now

	if _fight:
		_fight_step(now)

	if _build and now >= _next_build_msec and not is_nan(_ground_y):
		_next_build_msec = now + BUILD_EVERY_MS
		_net.inventory_action.rpc_id(1, NetScript.ACT_PLACE_BLUEPRINT, FOUNDATION_BLUEPRINT, 0, 0, Vector3(_position.x + 3.0, _ground_y, _position.z))
		_builds += 1

	if not _prey.is_empty():
		return   # chasing an animal: no axe blows meanwhile

	if not _target.is_empty() and now >= _next_hit_msec and _slot_of("stone_axe") >= 0:
		var flat: float = Vector2(_position.x - _target[2].x, _position.z - _target[2].z).length()

		if flat < 3.0:
			_next_hit_msec = now + 600
			_net.inventory_action.rpc_id(1, NetScript.ACT_HIT, _target[1], _target[0].x, _target[0].y, Vector3(float(_slot_of("stone_axe") + 1), 0.0, 0.0))
			_hits += 1


# --fight: the nearest animal the server reported within PREY_REACH_M is chased; within 2.2 m the spear strikes it every STRIKE_EVERY_MS.
func _fight_step(now: int) -> void:
	_prey = []
	var best_d: float = PREY_REACH_M

	for row in _animals:
		if row.size() < 3:
			continue

		var at: Vector3 = row[2]
		var d: float = Vector2(_position.x - at.x, _position.z - at.z).length()

		if d < best_d:
			best_d = d
			_prey = [int(row[0]), at]

	if _prey.is_empty() or best_d > 2.2 or now < _next_strike_msec or _slot_of("spear") < 0:
		return

	_next_strike_msec = now + STRIKE_EVERY_MS
	var eye: Vector3 = _position + Vector3(0.0, 1.4, 0.0)
	_net.inventory_action.rpc_id(1, NetScript.ACT_STRIKE, _slot_of("spear"), 0, 0, (Vector3(_prey[1]) + Vector3(0.0, 0.5, 0.0) - eye).normalized())
	_strikes += 1


func _nearest_tree() -> Array:
	var best: Array = []
	var best_d: float = 80.0

	for tree in _trees:
		if _tried.has("%d,%d,%d" % [tree[0].x, tree[0].y, tree[1]]):
			continue

		var d: float = Vector2(_position.x - tree[2].x, _position.z - tree[2].z).length()

		if d < best_d:
			best_d = d
			best = tree

	return best


func _slot_of(id: String) -> int:
	return _inv.numbers.find(_table.number_of(id)) if _inv != null else -1


func _on_slots(bytes: PackedByteArray) -> void:
	var n: int = mini(bytes[0], floori(float(bytes.size() - 1) / 9.0)) if not bytes.is_empty() else 0

	for k in n:
		var at: int = 1 + k * 9

		if bytes[at] < _inv.slot_count:
			_inv.numbers[bytes[at]] = bytes.decode_u32(at + 1)
			_inv.counts[bytes[at]] = bytes.decode_u16(at + 5)


func _on_surface(x: float, z: float, y: float) -> void:
	if absf(x - _position.x) < 8.0 and absf(z - _position.z) < 8.0:
		_ground_y = y
		_position.y = y + 0.9   # reported as a walking player is: the standing body's middle, half of stance.gd's 1.8 m above the feet (Dave 23 Nov 2026: the other players' view drew the bot half underground when it sent its feet)


# Tall items of a chunk (over 5 m) are taken as trees; a blow on anything else the server refuses, and the bot moves on after 40 s.
func _on_flora(chunk: Vector2i, bytes: PackedByteArray, _water: PackedByteArray, _full: bool) -> void:
	var items: Dictionary = PlacerScript.decode(bytes, Vector2(chunk) * FLORA_CHUNK_M)
	_trees = []

	for n in items["ids"].size():
		if float(items["heights"][n]) > 5.0:
			_trees.append([chunk, int(items["ids"][n]), items["positions"][n]])

	_target = []


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
	var lines: PackedStringArray = PackedStringArray()
	_latencies.sort()
	var count: int = _latencies.size()
	var median: int = int(_latencies[count / 2]) if count > 0 else -1
	var p95: int = int(_latencies[mini(int(count * 0.95), count - 1)]) if count > 0 else -1
	lines.append("BOT %s: welcome %d ms after start; pulses %d, worst heartbeat gap %d ms, gaps over 500 ms %d; blocks %d (%d KB), asked %d, still unanswered %d, block wait median %d ms p95 %d ms worst %d ms" % [
		_name, _welcome_msec - _started_msec, _pulses, _worst_gap_ms, _gaps_over_500, _blocks, int(_bytes / 1024.0), _blocks + _asked.size(), _asked.size(), median, p95, int(_latencies[count - 1]) if count > 0 else -1])

	if _probe != null:
		print("%s (%s)" % [_probe.summary(), _name])

	if _relay != null:
		print("RELAY %s: lag %d ms, jitter %d ms, loss %.0f%%: passed %d packets, dropped %d" % [_name, _relay.lag_ms, _relay.jitter_ms, _relay.loss * 100.0, _relay.passed, _relay.dropped])

	if _work:
		lines.append("BOT %s: work sent: digs %d, axe blows %d, twine crafts %d, spear strikes %d, blueprints %d; trees seen %d, given up %d; animal updates %d; pack %s" % [
			_name, _digs, _hits, _crafts, _strikes, _builds, _trees.size(), _tried.size(), _animals_heard, _pack_summary()])

	for line in lines:
		print(line)

	finished.emit(lines)
	_quit(1 if _welcome_msec == 0 else 0)   # 1: it never joined (no connection, refused, no welcome)


func _quit(code: int) -> void:
	if in_swarm:
		set_process(false)
		multiplayer.multiplayer_peer = null   # leave the server; the swarm frees the bot
	else:
		get_tree().quit(code)


func _pack_summary() -> String:
	var parts: PackedStringArray = PackedStringArray()

	for slot in _inv.slot_count:
		if _inv.numbers[slot] != 0:
			parts.append("%s x%d" % [_table.id_of(_inv.numbers[slot]), _inv.counts[slot]])

	return ", ".join(parts)
