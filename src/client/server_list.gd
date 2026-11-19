extends RefCounted

# The servers this player has added on the server pick page (docs/design/SERVER_PICK_PAGE.md; Dave 19 Nov 2026: "every direct connect should be saved
# in a list for quick picking next time", IPs or names "like hannibalshouse.duckdns.org"). Kept on this computer in user://servers.json. A server is
# stored by the address as typed (a name stays a name and is looked up fresh every time, so a home server whose IP changes keeps working), never by
# the IP it pointed to. The same server typed twice (any case, with or without the standard port, pasted with http://) is one row.
# The official server is not in this file: it comes from the release setting, client_config.json "official" (official()).
# No UI here: the page and the status check use it.

const JoinAddress := preload("res://src/client/join_address.gd")
const SAVED := "user://servers.json"

static var saved_path: String = SAVED      # tests point it elsewhere so they never touch a player's own list


# Text as typed or pasted -> {"host", "port", "key", "address"}, or {"error": plain words}. "address" is what the list shows and stores
# (":port" only when it is not the standard one); "key" is the same server whatever the case or spelling of the port.
static func normalise(text: String) -> Dictionary:
	var address: String = text.strip_edges()

	for prefix in ["http://", "https://"]:
		if address.to_lower().begins_with(prefix):
			address = address.substr(prefix.length())

	if address.contains("/"):
		address = address.left(address.find("/"))   # a path pasted from a browser ("host/play") is not part of the address

	var parsed: Dictionary = JoinAddress.parse(address)

	if parsed.has("error"):
		return parsed

	var host: String = str(parsed["host"]).to_lower().trim_suffix(".")
	var port: int = int(parsed["port"])
	var shown: String = host if port == JoinAddress.DEFAULT_PORT else "%s:%d" % [host, port]
	return {"host": host, "port": port, "key": shown, "address": shown}


# Every saved server, as stored: [{address, name, server_name, added, last_played, last_answered, last_build, last_character}].
# On the first run with no list, the one address the older join page remembered (join_address.cfg) becomes the first row.
static func load_rows() -> Array:
	if not FileAccess.file_exists(saved_path):
		return _from_old_join_address()

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(saved_path))
	var rows: Array = []

	if parsed is Dictionary and parsed.get("servers") is Array:
		for one in parsed["servers"]:
			if one is Dictionary and not normalise(str(one.get("address", ""))).has("error"):
				rows.append(one)

	return rows


static func save_rows(rows: Array) -> bool:
	var file: FileAccess = FileAccess.open(saved_path, FileAccess.WRITE)

	if file == null:
		return false

	file.store_string(JSON.stringify({"version": 1, "servers": rows}, "\t"))
	file.close()
	return true


# Adds a server (or finds the one already there, giving it the new name if one is typed). Returns {"rows", "index"} or {"error"}; nothing is
# saved on an error. The caller saves.
static func add(rows: Array, text: String, name: String = "") -> Dictionary:
	var parsed: Dictionary = normalise(text)

	if parsed.has("error"):
		return parsed

	var index: int = find(rows, parsed["key"])

	if index < 0:
		rows.append({"address": parsed["address"], "name": name.strip_edges(), "server_name": "", "added": int(Time.get_unix_time_from_system()),
				"last_played": 0, "last_answered": 0, "last_build": 0, "last_character": ""})
		index = rows.size() - 1
	elif name.strip_edges() != "":
		rows[index]["name"] = name.strip_edges()

	return {"rows": rows, "index": index}


# The row for this server (any spelling of it), or -1.
static func find(rows: Array, address: String) -> int:
	var parsed: Dictionary = normalise(address)

	if parsed.has("error"):
		return -1

	for i in rows.size():
		if normalise(str(rows[i].get("address", ""))).get("key", "") == parsed["key"]:
			return i

	return -1


static func remove(rows: Array, address: String) -> Array:
	var index: int = find(rows, address)

	if index >= 0:
		rows.remove_at(index)

	return rows


# The name shown on this computer only; empty goes back to the server's own name.
static func rename(rows: Array, address: String, name: String) -> Array:
	var index: int = find(rows, address)

	if index >= 0:
		rows[index]["name"] = name.strip_edges()

	return rows


# After a join: when, and as which character, so Continue and the character page can line it up next time.
static func mark_played(rows: Array, address: String, character_id: String) -> Array:
	var index: int = find(rows, address)

	if index >= 0:
		rows[index]["last_played"] = int(Time.get_unix_time_from_system())
		rows[index]["last_character"] = character_id

	return rows


# Last played first; never played after those, newest added first.
static func sorted(rows: Array) -> Array:
	var out: Array = rows.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _newer_first(a, b))
	return out


static func _newer_first(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("last_played", 0)) != int(b.get("last_played", 0)):
		return int(a.get("last_played", 0)) > int(b.get("last_played", 0))

	return int(a.get("added", 0)) > int(b.get("added", 0))


# The name a row shows: the player's own, else the one the server reported, else the address.
static func shown_name(row: Dictionary) -> String:
	for field in ["name", "server_name", "address"]:
		if str(row.get(field, "")) != "":
			return str(row[field])

	return ""


# The official server's address from the release setting (client_config.json "official", beside the game or inside it), or "" when this build has none.
static func official() -> String:
	for path in [OS.get_executable_path().get_base_dir().path_join(JoinAddress.CONFIG_NAME), "res://" + JoinAddress.CONFIG_NAME]:
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

			if parsed is Dictionary and str(parsed.get("official", "")) != "":
				return str(parsed["official"])

	return ""


# Starts looking up a server's name in the background (never freezes the page). Returns a lookup to pass to lookup_result, or -1 when the host is
# already an IP (use it as it is). A name such as a dynamic-DNS one is looked up every time, never kept.
static func lookup_start(host: String) -> int:
	if host.is_valid_ip_address():
		return -1

	return IP.resolve_hostname_queue_item(host, IP.TYPE_IPV4)


# {"state": "waiting" | "found" | "not_found", "ip"}. The lookup is cleared once it has an answer.
static func lookup_result(host: String, lookup: int) -> Dictionary:
	if lookup < 0:
		return {"state": "found", "ip": host}

	var status: int = IP.get_resolve_item_status(lookup)

	if status == IP.RESOLVER_STATUS_WAITING:
		return {"state": "waiting", "ip": ""}

	if status == IP.RESOLVER_STATUS_DONE:
		var ip: String = IP.get_resolve_item_address(lookup)
		IP.erase_resolve_item(lookup)
		return {"state": "found", "ip": ip} if ip != "" else {"state": "not_found", "ip": ""}

	IP.erase_resolve_item(lookup)
	return {"state": "not_found", "ip": ""}


static func _from_old_join_address() -> Array:
	var old: ConfigFile = ConfigFile.new()

	if old.load(JoinAddress.saved_path) != OK:
		return []

	var result: Dictionary = add([], str(old.get_value("join", "address", "")))
	return result.get("rows", [])
