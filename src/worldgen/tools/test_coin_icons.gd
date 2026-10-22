extends SceneTree

# Coin icons (Dave 2026-10-22): amounts are drawn as numbers with a coloured circle each, cheapest coin first.
#   godot --headless --path . --script res://src/worldgen/tools/test_coin_icons.gd

const ViewScript := preload("res://src/client/inventory_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var view = ViewScript.new()
	var coins: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/coins.json"))
	view._coins_cfg = coins
	check(view.coin_text(0) == "nothing", "zero reads nothing")
	check(view.coin_text(2345) == "5 copper, 4 bronze, 3 silver, 2 gold", "words run cheapest first (%s)" % view.coin_text(2345))
	var label: RichTextLabel = view.make_coin_label(24)
	view.fill_coin_line(label, ["Purse: ", 2345, "."])
	check(label.get_parsed_text().begins_with("Purse: 5 "), "text then copper first (%s)" % label.get_parsed_text())
	check(label.get_parsed_text().count(" ") >= 4, "four coin groups separated")
	view.fill_coin_line(label, [0])
	check(label.get_parsed_text() == "nothing", "zero amount reads nothing in the line")
	check(view.coin_icon("coin_gold") != view.coin_icon("coin_silver") and view.coin_icon("coin_gold") == view.coin_icon("coin_gold"), "one cached icon per coin")
	label.free()
	view.free()
	print("coin icons: %d failures" % failures)
	quit(1 if failures > 0 else 0)
