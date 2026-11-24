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
#   --threads=N     worker threads making blocks (default: usable CPUs - 1; cpu_budget.gd counts a container's CPU limit)
#   --quit-after=S  stop after S seconds (headless checks)
#   --profile=S     (load tests, tools/load_test.sh) every S seconds a PROFILE line of each frame step's time, and every telemetry line also on stdout
#   --timeout=S     (testing, also "--timeout S") the same as --quit-after; --watch-parent=PID stops when that process is gone. Neither flag = no limit.
#   --quit-when-empty  stop 10 s after the last player leaves, or after 5 min
#                      if nobody joins (the "play" launcher's own server)
#   --dedicated     a server for other machines (plan A4, Dave 18 Nov 2026): the admin check is on whatever
#                   admin_setting.json says, admins are the keys in <store>/admin.json only, --quit-when-empty
#                   and --open-admin are ignored, and the telemetry log and run note go in <store> and <store>/logs
#
# Creating the file stop.now in the store folder closes any server the normal way (ground flushed, spots noted,
# everything saved, exit 0). A stop signal kills Godot at once (exit 143, nothing saved: David4, 18 Nov 2026), so
# deploy/server/run_server.sh turns TERM/INT into that file; run a dedicated server through it.
#
# Clients start at the starter spawn point of tile (3,4).

