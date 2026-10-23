












## sound-duck-vetted | Duck quacks and sand footsteps (build 752)
Note: 1. Start the game (MikeW has pulled the new build). 2. Esc > Settings > Sound test > creature calls > duck. Listen: does it sound like a real duck and is it quiet enough? 3. Walk and run on sand: is running only a little louder than walking?
Note: Recommendation: Yes after listening, because the duck clips are real recordings that passed the team check and the sand run is now only about 5 dB over walk, as you asked.
[test]

## allow-mike-pull | NEW PERMISSION ask: let MikeW update your game folder, copy the island tiles and commit them?
Note: This is a new ask (not a website): Mike's permission check blocks him from touching your own game folder, even though you said he can. 1. Open the file /mnt/project-files/settings_addition_mike_pull.json (8 plain lines: git pull and push for your folder, copy 9 tiles and the water files in, commit only the tiles). 2. Add those lines into Mike's settings.json under permissions allow, then add the two folders under additionalDirectories (the file shows where). 3. Save the file and restart MikeW. 4. If you would rather not: do 'Fetch origin' and 'Pull' yourself in GitHub Desktop (2 clicks, game closed) and say 'pulled'; Mike then only copies and commits the tiles, which his current rules mostly allow.
Note: Recommendation: Yes, add them, because it is exactly the pull, copy and commit you already told us to do ourselves, limited to your game folder, the tile files and the water folder, with no force push and no main branch.
[check]
