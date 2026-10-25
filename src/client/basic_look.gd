extends RefCounted

# Stage-one models (Kathleen, art/MODEL_PLAN.md): any loose item drawn from a small shape and a colour, so every item has a look before
# any item gets a good one. `data/items/looks.json` maps an item id to {shape, color, size}; `mesh()` returns one vertex-coloured ArrayMesh
# (a few hundred triangles, 1200 at most for a bowl of stew, one shared material) centred on its middle with the underside near y = -0.06 * size. Upgrading an item later means
# deleting its looks.json entry or giving it a real model; nothing here changes.

const LOOKS_PATH := "res://data/items/looks.json"

static var _table: Dictionary = {}
static var _loaded: bool = false
static var _material: StandardMaterial3D
static var _metal_mats: Dictionary = {}


# The looks table, read once: item id -> {shape, color, size}. A missing or broken file means no entries (everything keeps its old look).
static func entry(item_id: String) -> Dictionary:
	if not _loaded:
		_loaded = true
		var file: FileAccess = FileAccess.open(LOOKS_PATH, FileAccess.READ)

		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())

			if parsed is Dictionary:
				_table = parsed.get("items", {})

	return _table.get(item_id, {})


static func has_look(item_id: String) -> bool:
	return not entry(item_id).is_empty()


static func mesh_for(item_id: String) -> Mesh:
	var def: Dictionary = entry(item_id)

	if def.is_empty():
		return null

	return mesh(str(def.get("shape", "chunk")), Color.html(str(def.get("color", "#8a8a8a"))), float(def.get("size", 1.0)), def.get("bits", []))


