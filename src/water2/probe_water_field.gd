extends SceneTree

# Dynasty water stage a: cost and pictures (Sonny, 31 Oct 2026). Prints ms per simulated second for a river on a big field, and saves top-down pictures.
#   godot --headless --path . --script res://src/water2/probe_water_field.gd -- [--out=res://src/water2/art]

const Field := preload("res://src/water2/water_field.gd")


func _init() -> void:
	var out: String = "res://src/water2/art"

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	_cost(256)
	_cost(512)
	_pictures(out)
	quit(0)


# A 4 percent valley across a field of n x n cells (8 m cells), a spring at the top, open end: the water covers a thin strip, the rest sleeps.
func _valley(n: int, cell: float) -> Array:
	var bed: PackedFloat32Array = PackedFloat32Array()
	bed.resize(n * n)
	var mid: int = n / 2

	for j in range(n):
		for i in range(n):
			var across: float = absf(float(j - mid)) * cell
			bed[j * n + i] = 30.0 - 0.04 * cell * float(i) + minf(across * across * 0.01, 25.0)

	var f = Field.new(n, n, cell, bed)
	f.open_edges = true
	f.add_spring(2, mid, 4.0)
	return [f, bed]


func _cost(n: int) -> void:
	var f = _valley(n, 8.0)[0]
	var t0: int = Time.get_ticks_usec()

	for s in range(120):
		f.step(1.0)

	var warm: int = Time.get_ticks_usec()
	var cells: int = 0
	var steps: int = 20

	for s in range(steps):
		f.step(1.0)
		cells += f.cells_stepped

	var us: int = Time.get_ticks_usec() - warm
	print("field %dx%d: %.1f ms per simulated second, %d cells visited per second of %d, awake blocks %d of %d, filling took %.1f s" % [n, n, float(us) / 1000.0 / steps, cells / steps, n * n, f.awake_blocks(), (n / 16) * (n / 16), float(warm - t0) / 1.0e6])


func _pictures(out: String) -> void:
	# river down a valley: depth as blue, speed as brightness of white
	var pair: Array = _valley(128, 8.0)
	var f = pair[0]

	for s in range(600):
		f.step(1.0)

	var im: Image = Image.create(f.w * 4, f.h * 4, false, Image.FORMAT_RGB8)

	for j in range(f.h):
		for i in range(f.w):
			var k: int = j * f.w + i
			var land: float = clampf((f.bed[k] - 4.0) / 28.0, 0.0, 1.0)
			var col: Color = Color(0.25 + 0.4 * land, 0.35 + 0.3 * land, 0.2 + 0.2 * land)

			if f.depth[k] > 0.01:
				var v: float = f.velocity(i, j).length()
				col = Color(0.1, 0.3, 0.55).lerp(Color(0.9, 0.97, 1.0), clampf(v / 3.0, 0.0, 1.0)).darkened(clampf(0.4 - f.depth[k] * 0.5, 0.0, 0.4))

			for dy in range(4):
				for dx in range(4):
					im.set_pixel(i * 4 + dx, j * 4 + dy, col)

	print("river picture ", im.save_png(ProjectSettings.globalize_path(out + "/river_valley.png")))

	# dam break frames on a flat floor: depth shaded, at 0, 4, 12, 40 s
	var bed: PackedFloat32Array = PackedFloat32Array()
	bed.resize(96 * 96)
	var d = Field.new(96, 96, 2.0, bed)

	for j in range(40, 56):
		for i in range(40, 56):
			d.add_water(i, j, 2.0)

	var strip: Image = Image.create(96 * 4 * 4, 96 * 4, false, Image.FORMAT_RGB8)
	var frame: int = 0

	for at in [0.0, 4.0, 12.0, 40.0]:
		d.step(at - d.time_s if at > d.time_s else 0.0)

		for j in range(96):
			for i in range(96):
				var depth: float = d.depth[j * 96 + i]
				var col: Color = Color(0.15, 0.18, 0.12) if depth < 0.01 else Color(0.8, 0.95, 1.0).lerp(Color(0.05, 0.25, 0.55), clampf(depth / 1.2, 0.0, 1.0))

				for dy in range(4):
					for dx in range(4):
						strip.set_pixel(frame * 96 * 4 + i * 4 + dx, j * 4 + dy, col)

		frame += 1

	print("dam break picture ", strip.save_png(ProjectSettings.globalize_path(out + "/dam_break_0_4_12_40s.png")))
