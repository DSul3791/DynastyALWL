extends RefCounted

# Which water the game runs (Sonny, 1 Nov 2026): the new Dynasty water (src/water2) is the default; the old one (src/water) stays behind `--water-old` on the server
# and the "Old water" switch in Esc > Settings > Gameplay, kept in user://input_settings.cfg like the other client settings. The launcher reads it when it starts
# the server, so a change applies the next time Play is pressed.

const SETTINGS_PATH := "user://input_settings.cfg"


static func old_water(path: String = SETTINGS_PATH) -> bool:
	var file: ConfigFile = ConfigFile.new()

	if file.load(path) != OK:
		return false

	return bool(file.get_value("water", "old", false))


static func set_old_water(on: bool, path: String = SETTINGS_PATH) -> void:
	var file: ConfigFile = ConfigFile.new()
	file.load(path)
	file.set_value("water", "old", on)
	file.save(path)
