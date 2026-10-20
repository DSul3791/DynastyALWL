extends RefCounted
# Short id of the commit this checkout is on, read from .git (no git program needed),
# so the HUD can tell which code is running now that build numbers come in blocks per
# thread and are not in time order. Empty when there is no .git folder (exports).

static func short_commit() -> String:
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
