extends RefCounted

# What a player would see of the animals over a real connection (Dave 23 Nov 2026, the real server: animals "teleporting and jumping right
# through us"; docs/design/ANIMAL_NETCODE.md), measured from a protocol bot (scenes/bot/bot_main.gd --probe-animals, tools/animal_net_probe.sh).
# Two parts:
# - Relay: a UDP relay inside the bot, between its ENet client and the server, that holds each packet `lag_ms` plus up to `jitter_ms` and
#   drops `loss` of them, both ways, as an internet link would (no root, no tc: Lane B shares its machine with the live server).
# - Probe: every animals batch as it comes, drawn 60 times a second through the client's own MotionBuffer (the new path, or with
#   `old_draw` the old one), counting what the eye sees: frames that move over 0.5 m, the worst frame move, time drawn still while its rows
#   move, batch holes (lost batches), the turn rate and acceleration in the rows, and state changes a minute.

class Relay:
	var listen: PacketPeerUDP = PacketPeerUDP.new()
	var up: PacketPeerUDP = PacketPeerUDP.new()
	var lag_ms: int = 0
	var jitter_ms: int = 0
	var loss: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var client_ip: String = ""
	var client_port: int = 0
	var queue: Array = []   # [due ms, to server?, bytes]
	var dropped: int = 0
	var passed: int = 0

	func start(port: int, server_host: String, server_port: int) -> bool:
		rng.seed = 23
		return listen.bind(port, "127.0.0.1") == OK and up.connect_to_host(server_host, server_port) == OK

	func poll() -> void:
		var now: int = Time.get_ticks_msec()

		while listen.get_available_packet_count() > 0:
			var bytes: PackedByteArray = listen.get_packet()
			client_ip = listen.get_packet_ip()
			client_port = listen.get_packet_port()
			_hold(now, true, bytes)

		while up.get_available_packet_count() > 0:
			_hold(now, false, up.get_packet())

		while not queue.is_empty() and int(queue[0][0]) <= now:
			var p: Array = queue.pop_front()

			if bool(p[1]):
				up.put_packet(p[2])
			elif client_port > 0:
				listen.set_dest_address(client_ip, client_port)
				listen.put_packet(p[2])

	func _hold(now: int, to_server: bool, bytes: PackedByteArray) -> void:
		if loss > 0.0 and rng.randf() < loss:
			dropped += 1
			return

		passed += 1
		var due: int = now + lag_ms + (rng.randi_range(0, jitter_ms) if jitter_ms > 0 else 0)
		var i: int = queue.size()

		while i > 0 and int(queue[i - 1][0]) > due:
			i -= 1

		queue.insert(i, [due, to_server, bytes])


