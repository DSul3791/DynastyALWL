# Animal tracks and sign: prints, gaits, how long they last, droppings, browse and beds

**Last checked:** 2026-11-08 (Jamie, mostly from memory of the standard field guides; little web today). **System owner:** MikeW (`docs/design/ANIMAL_SIGN.md` and `data/animals/animal_sign.json` on his life-layer branch, behind the `animal_sign` flag). **Related:** [animal-behaviour.md](animal-behaviour.md), [animals-in-weather.md](animals-in-weather.md), [soils-ground-wetness.md](soils-ground-wetness.md) (puddle and wetness times), [snow-on-slopes.md](snow-on-slopes.md) (drifting), `CONTRADICTIONS.md` (#690).

**Labels used on this page:**
- **"FG"** means a field-guide figure recalled from Bang and Dahlström, *Animal Tracks and Signs*; Elbroch, *Mammal Tracks and Sign*; and Elbroch and Marks, *Bird Tracks and Sign*. These are the usual European and North American guides. I did not recheck the numbers against the books today, so treat them as good to about ±20%.
- **"Judged"** means no source, our best estimate.
- "Our sums" means arithmetic done here.

**Species:** the list asked for has hare, badger and sheep. The game has none of the three yet (it has rabbit, cow and goat). They are kept here for later.

## Lessons (read these first)

1. **Gait is read from the pattern, not one print** (FG).
   - **Walk:** single prints, alternating left and right, in two lines a body's width apart.
     - Deer, wolves, foxes, cats and horses set the hind foot into or just behind the front print ("direct register"). A walking line shows one print per step, not two.
     - Bears and badgers often put the hind foot ahead of, or partly over, the front.
   - **Trot:**
     - **Dogs and foxes:** the same single prints at a longer step, in a much straighter line. A trotting fox is the classic "string of pearls" in snow.
     - **Deer:** trot in direct register too.
   - **Lope or canter:** groups of 3 or 4 prints in a slanting row, then a gap.
   - **Gallop or bound:** groups of 4 with long gaps between them.
     - **Running deer:** the hind prints land ahead of the fronts, often with the toes splayed and the dewclaws showing.
     - **Hares and rabbits:** a Y or T. The two small front prints are one behind the other, and the two big hind prints sit side by side ahead of them.
   - **Birds:** walkers (grouse, pheasant, crow when walking) leave alternating prints. Hoppers leave pairs side by side. A crow does both.

2. **Print size separates the big animals** (FG; length of a front print, adult, without dewclaws):

   | Species | Print length | Shape | Walk step | Trot step | Gallop or bound, group to group |
   |---|---|---|---|---|---|
   | Red deer | 7 to 9 cm (stag), 6 to 7 (hind) | two pointed halves, a heart | 60 to 80 cm | 100 to 130 cm | 2 to 5 m |
   | Moose | 13 to 16 cm (to 25 with dewclaws in mud) | big, blunt, splayed in soft ground | 110 to 160 cm | 150 to 200 cm | 3 to 6 m |
   | Wild boar | 5 to 7 cm, dewclaws wider than the hoof | rounded halves, dewclaws set wide behind | 40 to 60 cm | 60 to 80 cm | 1.5 to 3 m |
   | Brown bear | hind 25 to 30 cm by 15 to 17, front pad 13 to 16 wide | five toes, claw marks 5 to 10 cm ahead of the front toes, a human-like hind print | 50 to 70 cm | rarely trots | 2 to 4 m |
   | Black bear | hind 18 to 23 cm | as brown bear, claws shorter and close to the toes | 40 to 60 cm | rarely trots | 1.5 to 3 m |
   | Wolf | 10 to 13 cm by 8 to 11 (hind smaller) | four toes, claws, front pad like a triangle | 60 to 80 cm | 70 to 100 cm, a single line | 2 to 4 m |
   | Dog (large) | 8 to 11 cm | rounder and more splayed than a wolf; wanders | 40 to 60 cm | 60 to 80 cm | 1.5 to 3 m |
   | Red fox | 5 to 6 cm by 4 to 5 | small, oval, a bar across the pad | 25 to 35 cm | 30 to 40 cm, dead straight | 60 to 100 cm |
   | Lynx | 7 to 9 cm, round | four toes, no claw marks | 40 to 60 cm | 60 to 80 cm | 1.5 to 3 m |
   | Brown or mountain hare | front 4 to 6 cm, hind 6 to 8 (10 to 15 splayed in snow) | the Y group | — | — | 1 to 2 m, 3 m or more in flight |
   | Rabbit | front 2.5 to 3.5 cm, hind 4 to 6 | the same Y, smaller | — | — | 20 to 40 cm, to 1.5 m fleeing |
   | Badger | front 4.5 to 5.5 cm long, a little wider than long | five toes in a curve, long front claws 2 to 3 cm ahead | 20 to 30 cm | 40 to 50 cm | rare |
   | Horse | 12 to 15 cm, as wide as long | one round hoof, a V of frog behind | 70 to 90 cm | 120 to 150 cm | 3 to 5 m |
   | Cattle | 9 to 12 cm, 10 to 12 wide | two broad, rounded halves | 60 to 75 cm | rare | rare |
   | Sheep | 5 to 7 cm | two halves, narrow and pointed | 35 to 50 cm | 50 to 70 cm | 1 to 2 m |
   | Goat | 5 to 6 cm | two halves, blunter and squarer | 35 to 50 cm | 50 to 70 cm | 1 to 2 m |
   | Grouse | 4.5 to 6 cm | three forward toes (red grouse feathered, toes blurred in snow) | 10 to 15 cm, alternating | — | — |
   | Crow | 6 to 7 cm | three forward toes and a long hind toe | 8 to 12 cm, alternating; hops in pairs | — | — |

   - **Deer, cattle, sheep and goats:** the halves splay apart and the dewclaws print when the ground is soft or the animal runs.
   - **Young animals:** prints about 0.5 to 0.7 of the adult's length (judged, following the young size in the game).

3. **A print lasts as long as its ground keeps its shape** (FG for what happens, judged for the times):
   - **Wet mud and clay:** the sharpest prints. They set as the mud dries and then stay until rain softens them or feet trample them. A dried print in a track can last weeks.
   - **Turf and grass:** almost no print, only bent, darker grass that springs back in hours. A heavy animal on soaked turf punches deep holes that last days ("poaching").
   - **Sand:**
     - dry sand holds only shapeless dents, softened by wind within hours;
     - damp inland sand holds good prints until rain or wind;
     - on a beach, the next tide or swash wipes them.
   - **Snow:** good prints from about 1 cm of fresh snow.
     - In sun they melt out bigger and lose detail within a day.
     - New snow of more than a few centimetres buries them.
     - Drifting snow fills them within hours.
   - **Leaf litter, gravel and rock:** no prints. A tracker reads disturbed leaves, turned stones and scuffs. That is a different sign.

4. **Droppings name the species** (FG):

   | Species | Droppings | Where |
   |---|---|---|
   | Red deer | black pellets 2 to 2.5 cm long, acorn-shaped with a point and a dimple, shiny when fresh, in heaps of 20 to 100 or more; clumped into a mass on lush summer grazing | where it fed or bedded |
   | Moose | oval pellets 2.5 to 4 cm, brown, like pressed sawdust in winter; in summer a soft pile | the same |
   | Wild boar | dark, lumpy sausage segments about 5 to 7 cm thick | along trails, near rooting |
   | Brown or black bear | thick tubes 4 to 6 cm across in a pile; in late summer loose and full of berry seeds and grass | on trails |
   | Wolf | ropes 2.5 to 4 cm thick, twisted, full of hair and bone chips, tapered; grey-white when old | on trails and at junctions, as a mark |
   | Fox | 1.5 to 2.5 cm thick, 5 to 10 cm long, twisted with a tapered tail, holding hair, beetle wings and berries; a strong musky smell | on raised spots: stones, tussocks, mounds |
   | Hare | round, slightly flattened pellets 1.5 to 2 cm, fibrous, light brown | scattered where it fed |
   | Rabbit | round pellets about 1 cm | in latrines, small piles in the open |
   | Badger | loose and variable, often with beetle bits, in shallow dug pits | in latrines at the sett and along its borders |
   | Horse | balls 5 to 7 cm in a heap | anywhere; stallions keep dung piles |
   | Cattle | a flat pat 20 to 30 cm across | anywhere |
   | Sheep and goats | pellets 1 to 1.5 cm, scattered or clumped | anywhere |
   | Grouse | fibrous, light-brown cylinders 2 to 3 cm long, about 0.7 cm thick (heather) | heaps at roosts and in snow roost holes |
   | Crow | white splashes, and castings 3 to 4 cm long of husks, bones and fur | under roosts and perches |

5. **Browse height and tooth marks tell who fed** (FG):
   - **Deer, cattle, sheep and goats** have no upper front teeth. They tear twigs and leave ragged, crushed ends.
   - **Hares and rabbits** cut clean, at a slant like a knife, low down: up to about 50 to 60 cm, higher when standing on snow.
   - **How high each one browses:**
     - rabbit and hare: under 0.6 m;
     - sheep: up to about 1 m;
     - roe deer: up to about 1.2 m;
     - goat: about 1.5 to 2 m, on its hind legs;
     - red deer: about 1.8 m, which makes the "browse line" under woods;
     - cattle and horse: about 1.5 to 2 m;
     - moose: 2 to 3 m, and it rides saplings down to reach the tops.
   - **Bark stripping:** deer and goats leave vertical tooth grooves up to their browse height, mostly in late winter. Stags fray saplings with their antlers at 0.5 to 1.5 m in late summer.
   - **Boar** root up turf in patches of a square metre to tens of square metres, as if ploughed, and leave mud rubbed on trees near wallows at 0.5 to 1 m.
   - **Bears** tear open logs and anthills, and strip berry bushes.

6. **A bed is a pressed oval the size of the body** (FG):
   - **Red deer:** an oval of flattened grass or heather 1 to 1.5 m long, with hair and often droppings beside it. Roe beds are 0.8 to 1 m and are often scraped to bare soil.
   - **Moose:** an oval 1.5 to 2 m. In snow the bed melts and refreezes into a hard, icy hollow.
   - **Wild boar:** a nest of cut grass and twigs heaped about 1.5 to 2 m across, with muddy wallows nearby.
   - **Bear:** a day bed of 1 to 1.5 m, scraped at the foot of a tree or under cover.
   - **Wolf and fox:** a round bed curled up, about 0.6 to 0.9 m for a wolf and 0.4 to 0.6 m for a fox, often on a rise with a view.
   - **Hare:** a "form", a shallow scrape about 30 to 40 cm long, with its back to the wind.
   - **Sheep:** bare scrapes under banks and boulders, used for years.
   - **Badger:** no bed outside. The sett has spoil heaps and bedding of dry grass dragged in.
   - **Grouse:** roost holes in snow with a heap of droppings inside.

## Judged numbers for the game

### Print spacing by species and speed (our sums from lesson 2)

- **The design's rule:** one print every `stride_m` × (1 + 1.2 × speed / run speed). At a run that is 2.2 times the walking spacing.
- **What real gaits do:** the group spacing at a gallop is about 4 to 6 times the walking step (lesson 2).
- **Suggestions:**
  - **Walk:** one print per *step* (lesson 2's walk column, about half the full stride), alternating left and right.
  - **Trot:** 1.3 to 1.6 times the walk step, in a straighter line. For the fox and the wolf, set the prints almost on one line.
  - **Run:** a group of 4 prints (hoofed animals and dogs) or a Y group (hares and rabbits), and then a gap of the gallop column in lesson 2.
  - Pairs side by side (the design's run rule) is a fair stand-in for hoofed animals and dogs. The rabbit should get the Y.

| Species | Walk step (use) | `models.json` `stride_m` today | Run group spacing (use) |
|---|---|---|---|
| deer | 0.7 m | 1.4 | 3.5 m |
| moose | 1.3 m | 1.8 | 4.5 m |
| boar | 0.5 m | 0.8 | 2 m |
| bear | 0.6 m | 1.1 | 3 m |
| black bear | 0.5 m | 1.0 | 2.5 m |
| wolf | 0.7 m | 1.3 | 3 m |
| fox | 0.3 m | 0.9 | 0.8 m |
| lynx | 0.5 m | 0.9 | 2 m |
| rabbit | 0.3 m hop | 0.6 | 1 m |
| horse | 0.8 m | 1.6 | 4 m |
| cow | 0.7 m | 0.8 | 2 m (rare) |
| goat | 0.4 m | 0.8 | 1.5 m |
| dog | 0.5 m | 0.8 | 2 m |
| grouse, crow | 0.12 m, 0.1 m | 0.2 | — |

- **What `stride_m` is:** `models.json` calls it "metres per footstep", but its values sit near the full stride (two steps) for most species.
  - If one print is laid per `stride_m`, a walking deer shows half its prints.
  - Either lay two prints per `stride_m` or use the walk step column.
  - For the fox, both readings are about 1.5 to 3 times too long.

### How long a print lasts, by ground (in game days; one game day is about one real hour)

| Ground | Design today | Suggested (judged) | Why |
|---|---|---|---|
| Wet clay, mud, worn tracks | 3 days in summer, 10 in winter, 5 between | **Until the next real rain** (rain 0.4 or more for an hour or more), at most 10 days. Sharp for the first day, then softening | The 3 and 10 days are the soils page's puddle times, which is how long the ground *stays wet*. A print set in drying mud outlasts that, and rain is what erases it |
| Turf, grass | 3 days in summer, 10 in winter | **Half a day** for bent grass. **2 to 3 days** for deep hoof holes from a heavy animal (moose, horse, cow, bear) on soaked turf | Grass springs back in hours (lesson 3) |
| Sand inland | until rain over 0.5 or wind 0.6, at most 3 days | the same | — |
| Beach sand below the strand line | — | until the next high tide (about half a day), or the swash | `sea-and-shore.md` |
| Snow | until melt or new snow, at most 10 days | the same, but also filled when the wind is above about 0.35 for 2 hours or more (drifting), and blurred and grown about 1.3 times after a sunny day | `snow-on-slopes.md`: fresh snow moves from 4 to 5 m/s, about 0.35 on the shared wind mapping |
| Stone, gravel, leaf litter, dry ground | none | none, as designed | — |

**Other sign** (judged):
- **Droppings:** 5 days is right for fresh-looking ones. Pellets dry and dull in 1 to 3 days, and stay for weeks as old sign. A cow pat crusts in a day.
- **Browse:** 7 days is fine for fresh white wood. Old browse stays all season.
- **Beds:** 1 day is right in grass. A bed in snow lasts until the next snowfall.

### Never-see checks

- prints on gravel, rock or leaf litter;
- a bear or badger print without claw marks, or a lynx print with them;
- a wolf or fox trail that wanders like a dog's, or a trotting fox not in a straight line;
- a galloping deer leaving the same single alternating prints as a walking one;
- crisp prints in grass three days old;
- prints in snow that survive a night of drifting;
- rabbit pellets in a deer-sized heap, or deer pellets scattered singly;
- browse cut at 2.5 m where there are no moose.

## How ours works today

From reading MikeW's branch on 8 Nov (`claude/mikew-eye-placement`, not on main):
- **`ANIMAL_SIGN.md`:**
  - prints only on soft ground: mud, sand, snow, and wet dirt and turf;
  - one print per footfall once the animal has gone `stride_m` × (1 + 1.2 × speed / run speed);
  - single prints at a walk and pairs at a run;
  - shape by sign group, size by the animal's length;
  - browse after 40 s of feeding, droppings at one feeding spot in four, and a bed after 30 s lying;
  - a pool of 400 decals within 60 m;
  - lifetimes as in the table above.
- **`data/animals/animal_sign.json`:** hints per species and the tracking levels (40 tells the group, 65 the species, 90 age and injury).
- **`data/animals/models.json`:** `stride_m` per species, as in the table above.
- Hare, badger and sheep have no species yet.

## Sources

- Bang, P. and Dahlström, P., *Animal Tracks and Signs* (Collins / Oxford University Press; first English edition 1974, revised 2001). Recalled, not rechecked today.
- Elbroch, M. (2003), *Mammal Tracks and Sign: A Guide to North American Species*, Stackpole Books. Recalled, not rechecked today.
- Elbroch, M. and Marks, E. (2001), *Bird Tracks and Sign of North America*, Stackpole Books. Recalled, not rechecked today.
- Our soils and snow pages for how long ground stays wet and when snow drifts: [soils-ground-wetness.md](soils-ground-wetness.md), [snow-on-slopes.md](snow-on-slopes.md).
