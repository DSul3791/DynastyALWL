extends RefCounted

# Character attributes on the 0 to 100 scale (Dave 19 Nov 2026, data/items/attributes.json): a whole number that reads like a percentage. 50 is an average
# person. offset() turns a value into the signed pull that the luck, fitness, skill and trade maths are tuned in (-10 at 0, 0 at 50, +10 at 100; the old
# -10 to +10 scale), so those numbers keep their meaning. Every stored attribute goes through clamp_value(); old-scale values come in through from_old().

const PATH := "res://data/items/attributes.json"
const MIN := 0
const MAX := 100
const NEUTRAL := 50
const OLD_MAX := 10     # the old scale ran -OLD_MAX to +OLD_MAX
const PER_OLD_POINT := 5     # (MAX - NEUTRAL) / OLD_MAX: one old point is five here


static func load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func clamp_value(v: Variant) -> int:
	return clampi(int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) else NEUTRAL, MIN, MAX)


# The signed pull of a value, -10.0 at 0, 0 at 50, +10.0 at 100.
static func offset(v: float) -> float:
	return (clampf(v, MIN, MAX) - NEUTRAL) / float(PER_OLD_POINT)


# A value saved on the old -10 to +10 scale, on this one (old 0 is 50, +10 is 100).
static func from_old(old: Variant) -> int:
	var o: float = float(old) if typeof(old) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(old)) else 0.0
	return clamp_value(int(round(NEUTRAL + o * PER_OLD_POINT)))


# A new character's attributes (attributes.json "rolled"), each from roll_bands, or from player_bands for that attribute when `player` is true (a
# player's fitness starts in the middle range; an NPC's may land anywhere). Returns {name: value}.
static func roll_character(rng: RandomNumberGenerator, cfg: Dictionary, player: bool) -> Dictionary:
	var out: Dictionary = {}
	var names: Variant = cfg.get("rolled", [])
	var own: Variant = cfg.get("player_bands", {})

	for name in (names if typeof(names) == TYPE_ARRAY else []):
		var bands: Variant = cfg.get("roll_bands", [])

		if player and typeof(own) == TYPE_DICTIONARY and (own as Dictionary).has(name):
			bands = own[name]

		out[str(name)] = roll(rng, bands)

	return out


# The graded roll: a band ({from, to, weight}) picked by weight, then a whole number uniformly inside it. `rng` is the caller's stream. Bad or empty
# bands give NEUTRAL.
static func roll(rng: RandomNumberGenerator, bands_in: Variant) -> int:
	var bands: Array = []

	for b in (bands_in if typeof(bands_in) == TYPE_ARRAY else []):
		if typeof(b) == TYPE_DICTIONARY:
			bands.append(b)

	var total: float = 0.0

	for b in bands:
		total += maxf(float(b.get("weight", 0)), 0.0)

	if total <= 0.0:
		return NEUTRAL

	var pick: float = rng.randf() * total   # luck-exempt: the creation roll itself
	var u: float = rng.randf()   # luck-exempt: the creation roll itself
	var chosen: Dictionary = {}

	for b in bands:
		var w: float = maxf(float(b.get("weight", 0)), 0.0)

		if w <= 0.0:
			continue

		chosen = b     # the last band with weight catches a pick at the very top (rounding)

		if pick < w:
			break

		pick -= w

	var lo: int = clamp_value(chosen.get("from", MIN))
	var hi: int = maxi(clamp_value(chosen.get("to", MAX)), lo)
	return clampi(lo + int(floor(u * float(hi - lo + 1))), lo, hi)
