extends RefCounted

# Frozen water look (docs/design/frozen_water_look.md, Kathleen 8 Nov 2026), always on, client only. Pure functions: the numbers the
# liquid sheets' ice is drawn from (liquid_surface.gd set_ice_all). The ice rule itself is src/shared/ice.gd, unchanged; the walkable collider and
# the server keep using Ice.cover at the 3 m pond depth.

const Ice := preload("res://src/shared/ice.gd")
const Climate := preload("res://src/shared/climate.gd")

const OPEN_DEPTH_M := 3.0          # the deep water's cover: today's Ice.cover depth (terrain_client ICE_POND_DEPTH_M)
const SHORE_DEPTH_M := 1.0         # the shallows' cover: the shallowest depth ice.gd tells apart (2-day water lag, faster growth)
const THAW_FROM_PEAK := 0.125      # a thaw counts once the last 30 days held at least this cover (2.5 cm)
const SPRING_ABOVE_MEAN_C := 0.0   # spring water comes out at the year's mean (Jamie #739; about 10.7 C at #8002 from the grid row's 14.2 C, #717 row 21)
const SPRING_LAMBDA_M := 840.0     # one lambda = rho c Q / (h W) for every spring: gives Sonny's worked example, 810 m on a -4 C night at 6.5 C
                                   # (Jamie #739: about 440 m x sqrt(L/s) at -5 C calm, x1.8 at -2, x0.6 at -10, x0.4 at -15; this log rule gives the same ratios)
const SPRING_BREEZE := [0.3, 0.5]  # wind (0..1) over which the open length halves (Jamie #739: halve in a breeze; h doubles)
const SPRING_AIR_FLOOR_C := -0.5   # above this the air counts as this, so the open radius never runs to infinity at noon (about 2.2 km)
const MAX_SPRINGS := 8             # the shader's arrays
const MAX_HOLES := 8
const HOLE_RADIUS_M := 0.3
const HOLE_GAME_H := 18.0          # data/items/fishing.json ice.hole_game_h (a hole's whole life)
const NEAR_M := 3000.0             # holes further than this from the player are left out
const SPRING_NEAR_M := 5500.0      # and springs (their open radius reaches about 2.2 km, so one beyond the view can still open water in it)


# Vector4(open, shore, thaw, snow): open and shore are Ice covers at 3 m and 1 m, thaw 0..1 how much of the last 30 days' thickest ice has gone,
# snow the lying snow (weather_sounds.gd ground_snow), which the shader puts only on ice of 5 cm or more.
static func look(game_s: float, zone_group: String, altitude_m: float, seed_value: int, ground_snow: float) -> Vector4:
	var deep: Dictionary = Ice.season(game_s, zone_group, altitude_m, OPEN_DEPTH_M, seed_value)
	var shore: float = Ice.cover(game_s, zone_group, altitude_m, SHORE_DEPTH_M, seed_value)
	return Vector4(float(deep["cover"]), shore, thaw_of(float(deep["cover"]), float(deep["peak"])), clampf(ground_snow, 0.0, 1.0))


static func thaw_of(cover: float, peak: float) -> float:
	if peak < THAW_FROM_PEAK:
		return 0.0

	return clampf(1.0 - cover / peak, 0.0, 1.0)


# The water temperature a spring gives at `altitude_m` (C).
static func spring_c(zone_group: String, altitude_m: float) -> float:
	var climate: Dictionary = Climate.of_zone(zone_group)
	return float(climate["sea_level_mean_c"]) - float(climate["lapse_c_per_km"]) * maxf(altitude_m, 0.0) / 1000.0 + SPRING_ABOVE_MEAN_C


