extends RefCounted

# The rules that choose the player avatar's clip, its playback speed, its slope tilt and its clothes colours (Sonny, plan 4 of CHARACTER_DESIGN_VISION.md Part 8).
# These were inline in scenes/terrain_client/terrain_client.gd (`_update_view`, `_dress_avatar`); they are moved here unchanged in behaviour so the avatar
# logic has one home and can be tested without the game (tools/check_avatar_driver.gd). The client still owns the camera, the avatar node and the held item.

const StanceScript := preload("res://src/client/stance.gd")
const BasicLookScript := preload("res://src/client/basic_look.gd")
const WornSync := preload("res://src/client/worn_sync.gd")

const WALK_MIN_PACE := 0.6              # below this horizontal speed (m/s) the body stands still
const JOG_FROM := 2.2                   # walk to jog (m/s); 1.8 when already jogging or running, so the clip does not flicker at the limit
const JOG_HOLD := 1.8
const RUN_FROM := 5.0                   # jog to run; 4.4 when already running
const RUN_HOLD := 4.4
const RUN_CLIP_PACE := 6.0              # the pace the run clip was retimed for; running faster (9 m/s) does not play it faster
const JUMP_UP := 1.0                    # vertical speed (m/s) above which the airborne clip is the jump (rising); below it the fall
const AIR_DELAY := 0.15                 # seconds without a floor before the body counts as in the air
const LAND_AFTER := 0.4                 # a fall at least this long ends in the land clip
const LAND_HOLD := 0.36                 # how long the land clip is asked for (a little under its length, so it is not restarted when it ends)
const SKIN := Color(0.78, 0.62, 0.5)
const COAT := Color(0.4, 0.34, 0.28)
const TROUSERS := Color(0.25, 0.22, 0.2)
const SHOES := Color(0.14, 0.11, 0.09)


# The clip for a stance and a horizontal speed. `current` is the clip playing now (it sets the hysteresis margins).
static func choose_clip(stance: int, pace: float, current: String, carrying: bool) -> String:
	var clip: String = ["idle", "crouch", "sit", "lie"][stance]

	if stance == StanceScript.STAND and pace > WALK_MIN_PACE:
		var jog_from: float = JOG_FROM if current != "jog" and current != "run" else JOG_HOLD
		var run_from: float = RUN_FROM if current != "run" else RUN_HOLD
		clip = "run" if pace > run_from else ("jog" if pace > jog_from else "walk")

	# A large log on the shoulder (Dave 2026-10-21): the carry clips replace idle and the gaits while standing.
	if carrying and stance == StanceScript.STAND:
		clip = "carry_walk" if pace > WALK_MIN_PACE else "carry_idle"

	return clip


# Plan 19: the clip for a body that may be in the air or moving sideways or backwards (the clips of motion_extra.gd; the old body has no such clips and ignores the
# names, so ask a generated body only). `velocity_local` is the horizontal velocity in the body's own frame (x right, y the world z, so forward is -y), `vertical` the
# vertical speed (m/s, up positive), `airborne` true when not on the floor. Everything else falls back to choose_clip.
static func choose_clip_moving(stance: int, velocity_local: Vector2, vertical: float, airborne: bool, current: String, carrying: bool) -> String:
	if airborne and stance == StanceScript.STAND:
		return "jump" if vertical > JUMP_UP and current != "fall" else "fall"

	var pace: float = velocity_local.length()
	var forward: float = -velocity_local.y

	if stance == StanceScript.CROUCH and pace > WALK_MIN_PACE:
		return "crouch_walk"

	if stance == StanceScript.STAND and not carrying and pace > WALK_MIN_PACE and pace <= JOG_FROM:
		if forward < -0.5 * pace:
			return "walk_back"

		if absf(velocity_local.x) > 0.8 * pace:
			return "strafe_right" if velocity_local.x > 0.0 else "strafe_left"

	return choose_clip(stance, pace, current, carrying)


