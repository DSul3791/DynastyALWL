# log_* species chains: code spec for Tyler (Sal, 2026-10-31; guide finding F-11)

## Problem
Wood items come in two classes (data/items/wood_species.json `class_items`): hardwood gives `firewood` and `wooden_block`, softwood gives `firewood_soft` and `wooden_block_soft`. Recipes that name `wooden_block` therefore cannot be made by someone who only has conifers (spruce, pine, fir). The `log_*` species items (log_oak, log_birch, log_scots_pine, log_spruce and so on) and their lumber and beam recipes are split the same way.

## Already fixed in data
The Wooden hammer has a second recipe taking `wooden_block_soft`.

## To do in code (one rule, not more recipes)
1. **Any block works:** a recipe ingredient may name a *group* (`wood_block`) that accepts both `wooden_block` and `wooden_block_soft`. Add an optional `any_of: ["wooden_block", "wooden_block_soft"]` form for a needs row in recipes.json, read by `_queue_craft`, `_pack_covers`, the craft planner (src/shared/craft_planner.gd) and the client recipe list. Then the second hammer recipe can be retired.
2. **Same for logs:** `log` accepts any `log_*` species; a recipe asking for `log` takes whichever the pack holds (the species tag proposal in ITEM_CODE_HANDOFF.md section 1 supersedes the species items; do 1 first if that is done).
3. Tests: test_server_items (hammer made from a soft block, from a hard block, with both in the pack), test_auto_craft (planner picks the one it finds, no ambiguity message), save_compat (no item change).
Files: src/stream/server_items.gd, src/shared/craft_planner.gd, src/client/inventory_view.gd (recipe availability), data/items/recipes.json.
