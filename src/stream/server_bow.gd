extends RefCounted

# Bow rules (plan 4b, data/items/bow.json): the numbers of a shot. Pure: the arrow's flight is stepped by server_items (it owns the world), the hit test is a hook.

const BowAim := preload("res://src/shared/bow_aim.gd")

var cfg: Dictionary = {}


func _init(config: Dictionary = {}) -> void:
	cfg = config

	if cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/bow.json"))
		cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# The draw time a client sends is never trusted: it is clamped to what a draw can be.
func clamp_draw(draw_ms: int) -> int:
	return clampi(draw_ms, 0, int(cfg.get("draw_max_ms", 1200)))


# 0..1. Under draw_min_ms the shot is weak; from there to draw_max_ms the power rises from min_power to 1.
func power(draw_ms: int) -> float:
	var lo: int = int(cfg.get("draw_min_ms", 300))
	var hi: int = maxi(int(cfg.get("draw_max_ms", 1200)), lo + 1)
	var d: int = clamp_draw(draw_ms)

	if d < lo:
		return float(cfg.get("weak_power", 0.25))

	return lerpf(float(cfg.get("min_power", 0.5)), 1.0, float(d - lo) / float(hi - lo))


func speed(power_now: float) -> float:
	return float(cfg.get("speed_max", 45.0)) * power_now


# The bow skill (0..100) multiplies it by aim.damage_mult (Dave 10 Nov 2026).
func damage(arrow_damage: float, power_now: float, level: float) -> float:
	return arrow_damage * power_now * BowAim.damage_mult(cfg, level)


# The chance the arrow does NOT survive its landing: by tip, worse when it hit an animal; in water it is lost water_loss of the time (the larger of the two).
func lost_chance(tip: String, hit_animal: bool, in_water: bool) -> float:
	var base: float = float(cfg.get("break_chance", {}).get(tip, 0.5))

	if hit_animal:
		base = minf(base * float(cfg.get("hit_break_mult", 1.5)), 1.0)

	if in_water:
		base = maxf(base, float(cfg.get("water_loss", 0.5)))

	return base


# The arrow the bow is loaded with (`loaded`, an ammo item the pack holds) or else the first ammo id of the data list that the pack holds: its slot, or -1.
func ammo_slot(inv, table, loaded: int = 0) -> int:
	if loaded != 0 and is_ammo(table.id_of(loaded)) and inv.has(loaded, 1):
		return inv.numbers.find(loaded)

	for id in cfg.get("ammo", []):
		var number: int = table.number_of(str(id))

		if number != 0 and inv.has(number, 1):
			return inv.numbers.find(number)

	return -1


func is_ammo(item_id: String) -> bool:
	return (cfg.get("ammo", []) as Array).has(item_id)
