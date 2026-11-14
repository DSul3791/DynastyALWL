# Progression repair: F6 play checklist (GOALS-REPAIR)

**Final for the mission.** Written against `dev` `55c5b2a` (every mission PR is in `dev`; the newest is #1128). Pull `dev`, press F6 and play. The client and the server must be on the same build: protocol 121. Every step is NEEDS PLAYER VERIFICATION. Tests have passed headless on David4 (391/391 on `55c5b2a`), but nothing has been seen in a running game, and the intermittent crash while joining seen in headless runs is fixed for its confirmed cause by #1132 (`dev` `0eeef4a`; strong evidence, not proof; windowed play not yet seen), so it is still watched (section 0 and section 9). Sections 1 to 7 are the mission. Section 8 is plumbing and gardening, which you added on 14 Nov around 06:30Z: they are outside the mission's completion criteria but need your play check too. The evidence for each item is in [PLAYER_PROGRESSION_REPAIR_VERIFICATION.md](PLAYER_PROGRESSION_REPAIR_VERIFICATION.md).

Play with **Admin mode off**. While Admin mode is on, goals count nothing. Start from a **new character with an empty pack**, in a fresh world: you planned to wipe characters, world edits and items before testing (06:18Z), and nothing pays catch-up for what was done before. That wipe is yours to do; the team does not touch live saves. Each line says what to do, then what you should see. Tick it, or note what you saw.

Values marked (A-n) are provisional. If one feels wrong, note the number you'd like.

## 0. Before you start

- [ ] **Admin keys** (do this in a spare world, or after the run: Ctrl+Shift+J moves you far away, and X, R and N dig, spawn and teleport). Plain G opens the Journal's Goals page; Ctrl+Shift+G toggles flying. Try Ctrl+Shift with F2, F3, F4, F5, F7, F8, =, -, ], N, R, X, L, J and P. Each works only with both Ctrl and Shift held. Check that = - ] work on your keyboard, and that the editor doesn't swallow F5 or F8.
- [ ] **Journal is empty for a new character.** J opens the Index, G opens Goals, M opens Map, and Esc closes. The Map page reads "Nothing mapped yet. Explore to fill this page." Opening the inventory closes the Journal, and the other way round.
- [ ] **Keys under a screen** (#1104). Open the inventory (I) or the character screen (Tab). Hold Space and Ctrl on the ground, in water and on a ladder; on a ladder also press W and S. Nothing should move you: no jump, rise, dive, climb or letting go. Space still wakes you if you are asleep with a screen open.
- [ ] **Goals box.** At the upper right, a thin cream border, the heading "Goals" and the first two unfinished goals. It sits clear of the Comfort and food lines and hides while any screen is open.
- [ ] **Note any crash while joining.** Join a few times. Headless test runs used to crash now and then while joining (1 of 3 in the final run). The confirmed cause is fixed by #1132 (20 of 20 test joins clean since), which is strong evidence but not proof, and windowed play has not been seen yet. If the game crashes or freezes at a join, note when, and save the log if you can. #1124 fixed one cause (trees); trees may finish setting up a moment later than before, with unchanged looks.

## 1. First minutes: gathering, tools, fire, shelter

- [ ] **Drink and eat.** Within about 10 s you can drink at water (E); eat a berry once you find a bush. The first goal completes, and the **Goal Achieved** placard spins in with the goal's name and the coins actually paid: **5 copper and no items** (#1121, coins only; the 28 live goals all pay 5, A-42). You hear the short generated fanfare, the same every time (06:18Z: "a sound people will grow to recognize"); the placard holds about 4 s and spins out. The game never pauses. Check the look and the sound.
- [ ] **Placard queue.** Do two goals at once if you can, for example two pickups. The placards come one after the other and never overlap.
- [ ] **Gather.** Pick up stones, sticks, plant fibre and thatch with E. Make twine from fibre, then a Stone Axe (1 stone, 1 stick, 2 twine). Put the axe on the hotbar.
- [ ] **Own-hand gathering** (06:20Z ruling, #1117). Picking, cutting and harvesting by your own hand counts toward gather goals: when a tree you felled breaks up, its crown sticks and leaves, its bark, seeds and roots, a sapling-sized tree's pieces and the kindling cut off a trunk with a pick all count. Things bought, traded, looted, taken from storage, or from a tree someone else felled do not. Twine no longer gives sticks, and felling no longer gives kindling, as rewards.
- [ ] **Fell an oak.** Repeated axe blows fell it into a trunk. The logs that come off are **3 m long**. Check the lying log, the shoulder log and the next-cut band. The plain Log mesh is still 1 m and is known. At the **first axe blow on an oak log, 3 Tannin Bark** drop, once per tree (A-2). Hitting the standing tree gives no bark.
- [ ] **Carry logs.** An oak log rides on the shoulder (45 kg). Q lays it down. Spruce is 32 kg, light woods 26, and the plain Log is 18.4 (A-25). Does carrying feel right?
- [ ] **Blocks and hammer.** The axe on a ground log gives large wooden blocks. Craft Small wooden blocks (1 large gives 4 small, keeps the axe), then a Wooden Hammer (small block, stick, twine) and a Chopping Block (1 large block).
- [ ] **Firewood.** E at the Chopping Block with the axe in hand splits firewood, one per press. F at the block chops from stored logs (12 firewood from a 3 m species log).
- [ ] **Fire sizes.** Make a campfire kit, place it, and light it with E (small). Add wood with F (the fire's store): three firewood make it medium, and three logs make a bonfire. Check that the flames and warmth grow with each size. Only the goal "Light a fire" shows today; the fire-size counts are server-side only, for the corrected catalog.
- [ ] **Charcoal.** Make charcoal at the lit fire from 2 firewood.
- [ ] **Shelter.** Build a Lean-to with the hammer (20 sticks, 60 leaves, 6 twine) and a Crude - Foundation. Try one placed short of materials and finished by pressing E to deposit the rest: its goal still completes.
- [ ] **Scots pine.** Fell a Scots pine and cut its logs. Pine Tar drops sometimes. Make Tar at a campfire from 5 Pine Tar.

## 2. Water, leather and farming

- [ ] **Fill a container.** Hold a bowl, pot, bucket or waterskin and press E at the water. Each press adds 500 mL.
- [ ] **Recipe water.** Craft something that needs Water, for example Leather at a tanning rack (processed hide + 2 Tannin Bark + 1 Water). The water comes out of your filled container (500 mL per Water, A-1), and the container stays. Salt or sea water never counts. Cancel a queued craft: the water goes back into the container.
- [ ] **Leather route.** Hunt for a Hide (it is also needed for the Improved smelter). Build a Drying rack (8 stick, 4 twine), a Tanning rack (6 log, 4 twine; heavy, several trips) and a Leatherworking table (4 log, 4 stick, 4 twine, 2 stone). Then: Scraped hide at the drying rack (keeps a Hide scraper) → Leather at the tanning rack → Leather strap at the table (keeps a Knife). The strap is needed for the Copper and Bronze axes.
- [ ] **Farming.** Till a bed with the hoe.
  - **Sow:** with a seed in hand, E shows "Press E to sow <seed>". A new world starts in **summer**, so seeds from wild radish or prickly lettuce sow and the grains, carrot and flax do not; the server says "Not the season for <crop>." (A-4, A-6).
  - **Water:** hold a filled container, then "Press E to water the <crop>" (up to 8 L, A-3, A-7).
  - **Harvest:** when ripe, "Press E to harvest the <crop>".
  - **Looks:** the crop stages show as coloured boxes, which are placeholders. Check that they grow.
  - **Save:** quit and rejoin. The crop is at the same stage.

## 3. Map

- [ ] **Exploring fills the map.** Walk a few hundred metres, then press M. A charcoal sketch shows only the ground within about 40 m of where you walked: hills hatched, contour lines, water and shore, tree scribbles. A small cross marks you. Everywhere else stays bare paper.
- [ ] **Page controls.** The mouse wheel zooms and dragging moves the page. Each opening starts on where you stand.
- [ ] **Big map opens smoothly.** After a long walk, open and close the Map a few times. It should not stutter, because blocks fill in one at a time while the page is open.
- [ ] **Low skill draws rough.** At low Mapping the lines are light and wobbly and the contours coarse. Raise Mapping by exploring new ground, then come back to an old area. It redraws steadier only after you **walk there again**, and only once Mapping is 3 levels above what it was when you drew it (practice is capped per day, so this takes a while); a skill gain alone changes nothing.
- [ ] **Nothing from caves, standing still or jumps.** Standing still, walking over known ground, being in a cave, or a teleport or respawn adds nothing.
- [ ] **Persistence and privacy.** Quit and rejoin: your map is still there. A second player sees only their own map.

## 4. Metal: copper to steel, smithy wear and repair, bins and fuel

- [ ] **Mine ore.** A Stone Pickaxe (3 stone, 2 stick, 2 twine) on ore outcrop boulders (not every boulder) gives copper ore, tin ore and coal. It does not give iron. **Iron ore** on these tiles comes from **bog iron**: dig wet lowland soil (bog, marsh) with a spade and now and then rust-red lumps come up with the peat ("bog iron", about 1 dig in 25). The iron boulders lie under the sea.
- [ ] **Primitive smelter** (bp 200: 24 clay, 10 stone).
  - **Build and load:** build it and press E to open its store. Coal or Charcoal goes in the fuel part; ore goes in the ore part, one kind per slot.
  - **Smelting:** it smelts by itself, one ingot every 20 s. 1 copper ore makes 1 copper ingot; 1 copper ore + 1 tin ore make 2 bronze.
  - **Output and fuel:** ingots drop **on the ground in front**, because it has no rack. They last 2 hours (A-11). It burns 1 fuel per ore (A-10).
  - **Iron:** iron ore is refused.
- [ ] **Primitive smithy** (bp 9: 24 stone, 10 clay, 2 log, A-8). It needs no metal to build. Make a **Copper pickaxe** (3 copper ingot, 2 stick) and a **Copper axe** (2 copper ingot, 1 stick, 1 leather strap) (A-13). Does copper feel worth making? It should be a bit better than stone and a bit worse than bronze (A-14). The copper pickaxe still does not mine iron. The tool looks are placeholders.
- [ ] **Bronze tools.** At the Primitive smithy: bronze hammer, pickaxe, axe, nails, hinges and so on.
- [ ] **Improved smelter** (bp 300: clay 24, stone 16, log 2, hide 3, bronze hinges 2, bronze nails 20; A-9).
  - **Capacity:** 40 fuel, 40 ore and an 80-ingot rack. F opens its store; E works the bellows.
  - **Bellows:** press E and stay beside it to work the bellows. It smelts 1.3 times faster.
  - **Iron:** iron ore (dug as bog iron, see Mine ore) smelts only while someone is working the bellows. Walk away and it pauses without losing time.
  - **Looks:** the look is a placeholder.
- [ ] **Improved smithy** (bp 10: stone 16, clay 10, log 4, bronze ingot 6, bronze nails 20, bronze hinges 2; A-15). It is built with no iron. It must be fired to craft: keep Coal or Charcoal in your pack and the first craft lights it (the Primitive smithy needs no fuel). Make Hinges from iron, and the **Iron anvil** (5 iron ingot + 1 log, A-16).
- [ ] **Advanced smelter** (bp 201: brick 40, stone 20, mortar 8, iron ingot 6).
  - **Wind:** its built-in windmill works it. In a calm (under 4 m/s, A-18) nothing smelts and every lane keeps its time; when the wind picks up it carries on.
  - **Two lanes:** it smelts two ingots at once, faster than the Improved smelter.
  - **Steel:** put iron ore in the input, and drag Coal or Charcoal **onto an input slot** as carbon (A-24). 1 iron ore + 1 carbon makes 1 Steel ingot (A-19). Fuel put in the plain way (F, or Store all) goes to the hopper and is burned as fuel, never as carbon. Iron ore with no carbon makes iron.
- [ ] **Advanced smithy** (bp 301: stone 24, clay 12, log 6, the Iron anvil, nails 30, hinges 4; A-20). It works every metal up to steel. Make the **Steel anvil** there (5 steel ingot + 1 log, A-21) and a steel tool.
- [ ] **Master smithy** (R5, #1106; bp 202, a Bronze or better hammer, tier 3).
  - **Cost:** brick 30, stone 20, log 6, iron ingot 10, and the Steel anvil made at the Advanced smithy.
  - **Tempered and +1/+2:** these are made here and only here.
  - **Waiting:** away from it, a queued variant says "Your +1 <item> waits: go back to the master smithy". Nothing is lost.
- [ ] **Smithy wear** (R5).
  - Every craft at a smithy wears it.
  - Iron or steel work on a bronze anvil wears it 3 times as fast (A-17).
  - Durability by anvil is stone 60, bronze 120, iron 240, steel 480 crafts (A-26).
  - At the limit the smithy stays standing. Crafting there, opening its store, or taking it down says exactly **"Needs repair"** (A-23).
- [ ] **Smithy repair** (R5).
  - Right-click the hammer menu, choose Repair, then left-click the smithy (A-41).
  - A War Hammer does nothing.
  - **Cost:** about half the blueprint cost, without the anvil (A-27).
  - **Sources:** it takes from the ground nearby, then nearby chests or bins, then your pack. It takes all or nothing, and never from the smithy's own store.
  - When short, it says what it needs.
  - After a repair the store, fire and contents are as they were.
  - **Save:** a broken smithy is still broken after quit and rejoin, and a repaired one stays repaired.
- [ ] **Resource bins** (R6, #1111).

  | Bin | Units | Lumber (Plank) | Nails |
  |---|---|---|---|
  | Small resource bin (was the open storage bin) | 1000 | 16 | 32 |
  | Medium resource bin | 5000 | 32 | 64 |
  | Large resource bin | 10000 | 64 | 128 |

  - Each holds **one** material at a time. A second kind is refused with a notice. A bin saved with mixed contents before R6 refuses new puts until emptied.
  - Stack to nearby fills them.
  - The surface inside rises as it fills and is gone when empty.
  - The looks are placeholders: plank walls and a plain coloured slab.
  - **Save:** a bin keeps its one material and amount across quit and rejoin. Nothing is lost or doubled.
- [ ] **Smithy firing from nearby stores** (R6).
  - Carry no fuel. Put Coal or Charcoal within 30 m, in a bin, a Kiln's output, or a laid but unlit fire.
  - The Improved smithy's first craft lights it from there (A-28).
  - With nothing near, the cold notice tells you where fuel can be.
- [ ] **Smelters pull fuel** (R6). Every 5 minutes (A-33), a smelter tops up its fuel hopper from those same stores within 30 m, nearest first. It never fills the ore or carbon input.
- [ ] **Laid fires** (R6). Drawing fuel from a laid fire never shortens it. A fire drawn empty keeps its time left (A-34).
- [ ] **Bellows goal event.** Working the bellows while an iron ingot is made counts the bellows goal once per stint (server side; the catalog is off).
- [ ] **The whole route.** The headless test `test_mission001_walkthrough` goes stone → copper → bronze → iron → steel with no metal spawned, builds the Master smithy at its cost, and stops the Advanced smelter in a calm. It passed at R5 and R6. It is a test, not a played route: please play the same route once.
- [ ] **Carry feel.** The Improved smithy needs about 101 kg of materials, and the Primitive smithy and the Improved smelter about 62 kg each, against your 52.5 kg carry. Place the blueprint and deposit in 2–3 trips with E. Is that fair?
- [ ] **Two players at one smelter.** A second player can't work the bellows while you do, but can take ore out. Logging out pauses the iron.
- [ ] **Save.** Quit mid-smelt and rejoin. Nothing in the store is lost or doubled, and the banked time carries on.

## 5. Tier roofs, corners and the new building pieces

- [ ] **Roof 45 and Roof 65 on every tier** (#1110, #1112; names confirmed by you 05:29Z). On two facing walls of every tier, Fortified included, place "<Tier> - Roof 45" and "<Tier> - Roof 65". Each rests on a wall top, a ceiling edge or another panel's end; the wheel flips rise and fall; there are no posts or legs, and two panels meet at a ridge. No plain "Roof" is left. Does a Roof 65 costing the same as its 45 feel right (A-35)? The Fortified pair costs the Engineered - Roof 45 plus 4 Iron band (A-39) and looks like darker Engineered tiles with two iron straps.
- [ ] **Roof corners at both slopes** (#1118, A-37). Place a corner where two wall tops meet. It follows the slope of the panel beside it; with none beside it, the wheel picks the slope. A second corner on the same spot is refused, and so is a 65 panel on a 45's edge. Save and reload keeps the slope. The new Fortified - Roof corner costs the Engineered corner plus 2 Iron band (A-40).
- [ ] **Roof panel hint** (#1107, GA-18). Place a wall, doorway or window: the roof panel hint appears, and the Controls list has the roof wheel row. The hint wording is provisional.
- [ ] **The six new pieces** (#1113, A-40). Build Fortified - Window (10 Concrete, 4 Iron band), Fortified - Ceiling (14 Concrete, 2 Plank, 4 Iron band), Fortified - Stairs (17 Concrete, 4 Iron band), Fortified - Fence (9 Concrete, 2 Iron band), Engineered - Fence (7 Concrete) and Engineered - Gate (4 Concrete, 3 Plank, 2 Hinges; it opens and shuts with E). Each should snap like its Engineered (or Superior) counterpart.
- [ ] **Old roofs and corners.** A tier roof or corner saved before #1110 or #1118 reloads in the wrong place (roofs sit low as 45 panels; corners are hips at foundation height). Take it down (you get the refund) and build it again. A fresh world has none.
- [ ] **Refunds.** Taking a piece down refunds a group cost (nails, hinges) as the group's lowest member, so iron Hinges come back as Bronze hinges. That is existing behaviour; say if you want it changed.
- **Icons:** the tier roofs, the 65s, the corners and the six pieces need a re-render on a PC (the cloud cannot render them); until then some show old gables or no icon.

## 6. Doors and Crude roofs (from the earlier bug lists)

The full lists are `/mnt/project-files/buglist-002/F6_CHECKLIST.md` (doors) and `/mnt/project-files/buglist-001/F6_CHECKLIST.md` (roofs and placement). The essentials:

- [ ] **Doorways and doors.** Place an empty doorway of a few tiers and walk through it. Hang a separately made door: it snaps into the frame, opens and shuts with E, and a second player sees the same. A wrong shape is refused with the reason. Each tier should look as you designed it.
- [ ] **Roofs.** On two facing Crude walls, place Crude - Roof 45 and Roof 65. A sloped panel rises from the wall top, the wheel flips it, and two panels meet at a ridge.
- [ ] **Save.** Open and shut doors stay as you left them after a rejoin.

## 7. Goals overall

- [ ] **Any order.** Do a later goal before an earlier one. It still completes and pays once.
- [ ] **No replays.** Quit and rejoin: no old placards replay, and nothing pays twice.
- [ ] **Goals page.** On the Goals page (G), click a goal to see its How to, reward, Learn first and Leads to; links jump to those goals, and Back returns. Clicking only changes what you see. The list scrolls to the selected goal.
- [ ] **Window sizes.** Check the Journal and the Goals box at a small and a large window size.
- [ ] **Coins only** (#1121). Every live goal pays coins and no items. The amounts follow one stage table (start 5, copper and bronze 10, iron 15, steel 20 copper, A-42); the live goals are all at the start.
- [ ] **Store All.** With the inventory open, plain G is still Store All.

- [ ] **New goal events, server side** (#1125). Cooking a roast on a campfire, tilling, sowing, harvesting, replanting a bush, setting a snare, sharpening, repairing a tool, a building piece or a smithy, sleeping a night, storing in a chest or crate, locking one, hauling a crate on a handcart, buying from Hob, a matured jar, a served platter, a meal effect, wedging a torch, foraging new plants, catching new kinds of fish, mining ore, tempering and making a +1/+2 item each count in the character's goal counters. They do nothing you can see yet: the corrected catalog is off.

The corrected catalog (704 rows, of them the 651 draft goals) is **not live yet**. You said it stays off while it is audited and reworked (06:41Z); it goes in only on your word. Its open points are in the verification report, section 6.

## 8. Follow-on work you added (14 Nov, around 06:30Z): gardening and wells

These are outside the mission's completion criteria. They passed headless on David4 but need your play check. The values are G-n (`docs/design/HOE_GARDENING_DESIGN.md`) and P-n (`docs/design/PLUMBING_DESIGN.md`), all provisional.

- [ ] **Hoe Garden mode** (#1119). Hold the hoe, right-click, choose Garden. The list shows seeds, bushes and tree seeds in pack order, with counts (G-3). Pick wheat seeds and click open ground: it tills a bed and sows it in one click (G-1). Pick a dug-up bush and click open ground: it plants.
- [ ] **Levelling** (#1119, G-2). Hold Smooth on a slope: the ground within 3 m levels to the height under your feet, stronger than before. On a foundation, it levels to just below your feet (0.1 m). Strokes add up and stop once level.
- [ ] **Plots** (#1123). The hoe makes no plots (your ruling, 14 Nov): plots are built with the hammer (Small, Medium and Large gardening plots). A Medium plot takes 4 crops and a Large 9: E sows the next empty square metre, and each shows its own crop.
- [ ] **Hoe grid: Till a garden** (your spec, 14 Nov). Hold the hoe, right-click, choose Till a garden. Green markers show the beds; Alt + arrow keys size the grid (up to 10 by 10), the wheel turns it. On ground that rises or falls more than 1 m from its average the markers go red and a click says why. On gentler ground a click levels the marked area to its average, blends the ground 2 m outside it back to the slope, then tills every bed. Tilled soil should look dark, rich and furrowed (placeholder look: NEEDS PLAYER VERIFICATION). Walk 20 m away mid-job: it stops and says how many beds it made. A wall or foundation beside the garden is not dug under.
- [ ] **Hoe grid: Plant something.** Choose Plant something, pick seeds from the list, and the same grid places them 1 m apart (bushes 2 m, tree seeds 3 m). Turned to match a turned garden, the seeds land in its beds. Points out of reach plant as you walk past them. Harvest a ripe garden crop by hand: about one in five gives a Worm.
- [ ] **Tree seeds** (#1123). Fell a tree: 1 to 5 of its seeds land as a heap in its crown (G-11). Every tree, the fantasy trees too, drops its own "<Tree> seed" (English oak seed, Mirrorbark seed; your ruling, #1134; names G-9). Plant one in open ground: it grows as a sapling. Acorns and other fruit are food, not seeds. Herb and plant seeds come in their own change. The open points are listed in `docs/design/HOE_GARDENING_DESIGN.md`, "For Dave".
- [ ] **Wells** (#1120). Build a Primitive - Well (8 Log, 4 Twine, 1 Clay - Pot), an Improved - Well (the old Well: 30 Cobblestone, 8 Clay mortar, 4 Plank, 1 Rope, 1 Bucket) and an Advanced - Well (60 Cobblestone, 16 Clay mortar, 12 Plank, 4 Log, 16 Bark shingle, 2 Rope, 2 Bucket). Draw water with E. They give about 100, 200 and 600 L a day (P-2) and reach 6, 25 and 40 m down (P-3). A dry well says "The well is drawn dry. It fills again through the day." It fills again over one game day (one real hour). Save and rejoin keeps its water. The models and icons have not been looked at.
- [ ] **Well goals** (P-6). The goal "Build Improved - Well" keeps its old id. New goals "Build Primitive - Well" and "Build Advanced - Well" are in the corrected catalog for your review (it stays off).

## 9. Known limits (not defects)

- A tree's feller and a kiln's lighter are not saved. A trunk that splits, or a kiln batch that finishes, after a server restart or while that player is offline credits no one.
- **Join crash (headless test runs): fixed for the confirmed cause by #1132** (`dev` `0eeef4a`; strong evidence, not proof; windowed play unseen; Voxel Tools threads unchecked). Lane: 20 of 20 smokes clean after the fix, against 14 of 58 with RID or null-mesh lines and 2 crashes before (the final run on `55c5b2a` crashed once in 3). It was older than the mission. Note any crash while joining.
- The game still crashes on quit in headless test runs (exit 134); that is older and known.
