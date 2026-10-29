# Exertion by material hardness and tool size (proposal, nothing built)

Dave (2026-10-22): mining harder stuff and using bigger tools costs more exertion, so players must build fitness and strength to use them.

## What exists
- `exertion.json`: every tool use holds effort at `tool_effort[class]` for `work_s` (2.5 s). Axe and pick 1.05, spade 0.9, knife 0.55, torch 0.4. Effort above `rest_effort` (0.52) builds strain; over 1.0 you are over-exerted, past 1.4 you faint. Running is 1.0.
- Fitness attribute (-10..+10, trains with time winded) scales how fast strain rises (+10 is winded after 1.65 times as long). Strength attribute: designed, not yet built (carry limit, tool work speed). Skills Woodcutting, Mining and Digging halve blows at level 100 (SKILLS_AND_ATTRIBUTES.md).
- DESIGN_IDEAS 5.x already says: every harvestable thing and rock has a hardness, every tool a power; a tool works when power >= hardness. Tool tiers 1 to 4 exist in items.json (wood/stone/iron/steel).

## Proposal: base cost, per action
`effort = tool_effort[class] x size_factor x hardness_factor`, then clamp to 0.3 .. 1.6 (before any multiplier).

- `size_factor` per tool, a number in items.json (default 1.0): small hand tools 0.8, normal 1.0, big two-handed tools (felling axe, sledge, large pick, maul) 1.25, heavy mining tools 1.4.
- `hardness_factor` per material, a table in a new data file `data/items/hardness.json`: soft soil/sand 0.8, clay 0.95, gravel 1.0, softwood 0.95, hardwood (oak) 1.1, soft rock/limestone 1.15, granite 1.3, ore-bearing rock 1.35.
- Examples: iron spade in soil 0.9 x 1.0 x 0.8 = 0.72 (sustainable for a while); stone axe on oak 1.05 x 1.0 x 1.1 = 1.16; big pick on granite 1.05 x 1.4 x 1.3 = 1.9, clamped to 1.6, so only strong fit characters can keep going.

## How strength and fitness matter
1. **Cost reduction (everyone):** effort is divided by `1 + 0.03 x strength` (strength -10 makes work about 43 percent harder, +10 about 23 percent easier). Fitness already slows strain; it stays as is.
2. **Soft gate (bigger tools):** each tool may carry `needs_strength` (0 to 8). Below it the tool still works but effort gets +0.05 per missing point and blows land slower (work_speed x 0.9 per missing point, min 0.5). Never a hard "cannot", so no one is stuck.
3. **Hard rule stays power >= hardness** (a stone pick cannot cut granite regardless of strength).
4. **Skill:** the matching skill (Woodcutting/Mining/Digging) also lowers effort slightly (-1 percent per 5 levels) on top of fewer blows.
5. **Feedback:** inner-voice line when effort is over 1.2 ("This is too much for you yet"); the tool tooltip shows "heavy: needs strength N".

## Server load multiplier (Tyler_002)
Keep the formula above as the base cost. Apply the load multiplier last: `effort_final = clamp(base x load_mult, 0.3, 1.8)`, with load_mult = 1.0 in normal conditions rising as the signal weakens. One function `tool_effort_for(peer, tool, material)` returns the base; the multiplier wraps it.

## Needs from Dave (questions only if he wants them; recommended answers)
- Should a too-weak character be unable to use a big tool at all (hard gate) or just tire faster (soft gate)? Recommend soft gate.
- Do hardness values need to be visible to players (inspection) or discovered by trying? Recommend discovered, with a "feels very hard" hint.

## Build order when the stop lifts
Strength attribute first (job 87 follow-up), then hardness.json and size_factor, then the formula in `_wear_slot`'s work-effort line (server_items.gd), then the tooltip and inner-voice line, then tests and the balance sheet.

## Digging tool ladder (Dave 2026-10-22, later, not now)
Today the shovel digs everything in one smash, which is wanted for admin testing. Later the ladder is: spade for soil, gravel and sand only (Dave's dig-rock answer); rock needs a pick; an iron pickaxe, then a steel one, with harder material taking more swings the lower the tool tier. Fits the hardness rule above: swings needed = ceil(hardness / tool power), fewer swings for higher tiers (tiers 1 to 4 already exist in items.json). Keep the one-smash behaviour behind an admin or test setting so testing stays quick.
Queue: after the present-day jobs (tunnels, movement, water), with the hardness table.
