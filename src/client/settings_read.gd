extends RefCounted

# Reading one saved setting from a ConfigFile without trusting its type (screens and keys check, 23 Nov 2026). A settings file from an older
# build, or one edited by hand, can hold a text, a list or a table where a number or a switch belongs; int() or bool() of a list stops the
# script, so the start would break half way through reading. Each read gives the default instead when the value is not of a usable kind.


static func number(file: ConfigFile, section: String, key: String, default: float) -> float:
	var value: Variant = file.get_value(section, key, default)
	var read: float = default

	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			read = float(value)
		TYPE_BOOL:
			read = 1.0 if value else 0.0
		TYPE_STRING:
			read = float(value) if (value as String).is_valid_float() else default

	return read if is_finite(read) else default   # nan or inf would pass a clamp unchanged


static func whole(file: ConfigFile, section: String, key: String, default: int) -> int:
	return int(round(number(file, section, key, float(default))))


static func flag(file: ConfigFile, section: String, key: String, default: bool) -> bool:
	var value: Variant = file.get_value(section, key, default)

	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return float(value) != 0.0
		TYPE_STRING:
			var text: String = (value as String).strip_edges().to_lower()

			if text in ["true", "on", "yes", "1"]:
				return true

			if text in ["false", "off", "no", "0"]:
				return false

	return default
