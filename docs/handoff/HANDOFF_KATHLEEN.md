# Kathleen (art, animation, sound look) handoff, 11 Nov 2026

Main at handoff: bd3146aa (#1019). Copy in the repo: `docs/handoff/HANDOFF_KATHLEEN.md`. The older 1 Nov handoff is in `docs/archive/2026-11/HANDOFF_KATHLEEN_2026-11-01.md`.

## Role and boundaries
I own how things look: building pieces, items, icons, world resources (boulders, deposits), held items. Not mine: item data, names, recipes and yields (Jamie); server rules, rows and streaming (Steve); water and terrain (Sonny); design decisions (Morgan); gates (David4); merges (Tyler). Rig shots on Dave's PC are Dino's. Dave approves looks, and so does the coordinator, which has approval authority.

## How I work (keep this)
1. Sheet first. Render a sheet offline with `tools/look_runtime.py` (a GDScript-to-Python transpiler: `lr.build(name)`, `lr.triangles(root)` gives the true Godot triangle count; use it, because `faces_of` returns boxes as quads and under-counts). Put the sheet in `/mnt/project-files/kathleen/` and get approval.
2. Build in `src/client/piece_look.gd` and register it in `src/client/look_table.gd`. Keep each look under its cap in `src/worldgen/tools/test_look_table.gd` (default 300; add a named dict entry when a look is genuinely bigger, as was done for TILE_ROOFS and FORTIFIED). Placed structures also meet `test_structure_looks*.gd`: the footprint must stay within ±w/2+0.04, plus the height cap.
3. Icons for pieces are drawn from their looks: add to `tools/paint_look_icons.py` ITEMS (SHORTEN for roofs), then run `import_item_icons.py --imports-only`, and update the counts in `docs/ui/item_icons.md`.
4. Lint: zero new warnings. No integer division, no shadowed locals; cast `duplicate()` with `as`.
5. One PR at a time on the branch, off main. Gate at David4 through the coordinator (no cloud Godot runs). Look-only PRs gate on `test_look_table` plus the always set.
6. Check it in the real game with a look-rig shot (Dino):
   - `tools/look_rig.sh --look NAME` gives four views of a look, and `--looks a,b,c` a row of them.
   - `--pieces` takes structures by name.
   - `--give ID --lit` shows a lit torch or lantern in hand. Without `--lit`, a dark twin stays dark.
   - Also: `--cam first|left|right --dist M --pitch DEG --hour H --at X,Z --nograss`.
   - The rig log prints the held model's on-screen spot (#1018).
   - Good bare spot for buildings: beach sand at (52752, 67792), 616 m from spawn.

## Materials conventions
- One shared material per kind.
  - `_tone_mat(Color)` gives flat colours, cached per colour.
  - `_blocks_material(base, blocks, seed, mottle)` draws a courses texture once: `_brick`, `_slate`, `_tile`, `_flag`, `_mortar` and `_concrete` in `_tier_materials()`.
  - `_iron_mat()` is used for every iron part.
- Real geometry for silhouettes against the sky, such as shingle rows, ridges, merlons and slits. Textures only on flat faces.
- World resources that only need a distinct look reuse the shared mesh with a per-kind duplicate of the shader material, made once (outcrops: `inventory_view._boulder_material`, `OUTCROP_LOOK`, `OUTCROP_MOSS` 0.2).
- Held flames: the light's cull mask leaves out layer 2 (the held model's own meshes), so the model isn't over-lit at arm's length. A torch has a short HandLight so the fist isn't black.

## Approved looks (shipped)
- **Tier ladder:** Crude, Rustic, Refined, Sturdy, Superior, Engineered and Fortified, with pitched roofs and hip corners per tier, and ceilings (#973, #989, #1017). The table is `art/BUILDING_TIERS_LOOKS.md`.
  - Engineered roof is deep red clay tile on planks.
  - Fortified has a banded concrete wall, iron door, gate with lintel and brace, and a battlement wall top.
- **Bog iron deposit patch** (#1012): three ragged rust blobs and seven ore domes.
  - Wet adds water and an oily film; dug adds peat cuts.
  - An optional `ground` Callable drapes it over a rise.
  - Triangles: dry 194, wet 280, dug 290.
- **Outcrop boulders** (#1015, #1019): per-ore tint, streaks and flecks, with little moss.
  - Tin: dark cassiterite veins in a pale quartz host.
  - Copper: green malachite.
  - Iron: rust.
  - Coal: black seams.
  - Salt: pale crusts.
  - Limestone, chalk and marble: their own bedding.
- **Dark lantern icons** (#990).

## Rejected looks (do not bring back)
- A concrete roof: #972, and Dave said "bandit concrete would not make a good roof".
- Flat painted roof icons.
- A neon or glowing ore tell; the brief is to read from about 10 m.
- Heavy moss on outcrops.
- Rejected words for tiers and pieces: Wattle, Timber, Grand, Elegant, Solid, Robust, Stalwart. No "floor" in display names.

## Next work (not started; ready to pick up)
1. **Lantern horn glow, flame core and hand light.** Approved by the coordinator 10 Nov, but it isn't in a PR. It's commit `28596b75` on branch `claude/project-thread-rfqwpe`: cherry-pick it onto a fresh branch off main.
   - `held_item._make_lantern_model` gets HORN_GLOW_SHADER: brightest at flame height, dimmer at the corners.
   - A small bright flame core: narrow candle in wood, wider oil flame in iron.
   - A 0.6 m HandLight.
   - Then Dino takes one −55° first-person shot on the beach at 22:00 with `--give wooden_lantern --lit`.
2. **`_show_bog` hookup.** Draw the bog patch in the world. #997 is merged, so the deposit rows exist: `[id, 0, left, pos, 229 BOG_STATE, {"key","total","wet"}]`, with ids counting down from 2e9.
   - My draft is `bog_show.patch` in my scratchpad, which is lost with this session. Rewrite it from this description.
   - In `inventory_view._note_bog`, call `_show_bog(id)`.
   - The state is "wet" if wet, "dug" if left < total, else "dry". Rebuild only when the state changes.
   - Yaw comes from a hash of the key. Use `PieceLook.bog_iron_patch(state, ground)`, where `ground` is `func(x, z)` returning the ground height under the patch (from `_ground_below`, with NAN treated as 0) minus the patch's own height.
   - Store the node in `bogs[id]["node"]`; `_forget` already frees it.
3. **Outcrop retake.** A tin outcrop in open sun at 11:00, from 10 m and 4 m, after #1019. Dino has the request. The last shot was in deep shade, before the moss fix.

## Open questions for Dave (on the QA page)
- Do the Fortified pieces look right?
- Do the tier roofs look right?
- Is the outcrop tell strong enough?
- Is the bog patch right?
- Should the lantern follow-up ship?
- Character stylisation (ART_DIRECTION.md s54).

## Gotchas
- `tools/look_runtime.py` lacks some Godot API; add what you need: `floori`, `Vector3(0,-1,0)` for DOWN, and a `Callable` stand-in.
- Godot front faces are clockwise. `_tri_out(st, a, b, c, out)` fixes the winding toward `out`.
- A failed shader compile draws flat grey or magenta. Check every `String.replace` target exists exactly once in the source shader.
- Force push and amend are blocked on the branch. After a merge: `git checkout -B <branch> origin/main && git merge -s ours origin/<branch>`, then push.
