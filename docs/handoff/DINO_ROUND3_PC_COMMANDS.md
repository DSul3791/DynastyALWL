# Dino round 3 (2 Nov 2026, paper review on main b7af691, no Godot run)

## A. Guides re-checked against merged changes
- **Fire light 3.5 / 7 / 14 m (Steve, 1352ae2):** `cooking.json` fire_tiers now has light_m 3.5 / 7 / 14 and light_energy 1 / 2 / 4. This clears the drift I reported in round 1. Checklist, CONTROLS.md and PLAYTHROUGH_GUIDE.md already say 3.5 / 7 / 14: correct, no change.
- **Stack caps (corrected after Steve's check, commit 15168f1d, in main):** my first read was wrong. `stack_of()` in src/shared/item_table.gd returns 65535 for normal items and 1 only for items marked `unstackable`; the old `stack` numbers in items.json are ignored. PLAYTHROUGH_GUIDE.md line 31 said "stack 20" for stone: fixed to say there is no cap. No other guide mentions stack sizes. Note for the 61-stick count: sticks no longer take several slots, only weight (0.2 kg each, about 12 kg).
- **Carry weights (Sal #18):** `tools/carry_audit.py` runs. One recipe is SLOWING: recipe 151 rock_pile, 45 stone = 45 kg. Not in the first hour. The checklist weights (stick 0.2 etc.) are unchanged.
- **Text vs recipe:** `python3 tools/text_vs_recipe.py` reports 0 mismatches for hints and goals. It does not cover the clay hearth blueprint cost (10 bricks + 6 clay + 4 stones), which is the hint drift already sent to Sal.
- **Creator preview (Kathreen 52a8034):** the tool now starts facing the front. The checklist still lists "Creator preview opens on the back" as known broken. It needs a picture to confirm (section B, command 3), then the line can go.

## B. Exact commands for the PC thread (Windows, Git bash, repo root; Godot at C:/GodotInstaller/godot.windows.editor.x86_64.exe or set GODOT_EXE). Run each in the background, one at a time.
1. Placement refusals live (proves item 1 of round 1): `tools/godot_slot.sh timeout 300 $GODOT_EXE --headless --path . --script res://art/playthrough/probe_place.gd > out/probe_place.txt` then read the "(silent: ...)" lines; expect none.
2. First-hour status table (about 6 min): `tools/godot_slot.sh bash art/playthrough/run_status.sh`.
3. Creator front view: `tools/godot_slot.sh $GODOT_EXE --path . --resolution 1920x1080 --script res://tools/proto_creator_view.gd -- --out=res://art/playthrough/smoke/creator_2nov` (look at the first picture: front, not back).
4. Lit fire with flames, grass off: `art/playthrough/rig.sh --give campfire_kit:1 --drop --client-arg --shot-place --client-arg --shot-light --nograss --hour 21 --out <dir>` (flames and glow visible = QA card pic-fh-campfire-lit can go to Dave as Yes).
5. Felled trunk bark: `art/playthrough/rig.sh --item stone_axe --client-arg --shot-fell=flat --out <dir>` (the old picture had the camera over water; use `--at X,Z` of a dry flat spot if it repeats).
6. Lean-to with bed inside and lying: `art/playthrough/rig.sh --pieces lean_to,rough_bed --views "wide:6:-20:2" --out <dir>`; lying view still needs a rig change (Kathleen).
7. Sleep self-test at low energy and bench/drink/pot checks: need Tyler's test flags (not available to run).
8. Whole smoke (about 30 min, last): `bash art/playthrough/smoke_test.sh` then `python art/playthrough/smoke_report.py`.
Keep max 3 heavy Godot jobs through `tools/godot_slot.sh`. Pictures for Dave go on QA cards, one per card.
