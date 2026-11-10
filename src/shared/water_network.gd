extends RefCounted

# Water network (buildables plan section 6; Sonny's water_flow_rules_sonny.md; Steve's design note /mnt/project-files/design/water_network_note.md, all
# 10 Nov 2026): pieces with ports, linked outlet to inlet, solved like a power grid. Accounting only: the live water sim never sees it. Pure: the
# server (6b) turns structures.json "water" blocks into pieces, passes real seconds, sets pump and rain rates, and reads tank litres and plot inflow.
#
# A piece is a Dictionary:
#   role       "source" | "conduit" | "tank" | "consumer"
#   inlet      Vector3 (conduit, tank: at the rim; consumer)      outlet  Vector3 (source: the spout; conduit; tank: at its base)
#   cap_lpm    most it passes, litres a minute (conduit, source)  closed  true for a pipe, false for an open channel or trough
#   open       false for a shut sluice or tap                     rate_lpm  a source's output now (pump_lpm, windlass_lpm, rain x area)
#   quality    a source's water: "clean" or "river"                push_m  a force pump's push above its spout (the deep-well pump: 10)
#   litres_max a tank's size                                      tap_lpm  most a tank lets into a consumer straight below it (30)
#   room_l     a consumer's litres to full (the server sets it from plot moisture; 0 = full, a closed branch)
#
# Rules (Sonny's numbers):
#   - Links: an outlet feeds an inlet within PORT_JOIN_M across the ground. Into an open piece only when its inlet is at or below the outlet (+2 cm),
#     so water never climbs between pieces; pipe to pipe joints are sealed and the head rule covers them (up to PORT_JOIN_M of height).
#   - Direction is fixed by the ports; a piece that would close a loop, or make a network of more than MAX_PIECES, joins nothing (check()).
#   - Open channel: no flow if the outlet is above the inlet; full cap from 0.5 % fall, half from 0.1 %, a level run trickles 5 L/min.
#   - Closed pipe: the feeding surface comes down the pass (a force pump's spout + push_m, a hand pump's spout, a tank's base outlet, fixed so rates
#     hold between events); a pipe whose inlet is above it passes nothing (no siphons), and its head (surface - outlet) gives full cap from 1 m, in
#     proportion under that. Each 2 m pipe piece checks its own inlet, so the route is checked every 2 m.
#   - Each piece takes at most what it and the pieces below it can carry, so water is only sent where it can go (a shut piece, a full consumer, a
#     full tank with nowhere to send water and a channel to any of these are closed branches). A tee splits equally among open branches; what one
#     cannot take goes to the others.
#   - A tank fills at inflow - outflow; while it holds water its outlet passes what the pieces below it take; empty, it passes at most its inflow.
#     Full, the extra backs up (not counted). Water that has had no inflow for still_after_s is "still"; any inflow makes it the incoming water's.
#   - Rates hold between events; litres are worked out lazily. next_event_s() is the soonest a tank fills or empties, a consumer fills or a tank's
#     water goes still: solve() again then, or when a rate, a gate or a piece changes.

const PORT_JOIN_M := 0.3
const OPEN_SLACK_M := 0.02
const MAX_PIECES := 256
const FULL_FALL := 0.005
const HALF_FALL := 0.001
const FALL_EPS := 1.0e-6   # 1 cm in 2 m is a 0.5 % fall, whatever the float rounding
const LEVEL_TRICKLE_LPM := 5.0
const FULL_HEAD_M := 1.0
const TAP_LPM := 30.0
const QUALITY_ORDER := ["clean", "river", "still"]
const BIG := 1.0e12

var still_after_s: float = 3.0 * 3600.0   # 3 game days; the server sets it from the game clock's day length
var pieces: Dictionary = {}               # id -> piece (the caller's Dictionary, kept)
var _down: Dictionary = {}                # id -> ids its outlet feeds
var _up: Dictionary = {}                  # id -> ids feeding its inlet
var _in: Dictionary = {}                  # id -> L/min arriving at the last solve
var _out: Dictionary = {}                 # id -> L/min leaving at the last solve
var _quality: Dictionary = {}             # id -> the water's quality at the last solve
var _litres: Dictionary = {}              # tank id -> litres at the last solve
var _last_in_s: Dictionary = {}           # tank id -> real second its last inflow was seen
var _solved_s: float = 0.0


