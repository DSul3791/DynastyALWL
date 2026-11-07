"""Stage A of the watershed rebuild (docs/water/watershed_rebuild_design.md): the inputs every later stage uses.

Usage (on Dave's PC, never in the cloud):
  godot --headless --path . --script res://src/worldgen/tools/export_raw_heights.gd -- --landform --out=LANDFORM_DIR
  godot --headless --path . --script res://src/worldgen/tools/export_geology.gd -- --step=16 --out=GEOLOGY_DIR
  python tools/watershed/inputs.py LANDFORM_DIR GEOLOGY_DIR OUT_DIR [params.json]

Writes OUT_DIR/inputs.npz (landform, uplift, rain, rock id, soluble mask, sea mask, on the model grid; plus the grid origin and cell),
inputs.png (the four maps) and inputs_manifest.json (parameters, input hashes, summary numbers)."""
import sys, os, json, hashlib
import numpy as np
from scipy.ndimage import gaussian_filter, zoom

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'erosion_precarve'))
import noise, orographic   # noqa: E402

T = 1920          # samples per tile edge (8 m)
SPACING = 8.0


def load_landform(landform_dir, x0, z0, x1, z1):
    nx, nz = x1 - x0 + 1, z1 - z0 + 1
    fine = np.zeros((nz * T + 1, nx * T + 1), np.float32)
    for z in range(z0, z1 + 1):
        for x in range(x0, x1 + 1):
            a = np.fromfile(f'{landform_dir}/raw_{x}_{z}.f32', '<f4').reshape(T + 1, T + 1)
            fine[(z - z0) * T:(z - z0) * T + T + 1, (x - x0) * T:(x - x0) * T + T + 1] = a
    assert np.isfinite(fine).all()
    return fine


def to_model_grid(fine, step):
    """Sample every `step`-th fine sample after a (2 step + 1) box average, so the model grid holds the mean ground."""
    if step == 1:
        return fine.astype(np.float64)
    n = (fine.shape[0] - 1) // step + 1
    r = step
    pad = np.pad(fine.astype(np.float64), r, mode='edge')
    out = np.zeros((n, n))
    for dj in range(2 * r + 1):
        for di in range(2 * r + 1):
            out += pad[dj:dj + (n - 1) * step + 1:step, di:di + (n - 1) * step + 1:step]
    return out / float((2 * r + 1) ** 2)


def world_coords(n, dx, origin_x, origin_z):
    xs = origin_x + np.arange(n) * dx
    zs = origin_z + np.arange(n) * dx
    return np.meshgrid(xs, zs)


def uplift_field(h, sea, X, Z, dx, P, seed):
    u = P['uplift']
    smooth = gaussian_filter(np.maximum(h, 0.0), u['smooth_m'] / dx)
    design = np.clip(smooth / u['ref_height_m'], 0.0, 1.0) ** u['power']
    design = np.maximum(design, u['coast_floor'])
    hills = noise.plane_waves(X, Z, u['hill_wavelengths_m'], u['hill_amplitudes'], seed)
    factor = np.maximum(1.0 + hills, u['min_factor'])
    U = u['base_m_per_yr'] * design * factor
    U[sea] = 0.0
    return U


