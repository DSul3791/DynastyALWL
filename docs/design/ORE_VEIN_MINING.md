# Ore veins and mines (midgame mining)

**Status: DESIGN, Dave's answers of 17 Nov 2026 folded in (section 9). Nothing is built. Building waits for Dave's go on stage 1. The values in "For Dave" are provisional and change on his word.**

## 1. What Dave asked for
> there should be ore veins which are midgame mining operations and there should be surface stones which are for early game

(Dave, 17 Nov 2026, project thread "Rework copper rocks and placement".)

His answers to this proposal (17 Nov 2026, project chat):
> veins are often indicated by a large deposit of stones on the surface where the vein comes out. theoretically. no prebuilt mines yet. ores should be often scattered along where the vein runs below. the bigger the vein the more ore on the surface and the closer to the surface the bigger the ores stones on the surface. players will dig our ore first. before we have npc miners. no we are not going to have mine carts and rails we will use hand carts to haul out the ores we gather. so will the npcs in the future.

Earlier rulings this builds on (status and source as recorded; none is treated as a ban):
- **Ore at the surface is a node you then follow into the ground along the vein, like 7 Days to Die** ([Decided], owner, 20 Oct 2026, `DESIGN_IDEAS.md` near line 61). Ore under soil stays hidden: the label names the soil, not the ore under it ([Decided], same date, line 60).
- **Mines need support**: the bigger a man-made opening, the more it needs timbers or pillars; supports wear and need upkeep; a cave-in refills the workings with rubble, the land above does not sink ([Decided], `DESIGN_IDEAS.md` section 11.2).
- **Ore deposits are finite and do not renew**; some river and surface deposits renew slowly ([Decided], `DESIGN_IDEAS.md` section 11.4).
- **A mine is one of the basic outposts** (logging camp, quarry, mine): a quarry is an open pit, a mine is drilled with a shaft; hired NPCs work it ([Decided, source unverified], `Design_Ideas_Unapproved.md` "Outposts and town satellites"). Not built.
- **Tool ladder** (`docs/design/DYNASTY_MASTER_ITEMS.md` s2.1; the catalog stays frozen until its whole approval, and the Copper pickaxe and its rate are provisional, A-13/A-14, W-12): Pickaxe is Copper, Bronze, Iron, Steel ("metal mining: faster than a hammer on rock; a Bronze or better pick mines Iron"); early stone, copper, tin and coal come from the Stone Hammer.
- The 21 Oct 2026 shovel design (`DIGGING_DESIGN.md`) left "deeper tool classes (pick for rock)" for later.
- An earlier plan ([Proposed], Claude, 20 Oct 2026, `DESIGN_IDEAS.md` line 64) had the vein be "the connected run of resource voxels", followed by digging. Section 4 keeps that idea but adds seeded vein sheets inside each body, because today a body's voxels are ore right through.

