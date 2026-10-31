# Comfort and the Rested buff (Sal, 2026-10-31) [Proposed]

Dave's request: "bring in the comfort concept from Valheim where you place different items around you: a more comfortable bed, a more comfortable chair, a chandelier, torches, fires, fireplaces and other such nice things to improve your comfort level; having your comfort level up and being well rested gives you a bonus on your health and your exhaustion depletion, and all of your actions." And, refining it: comfort items count when you are NEAR them; you do not have to be inside the lean-to. "Build your lean-to under the shelter of a tree and the tree provides your shelter if you are not in the lean-to, then a chair gives another comfort point and the fire gives another."

Owners: design and data Sal (this file, data/items/comfort.json, 14 locked kit items); server code Tyler; models Kathleen. Nothing is coded yet.

## 1. The rule in one paragraph
Your **comfort level** (0 to 20) is 1 for being sheltered, plus the points of every DIFFERENT comfort piece within 9 m of you (on the same floor), each kind counted once (five chairs count as one chair, so players vary their camp). Fires, torches and chandeliers count only while LIT. At level 2 or more, sleeping, lying, or sitting on a seat for a while earns the **Rested** buff, which always lasts **45 real minutes** (18 game hours) and gives bonuses that grow with the level: health regeneration, exhaustion, hunger and thirst drain, action speed, skill gain and cold. The level also shows while you stand awake near the items; the buff is what you EARN by resting there.

## 2. Sheltered (the exact rule)
You are sheltered when ANY of these holds at your feet (the cover the game already knows):
1. you stand under a built roof: a lean-to, or any roof piece (Cover roofs, `Cover.at` returns 1.0 for a box or disc roof you are inside, y between its floor and top);
2. you stand under a **grown tree crown**: `Cover.at` through the tree index, only trees at 80 percent of their species height count (`SHELTER_MIN_SCALE` 0.8, disc radius `SHELTER_RADIUS` crown_m);
3. you are inside the lean-to (it is a roof, so rule 1).
So a camp can have its lean-to or only a big tree; the comfort items need not be inside the lean-to. The lean-to is shelter only: today 2.1 m high, 2.2 x 1.9 m, rain and sun cover. Comfort comes from what you place around it. If you are NOT sheltered, the furniture adds nothing (message "You are not sheltered: nothing here comforts you.").

## 3. What counts (data/items/comfort.json `kinds`)
| Class | Kinds and points | Status |
|---|---|---|
| shelter | sheltered +1 (once) | rule |
| bed (only the BEST bed in range counts) | rough bed 1, straw bed 2, feather bed 4, canopy bed 5 | rough bed live (bed.json comfort 1), rest future |
| seat | log seat 1, bench 1, chair 2 | future (log seat and bench are the cheap first items) |
| table | workbench 1, table 2 | workbench live, table future |
| rug | hide rug 1, wool rug 2 (both count) | future |
| fire (LIT only) | campfire 1, clay hearth 2, fireplace 4 | campfire and hearth live, fireplace future |
| light (LIT only) | wall torch 1, candle chandelier 3 | future |
| storage | chest 1, plank chest 1 | live |
| door, window | a doorway piece 1, a window wall 1 | live |
| decor | flower pot 1, antler mount 1 | future |
A kind counts once however many you place. A sensible camp: shelter 1 + straw bed 2 + bench 1 + workbench 1 + lit campfire 1 + chest 1 = **7**. A fine house: shelter 1 + canopy bed 5 + chair 2 + table 2 + rugs 3 + fireplace 4 + chandelier 3 + wall torch 1 + chest 1 + door 1 + window 1 + pot 1 = capped at **20**. The sum of everything is 39, so the cap of 20 matters. The existing rough bed (comfort 1 in bed.json) is the starting point: a bare lean-to with a rough bed is comfort 2 (shelter + bed) and just earns the buff.

