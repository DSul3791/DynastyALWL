# Food spoilage (job 91, design note, no code)

Food rots (Dave's rule for a living world). Today food never changes. This is what spoilage needs from Items; the creature and hunting work depends on it (HUNTING_PREREQUISITES.md, point 4).

## The rule
Every perishable item has a **freshness** from 100 (fresh) down to 0 (rotten). It falls at a rate per game hour that depends on the item, how it was prepared, and where it is kept. Rotten food cannot be eaten safely (it makes you sick: a health cost and wet/food penalty, no death); at 0 it turns into a "rotten" item that can be dropped, composted or burnt.

| Item class | Fresh lasts (open air, mild day) | Notes |
|---|---|---|
| Berries, greens, mushrooms | 1 to 2 game days | the quickest |
| Fruit, roots, nuts, seeds | 6 to 30 game days | nuts and seeds keep longest |
| Raw meat and fish | 1 game day | much shorter in heat |
| Cooked meat (roast) | 3 game days | |
| Dried, smoked or salted | 30+ game days | needs the drying rack or smoke fire (later) |
| Grain, flour | 60+ game days | wet ruins it |

A game day is one real hour, so "1 game day" is an hour of play: the pressure is real but not frantic. All numbers are data (data/items/spoilage.json), per item id or suffix like food kcal.

## What changes the rate (multipliers)
- **Where it lies:** in the pack 1.0; in a woven chest 0.8, plank chest 0.6 (air gets in); in a cool place (cellar, ice, later) 0.2; on the ground 1.5.
- **Weather and season:** the rate scales with Weather.temp_c: x0.5 near freezing, x1 at 15 C, x2 at 30 C; frozen is x0.1. Rain and damp add x1.3.
- **Preparation:** cooking roughly triples the shelf life of meat; drying and smoking multiply it by 10 (later).

## How it is stored (the one real change)
Items in a stack need a birth time. Proposal: a **freshness byte per slot** next to `wear` (the same trick containers use), so a stack is all one age; stacks of different ages never merge, and picking up merges only when ages are within 5 points (averaged). On the server it is a per-slot float updated lazily: store the game time the stack spoils at, compute freshness when needed (on eat, on tooltip, on a 60 s tick). No per-frame cost. World items and chest slots carry it the same way. Saves: inventories.json gets one more number per slot (version bump, neutral default 100 for old saves). Protocol: slot rows gain one byte; PROTOCOL.md entry when built. Cost at Low: negligible server work; the client shows a coloured freshness bar on the slot and a word in the tooltip ("fresh", "going off", "rotten").

## Weight loss
Drying and rotting lose water: a rotting item loses up to 30 percent of its weight as it goes; dried food weighs a third. The weights data gets a `dry_ratio` per food. (Optional, later.)

## Ties
- Hunger: stale food gives fewer kcal (freshness 50 gives 75 percent), rotten gives none and costs health.
- Luck: a rotten-food sickness chance goes through the luck function.
- Skills: a future Cooking or Preserving skill lowers the rate.

## Card for Dave
Should spoilage start strict or gentle? Strict (berries gone in an hour of play, forces fast eating and drying) or gentle (everything lasts 3 to 5 times longer; spoilage is a nuisance for a first release)? Recommended: gentle.

## Decided by Dave (2026-10-21)
Gentle: spoilage lasts 3 to 5 times longer than the strict table above. Nothing built yet.
