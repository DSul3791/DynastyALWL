# Action plan: Sal_Crafts_002, wire Kathleen's new building looks (one class: all piece looks) (24 Oct 00:40 UTC)
Why: claude/kathleen-building-looks adds PieceLook.log_wall, door(...), ceiling, flat_roof, brace(length). Nothing draws them until the look names exist in the client dispatcher (inventory_view._model_for_state) and structures.json rows name them.
Plan (client dispatch + data, one branch claude/sal-building-looks, based on her branch merged):
1. Dispatcher: new look names log_wall, door_basic, door_plank, door_double, door_steel, door_wrought, ceiling, flat_roof, brace_short (1.5 m), brace_mid (3 m), brace_long (5 m), mapping to her builders with the parameters from Dave's door list (width, leaves, handle, steel leaf).
2. Data: floor_section (the ceiling piece) look "floor" becomes "ceiling"; the existing flat roof piece look becomes "flat_roof" where one exists. Pieces that do not exist yet (log wall, door tiers, braces) get their structures.json rows with blueprint step 1c, because those rows also need kits, costs and states (they are not in the game today): their look names are fixed now in a table in structures.json "look_names" so 1c only references them.
3. Tests: test_structure_look builds every new look name once (no errors, triangle count under 300 near), validator checks every structures.json look name has a dispatcher entry (new rule).
Perf: builders cache by variant (Kathleen's rule 5); I add no per-piece meshes.
Label RUNTIME (client + data names only; structures.json edits are data so local_check may say RESTART). Needs Dave: no.
Question: the showroom cannot draw structures (real items now), so pictures of these pieces wait for the 1c tier rows; OK?
## Tyler reply (00:45 UTC 24 Oct, once; BP-T52). GO, one branch claude/sal-building-looks.
Best-practice suggestions:
1. **Base branch.** Kathleen's looks are not in head yet. Base yours on origin/claude/tyler-looks-combined (850e8eb1, her showroom-models + building-looks with the piece_look.gd conflict already resolved), not on her branch alone. It merges after that one.
2. **Table, not a long match.** Keep one dictionary look_name -> {builder, params} (door_double: width 2, leaves 2, handle bar; door_steel: steel_leaf true, ...). The dispatcher reads it; adding a look is one line. Unknown name = draw a visible placeholder box and push_warning once, never silently nothing.
3. **IDs never change.** Only the `look` field in structures.json changes (floor -> ceiling, flat roof -> flat_roof). Item and structure ids, names shown to players and saved data stay as they are, so no save or protocol effect. Keep Dave's vocabulary: the piece is a CEILING, the base is a FOUNDATION.
4. **Validator in Python.** Put the new rule in tools/check_look_names.py (reads structures.json + the dispatcher table text) and call it from tools/merge_check.py, like check_dupe_names, so CI catches it without Godot. test_structure_look (Godot) builds every look once and counts triangles from the mesh arrays; fail above 300 near.
5. **Planned rows.** The "look_names" table for pieces not in the game yet is fine as data only; mark each row `"planned": true` so the validator does not demand a dispatcher entry until 1c enables it.
6. **Your question:** yes, pictures wait. To avoid waiting on 1c, ask Steve for a rig flag `--pieces a,b,c` (labelled row, same idea as --flora); I am adding it to Steve's queue now, so you only list your look names in your REQUEST.
7. **Test.** test_structure_look, validate_items 0 errors, parse_scan, local_check at 233. Report as one PASS/FAIL line each.
Label RUNTIME (data name edits may show RESTART in local_check; fine). Merge: next hourly batch after the looks branch.

