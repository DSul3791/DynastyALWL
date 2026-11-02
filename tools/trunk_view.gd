extends Node3D

# A felled trunk as the client draws it, for tools/shot_node.gd (Kathleen): the trunk model of inventory_view.gd `_make_felled` with a given remaining length, and the logs that lie beside it.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/trunk_view.gd --arg-len=18 --logs=0 --out=C:/temp/trunk.png --height=4 --pitch=-30
#   --arg-len=METRES remaining trunk (18 whole tree)  --logs=N cut logs lying beside it  --orig=METRES whole tree length (default 18)  --species=oak|birch|beech|maple|pine ...

const InventoryView := preload("res://src/client/inventory_view.gd")


func _init() -> void:
	var length: float = 18.0
	var logs: int = 0
	var orig: float = 18.0
	var species: String = "oak"
	var stump: bool = false

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arg-len="):
			length = float(a.trim_prefix("--arg-len="))
		elif a.begins_with("--logs="):
			logs = int(a.trim_prefix("--logs="))
		elif a == "--stump":
			stump = true      # the stump left standing (the model of a felled tree's foot)
		elif a.begins_with("--species="):
			species = a.trim_prefix("--species=")
		elif a.begins_with("--orig="):
			orig = float(a.trim_prefix("--orig="))

	var iv: Node = InventoryView.new()   # not added to the tree: only its model builder is used
	var extra: Dictionary = {"radius": 0.3, "length": length, "yaw": 0.0, "pitch": -0.02, "orig_length": orig, "landed": true, "keywood": true, "species": species}
	var trunk: Node3D = iv._make_felled(not stump, extra)
	add_child(trunk)

	if stump:
		return
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.23, 0.15)
	var cut: StandardMaterial3D = StandardMaterial3D.new()
	cut.albedo_color = Color(0.72, 0.58, 0.38)

	for k in logs:
		var log_node: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.26 + 0.02 * float(k % 3)
		cyl.bottom_radius = 0.3 - 0.01 * float(k % 3)
		cyl.height = 2.44
		cyl.material = wood
		log_node.mesh = cyl
		log_node.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		log_node.position = Vector3(1.0 + 0.7 * float(k % 2), 0.3, orig - 1.5 - 2.7 * float(k)) if orig - 1.5 - 2.7 * float(k) > -1.0 else Vector3(1.0, 0.3, 4.0 + 0.7 * float(k))
		add_child(log_node)

		for end in [-1.0, 1.0]:
			var face: MeshInstance3D = MeshInstance3D.new()
			var disc: CylinderMesh = CylinderMesh.new()
			disc.top_radius = 0.26
			disc.bottom_radius = 0.26
			disc.height = 0.012
			disc.material = cut
			face.mesh = disc
			face.position = Vector3(0.0, end * 1.225, 0.0)
			log_node.add_child(face)
