class_name NetworkBridge
extends Node


signal server_welcome_received(
	protocol_version: int,
	world_format_version: int,
	minimum_region: Vector2i,
	maximum_region: Vector2i,
	generator_version: int,
	world_identity_seed: int
)

signal region_manifest_requested(
	peer_id: int,
	current_logical_region: Vector2i,
	radius: int
)

signal region_manifest_received(entries: Array)


@rpc("authority", "call_remote", "reliable")
func server_welcome(
	protocol_version: int,
	world_format_version: int,
	minimum_region: Vector2i,
	maximum_region: Vector2i,
	generator_version: int,
	world_identity_seed: int
) -> void:
	if multiplayer.is_server():
		return

	print(
		"Server welcome received. Protocol: ",
		protocol_version,
		" | World format: ", world_format_version,
		" | Regions: ", minimum_region, " -> ", maximum_region,
		" | Generator: ", generator_version,
		" | Seed: ", world_identity_seed
	)

	server_welcome_received.emit(
		protocol_version,
		world_format_version,
		minimum_region,
		maximum_region,
		generator_version,
		world_identity_seed
	)


@rpc("any_peer", "call_remote", "reliable")
func client_hello(protocol_version: int) -> void:
	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()

	print(
		"Client ",
		peer_id,
		" reports protocol version ",
		protocol_version
	)

	if protocol_version != AppConfig.PROTOCOL_VERSION:
		push_warning(
			"Client %d has incompatible protocol version %d"
			% [peer_id, protocol_version]
		)


@rpc("any_peer", "call_remote", "reliable")
func request_region_manifest(
	current_logical_region: Vector2i,
	radius: int = 1
) -> void:
	if not multiplayer.is_server():
		return

	region_manifest_requested.emit(
		multiplayer.get_remote_sender_id(),
		current_logical_region,
		clampi(radius, 0, 8)
	)


@rpc("authority", "call_remote", "reliable")
func server_region_manifest(entries: Array) -> void:
	if multiplayer.is_server():
		return

	region_manifest_received.emit(entries)
