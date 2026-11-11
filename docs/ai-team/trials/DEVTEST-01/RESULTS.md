# DEVTEST-01 — first controlled development trial: results
**Date:** 11 Nov 2026. **Requested by:** Dave, project thread "Dynasty — First Controlled Development Trial" (19:04 UTC): fix the approved "spend the lowest group member first" issue as a test of the AI Team OS. All other development stays frozen.
**Machine:** Dave's PC (ManlandRyzen5, Windows 11), checkout `C:\GodotProjects\DynastyALWL`, thread run by Remote Control. Godot 4.7.2 voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe` (`v4.7.2.stable.custom_build.ed1daf0bf`) and console build `Godot_v4.7.2-stable_win64_console.exe`.

## Outcome
- **Bug fixed:** yes. Every group cost now spends its lowest member first (tier, then material, then value), the same ranking the take-down refund already used, now one shared function (`ItemTable.spend_order`). Source priority between ground stock, pack and containers is unchanged. Details: `HANDOFF.md`.
- **Tests:** PASS. 182 affected tests, 0 fail, 0 skipped, 0 retries (`evidence/affected_tests_full2_summary.txt`, plan `evidence/affected_plan.json`); `validate_items` 0 errors. New checks fail with the fix disabled (8 + 7 + 1).
- **Independent review:** PASS, no Must-fix (`REVIEW_1.md`).
- **Startup smoke:** world load and join PASS; headless exit abnormal on both dev and the candidate (below).

## Evidence (TEST_GATES format)
| Field | Value |
|---|---|
| Task ID | DEVTEST-01 |
| Base SHA | `be491ba638610f23761d43be78787179c48e58fe` (`origin/dev` = `origin/main`) |
| Candidate head (code) | `1726dc29d10ad073c8de69568c9b66e28fed2fa4`; tests ran on the working tree before that commit, and `git diff 1726dc29d -- src` is empty (same code) |
| Runner | temporary Systems Engineer agent (tests), coordinator thread (smoke), both on this PC |
| Test plan | `tools/tests_for_diff.py --paths <5 changed files>` -> 178 fast + 4 timing + `validate_items`; `tools/run_tests.sh --jobs 3` |
| Counts | 182 pass, 0 fail, 0 skip, 0 flakes; single runs `test_build_stock`, `test_ingredient_groups` PASS |
| Reviewer | independent `gate-reviewer`, PASS |
| Visual | none changed; not visually checked |

## Startup smoke (TEST_GATES dev gate step 3)
`godot.windows.editor.x86_64.exe --headless --path . --quit-after 6000 -- --role=play --test`:
| Build | Runs | Join / world load | Script errors | Exit |
|---|---|---|---|---|
| candidate `1726dc29` | 2 (`evidence/smoke2`, `smoke3`) | PASS (welcome, ground column answer, animals, flora load) | 0 | 139 (segfault after quit) both times |
| dev `be491ba6` | 2 (`evidence/smoke_base3`, `smoke_base4`) | PASS (same) | 0 | 127, no clean shutdown lines, both times |

Neither build exits headless cleanly after joining a world, so the abnormal exit is pre-existing; the exit code differs (139 vs 127) and the cause is NOT DETERMINED. The changed code is not called by the client in this run (the client only counts; the paying code is server-side and no crafting or building happened). Recorded as a known issue, not a PASS. Dave plays with F6 in the editor; the in-editor run was not tested.

Side effect: the first smoke run on a throwaway clean checkout of dev (to get a baseline) started a headless terrain server that did not quit (pid 2692, port 24600). Agents may not stop processes on this PC, so Dave must end it (Task Manager) before playtesting, or F6 would join that old server. The throwaway checkout is in the session scratchpad, registered as a git worktree; `git worktree prune` after its folder is gone.

## AI Team OS observations
| Check | Result |
|---|---|
| Fresh Systems Engineer on assigned model/effort | Spawned fresh with `sonnet` / `high` (ROLE_CATALOG "Sonnet high for bounded changes"). The repo's `.claude/agents/systems-engineer.md` could not be selected by name because this session read its agent list before checking out the branch that has `.claude/agents/`; the agent was told to read and follow the file instead. Serving model not observable. |
| Read before change | Brief, constitution, decision authority, Ponytail, handoff template, design pointers. Library `decisions_pending.md` / `Steve_handoff_11Nov.md` not reachable from this machine or project: SOURCE UNVERIFIED. |
| Ponytail | Engineer ran `ponytail-review` on its diff, fixed a scale finding (sort moved off the counting path) and added a missing test; reviewer confirmed. |
| Scope | One file outside the brief (`item_table.gd`), justified and recorded. Dave's uncommitted files untouched. |
| Gates | Tests and review PASS; smoke partly PASS (exit issue above). |
| Retirement | Engineer and reviewer ended after their outputs were saved and checked; nothing lives only in their chats. |
| Not done | `BUILD_STOCK_M` comment fix (paired with this item in the handoff list, but not in Dave's authorization). Library copy: SYNC PENDING (old Library not reachable). |
