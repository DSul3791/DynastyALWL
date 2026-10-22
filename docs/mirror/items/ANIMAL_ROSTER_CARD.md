# Animal roster card (Radar, 2026-10-21): what comes after rabbit, deer, wolf

Nothing here is built. Same rules as today: server-owned records, no physics, staggered ticks, shared senses block (wind, crouch, hills, forest), habitat check, bleed-out, carcass and Hunting skill scaling. Tick cost is per animal near a player at the near rate (rabbit and deer measured about 0.01 ms; the soak with 20 players and wolves was 1.2 ms for all animals).

| | Moose | Boar | Fox | Bear | Bird flock (ducks, geese) |
|---|---|---|---|---|---|
| Habitat | wet forest edge, lake and river shores | oak and beech forest, mud near water | forest edge, meadow | deep forest and hills, far from town | ponds and lakes |
| Group | alone, or cow with calf | sounder of 3-6 | alone | alone, or sow with cubs | 6-20 |
| Health | 90 (10 spear hits) | 45 | 12 | 120 | 3 each |
| Speed m/s | walk 1.5, run 11 | walk 1.5, charge 9 | trot 4, sprint 11 | walk 1.8, run 9 | water 1, fly 12 |
| Senses | poor sight, good smell and hearing | poor sight, good smell | all good | good smell, fair sight | sharp sight, takes off at 20 m |
| Behaviour | grazes, wades; flees; a rutting bull (autumn) or a cow with calf charges a close player | roots for acorns; a wounded boar or a sow with piglets charges, otherwise leaves | steals unattended raw meat from a camp at night, flees at once | grazes, fishes; defends cubs or a carcass; follows a bleeding or meat-carrying player; stands up and bluffs first | floats, panics into flight and the whole flock goes; nests in spring |
| Danger | high if charged: 25 health a hit, can be dodged round a tree | medium: 12 a hit, short charge | none (a nuisance) | very high: 35 a hit, kills a healthy player in four | none |
| Loot | meat x8, hide x2, antler x2 | meat x4, hide x1, tusk x2 | pelt x1, meat x1 | meat x6, hide x3, claw x2, fat | meat x1, feathers x3, eggs in spring |
| Why | big food prize; Dave's wolf distraction | gives forests a risk before wolves | camp-keeping lesson (cover your meat) | the late-game fear, keeps players out of deep forest | easy first-hunt target, free arrows later |
| Tick cost | like deer, 1 per herd of 1-2 | like deer, herd of 3-6 | like rabbit | like wolf, no pack brain | one record per flock, birds drawn client-side |

## Recommendation
Build in this order: moose (it is the wolves' prey, so the pack distraction becomes real, and it is the same code as deer with a charge state), then fox (cheap, teaches the camp meat lesson), then bird flocks (cheap, client-side drawing, easy first hunt). Boar and bear come later and need the armour value before they are fair. Moose and bear get a separate "territory" circle so they never spawn inside the starter tile (same exclusion as natural wolves).

## Questions for Dave (three)
1. Moose first, then fox and bird flock: yes, or a different order (for example bear sooner)?
2. Should a charging animal (moose, boar) be dodgeable by sidestepping or by a tree between you, or should a bad meeting simply hurt (like the wolf maim)?
3. Fox stealing food from a camp: wanted, or too annoying?

## Horse (Dave 2026-10-21, not built yet)
Wild first, tamed later. A per-animal tamable value (0 to 1) decides behaviour: high = curious and lets you approach, low = flighty and always runs. Herds with a lead mare, foals stay close. Avoids the player like every animal; flees early (good eyes, ears, nose); a stallion may defend the herd like a moose (warn, charge, dodgeable). Future: taming (feed, patience, skill), riding, harness for logging and wagons (see DESIGN_IDEAS.md).
