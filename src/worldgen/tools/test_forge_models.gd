extends SceneTree

# Dave's four forge meshes as the game draws them (inventory_view._forge_glb): upright, centred, base on the ground, solid, the fire
# opening toward +Z (the front of every building here) and the sizes agreeing with the placement footprints in structures.json; the medium
# forge drawn as the Brick - Forge; a Smelter's fire shows only while it is lit, never on its ghost or site.
#   godot --headless --path . --script res://src/worldgen/tools/test_forge_models.gd

const PieceLook := preload("res://src/client/piece_look.gd")
const BuildingLook := preload("res://src/client/building_look.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var view = load("res://src/client/inventory_view.gd").new()
	var structures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))["structures"]
	var tiers: Dictionary = {"basic": "stone_forge", "medium": "blacksmithy", "large": "large_forge", "master": "master_forge"}

	for tier in tiers:
		var m: Node3D = view._forge_glb("forge_" + tier)
		check(m != null, "%s model loads" % tier)

		if m == null:
			continue

		var meshes: Node3D = m.get_child(0)
		var b: AABB = view._bounds_in(meshes, m)
		var def: Dictionary = structures[tiers[tier]]
		var k: float = view._forge_scale("forge_" + tier)
		var foot: AABB = b

		if tier == "basic":   # the Primitive smithy's footprint holds its forge and the stone anvil beside it (Dave 17 Nov 2026, provisional PS-2)
			var whole: Node3D = view._make_forge(int(def["state"]))
			foot = view._bounds_in(whole, whole)
			check(foot.position.x >= -float(def["footprint_x"]) * 0.5 - 0.02 and foot.end.x <= float(def["footprint_x"]) * 0.5 + 0.02, "the Primitive smithy and its anvil (x %.2f to %.2f) stand inside its footprint" % [foot.position.x, foot.end.x])
			whole.free()

		check(absf(foot.size.x - float(def["footprint_x"])) <= 0.35 and absf(foot.size.z - float(def["footprint_z"])) <= 0.35, "%s footprint %.2f x %.2f matches the mesh %.2f x %.2f" % [tier, def["footprint_x"], def["footprint_z"], foot.size.x, foot.size.z])
		check(absf(b.position.y) < 0.02 and b.size.y > 2.0 * k and b.size.y > b.size.x * 0.6, "%s stands upright with its base on the ground (height %.2f)" % [tier, b.size.y])
		check(absf(b.position.x + b.size.x * 0.5) < 0.02 and absf(b.position.z + b.size.z * 0.5) < 0.02, "%s footprint is centred on the pivot" % tier)
		var light: Node3D = m.get_node_or_null("Light")
		var plume: Node3D = null

		for c in m.get_children():
			if c is GPUParticles3D:
				plume = c

		check(light != null and plume != null, "%s has its flame light and smoke" % tier)

		if light != null and plume != null:
			check(light.position.z > plume.position.z, "%s: the fire is in front of the chimney, opening toward +Z (fire z %.2f, smoke z %.2f)" % [tier, light.position.z, plume.position.z])
			check(light.position.y < plume.position.y * 0.6 and plume.position.y > b.size.y * 0.8, "%s: fire low, smoke at the top (fire y %.2f smoke y %.2f scale %.2f)" % [tier, light.position.y, plume.position.y, k])

		var solid: CollisionShape3D = null

		for c in m.get_children():
			if c is StaticBody3D:
				solid = c.get_child(0)

		check(solid != null and (solid.shape as BoxShape3D).size.x > 2.0 * k, "%s is solid" % tier)

	# The Brick - Forge (item system 10 Nov 2026): Dave's medium forge with its cut stone in the brick walls' surface, the iron straps and the
	# rest as he made them.
	var smithy: Node3D = view._make_smithy()
	var bricked: int = 0
	var kept_iron: bool = false

	for child in smithy.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = child

		if mesh_node.mesh == null:
			continue

		for surface in mesh_node.mesh.get_surface_count():
			var own: Material = mesh_node.mesh.surface_get_material(surface)
			var drawn: Material = mesh_node.get_surface_override_material(surface)

			if own != null and own.resource_name == "cut_stone":
				check(drawn == PieceLook.brick_skin(), "the medium forge's cut stone is drawn in brick")
				bricked += 1
			elif own != null and own.resource_name == "iron":
				kept_iron = drawn == null

	check(bricked > 0 and kept_iron, "the Brick - Forge: a brick body (%d surfaces), its iron straps kept" % bricked)
	check(PieceLook.brick_skin().uv1_world_triplanar, "its bricks are laid in world space, level whatever the model's own axes")
	smithy.free()

	# A Smelter's fire burns only while its row says lit (Dave 17 Nov 2026: "it needs to show no fire when its not lit"): not as a blueprint
	# ghost, not as a site, not cold; every tier. The built Primitive smithy that shares the Primitive smelter's model keeps its fire.
	for kind in ["smelter", "improved_smelter", "large_forge"]:
		var state: int = int(structures[kind]["state"])

		for extra in [{}, {"lit": false}, {"lit": true}, {"lit": true, "site": []}]:
			var model: Node3D = view._model_for_state(state, extra)
			var flames: Node3D = model.get_node_or_null("Flames") as Node3D
			var smoke: GPUParticles3D = model.get_node_or_null("ForgeSmoke") as GPUParticles3D
			var burns: bool = bool(extra.get("lit", false)) and not extra.has("site")
			check(flames != null and smoke != null and flames.visible == burns and smoke.visible == burns and smoke.emitting == burns, "%s with %s: fire %s (flames %s, smoke %s)" % [kind, str(extra), "shown" if burns else "hidden", str(flames.visible) if flames != null else "none", str(smoke.emitting) if smoke != null else "none"])
			model.free()

		var ghost: Node3D = view.ghost_model(state)
		check((ghost.get_node_or_null("Flames") as Node3D) != null and not (ghost.get_node_or_null("Flames") as Node3D).visible, "%s blueprint ghost shows no fire" % kind)
		ghost.free()

	var smithy_fire: Node3D = view._model_for_state(int(structures["stone_forge"]["state"]), {})
	check(smithy_fire.get_node_or_null("StoneAnvil") != null, "the Primitive smithy has its stone anvil beside the fire (Dave 17 Nov 2026)")
	smithy_fire.free()

	# Every smithy's fire follows its row's "forge" (Dave 21 Nov 2026): 0 cold, 1 red coals when idle, 2 a bright flare while making.
	for kind in ["stone_forge", "blacksmithy", "advanced_smithy", "master_forge"]:
		if not structures.has(kind):
			continue

		for look in [0, 1, 2]:
			var m: Node3D = view._model_for_state(int(structures[kind]["state"]), {"forge": look})
			var fl: Node3D = m.get_node_or_null("Flames") as Node3D
			var tongues: Node3D = fl.get_node_or_null("Tongues") as Node3D if fl != null else null
			var plume: GPUParticles3D = m.get_node_or_null("ForgeSmoke") as GPUParticles3D
			var glow: OmniLight3D = m.get_node_or_null("Light") as OmniLight3D
			var ok: bool = fl != null and tongues != null and glow != null and fl.visible == (look >= 1) and tongues.visible == (look == 2) and (plume == null or plume.emitting == (look == 2))
			check(ok and (look == 0 or glow.light_energy > 0.0) and (look < 2 or glow.light_energy > 2.0 * float(BuildingLook.SMITHY_GLOW[1][0])), "%s with forge %d: %s" % [kind, look, ["cold", "red coals", "the flare"][look]])
			m.free()
	var smelter_model: Node3D = view._model_for_state(int(structures["smelter"]["state"]), {})
	check(smelter_model.get_node_or_null("StoneAnvil") == null, "the Primitive smelter, which shares the model, has no anvil")
	smelter_model.free()

	# No smithy blueprint burns (Dave 17 Nov 2026: "it currently has a fire in the blueprint that is burning before you make it"): ghost or site.
	for kind in ["stone_forge", "blacksmithy", "advanced_smithy", "master_forge"]:
		if not structures.has(kind):
			continue

		var smithy_state: int = int(structures[kind]["state"])

		for blueprint in [view.ghost_model(smithy_state), view._model_for_state(smithy_state, {"site": []})]:
			var flames_bp: Node3D = blueprint.get_node_or_null("Flames") as Node3D
			var smoke_bp: GPUParticles3D = blueprint.get_node_or_null("ForgeSmoke") as GPUParticles3D
			check((flames_bp == null or not flames_bp.visible) and (smoke_bp == null or not smoke_bp.emitting), "%s blueprint shows no fire or smoke" % kind)
			blueprint.free()

	print("forge models: %d failures" % failures)
	quit(1 if failures > 0 else 0)
