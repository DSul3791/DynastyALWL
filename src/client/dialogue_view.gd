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
var _shop_stock: Dictionary = {}           # item id -> how many he has on the shelf
var _shop_supply: Dictionary = {}          # item id -> supply price multiple (a full shelf is cheaper)
var _shop_repairs: bool = false            # this trader mends tools (data/npcs/shops.json "repairs")
var _extras_kinds: Array = ["material", "food", "medicine"]   # coins.json trade.sell_extras: what the one-click sale may sell
var _extras_below: int = 50                 # and only stacks worth less than this many copper each
var _repair_rate: float = 0.4              # data/items/coins.json trade.repair.rate
var _shop_till: int = -1                   # the coin in the trader's purse, -1 = unlimited
var _shop_tired: Dictionary = {}           # item id -> demand multiple (the trader is tired of buying it)
var _shop_buy_box: VBoxContainer
var _shop_sell_box: VBoxContainer
var _trader_ids: Array = []                 # npc ids in data/npcs/shops.json (they get the extras button)
var _extras_button: Button                   # the same one-click sale on the dialogue screen itself (trade kind 3)
var _shop_sell_all: Button                  # "Sell all but tools": the first press shows the total, the second sells
var _sell_all_result: Array = []             # "Sold ..." segments (text and coin amounts) shown beside the purse after the button
var _shop_sell_all_price: RichTextLabel
var _sell_all_slots: Array = []             # pack slots the button would sell
var _sell_all_total: int = 0
var _shop_purse: RichTextLabel
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
	var shops: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/shops.json"))

	if typeof(shops) == TYPE_DICTIONARY:
		for key in shops:
			if typeof(shops[key]) == TYPE_DICTIONARY and shops[key].has("buys"):
				_trader_ids.append(str(key))

	_extras_button = Button.new()
	_extras_button.text = "Would you like to buy my extra stuff?"
	_extras_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_extras_button.add_theme_font_size_override("font_size", FONT_PX)
	_extras_button.visible = false
	_extras_button.pressed.connect(func(): net.trade.rpc_id(1, _npc_id, 3, 0, 1))
	box.add_child(_extras_button)
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

	if _extras_button != null:
		_extras_button.visible = _trader_ids.has(npc_id)

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
	_sell_all_result = []

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
	_shop_purse = items.make_coin_label(SHOP_PX)
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

		if side == 1:
			_shop_sell_all = Button.new()
			_shop_sell_all.add_theme_font_size_override("font_size", SHOP_PX)
			_shop_sell_all.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_shop_sell_all.pressed.connect(_on_sell_all_pressed)
			var extras_row: HBoxContainer = HBoxContainer.new()
			column.add_child(extras_row)
			extras_row.add_child(_shop_sell_all)
			_shop_sell_all_price = items.make_coin_label(SHOP_PX)
			extras_row.add_child(_shop_sell_all_price)

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


func _on_shop(npc_id: String, title: String, ids: PackedStringArray, pay_milli: int, get_milli: int, buys: PackedStringArray, tired_ids: PackedStringArray, tired_milli: PackedInt32Array, stock: PackedInt32Array, supply_milli: PackedInt32Array, trader_purse: int) -> void:
	_shop_npc = npc_id
	_shop_title = title
	_shop_ids = ids
	_shop_pay = float(pay_milli) / 1000.0
	_shop_get = float(get_milli) / 1000.0
	_shop_buys = buys
	_shop_tired.clear()
	_shop_stock.clear()
	_shop_supply.clear()
	_shop_till = trader_purse
	var shops: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/shops.json"))
	var coins: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/coins.json"))
	_shop_repairs = typeof(shops) == TYPE_DICTIONARY and bool(shops.get(npc_id, {}).get("repairs", false))
	_repair_rate = float(coins.get("trade", {}).get("repair", {}).get("rate", 0.4)) if typeof(coins) == TYPE_DICTIONARY else 0.4

	if typeof(coins) == TYPE_DICTIONARY:
		var extras: Dictionary = coins.get("trade", {}).get("sell_extras", {})
		_extras_kinds = extras.get("kinds", _extras_kinds)
		_extras_below = int(extras.get("valuable_from", _extras_below))

	for i in ids.size():
		_shop_stock[ids[i]] = stock[i]
		_shop_supply[ids[i]] = float(supply_milli[i]) / 1000.0

	for i in tired_ids.size():
		_shop_tired[tired_ids[i]] = float(tired_milli[i]) / 1000.0
	_panel.visible = false
	_shop_panel.visible = true
	_refresh_shop()

	if not items.dialogue_open:
		items.dialogue_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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


# The smith's price for the pack slot, the same rule as the server's repair_cost.
func _repair_cost(slot: int) -> int:
	var number: int = items.inventory.numbers[slot]

	if number == 0:
		return 0

	var entry: Dictionary = items.table.entry(items.table.id_of(number))
	var durability: int = int(entry.get("durability", 0))
	var value: int = int(entry.get("value", 0))
	var worn: int = items.inventory.wear[slot]

	if durability <= 0 or worn <= 0 or value <= 0:
		return 0

	return maxi(int(ceil(float(value) * _repair_rate * clampf(float(worn) / float(durability), 0.0, 1.0) * _shop_pay - 0.0001)), 1)


