extends SceneTree
func _init():
	for k in ["lynx","elk"]:
		var dir := "res://assets/animals/%s" % k
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".fbx"):
				var n = (load(dir + "/" + f) as PackedScene).instantiate()
				var out := []
				var aabb := AABB()
				for ap in n.find_children("*", "AnimationPlayer", true, false):
					for an in ap.get_animation_list(): out.append(an)
				for mi in n.find_children("*", "MeshInstance3D", true, false):
					aabb = aabb.merge(mi.get_aabb()) if aabb.size != Vector3.ZERO else mi.get_aabb()
				print("== ", k, " aabb ", aabb.size, " n=", out.size())
				var pick := []
				for o in out:
					var b: String = o.get_slice("|", 1)
					if b.begins_with("Idle") or b in ["GrazingOnSpotA_1","WalkMedium_F","RunFast_F","WalkSlow_F","RunSlow_F","Walk_F_IP","Run_F_IP","Roar","Eat","Attack","Alert"] or b.begins_with("Walk") or b.begins_with("Run") or b.begins_with("Gallop") or b.begins_with("Trot") or b.begins_with("Sniff") or b.begins_with("StandStraig") or b.begins_with("Stand"): pick.append(b)
				print(", ".join(out.filter(func(o): var b=o.to_lower(); return "walk_fwd" in b and "to" not in b or "graz" in b or "eat" in b or "walk" == b.get_slice("|",1) or "feed" in b or "head" in b).map(func(o): return o.get_slice("|",1))))
				for mi in n.find_children("*", "MeshInstance3D", true, false):
					var ms := []
					for i in mi.mesh.get_surface_count(): ms.append(mi.mesh.surface_get_material(i).resource_name if mi.mesh.surface_get_material(i) else "-")
					print("  mesh ", mi.name, " ", ms)
	quit()
