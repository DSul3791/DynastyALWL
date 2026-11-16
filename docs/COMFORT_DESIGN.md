# Comfort and the Rested buff

**Scope/status:** director intent plus tuning and integration reference. Dave's requests below, the 31 Oct fixed-duration ruling and the 10 Nov shelter-height ruling have recorded attribution. Radius, point values, tiers and remaining proposals are tuning, not blanket director approval. [Master catalog](design/DYNASTY_MASTER_ITEMS.md) owns furniture identities, grades, recipes and food-effect interactions; this file owns comfort behavior. No new runtime/visual validation is claimed.

Dave's request: "bring in the comfort concept from Valheim where you place different items around you: a more comfortable bed, a more comfortable chair, a chandelier, torches, fires, fireplaces and other such nice things to improve your comfort level; having your comfort level up and being well rested gives you a bonus on your health and your exhaustion depletion, and all of your actions." And, refining it: comfort items count when you are NEAR them; you do not have to be inside the lean-to. "Build your lean-to under the shelter of a tree and the tree provides your shelter if you are not in the lean-to, then a chair gives another comfort point and the fire gives another."

## 1. Comfort calculation
Comfort is shelter + nearby different comfort pieces; five identical chairs do not stack. The data defaults are radius 9 m, vertical tolerance 3 m (same-floor approximation), recheck/cache 1.5 s and cap 20. Standing near the items shows comfort; resting earns Rested. Without shelter, level is 0 and furniture contributes nothing. Fires, torches, chandeliers and fireplaces count only while lit.

Count an ungraded kind once, only the best bed, and only the best grade per graded family (chair, bench, table, board chest). A bench and chair can both count; grades within one family cannot stack. Wagon beds participate in the same one-best-bed rule (master catalog). Bare shelter is 1; shelter + rough bed is 2, enough to earn Rested.

## 2. Sheltered (the exact rule)
Use the shared `Cover.at`/server cover query, covering built roofs (lean-to or roof piece) and grown tree crowns. Dave's 10 Nov ruling: only trees at least 4 m tall count (`SHELTER_MIN_HEIGHT_M`), whatever the species; the former 80%-of-species-height threshold is superseded (a 13 m oak had given no shelter). Tree cover uses crown radius `SHELTER_RADIUS`/`crown_m`; built box/disc roofs require the player inside their footprint and between floor/top.

A tree can shelter the camp without a lean-to, and furniture need not be inside it. The lean-to's recorded dimensions are 2.6 x 3.4 m, height 1.5 m, with rain/sun cover; it supplies shelter, not extra comfort points of its own. Without cover: "You are not sheltered: nothing here comforts you."

## 3. Comfort kinds and tuning
Recorded point schedule, reconciled with graded families; current configured values/status are in `data/items/comfort.json`. Availability belongs to current catalog/data, not this table.

| Class | Kinds and points |
|---|---|
| shelter | sheltered +1 (once) |
| bed (only the BEST bed in range counts) | rough bed 1, straw bed 2, feather bed 4, canopy bed 5 |
| seat (graded families, chairs and benches: each counts once at its BEST grade in range, Mission 001 master s3.5) | log seat 1, stool 1; graded: Crude chair 1, Crude bench 1, Rustic chair 2, Fine chair 3, Fine bench 3, Ornate chair 4 |
| table (graded tables count once, at the BEST grade in range) | workbench 1; graded: Crude table 1, Rustic table 2, Fine table 3, Ornate table 4 |
| rug | hide rug 1, wool rug 2 (both count) |
| fire (LIT only) | campfire 1, clay hearth 2, fireplace 4 |
| light (LIT only) | wall torch 1, candle chandelier 3 |
| storage | wicker chest 1; board chests (Crude, Rustic, Fine, Ornate) 1, counted once as one family |
| door, window | a doorway piece 1, a window wall 1 |
| decor | flower pot 1, antler mount 1 |

Both rug kinds may count. Example: shelter 1 + straw bed 2 + bench 1 + workbench 1 + lit campfire 1 + chest 1 = 7. A fine house can reach the cap of 20; cap the actual deduplicated sum rather than relying on old all-items totals.

