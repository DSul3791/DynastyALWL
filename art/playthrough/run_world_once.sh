#!/bin/bash
# ONE rig session, many pictures: the placed pieces in a row at the spawn, then the same forest under a grown beech 19 m away (dry, then in rain)
# and open ground in rain at the spawn. The beech position comes from spawn_survey.json (probe_spawn.gd). Run from the repo root.
cd "$(dirname "$0")/../.."
read BX BZ < <(python -c "import json;t=json.load(open('art/playthrough/spawn_survey.json'))['grown_trees_near'][0];print(t[1],t[3])")
MORE="under_beech_dry:$BX,1.6,$BZ,0,45,12,clear,-1;under_beech_rain:$BX,1.6,$BZ,0,45,12,rain,-1;open_ground_rain:53316,1.7,68476,0,5,12,rain,-1"
bash art/playthrough/rig.sh --pieces lean_to,rough_bed,chopping_block,workbench,tool_rack,thatch_roof,thatch_wall,thatch_floor,stone_forge,clay_hearth,oven --more-shots "$MORE" --at 53316,68476 --wait 90 --settle 25 --out art/playthrough/world --name once
