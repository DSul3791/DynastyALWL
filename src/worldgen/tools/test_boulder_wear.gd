extends SceneTree

# A worked rock's size and cracks follow the stones or ore it has left, from the first blow (Dave 21 Nov 2026 play test; src/shared/boulder_wear.gd).
#   godot --headless --path . --script res://src/worldgen/tools/test_boulder_wear.gd

const BoulderWear := preload("res://src/shared/boulder_wear.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var total: int = 740   # about a 2 m stone boulder (radius 1.0, boulders.json yield 0.04, 0.5 kg stones)

	# Size: whole at full, a straight line with the share left, SMALLEST_SHARE at the end.
	check(is_equal_approx(BoulderWear.radius_now(1.0, total, total), 1.0), "a whole rock keeps its full radius")
	check(BoulderWear.radius_now(1.0, total - 1, total) < 1.0, "the first blow already makes it smaller")
	check(is_equal_approx(BoulderWear.radius_now(1.0, 370, total), lerpf(BoulderWear.SMALLEST_SHARE, 1.0, 0.5)), "half the stones gone: the radius is half way to its smallest")
	check(is_equal_approx(BoulderWear.radius_now(1.0, 0, total), BoulderWear.SMALLEST_SHARE), "at the end it is SMALLEST_SHARE of its radius")
	check(BoulderWear.radius_now(2.0, 370, total) == 2.0 * BoulderWear.radius_now(1.0, 370, total), "it scales with the rock's own radius")

	# The old cube root kept 79% of the radius with half the stones gone; the line must be well below that (Dave: "shrink right along with").
	check(BoulderWear.radius_now(1.0, 370, total) < 0.65, "half way it has visibly shrunk, not the old 0.79")

	# Every blow that takes stone makes it smaller and more cracked: no flat stretch anywhere in its life.
	var last_r: float = BoulderWear.radius_now(1.0, total, total)
	var last_c: float = BoulderWear.crack(total, total)
	var steady: bool = true

	for left in range(total - 1, -1, -1):
		var r: float = BoulderWear.radius_now(1.0, left, total)
		var c: float = BoulderWear.crack(left, total)

		if not (r < last_r and c > last_c):
			steady = false

		last_r = r
		last_c = c

	check(steady, "radius falls and cracks grow on every stone taken, from first to last")

	# Step size is the same all the way: the first tenth shrinks as much as the last tenth.
	var first_tenth: float = BoulderWear.radius_now(1.0, total, total) - BoulderWear.radius_now(1.0, total - 74, total)
	var last_tenth: float = BoulderWear.radius_now(1.0, 74, total) - BoulderWear.radius_now(1.0, 0, total)
	check(is_equal_approx(first_tenth, last_tenth), "the first tenth of the stones shrinks it as much as the last tenth")

	# Cracks: none on a whole rock, FIRST_CRACK right after the first blow, 1.0 at the end.
	check(BoulderWear.crack(total, total) == 0.0, "a whole rock has no cracks")
	check(BoulderWear.crack(total - 1, total) >= BoulderWear.FIRST_CRACK, "the first blow shows cracks")
	check(BoulderWear.crack(total - 1, total) * 4.0 >= 0.5, "first-blow cracks are drawn clearly (the overlay's alpha is crack x 4, up to 0.9)")
	check(is_equal_approx(BoulderWear.crack(370, total), lerpf(BoulderWear.FIRST_CRACK, 1.0, 0.5)), "half gone: cracks half way to full")
	check(is_equal_approx(BoulderWear.crack(0, total), 1.0), "fully cracked at the end")

	# Small rocks (a copper rock of 3 stones) and odd rows.
	check(BoulderWear.radius_now(0.3, 2, 3) < 0.3 and BoulderWear.radius_now(0.3, 1, 3) < BoulderWear.radius_now(0.3, 2, 3), "a 3-stone rock shrinks on each of its blows")
	check(is_equal_approx(BoulderWear.radius_now(1.0, 5, 0), 1.0) and BoulderWear.crack(5, 0) == 0.0, "a row with no total is treated as whole")
	check(is_equal_approx(BoulderWear.radius_now(1.0, 900, total), 1.0), "more left than its total never grows it")

	# One rule for the server and the client: the old cube-root copies are gone from both.
	for path in ["res://src/stream/server_items.gd", "res://src/client/inventory_view.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		check(text.contains("BoulderWear.radius_now("), "%s sizes rocks with BoulderWear" % path)
		check(not text.contains("int(info[\"total\"]), 1)), 1.0 / 3.0)") and not text.contains("float(entry[\"total\"]), 1.0 / 3.0)"), "%s has no cube-root rock size left" % path)

	check(FileAccess.get_file_as_string("res://src/client/inventory_view.gd").contains("BoulderWear.crack("), "the client's cracks come from BoulderWear")

	print("test_boulder_wear: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
