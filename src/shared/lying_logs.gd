extends RefCounted

# Where a log lies, as the segment the grass and flora pressing uses: [ax, az, bx, bz, radius at a, radius at b] (x, z in metres).
# Client look only. Dave 2 Nov 2026: grass came up through felled and loose logs, so loose logs, stumps and boulders press it. A felled tree is
# its loose logs at once (16 Nov 2026), so there is no whole trunk to press.

const MIN_LOOSE_R := 0.08    # never thinner than this, so a small log still presses its blades


# A loose log item (a drawn cylinder lying along its local x, centred on `at`): `axis` is that x axis in world space with its length
# scale (the node's basis x), `length` the log's own length, r_a and r_b the radii at the +x and -x ends.
static func loose_segment(at: Vector3, axis: Vector3, length: float, r_a: float, r_b: float) -> Array:
	var half: Vector2 = Vector2(axis.x, axis.z) * (length * 0.5)
	return [snappedf(at.x + half.x, 0.01), snappedf(at.z + half.y, 0.01), snappedf(at.x - half.x, 0.01), snappedf(at.z - half.y, 0.01), maxf(r_a, MIN_LOOSE_R), maxf(r_b, MIN_LOOSE_R)]


# A stump or a boulder: a round footprint, pressed the same way (a segment of no length).
static func round_segment(at: Vector3, radius: float) -> Array:
	var r: float = maxf(radius, MIN_LOOSE_R)
	return [snappedf(at.x, 0.01), snappedf(at.z, 0.01), snappedf(at.x, 0.01), snappedf(at.z, 0.01), r, r]
