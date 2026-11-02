extends SceneTree

# Wall-of-water probe (Sonny, 2 Nov 2026): lists every river cell of tile 3,4 that test_river_surface counts as "water more than 4 m above its bank",
# grouped within 40 m, and for each group says whether the water drops there (a fall or dam) or not (a suspect). fall_scan lists only the top single drops.
#   godot --headless --path . --script res://tools/river_wall_probe.gd -- [--world=DIR] [--x=55776 --z=67952] [--drop=1.0]
# --x/--z (optional): also print the nearest group to that world point. A group is "fall/dam" when some wet cell in it has a wet cell 1 to 3 cells
# (8 to 24 m) away whose level is lower by --drop (default 1.0 m).

const TF := preload("res://src/worldgen/tile/tile_file.gd")
const WS := preload("res://src/water/water_store.gd")

const WET_M := 0.12
const X0 := 46080.0
const Z0 := 61440.0


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var drop_min: float = 1.0
	var probes: Array = []
	var px: float = NAN

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			world = argument.trim_prefix("--world=")
		elif argument.begins_with("--drop="):
			drop_min = float(argument.trim_prefix("--drop="))
		elif argument.begins_with("--x="):
			px = float(argument.trim_prefix("--x="))
		elif argument.begins_with("--z=") and not is_nan(px):
			probes.append(Vector2(px, float(argument.trim_prefix("--z="))))
			px = NAN

	var path: String = world + "/tiles/tile_3_4.tile"
	var header = TF.read_header(path)
	var n: int = int(header["header"]["samples"])
	var ground = TF.decode_height(TF.read_section(path, header["table"], "height")["raw"], TF.height_step_of(header["header"]))
	var cls = TF.read_section(path, header["table"], "water_class")["raw"]
	var depth = WS.load_depth(world + "/water/tile_3_4.water", n)
	var cells: Array = []   # [index, wall_m, drop_m]

	for j in range(1, n - 1):
		for i in range(1, n - 1):
			var k: int = j * n + i

			if cls[k] != 3 or depth[k] < WET_M:
				continue

			var wall: float = 0.0

			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var m: int = (j + step.y) * n + i + step.x

				if depth[m] < 0.01 and cls[m] != 1 and ground[m] > 0.0:
					wall = maxf(wall, ground[k] + depth[k] - ground[m])

			if wall <= 4.0:
				continue

			var level: float = ground[k] + depth[k]
			var drop: float = 0.0

			for dj in range(-3, 4):
				for di in range(-3, 4):
					var ni: int = i + di
					var nj: int = j + dj

					if ni < 0 or nj < 0 or ni >= n or nj >= n or (di == 0 and dj == 0):
						continue

					var q: int = nj * n + ni

					if depth[q] >= WET_M:
						drop = maxf(drop, level - (ground[q] + depth[q]))

			cells.append([k, wall, drop])

	# Group within 40 m (greedy by order).
	var groups: Array = []   # {at: Vector2, cells, wall, drop}

	for c in cells:
		@warning_ignore("integer_division")
		var at: Vector2 = Vector2(X0 + float(int(c[0]) % n) * 8.0, Z0 + float(int(c[0]) / n) * 8.0)
		var placed: bool = false

		for g in groups:
			if (g["at"] as Vector2).distance_to(at) <= 40.0:
				g["cells"] += 1
				g["wall"] = maxf(g["wall"], float(c[1]))
				g["drop"] = maxf(g["drop"], float(c[2]))
				placed = true
				break

		if not placed:
			groups.append({"at": at, "cells": 1, "wall": float(c[1]), "drop": float(c[2])})

	var suspects: int = 0
	print("%d wall cells in %d groups (fall/dam = water drops at least %.1f m within 24 m)" % [cells.size(), groups.size(), drop_min])

	for g in groups:
		var ok: bool = g["drop"] >= drop_min

		if not ok:
			suspects += 1

		print("group at x%.0f z%.0f: %d cells, wall up to %.1f m, water drops %.2f m nearby -> %s" % [g["at"].x, g["at"].y, g["cells"], g["wall"], g["drop"], "fall/dam" if ok else "SUSPECT"])

	for p in probes:
		var best: float = INF
		var which: Dictionary = {}

		for g in groups:
			var d: float = (g["at"] as Vector2).distance_to(p)

			if d < best:
				best = d
				which = g

		if which.is_empty():
			print("probe %s: no wall groups at all" % str(p))
		else:
			print("probe x%.0f z%.0f: nearest group %.0f m away at x%.0f z%.0f, drop %.2f m -> %s" % [p.x, p.y, best, which["at"].x, which["at"].y, which["drop"], "fall/dam" if which["drop"] >= drop_min else "SUSPECT"])

	print("suspect groups: %d" % suspects)
	quit(0)
