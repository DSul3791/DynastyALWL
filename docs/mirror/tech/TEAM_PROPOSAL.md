# Team structure (ADOPTED by Dave 2026-10-22 14:18 "Make it so"; Guru)

## Threads
| Role | Thread | Owns |
|---|---|---|
| Coordinator | project chat | routing, moderator check every 30 min, Dave's reports, memory |
| Technical Director + Guru | Tyler_Guru_SenDev | tech/ docs, approvals, build numbers, question page and test card, BEST_PRACTICES daily check, HANDOFF.md. Docs only, no game code |
| World | Sonny | ground, loading, tunnels, bracing, collapse, worldgen tests, water sim, ice, swim |
| Items and World objects | Radar | items, crafting, NPCs, animals, buildings, trade |
| Systems | Steve_ProblemSolver (was Tyler_002; on demand) | server, network, HUD, movement, performance, saves, crash hunt |
| Art and Sound | Kathleen_ArtisticDirector | look, animation, audio |
| Local runner | MikeW_LocalAgent (Dave's PC) | warning count, headless tests, GPU/editor checks, long runs |
Retired: Steve, Willy.

## How they work
1. Workers run on demand: start when a job is queued, park with a handoff when idle.
2. Day start: Guru logs the BEST_PRACTICES check; each running thread reads only entries changed since the log date and says "BP read <date>".
3. New kind of job: find the BP entry; none = ask the Technical Director, take another job meanwhile.
4. Cross-thread needs go through the coordinator, one line each.
5. Push: pull --rebase, checks, build number rule, BUILD_LOG line in the same commit.
6. Risky pushes (protocol, saves, shared files) get a Technical Director review first.

## Cloud versus Dave's PC
Cloud: reading, writing, small headless loads, python checks, docs. Dave's PC (MikeW, on demand, batched from TEST_QUEUE): Godot editor, GPU, warning count, long runs, screenshots.

## Reports to Dave
Short, voice friendly: "Finished: <job>", "Test done: X pass, Y fail" with one line per failure, "Question added: <title>", always ending "Still waiting on:". One daily Guru line: "Best practices checked <date>: N entries, M need your decision."

## Owner gaps found when Steve and Willy retired
- Rendering/GPU audit (Willy's RENDER_AUDIT.md, Ultra idle GPU-bound): assigned to Steve_ProblemSolver (performance) with Kathleen_ArtisticDirector for shaders.
- Warning-count tool (`tools/check_warnings.sh`, Willy's): maintained by MikeW, run on demand.
- Reviews of pushes (Steve's): Technical Director.
- Logout flag for collapse (Steve_ProblemSolver), nearest-rest lookup (Radar), flag read in collapse (Sonny): unchanged, Sonny now owns the collapse side.
- Bake bundle steps for Dave (Steve's): Technical Director writes them, Sonny supplies the water/ground part.

## Efficiency review (kept from the earlier version)
Verdict then: not the most efficient with nine always-on threads; the three changes (trim HANDOFF.md, merge Steve+Guru and Willy+Sonny, on-demand workers with a 30 minute moderator) are now applied. Savings were estimated at 30 to 40 percent of recurring tokens (rough, unmeasured). Do not add QA, scale or extra dev threads until the game moves past a friend session.
