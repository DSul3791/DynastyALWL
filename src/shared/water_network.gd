extends RefCounted

# Water network (buildables plan section 6; Sonny's water_flow_rules_sonny.md; Steve's design note /mnt/project-files/design/water_network_note.md, all
# 10 Nov 2026): pieces with ports, linked outlet to inlet, solved like a power grid. Accounting only: the live water sim never sees it. Pure: the
# server (6b) turns structures.json "water" blocks into pieces, passes real seconds, sets pump and rain rates, and reads tank litres and plot inflow.
#
# A piece is a Dictionary:
#   role       "source" | "conduit" | "tank" | "consumer"
#   inlet      Vector3 (conduit, tank: at the rim; consumer)      outlet  Vector3 (source: the spout; conduit; tank: at its base)
#   cap_lpm    most it passes, litres a minute (conduit, source)  closed  true for a pipe (or a riser-fed tank), false for open
#   open       false for a shut sluice or tap                     rate_lpm  a source's output now (pump_lpm, windlass_lpm, rain x area)
#   quality    a source's water: "clean" or "river"                push_m  a force pump's push above its spout (the deep-well pump: 10)
#   litres_max a tank's size                                      tap_lpm  most a tank lets into a consumer straight below it (30)
#   room_l     a consumer's litres to full (the server sets it from plot moisture; 0 = full, a closed branch)
#   outlets    more outlets besides `outlet` (a tee's second branch; plumbing PR 2): each feeds like the outlet; the cap and fall use `outlet`
#   catch_m    how far across the ground from its inlet an open piece catches a feeder's water (a trough's length, a flume's mouth; default PORT_JOIN_M)
#   drop_m     how far a feeder's water may fall into an open piece (a spout over a trough; default PORT_JOIN_M)
#   head_m     a tank's water stands this far over its base outlet (a raised cistern's tank on its plinth, its downpipe built in; plumbing PR 3)
#   lift_m     a tank fed at its foot through a closed riser takes water only from a surface at least this far over its inlet (the raised cistern)
#   rain_lpm   rain falling straight into a tank now, L/min (a barrel in the open; the server sets it from the weather; PLUMBING_DESIGN s9)
#   cap_lpm    on a consumer: the most it takes (a drip head's 2 L/min); none takes whatever comes
#   level_port a tank's point at its foot (a barrel's bottom centre) that pipes join to: tanks linked through pipes there level out (level_groups)
#   spout      a closed piece whose outlet always pours into what is under it (a tap: the pipe end it hangs from never caps it)
#   level_h_m  how tall the water in such a tank can stand above its spot (for levelling by water surface, level_litres)
#
# Rules (Sonny's numbers):
#   - Links: an outlet feeds an inlet within PORT_JOIN_M across the ground. Into an open piece only when its inlet is at or below the outlet (+2 cm),
#     so water never climbs between pieces; pipe to pipe joints are sealed and the head rule covers them (up to PORT_JOIN_M of height).
#   - Direction is fixed by the ports; a piece that would close a loop, or make a network of more than MAX_PIECES, joins nothing (check()).
#   - Open channel: no flow if the outlet is above the inlet; full cap from 0.5 % fall, half from 0.1 %, a level run trickles 5 L/min.
#   - Closed pipe: the feeding surface comes down the pass (a force pump's spout + push_m, a hand pump's spout, a tank's base outlet + head_m, fixed so rates
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
# Port look-ups (finding 5 of docs/ai-team/audits/2026-11-18_oversized_reactions_audit.md): every piece is filed by the CELL_M squares its ends
# stand in, so a piece is tried only against the pieces whose ends are near, and a connected run can be found without walking the world.
const CELL_M := 2.0
var _cells: Dictionary = {}               # Vector2i -> ids with an end in that square
var _seq: Dictionary = {}                 # id -> when it joined (links are listed in joining order, as when every piece was tried)
var _next_seq: int = 0
var _reach_m: float = PORT_JOIN_M         # the widest catch_m of any piece that joined: no link reaches farther across the ground


# --- Rates from effort (Sonny section 1 and 2) ---