const FishWaterScript := preload("res://src/server/server_fish_water.gd")
const WaterAreas := preload("res://src/shared/water_areas.gd")
const FineWaterSend := preload("res://src/shared/fine_water_send.gd")
const AnimalContact := preload("res://src/shared/animal_contact.gd")   # a blow reaches an animal's body, not its middle (hit_animal)
const SelfTimeoutScript := preload("res://src/shared/self_timeout.gd")
const EventLogScript := preload("res://src/shared/event_log.gd")
const IceMoatScript := preload("res://src/shared/ice_moat.gd")
const PlayServerScript := preload("res://src/shared/play_server.gd")
const GitStamp := preload("res://src/debug/git_stamp.gd")
const BuildInfo := preload("res://src/shared/build.gd")
const BuildStamp := preload("res://src/shared/build_stamp.gd")
const CpuBudgetScript := preload("res://src/shared/cpu_budget.gd")
const STOP_NOTE := "user://server_stop.json"   # Play asks the server it started to close: {"pid", "commit"} (launcher.gd)
const RUN_NOTE := "user://server_run.json"      # which server holds the port (read by the launcher)
const WATER_CHUNKS_MAX := 64              # flora chunks answered per water request
const GATHER_MIN_MSEC := 100              # a peer's gather requests are handled at most this often
const GATHER_REACH_M := 12.0              # a gather request for a chunk further than this from the player is ignored
const NetSettings := preload("res://src/shared/net_settings.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")
const BogIronScript := preload("res://src/shared/bog_iron.gd")
const SpawnPointScript := preload("res://src/shared/spawn_point.gd")
const NpcCampScript := preload("res://src/shared/npc_camp.gd")   # Edda and Hob's fire: where a player rescued to the town wakes (_rescue_spots)
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const SwimScript := preload("res://src/shared/swim.gd")
const TileDataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const NpcsScript := preload("res://src/stream/server_npcs.gd")
const PlayersScript := preload("res://src/stream/server_players.gd")
const CuesScript := preload("res://src/stream/server_action_cues.gd")
const FishSignsScript := preload("res://src/server/server_fish_signs.gd")
const TribesScript := preload("res://src/stream/server_tribes.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const EditedGroundScript := preload("res://src/stream/edited_ground.gd")
const CoarseGroundScript := preload("res://src/stream/server_coarse_ground.gd")
const FogGroundScript := preload("res://src/shared/fog_ground.gd")
const TrailsScript := preload("res://src/stream/server_trails.gd")
const RangesScript := preload("res://src/stream/server_ranges.gd")
const BanditsScript := preload("res://src/stream/server_bandits.gd")
const MapScript := preload("res://src/stream/server_map.gd")
const MapCodec := preload("res://src/shared/map_codec.gd")
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
const FloraPackScript := preload("res://src/stream/flora_pack.gd")   # prebuilt plants (Dave 23 Nov 2026)
const TreeTrunks := preload("res://src/flora/tree_trunks.gd")
const FloraStoreScript := preload("res://src/stream/server_flora.gd")
const WaterHub2Script := preload("res://src/water2/water_hub2.gd")   # Dynasty water (Sonny, 31 Oct 2026): the only water since 9 Nov 2026 (the old hub and --water-old are deleted)
# Lag lane 23 Nov 2026 (cloud join, timestamped): a new player's far ground reaches the neighbour tiles (a client's coarse LOD blocks go out
# several km), and those tiles were read only when the first such block was asked for, one after another at 1.4-2.6 s each: the ground was
# ready 13.5 s after the welcome, 6 s of it waiting for tiles (4, 4), (3, 5) and (4, 5). Every tile within this of the spawn is now read at
# start-up, and of a returning player's spot at the hello, each on its own worker, so the reads overlap and are mostly done before they are needed.
const JOIN_TILE_MARGIN_M := 6000.0
const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const BlockLinkScript := preload("res://src/stream/block_link_server.gd")
const ServerAuthScript := preload("res://src/shared/server_auth.gd")
const ServerSettingsScript := preload("res://src/stream/server_settings.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const TunnelWatchScript := preload("res://src/stream/tunnel_watch.gd")

const MAX_BATCH_BYTES := 192 * 1024
const MAX_PLAYERS := 32                 # the most players at once; the server pick page shows "2 / 32"
var max_players: int = MAX_PLAYERS       # --max-players=N (tests: a full server with 1 player)
const MAX_QUEUE_PER_PEER := 20000
const KEY_BURST := 8000                # block keys one peer may ask for at once; it refills KEY_REFILL_PER_S a second (one peer flooding must not fill the queue)
const KEY_REFILL_PER_S := 4000.0
const WeatherScript := preload("res://src/shared/weather.gd")
const ClimateScript := preload("res://src/shared/climate.gd")
const DrinkRulesScript := preload("res://src/shared/drink_rules.gd")
const CellReadsScript := preload("res://src/stream/cell_reads.gd")   # a scatter cell's ground, water and ore reads bound to its tile (one generator lock a cell)
const ThunderScript := preload("res://src/shared/thunder.gd")
const IceScript := preload("res://src/shared/ice.gd")
const WaterFlowScript := preload("res://src/stream/water_flow.gd")
const LandTypeScript := preload("res://src/water/land_type.gd")
const WEATHER_SWELL := 1.0              # a big storm makes every spring run this much stronger (x2 in all: the x10 start flow becomes x20; Dave 2026-10-20)
const DRY_SHRINK := 0.7                 # full dry heat takes this share off the spring flow (a trickle is left); the floor below
const RUNOFF_FLOOR := 0.2               # rivers never shrink below this share of the start flow
const WEATHER_LAG_S := 600.0            # real seconds the rivers take to follow the weather (about ten minutes to swell, as long to recede)
const WATER_BASE_RATE := 10.0           # m3 per second at each spring (about 158,000 US gallons a minute); the + and - keys scale it
const IDLE_LODS := 4                   # detail levels the idle builder keeps ahead of players
const IDLE_RADIUS_BLOCKS := 12         # circle around each player, in blocks of that level
const IDLE_MAX_DONE := 400000          # remembered built blocks (skips re-checking the store)
const IDLE_SAVED_SPOTS := 8            # characters' saved spots (most recent) prebuilt at start-up, with the spawn

var _commit: String = GitStamp.short_commit()   # read once at start (Dave 17 Nov 2026): a server left running after a pull must name the code it runs, not the checkout now on disk, or the client's out-of-date check is fooled
var _server_settings = ServerSettingsScript.new()
var _auth = ServerAuthScript.new()
var _stamped_build: int = BuildStamp.stamped_build()   # read once at start, like the commit: 0 = an editor run, which lets every build in (step A1)
var generator
var store
var flora
var trails                             # ServerTrails: worn game trails the animals leave
var ranges                             # ServerRanges: animal places and the trails between them (docs/design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md)
var bandits                            # ServerBandits: bandit camp sites woken by road traffic (docs/design/BANDIT_CAMPS.md)
var map_knowledge                      # ServerMap: what each character has surveyed for its charcoal Map (protocol 120)
var animals                            # ServerAnimals: wildlife around the players (rabbits)
var edited_ground                      # EditedGround: the ground with its digs and fills, for the animals
var coarse_ground = CoarseGroundScript.new()   # summits and valley-fog cells for the clients, from the tiles (protocol 132)
var _animal_sent: Dictionary = {}
var _send_round: int = 0
var identity = IdentityScript.new()      # who a peer is (src/stream/identity_provider.gd): the swap point for real logins
var items                              # ServerItems: inventories and world items
var npcs                               # ServerNpcs: classic NPCs (protocol 45)
var players                            # ServerPlayers: what each player sees of the others (protocol 151)
var cues                               # ServerActionCues: other players' blows, picks and crafts heard nearby (protocol 156)
var fish_signs                         # ServerFishSigns: fish jumps and shadows near players (protocol 169)
var tribes                             # ServerTribes: goblin tribes (data/creatures/goblin_tribes.json): standing, keeping off, anger
var admin                              # ServerAdmin: who may place markers and NPCs
var dialogue                           # ServerDialogue: talking to NPCs
var trade                              # ServerTrade: shops (coins)
var _npc_sent_ms: Dictionary = {}
var _animal_sent_ms: Dictionary = {}
var _npc_sent: Dictionary = {}         # peer -> hash of the NPC rows last sent
var _npc_send_t: float = 0.0
var _pulse_t: float = 0.0
var _water_updates: int = 0
var weather: Dictionary = {}           # the starter row's weather at sea level (WeatherScript.state), refreshed every second: the flora season, the log line, fallbacks
var _weather_next_msec: int = 0
var _weather_here_cache: Dictionary = {}   # Vector2i(tile row, height band) -> Weather.state, for the second it was made (_weather_here)
var _weather_here_msec: int = -100000
var _rain_hours_cache: Dictionary = {}   # Vector3i(tile row, height band, hours looked back) -> _rain_hours_at's answer, for the game hour it was made
var _rain_hours_hour: int = -1
var _blood_sent: Dictionary = {}       # peer -> hash of the blood trail last sent
var _burrows_sent: Dictionary = {}     # peer -> hash of the burrow spots last sent
var _trap_marks_sent: Dictionary = {}  # peer -> hash of the trap marks last sent for its Map
var _nests_sent: Dictionary = {}       # peer -> hash of the nest spots last sent
var _holes_sent: Dictionary = {}       # peer -> hash of the ice holes last sent (protocol 97)
var _far_fires_sent: Dictionary = {}   # peer -> hash of the far lit campfires last sent (protocol 114)
var _river_rows: Dictionary = {}   # tile row -> [swell, dry]: each live row's rivers follow their own row's weather, lagged (not saved: they settle in WEATHER_LAG_S)
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
# The idle builders wait while the main thread is pressed: with players spread out they took the CPUs the main thread needed (server load test
# 23 Nov 2026, 4 CPUs, 32 players over 2 km: 4 frames a second with them, 19 without). Set on the main thread, read by the idle threads.
const IDLE_YIELD_GAP_MS := 50          # a frame gap this long ...
const IDLE_YIELD_MS := 3000            # ... keeps the idle builders waiting this long
var _idle_hold_until_msec: int = 0
var _last_frame_msec: int = 0
var settings
var spawn: Vector3 = Vector3.ZERO
var net
var _queue: Array = []                 # urgent [peer, key Vector4i], oldest first
var _prefetch: Array = []              # prefetch [peer, key], oldest first
var _queued: Dictionary = {}           # [peer, key] -> "u" urgent, "p" prefetch, "r" running
var _flora_queue: Array = []           # [peer, chunk Vector2i, full (false: trees only)], oldest first
var _flora_running: int = 0            # workers making a flora chunk now (under _queue_mutex); at most _max_running - 1, so one is always free for ground
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
var _dev_reset_at_msec: int = -1   # testing only: --dev-reset-world=S runs the admin world reset S seconds after start (src/worldgen/tools/reset_world_store.gd)
var _watch_parent_pid: int = 0                # --watch-parent=PID (testing): quit when that process is gone
var _watch_next_msec: int = 0
var _listen_port: int = 0                    # the game port this server listens on (its run note)
var _stop_check_msec: int = 0                 # next look for Play's stop request (STOP_NOTE)
var _quit_when_empty: bool = false
var _dedicated: bool = false                  # --dedicated (header)
const STOP_NOW := "/stop.now"                 # in the store folder: close the normal way (run_server.sh writes it on a stop signal)
var _empty_since_msec: int = 0
var _quit_grace_msec: int = 10000
var _never_joined: bool = true
var _water_answered_msec: Dictionary = {}   # peer -> last time its water request was answered
var _water_window: Rect2 = Rect2()          # the live water window (world m) from the last flow packet: water only moves inside it
var _water_window_told: Rect2 = Rect2()     # the window the last "water moved" named
var _fine_sends: int = 0                    # 2 m water messages sent (the log line for the PC check)
# Dave 18 Nov 2026 ("water from small digs should be sent to local players"): each player is sent only the dig regions' 2 m water within
# EDIT_SEND_M of them (fine_water_send.gd). The newest packet of each region is kept, so one who comes within reach gets it at once.
var _fine_keys: PackedStringArray = PackedStringArray()   # every drawn region, as the last take_fine named them
var _fine_cache: Dictionary = {}       # key -> that region's newest packet
var _fine_told: Dictionary = {}        # peer -> {key: true}: the regions that player has a picture of
var _fine_named: Dictionary = {}       # peer -> PackedStringArray: the keys they were last named
var _live_told: Array = []                 # the dig windows' areas (Rect2) the last "water moved" named (Sullivan water)
var _water_tiles_told: Array = []          # the tiles (Vector2i) the last water update set: a new tile's first update may draw sleeping dig regions in
var _cave_streams_sent: Dictionary = {}     # peer -> {tile: true}: spring cave streams already sent (protocol 87)
var _water_sent: Dictionary = {}            # peer -> {chunk: hash of the water bytes it holds}: unchanged water is not sent again
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
# Audit finding 9 (Dave 18 Nov 2026): a dig or fill goes only to the players within EDIT_SEND_M of it. A player farther away gets it
# when they come within that range (_send_held_edits, every half second), or at their next join through the edits since (protocol 128).
# The client's finest ground reaches about 48 m and each coarser level doubles it (48, 96, 192, 384 m), so beyond about 384 m a 3 m
# edit no longer shows in its ground; 512 m leaves room for a rider between two half-second checks.
const EDIT_SEND_M := 512.0
const EDITS_HELD_MAX := 1024           # per player; past it the oldest held edit is sent anyway (out of range costs only a fetch)
const EDITS_RELEASE_MAX := 256         # held edits sent to one player per half second, so arriving at a long road is no hitch
var _edit_by: int = 0                  # the admin whose dig this is (_on_dig_requested): it reaches them wherever their reported spot is
var _edits_held: Dictionary = {}        # peer -> [[centre, radius, material (-1 = a dig)], ...] oldest first, not yet sent to that player
var _events = EventLogScript.new()      # user://server_events.log: peers, stalls, quit reason (why a client was dropped)
var _report_at_msec: int = 0
var _last_report: String = ""   # the 10 s status lines as last printed: unchanged, they wait for the 5 min heartbeat (Dave's server log, 23 Nov 2026)
var _last_report_msec: int = 0
var _usable_cpus: int = 1               # CPUs this process may use (cpu_budget.gd: a container's limit counts)
var _cpus_setting: int = 0              # --cpus=N or DYNASTY_SERVER_CPUS: the CPU threads the server may use in all (0 = no setting)
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
var ice_moat = IceMoatScript.new()   # the thaw's open shore moat, as the client draws it (ice_moat.gd)
var _night_frames: int = 0           # a night skip's catch-up frames so far (the log line)
var _night_cost_usec: int = 0
var _night_worst_usec: int = 0
var game_clock = GameClockScript.new()   # the one game clock; advances only while the server runs
var _clock_saved_msec: int = 0


var _refused_start: bool = false   # a save file exists but could not be read: the server quits at once and saves nothing


func _ready() -> void:
	net = $TerrainNet
	var port: int = 24600
	var world_dir: String = "res://worlds/base_world"
	var store_dir: String = ""
	_cpus_setting = CpuBudgetScript.setting(OS.get_cmdline_user_args(), OS.get_environment("DYNASTY_SERVER_CPUS"))
	_usable_cpus = CpuBudgetScript.allowed(CpuBudgetScript.usable(), _cpus_setting)   # --cpus / DYNASTY_SERVER_CPUS holds it to fewer (SERVER.md, CPUs)
	_max_running = maxi(_usable_cpus - 1, 1)   # a container held to fewer CPUs than the machine has gets fewer threads (David4, 15 Nov 2026)
	_idle_threads = CpuBudgetScript.idle_threads_for(_cpus_setting, _idle_threads)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument == "--clear-generated":
			_clear_generated_at_start = true
		elif argument.begins_with("--store="):
			store_dir = argument.trim_prefix("--store=")
		elif argument.begins_with("--max-players="):
			max_players = clampi(int(argument.trim_prefix("--max-players=")), 1, MAX_PLAYERS)
		elif argument.begins_with("--threads="):
			_max_running = maxi(int(argument.trim_prefix("--threads=")), 1)
		elif argument.begins_with("--idle-threads="):
			_idle_threads = maxi(int(argument.trim_prefix("--idle-threads=")), 0)
		elif argument == "--quit-when-empty":
			_quit_when_empty = true
		elif argument == "--dedicated":
			_dedicated = true
		elif argument.begins_with("--dev-reset-world="):
			_dev_reset_at_msec = Time.get_ticks_msec() + int(float(argument.trim_prefix("--dev-reset-world=")) * 1000.0)
		elif argument.begins_with("--profile="):
			_events.profile_every_msec = int(float(argument.trim_prefix("--profile=")) * 1000.0)   # load tests: PROFILE lines (event_log.gd)
			_events.profile_frame_phase = "clock"
		elif argument.begins_with("--quit-after="):
			_quit_at_msec = Time.get_ticks_msec() + int(float(argument.trim_prefix("--quit-after=")) * 1000.0)

	if _dedicated and _quit_when_empty:
		print("server: --dedicated ignores --quit-when-empty")

	_quit_when_empty = _quit_when_empty and not _dedicated

	# Testing only (self_timeout.gd): --timeout=N (or --timeout N) quits after N seconds the same clean way as --quit-after; --watch-parent=PID quits when that process is gone.
	var self_flags: Dictionary = SelfTimeoutScript.parse(OS.get_cmdline_user_args())

	if float(self_flags["seconds"]) > 0.0:
		var due: int = Time.get_ticks_msec() + int(float(self_flags["seconds"]) * 1000.0)
		_quit_at_msec = due if _quit_at_msec < 0 else mini(_quit_at_msec, due)

	_watch_parent_pid = int(self_flags["parent"])

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
	_server_settings.load_from(store_dir)   # name, message and password for the server pick page (store's server.json; DYNASTY_SERVER_PASSWORD)

	if _server_settings.problem != "":
		push_error("Terrain server: " + _server_settings.problem)   # never open a password server to everyone by a typo in server.json
		get_tree().quit(1)
		return

	print("server: name \"%s\"; %s" % [_server_settings.server_name, _server_settings.note])
	_load_game_clock()

	# Test plays (lag lane 23 Nov 2026): --game-hour=H starts the clock at hour H of its current day, so standing-play hitch counts taken on
	# different days compare (the sky's cost depends on the hour). Nothing else changes; the clock runs on from there and is saved as usual.
	# For throwaway test stores only: it can move the clock back up to a day, which skews item, trade and animal timers on a kept world.
	# --game-day=D (look rig --day, weather walk 23 Nov 2026) moves the clock to day D of the year (0 to 364) at the same hour, in the same year,
	# so the season turns and winter can be pictured; read before --game-hour, which then sets the hour of that day. Throwaway stores only.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--game-day=") and argument.trim_prefix("--game-day=").is_valid_int():
			var year_start: float = float(game_clock.year()) * float(GameClockScript.DAYS_PER_YEAR) * GameClockScript.SECONDS_PER_DAY   # starter-calendar: the admin --game-day sets the one clock
			game_clock.seconds = year_start + float(clampi(int(argument.trim_prefix("--game-day=")), 0, GameClockScript.DAYS_PER_YEAR - 1)) * GameClockScript.SECONDS_PER_DAY + game_clock.hour() * 3600.0   # starter-calendar: the admin --game-day sets the one clock
			print("server: --game-day: the clock is at day %d (%s), hour %.2f" % [game_clock.day_of_year(), game_clock.season(), game_clock.hour()])   # starter-calendar: a log line

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--game-hour=") and argument.trim_prefix("--game-hour=").is_valid_float():
			var day_start: float = floorf(game_clock.seconds / GameClockScript.SECONDS_PER_DAY) * GameClockScript.SECONDS_PER_DAY
			game_clock.seconds = day_start + clampf(float(argument.trim_prefix("--game-hour=")), 0.0, 23.99) * 3600.0
			print("server: --game-hour: the clock starts at hour %.2f of day %d" % [game_clock.hour(), game_clock.day_of_year()])   # starter-calendar: a log line

	var problem: String = store.setup(generator, store_dir)

	if _clear_generated_at_start:
		store.clear_generated()
		print("server: cleared the generated ground as asked (--clear-generated)")

	if problem == "" and not _store_writable(store_dir):
		problem = "the store folder %s cannot be written (read-only, full, or not this user's)" % store_dir

	if problem != "":
		push_error("Terrain server: cannot start: %s. The store is left as it was; nothing is saved over it." % problem)
		_refused_start = true   # no frame runs on a half-made server, and nothing is saved at exit
		get_tree().quit(1)
		return

	_start_tunnels()
	SpawnPointScript.use_world(world_dir)   # the starter tile's picked spawn (Stage E 6e); nothing else reads it to place things
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	flora = FloraStoreScript.new()
	flora.setup(placer, store_dir)
	var flora_pack = FloraPackScript.new()
	flora_pack.open(store_dir + "/" + FloraPackScript.FOLDER, FloraPackScript.fingerprint(store.tiles_stamp))

	if flora_pack.chunks() > 0:
		flora.pack = flora_pack

	if flora_pack.chunks() > 0 or flora_pack.stale > 0:
		print("server flora: prebuilt plants for %d chunks in %d tiles%s" % [flora_pack.chunks(), flora_pack.tiles, ("; %d tile files were made from other tiles, data or placer code and are not used (build them again)" % flora_pack.stale) if flora_pack.stale > 0 else ""])
	items = ItemsScript.new()
	@warning_ignore("confusable_local_declaration")
	items.send_full = func(peer, bytes): net.inventory_full.rpc_id(peer, bytes)
	@warning_ignore("confusable_local_declaration")
	items.send_slots = func(peer, bytes): net.inventory_slots.rpc_id(peer, bytes)
	@warning_ignore("confusable_local_declaration")
	items.send_purse = func(peer, counts): net.purse.rpc_id(peer, counts)
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
	items.cave_scatter = func(cell: Vector2i, cell_m: float) -> PackedFloat32Array:   # cave floor stones and boulders (Dave 4 Nov: caves "riddled with rocks and collectable stones")
		var centre: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * cell_m
		var cave_tile = generator.get_tile(generator.tile_of(centre.x, centre.y))
		var out: PackedFloat32Array = PackedFloat32Array()

		if cave_tile == null or cave_tile.placeholder:
			return out

		for n in cave_tile.cave_scatter_in(cell, cell_m):
			out.append_array(cave_tile.cave_scatter.slice(n * 5, n * 5 + 5))

		return out
	items.ground_ready = func(x, z) -> bool:
		if generator.tile_cached(x, z):
			return true

		generator.prefetch_tile(x, z)
		return false
	items.world_seed = int(settings.master_seed)
	items.rain_now = func(): return float(weather.get("rain", 0.0))
	items.cover_at = _cover_at
	items.cave_air = func(pos): return _cave_air(pos)   # depth in from the mouth and the day swing, for the cave air blend (docs/design/cave_climate_design.md)
	items.cave_mean_c = func(pos): return WeatherScript.year_mean_c(settings.get_zone_group_for_row(int(floor(pos.z / float(settings.tile_size_m)))), pos.y) if _in_cave(pos) else NAN   # cave air: the island's year mean at that height (#664)
	items.year_mean_at = func(pos): return WeatherScript.year_mean_c(settings.get_zone_group_for_row(int(floor(pos.z / float(settings.tile_size_m)))), pos.y)   # a cold store: the ground below 2 m holds the year mean (item_system.md D1)
	items.roof_add = func(roof): return flora.add_roof(roof)
	items.roof_remove = func(key): flora.remove_roof(key)
	items.register_roofs()

	for dev_arg in OS.get_cmdline_user_args():   # testing only (rigs and screenshots): --dev-place=name@x,z,yaw[,lit or coals or ash][,firewood or log], repeatable; normal play never passes it
		if dev_arg.begins_with("--dev-place="):
			items.dev_place_later(dev_arg.trim_prefix("--dev-place="))   # placed as soon as the ground under it is loaded
	items.tree_info = _tree_info
	items.shrub_info = _shrub_info
	items.standing_near = _standing_near
	items.flora_changed = _flora_changed
	flora.dynamic = func(home): return items.dynamic_items(home)
	items.cut_tree = _cut_tree
	items.camp_fire_on = true   # Edda and Hob's fire (data/npcs/camp.json) burns in every real world
	@warning_ignore("confusable_local_declaration")
	items.send_notice = func(peer, text): net.notice.rpc_id(peer, text)
	items.send_goals = func(peer, rows): net.goals.rpc_id(peer, rows)
	items.send_goal_done = func(peer, id, copper): net.goal_done.rpc_id(peer, id, copper)
	items.send_goal_progress = func(peer, changes): net.goal_progress.rpc_id(peer, changes)
	items.send_marker_done = func(peer, at): net.road_marker_done.rpc_id(peer, at)
	items.send_survey_refused = func(peer, last): net.survey_refused.rpc_id(peer, last)
	items.send_hoe_verdict = func(peer, kind, code, at, state, why, cells): net.hoe_verdict.rpc_id(peer, kind, code, at, state, why, cells)
	@warning_ignore("confusable_local_declaration")
	items.send_breath = func(peer, tenths): net.breath.rpc_id(peer, tenths)
	@warning_ignore("confusable_local_declaration")
	items.send_energy = func(peer, percent): net.energy.rpc_id(peer, percent)
	@warning_ignore("confusable_local_declaration")
	items.send_warmth = func(peer, percent): net.warmth.rpc_id(peer, percent)
	items.send_comfort = func(peer, tenths, target, trend, tip): net.comfort.rpc_id(peer, tenths, target, trend, tip)
	@warning_ignore("confusable_local_declaration")
	items.send_sick = func(peer, hours): net.sick.rpc_id(peer, hours)
	@warning_ignore("confusable_local_declaration")
	items.send_body = func(peer, bpm, eta, phase): net.body.rpc_id(peer, bpm, eta, phase)
	@warning_ignore("confusable_local_declaration")
	items.send_limp = func(peer, percent): net.limp.rpc_id(peer, percent)
	items.send_soak = func(peer, percent, windy): net.soak.rpc_id(peer, percent, windy)
	items.ice_cover_at = func(pos): return IceScript.cover(game_clock.seconds, settings.get_zone_group_for_row(int(floor(pos.z / float(settings.tile_size_m)))), maxf(pos.y, 0.0), 3.0, int(settings.master_seed), _row_of(pos), settings.equator_tile_row)   # the row's own winter
	@warning_ignore("confusable_local_declaration")
	items.send_worn = func(peer, numbers, insts):
		net.worn.rpc_id(peer, numbers, insts)
		players.worn_changed(peer, numbers)   # the others see the new clothes (protocol 151)
	players = PlayersScript.new()
	players.items = items
	players.send_rows = func(peer, ids, positions, yaws, states, held, times, left, more, cast): net.players.rpc_id(peer, ids, positions, yaws, states, held, times, left, more, cast)
	players.send_flight = func(peer, number, from, velocity, fire): net.flight_seen.rpc_id(peer, number, from, velocity, fire)
	items.send_flight = players.flight
	items.send_taken = func(peer, kind, points, days): net.ground_taken.rpc_id(peer, kind, points, days)   # protocol 160
	players.send_look = func(peer, about, char_name, body, code, worn_numbers): net.player_look.rpc_id(peer, about, char_name, body, code, worn_numbers)
	net.position_reported.connect(players.note_move)   # before facing_reported (report_position emits both, position first): the row's time
	net.facing_reported.connect(players.note_report)
	cues = CuesScript.new()   # other players' blows, picks and crafts heard nearby (protocol 156)
	cues.items = items
	cues.yaw_of = players.yaw_of
	items.yaw_of = players.yaw_of   # a raised shield guards the way the body faces (server_items.gd shield_share)
	cues.send_cue = func(peer, about, cue, detail, at): net.action_cue.rpc_id(peer, about, cue, detail, at)
	items.craft_working = cues.craft_working
	items.hurt_heard = cues.hurt   # an attack on a player: the gasp for the others near
	net.look_reported.connect(players.set_look)
	@warning_ignore("confusable_local_declaration")
	items.send_remains = func(peer, rows): net.remains_marks.rpc_id(peer, rows)
	@warning_ignore("confusable_local_declaration")
	items.send_thought = func(peer, line_id, text, kind): net.thought.rpc_id(peer, line_id, text, kind)
	@warning_ignore("confusable_local_declaration")
	items.send_skills = func(peer, attributes, rows): net.skills.rpc_id(peer, attributes, rows)
	items.weather_now = func(): return weather
	items.weather_at = _weather_here   # the weather over the spot itself (its row and height), as its player's client works it out
	@warning_ignore("confusable_local_declaration")
	items.send_died = func(peer, cause, point): net.died.rpc_id(peer, cause, point)
	items.cave_rescue = func(pos: Vector3): return _cave_rescue(pos) if _under_rock(pos) else []   # a player stuck in a cave's rock goes to the nearest campfire (Dave 23 Nov 2026)
	items.player_under_rock = func(pos: Vector3) -> bool: return _under_rock(pos)   # a stuck rescue is taken only for a player who is in a cave or tunnel
	items.rescue_spots = func(pos: Vector3): return _rescue_spots(pos)   # where a player passed out from cold wakes (server_items.gd _cold_out_tick)
	items.send_final_death = func(peer, cause): net.final_death.rpc_id(peer, cause)
	items.send_hit_number = func(peer, at, amount): net.hit_number.rpc_id(peer, at, amount)
	@warning_ignore("confusable_local_declaration")
	items.send_vitals = func(peer, hunger, health, weight, thirst, luck, fitness): net.vitals.rpc_id(peer, hunger, health, weight, thirst, luck, fitness)
	items.send_training = func(peer, percent): net.training.rpc_id(peer, percent)
	items.roll_new_characters = true   # a new player character rolls its attributes (data/items/attributes.json)
	items.send_food = func(peer, rows): net.food_effects.rpc_id(peer, rows)
	items.send_food_ask = func(peer, slot, number, groups): net.food_ask.rpc_id(peer, slot, number, groups)
	items.ore_near = func(pos, reach, names, depth_m):   # the ore of the baked tile a boulder at the spot is an outcrop of (TileTerrainData.ore_at), "" when none
		return generator.get_tile(generator.tile_of(pos.x, pos.z)).ore_at(pos, reach, names, depth_m)
	items.rock_near = func(pos):   # the bedrock rock under a boulder (TileTerrainData.bedrock_name_at): limestone, chalk and marble give limestone pieces
		return generator.get_tile(generator.tile_of(pos.x, pos.z)).bedrock_name_at(pos)
	items.bog_field = func(fx, fz, cfg):   # the bog iron patches of a field square on the baked tile holding it (BogIron.field; digging.json bog_iron)
		var m: float = float(cfg.get("field_m", 512.0))
		var cx: float = (float(fx) + 0.5) * m
		var cz: float = (float(fz) + 0.5) * m

		# Never read a tile on the main thread (a read takes seconds): null = not ready, asked for, and tried again on a later sync.
		if not generator.tile_cached(cx, cz):
			generator.prefetch_tile(cx, cz)
			return null

		return BogIronScript.field(generator.get_tile(generator.tile_of(cx, cz)), fx, fz, cfg)
	items.ground_open = func(points): return store.any_open(points)   # whether any point is open ground now (a bog hole never silts into a tunnel)
	items.bog_silt_at = func(x, z, cfg):   # what a dug hole on fen, marsh, swamp or bog silts back in with, 0 elsewhere (BogIron.silt_material); an unloaded tile counts as dry
		return BogIronScript.silt_material(generator.get_tile(generator.tile_of(x, z)), x, z, cfg) if generator.tile_cached(x, z) else 0
	items.fresh_water_y = func(pos, reach):   # wells and pumps (TileTerrainData.fresh_water_near): the nearest over every tile the reach touches
		var best: Vector2 = Vector2(INF, NAN)
		var coords: Dictionary = {}

		for corner in [Vector2(-reach, -reach), Vector2(reach, -reach), Vector2(-reach, reach), Vector2(reach, reach)]:
			coords[generator.tile_of(pos.x + corner.x, pos.z + corner.y)] = true

		for coord in coords:
			var near: Vector2 = generator.get_tile(coord).fresh_water_near(pos, reach)

			if near.x < best.x:
				best = near

		return best.y
	items.nearest_fresh_water = func(pos, reach):   # the drink goal's hint (server_items.gd _water_way): only tiles already loaded (never a tile read on this thread)
		var best: Vector3 = Vector3(0.0, INF, 0.0)
		var coords: Dictionary = {}
		var skipped: bool = false

		for corner in [Vector2.ZERO, Vector2(-reach, -reach), Vector2(reach, -reach), Vector2(-reach, reach), Vector2(reach, reach)]:
			if generator.tile_cached(pos.x + corner.x, pos.z + corner.y):
				coords[generator.tile_of(pos.x + corner.x, pos.z + corner.y)] = true
			else:
				skipped = true

		for coord in coords:
			var spot: Vector3 = generator.get_tile(coord).fresh_water_spot(pos, reach)

			if spot.y < best.y:
				best = spot

		return Vector3(0.0, NAN, 0.0) if best.y == INF and skipped else best   # NAN: not known yet (a tile the reach touches is not loaded)
	items.water_near = func(pos, reach): return DrinkRulesScript.water_near(generator.get_tile(generator.tile_of(pos.x, pos.z)), pos, reach, false)
	items.drink_water_near = func(pos, reach): return DrinkRulesScript.water_near(generator.get_tile(generator.tile_of(pos.x, pos.z)), pos, reach, true)   # and not down a bank (DrinkRules.REACH_DROP_M)
	items.ice_moat_at = func(pos): return IceMoatScript.in_moat(pos, ice_moat.moat_cells(pos, game_clock.seconds, settings.get_zone_group_for_row(int(floor(pos.z / float(settings.tile_size_m)))), int(settings.master_seed), _row_of(pos), settings.equator_tile_row), items.water_near)   # a thaw's open shore: a drink or fill without a hole, as the player sees it (#729)
	# The drink's source rows for vitals.json thirst.sources, from the baked tile (DrinkRules.tile_rows), with the year mean of this climate zone.
	items.water_source = func(pos, reach) -> Array:
		var group = settings.get_zone_group_for_row(int(floor(pos.z / float(settings.tile_size_m))))
		return DrinkRulesScript.tile_rows(generator.get_tile(generator.tile_of(pos.x, pos.z)), pos, reach, func(height: float) -> float: return WeatherScript.year_mean_c(group, height))
	items.water_depth_at = func(pos: Vector3) -> float:
		var water: Array = _water_at(pos)
		return 0.0 if is_nan(water[0]) else maxf(float(water[0]) - float(water[1]), 0.0)
	items.cell_reads = func(x: float, z: float) -> Dictionary: return CellReadsScript.bound(generator, water_live, x, z, _sea_cut_off)   # the four above, bound to one tile (copper and tin rocks, boulders)
	var fish_water = FishWaterScript.new(func(x: float, z: float) -> Array:
		var water: Array = _water_at(Vector3(x, 0.0, z))
		var baked: int = 0

		if generator.tile_cached(x, z):
			var tile_data = generator.get_tile(generator.tile_of(x, z))

			if not tile_data.placeholder and not tile_data.water_class.is_empty():
				baked = int(tile_data.water_class[tile_data.nearest(x, z)])

		return [water[0], water[1], baked, float(water[1]) <= 0.0 and not _sea_cut_off(x, z)])
	items.water_kind_at = func(x: float, z: float) -> Dictionary: return fish_water.water_kind_at(x, z)
	fish_signs = FishSignsScript.new()   # the schools seen: jumps and shadows near players (protocol 169)
	fish_signs.items = items
	fish_signs.surface_at = func(x: float, z: float) -> float: return float(_water_at(Vector3(x, 0.0, z))[0])
	fish_signs.ready_at = func(x: float, z: float) -> bool:
		# Never read a tile on the main thread (a read takes seconds): a cell on a tile not in memory is asked for and skipped this pass.
		if generator.tile_cached(x, z):
			return true

		generator.prefetch_tile(x, z)
		return false
	fish_signs.send_jump = func(peer: int, at: Vector3, kind: int, seed_value: int) -> void: net.fish_jump.rpc_id(peer, at, kind, seed_value)
	fish_signs.send_shadows = func(peer: int, rows: PackedFloat32Array) -> void: net.fish_shadows.rpc_id(peer, rows)
	@warning_ignore("confusable_local_declaration")
	@warning_ignore("confusable_local_declaration")
	items.send_zone = func(peer, biome_id): net.zone.rpc_id(peer, biome_id)
	items.zone_at = func(pos: Vector3) -> int:
		var tile_data = generator.get_tile(generator.tile_of(pos.x, pos.z))

		if tile_data.placeholder or tile_data.biome.is_empty():
			return -1

		return int(tile_data.biome[tile_data.nearest(pos.x, pos.z)])
	items.send_vent = func(peer_id, at: Vector3): net.vent.rpc_id(peer_id, at)
	items.vent_near = func(pos: Vector3) -> Vector3:
		var best: Vector3 = Vector3.INF
		var best_d: float = items.VENT_RANGE_M
		var tile_size: float = generator.tile_size_m

		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var px: float = pos.x + float(dx) * tile_size
				var pz: float = pos.z + float(dz) * tile_size

				# The tile under the player is read if needed; a neighbour only when it is already in memory (a read takes over a second).
				if (dx != 0 or dz != 0) and not generator.tile_cached(px, pz):
					continue

				var tile_data = generator.get_tile(generator.tile_of(px, pz))

				for body in tile_data.bodies:
					if int(body["kind"]) != 1:
						continue

					var c: Vector2 = body["center"]
					var d: float = Vector2(c.x - pos.x, c.y - pos.z).length()

					if d < best_d:
						best_d = d
						best = Vector3(c.x, float(body["top"]), c.y)

		return best
	items.send_reject = func(peer_id, reason): net.reject.rpc_id(peer_id, reason)
	@warning_ignore("confusable_local_declaration")
	items.send_craft_queue = func(peer, entries, left_ms): net.craft_queue.rpc_id(peer, entries, left_ms)
	@warning_ignore("confusable_local_declaration")
	items.send_strain = func(peer, strain_pm, state, fade_pm, stance): net.strain.rpc_id(peer, strain_pm, state, fade_pm, stance)
	@warning_ignore("confusable_local_declaration")
	items.send_chest = func(peer, id, bytes): net.chest_contents.rpc_id(peer, id, bytes)
	items.send_chest_info = func(peer, id, keep_out, may_set): net.chest_info.rpc_id(peer, id, keep_out, may_set)
	items.send_autoload_info = func(peer, id, number): net.autoload_info.rpc_id(peer, id, number)
	items.send_chest_lock = func(peer, id, locked, mine, may_open, wait_s, allowed): net.chest_lock.rpc_id(peer, id, locked, mine, may_open, wait_s, allowed)
	items.send_storage_view = func(peer, id, numbers, counts, containers): net.storage_view.rpc_id(peer, id, numbers, counts, containers)
	items.send_craft_stock = func(peer, numbers, counts): net.craft_stock.rpc_id(peer, numbers, counts)
	items.send_cart_pull = func(peer, id, pace_dms): net.cart_pull.rpc_id(peer, id, pace_dms)
	items.send_items_moved = func(peer, ids, positions, yaws): net.items_moved.rpc_id(peer, ids, positions, yaws)
	items.send_logs_moved = func(peer, ids, positions, poses): net.logs_moved.rpc_id(peer, ids, positions, poses)
	items.send_step_to = func(peer, spot, yaw): net.step_to.rpc_id(peer, spot, yaw)
	items.send_wheel_share = func(peer, spot, yaw_deg, percent, why): net.wheel_share.rpc_id(peer, spot, yaw_deg, percent, why)
	items.send_favourites = func(peer, flags): net.favourites.rpc_id(peer, flags)
	items.send_bulk_done = func(peer, kind, stacks, containers, ids): net.bulk_done.rpc_id(peer, kind, stacks, containers, ids)
	items.game_seconds = func(): return game_clock.seconds
	items.season_now = func(): return game_clock.season()   # starter-calendar: the fallback only (season_at)
	items.season_at = func(pos): return WeatherScript.season_at(game_clock.seconds, pos.z, float(settings.tile_size_m), settings.equator_tile_row)   # a place's own season (drinking water by source)
	items.season_stamp = func(): return game_clock.year() * 4 + game_clock.season_index()   # starter-calendar: the fallback only (season_stamp_at)
	items.season_stamp_at = func(pos): return WeatherScript.season_stamp_at(game_clock.seconds, _row_of(pos), settings.equator_tile_row)   # a place's own season count
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
		return "rock" if material >= Layout.MATERIAL_ROCK else str(soil_names.get(Layout.soil_of(material), "loam"))   # a wetland look digs as its soil (peat, mud)
	items.trees_near = _trees_near
	items.trees_along = _trees_along
	items.trees_near_cached = _trees_near_cached
	items.trunks_near = _arrow_trunks
	items.dig_support = func(base, radius, depth): return TreeSupport.solid_share(store.ops.edits_near(base, radius + depth), base, radius, depth)
	items.setup(ItemTableScript.load_default(), store_dir)
	items.ground_edits = func(): return store.ops.count   # the header's "digs": a hard stop drops the digs and fills after the last whole save (store.setup)

	if not items.load_failures.is_empty():
		var why: String = "SERVER NOT STARTED: these save files in %s exist but could not be read: %s. They were left as they are and nothing was saved over them. Run the server build that saved them, or restore each from its .prev copy if it has one, then start again." % [store_dir, ", ".join(PackedStringArray(items.load_failures))]
		push_error(why)
		print(why)
		_run_note("refused", 0, why)
		_refused_start = true
		get_tree().quit(3)   # never come up on an empty world over the players' saves
		return

	items.cut_felled_flora(flora)   # a stump saved before its tree's removal was (a crash between them): the tree stays cut

	admin = AdminScript.new()
	admin.load_keys([store_dir + "/admin.json"] if _dedicated else ["res://data/admin.json", store_dir + "/admin.json"])
	items.reset_terrain_edits = _reset_terrain_edits
	items.restore_flora = func() -> void: flora.restore_all()
	items.floor_below = _floor_below
	items.cave_floor = generator.cave_floor_at
	items.edits_near = func(point, radius): return store.ops.edits_near(point, radius)   # the hoe's levelling reads the ground through the saved digs and fills
	items.water_flow_at = _water_flow_at
	items.water_wheel = _water_wheel
	items.dump_water = _dump_water
	items.land_types = _land_types
	@warning_ignore("confusable_local_declaration")
	items.admin_ok = func(peer: int) -> bool: return admin.is_admin(items.key_of(peer))
	admin.open_to_all = OS.get_cmdline_user_args().has("--open-admin") and not _dedicated

	if _dedicated and OS.get_cmdline_user_args().has("--open-admin"):
		print("server: --dedicated ignores --open-admin")

	if _dedicated:
		admin.enforce = true
		print("server: dedicated; admin check on, %d admin keys in %s/admin.json" % [admin.count(), store_dir])

	npcs = NpcsScript.new()
	npcs.hour_now = func(): return game_clock.hour()
	npcs.ground_height = func(x, z): return generator.surface_height(x, z)
	npcs.blocked = func(x, z):
		var water: Array = _water_at(Vector3(x, 0.0, z))
		return not is_nan(water[0]) and float(water[0]) - float(water[1]) > 0.7
	npcs.player_positions = func(): return items.peer_positions()
	npcs.rain_now = func(): return float(weather.get("rain", 0.0))
	npcs.rain_at = func(pos): return float(_weather_here(pos).get("rain", 0.0))   # town people shelter from the rain over the town, not the starter row's
	npcs.setup(store_dir)
	tribes = TribesScript.new()
	tribes.items = items
	tribes.npcs = npcs
	tribes.game_seconds = func(): return game_clock.seconds
	tribes.players = func() -> Array:
		var rows: Array = []

		for peer in items._peer_pos:
			rows.append({"peer": peer, "key": items.key_of(peer), "pos": items._peer_pos[peer]})

		return rows
	tribes.setup(store_dir)
	npcs.wary = tribes.avoid   # goblin tribe members keep off, watch, stand guard at a weapon in hand, and hide from a player who struck one
	npcs.chores = tribes.chore_plan   # and keep busy round their camp (camp life, Dave 20 Nov 2026)
	net.held_reported.connect(func(peer: int, number: int, left: int, flags: int) -> void:
		if limits.allow(peer, "held_item"):   # a client flipping its hands as fast as it can would make every client near it rebuild a torch
			items.report_held(peer, number, left, flags))   # the item in each player's hand (protocol 146), for "a weapon in hand"
	items.rep_key = tribes.rep_id   # a tribe's members share one standing
	items.tribe_stock_line = tribes.stock_line   # what a goblin camp's chest and racks hold (the light version, Dave 20 Nov 2026)
	animals = AnimalsScript.new()
	edited_ground = EditedGroundScript.new()
	edited_ground.ops = store.ops
	edited_ground.surface = func(x, z): return generator.surface_height(x, z)
	animals.ground_height = edited_ground.height   # the ground with every dig and fill (edited_ground.gd): animals walk on and drop to it
	items.ground_now = edited_ground.height   # where carcasses, arrows, thrown things, litter and regrown plants come down (round 7)
	animals.ground_edited = edited_ground.is_edited
	animals.blocked = npcs.blocked
	animals.walls = func(x0, z0, x1, z1, margin): return items.structure_blocks_step(x0, z0, x1, z1, margin)
	animals.in_cave_at = _in_cave   # no blow through a cave roof (server_animals.blow_blocked)
	animals.water_level = func(x, z):
		var water_here: Array = _water_at(Vector3(x, 0.0, z))
		return float(water_here[0]) if not is_nan(water_here[0]) else NAN
	# The ground springs near a point, for drink_spot (animals go to a spring first: docs/design/spring_heads_lower_design.md 3).
	animals.springs_near = func(point: Vector3, reach: float) -> PackedVector3Array:
		var heads: PackedVector3Array = PackedVector3Array()
		var seen: Dictionary = {}

		for corner in [Vector2(-reach, -reach), Vector2(reach, -reach), Vector2(-reach, reach), Vector2(reach, reach)]:
			var tile = generator.tile_of(point.x + corner.x, point.z + corner.y)

			if seen.has(tile):
				continue

			seen[tile] = true
			var data = generator.get_tile(tile)

			if data == null or data.placeholder:
				continue

			for spring in data.ground_springs:
				var head: Vector3 = spring[0]

				if Vector2(head.x - point.x, head.z - point.z).length() <= reach:
					heads.append(head)

		return heads
	animals.player_positions = npcs.player_positions
	animals.player_stances = func(): return items.peer_stances()
	animals.wind = func(): return weather
	items.rain_hours_at = _rain_hours_at   # the drink rule's hours since rain, where the player drinks
	animals.weather_at = _weather_here   # each animal by the weather where it stands (its row and height), as players are
	coarse_ground.net = net
	coarse_ground.tiles_dir = world_dir + "/tiles"
	coarse_ground.tile_size_m = float(settings.tile_size_m)
	animals.fog_world = {"tiles_dir": world_dir + "/tiles", "tile_size_m": float(settings.tile_size_m)}   # the cold-air floor for animals' sight in fog (fog_ground.gd)
	animals.weather_ahead_at = func(hours, pos):   # a storm coming to the animal's own row (animals_in_weather_design.md 3; not the starter row's)
		var row: int = floori(pos.z / float(settings.tile_size_m))
		return WeatherScript.state(settings.master_seed, game_clock.seconds + float(hours) * 3600.0, settings.get_zone_group_for_row(row), 0.0, 0.0, row, settings.equator_tile_row)
	animals.row_of = func(pos): return floori(pos.z / float(settings.tile_size_m))
	animals.canopy = func(point): return flora.covered(point)
	animals.air_at = func(pos):   # Weather.air_c at the animal (#620): its own row's zone and season (across the equator too) and its height
		var row: int = floori(pos.z / float(settings.tile_size_m))
		return WeatherScript.air_c(game_clock.seconds, settings.get_zone_group_for_row(row), maxf(pos.y, 0.0), int(settings.master_seed), row, settings.equator_tile_row)
	animals.ice_cover_at = items.ice_cover_at   # the same ice as the players' (animals_on_ice_server.md)
	animals.ice_moat_at = items.ice_moat_at     # and the same open moat in a thaw
	animals.game_seconds = func(): return game_clock.seconds
	animals.thunder_between = func(t0, t1, centre, reach): return ThunderScript.strikes(int(settings.master_seed), t0, t1, _weather_at(centre), centre, reach)   # the shared strikes, under that player's own weather (birds_and_thunder_server.md)
	animals.canopy_ready = func(x, z): return _cover_ready(Vector3(x, 0.0, z))
	animals.undergrowth = func(point): return flora.in_undergrowth(point)
	animals.player_stalk = func(): return items.peer_stalk_factors()
	animals.player_loud = func(): return cues.loud_kinds()   # a blow, a cry or craft work carries farther to animals (hearing-range pass)
	animals.hour_now = func(): return game_clock.hour()
	animals.sun_row_m = float(settings.tile_size_m)
	animals.sunrise_now = func(z): return WeatherScript.sunrise_hour(WeatherScript.year_phase(game_clock.seconds) * float(GameClockScript.DAYS_PER_YEAR), NAN if is_nan(z) else ClimateScript.latitude_of_row(ClimateScript.row_of_z(z, float(settings.tile_size_m)), settings.equator_tile_row))   # the sun the sky draws (weather.gd slope_breeze uses the same): animal periods and trips follow it. starter-calendar: the declination is the one sky's, the latitude the row's
	animals.season_now = func(): return game_clock.season()   # starter-calendar: the fallback only (season_at)
	items.night_skip = func(peers: Array) -> float: return _night_skip_real_s(peers)
	animals.equator_row = settings.equator_tile_row
	animals.season_at = items.season_at   # an animal's seasons (young, the rut's threat) where it is
	flora.season_at = items.season_at   # bare winter broadleaves shelter nothing (docs/design/cover_by_season_design.md), by each spot's own season
	var biome_names: Dictionary = {}

	for biome_entry in tables.get_entries("biomes"):
		biome_names[int(biome_entry["id"])] = str(biome_entry["name"])

	animals.biome_at = func(x, z):
		var tile_data = generator.get_tile(generator.tile_of(x, z))
		return "" if tile_data.placeholder else str(biome_names.get(int(tile_data.biome[tile_data.nearest(x, z)]), ""))
	animals.fresh_water_m = func(x, z):   # baked distance to a river or lake (Stage E, tile fresh_m section); NAN in tiles baked before it
		var fresh_tile = generator.get_tile(generator.tile_of(x, z))
		return fresh_tile.fresh_water_m(x, z)
	animals.lair_mouths = func(x, z):   # the mouths of the inland caves with a goblin den (TileTerrainData.goblin_den_nodes) in the tile the player stands in (already loaded, so no wait); goblin groups come out of them
		var lair_tile = generator.get_tile(generator.tile_of(x, z))
		return PackedVector2Array() if lair_tile.placeholder else lair_tile.goblin_den_mouths
	animals.cave_den_mouths = func(x, z, sp):   # the mouths of the caves a species dens in (TileTerrainData.animal_den_species) in the tile there, if it is loaded (a wolf cell may reach a tile nobody stands on: no wait); bears, wolves and foxes are made at them
		if not generator.tile_cached(x, z):
			return PackedVector2Array()

		var den_tile = generator.get_tile(generator.tile_of(x, z))
		return PackedVector2Array() if den_tile.placeholder else den_tile.animal_den_mouths.get(sp, PackedVector2Array())
	animals.lair_path = func(x, z):   # the cave floor path from a goblin den's mouth (x, z) to the den (tile goblin_den_paths); empty when none is known
		var path_tile = generator.get_tile(generator.tile_of(x, z))

		if path_tile.placeholder:
			return PackedVector3Array()

		for k in mini(path_tile.goblin_den_mouths.size(), path_tile.goblin_den_paths.size()):
			if path_tile.goblin_den_mouths[k].distance_to(Vector2(x, z)) <= 1.0:
				return path_tile.goblin_den_paths[k]

		return PackedVector3Array()
	animals.berry_bushes = _berries_near_cached   # goblins forage at night (docs/design/goblin_den_life_design.md 2.3)
	animals.no_spawn = func(x, z): return items.spawn_blocked(x, z)   # no animal is made within no_spawn_m of anything put down (Dave 17 Nov 2026)
	animals.lair_guarded = func(x, z, radius): return items.lit_fire_near(Vector3(x, 0.0, z), radius)   # a burning placed fire near a lair's mouth keeps a killed band from coming back
	animals.setup()
	trails = TrailsScript.new()
	trails.game_seconds = func(): return game_clock.seconds
	trails.ground_height = edited_ground.height   # with digs and fills: a player in a dug hole still wears a path
	trails.setup(store_dir)
	animals.trails = trails
	ranges = RangesScript.new()
	ranges.setup()
	ranges.world_seed = items.world_seed
	ranges.ground_height = edited_ground.surface   # the generated ground: the places come out the same whatever has been dug
	ranges.blocked = npcs.blocked
	ranges.biome_weight = func(sp, x, z): return animals.biome_weight(animals.species_def(sp), x, z)
	ranges.no_spawn = animals.no_spawn
	ranges.ground_ready = items.ground_ready
	animals.ranges = ranges
	trails.ranges = ranges
	map_knowledge = MapScript.new()
	map_knowledge.key_of = func(peer): return items.key_of(peer)
	map_knowledge.skill_of = func(peer): return items.working_level(peer, "mapping")
	map_knowledge.practice = func(peer): return items.practice(peer, "survey")
	map_knowledge.goal_event = func(peer, event): items._goal_event(peer, event)
	map_knowledge.observe = _map_observe
	map_knowledge.trees_near = func(point, radius): return _cached_trees(point, radius).map(func(tree): return tree[1]) if flora != null else []
	map_knowledge.in_cave = _in_cave
	map_knowledge.landmarks_near = _map_landmarks
	map_knowledge.setup(store_dir)
	items.map_look = func(peer, at): map_knowledge.look_now(peer, at)
	items.fish_caught = func(peer, at): map_knowledge.note_catch(peer, at)
	items.forgot_key = func(key): map_knowledge.forget_key(key)
	animals.wolves.player_info = func(): return items.wolf_info()
	animals.wolves.heard_of = func(peer): return animals.heard_x(cues.loud_of(peer))   # a pack hears loud work too (hearing-range pass)
	# Every wild animal keeps out of a fire's or a torch's keep-off radius (Dave 6 Nov 2026). The fires come from _fire_spots, worked out from the world
	# items FIRE_SPOTS_MS apart (_refresh_fire_spots): the animals asked for every fire's radius every frame, and each ask walked every record.
	animals.wolves.fires = func(): return _fire_at
	animals.wolves.fire_radius = func(at): return float(_fire_keep_off[at]) if _fire_keep_off.has(at) else items.fire_protect_m(at)
	animals.fires = func(): return _fire_at
	animals.fire_radius = func(at): return float(_fire_keep_off[at]) if _fire_keep_off.has(at) else items.fire_protect_m(at)
	@warning_ignore("confusable_local_declaration")
	animals.wolves.hurt_player = func(peer, amount, lethal, cause, from): return items.hurt_player(peer, amount, lethal, cause, float(animals.cfg.get("wolves", {}).get("maim_hp", 25.0)), "", 0.0, from)
	@warning_ignore("confusable_local_declaration")
	animals.wolves.notice = func(peer, text): items._say(peer, text)
	@warning_ignore("confusable_local_declaration")
	animals.wolves.take_meat = func(peer): return items.take_all_meat(peer)
	animals.big_game.player_info = func(): return items.wolf_info()
	animals.thieves.loose_food = func(centre, r): return items.loose_food_near(centre, r)
	animals.thieves.food_at = func(id): return items.loose_food_pos(id)   # a fox after one piece reads it by id
	animals.thieves.take_food = func(id): return items.take_loose(id)
	animals.goblins.stealable = func(centre, r): return items.stealable_near(centre, r)   # goblins steal one small unlit thing at a time and pile it in their den
	animals.goblins.take_one = func(id): return items.take_one(id)
	animals.goblins.hoard_drop = func(number, count, pos, life_s): return items.drop_world_made(number, count, pos, life_s)
	animals.goblins.gift_drop = func(number, count, pos, by): return items.drop_world_made(number, count, pos, 0.0, by)
	animals.goblins.item_number = func(id): return items.table.number_of(id)
	animals.goblins.peer_key = func(peer): return items.key_of(peer)
	animals.goblins.trust.game_seconds = func(): return game_clock.seconds
	animals.goblins.trust.store_dir = store_dir
	animals.goblins.trust.load_records()   # goblin_trust.json: friendship per band and character
	animals.companions.peer_key = func(peer): return items.key_of(peer)
	animals.companions.game_seconds = func(): return game_clock.seconds
	animals.companions.ground_items = func(centre, r): return items.stealable_near(centre, r)   # food a player left for a stray, or for their dog
	animals.companions.take_item = func(id): return items.take_one(id)
	animals.companions.store_dir = store_dir
	animals.companions.load_records()   # companions.json: each companion's name, bond, owner and life story (dog_companion_design.md)
	animals.wolves.game_seconds = func(): return game_clock.seconds
	animals.wolves.store_dir = store_dir
	animals.wolves.load_dens()   # wolf_dens.json: killed packs' dens resting, and their orphans (wolf_packs_and_pups_design.md)
	animals.thieves.fires = func(): return animals.wolves.fires.call() if animals.wolves.fires.is_valid() else []
	animals.drop_loot = func(number, count, pos): items.drop_world_made(number, count, pos)
	@warning_ignore("confusable_local_declaration")
	animals.big_game.hurt_player = func(peer, amount, lethal, cause, from): return items.hurt_player(peer, amount, lethal, cause, 10.0, "", 0.0, from)
	animals.big_game.hurt_armed = func(peer, amount, lethal, cause, from, weapon):
		var blow: Dictionary = ItemsScript.weapon_blow(items.table.entry(str(weapon)), {})
		return items.hurt_player(peer, amount, lethal, cause, 10.0, str(blow["mode"]), float(blow["pen"]), from)
	@warning_ignore("confusable_local_declaration")
	animals.died = func(sp, pos, peer):
		if sp == "bandit" or sp == "horse":
			bandits.fallen(sp, pos)   # a camp's bandit leaves its site's row and drops its gear; a camp horse is one fewer (docs/design/BANDIT_CAMPS.md)

		items.make_carcass(sp, pos, peer)
	@warning_ignore("confusable_local_declaration")
	animals.send_hit = func(peer, id, zone, at): net.animal_hit.rpc_id(peer, id, zone, at)
	items.hit_animal_path = func(shooter, from, to, amount, lag) -> Dictionary:
		var member: String = tribes.member_on_segment(from, to)

		if member != "":   # a goblin tribe member cannot be hurt (Dave's side, 19 Nov 2026): the tribe turns on the archer and the arrow flies on
			tribes.harm(shooter, member)

		var now: int = Time.get_ticks_msec()   # lag (server_items.shot_lag): the animals are taken where the shooter sees them at this moment
		var seen_at: int = now - int(lag[0]) if lag.size() == 2 else -1
		var present_at: int = now - int(lag[1]) if lag.size() == 2 and int(lag[1]) >= 0 else -1
		var found: Dictionary = animals.target_on_segment(from, to, 0.6, 0.5, seen_at, present_at)

		if found.is_empty():
			return {}

		animals.damage(int(found["id"]), amount, shooter, "arrow")
		animals.report_hit(int(found["id"]), int(found.get("zone", 0)), found.get("point", found["at"]))   # every player near sees which animal and where (hunt_feedback_server.md)
		return found
	items.animal_alarm = func(point, radius): animals.alarm_near(point, radius)

	if OS.get_cmdline_user_args().has("--robot-audit"):   # the robot play-testers' server lines (src/server/robot_audit.gd, tools/robots.sh); testing only
		var audit: Node = preload("res://src/server/robot_audit.gd").new()
		add_child(audit)
		audit.setup(items, animals)

	items.nests_near = func(point, reach): return animals.nests_near(point, reach)
	items.animals_near = func(point, radius): return animals.list_near(point, radius)
	items.animal_snare = func(id): return animals.snare(id)
	animals.snare_pass = func(id, sp, from, to): items.animal_passed(id, sp, from, to)
	items.trail_strength = func(x, z): return trails.strength_at(x, z)
	items.run_distance = func(x, z, kind): return ranges.route_distance(x, z, kind)
	items.fox_near = func(x, z, m): return ranges.fox_near(x, z, m)
	items.species_active = func(sp): return animals.activity_chance(animals.species_def(sp))
	items.species_active_at = func(sp, hour, z): return animals.activity_at(animals.species_def(sp), hour, z)   # by the sun of the snare's row
	@warning_ignore("confusable_local_declaration")
	items.hit_animal = func(peer, origin, dir, reach, amount) -> Dictionary:
		var member: String = tribes.member_along(origin, dir, reach)

		if member != "" and animals.wall_between(origin, npcs.npcs[member]["pos"]):
			member = ""   # a tribe member behind a wall is out of reach of the blow, as an animal is (server_animals.target_along)

		var seen: Array = items.strike_seen.get(peer, [-1, -1])   # protocol 155: judged where the player saw the animals, at most rewind_max_ms back
		var target: int = animals.target_along(origin, dir, reach, int(seen[0]), int(seen[1]))
		var member_d: float = Vector2(npcs.npcs[member]["pos"].x - origin.x, npcs.npcs[member]["pos"].z - origin.z).length() if member != "" else INF
		var animal_d: float = Vector2(animals.animals[target]["pos"].x - origin.x, animals.animals[target]["pos"].z - origin.z).length() - AnimalContact.body_m(str(animals.animals[target]["sp"])) if target != 0 else INF   # to its body, as target_along

		if member != "" and member_d <= animal_d:   # a blow at a goblin tribe member (the nearer one) hurts nobody: the tribe turns on that player (server_tribes.gd harm)
			tribes.harm(peer, member)
			return {}

		if target == 0:
			return {}

		var point: Vector3 = animals.jab_point(target, origin, dir, reach, 0.5, int(seen[0]), int(seen[1])) + animals.moved_since(target, int(seen[0]), int(seen[1]))   # struck where the player saw it; that spot on the body now
		var zone: int = animals.hit_zone(target, point)
		animals.report_hit(target, zone, point)   # before the damage: a killing blow still reaches the players near (the flesh sound and the flinch)
		animals.damage(target, amount, peer, "spear")
		return {"at": point}
	dialogue = DialogueScript.new()
	dialogue.items = items
	dialogue.npcs = npcs
	trade = TradeScript.new()
	trade.items = items
	trade.npcs = npcs
	trade.game_seconds = func(): return game_clock.seconds
	trade.setup(store_dir)
	trade.in_save_set(items)   # shelves land in the same whole save as the packs that paid
	@warning_ignore("confusable_local_declaration")
	trade.send_shop = func(peer, npc_id, title, ids, pay, got, buys, tired_ids, tired, stock, supply_milli, purse): net.shop.rpc_id(peer, npc_id, title, ids, pay, got, buys, tired_ids, tired, stock, supply_milli, purse)
	dialogue.trade = trade
	trade.refuse = tribes.refuse   # a goblin tribe member may refuse: angry, hidden, a weapon on show, rushed
	trade.dealt = tribes.note_deal   # a deal with a member earns standing with its tribe
	@warning_ignore("confusable_local_declaration")
	net.trade_requested.connect(func(peer, npc_id, kind, a, count):
		var said: String = trade.deal(peer, npc_id, kind, a, count)

		if said != "":
			items._say(peer, said)

			if tribes.refuse(peer, npc_id, false) == "":   # a refused deal (an angry tribe) has said why once: no window again
				trade.open(peer, npc_id))   # the window is sent again with the new demand
	items.npc_name = func(id): return tribes.name_of_rep(id) if tribes.name_of_rep(id) != "" else str(npcs.npcs.get(id, {}).get("name", id))   # a tribe's standing is named for the tribe
	dialogue.hour_now = func(): return game_clock.hour()
	@warning_ignore("confusable_local_declaration")
	dialogue.send_say = func(peer, id, npc_name, text, voice, choices, ends): net.npc_say.rpc_id(peer, id, npc_name, text, voice, choices, ends)
	dialogue.refuse = tribes.refuse
	dialogue.setup(store_dir)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--npc-ai="):
			dialogue.router.mode = arg.substr(9)   # auto, static, ai or down (pretend the AI is dead: NPCs are unwell)

	spawn = _spawn_point(world_dir)
	animals.town = npcs.town_point()   # the island level and the stray dogs centre on the starter town's markers, never on the spawn (no_spawn_placement_design.md 3)
	bandits = BanditsScript.new()
	bandits.world_seed = items.world_seed
	bandits.town = animals.town
	bandits.spawn = Vector2(spawn.x, spawn.z)
	bandits.game_seconds = func(): return game_clock.seconds
	bandits.ground_height = func(x, z): return generator.surface_height(x, z)
	bandits.ground_ready = func(x, z): return generator.tile_cached(x, z)   # the hourly check never reads a tile from disk (1.8 to 4 s)
	bandits.in_water = npcs.blocked
	bandits.building_near = func(site_at, reach_m): return items.building_near(site_at, reach_m)
	bandits.tribe_camps = tribes.camp_spots   # no bandit site on a goblin tribe's ground
	bandits.cave_mouths_at = func(mouth_x, mouth_z):   # the cave, den and mine mouths of a loaded tile (mines load as caves); null while unloaded
		if not generator.tile_cached(mouth_x, mouth_z):
			return null

		var mouths: Array = []

		for row in generator.get_tile(generator.tile_of(mouth_x, mouth_z)).cave_mouths:
			mouths.append(Vector2((row[0] as Vector3).x, (row[0] as Vector3).z))

		return mouths
	bandits.road_distance = func(site_at, reach_m): return items.road_distance(site_at, reach_m)
	bandits.road_point = func(site_at, reach_m): return items.road_point(site_at, reach_m)
	bandits.setup(store_dir)
	bandits.animals = animals
	TreeTrunks.warm()   # the trunk collider table (_cached_trees), read once at start
	bandits.trees_at = func(camp_at: Vector2, camp_reach: float) -> Variant:   # the trunks round a camp fire, null until every chunk under it is made (no flora is made for it)
		var made: float = camp_reach + TreeTrunks.widest_m()   # a wide trunk (everember) is listed from its root, up to widest_m beyond the camp
		for corner in [Vector2(-made, -made), Vector2(made, -made), Vector2(-made, made), Vector2(made, made)]:
			if flora.items_cached(flora.placer.chunk_of(camp_at.x + corner.x, camp_at.y + corner.y)).is_empty():
				return null

		var feet: Array = []

		for trunk in _arrow_trunks(Vector3(camp_at.x, 0.0, camp_at.y), camp_reach):
			feet.append([Vector2(trunk[0].x, trunk[0].z), float(trunk[1])])

		return feet
	animals.bandit_camps = bandits
	animals.big_game.weapon_of = bandits.weapon_of   # a bandit's blow is his weapon's kind (a sword cuts), not a beast's
	animals.big_game.ping_ms = func(ping_peer): return _ping_ms(int(ping_peer))   # a fair dodge: a goblin's or bandit's blow judged once the player's step has come back
	bandits.lay_camp = func(camp_key, camp_fire, camp_lean_tos, camp_old, camp_tracks, camp_tracks_at): return items.lay_bandit_camp(camp_key, camp_fire, camp_lean_tos, camp_old, camp_tracks, camp_tracks_at)
	bandits.clear_camp = func(camp_key, camp_ids): items.clear_bandit_camp(camp_key, camp_ids)   # a site gone back to sleep takes its pit and tracks away
	bandits.laid_still = func(camp_ids): return items.bandit_camp_there(camp_ids)
	bandits.drop_gear = func(gear_key, gear_at): items.drop_world_made(items.table.number_of(gear_key), 1, gear_at)
	bandits.tell = func(bandit_peer, bandit_text): items._say(bandit_peer, bandit_text)
	bandits.ask = func(bandit_peer, talk_id, talk_name, talk_text, talk_choices): net.npc_say.rpc_id(bandit_peer, talk_id, talk_name, talk_text, "", PackedStringArray(talk_choices), false)   # stage 4 toll: the NPC talk window (only while robbery.enabled)
	bandits.take_coins = func(bandit_peer, bandit_copper): return items.take_coins(bandit_peer, bandit_copper)
	bandits.key_of = func(bandit_peer): return items.key_of(bandit_peer)
	bandits.rob_player = func(bandit_peer, bandit_stacks): return items.rob_stacks(bandit_peer, bandit_stacks)   # stage 4b, only while robbery.enabled
	bandits.drop_stash = func(stash_id, stash_count, stash_wear, stash_inst, stash_at): return items.drop_in_world(items.table.number_of(stash_id), stash_count, stash_at, stash_wear, 2.0e8, NAN, NAN, "", stash_inst)   # a lifetime over 1e8 never ages away
	bandits.flush_world = func(): items.save()
	animals.big_game.struck = func(struck_animal, struck_peer, struck_result): bandits.struck(struck_animal, struck_peer, struck_result)   # a landed charge (it changes nothing about the blow)
	bandits.pay_bounty = func(bandit_peer, bandit_copper): items.add_coins(bandit_peer, bandit_copper, "trade")   # the guard pays for a tied bandit (stage 5)
	bandits.captor_absent = items.is_absent   # a captive waits for a captor whose line dropped
	bandits.guards_at = func():
		var guard_spots: Array = []

		for npc_id in npcs.npcs:
			if str(npcs.npcs[npc_id]["role"]) == "guard" and bool(npcs.npcs[npc_id]["placed"]):
				guard_spots.append(npcs.npcs[npc_id]["pos"])

		return guard_spots
	items.bind_animal = func(bandit_peer, bind_from, bind_dir, bind_reach):   # Rope or Twine: ties a bandit who gave up, or claims a cleared camp's horse (5b)
		var bind_target: int = animals.target_along(bind_from, bind_dir, bind_reach)
		return bandits.bind(bind_target, bandit_peer) or bandits.claim_horse(bind_target, bandit_peer)
	items.road_trip = func(mover, mover_at, trip_kind): bandits.note(mover, mover_at, trip_kind)

	for site_line in bandits.report():
		print(site_line)

	items.respawn_point = spawn
	items.start_resources(world_dir + "/tiles", float(settings.tile_size_m), spawn, _resource_dangers())   # the island resource landscape, built on a worker thread before the first scatter
	_world_dir = world_dir
	_start_water()

	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	# One seat more than the players: ENet turns a peer past its limit away before any message, so the game could not tell "full" from
	# "down". The extra peer is let in only to be told the server is full (hello, below) and dropped.
	var error: int = server_peer.create_server(port, max_players + 1)

	if error != OK:
		push_error("Terrain server: cannot listen on port %d (%s)" % [port, error_string(error)])
		_events.start("telemetry_server_failed.log", _log_dir())
		_events.event("cannot listen on port %d (%s): another server may still be running on it" % [port, error_string(error)])
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = server_peer
	# Every client passes the join handshake before it counts as connected: an open server lets it straight through, a server with a password
	# checks it first (server_auth.gd). Until then the client gets no welcome and none of its calls are heard.
	_auth.protocol = NetScript.PROTOCOL_VERSION   # a client of another protocol is told why at the first word (161), before any call it would misread
	_auth.password_hash = _server_settings.password_hash
	_auth.salt = _server_settings.salt
	_auth.address_of = func(peer: int) -> String: return server_peer.get_peer(peer).get_remote_address() if server_peer.get_peer(peer) != null else "?"
	_auth.log_event = func(text: String) -> void: _events.event(text)
	_auth.attach_server(multiplayer as SceneMultiplayer)
	_events.start("telemetry_server_%d.log" % port, _log_dir())
	_events.watch_extra = _pool_summary
	_events.start_watchdog()
	_events.event("server listening on port %d after %d ms of start-up, %s, ram %d MB, commit %s" % [port, Time.get_ticks_msec(), OS.get_name(), int(OS.get_static_memory_usage() / 1048576.0), _commit])
	_listen_port = port
	_run_note("running", port)
	# Build the flora of the spawn's chunk once here, before any other thread exists. Start-up
	# crash (owner thread bug, build 204): about 1 start in 10 to 20 a worker thread died in the
	# flora placer (flora_placer.gd patch_at, signal 11) right after the first client connected,
	# when several workers made their first flora chunk at the same moment. Not reproduced here
	# in 90 starts; this makes the first call of every placer function happen on one thread.
	flora.chunk_bytes(Vector2i(int(floor(spawn.x / placer.chunk_m)), int(floor(spawn.z / placer.chunk_m))), true)
	flora.chunk_bytes(Vector2i(int(floor(spawn.x / placer.chunk_m)) + 1, int(floor(spawn.z / placer.chunk_m))), false)
	generator.prefetch_around(spawn.x, spawn.z, JOIN_TILE_MARGIN_M)   # the tiles the first join's far ground needs, read in parallel now, after the flora warm-up above (JOIN_TILE_MARGIN_M)
	_link = BlockLinkScript.new()
	_link.on_request = _on_blocks_requested
	_link.is_peer = _is_connected_peer
	_link_port = _link.start(port + 1)
	_publish_status()

	if _link_port == 0:
		print("Terrain server: no block line (port %d is taken); blocks go over the game connection" % (port + 1))

	multiplayer.peer_connected.connect(func(peer_id: int) -> void:
		var t0: int = Time.get_ticks_usec()
		_on_peer_connected(peer_id)
		_slow_rpc("peer_connected", t0))
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	net.blocks_requested.connect(func(peer_id, keys, urgent) -> void:
		var t0: int = Time.get_ticks_usec()
		_on_blocks_requested(peer_id, keys, urgent)
		_slow_rpc("blocks_requested", t0))
	net.dig_requested.connect(_on_dig_requested)
	net.sign_spotted_requested.connect(func(peer_id, x, z) -> void:   # a trail sign spotted (153): Tracking, once per sign (server_traps sign_found)
		if is_finite(float(x)) and is_finite(float(z)):
			items.sign_spotted(int(peer_id), Vector2(float(x), float(z))))
	net.edits_since_requested.connect(func(peer_id, tile, since) -> void:
		var t0: int = Time.get_ticks_usec()
		_on_edits_since_requested(peer_id, tile, since)
		_slow_rpc("edits_since_requested", t0))
	net.summits_requested.connect(_on_summits_requested)
	net.fog_cells_requested.connect(_on_fog_cells_requested)
	net.flora_requested.connect(func(peer_id, chunks) -> void:
		var t0: int = Time.get_ticks_usec()
		_on_flora_requested(peer_id, chunks)
		_slow_rpc("flora_requested", t0))
	net.cut_flora_requested.connect(_on_cut_flora_requested)
	net.cut_swath_requested.connect(_on_cut_swath_requested)
	net.position_reported.connect(func(peer_id, position, velocity) -> void:
		var t0: int = Time.get_ticks_usec()
		_on_position_reported(peer_id, position, velocity)
		_slow_rpc("position_reported", t0))
	net.water_rate_requested.connect(_on_water_rate_requested)
	net.water_requested.connect(func(peer_id, chunks) -> void:
		var t0: int = Time.get_ticks_usec()
		_on_water_requested(peer_id, chunks)
		_slow_rpc("water_requested", t0))
	net.forget_requested.connect(func(peer, key): items.forget_key(peer, identity.store_key(identity.authenticate(peer, key))))
	@warning_ignore("confusable_local_declaration")
	net.hello_requested.connect(func(peer, key, build):
		var t0: int = Time.get_ticks_usec()

		if _peers.has(peer) and _peers[peer].has("refused"):
			return   # refused once: a later hello from the same connection is never let in while it is being closed

		var refused: String = BuildStamp.refusal(_stamped_build, build)

		if refused != "":
			_refuse_join(peer, build, refused)
			return

		var account: String = identity.authenticate(peer, key)

		if account == "":
			return

		if _full_for(peer, identity.store_key(account)):
			_refuse_join(peer, build, SERVER_FULL % max_players)
			return

		if _peers.has(peer):
			_peers[peer]["player"] = true   # counted by _full_for from here on

		_slow_rpc("hello: authenticate", t0)
		for old_peer in items.peer_connected_hello(peer, identity.store_key(account)):
			print("Peer %d is the same character as peer %d: the older connection is dropped" % [peer, old_peer])
			bandits.captor_back(old_peer, peer)   # a bandit they tied waits for this connection now

			_drop_replaced(old_peer)

		_slow_rpc("hello: peer_connected_hello", t0)
		net.admin_status.rpc_id(peer, admin.is_admin(items.key_of(peer)))   # protocol 134: the client's Admin menu follows it
		net.npc_roster.rpc_id(peer, npcs.roster())
		var resume: Array = items.start_position_for(peer)

		if resume.size() == 3:
			generator.prefetch_around(float(resume[0]), float(resume[2]), JOIN_TILE_MARGIN_M)   # a returning player's far ground, read in parallel, started before _resume_spot's own tile read (JOIN_TILE_MARGIN_M)
			net.start_at.rpc_id(peer, _resume_spot(Vector3(float(resume[0]), float(resume[1]), float(resume[2]))))

		_slow_rpc("hello: done", t0))
	net.logout_requested.connect(func(leaving): items.note_logout(leaving))
	net.tunnel_setting_requested.connect(_on_tunnel_setting)
	net.admin_place_requested.connect(_on_admin_place)
	@warning_ignore("confusable_local_declaration")
	net.npc_talk_requested.connect(func(peer, npc_id, choice):
		if not bandits.toll_answer(peer, npc_id, choice):   # a bandit's toll (stage 4, only while robbery.enabled) answers in the talk window
			dialogue.talk(peer, npc_id, choice))
	net.surface_requested.connect(func(peer_id, x, z) -> void:
		var t0: int = Time.get_ticks_usec()
		_on_surface_requested(peer_id, x, z)
		_slow_rpc("surface_requested", t0))
	net.dump_requested.connect(_on_dump_requested)
	@warning_ignore("confusable_local_declaration")
	net.inventory_action_requested.connect(func(peer, kind, a, b, count, at):
		var cue_before: Array = []

		if cues != null:
			cues.note_action(peer, kind, a, b, count, at)   # before the action: a carcass's last cut or the blow that breaks the tool still reads what was there
			cue_before = cues.before_action(peer, kind, a, b)

		items.action(peer, kind, a, b, count, at)

		if cues != null and not cue_before.is_empty():
			cues.after_action(peer, kind, a, b, cue_before)   # after: a container, a drink or a pickup is heard only when the server let it through

		if players != null:
			players.note_action(peer, kind, count))
	@warning_ignore("confusable_local_declaration")
	net.pipe_lay_requested.connect(func(peer, slot, from, to): items.pipe_lay(peer, slot, from, to))
	_report_at_msec = Time.get_ticks_msec() + 10000

	for n in range(_max_running):
		var thread: Thread = Thread.new()
		thread.start(_worker_loop, Thread.PRIORITY_LOW)   # low: on a player's PC (Play) the client's render, mesh and audio threads come first (Dave 2 Nov 2026: 4-10 s freezes with 11 server threads on 12 cores)
		_workers.append(thread)

	if OS.has_environment("DYNASTY_IDLE_THREADS"):
		_idle_threads = maxi(int(OS.get_environment("DYNASTY_IDLE_THREADS")), 0)

	_make_idle_offsets()
	_seed_idle_spots()

	for n in range(_idle_threads):
		var idle: Thread = Thread.new()
		idle.start(_idle_loop, Thread.PRIORITY_LOW)
		_idle_workers.append(idle)

	print("Terrain server listening on port %d with %d worker threads and %d idle builders (%d usable CPUs of %d%s); store %s; spawn %s" % [port, _max_running, _idle_threads, _usable_cpus, OS.get_processor_count(),
		", CPU setting %d" % _cpus_setting if _cpus_setting > 0 else "", store_dir, str(spawn)])


# Owner (2026-10-19): spawn here (x, z in meters) instead of the baked spot at the bay
# head. Set to Vector2.ZERO to use the baked spot again.
# Moved 32 m north on 2026-10-21 (was z 68448): at the x10 flow that spot is on the pond A rim in
# 0.9 m of water; this one is on the flat 28.8 m bench, three squares from any water.
# Dave (2026-10-21 18:13) asked for exactly x 53301, z 68427, where he stood on grass by the lake (ground about 29.9 m).
# Before that he used x 53318, z 68473 as a temporary spawn. That is the pond A shore in about 0.9 m
# of water (you land just above it, the 6 s landing protection applies, deep or shallow water is a safe landing). The dry
# alternative, 12 m east on the 28.8 m shore bench, is Vector2(53330.0, 68466.0).
# Checked 31 Oct 2026 (tools/spawn_probe.gd, test_spawn_dry): in the current world this spot is dry, ground 31.6 m, the nearest settled water 113 m away and 7 m lower; the 0.9 m of
# water noted above was the old x10 flow. The guide's dark rippled plane here came from the build before the tile height fix (31 Oct), not from a pond.
const SPAWN_OVERRIDE := SpawnPointScript.OVERRIDE   # the one source (src/shared/spawn_point.gd), shared with the flora placer's starter clearing


# The spawn: the starter tile's spawn picked by rule (starter.spawn_picked), or SPAWN_OVERRIDE when the tile has none (spawn_point.gd), moved
# off any tree or shrub within 2 m to the nearest clear, dry, level spot (spawn_point.gd clear_of; no_spawn_placement_design.md 2).
func _spawn_point(world_dir: String) -> Vector3:
	var picked: Vector2 = SpawnPointScript.use_world(world_dir)
	var at: Vector2 = SpawnPointScript.clear_of(picked, _trunks_near(picked, 32.0), func(x: float, z: float) -> float: return float(generator.surface_height(x, z)),
		func(x: float, z: float) -> bool: return _baked_wet(x, z))

	if at != picked:
		print("spawn: moved %.1f m off a tree or shrub, to x %.1f z %.1f" % [at.distance_to(picked), at.x, at.y])
		SpawnPointScript.set_current(at)

	var point: Vector3 = Vector3(at.x, 0.0, at.y)
	point.y = maxf(generator.surface_height(point.x, point.z), 0.0) + 2.0
	return point


# The ground points (x, z) of the trees and shrubs within reach of a point, from the server's flora placer (grass and flowers left out).
func _trunks_near(at: Vector2, reach: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()

	if flora == null or flora.placer == null:
		return out

	var centre: Vector2i = flora.placer.chunk_of(at.x, at.y)

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var held: Dictionary = flora.items_of(Vector2i(centre.x + dx, centre.y + dz))   # kept, or prebuilt (flora_pack.gd): never placed again on the main thread

			for n in range(held["ids"].size()):
				var p: Vector3 = held["positions"][n]

				if Vector2(p.x, p.z).distance_to(at) <= reach and int(flora.placer.species_of(held["ids"][n]).get("kind", PlacerScript.KIND_PLANT)) != PlacerScript.KIND_PLANT:
					out.append(Vector2(p.x, p.z))

	return out


# What a character surveying a point sees there for its Map (server_map.gd observe): [ground height m, water kind], or [] while that
# tile or its flora chunk is not in memory yet (reading either here would stall the main thread, and a chunk not made yet would
# record its trees as none for good): the next survey step after they are made records the cell.
func _map_observe(x: float, z: float) -> Array:
	if not generator.tile_cached(x, z):
		return []

	if flora != null and flora.items_cached(Vector2i(int(floor(x / flora.placer.chunk_m)), int(floor(z / flora.placer.chunk_m)))).is_empty():
		return []

	var tile_data = generator.get_tile(generator.tile_of(x, z))

	if tile_data == null:
		return []

	var height: float = float(generator.surface_height(x, z))

	if tile_data.placeholder:
		return [height, MapCodec.WATER_SEA]

	var water_class: int = int(tile_data.water_class[tile_data.nearest(x, z)]) if not tile_data.water_class.is_empty() else 0

	if MapScript.water_kind(water_class) == MapCodec.WATER_NONE and not tile_data.water_class.is_empty():
		# A river narrower than the cell runs past its centre: four more looks across the cell find it (Dave 23 Nov 2026: the map must show rivers).
		for d in [Vector2(-5.0, -5.0), Vector2(5.0, -5.0), Vector2(-5.0, 5.0), Vector2(5.0, 5.0)]:
			if int(tile_data.water_class[tile_data.nearest(x + d.x, z + d.y)]) == 3:
				return [height, MapCodec.WATER_RIVER]

	return [height, MapScript.water_kind(water_class)]


# What a person would mark on their map round `point` (Dave 23 Nov 2026: "anything a human would find of interest should be marked"):
# [kind, x, z, label] rows for server_map.gd look_round, or null while the tile or its flora is not loaded (nothing then changes on the map).
# Cave mouths ("spring" where a spring comes out of one), bog iron patches, fruit trees by kind (data/map.json fruit_trees), a goblin
# tribe's camp under its name, a bandit camp once it stands, and the world items (server_items.map_marks_near: campfires, ore rocks
# started and left, paths and roads). Every source is a list kept for its own work: nothing here scans the world.
func _map_landmarks(point: Vector3, radius: float) -> Variant:
	# Every terrain tile and flora chunk the circle touches must be in memory: a look that cannot see part of the circle changes nothing,
	# so a cave or a stand of trees across an unloaded edge is never taken off the map.
	var tiles: Array = []

	for corner in [Vector2(-radius, -radius), Vector2(radius, -radius), Vector2(-radius, radius), Vector2(radius, radius)]:
		var x: float = point.x + corner.x
		var z: float = point.z + corner.y

		if not generator.tile_cached(x, z):
			return null

		var tile_data = generator.get_tile(generator.tile_of(x, z))

		if tile_data == null:
			return null

		if not tiles.has(tile_data):
			tiles.append(tile_data)

	if flora != null:
		var size: float = flora.placer.chunk_m

		for cz in range(int(floor((point.z - radius) / size)), int(floor((point.z + radius) / size)) + 1):
			for cx in range(int(floor((point.x - radius) / size)), int(floor((point.x + radius) / size)) + 1):
				if not flora.chunk_cached(Vector2i(cx, cz)):
					return null

	var here: Vector2 = Vector2(point.x, point.z)
	var out: Array = items.map_marks_near(point, radius)

	for tile_data in tiles:
		if tile_data.placeholder:
			continue

		for row in tile_data.cave_mouths:
			var mouth: Vector2 = Vector2((row[0] as Vector3).x, (row[0] as Vector3).z)

			if mouth.distance_to(here) <= radius:
				var spring: bool = false

				for at in tile_data.spring_mouths:
					spring = spring or at.distance_to(mouth) < 6.0

				out.append(["spring" if spring else "cave", mouth.x, mouth.y, "Spring" if spring else "Cave"])

	for patch in items._bog_patches_near(point.x, point.z, radius):
		if Vector2(float(patch["x"]), float(patch["z"])).distance_to(here) <= radius:
			out.append(["bog_iron", float(patch["x"]), float(patch["z"]), "Bog iron"])

	var fruit: Dictionary = map_knowledge.cfg.get("fruit_trees", {})

	if flora != null and not fruit.is_empty():
		var groups: Dictionary = {}   # group -> [count, sum x, sum z]

		for tree in _cached_trees(point, radius):
			var row: Array = fruit.get(str(tree[2]), [])

			if row.size() >= 2 and Vector2(tree[1].x, tree[1].z).distance_to(here) <= radius:
				var g: Array = groups.get(str(row[0]), [0, 0.0, 0.0])
				groups[str(row[0])] = [int(g[0]) + 1, float(g[1]) + tree[1].x, float(g[2]) + tree[1].z]

		var groves: Dictionary = map_knowledge.cfg.get("fruit_groups", {})

		for group in groups:
			var g: Array = groups[group]
			var names: Array = groves.get(group, [str(group).capitalize() + " tree", str(group).capitalize() + " trees", ""])
			var label: String = str(names[0]) if int(g[0]) == 1 else str(names[1])

			if int(g[0]) >= int(map_knowledge.cfg.get("orchard_from", 6)) and str(names[2]) != "":
				label = str(names[2])

			out.append(["fruit:" + str(group), float(g[1]) / float(g[0]), float(g[2]) / float(g[0]), label])

	if tribes != null:
		for tribe in tribes.tribes():
			var camp: Dictionary = (tribes.tribes()[tribe] as Dictionary).get("camp", {})
			var at: Dictionary = camp.get("fire", camp.get("mouth", {}))

			if not at.is_empty() and Vector2(float(at.get("x", 0.0)), float(at.get("z", 0.0))).distance_to(here) <= radius:
				out.append(["goblin_camp", float(at["x"]), float(at["z"]), str(tribe).capitalize()])   # the clan's name under its face (Dave 23 Nov 2026)

	if bandits != null:
		for cell in bandits.sites:
			var site: Dictionary = bandits.sites[cell]

			if int(site.get("stage", 0)) >= 3 and Vector2(float(site.get("x", 0.0)), float(site.get("z", 0.0))).distance_to(here) <= radius:
				out.append(["bandit_camp", float(site["x"]), float(site["z"]), "Bandits"])

	return out


# Whether the baked tile has water (any class but none) at a point.
func _baked_wet(x: float, z: float) -> bool:
	var tile_data = generator.get_tile(generator.tile_of(x, z))
	return not tile_data.placeholder and not tile_data.water_class.is_empty() and int(tile_data.water_class[tile_data.nearest(x, z)]) != 0


# The server's own WorkerThreadPool jobs not finished yet, and the block line's sends waiting on a client, for the state and WATCHDOG lines:
# what runs or waits while a client's first load runs (docs/design/LOCAL_SERVER_FIRST_LOAD_PLAN.md, option A). Any thread (the watchdog's):
# the counts are read under their own mutexes; the landscape task id is a plain read, only compared, never asked about (the main thread frees it).
func _pool_summary() -> String:
	var landscape: bool = items != null and items._resource_task != -1
	return "pool jobs: tile reads %d, undergrowth %d, cover %d, landscape %s; block line sends in progress %d" % [generator._prefetch_tasks.busy() if generator != null else 0,
		flora._brush_tasks.busy() if flora != null else 0, _cover_tasks.busy(), "on" if landscape else "off", _link.sending() if _link != null else 0]


# A peer's round trip in ms as ENet measures it (0 when there is no such peer), for a fair dodge (server_big_game late_s).
func _ping_ms(peer_id: int) -> int:
	var enet: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer

	if enet == null or not _peers.has(peer_id):
		return 0

	var link: ENetPacketPeer = enet.get_peer(peer_id)
	return int(link.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) if link != null else 0


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
	queued += ", " + _pool_summary()
	# What the memory holds (the long run, 23 Nov 2026: is a slow rise what players added or a leak): engine objects, nodes, resources, world
	# items, ground edits and animals.
	queued += ", objects %d nodes %d resources %d, world items %d, ground edits %d, animals %d" % [int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), items.world_item_count() if items != null else 0, store.ops.count, animals.animals.size() if animals != null else 0]
	return "peers %d fps %d ram %d MB, %s, %s | %s" % [_peers.size(), Engine.get_frames_per_second(), int(OS.get_static_memory_usage() / 1048576.0), queued, EventLogScript.host_stats(multiplayer.multiplayer_peer), " | ".join(parts)]


const FIRE_SPOTS_MS := 250   # how often the animals' list of fires and torches is worked out again (a lit fire is avoided within this)
var _fire_at: Array = []             # positions of the burning fires, torch bearers and guard lights (items.fire_spots)
var _fire_keep_off: Dictionary = {}  # position -> keep-off metres, for those positions
var _fire_spots_msec: int = -FIRE_SPOTS_MS


func _refresh_fire_spots() -> void:
	var now: int = Time.get_ticks_msec()

	if now - _fire_spots_msec < FIRE_SPOTS_MS:
		return

	_fire_spots_msec = now
	_fire_at = []
	_fire_keep_off = {}

	for spot in items.fire_spots():
		_fire_at.append(spot[0])
		_fire_keep_off[spot[0]] = float(spot[1])


# Join diagnosis (Sonny, 1 Nov 2026): an RPC handler that ran over 100 ms on the main thread says so in the telemetry file (crash_reports/telemetry_server_<port>.log), with the
# time since the handler began; "between frames (rpc handlers, engine)" in the stall lines is where the 17 s after a connect went.
func _slow_rpc(name: String, started_usec: int) -> void:
	var ms: int = (Time.get_ticks_usec() - started_usec) / 1000

	if ms >= 100:
		_events.event("SLOW RPC %s: %d ms" % [name, ms])


func _on_peer_connected(peer_id: int) -> void:
	_never_joined = false
	NetSettings.apply((multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(peer_id))
	_peers[peer_id] = {"blocks": 0, "bytes": 0, "since": Time.get_ticks_msec()}

	if ranges != null:   # the joining player's ground first: the trail places wait (data/animals/ranges.json hold_after_join_s)
		ranges.hold_for_join(Time.get_ticks_msec())
	_queue_mutex.lock()
	_connected_peers[peer_id] = true
	_queue_mutex.unlock()
	print("Client %d connected" % peer_id)
	_publish_status()
	_events.event("peer %d connected" % peer_id)
	net.welcome.rpc_id(peer_id, {
		"protocol": NetScript.PROTOCOL_VERSION,
		"server_build": _stamped_build if _stamped_build > 0 else BuildInfo.NUMBER,   # the build id
		"server_stamped": _stamped_build > 0,   # a release server: it checks the build at hello, so the client skips its commit check (protocol 133): a client on another commit says so plainly (empty commit = unknown = match)
		"server_commit": _commit,
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


# What the server pick page shows before a player joins (block line STATUS, docs/design/SERVER_PICK_PAGE.md). Sent again when a player comes or goes.
func _publish_status() -> void:
	if _link == null:
		return

	_link.set_status({
		"name": _server_settings.server_name,
		"message": _server_settings.message,
		"build": _stamped_build if _stamped_build > 0 else BuildInfo.NUMBER,
		"stamped": _stamped_build > 0,
		"protocol": NetScript.PROTOCOL_VERSION,
		"players": _peers.size(),
		"max_players": max_players,
		"locked": _server_settings.locked(),
	})


# A stamped server and a client of another build (step A1, Dave 18 Nov 2026): the client is told why, gets nothing of the player's,
# and is dropped a moment later so the reason arrives first.
# The same character joined again on a new connection (a rejoin before the dropped line timed out, or a second window): the old one is told
# why on its screen, then closed (its pack and spot already went to the new one, server_items.gd peer_connected_hello).
func _drop_replaced(old_peer: int) -> void:
	if not _peers.has(old_peer):
		return

	_peers[old_peer].erase("player")   # its character is the new connection's now: it no longer counts towards a full server

	net.join_refused.rpc_id(old_peer, "This character joined the server again from another game window or computer, so this one was closed. Nothing was lost.")
	await get_tree().create_timer(1.0).timeout

	if multiplayer.multiplayer_peer != null and _peers.has(old_peer):
		multiplayer.multiplayer_peer.disconnect_peer(old_peer)
		_on_peer_disconnected(old_peer)   # forgotten now: a dead line never answers the close, so it stayed in the lists (and was sent to, 2,540 send errors in 6 min) until its 60 to 120 s timeout (robots 23 Nov 2026); the engine's own leave later finds nothing (a force close would skip that leave and keep the peer in the engine's list)


# The words a player past max_players is given (the client titles its window "Server full" when it sees "server is full").
const SERVER_FULL := "The server is full (%d players). Try again when someone leaves."


# Whether a hello from `peer` (character `store_key`) finds the server full: only connections whose hello was let in count (not the ones
# still at the door or refused), and the same character coming back is never full, since its older connection is dropped for it.
func _full_for(peer: int, store_key: String) -> bool:
	var let_in: int = 0

	for other in _peers:
		if other == peer or not _peers[other].has("player") or _peers[other].has("refused"):
			continue

		if items.key_of(other) == store_key:
			return false

		let_in += 1

	return let_in >= max_players


func _refuse_join(peer: int, build: int, text: String) -> void:
	if not _peers.has(peer) or _peers[peer].has("refused"):
		return   # one refusal per connection, however many hellos it sends

	_peers[peer]["refused"] = true
	print("Join refused for peer %d (client build %d, this server build %d): %s" % [peer, build, _stamped_build, text])
	_events.event("peer %d refused (client build %d, server build %d): %s" % [peer, build, _stamped_build, text])
	net.join_refused.rpc_id(peer, text)
	await get_tree().create_timer(1.0).timeout

	if multiplayer.multiplayer_peer != null and _peers.has(peer):
		multiplayer.multiplayer_peer.disconnect_peer(peer)


# Starts the starter tile's running water on the tile as it is now loaded.
func _start_water() -> void:
	var water_tile: Vector2i = Vector2i(3, 4)
	var water_data = generator.get_tile(water_tile)

	if water_data.placeholder:
		return

	# The rivers and lakes start FULL, from the baked settled water of each tile (water/tile_X_Z.water), so a player never waits for the springs: changed 30 Oct 2026 after the
	# play-test (a dry start needed 6 simulated hours before the rivers ran and left broken patches meanwhile; Owner's old choice of 2026-10-18). The --dry-water and
	# --settled-water switches are gone (9 Nov 2026, no flags). The hub runs the starter tile and the neighbours its rivers cross into.
	water_live = WaterHub2Script.new()
	water_live.setup(water_tile, "%s/water" % _world_dir, WATER_BASE_RATE, generator, false)

	if water_live.has_method("set_store"):
		water_live.set_store(store)   # Sullivan dig windows read the server's ground (src/sullivan_water/live/dig_windows.gd)

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
# `main_thread` false (the tunnel watch's own thread): the old rule, all ground at or under 0 m is sea, since the animals' fog windows that
# answer _sea_cut_off are swapped on the main thread with no lock.
func _water_at(position: Vector3, main_thread: bool = true) -> Array:
	var tile: Vector2i = generator.tile_of(position.x, position.z)
	return CellReadsScript.water_at(generator, generator.get_tile(tile), water_live.data_of(tile) if water_live != null else null, water_live != null, position, _sea_cut_off if main_thread else Callable())


# Ground below sea level cut off from the open sea (a fen hollow behind sand above 0 m) is not the sea: no sea water to fill, no sea fish,
# no wading in a sea the client does not draw there (fog_ground.gd under_land, read from the animals' windows round the players).
func _sea_cut_off(x: float, z: float) -> bool:
	return animals != null and animals.sea_cut_off(x, z)


# As _water_at, for a player's reported position: under the hill, a spring cave pool's water counts (BUG-008), its floor taken as the
# basin's bottom so the swim and breath rules see deep water. Only here: the other callers ask at y 0 for the open water.
func _player_water_at(position: Vector3) -> Array:
	var water: Array = _water_at(position)

	if position.y < float(water[1]) - 1.0:
		var cave_surface: float = _cave_pool_surface(position)

		if not is_nan(cave_surface):
			return [cave_surface, cave_surface - TileDataScript.CAVE_POOL_DEPTH_M]

	return water


# A saved spot with the head under water (they left diving, or the water rose) comes up to the surface, swimming: nobody wakes up drowning.
func _resume_spot(spot: Vector3) -> Vector3:
	var water: Array = _player_water_at(spot)
	var in_cave: bool = spot.y < float(water[1]) - 1.0 and not _in_cave_pool(spot)   # under the ground, not in a cave pool: the lake above is not theirs

	if not in_cave and SwimScript.head_under(spot.y, water[0], water[1]):
		spot.y = float(water[0])

	return spot


# Where the player will touch the ground: straight below if hovering, farther
# along their heading the higher and faster they are. Blocks nearest this
# point are made first.
func _on_position_reported(peer_id: int, position: Vector3, velocity: Vector3) -> void:
	# A tile not in memory is never read here on the main thread (about 1 s on Dave's PC, BugsList 108): it is read on a worker, and the
	# swim, breath and cave pool state stay as last reported until it is in (a second or more).
	if generator.tile_cached(position.x, position.z):
		var water: Array = _player_water_at(position)
		items.set_swimming(peer_id, SwimScript.swimming(position.y, water[0], water[1]))
		items.set_head_under(peer_id, SwimScript.head_under(position.y, water[0], water[1]))
		items.set_cave_pool(peer_id, SwimScript.swimming(position.y, water[0], water[1]) and _in_cave_pool(position))
	else:
		generator.prefetch_tile(position.x, position.z)

	items.report_position(peer_id, position, velocity)   # with its velocity: a blow is judged from where the striker is now (strike_origin)

	if map_knowledge != null:
		map_knowledge.note_position(peer_id, position)   # the charcoal Map: a survey every few metres walked (server_map.gd)

	# The player's own tile's cave streams and pools, once (Dave 6 Nov 2026: "nope there is no water in the tunnels", and in a spring pool "I cant swim
	# in it. its not really there" while the breath ran down). They went only with the first water asked in a tile, and since the client asks only for
	# the chunks the live water touches (#218) a tile could go without them: the client then had no stream to draw and no pool to swim in, the server
	# still had the basin. Now the tile the player stands in sends them too (no more than once per peer and tile).
	if flora != null:
		_send_cave_streams(peer_id, Vector2i(int(floor(position.x / flora.placer.chunk_m)), int(floor(position.z / flora.placer.chunk_m))))
	generator.prefetch_around(position.x, position.z)
	_warm_flora(peer_id, position)
	var height: float = maxf(position.y - generator.surface_height(position.x, position.z), 0.0) if generator.tile_cached(position.x, position.z) else 0.0
	var descent: float = maxf(-velocity.y, 10.0)
	var seconds: float = minf(height / descent, 8.0)
	var point: Vector2 = Vector2(position.x + velocity.x * seconds, position.z + velocity.z * seconds)
	_queue_mutex.lock()
	_aim[peer_id] = point
	_queue_mutex.unlock()


# Whether a point is in a spring cave pool (icy water, BUG-008).
# The tile row of a position (Climate.row_of_z): its own seasons, sun and weather.
func _row_of(pos: Vector3) -> int:
	return floori(pos.z / float(settings.tile_size_m))


func _in_cave_pool(position: Vector3) -> bool:
	return not is_nan(_cave_pool_surface(position))


# The surface of the spring cave pool a reported position is in (the basin as carved, BUG-008), else NAN.
func _cave_pool_surface(position: Vector3) -> float:
	var tile_data = generator.get_tile(generator.tile_of(position.x, position.z))

	if tile_data == null or tile_data.placeholder or tile_data.cave_pool_shapes.is_empty():
		return NAN

	return tile_data.cave_pool_surface(position)


func _is_connected_peer(peer_id: int) -> bool:
	_queue_mutex.lock()
	var known: bool = _connected_peers.has(peer_id)
	_queue_mutex.unlock()
	return known


func _on_peer_disconnected(peer_id: int) -> void:
	if not _peers.has(peer_id):
		return   # forgotten already (_drop_replaced): the engine's own leave of that line, a minute or two later

	var info: Dictionary = _peers.get(peer_id, {})
	print("Client %d left after %d blocks, %.1f MB; flora %.1f MB" % [
		peer_id, int(info.get("blocks", 0)), float(info.get("bytes", 0)) / 1048576.0, float(info.get("flora_bytes", 0)) / 1048576.0
	])
	_events.event("peer %d left after %d blocks (last stats: %s)" % [peer_id, int(info.get("blocks", 0)), str(info.get("last_stats", "none"))])
	_peers.erase(peer_id)
	_publish_status()
	limits.forget(peer_id)
	_warm_home.erase(peer_id)
	_water_answered_msec.erase(peer_id)
	_water_sent.erase(peer_id)
	_cave_streams_sent.erase(peer_id)
	_gather_msec.erase(peer_id)
	_npc_sent.erase(peer_id)
	_edits_held.erase(peer_id)   # a rejoin catches up through the edits since (protocol 128)
	coarse_ground.drop(peer_id)
	_fine_told.erase(peer_id)
	_fine_named.erase(peer_id)
	_animal_sent.erase(peer_id)
	trails.forget_peer(peer_id)
	bandits.forget(peer_id)

	if map_knowledge != null:
		map_knowledge.forget_peer(peer_id)

	_blood_sent.erase(peer_id)
	_burrows_sent.erase(peer_id)
	_trap_marks_sent.erase(peer_id)
	players.forget(peer_id)
	cues.forget(peer_id)

	if fish_signs != null:
		fish_signs.forget(peer_id)
	_nests_sent.erase(peer_id)
	_holes_sent.erase(peer_id)
	_far_fires_sent.erase(peer_id)
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


# Admin only (server/client split A5): it changes the water for everybody.
func _on_water_rate_requested(peer_id: int, direction: int) -> void:
	if water_live == null or not admin.is_admin(items.key_of(peer_id)):
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
		_send_cave_streams(peer_id, Vector2i(chunks[2 * n], chunks[2 * n + 1]))


# Spring caves (Dave 3 Nov 2026): the streams down a tile's caves, and its cave dens (den sounds), go to a peer once, with the first water it asks for in that tile. Only from a tile
# already loaded (loading one here would stall the main thread); the next water request tries again.
func _send_cave_streams(peer_id: int, chunk: Vector2i) -> void:
	var x: float = (float(chunk.x) + 0.5) * flora.placer.chunk_m
	var z: float = (float(chunk.y) + 0.5) * flora.placer.chunk_m

	if not generator.tile_cached(x, z):
		return

	var tile: Vector2i = generator.tile_of(x, z)
	var sent: Dictionary = _cave_streams_sent.get(peer_id, {})
	_cave_streams_sent[peer_id] = sent

	if sent.has(tile):
		return

	sent[tile] = true
	var data = generator.get_tile(tile)

	if data == null or data.placeholder:
		return

	if not data.cave_streams.is_empty():
		net.cave_streams.rpc_id(peer_id, tile, data.cave_streams)
		@warning_ignore("integer_division")
		print("Terrain server: cave streams for tile %s to peer %d (%d pieces)" % [str(tile), peer_id, data.cave_streams.size() / 7])

	if not data.cave_dens.is_empty():
		net.cave_dens.rpc_id(peer_id, tile, data.cave_dens)

	for k in data.goblin_dens.size():   # where the goblin dens are (floor point) and the mouth their group comes out of, for checking a den by eye
		print("Terrain server: goblin den for tile %s at %.1f, %.1f, %.1f (floor), group mouth %.1f, %.1f" % [str(tile), data.goblin_dens[k].x, data.goblin_dens[k].y, data.goblin_dens[k].z, data.goblin_den_mouths[k].x, data.goblin_den_mouths[k].y])

	# Cave dressing (protocol 92): the bake's bone piles and formations, once the tile data carries them.
	var bones: PackedFloat32Array = data.get("cave_bones") if "cave_bones" in data else PackedFloat32Array()
	var formations: PackedFloat32Array = data.get("cave_formations") if "cave_formations" in data else PackedFloat32Array()

	if not bones.is_empty() or not formations.is_empty():
		net.cave_dressing.rpc_id(peer_id, tile, bones, formations)


# Lag review (Dave 2 Nov 2026): every "water moved" the client asks again for all ~22 chunks it holds, and every answer was
# unpacked and redrawn on its main thread, though in a settled river most chunks have not changed. Each peer's last water per chunk
# is remembered by hash; the same bytes are not sent again. Records what is sent (empty bytes forget it) and says whether to send.
func _water_changed_for(peer_id: int, chunk: Vector2i, bytes: PackedByteArray) -> bool:
	var held: Dictionary = _water_sent.get(peer_id, {})
	_water_sent[peer_id] = held

	if bytes.is_empty():
		held.erase(chunk)
		return true

	var key: int = hash(bytes) ^ bytes.size()

	if int(held.get(chunk, 0)) == key:
		return false

	held[chunk] = key
	return true


# Packing a chunk's water takes about 30 ms: ready ones go out at once, the rest are packed by a worker thread and sent
# from _process when done.
func _queue_water(peer_id: int, chunk: Vector2i) -> void:
	if flora.water_ready(chunk):
		var bytes: PackedByteArray = flora.water_bytes(chunk)

		if _water_changed_for(peer_id, chunk, bytes):
			net.deliver_water.rpc_id(peer_id, chunk, bytes)

		return

	_queue_mutex.lock()
	var added: bool = _water_queue.size() < MAX_QUEUE_PER_PEER * maxi(1, _connected_peers.size())

	if added:
		_water_queue.append([peer_id, chunk])

	_queue_mutex.unlock()

	if added:
		_work.post()


# The weather over one player, worked out as that player's own client does (terrain_client._update_weather): the zone of the
# row they stand in and their altitude. The birds flush from the thunder strikes under this weather, so they take off at the
# claps that player hears, even under a different storm from the starter row's.
func _weather_at(pos: Vector3) -> Dictionary:
	var row: int = floori(pos.z / float(settings.tile_size_m))
	return WeatherScript.state(settings.master_seed, game_clock.seconds, settings.get_zone_group_for_row(row), pos.y, 0.0, row, settings.equator_tile_row)


# The weather over a spot as the player's client there works it out (terrain_client._update_weather: the zone of its row, its height), so
# what the server does to a player (warmth, wet clothes, a fire or torch put out by rain, sleep, drinking) follows the sky that player
# sees: up a mountain it snows (no rain cooling, no fire put out) while it rains at the coast (weather and seasons walk, 23 Nov 2026).
# One answer per row and Weather.HEIGHT_BAND_M of height (band_height) a second, so many fires and players cost a few noise reads.
func _weather_here(pos: Vector3) -> Dictionary:
	var now: int = Time.get_ticks_msec()

	if now - _weather_here_msec >= 1000:
		_weather_here_cache.clear()
		_weather_here_msec = now

	var row: int = floori(pos.z / float(settings.tile_size_m))
	var height: float = WeatherScript.band_height(pos.y)
	var key := Vector2i(row, int(round(height)))

	if not _weather_here_cache.has(key):
		_weather_here_cache[key] = WeatherScript.state(settings.master_seed, game_clock.seconds, settings.get_zone_group_for_row(row), height, 0.0, row, settings.equator_tile_row)

	return _weather_here_cache[key]


# Game hours since it last rained over a spot (Weather.rain_hours_ago at its row and 10 m band, as _weather_here), up to max_h; INF when it
# did not. The drink rule's brooks (DrinkRules.runs) run after the rain that fell where the player stands, not the starter row's (Dave:
# nothing is based on where the spawn is). Worked out once a row and band a game hour.
func _rain_hours_at(pos: Vector3, max_h: float) -> float:
	var hour: int = floori(game_clock.seconds / 3600.0)

	if hour != _rain_hours_hour:
		_rain_hours_cache.clear()
		_rain_hours_hour = hour

	var row: int = floori(pos.z / float(settings.tile_size_m))
	var height: float = WeatherScript.band_height(pos.y)
	var look: int = ceili(maxf(max_h, 0.0))
	var key := Vector3i(row, int(round(height)), look)

	if _rain_hours_cache.has(key):
		return float(_rain_hours_cache[key])

	var ago: float = WeatherScript.rain_hours_ago(settings.master_seed, float(hour) * 3600.0, settings.get_zone_group_for_row(row), height, row, settings.equator_tile_row, float(look))
	_rain_hours_cache[key] = ago
	return ago


# The weather over the starter tile (zone from its row, season and time from the game clock,
# town spirit a neutral placeholder until it exists) swells the rivers: rain feeds the springs,
# lagged because runoff takes time (snow just piles up).
func _update_weather() -> void:
	var now: int = Time.get_ticks_msec()

	if now < _weather_next_msec or water_live == null:
		return

	_weather_next_msec = now + 1000
	var row: int = WeatherScript.STARTER_ROW               # starter-calendar: the fallback weather (weather_now, rain_now) for code with no place; the starter tile's row (Climate.STARTER_ROW): the one weather (rivers follow their own row, _river_runoff)
	var game_s: float = game_clock.seconds
	weather = WeatherScript.state(settings.master_seed, game_s, settings.get_zone_group_for_row(row), 0.0, 0.0, row, settings.equator_tile_row)

	var bucket: int = int(float(weather["rain"]) * 4.0) + 10 * int(float(weather["snow"]) * 4.0)

	if bucket != _weather_bucket:
		_weather_bucket = bucket
		print("server: starter row weather %s, rain %.2f snow %.2f storm %.2f, %.0f C; live water row %d rivers x%.2f of the start flow" % [weather["season"], weather["rain"], weather["snow"], weather["storm"], weather["temp_c"], water_live.centre.y, water_live.runoff])

	water_live.set_runoff(_river_runoff(game_s, water_live.centre.y))


# The runoff for the running water tile (row `running`: the hub's centre, the first baked tile of set_live): its own row's rain and heat at
# sea level, lagged WEATHER_LAG_S, so a river rises by the rain over it, not the starter row's (Dave: nothing is based on where the spawn
# is). The rows of the next few live tiles are followed too, so a player walking between rows meets that row's own state. Rain falling as snow higher up piles up (Weather.river_push reads rain).
# shortcut: a tile's rivers rise by their own tile row; an upstream stretch in another row is not weighted in (physical world thread
# 23 Nov 2026: nearly every catchment sits inside its own tile or the next). set_runoff is one number: any other live tile in another row
# runs on the running tile's runoff. A row is forgotten once no live tile is in it (WATER_KEEP_MS after the last player left), so walking
# back into a flooded row after that starts its rivers again from the baked flow and they swell over WEATHER_LAG_S.
func _river_runoff(game_s: float, running: int) -> float:
	var rows: Array = [running]

	for tile in _water_live_last.slice(0, 4):   # set_live's four at most
		if not rows.has((tile as Vector2i).y):
			rows.append((tile as Vector2i).y)

	for row in _river_rows.keys():
		if not rows.has(row):
			_river_rows.erase(row)

	var k: float = 1.0 - exp(-1.0 / WEATHER_LAG_S)

	for row in rows:
		var here: Dictionary = WeatherScript.state(settings.master_seed, game_s, settings.get_zone_group_for_row(row), 0.0, 0.0, row, settings.equator_tile_row)
		var push: float = WeatherScript.river_push(here)
		var dry: float = WeatherScript.river_dry(here)
		var was: Array = _river_rows.get(row, [0.0, 0.0])   # a row newly live starts from its baked flow, as its new water window does, and swells from there
		_river_rows[row] = [float(was[0]) + (push - float(was[0])) * k, float(was[1]) + (dry - float(was[1])) * k]

	var run: Array = _river_rows[rows[0]]
	return maxf(1.0 + WEATHER_SWELL * float(run[0]) - DRY_SHRINK * float(run[1]), RUNOFF_FLOOR)


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

	if water_live.has_method("take_flow"):
		var flow: Dictionary = water_live.take_flow()

		if not flow.is_empty():
			# shortcut: sent to everyone each publish (about 30 KB packed); a player who joins gets the next one, none is kept for late joiners
			net.deliver_water_flow.rpc(flow["origin"], flow["w"], flow["h"], flow["cell"], flow["raw"], flow["bytes"])
			var cell: float = float(flow["cell"])
			_water_window = Rect2(Vector2(flow["origin"]) - Vector2(0.5, 0.5) * cell, Vector2(float(flow["w"]), float(flow["h"])) * cell)

	# Sullivan water: the dig regions' 2 m water for the clients' fine sheets (docs/water/fine_drawing_2m.md).
	if water_live.has_method("take_fine"):
		var fine: Dictionary = water_live.take_fine()

		if not fine.is_empty():
			_fine_keys = fine["keys"]
			_send_fine(FineWaterSend.remember(_fine_cache, fine))
			_fine_sends += 1

			if _fine_sends == 1 or _fine_sends % 20 == 0:
				var bytes: int = 0

				for p in fine["packets"]:
					bytes += PackedByteArray(p[6]).size()

				print("server: 2 m water message %d: %d regions, %d textures, %d bytes" % [_fine_sends, fine["keys"].size(), fine["packets"].size(), bytes])

	if not updates.is_empty():
		var tiles: Array = []

		for update in updates:
			tiles.append(update[0])

		var same_tiles: bool = tiles == _water_tiles_told
		_water_tiles_told = tiles

		for update in updates:
			var tile_data = water_live.data_of(update[0])

			if tile_data == null:
				continue

			tile_data.set_sim(update[1], update[2])

			if update[0] == water_live.centre:
				_centre_levels = update[1]

		_water_updates += 1

		if _water_updates == 1 or _water_updates % 10 == 0:
			_wet_centre = _wet_squares(_centre_levels)
			print("server: water update %d (%d tiles), %d wet squares on the starter tile" % [_water_updates, updates.size(), _wet_centre])

		# Lag review (Steve 3 Nov 2026): the levels change only inside the live window (outside it the baked ones stay, water_hub2.publish_levels),
		# so clients re-ask only for the chunks there and where the window was, not for every chunk they hold. No window known: everything.
		# Sullivan water (Sonny, 7 Nov 2026): a dug ditch can lie outside the 8 m window, so each dig window is named too, now and where they were
		# last time. Each area is its own rectangle (finding 7, docs/ai-team/audits/2026-11-18_oversized_reactions_audit.md): two digs far apart
		# name two small areas, not one box over the ground between; and the server forgets only its packed water there (finding 12).
		# A different tile set: its first levels can hold sleeping dig regions that were never drawn into it, which no area names, so everywhere.
		if _water_window.has_area() and same_tiles:
			var live: Array = water_live.live_rects() if water_live.has_method("live_rects") else []
			var areas: Array = WaterAreas.changed_areas(_water_window, _water_window_told, live, _live_told)
			_water_window_told = _water_window
			_live_told = live
			flora.clear_water_in(areas)
			net.water_changed_in.rpc(areas)
		else:
			_water_window_told = _water_window
			_live_told = water_live.live_rects() if water_live.has_method("live_rects") else []
			flora.clear_water()
			net.water_changed.rpc()

		if not water_live.busy:
			net.water_rate.rpc(water_live.rate, false, water_live.rate * WATER_BASE_RATE)


# Cover.at for a fire: makes sure the flora chunk of the spot (and the neighbours whose crowns
# reach into it) is in the server's cover index, then asks it.
# A chunk not made yet is made on a worker thread (placing nine chunks on the main thread froze the server 4 to 8 s when the first player joined, Tyler 31 Oct 2026):
# until it is made its crowns are not in the index, so the answer is "open" there for a few seconds.
func _cover_at(point: Vector3) -> float:
	var size: float = flora.placer.chunk_m
	var home: Vector2i = Vector2i(int(floor(point.x / size)), int(floor(point.z / size)))

	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var chunk: Vector2i = flora.placer.normalize(home + Vector2i(dx, dz))

			if not flora.chunk_made(chunk) and not _cover_warming.has(chunk):
				_cover_warming[chunk] = true
				_start_cover_warm(chunk)

	if flora.roofed(point) or _in_cave(point):
		return 2.0   # under a built roof or in a cave: also shelter from the wind

	return 1.0 if flora.covered(point) else 0.0


var _cover_warming: Dictionary = {}   # chunk -> true while a worker thread makes it for the cover index


const CAVE_ROOF_M := 2.0   # ground at least this far over a player's feet for a spot in a cave to count as inside (not the open mouth)


# Whether a point is inside a cave with rock over it (tile_terrain_data.in_cave; Jamie's caves page, #664). A tile not loaded yet: no.
func _in_cave(point: Vector3) -> bool:
	if generator == null or not generator.tile_cached(point.x, point.z):   # no generator yet (a test that sets only the flora store)
		return false

	var tile_data = generator.get_tile(generator.tile_of(point.x, point.z))

	if tile_data == null or tile_data.placeholder or tile_data.caves.is_empty():
		return false

	return tile_data.in_cave(Vector3(generator.wrap_x(point.x), point.y, generator.wrap_x(point.z)), CAVE_ROOF_M)


# Inside a cave: {"deep_c" (the year mean at the height), "depth_m" (straight distance to the nearest mouth), "kind" (CaveAir), "day_part_c"
# (the day and night part of the outside air now)}; {} outside one. server_items blends its own outside air to deep_c with these.
func _cave_air(point: Vector3) -> Dictionary:
	if not _in_cave(point):
		return {}

	var group: String = settings.get_zone_group_for_row(int(floor(point.z / float(settings.tile_size_m))))
	var tile_data = generator.get_tile(generator.tile_of(point.x, point.z))
	var mouth: Array = tile_data.nearest_cave_mouth(Vector3(generator.wrap_x(point.x), point.y, generator.wrap_x(point.z)))
	return {"deep_c": WeatherScript.year_mean_c(group, point.y), "depth_m": float(mouth[0]), "kind": int(mouth[1]), "day_part_c": WeatherScript.day_part_c(game_clock.seconds, group)}


# Whether the cover index knows the crowns round a point: its flora chunk and the eight round it are made. Missing ones are started
# on a worker as in _cover_at, so asking again a few seconds later says yes (inland nests, MikeW 5 Nov).
func _cover_ready(point: Vector3) -> bool:
	var size: float = flora.placer.chunk_m
	var home: Vector2i = Vector2i(int(floor(point.x / size)), int(floor(point.z / size)))
	var all_made: bool = true

	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var chunk: Vector2i = flora.placer.normalize(home + Vector2i(dx, dz))

			if not flora.chunk_made(chunk):
				all_made = false

				if not _cover_warming.has(chunk):
					_cover_warming[chunk] = true
					_start_cover_warm(chunk)

	return all_made


var _cover_tasks = preload("res://src/shared/pool_tasks.gd").new()   # _warm_cover_chunk tasks, waited for in _exit_tree


func _start_cover_warm(chunk: Vector2i) -> void:
	if not _cover_tasks.add(_warm_cover_chunk.bind(chunk), "cover chunk"):
		_cover_warming.erase(chunk)   # shutting down


func _warm_cover_chunk(chunk: Vector2i) -> void:
	flora.chunk_bytes(chunk, flora.full_known(chunk))   # the full list when it is kept or being placed (a chunk by a player): no second placement
	_cover_warm_done.call_deferred(chunk)


func _cover_warm_done(chunk: Vector2i) -> void:
	_cover_warming.erase(chunk)


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

	var ref_height: float = 0.5 * (float(species["height_min"]) + float(species["height_max"]))   # what the client builds the model at (flora_view)
	return {"name": str(species["name"]), "position": all["positions"][at], "height": float(all["heights"][at]), "trunk": float(species["trunk"]), "ref_height": ref_height, "broadleaf": str(species.get("shape", "")) == "broadleaf", "id": id}


# A standing bush or shrub (placer or planted) for the axe and the pickaxe (Dave 2 Nov 2026), or {}.
func _shrub_info(chunk: Vector2i, id: int) -> Dictionary:
	var home: Vector2i = flora.placer.normalize(chunk)
	var all: Dictionary = flora.items_of(home)
	var at: int = all["ids"].find(id)

	if at < 0:
		return items.dynamic_shrub_info(home, id)

	var species: Dictionary = flora.placer._by_id.get(id >> 16, {})

	if species.is_empty() or int(species["kind"]) != PlacerScript.KIND_SHRUB or flora.removed_in(home).has(id):
		return {}

	return {"name": str(species["name"]), "position": all["positions"][at], "height": float(all["heights"][at])}


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
# Only the chunks the radius reaches, and only those whose full list is made (tree_info reads that list): every dig asks this, and it used
# to place and scan all nine 256 m chunks round the dig on the main thread (22 Nov 2026 load bots: 5.5 s on a first dig, about 50 ms on
# every later one). A chunk not made yet is skipped: the same dig's bury job makes it on the flora thread.
# shortcut: a dig in a chunk not made yet does not fell the trees it undermines; the next dig there does, once the chunk is made.
func _trees_near(point: Vector3, radius: float) -> Array:
	var size: float = flora.placer.chunk_m
	var home: Vector2i = Vector2i(int(floor(point.x / size)), int(floor(point.z / size)))
	var reach: int = maxi(int(ceil(radius / size)), 1)
	var found: Array = []

	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var corner: Vector2 = Vector2(float(home.x + dx) * size, float(home.y + dz) * size)

			if Vector2(clampf(point.x, corner.x, corner.x + size) - point.x, clampf(point.z, corner.y, corner.y + size) - point.z).length() > radius:
				continue

			var chunk: Vector2i = flora.placer.normalize(home + Vector2i(dx, dz))

			if not flora.has_items(chunk):
				continue   # the dig's own bury job (_bury_find, flora thread) makes it

			var trees: Dictionary = flora.items_of(chunk)   # kept: no placement
			var gone: Array = flora.removed_in(chunk)
			var ids: PackedInt32Array = trees["ids"]
			var positions: PackedVector3Array = trees["positions"]

			for n in range(ids.size()):
				var at: Vector3 = positions[n]

				if absf(at.x - point.x) > radius or absf(at.z - point.z) > radius or Vector2(at.x - point.x, at.z - point.z).length() > radius:
					continue

				var species: Dictionary = flora.placer._by_id.get(ids[n] >> 16, {})

				if not species.is_empty() and int(species["kind"]) == PlacerScript.KIND_TREE and not gone.has(ids[n]):
					found.append([chunk, ids[n]])

	return found


# Standing placer trees within `reach` of the straight line from a to b, as [chunk, id, how far along 0..1], from the flora chunks round `near` (a surveyed
# road's station) not yet in `done` (each is marked): server_items _road_fell asks as the road goes, so each chunk is looked through once, when the road reaches it.
# Only chunks whose full list the server already holds (has_items): one not made yet is left unmarked and asked again at the next station.
func _trees_along(a: Vector3, b: Vector3, reach: float, near: Vector3, done: Dictionary) -> Array:
	var size: float = flora.placer.chunk_m
	var a2: Vector2 = Vector2(a.x, a.z)
	var ab: Vector2 = Vector2(b.x, b.z) - a2
	var found: Array = []

	for corner in [Vector2(-reach, -reach), Vector2(reach, -reach), Vector2(-reach, reach), Vector2(reach, reach)]:
		var chunk: Vector2i = flora.placer.normalize(Vector2i(int(floor((near.x + corner.x) / size)), int(floor((near.z + corner.y) / size))))

		if done.has(chunk):
			continue

		if not flora.has_items(chunk):
			continue   # its full list is not made yet (making it is seconds of work on the main thread, and felling needs it): asked again at the next station, not marked done

		var trees: Dictionary = flora.items_of(chunk, true)

		if trees.is_empty() or not trees.has("ids"):
			continue

		done[chunk] = true
		var gone: Dictionary = {}

		for id in flora.removed_in(chunk):
			gone[id] = true

		for n in range(trees["ids"].size()):
			var species: Dictionary = flora.placer._by_id.get(trees["ids"][n] >> 16, {})

			if species.is_empty() or int(species["kind"]) != PlacerScript.KIND_TREE or gone.has(trees["ids"][n]):
				continue

			var at: Vector2 = Vector2(trees["positions"][n].x, trees["positions"][n].z)
			var t: float = clampf((at - a2).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)

			if (at - (a2 + ab * t)).length() <= reach:
				found.append([chunk, trees["ids"][n], t])

	return found


# Standing berry plants (the species with a drops.json "berry_yield" row) within `radius` of a point, from chunks whose items are already made
# only (server_flora items_cached), like _trees_near_cached: each chunk's berry plants are listed once and kept; removed plants are left out at
# each look. Goblins forage at them at night (docs/design/goblin_den_life_design.md 2.3); a look is once per goblin per idle, not per tick.
const BERRY_LISTS_KEPT := 100
var _berry_lists: Dictionary = {}    # chunk Vector2i -> Array of [id, position]
var _berry_ids: Dictionary = {}      # placer species id -> true, berry plants only (built once)


func _berries_near_cached(point: Vector3, radius: float) -> PackedVector3Array:
	var size: float = flora.placer.chunk_m
	var home: Vector2i = Vector2i(int(floor(point.x / size)), int(floor(point.z / size)))
	var reach: int = maxi(int(ceil(radius / size)), 1)
	var found: PackedVector3Array = PackedVector3Array()

	if _berry_ids.is_empty():
		var berries: Dictionary = items._drops.get("berry_yield", {})

		for id in flora.placer._by_id:
			if berries.has(str(flora.placer._by_id[id]["name"])):
				_berry_ids[id] = true

	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var corner: Vector2 = Vector2(float(home.x + dx) * size, float(home.y + dz) * size)
			var near_x: float = clampf(point.x, corner.x, corner.x + size)
			var near_z: float = clampf(point.z, corner.y, corner.y + size)

			if Vector2(near_x - point.x, near_z - point.z).length() > radius:
				continue

			var chunk: Vector2i = flora.placer.normalize(home + Vector2i(dx, dz))

			if not _berry_lists.has(chunk):
				var plants: Dictionary = flora.items_cached(chunk)

				if plants.is_empty():
					continue

				var listed: Array = []
				var ids: PackedInt32Array = plants["ids"]
				var positions: PackedVector3Array = plants["positions"]

				for n in range(ids.size()):
					if _berry_ids.has(ids[n] >> 16):
						listed.append([ids[n], positions[n]])

				while _berry_lists.size() >= BERRY_LISTS_KEPT:
					_berry_lists.erase(_berry_lists.keys()[0])

				_berry_lists[chunk] = listed

			var gone: Array = []
			var gone_read: bool = false

			for plant in _berry_lists[chunk]:
				if Vector2(plant[1].x - point.x, plant[1].z - point.z).length() > radius:
					continue

				if not gone_read:
					gone = flora.removed_in(chunk)
					gone_read = true

				if not gone.has(plant[0]):
					found.append(plant[1])

	return found


# Standing placer trees within `radius` of a point, as [position, species name], from chunks whose items are already made only (server_flora items_cached): the hint
# triggers ask 4 times a second, and _trees_near made the nine chunks round a new player on the main thread (3 to 11 s) and then scanned every plant in them
# (about 120 ms a look). Each chunk's trees are listed once and kept; felled trees are left out at each look. A chunk not made yet counts no trees until the
# flora stream (a worker) has made it.
const TREE_LISTS_KEPT := 200
const TREE_CELL_M := 16.0
const WIDE_CELL := Vector2i(2147483647, 2147483647)   # _tree_lists key of a chunk's trunks wider than TreeTrunks.SEARCH_TRUNK_M
var _tree_lists: Dictionary = {}     # chunk Vector2i -> Dictionary: 16 m cell Vector2i -> Array of [id, position, species name, trunk collider radius, height]
var _tree_names: Dictionary = {}     # placer species id -> name, trees only (built once)


# Lag run 5 Nov: hints 108 ms in one slow tick, near_fruit_tree_in_season 54 of it. Each look scanned every tree of the nine 256 m chunks round the
# player for an 8 m circle. Now a chunk the circle does not touch is skipped (not even listed), and a listed chunk keeps its trees in 16 m cells, so
# a look reads only the cells under the circle.
func _trees_near_cached(point: Vector3, radius: float) -> Array:
	var found: Array = []

	for tree in _cached_trees(point, radius):
		found.append([tree[1], tree[2]])

	return found


# Standing tree trunks near a point for an arrow's flight (Dave 10 Nov 2026: an arrow shot at a tree must stick in it), from the same cached cells:
# [root position, trunk radius m, height m] each. The radius is the collider's (flora_placer.collider_radius: the species trunk scaled by the tree's height;
# saplings, with none, are left out).
func _arrow_trunks(point: Vector3, radius: float) -> Array:
	var found: Array = []

	for tree in _cached_trees(point, radius):
		if float(tree[3]) > 0.0:   # saplings have no trunk collider (flora_placer.SAPLING_M)
			found.append([tree[1], float(tree[3]), float(tree[4])])

	return found


# The cached standing trees within `radius` of a point (flat): [id, root position, species name, trunk radius, height] each, from chunks already made only.
func _cached_trees(point: Vector3, radius: float) -> Array:
	var size: float = flora.placer.chunk_m
	var home: Vector2i = Vector2i(int(floor(point.x / size)), int(floor(point.z / size)))
	var widest: float = TreeTrunks.widest_m()
	var reach: int = maxi(int(ceil((radius + widest) / size)), 1)
	var found: Array = []

	if _tree_names.is_empty():
		for id in flora.placer._by_id:
			var row: Dictionary = flora.placer._by_id[id]

			if int(row["kind"]) == PlacerScript.KIND_TREE:
				_tree_names[id] = str(row["name"])

	var cell_lo: Vector2i = Vector2i(int(floor((point.x - radius) / TREE_CELL_M)), int(floor((point.z - radius) / TREE_CELL_M)))
	var cell_hi: Vector2i = Vector2i(int(floor((point.x + radius) / TREE_CELL_M)), int(floor((point.z + radius) / TREE_CELL_M)))

	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var corner: Vector2 = Vector2(float(home.x + dx) * size, float(home.y + dz) * size)
			var near_x: float = clampf(point.x, corner.x, corner.x + size)
			var near_z: float = clampf(point.z, corner.y, corner.y + size)

			if Vector2(near_x - point.x, near_z - point.z).length() > radius + widest:
				continue

			var chunk: Vector2i = flora.placer.normalize(home + Vector2i(dx, dz))

			if not _tree_lists.has(chunk):
				var trees: Dictionary = flora.items_cached(chunk)

				if trees.is_empty():
					continue

				var cells: Dictionary = {}
				var ids: PackedInt32Array = trees["ids"]
				var positions: PackedVector3Array = trees["positions"]
				var heights: Variant = trees.get("heights", [])

				for n in range(ids.size()):
					var tree_name: Variant = _tree_names.get(ids[n] >> 16)

					if tree_name != null:
						var at: Vector3 = positions[n]
						var cell: Vector2i = Vector2i(int(floor(at.x / TREE_CELL_M)), int(floor(at.z / TREE_CELL_M)))
						var species: Dictionary = flora.placer._by_id[ids[n] >> 16]
						var tall: float = float(heights[n]) if n < heights.size() else float(species["height_min"])
						var ref_height: float = maxf(0.5 * (float(species["height_min"]) + float(species["height_max"])), 0.1)

						if not cells.has(cell):
							cells[cell] = []

						# The trunk collider the client makes (tree_trunks.gd standing_collider: as wide as it is drawn): 0 for a sapling, which carts, rolling logs, digging and arrows pass through.
						var trunk_r: float = PlacerScript.collider_radius(PlacerScript.KIND_TREE, float(species["trunk"]), tall / ref_height, tall)
						var tree: Array = [ids[n], at, tree_name, TreeTrunks.standing_collider(str(tree_name), ids[n], tall, trunk_r), tall]

						if float(tree[3]) > TreeTrunks.SEARCH_TRUNK_M:
							cell = WIDE_CELL   # a trunk wider than the callers' search margins (the everember): found by its own radius below

							if not cells.has(cell):
								cells[cell] = []

						cells[cell].append(tree)

				while _tree_lists.size() >= TREE_LISTS_KEPT:
					_tree_lists.erase(_tree_lists.keys()[0])

				_tree_lists[chunk] = cells

			var listed: Dictionary = _tree_lists[chunk]
			var gone: Array = []
			var gone_read: bool = false

			for cz in range(cell_lo.y, cell_hi.y + 1):
				for cx in range(cell_lo.x, cell_hi.x + 1):
					var in_cell: Variant = listed.get(Vector2i(cx, cz))

					if in_cell == null:
						continue

					for tree in in_cell:
						if Vector2(tree[1].x - point.x, tree[1].z - point.z).length() > radius:
							continue

						if not gone_read:
							gone = flora.removed_in(chunk)
							gone_read = true

						if not gone.has(tree[0]):
							found.append(tree)

			# The wide trunks of this chunk: within `radius` of the point or reaching it (their own radius past it), so a caller's fixed
			# margin for an ordinary trunk still finds them (an arrow at an everember's bark, a cart beside it).
			for tree in listed.get(WIDE_CELL, []):
				if Vector2(tree[1].x - point.x, tree[1].z - point.z).length() > radius + float(tree[3]):
					continue

				if not gone_read:
					gone = flora.removed_in(chunk)
					gone_read = true

				if not gone.has(tree[0]):
					found.append(tree)

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
	flora.chunk_bytes(chunk, flora.full_known(chunk))   # the form whose placed list is kept or being placed (a chunk near a player: full), so nothing is placed again here
	var origin: Vector2 = flora.placer.chunk_origin(chunk)
	var centre: Vector3 = Vector3(origin.x + flora.placer.chunk_m * 0.5, 0.0, origin.y + flora.placer.chunk_m * 0.5)

	for peer in items.peers_near(centre, 600.0):
		var water_cached: bool = flora.water_ready(chunk)
		var water_bytes: PackedByteArray = flora.water_bytes(chunk) if water_cached else PackedByteArray()
		_water_changed_for(peer, chunk, water_bytes)
		net.deliver_flora.rpc_id(peer, chunk, flora.chunk_bytes(chunk, true), water_bytes, true)
		_send_stripped(peer, chunk)
		_send_drink_points(peer, chunk)

		if not water_cached:
			_queue_water(peer, chunk)


# The plants of a chunk that are bare this season, for a client that just got the chunk (berry picking keeps the bush standing).
# The record's drink points in the chunk (DrinkRules.chunk_points), when it has any: the client's E-to-drink prompt at a spring head or a narrow
# brook the settled water does not show (docs/design/drink_prompt_design.md (a)).
func _send_drink_points(peer: int, chunk: Vector2i) -> void:
	var origin: Vector2 = flora.placer.chunk_origin(chunk)
	var tile_data = generator.get_tile(generator.tile_of(origin.x + 1.0, origin.y + 1.0))
	var points: Array = DrinkRulesScript.chunk_points(tile_data, origin, flora.placer.chunk_m)

	if not (points[0] as PackedInt32Array).is_empty() or not (points[1] as PackedFloat32Array).is_empty():
		net.drink_points.rpc_id(peer, chunk, float(tile_data.spacing_m), points[0], points[1])


func _send_stripped(peer: int, chunk: Vector2i) -> void:
	var home: Vector2i = flora.placer.normalize(chunk)
	var ids: PackedInt32Array = items.stripped_ids("%d,%d" % [home.x, home.y])

	if not ids.is_empty():
		net.flora_stripped.rpc_id(peer, chunk, ids)

	var fruit: Array = items.fruit_state("%d,%d" % [home.x, home.y])

	if not (fruit[0] as PackedInt32Array).is_empty():
		net.flora_fruit.rpc_id(peer, chunk, fruit[0], fruit[1])


func _on_cut_flora_requested(peer_id: int, chunk: Vector2i, id: int) -> void:
	# Gathering (E): a plant or shrub is picked: it gives what drops.json and its season allow and then rests.
	# Trees are felled, not gathered (tree-fall comes later).
	var tick: int = Time.get_ticks_msec()

	if tick - int(_gather_msec.get(peer_id, -100000)) < GATHER_MIN_MSEC:
		return

	_gather_msec[peer_id] = tick
	_pick_flora(peer_id, chunk, id)


const SWATH_MOST := 400               # plants one sickle or scythe swing may name (a 3 m circle of dense grass holds far fewer)
const SWATH_SLACK_M := 0.75           # a plant this far past the tool's radius still counts: the player moved between the client's look and the server's

# One sickle or scythe swing (BugsList_Current.md entry 7; protocol 131): the server checks the tool in hand and the pace and harvests the ripe grain round
# the player (items.swath_swing), then each named plant within the radius: a grass (drops.json swath grasses) is gathered as E would, times the tier's
# yield; a bush is cut down and gives nothing (no sticks, no berries); anything else is left alone.
func _on_cut_swath_requested(peer_id: int, held_slot: int, plants: PackedInt32Array) -> void:
	var swing: Dictionary = items.swath_swing(peer_id, held_slot)

	if swing.is_empty():
		return

	var player_at: Variant = items.position_of(peer_id)

	if player_at == null:
		return

	var grasses: Array = swing["grasses"]
	var reach: float = float(swing["radius"]) + SWATH_SLACK_M
	var cut: int = int(swing["crops"])

	@warning_ignore("integer_division")
	var triples: int = plants.size() / 3   # whole triples only

	for n in range(mini(triples, SWATH_MOST)):
		var chunk: Vector2i = Vector2i(plants[n * 3], plants[n * 3 + 1])
		var id: int = plants[n * 3 + 2]
		var species: Dictionary = flora.placer._by_id.get(id >> 16, {})

		if species.is_empty():
			continue

		if not _chunk_in_reach(player_at, chunk):
			continue   # nothing is looked up, or generated, far away

		if int(species["kind"]) == PlacerScript.KIND_SHRUB:
			var info: Dictionary = _shrub_info(chunk, id)   # a placer bush or one planted from a dug-up bush

			if not info.is_empty() and Vector2((player_at as Vector3).x - info["position"].x, (player_at as Vector3).z - info["position"].z).length() <= reach and _cut_tree(chunk, id):
				cut += 1
		elif int(species["kind"]) != PlacerScript.KIND_TREE and grasses.has(str(species["name"])):
			items.swath_mult = float(swing["mult"])
			items.plant_stays = false   # a pick that skips gather() (was_picked) must not take the last plant's "stays standing"

			if _pick_flora(peer_id, chunk, id, reach):
				cut += 1

			items.swath_mult = 0.0

	if cut == 0:
		net.notice.rpc_id(peer_id, "Nothing to cut here: the %s cuts grass, ripe grain and bushes" % str(swing["tool"]))


# Whether the chunk's square comes within GATHER_REACH_M (flat) of the player: nothing is gathered, or generated, far away.
func _chunk_in_reach(player_at: Vector3, chunk: Vector2i) -> bool:
	var chunk_m: float = flora.placer.chunk_m
	var near_x: float = clampf(player_at.x, float(chunk.x) * chunk_m, float(chunk.x + 1) * chunk_m)
	var near_z: float = clampf(player_at.z, float(chunk.y) * chunk_m, float(chunk.y + 1) * chunk_m)
	return Vector2(player_at.x - near_x, player_at.z - near_z).length() <= GATHER_REACH_M


# One plant or shrub picked by `peer` (E, or a grass in a sickle or scythe swing): what drops.json and its season allow. `near_m` >= 0: only when the plant
# stands that close (flat) to the player (a swing), and never a tree. True when it gave something.
func _pick_flora(peer_id: int, chunk: Vector2i, id: int, near_m: float = -1.0) -> bool:
	var player_at: Variant = items.position_of(peer_id)

	if player_at == null or not _chunk_in_reach(player_at, chunk):
		return false

	var home: Vector2i = flora.placer.normalize(chunk)
	var all: Dictionary = flora.items_of(home)
	var at: int = all["ids"].find(id)
	var species: Dictionary = flora.placer._by_id.get(id >> 16, {})

	var fruit_tree: bool = not species.is_empty() and int(species["kind"]) == PlacerScript.KIND_TREE and (items._drops.get("fruit_tree", {}) as Dictionary).has(str(species["name"]))

	if at < 0 or species.is_empty() or (int(species["kind"]) == PlacerScript.KIND_TREE and not fruit_tree):
		return false

	if near_m >= 0.0 and (int(species["kind"]) == PlacerScript.KIND_TREE or Vector2((player_at as Vector3).x - all["positions"][at].x, (player_at as Vector3).z - all["positions"][at].z).length() > near_m):
		return false

	# Dave 2026-10-20: a picked plant disappears from the world, like a picked stone. Only a pick that gave
	# something removes it (server_items.gd); one that gave nothing leaves the plant alone.
	var key: String = "%d,%d,%d" % [home.x, home.y, id]

	# A plant picked bare before this rule (still in the saved "picked" list) goes now, giving nothing.
	var gave: bool = items.was_picked(key) or items.gather(peer_id, str(species["name"]), PlacerScript.KINDS[int(species["kind"])], key, id, all["positions"][at], float(all["heights"][at]))

	if gave and cues != null:
		cues.cue(peer_id, CuesScript.CUE_PICK, id >> 16, all["positions"][at] + Vector3(0.0, minf(float(all["heights"][at]) * 0.5, 1.5), 0.0))   # the others nearby hear it picked (protocol 156; a swath's many plants give one: the cue gap)

	if gave and fruit_tree:
		# A fruit tree stays; its store shrinks: every client learns how much was taken, and an empty tree is bare (no prompt, no fruit drawn).
		net.flora_fruit.rpc(chunk, PackedInt32Array([id]), PackedInt32Array([items.fruit_taken(key)]))

		if items.fruit_left(str(species["name"]), key, id, float(all["heights"][at])) <= 0:
			net.flora_stripped.rpc(chunk, PackedInt32Array([id]))
	elif gave and items.plant_stays:
		net.flora_stripped.rpc(chunk, PackedInt32Array([id]))      # a berry bush: it stays, bare until the season changes
	elif gave and flora.cut(chunk, id):
		net.flora_cut.rpc(chunk, id)

	return gave


func _on_dig_requested(peer_id: int, center: Vector3, radius: float) -> void:
	if not admin.is_admin(items.key_of(peer_id)):
		print("Admin dig refused for peer %d" % peer_id)
		return

	if not limits.allow(peer_id, "dig"):
		return

	# A flying admin's reported spot stays where they last stood still (terrain_client.gd _update_anchor), so their own dig would
	# wait in _edits_held until they stop (Lane A, 18 Nov 2026); it goes to them at once.
	_edit_by = peer_id
	_dig_ground(center, radius)
	_edit_by = 0


# The client has no world tiles (protocol 132): the summits round its tile and its valley-fog cells are read here (server_coarse_ground.gd).
# Only for the ground round the player, as the tiles on the client gave before; a far ask is refused (the client asks again in 15 s).
func _on_summits_requested(peer_id: int, tile: Vector2i) -> void:
	var at: Variant = items.position_of(peer_id)

	if at is Vector3 and limits.allow(peer_id, "coarse_ground"):
		var here: Vector2i = Vector2i(int(floor(at.x / float(settings.tile_size_m))), int(floor(at.z / float(settings.tile_size_m))))

		if absi(tile.x - here.x) <= 1 and absi(tile.y - here.y) <= 1:
			coarse_ground.ask_summits(peer_id, tile)


func _on_fog_cells_requested(peer_id: int, origin: Vector2) -> void:
	var at: Variant = items.position_of(peer_id)
	var centre: Vector2 = origin + Vector2.ONE * FogGroundScript.WINDOW_M * 0.5

	if at is Vector3 and origin.is_finite() and centre.distance_to(Vector2(at.x, at.z)) < FogGroundScript.REBUILD_M * 2.0 and limits.allow(peer_id, "coarse_ground"):
		coarse_ground.ask_fog(peer_id, origin)


# A joining client's saved copy of a tile is older than the tile (protocol 128): it gets the edits since, to forget only those blocks.
func _on_edits_since_requested(peer_id: int, tile: Vector2i, since: int) -> void:
	if not limits.allow(peer_id, "edits_since"):
		return

	var answer: Dictionary = store.edits_since(tile, since)
	net.edits_since.rpc_id(peer_id, tile, since, int(answer["revision"]), answer["spheres"], bool(answer["whole"]))


# The first edit after a quiet half second is announced at once; edits that follow within it are announced together when it ends
# (_process); each client then marks the blocks round its recent edits as outdated again (terrain_client.gd _on_tile_changed).
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
		return float(_water_at(Vector3(x, 0.0, z), false)[0])
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


# Water land types, R1 (design/WATER_LAND_TYPES.md): classifies the 200 m box round (x, z) from the live water (instant reading; the running
# 30 day signature is not wired into the water thread yet), draws it as letters (. dry, L lake, R river, M marsh, S swamp, B bog, F floodplain,
# * spring that passes the catch-basin rule, ! spring that fails it) and writes <store>/land_types_X_Z.txt. Admin button "Land types here".
func _land_types(x: float, z: float) -> String:
	var tile: Vector2i = generator.tile_of(x, z)
	var data = water_live.data_of(tile) if water_live != null else null
	var sim = water_live.sim_of(tile) if water_live != null else null

	if data == null or sim == null:
		return "no running water sim for the tile at %d, %d" % [int(x), int(z)]

	var half: int = 12
	var ci: int = int(round((x - data.x0) / sim.spacing_m))
	var cj: int = int(round((z - data.z0) / sim.spacing_m))
	var depth: PackedFloat32Array = sim.get_depth()
	var letters: String = ".LRMSBF"
	var counts: Array = [0, 0, 0, 0, 0, 0, 0]
	var rows: PackedStringArray = PackedStringArray()
	var spring_at: Dictionary = {}
	var passing: int = 0
	var failing: int = 0

	for spring in sim.springs:
		var report: Dictionary = LandTypeScript.basin_report(sim.ground, data.water_class, sim.side, int(spring[0]))
		spring_at[int(spring[0])] = bool(report["ok"])

	for j in range(maxi(cj - half, 1), mini(cj + half, sim.side - 2) + 1):
		var row: String = ""

		for i in range(maxi(ci - half, 1), mini(ci + half, sim.side - 2) + 1):
			var n: int = j * sim.side + i
			var t: int = LandTypeScript.DRY

			if depth[n] >= 0.01 or data.water_class[n] == 2 or data.water_class[n] == 3:
				var peaty: bool = n < data.soil.size() and data.soil[n] == 6
				var warm: bool = n < data.biome.size() and data.biome[n] == 10 and not peaty
				var wet: float = 1.0 if depth[n] >= LandTypeScript.WET_M else 0.0
				t = LandTypeScript.classify_cell(depth[n], LandTypeScript.speed_cell(sim.ground, depth, sim.side, sim.spacing_m, n), wet, data.water_class[n], peaty, warm)

			counts[t] += 1
			row += letters[t]

			if spring_at.has(n):
				row = row.substr(0, row.length() - 1) + ("*" if spring_at[n] else "!")

				if spring_at[n]:
					passing += 1
				else:
					failing += 1

		rows.append(row)

	var summary: String = "tile %s: dry %d, lake %d, river %d, marsh %d, swamp %d, bog %d, floodplain %d; springs in the box: %d pass the basin rule, %d fail" % [str(tile), counts[0], counts[1], counts[2], counts[3], counts[4], counts[5], counts[6], passing, failing]
	var path: String = _store_path + "/land_types_%d_%d.txt" % [int(x), int(z)]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return summary + " (cannot write " + path + ")"

	file.store_string("land types at x %.0f z %.0f (8 m cells, north up, 25 x 25)\n. dry L lake R river M marsh S swamp B bog F floodplain * spring in a basin ! spring NOT in a basin\n%s\n%s\n" % [x, z, "\n".join(rows), summary])
	file.close()
	print("server: land types written to ", path)
	return summary


# Running water for placement rules (src/stream/water_flow.gd): the speed in m/s of the settled water at a point (-1 none, 0 still), and the
# power of a water wheel spanning a to b (WaterFlow.wheel: {"w", "why", "along"}; Sonny's water rules section 10).
func _water_flow_at(point: Vector3) -> float:
	if water_live == null:
		return WaterFlowScript.NO_WATER

	return WaterFlowScript.speed_at(generator, water_live.data_of(generator.tile_of(point.x, point.z)), point.x, point.z)


func _water_wheel(a: Vector3, b: Vector3) -> Dictionary:
	if water_live == null:
		return {"w": 0.0, "why": "dry"}

	return WaterFlowScript.wheel(generator, water_live.data_of(generator.tile_of(a.x, a.z)), a, b, WaterFlowScript.load_rules(), items.water_depth_at)


# Where a loose item let go at `from` comes to rest (terrain_generator.floor_below: the generated ground, a cave's floor, the saved digs and fills).
func _floor_below(from: Vector3) -> float:
	return generator.floor_below(from, store.ops.edits_near(Vector3(from.x, from.y - 12.0, from.z), 12.0))   # every edit touching the 24 m column, oldest first


# Admin "Reset all terrain edits": every saved dig and fill (rubble included) is deleted, the ground and water are made again from the
# baked tiles, the tunnel clocks start clean and every player reloads. Buildings, items and plants are not touched.
func _reset_terrain_edits() -> void:
	var error: String = store.reset_edits()

	if error != "":
		print("server: reset of terrain edits failed: ", error)
		return

	store.clear_generated()
	edited_ground.forget()
	animals.ground_changed(Vector3.ZERO, INF)   # every animal back onto the generated ground
	flora.clear_memory()
	generator.forget_tiles()
	WaterGridScript.forget_ground()

	if water_live != null:
		water_live.stop()
		water_live = null

	_start_water()

	if tunnels != null:
		tunnels.set_enabled(tunnels.enabled)

	_cave_streams_sent.clear()
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

	for warned in result["warn"]:
		net.notice.rpc_id(int(warned), "The tunnel ceiling is creaking: brace it or leave.")

	# Where each rumble comes from (Dave 2 Nov 2026: cave-in rumbles nowhere near a cave): the dug space, its span and how short its support is.
	for at in result.get("warn_at", []):
		_events.event("tunnel creaking: peer %d at %s, dug space at %s (span %.1f m, need %.2f)" % [int(at[0]), str(items.position_of(int(at[0]))), str(at[1]), float(at[2]), float(at[3])])

	for leak in result["leak"]:
		net.leak.rpc_id(leak[0], leak[1], leak[2])

	for collapse in result["collapse"]:
		_events.event("tunnel collapse: %d cells, %d fills, victims %s" % [int(collapse["cells"]), (collapse["fills"] as Array).size(), str(collapse["victims"])])

		for victim in collapse["victims"]:
			var was: Variant = items.position_of(int(victim))
			var above: Vector3 = items.respawn_point
			var fire: Array = _cave_rescue(was) if was != null else []   # dug out and carried to the nearest campfire (Dave 23 Nov 2026)

			if not fire.is_empty():
				above = fire[0][0]
			elif was != null:   # no fire out of the rock: the top of the ground (a fill on it counts) or of the water over it, never inside rock or under a lake
				above = Vector3(was.x, ItemsScript.dug_out_height(float(generator.surface_height(was.x, was.z)), float(animals.ground_height.call(was.x, was.z)), float(_water_at(Vector3(was.x, 0.0, was.z))[0])), was.z)

			if not items.survive_cave_in(int(victim), above, not fire.is_empty()):   # death.json stop_at_1: dug out onto the ground above, health 1
				items.kill(int(victim), "cave-in")

		for fill in collapse["fills"]:
			_fill_ground(fill[0], fill[1], tunnels.rubble_material)


# A dig (material -1) or fill to the players near it (EDIT_SEND_M); the others' copies wait in _edits_held. A player's held edits
# near them go first, so edits to the same spot arrive in the order they were made.
func _send_edit(center: Vector3, radius: float, material: int) -> void:
	for peer in multiplayer.get_peers():
		var peer_id: int = int(peer)
		var at: Variant = center if peer_id == _edit_by else items.position_of(peer_id)

		# Behind a backlog of held edits near the player it waits its turn, so edits to one spot keep their order.
		if at != null and _edit_near(at, center) and not _send_held_edits(peer_id, at):
			_send_one_edit(peer_id, center, radius, material)
			continue

		var held: Array = _edits_held.get(peer_id, [])
		held.append([center, radius, material])
		_edits_held[peer_id] = held

		if held.size() > EDITS_HELD_MAX:
			var oldest: Array = held.pop_front()
			_send_one_edit(peer_id, oldest[0], oldest[1], oldest[2])


func _send_one_edit(peer_id: int, center: Vector3, radius: float, material: int) -> void:
	if material < 0:
		net.dug.rpc_id(peer_id, center, radius)
	else:
		net.filled.rpc_id(peer_id, center, radius, material)


# Sends a player the held edits now within EDIT_SEND_M of them, oldest first and at most EDITS_RELEASE_MAX; the rest keep waiting.
# True when some near ones are still waiting. (Two edits to the same spot that straddle the range edge can arrive out of order;
# that far out the client's finest ground is not loaded, so each only marks its saved blocks to be fetched again, which does not
# depend on the order.)
func _send_held_edits(peer_id: int, at: Vector3) -> bool:
	var held: Array = _edits_held.get(peer_id, [])

	if held.is_empty():
		return false

	var waiting: Array = []
	var sent: int = 0
	var behind: bool = false

	for edit in held:
		if sent < EDITS_RELEASE_MAX and _edit_near(at, edit[0]):
			_send_one_edit(peer_id, edit[0], edit[1], edit[2])
			sent += 1
		else:
			behind = behind or sent >= EDITS_RELEASE_MAX
			waiting.append(edit)

	if waiting.is_empty():
		_edits_held.erase(peer_id)
	else:
		_edits_held[peer_id] = waiting

	return behind


# The dig regions' 2 m water to each player within EDIT_SEND_M of them (fine_water_send.gd): `fresh` names the regions whose picture just
# changed. Nothing goes to a player for whom nothing changed, or whose spot is not known yet (the next half-second check sends it).
func _send_fine(fresh: Dictionary) -> void:
	if _fine_keys.is_empty() and _fine_named.values().all(func(k): return (k as PackedStringArray).is_empty()):
		return   # no dig water anywhere, and every player has been told so

	for peer in multiplayer.get_peers():
		var peer_id: int = int(peer)
		var at: Variant = items.position_of(peer_id)

		if at == null:
			continue

		var told: Dictionary = _fine_told.get(peer_id, {})
		var out: Dictionary = FineWaterSend.for_peer(at, generator.period_m, EDIT_SEND_M, _fine_keys, _fine_cache, fresh, told,
				_fine_named.get(peer_id, PackedStringArray()))
		_fine_told[peer_id] = told

		if out["send"]:
			_fine_named[peer_id] = out["keys"]
			net.deliver_fine_water.rpc_id(peer_id, out["keys"], out["packets"])


# Within EDIT_SEND_M across the ground, the world's wrap included.
func _edit_near(at: Vector3, center: Vector3) -> bool:
	var period: float = generator.period_m
	var dx: float = fposmod(center.x - at.x + period * 0.5, period) - period * 0.5
	var dz: float = fposmod(center.z - at.z + period * 0.5, period) - period * 0.5
	return dx * dx + dz * dz <= EDIT_SEND_M * EDIT_SEND_M


func _dig_ground(center: Vector3, radius: float) -> bool:
	var t0: int = Time.get_ticks_usec()
	var tiles: Array = store.dig_sphere(center, radius)
	var t1: int = Time.get_ticks_usec()

	# Nothing changed (the ground there is already dug out, or the block's log is full): no message to the clients, no
	# water wake, no log line. A held click on one spot used to do all of it every time and the server fell behind.
	if tiles.is_empty():
		return false

	_fill_last = []
	_send_edit(center, radius, -1)   # before tile_changed: the client re-marks the edits it has heard of when that comes (terrain_client.gd _on_tile_changed)

	for tile in tiles:
		_tell_tile_changed(tile)

	tunnels.mark_edit(center, radius)
	_ground_moved(center, radius)
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


# The animals' ground changed round a dig or fill: its cells are read again and the animals standing there come to rest on it.
func _ground_moved(center: Vector3, radius: float) -> void:
	if edited_ground != null:
		edited_ground.changed(center, radius)

	if animals != null:
		animals.ground_changed(center, radius)


# A shovel fill: the sphere of ground is saved in the edit log (store.fill_sphere), the water thread raises its ground
# there, and everyone is told. Returns false when nothing changed (the block holds its edit limit).
func _fill_ground(center: Vector3, radius: float, material: int) -> bool:
	# The same fill again with no dig in between changes nothing (a held click): dropped before it costs a log entry, a tile
	# revision, two messages and a water wake.
	if _fill_last == [center, radius, material]:
		return false

	var tiles: Array = store.fill_sphere(center, radius, material)

	if not tiles.is_empty():
		_fill_last = [center, radius, material]
		_send_edit(center, radius, material)   # before tile_changed, as in _dig_ground

	for tile in tiles:
		_tell_tile_changed(tile)

	if not tiles.is_empty():
		tunnels.mark_edit(center, radius)
		_ground_moved(center, radius)
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
	animals.watched.clear()

	for watched_id in items.spyglass.values():
		if int(watched_id) > 0:
			animals.watched[int(watched_id)] = true   # the animal an admin watches through the spyglass keeps living (server_animals tick)

	# Each player is looked at about four times a second, a fifth of them per pass, so the work never lands on one tick.
	animals.begin_send_pass()   # each animal's row built once this pass, the animals found by grid (docs/design/SERVER_SCALE.md)

	for n in range(_send_round % 5, peers.size(), 5):
		var peer: int = int(peers[n])
		var at: Variant = items.position_of(peer)

		if at == null:
			continue

		var rows: Array = npcs.rows_near(at)
		var signature: int = hash(rows)   # not str(rows): turning every player's rows into text 4 times a second was the dearest part (load test 23 Nov 2026)

		# The rows ride an unreliable channel and an idle crowd never changes, so a lost first packet (or one that came before the
		# client had built its NPC view) was never sent again: Dave's Ctrl+N saw "roster 2, drawn 0". Resend unchanged rows every 2 s.
		var now_ms: int = Time.get_ticks_msec()

		if not _npc_sent.has(peer) or int(_npc_sent[peer]) != signature or now_ms - int(_npc_sent_ms.get(peer, 0)) > 2000:
			_npc_sent[peer] = signature
			_npc_sent_ms[peer] = now_ms
			net.npcs.rpc_id(peer, rows)

		# The spyglass (docs/design/spyglass_design.md): out to the spyglass radius while one is looked through (the admin glass: animals.json
		# "spyglass"; a spyglass item: its tier in data/items/spyglass.json), and the watched animal's readout (admin, or a tier with one).
		var spy: int = int(items.spyglass.get(peer, 0)) if items.spyglass.has(peer) else -2
		var reach: Array = items.spyglass_reach(peer, animals.cfg.get("spyglass", {}))
		var beasts: Array = animals.rows_near(at, float(reach[0]), int(reach[1])) if spy >= 0 else animals.rows_near(at)
		var sig: int = hash(beasts)

		if spy == -1:
			items.spyglass.erase(peer)
			net.animal_info.rpc_id(peer, -1, {})
		elif spy > 0:
			net.animal_info.rpc_id(peer, spy, animals.info_of(spy))

		if not _animal_sent.has(peer) or int(_animal_sent[peer]) != sig or now_ms - int(_animal_sent_ms.get(peer, 0)) > 2000:
			_animal_sent[peer] = sig
			_animal_sent_ms[peer] = now_ms
			net.animals.rpc_id(peer, beasts, Time.get_ticks_msec())   # with the server clock the row times are on (protocol 147)

		for block in trails.updates_for(peer, at, now_ms):
			net.trails.rpc_id(peer, block[0], block[1], block[2], block[3])
			map_knowledge.note_trails(peer, Vector2i(block[0], block[1]), block[3])   # kept for the Map's trails (protocol 152)

		for block in map_knowledge.updates_for(peer, now_ms):
			net.map_blocks.rpc_id(peer, block[0], block[1], block[2], block[3], block[4])

		for block in map_knowledge.trail_updates_for(peer):
			net.map_trails.rpc_id(peer, block[0], block[1], block[2])

		var marks_sig: int = items.trap_marks_sig(peer)   # the snares and Bird traps this character has set, marked on its Map (protocol 150): sent when they change

		if not _trap_marks_sent.has(peer) or int(_trap_marks_sent[peer]) != marks_sig:
			_trap_marks_sent[peer] = marks_sig
			net.trap_marks.rpc_id(peer, items.trap_marks(peer))

		var trail: PackedVector3Array = animals.blood_near(at)
		var trail_sig: int = hash(trail)

		if int(_blood_sent.get(peer, 0)) != trail_sig:
			_blood_sent[peer] = trail_sig
			net.blood.rpc_id(peer, trail)

		var holes: PackedVector3Array = animals.burrows_near(at)
		var holes_sig: int = hash(holes)

		if int(_burrows_sent.get(peer, 0)) != holes_sig:
			_burrows_sent[peer] = holes_sig
			net.burrows.rpc_id(peer, holes)

		var nest_rows: Array = animals.nest_spots_near(at)
		var nests_sig: int = hash(nest_rows[0])

		if int(_nests_sent.get(peer, 0)) != nests_sig:
			_nests_sent[peer] = nests_sig
			net.nests.rpc_id(peer, nest_rows[0], nest_rows[1])

		var hole_rows: Array = items.ice_holes_near(at)
		var hole_sig: int = hash([hole_rows[0], hole_rows[1]])

		if int(_holes_sent.get(peer, 0)) != hole_sig:
			_holes_sent[peer] = hole_sig
			net.ice_holes.rpc_id(peer, hole_rows[0], hole_rows[1])

		var far_rows: Array = items.far_fires_near(at)   # their smoke seen from a hill (TEST-011)
		var far_sig: int = 1 + far_rows[0].size()

		for i in range(far_rows[0].size()):
			far_sig += hash([far_rows[0][i], far_rows[1][i]])   # order-free: two fires swapping rank as the player walks send nothing (the client ranks them itself)


		if int(_far_fires_sent.get(peer, 0)) != far_sig:
			_far_fires_sent[peer] = far_sig
			net.far_fires.rpc_id(peer, far_rows[0], far_rows[1])

	animals.end_send_pass()


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


# A small file written whole and taken away again: a read-only store, or one with no room for a save, stops the start with a clear line
# instead of a server that plays on and saves nothing.
func _store_writable(dir: String) -> bool:
	var probe: String = dir + "/write_check.json"
	var ok: bool = ItemsScript._write_file(probe, JSON.stringify({"version": 1, "checked": Time.get_unix_time_from_system(), "room": " ".repeat(65536)}))

	for one in [probe, probe + ".prev", probe + ".tmp"]:
		DirAccess.remove_absolute(one)

	return ok


func _process(delta: float) -> void:
	if _refused_start:
		return

	if store == null:
		return

	game_clock.follow(Time.get_ticks_usec())   # real time, not the clipped frame delta (game_clock.gd follow)
	var frame_now: int = Time.get_ticks_msec()

	if _last_frame_msec > 0 and frame_now - _last_frame_msec >= IDLE_YIELD_GAP_MS:
		_idle_hold_until_msec = frame_now + IDLE_YIELD_MS

	_last_frame_msec = frame_now
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
	_night_skip_frame()
	_events.mark("fish signs")
	if fish_signs != null:
		fish_signs.tick()
	_events.mark("tunnels+buried")
	_tunnel_tick()
	_send_buried()
	_events.mark("npcs")
	npcs.unwell = dialogue.router.is_unwell()
	tribes.tick(delta)
	npcs.tick(delta)
	_events.mark("animals")
	_refresh_fire_spots()
	animals.tick(delta)
	coarse_ground.tick()
	_events.mark("trails")

	for peer in items._peer_pos:
		trails.note_player(peer, items._peer_pos[peer])   # players' own worn paths (stage 2c): a write only on entering a new 4 m cell

	trails.tick(delta)
	_events.mark("ranges")   # its own step: a cold join's WATCHDOG named "trails" for 6 s (22 Nov), which also held these
	ranges.tick(npcs.player_positions.call(), Time.get_ticks_msec())
	_events.mark("bandits")
	bandits.tick()
	bandits.camp_tick(delta, items.peer_positions())
	_events.mark("map knowledge")
	map_knowledge.tick(delta)   # the save interval only
	_events.mark("send npcs")
	_send_npcs(delta)
	_events.mark("send players")
	players.tick(delta)
	_events.mark("deliver blocks")

	# Send what the workers made, batched per peer.
	_done_mutex.lock()
	var done: Array = _done
	_done = []
	var water_done: Array = _water_done
	_water_done = []
	_done_mutex.unlock()

	for entry in water_done:
		if _peers.has(entry[0]) and _water_changed_for(entry[0], entry[1], entry[2]):
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
			_water_changed_for(entry[0], entry[1], entry[4])
			net.deliver_flora.rpc_id(entry[0], entry[1], entry[2], entry[4], entry[5])
			_send_stripped(entry[0], entry[1])
			_send_drink_points(entry[0], entry[1])
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

	# One tile_changed per tile per half second however many edits there were, and the revision file once a second.
	if now - _tiles_told_msec >= 500:
		_tiles_told_msec = now

		for tile in _tiles_changed:
			net.tile_changed.rpc(tile, store.revision_of(tile))

		_tiles_changed.clear()
		_events.mark("checks: held edits")

		for peer_id in _edits_held.keys():
			var at: Variant = items.position_of(int(peer_id))

			if not multiplayer.get_peers().has(int(peer_id)):
				_edits_held.erase(peer_id)
			elif at != null:
				_send_held_edits(int(peer_id), at)

		_events.mark("checks: fine water")
		_send_fine({})   # a player who came within reach of a wet dig gets its water
		_events.mark("checks: revisions file")
		store.save_revisions()
		_events.mark("checks: flora removed file")

		if items.fells_on_disk():   # a felled tree's removal is written after its stump and logs (server_items fells_on_disk)
			flora.save_removed()

	_events.mark("checks: flags, report")
	var flag_path: String = _store_path + "/clear_generated.now"

	if now >= _flag_check_msec:
		_flag_check_msec = now + 3000

		var dump_flag: String = _store_path + "/water_dump.now"

		if FileAccess.file_exists(dump_flag):
			var spot: PackedStringArray = FileAccess.get_file_as_string(dump_flag).strip_edges().split(" ", false)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dump_flag))

			if spot.size() >= 2:
				print("server: water dump asked for: ", _dump_water(float(spot[0]), float(spot[1])))

		if FileAccess.file_exists(_store_path + STOP_NOW):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_store_path + STOP_NOW))
			print("server: stop asked (stop.now); saving and closing with %d players here" % _peers.size())
			_events.event("QUIT: stop asked (stop.now), %d players here" % _peers.size())
			_quit_at_msec = now + _tell_closing()
			_run_note("closing", _listen_port)

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
			flora.pack = null   # prebuilt plants stand on the old tiles: placed afresh until a pack for the new tiles is installed
			flora.clear_memory()
			WaterGridScript.forget_ground()

			# The water ran on the old ground (owner, 2026-10-19: it stood as a dome where the
			# new bake had taken the pond away): start it again on the new tiles.
			if water_live != null:
				water_live.stop()
				water_live = null

			_start_water()

			_cave_streams_sent.clear()
			net.ground_reset.rpc(store.tiles_stamp, _starter_stamp())
			print("server: the tile files changed (a bake finished); generated ground thrown away, players reload")

	if now >= _report_at_msec:
		_report_at_msec = now + 10000
		var report: String = "server: %d urgent and %d prefetch queued; generated %d, cache hits %d, edit hits %d, air from the table %d; flora chunks %d made, %d from memory; idle-built %d columns; bad blocks %d, failed tile loads %d" % [
			queued[0], queued[1], store.blocks_generated, store.cache_hits, store.edit_hits, store.air_hits, flora.chunks_made, flora.memory_hits, _idle_built, store.bad_blocks, generator.failed_tiles
		]

		if _link != null and _link.blocks_out > 0:
			report += "\nserver: %d blocks sent on the block line (%.1f MB)" % [_link.blocks_out, float(_link.bytes_out) / 1048576.0]

		var rows: String = store.made_rows_report()

		if rows != "":
			report += "\nserver: " + rows

		if report != _last_report or now - _last_report_msec >= 300000:   # an idle server printed the same two lines every 10 s; once in 5 min shows it is alive
			_last_report = report
			_last_report_msec = now
			_print_off_main(report)

	if _quit_when_empty and _quit_at_msec < 0:
		if not _peers.is_empty():
			_empty_since_msec = 0
		elif _empty_since_msec == 0:
			_empty_since_msec = now
			_quit_grace_msec = 300000 if _never_joined else NetSettings.value("server_empty_grace_s", 120) * 1000
			# Said out loud (Dave 17 Nov 2026: a Play server outlived his quit and the logs could not say why): a game that joins inside this
			# time gets this server, whatever code is on disk now; Play asks one of other code to close (_stop_if_asked).
			print("server: no players; closing in %d s unless someone joins" % int(_quit_grace_msec / 1000.0))
			_events.event("EMPTY: no players; closing in %d s unless someone joins" % int(_quit_grace_msec / 1000.0))
		elif now - _empty_since_msec >= _quit_grace_msec:
			print("server: no players left")
			_events.event("QUIT: no players left for %d s" % int(_quit_grace_msec / 1000.0))
			_quit_at_msec = now
			_run_note("closing", _listen_port)

	if _watch_parent_pid > 0 and now >= _watch_next_msec and _quit_at_msec < 0:
		_watch_next_msec = now + 3000

		if not OS.is_process_running(_watch_parent_pid):
			print("server: the parent process %d is gone, closing" % _watch_parent_pid)
			_events.event("QUIT: the parent process %d is gone" % _watch_parent_pid)
			_quit_at_msec = now

	if _quit_when_empty and now >= _stop_check_msec and _quit_at_msec < 0:
		_stop_check_msec = now + 2000
		_stop_if_asked(now)

	if _dev_reset_at_msec > 0 and now >= _dev_reset_at_msec:   # testing only: the same two steps as ACT_RESET_WORLD, without a player
		_dev_reset_at_msec = -1
		print("server: dev reset world: %d world rows removed" % items.reset_world())
		_reset_terrain_edits()

	if _quit_at_msec > 0 and now >= _quit_at_msec:
		_quit_at_msec = -1
		_close_players()
		var flush_from: int = Time.get_ticks_msec()
		store.flush()
		_events.event("shutdown: ground flushed in %d ms" % (Time.get_ticks_msec() - flush_from))
		DirAccess.remove_absolute(_run_note_path())
		print("server: done; generated %d, cache hits %d, edit hits %d" % [store.blocks_generated, store.cache_hits, store.edit_hits])
		get_tree().quit(0)

	_events.mark("between frames (rpc handlers, engine)")


# The 10 s report lines on a worker, like the items log lines (a print flushes the log on the PC's debug build: #397, #1491).
func _print_off_main(line: String) -> void:
	if items != null:
		items._log_off_main(line)
	else:
		print(line)


# A dedicated server keeps its notes and logs with its store (a container's one volume); Play's server keeps them where the launcher looks.
func _run_note_path() -> String:
	return _store_path + "/server_run.json" if _dedicated else RUN_NOTE


func _log_dir() -> String:
	return _store_path + "/logs" if _dedicated else "res://crash_reports"


# Tells the launcher (another process, same user folder) which server is on the port: its process, commit, whether it is closing and
# whether it obeys Play's stop request ("stop": 1, a server Play started; _stop_if_asked).
# A game started while the old server is closing, or from a newer checkout, replaces it instead of joining a server that
# will stop answering (Dave, build 619: stuck on "0 blocks arriving").
func _run_note(state: String, listen_port: int, why: String = "") -> void:
	var file: FileAccess = FileAccess.open(_run_note_path(), FileAccess.WRITE)

	if file != null:
		var note: Dictionary = {"pid": OS.get_process_id(), "port": listen_port, "commit": _commit, "state": state, "stop": 1 if _quit_when_empty else 0}

		if why != "":
			note["why"] = why   # "refused": the game's connect window shows it (terrain_client.gd _play_server_refused)
			note["t"] = Time.get_unix_time_from_system()

		file.store_string(JSON.stringify(note))
		file.close()


# Play found this server on its port running other code (Dave 17 Nov 2026: he pulled dev, pressed Play and joined the server from before the
# pull) and asks it to close. Only a request naming this process and another commit is obeyed, only by a server Play started
# (--quit-when-empty), and only with nobody playing on it: it closes the normal way (ground flushed, world and inventories saved in
# _exit_tree), so Play can start one on the new code.
# A stop with players here (a restart or an update, run_server.sh stop.now): each is told why (NetScript.SERVER_CLOSING) and the quit waits
# CLOSING_TELL_MS for that notice to go out; returns that wait (0 with nobody here).
const CLOSING_TELL_MS := 1500


func _tell_closing() -> int:
	if _peers.is_empty():
		return 0

	for peer in _peers.keys():
		net.notice.rpc_id(int(peer), NetScript.SERVER_CLOSING)

	return CLOSING_TELL_MS


# The players' connections are closed the normal way as the server quits (their games hear it at once and show the "connection lost"
# window with the reason, not 60 to 120 s later at their line's timeout). Their spots are noted and saved as before (_exit_tree).
func _close_players() -> void:
	var peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer

	if peer == null or _peers.is_empty():
		return

	for id in _peers.keys():
		peer.disconnect_peer(int(id))   # a polite goodbye (not forced): each game gets server_disconnected

	peer.host.flush()


func _stop_if_asked(now: int) -> void:
	if not FileAccess.file_exists(STOP_NOTE):
		return

	var asked: Variant = JSON.parse_string(FileAccess.get_file_as_string(STOP_NOTE))

	if not PlayServerScript.stop_is_for(asked, OS.get_process_id()):
		return

	var from: String = str(asked.get("commit", ""))

	if from == _commit:
		DirAccess.remove_absolute(STOP_NOTE)
		return   # a request left behind from before this server started (same process number again): Play only asks a server of other code

	if not _peers.is_empty():
		# Someone is playing here: they are not dropped. Play sees the request taken without "closing" and joins; its join screen says out of date.
		print("server: Play from commit %s asked this server (commit %s) to close; %d players here, staying up" % [from, _commit, _peers.size()])
		_events.event("STOP REFUSED: Play from commit %s asked; %d players here" % [from, _peers.size()])
		DirAccess.remove_absolute(STOP_NOTE)
		return

	print("server: Play from commit %s asked this server (commit %s) to close" % [from, _commit])
	_events.event("QUIT: Play from commit %s asked this server (commit %s) to close" % [from, _commit])
	_quit_at_msec = now
	_run_note("closing", _listen_port)
	DirAccess.remove_absolute(STOP_NOTE)   # after "closing" is written: Play reads a taken request with no "closing" as refused


func _send(peer_id: int, batch: Array) -> void:
	net.deliver_blocks.rpc_id(peer_id, batch[0], batch[1])
	_peers[peer_id]["blocks"] += batch[1].size()
	_peers[peer_id]["bytes"] += int(batch[2])


# True while a flora chunk may take a worker: flora leaves one worker for the ground (the join, lag lane 23 Nov 2026); one worker in all takes both.
static func flora_may_start(flora_running: int, max_running: int) -> bool:
	return flora_running < max_running - 1 or max_running <= 1


# Worker thread: takes the next block, urgent ones first, and makes it.
func _worker_loop() -> void:
	while true:
		_work.wait()
		_queue_mutex.lock()
		var item: Array = []
		var flora_item: Array = []

		# Order: urgent blocks, flora chunks, prefetch blocks.
		var water_item: Array = []

		# Lag lane 23 Nov 2026 (cloud join, timestamped): the joining player's first flora chunks (about 1 s each) took all three workers, and
		# urgent ground waited behind them: 3 blocks in the first 6 s after the welcome. Flora now leaves one worker for the ground.
		if _queue.is_empty() and not _flora_queue.is_empty() and flora_may_start(_flora_running, _max_running):
			flora_item = _flora_queue.pop_front()
			_flora_running += 1
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
			_queue_mutex.lock()
			_flora_running -= 1
			var flora_left: bool = not _flora_queue.is_empty()
			_queue_mutex.unlock()

			if flora_left:
				_work.post()   # a flora chunk passed over at the cap above gets a worker now
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


# The spawn and the most recent saved spots go in as idle anchors under ids below zero (no peer has one), so the idle
# builders make and save the ground round them with no one connected: after a TERRAIN_VERSION change threw the
# generated ground away, the first joins find it built. With the ground already saved this is only store look-ups.
# Each such anchor is dropped once its circle is done; players' own anchors always go first.
func _seed_idle_spots() -> void:
	var spots: Array = [spawn]
	spots.append_array(items.saved_spots(IDLE_SAVED_SPOTS))
	var id: int = -1

	for spot in spots:
		_idle_anchor[id] = Vector3i(int(floor(spot.x / 16.0)), 0, int(floor(spot.z / 16.0)))
		id -= 1


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

		if busy or anchors.is_empty() or _bake_running or Time.get_ticks_msec() < _idle_hold_until_msec:
			OS.delay_msec(20)
			continue

		var worked: bool = false
		# Players in the order they asked (ids above zero), then the start-up spots, spawn first.
		var order: Array = anchors.keys().filter(func(id): return id > 0)
		var spots: Array = anchors.keys().filter(func(id): return id < 0)
		spots.sort_custom(func(a, b): return a > b)
		order.append_array(spots)

		for peer in order:
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

			if peer < 0 and cursor[1] >= _idle_offsets.size():
				_queue_mutex.lock()
				var dropped: bool = _idle_anchor.erase(peer)   # the other idle thread may have finished it first
				_queue_mutex.unlock()

				if dropped:
					print("server: ground round start-up spot %d is claimed (built, found saved, or being built by the other idle thread)" % -peer)

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
	ItemsScript.restore_missing(path)

	if not FileAccess.file_exists(path):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY and FileAccess.file_exists(path + ".prev"):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(path + ".prev"))   # damaged: the save before it

	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("seconds"):
		game_clock.seconds = float(parsed["seconds"])


