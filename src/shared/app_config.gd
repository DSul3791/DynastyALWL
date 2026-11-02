class_name AppConfig
extends RefCounted


const PROTOCOL_VERSION := 2
const GENERATOR_VERSION := 3


static func get_command_line_value(key: String, default_value: String) -> String:
	var prefix := "--%s=" % key

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())

	return default_value


# True when a bare switch like --test is on the command line, before or after the `--` (Dave, 2 Nov 2026: test builds skip the character pages).
# `args` is for tests; the default reads the real command line.
static func has_flag(name: String, args: PackedStringArray = PackedStringArray()) -> bool:
	var list: PackedStringArray = args if not args.is_empty() else OS.get_cmdline_args() + OS.get_cmdline_user_args()
	return list.has("--" + name)
