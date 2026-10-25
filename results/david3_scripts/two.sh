export PATH=/tmp/gbin:$PATH GODOT_EXE=/opt/godot/godot
gate(){ # dir hash label tests flagsmode
  D=$1; H=$2; L=/tmp/g_$3.txt; echo "HEAD=$H" > $L
  cd $D; nice -n 19 /opt/godot/godot --headless --path . --import >/tmp/imp_$3.log 2>&1
  echo "parse_scan: $(nice -n 19 python3 tools/parse_scan.py 2>&1 | tail -1)" >> $L
  nice -n 19 bash tools/local_check.sh 2>&1 | grep -E "^FAIL|LOCAL CHECK|total" -A3 >> $L
  for T in $4; do R=$(nice -n 19 timeout 600 /opt/godot/godot --headless --path . --script res://src/worldgen/tools/$T.gd 2>&1); echo "$T exit $?: $(echo "$R" | grep -E 'per call|FAIL|failures|Test done|passed' | tr '\n' ' ' | cut -c1-240)" >> $L; done
  export REPO=$D; NC=0
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if [ "$5" = flags ]; then FL=("--test-respawn=10" "--test-go-to-spawn=10"); EX="${FL[$((i % 2))]}"; SP="mv$i:53301,1.7,68427,0,0,12,clear,-1"
    else X=$((53601 + (i % 3) * 100)); EX=""; SP="ta$i:53301,1.7,68427,0,0,12,clear,-1;tb$i:$X,1.7,68427,90,0,12,clear,-1;tc$i:53301,1.7,68427,180,0,12,clear,-1"; fi
    taskset -c 0-3 env EXTRA="$EX" SHOTSPEC="$SP" nice -n 19 bash /tmp/shot_land2.sh --out /out/g_$3 --wait 40 --settle 10 > /tmp/g_run.txt 2>&1
    CR=$(grep -cE "handle_crash|FATAL|signal 11" /out/fresh_join_server.log); [ $CR -gt 0 ] && NC=$((NC+1))
    echo "run $i [$EX]: $(grep -c saved /tmp/g_run.txt) pictures, server crash lines $CR, SPAWNTEST: $(grep -E 'SPAWNTEST' /out/fresh_join_client.log | tr '\n' ' ' | cut -c1-260)" >> $L
  done
  echo "runs with crash: $NC of 10" >> $L; echo GDONE >> $L
}
gate /work/ts2 dba07947255c486dedd528bd2225030061a0ffdb ts2 "test_sim_levels_threads test_block_cache_swap" none
gate /work/sc2 bbb4977df2dca19fe55547a4517fa5dd7286ad4e sc2 "test_spawn_column" flags
echo TWODONE > /tmp/two_done.txt