func _save_game_clock() -> void:
	_clock_saved_msec = Time.get_ticks_msec()

	if _store_path == "":
		return

	ItemsScript._write_file(_store_path + "/game_clock.json", JSON.stringify({"seconds": game_clock.seconds}))   # whole to a .tmp, then moved over: a hard stop never tears it


func _exit_tree() -> void:
	_events.event("EXIT: server closed (exit_tree)")
	_events.stop_watchdog()

	if not _refused_start:   # it never started: nothing is saved over the files it could not read (items.save is a no-op then; the threads still join)
		_save_game_clock()

	tunnels.stop()

	if animals != null:
		animals.fog_ground_finish()

	coarse_ground.finish()

	if trails != null:
		trails.save()

	if bandits != null:
		bandits.save()

	if map_knowledge != null:
		map_knowledge.save()

	if items != null:
		items.note_spots_on_close()   # players still in: where they stand now, not the last 10 s note
		items.save()
		items._finish_writer()   # a save with nothing new returns early: the last autosave's files and log lines still finish before the exit
		print("server save: %d flushes to the disk, %.1f ms each on average (sync -f before and after each header)" % [ItemsScript.syncs, ItemsScript.sync_ms / maxf(1.0, float(ItemsScript.syncs))])

	_bury_mutex.lock()
	_bury_queue.clear()
	_bury_stop = true
	_bury_mutex.unlock()

	if _bury_thread != null:
		_bury_sem.post()
		_bury_thread.wait_to_finish()
		_bury_thread = null

	if flora != null and not _refused_start:
		flora.save_removed(true)

	if animals != null and animals.goblins != null:
		animals.goblins.trust.save()   # goblin friendship (goblin_trust.json)

	if animals != null and animals.companions != null:
		animals.companions.save()   # companions (companions.json)

	if animals != null and animals.wolves != null:
		animals.wolves.save_dens()   # wolf dens (wolf_dens.json)

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

	# The pool tasks nothing else waits for: none may still run while the engine shuts its worker pool down (PoolTasks; main gate 21 Nov).
	_cover_tasks.finish()

	if items != null:
		items.finish_resources()   # the island resource landscape's build (start_resources)

	if flora != null:
		flora.finish_tasks()

	if generator != null:
		generator.finish_tasks()

	if store != null and OS.has_environment("BLOCKTIME"):
		print(store.timing_report())

	if store != null:
		store.flush()

	_events.close()   # last: nothing may start a log worker task while the engine shuts down (EventLog.close)


