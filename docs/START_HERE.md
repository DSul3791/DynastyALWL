# Start here (Jamie, 1 Nov 2026)

One page for a new agent or a new thread of Dave's. Everything else is found through `docs/DOC_MAP.md`.

## The game
*Dynasty: a life well lived*: a rough-medieval, multiplayer survival and town-building world with a "Sims vibe" (heirs, a dynasty that outlives one character). Godot 4.7.2, GDScript, Voxel Tools, built for weak hardware (1050-class GPU, 8 GB, 30 fps). Repo `C:\GodotProjects\DynastyALWL`, owner Dave (wants SHORT reports). Design: `DESIGN_IDEAS.md`, `DESIGN_PRINCIPLES.md`; short picture: `BIG_PICTURE.md`.

## Who does what (Dave's decisions, source: `MODERATOR_QA_LOG.md`; detail: `docs/handoff/SCOPE_<NAME>.md` and `HANDOFF_<NAME>.md`)
| Agent | Owns |
|---|---|
| Moderator | speaks for Dave, merges into the daily branch, decides reversible choices, QA page |
| Sonny | terrain and water mechanics |
| Kathleen, Kathreen | everything about LOOKS (items, characters, animals, plants, fire, water look) |
| Sal | all items: what they are, recipes, what they do, numbers and text |
| MikeW | plant and animal density, placement, behaviour |
| Steve | sub-system rules and code (character system, comfort, food, warmth, sleep, fire rules, placement, death, hints) |
| Tyler | Q&A testing and tooling (test suite, rigs, stability, merge gates) |
| Dino | playthrough and walkthrough guides; reports to the moderator |
| Jason (Champ) | all sound, including the hooks (which events make a sound); system owners expose events on request |
| Jamie | documentation (this page, `DOC_MAP.md`) |

## Rules
- NEVER merge to `main` until Dave has play-tested and says go. The integration branch is the daily, `DailyDev_20261029`; the moderator merges into it.
- Max 3 heavy Godot jobs at once on this PC: run them through `tools/godot_slot.sh` (`run_tests.sh`/`run_one_test.sh` do it themselves). Never kill Godot processes (one may be Dave's editor).
- Nothing is deleted: unused code goes to `proposed_removals/`, documents to `docs/archive/YYYY-MM/` (`git mv`).
- Dave decides design; reversible choices are decided and logged in `MODERATOR_QA_LOG.md`. Questions for Dave go on the QA page (branch `qa`, `questions/QUESTIONS.md`): pickable answers, one item per card. Never wait for Dave: take the next job.
- Rules in full: `RULES.md`, `docs/PONYTAIL_RULES.md` (water), `CONTROLS.md` (update on any input change). Wire format: `PROTOCOL.md`.

## Two Godot builds (do not mix up)
| Build | Path | Use |
|---|---|---|
| Voxel build (custom, Voxel Tools inside) | `C:\GodotInstaller\godot.windows.editor.x86_64.exe` (the default of `tools/godot`) | world tests, client scenes, running the game |
| Standard exe | `C:\GodotInstaller\Godot_v4.7.2-stable_win64_console.exe` | data and most server tests |

Never judge a full test run on the standard exe: the world tests fail to compile there (wrong build, not a bug).

## Run tests
```
GODOT_EXE=/c/GodotInstaller/Godot_v4.7.2-stable_win64_console.exe tools/run_one_test.sh <test> 300 /tmp/o_<test>    # one test, result in <out>/<test>.result
python3 tools/tests_for_diff.py origin/main HEAD --full > /tmp/plan.json
GODOT_EXE=/c/GodotInstaller/godot.windows.editor.x86_64.exe tools/run_tests.sh --jobs 3 --out /tmp/run --plan /tmp/plan.json   # whole suite
```
Tests live in `src/worldgen/tools/` and `src/water2/`. Latest full-run result: `docs/TYLER_NEXT_TASKS.md` (Tyler's final report); the Phase 2 order is `docs/handoff/PHASE2_RUNBOOK.md`.

## Run the game
From the project folder with the voxel build: `godot --path . -- --role=play` (play is the default role in `scenes/launcher.gd`; starts a server and joins it; pressing Play in the editor does the same). Water: the new Dynasty water (`src/water2`) is the default since 1 Nov; `--water-old` (or Esc > Settings > Gameplay > Old water) runs the old one (checked in `terrain_server.gd` and `launcher.gd`). Dave's play-test page: `MORNING_PLAYTEST_CHECKLIST.md`.

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
| items, recipes, economy | `docs/ITEMS_HANDOVER.md`, `docs/ECONOMY_FIRST_DAY.md` (stones sell 5 for 1 copper through `sell_lot`), `data/items/` |
| death rule | `data/items/death.json` (respawn at the bed until character level 10, then real death) |
| water, terrain | `docs/TERRAIN_WATER_BACKLOG.md`, `docs/DYNASTY_WATER_HISTORY.md` |
| sound | `docs/SOUND_MAP.md`, `docs/handoff/JASON_NEXT_TASKS.md` |
| looks | `docs/KATHLEEN_NEXT_TASKS.md`, `docs/handoff/HANDOFF_KATHREEN.md`, `art/CRITIQUES/` |
| controls, wire format, world files | `CONTROLS.md`, `PROTOCOL.md`, `WORLD_FORMAT_SPEC.md` |
| code and data | `src/`, `data/` (JSON tables), `tools/` (scripts); Dave's questions on branch `qa` (`questions/`) |
| old material | `docs/archive/YYYY-MM/` (nothing is deleted), `docs/mirror/` (frozen 22 Oct copy that tools cite) |
