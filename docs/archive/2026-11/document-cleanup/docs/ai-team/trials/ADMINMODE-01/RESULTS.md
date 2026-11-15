# ADMINMODE-01 — Admin Mode off by default: results
**Date:** 11 Nov 2026. **Requested by:** Dave, project thread "Make Admin Mode off by default" (19:53 UTC). Authorization covers this task only; other development stays paused. **Machine:** Dave's PC (ManlandRyzen5), checkout `C:\GodotProjects\DynastyALWL` by Remote Control; Godot `4.7.2.stable.custom_build.ed1daf0bf` (voxel build). Dave's uncommitted `.import`, `.uid` and asset files were left untouched and are not in any commit.

## Dave's requirement
Admin Mode OFF by default on client and server for every new play session; normal crafting enforces ingredients, known recipes, stations and other approved requirements; free crafting only after Esc > Admin switch-on; switching off restores normal crafting at once; client and server agree; Admin Mode stays usable for development; tests on isolated prefilled inventories; independent review; dedicated branch, no `main`.

## Root cause
- Server: `server_items._admin_mode_off` was opt-out, so every admin (everyone in local play, `admin_setting.json` `check_admin: false`) crafted free from login.
- Client: `inventory_view._free_craft()` returned `admin_craft or not AdminScript.check_enabled()`, so in local play the list was always free even with the switch off; `admin_craft` also defaulted to true.

## Change (branch `claude/project-thread-ta3l76`, base `dev` `7f8aabf4f`)
| Commit | What |
|---|---|
| `5813f238f` | Server opt-in `_admin_mode_on` (cleared at logout and on Play as a new player; `free_craft_for` false when unset); `_craft_tick` drops a free entry while Admin mode is off. Client `admin_craft` starts false and is the only thing that makes the list free; Esc switch shows off when unknown; the Admin kit list shows only while Admin mode is on. New `test_admin_mode_crafting`; old tests lose their forced-off lines. |
| `b8fb8db95` | Item catalog freeze recorded as a standing ruling (`DECISION_AUTHORITY.md`; pointers in `item-data`, `gameplay-designer`, `START_HERE.md`). |
| `1b5390862` | Review fixes: switching off purges queued free crafts at once (`_drop_free_crafts`); non-admins are told "Admin mode is for admins."; the `]` starter-items key gives only while Admin mode is on. |

Crafting paths audited (with the reviewer): craft queue, known/learn check, station check and step-to-station, stock incl. ground and containers, parts chains (`CraftPlanner`, ctx `free: false`), kept tools, `wears_tool`, the tick, queue save/load, client greying (`_can_craft`, `max_makeable`, `_station_ok`, recipe list). No item or recipe data changed (catalog freeze).

## Evidence (TEST_GATES format)
| Field | Value |
|---|---|
| Task ID | ADMINMODE-01 |
| Base SHA | `7f8aabf4f61b0d7dc307dba415506493b1354e15` (`origin/dev`) |
| Code heads tested | `5813f238f` (full plan), `1b5390862` (targeted re-run) |
| Plan | `tools/tests_for_diff.py origin/dev HEAD` at `5813f238f` -> 332 fast + 8 timing (`evidence/plan.json`); `tools/run_tests.sh --jobs 3` |
| Full plan | 339 pass, 1 fail: `test_flora_density` timed out at 300 s under 3-job load; alone it PASSES in 387 s (`evidence/flora_density_alone.result`). Known slow timing-lane test (`tools/test_lanes.json` note, 9 Nov). `evidence/suite_5813f238.log` |
| After review fixes | 16 targeted tests PASS (new test, server_items, new_player, auto_craft, craft_stock, bulk_ops, goals, logs_carry, lumber_route, learn, stations, showroom, first_hour, playability_bot, save_compat, items_persistence): `evidence/targeted_1b539086.log` |
| New test fails on old code | 19 FAIL with `dev`'s `server_items.gd` and `inventory_view.gd` (`evidence/new_test_on_old_code.out`) |
| Startup smoke | `--headless --quit-after 6000 -- --role=play --test` at `1b5390862`: world load and join PASS, 0 script errors, exit 127 (the known abnormal headless exit, same as dev in DEVTEST-01). `evidence/smoke_1b539086.txt` |
| Reviewer | independent `gate-reviewer`: PASS on `5813f238f` (3 Should-fix, all handled in `1b5390862` or sent to Dave), PASS on the `1b5390862` delta, no findings |
| Visual / UI | Esc > Admin switch and recipe-list greying NOT visually checked in the editor |
| Static | `tools/check_ai_team_package.py` fails on this Windows checkout only because CRLF `SKILL.md` copies differ byte-wise from the LF skill ZIPs (pre-existing, no skill touched); CI on Linux is the gate for it |

## Open for Dave
- `ACT_ADMIN_GIVE` (the server's admin give) still works with Admin Mode off for any admin, which in local play is everyone; only the client buttons (`]` key, Admin kit list) now require Admin Mode. Gating the server too would break about 30 smoke and self-test callers that give test items without switching Admin Mode on. Recommendation: keep it as the admin/test channel (`PROTOCOL.md` already calls it "tests only") and set `check_admin: true` before any public server.
- A non-admin on a server with `check_admin: true` who flips the switch sees a green list until a craft is refused (the server now tells them); the server stays authoritative.
