# Item icons (Kathleen, 9 Nov 2026)

Where the inventory's item icons live, which ones are baked and which are painted, and how to redo one. The look rules are in `docs/ui/inventory_crafting_redesign.md` section 6.7.

## Where they live

- **`assets/ui/item_icons/<item id>.png`**, one per live item in `data/items/items.json` and `data/items/gathered.json` (item_table.gd loads both). Each is 128 x 128 with no background. The slot adds the soft shadow, so it is not painted in.
- **`<item id>.png.import`** sits beside each PNG. `tools/import_item_icons.py` writes it the way Godot would. The cloud never runs an editor import, and `ResourceLoader.exists` needs this file to find the icon.
  - The uid comes from a hash of the id, so it is the same every time the file is written.
  - The cache path comes from the res:// path, so repainting a PNG does not change its `.import`.
- **`InventoryLook.icon_for(id)`** loads `res://assets/ui/item_icons/<id>.png` and caches it (`src/client/ui/inventory/inventory_look.gd`).
  - An id with no file shows the hatched "?" tile (art brief row 27), never a blank.

## Baked or painted

All 598 live items have an icon: 424 in `items.json` and 174 in `gathered.json`. There are two kinds.

| Kind | Count | Made by | Ran where |
|---|---|---|---|
| **Baked** | 491 (323 made items, 168 gathered materials) | `tools/icon_bake.gd`: the item's real game mesh (`basic_look.gd mesh_for`) in a fixed light rig | Dave's PC only (it needs the real renderer, so it cannot run headless) |
| **Painted, basic** | 2 (log, stone) | `tools/paint_basic_icons.py` | Anywhere; Python with numpy and Pillow |
| **Painted, made pieces** | 71 (walls, floors, roofs, stairs, ladder, log species, driftwood, furniture, stations, fires, torches, traps, carcass) | `tools/paint_structure_icons.py` | Anywhere; Python with numpy and Pillow |
| **Painted, small items** | 34 (spears, arrows, stick, spades, the 14 crop seeds, pies; kindling, tinder, thatch, straw, birch bark, withies): items the bake drew too thin or too alike to read at 23 px, and the common fire and shelter materials | `tools/paint_item_icons.py` | Anywhere; Python with numpy and Pillow |

**The painted list is the code.** It is `("log", "stone")` plus `NAMES` in `tools/paint_structure_icons.py` and in `tools/paint_item_icons.py`, each the keys of that file's `PIECES` dict. The importer reads that same list as `PAINTED`, so there is no second copy to keep in step. To print it:

```
python3 -c "import sys; sys.path.insert(0, 'tools'); import import_item_icons as i; print(len(i.PAINTED), i.PAINTED)"
```

**A painted icon is never replaced by a bake.** When a baked folder is imported, an id in `PAINTED` is skipped if its PNG is already there. Every other live item is baked.

## The painted rig

All three painters share the rig in `paint_basic_icons.py`:

- low-poly, flat-shaded facets;
- a warm key light from the top left, a fill of 0.38 and a gold rim;
- a three-quarter view (`VIEW`);
- the object fills about 80 % of the square;
- drawn at 4x and scaled down.

`paint_structure_icons.py` builds each piece from boxes, log prisms and uprights in its material's colours. It draws them with a z-buffer, so faces that cross still show the right way round.

`paint_item_icons.py` uses the same z-buffer render, with three rules for items that must read at 23 px (the recipe list at 1366 x 768):
- **Thin things** are drawn thick, on the diagonal, with an oversized head. Arrows are a fan of three, and blades are rolled toward the key light so they don't come out dark.
- **Each item in a set has its own colour**: spade blades in wood, stone, iron or steel; each crop seed shows its crop.
- **A set shares one layout**: every crop seed is a pile of its seed with the crop beside it.

- **Glowing faces.** A colour with a fourth value of 1 is drawn unlit. Coals, embers, flames and gems use this.
- **The turn.** Each `PIECES` entry is `(builder, turn)`. The turn picks the side shown: walls show their face, slabs their top, roofs both slopes, and logs their cut ends toward the light.

## How to repaint one

1. Change the builder in `tools/paint_structure_icons.py` or `tools/paint_item_icons.py`, or in `paint_basic_icons.py` for log and stone.
2. Repaint only that icon:
   ```
   python3 tools/paint_structure_icons.py --only stone_forge,oven
   ```
   It writes into `assets/ui/item_icons/` by default. Pass `--out DIR` to paint into a scratch folder and look at it first.
3. Look at it at slot size (100 px) and at 32 px against the slot colour. It must still read as a solid shape at 32 px (the silhouette test in `icon_bake.gd`).
4. Commit the PNG. Its `.import` stays as it is.

**Adding a new painted item:**
- Add a builder and a `PIECES` entry, then paint it with `--only <id>`.
- Run `python3 tools/import_item_icons.py --imports-only` to write its `.import`.
- The importer prints how many live items still have no icon. That count should not go up.

**Moving an item from baked to painted:** add it to `PIECES` and paint it. Its PNG is overwritten, and from then on bakes skip it.

**Moving it back:** take it out of `PIECES`, then re-import a bake of that id (below).

## How to rebake

This runs on Dave's PC, in a run he has asked for.

```
godot --path . --script res://tools/icon_bake.gd -- --out=C:/temp/item_icons --sheet=C:/temp/item_icon_sheet.png --items=id,id
python3 tools/import_item_icons.py C:/temp/item_icons
```

- The bake also writes `NEEDS_PAINTING.txt`. That lists the items with no game mesh, or only the grey placeholder chunk; they need a painted icon instead.
- The importer refuses some files and says why: an id that is not a live item (retired or unknown), a size other than 128 x 128, or a PNG with no alpha.

**Removing an icon** (for example, its item was retired): move the PNG and its `.import` to `proposed_removals/` with a row in `REMOVALS.md`, the same as other deleted files.

## Gathered materials (gathered.json)

`data/items/gathered.json` holds 174 gathered materials: kindling, tinder, thatch, straw, bark, berries, herbs and the rest. Until 9 Nov the bake and the importer read only `items.json`, so none of them had an icon, and the "424 of 424" count left them out.

Now both tools read `gathered.json` too, and all 174 have an icon:
- 168 come from Dino's bake of 9 Nov. Every one has a look in `looks.json`, and the steps are in `gathered_icons_job.md` in the shared files.
- 6 are painted: kindling, tinder, thatch, straw, birch bark and withies.

**Known weak spots.** These read as their kind at slot size, but not as themselves, because the bake draws each family with one shape and only the tint differs:
- about 30 herbs and leaves (the "frond" look);
- 22 flowers;
- 12 roots.

They are thin at 23 px, the same problem the seeds had, and they are the next painting batch.

## Contact sheets

The sheets Dave looked at are in the shared project files, under `inventory/`:
- `item_icons_in_repo_sheet.png`, the baked set;
- `icons_batch1_sections.png`, `icons_batch2_logs.png`, `icons_batch3_furniture.png` and `icons_batch4_stations.png`, the painted batches.
- `gathered_icon_sheet.png` (shared top level), the gathered bake, and `inventory/icons_gathered_painted6.png`, the six painted gathered materials.
