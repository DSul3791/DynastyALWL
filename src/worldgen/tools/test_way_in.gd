extends SceneTree

# A tester's way in (coordinator, 23 Nov 2026): what the joining window says when a join goes wrong, and the second-copy question.
# The live cases (full server, bad name, no server, no address) run in tools/way_in_check.sh.
#   godot --headless --path . --script res://src/worldgen/tools/test_way_in.gd      Prints "Test done: N pass, N fail".

const InstanceLock := preload("res://src/client/instance_lock.gd")
const GroundWatchdog := preload("res://src/client/ground_watchdog.gd")
const TEMP := "user://test_way_in_open.json"

var passes: int = 0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _initialize() -> void:
	var client: GDScript = load("res://scenes/terrain_client/terrain_client.gd")
	var server_src: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	var full_words: String = "The server is full (%d players). Try again when someone leaves." % 32
	check(server_src.contains("const SERVER_FULL := \"The server is full (%d players). Try again when someone leaves.\""), "the server's full words are the ones this test titles")
	check(client.join_refused_title(full_words) == "Server full", "a full server's refusal is titled Server full")
	check(client.join_refused_title("This character joined the server again from another game window or computer, so this one was closed. Nothing was lost.") == "Joined from elsewhere", "a second connection of the character is titled Joined from elsewhere")
	check(client.join_refused_title("This game is build 9257, the server is build 9300.") == "Update required", "a build refusal is titled Update required")
	check(server_src.contains("create_server(port, max_players + 1)"), "the server lets one peer past the limit in, to tell it the server is full")
	var client_src: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	check(not client_src.contains("or since > 120:"), "the joining window no longer closes at 2 minutes with the ground still missing")
	check(client.JOIN_GIVE_UP_S > GroundWatchdog.HARD_STALL_S + GroundWatchdog.STALL_WAIT_S, "the window's own give-up comes after the ground watchdog's, which names its failure first")
	check(not client_src.contains("A full server also turns new players away without a word"), "the cannot-reach words no longer blame a full server")

	# Second copy: a fresh note of another process -> asked; own, stale (a crash) or damaged -> not asked.
	var me: int = OS.get_process_id()
	var now: float = Time.get_unix_time_from_system()
	InstanceLock.claim(TEMP, me, now)
	check(InstanceLock.other_copy(TEMP, me, now) == 0, "the note of this very copy is not another copy")
	check(InstanceLock.other_copy(TEMP, me + 1, now + 4.0) == me, "another copy's fresh note is found")
	check(InstanceLock.other_copy(TEMP, me + 1, now + InstanceLock.FRESH_S + 1.0) == 0, "a note older than its refresh (a crash left it) is not asked about")
	check(InstanceLock.FRESH_S >= InstanceLock.EVERY_S * 2.0, "a note is fresh for at least two refreshes, so a slow frame does not let a second copy slip by")
	var file: FileAccess = FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_string("{\"pid\": [1]} not json")
	file.close()
	check(InstanceLock.other_copy(TEMP, me + 1, now) == 0, "a damaged note is as if none")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	check(InstanceLock.other_copy(TEMP, me + 1, now) == 0, "no note: no other copy")
	InstanceLock.claim(TEMP, me + 7, now)
	InstanceLock.release(TEMP, me)
	check(FileAccess.file_exists(TEMP), "closing leaves another copy's note alone")
	InstanceLock.claim(TEMP, me, now)
	InstanceLock.release(TEMP, me)
	check(not FileAccess.file_exists(TEMP), "closing takes this copy's own note away, so starting again at once is not asked about")
	InstanceLock.keep_fresh(self, TEMP)
	await process_frame
	var watcher: Node = root.get_node_or_null("InstanceLockNote")
	check(watcher != null and FileAccess.file_exists(TEMP), "an open copy keeps its note, with a watcher under the root")

	if watcher != null:
		root.remove_child(watcher)   # what closing the game does to every node under the root
		watcher.free()

	check(not FileAccess.file_exists(TEMP), "the watcher leaving (the game closing) takes the note away")
	var server_full_src: String = server_src.substr(server_src.find("func _full_for("), 700)
	check(server_full_src.contains("not _peers[other].has(\"player\")") and server_full_src.contains("items.key_of(other) == store"), "only players let in count, and the same character coming back is never full")
	check(InstanceLock.should_ask(PackedStringArray(), "Windows") and not InstanceLock.should_ask(PackedStringArray(["--test"]), "Windows") and not InstanceLock.should_ask(PackedStringArray(), "headless"), "asked in a real window only, never in tests or headless")
	var launcher_src: String = FileAccess.get_file_as_string("res://scenes/launcher.gd")
	check(launcher_src.contains("not OS.get_cmdline_user_args().has(\"--to-servers\") and InstanceLock.other_copy() > 0"), "a restart of this copy (Back to servers) is never asked about")

	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
