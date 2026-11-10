# Felled crowns and held E (Dave, 10 Nov 2026)

Dave's words: "when you fall a tree the upper half of the tree should flatten an area the size of that trees canopy and drop like 30 sticks and a hundred
leaves all over the forest floor in that circle but when you pick up the sticks and leaves by holding down the E key it picks them up in batches of 10 or
20 each. leaves should be 20". Then: held E "should then try to pick up the next closest thing because it might be lighter", "it should always try to pick
up whatevers under the reticule first", and "there should also be a 2 second pause between pickup the reticule to picking up surrounding".

## The crown lands

- On the fall, the server works out the crown circle (`server_items._crown_circle`) and puts it on the trunk row as `crown: [x, z, radius]`.
  - The radius is the canopy's own size, `Cover.crown_radius(crown_m, reference height, height)`. That is the same drip line the rain cover uses, with
    `crown_scatter.min_radius_m` as the smallest.
  - The centre is the middle of the crown's part of the trunk as it lies. `crown_from` 0.5 means the upper half.
- When the client's fall tween ends (1.5 s), the grass in the whole circle lies down: `grass_view.flatten` → `grass_trample.stamp_circle`. It stands up
  again like trodden grass (`data/look/grass_trample.json` `recover_s`). The ground's shape does not change. Shrubs stay standing.
- When the trunk breaks up (`split_trunk`, or `_split_small` for a sapling-sized one), the sticks and leaves drop all over the circle
  (`_crown_litter`). The amounts are set in `drops.json` `trunk.crown_scatter`:
  - `sticks_per_m` and `leaves_per_m` per metre of tree. A 15 m tree drops about 30 sticks and 100 leaves.
  - `spots` sets how many little heaps each one is spread over.
  - Conifers (`crown_leaves.fixed`) and bare broadleaves in winter drop sticks only.
  - The split no longer also drops the branch rows beside the trunk.
  - A trunk saved before this change has no circle. It, and a trunk cut by hand, still give the branch rows (`_branch_rows`, with sticks only for
    conifers now).

## Held E

All numbers are in `data/items/pickup_batch.json`.

- **Batches.** One E on sticks or leaves takes up to `batch` of them (10 sticks, 20 leaves). It takes from the heap picked first, then from the nearest
  heaps of the same item within `gather_m` that are in reach (`server_items._pickup_batch`). The server refuses (reason 2) only when none could be
  taken. The leaves' pile handful is 20 too.
- **Reticle first.** Held E repeats on the item the reticle is on, every `batch_every_s`. Once that item is gone, held E waits `reticle_pause_s` (2 s, a
  trial) before it sweeps what lies around.
- **Too heavy is not a stop.** The client judges each item with the server's own carry rule (`CarryRules.fit_count`, plus a large log needs an empty
  shoulder). An item the server refuses is passed over until E is let go. Held E goes on to the nearest thing that can be taken. "Too heavy to carry
  any more" shows only when nothing in reach could be taken: once per hold, or on release after a tap that nothing else answered.
