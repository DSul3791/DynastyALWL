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
# Protocol 161 (23 Nov 2026: a build 9257 client on a newer server got every call on the wrong method and no word why): the client speaks first.
#   client -> server  {"t": "hi", "protocol"}                       its protocol, at once
#   server -> client  {"t": "old", "protocol", "text"}              another protocol: the reason to show, then the server drops it
# and the server's ok and challenge carry its "protocol". The server waits for the hi before anything else: a client from before 161 never
# sends one, hears nothing, and its own 15 s wait (FIRST_WORD_S) says the server runs another build. A client from 161 on that hears an ok
# or challenge with no protocol is on an older server, and says so.
#
# The password never crosses the network and the server keeps only SHA256(salt + password) (server_settings.gd). A fresh one-time number every
# try means a copied proof is useless. Every client (game, bot) must attach: a server with this handshake waits for it.

const TRIES := 3                    # per connection (Dave: "you get 3 tries")
const GUARD_WRONG := 5              # wrong proofs from one address within GUARD_MSEC refuse that address for GUARD_MSEC
const GUARD_MSEC := 60000
const TIMEOUT_S := 180.0            # time to type a password; the engine's default (3 s) would drop a player mid-word
const FIRST_WORD_S := 15.0          # a client waits this long for the server's first word: a server of another protocol never sends one

var protocol: int = 0               # this side's terrain_net.gd PROTOCOL_VERSION (0: the old handshake, for a test of it)
signal outdated(text: String)       # client: this game and the server speak different protocols; the connection closes next

# Server side
var password_hash: PackedByteArray = PackedByteArray()    # empty: an open server
var salt: PackedByteArray = PackedByteArray()
var address_of: Callable            # (peer id) -> its IP, for the guard
var log_event: Callable             # (text) -> void, optional
var _nonces: Dictionary = {}        # peer id -> PackedByteArray
var _wrong: Dictionary = {}         # peer id -> wrong tries on this connection
var _fails: Dictionary = {}         # IP -> [msec of each wrong try]
var _hi: Dictionary = {}            # peer id -> true once its hi came (161)

# Client side
signal password_needed(tries_left: int, wrong: bool)   # ask the player, then call submit(); tries_left counts this one
signal refused(reason: String)                         # "wrong" (three wrong), "busy" (the guard): the server drops the connection next
signal accepted(salt_hex: String, hash_hex: String)    # a typed or remembered password passed: remember it if the player wants
var remembered: Callable            # (salt hex) -> remembered hash hex for this server, or ""
var _client_salt: PackedByteArray = PackedByteArray()
var _client_nonce: PackedByteArray = PackedByteArray()
var _trying_hash: PackedByteArray = PackedByteArray()
var _tried_remembered: bool = false
var heard: bool = false             # the server has said anything in the handshake (false at a failure: it does not speak this join)
var remembered_was_wrong: bool = false   # the last wrong try was the remembered password (the server's password changed since): forget it
var session_address: String = ""    # "host:port" of the server being joined: a password typed for it is reused on every new connection (below)

# Dave 25 Nov 2026 (R-JOIN-PASSWORD-ONCE): "it should save the password temporarily until it makes the connection. even if it has to try
# multiple times. it should only ever ask once". Once the player types a password, its key (SHA256(salt + password), as for Remember) is
# kept in memory for this run of the game, per server, and answers that server's next challenge by itself: a dropped join and Retry
# (the scene reloads), the --wait retry or a re-join never bring the box back. Only a "wrong" from the server clears it, and then the box
# asks. Held on Engine metadata so it outlives the scene; never on disk (Remember still decides that), never in a log or crash report.
const SESSION_META := "join_keys_this_session"

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
	if protocol > 0:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree

		if tree != null:   # a connection that never says hi (a client from before 161 closes itself at FIRST_WORD_S; a scanner would not) keeps no slot
			tree.create_timer(FIRST_WORD_S + 5.0).timeout.connect(func() -> void:
				if not _hi.has(peer) and _mp.multiplayer_peer != null and _mp.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and _mp.get_authenticating_peers().has(peer):
					_mp.disconnect_peer(peer))

		return   # waits for the client's hi (_server_got)

	_begin(peer)


