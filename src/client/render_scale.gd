extends RefCounted
# 3D render resolution by quality (Technical direction, 2026-10-20). Pixel count is the
# biggest GPU cost in a 3D game: the Godot docs say halving the scale factor cuts the
# rendered pixels to a quarter (resolution scaling page). Dave's window was 2880x1620
# (4.7 megapixels, 2.25 times 1080p), which an RTX 2060 Super cannot fill at 30 fps with
# sky, shadows, SSAO and TAA. The menus and text stay sharp at full window size; only
# the 3D picture is rendered at the tier's pixel budget and scaled up (FSR 1.0, which the
# docs rate better than bilinear for upscaling and which needs Forward+, our renderer).

const TARGET_MPIX := [1.0, 2.1, 2.1, 3.7]     # 3D megapixels per tier: Low about 720p, Medium and High 1080p, Ultra about 1440p
const MIN_SCALE := 0.5

# Largest 3D picture drawn, whatever the window size (Esc > Settings > Resolution; 1920x1080 at most).
static var cap: Vector2i = Vector2i(1920, 1080)
static var override_scale: float = 0.0        # > 0: a manual setting (Esc > Settings) wins over the tier


static func scale_for(window_size: Vector2i, quality: int) -> float:
	if override_scale > 0.0:
		return override_scale

	var mpix: float = float(window_size.x) * float(window_size.y) / 1000000.0
	var target: float = float(TARGET_MPIX[clampi(quality, 0, TARGET_MPIX.size() - 1)])
	var limit: float = minf(minf(float(cap.x) / float(maxi(window_size.x, 1)), float(cap.y) / float(maxi(window_size.y, 1))), 1.0)

	if mpix <= target:
		return limit

	return clampf(minf(sqrt(target / mpix), limit), 0.25, 1.0)


static func apply(viewport: Viewport, window_size: Vector2i, quality: int) -> float:
	var scale: float = scale_for(window_size, quality)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = scale
	return scale
