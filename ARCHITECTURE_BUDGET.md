# Architecture and performance budget

How the game shares work between CPU, RAM, disk, GPU and network, so the foundation is right before we add content. Written 2026-10-17 from the owner's request.

**Labels:** *[Measured]* means seen in our own build or tests. *[Practice]* means standard industry practice or a target we have not measured yet. Frame rates from the cloud are headless and say nothing about real graphics; the real check waits for the playtest.

## 1. Who does what

| Part | Best at | In our game |
|---|---|---|
| **CPU** | Many different decisions, in parallel threads | Server: generating ground, placing flora, NPC and world logic, economy, crafting rules. Client: game logic, physics, building meshes in background threads |
| **RAM** | Holding what is needed right now | The loaded ground blocks, flora lists, one copy of each tree mesh, recent cache |
| **Disk** | Holding a lot, slowly | Server: generated blocks and player edits (SQLite). Client: block cache. Never read the disk during a frame |
| **GPU** | Drawing the same thing many times | Ground, all trees and plants as shared instances, water, lighting, weather |
| **Network** | Small steady messages | Positions, edits, new blocks. Send recipes and heights, not finished pictures |

Rules of thumb: the server decides, the client draws. Never send what the client can rebuild cheaply. Never rebuild what is already on disk. Do slow work on background threads, never on the frame.

## 2. Where each thing lives today

- **Ground blocks.** Server generates once and saves; client caches on disk and builds the mesh and collision. *[Measured]* A 20 s walk loaded 11,928 blocks from a 14.6 MB client cache with none re-sent.
- **Flora positions.** Server places and sends a list per chunk; client holds it in RAM. *[Measured]* 125,671 items held, 23,949 drawn, 1,112 with collision, 1.6 MB.
- **Tree shape and color.** Client builds from kind and size. One MultiMesh per species, so thousands of trees share one built copy. *[Measured]* Practice-standard instancing already in use.
- **Water.** Server sends heights per chunk; client builds the surface. *[Measured]* 1,321 cells in 17 chunks in the test area.

## 3. Techniques that fit us

- **Levels of detail (LOD).** Ground already has coarser rings farther out, and collision uses 4 rings (*[Measured]*, fixed the outrunning-the-ground problem). Trees need the same: full model near, simple shape mid, flat card far. *[Practice]*
- **Instancing and sharing.** One built mesh per tree type, many placements. Add a handful of variants per species so forests do not look cloned. *[Practice]*
- **Streaming and caching.** Load around the player, prioritize the ground under them, cache on disk. *[Measured]* The server also builds a bullseye of blocks around players while idle.
- **Background threads.** Generation, mesh building and disk reads off the main thread; the main thread only hands finished work to the GPU. *[Measured]* Server uses threads; client meshing is handled by the voxel module's threads.
- **Culling.** Skip what the camera cannot see (frustum), what is hidden behind hills (occlusion, later), and what is too far to matter (distance fade). *[Practice]*
- **Budgets for assets.** Cap triangles per tree by distance, share textures in atlases, compress textures, avoid per-object materials. *[Practice]*
- **Colliders only near the player.** *[Measured]* Only 1,112 of 125,671 flora items have collision; keep it that way.

## 4. Target per player machine (all *[Practice]* targets, to be measured at the playtest)

**[Decided] Owner's minimum (2026-10-17), with 30 fps agreed as the low-tier goal and stronger machines welcome to enjoy more:** an old GTX/RTX 1050-class graphics card, 8 GB of RAM and a SATA drive (SSD or spinning hard drive) must be able to enjoy the game, and high-end machines must also be well served. Ray tracing is not in scope now.

