extends Node


const LocalRegionProviderScript = preload(
	"res://src/client/local_region_provider.gd"
)

const LocalBakedBlockStoreScript = preload(
	"res://src/client/local_baked_block_store.gd"
)

const ClientWorldScript = preload(
	"res://src/client/client_world.gd"
)


@onready var network_bridge: NetworkBridge = $NetworkBridge


var client_peer: ENetMultiplayerPeer

var region_provider = null
var block_store = null
var client_world = null


func _ready() -> void:
	print("")
	print("======================================")
	print(AppConfig.GAME_NAME)
	print("CLIENT")
	print("======================================")
	print("Protocol version: ", AppConfig.PROTOCOL_VERSION)
	print("World format:     ", AppConfig.WORLD_FORMAT_VERSION)
	print("======================================")
	print("")

	multiplayer.connected_to_server.connect(
		_on_connected_to_server
	)

	multiplayer.connection_failed.connect(
		_on_connection_failed
	)

	multiplayer.server_disconnected.connect(
		_on_server_disconnected
	)


	if not _initialize_local_world():
		return


	_connect_to_server()


# ==================================================
# LOCAL WORLD
# ==================================================

func _initialize_local_world() -> bool:
	print(
		"Initializing local region provider..."
	)


	region_provider = (
		LocalRegionProviderScript.new()
	)


	if not region_provider.initialize(
		AppConfig.DEFAULT_WORLD_PATH
	):
		push_error(
			"Client could not initialize LocalRegionProvider."
		)

		return false


	block_store = (
		LocalBakedBlockStoreScript.new()
	)


	if not block_store.initialize(
		region_provider
	):
		push_error(
			"Client could not initialize LocalBakedBlockStore."
		)

		return false


	print(
		"Local baked world access initialized."
	)


	# --------------------------------------------------
	# CREATE THE ACTUAL CLIENT WORLD
	# --------------------------------------------------

	client_world = (
		ClientWorldScript.new()
	)

	client_world.name = "ClientWorld"

	add_child(
		client_world
	)


	if not client_world.initialize(
		block_store
	):
		push_error(
			"Client could not initialize ClientWorld."
		)

		client_world.queue_free()
		client_world = null

		return false


	print(
		"Client world initialized."
	)


	return true


# ==================================================
# NETWORK
# ==================================================

func _connect_to_server() -> void:
	print(
		"Connecting to ",
		AppConfig.DEFAULT_SERVER_ADDRESS,
		":",
		AppConfig.DEFAULT_SERVER_PORT,
		"..."
	)


	client_peer = ENetMultiplayerPeer.new()


	var error := client_peer.create_client(
		AppConfig.DEFAULT_SERVER_ADDRESS,
		AppConfig.DEFAULT_SERVER_PORT
	)


	if error != OK:
		push_error(
			"Unable to create client connection. Error: %s"
			% error_string(error)
		)

		return


	multiplayer.multiplayer_peer = client_peer


func _on_connected_to_server() -> void:
	print(
		"Connected to server."
	)


	network_bridge.client_hello.rpc_id(
		1,
		AppConfig.PROTOCOL_VERSION
	)

	network_bridge.request_region_manifest.rpc_id(
		1,
		Vector2i.ZERO,
		2
	)


func _on_connection_failed() -> void:
	push_error(
		"Connection to server failed."
	)


func _on_server_disconnected() -> void:
	print(
		"Server disconnected."
	)


	multiplayer.multiplayer_peer = null


# ==================================================
# SHUTDOWN
# ==================================================

func _exit_tree() -> void:
	if block_store != null:
		block_store.close()
