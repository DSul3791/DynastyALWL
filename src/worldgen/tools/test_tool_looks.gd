extends SceneTree
# Headless check of the tool looks brought to the pickaxe standard (Dave 2026-10-25), one group per round. Spades: a long straight haft along x with the blade at +x, wide in z
# and thin in y, metal tiers (iron, steel) on the metal surface, wood and stone tiers on one plain surface, the blade narrowing to a point.

const BasicLook := preload("res://src/client/basic_look.gd")
const HeldItem := preload("res://src/client/held_item.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	# Spades at real size for the large tier (size 1.0): about 85 cm of haft plus the grip, a 28 by 19 cm blade, scaled down for the medium (0.85) and small (0.7) tiers.
	for tier in ["wooden", "stone", "iron", "steel"]:
		for size in ["", "_medium", "_large"]:
			var id: String = tier + "_spade" + size
			var mesh: Mesh = BasicLook.mesh_for(id)
			var metal: bool = tier in ["iron", "steel"]
			var box: AABB = mesh.get_aabb()
			var scale: float = float(BasicLook.entry(id).get("size", 1.0))
			_check(absf(scale - {"": 0.7, "_medium": 0.85, "_large": 1.0}[size]) < 0.001, id + ": size %.2f scales the real-size large spade" % scale)
			_check(mesh.get_surface_count() == (2 if metal else 1), id + ": surfaces %d (metal tiers have the metal head surface)" % mesh.get_surface_count())
			_check(box.size.x > 1.1 * scale and box.size.x < 1.25 * scale, id + ": about 1.18 m overall at size 1, %.2f m (size %.2f)" % [box.size.x / scale, scale])
			_check(box.size.y < 0.07 * scale, id + ": the blade is thin (y %.3f)" % box.size.y)
			_check(_width_near(mesh, 0.5 * scale, 0.02 * scale) > 0.17 * scale and _width_near(mesh, 0.5 * scale, 0.02 * scale) < 0.21 * scale, id + ": blade about 19 cm wide at the shoulders (%.3f)" % (_width_near(mesh, 0.5 * scale, 0.02 * scale) / scale))
			_check(_width_near(mesh, 0.738 * scale, 0.008 * scale) < 0.55 * _width_near(mesh, 0.5 * scale, 0.02 * scale), id + ": the blade tapers to a rounded tip")
			_check(_width_near(mesh, -0.36 * scale, 0.02 * scale) > 0.14 * scale and _width_near(mesh, -0.36 * scale, 0.02 * scale) < 0.18 * scale, id + ": a closed D-grip about 15 cm across (%.3f)" % (_width_near(mesh, -0.36 * scale, 0.02 * scale) / scale))

			var tris: int = 0

			for surface in mesh.get_surface_count():
				tris += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3

			_check(tris <= 1200, id + ": %d triangles (budget 1200)" % tris)

	# Metal colours: no blue tint (blue not above red by more than 15 percent), iron darker than steel, spade metal roughness 0.55 while the pickaxe stays 0.4.
	for id in ["iron_spade_large", "steel_spade_large"]:
		var mesh: Mesh = BasicLook.mesh_for(id)
		var colours: PackedColorArray = mesh.surface_get_arrays(1)[Mesh.ARRAY_COLOR]
		var mean: Color = Color(0, 0, 0, 0)

		for c in colours:
			mean += c

		mean /= float(colours.size())
		_check(mean.b < mean.r * 1.15, id + ": no blue tint (mean r %.3f b %.3f)" % [mean.r, mean.b])
		_check(absf((mesh.surface_get_material(1) as StandardMaterial3D).roughness - 0.55) < 0.001, id + ": metal roughness 0.55")

	_check(absf((BasicLook.mesh_for("iron_pickaxe").surface_get_material(1) as StandardMaterial3D).roughness - 0.4) < 0.001, "the locked pickaxe keeps metal roughness 0.4")
	_check(BasicLook.mesh_for("iron_spade_large").get_surface_count() == 2 and BasicLook.mesh_for("iron_spade_large").surface_get_material(1) != BasicLook.mesh_for("iron_pickaxe").surface_get_material(1), "spade and pickaxe use separate shared metal materials")

	# Carry: a spade carried in third person points its blade down, at least 20 degrees from vertical but not past it (blade end below the hand).
	var carry: Basis = Basis(Vector3.RIGHT, deg_to_rad(HeldItem.THIRD_SPADE_PITCH_DEG)) * HeldItem.HELD_LOOK_TURN["spade"]
	var blade_dir: Vector3 = carry * Vector3(1.0, 0.0, 0.0)
	var from_vertical: float = rad_to_deg(acos(clampf(-blade_dir.z, -1.0, 1.0)))
	print("spade carried: blade direction ", blade_dir, " is ", from_vertical, " degrees from straight down")
	_check(blade_dir.z < -0.5 and from_vertical >= 20.0, "the carried spade points its blade down, %.0f degrees from vertical" % from_vertical)

	# Axes and hammers: a straight haft along x with the head at its +x end, head wider in z than the haft is thick, all on one plain surface (no metal heads yet).
	for id in ["stone_axe", "stone_hammer", "wooden_hammer"]:
		var mesh: Mesh = BasicLook.mesh_for(id)
		var box: AABB = mesh.get_aabb()
		var scale: float = float(BasicLook.entry(id).get("size", 1.0))
		_check(mesh.get_surface_count() == 1, id + ": one plain surface")
		_check(box.size.x > 0.4 * scale and box.size.x < 0.9 * scale, id + ": haft along x, %.2f m long (size %.1f)" % [box.size.x, scale])
		_check(box.size.z > 0.1 * scale, id + ": the head is wide across the haft (z %.3f)" % box.size.z)
		_check(_width_near(mesh, 0.22 * scale, 0.1 * scale) > 0.1 * scale, id + ": the head sits at the haft's end (width %.3f near x 0.22)" % _width_near(mesh, 0.22 * scale, 0.1 * scale))
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

	_check(brightest < 0.3, "stone_knife: matt stone, no pale steel tones (brightest %.2f)" % brightest)
	_check(str(BasicLook.entry("wooden_hammer").get("shape", "")) == "hammer", "wooden_hammer is drawn as a mallet, not an axe")

	print("tool looks: %d failures" % failures)
	quit(1 if failures > 0 else 0)


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
