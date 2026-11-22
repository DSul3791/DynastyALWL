extends SceneTree

# A lost block line loses what it was asked for (cold first join, 22 Nov 2026: the line closed as the game froze, and 505 blocks waited for
# the 30 s ground retry). Pins: the client's line says once that it was lost (not when it is closed on purpose); the stream then puts every
# block a loader still waits for, that went out on the line, back in the urgent queue for the game connection, and only those.
# Local port 8200-8299 only.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_stream_ask_again.gd

const StreamScript := preload("res://src/stream/network_voxel_stream.gd")
const LinkScript := preload("res://src/stream/block_link.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func _load_in_thread(stream, block: Vector3i) -> Array:
	var result: Array = [-1]
	var thread: Thread = Thread.new()
	thread.start(func():
		var buffer: VoxelBuffer = VoxelBuffer.new()
		buffer.create(16, 16, 16)
		result[0] = stream._load_inner(buffer, block, 0))
	return [thread, result]


func _keys(taken: Array) -> Array:
	var keys: PackedInt32Array = taken[0]
	var out: Array = []

	for k in range(0, keys.size(), 4):
		out.append(Vector4i(keys[k], keys[k + 1], keys[k + 2], keys[k + 3]))

	return out


func _initialize() -> void:
	# 1. The stream: a block handed to the line and not answered is asked for again; one still unsent is not doubled.
	var stream = StreamScript.new()
	stream.timeout_msec = 5000
	var a: Array = _load_in_thread(stream, Vector3i(1, 0, 1))

	for n in range(200):
		if stream.pending() > 0:
			break
		OS.delay_msec(5)

	var first: Array = stream.take_requests()   # handed to the line
	check(_keys(first).has(Vector4i(1, 0, 1, 0)) and int(first[1]) == 1, "the block went out as one urgent request")
	var b: Array = _load_in_thread(stream, Vector3i(2, 0, 2))   # a second one, still in the queue (never handed over)

	for n in range(200):
		if stream.pending() > 1:
			break
		OS.delay_msec(5)

	check(stream.ask_again_waiting() == 1, "after the line is lost only the block that went out on it is asked again")
	var again: Array = stream.take_requests()
	var again_keys: Array = _keys(again)
	check(int(again[1]) == 2 and again_keys.slice(0, 2).has(Vector4i(1, 0, 1, 0)) and again_keys.slice(0, 2).has(Vector4i(2, 0, 2, 0)), "both go out once, as urgent, over the game connection (%d urgent)" % int(again[1]))
	check(stream.ask_again_waiting() == 2 and stream.take_requests()[1] == 2, "a second loss asks again for what is still unanswered")
	stream.deliver(PackedInt32Array([1, 0, 1, 0, 2, 0, 2, 0]), [PackedByteArray([1, 2, 3]), PackedByteArray([1, 2, 3])])
	a[0].wait_to_finish()
	b[0].wait_to_finish()
	check(stream.timeouts == 0 and stream.pending() == 0, "the answers reach the waiting loaders, nothing timed out (timeouts %d, pending %d)" % [stream.timeouts, stream.pending()])
	check(stream.ask_again_waiting() == 0, "with nothing waiting, nothing is asked again")

	# 2. The line: lost once when the server closes it, and not when the game closes it on purpose.
	var server: TCPServer = TCPServer.new()
	var port: int = 0

	for _attempt in range(10):
		var p: int = 8200 + randi() % 100

		if server.listen(p) == OK:
			port = p
			break

	check(port > 0, "a local block port listens")

	if port > 0:
		var link = LinkScript.new()
		link.stream = StreamScript.new()
		link.open("127.0.0.1", port, 7)
		var peer: StreamPeerTCP = null
		var since: int = Time.get_ticks_msec()

		while Time.get_ticks_msec() - since < 3000 and not link.ready():
			if peer == null and server.is_connection_available():
				peer = server.take_connection()

			link.pump()
			OS.delay_msec(5)

		check(link.ready() and not link.take_lost_line(), "the line is up and not lost")
		peer.disconnect_from_host()
		since = Time.get_ticks_msec()

		while Time.get_ticks_msec() - since < 3000 and link.ready():
			link.pump()
			OS.delay_msec(5)

		check(not link.ready() and link.take_lost_line(), "the server closing it is a loss")
		check(not link.take_lost_line(), "said once")
		var quiet = LinkScript.new()
		quiet.stream = StreamScript.new()
		quiet.open("127.0.0.1", port, 8)
		var kept: Array = []   # the server's end stays open, so only the game's close() ends this line
		since = Time.get_ticks_msec()

		while Time.get_ticks_msec() - since < 3000 and not quiet.ready():
			if server.is_connection_available():
				kept.append(server.take_connection())

			quiet.pump()
			OS.delay_msec(5)

		quiet.close()
		quiet.pump()
		check(kept.size() == 1 and not quiet.take_lost_line(), "closing it on purpose is not")
		server.stop()

	print("test_stream_ask_again: %d failures" % failures)
	quit(failures)
