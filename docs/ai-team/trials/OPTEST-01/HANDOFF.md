# Task handoff — OPTEST-01
- **Coordinator note (after REVIEW_2 PASS):** before building Option 1, apply REVIEW_2's Should-fix: match `filled` on centre within a tolerance, not on radius (the client cannot know `0.9 * cbrt(pieces)`).
- **Revision 2 (11 Nov 2026, fresh `task-investigator`, after REVIEW_1 FAIL):** re-verified the checkpoint against the code at `b03ac553`; corrected the conclusion to (3) NOT met, the fix to a two-option proposal, the decision level to B/C (not A), the stony_soil naming, the `_once` dedupe claim, the `decisions_pending.md` claim and several line numbers. Why: the first version's hook on `_on_filled` would sound for hoe/grade/cave-in fills (Must-fix 1), and its other statements were overstated.
- Task: does the spade fill sound still need its `shortcut:`? Role: `task-investigator` (sonnet). Status: **COMPLETE** (investigation only; no fix applied; the fix needs a decision, see Decision). Cloud checkout.
- Code: base SHA `b03ac553716032f907fbaeb62078fd9e677153b9`; `git rev-parse HEAD` in the checkout returned the same value again in revision 2 (read-only); `git status --short` showed only `?? docs/ai-team/trials/`. Branch `claude/project-thread-dxi3fw`. No PR. Changed files: this handoff only.
- Design authority: no design change involved by this report. `docs/PONYTAIL_RULES.md` (section 2, `shortcut:` convention), `docs/SOUND_MAP.md`, `docs/handoff/JASON_NEXT_TASKS.md`, `PROTOCOL.md` (repo root). No decision found that restricts shovel sounds (see Unverified claim).

## Answers
**(1) Does the fill path give the client a result it can use?** There is no reply to `ACT_FILL`. There is one shared broadcast that carries the material but not who or what caused it.
- Click: `src/client/held_item.gd:2137` sends `Net.ACT_FILL`; `:2140` plays `shovel_load(false, ...)` at once (the shortcut line). Sound plays even when the server refuses.
- Server: `src/stream/server_items.gd:1116` dispatches to `_fill` (`:2461`). It picks the pack material in `digging.json` "fill" order (`:2482-2490` region), maps it through `FILL_SOIL` (`:2457`: soil 5, sand 1, gravel 2, clay 4, stone **9**) and calls `fill_ground` (`:2507`). If the ground refuses, shovelfuls are handed back (`:2509-2510`).
- `fill_ground` is `_fill_ground` (`scenes/terrain_server/terrain_server.gd:2326`). On a real ground change it does `net.filled.rpc(center, radius, material)` (`:2341`) to everyone. An identical repeat returns false without broadcast (`:2329`, `_fill_last`).
- Client: `src/stream/terrain_net.gd:246-247` emits `filled_received`; `terrain_client.gd:816` connects it to `_on_filled` (`:1730`), which takes `_material` and ignores it; no sound.
- Refusal feedback to the actor: `_reject(peer, 0/1)` (`:2465`, `:2469`, too far / no spade) is a reason code; cooldown (`:2474-2475`) and `pieces < 1` (`:2501`) give nothing; no pack material gives a text notice (`:2489`). The `filled` broadcast fires only when ground changed.
- **`filled` is not spade-specific.** `_fill_ground` is also called by the hoe smooth (`server_items.gd:2706`), grade (`:2914`, `:3004`, always material 5 soil) and cave-in rubble (`terrain_server.gd:2175`). So a client cannot tell a spade fill from those using `filled` alone. `PROTOCOL.md:15` defines `filled` as (center, radius, material) only; `PROTOCOL.md:81` and `:155` document ACT_FILL / protocol 30.

