# PBR ground downloads for Mike (Kathleen, 24 Oct 2026)

Why: the ground uses albedo-only tiles; adding normal and roughness maps makes it look like real soil, grass and stone up close. All sets are from ambientCG, licence CC0 (public domain, no credit needed, commercial use fine). Download on Dave's PC (the cloud cannot reach the site).

Take from each zip the **1K-JPG** pack. In it use only these three maps, rename and copy them as shown. Ignore AmbientOcclusion, Displacement and the others.
Zip file names are `<id>_1K-JPG.zip`; inside: `<id>_1K-JPG_Color.jpg`, `<id>_1K-JPG_NormalGL.jpg` (use GL, not DX), `<id>_1K-JPG_Roughness.jpg`.

| Ground layer (existing tile) | ambientCG page | id | zip size | Why this one |
|---|---|---|---|---|
| layer_0_turf | https://ambientcg.com/view?id=Grass001 | Grass001 | 10 MB | short dense green lawn grass |
| layer_1_litter | https://ambientcg.com/view?id=Ground011 | Ground011 | 10 MB | forest floor with leaves (tags Forest, Leaves) |
| layer_2_gravel | https://ambientcg.com/view?id=Gravel023 | Gravel023 | 9 MB | photoscanned pale pebbles |
| layer_3_mud and layer_4_sand | https://ambientcg.com/view?id=Ground029 | Ground029 | 9 MB | tags Mud, Sand, Beach: one set, the shader tints it dark for mud |
| layer_5_rock | https://ambientcg.com/view?id=Rock001 | Rock001 | 6 MB | grey smooth rock, tags Moss, Flat |

Total download about 44 MB (5 zips).

## Where the files go (repo root = C:\GodotProjects\DynastyALWL_test)
`assets/pbr/ground/<layer>_color.jpg`, `<layer>_normal.jpg`, `<layer>_rough.jpg`, where `<layer>` is turf, litter, gravel, mud_sand, rock. Example: `Grass001_1K-JPG_NormalGL.jpg` becomes `assets/pbr/ground/turf_normal.jpg`. Fifteen files in all.

## Check before you copy
Open each page and look at the preview: it must match the "Why this one" column. If one looks wrong (for example Ground011 has no leaves), tell Kathleen which and pick the nearest page in the same ambientCG category (Ground, Gravel, Rock). Do not use Poly Haven or any non-CC0 source.

## Also add one line per set to assets/pbr/CREDITS_PBR.csv
`file,source,url,licence,date`, for example: `turf_color.jpg,ambientCG Grass001,https://ambientcg.com/view?id=Grass001,CC0,2026-10-24`.
Godot imports them on first open: for the _normal files, set Import > Detect 3D off and Normal Map to Enable in the Import dock (or tell Kathleen and she will ship the .import settings).
