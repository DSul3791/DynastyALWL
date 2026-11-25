extends RefCounted

# Where a client-only build (the testers' download) joins: it never starts a server of its own (server/client split, plan step A2,
# /mnt/project-files/server-client-split/PLAN.md). The address comes from the server last chosen on the server pick page
# (user://join_address.cfg), else from client_config.json shipped beside the game (or inside it), else nothing yet.
# A normal editor or PC run is not client-only and keeps Play's own local server (launcher.gd _host_and_play).
#   client_config.json: {"server": "play.example.org:24600"}

const SAVED := "user://join_address.cfg"
const CONFIG_NAME := "client_config.json"
const DEFAULT_PORT := 24600

static var saved_path: String = SAVED      # tests point it elsewhere so they never touch a player's own note


# The export preset of the client gives it the "client_only" feature; --client-only does the same on a PC for tests.
static func client_only() -> bool:
	return OS.has_feature("client_only") or AppConfig.has_flag("client-only")


# "host", "host:port" -> {"host", "port"}, or {"error": plain words} when it cannot be used.
# shortcut: IPv6 addresses (more than one ':') are refused; revisit if a tester's server is IPv6 only.
static func parse(text: String) -> Dictionary:
	var address: String = text.strip_edges()

	if address == "":
		return {"error": "The Address box (the first one) is empty: type the server's address there, for example play.example.org or 203.0.113.5:24600."}

	var parts: PackedStringArray = address.split(":")

	if parts.size() > 2 or parts[0] == "" or parts[0].contains(" "):
		return {"error": "\"%s\" is not a server address. Use a name or IP, and :port only if the server is not on %d." % [address, DEFAULT_PORT]}

	var port: int = DEFAULT_PORT

	if parts.size() == 2:
		if not parts[1].is_valid_int() or int(parts[1]) < 1 or int(parts[1]) > 65534:
			return {"error": "The port in \"%s\" must be a number from 1 to 65534." % address}

		port = int(parts[1])

	return {"host": parts[0], "port": port}


# The address to show and join: the last one typed here, else the shipped client_config.json, else "".
static func current() -> String:
	var file: ConfigFile = ConfigFile.new()

	if file.load(saved_path) == OK and str(file.get_value("join", "address", "")) != "":
		return str(file.get_value("join", "address", ""))

	for path in [OS.get_executable_path().get_base_dir().path_join(CONFIG_NAME), "res://" + CONFIG_NAME]:
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

			if parsed is Dictionary and str(parsed.get("server", "")) != "":
				return str(parsed["server"])

	return ""


static func save(address: String) -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("join", "address", address.strip_edges())
	file.save(saved_path)
