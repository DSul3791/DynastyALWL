extends SceneTree

# No worker thread makes a rendering resource or a node (14 Nov 2026: the client broke the headless renderer's stores at the join: "Attempting to initialize
# the wrong RID", "m" is null, signal 11 on David4). The headless (dummy) renderer's mesh, material, shader and texture stores are not thread safe in Godot
# 4.7.2 (servers/rendering/dummy/storage/*_storage.h: RID_Owner without THREAD_SAFE), so a mesh, material or texture made off the main thread there can corrupt
# the ones the main thread makes at the same time.
#   godot --headless --path . --script res://src/worldgen/tools/test_worker_resources.gd
# 1. Every function or lambda given to WorkerThreadPool.add_task / add_group_task or to a Thread's start, in src/ and scenes/ (tests and tools left out),
#    and every function those call (followed into other scripts through preload constants and class_name), makes no mesh, material, texture or node,
#    loads no resource and touches no scene tree or RenderingServer.
# 2. Every ResourceLoader.load_threaded_request of anything but an AudioStream sits in a function that checks for headless (DynastyBody.warm, the arms'
#    skin texture): loader threads make meshes, materials and textures too.

const FloraView := preload("res://src/flora/flora_view.gd")
const ROOTS := ["res://src", "res://scenes"]
# A mesh, material, texture or node made, a resource loaded, the scene tree or the RenderingServer used.
const FORBIDDEN := "\\b(ArrayMesh|ImmediateMesh|MeshInstance3D|MultiMesh|MultiMeshInstance3D|BoxMesh|SphereMesh|CylinderMesh|CapsuleMesh|QuadMesh|PlaneMesh|PrismMesh|TorusMesh" \
	+ "|StandardMaterial3D|ORMMaterial3D|ShaderMaterial|CanvasItemMaterial|Shader|ImageTexture|ImageTexture3D|Texture2DArray|NoiseTexture2D|GradientTexture1D|GradientTexture2D" \
	+ "|SubViewport|RenderingServer|GLTFDocument|Node|Node2D|Node3D|Control|Skeleton3D)\\b\\.|\\b(add_surface_from_arrays|surface_set_material|surface_get_arrays|create_from_image" \
	+ "|add_child|instantiate|get_tree|get_node|queue_free|generate_scene|load|preload|load_threaded_get|call_group|propagate_notification)\\(|\\.commit\\(\\)"
# Mesh builders a worker reaches only behind a constant that keeps them off: terrain_client._decode_in builds the old water and fall meshes only when
# flora_view.LIQUID_CHUNKS is false or DRAW_FALL_RIBBONS true (checked below: flip either and move that build to the main thread).
const OFF_BY_CONSTANT := ["res://src/worldgen/runtime/water_grid.gd:build_mesh", "res://src/worldgen/runtime/water_falls.gd:build_mesh"]

var _failures: int = 0
var _sources: Dictionary = {}      # path -> source text, comments cut
var _bodies: Dictionary = {}       # path -> {function name -> body text}
var _classes: Dictionary = {}      # class_name -> path


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	_failures += 0 if ok else 1


func _scripts(dir: String, out: Array) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if sub != "tools" and not sub.begins_with("."):
			_scripts(dir.path_join(sub), out)

	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd") and not file.begins_with("test_"):
			out.append(dir.path_join(file))


# A line without its comment (a # inside a string is rare in these scripts; it only hides the rest of that line).
func _code(line: String) -> String:
	return "" if line.strip_edges().begins_with("#") else line.split("#")[0]


func _read(path: String) -> void:
	var text: String = ""
	var bodies: Dictionary = {}
	var current: String = ""
	var head: RegEx = RegEx.create_from_string("^\\t?(static\\s+)?func\\s+(\\w+)")

	for line in FileAccess.get_file_as_string(path).split("\n"):
		var code: String = _code(line)
		text += code + "\n"
		var found: RegExMatch = head.search(code)

		if found != null:
			current = found.get_string(2)
			bodies[current] = ""
		elif not code.strip_edges().is_empty() and not code.begins_with("\t") and not code.begins_with(" "):
			current = ""

		if current != "":
			bodies[current] += code + "\n"

	_sources[path] = text
	_bodies[path] = bodies
	var named: RegExMatch = RegEx.create_from_string("(?m)^class_name\\s+(\\w+)").search(text)

	if named != null:
		_classes[named.get_string(1)] = path


# const Name := preload("res://...") in a script: Name -> path.
func _preloads(path: String) -> Dictionary:
	var out: Dictionary = {}

	for found in RegEx.create_from_string("const\\s+(\\w+)\\s*:?=\\s*preload\\(\"(res://[^\"]+\\.gd)\"\\)").search_all(str(_sources[path])):
		out[found.get_string(1)] = found.get_string(2)

	return out


