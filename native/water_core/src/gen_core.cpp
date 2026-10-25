#include "gen_core.h"

#include <algorithm>
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
	ClassDB::bind_method(D_METHOD("stamp_channels", "bed", "surface", "h", "centre_surface", "size", "cell_m", "jobs_i", "jobs_f"), &GenCore::stamp_channels);
	ClassDB::bind_method(D_METHOD("classify_climate", "c", "ids", "soil_ids", "soil_base", "heights", "water_class", "air", "fresh_distance", "ocean_distance", "moisture_noise", "temperature_noise", "sea_temperature", "row_wetness"), &GenCore::classify_climate);
	ClassDB::bind_method(D_METHOD("box_blur", "field", "samples", "radius"), &GenCore::box_blur);
	ClassDB::bind_method(D_METHOD("near_border", "province", "samples", "reach"), &GenCore::near_border);
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


PackedFloat32Array GenCore::box_blur(const PackedFloat32Array &field, int64_t p_samples, int64_t p_radius) const {
	const int samples = (int)p_samples;
	const int radius = (int)p_radius;
	PackedFloat32Array out = field.duplicate();

	if (radius <= 0) {
		return out;
	}

	float *dst = out.ptrw();
	std::vector<float> source((size_t)samples * (size_t)samples);

	for (int axis = 0; axis < 2; axis++) {
		for (size_t k = 0; k < source.size(); k++) {
			source[k] = dst[k];
		}

		for (int j = 0; j < samples; j++) {
			for (int i = 0; i < samples; i++) {
				double sum = 0.0;
				int count = 0;

				for (int k = -radius; k <= radius; k++) {
					const int ni = i + (axis == 0 ? k : 0);
					const int nj = j + (axis == 1 ? k : 0);

					if (ni < 0 || nj < 0 || ni >= samples || nj >= samples) {
						continue;
					}

					sum += (double)source[(size_t)nj * samples + ni];
					count++;
				}

				dst[(size_t)j * samples + i] = (float)(sum / (double)count);
			}
		}
	}

	return out;
}

PackedByteArray GenCore::near_border(const PackedByteArray &province, int64_t p_samples, int64_t p_reach) const {
	const int samples = (int)p_samples;
	const int reach = (int)p_reach;
	PackedByteArray out;
	out.resize((int64_t)samples * samples);
	out.fill(0);
	uint8_t *near = out.ptrw();
	const uint8_t *prov = province.ptr();
	const int steps[4][2] = { { reach, 0 }, { -reach, 0 }, { 0, reach }, { 0, -reach } };

	for (int j = 0; j < samples; j++) {
		for (int i = 0; i < samples; i++) {
			const int index = j * samples + i;
			const uint8_t p = prov[index];

			for (int s = 0; s < 4; s++) {
				const int ni = clamp_int(i + steps[s][0], 0, samples - 1);
				const int nj = clamp_int(j + steps[s][1], 0, samples - 1);

				if (prov[nj * samples + ni] != p) {
					near[index] = 1;
					break;
				}
			}
		}
	}

	return out;
}


Dictionary GenCore::stamp_channels(const PackedFloat32Array &p_bed, const PackedFloat32Array &p_surface, const PackedFloat32Array &p_h, const PackedFloat32Array &p_centre_surface, int64_t p_size, double cell_m, const PackedInt32Array &jobs_i, const PackedFloat64Array &jobs_f) const {
	const int size = (int)p_size;
	PackedFloat32Array bed_out = p_bed.duplicate();
	PackedFloat32Array surface_out = p_surface.duplicate();
	float *bed = bed_out.ptrw();
	float *surface = surface_out.ptrw();
	const float *h = p_h.ptr();
	const float *centre_surface = p_centre_surface.ptr();
	const int64_t jobs = jobs_i.size() / 2;

	for (int64_t job = 0; job < jobs; job++) {
		const int index = jobs_i[job * 2];
		const int span = jobs_i[job * 2 + 1];
		const double radius_m = jobs_f[job * 4];
		const double shift_x = jobs_f[job * 4 + 1];
		const double shift_z = jobs_f[job * 4 + 2];
		const double depth_here = jobs_f[job * 4 + 3];
		const int row = index / size;
		const int column = index % size;
		const double level = (double)centre_surface[index];

		for (int dz = -span; dz <= span; dz++) {
			const int nr = row + dz;

			if (nr < 0 || nr >= size) {
				continue;
			}

			for (int dc = -span; dc <= span; dc++) {
				const int nc = column + dc;

				if (nc < 0 || nc >= size) {
					continue;
				}

				const double off_x = (double)dc * cell_m - shift_x;
				const double off_z = (double)dz * cell_m - shift_z;
				const double t = std::sqrt(off_x * off_x + off_z * off_z) / radius_m;

				if (t > 1.0) {
					continue;
				}

				const double target = (double)h[index] - depth_here * (1.0 - t * t);
				const int neighbor = nr * size + nc;
				bed[neighbor] = (float)gd_min((double)bed[neighbor], target);

				if (target < level && (std::isnan(surface[neighbor]) || (double)surface[neighbor] < level)) {
					surface[neighbor] = (float)level;
				}
			}
		}
	}

	Dictionary result;
	result["bed"] = bed_out;
	result["surface"] = surface_out;
	return result;
}