static func mesh(shape: String, color: Color, size: float = 1.0, bits: Array = []) -> ArrayMesh:
	var parts: Array = []

	if shape not in ["bone", "coil", "coin", "ingot"]:
		color = Color.from_hsv(color.h, minf(color.s * 1.35, 1.0), minf(color.v * 1.08, 1.0))      # bolder colours so loose items tell apart on the grass (Dave 2026-10-22)
	var dark: Color = color.darkened(0.35)
	var light: Color = color.lightened(0.25)

	match shape:
		"sack":
			_sph(parts, 0.1, Vector3(1.0, 1.1, 1.0), Vector3(0.0, 0.0, 0.0), color)
			_cyl(parts, 0.04, 0.05, Vector3(0.0, 0.11, 0.0), Vector3.ZERO, dark)
		"backpack":
			# A hide rucksack: tall rounded body, a flap over the top with a buckle, two side pockets, two shoulder straps, a bedroll on top.
			_sph(parts, 0.12, Vector3(1.0, 1.25, 0.7), Vector3(0.0, 0.0, 0.0), color)
			_sph(parts, 0.12, Vector3(1.05, 0.5, 0.78), Vector3(0.0, 0.1, 0.0), dark)
			_box(parts, Vector3(0.03, 0.04, 0.012), Vector3(0.0, 0.03, -0.1), Color(0.85, 0.75, 0.3))
			_sph(parts, 0.05, Vector3(0.8, 1.0, 0.8), Vector3(0.12, -0.05, 0.0), dark)
			_sph(parts, 0.05, Vector3(0.8, 1.0, 0.8), Vector3(-0.12, -0.05, 0.0), dark)
			_cyl(parts, 0.032, 0.22, Vector3(0.0, 0.2, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.35, 0.3, 0.22))   # bedroll
			_box(parts, Vector3(0.03, 0.22, 0.01), Vector3(0.05, 0.0, 0.085), dark)
			_box(parts, Vector3(0.03, 0.22, 0.01), Vector3(-0.05, 0.0, 0.085), dark)
		"fibre":
			# A hank of plant fibre: a fan of long fine strands, frayed at both ends, tied in the middle with a twist of cord.
			for k in 14:
				var spread: float = (float(k) - 6.5) * 0.007
				var bend: float = (float(k % 3) - 1.0) * 0.05
				_box_rot(parts, Vector3(0.34 + 0.02 * float(k % 4), 0.004, 0.006), Vector3(0.0, 0.004 * float(k % 5), spread), Vector3(0.0, bend, 0.0), color.lightened(0.07 * float(k % 3)) if k % 2 == 0 else color.darkened(0.08))
			_cyl(parts, 0.04, 0.02, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), Color(0.45, 0.36, 0.2))
		"bar":
			# A trail-mix bar: a bar of oats and syrup with nuts, raisins, seeds and dried fruit pressed into it.
			_box(parts, Vector3(0.2, 0.035, 0.07), Vector3(0.0, -0.04, 0.0), color)
			for k in bits.size() * 3:
				var at: Vector3 = Vector3(-0.08 + 0.027 * float(k % 7), -0.018, -0.025 + 0.025 * float(k % 3))
				_sph(parts, 0.016, Vector3(1.0, 0.8, 1.0), at, Color.html(str(bits[k % bits.size()])))
		"joint":
			# A roast joint on the bone: a browned, glazed lump of meat with the bone showing at each end.
			_sph(parts, 0.1, Vector3(1.3, 0.8, 0.9), Vector3(0.0, -0.02, 0.0), color)
			_sph(parts, 0.06, Vector3(1.2, 0.5, 0.8), Vector3(0.0, 0.03, 0.0), color.lightened(0.15))
			_cyl(parts, 0.014, 0.12, Vector3(-0.17, -0.02, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.9, 0.87, 0.78))
			_sph(parts, 0.025, Vector3.ONE, Vector3(-0.23, -0.02, 0.015), Color(0.9, 0.87, 0.78))
			_sph(parts, 0.025, Vector3.ONE, Vector3(-0.23, -0.02, -0.015), Color(0.9, 0.87, 0.78))
			_cyl(parts, 0.014, 0.1, Vector3(0.16, -0.02, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.9, 0.87, 0.78))
		"ingot":
			_box(parts, Vector3(0.24, 0.05, 0.1), Vector3(0.0, -0.035, 0.0), color)
			_box(parts, Vector3(0.2, 0.03, 0.07), Vector3(0.0, 0.0, 0.0), light)
		"block":
			# A cut stone block, 2:1:1, with a chiselled lighter top.
			_box(parts, Vector3(0.2, 0.1, 0.1), Vector3(0.0, -0.02, 0.0), color)
			_box(parts, Vector3(0.18, 0.012, 0.08), Vector3(0.0, 0.034, 0.0), light)
		"brick":
			# A fired brick, about 3:1.4:1, with a paler top face.
			_box(parts, Vector3(0.15, 0.05, 0.07), Vector3(0.0, -0.02, 0.0), color)
			_box(parts, Vector3(0.13, 0.008, 0.055), Vector3(0.0, 0.009, 0.0), light)
		"pile":
			_sph(parts, 0.15, Vector3(1.0, 0.45, 1.0), Vector3(0.0, -0.03, 0.0), color)
			_sph(parts, 0.06, Vector3(1.0, 0.7, 1.0), Vector3(0.07, 0.03, 0.03), light)
			_sph(parts, 0.05, Vector3(1.0, 0.7, 1.0), Vector3(-0.06, 0.02, -0.05), dark)
		"clump":
			# A fist-sized clump of earth (soil, clay): a few lumpy chunks pressed together in two shades, a few crumbs round the foot.
			var lumps: Array = [[0.0, 0.0, 0.0, 0.034, 0.8], [0.035, 0.0, 0.012, 0.026, 0.7], [-0.03, 0.0, 0.02, 0.028, 0.75], [0.008, 0.0, -0.034, 0.027, 0.7],
				[-0.022, 0.0, -0.024, 0.022, 0.8], [0.014, 0.024, 0.006, 0.024, 0.8], [-0.012, 0.022, 0.014, 0.02, 0.85]]

			for k in range(lumps.size()):
				var l: Array = lumps[k]
				var shade: Color = [color, dark, color.lightened(0.1), color.darkened(0.15), color.lightened(0.05)][k % 5]
				_sph(parts, float(l[3]), Vector3(1.0 + 0.12 * float(k % 3), float(l[4]), 1.0 - 0.1 * float(k % 2)), Vector3(float(l[0]), float(l[1]) - 0.015, float(l[2])), shade)

			for k in range(7):
				var a: float = float(k) * 2.4 + 0.5
				var r: float = 0.05 + 0.012 * float(k % 3)
				_sph(parts, 0.007 + 0.002 * float(k % 2), Vector3(1.0, 0.7, 1.0), Vector3(cos(a) * r, -0.026, sin(a) * r), dark if k % 2 == 0 else color)
		"grit":
			# A handful of sand or gravel: a low scatter of small grains or stones, no smooth dome.
			var stones: int = 34
			var gravel: bool = color.get_luminance() < 0.6

			if not gravel:
				_sph(parts, 0.05, Vector3(1.0, 0.18, 1.0), Vector3(0.0, -0.024, 0.0), color.darkened(0.1))

			for k in range(stones):
				var a: float = float(k) * 2.4
				var r: float = 0.01 + 0.045 * sqrt(float(k) / float(stones))
				var grain: float = (0.008 + 0.004 * float((k * 7) % 4)) if gravel else (0.006 + 0.002 * float((k * 5) % 3))
				var shade: Color = [color, dark, light, color.darkened(0.12), color.lightened(0.08)][(k * 3) % 5]
				var at: Vector3 = Vector3(cos(a) * r, -0.026 + grain * 0.5 + (0.012 if k < 6 else 0.0), sin(a) * r)

				if gravel:
					_box_rot(parts, Vector3(grain * 2.0, grain * 1.3, grain * 1.7), at, Vector3(float(k) * 0.7, float(k) * 1.3, float(k) * 0.4), shade)
				else:
					_sph(parts, grain, Vector3(1.0, 0.6, 1.0), at, shade)
		"chunk":
			_sph(parts, 0.08, Vector3(1.0, 0.8, 1.1), Vector3(0.0, -0.02, 0.0), color)
			_sph(parts, 0.055, Vector3(1.0, 0.8, 1.0), Vector3(0.08, -0.03, 0.04), dark)
			_sph(parts, 0.05, Vector3(1.0, 0.9, 1.0), Vector3(-0.05, -0.02, 0.07), light)
		"bundle":
			_cyl(parts, 0.055, 0.34, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), color)
			_cyl(parts, 0.06, 0.03, Vector3(-0.07, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), dark)
			_cyl(parts, 0.06, 0.03, Vector3(0.07, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), dark)
		"planks":
			for k in 4:
				_box(parts, Vector3(0.5, 0.025, 0.13), Vector3(0.01 * float(k % 2), -0.04 + 0.028 * float(k), 0.0), color.lightened(0.04 * float(k % 2)))
		"beams":
			_box(parts, Vector3(0.55, 0.07, 0.07), Vector3(0.0, -0.035, -0.04), color)
			_box(parts, Vector3(0.55, 0.07, 0.07), Vector3(0.0, -0.035, 0.04), dark)
			_box(parts, Vector3(0.55, 0.07, 0.07), Vector3(0.0, 0.035, 0.0), color.lightened(0.05))
		"hide":
			_sph(parts, 0.17, Vector3(1.0, 0.08, 0.75), Vector3(0.0, -0.05, 0.0), color)
			_sph(parts, 0.1, Vector3(1.0, 0.09, 0.6), Vector3(0.04, -0.03, 0.0), dark)
		"net":
			# A shore net, folded: a flat round of crossing twine strands (a grid of thin bars) with a ring of small stone weights round the rim.
			for k in 9:
				var off: float = (float(k) - 4.0) * 0.022
				_box(parts, Vector3(0.2, 0.006, 0.006), Vector3(0.0, -0.02, off), color)
				_box(parts, Vector3(0.006, 0.006, 0.2), Vector3(off, -0.02, 0.0), dark)

			for k in 10:
				var a: float = TAU * float(k) / 10.0
				_sph(parts, 0.014, Vector3(1.0, 0.8, 1.0), Vector3(cos(a) * 0.1, -0.015, sin(a) * 0.1), light)
		"basket":
			# A stick basket: a round open pot of woven sticks, three darker weave bands and a rim, a loop handle of one bent stick.
			_cyl(parts, 0.09, 0.14, Vector3(0.0, 0.0, 0.0), Vector3.ZERO, color)
			_cyl(parts, 0.075, 0.13, Vector3(0.0, 0.012, 0.0), Vector3.ZERO, dark)
			_torus(parts, 0.09, 0.012, Vector3(0.0, 0.07, 0.0), light)

			for k in 3:
				_torus(parts, 0.09, 0.008, Vector3(0.0, -0.045 + 0.045 * float(k), 0.0), dark)

			_torus(parts, 0.07, 0.01, Vector3(0.0, 0.09, 0.0), color)
		"coil":
			_torus(parts, 0.07, 0.02, Vector3(0.0, -0.03, 0.0), color)
			_torus(parts, 0.07, 0.02, Vector3(0.0, 0.0, 0.0), dark)
		"bone":
			_cyl(parts, 0.018, 0.22, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), color)
			_sph(parts, 0.035, Vector3.ONE, Vector3(-0.11, 0.0, 0.015), color)
			_sph(parts, 0.035, Vector3.ONE, Vector3(-0.11, 0.0, -0.015), color)
			_sph(parts, 0.035, Vector3.ONE, Vector3(0.11, 0.0, 0.015), color)
			_sph(parts, 0.035, Vector3.ONE, Vector3(0.11, 0.0, -0.015), color)
		"feather":
			_box(parts, Vector3(0.22, 0.006, 0.06), Vector3(0.0, -0.05, 0.0), color)
			_box(parts, Vector3(0.24, 0.01, 0.008), Vector3(0.0, -0.045, 0.0), dark)
		"bark":
			_box(parts, Vector3(0.3, 0.02, 0.16), Vector3(0.0, -0.04, 0.0), color)
			_box(parts, Vector3(0.3, 0.02, 0.05), Vector3(0.0, -0.025, 0.06), dark)
		"leaves":
			_sph(parts, 0.13, Vector3(1.0, 0.35, 1.0), Vector3(0.0, -0.04, 0.0), color)
			_sph(parts, 0.09, Vector3(1.0, 0.4, 1.0), Vector3(0.03, 0.0, -0.02), light)
		"bottle":
			_cyl(parts, 0.045, 0.14, Vector3(0.0, -0.01, 0.0), Vector3.ZERO, color)
			_cyl(parts, 0.02, 0.07, Vector3(0.0, 0.095, 0.0), Vector3.ZERO, color)
			_cyl(parts, 0.022, 0.025, Vector3(0.0, 0.14, 0.0), Vector3.ZERO, dark)
		"loaf":
			_sph(parts, 0.1, Vector3(1.3, 0.55, 0.8), Vector3(0.0, -0.025, 0.0), color)
			_sph(parts, 0.07, Vector3(1.2, 0.3, 0.6), Vector3(0.0, 0.01, 0.0), light)
		"fruit":
			_sph(parts, 0.07, Vector3(1.0, 0.9, 1.0), Vector3(0.0, -0.01, 0.0), color)
			_cyl(parts, 0.006, 0.04, Vector3(0.0, 0.055, 0.0), Vector3.ZERO, Color(0.3, 0.22, 0.12))
		"round_berries":
			# Wild blueberries (Dave's photos): a handful of round dusky-blue berries, each with a small dark star crown on top.
			var round_spots: Array = [[0.0, 0.0, 0.0], [0.03, 0.0, 0.0], [-0.03, 0.0, 0.0], [0.0, 0.0, 0.03], [0.0, 0.0, -0.03], [0.022, 0.0, 0.024], [-0.022, 0.0, 0.024], [0.022, 0.0, -0.024], [-0.022, 0.0, -0.024], [0.0, 0.03, 0.0], [0.016, 0.028, 0.012], [-0.016, 0.028, -0.012]]

			for spot in round_spots:
				var at: Vector3 = Vector3(float(spot[0]), float(spot[1]) + 0.02, float(spot[2]))
				_sph(parts, 0.018, Vector3.ONE, at, color)
				_sph(parts, 0.006, Vector3(1.0, 0.5, 1.0), at + Vector3(0.0, 0.016, 0.0), color.darkened(0.55))
		"berries":
			# A raspberry: a red dome of small round drupelets in rings, a few unripe yellow-green ones, a green cap of sepals on top.
			var ring: Array = [[0.0, 0.0, 1], [0.026, 0.016, 6], [0.04, -0.004, 9]]

			for row in ring:
				for k in range(int(row[2])):
					var a: float = TAU * float(k) / float(maxi(int(row[2]), 1)) + float(row[0]) * 40.0
					var unripe: bool = (k * 5 + int(row[2])) % 11 == 0
					_sph(parts, 0.016, Vector3.ONE, Vector3(cos(a) * float(row[0]), float(row[1]) + 0.012, sin(a) * float(row[0])), Color(0.85, 0.8, 0.35) if unripe else color)

			_sph(parts, 0.03, Vector3(1.0, 0.25, 1.0), Vector3(0.0, 0.052, 0.0), Color(0.3, 0.45, 0.2))
		"bowl":
			_bowl(parts, color)
		"stew":
			_bowl(parts, Color(0.5, 0.34, 0.19))      # one shared wooden bowl under every soup and stew (Dave 2026-10-22)
			_fill(parts, color, bits, false)
		"mound":
			_bowl(parts, Color(0.5, 0.34, 0.19))
			_fill(parts, color, bits, true)
		"fish":
			_sph(parts, 0.09, Vector3(1.9, 0.6, 0.55), Vector3(0.0, -0.03, 0.0), color)
			_box(parts, Vector3(0.07, 0.012, 0.09), Vector3(0.2, -0.03, 0.0), dark)
			_sph(parts, 0.07, Vector3(1.6, 0.3, 0.5), Vector3(0.0, -0.05, 0.0), light)
		"meat":
			_sph(parts, 0.09, Vector3(1.2, 0.7, 0.9), Vector3(0.0, -0.02, 0.0), color)
			_sph(parts, 0.05, Vector3(1.0, 0.8, 1.0), Vector3(0.07, 0.0, 0.03), dark)
			_cyl(parts, 0.012, 0.09, Vector3(-0.1, -0.02, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.88, 0.85, 0.78))
		"skewer":
			_cyl(parts, 0.008, 0.4, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), Color(0.4, 0.28, 0.16))

			for k in 3:
				_sph(parts, 0.04, Vector3.ONE, Vector3(-0.09 + 0.09 * float(k), 0.0, 0.0), color if k != 1 else dark)
		"coin":
			_cyl(parts, 0.035, 0.008, Vector3(0.0, -0.05, 0.0), Vector3.ZERO, color)
			_cyl(parts, 0.027, 0.01, Vector3(0.0, -0.05, 0.0), Vector3.ZERO, light)
		"cloth":
			_box(parts, Vector3(0.26, 0.04, 0.2), Vector3(0.0, -0.04, 0.0), color)
			_box(parts, Vector3(0.22, 0.03, 0.16), Vector3(0.01, -0.005, 0.0), light)
			_box(parts, Vector3(0.18, 0.025, 0.12), Vector3(0.0, 0.02, 0.0), color)
		"shaft":
			# A spear (Dave: it must be pointy): an ash shaft with a slight taper and a leather grip wrap. The wooden spear has a whittled, fire-hardened point of the same wood (darker tip);
			# the iron-headed spear (bits "metal") has a socket cone bound to the shaft and a flat leaf blade with a midrib, ending in a sharp point. Mesh axes: shaft along x, point at +x.
			var ash_spear: Color = Color(0.38, 0.25, 0.12)
			var metal_head: bool = bits.has("metal")
			_cyl_taper(parts, 0.0175, 0.0165, 0.45, Vector3(-0.225, 0.0, 0.0), _tone(ash_spear, 1, 0.08))
			_cyl_taper(parts, 0.0165, 0.0155, 0.45, Vector3(0.225, 0.0, 0.0), _tone(ash_spear, 2, 0.08))
			for k in range(3):                                                                                       # a leather grip wrap
				_cyl(parts, 0.0195, 0.014, Vector3(-0.08 + 0.02 * float(k), 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5 + 0.25), Color(0.1, 0.05, 0.025) if k != 1 else Color(0.16, 0.09, 0.045))

			if metal_head:
				var iron_head: Color = Color(0.2, 0.19, 0.17)
				_cyl_taper(parts, 0.0165, 0.024, 0.1, Vector3(0.5, 0.0, 0.0), iron_head * 0.8)                       # the socket cone
				_metal(parts, 0.5, 0.5)
				_plate(parts, 0.545, 0.3, 0.07, 0, 12, iron_head * 1.35, true, true, 0.5, 0.5, Transform3D.IDENTITY, 3)   # a flat leaf blade with a ridge down the middle (the midrib) and a sharp point
				for k in range(5):                                                                                   # the twine binding below the socket: slanted turns in two tones, a visible wrap
					_cyl(parts, 0.0245, 0.014, Vector3(0.43 + 0.012 * float(k), 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5 + 0.35), Color(0.55, 0.4, 0.18) if k % 2 == 0 else Color(0.34, 0.24, 0.1))
			else:
				var stops: Array = [[0.45, 0.58, 0.0155, 0.0112, 0.1], [0.58, 0.7, 0.0112, 0.0062, 0.25], [0.7, 0.8, 0.0062, 0.0022, 0.42], [0.8, 0.84, 0.0022, 0.0004, 0.58]]   # the whittled point, darkening softly to a fire-hardened tip
				for stop in stops:
					_cyl_taper(parts, stop[2], stop[3], stop[1] - stop[0], Vector3(0.5 * (stop[0] + stop[1]), 0.0, 0.0), ash_spear.darkened(stop[4]))
		"axe":
			# A hafted stone axe (modelled on a real hafted stone felling axe, Dave 2026-10-25: tools to the pickaxe standard): a straight ash haft with weathered grain and a swollen
			# head end, a knapped stone wedge head lashed into it, thick at the poll and ground to a sharp edge that flares wider than the body, one chipped corner, and
			# five cross-lashing bands of leather thong either side of the head. Mesh axes: haft along x (grip at -x), head at x = 0.22, edge toward +z.
			color = _warm_stone(color)                                                                              # darker and warmer: in sunlight the plain grey read pale blue
			dark = color.darkened(0.3)
			light = color.lightened(0.18)
			var haft_wood: Color = Color(0.3, 0.2, 0.11)
			var thong: Color = Color(0.3, 0.17, 0.09)
			for k in range(10):                                                                                      # weathered grain along the haft
				_cyl(parts, 0.021, 0.05, Vector3(-0.25 + 0.05 * float(k) + 0.025, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), _tone(haft_wood, k, 0.06))
			_cyl(parts, 0.027, 0.1, Vector3(0.2, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), _tone(haft_wood, 2, 0.1))   # the haft swells where the head sits
			_box(parts, Vector3(0.09, 0.065, 0.065), Vector3(0.22, 0.0, 0.0), _tone(dark, 1, 0.12))                 # the poll block the wedge sits on
			_wedge(parts, 0.065, 0.15, 0.115, Vector3(0.22, 0.0, 0.05), _tone(color, 4, 0.08))                      # the wedge: base 6.5 cm, 15 cm out, 11.5 cm of edge
			_wedge(parts, 0.026, 0.055, 0.15, Vector3(0.225, 0.0, 0.1), light)                                     # the ground edge, flared wider than the body
			_box_rot(parts, Vector3(0.03, 0.03, 0.035), Vector3(0.285, 0.0, 0.12), Vector3(0.0, 0.5, 0.0), dark)  # a chipped corner
			for k in range(5):                                                                                       # leather thong lashing, five turns each side of the head
				_cyl(parts, 0.034, 0.012, Vector3(0.155 + 0.014 * float(k), 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), thong if k % 2 == 0 else thong.darkened(0.25))
				_cyl(parts, 0.034, 0.012, Vector3(0.262 + 0.014 * float(k), 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), thong if k % 2 == 1 else thong.darkened(0.25))
		"pick":
			# A pickaxe (Dave's reference rendering), mesh axes: haft along x (pommel at -x, head at x = 0.27), head along z. One straight iron head with both ends
			# curving toward the grip (-x, the pommel end, as in Dave's reference) in the haft-and-head plane: a long tapering pick at +z, a shorter flat-ended chisel at -z.
			# Nothing bends sideways (out of that plane). Held with the head vertical (points up and down); see HELD_LOOK_TURN.
			# Test: src/worldgen/tools/test_pick_axes.gd.
			var steel_head: bool = bits.has("steel")
			var iron: Color = Color(0.085, 0.09, 0.1) if steel_head else Color(0.034, 0.036, 0.042)   # metallic charcoal, grey-black gunmetal (steel a lighter charcoal); vertex colours are linear, so these read as sRGB ~(85,88,95) and ~(52,54,59) on screen
			var wood: Color = Color(0.3, 0.2, 0.11)
			var leather: Color = Color(0.3, 0.17, 0.09)
			for k in range(12):                                                                                              # weathered grain: the haft in twelve slightly different tones
				_cyl(parts, 0.02, 0.05, Vector3(-0.33 + 0.05 * float(k) + 0.025, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), _tone(wood, k, 0.12))
			_cyl(parts, 0.03, 0.07, Vector3(-0.3, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), _tone(wood, 3, 0.1))              # the flared pommel
			for k in range(8):                                                                                               # the leather grip wrap: alternating bound bands
				_cyl(parts, 0.0235, 0.02, Vector3(-0.27 + 0.02 * float(k) + 0.01, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), _tone(leather, k, 0.22) if k % 2 == 0 else leather.darkened(0.3))
			_cyl(parts, 0.027, 0.012, Vector3(-0.115, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), leather.darkened(0.2))  # its top band
			_box(parts, Vector3(0.075, 0.06, 0.085), Vector3(0.27, 0.0, 0.0), iron * 0.75)                    # the iron eye block the haft passes into
			_metal(parts)
			_box(parts, Vector3(0.02, 0.04, 0.04), Vector3(0.315, 0.0, 0.0), _tone(wood, 5, 0.1))                      # the haft's end, standing proud of the head
			for k in range(3):                                                                                               # the collar's leather lashing, three turns
				_cyl(parts, 0.028, 0.01, Vector3(0.2 + 0.014 * float(k), 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), leather if k != 1 else leather.darkened(0.25))
			_cyl(parts, 0.026, 0.01, Vector3(0.18, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), leather.darkened(0.2))
			var sweeps: Array = [[1.0, 0.28, 0.9, 10], [-1.0, 0.3, 0.72, 6]]                                             # side, sweep (rad), radius, segments: the long pick and the short chisel (twice the old segment count, same outline)
			for side in sweeps:
				var dir: float = side[0]
				var count: int = side[3]
				for seg in range(count):
					var t: float = float(seg) / float(count)
					var phi0: float = side[1] * t
					var phi1: float = side[1] * float(seg + 1) / float(count)
					var mid: float = 0.5 * (phi0 + phi1)
					var thick: float = 0.045 * (1.0 - t * 0.8) + 0.004 if dir > 0.0 else 0.04 - 0.008 * t
					var length: float = side[2] * (phi1 - phi0) * 1.06
					var at: Vector3 = Vector3(0.27 - side[2] * (1.0 - cos(mid)), 0.0, dir * (0.04 + side[2] * sin(mid)))
					var tone: Color = _tone_mul(iron, seg + (0 if dir > 0.0 else 7), 0.3)                                     # hammered, pitted: each segment a little lighter or darker
					if seg >= count - 2:
						tone = tone * 1.45                                                                              # the worked, bright points and edge
					_box_rot(parts, Vector3(thick, thick, length), at, Vector3(0.0, -dir * mid, 0.0), tone)
					_metal(parts)
			if steel_head:
				_box(parts, Vector3(0.012, 0.012, 0.12), Vector3(0.302, 0.0, 0.0), iron * 1.7)                  # steel: a polished ridge along the top of the head
				_metal(parts)
				_cyl(parts, 0.032, 0.012, Vector3(0.245, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.72, 0.58, 0.22))   # and a brass band
		"spade":
			# A digging spade at real size for the large tier (size 1.0; the smaller tiers scale down): a 3.2 cm ash haft, a leather sleeve at the grip, a rounded D-grip loop about 15 by 10 cm
			# and 3 cm thick in the haft's own grain, a short socket cone with a rolled collar fused to a 28 by 19 cm blade plate (a real polygon plate, see _plate: square shoulders, rounded
			# tip, dished, turned-up side lips, a rolled lip along the top) and flat rivets. Mesh axes: haft along x (grip at -x, blade at +x), blade thin in y, wide in z.
			# Iron and steel (bits "metal") are on the metal surface: iron roughness 0.65 / metallic 0.3, steel a little shinier (0.45 / 0.45) but neutral grey, not blue.
			var metal_blade: bool = bits.has("metal")
			var steel_blade: bool = bits.has("steel")
			var blade: Color = color
			var ash: Color = Color(0.38, 0.24, 0.11)                                                                 # warm ash
			var rough: float = 0.3 if steel_blade else 0.65
			var sheen: float = 0.6 if steel_blade else 0.3

			if metal_blade:
				blade = Color(0.26, 0.25, 0.225) if steel_blade else Color(0.11, 0.1, 0.082)                  # steel: neutral mid-grey (about sRGB 137); iron: dark charcoal (about 89); linear values
			elif absf(color.r - color.b) < 0.1:
				blade = Color(0.19, 0.16, 0.115)                                                               # stone: matt grey-brown
			else:
				blade = ash.darkened(0.15)                                                                      # wood: the same ash as the haft, a little darker

			var g: float = 0.12                                                                                     # the grip's flat side; the whole spade is about 0.8 m
			var cuts: Array = [0.0, 0.3, 0.5]                                                      # the haft in uneven lengths: subtle grain-like tone changes, no hard seam
			for k in range(2):
				var x0: float = g + cuts[k] * (0.45 - g) / 0.5
				var x1: float = g + cuts[k + 1] * (0.45 - g) / 0.5
				_cyl_taper(parts, 0.0165 - 0.0007 * cuts[k] / 0.5, 0.0165 - 0.0007 * cuts[k + 1] / 0.5, x1 - x0, Vector3(0.5 * (x0 + x1), 0.0, 0.0), _tone(ash, 1 + k * 3, 0.11))
			for k in range(2):                                                                                       # a leather sleeve: three thin turns near the grip
				_cyl(parts, 0.0182, 0.012, Vector3(g + 0.09 + 0.016 * float(k), 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5 + 0.25), Color(0.1, 0.05, 0.025) if k != 1 else Color(0.16, 0.09, 0.045))

			var d_points: Array = []                                                                                 # the D-grip path in x and z: flat against the haft end, a half ellipse behind
			for k in range(9):
				var ang: float = -PI * 0.5 + PI * float(k) / 8.0
				d_points.append(Vector2(g - 0.1 * cos(ang), 0.075 * sin(ang)))

			for k in range(8):
				_tube(parts, d_points[k], d_points[k + 1], 0.012, _tone(ash, 6, 0.04), 8)
			_tube(parts, Vector2(g, -0.075), Vector2(g, 0.075), 0.009, _tone(ash, 6, 0.04), 8)                       # the flat side, against the haft

			_cyl_taper(parts, 0.02, 0.034, 0.06, Vector3(0.41, 0.0, 0.0), blade * 1.2 if metal_blade else ash.darkened(0.3))   # a short socket cone
			if metal_blade:
				_metal(parts, rough, sheen)
			_cyl(parts, 0.045, 0.014, Vector3(0.437, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), blade * 1.5 if metal_blade else Color(0.16, 0.09, 0.045))   # a raised round collar at the socket mouth
			if metal_blade:
				_metal(parts, rough, sheen)
			_plate(parts, 0.44, 0.3, 0.2, 0, 12, blade, true, metal_blade, rough, sheen)                             # the blade plate, 30 by 20 cm, one piece with a symmetric arched tip
			_box(parts, Vector3(0.03, 0.01, 0.17), Vector3(0.46, 0.013, 0.0), blade * 1.5 if metal_blade else Color(0.16, 0.09, 0.045))   # the step plate across the shoulders (a leather strap on wood and stone)
			if metal_blade:
				_metal(parts, rough, sheen)
			for side in [-1.0, 1.0]:
				_sph(parts, 0.007, Vector3(1.0, 0.5, 1.0), Vector3(0.46, 0.019, side * 0.05), blade * 1.5 if metal_blade else Color(0.08, 0.05, 0.03), true)   # two round domed rivets
				if metal_blade:
					_metal(parts, rough, sheen)
		"saw":
			# A hand saw (modelled on a real panel saw): an ash pistol grip with a closed finger hole at -x, attached to the blade through a brass plate with three rivets (no gap), a thin
			# neutral-grey blade plate 50 cm long, 14 cm at the heel tapering to 5 cm at a rounded toe, a thin dark spine along the top (-z) and a row of fine teeth along the cutting edge (+z).
			var steel_blade: Color = Color(0.3, 0.285, 0.25)
			var grip_wood: Color = Color(0.38, 0.25, 0.13)
			var brass: Color = Color(0.13, 0.115, 0.1)
			_box(parts, Vector3(0.025, 0.026, 0.13), Vector3(-0.3, 0.0, 0.0), _tone(grip_wood, 1, 0.1))                 # the rear of the grip, the bar the hand closes round
			_box(parts, Vector3(0.14, 0.026, 0.025), Vector3(-0.23, 0.0, -0.052), _tone(grip_wood, 2, 0.1))             # the top bar
			_box(parts, Vector3(0.14, 0.026, 0.025), Vector3(-0.23, 0.0, 0.052), _tone(grip_wood, 3, 0.1))              # the bottom bar, closing the finger hole against the blade
			_box(parts, Vector3(0.05, 0.007, 0.13), Vector3(-0.165, 0.0, 0.0), brass)                                    # the brass plate the grip is riveted to the blade through
			for k in range(3):
				_sph(parts, 0.008, Vector3.ONE, Vector3(-0.18 + 0.014 * float(k), 0.006, 0.0), brass.lightened(0.3), true)   # brass rivets
			_plate(parts, -0.17, 0.5, 0.14, 0, 12, steel_blade, true, true, 0.65, 0.3, Transform3D(Basis.IDENTITY, Vector3.ZERO), 2)
			_box_rot(parts, Vector3(0.5, 0.007, 0.007), Vector3(0.08, 0.0, -0.0475), Vector3(0.0, -0.09, 0.0), Color(0.07, 0.07, 0.07))   # a thin dark spine along the top
			_metal(parts, 0.65, 0.3)
			for k in range(28):                                                                                       # fine teeth along the cutting edge
				var t: float = (float(k) + 0.5) / 30.0
				_wedge(parts, 0.006, 0.012, 0.0155, Vector3(-0.17 + 0.5 * t, 0.0, 0.07 * (1.0 - 0.64 * t) + 0.0055), steel_blade * 1.3)
				_metal(parts, 0.65, 0.3)
		"hammer":
			# A hafted hammer (modelled on a real stone club hammer; a wooden mallet when bits has "wood"): a short ash haft with weathered grain, a heavy blunt head across
			# the end with flat faces both sides (no edge), worn darker striking faces, and leather thong lashing either side of the head. Mesh axes: haft along x, head along z.
			var mallet: bool = bits.has("wood")
			var haft_wood: Color = Color(0.4, 0.27, 0.14)                                                            # wood brown, so the haft does not read dark grey in the hand
			var thong: Color = Color(0.5, 0.38, 0.2)                                                                 # rope / hide colour
			for k in range(9):
				_cyl(parts, 0.021, 0.05, Vector3(-0.225 + 0.05 * float(k) + 0.025, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), _tone(haft_wood, k, 0.06))
			_cyl(parts, 0.027, 0.1, Vector3(0.18, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), _tone(haft_wood, 2, 0.1))
			if mallet:
				var grain: Color = Color(0.42, 0.3, 0.17)                                                            # a turned wooden barrel head, banded with leather at both ends
				_cyl(parts, 0.05, 0.2, Vector3(0.2, 0.0, 0.0), Vector3(PI * 0.5, 0.0, 0.0), _tone(grain, 3, 0.1))
				for end in [-0.09, 0.09]:
					_cyl(parts, 0.053, 0.02, Vector3(0.2, 0.0, end), Vector3(PI * 0.5, 0.0, 0.0), thong.darkened(0.15))
			else:
				color = _warm_stone(color)
				dark = color.darkened(0.3)
				_box_rot(parts, Vector3(0.07, 0.06, 0.11), Vector3(0.2, 0.0, 0.0), Vector3(0.1, 0.15, 0.08), color)             # the head: a rough lump about half the old slab
				_box_rot(parts, Vector3(0.06, 0.05, 0.08), Vector3(0.205, 0.008, -0.01), Vector3(-0.2, -0.3, 0.12), _tone(color, 5, 0.12))   # a second, uneven face so the lump is not a clean block
				_box_rot(parts, Vector3(0.05, 0.05, 0.035), Vector3(0.2, 0.0, 0.065), Vector3(0.0, 0.0, 0.15), dark)    # a worn, darker striking face
				_box_rot(parts, Vector3(0.05, 0.05, 0.035), Vector3(0.2, 0.0, -0.065), Vector3(0.0, 0.0, -0.15), dark)
			for k in range(4):                                                                                       # leather thong lashing either side of the head
				_cyl(parts, 0.03, 0.01, Vector3(0.135 + 0.012 * float(k), 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), thong if k % 2 == 0 else thong.darkened(0.25))
				_cyl(parts, 0.03, 0.01, Vector3(0.255 + 0.012 * float(k), 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), thong if k % 2 == 1 else thong.darkened(0.25))
		"hoe":
			# A garden draw hoe (modelled on a real long-handled hoe; tools to the pickaxe standard): a 1.25 m ash haft with a slight taper, a darker patch where the hands go and a rounded
			# end, a socket cone, a goose-neck that bends down from it, and a thin trapezoid blade plate (a real polygon plate, dished, rolled edge) set a little back toward the grip.
			# Mesh axes: haft along x (grip at -x), blade hangs toward +z and is wide across y. Iron and steel (bits "metal") are on the metal surface like the spades.
			var metal_blade: bool = bits.has("metal")
			var blade: Color = color
			var ash: Color = Color(0.42, 0.3, 0.17)
			var rough: float = 0.65

			if metal_blade:
				blade = Color(0.25, 0.25, 0.25) if bits.has("steel") else Color(0.1, 0.095, 0.088)
			elif absf(color.r - color.b) < 0.1:
				blade = Color(0.22, 0.175, 0.12)                                                               # stone: matt grey, rough, tied on with twine below
			else:
				blade = ash.darkened(0.15)                                                                      # wood: the same ash as the haft, a little darker

			_cyl_taper(parts, 0.0195, 0.0185, 0.42, Vector3(0.24, 0.0, 0.0), _tone(ash, 1, 0.1))
			_cyl_taper(parts, 0.0185, 0.0195, 0.42, Vector3(-0.18, 0.0, 0.0), _tone(ash, 2, 0.1))
			_cyl_taper(parts, 0.0195, 0.021, 0.42, Vector3(-0.6, 0.0, 0.0), _tone(ash, 3, 0.1))
			_wrap(parts, -0.28, -0.12, 0.0202)                                                                        # a dark leather wrap with visible spiral turns where the hands go
			_sph(parts, 0.021, Vector3(0.8, 1.0, 1.0), Vector3(-0.815, 0.0, 0.0), _tone(ash, 4, 0.06))           # the rounded end
			var stone_blade: bool = bits.is_empty() and absf(color.r - color.b) < 0.1
			_cyl_taper(parts, 0.022, 0.034 if not stone_blade else 0.0195, 0.1, Vector3(0.4, 0.0, 0.0), blade * 1.5 if metal_blade else ash.darkened(0.15))   # the socket cone (a plain haft end for a stone head)
			if metal_blade:
				_metal(parts, rough, 0.3)

			_cyl_taper(parts, 0.03, 0.03, 0.02, Vector3(0.455, 0.0, 0.0), blade * 1.3 if metal_blade else ash.darkened(0.15))   # the small socket flange where the neck enters
			if metal_blade:
				_metal(parts, rough, 0.3)

			for k in range(3):                                                                                        # the goose-neck: a 70 degree bend toward +z
				var phi: float = (float(k) + 0.5) * deg_to_rad(70.0) / 3.0
				_box_rot(parts, Vector3(0.045, 0.024, 0.024), Vector3(0.45 + 0.08 * sin(phi), 0.0, 0.08 * (1.0 - cos(phi))), Vector3(0.0, -phi, 0.0), blade * 1.5 if metal_blade else ash.darkened(0.1))
				if metal_blade:
					_metal(parts, rough, 0.3)

			if bits.is_empty() and absf(color.r - color.b) < 0.1:
				for k in range(4):                                                                              # a stone blade is tied on: four turns of twine wound round the neck, slanted, in two tones
					var along: Vector3 = Vector3(cos(0.6), 0.0, sin(0.6))
					var turn: Basis = Basis(Vector3.UP, -0.6) * Basis.from_euler(Vector3(0.0, 0.0, -PI * 0.5 + 0.25))
					parts.append([_twine_band(), Transform3D(turn, Vector3(0.49, 0.0, 0.015) + along * 0.013 * float(k)), Color(0.55, 0.42, 0.2) if k % 2 == 0 else Color(0.38, 0.28, 0.13)])

			var frame: Transform3D = Transform3D(Basis(Vector3.UP, -0.2) * Basis(Vector3(0.0, 0.0, 1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)), Vector3(0.522, 0.0, 0.05))
			_plate(parts, 0.0, 0.13, 0.18, 0, 8, blade, true, metal_blade, rough, 0.3, frame, 1, 2.6 if stone_blade else 1.0)   # the blade plate, hanging toward +z, wide across y (a chunky stone head is thicker)
			_plate(parts, 0.0, 0.13, 0.18, 8, 12, Color(0.45, 0.45, 0.45) if bits.has("steel") else blade * 1.3, false, metal_blade, rough, 0.3, frame, 1)   # its bright cutting edge
		"knife":
			# A stone knife (Dave 2026-10-25: tools to the pickaxe standard; review: matt stone, wrapped handle, leaf blade): a short ash handle wrapped in three dark hide bands,
			# a bound joint where the blade is set straight into it, and a leaf-shaped knapped stone blade, thick straight back along -z, curved cutting edge toward +z, slightly
			# chipped, about as long as the handle (about 23 cm overall). No sheen. Mesh axes: handle at -x, blade pointing +x.
			var stone: Color = Color(0.3, 0.26, 0.19)                                                                                                 # matt grey-brown stone (linear; about sRGB 120, 110, 95 on screen)
			var hide: Color = Color(0.22, 0.13, 0.07)
			for k in range(4):
				_cyl(parts, 0.016, 0.03, Vector3(-0.1 + 0.03 * float(k) + 0.015, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), _tone(Color(0.3, 0.2, 0.11), k, 0.14))
			for k in range(3):
				_cyl(parts, 0.0185, 0.014, Vector3(-0.085 + 0.03 * float(k), 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), hide if k != 1 else hide.lightened(0.15))    # hide wraps
			_cyl(parts, 0.0195, 0.016, Vector3(0.006, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), hide.darkened(0.1))                                      # the bound joint
			var widths: Array = [0.022, 0.032, 0.038, 0.037, 0.03, 0.02, 0.01]                                                                          # leaf blade: width by slice
			for k in range(widths.size()):
				var w: float = widths[k]
				_box(parts, Vector3(0.0175, 0.011 - 0.0008 * float(k), w), Vector3(0.014 + 0.0171 * float(k), 0.0, -0.019 + w * 0.5), _tone(stone, k, 0.1))
			_box(parts, Vector3(0.1, 0.014, 0.006), Vector3(0.06, 0.0, -0.0185), stone.darkened(0.12))                                                  # the thick straight back
			_box_rot(parts, Vector3(0.012, 0.012, 0.012), Vector3(0.05, 0.0, 0.021), Vector3(0.0, 0.5, 0.0), stone.darkened(0.2))                       # a chipped notch on the edge
		"needle":
			_cyl(parts, 0.004, 0.12, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), color)
		"rod":
			# A fishing rod (item 75) or a wooden pin (bits "pin", item 233). The rod: a tapering ash cane 1.6 m, a leather-wrapped handle at the butt (-x), a small reel on a seat below it,
			# three guide rings and a pale line running to the tip. The pin: a short tapered peg with a rounded head.
			var cane: Color = Color(0.46, 0.3, 0.14)                                                                 # the warm brown of the ground rod
			if bits.has("pin"):
				_cyl_taper(parts, 0.011, 0.016, 0.1, Vector3(0.1, 0.0, 0.0), _tone(color, 1, 0.05), 14)
				_cyl_taper(parts, 0.004, 0.011, 0.18, Vector3(-0.04, 0.0, 0.0), _tone(color, 2, 0.05), 14)
				_sph(parts, 0.0175, Vector3(0.9, 1.0, 1.0), Vector3(0.155, 0.0, 0.0), _tone(color, 3, 0.05))
			else:
				for k in range(3):                                                                                   # the cane in three clear tones, thick at the butt and fine at the tip
					var x0: float = -0.55 + 0.45 * float(k)
					var x1: float = x0 + 0.45 if k < 2 else 0.8
					_cyl_taper(parts, _cane_r(x0), _cane_r(x1), x1 - x0, Vector3(0.5 * (x0 + x1), 0.0, 0.0), _tone(cane, [2, 5, 8][k], 0.16))
				_cyl(parts, 0.017, 0.06, Vector3(-0.6, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), cane.darkened(0.15))   # the butt under the wrap
				_wrap(parts, -0.8, -0.58, 0.019)                                                                      # the leather handle, one continuous spiral wrap
				_box(parts, Vector3(0.05, 0.012, 0.02), Vector3(-0.46, -0.0215, 0.0), cane.darkened(0.3))             # the reel seat on the cane
				_cyl(parts, 0.022, 0.02, Vector3(-0.46, -0.049, -0.012), Vector3(PI * 0.5, 0.0, 0.0), Color(0.16, 0.12, 0.09))   # a small dark iron reel drum, set toward the near side
				_cyl(parts, 0.027, 0.004, Vector3(-0.46, -0.049, -0.026), Vector3(PI * 0.5, 0.0, 0.0), Color(0.26, 0.2, 0.15))   # its side plate, facing the viewer
				var line: Array = [Vector2(-0.46, -0.027)]                                                           # the line: reel top, up to each guide, on to the tip
				for k in range(4):
					var gx: float = -0.1 + 0.28 * float(k) if k < 3 else 0.78
					var gy: float = -(_cane_r(gx) + 0.005)
					var ring: TorusMesh = TorusMesh.new()
					ring.inner_radius = 0.0055
					ring.outer_radius = 0.0075
					ring.rings = 6
					ring.ring_segments = 3
					parts.append([ring, Transform3D(Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5)), Vector3(gx, gy, 0.0)), Color(0.3, 0.28, 0.25)])
					line.append(Vector2(gx, gy))
				line.append(Vector2(0.8, 0.0))

				for k in range(line.size() - 1):
					var from: Vector2 = line[k]
					var to: Vector2 = line[k + 1]
					var span: Vector2 = to - from
					_cyl(parts, 0.0014, span.length(), Vector3(0.5 * (from.x + to.x), 0.5 * (from.y + to.y), 0.0), Vector3(0.0, 0.0, atan2(span.y, span.x) - PI * 0.5), Color(0.85, 0.82, 0.72))
		"torch":
			_handle(parts, 0.5)
			_sph(parts, 0.04, Vector3(1.0, 1.4, 1.0), Vector3(0.27, 0.0, 0.0), color)
		"pot":
			# A clay cooking pot: round belly, narrow neck, flared rim and two small lug handles.
			_sph(parts, 0.11, Vector3(1.0, 0.85, 1.0), Vector3(0.0, -0.025, 0.0), color)
			_cyl(parts, 0.06, 0.04, Vector3(0.0, 0.06, 0.0), Vector3.ZERO, color.darkened(0.1))
			_torus(parts, 0.065, 0.014, Vector3(0.0, 0.082, 0.0), dark)
			_box(parts, Vector3(0.05, 0.025, 0.02), Vector3(0.115, 0.0, 0.0), dark)
			_box(parts, Vector3(0.05, 0.025, 0.02), Vector3(-0.115, 0.0, 0.0), dark)
			_cyl(parts, 0.05, 0.012, Vector3(0.0, 0.075, 0.0), Vector3.ZERO, Color(0.12, 0.08, 0.06))   # dark mouth
		"bucket":
			# A wooden stave bucket: tapering sides with the stave joints showing, two dark wooden hoops, a rope bail across the top.
			_frustum(parts, 0.085, 0.11, 0.2, Vector3.ZERO, color)
			var stave: Color = color.darkened(0.4)

			for n in 8:
				var turn: float = float(n) * TAU / 8.0
				_box_rot(parts, Vector3(0.006, 0.2, 0.006), Vector3(sin(turn) * 0.0985, 0.0, cos(turn) * 0.0985), Vector3(0.0, turn, 0.0), stave)

			_torus(parts, 0.1, 0.008, Vector3(0.0, -0.05, 0.0), Color(0.3, 0.2, 0.11))
			_torus(parts, 0.108, 0.008, Vector3(0.0, 0.06, 0.0), Color(0.3, 0.2, 0.11))
			_cyl(parts, 0.1, 0.01, Vector3(0.0, 0.085, 0.0), Vector3.ZERO, Color(0.07, 0.05, 0.04))     # dark inside
			_torus_v(parts, 0.1, 0.007, Vector3(0.0, 0.1, 0.0), Color(0.75, 0.62, 0.38))                  # the rope bail
		"skin":
			_sph(parts, 0.09, Vector3(1.0, 1.3, 0.7), Vector3.ZERO, color)
			_cyl(parts, 0.02, 0.06, Vector3(0.0, 0.12, 0.0), Vector3.ZERO, dark)
		"kit":
			_box(parts, Vector3(0.3, 0.12, 0.2), Vector3(0.0, -0.01, 0.0), color)
			_box(parts, Vector3(0.31, 0.02, 0.21), Vector3(0.0, 0.0, 0.0), dark)
			_box(parts, Vector3(0.02, 0.13, 0.21), Vector3(0.0, 0.0, 0.0), light)
			# An emblem on the lid (bits[0]) tells the kits apart: saw, table, bench, anvil, rack, vice. No bits: the plain box.
			var emblem: String = str(bits[0]) if bits.size() > 0 else ""
			var tag: Color = Color(0.82, 0.8, 0.76)

			match emblem:
				"saw":
					_box(parts, Vector3(0.2, 0.006, 0.05), Vector3(0.0, 0.053, 0.0), Color(0.62, 0.64, 0.68))
					for k in range(8):
						_box(parts, Vector3(0.012, 0.012, 0.012), Vector3(-0.085 + 0.024 * float(k), 0.054, 0.03), Color(0.62, 0.64, 0.68))
					_box(parts, Vector3(0.05, 0.012, 0.03), Vector3(-0.12, 0.056, 0.0), Color(0.34, 0.23, 0.13))
				"table":
					_box(parts, Vector3(0.18, 0.012, 0.1), Vector3(0.0, 0.076, 0.0), tag)
					for leg in [[-0.075, -0.04], [0.075, -0.04], [-0.075, 0.04], [0.075, 0.04]]:
						_box(parts, Vector3(0.012, 0.03, 0.012), Vector3(float(leg[0]), 0.056, float(leg[1])), tag)
				"bench":
					_cyl(parts, 0.008, 0.12, Vector3(0.0, 0.058, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.34, 0.23, 0.13))
					_box(parts, Vector3(0.05, 0.04, 0.04), Vector3(0.07, 0.06, 0.0), Color(0.5, 0.5, 0.52))
				"anvil":
					_box(parts, Vector3(0.14, 0.03, 0.06), Vector3(0.0, 0.07, 0.0), Color(0.3, 0.3, 0.32))
					_box(parts, Vector3(0.06, 0.04, 0.05), Vector3(0.0, 0.045, 0.0), Color(0.26, 0.26, 0.28))
					_cone(parts, 0.025, 0.07, Vector3(0.1, 0.07, 0.0), Color(0.3, 0.3, 0.32))
				"rack":
					for k in range(3):
						_cyl(parts, 0.006, 0.1, Vector3(-0.07 + 0.07 * float(k), 0.07, 0.0), Vector3(PI * 0.5, 0.0, 0.0), tag)
					_box(parts, Vector3(0.2, 0.012, 0.012), Vector3(0.0, 0.1, 0.0), Color(0.34, 0.23, 0.13))
				"vice":
					_box(parts, Vector3(0.1, 0.05, 0.04), Vector3(0.0, 0.07, 0.0), Color(0.4, 0.4, 0.42))
					_box(parts, Vector3(0.02, 0.05, 0.06), Vector3(0.06, 0.07, 0.0), Color(0.5, 0.5, 0.52))
		"flower":
			# A flower head on a short stem: three crossed flat petal blades, a centre and a green stem (about 80 triangles). bits[0] is the centre colour.
			var centre: Color = Color.html(str(bits[0])) if bits.size() > 0 else Color(0.88, 0.7, 0.12)
			_cyl(parts, 0.006, 0.12, Vector3(0.0, -0.01, 0.0), Vector3.ZERO, Color(0.3, 0.5, 0.2))

			for k in 3:
				var petal: BoxMesh = BoxMesh.new()
				petal.size = Vector3(0.07, 0.006, 0.022)
				parts.append([petal, Transform3D(Basis.from_euler(Vector3(0.0, PI * float(k) / 3.0, 0.0)), Vector3(0.0, 0.05, 0.0)), color])

			_box(parts, Vector3(0.022, 0.01, 0.022), Vector3(0.0, 0.056, 0.0), centre)
		"frond":
			# A small fan of five leaf blades lying on a short stem (about 70 triangles).
			_cyl(parts, 0.005, 0.12, Vector3(-0.06, -0.05, 0.0), Vector3(0.0, 0.0, PI * 0.5), dark)

			for k in 5:
				var leaf: BoxMesh = BoxMesh.new()
				leaf.size = Vector3(0.12, 0.004, 0.04)
				var turn: float = (float(k) - 2.0) * 0.4
				parts.append([leaf, Transform3D(Basis.from_euler(Vector3(0.0, turn, 0.04 * float(k % 2))), Vector3(0.05 * cos(turn), -0.04 + 0.004 * float(k % 2), 0.05 * sin(turn))), color.lightened(0.08 * float(k % 2))])
		"root":
			# Three tapering roots lying side by side, thick at the top and thin at the tip (about 60 triangles).
			for k in 3:
				var taper: CylinderMesh = CylinderMesh.new()
				taper.top_radius = 0.022
				taper.bottom_radius = 0.004
				taper.height = 0.2 - 0.03 * float(k)
				taper.radial_segments = 5
				taper.rings = 1
				parts.append([taper, Transform3D(Basis.from_euler(Vector3(0.0, 0.25 * float(k - 1), PI * 0.5)), Vector3(0.0, -0.04 + 0.03 * float(k % 2), 0.035 * float(k - 1))), color.lightened(0.1 * float(k % 2))])
		"nut":
			# Two nuts: a round body and a darker cap on top (acorn, hazelnut, chestnut) (about 110 triangles).
			for spot in [[0.0, 0.0], [0.045, 0.03]]:
				var at: Vector3 = Vector3(float(spot[0]), -0.03, float(spot[1]))
				_sph(parts, 0.022, Vector3(1.0, 1.15, 1.0), at, color, true)
				_cyl(parts, 0.018, 0.012, at + Vector3(0.0, 0.026, 0.0), Vector3.ZERO, dark)
		"cap":
			# A mushroom: a domed cap on a pale stem; two of them, one smaller (about 130 triangles). bits[0] is the stem colour.
			var stem: Color = Color.html(str(bits[0])) if bits.size() > 0 else Color(0.93, 0.9, 0.8)

			for spot in [[0.0, 0.0, 1.0], [0.07, 0.04, 0.65]]:
				var scale_v: float = float(spot[2])
				var base: Vector3 = Vector3(float(spot[0]), -0.04, float(spot[1]))
				_cyl(parts, 0.011 * scale_v, 0.07 * scale_v, base + Vector3(0.0, 0.02 * scale_v, 0.0), Vector3.ZERO, stem)
				_sph(parts, 0.05 * scale_v, Vector3(1.0, 0.55, 1.0), base + Vector3(0.0, 0.06 * scale_v, 0.0), color, true)
		_:
			_sph(parts, 0.08, Vector3.ONE, Vector3.ZERO, color)

	return _combine(parts, size)


