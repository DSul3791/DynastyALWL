## cl-tests | The 11 old "have you answered this" checks (builds 623 to 645) are parked. Many builds have changed since. What now?
- Regroup them into one test card after the restart work, dropping any that no longer apply (recommended)
- Drop them all, test fresh builds instead
- Keep them parked for now

## cmd-ok | Approve the five completeness phrases (status, audit, what did we forget, goodnight, log it), the decision trace and the moderator's 30-minute checklist? (BP-T29)
- Approve as proposed (recommended)
- Approve, but fewer phrases (tell me which in chat)
- Not yet

## nf-ok | Approve the "never forget" rules for every thread (BP-T30)? Each thread keeps one open-items list, writes down promises at once, checks a six-box "definition of done" before saying done, lists unfinished things in its handoff, and may drop an item only with a one-line reason.
- Approve as proposed (recommended)
- Approve, but a lighter checklist (tell me in chat)
- Not yet

## repo-vis | Important: the main DynastyALWL repo is PUBLIC on GitHub today. Anyone with the address can read the code, design docs, questions and answers. Do you want that?
Making it private does not stop the team or your PC. The cloud threads and GitHub Desktop keep working. GitHub Pages for the repo itself would need a paid plan, which is why the tiny separate page repo is the plan.
- Make it private (recommended: it is an unreleased game)
- Keep it public
- Decide later

## review-rules | Approve the rules for the terrain review (BP-T32)? Sonny writes a docs-only review first: what is wrong today, 2 or 3 options with sources, tests a bake must pass (rivers flow downhill, lakes have outlets, 2 m of water does not flood everything, 9-tile bake 30 minutes or less). Nothing is built or baked until you pick an option.
Climate by coordinates (desert, jungle, tundra, volcano) is part of the review. The first bake waits for it.
- Approve as written (recommended)
- Approve, but I want to see the review before any prototype
- Change it, I will tell you how

## terrain-opt | How should we fix the ground so rivers and lakes come from the land? (Sonny's review, tech/TERRAIN_REVIEW.md)
Today only 32% of river cells sit where the ground really drains, a 2 m rise floods 6 times the wet area, and 1,912 natural basins are ignored because lakes are premade. A 9-tile bake is about 21 minutes in the cloud, not yet timed on your PC. The first bake waits for this choice. Nothing is built until you pick.
- B: Rivers and lakes found from the terrain; every lake gets a natural outlet; rain depends on climate (desert, jungle, volcano). 1 to 2 weeks, bake about the same length, makes the held spill-chute patch unnecessary (recommended)
- A: Quick fix. Snap the drawn rivers onto the land's own channels and deepen them. About 3 days. Lakes stay premade and climate stays cosmetic
- C: Rebuild the whole foundation with uplift and erosion. 4+ weeks, everything redone, best long term
- Not yet, I want to talk it through first
