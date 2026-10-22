# Big picture (read this first, every thread; about 2 KB; kept current by the Technical Director)

**The game.** DynastyALWL, "Dynasty, a life well lived": a persistent, rough-medieval, multiplayer online world with a "Sims vibe". Survival, exploration, town building, family, heirs and a dynasty that outlives one character. Near-photoreal look (Dave's brook photo wins); sound counts as much as content and visuals. Runs on weak hardware (1050-class, 8 GB, 30 fps minimum).

**Principles (DESIGN_PRINCIPLES.md).** Safe, then kind, then generous. Do it yourself or hire it out (no job only by hand, none only by NPC). Nobody is forced to build a town. Content, visuals and audio count equally. Server, client and admin tool stay separable.

**Where we are.** One starter town (tile 3,4) plus 8 neighbours, for a friend session. Present focus: movement, physics, water flow, tunnels, getting ready to play. Parked: scale beyond a friend session, QoS, flood damage, armour, voice, banking. World data is frozen until Dave's next bake. Development is paused until Dave says "go".

**What is built (see HANDOFF.md).** Generated terrain and water simulation, flora, walking/swimming/sleeping, items and crafting, campfire, foundations and walls, test NPCs (Hob, Edda), tunnel watch (off).

**Who does what.** Coordinator (routes, reports to Dave); Technical Director + Guru (docs, approvals, best practices); Sonny (ground and water); Radar (items, crafting, NPCs, buildings); Steve_ProblemSolver (server, network, UI, performance, saves); Kathleen_ArtisticDirector (art and sound); MikeW_LocalAgent (runs on Dave's PC).

**How we work.** Read tech/BEST_PRACTICES.md daily and before anything new. Dave wants SHORT reports. Questions for Dave go on the question page; blurts go to tech/IDEAS.md; priorities are P0 to P3. Details: HANDOFF.md, tech/PROCESS.md.
