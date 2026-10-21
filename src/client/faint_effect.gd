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

const EASE_K := 7.0                # how fast the picture follows a change (1 / time constant, per second): only smooths the server's steps
const SLEEP_K := 0.9               # lying down and waking from sleep: the picture takes about four seconds either way

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
var _k: float = EASE_K
var _slow: bool = false


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
	_k = EASE_K

	# Dave 2026-10-21: smooth, not chunky. Only a slight vignette and soft focus, then a gradual fade to black as the character goes
	# down; the server sends the progress in fine steps (protocol 59) and the picture follows it with exponential smoothing.
	match state:
		"over_exerted":
			var over: float = clampf((exertion - 1.0) * 2.0, 0.0, 1.0)
			_target = Vector3(0.25 * over, 0.0, 0.3 * over)
		"fainting", "waking":
			_target = Vector3(0.3 * smoothstep(0.0, 0.7, p), smoothstep(0.2, 1.0, p), 0.5 * p)
		"fainted":
			_target = Vector3(0.3, 1.0, 0.5)
		"sleeping":
			_target = Vector3(0.3, 1.0, 0.5)        # lying down: the same black as a faint, a little slower in and out
			_k = SLEEP_K
			_slow = true
		"sleep_wake":
			_target = Vector3.ZERO
			_k = SLEEP_K
		_:
			_target = Vector3.ZERO

	if _slow and state != "sleeping" and state != "sleep_wake" and blackout > 0.01:
		_k = SLEEP_K      # the wake from sleep keeps its slow ease until the picture is clear

	if blackout <= 0.01:
		_slow = false


func _process(delta: float) -> void:
	var t: int = FrameProbe.start()
	_process_body(delta)
	FrameProbe.stop("faint effect", t)


func _process_body(delta: float) -> void:
	if _rect == null:
		return

	var follow: float = 1.0 - exp(-_k * delta)
	tunnel = lerpf(tunnel, _target.x, follow)
	blackout = lerpf(blackout, _target.y, follow)
	blur = lerpf(blur, _target.z, follow)

	if _target.y == 0.0 and blackout < 0.004:
		tunnel = 0.0
		blackout = 0.0
		blur = 0.0
	var active: bool = tunnel > 0.002 or blackout > 0.002 or blur > 0.002

	if active != _rect.visible:
		_rect.visible = active

	if active:
		var size: Vector2 = _rect.size
		_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
		_material.set_shader_parameter("tunnel", tunnel)
		_material.set_shader_parameter("blackout", blackout)
		_material.set_shader_parameter("blur", blur)