## 2. What the game has now (checked on dev 9cf595d6)
- **Surface half, built.** Copper and tin surface rocks (`docs/design/COPPER_ROCKS.md`, #1202, #1203): small ones picked up by hand, bigger ones broken with a hammer or pick; copper thin everywhere and dense by water, tin by rivers near tin geology. Geology outcrop boulders (`boulders.json` `ore`) for copper, tin, iron, coal, salt. Bog iron dug with a shovel. A rock once taken stays gone.
- **The ore bodies are already in the ground.** The geology (`tile_geology.gd`, rules in `worlds/base_world/plan/tile_rules.json` `geology`) makes seeded bodies from provinces about 4 km across: tin as a shell over granite plutons (30-80 m thick), copper as a shell around smaller stocks (150-400 m thick), iron/copper/zinc skarn lenses where an intrusion meets limestone (60-200 m), coal and salt as layers, gold/silver veins on faults, gems. Intrusions and fault veins are buried by a random -200 to 900 m (`geology.burial`; about 3 in 10 reach the surface, shallower under mountains); copper shells start 100 m above their stock's top; salt domes lie 80-600 m down, pipes 0-400 m; skarns and layers sit at their rock layer. Nothing is placed because of spawn.
- **The voxels already carry the ore.** The terrain generator fills each body into the ground's resource channel at its real depth (`terrain_generator.gd`), keeps it under a soil cap except at exposed nodes, and the server strips ore more than 2 m behind any surface from what it sends, so a modified client cannot see through rock (`server_block_store.gd hide_buried_ore`). The channel holds only which ore (an id), not how rich: a body's grade is on its record in the tile's ore list. Nothing reads the resource channel for yield yet.
- **The surface rock check ignores depth.** `TileTerrainData.ore_at` gives a boulder the ore of the nearest compact body (lens, halo, vein, placer) within reach however deep its top is; only pipes and layers check depth (10 m, `layer_depth_m`). So a copper shell 600 m down still puts copper boulders on the ground above it.
- **Digging exists.** The shovel digs a 0.9 m sphere anywhere, rock included, into the saved dig log (`digs.dat`, every player sees it, survives restarts and re-bakes). Its yield comes from the *surface* material at that x,z, not from what is dug, so a tunnel 20 m down gives soil if the field above is loam. The pick does not dig: on bare rock it gives one stone a blow (6 a patch, regrowing).
- **Cave-ins and supports exist** (`tunnel_watch.gd`, `tunnel_stability.gd`; collapse is on in the test world through `data/tunnels.json`, off by default in code): a roofed space whose span, grown by up to double for the cover above it (full at 20 m), is wider than the roof can hold (2 m in loose soil, sand and gravel, 6 m in any rock) rumbles and then falls as rubble; Post (`timber_prop`, 5 m reach) and Beam (`timber_set`, 7.5 m) hold the ground around them and wear out. Ladder, lanterns, torches, Handcart and resource bins exist.

## 3. Proposal in one paragraph
A vein is a seeded sheet of rich ore inside an existing ore body. Where a vein comes out at the surface it often leaves a large deposit of ore stones; along the line where it runs below, ore stones often lie scattered, more of them the bigger the vein and bigger stones the nearer it runs to the surface. Those surface stones are the early game: finite ore that a Stone Hammer or bare hands can take, and the sign that leads to the vein. Once a player has smelted enough copper for a **Copper pickaxe**, they can open a mine: find a body from its signs at the surface, dig down or in with the pick, follow the ore they see in the tunnel wall, brace the workings with Posts and Beams, and haul the ore out with a Handcart. No prebuilt mines yet: every mine is dug by players. One vein holds far more ore than all the surface stones near it, but it costs a pick, timber, light, hauling and time, which is what makes it the midgame step. Everything comes from the geology the world already has; no second ore system is added.

## 4. What a vein is in the world
- **Inside a body, ore comes in veins.** Today a body's voxels are solid ore right through (a copper shell is hundreds of metres of ore). The generator will fill only the vein parts of a body. Each body gets a seeded list of vein sheets (each a record: a trace line, a dip, a thickness, a length, a grade and how deep its top lies; the same list is worked out by the generator, the server and the surface placement from the body's seed, so nothing new is saved): 1-3 m thick (the voxels are 1 m, so nothing thinner draws), dipping, 2-6 main veins in a body, 8-30 m apart where they run together, each 50-400 m long, running through the body and pinching and swelling along their length; between them only an occasional hashed ore voxel (a trace, as gem scatters are drawn today). Because a body has only a few veins, the generator checks a column against that short list (a line-distance test each, as fault veins are drawn now) while a block is generated, as the ore fill is today.
- **Bodies that are not sheets.** Iron skarn lenses (and other lens or pipe bodies) are one vein-like pod each: they follow the same surface rule as a vein by how near their top comes to the ground. Coal and salt layers keep today's rule: a seam shows at the surface where one of its bands comes within 10 m of the rock (`layer_depth_m`), so early coal from the Stone Hammer stays (OV-14). The look, the inspection label and the yield all read the same voxels, so what the player sees in the wall is what the pick gives.
- **Kinds by geology** (realistic and from the existing bodies):

| Ore | Where it already sits | As a mine |
|---|---|---|
| Copper | Shells around granite stocks; skarn lenses | Veins and stringers through the shell; rich skarn pods |
| Tin | Shell on the roof of granite plutons | Narrow quartz-cassiterite veins in hard granite (slow digging) |
| Iron | Skarn lenses beside limestone; bog iron | Massive pods (rich, short); bog iron stays a shovel job |
| Coal | Layer bands in sedimentary provinces | Seams: follow the band sideways, no vein pattern (the seam is the vein) |
| Salt | Evaporite layers, salt domes | Rock salt in the layer or the dome top |
| Gold, silver, lead, zinc, gems | Fault veins, lenses, pipes | Bodies exist, no items in the catalog: future (catalog frozen) |

