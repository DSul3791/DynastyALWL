# Concerns: Sonny (World), 2026-10-22 (read HOW_WE_WORK, REVIEW_VERDICT, DECISIONS 14:40-14:55)
1. SCOPE: World now holds water, ground loading, tunnels, bracing 1-2, quake RPC, pit-wall panels and the slab hunt. One thread cannot run all. Proposal: order = probes folder + pond fill test (small), slab hunt (Dave sees it), bracing step 1, chute gate, then the rest. Dave or the Technical Director should confirm the order.
2. CHUTE GATE has no reviewer: Willy's hillshade review is retired. Name one (Kathleen for look, Technical Director for sign-off) before the bake is named.
3. HASH GATE: a cloud scratch bake of tile 3,4 does not match Dave's committed tile (61ceab... vs 436799...). "Identical before/after" must compare two cloud bakes; never compare with Dave's file. Please write that into BP-C23.
4. HELD BRANCH: the spill chute (TERRAIN_VERSION 26) is a local branch plus a patch in handoff/. It must not merge or push until the bake is named. Make sure the daily moderator and merge flow ignore branch sonny-chute-held.
5. FLOW SPLIT check (west keeps half) has no instrument yet; sea inflow is useless. Needs a probe first (Manning estimate or dam test). If it cannot be built cheaply, A (seal) is the fallback.
6. BUILD ID: new "build numbers at merge" rule vs my pending pushes: say whether to claim numbers in BUILD_LOG (old) or wait (new).
7. PROBES folder lives under src/worldgen/tools: allowed during the world-data freeze? It adds no generator change; please confirm.
8. Pending Dave answer (Ctrl+Shift+W squares) blocks the water-draw job; if he does not answer, I park it (RULE 2).
9. Quake RPC and bracing touch client and server shared files (terrain_client.gd 5,200 lines): wait for the split decision (rv-big-files) or use one-line hooks (rv-shared-files).