# A pump's output, litres a minute: power over lift, capped by the pump: 60 x min(cap, P / (9.81 x H)), H = depth to the table + 1 m to the spout.
static func pump_lpm(cap_lps: float, watts: float, depth_m: float) -> float:
	return 60.0 * minf(cap_lps, watts / (9.81 * maxf(depth_m + 1.0, 0.1)))


# A well's windlass: one draw of the held container's `draw_l` (a bucket holds 8) each (4 + 1.5 x depth) seconds, as litres a minute.
static func windlass_lpm(depth_m: float, draw_l: float) -> float:
	return 60.0 * maxf(draw_l, 0.0) / (4.0 + 1.5 * maxf(depth_m, 0.0))


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

	if pieces.has(id):
		_unfile(id)

	pieces[id] = piece
	_down[id] = []
	_up[id] = []
	_file(id)

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

	if bool(piece.get("closed", false)):
		for u in _near(ends(piece), PORT_JOIN_M):   # a pipe end this piece now caps stops spilling into the open pieces under the joint
			if u == id or not _down.has(u):
				continue

			for d in (_down[u] as Array).duplicate():
				if d != id and not _links(pieces[u], pieces[d]):
					_down[u].erase(d)
					_up[d].erase(u)

	return ""


func remove(id: int) -> void:
	for u in _up.get(id, []):
		_down[u].erase(id)

	for d in _down.get(id, []):
		_up[d].erase(id)

	if pieces.has(id):
		_unfile(id)

	for table in [pieces, _down, _up, _in, _out, _quality, _litres, _last_in_s]:
		table.erase(id)


func downstream(id: int) -> Array:
	return _down.get(id, [])


func _links(from_piece: Dictionary, to_piece: Dictionary) -> bool:
	if not from_piece.has("outlet") or not to_piece.has("inlet"):
		return false

	var b: Vector3 = to_piece["inlet"]
	var sealed: bool = bool(from_piece.get("closed", false)) and bool(to_piece.get("closed", false))

	var ends: Array = [from_piece["outlet"]]

	if from_piece.has("outlets"):
		ends.append_array(from_piece["outlets"])

	for a in ends:
		if sealed:
			if Vector2(a.x - b.x, a.z - b.z).length() <= PORT_JOIN_M and absf(a.y - b.y) <= PORT_JOIN_M:
				return true
		elif Vector2(a.x - b.x, a.z - b.z).length() <= maxf(PORT_JOIN_M, float(to_piece.get("catch_m", 0.0))) \
				and b.y <= a.y + OPEN_SLACK_M and a.y - b.y <= maxf(PORT_JOIN_M, float(to_piece.get("drop_m", 0.0))) \
				and not (bool(from_piece.get("closed", false)) and not bool(from_piece.get("spout", false)) and _capped(a, from_piece)):
			return true

	return false


static func _sealed_near(a: Vector3, b: Vector3) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() <= PORT_JOIN_M and absf(a.y - b.y) <= PORT_JOIN_M


# A closed outlet joined to a closed piece's inlet or port (the next pipe, a junction, a Tap) pours nowhere else: it does not spill into a trough,
# barrel or plot under the joint. add() also drops such a spill when the capping piece joins after the pipe, so the build order does not matter.
func _capped(a: Vector3, owner: Dictionary) -> bool:
	for id in _near([a], PORT_JOIN_M):
		var p: Dictionary = pieces[id]

		if is_same(p, owner) or not bool(p.get("closed", false)):
			continue

		for at in ([p["inlet"]] if p.has("inlet") else []) + (p.get("ports", []) as Array):
			if _sealed_near(a, at):
				return true

	return false


# What a piece's water knows (a tank's litres at `now_s`, the water's quality, its still clock), so the server can take a run out and put it back
# turned again (keep before remove(), restore after add()). Solve again after.
func keep(id: int, now_s: float) -> Dictionary:
	var out: Dictionary = {}

	if _litres.has(id):
		out["litres"] = litres(id, now_s)

	if _quality.has(id):
		out["quality"] = _quality[id]

	if _last_in_s.has(id):
		out["last_in_s"] = _last_in_s[id]

	return out


