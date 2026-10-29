# Willy_002 notes: non-ground work handed to Tyler_002 (2026-10-22)

Dave: Willy owns ONLY the ground and how it is shaped. Everything else goes to Tyler. Read Willy_001_HANDOFF.md for the full background (crash hunt, telemetry files, gotchas); this file is what changed after it.

## Pushed by Willy_002 (branch claude/generator-v2)
- 597 server: water packed for clients on worker threads (`_water_queue`, `_queue_water`, `server_flora.water_ready`), `flora_removed.json` saved at most once a second and at exit (`save_removed`).
- 598 server: per-peer block-key budget on the block line (`KEY_BURST` 8000, `KEY_REFILL_PER_S` 4000 in terrain_server.gd). Steve's (b), welcome per reconnect: checked, cheap (small revisions dict), unchanged.
- 600 client: 5-bar server link indicator `src/client/link_bars.gd` (rtt, loss, silence; server heartbeat `pulse` RPC 4/s, PROTOCOL 67); lost-connection notice never quits by itself (`_show_lost_notice`, mutes sound, Retry/Quit); test flags `--lost-notice` (headless keeps running), `--lose-after=N`.
- 601 client: connection window `src/client/connect_window.gd` + `_update_connect_window` in terrain_client.gd. Not seen on screen (cloud engine is headless only): check its look.
- `.claude/settings.json` allows `git push origin claude/generator-v2` and the `HEAD:` form (Dave asked).

## Findings
- A hard-killed or old server is only noticed after the 60-120 s ENet timeouts (data/network.json); bars show it in about 1 s.
- Dave's "won't start, flat gray, last line 'connecting to 127.0.0.1:24600'" is reproduced headless: an OLD server (protocol 66) still on the port plus a new client (67) hangs silently. Adding an RPC shifts RPC ids, so the old welcome never arrives, so the protocol check never runs. Fix: 601 window says so after 8 s. Not done: the launcher (`Play: started the terrain server`) should refuse or kill a stale server on the port; find the launcher script.
- Cold store join: items step 1.4 s and 4.8 s on the first join (Radar's 599 may cover it).
- Server restart is needed after 597-601.

## Open for Tyler (non-ground)
1. Crash hunt from Dave's next telemetry (crash_reports/*.txt, telemetry_*.log).
2. Server stalls: `server_items.tick`, `_bury_plants`, welcome building, SCALE_PLAN items.
3. Load test and per-peer action rate limits (Willy_001 handoff queue item 0), block_link_server flood (Steve's (a): only the budget is done).
4. Connection window and bars polish, launcher stale-server check, step-over feel, pickup feed.
## Stays with Willy (ground)
Ground loading/streaming, settle time, bad ground blocks, terrain generator, tiers' ground distances.

## Digging rules found in the design docs (DESIGN_IDEAS.md)
- Depth (Section 11.3): no hard floor; depth measured from SEA LEVEL; about 3 km below sea level too hot to survive, stamina drains, digging deeper stops; skills, ventilation and magic push it deeper. Trench floor about -2800 m.
- Collapse (Section 11.2): natural caves stand while openings are small; larger man-made openings need supports (timber, pillars; torch-like reach 10 m, strengths add); abandoned or unpaid mines fail at the weak middle spots; a cave-in refills with rubble, the land above does not sink; collapsed mines revert through erosion and water. Open: opening sizes needing supports, support kinds, whether collapse injures miners, whether natural caves collapse after widening.
- Rock needs a pick (Dave answered dig-rock: spade soil/gravel/sand only).

## Dave 2026-10-22: no limit on excavating, brace or it shakes and collapses
Design proposal: tech/EXCAVATION_BRACING_GROUND_DESIGN.md (source of every point marked at the top). Needs to be added to DESIGN_IDEAS 11.2 as [Decided] by the doc owner. Depends on Tyler_002's compaction. Questions bracing-grace and collapse-lethal are on the page.

## State at 2026-10-22 night stop (Willy_002, ground only)
Pushed: 625 rock rescue (player inside rock always lifted; RESCUE lines in crash_reports), 635 protocol 68 quake RPC wired to sound.placed.quake, 642 small shadow biases in pits/tunnels (pit wall panels, test-queue line), 646 tunnel watch.
Tunnel watch (src/stream/tunnel_stability.gd, tunnel_watch.gd, data/tunnels.json): OFF by default ("enabled": false). "collapse": false even when enabled, so turning "enabled" on gives only timers + quake shaking messages (per Steve's step 1 and 2); collapse and deaths are step 3 and need Steve's second approval + Dave test card. Not done: admin overlay of working cells, saved wall clock for timers (opened times are in-memory msec, lost at restart), 90 s minimum warning "at their own spot" per player (grace min 225 s gives a 90 s shaking window but is not per-player), max 4 fill spheres per frame, logged-out players (question collapse-offline), support strength callable (Radar's items: set tunnels.support_strength and call tunnels.support_changed).
Open ground items: slab/lake squares are visual (Sonny's water sort suspected); pit panels need the F2 Low check; settle-time warm/cold numbers: cold east fly 46 s, warm run unfinished. Warning cleanup of frozen files: Dave said NO until next bake.
Test queue lines written for pit panels and rock rescue.
