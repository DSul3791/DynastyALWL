# Bandit camps

Status: stages 1 to 3, 5, 5b, 4a and 4b are in dev and not yet played; the toll and robbery (stage 4) are switched off (`robbery.enabled` false) until Dave turns them on. Full plan: Library `bandit-camps/PLAN.md`.

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
| BANDIT-16 | Caves and mines | no site within 150 m of a cave, animal den or abandoned mine mouth (as mines keep from caves and goblin camps) |

### Known limits (stage 2)

- No toll, robbery or horse claiming yet (stage 4 and 5b); bounty, dissolving and dormancy came with stage 5.
- A camp horse cannot be ridden or led away yet; it is tied and never bolts.
- The camp has no stash chest until stage 4.
- A site whose bandits are all gone is cleared and dissolves (stage 5).
- A camp is made only when none of its members is in the world: one bandit gone off on its own (past 300 m of every player) is made again with the others.
- Bandits have no footstep sounds yet.

## Stage 3: the warnings (`server_bandits.gd` warnings, `data/npcs/bandits.json` warnings, protocol 144)

A site that wakes does not show its camp at once (Dave agreed the plan's warning stages, 19 Nov 2026):

1. **Signs**: a cold fire pit at the site (a campfire in its cold ash state, marked with the site's key, never saved, nobody can use it) and boot prints leading off the nearest road toward it. The prints hang on a mark at the road point (a cold fire item flagged `marks`, same site key, never saved, not a building, no pit drawn, "Boot prints" when inspected), because world rows reach a player only within 100 m and the pit stands 100 to 300 m off the road.
2. **Lookout**, after 2 game days if the road is still busy: one bandit (the camp's first level) stands 60 m off the road on the line to the camp, watching the road. When a player comes within 40 m he walks back to the pit, so following him finds the camp.
3. **The camp** (stage 2), after 2 game days more.

At each step the road near the site must still hold half the points that woke it; if it does not, the pit and its prints are taken away, the lookout goes, and the site sleeps (it can wake again later like any candidate). A site woken before stage 3 is already a camp. Nothing in stage 3 hurts or robs anyone.

### For Dave (provisional, adjust after play)

| # | Choice | Value |
|---|---|---|
| BANDIT-17 | Signs | a cold fire pit and boot prints: pairs 0.8 m apart for 25 m off the road (at most 32 prints) |
| BANDIT-18 | Stage length | 2 game days for signs, 2 more for the lookout, then the camp |
| BANDIT-19 | Lookout | 60 m off the road, walks back to camp when a player is within 40 m |
| BANDIT-20 | Going back to sleep | road below half the wake points (15) before the camp |

### Known limits (stage 3)

- The Tracking skill does not read the prints yet (they are only seen); there is no "tracks" look-at line.
- A killed lookout leaves the post empty until the camp (a restart keeps it so). A pot cannot hang on the prints; one hung on the pit stays as it does on Edda and Hob's fire.
- Signs use the nearest surveyed road patch; a site whose road was taken up shows the pit without prints.
- The lookout watches only while a player is within 200 m of the camp or his post (like the camp's people); he walks back at walking pace and stays by the pit.
- Rain, snow and night do not change the prints.

## Stage 5: clearing a camp (`server_bandits.gd` clearing, `data/npcs/bandits.json` clearing; no protocol change)

Built before stage 4 (the coordinator, 20 Nov 2026, provisional on Dave's behalf): it takes nothing from a player. Dave, 19 Nov 2026: "once all the badits are apprehended or killed ... in a couple days the camp just dissolves back into the ground. once a camp is used it will become dormant".

- **Giving up.** A camp bandit hit below 15% of his health gives up: he sits where he is, throws down his weapon and stops fighting back or running. He can still be killed (then he drops only his clothes).
- **Tying.** Strike him with Rope or Twine in hand (left click, the same blow as any strike): he is tied and one Rope or Twine is used. A notice says so; there is no new key or prompt.
- **Leading.** A tied bandit follows the player who tied him, keeping about 2 m behind (walking, trotting when left behind). Led more than 30 m ahead of him, or after a game hour from giving up or being tied, he slips free and walks back to his camp, still badly hurt (one more blow and he gives up again). A bandit who gave up and is not tied gets up after a game hour too.
- **Bounty.** Led within 5 m of a guard (Edda, the only role guard today) he is handed over: he leaves his camp for good and the player gets 10 copper for each of his levels.
- **Cleared.** When a camp's last bandit is killed or handed over, the camp is cleared. 2 game days later it dissolves: the fire, Lean-tos and horses go. The site then stays dormant for 10 game days, however busy the road, before it may wake again like any candidate.
- Claiming the horses is stage 5b (below); a horse nobody claims stays tethered until the camp dissolves.
- A site whose only bandit out was the lookout, killed or handed over with no others left, is cleared and dissolves without ever becoming a camp.
- A bandit who threw down his weapon is remembered with the camp (saved), so one made again after a despawn has no second weapon to drop.

### For Dave (provisional, adjust after play)

| # | Choice | Value |
|---|---|---|
| BANDIT-21 | Giving up | below 15% health: sits, drops his weapon, no fighting back |
| BANDIT-22 | Tying | a strike with Rope or Twine in hand; one is used |
| BANDIT-23 | Leading | follows 2 m behind; slips free past 30 m |
| BANDIT-24 | Escaping | a game hour after giving up or being tied |
| BANDIT-25 | Bounty | from Edda (role guard) within 5 m: 10 copper a level |
| BANDIT-26 | Dissolving | 2 game days after the last bandit is gone |
| BANDIT-27 | Quiet time | dormant 10 game days after dissolving |

### Known limits (stage 5)

- No "Press E" prompt for tying: the strike with Rope or Twine in hand does it, told by a notice when he gives up.
- The guard must be placed (Edda out at her camp); a dormant guard far from every player takes no one.
- No patrols yet: the quiet time is a fixed 10 game days, not "while patrols pass" (patrols come with the starter town).
- The surrender pose is the bandit's sitting pose; a tied bandit shows no rope.
- A bandit who escapes walks back at walking pace and sits again; his health does not come back.

## Stage 5b: claiming the horses (`server_bandits.gd` claim_horse, `server_companions.gd` claim, `animals.json` horse companion; no protocol change)

Dave, 19 Nov 2026: horses are claimed and brought to town. The coordinator (20 Nov 2026, provisional on Dave's behalf): build it as 5b with a new companion source.

- Once a camp has no bandit left (killed or handed over), a strike at one of its horses with Rope or Twine in hand puts a lead on it; one Rope or Twine is used. While any bandit of the camp is left, the strike is an ordinary blow.
- The horse leaves the camp's row and becomes that player's companion (a new source "claimed": only a camp horse, never a stray). It follows about 4 m behind, saved with the dogs and wolves in companions.json, goes with its owner when they leave the game and is made again beside them on return. The camp dissolving does not take it.
- It needs no feeding: its bond stays full and it never warns. Both horses of a camp can be claimed, by one player or two; each stands a step apart from its owner's other companions.

### For Dave (provisional, adjust after play)

| # | Choice | Value |
|---|---|---|
| BANDIT-28 | Claiming | a strike with Rope or Twine at a horse of a camp with no bandit left; one is used |
| BANDIT-29 | A claimed horse | follows 4 m behind; no feeding, never leaves its owner |

### Known limits (stage 5b)

- No riding, no saddle shown while it follows (the client shows the tethered horse only), no hitching or stabling in town; it can only follow.
- No way to let a claimed horse go yet.
- Names come from a short first-try list (Bay, Ash, Clover...).

## Stage 4a: the toll (`server_bandits.gd` toll, `data/npcs/bandits.json` robbery and toll; no protocol change) - SWITCHED OFF

Dave's agreed default (19 Nov 2026): toll first, then attack. Built behind `robbery.enabled` (false): with it off no toll is asked, no one is charged for refusing and nothing is taken from a player. Turning it on is Dave's decision alone (the coordinator, 20 Nov 2026).

With the switch on:

- A player within 60 m of the road point by a camp (where its boot prints left the road), once a game day, is met by up to two of its bandits (not one who gave up, the lookout at his post, one fighting or hurt). They walk up and stop 4 m off, facing him.
- The NPC talk window opens: "Bandits block your way. "N copper to pass."" with Pay and Refuse. N is 5 copper by the camp's top level.
- Pay: the coins leave his purse and the bandits walk back to the fire.
- Refuse, no coins, no answer in 30 s or walking 20 m on: the bandits come at him with the ordinary big game charge (harmless: health stops at the floor, as every attack today).
- They never follow past 400 m from their fire.

### For Dave (provisional, adjust after play)

| # | Choice | Value |
|---|---|---|
| BANDIT-30 | Toll | 5 copper a level of the camp's strongest bandit, once a game day per character |
| BANDIT-31 | Who comes | up to 2 bandits, within 60 m of the camp's road point, stopping 4 m off |
| BANDIT-32 | Refusing | Refuse, no coins, 30 s without an answer or 20 m walked on: they charge |
| BANDIT-33 | Leash | 400 m from their fire |

### Known limits (stage 4a)

- Off until Dave turns it on: none of it can be seen in play yet.
- Robbery is stage 4b (below), also switched off: two stacks into a saved stash, no coins, no chest, no carts.
- The once-a-day memory is not saved: a server restart may ask again the same day.
- The talk window holds the player while it is open; walking on counts only once it is closed.

## Stage 4b: robbery (`server_bandits.gd` struck and stash, `server_items.gd` rob_stacks, `server_big_game.gd` struck hook; no protocol change) - SWITCHED OFF

Behind the same `robbery.enabled` (false). The coordinator, 20 Nov 2026, provisional on Dave's behalf: a smaller first cut, the stash saved with the camp instead of a chest, carts left out.

With the switch on:

- Only a bandit sent on a player's refused toll robs, and only when his charge leaves that player at the floor ("badly hurt"): he takes the 2 most valuable stacks of the pack (value x count), whole, with their wear and make. Never the item in hand, never a bag holding things, never coins (the purse). Any other blow, or a blow on another player, takes nothing; one charge robs once.
- What is taken goes into the camp's stash, saved at once with the camp's row. The player is told: "Clear their camp to get it back."
- The stash is never destroyed: when the camp is cleared it lies by the fire as ordinary items; a camp that dissolves or goes back to sleep drops it there too before its row goes.
- Switched off, the big game's struck hook changes nothing about a blow.

### For Dave (provisional, adjust after play)

| # | Choice | Value |
|---|---|---|
| BANDIT-34 | Robbery | at the floor after a refused toll: the 2 most valuable stacks, not the item in hand, a full bag or coins |
| BANDIT-35 | Stash | saved with the camp; dropped by the fire when it is cleared, dissolves or sleeps |

### Known limits (stage 4b)

- Off until Dave turns it on.
- No stash chest and no lock: the stash is not seen at the camp until it drops.
- Unattended carts are not robbed (not built).
- No quest items exist in the catalog yet, so none are excluded by name.
- A dropped stash never ages away (like a bag holding things); a piece whose item no longer exists stays in the stash rather than being lost. A camp ending far from every player waits to drop its stash until that ground can be read.
- Every stack of the item in hand is kept, not only the held slot.

## Before robbery.enabled is turned on

The switch is Dave's (the coordinator, 20 Nov 2026). Stages 4a and 4b ship off; these must be true first, each built, reviewed and lane-tested like any change:

1. **Saving cannot lose a robbery.** `save()` returns the camp file's write result, and a failed write puts the taken stacks back in the player's pack. `load_file` falls back to the previous good file (as server_items.gd does with `.prev`) instead of starting empty.
2. **The stash drop is cheap enough.** `flush_world` (a full, synchronous `items.save()`) is measured on a big world on Dave's PC, or replaced by a save of just the laid items.
3. **Kept pieces can be got back.** `stash_left` (pieces whose item left the catalog) has a recovery path, at least an admin listing; `load_file` keeps rather than drops a stash piece it cannot read.
4. **What is taken is right.** Value-0 stacks are skipped; the held slot, not every stack of the held item, is kept; quest items are excluded once the catalog has them.
5. **The stash chest (the plan's stage 4 step 3):** a camp chest holding the stash, locked while a bandit lives, if Dave wants it seen before it drops; it needs a new world structure and lock rules.
6. **Carts (the plan's step 4):** unattended carts within 150 m of a camp robbed at night into the stash, if Dave wants it.
7. **The toll's once-a-day memory** is saved, so a restart does not ask again the same day.
8. **Dave plays it** with the switch on in a test world and agrees the numbers BANDIT-30..35.

## Camp layout clear of trees (world audit, 23 Nov 2026)
`world_audit.gd --camps` laid every bandit candidate site on the baked tiles: Lean-tos stood in tree trunks and on hillsides, and every Lean-to's open side faced away from the fire. Now (`server_bandits.gd _turn_of`, `_fitting_turn`, `_camp_fits`): the open side faces the fire; the camp is turned in 30 degree steps from the seed's turn until its Lean-tos (their roof, back to ridge), seats, tether and fire miss every trunk (`trees_at`: terrain_server's standing trunks, null until the flora round the fire is made) and each Lean-to stands out of water on ground rising no more than `lean_to_rise_m` (data/npcs/bandits.json, 1.0 m, the player's own rule for a Lean-to) across it. The turn must fit the camp and every smaller camp its kills leave (fewer seats, one Lean-to less), so it stays clear after a death. The camp is laid only once the turn is found, and its people sit at that camp's seats. The turn is kept for the run, not saved: the same trees give the same turn after a restart, but trees felled since or changed water can turn the camp at the next start (its Lean-tos are laid again each start anyway). A candidate where no turn fits is refused ("cluttered"); one whose flora is not made yet waits ("unloaded") like unloaded ground. The camp does not see boulders yet.
