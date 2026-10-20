extends RefCounted

# The sound mixer presets: one row per quality tier (0 Low, 1 Mid, 2 High; Ultra uses High), the
# single place where the audio budget of ARCHITECTURE_BUDGET.md section 9 is set. sound_stage.gd
# applies a row in set_quality() and every sound layer reads its limits from `stage.preset`.
#
#   voices          sounds playing at once, all layers; past it the farthest, quietest one-shots are cut first
#   memory_mb       loaded sound files (Ogg stays compressed; WAV is whole)
#   nature_calls    bird and frog calls and bird flushes playing at once
#   town_loops      town fire, hammering and crowd loops playing at once
#   creature_voices animal calls playing at once (a threat call always plays)
#   cave_rays       rays that measure how enclosed the player is
#   cave_reverb     reverb on the Foley and Nature buses inside caves
#   exposure_points ground samples on the 70 m ring that make hilltops windy and valleys calm
#   occlusion_rays  a ray per distant sound to muffle those behind hills
const NAMES := ["Low", "Mid", "High"]
const ROWS := [
	{"voices": 24, "memory_mb": 150, "nature_calls": 4, "town_loops": 3, "creature_voices": 2, "cave_rays": 4, "cave_reverb": false, "exposure_points": 4, "occlusion_rays": false},
	{"voices": 48, "memory_mb": 300, "nature_calls": 6, "town_loops": 5, "creature_voices": 3, "cave_rays": 8, "cave_reverb": true, "exposure_points": 8, "occlusion_rays": true},
	{"voices": 96, "memory_mb": 600, "nature_calls": 8, "town_loops": 8, "creature_voices": 4, "cave_rays": 8, "cave_reverb": true, "exposure_points": 8, "occlusion_rays": true},
]


static func row(tier: int) -> Dictionary:
	return ROWS[clampi(tier, 0, ROWS.size() - 1)]
