# Action plan: look_rig item lookup, ground close-ups, showroom camera

Branch: claude/steve-rig-item, code commit bec78512 (base generator-v2 785). CHANGE_LABEL: RUNTIME (rig tooling only; no game behaviour, no bake, no protocol).

One class of small rig fixes, asked for by Kathleen and Mike:
1. tools/look_rig.sh and tools/look_rig_seed.py: item lookup also reads data/items/gathered.json (flowers, kindling, petals were "no such item").
2. New `--ground-close ID[:N]`: the pile seen side-on, camera 0.35 m up, 0.9 m away, 45 degrees down. `--gy` default 31.0 (spawn ground now; was 28.0, which buried the pile).
3. `--showroom-cam-height M`, `--showroom-look-down DEG`, `--showroom-spread` (src/debug/shot_runner.gd): camera height and pitch for the showroom rows, name tags staggered in three heights.

Mike's check: `tools/look_rig.sh --ground-close rose_petals:3 --name petals_ground` and `tools/look_rig.sh --showroom K1,K2 --showroom-cam-height 3 --showroom-look-down -35 --showroom-spread`. Parse scan and local_check as usual (expect 233, no new).
Not run in Godot in the cloud.