# Plan 20: the one call the client makes each frame. A body that has the plan 19 clips (a generated body) gets choose_clip_moving with its local velocity, the air time
# (the floor must be lost for AIR_DELAY seconds before it counts as in the air, so steps and slope edges do not flicker) and a landing: after a fall of LAND_AFTER
# seconds or more the `land` clip is asked for until it is over. Any other body (the old ragdoll) gets exactly choose_clip. The timers live in meta on the avatar.
static func clip_for(avatar, stance: int, velocity: Vector3, basis: Basis, on_floor: bool, pace: float, current: String, carrying: bool, delta: float) -> String:
	var player: AnimationPlayer = avatar.get("animation_player") as AnimationPlayer

	# The Dynasty body (dynasty_body.gd) has crouched walking clips and the air clips (jump, fall, land) but not the sideways and backward ones (the generated body's set): crouched and moving it
	# walks bent, in the direction of the velocity.
	var dynasty: bool = player != null and player.has_animation("crouch_walk_back")

	if dynasty and stance == StanceScript.CROUCH and pace > WALK_MIN_PACE:
		var crouch_local: Vector3 = basis.inverse() * velocity
		var crouch_clip: String = crouch_walk_clip(Vector2(crouch_local.x, crouch_local.z))

		# A torch in the hand (the client sets the meta `torch_in_hand` each frame) uses Dave's crouched torch walks; backwards has none.
		if bool(avatar.get_meta("torch_in_hand", false)) and crouch_clip != "crouch_walk_back" and player.has_animation(crouch_clip + "_torch"):
			return crouch_clip + "_torch"

		return crouch_clip

	if player == null or not player.has_animation("jump"):
		return choose_clip(stance, pace, current, carrying)

	var panic_t: float = maxf(float(avatar.get_meta("panic_t", 0.0)) - delta, 0.0)
	avatar.set_meta("panic_t", panic_t)

	if panic_t > 0.0 and player.has_animation("panic_run"):
		return "panic_run"

	var air_t: float = float(avatar.get_meta("air_t", 0.0))
	var land_t: float = maxf(float(avatar.get_meta("land_t", 0.0)) - delta, 0.0)

	if on_floor:
		if air_t >= LAND_AFTER and stance == StanceScript.STAND:
			land_t = LAND_HOLD

		air_t = 0.0
	else:
		air_t += delta

	avatar.set_meta("air_t", air_t)
	avatar.set_meta("land_t", land_t)

	if land_t > 0.0 and stance == StanceScript.STAND and not carrying:
		return "land"

	# The Dynasty body has the air clips but no walk_back or strafe clips: standing on the floor it gets the plain clip.
	if dynasty and (on_floor or stance != StanceScript.STAND):
		return choose_clip(stance, pace, current, carrying)

	var local: Vector3 = basis.inverse() * velocity
	return choose_clip_moving(stance, Vector2(local.x, local.z), velocity.y, air_t > AIR_DELAY, current, carrying)


# The state hooks of the Dynasty body (docs/DYNASTY_BODY.md): swimming, drinking, picking up, sitting down, standing up and waking, each a clip the game asks for
# when its state says so. `ctx` is {swimming, asleep, stance (what choose_clip sees), drink_stamp, pick_stamp (msec of the latest drink and pick-up; 0 = never)}.
# Returns the clip to play instead of the usual one, "" for none. A body without these clips (the generated body, the old ragdoll) always gets "". The one-shots
# play for the clip's own length; swimming holds for as long as it lasts. State between frames lives in meta on the avatar.
const HOOK_CLIPS := ["swim", "swim_idle", "drink", "pick_up", "sit_down", "stand_up", "wake_up"]


static func hook_clip(avatar, ctx: Dictionary, pace: float, delta: float) -> String:
	if avatar == null:
		return ""

	var player: AnimationPlayer = avatar.get("animation_player") as AnimationPlayer

	if player == null or not HOOK_CLIPS.all(func(name): return player.has_animation(name)):
		return ""

	var left: float = maxf(float(avatar.get_meta("hook_t", 0.0)) - delta, 0.0)
	var held: String = str(avatar.get_meta("hook_clip", ""))
	var stance: int = int(ctx.get("stance", StanceScript.STAND))
	var seen: Dictionary = avatar.get_meta("hook_seen", {"stance": stance, "asleep": bool(ctx.get("asleep", false)), "drink": int(ctx.get("drink_stamp", 0)), "pick": int(ctx.get("pick_stamp", 0))})
	var start: String = ""

	# The latest event wins; each is noticed once, when its state changes.
	if bool(seen["asleep"]) and not bool(ctx.get("asleep", false)):
		start = "wake_up"
	elif int(seen["stance"]) == StanceScript.STAND and stance == StanceScript.SIT:
		start = "sit_down"
	elif int(seen["stance"]) == StanceScript.SIT and stance == StanceScript.STAND:
		start = "stand_up"

	if int(ctx.get("drink_stamp", 0)) != int(seen["drink"]) and int(ctx.get("drink_stamp", 0)) > 0:
		start = "drink"
	elif int(ctx.get("pick_stamp", 0)) != int(seen["pick"]) and int(ctx.get("pick_stamp", 0)) > 0 and start == "":
		start = "pick_up"

	avatar.set_meta("hook_seen", {"stance": stance, "asleep": bool(ctx.get("asleep", false)), "drink": int(ctx.get("drink_stamp", 0)), "pick": int(ctx.get("pick_stamp", 0))})

	if bool(ctx.get("swimming", false)):
		avatar.set_meta("hook_t", 0.0)
		avatar.set_meta("hook_clip", "")
		return "swim" if pace > WALK_MIN_PACE * 0.5 else "swim_idle"

	# A one-shot only starts standing or sitting still enough to show it: walking on, the pick-up and the drink are skipped (a sweep would never let the body walk).
	if start != "" and (start != "pick_up" or pace < JOG_FROM):
		held = start
		left = player.get_animation(start).length

	avatar.set_meta("hook_t", left)
	avatar.set_meta("hook_clip", held if left > 0.0 else "")
	return held if left > 0.0 else ""


