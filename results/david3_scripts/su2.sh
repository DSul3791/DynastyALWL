# wait for gate A, then stop the gate loop, run the speed-up proof, restart the gate for B and C
while ! grep -q GATEDONE /tmp/gate_e405038b.txt 2>/dev/null; do sleep 20; done
for p in $(pgrep -f "[g]ateN.sh"); do kill $p; done; sleep 3
for p in $(pgrep -f "[o]pt/godot/godot --headless --path \. --script"); do kill $p; done
log=/tmp/su2.log; : > $log
G="nice -n 19 /opt/godot/godot --headless"
(cd /work/su2 && $G --path . --import > /tmp/imp_su2.log 2>&1)
echo "su2 head cbe31f7 imported" >> $log
run(){ # label threads extra
  rm -rf /work/o2_$1; mkdir -p /work/o2_$1
  ( while sleep 5; do cat /sys/fs/cgroup/memory.current; done > /tmp/mem_$1.txt ) & MP=$!
  cd /work/su2; S=$(date +%s)
  $G --path . --script res://src/worldgen/tools/bake_tiles.gd -- "--tiles=3,4;4,4" --threads=$2 --out=/work/o2_$1 $3 > /tmp/bake2_$1.txt 2>&1; RC=$?
  kill $MP 2>/dev/null
  PK=$(sort -n /tmp/mem_$1.txt | tail -1); echo "RUN $1 threads $2 exit $RC seconds $(( $(date +%s) - S )) peak_ram_MB $(( PK / 1048576 ))" >> $log
  return $RC
}
FIT=0
for T in 9 8 7 6; do
  if run nc$T $T "--no-cache"; then FIT=$T; break; fi
done
echo "fit threads $FIT" >> $log
if [ $FIT -gt 0 ]; then
  run cachebuild $FIT ""
  run cachereuse $FIT ""
  run cachereuse6 6 ""
  for v in nc$FIT cachebuild cachereuse cachereuse6; do for t in 3_4 4_4; do
    a=$(md5sum /work/out_base/tile_$t.tile | cut -d' ' -f1); b=$(md5sum /work/o2_$v/tile_$t.tile 2>/dev/null | cut -d' ' -f1)
    [ "$a" = "$b" ] && echo "MD5 same tile_$t $v" >> $log || echo "MD5 DIFF tile_$t $v" >> $log; done; done
fi
echo SU2DONE >> $log
(nohup bash /tmp/gateN2.sh >/dev/null 2>&1 &)