# Known dangers for the island resource landscape's starting-island check (handoff 13: "use existing danger information where available"):
# the camp of every goblin tribe that will not trade (its attitude's trades false) and every bandit site whose camp stands (stage 3), each
# with boulders.json distribution danger_m round it. Read once at start; nothing new is made for it.
# Under rock (a cave or a dug tunnel, _under_rock) the nearest campfire out of the rock comes first (_cave_rescue, Dave 23 Nov 2026).
# Where a player passed out from cold can be carried (Dave 23 Nov 2026): every goblin camp, every bandit camp, and the starter town (Edda and
# Hob's fire; without one the square of data/npcs/markers.json, else the middle of the markers; never the spawn). Each spot is moved a few metres off a camp's fire and
# off any tree, onto the ground. Only the nearest to `near` is grounded (reading trunks and tiles for every camp stalled the main thread):
# [[Vector3, "goblin" | "bandit" | "town"]], or [] when there is none. Not on the tick: only when someone passes out.
func _rescue_spots(near: Vector3) -> Array:
	var off_m: float = float((items._warmth_cfg.get("pass_out", {}) as Dictionary).get("off_fire_m", 2.5))
	var out: Array = []

	if _under_rock(near):   # passed out in a cave or tunnel: to the nearest campfire out of the rock (Dave 23 Nov 2026), else as below
		var fire: Array = _cave_rescue(near)

		if not fire.is_empty():
			return fire

	for tribe in tribes.tribes():
		var camp: Dictionary = (tribes.tribes()[tribe] as Dictionary).get("camp", {})
		var at: Dictionary = camp.get("fire", {})   # only a camp with a fire: a cave mouth alone has no warmth to wake in

		if at.has("x"):
			out.append([Vector2(float(at.get("x", 0.0)) + off_m, float(at.get("z", 0.0))), "goblin"])

	for cell in bandits.sites:
		var site: Dictionary = bandits.sites[cell]

		if int(site.get("stage", 0)) >= int(bandits.CAMP):
			out.append([Vector2(float(site.get("x", 0.0)) + off_m, float(site.get("z", 0.0))), "bandit"])

	# The town: beside Edda and Hob's fire (it always burns), not on the square 19 m off it, out of its warmth (coordinator 23 Nov 2026: "you wake
	# inside the warmth of its fire"). Its tree stands on the fire's west side (data/npcs/camp.json), so off_m east is clear of the trunk.
	var town: Vector2 = NpcCampScript.fire_spot()

	if town.x != INF:
		town.x += off_m
	else:
		town = animals.town

		for row in npcs._read("res://data/npcs/markers.json").get("markers", []):
			if str(row.get("kind", "")) == "square" and not row.has("npc"):
				town = Vector2(float(row.get("x", 0.0)), float(row.get("z", 0.0)))

	if town.x != INF:
		out.append([town, "town"])

	var best: Array = []

	for spot in out:
		if best.is_empty() or (spot[0] as Vector2).distance_to(Vector2(near.x, near.z)) < (best[0] as Vector2).distance_to(Vector2(near.x, near.z)):
			best = spot

	return [] if best.is_empty() else [[_rescue_ground(best[0]), best[1]]]


