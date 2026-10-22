extends RefCounted

# Picking plants by hand on the client (Dave 2026-10-20): the "Press E to harvest" prompt, tapping E
# to pick the nearest plant, and holding E to sweep every pickable plant within 2 m. The server
# decides what a pick gives (data/items/drops.json); GatherRules says the same thing here so the
# prompt only offers what will work. Plants the server has picked bare are remembered locally for
# the same game time (REGROW_GAME_S).

const GatherRules := preload("res://src/shared/gather_rules.gd")

const Net := preload("res://src/stream/terrain_net.gd")
const Interact := preload("res://src/shared/interact_rules.gd")
const SWEEP_RADIUS_M := 2.0
const SWEEP_AFTER_S := 0.35         # E held this long starts the sweep
const SWEEP_EVERY_S := 0.2          # then one pick per step (5 a second)
const REGROW_GAME_S := 3.0 * 86400.0
const RETRY_GAME_S := 72.0              # about 3 real seconds: a pick the server refused can be tried again
const CHUNK_M := 256.0

var _client
var _items
var _net
var _flora_by_id: Dictionary = {}
var _drops: Dictionary = {}
var _picked_until: Dictionary = {}   # "x,z,id" -> game seconds it is ready again
var _held_s: float = 0.0
var _sweep_left: float = 0.0
var _hint_left: float = 0.0


func setup(client, items, net) -> void:
	_client = client
	_items = items
	_net = net
	var flora_table: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))

	if typeof(flora_table) == TYPE_DICTIONARY:
		for entry in flora_table["entries"]:
			_flora_by_id[int(entry["id"])] = entry

	var drops: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
	_drops = drops if typeof(drops) == TYPE_DICTIONARY else {}


# Called every frame. `e_down` is whether E is held now.
func update(delta: float, e_down: bool) -> void:
	if _items == null or _client.body == null:
		return

	_hint_left -= delta

	if _hint_left <= 0.0:
		_hint_left = 0.2
		_items.plant_hint = _hint()

	if not e_down:
		_held_s = 0.0
		_sweep_left = 0.0
		_items.sweep_reset()
		return

	_held_s += delta

	if _held_s < SWEEP_AFTER_S:
		return

	_sweep_left -= delta

	if _sweep_left <= 0.0:
		_sweep_left = SWEEP_EVERY_S

		if _items.hold_use():
			return

		# One thing a step, the nearest of a loose item and a plant within 2 m, wherever you are looking.
		var found: Array = _candidates(SWEEP_RADIUS_M, false)
		var plant: Dictionary = {}

		for c in found:
			if c["ok"]:
				plant = c
				break

		var loose: Array = _items.sweep_target(SWEEP_RADIUS_M)

		if int(loose[0]) != 0 and (plant.is_empty() or float(loose[1]) <= float(plant["d"])):
			_items.sweep_pick(int(loose[0]))
		elif not plant.is_empty():
			_pick(plant)
		elif int(loose[0]) == 0:
			var branch: Dictionary = _branch(SWEEP_RADIUS_M, false)

			if not branch.is_empty():
				_pick_branch(branch)


# The nearest dead branch lying on the forest floor in reach (Dave 2026-10-22: loose sticks you can see are pickable); `view_only` keeps to those in view.
func _branch(radius: float, view_only: bool) -> Dictionary:
	if _client.grass == null:
		return {}

	var branch: Dictionary = _client.grass.branch_near(_client.body.global_position, radius)

	if branch.is_empty() or (view_only and not _items.in_view(branch["pos"])):
		return {}

	return branch


func _pick_branch(branch: Dictionary) -> void:
	_net.inventory_action.rpc_id(1, Net.ACT_LITTER, 0, 0, 0, branch["pos"])
	_client.grass.hide_branch(branch["cell"], int(branch["at"]))
	_items.clear_prompt()
	_hint_left = 0.0


