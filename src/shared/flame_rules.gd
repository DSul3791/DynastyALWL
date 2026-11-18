extends RefCounted

# Held flames and the wet (Dave, 4 Nov 2026): a torch goes out under water and in the open rain; a carried lantern (buildables plan B4) burns in the rain
# behind its horn panes but goes out under water. A torch (items.json "goes_out") stays the same item when it goes out (Dave 16 Nov 2026: "There should be no
# such thing as a doused torch"): its slot's instance data is marked "out" until it is lit again. A lantern names "doused_item", the dark lantern it becomes,
# whose row names "relit_item". "rain_douses": the rain puts it out too. The client watches its own hands (it knows the held slot) and asks the server (ACT_DOUSE).

const RAIN_DOUSE := 0.2        # rain strength that puts an open flame out: the server's RAIN_PUTS_OUT for open fires
const RAIN_GRACE_S := 5.0      # seconds in the open rain before a torch gives up: a shower you run through to cover keeps it

# The held torch's light, in one place so the large fire can be held to a multiple of it (BUG-002; docs/ai-team/missions/BUGLIST-001/environment-presentation.md):
# the main light reaches the item's light_m (items.json torch and improved_torch: 12 m) times TORCH_REACH_MULT with this omni attenuation, this energy with a flicker of this much
# each way; the hand light is the short warm one low on the stick.
# TORCH REACH EXPERIMENT (Dave 18 Nov 2026: "whatever it is now mark it as a starting point and then lets experiment by making it travel 50% further"). These two lines are the
# whole experiment; docs/design/TORCH_TREE_SAP.md "Torch light reach" has the numbers. STARTING POINT: TORCH_REACH_MULT 1.0 (12 m) and TORCH_LIGHT_ATTENUATION 1.0.
# Provisional TS-14: 1.5 (18 m) and 0.8, so the light the old torch gave at 8 m now reaches about 12 m; at 1 m it is unchanged (d^-attenuation is 1 there).
const TORCH_REACH_MULT := 1.5
const TORCH_LIGHT_ATTENUATION := 0.8
const TORCH_LIGHT_ENERGY := 2.0
const TORCH_LIGHT_FLICKER := 0.4
const TORCH_HAND_ENERGY := 0.7
const TORCH_HAND_RANGE_M := 1.6


# Why the flame of item `entry` goes out now: "water", "rain" or "" (it burns on). `rain_s` is how long it has been in the open rain.
static func douse_reason(entry: Dictionary, underwater: bool, rain: float, covered: bool, rain_s: float) -> String:
	if not can_go_out(entry):
		return ""

	if underwater:
		return "water"

	if bool(entry.get("rain_douses", false)) and in_rain(rain, covered) and rain_s >= RAIN_GRACE_S:
		return "rain"

	return ""


# Whether a burning flame of this row can be put out: a torch goes out in place ("goes_out"), a lantern becomes its "doused_item".
static func can_go_out(entry: Dictionary) -> bool:
	return bool(entry.get("goes_out", false)) or str(entry.get("doused_item", "")) != ""


# Whether the item in a slot (its row and instance data) is a flame that is out: a torch marked "out", or a dark lantern (it names "relit_item").
static func is_out(entry: Dictionary, item_inst: Dictionary) -> bool:
	return str(entry.get("relit_item", "")) != "" or (bool(entry.get("goes_out", false)) and bool(item_inst.get("out", false)))


# Why a torch cannot be lit now: "water" when the eye is under water, "rain" in open rain with nothing over you (a cave, a roof or a crown is cover), else "".
static func light_block(underwater: bool, rain: float, covered: bool) -> String:
	if underwater:
		return "water"

	return "rain" if in_rain(rain, covered) else ""


# Whether an open flame is out in rain strong enough to put it out.
static func in_rain(rain: float, covered: bool) -> bool:
	return rain >= RAIN_DOUSE and not covered


# The word a message uses for a held flame: "lantern" for a carried lantern (items.json "fuel": it burns a candle or lamp oil), else "torch". Either the
# burning row or the one put out (its "relit_item" row) may be passed.
static func flame_word(entry: Dictionary) -> String:
	return "lantern" if entry.has("fuel") or str(entry.get("tool_class", "")).begins_with("lantern") else "torch"


# A carried lantern (buildables plan B4, Steve's hotbar rule, 10 Nov 2026) burns only in the hand, and its fuel lasts the burning row's "burn_s"; the slot's
# wear counts the tenths of a second it has burned (as a torch's does). True when `lit_entry` is a lantern whose fuel is used up at `wear`: it stays dark until
# a candle or lamp oil (its "fuel") from the pack goes in. A torch never needs fuel: it burns down to nothing instead.
static func out_of_fuel(lit_entry: Dictionary, wear: int) -> bool:
	var burn_s: float = float(lit_entry.get("burn_s", 0.0))
	return lit_entry.has("fuel") and burn_s > 0.0 and float(wear) >= burn_s * 10.0
