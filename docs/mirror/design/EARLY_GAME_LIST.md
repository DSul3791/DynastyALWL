# Early game: one smooth list (24 Oct 2026)
Source: EARLY_GAME_FLOW.md v5 (sections 2.4, 4, 5, 6). Design only, nothing built.
Combine plan: Don't Starve + The Forest front door, Minecraft one-goal, Rust ladder in Valheim order, Valheim Rested/Comfort, Dragonwilds skills-by-use and shore net.

## First hour (R1)
1. Wake on flat ground at spawn with an empty pack. Stick and stone within 5 m. Voice hints on. (Needs: new-player switch for testing.)
2. Pick up stones, sticks, plant fibre (E; auto pickup is off by default).
3. Twine from fibre, by hand (3 fibre = 1 twine). Fibre and thatch both come from picking grass clumps and similar plants.
4. Stone axe, the FIRST TOOL (Dave): 1 stone + 1 stick + 5 twine (15 fibre). Log = 4 wooden blocks.
5. Fire, three sizes by wood (Dave 24 Oct). One campfire; its size follows the wood in it. All times are game time.
   - Tiny survival fire: sticks (and kindling/driftwood), 15 min each. Least light and heat. Needs only rocks, sticks and dry tinder (plant fibre).
   - Campfire: firewood, about 1 h each.
   - Bonfire: logs, hours each. Biggest light and heat.
   - Biggest wood burns first. With logs, firewood and sticks it starts as a bonfire.
   - Need at least 3 pieces of a wood to reach its size. Once burning it holds that size until the last piece of that wood is gone, then drops one size.
   - Fire in under 15 real min. Rain slows or fails it.
6. Sit by the fire under a tree. Canopy = rain/sun cover only; warmth is fire and clothes.
7. Spear, the FIRST WEAPON (Dave): 1 stick + 1 rock; the rock sharpens the stick. Upgrade to a stone spear with 5 twine and the same rock.
8. Drink and forage: water first, then berries, roots, herbs. Eat unknown things once; in R1 sickness costs food and water only, never health. Berries are season-only.
9. Fish with a shore net (20 twine + 4 stones, made by hand; the bench only makes better nets) at dawn/dusk. Sea is ~900 m away.
10. First shelter: lean-to (exists). Walls come later, as pieces, from thatch.
11. Thatch is everywhere (Dave 24 Oct): a new tall grass clump plant grows in patches across all grassy areas and is picked for thatch (2-4 per pick); felled trees give bark that is thatch; more sources per biome added as we go. (New plant and gather rules to build.)
12. Build pieces, not rooms (Dave): foundation, wall pieces, roof pieces, placed one at a time (blueprint or direct). No cheap 'room' item. Groups of connected blueprints can be saved as a grand blueprint; the hammer menu has a blueprint maker that copies any building into a named blueprint you can place anywhere. Taking down a blueprint returns 100 percent. Thatch wall piece stays 20 twine, 50 thatch, 15 sticks.
13. Rough bed: ~10 thatch + 4 sticks + 2 twine, under any roof (a lean-to counts). Lie (Z), sleep, better rest.
14. Camp bench: handles, better nets, tool kits. Planks come from a sawmill (hand saw exists, needs an iron blade: R3), so the bench ladder says where it ends. No planks (sawmill only).
15. No stone pick (Dave). The stone axe breaks rock slowly and wears out. Hammer: first one is wood + wood + twine (weakest, poor durability, same job), then stone + wood + twine, then copper, bronze, iron, steel. No adze.
16. Cooking: tripod pot, then clay hearth. Food can be cooked on the tiny stick fire (Dave). Drying rack after.

## Later (R2)
17. Bow and arrows, hunting, butchering, hide, hide clothing, traps.

## Later (R3)
18. Metals (R3): copper and tin show up near running water and along mountain bases, following real vein lines, some protruding as visible outcrops; finding one hints at a vein up the mountain to mine. Then copper axe (copper pick maybe), bronze, iron, steel. Forge needs hide. Armour ladder. Cooking tiers 2-3.

