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

