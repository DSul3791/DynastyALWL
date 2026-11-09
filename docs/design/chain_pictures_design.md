# Faster chain pictures, drawn from a thinned copy (design note; Sonny, 9 Nov 2026)

## Why

Nine tiles take about 68 min end to end, and Dave's rule (d) asks for well under 1 h. The parts are measured; the sum is not. The glacial cut B is estimated to take off about 8 min, so other cuts are needed too. This one is exact for every data file: only the PNG pixels change.

The chain draws 11 pictures:
- evolve: one per ground file, 7 in all (the snapshots and the end);
- glacial, lakes, groundwater and network: one each.

Each picture hands matplotlib the full 16 m grid for every layer of every panel. That is about 3,000 cells a side for nine tiles (estimate). The panels are 60 dpi and about 480 to 660 px wide. So matplotlib colour-maps and then resamples about 9 million cells per layer, about three times per layer, because the layout pass draws too.

In the glacial one-cycle profile (`glacial_split_profile_ws580v.txt`), `glacial_picture` took 15.7 s of the 87 s. Of that:
- image making was 10.1 s (`_make_image`, 30 calls);
- colour mapping was 2.7 s;
- resampling was 2.6 s;
- hillshade was 1.4 s.

## What changes

`tools/watershed/plots.py` only.

- **The thin factor.** `_thin_factor(n) = max(1, n // 700)`. The factor is a whole number, chosen so the thinned layer is never under 700 px a side. No panel is wider than 660 px, so matplotlib still only shrinks, as it does now. At about 3,000 cells a side the factor is 4, so each layer has 16 times fewer cells.
- **Two ways to thin a layer.** Both work over factor-by-factor blocks.
  - **Mean** of the cells in the block that are not empty. It is used for heights, hillshade, RGB and every measured field. A block with one river or sediment cell still shows it, at its own value. A block with no such cell stays empty and shows through, as now.
  - **Max**, for codes: the lake and hollow causes, the reach types, the streams, the pattern and the wetlands. A one-cell stream still lights its whole pixel. Where codes meet in a block, the higher code shows. For the lake and hollow causes, that is the red "unexplained" or "none", which is the one a reader looks for.
- **Same coordinates.** Each thinned layer is drawn with `extent` set to the full grid, and the axes are held to the full grid. The marks that are plotted in cell units stay where they are:
  - closed lakes, falls and outlets;
  - the groundwater heads.
- **Done at full resolution, then thinned.**
  - Hillshade, `LightSource.shade`, the slope gradient and the percentile limits. They cost about 1 to 3 s a picture. Doing them on the thinned grid would smooth the relief and lower the slopes, so the look would change.
- **Network's `thick`.** The 3-cell max filter in `network_picture` is kept only when the factor is under 3. It was there because one 16 m cell is under a pixel. The block max already widens a one-cell stream to a whole pixel, and both together would draw the streams bolder than now.
- **Zoom pictures.** They are a 6 km window, about 375 cells, and keep factor 1. Pictures of a small test grid also keep factor 1, so they are the same as before.

## What stays the same

- Every `.npz`, `.json` and manifest: the pictures only read them.
- Each stage's own `seconds` count, which stops before its picture.
- The panels, colours, titles, colour bars and figure sizes. (Thin and sparse layers do now show more plainly: see "Measured".)

## Expected

These are estimates.
- A picture drops from about 10 to 16 s to about 3 to 5 s. What is left is mostly the full-resolution hillshade and shading, and matplotlib's fixed cost.
- For the 11 pictures, that is about 1 to 2 min off nine tiles, most of it in evolve.

## Check (Dino; pre-approved by the coordinator)

1. **One glacial cycle on the branch:** `glacial.npz` is array-equal to the profile job's one cycle. The new `glacial.png` is copied to the shared folder, and the history-done time is noted.
2. **The five kinds of picture redrawn from ws580v's saved outputs**, once with main's `plots.py` and once with the branch's, each timed. Both sets are copied to the shared folder side by side, to judge by eye:
   - evolve, glacial, lakes, groundwater and network;
   - the bar: the same rivers, lakes, hollows and colours; nothing lost.
3. **No cloud runs.** The cloud ran only static checks.

## Measured (Dino, 9 Nov, branch head b8e3a698; `pictures_thin_ws580v.txt`)

- **The check:** one glacial cycle's `glacial.npz` is all same, and the history is done at t 36 s. The grid is 2,881 cells a side, so the thin factor is 4.
- **The five pictures, main's code against the branch:**

| picture | main | branch |
|---|---|---|
| evolve | 13.1 s | 6.5 s |
| glacial | 14.4 s | 5.7 s |
| lakes | 8.9 s | 3.8 s |
| groundwater | 11.5 s | 3.5 s |
| network | 19.1 s | 5.1 s |
| all five | 67.0 s | 24.6 s |

  Over the chain's 11 pictures (evolve draws 7), that is about 82 s off nine tiles.
- **By eye (Dino on network and lakes, Sonny on evolve, glacial and groundwater):** the same islands, rivers, lakes, hollows, colours and marks; nothing lost. Pixels that differ a lot: 0.4% (glacial) to 1.9% (network).
- **One difference, from what was designed.**
  - Main's pictures faded thin and sparse layers almost to nothing. Matplotlib's own shrinking weighs each pixel by how much of it has a value.
  - The branch draws a block with any value at full strength, so these layers now show plainly. That covers the rivers in evolve and lakes, the channels and springs in groundwater, the small lakes, and the till and sediment washes. On main, groundwater's "coming out" and channel panels were near blank.
  - The colour where a layer shows is its own value. What reads denser than it is, is how much of a 64 m block the layer covers.
  - The lakes basin panel looks bluer for the same reason: its rivers now show. The basin colours are the same seeded palette.
  - Where an exact old look matters, the fix is to weigh each block's opacity by its share of cells with a value. It was not done, because the old look hid what the panels are titled for.
