class_name DrainageFlow
extends RefCounted

# Option B stage 2 (tech/TERRAIN_B_DESIGN.md): water gathered from the hillsides.
# Each cell sheds `runoff` (m3/s: rain plus snowmelt times the zone coefficient) to its receiver from
# DrainageFill, so water crosses lakes to their outlet; `discharge` is the total passing each cell.

var discharge: PackedFloat32Array = PackedFloat32Array()


func build(fill, runoff: PackedFloat32Array) -> void:
	discharge = runoff.duplicate()

	for k in range(fill.order.size() - 1, -1, -1):
		var index: int = fill.order[k]
		var next: int = fill.receiver[index]

		if next >= 0:
			discharge[next] += discharge[index]


# Cells whose discharge passes `threshold` (m3/s): the rivers and brooks the land itself produces.
func channel_cells(threshold: float) -> PackedByteArray:
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(discharge.size())

	for index in range(discharge.size()):
		mask[index] = 1 if discharge[index] >= threshold else 0

	return mask
