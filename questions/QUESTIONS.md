












## sound-duck-vetted | Duck quacks and sand footsteps (build 752)
Note: 1. Start the game (MikeW has pulled the new build). 2. Esc > Settings > Sound test > creature calls > duck. Listen: does it sound like a real duck and is it quiet enough? 3. Walk and run on sand: is running only a little louder than walking?
Note: Recommendation: Yes after listening, because the duck clips are real recordings that passed the team check and the sand run is now only about 5 dB over walk, as you asked.
[test]

## allow-mike-pull | NEW PERMISSION ask: let MikeW update your game folder, copy the island tiles and commit them?
Note: This is a new ask (not a website): Mike's permission check blocks him from touching your own game folder, even though you said he can. 1. Open the file /mnt/project-files/settings_addition_mike_pull.json (8 plain lines: git pull and push for your folder, copy 9 tiles and the water files in, commit only the tiles). 2. Add those lines into Mike's settings.json under permissions allow, then add the two folders under additionalDirectories (the file shows where). 3. Save the file and restart MikeW. 4. If you would rather not: do 'Fetch origin' and 'Pull' yourself in GitHub Desktop (2 clicks, game closed) and say 'pulled'; Mike then only copies and commits the tiles, which his current rules mostly allow.
Note: Recommendation: Yes, add them, because it is exactly the pull, copy and commit you already told us to do ourselves, limited to your game folder, the tile files and the water folder, with no force push and no main branch.
[check]

## push-tiles-by-hand | Push the 9 new island tiles (MikeW's push is blocked by a permission check)
Note: 1. In GitHub Desktop: File > Add local repository > choose C:\GodotProjects\DynastyALWL_test (skip if it is already listed). 2. Current branch: claude/mike-bake-9tile (last commit: Bake 9 tiles, terrain version 26, 87fff3ca). 3. Click Push origin. 4. Tell us 'pushed'. Then we merge it and you Fetch origin + Pull in your normal folder, close the game first, and press Esc > Advanced > Clear blocks. Alternative: answer the earlier card allow-mike-pull Yes, save the settings and restart MikeW, then he can push himself.
Note: Recommendation: Yes, do the 4 steps, because it is the quickest way (about a minute) and the tiles are already checked: spawn flat and dry, island shape in. Only the far south-east coast edges are slightly soft and get fixed in a later bake.
[test]

## cost-basic-foundation | Basic foundation cost: small 1x1 = 6 boughs, 10 leaves, 4 sticks (2x2 = four times that)?
Note: Basic foundation is packed dirt with leaves and boughs; the ground flattens by itself, no tamping. Wooden and stone foundation costs are already approved.
Note: Recommendation: Yes because it is cheap and needs only things found in the woods, matching a first-day shelter.
[check]
