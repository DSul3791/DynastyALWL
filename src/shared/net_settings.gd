extends RefCounted

# Connection timeouts and ENet's packet throttle (data/network.json), shared by the server and the client.

const PATH := "res://data/network.json"


static func value(key: String, fallback: int) -> int:
	if not FileAccess.file_exists(PATH):
		return fallback

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))

	if typeof(parsed) == TYPE_DICTIONARY and parsed.has(key):
		return int(parsed[key])

	return fallback


# Gives one ENet peer the long timeouts, and a packet throttle that never drops unreliable packets on purpose (network.json
# _note_packet_throttle: it dropped animal rows and positions over the internet). ENet tells the other end too.
static func apply(enet_peer: ENetPacketPeer) -> void:
	if enet_peer != null:
		enet_peer.set_timeout(value("peer_timeout_limit_ms", 64), value("peer_timeout_min_ms", 60000), value("peer_timeout_max_ms", 120000))
		enet_peer.throttle_configure(value("packet_throttle_interval_ms", 5000), value("packet_throttle_acceleration", 2), value("packet_throttle_deceleration", 0))
