class_name LogLook
extends RefCounted
# The colour of a species log: the bark of the tree it was cut from (the tints in src/flora/tree_builder.gd), so an oak log
# looks like oak and a birch log like white birch (Dave 2026-10-23).

const TreeBuilder := preload("res://src/flora/tree_builder.gd")
const PLAIN := Color(0.33, 0.24, 0.16)

const SPECIES := {
	"oak": TreeBuilder.BARK_TINT_OAK, "beech": TreeBuilder.BARK_TINT_BEECH, "birch": TreeBuilder.BARK_TINT_BIRCH,
	"scots_pine": TreeBuilder.BARK_TINT_PINE_LOW, "spruce": TreeBuilder.BARK_TINT_SOFT, "alder": TreeBuilder.BARK_TINT_ALDER,
	"willow": TreeBuilder.BARK_TINT_WILLOW, "coconut_palm": TreeBuilder.BARK_TINT_PALM, "tropical_hardwood": Color(0.36, 0.26, 0.19),
	"acacia": Color(0.42, 0.33, 0.24), "mangrove": Color(0.34, 0.27, 0.20), "rowan": TreeBuilder.BARK_TINT_ROWAN,
	"wild_apple": TreeBuilder.BARK_TINT_APPLE, "wild_pear": TreeBuilder.BARK_TINT_PEAR, "wild_cherry": TreeBuilder.BARK_TINT_CHERRY,
	"sweet_chestnut": TreeBuilder.BARK_TINT_CHESTNUT, "walnut": TreeBuilder.BARK_TINT_WALNUT, "date_palm": TreeBuilder.BARK_TINT_PALM,
	"mirrorbark": TreeBuilder.CHROME_TINT, "wardpine": TreeBuilder.BARK_TINT_WARDPINE, "hearthwood": TreeBuilder.BARK_TINT_HEARTHWOOD,
	"everember": TreeBuilder.BARK_TINT_EVEREMBER, "witness_tree": TreeBuilder.BARK_TINT_WITNESS, "balsam_fir": TreeBuilder.BARK_TINT_FIR,
	"maple": TreeBuilder.BARK_TINT_MAPLE,
}


# "log_oak" gives the oak bark colour; anything else (the plain "log") the old brown.
static func color_of(item_id: String) -> Color:
	if not item_id.begins_with("log_"):
		return PLAIN

	return SPECIES.get(item_id.substr(4), PLAIN)