# A colour scaled by a repeatable pseudo-random factor (1 +- spread): the same idea as _tone, but it keeps very dark colours dark (lightened() lerps toward white).
static func _tone_mul(color: Color, k: int, spread: float) -> Color:
	var n: float = fposmod(sin(float(k) * 12.9898 + 4.1) * 43758.5453, 1.0) * 2.0 - 1.0
	return Color(color.r * (1.0 + n * spread), color.g * (1.0 + n * spread), color.b * (1.0 + n * spread), color.a)


# A colour nudged lighter or darker by a repeatable pseudo-random amount (up to `spread`), for weathered grain and hammered iron.
static func _tone(color: Color, k: int, spread: float) -> Color:
	var n: float = fposmod(sin(float(k) * 12.9898 + 4.1) * 43758.5453, 1.0) * 2.0 - 1.0
	return color.lightened(n * spread) if n > 0.0 else color.darkened(-n * spread)


# A stone head colour a little darker and warmer than the table grey (hands11 pictures: sunlit grey stone read pale blue-white).
static func _warm_stone(color: Color) -> Color:
	return color.darkened(0.33).lerp(Color(0.46, 0.38, 0.29), 0.42)


# A wooden handle lying along x, centred on the middle of a tool of this length (the head is added at its +x end).
static func _handle(parts: Array, length: float, radius: float = 0.016, wood: Color = Color(0.42, 0.3, 0.17)) -> void:
	_cyl(parts, radius, length, Vector3(-length * 0.05, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), wood)


