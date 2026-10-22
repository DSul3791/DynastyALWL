# Hunting and animals: what the item side needs (job 83, note only, no code)

For Technical direction. No animals exist yet; this lists what Items must have ready so a creature thread can plug in without redoing items.

## Already there
- Weapons with a `damage` number in items.json: spear 8, wooden spear 6. Wear per throw or jab (placeholder 1) through the tool-wear table.
- Stone knife (class knife) for butchering; a held-tool arm animation set (swing, jab, throw, use).
- One luck function for every roll, one drops table, `inspect` look-alikes and `familiarity` fields that animals will carry too.

## New items (all data, none built)
| Item | Notes |
|---|---|
| Raw meat | Food, spoils (see below). Weight per cut by species size. |
| Hide (raw) | Material, heavy, spoils slowly unless scraped or salted. |
| Bone, sinew, fat, feathers | Crafting inputs: needles, cordage, glue, arrows. |
| Roast meat | Cooked by a campfire, a long-lasting food. Reuses the roast logic. |
| Leather | Later, from a tanning step. Parked until Dave decides crafting depth. |
| Bow, arrows | Parked; the spear is the first hunting tool. |

## Hooks the server needs
1. **Damage hook**: `damage(target, amount, source_peer, kind)` called by the hit action. Spear damage already exists; add a bonus from skill later. Weapon wear charged per hit.
2. **Corpse as a world entity**: an animal that dies leaves a carcass entity (same shape as a felled trunk: owner none, decays). Working it with a knife gives parts one blow at a time, like `ACT_PROCESS`. No knife: you may drag nothing, only take scraps (rewards carrying a knife).
3. **Carcass loot table** in the drops file: per species `[item, min, max]` rows, rolled through `roll_amount` and `roll_chance`, so luck applies. Size scales yield (a deer feeds many days; a rabbit a meal). Same data shape as `trunk`.
4. **Spoilage**: meat and hide get an age; a raw item rots after N game hours (data), cooked lasts longer. Needs per-stack age in the pack: this is the one real item-system change (stacks of different age do not merge). Protocol cost stated when built.
5. **Carry weight**: a whole carcass is far over the carry limit (deer ~80 kg). Dragging or butchering in place is the rule; the weights sheet already refuses picking up over the limit.
6. **Hunger link**: meat kcal goes in the vitals food table (raw meat low, roast high). Eating raw may need a small penalty (data), not built.

## Questions for later (not blocking)
- Does a wounded animal flee and leave a blood trail? (creature thread)
- Do hunters need to learn to butcher (a skill that raises yield)? Skills are already planned to feed from use.
- Is hunting legal or limited by a town? Town spirit and ownership are future.

## Order I would build in
Damage hook plus carcass entity plus carcass table (one push), then meat and hide items and roasting, then spoilage. Each is its own protocol-cheap step; nothing needs to wait on animals actually existing, because an admin command can drop a test carcass.

## Status (Items, 2026-10-21 refill 11)
Data is in, all marked future until animals exist: raw_meat, roast_meat (Roasted meat), sinew, animal_fat, feather (items 68 to 72), sinew_cord recipe, meat kcal in vitals.json (raw 250, roasted 700), spoilage (raw meat 18 h, roasted 48 h, times the gentle multiplier of 4), cooking.json `cooks_into` (raw_meat becomes roast_meat at a fire) and `raw_unsafe` (eating raw meat makes you sick, from Tyler's note: wrong-raw means mild sickness, not death), and data/items/carcass.json (per species parts [item, min, max], size_kg, knife class, 4 blows: rabbit, grouse, fox, boar, deer, wolf). Already built: spoilage ages in the pack (no longer the open item 4), hot meals warm, clothing slots for hides (cloak, boots, hood, mittens, leggings). Still to build when the creature thread exists: the damage hook, the carcass entity, reading carcass.json with roll_amount, and a test carcass admin command.
