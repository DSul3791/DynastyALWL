extends RefCounted

# The release build stamp (server/client split step A1, Dave 18 Nov 2026: "the build number should be automated"; the server refuses a
# client whose build number differs). tools/build_stamp.py writes res://build_stamp.json just before an export: the build number is
# main's commit count at that commit (never typed, only goes up), with the full commit and the UTC date. The file is gitignored.
# Editor runs have no stamp and keep today's numbers (src/shared/build.gd NUMBER, the commit from .git), so local Play is unchanged.
# A stamp left in a checkout after a pull names another commit than .git and is ignored.

const GitStamp := preload("res://src/debug/git_stamp.gd")
const BuildInfo := preload("res://src/shared/build.gd")
const PATH := "res://build_stamp.json"


# {"build": int > 0, "commit": 40 hex, "date": String}, or {} when the text is not a whole stamp.
static func parse(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)

	if not parsed is Dictionary:
		return {}

	var row: Dictionary = parsed
	var build: Variant = row.get("build")
	var commit: String = str(row.get("commit", ""))

	if not (build is float or build is int) or int(build) != build or int(build) <= 0 or commit.length() != 40 or not commit.is_valid_hex_number():
		return {}

	return {"build": int(build), "commit": commit, "date": str(row.get("date", ""))}


# The stamp this copy runs with, or {} (an editor run, or a stamp that does not belong to the checkout's commit). git_commit is the
# .git commit ("" in an export); tests pass their own.
static func read(path: String = PATH, git_commit: String = GitStamp.git_commit()) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var stamp: Dictionary = parse(FileAccess.get_file_as_string(path))

	if not stamp.is_empty() and git_commit != "" and not str(stamp["commit"]).begins_with(git_commit):
		return {}

	return stamp


# The stamped build number, 0 for an editor run. This is what hello sends and what the server checks.
static func stamped_build() -> int:
	return int(read().get("build", 0))


# The build number to show (menu, HUD, welcome): the stamp's, or the hand-kept number in an editor run.
static func number() -> int:
	var build: int = stamped_build()
	return build if build > 0 else BuildInfo.NUMBER


# What a server stamped server_build says to a client that sent client_build at hello; "" lets it in. An unstamped server (Dave's
# editor Play, the PC tests) lets every build in, as today.
static func refusal(server_build: int, client_build: int) -> String:
	if server_build <= 0 or client_build == server_build:
		return ""

	if client_build <= 0:
		return "This game is a development copy; the server is build %d.\nInstall build %d and try again." % [server_build, server_build]

	return "This game is build %d; the server is build %d.\nUpdate the game and try again." % [client_build, server_build]
