# Art direction

What the world should look like, and how we get there on the minimum machine (GTX/RTX 1050-class, 8 GB RAM, 30 fps; ARCHITECTURE_BUDGET.md). Owned by the "Art direction" project thread. Started 2026-10-20 from the owner's target picture.

**Labels:** *[Decided]* owner decision, *[Proposed]* waiting on the owner, *[Measured]* seen in our build.

## 1. The target picture (owner, 2026-10-20)

**[Decided]** "Everything in it is how I envision our world looking": the trees, the grass, the ground and the brook, possibly the character. That level of detail, running on older medium machines.

The picture: a sunny autumn clearing. A small clear brook (about 1.5 m wide, ankle deep) runs between grassy banks toward the camera; tall golden reeds and long grass on the right, a lush meadow on the left; a thatched log hut and fences in the middle; grey granite cliffs with moss behind; birches and aspens in gold, tall thin pines on the skyline, a big broadleaf trunk framing the right side; a man in a red leather tunic on a log pile, holding a staff.

Source copy: `/mnt/project-files/uploads/hearth/6f55bce5-d10a-4d6c-b733-66e0ad3196d7` (1200 x 675 PNG).

## 2. What makes it look good, per element, in rendering terms

### 2.1 Light and atmosphere (the biggest single reason it looks real)
- **Strong warm sun against a blue sky fill.** Sunlit grass is almost yellow-white, shadows are cool blue-green, never black. That is a bright warm sun (about 1.0 to 1.3 energy, slightly orange) plus ambient light taken from the sky, not a flat grey ambient.
- **Filmic tone mapping.** Highlights roll off softly (sunlit grass tips, rock faces) instead of clipping, and mid-tones keep their colour. This is a tone mapper (AgX or ACES), not extra saturation.
- **Contact shadow / ambient occlusion everywhere things meet:** under grass at the base, inside tree crowns, where the bank meets the water, under the log pile, in cliff cracks. It is what makes objects sit on the ground.
- **Aerial perspective.** The distant pines and cliffs are lighter and bluer than the near ones. A light height-and-distance haze in the sky colour.
- **Soft shadows with a long reach.** Tree shadows fall across the meadow and are soft at their far end.

### 2.2 Grass
- **Full coverage.** In the meadow the soil is not visible at all; grass covers it to the horizon of the clearing. Near the camera there are hundreds of blades per square metre.
- **Colour comes from the blades, not the ground:** dark green at the base, yellow-green to straw at the tips, so every clump has a gradient, and the field has big patches (lush green on the left, dry gold on the right).
- **Mixed species:** fine meadow grass, tall seed-headed grass, golden reed clumps (about 1 m) near the wet ground, ferns under the trees, a few tiny flowers.
- **The far field is not grass at all.** Beyond about 30 m it is the ground texture painted in the same colours, so you never see where the cards stop.
- **Lit like a soft mass:** blades take the ground's lighting with a slight see-through glow when the sun is behind them.

### 2.3 Ground
- **Real material textures, not noise colour:** brown forest litter with needles and small sticks under the trees (right), gravel with pebbles on the path (bottom right), dark wet soil on the bank, mossy turf on rock tops.
- **Clear borders between materials** that follow the land (path edge, bank edge, edge of the tree shade), blended by height so pebbles poke through soil rather than fading like a gradient.
- **Small objects on the ground:** pebbles, sticks, a fallen log, stones on the bank edge.

### 2.4 The brook
- **Clear water: you see the bed.** Rounded pale pebbles and stones under the water, dark gaps between them. The water is nearly invisible where shallow and tints amber/teal only a little with depth.
- **Reflection by viewing angle (Fresnel):** near the camera you look through it; farther up the brook it mirrors the bright sky and trees.
- **Small moving ripples** flowing with the current that bend what you see underneath.
- **The banks make it:** a steep 20 to 40 cm cut bank, dark wet soil and moss at the waterline, grass hanging over the edge. The brook sits *in* the ground.
- **Scale:** this is a small stream, much smaller than our 20 m rivers. It is the kind of water that should run from springs and through towns.

