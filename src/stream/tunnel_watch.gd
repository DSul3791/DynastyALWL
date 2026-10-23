extends RefCounted

# The server's tunnel watch (tech/EXCAVATION_BRACING_GROUND_DESIGN.md sections 2 to 4): finds the dug spaces that need bracing,
# runs their grace timers, tells players near them about the shaking, and works out the collapse. Switched OFF by default
# (data/tunnels.json "enabled": false) until the bracing items exist: with it off nothing here runs.
#
# mark_dirty(blocks) after an edit; process_dirty(now_msec) measures the dirty blocks (tunnel_stability.gd) on a worker thread;
# tick(now_msec, peers) runs on the main thread and returns what to do: quake messages to send and collapses to apply.
#
# Grace: base 30 real minutes x (free span / span)^2, clamped to 225 s .. 60 min (the shaking part is the last 40 percent, so even the
# shortest window warns for 90 s). f = share of the window used: below 0.6 quiet, 0.6 to 0.8 creak (stage 2), 0.8 to 0.95 shake
# (stage 3), 0.95 to 1 throes (stage 4), at 1 collapse. A spot whose support strength x condition covers its need pauses its timer.
# A new support near a spot still short restarts the full window (support_changed).

const Stability := preload("res://src/stream/tunnel_stability.gd")
const GroundOps := preload("res://src/stream/ground_ops.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

const CELL_M := 2.0
const QUAKE_EVERY_MSEC := 500
const QUAKE_RANGE_M := 40.0
const MAX_FILLS_PER_COLLAPSE := 60
const FILL_RADIUS_M := 1.5

var enabled: bool = false
var collapse_enabled: bool = false           # step 3 (collapse and deaths) needs Steve's second approval and a Dave test card: off even when the watch is on
var base_grace_s: float = 1800.0
var min_grace_s: float = 225.0
var max_grace_s: float = 3600.0
var rubble_material: int = 1
# Dave 2026-10-22 (collapse-plan-1): a dug space wider than about 2 m starts a timer; about 10 minutes of quiet, then rumbling for the
# cave-in duration (a setting, 2 to 20 minutes, 20 by default) to dig out and brace. With quiet_s set the window is that fixed total
# (no width scaling) and the stages are measured from the end of the quiet part; unset (0) keeps the older width-scaled window.
var quiet_s: float = 0.0
var cave_in_s: float = 1200.0
const CAVE_IN_MIN_S := 120.0
const CAVE_IN_MAX_S := 1200.0
var load_block: Callable                     # (Vector3i block) -> VoxelBuffer of the block with every edit applied, or null
var load_natural: Callable                   # (Vector3i block) -> VoxelBuffer of the block as generated, no edits: collapse is for MAN-MADE spaces only (Dave 2026-10-23)
var surface_h: Callable                      # (x, z) -> ground surface height
var support_strength: Callable               # (Vector3) -> support strength x condition 0..1 at a point (items; none until they exist)

var _mutex: Mutex = Mutex.new()
var _dirty: Dictionary = {}                  # Vector3i block -> true
var _cells: Dictionary = {}                  # Vector3i cell -> {pos, need, span, free, opened, grace_ms, seen}
var _block_cells: Dictionary = {}            # Vector3i block -> Array of cell keys it holds
var _next_quake_msec: int = 0
var _sem: Semaphore = Semaphore.new()
var _thread: Thread
var _stopping: bool = false
var cells_measured: int = 0
var collapses: int = 0


# data: the parsed data/tunnels.json ({} when missing).
func configure(data: Dictionary) -> void:
	enabled = bool(data.get("enabled", false))
	collapse_enabled = bool(data.get("collapse", false))
	base_grace_s = float(data.get("base_grace_s", base_grace_s))
	min_grace_s = float(data.get("min_grace_s", min_grace_s))
	max_grace_s = float(data.get("max_grace_s", max_grace_s))
	rubble_material = int(data.get("rubble_material", rubble_material))
	quiet_s = maxf(float(data.get("quiet_s", quiet_s)), 0.0)
	cave_in_s = clampf(float(data.get("cave_in_s", cave_in_s)), CAVE_IN_MIN_S, CAVE_IN_MAX_S)


func start() -> void:
	if enabled and _thread == null:
		_thread = Thread.new()
		_thread.start(_loop)


func stop() -> void:
	_mutex.lock()
	_stopping = true
	_mutex.unlock()
	_sem.post()

	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


# After a dig or fill: the blocks the sphere touches are measured again.
func mark_edit(centre: Vector3, radius: float) -> void:
	if enabled:
		mark_dirty(GroundOps.blocks_of(centre, radius))


func mark_dirty(blocks: Array) -> void:
	if not enabled:
		return

	_mutex.lock()

	for block in blocks:
		_dirty[block] = true

	_mutex.unlock()
	_sem.post()


# A support was placed, removed or worn at `at`: spots within its reach (12 m) that are still short start a full window again.
func support_changed(at: Vector3, now_msec: int) -> void:
	_mutex.lock()

	for key in _cells:
		var cell: Dictionary = _cells[key]

		if (cell["pos"] as Vector3).distance_to(at) <= 12.0 and _strength(cell["pos"]) < float(cell["need"]):
			cell["opened"] = now_msec

	_mutex.unlock()


func working_count() -> int:
	_mutex.lock()
	var n: int = _cells.size()
	_mutex.unlock()
	return n


func _loop() -> void:
	while true:
		_sem.wait()
		_mutex.lock()
		var stopping: bool = _stopping
		_mutex.unlock()

		if stopping:
			return

		process_dirty(Time.get_ticks_msec())


# Measures every dirty block (worker thread, or a test). Cells that stopped needing bracing leave; new ones start their window now.
func process_dirty(now_msec: int) -> void:
	while true:
		_mutex.lock()

		if _dirty.is_empty():
			_mutex.unlock()
			return

		var block: Vector3i = _dirty.keys()[0]
		_dirty.erase(block)
		_mutex.unlock()
		var buffer: VoxelBuffer = load_block.call(block) if load_block.is_valid() else null

		if buffer == null:
			continue

		var found: Array = Stability.working(Stability.classify(buffer, Vector3(block * GroundOps.BLOCK_SIZE), surface_h))

		if load_natural.is_valid() and not found.is_empty():
			var natural: VoxelBuffer = load_natural.call(block)
			var origin: Vector3 = Vector3(block * GroundOps.BLOCK_SIZE)
			found = found.filter(func(cell): return natural == null or _dug(buffer, natural, (cell["pos"] as Vector3) - origin))
		_mutex.lock()

		for key in _block_cells.get(block, []):
			_cells.erase(key)

		var keys: Array = []

		for cell in found:
			var key: Vector3i = Vector3i(((cell["pos"] as Vector3) / CELL_M).floor())
			var grace_s: float = quiet_s + cave_in_s if quiet_s > 0.0 else clampf(base_grace_s * pow(float(cell["free"]) / maxf(float(cell["span"]), 0.1), 2.0), min_grace_s, max_grace_s)
			var was: Dictionary = _cells.get(key, {})
			_cells[key] = {"pos": cell["pos"], "need": cell["need"], "span": cell["span"], "opened": int(was.get("opened", now_msec)), "grace_ms": int(grace_s * 1000.0), "last": now_msec}
			keys.append(key)

		_block_cells[block] = keys
		cells_measured += found.size()
		_mutex.unlock()


# The window share f mapped so the quiet part (share q of the window; 0 keeps the old fixed layout) ends at 0.6: stage_of and
# strength_of then work unchanged on it.
# True when part of the cell (a 3 x 3 x 3 look around its centre) is air now but was rock when the ground was generated: someone dug it.
# Natural caves are never man-made, so they never start a window.
static func _dug(now: VoxelBuffer, natural: VoxelBuffer, local: Vector3) -> bool:
	for dy in range(-1, 2):
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var x: int = clampi(floori(local.x) + dx, 0, 15)
				var y: int = clampi(floori(local.y) + dy, 0, 15)
				var z: int = clampi(floori(local.z) + dz, 0, 15)

				if now.get_voxel_f(x, y, z, Layout.CHANNEL_SDF) > 0.0 and natural.get_voxel_f(x, y, z, Layout.CHANNEL_SDF) <= 0.0:
					return true

	return false


# The in-game switch (Esc > Settings, admin): off clears every running window; on starts the thread if it was never started.
func set_enabled(on: bool) -> void:
	_mutex.lock()
	enabled = on
	collapse_enabled = on

	if not on:
		_cells.clear()
		_block_cells.clear()
		_dirty.clear()

	_mutex.unlock()
	start()


func set_cave_in_s(seconds: float) -> void:
	cave_in_s = clampf(seconds, CAVE_IN_MIN_S, CAVE_IN_MAX_S)


static func _stage_share(f: float, q: float) -> float:
	if q <= 0.0:
		return f

	if f < q:
		return f / q * 0.6

	return 0.6 + (f - q) / maxf(1.0 - q, 0.001) * 0.4


static func stage_of(f: float) -> int:
	if f >= 1.0:
		return 5
	if f >= 0.95:
		return 4
	if f >= 0.8:
		return 3
	if f >= 0.6:
		return 2

	return 1


# Shake strength 0..1 for a window share f (stage 2 starts gently, the throes reach the full shake).
static func strength_of(f: float) -> float:
	return clampf((f - 0.6) / 0.4, 0.0, 1.0)


func _strength(at: Vector3) -> float:
	return float(support_strength.call(at)) if support_strength.is_valid() else 0.0


# peers: peer id -> position. Returns {"quake": [[peer, stage, strength_pm, point]], "collapse": [{"fills": [[centre, radius]], "victims": [peer], "cells": n}]}.
func tick(now_msec: int, peers: Dictionary) -> Dictionary:
	var out: Dictionary = {"quake": [], "collapse": []}

	if not enabled:
		return out

	_mutex.lock()
	var failed: Array = []
	var loudest: Dictionary = {}          # peer -> [stage, strength, point]
	var send_quake: bool = now_msec >= _next_quake_msec

	if send_quake:
		_next_quake_msec = now_msec + QUAKE_EVERY_MSEC

	for key in _cells:
		var cell: Dictionary = _cells[key]

		# Covered by supports: the window is paused (the time since the last look is not counted).
		if _strength(cell["pos"]) >= float(cell["need"]):
			cell["opened"] = int(cell["opened"]) + (now_msec - int(cell["last"]))
			cell["last"] = now_msec
			continue

		cell["last"] = now_msec
		var f: float = _stage_share(float(now_msec - int(cell["opened"])) / float(cell["grace_ms"]), quiet_s / maxf(quiet_s + cave_in_s, 1.0) if quiet_s > 0.0 else 0.0)
		var stage: int = stage_of(f)

		if stage == 5 and collapse_enabled:
			failed.append(key)
		elif stage >= 2 and send_quake:
			for peer in peers:
				if (peers[peer] as Vector3).distance_to(cell["pos"]) <= QUAKE_RANGE_M:
					var best: Array = loudest.get(peer, [0, 0.0, Vector3.ZERO])

					if stage > int(best[0]) or (stage == int(best[0]) and strength_of(f) > float(best[1])):
						loudest[peer] = [stage, strength_of(f), cell["pos"]]

	for peer in loudest:
		var info: Array = loudest[peer]
		out["quake"].append([peer, int(info[0]), int(float(info[1]) * 1000.0), info[2]])

	if not failed.is_empty():
		out["collapse"] = _collapse(failed, peers)

	_mutex.unlock()
	return out


# Caller holds the mutex. A cluster is every working cell that touches (within 4 m, chained) a failed cell: neighbours share the
# earliest due time, so the whole space comes down together. Each cluster becomes rubble fills and a victim list.
func _collapse(failed: Array, peers: Dictionary) -> Array:
	var clusters: Array = []
	var left: Array = _cells.keys()

	for seed in failed:
		if not left.has(seed):
			continue

		left.erase(seed)
		var group: Array = [seed]
		var at: int = 0

		while at < group.size():
			for key in left.duplicate():
				if (_cells[key]["pos"] as Vector3).distance_to(_cells[group[at]]["pos"]) <= 4.0:
					group.append(key)
					left.erase(key)

			at += 1

		clusters.append(group)

	var results: Array = []
	var touched: Dictionary = {}

	for group in clusters:
		var fills: Array = []
		var step: int = maxi(1, int(ceil(float(group.size()) / float(MAX_FILLS_PER_COLLAPSE))))
		var victims: Array = []

		for n in range(0, group.size(), step):
			fills.append([(_cells[group[n]]["pos"] as Vector3) + Vector3(0.0, 1.0, 0.0), FILL_RADIUS_M])

		for peer in peers:
			for key in group:
				var d: Vector3 = (peers[peer] as Vector3) - (_cells[key]["pos"] as Vector3)

				if Vector2(d.x, d.z).length() <= 2.2 and absf(d.y) <= 4.0:
					victims.append(peer)
					break

		results.append({"fills": fills, "victims": victims, "cells": group.size()})
		collapses += 1

		for key in group:
			touched[Vector3i(((_cells[key]["pos"] as Vector3) / float(GroundOps.BLOCK_SIZE)).floor())] = true
			_cells.erase(key)

	for block in touched:
		_dirty[block] = true

	_sem.post()
	return results
