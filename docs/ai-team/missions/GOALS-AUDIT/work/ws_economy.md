# GOALS-AUDIT workstream: reward economics (ws_economy)

**Status:** this is an audit only. It is a PROPOSAL and changes no live value. Every number below comes from `tools/economy.py` → `work/ws_economy.json`. Reproduce it with:
`python3 docs/ai-team/missions/GOALS-AUDIT/tools/economy.py . docs/ai-team/missions/GOALS-AUDIT/work` (Python 3.13.18).
**Tree:** branch `claude/project-thread-d8jals`, HEAD `7c3aed3`, baseline dev `dc2fa52`. There is no `data/` or `src/` diff between them. Inputs are `work/goals_parsed.json` (651 rows) and `work/pass2_deps.json`.
**Evidence class:** data and code were read and nothing was run, so the best class is CODE_VERIFIED. Godot, the tests and the game were not run. All play-time figures come from a model and are labelled ASSUMED where they are.

## Wage model (copper per real minute; a game day is one real hour)

| Earning route | Rate | Source / authority |
|---|---|---|
| Unskilled picking (the reference wage `W_PICK`) | 40 to 60 copper per 4 h, which is about **0.2/min (12/h)** | CREATOR rule "Dave's rule (2 Nov, replaces the 1 Nov one)", as Sal recorded it in `docs/ECONOMY_FIRST_DAY.md` lines 3-6 and the table. I have not seen Dave's original QA answer. Its pick rates are ASSUMED (`tools/economy_first_day.py` RATES: "nobody has timed them"). |
| Hob's daily wanted order | mean pay 8.43 for 35.3 units (about 6.3 min modeled), at most **once per game day, so 8.4/h** | IMPLEMENTED `data/npcs/shops.json` hob.wanted_orders |
| Ceiling on all sales to Hob (`W_HOB_CEIL`) | purse cap 300, then +100 per real hour, so **1.67/min sustained** | IMPLEMENTED shops.json hob.purse_cap / purse_regen_per_day; trade code `src/stream/server_trade.gd:397-414` |
| Species logs (axe holder) | Hob pays **26 for one oak log** and **224 for 10** (with demand fall-off, before the purse limit). 10 spruce logs pay 147. | IMPLEMENTED items.json `log_oak.value` 48, `log_spruce` 32. There is no buy_rule or sell_lot for logs. A felled tree drops its species log (`src/stream/server_items.gd:6626-6633`). See E-10. |
| Planks / hardwood boards | at most 10 and 15 copper per game day | IMPLEMENTED shops.json hob.buy_rules (3 and 2 per copper, 30 a day) |
| Fishing (trout) | 0.53 min per catch modeled, Hob pays 4, so **7.5/min in a burst**. Stock regrows at 0.2 fish/min per cell, so about 0.8/min sustained. | IMPLEMENTED `fishing.json` wait_s/window_s/cooldown_s/base_chance/regrow_s; archived target of 8-20 fish/h (`docs/mirror/design/PLAYABILITY_PREP.md:173`) |
| Value-1 goods in lots | 60 sticks → 1 copper, 30 stones → 1 copper | IMPLEMENTED items.json sell_lot; `server_trade.gd:372-391` |
| COINS.md anchors | unskilled day 30, skilled day 60; quest reward 1.5-2 × the goods' value | PROPOSAL (Radar, AI-authored, 21 Oct; `docs/mirror/items/COINS.md`). Not a Director rule. |

**Effort model (ASSUMED, a lower bound).** It counts the minutes of hands-on work for the materials a goal *consumes*. It recurses through the least-effort live recipe and adds `craft_s`. Gather minutes per unit are: Sal's RATES (stick 1/12, stone 1/6, fibre 1/10, clay/sand/soil 1/4 …); fish 0.53 (from fishing.json); logs 0.5; ore 0.5; animal parts 3; crops 0.5; thatch and water 0.1; anything else 0.25. Placing a build adds 0.5 min, and a first gather adds 1 to 5 min of search. The model leaves out prerequisite goals (stations and kept tools), walking, waiting on fires and timers, rest (energy.json: about 3 real hours of ordinary play per bar), learning and death. Real play time is UNKNOWN because nobody has timed it, and is probably several times the modeled figure. **Unit value:** items.json `value`; else the cheapest member of its group; else derived from a recipe; else 2, the convention in `src/worldgen/tools/test_economy_guard.gd:4`. 34 input ids have no value anywhere (`anomalies.valueless_inputs`). Hob pays 0 for them (`server_trade.gd:230-231`).

