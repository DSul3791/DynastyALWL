extends RefCounted

# Unreliable rows sent in parts that each fit one network packet (protocol 171, 26 Nov 2026). ENet splits anything over its MTU
# (1392 bytes) into fragments, and an unreliable packet missing any fragment is lost whole, so a batch over the MTU is lost about twice
# as often as one that fits. The lane servers logged "Sending 1393-1509 bytes unreliably which is above the MTU" for the animal rows
# (terrain_server _send_npcs), each one a batch more likely to be lost, and a lost batch is an animal that jumps.
#
# The server: split(rows) gives the rows as one part when they fit BUDGET, else as consecutive parts that each do, in their order
# (nearest first stays nearest first). Every part of a batch is sent with the same server ms and its part number and the part count.
# The client: note(batch, server_ms, part, parts, rows) per part keeps which parts of the newest batch came. Each part's rows are drawn
# as they come; a body missing from the rows is taken away only once every part of its batch came ("done"), so one lost part never
# makes animals vanish, it only leaves them for the next batch, a quarter of a second later.

const BUDGET := 1200          # bytes of rows in one part: under ENet's 1392 with the RPC's own bytes (method, server ms, part, parts) on top
const RESTART_MS := 10000     # a batch this far older than the newest is a restarted server's clock, not a late part
const ROW_MAX := 132          # bytes of the biggest animal row today (six fields, a dog foe, a plan, a health share): up to 9 always fit


static func split(rows: Array, budget: int = BUDGET) -> Array:
	if rows.size() * ROW_MAX + 8 <= budget or var_to_bytes(rows).size() <= budget:
		return [rows]   # nearly always: no size check for a few rows, one for the whole batch

	var parts: Array = []
	var part: Array = []
	var size: int = 8   # the array's own header: type and count

	for row in rows:
		var n: int = var_to_bytes(row).size()

		if not part.is_empty() and size + n > budget:
			parts.append(part)
			part = []
			size = 8

		part.append(row)
		size += n

	if not part.is_empty():
		parts.append(part)

	return parts


# batch is the client's own Dictionary, {} at first. Returns {"new": the first part of a newer batch to arrive, "stale": a part of an
# older batch (skip it: newer rows are drawn), "done": every part of this batch has come; batch["seen"] then holds every id in it}.
static func note(batch: Dictionary, server_ms: int, part: int, parts: int, rows: Array) -> Dictionary:
	var last: int = int(batch.get("ms", -1))
	var fresh: bool = last < 0 or server_ms > last or server_ms < last - RESTART_MS

	if not fresh and server_ms < last:
		return {"new": false, "stale": true, "done": false}

	if fresh:
		batch["ms"] = server_ms
		batch["got"] = {}
		batch["seen"] = {}

	batch["got"][part] = true

	for row in rows:
		batch["seen"][int(row[0])] = true

	return {"new": fresh, "stale": false, "done": (batch["got"] as Dictionary).size() >= maxi(parts, 1)}
