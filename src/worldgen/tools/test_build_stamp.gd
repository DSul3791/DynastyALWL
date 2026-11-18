extends SceneTree

# The automatic build number and the server's build check (server/client split step A1, Dave 18 Nov 2026: "the build number should be
# automated"; a client whose build number differs from the server's is refused). Checks: a stamp is read only when whole; one naming
# another commit than .git is ignored; the refusal text and who is let in; an editor run keeps build.gd NUMBER; the commit falls back to
# the stamp in an export; and the server, client, bot and title page are wired to it. Uses user://build_stamp_test, never res://.
#   godot --headless --path . --script res://src/worldgen/tools/test_build_stamp.gd

const BuildStamp := preload("res://src/shared/build_stamp.gd")
const BuildInfo := preload("res://src/shared/build.gd")
const TitleScene := preload("res://scenes/title/title.gd")
const DIR := "user://build_stamp_test"
const COMMIT := "6dedf7fe0123456789abcdef0123456789abcdef"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _write(name: String, text: String) -> String:
	var path: String = DIR.path_join(name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var whole: String = JSON.stringify({"build": 412, "commit": COMMIT, "date": "2026-11-18T20:00:00Z"})

	# Parsing: only a whole stamp counts.
	check(BuildStamp.parse(whole) == {"build": 412, "commit": COMMIT, "date": "2026-11-18T20:00:00Z"}, "a whole stamp is read")
	check(BuildStamp.parse("").is_empty() and BuildStamp.parse("[1]").is_empty() and BuildStamp.parse("{bad").is_empty(), "no stamp, a list or broken text is no stamp")
	check(BuildStamp.parse(JSON.stringify({"build": 0, "commit": COMMIT})).is_empty(), "build 0 is no stamp")
	check(BuildStamp.parse(JSON.stringify({"build": 41.5, "commit": COMMIT})).is_empty(), "a fractional build is no stamp")
	check(BuildStamp.parse(JSON.stringify({"build": "412", "commit": COMMIT})).is_empty(), "a build typed as text is no stamp")
	check(BuildStamp.parse(JSON.stringify({"build": 412, "commit": "6dedf7f"})).is_empty(), "a short commit is no stamp")
	check(BuildStamp.parse(JSON.stringify({"build": 412, "commit": "z".repeat(40)})).is_empty(), "a commit that is not hex is no stamp")

	# Reading: an export (no .git) trusts the stamp; a checkout trusts it only for its own commit.
	var path: String = _write("build_stamp.json", whole)
	check(int(BuildStamp.read(path, "").get("build", 0)) == 412, "an export (no .git) reads the stamp")
	check(int(BuildStamp.read(path, "6dedf7f").get("build", 0)) == 412, "a checkout on the stamped commit reads it")
	check(BuildStamp.read(path, "290a40f").is_empty(), "a stamp left in a checkout after a pull is ignored")
	check(BuildStamp.read(DIR.path_join("none.json"), "").is_empty(), "no file, no stamp")

	# The refusal: an unstamped server lets everyone in; a stamped one only its own build.
	check(BuildStamp.refusal(0, 0) == "" and BuildStamp.refusal(0, 412) == "", "an unstamped server (editor Play) refuses nobody")
	check(BuildStamp.refusal(412, 412) == "", "the same build joins")
	var older: String = BuildStamp.refusal(413, 412)
	check(older.contains("build 412") and older.contains("build 413") and older.contains("Update"), "another build is told both numbers and to update (%s)" % older.replace("\n", " "))
	check(BuildStamp.refusal(412, 0).contains("development copy"), "an editor copy is told it is one")

	# This checkout has no stamp of its own (gitignored), so the numbers are today's.
	if not FileAccess.file_exists(BuildStamp.PATH):
		check(BuildStamp.stamped_build() == 0, "an editor run sends build 0")
		check(BuildStamp.number() == BuildInfo.NUMBER, "an editor run shows build.gd NUMBER")
		check(TitleScene.build_text().begins_with("Build %d" % BuildInfo.NUMBER), "the title page shows it (%s)" % TitleScene.build_text())
	else:
		print("note: res://build_stamp.json exists here; the editor-run checks were skipped")

	# Wiring (source checks): the server reads its stamp once and checks hello before anything of the player's; the client sends its build and
	# shows the refusal; the welcome's build is the stamped one; the commit falls back to the stamp in an export.
	var server: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	var client: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	var net: String = FileAccess.get_file_as_string("res://src/stream/terrain_net.gd")
	var git: String = FileAccess.get_file_as_string("res://src/debug/git_stamp.gd")
	check(server.contains("var _stamped_build: int = BuildStamp.stamped_build()"), "the server reads its stamp once, at start")
	var hello_at: int = server.find("net.hello_requested.connect(func(peer, key, build):")
	var refuse_at: int = server.find("BuildStamp.refusal(_stamped_build, build)", hello_at)
	check(hello_at >= 0 and refuse_at > hello_at and refuse_at < server.find("identity.authenticate(peer, key)", hello_at), "the build is checked before the player is let in")
	check(server.contains("net.join_refused.rpc_id(peer, text)") and server.contains("disconnect_peer(peer)"), "a refused client is told why and dropped")
	check(server.contains("\"server_build\": _stamped_build if _stamped_build > 0 else BuildInfo.NUMBER") and server.contains("\"server_stamped\": _stamped_build > 0"), "the welcome names the enforced build and says it is a release server")
	check(server.contains("_peers[peer].has(\"refused\")"), "one refusal per connection")
	# The client's own commit check runs before hello is sent; against a release server it must stand aside, or two builds (whose commits
	# always differ) would see "the server is out of date" and never the server's "Update required".
	var commit_check_at: int = client.find("server_commit != _commit and _connect_window != null")
	check(commit_check_at >= 0 and client.substr(maxi(commit_check_at - 120, 0), 120).contains("not bool(info.get(\"server_stamped\", false))"), "the client's commit check stands aside for a release server")
	check(net.contains("func hello(player_key: String, build: int)") and net.contains("func join_refused(text: String)"), "hello carries the build; join_refused exists")
	check(FileAccess.get_file_as_string("res://src/client/inventory_view.gd").contains("net.hello.rpc_id(1, _player_key(), BuildStamp.stamped_build())"), "the client sends its stamped build")
	check(FileAccess.get_file_as_string("res://scenes/bot/bot_main.gd").contains("BuildStamp.stamped_build()"), "the load-test bot sends it too")
	check(client.contains("net.join_refused_received.connect(_on_join_refused)") and client.contains("_connect_window.fail(\"Update required\""), "the client shows the refusal")
	# One line each: Windows checkouts end lines with CRLF, so no check spans a line break.
	var lost_at: int = client.find("func _on_server_lost() -> void:")
	var guard_at: int = client.find("return   # dropped after a refusal", lost_at)
	check(lost_at >= 0 and guard_at > lost_at and guard_at < client.find("crash_report.report_now(\"server left", lost_at), "the drop after a refusal does not cover it with the lost-connection notice")
	var welcome_at: int = client.find("func _welcome_body(info: Dictionary) -> void:")
	var early_at: int = client.find("BuildStamp.refusal(int(info.get(\"server_build\", 0)), BuildStamp.stamped_build())", welcome_at)
	check(welcome_at >= 0 and early_at > welcome_at and early_at < client.find("world = info", welcome_at) and early_at < client.find("FloraViewScript.new()", welcome_at), "a release server's other build stops at the welcome, before anything loads or the hello goes")
	check(not client.contains("(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1)) if multiplayer.multiplayer_peer is ENetMultiplayerPeer"), "the lost-connection line does not ask a closed link for its peer")
	check(git.contains("load(\"res://src/shared/build_stamp.gd\").read()"), "the commit comes from the stamp when there is no .git")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("test_build_stamp: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