## 4. Rested duration and effects
Earn at comfort >=2 by sleep/lying in a bed, sitting on a seat for 30 s, or lying on bare ground for 60 s. Dave's recorded 31 Oct ruling fixes ordinary duration at **45 real minutes at every level**; comfort scales bonuses, not time. Ground lying earns half duration (22.5 real minutes). Convert using `GameClock.RATIO` when game-time units are needed (recorded ratio 24: 18 game hours per 45 real minutes), never hard-code game-unit duration.

Capture level/tier when earned; moving away does not recompute it. A completed rest at an equal/higher level refreshes the timer and a higher level replaces the tier; a lower level changes nothing. Buffs do not stack; retain across save/load and clear on death.

| Comfort at the moment | Health regen | Exhaustion (energy and strain) | Hunger and thirst drain | Action speed (crafting, tool blows) | Skill gain | Cold stress |
|---|---|---|---|---|---|---|
| 2 to 4 | +10% | -10% | - | - | - | - |
| 5 to 9 | +20% | -15% | -3% | - | +5% | - |
| 10 to 14 | +30% | -25% | -5% | +3% | +8% | -5% |
| 15 and up | +35% | -30% | -6% | +5% | +10% | -8% |

These modest tuning values supplement food and fire. With sleep (`bed.json` recorded regen_mult 1.25/drain_mult 0.5), use the larger health-regeneration benefit, not a product. Master catalog §3.16 owns food interactions: Rested skill gain applies to skill practice, never Fitness XP; food and Rested skill increments combine under the catalog cap, while other food/Rested/bed benefits take the larger effect. Do not independently retune those rules here.

## 5. HUD and messages
Retained presentation proposal: hearth/comfort number (grey 0–1, warm >=2), moon-and-cup Rested icon with real-minute countdown. Existing HUD line/tooltips are implementation, not proof these proposed icons are complete.

Example tooltip: "Comfort 7 (sheltered +1) / Bed +2, Bench +1, Campfire +1 (lit), Workbench +1, Chest +1 / Missing: a rug, a lit torch / Rested: +20% health regeneration, -15% exhaustion, 24 min left".
Messages: "You feel rested." / "You no longer feel rested." / "You are not sheltered: nothing here comforts you." / "It is too bare to rest well here (comfort 2 needed)."

## 6. Furniture and catalog boundary
Retain the comfort roles: log seat, stool, graded chairs/benches/tables, beds, rugs, fires/fireplace, lit wall torch/chandelier, chests, doorway/window, flower pot and antler mount. Model priority recorded with the original proposal: log seat/bench first, then chair, table, hide rug, wall torch, straw bed, chandelier, fireplace. This is a design reference, not a current assignment queue.

Use master catalog §§3.5/5 and current blueprint/structure data for names, IDs, costs, stations and availability. The old 14-kit recipe list, all-locked claims and unlock lists are superseded snapshots, not crafting instructions. Historical sourcing update 31 Oct: wool rug was relocked for lack of wool; feather/canopy beds switched from wool/linen to Fibre cloth. Original costs, item/recipe/state allocations and the hand-woven Fibre-cloth recipe are recoverable in the source below; do not reinstate them over later catalog decisions.

## 7. Integration and acceptance checks
`server_items.gd::comfort_at(peer)` returns `{level, sheltered, items:[{id,points,lit}], missing}`. Cache per player; read placed world-item state -> structure's `comfort` id -> comfort kind (or matching kind fallback). Apply the dedupe, light, cover, distance and cap rules above. `gap_exempt` furniture bypasses the placement gap; bed/roof support and hanging-light placement still need their own rules.

Retain checks in `test_comfort.gd`: outside cover 0; shelter alone 1; rough bed +1; repeated chairs once; best bed only; best grade/family once; unlit fire 0/lit 1; cap 20; level 2 and 10 both earn 45 real minutes; equal/higher rest refreshes, lower rest leaves buff unchanged; bed/Rested regen takes max; save/reload retains Rested. Sitting, ground lying, death and food-effect interactions need their relevant checks too. Listing a test is not a PASS result.

