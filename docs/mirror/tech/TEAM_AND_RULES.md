# Team and rules, all in one place (Guru_003, 2026-10-23 18:40 UTC; Dave asked 18:31). Update when anything changes.
Index: 1 Team and roles | 2 How we talk | 3 Daily rhythm | 4 Job flow (BP-T50) | 5 Branches, merges, builds | 6 Bakes | 7 Testing | 8 Dave's rules | 9 Code rules | 10 Where things live
## 1. Team and roles
| Name | Where | Owns |
|---|---|---|
| Dave | owner, plays on his PC, voice user | decides design; tests only at night; the only person who needs to give permission for new websites |
| Coordinator (Claude, project chat) | cloud | relays between threads, memory, reminders, moderator checks, reports to Dave |
| Tyler_Guru | cloud thread | decides who does what: reviews action plans and gives GO, merges branches, numbers builds, QA page, process and docs, answer sweeps, bake scheduling, approvals |
| Steve_ProblemSolver | cloud thread | server, network, HUD, performance, water sim, saves, look rig |
| Sonny_WorksDep | cloud thread | world: ground, Terrain B, island shape, water draw, bake plans |
| Sal_Crafts | cloud thread | items, crafting, building, animals, NPCs |
| Kathleen_ArtisticDirector | cloud thread | art, models, animation, sound |
| MikeW_LocalAgent | Remote Control session on Dave's PC | tests, renders, local_check, bakes, backups, clips (second clone C:\GodotProjects\DynastyALWL_test) |
Thread names count iterations: Name_NNN (a fresh thread each day, see section 3).
## 2. How we talk
1. Cloud threads CANNOT message each other. Everything goes through the coordinator, who relays.
2. Anything Dave must decide, test or do = a QA card (his to-do list, BP-T44), sent through Tyler who adds a recommendation (BP-T50). Cards: Yes/No + Why-not, TEST/PICTURE + Notes; one question per card; numbered steps for anything Dave does; never remove a card he may be answering.
3. Dave's replies: SUCCINCT, "Test done: 1 pass, 3 fail"; point form numbered for anything he must do; times in Atlantic (ADT = UTC-3 until 1 Nov, then AST = UTC-4); notify only for things needing Dave and "Finished:" items.
4. Dave's commands: status, audit, goodnight, idea.
5. Threads write notes in /mnt/project-files/ (shared folder, master docs in tech/, mirror in repo docs/mirror/).
## 3. Daily rhythm
- 8:00 AM Atlantic: every thread writes handoff/<Name>_<NNN>_HANDOFF.md, updates its tech/OPEN_<Name>.md, pushes; Tyler merges and rewrites the NOW block in HANDOFF.md and tech/DAY_LOG.md; the coordinator resets threads (fresh session reads HANDOFF NOW block, BIG_PICTURE, own handoff, OPEN file, DECISIONS tail). See tech/DAILY_HANDOFF.md.
- Hourly moderator check (coordinator): no thread idle, tell Dave when a thread waits on a permission prompt.
- Dave tests at night after the backup. When Dave says done: finish, push, handoff; Tyler merges ready branches; MikeW full check then backup (game and server closed). 8:18 pm wrap-up and 9 pm backup routines.
## 4. Job flow (BP-T50, Dave 23 Oct 18:31)
1. Every thread may do anything on its OWN job list.
2. Before creating a branch the thread writes an ACTION PLAN (goal, files, how, test, label, needs Dave?) in tech/ACTION_PLANS/<Name>_<topic>.md.
3. Tyler researches and replies with the best way and GO (aim: same hour). No GO yet = start the next item on the list.
4. After GO: read and write wherever the job needs. Ask Tyler nothing else except QA cards.
5. Nobody is ever blocked (BP-T44): a waiting thread moves to the next item and never touches another thread's code.
## 5. Branches, merges, builds
- Work only on claude/generator-v2 through per-thread branches claude/<name>-<topic>; never touch main (Dave merges). A branch with "held" in the name never merges.
- Tyler merges with tools/merge_branch.sh <name> (stops on conflict or failed merge_check; never commit with UU). Fetch with the full refspec +refs/heads/claude/*:refs/remotes/cl/*. Check git status before commit (no crash logs).
- Every change carries a label in BUILD_LOG: RUNTIME (no restart), RESTART (close game fully after Pull), BAKE (needs tile bake). Build number in src/shared/build.gd + BUILD_LOG + mirror + HANDOFF HEAD line. Merge guard CI runs on generator-v2.
- tools/local_check.sh: warning baseline 233 (only Tyler rewrites), zero new warnings. Dave: GitHub Desktop Fetch origin, Pull; close the game fully first.
- After hours (BP-T43): only Dave's asks of that day; Tyler decides merges so Dave's pulled build does not change while he plays.
## 6. Bakes
- 1-tile test bakes: no approval, MikeW in second clone, at least 2 h apart, never committed. 9-tile bake: Tyler batches, tile copy outside repo first, Dave commits the .tile files himself (BP-C23), Sonny re-settles water, QA card tells Dave to press Clear blocks. Never bake or commit tiles in the cloud. TERRAIN_VERSION change ships only with a bake.
## 7. Testing
- Team tests first (BP-T46); only human-judgment items go to Dave. tech/TEST_RECIPE.md: plan template, look down, step back about 1 m, expect-and-stop (BP-T49). Look rig tools/look_rig.sh, admin showroom at spawn (BP-T45). "No chasing ghosts": fix only with log, repro or screenshot.
## 8. Dave's rules
- Safe place (BP-T42): the game never says anything that might divide people; no labels for groups.
- Dave refuses crash reports/logs in the repo. Design direction thinly discussed = ask one question with recommendation; technical details decide yourself. Plans to Dave are 5 to 10 numbered lines (BP-T36).
- Permissions: only new websites (WebFetch) need Dave (BP-T48); a direct ask is a go. Repo stays PUBLIC until Tyler gives private-repo steps.
- Focus: movement, physics, water, tunnels, ready to play. Parked: scale, QoS, armour, voice, banking.
## 9. Code rules
- Typed GDScript, zero warnings in new code; server and client talk only through src/stream/terrain_net.gd; shared code in src/shared; input changes update CONTROLS.md and pass tools/check_controls.py. Before anything new find its BP entry in tech/BEST_PRACTICES.md (BP-T01..T50, BP-C..).
## 10. Where things live
HANDOFF.md (NOW block), BIG_PICTURE.md, tech/BEST_PRACTICES.md, DECISIONS.md, DAY_LOG.md, DAILY_HANDOFF.md, BUILD_LOG.md, TEST_RECIPE.md, QA_SYSTEM.md, QA_POSTING_HOWTO.md, OPEN_<Name>.md, ACTION_PLANS/, handoff/. QA page: https://dsul3791.github.io/DynastyALWL-QA/
