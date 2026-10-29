# Rock pile and ground piles: design (Guru, 2026-10-23 03:10 UTC; Dave's idea 02:59)
Design only. Nothing is built tonight. Build AFTER the P1 "Clear dropped items" fix. Owners: Steve (server merge/split), Sal (counts, pickup, item data), Kathleen (generated look).

## What Dave asked
Rocks dropped in one place merge. Up to 5 they look like one rock. Past 5 they become a rock pile model, generated on the fly from the count, almost no limit. Shape: 1 rock on top, 3 under it, then a wider row, and so on; enough rocks add another row.

## Facts from the code (server_items.gd)
- A dropped item is one entry {number, count, pos, left (seconds), wear}; it already holds a count. A pile is therefore ONE ground item with a big count, no new data type.
- Drop is refused when 64 loose items are within 12 m (MAX_DROPPED_NEAR, DROP_CROWD_M). Dropped items despawn after 1200 s (WORLD_ITEM_LIFETIME_S). Saved as one row per item in world_items.json.

## Rules
1. MERGE: when a drop lands (or a loose item settles) within 1.0 m of an existing ground item with the SAME item number and no wear, the count is added to it instead of making a new item. The merge runs BEFORE the crowd check, so merging never fails on the 64 limit. Tools and anything with wear never merge. Placed things (structures, fires, trees, scatter) never merge.
2. LOOK BY COUNT: count 1 to 5: shown as that many single rocks lying close (they can roll when walked over, as Dave wants). Count 6 or more: a pile model made by the client from the count, the item id (random seed for rock sizes and tilt) and the rock kind. No model bytes are sent.
3. PILE SHAPE: pyramid rows from the top: row k holds 2k-1 rocks (1, 3, 5, 7...). Full rows total 1, 4, 9, 16 (k squared). For count n, rows r = ceil(sqrt(n)); the top r-1 rows are full and the bottom row holds n - (r-1)^2 rocks, centred (odd counts look natural because rocks are jittered by the seed). Above about 500 rocks the client stops drawing every rock: a rocky mound (cone with a rock texture and a few big rocks on top) with the same footprint. Footprint radius about 0.45 m x rows, height about 0.35 m x rows, so 100 rocks = 10 rows = 4.5 m wide, 3.5 m high. Kathleen may tune.
4. TAKING: E on a pile takes ONE handful (the same number a hand can carry for that rock: Sal sets, about 5); hold E takes as many as your weight allows. The count drops and the model regenerates. At 5 or fewer it turns back into loose single rocks; at 0 it is removed. Splitting needs nothing extra.
5. ROCK PILE ITEM (sal-rock-pile): crafting 45 stones makes a carried "rock pile" item; setting it down places a pile with count 45. Press E returns 45 stones; hold E carries the pile. This is the same pile with a different way in.
6. OTHER KINDS: the same rule works for any bulk item. v1: stone and rock, soil, clay, sand, gravel and ore get a pile look from data (items.json "pile": {"shape": "pyramid" | "mound"}). Soil, sand, clay, gravel look like a mound. Logs, planks and bricks wait for a later "stack" look (neat rows), but they merge the same way from v1 (count only).
7. MIXED PILES: none. Different kinds near each other stay separate ground items side by side (a pile pushed aside is simplest). A merge needs the same item number.
8. WEIGHT AND COLLISION: pile weight = count x item weight (stone 1.0 kg). A pile of 6 or more is a solid obstacle (cylinder of the footprint) you walk around, like a boulder; you cannot climb it. Loose rocks of 5 or fewer have no collision and roll.
9. SAVE SIZE: one row of 9 numbers per pile, whatever the count. A pile of 10,000 costs the same as one rock.
10. NETWORK: one world item per pile. Adding or taking sends the changed count (an update to one entry), not the whole pile. The client builds the mesh once per count change and caches it by (count, seed).
11. DESPAWN AND LIMIT: a pile counts as ONE item for the crowd limit. Loose items keep the 20 minute timer. Recommendation: a pile of 6 or more lives 2 hours after the last add or take (timer reset on each change), because making piles is real work and losing them in 20 minutes would punish players. Admin switch for the limit stays.
12. CAP: count cap per ground item 100,000 (int stays safe); beyond it the drop makes a second pile next to the first.
13. TEST (next night after build): drop 6 stones in one spot: they become a pile; drop 14 more (20): the pile grows to 4 rows plus 4; hold E to carry; press E to take a handful and watch rows shrink.

## Questions for Dave (one Yes/No card each, posted 03:10 UTC)
rockpile-merge, rockpile-take, rockpile-kinds, rockpile-block, rockpile-despawn, rockpile-big.
