class_name AppConfig
extends RefCounted


const GAME_NAME := "Baked Voxel Game"

const PROTOCOL_VERSION := 2
const WORLD_FORMAT_VERSION := 3
const GENERATOR_VERSION := 3

const DEFAULT_SERVER_ADDRESS := "127.0.0.1"
const DEFAULT_SERVER_PORT := 27855
const DEFAULT_MAX_CLIENTS := 32

const DEFAULT_WORLD_PATH := "res://worlds/base_world"
const DEFAULT_LOCAL_DATA_ROOT := "user://server_data"


static func get_command_line_value(key: String, default_value: String) -> String:
	var prefix := "--%s=" % key

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())

	return default_value
