# Trees and forests in weather: sway, breaking, windthrow, leaf fall, snow, drip

**Last checked:** 2026-11-08 (web research by Jamie). **System owners:**
- MikeW: trees as habitat and shelter.
- Kathleen: tree look and sound (`flora_view.gd`, `tree_wind.gd`).
- Steve: shelter and warmth (`cover.gd`).

**Related:** [wind-over-terrain.md](wind-over-terrain.md) (gusts, crests, sway frequency), [snow-on-slopes.md](snow-on-slopes.md), [sound-outdoors.md](sound-outdoors.md), `soils-ground-wetness.md` (#657, wet soils), `fire-outdoors.md` (#668, drying wood).

## Lessons (read these first)

1. **The Beaufort land scale says what trees do at each wind.** These are the Met Office land descriptions (Metlink):

   | Force | km/h | m/s (our conversion) | Trees |
   |---|---|---|---|
   | 2 light breeze | 6 to 11 | 2 to 3 | "leaves rustle" |
   | 3 gentle breeze | 12 to 19 | 3 to 5 | "Leaves and small twigs in constant motion" |
   | 4 moderate | 20 to 28 | 6 to 8 | "small branches moved" |
   | 5 fresh | 29 to 38 | 8 to 11 | "Small trees in leaf begin to sway" |
   | 6 strong breeze | 39 to 49 | 11 to 14 | "Large branches in motion" |
   | 7 near gale | 50 to 61 | 14 to 17 | "Whole trees in motion" |
   | 8 gale | 62 to 74 | 17 to 21 | "Twigs break off trees" |
   | 9 strong gale | 75 to 88 | 21 to 24 | slates off roofs |
   | 10 storm | 89 to 102 | 25 to 28 | "trees uprooted" |

2. **Trunks snap at about 42 m/s, almost whatever the tree.**
   - Storm data and lab tests give a critical wind speed for breaking of "approximately 42 meters per second" (Virot et al. 2016, Physical Review E, reported by Phys.org).
   - Doubling a tree's size changed it by only 9%, and oak broke at about 10% more than pine.
   - In the 2009 storm Klaus, where local winds topped about 42 m/s, "fewer than half the trees survived", pines and oaks alike (Physics Today).

3. **In Britain, trees are pulled over by the roots more often than they snap, and wet ground is the reason.** (Forestry Commission Bulletin 114, *Forests and Wind*.)
   - Windthrow, where the root plate tips over, is more frequent than windsnap, where the stem breaks.
   - Damage "is likely above about 30 m/s", and over 40 m/s brings widespread damage.
   - **Gusts:** gusts can push "up to ten times" harder on a tree than the mean wind does. Two or more gales add up, because the first loosens the roots.
   - **Soils:**
     - surface-water gleys and peaty gleys "restrict root systems to less than 50 cm depth". "These are the soils that give most of our windthrow problems";
     - on such soils the winter water table is often under 40 cm deep;
     - wetter soil is quickly weaker.
   - **How often it happens:** winds of 35 m/s come about once in 20 years in central England, once in 5 years mid-slope in south Scotland, and every year at sea level in the Western Isles. Winds of 40 m/s come once in 100, 20 and 5 years at the same places.
   - **Edges:** old forest edges are wind-firm. New edges made by felling are weak, and damage can run several tree heights into the stand.
   - **Wet ground in tests (Teagasc, Ireland):** "poorly drained soil beneath the root plate" lets the plate overturn. Sitka spruce on a wet gley failed at 4 kNm, as the water pressure rose and the soil turned liquid. A tree on drained soil had not failed at 15 kNm.

4. **Leaves fall on short days, not because of wind.**
   - "Short day length is the most important environmental cue" for leaf fall. A layer of cells at the leaf stalk is digested, and then the leaf drops (Montana Public Radio, Field Notes).
   - Drought brings it earlier, and a wet spring and summer delay it.
   - A sudden hard frost can kill leaves before that layer forms. Those dead leaves then hang on into winter.
   - Trees in leaf catch more wind and snow. "Strong winds and heavy snow can put tremendous pressure on limbs that have leaves", and wet snow on trees in leaf does major damage.
   - In a North Dakota October storm, 12 inches of snow on trees still in leaf left "half of the Dickinsons' trees ... severely damaged" (CBS News).

5. **Conifers catch half or more of the snow, and hold it for weeks in the cold. Bare broadleaves hold almost none.**
   - **Cold forest (spruce, Yukon):**
     - in mid-winter the canopy held 46 to 69% of all the snow that had fallen (21 to 39 mm of water), and dense black spruce held up to 67%;
     - snow stays in the canopy "for weeks to months in the cold midwinter";
     - 38 to 45% of the year's snowfall turned straight to vapour from the canopy (Pomeroy, Hedstrom and Parviainen 1998).
   - **Mild, wet mountains (Oregon, Storck et al. 2002, via All-geo):**
     - conifers first caught up to 60% of the snow;
     - in mild weather, 70% then left as meltwater drip and 30% as "masses of snow falling to the ground";
     - snow turned to vapour only below freezing, and slowly, about 1 mm a day.
   - **Where the snow lies:** wind blows snow off branches, and it drops in clumps. The ground is driest under the crown and wettest near the crown's edge, by up to 30 to 40% (Broxton et al. 2015, via All-geo).
   - Bare broadleaves add "little" to winter interception (All-geo).

6. **Conifers keep a quarter to nearly half the rain off the ground. Broadleaves keep a tenth to a quarter.**
   - In Britain, "between 25 and 45% of annual rainfall is typically lost by interception from conifer stands", against "10–25% for broadleaves". The loss is highest in wet, windy uplands and in winter (Nisbet 2005, Forest Research, *Water Use by Trees*).
   - A crown holds only about 4 mm at most, even in a 50 to 100 mm storm (Wikipedia, Interception).
   - Rain that drips off leaves comes down as bigger drops. Drops over about 1.5 mm under trees are mostly drip, while free throughfall keeps the size spread of open rain. In strong wind and hard rain, the shaking canopy makes the drops smaller (Atmosphere 8(12): 240).

## Judged numbers for our trees

### Crown motion by wind (for `flora_view.gd` sway and `tree_wind.gd`)

| World wind (m/s) | Leaves and needles | Branches | Whole tree (top sway) |
|---|---|---|---|
| under 2 | still | still | still |
| 2 to 5 | flutter, rustle | twigs move | none |
| 5 to 8 | constant flutter | small branches | a slight lean of young trees |
| 8 to 14 | leaves show their pale undersides | large branches move | young trees sway; old trees 0.1 to 0.3 m at the top |
| 14 to 21 | streaming | branches whip; twigs and leaves come off | all trees sway 0.3 to 1 m at the top |
| 21 to 30 | stripped | dead and weak branches break | 1 to 2 m at the top, with hard gust swings |
| over 30 | — | — | trees on wet soil and new edges go over; past about 42 m/s, trunks snap |

- **Sway rhythm:**
  - a mature tree sways at about 0.2 to 0.5 Hz, about 0.26 Hz in `wind-over-terrain.md`, and about 19% faster when bare;
  - the motion follows the gusts. It is not a steady sine;
  - small trees and saplings sway faster than big ones.
- **Twigs and leaves in the air:** from about 17 m/s (force 8), some twigs, leaves and needles fly. Past 21 m/s, a litter of broken twigs lies under broadleaves after the storm.

### Windthrow (if Dave wants storm damage)

- **Chance that a mature tree goes over in one storm (judged from Bulletin 114):**

  | Peak gust | Dry, deep soil | Wet gley or peat, winter |
  |---|---|---|
  | under 25 m/s | 0 | 0 |
  | 30 m/s | under 1% | 2 to 5% |
  | 35 m/s | 1 to 3% | 10 to 20% |
  | 40 m/s | 5 to 10% | 30 to 50% |
  | 42 m/s and over | about half snap or go over, whatever the soil | |

- **What raises the risk:**
  - the soil is waterlogged, for example in a wet-soil class from `soils-ground-wetness.md`, or after a week of rain;
  - the tree stands on a new edge or alone on a crest;
  - the tree is tall, over about 20 m;
  - the tree is in leaf, so a summer storm hits broadleaves harder.
- **The look:** the root plate lifts, 2 to 4 m across and 0.3 to 0.5 m thick on wet soils, with a pit where it was. Trees fall in the direction of the wind, in rows. A snapped tree leaves a jagged stump 2 to 8 m high.

### Leaf fall by season (our game seasons)

| Broadleaf | Spring | Summer | Autumn | Winter |
|---|---|---|---|---|
| Crown | buds, then fresh leaves | full | colour, then falling from mid-autumn | bare twigs |
| Leaf litter | old, thin | thin | deep, fresh, crunchy | flattened, wet |

- A windy wet spell in mid-to-late autumn brings most leaves down in a few days. Before the cells at the stalk have formed, wind takes only a few.
- Young beech and oak often keep dead brown leaves into winter. That suits a hedge or a sapling, not a forest crown.
- Conifers keep their needles all year. Larch is the exception and goes gold, then bare.

### Snow on trees

- **Conifers:**
  - they catch about half of a snowfall, up to about 30 to 40 mm of water;
  - in frost the snow stays for weeks;
  - above 0 °C, or in wind over about 8 m/s, it sheds within hours, partly as clumps of 1 to 10 kg dropping off branches, the rest as drip.
- **Broadleaves:** when bare they hold only a thin line of snow on top of the branches. With leaves on, in early autumn or late spring, wet snow loads them and branches break.
- **The ground:** under a conifer crown the snow is shallow, a little over half the open depth. It is deepest just outside the crown's edge.

### Canopy drip after rain (for `wet_sounds.gd` and `cover.gd`)

- **Shelter:** under a conifer, the first 1 to 2 mm of rain hardly gets through, and a big crown keeps off about a third. Under a broadleaf in leaf, about 15% is kept off. A bare broadleaf gives little shelter.
- **Drip after the rain stops:** judged 15 to 60 minutes, longer in calm and humid air. The crown empties its stored 1 to 4 mm, and a gust brings a shower down.
- **The sound:** fewer but heavier drops under trees than in the open (drops over 1.5 mm are drip). In the forest after rain, the patter goes on when the open field is already quiet.

## Never-see checks

1. Trees swaying the same amount in a calm and in a gale.
2. Full green broadleaf crowns in deep winter, or brown leaves on every broadleaf all winter.
3. Snow staying on conifer branches through a thaw day. Snow piled thick on bare broadleaf twigs.
4. Trees falling uphill, against the wind, or in a breeze.
5. Rain stopping under the trees at the same moment it stops in the open.
6. Dry ground under a bare broadleaf in the rain.

## How ours works today (read from the code, 8 Nov, not tested)

- **Sway (`flora_view.gd` foliage shader):**
  - two fixed sine waves, at `TIME * 0.9` and `* 1.9`, about 0.14 and 0.30 Hz, with a fixed `sway` per material: broadleaf 0.012, conifer 0.006, palm 0.02 and grass 0.09;
  - a per-vertex `flutter` of 0.06;
  - nothing feeds the wind's strength into the shader, so trees sway the same in a calm and in a gale (never-see 1).
- **Sound (`tree_wind.gd`):** the loops for pine, leaves, dry leaves and bare branches follow the wind's strength and the season. They are silent below a world wind of 0.35. This part already follows the wind.
- **Seasons:** broadleaf leaf colour follows the season: green, then autumn colour, then "dead leaves in winter" (`flora_view.gd` line 1797). So winter crowns are full of brown leaves rather than bare (never-see 2). Bare models exist only for picked berry bushes.
- **Snow:** there is no snow on trees and no snow interception.
- **Windthrow:** trees do not fall in storms. Felled trees use `fell_pose.gd`.
- **Cover:** `cover.gd` gives a yes or no "covered" under a big enough tree's crown, with one fixed mild value whatever the tree or season. A bare winter broadleaf therefore shelters as well as a spruce.

## Sources

- Metlink (Royal Meteorological Society), Beaufort scale: https://www.metlink.org/fieldwork-resource/beaufort-scale/
- Phys.org (2016), Trees found to break at near the same wind speed regardless of size or species (Virot et al., Physical Review E 93): https://phys.org/news/2016-02-trees-size-species.html
- Physics Today, Trees break at a nearly constant wind speed: https://physicstoday.aip.org/news/trees-break-at-a-nearly-constant-wind-speed
- Forestry Commission Bulletin 114, Forests and wind: management to minimise damage: https://cdn.forestresearch.gov.uk/1995/03/fcbu114.pdf
- Teagasc, Reducing windthrow losses in farm forestry: https://teagasc.ie/crops/forestry/research/reducing-windthrow-losses-in-farm-forestry/
- Montana Public Radio, Field notes: what determines when leaves fall: https://www.mtpr.org/post/field-notes-what-determines-when-leaves-fall
- CBS News, Early snow overloads autumn trees: https://www.cbsnews.com/news/early-snow-overloads-autumn-trees
- Pomeroy, Hedstrom and Parviainen (1998), The snow mass balance of Wolf Creek, Yukon: https://research-groups.usask.ca/hydrology/documents/pubs/papers/pomeroy_et_al_1999_5.pdf
- All-geo (Jefferson), Conifers capture the snow, but do they intercept it? (Storck et al. 2002; Broxton et al. 2015): https://all-geo.org/jefferson/?p=1931
- Nisbet, T. (2005), Water use by trees, Forestry Commission Information Note 65: https://cdn.forestresearch.gov.uk/2005/03/fcin065.pdf
- Wikipedia, Interception (water): https://en.wikipedia.org/wiki/Interception_(water)
- Throughfall drop sizes, Atmosphere 8(12): 240 (MDPI): https://www2.mdpi.com/2073-4433/8/12/240
