# Action plan: look_rig item lookup, ground close-ups, showroom camera

Branch: claude/steve-rig-item, code commit bec78512 (base generator-v2 785). CHANGE_LABEL: RUNTIME (rig tooling only; no game behaviour, no bake, no protocol).

One class of small rig fixes, asked for by Kathleen and Mike:
1. tools/look_rig.sh and tools/look_rig_seed.py: item lookup also reads data/items/gathered.json (flowers, kindling, petals were "no such item").
2. New `--ground-close ID[:N]`: the pile seen side-on, camera 0.35 m up, 0.9 m away, 45 degrees down. `--gy` default 31.0 (spawn ground now; was 28.0, which buried the pile).
3. `--showroom-cam-height M`, `--showroom-look-down DEG`, `--showroom-spread` (src/debug/shot_runner.gd): camera height and pitch for the showroom rows, name tags staggered in three heights.

Mike's check: `tools/look_rig.sh --ground-close rose_petals:3 --name petals_ground` and `tools/look_rig.sh --showroom K1,K2 --showroom-cam-height 3 --showroom-look-down -35 --showroom-spread`. Parse scan and local_check as usual (expect 233, no new).
Not run in Godot in the cloud.

Tyler GO (24 Oct, BP-T55), done in the follow-up commit:
- tools/item_numbers.py: ONE function (load_numbers) merges items.json and gathered.json; a duplicate name or number stops the rig with an error. look_rig.sh and look_rig_seed.py both use it.
- Old behaviour reachable and changed defaults printed: every run prints "rig defaults: --gy 31.0 (was 28.0 ...)"; `--gy 28` repeats an old picture.
- Camera numbers are flags and logged: --close-height / --close-dist / --close-pitch (printed at start), showroom --showroom-cam-height / --showroom-look-down (logged per picture in the "shot runner: view" line).
- Showroom tag-overlap check: "shot runner: tag overlap view <row> ok|OVERLAP (n tags, m overlapping pairs)" per picture (estimate from letter count and font size; fixed-size tags).
- tools/check_rig_syntax.sh: bash -n, syntax parse of the python tools, merged item tables; prints "rig syntax: N pass, N fail". Run before handing to Mike (BP-T55). Evidence pictures stay out of generator-v2.

Follow-up from Mike's run of a15eeecc (same branch): --gy default 31.25 (the visible spawn ground is 31.17, flat items were buried); --showroom words match a whole label, else one word of it (K1 no longer picks K10-K12), else part of a label; new `--showroom-per N` frames one picture per N items of a row (close enough for small items, tags checked per picture); tag overlap counts only tags on screen.
