extends Control

# The pulse bar over the hotbar (Dave 9 Nov 2026, docs/design/heartbeat_design.md): a thin line of light that shoots out from the
# centre to both sides on each heartbeat and eases slowly back in before the next. Green at rest, yellow in the exercise range, orange
# then red in the danger zone (data/sound/heartbeat.json "bar"). It keeps time with BreathSounds' `beat` signal (the same pulse the
# ears hear) and fades out when the heart goes quiet in a faint.

const Breath := preload("res://src/client/breath_sounds.gd")
const QUIET_AFTER := 2.5                 # intervals with no beat before the line fades (the heart gone in a faint)

var bar: Dictionary = {}
var bpm: float = 55.0
var _since: float = 1000.0               # seconds since the last beat
var _interval: float = 60.0 / 55.0
var _zones: Array = []                   # [[from_bpm, Color], ...] rising
var _shown: float = 0.0                  # 0..1, fades in on a beat and out when the beats stop


func setup(breath, layer: CanvasLayer) -> void:
	var cfg: Dictionary = breath.heart if breath != null and not breath.heart.is_empty() else Breath.load_heart()
	configure(cfg.get("bar", {}))
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if breath != null:
		breath.beat.connect(pulse)

	layer.add_child(self)


func configure(bar_cfg: Dictionary) -> void:
	bar = bar_cfg
	var centre: Array = bar.get("centre", [960.0, 940.0])
	var reach: float = float(bar.get("max_half_px", 80.0)) + float(bar.get("glow_px", 9.0))
	position = Vector2(float(centre[0]) - reach, float(centre[1]) - 8.0)
	size = Vector2(2.0 * reach, 16.0)
	_zones = []

	for zone in bar.get("zones", [[0.0, "#4cff6a"]]):
		_zones.append([float(zone[0]), Color.html(str(zone[1]))])


# One heartbeat at this rate.
func pulse(rate: float) -> void:
	bpm = rate
	_interval = 60.0 / maxf(rate, 30.0)
	_since = 0.0


func _process(delta: float) -> void:
	_since += delta
	var target: float = 1.0 if _since < QUIET_AFTER * _interval else 0.0
	_shown = move_toward(_shown, target, delta * (8.0 if target > _shown else 0.7))

	if _shown > 0.0 or target > 0.0:
		queue_redraw()


# The colour for a heart rate: the last zone whose from_bpm it has reached.
func colour(rate: float) -> Color:
	var picked: Color = _zones[0][1] if not _zones.is_empty() else Color.GREEN

	for zone in _zones:
		if rate >= float(zone[0]):
			picked = zone[1]

	return picked


# How far out the line is, 0 (in at the centre) to 1 (full spread): out fast in rise_s (at most a quarter of the beat), then slowly
# back in over the rest of the beat, so a slow heart breathes and a fast one flickers.
static func spread(since: float, interval: float, rise_s: float) -> float:
	var rise: float = minf(rise_s, 0.25 * interval)

	if since < rise:
		var t: float = since / maxf(rise, 0.001)
		return 1.0 - (1.0 - t) * (1.0 - t)

	return 1.0 - smoothstep(0.0, 1.0, clampf((since - rise) / maxf(interval - rise, 0.001), 0.0, 1.0))


func _draw() -> void:
	if _shown <= 0.0:
		return

	var s: float = spread(_since, _interval, float(bar.get("rise_s", 0.09)))
	var half: float = lerpf(float(bar.get("min_half_px", 3.0)), float(bar.get("max_half_px", 80.0)), s)
	var mid: Vector2 = size * 0.5
	var c: Color = colour(bpm)
	var a: float = _shown * lerpf(0.55, 1.0, s)           # brightest as it flashes out
	var glow: float = float(bar.get("glow_px", 9.0))
	draw_line(mid - Vector2(half + glow * 0.5, 0.0), mid + Vector2(half + glow * 0.5, 0.0), Color(c, 0.22 * a), glow, true)
	draw_line(mid - Vector2(half, 0.0), mid + Vector2(half, 0.0), Color(c, a), float(bar.get("thickness_px", 3.0)), true)
