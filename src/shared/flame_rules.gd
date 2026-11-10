extends RefCounted

# Held flames and the wet (Dave, 4 Nov 2026): a torch goes out under water and in the open rain; a carried lantern (buildables plan B4) burns in the rain
# behind its horn panes but goes out under water. items.json marks a flame with "doused_item" (what it becomes when put out) and "rain_douses"; the dead item names
# "relit_item", which a burning fire turns it back into. The client watches its own hands (it knows the held slot) and asks the server (ACT_DOUSE).

const RAIN_DOUSE := 0.2        # rain strength that puts an open flame out: the server's RAIN_PUTS_OUT for open fires
const RAIN_GRACE_S := 5.0      # seconds in the open rain before a torch gives up: a shower you run through to cover keeps it


# Why the flame of item `entry` goes out now: "water", "rain" or "" (it burns on). `rain_s` is how long it has been in the open rain.
static func douse_reason(entry: Dictionary, underwater: bool, rain: float, covered: bool, rain_s: float) -> String:
	if str(entry.get("doused_item", "")) == "":
		return ""

	if underwater:
		return "water"

	if bool(entry.get("rain_douses", false)) and in_rain(rain, covered) and rain_s >= RAIN_GRACE_S:
		return "rain"

	return ""


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
