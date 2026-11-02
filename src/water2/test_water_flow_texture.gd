extends SceneTree

# Dynasty water c2: the render texture of a field (Sonny, 31 Oct 2026; written without being run, run it when the computer is back).
#   godot --headless --path . --script res://src/water2/test_water_flow_texture.gd

const Field := preload("res://src/water2/water_field.gd")
const FlowTexture := preload("res://src/water2/water_flow_texture.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var bed: PackedFloat32Array = PackedFloat32Array()
	bed.resize(32 * 8)

	for j in range(8):
		for i in range(32):
			bed[j * 32 + i] = 10.0 - 0.1 * float(i)

	var f = Field.new(32, 8, 2.0, bed)

	for j in range(8):
		f.add_spring(1, j, 0.5)

	for s in range(120):
		f.step(1.0)

	var im: Image = FlowTexture.build_image(f)
	_check(im.get_width() == 32 and im.get_height() == 8 and im.get_format() == Image.FORMAT_RGBAF, "the image is 32 x 8 RGBAF")
	var px: Color = im.get_pixel(16, 4)
	_check(absf(px.a - f.depth[4 * 32 + 16]) < 1.0e-6 and px.a > 0.0, "A is the depth of the cell (%.3f m)" % px.a)
	_check(absf(px.r - (f.bed[4 * 32 + 16] + f.depth[4 * 32 + 16])) < 1.0e-4, "R is the water surface, bed + depth (%.3f m)" % px.r)
	_check(px.g > 0.1 and absf(px.b) < 0.05, "G is the flow downhill (east %.2f m/s), B has no sideways flow" % px.g)
	_check(FlowTexture.foam_hint(0.5, 1.0) == 0.0 and FlowTexture.foam_hint(0.5, 6.0) > 0.5 and FlowTexture.foam_hint(5.0, 6.0) == 0.0 and FlowTexture.foam_hint(0.0, 9.0) == 0.0, "foam: none when slow, strong when fast and shallow, none in deep or no water")
	var dry: Color = im.get_pixel(31, 0)
	_check(dry.a >= 0.0 and absf(dry.r - (f.bed[31] + dry.a)) < 1.0e-4, "a dry or thin texel sits on its bed (surface %.2f, depth %.3f)" % [dry.r, dry.a])
	var pk: Dictionary = FlowTexture.packet(f, Vector2(100.0, 200.0))
	var back: Image = FlowTexture.unpack(pk["w"], pk["h"], pk["raw"], pk["bytes"])
	_check(back != null and back.get_width() == 32 and back.get_format() == Image.FORMAT_RGBAF, "the packet unpacks to a 32 x 8 float image")
	_check(back != null and absf(back.get_pixel(16, 4).g - px.g) < 0.02 and absf(back.get_pixel(16, 4).r - px.r) < 0.02, "depth and flow survive the wire")
	_check(pk["origin"] == Vector2(100.0, 200.0) and pk["bytes"].size() < pk["raw"], "origin kept, packet smaller than raw (%d of %d bytes)" % [pk["bytes"].size(), pk["raw"]])
	_check(back != null and absf(back.get_pixel(16, 4).r - px.r) < 1.0e-4, "the surface height survives the wire exactly (float)")
	_check(FlowTexture.unpack(32, 8, 7, pk["bytes"]) == null and FlowTexture.unpack(9999, 8, 9999 * 64, pk["bytes"]) == null, "a wrong size or a huge size is refused")
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)