static func _box(parts: Array, dims: Vector3, at: Vector3, color: Color) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = dims
	parts.append([box, Transform3D(Basis.IDENTITY, at), color])


static func _cyl(parts: Array, radius: float, height: float, at: Vector3, tilt: Vector3, color: Color) -> void:
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 8
	cyl.rings = 1
	parts.append([cyl, Transform3D(Basis.from_euler(tilt), at), color])


# A cone along x with its point at +x.
static func _cone(parts: Array, radius: float, length: float, at: Vector3, color: Color) -> void:
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = length
	cone.radial_segments = 6
	cone.rings = 1
	parts.append([cone, Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -PI * 0.5)), at), color])


# A cone pointing down (-y), for the points of a pick.
static func _cone_down(parts: Array, radius: float, length: float, at: Vector3, color: Color) -> void:
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = radius
	cone.bottom_radius = 0.0
	cone.height = length
	cone.radial_segments = 6
	cone.rings = 1
	parts.append([cone, Transform3D(Basis.IDENTITY, at), color])


# A wedge for an axe head: `base` wide (y), `out` long (z) from its base to the edge, `along` long (x, the length of the edge). Thick at z - out/2, edge at +z.
static func _wedge(parts: Array, base: float, out: float, along: float, at: Vector3, color: Color) -> void:
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(base, out, along)
	prism.left_to_right = 0.5
	parts.append([prism, Transform3D(Basis(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(1.0, 0.0, 0.0)), at), color])