func _begin(peer: int) -> void:
	if not locked():
		_send(peer, _stamped({"t": "ok"}))
		_mp.complete_auth(peer)
		return

	if _guarded(_address(peer)):
		_drop(peer, {"t": "busy"}, "refused at once: too many wrong passwords from %s" % _address(peer))
		return

	_nonces[peer] = Crypto.new().generate_random_bytes(16)
	_wrong[peer] = 0
	_send(peer, _stamped({"t": "challenge", "salt": salt.hex_encode(), "nonce": (_nonces[peer] as PackedByteArray).hex_encode()}))


func _server_got(peer: int, data: PackedByteArray) -> void:
	var message: Variant = JSON.parse_string(data.get_string_from_utf8())

	if protocol > 0 and message is Dictionary and str(message.get("t", "")) == "hi":
		if _hi.has(peer):
			return   # one hi a connection

		_hi[peer] = true
		var theirs: int = str(message.get("protocol", 0)).to_int()   # untrusted: a wrong type is not a number, not a script error

		if theirs != protocol:
			_drop(peer, {"t": "old", "protocol": protocol, "text": outdated_text(theirs, protocol)}, "refused: client protocol %d, this server %d" % [theirs, protocol])
			return

		_begin(peer)
		return

	if protocol > 0 and not _hi.has(peer):
		return   # nothing counts before the hi

	if not locked() or not _nonces.has(peer) or not message is Dictionary or str(message.get("t", "")) != "proof":
		return

	var expected: PackedByteArray = proof_of(password_hash, _nonces[peer])

	if str(message.get("proof", "")).to_lower() == expected.hex_encode():
		_nonces.erase(peer)
		_send(peer, _stamped({"t": "ok"}))
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
	_nonces.erase(peer)   # its hi stays until the connection ends (_forget): no second hi, and no fresh tries, in the second before the drop
	_wrong.erase(peer)

	if log_event.is_valid():
		log_event.call("peer %d %s" % [peer, why])

	var tree: SceneTree = Engine.get_main_loop() as SceneTree

	if tree != null:
		tree.create_timer(1.0).timeout.connect(func() -> void:
			if _mp.multiplayer_peer != null and _mp.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				_mp.disconnect_peer(peer))


func _forget(peer: int) -> void:
	_nonces.erase(peer)
	_wrong.erase(peer)
	_hi.erase(peer)


func _stamped(message: Dictionary) -> Dictionary:
	if protocol > 0:
		message["protocol"] = protocol

	return message


# What a player whose game speaks `client` reads on a server that speaks `server` (both sides of the 161 handshake use it).
static func outdated_text(client: int, server: int) -> String:
	if client < server:
		return "This game is older than the server (game version %d, server version %d).\nInstall the new version of the game, then join again. Your character and world are kept on the server." % [client, server]

	return "This game is newer than the server (game version %d, server version %d).\nThe server has not been updated yet: try again once it has, or ask whoever runs it." % [client, server]


func _address(peer: int) -> String:
	return str(address_of.call(peer)) if address_of.is_valid() else "?"


# ---- client ----

func attach_client(mp: SceneMultiplayer) -> void:
	_mp = mp
	mp.auth_timeout = FIRST_WORD_S   # raised to TIMEOUT_S once the server speaks (a player may be typing)
	mp.auth_callback = _client_got

	if protocol > 0:
		mp.peer_authenticating.connect(func(peer: int) -> void:
			if peer == 1:
				_send(1, {"t": "hi", "protocol": protocol}))   # first, before the server says anything (161)


# A new connection (the game's --wait retry): the server has said nothing yet on it.
func new_connection() -> void:
	heard = false
	_tried_remembered = false
	remembered_was_wrong = false
	_trying_hash = PackedByteArray()

	if _mp != null:
		_mp.auth_timeout = FIRST_WORD_S


