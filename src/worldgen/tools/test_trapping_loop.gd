extends SceneTree

# The whole trapping loop, over server restarts (the coordinator, 23 Nov 2026): snares set on the trails the player is sent, and off them;
# Tracking at each step; restarts while the player is away; the catches rolled for the game days away (on a trail only); what is caught,
# how it is worked with a knife, the snare's wear; the bird trap; the fish trap's catch kept in it over a restart; the trails kept for the
# Map and drawn there from Tracking 10. The real trails (server_ranges.gd), items (server_items.gd) and traps (server_traps.gd).
#   godot --headless --path . --script res://src/worldgen/tools/test_trapping_loop.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const RangesScript := preload("res://src/stream/server_ranges.gd")
const MapScript := preload("res://src/stream/server_map.gd")
const KnowledgeScript := preload("res://src/client/map_knowledge.gd")
const TrailCodec := preload("res://src/shared/trail_codec.gd")
const SkillWebScript := preload("res://src/shared/skill_web.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DIR := "user://test_trapping_loop"
const KEY := "loop-key-00000001"
const POND := Vector3(-40.0, 10.0, -40.0)   # a pond 10 m round, 0.6 m deep (for the fish trap)

var failures: int = 0
var passes: int = 0
var clock: Array = [100.0 * 86400.0 + 18.0 * 3600.0]   # a game day 100, dusk
var ranges = null


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1

	print(("ok   " if ok else "FAIL ") + what)


func ground(x: float, z: float) -> float:
	return 10.0 + 1.5 * sin(x * 0.01) + 1.2 * cos(z * 0.013)


# A server start: the items from the save, the trails worked out again from the world seed (as a real start does once a player is near).
func start(wipe: bool, at: Vector3):
	DirAccess.make_dir_recursive_absolute(DIR)

	if wipe:
		for file in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(x, z): return ground(x, z)
	items.game_seconds = func(): return clock[0]
	items.rain_now = func(): return 0.0
	items.water_near = func(p, _r): return (p as Vector3).distance_to(POND) < 12.0
	items.water_depth_at = func(p): return 0.6 if (p as Vector3).distance_to(POND) < 10.0 else 0.0
	items.trail_strength = func(_x, _z): return 0.0   # no worn grass: only the trails between animal places count
	items.species_active_at = func(_sp, hour, _z): return 0.6 if hour >= 18.0 or hour < 6.0 else 0.15   # rabbits out from dusk to dawn
	items.setup(ItemTableScript.load_default(), DIR)
	ranges = RangesScript.new()
	ranges.setup()
	ranges.world_seed = 11
	ranges.ground_height = func(x, z): return ground(x, z)
	ranges.blocked = func(_x, _z): return false
	ranges.no_spawn = func(x, z): return items.spawn_blocked(x, z)
	ranges.cfg["budget_ms"] = 1000.0

	for k in 80:
		ranges.tick([at], 1000 + k)

	items.run_distance = func(x, z, kind): return ranges.route_distance(x, z, kind)
	items.fox_near = func(x, z, m): return ranges.fox_near(x, z, m)
	items.peer_connected_hello(1, KEY)
	items.report_position(1, at)
	return items


func tracking(items) -> float:
	return float(items._skill_records(1).get("tracking", {}).get("p", 0.0))


# Sets a trap as placement does (the trap's own rules, then on_placed, and its no-spawn circle).
func lay(items, at: Vector3, kind: String = "snare_trap") -> int:
	items._last_practice.clear()   # the 2 s practice cooldown is real time
	var id: int = items._next_id
	items._next_id += 1
	items._items[id] = {"number": items.table.number_of(kind), "count": 1, "pos": at, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0}}
	items._traps.on_placed(1, id)
	items._zone_add(id)
	items._dirty = true
	return id


func traps_of(items, kind: String) -> Array:
	var out: Array = []

	for id in items._items:
		if str(items._items[id].get("struct", {}).get("kind", "")) == kind:
			out.append(id)

	return out


func save(items) -> void:
	items._dirty = true
	items.save()
	items._finish_writer()


