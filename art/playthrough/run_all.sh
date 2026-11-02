#!/bin/bash
# Playthrough pictures: each line is one rig run (3 at a time). Run from the repo root: bash art/playthrough/run_all.sh
cd "$(dirname "$0")/../.."
mkdir -p art/playthrough/logs
C="--gy 1039.0 --out art/playthrough"
R="--row-dist 5 --row-space 1.0 --agl 2.0 --pitch -25"
cat <<EOF | xargs -P 3 -I{} bash -c 'bash art/playthrough/rig.sh {} > "art/playthrough/logs/$(echo "{}" | sed -E "s/.*--name ([^ ]+).*/\1/").log" 2>&1'
--row stone,stick,plant_fibre,twine,thatch,leaves,bark,kindling,firewood $R $C --name 03_raw_materials
--row birch_bark,tinder,tinder_fungus,amadou,bedding,straw,flint,wooden_block,hide,feather $R $C --name 04_tinder_and_missing
--row stone_axe,stone_knife,stone_hammer,wooden_hammer,wooden_spade,stone_spade,wooden_hoe,stone_hoe,stone_pickaxe,torch $R $C --name 05_tools
--row wooden_spear,spear,wooden_club,stone_mace,wooden_bow,wooden_arrow,stone_arrow,javelin,wicker_shield,snare,fishing_rod $R $C --name 06_weapons
--row campfire_kit,lean_to_kit,rough_bed_kit,chest_kit,workbench_kit,chopping_block,thatch_roof_kit,thatch_wall_kit,thatch_floor_kit,thatch_doorway_kit $R $C --name 07_kits
--flora nettle,tall_grass,flax,reeds,thatch_grass,heather,riverbraid,tanglewort $C --name 02_fibre_plants
--flora raspberry,bramble,blueberry,hazel,plantain,comfrey,tinder_fungus,staunchmoss $C --name 02b_berries_herbs
--pieces lean_to,rough_bed,chopping_block,workbench,thatch_roof,thatch_wall,thatch_floor,thatch_doorway $C --name 09_placed_shelter
--item stone_axe --cam right --dist 1.6 $C --name 08_hold_stone_axe
--item spear --cam right --dist 1.6 $C --name 08_hold_spear
--item wooden_bow --cam right --dist 1.6 $C --name 08_hold_bow
--give campfire_kit:1 --drop --client-arg --shot-place $C --name 10_campfire_placed
EOF