def rain_field(h, dx, origin_x, origin_z, wind_by_row, z0, P):
    r = P['rain']
    step = max(int(round(r['cell_m'] / dx)), 1)
    coarse = h[::step, ::step]
    cdx = dx * step
    n = h.shape[0]
    rows_per_tile = int(round(T * SPACING / dx))
    rain = np.zeros_like(h)
    # One rain map per distinct wind; each model row takes the map of its tile row's wind (0: mean of both directions).
    maps = {}
    for sign in sorted(set(int(v) for v in wind_by_row.values())):
        dirs = [1, -1] if sign == 0 else [sign]
        acc = np.zeros_like(coarse)
        for d in dirs:
            acc += orographic.precipitation_mm_per_year(coarse, cdx, d * r['wind_m_s'], 0.0, r['background_mm_yr'], r['tau_c_s'], r['tau_f_s'])
        acc /= len(dirs)
        fine = zoom(acc, step, order=1)[:n, :n]
        if fine.shape != h.shape:
            fine = np.pad(fine, ((0, n - fine.shape[0]), (0, n - fine.shape[1])), mode='edge')
        maps[sign] = fine
    for j in range(n):
        tile_row = z0 + min(j // rows_per_tile, len(wind_by_row) - 1)
        rain[j, :] = maps[int(wind_by_row[str(tile_row)])][j, :]
    return np.maximum(rain, r['min_share'] * r['background_mm_yr'])


def sha(path):
    return hashlib.sha256(open(path, 'rb').read()).hexdigest()


def main():
    landform_dir, geology_dir, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    P = json.load(open(sys.argv[4] if len(sys.argv) > 4 else os.path.join(HERE, 'params.json')))
    os.makedirs(out_dir, exist_ok=True)
    x0, z0, x1, z1 = P['tiles']
    man_in = json.load(open(f'{landform_dir}/raw_manifest.json'))
    assert man_in.get('landform'), 'export the landform with --landform'
    step = int(P['model_step'])
    dx = SPACING * step
    fine = load_landform(landform_dir, x0, z0, x1, z1)
    h = to_model_grid(fine, step)
    n = h.shape[0]
    origin_x, origin_z = x0 * T * SPACING, z0 * T * SPACING
    sea = h <= 0.0
    X, Z = world_coords(n, dx, origin_x, origin_z)
    U = uplift_field(h, sea, X, Z, dx, P, int(P['seed']))
    rain = rain_field(h, dx, origin_x, origin_z, man_in['wind_toward_x_by_tile_row'], z0, P)

    import rock
    g = rock.load(geology_dir)
    assert g['n'] == n, ('geology grid', g['n'], 'model grid', n, 'export geology with --step', dx)
    rid = rock.rock_ids(g, h).reshape(n, n)
    soluble_ids = [k for k, v in g['names'].items() if v in P['rock']['soluble']]
    soluble = np.isin(rid, soluble_ids) & ~sea

    np.savez_compressed(f'{out_dir}/inputs.npz', landform=h.astype(np.float32), uplift=U.astype(np.float32), rain=rain.astype(np.float32),
                        rock=rid.astype(np.int16), soluble=soluble, sea=sea, cell_m=dx, origin_x=origin_x, origin_z=origin_z)
    land = ~sea
    summary = dict(grid=n, cell_m=dx, land_km2=float(land.sum() * dx * dx / 1e6), summit_m=float(h.max()),
                   rain_mm_yr=dict(min=float(rain[land].min()), mean=float(rain[land].mean()), max=float(rain[land].max())),
                   uplift_mm_yr=dict(mean=float(U[land].mean() * 1e3), max=float(U.max() * 1e3)),
                   soluble_km2=float(soluble.sum() * dx * dx / 1e6),
                   rock_km2={g['names'][int(k)]: float(c * dx * dx / 1e6) for k, c in zip(*np.unique(rid[land], return_counts=True))})
    inputs = {f: sha(f'{landform_dir}/{f}') for f in sorted(os.listdir(landform_dir)) if f.endswith('.f32')}
    inputs.update({f: sha(f'{geology_dir}/{f}') for f in sorted(os.listdir(geology_dir)) if f.startswith('geology')})
    json.dump(dict(params=P, inputs_sha256=inputs, summary=summary), open(f'{out_dir}/inputs_manifest.json', 'w'), indent=1)
    print(json.dumps(summary, indent=1))

    import matplotlib; matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.colors import LightSource
    fig, ax = plt.subplots(2, 2, figsize=(16, 16))
    ls = LightSource(315, 40)
    ax[0, 0].imshow(ls.shade(np.where(land, h, -30), cmap=plt.cm.terrain, vert_exag=3, blend_mode='soft', dx=dx, dy=dx)); ax[0, 0].set_title('A1 landform (no detail, no valleys)')
    im = ax[0, 1].imshow(np.where(land, U * 1e3, np.nan), cmap='magma'); ax[0, 1].set_title('A2 uplift mm/yr'); fig.colorbar(im, ax=ax[0, 1], shrink=0.7)
    im = ax[1, 0].imshow(np.where(land, rain, np.nan), cmap='Blues'); ax[1, 0].set_title('A4 rain mm/yr (wind from the manifest)'); fig.colorbar(im, ax=ax[1, 0], shrink=0.7)
    im = ax[1, 1].imshow(np.where(land, rid, np.nan), cmap='tab20'); ax[1, 1].contour(soluble, levels=[0.5], colors='k', linewidths=0.6)
    ax[1, 1].set_title('A3 surface rock (black line: soluble)')
    for a in ax.ravel(): a.axis('off')
    plt.tight_layout(); plt.savefig(f'{out_dir}/inputs.png', dpi=80)


if __name__ == '__main__':
    main()
