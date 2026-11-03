# Dave's play-test: one page (refreshed 3 Nov early, on main; pull the current head of `main`)

The long version with every row and note is `MORNING_PLAYTEST_CHECKLIST_FULL.md`. Tick as you go; anything wrong goes on a QA page card (the Comments box), or in chat. Numbers re-checked against data on main, 3 Nov.

## Before you start
1. **Pull** `main` (there is no daily branch any more, Dave 2 Nov) and open the project in Godot.
2. **Start:** open `scenes/launcher.tscn` and press **F6**. The game starts its own server and joins it (port 24600; if that port is busy it joins the server already running). The `--test` launch flag skips character select and the creator.
3. First screen is **character select**. No character yet: you land in the **creator**: type a name, press **Save and play**.

## New since the last pass (merged 2 Nov; none of it seen by a person yet)
- **Fire store (F):** F at a fire opens its store; the wood in it is what burns (stick 2 min, firewood 20 min, log 3 h, no total cap). **E lights a fire, and E on a burning fire puts it out.** Hold E on an unlit fire picks it up. Raw meat put in the store cooks while it burns (no hold-E roasting). 3 logs make the large fire and it **stays large until those logs are gone**. Firewood pieces look 60 percent bigger.
- **Felled trees:** about 2 s after landing the tree breaks up by itself into logs, sticks, leaves, bark, seeds and a root ball, and keeps the size it had standing. The hint reads "Your tree is down. Gather what fell: sticks, leaves, bark and logs."
- **Chopping block:** tap E splits, hold E picks it up; the firewood pile beside it grows.
- **Temperature bar** replaces Warmth (degrees; C/F under Settings > Gameplay).
- **Heavy things are hammer blueprints**, not kits (9 heavy kits retired; the first-hour kits are unchanged). A day of picking now pays about a meal and a bed.
- **Bushes:** the axe chops them up, a pickaxe digs one up to replant. Tall grass also gives oat and rye seeds.
- **Feel:** a landing dip, a camera jolt on tool blows, hit chips, floating damage numbers (Gameplay toggle).
- **Lag work:** many frame-time fixes, a lower-priority server and a "HITCH" log line for frames over 100 ms. Shift+F3 lists every playing sound with a mute switch.
- **Hoe road builder**, ocean swimming over any bed below 0 m, a palm belt at the beach, rivers drawn as one ribbon.
- **First-person arms** smoother and set wider (bug 4, still being tuned).

## The first 10 minutes (what you should see)
1. [ ] **Join.** Wait: the window may freeze for about 15 seconds (known). Then you stand in a summer forest meadow by a pond, spawn 53316, 68476, ground dry.
2. [ ] **Look around.** Big trees, ferns, tall grass, flowers. Press **Tab**: bars for Health, Food, Water, Temperature (degrees), Energy.
3. [ ] **Drink.** Walk to the water, press **E**.
4. [ ] **Sticks and stones.** Tap **E** on loose sticks and stones; **hold E** to sweep everything within 2 m.
5. [ ] **Nettles.** **E** on a nettle gives plant fibre **and** nettle leaves (new).
6. [ ] **Twine.** **I**, type "twine" in the search box (or pick it in the list), Craft: 3 fibre make 1 twine.
7. [ ] **Stone axe** (1 stone, 1 stick, 2 twine, 10 s). Put it on the hotbar and hold it (press its number).
8. [ ] **Fell a tree.** Click again and again (about 10 blows for a 1 m trunk, fewer for a thin one, 20 or more for a giant; see docs/handoff/DINO_BUG_CHECKS.md). About 2 seconds after it lands (2 Nov, bug 11 fix and #49, not yet seen in a client) the trunk breaks into its logs by itself, lying where it fell, and also drops what hand-cutting gives (sticks, leaves, bark or thatch, seeds, root ball): pick them up with E (a log goes on your shoulder). A trunk you started cutting, or one with no room around it, stays a trunk to cut by hand. Q puts the shoulder log down. A stump still in the ground can be chopped too: it is destroyed and gives firewood and kindling (no log).
9. [ ] **Campfire** (6 sticks, 3 stones, 8 s). Hold the kit, click where the ring shows: yellow = open, green = under a tree. It must be within about 6 m of you.
10. [ ] **Light it and feed it** (changed 2 Nov, fire store): the laid fire already holds a stick. Press **F** at the fire to open its store and put wood in (sticks, firewood, logs stack without limit); the wood in the store is what burns, and closing it works out burn time and tier. Then stand close and press **E** to light it (spends 1 fibre; birch bark also works). **E on a burning fire puts it out** (wood kept). **Hold E** on a fire that is not burning picks it up again as a kit. Stick = 2 min, firewood = 20 min, log = 3 h (real time); 3+ firewood is the medium fire, 3+ logs the large.
11. [ ] **Cook:** you need raw meat, fish or shellfish. The campfire **only cooks meat**: berries and nuts are refused with a message (they go in a pot or on a hearth). Put raw meat in the fire's store (F) and it cooks while the fire burns (no hold-E roasting any more). A plant food at the fire shows a hint: press 6 clay into a Clay pot, lash it with 3 sticks and 3 twine.
12. [ ] **Lean-to** (32 sticks, 8 leaves, 4 twine, 25 s). Place it. You should be able to lie down inside it.
13. [ ] **Rough bed** (8 bedding from ferns, 4 sticks, 2 twine). Place it **inside** the lean-to, press **E on the bed** ("Spawn point set"), then **Z** to lie down and hold **Z** 3 s to sleep.
14. [ ] **Bench** (Camp bench: 16 sticks, 6 twine, 4 stones, 60 s), then **wooden spear** (1 stick, 6 s; the stone is kept, not used up), **stone spear** (wooden spear + 2 twine, 10 s) and **stone knife** (2 stones, 1 stick, 8 s).

## Known broken or not yet checked by a person (3 Nov; bug numbers from `docs/BUGS_FOUND_IN_PLAY.md`, checks in `docs/handoff/DINO_BUG_CHECKS.md`)
- **Still open:** 1 fire timer (now a sum of all fuel, #135: check it), 5 tree hits, 7 lag, 8 firewood tier, 10 jump animation.
- **Fixed, needs your check:** 2 and 3 chopping block and pile (#30), 9 logs in the fire (#32), 11 felled-tree size (#39), 6 the 2 s fell pause (#98, cutting still being timed).
- **In-game hints still say the old fire controls** ("Press E to add wood", "Hold E to roast") until Sal's PR #53 is merged; follow this page, not the hint. The Tab and cold hints still say "Warmth".
- Chest self-test fails (the chest itself is untested in the client).
- Creator preview should now face you (Kathreen's fix, QA card pic-creator-front).
- Lit-fire flames and felled-trunk bark: on QA cards, waiting for your answer.
- Not yet seen in a window: lying in the bed, the fire store by hand, a felled tree breaking up.

## Tell me
- **QA page cards** (one per picture: spawn character, lean-to and bed, creator preview): Yes or No, and say why in Comments.
- Anything that stopped you before step 14: say the step number and what happened.
- How long any freeze lasted (the F3 overlay's worst frame, or the HITCH lines in the log).
