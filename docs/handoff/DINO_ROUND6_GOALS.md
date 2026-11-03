# Dino round 6: starter goals checked against data (3 Nov 2026, main 2e603e9, paper check)

I checked each of the 13 starter goals in `data/items/starter_goals.json` for three things: that its item ids exist (items.json plus gathered.json), that its recipe numbers match its hint, and that its check event is sent by the server.

**All clear:**
- drink, fibre, twine, axe, fell, fire, berries, shelter, bed, spear and knife.
- The hint numbers match recipes.json:
  - Stone axe: 1 stone, 1 stick, 2 twine.
  - Wooden spear: 1 stick, keep a stone.
  - Stone spear: wooden spear plus 2 twine.
  - Knife: 2 stones, 1 stick.
  - Rough bed: 10 thatch or bedding, 4 sticks, 2 twine.
- The fell reward "kindling" exists. It is in gathered.json as number 1080, and test_goals checks it.

**New finding:**
- **The "Build a workbench" goal ignores the log workbench.**
  - The check is `placed` with `what: workbench`.
  - The log workbench is a hammer blueprint (blueprints.json number 15). It places structure `log_workbench`, so `_goal_event(peer, "placed", "log_workbench")` never ticks the goal. Both structures have `station: workbench`.
  - A player who builds the log workbench first, as the tutorial's step 20 allows ("or 4 logs, 6 twine, 6 sticks"), never completes the goal. The fish goal waits on it (`after: workbench`), so the fish goal never opens either.
  - Suggested fix (Sal, data or goal code): let the check take a list (`what_any: [workbench, log_workbench]`) or count by station.
  - Severity: medium. It blocks two goals on a path the tutorial suggests.

**Already reported in round 5 (still open on main):**
- The workbench goal name doesn't match the recipe name "Camp bench".
- The fish goal only counts trout, perch, carp and pike.
- The hints still say Warmth and "roast" (Sal's PR #53).

**Also fixed this round, in PR 198:**
- `tools/check_controls.py` failed on main. The photo camera's PageUp/PageDown were bound but missing from it, so I added them to the tool and to CONTROLS.md.
- BUGS_FOUND_IN_PLAY.md: #1 is marked fixed, and #5 is marked as merged behind `felling.size_scaled` (off).

## Hints that never show (hints.json triggers vs `_hint_trigger_true` in server_items.gd)

40 hints use 37 trigger names. The server's `match` handles 24 of them. Any other trigger returns false, so its hint is never said. The code comment names only axe_held_near_tree, the fruit and orchard triggers, and beach_with_container as "never fires". These are dead too, with no note:

| Trigger | Hint text | Early game? | Easy to add? |
|---|---|---|---|
| has_campfire_kit | "Hold the fire kit and click ground. Under trees it survives rain." | yes, the first fire | yes: `inv.count_of(campfire_kit) >= 1` |
| near_nettle | "Nettles give fibre and leaves. Steep leaves in a pot for tea." | yes, the first fibre | needs a flora query near the player |
| near_fire_with_food | "Roast raw meat on the campfire. Cook plants in a pot." | yes, but the text is stale (no roasting since the fire store, #32), and Sal's PR #53 rewrites it | after #53 |
| digging_under_ceiling | "Digging out a roof support can bring it down." | no | no |
| has_sea_water, beach_with_bucket | sea water and salt | no | pack check easy; beach check needs water type |
| season_changes, autumn_end | seasons | no | needs the season clock |

Also: `workbench_placed` counts only `placed:workbench`, so the hint misses the log workbench, the same gap as the goal above.

Suggested owner: Tyler (hint code, 31 Oct) for has_campfire_kit and the log workbench; Sal for the texts.
