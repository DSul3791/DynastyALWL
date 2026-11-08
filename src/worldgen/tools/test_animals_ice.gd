extends SceneTree

# Ice for animals and the ice look's server asks (docs/design/animals_on_ice_server.md section 6; MikeW ANIMAL_WEATHER_LOOKS.md; Kathleen
# frozen_water_look.md #729; Jamie #736): deer and boar never step on ice, others walk on ice that holds their mass for sure, a water flock stands at the open water's
# edge on a frozen pond, a thaw moat is open water (for animals and for the players' _on_ice), and the live ice holes go to the client
# (protocol 97) nearest first. With animals.json ice.on false the animals keep today's rules.
#   godot --headless --path . --script res://src/worldgen/tools/test_animals_ice.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0
var cover: Array = [0.0]
var moat_from_x: Array = [INF]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.water_level = func(x, _z): return 10.5 if x > 100.0 else NAN          # a pond east of x 100: shallow to x 150, deep beyond
	a.blocked = func(x, _z): return x > 150.0                               # deep water (over 0.7 m)
	a.player_positions = func(): return []
	a.player_stances = func(): return []
	a.hour_now = func(): return 12.0
	a.weather_ahead = func(_h): return {}
	a.setup()
	a.traits = false
	a.ice_cover_at = func(_p): return cover[0]
	a.ice_moat_at = func(p): return p.x > moat_from_x[0]
	var deer: Dictionary = a.species_def("deer")
	var wolf: Dictionary = a.species_def("wolf")
	var ic: Dictionary = a._ice_cfg()

	check(not bool(ic.get("on", true)) and not a.ice_on(), "ice for animals ships off")
	ic["on"] = true

	# Deer and boar skirt the ice, even the shallows they would wade.
	cover[0] = 0.14   # the starter pond's skim, 2.8 cm
	a._ice_cache.clear()
	var deer_blocked: Callable = a.ice_moves(deer, "deer")[1]
	var boar_blocked: Callable = a.ice_moves(a.species_def("boar"), "boar")[1]
	check(bool(deer_blocked.call(120.0, 0.0)) and bool(boar_blocked.call(120.0, 0.0)), "a deer and a boar keep off skim ice in the shallows")
	check(not bool(deer_blocked.call(50.0, 0.0)), "dry land is still open to them")
	cover[0] = 0.0
	a._ice_cache.clear()
	check(not bool(a.ice_moves(deer, "deer")[1].call(120.0, 0.0)), "open shallows: a deer wades as before")

	# Jamie #736: ice holds an animal for sure when mass kg <= 0.9 h^2 (h cm). Starter skim (2.8 cm) holds a fox (6 kg), not a wolf (40 kg).
	cover[0] = 0.14
	a._ice_cache.clear()
	check(not bool(a.ice_moves(a.species_def("fox"), "fox")[1].call(200.0, 0.0)), "2.8 cm holds a fox over deep water")
	check(bool(a.ice_moves(wolf, "wolf")[1].call(200.0, 0.0)), "2.8 cm does not hold a wolf")
	check(a.ice_holds(200.0, 0.0, 40.0) == false and a.ice_holds(200.0, 0.0, 6.0), "ice_holds: 0.9 x 2.8^2 = 7.1 kg")

	# Wolves cross a 12 cm sheet (holds 130 kg), at the water's surface; 6 cm (32 kg) over deep water still blocks them.
	cover[0] = 0.6
	a._ice_cache.clear()
	var wolf_moves: Array = a.ice_moves(wolf, "wolf")
	check(not bool(wolf_moves[1].call(200.0, 0.0)) and absf(float(wolf_moves[0].call(200.0, 0.0)) - 10.5) < 0.01, "a wolf walks on a 12 cm sheet over deep water, at its surface")
	cover[0] = 0.3
	a._ice_cache.clear()
	check(bool(a.ice_moves(wolf, "wolf")[1].call(200.0, 0.0)), "6 cm over deep water does not bear a wolf")

	# A thaw moat is open water.
	cover[0] = 0.6
	a._ice_cache.clear()
	moat_from_x[0] = 188.0   # off the 4 m search grid: the edge at 190 is the first open step
	check(bool(a.ice_moves(wolf, "wolf")[1].call(200.0, 0.0)), "the thaw moat stops a wolf as open water does")

	# A water flock on a frozen pond stands at the edge of the open water (here the moat east of x 188), or does not settle.
	var spot: Vector2 = a.ice_edge_spot(150.0, 0.0, "duck")
	check(spot.x > 185.0 and spot.x < 195.0, "a flock on the ice stands at the open water's edge (x %.0f)" % spot.x)
	moat_from_x[0] = INF
	check(a.ice_edge_spot(150.0, 0.0, "duck").x == INF, "a pond frozen all over has no flock")
	a.spring_ice_x = func(p): return 0.0 if p.x > 170.0 else 1.0   # the open brook below a spring, east of x 170
	var by_spring: Vector2 = a.ice_edge_spot(150.0, 0.0, "duck")
	check(by_spring.x > 165.0 and by_spring.x < 175.0, "the flock gathers at the open water below a spring (x %.0f)" % by_spring.x)
	cover[0] = 0.6
	a._ice_cache.clear()
	check(bool(a.ice_moves(wolf, "wolf")[1].call(200.0, 0.0)), "a wolf does not walk on the open brook below a spring")
	a.spring_ice_x = Callable()
	cover[0] = 0.0
	a._ice_cache.clear()
	check(a.ice_edge_spot(150.0, 0.0, "duck") == Vector2(150.0, 0.0), "open water: the flock floats where it was")

	# The players' side: the moat is not ice, and the holes go out nearest first, live ones only.
	var items = ItemsScript.new()
	items.game_seconds = func(): return 1000.0
	items.ice_cover_at = func(_p): return 0.6
	items.water_near = func(_p, _r): return true
	check(items._on_ice(Vector3(5.0, 0.0, 0.0)), "a 12 cm sheet is ice to stand on")
	items.spring_ice_x = func(_p): return 0.5
	check(not items._on_ice(Vector3(5.0, 0.0, 0.0)), "near a spring mouth the 12 cm sheet counts as 6 cm: not ice to stand on (#739)")
	items.spring_ice_x = Callable()
	items.ice_moat_at = func(_p): return true
	check(not items._on_ice(Vector3(5.0, 0.0, 0.0)), "the thaw moat is open water to a player")
	items._holes = [{"pos": Vector3(30.0, 0.0, 0.0), "owner": "a", "until": 5000.0}, {"pos": Vector3(10.0, 0.0, 0.0), "owner": "b", "until": 4000.0},
		{"pos": Vector3(5.0, 0.0, 0.0), "owner": "c", "until": 900.0}, {"pos": Vector3(500.0, 0.0, 0.0), "owner": "d", "until": 9000.0}]
	var rows: Array = items.ice_holes_near(Vector3.ZERO)
	check(rows[0].size() == 2 and rows[0][0].x == 10.0 and rows[0][1].x == 30.0 and is_equal_approx(rows[1][0], 4000.0), "live holes within 120 m, nearest first, with their closing time (%s)" % str(rows))

	print("animals on ice: %d failures" % failures)
	quit(1 if failures > 0 else 0)
