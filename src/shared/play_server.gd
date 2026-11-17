extends RefCounted

# Play and the server it starts share two notes in the user folder (Dave 17 Nov 2026: he pulled dev, pressed Play and joined the server
# from before the pull, so Edda and Hob's camp was not there). The server writes server_run.json (pid, port, commit, state, "stop": 1 when
# Play started it); Play, finding its port held by a server of other code, writes server_stop.json naming that process, and only that
# process obeys. launcher.gd and terrain_server.gd use these two checks; test_play_server.gd tests them.


# True when Play should ask the server in `note` (server_run.json) to close: it holds `port`, Play started it, it is running (not
# already closing), its process is alive, and it runs other code than `mine`. Without a commit on either side (an export) nothing is asked.
static func should_ask_stop(note: Dictionary, port: int, mine: String, alive: bool) -> bool:
	var theirs: String = str(note.get("commit", ""))

	if int(note.get("port", 0)) != port or int(note.get("stop", 0)) != 1 or str(note.get("state", "")) != "running":
		return false

	return alive and mine != "" and theirs != "" and mine != theirs


# True when the stop request `asked` (server_stop.json) is for the process `pid`.
static func stop_is_for(asked: Variant, pid: int) -> bool:
	return asked is Dictionary and pid > 0 and int(asked.get("pid", 0)) == pid
