# Bandit camps

Status: stage 1 of 5 (sites and traffic) on branch `claude/project-thread-2c1rn3`; stages 2 to 5 not built. Full plan: Library `bandit-camps/PLAN.md`.

## What Dave asked for (19 Nov 2026, project chat)

- "bandit camp spawn areas ... predetermined by the seed like plants and trees but they only activate if someone builds a road within 500m of a spawn point. then it will also check to make sure there are no other bandit camps spawn activated within a few kms."
- He agreed to the coordinator's four changes: wake on traffic, not on the road existing; hidden sites off the road near a pinch point; warning stages (signs, lookout, camp); clearing keeps a stretch safe, nothing near the start area.
- "it should be an actual camp though ... a campfire maybe a couple of tamed horses with saddles and a tent or two and from 1 to 5 bandits", levelled for the area: near the starter town "mostly level 1 with maybe 1 guy at level 2".
- "once all the badits are apprehended or killed the players or the patrol men can claim the horses and bring them back to town to keep or to sell and basically in a couple days the camp just dissolves back into the ground. once a camp is used it will become dormant for as long as patrols pass that area from time to time. other sights might become active if there is lots of player traffic or high value npc like wagoneers and such nearby. law patrols reduce the risk of one spawning."
- "I agree with all 5 bandit ideas" (the plan's defaults): Lean-to for now (no new Tent item), toll first and attack if refused, beaten and robbed but left alive, a coin bounty from a guard for a captured bandit, the first-try numbers below.

## Stage 1: sites and traffic (`src/stream/server_bandits.gd`, `data/npcs/bandits.json`)

- **Sites.** One candidate per `cell_m` square, at a spot fixed by a hash of the cell and the world seed; `share` of the cells have one. Nothing is stored for a sleeping site.
- **Trip points.** On each position report the server already looks up whether the player is on a path (`server_items._on_path`, once a second). A player entering a new `stretch_m` stretch on a surveyed road adds `weights.road`, on a hand path `weights.path`, pulling a loaded cart `weights.cart`. Off every path the player is forgotten. Points halve every `half_life_days` game days.
- **Waking.** Once a game hour (`check_s`), only round the stretches that gained points, the candidates are tried, busiest first. A candidate wakes when the stretches within `near_road_m` hold `wake_points`, its ground is dry and gentle (no step of `slope_step_m` rises more than `slope_max_deg`), the nearest road patch is `road_off_m` away, no building or campfire stands within `building_clear_m`, it is `start_clear_m` from the town point and the spawn, and no awake site is within `spacing_m`.
- **Saved** in the server store as `bandit_sites.json` (awake sites, trip points). Each awake site prints one `BANDIT site` line at server start.
- Nothing appears in the world yet: the camp is stage 2.

## For Dave (provisional, adjust after play)

| # | Choice | Value |
|---|---|---|
| BANDIT-1 | Candidate spacing | one chance per 1 km square, half the squares |
| BANDIT-2 | Trip points | 1 a 100 m stretch on a road, 0.5 on a hand path, 3 pulling a loaded cart |
| BANDIT-3 | Fading | points halve every 3 game days (about 3 real hours) |
| BANDIT-4 | Busy enough | 30 points on the stretches within 500 m |
| BANDIT-5 | Where a camp sits | 100 to 300 m off the nearest road, slope under 15 degrees, not in water |
| BANDIT-6 | Kept clear | 1.5 km from the town point and the spawn, 150 m from any building, 3 km from another camp |
| BANDIT-7 | How often | once a game hour, only near stretches that gained points |

## Known limits (stage 1)

- Trip points since the last save are lost in a crash (saved at each wake and at shutdown).
- A candidate whose ground tile is not loaded is not read (no tile read stalls the server); it is tried again at the next check.
- Water means deeper than 0.7 m (the NPC walking test): a shallow pond counts as dry.
- Walking back and forth over one stretch boundary counts each crossing; harmless in stage 1, to be limited per mover before stage 2 puts camps in the world.
- The pinch-point preference (ford, forest stretch, pass) is not built: the busiest candidate that passes the rules wakes.
- Patrols, wagoneers and the used-site dormancy come with later stages; no patrol or wagoneer NPC exists yet.
