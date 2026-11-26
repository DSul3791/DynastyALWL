extends SceneTree

# The crafting window photographed in seconds, with its fit report: the game's own InventoryView, built with a made-up world (no server, no
# terrain), in a 1920x1080 picture, once per text size. Two windows: the Primitive smithy's (its one store grown past 20 slots beside its recipe
# list, Dave 17 Nov 2026) and your own inventory's Craft screen with every category tab. For the layout, not the game's look of the world.
#
#   godot --path . --script res://tools/shot_station.gd -- --out=C:/DynastyLane/logs/<job>/shots
#   options: --scales=0.85,1.0,1.2   text sizes (Esc > Settings, display_settings.gd TEXT_SCALES; 1.2 is the largest)
#            --windows=smithy,craft  which windows
#            --store=27              filled slots in the smithy's store (20 is its start; more makes it grow)
# Needs a window and a GPU like tools/shot_held.gd (a window flashes up for a few seconds); under --headless the fit reports still print but
# nothing is drawn and it exits 4.
# Prints one "shot station: WINDOW scale S: <fit report>" and one "shot station: saved PATH" line per picture, then "shot station: N picture(s)
# in T s, all fit" or "... K over"; exit 0 when every picture saved and fits, 3 when one is over, 4 when a picture was not saved.

const InventoryViewScript := preload("res://src/client/inventory_view.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const RecipeTableScript := preload("res://src/shared/recipe_table.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const VitalsRules := preload("res://src/shared/vitals_rules.gd")

const SIZE := Vector2i(1920, 1080)   # the window's design canvas (ArtKit)
const STATION_ID := 3


func _initialize() -> void:
	var started: int = Time.get_ticks_msec()
	var out: String = "user://shots"
	var scales: PackedStringArray = PackedStringArray(["0.85", "1.0", "1.2"])
	var windows: PackedStringArray = PackedStringArray(["smithy", "craft"])
	var store_slots: int = 27

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--scales="):
			scales = a.trim_prefix("--scales=").split(",", false)
		elif a.begins_with("--windows="):
			windows = a.trim_prefix("--windows=").split(",", false)
		elif a.begins_with("--store=") and a.trim_prefix("--store=").is_valid_int():
			store_slots = clampi(int(a.trim_prefix("--store=")), 0, InventoryScript.MAX_SLOTS)

	DirAccess.make_dir_recursive_absolute(out)
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var back: ColorRect = ColorRect.new()   # the world behind the window: a plain field
	back.color = Color(0.32, 0.42, 0.22)
	back.size = Vector2(SIZE)
	vp.add_child(back)
	var table = ItemTableScript.load_default()
	var recipes = RecipeTableScript.load_default(table)
	var kinds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))["structures"]
	var saved: int = 0
	var wanted: int = 0
	var over: int = 0

	for window in windows:
		if window != "smithy" and window != "craft":
			print("shot station: unknown window %s (smithy or craft)" % window)
			continue

		for scale_text in scales:
			if not scale_text.is_valid_float():
				print("shot station: --scales error: %s is not a number" % scale_text)
				continue

			wanted += 1
			var layer: CanvasLayer = CanvasLayer.new()
			vp.add_child(layer)
			var world_root: Node3D = Node3D.new()
			vp.add_child(world_root)
			await process_frame   # the window's text sizes read the layer's viewport once it is in the tree (as test_inventory_open_cost)
			var view = InventoryViewScript.new()   # not in the tree: its _process wants the whole client; the recipe pass is stepped here
			view.table = table
			view.inventory = InventoryScript.pack(table)
			view.recipes = recipes
			view._layer = layer
			view._root = world_root
			view._player_position = func() -> Vector3: return Vector3.ZERO
			view._ground_below = func(_at: Vector3) -> float: return 0.0
			view._carry_cfg = CarryRules.load_config()
			view._vitals_cfg = VitalsRules.load_config()
			view.text_scale = float(scale_text)
			_stock_pack(view)
			var forge: Dictionary = kinds["stone_forge"]
			view._world = {STATION_ID: {"node": null, "number": table.number_of(str(forge.get("item", "stone_forge"))), "count": 1, "pos": Vector3(1.5, 0.0, 0.0), "state": int(forge["state"]), "light": null}}

			if window == "smithy":
				var store = InventoryScript.new(table, int(forge.get("slots", 20)))
				store.grows = true

				for number in _store_items(view, store_slots):
					store.add(number, 1)

				view._open_asked_msec = Time.get_ticks_msec()   # as the server's answer to an F press
				view._on_chest(STATION_ID, store.to_bytes())
			else:
				view.toggle()   # I: your own inventory, its Craft screen on All

			var steps: int = 0

			while view._recipe_part.running() and steps < 20000:   # the list worked out at once (the game spreads it over frames)
				steps += 1
				view._recipe_part.step()

			if view._recipe_part.running():
				print("shot station: %s scale %s: the recipe list was still being worked out after %d steps (the picture shows it half built)" % [window, scale_text, steps])

			for i in 3:
				await process_frame

			await RenderingServer.frame_post_draw
			var report: String = view._frame.fit_report()
			var need: Vector2 = view._panel.get_combined_minimum_size()
			var fits: bool = view._frame.columns_fit() and need.x <= view._panel.size.x + 1.0 and need.y <= view._panel.size.y + 1.0

			if not fits:
				over += 1

			var extra: String = (", store %d slots" % view.chest_inv.slot_count) if window == "smithy" else ""
			print("shot station: %s scale %s: window %dx%d needs %dx%d%s; %s" % [window, scale_text, view._panel.size.x, view._panel.size.y, need.x, need.y, extra, report])
			var image: Image = vp.get_texture().get_image()
			var path: String = "%s/station_%s_%s.png" % [out, window, scale_text]

			if image != null and not image.is_empty() and image.save_png(path) == OK:
				saved += 1
				print("shot station: saved %s" % path)
			else:
				print("shot station: FAILED to save %s" % path)

			view._recipe_part.stop()
			layer.queue_free()
			world_root.queue_free()
			view.free()   # not in the tree (as test_inventory_open_cost)
			await process_frame

	print("shot station: %d picture(s) in %.1f s, %s" % [saved, float(Time.get_ticks_msec() - started) / 1000.0, "all fit" if over == 0 else "%d over" % over])
	quit(4 if saved < wanted or wanted == 0 else (3 if over > 0 else 0))


# A pack like a working player's: 10 of each of the 40 ingredients the recipes use most, so the lists show what can be made.
func _stock_pack(view) -> void:
	for number in _ranked_needs(view).slice(0, 40):
		view.inventory.add(int(number), 10)


# `count` different items for the smithy's store (materials and things it makes), one slot each.
func _store_items(view, count: int) -> Array:
	var picked: Array = []

	var made: Array = []

	for r in view.recipes.numbers():
		var gives: Array = view.recipes.recipe(r).get("gives", [])

		if not gives.is_empty():
			made.append(int(gives[0]))

	for number in _ranked_needs(view) + made:
		if picked.size() >= count:
			break

		if int(number) > 0 and not picked.has(int(number)):
			picked.append(int(number))

	return picked


func _ranked_needs(view) -> Array:
	var uses: Dictionary = {}

	for number in view.recipes.numbers():
		for need in view.recipes.recipe(number)["needs"]:
			if int(need[0]) > 0:
				uses[int(need[0])] = int(uses.get(int(need[0]), 0)) + 1

	var ranked: Array = uses.keys()
	ranked.sort_custom(func(a, b): return int(uses[a]) > int(uses[b]))
	return ranked
