extends RefCounted

# Wade, swim, drown and current rules (Sonny, 31 Oct 2026, dynasty-water stage a). Pure functions of the water at a body: no state, so server and client agree.
# The current limit follows flood-safety practice: a standing adult is swept off their feet when depth x speed passes about 1.0 m^2/s (0.6 for a child or a slippery bed).

const WADE_FROM_M := 0.08         # ankle: a splash, no slowdown
const WAIST_M := 1.0              # deeper than this the feet leave the bed: swimming
const SWEEP_LIMIT := 1.0          # depth x speed in m^2/s
const BREATH_S := 25.0            # seconds a body can stay under (no skill)

enum Mode { DRY, WET, WADE, SWIM, UNDER }


# One look at the water around a body.
#   depth_m: water depth under the body;  speed: current in m/s;  body_h: height of the body in m;  diving: the player chose to go under
# Returns {mode, speed_mult, push (0 to 1 of the current's speed carried onto the body), breath (seconds of breath per second: negative drains), swept, harm_per_s}
static func state(depth_m: float, speed: float, traits, body_h: float = 1.8, diving: bool = false) -> Dictionary:
	var out: Dictionary = {"mode": Mode.DRY, "speed_mult": 1.0, "push": 0.0, "breath": 1.0, "swept": false, "harm_per_s": 0.0}

	if depth_m < 0.02:
		return out

	var heavy: float = clampf(1.0 + 0.5 * (traits.viscosity - 0.05), 1.0, 6.0)   # thick liquids drag harder
	out["harm_per_s"] = traits.harm_per_s * minf(1.0, depth_m / 0.3)

	if depth_m < WADE_FROM_M:
		out["mode"] = Mode.WET
		return out

	if depth_m < WAIST_M:
		out["mode"] = Mode.WADE
		out["speed_mult"] = clampf(1.0 - 0.55 * (depth_m / WAIST_M), 0.35, 1.0) / heavy
		var hazard: float = depth_m * speed

		if hazard > SWEEP_LIMIT:
			out["swept"] = true
			out["push"] = 0.8
		else:
			out["push"] = clampf(hazard / SWEEP_LIMIT, 0.0, 1.0) * 0.4

		return out

	# deep: the body floats (a denser liquid floats it higher), head above unless diving and the water is over the head
	var float_up: float = clampf(traits.density, 0.8, 2.0)
	var head_under_depth: float = body_h * 0.9 * (2.0 / (1.0 + float_up))
	var head_under: bool = diving and depth_m > head_under_depth

	out["mode"] = Mode.UNDER if head_under else Mode.SWIM
	out["speed_mult"] = (0.35 if head_under else 0.45) / heavy
	out["push"] = clampf(0.5 + 0.1 * speed, 0.0, 1.0)
	out["breath"] = -1.0 if head_under else 2.0
	return out


# Seconds of breath left after `seconds` in this state, from `breath_s` now (clamped 0 to BREATH_S); 0 means drowning.
static func breath_after(breath_s: float, st: Dictionary, seconds: float) -> float:
	return clampf(breath_s + float(st["breath"]) * seconds, 0.0, BREATH_S)
