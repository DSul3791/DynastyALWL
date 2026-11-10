extends SceneTree

# The client draws the NPCs the server lists (Mandy, 2026-10-21, after "No NPC drawn (roster 2, drawn 0)"): the roster and rows of
# the two spawn NPCs must give two drawn bodies next to spawn, in every state, and survive running frames. Fails if the roster has
# NPCs but none is drawn.
#   godot --headless --path . --script res://src/worldgen/tools/test_npc_view.gd

const NpcViewScript := preload("res://src/client/npc_view.gd")
const DynastyBodyScript := preload("res://src/client/character/dynasty_body.gd")
const Shapes := preload("res://src/client/character/dynasty_shapes.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


# Dave 4 Nov 2026: the NPCs wear his body with every creator slider randomized. Each one is a Dynasty body whose genome comes from its id (the same look every visit),
# no two of the listed NPCs share a genome, and the width and face sliders reach the mesh as blend shape weights.
func _check_bodies(view: Node3D) -> void:
	if not DynastyBodyScript.available():
		print("test_npc_view: the Dynasty glb is not imported here, the NPC body checks are skipped")
		return

	var seen: Dictionary = {}
	var shaped: int = 0

	for id in view._bodies:
		var rig: Node3D = (view._bodies[id]["node"] as Node3D).get_node("Rig")
		check(rig.get_script() == DynastyBodyScript, "NPC %s wears Dave's body" % id)

		if rig.get_script() != DynastyBodyScript:
			continue

		var g: Dictionary = rig.genome
		check(g == NpcViewScript.genome_of(id), "NPC %s has the genome drawn from its id" % id)
		check(rig.proportions != null, "NPC %s has its bone lengths set" % id)
		var key: String = JSON.stringify([g.get("height"), g.get("build"), g.get("jaw"), g.get("nose"), g.get("skin")])
		check(not seen.has(key), "NPC %s does not share its sliders with NPC %s" % [id, seen.get(key, "")])
		seen[key] = id
		var mesh: MeshInstance3D = rig.body_mesh

		for name in Shapes.NAMES:
			var i: int = mesh.find_blend_shape_by_name(name)

			if i >= 0 and absf(mesh.get_blend_shape_value(i) - clampf(float(g.get(name, 0.0)), -1.0, 1.0)) < 0.001 and absf(float(g.get(name, 0.0))) > 0.001:
				shaped += 1

	check(shaped > 0, "the width and face sliders reach the NPC meshes as blend shape weights (%d)" % shaped)


# Dave 10 Nov 2026, "Edda is still sitting on the ground": a seated NPC plays the chair clip (the player's), and the rig is lifted so its hips
# joint rests 0.07 m over the chair's 0.45 m seat, not the ground sit inside the chair.
func _check_chair_sit() -> void:
	if not DynastyBodyScript.available():
		print("test_npc_view: the Dynasty glb is not imported here, the chair sit check is skipped")
		return

	var node: Node3D = Node3D.new()
	node.position = Vector3(53267.0, 29.9, 68073.0)
	get_root().add_child(node)
	var rig: Node3D = DynastyBodyScript.new()
	rig.set_proportions(NpcViewScript.genome_of("edda"))
	node.add_child(rig)
	check(NpcViewScript._sit_clip(rig) == "sit_chair", "a seated NPC plays the chair clip, not the ground sit")
	var s: Skeleton3D = rig.skeleton
	var hips_at = func() -> float: return (node.global_transform.affine_inverse() * (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_Hips")).origin)).y

	for clip in ["sit", "sit_chair"]:
		rig.position.y = 0.0
		rig.play(clip, 1.0, 0.0)
		rig.animation_player.seek(0.0, true)
		await process_frame
		await process_frame
		rig.position.y = NpcViewScript.seat_lift(node, rig)
		await process_frame
		var hips: float = hips_at.call()
		check(absf(hips - 0.52) < 0.03, "%s: lifted %.2f m, the hips rest on the seat (%.2f m, want 0.52)" % [clip, rig.position.y, hips])

	check(absf(rig.position.y) < 0.15, "the chair clip needs little lift (%.2f m): the body sits on the chair by itself" % rig.position.y)
	node.queue_free()


func _init() -> void:
	var view: Node3D = NpcViewScript.new()
	get_root().add_child(view)
	var text: String = FileAccess.get_file_as_string("res://data/npcs/npcs.json")
	var data: Variant = JSON.parse_string(text)
	var list: Array = data["npcs"] if data is Dictionary and data.has("npcs") else (data if data is Array else [])
	check(list.size() >= 2, "data/npcs/npcs.json lists at least two NPCs (%d)" % list.size())
	var roster: Array = []
	var rows: Array = []
	var spawn: Vector3 = Vector3(53301.0, 29.9, 68427.0)
	var n: int = 0

	for entry in list:
		roster.append([str(entry.get("id", "npc%d" % n)), str(entry.get("name", "?")), str(entry.get("role", "")), str(entry.get("outfit", ""))])
		rows.append([str(entry.get("id", "npc%d" % n)), spawn + Vector3(3.0 * float(n), 0.0, 4.0), 0.0, n % 4])
		n += 1

	view.on_roster(roster)
	view.on_rows(rows)
	check(view.roster.size() == roster.size(), "roster kept (%d of %d)" % [view.roster.size(), roster.size()])
	check(view.drawn_count() == mini(rows.size(), view.MAX_DRAWN), "every listed NPC drawn: %d of %d" % [view.drawn_count(), rows.size()])
	_check_bodies(view)
	var near: Dictionary = view.nearest(spawn, 20.0)
	check(not near.is_empty(), "an NPC is within 20 m of spawn")

	# Rows with no roster entry yet (the packet order is not guaranteed) must still draw, and a resend must not duplicate.
	view.on_rows(rows)
	check(view.drawn_count() == mini(rows.size(), view.MAX_DRAWN), "a resend keeps the same bodies: %d" % view.drawn_count())

	for state in range(4):
		var again: Array = []

		for row in rows:
			again.append([row[0], row[1], row[2], state])

		view.on_rows(again)

		for i in range(5):
			await process_frame

		check(view.drawn_count() > 0, "drawn after frames in state %d" % state)

	var fresh: Node3D = NpcViewScript.new()
	get_root().add_child(fresh)
	fresh.on_rows(rows)
	check(fresh.drawn_count() == mini(rows.size(), fresh.MAX_DRAWN), "rows before the roster still draw: %d" % fresh.drawn_count())

	await _check_chair_sit()
	print("test_npc_view: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
