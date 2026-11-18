extends RefCounted

# Which dig regions' 2 m water (deliver_fine_water, protocol 94) one player is sent: only the regions within reach of them
# (Dave 18 Nov 2026: "water from small digs should be sent to local players"; the follow-up to audit finding 9,
# docs/ai-team/audits/2026-11-18_oversized_reactions_audit.md). The server keeps each region's newest packet, so a player who comes
# within reach of a dug, wet spot gets its water at once instead of waiting for the region to change. The wire is unchanged: `keys`
# still names every region the client should keep, and the client drops its sheets for the rest. Pure, so tested in the cloud
# (test_fine_water_send).


# The world rectangle (x, z) a packet [key, origin of cell (0, 0), w, h, cell_m, raw size, bytes] draws over.
static func rect_of(packet: Array) -> Rect2:
	var cell: float = float(packet[4])
	return Rect2(Vector2(packet[1]) - Vector2(0.5, 0.5) * cell, Vector2(float(packet[2]), float(packet[3])) * cell)


# True when the nearest point of `rect` is within `reach` of `at` across the ground, the world's wrap (`period`) included.
static func near(at: Vector3, rect: Rect2, period: float, reach: float) -> bool:
	var mid: Vector2 = rect.get_center()
	var dx: float = absf(fposmod(mid.x - at.x + period * 0.5, period) - period * 0.5) - rect.size.x * 0.5
	var dz: float = absf(fposmod(mid.y - at.z + period * 0.5, period) - period * 0.5) - rect.size.y * 0.5
	dx = maxf(dx, 0.0)
	dz = maxf(dz, 0.0)
	return dx * dx + dz * dz <= reach * reach


# Keeps the newest packet of each region in `cache` (key -> packet) and forgets regions no longer drawn. `fine` is take_fine()'s
# {"keys", "packets"}. Returns the keys whose picture just changed.
static func remember(cache: Dictionary, fine: Dictionary) -> Dictionary:
	var keys: PackedStringArray = fine["keys"]

	for key in cache.keys():
		if not keys.has(String(key)):
			cache.erase(key)

	var fresh: Dictionary = {}

	for p in fine["packets"]:
		cache[String(p[0])] = p
		fresh[String(p[0])] = true

	return fresh


# One player's message. `keys` is every drawn region; a region with no packet yet (a sleeping one before its first picture) has no known
# place and is always named, which keeps a sheet the client already holds. `told` (key -> true) is what this player has a picture of
# and is updated; `last_keys` is what they were last named. {"send": false} when nothing for them changed.
static func for_peer(at: Vector3, period: float, reach: float, keys: PackedStringArray, cache: Dictionary, fresh: Dictionary,
		told: Dictionary, last_keys: PackedStringArray) -> Dictionary:
	var named: PackedStringArray = PackedStringArray()
	var packets: Array = []

	for key in keys:
		if not cache.has(key):
			named.append(key)
			continue

		if not near(at, rect_of(cache[key]), period, reach):
			told.erase(key)   # dropped by the client; comes again when they are back within reach
			continue

		named.append(key)

		if fresh.has(key) or not told.has(key):
			packets.append(cache[key])
			told[key] = true

	for key in told.keys():
		if not keys.has(String(key)):
			told.erase(key)

	return {"send": named != last_keys or not packets.is_empty(), "keys": named, "packets": packets}
