# Playtest Repair Mission 001: combat and tools (TEST-004, TEST-010, TEST-013)

Protocol: 115 (the hotbar fix took 112, the far campfire smoke 114 while this was in test; 113 unused).

Owner: thread "Fix spear combat, log carrying, tools". Base: `origin/dev` at `b922cc88a59586dfbd41f806744d9ccedfe2bf26`. Branch `claude/project-thread-r7u4ds`. `main` untouched.

## Ledger

| Test | Status | Why |
|---|---|---|
| TEST-004 spear combat | NEEDS PLAYER VERIFICATION | Root cause found and fixed in code; the spear hold is a visual change nobody has seen yet. |
| TEST-010 log carry | NEEDS PLAYER VERIFICATION | Log raised onto the shoulder and the right-hand tool put away; position chosen from the skeleton, not seen in game. |
| TEST-013 tools and "Forest Humus" | NEEDS PLAYER VERIFICATION | Server now uses the tool in hand with Dave's tool tiers for rock and wood; label fixed. Numbers need Dave's feel in play. |

No row is VERIFIED FIXED: Godot has not run on this change yet (no cloud runs; PC run pending Dave's go).

## TEST-004: spear attacks stop, spear held like a knife

Reproduced by reading the code (`src/client/held_item.gd`):
- The jab clock `_jab_t` was only advanced in the `_process` branch for a model with no arms. The first-person arms always exist, so the spear is always "mounted": the first jab set `_jab_t = 0` and it never went back below 0. `mouse_button` only starts a jab when `_jab_t < 0`, so after the first jab no more attacks were sent, and the arms stayed in the working pose. Early hits looked intermittent because a single jab only lands with an animal inside reach.
- The spear was laid along the fingers (`-Z` of the hand mount). The jab clip is a boxing punch (`Right_Jab_from_Guard` on the body, `jab` on the arms), so the shaft stuck out of the fist like a dagger; third person tilted it 150 degrees so it stood up like a staff.

Fix:
- The jab runs on its own clock every frame, whatever draws the model.
- `_aim_spear()` places the spear every frame from the view, not the hand bone: the point straight ahead from the fist with the hand `SPEAR_GRIP_Z` (0.3 m) behind the shaft's middle. Third person: the body's facing (avatar root, -Z), 8 degrees up. First person: the facing tipped 35 degrees down at rest, so it hangs below the view with the arms, turning to the camera's aim as the arms come up (jab, throw aim). The old spear branches of `_mount_model` / `_mount_model_third` are deleted (decision 61).
- Not changed: there is no spear-thrust animation in Dave's glb (84 clips, none a thrust), so the punch clip still moves the arm; the spear now points along it.

Test: `src/worldgen/tools/test_spear_hold.gd` (three jabs in a row each end; first-person rest and aimed directions; third-person facing with a hand mount at an odd angle; grip distance; no stretch). Eating from the hand is refused while a log is carried (review finding 5).

Dave to check: hold the Wooden Spear, jab repeatedly at a rabbit in first and third person; attacks never stop; the spear looks like a spear (point ahead, shaft through the fist).

## TEST-010: log too low, axe still in hand

- Third-person log was attached to `Spine2` at (-18, 9, -12) cm: chest height, behind the shoulder. The skeleton's right shoulder joint is (-18.7, 1.6, -3.7) cm from `Spine2` (read from `Dynasty_Base_Male.glb`). Moved to (-17, 24, -4): the 14 cm log resting on top of the shoulder, beside the head (`src/client/character/dynasty_body.gd`).
- Nothing put the right-hand item away while carrying. `held_item.carrying_log` (set every frame by `terrain_client.gd` from `items.shoulder_id`) makes `held_number()` return 0: the tool's model goes and it cannot be swung; the hotbar key stays chosen, so the tool returns the moment the log is laid down (F twice or Q). A torch or shield in the left hand stays.
- First-person log position unchanged (Dave set it 23 Oct).

Test: `test_spear_hold.gd` (carrying hides the axe, laying down brings it back).

Dave to check: pick up a log holding an axe, third person: log on top of the right shoulder by the head, no axe in the hand; put it down: the axe is back.

## TEST-013: tool effectiveness and "Forest Humus"

What "Forest Humus" is: a **boulder** (the breakable rock lumps, `data/items/boulders.json`). Boulders are drawn apart from the world items, so the look text fell through to the ground under the hit point and named the soil there, "Forest humus" (`data/tables/soils.json` id 8). It is rock: the look now says **Rock** (a display label in `terrain_client.gd`, no item or catalog change).

Why the axe and pick seemed equal:
1. The server broke a boulder with the *best pick or axe on the hotbar*, whatever was in hand (`server_items._boulder_tool`). With both on the hotbar, the held tool did not matter.
2. `boulders.json` gave the stone axe and stone pick the same 3 blows per stone.
3. The wear used work kind `"boulder"`, which has no `drops.json tool_wear` entry, so the existing "axe on rock wears 5" rule never applied.

Fix (protocol 115, approved by Dave in the thread, 12 Nov 2026: "yes it needs to know what tool I am using"):
- The client sends the held pack slot + 1: in the boulder ACT_HIT `count`, and in at.x of the tree ACT_HIT and the trunk, stump and log ACT_PROCESS (`PROTOCOL.md`). The server uses and wears only that tool, which must be on the hotbar and not broken; anything else is refused as no tool.

Tool tiers (Dave 12 Nov 2026, in the thread):
- Rock (`boulders.json tools`, now stones per blow): pick stone 1, bronze 2, iron 3, steel 4; axe stone 0.5, bronze 1, iron 1.5, steel 2. A boulder's stones stay fixed by its size; a better tool empties it in fewer blows, so it wears less for the same stone. A fraction carries over in the boulder's `progress`. Wear kind `"rock"`: an axe dulls and wears 5 a blow, a pick 1 ("hitting an axe on a stone will pull down its sharpness rapidly").
- Wood (`drops.json wood_tools speed`, the work one blow does): axe stone 1.0 (the old timing), bronze 1.5, iron 2.0, steel 2.5; pick stone 0.15, bronze 0.2, iron 0.25, steel 0.3. It divides the blows to fell a tree, cut a log off a trunk and break up a stump.
- A pick on wood ("using a pickaxe on a tree or a log will give you thatch, and kindling. not sticks or wood. if you break a log with a pickaxe it will just leave a pile of kindling"): every blow gives 1-2 kindling and 1 thatch, nothing else (no branches, sticks, firewood or bark). A trunk length cut through with a pick leaves a pile of 10 kindling instead of the log; a log on the ground breaks after 1 / speed blows (7 with a stone pick) into a pile of 5 (small log) or 10 (shoulder log) kindling; a stump gives 5 kindling. Wood never wears or dulls a pick (`tool_wear` pick tree, trunk, split 0: "a tree cant dull a pickaxe"). A tree a pick fells still falls and breaks into logs like any other (my reading; say if it should not). The 5 and 10 kindling counts are a first guess for Dave to tune.
- Not changed: the chopping block (split at a structure) and swinging at bare rock ground (`_mine`, still the first axe on the hotbar; reported, not in this fix).

Tests: `test_server_items.gd` boulder block (nothing, a stone or an empty slot in hand refused; iron pick 10 blows = 30 stones and 10 wear; a held stone axe with the iron pick on the hotbar: 12 blows = 6 stones, 60 axe wear, pick untouched; luck doubles at 3 a blow) and a pick on a trunk (kindling and thatch, no sticks, no wear on pick or axe); `test_stump_chop.gd` tiers (a bronze axe fells in fewer blows than a stone axe; a pick takes at least 5 times as many, gives kindling and thatch, no sticks, no wear; a stone pick breaks a log in 7 blows into a pile of 5 kindling, no blocks); `test_ore.gd`, `test_flint.gd` (now a stone pick, one piece a blow), `test_bronze_path.gd` send the held slot; 40 tree/trunk/stump/log calls in 11 tests send the axe slot through `src/worldgen/tools/held_tool.gd`.

Dave to check: look at a boulder (it says Rock). Hold the Stone - Pickaxe on a boulder: a stone every blow; a Stone - Axe: a stone every two blows, dulling fast. Chop a tree with the pickaxe: very slow, kindling and thatch only, no wear; break a log on the ground with it: a pile of kindling.

## Review

Gate review 1 (independent gate-reviewer agent) of d7c936e: FAIL on gate rules: (1) the protocol change needs Dave's approval (RULES.md "Big changes need Dave's approval first: ... the network protocol"; Class C in DECISION_AUTHORITY.md); asked on the thread, pending; (2) no Godot run yet. Code findings 3 (third-person facing from the skeleton, wrong for the fallback body), 4 (first-person spear in view at rest), 5 (eating with a log on the shoulder) and 9 (stale comment) fixed. The boulder and wood changes share one bump (now 115; the hotbar fix took 112, far smoke 114).

Gate review 2 (32530ba): no new must-fix. Done: checks that an axe only on the hotbar (nothing in hand) chops no tree, trunk, stump or log; a "You need an axe in hand to work wood." line when wood is struck without one; comment provenance quotes Dave's notes; FELLING_DESIGN.md network line updated. Follow-up (reported, not in this PR): `_mine` (swinging at bare rock ground) still needs and wears the first axe on the hotbar, so a held pick there wears the axe.

Gate review 4 (73aeadc, tool tiers): PASS, no must-fix. Fixed after it: the boulder tool is read before its wear (a stone pick breaking on a blow kept that blow's ore); a pick on a trunk gives no seeds or roots either (kindling and thatch only); the iron and steel pickaxe descriptions say three and four stones a blow (text only, no item change); the stale boulders.json note line; no slot snapshot for zero wear.

Gate review 5 (dev merge with the hotbar fix, c5d5d2f..4f7eac1): one must-fix, the 113 note in PROTOCOL.md still said an old client is refused by version 112; fixed, and 113 put first (newest first). Net change against dev is the same 32 files as before the merge.

## Test evidence

| Check | Ran | Result |
|---|---|---|
| `tools/merge_check.py` (base origin/dev) | yes, cloud (Python only) | all clear |
| `tools/tests_for_diff.py` selection | yes | 350 fast + 8 timing + 2 pictures + 3 checks (protocol change: all fast tests; kept per TEST_GATES) |
| Godot tests, full plan (352 fast, 8 timing, 3 checks) | yes, Dave's PC ManlandRyzen5, headless, separate worktree, at `3a7808c` (dev with the hotbar fix merged) | 358 pass, 2 fail: `test_server_items` did not compile (a local declared twice, my test edit; fixed in `4f7eac1`, then PASS); `test_flora_density` (timing lane, not touched here) timed out at 300 s with all its checks passing so far, rerun alone below. The seven tests for this change pass: test_spear_hold, test_stump_chop, test_server_items (at 4f7eac1), test_flint, test_ore, test_bronze_path, test_felling_time. Checks: validate_items 0 errors, look names all drawable, no new warnings. |
| `test_flora_density` timeout | yes, alone, at 4f7eac1 and at origin/dev 468ae5b | times out at 300 s on dev too, same place, no failed check: already on dev (it took 104-152 s on 6 Nov), not from this change |
| Final check after the dev merge (far smoke, protocol 114; this change now 115), `ba96633` | yes, Dave's PC, one at a time | 9/9 pass: test_spear_hold, test_stump_chop, test_server_items, test_flint, test_ore, test_bronze_path, test_hotbar_keys, test_handcart, test_felling_time. local_check: new-warning counts in files of other PRs and in server_items.gd lines that blame to dev, none from this change |
| Pictures (held_item, inventory_view) | no | cannot be judged headless: Dave's playtest |

## Follow-up: every swing uses the tool in hand (Dave 13 Nov 2026)

Dave: "if you do an attack on anything at anytime it needs to know what weapon is in hand"; "swinging any tool or weapon needs to always check the tool or weapon first because they might have bonuses to be able to hit stuff." Base `origin/dev` 869c5a3 (protocol 116). Status: NEEDS PLAYER VERIFICATION.

Audit of every server swing path (`server_items.gd`):

| Swing | Before | Now |
|---|---|---|
| Bare rock ground (ACT_MINE) | first axe on the hotbar | the pick or axe in hand (a = slot + 1, protocol 117); a pick wears 1 a blow, an axe 5 (data) |
| Bush (ACT_HIT_SHRUB) | first pick or axe on the hotbar, chosen by a pick flag | the tool in hand decides: a pick digs it up, an axe chops it (at.x = slot + 1) |
| Chopping block (E, ACT_USE_STRUCT) | first axe on the hotbar | the axe in hand (count = slot + 1) |
| Carcass (ACT_PROCESS) | first knife on the hotbar | the knife in hand (at.x = slot + 1) |
| Hammer repair, blueprint fill (ACT_REPAIR_STRUCT) | first hammer on the hotbar; reach from the heaviest | the hammer in hand, its tier sets the reach (b = slot + 1) |
| Spade dig and fill, spade size and tier | first spade on the hotbar | the spade in hand (a, already sent) |
| Hoe path, smooth, till, grade, survey marker | first hoe on the hotbar | the hoe in hand (a, already sent) |
| Animal strike, throw, bow, fishing, net, ice hole, planting a bush; trees, trunks, stumps, logs, boulders | already the item in hand | unchanged |

One resolver: `_held_tool` (on the hotbar, not broken, of the class) and `_swing_tool` (the same, saying why not). The replaced lookups are gone (`_say_tool_missing` deleted, the swing paths above no longer call `_has_tool` / `_tool_slot` / `_wear_tool` (the non-swing paths below still do)). No bonus system or item property was added.

Left as they are (not swings; reported to Dave): the tool a recipe needs (any on the hotbar), E-key plant gathering and garden-bed harvest, a surveyed road building itself as you walk, the goal hints, and placing a blueprint (the heaviest hammer on the hotbar sets what can be built and the building reach).

Tests: every test call of these actions sends the held slot through `held_tool.gd slot_of` (88 calls in 12 tests); `test_server_items.gd` adds a pickaxe in hand mining bare rock with the axe on the hotbar (pick wears, axe does not), nothing in hand mining nothing, a dig with the spade only on the hotbar refused, and the chopping block with the axe only on the hotbar refused ("in hand"); `test_station_storage.gd` checks a wooden hammer in hand sets the reach with a steel one on the hotbar. `art/playthrough/probe_hunt.gd` sends the knife in hand.

Evidence (head 8f0c9a5e14b22bf9731aedafeaa78bc65e20c7de, base dev 869c5a31a, PR #1067): independent gate review APPROVE after two fix rounds; GitHub CI green. David4 (Godot 4.7.2 voxel headless, fresh import, throwaway user data), 13 Nov 2026: 16 key tests one at a time 16/16 pass (including test_station_storage); selector set 354 fast + 8 timing 362/362 pass, no retries, 809 s (test_flora_density pass, 272 s); play-role startup smoke 0 SCRIPT ERRORs, 0 ERROR lines, known exit 134 at quit. Logs on David4: /work/lanerun/swing_focus, swing_plan, swing_extra. This commit adds only this paragraph.
