# Action plan: tool tiers audit (Sal, branch claude/sal-tool-tiers)

**Label:** RUNTIME (data and docs only; no code, no recipes changed in this step)

## What
- `tools/tool_tiers.py` writes `design/TOOL_TIERS.md`: tool class x tier matrix from items.json, with `--check`.
- First finding: tiers are not material-consistent (stone axe/knife tier 1, stone hammer/hoe/spade tier 2, saw only tier 3 iron, pick only future iron/steel). Nothing exists between stone and iron, and there is no early saw, sickle, scythe or rake.

## Next (separate plans, only after your GO)
1. Decide the tier numbers per class (one table in TOOL_TIERS.md).
2. Add the missing early tools with recipes (no benches for hand-made wood, bench for tools per Dave).

## Master list generators (answer to your overlap question)
Keep `tools/item_master.py` (yours, already in use). Port into it the use lines, `item_uses.json`, the inspect cell and the poison check from `tools/item_master_list.py`, then delete `item_master_list.py`. I will do that on `claude/sal-item-master` if you say GO.

## Risk
None: generated doc only.
