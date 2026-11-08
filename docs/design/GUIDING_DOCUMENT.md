# Dynasty: a life well lived. The Guiding Document

Written by the coordinator (Claude Fable 5.1) at Dave's direction, 7 Nov 2026. Version 1.

This is the document that says what the game is for and how every design we have, and every idea we have later, gets turned into something in the game. It sits above `DESIGN_IDEAS.md` (the permanent ideas file), `DESIGN_PRINCIPLES.md`, the water documents and the knowledge library. It does not replace them. The coordinator owns this document and is responsible for guiding its implementation; agents implement under it.

## 0. Tags

| Tag | Meaning |
|---|---|
| **[Dave]** | Dave's decision or intent, from his own words. Binding. |
| **[Existing]** | Already decided or built in the repo. The source is named. |
| **[Proposal G-nn]** | A coordinator proposal with an ID. Not decided. Dave reacts by ID in a few words ("yes G-04", "no G-07", "later G-10"). Nothing tagged Proposal is built in the game until Dave says so. Docs and data preparation may go ahead. |

## 1. The laws (all [Dave])

These bind every agent and every phase. Where any other document disagrees, these win.

1. **Design docs first.** No code for a new system or mechanic before a design document exists in the repo and Dave has reacted to it.
2. **No tests or bakes in the cloud.** Heavy work runs only on Dave's PC: Dino for pictures, bakes and anything visual; David4 for the headless gate. Both stop when Dave says "stop all testing", and nothing restarts until Dave's own words lift it.
3. **Systemic fixes only.** No area patches, no pinned heights, no per-spot fixes. If something is wrong in one place, fix the system that made it.
4. **Merges only on green CI and a passing gate.** Tyler merges; nobody else.
5. **The repo is public.** Purchased models and assets are never committed. Models Dave makes himself may be.
6. **Dave's watershed document** (`docs/water/Dynasty_How_Natural_Watersheds_Work.md`) has authority over every earlier water note.
7. **No cards and no questions to Dave.** Agents send questions to the coordinator, who answers from the agents' own recommendations or carries one short recommendation to Dave.
8. **Research first, record every lesson.** Check `docs/knowledge/` before starting; write what you learned there when you finish (Jamie keeps the library).
9. **Named agents only.** Threads are "Name: Role - Job". No new agents; leftovers go to the owning named agent.
10. **Measured by what works in play**, not by tests passed.

## 2. How a design becomes part of the game (the implementation path)

Every design in our documents, and every idea we come up with later, walks the same path. Nothing skips a step.

| Step | What happens | Who | Output |
|---|---|---|---|
| 1. Idea | A one-line idea with its source (Dave, a doc, a gap in the interaction map, real natural history). | Anyone; coordinator records it | An idea card (section 11.2) with an ID |
| 2. Reaction | Coordinator carries the card to Dave as a recommendation. Dave says yes, no or later. | Coordinator, Dave | Tag becomes [Dave] or the card is parked |
| 3. Design doc | The owning agent writes a design page: what it is, how it works, what data it needs, what systems it touches, how we will know it works, and what it must not break. Holistic: it names every dependent system. | Owner | A PR with only docs; coordinator reviews, Dave reacts |
| 4. Data before code | Tables in `data/` and schema docs are extended first. Code follows only where a shared system does not yet exist. | Owner | Data PR |
| 5. Build | Small PRs, one owner each, one creature or feature at a time, with a written completion criterion. After two failed attempts, find the root cause; if you cannot, document the blocker and move on. | Owner | PRs on green CI |
| 6. Gate | David4 runs the headless gate on the exact sha. | David4 via coordinator | Pass or a named failure |
| 7. Check in play | Dino runs it on the PC and brings back pictures or a report, scheduled behind higher-priority work and never while Dave is playing. | Dino via coordinator | Picture or report in the shared folder |
| 8. Merge | Tyler merges on green CI and a passing gate. | Tyler | In main |
| 9. Learn | What we learned goes into `docs/knowledge/`. The interaction map is regenerated. | Owner, Jamie | Knowledge entry |

The coordinator keeps a single progress report per phase: done, in progress, blocked. An agent that is blocked says so and moves to the next item; it does not retry the same test without a change.

### 2.1 Priority

When PC time, Tyler's queue or an agent's attention is contested, this order decides:

1. Sonny's terrain and water rebuild (full authority and priority, [Dave] 7 Nov).
2. MikeW's creature pipeline.
3. Steve's Stage E readers and dependent systems ([Dave] 7 Nov 20:17).
4. Everything in this document's plan, in phase order.

Lower-priority work reads what higher-priority work publishes and never asks it to change course.

## 3. Vision

**[Dave]** A fantasy adventure game in a massive world of islands and oceans and many climates. The world is full of things to find: creatures to **discover, hunt, tame and avoid**, and more. Creatures need places to live: **caves**, **mountain tops**, and the **sky**, where some soar. Dave can describe the ideas but not list them all, so the AI helps him **discover new things to add, work out how to implement them, and decide and map how players should interact with them.**

**[Existing]** The base is a rough-medieval multiplayer survival and town-building game with a dynasty that outlives one character (heirs), towns players found, real simulated water, seasons, fire and building. Inspirations: Valheim, ARK, Atlas, Medieval Dynasty, Minecraft (`DESIGN_IDEAS.md` 1). It must run on an old quad-core with 8 GB (`DESIGN_IDEAS.md` 3).

