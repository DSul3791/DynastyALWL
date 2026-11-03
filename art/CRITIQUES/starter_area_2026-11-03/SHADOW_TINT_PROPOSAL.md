# Proposal: warmer shade (for Technical direction review, not applied)

**Problem (critique item 2):** in shade, ferns, shrubs and the ground under trees read blue-grey. `look_settings.gd` lights shade only from the sky (`ambient_light_source = SKY`, `ambient_light_sky_contribution = 1.0`), and a clear blue sky makes that light cyan. Art_Direction.md asks for rich, warm, natural colours.

**Change proposed (two lines in `src/client/look_settings.gd`, every quality level):**
```
environment.ambient_light_sky_contribution = 0.75                 # was 1.0
environment.ambient_light_color = Color(0.62, 0.56, 0.44)          # warm bounce light from sunlit ground and leaves (new)
```
With a SKY source, Godot blends `ambient_light_color` in by (1 - sky_contribution): shade keeps 75% of the sky's light and gains 25% warm bounce, which is what green and brown surroundings give in real woods. Energy is unchanged.

**Cost:** none (two constants, no new pass).
**Risk:** night and storm scenes get slightly warmer shade too. If night reads less cold, scale the colour by the sun's height (same place the day cycle sets sky energy).
**Check:** spawn at noon (`--hour 12`) and the orchard close-up, before and after; one night shot (`--hour 22`) to confirm darkness still feels threatening.
