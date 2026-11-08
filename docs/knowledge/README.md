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
| Water in Godot (rivers, brooks, lakes, falls, flow, precision) | [water.md](water.md) | 2026-11-06 | Sonny |
| Caves (placement, shape, darkness, life) | [caves.md](caves.md) | 2026-11-06 | Sonny, Kathleen and Kathreen (look) |
| Sound outdoors (distance, air loss, wind shadow and carry, night carry, rain masking, snow and fog, forest, echoes, rivers) | [sound-outdoors.md](sound-outdoors.md) | 2026-11-08 | Kathleen (sound stage), Jason (audio) |
| Animal behaviour (senses, ranges, temperaments, seasons, young) | [animal-behaviour.md](animal-behaviour.md) | 2026-11-06 | MikeW |
| Torches and fire | [torches-fire.md](torches-fire.md) | 2026-11-06 | Sal, Kathleen (poses) |
| Warmth and weather (cold, rain, wet, drying, fire heat) | [warmth-weather.md](warmth-weather.md) | 2026-11-06 | Steve |
| The guiding document (G-ids, D-ids, how designs reach the game) | [guiding-document.md](guiding-document.md) | 2026-11-07 | Coordinator |
| Rivers and floodplains (meanders, braids, floodplains, levees, terraces, fans, deltas) | [rivers-floodplains.md](rivers-floodplains.md) | 2026-11-08 | Sonny |