## Then
19. Garden and decoration (flowers, small trees, fences, planters). Comfort raises Rested bonus.
20. Homestead / barn. Taming, trapping, beginner towns are out of scope.

## Rules that hold all the way
- One obvious next thing, never more than ~2 min from a useful action.
- Nothing needs a table until the camp bench.
- Failure says why in one line (inner voice). The inner voice has its own settings panel: hints on/off and inner dialogue on/off (perception warnings, jokes, 'that was a good day').
- Weaker tool cannot break harder material (wood < stone < bronze < iron).
- No dead ends: every item is used later.
- Death is gentle, no permadeath.

## Spawn rule (Dave 24 Oct)
Nothing is ever placed because it is close to spawn. When the world is settled, we pick a spawn point that is near the needed resources. The distances below are input for choosing it.

## Measured from the current spawn (Mike, about 10 m)
- Near, fine: river water 93 m SW; clay 91 m N; birch bark 73 m NE; wild mint at spawn.
- Medium: lake 361 m SE; sea 851 m W.
- Over 300 m, ONE REAL GAP: hard stone outcrop 450 m E (stony soil 445 m SE). Reeds 615 m NW no longer matter: thatch is everywhere (step 12).
- Drinking water is everywhere there is water (Dave), not a gap.
- Fish: cannot be read from the tile.

## Added after Tyler's review
- Tinder for the fire is plant fibre, which should be at the chosen spawn.
- Step 10: the spawn point should be near fishable water. Thatch is closed (step 12).
- R1 comfort items so comfort can be measured: rug, table, planter.
- R2/R3 steps must name the animals near the chosen spawn and that hide leads to the forge.
- Steps that already follow the principles: 1, 3, 5, 7, 8, 11, 17.
- Order: fire and twine within 15 min, axes by 30 min, shelter next.
- Add a torch (fire + stick) before dusk, and a first storage (stick-and-bark basket) for pack weight.
- Cold/warmth drives steps 6-7 but is design only: build the warmth vital first or drop cold from R1.
- Mike's probe is done (see Measured). Hard stone and fish are NOT fixed by placing them near spawn: they decide where the spawn point goes.
- Hide (forge) needs hunting: R2 must say which animals live near the chosen spawn.
- Fire code today: one strength only; fuel adds time (stick 5 real s, firewood 75 s, log 5 min). Dave's sizes need a strength per fuel and burn times stick 15 min, firewood 1 h, log hours (game time); today stick is 2 game min, firewood 30, log 2 h.

## Needs code changes (Sal checked, 24 Oct)
- Stone axe today = 2 stone + stick, no twine. Change to 1 stone + 1 stick + 5 twine.
- Wooden spear matches Dave's rule (1 stick + rock).
- Stone spear is built from scratch today. Change to an upgrade of the wooden spear: spear + 5 twine + the same rock.
- Hammer recipes: wooden hammer = wood + wood + twine, then stone, copper, bronze, iron, steel; adze removed from the game.

## Dave's QA answers (24 Oct)
Yes: new-player switch, fire lighting in dry weather, shore net, rough bed, respawn at bed, cooking stations, build both ways, release stages, 3 pieces per fire size, food cooks on the tiny fire, thatch sources go.
No/changed: no rooms (pieces and grand blueprints); no stone pick; no adze; wooden hammer first; blueprint takedown 100 percent; inner voice has its own settings; copper/tin placed by real ore lines.

## Gaps to close before R1
- Fire sizes (tiny/camp/bonfire: light, heat numbers; 3-piece rule; per-wood burn times); new-player test switch; stone axe recipe 1 stone + 1 stick + 5 twine; spear 1 stick + 1 rock and stone-spear upgrade (5 twine + same rock); fire-lighting step; tall grass clump plant and thatch gather rules (grass patches, tree bark); thatch wall and rough bed recipes; bed quality and per-player respawn; hard stone near the chosen spawn (the stone axe now breaks rock slowly); shore net; fishable water near the chosen spawn.
