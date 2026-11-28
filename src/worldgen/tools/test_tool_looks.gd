extends SceneTree
# Headless check of the tool looks brought to the pickaxe standard (Dave 2026-10-25), one group per round. Shovels: a long straight haft along x with the blade at +x, wide in z
# and thin in y, metal tiers (iron, steel) on the metal surface, wood and stone tiers on one plain surface, the blade narrowing to a point.

const BasicLook := preload("res://src/client/basic_look.gd")
const HeldItem := preload("res://src/client/held_item.gd")
const ItemTable := preload("res://src/shared/item_table.gd")

const HAND_HALF_M := 0.03   # from the middle of a closed hand to its front edge along the handle

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	# Shovels at real size for the large tier (size 1.0): about 85 cm of haft plus the grip, a 28 by 19 cm blade, scaled down for the medium (0.85) and small (0.7) tiers.
	for tier in ["wooden", "stone", "iron", "steel"]:
		for size in ["", "_medium", "_large"]:
			var id: String = tier + "_shovel" + size
			var mesh: Mesh = BasicLook.mesh_for(id)
			var metal: bool = tier in ["iron", "steel"]
			var box: AABB = mesh.get_aabb()
			var scale: float = float(BasicLook.entry(id).get("size", 1.0))
			_check(absf(scale - {"": 0.7, "_medium": 0.85, "_large": 1.0}[size]) < 0.001, id + ": size %.2f scales the real-size large shovel" % scale)
			_check(mesh.get_surface_count() == (2 if metal else 1), id + ": surfaces %d (metal tiers have the metal head surface)" % mesh.get_surface_count())
			_check(box.size.x > 0.68 * scale and box.size.x < 0.8 * scale, id + ": about 0.74 m overall at size 1, %.2f m (size %.2f)" % [box.size.x / scale, scale])
			_check(_y_extent(mesh, 0.52 * scale, 1.0, 1.0) < 0.045 * scale, id + ": the dished blade is shallow (y %.3f)" % (_y_extent(mesh, 0.52 * scale, 1.0, 1.0) / scale))
			_check(_y_extent(mesh, 0.6 * scale, 0.012 * scale, 0.012 * scale) < 0.008 * scale, id + ": a thin plate at the centre (%.4f m)" % (_y_extent(mesh, 0.6 * scale, 0.012 * scale, 0.012 * scale) / scale))
			_check(_width_near(mesh, 0.6 * scale, 0.02 * scale) > 0.17 * scale and _width_near(mesh, 0.6 * scale, 0.02 * scale) < 0.21 * scale, id + ": blade about 19 cm wide at the shoulders (%.3f)" % (_width_near(mesh, 0.6 * scale, 0.02 * scale) / scale))
			_check(_width_near(mesh, 0.74 * scale, 0.008 * scale) < 0.75 * _width_near(mesh, 0.6 * scale, 0.02 * scale), id + ": the blade ends in a narrower rounded tip")
			_check(_width_near(mesh, 0.05 * scale, 0.03 * scale) > 0.14 * scale and _width_near(mesh, 0.05 * scale, 0.03 * scale) < 0.2 * scale, id + ": a closed D-grip about 15 cm across (%.3f)" % (_width_near(mesh, 0.05 * scale, 0.03 * scale) / scale))

			var tris: int = 0

			for surface in mesh.get_surface_count():
				tris += int((mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3.0)

			_check(tris <= 1200, id + ": %d triangles (budget 1200)" % tris)

	# Metal colours: no blue tint (blue not above red by more than 15 percent), iron darker than steel, shovel metal roughness 0.55 while the pickaxe stays 0.4.
	for id in ["iron_shovel_large", "steel_shovel_large"]:
		var mesh: Mesh = BasicLook.mesh_for(id)
		var colours: PackedColorArray = mesh.surface_get_arrays(1)[Mesh.ARRAY_COLOR]
		var mean: Color = Color(0, 0, 0, 0)

		for c in colours:
			mean += c

		mean /= float(colours.size())
		_check(mean.b < mean.r * 1.15, id + ": no blue tint (mean r %.3f b %.3f)" % [mean.r, mean.b])
		var want_rough: float = 0.3 if id.begins_with("steel") else 0.65
		var want_metal: float = 0.6 if id.begins_with("steel") else 0.3
		var mat: StandardMaterial3D = mesh.surface_get_material(1) as StandardMaterial3D
		_check(absf(mat.roughness - want_rough) < 0.001 and absf(mat.metallic - want_metal) < 0.001, id + ": shovel metal roughness %.2f metallic %.2f (steel a little shinier than iron)" % [mat.roughness, mat.metallic])

	_check(absf((BasicLook.mesh_for("iron_pickaxe").surface_get_material(1) as StandardMaterial3D).roughness - 0.4) < 0.001, "the locked pickaxe keeps metal roughness 0.4")
	_check(BasicLook.mesh_for("iron_shovel_large").get_surface_count() == 2 and BasicLook.mesh_for("iron_shovel_large").surface_get_material(1) != BasicLook.mesh_for("iron_pickaxe").surface_get_material(1), "shovel and pickaxe use separate shared metal materials")

	# Carry in third person: a saw by the handle with the blade down and back about 30 degrees.
	var saw_dir: Vector3 = Basis(Vector3.RIGHT, deg_to_rad(HeldItem.THIRD_SAW_PITCH_DEG)) * HeldItem.HELD_LOOK_TURN["saw"] * Vector3(1.0, 0.0, 0.0)
	_check(saw_dir.z < -0.8 and saw_dir.y < -0.3, "the carried saw's blade points down and back (%.2f, %.2f)" % [saw_dir.y, saw_dir.z])

	# A hoe is carried upright on the hammer's line along the open hand (it lay 31 degrees off the hand and showed beside it), the hand down the haft so the
	# blade's far end is THIRD_STAFF_REACH_M away, the blade (model -Z) facing forward (+Y); a shovel hangs like a hammer.
	for id in ["wooden_hoe", "copper_hoe", "steel_hoe"]:
		var hoe: Node3D = HeldItem.look_tool_node(id)
		HeldItem.third_hold(hoe, "", "hoe")
		var haft: Vector3 = hoe.basis * Vector3.UP
		var hand_on: float = hoe.position.length()
		print("%s carried: haft %s, hand %.2f m from the model origin, blade end %.2f m from the hand" % [id, haft, hand_on, hand_on + float(hoe.get_meta("head_m"))])
		_check(haft.angle_to(HeldItem.third_hang_turn(0.0) * Vector3.UP) < 0.01, id + ": the haft hangs on the hammer's line")
		_check(absf(hand_on + float(hoe.get_meta("head_m")) - HeldItem.THIRD_STAFF_REACH_M) < 0.01 and hand_on > 0.02, id + ": the hand is on the haft, %.2f m from the blade end" % (hand_on + float(hoe.get_meta("head_m"))))
		_check((hoe.basis * Vector3.FORWARD).y > 0.5, id + ": the blade faces forward, away from the shins")
		hoe.free()

	# Axes and hammers: a straight haft along x with the head at its +x end, head wider in z than the haft is thick, all on one plain surface (no metal heads yet).
	for id in ["stone_axe", "stone_hammer"]:
		var mesh: Mesh = BasicLook.mesh_for(id)
		var box: AABB = mesh.get_aabb()
		var scale: float = float(BasicLook.entry(id).get("size", 1.0))
		_check(mesh.get_surface_count() == 1, id + ": one plain surface")
		_check(box.size.x > 0.4 * scale and box.size.x < 0.9 * scale, id + ": haft along x, %.2f m long (size %.1f)" % [box.size.x, scale])
		_check(box.size.z > 0.1 * scale, id + ": the head is wide across the haft (z %.3f)" % box.size.z)
		_check(_width_near(mesh, 0.22 * scale, 0.1 * scale) > 0.1 * scale, id + ": the head sits at the haft's end (width %.3f near x 0.22)" % _width_near(mesh, 0.22 * scale, 0.1 * scale))
	# Hoes (size 1.0): a 1.25 m haft along x, the blade hanging toward +z, thin in x, wide across y, widening toward the edge; metal tiers on the metal surface.
	for tier in ["wooden", "iron", "steel"]:   # the Stone - Hoe retired 18 Nov 2026
		var id: String = tier + "_hoe"
		var mesh: Mesh = BasicLook.mesh_for(id)
		var box: AABB = mesh.get_aabb()
		var tris: int = 0

		for surface in mesh.get_surface_count():
			tris += int((mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3.0)

		_check(mesh.get_surface_count() == (2 if tier in ["iron", "steel"] else 1), id + ": surfaces %d" % mesh.get_surface_count())
		_check(box.size.x > 1.3 and box.size.x < 1.45, id + ": about 1.37 m overall (%.2f)" % box.size.x)
		_check(box.size.y > 0.15 and box.size.y < 0.19 and box.end.z > 0.15, id + ": the blade is wide across y (%.3f) and hangs toward +z (to %.3f)" % [box.size.y, box.end.z])
		_check(tris <= 1200, id + ": %d triangles" % tris)

	# The procedural hand saw (Steel - Saw, and the stand-in while a model is not imported): about 60 cm overall, a thin blade (z extent 11 cm at the heel), narrower at the toe, on the metal surface.
	var saw: Mesh = BasicLook.mesh("saw", Color.html("#8a8a90"), 1.0, [])
	_check(saw.get_surface_count() == 2, "procedural saw: wooden grip plus the metal blade surface")
	_check(saw.get_aabb().size.x > 0.55 and saw.get_aabb().size.x < 0.66, "procedural saw: about 60 cm overall (%.2f)" % saw.get_aabb().size.x)
	_check(_width_near(saw, -0.1, 0.02) > _width_near(saw, 0.25, 0.02) + 0.02, "procedural saw: the blade narrows toward the toe (%.3f to %.3f)" % [_width_near(saw, -0.1, 0.02), _width_near(saw, 0.25, 0.02)])
	_check(_width_near(saw, -0.1, 0.015) > 0.12 and _width_near(saw, -0.1, 0.015) < 0.16, "procedural saw: about 14 cm across at the heel (%.3f)" % _width_near(saw, -0.1, 0.015))
	_check(_width_near(saw, 0.32, 0.012) < 0.06, "procedural saw: about 5 cm or less at the rounded toe (%.3f)" % _width_near(saw, 0.32, 0.012))
	_check(_tris(saw) <= 1200, "procedural saw: %d triangles" % _tris(saw))
	_check(_y_extent(saw, 0.0, 0.02, 0.03) < 0.01, "procedural saw: a thin plate (%.4f)" % _y_extent(saw, 0.0, 0.02, 0.03))
	var saw_hand_x: float = -HeldItem.look_grip_y(BasicLook.mesh_for("steel_saw"), BasicLook.entry("steel_saw"), 1.0) * HeldItem.third_choke("saw")
	_check(saw_hand_x < -0.17, "procedural saw: the third-person hand at x %.3f is behind the blade's heel (-0.17), in the grip" % saw_hand_x)

	# Dave's handsaw meshes (assets/tools/handsaws, 15 Nov 2026) for the Copper, Bronze and Iron saws: drawn from the file with its own textured material, on the
	# procedural saw's axes (handle at -x, blade toward +x, flat across y), copper the shortest, bronze a little longer, iron the longest.
	var lengths: Array = []

	for id in ["copper_saw", "bronze_saw", "hand_saw"]:
		var def: Dictionary = BasicLook.entry(id)
		var drawn: Mesh = BasicLook.mesh_for(id)
		var box: AABB = drawn.get_aabb()
		var material: StandardMaterial3D = drawn.surface_get_material(0) as StandardMaterial3D
		lengths.append(box.size.x)
		_check(drawn.get_surface_count() == 1 and material != null and material.albedo_texture != null and material.normal_texture != null, id + ": drawn from %s with its own colour and normal textures (imported?)" % def.get("model", "?"))
		_check(absf(box.size.x - float(def.get("model_length_m", 0.0))) < 0.005, id + ": %.3f m overall (looks.json %.2f)" % [box.size.x, float(def.get("model_length_m", 0.0))])
		var blade_x: float = box.position.x + 0.8 * box.size.x
		_check(_y_extent(drawn, blade_x, 0.04 * box.size.x, 1.0) < 0.6 * _width_near(drawn, blade_x, 0.04 * box.size.x), id + ": the blade lies flat, thin across y (%.3f) and deep across z (%.3f)" % [_y_extent(drawn, blade_x, 0.04 * box.size.x, 1.0), _width_near(drawn, blade_x, 0.04 * box.size.x)])
		_check(absf(box.get_center().x) < 0.002 and absf(box.get_center().y) < 0.002 and absf(box.get_center().z) < 0.002, id + ": centred on its origin")
		var x0: float = box.position.x
		_check(_y_extent(drawn, x0 + 0.06 * box.size.x, 0.04 * box.size.x, 1.0) > 1.5 * _y_extent(drawn, x0 + 0.8 * box.size.x, 0.04 * box.size.x, 1.0), id + ": the thick handle is at -x and the thin blade toward +x (%.3f vs %.3f)" % [_y_extent(drawn, x0 + 0.06 * box.size.x, 0.04 * box.size.x, 1.0), _y_extent(drawn, x0 + 0.8 * box.size.x, 0.04 * box.size.x, 1.0)])
		var edge: Vector2i = _blade_edges(drawn, box)
		_check(edge.x > int(1.5 * float(edge.y)), id + ": the toothed edge is on +z, down when held (%d vertices on the +z edge, %d on the -z spine)" % [edge.x, edge.y])
		_check(_tris(drawn) <= 5000, id + ": %d triangles (Dave's 5000 cap)" % _tris(drawn))
		_check(BasicLook.mesh_for(id) == drawn, id + ": built once and shared")
		# The hand closes on the handle, not the blade, in both views (Dave 17 Nov 2026: "it is stabbed right through his hand"): the grip point in third person
		# and first person, and the front of the fist, lie on the thick handle end.
		var held_x: float = -HeldItem.look_grip_y(drawn, def, 1.0)
		var third_x: float = held_x * HeldItem.third_choke("saw")
		var blade_t: float = _y_extent(drawn, x0 + 0.8 * box.size.x, 0.04 * box.size.x, 1.0)
		for hand_x in [held_x, third_x]:
			for at in [hand_x, hand_x + HAND_HALF_M]:   # the hand's middle and its front edge, toward the blade
				_check(_y_extent(drawn, at, 0.01, 1.0) > 1.5 * blade_t, id + ": the hand at x %.3f is on the handle at %.3f (thickness %.3f there, blade %.3f)" % [hand_x, at, _y_extent(drawn, at, 0.01, 1.0), blade_t])

	_check(lengths[0] < lengths[1] and lengths[1] < lengths[2], "copper saw shortest, bronze longer, iron longest (%.2f, %.2f, %.2f)" % lengths)

	# Stone knife: about 23 cm overall at size 1, blade about as long as the handle, a leaf blade (widest in the middle, narrow at the tip), matt stone (not bright steel).
	var knife: Mesh = BasicLook.mesh_for("stone_knife")
	var knife_scale: float = float(BasicLook.entry("stone_knife").get("size", 1.0))
	var length: float = knife.get_aabb().size.x / knife_scale
	_check(knife.get_surface_count() == 1, "stone_knife: one plain surface, no metal sheen")
	_check(length > 0.2 and length < 0.26, "stone_knife: about 23 cm overall (%.3f m)" % length)
	_check(_width_near(knife, 0.06 * knife_scale, 0.015 * knife_scale) > 2.0 * _width_near(knife, 0.14 * knife_scale, 0.008 * knife_scale), "stone_knife: leaf-shaped blade, wide in the middle and narrow at the tip")
	var brightest: float = 0.0

	for v in (knife.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray):
		brightest = maxf(brightest, v.get_luminance())

	_check(brightest < 0.4, "stone_knife: matt stone, no pale steel tones (brightest %.2f)" % brightest)
	_check(str(BasicLook.entry("stone_hammer").get("shape", "")) == "hammer", "stone_hammer is drawn as a hammer, not an axe")

	# Tool tier colours (D-TODO-4, 21 Nov 2026): every tool made in more than one metal names its tier in its look row and draws its metal in
	# that metal's colour. Tiers of one tool share the haft, so their mean colours differ only by the metal: copper redder than bronze, steel
	# lighter than iron, and no two tiers alike (a mean over the whole tool: the axe head is only about 4 percent of its vertices, so the gap bar is low). Saws are drawn through mesh() because three of them are Dave's models.
	var families: Dictionary = {"axe": ["copper_axe", "bronze_axe", "iron_axe", "steel_axe"], "pick": ["copper_pickaxe", "bronze_pickaxe", "iron_pickaxe", "steel_pickaxe"],
		"hammer": ["copper_hammer", "bronze_hammer", "iron_hammer", "steel_hammer"], "knife": ["copper_knife", "bronze_knife", "iron_knife", "steel_knife"],
		"chisel": ["copper_chisel", "bronze_chisel", "iron_chisel", "steel_chisel"], "hoe": ["copper_hoe", "bronze_hoe", "iron_hoe", "steel_hoe"],
		"shovel": ["copper_shovel", "bronze_shovel", "iron_shovel", "steel_shovel"], "sickle": ["copper_sickle", "bronze_sickle", "iron_sickle", "steel_sickle"],
		"scythe": ["copper_scythe", "bronze_scythe", "scythe", "steel_scythe"]}
	var tiers: Array[String] = ["copper", "bronze", "iron", "steel"]

	for family in families:
		var means: Array[Color] = []

		for k in range(4):
			var id: String = str(families[family][k])
			_check((BasicLook.entry(id).get("bits", []) as Array).has(tiers[k]), "%s names its tier %s in its look row" % [id, tiers[k]])
			means.append(_mean_colour(BasicLook.mesh_for(id)))

		_check(means[0].r - means[0].g > means[1].r - means[1].g, "%s: copper redder than bronze (%s, %s)" % [family, means[0], means[1]])
		_check(means[3].get_luminance() > means[2].get_luminance(), "%s: steel lighter than iron (%.3f, %.3f)" % [family, means[3].get_luminance(), means[2].get_luminance()])

		for a in range(4):
			for b in range(a + 1, 4):
				var gap: float = absf(means[a].r - means[b].r) + absf(means[a].g - means[b].g) + absf(means[a].b - means[b].b)
				_check(gap > 0.003, "%s: %s and %s tiers draw different colours (gap %.3f)" % [family, tiers[a], tiers[b], gap])

	var saws: Array[Color] = []

	for tier in tiers:
		saws.append(_mean_colour(BasicLook.mesh("saw", Color.html("#8a8a90"), 1.0, ["metal", tier])))

	_check(saws[0].r - saws[0].g > saws[1].r - saws[1].g and saws[3].get_luminance() > saws[2].get_luminance(), "saw: copper redder than bronze, steel lighter than iron")
	_check(str(BasicLook.entry("hand_saw").get("bits", [])) == str(["metal", "iron"]), "hand_saw (Iron - Saw) is the iron tier")

	# Placeholder looks 5a part 1 (21 Nov 2026): weapons, spears, arrows and bolts drawn from the existing shapes; each names its tier and builds a real mesh.
	for id in ["iron_shortsword", "steel_shortsword", "iron_greatsword", "steel_greatsword", "steel_rapier", "steel_scimitar", "iron_battleaxe", "steel_battleaxe",
			"iron_greataxe", "steel_greataxe", "iron_warhammer", "steel_warhammer", "steel_maul", "quarterstaff", "bronze_spear", "iron_spear", "steel_spear", "iron_pike",
			"iron_halberd", "steel_halberd", "iron_trident", "iron_buckler", "bronze_arrow", "iron_arrow", "steel_arrow", "wooden_bolt", "iron_bolt", "steel_bolt", "iron_lance"]:
		var row: Dictionary = BasicLook.entry(id)
		var tier: String = id.get_slice("_", 0)
		_check(str(row.get("shape", "chunk")) != "chunk", "%s has a shape of its own (%s)" % [id, str(row.get("shape", ""))])
		_check(tier not in ["iron", "steel", "bronze"] or (row.get("bits", []) as Array).has(tier), "%s names its tier in its look row" % id)
		var look: Mesh = BasicLook.mesh_for(id)
		_check(look != null and look.get_surface_count() > 0, "%s builds a mesh" % id)
	_check(_mean_colour(BasicLook.mesh_for("steel_spear")).get_luminance() > _mean_colour(BasicLook.mesh_for("iron_spear")).get_luminance(), "steel spear head lighter than iron")
	var curved_z: float = BasicLook.mesh("sword", Color.html("#9aa3ad"), 1.0, ["steel", "curved"]).get_aabb().size.z
	var straight_z: float = BasicLook.mesh("sword", Color.html("#9aa3ad"), 1.0, ["steel"]).get_aabb().size.z
	_check(curved_z > straight_z + 0.03, "the scimitar's blade curves out past the guard (%.3f m across, straight %.3f)" % [curved_z, straight_z])
	_check(BasicLook.mesh_for("quarterstaff").get_surface_count() == 2 and BasicLook.mesh_for("quarterstaff").get_aabb().size.x > 1.5, "the quarterstaff is a long staff with iron ferrules (%.2f m)" % BasicLook.mesh_for("quarterstaff").get_aabb().size.x)

	# Placeholder looks 5a part 2 (armour): drawn from the jerkin and garment shapes; metal pieces name their tier and take its colour.
	for id in ["iron_brigandine", "iron_breastplate", "iron_mail_hauberk", "steel_half_plate", "steel_plate_harness", "iron_mail_coif", "iron_gauntlets", "steel_gauntlets",
			"bronze_greaves", "iron_greaves", "steel_greaves", "iron_mail_chausses", "iron_sabatons", "steel_sabatons"]:
		var row: Dictionary = BasicLook.entry(id)
		var tier: String = id.get_slice("_", 0)
		_check(str(row.get("shape", "chunk")) in ["jerkin", "garment"], "%s is drawn as armour (%s)" % [id, str(row.get("shape", ""))])
		_check(id == "iron_brigandine" or (row.get("bits", []) as Array).has(tier), "%s names its tier in its look row" % id)
		var look: Mesh = BasicLook.mesh_for(id)
		_check(look != null and look.get_surface_count() > 0, "%s builds a mesh" % id)
	_check(_mean_colour(BasicLook.mesh_for("steel_greaves")).get_luminance() > _mean_colour(BasicLook.mesh_for("iron_greaves")).get_luminance(), "steel greaves lighter than iron")
	var light_xbow: Mesh = BasicLook.mesh_for("light_crossbow")
	var heavy_xbow: Mesh = BasicLook.mesh_for("heavy_crossbow")
	_check(str(BasicLook.entry("light_crossbow").get("shape", "")) == "crossbow" and light_xbow != null and light_xbow.get_aabb().size.z > 0.25 and light_xbow.get_aabb().size.x > 0.6, "the light crossbow is a stock with a prod across it")
	_check(heavy_xbow != null and light_xbow != null and heavy_xbow.get_surface_count() > light_xbow.get_surface_count(), "the heavy crossbow has a steel prod (a metal surface the light one lacks)")

	# Placeholder looks 5b (clothing): each piece is a garment of its own kind, the new kinds under the 300 triangle cap, and the kinds read apart.
	var kinds := {"linen_trousers": "trousers", "linen_skirt": "skirt", "linen_dress": "dress", "wool_dress": "dress", "wool_cloak": "cloak", "wool_coat": "coat", "wool_robe": "robe",
			"oilcloth_cloak": "cloak", "linen_apron": "apron", "leather_apron": "apron", "tabard": "tabard", "linen_headwrap": "headwrap", "leather_broad_brim_hat": "broad_brim",
			"fur_mittens": "mittens", "leather_shoes": "shoes", "wool_socks": "socks", "wool_scarf": "scarf"}

	for id in kinds:
		var row: Dictionary = BasicLook.entry(id)
		_check(str(row.get("shape", "")) == "garment" and (row.get("bits", []) as Array).has(kinds[id]), "%s is drawn as a %s" % [id, kinds[id]])
		var cloth: Mesh = BasicLook.mesh_for(id)
		var tris: int = _tris(cloth) if cloth != null else 0

		if str(kinds[id]) not in ["trousers", "cloak", "mittens"]:                                                       # the new kinds; trousers, cloaks and mittens are older drawings
			_check(tris > 12 and tris <= 300, "%s: %d triangles (more than a plain box, at most 300)" % [id, tris])

	_check(BasicLook.mesh_for("linen_dress").get_aabb().size.z > BasicLook.mesh_for("linen_skirt").get_aabb().size.z + 0.05, "a dress is longer than a skirt (it has a bodice)")
	_check(BasicLook.mesh_for("wool_robe").get_aabb().size.z > BasicLook.mesh_for("wool_coat").get_aabb().size.z, "a robe is longer than a coat")
	_check(BasicLook.mesh_for("leather_broad_brim_hat").get_aabb().size.x > 0.25, "the broad-brim hat has a wide brim (%.2f m)" % BasicLook.mesh_for("leather_broad_brim_hat").get_aabb().size.x)
	_check(_mean_colour(BasicLook.mesh_for("leather_apron")).get_luminance() < _mean_colour(BasicLook.mesh_for("linen_apron")).get_luminance(), "a leather apron is darker than a linen one")

	# Placeholder looks 5c (bags): each is drawn as its own kind of bag, the new kinds under the 300 triangle cap.
	var bag_kinds := {"fibre_shoulder_bag": "shoulder_bag", "leather_satchel": "satchel", "belt_pouch": "pouch", "tool_roll": "tool_roll", "wooden_pack_frame": "pack_frame",
			"weapon_scabbard": "scabbard", "utility_bandolier": "bandolier", "travellers_rucksack": "", "wicker_pack_basket": ""}

	for id in bag_kinds:
		var row: Dictionary = BasicLook.entry(id)
		var want: String = str(bag_kinds[id])
		_check(str(row.get("shape", "chunk")) != "chunk" and (want == "" or (str(row.get("shape", "")) == "bag" and (row.get("bits", []) as Array).has(want))), "%s is drawn as a bag (%s)" % [id, want])
		var bag: Mesh = BasicLook.mesh_for(id)
		var tris: int = _tris(bag) if bag != null else 0

		if want != "":                                                                                                       # the retired rucksack and pack basket reuse older drawings
			_check(tris > 12 and tris <= 300, "%s: %d triangles (more than a plain box, at most 300)" % [id, tris])

	_check(BasicLook.mesh_for("weapon_scabbard").get_aabb().size.x > 0.7, "the scabbard is sword length (%.2f m)" % BasicLook.mesh_for("weapon_scabbard").get_aabb().size.x)
	_check(BasicLook.mesh_for("weapon_scabbard").get_surface_count() == 2, "the scabbard has brass fittings on a metal surface")
	_check(BasicLook.mesh_for("belt_pouch").get_aabb().size.x < BasicLook.mesh_for("leather_satchel").get_aabb().size.x, "a belt pouch is smaller than a satchel")

	# Placeholder looks 5d (horse tack, harness, cart parts): each names its piece, stays under the 300 triangle cap, and metal fittings sit on a metal surface.
	var tack_kinds := {"rope_halter": "halter", "leather_bridle": "bridle", "riding_saddle": "saddle", "travellers_saddle": "travellers_saddle", "war_saddle": "war_saddle",
			"pack_saddle": "pack_saddle", "leather_saddlebags": "saddlebags", "wicker_panniers": "panniers", "cargo_lashings": "lashings", "light_draft_harness": "breastcollar",
			"heavy_collar_harness": "collar", "double_draft_harness": "double_harness", "double_ox_yoke": "ox_yoke", "iron_horseshoes": "horseshoes", "padded_horse_blanket": "blanket",
			"feedbag": "feedbag", "grooming_kit": "grooming", "padded_barding": "barding", "iron_mail_barding": "barding", "steel_plate_barding": "barding", "riding_boots": "boots",
			"wooden_cart_wheel": "wheel", "axle": "axle", "reinforced_wagon_wheel": "board_wheel"}

	for id in tack_kinds:
		var row: Dictionary = BasicLook.entry(id)
		_check(str(row.get("shape", "chunk")) in ["tack", "garment"] and (row.get("bits", []) as Array).has(tack_kinds[id]), "%s is drawn as a %s" % [id, tack_kinds[id]])
		var piece: Mesh = BasicLook.mesh_for(id)
		var tris: int = _tris(piece) if piece != null else 0
		_check(tris > 12 and tris <= 300, "%s: %d triangles (more than a plain box, at most 300)" % [id, tris])

	for id in ["riding_saddle", "leather_bridle", "wooden_cart_wheel", "reinforced_wagon_wheel", "iron_mail_barding"]:
		var fitted: Mesh = BasicLook.mesh_for(id)
		_check(fitted != null and fitted.get_surface_count() == 2, "%s has its iron on a metal surface" % id)

	_check(BasicLook.mesh_for("padded_barding").get_surface_count() == 1, "padded barding is all cloth, no metal surface")
	_check(_mean_colour(BasicLook.mesh_for("steel_plate_barding")).get_luminance() > _mean_colour(BasicLook.mesh_for("iron_mail_barding")).get_luminance(), "steel plate barding is lighter than iron mail")
	_check(BasicLook.mesh_for("reinforced_wagon_wheel").get_aabb().size.x > 0.9 and BasicLook.mesh_for("wooden_cart_wheel").get_aabb().size.x > 0.9, "the wheels are about a metre across")
	_check(BasicLook.mesh_for("war_saddle").get_aabb().size.y > BasicLook.mesh_for("riding_saddle").get_aabb().size.y, "a war saddle has a taller pommel and cantle than a riding saddle")

	# Placeholder looks 5e and 5f (food, cooking gear, the work tables, thread): none draws the grey chunk; the new dish kinds, cookware and packed tables stay under 300 triangles.
	var food_ids: Array = ["unbaked_flatbread", "unbaked_rye_flatbread", "unbaked_garlic_flatbread", "unbaked_honey_loaf", "unbaked_trail_bread", "unbaked_oatcakes", "unbaked_chestnut_cakes",
			"unbaked_apple_pie", "unbaked_fish_pie", "unbaked_venison_pie", "uncooked_sausages", "uncooked_meat_skewers", "uncooked_mushroom_skewers", "uncooked_crab_cakes",
			"banana_fritter_batter", "uncooked_meatballs", "smoked_meat", "dried_mushrooms", "seafood_platter", "roast_platter", "mixed_grill_platter", "charcuterie_board",
			"harvest_platter", "tavern_supper_board", "breakfast_platter", "dessert_platter", "ploughmans_board", "food_preparation_table", "leatherworking_table", "tailors_table",
			"fireplace_cooking_crane", "clay_griddle", "campfire_roasting_spit", "iron_grill_grate", "iron_frying_pan", "iron_cauldron", "thread"]
	var capped_kinds: Array = ["dough", "links", "platter", "board"]

	for id in food_ids:
		var row: Dictionary = BasicLook.entry(id)
		var food_shape: String = str(row.get("shape", "chunk"))
		_check(food_shape != "chunk", "%s has a look of its own (%s)" % [id, food_shape])
		var food_mesh: Mesh = BasicLook.mesh_for(id)
		_check(food_mesh != null and food_mesh.get_surface_count() > 0, "%s builds a mesh" % id)
		var bits: Array = row.get("bits", [])

		if food_mesh != null and (food_shape in ["cookware", "bench_pack"] or (food_shape == "dish" and bits.size() > 0 and str(bits[0]) in capped_kinds)):
			var tris: int = _tris(food_mesh)
			_check(tris > 12 and tris <= 300, "%s: %d triangles (more than a plain box, at most 300)" % [id, tris])

	for id in ["fireplace_cooking_crane", "campfire_roasting_spit", "iron_grill_grate", "iron_frying_pan", "iron_cauldron"]:
		_check(str(BasicLook.entry(id).get("shape", "")) == "cookware" and (BasicLook.entry(id).get("bits", []) as Array).has("iron"), "%s is iron cookware" % id)

	_check(BasicLook.mesh_for("iron_grill_grate").get_surface_count() == 1, "the grill grate is all iron (one metal surface)")
	_check(BasicLook.mesh_for("clay_griddle").get_surface_count() == 1, "the clay griddle has no metal")
	_check(BasicLook.mesh_for("ploughmans_board").get_aabb().size.x > BasicLook.mesh_for("ploughmans_board").get_aabb().size.z * 1.4, "a serving board is long, with a handle")
	_check(_mean_colour(BasicLook.mesh_for("unbaked_apple_pie")).get_luminance() > _mean_colour(BasicLook.mesh_for("apple_pie")).get_luminance(), "an unbaked pie is paler than a baked one")

	# Lane A pictures 22 Nov (fix forward): straight sword tips meet in a point, plate and brigandine read as armour, greaves, sabatons and chausses have shapes of their own.
	for id in ["iron_shortsword", "steel_shortsword", "iron_greatsword", "steel_greatsword", "steel_rapier"]:
		var blade: Mesh = BasicLook.mesh_for(id)
		var tip_w: float = _z_width(blade, blade.get_aabb().end.x - 0.012, INF)
		var body_w: float = _z_width(blade, 0.0, blade.get_aabb().end.x - 0.06)                                     # the blade and the back of the tip, past the guard
		_check(tip_w < body_w * 0.75, "%s: the blade ends in a point, not a fork (%.3f m wide at the tip, %.3f mid-blade)" % [id, tip_w, body_w])

	_check((BasicLook.entry("iron_brigandine").get("bits", []) as Array).has("brigandine") and BasicLook.mesh_for("iron_brigandine").get_surface_count() == 2, "the brigandine is cloth with riveted iron (a metal surface)")
	_check(BasicLook.mesh_for("steel_plate_harness").get_aabb().size.x > BasicLook.mesh_for("iron_breastplate").get_aabb().size.x + 0.15, "a full harness lays out pauldrons and vambraces beside the cuirass")

	for id in ["bronze_greaves", "iron_greaves", "steel_greaves", "iron_sabatons", "steel_sabatons", "iron_mail_chausses"]:
		var want_kind: String = "chausses" if id.ends_with("chausses") else ("sabatons" if id.ends_with("sabatons") else "greaves")
		_check((BasicLook.entry(id).get("bits", []) as Array).has(want_kind), "%s is drawn as %s" % [id, want_kind])
		_check(BasicLook.mesh_for(id).get_surface_count() == 2, "%s has its metal on a metal surface and leather straps apart" % id)

	_check(BasicLook.mesh_for("iron_greaves").get_aabb().size.z > BasicLook.mesh_for("iron_sabatons").get_aabb().size.z, "greaves are longer than sabatons")

	# The picture checker's held sweep (26 Nov 2026): these ten were held as the grey box on a stick (a "hammer"); each is held as its own look now,
	# for the player and for others (held_item.gd holds_plain_look, player_view.gd held_model). A shape with its own hand pose keeps it.
	var items: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json")) as Dictionary).get("items", {})

	for id in ["bone_club", "campfire_roasting_spit", "clay_griddle", "heavy_crossbow", "iron_grill_grate", "light_crossbow", "sewing_needle", "sling", "whetstone"]:   # not the retired stone wedge: its look is a flat wedge, longest across
		var kind: String = str((items.get(id, {}) as Dictionary).get("kind", ""))
		_check(HeldItem.holds_plain_look(id, kind), "%s (%s) is held as its own look, not the grey stick" % [id, kind])
		var node: Node3D = HeldItem.look_tool_node(id)
		var held_mesh: MeshInstance3D = node.get_child(0) as MeshInstance3D
		var long_axis: Vector3 = held_mesh.basis * Vector3(held_mesh.mesh.get_aabb().size.x, 0.0, 0.0)
		var box: Vector3 = held_mesh.mesh.get_aabb().size
		_check(box.x >= 0.8 * maxf(box.y, box.z), "%s: its mesh is longest along x, the axis laid along the hand (%s)" % [id, box])
		_check(node.has_meta("grip_y") and long_axis.length() <= HeldItem.HELD_LOOK_MAX_M + 0.001 and absf(long_axis.normalized().y) > 0.99, "%s lies along the hand's +Y, at most %.1f m (%.2f m)" % [id, HeldItem.HELD_LOOK_MAX_M, long_axis.length()])
		node.free()

	_check(not HeldItem.holds_plain_look("bucket", "container") and not HeldItem.holds_plain_look("clay_pot", "container"), "a bucket or pot is not laid along the hand (it stands up along its mesh +Y)")
	_check(not HeldItem.holds_plain_look("iron_axe", "tool") and not HeldItem.holds_plain_look("stone", "material"), "an axe keeps its own hand pose; a stone in hand is not a held tool look")

	# Metal sickles: no pale flint teeth (they read as white specks); the plain sickle keeps them.
	var plain_n: int = 0

	for surface in BasicLook.mesh_for("sickle").get_surface_count():
		plain_n += (BasicLook.mesh_for("sickle").surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

	for id in ["copper_sickle", "bronze_sickle", "iron_sickle", "steel_sickle"]:
		var n: int = 0

		for surface in BasicLook.mesh_for(id).get_surface_count():
			n += (BasicLook.mesh_for(id).surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

		_check(n < plain_n, "%s has no flint teeth (%d vertices, the plain sickle %d)" % [id, n, plain_n])

	# Third-person carry (BugsList 181): an axe, hammer, pick or mace hangs head-down outside the leg, its head no more than THIRD_HANG_DROP_M
	# below the hand; a blade points forward and a little down; all turn out to +X (the body's right, away from the thigh).
	var table: Variant = ItemTable.load_default()

	for row in [["stone_axe", "axe"], ["iron_axe", "axe"], ["stone_hammer", "hammer"], ["iron_pickaxe", "pick"], ["stone_mace", "mace"], ["iron_warhammer", "hammer"], ["steel_greataxe", "axe"], ["iron_shortsword", "sword"], ["iron_knife", "knife"], ["iron_sickle", "sickle"], ["copper_shovel", "shovel"], ["steel_shovel_large", "shovel"]]:
		var id: String = str(row[0])
		var carry_class: String = HeldItem.third_carry(id, str(table.entry(id).get("tool_class", "")))
		var node: Node3D = HeldItem.look_tool_node(id)
		HeldItem.third_hold(node, "", carry_class)
		var head_dir: Vector3 = node.basis * Vector3.UP
		var reach: float = node.position.length() + float(node.get_meta("head_m", 0.0))
		var head_end: Vector3 = node.basis * Vector3(0.0, reach, 0.0)
		print("%s carry_class %s: head %s, end %.2f m below the hand, %.2f out" % [id, carry_class, head_dir, -head_end.z, head_end.x])
		_check(carry_class == str(row[1]), "%s carries as %s (%s)" % [id, row[1], carry_class])
		_check(head_dir.x > 0.04 and head_dir.y > 0.2, "%s: the head points forward and out from the thigh (%s)" % [id, head_dir])

		if carry_class in HeldItem.THIRD_HANG_CARRIES:
			_check(-head_end.z <= HeldItem.THIRD_HANG_DROP_M + 0.01 and head_dir.z < -0.25, "%s hangs head-down, the head %.2f m below the hand (at most %.2f)" % [id, -head_end.z, HeldItem.THIRD_HANG_DROP_M])
		else:
			_check(head_dir.z < 0.0 and head_dir.z > -0.4, "%s points forward and only slightly down (%.2f)" % [id, head_dir.z])

		node.free()

	_check(HeldItem.third_hang_turn(0.3) * Vector3.UP == HeldItem.third_hang_turn(0.5) * Vector3.UP and (HeldItem.third_hang_turn(0.3) * Vector3.UP).z < -0.9, "a short tool hangs %.0f degrees forward of straight down" % HeldItem.THIRD_HANG_FWD_DEG)

	print("tool looks: %d failures" % failures)

	for id in ["spear", "wooden_spear", "fishing_rod", "wooden_pin"]:                                                  # spears, the fishing rod and the pin
		var tool_mesh: Mesh = BasicLook.mesh_for(id)
		var tool_tris: int = 0

		for si in tool_mesh.get_surface_count():
			tool_tris += int(float((tool_mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()) / 3.0)

		_check(tool_tris >= 100 and tool_tris <= 1200, id + ": %d triangles" % tool_tris)

	_check(BasicLook.mesh_for("spear").get_aabb().size.x > 1.1 and BasicLook.mesh_for("spear").get_aabb().size.x < 1.4, "spear: about 1.3 m")
	_check(BasicLook.mesh_for("spear").get_surface_count() == 1, "stone spear: a matt knapped stone point, no metal surface (Kathleen 3 Nov: the item is the Stone spear)")
	_check(BasicLook.mesh_for("wooden_spear").get_surface_count() == 1, "wooden spear: one plain surface")
	_check(BasicLook.mesh_for("fishing_rod").get_aabb().size.x > 1.5 and BasicLook.mesh_for("fishing_rod").get_aabb().size.x < 1.7, "fishing rod: about 1.6 m")
	_check(BasicLook.mesh_for("wooden_pin").get_aabb().size.x < 0.15, "wooden pin: a short peg")


	for id in ["wooden_shovel", "stone_shovel_medium", "iron_shovel_large"]:                                              # the blade plate is present at every size (not collapsed or missing)
		var plate_mesh: Mesh = BasicLook.mesh_for(id)
		var plate_scale: float = float(BasicLook.entry(id).get("size", 1.0))
		var plate_tris: int = 0
		var lo: Vector3 = Vector3(1e9, 1e9, 1e9)
		var hi: Vector3 = Vector3(-1e9, -1e9, -1e9)

		for si in plate_mesh.get_surface_count():
			var arrays: Array = plate_mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

			for k in range(0, idx.size(), 3):
				var c: Vector3 = (verts[idx[k]] + verts[idx[k + 1]] + verts[idx[k + 2]]) / 3.0

				if c.x > 0.5 * plate_scale and absf(c.z) > 0.03 * plate_scale:      # the plate beyond the socket
					plate_tris += 1

			for v in verts:
				if v.x > 0.5 * plate_scale:
					lo = lo.min(v)
					hi = hi.max(v)

		print("plate ", id, ": ", plate_tris, " triangles beyond the socket, aabb size ", hi - lo)
		_check(plate_tris > 100, id + ": the blade plate has %d triangles beyond the socket" % plate_tris)
		_check(hi.z - lo.z > 0.17 * plate_scale and hi.x - lo.x > 0.2 * plate_scale and hi.y - lo.y > 0.008 * plate_scale, id + ": the plate is %.3f wide, %.3f long, %.3f deep" % [(hi.z - lo.z) / plate_scale, (hi.x - lo.x) / plate_scale, (hi.y - lo.y) / plate_scale])


	for id in ["wooden_bow", "wooden_arrow", "stone_arrow", "quiver"]:                                                 # bow, arrows and quiver (items 269-272)
		var bow_mesh: Mesh = BasicLook.mesh_for(id)
		var bow_tris: int = 0

		for si in bow_mesh.get_surface_count():
			bow_tris += int(float((bow_mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()) / 3.0)

		_check(bow_tris >= 100 and bow_tris <= 1200, id + ": %d triangles" % bow_tris)

	# Dave 10 Nov 2026: a simple homemade self bow is about the archer's height, 1.6 to 1.8 m nock to nock; braced about 16 cm string to grip.
	var bow_box: AABB = BasicLook.mesh_for("wooden_bow").get_aabb()
	_check(bow_box.size.x > 1.65 and bow_box.size.x < 1.8, "wooden bow: %.2f m nock to nock (a self bow, 1.6 to 1.8 m)" % bow_box.size.x)
	_check(bow_box.size.z > 0.15 and bow_box.size.z < 0.22, "wooden bow: braced %.2f m deep (string to grip about 16 cm)" % bow_box.size.z)
	# Real size (Dave 10 Nov 2026: the bow was too small): the arrows were drawn at 0.55 of their 0.7 m from the days held looks were enlarged 1.8x.
	_check(BasicLook.mesh_for("wooden_arrow").get_aabb().size.x > 0.65 and BasicLook.mesh_for("wooden_arrow").get_aabb().size.x < 0.76, "wooden arrow: about 0.7 m at real size")
	_check(BasicLook.mesh_for("stone_arrow").get_aabb().size.x > 0.65 and BasicLook.mesh_for("stone_arrow").get_aabb().size.x < 0.76, "stone arrow: about 0.7 m at real size")

	quit(1 if failures > 0 else 0)


# The y extent of the vertices with x above `from_x` (an x window of `window` when it is small) and |z| below `z_limit`: how thick the blade is there.
func _y_extent(mesh: Mesh, from_x: float, window: float, z_limit: float) -> float:
	var low: float = 1e9
	var high: float = -1e9

	for surface in mesh.get_surface_count():
		for v in (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if (v.x > from_x if window >= 1.0 else absf(v.x - from_x) < window) and absf(v.z) <= (z_limit if z_limit < 1.0 else 1e9):
				low = minf(low, v.y)
				high = maxf(high, v.y)

	return high - low


# Along the blade (the front 55 percent), in 20 slices: x = vertices within 8 percent of the blade depth of the slice's +z edge, y = of its -z edge. The teeth
# make the toothed edge much denser than the plain spine.
func _blade_edges(mesh: Mesh, box: AABB) -> Vector2i:
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var from_x: float = box.position.x + 0.4 * box.size.x
	var step: float = 0.55 * box.size.x / 20.0
	var depth: float = box.size.z
	var slices: Array = []
	slices.resize(20)

	for k in 20:
		slices[k] = []

	for v in verts:
		var k: int = int(floorf((v.x - from_x) / step))

		if k >= 0 and k < 20:
			slices[k].append(v.z)

	var counts: Vector2i = Vector2i.ZERO

	for slice in slices:
		if slice.is_empty():
			continue

		var top: float = slice.max()
		var bottom: float = slice.min()

		for z in slice:
			counts.x += 1 if z > top - 0.08 * depth else 0
			counts.y += 1 if z < bottom + 0.08 * depth else 0

	return counts


func _tris(mesh: Mesh) -> int:
	var count: int = 0

	for surface in mesh.get_surface_count():
		count += int((mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3.0)

	return count


# The z extent of the vertices whose x is within `within` of `at`.
func _width_near(mesh: Mesh, at: float, within: float = 0.02) -> float:
	var low: float = 1e9
	var high: float = -1e9

	for surface in mesh.get_surface_count():
		for v in (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if absf(v.x - at) < within:
				low = minf(low, v.z)
				high = maxf(high, v.z)

	return high - low


# The mean vertex colour of every surface of a mesh.
func _mean_colour(mesh: Mesh) -> Color:
	var sum: Color = Color(0, 0, 0, 0)
	var count: int = 0

	for surface in mesh.get_surface_count():
		for c in (mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR] as PackedColorArray):
			sum += c
			count += 1

	return sum / float(maxi(count, 1))


# The width (z) of a mesh over the vertices with x between from_x and to_x: a pointed blade is narrow at its end, a forked one wide.
func _z_width(mesh: Mesh, from_x: float, to_x: float) -> float:
	var low: float = INF
	var high: float = -INF

	for surface in mesh.get_surface_count():
		for v in (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if v.x >= from_x and v.x <= to_x:
				low = minf(low, v.z)
				high = maxf(high, v.z)

	return maxf(high - low, 0.0)