# How far below a spring its brook stays open (m): Sonny's x0 = lambda ln((Tw - Ta) / (0 - Ta)), halved in a breeze (`wind` 0..1, Weather's); 0 for a
# spring at or below freezing.
static func spring_open_m(air_c: float, water_c: float, wind: float = 0.0) -> float:
	if water_c <= 0.0:
		return 0.0

	var air: float = minf(air_c, SPRING_AIR_FLOOR_C)
	var breeze: float = 1.0 - 0.5 * smoothstep(float(SPRING_BREEZE[0]), float(SPRING_BREEZE[1]), wind)
	return SPRING_LAMBDA_M * breeze * log((water_c - air) / (0.0 - air))


# Up to MAX_SPRINGS Vector4(x, z, open radius m, 0), nearest first, from cave_streams.gd pools ([centre, radius, depth] each).
static func springs_near(pools: Array, at: Vector3, air_c: float, zone_group: String, wind: float = 0.0) -> PackedVector4Array:
	var near: Array = []

	for pool in pools:
		var centre: Vector3 = pool[0]
		var d: float = Vector2(centre.x - at.x, centre.z - at.z).length()

		if d <= SPRING_NEAR_M:
			near.append([d, centre])

	near.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var out: PackedVector4Array = PackedVector4Array()

	for entry in near.slice(0, MAX_SPRINGS):
		var centre: Vector3 = entry[1]
		out.append(Vector4(centre.x, centre.z, spring_open_m(air_c, spring_c(zone_group, centre.y), wind), 0.0))

	return out


# Up to MAX_HOLES Vector4(x, z, radius m, age 0..1), nearest first. `holes` is a list of {"pos": Vector3, "until": game seconds} (the server's
# _holes, once Steve sends them) or {"pos", "forever": true} (the picture switch); a hole whose time is up is left out. Optional "radius" and "life_h"
# (skim broken by a wader, ice_feel.gd) replace HOLE_RADIUS_M and HOLE_GAME_H.
static func holes_near(holes: Array, at: Vector3, now_s: float) -> PackedVector4Array:
	var near: Array = []

	for hole in holes:
		var pos: Vector3 = hole["pos"]
		var age: float = 0.0

		if not bool(hole.get("forever", false)):
			var left_s: float = float(hole.get("until", 0.0)) - now_s

			if left_s <= 0.0:
				continue

			age = clampf(1.0 - left_s / (float(hole.get("life_h", HOLE_GAME_H)) * 3600.0), 0.0, 1.0)

		var d: float = Vector2(pos.x - at.x, pos.z - at.z).length()

		if d <= NEAR_M:
			near.append([d, Vector4(pos.x, pos.z, float(hole.get("radius", HOLE_RADIUS_M)), age)])

	near.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var out: PackedVector4Array = PackedVector4Array()

	for entry in near.slice(0, MAX_HOLES):
		out.append(entry[1])

	return out


# The picture switch --frozen-force=open[,thaw[,snow]]: Vector4(open, open, thaw, snow), or Vector4(-1, ...) when the text is empty or bad.
static func force_of(text: String) -> Vector4:
	var parts: PackedStringArray = text.split(",", false)

	if parts.is_empty() or not parts[0].is_valid_float():
		return Vector4(-1.0, -1.0, -1.0, -1.0)

	var cover: float = clampf(parts[0].to_float(), 0.0, 1.0)
	var thaw: float = clampf(parts[1].to_float(), 0.0, 1.0) if parts.size() > 1 and parts[1].is_valid_float() else 0.0
	var snow: float = clampf(parts[2].to_float(), 0.0, 1.0) if parts.size() > 2 and parts[2].is_valid_float() else 0.0
	return Vector4(cover, cover, thaw, snow)


# The picture switch --frozen-hole=x,z: one hole that never closes, or [] when the text is empty or bad.
static func hole_of(text: String) -> Array:
	var parts: PackedStringArray = text.split(",", false)

	if parts.size() < 2 or not parts[0].is_valid_float() or not parts[1].is_valid_float():
		return []

	return [{"pos": Vector3(parts[0].to_float(), 0.0, parts[1].to_float()), "forever": true}]
