# Playtest Repair Mission 001: combat and tools (TEST-004, TEST-010, TEST-013)

Owner: thread "Fix spear combat, log carrying, tools". Base: `origin/dev` at `b922cc88a59586dfbd41f806744d9ccedfe2bf26`. Branch `claude/project-thread-r7u4ds`. `main` untouched.

## Ledger

| Test | Status | Why |
|---|---|---|
| TEST-004 spear combat | NEEDS PLAYER VERIFICATION | Root cause found and fixed in code; the spear hold is a visual change nobody has seen yet. |
| TEST-010 log carry | NEEDS PLAYER VERIFICATION | Log raised onto the shoulder and the right-hand tool put away; position chosen from the skeleton, not seen in game. |
| TEST-013 tools and "Forest Humus" | NEEDS PLAYER VERIFICATION | Server now uses the tool in hand; label fixed. Tuning (axe on rock) needs Dave's feel. |

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

Fix:
- The client sends the held pack slot + 1 in the boulder ACT_HIT `count` (protocol 112; `PROTOCOL.md`). The server uses only that tool, which must be on the hotbar, not broken, and have a `boulders.json tools` entry; anything else is refused as no tool.
- Wear uses work kind `"rock"`: axe 5 per blow, pick 1 (existing data).
- Tuning of existing entries only: axe blows per stone are now twice the pick's of the same material (stone 6, bronze 4, iron 2, steel 2; picks unchanged 3, 2, 1, 1).
- A boulder's stones are still fixed by its size; a better tool only takes them in fewer blows (unchanged).

Effect for a Stone - Axe (900 durability) vs Stone - Pickaxe (4500) on rock: axe 6 blows and 30 wear per stone (about 30 stones a life), pick 3 blows and 3 wear (about 1500).

Wood (protocol 112): only an axe works wood (a pick is refused), but every tree, trunk, stump and loose-log blow used the first axe on the hotbar, so a held pick with an axe on the hotbar still chopped. Now the client sends the held slot + 1 in at.x of the tree ACT_HIT and the wood ACT_PROCESS; the server (`_held_tool`) uses and wears only that slot when it is an axe on the hotbar. Not changed: the chopping block (split at a structure) and swinging at bare rock ground (`_mine`, which still needs an axe on the hotbar; reported, not in this fix). Tests: 40 tree/trunk/stump/log calls in 11 tests send the axe slot through `src/worldgen/tools/held_tool.gd`; `test_server_items.gd` adds "a pickaxe in hand does not work a trunk, nor wear the axe on the hotbar".

Tests: `test_server_items.gd` boulder block (held axe with an iron pick on the hotbar: 6 blows a stone, 5 wear a blow, pick untouched; a stone or an empty slot in hand refused), `test_ore.gd`, `test_flint.gd`, `test_bronze_path.gd` updated to send the slot.

Dave to check: look at a boulder (it says Rock); with both on the hotbar, hold the Stone - Pickaxe, then the Stone - Axe: the pick takes a stone every 3 blows, the axe every 6 and wears fast. Say if the axe penalty feels right.

## Review

Gate review 1 (independent gate-reviewer agent) of d7c936e: FAIL on gate rules: (1) the protocol change needs Dave's approval (RULES.md "Big changes need Dave's approval first: ... the network protocol"; Class C in DECISION_AUTHORITY.md); asked on the thread, pending; (2) no Godot run yet. Code findings 3 (third-person facing from the skeleton, wrong for the fallback body), 4 (first-person spear in view at rest), 5 (eating with a log on the shoulder) and 9 (stale comment) fixed. The boulder and wood changes share one bump (112).

## Test evidence

| Check | Ran | Result |
|---|---|---|
| `tools/merge_check.py` (base origin/dev) | yes, cloud (Python only) | all clear |
| `tools/tests_for_diff.py` selection | yes | 350 fast + 8 timing + 2 pictures + 3 checks (protocol change: all fast tests; kept per TEST_GATES) |
| Godot tests | NO | pending a PC run with Dave's go |
