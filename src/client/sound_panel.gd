extends CanvasLayer

# The sound panel (Dave 2 Nov 2026: "a panel where I can turn on and off all current sound being used for the scene, just a list of sounds with sliding
# toggle switches beside them. Opens when I press like shift f3"). Shift+F3 opens and closes it. It lists every sound playing under the sound stage
# (and the world_sounds group), loudest first, with the module that owns it, its level and its distance, and a switch beside each one: on = heard, off = muted.
# Turn them off one at a time until the bad sound is gone, and the name that went quiet is the culprit.
#
# A muted sound keeps playing but is sent to the muted "SoundPanelOff" bus; the player's own bus is put back when it is switched on again. A sound is
# identified by its label (file name and owning module, SoundNow.label), so every player of that file goes together, including ones that start later
# (checked every ENFORCE_SEC). Mutes stay after the panel closes, so the game can be heard without the list; the panel's "Unmute all" button clears them.
# Debug only, nothing is saved.

const SoundNow := preload("res://src/client/sound_now.gd")
const MUTE_BUS := "SoundPanelOff"
const REFRESH_SEC := 0.5
const ENFORCE_SEC := 0.25
const MAX_ROWS := 40
const QUIET_DB := -70.0
const META_BUS := "sound_panel_bus"      # a muted player's own bus, kept to put back

static var assume_playing: bool = false   # tests: a headless run has no audio driver, so players never report playing

var open: bool = false
var muted: Dictionary = {}               # label -> true
var rows_shown: int = 0

var _stage: Node
var _listener: Callable                   # () -> Vector3, where the ear is
var _panel: PanelContainer
var _list: VBoxContainer
var _title: Label
var _switches: Dictionary = {}            # label -> CheckButton
var _refresh_left: float = 0.0
var _enforce_left: float = 0.0
var _last_set: Array = []                 # the labels shown, sorted
var _mouse_before: int = Input.MOUSE_MODE_CAPTURED


func setup(parent: Node, stage: Node, listener: Callable) -> void:
	_stage = stage
	_listener = listener
	layer = 120
	visible = false
	parent.add_child(self)
	_build()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 0.0
	_panel.position = Vector2(24.0, 24.0)
	_panel.custom_minimum_size = Vector2(400.0, 0.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.94)
	style.set_content_margin_all(10.0)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)
	_title = Label.new()
	column.add_child(_title)
	var bar: HBoxContainer = HBoxContainer.new()
	column.add_child(bar)
	var all_off: Button = Button.new()
	all_off.text = "Unmute all"
	all_off.pressed.connect(unmute_all)
	bar.add_child(all_off)
	var hint: Label = Label.new()
	hint.text = "  Shift+F3 closes. Switch off = muted."
	bar.add_child(hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380.0, 320.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func toggle() -> void:
	open = not open
	visible = open

	if open:
		_mouse_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_left = 0.0
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = _mouse_before as Input.MouseMode


func _process(delta: float) -> void:
	if _stage == null:
		return

	if open:
		_refresh_left -= delta

		if _refresh_left <= 0.0:
			_refresh_left = REFRESH_SEC
			_refresh()
			return

	if not muted.is_empty():
		_enforce_left -= delta

		if _enforce_left <= 0.0:
			_enforce_left = ENFORCE_SEC
			_enforce(_players())


func unmute_all() -> void:
	muted.clear()
	_enforce(_players())
	_refresh_left = 0.0


# Every AudioStreamPlayer and AudioStreamPlayer3D under the stage, plus the world_sounds group, once each.
func _players() -> Array:
	var found: Array = []
	var seen: Dictionary = {}
	_walk(_stage, found, seen)

	if _stage.is_inside_tree():
		for node in _stage.get_tree().get_nodes_in_group("world_sounds"):
			if (node is AudioStreamPlayer or node is AudioStreamPlayer3D) and not seen.has(node.get_instance_id()):
				seen[node.get_instance_id()] = true
				found.append(node)

	return found


func _walk(node: Node, found: Array, seen: Dictionary) -> void:
	for child in node.get_children():
		if child == self:
			continue

		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			if not seen.has(child.get_instance_id()):
				seen[child.get_instance_id()] = true
				found.append(child)

		_walk(child, found, seen)


static func mute_bus_index() -> int:
	var index: int = AudioServer.get_bus_index(MUTE_BUS)

	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, MUTE_BUS)
		AudioServer.set_bus_send(index, "Master")
		AudioServer.set_bus_mute(index, true)

	return index