func _client_got(_peer: int, data: PackedByteArray) -> void:
	var message: Variant = JSON.parse_string(data.get_string_from_utf8())

	if not message is Dictionary:
		return

	heard = true
	_mp.auth_timeout = TIMEOUT_S
	var kind: String = str(message.get("t", ""))

	if kind == "old":
		outdated.emit(str(message.get("text", outdated_text(protocol, str(message.get("protocol", 0)).to_int()))))
		return

	var server_protocol: int = str(message.get("protocol", 0)).to_int()

	if protocol > 0 and (kind == "ok" or kind == "challenge") and server_protocol != protocol:
		outdated.emit(outdated_text(protocol, server_protocol) if server_protocol > 0 else "This game is newer than the server (game version %d; the server is from before version 161).\nThe server has not been updated yet: try again once it has, or ask whoever runs it." % protocol)
		return   # an older server: no further step, the handshake times out and the connection closes

	match kind:
		"ok":
			if not _trying_hash.is_empty():
				accepted.emit(_client_salt.hex_encode(), _trying_hash.hex_encode())

			_mp.complete_auth(1)
		"challenge":
			_client_salt = str(message.get("salt", "")).hex_decode()
			_client_nonce = str(message.get("nonce", "")).hex_decode()
			var saved: String = str(remembered.call(_client_salt.hex_encode())) if remembered.is_valid() else ""
			var typed_before: String = session_key(session_address, _client_salt.hex_encode())

			if saved != "":
				_tried_remembered = true
				_send_proof(saved.hex_decode())
			elif typed_before != "":
				_send_proof(typed_before.hex_decode())   # typed earlier this run: not asked again
			else:
				password_needed.emit(TRIES, false)
		"wrong":
			var left: int = int(message.get("left", 0))
			remembered_was_wrong = _tried_remembered
			_tried_remembered = false
			session_forget(session_address)   # nothing right is held any more: the box asks

			if left <= 0:
				refused.emit("wrong")
				return

			_client_nonce = str(message.get("nonce", "")).hex_decode()
			password_needed.emit(left, true)
		"busy":
			refused.emit("busy")


# The player's typed password for the challenge now open. `keep`: the player ticked Remember (carried to the next connection with the key).
func submit(password: String, keep: bool = false) -> void:
	var key: PackedByteArray = hash_password(_client_salt, password)
	session_remember(session_address, _client_salt.hex_encode(), key.hex_encode(), keep)
	_send_proof(key)


# The keys typed this run, "host:port" -> {"salt", "hash", "keep"} (R-JOIN-PASSWORD-ONCE above). An empty address keeps nothing (tests, bots).
static func session_remember(address: String, salt_hex: String, hash_hex: String, keep: bool) -> void:
	if address == "":
		return

	var keys: Dictionary = Engine.get_meta(SESSION_META, {})
	keys[address] = {"salt": salt_hex, "hash": hash_hex, "keep": keep}
	Engine.set_meta(SESSION_META, keys)


static func session_key(address: String, salt_hex: String) -> String:
	var row: Variant = (Engine.get_meta(SESSION_META, {}) as Dictionary).get(address)
	return str((row as Dictionary).get("hash", "")) if address != "" and row is Dictionary and str((row as Dictionary).get("salt", "")) == salt_hex else ""


static func session_keeps(address: String) -> bool:
	var row: Variant = (Engine.get_meta(SESSION_META, {}) as Dictionary).get(address)
	return row is Dictionary and bool((row as Dictionary).get("keep", false))


static func session_forget(address: String) -> void:
	var keys: Dictionary = Engine.get_meta(SESSION_META, {})

	if keys.erase(address):
		Engine.set_meta(SESSION_META, keys)


func _send_proof(key: PackedByteArray) -> void:
	_trying_hash = key
	_send(1, {"t": "proof", "proof": proof_of(key, _client_nonce).hex_encode()})


func _send(peer: int, message: Dictionary) -> void:
	_mp.send_auth(peer, JSON.stringify(message).to_utf8_buffer())
