extends SceneTree
# A cell that flickers on and off between water updates stays drawn until it has been dry 4 updates in a row (WaterGrid.steady_edges).
const WG := preload("res://src/worldgen/runtime/water_grid.gd")
func mk(a: Array) -> Dictionary:
	var l := PackedFloat32Array(a)
	var w := 0
	for v in l: if not is_nan(v): w += 1
	return {"count": 2, "levels": l, "wet": w}
func _init():
	var n := NAN
	# cell 0 flickers: on, off, on, off, on, on, on, off x4
	var seq := [[1.0,2.0,2.0,2.0],[n,2.0,2.0,2.0],[1.0,2.0,2.0,2.0],[n,2.0,2.0,2.0],[1.0,2.0,2.0,2.0],[1.0,2.0,2.0,2.0],[n,2.0,2.0,2.0],[n,2.0,2.0,2.0],[n,2.0,2.0,2.0],[n,2.0,2.0,2.0]]
	var cur := mk(seq[0]); var out := ""
	for s in seq.slice(1):
		var nw := mk(s)
		WG.steady_edges(cur, nw)
		out += ("1" if not is_nan(nw["levels"][0]) else "0")
		cur = nw
	print("water steady: ", "ok" if out == "111111110" else "FAIL " + out)
	quit(0 if out == "111111110" else 1)