**(2) Material-aware shovel sounds that exist.**
- `src/client/placed_sounds.gd:128-129`: `shovel_load(stone: bool, at)` plays `stone_load` or `soil_load` (levels `:32`; clips from `assets/audio/make_placed.py`). Only caller: `held_item.gd:2140`, always `false`. No `stone_load` call anywhere (grep over `*.gd`). No test of `shovel_load` found (`test_slot_sounds.gd` has no "shovel").
- `placed_sounds.gd:_once` (`:214-239`) has **no dedupe or merge guard**; each call spawns a player. By contrast `src/client/dig_sounds.gd:33-34,81` merges (`MERGE_MS` 150 ms, `MERGE_M` 6 m). Only the server's `_fill_last` drops an identical repeat.
- Dig path is material-aware separately: `terrain_client.gd:1701-1706` `_on_dug` calls `sound.dig.dug(...)` (dig_soil/sand/gravel/clay/rock via `SoundStage.material_at`). The hoe borrows `hit_spade_soil` (`held_item.gd:2121-2124`).
- `docs/SOUND_MAP.md:20` "wired, to hear (always the soil scoop)", `:66` "fill plays the soil scoop: covered", `:50` stone_load was ported on purpose.
- Stale comment `placed_sounds.gd:127` ("soil or stone dragged onto it") is from the old load design removed by item 682 (`docs/mirror/tech/BUILD_LOG.md:382`: "Kathleen's shovel_load sound hook is unused now").

**(3) Is the revisit condition met today? NO (revision 2 corrects "met in substance").** The condition is "when the fill result carries its material". There is no per-click fill result. The only carrier is the shared `filled` broadcast, which has the material but cannot be attributed to a spade, and which also fires for hoe, grade and cave-in. Wiring it directly would break sound (see Fix options). `JASON_NEXT_TASKS.md:9` item 3 asked for a "server reply to ACT_FILL carries the material"; that reply does not exist. So the `shortcut:` still stands until one of the options below is chosen.

## Unverified claim: "Dave said the shovel must only ever use the soil scoop sound"
**UNVERIFIED RESTRICTION, SOURCE UNVERIFIED** (`DOCUMENT_AUTHORITY`/`DECISION_AUTHORITY` "Suspected obstruction"). No source given. Searched in revision 2: `docs/` text for "soil scoop", "only ever", "shovel must" (hits are only the `shortcut:` comment, `SOUND_MAP.md`, `JASON_NEXT_TASKS.md` and unrelated pages: wood_tier_note lime, fauna audit, field journal); `docs/knowledge` for shovel/scoop: none. **`decisions_pending.md` was NOT SEARCHED: it exists neither in this checkout (`find /` found none) nor in `/mnt/project-files`** (the earlier version wrongly said it was grepped). Design docs under `design/` are likewise inaccessible here. The only "always the soil scoop" text is an author's `shortcut:` limit and a description of current state; `stone_load` was ported on purpose and the JASON task asks for stone vs soil. Not treated as blocking. If Dave did say it, the coordinator should get his exact words before any change; the question is cheap to ask.

