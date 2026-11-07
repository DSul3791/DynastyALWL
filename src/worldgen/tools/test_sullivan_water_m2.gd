extends SceneTree

# Sullivan water M2 gate: the ditch, dam, spillway and irrigation sandbox on the M1 grid (guide sections 3.6, 3.7, 13 and 21: "edit, bypass,
# overflow, withdrawal tests"). Made-up grids only, seconds, no tile, no rendering.
#   godot --headless --path . --script res://src/worldgen/tools/test_sullivan_water_m2.gd
#
# Tolerances, chosen before running: ledger residuals < 1e-9 of the water involved; "no flow" means exactly zero m^3 through the face.

const Grid := preload("res://src/sullivan_water/freshwater/water_grid_2d.gd")
const Field := preload("res://src/sullivan_water/freshwater/irrigation_field.gd")

const LEDGER_TOL := 1.0e-9
const LAND := 5.0   # bed height of ground the water must not reach

var failures: int = 0


func _init() -> void:
	var begun: int = Time.get_ticks_msec()
	print("engine %s" % Engine.get_version_info().get("string", "?"))
	_partial_opening()
	_bypass()
	_spillway()
	_uphill_canal()
	_canal_split()
	_field_gate()
	_drought()
	_field_runoff()
	print("%d failures, %d ms" % [failures, Time.get_ticks_msec() - begun])
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _e(x: float) -> String:
	return String.num_scientific(x)


func _volume_cols(grid, i_from: int, i_to: int) -> float:
	var sum: float = 0.0

	for j in range(grid.h):
		for i in range(i_from, i_to):
			sum += grid.volume[grid.index(i, j)]
	return sum


# A reservoir 2.5 m deep behind a 3 m dam across a 6 cell wide channel; columns 0 to 9 upstream, the dam on the east faces of column 9.
func _reservoir(rows: int):
	var grid = Grid.new(20, rows)

	for j in range(rows):
		grid.set_crest_east(9, j, 3.0)

		for i in range(10):
			grid.add_water(i, j, 2.5 * grid.area_m2, "reservoir")

	return grid


# Guide 3.6: "test partial openings". Opening 2 of the 6 dam faces lets water out more slowly than opening all 6, and nothing passes the
# faces that stay shut.
func _partial_opening() -> void:
	var part = _reservoir(6)
	var full = _reservoir(6)

	for j in [2, 3]:
		part.set_crest_east(9, j, Grid.OPEN)

	for j in range(6):
		full.set_crest_east(9, j, Grid.OPEN)

	var shut_leaked: bool = false

	for _t in range(300):
		part.step()
		full.step()

		for j in [0, 1, 4, 5]:
			shut_leaked = shut_leaked or part.flow_e[part.index(9, j)] != 0.0

	var out_part: float = _volume_cols(part, 10, 20)
	var out_full: float = _volume_cols(full, 10, 20)
	print("  partial: %.2f m3 out through 2 faces, %.2f m3 through 6, in 30 s" % [out_part, out_full])
	_check(out_part > 0.0 and out_part < out_full, "3.6: a 2 face gap releases water (%.1f m3), less than the open dam (%.1f m3)" % [out_part, out_full])
	_check(not shut_leaked, "3.6: no water through the 4 dam faces that stay shut")
	_check(absf(part.ledger_residual()) < LEDGER_TOL * part.total_volume(), "3.6: partial opening ledger balances (%s m3)" % _e(part.ledger_residual()))


# Guide 3.6: "side bypass routes". The dam spans the channel (rows 0 to 5) but the bank beside it (rows 6 and 7) is only 2 m high, under the
# 2.5 m reservoir: the water goes round the dam over the bank, and nothing crosses the dam itself.
func _bypass() -> void:
	var grid = Grid.new(20, 8)

	for j in range(8):
		for i in range(20):
			grid.set_bed(i, j, 2.0 if j >= 6 else 0.0)

	for j in range(6):
		grid.set_crest_east(9, j, 3.0)

		for i in range(10):
			grid.add_water(i, j, 2.5 * grid.area_m2, "reservoir")

	var through_dam: bool = false

	for _t in range(600):
		grid.step()

		for j in range(6):
			through_dam = through_dam or grid.flow_e[grid.index(9, j)] != 0.0

	var below: float = _volume_cols(grid, 10, 20)
	_check(below > 1.0, "3.6: water goes round the dam over the low bank (%.2f m3 downstream)" % below)
	_check(not through_dam, "3.6: none of it crossed the dam's own faces")


