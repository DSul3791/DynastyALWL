extends Control

# The Goal Achieved placard (docs/design/PLAYER_JOURNAL_GOALS_UI.md "Goal Achieved placard"; GA-89, GA-93, GA-94, GA-95): Dave's ornate art
# (assets/ui/goal_placard/goal_achieved_blank.png, "Goal Achieved" and "Reward" painted in) with the goal's real name in the parchment band and the
# coins the server really paid in the blue reward box. It spins and grows in (ENTER_S), stays readable (HOLD_S), spins and shrinks away (EXIT_S),
# with a short trumpet fanfare (assets/audio/ui/ui_goal_0.ogg, own synthesis). Completions queue: one placard and one fanfare at a time, each
# once. Presentation only: it takes no input (mouse ignored, no keys), never pauses the game and pays nothing (the server already has).

const ArtKit := preload("res://src/client/ui/art_kit.gd")
const SoundStage := preload("res://src/client/sound_stage.gd")
const ART := "res://assets/ui/goal_placard/goal_achieved_blank.png"
const ART_SIZE := Vector2(1448.0, 1086.0)
const NAME_BOX := Rect2(360.0, 470.0, 728.0, 150.0)      # the parchment band between the two ornament rules, in art px
const REWARD_BOX := Rect2(372.0, 728.0, 704.0, 128.0)    # the blue reward box under the "Reward" tab, in art px
const NAME_INK := Color("#3A2310")
const REWARD_GOLD := Color("#F5D37A")
const WIDTH_PX := 600.0                                  # on the 1920 x 1080 canvas
const CENTRE_Y := 0.31                                   # of the screen height: above the crosshair
const ENTER_S := 0.6
const HOLD_S := 4.0
const EXIT_S := 0.5
const FANFARE_DB := -10.0

var queue: Array = []                                    # [title, copper, item text] waiting their turn
var showing: bool = false
var shown_count: int = 0                                 # placards started (tests)

var _items                                               # InventoryView: coin line and item names
var _card: Control
var _name: Label
var _reward: RichTextLabel
var _player: AudioStreamPlayer
var _fanfare: AudioStream


func setup(items, book) -> void:
	_items = items
	name = "GoalPlacard"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	var art: TextureRect = TextureRect.new()
	art.texture = _art()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(art)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	_name.add_theme_color_override("font_color", NAME_INK)
	_card.add_child(_name)
	_reward = _items.make_coin_label(32)
	_reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward.bbcode_enabled = false
	_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reward.add_theme_font_override("normal_font", ArtKit.font("garamond_semibold"))
	_reward.add_theme_color_override("default_color", REWARD_GOLD)
	_reward.add_theme_constant_override("outline_size", 4)
	_reward.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.15, 0.9))
	_card.add_child(_reward)
	_player = AudioStreamPlayer.new()
	SoundStage._make_bus("Interface")
	_player.bus = "Interface"
	_player.volume_db = FANFARE_DB
	add_child(_player)
	var found: Array = SoundStage._find("res://assets/audio/recorded/ui/", "ui_goal")

	if found.is_empty():
		found = SoundStage._find("res://assets/audio/ui/", "ui_goal")

	_fanfare = found[0] if not found.is_empty() else null
	book.achieved.connect(func(row: Dictionary, copper: int) -> void: announce(str(row["title"]), copper, _item_text(row)))


# The painted template; read straight from the png when the editor has not imported it yet (a fresh checkout).
static func _art() -> Texture2D:
	if ResourceLoader.exists(ART):
		return load(ART) as Texture2D

	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(ART))
	return ImageTexture.create_from_image(image) if image != null else null


# A legacy item reward ("4 Sticks"); coin rewards are drawn as coins. The server sends only copper with goal_done, so the item comes from the goal list.
func _item_text(row: Dictionary) -> String:
	if str(row.get("item", "")) == "" or int(row.get("item_n", 0)) <= 0:
		return ""

	var number: int = _items.table.number_of(str(row["item"]))
	return "%d %s" % [int(row["item_n"]), _items.table.name_of(number) if number > 0 else str(row["item"])]


# Queues one placard. Called once per goal_done (GoalBook.achieved), never for the join's list.
func announce(title: String, copper: int, item_text: String = "") -> void:
	queue.append([title, copper, item_text])

	if not showing:
		_next()


func _next() -> void:
	if queue.is_empty():
		showing = false
		_card.visible = false
		return

	showing = true
	shown_count += 1
	var entry: Array = queue.pop_front()
	_fill(str(entry[0]), int(entry[1]), str(entry[2]))
	_card.visible = true
	_card.rotation = -TAU
	_card.scale = Vector2(0.05, 0.05)
	_card.modulate = Color(1.0, 1.0, 1.0, 0.0)

	if _fanfare != null:
		_player.stream = _fanfare
		_player.play()

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_card, "rotation", 0.0, ENTER_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "scale", Vector2.ONE, ENTER_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, ENTER_S * 0.5)
	tween.chain().tween_interval(HOLD_S)
	tween.chain().tween_property(_card, "rotation", TAU, EXIT_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_card, "scale", Vector2(0.05, 0.05), EXIT_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_card, "modulate:a", 0.0, EXIT_S).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_next)


# Places the card and writes its two lines, sized to the screen; a long name steps its text down until it fits the band.
func _fill(title: String, copper: int, item_text: String) -> void:
	var view: Vector2 = get_viewport_rect().size
	var width: float = minf(WIDTH_PX * view.y / 1080.0, view.x * 0.9)
	var k: float = width / ART_SIZE.x
	var card_size: Vector2 = ART_SIZE * k
	_card.size = card_size
	_card.position = Vector2((view.x - card_size.x) * 0.5, view.y * CENTRE_Y - card_size.y * 0.5)
	_card.pivot_offset = card_size * 0.5
	_name.position = NAME_BOX.position * k
	_name.size = NAME_BOX.size * k
	_name.text = title
	_name.add_theme_font_size_override("font_size", fit_px(ArtKit.font("garamond_semibold"), title, _name.size, int(64.0 * k), int(30.0 * k)))
	_reward.position = REWARD_BOX.position * k
	_reward.size = REWARD_BOX.size * k
	var px: int = int(52.0 * k)
	_reward.add_theme_font_size_override("normal_font_size", px)
	_reward.set_meta("px", px)
	var segments: Array = []

	if copper > 0:
		segments.append(copper)

	if item_text != "":
		segments.append(("  " if copper > 0 else "") + item_text)

	if segments.is_empty():
		segments.append(0)   # "nothing": the goal paid no coins (a full purse)

	_items.fill_coin_line(_reward, segments)


# The largest font size from `most` down to `least` at which `text` wraps inside `box`.
static func fit_px(face: Font, text: String, box: Vector2, most: int, least: int) -> int:
	var px: int = most

	while px > least:
		var need: Vector2 = face.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, box.x, px) if face != null else Vector2.ZERO

		if need.x <= box.x and need.y <= box.y:
			break

		px -= 2

	return maxi(px, least)
