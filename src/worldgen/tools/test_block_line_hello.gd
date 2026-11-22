extends SceneTree

# The block line's hello wait (block_link_server.gd hello_wait_msec, 22 Nov 2026): on a cold first join the game sends its hello only
# after a 5-6 s freeze at the welcome, and the old 5 s wait closed every such line before it served the join. Pins, on local lines:
#   - a hello that comes after a pause shorter than the wait opens the line;
#   - one that comes after the wait is refused (the line was closed);
#   - past pending_max connections waiting for a hello, the oldest are closed.
# Local ports 8300-8399 only.
#   godot --headless --path . --script res://src/worldgen/tools/test_block_line_hello.gd

const BlockLinkServer := preload("res://src/stream/block_link_server.gd")

var failures: int = 0
var link


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _connect(port: int) -> StreamPeerTCP:
	var tcp: StreamPeerTCP = StreamPeerTCP.new()
	tcp.connect_to_host("127.0.0.1", port)
	var since: int = Time.get_ticks_msec()

	while Time.get_ticks_msec() - since < 3000:
		tcp.poll()

		if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break

		OS.delay_msec(5)

	return tcp


func _hello(tcp: StreamPeerTCP, peer_id: int) -> void:
	var hello: PackedByteArray = PackedByteArray()
	hello.resize(12)
	hello.encode_u32(0, 8)
	hello.encode_u32(4, BlockLinkServer.KIND_HELLO)
	hello.encode_s32(8, peer_id)
	tcp.put_data(hello)


func _has_line(peer_id: int) -> bool:
	link._mutex.lock()
	var yes: bool = link._lines.has(peer_id)
	link._mutex.unlock()
	return yes


func _wait_line(peer_id: int, msec: int) -> bool:
	var since: int = Time.get_ticks_msec()

	while Time.get_ticks_msec() - since < msec:
		if _has_line(peer_id):
			return true

		OS.delay_msec(5)

	return _has_line(peer_id)


# Whether the server closed this connection within `msec` (the game's end sees it go).
func _closed_within(tcp: StreamPeerTCP, msec: int) -> bool:
	var since: int = Time.get_ticks_msec()

	while Time.get_ticks_msec() - since < msec:
		tcp.poll()

		if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return true

		OS.delay_msec(10)

	return false


func _initialize() -> void:
	link = BlockLinkServer.new()
	link.is_peer = func(peer: int) -> bool: return peer >= 1 and peer <= 2
	link.on_request = func(_peer: int, _keys: PackedInt32Array, _urgent: int) -> void: pass
	link.hello_wait_msec = 2000
	link.pending_max = 4
	var port: int = 0

	for _attempt in range(10):
		var p: int = 8300 + randi() % 100

		if link.start(p) == p:
			port = p
			break

	check(port > 0, "a local block line listens")

	if port == 0:
		quit(1)
		return

	# 1. A hello after a 1.2 s pause (a frozen game's first frame), under the 2 s wait: the line opens.
	var late: StreamPeerTCP = _connect(port)
	OS.delay_msec(1200)
	_hello(late, 1)
	check(_wait_line(1, 2000), "a hello after a pause shorter than the wait opens the line")

	# 2. A hello after 3 s, past the wait: the server closed the connection first and no line opens.
	var too_late: StreamPeerTCP = _connect(port)
	OS.delay_msec(3000)
	_hello(too_late, 2)
	check(not _wait_line(2, 1000), "a hello after the wait is refused")
	check(_closed_within(too_late, 2000), "and that connection is closed")

	# 3. Six connections that never say hello, with room for four: the two oldest are closed at once, the newest four wait.
	link.hello_wait_msec = 20000   # room for a slow lane: only the cap closes connections in this part
	var quiet: Array = []

	for _n in range(6):
		quiet.append(_connect(port))
		OS.delay_msec(50)

	OS.delay_msec(300)
	check(_closed_within(quiet[0], 1000) and _closed_within(quiet[1], 1000), "past pending_max the oldest waiting connections are closed")
	check(not _closed_within(quiet[5], 500), "the newest still waits for its hello")

	for tcp in quiet:
		tcp.disconnect_from_host()

	late.disconnect_from_host()
	too_late.disconnect_from_host()
	link.stop()
	print("test_block_line_hello: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(1 if failures > 0 else 0)
