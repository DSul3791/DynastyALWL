# Start here (Jamie, updated 5 Nov 2026; roster and QA page updated 11 Nov 2026 for the handoff)

One page for a new agent or a new thread of Dave's. Everything else is found through `docs/DOC_MAP.md`.

## The game
*Dynasty: a life well lived*: a rough-medieval, multiplayer survival and town-building world with a "Sims vibe" (heirs, a dynasty that outlives one character). Godot 4.7.2, GDScript, Voxel Tools, built for weak hardware (1050-class GPU, 8 GB, 30 fps). Repo `C:\GodotProjects\DynastyALWL`, owner Dave (wants SHORT reports). Design: `DESIGN_IDEAS.md`, `DESIGN_PRINCIPLES.md`; short picture: `BIG_PICTURE.md`.

## Who does what (roster on 11 Nov 2026, at the handoff)

**The team is being restructured (Dave, 11 Nov 2026).** The handoff index is `/mnt/project-files/HANDOFF.md` in the project files: one section per agent, and each agent's full file is in `/mnt/project-files/handoffs/<Name>_handoff_11Nov.md`. The roster below is the one that is handing off, so read the handoff files before you trust it.

| Agent | Owns |
|---|---|
| Coordinator | speaks for Dave, staffs jobs, decides reversible choices; never writes code itself |
| Morgan | design documents and the QA page (questions for Dave) |
| Steve | game code and sub-system rules (server_items, building, fire, warmth, lanterns, mining) |
| Sonny | terrain, water, geology and ore bodies, bake verification |
| Jamie | item, recipe and blueprint data, names, id numbers, the encyclopedia, documentation (this page, `DOC_MAP.md`) |
| Kathleen | looks: models, icons, the look rig, art |
| Tyler | merges PRs (only on green CI plus a David4 PASS on the exact head) |
| David4 | the test gate on a gate PC (fastgate.sh); data PRs always gate there |
| Dino | Remote Control on Dave's PC: bakes, shots, world probes |
| MikeW | flora and fauna placement (offline since 8 Nov 2026) |

