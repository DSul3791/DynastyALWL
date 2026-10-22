# EXCAVATION_BRACING_GROUND_DESIGN: dig anything, brace it, or it shakes and collapses (ground side, proposal, no code)
Author: Willy_002, 2026-10-22. Dave's rule: NO limit on excavating. After an excavation there is a grace window when it is fine; as it runs out the earth shakes, stronger and stronger, until the player braces it properly or it collapses. Fits DESIGN_IDEAS 11.2 (supports like torches: reach 10 m, strengths add, weak middle spots fail first; a cave-in refills the workings with rubble, the land above does not sink; natural caves stand). Bracing ITEMS are Radar_002's; this note is what the ground does.


## Where each point comes from (read this first)
FROM DESIGN_IDEAS 11.2 (Decided unless marked): supports work like torches, each holds the ground within its reach, strength fades with distance, overlapping supports add up, weakest spot is the middle between two (Decided); starting numbers 10 m reach, linear fade, cap at full strength, need grows with opening size (Proposed); the bigger a man-made opening the more support it needs, natural caves stand while openings are small (Decided); supports wear and need maintenance, follow the 8.13 wear rule (Decided); a cave-in only refills the workings with rubble, the land above does not sink (Decided); rubble can be dug out again, collapse resolved lazily from timestamps like regrowth (Proposed); collapsed mines revert by erosion and water (Decided); abandoned mine rules (Decided). Section 11.3: no hard floor, heat limit about 3 km below sea level (Decided). Mine builder places bracing every so many metres (section on the admin mine builder).
FROM DAVE TODAY (2026-10-22, not yet in the docs): no limit on excavating; a grace window after an excavation; the earth shakes, stronger and stronger, until braced or it collapses. To be added to 11.2 as [Decided] by the doc owner.
STILL OPEN IN THE DOCS (11.2 last [Open] line): how big an opening needs supports, kinds of supports, whether a collapse can trap or injure miners, whether natural caves collapse after widening. My sections 1 and 4 are PROPOSALS for exactly these (span/overburden table, 70 percent rubble fill, damage and burial, natural-cave 1.5x rule).
NEW IN THIS NOTE (mine, Proposed): the enclosed-void definition and 2 m grid, the grace formula, the warning stages, the quake RPC, workings.dat, the server cost design.

## 1. What counts as an excavation needing bracing
Only an ENCLOSED void: air under a solid roof, made or widened by player edits. Open pits, trenches and cuts with sky above never collapse (they may slump later, not in this job). Natural caves never count unless players widen them past the free span.
- Measured on a 2 m grid inside a block (8 x 8 x 8 cells per 16 m block) from the block's SDF with all edits applied (the buffer the server already builds). A void cell is "roofed" if solid is found within 40 m straight up before sky.
- Span of a cell = twice the horizontal distance to the nearest solid wall (so a 3 m wide tunnel has span 3 m).
- Overburden = thickness of solid above the roof (0..40 m, capped).
- Need of a cell (0..1, to match items/BRACING_ITEMS.md where strength x condition is compared with it): span_eff = span x (1 + min(overburden, 20 m) / 20 m); need = clamp((span_eff - free_span) / (2 x free_span), 0, 1). Free span (needs no bracing) by the roof material: loose soil 1.2 m, sand and gravel 1.0 m, clay 2.0 m, soft rock 4 m, hard rock 8 m (the roof material is the rock layer from the tile's geology). A cell with need 0 is stable for ever.
- A cell with need above 0 is "working". It holds while strength x condition >= need, where strength is the sum of the nearby supports' strength faded by distance, capped at 1.0 (support kinds, reaches and strengths are Radar's table in items/BRACING_ITEMS.md; docs 11.2 torch rule).
- Depth has no hard limit (11.3: heat stops digging at about 3 km below sea level; overburden counts up to 20 m for this rule).
- Natural voids: the same measurement on the base ground (no edits) marks cells as natural; they are stable while the span with edits is no more than 1.5x the natural span.

## 2. The grace timer
- Starts when a cell first becomes "working" (the edit that opened it), stored as opened_at on the game clock. Nothing ticks: due time = opened_at + grace, resolved lazily like regrowth, works with nobody nearby.
- grace = 30 real minutes x (free_span / span)^2, clamped to 3 .. 60 minutes. A bigger span gives a shorter window; soil gets the factor of its own free span. Heavy rain in the area halves it (wet soil).
- Bracing (interface agreed with items/BRACING_ITEMS.md): while strength x condition >= need the spot's timer is PAUSED (safe). A support placed before the window ends restarts the FULL grace window for the spots it now covers that are still short. A support removed or worn so a spot falls short again starts a fresh window at half grace for that spot. Shake strength follows the remaining share of the window; the collapse happens when the window reaches zero at a spot still short of its need.
- Digging more into an already working region does not reset the timer; a new working cell gets its own timer; neighbours merge into one "working" cluster that shares the earliest due time.

