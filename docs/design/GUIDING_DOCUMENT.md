# Dynasty: a life well lived. The Guiding Document

Morgan (game design director), 7 Nov 2026. Draft 1 for Dave to react to.

This is the one page every agent reads to learn what the game is *for*. It does not replace `DESIGN_IDEAS.md` (the permanent ideas file), `DESIGN_PRINCIPLES.md` or the knowledge library. It sits above them: it says what we are building toward, what a player does in the world, and how new ideas are found, judged and mapped. The phased plan is in [GUIDING_PLAN.md](GUIDING_PLAN.md).

## How to read the tags

| Tag | Meaning |
|---|---|
| **[Dave]** | Dave's intent, in his words or clearly from them (his message of 7 Nov 2026 unless a date is given). |
| **[Existing]** | Already decided or built in the repo docs. The source is named. |
| **[Morgan]** | A proposal by me. Not decided. Dave reacts by its ID (for example "yes M-04, no M-07"). Nothing tagged [Morgan] is built until Dave says so. |

Rules that bind this document (Dave): design docs first; systemic designs, never patches; art goal is realistic with light fantasy exaggeration, aiming at photorealism; the repo is public, so purchased models are never committed (`/assets/animals` is ignored; models Dave makes himself, such as the goblins, may be); no tests or bakes in the cloud.

---

## 1. Vision

**[Dave]** A fantasy adventure game in a massive world of islands and oceans and many climates. The world is full of things to find: creatures to **discover, hunt, tame and avoid**. Creatures need places to live: **caves**, **mountain tops**, and the **sky**, where some soar. Dave can describe ideas but not list them all, so the AI helps him **discover new things to add, work out how to implement them, and decide and map how players should interact with them.**

**[Existing]** The base is a rough-medieval, multiplayer survival and town-building game with a "Sims vibe": a dynasty that outlives one character (heirs), towns players found, real simulated water, seasons, fire, building. Inspirations: Valheim, ARK (a huge island of many climates, fantasy flora and fauna), Atlas (ships between islands), Medieval Dynasty, Minecraft (stumbling into caves) (`DESIGN_IDEAS.md` 1). Light enough for an old quad-core and 8 GB (`DESIGN_IDEAS.md` 3).

**[Morgan] One sentence for the whole game:** *Wherever you go in this world, something is living its own life there, and you can learn it, use it, befriend it, hunt it, or get out of its way.*

The town-building and dynasty game gives players a home and a reason to come back. The adventure game, which this document is about, gives them a reason to leave it.

---

## 2. Pillars

Each pillar is a test. If a new idea fails a pillar, it is changed or dropped.

1. **A living world, not a spawn table. [Morgan, built on Existing]** Creatures live by habitat, season, time of day and need (food, water, rest), the way `animal-behaviour.md` already describes. Where a creature lives depends only on what is natural for it. Distance from the starter town sets its *level*, never its *place* (Dave, 6 Nov).
2. **Discovery is the reward. [Dave + Morgan]** Finding something nobody told you about is worth more than any drop. The world leaves evidence (tracks, calls, feathers, droppings, carcasses, circling birds, rumours) so a curious player can follow a trail from sign to creature to lair.
3. **Every creature has a role, and the role is readable. [Morgan]** From 20 m a player can tell what an animal is (Dave, 22 Oct: "animals count as basic done when they read as the right animal from 20 m"), and from its behaviour what it will probably do. Hidden rules feel unfair (`DESIGN_IDEAS.md` 3, Legibility): a reaction needs a cause the player can see.
4. **Many ways to meet each creature. [Dave]** Discover, hunt, tame, avoid, and more. A good creature supports at least three of those verbs, and the player's choice should matter.
5. **Danger is fair and travels with distance. [Existing]** Safer near home, harder far away, with a danger map by latitude, distance from starters and the abyss at (0,0) (`DESIGN_IDEAS.md` 4.13). Getting killed teaches. Getting killed by something you could not have seen coming does not.
6. **Realistic with a light fantasy hand. [Dave]** A creature is first a believable animal. The fantasy is one signature exaggeration, not a costume. Rule of thumb: you can guess its place in the food chain from its body.
7. **The world is made by systems, not by hand. [Dave]** Habitat comes from the terrain and water record, behaviour from shared data, placement from rules. No per-creature code paths and no per-spot patches.
8. **Safe, kind, generous. [Existing]** Taming, rescue, gifts and second chances are core design, not extras (`DESIGN_IDEAS.md` 3).
9. **Build for the weak machine. [Existing]** Creature counts, animation and sky traffic must fit an old quad-core. Far creatures simulate coarsely, near ones in detail.

---

## 3. The world

### 3.1 What exists

**[Existing]** (`DESIGN_IDEAS.md` 4.1, 4.2, 4.12, 4.13)