## Rules
- **Branches (Dave, 11 Nov 2026; supersedes the 2 Nov no-daily-branch rule, kept as history in `docs/ai-team/KNOWN_CONFLICTS.md` #1):** task branches (`claude/<task>`) cut from `dev` -> reviewed, fully committed `dev` for Dave's nightly playtest (Godot F6) -> protected, gated `main` by PR only. Never push or merge to `main` yourself; never merge your own PR. Never delete the `qa` branch (the old QA page, kept as a record). Process: `docs/ai-team/WORKFLOW.md`, gates: `docs/ai-team/TEST_GATES.md`.
- **AI Team Operating System v1.0 (installed 11 Nov 2026):** Claude Code entry `CLAUDE.md`; policy `docs/ai-team/CONSTITUTION.md`; install record and what is still unverified: `docs/ai-team/INSTALL_RECORD.md`. **Game development is paused until Dave explicitly authorizes it** (handoff freeze); the roster and daily rhythm below are the handing-off team, kept for history.
- **Item catalog FROZEN (Dave, 11 Nov 2026):** no discretionary additions, removals, renames or recipe redesigns in `data/items/`; implement, validate and report problems only. Ruling: `docs/ai-team/DECISION_AUTHORITY.md`.
- Daily rhythm (Dave, 2 Nov 2026): (1) start with an efficiency audit of yesterday's work and decide what to improve in workflow; (2) the moderator hands each agent its first 3 tasks; (3) each agent makes its new branch and carries on; (4) when the 3 are done or blocked, the agent finds 3 more in its own purview and continues, until told otherwise.
- Blocked or stuck (Dave, 2 Nov 2026): note it in your handoff, put a card on the QA page (Morgan keeps it; its link is in `/mnt/project-files/HANDOFF.md`, and the list is `design/decisions_pending.md` in the project files), and move straight on to your next job. No next job: find three more that improve the game in your role.
- Priority order (Dave approved 4 Nov 2026): 1 terrain and water, 2 freezes and lag, 3 testing, 4 first-hour bugs, 5 body and movement feel, 6 flora and fauna, 7 Art Direction pass, 8 audio, 9 tuning, 10 guides and docs, 11 new ideas (parked). Bugs Dave finds in play go right after terrain. The ranked list with reasons and the live staffing table are at the top of `/mnt/project-files/BACKLOG.md` (owner: Jamie).
- Staffing (Dave, 4 Nov 2026): work is staffed top-down by priority, not by lane. One agent per job; when yours is done or blocked, take the next open job at the highest rank. Leftovers go to `/mnt/project-files/backlog/<name>.md`.
- NO cloud testing (Dave, 5 Nov 2026): no cloud renders, headless runs or test runs; they use up his tokens. The only testing allowed is on Dave's PC, and only while he is not play testing.
- Knowledge library (Dave, 6 Nov 2026): before you code a system or fix a bug, read its topic doc in `docs/knowledge/` (index: `docs/knowledge/README.md`), then ask Jamie for fresh web research if it is missing or old. Add your lesson to the doc when you finish.
- LAW (Dave, 5 Nov 2026 18:48): absolutely no tests and no bakes in the cloud. All heavy work (tests, bakes, settles, builds) goes to Dave's PC through the coordinator.
- Questions for Dave (Dave, 5 Nov 2026): every open question or input he needs is a card on the QA page (Morgan keeps it; link in `/mnt/project-files/HANDOFF.md`), one card per question.
- Max 3 heavy Godot jobs at once on this PC: run them through `tools/godot_slot.sh` (`run_tests.sh`/`run_one_test.sh` do it themselves). Never start a Godot run without a timeout (hung headless scripts have held all slots); never kill Godot processes blindly (one may be Dave's editor).
- Deleting (decision 61, 11 Nov 2026; Dave's no-flags rule wins): **code that is replaced is deleted**, with no flags and no dead paths left behind. **Documents are archived, never deleted** (`docs/archive/YYYY-MM/`, `git mv`). Other unused files on disk are moved aside to `proposed_removals/`, not deleted.
- Dave decides design; reversible choices are decided and logged in `MODERATOR_QA_LOG.md`. Questions for Dave go on the QA page (Morgan; link in `/mnt/project-files/HANDOFF.md`): pickable answers, one item per card. Never wait for Dave: take the next job.
- Rules in full: `RULES.md`, `docs/PONYTAIL_RULES.md` (engineering method for all code, Ponytail v5.3.3), `CONTROLS.md` (update on any input change). Wire format: `PROTOCOL.md`.

## Two Godot builds (do not mix up)
| Build | Path | Use |
|---|---|---|
| Voxel build (custom, Voxel Tools inside) | `C:\GodotInstaller\godot.windows.editor.x86_64.exe` (the default of `tools/godot`) | world tests, client scenes, running the game |
| Standard exe | `C:\GodotInstaller\Godot_v4.7.2-stable_win64_console.exe` | data and most server tests |

Never judge a full test run on the standard exe: the world tests fail to compile there (wrong build, not a bug).

## Run tests
```
GODOT_EXE=/c/GodotInstaller/Godot_v4.7.2-stable_win64_console.exe tools/run_one_test.sh <test> 300 /tmp/o_<test>    # one test, result in <out>/<test>.result
python3 tools/tests_for_diff.py origin/dev HEAD --full > /tmp/plan.json
GODOT_EXE=/c/GodotInstaller/godot.windows.editor.x86_64.exe tools/run_tests.sh --jobs 3 --out /tmp/run --plan /tmp/plan.json   # whole suite
```
Tests live in `src/worldgen/tools/` and `src/water2/`. Latest full-run result: `docs/TYLER_NEXT_TASKS.md` (Tyler's final report); the Phase 2 order is `docs/handoff/PHASE2_RUNBOOK.md`.

## Run the game
From the project folder with the voxel build: `godot --path . -- --role=play` (play is the default role in `scenes/launcher.gd`; starts a server and joins it; pressing Play in the editor does the same). Water: the Dynasty water (`src/water2`) is the only water; the old hub and its `--water-old` switch were deleted on 9 Nov. The body is Dave's `Dynasty_Base_Male.glb`, the only one since 8 Nov (the old-body switches are gone; `docs/DYNASTY_BODY.md`). In game: K = photo camera, `/` = inspection mode (`CONTROLS.md`). Dave's play-test page: `MORNING_PLAYTEST_CHECKLIST.md`.

## Where everything is (for a new thread of Dave's)
| I want | Go to |
|---|---|
| every document, its owner and verdict | `docs/DOC_MAP.md` |
| who does what now, and each agent's state and next steps | `docs/handoff/SCOPE_<NAME>.md`, `HANDOFF_<NAME>.md`; backlogs table in `DOC_MAP.md` |
| what was decided and why (roles, rulings) | `MODERATOR_QA_LOG.md` |
| what was left to finish at handoff, and the Phase 2 order | `docs/CLOSING_PLAN.md`, `docs/handoff/PHASE2_RUNBOOK.md` |
| unmerged old branches and what to do with each | `docs/OLD_BRANCH_REVIEW.md` |
| the findings from playing it | `docs/handoff/FINDINGS_REPORT.md`, `PLAYTHROUGH_STEP_STATUS.md` |
| design, principles, rejected ideas | `DESIGN_IDEAS.md`, `DESIGN_PRINCIPLES.md`, `DESIGN_REJECTED.md` |
| items, recipes, economy, carry weights | `docs/ITEMS_HANDOVER.md`, `docs/CARRY_WEIGHTS.md`, `docs/ECONOMY_FIRST_DAY.md` (stones sell 5 for 1 copper through `sell_lot`), `data/items/` |
| death rule | `data/items/death.json` (respawn at the bed until character level 10, then real death) |
| water, terrain | `docs/TERRAIN_WATER_BACKLOG.md`, `docs/DYNASTY_WATER_HISTORY.md` |
| sound | `docs/SOUND_MAP.md`, `docs/handoff/JASON_NEXT_TASKS.md` |
| looks, the player body | `docs/DYNASTY_BODY.md`, `docs/KATHLEEN_NEXT_TASKS.md`, `docs/handoff/HANDOFF_KATHREEN.md`, `art/CRITIQUES/` |
| controls, wire format, world files | `CONTROLS.md`, `PROTOCOL.md`, `WORLD_FORMAT_SPEC.md` |
| code and data | `src/`, `data/` (JSON tables), `tools/` (scripts); Dave's questions on the QA page (link in `/mnt/project-files/HANDOFF.md`; the old `qa` branch is a record) |
| old material | `docs/archive/YYYY-MM/` (nothing is deleted), `docs/mirror/` (frozen 22 Oct copy that tools cite) |
