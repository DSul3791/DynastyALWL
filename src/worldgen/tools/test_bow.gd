extends SceneTree

# Bow shooting (ACT_SHOOT, data/items/bow.json): draw power, ammo, pace, flight to a stub animal, the ground, retrievable and breaking arrows, water, forged draw time.
# The aim (Dave 10 Nov 2026, BowAim, bow.json "aim"): steady time, wobble, the vital-zone pull, the server's spread and the damage by bow skill, the loaded arrow, fibre arrows.
#   godot --headless --path . --script res://src/worldgen/tools/test_bow.gd      Prints "Test done: N pass, N fail".

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const BowScript := preload("res://src/stream/server_bow.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const BowAim := preload("res://src/shared/bow_aim.gd")

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
	items._bow = BowScript.new()
	items._bow.cfg["aim"]["spread_deg"] = [[0, 0.0]]      # the flight checks aim true; the spread has its own checks (aim_checks)
	items.peer_connected_hello(1, "bow-key-00000001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	return items


func shoot(items, slot: int, draw_ms: int, dir: Vector3, loaded: int = 0) -> void:
	items._last_shot.clear()
	items.action(1, Net.ACT_SHOOT, slot, draw_ms, loaded, dir)


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
	aim_checks()
	loaded_checks()
	tree_checks()
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)


# BowAim: the numbers of the aim by bow skill (0..100), from bow.json.
func aim_checks() -> void:
	var cfg: Dictionary = BowAim.load_config()
	check(cfg.has("aim"), "bow.json has the aim numbers")
	check(is_equal_approx(BowAim.curve([[0, 2.0], [100, 4.0]], 50.0), 3.0) and BowAim.curve([[0, 2.0], [100, 4.0]], -5.0) == 2.0 and BowAim.curve([[0, 2.0], [100, 4.0]], 500.0) == 4.0, "a curve runs straight between its points and holds at the ends")
	check(is_equal_approx(BowAim.steady_s(cfg, 0.0), 2.0), "no skill: two seconds of steady aim (Dave)")
	check(BowAim.steady_s(cfg, 100.0) > BowAim.steady_s(cfg, 0.0), "skill holds the aim steady longer")
	check(BowAim.wobble_deg(cfg, 0.0, 1.9) == 0.0 and BowAim.wobble_deg(cfg, 0.0, 3.0) > 0.0, "no sway inside the steady time, sway after it")
	check(BowAim.wobble_deg(cfg, 0.0, 4.0) > BowAim.wobble_deg(cfg, 0.0, 3.0), "the sway grows the longer the bow is held")
	check(BowAim.wobble_deg(cfg, 0.0, 600.0) <= float(cfg["aim"]["wobble_max_deg"]) + 0.0001, "the sway stops growing at wobble_max_deg")
	check(BowAim.wobble_deg(cfg, 100.0, 7.0) < BowAim.wobble_deg(cfg, 0.0, 7.0), "skill sways less")
	check(BowAim.damage_mult(cfg, 0.0) == 1.0 and BowAim.damage_mult(cfg, 100.0) > 1.0, "skill raises the damage, none leaves it as the arrow's")
	var bow = BowScript.new()
	check(bow.damage(8.0, 1.0, 100.0) > bow.damage(8.0, 1.0, 0.0), "the server's damage takes the skill multiplier")

	# Each bow its own power and range (bow.json "bows"; Jamie #933): the longbow's arrow is faster, hits harder and flies further than the
	# wooden bow's; a bow with no row shoots like the wooden bow.
	check(is_equal_approx(bow.speed(1.0, "wooden_longbow"), 1.2 * bow.speed(1.0, "wooden_bow")) and is_equal_approx(bow.speed(1.0, "wooden_bow"), float(cfg["speed_max"])), "a longbow's arrow leaves 1.2 times as fast (%.0f m/s)" % bow.speed(1.0, "wooden_longbow"))
	check(bow.damage(8.0, 1.0, 0.0, "wooden_longbow") > bow.damage(8.0, 1.0, 0.0, "wooden_bow") and is_equal_approx(bow.damage(8.0, 1.0, 0.0, "wooden_bow"), bow.damage(8.0, 1.0, 0.0)), "and hits harder")
	check(bow.range_m("wooden_longbow") > bow.range_m("wooden_bow") and is_equal_approx(bow.range_m("no_such_bow"), float(cfg["range_m"])), "and flies further (%.0f m); a bow with no row is the wooden bow" % bow.range_m("wooden_longbow"))
	check(is_equal_approx(BowAim.bow_speed_max(cfg, "wooden_longbow"), bow.speed(1.0, "wooden_longbow")), "the client's flight uses the same speed as the server's")

	# The pull: none at no skill; with skill a zone near the aim draws it, a zone far off does not.
	var eye: Vector3 = Vector3.ZERO
	var points: Array = BowAim.zone_points(cfg, Vector3(0.0, -1.5, -30.0), 0.0)
	check(points.size() == 2, "a deer has its head and heart zones")
	var off: Vector3 = (points[1] - eye).normalized().rotated(Vector3.UP, deg_to_rad(2.0))
	check(BowAim.assist(cfg, 0.0, eye, off, points) == off, "no skill: no pull toward a vital zone")
	var pulled: Vector3 = BowAim.assist(cfg, 100.0, eye, off, points)
	check(pulled.angle_to(points[1] - eye) < off.angle_to(points[1] - eye), "skill pulls the aim toward the nearest vital zone")
	var far: Vector3 = (points[1] - eye).normalized().rotated(Vector3.UP, deg_to_rad(20.0))
	check(BowAim.assist(cfg, 100.0, eye, far, points) == far, "a zone outside the pull cone does not pull")

	# The spread: no skill turns a shot up to spread_deg, never more; full skill much less.
	var widest: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var forward: Vector3 = Vector3(0.0, 0.1, -1.0).normalized()

	for n in 500:
		widest = maxf(widest, rad_to_deg(BowAim.spread(forward, BowAim.spread_deg(cfg, 0.0), rng.randf(), rng.randf()).angle_to(forward)))   # luck-exempt: test draws

	check(widest <= BowAim.spread_deg(cfg, 0.0) + 0.001 and widest > BowAim.spread_deg(cfg, 0.0) * 0.8, "no skill: shots turn at random up to spread_deg (%.2f)" % widest)
	check(BowAim.spread_deg(cfg, 100.0) < BowAim.spread_deg(cfg, 0.0) * 0.2, "skill narrows the spread")
	check(BowAim.spread(forward, 0.0, 1.0, 0.5).is_equal_approx(forward), "no spread: the shot goes where it was aimed")


# The loaded arrow is shot first; fibre arrows (the only arrow made without feathers) are ammo.
func loaded_checks() -> void:
	var items = make("user://test_bow_loaded")
	var bow_no: int = items.table.number_of("wooden_bow")
	items.action(1, Net.ACT_ADMIN_GIVE, bow_no, 0, 1, Vector3.ZERO)
	var slot: int = items.inventory_of(1).numbers.find(bow_no)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("fibre_arrow"), 0, 2, Vector3.ZERO)
	said.clear()
	shoot(items, slot, 1200, Vector3(0.0, 0.2, -1.0))
	check(items._arrows.size() == 1 and arrows(items, "fibre_arrow") == 1 and not said.has(items._bow.cfg["say_no_ammo"]), "fibre arrows shoot (they were missing from the ammo list: the bow 'did not work at all')")
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone_arrow"), 0, 3, Vector3.ZERO)
	shoot(items, slot, 1200, Vector3(0.0, 0.2, -1.0), items.table.number_of("fibre_arrow"))
	check(arrows(items, "fibre_arrow") == 0 and arrows(items, "stone_arrow") == 3, "the bow loaded with fibre arrows shoots a fibre arrow, though stone comes first in the list")
	shoot(items, slot, 1200, Vector3(0.0, 0.2, -1.0), items.table.number_of("fibre_arrow"))
	check(arrows(items, "stone_arrow") == 2, "loaded arrows run out: the next ammo in the pack is shot")
	shoot(items, slot, 1200, Vector3(0.0, 0.2, -1.0), items.table.number_of("wooden_bow"))
	check(arrows(items, "stone_arrow") == 1, "a forged 'loaded' item that is not ammo is ignored")


