# Dino round 6: starter goals checked against data (3 Nov 2026, main 2e603e9, paper check)

**Status, 04:15 UTC:** Sal's PR #53 (merged to main as fe224e2) fixes the three main findings below:
- The workbench goal and its hint take `what_any: [workbench, log_workbench]`.
- The axe goal takes `or_have`, so a bought axe counts.
- The has_campfire_kit, near_nettle and near_fire_with_food hints now fire. near_nettle fires when nettles are in the pack.

#53 merges cleanly with PR 198 (`git merge-tree`). Its `test_goals` has not been run in Godot yet.

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

## First-hour item tooltips (items.json / gathered.json `description`) vs data: all correct

I checked 26 first-hour items: stone, stick, fibre, twine, leaves, bark, bedding, thatch, kindling, tinder, log, firewood, the axe, the knife, both spears, the five kits, the fishing rod, lumber, the rough plank and the stone hammer.
- "Light it with fibre" is right: cooking.json tinder is plant_fibre, and tinder, birch bark and tinder fungus also work.
- "The stone axe breaks rock" is right: boulders.json gives axe/stone 3 blows per stone.
- "Wedge lumber at a workbench" is right: recipe lumber_wedge, station workbench, keeps a stone wedge.
- Nothing to fix. The only gaps are that the `hammer` and `root_ball` ids have no tooltip text, and neither is a first-hour pack item.

## Fishing in the first hour (fishing.json): works at the spawn pond

- **Rod:** 2 sticks and 2 twine, no station.
  - Reach is 8 m, and a bite comes in 6-22 s. The base chance is 0.55, times 1.3 with bait (berries, raw meat or fibre), up to 0.93.
  - A pond gives carp 0.6 and perch 0.4, both counted by the fish goal.
  - The rod, stream and lake catches are all inside the goal's four species. The round 5 note about the fish goal applies only to the shore net and the spear, which take fish from schools.
- **Order:** the fish goal opens only after the workbench goal (`after: workbench`), but the rod needs no bench.
  - So a player can catch a fish before the goal opens. That still counts, because the goal checks `have_item_any` while the fish is in the pack, but it won't if the fish has already been eaten.
  - Suggest `after: twine` or `after: spear` (Sal). Low.
- **Bed:** `shelter_needed` true in structures.json matches the guide's "under the lean-to roof". The lean-to is 2.6 x 3.4 m and the bed is 1 x 2 m, so it fits.

## First night: fire heat by tier (warmth.json + cooking.json fire_tiers)

Since the fire tiers came in, the heat depends on the tier:

| Fire | Heat | Reach |
|---|---|---|
| Stick fire | +10 C | 2.5 m |
| Firewood fire | +20 C | 4 m |
| Log fire | +40 C | 5 m |

`warmth.json` fire_radius_m 4 / fire_c 20 is only the fallback.
- A roof does not add heat. It cuts the wind to 30 percent and keeps rain off.
- A bed takes 10 percent off the cold.

I fixed PLAYTHROUGH_GUIDE.md (warmth paragraph) and MORNING_PLAYTEST_CHECKLIST_FULL.md row 12.

These still say "a fire adds 20 C within 4 m" for every fire. They are other owners' docs, not changed:
- CLOTHING_WARMTH.md line 4.
- SEASONALITY_WINTER.md line 25.
- PROTOCOL.md entry 36.

## Carry weight of the first-day kit (weights.json)

The limit is 0.7 x 75 kg = 52.5 kg. Up to 42 kg there is no slowdown.

The whole first-day kit, gathered raw, weighs **23.4 kg**:

| Item | Count | Weight |
|---|---|---|
| Sticks | 63 | 12.6 kg |
| Stones | 10 | 10 kg |
| Leaves, thatch, fibre | | 0.8 kg |

So gathering never slows a new player. The only early load that does is logs: 15 kg each, so a third log on the shoulder passes 42 kg.

**Low, for Sal:** four kits break the weights.json rule "a kit weighs what it is made of":

| Kit | Kit weight | Inputs weigh |
|---|---|---|
| Campfire | 4.5 kg | 4.2 kg |
| Lean-to | 3.5 kg | 6.6 kg (crafting "loses" 3 kg) |
| Rough bed | 2.0 kg | 1.2 kg |
| Camp bench | 12 kg | 7.3 kg |

None of these matters in play at these sizes.

## First-hour sounds (assets/audio/sound_manifest.json, validate_sound_slots.py)

Every first-hour action has a sound slot with files on disk:
- pick: pluck, snip, pull, twist, snap
- item pickup (27 files)
- the craft sounds: twine, knap, bind, carve, start, done
- hit swing
- trees: creak, crash, leaves
- chop split and thock
- fire: light, fuel, small, large, rain, out
- eat crunch and soft
- drink gulp
- place lean-to and thump
- breath and heartbeat

`validate_sound_slots.py` reports no empty slots.

The manifest marks all of these `generated`, not `recorded` (only fish splash and tree frog are `recorded`); I did not listen to them. That is a note for Sound, not a bug: the first hour is heard entirely through placeholders, so a recorded drink, fire light and tree crash would be the biggest wins.
