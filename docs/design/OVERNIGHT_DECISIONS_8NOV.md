# Overnight decisions, 7 to 8 Nov 2026

**For Dave.** You said "you are in charge, keep moving forward". These are the calls the coordinator made for you while you were away. Each one came from an owner's question, and each can be undone. Most new code ships with its switch off, so nothing changes in the game until you turn it on.

Jamie wrote this page on 8 Nov from the pull requests and the project notes. "Merged" means it is on main now. "Open" means it is waiting on David4's gate and Tyler's merge.

## The decisions

| # | What was decided | Who asked | PR | How to undo it |
|---|---|---|---|---|
| 1 | **One temperature.** Every system reads the same air temperature (`Weather.air_c`). The starter island averages 9 °C over the year, ±5 °C between summer and winter, with an 8 °C day-night swing, and it gets 6.5 °C colder per km of height. | Steve, MikeW (Sonny for the numbers) | #620 (merged) | Change the starter row in `src/shared/climate.gd`, or revert #620. |
| 2 | **Fires leave coals and warm ash.** A fire that has burned 10 real minutes leaves coals for 2 real hours, then warm ash for 12 real hours. Wood laid on coals catches by itself. Warm ash relights with tinder. | Steve | #685 (open) | Change the `coals` numbers in `data/items/cooking.json`, or revert #685. |
| 3 | **A big fire survives rain.** A large fire with a coal bed keeps burning in any rain. It burns 1.25 times faster in heavy rain and smokes. Small and medium fires still go out. | Steve | #688 (open) | `cooking.json` `coals` (`rain_burn_from`, `rain_burn_x`), or revert #688. |
| 4 | **Wet wood.** Wood left out in rain gets wet and takes time to dry: kindling 4, firewood 36 and logs 168 game hours. A fire on wet wood burns weaker, longer and smokier. Wet kindling is hard to light. | Steve | #694 (open) | Revert #694. Old saves read as dry wood. |
| 5 | **Cave air.** Deep in a cave the air is the year's average at that height: 5.5 °C at the cave by the spawn. Near the mouth it blends from the outside air to that over 5 to 60 m, by season and by which way the cave slopes. A cave pool's water is the same temperature. Rain and wind do not reach you, and you only dry by a fire, except slowly at a winter mouth. | Steve (Jamie's caves pages for the numbers) | #667, #715 (open) | Remove the `cave_climate` block in `data/items/warmth.json` to get the plain #667 cave back. Revert #667 for no cave shelter at all. |
| 6 | **Puddle times.** Puddles drain in 3 hours on turf, 2 on leaf litter and 1 on gravel. On clay they last 3 days in summer and 10 in winter. Peat bogs never drain. | Kathleen (Jamie's soils page) | #693 (merged) | Edit section 8.1.1 of `docs/design/art_weather_light.md`. The puddle look is behind `--rain-look`. |
| 7 | **Hunt feedback.** A hurt animal now tells nearby players how hurt it is (0 to 1) and where it was hit (head, chest, hip or leg). It goes to players within 60 m. Network protocol 96. | MikeW | #705 (open) | Revert #705. MikeW's client side is behind `hunt_feedback`, off. |
| 8 | **Clothes dry slowly.** Soaked wool dries in about 2.5 game hours by a fire (0.4 an hour, today 6) and very slowly under cover (0.1 an hour, today 1). Being wet in wind is much colder. | Steve (Jamie's body-in-weather page) | #710 design, #712 code (open) | The `body_703` switch in `data/items/warmth.json` is off by default. |
| 9 | **Cold stages.** The warmth bar has three stages, mild, moderate and severe (under 40, 20 and 8). In moderate cold your actions are 1.5 times slower, and in severe cold 2.5 times. Nothing is refused, so you can always light a fire. Health still stops at 1. | Steve | #710, #712 (open) | `body_703` switch, off by default. |
| 10 | **Raw meat is a gamble, not a certainty.** Raw meat makes you sick 1 time in 5 (seal 1 in 3, eggs and shellfish 1 in 10, sea fish 1 in 20, freshwater fish 1 in 30). Luck helps. | Steve | #710, #712 (open) | The `infection` switch in `data/items/sickness.json` is off by default. |
| 11 | **Sickness starts late.** Sickness from raw food starts 1 to 3 game days after the meal, with a line that names the food. Plant poisons and rotten food still act at once. | Steve | #710, #712 (open) | The same `infection` switch. |
| 12 | **Water sickness is left out.** Your rule in `sickness.json`, that there is no clean or dirty water, stands until you say otherwise. | Steve | #710 | Nothing to undo. It is on your list below. |
| 13 | **The starter island is at 57° S.** `world.json` already puts it in the south. So the noon sun is in the north and shadows point south. South and south-east faces are the shady ones, where snow lasts and cirques form. The moon follows the sun by its phase. | Sonny (Kathleen to build it) | #706 library, #708 design, #711 code (open) | The switch `--one-sky` is off by default. Off, the sky is the old 52° N with the noon sun in the south. This is your hemisphere veto. |
| 14 | **Rule 6 shade is south-east.** The glacier carving on the terrain puts its shady side at bearing 135° (south-east), to match 57° S. | Sonny | #537, Sonny's R2 (open, head a4bef3fb) | `glacial.shady_bearing_deg` in Sonny's params. |
| 15 | **Rule 3 measures peaks on the tented height.** The ws580g run lost 40.8 m off a chalk summit. Sonny moved rule 3's height check to the tented surface, so peaks keep their height. This bumps the terrain version to 69. | Sonny (David4's run report) | #580 (open, head dae958dc), run as ws580h | Revert #580's rule 3 change, or stay on the ws580g bake (version 68). |
| 16 | **Pictures before ws580h.** Dino takes all the waiting screen pictures on your PC first: the cave pair, sea fog, the moon and the trees. The ws580h terrain run comes after. | Coordinator | no PR: Dino's run order | Tell Dino a different order. |
| 17 | **MikeW's branch is split.** Herd groups (server code) moved to their own PR, #666, which David4 checks. MikeW's other work waits on his branch until his slot on your PC. That is about 92 minutes, laid out in `PC_SESSION_MIKEW.md`. | MikeW | #666, and MikeW's branch | Nothing is merged from his branch until you have seen it. |
| 18 | **Karst and shale springs get a proper layer, not a clamp.** Sonny's spring stores gave 2 hours for karst and 2,700 years for shale. Both get fixed in the groundwater layers (a near-surface layer, and karst as two stores) rather than capped. | Sonny (Jamie's groundwater page for the numbers) | Sonny's R4 branch, #713 numbers | Sonny's params. |

## Things only Dave can answer

These are waiting for you. Nothing here was decided.

1. **Snare rate:** how often a set snare catches something.
2. **Path wear:** whether walked ground should wear into paths, and how fast.
3. **Lean-to leaves:** whether a lean-to needs leaves on top to keep the rain out.
4. **Vice cost:** what the vices cost the player.
5. **Torch numbers:** the torch's light reach (12 m on main, 9 in the code fallback) and how long it burns (30 real minutes).
6. **Sound listens:** listening to the new outdoor sounds (rain, wind, rivers, echoes, thunder) on your PC.
7. **PvP on dogs:** whether players can hurt other players' dogs.
8. **#648 R5:** your yes to merge Sonny's river network writer.
9. **Hemisphere:** keep the island at 57° S with the sun in the north (`--one-sky` on), or veto it and stay at 52° N.
10. **Water sickness:** whether some water should make you sick (it would need clean and dirty water, which your rule now says do not exist).
