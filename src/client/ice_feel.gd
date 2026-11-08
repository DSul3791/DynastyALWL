extends RefCounted

# Ice walk feel (docs/design/ice_walk_feel.md, Kathleen 8 Nov 2026; always on since Dave's 8 Nov ruling), client only. Pure numbers: the band of the ice under the
# player from the collider's own cover (terrain_client ice_now, Ice.cover at 3 m), and what each band does to the steps, the sounds and the eye.

enum Band { OPEN, SKIM, FILM, THIN, THICK }
const BAND_NAMES := ["open", "skim", "film", "thin sheet", "thick sheet"]
const SKIM_FROM := 0.01        # 2 mm
const FILM_FROM := 0.125       # 2.5 cm: the look turns from black skim to grey film here too (frozen_water_look.md)
const BEARS_FROM := 0.5        # 10 cm: Ice.WALK_COVER, the collider
const THICK_FROM := 0.7        # 14 cm (judged)

# Cracks per step at walk, jog, run, and the extra chance on a hard landing; the share of cracks that also send a zing.
const CRACK_CHANCE := {Band.THIN: [0.08, 0.14, 0.22, 0.5], Band.THICK: [0.02, 0.04, 0.07, 0.2]}
const ZING_SHARE := {Band.THIN: 1.0 / 3.0, Band.THICK: 1.0 / 8.0}
const BOOM_SHARE_PEAK := 1.0 / 3.0    # a thick sheet's groan is a boom this often from 06:00 to 10:00 and 16:00 to 20:00
const BOOM_SHARE_OTHER := 0.1

# Footing on a bearing sheet: bare ice, and snow on it (ground_snow SNOW_GRIP and up).
const SNOW_GRIP := 0.5
const PACE_BARE := [1.0, 0.9, 0.8]    # walk, jog, run
const PACE_SNOW := [1.0, 0.95, 0.9]
const GRIP_BARE := 5.0                # per second: v eases toward the wanted velocity (a stop slides v / grip metres)
const GRIP_SNOW := 12.0
const STEP_BARE := 0.85
const STEP_SNOW := 0.95
const BOB_BARE := 0.6
const BOB_SNOW := 0.85
const WADE_SKIM := 0.9
const WADE_FILM := 0.7

# Cold shock (the first minute of the 1-10-1 rule).
const ICY_WATER_C := 4.0
const SHOCK_S := 60.0                 # real seconds of slower swimming
const SHOCK_SWIM := 0.75
const SHOCK_REARM_S := 300.0          # out of the water this long before it can fire again
const SHOCK_DIP_M := 0.05
const PLUNGE_DIP_M := 0.06

# Broken skim and film in the look (FrozenWater holes, client only).
const PATCH_SKIM_M := 0.4
const PATCH_FILM_M := 0.5
const PATCH_REFREEZE_H := 3.0
const MAX_PATCHES := 8


static func band_of(cover: float) -> int:
	if cover >= THICK_FROM:
		return Band.THICK

	if cover >= BEARS_FROM:
		return Band.THIN

	if cover >= FILM_FROM:
		return Band.FILM

	if cover >= SKIM_FROM:
		return Band.SKIM

	return Band.OPEN


static func bears(band: int) -> bool:
	return band == Band.THIN or band == Band.THICK


static func crack_chance(band: int, gait: int, hard: bool) -> float:
	if not CRACK_CHANCE.has(band):
		return 0.0

	var row: Array = CRACK_CHANCE[band]
	return minf(float(row[clampi(gait, 0, 2)]) + (float(row[3]) if hard else 0.0), 1.0)


static func zing_share(band: int) -> float:
	return float(ZING_SHARE.get(band, 0.0))


static func boom_share(band: int, hour: float) -> float:
	if band != Band.THICK:
		return 0.0

	return BOOM_SHARE_PEAK if (hour >= 6.0 and hour < 10.0) or (hour >= 16.0 and hour < 20.0) else BOOM_SHARE_OTHER


static func _snowy(snow: float) -> bool:
	return snow >= SNOW_GRIP


static func pace_mult(band: int, gait: int, snow: float) -> float:
	if not bears(band):
		return 1.0

	return float((PACE_SNOW if _snowy(snow) else PACE_BARE)[clampi(gait, 0, 2)])


