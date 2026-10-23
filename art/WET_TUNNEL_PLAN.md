# Wet tunnels under water: looks and sounds (design)
Kathleen_ArtisticDirector, 2026-10-23. Dave 01:12: in a tunnel under the ocean, within about 4 m of the water above, water drips through the ceiling; the floor looks wet and splashes when you walk; no water accumulates (like Minecraft). Systems side (distance check, water above, bracing link) is Sonny/Steve; this is the art and sound.

## Stages by distance to the water above (client-side, from the same voxel query the server uses)
1. 4 to 2.5 m: damp. Ceiling and walls a little darker. Rare drips (one drop every 4 to 8 s per tunnel stretch).
2. 2.5 to 1.2 m: dripping. Dark wet patches on the ceiling, a drip point every 2 to 3 m, a drop every 1 to 3 s; the floor under each drip glistens.
3. Under 1.2 m: running. Thin streams run down the wall from the ceiling and a fine drizzle falls; many drip points; still no puddles (water vanishes when it reaches the floor).

## Looks
- Wet ceiling and walls: darker, lower roughness (a sheen), a few small streak decals running down; fades in by stage.
- Drips: one small falling drop (a 3 cm elongated white-blue sprite, 8 GPU particles per drip point at most), with a tiny ring splash decal on the floor for 0.3 s. Total cap: 12 drip points near the player.
- Wet floor: floor under and between drip points is darker and glossy, with 4 small wet-sheen patches per metre; no standing water, no depth.
- Wetness is visual only and never blocks the visual collapse warning (shaking dust still reads).

## Sounds (all generated placeholders first, assets/audio/make_wet.py)
- drip_plink (4 variants, pitch random): a clear drop on stone, quiet, spatial from the drip point; the closer to the water the more often.
- drip_trickle (loop, stage 3): soft running water down rock, spatial from the nearest stream, low level.
- wet_step (floor class "wet", 4 variants): a small splash and squelch on each footstep; replaces the normal step on the wet floor, level like mud.
- Echo and reverb stay as the approved tunnel sound.
- No music, no stinger; the water sounds are the warning that you are close to the ocean.

## Ties to other systems (ask Sonny/Steve, not mine)
- Water above should weaken the ceiling so bracing matters (Dave: "players better brace well"): send Sonny "wetness stage" as an input to the collapse check if Dave agrees.
