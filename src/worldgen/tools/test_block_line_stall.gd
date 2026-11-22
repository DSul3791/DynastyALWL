extends SceneTree

# The direct block line (block_link_server.gd) never lets one player's game hold the block workers that serve every player (22 Nov 2026).
# A game that stops reading its block line (hung, frozen, or a bad client) used to make put_data wait for it with the line's lock held,
# so every worker that took a block for that player waited too, and the other players' blocks stopped. Checked here, on local lines:
#   - sends to a player who reads nothing return at once, and that line is dropped (logged once) when its outbox passes the cap;
#   - two workers serving a stuck player and a reading one: the reading one gets every block, whole and in order;
#   - a line that takes nothing for the stall time is dropped, though its outbox is under the cap;
#   - an honest slow reader, with a pause shorter than the stall time, keeps its line and gets everything.
# Local ports 8100-8199 only.
#   godot --headless --path . --script res://src/worldgen/tools/test_block_line_stall.gd

const BlockLinkServer := preload("res://src/stream/block_link_server.gd")
const BLOCK_BYTES := 64 * 1024

var failures: int = 0
var link
var _jobs: Array = []                  # [peer, n] for the workers, in order
var _jobs_mutex: Mutex = Mutex.new()
var _slowest_send_msec: int = 0
var _stuck_refused: int = 0            # sends to the stuck player that came back false (its line dropped)


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _block(n: int, size: int) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size)
	bytes.fill(n % 251)
	return bytes


# A game's side of a line: connects and says which player it is.
func _open(port: int, peer_id: int) -> StreamPeerTCP:
	var tcp: StreamPeerTCP = StreamPeerTCP.new()
	tcp.connect_to_host("127.0.0.1", port)
	var since: int = Time.get_ticks_msec()

	while Time.get_ticks_msec() - since < 3000:
		tcp.poll()

		if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break

		OS.delay_msec(5)

	var hello: PackedByteArray = PackedByteArray()
	hello.resize(12)
	hello.encode_u32(0, 8)
	hello.encode_u32(4, BlockLinkServer.KIND_HELLO)
	hello.encode_s32(8, peer_id)
	tcp.put_data(hello)
	return tcp


func _has_line(peer_id: int) -> bool:
	link._mutex.lock()
	var yes: bool = link._lines.has(peer_id)
	link._mutex.unlock()
	return yes


func _wait_line(peer_id: int) -> bool:
	var since: int = Time.get_ticks_msec()

	while Time.get_ticks_msec() - since < 3000:
		if _has_line(peer_id):
			return true

		OS.delay_msec(5)

	return false


# Reads whole frames off a game's line: appends [key.x, payload size, payload ok] rows to `got`; returns the bytes left over.
func _read_frames(tcp: StreamPeerTCP, inbox: PackedByteArray, got: Array, max_bytes: int = 1 << 30) -> PackedByteArray:
	tcp.poll()
	var available: int = mini(tcp.get_available_bytes(), max_bytes)

	if available > 0:
		inbox.append_array(tcp.get_data(available)[1])

	var at: int = 0

	while inbox.size() - at >= 4:
		var size: int = inbox.decode_u32(at)

		if inbox.size() - at - 4 < size:
			break

		var n: int = inbox.decode_s32(at + 4)
		var payload: PackedByteArray = inbox.slice(at + 20, at + 4 + size)
		got.append([n, payload.size(), payload.count(n % 251) == payload.size()])
		at += 4 + size

	return inbox.slice(at)


# A block worker: takes the next job and sends it, like terrain_server's builders (a false send means ENet would carry it).
func _worker() -> void:
	while true:
		_jobs_mutex.lock()

		if _jobs.is_empty():
			_jobs_mutex.unlock()
			return

		var job: Array = _jobs.pop_front()
		_jobs_mutex.unlock()
		var size: int = BLOCK_BYTES if int(job[0]) == 1 else 1024
		var started: int = Time.get_ticks_msec()
		var sent: bool = link.send(int(job[0]), Vector4i(int(job[1]), 0, 0, 0), _block(int(job[1]), size))
		_jobs_mutex.lock()
		_slowest_send_msec = maxi(_slowest_send_msec, Time.get_ticks_msec() - started)

		if not sent and int(job[0]) == 1:
			_stuck_refused += 1

		_jobs_mutex.unlock()


