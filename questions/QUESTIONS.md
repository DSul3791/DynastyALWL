











## foundation-sizes | Should foundations come in two sizes, small 2 m and large 3 m?
Note: Blueprint building needs fixed foundation sizes. 2 m matches the building grid; 3 m gives bigger rooms for one foundation.
Note: Recommendation: Yes because it keeps the 2 m grid for walls and still gives a roomier option.
[check]

## dry-river-dump | Dump the water once at the dry river spot (build 750)
Note: 1. Fetch origin and Pull (build 750), close the game fully first. 2. Walk to the dry river spot (x 51609 z 69364). 3. Esc > Admin > Dump water here, once. 4. Tell us it is done; MikeW copies the files.
Note: Recommendation: Yes because it shows why your HUD says water 1.9 m below your feet while the server holds 4 to 9 m.
[test]

## bake9-steps | New island ground: pull, let Mike copy the tiles, commit them (build 751)
Note: 1. Close the game fully and the hidden server. 2. GitHub Desktop: Fetch origin, then Pull (build 751, code only). 3. Tell us 'pulled'. MikeW then copies the 9 new tile files into C:\GodotProjects\DynastyALWL\worlds\base_world\tiles. 4. GitHub Desktop will show 9 changed tile files. Tick them, commit with the message: Bake 9 tiles, terrain version 26. Then Push origin. 5. Tell us 'pushed'. Sonny then re-settles the water. 6. Start the game, Esc > Advanced > Clear blocks, and look around near spawn. The ground will have changed shape. Answer Yes if the game loads and spawn looks fine.
Note: Recommendation: Yes, do it tonight when you are ready because the 9-tile bake is done, spawn checks passed (slope 6.8 deg, flat, 0 water), and the old tiles are saved outside the repo for rollback.
[test]