# E tapped with nothing on the ground in reach: pick the nearest pickable plant, or say why not.
func tap() -> void:
	var found: Array = _candidates(Interact.reach_m(), true)

	for c in found:
		if c["ok"]:
			_pick(c)
			return

	var branch: Dictionary = _branch(Interact.reach_m(), true)

	if found.is_empty() and not branch.is_empty():
		_pick_branch(branch)
		return

	for c in found:
		if not _is_nothing(c):
			_items.show_notice("%s: %s" % [c["name"], c["reason"]])
			_items.refuse_cue("no_tool")
			return


func _pick(c: Dictionary) -> void:
	_net.cut_flora.rpc_id(1, c["chunk"], c["id"])
	_client.sound.harvestfx.pick(_flora_by_id.get(int(c["id"]) >> 16, {}), c["pos"])
	_picked_until[c["key"]] = _client.game_clock.seconds + RETRY_GAME_S   # until the server's answer removes the plant
	_items.clear_prompt()
	_hint_left = 0.0


# "Nothing to pick" (out of season, no yield) is not worth a prompt: only say why when a tool is missing.
func _is_nothing(c: Dictionary) -> bool:
	return str(c["reason"]).begins_with("nothing to pick")


func _hint() -> String:
	var found: Array = _candidates(Interact.reach_m(), true)

	if found.is_empty():
		var branch: Dictionary = _branch(Interact.reach_m(), true)

		if branch.is_empty():
			return ""

		_items.plant_aimed = _items.aimed_at(branch["pos"] + Vector3(0.0, 0.2, 0.0))
		return "Press E to gather"

	# Dave 2026-10-21: only "Press E to gather", no name and no "hold E". A missing tool is told after the press (message and cue).
	# Dave 2026-10-22: the text shows only while looking straight at it within the prompt reach (plant_aimed); E still works without it.
	for c in found:
		if c["ok"] or not _is_nothing(c):
			_items.plant_aimed = _items.aimed_at(c["pos"] + Vector3(0.0, 0.6, 0.0))
			return "Press E to gather"

	return ""


# Plants and shrubs within `radius` of the player, nearest first, each with what picking it would do.
func _candidates(radius: float, view_only: bool = false) -> Array:
	var here: Vector3 = _client.body.global_position
	var out: Array = []
	var chunks: Dictionary = {}

	for dx in [-radius, 0.0, radius]:
		for dz in [-radius, 0.0, radius]:
			chunks[Vector2i(int(floor((here.x + dx) / CHUNK_M)), int(floor((here.z + dz) / CHUNK_M)))] = true

	var season: String = _client.game_clock.season()
	var now_s: float = _client.game_clock.seconds
	var has_tool: Callable = func(tool_class: String) -> bool: return _items.has_tool_class(tool_class)
	var exists: Callable = func(item_id: String) -> bool: return _items.table.has_id(item_id)

	for chunk in chunks:
		if not _client.flora._chunks.has(chunk):
			continue

		var held: Dictionary = _client.flora._chunks[chunk]["items"]

		for n in range(held["ids"].size()):
			var p: Vector3 = held["positions"][n]
			var d: float = Vector2(p.x - here.x, p.z - here.z).length()

			if d > radius:
				continue

			if view_only and not _items.in_view(p):
				continue

			var id: int = held["ids"][n]
			var species: Dictionary = _client.flora._species.get(id >> 16, {})
			var kind: int = int(species.get("kind", 0))

			if kind == 0:
				continue

			var row: Dictionary = _flora_by_id.get(id >> 16, {})

			if row.is_empty():
				continue

			var key: String = "%d,%d,%d" % [chunk.x, chunk.y, id]
			var verdict: Dictionary
			var name: String = str(row.get("display", row.get("name", "plant")))

			# Picked plants say nothing at all until they bear again.
			if float(_picked_until.get(key, -1.0)) > now_s:
				continue

			verdict = GatherRules.check(row, "shrub" if kind == 1 else "plant", _drops, season, has_tool, exists)

			out.append({"d": d, "pos": p, "chunk": chunk, "id": id, "key": key, "name": name, "ok": verdict["ok"], "reason": verdict["reason"]})

	out.sort_custom(func(a, b): return a["d"] < b["d"])
	return out
