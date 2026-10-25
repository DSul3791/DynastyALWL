extends SceneTree
const TF := preload("res://src/worldgen/tile/tile_file.gd")
const WS := preload("res://src/water/water_store.gd")
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var head: Dictionary = TF.read_header(a[0])
	var h = TF.decode_height(TF.read_section(a[0], head["table"], "height")["raw"])
	var w: PackedByteArray = TF.read_section(a[0], head["table"], "water_class")["raw"]
	var side: int = int(round(sqrt(float(h.size()))))
	var depth: PackedFloat32Array = WS.load_depth(a[1], side)
	var seen := PackedByteArray(); seen.resize(side * side)
	var res: Array = []
	for i in range(side * side):
		if seen[i] == 1 or not (w[i] == 2 or depth[i] >= 1.0) or depth[i] <= 0.05: continue
		var st: Array = [i]; seen[i] = 1; var n := 0; var sx := 0.0; var sz := 0.0; var md := 0.0; var gmin := 1e9
		while st.size() > 0:
			var j: int = st.pop_back(); n += 1
			var jr: int = j / side; var jc: int = j % side
			sx += jc; sz += jr; md = max(md, depth[j]); gmin = min(gmin, h[j])
			for d in [[1,0],[-1,0],[0,1],[0,-1]]:
				var nr: int = jr + d[0]; var nc: int = jc + d[1]
				if nr < 0 or nr >= side or nc < 0 or nc >= side: continue
				var k: int = nr * side + nc
				if seen[k] == 0 and depth[k] > 0.05 and (w[k] == 2 or depth[k] >= 1.0): seen[k] = 1; st.append(k)
		if n * 0.0064 >= 1.0:
			res.append([n * 0.0064, 46080 + sx / n * 8.0, 61440 + sz / n * 8.0, md, gmin])
	res.sort_custom(func(x, y): return x[0] > y[0])
	for r in res: print("body %.1f ha centre x %d z %d max depth %.1f m surface-ish height %.1f" % [r[0], r[1], r[2], r[3], r[4]])
	quit()
