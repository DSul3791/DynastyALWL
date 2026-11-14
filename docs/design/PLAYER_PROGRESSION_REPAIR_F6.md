# Progression repair: F6 play checklist (GOALS-REPAIR)

**DRAFT, updated as work lands.** Written against `dev` `54b2c51c`. Pull `dev`, press F6 and play. The client and the server must be on the same build: protocol 120 now, and 121 once R4 lands. Every step is NEEDS PLAYER VERIFICATION. Tests have passed headless, but nothing has been seen in a running game. The evidence for each item is in [PLAYER_PROGRESSION_REPAIR_VERIFICATION.md](PLAYER_PROGRESSION_REPAIR_VERIFICATION.md).

Play with **Admin mode off**. While Admin mode is on, goals count nothing. Start from a **new character with an empty pack**. Each line says what to do, then what you should see. Tick it, or note what you saw.

Values marked (A-n) are provisional. If one feels wrong, note the number you'd like.

## 0. Before you start

- [ ] **Admin keys** (do this in a spare world, or after the run: Ctrl+Shift+J moves you far away, and X, R and N dig, spawn and teleport). Plain G opens the Journal's Goals page; Ctrl+Shift+G toggles flying. Try Ctrl+Shift with F2, F3, F4, F5, F7, F8, =, -, ], N, R, X, L, J and P. Each works only with both Ctrl and Shift held. Check that = - ] work on your keyboard, and that the editor doesn't swallow F5 or F8.
- [ ] **Journal is empty for a new character.** J opens the Index, G opens Goals, M opens Map, and Esc closes. The Map page reads "Nothing mapped yet. Explore to fill this page." Opening the inventory closes the Journal, and the other way round.
- [ ] **Goals box.** At the upper right, a thin cream border, the heading "Goals" and the first two unfinished goals. It sits clear of the Comfort and food lines and hides while any screen is open.

## 1. First minutes: gathering, tools, fire, shelter

- [ ] **Drink and eat.** Within about 10 s you can drink at water (E); eat a berry once you find a bush. The first goal completes, and the **Goal Achieved** placard spins in with the goal's name and the coins actually paid. You hear a short fanfare, it holds about 4 s and spins out. The game never pauses. Check the look and the sound.
- [ ] **Placard queue.** Do two goals at once if you can, for example two pickups. The placards come one after the other and never overlap.
- [ ] **Gather.** Pick up stones, sticks, plant fibre and thatch with E. Make twine from fibre, then a Stone Axe (1 stone, 1 stick, 2 twine). Put the axe on the hotbar.
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

## 4. Metal: copper, bronze, iron

- [ ] **Mine ore.** A Stone Pickaxe (3 stone, 2 stick, 2 twine) on ore outcrop boulders (not every boulder) gives copper ore, tin ore and coal. It does not give iron.
- [ ] **Primitive smelter** (bp 200: 24 clay, 10 stone).
  - **Build and load:** build it and press E to open its store. Coal or Charcoal goes in the fuel part; ore goes in the ore part, one kind per slot.
  - **Smelting:** it smelts by itself, one ingot every 20 s. 1 copper ore makes 1 copper ingot; 1 copper ore + 1 tin ore make 2 bronze.
  - **Output and fuel:** ingots drop **on the ground in front**, because it has no rack. They last 2 hours (A-11). It burns 1 fuel per ore (A-10).
  - **Iron:** iron ore is refused.
- [ ] **Primitive smithy** (bp 9: 24 stone, 10 clay, 2 log, A-8). It needs no metal to build. Make a **Copper pickaxe** (3 copper ingot, 2 stick) and a **Copper axe** (2 copper ingot, 1 stick, 1 leather strap) (A-13). Does copper feel worth making? It should be a bit better than stone and a bit worse than bronze (A-14). The copper pickaxe still does not mine iron. The tool looks are placeholders.
- [ ] **Bronze tools.** At the Primitive smithy: bronze hammer, pickaxe, axe, nails, hinges and so on.
- [ ] **Improved smelter** (bp 300: clay 24, stone 16, log 2, hide 3, bronze hinges 2, bronze nails 20; A-9).
  - **Capacity:** 40 fuel, 40 ore and an 80-ingot rack.
  - **Bellows:** press E and stay beside it to work the bellows. It smelts 1.3 times faster.
  - **Iron:** iron ore (mined with a Bronze pickaxe) smelts only while someone is working the bellows. Walk away and it pauses without losing time.
  - **Looks:** the look is a placeholder.
- [ ] **Improved smithy** (bp 10: stone 16, clay 10, log 4, bronze ingot 6, bronze nails 20, bronze hinges 2; A-15). It is built with no iron. It must be fired to craft: keep Coal or Charcoal in your pack and the first craft lights it (the Primitive smithy needs no fuel). Make Hinges from iron, and the **Iron anvil** (5 iron ingot + 1 log, A-16).
- [ ] **Carry feel.** The Improved smithy needs about 101 kg of materials, and the Primitive smithy and the Improved smelter about 62 kg each, against your 52.5 kg carry. Place the blueprint and deposit in 2–3 trips with E. Is that fair?
- [ ] **Two players at one smelter.** A second player can't work the bellows while you do, but can take ore out. Logging out pauses the iron.
- [ ] **Save.** Quit mid-smelt and rejoin. Nothing in the store is lost or doubled, and the banked time carries on.

## 5. Not in `dev` yet (to be added when they land)

- R4 (#1102): Advanced smelter (wind, two lanes, steel carbon dragged onto the input, A-18, A-19, A-24), Advanced smithy with the Iron anvil (A-20), Steel anvil (A-21).
- R5: Master smithy with the Steel anvil, smithy wear and "Needs repair", hammer repair (War Hammers excluded), Tempered steel (A-23, A-26, A-27).
- R6: Small, Medium and Large resource bins (one material, 1000/5000/10000), fuel pulls every 300 s from within 30 m (A-28 to A-34).
- Building tiers work.

## 6. Building, doors and roofs (already in `dev`)

The full lists are `/mnt/project-files/buglist-002/F6_CHECKLIST.md` (doors) and `/mnt/project-files/buglist-001/F6_CHECKLIST.md` (roofs and placement). The essentials:

- [ ] **Doorways and doors.** Place an empty doorway of a few tiers and walk through it. Hang a separately made door: it snaps into the frame, opens and shuts with E, and a second player sees the same. A wrong shape is refused with the reason. Each tier should look as you designed it.
- [ ] **Roofs.** On two facing Crude walls, place Crude - Roof 45 and Roof 65. A sloped panel rises from the wall top, the wheel flips it, and two panels meet at a ridge.
- [ ] **Save.** Open and shut doors stay as you left them after a rejoin.

## 7. Goals overall

- [ ] **Any order.** Do a later goal before an earlier one. It still completes and pays once.
- [ ] **No replays.** Quit and rejoin: no old placards replay, and nothing pays twice.
- [ ] **Goals page.** On the Goals page (G), click a goal to see its How to, reward, Learn first and Leads to; links jump to those goals, and Back returns. Clicking only changes what you see. The list scrolls to the selected goal.
- [ ] **Window sizes.** Check the Journal and the Goals box at a small and a large window size.
- [ ] **Store All.** With the inventory open, plain G is still Store All.

The corrected 651-goal catalog is **not live yet**. It waits for your decisions (verification report section 6).
