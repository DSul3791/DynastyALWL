extends RefCounted

# Which rain sounds play, for how much precipitation and what water stands (BUGLIST-001 BUG-004). Pure rules; weather_sounds.gd keeps the eased
# levels and the players, rain_splashes.gd the single drops. Dave: the audio and the sky must agree: no puddle or rain sound before the rain is
# really falling; early drops are leaf and branch ticks, then the soil and rock under the player as the rain grows; puddle and standing-water
# sounds only where water stands; and nothing here adds a fluid simulation (the standing water is Puddles' drawn pools, the ponds are the water zone).

const AUDIBLE_FROM := 0.15      # the world's rain (Weather.state "rain") from which any rain sound starts: the sky is overcast by then (weather_look wet_sky) and the streaks show
const SOUND_FROM := 0.1         # the same in the sound stage's own eased level (weather_sounds.rain): a drizzle at AUDIBLE_FROM eases to 0.11, so the bed is fully on by then
const SOUND_ONSET := 0.03       # below this eased level no rain layer plays at all; between the two it fades in (the natural approach)
const LEAF_UNTIL := 0.5         # the eased rain at which the drops are all on the ground, not leaves
const LEAF_OPEN := 0.6          # the leaf patter in the open at the very start of the rain, against the full under-trees patter
const PUDDLE_FROM := 0.2        # standing water at the feet (Puddles.water_at) from which a puddle sound plays
const GROUND_BED_KEEP := {"stone": 0.35, "mud": 0.4, "litter": 0.5, "snow": 0.2}   # how much of the open bed stays when that ground has its own loop


# Does the world's rain start the rain sounds? (weather_sounds.apply_state)
static func state_audible(rain_state: float) -> bool:
	return rain_state > AUDIBLE_FROM


# 0 below SOUND_ONSET, 1 from SOUND_FROM: every rain layer is scaled by it.
static func onset(rain: float) -> float:
	return smoothstep(SOUND_ONSET, SOUND_FROM, rain)


# The share of drops that strike leaves and branches: all of them at the first drops, none once the rain is steady.
static func leaf_share(rain: float) -> float:
	return 1.0 - smoothstep(SOUND_FROM, LEAF_UNTIL, rain)


# The loop levels (0..1, by loop name) for this rain.
#   rain       the sound stage's eased rain level 0..1
#   cover      0 open .. 1 under a canopy;  roof 0..1 under a roof (a share of cover)
#   water      the water zone's weight (a pond or river within earshot)
#   ground     {stone, mud, litter, snow} -> weight 0..1 of what the rain falls on under the player (eased by the caller)
#   standing   0..1 water standing at the feet: "mud" is the wet, puddly bed, so it needs it
static func layers(rain: float, cover: float, roof: float, water: float, ground: Dictionary, standing: float) -> Dictionary:
	var out: Dictionary = {}
	var heard: float = onset(rain)
	var heavy: float = smoothstep(0.4, 0.9, rain)
	var light: float = minf(rain * 2.0, 1.0) * (1.0 - 0.6 * heavy)
	var wide: float = minf(rain * 1.6, 1.0)
	var leaves: float = leaf_share(rain)
	var keep: float = 1.0
	var open: float = 1.0 - cover
	var under_roof: float = minf(roof, cover)

	for key in ground:
		var share: float = float(ground[key])

		if key == "mud":
			share *= clampf(standing / PUDDLE_FROM, 0.0, 1.0)         # no standing water, no puddly bed: the loose ground ticks as soil

		if key != "snow":
			share *= 1.0 - leaves                                       # the soil and rock bed grows in as the leaves give way

		keep -= (1.0 - float(GROUND_BED_KEEP[key])) * share
		out["rain_" + key] = wide * share * open * heard

	out["rain_light"] = light * (1.0 - 0.7 * cover) * (1.0 - under_roof) * keep * heard
	out["rain_heavy"] = heavy * (1.0 - 0.7 * cover) * (1.0 - under_roof) * keep * heard
	out["rain_leaves"] = (wide * (cover - under_roof) + LEAF_OPEN * wide * leaves * open) * heard
	out["rain_woodroof_light"] = light * under_roof * heard
	out["rain_woodroof_heavy"] = heavy * under_roof * heard
	out["rain_water"] = wide * water * heard
	return out


# The surface one drop near the player lands on, "" for none. `ground` is what the player stands on (rain_splashes: stone, gravel, grass, dirt, sand, mud, litter);
# `standing` the water at the feet 0..1; `pond` true when the drop falls on open water; `roll` a random 0..1.
static func drop_surface(rain: float, ground: String, standing: float, pond: bool, roll: float) -> String:
	if ground == "" or rain < SOUND_FROM:
		return ""                                                       # snow lies, or the rain has not really begun

	if pond:
		return "water"                                                  # water that is there answers the very first drops

	if roll < leaf_share(rain):
		return "litter"                                                 # a leaf or branch tick

	if ground == "mud" and standing < PUDDLE_FROM:
		return "dirt"                                                   # wet loose ground with no pool is still a soil pat, not a plop

	return ground
