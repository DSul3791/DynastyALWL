"""Rain and vegetation maps for the erosion model, from the climate the generator baked (export_tile_maps.gd: moisture m_X_Z.u8, biome b_X_Z.u8,
biomes.json). Both are on the model's 32 m grid for the nine centre tiles.
rain_map: runoff per cell, 1 = reference rain. Wet ground sheds more water; polar land (snowfield, glacier) never thaws: 0, so no streams are cut.
veg_map: multiplier on the loose cover's erodibility. Plants hold soil (forest low); bare or dry ground washes fast (desert high)."""
import json, numpy as np

RAIN_BY_BIOME = {'snowfield': 0.0, 'glacier': 0.0, 'hot_desert': 0.25, 'dry_scrub': 0.5, 'savanna': 0.8}
VEG_BY_BIOME = {'tropical_forest': 0.4, 'mangrove': 0.6, 'temperate_forest': 0.5, 'mixed_forest': 0.55, 'boreal_forest': 0.6, 'heath': 0.8,
                'temperate_grassland': 0.9, 'marsh': 0.7, 'alpine_meadow': 0.9, 'tundra': 1.0, 'savanna': 1.1, 'dry_scrub': 1.4, 'hot_desert': 1.8,
                'volcanic_waste': 1.2, 'beach': 1.0, 'bare_rock': 1.0, 'snowfield': 0.0, 'glacier': 0.0, 'ocean': 1.0}


def load(map_dir, x0=2, z0=3, x1=4, z1=5, step=4, moisture_range=(0.6, 1.5)):
    T = 1920
    nx, nz = x1 - x0 + 1, z1 - z0 + 1
    mo = np.zeros((nz * T + 1, nx * T + 1), np.uint8); bi = np.zeros_like(mo)
    for z in range(z0, z1 + 1):
        for x in range(x0, x1 + 1):
            for arr, tag in ((mo, 'm'), (bi, 'b')):
                a = np.fromfile(f'{map_dir}/{tag}_{x}_{z}.u8', np.uint8).reshape(T + 1, T + 1)
                arr[(z - z0) * T:(z - z0) * T + T + 1, (x - x0) * T:(x - x0) * T + T + 1] = a
    mo = mo[::step, ::step].astype(np.float64) / 255.0; bi = bi[::step, ::step]
    names = {int(k): v for k, v in json.load(open(f'{map_dir}/biomes.json')).items()}
    lo, hi = moisture_range
    rain = lo + (hi - lo) * mo
    veg = np.ones(mo.shape)
    for k, name in names.items():
        sel = bi == k
        if name in RAIN_BY_BIOME: rain[sel] = np.minimum(rain[sel], RAIN_BY_BIOME[name]) if RAIN_BY_BIOME[name] == 0.0 else rain[sel] * RAIN_BY_BIOME[name]
        if name in VEG_BY_BIOME: veg[sel] = VEG_BY_BIOME[name]
    return rain, veg, bi, names
