extends Control

# The inspection plus (Dave 26 Nov 2026: "regarding the aim reticle for everyday things make it a red + in the middle of the screen when you
# have inspect mode on"): a small red + at the middle of the screen, drawn only while inspection mode (the / key) is on. It marks the point E
# and F choose by (inventory_view.gd reticle_index: the view direction through the middle of the screen). The bow and spear keep their own cross
# (bow_reticle.gd); while that cross is up this one is hidden, so the two are never drawn at once. Hidden too while a menu or the pack has the
# mouse, in the photo camera (K) and behind the spyglass (it has its own centre dot). The size and shade are the thread's pick, not Dave's:
# arms 7 px from the middle, 2 px wide, a thin dark edge so it reads on snow.

const RED := Color(0.86, 0.08, 0.06, 0.95)
const EDGE := Color(0.0, 0.0, 0.0, 0.55)
const ARM_PX := 7.0
const WIDTH_PX := 2.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


# Whether the + shows: inspection on, the weapon's cross not up, and the player's view in play (the mouse turning it, or a picture run, which
# holds the mouse free; not the photo camera or the spyglass).
static func shown(inspecting: bool, weapon_cross_up: bool, view_in_play: bool) -> bool:
	return inspecting and not weapon_cross_up and view_in_play


func show_if(value: bool) -> void:
	if visible != value:
		visible = value


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var at: Vector2 = (size * 0.5).round()

	for pass_index in range(2):
		var color: Color = EDGE if pass_index == 0 else RED
		var arm: float = ARM_PX + (1.0 if pass_index == 0 else 0.0)
		var width: float = WIDTH_PX + (2.0 if pass_index == 0 else 0.0)
		draw_line(at + Vector2(-arm, 0.0), at + Vector2(arm, 0.0), color, width)
		draw_line(at + Vector2(0.0, -arm), at + Vector2(0.0, arm), color, width)
