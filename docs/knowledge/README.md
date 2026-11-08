# Knowledge library

This folder holds one doc per topic. Each doc records what we learned building a system, what other people do, what we tried, and what worked. Jamie (documentation) keeps it. This is Dave's idea, from 6 Nov 2026.

## The rule: read here first

Before you code a system or fix a bug:

1. **Read the topic doc here.** Check its "Lessons" and "What we tried" sections, so you don't repeat a dead end.
2. **If the doc is missing or its "Last checked" date is old, ask Jamie** to research the topic. Jamie searches the web for best practice, tips and other people's experience, and writes it up here. You can also search yourself, but put what you find in the doc.
3. **When you finish, add your lesson** to the doc's "What we tried" table: what you did, the PR, and whether it worked. A short line is enough. Jamie tidies it up.

Docs only. No tests or bakes in the cloud, ever (Dave's law, 5 Nov 2026). Anything that needs a run goes to Dave's PC through the coordinator.

## Doc layout

Pages from 8 Nov on use this order:

- **Last checked:** the date the web research was last refreshed, and the owners and related pages.
- **Lessons:** what the sources say, each with its source, the most important first.
- **Judged numbers for the game:** the values to build with.
- **Never-see checks:** things that must never appear in the game.
- **How ours works today:** what the code does, read from the code (not tested), with its date.
- **Sources:** every link.

Older pages (6 and 7 Nov) use Lessons, How ours works, What we tried (each attempt, its PR and the result), What others do, and Decided / next. Both layouts are fine. Add your lesson to whichever the page has.

**Labels:** "Our sums" means arithmetic done here from a sourced formula. "Judged" means no source was found, so the number is our best estimate.

**Contradictions:** [CONTRADICTIONS.md](CONTRADICTIONS.md) lists every place two pages, or a page and the code, give different numbers for the same thing, and which one to follow. Check it before you code from a number.

## Index

The **Numbers** column says how far a page's numbers are backed:
- **Sourced:** almost every number has a source.
- **Mostly sourced:** a few named numbers are judged.
- **Mixed:** the lessons are sourced, but the game tables are judged or our sums.
- **Game values:** the numbers are the game's own design values (Dave and the team). Other games are the references, so there is nothing real-world to source.
- **Own work:** our build notes, with no numbers to source.

Where a number still needs a source, the cell names it.

| Topic | Doc | Last checked | Owner of the system | Numbers |
|---|---|---|---|---|
| Creature models (bought rigged animals: install, check, clips, sizes) | [creature-models.md](creature-models.md) | 2026-11-07 | MikeW | Own work |
| Torch and campfire light in fog, rain and snow (reach, veil, halos, lit rain and snow, light over snow) | [firelight-in-weather.md](firelight-in-weather.md) | 2026-11-08 | Kathleen | Mixed: the reach table, fog reach, extra reach over snow and flame colours are judged; moon and snow albedo not checked |
| Moonlight and starlight (night lux by moon phase and height, starlight, overcast, torch falloff by distance, twilight, colour at night, snow) | [moonlight-starlight.md](moonlight-starlight.md) | 2026-11-08 | Kathleen (night light), MikeW (eye shine) | Mostly sourced: lux values sourced; game falloff judged |
| Water in Godot (the simulation decides where water is; rivers, brooks, lakes, falls, flow, float precision, what other games do, Sonny's water plan) | [water.md](water.md) | 2026-11-06 | Sonny | Own work; methods sourced |
| Sea and shore (tides, waves by fetch, surf zone by beach slope, swash, wrack line, salt spray, shore ice) | [sea-and-shore.md](sea-and-shore.md) | 2026-11-08 | Sonny, Kathleen (look) | Mixed: tide range, fetch and swell, wrack width, spray reach and wet-line drying are judged |
| Water clarity after rain (turbidity recovery, settling times, peat colour) | [water-clarity-after-rain.md](water-clarity-after-rain.md) | 2026-11-08 | Kathleen, Sonny | Mixed: the clearing half-lives, peat colour fade and snowmelt pulse are judged |
| Foam and white water below falls and rapids (white water by Froude number, plunge pools, foam sources, foam lines, colour) | [foam-falls-rapids.md](foam-falls-rapids.md) | 2026-11-08 | Kathleen, Sonny | Mixed: foam lifetime (10 to 30 min) and how much each source makes are judged |
| Caves (Dave's placement rules, skeleton carving, coarse LOD, walkable floors, darkness, cave water, dens) | [caves.md](caves.md) | 2026-11-06 | Sonny, Kathleen and Kathreen (look) | Own work; other games' practice sourced |
| Cave microclimate (deep-cave temperature, damp, air at the mouth, daylight reach, eyes, drips, dens and smoke) | [cave-microclimate.md](cave-microclimate.md) | 2026-11-08 | Kathleen (light, sound), Steve (dens, warmth), MikeW | Mostly sourced: the daylight share at each spot past the mouth is judged |
| Sound outdoors (distance, air loss, wind shadow and carry, night carry, rain masking, snow and fog, forest, echoes, rivers) | [sound-outdoors.md](sound-outdoors.md) | 2026-11-08 | Kathleen (sound stage), Jason (audio) | Mixed: the rain bed by game rain, echo levels, fog cut and river level by flow are judged |
| Sounds of weather and water (rain by surface and rate, wind by Beaufort in grass, trees and rock, how far water, surf and fire carry, thunder delay and range) | [weather-water-sounds.md](weather-water-sounds.md) | 2026-11-08 | Kathleen (sound stack), Steve (fire sounds) | Mixed: sourced levels, with our sums for hearing ranges |
| Animal behaviour (senses, flee and threat ranges, temperaments, seasons, young, levels by distance) | [animal-behaviour.md](animal-behaviour.md) | 2026-11-06 | MikeW | Game values |
| Animals in weather (rain, wind, storms, snow, cold, heat: shelter, facing the wind, feeding before storms) | [animals-in-weather.md](animals-in-weather.md) | 2026-11-08 | MikeW, Steve | Mixed: the size of each rule (feeding share, spook range, drift speed, storm feeding) is judged |
| Animals on ice and snow (who crosses frozen water, ice each animal needs, slipping, wolves on lake ice, foot load and sinking in snow, snow on backs, birds at the ice edge) | [animals-on-ice-and-snow.md](animals-on-ice-and-snow.md) | 2026-11-08 | Steve (ice), MikeW (behaviour) | Mixed: sourced ice rule, deer on ice, wolves and foot loads; our sums and some judged lines |
| Animal tracks and sign (print size and shape by species, walk, trot and gallop patterns, how long prints last by ground, droppings, browse height, beds) | [animal-tracks-sign.md](animal-tracks-sign.md) | 2026-11-08 | MikeW | Mixed: field-guide figures from memory, not rechecked; lifetimes and print spacing judged | Mixed: field-guide sizes from memory (marked FG), judged lifetimes |
| Torches and fire (torch item, rain douse, relight, the simple fire rule, light count, carry pose) | [torches-fire.md](torches-fire.md) | 2026-11-06 | Sal (thread closed), Kathleen (poses) | Game values |
| Fire outdoors (wood moisture and drying, rain on fires, embers, wind, smoke drift and plume height, burn rates) | [fire-outdoors.md](fire-outdoors.md) | 2026-11-08 | Kathleen (look), Steve (rules) | Mixed: fuel drying classes, green wood heat and plume rise sourced; rain on fire by size, ember times and the wet-wood rule judged |
| Wind over terrain (crest speed-up, lee shelter, gaps, night drainage, gusts, how trees, grass, smoke, flags and sound read the wind) | [wind-over-terrain.md](wind-over-terrain.md) | 2026-11-08 | Kathleen (look), MikeW (animals) | Mixed: the wind 0 to 1 to m/s mapping and most look numbers (sway, grass bend, smoke tilt, gust timing) are judged |
| Trees in weather (crown sway by wind force, branch break, windthrow and wet soils, leaf fall, snow on trees, canopy drip and shelter) | [trees-in-weather.md](trees-in-weather.md) | 2026-11-08 | Kathleen (look, sound), MikeW, Steve (cover) | Mixed: sourced lessons, judged game tables |
| Warmth and weather (cold, rain, wet, drying, fire heat) | [warmth-weather.md](warmth-weather.md) | 2026-11-06 | Steve | Game values |
| Soils and ground wetness (infiltration by soil, puddle drain times, peat and clay waterlogging, frost heave, mud season) | [soils-ground-wetness.md](soils-ground-wetness.md) | 2026-11-08 | Sonny (record), Kathleen (puddles) | Mostly sourced: the wetness class for each soil, frost heave size and mud-season walking speed are judged |
| Snow on slopes (wind drift and scour, cornices, melt order by aspect, last patches) | [snow-on-slopes.md](snow-on-slopes.md) | 2026-11-08 | Sonny, Kathleen | Mixed: the drift factors, cornice size and snow_off delays by aspect are judged |
| The guiding document (G-ids, D-ids, how designs reach the game) | [guiding-document.md](guiding-document.md) | 2026-11-07 | Coordinator | Own work |
| Snow lines and mountain climate (snow line, lapse rate, aspect, drift, summer snow patches) | [snow-lines-mountain-climate.md](snow-lines-mountain-climate.md) | 2026-11-08 | Sonny, weather owner, Kathleen (look) | Sourced: the worked case is our sums, and its gully drift ×3 is assumed |
| Glaciers and mountains (cirques, horns, arêtes, U-valleys, tarns, slope limits) | [glaciers-mountains.md](glaciers-mountains.md) | 2026-11-08 | Sonny | Sourced |
| Rivers and floodplains (meanders, braids, floodplains, levees, terraces, fans, deltas) | [rivers-floodplains.md](rivers-floodplains.md) | 2026-11-08 | Sonny | Sourced |
| Cirques and horns (headwall retreat rates, granite, how many glacial cycles make a horn, rule 6 settings) | [cirques-and-horns.md](cirques-and-horns.md) | 2026-11-08 | Sonny | Sourced: the rule 6 settings are judged middles of sourced ranges |
| Upland streams (stream density, bankfull flood ratio, Hey and Thorne widths, waterfalls, wave limit on deltas) | [upland-streams-numbers.md](upland-streams-numbers.md) | 2026-11-08 | Sonny | Mostly sourced: still needs the Hey and Thorne depth equation checked, stream density on permeable rock, and an upland sand yield |
| Contradictions between pages and with the code, and which to follow | [CONTRADICTIONS.md](CONTRADICTIONS.md) | 2026-11-08 | Jamie | Audit |
| Specific yield by rock type (granite, basalt, karst and other limestone, sandstone, shale, chalk, till, sand and gravel, peat; for spring stores and Rorabaugh recession) | [specific-yield.md](specific-yield.md) | 2026-11-08 | Sonny (springs, watershed) | Mostly sourced: a few rock types judged |

### Most wanted sources

These judged numbers drive code and still need a source:
1. The wind 0 to 1 to m/s mapping (`wind-over-terrain.md`), which four pages use.
2. The tide range for the starter island (`sea-and-shore.md`), if tides come.
3. Foam lifetime (`foam-falls-rapids.md`).
4. The clearing half-lives for rivers and lakes (`water-clarity-after-rain.md`).
5. The daylight share past a cave mouth (`cave-microclimate.md`).
6. The drift factors and melt delays by aspect (`snow-on-slopes.md`).