# Under rock: in a generated cave (_in_cave), or with more than CAVE_ROOF_M of ground over it as dug and filled (a dug tunnel; an open pit is not).
func _under_rock(p: Vector3) -> bool:
	if _in_cave(p):
		return true

	if generator == null or not generator.tile_cached(p.x, p.z):
		return false   # a tile not in memory is not read for this on the main thread (a far fire): taken as open

	var top: float = float(animals.ground_height.call(p.x, p.z)) if animals != null and animals.ground_height.is_valid() else NAN
	return not is_nan(top) and top - p.y > CAVE_ROOF_M


# A player rescued in a cave or tunnel (Dave 23 Nov 2026: "if you are in a cave and end up getting rescued they should deposit you at the
# nearest civilization and for these purposes that means campfire for now"): the nearest campfire that is not itself under rock, any owner's,
# lit or not, the town's and the goblin and bandit camps' fires included, set down off_fire_m off it inside its warmth as every wake spot
# (_rescue_ground). [[spot, "campfire" | "town" | "goblin" | "bandit"]], or [] when there is no fire out of the rock (the caller's own place stands).
func _cave_rescue(near: Vector3) -> Array:
	var off_m: float = float((items._warmth_cfg.get("pass_out", {}) as Dictionary).get("off_fire_m", 2.5))
	var fires: Array = items.campfires()   # the camps' fires are world items too (camp fires, lay_bandit_camp)
	var best: Array = ItemsScript.nearest_fire_out_of_rock(fires, near, func(p: Vector3) -> bool: return _under_rock(p), func(x: float, z: float) -> float: return float(generator.surface_height(x, z)))
	return [] if best.is_empty() else [[_rescue_ground(Vector2(best[0].x + off_m, best[0].z)), best[1]]]