| Tier | Machine | Frame rate | Game RAM / video memory | View distance | Notes |
|---|---|---|---|---|---|
| **Low (the minimum)** | GTX/RTX 1050-class (2-4 GB video memory), 8 GB RAM, 4-core CPU, SATA SSD or HDD, 1080p | 30 fps steady, never below 20 | Game up to 3.5 GB RAM (the system and browser need the rest); up to 1.5 GB video memory | Short; trees fade early, far ground is coarse | One shadow level or none, simple water (no reflections), fewer tree variants, density of grass and small plants cut, light weather effects, no volumetrics |
| Mid | 4-6 year old desktop, mid graphics card, 16 GB | 60 fps | up to 6 GB RAM, 4 GB video | Medium | Full instancing, near shadows, nicer water |
| High | Current graphics card, 16-32 GB | 60-144 fps | up to 10 GB RAM, 8+ GB video | Long | Best lighting, weather, water, extra detail |

Ray tracing: **[Future option]**. Keep lighting and water behind a quality setting so a ray-traced path can be added later for high-end cards without touching the low tier.

### Quality settings that scale between low and high

One master setting (Low, Medium, High, Ultra) sets a bundle of individual sliders, which players can still change:
view distance, ground detail rings, flora density and distance, tree detail level, shadow quality, water quality (flat, animated, reflective), weather and lighting effects, texture size, and the size of the client cache. The game picks a starting tier from the detected graphics card and memory. Every new feature must say what it does at Low before it is accepted. *[Practice]*

### What in the current build is risky for the low tier

- **Loading hitches from SATA.** The client reads blocks from its disk cache (*[Measured]* 11,928 blocks, 14.6 MB, from cache). A hard drive is slow at many small reads, and a SATA SSD is still far slower than the fast drives we may be assuming. Reads must stay on background threads, in larger batches, ahead of the player. Not yet tested on slow disks. *[Risk]*
- **Memory for flora is small, not a risk by itself.** *[Measured in code]* Each species is built once (`flora_view.gd`, one mesh per species) and every tree of that kind shares it through a MultiMesh; each placed tree costs only its position, size, turn and, for broadleaf trees, a color, roughly 100 bytes on the CPU side plus the same again in video memory. The 125,671 items near spawn are therefore about 10-25 MB, not gigabytes. The real memory risks are other things: ground blocks and their meshes and collision, the block cache held in RAM, textures and modeled meshes once art arrives, and one collision shape object per nearby tree (1,112 now; thousands would add up in engine objects). *[Risk, moderate]*
- **Draw load.** The cost is not memory but drawing: one draw per species per map cell, the triangles of every visible tree, and shadows (trees cast them). 23,949 drawn items on an old card at 1080p could drop below 30 fps. Mitigations: fewer triangles per tree at distance (levels of detail), tree distance fade, a density setting, and cheaper shadows. Unmeasured; we have only run headless. *[Risk]*
- **Meshing on few cores.** Ground meshes are built on background threads; a 4-core CPU also runs physics and the game. Running fast needs ground ready quickly (*[Measured]* fixed with 4 collision rings); on a slow CPU it may lag again. *[Risk]*
- **Water and tint effects** (smooth surface, underwater fog) are cheap now but will grow with realistic water; keep a flat-water fallback.
- **Client cache size.** It is capped at 2048 MB, which is fine on a hard drive; make it a setting.
- **Server-side speed.** Blocks not yet built on the server arrive late for everyone; low-tier players feel it most because their clients cannot hide it. The server's background builder around players (*[Measured]*) is the answer, not a big pre-build (Section 7).

## 5. Modeled and procedural assets

Owner art direction: Valheim or better, storybook look, heroic characters with a hint of cartoon, ultra-realistic water, weather and lighting.

- **Procedural stays for** where things go, size, age, season color and small variation, because it is cheap to store and send.
- **Modeled assets for** the look: hand-made tree, plant, building and character models, several per species, each with 3 or 4 detail levels. Procedural code then picks the model, scale, tilt and tint.
- **Water, weather and lighting** are mostly GPU shader work, so they cost frame time, not data. Budget them by quality tier.
- **Characters** get the largest triangle budget per object but there are few on screen; keep them separate from the thousands of trees.
- Keep a triangle and texture budget per category and check new art against it before accepting it.

