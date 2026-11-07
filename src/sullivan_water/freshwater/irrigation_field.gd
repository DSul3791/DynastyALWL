extends RefCounted

# Sullivan water, milestone M2: a farm field that drinks from the water grid (Sonny, 7 Nov 2026). Guide sections 3.7, 19 and 26.3.
#
# A field stores SOIL MOISTURE, not a 3D volume of water (guide 3.7). Each tick it asks its intake cell for at most
# intake_m3_per_s * dt and gets only what the grid really grants (WaterGrid2D.remove_water): during a drought a field never assumes its
# request was met (guide 19). What it takes moves from the surface-water ledger to this field's soil ledger. Water the soil cannot hold goes
# back to the grid as runoff on the runoff cell (a named source). Crops use soil water through `use_m3_per_s`.
#
# The field never writes grid volume except through remove_water and add_water, so the grid ledger stays exact.
#
# Not here (later milestones): infiltration from rain, seepage between fields, and the crop growth that reads `wetness()`.

var grid
var intake: Vector2i                   # the canal cell the field draws from
var runoff_cell: Vector2i              # where the water the soil cannot hold goes back (usually a cell downslope of the field)
var id: String = "field"
var intake_m3_per_s: float = 0.05      # the most the field's channel or gate lets in
var capacity_m3: float = 10.0          # soil water the field can hold (area x root depth x water-holding share)
var use_m3_per_s: float = 0.0          # what the crops drink from the soil
var gate_open: bool = true             # a shutoff gate on the field's intake

var soil_m3: float = 0.0
var drawn_m3: float = 0.0              # taken from the grid, in total
var returned_m3: float = 0.0           # given back to the grid as runoff, in total
var used_m3: float = 0.0               # drunk by the crops, in total
var last_requested_m3: float = 0.0
var last_granted_m3: float = 0.0


func _init(p_grid, p_intake: Vector2i, p_runoff: Vector2i, p_id: String = "field") -> void:
	grid = p_grid
	intake = p_intake
	runoff_cell = p_runoff
	id = p_id


# One tick, run after the grid's step at the same fixed dt. Returns the m^3 really drawn.
func step(dt: float) -> float:
	var use: float = minf(use_m3_per_s * dt, soil_m3)
	soil_m3 -= use
	used_m3 += use

	last_requested_m3 = intake_m3_per_s * dt if gate_open else 0.0
	last_granted_m3 = 0.0

	if last_requested_m3 > 0.0:
		last_granted_m3 = grid.remove_water(intake.x, intake.y, last_requested_m3, id + " intake")

	drawn_m3 += last_granted_m3
	soil_m3 += last_granted_m3
	var excess: float = maxf(0.0, soil_m3 - capacity_m3)

	if excess > 0.0:
		soil_m3 -= excess
		returned_m3 += excess
		grid.add_water(runoff_cell.x, runoff_cell.y, excess, id + " runoff")

	return last_granted_m3


# 0 = dry soil, 1 = full.
func wetness() -> float:
	return soil_m3 / capacity_m3 if capacity_m3 > 0.0 else 0.0


# The field's own ledger: what it holds equals what it drew, less what it gave back and what the crops drank. Zero up to rounding.
func ledger_residual() -> float:
	return soil_m3 - (drawn_m3 - returned_m3 - used_m3)