# A spade blade as a real polygon plate (Dave 2026-10-25 review: stacked boxes always stair-step): `rows` outline rows along x from `x0` over `length`, 7 columns across, the
# half width flat to 45 percent of the length (square shoulders) then an elliptical taper to a rounded tip, dished across (the edges lift 1.4 cm), curving forward at the
# socket, 4 mm thin with a rolled (thicker) edge, smooth-shaded. `from_row` to `to_row` of 12 build one piece, so the tip can take its own colour.
static func _plate(parts: Array, x0: float, length: float, wide: float, from_row: int, to_row: int, color: Color, with_root: bool, metal: bool, rough: float, metallic: float, xform: Transform3D = Transform3D.IDENTITY, mode: int = 0, thick_scale: float = 1.0) -> void:
	var rows: int = 12
	var cols: int = 2 if mode == 0 else 3
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top: Array = []
	var bottom: Array = []

	for i in range(from_row, to_row + 1):
		var t: float = float(i) / float(rows)
		var half: float = 0.5 * wide * (1.0 - 0.15 * t / 0.6) if t < 0.6 else 0.5 * wide * 0.85 * sqrt(maxf(1.0 - pow((t - 0.6) / 0.4, 2.0), 0.0))   # a spade blade: widest at the shoulders under the socket, gently tapering sides, a round arched tip

		if mode == 1:
			half = 0.5 * wide * (0.62 + 0.38 * t)                                                                     # a hoe blade: a trapezoid widening to a straight edge
		elif mode == 3:
			half = 0.5 * wide * pow(sin(PI * pow(t, 0.8)), 0.8)                                                             # a spear leaf: swelling, then a sharp point
		elif mode == 2:
			half = 0.5 * wide * (1.0 - 0.64 * t)                                                                      # a saw blade: 14 cm at the heel tapering to 5 cm at the toe

			if t > 0.9:
				half *= sqrt(maxf(1.0 - pow((t - 0.9) / 0.1, 2.0) * 0.9, 0.0))                                      # rounded toe

		half = maxf(half, 0.012)
		var forward: float = 0.006 * pow(1.0 - t, 2.0) if mode == 0 else 0.0
		var dish: float = (0.018 if mode == 0 else (0.008 if mode == 1 else (-0.007 if mode == 3 else 0.0))) * half / (0.5 * wide)               # the dish follows the local width, so the narrow tip does not curl into a hook
		var base: float = 0.004 if mode == 0 else (0.005 if mode == 1 else (0.003 if mode == 3 else 0.0025))

		if mode == 1:
			base += 0.007 * smoothstep(0.35, 0.7, t) * (1.0 - 0.8 * smoothstep(0.8, 1.0, t))                           # a hoe's edge thickens, then bevels to a thin cutting edge
		base *= thick_scale
		var rim: float = 0.006 if mode < 2 else 0.0
		var top_row: Array = []
		var bottom_row: Array = []

		for c in range(-cols, cols + 1):
			var u: float = float(c) / float(cols)
			var y: float = forward + dish * u * u
			var thick: float = base + rim * pow(absf(u), 6.0)
			top_row.append(Vector3(x0 + length * t, y, u * half))
			bottom_row.append(Vector3(x0 + length * t, y - thick, u * half))

		top.append(top_row)
		bottom.append(bottom_row)

	var width: int = cols * 2 + 1
	var last: int = top.size() - 1

	for r in range(last):
		for c in range(width - 1):
			_plate_quad(tool, top[r][c], top[r + 1][c], top[r + 1][c + 1], top[r][c + 1], Vector3.UP)
			_plate_quad(tool, bottom[r][c], bottom[r][c + 1], bottom[r + 1][c + 1], bottom[r + 1][c], Vector3.DOWN)

		_plate_quad(tool, top[r][0], bottom[r][0], bottom[r + 1][0], top[r + 1][0], Vector3(0.0, 0.0, -1.0))              # the rolled edge, both sides
		_plate_quad(tool, top[r][width - 1], top[r + 1][width - 1], bottom[r + 1][width - 1], bottom[r][width - 1], Vector3(0.0, 0.0, 1.0))

	for c in range(width - 1):                                                                                           # the end of the piece
		_plate_quad(tool, top[last][c], top[last][c + 1], bottom[last][c + 1], bottom[last][c], Vector3.RIGHT)

		if with_root:
			_plate_quad(tool, top[0][c], bottom[0][c], bottom[0][c + 1], top[0][c + 1], Vector3.LEFT)

	tool.index()
	tool.generate_normals()
	var piece: ArrayMesh = tool.commit()
	parts.append([piece, xform, color])

	if metal:
		_metal(parts, rough, metallic)


