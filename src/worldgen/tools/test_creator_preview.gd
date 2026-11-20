extends SceneTree

# The character creator's preview (scenes/creator_proto/creator_proto.gd, Dave 20 Nov 2026): the body does not spin by itself; a left drag turns it about its upright axis only, never up
# or down; picking a slider's part eases the camera to that part (not a jump), and back to the whole body when a section without a part opens; the wheel zooms toward the pointer and
# back out to exactly the whole body. Uses user://characters_creator_preview_test, never the real characters.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_creator_preview.gd
const CreatorScene := preload("res://scenes/creator_proto/creator_proto.tscn")
const Store := preload("res://src/client/character/character_store.gd")
const DynastyBody := preload("res://src/client/character/dynasty_body.gd")
const BodyModels := preload("res://src/client/character/body_models.gd")
const TEST_DIR := "user://characters_creator_preview_test"
const STEP_S := 1.0 / 60.0

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


func _initialize() -> void:
	_run()


func _run() -> void:
	Store.dir = TEST_DIR
	var screen = CreatorScene.instantiate()
	root.add_child(screen)

	for _i in range(5):
		await process_frame

	_check(screen._body != null, "the preview has a body")
	var still: Vector3 = screen._body.rotation_degrees

	for _i in range(30):
		await process_frame

	_check(screen._body.rotation_degrees.is_equal_approx(still), "the body does not turn by itself (%s then %s)" % [still, screen._body.rotation_degrees])
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(40.0, 0.0)
	screen._preview_input(drag)
	var turned: Vector3 = screen._body.rotation_degrees
	_check(is_equal_approx(fposmod(turned.y - still.y, 360.0), 40.0 * screen.TURN_DEG_PER_PX), "a left drag to the right turns the body (%.1f to %.1f)" % [still.y, turned.y])
	drag.relative = Vector2(0.0, 120.0)
	screen._preview_input(drag)
	_check(screen._body.rotation_degrees.is_equal_approx(turned), "an up or down drag does not tip the body")
	_check(is_zero_approx(screen._body.rotation_degrees.x) and is_zero_approx(screen._body.rotation_degrees.z), "the body only ever turns about its upright axis")
	var hover: InputEventMouseMotion = InputEventMouseMotion.new()
	hover.relative = Vector2(40.0, 0.0)
	screen._preview_input(hover)
	_check(screen._body.rotation_degrees.is_equal_approx(turned), "moving the mouse without the button held does not turn it")

	# A slider's part: the face sliders zoom to the head, eased.
	_check(float(screen._view["tall"]) == float(screen.FULL_VIEW["tall"]), "the page opens on the whole body")
	(screen._sliders["nose"] as HSlider).focus_entered.emit()
	_check(screen._part == "head", "the Nose slider picks the head")
	screen._ease_view(STEP_S)
	var gap: float = float(screen.FULL_VIEW["tall"]) - float(screen.PARTS["head"]["tall"])
	var moved: float = float(screen.FULL_VIEW["tall"]) - float(screen._view["tall"])
	_check(moved > 0.0 and moved < gap * 0.2, "one frame moves only part of the way (smooth, not a jump): %.3f of %.3f" % [moved, gap])
	await _settle(screen)
	_check(absf(float(screen._view["tall"]) - float(screen.PARTS["head"]["tall"])) < 0.01, "the view settles on the head's slice (%.3f)" % float(screen._view["tall"]))
	var head_y: float = float(screen._view["y"])
	_check(head_y > 1.35 and head_y < 1.95, "the view is centred on the head (%.2f m)" % head_y)
	var back: float = (screen._cam as Camera3D).position.z
	_check(back > 0.6 and back < 1.4, "the camera came in close (%.2f m)" % back)

	if DynastyBody.available():
		_check(screen._drawn_y.has("Head"), "the head height is read from the drawn bones")
		# The heights are the drawn ones, slider shapes included: a taller body moves the head view up.
		screen.logic.set_slider("height", 1.0)
		screen._rebuild_body()
		await _settle(screen)
		_check(float(screen._view["y"]) > head_y + 0.03, "Height +1 raises the head view (%.2f to %.2f m)" % [head_y, float(screen._view["y"])])
		screen.logic.set_slider("height", 0.0)
		screen._rebuild_body()

	(screen._sliders["feet"] as HSlider).focus_entered.emit()
	await _settle(screen)
	_check(float(screen._view["y"]) < 0.45, "the Feet slider looks down at the feet (%.2f m)" % float(screen._view["y"]))
	(screen._sliders["height"] as HSlider).focus_entered.emit()
	_check(screen._part == "" and screen._aim == screen.FULL_VIEW, "Height shows the whole body")
	screen.look_at_part("chest")
	screen._open_section("Colours")
	_check(screen._part == "" and screen._aim == screen.FULL_VIEW, "a section without a part shows the whole body")
	screen._open_section("Head and face")
	_check(screen._part == "head", "opening Head and face zooms to the head")
	screen._open_section("")
	_check(screen._aim == screen.FULL_VIEW, "closing every section shows the whole body")

	# The wheel: in toward the pointer, out to exactly the whole body.
	screen.zoom_preview(true, 0.5)
	_check(is_equal_approx(float(screen._aim["y"]), float(screen.FULL_VIEW["y"])) and float(screen._aim["tall"]) < float(screen.FULL_VIEW["tall"]), "wheel in at the middle zooms straight in")
	screen.zoom_preview(true, 0.1)
	_check(float(screen._aim["y"]) > float(screen.FULL_VIEW["y"]), "wheel in near the top moves toward the head")

	for _i in range(30):
		screen.zoom_preview(true, 0.0)

	_check(float(screen._aim["y"]) <= screen.VIEW_HIGH_M, "zooming in at the very top stays on the body (%.2f m)" % float(screen._aim["y"]))

	_check(is_equal_approx(float(screen._aim["tall"]), screen.VIEW_MIN_TALL_M), "zooming in stops at the closest view")

	for _i in range(30):
		screen.zoom_preview(false, 0.5)

	_check(is_equal_approx(float(screen._aim["tall"]), float(screen.FULL_VIEW["tall"])) and is_equal_approx(float(screen._aim["y"]), float(screen.FULL_VIEW["y"])), "zooming out ends on the whole body")

	# Another body model (when the page can switch to one) keeps the drag turn and the part views.
	var models: Array = BodyModels.ids()

	if models.size() > 1 and screen.has_method("_pick_body"):
		screen._pick_body(str(models[1]))
		await process_frame
		_check(is_equal_approx(fposmod(screen._body.rotation_degrees.y, 360.0), fposmod(turned.y, 360.0)), "a new body model faces the way the old one was turned")
		(screen._sliders["jaw"] as HSlider).focus_entered.emit()
		await _settle(screen)
		_check(screen._drawn_y.has("Head") and float(screen._view["y"]) > 1.3, "%s: the head view follows its own bones (%.2f m)" % [models[1], float(screen._view["y"])])

	screen.queue_free()
	await process_frame
	print("creator preview tests: %d failures" % _fails)
	quit(1 if _fails > 0 else 0)


# Eases the view for two seconds of fixed steps; each step waits a frame so the skeleton draws and its bone heights are read.
func _settle(screen) -> void:
	for _i in range(120):
		screen._ease_view(STEP_S)
		await process_frame