## 4. The Rested buff
Earned (comfort 2 or more at that moment) by: sleeping or lying in a bed; sitting on a seat for 30 s; lying on bare ground for 60 s (a half-length buff, see below). Duration is **fixed: `comfort_buff_real_minutes` = 45 real minutes** at every level (Dave, 31 Oct): the level scales the bonuses below, not the time. In game time it is computed from the game clock (`GameClock.RATIO` = 24 game hours per real hour, so 45 real minutes = 18 game hours), never hard-coded in game units. Resting again **refreshes** the 45 minutes while the comfort level is at least that of the current buff (a higher level also raises the tier); resting at a lower level changes nothing. It does not stack.
| Comfort at the moment | Health regen | Exhaustion (energy and strain) | Hunger and thirst drain | Action speed (crafting, tool blows) | Skill gain | Cold stress |
|---|---|---|---|---|---|---|
| 2 to 4 | +10% | -10% | - | - | - | - |
| 5 to 9 | +20% | -15% | -3% | - | +5% | - |
| 10 to 14 | +30% | -25% | -5% | +3% | +8% | -5% |
| 15 and up | +35% | -30% | -6% | +5% | +10% | -8% |
Kept modest on purpose: it never beats eating or a fire, it only smooths a long expedition. It folds into the existing sleep numbers (bed.json regen_mult 1.25, drain_mult 0.5 while asleep): take the LARGER health regeneration of the two, do not multiply, so a good bed cannot double up. Lying on bare ground at comfort 2 or more earns the buff at half length (about 22 real minutes).

## 5. HUD and messages
- A comfort icon (a small hearth with the number): grey at 0 to 1, warm at 2 and above.
- A Rested icon (moon and cup) with a countdown in minutes.
- Tooltip (Valheim style): "Comfort 7 (sheltered +1) / Bed +2, Bench +1, Campfire +1 (lit), Workbench +1, Chest +1 / Missing: a rug, a lit torch / Rested: +20% health regeneration, -15% exhaustion, 24 min left".
- Messages: "You feel rested." / "You no longer feel rested." / "You are not sheltered: nothing here comforts you." / "It is too bare to rest well here (comfort 2 needed)."

## 6. The new items (all `future`, recipes LOCKED until the model exists)
Fourteen kits, items 487 to 500, recipes 319 to 332: log seat (1 log, keep a stone axe, by hand), bench (3 lumber, 1 twine), chair (4 lumber, 2 twine, 1 hide), table (6 lumber, 2 twine), hide rug (3 hide, 1 sinew), wool rug (4 wool, 1 twine), straw bed (12 straw, 6 sticks, 2 twine), feather bed (a rough bed kit, 30 feathers, 4 wool), canopy bed (a feather bed kit, 8 lumber, 4 linen), wall torch (2 sticks, 1 tallow), candle chandelier (2 lumber, 2 twine, 6 candles), fireplace (24 brick, 4 mortar, 6 clay), flower pot (2 clay, 1 soil), antler mount (2 antler, 1 lumber, 1 twine). All at most 3 kinds. Stations: log seat, rugs, torch and pot by hand; the rest at the workbench (canopy bed and fireplace at level 2). **Model priority (Kathleen): log seat and bench (cheapest, the first comfort item), chair, table, hide rug, wall torch, straw bed, chandelier, fireplace.** Structures (structures.json rows, states 59 and up) are added when each model exists; until then the kit recipes stay locked so a player cannot craft something the client cannot draw.

## 7. Code spec for Tyler
1. **`comfort_at(peer) -> {level, sheltered, items: [{id, points, lit}], missing}`** in server_items.gd, cached per player for `recheck_s` (1.5 s) like bed.json:
   - `sheltered = cover_at(pos) > 0` using the same Cover query the server already uses for rain and beds (roofs plus grown trees); if not sheltered, level 0.
   - Collect placed structures (world items with `struct.kind`) within `radius_m` 9.0 horizontally and `height_m` 3.0 vertically of the player; map kind to `comfort.json kinds[id]`; skip kinds needing light unless lit (fires: `fire_is_lit(state)`; torches and chandeliers: a lit flag when they exist).
   - Dedupe by kind id. For class `bed` keep only the best (highest points). Sum points, add shelter 1, clamp to `max_level` 20.
2. **Rested buff**: stored on the character, `{level, until_game_s}` in characters.json (`rested`); set when the sleep/lie/sit rule completes with `comfort_at >= 2`; `until = now + comfort_buff_real_minutes (45) x 60 real seconds`, converted with the game clock's ratio (GameClock.RATIO, never a literal 24 or 1080). Refresh rule: on a completed rest at level L, if there is no buff or L >= buff.level then buff = {level: L, until: now + 45 min}; otherwise leave it. Clear on death.
3. **Hooks** (read `tier = the highest rested.tiers entry with min_level <= level at the moment of earning`, stored with the buff so it does not change while it runs):
   - health regeneration: multiply `health_regen_per_s` (vitals.json) by `regen_mult`; with sleeping/bed take max, not product;
   - exhaustion: multiply energy `drain_per_game_day` (energy.json) and strain climb (exertion.json) by `exhaustion_mult`;
   - hunger and thirst: multiply the burn terms by `hunger_thirst_mult`;
   - action speed: divide crafting time and tool-blow cooldowns by `action_speed_mult` (`_craft_tick` dt, `HIT_COOLDOWN_MS`);
   - skill gain: multiply the amount in `practice()` by `skill_gain_mult`;
   - cold: multiply the cold stress in warmth.json's formula by `cold_stress_mult` (like bed.json warmth_bonus).
