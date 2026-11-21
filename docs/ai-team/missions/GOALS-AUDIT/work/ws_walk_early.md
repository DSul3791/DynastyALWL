# GOALS-AUDIT workstream: new-player walkthrough, early game (MAIN 1-45 and side levels 1-5)

- Scope: `docs/design/PLAYER_GOALS_REWARDS_DRAFT.md` MAIN rows 1-45 (draft lines 28-72, `work/goals_parsed.json` route MAIN in order) and the section 2 side goals at dependency levels 1-5 (draft lines 155-340, 166 rows).
- Code and data read: baseline `dc2fa52374d49ce05ef1f31a300999d1da872d9d`. The branch head when this was written was `69d361b` (`claude/project-thread-d8jals`). `git diff --stat dc2fa52 HEAD` touches only `docs/ai-team/missions/GOALS-AUDIT/`, so every `src/` and `data/` citation below is identical at both SHAs.
- Evidence class: CODE_VERIFIED, meaning I read the code and data. Nothing here is GAMEPLAY_VERIFIED. I ran no Godot and no tests. Where a test exists I cite it. `work/david4_evidence_dc2fa52.md` is the coordinator's relay of a David4 PC run at dc2fa52 (20/20 pass), and only those relayed results count as AUTOMATED_TESTED here. I did not run them.
- Sibling workstreams: `work/ws_acquisition.json` and `work/ws_runtime.json` did not exist when I wrote this. Raw-material sources are therefore "per acquisition workstream" and goal events and completion are "per runtime workstream".
- Authority: the draft is PROPOSAL. Code and data are IMPLEMENTED. Door costs and frame costs are CREATOR (`docs/ai-team/missions/BUGLIST-002/CONTRACT.md:7-8,65`, Dave 13 Nov 2026). Catalog freeze: none of the findings asks for an item or recipe change. Catalog oddities are reported for Dave's review.

## (a) Step-by-step walkthrough: a new character with nothing, following MAIN 1-45

Legend: YES means the earlier steps explain enough. YES-WITH-UNTAUGHT-PREREQ means the step can be done but needs something no earlier step explains. NO means the step cannot be done as written. UNKNOWN means the code reading cannot settle it.

