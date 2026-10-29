# Technical direction: handoff (written 2026-10-21 13:20 by the outgoing thread)

You are the "Technical direction" Thread Claude for Dave's project "Dynasty a life well lived" (game DynastyALWL, medieval fantasy MMO, Godot 4.7.2 with Voxel Tools, repo DSul3791/DynastyALWL, branch `claude/generator-v2` ONLY, never main). Read project memory first (MEMORY.md), then this file, then tech/PROCESS.md.

## Who you are talking to
- Dave uses voice: keep everything short. You reach Dave ONLY through the coordinator (`send_message` to the coordinator session; currently session_01Q56PMTBrWt1QNcAeKECxYY, check it). Threads you answer DIRECTLY with `send_message` (not SendMessage). Text output is not delivered; end every turn with a hearthbot tool (`no_reply_needed` mostly).
- Session ids (check they are current, threads are being restarted; ask the coordinator for new ids): Items and crafting session_01V6Btc8oMTBkLDXxtZpyY7v; Art direction session_01Lp4BdAEwUFHKjaufRuJ5M3; Ground loading session_0176JkvTJrKJQ7GEdQ44pAsw; Basic world sounds session_01JKLSH2YXm4vAnVXHGBd2fh (ON HOLD); Waterfall research session_01LfSUeb5nufvBEw694MPZEv; River start / water work: id unknown to me, reach via the coordinator. Water and terrain "fresh start" thread is on hold.
- Commit trailers: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` and `Claude-Session: <your session url>`. No model names in anything pushed.

## What you own
Build numbers (tech/BUILD_LOG.md, "Next number" on line 8); architecture review and approvals: server/client/admin split, protocol (PROTOCOL.md must stay complete), save formats and versions, shared files, new dependencies, engine settings, per-frame cost outside the quality setting. Keep tech/JOBS.md (queues per thread) full so no thread idles; log decisions in tech/DECISIONS.md; render and cost tables in tech/RENDER_AUDIT.md; CONTROLS.md is the single list of inputs (tools/check_controls.py).
Dave's rules: minimum machine GTX/RTX 1050 class, 8 GB RAM, 30 fps; every feature states its cost at Low. Dave bakes tiles himself (Esc > Advanced > Admin: Bake starter tiles, ~30 min); no cloud baking. Dave's PC is an RTX 2060 SUPER. Thinly discussed DESIGN questions go to Dave as one card (via coordinator, with a recommended option); technical details you decide yourself. Nobody should wait for another agent (Dave, 2026-10-21 04:36): answer requests within two minutes.

## Standing approvals (tech/DECISIONS.md, 2026-10-21 "STANDING APPROVALS")
1. Protocol bumps and save-format changes for a feature Dave has already chosen are pre-approved if PROTOCOL.md is updated in the same push, saves are versioned with a neutral default for old saves, and cost at Low is stated. Push first, tell you after. NEW design not chosen by Dave still asks first.
2. Every thread holds at least two spare build numbers; if none, take the next free above head BUILD and tell you the commit id.
3. HUD BUILD constant = max(upstream, own number); the log keeps the number by commit id. Label clashes have been common and are cosmetic: log by commit id.
Other recorded decisions to know: luck trait (all rolls through src/shared/luck.gd, tools/check_luck.py flags raw random); Fitness (protocol 26); boulders (protocol 27); ice design (stateless Ice.cover, pond ice always holds, ocean floes); saved ground edits (one log: digs.dat, DIGS1 by Ground, River extends to DIGS2, limits radius 3 m, 5 ops/s, replay cap 200); tile-border water stage A (memory cap 1.2 GB, max 3 tiles, water thread at most half a core, a third in storms); waterfall sim-driven water sheet (water_grid.gd/water_material.gd); River 10x/20x spring flow approved with duty cap; ground edits must call GrassView.ground_changed; other players' character bodies budget 1 ms at Low for 20 visible; protocol 24 thirst, 25 luck to client, 26 Fitness, 27 boulders, 28 ACT_DIG, 29 sleep, 30 ACT_FILL, 31 water containers, 32 oxygen. PROTOCOL_VERSION is 32 at head 67f5e30.
Open item: admin dig RPC is ungated (no admin concept on the server) before any public server.

## Build number state (head 67f5e30, HUD 396; NEXT FREE 399)
Holdings at hand-off (reconcile with `git log` and BUILD_LOG.md; threads are being restarted and lose their notes, so re-send each its numbers):
- Ground: 348, 369, 370, 389, 390 (347 used by grass merge c6ab4d6).
- Art: 397, 398 (387 flora merge, 388 buildings look, 396 wind cue used).
- Items: 374, 391, 392 (382, 383, 384 used; older leftovers 329, 330, 337 to 339, 343, 344, 351, 352 may still be unused: they are below head, so any use is fine and the HUD takes max).
- River start: 385 used (oxygen), 393 used (border water), 394 used (cold generation); it needs fresh numbers: give it two from 399.
- Waterfall research: 340 (+395 held); builds 325, 334, 335 and 380 pushed.
- Sounds: none, on hold.
Recent pushes you may not have seen are in BUILD_LOG.md tail ("13:15 catch-up").

## Bake point
Dave bakes from head 1be1f5f or later (contains River generator set baec958 and Waterfall bare rock 380). 394 (cold generation speed) is byte identical, so no new bake needed for it. Rule: any tile-changing push is announced to you first and Dave is told. Water thread rebuild_starter_cache.sh exists for after his bake. When nothing pending changes tiles, say (via coordinator) "!!! All threads are done - ready for a rebuild!" and name the commit.

## Queues per thread (tech/JOBS.md has the text)
- Ground (client/performance): idle audit done (nothing in scripts); job 7 collision cost done (no change); now: the 24 small static-body meshes, client memory audit at Low (8 GB), then Dave's table with engine rows (probe table Ctrl+Shift+G). Grass merge 347 and engine rows 379 done. Possible next: 1050-class draw-call work (334 visible nodes at Low now), loading stalls.
- Art: wind cue done (396); next jobs 12 stills, 13 (covered), first-person arms with Items' held tool attach node, then the CPU/33 ms script hunt when Dave's per-piece table arrives. Flora merge at Low/Medium done (387); High/Ultra keep variants.
- Items and crafting: refill 8 in JOBS.md: jobs 90 (done as 382), 91 food spoilage design note + card for Dave, 92 clothing and warmth design note + card, 93 persistence drills (done as 383), 94 inventory/Tab audit. Items also owns skills (job 87 skills and attributes list: note + card for Dave), luck, Fitness, containers, sleep, dig under trees, boulders. Prior notes in items/*.md; Dave answered thirst (yes), luck (all rolls), fitness training slow.
- River start (water): drowning/oxygen done (385, protocol 32), border water stage A done (393), cold generation done (394); remaining: tile-border stage B only if a lake straddles a border (check script), saved edits steps 2 and 3 (DIGS2, water replay of digs, fill op; ACT_FILL exists from Items 378), bays/digs check, water cost report with ice/digs (WATER_COST_REPORT.md), ocean floes follow-ups.
- Waterfall research: sim-driven water sheet shipped (325, 334, 335); watching Dave's real cliff; 380 bare-rock lips needs the bake.
- Sounds: ON HOLD by Dave (sound ahead of development) except bugs Dave reports. All jobs 90, 91, 74, 85 and later held. Known bug: sound_check scenario "floor" fails even before Ground's change.
- Water and terrain "fresh start": on hold (notes tech/RIVER_START_NOTES.md).

## Waiting on Dave (via coordinator)
- His retake of the probe table on the newest head: Ultra meadow/under-crown, with the new engine rows and "idle step = timed pieces + untimed" (his last Ultra tables were script bound: 33 ms idle step while headless shows 1.7 ms; the missing time is engine, probably voxel main thread or viewport).
- A 1050-class PC run of Esc > Advanced > "Measure this machine" and the table.
- Watch for grass popping at group edges (347) and flora hitch (387), dusk hitch from the sky update (386), ocean floes and ice look, waterfall look.
- Cards: spoilage, warmth, skills/attributes (Items will send via coordinator).
- The bake (see above).

## Gotchas
- Threads hit message quotas and inboxes lag: resend numbers directly, and relay for them through the coordinator. Several threads took upstream+1 over each other's spares; always check the branch (`git fetch` in /tmp/claude-0/gv2, a worktree of origin/claude/generator-v2) before issuing.
- The repo worktree for reading code is /tmp/claude-0/gv2 (may be gone in a fresh session: clone DSul3791/DynastyALWL branch claude/generator-v2). I have no Grep tool problems: use Bash git grep.
- Dave often screenshots an older build: check his HUD build number before treating something as a regression. Cloud has no graphics; software-render stills only.
- Typos in session ids cause "message is required" or "could not be verified" errors: retype carefully.
- Never push to main. Dave closes the editor before pulling (locked dll).
- Open reviews: notes 65 (dig under trees) and 68 (sleep) were approved and built (372, 373). No reviews outstanding at hand-off. Items notes still to approve when they arrive: spoilage, warmth, skills list.