## 3. Warning stages (fraction f of the grace used)
Minimum warning: the shaking part (f >= 0.6) lasts at least 90 real seconds, so even the shortest window leaves time to run or brace.
- f < 0.6: quiet. Rare pebble tick sound within 8 m.
- 0.6 - 0.8 CREAK: timber-less creaks and soft cracks in the sound mix (15 m), a few dust motes from the roof. Subtle camera sway 0.
- 0.8 - 0.95 SHAKE: dust falls steadily, small pebbles drop (visual only), camera shake grows linearly 0 to 0.5 of full, rumble sound; players in the cluster get a notice line "The earth groans".
- 0.95 - 1.0 THROES: camera shake 0.5 to 1.0, loud cracks, debris drops (visual), screen dust; a 5 s countdown cue.
- 1.0 COLLAPSE.
Server sends one small RPC `quake(stage, strength, point)` twice a second to players within 40 m of a working cluster that is in stage 2 or later (no per-player work otherwise). Shake, dust and sound are client only (Mandy: sound/ and particles; I can drive camera shake).

## 4. The collapse
- Server computes it on a worker thread (never the main thread): for each working cell of the failed cluster, roof rubble falls in. The void volume V of the cluster is filled to 70 percent (rubble bulks up) with RUBBLE material by a small set of fill spheres (at most about 40 per cluster; cells are merged into spheres along the tunnel), biased to the floor in a pile at the angle of repose; the top 30 percent stays open, so a collapsed tunnel can be dug out again.
- The land above does not sink (11.2). A small surface dip is allowed only for roofs under 3 m of overburden (a visible crater, no more than 1 m).
- People inside the footprint (DAVE'S ANSWER 2026-10-22, collapse-lethal: always lethal inside the collapse): anyone whose body is inside the cells that fall is killed (death rules, remains and purse as usual). Because it is lethal the warning must be unmissable: the 90 s minimum shaking window stays, the throes stage carries a loud countdown cue, and nobody is hit outside the failed footprint (a margin of 1 m around the falling cells is the only edge). Items on the floor are buried under the rubble.
- Buried items can be dug out. Bracing items and chests inside are destroyed (broken timber drops, Radar). Water: `water_live.fill` is called per fill sphere (Sonny).
- Aftermath: a spoil/rubble mark on the surface above; a collapsed cluster is stable (no working cells), and later it erodes: soil rubble slowly settles (see question hole-refill).
- Collapse is NOT triggered in a block nobody has loaded; it waits and resolves the moment the block loads (lazy), so no empty-server work.

## 5. Storage
- A collapse is only more edits: the fill spheres are appended to digs.dat (kind fill, DIGS2 supports it). It relies on Tyler_002's compaction (GROUND_COMPACTION_DESIGN.md) and on the MAX_PER_BLOCK cap being removed after it works.
- A small new file `workings.dat` (append-only, derived from the log and items, rebuilt if lost): per working cluster: first cell, opened_at, due time, state (working / braced / collapsed). Rebuilding it from digs.dat after a loss just restarts all grace timers at full grace.
- Bracing lives in Radar's item records; the ground reads supports from the items service (position, type, reach, condition) and recomputes strength for a cluster only when a brace is placed, removed or worn.

## 6. Server cost
- Detection: each dig marks its block dirty; a coalesced (0.5 s) job on a worker classifies the block: 512 cells x one upward scan, about 0.3 ms, plus neighbours. Spam digging stays cheap.
- Timers: one min-heap of due times; the main thread only pops items that are due (O(1) per frame) and starts a worker for the collapse. No per-frame scan.
- Quake RPCs only for players near a cluster in stage 2+.
- Memory: one small record per working cluster.

## 7. Open points for Dave (questions go to questions/QUESTIONS.md)
(Radar's note recommends the same on injury and on natural caves collapsing like man-made ones; I proposed a gentler 1.5x-natural-span rule for natural caves, either works with the code.)
1. DECIDED by Dave: base grace about 30 real minutes (shorter for wider spans, longer for rock); clamp 3 to 60 stays.
2. DECIDED by Dave: a collapse always kills inside the falling footprint.
3. Do open pits and trenches ever slump (my pick: not now).

## 8. Order of work (after the dev stop and compaction)
1. Void classification and a debug overlay (admin): which cells are working, need, due time. 2. Timers and stages with sound and camera shake (no collapse yet). 3. Collapse edits and damage. 4. Hook to Radar's bracing items. 5. Tests: a tunnel dug at three spans, braced and unbraced; collapse equals a replay after restart; a re-bake keeps the rubble (edits replay).
