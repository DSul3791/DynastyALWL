extends SceneTree

# Server passwords and the status reply (docs/design/SERVER_PICK_PAGE.md): server_auth.gd's join handshake between a real ENet server and client
# in this one process (open server, right password, three wrong tries, the guard), server_settings.gd turning a typed password into a salted
# hash (and DYNASTY_SERVER_PASSWORD), and the block line's STATUS answer. No game world is loaded; ports 7700-7899.
#   godot --headless --path . --script res://src/worldgen/tools/test_server_auth.gd

const ServerAuth := preload("res://src/shared/server_auth.gd")
const ServerSettings := preload("res://src/stream/server_settings.gd")
const BlockLinkServer := preload("res://src/stream/block_link_server.gd")

var failures: int = 0
var port: int = 7700 + randi() % 150


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# One join: a server (open when password is "") and a client that answers each ask from `answers` in turn. Returns what happened.
func join(password: String, answers: Array, server_auth = null) -> Dictionary:
	port += 1
	var server_mp: SceneMultiplayer = SceneMultiplayer.new()
	var client_mp: SceneMultiplayer = SceneMultiplayer.new()
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var result: Dictionary = {"connected": false, "asked": [], "refused": "", "accepted": ""}

	if server_auth == null:
		server_auth = ServerAuth.new()

	if password != "" and server_auth.password_hash.is_empty():
		server_auth.salt = Crypto.new().generate_random_bytes(16)
		server_auth.password_hash = ServerAuth.hash_password(server_auth.salt, password)

	server_auth.address_of = func(_peer: int) -> String: return "127.0.0.1"
	var client_auth = ServerAuth.new()
	client_auth.password_needed.connect(func(left: int, wrong: bool) -> void:
		result["asked"].append([left, wrong])
		var index: int = result["asked"].size() - 1

		if index < answers.size():
			client_auth.submit(str(answers[index])))
	client_auth.refused.connect(func(reason: String) -> void: result["refused"] = reason)
	client_auth.accepted.connect(func(_salt: String, hash_hex: String) -> void: result["accepted"] = hash_hex)
	server_auth.attach_server(server_mp)
	client_auth.attach_client(client_mp)
	server_mp.peer_connected.connect(func(_peer: int) -> void: result["connected"] = true)
	server_peer.create_server(port, 4)
	server_mp.multiplayer_peer = server_peer
	client_peer.create_client("127.0.0.1", port)
	client_mp.multiplayer_peer = client_peer

	for i in 300:   # up to about 5 s
		server_mp.poll()
		client_mp.poll()
		await process_frame

		if result["connected"] or result["refused"] != "" or (result["asked"].size() > answers.size()):
			break

	for i in 90:    # let a drop arrive
		server_mp.poll()
		client_mp.poll()
		await process_frame

	client_peer.close()
	server_peer.close()
	return result


