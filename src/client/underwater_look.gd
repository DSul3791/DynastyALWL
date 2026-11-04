extends RefCounted

# Under water (Sonny, Dave 2 Nov 2026: "above the water looks amazing. being under the water looking up looks fake").
# The old look was a flat blue sheet over the screen. Now the water is drawn as water from inside:
# - the fog is the water (weather_look.gd _underwater_fog): blue-green by day, dark at night, thicker with depth;
# - the surface overhead is seen from below, a bright rippling window on the sky with a mirror round it (liquid_surface.gd,
#   water_material.gd, the !FRONT_FACING branch);
# - sunlight focused by the ripples plays over the bed as moving caustic lines (ground_material.gd `caustics`, set here);
# - this overlay: a slow wobble of the picture and a darker rim, on its own canvas layer under the HUD.

const OVERLAY := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 wob = vec2(sin(uv.y * 17.0 + TIME * 1.6) + sin(uv.y * 41.0 - TIME * 2.3) * 0.4,
		cos(uv.x * 13.0 + TIME * 1.2) + cos(uv.x * 37.0 + TIME * 2.0) * 0.4) * 0.0018;
	vec3 c = textureLod(screen, uv + wob, 0.0).rgb;
	float r = length((uv - 0.5) * vec2(1.6, 1.0));
	c *= 1.0 - 0.38 * smoothstep(0.35, 1.0, r);
	COLOR = vec4(c, 1.0);
}
"""

const CAUSTIC_DEPTH_M := 9.0     # caustics fade out over this much water above the bed

static var _overlay_shader: Shader = null
static var _last: Vector2 = Vector2(-1.0, 0.0)   # (strength, surface) last told to the ground


static func make() -> ColorRect:
	if _overlay_shader == null:
		_overlay_shader = Shader.new()
		_overlay_shader.code = OVERLAY

	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _overlay_shader
	rect.material = material
	rect.visible = false
	return rect


# Caustics on the ground under the water over the eye: x surface height, y strength (0 off; the daylight), z how deep they reach.
static func set_caustics(ground: ShaderMaterial, on: bool, surface: float, daylight: float) -> void:
	if ground == null:
		return

	var want: Vector2 = Vector2(snappedf(clampf(daylight, 0.0, 1.0), 0.05) if on else 0.0, snappedf(surface, 0.05))

	if want == _last:
		return

	_last = want
	ground.set_shader_parameter("caustics", Vector3(want.y, want.x, CAUSTIC_DEPTH_M))
