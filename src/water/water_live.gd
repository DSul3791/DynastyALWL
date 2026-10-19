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
const RATE_MIN := 0.1
const RATE_MAX := 5.0
const PUBLISH_TICKS := 15
const RUN_TICKS := 3000           # ticks to run after each change (long enough for rivers to drain to a trickle), then the water rests
const START_TICKS := 20000        # a dry start runs this long on its own, so the springs fill the land
const START_PUBLISH_TICKS := 40

var data
var rate: float = 1.0
var busy: bool = false

var _generator
var _base_rate: float = 3.0
var _path: String = ""
var _thread: Thread = null
var _mutex: Mutex = Mutex.new()
var _budget: int = 0
var _quit: bool = false
var _pending: PackedFloat32Array = PackedFloat32Array()
var _ticks: int = 0
var _dry_start: bool = false


# With dry_start the tile begins with no fresh water at all (only the sea): the springs
# fill the ponds and the rivers run down on their own, so the real water paths show.
func setup(tile_data, water_path: String, base_rate: float, tile_generator, dry_start: bool = false) -> void:
	_dry_start = dry_start

	if dry_start:
		_budget = START_TICKS

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
	_budget = maxi(_budget, RUN_TICKS)
	var now: float = rate
	_mutex.unlock()
	return now


# New drawing levels from the water thread, or empty when there is nothing new.
func take_levels() -> PackedFloat32Array:
	_mutex.lock()
	var levels: PackedFloat32Array = _pending
	_pending = PackedFloat32Array()
	_mutex.unlock()
	return levels


func _run() -> void:
	var sim = WaterSettler.build(data, _base_rate, _generator, not _dry_start)
	print("water: %d springs at %s" % [sim.springs.size(), str(sim.springs.map(func(sp): return [int(sp[0]) % data.samples, int(sp[0]) / data.samples]))])
	var saved: PackedFloat32Array = PackedFloat32Array() if _dry_start else WaterStore.load_depth(_path, data.samples)

	if not saved.is_empty():
		sim.depth = saved
		sim.wake_all_wet()

	var since: int = 0

	while true:
		_mutex.lock()
		var quit: bool = _quit
		var run: bool = _budget > 0
		var multiplier: float = rate

		if run:
			_budget -= 1

		busy = run
		_mutex.unlock()

		if quit:
			return

		if not run:
			OS.delay_msec(100)
			continue

		sim.spring_multiplier = multiplier
		# Owner (2026-10-19): turning the springs down must let the rivers drain to a
		# trickle, so a low rate never slows the water itself down.
		sim.speed_multiplier = clampf(multiplier, 1.0, 1.2)
		sim.step()
		since += 1

		if since >= (START_PUBLISH_TICKS if _dry_start else PUBLISH_TICKS) or _budget == 0:
			since = 0
			var levels: PackedFloat32Array = sim.level_map()
			_mutex.lock()
			_pending = levels
			_mutex.unlock()
