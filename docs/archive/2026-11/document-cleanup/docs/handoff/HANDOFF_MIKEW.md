# Handoff: MikeW: flora and fauna (plus the Grass leftovers), 5 Nov 2026

## Role
I own plants and animals: flora density and placement, fruit and forage, fauna behaviour (wander, flee, walls, nests, burrows, snares), and the grass view. Since 4 Nov I also hold the Grass thread's leftovers. Jamie (BACKLOG.md) gives me jobs top-down by priority, so I also take docs and data jobs. I never touch or merge main: Tyler merges. Branches are `claude/mikew-YYYYMMDD-*`, a new one each day.

## Rules that apply now (Dave)
- **No cloud testing (5 Nov 00:06).** No Godot runs, test runs or renders in the cloud. Fix code and data by reading them; QA (Tyler) runs tests on Dave's PC when he is not play testing. Plain python checks (`tools/guide_vs_recipe.py`, `tools/item_master.py`) are fine.
- **No kits (#292).** Everything placed is a hammer blueprint. Only the campfire kit and the Rough bed stay pack crafts. Never add a `*_kit` recipe.
- The game starts in summer (day 100), when there is food on the vines and trees (`test_season_fruit.gd`). Don't move it without Dave.
- Art follows `art/Art_Direction.md`. Short replies (Dave uses voice). Design calls and balance go to Dave; technical calls are mine.

## Done and merged (3 to 5 Nov)
- Early game fauna: #194 forage note, #209 frogs/ducks/gulls/seals by water, #219 snares draw rabbits and foxes, #224 thrown spears hit, #236 burrow spots to the client, #239 fox smell 120 m (Dave approved), #287 summer-start test.
- Stranded stacked PRs re-landed: #328 animals stop at walls (`steering.gd` cross callable, `server_animals.gd` walls), #329 nests, #332 floor tiles clear only their footprint, #335 nest spots sent to clients (PROTOCOL 91).
- #367 guides follow the no-kits rule, the hammer-built lean-to and the new costs (`guide_vs_recipe.py`: 0 mismatches).

## Open PRs (waiting on Tyler or Dave)
- #340 (draft): foundations clear the grass under them. Waiting on Dave's card. If he says "only under it", take it out of draft and send it to Tyler; otherwise close it.
- #369: item notes for rough plank, hinges and wooden pins name the blueprints that use them. The dead-end check is done: the validator lists none of the five.
- #371: the item validator lets a structure's `kit` id name a retired kit, because the code still keys pieces by it: placing, taking down, `_blueprint_of_kit`, old saves. Errors went from 66 to 13. Sal reviews it.
- #373: the other 12 validator errors: block descriptions, small block recipe names, log block sources before the recipe check, wild seeds from `seed_drops`, `torch_doused`. Sal's #372 fixes `next_number`. Not run: it needs a PC run of `validate_items.gd`, which should show 0 errors with all three merged.

## Waiting on Dave
- Real modelled animal meshes (card). The look check (`/mnt/project-files/art/look_check_20261104/README.md`) found the animals are code-built ellipsoids that fail Art Direction; coat shaders can't fix that.
- Far grass `fade_start_share` 0.25.

## Next steps
1. When #353 (fibre rope) lands on main, add its line to the first-hour guides, then run `python3 tools/guide_vs_recipe.py`.
2. Grass window checks are on the PC queue; follow up on what they find.
3. Not started (stop order 4 Nov): wiring animals to Hammer's `structure_blocks` (#166).

## Tools
- `tools/guide_vs_recipe.py`: guide numbers against recipe data. It flags any stick count within 70 characters after "lean-to".
- `tools/item_master.py /mnt/project-files/tech/ITEM_MASTER.md`; use `--check` to see if the file is stale.
- `src/worldgen/tools/validate_items.gd`: item data validator, run on the PC now.
- `tools/tests_for_diff.py --paths ...` then `tools/run_tests.sh --plan`: on the PC only now.
- Fauna odds: `snare_odds.gd`, `fox_odds.gd`, `tile_biomes.gd`.

## Read first
`/mnt/project-files/BACKLOG.md` (Jamie's job table), `/mnt/project-files/backlog/mikew.md` (my leftovers), `docs/FLORA_HANDOVER.md`, `docs/handoff/SCOPE_MIKEW.md`, `data/animals/animals.json`, `src/stream/server_animals.gd`, `data/tables/flora.json`, `src/client/grass_view.gd`.

## Decisions not to re-litigate
- Stacked PRs must target main. #248 and #279 were lost by being merged into dead base branches.
- The PLUME_FLOWERS grass-thinning idea gave bald patches and was reverted.
- Jason owns the grass build spike (resumable `_build`, agreed 5 Nov).
