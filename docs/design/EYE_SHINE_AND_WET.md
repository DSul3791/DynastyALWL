# Eye shine and wet looks: data and code plan (MikeW, 8 Nov 2026)

From Kathleen's art_animals.md (#593) sections 6 and 7. This note turns her table into model-row values and a code plan; no code yet.

## 1. Eye shine

**Data (models.json, per species row):** `shine_color` (hex) and `shine` (0 to 3). Values are Kathleen's; colours are the middle of her ranges.

| Species | shine_color | shine | Note |
|---|---|---|---|
| deer (all looks), elk | #e6f5dc | 3 | |
| moose | #f0b45a | 2 | guess |
| wolf, dog | #c8dc5a | 3 | |
| fox | #dcf0b4 | 3 | |
| lynx, puma, lion, leopard, tiger, cat | #b4e05a | 3 | |
| hyena | #c8e05a | 3 | |
| bear, black_bear | #f09a3c | 2 | |
| raccoon | #f0c850 | 3 | |
| horse, donkey | #5ac8b4 | 2 | |
| cow, buffalo, wildebeest | #64c896 | 2 | |
| goat, chamois, bighorn, mountain_goat, pronghorn | #a0d26e | 2 | guess for the wild ones |
| camel | #64c8a0 | 2 | guess |
| elephant, mammoth | #c8d278 | 1 | guess |
| rhino | #b4b48c | 1 | guess |
| seal (code body) | #c8f0e6 | 3 | needs a model first |
| beaver, kangaroo | #e6643c | 1 | guess |
| mink, honey_badger | #c8dc78 | 1 | guess |
| frog (code body) | #c8e0c8 | 1 | |
| rabbit, rat | #dc3c32 | 0.5 | no tapetum: faint red |
| boar, warthog, all birds | none | 0 | never shine |
| goblin | #f0b43c | 1.5 | fantasy, coordinator's proposal |

**Code plan (client, animal_view.gd):**
1. At model build, find the eye surfaces: a material or mesh name containing "Eye" (bear, elk, deer looks, tiger, buck, doe, alligator...). For a model with no eye surface, find the two head-side vertices clusters is too costly; instead place two tiny eye quads on the head bone at a row-given `eye_offset` [x, y, z] (only species that shine need it).
2. Give eye surfaces a small shader (or a second pass) whose emission = `shine_color` × `shine` × the torch light at the eye × a cone factor `smoothstep(cos 30°, 1, dot(eye_forward, to_camera))`, and zero beyond twice the torch's light range. The torch light at the eye: the player's held light only (its position and range, already known to the client), with the usual inverse-square fall-off; daylight, moon and placed fires add nothing.
3. A carcass's eyes lose the term over a few minutes (carcass_look.gd uses the same material).
4. Never through terrain or fur: emission only, no light, no glow pass; depth test as normal.

**Test:** an offline creature check option `--torch=6,12,18` rendering a dark scene with a light at the camera, and Kathleen's night shots on the PC (section 11).

## 2. Wet looks

**Data:** per-row `wet_rough` (roughness when wet, default 0.45) and `wet_dark` (how much darker, default 0.35); birds `wet_shed: true` (only head and neck darken).

**State (client only, nothing on the wire):** each drawn animal keeps `wet` 0 to 1 and `wet_line` (a height on the body):
- In water (its position below the water surface, the same test as the swim role) or wading: `wet_line` = water surface height above its feet, `wet` 1 below it.
- Rain: `wet` rises to 0.5 over a few minutes.
- Out of water: `wet` falls to 0 over about three game minutes; `wet_line` stays as the dark band until then.

**Code plan:** the model's materials get two uniforms (`wet`, `wet_line` in model space); the fragment darkens albedo by `wet_dark` and lowers roughness toward `wet_rough` below `wet_line` (smooth over 5 cm) times `wet`. Birds with `wet_shed` only use it on the head. The shake clip (Kathleen 7.1) plays once when `wet` passes 0.8 and the animal leaves the water, if the row names one.

**Order:** eye shine first (small, visible at night, ties to the torch and wolves), then wet (needs the swimmers in #589 and #590).

## 3. The crow's length (Kathleen's check 10.4)
`length_m` is 0.25 on main and on every branch. It is the **bone** length: the model is sized by its bones (in its Walk pose, `size_clip`), and its feathers reach about twice past them, so the crow is drawn about 0.48 m from bill to tail on the 1 m grid of the creature check. That matches a real carrion crow (0.45 to 0.5 m). No change; the row note says so.
