# Drinking water from the record: springs, brooks by season, frozen water, no salt

**Owner:** Steve, for the drink path (`_drink_water` and `water_near` in `src/stream/server_items.gd`, and the terrain server's `water_near`).
**Research:** Sonny, `docs/water/springs_and_drinking_water.md` (on the R5 branch until it merges).
**Status:** design only. The code waits until the R stack merges (R2 to R6 and the reader on #630), because it reads record fields that only exist there.
**Decided:** coordinator, 8 Nov 2026. Dave may revert.

## 1. What happens today (read from the code on main, 8 Nov, not tested)

- **The drink:** E at the water's edge (`ACT_DRINK`) gives one mouthful, `thirst.drink_ml` 300 ml. Drinks are paced 0.9 s apart, and the water must be within `reach_m` 3 m of the feet. A container in hand fills by `fill_ml` 500 instead.
- **What counts as water:** the terrain server's `water_near` says yes at:
  - a cave stream;
  - a cell the live water sim has wet;
  - or, before the sim runs, a cell whose `water_class` is over 1.
- **Not water:** the open sea (class 1, and the sim has no sea cells).
- **One kind of water.** Dave's rule of 21 Oct, in `sickness.json`, is "clean and dirty water do not exist". A salt marsh (class 10) counts as a drink today, which is a small bug.
- **No seasons and no ice.** A brook that only runs after rain can be drunk from in August if the sim still holds water there. Water that is frozen over can be drunk without breaking the ice, although fishing asks for a hole.

## 2. What the player will notice

- **Springs are always a drink:** summer, winter, drought and frost. Their water comes out at about the year's mean plus 1 °C (6.5 °C at cave 8002), so it never freezes.
- **Brooks follow their regime:**
  - a perennial brook runs all year;
  - an intermittent brook is dry in high summer unless it has rained in the last day;
  - an ephemeral gully holds water only in rain and for a few hours after.
  - In a dry August, a spring's brook runs down from the spring and stops where the record says its dry baseflow is used up. Below that point, the bed is dry.
- **Lakes and wide rivers** are a drink all year.
- **Winter ice:** lakes, still water and slow brooks far below a spring freeze on frosty nights. To drink there you break a hole first, the same hole fishing uses. A spring and the open brook just below it stay open.
- **Salt water is never a drink:** the sea and salt marsh both say "Salt water. It would only make you thirstier."
- **Wet ground** (a seep, a bog, marsh) has no open water. Phase 2 lets a dug scrape fill there.
- **Sickness:** none, by Dave's rule. The source kind is carried through, so the coordinator's pond odds (1 in 5, spring never) can plug in if Dave says yes.

## 3. The rule

A new server callable, `water_source(pos, reach_m) -> Dictionary`, is filled by the terrain server from the record reader. It returns `{}` when there is no drink, else `{"kind", "temp_c", "frozen"}`.

| kind | where (Sonny's fields) | a drink when |
|---|---|---|
| `spring` | a `springs_in(rect)` row within reach of its `pos` | always, while its dry flow (`m3_s` × `base_dry`, later per spring) is above 0 |
| `brook` | within reach of a `reaches_in(rect)` polyline, plus half its bankfull width | regime 1 always; regime 2 except in summer, or within `rain_memory_h` 24 game hours of rain; regime 3 only in rain or within `flash_memory_h` 6 game hours of it. In summer the brook is a drink only where the polyline row's `q_base_dry_m3_s` is above 0 (the walk below the spring). |
| `lake` | `water_class` 2 | always |
| `river` | `water_class` 3, once R6 item 3 writes it | always |
| `salt` | `water_class` 1 or 10 | never: say `say_salt` |
| `wet_ground` | `table_depth` 0, or classes 4 to 7 | phase 2: only from a dug scrape |

- **Order:** the cleanest source within reach wins: spring, then river, lake, brook, wet ground. This is Sonny's physical order. Salt never wins over fresh water within reach.
- **Ice:**
  - a spring is never frozen;
  - a brook is frozen at a point `x` m below its spring when the air is under 0 °C and `x` is past Sonny's open length `x₀ = λ ln((T_water − T_air)/(0 − T_air))`, with λ = ρcQ / (hW) and h = 20 W/m²K;
  - a brook with no spring upstream, or still water, follows the existing ice rule (`_on_ice`, #616).
  - Frozen water asks for `_hole_near` within reach, the fishing hole. Otherwise the player sees `say_frozen` ("The water is frozen. Break a hole in the ice first.").
- **The sim still counts.** Where the live sim has wet a cell that the record calls dry (a flood, a fresh puddle after rain), it is a `puddle` drink. This keeps today's rain puddles drinkable, and it comes last in the order.
- **Without the record** (an older world, or no `record/`), `water_source` falls back to today's `water_near`, minus salt marsh.

## 4. Data (`vitals.json` `thirst.sources`)

```
"sources": {"enabled": false, "rain_memory_h": 24, "flash_memory_h": 6, "night_h_w_m2k": 20.0,
            "say_salt": "Salt water. It would only make you thirstier.",
            "say_frozen": "The water is frozen. Break a hole in the ice first.",
            "say_dry": "The bed is dry."}
```

The flag ships off. With it off, today's `water_near` path runs unchanged, except that salt marsh stops counting. That fix is safe on its own and goes in with the code.

## 5. Phase 2 (after this)

- **A scrape in wet ground:** dig with a tool where `table_depth` is 0. A "scrape" world item fills in `scrape_fill_min` minutes (Sonny: a few) and gives `drink_ml` mouthfuls. Peat water is brown but drinkable.
- **Cold water:** drinking near 0 °C water in winter could cost a little warmth. This is judged and needs Jamie's number before code.
- **Per-spring dry flow and springs in `fresh_m`:** Sonny's additions 1 and 2. When they land, the spring row's own `q_base_dry_m3_s` replaces `m3_s × base_dry`, and nothing here changes shape.

## 6. Tests (static checks only in the cloud; run on Dave's PC)

New `test_drinking_water.gd`, with a stub record:
- **Spring:**
  - a spring row 2 m away is a drink in August and on a −10 °C night, with kind `spring`;
  - a spring's water temperature is the year mean plus 1.
- **Brook by regime:**
  - a regime 2 brook is dry in summer, wet in summer within a day of rain, and wet in autumn;
  - a regime 3 gully is wet only within 6 h of rain.
- **Brook below a spring:** in summer it is a drink above the row where `q_base_dry_m3_s` is 0 and dry below it. On a −4 °C night (Sonny's worked example, about 810 m) it is open at 500 m and frozen at 1000 m.
- **Frozen water:** with no hole the player gets the frozen line; with a hole they drink.
- **Salt:** the sea and salt marsh are refused with the salt line, even beside a lake 4 m off, and a lake 2 m off still wins.
- **Flag off:** today's drink, except salt marsh.

## 7. Questions for Dave (through the coordinator)

- Pond or still water sickness reverses his 21 Oct rule, so it stays out unless he says yes.
- Should salt water ever be drinkable in an emergency, at a cost? This design says never.
