# First-island town and NPC data spec (Sal, 2026-10-31)

Fits data/npcs/*.json (npcs.json, shops.json, markers.json, reputation.json, dialogue/) and ECONOMY_PLAN.md. Spec only; dialogue writing belongs to Mandy and Dave's taste for names.

## What exists
Two NPCs near the spawn (x 53301, z 68427): **Hob**, shopkeeper (sleeps 21 to 6, works 7 to 18, eats twice) with a stall (shops.json) and **Edda**, guard (works nights, sleeps in the morning). Markers: two beds and two chairs. Reputation ranks: Stranger, Known, Friend, Trusted. Shops buy at 55 percent of value and sell at 130 percent.

## Proposed roster (7 NPCs; names are placeholders for Dave)
| NPC | Role | Sells | Buys | Wants (quest hooks) | Needs in data |
|---|---|---|---|---|---|
| Hob | shopkeeper (exists) | tools, twine, fibre, torch, bandage | most things | sticks, stones, fibre (restock) | already in shops.json |
| Edda | guard (exists) | none | none | wolf pelts or a wolf kill, torches for the night watch | quest dialogue |
| Marra | healer | bandage, herb salve, splint, teas | herbs, roots, comfrey, plantain, mushrooms | yarrow, willow bark, aloe | shop entry, dialogue, bed and post markers |
| Tam | hunter | bow, arrows, quiver, spear | hide, feathers, sinew, bone, antler, claw, raw meat | wolf and boar kills, feathers | shop entry, outfit, post marker |
| Bran | fisher | fishing rod, shore net, bone arrows, sea salt | fish, shellfish, seaweed, eggs, crab meat | salmon in autumn | shop entry; shore foods need WATER_GATHER_SPEC.md |
| Wyn | smith (appears when a forge stands) | iron tools, nails, hinges | ingots, ore, coal | ore delivery | later; needs ore code |
| Gil | farmer | seeds, flour, bread | grain, vegetables, straw | straw, compost, a hoe repaired | needs farming code |

## Town layout hooks (markers.json kinds)
Add a table marker (NPC eating package exists), a square marker (wander), a shelter marker (rain package), a post per shop. Place houses with the thatch kits so town buildings use the same recipes a player can use.

## Day schedule rule
Shops open 7 to 18; the guard covers 18 to 6; the healer sleeps 22 to 6 but the healer's door is open to emergency dialogue (a bark "I will see you at dawn" after hours).

## Economy rules (from ECONOMY_PLAN.md)
Each shop gets a purse cap of 200 to 300 copper regenerating 100 a day. Dishes sold to a shop are capped by the new value rule, so cooking is a small side income rather than an exploit. Reputation: quests worth 1.5 to 2 times the goods; Friend rank gives the 8 percent price shift already in coins.json.

## Open for Dave
Names, whether the island has a mayor or elder, whether NPCs trade by barter or coins (coins now), and whether the smith appears only after the player builds a forge.
