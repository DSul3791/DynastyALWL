#!/bin/bash
# Self-test of tests_for_diff.py and run_tests.sh with a fake Godot (no Godot needed): prints "Test done: N pass, M fail".
cd "$(dirname "$0")/.." || exit 2
PY="${PYTHON:-python3}"; P=0; F=0
ok() { if [ "$1" = "0" ]; then P=$((P + 1)); else F=$((F + 1)); echo "FAIL $2"; fi; }
T=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/gt_$$"); mkdir -p "$T"
sel() { "$PY" tools/tests_for_diff.py --paths "$@"; }
field() { "$PY" -c "import json,sys;d=json.loads(sys.stdin.read());print($1)"; }

[ "$(sel docs/mirror/x.md tech/ACTION_PLANS/y.md | field "d['class']+str(len(d['fast']))")" = "docs0" ]; ok $? "docs only selects no tests"
[ "$(sel project.godot | field "len(d['fast'])")" -gt 60 ]; ok $? "project.godot selects all fast tests"
sel src/stream/terrain_net.gd | field "d['plan']=='change' and 'test_net_look' in d['fast'] and 'test_inventory' in d['fast'] and len(d['fast'])<60" | grep -q True; ok $? "a hub edit in a change plan selects its core list and the always set, not every fast test"
[ "$(sel src/stream/server_items.gd --wide | field "len(d['fast'])")" -gt "$(sel src/stream/server_items.gd | field "len(d['fast'])")" ]; ok $? "--wide follows every chain of loads and selects more than the change plan"
sel src/worldgen/tools/held_tool.gd | field "len(d['fast'])>11" | grep -q True; ok $? "a test helper selects the tests that use it"
[ "$(sel weird/new.gd | field "len(d['fast'])")" -gt 60 ]; ok $? "an unknown path selects all fast tests"
sel data/items/items.json | field "'test_eat_once' in d['fast'] and 'test_inventory' in d['fast']" | grep -q True; ok $? "item data selects the item group and the always set"
sel src/client/piece_look.gd | field "'test_tool_looks' in d['fast'] and 'warnings' in d['checks'] and bool(d['pictures'])" | grep -q True; ok $? "a look file selects the look tests, the warnings check and the picture lane"
sel worlds/base_world/tiles/a.tile | field "d['class']=='bake' and d['pin'] and 'test_worldgen' in d['slow']" | grep -q True; ok $? "baked tiles select the slow lane and the pin check"
sel src/worldgen/tools/test_traps.gd | field "'test_traps' in d['fast']" | grep -q True; ok $? "a changed test selects itself"
"$PY" tools/tests_for_diff.py --check-lanes >/dev/null; ok $? "every name in test_lanes.json is a test"
sel src/worldgen/tools/export_tile_maps.gd | field "len(d['slow'])==0"  | grep -q True; ok $? "an offline worldgen tool script does not start the slow lane"
sel tools/erosion_precarve/rock.py | field "d['class']=='docs' and len(d['fast'])==0" | grep -q True; ok $? "an offline python tool selects no tests"
sel src/worldgen/tile/tile_drainage.gd --wide | field "len(d['slow'])>0" | grep -q True; ok $? "worldgen runtime code: the wide plan selects the slow tests that reach it"
sel src/worldgen/tile/tile_drainage.gd | field "'test_head_pond_fill' not in d['slow'] and 'test_drainage_small' in d['fast']" | grep -q True; ok $? "worldgen water code selects the small tests, not the big release tests"
sel worlds/base_world/tiles/tile_3_4.tile | field "'test_head_pond_fill' in d['slow'] and 'test_tile_lakes' in d['slow']" | grep -q True; ok $? "baked tile data selects the big release tests"
"$PY" tools/tests_for_diff.py --paths src/worldgen/tile/tile_drainage.gd --full | field "len(d['slow'])==len(json.load(open('tools/test_lanes.json'))['slow']) and len(d['fast'])>60" | grep -q True; ok $? "--full selects the whole slow lane and every fast test"
sel tools/run_tests.sh | field "d['class']=='tools' and len(d['fast'])==0 and 'selftest' in d['checks']" | grep -q True; ok $? "a gate tool edit selects the lane check and selftest, no game tests"
sel src/water2/water_field.gd | field "'test_water_field' in d['fast'] and 'test_water_flow_texture' in d['fast']" | grep -q True; ok $? "src/water2 code selects the src/water2 tests that load it"
sel src/water2/test_water_window.gd | field "'test_water_window' in d['fast']" | grep -q True; ok $? "a changed src/water2 test selects itself"

