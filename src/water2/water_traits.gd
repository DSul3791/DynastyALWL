extends RefCounted

# The settable traits of one liquid (Sonny, 31 Oct 2026, dynasty-water stage a). Values come from water_kinds.json; any field may be overridden after `of`.
# Sim traits (change how it flows): density, viscosity, roughness, flow_rate, film_m. Look traits (never feed the sim): color, clarity_m, turbulence, wave_speed.
# Rule trait: harm_per_s (damage to a body in it).

const KINDS_PATH := "res://src/water2/water_kinds.json"

var kind: String = "fresh"
var color: Color = Color(0.12, 0.38, 0.42)
var clarity_m: float = 6.0
var density: float = 1.0
var viscosity: float = 0.05
var roughness: float = 0.03
var flow_rate: float = 1.0
var film_m: float = 0.004
var turbulence: float = 0.3
var wave_speed: float = 1.0
var harm_per_s: float = 0.0


static func of(kind_name: String):
	var t = load("res://src/water2/water_traits.gd").new()
	var table = JSON.parse_string(FileAccess.get_file_as_string(KINDS_PATH))
	var row: Dictionary = table.get(kind_name, table["fresh"])
	t.kind = kind_name if table.has(kind_name) else "fresh"
	var c: Array = row["color"]
	t.color = Color(c[0], c[1], c[2])

	for key in ["clarity_m", "density", "viscosity", "roughness", "flow_rate", "film_m", "turbulence", "wave_speed", "harm_per_s"]:
		t.set(key, float(row[key]))

	return t
