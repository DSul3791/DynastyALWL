# Plan: use Dave's 24-hour game server for tests (instead of the laptop). PLANNING ONLY, nothing installed. Tyler, 24 Oct 2026

## What Mike's jobs need
1. Godot 4.7.2 custom build (Voxel Tools 1.7, C++ water core). The water core DLL in git is WINDOWS only. On Linux the water tests fail until the core is built for Linux (a separate job, not planned here).
2. A clone of the repo (second clone, own folder), Python 3, Git. The oggs imported once in the editor (import step needs the editor binary; headless import works with `--headless --import`).
3. Disk: about 6 GB for the clone plus import cache; 20 GB free to be safe. RAM: 8 GB free for local_check/test_worldgen; more for bakes.
4. GPU: Forward Plus needs Vulkan. Pictures, look_rig and frame-time runs NEED a real GPU. Headless tests (parse_scan, validate_items, test_worldgen, test_slot_sounds, local_check where it does not render) do not.

## What goes where
- On the server (if Windows, or Linux once the DLL exists): parse_scan, local_check, validate_items, island_checks, test_worldgen, test_slot_sounds, item_master, check_controls. Cloud already does the Python ones.
- STAYS on Mike's PC: bakes, river settles, island table, backups, pictures and frame time (GPU), anything near Dave's play session.

## Keeping Dave's two games safe (rules)
1. Separate folder and a separate Windows/Linux user, never inside a game's folder.
2. Run tests at low priority with caps: Windows `start /low` + job limit; Linux `nice -n 19` + `systemd-run --scope -p CPUQuota=50% -p MemoryMax=4G`. Never more than 2 threads.
3. Only when Dave allows: a visible on/off flag file (tests_allowed.txt, Dave sets it) that the runner checks before each run; stop at once if a player count above 3 or CPU above 70 percent is seen.
4. No bakes there, no long jobs (cap each run at 20 min), logs kept in the test folder.
5. No new open ports. Mike's Claude Code connects OUT (remote-control session), the same way as on his PC.

## How Mike reaches it
`claude remote-control` run inside the clone on the server (steps in LAPTOP_SETUP.md E apply unchanged: copy settings_mike_all.json, change paths). Dave logs in once to start it; no port forwarding.

## Install steps (when Dave says go; Dave or Mike does them, not me)
1. Free-disk and RAM check. 2. Git, Python 3, Claude Code. 3. Copy the Godot installer folder (do NOT download Godot). 4. Clone to its own folder on branch claude/generator-v2. 5. Import once, run check_addons (ADDON_OK), parse_scan, local_check. 6. Start remote-control, test one tiny run with the caps on, watch both games.

## Ask Dave (one card)
1. Windows or Linux? 2. CPU model and cores, RAM total/free, free disk. 3. GPU: any, and which? 4. How busy is it in the evening (peak players)? 5. Which user/folder may Mike use, and OK to leave Claude Code running there? 6. Which hours are off limits?