# <base> <head> diffs from the merge base: a base that moved on past head adds none of its own newer files (19 Nov 2026).
R="$T/repo"; mkdir -p "$R"
( cd "$R" && git init -q && git config commit.gpgsign false && git config user.email t@t && git config user.name t && echo a > a.gd && git add . && git commit -qm c0 && git branch -q -M base0 \
	&& git checkout -qb br && echo b > br.gd && git add . && git commit -qm br && git checkout -q base0 && echo d > dev_only.gd && git add . && git commit -qm dev \
	&& git checkout -q --orphan lone && git rm -rqf . && echo l > lone.gd && git add . && git commit -qm lone ) >/dev/null 2>&1
mp() { "$PY" -c "import sys;sys.path.insert(0,'tools');import tests_for_diff as t;print(sorted(t.changed_paths(sys.argv[1],sys.argv[2],sys.argv[3])))" "$1" "$2" "$R"; }   # paths as arguments: Git Bash converts them for Windows python
[ "$(mp base0 br)" = "['br.gd']" ]; ok $? "a base that moved on: only head's own change (not dev_only.gd)"
[ "$(mp base0~1 br)" = "['br.gd']" ]; ok $? "a base that is an ancestor: the same as the two-dot diff"
# --same-change: a clean merge of base into a reviewed branch keeps its patch; a new edit does not. changed_names: the names an edit touched.
( cd "$R" && git checkout -q br && git checkout -qb br2 && git merge -q --no-edit base0 && git checkout -qb br3 && echo c >> br.gd && git commit -qam c3 \
	&& git checkout -q base0 && printf 'func _helper():\n\treturn 1\n\nfunc public_call():\n\treturn _helper()\n\nfunc other():\n\tpass\n' > h.gd && git add . && git commit -qm h \
	&& sed -i 's/return 1/return 2/' h.gd && git commit -qam h2 && git tag h2 \
	&& printf '@rpc("authority", "call_remote", "reliable")\nfunc net_msg():\n\tpass\n\nfunc keep_me():\n\tpass\n\nfunc gone_soon():\n\tpass\n' > r.gd && git add . && git commit -qm r && git tag r0 \
	&& sed -i 's/"authority"/"any_peer"/' r.gd && git commit -qam r1 && git tag r1 \
	&& head -n 6 r.gd > r2 && mv r2 r.gd && git commit -qam r2 && git tag r2 \
	&& git checkout -q br && git checkout -qb bin1 && printf '\000a' > m.bin && git add . && git commit -qm b1 \
	&& git checkout -q br && git checkout -qb bin2 && printf '\000b' > m.bin && git add . && git commit -qm b2 && git checkout -q base0 ) >/dev/null 2>&1
cn() { "$PY" -c "import sys;sys.path.insert(0,'tools');import tests_for_diff as t;print(sorted(t.changed_names(sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4])))" "$1" "$2" "$3" "$R"; }
[ "$(cn r0 r1 r.gd)" = "['net_msg']" ]; ok $? "changed_names: an @rpc line edit names the function it annotates"
cn r1 r2 r.gd | grep -q "'gone_soon'"; ok $? "changed_names: a deleted function is named"
pid() { "$PY" -c "import sys;sys.path.insert(0,'tools');import tests_for_diff as t;print(t.patch_id('base0',sys.argv[1],sys.argv[2]))" "$1" "$R"; }
[ "$(pid br)" = "$(pid br2)" ] && [ "$(pid br)" != "None" ]; ok $? "--same-change: merging the base into a reviewed branch keeps the same change"
[ "$(pid br)" != "$(pid br3)" ]; ok $? "--same-change: a new edit is a different change"
[ "$(pid bin1)" != "$(pid bin2)" ]; ok $? "--same-change: two different binary files are different changes"
[ "$(cn h2~1 h2 h.gd)" = "['_helper', 'public_call']" ]; ok $? "changed_names: the edited private function and its public caller, not the untouched one"
[ "$(mp base0 lone)" = "$(cd "$R" && "$PY" -c "import subprocess;print(sorted(subprocess.run(['git','diff','--name-only','base0','lone'],capture_output=True,text=True).stdout.split()))")" ]; ok $? "no shared history: the plain two-dot diff"

