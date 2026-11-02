extends SceneTree

# Writes the rock under the nine island tiles for the offline erosion model (tools/erosion_precarve), on the same 32 m grid it uses. Read-only.
# Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/export_geology.gd -- --out=C:/some/folder
#
# Options: --out=DIR; --tiles=X0,Z0,X1,Z1 (default 2,3,4,5); --step=M grid spacing (default 32); --world=DIR.
# Writes geology.json (rock erodibility by id; per province: datum, cycle, repeat, base rock, layers [rock, top, bottom]; grid size and origin)
# and geology_province.u8, geology_surface.f32 (province datum plus fold offset, metres), geology_granite.f32 and geology_basalt.f32
# (top of an intrusion or vent over each cell, -1e9 where none). All grids are n x n, row-major, rows along +z.
# The rock at height y over a cell: depth = surface - y; depth under 0 is the first layer; depth over repeat is the base rock; else the layer at
# fmod(depth, cycle). Limestone below marble_depth becomes marble. Same rule as TileGeology.layer_at.

const TileBakerScript := preload("res://src/worldgen/tile/tile_baker.gd")
const TileGeologyScript := preload("res://src/worldgen/tile/tile_geology.gd")


func _init() -> void:
	var out_dir: String = "user://geology"
	var rect: Array = [2, 3, 4, 5]
	var step: float = 32.0
	var world_dir: String = "res://worlds/base_world"

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument.begins_with("--tiles="):
			rect = []

			for part in argument.trim_prefix("--tiles=").split(","):
				rect.append(int(part))
		elif argument.begins_with("--step="):
			step = float(argument.trim_prefix("--step="))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")

	quit(_run(world_dir, out_dir, rect, step))


func _run(world_dir: String, out_dir: String, rect: Array, step: float) -> int:
	var baker = TileBakerScript.new()
	var problem: String = baker.setup(world_dir, 0.0)

	if problem != "":
		push_error(problem)
		return 1

	var tile_m: float = float(baker.settings.tile_size_m)
	var x0: float = float(rect[0]) * tile_m
	var z0: float = float(rect[1]) * tile_m
	var n: int = int(round(float(rect[2] - rect[0] + 1) * tile_m / step)) + 1
	var geology = TileGeologyScript.new()
	geology.setup(baker.settings, baker.tile_rules, baker.tables, baker.elevation, baker.sketch)
	geology.spacing_m = step
	geology.prepare_frame(x0, z0, n)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var surface: PackedFloat32Array = PackedFloat32Array()
	surface.resize(n * n)

	for k in range(n * n):
		surface[k] = geology._p_datum[geology.province[k]] + float(geology.layer_offset[k]) * 0.1

	_write("%s/geology_province.u8" % out_dir, geology.province)
	_write("%s/geology_surface.f32" % out_dir, surface.to_byte_array())
	_write("%s/geology_granite.f32" % out_dir, _clean(geology._granite_top).to_byte_array())
	_write("%s/geology_basalt.f32" % out_dir, _clean(geology._basalt_top).to_byte_array())
	var rocks: Dictionary = {}

	for entry in baker.tables.get_entries("rocks"):
		rocks[str(entry["id"])] = {"name": str(entry["name"]), "erodibility": float(entry.get("erodibility", 1.0))}

	var provinces: Array = []

	for p in range(geology.provinces.size()):
		var layers: Array = []

		for k in range(geology._p_rocks[p].size()):
			layers.append([int(geology._p_rocks[p][k]), float(geology._p_tops[p][k]), float(geology._p_bottoms[p][k])])

		provinces.append({
			"kind": str(geology.provinces[p]["kind"]), "datum": float(geology._p_datum[p]), "cycle": float(geology._p_cycle[p]),
			"repeat": float(geology._p_repeat[p]), "base": int(geology._p_base[p]), "marble_depth": minf(float(geology._p_marble_depth[p]), 1.0e9), "layers": layers,
		})

	var info: Dictionary = {"n": n, "step_m": step, "x0_m": x0, "z0_m": z0, "rocks": rocks, "provinces": provinces, "marble_id": geology._rock_ids["marble"], "limestone_id": geology._rock_ids["limestone"]}
	var file := FileAccess.open("%s/geology.json" % out_dir, FileAccess.WRITE)
	file.store_string(JSON.stringify(info, "\t"))
	file.close()
	print("geology exported: %d x %d cells of %.0f m, %d provinces" % [n, n, step, provinces.size()])
	return 0


func _clean(values: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = values.duplicate()

	for k in range(out.size()):
		if out[k] < -1.0e8:
			out[k] = -1.0e9

	return out


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
