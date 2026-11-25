extends SceneTree

# The stealthy crawl (Dave, QA #10, 25 Nov 2026: "right now when you lay down its always like you are sleeping. that should only be when you are lying
# on a bed or when you hold Z to go to sleep. otherwise you should first drop like you are being stealthy and crawling"). Lying off a bed and awake
# the body crawls (avatar_driver.gd crawl_clip: prone still, crawl forward or sideways, crawl_back backwards) at stance.gd CRAWL_MPS; lying at rest
# (meta lie_rest: on a bed, asleep, fainted) it keeps the sleep pose. A body without the crawl clips keeps the old lie.
#   godot --headless --path . --script res://src/worldgen/tools/test_crawl.gd

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


func _clip(body, velocity: Vector3) -> String:
	return AvatarDriver.clip_for(body, StanceScript.LIE, velocity, Basis.IDENTITY, true, Vector2(velocity.x, velocity.z).length(), "", false, 0.016)


func _initialize() -> void:
	var body: FakeBody = _body(["idle", "lie", "prone", "crawl", "crawl_back", "jump", "fall", "land", "crouch_walk_back"])

	# Awake and off a bed: the crawl, by the way the body moves (forward is -Z).
	check(_clip(body, Vector3.ZERO) == "prone", "lying still off a bed: the low crawl pose, not the sleep pose")
	check(_clip(body, Vector3(0.0, 0.0, -0.4)) == "crawl", "moving forward: crawl")
	check(_clip(body, Vector3(0.0, 0.0, 0.4)) == "crawl_back", "moving back: crawl_back")
	check(_clip(body, Vector3(0.4, 0.0, 0.0)) == "crawl", "moving sideways: the forward crawl (the rig has no sideways one)")
	check(_clip(body, Vector3(0.0, 0.0, -0.05)) == "prone", "a drift under CRAWL_MIN_PACE: still")

	# At rest (on a bed, asleep, fainted): the sleep pose.
	body.set_meta("lie_rest", true)
	check(_clip(body, Vector3.ZERO) == "lie", "lying on a bed or asleep: the sleep pose")
	check(AvatarDriver.far_lie_clip(body, "lie") == "lie", "far off and at rest: the sleep pose")
	body.set_meta("lie_rest", false)
	check(AvatarDriver.far_lie_clip(body, "lie") == "prone", "far off and awake off a bed: the crawl pose")
	check(AvatarDriver.far_lie_clip(body, "sit") == "sit", "far off and sitting: unchanged")

	# A body without the crawl clips keeps lying as before.
	var plain: FakeBody = _body(["idle", "lie", "jump"])
	check(_clip(plain, Vector3.ZERO) == "lie" and _clip(plain, Vector3(0.0, 0.0, -0.4)) == "lie", "a body without the crawl clips: lie")
	check(AvatarDriver.far_lie_clip(plain, "lie") == "lie", "far off, no crawl clips: lie")

	# The pace: the stance's share of the 3.2 m/s walk is the crawl's 0.4 m/s, and the stride plays at its own speed there (no sliding).
	check(is_equal_approx(3.2 * float(StanceScript.SPEED[StanceScript.LIE]), StanceScript.CRAWL_MPS) and is_equal_approx(StanceScript.CRAWL_MPS, 0.4), "lying moves at the crawl's 0.4 m/s")
	check(is_equal_approx(AvatarDriver.speed_scale("crawl", StanceScript.CRAWL_MPS), 1.0) and is_equal_approx(AvatarDriver.speed_scale("crawl_back", 0.2), 0.5), "the crawl clips follow the real pace")

	# The keys: a movement key stands a sitter up, and a lier unless crawling.
	var st = StanceScript.new()
	st.set_stance(StanceScript.LIE)
	st.moved(true)
	check(st.stance == StanceScript.LIE, "crawling: a movement key keeps the player lying")
	st.moved()
	check(st.stance == StanceScript.STAND, "lying at rest: a movement key stands the player up")
	st.set_stance(StanceScript.SIT)
	st.moved(true)
	check(st.stance == StanceScript.STAND, "sitting: a movement key stands the player up")

	body.free()
	plain.free()
	print("test_crawl: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
