#include "gen_core.h"

#include <cmath>
#include <vector>

using namespace godot;

// Godot's own MIN / MAX / smoothstep / lerp, written out so the arithmetic matches GDScript's minf, maxf, smoothstep and lerpf.
static inline double gd_min(double a, double b) { return a < b ? a : b; }
static inline double gd_max(double a, double b) { return a > b ? a : b; }

static inline double gd_smoothstep(double from, double to, double x) {
	double s = (x - from) / (to - from);
	s = s < 0.0 ? 0.0 : (s > 1.0 ? 1.0 : s);
	return s * s * (3.0 - 2.0 * s);
}

void GenCore::_bind_methods() {
	ClassDB::bind_method(D_METHOD("flood", "h", "sea", "size"), &GenCore::flood);
	ClassDB::bind_method(D_METHOD("route", "h", "sea", "filled", "parent", "size"), &GenCore::route);
	ClassDB::bind_method(D_METHOD("carve_valleys", "cut", "h", "size", "cell_m", "jobs_i", "jobs_f"), &GenCore::carve_valleys);
}

PackedFloat32Array GenCore::carve_valleys(const PackedFloat32Array &p_cut, const PackedFloat32Array &p_h, int64_t p_size, double cell_m, const PackedInt32Array &jobs_i, const PackedFloat64Array &jobs_f) const {
	PackedFloat32Array out = p_cut.duplicate();
	float *cut = out.ptrw();
	const float *h = p_h.ptr();
	const int size = (int)p_size;
	const int64_t jobs = jobs_i.size() / 2;

	for (int64_t job = 0; job < jobs; job++) {
		const int index = jobs_i[job * 2];
		const int reach = jobs_i[job * 2 + 1];
		const double floor_level = jobs_f[job * 6];
		const double side_here = jobs_f[job * 6 + 1];
		const double half_m = jobs_f[job * 6 + 2];
		const double rim_m = jobs_f[job * 6 + 3];
		const double strength = jobs_f[job * 6 + 4];
		const double max_cut_m = jobs_f[job * 6 + 5];
		const int row = index / size;
		const int column = index % size;

		for (int dz = -reach; dz <= reach; dz++) {
			const int nr = row + dz;

			if (nr < 0 || nr >= size) {
				continue;
			}

			for (int dc = -reach; dc <= reach; dc++) {
				const int nc = column + dc;

				if (nc < 0 || nc >= size) {
					continue;
				}

				const double distance = std::sqrt((double)(dz * dz + dc * dc)) * cell_m;

				if (distance > rim_m) {
					continue;
				}

				const int neighbor = nr * size + nc;
				const double wanted = floor_level + side_here * gd_max(distance - half_m, 0.0);
				const double weight = (1.0 - gd_smoothstep(0.5, 1.0, distance / rim_m)) * strength;
				const double current = (double)cut[neighbor];
				const double lowered = current + (gd_min(current, wanted) - current) * weight;
				const double carved = gd_max(lowered, (double)h[neighbor] - max_cut_m);
				cut[neighbor] = (float)gd_min(current, carved);
			}
		}
	}

	return out;
}


static const double BUCKETS_PER_M = 100.0;
static const double WATER_EPSILON_M = 0.001;

static inline int clamp_int(int v, int lo, int hi) { return v < lo ? lo : (v > hi ? hi : v); }

