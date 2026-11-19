extends RefCounted

# Server passwords (Dave 19 Nov 2026: "servers need the ability to also have a password ... you get 3 tries"; docs/design/SERVER_PICK_PAGE.md
# "Server passwords"). Runs in Godot's join handshake (SceneMultiplayer auth), before the server counts the player as connected: until it passes
# the client gets no welcome, no ground and nothing else, and no RPC of its own is heard.
#
#   server -> client  {"t": "ok"}                                   open server, or the proof was right: both sides complete the handshake
#   server -> client  {"t": "challenge", "salt", "nonce"}           this server has a password
#   client -> server  {"t": "proof", "proof"}                       HMAC-SHA256(key = SHA256(salt + password), nonce), all hex
#   server -> client  {"t": "wrong", "left", "nonce"}               wrong; "left" tries remain on this connection (0: the server drops it)
#   server -> client  {"t": "busy"}                                 too many wrong tries from this address lately: wait a minute
#
# The password never crosses the network and the server keeps only SHA256(salt + password) (server_settings.gd). A fresh one-time number every
# try means a copied proof is useless. Every client (game, bot) must attach: a server with this handshake waits for it.

const TRIES := 3                    # per connection (Dave: "you get 3 tries")
const GUARD_WRONG := 5              # wrong proofs from one address within GUARD_MSEC refuse that address for GUARD_MSEC
const GUARD_MSEC := 60000
const TIMEOUT_S := 180.0            # time to type a password; the engine's default (3 s) would drop a player mid-word

# Server side
var password_hash: PackedByteArray = PackedByteArray()    # empty: an open server
var salt: PackedByteArray = PackedByteArray()
var address_of: Callable            # (peer id) -> its IP, for the guard
var log_event: Callable             # (text) -> void, optional
var _nonces: Dictionary = {}        # peer id -> PackedByteArray
var _wrong: Dictionary = {}         # peer id -> wrong tries on this connection
var _fails: Dictionary = {}         # IP -> [msec of each wrong try]

# Client side
signal password_needed(tries_left: int, wrong: bool)   # ask the player, then call submit(); tries_left counts this one
signal refused(reason: String)                         # "wrong" (three wrong), "busy" (the guard): the server drops the connection next
signal accepted(salt_hex: String, hash_hex: String)    # a typed or remembered password passed: remember it if the player wants
var remembered: Callable            # (salt hex) -> remembered hash hex for this server, or ""
var _client_salt: PackedByteArray = PackedByteArray()
var _client_nonce: PackedByteArray = PackedByteArray()
var _trying_hash: PackedByteArray = PackedByteArray()
var _tried_remembered: bool = false
var remembered_was_wrong: bool = false   # the last wrong try was the remembered password (the server's password changed since): forget it

var _mp: SceneMultiplayer


func locked() -> bool:
	return not password_hash.is_empty()


static func hash_password(salt_bytes: PackedByteArray, password: String) -> PackedByteArray:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(salt_bytes)
	context.update(password.to_utf8_buffer())
	return context.finish()


static func proof_of(key: PackedByteArray, nonce: PackedByteArray) -> PackedByteArray:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, key, nonce)


# ---- server ----

func attach_server(mp: SceneMultiplayer) -> void:
	_mp = mp
	mp.auth_timeout = TIMEOUT_S
	mp.auth_callback = _server_got
	mp.peer_authenticating.connect(_server_start)
	mp.peer_authentication_failed.connect(func(peer: int): _forget(peer))
	mp.peer_connected.connect(func(peer: int): _forget(peer))


func _server_start(peer: int) -> void:
	if not locked():
		_send(peer, {"t": "ok"})
		_mp.complete_auth(peer)
		return

	if _guarded(_address(peer)):
		_drop(peer, {"t": "busy"}, "refused at once: too many wrong passwords from %s" % _address(peer))
		return

	_nonces[peer] = Crypto.new().generate_random_bytes(16)
	_wrong[peer] = 0
	_send(peer, {"t": "challenge", "salt": salt.hex_encode(), "nonce": (_nonces[peer] as PackedByteArray).hex_encode()})


