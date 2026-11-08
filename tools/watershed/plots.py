"""Pictures of the watershed stages, drawn from their saved outputs so they can be redrawn in seconds without rerunning a stage.

Usage (on Dave's PC):
  python tools/watershed/plots.py ground OUT_DIR      # redraws OUT_DIR/evolve.png from OUT_DIR/ground.npz (stage B)
  python tools/watershed/plots.py zoom OUT_DIR X Z [SIZE_M]   # OUT_DIR/zoom_X_Z.png: a SIZE_M square (default 6 km) at 16 m"""
import sys
import numpy as np


def ground_picture(npz_path, png_path):
    """Six panels, so the result can be judged by eye:
    landform and final ground on ONE height scale (so a rise or a cut shows as a colour change, not a rescale);
    height change (red rose, blue cut): where erosion has not reached, the change is close to the full uplift;
    rivers (quick-runoff area of 5 ha or more, darker as it grows) and closed hollows (red) on a grey hillshade;
    sediment thickness; slope (texture: evenly corrugated ground would show here)."""
    import matplotlib; matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.colors import LightSource
    d = np.load(npz_path)
    g = d['ground'].astype(np.float64); s0 = d['start'].astype(np.float64); sea = d['sea'].astype(bool)
    dx = float(d['cell_m']); land = ~sea
    ls = LightSource(315, 40)
    top = float(max(g[land].max(), s0[land].max()))
    shade = ls.hillshade(np.where(land, g, 0.0), vert_exag=3, dx=dx, dy=dx)
    fig, ax = plt.subplots(2, 3, figsize=(24, 16))
    for a, z, t in ((ax[0, 0], s0, 'landform (start)'), (ax[0, 1], g, 'final ground (same height scale)')):
        rgb = ls.shade(np.where(land, z, -top * 0.02), cmap=plt.cm.terrain, vert_exag=3, blend_mode='soft', dx=dx, dy=dx,
                       vmin=-top * 0.02, vmax=top)
        a.imshow(rgb); a.set_title(f'{t}, max {z[land].max():.0f} m')
    ch = np.where(land, g - s0, np.nan)
    lim = float(np.nanpercentile(np.abs(ch), 99.5)) or 1.0
    im = ax[0, 2].imshow(ch, cmap='RdBu_r', vmin=-lim, vmax=lim); ax[0, 2].set_title('height change (m): red rose, blue cut')
    fig.colorbar(im, ax=ax[0, 2], shrink=0.6)
    ax[1, 0].imshow(np.where(land, shade, np.nan), cmap='gray', vmin=0, vmax=1)
    if 'quick_area_m2' in d.files:
        q = d['quick_area_m2'].astype(np.float64)
        riv = np.where(land & (q >= 5e4), np.log10(np.maximum(q, 5e4)), np.nan)
        ax[1, 0].imshow(riv, cmap='Blues', vmin=4.0, vmax=float(np.nanmax(riv)) if np.isfinite(riv).any() else 8.0)
    if 'pit_m' in d.files:
        pit = d['pit_m'].astype(np.float64)
        ax[1, 0].imshow(np.where(land & (pit > 0.1), 1.0, np.nan), cmap='autumn', vmin=0, vmax=1)
    ax[1, 0].set_title('rivers: quick-runoff area 5 ha and more (darker = more water); closed hollows 0.1 m deep and more in red')
    ax[1, 1].imshow(np.where(land, shade, np.nan), cmap='gray', vmin=0, vmax=1)
    im = ax[1, 1].imshow(np.where(land & (d['sediment_m'] > 0.05), d['sediment_m'], np.nan), cmap='YlOrBr', vmin=0, vmax=10, alpha=0.85)
    ax[1, 1].set_title('sediment (m): floodplains, fans, deltas'); fig.colorbar(im, ax=ax[1, 1], shrink=0.6)
    gy, gx = np.gradient(g, dx)
    im = ax[1, 2].imshow(np.where(land, np.degrees(np.arctan(np.hypot(gx, gy))), np.nan), cmap='magma', vmin=0, vmax=45)
    ax[1, 2].set_title('slope (deg)'); fig.colorbar(im, ax=ax[1, 2], shrink=0.6)
    for a in ax.ravel():
        a.axis('off')
    plt.tight_layout(); plt.savefig(png_path, dpi=60); plt.close(fig)