# --- Rates from effort (Sonny section 1 and 2) ---

# A pump's output, litres a minute: power over lift, capped by the pump: 60 x min(cap, P / (9.81 x H)), H = depth to the table + 1 m to the spout.
static func pump_lpm(cap_lps: float, watts: float, depth_m: float) -> float:
	return 60.0 * minf(cap_lps, watts / (9.81 * maxf(depth_m + 1.0, 0.1)))


# A well's windlass: 10 L each (4 + 1.5 x depth) seconds, as litres a minute.
static func windlass_lpm(depth_m: float) -> float:
	return 600.0 / (4.0 + 1.5 * maxf(depth_m, 0.0))


# --- The graph ---

# Whether `piece` may join as it stands: "" (it links), "loop" (it would close a loop: it joins nothing; the ghost says "This would make a loop.")
# or "full" (its network would pass MAX_PIECES).
func check(piece: Dictionary) -> String:
	var ups: Array = _feeders(piece)
	var downs: Array = _fed(piece)

	for d in downs:
		for u in ups:
			if d == u or _reaches(d, u):
				return "loop"

	var seen: Dictionary = {}

	for start in ups + downs:
		_collect(start, seen)

	return "full" if seen.size() + 1 > MAX_PIECES else ""


# Adds a piece and links it, unless check() says no (then it stands alone). Returns check()'s answer. Solve again after.
func add(id: int, piece: Dictionary) -> String:
	var why: String = check(piece)
	pieces[id] = piece
	_down[id] = []
	_up[id] = []

	if str(piece.get("role", "")) == "tank" and not _litres.has(id):
		_litres[id] = 0.0

	if why != "":
		return why

	for u in _feeders(piece):
		_down[u].append(id)
		_up[id].append(u)

	for d in _fed(piece):
		_up[d].append(id)
		_down[id].append(d)

	return ""


func remove(id: int) -> void:
	for u in _up.get(id, []):
		_down[u].erase(id)

	for d in _down.get(id, []):
		_up[d].erase(id)

	for table in [pieces, _down, _up, _in, _out, _quality, _litres, _last_in_s]:
		table.erase(id)


func downstream(id: int) -> Array:
	return _down.get(id, [])


func _links(from_piece: Dictionary, to_piece: Dictionary) -> bool:
	if not from_piece.has("outlet") or not to_piece.has("inlet"):
		return false

	var a: Vector3 = from_piece["outlet"]
	var b: Vector3 = to_piece["inlet"]

	if Vector2(a.x - b.x, a.z - b.z).length() > PORT_JOIN_M or absf(a.y - b.y) > PORT_JOIN_M:
		return false

	var sealed: bool = bool(from_piece.get("closed", false)) and bool(to_piece.get("closed", false))
	return sealed or b.y <= a.y + OPEN_SLACK_M


func _feeders(piece: Dictionary) -> Array:
	var out: Array = []

	for id in pieces:
		if _links(pieces[id], piece):
			out.append(id)

	return out


func _fed(piece: Dictionary) -> Array:
	var out: Array = []

	for id in pieces:
		if _links(piece, pieces[id]):
			out.append(id)

	return out


func _reaches(from_id: int, to_id: int) -> bool:
	var stack: Array = [from_id]
	var seen: Dictionary = {}

	while not stack.is_empty():
		var at: int = stack.pop_back()

		if at == to_id:
			return true

		if seen.has(at):
			continue

		seen[at] = true
		stack.append_array(_down.get(at, []))

	return false


func _collect(start: int, seen: Dictionary) -> void:
	var stack: Array = [start]

	while not stack.is_empty():
		var at: int = stack.pop_back()

		if seen.has(at):
			continue

		seen[at] = true
		stack.append_array(_down.get(at, []))
		stack.append_array(_up.get(at, []))


# --- Solving ---

