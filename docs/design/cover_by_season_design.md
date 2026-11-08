# Tree cover by season: bare broadleaves shelter nothing in winter

**Owner:** Steve, for `src/shared/cover.gd` (the shared cover index, client and server).
**Research:** Jamie #675 (`docs/knowledge/trees-in-weather.md`, "Shelter" and never-see 6).
**Look it pairs with:** Kathleen #687, the `--bare-winter` bare crowns.
**Decided:** coordinator, 8 Nov 2026. Dave may revert.

## 1. What is wrong today

`Cover.at` gives a yes-or-no "covered" under any tree big enough to stand under (Dave, 30 Oct). The same value applies whatever the tree or the season. So in winter a leafless oak keeps the rain off you, and the ground under it dry, exactly as well as a spruce does. Jamie's never-see 6 is "dry ground under a bare broadleaf in the rain".

## 2. The rule

- **Bare broadleaves:** in the game season "winter", the temperate deciduous broadleaves give no cover.
  - The list is Kathleen's `DECIDUOUS`: oak, beech, birch, alder, willow, maple, sweet chestnut, walnut, witness tree.
  - Under them the rain reaches you and the ground, as in the open.
- **Unchanged:** conifers and the evergreen broadleaves cover all year. Spring, summer and autumn are unchanged for every tree.
- **Kept for bare trees:** a bare tree keeps its crown depth (`crown_depth`), so leaf litter and the bare ground under it stay. `crowns_in`, which grass uses for litter and closure, also keeps bare trees.
- **Not kept for bare trees:** `covers` and `discs_near` skip them in winter. `discs_near` draws the rain and ground-wetness mask, so the wet ground and the warmth rules agree.
- **The switch is Kathleen's `--bare-winter` flag**, read by `cover.gd` on both client and server, so the shelter only changes when the crowns are drawn bare. With it off, nothing changes.
- **Day threshold:** the same as her look, the game season "winter" from the game clock (`GameClock.season()` on the server, `flora_view.season` on the client, which also follows `--flora-day` for the shot runner).

### Why yes or no, and not Jamie's shares

Jamie measured a big conifer keeping off about a third of the rain, a broadleaf in leaf about 15%, and a bare one little. Today the game treats every crown as full shelter: one value, by Dave's rule of 21 Oct, "cover is only mild shelter". Turning cover into shares would change rain, warmth, animals' cover and the ground look all at once. That is a larger change for Dave to choose. This note only stops the bare trees from lying.

## 3. How

- `Cover.add_chunk`'s species `info` row gains a fourth field: true for a deciduous broadleaf. `server_flora` and `flora_view` fill it from the species name with `Cover.is_deciduous(name)`.
- Each index cell keeps a byte per tree in `"b"`, parallel to `"f"` and `"k"`: 1 for bare in winter. `_filter` keeps it in step.
- `Index.leafless` is a bool:
  - the client's `flora_view.set_season` sets it to `season == "winter"`;
  - the server's weather tick sets it from the game clock, under `server_flora`'s mutex;
  - it is always false without `--bare-winter`.
- `covers` and `discs_near` skip a tree whose byte is 1 while `leafless` is true.
- The client's rain mask redraws on a season change, as the crowns already do.

## 4. What changes in play (switch on, winter)

- Rain soaks a player standing under an oak (`warmth.json`'s `covered` test), and the oak does not dry them (`dry_cover_per_h`).
- Animals no longer count a bare broadleaf as rain cover. `cover_stand_m` asks `cover_at`, so deer and stock in the winter rain go to the spruce.
- The ground under a bare oak is as wet as the open.

## 5. Tests

Static checks only in the cloud, per Dave's law. `test_cover.gd` gains:
- a winter oak gives no cover and a winter spruce still does;
- the same oak covers in summer;
- with the switch off, the winter oak still covers;
- `crown_depth` under the bare oak is unchanged;
- `discs_near` leaves the bare oak out in winter;
- felling, which removes an item, keeps the bare bytes in step.

## 6. Not here

- Rain shares by tree (section 2).
- Snow held on conifer crowns. That is Kathleen's `--tree-snow` look (#689) and Sonny's snow window.
- Autumn leaf fall inside the season.
