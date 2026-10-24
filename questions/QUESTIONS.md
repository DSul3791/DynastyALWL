












## sound-duck-vetted | Duck quacks and sand footsteps (build 752)
Note: 1. Start the game (MikeW has pulled the new build). 2. Esc > Settings > Sound test > creature calls > duck. Listen: does it sound like a real duck and is it quiet enough? 3. Walk and run on sand: is running only a little louder than walking?
Note: Recommendation: Yes after listening, because the duck clips are real recordings that passed the team check and the sand run is now only about 5 dB over walk, as you asked.
[test]

## look-new-tools | Can you craft the new tools? (build 787: stone hammer, hand saw, stone adze)
Note: 1. Pull build 787.
Note: 2. At a workbench craft a stone hammer, a hand saw and a stone adze.
Note: 3. Use the hand saw on a log: hand-sawn lumber recipe.
Note: 4. Yes if all three craft. The hammer and adze do nothing else yet; their descriptions say so.
[test]

## laptop-for-tests | Use your old laptop for tests (local_check, test_worldgen, sound tests, pictures) and keep all bakes on Mike's PC?
Note: Steps are in tech/LAPTOP_SETUP.md. First step is a 5-minute dxdiag check: 8 GB RAM, Vulkan GPU, 20 GB free disk.
Note: Recommendation: Yes: bakes never wait for tests, and the laptop's frame times are labelled so they are not mixed with Mike's PC.
[check]

## wl-farmland | Water land types: player-tilled farmland is exempt from wild succession (weeds only)?
Note: Waterlogging still hurts crops.
Note: Recommendation: Yes because your fields should not turn into woods overnight.
[check]

## new-player-switch | Start with nothing but ground items, hints on, plus an admin 'become a new player' switch for testing?
Note: Empties the pack, turns hints on, drops admin powers so Mike can time the real first hour.
Note: Recommendation: Yes because we cannot test the first hour any other way.
[check]

## build-both-ways | Building both ways: blueprint and direct piece from the hotbar, same cost, 2 m grid and foundation rule; ship direct foundation first?
Note: New players start with the direct way.
Note: Recommendation: Yes because direct pieces suit a first shelter and need no protocol change.
[check]

## release-stages | Release in three stages: R1 first hour and house, R2 hunting and hide, R3 metal?
Note: Recommendation: Yes because hunting needs a carcass system and metal needs hide, neither built.
[check]

## wl-window | Water land types: read the water over 30 game days so one storm does not rename land?
Note: Plan: design/WATER_LAND_TYPES.md. Land is named from slowly averaged water (30 game days = 30 real hours).
Note: Recommendation: Yes because a single storm should not turn a meadow into a swamp. Why not: change feels slow.
[check]

## wl-dam-order | Dams: build order is dam test, then water stability test, then strength and breach, then wash-away?
Note: The water step must be fixed before a burst can be simulated safely.
Note: Recommendation: Yes because a breach could blow up the water simulation otherwise.
[check]

## wl-bridges | Bridges: low plank bridges and fords can be washed out in floods, high stone bridges with piers survive?
Note: Needs span and pier pieces with a flood rating from Sal's building tiers.
Note: Recommendation: Yes because it makes bridges matter. Why not: players lose work to floods.
[check]

## wl-dead-trees | Water land types: dead trees stay visible 20 to 30 game days, then fall?
Note: Needs a new bare-trunk model per species; until then trees just vanish.
Note: Recommendation: Yes because players should see why the wood is changing.
[check]

## wl-tree-speed | Water land types: trees take 3 to 6 real days to die after the water changes (herbs half a day)?
Note: One game day is one real hour. Spruce, fir and beech drown first; willow and alder last.
Note: Recommendation: Yes because it is slow enough to react, fast enough to see. Why not: you may want it faster.
[check]

## fish-species-list | Use this fish list (salmon and trout in rivers, herring to tuna in the sea)?
Note: Full list and reasons: design/FISH_AND_FISHING_PLAN.md, section on species.
Note: Recommendation: Yes because the list fits the North Atlantic island (moose, blueberry, ADT) and gives early fish near rivers.
[check]

## fish-stock-schools | Keep fish as hidden stock with moving schools, not swimming creatures?
Note: Fish stay a number per area with schools that drift; no swimming fish bodies to simulate.
Note: Recommendation: Yes because it costs almost nothing per frame and still lets players read the water.
[check]

## fish-salmon-autumn | Make the salmon run autumn-only, trout the rest of the year?
Note: Salmon only in rivers in autumn; trout and perch the rest of the year.
Note: Recommendation: Yes because a season gives a reason to return to the river.
[check]

## fish-shadows | Show dark fish shadows in clear shallow water as well as jumps?
Note: Dark shapes in clear shallow water, plus jumps and ripples, so players can see where to fish.
Note: Recommendation: Yes because it teaches fishing by looking, as the early-game rules ask.
[check]

## fish-sea-shore-only | Limit sea fishing to shore and shallows until boats exist?
Note: Deep-sea fish (tuna, cod) wait for boats.
Note: Recommendation: Yes because boats do not exist yet and it avoids unreachable fish.
[check]

## wl-soil-types | Water land types: swamp, marsh or bog chosen by soil and climate, not water alone?
Note: Peat or cool = bog, fertile and warm = swamp, otherwise open marsh.
Note: Recommendation: Yes because shallow water alone cannot tell them apart.
[check]

## wl-flood-plain | Water land types: a flood makes floodplain only, never swamp?
Note: Lasting dams still make swamp.
Note: Recommendation: Yes because floods come and go, so they should not rename land.
[check]

## wl-lake-size | Water land types: still water of 4 or more cells (about 250 m2) counts as a lake in the label?
Note: Ponds are still never placed in the bake. This is only the runtime label.
Note: Recommendation: Yes because smaller is a puddle.
[check]

## wl-dam-strength | Dams: strength depends on material, thickness and bracing, and dirt erodes if water pours over the top?
Note: Stone holds more than dirt; stone or dirt piled behind adds strength; a spillway relieves pressure.
Note: Recommendation: Yes because it matches your rule. Why not: more rules for builders to learn.
[check]

## wl-dam-breach | Dams: a breach is slow with a warning (creak, chat line), never instant?
Note: The dam opens over about a minute and the stored water runs out at its visible pace.
Note: Recommendation: Yes because players get a chance to react. Why not: less dramatic.
[check]

## wl-wash-away | Dams: fast flood water sweeps players and loose items downstream with light damage and no death at first?
Note: Applied in the game client from water speeds; server checks damage.
Note: Recommendation: Yes because it is safe and kind first. Why not: you may want deaths later.
[check]

## fire-lighting-rain | Does fire always light in dry weather (strike stones into dry plant-fibre tinder), and rain makes it slow or fail?
Note: Fire size follows the wood as you decided. This is only about lighting it.
Note: Recommendation: Yes because it takes about 10 seconds, is physical and never softlocks.
[check]

## shore-net-first | Does fishing start with a shore net (20 twine + 4 stones), with trap, spear and rod later and no reflex minigame?
Note: Stand at a ripple spot at the water edge, hold E about 20 s, get 1 to 3 small fish.
Note: Recommendation: Yes because it is simple and obvious for the first hour.
[check]

## rough-bed-rules | Rough bed: thatch + 4 sticks + 2 twine under any roof, better sleep, food and water at half rate asleep, never auto-wakes?
Note: A roofed room hides the sleeper. The Rested bonus from decoration comes later.
Note: Recommendation: Yes because it makes home worth building and gives a safe one-hour break.
[check]
