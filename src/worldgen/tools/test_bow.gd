extends SceneTree

# Bow shooting (ACT_SHOOT, data/items/bow.json): draw power, ammo, pace, flight to a stub animal, the ground, retrievable and breaking arrows, water, forged draw time.
#   godot --headless --path . --script res://src/worldgen/tools/test_bow.gd      Prints "Test done: N pass, N fail".

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const BowScript := preload("res://src/stream/server_bow.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var passes: int = 0
var failures: int = 0
var said: Array = []
var hits: Array = []
var alarms: Array = []
var deer_at: Vector3 = Vector3(0.0, 10.0, -20.0)


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.ground_height = func(_x, _z): return 10.0
	items.hit_animal_path = func(_peer, from, to, amount) -> Dictionary:
		var seg: Vector3 = to - from
		var t: float = clampf((deer_at + Vector3(0.0, 0.5, 0.0) - from).dot(seg) / maxf(seg.length_squared(), 0.000001), 0.0, 1.0)

		if (from + seg * t).distance_to(deer_at + Vector3(0.0, 0.5, 0.0)) <= 0.6:
			hits.append(amount)
			return {"at": deer_at}

		return {}
	items.animal_alarm = func(point, radius): alarms.append([point, radius])
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "bow-key-00000001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	return items


func shoot(items, slot: int, draw_ms: int, dir: Vector3) -> void:
	items._last_shot.clear()
	items.action(1, Net.ACT_SHOOT, slot, draw_ms, 0, dir)


func fly(items, seconds: float) -> void:
	for n in int(seconds * 20.0):
		items._arrow_fly(0.05)


func arrows(items, id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func _init() -> void:
	var bow = BowScript.new()
	check(bow.power(0) == bow.cfg["weak_power"] and bow.power(299) == bow.cfg["weak_power"], "a draw under the minimum is a weak shot")
	check(is_equal_approx(bow.power(300), bow.cfg["min_power"]) and is_equal_approx(bow.power(1200), 1.0), "power runs from min_power at the minimum draw to 1 at the full draw")
	check(bow.power(999999) == 1.0 and bow.clamp_draw(-50) == 0, "a forged draw time is clamped")
	check(bow.lost_chance("stone", false, false) < bow.lost_chance("wood", false, false), "stone tips break less than wood")
	check(bow.lost_chance("stone", true, false) > bow.lost_chance("stone", false, false), "an arrow that hit an animal breaks more")
	check(bow.lost_chance("stone", false, true) >= bow.cfg["water_loss"], "water loses half the arrows or more")

	var items = make("user://test_bow")
	var bow_no: int = items.table.number_of("wooden_bow")
	check(bow_no != 0 and items.table.number_of("stone_arrow") != 0, "the bow and arrow items exist")
	items.action(1, Net.ACT_ADMIN_GIVE, bow_no, 0, 1, Vector3.ZERO)
	var slot: int = items.inventory_of(1).numbers.find(bow_no)

	# No arrows: nothing flies, the player is told.
	shoot(items, slot, 1200, Vector3(0.0, 0.0, -1.0))
	check(items._arrows.is_empty() and said.has(items._bow.cfg["say_no_ammo"]), "no arrows, no shot")

	# A full draw at a deer 20 m away, level: the arc falls about a metre by then, from eye height onto the chest. It hits and hurts.
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone_arrow"), 0, 5, Vector3.ZERO)
	shoot(items, slot, 1200, Vector3(0.0, 0.0, -1.0))
	check(items._arrows.size() == 1 and arrows(items, "stone_arrow") == 4, "a shot takes one arrow from the pack")
	check(alarms.size() == 1 and float(alarms[0][1]) == float(items._bow.cfg["noise_m"]), "the shot is heard within the noise radius")
	fly(items, 2.0)
	check(items._arrows.is_empty() and hits.size() == 1, "the arrow ends its flight on the deer")
	check(absf(float(hits[0]) - 8.0) < 0.5, "a full draw does the stone arrow's damage (%.1f)" % float(hits[0] if hits.size() > 0 else 0.0))

	# A short draw falls short and lands on the ground, and can be picked up again.
	hits.clear()
	deer_at = Vector3(0.0, 10.0, -60.0)
	shoot(items, slot, 100, Vector3(0.0, 0.05, -1.0))
	check(said.has(items._bow.cfg["say_weak"]), "a weak draw is told")
	fly(items, 6.0)
	check(items._arrows.is_empty() and hits.is_empty(), "a weak shot does not reach a deer 60 m away")

	# Pace: a second press inside the pace does nothing.
	items._last_shot.clear()
	items.action(1, Net.ACT_SHOOT, slot, 1200, 0, Vector3(0.0, 0.2, -1.0))
	var in_air: int = items._arrows.size()
	items.action(1, Net.ACT_SHOOT, slot, 1200, 0, Vector3(0.0, 0.2, -1.0))
	check(items._arrows.size() == in_air, "a second shot inside the pace is ignored")
	fly(items, 8.0)

	deer_at = Vector3(0.0, -500.0, 0.0)      # out of the way of the rest

	# Landing: over many shots the survivors lie on the ground as the data says (stone: lost 35 percent).
	var total: int = 400
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone_arrow"), 0, 1, Vector3.ZERO)
	var landed: int = 0
	var before_world: int = items._items.size()

	for n in total:
		items.inventory_of(1).add(items.table.number_of("stone_arrow"), 1)
		shoot(items, slot, 1200, Vector3(0.0, 0.3, -1.0))
		fly(items, 8.0)

	for id in items._items:
		if int(items._items[id].get("number", 0)) == items.table.number_of("stone_arrow"):
			landed += int(items._items[id].get("count", 1))

	var share: float = float(landed) / float(total + 2)
	check(share > 0.45 and share < 0.85, "about 65 percent of stone arrows survive a landing on the ground (%.2f)" % share)

	# Range cap: a very high shot comes down within range_m of flight, never loops forever.
	shoot(items, slot, 1200, Vector3(0.0, 1.0, -0.01))
	fly(items, 30.0)
	check(items._arrows.is_empty(), "every arrow ends its flight")

	# Water: arrows landing in water are lost half the time or more, so fewer lie on the bottom than on dry ground.
	items.water_depth_at = func(_p): return 1.0
	var stone: int = items.table.number_of("stone_arrow")
	var world_before: int = 0
	var wet_kept: int = 0
	var wet_shots: int = 300

	for id in items._items:
		world_before += int(items._items[id].get("count", 1)) if int(items._items[id].get("number", 0)) == stone else 0

	for n in wet_shots:
		items.inventory_of(1).add(stone, 1)
		shoot(items, slot, 1200, Vector3(0.0, 0.3, -1.0))
		fly(items, 8.0)

	for id in items._items:
		wet_kept += int(items._items[id].get("count", 1)) if int(items._items[id].get("number", 0)) == stone else 0

	wet_kept -= world_before
	check(wet_kept < int(float(wet_shots) * 0.6), "water loses half of the stone arrows or more (%d of %d kept)" % [wet_kept, wet_shots])

	# A broken bow does not shoot.
	items.water_depth_at = Callable()
	items.inventory_of(1).wear[slot] = 100000
	var count_before: int = items._arrows.size()
	items.inventory_of(1).add(items.table.number_of("stone_arrow"), 1)
	shoot(items, slot, 1200, Vector3(0.0, 0.1, -1.0))
	check(items._arrows.size() == count_before, "a broken bow does not shoot")
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
