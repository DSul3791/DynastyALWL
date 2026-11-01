# Action plan: new-player switch, R1 gentle rules, recipe open list

Branch: claude/steve-new-player (plan only; devstop). Build 789, CHANGE_LABEL: RESTART (server code and data; no bake, no flora bump). Answers EARLY_GAME_LIST steps 1, 6, 8 and walkthrough blocker 1.

## 1. "Become a new player" switch (step 1, Dave: yes)
- Esc > Admin settings gets one button "Play as a new player" (admin only, like Admin mode). It sends a new inventory_action kind ACT_NEW_PLAYER (same pattern as ACT_CLEAR_DROPS and ACT_ADMIN_MODE: no protocol bump).
- Server, for that peer: empties the pack and worn gear (items vanish, a confirm line first: "This empties your pack"); fresh vitals (_new_vitals); Admin mode OFF for the peer (so crafting costs real ingredients); clears the per-character hint-fired flags; sets `new_player` on the character record so a restart keeps it. Optional second action "Back to admin" turns the flag off (items are not returned).
- Stays where it stands; it does not teleport. Spawn extras (sticks and stones near respawn, drops.json spawn_boost) apply only after a real respawn, so Mike tests from the spawn point by walking there or dying. Decision for Tyler: add a "to spawn" step to the switch? I recommend NO (the spawn point is chosen last).
- Test: test_new_player.gd: pack empty, worn empty, admin mode off, flag saved and reloaded, a second press does nothing odd, a non-admin is refused.

## 2. R1 gentle rules (step 8)
- Sickness already costs food and water only (sickness.json: symptoms take kcal and ml, no health). Nothing to change; the test pins it so a later edit cannot add health loss.
- Eat-once memory ("harm teaches and is remembered") does NOT exist in code. Out of this plan; it is a separate small job (per-character set of tried foods + the voice line) after 790.

## 3. Warmth under a canopy (step 6) — a real conflict
- Dave's rule: canopy is rain/sun cover only, warmth is fire and clothes. warmth.json today: covered_wind_share 0.3, covered_rain_share 0.0, and cover.at counts a tree crown as cover, so standing under a tree cuts wind chill by 70 percent.
- Fix (data + one small code split): wind shelter only for a ROOF (building, lean-to), not a tree crown; rain share stays 0 for both. Needs cover.at to say which kind of cover (roof vs crown). Decision for Tyler: do it (recommended, Dave's words) or leave canopy wind shelter as a small bonus.

## 4. Recipe open list (Tyler's ruling: known=true from the start, one data list)
- Check Tyler asked: does known=true break craft()? NO. craft() and the queue only test the `known` flag, then the station and the ingredients (recipe_table.gd:88, server_items.gd:6269). known=true changes nothing else.
- But known is not the real blocker for walls: wall, floor, roof, doorway and window kits need LUMBER (sawmill, R3), and the roof/foundation kits are the only ones reachable (foundation = 8 stone + 2 clay at a workbench). Opening them without a way to get lumber changes nothing. So the list must carry Sal's new pieces (thatch wall, rough bed, shore net, tripod pot, hearth, hammer ladder) as they land.
- Mechanism: data/items/open_recipes.json {"open": ["foundation_section_kit", ...]}; recipe_table.gd sets known=true for the ids on load (client and server share the table, so the craft UI agrees). Unknown ids fail the test. Sal adds a name when a recipe is ready; no recipes.json edits. First list: foundation_section_kit, the R1 recipes Sal's sal-r1-recipes defines, rough_bed, shore_net, tripod pot, clay hearth.
- Test: every id exists; each opened recipe crafts with exact ingredients at its station; recipes not listed stay locked.

## Cost and risk
Server: one action handler, one save field, one data file read at start. No new traffic. Risk: the switch deletes a tester's pack (confirm line, admin only).
Not run in Godot in the cloud. Follow-ups, not in this plan: respawn at own bed (needs sal-rough-bed), inner-voice settings panel (steve-inner-voice-panel after 790), hint engine (the H1-H35 table).
