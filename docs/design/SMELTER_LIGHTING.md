# Smelters light like a campfire

Dave, 17 Nov 2026 (project thread "Make smelter work like campfire"), playing the Primitive smelter on `dev`: "the smelter just say press e or f for its fuel or ore. it should say Press E to light. thats it. if I press f it should open the inventory just like the campfire. and when Its lit it should smelt the ore into ingots. also when I placed it the blue print already had fire in it. and when I built it even though it wasnt lit it still had fire. it needs to show no fire when its not lit. it should work similar to a campfire."

## What changed (every smelter tier: Primitive, Improved, Advanced)
- **Lit or cold.** A smelter has the placed row's `lit` flag, as the Kiln and the lights do. It smelts only while lit; cold, nothing moves and a half-done ingot keeps its time (`server_smelter.tick`). Before this a smelter smelted by itself whenever its hopper had fuel and its input had ore, with no step to start it.
- **E lights it, E puts it out** (`server_smelter.use`). E on a cold smelter lights it when its fuel slot holds Coal or Charcoal; with no fuel it stays cold and says "Put Coal or Charcoal in its fuel slot first (F)." E on a lit one puts it out, and what is in it stays.
- **It goes out by itself** when its fuel slot is empty: the last fuel burnt, or taken out. Fuel put in later does not light it again; E does.
- **F opens its store**, as it did (`open_container`): the fuel slot, the ore slots and, on the Improved and Advanced, the ingot rack.
- **The look-at line** says "Press E to light" while cold, and nothing else. While lit: "Press E to put out" (the campfire's words). The Improved smelter, lit: "Press E to work the bellows, E again to stop (hold E to put it out)".
- **Fire only while lit.** The smelter models' flames and smoke show only while it is lit: never on the blueprint ghost, the blueprint site or a cold smelter (`inventory_view._smelter_fire`, `BuildingLook.show_forge_fire`). A lit smelter's fire light joins the nearest-lights list like any fire.
- **Saved.** smelters.json gains a `lit` list of the lit smelters' store uids; a restart keeps them lit. No protocol change: `lit` already travels on the placed row.
- **The store's words** read "Fuel (slot 1): Coal or Charcoal, up to 20. Ore (slots 2 to 3): up to 20. The ingots drop in front of it. Press E beside it to light it." (was "Slot 1: fuel, Coal or Charcoal (20) ..."). The Primitive smelter's description now reads "Fed Coal or Charcoal and ore and lit, it smelts copper, tin and bronze." (was "... by itself").

## Why it may not have smelted for Dave
Before this change the server smelted with no lighting at all whenever Coal or Charcoal sat in the fuel slot and ore in the ore slots (`test_smelters` covers it). So the likely causes were: no Coal or Charcoal in the fuel slot (firewood and wood are not smelter fuel), or, on builds before PR #1199 (16 Nov 2026), the old 64-items-within-12 m ground limit refusing the ingot drop, which made the finished ingot wait. Not confirmed on his save, which was not looked at.

## Saves from before this change
smelters.json from before has no `lit` list, so every smelter loads cold, one half way through an ingot too: its time is kept and E lights it again.

## Not changed
- The Primitive smithy shares the Primitive smelter's model and the Master smithy the Advanced smelter's; both keep their fire as before. Showing the smithies' fire only while fired is a separate change.
- Fuel burnt: still one Coal or Charcoal a unit of ore, when the ingot is delivered (A-10). The every-300 s fuel pull from stores within 30 m (A-33) still fills a smelter's hopper, lit or cold.
- No fire sound for a lit smelter (the smithies have none either).

## For Dave (assumed on his behalf, provisional)
- SL-1: lit, it burns fuel only as it makes ingots (one a unit of ore, as before); a lit smelter with no ore burns nothing and stays lit.
- SL-2: it goes out when its fuel slot is empty, as a campfire goes out when its wood is gone; fuel added later (by hand or by the 300 s pull) needs E again.
- SL-3: lit, the Primitive and Advanced smelters say "Press E to put out"; the lit Improved smelter keeps E for its bellows and puts out with hold E.
- SL-4: the cold prompt is only "Press E to light", as asked: hold E still takes a cold smelter down (as before, now unsaid); F still opens it.
- SL-5: E with no fuel does not light it and says to put Coal or Charcoal in its fuel slot.
- SL-6: the look-at line offers no take-down while a smelter is lit, as with a burning campfire (put it out first).
- SL-8: a lit smelter whose fuel slot holds less than its next job needs (1 Charcoal for a Bronze pair, which takes 2) stays lit and waits for more fuel; it goes out only when the fuel slot is empty.
- SL-7: the Advanced smelter still needs the wind as well as being lit; lighting it in a calm says the windmill waits.

## Primitive smithy: no fire in a blueprint, a stone anvil (Dave 17 Nov 2026)

Dave: "it currently has a fire in the blueprint that is burning before you make it and it needs a stone anvil so basically a flat topped carved rough stone beside it for hammering on materials".

- No blueprint burns: `inventory_view._model_for_state` puts out the flames and smoke of every forge, smithy and smelter look (the `Flames` and `ForgeSmoke` hooks) for a placement ghost (`ghost_model`) or a site waiting for materials. Checked: kilns, the Grill, Cooking pot, Griddle, fireplace and campfires draw no flames when not lit (a ghost is drawn in one ghost colour, so their painted embers do not read as fire). Fire stations have no fire sound outside the campfire states.
- The Primitive smithy's model (Dave's `forge_basic.glb`, shared with the Primitive smelter) gets a rough stone anvil beside the fire: `BuildingLook.add_stone_anvil`, with its own solid. Not a catalog item, recipe or separate placeable; the cost is unchanged. The smelters that share the model have no anvil.