- Tiles are 15.36 km square. Islands cross tile borders. The world is planned from a coarse sketch of islands formed the way real ones form: island arcs, hotspot chains, continental fragments, mid-ocean ridges, atolls and reefs. Each feature sets the island's geology and resources.
- Climate runs north to south from the **equator row** (desert, hottest) through temperate to **arctic**, with the north and south poles meeting at the wrap seam. Seasons are real. Altitude cools mountains, so tall equatorial peaks can carry snow.
- The **starter islands** are temperate, low level near the town (levels 1-5), 5-10 mid, 10-20 on the far side.
- Further east and west is harder: higher-level creatures, cliffs, volcanoes, terrible storms. The **equator row** and **polar regions** are higher level with meaner mythical creatures (yetis at the poles). At the centre sits the **abyssal trench** and the **ultimate island**: a desert island with a 1,900 m volcano, ruins of a fallen civilization, dragons and wyverns, sandworms and scorpions, temples, caves and labyrinths, and the best loot in the game.
- At sea: ships, wrecks to dive, flotsam from real events, pirates, sea monsters (kraken, attacking whales) in the dangerous waters.

**[Existing, in progress]** Sonny is rebuilding terrain and water as one watershed system (`docs/water/watershed_rebuild_design.md`, steps R1 to R8). It will give us glacial lakes, cirques, waterfalls from hanging valleys, springs, seeps, wetlands by type (marsh, swamp, fen, bog), and rivers sized by their supply. MikeW is integrating the purchased rigged animals one at a time (`design/ANIMALS_BATCHES.md`). This document builds on both and does not compete with them.

### 3.2 Island archetypes

**[Morgan, M-01]** The world sketch already knows how each island formed. I propose we turn that into a named set of **island archetypes**, so every island promises something different and the generator can fill in the details from its rock, climate and water, not from dice. An archetype is a *recipe the existing sketch already supports*, not a new generator.

| Archetype | Born from | Look and climate | Signature place | Signature creatures (some already modelled) | Signature hazard | Why a player sails there |
|---|---|---|---|---|---|---|
| **Hearth island** (starter) | Continental fragment | Temperate forest, meadow, rivers, spring caves | Spring caves with goblin dens, river heads | Deer, boar, wolf, fox, bear, moose, rabbit, goblins | Low-level wolves and bears | Learn the game. Home. |
| **Highland island** | Continental fragment, folded rock | Heath, boreal forest, alpine meadow, glacial tarns | Peaks with eyries, cirque lakes | Bighorn, mountain goat, chamois, lynx, black bear, golden eagle | Cold, falls, storms | Rare ore, trophy game, climbing |
| **Fen and moor island** | Low continental fragment, glacial flats | Marsh, fen, bog, mist | Wetland nesting grounds | Moose, beaver, mink, geese, herons, marsh lights (see M-12) | Bogs, getting lost | Peat, reeds, birds, quiet danger |
| **Fire island** | Volcanic arc | Black rock, steam, hot springs, ash forest | Geothermal pools, lava tubes | Fumarole crawlers, ember boar, cliff nesters | Heat, gas, eruptions | Obsidian, sulfur, hot-spring camps |
| **Seabird isle** | Hotspot chain, old basalt | Treeless turf, sea cliffs | Cliff colonies, sea stacks | Gulls, puffins, seals, sea eagles | Wind, slippery rock | Eggs, feathers, seal hunting |
| **Reef atoll** | Coral on old volcanoes | Lagoon, palms, white sand | Lagoon, reef, wreck diving | Turtles, rays, sharks, crabs, tropical birds | Sharks, tides | Pearls, limestone, calm anchorage |
| **Ice island** | Arctic arc | Glacier, fjord, sea ice | Ice caves, whale bays | Polar bear, walrus, seal, musk ox, arctic fox, yeti | Cold, whiteout | Sled routes, whaling, rare furs |
| **Dune and savanna island** | Equator row | Desert, scrub, wadis, salt flats | Oases, ruined shore villages | Camel, lion, hyena, vultures, scorpions | Heat, thirst | Gold, ruins, old roads |
| **The ultimate island** | Fixed, `center_island` | Volcano desert | Fallen city, lava river, labyrinths | Dragons, wyverns, sandworms | Everything | The greatest rewards |

**[Existing]** Rows 1 and 9 are Dave's design. **[Morgan]** The rows between are my proposal, drawn from his list of regions and from the real islands the sketch already copies (Iceland, Hawaii, the Aleutians, the British Isles).

Two notes. First, the animals we bought but left out as "wrong world" (camel, lion, leopard, hyena, rhinoceros, warthog, wildebeest, elephant and others in `design/ANIMALS_BATCHES.md`) are right for the **dune and savanna island** and the wetter equatorial islands. **[Morgan, M-02]** Keep them in the pack folder and bring them in at Phase 6, not never. Second, Dave's rule that an island's moisture can vary (4.2: "not every desert-row island is sand") gives us savanna and jungle islands on the hot row for free.

### 3.3 Habitat is data, not code

**[Morgan, M-03]** Every creature row in `data/animals/animals.json` already has `biomes`, `near_fresh_water_m` and `near_ocean_m`. I propose we extend the same style of key to cover every habitat Dave named, so a mountain-top or sky creature is only a new row, never new code:

