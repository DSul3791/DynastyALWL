#include "water_core.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

// Kept equal to the constants in src/water/water_sim.gd.
static const double GRAVITY = 9.81;
static const double MANNING_N = 0.035;
static const double STABILITY = 0.7;
static const double DT_MAX_S = 2.0;
static const double DT_MIN_S = 0.05;
static const double FACE_MIN_M = 0.001;
static const double SPEED_MAX_M_S = 12.0;
static const double SLEEP_M = 0.00002;
static const double WET_M = 0.12;
static const double STEEP_WET_M = 0.6;
static const double THIN_WET_M = 0.02;   // thinner running water drawn where it joins wet water on both sides
static const double STEEP_DROP_M = 3.0;
static const double PUDDLE_M = 0.06;
static const double LEVEL_M = 0.002;
static const double DRY_M_PER_S = 0.0001;

void WaterCore::setup(int64_t cells_per_side, double spacing, const PackedFloat32Array &ground_heights) {
	side = (int)cells_per_side;
	spacing_m = spacing;
	size_t count = (size_t)side * (size_t)side;
	ground.assign(count, 0.0f);
	const float *g = ground_heights.ptr();
	for (size_t k = 0; k < count && k < (size_t)ground_heights.size(); k++) {
		ground[k] = g[k];
	}
	depth.assign(count, 0.0);
	flow_x.assign(count, 0.0f);
	flow_z.assign(count, 0.0f);
	delta.assign(count, 0.0);
	mark.assign(count, 0);
	touched_mark.assign(count, 0);
	spring_cell.assign(count, 0);
	active.clear();
	touched.clear();
	dirty.clear();
	springs.clear();
	levels = PackedFloat32Array();
	levels_ready = false;
	deepest = 1.0;
	ticks = 0;
	seconds = 0.0;
	evaporated_m3 = 0.0;
	sea_m3 = 0.0;
}

void WaterCore::wake(int32_t k) {
	if (mark[k] == 0 && ground[k] > 0.0f) {
		mark[k] = 1;
		active.push_back(k);
	}
}

void WaterCore::add_delta(int32_t k, double amount) {
	if (!touched_mark[k]) {
		touched_mark[k] = 1;
		touched.push_back(k);
	}
	delta[k] += amount;
}

void WaterCore::set_ground(int64_t k, double height) {
	if (k < 0 || k >= (int64_t)ground.size()) {
		return;
	}
	ground[k] = (float)height;
	dirty.push_back((int32_t)k);
	wake((int32_t)k);
	int32_t n[4] = { (int32_t)k - 1, (int32_t)k + 1, (int32_t)k - side, (int32_t)k + side };
	for (int d = 0; d < 4; d++) {
		if (n[d] >= 0 && n[d] < (int32_t)ground.size()) {
			wake(n[d]);
		}
	}
}

void WaterCore::add_water(int64_t k, double meters) {
	depth[k] += meters;
	dirty.push_back((int32_t)k);
	wake((int32_t)k);
}

void WaterCore::add_spring(int64_t k, double m3_per_s) {
	springs.emplace_back((int32_t)k, m3_per_s);
	spring_cell[k] = 1;
	wake((int32_t)k);
}

void WaterCore::set_depth(const PackedFloat32Array &values) {
	const float *v = values.ptr();
	for (size_t k = 0; k < depth.size() && k < (size_t)values.size(); k++) {
		depth[k] = v[k];
		dirty.push_back((int32_t)k);
	}
}

PackedFloat32Array WaterCore::get_depth() const {
	PackedFloat32Array out;
	out.resize((int64_t)depth.size());
	float *o = out.ptrw();
	for (size_t k = 0; k < depth.size(); k++) {
		o[k] = (float)depth[k];
	}
	return out;
}

double WaterCore::depth_at(int64_t k) const {
	return (k >= 0 && k < (int64_t)depth.size()) ? depth[k] : 0.0;
}

void WaterCore::wake_all_wet() {
	for (size_t k = 0; k < depth.size(); k++) {
		if (depth[k] > 0.0) {
			wake((int32_t)k);
		}
	}
}

double WaterCore::face(double q, double level_a, double ground_a, double level_b, double ground_b, double step_s) const {
	double face_depth = std::max(level_a, level_b) - std::max(ground_a, ground_b);
	if (face_depth <= FACE_MIN_M) {
		return 0.0;
	}
	double push = GRAVITY * face_depth * step_s * (level_a - level_b) / spacing_m;
	q = (q + push) / (1.0 + GRAVITY * step_s * MANNING_N * MANNING_N * std::fabs(q) / std::pow(face_depth, 7.0 / 3.0));
	double most = SPEED_MAX_M_S * face_depth;
	return std::clamp(q, -most, most);
}

bool WaterCore::is_stranded(int32_t k) const {
	int i = k % side;
	int j = k / side;
	if (i == 0 || j == 0 || i == side - 1 || j == side - 1) {
		return false;
	}
	double here = ground[k] + depth[k] - LEVEL_M;
	int32_t n[4] = { k - 1, k + 1, k - side, k + side };
	for (int d = 0; d < 4; d++) {
		if (ground[n[d]] + depth[n[d]] < here) {
			return false;
		}
	}
	return true;
}

