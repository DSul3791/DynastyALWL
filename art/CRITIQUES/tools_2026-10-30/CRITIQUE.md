# Critique: held tools in the real game (2026-10-30, Kathleen)

Rig: `tools/look_rig.sh --item ID --cam right --dist 1.6 --at 53270,68440`, third person from the character's right, 12:00 clear. The body is the current ragdoll (restyle pending). Severity 1 minor, 2 should fix, 3 must fix.

| Tool | Picture | Reading | Flaws | Sev |
|---|---|---|---|---|
| Iron pickaxe | iron_pickaxe_held.jpg | reads at once as a pickaxe: wrapped haft, collar, long curved dark head | none; matches the archived note "locked, Dave: excellent" | - |
| Hand saw | hand_saw_held.jpg | reads as a hand saw: toothed steel blade, open handle | blade hangs straight down, handle loop thin at this size | 1 |
| Wooden hoe | wooden_hoe_held.jpg | reads as a draw hoe: long pale haft with binding, bent neck, small blade at the end | haft leans well forward; blade small and the same pale wood as the haft | 1 |
| Stone axe | stone_axe_held.jpg | reads as a hafted axe from the side: lashed head under a swollen haft end | head is a pale blue-grey slab; from this side the wedge taper and edge are lost, so it looks like a block (sunlight bleaches the grey) | 1 |
| Wooden spade | wooden_spade_held.jpg | reads as a staff: the blade is seen exactly edge-on and nearly vanishes | the held pose shows the blade's thin edge to a side camera; the flat of the blade never faces the viewer from the right | 1 |
| Stone knife | stone_knife_held.jpg | a short dark blade out of a wrapped grip; readable as a knife at 1.6 m only | small, dull, dark blade against dark clothing | 1 |

No severity 2 or 3 flaws, so none were changed. Candidates if Dave wants more: a warmer, darker stone for the axe head (`_warm_stone` already exists), a visible blade face for the spade pose, a lighter knife blade.