# A spillway: the dam is 3 m high except a 2 m notch in row 5. A spring keeps feeding the reservoir and an outlet drains the river below.
# The reservoir holds near the notch, under the main crest, and all the water leaves through the notch.
func _spillway() -> void:
	var grid = Grid.new(20, 6)

	for j in range(6):
		grid.set_crest_east(9, j, 2.0 if j == 5 else 3.0)

	grid.add_spring(0, 2, 2.0, "spring")   # 240 m2 of reservoir reaches the 2 m notch after about 240 s
	grid.add_sink(19, 2, 5.0, "outlet")
	var over_main: bool = false

	for _t in range(6000):
		grid.step()

		for j in range(5):
			over_main = over_main or grid.flow_e[grid.index(9, j)] != 0.0

	var level: float = grid.surface(5, 2)
	print("  spillway: reservoir %.3f m (notch 2.0, dam 3.0), outlet took %.1f m3 of %.1f" % [level, -float(grid.by_id.get("outlet", 0.0)), float(grid.by_id.get("spring", 0.0))])
	_check(level > 2.0 and level < 2.5, "3.6: the reservoir holds just over the 2 m spillway (%.3f m)" % level)
	_check(not over_main, "3.6: nothing went over the 3 m main crest")
	_check(-float(grid.by_id.get("outlet", 0.0)) > 0.4 * float(grid.by_id.get("spring", 0.0)), "3.6: once full, the spillway passes the spring's water on downstream")


# Guide 3.7: a canal only fills where it is below the supply surface. A river 1 m deep (bed 0); a canal leaves it northward, first at bed 0.5
# (fills), then over a 1.2 m rise (above the river surface: stays dry), and past it a low 0.8 m stretch that also stays dry because the rise
# blocks it (guide 3.9: a ditch lower than the source stays dry behind a ridge).
func _uphill_canal() -> void:
	var grid = Grid.new(12, 6)
	var canal_beds: Array = [0.5, 1.2, 0.8, 0.8]

	for j in range(6):
		for i in range(12):
			var y: float = LAND

			if j >= 4:
				y = 0.0
			elif i == 5:
				y = canal_beds[3 - j]

			grid.set_bed(i, j, y)

	for j in range(4, 6):
		for i in range(12):
			grid.add_water(i, j, 1.0 * grid.area_m2, "river")

	for _t in range(1500):
		grid.step()

	_check(grid.depth(5, 3) > 0.3, "3.7: the canal stretch below the river surface fills (%.3f m deep)" % grid.depth(5, 3))
	_check(grid.volume[grid.index(5, 2)] == 0.0, "3.7: the canal over the 1.2 m rise stays dry (river surface %.3f m)" % grid.surface(3, 5))
	_check(grid.volume[grid.index(5, 1)] == 0.0 and grid.volume[grid.index(5, 0)] == 0.0, "3.7: the low stretch behind the rise stays dry")


