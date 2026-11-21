extends SceneTree

# Hair styles in the character creator (Dave 20 Nov 2026: his Meshy hair models; "everyone is allowed to use any hair style ... we will just include them all in the lineup").
# (The size bounds allow a jaw-length bob, Medium bob, 21 Nov 2026: up to 26 cm across, ending up to 12 cm below the head joint.)
# Checks: every style of hair_models.gd is imported as one mesh, one-sided, casting ordinary shadows, with its textures VRAM Compressed (docs/design/CHARACTER_MESHES.md);
# body_1 and body_2 wear every style on the head bone, sitting on the head (crown, sides and back) in the idle pose; the Head slider grows the hair with the head; changing
# the style swaps the one hair node and "" takes it off; the hair colour tints it (the default colour leaves it as painted); the creator offers every style and no hair
# in one lineup; share codes keep the style (version 5) and older codes load with no hair.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_hair_styles.gd
const Body := preload("res://src/client/character/dynasty_body.gd")
const HairModels := preload("res://src/client/character/hair_models.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const Logic := preload("res://src/client/character/creator_logic.gd")

const CROWN_DROP_M := 0.08
# The middle of Body 1's skull above the ears in its model space (tools/hair/body_fit.py skull_box of Dynasty_Base_Male.glb), where every hair
# glb is fitted; on another body it is carried by that body's hair_fit like the hair.
const SKULL_MID := Vector3(-0.0007, 1.655, 0.0002)

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


func _hair_mesh(body: Node3D) -> MeshInstance3D:
	if body.hair == null:
		return null

	var found: Array = body.hair.find_children("*", "MeshInstance3D", true, false)
	return found[0] if not found.is_empty() else null


# The hair's box in world space and the head's crown and middle as drawn, read in skeleton_updated (after the sliders' modifier), the way test_dynasty_body_2.gd reads bones.
func _measure(body: Node3D) -> Dictionary:
	var out: Dictionary = {}
	var s: Skeleton3D = body.skeleton
	var done: Array = [false]
	var grab: Callable = func() -> void:
		if done[0]:
			return

		var mesh: MeshInstance3D = _hair_mesh(body)

		if mesh == null:
			return

		var head: Transform3D = s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_Head"))
		# The hair rides on the head bone: its box is that of its corners carried by the bone's drawn pose and the hair's own place under it. (Carrying the
		# mesh's own box instead turns it with the head and swells it: the PC lane read a long style's top 6 cm high that way, 20 Nov 2026.)
		var xf: Transform3D = head * (body.hair.get_child(0) as Node3D).transform * mesh.transform
		var corners: PackedVector3Array = mesh.mesh.get_faces()
		var box: AABB = AABB(xf * corners[0], Vector3.ZERO)
		var top_end: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_HeadTop_End"))).origin
		# The crown: the hair within CROWN_DROP_M below the top bone, for centring on the skull. A long style's lower hair swings behind the head as
		# the idle pose tips it, and the top bone's tip stands about 4 cm in front of the skull's middle, so the whole box against that bone is no
		# measure of where the hair sits (Lane B on 27f5f5d2: Medium bob 0.068 m off).
		var crown: AABB = AABB()
		var has_crown: bool = false

		for corner in corners:
			var at: Vector3 = xf * corner
			box = box.expand(at)

			if at.y < top_end.y - CROWN_DROP_M:
				continue

			crown = crown.expand(at) if has_crown else AABB(at, Vector3.ZERO)
			has_crown = true

		out["box"] = box
		out["top"] = top_end
		out["crown"] = crown
		out["skull"] = xf * SKULL_MID
		out["head"] = head.origin
		done[0] = true
	s.skeleton_updated.connect(grab)

	for i in range(4):
		await process_frame

	s.skeleton_updated.disconnect(grab)
	return out


func _init() -> void:
	# The files: one mesh each, one-sided, ordinary shadows, textures VRAM Compressed with their PNGs committed.
	_check(HairModels.lineup().size() == HairModels.STYLES.size() + 1 and HairModels.lineup()[0] == HairModels.NONE, "the lineup is no hair, then every style")

	for id in HairModels.STYLES:
		var path: String = HairModels.glb(id)
		var packed: PackedScene = load(path) as PackedScene
		_check(packed != null, "%s: %s is imported" % [id, path])

		if packed == null:
			continue

		var inst: Node = packed.instantiate()
		var meshes: Array = inst.find_children("*", "MeshInstance3D", true, false)
		_check(meshes.size() == 1, "%s: one mesh (got %d)" % [id, meshes.size()])

		for m in meshes:
			var mi: MeshInstance3D = m
			_check(mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "%s: casts shadows On, not Double-Sided" % id)
			var mat: BaseMaterial3D = mi.get_active_material(0) as BaseMaterial3D
			_check(mat != null and mat.cull_mode == BaseMaterial3D.CULL_BACK, "%s: the material is one-sided" % id)
			_check(mat != null and mat.albedo_texture != null and mat.normal_texture != null, "%s: colour and normal textures are on" % id)
			var faces: int = int(mi.mesh.get_faces().size() / 3.0) if mi.mesh != null else 0
			_check(faces > 500 and faces < 40000, "%s: %d triangles" % [id, faces])

		inst.free()

		for tex in ["texture_0", "normal", "texture_0_metallic_roughness"]:
			var png: String = path.get_basename() + "_" + tex + ".png"
			_check(FileAccess.file_exists(png), "%s: %s is committed" % [id, png.get_file()])
			var settings: String = FileAccess.get_file_as_string(png + ".import")
			_check(settings.contains("compress/mode=2") and settings.contains("mipmaps/generate=true"), "%s: %s is VRAM Compressed with mipmaps" % [id, png.get_file()])
			_check(settings.contains("compress/normal_map=1") == (tex == "normal"), "%s: %s is a normal map only if it is the normal map" % [id, png.get_file()])

	# Every style on both bodies, in the idle pose: on the head, not floating, not sunk.
	for model in ["body_1", "body_2"]:
		var body: Node3D = Body.new(model)
		root.add_child(body)
		body.play("idle", 1.0, 0.0)
		var g: Dictionary = Generator.make_genome()
		body.set_proportions(g)
		_check(body.hair == null, "%s: a new character has no hair" % model)

		for id in HairModels.STYLES:
			g["hair_model"] = id
			body.set_proportions(g)
			_check(body.hair != null and body.hair.bone_name == "mixamorig_Head", "%s %s: the hair hangs on the head bone" % [model, id])
			_check(body.skeleton.find_children("Attach_Hair*", "BoneAttachment3D", false, false).size() == 1, "%s %s: one hair node" % [model, id])
			var m: Dictionary = await _measure(body)

			if m.is_empty():
				_check(false, "%s %s: the hair was drawn" % [model, id])
				continue

			var box: AABB = m["box"]
			var top: Vector3 = m["top"]
			_check(box.end.y > top.y - 0.03 and box.end.y < top.y + 0.06, "%s %s: the hair's top is at the crown (%.3f m, crown %.3f m)" % [model, id, box.end.y, top.y])
			_check(box.position.y > m["head"].y - 0.12, "%s %s: nothing hangs far below the head joint (bottom %.3f m, joint %.3f m)" % [model, id, box.position.y, m["head"].y])
			var crown_mid: Vector3 = (m["crown"] as AABB).get_center()
			var skull: Vector3 = m["skull"]
			var off: float = Vector2(crown_mid.x - skull.x, crown_mid.z - skull.z).length()
			_check(off < 0.03, "%s %s: the hair's crown is centred over the skull (%.3f m off)" % [model, id, off])
			# And the skull the hair is fitted to sits on this body's head: the top bone's tip stands about 4 cm in front of the skull's middle.
			var placed: float = Vector2(skull.x - top.x, skull.z - top.z).length()
			_check(placed < 0.08, "%s %s: the hair sits on this body's head (skull middle %.3f m from the top bone)" % [model, id, placed])
			_check(box.size.x > 0.13 and box.size.x < 0.26 and box.size.z > 0.15 and box.size.z < 0.26, "%s %s: the hair is head sized (%.3f x %.3f m)" % [model, id, box.size.x, box.size.z])

		# The Head slider grows the hair with the head.
		g["hair_model"] = "crew_cut"
		g["head"] = 0.0
		body.set_proportions(g)
		var plain: Dictionary = await _measure(body)
		g["head"] = 1.0
		body.set_proportions(g)
		var big: Dictionary = await _measure(body)

		if not plain.is_empty() and not big.is_empty():
			_check((big["box"] as AABB).size.x > (plain["box"] as AABB).size.x * 1.04, "%s: Head +1 makes the hair bigger with the head (%.3f m from %.3f m)" % [model, (big["box"] as AABB).size.x, (plain["box"] as AABB).size.x])

		# Colour: the default leaves it as painted, another colour tints it, and the body's hair material is its own copy.
		g["head"] = 0.0
		body.set_proportions(g)
		var mat: BaseMaterial3D = _hair_mesh(body).get_surface_override_material(0) as BaseMaterial3D
		_check(mat != null and mat.albedo_color.is_equal_approx(Color(1, 1, 1)), "%s: the default hair colour leaves the hair as painted" % model)
		g["hair"] = Color(0.7, 0.55, 0.25)
		body.set_proportions(g)
		_check(mat != null and mat.albedo_color.r > 1.5, "%s: a fair hair colour brightens it" % model)
		g["hair_model"] = ""
		body.set_proportions(g)
		await process_frame
		_check(body.hair == null and body.skeleton.find_children("Attach_Hair*", "BoneAttachment3D", false, false).is_empty(), "%s: no hair takes it off" % model)
		g["hair_model"] = "no_such_style"
		body.set_proportions(g)
		_check(body.hair == null, "%s: an unknown style shows no hair" % model)
		body.queue_free()

	# The creator and share codes.
	var logic: RefCounted = Logic.new({}, 5)
	logic.set_hair_model("slicked_back")
	var back: Dictionary = Generator.decode(logic.code())
	_check(str(back.get("hair_model", "?")) == "slicked_back", "a share code keeps the hair style")
	var plain_code: Dictionary = Generator.make_genome()
	_check(str(Generator.decode(Generator.encode(plain_code)).get("hair_model", "?")) == "", "a share code with no hair loads with no hair")
	var bad: Dictionary = Generator.make_genome()
	bad["hair_model"] = "Bad Id!"
	_check(str(Generator.decode(Generator.encode(bad)).get("hair_model", "?")) == "", "an id with other letters is not written")
	var v4: PackedByteArray = Marshalls.base64_to_raw(Generator.encode(plain_code))
	v4 = v4.slice(0, v4.size() - 2)       # drop the version 5 length byte and the check byte
	v4[0] = 4
	v4.append(Generator._crc8(v4))
	var old: Dictionary = Generator.decode(Marshalls.raw_to_base64(v4))
	_check(not old.is_empty() and str(old["hair_model"]) == "", "a version 4 code still loads, with no hair")

	print("test_hair_styles: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(1 if _fails > 0 else 0)
