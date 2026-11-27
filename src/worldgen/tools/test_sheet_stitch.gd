extends SceneTree

# Two chunk sheets meet without a seam (LiquidSurface.stitch, BugsList 157: 0.38 m of level and a 0.25 m lift apart at x 57856): the later sheet takes
# the neighbour's edge texels exactly, fades the difference inward, and a coarse sheet is first spread to its fine neighbour's size.
#   godot --headless --path . --script res://src/worldgen/tools/test_sheet_stitch.gd

const LiquidSurface := preload("res://src/water2/liquid_surface.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _flat(side: int, level: float, speed: float) -> Image:
	var im: Image = Image.create(side, side, false, Image.FORMAT_RGBAF)
	im.fill(Color(level, speed, 0.0, 1.0))
	return im


func _initialize() -> void:
	var west: Image = _flat(17, 1.65, 1.6)                       # the earlier sheet, its east edge at column 16
	var east: Image = _flat(17, 1.27, 0.3)
	east = LiquidSurface.stitch(east, Vector2i(-1, 0), west)      # the west neighbour lies at -x
	var worst: float = 0.0

	for t in range(17):
		worst = maxf(worst, absf(east.get_pixel(0, t).r - west.get_pixel(16, t).r) + absf(east.get_pixel(0, t).g - west.get_pixel(16, t).g))

	check(worst < 0.0001, "the shared edge is the same on both sheets (worst %.4f)" % worst)
	var inward: Array = [east.get_pixel(1, 8).r, east.get_pixel(2, 8).r, east.get_pixel(3, 8).r, east.get_pixel(4, 8).r]
	check(inward[0] > inward[1] and inward[1] > inward[2] and absf(inward[3] - 1.27) < 0.0001, "the difference fades out inward %s" % str(inward))

	var coarse: Image = _flat(5, 1.0, 0.0)
	var fine: Image = _flat(17, 1.0, 0.0)

	for t in range(17):
		fine.set_pixel(t, 0, Color(1.0 + 0.1 * float(t % 2), 0.0, 0.0, 1.0))  # a bumpy fine edge, row 0 = its north side

	var joined: Image = LiquidSurface.stitch(coarse, Vector2i(0, 1), fine)  # the fine sheet lies south (+z): its row 0 meets our last row
	check(joined.get_width() == 17, "a coarse sheet is spread to its fine neighbour's size (%d)" % joined.get_width())
	var bumps: float = 0.0

	for t in range(17):
		bumps = maxf(bumps, absf(joined.get_pixel(t, 16).r - fine.get_pixel(t, 0).r))

	check(bumps < 0.0001, "every fine vertex on the edge is matched (worst %.4f)" % bumps)
	check(LiquidSurface.stitch(east, Vector2i(1, 0), null) == east, "no neighbour drawn: the sheet is unchanged")
	print("sheet stitch: %d failures" % failures)
	quit(1 if failures > 0 else 0)