### 2.5 Trees
- **Leaves read as clusters, not single cards.** Each card is a photo-like spray of many small leaves with holes between them, so crowns are lacy at the edge and dense inside.
- **Crowns are shaded as one soft volume:** dark inside, bright on the sun side, with light glowing through the leaves on the edge (birch and aspen gold glows). That is normals pointing out from the crown centre plus crown ambient occlusion plus back-light translucency.
- **Bark has depth:** the big trunk on the right shows deep furrows and moss at the base (a normal map plus a moss tint at the bottom).
- **Pines are tall, thin, bare low down,** with a small open crown high up (Scots pine style) and you see sky through them.
- **Distance:** far trees are simple but keep their silhouette and colour; nothing pops.

### 2.6 Rock
- **Big grey granite faces with cracks and ledges,** moss and grass on every flat top, lighter where the sun hits, darker blue in cracks. A rock texture projected from the sides (triplanar) with moss on up-facing surfaces.

### 2.7 Character and buildings
- **Character:** realistic proportions, layered clothes (leather tunic, cloth sash, bracers, boots), rich material detail. This is more realistic than "heroic with a hint of cartoon" (see the open question in Section 5).
- **Buildings:** log and thatch with mossy thatch, real wood grain. Not in scope yet; noted for later.

## 3. Where our build is today (owner screenshots builds 50 to 61)

| Element | Today | Gap to the picture |
|---|---|---|
| Light | Sun with shadows, flat white ambient at 0.45, linear tone mapping, no ambient occlusion, light fog | Flat and grey; shadows lack colour; nothing sits on the ground |
| Grass | Three layers of cards, sparse tufts, ground shows through, 14 to 48 m | Far too thin; colour is in the ground, not the blades |
| Ground | One colour per soil plus value noise (no textures) | Smooth plastic look, no litter, gravel or pebbles |
| Water | Opaque grey animated surface, rivers 20 m wide | Not clear, no bed visible, no small brooks |
| Trees | Procedural, single leaf cards visible as stripes, flat-lit crowns | Need cluster cards, crown shading, translucency, bark normals |
| Rock | Grey noise with strata bands | Needs real rock texture and moss tops |

## 4. How to get there on the minimum machine: ranked plan

Ranked by how much closer each step gets us per millisecond of frame time on a 1050. Each step says what Low does (ARCHITECTURE_BUDGET rule).

1. **Light and post (biggest win, nearly free).** AgX tone mapping, ambient light from the sky, a warmer brighter sun, slightly blue shadows, SSAO on Medium and up (half resolution), a little glow on High, height haze for aerial perspective. *Cost:* tone mapping and sky ambient about 0 ms; SSAO about 1 to 2 ms on a 1050 at half res. *Low:* tone mapping and sky light only, no SSAO.
2. **Ground material textures.** A set of 6 to 8 tileable materials (meadow soil, forest litter, gravel/pebbles, wet bank soil/mud, streambed pebbles, granite, moss, sand) in one texture array, each colour + normal + roughness/height packed, blended by height, side-projected only on steep faces, and a far-distance colour so the tiling never shows. *Cost:* about 1 ms; 20 to 40 MB of video memory at 1K. *Low:* 512 px textures, no height blend. *Textures:* the cloud cannot download texture libraries (proxy blocks ambientCG and Poly Haven, checked 2026-10-20), so either we generate them procedurally in the cloud or the owner downloads CC0 sets on his machine and commits them.
3. **Grass that covers the ground.** Many more, denser clumps near the player using alpha-to-coverage cards (smooth edges, no shimmer), colour gradient per blade, a few species (meadow, tall seed grass, reed, fern, flowers) in one atlas, the ground texture tinted to the same grass colour so the far field matches, base darkening for contact shadow. *Cost:* the most expensive step (overdraw); the grass radius and density per tier carry the cost. *Low:* about 15 m radius, fewer bigger clumps; the matching ground colour does most of the work.
4. **Trees.** Leaf cluster cards (sprays of leaves with alpha) instead of single leaves, normals bent out from the crown centre, crown ambient occlusion baked into vertex colour, back-light translucency, bark normal maps with moss at the base, and far trees as impostor cards. *Cost:* fewer, bigger cards lower the triangle count; impostors cut far cost. *Low:* impostors from closer in.
5. **Clear water and brooks.** A water shader that shows the bed: depth-based colour and clarity, sky reflection by angle, flowing ripples that bend the view, foam at rocks, wet dark banks; small brooks generated from springs (owned by the water/terrain thread). *Cost:* about 0.5 to 1 ms (screen texture + depth). *Low:* sky reflection and depth tint without refraction.
6. **Rock and small details.** Granite texture with moss on tops (part of step 2), scattered pebbles, sticks and boulder meshes near the player.
7. **Characters and buildings.** Later, when they exist.