func restore(id: int, kept: Dictionary) -> void:
	if kept.has("litres") and _litres.has(id):
		_litres[id] = clampf(float(kept["litres"]), 0.0, float(pieces[id].get("litres_max", 0.0)))

	if kept.has("quality"):
		_quality[id] = kept["quality"]

	if kept.has("last_in_s"):
		_last_in_s[id] = kept["last_in_s"]


# Every point a piece may join at: its inlet and outlets, and every port of a channel or pipe (whichever way it is turned).
static func ends(piece: Dictionary) -> Array:
	var out: Array = []

	for key in ["inlet", "outlet"]:
		if piece.has(key):
			out.append(piece[key])

	for key in ["outlets", "ports"]:
		if piece.has(key):
			out.append_array(piece[key])

	return out


func _cell(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / CELL_M), floori(at.z / CELL_M))


func _file(id: int) -> void:
	_seq[id] = _next_seq
	_next_seq += 1
	_reach_m = maxf(_reach_m, float(pieces[id].get("catch_m", 0.0)))

	for at in ends(pieces[id]):
		var c: Vector2i = _cell(at)

		if not _cells.has(c):
			_cells[c] = []

		if not (_cells[c] as Array).has(id):
			_cells[c].append(id)


func _unfile(id: int) -> void:
	for at in ends(pieces[id]):
		var c: Vector2i = _cell(at)

		if _cells.has(c):
			_cells[c].erase(id)

			if (_cells[c] as Array).is_empty():
				_cells.erase(c)

	_seq.erase(id)


# The pieces with an end within `reach` metres across the ground of any of `points` (or a little farther: whole squares), in joining order.
func _near(points: Array, reach: float) -> Array:
	var found: Dictionary = {}
	var span: int = ceili(reach / CELL_M)

	for at in points:
		var c: Vector2i = _cell(at)

		for dx in range(-span, span + 1):
			for dz in range(-span, span + 1):
				for id in _cells.get(c + Vector2i(dx, dz), []):
					found[id] = true

	var out: Array = found.keys()

	if out.size() > 1:
		out.sort_custom(func(a, b): return int(_seq[a]) < int(_seq[b]))

	return out


# The connected runs (pieces whose ends come within a link's reach of each other, whichever way they are turned) that have a piece near any of
# `points`; with no points, every run. Each run is a list of ids in joining order. Nothing outside a run can link to it or change how it turns.
func runs(points: Array = []) -> Array:
	var starts: Array = pieces.keys() if points.is_empty() else _near(points, _reach_m)
	var seen: Dictionary = {}
	var out: Array = []

	for start in starts:
		if seen.has(start):
			continue

		var run: Array = []
		var stack: Array = [start]
		seen[start] = true

		while not stack.is_empty():
			var at: int = stack.pop_back()
			run.append(at)

			for other in _near(ends(pieces[at]), _reach_m):
				if not seen.has(other):
					seen[other] = true
					stack.append(other)

		run.sort_custom(func(a, b): return int(_seq[a]) < int(_seq[b]))
		out.append(run)

	return out


# The pieces whose outlet would feed `piece` as it stands (the server turns a channel or pipe so its inlet is the port the water comes from).
func feeders_of(piece: Dictionary) -> Array:
	return _feeders(piece)


func _feeders(piece: Dictionary) -> Array:
	var out: Array = []

	if not piece.has("inlet"):
		return out

	for id in _near([piece["inlet"]], maxf(PORT_JOIN_M, float(piece.get("catch_m", 0.0)))):
		if not is_same(pieces[id], piece) and _links(pieces[id], piece):   # never itself: a short closed piece's outlet can lie within a joint of its own inlet
			out.append(id)

	return out


func _fed(piece: Dictionary) -> Array:
	var out: Array = []

	if not piece.has("outlet"):
		return out

	var points: Array = [piece["outlet"]]

	if piece.has("outlets"):
		points.append_array(piece["outlets"])

	for id in _near(points, _reach_m):
		if not is_same(pieces[id], piece) and _links(piece, pieces[id]):
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
				var rain: float = maxf(float(piece.get("rain_lpm", 0.0)), 0.0)

				if rain > 0.0:
					got += rain
					q = _worse(q, "clean")   # rain is clean water

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

	if room.size() > 1:
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
			return (piece["outlet"] as Vector3).y + float(piece.get("head_m", 0.0)) if piece.has("outlet") else -BIG

	return fed