func _refresh_shop() -> void:
	if _shop_panel == null or not _shop_panel.visible or _shop_npc == "":
		return

	_shop_title_label.text = _shop_title
	var purse_line: Array = ["Purse: ", items.purse_copper, "    "]

	if _shop_till >= 0:
		purse_line.append_array(["His purse: ", _shop_till, "    "])

	purse_line.append_array(_sell_all_result)
	items.fill_coin_line(_shop_purse, purse_line)

	for child in _shop_buy_box.get_children():
		child.queue_free()

	for child in _shop_sell_box.get_children():
		child.queue_free()

	for i in _shop_ids.size():
		var id: String = _shop_ids[i]
		var number: int = items.table.number_of(id)
		var price: int = maxi(int(ceil(float(items.table.entry(id).get("value", 0)) * _shop_pay * float(_shop_supply.get(id, 1.0)) - 0.0001)), 1) if int(items.table.entry(id).get("value", 0)) > 0 else 0
		var left: int = int(_shop_stock.get(id, 0))
		_shop_row(_shop_buy_box, "%s  x%d  -" % [items.table.name_of(number), left] if left > 0 else "%s  -  sold out" % items.table.name_of(number), items._tooltip(number, 1) + "\nYou pay %s each." % items.coin_text(price), i, 0, left > 0 and items.purse_copper >= price, price if left > 0 else -1)

	var any: bool = false
	_sell_all_slots.clear()
	_sell_all_total = 0

	for slot in items.inventory.numbers.size():
		if items.inventory.numbers[slot] == 0:
			continue

		var each: int = _price_to_get(slot)

		if each <= 0:
			continue

		any = true
		var entry2: Dictionary = items.table.entry(items.table.id_of(items.inventory.numbers[slot]))

		if _extras_kinds.has(str(entry2.get("kind", ""))) and str(entry2.get("tool_class", "")) == "" and int(entry2.get("value", 0)) < _extras_below:
			_sell_all_slots.append(slot)
			_sell_all_total += each * items.inventory.counts[slot]

		var number2: int = items.inventory.numbers[slot]
		_shop_row(_shop_sell_box, "%s x%d  -" % [items.table.name_of(number2), items.inventory.counts[slot]], items._tooltip(number2, items.inventory.counts[slot], items.inventory.wear[slot]) + "\nThe trader pays %s each." % items.coin_text(each), slot, 1, true, each, "  each")

	if bool(_shop_repairs):
		for slot in items.inventory.numbers.size():
			var cost: int = _repair_cost(slot)

			if cost > 0:
				var number3: int = items.inventory.numbers[slot]
				_shop_row(_shop_sell_box, "Mend %s  -" % items.table.name_of(number3), items._tooltip(number3, 1, items.inventory.wear[slot]) + "\nThe smith mends it as new for %s." % items.coin_text(cost), slot, 2, items.purse_copper >= cost, cost)

	_update_sell_all()

	if not any:
		var none: Label = Label.new()
		none.text = "Nothing in your pack that this trader will buy."
		none.add_theme_font_size_override("font_size", SHOP_PX - 4)
		_shop_sell_box.add_child(none)


func _update_sell_all() -> void:
	if _shop_sell_all == null:
		return

	_shop_sell_all.disabled = _sell_all_slots.is_empty()
	_shop_sell_all.tooltip_text = "Sells everything except tools, weapons, coins and valuables (worth %s or more each). Sell those one at a time below." % items.coin_text(_extras_below)

	_shop_sell_all.text = "Would you like to buy my extra stuff?"
	items.fill_coin_line(_shop_sell_all_price, ["  about ", _sell_all_total] if not _sell_all_slots.is_empty() else ["  nothing to spare"])


func _on_sell_all_pressed() -> void:
	if _sell_all_slots.is_empty():
		return

	_sell_all_result = ["Sold %d kinds of extra stuff for about " % _sell_all_slots.size(), _sell_all_total, "."]

	for slot in _sell_all_slots.duplicate():
		net.trade.rpc_id(1, _shop_npc, 1, slot, 999)

	_refresh_shop()


func _shop_row(parent: VBoxContainer, text: String, tip: String, index: int, kind: int, enabled: bool, price: int = -1, price_note: String = "") -> void:
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

	if price >= 0:
		var price_label: RichTextLabel = items.make_coin_label(SHOP_PX - 4)
		items.fill_coin_line(price_label, [price, price_note] if price_note != "" else [price])
		row.add_child(price_label)

	var more: Button = Button.new()
	more.visible = kind != 2
	more.text = "x10" if kind == 0 else "All"
	more.add_theme_font_size_override("font_size", SHOP_PX - 4)
	more.disabled = not enabled
	more.pressed.connect(func(): net.trade.rpc_id(1, _shop_npc, kind, index, 10 if kind == 0 else 999))
	row.add_child(more)
