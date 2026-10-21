extends RefCounted

# The server's running water for one tile (DESIGN_IDEAS 6.18). Loads the settled water,
# then keeps ticking on its own thread while the flow rate is being tuned, and hands the
# main thread a fresh set of drawing levels every PUBLISH_TICKS ticks.
#
# The flow rate is one number for every spring (a multiplier on the baked rate); the
# +/- keys step it by RATE_STEP. Runs only the tile it was given; the server swaps the
# result into the tile's `sim_levels` and tells clients to redraw.

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
var rate: float = DEFAULT_RATE
var runoff: float = 1.0          # rain makes the springs run stronger (the server sets it from the weather, WEATHER_RUNOFF)
var busy: bool = false

var _generator
var _base_rate: float = 3.0
var _path: String = ""
var _thread: Thread = null
var _mutex: Mutex = Mutex.new()
var _budget: float = 0.0          # simulated seconds left to run
var _quit: bool = false
var _pending: PackedFloat32Array = PackedFloat32Array()
var _pending_falls: PackedFloat32Array = PackedFloat32Array()
var fall_levels: PackedFloat32Array = PackedFloat32Array()   # set by take_levels, see _fall_levels
var _ticks: int = 0
var _dry_start: bool = false
var _digs: Array = []              # [center, radius] waiting for the water thread


# With dry_start the tile begins with no fresh water at all (only the sea): the springs
# fill the ponds and the rivers run down on their own, so the real water paths show.
func setup(tile_data, water_path: String, base_rate: float, tile_generator, dry_start: bool = false) -> void:
	_dry_start = dry_start

	if dry_start:
		_budget = START_SECONDS

	data = tile_data
	_generator = tile_generator
	_path = water_path
	_base_rate = base_rate
	_thread = Thread.new()
	_thread.start(_run)


func stop() -> void:
	_mutex.lock()
	_quit = true
	_mutex.unlock()

	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


# Steps the rate up (+1) or down (-1) and sets the water running toward it.
func step_rate(direction: int) -> float:
	_mutex.lock()
	rate = clampf(rate * (RATE_STEP if direction > 0 else 1.0 / RATE_STEP), RATE_MIN, RATE_MAX)
	_budget = maxf(_budget, RUN_SECONDS)
	var now: float = rate
	_mutex.unlock()
	return now


# A player dug a hole: the water thread lowers its ground there and runs again.
func dig(center: Vector3, radius: float) -> void:
	_mutex.lock()
	_digs.append([center, radius])
	_budget = maxf(_budget, RUN_SECONDS)
	_mutex.unlock()


# Rain swells the rivers: the springs run `value` times stronger (1 is dry weather). Wakes the
# water when it moves enough to matter, so the rivers follow it.
func set_runoff(value: float) -> void:
	_mutex.lock()

	if absf(value - runoff) > 0.02:
		_budget = maxf(_budget, RUN_SECONDS)

	runoff = value
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


func _run() -> void:
	var sim = WaterSettler.build(data, _base_rate, _generator, not _dry_start)
	print("water: running on the %s core" % ("C++" if sim.native() else "GDScript (the C++ add-on did not load)"))
	print("water: %d springs at %s" % [sim.springs.size(), str(sim.springs.map(func(sp): return [int(sp[0]) % data.samples, int(sp[0]) / data.samples]))])
	var saved: PackedFloat32Array = PackedFloat32Array() if _dry_start else WaterStore.load_depth(_path, data.samples)

	if not saved.is_empty():
		sim.set_depth(saved)
		sim.wake_all_wet()

	var since: int = 0
	var channel: PackedInt32Array = PackedInt32Array()

	for k in range(data.water_class.size()):
		if data.water_class[k] != 0 and data.heights[k] > 0.0:
			channel.append(k)

	var held: PackedByteArray = PackedByteArray()
	held.resize(channel.size())

	while true:
		_mutex.lock()
		var quit: bool = _quit
		var run: bool = _budget > 0.0
		var multiplier: float = rate * runoff
		var digs: Array = _digs
		_digs = []

		busy = run
		_mutex.unlock()

		if quit:
			return

		if not run:
			OS.delay_msec(100)
			continue

		var tick_start: int = Time.get_ticks_usec()

		for hole in digs:
			var cells: int = sim.dig(hole[0], hole[1], Vector2(data.x0, data.z0))
			print("water: a dig at %s lowered %d water squares" % [str(hole[0]), cells])

		# The rate scales the springs only; the water itself moves by gravity and
		# friction, so a low rate drains the rivers to a trickle (owner, 2026-10-19).
		sim.spring_multiplier = multiplier
		sim.step()
		_mutex.lock()
		_budget -= sim.dt
		_mutex.unlock()
		since += 1

		if since >= (START_PUBLISH_TICKS if _dry_start else PUBLISH_TICKS) or _budget <= 0.0:
			since = 0
			var levels: PackedFloat32Array = sim.level_map()
			_hold_channel(sim, levels, channel, held)
			var falls: PackedFloat32Array = _fall_levels(sim, levels, channel)
			_mutex.lock()
			_pending = levels
			_pending_falls = falls
			_mutex.unlock()

		# Technical direction (2026-10-20): the water thread shares the PC with the client, so
		# it sleeps in proportion to the work it did and uses at most CPU_DUTY of one core
		# (CPU_DUTY_STORM at the x20 storm), running slower than real time when it must.
		var duty: float = lerpf(CPU_DUTY, CPU_DUTY_STORM, clampf((multiplier / DEFAULT_RATE - 1.0), 0.0, 1.0))
		var busy_us: int = Time.get_ticks_usec() - tick_start
		OS.delay_usec(int(float(busy_us) * (1.0 / duty - 1.0)))


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
