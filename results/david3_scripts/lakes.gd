extends SceneTree
const TF := preload("res://src/worldgen/tile/tile_file.gd")
const WS := preload("res://src/water/water_store.gd")
func comps(mask: PackedByteArray, side: int, r0: int, r1: int) -> Array:
	var seen := PackedByteArray(); seen.resize(mask.size())
	var out: Array = []
	for r in range(r0, r1 + 1):
		for c in range(side):
			var i: int = r * side + c
			if mask[i] == 0 or seen[i] == 1: continue
			var n: int = 0; var st: Array = [i]; seen[i] = 1
			while st.size() > 0:
				var j: int = st.pop_back(); n += 1
				var jr: int = j / side; var jc: int = j % side
				for d in [[1,0],[-1,0],[0,1],[0,-1]]:
					var nr: int = jr + d[0]; var nc: int = jc + d[1]
					if nr < r0 or nr > r1 or nc < 0 or nc >= side: continue
					var k: int = nr * side + nc
					if mask[k] == 1 and seen[k] == 0: seen[k] = 1; st.append(k)
			out.append(n)
	return out
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var head: Dictionary = TF.read_header(a[0])
	var h = TF.decode_height(TF.read_section(a[0], head["table"], "height")["raw"])
	var w: PackedByteArray = TF.read_section(a[0], head["table"], "water_class")["raw"]
	var side: int = int(round(sqrt(float(h.size()))))
	var depth: PackedFloat32Array = WS.load_depth(a[1], side)
	var lake := PackedByteArray(); lake.resize(side * side)
	var wet := PackedByteArray(); wet.resize(side * side)
	var wetn := 0
	for i in range(side * side):
		if depth[i] > 0.05:
			wet[i] = 1; wetn += 1
			if w[i] == 2 or depth[i] >= 1.0: lake[i] = 1
	var cs: Array = comps(lake, side, 0, side - 1)
	var big: Array = cs.filter(func(n): return n * 64.0 / 10000.0 >= 0.5)
	var ha := 0.0
	for n in big: ha += n * 64.0 / 10000.0
	print("lake bodies (class lake, wet >0.05 m): %d total; >=0.5 ha: %d, %.1f ha" % [cs.size(), big.size(), ha])
	var sizes := big.map(func(n): return snappedf(n * 64.0 / 10000.0, 0.1)); sizes.sort(); print("sizes ha: ", sizes)
	print("all wet cells: %d (%.1f ha)" % [wetn, wetn * 0.0064])
	var r0: int = int((75053.0 - 4 * 15360) / 8.0); var r1: int = int((75780.0 - 4 * 15360) / 8.0)
	var rc: Array = comps(wet, side, r0, r1)
	print("window z75053-75780 (rows %d-%d): %d wet pieces, cells: %s" % [r0, r1, rc.size(), str(rc.max()) + " biggest"])
	quit()
