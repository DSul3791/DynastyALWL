G="nice -n 19 /opt/godot/godot --headless"
cd /work/bake
for H in d79a4a44 15616045 b9c6afb8; do
  while [ "$(cut -d. -f1 /proc/loadavg)" -ge 6 ]; do sleep 15; done
  OUT=/tmp/gate_$H.txt; : > $OUT
  git checkout -q --detach $H 2>>$OUT; FULL=$(git rev-parse $H); [ "$(git rev-parse HEAD)" = "$FULL" ] || { echo "HEAD MISMATCH abort" >> $OUT; echo GATEDONE >> $OUT; continue; }; echo "HEAD=$FULL" >> $OUT
  $G --path . --import > /tmp/imp_$H.log 2>&1
  echo "parse_scan: $(nice -n 19 python3 tools/parse_scan.py 2>&1 | tail -1)" >> $OUT
  P=0; F=0
  for f in src/worldgen/tools/test_*.gd; do N=$(basename $f .gd)
    R=$(nice -n 19 timeout 900 /opt/godot/godot --headless --path . --script res://$f 2>&1); RC=$?
    if [ $RC -eq 0 ] && ! echo "$R" | grep -qiE "[1-9][0-9]* fail|^FAIL|SCRIPT ERROR|Parse Error"; then P=$((P+1)); else F=$((F+1)); echo "FAIL $N: $(echo "$R" | grep -iE 'fail|error' | head -2 | tr '\n' ' ' | cut -c1-200)" >> $OUT; fi
  done
  echo "tests: $P pass, $F fail" >> $OUT
  PATH=/tmp/gbin:$PATH GODOT_EXE=/opt/godot/godot nice -n 19 bash tools/local_check.sh 2>&1 | grep -E "^FAIL|LOCAL CHECK|total" >> $OUT
  echo "tripod mentions in data/items: $(grep -rilE 'tripod' data/items | tr '\n' ' ')" >> $OUT
  python3 - >> $OUT <<'PY'
import json,collections
for f,k in (('items','items'),('recipes','recipes')):
    d=json.load(open(f'data/items/{f}.json')); L=d[k]; nums=[e.get('number') for e in L.values()]
    dn=[n for n,c in collections.Counter(nums).items() if c>1]
    print(f, len(nums),'dup',dn,'max',max(nums),'next',d['next_number'])
PY
  echo GATEDONE >> $OUT
done
echo ALLGATES >> /tmp/gate_all.txt
