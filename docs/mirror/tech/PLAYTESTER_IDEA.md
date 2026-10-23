# Play-tester thread (Dave 15:51, 23 Oct): "a thread that tries to play the game with basic instructions, keeps trying and testing and gives feedback"
Status: idea, high interest (BP-T24). Owner: Guru (plan), Steve (bot hooks), MikeW (runs on Dave's PC).

## What we already have
- Look rig (tools/look_rig.sh, shot_runner.gd): windowed stills with flags (--flora, --give, --drop, --dist, --ground). It can place the camera and take pictures but not play.
- Protocol bots (tools/bots.sh, scenes/bot/bot_main.tscn): headless players that walk, ask for ground and dig. They see numbers, not pictures.
- BP-T49: ground tests look down at the spot.

## Staged plan
1. **Scripted goal runs (small, days):** extend the rig with a text script of steps, e.g. `walk_to x z`, `look_down 15`, `equip shovel`, `dig`, `chop`, `craft wooden_block`, `drop`, `snap name`. Each step writes a screenshot and a one-line state dump (position, inventory, hp). A thread or MikeW reads the pictures and answers "did it work?". Builds on look_rig.sh; Steve adds the step commands, MikeW runs it.
2. **Bot client with a goal list (medium, 1-2 weeks):** a windowed (or headless with a render target) client that reads a goal file ("get 10 firewood", "build a basic wall", "survive a cave-in") and uses fixed helper behaviours (pathing, aim at target, use item). It writes a report of pass/fail per goal with screenshots. Steve builds the hooks (input injection, targeting by item id, event log); MikeW runs nightly after the backup or when Dave is away.
3. **LLM-driven loop (larger, only if tools allow):** a Claude session on Dave's PC reads screenshots and presses keys with computer-use tools, given plain instructions ("make a fire and cook a fish"). It keeps trying, notes what is confusing or broken, and posts the report. Needs computer-use access on Dave's PC (MikeW is checking which tools his session has). Slower and costlier per step, but finds "feel" problems the scripts can't.
4. **Feedback loop:** each run ends with a report (goals passed, stuck points, screenshots) into tech/PLAYTEST_REPORTS/ and a short QA card only if it needs Dave's judgment. Stuck points become jobs for the owning thread.

## Core rule, all stages: EXPECT AND STOP (Dave 15:54)
- Guru and Tyler write the exact steps (keys, menus, targets), so a menu change means updating the script, not guessing.
- Every step states what it expects to see or measure afterwards (an item in the hotbar, a hole of N blocks, text on screen, a coordinate range).
- If the expectation is not met, or something expected is missing, the run STOPS at once. It does not skip ahead and does not improvise.
- The stop report gives: step number and text, expected, seen, a screenshot, the one-line state dump and the build number. It goes to Guru (coordinator relay), who sends it to the owner thread to fix.
- After the fix, the same script reruns from the start. A script that passes end to end is the test; the report log lives in tech/PLAYTEST_REPORTS/.
- Stage 3 (LLM loop) follows the same rule: it must stop and report rather than try to work around a missing thing.

## Cost and risk
- Stage 1: low cost, low risk (client-only test code, no protocol change). Value now: it replaces many "please test" cards.
- Stage 2: medium; the risk is a fragile bot after UI changes. Keep helpers few and data-driven. Use the second clone and a separate test server and store, never Dave's saved world.
- Stage 3: highest token and time cost and the least repeatable; runs take minutes per goal. Use it for a weekly "new player" pass, not every build. Also it needs Dave's PC for the screen, so it can run only while the PC is on and unused.
- All stages: run on the test clone with an isolated store; never commit screenshots or logs (only reports); no effect on the game's code paths other than test hooks behind a flag.

## Recommendation
Yes: do stage 1 now (Steve + MikeW), then stage 2, and decide on stage 3 once we know which tools MikeW has. First goals to script: the dig test (BP-T49), pick up a pile, chop a log to blocks to firewood, a cave-in death.