# A quad a, b, c, d wound clockwise (Godot's front face) as seen from `outward` (two triangles).
static func _plate_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	var normal: Vector3 = (b - a).cross(c - a) + (c - a).cross(d - a)
	var order: Array = [a, c, b, a, d, c] if normal.dot(outward) >= 0.0 else [a, b, c, a, c, d]

	for v in order:
		tool.add_vertex(v)


# A leather wrap on a haft from x0 to x1: slanted bands in two dark tones so the spiral turns read (spade and hoe hand grips).
static func _wrap(parts: Array, x0: float, x1: float, radius: float) -> void:
	var count: int = int((x1 - x0) / 0.03)

	for k in range(count):
		var tone: Color = Color(0.1, 0.05, 0.025) if k % 2 == 0 else Color(0.16, 0.09, 0.045)
		_cyl(parts, radius, 0.032, Vector3(x0 + 0.03 * (float(k) + 0.5), 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5 + 0.3), tone)


# A round tube between two points in the x-z plane (the grip's D path), radius `radius`, six sided.
static func _tube(parts: Array, from: Vector2, to: Vector2, radius: float, color: Color, sides: int = 6) -> void:
	var along: Vector3 = Vector3(to.x - from.x, 0.0, to.y - from.y)
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = along.length() + radius * 0.8
	cyl.radial_segments = sides
	cyl.rings = 1
	var y_axis: Vector3 = along.normalized()
	var x_axis: Vector3 = Vector3.UP
	parts.append([cyl, Transform3D(Basis(x_axis, y_axis, x_axis.cross(y_axis)), Vector3(0.5 * (from.x + to.x), 0.0, 0.5 * (from.y + to.y))), color])


