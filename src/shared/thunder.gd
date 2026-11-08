extends RefCounted

# Thunder strikes the same on the server and every client (docs/design/birds_and_thunder_server.md): where and when lightning strikes,
# from the world seed, the game time and the storm. The world is cut into CELL_M cells and game time into SLOT_S slots; in each slot a
# cell has a strike with a chance that grows with the storm, at a hashed point in the cell and a hashed moment in the slot. Pure and static.
# The rate is today's client rate (weather_sounds.gd: a strike within about 2.8 km every 14 to 45 real seconds at the full storm), spread
# evenly over the ground: about one strike per cell every 45 real seconds at storm 1 (judged from that).
# A strike needs a storm: rain 0.5 or more (weather_sounds.gd's thunder gate) and storm over 0.

const CELL_M := 4000.0
const SLOT_S := 60.0                 # game seconds (2.5 real seconds at GameClock.RATIO 24)
const CELL_EVERY_GAME_S := 1089.0     # mean game seconds between strikes in one cell at storm 1 (45 real s)
const RAIN_FROM := 0.5
const STREAM := 911


# The strikes between game seconds t0 (exclusive) and t1 (inclusive) within reach_m of `centre`: [[Vector3 point (y 0), game second], ...].
static func strikes(seed_value: int, t0: float, t1: float, weather_state: Dictionary, centre: Vector3, reach_m: float) -> Array:
	var found: Array = []
	var storm: float = clampf(float(weather_state.get("storm", 0.0)), 0.0, 1.0)

	if storm <= 0.0 or float(weather_state.get("rain", 0.0)) < RAIN_FROM or t1 <= t0:
		return found

	var chance: float = clampf(SLOT_S / CELL_EVERY_GAME_S * maxf(storm, 0.2), 0.0, 1.0)
	var cx0: int = floori((centre.x - reach_m) / CELL_M)
	var cx1: int = floori((centre.x + reach_m) / CELL_M)
	var cz0: int = floori((centre.z - reach_m) / CELL_M)
	var cz1: int = floori((centre.z + reach_m) / CELL_M)

	for slot in range(floori(t0 / SLOT_S), floori(t1 / SLOT_S) + 1):
		for cx in range(cx0, cx1 + 1):
			for cz in range(cz0, cz1 + 1):
				var key: int = (cx * 92821) ^ (cz * 68917) ^ slot

				if _hash(seed_value, STREAM, key) >= chance:
					continue

				var at: float = (float(slot) + _hash(seed_value, STREAM + 1, key)) * SLOT_S

				if at <= t0 or at > t1:
					continue

				var point: Vector3 = Vector3((float(cx) + _hash(seed_value, STREAM + 2, key)) * CELL_M, 0.0, (float(cz) + _hash(seed_value, STREAM + 3, key)) * CELL_M)

				if Vector2(point.x - centre.x, point.z - centre.z).length() <= reach_m:
					found.append([point, at])

	return found


static func _hash(seed_value: int, stream: int, i: int) -> float:
	var h: int = (seed_value * 73856093) ^ (stream * 19349663) ^ (i * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0
