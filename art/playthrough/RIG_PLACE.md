# Placing structures for screenshots (testing only)

The server takes `--dev-place=name@x,z,yaw[,lit]`, repeatable. It puts the structure on the ground at x,z (world metres, the height is looked up) as soon as that ground is loaded (waits up to 3 minutes), with no kit. It exists for rigs and pictures; a normal server is never started with it.

- `name`: a structure kind of data/items/structures.json: `lean_to`, `rough_bed`, `straw_bed`, `feather_bed`, `canopy_bed`, `chest`, `workbench`, `fireplace`, `wall_torch`, `chandelier`, `chair`, `bench`, `table`, `hide_rug`, ... or `campfire` (a campfire).
- `yaw`: degrees (the lean-to's open front faces +x at 0).
- `lit`: optional last word; lights a fireplace, torch or chandelier (it burns for a long time) and a campfire (otherwise a laid, unlit fire).
- A bed placed at the lean-to's own x,z lies inside it (the same rule as in play).

Examples (through art/playthrough/rig.sh, which passes `SERVER_ARGS` to the server):

    SERVER_ARGS="--dev-place=lean_to@53301,68427,0 --dev-place=rough_bed@53301,68427,0 --dev-place=campfire@53306,68427,0,lit" bash art/playthrough/rig.sh ...
    SERVER_ARGS="--dev-place=fireplace@53310,68430,90,lit --dev-place=wall_torch@53310,68433,0,lit --dev-place=chandelier@53312,68430,0,lit" bash art/playthrough/rig.sh ...

The server log says `dev-place <spec> -> world id N` for each one, or that it could not place it. Test: src/worldgen/tools/test_dev_place.gd.