- **Surface ore follows the vein (Dave's rule).** The surface stones come from the veins, on a sliding scale, not an on/off depth:
  - *Where a vein comes out* (its sheet meets the ground): often a large deposit of ore stones along the outcrop, from hand-sized up to boulders.
  - *Along the line where it runs below* (its trace on the ground, out to where the sheet dips deep): ore stones often scattered over it, in stretches with gaps.
  - *Bigger vein, more ore at the surface*: the number of stones in a stretch follows the vein's thickness and grade.
  - *Nearer the surface, bigger stones*: stone size follows how deep the vein is under that spot, largest over the outcrop and shrinking to pebbles, then none, as it runs deeper (OV-1).
  - This replaces today's outcrop boulders over whole bodies (`boulders.json` `ore` `boulder_share`, which ignore depth), so a body 600 m down no longer puts ore on the ground; its veins do only where they come near. Smaller stones are picked by hand and bigger ones broken with a hammer, as `COPPER_ROCKS.md` already does.
- **How this fits the surface rocks already in dev** (`COPPER_ROCKS.md`):
  - River copper and tin stay as they are (ore worn out of veins upstream and carried down; tin already lies only near a tin body, in practice its river placers).
  - Copper "strewn about the lands a bit" (CR-2, Dave 16 Nov) and the copper on river beds and shores (CR-3) stay as they are; vein stones are added on top. Moving land copper onto veins only would narrow his 16 Nov ruling, so it is not proposed (OV-13). Mountain-foot copper boulders (CR-5) stay.
  - The rock looks, sizes, grades and the hand/hammer split are kept.
- **How deep a player can reach.** No depth limit is set. In practice a shaft of tens of metres is a big job by hand, so veins within about 60 m (OV-12, a guide, not a rule) are the real midgame targets and deeper ones wait for NPC crews. How many bodies lie within 60 m near spawn is not measured yet: `src/worldgen/tools/ore_world.gd` lists every body with its top and depth and would answer it on Dave's PC.

## 5. Finding one (prospecting)
No new tool. Signs, from strongest to faintest:
1. **The vein's own stones**: the large deposit where it comes out, then the trail of stones along it, getting smaller where it runs deeper (section 4). Follow the trail back to the big stones and dig there.
2. **Float in streams**: tin pebbles in a river point upstream to their source (true now: tin rocks lie only near a tin body, in practice its river placers). River copper rocks are strewn without regard to bodies (CR-2, CR-3), so they are not a pointer; geology copper placers are.
3. **Test pits**: a shovel or pick hole through the cover into rock shows what the rock is (the label already names ore in bare rock); a pick blow on ore rock gives a piece of ore.

Later (not in this plan): stained ground, indicator plants, a surveying skill, an NPC prospector who sells rumours.

## 6. Mining one
- **Tools.** In rock the pickaxe digs: each blow bites a 0.9 m sphere out of the face (the shovel's size; it clears about 3 of the 1 m voxels) and pays only for voxels it actually cleared: each cleared ore voxel gives the pick's pieces, each of them ore by the grade of the vein (or body, for a trace voxel) that holds it, looked up from the vein records, else stone; cleared plain rock gives stone. A bite that clears nothing new (an old hole) pays nothing, so ore is finite per voxel. Copper pick for copper, tin, coal and salt; Bronze or better for iron (the existing `needs_material` rule). Better picks are faster, not richer (`boulders.json` tools: copper 1.5, bronze 2, iron 3, steel 4). Hard host rock digs slower, by the existing rock hardness table (`tile_rules.json` top-level `rock.hardness`: granite 0.95, basalt 0.85, limestone 0.7, shale 0.15). The shovel keeps soil, sand, gravel, clay and rubble; in solid rock it does nothing. Hammers keep surface rocks and do not tunnel.
- **Yield from what is dug.** The dig yield reads the voxel material and ore at the point struck, not the surface material above it (this also fixes underground shovel digs giving the soil of the field above).
- **Supports.** The existing cave-in rules decide: a 2 m drift in rock stands unsupported however deep; a drift 4 m wide under 20 m of rock, a wide room, or almost any tunnel in loose soil needs Posts or Beams. A cave-in fills the workings with rubble (ore taken stays taken and rubble can be dug out again: [Proposed], `DESIGN_IDEAS.md` 11.2).
- **Light.** Underground is dark; torches, lanterns and wall lanterns as they are.
- **Hauling.** Copper, tin and iron ore weigh 1.5 kg a piece, coal 0.5 kg. Ore goes out by Handcart (Dave: no mine carts or rails; future NPC miners will use hand carts too), into resource bins at the mine mouth. Following from that (not Dave's words; OV-15): a mine is entered by a sloped tunnel a Handcart can be pulled up (an adit into a hillside, or a ramp down), and ladders serve as a way in on foot. Stage 3 checks the Handcart in tunnels against its data today (`structures.json` handcart: 1.2 x 2.0 m, carries 120 kg, about 80 ore pieces, slope up to 0.36 with load slowing it, 4 a 256 m chunk).
- **"Mining operation"** means: (1) now, a player or a group digging a real mine with picks, supports, light and Handcarts; (2) later, a mine outpost (the Mining shed of the outpost design) where hired NPC miners dig and haul with Handcarts while nobody is there. No prebuilt mines yet.

## 7. Surface versus vein (why surface is early, veins midgame)
| | Surface stones | Vein |
|---|---|---|
| Tool | Hands, Stone Hammer | Copper pickaxe or better (Bronze for iron) |
| Where | Along veins, river beds, mountain feet | Under its trail of surface stones |
| Ore in one find | 1 (by hand) to about 2,800 (a 2 m copper boulder) | Far more: a body holds millions of tonnes, a vein in it thousands |
| Setup | None | Dig in, brace, light, haul by Handcart |
| Rate | Fast at first, then gone near home | Steady: 1.5-4 pieces per ore voxel cleared (a bite clears about 3), all day |
| Renews | Taken stays taken (CR rules) | Finite (deposits do not renew) |

The surface gives enough copper for the first tools and a Copper pickaxe; the vein is where bronze and iron in quantity come from.

## 8. Server cost and multiplayer
- **Nothing new to save.** Every pick bite is a dig in the existing dig log, so the ore taken is the rock removed: finite with no tonnage book-keeping, and every player sees the same tunnel. Collapse uses the existing tunnel watch on its worker thread.
- **Per blow:** one dig-log record and one `dug` message, as a shovel dig today, plus knowing which voxels the bite cleared. The server does not keep blocks in memory today (a read goes through `load_block`: settled cache or SQLite or generation, then replay), so stage 2 adds a small cache of the few blocks around each working miner, kept as the bites are applied, and a lookup of the body that holds each ore voxel (a few rectangle checks in the tile's ore list). NOT MEASURED: a miner swings every 700 ms, so stage 2 must be measured on Dave's PC before it lands.
- **Generation:** a column inside a body is tested against its few veins (2-6 line-distance tests), only in blocks that hold a body; most blocks pay nothing. NOT MEASURED; the block generation time on Dave's PC is the check. It changes generated blocks, so it needs a terrain version step and a starter cache rebuild on Dave's PC (`tools/rebuild_starter_cache.sh`). Existing digs replay on top as usual; ore voxels under old holes are simply gone, and ore in unworked rock moves to the vein pattern. A world wipe is Dave's action only, if he wants one.
- **Surface stones from veins:** laid per 32 m cell like the copper and tin rocks now, from the cell's own seed: one look at the veins whose trace passes near the cell (a few line-distance checks), then the stones on it; nothing saved but taken rocks (as now). The vein list is made once per body when its tile loads. NOT MEASURED; the slow-cell log line covers it.
- **Limits.** No new limits. Existing ones that a large mine meets: the dig log holds at most 20,000 edits in one 16 m block in its lifetime (about 60,000 m3 of 0.9 m bites, more than the block holds) and 600 not yet settled; Posts and Beams are capped at 60 of each per 256 m chunk (a fresh Beam holds 7.5 m around it, so one every 14 m covers about 840 m of drift). Raising the support cap is listed in For Dave.
- **Cheating:** clients still never receive ore more than 2 m behind a surface, so x-ray clients learn nothing; the server decides every yield.

## 9. Dave's answers (17 Nov 2026)
1. **What a vein is:** real veins the player digs out (our reading of "players will dig our ore first"). No prebuilt mines yet.
2. **Surface ore:** follows the veins on a sliding scale (section 4), not the proposed 10 m cutoff.
3. **Who works a mine:** players dig ore first; NPC miners later.
4. **New items:** no mine carts and no rails; ore is hauled with Handcarts, by NPCs too later. The Hoist was not answered and is left out. No new items in this plan.

## 10. Build plan (each stage its own PR, reviewed and tested on Dave's PC; stage 1 waits for his go)
1. **Veins in the ground and on the surface.** Seeded vein records per body; the generator fills ore only in veins (terrain version step, starter cache rebuild on Dave's PC); surface stones laid along veins by size and depth (section 4), replacing the whole-body outcrop boulders (layers keep their rule, OV-14); the copper and tin rocks already in dev stay (OV-13). Picture on Dave's PC of a vein's outcrop and trail. Playable: walk a trail of stones to its big outcrop.
2. **Pick digs rock; yield from what is dug.** Pick bites rock into the dig log and pays only for voxels it clears (ore by its vein's grade, else stone), with a small block cache measured on Dave's PC; shovel limited to loose ground; iron needs bronze; underground shovel digs give what they dig. Check Posts and Beams can be placed on a tunnel floor.
3. **Working mines.** Handcart in tunnels and up ramps; support cap (OV-10); tunnel wall look shows the vein; whole loop played from surface stones to a braced mine.
4. **Later, separate design:** mine outposts and NPC miners with Handcarts (`DESIGN_IDEAS.md` 11.4), deep-mine air and heat, gold, silver, lead and zinc once they have items.

## For Dave (provisional, assumed on his behalf)
| ID | Choice | Value | Why |
|---|---|---|---|
| OV-1 | Surface stones by vein depth | a deposit at 7 in 10 outcrops; trail stones in about half of each 32 m stretch; over the outcrop: deposit of stones up to 1.3 m radius; stone size falls with the vein's depth under the spot, to pebbles at about 30 m and none past about 60 m; count per 32 m of trail follows thickness x grade | Dave's sliding scale; the depths are first guesses. |
| OV-2 | Vein sheets in a body | 2-6 main veins, 1-3 m thick, 50-400 m long, 8-30 m apart where together, dipping, pinch and swell | Real veins are narrow and come in sets; few enough to give a clear trail. |
| OV-3 | Ore between veins | 1 voxel in 50 is ore (hashed) | Wall rock in an ore body carries a little. |
| OV-4 | Pick bite | 0.9 m radius sphere a blow (the shovel's), 700 ms a blow as now | About 3 m3 a bite, so 3-5 blows a metre of 2 m drift; tune the pace on play. |
| OV-5 | Pieces per cleared voxel | the pick's rate (copper 1.5, bronze 2, iron 3, steel 4), each ore by its body's grade, else stone | Same numbers as breaking boulders. |
| OV-6 | Hard rock slower | blow pace scaled by the existing rock hardness | Tin in granite is hard work, as in real tin mines; no new table. |
| OV-7 | Shovel in solid rock | does nothing ("Too hard for a shovel") | Pick for rock, shovel for loose ground. Changes today's behaviour. |
| OV-8 | Hammer | surface rocks only, no tunnelling | His tool ladder: hammer harvests rocks, pick mines. |
| OV-9 | (retired: stained ground, moved to later) | | |
| OV-10 | Support cap | lift Posts and Beams from 60 a chunk to no cap | Dave's taste for no arbitrary limits (his 16 Nov 2026 ruling on ground drops, "there should be no limit", PR #1199); a large mine needs many. |
| OV-11 | Coal seams and salt | mined like veins, copper pick | They are already layers in the ground. |
| OV-12 | Practical mine depth | veins within about 60 m are the midgame targets; no limit set | A guide for testing. |
| OV-13 | Copper rocks already in dev | kept as they are (CR-2 strewn land, CR-3 rivers, CR-5 mountain feet, looks, sizes, grades); vein stones are added on top | His 16 Nov ruling ("strewn about the lands a bit and more abundant along river beds and shores") stands; he can ask to move land copper onto veins. |
| OV-14 | Coal, salt, iron surface stones | layers keep the 10 m band rule; lens and pipe bodies (iron skarn) use the vein surface rule | Early coal from the Stone Hammer stays; iron shows where its pod comes near. |
| OV-15 | Mine entrance | sloped adit or ramp a loaded Handcart can be pulled up; ladders for walking in | Follows from Handcarts only and no Hoist. |

## Catalog
No new items, stations or tools (Dave: no mine carts or rails; the Hoist is left out). Mining shed (outpost) comes with the outpost design later.
