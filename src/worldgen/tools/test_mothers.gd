extends SceneTree

# Mothers with young by species (docs/design/ANIMAL_SCENARIOS.md gap 12): a deer or black bear mother whose young a player has come
# between mostly bluffs (young.bluff_share); a moose presses home every time. A hider's young (deer) drops and lies still when its
# mother runs, then goes back to her; a follower's young (moose) runs at her side.
#   godot --headless --path . --script res://src/worldgen/tools/test_mothers.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var players: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players.map(func(p): return p["pos"])
	a.season_now = func(): return "spring"
	a.setup()
	a.traits = true
	a.rng.seed = 21

	for sp in a.cfg["species"]:
		a.cfg["species"][sp]["target_per_player"] = 0

	a.big_game.player_info = func(): return players
	a.big_game.hurt_player = func(_peer, _amount, _lethal, _cause, _from): return "hurt"
	return a


# A mother of `kind` with young; true when it spawned with them.
func mother(a, kind: String) -> Dictionary:
	for _n in 60:
		var id: int = a.spawn(kind, 0.0, 0.0)

		if not a._young_of(a.animals[id]).is_empty():
			return a.animals[id]

		a.animals.clear()

	return {}


func _initialize() -> void:
	# 1. Bluff or real: of 40 charges for its young, a deer mother bluffs most, a moose none.
	for kind in ["deer", "moose", "black_bear"]:
		var bluffs: int = 0

		for n in 40:
			var a = make()
			a.rng.seed = 100 + n
			var m: Dictionary = mother(a, kind)
			var kid: Dictionary = a.animals[a._young_of(m)[0]]
			players = [{"peer": 1, "pos": kid["pos"] + Vector3(1.0, 0.0, 0.0), "stance": 0, "hp": 1.0}]
			var pp: Vector3 = players[0]["pos"]
			a._step(m, 0.1, m["pos"].distance_to(pp), pp, m["pos"].distance_to(pp), pp)

			if int(m["state"]) != a.WARN:
				continue

			for _s in 60:
				a.big_game.step(m, 0.05)

				if int(m["state"]) == a.WARN + 1:
					break

			bluffs += 1 if bool(m.get("bluff", false)) else 0

		var share: float = float(bluffs) / 40.0

		if kind == "moose":
			check(bluffs == 0, "a moose mother never bluffs for her calf (%d of 40)" % bluffs)
		else:
			check(share >= 0.6, "a %s mother mostly bluffs for her young (%d of 40)" % [kind, bluffs])

	# 2. Hide or follow: the mother runs; a fawn lies still where it was, a moose calf runs with her.
	for kind in ["deer", "moose"]:
		var a = make()
		var m: Dictionary = mother(a, kind)
		var kid: Dictionary = a.animals[a._young_of(m)[0]]
		var kid_at: Vector3 = kid["pos"]
		players = [{"peer": 1, "pos": Vector3(-30.0, 10.0, 0.0), "stance": 0, "hp": 1.0}]
		a._bolt(m, players[0]["pos"], a.species_def(kind))

		for _n in 20:
			a._step_young(kid, 0.1)
			m["pos"] += Vector3(1.0, 0.0, 0.0)   # she runs off

		var moved: float = kid["pos"].distance_to(kid_at)

		if kind == "deer":
			check(moved < 0.5 and a._wire_state_now(kid) == a.LIE, "a fawn lies still where it was when its mother runs (moved %.1f m, state %d)" % [moved, a._wire_state_now(kid)])
			m["state"] = a.GRAZE

			for _n in 40:
				a._step_young(kid, 0.1)

			check(not kid.has("hiding") and kid["pos"].distance_to(kid_at) > 1.0, "and goes back to her once she is calm")
		else:
			check(moved > 1.0, "a moose calf runs at its mother's side (moved %.1f m)" % moved)

	print("test_mothers: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
