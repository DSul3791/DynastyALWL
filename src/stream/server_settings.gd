extends RefCounted

# What a server tells players before they join, and its password (docs/design/SERVER_PICK_PAGE.md). Set by whoever runs it in the store's
# server.json; every key is optional and a missing file is an open server with no name, as before:
#   {"name": "Hannibal's House", "message": "Bring an axe, the north woods are full.", "password": "typed here once"}
# A plain "password" is replaced at start by "password_salt" and "password_hash" (SHA256(salt + password)) and the file rewritten, so the
# password itself stays on disk only until the server first starts. Docker: the environment variable DYNASTY_SERVER_PASSWORD sets it
# instead (hashed in memory only, never written) and wins over the file; empty or unset leaves the file's setting. deploy/server/SERVER.md.
# The salt is kept in the file and reused (it is not secret), so a player's remembered password keeps working across restarts.
# A server.json that cannot be read stops the server (problem): it must never open a password server to everyone by a typo.

const ServerAuth := preload("res://src/shared/server_auth.gd")
const FILE := "server.json"
const ENV_PASSWORD := "DYNASTY_SERVER_PASSWORD"
const NAME_MAX := 48
const MESSAGE_MAX := 160

var server_name: String = ""
var message: String = ""
var salt: PackedByteArray = PackedByteArray()
var password_hash: PackedByteArray = PackedByteArray()   # empty: open
var note: String = ""                                    # one line for the start log (never the password)
var problem: String = ""                                 # not empty: the server must not start (says why)


func load_from(store_dir: String) -> void:
	var path: String = store_dir.path_join(FILE)
	var data: Dictionary = {}

	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

		if not parsed is Dictionary:
			problem = "%s is not readable JSON. Fix it (or remove it for an open server with no name) and start again." % path
			return

		data = parsed

	server_name = str(data.get("name", "")).strip_edges().left(NAME_MAX)
	message = str(data.get("message", "")).strip_edges().left(MESSAGE_MAX)
	var kept_salt: PackedByteArray = str(data.get("password_salt", "")).hex_decode()

	if kept_salt.size() < 16:
		kept_salt = Crypto.new().generate_random_bytes(16)

	if str(data.get("password", "")) != "":
		salt = Crypto.new().generate_random_bytes(16)   # a new password gets a new salt: players' remembered old one is quietly ignored
		password_hash = ServerAuth.hash_password(salt, str(data["password"]))
		data.erase("password")
		data["password_salt"] = salt.hex_encode()
		data["password_hash"] = password_hash.hex_encode()
		kept_salt = salt
		var written: String = _write(path, data)
		note += written if written != "" else "the password in server.json is now stored hashed. "
	elif str(data.get("password_hash", "")) != "":
		if str(data.get("password_salt", "")).hex_decode().size() < 16 or str(data["password_hash"]).hex_decode().size() != 32:
			problem = "%s has a password_hash without a usable password_salt. Put the password back as \"password\" (it is hashed again at start) and start again." % path
			return

		salt = kept_salt
		password_hash = str(data["password_hash"]).hex_decode()

	if OS.get_environment(ENV_PASSWORD) != "":
		salt = kept_salt
		password_hash = ServerAuth.hash_password(salt, OS.get_environment(ENV_PASSWORD))
		note += "password from %s. " % ENV_PASSWORD

		if str(data.get("password_salt", "")) != salt.hex_encode():
			data["password_salt"] = salt.hex_encode()
			note += _write(path, data)

	note += "password: %s" % ("on" if not password_hash.is_empty() else "off")


func locked() -> bool:
	return not password_hash.is_empty()


# Writes beside the file and renames over it, so a stop mid-write never leaves half a file. Returns "" or a note for the log.
func _write(path: String, data: Dictionary) -> String:
	var temp: String = path + ".new"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)

	if file == null:
		return "could not rewrite server.json (%s). " % error_string(FileAccess.get_open_error())

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var error: int = DirAccess.rename_absolute(temp, path)
	return "" if error == OK else "could not rewrite server.json (%s). " % error_string(error)
