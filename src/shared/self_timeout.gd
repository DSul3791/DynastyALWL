extends Node

# Testing-only self shutdown (Dave via the moderator, 31 Oct 2026): a process we start for a test, rig or probe ends by itself. Opt-in flags, and with none of them there is NO limit,
# so a normal server or game is unaffected:
#   --timeout=300  (or  --timeout 300)   quit cleanly after that many seconds
#   --watch-parent=PID                   quit cleanly when that process is gone (the launcher died or was killed)
# The server reads the same flags in terrain_server.gd (it already has a clean quit path); the client and the bot add this node.
#   Self.parse(args) -> {"seconds": float (0 = none), "parent": int (0 = none)}

signal due(reason: String)

var seconds: float = 0.0
var parent_pid: int = 0
var _begun_ms: int = 0
var _next_check_ms: int = 0


static func parse(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"seconds": 0.0, "parent": 0}

	for i in range(args.size()):
		var a: String = args[i]

		if a.begins_with("--timeout="):
			out["seconds"] = maxf(float(a.trim_prefix("--timeout=")), 0.0)
		elif a == "--timeout" and i + 1 < args.size() and args[i + 1].is_valid_float():
			out["seconds"] = maxf(float(args[i + 1]), 0.0)
		elif a.begins_with("--watch-parent="):
			out["parent"] = maxi(int(a.trim_prefix("--watch-parent=")), 0)

	return out


# Adds the watcher to `host` when a flag is present; returns it (or null). `on_due` is called with the reason; the default quits the tree.
static func install(host: Node, args: PackedStringArray, on_due: Callable = Callable()) -> Node:
	var parsed: Dictionary = parse(args)

	if float(parsed["seconds"]) <= 0.0 and int(parsed["parent"]) <= 0:
		return null

	var watcher = load("res://src/shared/self_timeout.gd").new()
	watcher.name = "SelfTimeout"
	watcher.seconds = float(parsed["seconds"])
	watcher.parent_pid = int(parsed["parent"])
	watcher._begun_ms = Time.get_ticks_msec()
	host.add_child(watcher)
	watcher.due.connect(on_due if on_due.is_valid() else func(reason: String):
		print("self timeout: %s, quitting" % reason)
		host.get_tree().quit(0))
	return watcher


# Why it is time to stop, "" when not: pure, so a test can call it with a clock.
func reason_at(now_ms: int, parent_alive: bool) -> String:
	if seconds > 0.0 and float(now_ms - _begun_ms) >= seconds * 1000.0:
		return "--timeout=%d reached" % int(seconds)

	if parent_pid > 0 and not parent_alive:
		return "parent process %d is gone" % parent_pid

	return ""


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()

	if now < _next_check_ms:
		return

	_next_check_ms = now + 1000
	var why: String = reason_at(now, parent_pid <= 0 or OS.is_process_running(parent_pid))

	if why != "":
		set_process(false)
		due.emit(why)
