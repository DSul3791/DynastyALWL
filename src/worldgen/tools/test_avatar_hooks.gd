extends SceneTree

# The Dynasty body's state hooks (docs/DYNASTY_BODY.md): swim, drink, pick up, sit down, stand up, wake up. avatar_driver.gd hook_clip asks for the clip when
# the state changes; a body without these clips gets nothing.
#   godot --headless --path . --script res://src/worldgen/tools/test_avatar_hooks.gd

const AvatarDriver := preload("res://src/client/character/avatar_driver.gd")
const StanceScript := preload("res://src/client/stance.gd")

var failures: int = 0


class FakeBody:
	extends Node3D
	var animation_player: AnimationPlayer


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _body(clips: Array) -> FakeBody:
	var body: FakeBody = FakeBody.new()
	body.animation_player = AnimationPlayer.new()
	var library: AnimationLibrary = AnimationLibrary.new()

	for name in clips:
		var a: Animation = Animation.new()
		a.length = 1.0
		library.add_animation(name, a)

	body.animation_player.add_animation_library("", library)
	return body


func _initialize() -> void:
	var all: Array = ["idle", "swim", "swim_idle", "drink", "pick_up", "sit_down", "stand_up", "wake_up"]
	var body: FakeBody = _body(all)
	var ctx: Dictionary = {"swimming": false, "asleep": false, "stance": StanceScript.STAND, "drink_stamp": 0, "pick_stamp": 0}
	check(AvatarDriver.hook_clip(body, ctx, 0.0, 0.016) == "", "nothing happening: no hook")

	# Swimming: the stroke while moving, the tread while still; leaving the water ends it at once.
	ctx["swimming"] = true
	check(AvatarDriver.hook_clip(body, ctx, 1.0, 0.016) == "swim", "swimming and moving: swim")
	check(AvatarDriver.hook_clip(body, ctx, 0.0, 0.016) == "swim_idle", "swimming and still: swim_idle")
	ctx["swimming"] = false
	check(AvatarDriver.hook_clip(body, ctx, 0.0, 0.016) == "", "out of the water: the usual clip again")

	# Drink: a new drink stamp plays the clip for its length, then it ends.
	ctx["drink_stamp"] = 1000
	check(AvatarDriver.hook_clip(body, ctx, 0.0, 0.016) == "drink", "a drink: drink")
	check(AvatarDriver.hook_clip(body, ctx, 0.0, 0.5) == "drink", "still drinking half a second later")
	check(AvatarDriver.hook_clip(body, ctx, 0.0, 0.6) == "", "and finished after the clip's length")

	# Pick up: standing still, a pick-up bends over; at a run it is skipped.
	ctx["pick_stamp"] = 2000
	check(AvatarDriver.hook_clip(body, ctx, 0.0, 0.016) == "pick_up", "a pick-up: pick_up")
	check(AvatarDriver.hook_clip(body, ctx, 0.0, 1.5) == "", "and over")
	ctx["pick_stamp"] = 3000
	check(AvatarDriver.hook_clip(body, ctx, 4.0, 0.016) == "", "a pick-up on the run is not played")

	# Sitting down and standing up: the chair transitions are not played for the ground sit (the sit clip blends in directly).
	ctx["stance"] = StanceScript.SIT
	check(AvatarDriver.hook_clip(body, ctx, 0.0, 0.016) == "", "standing to sitting: no chair transition")
	ctx["stance"] = StanceScript.STAND
	check(AvatarDriver.hook_clip(body, ctx, 0.0, 0.016) == "", "sitting to standing: no chair transition")
	ctx["stance"] = StanceScript.CROUCH
	check(AvatarDriver.hook_clip(body, ctx, 0.0, 0.016) == "", "crouching has no hook")

	# Waking: the sleep ends.
	ctx["stance"] = StanceScript.LIE
	ctx["asleep"] = true
	AvatarDriver.hook_clip(body, ctx, 0.0, 0.016)
	ctx["asleep"] = false
	check(AvatarDriver.hook_clip(body, ctx, 0.0, 0.016) == "wake_up", "asleep to awake: wake_up")

	# A body without the clips (the generated body, the old ragdoll) gets nothing and is not harmed.
	var plain: FakeBody = _body(["idle", "walk"])
	ctx["swimming"] = true
	check(AvatarDriver.hook_clip(plain, ctx, 1.0, 0.016) == "", "a body without the hook clips gets no hook")
	check(AvatarDriver.hook_clip(null, ctx, 1.0, 0.016) == "", "no body: no hook")

	print("test_avatar_hooks: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