# Brings the tanks to `now_s`, then works every rate out again: surfaces down from the sources, what each piece can take up from the plots and tanks
# (so water is only sent where it can go: a channel to a full plot carries nothing and a cistern does not drain into it), then the flows down.
func solve(now_s: float) -> void:
	for id in _litres:
		_litres[id] = litres(id, now_s)

		if float(_in.get(id, 0.0)) > 0.0 or not _last_in_s.has(id):
			_last_in_s[id] = now_s   # inflow went on until now, or the first solve to see this tank starts its clock

	_solved_s = now_s
	var order: Array = _order()
	var surface: Dictionary = {}    # id -> the water surface feeding it (closed pipes)
	var arriving: Dictionary = {}
	var incoming: Dictionary = {}   # id -> worst quality arriving

	for id in order:
		surface[id] = -BIG
		arriving[id] = 0.0
		incoming[id] = ""

	for id in order:
		var feed_y: float = _feed_y(id, float(surface[id]))

		for d in _down[id]:
			surface[d] = maxf(float(surface[d]), feed_y)

	var take: Dictionary = {}       # id -> most it accepts, L/min, given what is below it

	for i in range(order.size() - 1, -1, -1):
		take[order[i]] = _take(order[i], surface, take)

	for id in order:
		var piece: Dictionary = pieces[id]
		var got: float = float(arriving[id])
		var out: float = got
		var q: String = str(incoming[id])

		match str(piece.get("role", "")):
			"source":
				out = maxf(minf(float(piece.get("rate_lpm", 0.0)), float(piece.get("cap_lpm", BIG))), 0.0)
				q = str(piece.get("quality", "clean"))
			"tank":
				var held: float = float(_litres.get(id, 0.0))
				out = BIG if held > 0.0 else got   # holding water, it passes what the pieces below take; empty, at most its inflow

				if got > 0.0:
					_last_in_s[id] = now_s
				elif held > 0.0:
					q = str(_quality.get(id, "clean"))

					if now_s - float(_last_in_s.get(id, now_s)) >= still_after_s:
						q = "still"
			"consumer":
				out = 0.0

		_in[id] = got
		_quality[id] = q if q != "" else "clean"
		_out[id] = _share(id, out, take, arriving, incoming)


# Sends up to `amount` from `id` down its links, equal shares where they fit; a branch that takes less than its share passes the rest to the others.
# Each branch takes at most what is left of its own take (two feeders into one piece share it). Returns what was sent.
func _share(id: int, amount: float, take: Dictionary, arriving: Dictionary, incoming: Dictionary) -> float:
	var room: Array = []

	for d in _down[id]:
		var r: float = minf(_limit(id, d), float(take[d]) - float(arriving[d]))

		if r > 0.0:
			room.append([r, d])

	room.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var left: float = amount
	var n: int = room.size()

	for r in room:
		var give: float = minf(float(r[0]), left / float(n))
		n -= 1

		if give <= 0.0:
			continue

		left -= give
		arriving[r[1]] = float(arriving[r[1]]) + give
		incoming[r[1]] = _worse(str(incoming[r[1]]), _quality[id])

	return amount - left


# The surface a piece passes to closed pipes below it: a source's spout (+ a force pump's push), a tank's base outlet (fixed, so rates hold between
# events), else the surface feeding it.
func _feed_y(id: int, fed: float) -> float:
	var piece: Dictionary = pieces[id]

	match str(piece.get("role", "")):
		"source":
			return (piece["outlet"] as Vector3).y + float(piece.get("push_m", 0.0))
		"tank":
			return (piece["outlet"] as Vector3).y if piece.has("outlet") else -BIG

	return fed


# Most a piece accepts, L/min: a plot with room and a tank not full take anything; a full plot takes nothing; a full tank, a channel or a pipe takes
# what the pieces below it take (a channel or pipe also its own cap; one with nothing below takes nothing: no water is spilled on the ground).
func _take(id: int, surface: Dictionary, take: Dictionary) -> float:
	var piece: Dictionary = pieces[id]

	match str(piece.get("role", "")):
		"consumer":
			return BIG if float(piece.get("room_l", 0.0)) > 0.0 else 0.0
		"tank":
			if float(_litres.get(id, 0.0)) < float(piece.get("litres_max", 0.0)) - 0.001:
				return BIG
		"conduit":
			var cap: float = _conduit_cap(piece, float(surface[id]))

			if cap <= 0.0:
				return 0.0

			return minf(cap, _below(id, take))
		"source":
			return 0.0

	return _below(id, take)


func _below(id: int, take: Dictionary) -> float:
	var sum: float = 0.0

	for d in _down[id]:
		sum += minf(_limit(id, d), float(take[d]))

	return sum


