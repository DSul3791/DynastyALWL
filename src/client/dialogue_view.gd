extends Node

# Talking to an NPC (protocol 45): "Press E to talk to <name>" through the interaction registry, then a panel at the bottom of the
# screen with the NPC's name, their line and the choices (click, or keys 1 to 5). Esc or the last line closes it. The line carries
# a voice_id for text to voice (Mandy hooks that up through voice_line). Fonts are 20 px on the 1920x1080 canvas (26 on the old 2880x1620 one), readable on a 55 inch 4K.

const SmithingRules := preload("res://src/shared/smithing_rules.gd")
const TradePrices := preload("res://src/shared/trade_prices.gd")   # the server's own price sums (server_trade.gd)
const KeyBindings := preload("res://src/client/key_bindings.gd")
const FONT_PX := 20
const MAX_CHOICES := 5

var net
var items                       # InventoryView (screen state and the registry)
var npc_view
var player_position: Callable
var voice_line: Callable = Callable()   # (voice_id, text) -> void; text to voice listens here

var _panel: PanelContainer = null
var _shop_close: Button = null             # its Close button, relabelled with the bound key each time it opens
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
var _demand_drop: float = 0.03             # coins.json trade.demand: each unit sold lowers the next one's price by this much of the base
var _demand_floor: float = 0.3             # and never under this
var _shop_till: int = -1                   # the coin in the trader's purse, -1 = unlimited
var _shop_tired: Dictionary = {}           # item id -> demand multiple (the trader is tired of buying it)
var _shop_rules: Dictionary = {}           # item id -> this trader's buy rule (data/npcs/shops.json buy_rules: lot, lot_value)
var _shop_buy_box: VBoxContainer
var _shop_sell_box: VBoxContainer
var _trader_ids: Array = []                 # npc ids in data/npcs/shops.json (they get the extras button)
var _extras_button: Button                   # the same one-click sale on the dialogue screen itself (trade kind 3)
var _shop_sell_all: Button                  # "Sell all but tools": the first press shows the total, the second sells
var _shop_sell_all_price: RichTextLabel
var _sell_all_slots: Array = []             # pack slots the button would sell
var _sell_all_total: int = 0
var _shop_purse: RichTextLabel
var _shop_title_label: Label
var _talk_reply: Label                      # a server notice while talking (Hob's order of the day): the notice line sits behind the talk window now that it is mid-screen
var _shop_reply: Label                      # the trader's last answer ("Sold ...", "I've bought all I can ..."): the notice line sits behind this window (TEST-003)
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
	net.inventory_full_received.connect(func(_b): _refresh_shop())   # a sale that shrinks the pack comes as the whole pack (protocol 116)
	net.notice_received.connect(_on_notice)
	items.register_interactable("npc", 25, _probe)
	items.dialogue_key = _key
	items.dialogue_close = close
	_build(layer)


const CHEST := Vector3(0.0, 1.2, 0.0)   # a person is aimed at by the chest, where the reticle rests when you look at them, not by the feet


func _probe() -> Dictionary:
	if items.dialogue_open or not player_position.is_valid():
		return {}

	# Of the people within 3 m and in view, the one nearest the reticle, else the nearest (Dave 21 Nov 2026: E acts on what the reticle is on first).
	var seen: Array = npc_view.within(player_position.call(), 3.0).filter(func(n): return items.in_view(n["pos"]))

	if seen.is_empty():
		return {}

	var aimed: int = items.reticle_index(seen.map(func(n): return n["pos"] + CHEST))
	var near: Dictionary = seen[maxi(aimed, 0)]

	var id: String = str(near["id"])
	return {"kind": "npc", "point": near["pos"] + CHEST, "prompt": "Press E to talk to %s" % str(near["name"]), "tap": func(): net.npc_talk.rpc_id(1, id, -1)}


