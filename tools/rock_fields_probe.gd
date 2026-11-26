extends SceneTree

# Probe for PR #1988 (rocky ground): why fires and crafts stopped working in tests on flat ground with rock_fields on (Lane A, 26 Nov 2026). The set-up of
# test_fire_fuel_tiers (flat ground at 10 m, a player at the origin, a fire at x 2), with rock_fields on and then off: after 200 ticks of 10 s
# it prints the rocky-ground rows near the origin, the player's position as the server has it, the fire's state and whether fuel goes in.
#   godot --headless --path . --script res://tools/rock_fields_probe.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")


func _init() -> void:
	for fields_on in [true, false]:
		var dir: String = "user://rock_fields_probe_%s" % str(fields_on)
		DirAccess.make_dir_recursive_absolute(dir)

		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + "/" + file)

		var said: Array = []
		var f = ItemsScript.new()
		f.send_full = func(_p, _b): pass
		f.send_slots = func(_p, _b): pass
		f.send_world_items = func(_p, _a, _r): pass
		f.send_notice = func(_p, t): said.append(t)
		f.setup(ItemTableScript.load_default(), dir)
		f._boulder_cfg["rock_fields"]["enabled"] = fields_on
		f.ground_height = func(_x, _z): return 10.0
		f.peer_connected_hello(1, "firekey000001")
		f._characters[f._peer_key[1]]["grace_s"] = 0.0
		f.report_position(1, Vector3(0.0, 10.0, 0.0))
		f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("campfire_kit"), 0, 1, Vector3.ZERO)
		f.action(1, Net.ACT_PLACE, 0, 0, 0, Vector3(2.0, 10.0, 0.0))
		var id: int = 0

		for k in f._items:
			if f._items[k].has("fire"):
				id = k

		var stick: int = f.table.number_of("stick")
		f.action(1, Net.ACT_ADMIN_GIVE, stick, 0, 10, Vector3.ZERO)

		var ticks_usec: int = Time.get_ticks_usec()

		for n in range(200):
			f.tick(10.0)

		var ticks_ms: float = float(Time.get_ticks_usec() - ticks_usec) / 1000.0   # past 15 s of real time the player is parked as absent (ABSENT_MS)

		var field: Array = []

		for k in f._items:
			var it: Dictionary = f._items[k]

			if it.has("scatter") and (int(it["scatter"]) & f.FIELD_KEY) != 0:
				field.append("%s r %.2f" % [str(it["pos"]), float(it.get("boulder", {}).get("radius", 0.0))])

		var before: int = f.inventory_of(1).count_of(stick)
		said.clear()
		f.action(1, Net.ACT_FUEL, id, 0, 0, Vector3.ZERO)
		print("rock_fields_probe: fields %s: %d rows %s; items %d, next id %d; fire id %d exists %s at %s state %s; peer pos %s, parked %s; sticks %d -> %d; said %s; reach %s; 200 ticks took %.0f ms" % [
			str(fields_on), field.size(), str(field), f._items.size(), f._next_id, id, str(f._items.has(id)), str(f._items.get(id, {}).get("pos")),
			str(f._items.get(id, {}).get("fire", {}).get("state")), str(f._peer_pos.get(1)), str(f._parked.has(1)), before, f.inventory_of(1).count_of(stick), str(said),
			str(not f._fire_in_reach(1, id).is_empty()), ticks_ms])

	quit(0)
