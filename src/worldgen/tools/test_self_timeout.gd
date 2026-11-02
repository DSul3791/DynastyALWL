extends SceneTree

# Testing-only self shutdown flags (self_timeout.gd): parsing of --timeout=S, --timeout S and --watch-parent=PID; no flag means no watcher at all; the due rule with a fake clock.
#   godot --headless --path . --script res://src/worldgen/tools/test_self_timeout.gd

const SelfScript := preload("res://src/shared/self_timeout.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var a: Dictionary = SelfScript.parse(PackedStringArray(["--server=x", "--timeout=300"]))
	check(float(a["seconds"]) == 300.0 and int(a["parent"]) == 0, "--timeout=300 is 300 seconds")
	check(float(SelfScript.parse(PackedStringArray(["--timeout", "120"]))["seconds"]) == 120.0, "--timeout 120 (two words) works too")
	check(int(SelfScript.parse(PackedStringArray(["--watch-parent=4242"]))["parent"]) == 4242, "--watch-parent=PID is read")
	var none: Dictionary = SelfScript.parse(PackedStringArray(["--server=x", "--port=1"]))
	check(float(none["seconds"]) == 0.0 and int(none["parent"]) == 0, "no flag: no limit")
	check(SelfScript.install(self.root, PackedStringArray(["--port=1"])) == null, "no flag: no watcher is added")
	var w = SelfScript.new()
	w.seconds = 10.0
	w.parent_pid = 77
	w._begun_ms = 1000
	check(w.reason_at(5000, true) == "" and w.reason_at(11000, true).begins_with("--timeout=10") and w.reason_at(5000, false).contains("77"), "due after the seconds, or when the parent is gone; not before")
	var node: Node = SelfScript.install(self.root, PackedStringArray(["--timeout=300"]), func(_why): pass)
	check(node != null and node.seconds == 300.0, "with a flag the watcher is added")
	print("self timeout: %d failures" % failures)
	quit(1 if failures > 0 else 0)