func _build(layer: CanvasLayer) -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.anchor_left = 0.2
	_panel.anchor_right = 0.8
	_panel.anchor_top = 0.3   # the middle of the screen, clear of the hotbar at the bottom (Dave, 13 Nov 2026)
	_panel.anchor_bottom = 0.7
	var box: VBoxContainer = VBoxContainer.new()
	_panel.add_child(box)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", FONT_PX + 2)
	_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	box.add_child(_name)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", FONT_PX)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(560, 0)
	box.add_child(_text)
	_talk_reply = Label.new()
	_talk_reply.add_theme_font_size_override("font_size", FONT_PX)
	_talk_reply.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_talk_reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talk_reply.visible = false   # no blank line when there is no notice
	box.add_child(_talk_reply)
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
		done.text = "Close (%s)" % KeyBindings.label("interact")
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
	_talk_reply.visible = false
	_talk_reply.text = ""   # cleared here, not in _on_say: the server sends a choice's notice before the next line
	net.npc_talk.rpc_id(1, _npc_id, index)


func _key(event: InputEventKey) -> bool:
	if _shop_panel != null and _shop_panel.visible:
		if KeyBindings.matches(event, "interact") or event.keycode == KEY_ESCAPE:
			close()

		return true

	if event.keycode >= KEY_1 and event.keycode <= KEY_5 and event.keycode - KEY_1 < _count:
		_choose(event.keycode - KEY_1)
		return true

	if KeyBindings.matches(event, "interact") and (_ends or _count == 0):
		close()
		return true

	return true   # while talking, no other quick key acts


func close() -> void:
	if _panel != null:
		_panel.visible = false

	if _shop_panel != null:
		_shop_panel.visible = false

	_shop_npc = ""

	if _shop_reply != null:
		_shop_reply.text = ""

	if _talk_reply != null:
		_talk_reply.text = ""
		_talk_reply.visible = false

	if items != null and items.dialogue_open:
		items.dialogue_open = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_npc_id = ""


# --- the trade window (Dave 2026-10-21): what the trader sells on the left, what the pack can sell on the right, prices in coins ---

const SHOP_PX := 20


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
	_shop_title_label.add_theme_font_size_override("font_size", SHOP_PX + 6)
	_shop_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_shop_title_label)
	_shop_purse = items.make_coin_label(SHOP_PX)
	head.add_child(_shop_purse)
	var close_button: Button = Button.new()
	_shop_close = close_button
	close_button.text = "Close (%s)" % KeyBindings.label("interact")
	close_button.add_theme_font_size_override("font_size", SHOP_PX)
	close_button.pressed.connect(close)
	head.add_child(close_button)
	_shop_reply = Label.new()
	_shop_reply.add_theme_font_size_override("font_size", SHOP_PX)
	_shop_reply.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_shop_reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_shop_reply)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	box.add_child(columns)

	for side in 2:
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		var title: Label = Label.new()
		title.text = "Buy" if side == 0 else "Sell"
		title.add_theme_font_size_override("font_size", SHOP_PX + 2)
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
	_shop_rules = (shops.get(npc_id, {}).get("buy_rules", {}) as Dictionary) if typeof(shops) == TYPE_DICTIONARY else {}
	_repair_rate = float(coins.get("trade", {}).get("repair", {}).get("rate", 0.4)) if typeof(coins) == TYPE_DICTIONARY else 0.4

	if typeof(coins) == TYPE_DICTIONARY:
		var extras: Dictionary = coins.get("trade", {}).get("sell_extras", {})
		_extras_kinds = extras.get("kinds", _extras_kinds)
		_extras_below = int(extras.get("valuable_from", _extras_below))
		_demand_drop = float(coins.get("trade", {}).get("demand", {}).get("drop_per_sale", _demand_drop))
		_demand_floor = float(coins.get("trade", {}).get("demand", {}).get("floor", _demand_floor))

	for i in ids.size():
		_shop_stock[ids[i]] = stock[i]
		_shop_supply[ids[i]] = float(supply_milli[i]) / 1000.0

	for i in tired_ids.size():
		_shop_tired[tired_ids[i]] = float(tired_milli[i]) / 1000.0
	_panel.visible = false
	_shop_panel.visible = true
	_shop_close.text = "Close (%s)" % KeyBindings.label("interact")   # the key may have been rebound since the window was built
	_refresh_shop()

	if not items.dialogue_open:
		items.dialogue_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# What the trader pays for a stack slot of the pack, the same rule as the server: [the lot he buys it in, what he pays a lot] (a lot is one unit