| # | goal_id | Can do now? | What the guide fails to explain | Evidence |
|---|---|---|---|---|
| 1 | gather:stick | YES | The prompt says only "Press E to gather". Hold E picks up everything within 2 m. Auto pickup is the P key. Tap or hold is not explained (LOW). | CONTROLS.md:77, :23 (P) |
| 2 | gather:stone | YES | "Or break an appropriate boulder": the player has no tool yet. A stone axe blow on bare rock gives a stone, but the axe is step 7 (LOW). | CONTROLS.md:62; items.json stone description |
| 3 | drink | YES | Nothing missing. | CONTROLS.md:75; server_items.gd:1104-1109 (`_goal_event drink`); test_goals relayed pass |
| 4 | fibre | YES | Asks for 12 fibre. The tools up to the hammer need 5 twine = 15 fibre (2 axe + 2 pickaxe + 1 hammer), and the twine goal's 2 twine are used by the axe (W-11). | drops.json by_species nettle 1-2, tall_grass 1-3; recipes.json:10 (twine 3 fibre) |
| 5 | twine | YES | Nothing missing for the craft. The I key, queue and Craft button match the live screen. | recipes.json:10; CONTROLS.md:58 |
| 6 | craft:stone_knife | YES | That the knife is the carcass tool is not mentioned until step 45 (W-02). | recipes.json stone_knife; items.json stone_knife tool_class knife |
| 7 | axe | YES | "Equip it": a new tool goes into the first empty hotbar slot by itself. The player must press that number key to hold it, and tools work only from the hotbar (LOW, W-15). | CONTROLS.md:59; server_items.gd:5979-5983 (`_held_tool` needs on_hotbar) |
| 8 | craft:stone_pickaxe | YES | Needs 2 more twine. The fibre count of step 4 is short (W-11). Purpose not stated: boulders and ore. A pick on wood only makes kindling. | recipes.json stone_pickaxe; server_items.gd:6431-6440, 9240-9262 |
| 9 | fell | YES | A tree takes 3-22 blows by trunk size. "Strike a thin tree first" is missing (LOW). When the trunk lands it breaks into logs by itself, and the crown drops sticks and leaves (broadleaves, not in winter). The leaves are needed at step 25 and the guide never says so (W-08). | server_items.gd:5827-5893 (`_hit`), 6640-6720 (`_auto_split`, `split_trunk`); drops.json felling tree_min 3 / tree_max 22, trunk crown_scatter, leaves_note |
| 10 | gather:log | YES-WITH-UNTAUGHT-PREREQ | "Collect the resulting logs" (plural) cannot be done. A species log (Oak, Birch, Spruce, ...) is a shoulder item, one at a time. A second pickup says "Put your log down first (Q)". Q, which puts it down, is never taught. Whether the goal key `log` counts species logs is per runtime workstream (W-04, W-20). | items.json log_oak `carry: shoulder`, `stack 1`; server_items.gd:898-927, 908; key_bindings.gd:30 (put_down_log Q) |
| 11 | activity:chop_log_blocks | YES-WITH-UNTAUGHT-PREREQ | "Drop a felled log onto the ground": felled logs already lie on the ground, so no drop is needed. Q, F F or D drops a carried one. The yield is not explained. A species (shoulder) log gives 3 Large wooden blocks. Only a plain `Log` (species whose own log is retired, e.g. alder, willow, rowan) gives 3 small blocks. "Keep one for your Wooden - Hammer" is therefore usually wrong (W-01). | server_items.gd:9223-9276 (`_chop_loose_log`; 9268 count, 9276 `block_large` if shoulder log); structures.json:30 chopping_block blocks_per_log 3, blocks_per_shoulder_log 3; wood_species.json class_items; CONTROLS.md:72 says "4 blocks from a log, 12 from a shoulder log" (stale) |
| 12 | hammer | NO, as written, for most first trees | The recipe needs `wooden_block` (group: Hardwood block or Softwood block). A Large block does not satisfy it. Hidden step: Inventory, "Small wooden blocks" (1 Large wooden block, axe kept, gives 4 Hardwood blocks) or "Small softwood blocks". That step is a side goal at level 5 / 3 (W-01). | recipes.json:3391 (wooden_hammer needs wooden_block), :4113 (small_blocks_from_large), :4123; wood_species.json:12,17 (groups); test_mission001_walkthrough.gd:482-484 crafts `small_blocks_from_large` before `wooden_hammer` (relayed pass, step 1e) |
| 13 | craft:campfire_kit | YES | Nothing missing. | recipes.json:146 |
| 14 | activity:place_campfire | YES-WITH-UNTAUGHT-PREREQ | "Use its placement action": the kit is not a tool and lands in the backpack. The player must open I, Use (E) on the kit to hold it, then left-click where the ring shows. Also missing: 2 m from another fire, 2.5 m from structures, a yellow ring means rain puts it out, a green ring means under a crown (W-06). | CONTROLS.md:59 (Use E on a kit moves it to the hotbar), :67; hints.json place_fire; server_items.gd:3666-3829 (fire gap and `_goal_event placed campfire` at 3829) |
| 15 | fire | YES | "Open its fuel storage with F, add sticks" is not needed. A placed kit already holds its first sticks, and E lights it. The kit's own description still says "light it with fibre", but no starter is used (LOW, W-12). | server_items.gd:3822-3828 (start sticks into the store); CONTROLS.md:73; items.json:73 campfire_kit description |
| 16 | craft:chopping_block | YES-WITH-UNTAUGHT-PREREQ | "1 Large wooden block": the guide never said where it comes from. Step 11 said only "wooden blocks" (W-01; also pass2_report.txt). | recipes.json:344; server_items.gd:9276 |
| 17 | activity:place_chopping_block | YES-WITH-UNTAUGHT-PREREQ | Same placement gap as step 14 (I, Use E, left click) (W-06). Missing: 2.5 m clear of the fire and other structures. "Keep an axe equipped": it must be in hand (held hotbar slot), not merely owned. | server_items.gd:9188-9193 ("You need an axe in hand to split wood."), 8418 (2.5 m gap) |
| 18 | gather:log_oak | YES | "Oak or other supported hardwood" is not listed: beech, birch, maple, walnut and mahogany also count. Spruce, Scots pine and the plain Log are softwood (W-14). One at a time on the shoulder (W-04). | wood_species.json ingredient_groups log_oak / log_spruce |
| 19 | craft:firewood | YES-WITH-UNTAUGHT-PREREQ | The text mixes two real actions. (1) E at the block splits one wooden block from the pack. A small block gives 2 firewood and a large block gives 4, on the ground beside the block. (2) F opens the block's Craft tab, where "Hard firewood" turns 1 hardwood log (shoulder, or on the ground within 3 m) into 12 firewood in the block's own store. The goal cites recipe (2) but tells the player to do (1) (W-05). | server_items.gd:9175-9207 (E path; structures.json:30 firewood_per_block 2, firewood_per_large_block 4); recipes.json:7947 (chopping_hard_firewood: log_oak, keeps axe, gives 12, station chopping_block); server_items.gd:17005-17006, 15844 (logs within 3 m) |
| 20 | activity:medium_fire | YES | Firewood made through F sits in the chopping block's store tab and must be taken out first (W-05). Any wooden block also counts as firewood class, so blocks alone can make the medium fire. Fine, but a shortcut worth stating. | cooking.json fuel_class (wooden_block* = firewood), min_pieces 3; CONTROLS.md:73; test_fire_fuel_tiers relayed pass |
| 21 | activity:bonfire | YES-WITH-UNTAUGHT-PREREQ | 3 logs means 3 trips with one shoulder log each: E to pick up, walk, F at the fire, move it in. Not explained (W-04). The next pot step cannot use this fire while logs remain (W-07). | cooking.json fuel_class log, fire_tiers log tier 3; CONTROLS.md:73 (a log burns 3 h real time); server_items.gd:9685 (logs ignored under a pot) |
| 22 | berries | YES | Nothing missing (right click or Eat / use). | CONTROLS.md:78 |
| 23 | craft:wooden_spade | YES | Nothing missing. Right click switches Dig and Raise. Default is Dig. | recipes.json wooden_spade; held_item.gd:1156-1159, 2228 |
| 24 | gather:thatch | YES | Quantity: rows 26-33 need 145 thatch (bed 10, foundation 20, wall 20, doorway 20, window 15, two roofs 60). Tall grass gives 2 a plant, heather 4, reeds 8, thatch grass 10. "Enough for the selected recipe" hides the scale (W-11). Sources per acquisition workstream. | blueprints.json:232-236, 15; drops.json by_species tall_grass/heather/reeds, harvest_yield thatch_grass |
| 25 | shelter | YES-WITH-UNTAUGHT-PREREQ | The cost is not given: 20 sticks, 60 leaves, 6 twine. Leaves are never taught. They come from a felled broadleaf's crown (none from conifers, none in winter) or from axing a bush. Also missing: open side faces you, 2.5 m gap (W-08). | blueprints.json:228 (lean_to cost); starter_goals.json shelter hint; drops.json trunk crown_leaves fixed (conifers), leaves_note, shrub_work; test_mission001_walkthrough step 1f (relayed pass) |
| 26 | bed | YES-WITH-UNTAUGHT-PREREQ | "Place it under cover": the server lets a non-furniture bed stand within 2.5 m of a structure only inside a lean-to's box. Near a Crude foundation or walls it says "Something is in the way." The client ghost checks only states 5/6/7 and may show green. Say "inside your lean-to". Placement controls as in step 14 (W-06, W-09). | server_items.gd:8406-8418 (`bed_in_shelter`, gap rule); placement_rules.gd:12 (STRUCTURE_STATES 5,6,7), :673-683, :747-757; structures.json:393 (rough_bed not gap_exempt; `shelter_needed` is not read by any .gd) |
| 27 | workbench | YES | 2.5 m spacing not stated (W-16). Otherwise matches blueprints.json:237 (16 stick, 6 twine, 4 stone, hammer 1). | blueprints.json:237; test_goals relayed pass ("placing a workbench completes the workbench goal") |
| 28 | build:thatch_floor | YES | Mouse wheel lifts a lone foundation. A second one snaps edge to edge. Not explained (LOW). | blueprints.json:232; placement_rules.gd:80-90, 400-441; held_item.gd:986-987 |
| 29 | build:thatch_wall | YES | Walls do not need a foundation: on bare ground they snap to a 1 m grid. Aimed near a foundation's edge they snap to its anchors. Not explained. | placement_rules.gd:110-162 (anchors, then `_join`, then grid) |
| 30 | build:thatch_doorway | YES | This is an empty frame. The door is a separate piece, Crude - Door (50 stick, 100 twine, CREATOR cost), that snaps into the opening. MAIN never asks for it (W-03). | structures.json:401 note ("its door is a separate item"); BUGLIST-002 CONTRACT.md:7,65 |
| 31 | build:thatch_window | YES | Nothing missing beyond the generic text. | blueprints.json:15 |
| 32 | build:thatch_roof | YES-WITH-UNTAUGHT-PREREQ | The panel must rest on a wall top, a ceiling edge or another panel's end, aimed across it. The server refuses a free-standing panel. The wheel flips rise or fall. "Where the building ghost is valid" hides all of this (W-10). | server_items.gd:3730; placement_rules.gd:306-338; held_item.gd:990-992; structures.json:400 note; test_roof_panels.gd |
| 33 | build:thatch_roof_65 | YES-WITH-UNTAUGHT-PREREQ | Same as 32. | structures.json thatch_roof_65 note |
| 34 | gather:clay | YES | The inspection key (/) names the ground (Clay). Loam, silt and alluvium also give clay 35-50% of the time under the topsoil. "Verify the terrain shown by the game" could say this. | digging.json yield clay, under; CONTROLS.md:25 (/ inspection) |
| 35 | gather:sand | YES | No purpose in rows 1-45. Sand is first used by Clay mortar at draft line 96 (W-13). | digging.json yield sand / beach_sand |
| 36 | craft:brick | YES | "Use a lit campfire" means stand within the fire's use reach while it burns. 3 bricks per craft. The hearth and oven need 34 bricks, about 12 crafts and 24 clay, which is not said (W-11). | recipes.json:2846; server_items.gd:13039-13046 (campfire station = a lit fire) |
| 37 | craft:clay_pot | YES | Nothing missing (6 clay at a lit campfire). | recipes.json clay_pot |
| 38 | build:campfire_pot | YES-WITH-UNTAUGHT-PREREQ | It must be aimed onto a small fire within 2 m. It is refused on the bonfire and on any fire still holding logs: "The fire is too big for a pot. Let the logs burn down first." "Where the ghost is valid" misleads, and the bonfire built at row 21 is the wrong fire for 3+ real hours (W-07). | placement_rules.gd:10 (POT_FIRE_STATES excludes 41), :66-67, :731-743; server_items.gd:8371-8379; test_campfire_pot.gd:166-172 (relayed pass) |
| 39 | build:drying_rack | YES | 2.5 m spacing (W-16). Purpose (MAIN 48 scraped hide, dried foods) is not stated. | blueprints.json drying_rack; structures.json drying_rack |
| 40 | build:smoker | YES | 2.5 m spacing (W-16). | blueprints.json smoker |
| 41 | build:food_preparation_table | YES-WITH-UNTAUGHT-PREREQ | "3 Log": logs are drawn from the shoulder and from log items on the ground within 3 m of the player ("Using nearby logs"), or from a blueprint site filled with E. Never explained (W-04). | blueprints.json:283; server_items.gd:8164, 15839-15925 |
| 42 | build:clay_hearth | YES | 10 bricks means 4 brick crafts (W-11). The hearth also counts as a campfire station (`also`). Not mentioned, but harmless. | blueprints.json:198; structures.json:396 (station_level 2, also campfire 1) |
| 43 | build:oven | YES-WITH-UNTAUGHT-PREREQ | "Build near Clay hearth": the player must stand within about 4 m of the hearth (its reach 3 m + 1 m grace), and the oven must stand at least 2.5 m from it. 24 bricks means 8 crafts (W-16, W-11). | blueprints.json:207 (near clay_hearth, near_level 2); server_items.gd:8155-8156, 13022-13050; 8418 |
| 44 | craft:thread | YES | No consumer in rows 1-45. Its purpose is not stated (W-13). | recipes.json thread |
| 45 | gather:hide | NO with what MAIN taught | No MAIN step makes a weapon or a snare. Only `kind: weapon` items with damage can strike an animal. The stone axe, pickaxe and knife are `kind: tool`. The knife must then be in hand to dress the carcass (left click), and rabbits give 1 hide. Hunting (Wooden - Spear L1, Snare L2, "spear" L3, "knife" L4) is all off-route (W-02). | server_items.gd:2243-2259 (`_strike`: weapon kind and damage only), 2288-2296 (`_process_carcass`: knife in hand), 2335 (carcass_worked); items.json stone_axe/stone_knife kind tool, wooden_spear kind weapon; carcass.json rabbit parts; server_traps.gd:3-5 |

