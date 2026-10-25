# Action plan: bow, arrows and quiver items (Sal, branch claude/sal-bow-items, build 795)

Items and recipes only; Steve's `claude/steve-bow-shoot` (f1e56758) does shooting, hit and damage, and reads these item fields. Label RESTART (new items and recipes, no code, no protocol change).

## Items (from my reserved block; 267 and 268 are taken by the oven and oven kit, so these start at 269)
| # | id | kind | notes |
|---|---|---|---|
| 269 | wooden_bow | weapon, weapon_class "bow", tier 1 | durability 400, damage 0 (the arrow carries damage), draw_s 1.0, range_m 40; repair 1 twine |
| 270 | wooden_arrow | material, ammo "arrow", stack 20 | sharpened stick tip, fire-hardened; arrow_damage 5.0, retrieve_chance 0.5 |
| 271 | stone_arrow | material, ammo "arrow", stack 20 | arrow_damage 8.0, retrieve_chance 0.6 (stone point lasts) |
| 272 | quiver | gear, slot "back", carries 40 arrows | fields only; Steve's shooting reads `ammo` and takes from the quiver first, then the pack |

## Recipes (from 170)
| # | gives | needs | where |
|---|---|---|---|
| 170 | wooden_bow | 2 stick, 3 twine, | workbench (a weapon), known |
| 171 | wooden_arrow x4 | 2 stick, 2 feather | by hand, known |
| 172 | stone_arrow x4 | 2 stick, 2 feather, 2 stone | by hand, known |
| 173 | quiver | 2 hide, 2 twine | by hand, known |

Arrows are small ammo, so by hand; only the bow (a weapon) needs the bench (CRAFTING_STATIONS_RULE). Feathers exist already. All recipes known from the start like the rest.

## Handoffs
- Name list to Kathleen via the Moderator for looks: wooden_bow, wooden_arrow, stone_arrow, quiver (I stub with a BasicLook line/cylinder shapes).
- Steve: field names above (`weapon_class bow`, `draw_s`, `range_m`, `ammo`, `arrow_damage`, `retrieve_chance`); tell me if he wants other names before I build.

## Not changed
No existing item renamed or renumbered; no save format change; hit rules, drawing animation and retrieval are Steve's.

## Tests (David3)
validate_items 0 errors, test_server_items craft/known tests for 170-173, test_new_player, duplicate sweep, local_check 233.

## Ask
GO or changes, one reply.