Every step gets a before-and-after render (cloud software rendering, `cloud-rendering` memory) and a frame-time check in the owner's playtest.

## 5. Realism over storybook

**[Decided] (owner, 2026-10-20: "to me the picture is right")** The picture is near-photoreal, while the earlier direction (DESIGN_IDEAS Section 1) said "the world looks like the best of old fantasy book illustrations" with slightly cartoonish characters. The picture wins. The world aims for natural, realistic materials and light with warm, rich colour, and "storybook" lives in the colour and mood rather than in painted shapes. The character style is decided in section 10.

## 6. Time of day (owner feedback on build 66, 2026-10-20)

The midday sun (high angle, bright) feels right. At morning and evening Dave expects warmer, golden colouring around the golden hours. **[Decided]** When time of day exists, sun colour, sun energy, sky colours, fog/haze colour and ambient light all shift with the sun's height: white-warm and bright at noon, deep gold and softer near the horizon, then cool blue at dusk and night. `src/client/look_settings.gd` holds the midday values; a sun-height curve will drive them. Nothing to change until a day cycle exists.

## 7. Ground textures (step 2, build 84)

Six seamless 512 px textures are generated by `tools/make_ground_textures.py` (turf, forest litter, gravel, mud and clay, sand, rock) into `assets/ground/` (about 4 MB). Each has a brightness detail (R), bump (G, B) and height (A). `ground_material.gd` loads them as one texture array; each palette entry names its layer (`SOIL_LAYER`; every rock uses layer 5), mixed materials mix layers, and steep faces draw as rock. The soil colours still come from the tables; the texture only adds detail and bump, fading out 60 to 260 m away.
**Cost at Low:** 256 px textures (1.5 MB of video memory), one sample per active layer, no side projections. Medium and up use 512 px; side projections (3 samples) only on slopes steeper than about 22 degrees.
Checked only on a flat test patch in the cloud renderer (`art/ground_textures_test.png`); slopes, rock faces and far tiling need Dave's playtest.

## 8. Vegetation follows the slope (owner rules, 2026-10-20; reference: an alpine hillside photo)

Target look: green meadow at the foot of a hill; as the slope grows the grass fails in patches and then holds only on small ledges and outcrops; steep faces are bare rock with moss and grass tufts in cracks. Plants try to grow on ledges and outcrops, usually stunted trees and bushes there too. **Hardwoods fade out gradually toward the slopes of hills and mountains** and give way to dense patches of low, ground-hugging evergreens (fir and similar); toward steep ground those get lower, then only stunted trees on ledges and outcrops.