Tally: YES 29, YES-WITH-UNTAUGHT-PREREQ 14, NO 2 (rows 12 and 45), UNKNOWN 0. Row 12 is NO for any species log, and only the plain-Log species (retired species logs) avoid it.

## (b) Findings

**W-01 HIGH: the Wooden - Hammer needs a step the guide does not have.** Affected: activity:chop_log_blocks, hammer, craft:chopping_block, craft:wooden_block, craft:wooden_block_soft.
- Felled trees drop the species log (`_log_number`, server_items.gd:6627-6633). The live, non-retired species logs (oak, beech, birch, Scots pine, spruce, mahogany, walnut, maple) are shoulder items (items.json `carry: shoulder`).
- Axing a shoulder log on the ground gives 3 **Large** wooden blocks (`block_large`, server_items.gd:9268-9276). Only the plain `Log` gives small blocks.
- Wooden - Hammer needs `wooden_block`, the Hardwood/Softwood block group (recipes.json:3391; wood_species.json:12). A Large block does not satisfy it.
- The working route is the one the walkthrough test uses: craft "Small wooden blocks" (1 Large, axe kept, gives 4 Hardwood blocks), then the hammer (test_mission001_walkthrough.gd:482-484, relayed pass).
- **Add** a MAIN step between rows 11 and 12: "Cut a large block into small blocks". In Inventory (I), craft Small wooden blocks (1 Large wooden block, axe on the hotbar kept) for 4 Hardwood blocks, or Small softwood blocks from a softwood large block. Reuse goal ids craft:wooden_block / craft:wooden_block_soft and move them out of levels 5 and 3.
- **Correct** row 11: "A full species log gives 3 Large wooden blocks; keep one for the Chopping block and cut another into small blocks for the hammer."
- Report for Dave (catalog, no edit): `small_blocks_from_large` accepts the softwood large block through the group and still gives Hardwood blocks (recipes.json:4113, wood_species.json:17). CONTROLS.md:72 still says "4 blocks from a log, 12 from a log carried on the shoulder", but the data says 3 and 3 (structures.json:30).

**W-02 HIGH: "Obtain hide" (MAIN 45) has no hunting step before it.** Affected: gather:hide, then craft:processed_hide, craft:leather and the rest of the leather chain.
- `_strike` accepts only items with `kind: weapon` and damage (server_items.gd:2249). The MAIN tools (axe, pickaxe, knife, hammer, spade) are `kind: tool`.
- Dressing needs a knife in hand (server_items.gd:2294) and pays out over several blows.
- The ways to get a carcass are all side goals: craft:wooden_spear (L1, weapon, damage 6), craft:snare (L2, a catch lays a carcass, server_traps.gd:3-5), spear (L3) and the legacy knife goal "Make a Stone - Knife and work a kill" (L4, event carcass_worked, server_items.gd:2335).
- **Add** 2 MAIN steps before row 45:
  - "Craft Wooden - Spear (1 stick, keep 1 stone); hold it and left-click to jab, or right-click hold then left-click to throw", or the Snare alternative.
  - Move legacy `knife` here: "Kill a rabbit, hold the Stone - Knife and left-click the carcass until it is dressed (a rabbit gives 1 hide, 1-2 meat, 1-2 bone)".
- Then row 45 can say "from the carcass you dressed".

**W-03 HIGH: door ordering and door instructions.** Affected: build:crude_door, build:crude_arched_door, build:crude_double_door, build:crude_double_arched_door, build:thatch_doorway.
- A door places only into an empty doorway of its own shape. Otherwise the server says "a door goes in a doorway: aim at the empty opening of one" or "this doorway takes ...". See placement_rules.gd:32, 587-620, 811-816 and server_items.gd:3733-3740 (doorway_fit at 3734). test_doors is a relayed pass.
- Crude - Arched door, Double door and Double arched door are at level 2 (draft lines 199, 201, 202). Their doorways are at level 4 (lines 244-246), so all three are NO at their listed position.
- All four door how-tos say "Place it where the building ghost is valid" instead of "aim at the empty opening of a matching Crude doorway".
- MAIN row 30 builds an empty frame and never mentions the door.
- **Correct**: put each door after its frame, and change the door text to "Aim at the empty opening of a Crude - [shape] doorway; the door snaps in."
- **Add** to row 30: "This is an empty frame; its door is the separate Crude - Door." Optionally add build:crude_door to MAIN after row 30.
- Costs are CREATOR (BUGLIST-002 CONTRACT.md:65: 50 stick, 100 twine, doubles 2x). Do not change them. Do state that 100 twine is 300 plant fibre.