# A tank straight over a plot or another tank lets out at most its tap_lpm.
func _limit(from_id: int, d: int) -> float:
	if str(pieces[from_id].get("role", "")) == "tank" and str(pieces[d].get("role", "")) != "conduit":
		return float(pieces[from_id].get("tap_lpm", TAP_LPM))

	return BIG


func _conduit_cap(piece: Dictionary, feed_y: float) -> float:
	if not bool(piece.get("open", true)) or not piece.has("inlet") or not piece.has("outlet"):
		return 0.0

	var cap: float = float(piece.get("cap_lpm", 0.0))
	var inlet: Vector3 = piece["inlet"]
	var outlet: Vector3 = piece["outlet"]

	if bool(piece.get("closed", false)):
		if inlet.y > feed_y:
			return 0.0   # above the feeding surface: a siphon would need priming

		return cap * clampf((feed_y - outlet.y) / FULL_HEAD_M, 0.0, 1.0)

	var length: float = maxf(Vector2(inlet.x - outlet.x, inlet.z - outlet.z).length(), 0.1)
	var fall: float = (inlet.y - outlet.y) / length

	if fall < -0.0001:
		return 0.0

	if fall >= FULL_FALL - FALL_EPS:
		return cap

	if fall >= HALF_FALL - FALL_EPS:
		return cap * 0.5

	return minf(cap, LEVEL_TRICKLE_LPM)


func _worse(a: String, b: String) -> String:
	if a == "":
		return b

	return a if QUALITY_ORDER.find(a) >= QUALITY_ORDER.find(b) else b


func _order() -> Array:
	var left: Dictionary = {}
	var ready: Array = []
	var out: Array = []

	for id in pieces:
		left[id] = (_up[id] as Array).size()

		if int(left[id]) == 0:
			ready.append(id)

	while not ready.is_empty():
		var id: int = ready.pop_back()
		out.append(id)

		for d in _down[id]:
			left[d] = int(left[d]) - 1

			if int(left[d]) == 0:
				ready.append(d)

	return out


# --- Reading ---

func inflow_lpm(id: int) -> float:
	return float(_in.get(id, 0.0))


func outflow_lpm(id: int) -> float:
	return float(_out.get(id, 0.0))


func quality(id: int) -> String:
	return str(_quality.get(id, "clean"))


# A tank's litres at `now_s`: the last solve's litres plus its net rate since, kept between empty and full.
func litres(id: int, now_s: float) -> float:
	if not _litres.has(id):
		return 0.0

	var net: float = float(_in.get(id, 0.0)) - float(_out.get(id, 0.0))
	return clampf(float(_litres[id]) + net * maxf(now_s - _solved_s, 0.0) / 60.0, 0.0, float(pieces[id].get("litres_max", 0.0)))


# The soonest real second something changes by itself: a tank fills or empties, a consumer fills (its room_l at its inflow), a tank's water goes
# still. INF when nothing will.
func next_event_s() -> float:
	var soonest: float = INF

	for id in pieces:
		var piece: Dictionary = pieces[id]
		var role: String = str(piece.get("role", ""))

		if role == "tank":
			var net: float = float(_in.get(id, 0.0)) - float(_out.get(id, 0.0))
			var held: float = float(_litres.get(id, 0.0))
			var top: float = float(piece.get("litres_max", 0.0))

			if net > 0.0 and held < top:
				soonest = minf(soonest, _solved_s + (top - held) / net * 60.0)
			elif net < 0.0 and held > 0.0:
				soonest = minf(soonest, _solved_s + held / -net * 60.0)

			if float(_in.get(id, 0.0)) <= 0.0 and held > 0.0 and quality(id) != "still":
				soonest = minf(soonest, float(_last_in_s.get(id, _solved_s)) + still_after_s)
		elif role == "consumer" and float(_in.get(id, 0.0)) > 0.0:
			soonest = minf(soonest, _solved_s + float(piece.get("room_l", 0.0)) / float(_in[id]) * 60.0)

	return soonest


# Only tank litres are saved (the graph comes back from the placed pieces): id -> litres now.
func save_litres(now_s: float) -> Dictionary:
	var out: Dictionary = {}

	for id in _litres:
		out[id] = litres(id, now_s)

	return out


func set_litres(id: int, value: float) -> void:
	if pieces.has(id):
		_litres[id] = clampf(value, 0.0, float(pieces[id].get("litres_max", 0.0)))
