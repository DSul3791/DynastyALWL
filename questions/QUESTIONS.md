












## sound-duck-vetted | Duck quacks and sand footsteps (build 752)
Note: 1. Start the game (MikeW has pulled the new build). 2. Esc > Settings > Sound test > creature calls > duck. Listen: does it sound like a real duck and is it quiet enough? 3. Walk and run on sand: is running only a little louder than walking?
Note: Recommendation: Yes after listening, because the duck clips are real recordings that passed the team check and the sand run is now only about 5 dB over walk, as you asked.
[test]

## push-tiles-by-hand | Push the 9 new island tiles (MikeW's push is blocked by a permission check)
Note: 1. In GitHub Desktop: File > Add local repository > choose C:\GodotProjects\DynastyALWL_test (skip if it is already listed). 2. Current branch: claude/mike-bake-9tile (last commit: Bake 9 tiles, terrain version 26, 87fff3ca). 3. Click Push origin. 4. Tell us 'pushed'. Then we merge it and you Fetch origin + Pull in your normal folder, close the game first, and press Esc > Advanced > Clear blocks. Alternative: answer the earlier card allow-mike-pull Yes, save the settings and restart MikeW, then he can push himself.
Note: Recommendation: Yes, do the 4 steps, because it is the quickest way (about a minute) and the tiles are already checked: spawn flat and dry, island shape in. Only the far south-east coast edges are slightly soft and get fixed in a later bake.
[test]

## pull-clean-folder | Your game folder blocks the Pull: clear 2 things first (about 2 minutes)
Note: 1. Close the game fully. 2. GitHub Desktop > Changes tab: right-click crash_reports/telemetry_server_24600.log > Discard changes (it is only an old log; the new build stops tracking it). 3. In File Explorer open C:\GodotProjects\DynastyALWL\src\client and delete cavein_death.gd.uid. 4. In C:\GodotProjects\DynastyALWL\src\worldgen\tools delete test_cavein_death.gd.uid and test_flora_close.gd.uid (the Pull brings these back itself). 5. GitHub Desktop: Fetch origin, then Pull origin. 6. Tell us 'pulled'.
Note: Recommendation: Yes, do it, because it is the only blocker for the new build and the three files are just Godot index files that come back with the Pull.
[test]