**W-04 MED: logs are never explained (shoulder carry, Q, how recipes and blueprints take them).** Affected: gather:log, activity:chop_log_blocks, gather:log_oak, activity:bonfire, build:food_preparation_table, and every later log-cost blueprint (side L4 Rustic, Grindstone, Oil press, racks).
- A species log is one pack slot shown on the shoulder, one at a time. A second pickup says "Put your log down first (Q)" (server_items.gd:898-927).
- Q, F F or D lays it down (key_bindings.gd:30; CONTROLS.md:24, 28).
- Crafts and blueprints that cost logs take the carried log first, then log items lying within **3 m** of the player (LOG_NEAR_M, server_items.gd:15839-15925; 8164 blueprints; 17005-17006 crafts). The player sees "Using nearby logs".
- A blueprint site set down with too few materials is filled with E (CONTROLS.md:53).
- **Add** one sentence to row 10 and reuse it in rows 21 and 41: "Logs are carried one at a time on your shoulder (Q puts one down). For a recipe or blueprint, lay the logs within 3 m of you, or set down the blueprint and press E on it to add materials."

**W-05 MED: firewood: two real paths, taught as one.** Affected: craft:firewood, activity:place_chopping_block, activity:medium_fire.
- Path (1), the draft's text: E at the block splits one wooden block from the pack. A small block gives 2 firewood and a large one gives 4, dropped beside the block (server_items.gd:9175-9207; structures.json:30).
- Path (2), the recipe the row cites: F opens the block's Craft tab. "Hard firewood" turns 1 hardwood log into 12 firewood, axe on the hotbar, and the firewood goes into the block's store tab (recipes.json:7947; CONTROLS.md:72). "Soft firewood" takes a softwood log.
- Both work, so the draft's "discrepancy" note is not a contradiction.
- **Correct** row 19 to teach path (2), which matches the recipe key and row 18's hardwood log: "Lay the oak log within 3 m (or carry it), press F at the chopping block, choose Hard firewood, Craft: 12 firewood appear in the block's store tab; take them out." Mention E-splitting a block as the quick alternative.
- Row 20 should add: "wooden blocks also count as firewood on a fire" (cooking.json fuel_class).
- Which event each path emits is per runtime workstream.

**W-06 MED: placing kits (campfire, chopping block, Thatch - Bed, snare, rock pile) is never explained.** Affected: activity:place_campfire, activity:place_chopping_block, bed, craft:snare, craft:rock_pile.
- These are `kind: placeable`, not tools, so they go to the backpack, not the hotbar.
- The working control is I, select the kit, Use (E), which moves it to the hotbar and holds it. Then left-click where the ghost or ring shows (CONTROLS.md:59, 67; hints.json place_fire "Hold the fire kit and click ground").
- **Correct** rows 14, 17 and 26 to say exactly that, with the ring colours for the fire.

**W-07 MED: the Campfire pot instruction misleads, and it follows the bonfire.** Affected: build:campfire_pot, activity:bonfire.
- The pot is attach_to fire. It snaps only to a small fire within 2 m, never the bonfire (placement_rules.gd:10, 66-67).
- The server refuses any fire whose store still holds logs (server_items.gd:8371-8379; test_campfire_pot.gd:166-172, relayed pass).
- A log burns about 3 real hours (CONTROLS.md:73). Right after row 21 the player's only fire is the wrong one.
- **Correct** row 38: "Hold the hammer near a small lit campfire (sticks or firewood, no logs), choose Campfire pot and aim at the fire; it hangs over it. A fire with logs in it is too big: lay a second campfire at least 2 m away or wait."

**W-08 MED: the lean-to's cost and its leaves are never taught.** Affected: shelter, and indirectly fell.
- The blueprint costs 20 stick, 60 leaves and 6 twine (blueprints.json:228; starter_goals.json shelter hint). The draft says only "the materials displayed".
- Leaves come from a felled broadleaf's crown (about 100 for a mid-size tree). Conifers give none, and bare broadleaves give none in winter. Axing a bush gives 10-20 (drops.json trunk crown_scatter, crown_leaves fixed, leaves_note; shrub_work).
- **Correct** row 25 with the cost. **Add** to row 9 or 25: "pick up the leaves from the crown of a felled broadleaf (not pine or spruce; none in winter) or chop bushes with the axe."

**W-09 MED (UNKNOWN in play): "place it under cover" can fail for the Thatch - Bed.** Affected: bed.
- The server exempts a bed from the 2.5 m structure gap only inside a shelter's box (lean-to; server_items.gd:8406-8418). The rough bed is not gap_exempt (structures.json:393).
- A bed on or beside a Crude foundation or walls gets "Something is in the way."
- The client ghost checks the gap only against states 5/6/7 (placement_rules.gd:12, 745-765), so it can show green there. This client/server mismatch was found by reading the code only and is not play-verified.
- `shelter_needed` is in data but read by no script, so the bed can also stand in the open.
- **Correct** row 26: "place it inside your lean-to."

**W-10 MED: Crude roof panels and the building controls are hidden behind "where the ghost is valid".** Affected: build:thatch_roof, build:thatch_roof_65, build:thatch_floor, build:thatch_wall.
- Roof panels must rest on a wall top, a ceiling edge or another panel's end, facing across it. The server refuses one on the ground (server_items.gd:3730; placement_rules.gd:306-338). The mouse wheel flips rise or fall (held_item.gd:990-992).
- CONTROLS.md does not document the roof-panel wheel at all (cross-reference for the UI/keys workstream).
- Walls snap to a foundation's edge when aimed near it but also stand on bare ground (placement_rules.gd:110-162). The wheel lifts a lone foundation (held_item.gd:986).
- **Correct** rows 32 and 33: "Build walls first; aim at the top of a wall and face across it; the mouse wheel flips whether the panel rises or falls from that edge." Give rows 28 and 29 the one-line snapping hint.

**W-11 MED: quantities are not given, and the counts are large.** Affected: fibre, twine, gather:thatch, craft:brick, build:clay_hearth, build:oven.
- MAIN rows 5-43 spend 55 twine, i.e. 165 plant fibre. Itemised: twine goal 2, axe 2, pickaxe 2, hammer 1, lean-to 6, bed 2, workbench 6, Crude pieces 4+3+3+3+6+6, pot 3, rack 4, table 2. Row 4 asks for 12 fibre.
- The same rows need 145 thatch, and 34 bricks: 12 brick crafts, 24 clay. Clay overall for rows 36-43 is about 52.
- **Correct** row 4 to "at least 15 for your first tools". Add a "you will need about ..." line to rows 24 and 36. No goal change is needed.

**W-12 LOW: lighting text and the stale kit description.** Affected: fire.
- The kit is laid with its first sticks already in the store (server_items.gd:3822-3828), so "add sticks" is optional.
- items.json:73 still says "light it with fibre". CONTROLS.md:73 says no starter is needed or used (Dave 5 Nov 2026). Report this text for Dave's catalog review.
- A laid, unlit fire waits FIRE_LAID_S = 1800 s for the player (server_items.gd:114). What happens after that was not traced (UNKNOWN). "Light it soon after placing" is a safe hint.

**W-13 LOW: rows without a purpose in this segment.** Affected: gather:sand (MAIN 35), craft:thread (MAIN 44).
- Sand is first used by Clay mortar (draft line 96). Thread has no consumer in rows 1-45.
- **Proposed**: move sand next to mortar and thread next to its first consumer, or state the purpose in the how-to.

