extends RefCounted

# What a server tells players before they join, and its password (docs/design/SERVER_PICK_PAGE.md). Set by whoever runs it in the store's
# server.json; every key is optional and a missing file is an open server with no name, as before:
#   {"name": "Hannibal's House", "message": "Bring an axe, the north woods are full.", "password": "typed here once"}
# A plain "password" is replaced at start by "password_salt" and "password_hash" (SHA256(salt + password)) and the file rewritten, so the
# password itself stays on disk only until the server first starts. Docker: the environment variable DYNASTY_SERVER_PASSWORD sets it
# instead (hashed in memory only, never written) and wins over the file; empty or unset leaves the file's setting. deploy/server/SERVER.md.

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


func load_from(store_dir: String) -> void:
	var path: String = store_dir.path_join(FILE)
	var data: Dictionary = {}

	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

		if parsed is Dictionary:
			data = parsed
		else:
			note = "server.json is not readable JSON: ignored (open server, no name). "

	server_name = str(data.get("name", "")).strip_edges().left(NAME_MAX)
	message = str(data.get("message", "")).strip_edges().left(MESSAGE_MAX)

	if str(data.get("password", "")) != "":
		salt = Crypto.new().generate_random_bytes(16)
		password_hash = ServerAuth.hash_password(salt, str(data["password"]))
		data.erase("password")
		data["password_salt"] = salt.hex_encode()
		data["password_hash"] = password_hash.hex_encode()
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

		if file != null:
			file.store_string(JSON.stringify(data, "\t"))
			file.close()
			note += "the password in server.json is now stored hashed. "
		else:
			note += "could not rewrite server.json: the password stays there in plain text until it can be. "
	elif str(data.get("password_hash", "")) != "" and str(data.get("password_salt", "")) != "":
		salt = str(data["password_salt"]).hex_decode()
		password_hash = str(data["password_hash"]).hex_decode()

	if OS.get_environment(ENV_PASSWORD) != "":
		salt = Crypto.new().generate_random_bytes(16)
		password_hash = ServerAuth.hash_password(salt, OS.get_environment(ENV_PASSWORD))
		note += "password from %s. " % ENV_PASSWORD

	note += "password: %s" % ("on" if not password_hash.is_empty() else "off")


func locked() -> bool:
	return not password_hash.is_empty()