# Guide 3.7: "canals that split" and "a shutoff gate". A spring feeds a trunk canal that splits into a north and a south branch, each ending
# in an outlet. Mirror-equal branches share the water evenly; closing a gate on the south branch sends it all north.
func _canal_split() -> void:
	var grid = Grid.new(15, 7)

	for j in range(7):
		for i in range(15):
			grid.set_bed(i, j, 0.0 if (j == 3 and i <= 7) or i == 7 else LAND)

	grid.add_spring(0, 3, 1.0, "spring")
	grid.add_sink(7, 0, 5.0, "north")
	grid.add_sink(7, 6, 5.0, "south")

	for _t in range(3000):
		grid.step()

	var north: float = -float(grid.by_id["north"])
	var south: float = -float(grid.by_id["south"])
	print("  split: north %.3f m3, south %.3f m3, spring %.3f m3" % [north, south, float(grid.by_id["spring"])])
	_check(north > 0.0 and absf(north - south) < 0.01 * (north + south), "3.7: two equal branches share the water evenly (north %.2f, south %.2f m3)" % [north, south])

	grid.set_crest_south(7, 3, Grid.WALL)   # the gate: the face between the trunk's end and the south branch

	for _t in range(3000):
		grid.step()

	var north_more: float = -float(grid.by_id["north"]) - north
	var south_more: float = -float(grid.by_id["south"]) - south
	print("  gate shut: north %.3f m3 more, south %.3f m3 more" % [north_more, south_more])
	_check(south_more < 0.05 * north_more, "3.7: with the south gate shut the water goes north (north +%.2f, south +%.3f m3: only what was already in the branch)" % [north_more, south_more])
	_check(absf(grid.ledger_residual()) < LEDGER_TOL * float(grid.by_id["spring"]), "3.7: split ledger balances (%s m3)" % _e(grid.ledger_residual()))


# A field's own gate: shut, it takes nothing; open, it draws from the canal.
func _field_gate() -> void:
	var grid = Grid.new(4, 1)
	grid.fill_to_level(0.5)
	var field = Field.new(grid, Vector2i(3, 0), Vector2i(0, 0), "field")
	field.gate_open = false

	for _t in range(50):
		grid.step()
		field.step(grid.dt)

	_check(field.drawn_m3 == 0.0, "3.7: a field with its gate shut draws nothing")
	field.gate_open = true

	for _t in range(50):
		grid.step()
		field.step(grid.dt)

	_check(field.drawn_m3 > 0.2, "3.7: with the gate open it draws from the canal (%.3f m3 in 5 s)" % field.drawn_m3)


# Guide 3.7 and 19: "nearly dry canals" and F13. A canal holding 0.2 m3 and a field asking 0.05 m3/s for 20 s (1 m3): the field gets only
# what is there, never more; the canal never goes negative; the water only moves from canal to soil.
func _drought() -> void:
	var grid = Grid.new(6, 1)
	grid.add_water(0, 0, 0.2, "last water")
	var field = Field.new(grid, Vector2i(5, 0), Vector2i(5, 0), "field")
	var short: bool = false

	for _t in range(200):
		grid.step()
		field.step(grid.dt)
		short = short or field.last_granted_m3 < field.last_requested_m3

	var world: float = grid.total_volume() + field.soil_m3
	_check(field.drawn_m3 <= 0.2 + 1.0e-12 and grid.min_volume() >= 0.0, "F13: the field drew %.4f m3 of the 0.2 there; no cell negative" % field.drawn_m3)
	_check(short, "F13: the field was granted less than it asked once the canal ran low")
	_check(absf(world - 0.2) < 1.0e-12, "F13: canal plus soil still hold the 0.2 m3 (%.12f)" % world)
	_check(absf(field.ledger_residual()) < 1.0e-12 and absf(grid.ledger_residual()) < 1.0e-12, "F13: field and grid ledgers balance")


# A small field fills up: what the soil cannot hold goes back to the grid as runoff, counted, so no water is made or lost.
func _field_runoff() -> void:
	var grid = Grid.new(6, 1)
	grid.fill_to_level(1.0)
	var start: float = grid.total_volume()
	var field = Field.new(grid, Vector2i(5, 0), Vector2i(0, 0), "field")
	field.capacity_m3 = 0.5
	field.intake_m3_per_s = 0.1
	field.use_m3_per_s = 0.01

	for _t in range(400):
		grid.step()
		field.step(grid.dt)

	var world: float = grid.total_volume() + field.soil_m3 + field.used_m3
	_check(field.returned_m3 > 0.0 and field.soil_m3 <= field.capacity_m3, "3.7: the full field sends its extra water back as runoff (%.3f m3), soil at %.0f%%" % [field.returned_m3, 100.0 * field.wetness()])
	_check(absf(world - start) < LEDGER_TOL * start, "3.7: grid plus soil plus what the crops drank equals the start (%.9f / %.9f m3)" % [world, start])
