extends Node

# Many load-test bots in one process (server load tests, tools/load_test.sh, 23 Nov 2026). One Godot process per bot (tools/bots.sh)
# costs about 100 MB and a start-up each, too much for 32 players on a 4-CPU machine; here every bot is the same scenes/bot/bot_main.tscn
# under its own holder node with its own SceneMultiplayer, so each is a separate ENet client to the server with RPC paths that match
# the real client's ("Main/TerrainNet" under the holder).
#   --bots=N --first=K (names sK.. so two swarms do not clash) --stagger-ms=MS (between joins), then any bot_main.gd argument
#   (--server, --port, --seconds, --work, --spread, --fight, --build, --dig-every) given to every bot.
# Quits when every bot has finished.

const BotScene := preload("res://scenes/bot/bot_main.tscn")
const SelfTimeoutScript := preload("res://src/shared/self_timeout.gd")

var _count: int = 8
var _first: int = 1
var _stagger_ms: int = 500
var _shared: PackedStringArray = PackedStringArray()
var _started: int = 0
var _left: int = 0
var _next_msec: int = 0


func _ready() -> void:
	SelfTimeoutScript.install(self, OS.get_cmdline_user_args())

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--bots="):
			_count = maxi(int(argument.trim_prefix("--bots=")), 1)
		elif argument.begins_with("--first="):
			_first = int(argument.trim_prefix("--first="))
		elif argument.begins_with("--stagger-ms="):
			_stagger_ms = maxi(int(argument.trim_prefix("--stagger-ms=")), 0)
		elif not argument.begins_with("--name="):
			_shared.append(argument)

	_left = _count


func _process(_delta: float) -> void:
	if _started >= _count or Time.get_ticks_msec() < _next_msec:
		return

	_next_msec = Time.get_ticks_msec() + _stagger_ms
	var holder: Node = Node.new()
	holder.name = "Bot%d" % (_first + _started)
	get_tree().root.add_child.call_deferred(holder)
	_start_bot.call_deferred(holder, "s%d" % (_first + _started))
	_started += 1


func _start_bot(holder: Node, bot_name: String) -> void:
	get_tree().set_multiplayer(SceneMultiplayer.new(), holder.get_path())
	var bot: Node = BotScene.instantiate()
	var args: PackedStringArray = _shared.duplicate()
	args.append("--name=" + bot_name)
	bot.preset_args = args
	bot.in_swarm = true
	bot.finished.connect(func(_lines: PackedStringArray) -> void: _bot_done(holder), CONNECT_ONE_SHOT)
	holder.add_child(bot)


func _bot_done(holder: Node) -> void:
	_left -= 1
	holder.queue_free.call_deferred()

	if _left <= 0:
		print("SWARM: all %d bots finished" % _count)
		get_tree().quit.call_deferred(0)
