# Rendering best-practice audit (Technical direction, 2026-10-20, build 112)

Trigger: Dave's RTX 2060 Super shows gpu 24 to 28 ms at High, and 11 to 12 ms even when looking at nothing but sky. Cloud cannot render real frames, so this is a code audit against Godot's own documentation plus a measurement tool for Dave's machine (F8). Numbers below marked "unmeasured" are expectations, not results.

## What I found, biggest first
1. **The 3D picture was 4.7 megapixels.** `project.godot` set the window to 2880x1620 (2.25 times 1080p) and Dave runs it that way. Godot's own scaling page: the cost grows with pixels and "halving the resolution scale factor will reduce the number of rendered megapixels per frame by a factor of 4"; it also says scaling is most useful when the scene is GPU-bound. Sky at 4.7 MP explains the 11 ms of pure sky. **Fixed:** 3D renders at a per-tier pixel budget (Low 1.0 MP, Medium and High 2.1 MP, Ultra 3.7 MP) and is upscaled with FSR 1.0, menus and text stay sharp at window size; the default window is 1920x1080 (`window_width_override`, keeps the UI proportions). Expected: High at 2880x1620 drops from 4.7 to 2.1 MP, so every per-pixel cost (sky, SSAO, TAA, glow, grass overdraw) falls by about 55 percent (unmeasured).
2. **Four shadow cascades at every tier.** Godot's directional light defaults to 4 PSSM splits; each split draws the shadow casters again, and trees cast shadows. **Fixed:** 2 splits at Low/Medium/High (4 only at Ultra), 2048 shadow atlas at Medium. Unmeasured; the F8 probe's "sun shadows off" line shows the remaining cost.
3. **Full-window sky shader.** The cloud sky runs 3 to 5 noise octaves plus light samples per visible sky pixel (`sky_clouds.gd`). Fixed indirectly by item 1; the new F8 step "sky clouds at Low quality" shows its remaining cost. If still large, Art direction should drop to a cheaper cloud model (precomputed noise texture instead of per-pixel noise).
4. **Direct3D 12 driver is forced** (`rendering_device/driver.windows="d3d12"` in project.godot). Godot's Windows default is Vulkan; D3D12 is the newer, less proven backend. I could not find a trustworthy benchmark either way (searches returned only a forum question with no replies), so this is a test, not a fix: run once with `--rendering-driver vulkan` and compare the F8 table. The HUD and probe now print the driver name.
5. **Embedded game view in the editor.** Dave runs the game inside the editor's Game tab: the editor draws on the same GPU at the same time. Not measurable from here; compare against running the game standalone (embedding off, or the launcher) with the same F8 table.
6. **Things already conventional (no change):** foliage and grass use alpha scissor (`discard`), not alpha blending (Godot's guidance: as few transparent objects as possible; blended materials cannot be sorted by material); grass casts no shadow; one MultiMesh per species/cell with custom AABB and per-species `visibility_range_end`; trees use MultiMesh (the docs' recommended way for thousands of identical objects); tone mapping and sky ambient are near free; SSAO is half size by default.
7. **Open items for the Art thread (their area):** impostors or billboards for far trees (docs: a single transparent quad per distant tree via visibility ranges), mesh LOD per tree crown, occlusion culling occluders (none yet), SSAO/TAA/glow only from Medium/High (as designed).

## Per-tier settings now
| Tier | 3D pixel budget | Shadows | Cascades | Shadow map | AA | SSAO | Glow |
|---|---|---|---|---|---|---|---|
| Low | 1.0 MP | none | n/a | n/a | FXAA | off | off |
| Medium | 2.1 MP | 45 m (build 164) | 2 | 2048 | TAA | on | off |
| High | 2.1 MP | 100 m (trees cast to 60 m from build 164) | 2 | 4096 | TAA | on | on |
| Ultra | 3.7 MP | 120 m (build 164) | 4 | 4096 | TAA | on | on |

## What Dave should do (measured results decide the rest)
1. Pull, run, press Ctrl+Shift+G at the spawn (or Esc > Advanced > GPU breakdown; F8 stops the game in the Godot editor) and send the table (it also lists graphics card, driver, window, scale).
2. Run it once more standalone and once with `--rendering-driver vulkan`; send both tables.

