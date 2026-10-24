# Early game: guiding principles (24 Oct 2026, v2 after Tyler's review)
From the five-game research (Valheim, Minecraft, The Forest, ARK/Rust, Don't Starve, plus Dragonwilds) and Dave's vision. EARLY_GAME_LIST.md is ONE way to follow these; if a step changes, the principles stay.
Marks: [BUILT] works in the game today. [NOT BUILT] design only. [PART] some exists. Each principle has a TEST (a number or a check).

## Teaching
1. **One obvious next goal.** Never more than ~2 minutes without a useful action. (Minecraft) TEST: Mike's stopwatch, no gap over 2 min. [PART]
2. **Learn by doing.** Pick up, try, combine by hand. Failure says why in one line. (Forest, Don't Starve) [BUILT: hand combines, failure lines]
3. **Show what's missing.** Buildings show a blueprint ghost; crafted items show the missing parts in the crafting screen (no ghost item). (Forest, Don't Starve) [PART: blueprints only]
4. **The inner voice hints after a mistake. If the player does nothing for 60 s it gives one gentle up-front hint for that step.** Short, never an order, ends on the thing. The player can switch hints and inner dialogue on or off in settings. (Don't Starve, Forest) TEST: hint line count and length. [PART]
5. **Eat-once learning.** Try an unknown food once; harm teaches and is remembered. In the first hour unknown food costs food and water only, never health. (Forest) [PART]
6. **Night and weather teach.** First night must be survivable with a lean-to and a fire (a game day is 1 real hour, so dusk comes early). (Don't Starve, Minecraft) TEST: Mike plays the first night. [PART: cold design only]

## Progress
7. **Useful in the first minute, with no menu needed to reach the first action.** Something to pick up, tree and stone in reach. (Rust, Don't Starve) TEST: first pickup under 60 s. [PART]
8. **Every tier is one new thing to find.** The player knows what to go and get next. (Rust) [PART]
9. **Soft before hard.** Wood, stone, soft metal, then iron. (Valheim) [PART: copper/tin/bronze not built]
10. **A tool can't break harder material than itself.** (Minecraft, Dragonwilds) [PART]
11. **A tier is something you place.** Stations show progress in the yard. (Don't Starve, Dragonwilds) [BUILT: bench, racks]
12. **Tool ladder follows the materials.** Stone axe first, then copper, bronze, iron; no special pick tier. (Dave)
12b. **Skills grow from use.** No points, no trees. (Dragonwilds) [NOT BUILT]
13. **No dead ends.** Every item made is used later. TEST: run item_master, list items no recipe uses; fail if any in R1. [PART]

## Survival and home
14. **Start with rocks and sticks; better materials give a bigger result.** Fire size follows the wood: sticks = tiny survival fire (15 min each), firewood = campfire (about 1 h each), logs = bonfire (hours each), game time. Biggest wood burns first; 3 pieces needed to reach a size; it holds that size until the last piece is gone, then drops one size. (Dave) [NOT BUILT: fire has one strength today]
15. **Fire is warmth, light, safety and cooking in one.** (Don't Starve, Forest) [PART: warmth system exists]
16. **Water is a need as well as food.** Drink from streams or deep water; drinking water is everywhere there is water (Dave). The spawn point is chosen near water. TEST: Mike probes distance. [PART]
17. **Home pays you back.** Roof + fire + bed give warmth, safety, rest, comfort bonus. (Valheim Rested/Comfort, Minecraft bed) [NOT BUILT: bed item, comfort bonus]
18. **A visible shelter ladder.** Lean-to, thatch hut, built room. (Forest, Valheim) [PART]
19. **Building shows what holds.** Integrity colours. (Valheim) [NOT BUILT]
20. **Build rules are simple and shared.** One tier rule, collapse timers, both build routes cost the same. (Rust) [PART]

## Feel
21. **Fun, simple, obvious.** Realistic and hands-on, not a grind; ARK/Rust PvP stress rejected. (Dave) TEST: first fire under 15 min, roofed bed under 90 min, plus Dave's own play.
22. **Death is gentle, and your line continues.** Full rules already decided in DESIGN_IDEAS.md 6.1 and items/DEATH_RESPAWN_DESIGN.md; this early game follows them, it does not redefine them. In short: your pack stays in remains on the spot (only you for day 1, anyone from day 2, cleaned up at day 8); you respawn as a new character keeping luck, fitness, skills and placed things; heir/child restart inheriting everything is the family system (not built). No permadeath. [PART: remains and respawn BUILT; heir, last-shelter spawn NOT BUILT]
23. **Easy floor, deep ceiling.** Casual players are never forced to craft: other players can craft for you (trade). Crafters get depth. (No shops or hired crafters exist.)
24. **Fishing starts simple.** Shore net first, rod later. (Dragonwilds, Forest) [NOT BUILT]
25. **Fast on the weakest PC.** First hour holds 60 fps, since the MMO shares the spawn. TEST: frame rate at spawn. 
26. **More than one way to get each key material.** Thatch comes from bark, a pickable tall grass in patches, and reeds; stone, fibre and wood the same. No single plant is a bottleneck. (Dave) [NOT BUILT: thatch gather rules]
27. **A crowded spawn still works.** Stones, sticks, thatch regrow or scatter so the nth player finds them. TEST: set a regrowth rate before launch. [NOT BUILT]
28. **Nothing divisive.** Safe for everyone.

## Decided (principles may not contradict)
- We place pieces, not rooms. Connected blueprints save as a grand blueprint; hammer blueprint maker copies a building. Blueprint takedown returns 100 percent. (Dave 24 Oct)
- No stone pick and no adze. Stone axe breaks rock slowly and wears out. Hammer ladder: wood+wood+twine, stone, copper, bronze, iron, steel. Copper/tin follow real ore lines near running water and mountain bases. (Dave 24 Oct)
- Inner voice has its own settings panel: hints on/off, inner dialogue on/off. (Dave 24 Oct)
- Food can be cooked on the tiny stick fire; a fire tier needs 3 pieces of that wood. (Dave 24 Oct)
- Nothing is ever placed because it is close to spawn. When the world is settled we pick a spawn point near the needed resources (stone, thatch grass, fish, bark, water). Dave 24 Oct.
- Wood chain: log + axe = 4 wooden blocks; trees under 8 ft are firewood/sticks by hand; no planks without a sawmill.
- Canopy is rain/sun cover only; warmth is fire and clothes.
- Basic wall 20 twine, 50 thatch, 15 sticks (not built); blueprint rules as set by Tyler.
- No hand axe (Dave 24 Oct). First tool = stone axe: 1 stone + 1 stick + 5 twine. First weapon = spear: 1 stick + 1 rock; stone spear = spear + 5 twine + same rock. Fibre and thatch come from picking grass clumps and similar plants.
- Pick-up: auto pickup is OFF by default (P key).
- Fire sizes and burn rules as in principle 14 (Dave 24 Oct).
- Cold hurts slowly, health floor 1.

- Death and heirs: as in DEATH_RESPAWN_DESIGN.md / DESIGN_IDEAS.md 6.1 (remains day 1 owner only, day 2 anyone, gone day 8).

## Tools, not principles
- "Become a new player" switch for testers (empty pack, hints on).
