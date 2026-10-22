extends RefCounted

# Bird flocks on the water (Radar, 2026-10-21, Dave's animal rules: they stay away from people and have the basic behaviour of the real
# animal). One record per flock (ducks and geese), drawn by the client as a handful of birds: they float on a pond or lake, raise their
# heads when a person is within alert_m (the usual senses: wind, crouching, hills), and the whole flock takes off together, flying
# straight away from the threat and low-climbing, when someone comes within takeoff_m. Their alarm sets other wildlife running.
# They are gone once they have flown fly_m (another flock settles on some water later). Numbers: species "flock" block in animals.json.

const TAKEOFF := 15   # wire state: the flock is in the air

var host                # ServerAnimals


func handles(a: Dictionary) -> bool:
	return host.species_def(a["sp"]).has("flock")


func step(a: Dictionary, dt: float, seen_d: float, seen_p: Vector3) -> void:
	var def: Dictionary = host.species_def(a["sp"])
	var fl: Dictionary = def["flock"]

	if int(a["state"]) == TAKEOFF:
		var dir: Vector2 = Vector2.from_angle(float(a["dir"]))
		var speed: float = float(fl.get("fly_mps", 14.0))
		a["pos"] = Vector3(a["pos"].x + dir.x * speed * dt, a["pos"].y, a["pos"].z + dir.y * speed * dt)
		a["flown"] = float(a["flown"]) + speed * dt
		var climb: float = minf(float(a["flown"]) * 0.3, float(fl.get("climb_m", 25.0)))
		var base: float = float(host.water_level.call(a["pos"].x, a["pos"].z)) if host.water_level.is_valid() else a["pos"].y
		a["heading"] = float(a["dir"])
		a["pos"].y = (a["home"].y if is_nan(base) else maxf(base, a["home"].y)) + climb

		if float(a["flown"]) >= float(fl.get("fly_m", 160.0)):
			host.animals.erase(a["id"])

		return

	if seen_d <= float(fl.get("takeoff_m", 22.0)):
		take_off(a, seen_p)
	elif seen_d <= float(fl.get("alert_m", 45.0)):
		a["state"] = host.ALERT
		a["heading"] = atan2(seen_p.z - a["pos"].z, seen_p.x - a["pos"].x)
	else:
		a["state"] = host.GRAZE


# The whole flock goes up, away from the danger, and sounds the alarm for whatever else is near.
func take_off(a: Dictionary, from: Vector3) -> void:
	var def: Dictionary = host.species_def(a["sp"])
	var away: Vector2 = Vector2(a["pos"].x - from.x, a["pos"].z - from.z)
	away = away.normalized() if away.length() > 0.1 else Vector2.from_angle(float(a["heading"]))
	a["dir"] = away.angle() + host.rng.randf_range(-0.3, 0.3)   # luck-exempt: which way a flock banks
	a["flown"] = 0.0
	a["state"] = TAKEOFF
	var alarm_m: float = float(def["flock"].get("alarm_m", 60.0))

	for other_id in host.animals:
		var other: Dictionary = host.animals[other_id]

		if other_id != a["id"] and not other.has("pack") and int(other["state"]) == host.GRAZE and float(other["alarm"]) < 0.0 and Vector2(other["pos"].x - a["pos"].x, other["pos"].z - a["pos"].z).length() <= alarm_m:
			other["alarm"] = host.rng.randf_range(0.3, 1.0)   # luck-exempt: how fast others react to the alarm
			other["alarm_from"] = a["pos"]
