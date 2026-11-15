# Session and task lifecycle
**Status: IN FORCE (activated by Dave, 12 Nov 2026; `INSTALL_RECORD.md`). Drafted as PROPOSED.**

1. **Create task**: brief must include job ID, context docs, exact expected behavior, files/interfaces allowed, prohibited side effects, priority, tests, owner, reviewer, destination branch and authorized runtime.
2. **Read selectively**: start from current `origin/dev`, `CLAUDE.md`, `docs/START_HERE.md`, the topic map, current mission state/decisions, relevant code/tests and knowledge entry; use private handoffs when accessible and relevant. Do NOT load the entire Library in every agent; the map is not the entire manual.
3. **Work in bounded unit**: investigate + implement + verify + handoff one cohesive change. Workers do not create unrelated work: the coordinator prioritizes and assigns; workers finish, document results and request their next assignment (Dave, 12 Nov 2026).
4. **Checkpoint continuously**: after a meaningful milestone or before context handoff, write short task state with current SHA, changed paths, hypothesis, what failed, commands, exact next action, risk and decision source.
5. **Refresh**: at task boundary by default, earlier when context quality declines or multiple compactions occur. No magic 60% 'hard limit'. Save checkpoint before retirement; the next session verifies it.
6. **Retire**: close a worker only when outputs are saved and verified; coordinator updates task board and releases ownership. Do not depend on a Cowork API to rotate sessions automatically unless tested.
7. **Coordinator longevity**: update a compact `COORDINATOR_STATE.md` often. If Cowork coordinator chat becomes overloaded, create a new chat/project with state and explicit owner transition only through verified, user-accessible workflow. Do not assume existing active child conversations transfer.

If permissions, local files or GitHub are unavailable, mark task BLOCKED and hand off precise steps rather than claiming invisible completion.
