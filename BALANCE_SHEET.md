# Early-game balance sheet (Sal, 2026-10-31)

Time and quantity budget for the first tools, compared with other survival games. **Source quality is mixed:** the comparison numbers come from guide sites found by quick web searches, several of which disagree with each other or are out of date. They are a sanity check, not a target. Our numbers come from data/items/recipes.json and blueprints.json as of this commit. Gathering time is not measured (nobody has timed a real pickup run); only crafting seconds and material counts are.

## Our budget (fibre counts 3 fibre per twine)
| Goal | Materials | Craft time | Notes |
|---|---|---|---|
| Twine | 3 plant fibre | 2 s | recipe 1 |
| First axe | 1 stone, 1 stick, 2 twine = 6 fibre | 4 s plus 4 s twine | cut from 5 twine (15 fibre) this round |
| First fire | 6 sticks, 3 stones (laid fire), 1 plant fibre (or bark, tinder) to light | 3 s | "campfire" recipe |
| Shelter (lean-to) | 8 sticks, 6 leaves, 2 twine (6 fibre) | 8 s | |
| Rough bed | 10 thatch (or 8 straw or bedding), 4 sticks, 2 twine | 10 s | |
| Workbench | 20 sticks, 6 twine (18 fibre), 4 stones | 60 s | no station needed (cost raised 31 Oct) |
| Stone knife / spear | 2 stone + stick; wooden spear + 2 twine | 3 s / 4 s | |
| Bow | 2 sticks, 3 twine at the workbench | 8 s | arrows need feathers or the weaker fibre arrow |
| First forge (Basic Forge, hammer blueprint) | 24 stone (was 36), 10 clay, 2 hide | not data-driven here | needs a workbench of level 2 nearby |
| Total hand-made kit (axe, fire, shelter, bed, bench, bow) | about 30 sticks, 6 stones, 10 thatch, 6 leaves, 12 twine (36 fibre) | about 60 s of crafting | gathering dominates |

## Comparison (sources in the list below)
| Item | Ours | Valheim (as reported) | The Forest (as reported) | Vintage Story | Verdict |
|---|---|---|---|---|---|
| First axe | 1 stone, 1 stick, 6 fibre | Flint axe: 4 wood, 6 flint (one source also lists a stone axe 5 wood, 4 stone or 2 stone, so sources disagree) | stick, rock, rope | flint axe head knapped, plus a stick (one guide: 1 stick + 2 flint) | **fair**; ours is the cheapest in wood, and how long it takes depends on how dense the fibre plants are |
| Workbench | 12 sticks, 3 twine | 10 wood | not applicable | crafting grid in the inventory, no bench early (as reported) | **fair** (gathering time not measured) |
| Campfire | 6 sticks, 3 stones | 2 wood, 5 stone (a source lists "firepit" separately) | not covered | not searched | **fair** |
| Shelter | 8 sticks, 6 leaves, 2 twine | workbench needs a roof and walls (about 70 percent enclosed, as reported) | lean-to: sources disagree (one lists 53 logs, for Sons of the Forest) | not searched | **ours is far cheaper**: appropriate for a first-day shelter |
| Bow | 2 sticks, 3 twine | not searched | stick, cloth, rope | not searched | **fair** |
| First forge | 36 stone, 10 clay, 2 hide | not searched | not applicable | copper smelting needs dry grass, clay, logs, coal and native copper plus a crucible (wiki copper guide, as reported) | **a lot of stone**: 36 stone is about 72 stone-axe boulder blows at 3 blows per stone, as a stone-age task that is tolerable, as a first-day task it is not; consider 24 stone |
| Copper/bronze timing | not buildable yet | not searched | not covered | a third-party guide puts first copper tools at days 6 to 7, a rough plan not a benchmark | we are **too slow by design today** (no ore source at all) |

## Flags
- **Too slow:** the first forge (stone count, plus an ore source that does not exist); getting feathers for real arrows; hand-sawn lumber without iron (the Stone wedge route helps).
- **Too fast / cheap:** nothing yet found; the first axe at 6 fibre is cheap by design (the moderator asked for a cheap first tool).
- **Unknown until play-tested:** how long gathering 36 fibre or 30 sticks takes; recommend timing it in the guide's next play-through and entering the seconds here.
- **Tuning knob:** all costs above are data, so changing them is one-line edits, except the tests that hard-code the axe cost (already updated for 2 twine).

## Sources (quick web searches; guides disagree, check in game)
- Valheim recipe guides: [game8](https://game8.co/games/Valheim/archives/320273), [gamertweak](https://gamertweak.com/valheim-crafting-recipes-list/), [ginx.tv](https://www.ginx.tv/en/valheim-crafting-guide-all-recipes-upgrades-items-weapons-and-armour), [primagames workbench](https://primagames.com/news/valheim-how-craft-workbench-build-roof-workbench), [gamesradar progression](https://www.gamesradar.com/valheim-crafting-progression-guide)
- The Forest and Sons of the Forest crafting: [gamepressure](https://www.gamepressure.com/forest/guide/z0651d), [accelerated-ideas](https://www.accelerated-ideas.com/theforest/crafting-guide-craftable-items.aspx), [gfinity bow guide](https://www.gfinityesports.com/misc/the-forest-how-to-make-a-bow-and-arrows-recipe-and-materials-guide/), [pindrop (Sons)](https://pindrop.gg/sons-of-the-forest/crafting)
- Vintage Story: [first day guide](https://wiki.vintagestory.at/Survival_Guide_-_Your_first_day/uk), [crafting](https://wiki.vintagestory.at/Crafting), [knapping](https://wiki.vintagestory.at/Special:MyLanguage/knapping), [early game survival](https://supercraft.host/wiki/vintage-story/early_game_survival/)
