extends SceneTree

# Picture (Sonny, 30 Oct 2026) for WATER_PLAN.md: the nine baked tiles (2..4 by 3..5, 15 km each) from above, as the game read them in build 826 (left: 0.125 m height step, sea at 0 m)
# and as they were baked (right: 0.1 m step). Blue = ground below the sea (darker deeper), green to white = land by height, a red dot where Dave stood (x 51689, z 65076).
#   godot --headless --path . --script res://tools/water_coast_picture.gd

const TileFile := preload("res://src/worldgen/tile/tile_file.gd")
const TILE_M := 15360.0


func _color(h: float) -> Color:
	if h < 0.0:
		var t: float = clampf(-h / 2000.0, 0.0, 1.0)
		return Color(0.1, 0.35, 0.65).lerp(Color(0.02, 0.07, 0.25), t)

	var u: float = clampf(h / 1400.0, 0.0, 1.0)
	return Color(0.25, 0.55, 0.22).lerp(Color(0.55, 0.45, 0.3), clampf(u * 2.0, 0.0, 1.0)).lerp(Color(0.95, 0.95, 0.95), clampf(u * 2.0 - 1.0, 0.0, 1.0))


func _initialize() -> void:
	var n: int = 481
	var side: int = n * 3
	var wrong: Image = Image.create(side, side, false, Image.FORMAT_RGB8)
	var right: Image = Image.create(side, side, false, Image.FORMAT_RGB8)

	for tx in range(2, 5):
		for tz in range(3, 6):
			var path: String = "res://worlds/base_world/tiles/tile_%d_%d.tile" % [tx, tz]
			var head: Dictionary = TileFile.read_header(path)
			var raw: PackedByteArray = TileFile.read_section(path, head["table"], "low_height")["raw"]
			var h_wrong: PackedFloat32Array = TileFile.decode_height(raw)
			var h_right: PackedFloat32Array = TileFile.decode_height(raw, TileFile.height_step_of(head["header"]))

			for z in range(n):
				for x in range(n):
					var i: int = z * n + x
					wrong.set_pixel((tx - 2) * n + x, (tz - 3) * n + z, _color(h_wrong[i]))
					right.set_pixel((tx - 2) * n + x, (tz - 3) * n + z, _color(h_right[i]))

	# Dave's position: x 51689, z 65076 -> tile 3,4 local (5609, 3636) at 32 m per sample.
	var dx: int = int((3 - 2) * n + 5609.0 / 32.0)
	var dz: int = int((4 - 3) * n + 3636.0 / 32.0)

	for image in [wrong, right]:
		for oz in range(-5, 6):
			for ox in range(-5, 6):
				if ox * ox + oz * oz <= 25:
					image.set_pixel(dx + ox, dz + oz, Color(1, 0.1, 0.1))

	var both: Image = Image.create(side * 2 + 20, side, false, Image.FORMAT_RGB8)
	both.fill(Color(0, 0, 0))
	both.blit_rect(wrong, Rect2i(0, 0, side, side), Vector2i(0, 0))
	both.blit_rect(right, Rect2i(0, 0, side, side), Vector2i(side + 20, 0))
	both.save_jpg(ProjectSettings.globalize_path("res://art/water/coast_read_wrong_vs_right.jpg"), 0.88)
	print("saved ", both.get_size())
	quit(0)