static func grip_rate(band: int, snow: float) -> float:
	if not bears(band):
		return INF

	return GRIP_SNOW if _snowy(snow) else GRIP_BARE


static func step_scale(band: int, snow: float) -> float:
	if not bears(band):
		return 1.0

	return STEP_SNOW if _snowy(snow) else STEP_BARE


static func bob_scale(band: int, snow: float) -> float:
	if not bears(band):
		return 1.0

	return BOB_SNOW if _snowy(snow) else BOB_BARE


# The horizontal velocity after one frame on ice: eases toward `want` at `grip` per second (INF: at once, as everywhere else).
static func grip_step(current: Vector2, want: Vector2, grip: float, delta: float) -> Vector2:
	if is_inf(grip):
		return want

	return current + (want - current) * (1.0 - exp(-grip * delta))


static func wade_mult(band: int) -> float:
	if band == Band.SKIM:
		return WADE_SKIM

	if band == Band.FILM:
		return WADE_FILM

	return 1.0


# The water temperature the server's warmth uses for a swimmer (server_items, data/items/warmth.json), never under 1 C.
static func water_c(air_c: float, cfg: Dictionary) -> float:
	var base: float = float(cfg.get("water_base_c", 12.0))
	return maxf(base + float(cfg.get("water_follow", 0.7)) * (air_c - base), 1.0)


static func icy(water_temp_c: float, cover: float) -> bool:
	return cover >= SKIM_FROM or water_temp_c <= ICY_WATER_C


# The thaw moat in collider cells (8 m): the shore ring from thaw 0.2, two rings from 0.5.
static func moat_cells(thaw: float) -> int:
	if thaw >= 0.5:
		return 2

	if thaw >= 0.2:
		return 1

	return 0


# The cold shock: `state` {"left": seconds of shock left, "out": seconds out of the water}, `in_icy` true while swimming or deep in icy water,
# `in_water` true while in any water deeper than the knees. Returns true on the frame it starts (play the gasp, jolt the eye).
static func shock_step(state: Dictionary, delta: float, in_icy: bool, in_water: bool) -> bool:
	var left: float = maxf(float(state.get("left", 0.0)) - delta, 0.0)
	var out: float = float(state.get("out", SHOCK_REARM_S)) + delta if not in_water else 0.0
	var armed: bool = float(state.get("out", SHOCK_REARM_S)) >= SHOCK_REARM_S
	var starts: bool = in_icy and armed and float(state.get("left", 0.0)) <= 0.0
	state["left"] = SHOCK_S if starts else left
	state["out"] = out
	return starts


static func swim_mult(state: Dictionary) -> float:
	return SHOCK_SWIM if float(state.get("left", 0.0)) > 0.0 else 1.0


# A broken patch of skim or film at `feet` (FrozenWater hole form), or {} for other bands. It refreezes after PATCH_REFREEZE_H game hours.
static func patch_at(band: int, feet: Vector3, now_s: float) -> Dictionary:
	if band != Band.SKIM and band != Band.FILM:
		return {}

	return {"pos": feet, "until": now_s + PATCH_REFREEZE_H * 3600.0, "life_h": PATCH_REFREEZE_H, "radius": PATCH_SKIM_M if band == Band.SKIM else PATCH_FILM_M}


# Keeps the newest MAX_PATCHES patches that are still frozen-over-able (the oldest goes first); a patch closer than its radius to the new one is replaced.
static func add_patch(patches: Array, patch: Dictionary, now_s: float) -> Array:
	var out: Array = patches.filter(func(p): return float(p["until"]) > now_s and Vector3(p["pos"]).distance_to(patch["pos"]) > float(patch["radius"]))
	out.append(patch)

	while out.size() > MAX_PATCHES:
		out.remove_at(0)

	return out


static func log_line(band: int, event: String, sound_name: String, pace: float, grip: float) -> String:
	return "ice feel: band %s, %s (%s), pace x%.2f, grip %s" % [BAND_NAMES[band], event, sound_name, pace, "instant" if is_inf(grip) else "%.0f" % grip]
