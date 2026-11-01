extends RefCounted

# Render contract, stage c2 (Sonny, 31 Oct 2026; written while the computer was off limits, NOT RUN YET: see the queued commands in docs/DYNASTY_WATER_STATUS.md).
# One RGBAF texel per sim cell: R depth (m), G flow x (m/s, east), B flow z (m/s, south), A foam hint 0..1 (fast shallow water: speed over FOAM_SPEED, thinned out by depth).
# `build_image` makes it from a field, `apply` hands it to a water ShaderMaterial together with where it lies in the world, `SHADER_INCLUDE` is the code the shader adds to read it.
# The game's water shader (src/client/water_material.gd) takes flow today from vertex COLOR, which the client derives from received levels; with this texture the flow, depth and foam come from the sim.
# Nothing here changes the game: the six-line patch that switches the shader over is written out in docs/DYNASTY_WATER_STATUS.md and is applied only after the tests have run.

const FOAM_SPEED := 3.0      # m/s above which shallow water starts to foam
const FOAM_DEPTH := 1.5      # m: deeper water foams less (the energy goes under)

const SHADER_INCLUDE := """
uniform sampler2D water2_tex : filter_linear, repeat_disable;
uniform vec2 water2_origin = vec2(0.0);      // world x, z of the first cell centre
uniform vec2 water2_size = vec2(1.0);        // world metres the texture covers (cells x cell size)
uniform float water2_on = 0.0;               // 0: the old vertex-colour flow; 1: read the texture
// depth (m), flow (m/s), foam 0..1 at a world position; outside the window: no water data, depth -1
vec4 water2_at(vec2 world_xz) {
	vec2 uv = (world_xz - water2_origin) / water2_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec4(-1.0, 0.0, 0.0, 0.0);
	}
	return textureLod(water2_tex, uv, 0.0);   // vertex stage: no derivatives, so an explicit level
}
"""


# The texture image of a field: Image.FORMAT_RGBAF, size w x h.
static func build_image(f) -> Image:
	var im: Image = Image.create(f.w, f.h, false, Image.FORMAT_RGBAF)

	for j in range(f.h):
		for i in range(f.w):
			var d: float = f.depth[j * f.w + i]
			var v: Vector2 = f.velocity(i, j)
			im.set_pixel(i, j, Color(d, v.x, v.y, foam_hint(d, v.length())))

	return im


# Foam 0..1 from speed and depth: none below FOAM_SPEED, full at twice that, halved by deep water. Independent of the `turbulence` trait, which scales it in the shader (calm vs rough stays a setting).
static func foam_hint(depth_m: float, speed: float) -> float:
	if depth_m < 0.02:
		return 0.0

	return clampf((speed - FOAM_SPEED) / FOAM_SPEED, 0.0, 1.0) * clampf(1.0 - depth_m / (2.0 * FOAM_DEPTH), 0.0, 1.0)


# Gives a water ShaderMaterial the texture and where it lies. `origin` is the world position of cell (0, 0); the texel centres sit on the cells, so the texture covers w x cell metres starting half a cell
# before the origin.
static func apply(material: ShaderMaterial, f, origin: Vector2) -> void:
	material.set_shader_parameter("water2_tex", ImageTexture.create_from_image(build_image(f)))
	material.set_shader_parameter("water2_origin", origin - Vector2(0.5, 0.5) * f.cell_m)
	material.set_shader_parameter("water2_size", Vector2(float(f.w), float(f.h)) * f.cell_m)
	material.set_shader_parameter("water2_on", 1.0)
