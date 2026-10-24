












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

## bridge-ramp-cap | Cap a bridge ramp at 40 m long?
Note: Bridge ramps and supports reach into the ground, so steep banks make longer ramps. Past 40 m the ghost says 'ramp too long'.
Note: Recommendation: Yes, 40 m, because a 1 in 6 ramp over a 6 m bank is 36 m and anything longer is a different structure.
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
