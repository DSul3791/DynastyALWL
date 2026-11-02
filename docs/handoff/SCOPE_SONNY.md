> **Update 2 Nov 2026 (Dave): there is no daily branch any more.** Where this document says "the daily" or `DailyDev_20261029`, read `origin/main`. Work on your own new branch each day (`claude/<name>-YYYYMMDD`) and open a PR. Bugs in `docs/BUGS_FOUND_IN_PLAY.md` come first. Rules: `docs/START_HERE.md`.

# Scope: Sonny (terrain and Dynasty water), 1 Nov 2026

> **RULE (Dave, 1 Nov 2026): water MECHANICS are yours; water LOOKS go to the art team** (Kathreen first): colour, transparency, shader appearance, foam, flow-texture look, reflections, shore look. You supply depth and flow in a stable form (textures, levels); they own how it looks; review each other's edits.

> **ROLE CHANGE (Dave, 1 Nov 2026): Sonny is the terrain and water agent only** (baked tiles, ground, shore, slopes, water: the foundation everyone plays on). The character work he did earlier is handed over: character LOOK to Kathleen, character SYSTEM (store, records, select code, goals and recipes per character, idle timeout, first-minutes smoke tests) to Steve (Tyler had it for a few hours on 1 Nov). Edited by Jamie with Sonny's OK; character history is in section 2.

Read with `HANDOFF_SONNY.md` (exact next steps, tests) and `docs/DYNASTY_WATER_HISTORY.md` (why and how the water was built).

## 1. The job, where it starts and stops

One lane: terrain and water. **Water:** the new "Dynasty water" simulation under `src/water2/` on branch `dynasty-water` (one thin edit set outside: server hub choice, launcher, Esc menu switch, look rig).
Stops at: the old water (`src/water/`, frozen, kept only behind `--water-old`); baked tile files (nobody commits a baked tile without Dave's go); flora, fruit, animals, art and items (other sessions: flora-density, Kathleen art, Sal, Tyler); main branch and the daily (the moderator merges, never me).

## 2. Done so far (hashes; the character list is from branch history of `sonny-character` and was not re-audited)

Water, all on `dynasty-water`: 8cdfa792 proposal; 9f67e40d stage a (core sim, traits, rules, 21-check test); ec3b1c92 stage b (real tile window); 4c96d626 stage c (visual demo); ed538f1e stages d+e (hub behind `--water2`, rain, springs and sinks); 813cf8e1 rest snap, channel mode, hold_steady, cost 224 to 92 ms; a4d2ec51 demo with the game shader; f009728f `_rest` edge fix and render texture code; a08e8c53 test results; 5853ef75, b50fe380, d7c189ce task list, handoff, late probes; the daily merged in at b802ed25 and 27517559. The default flip, history and this scope are in the commit named in my report.
Character work, now handed over (to Kathleen: look; to Steve: system): db105d36 creator pictures per section and water handover; c41e2d21 creator opens facing front; 588b22a7 phase 5 fall scan and character and loading pictures; 29448b16 learned recipes per character; 8f08947e starter goals per character with rewards and hints; e952d1fc idle timeout setting 5-120 minutes; 1f0e121f, 65a9bdbf, bcf064c0, 5b29b37e smoke tests and reports of select, creator and the first walk.

## 3. Planned, in order

1. Water default flipped and verified (this push), then real-game before/after pictures at a river or lake on the QA page.
2. Protocol flow channel and the `water_material.gd` patch so the game shows the sim's flow, depth and kinds.
3. Windows that follow players with shared seams; digs and fills reaching the field.
4. Swim, drown and sweep wired to the player (`water_rules.gd`), with the existing `swim.gd` as the base.
5. Cost: cell-list stepping or sleeping steady river cells; one-hour soak; tune the rain scale with real storms.
6. Lava and swamp look through the game shader; traits editable in game (colour, clarity, density, viscosity, flow rate as settings).
7. Delete the old water only after Dave sees one release with the new one as default and says so.

## 4. Priorities

1. **The new water must not hurt the play-test** (cost, rivers staying, no flooding): it is now the default, every player meets it.
2. **Real-game pictures of it working**: Dave decides by eye and none of a river or lake exists yet.
3. **Flow and depth reaching the shader**: without it the game does not show what the sim computes.
4. **Windows following players and digs reaching the field**: today only the starter tile's wettest km is live.
5. Terrain: ground, shore and slope problems found by Dino or Tyler, and the lake plan in `PHASE7_PLAN.md` (needs Dave's go for any bake).

## 5. Dependencies

I depend on: the moderator (merges, Dave's go/no-go, QA page flow); `tools/godot_slot.sh` and the machine's three heavy job slots (often full); the tile format and `TileTerrainData` (owned by worldgen); the water shader `src/client/water_material.gd`; Dave for any baked tile or default decision.
Depending on me: the moderator's daily (water is now its default hub and Esc menu switch); whoever touches the server hub (`terrain_server.gd`), the launcher or the Esc menu (merge conflicts); flora and animals if they read `sim_levels` (they still get levels, nothing changed there); anyone wanting swim or drown rules.

## 6. Finished when

Water: new water default and the old one removable with no loss (Dave has seen it on a river and a lake and said yes); the flow channel shows the sim's flow in the game; windows follow players; digs change water; swim and drown rules run on it; all water tests and `test_water_soak`, `test_spawn_dry`, `test_first_hour` green on the voxel build; cost under budget with several windows; the old `src/water/` deleted after one release.
