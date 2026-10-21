extends RefCounted

# The server's running water for one tile (DESIGN_IDEAS 6.18). Loads the water, then the
# WaterHub's single thread ticks it (begin, then tick) while the flow rate is being tuned, and
# a fresh set of drawing levels is handed to the main thread every PUBLISH_TICKS ticks.
#
# The flow rate is one number for every spring (a multiplier on the baked rate); the
# +/- keys step it by RATE_STEP (the hub holds it). The server swaps the result into the
# tile's `sim_levels` and tells clients to redraw.

const WaterSettler := preload("res://src/water/water_settler.gd")
const WaterStore := preload("res://src/water/water_store.gd")

const RATE_STEP := 1.1            # each + or - key press changes the rate by about 10 %
const RATE_MIN := 0.5            # owner (2026-10-19): 0.5x looks most like a brook and still keeps flowing
const RATE_MAX := 40.0           # owner (2026-10-19): higher than 5x, for floods; 4x the start rate since 2026-10-20
# Owner (2026-10-20): at x1 the rivers broke into patches on the way down and wandered; at x10
# they reach the ocean whole. Every pond's spring starts at x10.
const DEFAULT_RATE := 10.0
const CPU_DUTY := 0.5             # share of one core the water thread may use (it sleeps the rest)
const CPU_DUTY_STORM := 0.33      # the same at x20 (twice the start flow), when each step costs most
const PUBLISH_TICKS := 15
# The water moves in real seconds now (water_sim.gd), so these are simulated time.
const RUN_SECONDS := 7200.0       # simulated time to run after each change (rivers settle to the new flow), then the water rests
const START_SECONDS := 21600.0    # a dry start runs this long on its own, so the springs fill the land
const START_PUBLISH_TICKS := 40
# Owner report (2026-10-20, build 130 bake): the water poured over the pond lip and down the
# cliff, but as a film a few cm to 20 cm deep, thinner than the draw rules (water_sim.gd
# WET_M 0.12 m, STEEP_WET_M 0.6 m on drops), so the lip and the fall showed as dry dirt.
# On the baked channel (brook, river, fall) any water this deep is drawn.
const CHANNEL_WET_M := 0.01
const FALL_FILM_M := 0.02        # thin water on a baked channel this deep counts for finding falls
const CHANNEL_POOL_M := 0.5      # drawn water this deep beside a film cell is a pond or pool
const HOLD_M := 0.03             # drawn channel water stays drawn until it is thinner than this (hysteresis)
const CHANNEL_BANK_M := 1.0      # a film cell no more than this above drawn water beside it is the bank, not the fall

var data
var sim = null                    # the tile's WaterSim, built by begin() on the water thread
var tile: Vector2i = Vector2i.ZERO
var busy: bool = false
var rate: float = DEFAULT_RATE   # set by the hub (one flow rate for every tile)
var runoff: float = 1.0          # likewise: rain makes the springs run stronger

var _generator
var _base_rate: float = 3.0
var _path: String = ""
var _mutex: Mutex = Mutex.new()
var _budget: float = 0.0          # simulated seconds left to run
var _pending: PackedFloat32Array = PackedFloat32Array()
var _pending_falls: PackedFloat32Array = PackedFloat32Array()
var fall_levels: PackedFloat32Array = PackedFloat32Array()   # set by take_levels, see _fall_levels
var _dry_start: bool = false
var _digs: Array = []              # [center, radius, filled] waiting for the water thread
var _since: int = 0
var _channel: PackedInt32Array = PackedInt32Array()
var _held: PackedByteArray = PackedByteArray()


# With dry_start the tile begins with no fresh water at all (only the sea): the springs
# fill the ponds and the rivers run down on their own, so the real water paths show. The
# tile only runs when the WaterHub (src/water/water_hub.gd) calls begin() and tick().
func setup(tile_coord: Vector2i, tile_data, water_path: String, base_rate: float, tile_generator, dry_start: bool = false) -> void:
	tile = tile_coord
	_dry_start = dry_start

	if dry_start:
		_budget = START_SECONDS

	data = tile_data
	_generator = tile_generator
	_path = water_path
	_base_rate = base_rate