class Probe:
	const MotionBuffer := preload("res://src/client/motion_buffer.gd")
	var old_draw: bool = false
	var clock: Dictionary = MotionBuffer.clock_new()
	var bodies: Dictionary = {}   # id -> {samples, row_ms, sm_p, sm_err, drawn, last_row [pos, heading, row_ms], state, moving_until}
	var gap: float = 0.25
	var rows_at: float = -1.0
	var off: float = INF
	var last_ms: int = -1
	var batches: int = 0
	var holes: int = 0
	var frames: int = 0
	var jumps: int = 0
	var worst: float = 0.0
	var frozen_s: float = 0.0
	var turn_max: float = 0.0
	var turn_snaps: int = 0
	var accel_max: float = 0.0
	var state_changes: int = 0
	var body_seconds: float = 0.0
	var _acc: float = 0.0

	func on_rows(rows: Array, server_ms: int) -> void:
		var now_s: float = float(Time.get_ticks_usec()) / 1.0e6
		batches += 1

		if last_ms >= 0 and float(server_ms - last_ms) / 1000.0 >= float(clock["interval"]) * 1.5:
			holes += maxi(int(round(float(server_ms - last_ms) / 1000.0 / float(clock["interval"]))) - 1, 1)

		if old_draw:
			if rows_at >= 0.0:
				gap = lerpf(gap, clampf(now_s - rows_at, 0.05, 0.5), 0.2)

			rows_at = now_s
			off = MotionBuffer.clock_off(off, now_s, server_ms, last_ms)

		MotionBuffer.clock_note(clock, now_s, server_ms)
		last_ms = server_ms
		var seen: Dictionary = {}

		for row in rows:
			var id: int = int(row[0])
			seen[id] = true

			if not bodies.has(id):
				bodies[id] = {"samples": [], "state": int(row[4]), "drawn": Vector3.INF, "moving_until": 0.0}

			var b: Dictionary = bodies[id]
			var lr: Array = b.get("last_row", [])

			# The rows themselves: how sharply the server turns and speeds up an animal (robot steering shows here, not in the drawing).
			if not lr.is_empty() and int(row[5]) > int(lr[2]):
				var dt: float = float(int(row[5]) - int(lr[2])) / 1000.0
				var v: Vector2 = Vector2((row[2] as Vector3).x - (lr[0] as Vector3).x, (row[2] as Vector3).z - (lr[0] as Vector3).z) / dt
				var turn: float = absf(angle_difference(float(lr[1]), float(row[3]))) / dt
				turn_max = maxf(turn_max, turn)
				turn_snaps += 1 if turn > 6.0 and v.length() > 0.3 else 0   # over a full turn a second while moving: a snap, not a turn
				var was_v: Vector2 = b.get("v", Vector2.ZERO)
				accel_max = maxf(accel_max, (v - was_v).length() / dt)
				b["v"] = v

				if v.length() > 0.3:
					b["moving_until"] = now_s + 0.8

			if int(row[4]) != int(b["state"]):
				state_changes += 1

			b["state"] = int(row[4])
			b["last_row"] = [row[2], float(row[3]), int(row[5])]
			MotionBuffer.push_row(b, row[2], float(row[3]), int(row[5]), off if old_draw else float(clock["off"]), gap if old_draw else INF)

		for id in bodies.keys():
			if not seen.has(id):
				bodies.erase(id)

	# Called every frame; draws 60 times a second.
	func tick(delta: float) -> void:
		_acc += delta

		while _acc >= 1.0 / 60.0:
			_acc -= 1.0 / 60.0
			_draw(1.0 / 60.0)

	func _draw(frame: float) -> void:
		var now_s: float = float(Time.get_ticks_usec()) / 1.0e6
		frames += 1

		for id in bodies:
			var b: Dictionary = bodies[id]

			if (b["samples"] as Array).is_empty():
				continue

			var d: Vector3

			if old_draw:
				d = MotionBuffer.at(b["samples"], now_s - MotionBuffer.delay_s(gap))[0]
			else:
				d = MotionBuffer.smooth(b, MotionBuffer.at(b["samples"], now_s - MotionBuffer.clock_delay(clock))[0], MotionBuffer.speed_of(b["samples"]), frame)

			if b["drawn"] != Vector3.INF:
				var mv: float = Vector2(d.x - b["drawn"].x, d.z - b["drawn"].z).length()

				if mv < MotionBuffer.SNAP_M:
					worst = maxf(worst, mv)
					jumps += 1 if mv > 0.5 else 0

				if mv < 0.002 and now_s < float(b["moving_until"]):
					frozen_s += frame

			body_seconds += frame
			b["drawn"] = d

	func summary() -> String:
		var mins: float = maxf(body_seconds / 60.0, 0.001)
		return "PROBE %s: batches %d, holes %d (%.1f%% lost), animal-minutes %.1f, frames over 0.5 m %.1f a minute, worst frame move %.2f m, drawn still while moving %.1f s a minute, row turn max %.1f rad/s, turn snaps %.1f a minute, row acceleration max %.1f m/s2, state changes %.1f a minute, draw delay %.2f s" % [
			"old draw" if old_draw else "new draw", batches, holes, 100.0 * float(holes) / maxf(float(batches + holes), 1.0), mins, float(jumps) / mins, worst, frozen_s / mins, turn_max, float(turn_snaps) / mins, accel_max, float(state_changes) / mins, MotionBuffer.clock_delay(clock)]