def zoom_picture(npz_path, png_path, x_m, z_m, size_m=6000.0):
    """A close look at full resolution (one pixel per 16 m cell): a size_m square centred on world x_m, z_m, as a hillshade
    with the rivers (quick-runoff area 5 ha and more), the landform beside it and the slope. The overview pictures are about
    100 m a pixel, too coarse to tell branching valleys from straight parallel gullies; this shows which the ground has."""
    import matplotlib; matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.colors import LightSource
    d = np.load(npz_path)
    dx = float(d['cell_m']); ox = float(d['origin_x']); oz = float(d['origin_z'])
    n = d['ground'].shape[0]
    half = int(round(size_m / dx / 2.0))
    ci = int(round((x_m - ox) / dx)); cj = int(round((z_m - oz) / dx))
    i0, i1 = max(ci - half, 0), min(ci + half, n); j0, j1 = max(cj - half, 0), min(cj + half, n)
    win = (slice(j0, j1), slice(i0, i1))
    g = d['ground'].astype(np.float64)[win]; s0 = d['start'].astype(np.float64)[win]; land = ~d['sea'].astype(bool)[win]
    ls = LightSource(315, 40)
    fig, ax = plt.subplots(1, 3, figsize=(30, 10.5))
    ext = (ox + i0 * dx, ox + i1 * dx, oz + j1 * dx, oz + j0 * dx)
    for a, z, t in ((ax[0], s0, 'landform (start)'), (ax[1], g, 'ground, rivers 5 ha and more')):
        a.imshow(np.where(land, ls.hillshade(np.where(land, z, 0.0), vert_exag=2, dx=dx, dy=dx), np.nan), cmap='gray', vmin=0, vmax=1,
                 extent=ext)
        a.set_title(f'{t}, max {z[land].max():.0f} m' if land.any() else t)
    if 'quick_area_m2' in d.files:
        q = d['quick_area_m2'].astype(np.float64)[win]
        riv = np.where(land & (q >= 5e4), np.log10(np.maximum(q, 5e4)), np.nan)
        ax[1].imshow(riv, cmap='Blues', vmin=4.0, vmax=float(np.nanmax(riv)) if np.isfinite(riv).any() else 8.0, extent=ext)
    gy, gx = np.gradient(g, dx)
    im = ax[2].imshow(np.where(land, np.degrees(np.arctan(np.hypot(gx, gy))), np.nan), cmap='magma', vmin=0, vmax=50, extent=ext)
    ax[2].set_title('slope (deg)'); fig.colorbar(im, ax=ax[2], shrink=0.7)
    fig.suptitle(f'{size_m / 1000:.1f} km round x {x_m:.0f}, z {z_m:.0f} (world metres)')
    fig.tight_layout(); fig.savefig(png_path, dpi=60); plt.close(fig)


if __name__ == '__main__':
    if len(sys.argv) >= 5 and sys.argv[1] == 'zoom':
        # python plots.py zoom RUN_DIR X Z [SIZE_M]: writes RUN_DIR/zoom_<x>_<z>.png
        x_, z_ = float(sys.argv[3]), float(sys.argv[4])
        zoom_picture(f'{sys.argv[2]}/ground.npz', f'{sys.argv[2]}/zoom_{x_:.0f}_{z_:.0f}.png', x_, z_,
                     float(sys.argv[5]) if len(sys.argv) > 5 else 6000.0)
    elif len(sys.argv) == 3 and sys.argv[1] == 'ground':
        ground_picture(f'{sys.argv[2]}/ground.npz', f'{sys.argv[2]}/evolve.png')
    else:
        raise SystemExit(__doc__)