## 6. Most valuable next steps, in order

1. **Real-hardware measurement at the playtest**, including one machine matching the low tier (1050-class, 8 GB, SATA drive). Frame time split (CPU vs GPU), memory, and load times from a hard drive and a SATA SSD. Everything above is a target until then.
2. **Tree levels of detail and variants.** Biggest GPU and memory lever; set the model and detail-level format before any art is made.
3. **A quality setting and per-tier budgets in code** (view distance, flora density, shadow and water quality) so one setting scales the game from the 1050-class minimum to high end.
4. **Cache size limit and a clear-cache control** on the client (see Section 7), so the grown cache never fills a small drive.
5. **Frame-time and memory readout in the game HUD**, so every later change shows its cost right away.

## 7. Install size and growth (owner decision, 2026-10-17: **[Decided]**)

No big pre-build. The install download stays as light as possible. Ground is built and saved as the player travels, so the local data grows with where that player has been. (The measured 24 GB pre-build estimate for nine tiles is shelved; the prebuild tool stays for tests.)

What this means for the low tier (8 GB RAM, SATA drive) *[Practice]*:
- **Small install, growing cache.** Only the game and a small starter set ship; the rest is cached on first visit. First visits to new ground are the slow moments, so the server's background builder around each player and the ground-under-the-player priority matter most there.
- **Cache size limit.** Keep the existing client cache cap (2 GB now) as a setting. Suggested defaults: Low 1 GB, Mid 4 GB, High 10 GB. When full, drop the least recently visited blocks first.
- **A clear-cache button** in settings, with the current cache size shown, so a player can free disk without reinstalling. Nothing is lost: the ground is rebuilt or re-sent when visited again.
- **Hard drives:** write the cache in large batches off the main thread, so saving never causes hitches.

## 8. Progress

- **Done (build 14):** quality presets Low, Medium, High, Ultra (F2 or `--quality=N` in the client). They set ground view distance (768, 1280, 2048, 2048 m), tree/shrub/plant draw distance (40%, 70%, 100%, 100%) and shadow distance (none, 60, 100, 250 m). *[Measured, headless]* Low loads about 18% fewer ground blocks in the same walk (9,784 against 11,924). Real frame rates still need real machines.
- **Done (build 14):** the on-screen readout shows frames per second, average and worst frame time over the last 120 frames, quality name and game memory.
- **Done (build 14):** the client cache limit follows the preset (1, 4, 10 GB) and the oldest, farthest places are dropped first; `--clear-cache` wipes it at start.
- **Done (build 15):** ground detail comes from a cheap noise shader (no textures to load); fine detail fades out with distance. Colors were converted to true display values and muted. Not seen on screen yet.
- **Not started:** real-machine measurement (needs a playtest), tree levels of detail and variants, an in-game clear-cache button.

## 9. Audio budget (first sounds built 2026-10-19: wind, footsteps, grass; under 1 MB of Ogg, at most 8 playing)

Audio needs its own budget, especially on the low tier *[Practice]*:
- **CPU:** mixing many sounds at once (wind, water, birds, footsteps, animals) costs processor time. Cap the number of sounds playing together (for example about 24 on Low, 48 on Mid, 96 on High) and drop the quietest or farthest first.
- **Memory:** short sounds stay in RAM; long ambient beds are streamed from disk, never fully loaded. Keep total loaded sound under a set size per tier (suggested 150 MB on Low).
- **Disk:** compressed formats (Ogg), streamed in the background, so a slow SATA drive never stalls the game. Sound adds to the install size, so it is part of the light-download goal.
- **Placement:** sounds are placed in space (direction and distance), which is what makes a sound stage believable; keep the position math cheap and only for nearby sources.