static inline double gd_clamp(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }
static inline double gd_lerp(double a, double b, double w) { return a + (b - a) * w; }

Dictionary GenCore::classify_climate(const Dictionary &c, const Dictionary &ids, const Dictionary &soil_ids, const PackedFloat64Array &soil_base, const PackedFloat32Array &heights, const PackedByteArray &water_class, const PackedFloat32Array &air, const PackedFloat32Array &fresh_distance, const PackedFloat32Array &ocean_distance, const PackedByteArray &moisture_noise, const PackedByteArray &temperature_noise, const PackedFloat32Array &sea_temperature, const PackedFloat32Array &row_wetness) const {
#define C(name) ((double)c[name])
#define ID(name) ((int)ids[name])
#define SOIL(name) ((int)soil_ids[name])
	const int side = (int)(int64_t)c["samples"];
	const int step = (int)(int64_t)c["step"];
	const int coarse = (int)(int64_t)c["coarse"];
	const int ocean_kind = (int)(int64_t)c["ocean_kind"];
	const int lake_kind = (int)(int64_t)c["lake_kind"];
	const int64_t total = (int64_t)side * side;

	PackedFloat32Array temperature_out;
	PackedByteArray moisture_out, biome_out, soil_out, fertility_out;
	PackedInt32Array biome_counts, soil_counts;
	temperature_out.resize(total);
	moisture_out.resize(total);
	biome_out.resize(total);
	soil_out.resize(total);
	fertility_out.resize(total);
	biome_counts.resize(256);
	biome_counts.fill(0);
	soil_counts.resize(256);
	soil_counts.fill(0);
	float *temperature_c = temperature_out.ptrw();
	uint8_t *moisture = moisture_out.ptrw();
	uint8_t *biome = biome_out.ptrw();
	uint8_t *soil = soil_out.ptrw();
	uint8_t *fertility = fertility_out.ptrw();
	int32_t *bc = biome_counts.ptrw();
	int32_t *sc = soil_counts.ptrw();
	int64_t fertile_cells = 0;

	const double lapse = C("lapse"), inv_two_spacing = C("inv_two_spacing");
	const double rock_tan = C("rock_tan"), scree_tan = C("scree_tan"), marsh_tan = C("marsh_tan"), flood_tan = C("flood_tan"), stony_tan = C("stony_tan"), zero_tan = C("zero_tan");
	const double hot_min = C("hot_min"), warm_min = C("warm_min"), cold_min = C("cold_min"), snow_max = C("snow_max"), glacier_max = C("glacier_max");
	const double peak = C("peak"), width = C("width"), best_low = C("best_low"), best_high = C("best_high"), zero_low = C("zero_low"), zero_high = C("zero_high");
	const double temperature_amplitude = C("temperature_amplitude"), fresh_bonus = C("fresh_bonus"), near_fresh = C("near_fresh"), moisture_amplitude = C("moisture_amplitude");
	const double beach_height_m = C("beach_height_m"), beach_distance_m = C("beach_distance_m"), marsh_height_m = C("marsh_height_m"), marsh_moisture = C("marsh_moisture");
	const double alpine_min_height_m = C("alpine_min_height_m"), boreal_moisture = C("boreal_moisture"), desert_moisture = C("desert_moisture"), scrub_moisture = C("scrub_moisture");
	const double savanna_moisture = C("savanna_moisture"), grassland_moisture = C("grassland_moisture"), mixed_moisture = C("mixed_moisture"), cool_forest_below_c = C("cool_forest_below_c");
	const double floodplain_distance_m = C("floodplain_distance_m"), sand_moisture = C("sand_moisture"), clay_moisture = C("clay_moisture"), clay_edge_m = C("clay_edge_m");

	const int i_ocean = ID("ocean"), i_beach = ID("beach"), i_hot_desert = ID("hot_desert"), i_dry_scrub = ID("dry_scrub"), i_savanna = ID("savanna");
	const int i_tropical = ID("tropical_forest"), i_mangrove = ID("mangrove"), i_grassland = ID("temperate_grassland"), i_temperate = ID("temperate_forest");
	const int i_mixed = ID("mixed_forest"), i_marsh = ID("marsh"), i_heath = ID("heath"), i_boreal = ID("boreal_forest"), i_tundra = ID("tundra");
	const int i_alpine = ID("alpine_meadow"), i_rock = ID("bare_rock"), i_snow = ID("snowfield"), i_glacier = ID("glacier");
	const int s_rock = SOIL("bare_rock"), s_sand = SOIL("sand"), s_gravel = SOIL("gravel"), s_silt = SOIL("silt"), s_clay = SOIL("clay"), s_loam = SOIL("loam");
	const int s_peat = SOIL("peat"), s_alluvium = SOIL("alluvium"), s_humus = SOIL("forest_humus"), s_stony = SOIL("stony_soil"), s_snow = SOIL("snow");
	const int s_ice = SOIL("glacial_ice"), s_beach = SOIL("beach_sand");

	const float *heights_p = heights.ptr();
	const uint8_t *wc = water_class.ptr();
	const float *air_p = air.ptr();
	const float *fresh_p = fresh_distance.ptr();
	const float *ocean_p = ocean_distance.ptr();
	const uint8_t *mnoise = moisture_noise.ptr();
	const uint8_t *tnoise = temperature_noise.ptr();
	const float *sea_t = sea_temperature.ptr();
	const float *row_wet = row_wetness.ptr();
	const double *soil_base_p = soil_base.ptr();

	for (int j = 0; j < side; j++) {
		const double v = (double)j / (double)step;
		const int r0 = std::min((int)v, coarse - 2);
		const double tv = v - (double)r0;

		for (int i = 0; i < side; i++) {
			const int index = j * side + i;
			const double h = (double)heights_p[index];
			const int kind = wc[index];
			const double u = (double)i / (double)step;
			const int c0 = std::min((int)u, coarse - 2);
			const double tu = u - (double)c0;
			const int base_cell = r0 * coarse + c0;

			double temperature = (double)sea_t[j] - lapse * gd_max(h, 0.0);
			temperature += temperature_amplitude * ((double)tnoise[index] / 127.5 - 1.0);
			temperature_c[index] = (float)temperature;
			const double air_here = gd_lerp(
					gd_lerp((double)air_p[base_cell], (double)air_p[base_cell + 1], tu),
					gd_lerp((double)air_p[base_cell + coarse], (double)air_p[base_cell + coarse + 1], tu), tv);
			const int near_cell = (r0 + (tv > 0.5 ? 1 : 0)) * coarse + c0 + (tu > 0.5 ? 1 : 0);
			const double fresh_here = (double)fresh_p[near_cell];
			double wet = (double)row_wet[j] * (0.4 + 0.9 * air_here);
			wet += fresh_bonus * gd_clamp(1.0 - fresh_here / near_fresh, 0.0, 1.0);
			wet += moisture_amplitude * ((double)mnoise[index] / 127.5 - 1.0);
			wet = gd_clamp(wet, 0.0, 1.0);
			moisture[index] = (uint8_t)(int)std::round(wet * 255.0);

			if (kind != 0) {
				const int water_soil = kind == ocean_kind ? s_sand : (kind == lake_kind ? s_silt : s_gravel);
				biome[index] = (uint8_t)i_ocean;
				soil[index] = (uint8_t)water_soil;
				fertility[index] = 0;
				bc[i_ocean]++;
				sc[water_soil]++;
				continue;
			}

			const double gx = ((double)heights_p[index + (i < side - 1 ? 1 : 0)] - (double)heights_p[index - (i > 0 ? 1 : 0)]) * inv_two_spacing;
			const double gz = ((double)heights_p[index + (j < side - 1 ? side : 0)] - (double)heights_p[index - (j > 0 ? side : 0)]) * inv_two_spacing;
			const double slope = std::sqrt(gx * gx + gz * gz);
			const double ocean_here = (double)ocean_p[near_cell];

			int chosen;

			if (h < beach_height_m && ocean_here < beach_distance_m) {
				chosen = (temperature >= hot_min && wet >= 0.6 && slope < marsh_tan) ? i_mangrove : i_beach;
			} else if (h < marsh_height_m && slope < marsh_tan && wet >= marsh_moisture && temperature > cold_min) {
				chosen = i_marsh;
			} else if (temperature < glacier_max && h > 150.0) {
				chosen = i_glacier;
			} else if (temperature < snow_max) {
				chosen = i_snow;
			} else if (slope > rock_tan) {
				chosen = i_rock;
			} else if (temperature < cold_min) {
				chosen = i_tundra;
			} else if (h > alpine_min_height_m && temperature < warm_min + 3.0) {
				chosen = i_alpine;
			} else if (temperature < warm_min) {
				chosen = wet >= boreal_moisture ? i_boreal : i_tundra;
			} else if (temperature >= hot_min) {
				if (wet < desert_moisture) {
					chosen = i_hot_desert;
				} else if (wet < scrub_moisture) {
					chosen = i_dry_scrub;
				} else if (wet < savanna_moisture) {
					chosen = i_savanna;
				} else {
					chosen = i_tropical;
				}
			} else if (wet < desert_moisture) {
				chosen = i_dry_scrub;
			} else if (wet < grassland_moisture) {
				chosen = i_grassland;
			} else if (wet < mixed_moisture) {
				chosen = temperature < cool_forest_below_c ? i_mixed : i_temperate;
			} else if (ocean_here < 600.0 && slope > 0.0 && temperature < cool_forest_below_c + 2.0) {
				chosen = i_heath;
			} else {
				chosen = i_temperate;
			}

			int picked;

			if (chosen == i_rock || slope > rock_tan) {
				picked = s_rock;
			} else if (chosen == i_glacier) {
				picked = s_ice;
			} else if (chosen == i_snow) {
				picked = s_snow;
			} else if (chosen == i_beach || chosen == i_mangrove) {
				picked = chosen == i_beach ? s_beach : s_silt;
			} else if (chosen == i_marsh) {
				picked = s_peat;
			} else if (chosen == i_tundra) {
				picked = slope > stony_tan ? s_stony : s_gravel;
			} else if (slope > scree_tan) {
				picked = s_stony;
			} else if (fresh_here < floodplain_distance_m && slope < flood_tan) {
				picked = s_alluvium;
			} else if (chosen == i_hot_desert || (wet < sand_moisture && h < 40.0)) {
				picked = s_sand;
			} else if (slope > stony_tan) {
				picked = s_stony;
			} else if (wet >= clay_moisture && slope < flood_tan && fresh_here < clay_edge_m) {
				picked = s_clay;
			} else if (chosen == i_temperate || chosen == i_mixed || chosen == i_boreal || chosen == i_tropical || chosen == i_heath) {
				picked = s_humus;
			} else {
				picked = s_loam;
			}

			biome[index] = (uint8_t)chosen;
			soil[index] = (uint8_t)picked;
			bc[chosen]++;
			sc[picked]++;

			const double moisture_factor = gd_clamp(1.0 - std::fabs(wet - peak) / width, 0.0, 1.0);
			double temperature_factor = 1.0;

			if (temperature < best_low) {
				temperature_factor = gd_clamp((temperature - zero_low) / (best_low - zero_low), 0.0, 1.0);
			} else if (temperature > best_high) {
				temperature_factor = gd_clamp((zero_high - temperature) / (zero_high - best_high), 0.0, 1.0);
			}

			const double slope_factor = gd_clamp(1.0 - slope / zero_tan, 0.0, 1.0);
			const double value = soil_base_p[picked] * (0.35 + 0.65 * moisture_factor) * temperature_factor * slope_factor;
			int rounded = (int)std::round(value);
			rounded = rounded < 0 ? 0 : (rounded > 255 ? 255 : rounded);
			fertility[index] = (uint8_t)rounded;

			if (value >= 150.0) {
				fertile_cells++;
			}
		}
	}

#undef C
#undef ID
#undef SOIL
	Dictionary result;
	result["temperature_c"] = temperature_out;
	result["moisture"] = moisture_out;
	result["biome"] = biome_out;
	result["soil"] = soil_out;
	result["fertility"] = fertility_out;
	result["biome_counts"] = biome_counts;
	result["soil_counts"] = soil_counts;
	result["fertile_cells"] = fertile_cells;
	return result;
}
