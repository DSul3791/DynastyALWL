# Action plan: caves sound like nothing, except what you do (and drips and echoes in wet caves)

Branch: claude/steve-cave-air (plan only, devstop). CHANGE_LABEL: RUNTIME (client sound; data table). Dave 24 Oct 14:24: air sounds are loud in the cave; hear the outside air for a bit after entering, less the further in; ambience in a cave sounds like nothing unless you move, walk or work; a WET cave has drips and echoes.
Pollen in the cave is the cave-light thread's job (wind_cue.gd). This plan edits src/client/cave_sounds.gd (+ one data file); nobody else touches that file.

## What is wrong today (src/client/cave_sounds.gd)
1. At full enclosure the buses are only cut Wind -18 dB, Weather -14 dB, Nature -8 dB (DROP_DB), low-passed at 1800 Hz. Far too loud, and the same at the mouth as deep inside.
2. The Nature bus also carries bird/animal calls, my ambience beds (ambience_slots.gd, no hush of their own) and the cave DRIPS. Cutting Nature hard would kill the drips, so the drips move to the Foley bus (it already has the cave reverb).
3. Drips play in EVERY cave once enclosure >= 0.45: dry caves drip too. Nothing knows wet from dry.
4. Depth is not measured: enclosure eases over 2 s, so the outside air is gone (or equally loud) in seconds, not by distance.

## Design
1. **Depth** (new, `depth_m`): metres walked inside rock. While rock_enclosure >= 0.5, add the horizontal distance moved each frame; below 0.3, let it fall 3x as fast as you walk out (so the mouth sound returns as you leave); in between hold. Standing at the mouth keeps the outside air; walking in fades it; no rays added. If the first scan after login or a teleport is already enclosed, start at the cap (deep).
2. **Air fade by depth**, from a table (data/sound/cave_air.json, no numbers in code): dB per bus at depth 0 / 6 / 25 / 40 m, e.g. Wind and Weather 0, -6, -45, -60; Nature (calls, beds, insects) 0, -8, -45, -60; low-pass 20000, 6000, 1800, 1000 Hz. The enclosure term stays on top for half-open places (overhangs). At -60 dB the bus is muted (no CPU).
3. **Silent base**: no room tone, deep inside the air buses are muted. What you hear is Foley only: steps, tools, digging, breath, body (these already echo through the World reverb bus).
4. **Wet or dry**: wet = the server's leak message (protocol 73: ceiling points with water within 4 m above, up to 24 within 40 m) already feeds drip_view (gap_m, wet_here). Cave sounds reads `wet = clamp(1 - gap_m / 4)` held for 20 s after the last leak message. No new network traffic. Karst sumps (water in the cave floor, tile "water" segments) are not in that message: first version leaves them dry (limit; a later server flag can add them).
5. **Drips and echoes only when wet**: drips need wet >= 0.2 (rate scales with wet, as the leak closeness already does); reverb wet-mix x0.5 in a dry cave (still a little echo on steps: a hole in rock does echo), full in a wet one. Drips go on the Foley bus.
6. **Rig/test**: `--cave=1` stays; new `--cave-depth=M` and `--cave-wet=0..1` to hear a spot without walking. Headless test test_cave_air.gd: walk 25 m in -> -45 dB, walk out -> back, stand at the mouth -> unchanged, table interpolation, dry cave plays no drip, wet cave plays drips.

## Cost
No new rays or buses. One distance integration per frame, bus volumes set only when they change by more than 0.5 dB, one small JSON read at start. Fewer voices playing in caves than today.

## Risks / honest limits
- Walked distance is a proxy for "distance from the mouth" (a cave with a skylight lets air in; a long straight tunnel behaves as expected). A real mouth distance would need cave data on the client.
- Man-made tunnels use the same measure (a long tunnel goes silent too: matches Dave's "nothing unless you work").
- Rain on a skylight or the sound of a river in the cave is not handled here (water_sounds stays as is).
- Not run in Godot in the cloud; Mike's rig pictures cannot show sound: Dave's ear card is the real test (walk in 30 m, then out).

## Open for Tyler (one answer)
The depth table numbers above are my first guess (full silence at 25 to 40 m). GO as written?

## Build notes (25 Oct)
cave_sounds.gd: depth_m (walked inside rock; teleport/first scan starts at the cap or 0), air dB/low-pass per bus from data/sound/cave_air.json (min with the old enclosure cut), wet from the leak gap held 20 s (note_gap, called from terrain_client next to sound.wet.update), drips only when wet (>= 0.2) and on the Foley bus, reverb wet x0.5 in a dry cave. Flags --cave-depth=M, --cave-wet=0..1. Test: src/worldgen/tools/test_cave_air.gd (pure functions, 23 checks). Dave's ear card: walk 30 m in, then out; wet cave drips, dry does not.
