# Sullivan's Guide to Better Water in Godot

**A prescriptive engineering standard for realistic oceans, rivers, dams, irrigation and editable terrain in Godot 4.7.2 with Voxel Tools 1.7**

**Edition:** 3.0 — November 6, 2026 (integrated implementation closure)  
**Audience:** game programmers, technical artists, Godot/GDExtension developers, and AI coding agents  
**Scope:** reusable across games, including voxel-based and open-world games  
**Target runtime:** Godot **4.7.2** and **Voxel Tools 1.7** (custom engine module preferred; extension requires separate compatibility validation)  
**Companion artifact:** this Edition 3 package, with the Edition 1 prototype, updated code examples, a Voxel Tools edit bridge and implementation checklists

> **Prime directive:** Simulate water accurately where the player can change its **consequences**. Fake the expensive microscopic details of its **appearance**. Never let those two representations disagree where characters or gameplay interact.

> **Honest status:** This is a development specification with an illustrative, testable starter implementation, **not a finished, experimentally verified Godot plugin**. The accompanying scripts were inspected and are accompanied by smoke tests, but Godot was not installed in the document-generation environment, so engine execution and performance are **unverified**. The rules marked **MUST** are acceptance requirements; the numbers marked **starting value** must be tuned and benchmarked.

---

## Locked implementation target — do not silently upgrade or substitute

- **Engine:** Godot **4.7.2**. The official upstream version and the Zylann Voxel Tools **4.7.2 custom engine build** are separate binaries. Confirm which executable launches the project before compiling or importing anything. Do not assume that loading a normal Godot editor supplies the built-in voxel module.
- **Voxel terrain:** Zylann **Voxel Tools 1.7**, using `VoxelLodTerrain` and smooth SDF (`VoxelMesherTransvoxel`, `VoxelBuffer.CHANNEL_SDF`) for the documented reference integration. Blocky terrain is an alternative adapter and must not be quietly mixed into the SDF implementation.
- **Distribution:** Prefer the corresponding **custom engine module build** when available. The project's 1.7 GDExtension release is a separate option; its release notes explicitly warn of reduced testing relative to module builds. Verify binary and export-template compatibility before switching.
- **Coordinate contract:** Godot world units are meters, Y up, X/Z ground plane. Require uniform scale = 1 on the reference voxel terrain and root until the transform adapter has tested scaling/rotation. `VoxelTool` edit positions are **terrain-local voxel coordinates**, not automatically world coordinates.
- **Stated status:** the included GDScript is illustrative/prototype code inspected for design consistency, **not** production-verified or executed in the target Godot/Voxel Tools runtime. Every new API call must be confirmed against the installed 1.7 build and exercised in an engine smoke test.