**[Proposal G-00] The one sentence:** *Wherever you go in this world, something is living its own life there, and you can learn it, use it, befriend it, hunt it, or get out of its way.* The dynasty game gives players a home and a reason to come back. The adventure game, which this document is about, gives them a reason to leave it.

## 4. Pillars

Each pillar is a test. An idea that fails one is changed or dropped.

1. **A living world, not a spawn table.** Creatures live by habitat, season, time of day and need (food, water, rest), as `docs/knowledge/animal-behaviour.md` describes. Where a creature lives depends only on what is natural for it. Distance from the starter town sets its *level*, never its *place* ([Dave] 6 Nov).
2. **Discovery is the reward.** Finding something nobody told you about is worth more than any drop. The world leaves evidence: tracks, calls, feathers, droppings, carcasses, circling birds, rumours.
3. **Every creature has a readable role.** From 20 m a player can tell what it is ([Dave] 22 Oct) and from its behaviour what it will probably do. A reaction needs a cause the player can see.
4. **Many ways to meet each creature.** Discover, hunt, tame, avoid, and more ([Dave]). A good creature supports at least three verbs, and the player's choice matters.
5. **Danger is fair and travels with distance.** Safer near home, harder far away, with the danger map by latitude, distance from starters and the abyss at (0,0) ([Existing] `DESIGN_IDEAS.md` 4.13). Death teaches; death with no warning does not.
6. **Realistic with a light fantasy hand** ([Dave] art goal). A creature is first a believable animal. The fantasy is one signature exaggeration, not a costume.
7. **The world is made by systems, not by hand.** Habitat comes from the terrain and water record, behaviour from shared data, placement from rules. No per-creature code paths and no per-spot patches ([Dave]).
8. **Safe, kind, generous** ([Existing] `DESIGN_IDEAS.md` 3). Taming, rescue, gifts and second chances are core.
9. **Build for the weak machine.** Far creatures simulate coarsely, near ones in detail. Caps per quality setting.

## 5. The world

### 5.1 What exists [Existing] (`DESIGN_IDEAS.md` 4.1, 4.2, 4.12, 4.13)

- Tiles are 15.36 km square; islands cross tile borders. The world is planned from a coarse sketch of islands formed the way real ones form: island arcs, hotspot chains, continental fragments, mid-ocean ridges, atolls and reefs. Each origin sets the island's geology and resources.
- Climate runs from the **equator row** (hottest) through temperate to **arctic**, poles meeting at the wrap seam. Seasons are real. Altitude cools mountains. Not every hot-row island is sand (4.2).
- **Starter islands** are temperate, levels 1-5 near town, 5-10 mid, 10-20 far.
- East and west grow harder: cliffs, volcanoes, storms. Equator and polar rows carry meaner mythical creatures (yetis at the poles). At the centre sit the **abyssal trench** and the **ultimate island**: a desert island with a 1,900 m volcano, the ruins of a fallen civilization, dragons and wyverns, sandworms and scorpions, temples, caves and labyrinths, and the best loot.
- At sea: ships, wrecks to dive, flotsam, pirates, sea monsters in dangerous waters.

