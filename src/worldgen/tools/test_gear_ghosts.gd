extends SceneTree

# The painted gear-slot ghosts (art brief row 20; docs/ui/inventory_crafting_redesign.md section 8): every empty gear well of the You column has its
# painted ghost_<slot>.png in ArtKit.ART_DIR, the ten slots including outer and waist (10 Nov 2026). Each is a square white mask with clear
# holes, which draw_glyph tints to GHOST and shadows itself, so the painting must not carry its own colour or shadow.
# Painted by tools/paint_gear_ghosts.py from the placeholder shapes in ArtKit.glyph_shapes.
#   godot --headless --path . --script res://src/worldgen/tools/test_gear_ghosts.gd

const ArtKit := preload("res://src/client/ui/art_kit.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	ArtKit.clear_cache()
	check(ArtKit.GEAR_GHOST.size() == 10, "ten gear wells to paint")

	for gear in ArtKit.GEAR_GHOST:
		var glyph: String = str(ArtKit.GEAR_GHOST[gear])
		var file: String = str(ArtKit.GLYPH_FILE.get(glyph, ""))
		check(file == "ghost_" + gear, "the %s well's glyph %s is drawn from ghost_%s.png (%s)" % [gear, glyph, gear, file])
		var texture: Texture2D = ArtKit.art(file)
		check(texture != null, "%s.png is painted and loads" % file)

		if texture == null:
			continue

		var image: Image = texture.get_image()
		check(image != null and image.get_width() == image.get_height() and image.get_width() >= 52, "%s.png is square and at least the 52 px it is drawn at" % file)

		if image == null:
			continue

		image.decompress()
		var solid: int = 0
		var clear: int = 0
		var tinted: bool = false

		for y in range(0, image.get_height(), 2):
			for x in range(0, image.get_width(), 2):
				var c: Color = image.get_pixel(x, y)

				if c.a > 0.9:
					solid += 1

					if absf(c.r - c.g) > 0.02 or absf(c.g - c.b) > 0.02:
						tinted = true
				elif c.a < 0.05:
					clear += 1

		var samples: int = (image.get_width() / 2) * (image.get_height() / 2)
		check(solid > samples / 10 and clear > samples / 4, "%s.png: a silhouette on a clear ground (%d solid, %d clear of %d)" % [file, solid, clear, samples])
		check(not tinted, "%s.png is grey, so the game's tint gives its colour" % file)

	print("test_gear_ghosts: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
