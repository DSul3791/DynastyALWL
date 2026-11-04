extends Control

# Listens for the next key press while the Controls page waits for a new binding (Dave 4 Nov 2026). It sits inside the Esc menu,
# sees keys before the menu's own handling, and swallows them while armed, so Esc cancels the capture instead of closing the menu.
# A key pressed with Ctrl or Shift held gives a combination; Ctrl, Shift or Alt pressed and released alone is bound as that key.

signal captured(key: int, ctrl: bool, shift: bool)
signal cancelled

const MODIFIERS := [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]

var armed: bool = false
var _lone_modifier: int = KEY_NONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)


func arm() -> void:
	armed = true
	_lone_modifier = KEY_NONE


func disarm() -> void:
	armed = false
	_lone_modifier = KEY_NONE


func _input(event: InputEvent) -> void:
	if not armed or not (event is InputEventKey):
		return

	get_viewport().set_input_as_handled()

	if event.echo:
		return

	if event.pressed:
		if event.keycode == KEY_ESCAPE:
			disarm()
			cancelled.emit()
		elif event.keycode in MODIFIERS:
			_lone_modifier = event.keycode
		else:
			var key: int = event.keycode
			disarm()
			captured.emit(key, event.ctrl_pressed, event.shift_pressed)
	elif _lone_modifier != KEY_NONE and event.keycode == _lone_modifier:
		var key_alone: int = _lone_modifier
		disarm()
		captured.emit(key_alone, false, false)
