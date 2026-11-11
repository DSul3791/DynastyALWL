# Wood: where logs fit (discussion only, no changes)

Morgan, 10 Nov 2026. Rewritten around Dave's principle: start from what a log is actually for, not from the naming. Data from Jamie's export (main 367e44cb plus #941, #950, #953); "lumber" in recipes is shown as Plank.

## 1. What logs are for (the test)

A thing is made of **logs** only if it is one of:
1. split into firewood or blocks (the chopping block);
2. a **log cabin**: the house, its walls, floor, roof frame, stairs, doors, windows;
3. sawn into planks at a saw or sawmill;
4. **mine timbers and bracing**;
5. **bridges, palisades and other heavy construction**.

Everything else is sawn wood and reads **"Wooden"**, or no tier word at all if there is no second material. **"Timber" is dropped** as a tier word (no Log/Timber split) unless Dave wants it back.

## 2. Log uses: what exists, what is missing

| Use | Exists today | Missing |
|---|---|---|
| Firewood and blocks | Log, Firewood, Wooden block (and Large, Softwood variants), Chopping block | nothing |
| Sawing | Log into planks by hand-split, Iron/Bronze - Saw, Sawmill | nothing |
| Cabin pieces | Log - Foundation, Wall, Doorway, Window, Ceiling, Roof, Roof corner, Stairs, Pillar | nothing |
| Defence | Log - Palisade, Log - Palisade gate, Log - Fence, Log - Gate | nothing |
| **Bridge** | none | **Log - Bridge** (heavy construction; needs Steve's span snap) |
| **Mine bracing** | none | **Mine brace** (timber props for a shaft; needs a mining or cave-in rule from Steve and Sonny) |
| **Raft and pier** | Log - Raft planned (future), Wooden - Pier only in the master list | Log - Raft stays; Pier is a bridge-scale piece, so Log - Pier |

## 3. Current Log items that fail the test

| Item | Today | Fix |
|---|---|---|
| Log - Bench (2 log, 1 twine) | furniture | **Drop**; Wooden - Bench (3 planks) exists |
| Log - Table (3 log, 2 twine) | furniture | **Drop**; Wooden - Table exists |
| Log - Trough (2 log, 1 twine) | animal trough | **Drop**; Wooden - Trough exists |
| Log - Workbench (4 log, 6 stick; level 2) | station | **Rename to Carpenter's bench** (plain name, sawn planks, level 2); see section 5 |
| Log - Seat (1 log) | a sit-down | **Plain "Seat"** (a cut log round); it is a stump, not furniture |
| Log - Fence (3 log, 1 twine) | fence | pass: rail fences of whole logs are heavy construction; keep |
| Log - Pillar (1 log) | cabin pillar | pass |

Pass: Foundation, Wall, Doorway, Window, Ceiling, Roof, Roof corner, Stairs, Palisade, Palisade gate, Gate.
**Stairs:** Dave's ladder example. A log cabin has log-stair pieces (stairs and a loft), but a freestanding ladder is not a log item. Our Log - Stairs is a cabin piece and passes; if Dave wants, add a plain **Wooden - Ladder** (planks) as a separate light item.

## 4. Everything else is Wooden

Wooden is the sawn-wood family for furniture, fittings and tools; no Log or Timber twin. Where a second material exists the word stays (Wooden/Stone/Iron - Bench). Where it does not, the tier word goes by the existing rule: Chest, Barrel, Beam, Post, Railing, Shelf, Cupboard, Cold frame, Compost bin, Planter box, Trellis, Sluice, Torch post, Double doorway. **Chair, Table, Bench** keep the word because Stone and Iron versions exist. The stick-and-block tools (Spade, Hoe, Bow, Spear, Club, Hammer, Arrow, Snowshoes) keep "Wooden" because Stone, Bronze and Iron versions exist (Snowshoes and Club: no second material, so plain). Building tiers become **Thatch, Log (house), Wooden (planks), Stone, Brick**: Wooden - Foundation and Wall stay as the plank house, Log - Foundation and Wall as the cabin.

## 5. One open question for Dave

The workbench ladder is Wooden (sticks, level 1), Log (level 2), Stone (level 3). With logs kept for cabins the middle body is not a log item. I recommend **Wooden - Workbench** (level 1, hand-built), **Carpenter's bench** (level 2, sawn planks, plain name) and **Stone - Workbench** (level 3), with Vice and Tool rack still the add-ons. Nothing is changed.

---

## Addendum: the wood chain itself (no items; discussion only)

Source: Jamie's export (recipes) and EARLY_GAME_FLOW.md. **Not in the export:** how many logs, sticks and bark a felled tree drops by size, so that number is left as "per tree table" below.

### What we have today

| Step | Today | Yield / time |
|---|---|---|
| Tree | Under 8 ft: firewood and sticks by hand. Larger: Hand axe (slow) or Stone axe | drops Log, Stick, Bark by tree size (table not in export) |
| Log (5 stack) | "A heavy length of trunk" | not craftable; from felling |
| Log to Large wooden block | felled round pieces (also gathered) | Large block (5 stack) |
| Large block to Small blocks | Stone axe | 1 Large to **4** Small blocks (4 s) |
| Large block to firewood or Chopping block | Chopping block: 1 Large block (8 s) | firewood (40 stack); **no yield shown in the export** |
| Log to Plank, by hand | Iron - Saw kept (needs Iron - Saw, saw blade) | 1 Log to **2** Plank (24 s) |
| Log to Plank, by wedge | Stone - Wedge kept, at the workbench | 1 Log to **2** Plank (14 s) |
| Log to Plank, at the Sawmill | Sawmill (40 Plank, 100 nails, saw blade, water wheel) | 1 Log to **4** Plank (6 s) |
| Stick | "A fallen branch", picked up in the world (40 stack) | free, from trees and ground |
| Bark | stripped from a felled trunk (40 stack); twine and tannin | per tree table |
| Firewood to Charcoal | campfire: 2 Firewood to 1 Charcoal (30 s); Kiln: 2 Firewood to 2 Charcoal | no coal within 4 km of spawn, so charcoal is the forge fuel |
| Pine pitch to Tar | 5 Pine pitch to 1 Tar (12 s) | pitch is a pine drop |
| Softwood and Fine wood | gathered, quality planks and furniture | Fine wood marked for quality planks |

So today **Log to Plank has three routes (hand-sawn 2, wedge 2, sawmill 4)**, and every sawn item is 3 to 40 planks. There is no step between Plank and finished item except small parts (Wooden pin, 20 per Plank). Beam is a finished building piece (4 Plank, 1 Twine, 1 Stick), not a material.

### What it should be (proposal)

1. **Tree** (axe) gives **Log** (the felled trunk), **Stick** (branches, free) and **Bark** (strip it).
2. **Log** goes one of three ways:
   - **Block or firewood**: axe on a Chopping block, 1 Log to 4 Firewood. This stays the cheapest, no tool beyond the axe.
   - **Plank by hand**: a **saw bench** (a hand rip saw at the Wooden workbench, or the Wedge), **1 Log to 2 Plank, slow** (about 24 s).
   - **Plank at the Sawmill**: **1 Log to 4 Plank, fast** (about 6 s). The sawmill is the later upgrade; hand planks must stay slow enough that the sawmill is worth building.
3. **Plank** is the only sawn material. Everything built of "Wooden" uses Plank, Stick and Twine; Wooden pin comes from a Plank.
4. **Beam**: keep as a finished piece, not a material; heavy cabin work uses whole **Log** directly (Log - Wall and so on), so there is no Beam step in the chain.
5. **Stick**: stays a free pickup (and the main hand-tool and fence material); no stick from planks.
6. **Charcoal and Pine tar**: unchanged (Firewood to Charcoal at the fire; Pine pitch to Tar). Dave asked only about the main line, so these are noted, not redesigned.

One change this makes: the **Wedge route** and the **hand-saw route** both do the same job at the same yield today, so we keep one hand route (the Wedge, cheapest tool, 2 Plank) and let the Iron - Saw make the same 2 Plank faster, unless Dave prefers it to give more. Nothing is changed.

---

## Correction (Dave, 10 Nov): the foundation is the floor

Nothing in this note questions the plank foundation. In this game the foundation is also the floor, so **Wooden - Foundation** (planks laid across a frame) is a normal wooden floor and **stays as it is**; **Log - Foundation** is the rough, cheaper version (round logs and stone footings). Both keep their place in the building ladder. The existing rule also stays: **no separate "floor" pieces**; the foundation and the ceiling of the storey below are the floors. Any earlier line here that read as moving or demoting Wooden - Foundation is withdrawn. Discussion only; nothing is changed.

---

## Dave's rulings, 10 Nov (recorded; no code or data changes)

1. **Tier 1 is "Crude".** It replaces "Thatch" as the tier word. Made from whatever you can scrounge in the wilderness (sticks, grass, reed, stones). Locked in as the first tier.
2. **Tier 2 is the log-frame tier, tools in hand.** You can fell trees and have logs. The foundation is a **2 m x 2 m x 2 m log foundation**: four legs, criss-cross log bracing, a deck of logs across the top, the look of a cabin raised in the woods or jungle. Costs **logs only**; splitting some logs and using pins is implied and not costed. Dave leans to calling this tier **"Wooden"**.
3. **Tier 3 is sawn planks**, once there is a saw or sawmill. A neat, closed-in foundation block of proper boards and timber. **Name not picked yet.**
4. Then **Stone**, then **Brick**.

Resulting ladder: **Crude, Wooden (logs), [tier 3 word], Stone, Brick.**

## Word for tier 3 (his question)

| Word | For | Against |
|---|---|---|
| **Timber** | the real word for sawn structural wood ("timber frame"); reads higher than Wooden; one short word | "Timber" can also mean standing trees; we dropped it earlier only because Log/Timber was a split inside one tier |
| **Plank** | exactly what it is made of (Plank is already the item name) | reads like an item, "Plank - Wall" sounds thin |
| **Board** | short, plain | "Board - Foundation" sounds odd |
| **Framed** | says what it is, a framed and boarded foundation | does not read as a material tier like the rest |
| **Carpenter's** (or Joined) | tidy and skilled | long; fits as a bench name, less as a tier |

**My pick: Timber.** It is short, it already means "properly sawn, framed wood", it matches the Carpenter's bench rename, and it sorts cleanly above Wooden (logs). Runner-up: Plank.

## What a pick changes (when he decides; not done now)

- Today's rows named **Log -** (Foundation, Wall, Doorway, Window, Ceiling, Roof, Roof corner, Stairs, Pillar, Fence, Gate) would display as **Wooden -** (tier 2), since Dave wants the log-frame tier called Wooden.
- Today's **Wooden -** building rows (lumber) would display as **Timber -**.
- **Thatch -** rows would display as **Crude -**.
- Tools and weapons keep "Wooden" (stick and block); wood-only items drop the word, as before.
- Ids never change; only names, the ladder text in item_system.md, buildables_plan.md and progression.md, and the Log - Foundation look (Kathleen: 2 m cube with legs and bracing).

Waiting for Dave's tier 3 pick before anything else. Nothing is changed.

---

## FINAL LADDER (Dave's picks, 10 Nov 11:58; not applied anywhere yet)

**Crude, Rustic, Refined, Stone, Brick** (metal pieces keep Iron and Steel).

| Tier | Word | Made of | Gate |
|---|---|---|---|
| 1 | **Crude** | whatever you scrounge: sticks, grass, reed, thatch, stones | by hand |
| 2 | **Rustic** | logs, felled with an axe; log-frame look | axe and hammer |
| 3 | **Refined** | sawn planks and timber | saw or sawmill |
| 4 | **Stone** | stone block (or cobblestone) with clay mortar, as today | stone tools |
| 5 | **Brick** | fired brick with mortar, as today | kiln |

No wood-and-stone tier. Half-timber (planks and plaster) is at most a **Refined wall variant** later; adobe is not a tier.

## Rename map (display names only; ids never change)

| Today | New |
|---|---|
| Thatch - Foundation, Wall, Doorway, Window, Roof, Roof corner, Pillar, Fence, Gate, Garden plot, Scarecrow | **Crude -** the same piece (Thatch - Bed and Scarecrow: plain names if only one material, see below) |
| Log - Foundation, Wall, Doorway, Window, Ceiling, Roof, Roof corner, Stairs, Pillar, Fence, Gate | **Rustic -** the same piece |
| Wooden - Foundation, Wall, Doorway, Window, Ceiling, Roof, Roof corner, Stairs, Pillar, Fence, Gate, Garden plot, Trough, Channel, Chair, Table, Bench | **Refined -** the same piece |
| Stone -, Brick -, Iron -, Steel - rows | unchanged |

**Rustic - Foundation** is Dave's 2 m x 2 m x 2 m log frame: four legs, criss-cross log bracing, logs across the top, costing logs only (pins and splitting implied, not costed). Needs a new look from Kathleen. **Refined - Foundation** keeps today's plank-on-frame floor.

## Small items (from the earlier addenda, restated on the new words)

- **Dropped:** Log - Bench, Log - Table, Log - Trough (the Refined versions exist).
- **Log - Seat** becomes a plain **Seat** (one log round).
- **Log - Workbench** is dropped as a log item. Workbench bodies become **Crude - Workbench** (sticks, level 1), **Refined - Workbench** (sawn planks, level 2) and **Stone - Workbench** (level 3), with Vice and Tool rack as the add-ons. This keeps the three levels; Dave to confirm, or keep the plain name "Carpenter's bench" for level 2.
- **Log - Palisade and Palisade gate** become plain **Palisade** and **Palisade gate** (one material, heavy construction).
- **Wood-only items lose the tier word:** Chest, Barrel, Beam, Post, Railing, Shelf, Cupboard, Cold frame, Compost bin, Planter box, Trellis, Sluice, Torch post, Double doorway, Hand pump stays "Wooden - Hand pump" (an Iron one exists).
- **Tools and weapons keep "Wooden"** (Spade, Hoe, Bow, Spear, Hammer, Arrow, Longbow); the tool ladder is Wooden, Stone, Bronze, Iron, Steel. Only buildings use Crude, Rustic, Refined.
- **Heavy-construction gaps** (do not exist yet): Rustic - Bridge and Mine brace; both need Steve rules.
- **Wood chain** section above stands as written.

## Files that would change when Dave says go

item_system.md (ladders, section 1 naming rule, section 6), buildables_plan.md (every tier word in B1 to B6), progression.md (ladder table, gates), and Jamie's rename list in item_changes_for_jamie.md. Code or data: none until Dave says go.

---

## UPDATE 10 Nov 12:02: Dave's final ladder, all quality words

Dave: stone and brick are material words, so the building tiers get quality words too. **Crude, Rustic, Refined, Sturdy, Superior.**

| Tier | Word | Made of | Replaces |
|---|---|---|---|
| 1 | **Crude** | scrounged: sticks, grass, reed, thatch | Thatch |
| 2 | **Rustic** | logs | Log |
| 3 | **Refined** | sawn planks and timber | Wooden (buildings) |
| 4 | **Sturdy** | cut stone and clay mortar | Stone (buildings) |
| 5 | **Superior** | fired brick and mortar | Brick (buildings) |

Metal building pieces keep **Iron** and **Steel**. Dave picked "Sturdy"; "Grand" was dropped; he chose "Superior" for brick.

### Rows the Stone and Brick change touches (from Jamie's export, live blueprints)

**Stone building rows to Sturdy (27 minus the two stations below = 25):**
Fence, Gate, Foundation, Bench, Table, Garden plot, Planter, Torch pillar, Lamp post, Brazier, Ceiling, Roof, Roof corner, Pillar, Stairs, Wall, Doorway, Window, Well, Trough, Channel, Channel corner, Channel tee, Cistern, Raised cistern.

**Brick building rows to Superior (12):** Fence, Gate, Foundation, Garden plot, Ceiling, Roof, Roof corner, Pillar, Stairs, Wall, Doorway, Window.

**Stations that carry the word, a call for Dave (3 rows):** Stone - Forge, Brick - Forge, Stone - Workbench. They are buildings, so my recommendation is to follow the ladder: **Sturdy - Forge**, **Superior - Forge**, **Sturdy - Workbench**, keeping their levels (forge 1 and 2, workbench 3). The workbench line is then Crude (1), Refined (2), Sturdy (3).

**Not touched (tool and weapon ladder stays by material):** Stone - Axe, Knife, Hammer, Pickaxe, Spade, Hoe, Sickle, Spear, Mace, Arrow, Wedge. Items other than buildings keep Wooden, Stone, Bronze, Iron, Steel.

**Single-material rule check (a call for Dave):** Well, Cistern, Raised cistern, Torch pillar, Planter, Brazier and the Channel set exist only in stone today. By the plain-name rule they would lose the word ("Well", "Cistern", "Brazier"). The ones with a second material (Lamp post, Trough, Channel in wood) keep it as "Sturdy - Lamp post" and so on. Recommend dropping the word on the single-material rows so players do not meet "Sturdy - Well".

### Updated rename map

Thatch to Crude, Log to Rustic, Wooden (buildings) to Refined, Stone (buildings) to Sturdy, Brick (buildings) to Superior. Ids never change. Files that would change when Dave says go: item_system.md, buildables_plan.md, progression.md, item_changes_for_jamie.md. Nothing is changed in code or data.

---

## COORDINATOR CALLS, 10 Nov 12:04 (recorded; Dave can overrule). These narrow the update above.

1. **The quality ladder applies to building pieces only:** Foundation, Wall, Doorway, Window, Ceiling, Roof, Roof corner, Stairs, Pillar, Fence, Gate and Palisade. Everything else (stations, furniture, containers, tools) keeps **material words**.
2. **Stations keep their material names:** Stone - Forge, Brick - Forge and Stone - Workbench stay as they are. The workbench ladder stays by material: **Wooden - Workbench** (level 1), **Carpenter's bench** (level 2, plain name, replaces Log - Workbench), **Stone - Workbench** (level 3). This replaces my Crude/Refined/Sturdy workbench and Sturdy/Superior forge proposals in the updates above; those are withdrawn.
3. **Stone-only items drop the tier word** (single-material rule): Well, Cistern, Raised cistern, Torch pillar, Brazier, Planter.

### Rows this leaves on the quality ladder

| Tier | Building pieces | Count |
|---|---|---|
| Crude (was Thatch) | Foundation, Wall, Doorway, Window, Roof, Roof corner, Pillar, Fence, Gate | 9 |
| Rustic (was Log) | Foundation, Wall, Doorway, Window, Ceiling, Roof, Roof corner, Stairs, Pillar, Fence, Gate; Palisade and Palisade gate become plain | 11 |
| Refined (was Wooden) | Foundation, Wall, Doorway, Window, Ceiling, Roof, Roof corner, Stairs, Pillar, Fence, Gate | 11 |
| Sturdy (was Stone) | the same 11 | 11 |
| Superior (was Brick) | the same 11 | 11 |
| Iron, Steel | Doorway, Fence, Gate, Railing (metal pieces keep the metal word) | unchanged |

### Rows that keep material words

- **Furniture and fittings:** Bench, Table, Chair, Trough, Channel (and corner, tee), Lamp post, Hanging lantern, Garden plot, Planter box, Scarecrow, Bed: Wooden -, Stone -, Brick -, Thatch -, Iron - as today.
- **Stations:** Stone - Forge, Brick - Forge, Wooden - Workbench, Stone - Workbench, Carpenter's bench.
- **Tools and weapons:** Wooden, Stone, Bronze, Iron, Steel.
- **Wood-only items** keep no tier word; Stone-only items drop it (call 3).

The earlier "Sturdy 25, Superior 12" counts above are replaced by 11 and 11. Rustic - Bridge and Mine brace stay open. Nothing is changed in code or data until Dave says go.

---

## FUTURE sixth tier: Fortified (Dave's question, 10 Nov 12:05; not built now)

Dave asked where a fortified wall (iron-banded masonry) would fit. Answer: a **sixth, defensive tier above Superior, named Fortified**, parked until raids or sieges exist.

| | |
|---|---|
| Ladder | Crude, Rustic, Refined, Sturdy, Superior, **Fortified** |
| Made of | cut stone block with lime mortar or lime concrete, tied and banded with **iron**; costs stone block, mortar or lime, iron bands (ingots and nails) |
| Gate | after the iron gate (needs a Brick - Forge and iron); lime for concrete means a lime kiln later |
| Pieces | Foundation, Wall, Doorway, Gate, Pillar, wall top or battlement; **no roof, ceiling or stairs** (it is a defensive shell, not a house) |
| Why a tier, not a variant | it is a clear step up (higher hit points against raids and siege) and the pieces differ; Dave's "half-timber" idea stays a Refined wall variant, adobe is not a tier |
| Not now | no code, data or looks; waits for raids and siege to exist, and for Steve's hit-point rules |

Adjacent rule: metal pieces (Iron - Doorway, Iron - Gate) stay by metal word; Fortified is the masonry-plus-iron wall, so a Fortified - Doorway would be the heavy iron-banded door in a masonry frame and replaces nothing today. Nothing is changed.

### Fortified: inputs (Dave: raw iron or banding?) — recorded 10 Nov 12:06, future only

**Make the banding first**, like nails and hinges. Raw ingots are never a building cost for Fortified pieces.
- **Iron band** (new forge product, future): 1 Iron ingot makes 2 Iron bands at the Brick - Forge with an Anvil within 5 m (level 3).
- **Lime mortar** (new material, future): burnt limestone at the Kiln, then slaked; the "concrete". **Clay mortar** stays for Sturdy; **lime mortar** is for Fortified.
- **Fortified piece cost:** stone block + lime mortar + Iron bands (numbers set later with Steve's hit-point rules).
- Needs limestone in the world (Sonny to confirm it exists near spawn); no code, data or looks now. Nothing is changed.

### Fortified: lime mortar dropped, Concrete instead (Dave, 10 Nov 12:08; supersedes the two lines above)

- **No Lime mortar.** Lime is only ever the binder in concrete, so we end up with concrete.
- **Concrete** (the single new Fortified material, future): burnt limestone from the Kiln plus sand or gravel, mixed with water at a trough.
- **Fortified piece cost:** Concrete + Iron bands. **No stone block.**
- **Clay mortar stays the only mortar** (Sturdy and Superior).
- Still future only; limestone near spawn still to confirm (Sonny). Nothing is changed.

### Fortified: Concrete recipe corrected (Dave, 10 Nov 12:09; supersedes the "sand or gravel at a trough" line)

- **Concrete = Lime + Sand + Stone**, all three, combined at a **Mixer** (new station, future: a mortar trough or hand-cranked drum; part of the Fortified gate).
- **Lime** (new material, future): burnt limestone from the Kiln. Sand and Stone are raw materials (sand from beaches and riverbeds, as the world allows).
- Fortified piece cost still Concrete + Iron bands, no stone block; clay mortar stays the only mortar.
- Still future only; limestone and sand sources near spawn to confirm (Sonny). No numbers yet. Nothing is changed.

### Fortified: Lime powder (Dave, 10 Nov 12:10; naming and chain, future only)

- **Limestone** (mined) goes in the **Kiln** and comes out as **Lime powder** (the item name; replaces "Lime").
- **Concrete = Lime powder + Sand + Stone**, combined at the **Mixer**.
- Fortified piece cost: Concrete + Iron bands. Clay mortar stays the only mortar.
- Limestone and sand sources near spawn still to confirm (Sonny). No numbers, no data. Nothing is changed.

---

## SEVEN-TIER LADDER (Dave, 10 Nov 12:14; both top tiers future, no numbers)

**Crude, Rustic, Refined, Sturdy, Superior, Engineered, Fortified.**

| Tier | Word | Made of | State |
|---|---|---|---|
| 1 | Crude | scrounged: sticks, grass, reed, thatch | to rename from Thatch |
| 2 | Rustic | logs | to rename from Log |
| 3 | Refined | sawn planks and timber | to rename from Wooden |
| 4 | Sturdy | cut stone with clay mortar | to rename from Stone |
| 5 | Superior | fired brick with clay mortar | to rename from Brick |
| 6 | **Engineered** | **plain Concrete**, no iron | future |
| 7 | **Fortified** | **Concrete + Iron bands** | future |

- **Concrete** (Lime powder + Sand + Stone at the Mixer) is the Engineered material; Fortified adds Iron bands (1 ingot makes 2 at the anvil) on top.
- **Engineered pieces:** Foundation, Wall, Doorway, Pillar, Roof (a flat concrete slab), Ceiling, Stairs, Window; a civil and building tier, unlike Fortified. **Fortified pieces:** Foundation, Wall, Doorway, Gate, Pillar, wall top or battlement; defensive only, no roof or stairs. (My proposal; Dave to confirm.)
- **One look:** Engineered and Fortified may share one model, with iron bands added for Fortified (Kathleen).
- **Gates:** Engineered needs limestone, a Kiln, a Mixer and sand; Fortified also needs the Brick - Forge with an Anvil for bands.
- Future only; Steve's hit-point rules come later. Nothing is changed in code or data.
---

## ROOF AND WALL TABLE: Tier table: wall, ceiling and roof materials (LOCKED by Dave's go 10 Nov; roof ruling is the coordinator's, Dave may overrule)

Roof and wall are different materials: a roof sheds water and needs light, weatherproof cover on a frame; concrete is not a roof.

| Tier | Foundation (and floor) | Wall | Ceiling | Roof (cover over rafters) |
|---|---|---|---|---|
| 1 Crude | sticks and thatch bundles | thatch on stick frame | none (one storey) | **thatch** on stick frame |
| 2 Rustic | log frame, 2 m cube, logs across the top | stacked logs | log poles | **bark shingle** over log rafters |
| 3 Refined | planks on a frame, closed in | planks | **plank joists** and boards | **wooden shakes** (split shingles) over plank rafters |
| 4 Sturdy | cut stone with clay mortar | cut stone, clay mortar | plank joists | **slate or stone slab** (Stone shingle) over plank rafters |
| 5 Superior | fired brick, clay mortar | brick, clay mortar | plank joists | **fired clay roof tile** over plank rafters |
| 6 Engineered (future) | plain Concrete | Concrete | **concrete slab** | **clay roof tile** over plank rafters (no concrete roof) |
| 7 Fortified (future) | Concrete + Iron bands | Concrete + Iron bands | none | none (defensive: wall, doorway, gate, pillar, battlement) |

New or changed items this needs: **Bark shingle** (stripped Bark, by hand), **Wooden shingle** (shakes; 1 Plank splits into several, at the workbench), **Clay roof tile** (Clay, at the Kiln; unparks the old "roof tiles" row), existing **Stone shingle** stays for Sturdy. Costs are first pass and live blueprints keep working until Jamie reprices them.

## Concrete chain and the rows it adds (future; no numbers until Steve and Sonny)

- **Limestone** (mined; Sonny confirms the source near spawn) -> **Kiln** -> **Lime powder**.
- **Concrete** = Lime powder + Sand + Stone at the **Mixer** (new station: a mortar trough or hand-cranked drum). Sand exists today (digging).
- **Iron band** = 1 Iron ingot makes 2 at the Brick - Forge with an Anvil within 5 m (level 3). Engineered needs Concrete; Fortified needs Concrete and Iron bands.
- Engineered pieces: Foundation, Wall, Doorway, Window, Pillar, Stairs, Ceiling (slab), Roof (clay tile over planks). Fortified pieces: Foundation, Wall, Doorway, Gate, Pillar, Wall top (battlement).
