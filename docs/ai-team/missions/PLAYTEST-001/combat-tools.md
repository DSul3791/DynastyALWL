# Playtest Repair Mission 001: combat and tools (TEST-004, TEST-010, TEST-013)

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

Fix (protocol 112, approved by Dave in the thread, 12 Nov 2026: "yes it needs to know what tool I am using"):
- The client sends the held pack slot + 1: in the boulder ACT_HIT `count`, and in at.x of the tree ACT_HIT and the trunk, stump and log ACT_PROCESS (`PROTOCOL.md`). The server uses and wears only that tool, which must be on the hotbar and not broken; anything else is refused as no tool.

Tool tiers (Dave 12 Nov 2026, in the thread):
- Rock (`boulders.json tools`, now stones per blow): pick stone 1, bronze 2, iron 3, steel 4; axe stone 0.5, bronze 1, iron 1.5, steel 2. A boulder's stones stay fixed by its size; a better tool empties it in fewer blows, so it wears less for the same stone. A fraction carries over in the boulder's `progress`. Wear kind `"rock"`: an axe dulls and wears 5 a blow, a pick 1 ("hitting an axe on a stone will pull down its sharpness rapidly").
- Wood (`drops.json wood_tools speed`, the work one blow does): axe stone 1.0 (the old timing), bronze 1.5, iron 2.0, steel 2.5; pick stone 0.15, bronze 0.2, iron 0.25, steel 0.3. It divides the blows to fell a tree, cut a log off a trunk and break up a stump.
- A pick on wood ("using a pickaxe on a tree or a log will give you thatch, and kindling. not sticks or wood. if you break a log with a pickaxe it will just leave a pile of kindling"): every blow gives 1-2 kindling and 1 thatch, nothing else (no branches, sticks, firewood or bark). A trunk length cut through with a pick leaves a pile of 10 kindling instead of the log; a log on the ground breaks after 1 / speed blows (7 with a stone pick) into a pile of 5 (small log) or 10 (shoulder log) kindling; a stump gives 5 kindling. Wood never wears or dulls a pick (`tool_wear` pick tree, trunk, split 0: "a tree cant dull a pickaxe"). A tree a pick fells still falls and breaks into logs like any other (my reading; say if it should not). The 5 and 10 kindling counts are a first guess for Dave to tune.
- Not changed: the chopping block (split at a structure) and swinging at bare rock ground (`_mine`, still the first axe on the hotbar; reported, not in this fix).

Tests: `test_server_items.gd` boulder block (nothing, a stone or an empty slot in hand refused; iron pick 10 blows = 30 stones and 10 wear; a held stone axe with the iron pick on the hotbar: 12 blows = 6 stones, 60 axe wear, pick untouched; luck doubles at 3 a blow) and a pick on a trunk (kindling and thatch, no sticks, no wear on pick or axe); `test_stump_chop.gd` tiers (a bronze axe fells in fewer blows than a stone axe; a pick takes at least 5 times as many, gives kindling and thatch, no sticks, no wear; a stone pick breaks a log in 7 blows into a pile of 5 kindling, no blocks); `test_ore.gd`, `test_flint.gd` (now a stone pick, one piece a blow), `test_bronze_path.gd` send the held slot; 40 tree/trunk/stump/log calls in 11 tests send the axe slot through `src/worldgen/tools/held_tool.gd`.

Dave to check: look at a boulder (it says Rock). Hold the Stone - Pickaxe on a boulder: a stone every blow; a Stone - Axe: a stone every two blows, dulling fast. Chop a tree with the pickaxe: very slow, kindling and thatch only, no wear; break a log on the ground with it: a pile of kindling.

## Review

Gate review 1 (independent gate-reviewer agent) of d7c936e: FAIL on gate rules: (1) the protocol change needs Dave's approval (RULES.md "Big changes need Dave's approval first: ... the network protocol"; Class C in DECISION_AUTHORITY.md); asked on the thread, pending; (2) no Godot run yet. Code findings 3 (third-person facing from the skeleton, wrong for the fallback body), 4 (first-person spear in view at rest), 5 (eating with a log on the shoulder) and 9 (stale comment) fixed. The boulder and wood changes share one bump (112).

Gate review 2 (32530ba): no new must-fix. Done: checks that an axe only on the hotbar (nothing in hand) chops no tree, trunk, stump or log; a "You need an axe in hand to work wood." line when wood is struck without one; comment provenance quotes Dave's notes; FELLING_DESIGN.md network line updated. Follow-up (reported, not in this PR): `_mine` (swinging at bare rock ground) still needs and wears the first axe on the hotbar, so a held pick there wears the axe.

Gate review 4 (73aeadc, tool tiers): PASS, no must-fix. Fixed after it: the boulder tool is read before its wear (a stone pick breaking on a blow kept that blow's ore); a pick on a trunk gives no seeds or roots either (kindling and thatch only); the iron and steel pickaxe descriptions say three and four stones a blow (text only, no item change); the stale boulders.json note line; no slot snapshot for zero wear.

## Test evidence

| Check | Ran | Result |
|---|---|---|
| `tools/merge_check.py` (base origin/dev) | yes, cloud (Python only) | all clear |
| `tools/tests_for_diff.py` selection | yes | 350 fast + 8 timing + 2 pictures + 3 checks (protocol change: all fast tests; kept per TEST_GATES) |
| Godot tests | NO | pending a PC run with Dave's go |
