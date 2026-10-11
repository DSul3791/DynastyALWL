# Changes in this pass

## 1. Shared horizontal column cache

The LOD bake path now computes these common X/Z facts once in `BakedVoxelSampler`:

- master/local geology X
- master/local geology Z
- geological column top
- total deformation
- fault-zone strength
- surface height
- surficial deposit information
- shallow intrusion column information

`NaturalCaveSampler` consumes the shared master coordinates and fault strength directly.
`MineralDepositSampler` consumes the shared master coordinates, deformation, and fault strength directly and prepares only mineral-specific X/Z facts.

The older standalone preparation functions remain for compatibility/fallback use, but the main voxel-bake path no longer uses them.

## 2. Scalable mountain system

`TectonicDeformation` no longer hard-codes three principal peaks or one 1000 m broad central dome.

The new system:

- derives the mountain province from island dimensions
- derives major mountain count from structural length / target spacing
- uses deterministic seed-based irregular position, height, and radius per mass
- gives every mass its own broad uplift and sharper summit
- keeps a weaker connecting axial ridge
- carves broad inter-mass valleys before erosion/hydrology
- retains secondary ridges, spurs, saddles, foothill detail, folding, faulting, erosion, and later hydrology

For a 10.24 km island, the current constants normally produce several major mountain masses rather than a fixed count of three.

## First test

Run the same 8 m wrapped surface preview used for the previous terrain screenshots. Compare:

1. number of visually distinct major summits
2. width/depth of valleys between mountain groups
3. whether any broad valley/basin is large enough for forest/lake/river gameplay
4. maximum elevation
5. wrapped-edge neighbor step
6. total 8 m preview build time

Do not start a full voxel bake until the 8 m macro terrain looks right.
