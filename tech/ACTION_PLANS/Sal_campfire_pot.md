# Action plan: campfire pot, hand-made twine tests, craft menu categories and search (Sal)
Branch: claude/sal-cooking-tripod. One plan for Tyler per BP-T52.

## 1. Campfire pot (built, head after 6e30ab9b)
- Renamed (items 254/255, recipe 165 kept); old "tripod_pot" struct rows load as campfire_pot (structures.json legacy_kinds).
- Snaps onto the nearest small fire within 2 m (laid, lit or out; not a bonfire; one pot per fire). No fire nearby: nothing placed, kit stays in the pack, message "Lay a fire first".
- While a pot hangs on a fire it never passes the firewood stage (fire tiers: `_fire_best_state` skips the log tier). Taking the pot down lifts the cap, the fire burns on.
- Cooks only while that fire is lit. Fire out: the craft waits at its progress (not reset, nothing lost) and resumes when the fire is lit again.
- The link is the shared position and is never saved (fire["pot"] is recomputed on load and every fire tick), so nothing can dangle; attached, fire out and detached all save and reload the same.
- Fire tiers code change: `_fire_best_state` only (3 lines); `_refresh_pots` added.
- Tests: test_campfire_pot.gd. One check still FAILS: "an old state 1 fire loads and takes the pot" (synthetic old save; to fix).

## 2. Twine by hand (Dave 23:49)
Twine is recipe 1: 3 plant fibre, 2 s, known from the start, no station or tool, so it is in the player's own crafting menu. The 4 failing 792 tests assumed the old axe/spear recipes. Updated: test_inventory (twist 10 twine, spear = wooden spear + 5 twine), test_first_hour (twist 5 twine before the axe, more fibre dropped, a laid fire counts as placed), test_first_town (twine first, fire set lit), test_slot_sounds (door_thatch_open/close slots reuse the wood door clips; Kathleen to record real ones). All four pass: inventory 0 fail, first_hour 0 fail, first_town 21 steps 0 fail, slot_sounds 0 fail.

## 3. Craft menu categories and search (Dave 23:50), next build
Search box at the top filters by name as you type. Category tabs: All, Tools, Weapons, Shelter and building, Fire and cooking, Food and drink, Clothing, Materials, Containers and furniture. Each recipe gets a "category" in recipes.json (default by gives-kind); alphabetical inside each. Client only (inventory_view.gd), CHANGE_LABEL RESTART. Test: filter text "tw" shows Twine; a category shows only its recipes.
