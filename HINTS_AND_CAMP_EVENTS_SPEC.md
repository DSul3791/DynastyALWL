# Hints on screen and the camp-goal events: code spec for Tyler (Sal, 2026-10-31)

## 1. Hints (data/items/hints.json, 26 lines, 12 words or fewer, read by nothing today)
Each row: `id`, `trigger` (free text naming a moment), `text`, optional `goal` (a starter goal id). The server already sends the next hint when a goal completes ("next-hint notices", server_items.gd goals). Add:
1. **Where they appear:** the notice line at the top of the screen (the same channel as "You work out how to make X"), one line, shown for 6 seconds, and listed in the goal screen next to the goal.
2. **When:** show a hint at most once per character per hint id (save `hints_seen` beside `goals_done` in characters.json), when its trigger becomes true. Map the trigger names to checks:
| trigger | check |
|---|---|
| first_frame, moved | character spawned; moved 5 m |
| water_in_view | water within 20 m and Water bar under 100 |
| after_drink | event `drink` |
| 8_sticks, 12_fibre | pack holds 8 sticks, 12 plant fibre |
| 2_twine_1_stone_1_stick | pack holds those |
| axe_made, axe_held_near_tree | made stone axe; axe held and a tree within 20 m |
| tree_down | event `tree_felled` |
| 6_sticks_3_stones, kit_made, fire_placed, fire_lit | pack holds them; made `campfire_kit`; event `placed` what fire; event `fire_lit` |
| hungry | Food bar under 80 |
| fire_burning_cold | fire lit and Warmth under 70 |
| leanto_made, leanto_placed, bed_placed | made `lean_to_kit`; `placed` lean_to; `placed` rough_bed |
| workbench_placed, spear_made | `placed` workbench; made spear |
| warmth_under_70, dusk | Warmth under 70; hour 18 to 20 |
3. **Repeat:** if a hint's goal is still open 5 minutes after it was shown, show it once more (Dave's answer pending; default yes, once).
4. **Test:** extend test_goals: a hint is sent once when its trigger holds, not twice; saved in characters.json.

## 2. Camp-goal events (data/items/camp_goals.json; `needs_code` true)
| event | emit when | check shape |
|---|---|---|
| `worn_warmth` | worn pieces change (ACT_WEAR / UNWEAR) | goal `{event:"worn_warmth", min: 0.7}`: sum of worn `warmth` (clothing.json, capped 0.85) is at least `min` |
| `talked` | a dialogue with an NPC opens | goal `{event:"talked", npc:"edda", hour_between:[19,23]}`: count when the NPC id and game hour match |
| `moved_lit_night` | every second while the player holds a lit torch (or stands within 4 m of a lit fire) between dusk and dawn | goal `{event:"moved_lit_night", metres:100}`: accumulate distance walked; complete at `metres` |
| made `jerky`, `salted_fish`, `smoked_fish`, `dried_berries`, `candle`, `torch` | already counted by `made_item` | no code |
Reward shape `{coin_copper, rep}`: `rep` is new; apply with the existing add_rep effect for the NPC named in the goal (or a town-wide reputation if none).

## 3. Bronze pick tier (from CODE_MISMATCHES.md, repeated here so it is not lost)
In `_hit_boulder`'s ore branch require the held tool's `material` to be in `boulders.json ore.needs_material[<ore name>]`; refuse with a notice "This pick is too soft for that ore." Test: a stone pick on an iron outcrop gives stone only; a bronze pick gives iron ore.