## Measured, Dave's machine (2026-10-20, build 157, High, embedded editor, 3D 1920x1080 in a 3816x1869 window, RTX 2060 Super, d3d12)
Everything on 20.0 ms (30 fps with vsync, CPU only 1.6 ms, 1157 draws, 16,131 flora drawn, 15,851 grass). Each row turns one thing off:
| Step | ms | Saves |
|---|---|---|
| trees, shrubs, plants off | 8.8 | **11.3** |
| sun shadows off | 13.8 | **6.2** |
| anti-aliasing off | 18.7 | 1.4 |
| SSAO off | 19.0 | 1.0 |
| glow off | 19.2 | 0.9 |
| sea off | 19.8 | 0.2 |
| fog off | 19.9 | 0.1 |
| grass off, ground off | 20.0 | about 0 |
| 3D at full window size (3816x1869) | 25.5 | -5.5 (so 1080p saves 5.5) |
Reading: the GPU is bound by flora (vegetation draw plus the shadows they cast), not by ground, water, grass or post effects. 20 ms is over the 16.7 ms of 60 fps and under 33 ms; the vsync lock shows 30 fps because the frame just misses 16.7. Target: High at 60 fps means about 11 ms saved from flora and shadows. CPU is not the problem.
Not yet seen: rows after "3D at half pixels" (cut off, ground thread fixing), standalone and Vulkan runs.

## Flora cost plan (decided 2026-10-20)
Owner: Art direction (flora view and impostors), with Ground adding probe rows. Order, one at a time, measure after each:
1. **Split the probe row** into trees, shrubs, plants and trees beyond 100 m / beyond 200 m, plus "tree shadows off" (Ground, small).
2. **Pull the impostor switch closer** (Art's IMPOSTOR_M table, High now 300 m): try High 180, Medium 150, Low 100, Ultra 250; keep the screenshot comparison per tier.
3. **Tree shadows only near**: trees beyond 60 m cast no shadow (Low none, as now); shrubs and plants cast none beyond 25 m.
4. **Cheaper crowns**: triangle budget per full-detail tree and a mid LOD between full and impostor.
5. **Shrub and plant draw distance** on High from 90/45 m down if the split row says they matter.
6. Merging crown meshes only if the draw count still dominates after 2 to 4.
Each step reports ms at High and Low from the same probe; a step stays only if it saves at least 1 ms with no visible pop in the screenshot pair.

## Sources
- Godot docs, Resolution scaling: https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html (fetched source text; scale factors, FSR 1.0 and 2.2, Forward+ requirement, "halving the scale factor ... factor of 4").
- Godot docs, 3D antialiasing: https://docs.godotengine.org/it/4.4/_sources/tutorials/3d/3d_antialiasing.rst.txt (FXAA cheapest, MSAA and TAA medium, FSR2 highest).
- Godot docs, Optimizing 3D performance: https://docs.godotengine.org/en/stable/_sources/tutorials/performance/optimizing_3d_performance.rst.txt (transparency, overdraw, MultiMesh, visibility ranges, impostors, occluders).

## Ultra table, Dave's RTX 2060 SUPER, 2026-10-20 23:46 (forest, looking at trees; 3816x1869, 3D scale 0.89, d3d12)
Everything on: 25.6 ms. Saved when off: trees 7.6, trees beyond 100 m 3.8, tree shadows 5.5, sun shadows 6.5, ground 1.6, SSAO 1.6, glow 1.3, AA 1.5, 3D at half pixels 4.3, grass 0.1, shrubs/plants/sea/fog/clouds about 0.
Caveat: the view was in a forest, so little grass was in view; the grass cost still has to be measured in an open meadow at Ultra and High (look along the ground). Trees and shadows are the cost, not grass.

## Dave's Ultra meadow table (2026-10-21 ~03:30, relayed by Art; RTX 2060 SUPER, 3816x1869 at 0.89 scale)
Everything on 27.2 ms. Off: grass 0.3 saved (98% short grass at 160 m reach costs ~0.3 ms at Ultra), trees 4.5, tree shadows 2.5, sun shadows 3.8, ground 2.2, SSAO 2.7, glow 1.9, AA 2.2; half the 3D pixels saves 5.5 (resolution bound). Forest view earlier: trees 7.6, tree shadows 5.5, sun shadows 6.5 (different view; the shadow proxy 301 looks effective). Still owed from Dave: under-crown table, run test, lake-shore check, dig test, High measure.

## Dave's second Ultra table, standing in tall grass (2026-10-21 ~03:35, via Art)
Everything on 29.0 ms; nothing saves more than 0.9 (grass 0.5, trees 0.9, tree shadows 0.8); half the 3D pixels saves only 0.8 (vs 5.5 in the meadow view). Conclusion: this frame is CPU bound. Build 350 adds CPU script ms, physics ms, draw calls, triangles to the probe table. Dave to retake in the same spot. Suspects: grass_view build queue while standing, retries of cells with no ground collision, 0.8 s rescans, flora apply_built, trample map.

## Dave's build-354 table (Ultra, meadow with trees, via Art 04:02)
CPU scripts 33.0 ms, physics 0.3, GPU 20.6, 30 fps. Grass off saves nothing; grass update 0.26 ms headless. The frame is SCRIPT bound by something else (suspects: new third-person ragdoll skeleton and held item/arms, inventory/Tab screen updates, sound, weather, flora apply_built, emitters). Build 355 adds script ms by piece to the probe table; Dave to retake. TOP PRIORITY for Art and Ground until named: 33 ms of script is over the 33 ms budget at 30 fps on his 2060 SUPER, far over on the minimum machine.

## Low-tier draw-call audit (Ground, 2026-10-21 05:27, headless scene-tree count at spawn 53233,68416)
About 970 MultiMesh/mesh nodes, 27k instances, ~1000 draw calls before terrain. Top sources: 1) grass cells 394 MultiMeshes for 19.3k cards (49 cards a draw, ~6-7 layers x ~56 cells); 2-4) flora chunks (208,267) 223 MMs for 3.4k instances, (207,267) 206, (208,266)/(207,266) 45 and 41; 5) shadow-casting MMs (28, off at Low) and 45 voxel block meshes. Pattern: splitting per chunk x species x LOD and per grass cell x layer leaves 15-50 instances per draw. Fix plan: (a) grass: one MultiMesh per layer per 2x2 cells (4x4 at Low), Ground with Art's grass_view.gd; (b) flora: one MultiMesh per species/LOD across neighbouring chunks, Art's flora_view.gd. Target: halve draw calls at Low, no popping, guards pass. Measure draw calls before and after with the probe table.

