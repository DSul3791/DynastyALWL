L=/tmp/mutex.txt; : > $L
export REPO=/work/hyb
cd /work/hyb
run(){ # label flagsets
  K=$1; F=$2
  cd /work/hyb
  TS=$(date +%s) 
  taskset -c 0-3 env EXTRA="$F" SHOTSPEC="m$K:53301,1.7,68427,0,0,12,clear,-1" nice -n 19 bash /tmp/shot_land2.sh --out /out/mutex --wait 40 --settle 15 > /tmp/mut_run.txt 2>&1
  CR=$(grep -cE "handle_crash|FATAL" /out/fresh_join_server.log)
  echo "$K [$F] shot_exit_text: $(grep -E '^shot:|saved' /tmp/mut_run.txt | tr '\n' ' ' | cut -c1-120) | server_crash_lines=$CR | $(grep -E 'SPAWNTEST' /out/fresh_join_client.log | head -3 | tr '\n' ' ' | cut -c1-200)" >> $L
  return $CR
}
echo "== UNFIXED generator-v2 flora_placer.gd on spawn-column client/server, 4 cores" >> $L
cp /tmp/fp_unfixed.gd /work/hyb/src/worldgen/runtime/flora_placer.gd
FLAGS=("--test-respawn=10" "--test-go-to-spawn=10")
for i in 1 2 3 4 5; do run u$i "${FLAGS[$((i % 2))]}"; [ $? -gt 0 ] && { echo "unfixed crashed on run $i" >> $L; break; }; done
echo "== FIXED 8394ee6f flora_placer.gd" >> $L
cp /tmp/fp_fixed.gd /work/hyb/src/worldgen/runtime/flora_placer.gd
NC=0
for i in 1 2 3 4 5 6 7 8 9 10; do run f$i "${FLAGS[$((i % 2))]}"; [ $? -gt 0 ] && NC=$((NC+1)); done
echo "fixed runs with a crash: $NC of 10" >> $L
cd /work/hyb; echo "parse_scan: $(nice -n 19 python3 tools/parse_scan.py 2>&1 | tail -1)" >> $L
PATH=/tmp/gbin:$PATH GODOT_EXE=/opt/godot/godot nice -n 19 bash tools/local_check.sh 2>&1 | grep -E "^FAIL|LOCAL CHECK|total" >> $L
echo MUTDONE >> $L