Dictionary GenCore::flood(const PackedFloat32Array &p_h, const PackedByteArray &p_sea, int64_t p_size) const {
	const int size = (int)p_size;
	const int total = size * size;
	const float *h = p_h.ptr();
	const uint8_t *sea = p_sea.ptr();

	PackedFloat32Array filled_out = p_h.duplicate();
	float *filled = filled_out.ptrw();
	PackedInt32Array parent_out;
	parent_out.resize(total);
	parent_out.fill(-1);
	int32_t *parent = parent_out.ptrw();
	PackedInt32Array order_out;
	order_out.resize(total);   // trimmed to the cells reached below
	int32_t *order = order_out.ptrw();
	int order_count = 0;

	int high = 1;

	for (int k = 0; k < total; k++) {
		const int candidate = (int)((double)h[k] * BUCKETS_PER_M) + 2;
		high = candidate > high ? candidate : high;
	}

	std::vector<int32_t> head((size_t)high + 2, -1);
	std::vector<int32_t> next((size_t)total, 0);
	std::vector<uint8_t> seen((size_t)total, 0);
	const int steps[4] = { -1, 1, -size, size };

	for (int index = 0; index < total; index++) {
		const int row = index / size;
		const int column = index % size;
		const bool edge = row == 0 || column == 0 || row == size - 1 || column == size - 1;
		bool shore = sea[index] == 1;

		if (!shore && !edge) {
			for (int s = 0; s < 4; s++) {
				if (sea[index + steps[s]] == 1) {
					shore = true;
					break;
				}
			}
		}

		if (shore || edge) {
			seen[index] = 1;
			const int q = clamp_int((int)((double)h[index] * BUCKETS_PER_M), 0, high);
			next[index] = head[q];
			head[q] = index;
		}
	}

	for (int slot = 0; slot < (int)head.size(); slot++) {
		while (head[slot] != -1) {
			const int index = head[slot];
			head[slot] = next[index];
			order[order_count++] = index;
			const int row = index / size;
			const int column = index % size;

			for (int dz = -1; dz <= 1; dz++) {
				const int nr = row + dz;

				if (nr < 0 || nr >= size) {
					continue;
				}

				for (int dc = -1; dc <= 1; dc++) {
					const int nc = column + dc;

					if ((dc == 0 && dz == 0) || nc < 0 || nc >= size) {
						continue;
					}

					const int neighbor = nr * size + nc;

					if (seen[neighbor] == 1) {
						continue;
					}

					seen[neighbor] = 1;
					filled[neighbor] = (float)gd_max((double)h[neighbor], (double)filled[index]);
					parent[neighbor] = index;
					int q = clamp_int((int)((double)filled[neighbor] * BUCKETS_PER_M), 0, high + 1);
					q = q > slot ? q : slot;
					next[neighbor] = head[q];
					head[q] = neighbor;
				}
			}
		}
	}

	order_out.resize(order_count);
	Dictionary result;
	result["filled"] = filled_out;
	result["parent"] = parent_out;
	result["order"] = order_out;
	return result;
}

Dictionary GenCore::route(const PackedFloat32Array &p_h, const PackedByteArray &p_sea, const PackedFloat32Array &p_filled, const PackedInt32Array &p_parent, int64_t p_size) const {
	const int size = (int)p_size;
	const int total = size * size;
	const float *h = p_h.ptr();
	const uint8_t *sea = p_sea.ptr();
	const float *filled = p_filled.ptr();

	PackedInt32Array receiver_out = p_parent.duplicate();
	int32_t *receiver = receiver_out.ptrw();

	for (int index = 0; index < total; index++) {
		if (sea[index] == 1 || (double)filled[index] - (double)h[index] > WATER_EPSILON_M) {
			continue;
		}

		const int row = index / size;
		const int column = index % size;
		int best = -1;
		double best_slope = 0.0;

		for (int dz = -1; dz <= 1; dz++) {
			const int nr = row + dz;

			if (nr < 0 || nr >= size) {
				continue;
			}

			for (int dc = -1; dc <= 1; dc++) {
				const int nc = column + dc;

				if ((dc == 0 && dz == 0) || nc < 0 || nc >= size) {
					continue;
				}

				const int neighbor = nr * size + nc;
				double drop = (double)filled[index] - (double)filled[neighbor];

				if (dc != 0 && dz != 0) {
					drop /= 1.4142;
				}

				if (drop > best_slope + 1.0e-5) {
					best_slope = drop;
					best = neighbor;
				}
			}
		}

		if (best >= 0) {
			receiver[index] = best;
		}
	}

	std::vector<int32_t> indegree((size_t)total, 0);

	for (int index = 0; index < total; index++) {
		if (receiver[index] >= 0) {
			indegree[receiver[index]]++;
		}
	}

	std::vector<int32_t> queue;
	queue.reserve((size_t)total);

	for (int index = 0; index < total; index++) {
		if (indegree[index] == 0) {
			queue.push_back(index);
		}
	}

	size_t head = 0;

	while (head < queue.size()) {
		const int index = queue[head];
		head++;

		if (receiver[index] >= 0) {
			indegree[receiver[index]]--;

			if (indegree[receiver[index]] == 0) {
				queue.push_back(receiver[index]);
			}
		}
	}

	PackedInt32Array order_out;
	order_out.resize((int64_t)queue.size());
	int32_t *order = order_out.ptrw();

	for (size_t k = 0; k < queue.size(); k++) {
		order[k] = queue[queue.size() - 1 - k];   // queue.reverse()
	}

	Dictionary result;
	result["receiver"] = receiver_out;
	result["order"] = order_out;
	return result;
}
