# Answers

## coffer-raid | Banking: if raiders break a family coffer, how much coin do they get?
Answer: None, a coffer cannot be raided
Answered: 2026-10-21 23:15 UTC

## coffer-place | Banking: where can a family coffer be placed?
Answer: Only inside owned land
Answered: 2026-10-21 23:15 UTC

## coffer-access | Banking: who can open a family coffer?
Answer: Only the owner
Answered: 2026-10-21 23:16 UTC

## coffer-atm | Banking: is there a fee to use coin from a faraway coffer for a big deal?
Answer: Free
Answered: 2026-10-21 23:16 UTC

## coffer-heir | Banking: when a character dies, what happens to their coffers?
Answer: They pass to the heir
Answered: 2026-10-21 23:17 UTC

## deal-offline | Banking: can a big deal be sealed while the payer is offline?
Answer: Yes, the agreement waits and seals when the coin is there
Answered: 2026-10-21 23:17 UTC

## fishing-bait | Fishing: should bait still make dawn fishing a sure bite (a fish every 19 s)?
Answer: Cap the bonus so dawn is a bit under sure (about 0.93 a cast)
Answered: 2026-10-22 00:06 UTC

## fishing-hint | Fishing: show a hint when a spot is nearly fished out?
Answer: Yes, "the water is still" when under 3 fish are left
Answered: 2026-10-22 00:06 UTC

## cast-roles | Starter town people: who lives here besides Hob (shopkeeper) and Edda (guard)?
Answer: Keep just Hob and Edda for now
Answered: 2026-10-22 00:06 UTC

## cast-names | Starter town people: what are the new people called?
Answer: I will name them myself later
Answered: 2026-10-22 00:07 UTC

## cast-trade | Starter town people: what do they trade?
Answer: Only Hob trades; the others only talk and give quests
Answered: 2026-10-22 00:07 UTC

## cast-child | Starter town people: should there be a child?
Answer: Yes: Pip chats, plays, and runs small errands, never trades or fights [recommended]
Answered: 2026-10-22 00:07 UTC

## fall-channel | The 300 m waterfall near x 53640 z 69150 is thin water running down bare mountain slope, not a carved river. Do you want a carved river channel (about 10 to 14 m wide, one clean chute, bed continuing from the pond) down it in the next bake?
Answer: Yes, carve the river channel down the fall in the next bake
Answered: 2026-10-22 01:04 UTC

## scale-target | What does "1000 players online" mean for the server plan?
Answer: 1000 spread across the whole world (normal MMO target)
Answered: 2026-10-22 01:24 UTC

## sound-music | Should the game have background music?
Answer: No music, only world sounds (recommended: keeps the world feeling real)
Answered: 2026-10-22 03:05 UTC

## sound-wolf-howl | When should wolves howl?
Answer: Only at night, far away, more in winter (recommended)
Answered: 2026-10-22 03:05 UTC

## sound-footstep-others | How far away should you hear other players' footsteps?
Answer: 15 m, same as NPC voices (recommended)
Answered: 2026-10-22 03:06 UTC

## sound-npc-voice-ambient | Should NPCs mutter or hum when you are nearby and they are idle?
Answer: Yes, rarely, short lines (recommended)
Answered: 2026-10-22 03:06 UTC

## river-flood | Should heavy rain make rivers swell and flood low ground?
Answer: Yes, real floods in storms and spring melt (can wash out low buildings and crops)
Answered: 2026-10-22 03:06 UTC

## dig-rock | Can a spade dig through solid rock? (my pick: soil only, rock needs a pick)
Answer: Spade digs soil, gravel and sand only; rock needs a pick and is slower
Answered: 2026-10-22 03:07 UTC

## hole-refill | Do small surface holes and pits (spade digs in open ground, not mines) fill back in by themselves? (the docs only say mines revert through erosion and water; my pick: yes, slowly)
Answer: No, a hole stays until someone fills it
Answered: 2026-10-22 03:08 UTC

## drop-cap-full | When the ground around you already holds 64 dropped items (a 256 m square), what should happen when you drop one more?
Answer: Refuse the drop and say why (current behaviour)
Answered: 2026-10-22 03:12 UTC

## build-first-set | Which player-built structures should come first after the campfire kit, lean-to and chest?
Answer: A full wall, floor and roof kit so players design their own houses
Answered: 2026-10-22 03:13 UTC

## hole-refill | Do dug holes slowly fill back in by themselves? (my pick: no, they stay until filled)
Answer: No, a hole stays until someone fills it
Answered: 2026-10-22 03:16 UTC