func _initialize() -> void:
	var salt: PackedByteArray = "00112233445566778899aabbccddeeff".hex_decode()
	var key: PackedByteArray = ServerAuth.hash_password(salt, "Hannibal")
	check(key.size() == 32 and key == ServerAuth.hash_password(salt, "Hannibal"), "the hash is SHA-256 and the same each time")
	check(key != ServerAuth.hash_password(salt, "hannibal"), "case matters (Caps Lock)")
	check(ServerAuth.proof_of(key, "01".hex_decode()) != ServerAuth.proof_of(key, "02".hex_decode()), "a new one-time number gives a new proof")

	var open: Dictionary = await join("", [])
	check(open["connected"] and open["asked"].is_empty(), "an open server lets the client in without asking")
	var right: Dictionary = await join("Hannibal", ["Hannibal"])
	check(right["connected"] and right["asked"] == [[3, false]], "a password server asks once, and the right password gets in")
	check(right["accepted"] != "", "the accepted password's hash is handed back to remember")
	var second: Dictionary = await join("Hannibal", ["hannibal", "Hannibal"])
	check(second["connected"] and second["asked"] == [[3, false], [2, true]], "a wrong try says so with 2 left, then the right one gets in")
	var guard = ServerAuth.new()
	var three: Dictionary = await join("Hannibal", ["a", "b", "c"], guard)
	check(not three["connected"] and three["refused"] == "wrong" and three["asked"].size() == 3, "three wrong tries: refused, the client is told")
	var fourth: Dictionary = await join("", ["d", "e", "f"], guard)
	check(not fourth["connected"] and fourth["refused"] == "busy", "five wrong from one address in a minute: the next join is refused at once")

	var dir: String = OS.get_cache_dir().path_join("dynasty_test_auth_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dir)
	var file: FileAccess = FileAccess.open(dir.path_join("server.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"name": "Hannibal's House", "message": "Bring an axe.", "password": "Hannibal"}))
	file.close()
	OS.unset_environment(ServerSettings.ENV_PASSWORD)
	var settings = ServerSettings.new()
	settings.load_from(dir)
	var written: String = FileAccess.get_file_as_string(dir.path_join("server.json"))
	check(settings.server_name == "Hannibal's House" and settings.message == "Bring an axe.", "the name and message are read")
	check(settings.locked() and not written.contains("\"Hannibal\"") and written.contains("password_hash"), "a typed password is replaced on disk by its salted hash")
	check(settings.password_hash == ServerAuth.hash_password(settings.salt, "Hannibal"), "the stored hash checks the same password")
	var again = ServerSettings.new()
	again.load_from(dir)
	check(again.password_hash == settings.password_hash and again.salt == settings.salt, "the next start reads the hash back")
	OS.set_environment(ServerSettings.ENV_PASSWORD, "FromDocker")
	var docker = ServerSettings.new()
	docker.load_from(dir)
	check(docker.password_hash == ServerAuth.hash_password(docker.salt, "FromDocker"), "DYNASTY_SERVER_PASSWORD wins over the file")
	OS.unset_environment(ServerSettings.ENV_PASSWORD)
	DirAccess.remove_absolute(dir.path_join("server.json"))
	var none = ServerSettings.new()
	none.load_from(dir)
	check(not none.locked() and none.server_name == "", "no server.json: an open server with no name, as before")
	DirAccess.remove_absolute(dir)

	var link = BlockLinkServer.new()
	link.is_peer = func(_peer: int) -> bool: return false
	link.on_request = func(_peer: int, _keys: PackedInt32Array, _urgent: int) -> void: pass
	port += 1
	check(link.start(port) == port, "the block line listens")
	link.set_status({"name": "Hannibal's House", "players": 2, "max_players": 32, "locked": true})
	var tcp: StreamPeerTCP = StreamPeerTCP.new()
	tcp.connect_to_host("127.0.0.1", port)
	var reply: PackedByteArray = PackedByteArray()
	var asked: bool = false

	for i in 300:
		tcp.poll()

		if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			if not asked:
				var frame: PackedByteArray = PackedByteArray()
				frame.resize(8)
				frame.encode_u32(0, 4)
				frame.encode_u32(4, BlockLinkServer.KIND_STATUS)
				tcp.put_data(frame)
				asked = true

			if tcp.get_available_bytes() > 0:
				reply.append_array(tcp.get_data(tcp.get_available_bytes())[1])

		if reply.size() >= 8 and reply.size() >= 4 + int(reply.decode_u32(0)):
			break

		await process_frame

	var status: Variant = JSON.parse_string(reply.slice(8).get_string_from_utf8()) if reply.size() > 8 else null
	check(reply.size() > 8 and reply.decode_u32(4) == BlockLinkServer.KIND_STATUS, "a STATUS ask gets a status frame back")
	check(status is Dictionary and str(status.get("name")) == "Hannibal's House" and int(status.get("players")) == 2 and bool(status.get("locked")), "the status names the server, its players and its padlock")
	tcp.disconnect_from_host()
	link.stop()

	print("server auth: %d failures" % failures)
	quit(1 if failures > 0 else 0)
