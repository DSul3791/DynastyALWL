# Session and task lifecycle
**Status: PROPOSED.**

1. **Create task**: brief must include job ID, context docs, exact expected behavior, files/interfaces allowed, prohibited side effects, priority, tests, owner, reviewer, destination branch and authorized runtime.
2. **Read selectively**: start from Library `START_HERE`, relevant handoff, latest current spec, decisions, code, tests and knowledge entry. Do NOT load the entire Library in every agent; the map is not the entire manual.
3. **Work in bounded unit**: investigate + implement + verify + handoff one cohesive change. Avoid aimless self-generation of 'three new tasks'; coordinator prioritizes from shared backlog.
4. **Checkpoint continuously**: after meaningful milestone, write short task state with current SHA, changed paths, hypothesis, what failed, commands, exact next action, risk and decision source.
5. **Refresh**: at task boundary by default, earlier when context quality declines or multiple compactions occur. No magic 60% 'hard limit'. Save checkpoint before retirement; the next session verifies it.
6. **Retire**: close a worker only when outputs are saved and verified; coordinator updates task board and releases ownership. Do not depend on a Cowork API to rotate sessions automatically unless tested.
7. **Coordinator longevity**: update a compact `COORDINATOR_STATE.md` often. If Cowork coordinator chat becomes overloaded, create a new chat/project with state and explicit owner transition only through verified, user-accessible workflow. Do not assume existing active child conversations transfer.

If permissions, local files or GitHub are unavailable, mark task BLOCKED and hand off precise steps rather than claiming invisible completion.
