# Crafting time and pacing pass (Sal, 2026-10-31)

Request: the guide found the start too fast (the first 4 minutes); aim for about 12 minutes of play to reach a shelter and a bench, without making fibre a grind. This is a proposal with numbers; no recipe was changed.

## What the data says today (craft_s from recipes.json)
| Item | Now (s) | Proposed (s) | Note |
|---|---|---|---|
| Twine | 2 | 3 | 14 twine in the first kit |
| Stone axe | 4 | 10 | the first real tool |
| Campfire | 3 | 8 | |
| Small shelter | 8 | 25 | |
| Rough bed | 10 | 25 | |
| Camp bench (Workbench) | 12 | 40 | |
| Wooden spear / Stone spear | 3 / 4 | 6 / 10 | |
| Stone knife | 3 | 8 | |
| Wooden spade | 4 | 8 | |
| Chopping block | 3 | 8 | |
| Tool rack | 10 | 20 | |
| Wooden bow | 8 | 20 | |
| Stone hammer | 6 | 15 | |
| Stone pickaxe | 10 | 25 | |
| Woven chest | 8 | 20 | |
| **Total of these 16** | **98 s** | **251 s** | +153 s, about 2.5 minutes |

The whole starter kit (axe, fire, shelter, bed, bench, bow and the twine for them: 14 twine, 36 fibre) costs 98 seconds of crafting today. Real time is dominated by gathering, which nobody has timed.

## Where the other minutes must come from (not craft time)
To move 4 minutes to 12, crafting adds 2.5 minutes. The other 5 to 6 minutes have to come from the world and the tools, owned by other lanes:
1. **Pickup pace.** `gather_pace_ms` and the E-hold pace in server_items.gd decide how fast a plant or stick is taken. A short pause per pickup (for example 0.8 s) makes 36 fibre plus 30 sticks about 1 to 2 minutes, which is the grind the request wants to avoid; keep it at the current value unless play shows the start is still too quick.
2. **Walking.** Sticks and stones come from ground scatter (about 2 to 4 per 32 m cell, more near the spawn). The spawn boost makes the first minutes short; reduce `spawn_boost` (stones_max_boost, sticks_max_boost in drops.json ground_scatter) from 4 to 2 so the player walks between cells. Cost: nothing in the kit gets more expensive.
3. **Effort.** Crafting causes no exertion today (exertion.json covers movement, tools and loads). A 0.3 effort for the duration of a craft over 20 s would make long crafts tiring, not wasteful. Code change.
4. **Tree felling.** 30 blows for a thin tree is already about 30 to 40 s. Leave it.

## Recommendation
Apply the craft_s column (one data edit, safe for tests: they check outputs, not craft seconds, except the short waits in test_first_hour and test_auto_craft that run fixed seconds; those waits need raising about 2.5x) and reduce `spawn_boost` stones and sticks to 2; then time one fresh play-through and bring the result back here before touching fibre costs. I did not apply either without a play-through to measure, because the guide has not timed gathering yet and a wrong guess would make the start slow instead of paced.