- **Built (build 86, client only):** soil colour and grass cover thin with slope and break up in noise patches (`ground_material.gd` and `grass_view.gd` use the same rule: full cover under slope 0.14, gone by 0.42, where slope is 1 minus the surface normal's y). Where it fails the stone shows through with the rock texture. A ledge has a level surface of its own, so it keeps its green. Cost: one extra noise sample in the ground shader and a cheap check in grass placement; nothing extra at Low.
- **Built (build 90, server flora placer, approved by Technical direction with the item ids kept):** `flora_placer.gd` thins hardwoods with slope (down to 5% of normal by slope 0.6), makes conifers grow lower on slopes (down to 40% height), adds dense low (1 to 3 m) fir and spruce patches (`"montane": true` in `flora.json`, in 30 m patches, 40% of the squares, on steep and ridge ground, built from the species' own stand cells that no circle uses), and lets hardy species (`"ledge": true`: pines, firs, spruce, juniper, rowan, gorse, rosemary, dwarf birch, sleetberry) stand stunted on flat ledges (surface within 1.5 m flatter than 0.3) of ground steeper than their limit, 30% of such spots. Measured on 49 chunks around spawn: hardwoods on slopes over 0.4 fell from 256 to 110; conifers on slopes over 0.4 rose from 238 to 1224 with mean height falling from 17 m to 3.4 m. Tests 881 passed, flight check 3 slow frames (baseline 19), placer time about 20% higher (server only). Cost at Low: client draws more but smaller conifers on slopes and fewer big hardwoods; no new client work.

## 9. Weather looks take zone, season and town spirit as inputs (owner, 2026-10-20)

Weather is set by the north-south zone, every zone has seasons, dry zones stay dry and polar zones get snow instead of rain. A town's area is also shaped by its town spirit: high spirit gives mostly sun and warm, gentle, occasional nightly rain; low spirit gives heavy storms, lightning, blizzards, multi-day rain and very little sun. Sky, light, fog, rain, snow and wet-ground looks (and their sounds) should read three inputs: zone, season, spirit. Nothing built yet; `look_settings.gd` and `sky_clouds.gd` are where they will plug in.

## 10. Character look (owner decision, 2026-10-20)

**[Decided]** Characters are slightly stylised: heroic proportions and a hint of cartoon, not realistic, and lighter on older machines (a lower triangle and texture budget than the target picture's character, which was realistic). The world around them stays realistic. This unblocks character model work (Art queue item 7); the budget per character (triangles, bones, texture size, per tier) still goes through the asset budget table with Technical direction before any model is made.

## 11. Forest floor objects (owner decision, 2026-10-20)

**[Decided]** First: fallen branches and leaf litter on the forest floor. Later: reeds, driftwood, pebbles and the rest of the Stage 7 list. Built in Art queue item 5 (rock and small details); the litter texture layer from step 2 already covers the base look.

## 12. Dense grass (step 3, build 97)

New painted card textures from `tools/make_grass_textures.py` (fine tapered blades, dark root to light tip, tall grass with seed heads, ground cover as blades splayed flat). More cards: 4 cover, 4 short, 2 tall per ground sample, and more ground samples per tier (3, 4, 5, 6 per 6 m side, was 2, 3, 4, 5). Blades have back-light so the sun glows through them. The ground shader tints grassy ground (`lw[0] * cover`) to the same meadow green so no dark soil shows between tufts and far ground matches near.
**Cost per tier** (cards, estimated from the cloud test clearing and radius; real frame time still needs a playtest): Low about 1.3 k cards at 14 m (was about 0.6 k), Medium about 6 k at 24 m, High about 20 k at 34 m (22 k in the test clearing), Ultra about 55 k at 48 m. Low stays at 14 m. Alpha-to-coverage was not used: it needs MSAA, which Low cannot afford; Medium and up smooth the card edges with TAA.
Renders: `art/grass_before.png`, `art/grass_after.png`.

## 13. Tree crowns and bark (step 4, build 100)

What changed (client look only, no model or save format change):
- Foliage shader: crown undersides are darker (normal facing down, up to 40%), and every patch of leaves gets its own tone (fixed per UV cell, 12%), so a crown reads as clusters instead of one smooth lump. Back-light and bent normals unchanged.
- Bark: `tools/make_bark_textures.py` makes `bark.png` (thin furrows running up the trunk) and `bark_smooth.png`; RGB is the near-neutral colour (species tint multiplies it), alpha is the height. The bark shader darkens furrows, lightens ridges and adds damp moss to the bottom metre of the trunk.
- Rounded tree base: fixed earlier (triangle winding in `_trunk` and `_branch`).
- Before/after: /mnt/project-files/art/crowns_oak_before_after.png

Cost at Low: no new textures, no new draws. About 6 extra shader operations per leaf pixel and 4 per bark pixel; one extra varying. Not measurable in the cloud (stills only), to be confirmed in Dave's frame probe.

Still open for step 4: far-tree impostors (LOD format needs Technical direction approval, joint with Ground loading item 6).

## 14. Denser grass, round two (build 102, Dave: "we need much more grass")

Findings: grass is already built once per 6 m ground cell (one MultiMesh per layer per cell, kept until the cell leaves the radius, no per-frame rebuild or buffer rewrite) and each layer shares ONE clump mesh and ONE material for all cells. Shadows are already off for grass. So the cost is GPU fill and shading, not CPU or re-uploads. Dave's High screenshot: cpu 1.7 ms, gpu 28.3 ms, 11,929 grass cards.
Changes: smaller, more numerous cards (cover 6, short 8, tall 3 per ground sample before the quality factor; short cards 2 crossed quads instead of 3, 0.55 by 0.34 m), fuller textures (70 blades per short card, 120 per cover card), quality density factor (Low 0.45, Medium 0.65, High 0.75, Ultra 0.85), more ground samples (Medium 5, High 6, Ultra 7 per 6 m side), short layer drawn to 70% of the radius (was 85%), cover layer to 60% (was 50%). Shader: diffuse_lambert instead of burley, back-light only on tall grass.
Test clearing cards at High: 55,000 at density 1.0 (build 97: 22,000); shipped at 0.75, about 41,000.
Measuring: Ctrl+Shift+G in game, or Esc > Advanced (GPU probe) lists GPU ms with grass off, trees off, ground off, sea off, shadows off, SSAO off, glow off, fog off and AA off. Real per-tier cost needs that table from Dave's machine; the cloud only renders stills.

## 15. Clear water (step 5, build 111)

Rivers and ponds now read as clear brook water over a visible bed: `clarity_m` 0.45 to 1.1 and `edge_alpha` 0.35 to 0.12 (thin water stays see-through, about 2 m is opaque, deep water is still the dark sea colour). At Medium and up the bed is tinted by depth (red is absorbed first, so it greens and darkens, `exp(-depth * (0.55, 0.16, 0.10))`) and bright caustic lines play on it in water shallower than about 1.8 m within 25 m of the eye. Sky reflection (Fresnel with mirrored clouds), refraction and foam were already in place (steps 1 to 3) and are unchanged; the flow speed in the vertex colour is untouched (Water thread, build 101).
**Low (condition from Technical direction):** a second shader variant without `depth_texture` and `screen_texture` (no full-frame copy in Forward+); the water depth comes from the vertex alpha, the colour is sky reflection plus depth tint blended over the ground. `WaterMaterial.apply_quality` switches the shader. Renders: `art/water_before_after.png` (Medium, before on top), `art/water_low.png`.
**GPU breakdown cost:** not measurable in the cloud. Expected: Medium and up, caustics add 2 noise samples only on shallow near water (a few percent of the water pass), the absorption is 3 multiplies; Low saves the two full-frame copies the old shader forced at every tier. Dave's F8 "sea off" line before and after is the real number.

## 16. Far-tree impostors (step 4, build 125, approved by Technical direction with conditions)

Trees now have three tiers, chosen per 256 m chunk by chunk distance (table `FloraView.IMPOSTOR_M`, `IMPOSTOR_TILE_PX`, `FAR_SHADOWS`; full-model and view distances come from the tile rules times the client's QUALITY_FLORA):
| Quality | Full model | Far model (150 to 300 tris) | Impostor | Image per species |
|---|---|---|---|---|
| Low | 0 to 60 m | 60 to 120 m | 120 to 180 m | 64x128 x 2 views, about 87 KB |
| Medium | 0 to 105 m | 105 to 210 m | 210 to 315 m | 128x256 x 2 views, about 350 KB |
| High | 0 to 150 m | 150 to 300 m | 300 to 450 m | same |
| Ultra | 0 to 150 m | 150 to 300 m (casts shadows) | 300 to 450 m | same |
How: `src/flora/tree_impostor.gd` renders each tree species' far model once at startup into a SubViewport (orthographic, front and side, flat white ambient and no sun so no light direction is baked in), packs the two views into one mipmapped atlas and builds 2 crossed vertical quads (4 triangles). The shader tints the crown above the lowest leaf with the tree's own autumn or conifer colour (INSTANCE_CUSTOM), leaves the trunk untinted, lights the quad like the ground (normal up) and darkens the lower crown a little. Everything is client only: no server, protocol, save or item id change, the MultiMesh per species and part and its buffer are as before (only the mesh differs). Skipped (far model stays): glowing species (everember, witness tree), headless runs (no rendering device), and any species whose capture fails; the capture runs one view per frame at startup (about 24 species) and again only if the image size changes with quality. Shadows: impostors cast none; far-model trees cast shadows only at Ultra (the part's bounds overlap the cascades, so every instance of a part would otherwise go through the shadow pass).
Known limits: one variant per species (the far model's variant 0) stands for all variants; a season change needs a new capture (hook: `set_quality`/`_capture_impostors`); no fade between tiers (the switch is per chunk, 256 m wide, beyond 120 to 300 m).
Checks: cloud render, far model above and impostors below at 190 m, same trees: `art/tree_impostor_far_vs_impostor.png` (size and tint match; impostor crowns are a little flatter). Headless client check: 1507 frames, 2 slower than 50 ms, no script errors.
Cost at Low: 4 triangles and 2 alpha-tested quads per tree beyond 120 m instead of 150 to 300 triangles; 87 KB per species once. GPU breakdown "trees off" before and after still to be measured on Dave's machine.

## 17. Weather look (job 6b, build 131)

Client only; no server, protocol or save change. `src/client/weather_look.gd` reads the same weather state the sounds use (`terrain_client.weather`, refreshed once a second; the F-menu sound test kinds also drive it) and eases the picture toward it over about 8 s.
Rules (Dave, 2026-10-20): rain and snow only fall from clouds (cloud cover = max of cloud, rain, snow, storm, so a clear sky never rains). Bigger storms get darker, greyer clouds and sky (`gloom` uniform in `sky_clouds.gd`; coverage rises toward overcast; sun energy and sky light dim; fog thickens and takes the same grey). The biggest storms add lightning: a sky flash (lights the clouds from within, jumps sun and ambient) and, from Medium, a jagged camera-facing bolt with two forks. Rain soaks the ground everywhere (darker, glossier) and stays dry under trees; snow settles on flat ground and not under trees, buries the grass above 0.5 lying.
Dry under trees: `canopy_map.gd` keeps a 128 m x 128 m map (one texel per metre, R8, 16 KB) centred on the player; every tree crown within it is stamped as a disc of its crown diameter (any tree, any season; `FloraView.canopy_discs`, `canopy_version`). The ground shader reads it (no wetness or snow under a disc) and the rain streak shader scales a streak to zero over a disc, so no rain falls through a canopy near the player. `weather_look.cover_at(Vector3)` is the shared query. The map redraws when the player moved 12 m or the trees changed (at most every 400 ms).
Lightning event for Sounds and gameplay: `sound.weather.lightning(at, distance_m)` (client side, from the weather state, no network); the look listens to it and also emits `flash_started(at_world, distance_m)`. Real strikes that burn, injure or kill need a server position: a gameplay matter, not built here.
Cost per tier (rain streaks, snow flakes, bolt): Low 500 / 350, no bolt geometry, sky flash only, no snow turbulence; Medium 1400 / 900 plus bolt and turbulence; High 2800 / 2000; Ultra 4500 / 3200. Per frame at every tier: a handful of sky, light, fog and ground uniforms; the 16 KB canopy texture upload only when it changes. The sky grading is 6 extra multiplies per sky pixel. No new full-frame passes, no volumetrics. F8 numbers are for Dave's machine; the cloud renderer (software) cannot time the GPU.

## 18. Fir to hardwood gradient (build 150, Dave 2026-10-20)

Below a mountain about 80 to 90% of the trees are firs; moving away toward the fertile lowlands it reverses to about 85% hardwoods. `flora_placer.gd`: `_mountain_near` (how far the highest ground on rings 200 and 450 m around a spot stands above it, smoothstep 25 to 120 m) combined with the old ridge factor gives a 0..1 "mountain" value; evergreens get a chance multiplier from `MIX_MINOR` 0.12 (lowland) to 1.0 (mountain), hardwoods from 1.0 to `MIX_HARD_AT_MOUNTAIN` 0.05, so the change is smooth. Slope thinning of hardwoods is unchanged. Server placement only: no re-bake, no format change, trees are placed live.
Counts (starter area, 11 x 11 chunks, trees only), by mountain value: below a mountain (over 0.8) firs 15,798 vs hardwoods 3,761 (81% firs; before 11,477 vs 12,927, 47%); lowland (under 0.2) firs 1,327 vs hardwoods 8,278 (86% hardwoods; before 1,499 vs 8,352, 85%); middle bands 22% and 62% firs. Cost: 16 extra height lookups per tree candidate on the server only; nothing on the client.

## 19. Flora cost plan, step 2: impostor switch closer (build 160)

Dave's GPU table (build 157, High): trees, shrubs and plants 11.3 ms of 20, sun shadows 6.2 ms. Step 2 of tech/RENDER_AUDIT.md "Flora cost plan": `FloraView.IMPOSTOR_M` from [120, 210, 300, 300] to [100, 150, 180, 250] (Low, Medium, High, Ultra), so trees turn into 4-triangle impostors sooner. Full-model range (60 / 105 / 150 / 150 m) and view range are unchanged. Cost: fewer far-model trees (150 to 300 triangles each) drawn between the old and new switch distance; Low saves them beyond 100 m instead of 120 m. Measure: Dave's F8 table "trees, shrubs, plants off" and the total at High and Low before and after; keep only if it saves 1 ms or more with no visible pop.

## 20. Flora cost plan, step 3: tree shadows only near (build 164)

Sun shadow range per tier (terrain_client QUALITY_SHADOW_M, Technical direction): Low off, Medium 45 m, High 60 m, Ultra 120 m. Full-detail trees also cast shadows only inside the same range, chosen per 64 m cell (`FloraView.SHADOW_M`, `CELL_M`): a cell of a chunk beyond it draws its full models in a separate group with shadows off, so a 256 m chunk no longer casts everything because one corner is near. Far-model trees cast shadows only at Ultra (unchanged), impostors none, shrubs and plants none. Client only. Cost: up to 16 cell checks per chunk when its level is worked out; one extra draw group per species and part for the cells beyond the range. Measure: F8 "sun shadows off" and total at High.

## 21. Double the grass (build 191, Dave 2026-10-20: "double the amount or more")

`QUALITY_GRASS_DENSITY` (cards per ground sample, times each layer's own count) from [0.45, 0.65, 0.75, 0.85] to [0.68, 1.3, 1.5, 1.7]: 2.0 times the grass at Medium, High and Ultra, and 1.5 times at Low (Technical direction: the Low minimum machine is a 1050-class card). Draw radius (14 / 24 / 34 / 48 m), ground samples per cell (so ground raycasts), draws per cell (3 layers) and every thinning rule (slope, water, canopy, soil) are unchanged: the extra cards fall only where grass already grew, and each cell is still built once.
Instances in the headless walk: Low about 1,400 (about 930 before), High about 57,000 (about 28,000 before). Draw calls: unchanged (up to 3 per cell, 420 cells at High in the walk). Memory: 64 bytes per card in the GPU buffer, so about 3.6 MB at High (was 1.8 MB), about 0.1 MB at Low.
Also: the cell's cards now go to the GPU as one MultiMesh buffer instead of two calls per card. Grass build on the main thread at High (900-frame walk): 4.16 ms average and 170 ms worst per frame with double density and the old per-card calls; 1.26 ms average and 14.5 ms worst with the buffer (that run at density 1.65).
GPU: grass is alpha-scissor cards and "grass off" saved about 0 ms in Dave's table (build 157). The Low and High "grass off" rows on Dave's next table are the real numbers (cloud has no graphics).

## 22. Low priority: drifting air debris (idea from Dave, 2026-10-20, not to build now)

Pollen, seeds and dust drifting through the air, for realism and to show the wind direction for hunting on land. None at sea unless close to an island. Plan: a small GPUParticles3D around the camera like the rain and snow in `weather_look.gd`, fed by the same world wind vector the sound and the grass sway use, so all three agree; density by season (pollen in spring and summer, seeds in autumn), nearby flora and time of day; off or very sparse at Low; faded by distance from the shore (needs a shore distance from the ground or sea, no new network data). Cost to state when built: particle count per tier and the F8 line.
