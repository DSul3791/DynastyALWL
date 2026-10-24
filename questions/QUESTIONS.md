












## sound-duck-vetted | Duck quacks and sand footsteps (build 752)
Note: 1. Start the game (MikeW has pulled the new build). 2. Esc > Settings > Sound test > creature calls > duck. Listen: does it sound like a real duck and is it quiet enough? 3. Walk and run on sand: is running only a little louder than walking?
Note: Recommendation: Yes after listening, because the duck clips are real recordings that passed the team check and the sand run is now only about 5 dB over walk, as you asked.
[test]

## look-terrain-783 | Does the new land from spawn to the mountains look right? (build 787)
Note: 1. Close the game fully, end any leftover Godot in Task Manager, GitHub Desktop Fetch + Pull, start. HUD must say ground v41.
Note: 2. Esc > Admin > Reset all terrain edits, then Clear blocks.
Note: 3. Walk from spawn toward the mountains. Look at: rivers start high in the valleys, gullies, beaches, foothills.
Note: 4. Say Yes if it looks right. If No, write where (F3 gives x z) and what is wrong.
[test]

## look-caves-dark | Are caves and tunnels dark by day now? (build 784)
Note: 1. Pull build 787 (see the terrain card for the steps).
Note: 2. Walk into a cave or a dug tunnel in daylight: it should go dark, with a torch still lighting it.
Note: 3. Esc > Settings > Cave darkness: try Dark and Normal.
Note: 4. Yes if dark and readable with a torch. No: write what is wrong.
[test]

## look-sound-batch2 | Do the new ambience sounds sound right? (bird chorus, owl, frogs, crickets, surf, wind)
Note: 1. Pull build 787.
Note: 2. Esc > Settings > Sound test > Batch 2: press once per group; each group plays 3 times.
Note: 3. Listen with headphones. Yes if they sound natural. No: name the group that is wrong.
[test]

## look-trees-ferns | Do the trees, ferns and grass look better, and is there a softwood belt on the foothills? (build 779, 784)
Note: 1. Pull build 787.
Note: 2. Look at a hardwood forest, then walk up a slope: softwoods (pine, spruce) should take over on the foothills and slopes, hardwoods on fertile flat ground.
Note: 3. Yes if the belt looks right. No: write where (F3) and what is wrong.
[test]

## look-new-tools | Can you craft the new tools? (build 787: stone hammer, hand saw, stone adze)
Note: 1. Pull build 787.
Note: 2. At a workbench craft a stone hammer, a hand saw and a stone adze.
Note: 3. Use the hand saw on a log: hand-sawn lumber recipe.
Note: 4. Yes if all three craft. The hammer and adze do nothing else yet; their descriptions say so.
[test]

## rumble-300m | Should the volcano rumble play only above 300 m (high up), or also from the ground near the volcano?
Note: Now the rumble plays only when you are above 300 m. A volcano on the horizon is silent from the ground.
Note: Recommendation: Relax it: play it softly from the ground within about 3 km of the vent, louder up close, because a volcano you can see should be heard (a distance table, no new code).
[check]