| Key | Meaning | Fed by |
|---|---|---|
| `altitude_m` (min, max) | Height band | Terrain |
| `slope_deg` (min, max) | Cliff and crag dwellers need steep rock | Terrain |
| `rock` | Needs rock outcrops, scree, ledges | Geology |
| `water_kind` | River, lake, tarn, fen, bog, spring pool, hot spring | Water record (rebuild R6) |
| `cave` | Den tier, depth band, wet or dry | Cave skeleton (`tile_sites.gd`) |
| `canopy` | Under or in trees, hollow trunks | Flora |
| `sea_depth_m` (min, max) | Shore, shelf, open ocean, abyss | World elevation |
| `sky` | Soars. Uses updrafts. Roosts at `lair` | Wind and relief |
| `lair` | `den`, `burrow`, `nest`, `eyrie`, `hollow`, `warren`, `roost`, `holt`, `haulout` | Placement rules |
| `season` | `migrate`, `hibernate`, `rut`, `breed`, `moult` | Calendar |

Before the rebuild lands (R6), only the keys the current terrain can answer are used. The rest are written down now so the data does not need redoing.

---

## 4. Creatures by habitat

The verbs: **Discover** (find and learn), **Hunt** (food, hide, trophy), **Tame** (companion, mount, livestock, familiar), **Avoid** (a danger to read and dodge), **Harvest** (take without killing: honey, wool, eggs, feathers, milk), **Ally** (it helps you unasked), **Study** (a journal entry that unlocks knowledge).

Key: ✔ the verb is the main one. ○ possible. blank = not intended. **Have** = a model we own or Dave made. **Need** = no model yet (Meshy or another source). `L` = lair type. Everything marked [Existing] is in `animals.json` or `ANIMALS_BATCHES.md` today; the roles marked [Morgan] are proposals.

### 4.1 Forest, meadow and farmland (the Hearth island)