# Builds the simulation (several seconds): the first thing the water thread does for a tile.
# With `saved` depths (a tile unloaded earlier this session) it carries on from them.
func begin(saved: PackedFloat32Array = PackedFloat32Array()) -> void:
	sim = WaterSettler.build(data, _base_rate, _generator, not _dry_start)
	print("water %s: running on the %s core, %d springs" % [str(tile), "C++" if sim.native() else "GDScript (the C++ add-on did not load)", sim.springs.size()])
	var from_file: PackedFloat32Array = PackedFloat32Array()

	if saved.is_empty() and not _dry_start:
		from_file = WaterStore.load_depth(_path, data.samples)

	var start: PackedFloat32Array = saved if not saved.is_empty() else from_file

	if not start.is_empty():
		sim.set_depth(start)
		sim.wake_all_wet()

	_since = 0
	_channel = PackedInt32Array()

	for k in range(data.water_class.size()):
		if data.water_class[k] != 0 and data.heights[k] > 0.0:
			_channel.append(k)

	_held = PackedByteArray()
	_held.resize(_channel.size())


# Saves the water depths and drops the simulation (an unloaded tile). Returns the depths so the
# hub can keep them for this session; the file in the world's water folder is the saved copy.
func unload() -> PackedFloat32Array:
	var depth: PackedFloat32Array = PackedFloat32Array()

	if sim != null:
		depth = sim.get_depth()
		WaterStore.save(_path, data.samples, depth)
		sim = null

	return depth


# Seconds of water simulated so far (the hub steps the tile furthest behind).
func seconds() -> float:
	return sim.seconds if sim != null else 0.0


# Whether this tile has anything to run: time left in its budget, or a dig waiting.
func wants_run() -> bool:
	_mutex.lock()
	var run: bool = _budget > 0.0 or not _digs.is_empty()
	busy = run
	_mutex.unlock()
	return run


# Gives the water more time to run (a flow change, a dig, rain).
func wake(seconds_to_run: float = RUN_SECONDS) -> void:
	_mutex.lock()
	_budget = maxf(_budget, seconds_to_run)
	_mutex.unlock()


# A player dug a hole: the water thread lowers its ground there and runs again.
func dig(center: Vector3, radius: float) -> void:
	_edit(center, radius, false)


# A player filled ground in (a dam): the water thread raises its ground there and runs again.
func fill(center: Vector3, radius: float) -> void:
	_edit(center, radius, true)


func _edit(center: Vector3, radius: float, filled: bool) -> void:
	_mutex.lock()
	_digs.append([center, radius, filled])
	_budget = maxf(_budget, RUN_SECONDS)
	_mutex.unlock()


# New drawing levels from the water thread, or empty when there is nothing new.
func take_levels() -> PackedFloat32Array:
	_mutex.lock()
	var levels: PackedFloat32Array = _pending
	_pending = PackedFloat32Array()

	if not levels.is_empty():
		fall_levels = _pending_falls
	_mutex.unlock()
	return levels


# One tick on the water thread at `multiplier` times the spring rate; publishes drawing levels
# now and then. Returns the simulated seconds the tick covered.
func tick(multiplier: float) -> float:
	_mutex.lock()
	var digs: Array = _digs
	_digs = []
	_mutex.unlock()

	for hole in digs:
		if hole[2]:
			print("water %s: a fill at %s raised %d water squares" % [str(tile), str(hole[0]), sim.fill(hole[0], hole[1], Vector2(data.x0, data.z0))])
		else:
			print("water %s: a dig at %s lowered %d water squares" % [str(tile), str(hole[0]), sim.dig(hole[0], hole[1], Vector2(data.x0, data.z0))])

	# The rate scales the springs only; the water itself moves by gravity and
	# friction, so a low rate drains the rivers to a trickle (owner, 2026-10-19).
	sim.spring_multiplier = multiplier
	sim.step()
	_mutex.lock()
	_budget -= sim.dt
	var out_of_time: bool = _budget <= 0.0
	_mutex.unlock()
	_since += 1

	if _since >= (START_PUBLISH_TICKS if _dry_start else PUBLISH_TICKS) or out_of_time:
		_since = 0
		var levels: PackedFloat32Array = sim.level_map()
		_hold_channel(sim, levels, _channel, _held)
		var falls: PackedFloat32Array = _fall_levels(sim, levels, _channel)
		_mutex.lock()
		_pending = levels
		_pending_falls = falls
		_mutex.unlock()

	return sim.dt