Official sources: [Godot 4.7.2 release](https://godotengine.org/article/maintenance-release-godot-4-7-2/), [Voxel Tools 1.7 release](https://github.com/Zylann/godot_voxel/releases), [VoxelTool API](https://github.com/Zylann/godot_voxel/blob/master/doc/source/api/VoxelTool.md), [Voxel scripting](https://github.com/Zylann/godot_voxel/blob/master/doc/source/scripting.md), [Voxel performance](https://github.com/Zylann/godot_voxel/blob/master/doc/source/performance.md). **GitHub master documentation may differ from the installed 1.7 tag:** the engine class database and installed source are authoritative.

---

## 0. Executive decision — what to build and why

Build **three independent modules sharing one interface**:

1. **OceanWater:** deterministic, GPU-rendered multi-frequency displacement waves with matching CPU wave-height queries, weather-scaled wave states, and separately rendered coastal detail. Start with four directional vertical displacement components (the supplied starter); improve to 3–6 Gerstner components if the visual payoff warrants the complexity. Do **not** start with FFT or full ocean physics.
2. **FreshWater:** conservative, active-region **2D cell/virtual-pipe** flow over a bed-elevation representation. Each link between cells carries a volume of water, allocated once and applied to both cells. This supports lakes filling, ditches, diverted streams, overtopping and dams. Use chunk-boundary bookkeeping when scaling beyond the starter. Do **not** start with particle fluids, a global 3D Navier–Stokes model or a visually animated river pretending to flow.
3. **WaterService:** provides water height, bottom, flow, normal, occupancy, body identifier and confidence/quality to swimmers, props, boats, sound, AI and effects. Never let each subsystem invent its own water level.

**Why this combination?** Surface/ocean visuals need fast, rich shading; terrain deformation needs water **volume and connectivity**. A texture cannot fill a player-dug channel. A particle fluid is unnecessary for a long stream. A conservative head-driven solver captures the gameplay effect of changing terrain at manageable cost. See the practical audit (`Godot_Water_823_Finding_Practicality_Audit.md`) and the original 10 volumes for deeper alternatives; they are background research, *not* 823 required features.

**Failure criterion:** if the system can paint gorgeous rivers but cannot accumulate water behind a dam and redirect it through a dug ditch while conserving mass, the freshwater architecture has failed even if its screenshot looks convincing.

### What the selected model does **not** claim

- The starter's head-difference orifice flow is **not** a complete shallow-water momentum solver, and its currents/dam-break timing are approximate. For better flood wavefronts or momentum, upgrade the **flow solver**, not the whole rendering stack.
- A single height per column cannot represent an aqueduct over a lower stream, flooded cave under a dry roof, or sealed pressurized pipe. Support these using **separate volume layers/connected water-body nodes** only where needed.
- No promise of arbitrary world size or fixed frame budget without benchmarks on target hardware.
- Voxel Tools is not the only supported terrain backend: adapters isolate engine/plugin specifics.

---

## 1. Scope and non-negotiable standards

### Features to deliver

**Essential freshwater:** believable directed flow, terrain-aware path selection, water volume conservation, persistent upstream ponding, overflow, drainage, editable dam/ditch/canal interaction, dynamically wetting shorelines, springs/rain source terms, closed and open boundaries, saving, region activation, and swimmer-current queries.

**Essential ocean:** ocean-scale apparent continuity, nonrepeating multi-scale wave pattern, wind and weather response, matching CPU and GPU wave heights, buoyancy and character bobbing, plausible horizon lighting, coast-safe wave attenuation, foam/surf and underwater transition.

**Shared:** stable API, consistent world coordinate conventions, unified time, water-material parameter conventions, debug instrumentation, save/load specification, low-complexity fallback renderers, regression suite and performance measurement.

### Explicitly optional

FFT ocean, true horizontal Gerstner displacement, advanced shallow-water Riemann solvers, continuous full sediment physics, 3D cave fluid, pressure transients, wave-wave coupling, high-fidelity ice fracture, groundwater PDE and volumetric bubble microphysics. Add these **only** when an actual gameplay/visual test proves the simpler solution inadequate.

### Mandatory units and conventions

| Quantity | Canonical representation |
|---|---|
| World position | Godot `Vector3` in metres; **Y is up**, X/Z horizontal |
| Bed / water surface | World-space Y in metres |
| Cell area | `cell_size_m * cell_size_m`, square metres |
| Water inventory | **Cubic metres** per cell, not `depth` when storing conserved state |
| Water depth | `volume_m3 / wet_area_m2` for simple cells |
| Flow between cells | Signed cubic metres transferred **per simulation step**; discharge is m³/s |
| Horizontal velocity | Vector3(m/s, 0, m/s) |
| Time | Seconds from one centralized simulation clock |
| Sea level | World-space Y; do not assume Y=0 |
| Terrain modification | World-space region bounds + terrain version/revision |

**MUST:** compare like units. A common agent failure is to add `flow_rate_m3_per_s` directly into `water_depth_m` without multiplying by `delta_seconds` and dividing by area. Another is to confuse `x/z` grid coordinates with `x/y` texture coordinates.

---

## 2. Reference architecture and file ownership

```text
WaterRoot (Node3D)
  WaterService             # authoritative query routing and time
  WaterWeather             # global/local wind, rain, storms, tide
  Oceans                   # one or multiple OceanWater bodies
  FreshWaterWorld          # authoritative water inventory and flow
    Regions                # runtime cell chunks (later implementation)
    Sources                # rain, springs, river inlets, pumps
    Sinks                  # drains, evaporation, outlets, irrigation use
    WaterConnections       # culverts, narrow channels, stacked water links
  WaterRenderWorld         # water meshes, foam, shore, falls, underwater
  WaterDebug               # inspection and accounting overlay
  WaterSaveManager         # versioned persistent state
```

**Strict ownership:**

- **FreshWaterWorld** owns freshwater volume and all exchanges; shaders, splashes, farms and player scripts MUST NOT mutate cell volumes directly.
- **OceanWater** owns wave definitions and simulation clock input; swimmers MUST NOT use a different wave approximation from rendering.
- **TerrainAdapter** owns the conversion from arbitrary voxel/mesh terrain into water-relevant bed/face barrier geometry.
- **WaterService** routes sampling requests. It must distinguish an ocean surface, a river cell, multiple stacked layers and **no water**.
- **Renderer** is a *consumer* of water state, never the source of truth for flow.

### Suggested reusable project layout

```text
res://addons/sullivan_water/
  core/water_service.gd
  core/water_sample.gd
  core/water_weather.gd
  ocean/ocean_water.gd
  ocean/ocean_baseline.gdshader
  freshwater/water_grid_2d.gd
  freshwater/freshwater_world.gd
  freshwater/terrain_adapter.gd
  freshwater/chunk_flux_ledger.gd
  freshwater/water_sources.gd
  render/water_surface_mesher.gd
  render/river_surface.gdshader
  interaction/water_buoyancy.gd
  tests/test_water_grid.gd
  tests/test_water_world.gd
  README.md
```

The zip ships baseline equivalents for `ocean_water`, `ocean_baseline`, `water_grid_2d` and `test_water_grid`; other paths are the production **architecture target**, not fabricated completed files.

### Canonical query contract

```gdscript
# Specification — implement as a typed WaterSample Resource or data object.
class_name WaterSample
extends RefCounted

var found: bool = false
var body_id: int = -1
var surface_y: float = 0.0
var bottom_y: float = 0.0
var depth_m: float = 0.0
var normal: Vector3 = Vector3.UP
var velocity_mps: Vector3 = Vector3.ZERO
var underwater: bool = false
var foam: float = 0.0
var turbidity: float = 0.0
var quality: int = 0 # e.g., 0=absent, 1=approximate, 2=authoritative
```

**WaterService.sample(position, t)** must specify whether the caller wants `nearest_surface`, `submerged_volume`, or `water_under_point`. A naive `max(surface height)` across every body is incorrect at bridges, aqueducts, rivers above caves, and coasts. If bodies overlap, route by **3D membership + priorities**; water height alone cannot disambiguate enclosed volumes.

---

## 3. Build the freshwater simulation first: the hardest irreversible decision

### 3.1 Choose the **virtual-pipe/cell volume** model

In the baseline:

- Partition traversable terrain into square **columns** on XZ.
- Each cell stores **bed elevation**, **water volume**, and optionally terrain face crest/barrier elevations.
- Every shared east/south face is evaluated once. The sign records direction; the receiving cell receives precisely what the donor loses.
- Proposed outflows are allocated **together** so total leaving a cell never exceeds its inventory.
- A cell with no water cannot send water. A dry receiving cell can become wet if its sill is below the upstream surface.
- During runtime, the water surface is derived from bed elevation + stored volume / area; only an approximate representation of submerged geometry is used.

This is a good default for open-air rivers and irrigation. It is **not** a justification to simulate water as free-floating particles or to advance per voxel.

#### Example governing quantities

For cell `i`:

`h_i = max(0, V_i / A_i)`  (water depth, metres)

`eta_i = z_bed_i + h_i`  (free-surface height, metres)

For a face joining cells `i,j`, let `sill = max(bed_i, bed_j, built_barrier_crest)`.

`head = eta_i - eta_j`.

A deliberately approximate baseline discharge is:

`Q_ij = C * face_width * max(0, eta_upstream - sill) * sqrt(2*g*abs(head)) * sign(head)`

`transfer_ij = Q_ij * dt`  in m³.

**Caution:** this orifice-inspired formula is a *game approximation*; it is not a universal treatment of open channels, broad-crested weirs, critical flow, momentum or a flooded culvert. It can yield unrealistic rates at complex hydraulic controls. Limit water by collectively available inventory; if the game demands realistic discharge, select and calibrate an appropriate weir/channel relation or a finite-volume shallow-water solver for that component.

### 3.2 The transaction algorithm is non-negotiable

```text
FIXED TICK:
  0. Apply authorized sources/sinks, recording ledger entries.
  1. Snapshot previous bed, volume, surface and barrier state.
  2. For each INTERNAL shared face exactly once:
       compute signed candidate transfer using the SNAPSHOT.
  3. For each source cell: sum all candidate outgoing transfers.
  4. If candidate outflow exceeds existing inventory, proportionally scale
     ALL that cell's outgoing transfers.
  5. Apply each face's equal-and-opposite deltas once.
  6. Commit new volumes simultaneously; check negative-depth violations.
  7. Recompute currents and wake/foam-driving fields from face flow.
  8. Record source, sink, outlet and storage ledger totals.
  9. Mark changed cells and neighboring chunks for rendering/activation.
```

**NEVER** update water volume during the first face scan and immediately use that updated value for the next neighbor. That introduces directional bias and potentially creates or loses water depending on iteration order. Never clamp individual outflows without accounting for other outbound faces.

### 3.3 The complete starter core

The companion `scripts/WaterGrid2D.gd` provides a complete reference **one-region closed-domain** implementation with:

- double-precision volume/bed arrays,
- paired east/south faces,
- a crest elevation for each face (dam/levee control),
- three-pass candidate/scale/settle updates,
- a coarse surface and velocity query,
- `set_bed`, `add_water`, `remove_water`, `total_volume`, and `step`.

The companion `tests/TestWaterGrid.gd` provides executable Godot smoke tests for **volume conservation**, **a newly cut crossing**, and **a blocked/unblocked dam**. **Run them before adding graphics or threading.**

**Why a smaller complete example rather than pretending to supply an enormous finished plugin?** It minimizes hidden assumptions. The transition from a single grid to production streaming is an actual engineering task; hiding it behind fictional APIs would create precisely the mistakes this guide intends to prevent.

### 3.4 Solver rate and stability

- Start at **10 updates/second**, fixed `dt=0.1s`, **2m cells**, with a visibly conservative flow coefficient. These are **test parameters**, not a promised optimum.
- Decouple mesh/shader render frequency from flow ticks. Interpolate visual surface height between authoritative snapshots; never interpolate **inventory** as simulation state.
- Use a **maximum substep `dt`**, accumulate elapsed time and limit the number of catch-up steps so a pause does not cause a giant unstable timestep.
- A head-based solver with explicit transfers can produce sloshing, excessive flood speed or grid-aligned artifacts. Inspect drained/filled test basins and adjust damping or upgrade momentum treatment. A water conservation check does **not** prove physically plausible flow.
- Debug a 16×16 grid before evaluating large regions. For baseline, keep GPU out of the critical hydraulic solver: debugging source/sink totals and voxel edits is easier in CPU code.

### 3.5 Add actual open boundaries (production)

The shipped starter has **sealed outer edges**. Production rivers often require open inflows/outflows. Do not solve that by deleting water at the screen edge or sleeping its last row.

Implement one **boundary link type** with clearly defined state:

| Type | Behaviour | Water-accounting rule |
|---|---|---|
| Solid | zero transfer | no source/sink |
| Fixed-stage reservoir | exchange against reservoir surface | count reservoir transfers |
| Fixed-discharge inlet | inject prescribed m³/s | count source |
| Free-draining outlet | export according to boundary rule | count sink/export |
| Adjacent active chunk | standard shared face | exactly one transfer globally |
| Dormant/persistent chunk | wake or use represented boundary reservoir | **do not discard** transfer |

Each chunk boundary face must be owned **once** globally (e.g. owner is lexicographically smaller chunk key). Export two signed quantities, `incoming_m3` and `outgoing_m3`, and settle both ends in one global update or transaction. The summed world inventory must satisfy:

`water_after = water_before + source_m3 - sink_m3 - exported_to_outside_m3`.

### 3.6 Dams and levees

Do **not** implement a dam as `river.speed = 0` or a decorative wall mesh.

A dam changes **terrain geometry or a face-crest elevation**, creating a higher sill. A reservoir accumulates upstream if inlet water keeps arriving. When upstream surface exceeds crest, water should flow over it. A dam removal lowers face crests, waking neighbors and releasing stored volume naturally.

Agent instructions:

1. Apply the terrain/built-structure edit to authoritative geometry.
2. Rebuild affected face crests or permeability (not every world cell).
3. Invalidate/wake the edited cell plus hydrologically connected neighbors.
4. Preserve upstream water inventory; do not zero it to “reset” the river.
5. Let flux transactions propagate the new flow.
6. Generate overtopping foam/spray visually from hydraulic drop and discharge.
7. Test partial openings, side bypass routes and removing sections of a dam.

If the player can make a dam from discrete blocks, treat blocked faces as raised crest/permeability barriers with explicit persistence; a mesh alone is not collision/hydrology state.

### 3.7 Ditches, irrigation canals and fields

A canal is not a spline telling water where to go. It is a **connected low-elevation route** whose inlet is hydraulically below a supply water surface.

After ditch excavation:

- Lower sampled bed/face sill in the affected cells; calculate newly passable links.
- Wake the channel route and water source boundary.
- Route water according to water-level difference, not just ground slope.
- If canal levels are **higher** than a field, it can gravity-feed the field. Otherwise it needs a powered pump, siphon or raised reservoir.
- A field stores **soil moisture**, not a full 3D fluid volume. Let `irrigation_intake_m3` be withdrawn from a canal cell; convert it into soil moisture through a capacity/infiltration rate. Excess can become runoff via a normal source term.

```text
withdrawn = min(cell_available_m3, intake_capacity_m3_per_s * dt)
soil_water += min(withdrawn, soil_storage_remaining)
return excess_to_runoff_if_any
record intake as a named transfer from surface-water ledger to soil-water ledger
```

**MUST:** farming must not simply ask whether water is within 10m and instantly mark a field irrigated. Test uphill canals, nearly dry canals, canals that split, and a shutoff gate.

### 3.8 Springs, ponds, lakes, rain and evaporation

- **Spring:** inject `flow_rate_m3_per_s * dt` into a designated cell or volume layer. Recharge may be a smooth weather/season multiplier. Record its source ID.
- **Lake/pond:** a set of connected low cells, not a fixed magic plane unless static lake water is an intentional cheap feature. Pond surface equalizes by flow as long as outlets permit.
- **Rain:** rainfall intensity `mm/hour -> metres/second`, multiplied by catchment area and a runoff fraction. Most rainfall infiltrates or is stored; direct surface flow can be simplified.
- **Evaporation:** small explicit sink; avoid removing more than the available cell inventory.
- **Reservoir or sea boundary:** explicitly specify whether the source is effectively infinite, finite or persistent. Infinite water has no conservation within the local simulated world, but is valid if counted as external import.

### 3.9 Flow driven by surface elevation, not always by ground elevation

This is a common coding mistake. Water moves toward **lower hydraulic head**. Ground can slope uphill across a small hump while a higher upstream water surface permits flow over it. Conversely, a ditch lower than a riverbed may remain dry if a ridge/wall blocks the connection.

A solver operating only on `terrain_height_difference` will fail dams, canals and equalizing reservoirs.

### 3.10 Vertical cavities and stacked water

A single `bed + depth` per XZ cell cannot describe caves and aqueducts correctly. Choose one of:

- **Unimportant flooded cave:** water volume trigger, predetermined level and animated surface (cheap).
- **Gameplay-relevant separated cavities:** construct a **graph of 3D compartments**, each with a `volume -> surface elevation` storage curve and links connecting at explicit elevations.
- **Aqueduct over river:** distinct compartment/layer with independent inventory and surface query. Transfer only through explicitly defined openings.
- **Pressurized pipe:** use a flow link with capacity and optional pressure approximation; do not force it into free-surface column flow.

Only connect cavities whose voxel geometry has an actual opening. A floor with a low ceiling does not automatically connect upward to an open lake above.

---

## 4. Voxel integration: what AI coding agents routinely get wrong

### 4.1 Use a terrain adapter; never call voxel data from the water core

```text
TerrainAdapter interface:
  sample_bed_height(world_x, world_z) -> elevation_m or UNKNOWN
  sample_face_opening(world_a, world_b) -> crest_m, width_m, occupancy
  on_terrain_changed(world_aabb, terrain_revision)
  is_region_loaded(chunk_key) -> bool
  request_region_load(chunk_key)
```

For simple heightfields the bed is the highest **relevant solid support surface below that water layer**, not necessarily the topmost rock at XZ. In a cave, topmost-rock height would incorrectly close the cavern or place its water above the roof. Use a separate compartment representation where overhangs/stacking matter.

Voxel Tools offers `VoxelLodTerrain`, `VoxelTerrain`, voxel editing utilities and runtime terrain streaming, but exact method names, coordinate transformation and change notifications **vary by installed version and data/mesher mode**. The guide intentionally keeps those details behind an adapter; inspect the installed Voxel Tools headers/docs before writing bridge code. Official documentation: https://voxel-tools.readthedocs.io/en/latest/ .

### 4.2 Mandatory edit sequence

```text
Player changes voxel terrain:
  1. Acquire validated edit request (authority; bounds; revision).
  2. Commit voxel operation through the terrain backend.
  3. Wait until authoritative voxel storage is updated (mesh redraw may lag).
  4. Expand changed AABB by >= one water cell on every horizontal side.
  5. Refresh relevant bed samples and face sills from voxel storage.
  6. Keep existing water inventories; do not initialize them to zero.
  7. Mark dependent cells, affected region faces, and neighboring chunks active.
  8. Resume water ticks; rebuild only dirty water render patches.
  9. Record terrain and water revisions together for save/multiplayer.
```

**If the player raises ground into a wet cell:** keeping the stored volume raises its water surface and pushes it toward available space over subsequent ticks. **If the player digs downward:** existing volume occupies more capacity, so the local surface may fall; adjacent water may flow in. Never invent new water merely because the terrain has been lowered.

**Face width matters:** A 0.5m irrigation ditch inside a 2m cell may disappear in a coarse bed sample. Represent narrow channels using an **explicit subgrid link** with opening width, sill and capacity rather than reducing the entire grid to 0.1m resolution.

### 4.3 Procedural river creation **before** runtime flow

A river that has no plausible bed is not rescued by a sophisticated solver. For procedural worlds:

1. Generate a terrain elevation model and identify high/low elevations.
2. Build watershed/drainage structure and find valid sea/lake outlets.
3. Resolve closed depressions intentionally: some are real lakes, others should drain or spill; avoid accidental isolated one-cell pits.
4. Accumulate upstream contributing area / runoff to identify perennial channels and smaller tributaries.
5. Route stream **centerlines** down valleys, rather than drawing arbitrary straight splines over flat ground.
6. Smooth the centerline within local terrain constraints; avoid forcing water to climb hills.
7. Carve a continuous profile with a generally downstream-falling bed. Include variable pools, riffles and width/depth tied to expected flow.
8. Widen bends and vary cross sections, materials and bank shapes. Do not create perfectly vertical rectangular trench walls everywhere.
9. Set headpond levels, overflow/outlet controls and spring feeds explicitly.
10. Generate terrain and water solver state from the **same geometry model**; verify outlets are open.

**Sizing:** there is no universal river depth. Use a game-scale discharge class (tiny creek, stream, river, large river), a planned width and flow, then fit bed depth and water surface to navigability and visual need. Do **not** hardcode every river at “3m deep”. Test downstream monotonic profile, width transitions, pools and lake outlets.

### 4.4 Prevent the random straight-cut edges

They usually result from one of four failures:

- Hard cut across a low-resolution chunk boundary.
- Missing active wet cells beyond the currently generated water mesh.
- Painting a rectangular water plane over a curving terrain edge.
- Simulated depth below visibility threshold while visual foam/shore geometry remains.

**Correction:** contour the wet/dry boundary from sampled water surface minus terrain bed, triangulate a shared-border mesh across chunk edges, keep neighbor halo values, rebuild edge vertices in matching world coordinates, add small opacity/foam feathering at shallow depth, and **do not** close an open river with a render tile edge.

**Never** use only the current tile's local coordinates to create shore vertices without consulting neighboring tiles: adjacent water mesh normals/positions will disagree and form cracks.

---

## 5. River renderer — visuals must be derived from water simulation

### Recommended layers

1. **Surface mesh:** terrain-following patch with smoothed water level. Sample coarse grid and use water level interpolation; clip to valid wet footprint.
2. **Near-shore border:** intersect interpolated water height against terrain; transparent shallow coloration and a thin foam/shore band.
3. **Flow normals:** two scrolling normal maps **advected in the direction of local current**, not globally to the east. Pack flow vector/velocity in an RG texture or vertex color.
4. **Foam:** driven by speed, falling-height drop, shallow contact and high gradient. Foam appearance/lifetime are shader and particle choices, not a second physical liquid simulation.
5. **Falls and rapids:** specialized local sheet meshes, flow-aligned spray and downstream ripples where water crosses steep elevation differences.
6. **Underwater:** consistent water color, depth-based visibility, fog and audio.

### Engineering note: a river is not a tilted plane

A long river surface must have **local** elevations. It may be higher upstream, with level pools behind a dam, currents accelerated in narrow sections and different banks in each region. Rendering a single flat plane or subtracting `length * slope` from a spline will visibly detach water from terrain after edits.

### Rendering update workflow

```text
FLOW TICK -> changed wet cells, heights, face rates
      |-> low-frequency CPU physics query cache
      |-> dirty mesh region ids, not rebuild entire river
      |-> flow texture upload (current direction/speed)
      |-> foam/spray event queue
GPU FRAME -> interpolate visual heights, animate normals,
             apply environment reflections, draw foam/spray
```

**Avoid GPU readback** for every character. Water-query values are already available in the CPU simulation; keep renderer state downstream of those values.

---

## 6. Oceans: make them look large and alive without simulating a real sea

### 6.1 Start with a reproducible, cheap wave basis

The supplied `OceanWater.gd` + `ocean_baseline.gdshader` use four directional vertical displacement waves:

`height(x,z,t) = sea_level + sum(A_i * sin(k_i * dot(direction_i, xz) - sqrt(g*k_i) * t))`.

From the same wave parameters compute:

`dheight/dx`, `dheight/dz`, and `normal = normalize((-dheight/dx, 1, -dheight/dz))`.

**Why start here?** Unlike full horizontal Gerstner displacement, height is a single-valued function of world X/Z; a physics query can exactly match vertex deformation at a given coordinate, which is excellent for debugging character bobbing. Once matched, optionally add horizontal Gerstner displacement and solve the reverse mapping from displaced X/Z to original parameter coordinates. Merely evaluating an unadjusted sine at the visible displaced position will produce a swimmer/boat mismatch.

**Important:** vertical waves have no true wave-driven water velocity or dynamic wave breaking. Use an approximate current field and foam masks for gameplay. For large storms and close-up ships, horizontal-displacement Gerstner or FFT may improve appearance and wave mechanics, but remain upgrades.

### 6.2 Exact setup for starter ocean scene

1. Add `OceanWater` (`Node3D`) with `OceanWater.gd`.
2. Add child `Surface` (`MeshInstance3D`) with subdivided `PlaneMesh` in local XZ; make it sufficiently dense for the largest wave frequency.
3. In `Surface.material_override`, create `ShaderMaterial` with `ocean_baseline.gdshader`.
4. Add a `WorldEnvironment` with sky/environment lighting; add `DirectionalLight3D`.
5. Set `OceanWater.follow_camera` to the active Camera3D. The supplied controller snaps the mesh under the camera to create apparent infinity, while the shader uses world X/Z so waves do not reset with camera motion.
6. Set `sea_level` explicitly and check `sample_height(world_x, world_z)` in debug against the rendered surface.
7. Tune only after synchronization passes. The mesh needs extra cull bounds due to shader deformation.
8. The baseline shader is intentionally **opaque and minimal**; it is a geometry/height correctness test, **not the final art shader**.

**Gotcha:** the four wave vectors in `OceanWater.gd` and shader defaults must always match. In production, set **all** wave parameters and shared time from one serialized wave-state resource every update or when weather changes; do not maintain hand-edited duplicates.

### 6.3 How to make the ocean convincingly realistic

After baseline matching, add the following in order:

**A. Two normal-map scales:** a broad directional detail plus smaller wind ripples; rotate/advect according to wind, vary UV frequency and speed so patterns don't repeat obviously.

**B. Fresnel reflection and roughness:** make grazing-angle water reflective; sample environment/sky, optionally use screen-space or planarly rendered reflections for important nearby objects. Prefer reasonable roughness variation to a chrome/mirror ocean.

**C. Depth-dependent absorption:** shallow water greener/clearer, deep water darker/bluer according to artistic extinction coefficients. Beer–Lambert approximation: `transmittance_rgb = exp(-absorption_rgb * optical_path_m)`. Use physically-inspired controls, not a large real-world optics simulation.

**D. Shore and surf:** gradually attenuate long wave amplitude in shallow water to prevent swells penetrating hills. Add shallow water crest foam and shore break geometry/particles near wave impact. A proper wetting foam line follows coast shape, not a global repeated texture.

**E. Spray:** emit sparse particles at actual impact/crest/boat events and from storm thresholds; random per-pixel glitter is not coherent spray.

**F. Weather:** interpolate amplitude, dominant directions, roughness, foam activity, spray and wind-ripple layers over several seconds or minutes of game time. Do **not** instantly change every wave's phase, which looks like the entire ocean teleporting.

**G. Large-world continuity:** camera-followed patches, radial LOD or projected grid, and consistent world-space wave UVs. Keep render mesh size/pixel density appropriate to screen footprint. Ensure far horizon uses the same ocean state and blends with sky/fog.

### 6.4 Godot rendering restrictions you must design around

Godot 4 uses `hint_screen_texture` and `hint_depth_texture`, not Godot 3's old `SCREEN_TEXTURE` and `DEPTH_TEXTURE`. Depth is **reverse-Z** in modern Godot; do not compare raw depth values as if 0 means near. Reconstruct view-space depth with `INV_PROJECTION_MATRIX` before comparing terrain and water distances. See the official shader references:

- https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html
- https://docs.godotengine.org/en/4.6/tutorials/shaders/screen-reading_shaders.html
- https://docs.godotengine.org/en/4.6/tutorials/shaders/advanced_postprocessing.html

**Critical limitation:** in the 3D pipeline the screen texture is captured before transparent surfaces; transparent props and particles may not appear in water screen-space refraction/reflection. Transparent water sorting and depth prepasses require explicit QA; an art shader that looks excellent over opaque rocks can fail behind glass, foliage and other transparent effects. Forward+ normal-roughness textures are not supported identically in Mobile/Compatibility rendering. Plan an explicit alternative path for lower renderers.

#### Optional depth thickness calculation (illustrative shader fragment)

```glsl
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
// In fragment():
float depth_value = textureLod(depth_texture, SCREEN_UV, 0.0).r;
vec4 scene_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_value, 1.0);
scene_view /= scene_view.w;
// In a normal Godot spatial fragment, VERTEX is the water fragment's view-space position.
float optical_thickness = max(0.0, -scene_view.z - (-VERTEX.z));
vec3 transmission = exp(-vec3(0.12, 0.045, 0.020) * optical_thickness);
```

This is a **starting depth-screen-space approximation**, not a robust underwater ray marcher. It must handle sky/background depth, objects rendered in front, reverse-Z correctness, clipping, and renderer-dependent projection. Use a debug view of `optical_thickness` before blending the final colors.

### 6.5 Weather and wave configuration

Suggested serialized parameters:

```text
OceanSeaState:
  sea_level_y
  wind_direction_xz
  wind_speed_mps
  swell_direction_xz
  swell_amplitude_m
  short_wave_amplitude_m
  short_wave_scale
  choppiness_01
  foam_threshold
  spray_threshold
  response_seconds
  tide_offset_m
```

Keep **wind-driven short waves** and slow **swell** as distinct controls. Wave phase must remain continuous during parameter changes; interpolation of frequency requires care because abruptly changing `k` changes spatial/temporal phase. A conservative upgrade is to fade between two persistent wave sets rather than retuning the current wave in place.

**Tides:** a simple sea-level offset + optional cyclic sine term is fine for ordinary games. If a river mouth is connected to a tidal ocean, represent its sea boundary as a time-varying **water stage**; do not only raise the ocean mesh while leaving the river's boundary static.

---

## 7. Interaction: swimmers, buoyancy, boats, currents and waves

### 7.1 Sample once; reuse the result

A character moving in water should receive the same water sample used for VFX and environment transitions. Query at physics steps; interpolate artwork. Different systems may use different LODs but not unrelated wave constants.

**Swimming:** apply movement relative to local water velocity, `relative_velocity = character_velocity - sampled_water_velocity`. If swimming upstream, player input acts against the current. Use horizontal flow for drift; approximate vertical turbulence as an occasional force/VFX near rapids, rather than making random water velocity everywhere.

**Near surface:** the body's flotation target tracks `sample.surface_y`. Add damping based on relative vertical velocity so the character bobs naturally without spring explosion.

### 7.2 A safe, simple buoyancy rule

For a small prop, estimate a submerged fraction `f` between 0 and 1 and calculate:

`buoyancy_force_y = water_density * g * displaced_volume_m3 * f`.

Apply a drag force on the object's motion relative to water. Use `RigidBody3D.apply_central_force` or `apply_force` **each physics frame**; do not repeatedly use an impulse as though it were a force. Godot reference: https://docs.godotengine.org/en/4.6/classes/class_rigidbody3d.html .

For boats use at least four sample points for roll/pitch stability, but do not multiply the **entire hull volume** by four at four points: each sample represents its share of the hull. Clamp and damp vertical forces; tune for mass, displacement volume and center of mass. Large vessels may require a more accurate hull sampling mesh later.

### 7.3 Character bobbing and drift failure checks

- Still water: character settles without vertical jitter.
- Waves: motion matches current visible crest/trough, no permanent offset.
- Rapids: drift direction agrees with current visualization.
- Exiting water: drag/buoyancy ceases cleanly, no lingering velocity lock.
- Crossing ocean/river boundary: avoid suddenly switching height/velocity discontinuously—blend query sources in a bounded transition region while keeping simulation authority explicit.

---

## 8. Integrating river water with oceans and lakes

### River mouth / estuary

- Freshwater outlet must connect to an ocean **stage boundary**, not a black hole that deletes water unpredictably.
- Ocean stage may move due to tides; low river gradient may temporarily slow or reverse near the mouth. A simple tide-dependent head link is usually enough.
- Blend water material color, wave scale, foam and turbidity across a visually plausible transition zone. The solver only needs consistent **exchange**, not full saltwater/ocean mixing.
- Avoid rendering a hard straight edge where two independent surface meshes overlap. Match coastline geometry, clip overlapping meshes and use a transition material.

### Big lakes

A lake with fixed geometry and no gameplay-relevant inflow/outflow can use a static level with small wind waves. A lake feeding or receiving player-redirected rivers must connect its inventory or reservoir node to the freshwater solver. Large lakes may reuse **ocean visual shaders** while their base elevation is owned by a freshwater reservoir.

### Waterfalls

Hydraulic effect: water crosses a steep bed step, and downstream receives the same transfer. Art effect: local waterfall sheet, particles, impact foam and underwater bubbles. The visual fall does **not** create or destroy water. No continuous 3D CFD is required.

---

## 9. Save/load, sleeping regions, large worlds and multiplayer

### Persist **authoritative** state, not rendered meshes

```text
WaterSaveHeader:
  format_version
  world_seed_or_world_id
  terrain_revision
  water_solver_version
  cell_size_m
  origin_world_xz
  simulation_tick
  boundary_condition_version

Per region:
  region_id, dimensions, cell elevations or terrain revision reference
  volume_m3 per cell
  barrier crest/permeability state
  source/sink settings
  external/neighbor flux backlog, if any
```

Store enough precision for the intended world scale. After load, recompute surfaces/meshes/flow caches; compare total volume ledger to pre-save snapshot. Do not save ocean wave vertex positions—save sea-state parameters plus synchronized wave clock/seed.

### Sleeping chunks correctly

A chunk may sleep if: all cells dry and disconnected from rising upstream flows, or water near rest with no active source/sink and no pending neighbor transfer. **Wake** when terrain changes, weather adds rain, upstream stage rises, an adjacent cell wets, a dam opens, or new water sources arrive.

**Never** sleep a chunk just because the player is far away while another chunk continues to send it water. Options:

1. Keep a coarse offscreen regional water budget and periodic updates.
2. Persist a boundary reservoir and accumulated transfers, then reconcile on load.
3. Keep a low-resolution global hydrological network that routes broad discharge across unloaded regions.

The correct choice depends on world size and persistence. A naive “unloaded = no water” rule creates impossible floods/drains after streaming.

### Determinism and server authority

For a multiplayer persistent game, make terrain edits and water transfers authoritative on the server. Do not replicate shader-level waves every frame; synchronize ocean seed/parameters/time. For freshwater, transmit dirty-region snapshots/deltas and authoritative volumes or quantized heights on a budget. Client visuals can interpolate. Exact floating-point bit-level determinism across CPU architectures is **not** guaranteed; fixed-point inventories are worth considering if deterministic rollback is a real requirement, but are not required for the initial prototype.

---

## 10. Production optimization and engineering escalation

### Practical budgets — proposed targets, not published benchmarks

- Small fresh-water prototype: 10 Hz, 2m cells, 16–32 cell tiles, inspect update cost.
- Target typical visible active simulation **~1–2ms** on intended hardware after profiling; allow spikes only with measured justification.
- Avoid rebuilding entire water meshes every flow tick. Keep dirty-region sets and mesh-update rate independent of solver rate.
- Water visual material may use multiple LODs and lower frequency far-field detail, not full tessellation to the horizon.
- C++/GDExtension is an optimization step **after** a correct CPU reference grid passes tests. The authoritative algorithm and test datasets must remain unchanged during the port.

### When to upgrade which part

| Observed failure | First corrective action | Advanced escalation |
|---|---|---|
| Water disappears at dam | Fix ledger and paired face settlement | Never hide bug with shader |
| Water oscillates in pond | Reduce dt/discharge, add stable damping | Well-balanced shallow-water solver |
| Narrow ditch invisible to solver | Explicit subgrid flow link/face geometry | Local fine grid |
| Slow across huge maps | Sleep/activate by hydrological dependency | Coarse global routing or GPU compute |
| Ocean looks too repetitive | More wave directions/frequencies, normal detail | FFT cascade if A/B test validates |
| Shoreline is rectangular | Wet/dry contour meshing, neighbor halos | Higher-res shore mesh |
| Boat looks disconnected from wave | Unify CPU/GPU phase and sample coordinates | Horizontal Gerstner inverse or GPU query |
| Cave flooding fails | Add compartment volumes and portals | Limited 3D fluid/pressure solver |
| Rapids look lifeless | Flow foam, waterfall sheets and particles | Local hybrid physics only if game needs it |

---

## 11. Mandatory validation suite: what must pass before integration

### A. Closed-volume conservation (first gate)

- A closed bowl with 10,000 m³ retains that volume over thousands of fixed steps within precision tolerance.
- Empty cells do not acquire negative depth; no cell creates water out of nothing.
- Two adjacent cells exchange equal/opposite amounts.
- Conservation remains true regardless of traversal ordering (same physical result within tolerance).
- Repeated save/load cycles preserve volume.

### B. Terrain response (second gate)

- Dig ditch: connected water enters and downstream channel becomes wet without scripted path.
- Lower a bed cell: local surface may drop while total volume remains unchanged.
- Raise an immersed bed: displaced water is retained/redistributed, not deleted.
- Ridge higher than surface blocks water even if the receiving valley is lower.
- Narrow passage works via subgrid link when smaller than cell width.

### C. Dam and spillway (third gate)

- Barrier creates backwater upstream, lower downstream delivery, and level rise with continued inflow.
- Overtopping begins when stage exceeds barrier crest; water flows to the other side.
- Removing barrier gives a transient surge **without instant global equalization**.
- A partial breach and alternate bypass behave as expected.
- Flow plus source/sink ledger reconciles exactly within tolerance.

### D. Chunking and persistence (fourth gate)

- Cross-chunk flow matches a same-sized monolithic grid with identical conditions.
- No duplicate or missing transfer across shared faces.
- Unload/reload a neighbor and confirm no inventory is lost.
- Terrain edits on chunk edges wake both sides.
- Streaming does not produce straight visual boundaries.

### E. Ocean rendering/physics (fifth gate)

- Water surface readback from **CPU mathematical query** agrees with shader wave at 50 randomized points and 20 time samples within chosen geometry tolerance.
- Moving camera-follow ocean mesh does not change wave phase at the same world point.
- Changing weather does not cause phase jumps or visible snapping.
- Underwater objects have no depth-inverted coloration on target renderer.
- Shore wave/foam transition follows actual coast, including changing tide.
- Multiple boats and swimmer profiles do not trigger GPU synchronous readbacks.

### F. Performance (sixth gate)

- Measure solver time, dirty mesh time, render GPU time, allocations and stutters **separately**.
- Test at least: idle lake, 20 active canals, rapid dam break, wet/dry shoreline, worst-case storm ocean, and fast player terrain edits.
- Benchmark on minimum supported hardware, not only developer PC.

**Definition of DONE:** every mandatory test has automated evidence (logs, frame captures, numerical assertions) and a recorded engine version/hardware configuration. “Looks okay in the editor” is not a pass.

---

## 12. Instructions to an AI coding agent (copy this into task briefs)

> Follow **Sullivan's Guide to Better Water in Godot** exactly unless the task explicitly changes a requirement. First inspect the project's Godot version, terrain backend, rendering method, coordinate system, water-relevant scenes/scripts, and existing data ownership. Do not invent Voxel Tools/GDExtension API names; consult the installed source headers. Build a separate demonstration scene before integrating the system. Water inventory must be stored in cubic metres, with paired face transactions and source/sink accounting. No water mesh, foam shader, character or crop script is allowed to change authoritative water volume directly. Water renderers must sample authoritative simulation. Keep ocean wave parameters/clock shared by GPU and CPU. Do not start GPU compute, FFT, advanced CFD, multiplayer or erosion before core correctness tests pass. Supply complete replacement code with exact `res://` paths and exact instructions for scene-node connections. Run parser, smoke tests, integration tests and a before/after performance capture; report tests NOT run and blockers. Never claim a feature works based only on successful parsing.

### Mandatory delivery format for coding work

```text
1. Files created/changed (absolute OS path + res:// path)
2. Why each file changed
3. Scene/node/material setup steps with exact node names
4. Authoritative water data owners
5. New public APIs with units and edge cases
6. How terrain edits propagate to flow and rendering
7. Tests run, exact results, failures, and tests NOT run
8. Performance before/after on named hardware
9. Known limitations and next incremental milestone
```

**Never accept:** an unexplained giant script that simultaneously owns water simulation, voxel edits, rendering, sound and physics; hardcoded terrain heights that do not update; water disappearing when cells unload; copied wave code that differs between CPU and shader; a “dam” made only of a blocking static mesh; a performance claim without a measured reproduction.

---

## 13. Step-by-step milestone plan

| Milestone | Deliverable | Acceptance gate |
|---|---|---|
| **M0** | Unmodified Godot 4 project, baseline starter tests | Scripts parse; smoke tests run |
| **M1** | Single-region conservative freshwater sandbox | 10k step volume ledger; dry/wet; stable pond |
| **M2** | Ditch/dam/spillway/irrigation sandbox | Edit, bypass, overflow, withdrawal tests |
| **M3** | Terrain adapter for actual voxel backend | Real edits update cells/crests without reset |
| **M4** | Production chunk seams and sleep/wake | Cross-region and unload/reload comparisons |
| **M5** | Ocean baseline, unified CPU/GPU waves | Height and normal cross-check |
| **M6** | Ocean/river optical quality pass | Shore, foam, refraction, weather, underwater QA |
| **M7** | Unified swimmers/boats, sources/sinks, lake mouths | Movement/volume consistency |
| **M8** | Save/load, multiplayer only if necessary, optimization | Worst-case profiles and regression suite |

This order intentionally proves *flow correctness* before committing time to advanced graphics. Ocean rendering may be developed in parallel because its mathematics and resource ownership are independent of river solver work.

---

## 14. Reference material and evidence quality

### Primary Godot APIs (verify against the exact installed engine)

1. [Godot 4.6 spatial shaders](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html) — built-in variables, transparency and render modes.
2. [Godot 4.6 screen-reading shaders](https://docs.godotengine.org/en/4.6/tutorials/shaders/screen-reading_shaders.html) — depth, screen capture and render restrictions.
3. [Godot 4.6 advanced postprocessing](https://docs.godotengine.org/en/4.6/tutorials/shaders/advanced_postprocessing.html) — reverse-Z and depth reconstruction.
4. [Godot SurfaceTool](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/surfacetool.html) — mesh construction, normals/tangents.
5. [Godot RigidBody3D](https://docs.godotengine.org/en/4.6/classes/class_rigidbody3d.html) — forces versus impulses.
6. [Godot GeometryInstance3D](https://docs.godotengine.org/en/4.5/classes/class_geometryinstance3d.html) — shader-displaced mesh culling margins.
7. [Voxel Tools documentation](https://voxel-tools.readthedocs.io/en/latest/) — terrain types, runtime editing and adapter integration.

### Selected practitioner and research references

- [Godot voxel-water implementation discussion (October 2026)](https://www.reddit.com/r/godot/comments/1x5bqei/in_honor_of_the_water_sim_trend_heres_mine_voxel/) — developer-reported implementation using columns/virtual pipes, multithreading and exact volume accounting. Claims need reproduction.
- [Water simulation methods for games: A comparison](https://www.researchgate.net/publication/266653134_Water_simulation_methods_for_games_A_comparison) — comparative research; do not overgeneralize it to every hydraulic case.
- [Godot compute shader shallow-water developer report](https://www.reddit.com/r/godot/comments/1vdi141/compute_shaders_are_awesome/) — Godot-specific implementation lessons and shoreline limitations.
- [BeachSandbox Godot implementation](https://github.com/kanaworksai-hue/beach-sandbox) — sample project and developer-reported benchmarks; small demo footprint and unverified transferability.
- **Research archive:** `Godot_Advanced_Water_Research_Volume_001.md` and `Godot_Water_Research_Volume_002...010.md`, plus the 823-item audit. These contain many optional techniques deliberately excluded from the production default.

### Evidence labels to preserve in future editions

- **Documented Godot behaviour:** linked to official engine documentation for an identified version.
- **Published engineering technique:** linked to identifiable implementation or research, possibly measured on different hardware.
- **Developer anecdote:** useful direction, but hardware/version/performance claims not verified independently.
- **Guide recommendation:** informed design choice; performance and quality are not guaranteed until project-specific acceptance tests pass.
- **Starter code:** runnable *candidate* that must be compiled/executed and benchmarked on the target engine.

---

## 15. One-page final coding standard

1. **Store freshwater as volume.** Do not store only a texture, particle count or untracked height.
2. **Transfer mass exactly once per face.** Limit collective outflow, add and subtract in paired operations.
3. **Route by hydraulic head and passable openings.** Not only by river spline direction or ground slope.
4. **Terrain edits update geometry, not water inventory.** Wake and recompute affected links.
5. **Chunk seams are solver connections, not boundaries.** Preserve volume across unloaded regions.
6. **Render from simulation, never simulate from the shader.** Hide grid scale with smooth meshes, flowmaps and foam.
7. **Ocean visuals use synchronized CPU/GPU wave equations and time.** Do not let bobbing diverge from visible waves.
8. **Fake tiny physics.** Foam, bubbles, spray, erosion and capillary ripples are artistic effects until gameplay demands more.
9. **Special-case complex water topology.** Stacked caves, aqueducts and pipes require compartments/links, not a single height column.
10. **Measure and test before sophistication.** Promote more advanced algorithms only after a reproducible failure or quality gain.

**Desired outcome:** a world where rivers are genuinely reroutable, dams fill and overflow, irrigation reaches fields only when water actually arrives, lakes and springs connect sensibly, ocean swells move swimmers/boats believably, and all the water looks beautiful without turning the game into an engineering-fluid laboratory.


---

# Part II — Godot 4.7.2 + Voxel Tools 1.7 integration contract

The following instructions are deliberately prescriptive. They replace vague suggestions such as “update water when the user digs” with a required data flow and failure policy. For each implementation milestone, Claude must cite the matching manual section and attach runtime test output. **Never mark a feature complete because it visually appears to work.**

## 16. Installation and runtime verification checklist

1. Record the executable path and output of `godot --version` (or the explicit absolute executable equivalent). The stock 4.7.2 editor and the Voxel Tools 1.7 custom engine build are **not identical**. The module build's own editor/export templates must be used to retain voxel classes on export. The extension variant requires installation in the project and an explicit export check.
2. In an empty reproduction project, instantiate the intended voxel terrain and assert `ClassDB.class_exists("VoxelLodTerrain")` and `ClassDB.class_exists("VoxelTool")`. If these fail, **STOP**. Do not implement fallback fake voxels in silence.
3. Verify the terrain node type (`VoxelLodTerrain` for this reference), generator, stream, viewer, mesher, SDF channel, data block size, editing range and collision settings in the inspector. Save a screenshot/scene diff of configuration.
4. Verify `get_voxel_tool()` returns a usable tool; set `channel = VoxelBuffer.CHANNEL_SDF` before accessing smooth terrain voxels; verify `is_area_editable(AABB(...))` on a loaded LOD0 area; do not edit beyond the loaded first LOD. Requesting nonloaded edits is **not** a valid water interaction.
5. Use a local fixed-point test with two known positions: world `(x,z)` -> `terrain.to_local(world_pos)` -> local voxel coordinates. Carve one small area and verify it changes at the expected visible world position. Do not proceed until this matches.
6. Verify whether the project is using Voxel Tools as an engine module or a GDExtension. If the extension, check the plugin's installed versions and any extra differences in API behavior; never assume module-only C++ facilities are available.
7. Keep an environment manifest with Godot full version/hash, Voxel Tools version/release/hash, renderer (Forward+/Mobile/Compatibility), graphics hardware, physics tick rate and large-world-coordinate setting. Tests are reproducible only with this information.

### Voxel Tools APIs to use and constraints to respect

The Voxel Tools `VoxelTool` interface documents `do_sphere(center, radius)`, `do_box(begin, end)`, `do_path(points, radii)`, `is_area_editable(box)`, `get_voxel_f(pos)`, `mode`, and `channel`. Smooth terrain normally uses `VoxelBuffer.CHANNEL_SDF`. `MODE_ADD` creates matter, `MODE_REMOVE` removes matter. Bulk operations are preferable to random per-voxel updates; `VoxelLodTerrain` only permits editing loaded LOD0 data. These claims are grounded in the plugin documentation, but the **installed build** is the ultimate API authority.

**Do not implement a raycast and claim it is the authoritative terrain bed.** Physics collision meshes may lag voxel edits or be unavailable for an unloaded chunk. For a first prototype, a physics raycast is acceptable as a visual sampling fallback *after collisions are rebuilt*; for simulation authority, implement an SDF-based bed/solid-fraction sampler from voxel data or a versioned cached height/barrier representation derived from SDF. Overhangs and tunnels require more than one height per column.

## 17. Required terrain-to-water update transaction

Implement one authoritative `TerrainWaterEditCoordinator` and require all player/building tools, explosions, erosion logic and world-gen amendments to go through it. The transaction is **not** a callback from whatever mesh changed last.

**Stage A — preflight**

1. Convert the world-space tool volume to terrain-local voxel-space AABB; add a halo at least one water cell plus an SDF extraction margin.
2. Check the area is editable. If any part is outside loaded LOD0, reject the edit with an explicit reason or queue it for when the region becomes editable. Never partially apply a bulk edit while telling gameplay it succeeded.
3. Mark affected water cells and adjoining edges. Record old per-cell bed area/face barriers and old water volumes. Snapshot/lock the affected cells and edge exchange ledger at the simulation tick barrier.

**Stage B — edit**

4. Apply a bulk VoxelTool operation in local coordinates. For a trench, use `MODE_REMOVE`; for a levee, use `MODE_ADD`. Check the installed tool has the selected operation; pass explicit radius and path samples. Do not perform thousands of `set_voxel_f` edits unless profiling establishes the need.
5. On successful modification, increment `terrain_revision` and enqueue an AABB invalidation event. Never infer completion from visual remeshing.
6. Update just the local **hydraulic representation** of the changed region: bottom elevation, approximate wettable area/capacity, and four lateral barrier elevations (`east/south` stored once per shared face). For irregular banks, extract face saddle/crest from more than one terrain sample; do not blindly set the crest equal to the lower cell's center bed.

**Stage C — reconcile**

7. If terrain is lowered: keep the old water volume, lower the bed, and recompute surface elevation. The newly carved cavity initially increases capacity; it is **not** instantly filled from nowhere. Water enters via later solver transfers.
8. If terrain is raised: keep old volume temporarily but mark displacement. If the new solid region displaces occupied water, transfer that displaced volume to reachable neighboring wet cells with capacity, over controlled substeps. If no physical destination exists, **reject the edit or record a named overflow/reservoir event**. Never delete the water silently or simply force the water plane upward through an impermeable roof.
9. Update face connectivity and any narrow-channel conductance. Rebuild graphics/physics on their own schedules. Hydraulics must use the new terrain revision immediately after the transaction commits, even if visuals lag.
10. Commit one terrain revision and one water-state revision, release cell/ledger lock, then publish an `affected_region_changed(bounds, revision)` notification. All consumers invalidate their caches from that event.
11. For multiplayer, server owns commit order and distributes terrain edit IDs and authoritative water-state corrections. Never let clients independently edit conserved water inventory.

**Fail conditions:** changed terrain but old hydraulic barriers; hydraulic update without successful voxel edit; inventory delta with no named source/sink or edge exchange; edit in noneditable LOD; sampler reading stale collision as if it were post-edit geometry.

## 18. Minimum Voxel Tools bridge: exact file and scope

**File:** `res://addons/sullivan_water/voxel/voxel_terrain_edit_bridge.gd`.

The package includes this script. It performs a **verified subset** of the full coordinator behavior: world-to-local conversion, bounding editability checks, bulk sphere edits, and a typed event. It intentionally does **not** claim to extract hydraulic bed data or do atomic multi-chunk commits; those must be implemented and tested in the coordinator before gameplay uses the bridge for production flooding.

```gdscript
class_name SullivanVoxelTerrainEditBridge
extends Node
signal terrain_edit_committed(local_bounds: AABB, revision: int)
@export var terrain: Node3D
var terrain_revision: int = 0

func edit_sphere_world(world_center: Vector3, radius_m: float, add_matter: bool) -> bool:
    if terrain == null or not terrain.has_method("get_voxel_tool") or radius_m <= 0.0:
        push_error("Missing Voxel Tools terrain or invalid edit radius")
        return false
    if not is_equal_approx(terrain.scale.x, 1.0) or not is_equal_approx(terrain.scale.y, 1.0) or not is_equal_approx(terrain.scale.z, 1.0):
        push_error("This reference bridge requires unit terrain scale")
        return false
    var local_center: Vector3 = terrain.to_local(world_center)
    var r := radius_m + 2.0 # SDF halo; tune with measured voxel scale
    var box := AABB(local_center - Vector3.ONE * r, Vector3.ONE * (2.0 * r))
    var tool = terrain.call("get_voxel_tool")
    tool.channel = VoxelBuffer.CHANNEL_SDF
    if not tool.is_area_editable(box):
        push_warning("Voxel edit rejected: affected LOD0 area is not editable")
        return false
    tool.mode = VoxelTool.MODE_ADD if add_matter else VoxelTool.MODE_REMOVE
    tool.do_sphere(local_center, radius_m)
    terrain_revision += 1
    terrain_edit_committed.emit(box, terrain_revision)
    return true
```

**Integration requirement:** listen to the signal, convert the local AABB to water-cell indices with the correct transform, and schedule the hydraulic re-extraction. The bridge cannot determine on its own whether the hydraulic extraction has completed. For real production edits, the coordinator must own the edit and commit sequence described in Section 17, not merely call this demonstration and immediately resume simulation.

## 19. Hydraulics detail Claude must not infer

### Shared-face representation

Define the water cell with `(ix, iz)` and cell area `A = dx²`. Store `bed_y`, `volume_m3`, and faces `(east, south)` once; west/north refer to their neighbor's corresponding face. Face state includes `crest_y`, `width_m`, `conductance`, `blocked`, `last_signed_volume_m3` and revision. A wall is a high crest or zero conductance. A culvert is **not** a low exterior crest: it is a special graph link with inlet/outlet elevations and discharge limits. Use a separate node/edge graph for enclosed passage connectivity.

One tick must use this order: (1) gather fixed source and sink volumes, (2) compute proposed face transfers from the **same old state**, (3) cap each cell's total outgoing transfers so it cannot transfer more water than it owns, (4) apply equal/opposite volume changes once per face, (5) apply tracked external boundaries, (6) assert accounting and nonnegative inventory, (7) update diagnostics and publish new read-only render snapshots. No one else mutates the grid during the tick.

The Edition 1 `WaterGrid2D.gd` deliberately uses a simplified head-difference discharge. It provides a **conservative starting point**, not verified flood velocities or momentum. It treats only the region interior (sealed edges), and its `last_flow_x/z` values are approximate flow-query proxies. For production, explicitly implement sources, sinks, boundary exchange, links between cells/chunks, and an independently defined discharge-to-velocity conversion. Do not promote its apparent velocity into an accurate safety/drag force without measured tests.

### Reservoir and irrigation volumes

`spring_m3_per_s`, `rain_m_per_s * catchment_area_m2`, irrigation extraction `m3_per_s`, and open-boundary ocean/river inflows must all be multiplied by `dt` to obtain volumes. Each carries a named source/sink ID. Use a ledger:

```
V_after = V_before + sum(external_inflows) - sum(external_outflows)
error = V_after - expected
```

Interior edge fluxes must cancel in the ledger. Every flow to an unloaded region must be stored in a persistent boundary reservoir/queued exchange, or disallowed using a sealed boundary. It must **never** be thrown away by unloading the chunk. A field's irrigation controller requests extraction from the water service and obtains the **actually granted** volume; it cannot assume its request was satisfied during drought.

### Dams and overtopping

Model each dam as modifying face crests/conductance (with optional cells for the dam body). For the minimal system, dam-break effects use the same conservative solver but a higher temporary substep frequency. A more faithful flood wave may require momentum-capable shallow-water equations; upgrade only if measured gameplay proves necessary. Place known-volume reservoirs on both sides of the dam and compare simulation output to expected qualitative behavior: upstream level rises, downstream outflow drops, overtopping only above crest, breaking the wall releases measured volume, and no water inventory spontaneously changes.

### Cavities and aqueducts

The 2D surface solver supports **one water surface per x/z column**. It must never treat a roofed cave as an ordinary open basin or teleport upper aqueduct water into a stream below. Represent cave/aqueduct volumes as an additional *local* water-body graph (volumes, capacities, pressure/head, links) and couple only at explicit openings. Maintain a body-layer identifier in water queries. For a game with caves, this is a **production requirement**, not an optional visual effect.

## 20. Water rendering, surface generation, and ocean clock fidelity

### Rivers and lakes

Mesh only wet/changed cells. For cells crossed by a shoreline, use an approximate fractional coverage/edge intersection and stitch neighboring patches to avoid squared-off edges. Use a stable shared vertex grid or seam rules at chunk borders; do not independently round mesh heights per chunk. Water surface is near-horizontal with varying hydraulic head, **not** terrain-parallel; advection textures are driven by simulated horizontal flow. Make depth-based transparency and absorption driven by actual sampled depth, with a fallback where depth textures cannot see through transparent objects.

At each water render update, produce `height`, `depth`, `flow_xz`, `foam_mask`, `wet_mask`, and `body_id`. Keep surface meshing and visual foam trails independent of conserved water state. A waterfall should take its visible location and flow strength from a real hydraulic drop. Place a sheet/particles for the falling portion; don't force a heightfield solver to represent a hanging vertical 3D sheet.

### Oceans

Maintain **one** wave parameter source and monotonic simulation clock shared by shader and gameplay. Keep wave phases based on **world-space** coordinates even when the ocean mesh follows the camera, otherwise waves visibly restart or slide when mesh origin jumps. For the included vertical-wave baseline, CPU `sample_height(x,z)` must numerically agree with shader displacement, including gravity/wavenumber/amplitude/time. For true horizontal Gerstner displacement, naive sampling at a world x/z is no longer valid: solve for the source horizontal coordinates iteratively or adopt an explicit approximate query budget. Do not mix vertical-only CPU queries with horizontally displaced GPU vertices.

Storm intensity should *blend* wave amplitudes/directions/frequencies over time. The base baseline is deliberately cheap; quality improvements should be made in this order: wave diversity, lighting/roughness, world-space normal detail, depth-dependent absorption, localized shore foam, then optional geometry displacement upgrade. Higher-cost FFT is not the default.

**Ocean displacement budget:** ensure mesh subdivision supports the shortest geometric wavelength; subpixel waves belong in normal maps. Explicitly expand mesh bounding boxes or cull margins for maximum displacement; otherwise the surface disappears at camera frustum edges. For floating rigid bodies, apply force in the physics loop; don't teleport dynamic bodies every rendered frame.

## 21. Deterministic acceptance-test matrix

Every test must report engine version, terrain revision, active-cell count, solver delta, source/sink ledger, initial and final volume, maximum negative volume, frame timing and world-space screenshot/video.

| ID | Setup | Pass condition |
|----|-------|----------------|
| F01 | 16x16 closed basin with known initial 100 m³ | Relative volume error < 1e-6 after 1000 ticks (float prototype); no negative cells |
| F02 | Same basin, all initial water in one cell | No water created/lost; volume nonnegative on each tick; stable redistribution |
| F03 | Two basins separated by a raised face | No flow before opening; flow starts after crest lowered, and equals exchanged volume |
| F04 | 3 m-high dam and constant named upstream inflow | No overtopping below crest; rise upstream; flow after overflow is not instantaneous redistribution |
| F05 | Remove dam at recorded tick | Stored upstream water moves downstream; same combined inventory unless declared boundary outlet |
| F06 | Dig connected canal through VoxelLodTerrain SDF | No immediate water creation; water then enters by active cell transfers, following the new terrain |
| F07 | Raise ground under standing water | Displaced water transferred/accounted or edit rejected; cannot vanish silently |
| F08 | Unload/load active chunk during flow | Boundary ledger reconciles; inventory and flow state persist across reload |
| F09 | 10 and 60 fps render rates, same fixed simulation steps | Final water cell state agrees within numerical tolerance |
| F10 | Sample 100 deterministic points/time stamps on ocean | CPU and shader vertical heights agree to tolerance after coordinate origin shifts |
| F11 | Aqueduct over river | Upper water remains on separate layer; no cross-transfer absent connected opening |
| F12 | Cave with dry air pocket above underwater opening | Submergence/volume query recognizes correct physical layer; no false global sea-plane fill |
| F13 | Irrigation controller requests greater withdrawal than available | Only granted water is delivered to crops; inventory never negative |
| F14 | Terrain edit near unloaded LOD region | Explicit reject/queue; no partial silent edit |
| F15 | 16->32->64 active chunks with rain and rivers | Measure and plot CPU tick time, GPU frame time, memory, mesh rebuild latency, largest backlog |

**Tolerances:** F01 is a target for double-precision local prototype, not a universal guarantee for long-running production or fixed-point network implementations. Pick and record numeric tolerances before testing. A failing acceptance test blocks the corresponding milestone; never replace it with an assertion that visuals look correct.

## 22. Required Claude work report per milestone

Claude must deliver the exact file paths, complete changed source files, API-compatibility evidence, and a test table with `PASS/FAIL/NOT RUN`. If test tools are unavailable, mark `NOT RUN` rather than stating “verified”. It must not silently change the selected freshwater algorithm, ocean wave representation, world coordinate system, serialization format or Voxel Tools backend. Any proposed departure requires a short evidence-based decision record naming the gameplay problem, tested alternative, performance result, and migration cost.

**Milestone order:** M0 verify Godot/Voxel Tools environment → M1 closed conservative grid → M2 terrain-SDF adapter and world editing → M3 dams/ditches/irrigation → M4 chunk persistence and boundaries → M5 river/shore rendering → M6 ocean renderer and CPU/GPU match → M7 swimmers/boats → M8 caves/stacked water → M9 performance/exports. Do not claim `M0–M9` implemented just because the chapter describing them exists.

### Research and source quality

The detailed scientific research (Volumes 001–010) remains supporting material. Some entries are engineering interpretations and are not individually validated. This Edition 2 makes recommendations based on gameplay scope, but **must not be treated as proof that the chosen algorithms have met their acceptance tests**. After M0, record the actual installed runtime and update the guide's compatibility notes based on measured results.

---

# Part III — Implementation closure: production decisions Claude must not invent

**Edition 3.0 additions.** This part is **normative** for implementations targeting Godot 4.7.2 and Voxel Tools 1.7. Sections 0–22 remain applicable. If two instructions conflict, the stricter conservation/safety rule in this part takes precedence. The algorithms below are implementation specifications, **not claims of an already-tested plugin**. They deliberately reject unsupported edits instead of fabricating geometry or water state.

## 23. Mandatory project discovery and version gate

Before writing a line of integration code, Claude MUST produce `docs/water/runtime_inventory.md` identifying:

1. Exact Godot binary path and `--version` output; whether Voxel Tools is engine-integrated or a GDExtension; version/hash of the installed Voxel Tools binaries and export templates.
2. Actual terrain node class (`VoxelLodTerrain` or alternative), its transform, voxel scale, stream/generator/mesher objects, terrain origin and world coordinate conventions.
3. Actual SDF convention, SDF channel type, nominal zero-isosurface, and whether the voxel tool accesses edited data or procedural generator data at each position. Probe a known solid position, a known air position, and one surface crossing.
4. Current terrain edit call sites, thread ownership, save path, terrain revision mechanism, and any terrain signal already emitted after editing.
5. Rendering method (Forward+, Mobile or Compatibility), target platforms, and physics tick rate.

**Hard gate:** no guessed `VoxelTool` methods. Open the installed class documentation or engine class database and compile/run a tiny adapter smoke test. The bridge in Edition 2 must not be called a complete terrain sampler. APIs on `master` GitHub may not match 1.7. If any crucial API is absent, log `BLOCKED: installed API mismatch`, do not substitute an invented method.

## 24. Terrain-to-water geometry: exact extraction contract

### 24.1 Separate geometric truth from hydraulic state

The water solver MUST NOT directly query scattered voxel values during each substep. Build a cached **HydraulicTile** from terrain geometry:

```text
HydraulicTile (fixed horizontal grid resolution Δx metres)
  tile_id: integer coordinate pair (tx,tz)
  terrain_revision: monotonic integer
  cell_min_surface_y[cell]: lowest exposed top-of-solid floor suitable for open water
  cell_wet_area_fraction[cell]: in [0,1]; 1 for simple reference implementation
  east_face_crest_y[cell], south_face_crest_y[cell]: terrain barrier level at shared face
  east_face_open_fraction[cell], south_face_open_fraction[cell]: in [0,1]
  classification[cell]: OPEN_SURFACE | STACKED_OR_OVERHANG | UNKNOWN
  available: bool; geometry_version: integer
```

**No invented bed:** An overhang/bridge creates more than one solid/air intersection on a vertical probe. Mark it `STACKED_OR_OVERHANG` and route it to a separate water-volume graph or reject fluid simulation there until that graph exists. A missing/unloaded voxel sample is `UNKNOWN`, never treated as air. For reference implementation, require `cell_wet_area_fraction=1` and fully open/closed face fractions; fractional geometry is a later upgrade.

### 24.2 Sampling protocol (simple outdoor surface layer)

- Define an explicit vertical scan range `[Y_MIN, Y_MAX]`, in world-space metres, appropriate to the game's *loaded* terrain. Set scan increment to `min(voxel_size_m, cell_size_m / 4)`, then refine detected solid/air crossings by binary search to at most `min(0.05 m, voxel_size_m/4)` error.
- At each cell centre and at **both ends plus midpoint of all shared faces** (at minimum), sample occupancy through a verified terrain adapter. Convert **world** to **terrain local** before sampling. Do not interpret SDF bytes as metres unless the installed format is confirmed.
- Find the highest solid-to-air crossing exposed to sky for an open-air reference tile. If the column has multiple air cavities or missing terrain data, mark it as requiring a layered representation; do not collapse an enclosed cave into the outdoor bed.
- Derive the face crest from the **highest solid obstruction at the wet surface's passage**, not merely `max(cell_bed_left,cell_bed_right)`. A narrow dam can lie on the boundary even if both cell centres are low. Use the maximum sampled topography along the face for the conservative initial implementation. This may over-block a narrow opening; use face subsegments when that artifact matters.
- Do **not** label a visibly intersecting surface as fully navigable if the samples are insufficient. Add probes or increase hydraulic resolution near player edits.
- Cache computed geometry with the exact terrain revision and tile address. No tile is publishable with partially updated faces.

**Important:** In the baseline `WaterGrid2D`, setting a crest equal to the sampled terrain boundary provides only a *single threshold*. It cannot represent an arbitrary archway or roof. The distinction is intentional.

### 24.3 Geometry resolution trade-off and acceptance tests

The hydraulic grid can be coarser than the rendering mesh; geometry extraction MUST preserve dams/ditches of minimum supported dimensions. Define in project configuration:

```text
hydraulic_cell_size_m = 1.0  # proposed starting value; measure before production
minimum_supported_ditch_width_m = 2.0
minimum_supported_dam_thickness_m = 1.0
terrain_probe_spacing_m <= 0.5 * minimum_supported_dam_thickness_m
```

These are **starting values**, not universal defaults. If the project allows a 0.25 m dam across a 2 m hydraulic cell, a single height sample is insufficient. Either increase local resolution, encode the barrier as an explicit face obstruction, or declare that feature unsupported. Never silently let water pass through.

Test `G01`: construct a 1 m-wide raised berm between two flat cells. The face crest must rise while the cell-centre beds may remain unchanged. Test `G02`: dig a 2 m connected cut through the berm; its face crest must lower. Test `G03`: put a bridge over an open river; lower flow MUST remain under the bridge without filling its roof volume. Until layered support exists, this test must be `BLOCKED`, not marked passed.

## 25. Atomic editing: no disappearing water when a dam is built

### 25.1 Edit transaction state machine

```text
IDLE -> PREPARED -> TERRAIN_EDITED -> GEOMETRY_READY -> COMMITTED
                   \-> REJECTED_OR_RESTORED (with explicit reason)
```

**Single authority:** a `TerrainWaterEditCoordinator` alone may commit a terrain edit that affects simulated water. It accepts world-space edit bounds, edit function, expected terrain revision, and editor/player ID. Do not allow arbitrary digging scripts to mutate voxels without notifying it.

1. **PREPARE:** acquire deterministic sorted locks for every affected tile and its one-face halo; stop solver steps that access those tiles. Snapshot old bed, crests, volumes, face transfers, volume-ledger counters, edit revision, and terrain rollback data if rollback is supported. If authoritative voxel rollback is impossible, use a safely replayable operation log and refuse edits that cannot be applied atomically.
2. **PRECHECK:** ensure Voxel Tools LOD0 editing is available for the expanded bounds, that all required neighbor tiles are loaded, and that the edit cannot cross unsupported enclosed geometry. If not, return a typed `REJECTED_UNLOADED` / `REJECTED_UNSUPPORTED_GEOMETRY` without changing voxels.
3. **APPLY TERRAIN EDIT:** execute on the thread/API context required by installed Voxel Tools; only increment the committed terrain revision after the actual tool operation succeeds. Do not trust visual remeshing completion as a substitute for SDF update completion.
4. **REBUILD GEOMETRY:** rebuild full affected cells and all shared-face crests, including a one-cell outer ring; validate finite elevations and complete data.
5. **RECONCILE:** carry exact cubic metres per cell forward unless the user action explicitly pumps/removes water. **Raising land does not destroy water.** With a depth-based column, volume stays constant and the surface rises. If a roof/cavity becomes closed, require a valid layered container; otherwise reject and restore/compensate the edit.
6. **COMMIT:** atomically swap new geometry, increment terrain+hydraulic revisions, release locks, reactivate those tiles and neighbors, emit one `hydraulic_geometry_committed` event. Renderer and physics queries consume the same committed revision.

**If terrain rollback is unavailable:** do not promise an atomic transaction without implementing a staging/replay mechanism. Schedule edits only where geometry can be guaranteed and tested; for partial failures, freeze that tile and raise a blocking error. Do not silently commit a partial geometry snapshot.

### 25.2 Bed displacement illustration

```gdscript
# WaterGrid2D is the Edition 2 prototype. This is correct ONLY for open-air
# height-column cells; caves and sealed volumes need another container model.
func apply_open_air_bed_change(grid: WaterGrid2D, x: int, z: int, new_bed_y: float) -> void:
    var i := grid.index(x, z)
    var conserved_m3 := grid.volume[i]
    grid.set_bed(x, z, new_bed_y)
    assert(is_equal_approx(grid.volume[i], conserved_m3))
```

The shader must then render the raised surface and the solver redistributes volume gradually. It is **incorrect** to clamp the old water surface in place and delete the water that no longer fits below it.

## 26. Region boundaries, sleeping and persistence: precise rules

### 26.1 Every face has one owner

For global integer cell coordinate `(gx,gz)`, define its east edge as `(gx,gz,EAST)` and south edge as `(gx,gz,SOUTH)`. Exactly one region owns that edge even if the opposite cell belongs to another region. Region ownership and update order MUST NOT depend on camera position or thread scheduling. Assign eastern/southern face ownership to the lexicographically smaller face endpoint; each edge is enumerated once.

**Parallel update phases:** (A) snapshot all relevant old volumes/surfaces; (B) calculate signed candidate face transfers from immutable snapshots; (C) sum outgoing for all cells, including outgoing crossing region boundaries; (D) compute one per-cell supply scale; (E) apply equal and opposite deltas to adjacent cells, and commit all region deltas together. Per-region independent scaling is invalid when a single cell flows through more than one boundary.

### 26.2 Unloaded and sleeping boundary policies

For every region border choose and record exactly one policy:

- **ACTIVE_NEIGHBOR:** both cell volumes are loaded and transfers computed normally.
- **FROZEN_CLOSED:** boundary face transfer is zero; permitted ONLY for an intentionally impermeable world edge or as an explicitly labelled temporary gameplay limitation. It cannot silently represent an arbitrary unloaded stretch of river.
- **PERSISTED_RESERVOIR:** neighboring unloaded area is represented by a water-body reservoir with stored volume and a defined stage-volume curve. Transfers must change both the active cell and reservoir ledger in the same transaction.
- **OPEN_BOUNDARY:** water leaves or enters via a declared external world boundary. Record every transferred m³ in an `external_in_m3` or `external_out_m3` ledger.

A sleeping region is allowed only if all net flows and source/sink activities are below configured thresholds. A sleeping region must wake for neighboring water rise, incoming flux, weather sources, scheduled pump requests, terrain edits, or state load. Never discard its water inventory. If a region is unavailable and has no reservoir representation, halt/request region activation rather than invent downstream water levels.

### 26.3 Conservation ledger — test with a numeric equality

```text
expected_volume(t1) = volume(t0)
  + source_in_m3 + boundary_in_m3
  - withdrawal_m3 - evaporation_m3 - boundary_out_m3
actual_volume(t1) = sum(active_cell_volume_m3)
  + sum(sleeping_region_volume_m3)
  + sum(reservoir_volume_m3)
  + sum(inflight_transfer_m3)
residual_m3 = actual_volume(t1) - expected_volume(t1)
```

All sources/sinks are applied **once** at the fixed simulation step; irrigation crops only receive the volume actually withdrawn. When parallelizing, accumulate `inflight_transfer_m3` through an explicit ownership/commit protocol; a queued message is not free extra water. Emit the absolute/relative residual every N ticks and fail deterministic tests when out of tolerance.

### 26.4 Save format and crash safety

Version every file. Required save fields: `schema_version`, engine/plugin metadata, world ID, tile resolution/origin, terrain revision, hydraulic revision, monotonic tick ID, simulation time, active tile volumes, sleeping tile volumes, pending reservoir volumes, face crest revisions, sources and sinks, and cumulative ledger counters. Include a checksum per tile, and test corrupt-file rejection.

1. Pause/commit an authoritative solver tick; never serialize half of phase B or E.
2. Snapshot terrain revision and water revision together; save terrain and hydrology using a **matching checkpoint ID**.
3. Write new snapshots to temporary paths, flush and verify, then atomically publish the checkpoint manifest. On crash recovery, load the latest fully committed manifest, not whichever file has the newest timestamp.
4. On load, reject version mismatches that cannot be migrated, non-finite numbers, negative volumes, missing terrain snapshots, or inconsistent tile sizes; never reset unknown water to zero silently.
5. Run a 1000-tick save/reload test including a streaming boundary, a changed dam and an active irrigation withdrawal. Compare against uninterrupted execution using recorded tolerances.

## 27. River surface generation: geometry and shaders driven by true water state

### 27.1 Surface mesh topology

Build a mesh over **wet cells** only, with adaptive edge stitching and a narrow shoreline transition strip. For each wet cell, determine surface `η = bed + volume/area`. Use neighboring η samples to interpolate water surface vertices, BUT do not bridge across a high impermeable face crest: split the patch at a dam, wall, cliff or waterfall. Under a steep drop, generate separate upper and lower surfaces plus a waterfall sheet.

- For regular water with gentle slope, use a regular indexed grid with shared vertex indices. Sample water elevations from one committed solver snapshot.
- At wet/dry boundaries, clip the surface to the terrain intersection instead of truncating at rectangular cell edges. Initial implementation: marching squares on `wetness = water_surface_y - terrain_bed_y`, interpolating `wetness = 0` crossings on cell edges. **Ambiguous 0101/1010 cases:** use a consistent asymptotic decider or split based on centre wetness, never alternate topology randomly with frame order.
- Move shoreline vertices slightly away from solid intersections to avoid z-fighting, using a tunable millimetre-scale rendering-only offset; this must not alter physical depth.
- Use temporal hysteresis for visual wetness only (`wet_on > wet_off`) to avoid flickering on shallow water; physics remains based on true nonnegative volume.
- Ensure geometry update queue respects terrain and water revision pairs. Keep the previous valid mesh until a new complete mesh is ready; don't show half-updated water strips.

### 27.2 Optical appearance and flow

Use **one reusable water material**, fed by per-body/region parameters: absorption coefficients (RGB per metre), scattering/turbidity, wind ripples, roughness, foam amount and foam fade, and flow-map/velocity. Advect surface normal/foam UVs along water direction using `uv += flow_mps * time_s / texture_world_scale_m`. Do not infer flow from river spline tangent after a player redirects the river; use the actual solver output.

Foam sources include high speed, steep local drop, obstacles, impact at waterfall base and thin breaking shoreline. A cheap starting foam mask is:

```text
speed01 = smoothstep(v_start, v_full, |velocity|)
drop01 = smoothstep(slope_start, slope_full, downhill_surface_gradient)
shore01 = 1 - smoothstep(depth_start, depth_end, water_depth)
foam_seed = clamp(0.55*speed01*drop01 + 0.30*shore01 + 0.15*obstacle_impact,0,1)
foam_next = max(foam_seed, foam_prev*exp(-dt/foam_lifetime_seconds))
```

Coefficients are art tuning values, **not physical constants**. Preserve foam lifetime and advection on screen when water moves; recomputing a random foam texture every render frame causes visible shimmering. For expensive environments, keep foam persistence in a lower-resolution texture while water volumes stay authoritative on CPU.

### 27.3 Waterfall interface

A waterfall occurs when upstream face surface exceeds a downhill outlet threshold and the hydraulic head drop is sufficiently large. **Flow transfer remains in the hydraulic solver**; waterfalls are geometry and FX consumers. Spawn a ribbon/mesh from the current upper wet edge to lower receiving surface, advect UVs downward with gravity-inspired speed, and emit GPU droplets/mist at contact. Blend foam at top lip and impact basin. Do not route hydraulic volume through a particle system.

### 27.4 Visual-specific tests

`R01`: excavation changes shoreline silhouette only in revised tiles, with no visible straight tile cutoffs. `R02`: current UV direction reverses after a valid canal diversion. `R03`: upper dam water remains visibly higher than downstream water and mesh does not connect through the barrier. `R04`: waterfalls render as falling sheets while conserved volume still transfers through the solver. `R05`: no disappearing mesh at camera frustum edges and no stale mesh after reloading a tile.

## 28. Ocean rendering and interactions: detailed implementation decisions

### 28.1 Canonical wave contract

Use ONE wave descriptor array shared between shader and gameplay sample code. Each component has direction unit vector `(dx,dz)`, wavelength `λ` in metres, amplitude `A` in metres, and phase speed determined from chosen dispersion relation. For a simple deep-water surface:

```text
k = 2π/λ                         [rad/m]
ω = sqrt(g*k)                    [rad/s]
phase = k * dot(dir, position_xz) - ω * simulation_time_s + phase_offset
height = mean_level_y + Σ(A*sin(phase))
vertical_velocity = Σ(-A*ω*cos(phase))
```

If using Gerstner waves (with horizontal displacement), **invert the displacement** when sampling height at a world X/Z position; do not evaluate the undeformed mesh coordinate and pretend it is the same world position. For Edition 2's vertical-only wave starter, the above direct sample is valid. Change only one representation at a time and rerun height-match tests.

### 28.2 Ocean mesh and shader priorities

- Prefer a camera-following ocean mesh/clipmap, with vertices dense near the observer and coarser at distance. Keep UV/world-relative phase continuous during origin shifts. The vertex bounds must include maximum vertical displacement plus horizontal displacement when enabled.
- Put resolvable long waves in vertex displacement; small waves in two independently scrolling normal textures. Use view-dependent roughness, sky/planar/probe reflections where available, and thickness-dependent transmission/absorption.
- Determine water thickness using **linearized** scene depth and the water surface's view-space depth. Reverse-Z requires correct projection reconstruction; never compare raw depth texture to world Y directly. If the rendering pipeline cannot sample reliable scene depth behind transparent water, degrade to a stable shallow/deep color and shoreline foam instead of shipping inverted artifacts.
- Screen-space reflections cannot show out-of-screen or hidden geometry. Provide fallback sky reflection/probes; do not interpret screen-space holes as actual clear water.
- Apply weather changes by smoothing wind strength/direction, small-wave amplitude, foam threshold and spray density. Do not abruptly randomize wave phases as weather changes; existing swell must persist and decay over time.
- Shore-breaking effect: compare local wave amplitude to depth and scale it as water becomes shallow; use a coastline foam band and particles rather than requiring non-hydrostatic surf simulation.

### 28.3 Shared ocean time and floating objects

`WaterService` must provide **one simulation time**, used in ocean shader uniform and CPU sampler. Capture floating-object query samples once per physics tick and apply forces/kinematic motion consistently. Floating body buoyancy may use 4–8 hull points: for each submerged point compute `h = max(surface_y - point_y, 0)` and apply a bounded upward restoring force plus damping; add current-relative drag. This is gameplay buoyancy, not a hydrostatic certification model. Prevent unstable forces by capping acceleration and logging out-of-range water heights.

`O01`: sample ≥100 fixed X/Z/t points; compare shader displacement reference math and CPU height within measured tolerance. `O02`: move floating origin/camera through many kilometres; phase and buoyancy remain continuous. `O03`: transition from calm to storm without wave phase jumps; foam and normals change smoothly. `O04`: shallow coast hides grid cuts and hard alpha edges at varying tides.

## 29. Character water-state machine: remove ambiguity from swimming

Use explicit states `DRY`, `WADING`, `SURFACE_SWIM`, `SUBMERGED`, `FALLING_THROUGH_WATERFALL`, with transitions based on `WaterSample.surface_y_m`, `bottom_y_m`, head/chest positions, depth, and hysteresis. Never assume all terrain under an ocean is deep or all water has one level. Query every physics frame from the authoritative service, not from intersecting render meshes.

```text
DRY -> WADING             feet < surface and water_depth > wade_threshold
WADING -> SURFACE_SWIM    depth > swim_threshold and chest below surface
SURFACE_SWIM -> SUBMERGED head below surface by submerge_hysteresis
SUBMERGED -> SURFACE_SWIM head emerges by emerge_hysteresis
WADING -> DRY             feet clear by exit_hysteresis
```

Implement configurable movement relative to water velocity: `relative_velocity = player_velocity - sampled_current`. Use drag on **relative** velocity, not global player velocity, to ensure that resting swimmers drift naturally downstream. Surface bob follows the sampled water surface using damped movement and a vertical-speed limit; do not teleport a collision body directly to every high-frequency crest. Oxygen and drowning gameplay are separate game mechanics and must not be encoded as a water-simulation side effect.

Test `I01`: zero input in a stream produces downstream drift; identical input upstream produces the expected reduced net progress. `I02`: a wave moves the surface and bobbing object coherently without snapping. `I03`: crossing a river/ocean seam cannot flip water identity several times per second; use a body-priority and hysteresis policy. `I04`: wading in shallow water is not treated as swimming in a bottomless ocean.

## 30. Non-negotiable architecture/quality gates

Each of the following is **a blocking requirement** before Claude claims a feature finished:

| Gate | Demonstration | If it fails |
|---|---|---|
| A — API compatibility | A minimal Godot 4.7.2 + Voxel Tools 1.7 scene runs using the exact APIs | Stop; document mismatch, do not guess |
| B — mass accounting | 1000-tick isolated closed basin within chosen conservation tolerance | Fix ledger/step ordering before adding visuals |
| C — editable path | Newly dug ditch changes face crest/connectivity and routes water | Fix geometry adapter or terrain revision handling |
| D — dam | Placed dam blocks, pools, overtops and releases with conserved inventory | Fix crest/volume logic |
| E — tile streaming | Flow across owner borders is accounted once, including save/reload | No open-world release |
| F — rendering truth | Shoreline and foam follow solver changes, no mesh cut edges | Fix mesh generation/revisions |
| G — ocean consistency | CPU sample matches displayed waves after weather and origin changes | Fix shared wave definition/time |
| H — player interactions | Swimming, bobbing, drift and buoyancy use `WaterService` only | Fix query routing/state machine |
| I — performance | Representative benchmark logged on target hardware with active cells, ms/tick, allocations and FPS | Optimize measured bottleneck, not conjecture |

**Required deliverable format for Claude:** every milestone report must contain (1) exact files changed, (2) full code when requested, (3) runtime build info, (4) tests run and measured outputs, (5) tests not run and why, (6) known deviations from this guide, and (7) next milestone blocked/unblocked. Do not accept generic “works fine” or screenshots alone.

### Explicit exclusions and escalation thresholds

The baseline is not expected to simulate sealed pipe pressure, tunnels with trapped air, archways with multiple stacked surface levels, fully physical erosion or global flood shockwaves accurately. Add a **local** specialized model only when a user-facing test demonstrably fails, then connect it to the water-volume ledger. Never expand the solver universally to 3D just because one cave demands a separate volume system.

### Editor/runtime validation status

All pseudocode, render algorithms and GDScript fragments in this edition require running in the exact installed Godot 4.7.2 + Voxel Tools 1.7 build before they can be labelled tested. Neither an illustrative snippet nor a detailed spec is proof of successful implementation. The implementation plan is deliberately complete about decisions and failure handling while still distinguishing **design**, **compiled prototype**, and **validated production feature**.
