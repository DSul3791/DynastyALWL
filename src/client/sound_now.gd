extends RefCounted

# What is sounding right now (Dave 2 Nov 2026: a deep wobbling "metal sheet" sound plays all day and never shows as the last sound).
# The HUD's "last sound" only lists one-shots from the sources that report a `last` text; loops and beds (wind, trees in the wind,
# water, weather, ambience beds, insects, wind in gaps, emitters) play for minutes and never report. This walks every player under
# the sound stage and lists the loudest ones playing now, whatever started them: file, the module that owns it and a rough level
# at the listener (the player's volume, its bus and, for a positional one, distance). Cheap: a few dozen nodes, twice a second.

const QUIET_DB := -60.0                 # quieter than this at the listener is left out


# The `count` loudest sounding players under `root`, loudest first: [[label, dB], ...]. `at` is the listener (the camera).
static func loudest(root: Node, at: Vector3, count: int) -> Array:
	var found: Array = []
	_collect(root, at, found)
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	return found.slice(0, count)


# One HUD line from loudest(): "treewind_bare_1 (tree_wind) -18 dB, ...", or "none".
static func line(list: Array) -> String:
	var parts: PackedStringArray = []

	for entry in list:
		parts.append("%s %.0f dB" % [entry[0], float(entry[1])])

	return ", ".join(parts) if not parts.is_empty() else "none"


# A rough level at the listener: the player's own volume, its bus, and for a positional player the inverse distance falloff
# (Godot's ATTENUATION_INVERSE_DISTANCE: unit_size / distance), silent beyond max_distance.
static func level_db(volume_db: float, bus_db: float, positional: bool, unit_size: float, max_distance: float, distance: float) -> float:
	var level: float = volume_db + bus_db

	if positional:
		if max_distance > 0.0 and distance > max_distance:
			return -INF

		level += linear_to_db(clampf(unit_size / maxf(distance, 0.01), 0.0, 1.0))

	return level


# "file (module)": the stream's file name, else the player's node name; the module is the script file of the nearest owner with one.
static func label(player: Node, stream: AudioStream) -> String:
	var sound_name: String = stream.resource_path.get_file().get_basename() if stream != null and stream.resource_path != "" else str(player.name)
	var owner_node: Node = player.get_parent()

	while owner_node != null and owner_node.get_script() == null:
		owner_node = owner_node.get_parent()

	var module: String = (owner_node.get_script() as Script).resource_path.get_file().get_basename() if owner_node != null else "?"
	return "%s (%s)" % [sound_name, module]


static func _collect(node: Node, at: Vector3, found: Array) -> void:
	for child in node.get_children():
		_collect(child, at, found)

	var level: float = -INF

	if node is AudioStreamPlayer3D:
		var p3: AudioStreamPlayer3D = node
		if not p3.playing or p3.stream_paused:
			return
		level = level_db(p3.volume_db, _bus_db(p3.bus), true, p3.unit_size, p3.max_distance, p3.global_position.distance_to(at) if p3.is_inside_tree() else 0.0)
		found_add(found, label(p3, p3.stream), level)
	elif node is AudioStreamPlayer:
		var p2: AudioStreamPlayer = node
		if not p2.playing or p2.stream_paused:
			return
		level = level_db(p2.volume_db, _bus_db(p2.bus), false, 1.0, 0.0, 0.0)
		found_add(found, label(p2, p2.stream), level)


static func found_add(found: Array, text: String, level: float) -> void:
	if level >= QUIET_DB:
		found.append([text, level])


static func _bus_db(bus_name: String) -> float:
	var index: int = AudioServer.get_bus_index(bus_name)
	return AudioServer.get_bus_volume_db(index) if index >= 0 else 0.0