**[Existing, in progress]** Sonny is rebuilding terrain and water as one watershed system (`docs/water/watershed_rebuild_design.md`, steps R0 to R8): landscape evolution, lakes by named cause, groundwater, wetlands by type, channel heads by slope and area, cave springs only in soluble or fractured rock, an island water record (R6) and readers (Stage E, Steve). MikeW integrates purchased rigged animals one at a time (`design/ANIMALS_BATCHES.md`, PRs #538, #540). This document builds on both and never competes with them for PC time.

### 5.2 Island archetypes [Proposal G-01]

The sketch already knows how each island formed. Name that as an **archetype**: a label per island that says what habitats, creatures, places and hazards the generator should fill in from the island's rock, climate and water. It is a recipe the existing sketch supports, not a new generator.

| Archetype | Born from | Look | Signature place | Signature creatures | Hazard | Why sail there |
|---|---|---|---|---|---|---|
| **Hearth** (starter) [Dave] | Continental fragment | Temperate forest, meadow, rivers, spring caves | Spring caves, goblin dens, river heads | Deer, boar, wolf, fox, bear, moose, rabbit, goblins | Low-level wolves and bears | Learn the game. Home. |
| **Highland** | Folded fragment | Heath, boreal forest, alpine meadow, tarns | Peaks with eyries, cirque lakes | Bighorn, goat, chamois, lynx, black bear, eagle | Cold, falls, storms | Ore, trophy game, climbing |
| **Fen and moor** | Low fragment, glacial flats | Marsh, fen, bog, mist | Wetland nesting grounds | Moose, beaver, mink, geese, herons | Bogs, getting lost | Peat, reeds, birds |
| **Fire** | Volcanic arc | Black rock, steam, hot springs, ash forest | Geothermal pools, lava tubes | Ember boar, cliff nesters | Heat, gas, eruptions | Obsidian, sulfur, hot-spring camps |
| **Seabird isle** | Hotspot chain | Treeless turf, sea cliffs | Cliff colonies, sea stacks | Gulls, puffins, seals, sea eagles | Wind, slippery rock | Eggs, feathers, seal hunting |
| **Reef atoll** | Coral on old volcano | Lagoon, palms, white sand | Lagoon, reef, wreck diving | Turtles, rays, sharks, crabs | Sharks, tides | Pearls, limestone, anchorage |
| **Ice** | Arctic arc | Glacier, fjord, sea ice | Ice caves, whale bays | Polar bear, walrus, seal, musk ox, arctic fox, yeti | Cold, whiteout | Sled routes, whaling, furs |
| **Dune and savanna** | Equator row | Desert, scrub, wadis, salt flats | Oases, ruined shore villages | Camel, lion, hyena, vultures, scorpions | Heat, thirst | Gold, ruins, old roads |
| **The ultimate island** [Dave] | Fixed `center_island` | Volcano desert | Fallen city, lava river, labyrinths | Dragons, wyverns, sandworms | Everything | The greatest rewards |

**[Proposal G-02]** The purchased animals set aside as "wrong world" (camel, lion, leopard, hyena, rhinoceros, warthog, wildebeest, elephant) belong to the dune and savanna archetype. Keep them in the pack and bring them in at Phase 6.

### 5.3 Habitat is data, not code [Proposal G-03]

Every row in `data/animals/animals.json` already has `biomes`, `near_fresh_water_m` and `near_ocean_m`. Extend the same style of key so a mountain-top, cave or sky creature is only a new row:

| Key | Meaning | Fed by |
|---|---|---|
| `altitude_m` (min, max) | Height band | Terrain |
| `slope_deg` (min, max) | Cliff and crag dwellers need steep rock | Terrain |
| `rock` | Needs outcrops, scree, ledges | Geology |
| `water_kind` | River, lake, tarn, fen, bog, spring pool, hot spring | Water record (R6) |
| `cave` | Den tier, depth band, wet or dry | Cave skeleton |
| `canopy` | Under or in trees, hollow trunks | Flora |
| `sea_depth_m` (min, max) | Shore, shelf, open ocean, abyss | World elevation |
| `sky` | Soars; uses updrafts; roosts at `lair` | Wind and relief |
| `lair` | den, burrow, nest, eyrie, hollow, warren, roost, holt, haulout | Placement rules |
| `season` | migrate, hibernate, rut, breed, moult | Calendar |

All new keys are optional. Before R6 lands, only keys the current terrain can answer are used; the rest are written now so the data never needs redoing.

## 6. Creatures by habitat

The verbs: **Discover** (find and learn), **Hunt** (food, hide, trophy), **Tame** (companion, mount, livestock, familiar), **Avoid** (a danger to read and dodge), **Harvest** (take without killing: honey, wool, eggs, feathers, milk), **Ally** (it helps you unasked), **Study** (a journal entry that unlocks knowledge). **Have** = a model we own or Dave made. **Need** = no model yet.

### 6.1 Forest, meadow and farmland (Hearth)

| Creature | Model | Verbs | Notes |
|---|---|---|---|
| Rabbit, fox, deer, boar, moose, wolf, bear | Have [Existing] | D, H, A | Temperaments, flee and threat ranges, seasons and young are built (#480, #485). |
| Horse, donkey | Have [Existing] | D, T | [Dave] wild first, tamed later, each with a tamable value; riding later. |
| Black bear, lynx, elk | Have, batch 1 | D, H, A | In MikeW's pipeline. |
| Chamois, mink, raccoon, rat, crow, pheasant, goose | Have, batch 2 (#540) | D, H, Ally | Crow is also a sign (G-07). |
| Cow, goat, chicken, cat, dog, buffalo | Have, batch 3 | T, Harvest | Livestock and companions; wait for the taming design (section 8.2). |
| Honey bees and wild hives | Need | D, Harvest | [Proposal G-04] with honeyguide birds that lead you to a hive. |

### 6.2 Wetlands, rivers and lakes

The rebuild makes these places real: marsh, swamp, fen and bog by cause, tarns, seeps, spring pools. [Existing] Sonny's design says beaver ponds belong to the ecology later. This is that later.

| Creature | Model | Verbs | Notes |
|---|---|---|---|
| Frog, duck, goose | Have | D, H | Tied to fresh water already. |
| Beaver | Have, batch 1 | D, Harvest, Ally | [Proposal G-05] A beaver builds: it dams a small low-gradient woodland stream and raises a real pond; players can break the dam. Needs R6 and R7. |
| Moose | Have | D, H, A | Wades in fens and tarns in the autumn rut. |
| Heron, kingfisher, otter | Need | D, Study | Signs of a healthy stream. |
| Trout, salmon, bluegill | Have (2) | H | [Proposal G-06] Fishing, and an autumn salmon run on rivers that reach the sea, where bears, eagles and wolves gather. |
| Marsh lights | Need (effect only) | D, A | [Proposal G-12] A light over bogs at night that leads travellers astray. No model cost. |

### 6.3 Caves and the underground

**[Existing]** Caves are skeletons of passages carved into voxels. Spring caves sit at river heads, inland, at a hill foot, about 100 m deep with a pool at the back and dens in side branches. Every cave may be inhabited by animals, creatures or people ([Dave] 6 Nov). Goblins live in a dry offshoot den; bears den in caves. The rebuild (C7) will place cave springs only in soluble or fractured rock, so cave placement will change with R5/R6; Steve's readers carry dens across.

**[Dave]** "Things need caves to live in." The cave is the creature's home, and the creature tells you what the cave is.

| Dweller | Where | Verbs | Notes |
|---|---|---|---|
| Bear | Spring cave den | A, H | Hibernates; torch does not protect in its den ([Dave]). |
| Goblins | Dry offshoot den | A, Study | [Existing] groups of 2-5, nocturnal, skittish, steal from the dark. |
| Bats | Any deep dry cave, out at dusk | D, Ally | [Proposal G-08] A dusk emergence: a free spectacle and a clue that the cave is deep and has a second opening. |
| Glowworm ceilings | Wet chambers | D | [Proposal] Real; the one light in a truly dark cave. |
| Cave snake, giant spider | Deep dry branches | A | [Existing] `DESIGN_IDEAS.md` 4.4. |
| Olm, blind cave fish | Cold spring pools | D, Study | [Proposal] Real, harmless, a quiet joy. |
| Survivors, hermits, bandits | Any inhabited cave | Ally, A | [Existing] NPCs; hermits trade rumours. |
| Cave bear | Deep caves, harder islands | A | Scale and scar variant of the bear. |
| Troll or ogre | Rare, deepest, harder islands | A | [Proposal G-10] A lair puzzle: asleep by day, hates sunlight, the river through its cave is the way to lure it out. |

### 6.4 Mountains and crags

The rebuild's glacial history (R2b) gives cirques, tarns, troughs, hanging valleys and falls, and the cliff and scree ground that fits climbers.

| Creature | Model | Verbs | Notes |
|---|---|---|---|
| Bighorn, mountain goat, chamois | Have | D, H | They flee *up*. Habitat is `slope_deg` and `rock`, not a biome. |
| Marmot, pika, ptarmigan | Need | D | Marmots whistle an alarm when something big is near. |
| Snow leopard, wolverine | Need | A, H | Rare, solitary, a trophy for patient players. |
| Golden eagle | Need | D, Study | Nests in an eyrie on a crag (`lair: eyrie`). |
| Mountain troll, stone giant | Need | A | Top of the danger scale on harder islands (G-10). |
| Avalanche and rockfall | System | A | A place hazard from climate and slope. |

**[Dave]** "Some things live on mountain tops." **[Proposal G-13]** Every high peak holds **one thing worth the climb**: an eyrie, a hidden tarn, a ruin, a shrine, a fallen star (G-14). Climbing needs a verb the game lacks: rope, pitons, hand-holds; see Phase 5.

### 6.5 The sky

**[Dave]** "Soaring around in the sky." Birds are the cheapest way to make a world look alive, and soaring is real behaviour that depends on terrain: thermals over sun-warmed slopes, ridge lift where wind meets a hill, vultures over death.

**[Proposal G-15] One soaring system**, not many scripts:
- The world wind and relief already exist (the rebuild's orographic rain uses them). From them a cheap *lift field* says where air rises.
- A soaring bird picks a lift cell, circles up, glides to the next. No path-finding; almost no cost when far.
- Birds are *signs*: vultures mark a carcass; crows and ravens mark a kill or a fight; gulls mark the coast and a fish school; a hawk hanging still marks prey; geese in a V mark a season change.
- Apex sky creatures use the same system at larger scale: sea eagle, golden eagle, roc (a huge eagle; the extinct Haast's eagle at 15 kg is the real base), wyvern, dragon ([Dave], ultimate island). A roc takes goats and sheep, and a careless player in the open on a high ridge.
- **Avoid** is the main verb for apex birds: cover, a raised shield, a torch at dusk, a horse that bolts under a shadow. **Tame** applies to a hawk or falcon for small game, and a raven.

### 6.6 Coast and sea

| Creature | Model | Verbs | Notes |
|---|---|---|---|
| Gull, seabird, seal | Have [Existing] | D, H | Haul-outs and nesting cliffs exist. |
| Crab, shellfish, kelp | Need | Harvest | Tide-pool foraging: a gentle start. |
| Fish | Have (3) | H | Needs fishing (G-06). |
| Dolphin, whale, shark, ray, turtle | Need | D, A | [Proposal G-11] Pods alongside a ship are an encounter; sharks gather at blood. |
| Kraken, sea serpent | Need | A | [Existing] dangerous waters. |
| Walrus, polar bear | Need | H, A | Ice archetype. |
| Albatross, puffin, sea eagle | Need | D, Ally | An albatross following a ship means land is near. |

### 6.7 Polar and desert extremes

**[Existing]** Polar: yetis, sea ice with seasonal thickness, seal hunting, ice fishing. Desert row: dragons and wyverns, giant sandworms and scorpions. **[Proposal]** The same rule for both: the animal is real and the exaggeration small, then a mythical apex sits on top. A yeti is a scaled-up wild thing of the high snows; a sandworm is a desert sea-serpent whose approach you feel through the ground.

### 6.8 The five-point test for a fantasy creature [Proposal G-16]

1. A **real animal at its base**, so it moves, eats and breeds believably.
2. **One signature exaggeration** we can say the purpose of.
3. A **habitat**: niche, lair, food chain.
4. A **readable warning**: a sound, a posture, a silhouette.
5. **Three or more verbs.**

Pass: antler-moss stag, stone-hide boar of fire islands, ember-wolf, roc, yeti, sandworm. Fail: a rainbow unicorn, a generic dragon with no lair.

## 7. How players meet a creature: the interaction card [Proposal G-17]

**[Dave]** "Decide and map how players should interact with them." Every creature gets one **interaction card**, the same shape for all, filled from data, so the whole game's map is a table you can read in one sitting.

| Field | What it answers |
|---|---|
| **Niche** | Habitat keys (5.3), activity (day, night, dusk), diet, food-chain place. |
| **Sign** | What the player finds *before* the animal: tracks, scat, feathers, calls, a kill, circling birds, a rumour. |
| **Senses** | Sight, hearing, smell, and the wind. |
| **Temperament** | Passive, neutral, defensive, aggressive, friendly [Existing]. |
| **Warning** | What it does before it acts, so the reaction has a visible cause. |
| **Verbs** | Which of Discover, Hunt, Tame, Avoid, Harvest, Ally, Study, and how. |
| **Reward** | Food, hide, bone, trophy, knowledge, a companion, a clue. |
| **Counterplay** | How a player with the right tool, skill or plan beats or escapes it. |
| **Level and tier** | Level range from the danger map; the gear tier that makes it fair. |
| **Seasons** | Hibernate, rut, migrate, young. |
| **Systems touched** | The code that must exist, so dependencies are found early. |

### 7.1 Worked cards

| Creature | Sign | Warning | Verbs | Counterplay |
|---|---|---|---|---|
| Deer | Tracks, rubbed bark, a soft call at dusk | Head up, ears turn, stamp | Hunt, Discover | Downwind, still, a spear from cover |
| Bear at den | Clawed trees, torn logs, a bone pile | Turns to face you [Existing]; huff, jaw-pop and standing [Proposal]; then charge | Avoid, Hunt, Study | Stay out of the den ring; fire does not help there |
| Wolf | Howl, tracks in a line | Growl, low circling | Avoid, Hunt, Tame (pup) [Proposal] | Torch 9 m (`torch_light_m` in `animals.json`), fight at a chokepoint |
| Goblin band | Footprints at the fire's edge, a missing item, glinting eyes | Sudden retreat, a whistle | Avoid, Study, Ally [Proposal] | Stay in light; never corner them |
| Beaver | Gnawed stumps, a lodge, a new pond | Tail slap | Discover, Harvest, Ally | Break the dam; fish the pond |
| Bighorn, goat | Scat on ledges, a clatter of stones | Bound upslope | Hunt, Discover | Climb above them |
| Golden eagle | A wheeling dot, a shadow, white-washed ledges | A scream and a stoop | Avoid, Study, Tame | Keep to cover; a shield; shoot in the dive |
| Vulture, raven | Circling | None: they are the sign | Discover, Ally | Follow them |
| Seal | A head in the surf, barks, a haul-out | Slides into the water | Hunt, Discover | Approach from the sea side |
| Whale | A spout, a sound across water | None | Discover, Study | A calm ship |
| Glowworms | A faint glow before you see the cave | None | Discover | Light off: they are your light |
| Dragon, wyvern | Scorched ground, a burnt camp, a long shadow | Smoke, a roar, a gust | Avoid, Study | Cover, water, a ballista, a ship |

### 7.2 The matrix

The cards roll up into one **creature by verb matrix**, `docs/design/INTERACTION_MAP.md`, generated by a small script from `animals.json` plus the cards so it never goes stale. It is how we catch gaps: a habitat with no Discover creature, a tier with no Avoid creature, a verb used by only two species.

## 8. Hunting, taming and avoiding as shared systems

Three shared systems carry all of it, so each new creature is only data.

### 8.1 Hunting
**[Existing]** Senses, flee and threat ranges, temperament, seasons, young, carcasses and parts, thrown spears, snares. **[Proposal]** Add tracking (sign leads to the animal), trophy quality (older males are warier), clean kills versus wounded animals that flee and die later, and season rules (mothers with young, rut males). All through the existing temperament and range data.

### 8.2 Taming [Proposal G-09]
**[Existing]** Horses have a per-animal tamable value; farm animals wait for a taming design; familiars are future; young animals already follow their mother. One taming system, four **bonds**:

| Bond | Earned by | Gives | Examples |
|---|---|---|---|
| Livestock | Buy or catch young; house, feed, keep | Milk, wool, eggs, meat, hide | Cow, goat, chicken, sheep |
| Mount | Gentle approach, feed, patience; saddle later | Speed, load, reach | Horse, donkey, camel; later a great elk |
| Companion | Raise from the young, or earn trust at a camp over days | Follows, guards, warns, hunts, finds | Dog, cat, wolf pup, fox kit, hawk, raven |
| Familiar | A quest or a mentor, never a catch | Talks, has personality, grows with the player | Parrot, monkey, raven (`DESIGN_IDEAS.md` 6.11) |

The verbs are the same for all four: **approach, offer, wait, bond.** Temperament sets how long and how careful. The ladder is data: `tame: { bond, food, trust_per_day, min_level }`. A bond is days of presence, not a button, which fits a game on a real clock. Companions are individuals with a name, a bond level and a history, and **a dynasty passes a companion to an heir**. That is the strongest link between the adventure game and the dynasty game, so it is not skipped.

### 8.3 Avoiding
A skill with tools, not a coin toss: stealth (crouch, downwind), terrain (a river, a cliff, a tree), light and fire (goblins and wolves keep out; the den bear and a mother with young ignore it), sound, shelter, speed, and companions (a dog barks first). The warning is the contract: the player always gets something to see or hear before the danger acts.

## 9. Discovery: how a player learns the world

### 9.1 The field journal [Proposal G-18, awaiting Dave]
**[Existing]** `DESIGN_IDEAS.md` 6.15 has journals ("what a character knows"). Use that one place for creature knowledge, a ladder per species: **Heard of, Sighted, Observed, Tracked, Studied.** Each rung reveals more: range, habits, weak points, drops, safe approach, lore. The whole ladder can be climbed without killing. Family knowledge is inherited by the heir, so a dynasty accumulates a natural history; journal pages are copyable items and are not inherited (D-09).

### 9.2 Rumours on the news rail [Proposal G-19, awaiting Dave]
**[Existing]** News travels with people; the game owns the facts and the language model only speaks (`DESIGN_IDEAS.md` 13.6, principle 3). Creatures and places become rumours on that rail: a hermit, a sailor or a shopkeeper tells you something true about a creature or place the world already contains. This is how the AI helps players find things without a quest marker.

### 9.3 Signs
**[Existing]** `data/animals/animal_sign.json`. Every species gets at least two sign kinds; a player who has the journal rung sees them more easily.

## 10. Places of adventure

A place is an event waiting for a person. It needs a reason to exist (the terrain and water made it), a reason to visit (a reward), a way in (a path or a challenge), a readable danger, and a story the player can piece together.

**[Existing]** Caves, dens, lair sites filled at runtime, ruins and labyrinths on harder islands, the fallen city and old road, wrecks, flotsam, bandit camps, fallen adventurers with their gear.

**[Proposal]** Additional place types, each built from the rebuild's output or systems we already have:

| ID | Place | Made by | Life | Reward | Needs |
|---|---|---|---|---|---|
| G-20 | Eyrie on a crag | Slope, rock | Eagles, later a roc | Feathers, eggs, a vantage | Soaring, climbing |
| G-21 | Hidden tarn in a cirque | Glacial history (R2b) | Rare fish, a shrine, a hermit | Clean water, a rare plant | R2b, R3 |
| G-22 | Cave behind a fall | Hanging-valley fall | Bats, glowworms, a hermit | Shelter, a secret | Breaks "caves only at river starts"; decision in section 13 |
| G-23 | Hot spring camp | Fire-island geothermal | Steam-loving animals, a bathing NPC | Warmth, minerals | A hot water type |
| G-24 | Sea stack colony | Seabird isle | Nesting seabirds, seals | Eggs, feathers | Cliffs, boats |
| G-25 | Wreck and sunken ruin | Existing wrecks | Rays, moray, a ghost-light | Cargo, a map | Diving |
| G-26 | Standing stones and shrines | Authored on peaks and headlands | A one-time boon | A blessing or a secret | Authoring tool |
| G-14 | A fallen star | Rare event on high ground | A crater, a strange ore | A unique item | Event system |
| G-27 | Ruined watchtower | The fallen civilization | A bandit or hermit | Loot, a view | Authoring |
| G-28 | Migration route | Season and calendar | Elk, geese, whales passing | A hunting season, a spectacle | Calendar |

Authored places (G-26, G-27, the fallen city) use the AI-assisted authoring path in `DESIGN_IDEAS.md` 4.12: authored with AI help, fixed data once approved, the same on every generation.

## 11. Progression across the world

Progress is a widening of what the player can reach and understand, not only a bigger number. Three tracks climb together: **Power** (level, gear tier, skills), **Reach** (boat, ship, mount, climbing kit, cold and heat gear), **Knowledge** (journal, rumours, maps). A dynasty carries reach and knowledge to its heirs more than power.

| Ring | Where | Levels | The player has | New things to meet |
|---|---|---|---|---|
| 1 Home [Dave] | Starter town and near | 1-5 | Camp, fire, torch, basic tools | Rabbit, deer, fox, boar; goblins at night |
| 2 The island [Dave] | Mid and far side | 5-20 | Better tools, a horse or dog, a journal | Bear, wolf, moose, dens, peaks |
| 3 The sheltered sea | Neighbouring temperate islands | 10-25 | A boat | Seabirds, seals, new archetypes |
| 4 The wild east and west | Harder temperate islands | 20-40 | A ship, a crew | Cliffs, volcanoes, storms, apex birds |
| 5 The extremes | Equator and polar rows | 35-60 | Cold or heat gear, expedition kit | Yetis, sandworms, ice and fire islands |
| 6 The abyss and the ultimate island | Centre | 60+ | A true expedition | Dragons, wyverns, kraken, the fallen city |

Rings 3 to 6 are [Proposal] bands read from Dave's danger map, to be tuned in play.

## 12. How the AI helps Dave discover more

**[Dave]** "I want to leverage you as the AI to help me discover new things to add to our game, how to implement them, and to decide and map how players should interact with them."

### 12.1 The discovery loop (repeats)
1. **Find.** The coordinator takes one habitat, one archetype or one gap in the matrix, and reads real natural history, the repo's docs and the models we own.
2. **Propose.** An idea card with an ID, tagged Proposal.
3. **React.** Dave answers by ID in a few words. No questionnaires, no cards.
4. **Decide.** An approved idea becomes [Dave], is folded into `DESIGN_IDEAS.md` as a tagged item, and the plan gains a task with an owner.
5. **Build.** The owner walks the implementation path (section 2): design doc, data, code, gate, PC check, merge.
6. **Learn.** The lesson goes into `docs/knowledge/`; the matrix is regenerated.

### 12.2 The idea card
`ID` · name · what it is (one line) · where it lives (habitat keys) · why it is fun (verbs) · what it touches (systems, owners) · what it needs first · cost (S, M, L) · risk · Dave's intent behind it.

### 12.3 Where the AI decides and where it does not
When Dave is away, the coordinator answers agents' questions from Dave's stated intent and the agents' own recommendations, and records each answer in the thread and in project memory. Thin design (a new mechanic, a new creature class, how deadly a place feels) gets a written recommendation and waits for Dave's reaction before game content is built; docs and data preparation go ahead. Technical choices stay with the owning agent.

## 13. Decisions the coordinator has taken under Dave's intent

These are recommendations applied now so work is not blocked. Dave can overturn any by ID.

| ID | Decision | Reason |
|---|---|---|
| D-01 | G-16 (five-point test) and G-17 (interaction cards and matrix) are in force now for docs and data. | They cost nothing in code and stop drift. |
| D-02 | G-03 habitat keys are added as optional schema now; no placement uses a key until a system can answer it. | Data before code; no churn later. |
| D-03 | Taming (G-09) order: companion and mount first, livestock second, familiar last. | Horses, dogs and wolf pups exist; familiars need quests. |
| D-04 | Amended by D-09: family knowledge (G-18) is inherited by the heir; journal pages are copyable items and are not inherited. | Knowledge is the dynasty's long game; pages follow the item rules. |
| D-05 | G-22 cave behind a fall: parked until the rebuild gives hanging-valley falls, then revisited against the "caves only at river starts" rule. | Do not break a Dave rule for scenery. |
| D-06 | G-02 hot-row animals come in at Phase 6 with the dune and savanna archetype. | Right world for them; no model cost. |
| D-07 | Climbing gets a design doc in Phase 5 before any code. | Without it peaks are scenery; with no design it would be a patch. |
| D-08 | Rings 3 to 6 bands stand as drafted until play says otherwise. | Tuning needs play data. |
| D-09 | `DESIGN_IDEAS.md` 6.15 wins where it and this document differ on journals and knowledge. D-04 is amended to match: family knowledge is inherited by the heir; journal pages are copyable items and are not inherited. | 6.15 is the earlier, more detailed design. |
| D-10 | Mountains: Dave wants colossal, epic fantasy peaks, on the starter island too. (1) Relief varies per island and per seed. (2) Island character is set at the landform and seed stage: `sketch_rules.json` gives `summit_m` per island type (starter 1000-1450 m, volcano 1500-2300 m, three-peak 2000-2700 m, giant up to 3400 m). (3) Erosion only carves valleys; it never erodes summits below the landform. (4) Peaks are built within the rock's standing angle, with granite under massif tops. | [Dave] intent; systemic, so the same rules make every island. |

## 14. The phased plan

Principles: data first; nothing blocks on the rebuild that does not have to; one creature or feature at a time with a written completion criterion; small PRs with one owner; no PC work ahead of Sonny; every phase ends with something Dave can see or play.

| Phase | Goal | Deliverables | Owners | Depends on | Done when |
|---|---|---|---|---|---|
| **0 Agree the guide** (now) | This document in main; Dave reacts by ID | This PR; Dave's reactions; `DOC_MAP.md` entry | Coordinator, Jamie | None | Dave has said yes, no or later to the proposals, or the decisions in section 13 stand |
| **1 The creature record** (docs and data) | Every creature described the same way; gaps visible | G-03 optional habitat keys in the schema doc and loaders; G-17 an interaction card for each existing species and the generated `INTERACTION_MAP.md`; a gap list | Coordinator (cards), MikeW (loader reads keys, after batch 3), Jamie (docs) | None | The matrix exists and the gap list feeds Phases 2-6 |
| **2 Discovery with existing animals** | A player can learn the animals already in the game | G-18 journal page with the five-rung ladder; two sign kinds per species in `animal_sign.json`; G-07 crows and ravens gather at a carcass | Steve (journal state, inherited), Kathleen (look), MikeW (sign), Jason (calls) | Steve's readers (#541) agreed first | On the starter island, see a sign, follow it to a fox, watch the journal fill |
| **3 Archetypes and rumours** | The map says what each island is for | G-01 archetype tag per island in the world plan; G-19 ten rumours for the starter ring on the news rail; G-08 bat emergence at inhabited caves; one content brief per archetype | Coordinator (briefs), Steve (news rail), Sonny (tag, only after the rebuild's current step), Jason and Kathleen (bats) | The world sketch stable; not R-steps | One page per archetype and the tag in the plan |
| **4 Shared systems** (the heavy phase) | A creature becomes a row of data | G-09 taming (companion and mount first); G-15 soaring (lift field, birds as signs); cave life (dens inside caves, sleeping, foraging, stealing); G-05 beaver ponds; G-04 honey | MikeW (behaviour), Steve (state, persistence), Sonny (water and caves), Kathleen (looks) | Taming: batch 3 animals; Soaring: existing wind and relief; Cave life: R5 cave springs; Beaver and honey: R6/R7 and flora | Per system: one real creature uses it in play on the PC and its data row is the only creature-specific code |
| **5 Peaks, water and fishing** | The rebuild's lakes, falls and wetlands become living places | G-06 fishing and the salmon run; G-20 eyries and G-21 tarns placed by slope, rock and cirque tags; a climbing design doc then climbing kit; G-12 marsh lights; wetland creatures by type | MikeW, Steve, Sonny, Kathleen, Jason | R3, R4, R5, R6, R7; Phase 4 soaring and taming. No water creature before R6. | Climb to an eyrie and watch an eagle; fish a river whose size matches its flow |
| **6 Coast, sea and the hot row** | Sailing is an adventure with life in the water | G-11 whale and dolphin encounters, albatross, sharks at blood, tide pools; G-24 sea stacks; G-25 wrecks with life; G-02 hot-row animals on the dune archetype; atoll and seabird isle content | MikeW, Kathleen, Jason, Sonny (ocean), Steve (ships) | Ships and sailing design; ocean look; Phase 3 tags; sea-life models (Need) | Cross open water, see a whale, land on an atoll, meet a turtle |
| **7 Fantasy creatures and hard islands** | The mythical layer, built with G-16 | A roster: antler-moss stag, stone-hide boar, ember-wolf, cave bear, roc, yeti, sandworm, troll, kraken, wyvern; G-10 lair puzzles; regional variants by material and scale (frost wolf, ember boar); fire, ice and storm hazards | MikeW, Kathleen, Jason; Dave makes models in Meshy as he did the goblins | Taming for mounts; soaring for roc and wyvern | Each creature passes the five-point test and has a card |
| **8 The ultimate island and the abyss** | The centre of the world as Dave designed it | Dragons and wyverns, sandworms and scorpions, the fallen city, labyrinths and boss lairs, lava river, old road, the greatest loot; G-14, G-26 to G-28 as authored places | All | Everything above | A prepared expedition crosses the abyss, lands, survives a day and brings something back |

### 14.1 What the plan needs from the rebuild

| Need | From | Earliest use |
|---|---|---|
| Ground, rock and slope as one record | R6 | Phase 5 (cliff habitat, eyries) |
| Water kinds with cause (river, lake, tarn, fen, bog, spring pool) | R3, R4, R6 | Phase 5 |
| Discharge per reach | R5 | Phase 5 (fish, river danger) |
| Glacial features (cirque, trough, hanging valley, fall) | R2b | Phase 5 (tarns) |
| Cave springs by cause | R5 | Phase 4 cave life (den placement moves with them) |
| Live water seeded from the record | R7 | Phase 4 beaver ponds |
| Readers for every dependent system | Stage E (Steve, #541) | Phase 2 onward |

Until these land, Phases 0 to 3 and the shared systems that need no new water (taming, soaring, journal) go ahead. This plan never asks Sonny or Dino for anything; it reads what they publish.

### 14.2 What the plan needs from the creature pipeline

One-at-a-time integration with the reusable recipe (MikeW, `ANIMALS_BATCHES.md`); species numbers (next free 30 after batch 2); role-mapped clips (follow for taming, glide for soaring, stand-and-drink for fishing); batch 3 farm animals for taming. **Model gap:** the pack has no eagle, hawk, owl, bat, dolphin or whale. Sky, cave and sea life depend on Dave making these in Meshy or another source; the coordinator keeps the missing-model list by priority: golden eagle, bat, raven, whale, dolphin, owl.

### 14.3 How a creature gets added (the recipe)

1. Idea card approved ([Dave]). 2. Interaction card. 3. Five-point test if fantasy. 4. Model: owned, or made by Dave; purchased never committed. 5. Rows: `animals.json` (movement, habitat keys, temperament, seasons, young, tame), `models.json`, carcass and parts, sign, sound slot, species kind. 6. Gate on David4, then Dino on the PC: it appears, faces the right way, plays its clips, behaves as the card says. 7. Knowledge line in `docs/knowledge/animal-behaviour.md`. 8. Matrix regenerated; gaps rechecked.

### 14.4 Measures

Species with a card: all, at Phase 1. Species with three or more verbs: 80% of the roster by Phase 6. Habitats with a Discover creature (cave, peak, sky, wetland, coast, open sea, polar, desert): all eight by Phase 7. Archetypes with a content brief: all nine by Phase 3. A progress report (done, in progress, blocked) kept by the coordinator and updated each phase.

### 14.5 Risks

Competing with the rebuild for PC time (no PC work before Phase 4 except what Dino can fit). Model gaps (list kept; Dave's Meshy path). New mechanics invented without design (each gets a design page and Dave's reaction first). Scope (archetypes ship one at a time, Hearth first). Weak machines (coarse far simulation, caps per quality). Public repo (asset folders ignored). Conflicts with standing rules (flagged in section 13; no change without Dave).

## 15. What not to do

- Do not commit purchased models or name a pack's files in the public repo.
- Do not place species by distance from town; only their level.
- Do not add a creature row without an interaction card.
- Do not add a mechanic inside a creature; add it to a shared system and give the creature data.
- Do not add something with no use: every creature gives food, a sign, knowledge, a threat or a companion.
- Do not run tests or bakes in the cloud. Do not put questions or cards to Dave.

## 16. Where this fits

| Doc | Relation |
|---|---|
| `DESIGN_IDEAS.md` | Permanent ideas file; approved proposals are folded in as tagged items. |
| `DESIGN_PRINCIPLES.md` | Principles this document applies. |
| `docs/water/Dynasty_How_Natural_Watersheds_Work.md` | Dave's authority on water. |
| `docs/water/watershed_rebuild_design.md` | Sonny's rebuild; this plan depends on R1 to R8. |
| `docs/water/stage_e_readers_design.md` (#541) | Steve's readers; every dependent system reads the record through them. |
| `design/ANIMALS_BATCHES.md` | MikeW's pipeline; the roster here extends it. |
| `docs/knowledge/` | The lessons this builds on and feeds. |
