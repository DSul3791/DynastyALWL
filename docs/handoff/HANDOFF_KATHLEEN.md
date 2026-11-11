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

## Unfinished work (preserved, status noted)
Nothing of mine is half-merged. No art PR is open. The two pieces below are written and approved but were not opened as PRs, because of the no-new-work rule. Both are saved:
1. **Lantern horn glow, flame core and hand light.** Approved by the coordinator on 10 Nov. Not gated, and never run in Godot.
   - Commit `28596b75`. It sits in the history of branch `claude/project-thread-rfqwpe` (reachable, not in the tree), and as a patch in `art/parked/lantern_horn.patch` (copy in `/mnt/project-files/kathleen/parked/`). It applies to main with `git apply -3`.
   - What it does in `held_item._make_lantern_model`:
     - `HORN_GLOW_SHADER` replaces the flat amber box; the glow is brightest at flame height and dims toward the corners.
     - A small bright flame core: a narrow candle in the wooden lantern, a wider oil flame in the iron one.
     - A 0.6 m `HandLight`, so the fist holding the bail isn't grey-dark in first person.
   - Check: one first-person shot at −55° on the beach (52752, 67792) at 22:00, with `--give wooden_lantern --lit`.
2. **`_show_bog` hookup**, which draws the bog patch in the world. `art/parked/bog_show.patch` (copy in `/mnt/project-files/kathleen/parked/`) applies cleanly to main bd3146aa now that #997 is in.
   - `_note_bog` calls `_show_bog(id)`.
   - State: "wet" if wet, "dug" if left < total, else "dry". The patch is rebuilt only when the state changes.
   - Yaw comes from a hash of the key, and the stain drapes over the ground through `_ground_below`, with NAN treated as 0.
   - Not gated, and never run in Godot.
3. **Outcrop retake.** A tin outcrop in open sun at 11:00, from 10 m and 4 m, on main with #1019 (Dino has the ask).

Sheet scripts used for approvals (run them with `tools/look_runtime.py` on the path) are in `/mnt/project-files/kathleen/parked/*_sheet.py`.

## Outstanding bugs and risks (art)
- The carried lantern pane reads as a flat amber card, and the left fist is grey-dark in first person. The fix is item 1 above.
- The tin outcrop has only been seen in deep shade and before the moss fix (#1019). Its 10 m read is unconfirmed.
- The bog patch can't be seen in game until item 2 lands.
- The tier roofs and ceilings (#973) have never been shot in the world. They're checked only by offline sheets and the triangle tests.
- From 1 Nov, still open: thatch seen from behind reads as paper triangles; cut logs are plain blocks; the stone axe head is pale and blocky.

## Visual systems verified only by eye (no automated check)
Headless tests prove that a look builds, fits its footprint and stays under its triangle cap. They don't prove it looks right or that a shader compiles. These are checked only by pictures:
- Every look in `look_table.gd`: the sheets, plus Dino's rig shots where they exist (Fortified yes, roofs no).
- The outcrop shader splice (`OUTCROP_GLSL` and the uniforms replaced into `BOULDER_SHADER`). A broken replace shows as flat grey or magenta boulders, and no test catches it. The 10 Nov shot showed 0 shader errors.
- The lantern lights: their range, the cull mask (layer 2), whether a dark twin stays dark, and the hand light.
- All item icons (the `paint_look_icons.py` output).
- Roof hip corners lining up with the straight pieces, and the Fortified wall top over pillars (`kathleen/fortified_wall_top_joint.png`).

## Important technical decisions
- Tier roofs come from one data-driven builder (`ROOF_SPEC`), not one function per tier, so a new tier is one row.
- Shingle and tile courses are real geometry, which is why the clay-tile roofs need the 350/400 caps. The coordinator chose raising the caps over trimming rows (#973 gate).
- Outcrops change the shader material only (no new mesh or triangles), with one material per ore made once. The client reads `"ore"` straight from the row; Steve's `boulder_info` accessor (#1008) was closed as not needed.
- The bog patch is drawn on the client from server rows (BOG_STATE 229), because the client has no water-class map.
- Concrete foundations: the footing steps run down to the body's foot, so a dipped corner never shows a ledge.

## Lessons and failed approaches (not written down elsewhere)
- Never estimate triangles from `look_runtime.faces_of`: boxes come back as quads, and I under-counted the brick roofs (308) and corners (382), which failed the gate. Use `lr.triangles(root)`.
- Bolt heads and brackets placed "on the face" stuck out past the footprint test's ±w/2+0.04 limit. Centre them on the face.
- Rib and band clipping: the edge point is `a.lerp(b, da / (da - db))`. The first formula fanned the ribs.
- Shadowed or tree-cover rig spots make a look unjudgeable. Shoot on the bare beach at (52752, 67792); 11:00 for day, 22:00 for night.
- A "gap" under a building in a shot is usually an overhanging footing step seen at a dipped corner, not a float. Check the body depth before you call it a placement bug.
- Moss on the shared boulder shader (0.65) swamps any tint. Any new per-kind boulder look needs its own mossiness.
- First-person held items at the hip are out of frame above −45° pitch. Use −55°.
- The rig selecting before the pack arrived left both hands empty. That's fixed in #1016; #1018 added the in-frame log line, so a missing model now says why.
- `look_runtime.py` lacks some Godot API (`Vector3.DOWN`, `floori`, `Callable`). Add stand-ins to it, not workarounds in the look code.

## Next steps I recommend
1. Ship item 1 (lantern) and item 2 (`_show_bog`): each is one small look PR, gated by `test_look_table` plus the always set, then one rig shot each.
2. A rig pass on the tier roofs and ceilings: `--looks` for the rows on the beach at 11:00, then fix whatever reads badly.
3. Get Dave's answers on the art questions on the QA page before any new look work.

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