# changed_rows: an item-data edit made only of rows names the changed rows; a rule value or a new section takes the whole group (None).
( cd "$R" && git checkout -q base0 && printf '{"note": "a", "next_number": 3, "items": {"stone_axe": {"n": 1}, "flint": {"n": 2}}}' > it.json && git add . && git commit -qm j0 && git tag j0 \
	&& printf '{"note": "b", "next_number": 4, "items": {"stone_axe": {"n": 9}, "flint": {"n": 2}, "new_rock": {"n": 3}}}' > it.json && git commit -qam j1 && git tag j1 \
	&& printf '{"note": "b", "next_number": 4, "pace": 2, "items": {"stone_axe": {"n": 9}, "flint": {"n": 2}, "new_rock": {"n": 3}}}' > it.json && git commit -qam j2 && git tag j2 ) >/dev/null 2>&1
cr() { "$PY" -c "import sys;sys.path.insert(0,'tools');import tests_for_diff as t;r=t.changed_rows(sys.argv[1],sys.argv[2],'it.json',sys.argv[3]);print(sorted(r) if r is not None else None)" "$1" "$2" "$R"; }
[ "$(cr j0 j1)" = "['new_rock', 'stone_axe']" ]; ok $? "changed_rows: an edited and an added row, not the untouched one or the note and next_number"
[ "$(cr j1 j2)" = "None" ]; ok $? "changed_rows: a new top-level value is not rows (whole item group)"
# select() with item_ids: a row a test names selects that test, not the whole group; a row no test names (a new row) takes the whole group.
si() { "$PY" -c "import sys,json;sys.path.insert(0,'tools');import tests_for_diff as t;d=t.select(['data/items/items.json'],t.load_lanes(),item_ids={'data/items/items.json':set(sys.argv[1].split(','))});print(len(d['fast']),'test_eat_once' in d['fast'],'validate_items' in d['checks'])" "$1"; }
G=$(si zz_no_such_row_x); N=$(si clay_jug); [ "${N%% *}" -lt "${G%% *}" ] && [ "${N##* }" = "True" ]; ok $? "item rows a test names select fewer tests than the whole group, with validate_items ($N vs $G)"
[ "$(si clay_jug,zz_no_such_row_x)" = "$G" ]; ok $? "a changed row no test names takes the whole item group"
sel data/items/looks.json | field "'test_eat_once' not in d['fast'] and 'test_item_looks' in d['fast'] and 'validate_items' in d['checks']" | grep -q True; ok $? "looks.json (client only) skips the item group, keeps its direct loaders and validate_items"
"$PY" tools/tests_for_diff.py --paths src/worldgen/tile/tile_drainage.gd --full --no-slow | field "len(d['slow'])==0 and len(d['fast'])>60" | grep -q True; ok $? "--no-slow leaves the slow lane out (main gate Lane A)"
sel data/items/items.json | field "'test_animals_weather' not in d['fast'] and 'test_death' not in d['fast']" | grep -q True; ok $? "item group name patterns match whole name parts ('eat' is not in test_animals_weather)"
cat > "$T/fakegodot" <<'F'
#!/bin/bash
for a in "$@"; do case "$a" in res://*) S="$a";; esac; done
N=$(basename "$S" .gd)
case "$N" in
	test_animals) C="${FAKE_COUNT:?}"; n=$(cat "$C" 2>/dev/null || echo 0); echo $((n + 1)) > "$C"; [ "$n" -eq 0 ] && { echo "FAIL first time"; exit 1; };;
	test_broken) echo "FAIL always"; exit 1;;
	test_script_error) echo "SCRIPT ERROR: bad"; exit 0;;
	validate_items) [ -n "$FAKE_ITEMS_BAD" ] && { echo "validate_items: 2 errors"; exit 0; }; echo "validate_items: 0 errors"; exit 0;;
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
# every check the plan lists runs (22 Nov 2026: validate_items was listed and never run); an unknown check fails the run
echo '{"fast":["test_inventory"],"timing":[],"slow":[],"checks":["validate_items"]}' > "$T/pc.json"
OUTTXT=$(bash tools/run_tests.sh --jobs 1 --out "$T/o4" --plan "$T/pc.json" 2>&1); echo "$OUTTXT" | grep -q "Test done: 2 pass, 0 fail"; ok $? "a plan's validate_items check runs and counts as a pass"
OUTTXT=$(FAKE_ITEMS_BAD=1 bash tools/run_tests.sh --jobs 1 --out "$T/o5" --plan "$T/pc.json" 2>&1); [ $? -ne 0 ] && echo "$OUTTXT" | grep -q "FAILED check validate_items"; ok $? "validate_items errors fail the run"
echo '{"fast":["test_inventory"],"timing":[],"slow":[],"checks":["no_such_check"]}' > "$T/pc2.json"
OUTTXT=$(bash tools/run_tests.sh --jobs 1 --out "$T/o6" --plan "$T/pc2.json" 2>&1); [ $? -ne 0 ] && echo "$OUTTXT" | grep -q "CHECKS NOT RUN: no_such_check"; ok $? "a check the runner does not know is named and fails the run"
# pc_queue.sh with a fake gate, slot and gh: pass, real failure (fails solo too), conflict, load noise (passes solo twice),
# missing branch, already merged; all rows land in one results file with the full tested head.
cat > "$T/fake_gate.sh" <<'FG'
echo "HEAD=$1"
case "$1" in
	$PCQ_A) echo "Test done: 5 pass, 0 fail"; echo "NEW failures: none"; echo "CHECKS: pass"; exit 0;;
	$PCQ_B) echo "Test done: 4 pass, 1 fail"; echo "NEW failures:  test_cave_dressing"; echo "CHECKS: pass"; exit 1;;
	$PCQ_D) echo "Test done: 4 pass, 1 fail"; echo "NEW failures:  test_noisy"; echo "CHECKS: pass"; exit 1;;
	*) echo "CONFLICT: the trial merge with main fails:"; exit 2;;
