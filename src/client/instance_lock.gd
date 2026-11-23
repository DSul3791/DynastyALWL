extends RefCounted

# A second copy of the game on the same computer (coordinator, 23 Nov 2026: "a second copy of the game already running"). Both would share the
# user folder (settings, keys, ground cache, character keys) and the same character: the server lets the newer one in and closes the older
# with "joined from elsewhere". So the launcher asks first: the open copy rewrites the note user://game_open.json every few seconds (its process
# id and the time; the engine can only ask about processes it started itself, so a fresh note is the sign of life). A note younger than
# FRESH_S from another process: the player sees "Dynasty is already open" with Quit and Open anyway. A crash leaves a stale note, never asked about.
# Not asked: a restart of the game itself (--to-servers, set_restart_on_exit: the old process may still be closing), tests (--test), headless runs.

const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")   # its printer (no bare print in client code)
const PATH := "user://game_open.json"
const EVERY_S := 5.0
const FRESH_S := 60.0   # longer than the longest first-start freeze (about 25 s), when a tester is most likely to start the game again


# The process id of another copy of the game whose note is fresh, or 0.
static func other_copy(path: String = PATH, own_pid: int = OS.get_process_id(), now: float = Time.get_unix_time_from_system()) -> int:
	if not FileAccess.file_exists(path):
		return 0

	var note: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if not (note is Dictionary) or typeof(note.get("pid")) not in [TYPE_INT, TYPE_FLOAT] or typeof(note.get("t")) not in [TYPE_INT, TYPE_FLOAT]:
		return 0   # a damaged note: as if none

	var pid: int = int(note["pid"])
	var age: float = now - float(note["t"])

	if pid <= 0 or pid == own_pid or age > FRESH_S or age < -FRESH_S:
		return 0

	return pid


static func claim(path: String = PATH, own_pid: int = OS.get_process_id(), now: float = Time.get_unix_time_from_system()) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify({"pid": own_pid, "t": now}))


# Takes the note away on a clean exit, only when it is still this copy's (a quick restart after closing is then never asked about).
static func release(path: String = PATH, own_pid: int = OS.get_process_id()) -> void:
	if not FileAccess.file_exists(path):
		return

	var note: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if note is Dictionary and typeof(note.get("pid")) in [TYPE_INT, TYPE_FLOAT] and int(note["pid"]) == own_pid:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# Rewrites the note every EVERY_S for as long as this copy runs (a tree timer: it outlives every page and runs while the game is paused).
# The first call also leaves a node under the root whose leaving (the game closing) releases the note.
static func keep_fresh(tree: SceneTree) -> void:
	claim()

	if not tree.root.has_node("InstanceLockNote"):
		var watcher: Node = Node.new()
		watcher.name = "InstanceLockNote"
		watcher.tree_exiting.connect(func() -> void: release())
		tree.root.add_child.call_deferred(watcher)

	tree.create_timer(EVERY_S, true).timeout.connect(keep_fresh.bind(tree))


# Whether the launcher keeps the note at all for these command-line flags and display (a restart, --to-servers, keeps it but does not ask).
static func should_ask(user_args: PackedStringArray, display_name: String) -> bool:
	return display_name != "headless" and not user_args.has("--test")


# The question, on its own layer over a blank screen. `go_on` runs after Open anyway; Quit closes this copy.
static func ask(parent: Node, go_on: Callable) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	var back: ColorRect = ColorRect.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0.06, 0.07, 0.09, 1.0)
	layer.add_child(back)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(centre)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(680.0, 0.0)
	box.add_theme_constant_override("separation", 14)
	centre.add_child(box)
	var title: Label = Label.new()
	title.text = "Dynasty is already open"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	var body: Label = Label.new()
	body.text = "Another copy of the game is running on this computer (it may be behind this window or on the taskbar). Two copies share your settings and your character, and the second one to join closes the first.\n\nQuit and switch to the open copy, or open this one anyway."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 20)
	box.add_child(body)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	for spec in [["Quit", func() -> void: parent.get_tree().quit()], ["Open anyway", func() -> void:
		layer.queue_free()
		go_on.call()]]:
		var button: Button = Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(220.0, 48.0)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(spec[1])
		row.add_child(button)

	parent.add_child(layer)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	FreezeWatchScript.printer.line("Launcher: another copy of the game is open; asked Quit or Open anyway")   # tools/way_in_eyes.sh reads it
