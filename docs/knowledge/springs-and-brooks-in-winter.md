# Springs and brooks in winter: springs do not freeze, how far the brook below stays open, thin ice by spring mouths, and what drinking and fishing should assume

**Last checked:** 2026-11-08 (Jamie; a short web pass, with the open-water lengths our own sums). **Owners:**
- Steve: drinking water (#719 design, #720 code) and animals at water (#734).
- Sonny: springs in the record (`network.json` spring rows, #726 and #732).
- Kathleen: the frozen water look (#729, #731).

**Related:**
- `animals-on-ice-and-snow.md` (#736): ice each animal needs.
- [cave-microclimate.md](cave-microclimate.md) and `underground-climate.md` (#709): spring water at the cave mean.
- `groundwater-layers-recession.md` (#713): spring stores and recession.
- `docs/design/still_water_ice.md`.

## Lessons (read these first)

1. **A spring comes out at the ground's year-round temperature, so it does not freeze.**
   - "Groundwater equilibrates to the mean annual air temperature", about 9 °C in south-east Minnesota. When it enters a stream in winter "it warms the water, preventing it from freezing" (University of Minnesota, Why Daley Creek doesn't freeze).
   - A Vermont spring "measures 41 degrees in midwinter, just as it does in August" (5 °C). Groundwater-fed springs "can flow year-round, regardless of plunging temperatures" (*Northern Woodlands*, Springs in Winter).
   - Even below −40 °C in Alaska, river reaches fed by groundwater springs stay ice-free or have "dangerously thin ice" all winter (Modeling the thermal balance between groundwater springs and river ice, abstract).
   - **For us:** the year mean at the spring's height. The starter's warmth follows the grid's curve, about 14.4 °C a year at sea level (`OVERNIGHT_DECISIONS_8NOV.md` row 20, #717). So spring #8002 (533 m) comes out at about **10.9 °C**, the same as the cave air there (`underground-climate.md`, #709). The tables below are for a 5.5 °C spring, as on a colder island or high in the mountains. For a 10.9 °C spring, the open lengths are about 1.4 to 1.8 times longer (our sums).

2. **The brook below a spring stays open until its water has cooled to 0 °C, and that takes hundreds of metres.**
   - **Our sums:** open water loses heat to cold air at about h = 20 to 40 W/m² per °C. This counts convection, radiation and evaporation, from calm to breezy (judged, typical values).
     - The water then cools toward the air temperature over a length λ = ρc × Q ÷ (h × W), where Q is the flow and W the width.
     - It reaches 0 °C at x = λ × ln((T_spring − T_air) ÷ (0 − T_air)).
   - **Open length below a 5.5 °C spring:**

     | Spring | Flow | Width | Air −2 °C | Air −5 °C | Air −10 °C | Air −15 °C |
     |---|---|---|---|---|---|---|
     | Seep | 0.2 L/s | 0.2 m | 140 to 280 m | 80 to 160 m | 45 to 90 m | 35 to 65 m |
     | Small spring | 2 L/s | 0.5 m | 550 m to 1.1 km | 310 to 620 m | 180 to 370 m | 130 to 260 m |
     | Good spring | 20 L/s | 1.5 m | 1.8 to 3.7 km | 1 to 2 km | 610 m to 1.2 km | 440 to 870 m |
     | Big spring | 100 L/s | 3 m | 4.6 to 9.2 km | 2.6 to 5.2 km | 1.5 to 3 km | 1.1 to 2.2 km |

     The first figure is with a breeze (h 40) and the second in calm air (h 20).
   - Past that point the brook can freeze, first as ice along the banks and on still pools, then right across where it runs slowly (judged).
   - **Running water freezes last.** Fast, rough water forms slush and ice on the stones before it forms a sheet (judged; frazil and anchor ice are the usual terms).

3. **Around a spring mouth and above an upwelling, any ice is thin.**
   - Where spring water rises into a pond or under a lake's ice, it melts the ice from below. That leaves an open hole or a ring of thin ice (the Alaska abstract: "dangerously thin ice").
   - **Judged:** count ice as half as thick within about 10 to 30 m of a spring mouth or an inflow. That is the same halving rule as `animals-on-ice-and-snow.md` (#736); the 10 to 30 m reach is new here.

4. **On the starter island, the low ground hardly freezes at all, and its brooks never do.**
   - **Our sums** at the grid's warmth (#717 rows 19 and 20: about 34° S, 14.4 °C a year at sea level). They keep `climate.gd`'s ±5 °C season, 8 °C day range, 6.5 °C per km and ±4 °C cold spells:
     - the midwinter mean at sea level is about 9.4 °C. At spring #8002 (533 m) it is about 5.9 °C;
     - at #8002 the coldest dawn, in a cold spell, is about −2 °C (5.9 − 4 for the night − 4 for the spell), and it is above freezing again by mid-morning;
     - so brooks below about 800 m never freeze, and ponds there get at most a dawn skim of a few millimetres (`animals-on-ice-and-snow.md`, #736);
     - the lesson 2 table matters only high up: above about 800 m, a brook can ice at its edges in a midwinter cold spell, and above about 1,200 m, tarns can freeze over.
   - The earlier version of this page used the old 9 °C climate (−7.5 °C dawns, 2.8 cm of pond ice). That no longer holds.

## Judged numbers for Steve, Sonny and Kathleen

### Drinking (#719, #720)

| Source | In winter | Drink? |
|---|---|---|
| Spring mouth | always open, at the year mean (about 10.9 °C at #8002) | yes, always |
| Brook below a spring, within the open length above | open | yes |
| Brook further down, or a brook with no spring | may be ice-edged; open in its fast riffles | yes where open; ice needs a hole |
| Pond or lake | skim or sheet ice | needs a hole; at a spring inflow there may be an open patch |
| Sea | — | no (salt), as #719 |

- **The open length** can come from the table (lesson 2), or from Sonny's spring row: `m3_s` gives Q, and the brook's width gives W.
  - A simpler rule for the game (a fit to the table, within about 30%): open length ≈ 440 m × √(flow in L/s) in calm air at −5 °C. Halve it in a breeze. Multiply by 1.8 at −2 °C, 0.6 at −10 °C and 0.4 at −15 °C. That is for a 5.5 °C spring; for a spring at about 11 °C (the starter at 533 m), multiply again by about 1.5. The square root is there because bigger springs make wider brooks, which lose heat faster.
- **Cold water to drink:** a spring at 5 to 11 °C is cool but safe. Ice-melt water at 0 °C is colder. Neither needs a warmth penalty beyond what eating snow would give (judged).

### Ice holes and fishing (#719, #737)

- **A person can stand on ice** from about 10 cm of clear ice (`animals-on-ice-and-snow.md`, #736). On the starter, only high tarns above about 1,200 m reach that in a cold winter, so ice fishing is a high-mountain thing there. The low ponds never bear a person.
- **Near a spring inflow** the ice is half as thick, so the place where the fish gather in winter (the warmer spring water) is the most dangerous ice.
- **An open patch at an inflow** is the natural "hole" on a frozen pond. Water birds sit at it, and a person could fish from the bank there without walking on ice (judged).

### Animals at water in winter (#734)

- **Herds and wolves** go to the open water: a spring mouth, or the open brook below it (judged, from lesson 1). In a freeze, those spots are where tracks and kills gather.
- **Birds** (ducks, herons, dippers) keep to the open stretch below a spring (`animals-on-ice-and-snow.md` lesson 6, judged).
- The spring's "refuge for tiny creatures from both summer heat and the freezing cold of winter" (*Northern Woodlands*) also means insects, and so wrens and dippers, at springs in winter.

### The look (#729, #731)

- **A spring mouth in frost:** water steams only when the air is about 10 to 15 °C colder than the water (`breath-and-steam-in-cold.md`, #744, our sums tuned to sea smoke). For a 5.5 °C spring that means air below about −8 °C (−5 °C in humid, calm air). For the starter's 10.9 °C spring at #8002, it means air below about −3 °C, or about 0 °C in humid, calm air.
  - The coldest dawns at #8002 are about −2 °C, so its spring steams faintly on calm, damp dawns in a midwinter cold spell, and the mist clears by mid-morning.
  - When it does steam, frost and rime build on the stones and plants beside it (judged).
- **The open length:** dark open water first; then ice shelves growing out from the banks; then full ice on the slow pools; fast riffles open longest.
- **Green moss and cress** stay green in the spring run all winter (judged).

## Never-see checks

- a spring frozen over;
- a pond frozen solid right up to a spring inflow;
- a spring-fed brook iced over within a few metres of its source;
- a frozen brook whose fast riffles freeze before its slow pools;
- people walking or fishing on ice on the starter's low ground.

## How ours works today (read from the PR titles and notes, 8 Nov, not tested)

- #719 (design): drinking water comes from the record. Springs work always, brooks by season, ice needs a hole, and there is no salt. #720 is step 1 of the code (flag off).
- #731: the frozen water look on the liquid sheets (`--frozen-water`). Its note gives the starter ponds at most 2.8 cm (spawn pond) and 5.6 cm (#8002), for the old 9 °C climate. At the grid's 14.4 °C the low ponds get almost none (#736).
- #734: herds drink at dawn and dusk, and wolves wait there (flag off).
- #737: animals on ice, ice holes sent to the client (protocol 97), and a thaw moat hook.
- No spring-temperature or open-length rule was read in code for this page.

## Sources

- University of Minnesota, Why Daley Creek doesn't freeze. https://midge.cfans.umn.edu/news/why-daley-creek-doesn%E2%80%99t-freeze
- *Northern Woodlands*, Springs in Winter (The Outside Story). https://northernwoodlands.org/pdf/TOS_Springs_in_Winter.pdf
- Modeling the thermal balance between groundwater springs and river ice (abstract). https://core.ac.uk/works/9356593
- Our sums: the open-water lengths, the starter's winter air at the grid's 14.4 °C, the steam at the spring.
- **Judged:** heat loss h 20 to 40 W/m² per °C, half ice within 10 to 30 m of a spring, the order of freezing along a brook, animals and birds at open water, the square-root game rule.

## Fetches still to do

1. A measured open-water length below a spring in winter, with its flow and the air temperature.
2. Heat loss from open water in winter (a river ice engineering source with h values).
3. Frazil and anchor ice in fast streams (where and when they form).