# Owner report (2026-10-21): near the ocean the rivers ran low and blotchy, patches flipping
# between water and bank. A channel cell drawn last publish stays drawn, at its true level,
# until its water is thinner than HOLD_M, so a shallow reach sloshing around the 12 cm draw
# depth is a steady ribbon. `held` is 1 on the channel cells drawn last time (updated here).
static func _hold_channel(sim, levels: PackedFloat32Array, channel: PackedInt32Array, held: PackedByteArray) -> void:
	if levels.size() != sim.ground.size():
		return

	var depth: PackedFloat32Array = sim.get_depth()

	for n in range(channel.size()):
		var k: int = channel[n]

		if is_nan(levels[k]) and held[n] == 1 and depth[k] >= HOLD_M and sim.ground[k] > 0.0 and not (depth[k] < sim.STEEP_WET_M and sim._is_steep(k)):
			levels[k] = sim.ground[k] + depth[k]

		held[n] = 0 if is_nan(levels[k]) else 1


# Draws thin running water on the channel cells the sim's own draw rules leave out, at the
# water's true level. Owner report (2026-10-20, build 145): films on a pond's rim cells
# (sloshing a few cm) drawn above the pond climbed its bank like a wall, so a film is skipped
# where its bed is within CHANNEL_BANK_M of the drawn water beside it; a cell further above
# (the fall face, or the ramp below a lip) is drawn.
static func _show_channel(sim, levels: PackedFloat32Array, channel: PackedInt32Array) -> PackedFloat32Array:
	if levels.size() != sim.ground.size():
		return levels

	var depth: PackedFloat32Array = sim.get_depth()
	var side: int = int(sqrt(float(levels.size())))
	var drawn: PackedFloat32Array = levels.duplicate()

	for k in channel:
		if not is_nan(levels[k]) or depth[k] < CHANNEL_WET_M:
			continue

		var level: float = sim.ground[k] + depth[k]
		var climbs: bool = false
		var column: int = k % side

		for n in [k - 1, k + 1, k - side, k + side, k - side - 1, k - side + 1, k + side - 1, k + side + 1]:
			if n < 0 or n >= levels.size() or absi(n % side - column) > 1:
				continue

			if not is_nan(drawn[n]) and depth[n] >= CHANNEL_POOL_M and sim.ground[k] <= drawn[n] + CHANNEL_BANK_M:
				climbs = true
				break

		if not climbs:
			levels[k] = level

	return levels


# Owner report (2026-10-20, build 200): no water went over pond B's cliff, though the river
# ran at its foot. A spring's flow down a cliff is only about 10 cm thick, and thin water on
# a steep drop is not drawn (water_sim.gd STEEP_WET_M), so the fall finder saw no wet points
# on the face and made no fall. For the fall finder only, the drawn levels plus the thin
# water on the baked channels: the falls are drawn as ribbons, so this never puts a film on
# a bank.
static func _fall_levels(sim, levels: PackedFloat32Array, channel: PackedInt32Array) -> PackedFloat32Array:
	if levels.size() != sim.ground.size():
		return levels

	var depth: PackedFloat32Array = sim.get_depth()
	var out: PackedFloat32Array = levels.duplicate()

	for k in channel:
		if is_nan(out[k]) and depth[k] >= FALL_FILM_M:
			out[k] = sim.ground[k] + depth[k]

	return out
