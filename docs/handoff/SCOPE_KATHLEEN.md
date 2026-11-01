# Scope: Kathleen (art and looks), 2026-11-01

> **ADDITION (Dave, 1 Nov 2026): water LOOKS are the art team's** (colour, transparency, shader appearance, foam, flow-texture look, reflections, shore look). Kathreen takes it first; Sonny keeps the mechanics and supplies depth and flow data.

> **RULE (Dave, 1 Nov 2026): anything about LOOKS is yours.** That includes how plants (flower and stem colours, grass appearance and shader look) and animals look, as well as characters and fire. MikeW keeps density, placement, seasons and draw cost.

> **ROLE ADDITION (Dave, 1 Nov 2026): fire and flame looks are yours:** flames, embers, glow, flicker, colour, light range and shape (the front-only fireplace cone), lit torch and chandelier looks, smoke. Tyler keeps the rules (lit/unlit, fuel, warmth, saved state) and reviews code changes. Start from Tyler's fire-light commits ed07d89f, ceeb057e, e5172fe9, eb9f4a39, a6a6f4d9, 02e7d317 and the pictures in art/CRITIQUES/fire_light_2026-10-31 and lit_2026-10-31. The Guide found a lit campfire with no visible flames in his picture (QA card pic-fh-campfire-lit): check that first.

> **ROLE ADDITION (Dave, 1 Nov 2026, interim): the character LOOK is yours:** body, face, hair, worn clothes and armour as seen, hands, the side-on stance and animations, the creator preview (it opens on the back) and select/loading pictures. Previously Sonny's; the character system (records, select code) goes to Tyler.

Read with `HANDOFF_KATHLEEN.md` (state, tests, risks, how to post pictures).

## 1. The job, in plain words
Make everything the player sees of things (not people's bodies, not water, not the ground) look like the real object at 10 and 30 m, while keeping it cheap to draw. That covers item looks (tools, weapons, armour, food, materials, kits), furniture and structure models, fauna models, and fixes to flora models (tree and shrub shapes, bark, fruit, flowers). It starts where a design says "this thing exists" (Sal's item rows, Tyler's structures, flora.json rows) and ends when the model is built, rated honestly, shown in the real game, and approved by Dave on a QA card. It does not cover item data, recipes, balance (Sal), server logic and the light code of lit fixtures (Tyler), where flora grows and how thick (flora session), the foliage shader, water, body, camera and stance (Sonny). I never merge into the daily branch.

## 2. Done so far (kathleen-art; the daily holds everything up to 27833d45)
- Lean-to with long sloped roof and collider (ridge 1.5 m, about 35 degrees): see `art/CRITIQUES/leanto_2026-10-31`, test `test_leanto_collider`.
- Lit fixtures (fireplace front 4.5, torch and chandelier 4): `art/CRITIQUES/lit_2026-10-31`, `real_game_2026-10-31`.
- Tall-grass panicle tips and far cue; meadow flowers rounds 1 to 3 (eb4bab27, flora rated 4/5 at 10 m); round apples; crown variety (all in tree_builder.gd).
- Fibre cloth, chopping block, ten distinct kits, larger hands: `fibre_cloth_`, `kits_` critiques.
- Felled trunk, stump and log bark in the real game: 27833d45 (shader `lift`, softwood tint fallback).
- Docs and queues: 54fe1cb9 (orchard real-game shots), ed41278e (ITEM_ART_STATUS), 38a51028 (ART_TASKS), 82fd3f80 (handoff).
- QA cards on the qa branch: pic-orchard, pic-fibre-cloth, pic-kits, pic-hands, pic-meadow-flowers, pic-apples, pic-crown-variety, pic-fireplace-light, pic-orchard-real, pic-felled-bark-after, pic-hold-stone-axe.

## 3. Plan, in order
1. Re-run the lying-trunk fall shot (rig `--shot-fell=flat`, quiet PC) and post one card. Only for trees that really fall: Dave's rule is that a stump still in the ground is chopped to nothing (firewood and kindling, no fallen log), so no more stump-chopping shots.
2. Orchard and crown close-ups in game (about 15 m north of the orchard, 53376,68506 yaw 180), two cards.
3. Cut logs (`src/client/log_look.gd`): bark on the sides, pale cut face with ring.
4. Held stone axe: darker, chipped stone head (card pic-hold-stone-axe rated 3).
5. Real-game pass, one card each: long-roof lean-to with bed, ten kits, larger hands, fibre cloth, white and pink meadow drifts.
6. Firewood and kindling item looks: currently plain bundle shapes in `data/items/looks.json` (firewood #8a5e36, firewood_soft #9a7a4a, kindling #a8845a size 0.6), world drop as a split stick in inventory_view.gd. Make them read as split wood and a handful of thin sticks; check in game.
7. Weakest pictures in `art/playthrough` (rated 1 to 3): fix the worst three.
8. Not yet modelled: log cabin set piece, woven texture on fibre cloth, thatch seen from behind (second offset layer), furniture rows in structures.json (with Tyler and Sal).

## 4. Priorities, ranked
1. Things Dave sees first in play (trees, felled trees, the held tool, fire): they decide whether the game looks real.
2. Real-game verification of what is only rendered offline: a model that passes the sheet but not the game is not done.
3. Firewood, kindling and logs: the everyday wood items every player handles.
4. Kits and furniture: the build-up of a camp.
5. Rare set pieces and polish (log cabin, cloth weave, thatch back): last, cheap to defer.

## 5. Dependencies
I depend on: Sal (item numbers, new items arriving without looks: `test_item_looks` catches them), Tyler (structure rows, fixture light, flame colour, rig `--dev-place`), the flora session (densities, foliage shader; they rate flora pictures), Sonny (stance, grass over feet), the moderator (merging, QA page, Dave's rules). Depending on me: Sal and Tyler for looks of new items and structures; flora for tree, flower and fruit models; the Guide for in-game pictures of crafted things.

## 6. The job is finished when
Every item in `data/items` and every structure and flora row has a look that passes `test_item_looks`, `test_look_table`, `test_structure_looks`, `test_tool_looks`, `test_flora_budget`; every item Dave can meet in the first hours has been seen in the real game at 10 m and rated 4 or more by me and accepted (Yes) on its QA card; and `ITEM_ART_STATUS.md` shows no "rough" row among items a player meets before the first winter.