func _server_got(peer: int, data: PackedByteArray) -> void:
	var message: Variant = JSON.parse_string(data.get_string_from_utf8())

	if not locked() or not _nonces.has(peer) or not message is Dictionary or str(message.get("t", "")) != "proof":
		return

	var expected: PackedByteArray = proof_of(password_hash, _nonces[peer])

	if str(message.get("proof", "")).to_lower() == expected.hex_encode():
		_nonces.erase(peer)
		_send(peer, {"t": "ok"})
		_mp.complete_auth(peer)
		return

	var ip: String = _address(peer)
	_wrong[peer] = int(_wrong.get(peer, 0)) + 1
	_fails[ip] = (_fails.get(ip, []) as Array) + [Time.get_ticks_msec()]
	var left: int = TRIES - int(_wrong[peer])

	if left <= 0 or _guarded(ip):
		_drop(peer, {"t": "wrong", "left": 0} if left <= 0 else {"t": "busy"}, "wrong password %d times from %s" % [int(_wrong[peer]), ip])
		return

	_nonces[peer] = Crypto.new().generate_random_bytes(16)
	_send(peer, {"t": "wrong", "left": left, "nonce": (_nonces[peer] as PackedByteArray).hex_encode()})


func _guarded(ip: String) -> bool:
	var now: int = Time.get_ticks_msec()
	var recent: Array = (_fails.get(ip, []) as Array).filter(func(at: int) -> bool: return now - at < GUARD_MSEC)

	if recent.is_empty():
		_fails.erase(ip)
	else:
		_fails[ip] = recent

	return recent.size() >= GUARD_WRONG


# Tells the client why, then drops it a moment later so the reason arrives first.
func _drop(peer: int, message: Dictionary, why: String) -> void:
	_send(peer, message)
	_forget(peer)

	if log_event.is_valid():
		log_event.call("peer %d %s" % [peer, why])

	var tree: SceneTree = Engine.get_main_loop() as SceneTree

	if tree != null:
		tree.create_timer(1.0).timeout.connect(func() -> void:
			if _mp.multiplayer_peer != null:
				_mp.disconnect_peer(peer))


func _forget(peer: int) -> void:
	_nonces.erase(peer)
	_wrong.erase(peer)


func _address(peer: int) -> String:
	return str(address_of.call(peer)) if address_of.is_valid() else "?"


# ---- client ----

func attach_client(mp: SceneMultiplayer) -> void:
	_mp = mp
	mp.auth_timeout = TIMEOUT_S
	mp.auth_callback = _client_got


func _client_got(_peer: int, data: PackedByteArray) -> void:
	var message: Variant = JSON.parse_string(data.get_string_from_utf8())

	if not message is Dictionary:
		return

	match str(message.get("t", "")):
		"ok":
			if not _trying_hash.is_empty():
				accepted.emit(_client_salt.hex_encode(), _trying_hash.hex_encode())

			_mp.complete_auth(1)
		"challenge":
			_client_salt = str(message.get("salt", "")).hex_decode()
			_client_nonce = str(message.get("nonce", "")).hex_decode()
			var saved: String = str(remembered.call(_client_salt.hex_encode())) if remembered.is_valid() else ""

			if saved != "":
				_tried_remembered = true
				_send_proof(saved.hex_decode())
			else:
				password_needed.emit(TRIES, false)
		"wrong":
			var left: int = int(message.get("left", 0))
			remembered_was_wrong = _tried_remembered
			_tried_remembered = false

			if left <= 0:
				refused.emit("wrong")
				return

			_client_nonce = str(message.get("nonce", "")).hex_decode()
			password_needed.emit(left, true)
		"busy":
			refused.emit("busy")


# The player's typed password for the challenge now open.
func submit(password: String) -> void:
	_send_proof(hash_password(_client_salt, password))


func _send_proof(key: PackedByteArray) -> void:
	_trying_hash = key
	_send(1, {"t": "proof", "proof": proof_of(key, _client_nonce).hex_encode()})


func _send(peer: int, message: Dictionary) -> void:
	_mp.send_auth(peer, JSON.stringify(message).to_utf8_buffer())
