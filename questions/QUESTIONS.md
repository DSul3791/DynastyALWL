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

## terrain-opt | How should we fix the ground so water works like real nature? (Sonny's review, tech/TERRAIN_REVIEW.md)
Your requirements: deep lakes in natural basins, streams that gather rain and snowmelt, rivers that carry water away to farmland and sea, flood-prone fertile land, streams good for waterwheels and fishing, and natural channel shape (deeper on outer bends, shallow inside, pools and riffles, never a uniform ditch). Today only 32% of river cells sit where the ground really drains, and a 2 m rise floods 6 times the wet area. The first bake waits for this choice. Nothing is built until you pick.
- B: Find rivers and lakes from the terrain itself. Meets all requirements, including natural channel shape. 1 to 2 weeks. Threaded bake about 8 to 10 minutes for 9 tiles. Makes the held spill-chute patch unnecessary (recommended)
- A: Quick fix, snap the drawn rivers onto the land's channels. About 3 days. Fails 4 of 9 and only adds the bend depth: no snowmelt, no natural basins or outlets, no flood plains, no data for waterwheels or fishing
- C: Rebuild the whole foundation. Meets all 9 but 4+ weeks and everything redone
- Not yet, I want to talk it through first
