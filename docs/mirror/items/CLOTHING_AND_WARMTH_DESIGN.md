# Clothing and warmth (job 92, design note, no code)

Nothing about cold or heat exists in play yet. The weather already gives `Weather.temp_c`, rain, snow and wind per zone, season and time of day (the server's `weather` state, row-based zones north to south), plus ice zones, so exposure can be computed from what is there.

## Body warmth
A new vital, **warmth**, 0 to 100, separate from health: 100 comfortable, falling when cold, rising by a fire or shelter. Below about 40 you shiver (stamina and exertion rise faster, fitness-scaled), below 20 hypothermia slowly costs health (never kills in the first version: health stops at 1, same rule as everything else). The same value running high covers heat in the desert zones, as "overheated", drawing water faster.

## What decides exposure (all data, server side, 1 Hz)
Heat loss per game minute = base x (comfort_temp - air_temp, never below 0) x wind factor x wetness factor x (1 - insulation).
- **Air temperature:** Weather.temp_c at the player's zone and time.
- **Wind:** exposed ridge and open ground more, forest and valleys less (the same exposure number sound already computes).
- **Wetness:** rain on you, swimming, standing in water: x1.5 to x3 while wet, drying over game minutes. A roof (Cover.at) stops rain on you; a lean-to is full cover.
- **Fire:** within 4 m of a lit campfire adds warmth and dries you; a torch in hand gives a little.
- **Shelter:** a lean-to, or a built wall, cuts the wind term.
- **Insulation (clothes):** each worn piece has `warmth` (0 to 1 share of heat kept), `wet_resist`, and a weight; slots head, body, legs, feet, hands. Summed and capped at 0.85. Heavier clothes make you hot when it is warm.
- **Ice zones:** at -10 C and below, unprotected loss is fast enough that you need real insulation and a fire; open ocean ice and cold water are the strictest places.

## Clothes (items, mostly future)
Wrapped hide cloak, hide boots, leather jerkin, wool cloak, fur hat, mittens. Early game: plant fibre skirt and grass cloak (small warmth, rot quickly). They need hides, wool, a sewing needle (job 90) and the Tailoring skill. Items get `kind: clothing`, `slot`, `warmth`, `wet_resist`, `durability` (wear from use), a body slot panel in the Tab screen, and appear on the character model (Art builds the layer rig after the ragdoll). Equipment is a new inventory section (9 slots); a protocol and save bump when built.

## What it needs when built
1. warmth vital in vitals.json (neutral default 100) and a strain-style tick in server_items.gd;
2. clothing data table and equip action (Use on a clothing item wears it; Tab shows the slots);
3. weather hooks: `temp_c` per player position (cheap: weather is per zone);
4. HUD: no bar on the main screen (Dave's rule); warmth bar only at the top of the Tab screen and the inventory, and the status icons already have room for a shiver symbol. Sound: shivering breath is Sounds' job.
Cost at Low: server one scalar per player per second; client nothing per frame.

## Card for Dave
Should cold actually hurt, or only slow you? (a) Cold only costs comfort and speed (shivering, faster exertion), never health; (b) cold slowly costs health down to 1 like hunger does; recommended (b) because it is consistent with the rest and gives clothes a real job.

## Decided by Dave (2026-10-21)
Cold costs health, slowly down to 1, like hunger. Nothing built yet.
