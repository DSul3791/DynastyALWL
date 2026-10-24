












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

## hammer-adze-recipe | Make the stone hammer and stone adze cost 1 stone + 1 stick + 5 twine like the axe?
Note: Today they cost 2 stone + stick + 1 twine. The stone axe becomes 1 stone + 1 stick + 5 twine. The knife stays 2 stone + stick.
Note: Recommendation: Yes, because all hafted stone tools then cost the same and fibre becomes the early limit.
[check]

## wl-farmland | Water land types: player-tilled farmland is exempt from wild succession (weeds only)?
Note: Waterlogging still hurts crops.
Note: Recommendation: Yes because your fields should not turn into woods overnight.
[check]

## wl-r1-first | Water land types: build R1 first (admin map of land types, no plant changes, plus the dam test)?
Note: R2 plants and R3 succession follow.
Note: Recommendation: Yes because it is safe and shows where the game thinks each type is. Why not: nothing new in play yet.
[check]

## thatch-screen-first-room | Is the first room a cheap thatch screen wall (about 12 thatch, 4 twine, 6 sticks)?
Note: The full wall (20 twine, 50 thatch, 15 sticks) makes a 4-wall room cost 200 thatch, too much for a roofed bed in 90 minutes.
Note: The full 50-thatch wall stays as the proper wall for later.
Note: Recommendation: Yes because it makes a roofed bed in 90 minutes reachable; otherwise the target moves to about 2.5 hours.
[check]

## new-player-switch | Start with nothing but ground items, hints on, plus an admin 'become a new player' switch for testing?
Note: Empties the pack, turns hints on, drops admin powers so Mike can time the real first hour.
Note: Recommendation: Yes because we cannot test the first hour any other way.
[check]

## metal-ladder | Metal ladder: stone pick first, then bronze pick from the basic forge, iron needs a bronze pick; add copper, tin and bronze to the game?
Note: Stone pick opens soft rock, clay and coal. An optional bone/antler pick can dig copper and tin. The data jumps from stone to iron today.
Note: Recommendation: Yes because a rock cannot break iron, and soft metal first matches real history.
[check]

## respawn-at-bed | Respawn at your own bed (per player), built right after the first hour work?
Note: Needs new server and save state. Today there is one global respawn point.
Note: Recommendation: Yes because it makes the bed your home.
[check]

## cooking-stations | Three cooking stations: tripod pot, clay hearth, oven (tier 1 in R2, the others R3)?
Note: Recommendation: Yes because each tier is a thing you place and the recipes already exist.
[check]

## inner-voice-hints | Inner-voice hints: max 6 an hour, 12 words, never an order, admin can mute, one gentle up-front hint after 60 s of doing nothing?
Note: Hints otherwise come after a mistake.
Note: Recommendation: Yes because it guides without nagging.
[check]

## build-both-ways | Building both ways: blueprint and direct piece from the hotbar, same cost, 2 m grid and foundation rule; ship direct foundation first?
Note: New players start with the direct way.
Note: Recommendation: Yes because direct pieces suit a first shelter and need no protocol change.
[check]

## direct-on-blueprint | A direct piece placed on an unfinished blueprint waits until it is done; taking down a finished piece returns 50 percent?
Note: Recommendation: Yes, and 50 percent is your call.
[check]

## release-stages | Release in three stages: R1 first hour and house, R2 hunting and hide, R3 metal?
Note: Recommendation: Yes because hunting needs a carcass system and metal needs hide, neither built.
[check]

## copper-tin-placement | Place copper and tin nuggets at runtime near gullies and rock faces, because the baked ground has none?
Note: Hard stone is handled by choosing the spawn point near it, not by placing it.
Note: Recommendation: Yes because the final bake would otherwise leave the bronze step with no ore.
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