## Fix options (proposals, NOT applied; freeze ON)
The earlier "play the sound in `_on_filled` for material 9" proposal is **withdrawn**: it would scoop for every hoe stroke (up to ~4 fills each, on top of the hoe's own click at `held_item.gd:2121-2124`), every grade and every cave-in, to every client, with no merge guard.
- **Option 0, keep as is.** Leave the `shortcut:`; update nothing. Cost: soil scoop on every spade click even if refused or stony. Level A (no change).
- **Option 1, actor-side matching, no protocol change (B at best).** In the actor's client only, remember the last ACT_FILL click (hit point + 0.1 m, time, a short window). When `_on_filled` arrives with a matching center and radius within the window, play `shovel_load(<stone?>, center)` once, and clear the pending record (the clear is the dedupe). A refusal or a hoe/cave-in fill never matches, so stays silent. Design consequence to state: **other players hear nothing** (today the sound is also local to the clicker, so this is no regression). Remaining judgement calls: which `FILL_SOIL` result is "stone". Material 9 is **`stony_soil`** (`data/tables/soils.json:126-128`), reached from the pack item "stone"; a client `material == 9` duplicates the server table, so a named constant/shared lookup is needed rather than a literal. Clay and gravel stay on the soil scoop; more clips are a sound-design call. Reach is small: `held_item.gd` (pending record, delete `:2139-2140` and the shortcut), `terrain_client.gd` `_on_filled`, `SOUND_MAP.md:20,66`, `JASON_NEXT_TASKS.md` item 3.
- **Option 2, protocol discriminator (C).** Add an argument to `filled` (source/kind) or a new actor reply, so every client can sound a spade fill and all hear it. Breaking RPC change: protocol bump (`PROTOCOL.md:15,155`) and the test/doc ripple.

## Decision (`DECISION_AUTHORITY.md`)
Corrected from "A" in revision 1 (review finding 2).
- Option 0: A (no change).
- Option 1: **B at best** (local design refinement: coordinator/subsystem lead, a DELEGATED entry with before/after; no Dave approval if low-risk and it fits accepted design). Stone-vs-soil mapping and "others hear nothing" belong in that entry.
- Option 2: **C**, **needs Dave** (breaking RPC, protocol change) plus a coordinator PROTOCOL decision.
- **Needs Dave or a protocol decision: only Option 2** (and Dave's go for any build while the freeze is ON, which applies to every option except 0). Recommendation: Option 1 when the freeze lifts; ask Dave only if he wants other players to hear fills or if he did say "soil scoop only".

## Tests a fix would need
- Run status for everything below: **NOT RUN** (Godot forbidden; I executed no tests).
- Existing `src/worldgen/tools/test_server_items.gd:817-857` covers ACT_FILL spend/refusal/hand-back (not re-run; no change needed for Option 1).
- Needed for Option 1 (headless where possible): after an ACT_FILL click, a matching `filled` with material 5 calls `shovel_load(false, ...)` once; with the stony-soil id calls `shovel_load(true, ...)`; **negative cases**: no pending click, a `filled` that does not match (hoe smooth, grade, cave-in rubble), a refused click with no broadcast, a second `filled` after the pending record was consumed: no sound each. Plus a `--sound-log` PC check (`JASON_NEXT_TASKS.md:7`) by Dave/Jason with a stony fill, soil fill and a hoe stroke (must stay silent apart from the hoe click).
- Option 2 additionally: client/server RPC parity tests, `PROTOCOL.md` update.

## What did NOT run / defects / risks
- No Godot, no tests, no sound heard.
- Revision 2 re-read the code cited above and `soils.json:126-128`. Not read in detail: `Layout`, whether `_on_filled` has other side effects relevant to ordering, and the audio clips themselves.
- Option 1 risk: matching is heuristic (a fast second click before the broadcast returns could overwrite the pending record; the server cooldown of 0.7 s shared with digs, `server_items.gd:2474`, bounds this). Latency: the sound follows the server round trip instead of the click; this is the stated intent of the shortcut.
- `ponytail-review` was not run on a diff (no diff). Its method was applied to the investigation: no new abstraction, replaced code is deleted, a client literal for material 9 is avoided.

## Attempts that failed / research
First version's fix (hook `_on_filled` for all fills) was found wrong by REVIEW_1; do not repeat it. Key finding: the `shortcut:` condition is not met, and the cheapest honest fix is client-side matching.

## Next action for a fresh agent
1. Coordinator: choose the option (Option 1 recommended; ask Dave only for Option 2 or if the "soil scoop only" claim is real). 2. After Dave lifts the freeze: implement on a task branch, add the tests above with negative cases, run `ponytail-review`, request `gate-reviewer`, arrange the PC listening check. 3. Resolve the stale comment `placed_sounds.gd:127` in the same change.

## Review resolution (REVIEW_1)
1 hook fires for every fill: accepted, proposal withdrawn, options rewritten. 2 level: accepted (B/C). 3 material 9 = stony_soil: accepted. 4 no `_once` dedupe: accepted. 5 "met in substance": accepted, answer (3) now NO. 6 `decisions_pending.md`: accepted, NOT SEARCHED. 7 line numbers: corrected (2341, 2465/2469, 2474-2475, 2489, 2501). 8 stale comment: noted.

## Docs updated / review status
- Docs updated: this file only. Repo commit: none (coordinator commits). Library sync: SYNC PENDING.
- Independent review: REVIEW_1 FAIL addressed above; revision 2 not yet re-reviewed, not self-certified.
