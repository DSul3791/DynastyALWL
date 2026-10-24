#!/bin/bash
# BP-T55: tooling branches carry syntax checks. Run before handing a rig change to Mike: bash -n on the shell tools, py_compile on the python ones,
# and the item tables merge without a duplicate name or number. Prints "rig syntax: N pass, N fail".
cd "$(dirname "$0")/.." || exit 2
PASS=0; FAIL=0
for f in tools/look_rig.sh tools/check_rig_syntax.sh; do
  if bash -n "$f"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL bash -n $f"; fi
done
for f in tools/item_numbers.py tools/look_rig_seed.py; do
  if python -c "import ast,sys; ast.parse(open('$f',encoding='utf-8').read())"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL syntax $f"; fi
done
if python tools/item_numbers.py stone > /dev/null; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL item tables (duplicate name or number)"; fi
echo "rig syntax: $PASS pass, $FAIL fail"
[ "$FAIL" = 0 ]
