extends RefCounted

# Resource bins (master s2.5, CATALOG_IMPLEMENTATION_PLAN R6, repair plan "dedicated resource-bin family"; GOALS-REPAIR WP-METAL R6): a
# structures.json row with "bin": {"units": N} holds up to N units of ONE item kind. An empty bin is unassigned; the first item put in
# assigns it, every later put must be that exact item, and when the last unit is taken out it is unassigned again. The assignment is never
# stored: it is the kind the bin holds (so a save keeps it while occupied and clears it when empty by itself). Capacity is units, never
# weight or slots; the bin's slots are layout only (PROVISIONAL, GOALS-REPAIR A-32). A bin saved before R6 with more than one kind
# (the old mixed Open storage bin) keeps everything and can be emptied, but takes nothing in until it holds one kind.
# Used by server_items.gd (_box_put, _box_room, the fill on the world row) and the client look (surface_height).


static func is_bin(def: Dictionary) -> bool:
	return typeof(def.get("bin", null)) == TYPE_DICTIONARY


static func capacity(def: Dictionary) -> int:
	return int(def.get("bin", {}).get("units", 0)) if is_bin(def) else 0


# The item number the bin holds: 0 when empty (unassigned), -1 when it holds more than one kind (an old mixed bin).
static func assigned(box) -> int:
	var kind: int = 0

	for i in box.slot_count:
		if box.numbers[i] == 0:
			continue

		if kind == 0:
			kind = box.numbers[i]
		elif box.numbers[i] != kind:
			return -1

	return kind


static func units(box) -> int:
	var total: int = 0

	for i in box.slot_count:
		if box.numbers[i] != 0:
			total += box.counts[i]

	return total


# How many of `amount` of item `number` the bin takes now (0: the wrong kind, a mixed bin, or full).
static func room(def: Dictionary, box, number: int, amount: int) -> int:
	var held: int = assigned(box)

	if held == -1 or (held != 0 and held != number):
		return 0

	return clampi(capacity(def) - units(box), 0, amount)


# Why a put was refused (room gave 0), for the player.
static func refusal(def: Dictionary, box, number: int, table) -> String:
	var held: int = assigned(box)

	if held == -1:
		return "This bin holds more than one thing from before. Empty it, and it takes one kind again."

	if held != 0 and held != number:
		return "This bin holds only %s. Empty it to store something else." % table.in_sentence(table.name_of(held))

	return "The bin is full (%d)." % capacity(def)


# 0 empty, 1 to 4 quarters full, by units against capacity (the world row's "fill", as the station stores').
static func fill_quarters(def: Dictionary, box) -> int:
	var used: int = units(box)
	var most: int = capacity(def)
	return 0 if used <= 0 or most <= 0 else clampi(ceili(4.0 * float(used) / float(most)), 1, 4)


# Fill share 0..1, by units.
static func fill_share(def: Dictionary, box) -> float:
	var most: int = capacity(def)
	return clampf(float(units(box)) / float(most), 0.0, 1.0) if most > 0 else 0.0


# The resource surface inside the bin's walls (master s2.5: one surface that rises and lowers with the fill and is gone when empty):
# its height above the bin's floor for a fill share, `floor_y` at the lowest visible fill up to `rim_y` (just under the rim) when full;
# -1.0 when empty (no surface drawn).
static func surface_height(share: float, floor_y: float, rim_y: float) -> float:
	if share <= 0.0:
		return -1.0

	return lerpf(floor_y, rim_y, clampf(share, 0.0, 1.0))
