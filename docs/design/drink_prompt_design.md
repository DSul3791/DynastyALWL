# Drinking where the record has water the player can't see (design)

Steve, 9 Nov 2026. This is design only, for Kathleen (the HUD prompt) and Sonny (the water look). It follows drinking water steps 2a (#816) and 2b (#819).

## 1. The gap

The drink rule now knows more water than the player sees.

**What the rule knows:**
- `DrinkRules.tile_rows` gives a spring row at every ground spring head within reach.
- It gives a brook row, by regime, on every record channel sample.
- `drink_near.gd` passed on Dave's PC on 9 Nov.

**Two gates stand before the rule, and both need water the settled water grid shows:**
- **Client:** the E-to-drink prompt (`terrain_client.gd _water_ahead`) needs `flora.water_surface_at` to be at least `WaterVolume.DRINK_DEPTH_M` deep, within 2 m ahead. That is the chunk's WaterGrid from `deliver_flora`.
- **Server:** `_drink_water` first asks `water_near`, which is the baked water class with the live sim. Only after that does it ask `_drink_source_ok`, which is the rule.

So these places never offer a drink, although the rule would allow one:
- a spring head under its bushes;
- a 0.5 m brook narrower than the settled film;
- a gully in the rain.

The rule's refusals still work wherever water shows, for example "The bed is dry" on an intermittent brook in August.

## 2. Options

- **(a) A drink mask in the flora chunk, and the rule as the server's gate. Recommended.**
  - **Server:** `server_flora.water_bytes` adds a second small part to `deliver_flora`: the chunk's drink points.
    - These are the ground spring heads, and the channel samples whose row is a brook.
    - It is one byte per 8 m sample: 0 none, 1 spring, 2 to 4 brook regime.
    - Run-length coded, it is a few hundred bytes for a chunk with a stream and nothing for a dry one.
  - **Client:** `_water_ahead` is also true within 2 m of a drink point. The prompt reads "Press E to drink" as today.
  - **Server:** `_drink_water` passes when `water_near` is true or `DrinkRules.tile_rows` gives any non-salt row. The rule then decides as today: drink, "The bed is dry", "frozen" or "salt".
  - The prompt shows on a dry bed too. The server's "The bed is dry" is the answer there, the same as on a visible dry bed today.
- **(b) Make the water visible.**
  - A small pool, about 1 m across, at each ground spring head, under the bushes.
  - A thin ribbon on brook samples that runs by season.
  - This is Sonny's water look and an art pass, and it is the better world. But it is bigger, it needs the season on the client, and it would still need (a)'s server gate for the brooks the ribbon misses.
- **(c) Leave it.** A ground spring is then only a drink where the settled water happens to show. That breaks step 2a's promise ("always a drink").

## 3. Recommendation and steps

Do (a) now and keep (b) as a later art item. In order:

1. **The server gate** (`_drink_water`): rows from `tile_rows` count as water within reach.
   - No net change.
   - `test_drinking_water` gets a dry-looking spring head that gives a drink, and a dry August bed that gives "The bed is dry".
2. **The drink mask in `deliver_flora`:**
   - `terrain_net.gd` adds one field, and the protocol number goes up;
   - `flora_view` keeps the mask per chunk;
   - `_water_ahead` reads it.
   - Kathleen checks that the prompt and tooltip text are the same as for visible water.
   - `test_drinking_water` checks that a chunk with a spring head sends its point (no test covers `deliver_flora` yet).
3. **Later (b):** spring pools and brook ribbons, as Sonny's design.

**Cost:**
- No bake: the tiles already hold the drink sections.
- No TERRAIN_VERSION change.
- Step 2 changes the client protocol, so old clients must update. Dave's builds always update together.

## 4. Questions

- **For Kathleen:** should the prompt say "Press E to drink" on a spring head that the player can't see is water? Or would "Press E to drink (spring)" read better? I lean to the plain text.
- **For Sonny:** is a 1 m pool at the head right for a 5 to 10 L/s ground spring, or should its size follow the flow?