# Most a piece accepts, L/min: a plot with room and a tank not full take anything; a full plot takes nothing; a full tank, a channel or a pipe takes
# what the pieces below it take (a channel or pipe also its own cap; one with nothing below takes nothing: no water is spilled on the ground).
func _take(id: int, surface: Dictionary, take: Dictionary) -> float:
	var piece: Dictionary = pieces[id]

	match str(piece.get("role", "")):
		"consumer":
			return float(piece.get("cap_lpm", BIG)) if float(piece.get("room_l", 0.0)) > 0.0 else 0.0
		"tank":
			if piece.has("lift_m") and piece.has("inlet") and float(surface[id]) < (piece["inlet"] as Vector3).y + float(piece["lift_m"]):
				return 0.0   # the water reaching its riser cannot climb to the tank

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


# --- Linked barrels (PLUMBING_DESIGN s9, PV-7) ---

# The sets of tanks with a level_port whose ports are joined through closed pipes (any run, any junction), each a list of ids in joining order;
# only sets of two or more. Walks only the pipes round the ports (the cell index), so it costs about the linked pipes, not all plumbing.
func level_groups() -> Array:
	var port_of: Dictionary = {}

	for id in pieces:
		if str(pieces[id].get("role", "")) == "tank" and pieces[id].has("level_port"):
			port_of[id] = pieces[id]["level_port"]

	var seen: Dictionary = {}
	var out: Array = []

	for start in port_of:
		if seen.has(start):
			continue

		seen[start] = true
		var group: Array = [start]
		var points: Array = [port_of[start]]
		var walked: Dictionary = {}

		while not points.is_empty():
			var at: Vector3 = points.pop_back()

			for other in _near([at], PORT_JOIN_M):
				if walked.has(other):
					continue

				var p: Dictionary = pieces[other]

				if port_of.has(other):
					if not seen.has(other) and _sealed_near(at, port_of[other]):
						seen[other] = true
						walked[other] = true
						group.append(other)
						points.append(port_of[other])

					continue

				if str(p.get("role", "")) != "conduit" or not bool(p.get("closed", false)) or not p.has("ports"):
					continue

				var touches: bool = false

				for end in p["ports"]:
					touches = touches or _sealed_near(at, end)

				if touches:
					walked[other] = true
					points.append_array(p["ports"])

		if group.size() > 1:
			group.sort_custom(func(a, b): return int(_seq[a]) < int(_seq[b]))
			out.append(group)

	return out


# How `total` litres stand in linked tanks, like water: one surface height over them all, each tank holding what lies under that surface between
# its foot (base_y) and its top (base_y + height), up to its size (cap). rows: [[base_y, height, cap], ...]. Returns the litres of each, in order.
static func level_litres(rows: Array, total: float) -> Array:
	var room: float = 0.0
	var lo: float = INF
	var hi: float = -INF

	for row in rows:
		room += float(row[2])
		lo = minf(lo, float(row[0]))
		hi = maxf(hi, float(row[0]) + maxf(float(row[1]), 0.01))

	var out: Array = []

	if rows.is_empty():
		return out

	total = clampf(total, 0.0, room)

	for _n in 40:   # bisect the surface: 40 halvings of a few metres is far under a millimetre
		var mid: float = (lo + hi) * 0.5

		if _held_under(rows, mid) < total:
			lo = mid
		else:
			hi = mid

	var sum: float = 0.0

	for row in rows:
		out.append(_tank_under(row, hi))
		sum += float(out[out.size() - 1])

	if sum > 0.0:   # the bisection's last crumb goes back in proportion, so no water is made or lost
		for n in out.size():
			out[n] = float(out[n]) * total / sum

	return out


static func _tank_under(row: Array, surface: float) -> float:
	return float(row[2]) * clampf((surface - float(row[0])) / maxf(float(row[1]), 0.01), 0.0, 1.0)


static func _held_under(rows: Array, surface: float) -> float:
	var sum: float = 0.0

	for row in rows:
		sum += _tank_under(row, surface)

	return sum
