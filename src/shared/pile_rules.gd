extends RefCounted

# Cone piles (Dave 19 Nov 2026, boulders plan /mnt/project-files/boulders/PLAN.md section 5b): a pile of loose broken stone is a solid cone
# ("make them tight with no airspace in between", "realistically when you just drop rocks or items in a pile they eventually make a cone shape").
# Its volume is its pieces' own volume (count x kg each / density), its sides stand at the angle of repose, so the cone grows linearly in
# volume with the count, by new layers on the outside. The server (merge reach, what a pile may not grow into) and the client (the look)
# both size a pile with these, so they agree. Only items.json pile rows with "shape": "cone" are cones.

const REPOSE_DEG := 35.0      # loose angular rock settles at about 35 degrees (PROVISIONAL PL-2)
const MIN_DRAWN_R_M := 0.15   # a tiny pile is drawn at least this wide so it can be found (look only; the server uses the true size)


static func is_cone(pile: Dictionary) -> bool:
	return str(pile.get("shape", "")) == "cone" and float(pile.get("density_kg_m3", 0.0)) > 0.0


# The base radius in metres of a solid cone of `count` pieces of `unit_kg` each at `density_kg_m3`.
static func cone_radius(count: int, unit_kg: float, density_kg_m3: float) -> float:
	if count <= 0 or unit_kg <= 0.0 or density_kg_m3 <= 0.0:
		return 0.0

	var volume: float = float(count) * unit_kg / density_kg_m3
	return pow(3.0 * volume / (PI * tan(deg_to_rad(REPOSE_DEG))), 1.0 / 3.0)


static func cone_height(radius: float) -> float:
	return radius * tan(deg_to_rad(REPOSE_DEG))
