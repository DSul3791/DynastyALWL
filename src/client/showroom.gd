extends RefCounted
# The admin showroom (Dave 2026-10-23): rows of things laid out on the ground east and south of the spawn point so he can look at
# them, with the grass cleared under them. It lives only on the admin's own screen while Admin mode is on (items.admin_craft):
# nothing is sent to the server, nothing is saved, nothing can be picked up and no item limit applies. The rows come from
# data/items/showroom.json (see its note), so a thread adds a row without code.

const PATH := "res://data/items/showroom.json"
const SHOW_WITHIN_M := 90.0       # rows are only built while the player is this near the spawn
const RETRY_MSEC := 1000          # a spot whose ground is not loaded yet is tried again after this
const CLEAR_EVERY_M := 4.0        # one grass-clearing spot per this much of a row

var rows: Array = []              # the parsed rows
var origin: Vector3 = Vector3.ZERO
var skipped: int = 0              # entries with an unknown id (logged once each)

var _view                         # the inventory view (item meshes and the ground height)
var _root: Node3D
var _spots: Array = []            # [Vector3 position, int item number, int seed, Node3D or null]
var _next_try_msec: int = 0
var _active: bool = false
var _plants_said: bool = false


func setup(view, spawn: Vector3) -> void:
	_view = view
	origin = spawn
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	rows = parsed["rows"] if parsed is Dictionary and parsed.get("rows") is Array else []


# Called a few times a second with the switch and the player's position.
func update(on: bool, player: Vector3) -> void:
	var near: bool = on and Vector2(player.x - origin.x, player.z - origin.z).length() <= SHOW_WITHIN_M

	if not near:
		if _active:
			_clear()

		return

	if not _active:
		_active = true
		_lay_out()

	var now: int = Time.get_ticks_msec()

	if now < _next_try_msec:
		return

	_next_try_msec = now + RETRY_MSEC

	for spot in _spots:
		if spot[3] == null:
			var ground: float = float(_view._ground_below.call(Vector3(spot[0].x, origin.y + 60.0, spot[0].z)))

			if is_nan(ground):
				continue

			spot[3] = _view.make_display_item(int(spot[1]), int(spot[2]))
			spot[3].position += Vector3(spot[0].x, ground, spot[0].z)
			_root.add_child(spot[3])


# Grass-clearing spots (one every CLEAR_EVERY_M along each row) while the showroom is showing.
func clear_spots() -> Array:
	var out: Array = []

	if not _active:
		return out

	for row in rows:
		var start: Array = row.get("start", [0, 0])
		var step: Array = row.get("step", [0, 1.5])
		var length: float = Vector2(float(step[0]), float(step[1])).length() * maxf(float(row.get("items", []).size()), 1.0)
		var stops: int = maxi(int(ceil(length / CLEAR_EVERY_M)), 1)

		for n in range(stops + 1):
			var along: float = minf(float(n) * CLEAR_EVERY_M / maxf(length, 0.01), 1.0)
			out.append(Vector3(snappedf(origin.x + float(start[0]) + float(step[0]) * float(row.get("items", []).size()) * along, 0.01), origin.y, snappedf(origin.z + float(start[1]) + float(step[1]) * float(row.get("items", []).size()) * along, 0.01)))

	return out


func _lay_out() -> void:
	_root = Node3D.new()
	_root.name = "Showroom"
	_view._root.add_child(_root)
	_spots.clear()
	var seed_n: int = 1

	for row in rows:
		var start: Array = row.get("start", [0, 0])
		var step: Array = row.get("step", [0, 1.5])
		var at: Vector3 = origin + Vector3(float(start[0]), 0.0, float(start[1]))

		if row.has("plants") and not _plants_said:
			_plants_said = true
			print("Showroom: plants rows are read but not drawn yet")

		for entry in row.get("items", []):
			var number: int = _view.table.number_of(str(entry[0]))

			if number <= 0:
				skipped += 1
				print("Showroom: unknown item '%s' in row '%s' skipped" % [str(entry[0]), str(row.get("label", ""))])
			else:
				for k in range(clampi(int(entry[1]) if entry.size() > 1 else 1, 1, 20)):
					seed_n += 1
					_spots.append([at + Vector3(0.06 * float(k % 3), 0.0, 0.06 * floorf(float(k) / 3.0)), number, seed_n, null])

			at += Vector3(float(step[0]), 0.0, float(step[1]))


func _clear() -> void:
	_active = false

	if _root != null:
		_root.queue_free()
		_root = null

	_spots.clear()