func _initialize() -> void:
	link = BlockLinkServer.new()
	link.is_peer = func(peer: int) -> bool: return peer >= 1 and peer <= 4
	link.on_request = func(_peer: int, _keys: PackedInt32Array, _urgent: int) -> void: pass
	var outbox_cap: bool = "outbox_max_bytes" in link   # false on the code before the fix: part 1 then shows the hole, and parts 2 and 3 do not apply

	if outbox_cap:
		link.outbox_max_bytes = 2 * 1024 * 1024
		link.stall_msec = 3000
	var port: int = 0

	for _attempt in range(10):
		var p: int = 8100 + randi() % 100

		if link.start(p) == p:
			port = p
			break

	check(port > 0, "a local block line listens")

	if port == 0:
		quit(1)
		return

	# 1. A stuck player (1, reads nothing) and a reading one (2), served by two workers taking interleaved jobs.
	var stuck: StreamPeerTCP = _open(port, 1)
	var reader: StreamPeerTCP = _open(port, 2)
	check(_wait_line(1) and _wait_line(2), "both players' lines are up")

	for n in range(400):   # 25 MB for the stuck player, far past any socket buffer, and 400 small blocks for the other
		_jobs.append([1, n])
		_jobs.append([2, n])

	var workers: Array = [Thread.new(), Thread.new()]

	for worker in workers:
		worker.start(_worker)

	var got: Array = []
	var inbox: PackedByteArray = PackedByteArray()
	var since: int = Time.get_ticks_msec()

	while Time.get_ticks_msec() - since < 8000 and got.size() < 400:
		inbox = _read_frames(reader, inbox, got)
		OS.delay_msec(2)

	_jobs_mutex.lock()
	var left: int = _jobs.size()
	_jobs_mutex.unlock()
	check(left == 0, "the workers were not held by the player who reads nothing (%d jobs left after 8 s)" % left)
	check(got.size() == 400, "the reading player got every block (%d of 400)" % got.size())
	var seen: Dictionary = {}
	var whole: bool = true

	for row in got:   # two workers: the order between them is free, each block arrives once and whole
		seen[int(row[0])] = true
		whole = whole and int(row[1]) == 1024 and bool(row[2])

	check(whole and seen.size() == got.size(), "each one once and whole")
	check(_slowest_send_msec < 1000, "no send waited for a game (slowest %d ms)" % _slowest_send_msec)
	var dropped: int = int(link.lines_dropped) if outbox_cap else -1
	check(not _has_line(1) and dropped == 1, "the stuck player's line was dropped once, at the outbox cap (dropped %d)" % dropped)
	# (On the old code a send to player 1 here would wait for the held line's lock for ever, so it is only asked of the new code.)
	check(outbox_cap and _stuck_refused > 0 and not link.send(1, Vector4i.ZERO, _block(0, 16)), "and its later blocks go to the game connection (%d refused)" % _stuck_refused)
	check(_has_line(2), "the reading player keeps its line")

	# Unblocks a worker still inside put_data (the old code), so the test always ends.
	stuck.disconnect_from_host()

	for worker in workers:
		worker.wait_to_finish()

	if not outbox_cap:
		reader.disconnect_from_host()
		link.stop()
		print("test_block_line_stall: %d failures (code before the outbox cap)" % maxi(failures, 1))
		quit(1)
		return

	# 2. A line that takes nothing for the stall time is dropped, though its outbox stays under the cap.
	var quiet: StreamPeerTCP = _open(port, 3)
	check(_wait_line(3), "a third player's line is up")
	var n3: int = 0
	var waiting: int = 0
	since = Time.get_ticks_msec()

	while Time.get_ticks_msec() - since < 5000 and waiting == 0 and n3 < 300:   # fill the socket until the outbox holds something
		link.send(3, Vector4i(n3, 0, 0, 0), _block(n3, BLOCK_BYTES))
		n3 += 1
		link._mutex.lock()
		var line: Dictionary = link._lines.get(3, {})
		link._mutex.unlock()

		if not line.is_empty():
			line["mutex"].lock()
			waiting = link._waiting(line)
			line["mutex"].unlock()

	check(waiting > 0 and waiting <= link.outbox_max_bytes and _has_line(3), "its outbox holds %d bytes, under the cap" % waiting)
	since = Time.get_ticks_msec()

	while Time.get_ticks_msec() - since < link.stall_msec + 5000 and _has_line(3):
		OS.delay_msec(50)

	check(not _has_line(3) and link.lines_dropped == 2, "and the line is dropped after %d s with nothing taken (dropped %d)" % [link.stall_msec / 1000, link.lines_dropped])
	quiet.disconnect_from_host()

	# 3. An honest slow reader keeps its line: it reads 64 KB every 50 ms, and once pauses 2 s (under the 3 s stall time).
	var slow: StreamPeerTCP = _open(port, 4)
	check(_wait_line(4), "a slow player's line is up")
	var slow_got: Array = []
	var slow_inbox: PackedByteArray = PackedByteArray()
	var sent4: int = 0
	var paused: bool = false
	since = Time.get_ticks_msec()

	while Time.get_ticks_msec() - since < 20000 and slow_got.size() < 120:
		if sent4 < 120:
			link.send(4, Vector4i(sent4, 0, 0, 0), _block(sent4, 16 * 1024))
			sent4 += 1

		if not paused and slow_got.size() >= 40:
			paused = true
			OS.delay_msec(2000)

		slow_inbox = _read_frames(slow, slow_inbox, slow_got, 64 * 1024)
		OS.delay_msec(50)

	var slow_ok: bool = slow_got.size() == 120

	for i in range(slow_got.size()):
		slow_ok = slow_ok and int(slow_got[i][0]) == i and bool(slow_got[i][2])

	check(slow_ok and _has_line(4) and link.lines_dropped == 2, "the slow reader got all 120 blocks in order and kept its line (%d)" % slow_got.size())
	slow.disconnect_from_host()
	reader.disconnect_from_host()
	link.stop()
	print("test_block_line_stall: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(1 if failures > 0 else 0)
