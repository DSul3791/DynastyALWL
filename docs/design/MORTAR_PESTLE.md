# Mortar and pestle: what it is and how the game should use it

Status: AGREED. Dave, 18 Nov 2026 10:12Z: "Mortar and Pestle I agree with your assessment." Built with the assumed answers MP-1..MP-5 (section 4).

Asked by Dave, 17 Nov 2026: "when I made a morter and pestle I expected a stone bowl with a pestle in it. but instead it made me type of hammer tool" and "the mortar and pestle is a work station for making stuff from plants and such. you use it to grind things. do some research into it and give me a report on how you think we should use it."

## 1. What a mortar and pestle is

- The **mortar** is a heavy bowl, usually stone (granite, basalt, marble), sometimes hardwood or bronze. Medieval kitchen and apothecary mortars were big and heavy, often 5 to 30 kg, and sat on a table, a bench or the floor. Large ones stood on a wooden block or stump.
- The **pestle** is a short, blunt, club-shaped grinder of stone or hardwood, held in the fist, that rests in the bowl when not in use.
- It is worked by pounding and twisting the pestle against the bowl. It handles small batches and fine work: you grind a handful, not a sack.
- Medieval uses: herbs into pastes and poultices for medicine; dried herbs and roots into powders; spices, salt and seeds (mustard, pepper, coriander) for cooking; nuts and garlic into pastes and sauces; pigments (charcoal, ochre, berries, plants) for paint and dye; small amounts of grain into coarse meal before or alongside a quern.
- Bulk grain was the quern's (hand mill's) job: two millstones, much faster for flour. The mortar was for everything small, fine or wet.

## 2. What the game has now (dev 40f36037)

- Item #807 `mortar_pestle`, "Mortar and pestle", kind `tool`, tool_class `mortar_pestle`, 1.5 kg, durability 2000, value 6. Recipe #377: 2 stone, 8 s, hand craft.
- It is kept (not used up) by four medicine recipes: Plantain poultice #8, Comfrey poultice #9, Leaf bandage #10, Herb antidote #378. It counts anywhere in the pack or on the hotbar (`RULINGS.md` R-CRAFT-KEPT-TOOL).
- **Why it looks like a hammer (a plain bug):** it has no model of its own. In hand, `held_item.gd` `_make_other_model()` gives every tool without a model a 0.6 m rod with a grey block on the end, which reads as a hammer, and a left click plays the generic "use" arm swing. On the ground it is a plain grey stone chunk (looks.json shape `chunk`). Its inventory icon already shows a bowl with a pestle. It does **not** act as a hammer: the build screen and hammering check tool_class `hammer`, which it does not have.
- **Hand mill** #344 (`quern`): since #1218 a placed station (two millstones on a stone base). Makes flour from wheat, barley, oats, rye and wild grain, and Bonemeal from bones.
- **Food preparation table**: mixes and shapes uncooked dishes (dough, pies, batters). No grinding.
- **Apothecary cabinet** #1229: storage for herbs and remedies only.
- Herb salve (comfrey + animal fat) is a hand recipe with no station and no tool.
- The world has a wide herb list (plantain, comfrey, chamomile, yarrow, mint, sage, valerian, feverfew, arnica, St John's wort, willow bark, many magical herbs) and every tree and herb has a seed. Most of these herbs are not used by any recipe yet.

## 3. Recommendation

1. **Make it a small placed station**, as Dave described. Crafted by hand from stone as now (recipe #377 unchanged), then placed like the Hand mill: a heavy stone bowl with the pestle resting in it, about 35 cm across, sitting on the ground, a floor, a table or a stump. Press E to open its window, which lists only its recipes (the station window from #1208) with its own small store (#1212). It is no longer held, so no hand model and no swing are needed. It keeps its item id, name, number and cost.
2. **It is the "grind small things" station; the Hand mill is the "grind grain in bulk" station.** Mortar: herbs, medicine, spices, seeds, nuts, pigments, small batches. Hand mill: flour and bonemeal. Food preparation table: mixing and shaping food from what the mortar and mill make.
3. **Progression: the very first station**, stone age, before the Hand mill. It is the player's first medicine station, which fits the four early medicine recipes it already serves.
4. **Recipes, first step (no new items):** the four medicine recipes it already keeps move onto it (they stop needing it in hand), and Herb salve moves onto it too.
5. **Later, with the item list (new items, so Dave's call when he gets to medicine, spices and dyes):** dried herb powders for teas and remedies, ground spices and seasoning, nut and garlic pastes, pigments and dyes from charcoal, berries and plants, and a slow small-batch Wild grain meal so a player without a Hand mill can still make a little flour. The many unused herbs in the world are the natural input.

## 4. What was built (18 Nov 2026)

- Item #807 is kind `placeable` (no tool class, durability or repair); number, name, recipe #377 (2 Stone, 8 s, by hand) and value unchanged. Structure `mortar_pestle`, state 456, 0.4 x 0.4 m, station `mortar_pestle`, reach 3 m.
- Plantain poultice #8, Comfrey poultice #9, Leaf bandage #10, Herb antidote #378 and Herb salve #198 name `"station": "mortar_pestle"`; none keeps it in hand.
- Look: one stone bowl and pestle mesh (basic_look.gd shape `mortar`) on the ground, in the hand (70 percent) and placed (piece_look.gd `mortar_pestle`). The existing icon already shows a bowl and pestle and was not rebaked.
- Not run in Godot (Dave's token rule); never seen in a picture.

## For Dave

Questions, each with the answer we would assume (provisional, MP-n) if he does not say otherwise.

- **MP-1** Placed station or carried tool? *Assumed: placed station, crafted by hand and placed like the Hand mill.*
- **MP-2** Which recipes move onto it now? *Assumed: Plantain poultice, Comfrey poultice, Leaf bandage, Herb antidote and Herb salve. Nothing new until the item list reaches medicine, spices and dyes.*
- **MP-3** Cost stays 2 stone, 8 s, hand craft? *Assumed: yes (catalog frozen).*
- **MP-4** Where can it be set down? *Assumed: anywhere a station can go (ground, floors, ceilings, under the PlacementRules from #1216).*
- **MP-5** Look: grey stone bowl about 35 cm across with a short stone pestle resting in it, ground and icon to match. *Assumed: stone pestle, not wood.*
