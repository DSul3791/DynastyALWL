extends Node

# Terrain server (plan step 16): answers clients' block requests from the
# edits store, the generated-block cache or the runtime generator.
#
#   godot --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=24600
#
# Options (after "--"):
#   --port=N        UDP port (default 24600)
#   --world=DIR     world folder (default res://worlds/base_world)
#   --clear-generated  throw away the generated ground at start (edits are kept);
#                     while running, creating the file clear_generated.now in the
#                     store folder does the same
#   --store=DIR     server store folder (default user://server_store/<world name>)
#   --threads=N     worker threads making blocks (default: processor count - 1)
#   --quit-after=S  stop after S seconds (headless checks)
#   --quit-when-empty  stop 10 s after the last player leaves, or after 5 min
#                      if nobody joins (the "play" launcher's own server)
#
# Clients start at the starter spawn point of tile (3,4).

const EventLogScript := preload("res://src/shared/event_log.gd")
const GitStamp := preload("res://src/debug/git_stamp.gd")
const BuildInfo := preload("res://src/shared/build.gd")
const RUN_NOTE := "user://server_run.json"      # which server holds the port (read by the launcher)
const WATER_CHUNKS_MAX := 64              # flora chunks answered per water request
const GATHER_MIN_MSEC := 100              # a peer's gather requests are handled at most this often
const GATHER_REACH_M := 12.0              # a gather request for a chunk further than this from the player is ignored
const NetSettings := preload("res://src/shared/net_settings.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const SwimScript := preload("res://src/shared/swim.gd")
const NpcsScript := preload("res://src/stream/server_npcs.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const TrailsScript := preload("res://src/stream/server_trails.gd")
const IdentityScript := preload("res://src/stream/identity_provider.gd")
const AdminScript := preload("res://src/stream/server_admin.gd")
const DialogueScript := preload("res://src/stream/server_dialogue.gd")
const TradeScript := preload("res://src/stream/server_trade.gd")
const StoreScript := preload("res://src/stream/server_block_store.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TreeSupport := preload("res://src/shared/tree_support.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const NetScript := preload("res://src/stream/terrain_net.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const ActionLimitsScript := preload("res://src/shared/action_limits.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const FloraStoreScript := preload("res://src/stream/server_flora.gd")
const WaterHubScript := preload("res://src/water/water_hub.gd")
const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const BlockLinkScript := preload("res://src/stream/block_link_server.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const TunnelWatchScript := preload("res://src/stream/tunnel_watch.gd")

const MAX_BATCH_BYTES := 192 * 1024
const MAX_QUEUE_PER_PEER := 20000
const KEY_BURST := 8000                # block keys one peer may ask for at once; it refills KEY_REFILL_PER_S a second (one peer flooding must not fill the queue)
const KEY_REFILL_PER_S := 4000.0
const WeatherScript := preload("res://src/shared/weather.gd")
const IceScript := preload("res://src/shared/ice.gd")
const WEATHER_SWELL := 1.0              # a big storm makes every spring run this much stronger (x2 in all: the x10 start flow becomes x20; Dave 2026-10-20)
const DRY_SHRINK := 0.7                 # full dry heat takes this share off the spring flow (a trickle is left); the floor below
const RUNOFF_FLOOR := 0.2               # rivers never shrink below this share of the start flow
const WEATHER_LAG_S := 600.0            # real seconds the rivers take to follow the weather (about ten minutes to swell, as long to recede)
const WATER_BASE_RATE := 10.0           # m3 per second at each spring (about 158,000 US gallons a minute); the + and - keys scale it
const IDLE_LODS := 4                   # detail levels the idle builder keeps ahead of players
const IDLE_RADIUS_BLOCKS := 12         # circle around each player, in blocks of that level
const IDLE_MAX_DONE := 400000          # remembered built blocks (skips re-checking the store)

var generator
var store
var flora
var trails                             # ServerTrails: worn game trails the animals leave
var animals                            # ServerAnimals: wildlife around the players (rabbits)
var _animal_sent: Dictionary = {}
var _send_round: int = 0
var identity = IdentityScript.new()      # who a peer is (src/stream/identity_provider.gd): the swap point for real logins
var items                              # ServerItems: inventories and world items
var npcs                               # ServerNpcs: classic NPCs (protocol 45)
var admin                              # ServerAdmin: who may place markers and NPCs
var dialogue                           # ServerDialogue: talking to NPCs
var trade                              # ServerTrade: shops (coins)
var _npc_sent_ms: Dictionary = {}
var _animal_sent_ms: Dictionary = {}
var _npc_sent: Dictionary = {}         # peer -> signature of the NPC rows last sent
var _npc_send_t: float = 0.0
var _pulse_t: float = 0.0
var _water_updates: int = 0
var weather: Dictionary = {}           # the weather at the water tile now (WeatherScript.state), refreshed every second
var _weather_next_msec: int = 0
var _blood_sent: Dictionary = {}       # peer -> hash of the blood trail last sent
var _swell: float = 0.0
var _dry: float = 0.0
var _weather_bucket: int = -1
var _water_seen: Dictionary = {}        # tile -> msec a player was last in it (the live water set keeps a tile WATER_KEEP_MS after)
var _water_live_next: int = 0
var _water_live_last: Array = []
var _centre_levels: PackedFloat32Array = PackedFloat32Array()   # the centre tile's last drawn levels (only read for the log line)
var _wet_centre: int = 0               # wet squares on the starter tile at the last update (the log line)
var tunnels = TunnelWatchScript.new()     # tunnel grace timers, shaking and collapse (data/tunnels.json, off until the bracing items exist)
var water_live                         # the starter tile's running water, tuned with + and - on the client
var _world_dir: String = ""
var _bake_running: bool = false        # a tile bake is writing the tile files (store.baking)
var settings
var spawn: Vector3 = Vector3.ZERO
var net
var _queue: Array = []                 # urgent [peer, key Vector4i], oldest first
var _prefetch: Array = []              # prefetch [peer, key], oldest first
var _queued: Dictionary = {}           # [peer, key] -> "u" urgent, "p" prefetch, "r" running
var _flora_queue: Array = []           # [peer, chunk Vector2i, full (false: trees only)], oldest first
var _key_budget: Dictionary = {}       # peer -> [keys left, msec of the last refill] (queue mutex)
var _water_queue: Array = []           # [peer, chunk Vector2i] water to pack on a worker thread (never on the main thread), oldest first
var _water_done: Array = []            # [peer, chunk, bytes] packed, waiting to be sent by the main thread
var _flora_queued: Dictionary = {}     # [peer, chunk, full] -> true
var _queue_mutex: Mutex = Mutex.new()  # guards the five above
var _work: Semaphore = Semaphore.new() # one post per queued item
var _workers: Array = []               # Threads making blocks
var _stopping: bool = false
var _link = null                     # direct block line (block_link_server.gd); its port is the game port + 1
var _link_port: int = 0
var _connected_peers: Dictionary = {} # peer id -> true, read by the block line's thread (queue mutex)
var _max_running: int = 3
var _done: Array = []                  # [peer, key, bytes]
var _done_mutex: Mutex = Mutex.new()
var _peers: Dictionary = {}            # peer -> {"blocks": n, "bytes": n}
var _quit_at_msec: int = -1
var _quit_when_empty: bool = false
var _empty_since_msec: int = 0
var _quit_grace_msec: int = 10000
var _never_joined: bool = true
var _water_answered_msec: Dictionary = {}   # peer -> last time its water request was answered
var _gather_msec: Dictionary = {}           # peer -> last gather request handled
const BURY_QUEUE_MAX := 4000        # digs waiting for the plant check; beyond it a dig skips the check
var _bury_mutex: Mutex = Mutex.new()
var _bury_queue: Array = []         # [center, radius] of digs and fills not yet checked for plants
var _bury_out: Array = []           # [chunk, id] of plants removed, waiting to be announced
var _bury_thread: Thread = null     # the flora thread (started at the first job)
var _bury_sem: Semaphore = Semaphore.new()
var _bury_stop: bool = false
var _bury_dropped: int = 0
var _warm_home: Dictionary = {}     # peer -> the flora chunk last warmed around it
var _refused_seen: int = 0              # ops.rejected when a refusal was last told to a player
var limits = ActionLimitsScript.new()      # per-peer token buckets (data/limits.json); drops show in the telemetry line
var _fill_last: Array = []                  # [centre, radius, material] of the last fill that changed something; a repeat is dropped
var _tiles_changed: Dictionary = {}     # tiles edited since the clients were told (tile_changed goes out at most every 0.5 s)
var _tiles_told_msec: int = 0
var _events = EventLogScript.new()      # user://server_events.log: peers, stalls, quit reason (why a client was dropped)
var _report_at_msec: int = 0
var _idle_threads: int = 2             # idle builder threads (--idle-threads=N, 0 turns it off)
var _idle_workers: Array = []
var _idle_offsets: Array = []          # [lod, dx, dz] nearest first, same for every player
var _idle_anchor: Dictionary = {}      # peer -> Vector3i LOD 0 block the player is at
var _idle_done: Dictionary = {}        # Vector4i -> true, built or found saved
var _idle_built: int = 0
var _aim: Dictionary = {}              # peer -> Vector2 ground point to make first (metres), from reported position and speed


var _clear_generated_at_start: bool = false
var _flag_check_msec: int = 0
var _store_path: String = ""
var game_clock = GameClockScript.new()   # the one game clock; advances only while the server runs
var _clock_saved_msec: int = 0


func _ready() -> void:
	net = $TerrainNet
	var port: int = 24600
	var world_dir: String = "res://worlds/base_world"
	var store_dir: String = ""
	_max_running = maxi(OS.get_processor_count() - 1, 1)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument == "--clear-generated":
			_clear_generated_at_start = true
		elif argument.begins_with("--store="):
			store_dir = argument.trim_prefix("--store=")
		elif argument.begins_with("--threads="):
			_max_running = maxi(int(argument.trim_prefix("--threads=")), 1)
		elif argument.begins_with("--idle-threads="):
			_idle_threads = maxi(int(argument.trim_prefix("--idle-threads=")), 0)
		elif argument == "--quit-when-empty":
			_quit_when_empty = true
		elif argument.begins_with("--quit-after="):
			_quit_at_msec = Time.get_ticks_msec() + int(float(argument.trim_prefix("--quit-after=")) * 1000.0)

	var errors: Array = []
	settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or rules.is_empty() or not errors.is_empty():
		push_error("Terrain server: %s" % "\n".join(errors))
		get_tree().quit(1)
		return

	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	store = StoreScript.new()
	store.settle_enabled = int(NetSettings.value("settled_ground", 1)) != 0

	if store_dir == "":
		store_dir = "user://server_store/%s" % settings.world_name.validate_filename()

	_store_path = store_dir
	_load_game_clock()
	var problem: String = store.setup(generator, store_dir)

	if _clear_generated_at_start:
		store.clear_generated()
		print("server: cleared the generated ground as asked (--clear-generated)")

	if problem != "":
		push_error("Terrain server: %s" % problem)
		get_tree().quit(1)
		return

	_start_tunnels()
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	flora = FloraStoreScript.new()
	flora.setup(placer, store_dir)
	items = ItemsScript.new()
	@warning_ignore("confusable_local_declaration")
	items.send_full = func(peer, bytes): net.inventory_full.rpc_id(peer, bytes)
	@warning_ignore("confusable_local_declaration")
	items.send_slots = func(peer, bytes): net.inventory_slots.rpc_id(peer, bytes)
	@warning_ignore("confusable_local_declaration")
	items.send_purse = func(peer, copper): net.purse.rpc_id(peer, copper)
	@warning_ignore("confusable_local_declaration")
	items.send_carry = func(peer, item_id): net.carry.rpc_id(peer, item_id)
	@warning_ignore("confusable_local_declaration")
	items.send_reputation = func(peer, ids, names, points): net.reputation.rpc_id(peer, ids, names, points)
	@warning_ignore("confusable_local_declaration")
	items.send_received = func(peer, item_id, count, source): net.item_gain.rpc_id(peer, item_id, count, source)
	@warning_ignore("confusable_local_declaration")
	items.send_world_items = func(peer, added, removed): net.world_items.rpc_id(peer, added, removed)
	items.dig_ground = _dig_ground
	tunnels.support_strength = items.support_strength_at      # bracing holds a tunnel up (called from the watch's own thread; the support list is mutex-guarded)
	items.support_changed = func(at: Vector3) -> void: tunnels.support_changed(at, Time.get_ticks_msec())
	items.dig_refusal = _dig_refusal
	items.fill_ground = _fill_ground
	items.ground_height = func(x, z): return generator.surface_height(x, z)
	items.ground_ready = func(x, z) -> bool:
		if generator.tile_cached(x, z):
			return true

		generator.prefetch_tile(x, z)
		return false
	items.world_seed = int(settings.master_seed)
	items.rain_now = func(): return float(weather.get("rain", 0.0))
	items.cover_at = _cover_at
	items.roof_add = func(roof): return flora.add_roof(roof)
	items.roof_remove = func(key): flora.remove_roof(key)
	items.register_roofs()
	items.tree_info = _tree_info
	items.standing_near = _standing_near
	items.flora_changed = _flora_changed
	flora.dynamic = func(home): return items.dynamic_items(home)
	items.cut_tree = _cut_tree
	@warning_ignore("confusable_local_declaration")
	items.send_notice = func(peer, text): net.notice.rpc_id(peer, text)
	@warning_ignore("confusable_local_declaration")
	items.send_breath = func(peer, tenths): net.breath.rpc_id(peer, tenths)
	@warning_ignore("confusable_local_declaration")
	items.send_energy = func(peer, percent): net.energy.rpc_id(peer, percent)
	@warning_ignore("confusable_local_declaration")
	items.send_warmth = func(peer, percent): net.warmth.rpc_id(peer, percent)
	@warning_ignore("confusable_local_declaration")
	items.send_sick = func(peer, hours): net.sick.rpc_id(peer, hours)
	@warning_ignore("confusable_local_declaration")
	items.send_body = func(peer, bpm, eta, phase): net.body.rpc_id(peer, bpm, eta, phase)
	@warning_ignore("confusable_local_declaration")
	items.send_limp = func(peer, percent): net.limp.rpc_id(peer, percent)
	items.ice_cover_at = func(pos): return IceScript.cover(game_clock.seconds, settings.get_zone_group_for_row(int(floor(pos.z / float(settings.tile_size_m)))), maxf(pos.y, 0.0), 3.0)
	@warning_ignore("confusable_local_declaration")
	items.send_worn = func(peer, numbers): net.worn.rpc_id(peer, numbers)
	@warning_ignore("confusable_local_declaration")
	items.send_remains = func(peer, rows): net.remains_marks.rpc_id(peer, rows)
	@warning_ignore("confusable_local_declaration")
	items.send_thought = func(peer, line_id, text, kind): net.thought.rpc_id(peer, line_id, text, kind)
	@warning_ignore("confusable_local_declaration")
	items.send_skills = func(peer, attributes, rows): net.skills.rpc_id(peer, attributes, rows)
	items.weather_now = func(): return weather
	@warning_ignore("confusable_local_declaration")
	items.send_died = func(peer, cause, point): net.died.rpc_id(peer, cause, point)
	@warning_ignore("confusable_local_declaration")
	items.send_vitals = func(peer, hunger, health, weight, thirst, luck, fitness): net.vitals.rpc_id(peer, hunger, health, weight, thirst, luck, fitness)
	items.water_near = func(pos, reach):
		var tile_data = generator.get_tile(generator.tile_of(pos.x, pos.z))

		if tile_data.placeholder:
			return false

		for offset in [Vector2.ZERO, Vector2(reach, 0.0), Vector2(-reach, 0.0), Vector2(0.0, reach), Vector2(0.0, -reach)]:
			var k: int = tile_data.nearest(pos.x + offset.x, pos.z + offset.y)

			if not tile_data.sim_levels.is_empty():
				if not is_nan(tile_data.sim_levels[k]):
					return true
			elif tile_data.water_class[k] > 1 and not is_nan(tile_data.water_surface[k]):
				return true

		return false
	items.water_depth_at = func(pos: Vector3) -> float:
		var water: Array = _water_at(pos)
		return 0.0 if is_nan(water[0]) else maxf(float(water[0]) - float(water[1]), 0.0)
	@warning_ignore("confusable_local_declaration")
	items.send_reject = func(peer, reason): net.reject.rpc_id(peer, reason)
	@warning_ignore("confusable_local_declaration")
	items.send_craft_queue = func(peer, entries, left_ms): net.craft_queue.rpc_id(peer, entries, left_ms)
	@warning_ignore("confusable_local_declaration")
	items.send_strain = func(peer, strain_pm, state, fade_pm, stance): net.strain.rpc_id(peer, strain_pm, state, fade_pm, stance)
	@warning_ignore("confusable_local_declaration")
	items.send_chest = func(peer, id, bytes): net.chest_contents.rpc_id(peer, id, bytes)
	items.game_seconds = func(): return game_clock.seconds
	items.season_now = func(): return game_clock.season()
	items.season_stamp = func(): return game_clock.year() * 4 + game_clock.season_index()
	items.rock_at = func(x, z):
		var tile_data = generator.get_tile(generator.tile_of(x, z))

		if tile_data.placeholder:
			return false

		var h: float = float(generator.surface_height(x, z))
		return generator._surface_material(tile_data, x, z, h) >= Layout.MATERIAL_ROCK
	var soil_names: Dictionary = {}

	for entry in tables.get_entries("soils"):
		soil_names[int(entry["id"])] = str(entry["name"])

	items.ground_material = func(x, z):
		var tile_data = generator.get_tile(generator.tile_of(x, z))

		if tile_data.placeholder:
			return "rock"

		var material: int = generator._surface_material(tile_data, x, z, float(generator.surface_height(x, z)))
		return "rock" if material >= Layout.MATERIAL_ROCK else str(soil_names.get(material, "loam"))
	items.trees_near = _trees_near
	items.dig_support = func(base, radius, depth): return TreeSupport.solid_share(store.ops.edits_near(base, radius + depth), base, radius, depth)
	items.setup(ItemTableScript.load_default(), store_dir)
	admin = AdminScript.new()
	admin.load_keys(["res://data/admin.json", store_dir + "/admin.json"])
	items.reset_terrain_edits = _reset_terrain_edits
	items.floor_below = _floor_below
	items.dump_water = _dump_water
	@warning_ignore("confusable_local_declaration")
	items.admin_ok = func(peer: int) -> bool: return admin.is_admin(items.key_of(peer))
	admin.open_to_all = OS.get_cmdline_user_args().has("--open-admin")
	npcs = NpcsScript.new()
	npcs.hour_now = func(): return game_clock.hour()
	npcs.ground_height = func(x, z): return generator.surface_height(x, z)
	npcs.blocked = func(x, z):
		var water: Array = _water_at(Vector3(x, 0.0, z))
		return not is_nan(water[0]) and float(water[0]) - float(water[1]) > 0.7
	npcs.player_positions = func(): return items.peer_positions()
	npcs.rain_now = func(): return float(weather.get("rain", 0.0))
	npcs.setup(store_dir)
	animals = AnimalsScript.new()
	animals.ground_height = npcs.ground_height
	animals.blocked = npcs.blocked
	animals.water_level = func(x, z):
		var water_here: Array = _water_at(Vector3(x, 0.0, z))
		return float(water_here[0]) if not is_nan(water_here[0]) else NAN
	animals.player_positions = npcs.player_positions
	animals.player_stances = func(): return items.peer_stances()
	animals.wind = func(): return weather
	animals.canopy = func(point): return flora.covered(point)
	animals.setup()
	trails = TrailsScript.new()
	trails.game_seconds = func(): return game_clock.seconds
	trails.setup(store_dir)
	animals.trails = trails
	animals.wolves.player_info = func(): return items.wolf_info()
	animals.wolves.fires = func(): return items._lit_fires()
	@warning_ignore("confusable_local_declaration")
	animals.wolves.hurt_player = func(peer, amount, lethal, cause): return items.hurt_player(peer, amount, lethal, cause, float(animals.cfg.get("wolves", {}).get("maim_hp", 25.0)))
	@warning_ignore("confusable_local_declaration")
	animals.wolves.notice = func(peer, text): items._say(peer, text)
	@warning_ignore("confusable_local_declaration")
	animals.wolves.take_meat = func(peer): return items.take_all_meat(peer)
	animals.big_game.player_info = func(): return items.wolf_info()
	animals.thieves.loose_food = func(centre, r): return items.loose_food_near(centre, r)
	animals.thieves.take_food = func(id): return items.take_loose(id)
	animals.thieves.fires = func(): return animals.wolves.fires.call() if animals.wolves.fires.is_valid() else []
	animals.drop_loot = func(number, count, pos): items.drop_in_world(number, count, pos)
	@warning_ignore("confusable_local_declaration")
	animals.big_game.hurt_player = func(peer, amount, lethal, cause): return items.hurt_player(peer, amount, lethal, cause, 10.0)
	@warning_ignore("confusable_local_declaration")
	animals.died = func(sp, pos, peer): items.make_carcass(sp, pos, peer)
	@warning_ignore("confusable_local_declaration")
	items.hit_animal = func(peer, origin, dir, reach, amount) -> bool:
		var target: int = animals.target_along(origin, dir, reach)
		return target != 0 and (animals.damage(target, amount, peer, "spear") or true)
	dialogue = DialogueScript.new()
	dialogue.items = items
	dialogue.npcs = npcs
	trade = TradeScript.new()
	trade.items = items
	trade.npcs = npcs
	trade.game_seconds = func(): return game_clock.seconds
	trade.setup(store_dir)
	@warning_ignore("confusable_local_declaration")
	trade.send_shop = func(peer, npc_id, title, ids, pay, got, buys, tired_ids, tired, stock, supply_milli, purse): net.shop.rpc_id(peer, npc_id, title, ids, pay, got, buys, tired_ids, tired, stock, supply_milli, purse)
	dialogue.trade = trade
	@warning_ignore("confusable_local_declaration")
	net.trade_requested.connect(func(peer, npc_id, kind, a, count):
		var said: String = trade.deal(peer, npc_id, kind, a, count)

		if said != "":
			items._say(peer, said)
			trade.open(peer, npc_id))   # the window is sent again with the new demand
	items.npc_name = func(id): return str(npcs.npcs.get(id, {}).get("name", id))
	dialogue.hour_now = func(): return game_clock.hour()
	@warning_ignore("confusable_local_declaration")
	dialogue.send_say = func(peer, id, npc_name, text, voice, choices, ends): net.npc_say.rpc_id(peer, id, npc_name, text, voice, choices, ends)
	dialogue.setup(store_dir)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--npc-ai="):
			dialogue.router.mode = arg.substr(9)   # auto, static, ai or down (pretend the AI is dead: NPCs are unwell)

	spawn = _spawn_point(world_dir)
	items.respawn_point = spawn
	_world_dir = world_dir
	_start_water()

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = peer.create_server(port, 32)

	if error != OK:
		push_error("Terrain server: cannot listen on port %d (%s)" % [port, error_string(error)])
		_events.start("telemetry_server_failed.log")
		_events.event("cannot listen on port %d (%s): another server may still be running on it" % [port, error_string(error)])
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = peer
	_events.start("telemetry_server_%d.log" % port)
	_events.start_watchdog()
	_events.event("server listening on port %d after %d ms of start-up, %s, ram %d MB, commit %s" % [port, Time.get_ticks_msec(), OS.get_name(), int(OS.get_static_memory_usage() / 1048576.0), GitStamp.short_commit()])
	_run_note("running", port)
	# Build the flora of the spawn's chunk once here, before any other thread exists. Start-up
	# crash (owner thread bug, build 204): about 1 start in 10 to 20 a worker thread died in the
	# flora placer (flora_placer.gd patch_at, signal 11) right after the first client connected,
	# when several workers made their first flora chunk at the same moment. Not reproduced here
	# in 90 starts; this makes the first call of every placer function happen on one thread.
	flora.chunk_bytes(Vector2i(int(floor(spawn.x / placer.chunk_m)), int(floor(spawn.z / placer.chunk_m))), true)
	flora.chunk_bytes(Vector2i(int(floor(spawn.x / placer.chunk_m)) + 1, int(floor(spawn.z / placer.chunk_m))), false)
	_link = BlockLinkScript.new()
	_link.on_request = _on_blocks_requested
	_link.is_peer = _is_connected_peer
	_link_port = _link.start(port + 1)

	if _link_port == 0:
		print("Terrain server: no block line (port %d is taken); blocks go over the game connection" % (port + 1))

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	net.blocks_requested.connect(_on_blocks_requested)
	net.dig_requested.connect(_on_dig_requested)
	net.flora_requested.connect(_on_flora_requested)
	net.cut_flora_requested.connect(_on_cut_flora_requested)
	net.position_reported.connect(_on_position_reported)
	net.water_rate_requested.connect(_on_water_rate_requested)
	net.water_requested.connect(_on_water_requested)
	@warning_ignore("confusable_local_declaration")
	net.hello_requested.connect(func(peer, key):
		var account: String = identity.authenticate(peer, key)

		if account == "":
			return

		items.peer_connected_hello(peer, identity.store_key(account))
		net.npc_roster.rpc_id(peer, npcs.roster())
		var resume: Array = items.start_position_for(peer)

		if resume.size() == 3:
			net.start_at.rpc_id(peer, Vector3(float(resume[0]), float(resume[1]), float(resume[2]))))
	net.logout_requested.connect(func(leaving): items.note_logout(leaving))
	net.tunnel_setting_requested.connect(_on_tunnel_setting)
	net.admin_place_requested.connect(_on_admin_place)
	@warning_ignore("confusable_local_declaration")
	net.npc_talk_requested.connect(func(peer, npc_id, choice): dialogue.talk(peer, npc_id, choice))
	net.surface_requested.connect(_on_surface_requested)
	net.dump_requested.connect(_on_dump_requested)
	@warning_ignore("confusable_local_declaration")
	net.inventory_action_requested.connect(func(peer, kind, a, b, count, at): items.action(peer, kind, a, b, count, at))
	_report_at_msec = Time.get_ticks_msec() + 10000

	for n in range(_max_running):
		var thread: Thread = Thread.new()
		thread.start(_worker_loop)
		_workers.append(thread)

	if OS.has_environment("DYNASTY_IDLE_THREADS"):
		_idle_threads = maxi(int(OS.get_environment("DYNASTY_IDLE_THREADS")), 0)

	_make_idle_offsets()

	for n in range(_idle_threads):
		var idle: Thread = Thread.new()
		idle.start(_idle_loop)
		_idle_workers.append(idle)

	print("Terrain server listening on port %d with %d worker threads; store %s; spawn %s" % [port, _max_running, store_dir, str(spawn)])


# Owner (2026-10-19): spawn here (x, z in meters) instead of the baked spot at the bay
# head. Set to Vector2.ZERO to use the baked spot again.
# Moved 32 m north on 2026-10-21 (was z 68448): at the x10 flow that spot is on the pond A rim in
# 0.9 m of water; this one is on the flat 28.8 m bench, three squares from any water.
# Dave (2026-10-21 18:13) asked for exactly x 53301, z 68427, where he stood on grass by the lake (ground about 29.9 m).
# Before that he used x 53318, z 68473 as a temporary spawn. That is the pond A shore in about 0.9 m
# of water (you land just above it, the 6 s landing protection applies, deep or shallow water is a safe landing). The dry
# alternative, 12 m east on the 28.8 m shore bench, is Vector2(53330.0, 68466.0).
const SPAWN_OVERRIDE := Vector2(53301.0, 68427.0)


func _spawn_point(world_dir: String) -> Vector3:
	var path: String = world_dir + "/tiles/tile_3_4.tile"
	var point: Vector3 = Vector3(3.5, 0.0, 4.5) * float(settings.tile_size_m)
	var head: Dictionary = TileFileScript.read_header(path)

	if SPAWN_OVERRIDE != Vector2.ZERO:
		point = Vector3(SPAWN_OVERRIDE.x, 0.0, SPAWN_OVERRIDE.y)
	elif head["ok"]:
		var starter: Dictionary = TileFileScript.read_list(path, head["table"], "starter")

		if starter["ok"] and typeof(starter["value"]) == TYPE_DICTIONARY and starter["value"].has("spawn_point"):
			var s: Array = starter["value"]["spawn_point"]
			point = Vector3(float(s[0]), 0.0, float(s[2]))

	point.y = maxf(generator.surface_height(point.x, point.z), 0.0) + 2.0
	return point


# The server's state line for user://server_events.log; keeps each peer's last statistics for the "left" line.
func _event_state() -> String:
	var enet: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var parts: PackedStringArray = PackedStringArray()

	for peer_id in _peers:
		var stats: String = EventLogScript.peer_stats(enet.get_peer(peer_id)) if enet != null else "no enet"
		_peers[peer_id]["last_stats"] = stats
		parts.append("peer %d %s" % [peer_id, stats])

	_queue_mutex.lock()
	var queued: String = "queued urgent %d prefetch %d, in work %d" % [_queue.size(), _prefetch.size(), _queued.size()]
	_queue_mutex.unlock()
	var dropped: String = limits.summary()
	queued += ", limiter drops: " + dropped if dropped != "" else ""
	queued += ", " + store.settle.summary() + ", busiest block %d edits" % store.ops.busiest_block() if store.ops.count > 0 else ""
	queued += ", digs refused (block full): %d" % store.ops.rejected if store.ops.rejected > 0 else ""
	return "peers %d fps %d ram %d MB, %s, %s | %s" % [_peers.size(), Engine.get_frames_per_second(), int(OS.get_static_memory_usage() / 1048576.0), queued, EventLogScript.host_stats(multiplayer.multiplayer_peer), " | ".join(parts)]


func _on_peer_connected(peer_id: int) -> void:
	_never_joined = false
	NetSettings.apply((multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(peer_id))
	_peers[peer_id] = {"blocks": 0, "bytes": 0, "since": Time.get_ticks_msec()}
	_queue_mutex.lock()
	_connected_peers[peer_id] = true
	_queue_mutex.unlock()
	print("Client %d connected" % peer_id)
	_events.event("peer %d connected" % peer_id)
	net.welcome.rpc_id(peer_id, {
		"protocol": NetScript.PROTOCOL_VERSION,
		"server_build": BuildInfo.NUMBER,       # the build id: a client on another commit says so plainly (empty commit = unknown = match)
		"server_commit": GitStamp.short_commit(),
		"world_name": settings.world_name,
		"master_seed": settings.master_seed,
		"tile_size_m": settings.tile_size_m,
		"min_tile": settings.min_tile,
		"tiles_per_side": settings.tiles_x,
		"revisions": store.revisions(),
		"tunnels": {"on": tunnels.enabled, "cave_in_s": int(tunnels.cave_in_s)},
		"spawn": spawn,
		"terrain_version": Layout.TERRAIN_VERSION,
		"tiles_stamp": store.tiles_stamp,
		"starter_stamp": _starter_stamp(),
		"block_port": _link_port,
		"game_seconds": game_clock.seconds,
		"zones": settings.zones.map(func(zone): return [str(zone["group"]), int(zone["max_abs_row"])]),
		"equator_row": settings.equator_tile_row,
	})


# Starts the starter tile's running water on the tile as it is now loaded.
func _start_water() -> void:
	var water_tile: Vector2i = Vector2i(3, 4)
	var water_data = generator.get_tile(water_tile)

	if water_data.placeholder:
		return

	# Owner (2026-10-18): the world starts dry and the springs fill it, so the real water
	# paths show; --settled-water starts from the baked water file instead. The hub runs the starter
	# tile and the neighbours its rivers cross into (water/tile_X_Z.water per tile).
	var dry_start: bool = not OS.get_cmdline_user_args().has("--settled-water")
	water_live = WaterHubScript.new()
	water_live.setup(water_tile, "%s/water" % _world_dir, WATER_BASE_RATE, generator, dry_start)

	# Saved digs and fills shape the water's ground again after every restart and re-bake.
	for edit in store.ops.edits():
		if int(edit[0]) == store.ops.KIND_FILL:
			water_live.fill(edit[1], float(edit[2]))
		else:
			water_live.dig(edit[1], float(edit[2]))


# Which starter ground (shipped client cache) fits the tiles: terrain version and the spawn tile file.
func _starter_stamp() -> String:
	return "%d_%s" % [Layout.TERRAIN_VERSION, Layout.tile_stamp(generator.tiles_dir, Vector2i(3, 4))]


# Swimmer (deep water, feet well under the surface) and head-under (the breath runs down) come from a reported
# position by src/shared/swim.gd; the client swims by the same rules, the server decides the cost.
# [water surface (NAN if none), ground height] at a reported position: the sea at 0, or the simulated tile's water.
func _water_at(position: Vector3) -> Array:
	var ground: float = generator.surface_height(position.x, position.z)
	var surface: float = NAN

	if ground <= 0.0:
		surface = 0.0
	elif water_live != null:
		var tile_data = water_live.data_of(generator.tile_of(position.x, position.z))

		if tile_data != null and not tile_data.sim_levels.is_empty():
			surface = tile_data.sim_levels[tile_data.nearest(position.x, position.z)]

	return [surface, ground]


# Where the player will touch the ground: straight below if hovering, farther
# along their heading the higher and faster they are. Blocks nearest this
# point are made first.
func _on_position_reported(peer_id: int, position: Vector3, velocity: Vector3) -> void:
	var water: Array = _water_at(position)
	items.set_swimming(peer_id, SwimScript.swimming(position.y, water[0], water[1]))
	items.set_head_under(peer_id, SwimScript.head_under(position.y, water[0], water[1]))
	items.report_position(peer_id, position)
	generator.prefetch_around(position.x, position.z)
	_warm_flora(peer_id, position)
	var height: float = maxf(position.y - generator.surface_height(position.x, position.z), 0.0) if generator.tile_cached(position.x, position.z) else 0.0
	var descent: float = maxf(-velocity.y, 10.0)
	var seconds: float = minf(height / descent, 8.0)
	var point: Vector2 = Vector2(position.x + velocity.x * seconds, position.z + velocity.z * seconds)
	_queue_mutex.lock()
	_aim[peer_id] = point
	_queue_mutex.unlock()


func _is_connected_peer(peer_id: int) -> bool:
	_queue_mutex.lock()
	var known: bool = _connected_peers.has(peer_id)
	_queue_mutex.unlock()
	return known


func _on_peer_disconnected(peer_id: int) -> void:
	var info: Dictionary = _peers.get(peer_id, {})
	print("Client %d left after %d blocks, %.1f MB; flora %.1f MB" % [
		peer_id, int(info.get("blocks", 0)), float(info.get("bytes", 0)) / 1048576.0, float(info.get("flora_bytes", 0)) / 1048576.0
	])
	_events.event("peer %d left after %d blocks (last stats: %s)" % [peer_id, int(info.get("blocks", 0)), str(info.get("last_stats", "none"))])
	_peers.erase(peer_id)
	limits.forget(peer_id)
	_warm_home.erase(peer_id)
	_water_answered_msec.erase(peer_id)
	_gather_msec.erase(peer_id)
	_npc_sent.erase(peer_id)
	_animal_sent.erase(peer_id)
	trails.forget_peer(peer_id)
	_blood_sent.erase(peer_id)
	dialogue.peer_left(peer_id)
	items.peer_left(peer_id)

	if _link != null:
		_link.drop(peer_id)

	_queue_mutex.lock()
	_connected_peers.erase(peer_id)
	_idle_anchor.erase(peer_id)
	_aim.erase(peer_id)
	_queue = _queue.filter(func(item): return item[0] != peer_id)
	_prefetch = _prefetch.filter(func(item): return item[0] != peer_id)
	_flora_queue = _flora_queue.filter(func(item): return item[0] != peer_id)
	_water_queue = _water_queue.filter(func(item): return item[0] != peer_id)
	_key_budget.erase(peer_id)
	_queue_mutex.unlock()


# Urgent keys go before every prefetch key; a prefetch key asked for again
# as urgent moves up.
func _on_blocks_requested(peer_id: int, keys: PackedInt32Array, urgent: int) -> void:
	var added: int = 0
	var now: int = Time.get_ticks_msec()
	_queue_mutex.lock()
	var budget: Array = _key_budget.get(peer_id, [float(KEY_BURST), now])
	budget[0] = minf(float(KEY_BURST), float(budget[0]) + float(now - int(budget[1])) * 0.001 * KEY_REFILL_PER_S)
	budget[1] = now
	@warning_ignore("integer_division")
	var wanted: int = mini(keys.size() / 4, int(budget[0]))
	budget[0] = float(budget[0]) - float(wanted)
	_key_budget[peer_id] = budget

	for n in range(wanted):
		if _queue.size() + _prefetch.size() >= MAX_QUEUE_PER_PEER:
			break

		var key: Vector4i = Vector4i(keys[4 * n], keys[4 * n + 1], keys[4 * n + 2], clampi(keys[4 * n + 3], 0, 15))
		var id: Array = [peer_id, key]
		var state: String = _queued.get(id, "")

		if n < urgent:
			if key.w == 0:
				_idle_anchor[peer_id] = Vector3i(key.x, key.y, key.z)

			if state == "" or state == "p":
				_queued[id] = "u"
				_queue.append(id)
				added += 1
		elif state == "":
			_queued[id] = "p"
			_prefetch.append(id)
			added += 1

	_queue_mutex.unlock()

	for n in range(added):
		_work.post()


# Flora chunks wait behind urgent blocks and before prefetch blocks.
func _on_flora_requested(peer_id: int, chunks: PackedInt32Array) -> void:
	var added: int = 0
	_queue_mutex.lock()

	@warning_ignore("integer_division")
	for n in range(chunks.size() / 3):
		var id: Array = [peer_id, Vector2i(chunks[3 * n], chunks[3 * n + 1]), chunks[3 * n + 2] != 0]

		if _flora_queue.size() < MAX_QUEUE_PER_PEER and not _flora_queued.has(id):
			_flora_queued[id] = true
			_flora_queue.append(id)
			added += 1

	_queue_mutex.unlock()

	for n in range(added):
		_work.post()


func _on_water_rate_requested(_peer_id: int, direction: int) -> void:
	if water_live == null:
		return

	var rate: float = water_live.step_rate(direction)
	print("server: water flow rate now x%.2f" % rate)
	net.water_rate.rpc(rate, true, rate * WATER_BASE_RATE)


# Protocol 45: the ground height under a point (a client that stopped high up streams the ground below first).
# One dump a second per player (it generates a block).
var _dump_last: Dictionary = {}


func _on_dump_requested(peer_id: int, x: float, y: float, z: float) -> void:
	var now: int = Time.get_ticks_msec()

	if now - int(_dump_last.get(peer_id, -10000)) < 1000:
		return

	_dump_last[peer_id] = now
	net.dump_result.rpc_id(peer_id, store.dump_cell(x, y, z))


func _on_surface_requested(peer_id: int, x: float, z: float) -> void:
	net.surface.rpc_id(peer_id, x, z, float(generator.surface_height(x, z)))


func _on_water_requested(peer_id: int, chunks: PackedInt32Array) -> void:
	# One answer per peer per second and at most WATER_CHUNKS_MAX chunks in it: every answer costs main-thread time, and a client
	# (or a bug) asking over and over must not be able to keep the server busy.
	var now: int = Time.get_ticks_msec()

	if now - int(_water_answered_msec.get(peer_id, -100000)) < 1000:
		return

	_water_answered_msec[peer_id] = now
	@warning_ignore("integer_division")
	for n in range(mini(chunks.size() / 2, WATER_CHUNKS_MAX)):
		_queue_water(peer_id, Vector2i(chunks[2 * n], chunks[2 * n + 1]))


# Packing a chunk's water takes about 30 ms: ready ones go out at once, the rest are packed by a worker thread and sent
# from _process when done.
func _queue_water(peer_id: int, chunk: Vector2i) -> void:
	if flora.water_ready(chunk):
		net.deliver_water.rpc_id(peer_id, chunk, flora.water_bytes(chunk))
		return

	_queue_mutex.lock()
	var added: bool = _water_queue.size() < MAX_QUEUE_PER_PEER * maxi(1, _connected_peers.size())

	if added:
		_water_queue.append([peer_id, chunk])

	_queue_mutex.unlock()

	if added:
		_work.post()


# The weather over the starter tile (zone from its row, season and time from the game clock,
# town spirit a neutral placeholder until it exists) swells the rivers: rain feeds the springs,
# lagged because runoff takes time (snow just piles up).
func _update_weather() -> void:
	var now: int = Time.get_ticks_msec()

	if now < _weather_next_msec or water_live == null:
		return

	_weather_next_msec = now + 1000
	var row: int = 4
	var game_s: float = game_clock.seconds
	weather = WeatherScript.state(settings.master_seed, game_s, settings.get_zone_group_for_row(row), 0.0, 0.0)
	var bucket: int = int(float(weather["rain"]) * 4.0) + 10 * int(float(weather["snow"]) * 4.0)

	if bucket != _weather_bucket:
		_weather_bucket = bucket
		print("server: weather %s, rain %.2f snow %.2f storm %.2f, %.0f C, rivers x%.2f of the start flow" % [weather["season"], weather["rain"], weather["snow"], weather["storm"], weather["temp_c"], water_live.runoff])

	_swell += (WeatherScript.river_push(weather) - _swell) * (1.0 - exp(-1.0 / WEATHER_LAG_S))
	_dry += (WeatherScript.river_dry(weather) - _dry) * (1.0 - exp(-1.0 / WEATHER_LAG_S))
	water_live.set_runoff(maxf(1.0 + WEATHER_SWELL * _swell - DRY_SHRINK * _dry, RUNOFF_FLOOR))


# The water sim follows the players (tech/WATER_NINE_TILES_PLAN.md): the tiles they stand in, kept
# WATER_KEEP_MS after they leave, newest first; with nobody connected the starter tile keeps running.
const WATER_KEEP_MS := 120000


func _update_water_live() -> void:
	var now: int = Time.get_ticks_msec()

	if now < _water_live_next:
		return

	_water_live_next = now + 2000

	for position in items.peer_positions():
		_water_seen[generator.tile_of(position.x, position.z)] = now

	var tiles: Array = []

	for tile in _water_seen.keys():
		if now - int(_water_seen[tile]) > WATER_KEEP_MS:
			_water_seen.erase(tile)
		else:
			tiles.append(tile)

	tiles.sort_custom(func(a, b): return int(_water_seen[a]) > int(_water_seen[b]))

	if tiles.is_empty():
		tiles = [Vector2i(3, 4)]

	if tiles != _water_live_last:
		_water_live_last = tiles.duplicate()
		water_live.set_live(tiles)


# Wet squares of a tile's levels, counted on every 4th row and column (times 16): the log line only. Counting all of them
# in GDScript took about 250 ms of a server frame on every water update.
func _wet_squares(levels: PackedFloat32Array) -> int:
	var side: int = int(round(sqrt(float(levels.size()))))
	var count: int = 0

	for j in range(0, side, 4):
		for i in range(0, side, 4):
			if not is_nan(levels[j * side + i]):
				count += 1

	return count * 16


# New levels from the water thread: swap them into the tile and tell clients.
func _poll_water() -> void:
	if water_live == null:
		return

	_update_water_live()

	var updates: Array = water_live.take_updates()

	if not updates.is_empty():
		for update in updates:
			var tile_data = water_live.data_of(update[0])

			if tile_data == null:
				continue

			tile_data.sim_levels = update[1]
			tile_data.fall_levels = update[2]

			if update[0] == water_live.centre:
				_centre_levels = update[1]

		_water_updates += 1

		if _water_updates == 1 or _water_updates % 10 == 0:
			_wet_centre = _wet_squares(_centre_levels)
			print("server: water update %d (%d tiles), %d wet squares on the starter tile" % [_water_updates, updates.size(), _wet_centre])

		flora.clear_water()
		net.water_changed.rpc()

		if not water_live.busy:
			net.water_rate.rpc(water_live.rate, false, water_live.rate * WATER_BASE_RATE)


# Cover.at for a fire: makes sure the flora chunk of the spot (and the neighbours whose crowns
# reach into it) is in the server's cover index, then asks it.
func _cover_at(point: Vector3) -> float:
	var size: float = flora.placer.chunk_m
	var home: Vector2i = Vector2i(int(floor(point.x / size)), int(floor(point.z / size)))

	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			flora.chunk_bytes(home + Vector2i(dx, dz), false)

	return 1.0 if flora.covered(point) else 0.0


# A standing tree for the axe: {name, position, height, trunk}, or {} when there is none (cut already,
# not a tree, no such id). The last few chunks' items are kept so a run of blows works them out once.
func _tree_info(chunk: Vector2i, id: int) -> Dictionary:
	var home: Vector2i = flora.placer.normalize(chunk)

	var all: Dictionary = flora.items_of(home)
	var at: int = all["ids"].find(id)
	var species: Dictionary = flora.placer._by_id.get(id >> 16, {})

	if at < 0:
		return items.dynamic_tree_info(home, id)

	if species.is_empty() or int(species["kind"]) != PlacerScript.KIND_TREE or flora.removed_in(home).has(id):
		return {}

	return {"name": str(species["name"]), "position": all["positions"][at], "height": float(all["heights"][at]), "trunk": float(species["trunk"])}


func _cut_tree(chunk: Vector2i, id: int) -> bool:
	var home: Vector2i = flora.placer.normalize(chunk)

	if items.remove_dynamic(home, id):
		net.flora_cut.rpc(chunk, id)
		return true

	if not flora.cut(chunk, id):
		return false

	net.flora_cut.rpc(chunk, id)
	return true


# Standing placer trees whose root lies within `radius` (flat) of a point, as [chunk, id] (dig under trees, job 85).
func _trees_near(point: Vector3, radius: float) -> Array:
	var size: float = flora.placer.chunk_m
	var home: Vector2i = Vector2i(int(floor(point.x / size)), int(floor(point.z / size)))
	var found: Array = []

	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var chunk: Vector2i = flora.placer.normalize(home + Vector2i(dx, dz))
			var trees: Dictionary = flora.items_of(chunk, true)
			var gone: Array = flora.removed_in(chunk)

			for n in range(trees["ids"].size()):
				var species: Dictionary = flora.placer._by_id.get(trees["ids"][n] >> 16, {})

				if species.is_empty() or int(species["kind"]) != PlacerScript.KIND_TREE or gone.has(trees["ids"][n]):
					continue

				if Vector2(trees["positions"][n].x - point.x, trees["positions"][n].z - point.z).length() <= radius:
					found.append([chunk, trees["ids"][n]])

	return found


# The nearest standing tree of a species within `radius` of a point (placer trees only): [position] or [].
func _standing_near(species_name: String, point: Vector3, radius: float) -> Array:
	var size: float = flora.placer.chunk_m
	var home: Vector2i = Vector2i(int(floor(point.x / size)), int(floor(point.z / size)))
	var best: Array = []

	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var chunk: Vector2i = flora.placer.normalize(home + Vector2i(dx, dz))
			var trees: Dictionary = flora.items_of(chunk, true)
			var gone: Array = flora.removed_in(chunk)

			for n in range(trees["ids"].size()):
				var species: Dictionary = flora.placer._by_id.get(trees["ids"][n] >> 16, {})

				if species.is_empty() or str(species["name"]) != species_name or gone.has(trees["ids"][n]):
					continue

				var d: float = Vector2(trees["positions"][n].x - point.x, trees["positions"][n].z - point.z).length()

				if d <= radius and (best.is_empty() or d < best[0]):
					best = [d, trees["positions"][n]]

	return [] if best.is_empty() else [best[1]]


# Saplings or grown trees of a chunk changed: drop the packed copy, refill the cover index and
# send the chunk again to the players near it.
func _flora_changed(chunk: Vector2i) -> void:
	flora.invalidate(chunk)
	flora.chunk_bytes(chunk, false)
	var origin: Vector2 = flora.placer.chunk_origin(chunk)
	var centre: Vector3 = Vector3(origin.x + flora.placer.chunk_m * 0.5, 0.0, origin.y + flora.placer.chunk_m * 0.5)

	for peer in items.peers_near(centre, 600.0):
		var water_cached: bool = flora.water_ready(chunk)
		net.deliver_flora.rpc_id(peer, chunk, flora.chunk_bytes(chunk, true), flora.water_bytes(chunk) if water_cached else PackedByteArray(), true)
		_send_stripped(peer, chunk)

		if not water_cached:
			_queue_water(peer, chunk)


# The plants of a chunk that are bare this season, for a client that just got the chunk (berry picking keeps the bush standing).
func _send_stripped(peer: int, chunk: Vector2i) -> void:
	var home: Vector2i = flora.placer.normalize(chunk)
	var ids: PackedInt32Array = items.stripped_ids("%d,%d" % [home.x, home.y])

	if not ids.is_empty():
		net.flora_stripped.rpc_id(peer, chunk, ids)


func _on_cut_flora_requested(peer_id: int, chunk: Vector2i, id: int) -> void:
	# Gathering (E): a plant or shrub is picked: it gives what drops.json and its season allow and then rests.
	# Trees are felled, not gathered (tree-fall comes later).
	var tick: int = Time.get_ticks_msec()

	if tick - int(_gather_msec.get(peer_id, -100000)) < GATHER_MIN_MSEC:
		return

	_gather_msec[peer_id] = tick
	var player_at: Variant = items.position_of(peer_id)
	var chunk_m: float = flora.placer.chunk_m

	if player_at == null:
		return

	# Nearest point of the chunk's square to the player: nothing is gathered, or generated, far away.
	var near_x: float = clampf((player_at as Vector3).x, float(chunk.x) * chunk_m, float(chunk.x + 1) * chunk_m)
	var near_z: float = clampf((player_at as Vector3).z, float(chunk.y) * chunk_m, float(chunk.y + 1) * chunk_m)

	if Vector2((player_at as Vector3).x - near_x, (player_at as Vector3).z - near_z).length() > GATHER_REACH_M:
		return

	var home: Vector2i = flora.placer.normalize(chunk)
	var all: Dictionary = flora.items_of(home)
	var at: int = all["ids"].find(id)
	var species: Dictionary = flora.placer._by_id.get(id >> 16, {})

	if at < 0 or species.is_empty() or int(species["kind"]) == PlacerScript.KIND_TREE:
		return

	# Dave 2026-10-20: a picked plant disappears from the world, like a picked stone. Only a pick that gave
	# something removes it (server_items.gd); one that gave nothing leaves the plant alone.
	var key: String = "%d,%d,%d" % [home.x, home.y, id]

	# A plant picked bare before this rule (still in the saved "picked" list) goes now, giving nothing.
	var gave: bool = items.was_picked(key) or items.gather(peer_id, str(species["name"]), PlacerScript.KINDS[int(species["kind"])], key, id, all["positions"][at], float(all["heights"][at]))

	if gave and items.plant_stays:
		net.flora_stripped.rpc(chunk, PackedInt32Array([id]))      # a berry bush: it stays, bare until the season changes
	elif gave and flora.cut(chunk, id):
		net.flora_cut.rpc(chunk, id)


func _on_dig_requested(peer_id: int, center: Vector3, radius: float) -> void:
	if not admin.is_admin(items.key_of(peer_id)):
		print("Admin dig refused for peer %d" % peer_id)
		return

	if not limits.allow(peer_id, "dig"):
		return

	_dig_ground(center, radius)


# The first edit after a quiet half second is announced at once; edits that follow within it are announced together when it ends
# (_process), each announcement making every client forget what it fetched ahead and ask again.
func _tell_tile_changed(tile: Vector2i) -> void:
	var now: int = Time.get_ticks_msec()

	if now - _tiles_told_msec >= 500 and _tiles_changed.is_empty():
		_tiles_told_msec = now
		net.tile_changed.rpc(tile, store.revision_of(tile))
	else:
		_tiles_changed[tile] = true


# Why the dig that just changed nothing did so: the spot's blocks hold the most edits they replay, or the hole is already there.
func _dig_refusal() -> String:
	if store.ops.rejected != _refused_seen:
		_refused_seen = store.ops.rejected
		return "This ground is dug over too much to dig any further here."

	return "The ground there is already open."


# Tunnel watch (tunnel_watch.gd, tech/EXCAVATION_BRACING_GROUND_DESIGN.md): measures dug blocks on its own thread; the main
# thread only sends the shaking messages and applies a collapse (rubble fills, victims). Does nothing while data/tunnels.json says off.
func _start_tunnels() -> void:
	var path: String = "res://data/tunnels.json"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	var merged: Dictionary = (data as Dictionary).duplicate() if typeof(data) == TYPE_DICTIONARY else {}
	var saved_path: String = _store_path + "/tunnel_settings.json"      # the in-game switch (Esc > Settings, admin) wins over data/tunnels.json

	if FileAccess.file_exists(saved_path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(saved_path))

		if typeof(saved) == TYPE_DICTIONARY:
			merged["enabled"] = bool(saved.get("on", merged.get("enabled", false)))
			merged["collapse"] = merged["enabled"]
			merged["cave_in_s"] = float(saved.get("cave_in_s", merged.get("cave_in_s", 1200.0)))

	tunnels.configure(merged)
	tunnels.load_natural = func(block: Vector3i) -> VoxelBuffer:
		var buffer: VoxelBuffer = Layout.make_buffer(16)
		store.load_natural(buffer, block)
		return buffer
	tunnels.load_block = func(block: Vector3i) -> VoxelBuffer:
		var buffer: VoxelBuffer = Layout.make_buffer(16)
		store.load_block(buffer, block, 0)
		return buffer
	tunnels.water_above = func(x: float, z: float) -> float:      # the sea is 0 m; a river or lake is its live level (read on the watch's own thread)
		return float(_water_at(Vector3(x, 0.0, z))[0])
	tunnels.surface_h = func(x: float, z: float) -> float: return generator.surface_height(x, z)
	tunnels.start()


# Writes the live water cells in a 40 m box around (x, z) to <store>/water_dump_X_Z.txt (outside the repo): per 8 m cell the baked ground, the
# sim ground, depth, drawn level and the flow across its faces, plus the sim's totals. For the dry-river hunt (Dave 2026-10-23).
# Triggered by an admin (Esc > Admin > Dump water here) or by a file water_dump.now in the store holding "x z".
func _dump_water(x: float, z: float) -> String:
	var tile: Vector2i = generator.tile_of(x, z)
	var data = water_live.data_of(tile) if water_live != null else null
	var sim = water_live.sim_of(tile) if water_live != null else null

	if data == null or sim == null:
		return "no running water sim for the tile at %d, %d" % [int(x), int(z)]

	var lines: PackedStringArray = PackedStringArray()
	lines.append("water dump at x %.1f z %.1f, tile %s, sim side %d spacing %.1f, data samples %d x0 %.1f z0 %.1f" % [x, z, str(tile), sim.side, sim.spacing_m, data.samples, data.x0, data.z0])
	lines.append("sim %s core, ticks %d, seconds %.0f, evaporated %.0f m3, to sea %.0f m3, flow key x%.2f, volume %.0f m3 in %d wet cells" % ["C++" if sim.native() else "GDScript", sim.ticks, sim.seconds, sim.evaporated_m3, sim.sea_m3, sim.spring_multiplier, sim.total_volume(), sim.wet_cells()])
	lines.append("cell i j | x z | baked_ground sim_ground depth level(sim_levels) | flow_x flow_z")
	var near_springs: Array = []

	for spring in sim.springs:
		var si: int = int(spring[0]) % sim.side
		@warning_ignore("integer_division")
		var sj: int = int(spring[0]) / sim.side
		var sx: float = data.x0 + float(si) * sim.spacing_m
		var sz: float = data.z0 + float(sj) * sim.spacing_m

		if absf(sx - x) <= 200.0 and absf(sz - z) <= 200.0:
			near_springs.append("spring cell %d,%d at x %.0f z %.0f: %.3f m3/s" % [si, sj, sx, sz, float(spring[1])])

	lines.append("springs within 200 m: %s" % (", ".join(PackedStringArray(near_springs)) if not near_springs.is_empty() else "none"))

	for j in range(maxi(int(floor((z - 20.0 - data.z0) / sim.spacing_m)), 0), mini(int(ceil((z + 20.0 - data.z0) / sim.spacing_m)), sim.side - 1) + 1):
		for i in range(maxi(int(floor((x - 20.0 - data.x0) / sim.spacing_m)), 0), mini(int(ceil((x + 20.0 - data.x0) / sim.spacing_m)), sim.side - 1) + 1):
			var n: int = j * sim.side + i
			var level: float = data.sim_levels[n] if n < data.sim_levels.size() else NAN
			# The C++ core keeps depth inside itself (sim.depth_at) and does not give the flows to GDScript: they print as nan.
			var flow_x: float = sim.flow_x[n] if n < sim.flow_x.size() else NAN
			var flow_z: float = sim.flow_z[n] if n < sim.flow_z.size() else NAN
			var ground_here: float = sim.ground[n] if n < sim.ground.size() else NAN
			lines.append("%d %d | %.0f %.0f | %.2f %.2f %.3f %.2f | %.3f %.3f" % [i, j, data.x0 + float(i) * sim.spacing_m, data.z0 + float(j) * sim.spacing_m, data.heights[n] if n < data.heights.size() else NAN, ground_here, sim.depth_at(n), level, flow_x, flow_z])

	var path: String = _store_path + "/water_dump_%d_%d.txt" % [int(x), int(z)]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return "cannot write " + path

	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("server: water dump written to ", path)
	return path


# Where a loose item let go at `from` comes to rest: straight down through the air to the first ground, by the generated surface with the
# saved digs and fills laid over it, in order (Dave 2026-10-23: mined soil and rocks hung in the air over the hole that was dug under them).
# Natural caves are not known to this probe (only the surface height and the edits are), so an item dropped inside a natural cave
# keeps its height. Returns the resting height, or NAN when there is no ground within 24 m below.
func _floor_below(from: Vector3) -> float:
	var edits: Array = store.ops.edits_near(Vector3(from.x, from.y - 12.0, from.z), 12.0)   # every edit touching the 24 m column, oldest first
	var surface: float = generator.surface_height(from.x, from.z)
	var y: float = from.y + 0.05

	for step in range(480):   # 0.05 m steps, 24 m
		var p: Vector3 = Vector3(from.x, y, from.z)
		var solid: bool = p.y < surface

		for op in edits:
			if p.distance_to(op[1]) <= float(op[2]):
				solid = int(op[0]) == 1

		if solid:
			return y + 0.05

		y -= 0.05

	return NAN


# Admin "Reset all terrain edits": every saved dig and fill (rubble included) is deleted, the ground and water are made again from the
# baked tiles, the tunnel clocks start clean and every player reloads. Buildings, items and plants are not touched.
func _reset_terrain_edits() -> void:
	var error: String = store.ops.reset()

	if error != "":
		print("server: reset of terrain edits failed: ", error)
		return

	store.clear_generated()
	flora.clear_memory()
	generator.forget_tiles()
	WaterGridScript.forget_ground()

	if water_live != null:
		water_live.stop()
		water_live = null

	_start_water()

	if tunnels != null:
		tunnels.set_enabled(tunnels.enabled)

	net.ground_reset.rpc(store.tiles_stamp, _starter_stamp())


# An admin turns the tunnel collapse on or off and sets the cave-in duration from Esc > Settings; saved beside the world, told to everyone.
func _on_tunnel_setting(peer: int, on: bool, cave_in_s: int) -> void:
	if not admin.is_admin(items.key_of(peer)):
		net.notice.rpc_id(peer, "Only an admin can change the tunnel collapse.")
		net.tunnel_settings.rpc_id(peer, tunnels.enabled, int(tunnels.cave_in_s))
		return

	tunnels.set_cave_in_s(float(cave_in_s), Time.get_ticks_msec())
	tunnels.set_enabled(on)
	var file: FileAccess = FileAccess.open(_store_path + "/tunnel_settings.json", FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify({"on": on, "cave_in_s": int(tunnels.cave_in_s)}))
		file.close()

	print("Tunnel collapse %s, cave-in %d s (peer %d)" % ["on" if on else "off", int(tunnels.cave_in_s), peer])
	net.tunnel_settings.rpc(on, int(tunnels.cave_in_s))


func _tunnel_tick() -> void:
	if not tunnels.enabled:
		return

	var peers: Dictionary = {}

	for peer in items.peer_ids():
		var at: Variant = items.position_of(int(peer))

		if at != null:
			peers[int(peer)] = at

	var result: Dictionary = tunnels.tick(Time.get_ticks_msec(), peers)

	for quake in result["quake"]:
		net.quake.rpc_id(quake[0], quake[1], quake[2], quake[3])

	for leak in result["leak"]:
		net.leak.rpc_id(leak[0], leak[1], leak[2])

	for collapse in result["collapse"]:
		_events.event("tunnel collapse: %d cells, %d fills, victims %s" % [int(collapse["cells"]), (collapse["fills"] as Array).size(), str(collapse["victims"])])

		for victim in collapse["victims"]:
			items.kill(int(victim), "cave-in")

		for fill in collapse["fills"]:
			_fill_ground(fill[0], fill[1], tunnels.rubble_material)


func _dig_ground(center: Vector3, radius: float) -> bool:
	var t0: int = Time.get_ticks_usec()
	var tiles: Array = store.dig_sphere(center, radius)
	var t1: int = Time.get_ticks_usec()

	# Nothing changed (the ground there is already dug out, or the block's log is full): no message to the clients, no
	# water wake, no log line. A held click on one spot used to do all of it every time and the server fell behind.
	if tiles.is_empty():
		return false

	_fill_last = []

	for tile in tiles:
		_tell_tile_changed(tile)

	net.dug.rpc(center, radius)
	tunnels.mark_edit(center, radius)
	var t2: int = Time.get_ticks_usec()

	if water_live != null:
		water_live.dig(center, radius)

	var t3: int = Time.get_ticks_usec()
	_bury_plants(center, radius)
	var t4: int = Time.get_ticks_usec()
	print("Dug a %.1f m sphere at %s; tiles %s" % [radius, str(center), str(tiles)])

	# A dig over 20 ms names where the time went (edit log, announcement, water, plants), so a slow tunnel shows in the telemetry.
	if t4 - t0 > 20000:
		_events.event("slow dig %.0f ms: edit %.0f, tell %.0f, water %.0f, plants %.0f" % [float(t4 - t0) / 1000.0, float(t1 - t0) / 1000.0, float(t2 - t1) / 1000.0, float(t3 - t2) / 1000.0, float(t4 - t3) / 1000.0])

	return true


# Shrubs and plants (not trees: they fall, see server_items _fell_undermined) standing in a dug or filled
# sphere are removed from the world, so nothing floats over a hole or stands buried in a fill (saved edits
# step 2, flora cleanup). They stay gone like any picked plant.
func _bury_plants(center: Vector3, radius: float) -> void:
	_flora_job(["bury", center, radius])


# One persistent thread does the slow flora work so the main thread never waits for it: the plant check of every dig and fill, and
# placing the chunks around a player before their first dig or chop. Placing a chunk takes seconds the first time (it used to run
# on the main thread, nine chunks per dig: 6 s per tunnel dig, and a minute of fast digging backed the server up for minutes).
# The cuts it finds wait in _bury_out and are announced from the main thread.
func _flora_job(job: Array) -> void:
	_bury_mutex.lock()

	if _bury_queue.size() >= BURY_QUEUE_MAX:
		_bury_dropped += 1

		if _bury_dropped == 1 or _bury_dropped % 100 == 0:
			_events.event("flora worker queue full (%d jobs), %d dropped" % [_bury_queue.size(), _bury_dropped])
	else:
		_bury_queue.append(job)

	_bury_mutex.unlock()

	if _bury_thread == null:
		_bury_thread = Thread.new()
		_bury_thread.start(_bury_drain)

	_bury_sem.post()


func _bury_drain() -> void:
	while true:
		_bury_sem.wait()
		_bury_mutex.lock()
		var job: Array = [] if _bury_queue.is_empty() else _bury_queue.pop_front()
		var stop: bool = _bury_stop
		_bury_mutex.unlock()

		if stop:
			return

		if job.is_empty():
			continue

		if job[0] == "warm":
			flora.items_of(job[1])
			continue

		var found: Array = _bury_find(job[1], job[2])

		if not found.is_empty():
			_bury_mutex.lock()
			_bury_out.append_array(found)
			_bury_mutex.unlock()


# Places the nine chunks around a player on the flora thread when they step into a new chunk, so a dig or chop there finds them ready.
func _warm_flora(peer_id: int, position: Vector3) -> void:
	var size: float = flora.placer.chunk_m
	var home: Vector2i = Vector2i(int(floor(position.x / size)), int(floor(position.z / size)))

	if _warm_home.get(peer_id, Vector2i(1 << 30, 0)) == home:
		return

	_warm_home[peer_id] = home

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var chunk: Vector2i = flora.placer.normalize(home + Vector2i(dx, dz))

			if not flora.has_items(chunk):
				_flora_job(["warm", chunk])


func _bury_find(center: Vector3, radius: float) -> Array:
	var found: Array = []
	var chunk_m: float = flora.placer.chunk_m
	var home: Vector2i = Vector2i(int(floor(center.x / chunk_m)), int(floor(center.z / chunk_m)))

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var chunk: Vector2i = flora.placer.normalize(home + Vector2i(dx, dz))

			var all: Dictionary = flora.items_of(chunk)

			for n in range(all["ids"].size()):
				var id: int = all["ids"][n]
				var species: Dictionary = flora.placer._by_id.get(id >> 16, {})

				if species.is_empty() or int(species["kind"]) == PlacerScript.KIND_TREE:
					continue

				var at: Vector3 = all["positions"][n]

				if Vector2(at.x - center.x, at.z - center.z).length() <= radius and at.y >= center.y - radius and at.y <= center.y + radius + 0.5 and flora.cut(chunk, id):
					found.append([chunk, id])

	return found


# Main thread, each frame: announce the plants the worker removed.
func _send_buried() -> void:
	_bury_mutex.lock()
	var out: Array = _bury_out.slice(0, 200)
	_bury_out = _bury_out.slice(out.size())
	_bury_mutex.unlock()

	for cut in out:
		net.flora_cut.rpc(cut[0], cut[1])


# A spade fill: the sphere of ground is saved in the edit log (store.fill_sphere), the water thread raises its ground
# there, and everyone is told. Returns false when nothing changed (the block holds its edit limit).
func _fill_ground(center: Vector3, radius: float, material: int) -> bool:
	# The same fill again with no dig in between changes nothing (a held click): dropped before it costs a log entry, a tile
	# revision, two messages and a water wake.
	if _fill_last == [center, radius, material]:
		return false

	var tiles: Array = store.fill_sphere(center, radius, material)

	if not tiles.is_empty():
		_fill_last = [center, radius, material]

	for tile in tiles:
		_tell_tile_changed(tile)

	if not tiles.is_empty():
		net.filled.rpc(center, radius, material)
		tunnels.mark_edit(center, radius)
		_bury_plants(center, radius)

		if water_live != null:
			water_live.fill(center, radius)

	print("Filled a %.1f m sphere at %s; tiles %s" % [radius, str(center), str(tiles)])
	return not tiles.is_empty()


# NPC rows to each player, about four times a second and only when something near them changed.
func _send_npcs(delta: float) -> void:
	_pulse_t += delta

	if _pulse_t >= 0.25:
		_pulse_t = 0.0

		for peer_id in _peers:
			net.pulse.rpc_id(peer_id)

	_npc_send_t += delta

	if _npc_send_t < 0.05:
		return

	_npc_send_t = 0.0
	_send_round += 1
	var peers: Array = items.peer_ids()

	# Each player is looked at about four times a second, a fifth of them per pass, so the work never lands on one tick.
	for n in range(_send_round % 5, peers.size(), 5):
		var peer: int = int(peers[n])
		var at: Variant = items.position_of(peer)

		if at == null:
			continue

		var rows: Array = npcs.rows_near(at)
		var signature: String = str(rows)

		# The rows ride an unreliable channel and an idle crowd never changes, so a lost first packet (or one that came before the
		# client had built its NPC view) was never sent again: Dave's Ctrl+N saw "roster 2, drawn 0". Resend unchanged rows every 2 s.
		var now_ms: int = Time.get_ticks_msec()

		if _npc_sent.get(peer, "") != signature or now_ms - int(_npc_sent_ms.get(peer, 0)) > 2000:
			_npc_sent[peer] = signature
			_npc_sent_ms[peer] = now_ms
			net.npcs.rpc_id(peer, rows)

		var beasts: Array = animals.rows_near(at)
		var sig: String = str(beasts)

		if _animal_sent.get(peer, "") != sig or now_ms - int(_animal_sent_ms.get(peer, 0)) > 2000:
			_animal_sent[peer] = sig
			_animal_sent_ms[peer] = now_ms
			net.animals.rpc_id(peer, beasts)

		for block in trails.updates_for(peer, at, now_ms):
			net.trails.rpc_id(peer, block[0], block[1], block[2])

		var trail: PackedVector3Array = animals.blood_near(at)
		var trail_sig: int = hash(trail)

		if int(_blood_sent.get(peer, 0)) != trail_sig:
			_blood_sent[peer] = trail_sig
			net.blood.rpc_id(peer, trail)


# Admin placement: only player keys listed in data/admin.json. Nobody is an admin when that file is absent.
func _on_admin_place(peer: int, kind: String, pos: Vector3, arg: String) -> void:
	if not admin.is_admin(items.key_of(peer)):
		print("Admin RPC refused for peer %d" % peer)
		return

	if kind == "marker" and ["bed", "chair", "post"].has(arg):
		print("Admin %d placed marker %s" % [peer, npcs.add_marker(arg, pos.x, pos.z)])
	elif kind == "npc":
		npcs.place_npc(arg, pos.x, pos.z)
	elif kind == "animal":
		if arg == "wolf":
			animals.wolves.spawn_pack(pos.x, pos.z)
		else:
			animals.spawn(arg, pos.x, pos.z)
	elif kind == "carcass":
		items.make_carcass(arg, pos)


func _process(delta: float) -> void:
	if store == null:
		return

	game_clock.advance(delta)
	_events.tick(_event_state, 1000, 500)
	_events.mark("clock")

	if Time.get_ticks_msec() - _clock_saved_msec > 30000:
		_save_game_clock()

	_events.mark("water poll")
	_poll_water()
	_events.mark("weather")
	_update_weather()
	_events.mark("items")
	items.tick(delta)
	_tunnel_tick()
	_send_buried()
	_events.mark("npcs")
	npcs.unwell = dialogue.router.is_unwell()
	npcs.tick(delta)
	_events.mark("animals")
	animals.tick(delta)
	_events.mark("trails")
	trails.tick(delta)
	_events.mark("send npcs")
	_send_npcs(delta)
	_events.mark("deliver blocks")

	# Send what the workers made, batched per peer.
	_done_mutex.lock()
	var done: Array = _done
	_done = []
	var water_done: Array = _water_done
	_water_done = []
	_done_mutex.unlock()

	for entry in water_done:
		if _peers.has(entry[0]):
			net.deliver_water.rpc_id(entry[0], entry[1], entry[2])

	var batches: Dictionary = {}
	_queue_mutex.lock()

	for entry in done:
		if entry.size() > 3:
			_flora_queued.erase([entry[0], entry[1], entry[5]])
		else:
			_queued.erase([entry[0], entry[1]])

	var queued: Array = [_queue.size(), _prefetch.size()]
	_queue_mutex.unlock()

	for entry in done:
		if not _peers.has(entry[0]):
			continue

		if entry.size() > 3:
			net.deliver_flora.rpc_id(entry[0], entry[1], entry[2], entry[4], entry[5])
			_send_stripped(entry[0], entry[1])
			_peers[entry[0]]["flora_bytes"] = int(_peers[entry[0]].get("flora_bytes", 0)) + (entry[2] as PackedByteArray).size()
			continue

		if not batches.has(entry[0]):
			batches[entry[0]] = [PackedInt32Array(), [], 0]

		var batch: Array = batches[entry[0]]
		var key: Vector4i = entry[1]
		batch[0].append_array(PackedInt32Array([key.x, key.y, key.z, key.w]))
		batch[1].append(entry[2])
		batch[2] += (entry[2] as PackedByteArray).size()

		if batch[2] >= MAX_BATCH_BYTES:
			_send(entry[0], batch)
			batches[entry[0]] = [PackedInt32Array(), [], 0]

	for peer_id in batches:
		if not batches[peer_id][1].is_empty():
			_send(peer_id, batches[peer_id])

	_events.mark("checks")
	var now: int = Time.get_ticks_msec()

	# One tile_changed per tile per half second however many edits there were (each makes every client forget what it
	# fetched ahead and ask again), and the revision file once a second.
	if now - _tiles_told_msec >= 500:
		_tiles_told_msec = now

		for tile in _tiles_changed:
			net.tile_changed.rpc(tile, store.revision_of(tile))

		_tiles_changed.clear()
		store.save_revisions()
		flora.save_removed()

	var flag_path: String = _store_path + "/clear_generated.now"

	if now >= _flag_check_msec:
		_flag_check_msec = now + 3000

		var dump_flag: String = _store_path + "/water_dump.now"

		if FileAccess.file_exists(dump_flag):
			var spot: PackedStringArray = FileAccess.get_file_as_string(dump_flag).strip_edges().split(" ", false)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dump_flag))

			if spot.size() >= 2:
				print("server: water dump asked for: ", _dump_water(float(spot[0]), float(spot[1])))

		if FileAccess.file_exists(flag_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(flag_path))
			store.clear_generated()
			print("server: cleared the generated ground as asked (clear_generated.now)")

		# Owner (2026-10-19): no building ahead while a bake runs (it would only be thrown away).
		var baking_now: bool = store.baking()

		if baking_now != _bake_running:
			_bake_running = baking_now
			print("server: a tile bake is running; building ahead is paused until it is done" if baking_now else "server: the tile bake is done")

		# A bake finished: the ground is made again from the new tiles, and clients reload.
		if store.check_tiles(now):
			generator.forget_tiles()
			flora.clear_memory()
			WaterGridScript.forget_ground()

			# The water ran on the old ground (owner, 2026-10-19: it stood as a dome where the
			# new bake had taken the pond away): start it again on the new tiles.
			if water_live != null:
				water_live.stop()
				water_live = null

			_start_water()

			net.ground_reset.rpc(store.tiles_stamp, _starter_stamp())
			print("server: the tile files changed (a bake finished); generated ground thrown away, players reload")

	if now >= _report_at_msec:
		_report_at_msec = now + 10000
		print("server: %d urgent and %d prefetch queued; generated %d, cache hits %d, edit hits %d; flora chunks %d made, %d from memory; idle-built %d columns; bad blocks %d, failed tile loads %d" % [
			queued[0], queued[1], store.blocks_generated, store.cache_hits, store.edit_hits, flora.chunks_made, flora.memory_hits, _idle_built, store.bad_blocks, generator.failed_tiles
		])

		if _link != null and _link.blocks_out > 0:
			print("server: %d blocks sent on the block line (%.1f MB)" % [_link.blocks_out, float(_link.bytes_out) / 1048576.0])

	if _quit_when_empty and _quit_at_msec < 0:
		if not _peers.is_empty():
			_empty_since_msec = 0
		elif _empty_since_msec == 0:
			_empty_since_msec = now
			_quit_grace_msec = 300000 if _never_joined else NetSettings.value("server_empty_grace_s", 120) * 1000
		elif now - _empty_since_msec >= _quit_grace_msec:
			print("server: no players left")
			_events.event("QUIT: no players left for %d s" % int(_quit_grace_msec / 1000.0))
			_quit_at_msec = now
			_run_note("closing", _link_port - 1)

	if _quit_at_msec > 0 and now >= _quit_at_msec:
		_quit_at_msec = -1
		var flush_from: int = Time.get_ticks_msec()
		store.flush()
		_events.event("shutdown: ground flushed in %d ms" % (Time.get_ticks_msec() - flush_from))
		DirAccess.remove_absolute(RUN_NOTE)
		print("server: done; generated %d, cache hits %d, edit hits %d" % [store.blocks_generated, store.cache_hits, store.edit_hits])
		get_tree().quit(0)

	_events.mark("between frames (rpc handlers, engine)")


# Tells the launcher (another process, same user folder) which server is on the port: its process, commit and whether it is closing.
# A game started while the old server is closing, or from a newer checkout, replaces it instead of joining a server that
# will stop answering (Dave, build 619: stuck on "0 blocks arriving").
func _run_note(state: String, listen_port: int) -> void:
	var file: FileAccess = FileAccess.open(RUN_NOTE, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify({"pid": OS.get_process_id(), "port": listen_port, "commit": GitStamp.short_commit(), "state": state}))
		file.close()


func _send(peer_id: int, batch: Array) -> void:
	net.deliver_blocks.rpc_id(peer_id, batch[0], batch[1])
	_peers[peer_id]["blocks"] += batch[1].size()
	_peers[peer_id]["bytes"] += int(batch[2])


# Worker thread: takes the next block, urgent ones first, and makes it.
func _worker_loop() -> void:
	while true:
		_work.wait()
		_queue_mutex.lock()
		var item: Array = []
		var flora_item: Array = []

		# Order: urgent blocks, flora chunks, prefetch blocks.
		var water_item: Array = []

		if _queue.is_empty() and not _flora_queue.is_empty():
			flora_item = _flora_queue.pop_front()
		elif _queue.is_empty() and not _water_queue.is_empty():
			water_item = _water_queue.pop_front()

		while flora_item.is_empty() and water_item.is_empty() and item.is_empty() and not (_queue.is_empty() and _prefetch.is_empty()):
			var urgent: bool = not _queue.is_empty()
			var next: Array = _pop_nearest_urgent() if urgent else _prefetch.pop_front()

			# A prefetch entry moved up to urgent, or already taken, is skipped.
			if _queued.get(next, "") == ("u" if urgent else "p"):
				_queued[next] = "r"
				item = next

		var stopping: bool = _stopping
		_queue_mutex.unlock()

		if stopping:
			return

		if not water_item.is_empty():
			var packed: PackedByteArray = flora.water_bytes(water_item[1])
			_done_mutex.lock()
			_water_done.append([water_item[0], water_item[1], packed])
			_done_mutex.unlock()
			continue

		if not flora_item.is_empty():
			var chunk_bytes: PackedByteArray = flora.chunk_bytes(flora_item[1], flora_item[2])
			var water_bytes: PackedByteArray = flora.water_bytes(flora_item[1])
			_done_mutex.lock()
			_done.append([flora_item[0], flora_item[1], chunk_bytes, "flora", water_bytes, flora_item[2]])
			_done_mutex.unlock()
			continue

		if item.is_empty():
			continue

		var key: Vector4i = item[1]
		var bytes: PackedByteArray = store.block_bytes(Vector3i(key.x, key.y, key.z), key.w)
		var check: PackedByteArray = PackedByteArray()
		check.resize(4)
		check.encode_u32(0, hash(bytes) & 0xffffffff)
		bytes.append_array(check)           # the client verifies this before using the block

		# Straight down the block line when this player has one (no wait for the main thread).
		if _link.send(item[0], key, bytes):
			_queue_mutex.lock()
			_queued.erase(item)
			_queue_mutex.unlock()
			continue

		_done_mutex.lock()
		_done.append([item[0], key, bytes])
		_done_mutex.unlock()


# Takes the urgent block closest to where its player will land (queue mutex held).
# Looks at the oldest 400 only, so one pick stays cheap; blocks of players with
# no report yet go in arrival order.
func _pop_nearest_urgent() -> Array:
	var best: int = 0
	var best_score: float = INF

	for n in range(mini(_queue.size(), 400)):
		var item: Array = _queue[n]
		var aim: Variant = _aim.get(item[0], null)

		if aim == null:
			return _queue.pop_front() if n == 0 else _queue.pop_at(n)

		var key: Vector4i = item[1]
		var block_m: float = float(16 << key.w)
		var centre: Vector2 = Vector2((float(key.x) + 0.5) * block_m, (float(key.z) + 0.5) * block_m)
		# Finer detail first among equals: ground you stand on before far views.
		var score: float = centre.distance_to(aim) + 60.0 * float(key.w)

		if score < best_score:
			best_score = score
			best = n

	return _queue.pop_at(best)


# Block offsets around a player, nearest first; each detail level covers a
# circle of IDLE_RADIUS_BLOCKS blocks of its own size, so coarse levels reach
# farther. Levels are interleaved by how far out in their own circle they are.
func _make_idle_offsets() -> void:
	var list: Array = []

	for lod in range(IDLE_LODS):
		for dz in range(-IDLE_RADIUS_BLOCKS, IDLE_RADIUS_BLOCKS + 1):
			for dx in range(-IDLE_RADIUS_BLOCKS, IDLE_RADIUS_BLOCKS + 1):
				var d: float = sqrt(float(dx * dx + dz * dz)) / float(IDLE_RADIUS_BLOCKS)

				if d <= 1.0:
					list.append([d + 0.01 * float(lod), lod, dx, dz])

	list.sort_custom(func(a, b): return a[0] < b[0])
	_idle_offsets = list.map(func(item): return [item[1], item[2], item[3]])


# Idle thread: while no player is waiting for anything, makes and saves the
# blocks around each player, starting with the ones closest to them. Real
# requests always go first (checked before every block).
func _idle_loop() -> void:
	var cursors: Dictionary = {}       # peer -> [anchor, next offset index]

	while true:
		_queue_mutex.lock()
		var stopping: bool = _stopping
		var busy: bool = not (_queue.is_empty() and _prefetch.is_empty() and _flora_queue.is_empty() and _water_queue.is_empty())
		var anchors: Dictionary = _idle_anchor.duplicate()

		for peer in anchors:
			if _aim.has(peer):
				var aim: Vector2 = _aim[peer]
				anchors[peer] = Vector3i(int(floor(aim.x / 16.0)), anchors[peer].y, int(floor(aim.y / 16.0)))

		_queue_mutex.unlock()

		if stopping:
			return

		if busy or anchors.is_empty() or _bake_running:
			OS.delay_msec(20)
			continue

		var worked: bool = false

		for peer in anchors:
			var anchor: Vector3i = anchors[peer]
			var cursor: Array = cursors.get(peer, [Vector3i(), 0])

			# Followed the player somewhere new: start again from the nearest blocks.
			if (cursor[0] - anchor).length() > 2.0:
				cursor = [anchor, 0]

			var offset: Array = []

			while cursor[1] < _idle_offsets.size():
				offset = _idle_offsets[cursor[1]]
				cursor[1] += 1

				if _idle_prebuild_column(anchor, offset):
					worked = true
					break

			cursors[peer] = cursor

			if worked:
				break

		if not worked:
			OS.delay_msec(100)


# Makes the surface blocks of one column (one block above and below the
# ground). True if it made anything.
func _idle_prebuild_column(anchor: Vector3i, offset: Array) -> bool:
	var lod: int = offset[0]
	var block_m: float = float(16 << lod)
	var bx: int = (anchor.x >> lod) + offset[1]
	var bz: int = (anchor.z >> lod) + offset[2]
	var key: Vector4i = Vector4i(bx, 0, bz, lod)

	_queue_mutex.lock()
	var seen: bool = _idle_done.has(key)

	if _idle_done.size() >= IDLE_MAX_DONE:
		_idle_done.clear()

	_idle_done[key] = true     # claimed, so no other idle thread repeats it
	_queue_mutex.unlock()

	if seen:
		return false

	var low: float = INF
	var high: float = -INF

	for k in range(5):
		var sx: float = (float(bx) + (0.5 if k == 4 else float(k % 2) * 0.99)) * block_m
		@warning_ignore("integer_division")
		var sz: float = (float(bz) + (0.5 if k == 4 else float(k / 2 % 2) * 0.99)) * block_m
		var h: float = generator.surface_height(sx, sz)
		low = minf(low, h)
		high = maxf(high, h)

	var made: bool = false

	for by in range(int(floor(low / block_m)) - 1, int(floor(high / block_m)) + 2):
		if store.ensure_block(Vector3i(bx, by, bz), lod):
			made = true

	_queue_mutex.lock()

	if made:
		_idle_built += 1

	_queue_mutex.unlock()
	return made


func _load_game_clock() -> void:
	var path: String = _store_path + "/game_clock.json"
	_clock_saved_msec = Time.get_ticks_msec()

	if not FileAccess.file_exists(path):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("seconds"):
		game_clock.seconds = float(parsed["seconds"])


func _save_game_clock() -> void:
	_clock_saved_msec = Time.get_ticks_msec()

	if _store_path == "":
		return

	var file: FileAccess = FileAccess.open(_store_path + "/game_clock.json", FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify({"seconds": game_clock.seconds}))


func _exit_tree() -> void:
	_events.event("EXIT: server closed (exit_tree)")
	_events.stop_watchdog()
	_save_game_clock()

	tunnels.stop()

	if trails != null:
		trails.save()

	if items != null:
		items.save()

	_bury_mutex.lock()
	_bury_queue.clear()
	_bury_stop = true
	_bury_mutex.unlock()

	if _bury_thread != null:
		_bury_sem.post()
		_bury_thread.wait_to_finish()
		_bury_thread = null

	if flora != null:
		flora.save_removed(true)

	_queue_mutex.lock()
	_stopping = true
	_queue_mutex.unlock()

	for thread in _workers:
		_work.post()

	for thread in _workers:
		thread.wait_to_finish()

	for thread in _idle_workers:
		thread.wait_to_finish()

	if _link != null:
		_link.stop()

	if water_live != null:
		water_live.stop()

	if store != null and OS.has_environment("BLOCKTIME"):
		print(store.timing_report())

	if store != null:
		store.flush()