# One turn of twine round a neck (a short fat ring of cylinder).
static func _twine_band() -> CylinderMesh:
	var band: CylinderMesh = CylinderMesh.new()
	band.top_radius = 0.022
	band.bottom_radius = 0.022
	band.height = 0.012
	band.radial_segments = 8
	band.rings = 1
	return band


# The fishing rod's cane radius at x along the rod: a blank 1.5 times thicker than a thin cane, fine at the tip.
static func _cane_r(x: float) -> float:
	return 0.0155 - 0.0105 * (x + 0.55) / 1.35


# A cylinder along x (radius `back` at -x, `front` at +x) centred at `at`: a smooth tapering haft or socket cone.
static func _cyl_taper(parts: Array, back: float, front: float, length: float, at: Vector3, color: Color, sides: int = 8) -> void:
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = front
	cyl.bottom_radius = back
	cyl.height = length
	cyl.radial_segments = sides
	cyl.rings = 1
	parts.append([cyl, Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -PI * 0.5)), at), color])


# A box turned by `tilt` (Euler) in place.
static func _box_rot(parts: Array, dims: Vector3, at: Vector3, tilt: Vector3, color: Color) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = dims
	parts.append([box, Transform3D(Basis.from_euler(tilt), at), color])


# A frustum (wider at the top): a bucket or a bowl.
static func _frustum(parts: Array, bottom: float, top: float, height: float, at: Vector3, color: Color) -> void:
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = top
	cyl.bottom_radius = bottom
	cyl.height = height
	cyl.radial_segments = 10
	cyl.rings = 1
	parts.append([cyl, Transform3D(Basis.IDENTITY, at), color])


