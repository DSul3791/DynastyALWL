#!/bin/bash
# World pictures on the fixed world, one rig run after another (quiet machine, long waits). Run from the repo root.
cd "$(dirname "$0")/../.."
W="--wait 240 --settle 45 --out art/playthrough/world"
bash art/playthrough/rig.sh --name spawn_view $W
bash art/playthrough/rig.sh --item stone_axe --client-arg --shot-fell=flat --name fell $W
bash art/playthrough/rig.sh --pieces lean_to,rough_bed,chopping_block,workbench,tool_rack,thatch_roof --name shelter $W
bash art/playthrough/rig.sh --give campfire_kit:1 --drop --client-arg --shot-place --name campfire $W
