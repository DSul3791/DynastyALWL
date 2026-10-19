// The water simulation's inner loop in C++ (owner, 2026-10-19: "go ahead with moving the
// simulation core to c++"). The same method as src/water/water_sim.gd, which stays as the
// fallback and owns everything that is not hot (digging, spring placement, tools): the
// local inertial shallow-water method (Bates et al. 2010) with Manning friction.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>

#include <cstdint>
#include <vector>

namespace godot {

class WaterCore : public RefCounted {
	GDCLASS(WaterCore, RefCounted)

public:
	void setup(int64_t cells_per_side, double spacing, const PackedFloat32Array &ground_heights);
	void set_ground(int64_t k, double height);
	void add_water(int64_t k, double meters);
	void add_spring(int64_t k, double m3_per_s);
	void set_depth(const PackedFloat32Array &values);
	PackedFloat32Array get_depth() const;
	double depth_at(int64_t k) const;
	void wake_all_wet();
	double step(double spring_multiplier);
	PackedFloat32Array level_map();
	void reset_levels();
	double total_volume() const;
	int64_t wet_cells() const;
	int64_t active_cells() const { return (int64_t)active.size(); }

	int64_t get_ticks() const { return ticks; }
	double get_seconds() const { return seconds; }
	double get_dt() const { return dt; }
	double get_evaporated_m3() const { return evaporated_m3; }
	double get_sea_m3() const { return sea_m3; }

protected:
	static void _bind_methods();

private:
	int side = 0;
	double spacing_m = 8.0;
	std::vector<float> ground;
	std::vector<double> depth;
	std::vector<float> flow_x;
	std::vector<float> flow_z;
	std::vector<double> delta;
	std::vector<uint8_t> mark;
	std::vector<uint8_t> touched_mark;
	std::vector<uint8_t> spring_cell;
	std::vector<int32_t> active;
	std::vector<int32_t> touched;
	std::vector<int32_t> dirty;
	std::vector<int32_t> previous;
	std::vector<std::pair<int32_t, double>> springs;
	PackedFloat32Array levels;
	bool levels_ready = false;
	double deepest = 1.0;
	int64_t ticks = 0;
	double seconds = 0.0;
	double dt = 0.5;
	double evaporated_m3 = 0.0;
	double sea_m3 = 0.0;

	void wake(int32_t k);
	void add_delta(int32_t k, double amount);
	double face(double q, double level_a, double ground_a, double level_b, double ground_b, double step_s) const;
	bool is_stranded(int32_t k) const;
	bool is_steep(int32_t k) const;
	bool reaches_wet(int32_t k, int32_t step) const;
	bool drawn_wet(int32_t k) const;
	void refresh_level(int32_t k);
};

} // namespace godot