# A ring standing on its edge (a bucket bail).
static func _torus_v(parts: Array, ring: float, tube: float, at: Vector3, color: Color) -> void:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = ring - tube
	torus.outer_radius = ring + tube
	torus.rings = 10
	torus.ring_segments = 4
	parts.append([torus, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)), at), color])


# The shared wooden bowl: a shallow flared bowl with a rim and a dark hollow.
static func _bowl(parts: Array, wood: Color) -> void:
	_frustum(parts, 0.055, 0.115, 0.07, Vector3(0.0, -0.035, 0.0), wood)
	_torus(parts, 0.115, 0.011, Vector3(0.0, 0.0, 0.0), wood.lightened(0.12))
	_cyl(parts, 0.105, 0.006, Vector3(0.0, -0.003, 0.0), Vector3.ZERO, wood.darkened(0.45))


# What is in a bowl: a surface of `broth` and chunky bits (small cubes and balls of the given colours) scattered over it, or a heaped mound.
static func _fill(parts: Array, broth: Color, bits: Array, mound: bool) -> void:
	if mound:
		_sph(parts, 0.1, Vector3(1.0, 0.55, 1.0), Vector3(0.0, 0.0, 0.0), broth)
	else:
		_cyl(parts, 0.103, 0.012, Vector3(0.0, -0.004, 0.0), Vector3.ZERO, broth)

	var count: int = 10 if bits.size() > 0 else 0

	for k in count:
		var angle: float = float(k) * 2.39996
		var radius: float = 0.085 * sqrt((float(k) + 0.5) / float(count))
		var at: Vector3 = Vector3(cos(angle) * radius, (0.045 if mound else 0.012) * (1.0 - radius / 0.12) + 0.008, sin(angle) * radius)
		var tint: Color = Color.html(str(bits[k % bits.size()]))

		if k % 2 == 0:
			_box_rot(parts, Vector3(0.03, 0.026, 0.03), at, Vector3(0.3 * float(k), 0.5 * float(k), 0.0), tint)
		else:
			_sph(parts, 0.017, Vector3.ONE, at, tint)


static func _sph(parts: Array, radius: float, scale_v: Vector3, at: Vector3, color: Color, low: bool = false) -> void:
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = 6 if low else 8
	sph.rings = 3 if low else 4
	parts.append([sph, Transform3D(Basis.from_scale(scale_v), at), color])


static func _torus(parts: Array, ring: float, tube: float, at: Vector3, color: Color) -> void:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = ring - tube
	torus.outer_radius = ring + tube
	torus.rings = 10
	torus.ring_segments = 5
	parts.append([torus, Transform3D(Basis.IDENTITY, at), color])


# Marks the part just added as metal: it goes on its own surface with the metallic material (the pickaxe head so far).
static func _metal(parts: Array, rough: float = 0.4, metallic: float = 0.8) -> void:
	(parts[parts.size() - 1] as Array).append(Vector2(rough, metallic))


static func _combine(parts: Array, size: float) -> ArrayMesh:
	var plain: Array = []
	var metal: Dictionary = {}                                                  # roughness -> parts: one surface per roughness (the pickaxe 0.4, spades 0.55)

	for part in parts:
		if (part as Array).size() > 3:
			var kind: Vector2 = part[3]
			var group: Array = metal.get(kind, [])
			group.append(part)
			metal[kind] = group
		else:
			plain.append(part)

	var result: ArrayMesh = ArrayMesh.new()

	if not plain.is_empty() or metal.is_empty():
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(plain, size))
		result.surface_set_material(0, _shared_material())

	for kind in metal:
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(metal[kind], size))
		result.surface_set_material(result.get_surface_count() - 1, _metal_material((kind as Vector2).x, (kind as Vector2).y))

	return result


static func _surface_arrays(parts: Array, size: float) -> Array:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	for part in parts:
		var arrays: Array = (part[0] as ArrayMesh).surface_get_arrays(0) if part[0] is ArrayMesh else (part[0] as PrimitiveMesh).get_mesh_arrays()
		var xform: Transform3D = part[1]
		var color: Color = part[2]
		var first: int = vertices.size()
		var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

		for i in source.size():
			vertices.append(xform * source[i] * size)
			normals.append((xform.basis * source_n[i]).normalized())
			colors.append(color)

		for index in arrays[Mesh.ARRAY_INDEX]:
			indices.append(first + int(index))

	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = vertices
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_INDEX] = indices
	return out


# One shared metal material, built once: the vertex colour is the metal's colour, smooth and shiny.
static func _metal_material(rough: float = 0.4, metallic: float = 0.8) -> StandardMaterial3D:
	var key: Vector2 = Vector2(rough, metallic)

	if not _metal_mats.has(key):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.metallic = metallic
		material.roughness = rough
		_metal_mats[key] = material

	return _metal_mats[key]


static func _shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 1.0

	return _material
