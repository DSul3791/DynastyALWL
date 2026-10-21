extends SceneTree

# NPC daily routines (Radar, 2026-10-21): every schedule is a full day of known packages with enough sleep, every package has a
# marker kind that exists with enough places for the cast, and rain sends outdoor work to shelter.
#   godot --headless --path . --script res://src/worldgen/tools/test_npc_routines.gd

const NpcsScript := preload("res://src/stream/server_npcs.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/npcs.json"))
	var markers: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/markers.json"))
	var places: Dictionary = {}   # marker kind -> total slots

	for m in markers["markers"]:
		places[str(m["kind"])] = int(places.get(str(m["kind"]), 0)) + int(m["slots"])

	for pkg in cfg["packages"]:
		check(places.has(str(cfg["packages"][pkg]["marker"])), "package %s has markers of kind %s" % [pkg, cfg["packages"][pkg]["marker"]])

	for hour in 24:
		var wanted: Dictionary = {}

		for npc in cfg["npcs"]:
			check((npc["schedule"] as Array).size() == 24, "%s has 24 slots" % npc["id"])
			var pkg: String = str(npc["schedule"][hour])
			check(cfg["packages"].has(pkg), "%s slot %d names a known package (%s)" % [npc["id"], hour, pkg])
			var kind: String = str(cfg["packages"].get(pkg, {}).get("marker", ""))
			wanted[kind] = int(wanted.get(kind, 0)) + 1

		for kind in wanted:
			check(int(wanted[kind]) <= int(places.get(kind, 0)), "hour %d: %d NPCs want %s and there are %d places" % [hour, wanted[kind], kind, places.get(kind, 0)])

	for npc in cfg["npcs"]:
		var sleep: int = 0

		for pkg in npc["schedule"]:
			sleep += 1 if str(pkg) == "sleep" else 0

		check(sleep >= 6 and sleep <= 10, "%s sleeps 6 to 10 hours (%d)" % [npc["id"], sleep])

	# Rain: Hob at his post at noon walks to a shelter marker, and goes back when it clears.
	var npcs = NpcsScript.new()
	NpcsScript.test_hold_off = true
	var hour: Array = [10.0]
	var rain: Array = [0.0]
	npcs.hour_now = func(): return hour[0]
	npcs.ground_height = func(_x, _z): return 10.0
	npcs.rain_now = func(): return rain[0]
	npcs.player_positions = func(): return [Vector3(53300.0, 10.0, 68426.0)]
	npcs.setup("")
	var hob: Dictionary = npcs.npcs["hob"]
	check(npcs.package_of(hob, 10.0) == "work", "dry: Hob works at ten")
	rain[0] = 0.8
	check(npcs.package_of(hob, 10.0) == "shelter", "wet: Hob goes under cover")
	check(npcs.package_of(hob, 3.0) == "sleep", "wet at three in the morning he still sleeps")
	rain[0] = 0.1
	check(npcs.package_of(hob, 10.0) == "work", "light rain does not move him")
	print("npc routines: %d failures" % failures)
	quit()