## dig-depth | How deep may players dig below the surface?
Answer: Already decided in DESIGN_IDEAS.md (Sections 4.5, 11): depth is measured from sea level; deep mines are limited by heat (lethal about -3,000 m), the world bottom is -4,000 m; deep mines need ventilation. No separate dig limit. (Removed from the page by Steve_002, answered in the docs)
Answered: 2026-10-22 03:20 UTC

## tunnel-collapse | Do unsupported tunnels and caves ever collapse?
Answer: Already decided in DESIGN_IDEAS.md (mines section): mines and caves can become unstable; bigger man-made openings need timber supports (reach about 10 m); unmaintained supports fail and the mine can cave in. (Removed from the page by Steve_002, answered in the docs)
Answered: 2026-10-22 03:20 UTC

## host-max-players | Friend-hosted game player cap
Answer: Already decided in DECISIONS.md 2026-10-22 01:40 (condition 2): baseline a friend session of 10 to 20 on an 8 GB machine; max_clients becomes a config value. Technical, not Dave's call. (Withdrawn by Steve_002)
Answered: 2026-10-22 03:20 UTC
## bracing-grace | How long is the grace window after digging a soil tunnel before the earth starts to shake? (my pick: 30 real minutes, shorter for wider spans)
Answer: About 30 real minutes (shorter for wider spans, longer for rock)
Answered: 2026-10-22 03:56 UTC

## collapse-lethal | Can a collapse kill a player who ignores the warnings? (my pick: heavy damage, buried, can be dug out)
Answer: Always lethal inside the collapse
Answered: 2026-10-22 03:57 UTC

## load-exertion-own-link | When the server is overloaded players tire faster. Should a player whose OWN connection is weak (but the server is fine) also tire faster? (my pick: no, only server load counts)
Answer: No, only server overload makes actions harder (a player on bad wifi is not punished)
Answered: 2026-10-22 03:58 UTC

## warning-cleanup-frozen | May Willy add warning-silencing annotations to the frozen terrain-generator files (no change to the baked result, checked by identical test-bake hashes)? (my pick: yes, gated)
Answer: No, leave the frozen files alone until the next real bake
Answered: 2026-10-22 03:59 UTC


## collapse-offline | A tunnel's collapse time runs out while the player is logged out inside it. What happens to them?
Answer (Dave, in chat): the game must tell a deliberate logout from a disconnect. A disconnect: the player respawns at the nearest place they rested or built a shelter. A deliberate logout inside a tunnel that then collapses: they die.
Answered: 2026-10-22 05:38 UTC
## rv-build-numbers | Build numbers keep colliding (5 re-pushes in one evening). Fix it? Research: short-lived branches merged fast by one owner work best. Best practices BP-C101, BP-C107.
Answer: Yes, all three (recommended)
Answered: 2026-10-22 15:01 UTC

## rv-big-files | Three code files are huge (server_items 5,000 lines, inventory_view 3,800, terrain_client 5,200), so every edit costs a lot of reading. Split them? Research: the context window is the scarce resource. BP-C03.
Answer: Yes, one at a time, after restart (recommended)
Answered: 2026-10-22 15:02 UTC

## rv-local-first | Run every build, test and warning check on your PC by default through one command (tools/local_check.sh), cloud threads only edit and review? Research: a check the agent can run is the best quality lever. BP-C83, BP-C80.
Answer: Yes (recommended)
Answered: 2026-10-22 15:02 UTC

## rv-warning-baseline | Commit the current warning list (233) as a baseline file so reports show only NEW warnings? BP-C01.
Answer: Yes (recommended)
Answered: 2026-10-22 15:03 UTC

## rv-bp-digest | Everyone reads the 80-entry best practices every day (costly; research says long instruction files get ignored). Replace with a 15-line digest per role plus the changelog lines? BP-T25.
Answer: Yes, role digests (recommended)
Answered: 2026-10-22 15:03 UTC

## rv-shared-files | Threads need one-line changes in other threads' files (piece looks, sounds, client wiring). Allow one-line data hooks in another thread's file if announced in BUILD_LOG? BP-C10, BP-T22.
Answer: Yes (recommended)
Answered: 2026-10-22 15:04 UTC

## rv-waiting-line | Your rule: every post ends "Still waiting on:". Threads often have nothing to wait for. Keep it always (writing "nothing") or only when something is pending? BP-T10.
Answer: Only when something is pending (recommended)
Answered: 2026-10-22 15:04 UTC

## rv-lfs | Tile files in git (BP-C108): all server runs, flight checks and edge-matching run on your PC (your rule), so cloud threads never need tiles. Tiles stay in git as backup and history. Is any extra step needed?
Answer: Keep tiles in git as backup, cloud threads simply never use them (recommended)
Answered: 2026-10-22 15:09 UTC

## cc-first-job | When the team restarts, what should they do first? (Triple-check item; every thread agreed the process is ready.)
Answer: Crashes, saves and version check first, then water, then items, then art (recommended)
Answered: 2026-10-22 15:14 UTC