# An arrow shot at a tree sticks in it (Dave 10 Nov 2026: "I just stood right infront of a tree and shot an arrow and it did not hit the tree or stick
# into it. there should be an arrow in that tree until I collect it or it fades out in 5 minutes"); the sway turns the whole view (BowAim.turn_of).
func tree_checks() -> void:
	# The trunk test: a level flight 1.5 m up meets a 0.3 m trunk 8 m ahead at its bark; passing beside it, over its top or after the segment misses.
	var trunk_foot: Vector3 = Vector3(0.0, 10.0, -8.0)
	var t: float = BowAim.segment_trunk(Vector3(0.0, 11.5, 0.0), Vector3(0.0, 11.5, -10.0), trunk_foot, 0.3, 12.0)
	check(absf(t - 0.77) < 0.001, "a level shot meets the trunk at its bark, 7.7 m out (%.3f)" % t)
	check(BowAim.segment_trunk(Vector3(1.0, 11.5, 0.0), Vector3(1.0, 11.5, -10.0), trunk_foot, 0.3, 12.0) < 0.0, "1 m to the side misses")
	check(BowAim.segment_trunk(Vector3(0.0, 23.0, 0.0), Vector3(0.0, 23.0, -10.0), trunk_foot, 0.3, 12.0) < 0.0, "over the top of a 12 m tree misses")
	check(BowAim.segment_trunk(Vector3(0.0, 11.5, 0.0), Vector3(0.0, 11.5, -5.0), trunk_foot, 0.3, 12.0) < 0.0, "a step that ends short of the trunk misses")

	# The server: a full draw at the trunk 8 m ahead (Dave stood right in front of it) leaves one arrow stuck at the bark, for 5 minutes.
	deer_at = Vector3(0.0, -100.0, 0.0)
	var items = make("user://test_bow_tree")
	items.trunks_near = func(point: Vector3, radius: float) -> Array:
		return [[trunk_foot, 0.3, 12.0]] if Vector2(point.x - trunk_foot.x, point.z - trunk_foot.z).length() <= radius else []
	items._bow.cfg["break_chance"] = {}   # every tip unbreakable here: the check is where it ends, not the luck of it
	items._bow.cfg["break_chance"]["stone"] = 0.0
	var bow_no: int = items.table.number_of("wooden_bow")
	items.action(1, Net.ACT_ADMIN_GIVE, bow_no, 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone_arrow"), 0, 2, Vector3.ZERO)
	var slot: int = items.inventory_of(1).numbers.find(bow_no)
	shoot(items, slot, 1200, Vector3(0.0, 0.0, -1.0))
	fly(items, 2.0)
	var stuck: Array = []

	for id in items._items:
		if items._items[id].has("tilt"):
			stuck.append(items._items[id])

	check(items._arrows.is_empty() and stuck.size() == 1, "the arrow stops in the trunk and stays there (%d stuck)" % stuck.size())

	if stuck.size() == 1:
		var at: Vector3 = stuck[0]["pos"]
		check(Vector2(at.x - trunk_foot.x, at.z - trunk_foot.z).length() < 0.31 and at.y > 11.0 and at.y < 12.0, "at the bark, about eye height (%s)" % str(at))
		check(is_equal_approx(float(stuck[0]["left"]), 300.0) and float(items._bow.cfg.get("stuck_s", 0.0)) == 300.0, "it stays 5 minutes unless picked up (bow.json stuck_s)")
		check(absf(float(stuck[0]["tilt"])) < 0.2 and absf(wrapf(float(stuck[0]["rot_y"]) - PI * 0.5, -PI, PI)) < 0.01, "it points along its flight (yaw %.2f, tilt %.2f)" % [float(stuck[0]["rot_y"]), float(stuck[0]["tilt"])])

	shoot(items, slot, 1200, Vector3(0.0, 0.0, -1.0))
	fly(items, 2.0)
	var stuck_now: int = 0

	for id in items._items:
		stuck_now += 1 if items._items[id].has("tilt") else 0

	check(stuck_now == 2, "a second arrow beside the first is its own stuck arrow, not a pile (%d)" % stuck_now)

	# A shot that does not stick (bow.json "bows" sticks false: the sling's stone) drops at the trunk's foot instead. The wooden bow stands in
	# for the sling here, since the Sling and Sling stone items come with Jamie's Part C rows.
	items._bow.cfg["bows"]["wooden_bow"]["sticks"] = false
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone_arrow"), 0, 1, Vector3.ZERO)
	shoot(items, slot, 1200, Vector3(0.0, 0.0, -1.0))
	fly(items, 2.0)
	var at_foot: Array = []

	for id in items._items:
		if not items._items[id].has("tilt") and int(items._items[id].get("number", 0)) == items.table.number_of("stone_arrow"):
			at_foot.append(items._items[id])

	check(items._arrows.is_empty() and at_foot.size() == 1 and absf(float(at_foot[0]["pos"].y) - 10.0) < 0.3 and Vector2(at_foot[0]["pos"].x - trunk_foot.x, at_foot[0]["pos"].z - trunk_foot.z).length() < 0.6, "a shot that does not stick lies at the trunk's foot (%d)" % at_foot.size())
	items._bow.cfg["bows"]["wooden_bow"].erase("sticks")

	# The sling (item_system.md): drawn and loosed like a bow, its own ammo list, slower and shorter, never sticks, its own lines.
	var sling_cfg: Dictionary = BowAim.load_config()
	check(BowAim.shoots({"weapon_class": "sling"}) and BowAim.shoots({"weapon_class": "bow"}) and not BowAim.shoots({"weapon_class": "spear"}), "a sling shoots like a bow; a spear does not")
	check(BowAim.ammo_for(sling_cfg, "sling") == ["sling_stone"] and BowAim.ammo_for(sling_cfg, "wooden_bow") == sling_cfg["ammo"] and BowAim.ammo_for(sling_cfg, "wooden_longbow") == sling_cfg["ammo"], "the sling throws sling stones; the bows take the arrow list")
	check(not BowAim.sticks(sling_cfg, "sling") and BowAim.sticks(sling_cfg, "wooden_bow"), "a sling stone never sticks; an arrow does")
	var sling_bow = BowScript.new()
	check(not sling_bow.is_ammo("stone_arrow", "sling") and sling_bow.is_ammo("sling_stone", "sling") and sling_bow.is_ammo("stone_arrow", "wooden_bow"), "an arrow is no sling ammo")
	check(absf(sling_bow.speed(1.0, "sling") - 31.5) < 0.01 and is_equal_approx(sling_bow.range_m("sling"), 60.0), "a sling stone leaves at about 32 m/s and reaches 60 m")
	check(BowAim.say(sling_cfg, "sling", "say_no_ammo") == "You have no sling stones." and BowAim.say(sling_cfg, "wooden_bow", "say_no_ammo") == str(sling_cfg["say_no_ammo"]), "the sling says its own lines")
	check(float(sling_cfg["break_chance"].get("stone_shot", 1.0)) <= 0.1, "a sling stone seldom breaks")

	# The sway's turn of the view: turn_of undoes turned for small angles.
	var fwd: Vector3 = Vector3(0.0, 0.0, -1.0)
	var turn: Vector2 = BowAim.turn_of(BowAim.turned(fwd, Vector3.RIGHT, Vector3.UP, Vector2(0.8, -0.5)), fwd, Vector3.RIGHT, Vector3.UP)
	check(absf(turn.x - 0.8) < 0.01 and absf(turn.y + 0.5) < 0.01, "the view turns by the sway it is given (%s)" % str(turn))
	var cfg: Dictionary = BowAim.load_config()
	check(float(cfg["aim"]["wobble_max_deg"]) <= 1.5, "the sway is much less than the 4 degrees the cross moved (%.1f)" % float(cfg["aim"]["wobble_max_deg"]))
