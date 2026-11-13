extends RefCounted
# Test helper (protocol 115, TEST-013): wood work is done with the axe in hand, so a tree blow (ACT_HIT) or a trunk, stump or log blow
# (ACT_PROCESS) carries the held pack slot + 1 in at.x. at_axe gives that for player `peer`'s first usable axe on the hotbar, as a
# player holding it would send; with no axe it is 0 (nothing in hand) and the server refuses the blow.


static func at_axe(items, peer: int = 1) -> Vector3:
	var inv = items.inventory_of(peer)

	for slot in range(inv.slot_count):
		if inv.on_hotbar(slot) and not items._is_broken(inv, slot) and str(items.table.entry(items.table.id_of(inv.numbers[slot])).get("tool_class", "")) == "axe":
			return Vector3(float(slot + 1), 0.0, 0.0)

	return Vector3.ZERO