## 8. Open design questions
Original author defaults, **not director decisions**: walking-speed bonus [no]; pause buff outside shelter [no, timer runs]; NPC houses/reputation using player comfort [later]. The running-timer behavior is recorded in §4; this cleanup grants no new approval to the defaults or NPC idea.

## 9. Inspiration and sources
The 31 Oct author used Valheim as inspiration, not Dynasty authority: guides differed on starting duration (about 7–8 min plus 1 min/level) and range (one said about 10 m). "Each kind once" was attributed to Dave but was not explicit in the consulted guides. Links retained: [ExitLag](https://www.exitlag.com/blog/valheim-comfort/), [PC Gamer](https://pcgamer.com/increase-valheim-comfort-level-max), [Mobalytics](https://mobalytics.gg/gamebase/guides/valheim-comfort-rested-guide), [Indifferent Broccoli](https://wiki.indifferentbroccoli.com/en/Valheim/Comfort), [Corrosion Hour](https://www.corrosionhour.com/valheim-how-does-comfort-work/). No Rust/Vintage Story/Sims research was claimed.

## 10. Integration reference
This replaces the repeated 31 Oct "code needed" list. Static code contains comfort, Rested and seat paths; it is incorrect to say nothing is coded. Current behavior still requires appropriate tests/player evidence.

1. **Comfort query:** `server_items.gd::comfort_at`, `data/items/comfort.json`, shared cover query. See §§1–3/7.
2. **Rested storage/hooks/HUD:** inspect `server_items.gd` comfort functions and [network protocol](../PROTOCOL.md). The old `{level,until_game_s}` design sketch is not the stored schema: code uses `rested` with `level` and `until` Unix seconds. Preserve compatibility; do not migrate it during docs cleanup. Hooks cover health regen, energy/strain exhaustion, hunger/thirst drain, crafting/tool pace, `practice()` skill gain and warmth/cold stress. The original proposed wire sketches do not override current protocol messages.
3. <a id="sitting"></a>**Sitting (legacy reference §10.3):** Dave, 5 Nov: "we need a sitting on a chair action". E on log seat/stool/bench/chair sits; hold E takes the object down. `use:sit` rows carry `sit_face`: chair front(-Z), bench side approached/nearest `sit_spots_x`(-0.6,0,0.6), log seat/stool free facing. `dynasty_body.gd::sit_chair` holds Chair_Sit_Idle_M (source hips 0.51 m); movement/X/Z exits, recorded stand-up offset 0.7 m forward. Later body note adds X beside/inside a seat and `_seat_lift` placing hips 0.07 m over the seat. Server proximity threshold recorded 1.2 m; sitting 30 s at comfort>=2 earns Rested. Remote players were reported to see ground sit; whether that gap is fixed is unverified here.
4. **Beds:** sleep lookup must include rough, straw, feather, canopy and later catalog bed variants, applying one-best-bed. Original points 1/2/4/5 are in §3; avoid rough-bed-only lookup.
5. **Lit fixtures:** only lit lights count. Original fuel proposal: stick for torch, candles for chandelier, firewood for fireplace; use current data for actual fuel. Campfire/hearth use existing fire state.
6. **Placement:** wall torch/antler mount need a wall (floor placement was only a provisional fallback); chandelier hangs from roof. `structures.json` uses `comfort`, `gap_exempt`, `lights`, `shelter_needed` as applicable.
7. **Tests:** §7 and the relevant persistence, food, sitting and fixture checks. This cleanup ran no Godot tests.

Source: [31 Oct–10 Nov design and integration notes](https://github.com/DSul3791/DynastyALWL/blob/5352ecf4426adb164d81e8385ad2aaa9744a5992/docs/COMFORT_DESIGN.md). Personal rosters, obsolete kit recipes and superseded progress reports are preserved in Git history rather than duplicated as current instructions.
