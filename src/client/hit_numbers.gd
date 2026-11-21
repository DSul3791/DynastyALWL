extends RefCounted

# Floating damage numbers (Dave 2 Nov 2026): where a hit lands, the damage floats up and fades. On by default; Esc > Settings > Gameplay,
# Damage numbers turns it off (display_settings.gd damage_numbers). The server sends hit_number(at, amount) (protocol 86): an animal shows the
# damage it took, a tree or a boulder its share of 100 per blow.

const RISE_M := 1.0          # how far the number floats up
const LIFE_S := 1.4          # how long it shows (Dave 19 Nov 2026: he could not tell a spear was hurting a bear; was 0.9 s)
const HOLD_S := 0.5          # it stays full strength this long before it fades
const FONT_SIZE := 96        # was 64; PROVISIONAL HIT-1 with LIFE_S and POP
const POP := 1.35            # it pops in this much larger and settles to its size in POP_S
const POP_S := 0.12
const COLOR := Color(1.0, 0.86, 0.35)


# The text for an amount (always at least 1).
static func text_for(amount: int) -> String:
	return str(maxi(amount, 1))


# A label at `at` under `parent`, rising and fading, then freed. Returns it (tests read it).
static func spawn(parent: Node, at: Vector3, amount: int) -> Label3D:
	var label: Label3D = Label3D.new()
	label.name = "HitNumber"
	label.text = text_for(amount)
	label.font_size = FONT_SIZE
	label.pixel_size = 0.004
	label.outline_size = 12
	label.modulate = COLOR
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true                     # seen through leaves and bark
	label.fixed_size = false
	label.shaded = false
	label.position = at + Vector3(randf_range(-0.15, 0.15), 0.0, randf_range(-0.15, 0.15))   # two quick hits do not sit on each other
	parent.add_child(label)

	if label.is_inside_tree():
		var tween: Tween = label.create_tween()
		tween.set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y + RISE_M, LIFE_S).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(label, "modulate:a", 0.0, LIFE_S - HOLD_S).set_delay(HOLD_S).set_ease(Tween.EASE_IN)
		tween.tween_property(label, "outline_modulate:a", 0.0, LIFE_S - HOLD_S).set_delay(HOLD_S).set_ease(Tween.EASE_IN)
		label.scale = Vector3.ONE * POP
		tween.tween_property(label, "scale", Vector3.ONE, POP_S).set_ease(Tween.EASE_OUT)
		tween.chain().tween_callback(label.queue_free)

	return label
