extends RefCounted

# One place that puts Kathleen's worn clothing (worn_look.gd, data/items/worn.json) on a ragdoll body. Callers hand it the worn item numbers (the
# player's own protocol 40 list) or item ids (NPC outfits, data/npcs/outfits.json) and whether the body is far; it converts once, remembers what is
# on the rig (meta "worn_key") and does nothing when nothing changed. Distance: far is decided here with a few metres of hysteresis so a body at
# the limit does not flicker (far bodies skip the detail parts).
# Today only the player's own body and NPCs wear things. When remote-player bodies arrive, call apply() with the ids the server sends (claim a
# protocol number then, nothing changes here).

const WornLook := preload("res://src/client/worn_look.gd")
const FAR_M := 30.0
const HYSTERESIS_M := 3.0


# Item ids for a list of worn item numbers (0 = nothing in that slot); only items that have a worn.json row.
static func ids_of(numbers, table) -> Array:
	var ids: Array = []

	for number in numbers:
		if int(number) <= 0:
			continue

		var id: String = table.id_of(int(number))

		if WornLook.has_worn(id):
			ids.append(id)

	return ids


# Item ids from names that may not all be wearable (an NPC outfit row): unknown ones are skipped, and logged once per id.
static var _warned: Dictionary = {}


static func known_ids(names: Array) -> Array:
	var ids: Array = []

	for name in names:
		if WornLook.has_worn(str(name)):
			ids.append(str(name))
		elif not _warned.has(str(name)):
			_warned[str(name)] = true
			print("worn_sync: '%s' has no worn.json row, skipped" % str(name))

	return ids


# The far flag after a distance reading: far beyond FAR_M + hysteresis, near again inside FAR_M - hysteresis, unchanged in between.
static func far_after(distance_m: float, was_far: bool) -> bool:
	if was_far:
		return distance_m > FAR_M - HYSTERESIS_M

	return distance_m > FAR_M + HYSTERESIS_M


# Hang `item_ids` on `rig` (a RagdollBody). Returns the number of parts hung, or -1 when the rig already wears exactly this (nothing touched).
static func apply(rig: Node, item_ids: Array, far: bool) -> int:
	var sorted_ids: Array = item_ids.duplicate()
	sorted_ids.sort()
	var key: String = "%s|%s" % [",".join(PackedStringArray(sorted_ids)), "far" if far else "near"]

	if str(rig.get_meta("worn_key", "")) == key:
		return -1

	rig.set_meta("worn_key", key)
	return WornLook.attach(rig, item_ids, far)
