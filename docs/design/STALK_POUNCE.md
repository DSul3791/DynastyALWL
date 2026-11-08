# Stalk and pounce posture for predators (MikeW, 8 Nov 2026; design)

The server already sends what a predator is doing: wolves `STALK` (6) while the pack closes in and `ATTACK` (7) on the rush (`server_wolves.gd`); a thief (fox, raccoon) `SNEAK` and `CARRY` (`server_thieves.gd`); big game `WARN` (10) and `CHARGE` (11). On the client every one of these plays the walk or run clip by speed, so a stalking wolf trots upright and a sneaking fox walks like any fox.

## What it should look like
- **Stalk / sneak:** body low (about 75% of standing height), head lower than the shoulders and level, ears forward, tail low and still, slow deliberate steps (the walk clip at half rate, and longer pauses between steps), each forepaw lifted higher and set down softly. Stops and freezes for 1 to 3 s when the prey looks up (the head-tracking target looks toward it).
- **Pounce** (the last 3 m of an attack on small prey; fox and lynx at a rabbit, later at a bird): a short crouch-and-rear (0.2 s, hindquarters lower), then a leap on an arc (lynx up to 1 m high and 4 m long, fox a mousing jump straight up and down onto the spot), forepaws first.
- **Rush** (wolves `ATTACK`, big game `CHARGE`): already the run or sprint clip; add ears flat (the ears layer does it for 10, 11, 16; add 7) and head forward.

## How (the same bone layer)
1. **Crouch:** a `state_poses` entry keyed by the stalk states (6 for wolves, the thief's `SNEAK` number for fox and raccoon, a lynx stalk when the server has one): spine and neck pitched down, hind and fore upper legs bent (the knee and hip angle from a `bone_offsets`-style table), tail bones lowered and their `tail_motion` scale set to 0 in that state.
2. **Slow steps:** while in a stalk state, the walk clip plays at half its matched rate (`stalk_rate` 0.5 in the row), so the feet still match the ground at the lower speed the server sends.
3. **Freeze:** when the nearest grazer's head-tracking weight rises (it looked up), the stalker's clip pauses (`speed_scale` 0) for 1 to 3 s: client-side only, the server keeps its own timing; the freeze is a visual hold, not a stop.
4. **Pounce arc:** when the server's state turns to attack within 3 m of a small prey, the hop-arc code (HOP_ARC.md) runs once with a pounce profile (`pounce`: rear 0.2 s, `arc_m`, `bound_m`), the clip's jump clip if the file has one (lynx `low_pose_to_jump_fwd_01`, fox `Jump`), else the run clip frozen at its stretch frame.
5. **Data:** `"stalk": {"states": [6], "pose": {...}, "rate": 0.5, "freeze_s": [1, 3]}`, `"pounce": {"clip": "...", "arc_m": 0.8, "bound_m": 4}` on wolf, fox, lynx, puma, lion, leopard, tiger, cat, raccoon.

## Check
`creature_motion --kinds=wolf --state=6 --speed=1` (stalk), `--kinds=fox --state=<SNEAK>`, and a pounce strip (`--state=7` with a target 3 m ahead); then a live hunt picture.

## Wind (Jamie's #637), for the same layer later
Wind m/s = 20 × wind^1.3 (0.15 a breeze, 0.5 small trees sway, 0.9 a gale), gusts about 1.5× the mean. Above about 0.5: ears laid back a little (the ears layer, a wind term) and the tail swinging with the gusts (the tail layer, a wind term); a fur ruffle needs the coat shader and comes with the wet line.