# The text of a call's arguments, from just after its "(" to the matching ")".
func _arguments(text: String, from: int) -> String:
	var depth: int = 1
	var at: int = from

	while at < text.length() and depth > 0:
		depth += 1 if text[at] == "(" else (-1 if text[at] == ")" else 0)
		at += 1

	return text.substr(from, at - from - 1)


# Adds [path, function] for each call in `text` that names a function of this script, or of a script it preloads or a class_name.
func _calls(path: String, text: String, into: Array) -> void:
	var known: Dictionary = _preloads(path)

	for found in RegEx.create_from_string("(?:\\b(\\w+)\\.)?\\b(\\w+)\\(").search_all(text):
		var owner_name: String = found.get_string(1)
		var target: String = path if owner_name.is_empty() else str(known.get(owner_name, _classes.get(owner_name, "")))

		if _bodies.has(target):
			into.append([target, found.get_string(2)])


func _init() -> void:
	var paths: Array = []

	for root in ROOTS:
		_scripts(root, paths)

	for path in paths:
		_read(path)

	_check(paths.size() > 100, "%d game scripts read" % paths.size())
	var forbidden: RegEx = RegEx.create_from_string(FORBIDDEN)
	var workers: int = 0
	var reached_total: int = 0

	for path in paths:
		var text: String = _sources[path]
		var starts: String = "WorkerThreadPool\\.add_(?:group_)?task\\("

		for thread in RegEx.create_from_string("(\\w+)\\s*=\\s*Thread\\.new\\(\\)").search_all(text):
			starts += "|\\b%s\\.start\\(" % thread.get_string(1)

		for start in RegEx.create_from_string(starts).search_all(text):
			var given: String = _arguments(text, start.get_end())
			var line: int = text.substr(0, start.get_start()).count("\n") + 1
			var queue: Array = []
			var texts: Array = []     # [label, text]
			workers += 1

			if given.strip_edges().begins_with("func"):
				texts.append(["the lambda", given])
				_calls(path, given, queue)
			else:
				# A function (name, name.bind(...), Script.name), or a Callable held in a local: then the function that makes it is read whole.
				var parts: PackedStringArray = given.split("(")[0].split(",")[0].strip_edges().split(".")

				if parts.size() > 1 and parts[parts.size() - 1] == "bind":
					parts.remove_at(parts.size() - 1)

				_calls(path, ".".join(parts) + "(", queue)

				if parts.size() == 1 and not (_bodies[path] as Dictionary).has(parts[0]):
					for function in _bodies[path]:
						if RegEx.create_from_string("var\\s+%s\\b[^\\n]*=\\s*func" % parts[0]).search(str(_bodies[path][function])) != null:
							texts.append(["%s (the Callable %s)" % [function, parts[0]], _bodies[path][function]])
							_calls(path, _bodies[path][function], queue)

			var seen: Dictionary = {}

			while not queue.is_empty():
				var step: Array = queue.pop_back()
				var key: String = "%s:%s" % [step[0], step[1]]

				if seen.has(key) or not (_bodies[step[0]] as Dictionary).has(step[1]):
					continue

				seen[key] = true

				if key in OFF_BY_CONSTANT:
					continue

				var body: String = _bodies[step[0]][step[1]]
				texts.append([key, body])
				_calls(step[0], body, queue)

			reached_total += seen.size()

			for pair in texts:
				var bad: Array = forbidden.search_all(str(pair[1])).map(func(found: RegExMatch) -> String: return found.get_string(0))
				_check(bad.is_empty(), "%s:%d worker, %s: makes no mesh, material, texture or node %s" % [path.get_file(), line, pair[0], str(bad)])

	_check(workers >= 15, "%d worker starts found" % workers)
	_check(reached_total >= 30, "%d functions reached from them" % reached_total)
	_check(FloraView.LIQUID_CHUNKS and not FloraView.DRAW_FALL_RIBBONS, "the water and fall mesh builders stay off on the chunk worker (LIQUID_CHUNKS, no DRAW_FALL_RIBBONS)")

	# 2. Threaded loads of anything but sound are guarded for headless.
	var threaded: int = 0

	for path in paths:
		for function in _bodies[path]:
			var body: String = _bodies[path][function]

			for line in body.split("\n"):
				if line.contains("load_threaded_request("):
					threaded += 1
					_check(line.contains("\"AudioStream\"") or body.contains("headless"), "%s %s: a threaded load of %s is guarded for headless" % [path.get_file(), function, line.strip_edges()])

	_check(threaded >= 3, "%d threaded loads found" % threaded)
	print("test_worker_resources: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)
