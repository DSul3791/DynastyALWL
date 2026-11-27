extends Node

# Looks made ahead of the welcome (coordinator 26 Nov 2026, option (a) of the join lag): on Lane A's Low route the welcome's one frame spent
# 1011 ms making the waterfall mist and 450 ms the rain and snow (98617e37: then 1307 ms the rain's splash) (their particle and shader materials, made for the GPU the first time;
# headless the same costs a few ms). This runner makes them during the title and character menus, one look a frame, and keeps them; the
# welcome takes the made one (fall_mist.gd, weather_look.gd) instead of making its own. A player who skips the menus gets them made in the
# frames while the client waits for the welcome (terrain_client.gd _ready starts it too); a look not made in time is made at the welcome,
# as before. Window only: headless runs (tests, the lane's smokes) make everything at the welcome, unchanged.
# Each look's time is printed ("look warm: ... N ms"), so the lane log says what each costs where it now falls.

const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")
const FallMistScript := preload("res://src/client/fall_mist.gd")
const STEPS := ["splash", "fall_mist", "rain", "snow"]   # largest first: a player who skips the menus gets the welcome about 4 frames in (Lane A 7bba32bd)

static var _runner: Node = null
static var _made: Dictionary = {}   # step -> its made node, until taken
static var _done: Dictionary = {}   # step -> true once made (taken or not), so a second runner does not make it again

var _next: int = 0


# Starts the runner once per run (the launcher in the menus, terrain_client.gd _ready when the menus were skipped); does nothing headless.
static func start(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless" or tree == null or is_instance_valid(_runner) or _done.size() >= STEPS.size():
		return

	var runner: Node = load("res://src/client/look_warm.gd").new()   # its own script, by path: static code has no self to call new() on
	runner.name = "LookWarm"
	_runner = runner
	tree.root.add_child.call_deferred(runner)   # the root outlives the menu scenes, so the made looks wait across scene changes


# The made look of `step`, taken out of the runner (the caller adds it where it belongs), or null when it was not made yet. Either way the step
# is done: the welcome made its own, so the runner never makes it later, in play.
static func take(step: String) -> Node:
	_done[step] = true

	if not _made.has(step):
		return null

	var node: Node = _made[step]
	_made.erase(step)

	if not is_instance_valid(node):
		return null

	if node.get_parent() != null:
		node.get_parent().remove_child(node)

	return node


func _process(_delta: float) -> void:
	while _next < STEPS.size() and _done.has(str(STEPS[_next])):
		_next += 1

	if _next >= STEPS.size():
		set_process(false)
		return

	var step: String = STEPS[_next]
	var t0: int = Time.get_ticks_usec()
	var node: Node = _make(step)
	_done[step] = true
	_next += 1

	if node != null:
		_made[step] = node
		add_child(node)   # in the tree out of sight (nothing emits), so whatever the renderer makes on entering is done here too

	FreezeWatchScript.printer.line("look warm: %s %.0f ms" % [step, float(Time.get_ticks_usec() - t0) / 1000.0])


static func _make(step: String) -> Node:
	match step:
		"fall_mist":
			var mist: Node3D = FallMistScript.new()
			mist.name = "FallMist"
			mist.setup(0)   # the cards per fall follow the game's quality at the welcome (set_quality)
			return mist
		"rain", "snow":
			var weather: Node = load("res://src/client/weather_look.gd").new()   # load, not preload: weather_look.gd preloads this script
			var made: Node = weather.make_particles(step)
			weather.free()
			return made
		"splash":
			var weather: Node = load("res://src/client/weather_look.gd").new()
			var parts: Node = weather.make_splash_parts()
			weather.free()
			return parts

	return null


func _exit_tree() -> void:
	_made.clear()   # the made looks not taken go with this node (the game closed from a menu)
