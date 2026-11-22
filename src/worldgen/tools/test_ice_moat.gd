extends SceneTree

# The thaw's open shore moat on the server agrees with the client's sheet (ice_moat.gd; frozen_water_look.md 4, #729; coordinator 22 Nov 2026: "fix
# the thaw-ice moat so the server agrees with what the player sees (drinking and filling at the open shore water in spring)").
#   1. in_moat: no moat, no open water; a point one 8 m cell from dry ground is open in a one-cell moat, the middle of the lake is not; two cells reach further;
#   2. moat_cells is the client's IceFeel.moat_cells(FrozenWater.thaw_of(Ice.season at 3 m)) at the same time, height and zone, kept for an hour;
#      over a temperate winter there is ice with no moat and a thaw with one;
#   3. the server's ice rule (_on_ice) is open water in the moat and ice beside it, so a drink at the open shore needs no hole.
#   godot --headless --path . --script res://src/worldgen/tools/test_ice_moat.gd

const IceMoat := preload("res://src/shared/ice_moat.gd")
const Ice := preload("res://src/shared/ice.gd")
const FrozenWater := preload("res://src/client/frozen_water.gd")
const IceFeel := preload("res://src/client/ice_feel.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

const DAY := 86400.0
const SEED := 574716103   # test_frozen_water's world
const ALT_M := 533.0       # its spring level, where a temperate winter freezes
var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var lake := func(pos: Vector3, _reach: float) -> bool: return pos.x >= 0.0 and pos.x <= 200.0 and pos.z >= 0.0 and pos.z <= 200.0   # a 200 m lake

	check(not IceMoat.in_moat(Vector3(4.0, 10.0, 100.0), 0, lake), "no moat: the shore is ice")
	check(IceMoat.in_moat(Vector3(4.0, 10.0, 100.0), 1, lake), "a one-cell moat: 4 m from the shore is open water")
	check(not IceMoat.in_moat(Vector3(12.0, 10.0, 100.0), 1, lake) and IceMoat.in_moat(Vector3(12.0, 10.0, 100.0), 2, lake), "12 m out is ice in a one-cell moat, open in a two-cell one")
	check(not IceMoat.in_moat(Vector3(100.0, 10.0, 100.0), 2, lake), "the middle of the lake is ice in any moat")
	check(not IceMoat.in_moat(Vector3(4.0, 10.0, 100.0), 1, Callable()), "no water map: no moat")

	var moat = IceMoat.new()
	var seen_ice: bool = false
	var seen_thaw: float = -1.0

	for day in range(300, 420, 2):   # a temperate winter (test_frozen_water days 342 to 344)
		var t: float = float(day) * DAY + 12.0 * 3600.0
		var season: Dictionary = Ice.season(t, "temperate", ALT_M, 3.0, SEED)
		var want: int = IceFeel.moat_cells(FrozenWater.thaw_of(float(season["cover"]), float(season["peak"])))
		var fresh = IceMoat.new()
		var got: int = fresh.moat_cells(Vector3(0.0, ALT_M, 0.0), t, "temperate", SEED)

		if got != want:
			check(false, "day %d: the server's moat %d is the client's %d" % [day, got, want])
			break

		seen_ice = seen_ice or (float(season["cover"]) > 0.1 and got == 0)

		if got > 0 and seen_thaw < 0.0:
			seen_thaw = t

	check(seen_ice, "a temperate winter has ice with no moat")
	check(seen_thaw >= 0.0, "and a thaw with an open moat (first at day %.0f)" % (seen_thaw / DAY))

	if seen_thaw >= 0.0:
		var first: int = moat.moat_cells(Vector3(0.0, ALT_M, 0.0), seen_thaw, "temperate", SEED)
		check(first > 0 and moat.moat_cells(Vector3(0.0, ALT_M, 0.0), seen_thaw - 200.0 * DAY, "temperate", SEED) == 0, "kept for an hour, not for another time of year (%d)" % first)

		# The server's ice rule as terrain_server wires it.
		var items = ItemsScript.new()
		items.send_notice = func(_p, _t): pass
		items.setup(ItemTableScript.load_default(), "user://test_ice_moat")
		items.water_near = lake
		items.ice_cover_at = func(_pos): return 1.0   # thick ice everywhere, as the moat's thaw still has in the middle
		items.ice_moat_at = func(pos): return IceMoat.in_moat(pos, first, lake)
		check(not items._on_ice(Vector3(4.0, ALT_M, 100.0)), "the server's ice rule: 4 m from the shore is open water in the thaw (a drink needs no hole)")
		check(items._on_ice(Vector3(100.0, ALT_M, 100.0)), "and the middle is still ice (a hole is needed there)")
		items._finish_writer()

	var server_text: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	check(server_text.contains("items.ice_moat_at = func(pos): return IceMoatScript.in_moat(") and server_text.contains("animals.ice_moat_at = items.ice_moat_at"), "the server wires the moat for players and animals (it was never set before 22 Nov 2026)")
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
