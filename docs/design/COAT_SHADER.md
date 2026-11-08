# Coat shader: wind, wet, season, dust

The animal coats today are StandardMaterial3D overrides built from the row's `materials` (animal_view.gd `_model_materials`). This plan
adds four looks on top of them. Sections 1, 3 and 4 are built, each behind its own flag (all default off): `coat_ruffle`,
`season_coats`, `coat_dust`. Section 2 waits for the wet-look branch to merge.

## 1. Fur ruffle in wind (built, flag `coat_ruffle`)

- A small vertex shader on coat surfaces: vertices pushed along the normal by a noise field that scrolls with the wind direction,
  amplitude `wind^1.3 x ruffle_cm` (row key `ruffle_cm`, about 0.5 for a fox, 1.5 for a bear or yak, 0 for short coats like the horse).
- Masked by the texture's alpha cards where a model has them (ruff, mane, tail), so the body does not swell.
- Needs a ShaderMaterial copy of the coat material (albedo, normal, roughness carried over); one shader shared by all species.
- Wind comes from `wind_now` (already wired: ears and tails use it).
- As built: `_ruffle_material` swaps the coat's StandardMaterial3D for a ShaderMaterial with the same texture, roughness and alpha cut
  (one shader per cull mode). Each vertex moves along its normal and the wind direction by a travelling two-sine ripple; amp is
  `ruffle_cm x wind^1.3`, set once a second, full on fur cards (cut-out surfaces) and a third on the body. Wind direction is fixed
  for now (the weather sends strength only). Rows: fox 0.5, wolf 0.8, bear 1.5, black bear 1.2, lynx 0.6, goat 0.6, raccoon 0.5.
- The shader cannot be compiled headless; the PC strip is its first real check.

## 2. Wet darkening (tie-in with the wet look)

- The wet look (WET_LINE_SHADER.md, branch claude/mikew-wet-look) darkens and smooths coats after swimming or rain (`wet_dark`,
  `wet_rough`, `wet_shed`). It writes `albedo_color` on the same `coat_mats` list this branch collects.
- When both branches are merged, the two multiply: the wet darkening joins `_coat_tick` (season tint x dust x wet), and
  `_wet_look` hands it its wet amount rather than writing the colour itself, so neither overwrites the other. Until then they live on separate branches.

## 3. Seasonal coat colour (built, flag `season_coats`)

- Row key `season_tint`: `{spring, summer, autumn, winter: colour}`. The colour multiplies the coat texture (`albedo_color`), so
  white means the texture as bought.
- Season from `conditions_now` (`season`, the client's clock). Checked once a second and eased 30 percent per check, so a season
  change fades over a few seconds rather than snapping. A real moult takes weeks; the client season is its middle.
- Eye surfaces are left out of `coat_mats`, so eyes and eye shine keep their colour.
- Rows set now: deer (warm red summer, grey-brown winter), elk, moose, wolf (slightly paler winter), fox (paler winter), rabbit
  (paler winter). A true white winter hare needs its own texture swap, not a tint; noted for when a hare model arrives.
- Check on the PC: `creature_motion --id=deer --season=winter` and `--season=summer` with the flag on, side by side.

## 4. Dust on coats after rolling (built, flag `coat_dust`)

- When an animal ends a roll or dust-bath clip (horse, bison, donkey, elephant: clip roles to be named), a dust amount goes to 1 and
  fades over about 3 minutes, or at once in water or heavy rain.
- Look: `albedo_color` lerped toward the ground's dust colour (the footfall puff colours) by `dust x 0.35`, roughness up by 0.1.
- As built (`_coat_tick`): dust builds over about 2 s while the animal is in a roll state (row `roll_states`, default [8], the
  server's roll in the grass), takes the ground's colour (dust, mud, snow), fades over 3 minutes, and goes at once in water or on
  rain-wet ground. Season tint and dust share one colour: tint, then lerp toward dust, so neither overwrites the other.

## Order

All three built parts are checked on the PC together (run sheet m19 to m22). When the wet look merges, its darkening joins the same
`_coat_tick` colour (tint x dust x wet).
