# Knowledge library

This folder holds one doc per topic. Each doc records what we learned building a system, what other people do, what we tried, and what worked. Jamie (documentation) keeps it. This is Dave's idea, from 6 Nov 2026.

## The rule: read here first

Before you code a system or fix a bug:

1. **Read the topic doc here.** Check its "Lessons" and "What we tried" sections, so you don't repeat a dead end.
2. **If the doc is missing or its "Last checked" date is old, ask Jamie** to research the topic. Jamie searches the web for best practice, tips and other people's experience, and writes it up here. You can also search yourself, but put what you find in the doc.
3. **When you finish, add your lesson** to the doc's "What we tried" table: what you did, the PR, and whether it worked. A short line is enough. Jamie tidies it up.

Docs only. No tests or bakes in the cloud, ever (Dave's law, 5 Nov 2026). Anything that needs a run goes to Dave's PC through the coordinator.

## Doc layout

Each doc has these sections:

- **Last checked:** the date the web research was last refreshed.
- **Lessons:** short do and don't rules, with the most important first.
- **How ours works:** the current design, with links to code and design docs.
- **What we tried:** a table of each attempt, its PR, and the result.
- **What others do:** community and industry practice, with sources.
- **Decided / next:** the agreed plan and open questions (open questions go on the QA page as cards).

## Index

| Topic | Doc | Last checked | Owner of the system |
|---|---|---|---|
| Creature models (bought rigged animals: install, check, clips, sizes) | [creature-models.md](creature-models.md) | 2026-11-07 | MikeW |
| Torch and campfire light in fog, rain and snow (reach, veil, halos, lit rain and snow, light over snow) | [firelight-in-weather.md](firelight-in-weather.md) | 2026-11-08 | Kathleen |
| Water in Godot (rivers, brooks, lakes, falls, flow, precision) | [water.md](water.md) | 2026-11-06 | Sonny |
| Sea and shore (tides, waves by fetch, surf zone by beach slope, swash, wrack line, salt spray, shore ice) | [sea-and-shore.md](sea-and-shore.md) | 2026-11-08 | Sonny, Kathleen (look) |
| Water clarity after rain (turbidity recovery, settling times, peat colour) | [water-clarity-after-rain.md](water-clarity-after-rain.md) | 2026-11-08 | Kathleen, Sonny |
| Foam and white water below falls and rapids | [foam-falls-rapids.md](foam-falls-rapids.md) | 2026-11-08 | Kathleen, Sonny |
| Caves (placement, shape, darkness, life) | [caves.md](caves.md) | 2026-11-06 | Sonny, Kathleen and Kathreen (look) |
| Sound outdoors (distance, air loss, wind shadow and carry, night carry, rain masking, snow and fog, forest, echoes, rivers) | [sound-outdoors.md](sound-outdoors.md) | 2026-11-08 | Kathleen (sound stage), Jason (audio) |
| Animal behaviour (senses, ranges, temperaments, seasons, young) | [animal-behaviour.md](animal-behaviour.md) | 2026-11-06 | MikeW |
| Animals in weather (rain, wind, storms, snow, cold, heat: shelter, facing the wind, feeding before storms) | [animals-in-weather.md](animals-in-weather.md) | 2026-11-08 | MikeW, Steve |
| Torches and fire | [torches-fire.md](torches-fire.md) | 2026-11-06 | Sal, Kathleen (poses) |
| Wind over terrain (crest speed-up, lee shelter, gaps, night drainage, gusts, how trees, grass, smoke, flags and sound read the wind) | [wind-over-terrain.md](wind-over-terrain.md) | 2026-11-08 | Kathleen (look), MikeW (animals) |
| Warmth and weather (cold, rain, wet, drying, fire heat) | [warmth-weather.md](warmth-weather.md) | 2026-11-06 | Steve |
| Soils and ground wetness (infiltration by soil, puddle drain times, peat and clay waterlogging, frost heave, mud season) | [soils-ground-wetness.md](soils-ground-wetness.md) | 2026-11-08 | Sonny (record), Kathleen (puddles) |
| Snow on slopes (wind drift and scour, cornices, melt order by aspect, last patches) | [snow-on-slopes.md](snow-on-slopes.md) | 2026-11-08 | Sonny, Kathleen |
| The guiding document (G-ids, D-ids, how designs reach the game) | [guiding-document.md](guiding-document.md) | 2026-11-07 | Coordinator |
| Snow lines and mountain climate (snow line, lapse rate, aspect, drift, summer snow patches) | [snow-lines-mountain-climate.md](snow-lines-mountain-climate.md) | 2026-11-08 | Sonny, weather owner, Kathleen (look) |
| Glaciers and mountains (cirques, horns, arêtes, U-valleys, tarns, slope limits) | [glaciers-mountains.md](glaciers-mountains.md) | 2026-11-08 | Sonny |
| Rivers and floodplains (meanders, braids, floodplains, levees, terraces, fans, deltas) | [rivers-floodplains.md](rivers-floodplains.md) | 2026-11-08 | Sonny |
| Cirques and horns (headwall retreat rates, granite, how many glacial cycles make a horn) | [cirques-and-horns.md](cirques-and-horns.md) | 2026-11-08 | Sonny |
| Upland streams (stream density, bankfull flood ratio, Hey and Thorne widths, waterfalls, wave limit on deltas) | [upland-streams-numbers.md](upland-streams-numbers.md) | 2026-11-08 | Sonny |
