extends Node3D

# Animal models from src/client/animal_view.gd for tools/shot_node.gd (Kathleen): one or several species in a row, four views, offline with the real meshes (no game light).
# Used for the iterative critique rounds of the fauna looks (art/CRITIQUES/<species>_<date>/roundN.png).
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/animal_sheet.gd --animal=rabbit,fox,deer --out=C:/temp/animals.png --height=2.2 --pitch=-15
# Species: rabbit, wolf, fox, deer, moose, horse, duck (a flock of one), boar, songbird, frog, trout, bear.
# --models: draw a species from its data/animals/models.json scene when one is there (the game's own path, _make_model), else
# its code-built body; the godot.log line "animal model <kind>: ..." says which (MikeW, PR 495).

const AnimalView := preload("res://src/client/animal_view.gd")


func _init() -> void:
	var names: PackedStringArray = PackedStringArray()

	var flying: bool = false
	var models: bool = false

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--animal="):
			names = a.trim_prefix("--animal=").split(",", false)
		elif a == "--fly":
			flying = true      # gulls (seabird flock): open wings, mid-beat, lifted (state 15)
		elif a == "--models":
			models = true

	var view: Node3D = AnimalView.new()
	var spacing: float = 2.2

	for n in names.size():
		var model: Node3D = null

		if models:
			model = view._make_model(AnimalView.KIND_OF_SPECIES.find_key(names[n]) if AnimalView.KIND_OF_SPECIES.values().has(names[n]) else -1)

		match names[n] if model == null else "":
			"rabbit": model = view._make_rabbit()
			"wolf": model = view._make_wolf()
			"fox": model = view._make_fox()
			"deer": model = view._make_deer(0)
			"moose": model = view._make_moose(0)
			"horse": model = view._make_horse(0)
			"duck": model = view._make_flock(0)
			"boar": model = view._make_boar()
			"songbird": model = view._make_songbird()
			"frog": model = view._make_frog()
			"trout": model = view._make_fish()
			"grouse": model = view._make_grouse()
			"seal": model = view._make_seal()
			"gull": model = view._make_seabird()
			"gull_flock": model = view._make_gull_flock(7)
			"bear": model = view._make_bear()

		if model == null:
			push_warning("animal_sheet: unknown species " + names[n])
			continue

		model.position = Vector3((float(n) - float(names.size() - 1) * 0.5) * spacing, 0.0, 0.0)
		add_child(model)

		if flying and names[n] == "gull_flock":
			view._t = 0.3      # a wing beat part way up
			for step in 120:   # let each gull reach its flying height
				view._animate_gulls(model.get_node("Rig"), true)