# Puts the players of muted labels on the muted bus and everyone else back on the bus they came from.
func _enforce(players: Array) -> void:
	mute_bus_index()

	for player in players:
		if not is_instance_valid(player) or player.stream == null:
			continue

		var is_muted: bool = muted.has(SoundNow.label(player, player.stream))

		if is_muted and str(player.bus) != MUTE_BUS:
			player.set_meta(META_BUS, str(player.bus))
			player.bus = MUTE_BUS
		elif not is_muted and str(player.bus) == MUTE_BUS and player.has_meta(META_BUS):
			player.bus = str(player.get_meta(META_BUS))
			player.remove_meta(META_BUS)


func _refresh() -> void:
	var players: Array = _players()
	_enforce(players)
	var ear_at: Vector3 = _listener.call() if _listener.is_valid() else Vector3.ZERO
	var best: Dictionary = {}                # label -> [level dB, distance m (-1 flat), bus, count]

	for player in players:
		if not is_instance_valid(player) or not (player.playing or assume_playing) or player.stream == null or player.stream_paused:
			continue

		var label: String = SoundNow.label(player, player.stream)
		var bus_name: String = str(player.get_meta(META_BUS)) if player.has_meta(META_BUS) else str(player.bus)
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		var bus_db: float = AudioServer.get_bus_volume_db(bus_index) if bus_index >= 0 else 0.0
		var level: float
		var distance: float = -1.0

		if player is AudioStreamPlayer3D:
			distance = player.global_position.distance_to(ear_at)
			level = SoundNow.level_db(player.volume_db, bus_db, true, player.unit_size, player.max_distance, distance)
		else:
			level = SoundNow.level_db(player.volume_db, bus_db, false, 1.0, 0.0, 0.0)

		if level < QUIET_DB and not muted.has(label):
			continue

		var entry: Array = best.get(label, [-INF, distance, bus_name, 0])
		entry[0] = maxf(float(entry[0]), level)
		entry[3] = int(entry[3]) + 1
		best[label] = entry

	for label in muted:
		if not best.has(label):
			best[label] = [-INF, -1.0, "", 0]       # a muted sound that is not playing right now stays on the list so it can be switched back on

	var labels: Array = best.keys()
	labels.sort_custom(func(a, b): return float(best[a][0]) > float(best[b][0]))
	labels = labels.slice(0, MAX_ROWS)
	rows_shown = labels.size()
	_title.text = "Sounds in this scene: %d playing, %d muted" % [best.size(), muted.size()]

	# The rows are rebuilt only when the set of sounds changes (not when their order does), so a switch is never replaced under the mouse.
	var sorted_now: Array = labels.duplicate()
	sorted_now.sort()

	if sorted_now != _last_set:
		_rebuild(labels)
		_last_set = sorted_now

	for label in labels:
		_update_row(label, best[label])


func _rebuild(labels: Array) -> void:
	for child in _list.get_children():
		child.queue_free()

	_switches.clear()

	for label in labels:
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "row_%d" % _switches.size()
		var text: Label = Label.new()
		text.name = "text"
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.clip_text = true
		row.add_child(text)
		var check: CheckButton = CheckButton.new()
		check.button_pressed = not muted.has(label)
		check.toggled.connect(_on_switch.bind(label))
		row.add_child(check)
		_list.add_child(row)
		_switches[label] = check
		row.set_meta("label", label)


func _update_row(label: String, entry: Array) -> void:
	var check: CheckButton = _switches.get(label)

	if check == null:
		return

	var text: Label = check.get_parent().get_node("text")
	var level: String = "not playing" if is_inf(float(entry[0])) else "%.0f dB" % float(entry[0])
	var where: String = "" if float(entry[1]) < 0.0 else ", %.0f m" % float(entry[1])
	text.text = "%s  %s%s%s" % [label, level, where, "  x%d" % int(entry[3]) if int(entry[3]) > 1 else ""]
	text.modulate = Color(1, 1, 1, 0.45) if muted.has(label) else Color(1, 1, 1, 1)


func _on_switch(on: bool, label: String) -> void:
	if on:
		muted.erase(label)
	else:
		muted[label] = true

	_enforce(_players())
