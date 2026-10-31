# Forest floor and beach models (flora session request), 2026-10-31, Kathleen

Pictures: offline four views through tools/flora_model_view.gd (the real tree_builder.gd build, vertex colours, no leaf textures, brighter than the game). Models are in src/flora/tree_builder.gd.

| Model (flora entry name, model) | Pictures | Critique | Rating | Next |
|---|---|---|---|---|
| fallen_log (model fallen_log), hollow_log (same model, hollow end) | fallen_log_round1 (thin grey tube, a few moss blobs), round2 | dark bark with lighter and darker ridges, snapped branch stubs, a pale broken end, moss on top and down the sides; hollow variant has a dark mouth at one end | 3 | the moss reads as leaf diamonds: more, smaller, rounder tufts; a darker damp underside; check in the real game at 10 m |
| old_stump (model fallen_log) | old_stump_round1.png | squat butt with splayed roots, a pale broken top and a mossy cap; reads as an old stump | 3 | bigger moss, a split in the top |
| kelp (model kelp) | kelp_round1 (read as dry grass), round2 (stipes with flat lobes) | still reads as pale reeds with buds, not kelp (underwater it will take the water tint, but the shape is not ribbon-like) | 2 | wider wavy ribbon blades, a darker olive, a forest of fewer longer stipes; look at it in the real game under water |
| dune_grass (model grass_tuft), sea_holly (model wildflower) | dune_grass_round1.png, sea_holly_round1.png | not yet critiqued: dune grass a rounded tuft of grey-green blades with pale plumes, sea holly steel-blue heads on stiff stems | 2 | real-game check next to sand |

Rule for the flora session: fallen_log length is the entry height_m (2 to 6 m), the radius is derived (max of crown_m x 0.12 and length x 0.075, between 0.14 and 0.45 m), so a collider for logs of 4 m and more can use a capsule of that radius along the log (x axis of the model, yaw random).
