extends RefCounted

# Where a log lies, as the segment the grass and flora pressing uses: [ax, az, bx, bz, radius at a, radius at b] (x, z in metres).
# Client look only. Dave 2 Nov 2026: grass came up through felled and loose logs. Two causes: a cut trunk is thicker at its cut end than
# the standing-tree taper (inventory_view._make_felled), so the pressed strip was too narrow there, and loose logs were not pressed at all.

const TAPER := 0.45          # a whole trunk's top is (1 - TAPER) of its butt radius; a shortened one is thicker (inventory_view._make_felled)
const MIN_LOOSE_R := 0.08    # never thinner than this, so a small log still presses its blades


# A felled trunk (world state 3) lies from the stump `at` along `yaw`. `extra` is the world row's extra: radius, length, orig_length.
static func trunk_segment(at: Vector3, extra: Dictionary) -> Array:
	var yaw: float = float(extra.get("yaw", 0.0))
	var length: float = float(extra.get("length", 8.0))
	var r: float = float(extra.get("radius", 0.3))
	var orig: float = maxf(float(extra.get("orig_length", length)), length)
	var r_end: float = r * (1.0 - TAPER * length / maxf(orig, 0.01))
	return [snappedf(at.x, 0.01), snappedf(at.z, 0.01), snappedf(at.x + sin(yaw) * length, 0.01), snappedf(at.z + cos(yaw) * length, 0.01), r, r_end]


# A loose log item (a drawn cylinder lying along its local x, centred on `at`): `axis` is that x axis in world space with its length
# scale (the node's basis x), `length` the log's own length, r_a and r_b the radii at the +x and -x ends.
static func loose_segment(at: Vector3, axis: Vector3, length: float, r_a: float, r_b: float) -> Array:
	var half: Vector2 = Vector2(axis.x, axis.z) * (length * 0.5)
	return [snappedf(at.x + half.x, 0.01), snappedf(at.z + half.y, 0.01), snappedf(at.x - half.x, 0.01), snappedf(at.z - half.y, 0.01), maxf(r_a, MIN_LOOSE_R), maxf(r_b, MIN_LOOSE_R)]


# A stump or a boulder: a round footprint, pressed the same way (a segment of no length).
static func round_segment(at: Vector3, radius: float) -> Array:
	var r: float = maxf(radius, MIN_LOOSE_R)
	return [snappedf(at.x, 0.01), snappedf(at.z, 0.01), snappedf(at.x, 0.01), snappedf(at.z, 0.01), r, r]
