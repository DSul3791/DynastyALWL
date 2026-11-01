extends Node

# The real-death screen (Dave: real death at level 10; the build waits for his answers on the cards death-before-heirs, death-new-start and death-downed-state, and
# data/items/death.json "real_death" is false until he says go). The server sends final_death(cause) instead of bringing the character back: the picture goes black, the
# screen says who died and what happened to their things, and one button deletes this character from the machine and returns to the character select page, which
# leads to the creator. Nothing here runs unless the server sends the message.

const CharacterStore := preload("res://src/client/character/character_store.gd")

var active: bool = false

var _layer: CanvasLayer
var _text: Label
var _button: Button


# The words on the screen for a cause of death (empty for a character that was already dead when the player came back).
static func lines(cause: String, character_name: String) -> Array:
	var who: String = character_name if character_name != "" else "Your character"
	var how: String = "" if cause == "" else " (%s)" % cause
	return ["%s has died%s." % [who, how], "Everything they carried lies in their remains, where they fell.", "Their story ends here. A new one can begin."]


func show_for(cause: String, character_name: String) -> void:
	active = true

	if _layer == null:
		_build()

	_text.text = "\n".join(lines(cause, character_name))
	_layer.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 96
	add_child(_layer)
	var black: ColorRect = ColorRect.new()
	black.color = Color(0.0, 0.0, 0.0, 0.94)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(black)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	black.add_child(box)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 28)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_text)
	_button = Button.new()
	_button.text = "Make a new character"
	_button.add_theme_font_size_override("font_size", 24)
	_button.pressed.connect(_new_character)
	box.add_child(_button)
	box.position = Vector2(300.0, 260.0)


# The dead character leaves this machine's list and the select page opens (it sends a player with no characters to the creator).
func _new_character() -> void:
	var id: String = CharacterStore.active_id()

	if id != "":
		CharacterStore.delete(id)

	if Engine.has_meta("creator_done"):
		Engine.remove_meta("creator_done")

	get_tree().change_scene_to_file("res://scenes/launcher.tscn")