## cc-radar-name | One thread is called Radar in the docs and Sal_Crafts in one review. Which name do we use?
Answer: Sal_Crafts
Answered: 2026-10-22 15:15 UTC

## cc-long-runs | Long test runs and bakes on your PC use the same computer and graphics card as your game. When may MikeW run them?
Answer: Any time except while the game is running; MikeW checks first (recommended)
Answered: 2026-10-22 15:15 UTC

## cc-keep-awake | Local-first only works if your PC is awake with Claude Desktop open while the team works. Can we ask Windows to stay awake then?
Answer: Yes, keep awake while the team is working (recommended)
Answered: 2026-10-22 15:15 UTC

## cc-branches | Per-thread branches (you approved): when do they start?
Answer: From the first job after restart (recommended)
Answered: 2026-10-22 15:16 UTC

## bk-plan | Nightly backup plan (your top priority). Approve it so MikeW can write the script? Plan and every failure case it handles: tech/BACKUP_PLAN.md (copy in docs/mirror/tech/). Restore steps: tech/RESTORE_PROCEDURE.md.
Answer: Approve as written (recommended)
Answered: 2026-10-22 15:35 UTC

## bk-weekly | Backups older than 30 days are thinned to one per week. Which one do we keep forever from each week?
Answer: The LAST backup of the week, normally Sunday night: it holds the whole week's work (recommended)
Answered: 2026-10-22 15:44 UTC

## bk-trigger | How should the nightly backup start?
Answer: When you say "goodnight", and MikeW checks that Godot is closed first (recommended: it only runs when you are done)
Answered: 2026-10-22 15:44 UTC

## bake-plan | Approve the bake plan (BP-T31)? Every change is labelled RUNTIME (just play), RESTART (close game fully) or BAKE (waits for a bake window). Bakes are batched, at most once a week, 1-tile test first, then one full 9-tile bake.
Answer: Approve as written (recommended)
Answered: 2026-10-22 16:52 UTC

## cl-tests | The 11 old "have you answered this" checks (builds 623 to 645) are parked. Many builds have changed since. What now?
Answer: Regroup them into one test card after the restart work, dropping any that no longer apply (recommended)
Answered: 2026-10-22 17:17 UTC

## cmd-ok | Approve the completeness phrases (status, audit, goodnight, idea), the decision trace and the moderator's 30-minute checklist? (BP-T29)
Answer: Approved (Dave in chat: the commands are already done)
Answered: 2026-10-22 17:18 UTC

## nf-ok | Approve the "never forget" rules for every thread (BP-T30)? Each thread keeps one open-items list, writes down promises at once, checks a six-box "definition of done" before saying done, lists unfinished things in its handoff, and may drop an item only with a one-line reason.
Answer: Approve as proposed (recommended)
Answered: 2026-10-22 17:19 UTC

## repo-vis | Important: the main DynastyALWL repo is PUBLIC on GitHub today. Anyone with the address can read the code, design docs, questions and answers. Do you want that?
Answer: Make it private (recommended: it is an unreleased game)
Answered: 2026-10-22 17:20 UTC

## review-rules | Approve the rules for the terrain review (BP-T32)? Sonny writes a docs-only review first: what is wrong today, 2 or 3 options with sources, tests a bake must pass (rivers flow downhill, lakes have outlets, 2 m of water does not flood everything, 9-tile bake 30 minutes or less). Nothing is built or baked until you pick an option.
Answer: Approve as written (recommended)
Answered: 2026-10-22 17:21 UTC

## terrain-opt | How should we fix the ground so water works like real nature? (Sonny's review, tech/TERRAIN_REVIEW.md)
Answer: B: Find rivers and lakes from the terrain itself. Meets all requirements, including natural channel shape. 1 to 2 weeks. Threaded bake about 8 to 10 minutes for 9 tiles. Makes the held spill-chute patch unnecessary (recommended)
Answered: 2026-10-22 17:22 UTC

## model-plan | Approve Kathleen's two-stage plan? Stage one: a simple first model AND a placeholder sound for every item, creature and plant. Stage two: upgrades. (art/MODEL_PLAN.md)
Answer: Approve, two stages: basic models and placeholder sounds first, upgrades later (recommended)
Answered: 2026-10-22 18:32 UTC

## model-look | Basic models and placeholder sounds may differ in colour, size and sound from the final art (stage one). Is that fine for now?
Answer: Yes, fine for now (recommended)
Answered: 2026-10-22 18:32 UTC

## model-creatures | Do animals count as "basic done" when they read as the right animal from 20 m (shape and colour)?
Answer: Yes (recommended)
Answered: 2026-10-22 18:33 UTC