# Which crouched walking clip for a velocity in the body's own frame (x right, y the world z, so forward is -y): back, sideways or forward.
static func crouch_walk_clip(velocity_local: Vector2) -> String:
	var pace: float = velocity_local.length()
	var forward: float = -velocity_local.y

	if forward < -0.5 * pace:
		return "crouch_walk_back"

	if absf(velocity_local.x) > 0.8 * pace:
		return "crouch_walk_right" if velocity_local.x > 0.0 else "crouch_walk_left"

	return "crouch_walk"


# The AnimationPlayer's speed scale that keeps the stride on the ground (natural speeds 1.4, 3.2 and 6.0 m/s, see ragdoll_body.gd).
static func speed_scale(clip: String, pace: float) -> float:
	if clip == "panic_run":
		return 1.0

	if clip == "walk_back":
		return clampf(pace / 1.1, 0.5, 1.5)

	if clip == "strafe_left" or clip == "strafe_right":
		return clampf(pace / 1.3, 0.5, 1.6)

	if clip.begins_with("crouch_walk"):   # includes the _torch variants
		return clampf(pace / 0.9, 0.5, 1.6)

	if clip == "carry_walk":
		return clampf(pace / 1.1, 0.6, 1.5)

	if clip == "walk":
		return clampf(pace / 1.4, 0.5, 1.7)

	if clip == "jog":
		return clampf(pace / 3.2, 0.8, 1.6)

	if clip == "run":
		return clampf(minf(pace, RUN_CLIP_PACE) / RUN_CLIP_PACE, 0.8, 1.0)   # BUG-011: running is faster than the clip, the cadence is not

	return 1.0


# Lean into a slope: uphill by the slope angle (up to 25 degrees), downhill a little back (Tyler's table). `local_normal` is the floor normal in the
# body's own frame. Returns the tilt in radians (0 when not on the floor, nearly still or idle).
static func slope_tilt(on_floor: bool, local_normal: Vector3, pace: float, clip: String) -> float:
	if not on_floor or pace <= WALK_MIN_PACE or clip == "idle":
		return 0.0

	var angle: float = atan2(local_normal.z, maxf(local_normal.y, 0.1))
	return clampf(angle, -0.1, 0.44) if angle > 0.0 else clampf(angle * 0.4, -0.1, 0.0)


# The clothes colours of the worn items: body colours the coat, legs the trousers, feet the shoes (stage-one clothing, art/MODEL_PLAN.md).
static func outfit_colors(worn_numbers: Array, table, base: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"coat": base.get("coat", COAT), "trousers": base.get("trousers", TROUSERS), "shoes": base.get("shoes", SHOES)}

	for number in worn_numbers:
		if int(number) == 0:
			continue

		var id: String = table.id_of(int(number))
		var slot: String = str(table.entry(id).get("slot", ""))
		var def: Dictionary = BasicLookScript.entry(id)

		if def.is_empty():
			continue

		var tint: Color = Color.html(str(def.get("color", "#808080")))

		if slot == "body":
			out["coat"] = tint
		elif slot == "legs":
			out["trousers"] = tint
		elif slot == "feet":
			out["shoes"] = tint

	return out


# Paints the avatar and hangs the worn pieces (Kathleen's worn_look builders through WornSync).
static func dress(avatar, items) -> void:
	if avatar == null or items == null:
		return

	# A generated body wears the clothes and skin the player chose in the creator unless an item is worn over them; the old body keeps the fixed colours.
	var genome: Variant = avatar.get("genome")
	var base: Dictionary = {}
	var skin: Color = SKIN

	if typeof(genome) == TYPE_DICTIONARY and (genome as Dictionary).has("tunic") and (genome as Dictionary).has("skin"):
		skin = (genome as Dictionary)["skin"]
		base = {"coat": (genome as Dictionary)["tunic"], "trousers": (genome as Dictionary)["trousers"], "shoes": (genome as Dictionary)["boots"]}

	var colors: Dictionary = outfit_colors(items.worn, items.table, base)
	avatar.dress(skin, colors["coat"], colors["trousers"], colors["shoes"])
	WornSync.apply(avatar, WornSync.ids_of(items.worn, items.table), false)   # the own avatar shows in third person only, so no first-person clipping (worn_look.gd maps the old bone names to the generated body)
