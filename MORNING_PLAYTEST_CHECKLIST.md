# Dave's play-test: one page (daily branch 3494d612, 31 Oct)

The long version with every row and note is `MORNING_PLAYTEST_CHECKLIST_FULL.md`. Tick as you go; anything wrong goes on a QA page card (the Comments box), or in chat.

## Before you start
1. **Pull** the daily branch `DailyDev_20261029` (head `3494d612`) and open the project in Godot.
2. **Start:** open `scenes/launcher.tscn` and press **F6**. The game starts its own server and joins it (port 24600; if that port is busy it joins the server already running).
3. First screen is **character select**. No character yet: you land in the **creator**: type a name, press **Save and play**.

## The first 10 minutes (what you should see)
1. [ ] **Join.** Wait: the window may freeze for about 15 seconds (known). Then you stand in a summer forest meadow by a pond, spawn 53316, 68476, ground dry.
2. [ ] **Look around.** Big trees, ferns, tall grass, flowers. Press **Tab**: bars for Health, Food, Water, Warmth, Energy.
3. [ ] **Drink.** Walk to the water, press **E**.
4. [ ] **Sticks and stones.** Tap **E** on loose sticks and stones; **hold E** to sweep everything within 2 m.
5. [ ] **Nettles.** **E** on a nettle gives plant fibre **and** nettle leaves (new).
6. [ ] **Twine.** **I**, pick Twine, Craft: 3 fibre make 1 twine.
7. [ ] **Stone axe** (1 stone, 1 stick, 2 twine, 10 s). Put it on the hotbar and hold it (press its number).
8. [ ] **Fell a tree.** Click again and again (about 10 blows for a thin tree). Then keep striking the trunk: branches (sticks, leaves), then logs on your shoulder.
9. [ ] **Campfire** (6 sticks, 3 stones, 8 s). Hold the kit, click where the ring shows: yellow = open, green = under a tree. It must be within about 6 m of you.
10. [ ] **Light it:** stand close, **E** (spends 1 fibre; birch bark also works). Feed it with **E** (sticks, firewood, logs).
11. [ ] **Cook:** you need raw meat, fish or shellfish. The campfire **only cooks meat**: berries and nuts are refused with a message (they go in a pot or on a hearth).
12. [ ] **Lean-to** (32 sticks, 8 leaves, 4 twine, 25 s). Place it. You should be able to lie down inside it.
13. [ ] **Rough bed** (8 bedding from ferns, 4 sticks, 2 twine). Place it **inside** the lean-to, press **E on the bed** ("Spawn point set"), then **Z** to lie down and hold **Z** 3 s to sleep.
14. [ ] **Bench** (Camp bench: 16 sticks, 6 twine, 4 stones, 60 s), then spear (1 stick, 2 twine) and knife (2 stones, 1 stick).

## Known broken (do not report these again)
- Join freeze of about 15 seconds.
- Creator preview opens on the back of the body, plain colours.
- Chest self-test fails (the chest itself is untested in the client).
- Novice respawn card is pending.
- Water is still the old system (flat sea, no foam).
- Grey looks: chopping block and nettle tea. Kits look alike (56 kits, 19 looks).
- Not yet seen in the client by me: lying in the bed, the lit-fire picture, a felled log with bark.

## Tell me
- **QA page cards** (one per picture: spawn character, lean-to and bed, creator preview): Yes or No, and say why in Comments.
- Anything that stopped you before step 14: say the step number and what happened.
- How long the join freeze lasted.
