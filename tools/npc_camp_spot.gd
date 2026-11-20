extends SceneTree

# Edda and Hob's camp under a tree (Dave 17 Nov 2026: "move EDDA and Hob under the nearest big tree and give them a large campfire that players
# cannot access ... just inside the shelter line of the tree so the rain doesnt effect it"; he picked the tree beside x 53283 z 68083 and asked for
# "the fire infront of the tree. put hob on the left side of the tree and edda on the right side of the tree both facing the fire").
# Prints the standing trees near a point from the real flora placer (species, foot, height, the crown circle the Cover index shelters, trunk), and for
# the nearest one tall enough to shelter (Cover.SHELTER_MIN_HEIGHT_M) the camp spots data/npcs/camp.json wants: the fire `inside` metres inside the
# crown circle on the front side (toward the viewer looking along `bearing`, compass degrees, 0 north -z, 90 east +x), Hob `side` metres to the
# viewer's left and Edda to the right, each `fwd` metres toward the fire, turned to face it; with the trees and shrubs near each spot.
#   godot --headless --path . --script res://tools/npc_camp_spot.gd -- [--x=53283 --z=68083 --bearing=214 --inside=1.0 --side=2.0 --fwd=1.0 --reach=12]
# --reach: how far from the point to look for the tree (m); the 40 nearest trees and shrubs are listed.

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const CoverScript := preload("res://src/shared/cover.gd")


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var args: Dictionary = {"x": 53283.0, "z": 68083.0, "bearing": 214.0, "inside": 1.0, "side": 2.0, "fwd": 1.0, "reach": 12.0}

	for argument in OS.get_cmdline_user_args():
		for key in args:
			if argument.begins_with("--%s=" % key):
				args[key] = float(argument.trim_prefix("--%s=" % key))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var at: Vector2 = Vector2(float(args["x"]), float(args["z"]))
	var reach: float = float(args["reach"])   # how far from the point to look for trees and shrubs (m)
	var index = CoverScript.Index.new()
	var flora: Array = []   # [species row, Vector3 foot, height]
	var lo: Vector2i = placer.chunk_of(at.x - reach - 40.0, at.y - reach - 40.0)
	var hi: Vector2i = placer.chunk_of(at.x + reach + 40.0, at.y + reach + 40.0)

	for ci in range(lo.x, hi.x + 1):
		for cj in range(lo.y, hi.y + 1):
			var made: Dictionary = placer.chunk_items(Vector2i(ci, cj))
			CoverScript.add_chunk(index, Vector2i(ci, cj), made, func(species_id: int) -> Array:   # as server_flora._fill_cover
				var item: Dictionary = placer.species_by_id(species_id)
				return [] if item.is_empty() else [int(item["kind"]), float(item["crown"]), float(item["height_ref"]), CoverScript.is_deciduous(str(item.get("name", "")))])

			for n in range(made["ids"].size()):
				var row: Dictionary = placer.species_of(made["ids"][n])

				if not row.is_empty() and int(row["kind"]) != PlacerScript.KIND_PLANT:   # plants are no collider and give no shelter
					flora.append([row, made["positions"][n], float(made["heights"][n])])

	flora.sort_custom(func(a, b): return Vector2(a[1].x, a[1].z).distance_to(at) < Vector2(b[1].x, b[1].z).distance_to(at))
	print("trees and shrubs within %.0f m of %.1f, %.1f, nearest first (40 at most):" % [reach, at.x, at.y])
	var shown: int = 0
	var tree: Array = []

	for f in flora:
		var d: float = Vector2(f[1].x, f[1].z).distance_to(at)

		if d > reach:
			break

		var row: Dictionary = f[0]
		var crown_r: float = CoverScript.crown_radius(float(row["crown"]), float(row["height_ref"]), float(f[2])) if int(row["kind"]) == PlacerScript.KIND_TREE else 0.0
		var shelters: bool = int(row["kind"]) == PlacerScript.KIND_TREE and float(f[2]) >= CoverScript.SHELTER_MIN_HEIGHT_M
		if shown < 40:
			print("  %-16s %-5s foot %.2f, %.2f, %.2f  %.1f m away  height %.1f m  trunk_m %.2f  shelter circle %.2f m%s%s" % [str(row["name"]), PlacerScript.KINDS[int(row["kind"])], f[1].x, f[1].y, f[1].z, d, float(f[2]), float(row.get("trunk", 0.0)), crown_r, "" if shelters else "  (no shelter)", "  deciduous (bare in winter)" if CoverScript.is_deciduous(str(row["name"])) else ""])
			shown += 1

		if tree.is_empty() and shelters:
			tree = [row, f[1], f[2], crown_r]

		if not tree.is_empty() and shown >= 40:
			break

	if tree.is_empty():
		print("no sheltering tree within %.0f m" % reach)
		quit(1)
		return

	var foot: Vector3 = tree[1]
	var turn: float = deg_to_rad(float(args["bearing"]))
	var view: Vector2 = Vector2(sin(turn), -cos(turn))         # the way the viewer looks, across the ground (x, z)
	var front: Vector2 = -view                            # from the trunk toward the viewer
	var left: Vector2 = Vector2(view.y, -view.x)          # the viewer's left (view turned a quarter anticlockwise seen from above, north -z)
	var trunk: Vector2 = Vector2(foot.x, foot.z)
	var fire: Vector2 = trunk + front * (float(tree[3]) - float(args["inside"]))
	var hob: Vector2 = trunk + left * float(args["side"]) + front * float(args["fwd"])
	var edda: Vector2 = trunk - left * float(args["side"]) + front * float(args["fwd"])
	print("camp tree: %s at %.2f, %.2f (height %.1f m, shelter circle %.2f m)" % [str(tree[0]["name"]), foot.x, foot.z, float(tree[2]), float(tree[3])])

	for spot in [["fire", fire], ["hob", hob], ["edda", edda]]:
		var p: Vector2 = spot[1]
		var y: float = foot.y
		var covered: bool = index.covers(Vector3(p.x, y + 0.3, p.y))
		var near: Array = []

		for f in flora:
			var d: float = Vector2(f[1].x, f[1].z).distance_to(p)

			if d <= 1.5 and int(f[0]["kind"]) != PlacerScript.KIND_PLANT:
				near.append("%s %.1f m" % [str(f[0]["name"]), d])

		var face: float = rad_to_deg(atan2(fire.y - p.y, fire.x - p.x))   # server_npcs heading: atan2(dz, dx) (Steering)
		print("  %-4s x %.2f z %.2f  covered %s  yaw %.0f  trees or shrubs within 1.5 m: %s" % [spot[0], p.x, p.y, str(covered), face, ", ".join(near) if not near.is_empty() else "none"])

	quit(0)
