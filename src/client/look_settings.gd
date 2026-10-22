extends RefCounted

# Light and picture settings for the client (ART_DIRECTION.md step 1, owner's target
# picture 2026-10-20): a warm sun against blue sky light, film-like tone mapping so
# sunlit grass and rock roll off softly instead of clipping, contact shadows where things
# meet the ground (SSAO), a light haze that turns far hills and trees toward the sky
# colour, and smoothed edges on leaves and grass cards.
#
# Cost follows quality (F2). Low (the GTX 1050 minimum): tone mapping, sky light, haze
# and FXAA only, which are close to free. Medium: SSAO at half size and TAA. High and
# Ultra add a soft glow on the brightest parts.

const SUN_COLOR := Color(1.0, 0.92, 0.80)
const SUN_ENERGY := 1.55
const DAY_CYCLE := true      # the sun, moon and sky follow the game clock (day_cycle.gd); false keeps the old fixed afternoon
const FOG_DENSITY := 0.0009          # clear air; the underwater fog replaces it while diving
const SSAO_FROM := 1                 # first quality level with contact shadows
const GLOW_FROM := 2
const TAA_FROM := 1


static func apply(environment: Environment, sun: DirectionalLight3D, viewport: Viewport, quality: int) -> void:
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.1
	environment.tonemap_white = 6.0
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 1.0
	environment.ambient_light_energy = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	environment.fog_density = FOG_DENSITY
	environment.fog_aerial_perspective = 0.7     # haze takes the colour of the sky behind it

	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.12
	environment.adjustment_contrast = 1.05

	environment.ssao_enabled = quality >= SSAO_FROM
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 2.2
	environment.ssao_power = 1.6
	environment.ssao_detail = 0.6
	environment.ssao_light_affect = 0.15      # a little in sunlight too, so grass bases darken

	environment.glow_enabled = quality >= GLOW_FROM
	environment.glow_intensity = 0.35
	environment.glow_bloom = 0.03
	environment.glow_hdr_threshold = 1.2
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	if sun != null:
		sun.light_color = SUN_COLOR
		sun.light_energy = SUN_ENERGY
		sun.shadow_blur = 1.5

	if viewport != null:
		viewport.use_taa = quality >= TAA_FROM
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if quality >= TAA_FROM else Viewport.SCREEN_SPACE_AA_FXAA