double WaterCore::step(double spring_multiplier) {
	const int width = side;
	const double area = spacing_m * spacing_m;
	const size_t count = active.size();
	dt = std::clamp(STABILITY * spacing_m / std::sqrt(GRAVITY * std::max(deepest, 0.05)), DT_MIN_S, DT_MAX_S);
	const double step_s = dt;
	const double per_flow = step_s / spacing_m;
	double moved = 0.0;
	touched.clear();

	// 1. Flows on every face of the working cells (a shared face is done once).
	for (size_t a = 0; a < count; a++) {
		int32_t k = active[a];
		int i = k % width;
		int j = k / width;
		double gk = ground[k];
		double here = gk + depth[k];

		for (int d = 0; d < 4; d++) {
			int32_t n = -1;
			if (d == 0) {
				n = i < width - 1 ? k + 1 : -1;
			} else if (d == 1) {
				n = j < width - 1 ? k + width : -1;
			} else if (d == 2) {
				if (i == 0) {
					n = -2;
				} else if (mark[k - 1] == 1) {
					continue;
				} else {
					n = k - 1;
				}
			} else {
				if (j == 0) {
					n = -2;
				} else if (mark[k - width] == 1) {
					continue;
				} else {
					n = k - width;
				}
			}

			// The open edge: water runs out as if onto dry ground of the same height.
			if (n < 0) {
				if (depth[k] <= 0.0) {
					continue;
				}
				double out = std::max(face(0.0, here, gk, gk, gk, step_s), 0.0);
				out = std::min(out, depth[k] * 0.25 / per_flow);
				double gone = out * per_flow;
				add_delta(k, -gone);
				sea_m3 += gone * area;
				moved += gone * area;
				continue;
			}

			double gn = ground[n];
			double there = gn > 0.0 ? gn + depth[n] : 0.0; // the sea holds at 0 m
			bool forward = d < 2;
			double stored = forward ? (d == 0 ? flow_x[k] : flow_z[k]) : -(d == 2 ? flow_x[n] : flow_z[n]);
			double q = face(stored, here, gk, there, gn, step_s);

			if (q > 0.0) {
				q = std::min(q, depth[k] * 0.25 / per_flow);
			} else if (gn > 0.0) {
				q = std::max(q, -depth[n] * 0.25 / per_flow);
			} else {
				q = 0.0; // the sea never flows back onto land
			}

			if (d == 0) {
				flow_x[k] = (float)q;
			} else if (d == 1) {
				flow_z[k] = (float)q;
			} else if (d == 2) {
				flow_x[n] = (float)-q;
			} else {
				flow_z[n] = (float)-q;
			}

			if (q == 0.0) {
				continue;
			}

			double amount = q * per_flow;
			add_delta(k, -amount);
			moved += std::fabs(amount) * area;

			if (gn > 0.0) {
				add_delta(n, amount);
			} else {
				sea_m3 += amount * area;
			}
		}
	}

	// 2. Springs pour over a 5 x 5 patch.
	for (const auto &sp : springs) {
		int32_t centre = sp.first;
		double share = sp.second * spring_multiplier * step_s / area / 25.0;
		for (int dj = -2; dj <= 2; dj++) {
			for (int di = -2; di <= 2; di++) {
				int ci = centre % side + di;
				int cj = centre / side + dj;
				if (ci >= 0 && ci < side && cj >= 0 && cj < side && ground[cj * side + ci] > 0.0f) {
					add_delta(cj * side + ci, share);
				}
			}
		}
	}

	// 3. Apply, and decide who works next tick: cells that changed and their neighbours.
	previous.assign(active.begin(), active.end());
	for (size_t a = 0; a < count; a++) {
		mark[active[a]] = 0;
	}
	active.clear();
	deepest = 0.05;

	for (size_t t = 0; t < touched.size(); t++) {
		int32_t k = touched[t];
		touched_mark[k] = 0;
		double change = delta[k];
		depth[k] = std::max(depth[k] + change, 0.0);
		delta[k] = 0.0;
		dirty.push_back(k);

		if (std::fabs(change) > SLEEP_M || spring_cell[k] == 1) {
			wake(k);
			if (k % width > 0) {
				wake(k - 1);
			}
			if (k % width < width - 1) {
				wake(k + 1);
			}
			if (k >= width) {
				wake(k - width);
			}
			if (k < width * (width - 1)) {
				wake(k + width);
			}
		}
	}

	// 4. Stranded puddles dry.
	for (size_t a = 0; a < previous.size(); a++) {
		int32_t k = previous[a];
		if (depth[k] > 0.0 && depth[k] < PUDDLE_M && spring_cell[k] == 0 && is_stranded(k)) {
			double lost = std::min(depth[k], DRY_M_PER_S * step_s);
			depth[k] -= lost;
			dirty.push_back(k);
			evaporated_m3 += lost * area;
			wake(k);
		}
	}

	for (size_t a = 0; a < active.size(); a++) {
		deepest = std::max(deepest, depth[active[a]]);
	}

	ticks += 1;
	seconds += step_s;
	return moved;
}

