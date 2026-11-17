# Ore veins and mines (midgame mining)

**Status: PROPOSAL for Dave, 17 Nov 2026. Design only: nothing here is built or approved. The four choices in section 9 are his; the values in "For Dave" are provisional and change on his word.**

## 1. What Dave asked for
> there should be ore veins which are midgame mining operations and there should be surface stones which are for early game

(Dave, 17 Nov 2026, project thread "Rework copper rocks and placement".)

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
A vein is the part of an existing ore body that is rich enough to follow. Surface stones stay the early game: small, finite pockets of ore on the ground that a Stone Hammer or bare hands can take. Once a player has smelted enough copper for a **Copper pickaxe**, they can open a mine: find a body from its signs at the surface, dig down or in with the pick, follow the ore they see in the tunnel wall, brace the workings with Posts and Beams, and haul the ore out. One vein holds far more ore than all the surface stones near it, but it costs a pick, timber, light, hauling and time, which is what makes it the midgame step. Everything comes from the geology the world already has; no second ore system is added.

## 4. What a vein is in the world
- **Inside a body, ore comes in veins.** Today a body's voxels are solid ore right through (a copper shell is hundreds of metres of ore). Proposal: the generator fills only the vein parts of a body. Each body gets a few seeded vein sheets: 1-3 m thick (the voxels are 1 m, so nothing thinner draws), dipping, spaced 8-30 m apart, running through the body and pinching and swelling along their length; between them only an occasional hashed ore voxel (a trace, as gem scatters are drawn today). One cheap seeded 3D pattern per body, worked out while a block is generated, as the ore fill is today. The look, the inspection label and the yield all read the same voxels, so what the player sees in the wall is what the pick gives.
- **Kinds by geology** (realistic and from the existing bodies):

| Ore | Where it already sits | As a mine |
|---|---|---|
| Copper | Shells around granite stocks; skarn lenses | Veins and stringers through the shell; rich skarn pods |
| Tin | Shell on the roof of granite plutons | Narrow quartz-cassiterite veins in hard granite (slow digging) |
| Iron | Skarn lenses beside limestone; bog iron | Massive pods (rich, short); bog iron stays a shovel job |
| Coal | Layer bands in sedimentary provinces | Seams: follow the band sideways, no vein pattern (the seam is the vein) |
| Salt | Evaporite layers, salt domes | Rock salt in the layer or the dome top |
| Gold, silver, lead, zinc, gems | Fault veins, lenses, pipes | Bodies exist, no items in the catalog: future (catalog frozen) |

- **The depth question.** Proposal: a compact body gives surface outcrop boulders only where its top at that spot comes within 10 m of the bedrock surface, the same test pipes and coal seams use now (`layer_depth_m`). Bodies deeper than that give no boulders and become vein targets, found by their signs. River copper and tin (`COPPER_ROCKS.md`) are unchanged: they come from placers along the river, which sit at the ground. The strewn land copper (CR-2) is not tied to bodies and stays.
- **How deep a player can reach.** No depth limit is set. In practice a shaft of tens of metres is a big job by hand, so bodies within about 60 m (OV-12, a guide, not a rule) are the real midgame targets and deeper ones wait for later machinery (hoists, NPC crews). How many bodies lie within 60 m near spawn is not measured yet: `src/worldgen/tools/ore_world.gd` lists every body with its top and depth and would answer it on Dave's PC.

## 5. Finding one (prospecting)
No new tool. Signs, from strongest to faintest:
1. **Outcrops**: shallow bodies still show ore boulders and exposed nodes in bare rock (as now, minus the deep ones).
2. **Float in streams**: tin pebbles in a river point upstream to their source (true now: tin rocks lie only near tin placers). River copper rocks are strewn without regard to bodies (CR-2, CR-3), so they are not a pointer; geology copper placers are.
3. **Stained ground** over a body within about 30 m of the surface: rusty brown over iron, green-blue over copper, pale bleached patches over tin; a faint ground tint drawn by the client from a list of shallow bodies (provisional, needs a look pass, a protocol step and a re-bake; see section 8).
4. **Test pits**: a shovel or pick hole through the cover into rock shows what the rock is (the label already names ore in bare rock); a pick blow on ore rock gives a piece of ore.

Later (not in this plan): indicator plants, a surveying skill, an NPC prospector who sells rumours.

