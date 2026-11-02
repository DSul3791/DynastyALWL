#!/bin/bash
cd "$(dirname "$0")/../../.."
G=C:/GodotInstaller/godot.windows.editor.x86_64.exe; O=art/playthrough/phase2; R="bash art/playthrough/rig.sh"
tools/godot_slot.sh $G --path . --resolution 1920x1080 --script res://tools/proto_creator_view.gd -- --out=res://art/playthrough/phase2 > $O/creator.log 2>&1
tools/godot_slot.sh $R --pieces lean_to,rough_bed --views "wide:7:-15:2.5;close:4:-25:2.0" --at 53316,68476 --wait 60 --settle 60 --out $O --name leanto_bed > $O/rig_leanto.log 2>&1
tools/godot_slot.sh $R --pieces lean_to,rough_bed --client-arg --shot-stance=lie --cam left --walk 0 --at 53316,68476 --wait 60 --settle 60 --out $O --name lying > $O/rig_lying.log 2>&1
tools/godot_slot.sh $R --give campfire_kit:1 --drop --client-arg --shot-place --client-arg --shot-light --nograss --wait 60 --settle 60 --out $O --name campfire_lit_nograss > $O/rig_fire.log 2>&1
tools/godot_slot.sh $R --item stone_axe --client-arg --shot-fell=flat --wait 120 --settle 20 --out $O --name fell > $O/rig_fell.log 2>&1
tools/godot_slot.sh $R --cam first --admin --wait 60 --settle 30 --out $O --name spawn_tab > $O/rig_spawn.log 2>&1
tools/godot_slot.sh timeout 300 $G --headless --path . --script res://art/playthrough/probe_shelter.gd > art/playthrough/probe_shelter_output.txt 2>&1
tools/godot_slot.sh timeout 300 $G --headless --path . --script res://art/playthrough/probe_place.gd > art/playthrough/probe_place_output.txt 2>&1
tools/godot_slot.sh python art/playthrough/smoke_clients.py sleep > $O/sleep.out 2>&1; cp art/playthrough/smoke/logs/client_sleep.log $O/client_sleep_clean.log
tools/godot_slot.sh python art/playthrough/smoke_clients.py arrival,gather,plantpick,chop,fire,cook,leanto,spear,placed,walk > $O/selftests.out 2>&1
echo CHAIN DONE > $O/done.txt