bool WaterCore::is_steep(int32_t k) const {
	double lowest = ground[k];
	int32_t n[4] = { k - 1, k + 1, k - side, k + side };
	for (int d = 0; d < 4; d++) {
		if (n[d] >= 0 && n[d] < (int32_t)ground.size()) {
			lowest = std::min(lowest, (double)ground[n[d]]);
		}
	}
	return ground[k] - lowest > STEEP_DROP_M;
}

// Thin water from k in one direction reaches water deep enough to draw within two squares.
bool WaterCore::reaches_wet(int32_t k, int32_t step) const {
	int32_t n = k;
	for (int hop = 0; hop < 2; hop++) {
		int32_t next = n + step;
		if (next < 0 || next >= (int32_t)depth.size() || ((step == 1 || step == -1) && next / side != n / side)) {
			return false;
		}
		n = next;
		if (depth[n] >= WET_M) {
			return true;
		}
		if (depth[n] < THIN_WET_M) {
			return false;
		}
	}
	return false;
}

// Owner report (2026-10-19, a dry band across the river): a shallow riffle under WET_M cut
// the drawn river in two; thin water with drawn water on both sides is drawn too.
bool WaterCore::drawn_wet(int32_t k) const {
	if (depth[k] >= WET_M) {
		return true;
	}
	if (depth[k] < THIN_WET_M) {
		return false;
	}
	return (reaches_wet(k, -1) && reaches_wet(k, 1)) || (reaches_wet(k, -side) && reaches_wet(k, side));
}

void WaterCore::refresh_level(int32_t k) {
	float *l = levels.ptrw();
	l[k] = NAN;
	if (ground[k] <= 0.0f || !drawn_wet(k)) {
		return;
	}
	if (depth[k] < STEEP_WET_M && is_steep(k)) {
		return;
	}
	l[k] = (float)(ground[k] + depth[k]);
}

PackedFloat32Array WaterCore::level_map() {
	if (!levels_ready) {
		levels.resize((int64_t)depth.size());
		for (size_t k = 0; k < depth.size(); k++) {
			refresh_level((int32_t)k);
		}
		levels_ready = true;
	} else {
		// A change can decide whether thin water up to two squares away is drawn.
		const int32_t total = (int32_t)depth.size();
		for (int32_t k : dirty) {
			int32_t near[9] = { k, k - 1, k + 1, k - 2, k + 2, k - side, k + side, k - 2 * side, k + 2 * side };
			for (int32_t n : near) {
				if (n >= 0 && n < total) {
					refresh_level(n);
				}
			}
		}
	}
	dirty.clear();
	return levels.duplicate();
}

void WaterCore::reset_levels() {
	levels_ready = false;
}

double WaterCore::total_volume() const {
	double total = 0.0;
	for (size_t k = 0; k < depth.size(); k++) {
		if (ground[k] > 0.0f) {
			total += depth[k];
		}
	}
	return total * spacing_m * spacing_m;
}

int64_t WaterCore::wet_cells() const {
	int64_t count = 0;
	for (double d : depth) {
		if (d >= WET_M) {
			count++;
		}
	}
	return count;
}

void WaterCore::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "cells_per_side", "spacing", "ground_heights"), &WaterCore::setup);
	ClassDB::bind_method(D_METHOD("set_ground", "k", "height"), &WaterCore::set_ground);
	ClassDB::bind_method(D_METHOD("add_water", "k", "meters"), &WaterCore::add_water);
	ClassDB::bind_method(D_METHOD("add_spring", "k", "m3_per_s"), &WaterCore::add_spring);
	ClassDB::bind_method(D_METHOD("set_depth", "values"), &WaterCore::set_depth);
	ClassDB::bind_method(D_METHOD("get_depth"), &WaterCore::get_depth);
	ClassDB::bind_method(D_METHOD("depth_at", "k"), &WaterCore::depth_at);
	ClassDB::bind_method(D_METHOD("wake_all_wet"), &WaterCore::wake_all_wet);
	ClassDB::bind_method(D_METHOD("step", "spring_multiplier"), &WaterCore::step);
	ClassDB::bind_method(D_METHOD("level_map"), &WaterCore::level_map);
	ClassDB::bind_method(D_METHOD("reset_levels"), &WaterCore::reset_levels);
	ClassDB::bind_method(D_METHOD("total_volume"), &WaterCore::total_volume);
	ClassDB::bind_method(D_METHOD("wet_cells"), &WaterCore::wet_cells);
	ClassDB::bind_method(D_METHOD("active_cells"), &WaterCore::active_cells);
	ClassDB::bind_method(D_METHOD("get_ticks"), &WaterCore::get_ticks);
	ClassDB::bind_method(D_METHOD("get_seconds"), &WaterCore::get_seconds);
	ClassDB::bind_method(D_METHOD("get_dt"), &WaterCore::get_dt);
	ClassDB::bind_method(D_METHOD("get_evaporated_m3"), &WaterCore::get_evaporated_m3);
	ClassDB::bind_method(D_METHOD("get_sea_m3"), &WaterCore::get_sea_m3);
}
