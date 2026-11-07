extends RefCounted

# Sullivan water, milestone M3: the one door for ground edits that touch water (Sonny, 7 Nov 2026). Guide sections 4.2, 17 and 25.
#
# Every dig, fill, dam or levee that can change water goes through edit_sphere(). In order:
#   A. PRECHECK: the edit box plus a halo of one water cell must be loaded and editable (source.is_loaded). If not, the edit is refused
#      with REJECTED_UNLOADED and nothing changes (test F14).
#      The water volumes in the affected cells are recorded.
#   B. EDIT: the source applies the sphere (source.edit_sphere). Only after it reports success does terrain_revision rise.
#   C. RECONCILE: the adapter re-reads the affected cells and faces (beds and crests) from the edited ground. Every cell keeps its cubic
#      metres: dug ground does not fill from nowhere (F06), raised ground lifts the water's surface and the flow spreads it (F07, guide 25.2).
#      If the edit roofed over a wet cell (it became STACKED), this one-surface grid cannot hold that water. The edit is undone when the
#      source can undo (REJECTED_UNSUPPORTED_GEOMETRY). Otherwise the region is frozen with a blocking error, never silently committed.
#   D. COMMIT: water_revision rises with terrain_revision, and every listener hears affected_region_changed(cells box, revision).
#
# The edit runs between grid ticks, so the solver never sees half-edited geometry. That is the guide's tick barrier: the caller must not call
# grid.step() from another thread while edit_sphere runs.
#
# The source also needs edit_sphere(center: Vector3, radius: float, add: bool) -> bool, and may have undo_last() -> bool.

const COMMITTED := "COMMITTED"
const REJECTED_UNLOADED := "REJECTED_UNLOADED"
const REJECTED_EDIT_FAILED := "REJECTED_EDIT_FAILED"
const REJECTED_UNSUPPORTED_GEOMETRY := "REJECTED_UNSUPPORTED_GEOMETRY"
const FROZEN := "FROZEN"

var grid
var adapter
var source
var terrain_revision: int = 0
var water_revision: int = 0
var frozen: bool = false            # a failed reconcile that could not be undone: no more edits until a person looks
var frozen_reason: String = ""
var listeners: Array[Callable] = []  # each is called as listener.call(cells: Rect2i, revision: int)


func _init(p_grid, p_adapter) -> void:
	grid = p_grid
	adapter = p_adapter
	source = p_adapter.source


# Reads the whole grid from the ground once, before the water starts. Returns the adapter's report.
func build() -> Dictionary:
	return adapter.extract(grid, 0, 0, grid.w - 1, grid.h - 1)


# One sphere edit in world space. `add` true raises ground (a fill, a dam), false removes it (a dig, a ditch).
# Returns {"result": one of the constants above, "reason": String, "revision": int, "cells": Rect2i}.
func edit_sphere(center: Vector3, radius: float, add: bool) -> Dictionary:
	if frozen:
		return _answer(FROZEN, frozen_reason, Rect2i())

	if radius <= 0.0:
		return _answer(REJECTED_EDIT_FAILED, "radius must be above zero", Rect2i())

	# A. Precheck: the cells the sphere touches, plus one cell of halo all round.
	var lo: Vector2 = (Vector2(center.x, center.z) - Vector2(radius, radius) - adapter.origin) / grid.cell_m
	var hi: Vector2 = (Vector2(center.x, center.z) + Vector2(radius, radius) - adapter.origin) / grid.cell_m
	var i0: int = floori(lo.x) - 1
	var j0: int = floori(lo.y) - 1
	var i1: int = floori(hi.x) + 1
	var j1: int = floori(hi.y) + 1
	var cells: Rect2i = Rect2i(i0, j0, i1 - i0 + 1, j1 - j0 + 1)
	var box: AABB = adapter.cells_box(i0, j0, i1, j1)
	box = box.merge(AABB(center - Vector3.ONE * radius, Vector3.ONE * 2.0 * radius))

	if not source.is_loaded(box):
		return _answer(REJECTED_UNLOADED, "the edit or its one-cell halo reaches ground that is not loaded", cells)

	var before: float = grid.total_volume()

	# B. Edit.
	if not source.edit_sphere(center, radius, add):
		return _answer(REJECTED_EDIT_FAILED, "the ground refused the edit", cells)

	terrain_revision += 1

	# C. Reconcile.
	var report: Dictionary = adapter.extract(grid, i0, j0, i1, j1)

	if not bool(report["ok"]) or _roofed_wet_cell(i0, j0, i1, j1):
		var why: String = String(report["reason"]) if not bool(report["ok"]) else "the edit roofs over standing water; the one-surface grid cannot hold it"

		if source.has_method("undo_last") and source.undo_last():
			terrain_revision += 1
			var back: Dictionary = adapter.extract(grid, i0, j0, i1, j1)

			if bool(back["ok"]):
				_tell(cells)
				return _answer(REJECTED_UNSUPPORTED_GEOMETRY, why + " (undone)", cells)

		frozen = true
		frozen_reason = why + " (could not be undone)"
		push_error("Sullivan water: " + frozen_reason)
		return _answer(FROZEN, frozen_reason, cells)

	# The volumes must be exactly as before: the edit moved ground, never water.
	if grid.total_volume() != before:
		frozen = true
		frozen_reason = "water changed during a ground edit (%.9f to %.9f m3)" % [before, grid.total_volume()]
		push_error("Sullivan water: " + frozen_reason)
		return _answer(FROZEN, frozen_reason, cells)

	# D. Commit.
	_tell(cells)
	return _answer(COMMITTED, "", cells)


func _roofed_wet_cell(i0: int, j0: int, i1: int, j1: int) -> bool:
	for j in range(maxi(j0, 0), mini(j1, grid.h - 1) + 1):
		for i in range(maxi(i0, 0), mini(i1, grid.w - 1) + 1):
			var k: int = grid.index(i, j)

			if adapter.classification[k] == adapter.STACKED and grid.volume[k] > 0.0:
				return true
	return false


func _tell(cells: Rect2i) -> void:
	water_revision = terrain_revision

	for listener in listeners:
		listener.call(cells, terrain_revision)


func _answer(result: String, reason: String, cells: Rect2i) -> Dictionary:
	return {"result": result, "reason": reason, "revision": terrain_revision, "cells": cells}
