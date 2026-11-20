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
- A mover's last four stretches do not count again, so pacing one boundary counts once; a walk out and back counts.
- The pinch-point preference (ford, forest stretch, pass) is not built: the busiest candidate that passes the rules wakes.
- Patrols, wagoneers and the used-site dormancy come with later stages; no patrol or wagoneer NPC exists yet.

## Stage 2: the camp itself (`server_bandits.gd` camp part, `data/npcs/bandits.json` camp, protocol 143)

An awake site is laid on the ground from its row at every server start and never saved in the world (the site row is its record):

- a campfire at the site, lit and refusing a player's use ("That is the bandits' fire. It is not yours to tend.");
- one Lean-to for 1 or 2 bandits, two for 3 to 5, open to the fire (Dave agreed a Lean-to for now, no new Tent item); they cannot be taken down;
- the horses (two) tethered 9 m behind the fire, shown saddled (wire state 22);
- the bandits, made while a player is within 200 m, sitting round the fire (state 23), lying at night (24), one standing lookout.

A camp's bandits are fixed by the seed: their count and levels by distance band from the starter town (from the spawn while there is no town). Near the town 1 or 2 bandits at level 1, a quarter of camps with one at level 2; further out more and stronger. Bandits are animal species 52 (`bandit`) and fight back through the big game warn and charge when hit, harmless to life as all attacks are for now. A badly hurt bandit runs from whoever hurt it. A fallen bandit leaves its site's row for good and drops its weapon and clothes; a camp horse that dies leaves the row too. The client draws bandits with the human ragdoll in the `bandit` outfit.

### For Dave (provisional, adjust after play)

| # | Choice | Value |
|---|---|---|
| BANDIT-8 | Bandits by distance from the town | under 3 km 1-2 at level 1 (a quarter with one at level 2); 3-5 km 2-3 at levels 1-3; 5-8 km 2-4 at 3-6; beyond 3-5 at 5-10 |
| BANDIT-9 | Lean-tos | one for 1-2 bandits, two for more, 5 m from the fire |
| BANDIT-10 | Horses | two, tethered 9 m behind the fire |
| BANDIT-11 | When they appear | a player within 200 m; gone with the animals past 300 m, made again on return |
| BANDIT-12 | Gear | level 1+ wooden club and hide clothes; 3+ bronze spear and hood; 5+ iron sword and fur cloak |
| BANDIT-13 | Running | under 30% health a bandit runs, up to 40 m from its seat |
| BANDIT-14 | Health | 40 at level 1, scaled by the island level's health per level |
| BANDIT-15 | Goblin ground | no site within 1.5 km of a goblin tribe camp |

### Known limits (stage 2)

- No toll, robbery, bounty, horse claiming, dissolving or dormancy yet (stages 3 and 4).
- A camp horse cannot be ridden or led away yet; it is tied and never bolts.
- The camp has no stash chest until stage 4.
- A site whose bandits and horses are all gone stays awake and its empty camp is laid at every start until stage 3 dissolves it.
- A camp is made only when none of its members is in the world: one bandit gone off on its own (past 300 m of every player) is made again with the others.
- Bandits have no footstep sounds yet.
