G="nice -n 19 /opt/godot/godot --headless"
L=/tmp/gs2.txt; echo "HEAD=690ee1716e5162f4187a2e4ccaaee68e5a7f83d1 (new .so) vs ref 5b9d9f915c014bb6591b30275da1f86a2b77f873 (old .so)" > $L
cd /work/gs3a; $G --path . --import > /tmp/imp_gs3a.log 2>&1; echo "imported" >> $L
for V in /work/su_base /work/gs3a; do cd $V; rm -f worlds/base_world/water/tile_3_4.water; S=$(date +%s); timeout 3000 $G --path . --script res://src/worldgen/tools/settle_water.gd -- --tile=3,4 --ticks=600 > /tmp/settle_$(basename $V).txt 2>&1; RC=$?; echo "SETTLE $(basename $V) exit $RC seconds $(( $(date +%s) - S )) md5 $(md5sum worlds/base_world/water/tile_3_4.water 2>&1 | cut -d' ' -f1)" >> $L; done
echo GS2DONE >> $L