4. **Protocol/HUD**: send `comfort(level, sheltered, [ [id, points, lit], ... ], missing)` when it changes (at most every 1.5 s) and `rested(level, seconds_left)`. Client draws the two icons and the tooltip above.
5. **Tests** (test_comfort.gd): level 0 outside cover; sheltered with nothing = 1; a rough bed adds 1; five chairs count once; unlit campfire adds 0, lit adds 1; the best bed only; the cap 20; sleeping at level 2 earns 45 real minutes and so does level 10 (the tier differs, not the time); a rest at a lower level does not shorten or lower the buff; a rest at an equal or higher level refreshes it; regen takes max with the bed; save and reload keeps `rested`.

## 8. Open questions for Dave (my defaults in brackets)
1. Should Rested also give a small speed (walking) bonus? [no]
2. Should the buff pause while you are not sheltered? [no, it runs on]
3. Should NPC houses count the player's comfort for their reputation? [later]

## 9. References (checked by web search, 31 Oct 2026; guides disagree on details, so treat as a model, not a spec)
Valheim: Rested lasts about 7 to 8 minutes plus 1 minute per comfort level, and comfort comes from nearby furniture and fire inside a sheltered area (sources: [exitlag comfort guide](https://www.exitlag.com/blog/valheim-comfort/), [PC Gamer comfort guide](https://pcgamer.com/increase-valheim-comfort-level-max), [mobalytics comfort and rested guide](https://mobalytics.gg/gamebase/guides/valheim-comfort-rested-guide), [Indifferent Broccoli wiki](https://wiki.indifferentbroccoli.com/en/Valheim/Comfort), [corrosionhour how comfort works](https://www.corrosionhour.com/valheim-how-does-comfort-work/)). One guide puts the practical range at about 10 m. The "each kind counts once" rule is Dave's and the commonly described Valheim behaviour; the results I read did not state it outright. I did not research Rust, Vintage Story or The Sims for this pass, so none is cited.

## 10. Data is in; code list for Tyler (Sal, 2026-10-31)
Done in data: 15 furniture rows in structures.json (states 59 to 73: log_seat, stool, bench, chair, table, hide_rug, wool_rug, straw_bed, feather_bed, canopy_bed, wall_torch, chandelier, fireplace, flower_pot, antler_mount), each with `comfort` (the id in comfort.json `kinds`), `gap_exempt: true`, `lights: true` (torch, chandelier, fireplace), `shelter_needed: true` (beds, chandelier, fireplace). Placed items 502 to 516; kits 487 to 501. Kits UNLOCKED: log seat, stool, bench, chair, table, hide rug, wool rug, straw bed. Still locked and future: feather bed, canopy bed, wall torch, chandelier, fireplace, flower pot, antler mount. Placement: `placement_rules.gd` now skips the 2.5 m gap for `gap_exempt` rows (test line added).
Code needed:
1. `comfort_at(peer)` as in section 7, reading each nearby world item's state -> structures row -> `comfort` id -> comfort.json `kinds`.
2. Rested buff on the character, its hooks (regen, exhaustion, hunger/thirst, action speed, skill gain, cold) and the comfort/rested messages to the client with the HUD icons.
3. Sitting: E on log_seat, stool, bench (three sit spots at x -0.6, 0, 0.6), chair; sit stance at the piece centre, 30 s earns the buff when comfort is at least 2.
4. Beds: bed.json keys the good-bed effect to `rough_bed`; add `straw_bed`, `feather_bed`, `canopy_bed` (comfort points 2, 4, 5) and let sleep find any of them.
5. Lit logic (before we unlock torch, chandelier, fireplace): a `lit` flag per placed light fuelled with a stick (torch), candles (chandelier) or firewood (fireplace); only lit lights count. Fire states for the campfire and clay hearth already exist.
6. Wall pieces (wall_torch, antler_mount) need a wall to hang on (or accept floor placement for now); the chandelier hangs from a roof.
7. test_comfort.gd as listed in section 7.
