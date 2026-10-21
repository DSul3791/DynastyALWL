extends Node

# The picture when the player is over-exerted and faints (owner, 2026-10-20): first the sight
# narrows and blurs, then it fades to black over a few seconds, stays black while only the
# heartbeat is heard, and comes back slowly on waking. Client only; the exertion system (Items)
# decides the state and calls
#
#   faint.set_state(state, exertion, progress)
#     state     "normal", "over_exerted", "fainting", "fainted" or "waking"
#     exertion  0 to 1 and above (over 1 is over-exerted: the tunnel grows with it)
#     progress  0 to 1 through the fade-out while "fainting", 1 down to 0 while "waking"
#
# Free when normal: the overlay is hidden, so nothing is drawn and no screen copy is made. When
# shown it is one full-screen rectangle (a screen texture read, the blur is a lower mip level, so
# no extra passes), drawn under the HUD text and menus. `blackout` (0 to 1) is exposed for sounds.

const EASE_PER_S := 1.2            # how fast the picture follows a change, per second (smooths steps)

const SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float tunnel = 0.0;     // 0 clear, 1 only a pinhole of sight left
uniform float blackout = 0.0;   // 0 clear, 1 black
uniform float blur = 0.0;       // 0 sharp, 1 very soft towards the edges
uniform float aspect = 1.78;

void fragment() {
	vec2 centred = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(centred);
	float inner = mix(1.2, 0.08, tunnel);
	float edge = smoothstep(inner, inner + 0.45, r);
	vec3 sharp = textureLod(screen, SCREEN_UV, 0.0).rgb;
	vec3 soft = textureLod(screen, SCREEN_UV, 1.0 + 3.0 * blur * edge).rgb;
	vec3 c = mix(sharp, soft, clamp(blur * (0.4 + edge), 0.0, 1.0));
	c = mix(c, vec3(0.0), clamp(edge * tunnel + blackout, 0.0, 1.0));
	COLOR = vec4(c, 1.0);
}
"""

var blackout: float = 0.0
var tunnel: float = 0.0
var blur: float = 0.0

var _rect: ColorRect
var _material: ShaderMaterial
var _target: Vector3 = Vector3.ZERO      # tunnel, blackout, blur


const FrameProbe := preload("res://src/debug/frame_probe.gd")

func setup(layer: CanvasLayer) -> void:
	var shader: Shader = Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_rect.visible = false
	layer.add_child(_rect)


func set_state(state: String, exertion: float, progress: float) -> void:
	var p: float = clampf(progress, 0.0, 1.0)

	match state:
		"over_exerted":
			var over: float = clampf((exertion - 1.0) * 2.0, 0.0, 1.0)
			_target = Vector3(0.6 * over, 0.0, 0.5 * over)
		"fainting", "waking":
			_target = Vector3(0.6 + 0.4 * p, smoothstep(0.35, 1.0, p), 0.5 + 0.5 * p)
		"fainted":
			_target = Vector3(1.0, 1.0, 1.0)
		_:
			_target = Vector3.ZERO


func _process(delta: float) -> void:
	var t: int = FrameProbe.start()
	_process_body(delta)
	FrameProbe.stop("faint effect", t)


func _process_body(delta: float) -> void:
	if _rect == null:
		return

	var step: float = EASE_PER_S * delta
	tunnel = move_toward(tunnel, _target.x, step)
	blackout = move_toward(blackout, _target.y, step)
	blur = move_toward(blur, _target.z, step)
	var active: bool = tunnel > 0.002 or blackout > 0.002 or blur > 0.002

	if active != _rect.visible:
		_rect.visible = active

	if active:
		var size: Vector2 = _rect.size
		_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
		_material.set_shader_parameter("tunnel", tunnel)
		_material.set_shader_parameter("blackout", blackout)
		_material.set_shader_parameter("blur", blur)
