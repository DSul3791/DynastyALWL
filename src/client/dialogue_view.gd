extends Node

# Talking to an NPC (protocol 45): "Press E to talk to <name>" through the interaction registry, then a panel at the bottom of the
# screen with the NPC's name, their line and the choices (click, or keys 1 to 5). Esc or the last line closes it. The line carries
# a voice_id for text to voice (Mandy hooks that up through voice_line). Fonts are 26 px, readable on a 55 inch 4K at 1080p.

const FONT_PX := 26
const MAX_CHOICES := 5

var net
var items                       # InventoryView (screen state and the registry)
var npc_view
var player_position: Callable
var voice_line: Callable = Callable()   # (voice_id, text) -> void; text to voice listens here

var _panel: PanelContainer = null
var _shop_panel: PanelContainer = null     # the trade window (protocol 62)
var _shop_npc: String = ""
var _shop_title: String = ""
var _shop_ids: PackedStringArray = PackedStringArray()
var _shop_pay: float = 1.3                 # what you pay per unit of value
var _shop_get: float = 0.55                # what the trader pays per unit of value
var _shop_buys: PackedStringArray = PackedStringArray()
var _shop_tired: Dictionary = {}           # item id -> demand multiple (the trader is tired of buying it)
var _shop_buy_box: VBoxContainer
var _shop_sell_box: VBoxContainer
var _shop_purse: Label
var _shop_title_label: Label
var _name: Label = null
var _text: Label = null
var _choices: VBoxContainer = null
var _npc_id: String = ""
var _count: int = 0
var _ends: bool = false


func setup(net_ref, items_ref, npc_view_ref, layer: CanvasLayer, player_pos: Callable) -> void:
	net = net_ref
	items = items_ref
	npc_view = npc_view_ref
	player_position = player_pos
	net.npc_say_received.connect(_on_say)
	net.shop_received.connect(_on_shop)
	net.purse_received.connect(func(_c): _refresh_shop())
	net.inventory_slots_received.connect(func(_b): _refresh_shop())
	items.register_interactable("npc", 25, _probe)
	items.dialogue_key = _key
	items.dialogue_close = close
	_build(layer)


func _probe() -> Dictionary:
	if items.dialogue_open or not player_position.is_valid():
		return {}

	var near: Dictionary = npc_view.nearest(player_position.call(), 3.0)

	if near.is_empty() or not items.in_view(near["pos"]):
		return {}

	var id: String = str(near["id"])
	return {"prompt": "Press E to talk to %s" % str(near["name"]), "tap": func(): net.npc_talk.rpc_id(1, id, -1)}


func _build(layer: CanvasLayer) -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.anchor_left = 0.2
	_panel.anchor_right = 0.8
	_panel.anchor_top = 0.62
	_panel.anchor_bottom = 0.95
	var box: VBoxContainer = VBoxContainer.new()
	_panel.add_child(box)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", FONT_PX + 4)
	_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	box.add_child(_name)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", FONT_PX)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(700, 0)
	box.add_child(_text)
	_choices = VBoxContainer.new()
	box.add_child(_choices)
	layer.add_child(_panel)
	_build_shop(layer)


func _on_say(npc_id: String, npc_name: String, text: String, voice_id: String, choices: PackedStringArray, ends: bool) -> void:
	if text == "" and choices.is_empty():
		close()
		return

	_npc_id = npc_id
	_ends = ends
	_name.text = npc_name
	_text.text = text
	_count = mini(choices.size(), MAX_CHOICES)

	for child in _choices.get_children():
		child.queue_free()

	for i in _count:
		var button: Button = Button.new()
		button.text = "%d  %s" % [i + 1, choices[i]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", FONT_PX)
		var index: int = i
		button.pressed.connect(func(): _choose(index))
		_choices.add_child(button)

	if ends or _count == 0:
		var done: Button = Button.new()
		done.text = "Close (E)"
		done.add_theme_font_size_override("font_size", FONT_PX)
		done.pressed.connect(close)
		_choices.add_child(done)

	_panel.visible = true

	if not items.dialogue_open:
		items.dialogue_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if voice_line.is_valid():
		voice_line.call(voice_id, text)


func _choose(index: int) -> void:
	net.npc_talk.rpc_id(1, _npc_id, index)


func _key(event: InputEventKey) -> bool:
	if _shop_panel != null and _shop_panel.visible:
		if event.keycode == KEY_E or event.keycode == KEY_ESCAPE:
			close()

		return true

	if event.keycode >= KEY_1 and event.keycode <= KEY_5 and event.keycode - KEY_1 < _count:
		_choose(event.keycode - KEY_1)
		return true

	if event.keycode == KEY_E and (_ends or _count == 0):
		close()
		return true

	return true   # while talking, no other quick key acts


func close() -> void:
	if _panel != null:
		_panel.visible = false

	if _shop_panel != null:
		_shop_panel.visible = false

	_shop_npc = ""

	if items != null and items.dialogue_open:
		items.dialogue_open = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_npc_id = ""


# --- the trade window (Dave 2026-10-21): what the trader sells on the left, what the pack can sell on the right, prices in coins ---

const SHOP_PX := 28


func _build_shop(layer: CanvasLayer) -> void:
	_shop_panel = PanelContainer.new()
	_shop_panel.visible = false
	_shop_panel.anchor_left = 0.05
	_shop_panel.anchor_right = 0.95
	_shop_panel.anchor_top = 0.05
	_shop_panel.anchor_bottom = 0.95
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color(0.07, 0.07, 0.08, 0.95)
	back.set_corner_radius_all(10)
	back.set_content_margin_all(18)
	_shop_panel.add_theme_stylebox_override("panel", back)
	var box: VBoxContainer = VBoxContainer.new()
	_shop_panel.add_child(box)
	var head: HBoxContainer = HBoxContainer.new()
	box.add_child(head)
	_shop_title_label = Label.new()
	_shop_title_label.add_theme_font_size_override("font_size", SHOP_PX + 8)
	_shop_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_shop_title_label)
	_shop_purse = Label.new()
	_shop_purse.add_theme_font_size_override("font_size", SHOP_PX)
	head.add_child(_shop_purse)
	var close_button: Button = Button.new()
	close_button.text = "Close (E)"
	close_button.add_theme_font_size_override("font_size", SHOP_PX)
	close_button.pressed.connect(close)
	head.add_child(close_button)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 30)
	box.add_child(columns)

	for side in 2:
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		var title: Label = Label.new()
		title.text = "Buy" if side == 0 else "Sell"
		title.add_theme_font_size_override("font_size", SHOP_PX + 4)
		column.add_child(title)
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(scroll)
		var list: VBoxContainer = VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)

		if side == 0:
			_shop_buy_box = list
		else:
			_shop_sell_box = list

	layer.add_child(_shop_panel)


