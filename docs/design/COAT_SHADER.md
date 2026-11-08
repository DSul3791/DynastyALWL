# Coat shader: wind, wet, season, dust

The animal coats today are StandardMaterial3D overrides built from the row's `materials` (animal_view.gd `_model_materials`). This plan
adds four looks on top of them. Only section 3 (seasonal colour) is built so far, behind the flag `season_coats` (default off).

## 1. Fur ruffle in wind (planned)

- A small vertex shader on coat surfaces: vertices pushed along the normal by a noise field that scrolls with the wind direction,
  amplitude `wind^1.3 x ruffle_cm` (row key `ruffle_cm`, about 0.5 for a fox, 1.5 for a bear or yak, 0 for short coats like the horse).
- Masked by the texture's alpha cards where a model has them (ruff, mane, tail), so the body does not swell.
- Needs a ShaderMaterial copy of the coat material (albedo, normal, roughness carried over); one shader shared by all species.
- Wind comes from `wind_now` (already wired: ears and tails use it).

## 2. Wet darkening (tie-in with the wet look)

- The wet look (WET_LINE_SHADER.md, branch claude/mikew-wet-look) darkens and smooths coats after swimming or rain (`wet_dark`,
  `wet_rough`, `wet_shed`). It writes `albedo_color` on the same `coat_mats` list this branch collects.
- When both branches are merged, the two multiply: one `_coat_colour(node)` will compute season tint x wet darkening x dust, and both
  `_wet_look` and `_coat_season` will call it, so neither overwrites the other. Until then they live on separate branches.

## 3. Seasonal coat colour (built, flag `season_coats`)

- Row key `season_tint`: `{spring, summer, autumn, winter: colour}`. The colour multiplies the coat texture (`albedo_color`), so
  white means the texture as bought.
- Season from `conditions_now` (`season`, the client's clock). Checked once a second and eased 30 percent per check, so a season
  change fades over a few seconds rather than snapping. A real moult takes weeks; the client season is its middle.
- Eye surfaces are left out of `coat_mats`, so eyes and eye shine keep their colour.
- Rows set now: deer (warm red summer, grey-brown winter), elk, moose, wolf (slightly paler winter), fox (paler winter), rabbit
  (paler winter). A true white winter hare needs its own texture swap, not a tint; noted for when a hare model arrives.
- Check on the PC: `creature_motion --id=deer --season=winter` and `--season=summer` with the flag on, side by side.

## 4. Dust on coats after rolling (planned)

- When an animal ends a roll or dust-bath clip (horse, bison, donkey, elephant: clip roles to be named), a dust amount goes to 1 and
  fades over about 3 minutes, or at once in water or heavy rain.
- Look: `albedo_color` lerped toward the ground's dust colour (the footfall puff colours) by `dust x 0.35`, roughness up by 0.1.
- Shares the `_coat_colour` product from section 2.

## Order

Season colour checked on the PC first; then the shared `_coat_colour` when the wet look merges; then dust; ruffle last (it is the only
part that needs a shader).
