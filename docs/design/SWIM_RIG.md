# Whales and dolphins posed from their spines (MikeW, 8 Nov 2026)

The same treatment as the posed birds (BIRD_FLIGHT.md part 3), for Dave's other two Meshy models: a whale and a dolphin may come with
a good skeleton and few or no clips, so the swimming is built from their own spine bones in code. Behind `swim_rig` (off); it runs
only for a row that asks for it (`posed_swim: true`, set in both pending rows) or names no swim clip. SEA_MAMMALS.md has the sea
path (the server's pod and whale, the blow spout); this note is the body.

## How they move (in life)
- **Up and down, not side to side.** Whales and dolphins beat their flukes vertically; the wave runs from the chest to the tail,
  small at the front and growing to the flukes.
- **Tail beat:** a large whale about once every 4 seconds cruising (0.25 Hz), a dolphin 1.5 to 2 beats a second (1.6), faster when
  it hurries.
- **Flippers** steer and stroke a little against the beat.
- **Porpoising:** a dolphin at speed leaps clear in low arcs, nose up as it rises, nose down as it re-enters.
- **Blow:** at the surface, every 20 to 60 s for a whale (a 4 m spout), 8 to 20 s for a dolphin (a small puff); SEA_MAMMALS.md.
- **Breach:** a whale hurls itself clear now and then; that is a one-shot server event still to come (Steve), not a pose.

## Bones the code looks for (any naming; the row's `spine_bones` list wins)
| Part | Words in the bone name |
|---|---|
| spine chain, in skeleton order (parents first) | spine, back, chest, tail, caudal, fluke |
| flippers | flipper, pectoral, fin |
At least two spine bones are needed; with fewer, a log note (`posed swim: no spine chain found`) and the clips or the swim block only.

## The poses (bone_offsets.gd state poses, about the row's `swim_axis`, default x: up and down)
| State | Pose | Numbers |
|---|---|---|
| 0 at the surface | a slow, small wave: a third of the swing at half the beat | |
| 1 travelling | the wave from chest to flukes, each bone 0.35 of a beat later along the chain and wider (a quarter of the swing at the chest, all of it at the flukes), at `sea.tail_hz` | `swim_swing_deg`: whale 8, dolphin 14; `tail_hz`: whale 0.25, dolphin 1.6 |
| 2 hurrying | the same at 1.6 times the beat and 1.3 times the swing | |
| flippers | a small stroke (0.4 of the swing) half a beat out of step | |
| porpoising | `_porpoise_pitch`: on the dolphin's hop arc the Rig (through `LifeUtil.rig`) pitches nose-up rising and nose-down falling, up to 34 degrees | the row's `hop.run` (bound 6 m, arc 1.2 m) |
A wrong axis or sign shows at once in the Dino strip; the row's `swim_axis` or a negative `swim_swing_deg` fixes it without code.

## Check
Run sheet m50: the alligator posed from its own spine with `--swimrig --posed` as a stand-in (its spine is the same kind of chain;
an alligator swims side to side, so the stand-in proves the bone search and the wave, not the axis). The Meshy rows in DINO_SHOTS.md.
