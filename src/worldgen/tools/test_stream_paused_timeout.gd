extends SceneTree

# Join hang (2 Nov 2026, rig "1 blocks still arriving" for ever): a block's wait clock restarted on every pause, also after its request had gone out, so a
# player held in the air (pause flipping on and off) never let it time out and the join watchdog saw nothing fail. Pins: a request still in the outbox does
# not time out while paused; a request already handed to the link times out even while paused.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_stream_paused_timeout.gd

const StreamScript := preload("res://src/stream/network_voxel_stream.gd")

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


func _init() -> void:
	# 1. Paused and never sent: the wait holds (the player is flying, nothing was asked for yet).
	var held = StreamScript.new()
	held.timeout_msec = 300
	held.paused = true
	var a: Array = _load_in_thread(held, Vector3i(1, 0, 1))
	OS.delay_msec(900)
	check(held.pending() == 1 and held.timeouts == 0, "paused, request not sent: still waiting after 3 timeouts' worth (pending %d, timeouts %d)" % [held.pending(), held.timeouts])
	held.close()
	a[0].wait_to_finish()

	# 2. Sent, then paused (the join hang): the clock keeps running and the block fails, so the watchdog can retry.
	var sent = StreamScript.new()
	sent.timeout_msec = 300
	var b: Array = _load_in_thread(sent, Vector3i(2, 0, 2))

	for n in range(200):
		if sent.pending() > 0:
			break
		OS.delay_msec(5)

	var taken: Array = sent.take_requests()
	check((taken[0] as PackedInt32Array).size() >= 4, "the request was handed to the link")
	sent.paused = true

	for n in range(40):
		sent.paused = n % 2 == 0      # the pause flips on and off, as it did in the air
		OS.delay_msec(25)

	sent.paused = true

	for n in range(200):   # up to 2 s; a wait that never times out is closed so the test ends with a FAIL instead of hanging
		if sent.timeouts > 0:
			break
		OS.delay_msec(10)

	sent.close()
	b[0].wait_to_finish()
	check(sent.timeouts == 1 and sent.pending() == 0, "sent then paused: the block times out (timeouts %d, pending %d)" % [sent.timeouts, sent.pending()])

	# 3. Not paused: the plain timeout still works.
	var plain = StreamScript.new()
	plain.timeout_msec = 200
	var c: Array = _load_in_thread(plain, Vector3i(3, 0, 3))
	c[0].wait_to_finish()
	check(plain.timeouts == 1, "not paused: a block nobody answers times out (timeouts %d)" % plain.timeouts)

	print("test_stream_paused_timeout: %d failures" % failures)
	quit(failures)