## Totals (copper)

| Scope | Goals | Draft | Recommended | Draft as hours of picking (0.2/min) | Draft as hours of Hob's purse refill |
|---|---|---|---|---|---|
| Full catalog | 651 | **15670** | **3056** | 1305.8 | 156.7 |
| Main route | 118 | 2826 | 1304 | 235.5 | 28.3 |
| Additional | 533 | 12844 | 1752 | — | — |

The modeled catalog work is 5349 min, or about 89 h as a lower bound. Over that time picking pays 1070 and Hob can pay at most 8915.
- Draft = **14.6×** the picking wage and **1.76×** the most Hob could ever pay.
- Recommended = 2.9× the picking wage and 0.34× Hob's ceiling.
- Main route: draft 17.7× and recommended 8.2× the picking wage for the modeled 797 min.

By dependency level (draft → recommended): main 2826→1304; L1 50→40; L2 177→111; L3 70→47; L4 247→117; L5 578→180; L6 489→181; L7 297→117; L8 385→86; L9 226→83; L12 50→41; L13 705→178; L14 1520→297; **L15 4890→179; L16 1480→54; L17 1680→41**. The by_section totals in the JSON are identical, because each section is one level.

## Milestones on the main route (cumulative copper)

| Milestone (main #) | Draft | Recommended | Live legacy coin in it | Modeled work (min) | Picking wage for that work | Draft ÷ wage |
|---|---|---|---|---|---|---|
| First 10 goals | 36 | 32 | — | 10.5 | 2.1 | — |
| First shelter `shelter` (#25) | 106 | 92 | 29 | 31.0 | 6.2 | 17.1× |
| First workbench (#27) | 124 | 110 | 47 | 37.9 | 7.6 | 16.4× |
| First modeled hour, `build:thatch_roof_65` (#33) | 166 | 142 | 47 | 66.4 | 13.3 | 12.5× |
| Enough to buy one of every Hob stock item (198) | #38 campfire pot (200) | #42 clay hearth (215) | | | | |
| First metal `craft:iron_ingot` (#59) | 409 | 362 | 47 | 157.9 | 31.6 | 12.9× |
| First steel `craft:steel_ingot` (#101) | 1546 | 1009 | 47 | 440.6 | 88.1 | 17.5× |
| First Fortified piece `build:fortified_foundation` (#114) | 2426 | 1257 | 47 | 649.5 | 129.9 | 18.7× |
| End of route `build:fortified_gate` (#118) | 2826 | 1304 | 47 | 797.3 | 159.5 | 17.7× |

## Findings

**E-01 HIGH: the catalog payout exceeds everything ordinary play can earn.**
- Goals affected: all 651.
- The draft pays 15670 copper. That is 1306 h of Dave's picking wage, or 157 real hours of Hob's whole purse refill. It is 1.76× the most all sales to Hob could pay over the modeled time to finish the catalog.
- Goal coin is minted by `add_coins(peer, …, "goal")` (`src/stream/server_items.gd:15771-15772`). It bypasses Hob's purse, which is the only income throttle (`ECONOMY_FIRST_DAY.md` "Hob's purse is a second ceiling").
- Once goals pay more than the purse can, selling to Hob stops mattering as income. Picking at 12/h becomes noise next to one 60-copper decoration goal, which is worth 5 hours of picking.
- Recommendation: about 3056 in total (main 1304), using the bands below. No goal is removed. **Dave decides.**

**E-02 HIGH: rewards follow dependency depth, not content or effort.**
- Additional route: Spearman correlation of reward with dependency level is **0.886**; with modeled effort it is **0.319**.
- Each level is in effect one flat price:
  - L15: 79 of 84 goals pay 60.
  - L16: 16 of 21 pay 80.
  - L17: all 14 pay 120.
  - L13: 39 of 45 pay 15.
  - L14: 34 pay 20 and 19 pay 40.
- Examples of the result:
  - `build:crude_chair`, `crude_table`, `bench` and `stool` pay **80 each**, for inputs worth 11-48 and 0.8-1.7 min of work. That is twice the Smithy (40).
  - `build:handcart` pays 120.
  - `build:engineered_pillar` (5 concrete) pays 120, the same as `build:engineered_foundation`.
- Recommendation: price by goal class (bands table) plus a small effort top-up.

**E-03 HIGH: separate coins for every variation make up most of the catalog.** Draft totals (recommended in brackets):

| Group | Goals | Draft (recommended) | Share of the draft |
|---|---|---|---|
| Furniture, storage, decor, water and garden placeables | 109 | 4827 (259) | 30.8% |
| Building pieces | 90 | 4275 (357) | 27.3% |
| …of which non-lead variants | 69 | 3081 (166) | |
| Engineered and Fortified pieces at 120 | 19 | 2280 (129) | 14.6% |
| Doors (all 28 configurations) | 28 | 1388 (175) | |
| …of which arched, double and double-arched shape variants | 21 | 1041 (103) | |
| Metal equipment | 83 | 1480 (467) | |
| …of which off-route | 73 | 1315 (340) | |
| Food dishes | 91 | 685 (212) | |
| Clothing | 45 | 408 (134) | |

- These classes hold 12898 of the 15670 copper (82%), and most of their goals are variants of a family that has already been taught.
- Recommendation (grouping without removing any goal): the **first goal completed in each family pays that family's band**. Later members pay a variant rate of 1-2, plus an effort top-up.
  - Families are door shape × tier, building piece tier and function, cook station, metal tier, clothing material and placeable category.
  - Pay the lead to *whichever* member completes first. This fits the draft's rule that any valid out-of-order completion earns the goal (draft, "What each goal must teach").
  - This needs a `family` id per goal in the future goal data (UI/runtime workstreams).

**E-04 HIGH: station rewards are not monotone.**

| Station | Draft | Recommended |
|---|---|---|
| Stone workbench | **120** | 41 |
| Mixer | **120** | 40 |
| Sawmill | 240 | 82 |
| Smithy | 40 | 41 |
| Blast furnace | **40** | 80 |
| Master smithy | 80 | 86 |
| Smelter | 10 | 20 |
| Stone forge | 10 | 20 |
| Fireplace cooking crane (an add-on) | 80 | 20 |

- The blast furnace takes 31 min of modeled work and 408 of inputs. The stone workbench takes 14.9 min and 132, yet pays 3× as much.
- In the draft the Smelter (opens metal) pays 10, the same as the Preserving jar. The Stone forge (opens bronze) also pays 10.
- The Fireplace cooking crane is an add-on that pays 80, the same as the Master smithy.
- Recommendation: station bands of 10, 20, 40 and 80 by tier. Stations that open an era (smelter, stone forge, stone workbench, mixer, sawmill, blast furnace, master smithy) get at least their era's band. Add-ons get half the band.

**E-05 MEDIUM: tier-entry materials are inverted.**

| Goal | Draft | Recommended |
|---|---|---|
| `craft:wooden_pin` (1 plank → 20 pins, 0.2 min) | **30** | 4 |
| `craft:iron_ingot` (the first metal) | **7** | 15 |
| `craft:concrete` | 40 | 15 |
| `craft:steel_ingot` | 15 | 25 |
| Plank / Hardwood board | 20 | 8 |
| Nails, hinges, iron band | 15 | 7 |

Recommendation: the milestone list in the bands table below.

**E-06 MEDIUM: early-game cash shock.**
- By main goal #38 (Campfire pot), the draft has paid 200. That buys one of every item Hob sells (198 at stranger prices, `totals.hob_stock_prices`).
- By the first workbench the draft has paid 124. Dave's legacy goals paid 47 by then, and the modeled 38 minutes of work are worth 7.6 at the picking wage.
- Later payouts have no coin sink. Hob stocks only 15 primitive items; repairs and lessons are the only other sinks.
- The draft's single Sawmill reward (240) is worth more than Hob's whole shelf.
- The recommended first hour (142) is still about 3 four-hour picking days (48 each), mostly from teaching goals.
- **Dave decision:** should the first-hour coin be about one picking day? Then the new early goals would pay 1-2 each. His own legacy goals already pay 47 by the workbench.

**E-07 MEDIUM: rewards above the market value of the outputs.**
- 110 goals pay more than Hob would give for what they make. Examples (draft reward vs Hob's payment for the output):

| Goal | Draft reward | Hob pays for the output |
|---|---|---|
| `craft:concrete` | 40 | 6 |
| `craft:wooden_pin` | 30 | 1 |
| `craft:lumber` | 20 | 2 (buy_rule) |
| `craft:hardwood_board` | 20 | 2 |
| `craft:axle` | 40 | 16 |
| `craft:wooden_cart_wheel` | 40 | 13 |
| `craft:carved_stone_shingle` | 20 | 1 |
| `winter_store` (legacy) | 30 | 9 |

- These cannot be farmed: goals pay once per character (`goals_done`, `server_items.gd:15766`). They are one-off cash shocks; see E-06.

**E-08 LOW (catalog review): rewards below input value are expected, but the extremes show cost problems.**
- 478 of 651 goals pay less than the market value of their inputs. That is normal, because the player keeps the output.
- **Catalog problems for Dave's review** (catalog freeze, so no data edit is proposed):
  - The Crude door costs **50 sticks + 100 twine**, which is 300 fibre: 350 copper of value and about 38 min of modeled work.
  - The Crude double doors cost 700 copper of inputs and about 76 min, against a Rustic door's 5 planks (40). Crude doors cost far more than higher tiers.
  - The Fortified door costs 10 iron + 10 steel ingots (900). Its double version costs 1800 and about 191 min, for a 40-copper reward.
- With the effort top-up the recommendation pays 10 for a crude double door and 20 for a fortified double door. They should still be repriced in the catalog.

**E-09 MEDIUM (Dave's decision): the legacy goals differ from the live data.**
- 25 of 28 are identical (live total 201 coin, draft 211). The three that differ:

| Goal | Live reward | Draft |
|---|---|---|
| `twine` | 4 sticks (`starter_goals.json` goals[twine].reward.item). Value 4, but Hob pays 0 for them (lot of 60). | 4 copper |
| `fell` | 3 kindling (reward.item). Kindling has no value in the data (gathered.json, derived ≈1), so Hob pays 0. | **6 copper**: twice `hammer`/`hoe` and more than `fire` (5) |
| `story` | 3 copper + 1 rep (`camp_goals.json` reward.rep) | 3 copper; the rep is dropped |

- The creator rule "monetary goal rewards only" points to converting twine and fell to coins. Dave's standing ruling keeps legacy rewards as they are; **he decides**.
- If he converts them, I recommend twine 4 and fell 3 (the item value, with the floor of 3 that the other first-hour goals use).
- The live `_about` notes say "read by nothing yet", but the code reads both files (`server_items.gd:15635-15637`), so the notes are stale.

**E-10 MEDIUM (economy context for catalog review): ordinary income for anyone with an axe is the purse cap, not 0.2/min.**
- Species logs are worth 24-48. Hob buys them at value × 0.55 with no lot or daily rule.
- One oak tree (about 5 logs) sells for about 120. Ten oak logs pay 224, which almost empties a full purse (300).
- `ECONOMY_FIRST_DAY.md`'s lumber note assumed Log = 4. Dave's "poor wage" target therefore holds only for picking.
- The comparisons above use both the picking wage and Hob's ceiling.
- Recommendation for Dave's catalog/economy review: a `buy_rules` entry or `sell_lot` for species logs. Report only; no data edit.

**E-11 LOW: the bonfire pays twice the medium fire.**
- `activity:bonfire` pays 10 and the medium fire 5. The extra is 3 logs (about 2 min).
- Recommendation: 5.

**E-12 LOW (data note): charcoal's value is fractional.**
- `charcoal.value` is 0.15, a float. The trade code rounds it to 0 (`int(round(...))`), so Hob pays nothing (`server_trade.gd:371`).
- `DYNASTY_MASTER_ITEMS.md:1049` says "value (today 3…)".
- This makes the fuel cost of every ingot about 0 in this model. Report only.

**E-13 LOW (document): two section headings have stale counts.**
- The draft headings say L2 has 36 goals and L4 has 37. The rows number 35 and 36, apparently after the hammer/hoe merge.

## Recommended reward bands (copper; `economy.py` constants)

| Goal class | Lead (first of the family) | Variant | Notes |
|---|---|---|---|
| Legacy (28) | live value | — | Dave's standing ruling. Twine and fell are items today. |
| First gather of a raw material | 3 (5 for ores, limestone, flint, pine tar, tannin bark, hide, fat, wool, flax) | — | 3 copper = 15 min of picking wage |
| Teaching action (place, chop, fire size) | ≤ 5 | — | |
| Station, tier 1 / 2 / 3 / 4 | 10 / 20 / 40 / 80 | — | Era openers: smelter and stone forge ≥ 20; stone workbench and mixer ≥ 40; sawmill, blast furnace and master smithy 80 |
| Station add-on | half the tier band | — | |
| Tier-entry material | iron ingot 15, steel 25, bronze 10, copper/tin 5, concrete 15, plank/board 8, leather 8, charcoal 5, brick 4 | — | |
| Other intermediate material, by material tier 1-5 | 3 / 4 / 5 / 7 / 10 | — | |
| Building piece, tier lead: Crude / Rustic / Sturdy / Superior / Refined / Engineered / Fortified | 7 / 7 / 10 / 12 / 15 / 25 / 40 | 2 | 4 for the first piece of a new function; main route never below 5 |
| Door, plain door of a tier | half that tier's piece band (min 3; 5 on the main route) | 1 | 3 for the first arched, double or double-arched door anywhere |
| Metal tools, weapons, armour (bronze / iron / steel) | 10 / 12 / 15 on the main route | 3 / 3 / 4 | Off-route working tools (axe, spade, sickle…) pay 5 |
| Primitive equipment | 3 | 2 | |
| Food: first dish at each cook station | 5 | 2 | |
| Clothing, containers, medicine, placeables (first per family) | 3 / 5 / 8 / 10 / 12 by material tier | 2 | |
| **Every non-legacy goal** | + floor(effort_min × 0.2 × 0.5) | | Pays half the picking wage for the modeled work. Rewards then rise with work inside a class and never replace wage income. |

**Why these bands:**
- A goal coin should mark novelty and guidance, not pay for repeated labour. Ordinary play (picking, trade and Hob's orders) pays for labour.
- The bands keep the main route at about 13 h of Hob's purse ceiling, and the catalog at a third of what Hob could pay over the modeled time.
- Monotonicity in the recommendation: Spearman with effort is 0.366 (the draft's is 0.405 overall). Leads deliberately pay more than equal-effort variants, which accounts for the remaining same-class inversions (`anomalies.recommended_not_monotone_count` 565, against 1063 in the draft).

## Verified / not verified
- **Verified (CODE_VERIFIED, by reading):**
  - Live legacy rewards and their payout path.
  - Hob's trade formula, purse, lots and buy rules.
  - Item values and recipes.
  - The species-log drop.
  - That goals pay once.
- **Not verified:**
  - Any real gathering pace or play time; every pick rate is ASSUMED.
  - Fish stock behaviour over time.
  - Whether other traders exist in play: only Hob is in shops.json, and `shops_proposal.json` is a proposal.
  - Real play time to reach each milestone (UNKNOWN; it needs playtest timing).
  - Repair and lesson sinks were not quantified.
- No game, test or Godot run.
