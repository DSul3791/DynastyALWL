extends RefCounted

# Where a water update changed the levels (protocol 130; audit findings 7 and 12, docs/ai-team/audits/2026-11-18_oversized_reactions_audit.md),
# and which held chunks a client asks again for. Pure, so the server's and the client's halves are tested together in the cloud
# (test_water_reask), where stock Godot cannot load either scene.


# The areas one update names, each its own Rect2 (world x, z): the live window, where it was last time, each dig window now and where they
# were last time. Never empty while the window has an area, so a client holding a chunk under the moving water always asks again.
static func changed_areas(window: Rect2, window_told: Rect2, live: Array, live_told: Array) -> Array:
	var areas: Array = [window]

	if window_told.has_area() and window_told != window:
		areas.append(window_told)

	for r in live + live_told:
		if (r as Rect2).has_area() and not areas.has(r):
			areas.append(r)

	return areas


# The held chunks (Vector2i, chunk_m squares) a client asks again for: those touching any area grown by a chunk; every one when no area is
# known (a plain water_changed, or an empty list).
static func chunks_to_ask(held: Array, areas: Array, chunk_m: float) -> Array:
	var grown: Array = []

	for area in areas:
		grown.append((area as Rect2).grow(chunk_m))

	var out: Array = []

	for chunk in held:
		if grown.is_empty() or touches_any(grown, Rect2(Vector2(chunk) * chunk_m, Vector2(chunk_m, chunk_m))):
			out.append(chunk)

	return out


static func touches_any(areas: Array, chunk: Rect2) -> bool:
	for area in areas:
		if (area as Rect2).intersects(chunk):
			return true

	return false