## 6. Mining one
- **Tools.** In rock the pickaxe digs: each blow bites a 0.9 m sphere out of the face (the shovel's size; it clears about 3 of the 1 m voxels) and pays only for voxels it actually cleared: each cleared ore voxel gives the pick's pieces, each of them ore by the grade of the body that holds it (looked up from the tile's ore list, as `ore_at` does), else stone; cleared plain rock gives stone. A bite that clears nothing new (an old hole) pays nothing, so ore is finite per voxel. Copper pick for copper, tin, coal and salt; Bronze or better for iron (the existing `needs_material` rule). Better picks are faster, not richer (`boulders.json` tools: copper 1.5, bronze 2, iron 3, steel 4). Hard host rock digs slower, by the existing rock hardness table (`geology` rock `hardness`: granite 0.95, basalt 0.85, limestone 0.7, shale 0.15). The shovel keeps soil, sand, gravel, clay and rubble; in solid rock it does nothing. Hammers keep surface rocks and do not tunnel.
- **Yield from what is dug.** The dig yield reads the voxel material and ore at the point struck, not the surface material above it (this also fixes underground shovel digs giving the soil of the field above).
- **Supports.** The existing cave-in rules decide: a 2 m drift in rock stands unsupported however deep; a 3 m drift under 20 m of rock, a wide room, or almost any tunnel in loose soil needs Posts or Beams. A cave-in fills the workings with rubble (ore taken stays taken and rubble can be dug out again: [Proposed], `DESIGN_IDEAS.md` 11.2).
- **Light.** Underground is dark; torches, lanterns and wall lanterns as they are.
- **Hauling.** Copper, tin and iron ore weigh 1.5 kg a piece, coal 0.5 kg. Stage 1: carry it, or use the Handcart where the tunnel is wide enough, and tip it into resource bins at the mine mouth. Stage 2 (new items, Dave's yes needed): a Mine cart on wooden rails for long drifts and a Hoist over a shaft (a windlass and bucket, like the well's) to lift ore and players.
- **"Mining operation"** means, in stages: (1) a player or a group digging a real mine with picks, supports, light and carts; (2) machinery that moves ore from the face to the surface; (3) later, a mine outpost (the Mining shed of the outpost design) where hired miners work it while nobody is there.

## 7. Surface versus vein (why surface is early, veins midgame)
| | Surface stones | Vein |
|---|---|---|
| Tool | Hands, Stone Hammer | Copper pickaxe or better (Bronze for iron) |
| Where | Strewn, river beds, mountain feet | Buried bodies, found by signs |
| Ore in one find | 1 (by hand) to about 2,800 (a 2 m copper boulder) | Far more: a body holds millions of tonnes, a vein in it thousands |
| Setup | None | Dig in, brace, light, haul |
| Rate | Fast at first, then gone near home | Steady: 1.5-4 pieces per ore voxel cleared, all day |
| Renews | Taken stays taken (CR rules) | Finite (deposits do not renew) |

The surface gives enough copper for the first tools and a Copper pickaxe; the vein is where bronze and iron in quantity come from.

## 8. Server cost and multiplayer
- **Nothing new to save.** Every pick bite is a dig in the existing dig log, so the ore taken is the rock removed: finite with no tonnage book-keeping, and every player sees the same tunnel. Collapse uses the existing tunnel watch on its worker thread.
- **Per blow:** one dig-log record and one `dug` message, as a shovel dig today, plus knowing which voxels the bite cleared. The server does not keep blocks in memory today (a read goes through `load_block`: settled cache or SQLite or generation, then replay), so stage 1 adds a small cache of the few blocks around each working miner, kept as the bites are applied, and a lookup of the body that holds each ore voxel (a few rectangle checks in the tile's ore list). NOT MEASURED: a miner swings every 700 ms, so stage 1 must be measured on Dave's PC before it lands.
- **Generation:** the vein pattern is a cheap seeded test per voxel run inside bodies, only in blocks that hold a body; most blocks pay nothing. It changes generated blocks, so it needs a terrain version step and a starter cache rebuild on Dave's PC (`tools/rebuild_starter_cache.sh`). Existing digs replay on top as usual; ore voxels under old holes are simply gone, and ore in unworked rock moves to the vein pattern. A world wipe is Dave's action only, if he wants one.
- **Depth-gated outcrops:** one height compare per body in `ore_at`; cheaper than now.
- **Stained ground:** the client needs to know where shallow bodies are: either a new tile section (a re-bake) or a short list sent at tile load (a protocol step). The client tints ground in a shader; no per-frame server work.
- **Limits.** No new limits. Existing ones that a large mine meets: the dig log holds at most 20,000 edits in one 16 m block in its lifetime (about 10,000 m3 of bites, more than the block holds) and 600 not yet settled; Posts and Beams are capped at 60 of each per 256 m chunk (a fresh Beam holds 7.5 m around it, so one every 14 m covers about 840 m of drift). Raising the support cap is listed in For Dave.
- **Cheating:** clients still never receive ore more than 2 m behind a surface, so x-ray clients learn nothing; the server decides every yield.

## 9. The choices that are Dave's
1. **What a vein is.** (A, recommended) Real veins inside the existing bodies that you see in the tunnel wall and follow with a pick, in real tunnels. (B) A mine entrance on a body that pays ore over time with no real tunnel (cheaper to build, less natural).
2. **Deep bodies and surface boulders.** (A, recommended) Only bodies within 10 m of the rock surface give outcrop boulders; deeper ones show only faint signs and are mine targets. (B) Keep surface boulders over every body as now.
3. **Who works a mine at midgame.** (A, recommended) Players first (stages 1-2), hired NPC miners later with outposts. (B) Hold mining until outposts and NPC miners can be built together.
4. **New items for stage 2.** Mine cart, Wooden rails, Hoist (shaft windlass and bucket). Yes to all, some, or none for now. Stage 1 needs no new items.

## 10. Build plan (each stage its own PR, reviewed and tested on Dave's PC)
1. **Pick digs rock; yield from what is dug.** Pick bites rock into the dig log, pays only for voxels it clears (ore by its body's grade, else stone), with a small block cache measured on Dave's PC, shovel limited to loose ground, iron needs bronze; underground shovel digs give what they dig. Check Posts and Beams can be placed on a tunnel floor. Depth-gated outcrops (choice 2). Tests: yields by voxel, tool tiers, ore taken stays gone, cave-in unchanged.
2. **Veins inside bodies.** Vein pattern in the generator (terrain version step, starter cache rebuild), grade from the vein; tunnel walls show ore; tool test on Dave's PC for the look.
3. **Prospecting signs.** Stained ground over shallow bodies; outcrop and float checks.
4. **Hauling machinery** (only if Dave says yes to the items): Mine cart and rails, Hoist.
5. **Later, separate design:** mine outposts and NPC miners (drawing down a body's tonnage as a number, `DESIGN_IDEAS.md` 11.4), deep-mine air and heat, gold, silver, lead and zinc once they have items.

## For Dave (provisional, assumed on his behalf)
| ID | Choice | Value | Why |
|---|---|---|---|
| OV-1 | Outcrop depth for compact bodies | top within 10 m of the rock surface | The same test coal seams and pipes already use. |
| OV-2 | Vein sheets in a body | 0.5-3 m thick, 8-30 m apart, dipping, pinch and swell | Real veins are narrow and come in sets. |
| OV-3 | Ore between veins | 1 voxel in 50 is ore (hashed) | Wall rock in an ore body carries a little. |
| OV-4 | Pick bite | 0.9 m radius sphere a blow (the shovel's), 700 ms a blow as now | About 3 m3 a bite, so 3-5 blows a metre of 2 m drift; tune the pace on play. |
| OV-5 | Pieces per cleared voxel | the pick's rate (copper 1.5, bronze 2, iron 3, steel 4), each ore by its body's grade, else stone | Same numbers as breaking boulders. |
| OV-6 | Hard rock slower | blow pace scaled by the existing rock hardness | Tin in granite is hard work, as in real tin mines; no new table. |
| OV-7 | Shovel in solid rock | does nothing ("Too hard for a shovel") | Pick for rock, shovel for loose ground. Changes today's behaviour. |
| OV-8 | Hammer | surface rocks only, no tunnelling | His tool ladder: hammer harvests rocks, pick mines. |
| OV-9 | Stained ground | bodies within 30 m of the surface | Deep enough to lead to a mine, rare enough to be a find. |
| OV-10 | Support cap | lift Posts and Beams from 60 a chunk to no cap | Dave's taste for no arbitrary limits (as in his 16 Nov ground-drop ruling); a large mine needs many. |
| OV-11 | Coal seams and salt | mined like veins, copper pick | They are already layers in the ground. |
| OV-12 | Practical mine depth | bodies within about 60 m are the midgame targets; no limit set | A guide for prospecting signs and testing. |

## Catalog
Catalog frozen: stage 1 to 3 add no items, stations or tools. Stage 4 needs his yes for: Mine cart, Wooden rails, Hoist. Mining shed (outpost) comes with the outpost design later.
