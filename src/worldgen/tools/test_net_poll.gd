extends SceneTree

# The client's own network poll (net_poll.gd; Lane A 26 Nov 2026: hitches of 69-118 ms sat in Godot's multiplayer poll, unnamed): a mark is
# connected last on every signal of the messages node and moved back behind handlers connected later, a poll's time is split by message,
# and the node takes the poll over from the SceneTree and gives it back when it leaves.
#   godot --headless --path . --script res://src/worldgen/tools/test_net_poll.gd

const NetPollScript := preload("res://src/debug/net_poll.gd")

var failures: int = 0
var order: PackedStringArray = PackedStringArray()


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	# A stand-in for TerrainNet: two signals, one with arguments.
	var source: GDScript = GDScript.new()
	source.source_code = "extends Node\nsignal rows_received(a, b)\nsignal ping_received()\n"
	check(source.reload() == OK, "the stand-in messages script compiles")
	var messages: Node = Node.new()
	messages.set_script(source)
	messages.connect("rows_received", func(_a, _b) -> void: order.append("first handler"))

	var poll = NetPollScript.new(messages)
	poll.listen()
	var rows: Array = messages.get_signal_connection_list("rows_received")
	check(rows.size() == 2 and messages.get_signal_connection_list("ping_received").size() == 1, "one mark on each of the messages' own signals")
	messages.connect("rows_received", func(_a, _b) -> void: order.append("late handler"))
	poll.listen()
	rows = messages.get_signal_connection_list("rows_received")
	check(rows.size() == 3 and Callable(rows[2]["callable"]) == poll._marks["rows_received"], "a handler connected later goes before the mark again")

	# Outside a poll nothing is recorded; inside, each message is marked after its handlers.
	messages.emit_signal("rows_received", 1, 2)
	check(poll._names.is_empty(), "outside a poll nothing is recorded")
	poll._polling = true
	messages.emit_signal("rows_received", 1, 2)
	messages.emit_signal("ping_received")
	poll._polling = false
	check(poll._names == PackedStringArray(["rows_received", "ping_received"]), "inside a poll each message is marked (%s)" % str(poll._names))
	check(order.size() == 4 and order[3] == "late handler", "the handlers run before the mark (%s)" % str(order))

	# A poll from 1000 to 8900 us: rows_received marked at 2000, ping_received at 2500, rows_received again at 7900, poll end 8900.
	var names: PackedStringArray = PackedStringArray(["rows_received", "ping_received", "rows_received"])
	var at: PackedInt64Array = PackedInt64Array([2000, 2500, 7900])
	var spans: Dictionary = NetPollScript.split(names, at, 1000, 8900)
	check(int(spans["rows_received"][0]) == 2 and int(spans["rows_received"][1]) == 6400, "each message runs from the mark before it to its own (%s)" % str(spans["rows_received"]))
	check(int(spans["ping_received"][1]) == 500 and int(spans["after"][1]) == 1000, "ping 500 us, after 1000 us (%s, %s)" % [str(spans["ping_received"]), str(spans["after"])])
	var line: String = NetPollScript.text(spans)
	check(line.begins_with("rows_received x2 6 ms, after 1 ms"), "the line names the longest first with counts (%s)" % line)
	var empty: Dictionary = NetPollScript.split(PackedStringArray(), PackedInt64Array(), 1000, 4000)
	check(empty.size() == 1 and int(empty["after"][1]) == 3000, "a poll with no message is all after")

	# The node takes the poll over and gives it back.
	root.add_child(poll)
	check(not multiplayer_poll, "the SceneTree stops its own poll while the node is in")
	check(poll.process_mode == Node.PROCESS_MODE_ALWAYS, "it polls while the game is paused")
	poll._process(0.016)   # an offline peer: polls without error
	root.remove_child(poll)
	check(multiplayer_poll, "the SceneTree polls again once the node leaves")
	poll.free()
	messages.free()
	print("test_net_poll: %d failures" % failures)
	quit(1 if failures > 0 else 0)