## After grass 347 and flora 387 (Ground, 2026-10-21 13:04, headless Low at spawn)
Visible nodes about 970 to 334 (flora chunk MMs 99+98, grass 64, voxel terrain blocks 45, 24 small static-body meshes to identify, flora misc 3). Physics step: trunk colliders 2933 at 160 m 1.99 ms, 1613 at 60 m 1.83 ms, 0 colliders 2.25 ms, collision_lod_count 4 1.70 ms vs 1 3.84 ms: colliders are NOT what the physics step costs (floor about 1-2 ms is engine voxel collision); no change. Tree LOD job 6 is done by Art (125, 166, 387).

## Willy 2026-10-21: the 33 ms "idle step" at Ultra is the wait for the GPU, not engine CPU work
Dave's build-445 Ultra table (RTX 2060 SUPER, 3816x1869, 3D 0.89): idle step 33.1 ms, timed script pieces 2.9, "untimed" 32.7, voxel main thread under 5 us, physics 0.3, but "everything on" GPU time 27.9 ms and 30 fps with vsync ON (default). A frame that takes 28 ms on the GPU misses the 16.7 ms vsync slot and snaps to 30 fps; the main thread then sits blocked in present/swapchain acquire, and the engine counts that block inside the idle step (33.1 ms is just 1/30 s). So "untimed" is mostly waiting, and Ultra at this resolution is GPU-bound. The rows that matter are the GPU savings: trees off 8.3 ms, sun shadows 5.4, tree shadows 4.6, 3D 0.71 scale 3.6, SSAO 1.0, fog 1.0 (shrubs, grass, plants, ground, sea cost nothing on the GPU). Scripts, voxel and physics are not the limit. To confirm: Esc > VSync off and read the table again; the idle step should fall to about the GPU time or below and fps rise above 30. Cuts belong to Art (tree and shadow cost): fewer cascade casters (trees in the far cascade), tree shadows only to 100 to 150 m, 3D scale 0.8 default at Ultra on a 4K window.
