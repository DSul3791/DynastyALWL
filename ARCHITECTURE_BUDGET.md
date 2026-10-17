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

| Tier | Example | Frame rate | Game memory | View distance | Notes |
|---|---|---|---|---|---|
| Low | Older laptop, integrated graphics | 30 fps steady | up to 4 GB | short, trees fade early | Fewer tree variants, no volumetric weather, simple water |
| Mid | 4-6 year old desktop, mid graphics card | 60 fps | up to 8 GB | medium | Full instancing, shadows near, nice water |
| High | Current graphics card | 60-144 fps | up to 16 GB | long | Best lighting, weather, water, extra detail |

The existing decision still holds: the client stays light enough for older computers. One quality setting should move all of these together.

## 5. Modeled and procedural assets

Owner art direction: Valheim or better, storybook look, heroic characters with a hint of cartoon, ultra-realistic water, weather and lighting.

- **Procedural stays for** where things go, size, age, season color and small variation, because it is cheap to store and send.
- **Modeled assets for** the look: hand-made tree, plant, building and character models, several per species, each with 3 or 4 detail levels. Procedural code then picks the model, scale, tilt and tint.
- **Water, weather and lighting** are mostly GPU shader work, so they cost frame time, not data. Budget them by quality tier.
- **Characters** get the largest triangle budget per object but there are few on screen; keep them separate from the thousands of trees.
- Keep a triangle and texture budget per category and check new art against it before accepting it.

## 6. Most valuable next steps, in order

1. **Real-hardware measurement at the playtest.** Frame time split (CPU vs GPU), memory, and load times on at least one low and one mid machine. Everything above is a target until then.
2. **Tree levels of detail and variants.** Biggest GPU and memory lever; set the model and detail-level format before any art is made.
3. **A quality setting and per-tier budgets in code** (view distance, flora density, shadow and water quality) so one slider scales the game.
4. **Pre-build coarse ground for the nine starter tiles**, with full detail near the town (*[Measured]* about 9 hours and 24 GB for coarse levels; full detail costs far more, about 2-5 hours and 6-12 GB per tile), so players never wait on the server.
5. **Frame-time and memory readout in the game HUD**, so every later change shows its cost right away.