**W-14 LOW: "oak or other supported hardwood" should name the species.** Affected: gather:log_oak, craft:firewood.
- The Hardwood log group is oak, beech, birch, maple, walnut and mahogany (`log_tropical_hardwood`). Spruce, Scots pine and the plain Log feed the Softwood recipe (wood_species.json ingredient_groups log_oak / log_spruce).
- A birch counts as hardwood here, which a player would not guess.

**W-15 LOW: control details.** Affected: axe, fell, gather:stone, and the draft header.
- Tools must be on the hotbar and held with the number key (CONTROLS.md:59; server_items.gd:5980).
- A tree takes 3-22 blows (drops.json felling). Thin trees are quickest.
- "Break a boulder" needs a stone axe or pickaxe, which come at rows 7-8.
- The draft header assigns J and G to the journal and goals. key_bindings.gd:53 binds G to the admin fly toggle and :65 binds J to the jitter test (cross-reference only, per UI/keys workstream).

**W-16 LOW: station spacing and the oven's "near".** Affected: activity:place_campfire, activity:place_chopping_block, workbench, build:drying_rack, build:smoker, build:food_preparation_table, build:clay_hearth, build:oven.
- Every non-piece structure must stand 2.5 m from fires and other structures (structures.json gap_m 2.5; server_items.gd:8418). The exceptions are gap_exempt furniture and beds in a lean-to. Fires need 2 m between fires.
- The oven needs the player within the hearth's 3 m reach plus 1 m grace while placing (server_items.gd:8155-8156, 13022-13050), with the oven itself at least 2.5 m from the hearth.
- **Add** one sentence to row 14 that applies to all stations, and "2.5 to about 4 m from the hearth" to row 43.

**W-17 MED: level-5 side goals that cannot be built.** Affected: build:stone_cistern, build:clay_pipe_run, build:clay_pipe_elbow, build:clay_pipe_tee, build:stone_channel, build:stone_channel_corner, build:stone_channel_tee, build:stone_trough.
- The rows are `known: false, locked: true` (blueprints.json:96-107), and `_can_blueprint` refuses unknown rows (server_items.gd:8138-8139).
- **Recommend** marking them unavailable or hiding them until unlocked. Do not list them as achievable goals.

**W-18 MED: side-branch dependency levels 1-5 understate prerequisites.** Section (c) lists them one by one. The worst cases:
- Feathered arrows and bolts at L1 need a bird kill.
- Flour (L2) needs farmed wheat.
- Fish dishes (L2) come before "Catch a fish" (L3).
- Stone - Hoe (L3) needs the Wooden - Hoe from "Make a hoe" (L5).
- Raw-meat dishes at L2/L3 come before any hunting.
- Sturdy and Superior pieces at L5 need Clay mortar and Cobblestone, which are taught at MAIN draft lines 95-96.
- Fibre cloth (L5) needs the Loom (MAIN draft line 81).
- **Correct**: recompute levels from MAIN position. Hunting at least should be a MAIN step (W-02).

**W-19 LOW: one action, several rewards.** Affected: craft:rough_bed_kit and bed (craft, then place); craft:campfire_kit, activity:place_campfire and fire (craft, place, light).
- This is acceptable as tutorial granularity, but craft:rough_bed_kit (L2) duplicates the craft that MAIN 26 already requires. Flag for Dave's reward review; no change proposed here.

**W-20 LOW (UNKNOWN): the gather:log goal key is the plain `log`.** Affected: gather:log.
- Most felled trees give species logs, which are members of the `log` group (wood_species.json:9).
- Whether completion matches group members is per runtime workstream. If it matches only the id `log`, row 10 is unreachable from oak, birch, spruce and the other species trees.

## (c) Side-branch goals, dependency levels 1-5, checked one by one (166)

Unless a line says otherwise, "OK" means the draft's materials, station and kept tools match recipes.json or blueprints.json (static_flags empty in goals_parsed.json, re-read by hand for the early rows). Every blueprint row listed is hammer 1 (blueprints.json; only 39 Iron/Fortified rows are tier 3), so the Wooden - Hammer is enough throughout. Every non-furniture structure also needs 2.5 m clearance (W-16), which no how-to states.