esac
FG
mkdir -p "$T/slot/tools"
cat > "$T/slot/tools/run_tests.sh" <<'FR'
for a in "$@"; do case "$a" in test_noisy) echo "Test done: 1 pass, 0 fail"; exit 0;; test_*) echo "Test done: 0 pass, 1 fail"; exit 1;; esac; done
FR
printf '#!/bin/bash\n[ "$3" = "906" ] && echo MERGED || echo OPEN\n' > "$T/gh"; chmod +x "$T/gh"
H=$(git rev-parse HEAD)
for k in a:0 b:1 c:2 d:3; do git update-ref "refs/remotes/origin/pcq-selftest-${k%:*}" "$(git rev-parse "HEAD~${k#*:}")"; done
printf '# test queue\n1 901 pcq-selftest-a\n\n2 902 pcq-selftest-b slow\n3 903 pcq-selftest-c\n4 904 pcq-selftest-missing\n5 905 pcq-selftest-d\n6 906 pcq-selftest-a' > "$T/queue.txt"
OUTTXT=$(PCQ_A=$H PCQ_B=$(git rev-parse HEAD~1) PCQ_D=$(git rev-parse HEAD~3) PC_QUEUE_GATE="$T/fake_gate.sh" PC_QUEUE_SLOT="$T/slot" PC_QUEUE_GH="$T/gh" bash tools/pc_queue.sh "$T/queue.txt" --out "$T/res.md" 2>&1); RC=$?
[ $RC -eq 1 ]; ok $? "pc_queue exits 1 when any PR did not pass"
grep -q "| #901 | \`pcq-selftest-a\` | $H | PASS | 5 pass, 0 fail | - |" "$T/res.md"; ok $? "pc_queue writes a PASS row with the full 40-character head and the test count"
grep -q '| #902 | .* | FAIL | 4 pass, 1 fail | test_cave_dressing |' "$T/res.md"; ok $? "pc_queue keeps FAIL when the test also fails alone"
grep -q '| #903 | .* | CONFLICT with main |' "$T/res.md"; ok $? "pc_queue marks a trial-merge conflict"
grep -q '| #904 | .* | ERROR: branch not found |' "$T/res.md"; ok $? "pc_queue keeps going past a missing branch"
grep -q '| #905 | .* | PASS (load noise: test_noisy) |' "$T/res.md"; ok $? "pc_queue marks load noise when the failing test passes alone twice"
grep -q '| #906 | .* | skipped: already merged |' "$T/res.md"; ok $? "pc_queue skips a merged PR, also on a last line with no newline"
[ "$(grep -c '^| [0-9]' "$T/res.md")" = "6" ]; ok $? "pc_queue skips comments and blank lines (6 rows)"
for k in a b c d; do git update-ref -d "refs/remotes/origin/pcq-selftest-$k"; done
echo "Test done: $P pass, $F fail"
rm -rf "$T"
[ "$F" -eq 0 ]
