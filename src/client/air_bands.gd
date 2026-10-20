extends RefCounted

# Distance and cover dulling for big far sounds (client only): a waterfall, a fire or a thunder roll loses its high end
# the farther off it is and the more forest, hill, roof or cave wall lies between. Shared by bus, not by voice:
# each kind has up to three low-passed child buses ("Air_fall_1" ...), one LowPass effect each, and a voice is moved to
# the band its effective distance falls in. Moving to a band is a bus change, so the cost is the same with one fire or twenty.
#
# kinds: parent bus the bands send to, edges (effective metres where band 1, 2, 3 start), hz (the cutoff of each band).
# Effective distance = real distance x stretch, the stretch growing with the cover:
#   forest   +FOREST_STRETCH x forest share x how far (full at 80 m)
#   hill     +HILL_STRETCH when a ray from the head is blocked
#   roof     +ROOF_STRETCH x roofed share (standing under a roof) and +CAVE_STRETCH x cave enclosure
# A band is entered at its edge +15 % and left at its edge -15 %, so a voice at the boundary does not flip back and forth.

const KINDS := {
	"thunder": {"parent": "Weather", "edges": [600.0, 1800.0], "hz": [1600.0, 450.0]},
	"fall": {"parent": "Nature", "edges": [110.0, 260.0, 520.0], "hz": [6000.0, 3000.0, 1400.0]},
	"fire": {"parent": "Foley", "edges": [30.0, 70.0, 150.0], "hz": [7000.0, 3800.0, 2000.0]},
}
const HYSTERESIS := 0.15
const FOREST_STRETCH := 0.6
const FOREST_FULL_M := 80.0
const HILL_STRETCH := 1.2
const ROOF_STRETCH := 0.8
const CAVE_STRETCH := 1.5


static func stretch(distance_m: float, forest: float, hill: bool, roofed: float, enclosure: float) -> float:
	var s: float = 1.0 + FOREST_STRETCH * forest * clampf(distance_m / FOREST_FULL_M, 0.0, 1.0)
	s += HILL_STRETCH if hill else 0.0
	return s + ROOF_STRETCH * roofed + CAVE_STRETCH * enclosure


# The band (0 = plain parent bus) for an effective distance, given the band the voice is in now.
static func band_for(kind: String, effective_m: float, current: int) -> int:
	var edges: Array = KINDS[kind]["edges"]
	var target: int = 0

	for edge in edges:
		if effective_m >= float(edge):
			target += 1

	if target > current:
		return current if effective_m < float(edges[current]) * (1.0 + HYSTERESIS) else target

	if target < current:
		return current if effective_m >= float(edges[current - 1]) * (1.0 - HYSTERESIS) else target

	return current


# The bus name of a band, made on first use: a child of the kind's parent with one low-pass.
static func bus_for(kind: String, band: int) -> String:
	var parent: String = str(KINDS[kind]["parent"])

	if band <= 0:
		return parent

	var bus_name: String = "Air_%s_%d" % [kind, band]

	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, parent)
		var low: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
		low.cutoff_hz = float(KINDS[kind]["hz"][band - 1])
		AudioServer.add_bus_effect(index, low)

	return bus_name


# True for a band bus (shed priority and the mixer treat it as its parent).
static func parent_of(bus_name: String) -> String:
	if not bus_name.begins_with("Air_"):
		return bus_name

	var index: int = AudioServer.get_bus_index(bus_name)
	return AudioServer.get_bus_send(index) if index >= 0 else bus_name


static func remove_all() -> void:
	for kind in KINDS:
		for band in range(1, 4):
			var index: int = AudioServer.get_bus_index("Air_%s_%d" % [kind, band])

			if index >= 0:
				AudioServer.remove_bus(index)
