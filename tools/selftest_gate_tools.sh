#!/bin/bash
# Self-test of tests_for_diff.py and run_tests.sh with a fake Godot (no Godot needed): prints "Test done: N pass, M fail".
cd "$(dirname "$0")/.." || exit 2
PY="${PYTHON:-python3}"; P=0; F=0
ok() { if [ "$1" = "0" ]; then P=$((P + 1)); else F=$((F + 1)); echo "FAIL $2"; fi; }
T=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/gt_$$"); mkdir -p "$T"
sel() { "$PY" tools/tests_for_diff.py --paths "$@"; }
field() { "$PY" -c "import json,sys;d=json.loads(sys.stdin.read());print($1)"; }

[ "$(sel docs/mirror/x.md tech/ACTION_PLANS/y.md | field "d['class']+str(len(d['fast']))")" = "docs0" ]; ok $? "docs only selects no tests"
[ "$(sel src/stream/terrain_net.gd | field "len(d['fast'])")" -gt 60 ]; ok $? "a shared base file selects all fast tests"
[ "$(sel weird/new.gd | field "len(d['fast'])")" -gt 60 ]; ok $? "an unknown path selects all fast tests"
sel data/items/items.json | field "'test_eat_once' in d['fast'] and 'test_inventory' in d['fast']" | grep -q True; ok $? "item data selects the item group and the always set"
sel src/client/piece_look.gd | field "'test_tool_looks' in d['fast'] and 'warnings' in d['checks'] and bool(d['pictures'])" | grep -q True; ok $? "a look file selects the look tests, the warnings check and the picture lane"
sel worlds/base_world/tiles/a.tile | field "d['class']=='bake' and d['pin'] and 'test_worldgen' in d['slow']" | grep -q True; ok $? "baked tiles select the slow lane and the pin check"
sel src/worldgen/tools/test_traps.gd | field "'test_traps' in d['fast']" | grep -q True; ok $? "a changed test selects itself"
"$PY" tools/tests_for_diff.py --check-lanes >/dev/null; ok $? "every name in test_lanes.json is a test"
sel src/worldgen/tools/export_tile_maps.gd | field "len(d['slow'])==0"  | grep -q True; ok $? "an offline worldgen tool script does not start the slow lane"
sel tools/erosion_precarve/rock.py | field "d['class']=='docs' and len(d['fast'])==0" | grep -q True; ok $? "an offline python tool selects no tests"
sel src/worldgen/tile/tile_drainage.gd | field "len(d['slow'])>0" | grep -q True; ok $? "worldgen runtime code selects the slow tests that load it"
sel src/worldgen/tile/tile_drainage.gd | field "len(d['slow'])<9" | grep -q True; ok $? "per commit, worldgen code does not start the whole slow lane"
"$PY" tools/tests_for_diff.py --paths src/worldgen/tile/tile_drainage.gd --full | field "len(d['slow'])==9 and len(d['fast'])>60" | grep -q True; ok $? "--full selects the whole slow lane and every fast test"
sel tools/run_tests.sh | field "d['class']=='tools' and len(d['fast'])==0 and 'selftest' in d['checks']" | grep -q True; ok $? "a gate tool edit selects the lane check and selftest, no game tests"

cat > "$T/fakegodot" <<'F'
#!/bin/bash
for a in "$@"; do case "$a" in res://*) S="$a";; esac; done
N=$(basename "$S" .gd)
case "$N" in
	test_animals) C="${FAKE_COUNT:?}"; n=$(cat "$C" 2>/dev/null || echo 0); echo $((n + 1)) > "$C"; [ "$n" -eq 0 ] && { echo "FAIL first time"; exit 1; };;
	test_broken) echo "FAIL always"; exit 1;;
	test_script_error) echo "SCRIPT ERROR: bad"; exit 0;;
esac
echo "Test done: 1 pass, 0 fail"
F
chmod +x "$T/fakegodot"
export GODOT_EXE="$T/fakegodot" FAKE_COUNT="$T/count"
# retry rules come from test_lanes.json; use real test names for the lanes and the fake for the behaviour
cp tools/test_lanes.json "$T/lanes.bak"
OUTTXT=$(bash tools/run_tests.sh --jobs 2 --out "$T/o1" --fast test_inventory test_traps --timing test_animals 2>&1); echo "$OUTTXT" | grep -q "Test done: 3 pass, 0 fail"; ok $? "a run passes when the one retry of a retry-listed test passes"
echo "$OUTTXT" | grep -q "FLAKE test_animals"; ok $? "a retry that passed is logged as a FLAKE"
echo "$OUTTXT" | grep -q "slowest"; ok $? "the summary names the slowest tests"
bash tools/run_tests.sh --jobs 2 --out "$T/o2" --fast test_script_error >/dev/null 2>&1; [ $? -ne 0 ]; ok $? "error text in the output fails a test"
OUTTXT=$(bash tools/run_tests.sh --jobs 2 --out "$T/o3" --fast test_broken 2>&1); echo "$OUTTXT" | grep -q "Test done: 0 pass, 1 fail"; ok $? "a failing test not on the retry list fails at once"
echo "Test done: $P pass, $F fail"
rm -rf "$T"
[ "$F" -eq 0 ]
