extends RefCounted
# Test helper (TEST-013 playtest repair): every swing is done with the tool in hand (protocols 115 and 117), so a test sends the held pack
# slot as a player holding the tool would: slot_of gives player `peer`'s first usable tool of a class on the hotbar (-1: none, nothing in
# hand), at_axe that axe's slot + 1 in x for a tree blow (ACT_HIT) or a trunk, stump or log blow (ACT_PROCESS); 0 is nothing in hand and the
# server refuses the blow.

const Net := preload("res://src/stream/terrain_net.gd")


static func slot_of(items, tool_class: String, peer: int = 1) -> int:
	var inv = items.inventory_of(peer)

	for slot in range(inv.slot_count):
		if inv.on_hotbar(slot) and not items._is_broken(inv, slot) and str(items.table.entry(items.table.id_of(inv.numbers[slot])).get("tool_class", "")) == tool_class:
			return slot

	return -1


static func at_axe(items, peer: int = 1) -> Vector3:
	return Vector3(float(slot_of(items, "axe", peer) + 1), 0.0, 0.0)


# Blueprint sites (Dave 18 Nov 2026: "blue prints should not autocomplete on placement. they should only get supplies added to them when they are
# hit with a hammer"): every hammer or knife placement sets down a site and takes nothing; a hammer swing on the site (ACT_REPAIR_STRUCT, the held
# hammer's slot + 1) pulls what it still needs from the pack, the ground and the builder's own containers within reach. site_of gives the world id of
# the placed site of `kind` (the highest id: the latest; -1 none). hit_site swings the hammer in hand once at it and is true when the piece now stands;
# a player standing farther than SITE_STEP_M (placing reaches 6 m, a swing 3.5 m) walks up to 1.5 m from it for the swing and back after.
const SITE_STEP_M := 3.0


static func site_of(items, kind: String) -> int:
	var best: int = -1

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct") and str(it["struct"]["kind"]) == kind and it["struct"].has("site") and int(id) > best:
			best = int(id)

	return best


static func hit_site(items, id: int, peer: int = 1) -> bool:
	if id < 0 or not items._items.has(id) or not items._items[id].has("struct"):
		return false

	if items._items[id]["struct"].has("site"):
		var was: Vector3 = items._peer_pos.get(peer, Vector3.ZERO)
		var at: Vector3 = items._items[id]["pos"]
		var far: bool = was.distance_to(at) > SITE_STEP_M

		if far:
			var away: Vector3 = Vector3(was.x - at.x, 0.0, was.z - at.z)
			items.report_position(peer, at + (away.normalized() if away.length() > 0.01 else Vector3(1.0, 0.0, 0.0)) * 1.5)

		items.action(peer, Net.ACT_REPAIR_STRUCT, id, slot_of(items, "hammer", peer) + 1, 0, Vector3.ZERO)

		if far:
			items.report_position(peer, was)

	return items._items.has(id) and not items._items[id]["struct"].has("site")