# A step off a tree or wet ground stays within search_m (warmth.json pass_out wake_search_m) of the spot, so the player still wakes in the fire's warmth.
func _rescue_ground(at: Vector2) -> Vector3:
	var search_m: float = float((items._warmth_cfg.get("pass_out", {}) as Dictionary).get("wake_search_m", 1.5))
	var trunks: PackedVector2Array = _trunks_near(at, 32.0)
	var ground_at: Callable = func(x: float, z: float) -> float: return float(generator.surface_height(x, z))
	var wet_at: Callable = func(x: float, z: float) -> bool: return _baked_wet(x, z)
	var clear: Vector2 = SpawnPointScript.clear_of(at, trunks, ground_at, wet_at, {"search_m": search_m, "ring_m": 0.5, "clear_m": 1.3})

	if clear == at and not SpawnPointScript._trunk_free(at, trunks, 1.3):
		clear = SpawnPointScript.clear_of(at, trunks, ground_at, wet_at)   # a thicket round the fire: out of a tree first, the warmth second
	var edited: float = float(animals.ground_height.call(clear.x, clear.y)) if animals != null and animals.ground_height.is_valid() else NAN
	return Vector3(clear.x, ItemsScript.dug_out_height(float(generator.surface_height(clear.x, clear.y)), edited, NAN), clear.y)   # 2 m over the ground, a fill on it too


