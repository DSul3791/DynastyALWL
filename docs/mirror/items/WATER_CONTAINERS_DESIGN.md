# Water containers: waterskin, clay pot, bucket (job 88, design note, no code)

Fits the thirst system as built (protocol 24, vitals.json "thirst"): a full body holds 2,400 ml and lasts at least a game day; a mouthful at the water's edge gives 300 ml (one per press, about one a second at most); drink items give ml from the `drink` table (empty today). No container exists yet, so you can only drink where water lies at your feet.

## The three containers
| Item | Holds | Made from | Notes |
|---|---|---|---|
| Waterskin | 1.5 L | Hide (hunting prerequisites) or leather + cordage | Light, carried on the hotbar; the first container once hides exist |
| Clay pot | 3 L | Clay (dug now, job 84) fired at a campfire | Heavy, breaks if dropped hard; a stationary store at camp, still carryable |
| Bucket | 8 L | Lumber + cordage | For carrying water to a camp, a garden or a trough; too heavy to drink from on the move |
| (Stone-age stopgap) | 0.3 L | Hollow wood bowl from a log | Optional; lets a player carry a little water before hides or a kiln |

Weights: water is 1 kg per litre, plus the empty container. A full bucket is about 8.5 kg, the pot about 4 kg full, the skin about 1.7 kg. The weights audit already counts anything in the pack, so a full bucket drags you toward the 80 percent carry line honestly.

## How filling and drinking work
1. **State on the item.** A container stack of 1 carries `ml` (0 to its capacity) beside its wear. One new per-item field, saved with the pack (inventories.json), neutral default 0; old files read as empty. Stacks of containers with different fill do not merge.
2. **Fill (E at the water's edge, or on a river or pond):** with a container in the hotbar and water within reach (the same check as drinking), E fills it at the server's drink pace instead of drinking. One new action (ACT_FILL, or ACT_DRINK with a flag); protocol bump when built.
3. **Drink from it (Use / E on the held container):** takes a mouthful (300 ml, data) into thirst, same pace as drinking, the rest stays. Empty thirst is capped at the body cap, so the container keeps what the body could not take.
4. **Pour out (Drop D on a container, or Shift+D):** drops the container and spills its water; a separate "Empty" button later.
5. **Dirty water:** pond and slow river water could carry sickness later; the container records where it was filled (`source`), so a purify step (boiling in the pot on a fire) can be added without changing the format. Not built; thirst has no sickness today.
6. **Use in recipes:** potions and cooking (broth, boiled food) ask for water in a pot; a recipe line "1 L water" is checked against the container's `ml`. Not in the first build.

## Server pieces
- items.json: three items with `capacity_ml`, `kind: container`; weights.json: empty weights; recipes for the pot (fire) and the bucket (lumber).
- Inventory slot gains an `ml` array next to `wear` (see Inventory.wear); `_fill_container`, `_drink_from`, spill on drop; carry weight = empty + ml / 1000.
- Protocol: slot rows gain a fill value; ACT_FILL. PROTOCOL.md entry, save version bump with neutral default, cost at Low stated when built (a few bytes per container slot, no per-frame client work).
- Client: a fill bar on the slot (a thin line like the wear line), "Fill (E)" prompt at water, tooltip "1.2 L of 1.5 L".

## Order and dependencies
Needs hides (waterskin; hunting note), kiln or fire for clay (pot; clay now exists), lumber (bucket; parked with the saw mill). The first useful build is the wooden bowl or the pot, since clay is already dug.

## Questions for Dave (not blocking)
- Is carrying water to a camp (bucket) a feature, or is drinking at the source enough for the first release?
- Should a waterskin leak or dry out over time? Recommended: no.

## Decided by Dave (2026-10-21): keep it light
No dirty water and no sickness. Dropping a container never spills it: you can drop a container and its water stays in it. (Built that way in job 89.)
