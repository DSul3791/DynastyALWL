#!/bin/bash
# Final world pictures on a quiet PC (Oct 31 night): coast, under a beech, campfire placed and lit, felling. Wrap with tools/godot_slot.sh.
cd "$(dirname "$0")/../.."
O="--out art/playthrough/world3"
bash art/playthrough/rig.sh --pieces lean_to,rough_bed,workbench,stone_forge --more-shots "coast:52600,1.7,66592,90,0,12,clear,-1;under_beech:53312.8,1.6,68494.3,0,40,12,clear,-1" --at 53316,68476 --wait 60 --settle 75 $O --name clearing
bash art/playthrough/rig.sh --give campfire_kit:1 --drop --client-arg --shot-place --client-arg --shot-light --wait 60 --settle 60 $O --name campfire_lit
bash art/playthrough/rig.sh --item stone_axe --client-arg --shot-fell=flat --wait 120 --settle 20 --keep $O --name fell
