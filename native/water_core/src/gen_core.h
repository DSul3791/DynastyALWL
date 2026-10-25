// Hot loops of the tile generator in C++ (speed-up build, 25 Oct 2026). Every function does exactly what the GDScript it
// replaces does, in the same order and with the same double arithmetic, so tile files stay byte-identical (the GDScript
// stays as the fallback and as the test reference: src/worldgen/tools/test_gen_core.gd). Built with -fno-fast-math
// -ffp-contract=off (SConstruct), on Linux and Windows alike.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

class GenCore : public RefCounted {
	GDCLASS(GenCore, RefCounted)

public:
	// DrainageChannels._valleys: stamps the valley jobs, in order, into a copy of `cut`.
	// jobs_i: per job [cell index, reach in cells]. jobs_f: per job [floor_level, side_here, half_m, rim_m, strength, max_cut_m].
	PackedFloat32Array carve_valleys(const PackedFloat32Array &cut, const PackedFloat32Array &h, int64_t size, double cell_m, const PackedInt32Array &jobs_i, const PackedFloat64Array &jobs_f) const;

	// DrainageFill._flood: {"filled": PackedFloat32Array, "parent": PackedInt32Array, "order": PackedInt32Array}.
	Dictionary flood(const PackedFloat32Array &h, const PackedByteArray &sea, int64_t size) const;
	// DrainageFill._route: {"receiver": PackedInt32Array, "order": PackedInt32Array}.
	Dictionary route(const PackedFloat32Array &h, const PackedByteArray &sea, const PackedFloat32Array &filled, const PackedInt32Array &parent, int64_t size) const;

protected:
	static void _bind_methods();
};

} // namespace godot
