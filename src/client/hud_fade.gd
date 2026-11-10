extends Node

const Breath := preload("res://src/client/breath_sounds.gd")

# Passing out (Dave 10 Nov 2026, docs/design/heartbeat_design.md "Passing out"): when the player faints from over-exertion the whole HUD fades
# out, the hotbar and all, and only the heartbeat line stays: the one reminder that you are alive. It goes with the vision (the server's blackout,
# strain_fade): gone when the black reaches faint_hud.gone_at_black, back as the black lifts on waking, never faster than faint_hud.fade_s for
# the whole way. Sleep blacks out the same picture but keeps the HUD (Dave asked for the faint only).
#
# Every direct child of the HUD layer is faded through its own modulate alpha, except the kept ones (the heartbeat line and the blackout picture
# itself). So a node placed straight on the HUD layer fades its own look with self_modulate, never modulate (inventory_view's labels do).
#   hud_fade.setup(layer, [heart_pulse, faint_rect], heartbeat.json "faint_hud")
#   hud_fade.step(delta, HudFade.black_of(items.strain_state, items.strain_fade, items.asleep))   each frame

var shown: float = 1.0                # 1 the HUD as normal, 0 gone
var gone_at_black: float = 0.5
var fade_s: float = 0.8
var _layer: CanvasLayer
var _keep: Array = []
var _applied: float = 1.0


func setup(layer: CanvasLayer, keep: Array, cfg: Dictionary) -> void:
	_layer = layer
	_keep = keep

	if cfg.is_empty():
		cfg = Breath.load_heart().get("faint_hud", {})     # the heart controller not set up yet: read heartbeat.json

	gone_at_black = maxf(float(cfg.get("gone_at_black", 0.5)), 0.01)
	fade_s = maxf(float(cfg.get("fade_s", 0.8)), 0.01)


# How black the faint is, 0 to 1, from the server's strain (inventory_view: state 1 over-exerted with the blackout coming on, 2 fainted,
# 3 waking with the blackness left). Asleep (state under 2) is the sleep fade, not a faint: 0.
static func black_of(strain_state: int, strain_fade: float, asleep: bool) -> float:
	if asleep and strain_state < 2:
		return 0.0

	if strain_state == 2:
		return 1.0

	if strain_state == 1 or strain_state == 3:
		return clampf(strain_fade, 0.0, 1.0)

	return 0.0


# How much of the HUD to show at this blackout: all of it at 0, none from gone_at_black up.
static func target(black: float, gone_at: float) -> float:
	return 1.0 - clampf(black / maxf(gone_at, 0.01), 0.0, 1.0)


func step(delta: float, black: float) -> void:
	shown = move_toward(shown, target(black, gone_at_black), delta / fade_s)

	if shown >= 1.0 and _applied >= 1.0:
		return      # the usual case: nothing to touch

	_apply(shown)


func _apply(alpha: float) -> void:
	_applied = alpha

	if _layer == null:
		return

	for child in _layer.get_children():
		if child is CanvasItem and not _keep.has(child):
			(child as CanvasItem).modulate.a = alpha
