extends RefCounted
# Test helper (TEST-013 playtest repair): every swing is done with the tool in hand (protocols 115 and 117), so a test sends the held pack
# slot as a player holding the tool would: slot_of gives player `peer`'s first usable tool of a class on the hotbar (-1: none, nothing in
# hand), at_axe that axe's slot + 1 in x for a tree blow (ACT_HIT) or a trunk, stump or log blow (ACT_PROCESS); 0 is nothing in hand and the
# server refuses the blow.


static func slot_of(items, tool_class: String, peer: int = 1) -> int:
	var inv = items.inventory_of(peer)

	for slot in range(inv.slot_count):
		if inv.on_hotbar(slot) and not items._is_broken(inv, slot) and str(items.table.entry(items.table.id_of(inv.numbers[slot])).get("tool_class", "")) == tool_class:
			return slot

	return -1


static func at_axe(items, peer: int = 1) -> Vector3:
	return Vector3(float(slot_of(items, "axe", peer) + 1), 0.0, 0.0)