- L1 `craft:compost` (draft line 155): problem. Rotten food only exists after food spoils, and nothing at level 1 teaches it (raw source per acquisition workstream).
- L1 `craft:grass_skirt` (draft line 156): OK. 8 plant fibre, hand (recipe matches).
- L1 `craft:fishing_bait` (draft line 157): problem. Worms come only from Wooden - Spade digs in moist soil (digging.json finds, 6% a stroke). The spade is MAIN 23, so level 1 is too early, and the source is not named.
- L1 `craft:quern` (draft line 158): OK. 2 stone, 1 stick, hand. Its purpose (flour) needs wheat from farming; say so.
- L1 `craft:mortar_pestle` (draft line 159): OK. 2 stone, hand.
- L1 `craft:bandage` (draft line 160): OK. The order works (Mortar and pestle is the row above). Plantain leaves source not named (raw source per acquisition workstream).
- L1 `craft:rock_pile` (draft line 161): OK. 45 stone, hand. It is a placeable (hotbar plus left click), which is not explained.
- L1 `craft:rope` (draft line 162): OK. 4 twine (12 plant fibre), hand.
- L1 `craft:sling_stone` (draft line 163): problem. Gravel needs a Wooden - Spade on gravel ground (digging.json yield gravel). The spade is MAIN 23, so level 1 is too early.
- L1 `craft:stone_arrow` (draft line 164): problem. Feathers come from a bird carcass (carcass.json grouse and others), so a kill and a knife come first. Arrows are useless before the Shortbow (level 3, Workbench).
- L1 `craft:whetstone` (draft line 165): OK. 1 stone, hand.
- L1 `craft:wicker_shield` (draft line 166): OK. 3 stick, 2 fibre, hand.
- L1 `craft:wooden_arrow` (draft line 167): problem. Needs Feathers (a bird kill); same ordering fault as Stone - Arrow.
- L1 `craft:wooden_bolt` (draft line 168): problem. Needs Feathers, and a bolt also needs a crossbow that comes far later than level 1.
- L1 `craft:wooden_spear` (draft line 169): OK, and it is the first real weapon (items.json wooden_spear kind weapon, damage 6). It should move to MAIN before gather:hide (W-02).
- L1 `build:vice` (draft line 170): OK to build (8 stick, 4 stone, hammer 1). It is a Workbench add-on (structures.json vice addon_of workbench) and the Workbench is MAIN 27. The how-to does not say to place it near the Workbench.
- L2 `sell` (draft line 176): OK as written (legacy goal). NPC location per runtime workstream.
- L2 `craft:bark_shingle` (draft line 177): OK. 2 bark, keeps Any knife. Bark source (axe work on trunks, knife on bark) not named (raw source per acquisition workstream).
- L2 `craft:campfire_roasting_spit` (draft line 178): OK. 4 stick, 2 twine, hand.
- L2 `craft:grass_cloak` (draft line 179): OK. 16 fibre, 1 twine, hand.
- L2 `craft:fibre_sandals` (draft line 180): OK. 6 fibre, 1 twine, hand.
- L2 `craft:fibre_shoulder_bag` (draft line 181): OK. 8 fibre, 3 twine, hand.
- L2 `craft:fire_arrow` (draft line 182): problem. Needs a Wooden - Arrow (feathers, a bird kill) and Pitch (resin, pine tar or animal fat: wood_species.json ingredient_groups pitch). Neither is available at level 2.
- L2 `craft:shore_net` (draft line 183): OK. 3 rope (36 fibre), 4 stone, hand. How to set it at water is not explained (per acquisition workstream).
- L2 `craft:fishing_spear` (draft line 184): OK. 1 stick, keeps Any knife (the knife is MAIN 6).
- L2 `craft:flour` (draft line 185): problem. Wheat needs farming (tall grass gives wheat seeds only, drops.json seed_drops), so level 2 is far too early.
- L2 `craft:garlic_meat` (draft line 186): problem. Needs Raw meat (a kill and a knife) plus wild garlic and rosemary. No hunting is taught by level 2.
- L2 `craft:herb_antidote` (draft line 187): problem. Needs 1 Water as an item, and no goal teaches filling a container (raw source per acquisition workstream).
- L2 `craft:herb_fish` (draft line 188): problem. Needs a Fish, and "Catch a fish" is level 3 (listed after this row).
- L2 `craft:poultice` (draft line 189): OK. 3 plantain, keeps Mortar and pestle.
- L2 `craft:juniper_trout` (draft line 190): problem. Needs a Fish (level 3, listed after) and juniper berries.
- L2 `craft:snare` (draft line 191): OK. 3 twine, 2 stick. It is the other early way to get a carcass (server_traps.gd:3-5). It is placed from the hotbar on an animal path, which is not explained.
- L2 `craft:splint` (draft line 192): OK. 2 stick, 1 twine, hand.
- L2 `craft:stone_hammer` (draft line 193): OK. 1 stone, 1 stick, 1 twine. It is tier 2, but no live blueprint needs tier 2 (blueprints.json hammer is 1 or 3 only). Say what it is for (durability, reach for materials).
- L2 `craft:stone_mace` (draft line 194): OK. A weapon (damage 9) usable for hunting.
- L2 `craft:straw_hat` (draft line 195): OK. 6 straw, 2 twine. Straw comes from tall grass (drops.json by_species tall_grass straw 1-3), which is not named.
- L2 `craft:rough_bed_kit` (draft line 196): OK, but it duplicates MAIN 26 "Make a bed" (that goal needs this exact craft first), so one action earns two rewards.
- L2 `craft:wicker_pack_basket` (draft line 197): OK. 12 stick, 4 twine, hand.
- L2 `build:wicker_basket` (draft line 198): OK. 8 stick, 4 twine, hammer 1.
- L2 `build:crude_arched_door` (draft line 199): NO at this position. A door snaps only into an empty doorway of its own shape (placement_rules.gd:587-620), and Crude - Arched doorway is level 4 (line 244). The cost of 50 stick plus 100 twine is the creator-approved door cost (BUGLIST-002 CONTRACT.md:65). The how-to lacks "aim at the empty doorway".
- L2 `build:crude_door` (draft line 200): OK after MAIN 30 (Crude - Doorway). The how-to says "where the building ghost is valid" instead of "aim at the empty opening of a Crude - Doorway". 100 twine is 300 plant fibre and deserves a warning.
- L2 `build:crude_double_arched_door` (draft line 201): NO at this position. Needs a Crude - Double arched doorway (level 4, line 245).
- L2 `build:crude_double_door` (draft line 202): NO at this position. Needs a Crude - Double doorway (level 4, line 246).
- L2 `build:thatch_fence` (draft line 203): OK. 12 stick, 2 twine; stands on the ground.
- L2 `build:thatch_gate` (draft line 204): OK. 14 stick, 3 twine.
- L2 `build:thatch_pillar` (draft line 205): OK. It snaps to a foundation's middle or corners (placement_rules.gd:166-176); say so.
- L2 `build:straw_bed` (draft line 206): OK. Hammer blueprint, gap_exempt (structures.json straw_bed). Straw source not named.
- L2 `build:thatch_garden_plot` (draft line 207): YES-WITH-UNTAUGHT-PREREQ. Soil needs the Wooden - Spade (MAIN 23) on soil ground, which is not named.
- L2 `build:tool_rack` (draft line 208): OK to build. It is a Workbench add-on (structures.json tool_rack addon_of workbench, addon_reach_m 5) but must stand 2.5 m clear (server_items.gd:8418). Not explained.
- L2 `build:wooden_trellis` (draft line 209): OK. 10 stick, 4 twine.
- L2 `build:chest` (draft line 210): OK. 10 stick, 4 twine (test_mission001_walkthrough step 1g builds it).
- L3 `fish` (draft line 216): problem. The text is vague. The earliest working method is a Wooden - Spear or Fishing spear jab at fish water (server_items.gd:13401-13402, spear and fish_spear). The Fishing rod needs a Hook made from Bone (recipes.json fishing_rod, hook), so a kill comes first.
- L3 `spear` (draft line 217): OK. Wooden - Spear, then Stone - Spear (1 wooden spear, 2 twine, 1 stone; recipes.json spear).
- L3 `craft:dried_apples` (draft line 218): OK after the MAIN 39 Drying rack. Apples are seasonal (raw source per acquisition workstream).
- L3 `craft:dried_figs` (draft line 219): OK after MAIN 39. Figs are regional (raw source per acquisition workstream).
- L3 `craft:dried_mushrooms` (draft line 220): OK after MAIN 39 (test_mission001_walkthrough step 4i dries porcini).
- L3 `craft:horn_pane` (draft line 221): problem. Horn comes only from a carcass, and no hunting comes before level 3 (raw source per acquisition workstream).
- L3 `craft:javelin` (draft line 222): YES-WITH-UNTAUGHT-PREREQ. Flint is taught at MAIN 46; fine if the main route comes first.
- L3 `craft:roast_joint` (draft line 223): problem. Needs Raw meat (a kill) and an Oven (MAIN 43); level 3 understates both.
- L3 `craft:wooden_bow` (draft line 224): OK. 2 stick, 3 twine at a Workbench (MAIN 27). Useless without arrows (feathers).
- L3 `craft:wooden_block_soft` (draft line 225): problem. This craft is required at MAIN 12 whenever the first tree was softwood (spruce, Scots pine), so it belongs in MAIN before the hammer (W-01).
- L3 `craft:stone_hoe` (draft line 226): problem. Needs a Wooden - Hoe, which "Make a hoe" teaches at level 5 (pass2_report.txt).
- L3 `craft:cut_stone_block` (draft line 227): OK. 8 stone at a Workbench.
- L3 `craft:stone_shingle` (draft line 228): OK. 2 stone at a Workbench.
- L4 `gather:animal_fat` (draft line 234): OK after hunting, but rabbits give none. Only larger animals do (carcass.json boar and deer parts); say which.
- L4 `gather:bone` (draft line 235): OK after hunting (a rabbit gives 1-2 bone, carcass.json).
- L4 `order` (draft line 236): OK (legacy).
- L4 `knife` (draft line 237): OK as a goal (event carcass_worked, server_items.gd:2335). But it is the only goal that teaches "kill, then dress with the knife", and it sits at level 4 while MAIN 45 needs it (W-02).
- L4 `build:grindstone` (draft line 238): OK. 12 stone, 2 log. The logs must be on the shoulder or within 3 m (server_items.gd:15844), which is not stated.
- L4 `build:oil_press` (draft line 239): OK. 12 stone, 4 log; same log-reach note.
- L4 `craft:clay_griddle` (draft line 240): OK. 4 clay at a lit campfire.
- L4 `craft:clay_jug` (draft line 241): OK. 4 clay at a lit campfire.
- L4 `craft:clay_pipe` (draft line 242): OK to craft, but its only blueprints (Clay - Pipe, elbow, tee) are locked (W-17).
- L4 `craft:mug` (draft line 243): OK. 2 clay at a lit campfire.
- L4 `build:thatch_arched_doorway` (draft line 244): OK. Costs one Crude - Wall (BUGLIST-002 decision 2).
- L4 `build:thatch_double_arched_doorway` (draft line 245): OK. Twice the wall cost; spans two wall anchors (placement_rules.gd:195).
- L4 `build:thatch_double_doorway` (draft line 246): OK. Twice the wall cost.
- L4 `build:thatch_roof_corner` (draft line 247): OK. Its piece_kind is roof (not a panel), so the wall-top rule does not bind it. Placement guidance is missing.
- L4 `build:firewood_rack` (draft line 248): OK. 2 log, 10 stick, 2 twine; log-reach note.
- L4 `build:flower_pot` (draft line 249): YES-WITH-UNTAUGHT-PREREQ. Soil (spade).
- L4 `build:log_rack` (draft line 250): OK. 4 log, 4 twine. Useful because species logs are one-at-a-time shoulder items.
- L4 `build:log_palisade` (draft line 251): OK. 6 log, 2 twine; log-reach note.
- L4 `build:timber_prop` (draft line 252): OK. 1 log, 1 twine.
- L4 `build:log_arched_doorway` (draft line 253): OK. A Rustic frame costs a Rustic wall (6 log, 2 twine).
- L4 `build:log_floor` (draft line 254): OK. 8 log, 2 twine ("Rustic - Ceiling").
- L4 `build:log_doorway` (draft line 255): OK. 6 log, 2 twine.
- L4 `build:log_double_arched_doorway` (draft line 256): OK. 12 log, 4 twine.
- L4 `build:log_double_doorway` (draft line 257): OK. 12 log, 4 twine.
- L4 `build:log_fence` (draft line 258): OK. 3 log, 1 twine.
- L4 `build:log_gate` (draft line 259): OK. 4 log, 2 twine.
- L4 `build:log_pillar` (draft line 260): OK. 1 log, 1 twine.
- L4 `build:log_roof` (draft line 261): OK. 4 log, 14 Bark shingle, 2 twine (bark shingle is level 2).
- L4 `build:log_roof_corner` (draft line 262): OK. 3 log, 9 bark shingle, 2 twine.
- L4 `build:log_stairs` (draft line 263): OK. 8 log, 2 twine.
- L4 `build:log_wall` (draft line 264): OK. 6 log, 2 twine. The 6 shoulder logs must be ferried one at a time, or a blueprint site filled with E.
- L4 `build:log_window` (draft line 265): OK. 5 log, 2 twine.
- L4 `build:thatch_scarecrow` (draft line 266): OK. 6 stick, 10 thatch, 2 twine.
- L4 `build:log_seat` (draft line 267): OK. 1 log.
- L4 `build:storage_jar` (draft line 268): OK. 8 clay.
- L4 `build:stone_fence` (draft line 269): problem. Cobblestone is a Workbench craft (recipes.json cobblestone, 3 stone) taught only at MAIN draft line 95; level 4 understates it.
- L5 `fur_for_winter` (draft line 275): problem. A "full hide set" needs leather or hide clothing from the Tailor's and Leatherworking tables (MAIN 52-53) and the check event worn_warmth (camp_goals.json). Level 5 understates it (runtime per runtime workstream).
- L5 `story` (draft line 276): UNKNOWN. camp_goals.json marks it needs_code true (per runtime workstream).
- L5 `torch_night` (draft line 277): YES-WITH-UNTAUGHT-PREREQ. The Pitch source (resin, pine tar or animal fat) is not taught (raw source per acquisition workstream).
- L5 `hoe` (draft line 278): OK. Wooden - Hoe: 2 stick, 1 twine, keeps a stone (recipes.json wooden_hoe).
- L5 `craft:banana_fritter_batter` (draft line 279): problem. Flour needs farmed wheat, and bananas are regional (raw source per acquisition workstream).
- L5 `craft:bone_arrow` (draft line 280): problem. Feathers and bone both need kills, and there is no bow before level 3.
- L5 `craft:bone_club` (draft line 281): OK after a kill. 2 bone, 2 twine.
- L5 `craft:sewing_needle` (draft line 282): OK after a kill. 1 bone.
- L5 `craft:egg_nettle_fry` (draft line 283): YES-WITH-UNTAUGHT-PREREQ. Needs eggs (nests), nettles (E on a nettle gives 2-4, drops.json) and animal fat. The griddle is level 4.
- L5 `craft:fibre_cloth` (draft line 284): problem. Needs a Loom (MAIN draft line 81); level 5 understates it.
- L5 `craft:fruit_juice` (draft line 285): problem. Needs 1 Water item (raw source per acquisition workstream).
- L5 `craft:wooden_block` (draft line 286): problem. This is the hidden step MAIN 12 needs (1 Large wooden block gives 4 Hardwood blocks, axe kept; recipes.json small_blocks_from_large). Move it into MAIN (W-01).
- L5 `craft:herb_omelette` (draft line 287): YES-WITH-UNTAUGHT-PREREQ. Egg and thyme sources not taught; the griddle is level 4.
- L5 `craft:herb_salve` (draft line 288): OK after a larger kill (animal fat).
- L5 `craft:hook` (draft line 289): OK after a kill (bone).
- L5 `craft:lamp_oil` (draft line 290): YES-WITH-UNTAUGHT-PREREQ. Herring is a sea fish. The Campfire pot must hang over a lit small fire (server_items.gd serving_station attach_to fire).
- L5 `craft:energy_bar` (draft line 291): problem. Honeyspindle nectar has no taught source (pass2_report.txt: 12 goals) (raw source per acquisition workstream).
- L5 `craft:feast_roast` (draft line 292): OK after a larger kill (fat) plus herbs.
- L5 `craft:sling` (draft line 293): OK after a kill. 1 hide, 1 twine (a sling is a weapon, but needs a hide first).
- L5 `craft:toggle` (draft line 294): OK after a kill. 1 bone.
- L5 `craft:unbaked_apple_pie` (draft line 295): The station is OK (Food preparation table, MAIN 41). The inputs (flour from farming, meat, fat, honeyspindle, water and so on) come later than level 5 (raw source per acquisition workstream).
- L5 `craft:unbaked_chestnut_cakes` (draft line 296): Station OK (Food preparation table, MAIN 41). Inputs come later than level 5 (raw source per acquisition workstream).
- L5 `craft:unbaked_fish_pie` (draft line 297): Station OK (Food preparation table, MAIN 41). Inputs come later than level 5 (raw source per acquisition workstream).
- L5 `craft:unbaked_flatbread` (draft line 298): Station OK (Food preparation table, MAIN 41). Inputs come later than level 5 (raw source per acquisition workstream).
- L5 `craft:unbaked_garlic_flatbread` (draft line 299): Station OK (Food preparation table, MAIN 41). Inputs come later than level 5 (raw source per acquisition workstream).
- L5 `craft:unbaked_honey_loaf` (draft line 300): Station OK (Food preparation table, MAIN 41). Inputs come later than level 5 (raw source per acquisition workstream).
- L5 `craft:unbaked_oatcakes` (draft line 301): Station OK (Food preparation table, MAIN 41). Inputs come later than level 5 (raw source per acquisition workstream).
- L5 `craft:unbaked_trail_bread` (draft line 302): Station OK (Food preparation table, MAIN 41). Inputs come later than level 5 (raw source per acquisition workstream).
- L5 `craft:unbaked_venison_pie` (draft line 303): Station OK (Food preparation table, MAIN 41). Inputs come later than level 5 (raw source per acquisition workstream).
- L5 `craft:uncooked_crab_cakes` (draft line 304): Station OK (Food preparation table, MAIN 41). Inputs come later than level 5 (raw source per acquisition workstream).
- L5 `craft:uncooked_meat_skewers` (draft line 305): Station OK (Food preparation table, MAIN 41). Inputs come later than level 5 (raw source per acquisition workstream).
- L5 `craft:uncooked_mushroom_skewers` (draft line 306): OK after MAIN 41. Mushrooms and wild garlic are forage (raw source per acquisition workstream).
- L5 `build:brick_garden_plot` (draft line 307): OK to build (hammer 1), but needs Clay mortar (MAIN draft line 96: 2 sand, 1 clay) and/or Cobblestone or Stone block (Workbench); level 5 understates it.
- L5 `build:stone_cistern` (draft line 308): NO. The blueprint is known false and locked (blueprints.json), and _can_blueprint refuses unknown rows (server_items.gd:8138-8139). Not achievable now.
- L5 `build:clay_pipe_run` (draft line 309): NO. Blueprint known false and locked (blueprints.json); refused by _can_blueprint (server_items.gd:8138-8139). Not achievable now.
- L5 `build:clay_pipe_elbow` (draft line 310): NO. Blueprint known false and locked; refused by _can_blueprint (server_items.gd:8138-8139). Not achievable now.
- L5 `build:clay_pipe_tee` (draft line 311): NO. Blueprint known false and locked; refused by _can_blueprint (server_items.gd:8138-8139). Not achievable now.
- L5 `build:fireplace` (draft line 312): OK to build (hammer 1), but needs Clay mortar (MAIN draft line 96) as well as brick and clay; level 5 understates it.
- L5 `build:hide_rug` (draft line 313): OK after kills. 3 hide, 1 sinew (rabbits give no sinew; carcass.json).
- L5 `build:hide_sack` (draft line 314): OK after kills. 2 hide, 1 twine.
- L5 `build:root_cellar` (draft line 315): OK to build (hammer 1), but needs Clay mortar (MAIN draft line 96) and Stone blocks (Workbench); level 5 understates it.
- L5 `build:stone_bench` (draft line 316): OK to build (hammer 1), but needs Clay mortar (MAIN draft line 96) and Cobblestone (Workbench); level 5 understates it.
- L5 `build:stone_brazier` (draft line 317): OK to build (hammer 1), but needs Clay mortar and Cobblestone; level 5 understates it.
- L5 `build:stone_channel` (draft line 318): NO. Blueprint known false and locked; refused by _can_blueprint (server_items.gd:8138-8139). Not achievable now.
- L5 `build:stone_channel_corner` (draft line 319): NO. Blueprint known false and locked; refused by _can_blueprint (server_items.gd:8138-8139). Not achievable now.
- L5 `build:stone_channel_tee` (draft line 320): NO. Blueprint known false and locked; refused by _can_blueprint (server_items.gd:8138-8139). Not achievable now.
- L5 `build:stone_garden_plot` (draft line 321): OK to build (hammer 1), but needs Clay mortar and Cobblestone; level 5 understates it.
- L5 `build:stone_planter` (draft line 322): OK to build (hammer 1), but needs Clay mortar and Cobblestone; level 5 understates it.
- L5 `build:stone_trough` (draft line 323): NO. Blueprint known false and locked; refused by _can_blueprint (server_items.gd:8138-8139). Not achievable now.
- L5 `build:stone_arched_doorway` (draft line 324): OK to build (hammer 1), but needs Clay mortar and Stone blocks; level 5 understates it.
- L5 `build:stone_doorway` (draft line 325): OK to build (hammer 1), but needs Clay mortar and Stone blocks; level 5 understates it.
- L5 `build:stone_double_arched_doorway` (draft line 326): OK to build (hammer 1), but needs Clay mortar and Stone blocks; level 5 understates it.
- L5 `build:stone_double_doorway` (draft line 327): OK to build (hammer 1), but needs Clay mortar and Stone blocks; level 5 understates it.
- L5 `build:stone_pillar` (draft line 328): OK to build (hammer 1), but needs Clay mortar and Cobblestone; level 5 understates it.
- L5 `build:stone_stairs` (draft line 329): OK to build (hammer 1), but needs Clay mortar and Cobblestone; level 5 understates it.
- L5 `build:stone_wall` (draft line 330): OK to build (hammer 1), but needs Clay mortar and Stone blocks; level 5 understates it.
- L5 `build:stone_window` (draft line 331): OK to build (hammer 1), but needs Clay mortar and Stone blocks; level 5 understates it.
- L5 `build:brick_arched_doorway` (draft line 332): OK to build (hammer 1), but needs Clay mortar (MAIN draft line 96) as well as brick; level 5 understates it.
- L5 `build:brick_doorway` (draft line 333): OK to build (hammer 1), but needs Clay mortar as well as brick; level 5 understates it.
- L5 `build:brick_double_arched_doorway` (draft line 334): OK to build (hammer 1), but needs Clay mortar as well as brick; level 5 understates it.
- L5 `build:brick_double_doorway` (draft line 335): OK to build (hammer 1), but needs Clay mortar as well as brick; level 5 understates it.
- L5 `build:brick_fence` (draft line 336): OK to build (hammer 1), but needs Clay mortar as well as brick; level 5 understates it.
- L5 `build:brick_pillar` (draft line 337): OK to build (hammer 1), but needs Clay mortar as well as brick; level 5 understates it.
- L5 `build:brick_stairs` (draft line 338): OK to build (hammer 1), but needs Clay mortar as well as brick; level 5 understates it.
- L5 `build:brick_wall` (draft line 339): OK to build (hammer 1), but needs Clay mortar as well as brick; level 5 understates it.
- L5 `build:brick_window` (draft line 340): OK to build (hammer 1), but needs Clay mortar as well as brick; level 5 understates it.

## Verified vs not verified

- Verified by reading (CODE_VERIFIED): every server, placement and data rule cited above.
- AUTOMATED_TESTED by relay (David4 run at dc2fa52, not run by me):
  - Hammer via `small_blocks_from_large`: test_mission001_walkthrough step 1e, test lines 482-484.
  - Lean-to cost: step 1f.
  - Campfire pot refused on a bonfire or a fire holding logs: test_campfire_pot.gd:166-172.
  - Goal events for drink, fell, fire, lean-to and workbench: test_goals.
- Not verified:
  - The bed client/server ghost mismatch (W-09).
  - What happens to a laid fire after 1800 s (W-12).
  - Whether gather:log, gather:log_oak, craft:firewood and the activity goals have completion events (per runtime workstream).
  - Every raw-material source (per acquisition workstream).
  - Nothing was played in Godot.
