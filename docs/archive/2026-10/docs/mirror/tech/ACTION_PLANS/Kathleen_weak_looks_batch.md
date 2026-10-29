# Weak looks batch (Kathleen, 25 Oct): branch claude/kathleen-weak-looks db50b5ab (contains claude/kathleen-held-pose 27677835)
Class of small look-only changes, all RUNTIME (no bake, no restart-sensitive data):
1. Pickaxe held turn (held_item.gd HELD_LOOK_TURN "pick"): head runs across the player, points droop; fixes the "bent sideways from the front" Dave reported. Test: Mike front/behind/right at 2 m.
2. Steel vs iron pickaxe (basic_look.gd pick shape + looks.json steel_pickaxe bits ["steel"]): polished ridge and brass collar on steel, dark forged band on iron.
3. Kit lid emblems (basic_look.gd "kit" shape; looks.json bits on saw_mill_kit, woodworking_table_kit, workbench_kit, tool_rack_kit, vice_kit, four forge kits): kits no longer look the same. Sal owns looks.json; additive bits only.
4. Water wheel (piece_look.gd): axle, two 10-spoke frames with rim, 10 slanted paddles; saw mill reuses it. check_look_names passes.
5. Included from held-pose: tool heads, saw/hammer shapes, hand/pose tuning, arms frozen at 27677835.
Tests: parse and mesh builds headless, check_look_names, Mike front/behind/right pickaxe, kit and wheel pictures from David3. Not yet seen rendered.
