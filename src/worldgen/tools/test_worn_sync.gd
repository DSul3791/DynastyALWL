extends SceneTree

# WornSync: an outfit hung twice changes nothing the second time, one swapped item changes the key, far/near hysteresis holds.

const WornSync := preload("res://src/client/worn_sync.gd")
const RagdollScript := preload("res://src/client/ragdoll_body.gd")

var failures: int = 0


func check(name: String, ok: bool) -> void:
	print("%s: %s" % ["pass" if ok else "FAIL", name])
	failures += 0 if ok else 1


func _init() -> void:
	var rig: Node3D = RagdollScript.new()
	root.add_child(rig)
	var outfit: Array = WornSync.known_ids(["hide_boots", "hide_hood", "no_such_item"])
	check("unknown id skipped", outfit.size() == 2)
	check("first apply hangs parts", WornSync.apply(rig, outfit, false) >= 0)
	check("second apply changes nothing", WornSync.apply(rig, outfit, false) == -1)
	check("swapped item rehangs", WornSync.apply(rig, ["hide_boots"], false) >= 0)
	check("far rehangs", WornSync.apply(rig, ["hide_boots"], true) >= 0)
	check("near at 20 m", not WornSync.far_after(20.0, false))
	check("far at 40 m", WornSync.far_after(40.0, false))
	check("hysteresis keeps far at 29 m", WornSync.far_after(29.0, true))
	check("hysteresis keeps near at 31 m", not WornSync.far_after(31.0, false))
	print("worn sync test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
