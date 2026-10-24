# Laptop as second test machine (Tyler, 24 Oct 10:50 UTC). Dave: old laptop for testing; Mike's PC keeps the bakes.
Point form, numbered. Anything marked [Dave] is done by hand on the laptop.

## A. Is the laptop good enough? (5 minutes; do this FIRST)
1. [Dave] Press Win+R, type dxdiag, Enter. Note: Processor, Memory, Graphics card name and its dedicated memory. The Display tab must list Direct3D feature levels 12_0 or higher, or Vulkan 1.2 must be supported (look the card up on the maker's page if unsure). The game uses the Forward Plus renderer (project.godot), which needs a Vulkan-capable GPU.
2. Minimum to be useful: 8 GB RAM (16 GB better; the water test holds up to 1.2 GB, Godot and the editor take more), a GPU from about 2016 or newer (GTX 960 / RX 470 / Intel Iris Xe or better), 20 GB free disk (the repo is 1.5 GB, the world files 90 MB, plus Godot's import cache and the engine), a wired or good wifi link for git.
3. Below that (4 GB RAM, no Vulkan): it can still run only the cloud-style checks (python tools: parse_scan, merge_check, check_controls, item_master) and nothing that needs Godot. Tell me the dxdiag lines and I decide.

## B. Install on the laptop
4. [Dave] Git for Windows (includes Git Bash, which the .sh tools need) and GitHub Desktop (same as the main PC), and Python 3 (tick "Add to PATH").
5. [Dave] Godot: DO NOT download Godot from the website. The project needs OUR custom editor build, Godot 4.7.2 with Voxel Tools 1.7 compiled in. Copy the folder C:\GodotInstaller from the main PC (it holds godot.windows.editor.x86_64.exe) to the same place on the laptop (USB stick or network share), so the path is identical: C:\GodotInstaller\godot.windows.editor.x86_64.exe. If the folder has other files next to the exe, copy them all. The water core (addons/water_core, a native DLL) comes with the repo through git.
6. [Dave] Claude Code on the laptop, so Mike-style work can run there: install it from https://code.claude.com/docs/en/quickstart (use the current install steps on that page) and sign in with the same Claude account.

## C. Clone and branch (a SEPARATE clone, never the play folder)
7. [Dave] GitHub Desktop > File > Clone repository > DSul3791/DynastyALWL > local path C:\GodotProjects\DynastyALWL_laptop (not the main PC's play folder name, so nobody mixes them).
8. [Dave] In GitHub Desktop, Current branch: claude/generator-v2. Click Fetch origin, then Pull, before every test session. The 9 baked tiles and the water files come with that pull (they are tracked in git).
9. Never play the game from this clone and never commit from it. Tests only; any file a test writes stays local.

## D. First run (once)
10. [Dave] Open Git Bash in C:\GodotProjects\DynastyALWL_laptop and run: GODOT_EXE="C:/GodotInstaller/godot.windows.editor.x86_64.exe" tools/godot --headless --path . --script res://tools/check_addons.gd . It must print ADDON_OK. If not, send the last 10 lines.
11. [Dave] Import the sound files ONCE (a fresh clone has not imported the oggs, which made test_slot_sounds fail earlier): open the project in the editor (godot.windows.editor exe, Project Manager > Import > pick project.godot), wait until the import bar at the bottom ends (a few minutes), then close the editor. Do this again only after a big pull that adds audio.
12. [Dave] Run: python tools/parse_scan.py (must say 0 problems), then bash tools/local_check.sh (it closes with the pass/fail list; write down how long it took).

## E. Connect it as a remote agent (so Claude can work on it)
13. [Dave] Open a terminal (Git Bash) IN the laptop clone folder, run: claude remote-control (Claude Code's Remote Control; the same thing Mike's PC uses). Or use the Claude Desktop app settings > Remote Control > connect this computer. Name the session LaptopW_LocalAgent if it asks.
14. [Dave] In the Claude app on the main side, the laptop shows as a connected device; the coordinator then starts the laptop session in the clone folder. Permissions: copy the project permission file from /mnt/project-files/settings_mike_all.json into the laptop clone's .claude/settings.json, but change every C:/GodotProjects/DynastyALWL to C:/GodotProjects/DynastyALWL_laptop. A project settings file only loads when the session starts IN that folder, so start it in the clone.
15. Rule on the laptop session: tests only, no rm -rf, no force pushes, no bake pushes. Results go to the thread as text plus the table file.

## F. Job split
16. MAIN PC (Mike, stays): all bakes and settles (9 tiles, seam stitch), claude/mike-bake-* commits, island_checks table on a bake, the nightly backup (needs Godot closed), Dave's play folder pulls.
17. LAPTOP (moves off Mike's PC if it can run Godot at F2 Low): test_worldgen (884 tests), test_slot_sounds, local_check (warning count vs baseline), validate_items, test_server_items, look_rig pictures and --frametime (frame time numbers are only comparable on the SAME machine: always report the laptop figure labelled "laptop" and never compare it with Mike's PC figure), the Batch 2 sound listen if it has speakers.
18. Cloud (already): parse_scan, merge_check, check_controls, check_look_names, sound_check, item_master. Owners run those before Mike's or the laptop's gate.
19. Queue rule: Mike's queue lists each item as MAIN or LAPTOP; the two run at the same time. A branch's gate result needs the id tested and which machine ran it.
20. Pick-up test after setup: the laptop runs gate list 6 (island-checks c88cc1a8, sound-batch2 018f30ed, item-master aa7023df) test_slot_sounds and local_check as its first job; if its numbers match Mike's PC (same pass/fail and same warning count), it is trusted for the rest.
