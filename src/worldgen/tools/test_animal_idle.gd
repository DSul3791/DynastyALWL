extends SceneTree

# Idle life (Dave 23 Nov 2026: animals "like really bad animatronics"; docs/design/ANIMAL_GAIT.md): a standing or grazing animal plays its
# own clip first, then one idle variant once through its length, then its own clip again for 6 to 16 s; a change of role starts again
# on its own clip; a model with no variants plays its own clip only.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_idle.gd

const AnimalViewScript := preload("res://src/client/animal_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var v = AnimalViewScript.new()
	var player: AnimationPlayer = AnimationPlayer.new()
	var lib: AnimationLibrary = AnimationLibrary.new()

	for clip in [["Graze", 8.0], ["LookUp", 2.5], ["Shake", 0.6]]:
		var anim: Animation = Animation.new()
		anim.length = float(clip[1])
		lib.add_animation(StringName(clip[0]), anim)

	player.add_animation_library("", lib)
	player.set_meta("idle", {"0": ["LookUp"]})
	var b: Dictionary = {}

	check(v._idle_life(b, player, "0", "Graze") == "Graze", "it starts on its own clip")
	var first: float = float(b["idle_until"]) - v._t
	check(first >= 2.0 and first <= 12.0, "its first spell is 2 to 12 s (%.1f)" % first)
	v._t = float(b["idle_until"]) + 0.01
	check(v._idle_life(b, player, "0", "Graze") == "LookUp", "then a variant")
	check(absf(float(b["idle_until"]) - v._t - 2.5) < 0.001, "played once through its own length (2.5 s)")
	v._t = float(b["idle_until"]) + 0.01
	check(v._idle_life(b, player, "0", "Graze") == "Graze", "then its own clip again")
	var spell: float = float(b["idle_until"]) - v._t
	check(spell >= 6.0 and spell <= 16.0, "for 6 to 16 s (%.1f)" % spell)

	# A change of role (it stood up to watch) starts on that role's own clip.
	v._t = float(b["idle_until"]) + 0.01
	check(v._idle_life(b, player, "3", "Alert") == "Alert", "a role with no variants plays its own clip")
	check(v._idle_life(b, player, "0", "Graze") == "Graze", "back to grazing: it starts on its own clip, not a variant")

	# A variant shorter than IDLE_MIN_S plays through more than once.
	player.set_meta("idle", {"0": ["Shake"]})
	var c: Dictionary = {}
	v._idle_life(c, player, "0", "Graze")
	v._t = float(c["idle_until"]) + 0.01
	check(v._idle_life(c, player, "0", "Graze") == "Shake" and absf(float(c["idle_until"]) - v._t - AnimalViewScript.IDLE_MIN_S) < 0.001, "a 0.6 s shake holds for IDLE_MIN_S")

	player.set_meta("idle", {})
	var d: Dictionary = {}
	check(v._idle_life(d, player, "0", "Graze") == "Graze" and not d.has("idle_until"), "no variants: its own clip, no spell kept")

	player.free()
	v.free()
	print("test_animal_idle: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
