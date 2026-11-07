# Water runtime inventory (M0)

**Written:** 7 Nov 2026 by Sonny. **Required by:** the guide, section 23 (`docs/water/Sullivans_Guide_to_Better_Water_in_Godot_Edition_3.md`).

The guide says no water integration code is written until this file exists. Every fact below comes from the repo, with its file and line. Runtime facts need the engine on Dave's PC. Those rows say **NOT RUN** until Dino runs the probes in the last section; nothing here is called verified before that.

## 1. Engine and Voxel Tools

| Fact | Value | Source | Status |
|---|---|---|---|
| Engine | Godot 4.7 features, Forward Plus | `project.godot` line 22 (`config/features`) | from repo |
| Voxel Tools | Built into the engine as a custom module build, not a GDExtension. The Linux headless build is `godot-4.7.2-voxel1.7-linux-headless`. | `tools/build_godot_linux.sh`, `/mnt/project-files/engine/` | from repo |
| Exact `--version` output | `Godot Engine v4.7.2.stable.custom_build.ed1daf0bf` (2026-08-17) | probe P1, David4 headless, 7 Nov 2026 | **PASS** (the binary path on Dave's PC is still to come from Dino) |
| Voxel Tools version string and commit | Voxel Tools 1.7.0 as a module, git 2ac9f5f8. `VoxelLodTerrain` and `VoxelTool` exist, with `do_sphere`, `get_voxel_f`, `raycast`, `set_voxel_f`, `paste` and `do_box`. | probe P2, David4 headless, 7 Nov 2026 | **PASS** |
| Other native code | `addons/water_core` is a GDExtension used by the current water (src/water2). It is separate from Voxel Tools. | `addons/water_core/water_core.gdextension` | from repo |

## 2. Terrain node

| Fact | Value | Source |
|---|---|---|
| Node class | `VoxelLodTerrain`, created in code, not in a scene | `scenes/terrain_client/terrain_client.gd:1080` |
| Mesher | `VoxelMesherTransvoxel`, `TEXTURES_SINGLE_S4` | `terrain_client.gd:1083-1085` |
| Generator and stream | No generator on the client. The ground comes from the server through `NetworkVoxelStream` (`src/stream/network_voxel_stream.gd`), with a disk cache. | `terrain_client.gd:1065-1082` |
| LODs, view distance, mesh block | `lod_count` 7, `view_distance` 2048, `mesh_block_size` 32, `collision_lod_count` 4 | `terrain_client.gd:151, 181, 1086-1095` |
| Format | SDF 16 bit; rock, soil, resource and material channels are 8 bit each | `src/worldgen/runtime/terrain_layout.gd:66-73` |
| Units and axes | metres, Y up, X/Z ground. The world is about 54 km across, so the spawn sits near x 53296, z 68080. | `src/shared/spawn_point.gd` |
| Transform and scale | The terrain node is not moved or scaled in code, and every caller assumes scale 1. Probe P3 confirms it (**NOT RUN**). | `terrain_client.gd:1080-1100` |

## 3. SDF convention

| Fact | Value | Source | Status |
|---|---|---|---|
| Sign | Negative is solid and positive is air ("above 0 is open") | `terrain_layout.gd:7`, `terrain_client.gd` dig log line | from repo |
| Zero crossing is the ground surface | assumed | needs probe P4 (one known solid point, one known air point, one surface crossing) | **NOT RUN** |
| Edited data or generator data | The client reads streamed, edited blocks. The server keeps the edits in `server_block_store.gd`. | `src/stream/server_block_store.gd` | from repo |

## 4. Terrain edits

- **Authority is the server.** A dig request arrives at `terrain_server.gd:1569` (`_on_dig_requested`). `_dig_ground` calls `store.dig_sphere(center, radius)` (`server_block_store.gd:529`). That bumps a revision per tile (`revision_of`, line 285) and announces `tile_changed` to the clients.
- **Clients** apply the same sphere locally with `VoxelTool.do_sphere`, using `MODE_REMOVE` for a dig and `MODE_ADD` for a fill (`terrain_client.gd:1625-1662`).
- **The water is told** through `water_live.dig(center, radius)` (`terrain_server.gd:1893`). The current water does nothing with it: `water_hub2.gd:102` is `pass`, with the comment "digs and fills do not reach the field yet". **Today a dug ditch never changes where water flows.** This is the gap the guide's terrain adapter and edit transaction (sections 17, 24 and 25) close.
- **The terrain revision** exists per tile (`store.revision_of`). That is the revision the guide's `hydraulic_geometry_committed` event should carry.
- **Thread ownership:** edits run on the main thread on the server. A full audit is part of M3.

## 5. Rendering and physics

| Fact | Value | Source |
|---|---|---|
| Renderer | Forward Plus | `project.godot:22` |
| Physics | Jolt Physics, default tick (60 Hz, not set in `project.godot`) | `project.godot:40` |
| Target platforms | Windows (Dave's PC, the game), Linux headless (server and tests) | `tools/` |

## 6. Water that exists today (what the guide replaces or keeps)

- **`src/water2`** is the current live water. It uses the local inertial shallow water scheme (Bates 2010) on 8 m cells, with sleeping 16 x 16 blocks. It stores depth in float32 and flux, with no per-face crests and no ledger. `liquid_surface.gd` draws it. The baked rivers come from `src/worldgen/tile/drainage_*.gd` and `tile_valley_drain.gd`.
- **`src/water`** is the older hub. It is kept behind `--water-old`.
- The guide's freshwater model differs from both. It stores volume in m³ as float64, has paired faces with crests, scales a cell's outflows together, and keeps a ledger. Per the guide (section 12: "build a separate demonstration scene before integrating"), the new code lives in **`src/sullivan_water/`** next to the old code, and replaces it only once its gates pass.

## 7. Probes for Dino (Dave's PC)

Each probe is reported as PASS, FAIL or NOT RUN, together with its output.

- **P1:** `godot --version`, plus the full path of the executable that opens this project.
- **P2:** `ClassDB.class_exists("VoxelLodTerrain")`, `ClassDB.class_exists("VoxelTool")`, and `ClassDB.class_get_method_list("VoxelTool")` filtered to `do_sphere`, `get_voxel_f`, `raycast`, `set_voxel_f`, `paste`, and `do_box`. Also report the Voxel Tools version, if the build exposes it.
- **P3:** in a running client, report `terrain.global_transform` and `terrain.scale`.
- **P4:** in a running client at the spawn, use `get_voxel_tool()` with `channel = CHANNEL_SDF` and call `get_voxel_f`:
  - 5 m under the ground, which should be negative;
  - 5 m above it, which should be positive;
  - in 0.25 m steps through the surface, to find where the sign changes compared with the collision ground height.
- **M1 gate:** `godot --headless --path . --script res://src/worldgen/tools/test_sullivan_water_grid.gd`, with the full output.