# for most goods; cheap goods go by items.json sell_lot, and his own buy rule wins). Worn tools and old food pay less; [1, 0] when he pays nothing.
func _price_to_get(slot: int) -> Array:
	var number: int = items.inventory.numbers[slot]
	var entry: Dictionary = items.table.entry(items.table.id_of(number))
	var terms: Array = TradePrices.sell_terms(entry, _shop_rules.get(items.table.id_of(number), {}), SmithingRules.value_mult(items.inventory.inst_of(slot)))   # craftsmanship raises it, as on the server
	var value: int = int(terms[1])

	if value <= 0 or not (_shop_buys.has("all") or _shop_buys.has(str(entry.get("kind", "")))):
		return [1, 0]

	var life: float = 1.0
	var durability: int = items.inventory.max_durability(slot)

	if durability > 0:
		life = clampf(1.0 - float(items.inventory.wear[slot]) / float(durability), 0.0, 1.0)

	if items.table.shelf_units(number) > 0:
		life = minf(life, items.table.freshness(number, items.inventory.wear[slot]))

	var tired: float = float(_shop_tired.get(items.table.id_of(number), 1.0))
	return [int(terms[0]), TradePrices.lot_to_get(value, _shop_get * tired, life), value, life, tired]


# " each", or " for 60" for goods sold by the lot.
func _lot_note(lot: int) -> String:
	return "  each" if lot <= 1 else "  for %d" % lot


# The smith's price for the pack slot, the same rule as the server's repair_cost.
func _repair_cost(slot: int) -> int:
	var number: int = items.inventory.numbers[slot]

	if number == 0:
		return 0

	var entry: Dictionary = items.table.entry(items.table.id_of(number))
	var durability: int = items.inventory.max_durability(slot)
	var value: int = int(entry.get("value", 0))
	var worn: int = items.inventory.wear[slot]

	if durability <= 0 or worn <= 0 or value <= 0 or SmithingRules.disposable(entry):
		return 0

	return maxi(int(ceil(float(value) * _repair_rate * clampf(float(worn) / float(durability), 0.0, 1.0) * _shop_pay - 0.0001)), 1)


