extends SceneTree

# A held item in the third-person hand, photographed in seconds: the game's own body (MyCharacter.make_avatar) standing in its idle clip on a flat
# floor, the item built and posed by the same code the game uses (HeldItem.look_tool_node, third_hold, third_fist_on), one PNG per camera angle.
# No server, no world, no streaming: for the hold itself (Dave 17 Nov 2026: the look rig sat 2 to 5 minutes per shot). Not the game's lighting,
# terrain or grass; use tools/look_rig.sh for the item in the world.
#
#   godot --path . --script res://tools/shot_held.gd -- --item=copper_saw --out=C:/DynastyLane/logs/<job>/shots
#   options: --angles="name:deg:dist;..."  camera deg round the body from its front (0 front, 90 its left, -90 its right, 180 behind), dist m away;
#                                          under 2 m it aims at the held item, else at the chest (default right:-90:1.6;left:90:1.6;hand:-90:0.7;front:0:1.6)
#            --name=NAME   file prefix (default the item id): NAME_<angle>.png
#            --clip=idle   the body's clip (any clip of the body: walk, run, crouch ...)
#            --measure     also print how the handle lies on the hand, in the mount's frame: the palm's facing, the hand's line and the handle's line, and
#                          the handle's angle out of the palm's plane (0: it lies flat across the palm; 90: it runs straight through it)
#            --fist=ball   the old ball fist round the grip instead of the body's own hand closed on it (dynasty_grip.gd, BugsList 177: before pictures)
# Needs a window and a GPU like tools/shot_node.gd (a window flashes up for a few seconds); under --headless nothing is drawn and it exits 4.
# Prints one "shot held: saved PATH" line per picture and "shot held: N picture(s) in T s"; exit 4 when a picture was not saved, 2 on a bad item.

