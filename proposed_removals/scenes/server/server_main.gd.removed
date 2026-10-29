extends Node


const ServerWorldRegionsScript := preload(
	"res://src/server/server_world_regions.gd"
)

var server_peer: ENetMultiplayerPeer
var world_regions = null

@onready var network_bridge: NetworkBridge = $NetworkBridge


func _ready() -> void:
	print("")
	network_bridge.region_manifest_requested.connect(
		_on_region_manifest_requested
	)
	print("======================================")
	print(AppConfig.GAME_NAME)
	print("DEDICATED SERVER")
	print("======================================")
	print("Protocol version: ", AppConfig.PROTOCOL_VERSION)
	print("World format:     ", AppConfig.WORLD_FORMAT_VERSION)
	print("Port:             ", AppConfig.DEFAULT_SERVER_PORT)
	print("======================================")
	print("")

	if not _initialize_world_regions():
		push_error("Server startup stopped because the world is incomplete.")
		return

	_start_server()


func _initialize_world_regions() -> bool:
	var world_path: String = AppConfig.get_command_line_value(
		"world",
		AppConfig.DEFAULT_WORLD_PATH
	)
	world_regions = ServerWorldRegionsScript.new()
	return world_regions.initialize(world_path)


func _start_server() -> void:
	server_peer = ENetMultiplayerPeer.new()

	var error := server_peer.create_server(
		AppConfig.DEFAULT_SERVER_PORT,
		AppConfig.DEFAULT_MAX_CLIENTS
	)

	if error != OK:
		push_error(
			"Unable to start server on port %d. Error: %s"
			% [
				AppConfig.DEFAULT_SERVER_PORT,
				error_string(error)
			]
		)
		return

	multiplayer.multiplayer_peer = server_peer

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print(
		"Server listening on port ",
		AppConfig.DEFAULT_SERVER_PORT
	)


func _on_peer_connected(peer_id: int) -> void:
	print("Client connected: ", peer_id)

	network_bridge.server_welcome.rpc_id(
		peer_id,
		AppConfig.PROTOCOL_VERSION,
		AppConfig.WORLD_FORMAT_VERSION,
		world_regions.get_minimum_region(),
		world_regions.get_maximum_region(),
		world_regions.get_generator_version(),
		world_regions.get_world_identity_seed()
	)


func _on_peer_disconnected(peer_id: int) -> void:
	print("Client disconnected: ", peer_id)


func _on_region_manifest_requested(
	peer_id: int,
	current_logical_region: Vector2i,
	radius: int
) -> void:
	if world_regions == null or not world_regions.is_ready():
		return

	var entries: Array[Dictionary] = world_regions.get_manifest(
		current_logical_region,
		radius
	)
	network_bridge.server_region_manifest.rpc_id(peer_id, entries)