func _on_shop(npc_id: String, title: String, ids: PackedStringArray, pay_milli: int, get_milli: int, buys: PackedStringArray, tired_ids: PackedStringArray, tired_milli: PackedInt32Array) -> void:
	_shop_npc = npc_id
	_shop_title = title
	_shop_ids = ids
	_shop_pay = float(pay_milli) / 1000.0
	_shop_get = float(get_milli) / 1000.0
	_shop_buys = buys
	_shop_tired.clear()

	for i in tired_ids.size():
		_shop_tired[tired_ids[i]] = float(tired_milli[i]) / 1000.0
	_panel.visible = false
	_shop_panel.visible = true
	_refresh_shop()

	if not items.dialogue_open:
		items.dialogue_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _price_to_pay(value: int) -> int:
	return maxi(int(ceil(float(value) * _shop_pay - 0.0001)), 1) if value > 0 else 0


# What the trader pays for a stack slot of the pack (each), the same rule as the server: worn tools and old food pay less.
func _price_to_get(slot: int) -> int:
	var number: int = items.inventory.numbers[slot]
	var entry: Dictionary = items.table.entry(items.table.id_of(number))
	var value: int = int(entry.get("value", 0))

	if value <= 0 or not (_shop_buys.has("all") or _shop_buys.has(str(entry.get("kind", "")))):
		return 0

	var life: float = 1.0
	var durability: int = int(entry.get("durability", 0))

	if durability > 0:
		life = clampf(1.0 - float(items.inventory.wear[slot]) / float(durability), 0.0, 1.0)

	if items.table.shelf_units(number) > 0:
		life = minf(life, items.table.freshness(number, items.inventory.wear[slot]))

	var tired: float = float(_shop_tired.get(items.table.id_of(number), 1.0))
	return maxi(int(floor(float(value) * _shop_get * tired * life + 0.0001)), 1) if life > 0.0 else 0


func _refresh_shop() -> void:
	if _shop_panel == null or not _shop_panel.visible or _shop_npc == "":
		return

	_shop_title_label.text = _shop_title
	_shop_purse.text = "Purse: %s    " % items.coin_text(items.purse_copper)

	for child in _shop_buy_box.get_children():
		child.queue_free()

	for child in _shop_sell_box.get_children():
		child.queue_free()

	for i in _shop_ids.size():
		var id: String = _shop_ids[i]
		var number: int = items.table.number_of(id)
		var price: int = _price_to_pay(int(items.table.entry(id).get("value", 0)))
		_shop_row(_shop_buy_box, "%s  -  %s" % [items.table.name_of(number), items.coin_text(price)], items._tooltip(number, 1) + "\nYou pay %s each." % items.coin_text(price), i, 0, items.purse_copper >= price)

	var any: bool = false

	for slot in items.inventory.numbers.size():
		if items.inventory.numbers[slot] == 0:
			continue

		var each: int = _price_to_get(slot)

		if each <= 0:
			continue

		any = true
		var number2: int = items.inventory.numbers[slot]
		_shop_row(_shop_sell_box, "%s x%d  -  %s each" % [items.table.name_of(number2), items.inventory.counts[slot], items.coin_text(each)], items._tooltip(number2, items.inventory.counts[slot], items.inventory.wear[slot]) + "\nThe trader pays %s each." % items.coin_text(each), slot, 1, true)

	if not any:
		var none: Label = Label.new()
		none.text = "Nothing in your pack that this trader will buy."
		none.add_theme_font_size_override("font_size", SHOP_PX - 4)
		_shop_sell_box.add_child(none)


func _shop_row(parent: VBoxContainer, text: String, tip: String, index: int, kind: int, enabled: bool) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tip
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", SHOP_PX)
	button.disabled = not enabled
	button.pressed.connect(func(): net.trade.rpc_id(1, _shop_npc, kind, index, 1))
	row.add_child(button)
	var more: Button = Button.new()
	more.text = "x10" if kind == 0 else "All"
	more.add_theme_font_size_override("font_size", SHOP_PX - 4)
	more.disabled = not enabled
	more.pressed.connect(func(): net.trade.rpc_id(1, _shop_npc, kind, index, 10 if kind == 0 else 999))
	row.add_child(more)
