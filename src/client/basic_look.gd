extends RefCounted

# Stage-one models (Kathleen, art/MODEL_PLAN.md): any loose item drawn from a small shape and a colour, so every item has a look before
# any item gets a good one. `data/items/looks.json` maps an item id to {shape, color, size}; `mesh()` returns one vertex-coloured ArrayMesh
# (a few hundred triangles, 1200 at most for a bowl of stew, one shared material) centred on its middle with the underside near y = -0.06 * size. Upgrading an item later means
# deleting its looks.json entry or giving it a real model; nothing here changes.

const LOOKS_PATH := "res://data/items/looks.json"

static var _table: Dictionary = {}
static var _loaded: bool = false
static var _material: StandardMaterial3D
static var _metal_mat: StandardMaterial3D


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
			# A spear: a long shaft and a long, plainly pointed cone head at the +x end (Dave: it must be pointy).
			_cyl(parts, 0.016, 0.9, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), Color(0.42, 0.3, 0.17))
			_cone(parts, 0.045, 0.28, Vector3(0.58, 0.0, 0.0), color)
			_cyl(parts, 0.024, 0.04, Vector3(0.43, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.8, 0.7, 0.4))   # the binding below the head
		"axe":
			# A stone axe: a stick with a wedge-headed blade lashed to the end. The wedge is thick at the stick and thins to a sharp edge, sticking out
			# sideways, so from the side the whole thing reads like a hoe. The edge is ground wider than the body and one corner is chipped, so the
			# head is not a plain box; a thicker haft end and three wraps of cord hold it on.
			color = _warm_stone(color)                                                                              # darker and warmer: in sunlight the plain grey read pale blue
			dark = color.darkened(0.3)
			light = color.lightened(0.18)
			_handle(parts, 0.5, 0.021, Color(0.3, 0.2, 0.11))                                                       # a thicker, darker haft
			_cyl(parts, 0.027, 0.1, Vector3(0.2, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.3, 0.2, 0.11))     # the haft swells where the head sits
			_box(parts, Vector3(0.09, 0.065, 0.065), Vector3(0.22, 0.0, 0.0), dark)                                # the poll block the wedge sits on
			_wedge(parts, 0.065, 0.15, 0.115, Vector3(0.22, 0.0, 0.05), color)                                     # the wedge: base 6.5 cm, 15 cm out, 11.5 cm of edge
			_wedge(parts, 0.026, 0.055, 0.15, Vector3(0.225, 0.0, 0.1), light)                                     # the ground edge, flared wider than the body
			_box_rot(parts, Vector3(0.03, 0.03, 0.035), Vector3(0.285, 0.0, 0.12), Vector3(0.0, 0.5, 0.0), dark)  # a chipped corner
			for wrap_x in [0.165, 0.19, 0.28]:
				_cyl(parts, 0.034, 0.02, Vector3(wrap_x, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.78, 0.66, 0.38))   # cord wraps
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
			# A real garden spade: long shaft, D-shaped grip, a socket, and a flat blade that narrows to a point.
			_handle(parts, 0.75)
			_box(parts, Vector3(0.03, 0.03, 0.15), Vector3(-0.4, 0.0, 0.0), Color(0.42, 0.3, 0.17))                    # grip bar
			_box(parts, Vector3(0.06, 0.03, 0.03), Vector3(-0.37, 0.0, 0.06), Color(0.42, 0.3, 0.17))                  # grip sides
			_box(parts, Vector3(0.06, 0.03, 0.03), Vector3(-0.37, 0.0, -0.06), Color(0.42, 0.3, 0.17))
			_cyl(parts, 0.024, 0.11, Vector3(0.3, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), dark)                        # socket
			_box(parts, Vector3(0.14, 0.012, 0.19), Vector3(0.4, 0.0, 0.0), color)                                     # blade, square part
			_box_rot(parts, Vector3(0.13, 0.012, 0.13), Vector3(0.47, 0.0, 0.0), Vector3(0.0, PI * 0.25, 0.0), color)  # blade, pointed tip
			_box(parts, Vector3(0.1, 0.016, 0.02), Vector3(0.36, 0.0, 0.0), light)                                     # centre rib
		"saw":
			# A hand saw: a wooden pistol grip at -x, a thin steel blade (about 0.55 m long) that narrows toward the tip, and a row of teeth along the cutting edge (+z).
			var steel: Color = color.darkened(0.22)
			_box(parts, Vector3(0.1, 0.03, 0.045), Vector3(-0.26, 0.0, 0.0), Color(0.34, 0.23, 0.13))                 # grip
			_box(parts, Vector3(0.1, 0.03, 0.03), Vector3(-0.28, 0.0, -0.045), Color(0.34, 0.23, 0.13))               # the grip's lower leg
			_box(parts, Vector3(0.04, 0.02, 0.05), Vector3(-0.19, 0.0, 0.0), dark)                                    # the plate the blade is riveted to
			_box(parts, Vector3(0.3, 0.008, 0.075), Vector3(-0.02, 0.0, 0.0), steel)                                  # blade, wide end
			_box(parts, Vector3(0.12, 0.008, 0.055), Vector3(0.19, 0.0, 0.004), steel)                                # blade, narrower toward the tip
			_box(parts, Vector3(0.45, 0.012, 0.01), Vector3(0.0, 0.0, -0.036), dark)                                  # the stiffened back
			for k in range(16):
				_box_rot(parts, Vector3(0.012, 0.01, 0.014), Vector3(-0.15 + 0.0205 * float(k), 0.0, 0.043 if k < 10 else 0.035), Vector3(0.0, 0.0, 0.7), steel.lightened(0.15))   # teeth
		"hammer":
			# A stone hammer: a stick with a heavy blunt stone head lashed across the end, flat faces both sides (no edge).
			color = _warm_stone(color)
			dark = color.darkened(0.3)
			_handle(parts, 0.45, 0.021, Color(0.3, 0.2, 0.11))
			_cyl(parts, 0.027, 0.1, Vector3(0.18, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.3, 0.2, 0.11))
			_box(parts, Vector3(0.09, 0.08, 0.2), Vector3(0.2, 0.0, 0.0), color)                                     # the head
			_box_rot(parts, Vector3(0.095, 0.07, 0.06), Vector3(0.2, 0.0, 0.1), Vector3(0.0, 0.0, 0.12), dark)       # a worn, darker striking face
			_box_rot(parts, Vector3(0.095, 0.07, 0.06), Vector3(0.2, 0.0, -0.1), Vector3(0.0, 0.0, -0.12), dark)
			for wrap_x in [0.155, 0.245]:
				_cyl(parts, 0.04, 0.02, Vector3(wrap_x, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.78, 0.66, 0.38))
		"hoe":
			# A garden hoe: long handle, a socket, a neck that bends out sideways, and a flat wide blade angled back toward the handle's end.
			_handle(parts, 0.85)
			_cyl(parts, 0.022, 0.08, Vector3(0.38, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), dark)                           # socket
			_box_rot(parts, Vector3(0.03, 0.025, 0.12), Vector3(0.44, 0.0, 0.045), Vector3(0.0, 0.35, 0.0), dark)         # the neck bends out
			_box_rot(parts, Vector3(0.012, 0.17, 0.1), Vector3(0.5, 0.0, 0.1), Vector3(0.0, -0.25, 0.0), color)           # the flat blade, wide across
			_box_rot(parts, Vector3(0.012, 0.17, 0.015), Vector3(0.5, 0.0, 0.147), Vector3(0.0, -0.25, 0.0), light)       # the sharpened lower edge
		"knife":
			# A knife: a rounded grip, a small guard, and a blade with a thick back and a thin pointed edge.
			_handle(parts, 0.14)
			_box(parts, Vector3(0.015, 0.03, 0.045), Vector3(0.05, 0.0, 0.0), dark)                                 # guard
			_box(parts, Vector3(0.1, 0.012, 0.03), Vector3(0.115, 0.0, 0.0), color)                                 # blade body
			_box(parts, Vector3(0.1, 0.006, 0.012), Vector3(0.115, 0.0, 0.017), light)                              # the edge
			_box(parts, Vector3(0.04, 0.011, 0.024), Vector3(0.185, 0.0, 0.003), color)                              # the blade narrows to the point, touching the body (no gap)
			_box(parts, Vector3(0.03, 0.009, 0.012), Vector3(0.22, 0.0, 0.0), color)
			_box(parts, Vector3(0.012, 0.006, 0.006), Vector3(0.241, 0.0, -0.002), light)                             # the tip
		"needle":
			_cyl(parts, 0.004, 0.12, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), color)
		"rod":
			_cyl(parts, 0.008, 0.9, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), Color(0.4, 0.3, 0.18))
			_cyl(parts, 0.025, 0.04, Vector3(-0.3, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), color)
		"torch":
			# Unlit: the stick with a wrapped head and twine bands, no flame (held_item.gd's torch has the same colours and proportions).
			_handle(parts, 0.44, 0.016)
			_cyl(parts, 0.0185, 0.17, Vector3(0.1, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.2, 0.14, 0.09))    # the grimy top of the stick
			_cyl(parts, 0.045, 0.14, Vector3(0.17, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.34, 0.22, 0.13))   # the wrapped head
			_cyl(parts, 0.0455, 0.047, Vector3(0.2115, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.22, 0.13, 0.08))   # the charred top third
			_cyl(parts, 0.047, 0.015, Vector3(0.235, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.1, 0.06, 0.04))   # soot on the very top
			_cyl(parts, 0.0475, 0.012, Vector3(0.125, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.6, 0.5, 0.32))   # twine, worn
			_cyl(parts, 0.0485, 0.012, Vector3(0.19, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.6, 0.5, 0.32))
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
	return color.darkened(0.22).lerp(Color(0.5, 0.42, 0.34), 0.3)


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
static func _metal(parts: Array) -> void:
	(parts[parts.size() - 1] as Array).append(true)


static func _combine(parts: Array, size: float) -> ArrayMesh:
	var plain: Array = []
	var metal: Array = []

	for part in parts:
		if (part as Array).size() > 3:
			metal.append(part)
		else:
			plain.append(part)

	var result: ArrayMesh = ArrayMesh.new()

	if not plain.is_empty() or metal.is_empty():
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(plain, size))
		result.surface_set_material(0, _shared_material())

	if not metal.is_empty():
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(metal, size))
		result.surface_set_material(result.get_surface_count() - 1, _metal_material())

	return result


static func _surface_arrays(parts: Array, size: float) -> Array:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	for part in parts:
		var arrays: Array = (part[0] as PrimitiveMesh).get_mesh_arrays()
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
static func _metal_material() -> StandardMaterial3D:
	if _metal_mat == null:
		_metal_mat = StandardMaterial3D.new()
		_metal_mat.vertex_color_use_as_albedo = true
		_metal_mat.metallic = 0.8
		_metal_mat.roughness = 0.4

	return _metal_mat


static func _shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 1.0

	return _material
