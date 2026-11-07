class_name WaterGrid2D
extends RefCounted
## Single-region, closed-boundary, conservative surface-water prototype.
## Coordinates: x/z horizontal, y elevation. One cell stores cubic metres.
## This is NOT a full shallow-water momentum solver.

const G: float = 9.81
const DRY_EPS: float = 0.0000001
const NO_CREST: float = -1.0e20

var width: int
var height: int
var cell_size: float
var area: float
var discharge_coefficient: float = 0.18 # Intentional game-tuning parameter.

var bed: PackedFloat64Array
var volume: PackedFloat64Array
var east_crest: PackedFloat64Array
var south_crest: PackedFloat64Array
var last_flow_x: PackedFloat64Array
var last_flow_z: PackedFloat64Array

func _init(w: int = 32, h: int = 32, spacing: float = 2.0) -> void:
    assert(w >= 2 and h >= 2 and spacing > 0.0)
    width = w
    height = h
    cell_size = spacing
    area = spacing * spacing
    var n := w * h
    bed.resize(n)
    volume.resize(n)
    east_crest.resize(n)
    south_crest.resize(n)
    last_flow_x.resize(n)
    last_flow_z.resize(n)
    bed.fill(0.0)
    volume.fill(0.0)
    east_crest.fill(NO_CREST)
    south_crest.fill(NO_CREST)
    last_flow_x.fill(0.0)
    last_flow_z.fill(0.0)

func index(x: int, z: int) -> int:
    assert(x >= 0 and x < width and z >= 0 and z < height)
    return z * width + x

func set_bed(x: int, z: int, elevation: float) -> void:
    bed[index(x, z)] = elevation
    # Retain the water volume on a terrain edit. Raised ground displaces water.

func set_east_crest(x: int, z: int, elevation: float) -> void:
    assert(x < width - 1)
    east_crest[index(x, z)] = elevation

func set_south_crest(x: int, z: int, elevation: float) -> void:
    assert(z < height - 1)
    south_crest[index(x, z)] = elevation

func add_water(x: int, z: int, cubic_metres: float) -> void:
    assert(cubic_metres >= 0.0)
    var i := index(x, z)
    volume[i] += cubic_metres

func remove_water(x: int, z: int, cubic_metres: float) -> float:
    assert(cubic_metres >= 0.0)
    var i := index(x, z)
    var taken := minf(volume[i], cubic_metres)
    volume[i] -= taken
    return taken

func surface(x: int, z: int) -> float:
    var i := index(x, z)
    return bed[i] + volume[i] / area

func depth(x: int, z: int) -> float:
    return volume[index(x, z)] / area

func total_volume() -> float:
    var result := 0.0
    for v in volume:
        result += v
    return result

func _candidate_transfer(a: int, b: int, crest: float, dt: float) -> float:
    var ha: float = bed[a] + volume[a] / area
    var hb: float = bed[b] + volume[b] / area
    var difference: float = ha - hb
    if absf(difference) < 0.000001:
        return 0.0
    var upstream: int = a if difference > 0.0 else b
    var sill: float = maxf(maxf(bed[a], bed[b]), crest)
    var available_depth: float = maxf(0.0, maxf(ha, hb) - sill)
    if available_depth <= 0.0:
        return 0.0
    # Simplified head-difference discharge: m * m * (m/s) * s = m^3.
    var proposed: float = discharge_coefficient * cell_size * available_depth * sqrt(2.0 * G * absf(difference)) * dt
    return minf(proposed, volume[upstream]) * signf(difference)

func step(dt: float) -> void:
    assert(dt > 0.0 and dt <= 0.25)
    var n: int = width * height
    var east := PackedFloat64Array()
    var south := PackedFloat64Array()
    var outgoing := PackedFloat64Array()
    var scale := PackedFloat64Array()
    var change := PackedFloat64Array()
    east.resize(n)
    south.resize(n)
    outgoing.resize(n)
    scale.resize(n)
    change.resize(n)
    east.fill(0.0)
    south.fill(0.0)
    outgoing.fill(0.0)
    change.fill(0.0)
    last_flow_x.fill(0.0)
    last_flow_z.fill(0.0)

    # PASS 1: read only old state; compute proposed face transfers.
    for z in range(height):
        for x in range(width):
            var i: int = index(x, z)
            if x + 1 < width:
                var j: int = i + 1
                var v: float = _candidate_transfer(i, j, east_crest[i], dt)
                east[i] = v
                outgoing[i if v > 0.0 else j] += absf(v)
            if z + 1 < height:
                var j: int = i + width
                var v: float = _candidate_transfer(i, j, south_crest[i], dt)
                south[i] = v
                outgoing[i if v > 0.0 else j] += absf(v)

    # PASS 2: limit ALL outgoing transfers collectively per source cell.
    for i in range(n):
        scale[i] = minf(1.0, volume[i] / outgoing[i]) if outgoing[i] > DRY_EPS else 1.0

    # PASS 3: settle every shared face exactly once, with paired +/- deltas.
    for z in range(height):
        for x in range(width):
            var i: int = index(x, z)
            if x + 1 < width:
                var j: int = i + 1
                var v: float = east[i]
                v *= scale[i if v > 0.0 else j]
                change[i] -= v
                change[j] += v
                last_flow_x[i] += v / dt
                last_flow_x[j] += v / dt
            if z + 1 < height:
                var j: int = i + width
                var v: float = south[i]
                v *= scale[i if v > 0.0 else j]
                change[i] -= v
                change[j] += v
                last_flow_z[i] += v / dt
                last_flow_z[j] += v / dt

    for i in range(n):
        volume[i] += change[i]
        # This should only correct roundoff. Log substantial negatives as bugs.
        if volume[i] < -0.000001:
            push_error("Negative water volume at cell %d: %.12f" % [i, volume[i]])
        volume[i] = maxf(0.0, volume[i])

func velocity(x: int, z: int) -> Vector3:
    var i := index(x, z)
    var d := maxf(depth(x, z), 0.02)
    # Two faces contribute to each interior cell; coarse velocity estimate.
    return Vector3(last_flow_x[i] / (2.0 * cell_size * d), 0.0,
                   last_flow_z[i] / (2.0 * cell_size * d))