For Dave (assumed on his behalf, provisional):
- PS-1: the anvil is three uneven stone courses narrowing to a dressed flat top about 34 by 29 cm, 0.6 m up.
- PS-2: it stands to one side of the fire (the model's +x side; not yet seen in a picture), the forge moved 0.25 m the other way; the footprint grows from 0.9 to 1.6 m wide to hold both (1.4 at first; Lane A measured the forge with its anvil at x -0.79 to 0.73, 1.52 m, so 18 Nov 2026 it became 1.6; the look is unchanged).
- PS-3, PS-4: superseded by the smithy fuel slot below (Dave 21 Nov 2026).

## Smithies: a fuel slot, no lighting (Dave 21 Nov 2026)

Dave: "smithys should just take coal in a fuel slot. same for all smithys. dont need to be lit. they should have red coals when idle and flare really bright while making stuff." (He had found the Primitive smithy needed no fuel while the Improved one burned charcoal from his pack.) He also confirmed the stone anvil's side: "the anvil on the side looks fine".

- All four smithies (Primitive, Improved, Advanced, Master) have `"fuel_slot": "fuel"` in structures.json. The first slot of the smithy's store is its fuel slot. Coal or Charcoal put in goes there first, anything else never goes there (a drag of anything else onto it is refused), and a product never lands there.
- A smithy works only with fuel in that slot. It is never lit, and E does nothing new. The old `craft_needs_lit` firing from the pack or from a nearby bin, kiln or unlit fire (A-28 for smithies) is deleted.
- Fuel burns only while a craft is worked there: one unit gives `fuel_craft_s` seconds of making, and the next unit is taken from the slot when that runs out. An idle smithy burns nothing.
- The look follows the row's `forge`: 0 cold (no fuel), 1 red coals (fuel in, idle, a dim red glow, no flame or smoke), 2 the flare (a craft worked there: tall flames, smoke and a bright light). `BuildingLook.forge_state`.

For Dave (assumed on his behalf, provisional):
- SF-1: Charcoal counts as well as Coal, the same "fuel" group the smelters burn.
- SF-2: one Coal or Charcoal lasts 1800 s (30 minutes) of making, the old firing time.
- SF-3: the fuel slot holds one stack. More Coal put in is kept in the rest of the store but not burnt until it is moved into the fuel slot.
- SF-4: idle coals glow at 0.45 energy over 3.5 m; the flare is 3.2 energy over 12 m.
- SF-5: a smithy goes back to idle coals 1.5 s after the last craft worked there.
- shortcut: the part-burnt unit (fuel_left) is not saved, so a restart loses under one unit's making time.
