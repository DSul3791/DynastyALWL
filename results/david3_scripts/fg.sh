export PATH=/tmp/gbin:$PATH GODOT_EXE=/opt/godot/godot
G="nice -n 19 /opt/godot/godot --headless"
L=/tmp/fg.txt; cd /work/bake
git fetch -q origin claude/lake-size claude/mike-bake-793 claude/generator-v2
git checkout -q -f --detach c30d6d5ffb9b71a16064abac732392aba858bda6 && git checkout -q ee50b0e2b700e97725bcfa081ae94b53ee3c02fd -- worlds/base_world/tiles worlds/base_world/water
echo "HEAD=$(git rev-parse HEAD) (lake-size) + tiles/water from ee50b0e2b700e97725bcfa081ae94b53ee3c02fd (mike-bake-793)" > $L
$G --path . --import > /tmp/imp_fg.log 2>&1
echo "parse_scan: $(nice -n 19 python3 tools/parse_scan.py 2>&1 | tail -1)" >> $L
echo "conflict markers: $(grep -rlE "^(<<<<<<<|=======$|>>>>>>>)" --include=*.gd --include=*.uid --include=*.json --include=*.tscn --include=*.tres --include=*.py --include=*.sh . 2>/dev/null | tr "\n" " ")(none if empty)" >> $L
CHANGE_LABEL=BAKE nice -n 19 bash tools/local_check.sh 2>&1 | grep -E "^FAIL|LOCAL CHECK|total|labelled" -A4 >> $L
echo "tile md5 (Mike: 3_4 31586ef6, 4_4 16581815, 4_3 8141b451): $(for t in 3_4 4_4 4_3; do printf "%s=%s " $t $(md5sum worlds/base_world/tiles/tile_$t.tile | cut -c1-8); done)" >> $L
echo "erosion_delta_v2.bin sha256: $(sha256sum worlds/base_world/erosion_delta_v2.bin | cut -d' ' -f1) (expect ac0df3cc0fc4cc54feb0cb3365d2022960c45690e8e84fa31b2963e8ee9e55c4); v1 present: $(ls worlds/base_world/erosion_delta_v1.bin 2>&1 | grep -c 'No such' | sed 's/1/no (removed)/;s/0/YES/')" >> $L
echo "TERRAIN_VERSION in code: $(grep -rhoE 'TERRAIN_VERSION[^=]*= *[0-9]+' src | head -2 | tr '\n' ' ')" >> $L
R=$(nice -n 19 timeout 900 /opt/godot/godot --headless --path . --script res://src/worldgen/tools/test_tile_lakes.gd 2>&1); echo "test_tile_lakes (on the baked tiles) exit $?: $(echo "$R" | grep -cE '^ok')  ok lines, FAIL lines: $(echo "$R" | grep -E 'FAIL|failures' | tr '\n' ' ' | cut -c1-200)" >> $L
echo "merge_check.py: $(MERGE_CHECK_BASE=origin/claude/generator-v2 python3 tools/merge_check.py 2>&1 | tail -6 | tr '\n' ' ' | cut -c1-500)" >> $L
python3 - >> $L <<'PY'
import json,collections
for f,k in (('items','items'),('recipes','recipes')):
    d=json.load(open(f'data/items/{f}.json')); X=d[k]; nums=[e.get('number') for e in X.values()]
    print(f, len(nums),'dup',[n for n,c in collections.Counter(nums).items() if c>1],'max',max(nums),'next',d['next_number'])
PY
# spawn walk on the baked tiles: a join at spawn with a picture, and a short move (two shots)
export REPO=/work/bake
SHOTSPEC="fg1:53301,1.7,68427,0,0,12,clear,-1;fg2:53301,1.7,68427,90,0,12,clear,-1" EXTRA="" nice -n 19 bash /tmp/shot_land2.sh --out /out/fg --wait 40 --settle 10 > /tmp/fg_run.txt 2>&1
echo "spawn walk: $(grep -E 'landed|FAILED|saved|cache' /out/fresh_join_client.log | cut -c1-160 | tr '\n' '|' | cut -c1-700) crash lines $(grep -cE 'handle_crash|FATAL|signal 11' /out/fresh_join_server.log)" >> $L
P=0; F=0
for f in src/worldgen/tools/test_*.gd; do T=$(basename $f .gd)
  R=$(nice -n 19 timeout 900 /opt/godot/godot --headless --path . --script res://$f 2>&1); RC=$?
  if [ $RC -eq 0 ] && ! echo "$R" | grep -qiE "[1-9][0-9]* fail|^FAIL|SCRIPT ERROR|Parse Error"; then P=$((P+1)); else F=$((F+1)); echo "FAIL $T: $(echo "$R" | grep -iE 'fail|error' | head -2 | tr '\n' ' ' | cut -c1-180)" >> $L; fi
done
echo "tests: $P pass, $F fail" >> $L
echo FGDONE >> $L