| Creature | Model | D | H | T | A | Ha | Notes |
|---|---|---|---|---|---|---|---|
| Rabbit, fox, deer, boar, moose, wolf, bear | Have, [Existing] | ✔ | ✔ | | ✔ | | Temperaments, flee and threat ranges, seasons and young are built (#480, #485). |
| Horse, donkey | Have, [Existing] | ✔ | | ✔ | | ○ | **[Dave]** wild first, tamed later, each horse with a tamable value; riding and harness future (`DESIGN_IDEAS.md`, Horses). |
| Black bear, lynx, elk | Have, batch 1 | ✔ | ✔ | | ✔ | | In MikeW's current batch. |
| Cow, goat, chicken, cat, dog, buffalo | Have, batch 3 | ○ | | ✔ | | ✔ | Livestock and companions. Not tameable "until the taming design says so" (`ANIMALS_BATCHES.md`). This document is that design (section 6). |
| Songbirds, grouse, pheasant, crow, goose | Have | ✔ | ✔ | | | ○ | Crow and raven are also **Allies** (M-07). |
| Honey bees and a wild hive | Need | ✔ | | | | ✔ | **[Morgan, M-04]** see below. |

### 4.2 Wetlands, rivers and lakes

The watershed rebuild makes these places real: marsh, swamp, fen and bog by cause, glacial tarns, seeps, spring pools, beaver-able streams. **[Existing]** Sonny's design says "beaver ponds belong to the ecology later". This is that later.

| Creature | Model | Roles | Notes |
|---|---|---|---|
| Frog, duck, goose | Have | D, H | Already tied to fresh water (`near_fresh_water_m`). |
| Beaver | Have, batch 1 | D, Harvest, Ally | **[Morgan, M-05]** A beaver *builds*: it damns small low-gradient streams in woodland and raises a pond. The pond is a real water feature. Players can break a dam to drain it, or use the pond. Needs the rebuild's record to place and the live water to hold. Phase 4. |
| Mink, raccoon | Have, batch 2 | D, H | Pelts, small threats to a chicken coop. |
| Moose | Have | D, H, A | Wades in fens and tarns in the autumn rut. |
| Heron, kingfisher, otter | Need | D, Study | Signs of a healthy stream: fish present. |
| Trout, salmon, bluegill | Have (trout, bluegill) | H | Need the fishing system (`ANIMALS_BATCHES.md`). **[Morgan, M-06]** a **salmon run** on rivers that reach the sea, in autumn: bears, eagles and wolves gather. A seasonal spectacle that shows the whole food chain at once. |
| Marsh lights (will-o'-the-wisp) | Need | D, A | **[Morgan, M-12]** A pure light effect over bogs and fens at night: marsh gas, drawn from fact, with a fantasy lure that leads travellers astray. A hazard with no model cost. |

### 4.3 Caves and the underground

**[Existing]** Caves are skeletons of passages carved into voxels. **Spring caves** sit only at river heads, inland, a hill foot, about 100 m deep with a pool at the back and dens in side branches. Every cave has a chance of being inhabited by animals, creatures or people (Dave, 6 Nov): good NPC survivors or bandits. Goblins live in a dry offshoot den. Bears den in caves. Hazards: steep slopes, thin rock bridges, tight squeezes. Ore shows in the walls. Rock shelters stay. Karst and sea caves are off for now (`caves.md` lesson 9).

**[Dave]** "Things need caves to live in." So the cave is the home of the creature, and the creature tells you what the cave is.

| Dweller | Where | Roles | Notes |
|---|---|---|---|
| Bear (black, brown) | Spring cave den | A, H | Hibernates in winter; torch does not protect in its den (Dave). |
| Goblins | Dry offshoot den (bones, sticks, thatch, small fire) | A, Study, ○Tame (see M-09) | **[Existing]** groups of 2 to 5, nocturnal, skittish. |
| Bats | Any cave, flies out at dusk | D, Ally | **[Morgan, M-08]** A mass emergence at dusk is a free spectacle and a clue: a cave with bats is deep, dry and has a second opening. They guano. |
| Glowworm ceiling | Wet chambers | D | **[Morgan]** Real (New Zealand, Australia). It is the one source of light in a pitch-black cave, which Dave already made truly dark. Fantasy: stronger glow. |
| Cave snake, giant spider | Deep dry branches | A | Named in `DESIGN_IDEAS.md` 4.4 as cave creatures. |
| Olm and blind cave fish | Cold spring pools | D, Study | **[Morgan]** Real. Pale, long, harmless, a quiet joy for a patient player. Tells you the pool is old and connected. |
| Survivors, hermits, bandits | Any inhabited cave | Ally, A | **[Existing]** NPCs. Hermits trade rumours (section 7). |
| Cave bear (fantasy, bigger) | Deep caves on harder islands | A | Same model family as the bear with scale and scar variants. |
| Troll or ogre | Rare, deepest, harder islands | A | **[Morgan, M-10]** Not a stat block but a *lair puzzle*: it is asleep by day, hates sunlight and the river that runs through its cave is the way to lure it out. |

### 4.4 Mountains and crags

This is where the rebuild's glacial history pays off: cirques, tarns, troughs, hanging valleys and falls, and the cliff and scree ground that fits climbers.

| Creature | Model | Roles | Notes |
|---|---|---|---|
| Bighorn sheep, mountain goat, chamois | Have | D, H | **[Existing]** batch 1 and 2. They flee *up*, which is a hunting lesson. **[Morgan]** Their habitat is `slope_deg` and `rock`, not a biome. |
| Marmot, pika, ptarmigan | Need | D | **[Morgan]** Small alpine life; marmots whistle an alarm that tells you something big is near. |
| Snow leopard, wolverine | Need | A, H | Rare, solitary, hard to find: a trophy hunt for patient players. |
| Golden eagle | Need | D, Study | Nests in an **eyrie** on a crag (`lair: eyrie`). See 4.5. |
| Mountain troll, stone giant | Need | A | **[Morgan]** At the top of the danger scale on harder islands; see M-10. |
| Avalanche and rockfall | System | A | Not a creature but a place hazard that the climate and slope already imply. |

**[Dave]** "Some things live on mountain tops." **[Morgan]** I want the peaks to be a reason to climb, not only to look at. Each high peak should have **one thing worth the effort**: an eyrie, a hidden tarn, a ruin, a shrine, a meteor (M-14). Climbing needs a verb the game does not have yet (rope, pitons, hand-holds): see the plan, Phase 5.

### 4.5 The sky

**[Dave]** "Soaring around in the sky." Birds are the cheapest way to make a world look alive, and soaring is a real behaviour that depends on terrain: hawks and eagles ride **thermals** over sun-warmed slopes and **ridge lift** where wind meets a hill, vultures circle over death.

**[Morgan, M-15]** One **soaring system**, not many scripts:

- The wind and the relief already exist (the rebuild's orographic rain model uses them; grass sways with the world wind). From them a cheap *lift field* says where air rises.
- A soaring bird picks a lift cell, circles up in it, glides to the next. It needs no path-finding and costs almost nothing when far.
- Birds are *signs*: **vultures circling mark a carcass; crows or ravens gathering mark a kill or a fight; gulls mark the coast and a fishing school; a hawk hanging still marks prey; geese in a V mark a season change.** Players learn to read the sky.
- **Apex sky creatures** then use the same system at larger scale: sea eagle, golden eagle, **roc / thunderbird** (a huge eagle; real extinct Haast's eagle was about 15 kg, so "light fantasy" scales it), wyvern, dragon (Dave's list, ultimate island). They *hunt*: a roc takes goats and sheep, and a careless player in the open on a high ridge.
- **Avoid** is the main verb for apex birds. Counterplay: cover, a shield held up, a torch at dusk, a horse that bolts under a shadow. **Tame** applies to a few: a hawk or falcon for hunting small game (a long-term companion), a raven.

### 4.6 Coast and sea

**[Existing]** Seals haul out on bare rock and salt marsh; gulls use salt marsh; players can dive wrecks and spear-fish; sea monsters belong to dangerous waters.

| Creature | Model | Roles | Notes |
|---|---|---|---|
| Gull, seabird, seal | Have/ Existing | D, H | Haul-out sites and nesting cliffs. |
| Crab, shellfish, kelp | Need | Harvest | Tide-pool foraging is a safe, gentle start. |
| Fish (many) | Have (3) | H | Needs fishing (M-06). |
| Dolphin, whale, shark, ray, turtle | Need | D, A | **[Morgan, M-11]** Whale and dolphin pods are *encounters* for sailors: a pod alongside is a good omen, a whale breaching near a small boat is a fright. Sharks gather where blood is in the water. |
| Kraken, sea serpent | Need | A | **[Existing]** kraken is in the plan for dangerous waters. |
| Walrus, polar bear | Need | H, A | Ice islands. |
| Sea eagle, puffin, albatross | Need | D | Albatross: a real seabird that follows ships for days: **Ally** (it means land is on the way, a navigation clue). |

### 4.7 Polar and desert extremes

**[Existing]** Polar regions: yetis and other mythical creatures; sea ice with seasonal thickness; hunting seals, ice fishing, polar creatures. Desert row: the harshest climate, dragons and wyverns, giant sandworms and scorpions.

**[Morgan]** The same rule applies to both: *the animal is real and the exaggeration is small*, then a mythical apex sits at the top. Real: polar bear, musk ox, arctic fox, walrus, snowy owl; camel, lion, hyena, vulture, scorpion, monitor lizard. Exaggerated: a yeti is a scaled-up wild thing of the high snows, not a man in a suit; a sandworm is a desert sea-serpent whose approach you feel through the ground.

### 4.8 What makes a fantasy creature belong here

**[Dave]** Art goal: realistic, light fantasy exaggeration, photorealism. **[Morgan, M-16]** A short test for any new fantasy creature:

1. It has a **real animal at its base** (so it moves, eats and reproduces believably).
2. It has **one signature exaggeration** (size, glow, hide, horns, a call), and we can say what it is *for*.
3. It **fits a habitat** (it has a niche, a lair and a food chain).
4. It has **a readable warning** (a sound, a posture, a silhouette).
5. It **supports at least three verbs.**

Examples that pass: the antler-moss stag (an elk whose antlers carry living moss and lichen: a real effect in old animals, exaggerated), the stone-hide boar of volcanic islands (a boar with a plated hide that reads as basalt), the ember-wolf (a wolf with a faint heat-glow beneath its fur on fire islands). Examples that fail: a rainbow unicorn, a generic dragon with no lair.

---

## 5. How players meet a creature: the interaction map

**[Dave]** "Decide and map how players should interact with them." **[Morgan, M-17]** Every creature gets one **interaction card**. It is the same shape for all, filled from data, so the map of the whole game is a table you can read in one sitting. Here is the card, then a worked set.

### 5.1 The card

| Field | What it answers |
|---|---|
| **Niche** | Habitat keys (3.3), activity (day, night, dusk), diet, food-chain place. |
| **Sign** | What the player finds *before* the animal: tracks, scat, feathers, calls, a kill, a smell, circling birds, a rumour. |
| **Senses** | Sight, hearing, smell: which the animal uses, and the wind. |
| **Temperament** | Mix of passive / neutral / defensive / aggressive / friendly [Existing]. |
| **Warning** | What it does before it acts, so the reaction has a visible cause. |
| **Verbs** | Discover, Hunt, Tame, Avoid, Harvest, Ally, Study: which, and how. |
| **Reward** | Food, hide, bone, trophy, knowledge, a companion, a clue. |
| **Counterplay** | How a player with the right tool, skill or plan beats or escapes it. |
| **Level and tier** | Level range from the danger map; gear tier that makes it fair. |
| **Seasons** | Hibernate, rut, migrate, young. |
| **Systems touched** | The code that must exist (so we find dependencies early). |

### 5.2 Worked cards

| Creature | Sign | Warning | Verbs | Counterplay | Needs |
|---|---|---|---|---|---|
| **Deer** | Tracks, rubbed bark, a soft call at dusk | Head up, ears turn, stamp | Hunt, Discover | Downwind, still, a thrown spear from cover | Existing |
| **Bear (den)** | Claw-marked trees, torn logs, a smell, a bone pile | Huff, jaw-pop, stand up, then charge (WARN then CHARGE) | Avoid, Hunt, Study | Stay out of the 15 m den ring; a mother with cubs is worst; fire does not help at the den | Existing (#480) |
| **Wolf** | Howl, tracks in a line, scat | Growl, low circling | Avoid, Hunt, Tame (pup, M-09) | Torch (8 m protection), fight at a chokepoint | Existing |
| **Goblin band** | Footprints at the fire's edge, a missing item, glinting eyes | Sudden retreat, a whistle | Avoid, Study, Ally (M-09) | Stay in light; leave food out and they watch; never corner them | Existing + den work |
| **Beaver** | Gnawed stumps, a lodge, a new pond | Tail slap | Discover, Harvest, Ally | Break a dam; a pond is a fishing spot | M-05 |
| **Bighorn / goat** | Scat on ledges, a clatter of stones, a lone sentinel | Bound upslope | Hunt, Discover | Climb above them; they flee up | Climb + slope habitat |
| **Golden eagle** | A wheeling dot, a shadow, white-washed ledges, a kill | A scream and a stoop | Avoid, Study, Tame (falconry) | Keep to cover in the open; a shield; shoot in the dive | Soaring + eyrie |
| **Vulture / raven** | Circling | None (they are a sign) | Discover (the kill), Ally | Follow them | Soaring |
| **Seal** | A head in the surf, barks, a haul-out | Slides into the water | Hunt, Discover | Approach from the sea side, not the land | Existing |
| **Whale** | A spout, a sound across the water | None | Discover, Study | A calm ship; do not rock it | Sea |
| **Cave glowworms** | A faint blue-green glow before you see the cave | None | Discover | Light off: they are your light | Cave dressing |
| **Dragon / wyvern** | Scorched ground, a burnt-out camp, a rumour, a long shadow | Smoke, a roar, a gust | Avoid, Study | Cover, water, a ballista, a ship | Ultimate island |

### 5.3 Reading the whole map

The worked cards roll up into one **creature × verb matrix** (in `docs/design/INTERACTION_MAP.md` when Dave approves the card shape: **[Morgan, M-17]**). It is the tool for catching gaps: a habitat with no Discover creature, a tier with no Avoid creature, a verb (Tame) used by only two species. The matrix is regenerated from `animals.json` plus the cards, so it never goes out of date.

---

## 6. Taming, hunting and avoiding as systems

Three shared systems carry all of it, so each new creature is only data.

### 6.1 Hunting

**[Existing]** Senses (sight, hearing, wind scent), flee and threat range, temperament, seasons, young, carcasses and parts, thrown spears, snares (#219 open). **[Morgan]** Add: **tracking** (sign leads to the animal, section 5), **trophy quality** (older males are warier, theHunter-style, per `animal-behaviour.md`), **clean kills versus wounded animals that flee and die later** (a rewarding and humane-feeling reason to aim), and **season rules** (mothers with young, rut males). All through the existing temperament and range data.

### 6.2 Taming

**[Existing]** Horses have a per-animal tamable value; farm animals wait for a taming design; **familiars** (companion animals with personalities, from dogs and crows to a dragon whelp) are future; young animals already exist as real animals following their mother.

**[Morgan, M-09]** One taming system, four **bonds** that differ in how you get them and what they give:

| Bond | How it is earned | What it gives | Examples |
|---|---|---|---|
| **Livestock** | Buy or catch young; house, feed, keep | Milk, wool, eggs, meat, hide | Cow, goat, chicken, sheep |
| **Mount** | Gentle approach; feed and patience; saddle later | Speed, load, a longer reach | Horse, donkey, camel; later a great elk or a hippogriff-like mount on fantasy islands |
| **Companion** | Raise from the young (imprint) or earn trust at a camp over days | Follows, guards, warns, hunts, finds | Dog, cat, wolf pup, fox kit, hawk, raven |
| **Familiar** | A quest or a mentor, never a catch | Talks, has personality, grows with the player | Parrot, monkey, raven (Dave's Claptrap-style idea in `DESIGN_IDEAS.md` 6.11) |

The verbs are the same across all four: **approach, offer, wait, bond.** The creature's temperament sets how long and how careful it takes. A friendly one comes close at once; a flighty horse always runs; a wolf pup raised from the young is loyal for life but a wild adult is never tamed. The taming ladder is *data*: `tame: { bond, food, trust_per_day, min_level }`. A bond is not a button. It is a few days of presence, which suits a game that already runs on a real clock.

Companions are individuals with a name, a bond level, an ownership history, and a hand-me-down: **a dynasty can pass a companion to an heir** (`DESIGN_IDEAS.md` 3, Provenance). **[Morgan]** It is the single strongest link between the adventure game and the dynasty game, which is why I would not skip it.

### 6.3 Avoiding

Avoiding must be a skill with tools, not a coin toss: **stealth** (sneak, crouch, stay downwind), **terrain** (a river, a cliff, a tree they cannot climb), **light and fire** (goblins and wolves keep out; the den-bear and a mother with young ignore it), **sound** (do not clatter), **shelter** (roof, cave mouth), **speed** (run 9 m/s), and **companions** (a dog's bark warns first). The warning (section 5) is the contract: the player is always given something to see or hear before the danger acts.

---

## 7. Discovery: how a player learns the world

**[Dave]** "Creatures to discover." Here is one system for it.

### 7.1 The field journal

**[Existing]** `DESIGN_IDEAS.md` 6.15 has journals and libraries ("what a character knows"). **[Morgan, M-18]** Use that one place for creature knowledge. Each species has a ladder of **knowledge**:

1. **Heard of** (a rumour or a sign).
2. **Sighted.**
3. **Observed** (a few minutes watched at a distance without being noticed).
4. **Tracked** (found its lair or sign trail).
5. **Studied** (killed, tamed, or watched across a season).

Each rung reveals more: its range, habits, weak points, drops, safe approach, and finally its lore entry. Knowledge is the *reward for the cautious player*: you can unlock the whole ladder without ever killing it. It also gives the AI something to point at: a rumoured creature on your journal is a map to an adventure.

A player's journal is **inherited by an heir** (it is knowledge, not an item), so a dynasty accumulates a natural history. **[Morgan]** That is the long game for explorers.

### 7.2 Rumours and the news

**[Existing]** "News travels with people": warrants, prices and threats are facts with a place and time that spread through travellers, wagons and ships (`DESIGN_IDEAS.md` 13.6). **[Existing]** The game owns the facts; the language model only speaks (principle 3).

**[Morgan, M-19]** Creatures and places become **rumours** on that same rail. A hermit in a spring cave, a sailor in port, a shopkeeper: each can tell you something true about a real creature or place the world already contains ("a white stag has been seen at the head of Greywater"; "the bay beyond the cape smells of sulfur"). The model voices it; the fact comes from the world. Rumours are how Dave's AI helps players *find* things without a quest marker.

### 7.3 Signs

**[Existing]** `data/animals/animal_sign.json` exists. **[Morgan]** Treat sign as a first-class channel. Every species has at least two sign kinds, and a player who knows how to read them (a journal rung) sees them more easily.

---

## 8. Places of adventure

A place is an *event waiting for a person*. It must have a **reason to exist** (the terrain and water made it), a **reason to visit** (a reward), a **way in** (a path or a challenge), a **danger that is readable**, and **a story the player can piece together** from what is there.

**[Existing]** Caves (spring caves, rock shelters), dens, lair sites (dormant sites that the server fills at runtime), ruins and labyrinths on harder islands, the fallen civilization's city and old road on the ultimate island, wrecks to dive, flotsam, bandit camps, remains of fallen adventurers with their gear.

**[Morgan]** Additional place types, each built from the rebuild's output or from systems we already have, with the creature that gives it life:

| ID | Place | Made by | Creature or event | Reward | Needs |
|---|---|---|---|---|---|
| **M-20** | **Eyrie** on a crag | Terrain slope, rock | Eagles, later a roc | Feathers, eggs (risky), a vantage | Soaring system, climbing |
| **M-21** | **Hidden tarn** in a cirque | Glacial history (rebuild B2) | Rare fish, a shrine, a hermit | Calm, clean water, a rare plant | Rebuild R2b, R3 |
| **M-22** | **Behind-the-falls cave** | Hanging-valley waterfall (rebuild) | Bats, glowworms, a hermit | Shelter, a secret | Needs Dave's OK: his rule is "caves only at river starts" |
| **M-23** | **Hot spring camp** | Fire-island geothermal | Steam-loving animals, a bathing NPC | Warmth (comfort), minerals | New water type (hot) |
| **M-24** | **Sea stack colony** | Seabird isle | Nesting seabirds, seals | Eggs, feathers, a lighthouse | Cliffs, boats |
| **M-25** | **Wreck and sunken ruin** | Existing wrecks, flotsam | Rays, moray, a ghost-light | Cargo, a map | Diving |
| **M-26** | **Standing stones and shrines** | Hand-placed on peaks and headlands | A one-time boon | A blessing or a secret | Authoring tool |
| **M-14** | **A fallen star** | A rare event on high ground | A crater, a strange ore | A unique item | Event system |
| **M-27** | **Ruined watchtower** | The fallen civilization, scattered | A bandit or hermit | Loot, a view | Authoring |
| **M-28** | **Migration route** | Season + calendar | Elk, geese, whales moving through | A hunting season, a spectacle | Calendar |

The AI-assisted authoring path in `DESIGN_IDEAS.md` 4.12 ("ruins and roads authored with AI help become fixed data once approved") is the one to use for M-26, M-27 and the fallen civilization, so they are the same on every generation.

---

## 9. Progression across the world

Progress is a **widening of what the player can reach and understand**, not only a bigger number.

| Ring | Where | Levels | The player has | New things to meet |
|---|---|---|---|---|
| **1. Home** | Starter town and near | 1-5 | A camp, fire, torch, basic tools | Rabbit, deer, fox, boar; goblins at night |
| **2. The island** | Mid and far side | 5-20 | Better tools, a horse or a dog, a journal | Bear, wolf, moose, cave dens, peaks |
| **3. The sheltered sea** | Neighbouring temperate islands | 10-25 | A boat | Seabirds, seals, coast, new archetypes |
| **4. The wild east and west** | Harder temperate islands | 20-40 | A ship, a crew | Cliffs, volcanoes, bigger storms, apex birds |
| **5. The extremes** | Equator and polar rows | 35-60 | Cold or heat gear, expedition kit | Yetis, sandworms, ice and fire islands |
| **6. The abyss and the ultimate island** | Centre | 60+ | A true expedition | Dragons, wyverns, kraken, the fallen city |

**[Existing]** The level bands for ring 1 and 2 come from Dave; the rest are my reading of his danger map (`DESIGN_IDEAS.md` 4.13). **[Morgan]** I mark rings 3 to 6 as *proposed bands* for Dave to correct.

Three tracks climb together:

- **Power** (character level, gear tier, skills; `design/TOOL_TIERS.md`).
- **Reach** (boat, ship, mount, climbing kit, cold and heat gear).
- **Knowledge** (journal ladders, rumours, maps). **[Morgan]** Make knowledge matter: a Studied bear lets you read its charge earlier. An expedition without knowledge is harder than the same expedition with it.

A dynasty carries **reach and knowledge** to its heirs more than power. That is how a life well lived adds up over generations.

---

## 10. How the AI helps Dave discover more

**[Dave]** "I want to leverage you as the AI to help me discover new things to add to our game, how to implement them, and to decide and map how players should interact with them."

This is a process, so it can repeat.

### 10.1 The discovery loop

1. **Find.** I look at one habitat, one island archetype or one gap in the interaction map, and read real natural history, the repo's docs and the models we own.
2. **Propose.** I write an **idea card** (below) with a reason it belongs, tagged [Morgan] with an ID.
3. **React.** Dave answers by ID in a few words ("yes", "no", "later", "change X"). No questionnaire.
4. **Decide.** An approved idea becomes [Dave] and is folded into `DESIGN_IDEAS.md` as a tagged item (the existing rule for brainstorm material); the plan below gains a task.
5. **Build.** The owning agent implements it from data. The interaction card and the matrix update.
6. **Learn.** What we learned goes into `docs/knowledge/` (Jamie).

### 10.2 The idea card

`ID` · **name** · what it is (one line) · where it lives (habitat keys) · why it is fun (verbs) · what it touches (systems, owners) · what it needs first (dependencies) · cost (S, M, L) · risk · Dave's intent behind it.

### 10.3 Where the AI should *not* decide

I do not decide things Dave has not covered. Thinly covered design (which species, what a power does, how deadly a place feels) gets a recommendation and waits for Dave to react (`dave-confidence-rule`). Technical choices stay with the owners.

---

## 11. Proposals at a glance

Every [Morgan] item, for Dave to react to by ID. Priority is my reading of value over cost, not a decision.

| ID | Idea | Value | Cost | Phase |
|---|---|---|---|---|
| M-01 | Island archetypes (recipes from the world sketch) | High | S | 3 |
| M-02 | Bring the "wrong world" animals in for the hot row | Med | M | 6 |
| M-03 | Habitat keys for every habitat Dave named | High | S | 1 |
| M-04 | Wild bee hives and honey, with honeyguide birds that lead you to them | Med | M | 4 |
| M-05 | Beavers that build ponds | High | L | 4 |
| M-06 | Fishing and the autumn salmon run | High | L | 5 |
| M-07 | Ravens, crows and vultures as Allies and signs | High | S | 2 |
| M-08 | Bat emergence at dusk | Med | S | 3 |
| M-09 | One taming system with four bonds | High | L | 4 |
| M-10 | Lair puzzles for troll and ogre | Med | M | 7 |
| M-11 | Whale and dolphin encounters for sailors | Med | M | 6 |
| M-12 | Marsh lights | Low | S | 5 |
| M-14 | A fallen star event | Low | M | 8 |
| M-15 | One soaring system (lift field, birds as signs) | High | M | 4 |
| M-16 | The five-point test for fantasy creatures | High | S | 0 |
| M-17 | Interaction cards and the creature × verb matrix | High | S | 1 |
| M-18 | Field journal knowledge ladder | High | M | 2 |
| M-19 | Rumours on the news rail | High | M | 3 |
| M-20 to M-28 | Places in section 8 | Mixed | Mixed | 5-8 |

---

## 12. Questions that need Dave's reaction

I recommend an answer to each. Silence means I carry on with the recommendation only for docs and data, never for built content.

1. **Taming (M-09):** the four bonds. *Recommended: yes.* Companion and mount first.
2. **Knowledge ladder (M-18):** inherited by heirs. *Recommended: yes.*
3. **Caves and the "caves only at river starts" rule (M-22):** a cave behind a fall is a lovely place but breaks the rule. *Recommended: keep the rule for now; revisit once the rebuild gives hanging-valley falls.*
4. **The hot-row animals (M-02):** *Recommended: bring them in with the dune island, Phase 6.*
5. **Rings 3 to 6 level bands:** *Recommended: keep as drafted, tune with play.*
6. **Mount for the great elk and fantasy mounts:** *Recommended: later, after horse and donkey.*
7. **Climbing (peaks):** a climbing verb and kit. *Recommended: yes, and soon, because without it peaks are scenery.*

---

## 13. What not to do

- Do not commit purchased models. Do not name or ship a purchased pack's files in the public repo.
- Do not place species by distance from the town; only their level (Dave, 6 Nov).
- Do not add a creature row without an interaction card.
- Do not add a new mechanic inside a creature. Add it to a shared system and give the creature data.
- Do not add something with no use. "Every resource needs a use" applies to creatures too: every creature gives food, a sign, knowledge, a threat or a companion (`DESIGN_IDEAS.md` 3).
- Do not run tests or bakes in the cloud.

---

## 14. Where this fits

| Doc | Relation |
|---|---|
| `DESIGN_IDEAS.md` | The permanent ideas file. Approved ideas from here are folded in as tagged items. |
| `docs/water/Dynasty_How_Natural_Watersheds_Work.md` | Dave's authority on water. Habitat keys that need water read the rebuild's record, never infer it. |
| `docs/water/watershed_rebuild_design.md` | Sonny's rebuild. This plan depends on R1 to R8. |
| `design/ANIMALS_BATCHES.md` | MikeW's creature pipeline. The roster here extends it. |
| `docs/knowledge/animal-behaviour.md`, `caves.md` | The lessons this document builds on. |
| `docs/GOBLINS.md` | A worked example of a creature built to Dave's spec. |
| [GUIDING_PLAN.md](GUIDING_PLAN.md) | The phased plan. |
