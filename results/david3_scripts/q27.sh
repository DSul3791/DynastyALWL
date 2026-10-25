export PATH=/tmp/gbin:$PATH GODOT_EXE=/opt/godot/godot
G="nice -n 19 /opt/godot/godot --headless"
wait_quiet(){ while [ "$(cut -d. -f1 /proc/loadavg)" -ge 6 ]; do sleep 20; done; }
prep(){ H=$1; D=/work/q_${H:0:8}; mkdir -p $D; (cd /work/repo && git fetch -q origin 2>/dev/null; git archive $H | tar -x -C $D); (cd $D && $G --path . --import > /tmp/imp_q_${H:0:8}.log 2>&1); }
fullgate(){ # hash name [extra tests]
  H=$1; N=$2; shift 2; L=/tmp/q_${H:0:8}.txt; echo "HEAD=$H ($N)" > $L; wait_quiet; prep $H; D=/work/q_${H:0:8}; cd $D
  echo "parse_scan: $(nice -n 19 python3 tools/parse_scan.py 2>&1 | tail -1)" >> $L
  echo "conflict markers (all tracked-type files, incl .uid): $(grep -rlE "^(<<<<<<<|=======$|>>>>>>>)" --include=*.gd --include=*.uid --include=*.json --include=*.tscn --include=*.tres --include=*.py --include=*.sh . 2>/dev/null | tr "\n" " ")none-if-empty" >> $L
  nice -n 19 bash tools/local_check.sh 2>&1 | grep -E "^FAIL|LOCAL CHECK|total" -A4 >> $L
  P=0; F=0
  for f in src/worldgen/tools/test_*.gd; do T=$(basename $f .gd)
    R=$(nice -n 19 timeout 900 /opt/godot/godot --headless --path . --script res://$f 2>&1); RC=$?
    if [ $RC -eq 0 ] && ! echo "$R" | grep -qiE "[1-9][0-9]* fail|^FAIL|SCRIPT ERROR|Parse Error"; then P=$((P+1)); else F=$((F+1)); echo "FAIL $T: $(echo "$R" | grep -iE 'fail|error' | head -2 | tr '\n' ' ' | cut -c1-180)" >> $L; fi
  done
  echo "tests: $P pass, $F fail" >> $L
  python3 - >> $L <<'PY'
import json,collections
for f,k in (('items','items'),('recipes','recipes')):
    d=json.load(open(f'data/items/{f}.json')); L=d[k]; nums=[e.get('number') for e in L.values()]
    print(f, len(nums),'dup',[n for n,c in collections.Counter(nums).items() if c>1],'max',max(nums),'next',d['next_number'])
PY
  echo QDONE >> $L
}
itemgate(){ H=$1; L=/tmp/q_${H:0:8}.txt; echo "HEAD=$H (item shots)" > $L; wait_quiet; prep $H; D=/work/q_${H:0:8}; cd $D
  echo "parse_scan: $(nice -n 19 python3 tools/parse_scan.py 2>&1 | tail -1)" >> $L
  echo "conflict markers (all tracked-type files, incl .uid): $(grep -rlE "^(<<<<<<<|=======$|>>>>>>>)" --include=*.gd --include=*.uid --include=*.json --include=*.tscn --include=*.tres --include=*.py --include=*.sh . 2>/dev/null | tr "\n" " ")none-if-empty" >> $L
  nice -n 19 bash tools/local_check.sh 2>&1 | grep -E "^FAIL|LOCAL CHECK|total" -A4 >> $L
  R=$(nice -n 19 timeout 900 /opt/godot/godot --headless --path . --script res://src/worldgen/tools/test_item_cam.gd 2>&1); echo "test_item_cam exit $?: $(echo "$R" | grep -E 'FAIL|Test done' | tr '\n' ' ' | cut -c1-200)" >> $L
  for K in iron_pickaxe iron_spade_large iron_hoe; do
    REPO=$D CLIENT_SECS= SHOTSPEC="it_$K:53301,1.7,68427,0,0,12,clear,-1" EXTRA="--shot-item=$K" nice -n 19 bash /tmp/shot_land2.sh --out /out/q_items --wait 40 --settle 10 > /tmp/q_run.txt 2>&1
    if ! grep -qE "item view .* (ok|FAILED)" /out/fresh_join_client.log; then echo "(no item-view lines, rerun once)" >> $L; REPO=$D SHOTSPEC="it_$K:53301,1.7,68427,0,0,12,clear,-1" EXTRA="--shot-item=$K" nice -n 19 bash /tmp/shot_land2.sh --out /out/q_items --wait 40 --settle 10 > /tmp/q_run.txt 2>&1; fi
    echo "--- $K" >> $L; grep -E "item view .* (ok|FAILED)" /out/fresh_join_client.log | cut -c1-200 >> $L
  done
  echo QDONE >> $L
}
fullgate 0f190ff29ddd2264c1437875f9448c4e3b2185b5 sal-hearth-oven-build-v2
fullgate 422beb3bb8250a351c3a962735e050a5a79ad6d1 sal-item-master
(cd /work/repo; D=/work/q_tt; mkdir -p $D; git archive ad07a34b53e1f54d3794dc4ca780c22651a40c30 | tar -x -C $D; echo "HEAD=ad07a34b53e1f54d3794dc4ca780c22651a40c30 (sal-tool-tiers) parse_scan: $(cd $D; python3 tools/parse_scan.py 2>&1 | tail -1)" > /tmp/q_ad07a34b.txt; echo QDONE >> /tmp/q_ad07a34b.txt)
echo ALLQ27 > /tmp/q27_all.txt