func _refresh_shop() -> void:
	if _shop_panel == null or not _shop_panel.visible or _shop_npc == "":
		return

	_shop_title_label.text = _shop_title
	var purse_line: Array = ["Purse: ", items.purse_coins, "    "]   # coins as held

	if _shop_till >= 0:
		purse_line.append_array(["His purse: ", _shop_till, "    "])

	items.fill_coin_line(_shop_purse, purse_line)

	for child in _shop_buy_box.get_children():
		child.queue_free()

	for child in _shop_sell_box.get_children():
		child.queue_free()

	for i in _shop_ids.size():
		var id: String = _shop_ids[i]
		var number: int = items.table.number_of(id)
		var price: int = TradePrices.lot_to_pay(int(items.table.entry(id).get("value", 0)), _shop_pay * float(_shop_supply.get(id, 1.0)))   # a lot's price, as the server charges
		var lot: int = TradePrices.shelf_lot(items.table.entry(id))
		var left: int = int(_shop_stock.get(id, 0))
		var first: int = TradePrices.total_to_pay(price, lot, mini(lot, maxi(left, 1)))   # what one click buys (a lot, or what is left of one)
		_shop_row(_shop_buy_box, "%s  x%d  -" % [items.table.name_of(number), left] if left > 0 else "%s  -  sold out" % items.table.name_of(number), items._tooltip(number, 1) + "\nYou pay %s%s." % [items.coin_text(price), _lot_note(lot)], i, 0, left > 0 and items.purse_copper >= first, price if left > 0 else -1, "" if lot <= 1 else _lot_note(lot), lot)

	var any: bool = false
	_sell_all_slots.clear()
	_sell_all_total = 0
	var till: int = _shop_till if _shop_till >= 0 else 1 << 30   # the one-click sale stops where his purse does, as the server's does
	var sold_by_id: Dictionary = {}   # units of an item the estimate has sold already: a second stack starts at the lower price, as on the server

	for slot in items.inventory.numbers.size():
		if items.inventory.numbers[slot] == 0:
			continue

		var quote: Array = _price_to_get(slot)
		var lot2: int = int(quote[0])
		var each: int = int(quote[1])

		if each <= 0:
			continue

		any = true
		var entry2: Dictionary = items.table.entry(items.table.id_of(items.inventory.numbers[slot]))

		if _extras_kinds.has(str(entry2.get("kind", ""))) and str(entry2.get("tool_class", "")) == "" and int(entry2.get("value", 0)) < _extras_below and not items.inventory.inst_of(slot).has("bag") and not items.inventory.maturing_at(slot):   # the server refuses a full bag and a maturing batch
			_sell_all_slots.append(slot)
			var id2: String = items.table.id_of(items.inventory.numbers[slot])
			var start: float = maxf(float(quote[4]) - _demand_drop * float(sold_by_id.get(id2, 0)), _demand_floor)
			var made: Array = TradePrices.sale(int(quote[2]), lot2, items.inventory.counts[slot], _shop_get, start, _demand_drop, _demand_floor, float(quote[3]), till)   # the falling price and his purse, as the server pays (a trader's daily limit is not known here: "about")
			_sell_all_total += int(made[1])
			till -= int(made[1])
			sold_by_id[id2] = int(sold_by_id.get(id2, 0)) + int(made[0])

		var number2: int = items.inventory.numbers[slot]
		_shop_row(_shop_sell_box, "%s x%d  -" % [items.table.name_of(number2), items.inventory.counts[slot]], items._tooltip(number2, items.inventory.counts[slot], items.inventory.wear[slot], items.inventory.inst_of(slot)) + "\nThe trader pays %s%s." % [items.coin_text(each), _lot_note(lot2)], slot, 1, items.inventory.counts[slot] >= lot2, each, _lot_note(lot2), lot2)

	if bool(_shop_repairs):
		for slot in items.inventory.numbers.size():
			var cost: int = _repair_cost(slot)

			if cost > 0:
				var number3: int = items.inventory.numbers[slot]
				_shop_row(_shop_sell_box, "Mend %s  -" % items.table.name_of(number3), items._tooltip(number3, 1, items.inventory.wear[slot], items.inventory.inst_of(slot)) + "\nThe smith mends it as new for %s." % items.coin_text(cost), slot, 2, items.purse_copper >= cost, cost)

	_update_sell_all()

	if not any:
		var none: Label = Label.new()
		none.text = "Nothing in your pack that this trader will buy."
		none.add_theme_font_size_override("font_size", SHOP_PX - 4)
		_shop_sell_box.add_child(none)


# While the trade or talk window is open, the server's notices (the trader's answers to each deal) are shown in it.
func _on_notice(text: String) -> void:
	if _shop_reply != null and _shop_panel != null and _shop_panel.visible:
		_shop_reply.text = text
	elif _talk_reply != null and _panel != null and _panel.visible:
		_talk_reply.text = text
		_talk_reply.visible = true


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

	net.trade.rpc_id(1, _shop_npc, 3, 0, 0)   # one sale on the server; its answer ("Sold 7 kinds of extra stuff for <what he really paid>") shows in the reply line (Dave 24 Nov 2026)


# `step`: the units one click buys or sells (a lot of goods sold by the lot); x10 buys ten of those, All sells the stack.
func _shop_row(parent: VBoxContainer, text: String, tip: String, index: int, kind: int, enabled: bool, price: int = -1, price_note: String = "", step: int = 1) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tip
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", SHOP_PX)
	button.disabled = not enabled
	button.pressed.connect(func(): net.trade.rpc_id(1, _shop_npc, kind, index, step if kind != 2 else 1))
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
	more.pressed.connect(func(): net.trade.rpc_id(1, _shop_npc, kind, index, mini(10 * step, 999) if kind == 0 else 999))
	row.add_child(more)