const HeldItem := preload("res://src/client/held_item.gd")
const BasicLook := preload("res://src/client/basic_look.gd")
const MyCharacter := preload("res://src/client/character/my_character.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const GripScript := preload("res://src/client/character/dynasty_grip.gd")

const SIZE := Vector2i(1280, 720)
const FOV := 75.0          # the game's FOV_BASE
const CHEST_Y := 0.95      # where a wide shot aims, above the feet (shot_runner _side_view)


func _init() -> void:
	var started: int = Time.get_ticks_msec()
	var item: String = ""
	var out: String = "user://shots"
	var prefix: String = ""
	var clip: String = "idle"
	var measure: bool = false
	var angles_text: String = "right:-90:1.6;left:90:1.6;hand:-90:0.7;front:0:1.6"

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--item="):
			item = a.trim_prefix("--item=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--name="):
			prefix = a.trim_prefix("--name=")
		elif a.begins_with("--clip="):
			clip = a.trim_prefix("--clip=")
		elif a.begins_with("--angles="):
			angles_text = a.trim_prefix("--angles=")
		elif a == "--measure":
			measure = true
		elif a == "--fist=ball":
			GripScript.closes = false   # the old ball fist round the grip, for a before picture (BugsList 177)

	var shape: String = str(BasicLook.entry(item).get("shape", ""))

	var plain: bool = item != "" and HeldItem.holds_plain_look(item, str(ItemTableScript.load_default().entry(item).get("kind", "")))   # a look held along the hand (a crossbow, a whetstone), as the game does

	if item == "" or not (HeldItem.HELD_LOOK_TURN.has(shape) or plain) or shape in ["bow", "hand_net", "shaft"]:
		print("shot held: FAIL %s has no held look this tool can pose (shape '%s'; bows, nets and spears are held by code of their own, use tools/look_rig.sh)" % [item, shape])
		quit(2)
		return

	if prefix == "":
		prefix = item

	DirAccess.make_dir_recursive_absolute(out)
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(20, 20)
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.32, 0.42, 0.22)
	plane.material = floor_material
	floor_mesh.mesh = plane
	vp.add_child(floor_mesh)
	root.add_child(vp)

	var avatar: Node3D = MyCharacter.make_avatar()   # faces -Z, feet at its origin
	vp.add_child(avatar)
	await process_frame

	if avatar.has_method("play"):
		avatar.call("play", clip)

	var tool_class: String = str(ItemTableScript.load_default().entry(item).get("tool_class", ""))
	var model: Node3D = HeldItem.look_tool_node(item)
	var mount: Node3D = avatar.get("hand_mount_r") as Node3D

	if mount == null:
		print("shot held: FAIL the body has no right hand mount")
		quit(2)
		return

	mount.add_child(model)
	HeldItem.third_hold(model, "", HeldItem.third_carry(item, tool_class))
	var tint: Color = Color.WHITE
	var worn: Variant = avatar.get("_skin_material")

	if worn is BaseMaterial3D:
		tint = (worn as BaseMaterial3D).albedo_color   # the body's skin tint, as held_item.gd _third_skin_color

	HeldItem.third_fist_on(model, Color(HeldItem.THIRD_SKIN.r * tint.r, HeldItem.THIRD_SKIN.g * tint.g, HeldItem.THIRD_SKIN.b * tint.b)).visible = true
	if measure:
		await create_timer(0.4).timeout
		_measure(avatar, mount, model, item)

	var cam: Camera3D = Camera3D.new()
	cam.fov = FOV
	vp.add_child(cam)
	cam.current = true
	await create_timer(0.4).timeout   # the clip blends in and the hand bone carries the model to its pose
	var saved: int = 0
	var wanted: int = 0

	for part in angles_text.split(";", false):
		var bits: PackedStringArray = part.split(":", false)

		if bits.size() != 3 or not bits[1].is_valid_float() or not bits[2].is_valid_float():
			print("shot held: --angles error: %s is not name:deg:dist" % part)
			continue

		wanted += 1
		var deg: float = deg_to_rad(float(bits[1]))
		var dist: float = float(bits[2])
		var aim: Vector3 = model.global_position if dist < 2.0 else avatar.global_position + Vector3(0.0, CHEST_Y, 0.0)
		var side: Vector3 = avatar.global_transform.basis * Vector3(-sin(deg), 0.0, -cos(deg))
		cam.global_position = aim + side * dist + Vector3(0.0, 0.1, 0.0)
		cam.look_at(aim, Vector3.UP)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = vp.get_texture().get_image()
		var path: String = "%s/%s_%s.png" % [out, prefix, bits[0]]

		if image != null and image.save_png(path) == OK:
			saved += 1
			print("shot held: saved %s (angle %s, %.2f m, tool_class %s, grip %.3f m)" % [path, bits[1], dist, tool_class, float(model.get_meta("grip_y", 0.0))])
		else:
			print("shot held: FAILED to save %s" % path)

	print("shot held: %d picture(s) in %.1f s" % [saved, float(Time.get_ticks_msec() - started) / 1000.0])
	quit(0 if saved == wanted and saved > 0 else 4)


# --measure: the palm's facing (the hand bone's +Z, dynasty_body.gd GRIP_PALM_M), wrist to grip and the handle (the model's +Y), all in the mount's frame.
func _measure(avatar: Node3D, mount: Node3D, model: Node3D, item: String) -> void:
	var skeleton: Skeleton3D = avatar.get("skeleton") as Skeleton3D
	var hand: int = skeleton.find_bone("mixamorig_RightHand") if skeleton != null else -1

	if hand < 0:
		print("shot held: measure FAIL no right hand bone")
		return

	var bone: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand)
	var to_mount: Basis = mount.global_basis.orthonormalized().inverse()
	var palm: Vector3 = (to_mount * bone.basis.z).normalized()
	var along: Vector3 = (to_mount * (mount.global_position - bone.origin)).normalized()
	var shaft: Vector3 = (model.basis * Vector3.UP).normalized()
	var out_deg: float = rad_to_deg(asin(clampf(absf(shaft.dot(palm)), 0.0, 1.0)))
	var lowest: float = INF

	for child in model.find_children("*", "MeshInstance3D", true, false):
		var drawn: MeshInstance3D = child as MeshInstance3D
		var box: AABB = drawn.global_transform * drawn.get_aabb()
		lowest = minf(lowest, box.position.y)

	print("shot held: measure %s palm %s hand %s handle %s out of palm plane %.0f deg, to the hand line %.0f deg; hand %.2f m up, tool's lowest point %.2f m up" % [item, str(palm), str(along), str(shaft), out_deg, rad_to_deg(shaft.angle_to(along)), mount.global_position.y - avatar.global_position.y, lowest - avatar.global_position.y])