func _resource_dangers() -> Array:
	var reach: float = float((items._boulder_cfg.get("distribution", {}) as Dictionary).get("danger_m", 200.0))
	var out: Array = []
	var attitudes: Dictionary = tribes.cfg.get("attitudes", {})

	for tribe in tribes.tribes():
		var attitude: Dictionary = attitudes.get(str((tribes.tribes()[tribe] as Dictionary).get("attitude", "")), {})
		var camp: Dictionary = (tribes.tribes()[tribe] as Dictionary).get("camp", {})
		var at: Dictionary = camp.get("fire", camp.get("mouth", {}))

		if not bool(attitude.get("trades", true)) and not at.is_empty():
			out.append([float(at.get("x", 0.0)), float(at.get("z", 0.0)), reach])

	for cell in bandits.sites:
		var site: Dictionary = bandits.sites[cell]

		if int(site.get("stage", 0)) >= int(bandits.CAMP):
			out.append([float(site.get("x", 0.0)), float(site.get("z", 0.0)), reach])

	return out


# Skipping the night (server_items.gd night_skip): the real seconds to pass so the latest sleeper's sunrise comes, when it is night at every
# sleeper's spot (after their sunset or before their sunrise: sunset is as far after noon as sunrise is before it), else 0. No skip in a polar
# day (no night) or a polar night (no dawn).
func _night_skip_real_s(peers: Array) -> float:
	var day: float = WeatherScript.year_phase(game_clock.seconds) * float(GameClockScript.DAYS_PER_YEAR)   # starter-calendar: the declination is the one sky's, the latitude each sleeper's row (as animals.sunrise_now)
	var sunrises: Array = []

	for peer in peers:
		var pos: Vector3 = items._peer_pos.get(peer, Vector3.INF)
		sunrises.append(WeatherScript.sunrise_hour(day, NAN if not pos.is_finite() else ClimateScript.latitude_of_row(ClimateScript.row_of_z(pos.z, float(settings.tile_size_m)), settings.equator_tile_row)))

	return ItemsScript.night_to_dawn_h(game_clock.hour(), sunrises) * 3600.0 / GameClockScript.RATIO


# One frame of a night skip: the clock moves on by a step and the world's slow work and the players' vitals catch up by the same (a minute of
# real time a frame, so the catch-up is spread out instead of one long freeze); at the end everyone wakes and the clients' clocks jump with it.
func _night_skip_frame() -> void:
	if not items.night_skipping():
		return

	var t0: int = Time.get_ticks_usec()
	var step: float = minf(items._night_left, items.NIGHT_SKIP_STEP_S)
	game_clock.advance(step)
	items.night_skip_step()
	_night_cost_usec += Time.get_ticks_usec() - t0
	_night_worst_usec = maxi(_night_worst_usec, Time.get_ticks_usec() - t0)
	_night_frames += 1

	if not items.night_skipping():
		items.night_skip_finish()
		net.game_time.rpc(game_clock.seconds)
		_save_game_clock()
		print("night skip: dawn at hour %.2f, day %d; %d frames, %.1f ms in all, %.1f ms the longest frame" % [game_clock.hour(), game_clock.day_of_year(), _night_frames, float(_night_cost_usec) / 1000.0, float(_night_worst_usec) / 1000.0])   # starter-calendar: a log line
		_night_frames = 0
		_night_cost_usec = 0
		_night_worst_usec = 0
