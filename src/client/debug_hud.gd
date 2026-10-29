extends RefCounted

# The on-screen debug details (F3, or Esc > Settings > Debug details; off by default, owner
# 2026-10-20). Threads add their own diagnostic line without touching terrain_client.gd:
#
#   client.debug_hud.add_line("water", func() -> String: return "water: %d cells" % cells)
#
# A line's Callable is only called while the details are on, so nothing is built when they
# are off. Adding the same name again replaces that line.

var enabled: bool = false

var _names: Array = []
var _lines: Dictionary = {}


func add_line(line_name: String, text_of: Callable) -> void:
	if not _lines.has(line_name):
		_names.append(line_name)

	_lines[line_name] = text_of


func text() -> String:
	var out: PackedStringArray = PackedStringArray()

	for line_name in _names:
		var text_of: Callable = _lines[line_name]

		if text_of.is_valid():
			out.append(str(text_of.call()))

	return "\n".join(out)
