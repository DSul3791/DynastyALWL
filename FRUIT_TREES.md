# Fruit trees: item and calendar data (Sal, 2026-10-31, for Dave's request)

## Items added (431 to 449, all `future` until the flora session gives each tree a harvest)
Apples: early summer (July, days), summer (August, a week), autumn (Sept and Oct, three weeks), keeping (picked Oct and Nov, lasts until spring), cooking (Aug to Oct, a month); the cider/crab apple already exists (`crab_apples`, tree `wild_apple`). Pears: summer, autumn, winter (keeps to February). Sour cherries (the existing `cherries` are the sweet ones), plums, damsons, quince, medlar, figs, olives, pomegranates, mangoes, oranges, lemons. Each has weight, stack 20, a value, calories (vitals.json), shelf life in game hours (spoilage.json: early apple 72, summer 168, autumn 480, keeping 2160, cooking 720; pears 96, 360, 1440; plums 96, damsons 120, quince 1200, medlar 240, figs 72, olives 720, pomegranates 1200, mangoes 96, oranges 480, lemons 720) and a description with the taste. Hydration, warmth and vitamin values are not in the vitals data (food has only calories), so none were invented.

## Dishes added (at most 3 ingredients)
Dried apples and dried figs (campfire, 3 fruit give 3, last 40 days), apple sauce (pot), apple pie (oven, needs flour), plum jam, stewed pears, preserved damsons (pot, sweet nectar stands in for honey, which does not exist), quince paste. Cider press: not added (a future structure).

## Calendar
`data/items/seasons.json` has `fruit_and_nuts` (31 entries with months, how long it keeps, whether the tree exists, biomes) and `fruit_hints` (6 winter-planning lines such as "Keeping apples last until spring in a cool store."). Months follow the table calendar (day 0 = 1 March; a year is 365 real hours).

## What the flora session must build
Trees that exist in flora.json today: wild_apple (crab apples), wild_pear, wild_cherry, rowan, sea_buckthorn, hazel, sweet_chestnut, walnut, date_palm, wild_banana, coconut_palm. Trees still to add (each yields the item of the same name, picked a pack at a time with the weight limit): apple early, summer, autumn, keeping and cooking varieties (temperate biomes), summer/autumn/winter pear, sour cherry, plum, damson, quince, medlar (temperate), fig, olive, pomegranate (dry_scrub, savanna, hot_desert), mango (tropical_forest), orange and lemon (dry_scrub, savanna: a subtropical stand; the biome table has no Mediterranean biome, so I used these two). None was skipped. Horticulture facts (ripening months, keeping times) are general knowledge, not individually sourced.

## Looks
All 19 fruit and 8 dishes are listed in data/items/look_placeholders.json and data/items/look_wishlist.md (one apple model with colour tints).
