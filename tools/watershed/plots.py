"""Pictures of the watershed stages, drawn from their saved outputs so they can be redrawn in seconds without rerunning a stage.

Usage (on Dave's PC):
  python tools/watershed/plots.py ground OUT_DIR      # redraws OUT_DIR/evolve.png from OUT_DIR/ground.npz (stage B1)
  python tools/watershed/plots.py glacial OUT_DIR     # redraws OUT_DIR/glacial.png from OUT_DIR/glacial.npz (stage B2)"""
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


def glacial_picture(npz_path, png_path):
    """Six panels for the glacial history:
    the river-era ground with the largest ice extent over it (blue, darker = thicker);
    the final ground on the same height scale;
    what the ice and its meltwater cut (blue) and laid down (red) over the cold stage;
    till and moraine (under or at the ice, brown) and outwash (beyond it, yellow);
    closed hollows by what made them: ice-scoured floor (blue), glacial deposit sill (orange), other sediment sill (yellow),
    none of these (red: R3 fills them);
    slope."""
    import matplotlib; matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.colors import LightSource, ListedColormap
    d = np.load(npz_path)
    g = d['ground'].astype(np.float64); b1 = d['b1_ground'].astype(np.float64); sea = d['sea'].astype(bool)
    dx = float(d['cell_m']); land = ~sea
    ls = LightSource(315, 40)
    top = float(max(g[land].max(), b1[land].max()))
    shade_b1 = ls.hillshade(np.where(land, b1, 0.0), vert_exag=3, dx=dx, dy=dx)
    shade = ls.hillshade(np.where(land, g, 0.0), vert_exag=3, dx=dx, dy=dx)
    fig, ax = plt.subplots(2, 3, figsize=(24, 16))
    ice = d['ice_max_m'].astype(np.float64)
    ax[0, 0].imshow(np.where(land, shade_b1, np.nan), cmap='gray', vmin=0, vmax=1)
    im = ax[0, 0].imshow(np.where(land & (ice > 0), ice, np.nan), cmap='Blues', vmin=0, vmax=max(float(ice.max()), 1.0), alpha=0.8)
    ax[0, 0].set_title(f'river-era ground, largest ice extent (m thick), {(land & (ice > 0)).sum() * dx * dx / 1e6:.1f} km2')
    fig.colorbar(im, ax=ax[0, 0], shrink=0.6)
    rgb = ls.shade(np.where(land, g, -top * 0.02), cmap=plt.cm.terrain, vert_exag=3, blend_mode='soft', dx=dx, dy=dx, vmin=-top * 0.02, vmax=top)
    ax[0, 1].imshow(rgb); ax[0, 1].set_title(f'final ground (same height scale as B1), max {g[land].max():.0f} m')
    cut = np.where(land, -d['glacial_cut_m'].astype(np.float64), np.nan)
    lim = float(np.nanpercentile(np.abs(cut), 99.5)) or 1.0
    im = ax[0, 2].imshow(cut, cmap='RdBu_r', vmin=-lim, vmax=lim); ax[0, 2].set_title('cold stage: cut (blue) and laid down (red), m')
    fig.colorbar(im, ax=ax[0, 2], shrink=0.6)
    ax[1, 0].imshow(np.where(land, shade, np.nan), cmap='gray', vmin=0, vmax=1)
    ax[1, 0].imshow(np.where(land & (d['outwash_m'] > 0.2), d['outwash_m'], np.nan), cmap='YlOrBr', vmin=0, vmax=20, alpha=0.5)
    im = ax[1, 0].imshow(np.where(land & (d['till_m'] > 0.2), d['till_m'], np.nan), cmap='copper_r', vmin=0, vmax=30, alpha=0.85)
    ax[1, 0].set_title('till and moraine (brown, m), outwash (yellow)'); fig.colorbar(im, ax=ax[1, 0], shrink=0.6)
    hc = d['hollow_cause'].astype(np.float64)          # per hollow, as in the summary: 0 ice-scoured floor, 1 glacial deposit
    cls = np.where(land & (hc >= 0), hc, np.nan)        # sill, 2 other sediment sill, 3 none; -1 no hollow
    ax[1, 1].imshow(np.where(land, shade, np.nan), cmap='gray', vmin=0, vmax=1)
    ax[1, 1].imshow(cls, cmap=ListedColormap(['#1f5fbf', '#f08c00', '#f2d024', '#d62728']), vmin=-0.5, vmax=3.5)
    ax[1, 1].set_title('hollows: ice-scoured (blue), glacial sill (orange), other sediment (yellow), none (red)')
    gy, gx = np.gradient(g, dx)
    im = ax[1, 2].imshow(np.where(land, np.degrees(np.arctan(np.hypot(gx, gy))), np.nan), cmap='magma', vmin=0, vmax=45)
    ax[1, 2].set_title('slope (deg)'); fig.colorbar(im, ax=ax[1, 2], shrink=0.6)
    for a in ax.ravel():
        a.axis('off')
    plt.tight_layout(); plt.savefig(png_path, dpi=60); plt.close(fig)


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == 'ground':
        ground_picture(f'{sys.argv[2]}/ground.npz', f'{sys.argv[2]}/evolve.png')
    elif len(sys.argv) == 3 and sys.argv[1] == 'glacial':
        glacial_picture(f'{sys.argv[2]}/glacial.npz', f'{sys.argv[2]}/glacial.png')
    else:
        raise SystemExit(__doc__)
