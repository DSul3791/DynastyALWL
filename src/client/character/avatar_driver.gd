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


# The AnimationPlayer's speed scale that keeps the stride on the ground (natural speeds 1.4, 3.2 and 6.0 m/s, see ragdoll_body.gd).
static func speed_scale(clip: String, pace: float) -> float:
	if clip == "carry_walk":
		return clampf(pace / 1.1, 0.6, 1.5)

	if clip == "walk":
		return clampf(pace / 1.4, 0.5, 1.7)

	if clip == "jog":
		return clampf(pace / 3.2, 0.8, 1.6)

	if clip == "run":
		return clampf(pace / 6.0, 0.8, 2.0)

	return 1.0


# Lean into a slope: uphill by the slope angle (up to 25 degrees), downhill a little back (Tyler's table). `local_normal` is the floor normal in the
# body's own frame. Returns the tilt in radians (0 when not on the floor, nearly still or idle).
static func slope_tilt(on_floor: bool, local_normal: Vector3, pace: float, clip: String) -> float:
	if not on_floor or pace <= WALK_MIN_PACE or clip == "idle":
		return 0.0

	var angle: float = atan2(local_normal.z, maxf(local_normal.y, 0.1))
	return clampf(angle, -0.1, 0.44) if angle > 0.0 else clampf(angle * 0.4, -0.1, 0.0)


# The clothes colours of the worn items: body colours the coat, legs the trousers, feet the shoes (stage-one clothing, art/MODEL_PLAN.md).
static func outfit_colors(worn_numbers: Array, table) -> Dictionary:
	var out: Dictionary = {"coat": COAT, "trousers": TROUSERS, "shoes": SHOES}

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

	var colors: Dictionary = outfit_colors(items.worn, items.table)
	avatar.dress(SKIN, colors["coat"], colors["trousers"], colors["shoes"])
	WornSync.apply(avatar, WornSync.ids_of(items.worn, items.table), false)   # the own avatar shows in third person only, so no first-person clipping
