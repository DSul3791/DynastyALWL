extends RefCounted

# Connection timeouts (data/network.json), shared by the server and the client.

const PATH := "res://data/network.json"


static func value(key: String, fallback: int) -> int:
	if not FileAccess.file_exists(PATH):
		return fallback

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))

	if typeof(parsed) == TYPE_DICTIONARY and parsed.has(key):
		return int(parsed[key])

	return fallback


# Gives one ENet peer the long timeouts.
static func apply(enet_peer: ENetPacketPeer) -> void:
	if enet_peer != null:
		enet_peer.set_timeout(value("peer_timeout_limit_ms", 64), value("peer_timeout_min_ms", 60000), value("peer_timeout_max_ms", 120000))