func _init() -> void:
	var home: Vector3 = Vector3(128.0, 10.0, 128.0)
	var items = start(true, home)

	# The rabbit runs the player is sent (the trail block's routes), every few metres along them.
	var run_pts: Array = []

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key: Vector2i = Vector2i(dx, dz)

			for route in TrailCodec.decode_routes(ranges.wire(key, 1000), key, TrailCodec.ROUTE_BLOCK_M):
				if int(route[0]) != 0:
					continue

				for p in (route[1] as PackedVector2Array):
					if p.distance_to(Vector2(home.x, home.z)) < 200.0 and run_pts.all(func(q): return (q as Vector2).distance_to(p) > 6.0):
						run_pts.append(p)

	check(run_pts.size() >= 30, "the player is sent rabbit runs near them (%d spots)" % run_pts.size())
	var off_pts: Array = []

	for n in 400:
		var p: Vector2 = Vector2(home.x, home.z) + Vector2(cos(float(n) * 2.4), sin(float(n) * 2.4)) * (20.0 + float(n) * 0.4)

		if off_pts.size() < 10 and float(ranges.route_distance(p.x, p.y, -1)) >= 10.0:
			off_pts.append(p)

	check(off_pts.size() == 10, "and open ground well off any trail")

	# Set on the trails: each trains Tracking; off them, nothing.
	var t0: float = tracking(items)
	var on_ids: Array = []

	for n in 30:
		on_ids.append(lay(items, Vector3(run_pts[n].x, ground(run_pts[n].x, run_pts[n].y), run_pts[n].y)))

	var t1: float = tracking(items)
	check(t1 > t0, "thirty snares set on the runs train Tracking (%.1f -> %.1f units)" % [t0, t1])
	check(on_ids.all(func(id): return items._traps.trail_at(items._items[id]["pos"]) > 0.9), "every one of them reads the trail on the server")

	for p in off_pts:
		lay(items, Vector3(p.x, ground(p.x, p.y), p.y))

	check(is_equal_approx(tracking(items), t1), "ten set in open grass train nothing (%.1f)" % tracking(items))
	var bird_at: Vector2 = off_pts[0] + Vector2(3.0, 0.0)
	lay(items, Vector3(bird_at.x, ground(bird_at.x, bird_at.y), bird_at.y), "bird_trap_set")
	items._traps.tick(float(items._traps.cfg["check_s"]))   # the player near: each trap notes how squarely it sits on a run
	check(on_ids.all(func(id): return float(items._items[id]["struct"].get("run", 0.0)) > 0.9), "and notes it is on a run while the player is near")

	# The trails go on the character's map record, and come back after a restart.
	var map = MapScript.new()
	map.key_of = func(_peer): return KEY
	map.setup(DIR)

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			map.note_trails(1, Vector2i(dx, dz), ranges.wire(Vector2i(dx, dz), 1000))

	map.save()

	# Restart 1, with the player at home; then the player goes off for three game days, with a restart in the middle.
	save(items)
	items = start(false, home)
	check(traps_of(items, "snare_trap").size() == 40 and traps_of(items, "bird_trap_set").size() == 1, "after a restart all forty snares and the bird trap are set (%d, %d)" % [traps_of(items, "snare_trap").size(), traps_of(items, "bird_trap_set").size()])
	check(traps_of(items, "snare_trap").all(func(id): return str(items._items[id]["struct"].get("owner", "")) == KEY), "each with its owner")
	items._traps.tick(float(items._traps.cfg["check_s"]))
	items.report_position(1, Vector3(5000.0, 10.0, 5000.0))
	clock[0] += 1.5 * 86400.0
	save(items)
	items = start(false, Vector3(5000.0, 10.0, 5000.0))
	clock[0] += 1.5 * 86400.0
	var before_catch: float = tracking(items)

	# Home again: one roll a snare for the time away, on the runs only.
	items.report_position(1, home)
	items._last_practice.clear()
	items._traps.tick(float(items._traps.cfg["check_s"]))   # before the trails round home are worked out again: each rolls on the run it noted (kept over the restarts)

	for k in 80:
		ranges.tick([home], 5000 + k)   # worked out again, to tell the snares on the runs from those in open grass
	var caught_on: Array = []
	var caught_off: int = 0

	for id in traps_of(items, "snare_trap"):
		var st: Dictionary = items._items[id]["struct"]

		if items._items.has(int(st.get("catch", 0))):
			if float(ranges.route_distance(items._items[id]["pos"].x, items._items[id]["pos"].z, -1)) < 1.0:
				caught_on.append(id)
			else:
				caught_off += 1

	check(caught_on.size() >= 4 and caught_on.size() <= 24, "after three game days away about a third of the snares on the runs hold a catch (%d of 30)" % caught_on.size())
	check(caught_off == 0, "and none in open grass (%d)" % caught_off)

	if caught_on.is_empty():
		_finish()
		return

	var snare: int = caught_on[0]
	var carcass: int = int(items._items[snare]["struct"]["catch"])
	var body: Dictionary = items._items[carcass]["struct"]
	check(str(body["kind"]) == "carcass" and ["rabbit", "fox"].has(str(body["species"])) and bool(body.get("snared", false)), "the catch is a %s carcass, marked as snared" % str(body.get("species", "")))
	check((items._items[carcass]["pos"] as Vector3).distance_to(items._items[snare]["pos"]) < 2.0, "lying by its snare")
	check(int(items._items[snare].get("wear", 0)) == 1, "the snare wears one for the catch")
	check(tracking(items) > before_catch, "a catch trains Tracking (%.1f -> %.1f)" % [before_catch, tracking(items)])

	# A restart while the catch lies there: it is still there, the snare still sprung, its wear kept.
	var held: Dictionary = {}

	for id in caught_on:
		held[items._items[id]["pos"]] = str(items._items[int(items._items[id]["struct"]["catch"])]["struct"]["species"])

	save(items)
	items = start(false, home)
	var kept: int = 0
	var wear_kept: int = 0

	for id in traps_of(items, "snare_trap"):
		var at: Vector3 = items._items[id]["pos"]

		if not held.has(at):
			continue

		var c: int = int(items._items[id]["struct"].get("catch", 0))
		kept += 1 if items._items.has(c) and str(items._items[c].get("struct", {}).get("kind", "")) == "carcass" and str(items._items[c]["struct"].get("species", "")) == str(held[at]) else 0
		wear_kept += 1 if int(items._items[id].get("wear", 0)) == 1 else 0

	check(kept == held.size(), "a restart keeps every catch in its snare (%d of %d)" % [kept, held.size()])
	check(wear_kept == held.size(), "and each snare's wear (%d of %d)" % [wear_kept, held.size()])
	var stray: int = 0

	for id in traps_of(items, "snare_trap"):
		var c: int = int(items._items[id]["struct"].get("catch", 0))

		if not held.has(items._items[id]["pos"]) and items._items.has(c):
			stray += 1

	check(stray == 0, "no empty snare reads as sprung by something else after the restart (%d)" % stray)

	# A catch half cut up when the server restarts is still there half cut (its parts never come twice).
	var cut_snare: int = -1

	for id in traps_of(items, "snare_trap"):
		if held.has(items._items[id]["pos"]) and cut_snare < 0:
			cut_snare = id

	var cut_at: Vector3 = items._items[cut_snare]["pos"]
	var cut_carcass: int = int(items._items[cut_snare]["struct"]["catch"])
	var inv0 = items.inventory_of(1)
	items.give(1, items.table.number_of("stone_knife"), 1)
	items.report_position(1, items._items[cut_carcass]["pos"])
	items._last_process.clear()
	items._process_carcass(1, inv0, cut_carcass, inv0.numbers.find(items.table.number_of("stone_knife")))
	check(items._items.has(cut_carcass) and int(items._items[cut_carcass]["struct"]["blows"]) == 1, "one cut into a held catch")
	save(items)
	items = start(false, home)
	var cut_blows: int = -1

	for id in traps_of(items, "snare_trap"):
		var c2: int = int(items._items[id]["struct"].get("catch", 0))

		if items._items[id]["pos"] == cut_at and items._items.has(c2):
			cut_blows = int(items._items[c2]["struct"].get("blows", 0))

	check(cut_blows == 1, "after a restart a half cut catch is still in its snare, half cut, not whole again (%d blows)" % cut_blows)
	held.erase(cut_at)

	# Collected with a knife: the parts go into the pack, the snare sets itself again once the carcass is gone.
	for id in traps_of(items, "snare_trap"):
		if held.has(items._items[id]["pos"]):
			snare = id
			break

	carcass = int(items._items[snare]["struct"].get("catch", 0))
	var inv = items.inventory_of(1)
	items.give(1, items.table.number_of("stone_knife"), 1)
	var knife_slot: int = inv.numbers.find(items.table.number_of("stone_knife"))
	var pack_before: int = 0

	for slot in inv.slot_count:
		pack_before += inv.counts[slot]

	if items._items.has(carcass):
		items.report_position(1, items._items[carcass]["pos"])

	for blow in 20:
		if not items._items.has(carcass):
			break

		items._last_process.clear()
		items._process_carcass(1, inv, carcass, knife_slot)

	var pack_after: int = 0

	for slot in inv.slot_count:
		pack_after += inv.counts[slot]

	check(not items._items.has(carcass) and pack_after > pack_before, "worked with a knife, the catch goes into the pack (%d -> %d things)" % [pack_before, pack_after])
	items._items[snare]["struct"]["quiet"] = 0.0
	items._items[snare]["struct"]["away_at"] = clock[0] - 12.0 * 3600.0
	var again: bool = false

	for n in 200:
		items._items[snare]["struct"]["away_at"] = clock[0] - 12.0 * 3600.0

		if items._traps.check_away(snare):
			again = true
			break

	check(again, "and the snare, free again, catches again")

	# The fish trap: set in the pond, it fishes the game hours; its catch is kept in it over a restart and taken out like a chest's.
	var fish_def: Dictionary = items._structures.get("fish_trap_set", {})
	var kit: int = items.table.number_of(str(fish_def.get("kit", "fish_trap")))
	items.report_position(1, POND + Vector3(2.0, 0.0, 0.0))
	items.give(1, kit, 1)
	items.action(1, Net.ACT_PLACE, inv.numbers.find(kit), 0, 0, POND)
	var fish_traps: Array = traps_of(items, "fish_trap_set")
	check(fish_traps.size() == 1, "a fish trap goes into the pond")
	var fished: int = 0

	if fish_traps.size() == 1:
		var uid: int = int(items._items[fish_traps[0]]["struct"]["uid"])
		var cell: Vector2i = items._fish_cell(POND)
		items._fish_stock["%d,%d" % [cell.x, cell.y]] = [12, Time.get_unix_time_from_system()]
		items._fishing_data()["trap"]["hour_chance"] = 1.0

		clock[0] += 4.0 * 3600.0
		items.report_position(1, POND + Vector3(1.0, 0.0, 0.0))
		items._chest_of(1, fish_traps[0])   # E: the hours it has stood are fished now
		var box = items._chests[uid]

		for slot in box.slot_count:
			fished += box.counts[slot] if box.numbers[slot] != 0 else 0

		check(fished >= 1, "and fishes the game hours (%d fish)" % fished)
		save(items)
		items = start(false, home)
		var kept_fish: int = 0
		var box2 = items._chests.get(uid)

		for slot in (box2.slot_count if box2 != null else 0):
			kept_fish += box2.counts[slot] if box2.numbers[slot] != 0 else 0

		check(traps_of(items, "fish_trap_set").size() == 1 and kept_fish == fished, "after a restart the fish trap is set with its %d fish in it (%d)" % [fished, kept_fish])

	# The Map: the trails the character was near come back with its map after a restart, and are drawn from Tracking 10.
	var map2 = MapScript.new()
	map2.key_of = func(_peer): return KEY
	map2.setup(DIR)
	var sent: Array = []

	for n in 10:
		sent.append_array(map2.trail_updates_for(1))   # a few blocks a pass
	check(sent.size() >= 7, "after a restart the character's map holds the trails of the blocks it was near (%d)" % sent.size())
	var k = KnowledgeScript.new()

	for u in sent:
		k.set_trails(int(u[0]), int(u[1]), u[2])

	var level_10: float = SkillWebScript.units_for(items._skills_cfg, "tracking", float(k.trails_tracking))
	# A save from before trap state was kept (rows without index 24) still loads its traps.
	save(items)
	var area_dir: String = DIR + "/world_items"
	var stripped: int = 0

	for file in DirAccess.get_files_at(area_dir):
		if not file.ends_with(".json"):
			continue

		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(area_dir + "/" + file))

		if typeof(parsed) != TYPE_DICTIONARY:
			continue

		for row in parsed.get("items", []):
			if (row as Array).size() > 24 and str(row[9]) == "snare_trap":
				(row as Array).resize(24)
				stripped += 1

		var f: FileAccess = FileAccess.open(area_dir + "/" + file, FileAccess.WRITE)
		f.store_string(JSON.stringify(parsed))
		f.close()

	var old_save = start(false, home)
	check(stripped == 40 and traps_of(old_save, "snare_trap").size() == 40, "an older save's snare rows (no state, %d) still load, all forty (%d)" % [stripped, traps_of(old_save, "snare_trap").size()])
	check(k.trails_tracking == 10 and tracking(items) < level_10, "the Map draws them from Tracking %d; this trapper is not there yet (%.0f of %.0f units)" % [k.trails_tracking, tracking(items), level_10])
	_finish()


func _finish() -> void:
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
