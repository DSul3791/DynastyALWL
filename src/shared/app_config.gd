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
