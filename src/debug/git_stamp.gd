extends RefCounted
# Short id of the commit this copy runs, so the HUD and the join check can tell which code is running. Read from .git (no git
# program needed); an export has no .git folder, so it reads the commit from the release stamp (src/shared/build_stamp.gd,
# step A1) instead. Empty only with neither.

static func short_commit() -> String:
	var id: String = git_commit()

	if id != "":
		return id

	var stamp: Dictionary = load("res://src/shared/build_stamp.gd").read()   # load, not preload: build_stamp.gd preloads this file
	return str(stamp.get("commit", "")).substr(0, 7)


# The short commit from .git alone, "" when there is none (exports).
static func git_commit() -> String:
	var git_dir: String = ProjectSettings.globalize_path("res://.git")

	if FileAccess.file_exists(git_dir):
		# A worktree: ".git" is a file reading "gitdir: <path>".
		var link: String = FileAccess.get_file_as_string(git_dir).strip_edges()
		git_dir = link.trim_prefix("gitdir:").strip_edges()

	var head: String = FileAccess.get_file_as_string(git_dir.path_join("HEAD")).strip_edges()

	if not head.begins_with("ref:"):
		return head.substr(0, 7)

	var ref: String = head.trim_prefix("ref:").strip_edges()
	var id: String = FileAccess.get_file_as_string(git_dir.path_join(ref)).strip_edges()

	if id == "":
		var packed: String = FileAccess.get_file_as_string(git_dir.path_join("packed-refs"))

		for line in packed.split("\n"):
			if line.ends_with(" " + ref):
				id = line.substr(0, 40)
				break

	return id.substr(0, 7)
