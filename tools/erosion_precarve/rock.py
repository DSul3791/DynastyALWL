"""Layered rock for the erosion model: how hard the ground is at a given height, from the generator's geology (export_geology.gd).
Same rule as TileGeology.layer_at: depth below the province's old surface picks the layer; intrusions and vents override; loose cover on top."""
import json, numpy as np, numba as nb


def load(geo_dir, cover_m=4.0, cover_ery=5.0, cover_slope_deg=42.0):
    info = json.load(open(f'{geo_dir}/geology.json'))
    n = info['n']
    prov = np.fromfile(f'{geo_dir}/geology_province.u8', np.uint8).reshape(n, n).ravel().astype(np.int32)
    surf = np.fromfile(f'{geo_dir}/geology_surface.f32', '<f4').ravel().astype(np.float64)
    gran = np.fromfile(f'{geo_dir}/geology_granite.f32', '<f4').ravel().astype(np.float64)
    basa = np.fromfile(f'{geo_dir}/geology_basalt.f32', '<f4').ravel().astype(np.float64)
    nr = max(int(float(k)) for k in info['rocks']) + 1
    er = np.ones(nr)
    for k, v in info['rocks'].items():
        er[int(float(k))] = v['erodibility']
    P = info['provinces']
    cycle = np.array([p['cycle'] for p in P]); repeat = np.array([p['repeat'] for p in P])
    base = np.array([int(p['base']) for p in P], np.int32); marble = np.array([p['marble_depth'] for p in P])
    ptr = np.zeros(len(P) + 1, np.int32)
    for i, p in enumerate(P): ptr[i + 1] = ptr[i] + len(p['layers'])
    lrock = np.zeros(ptr[-1], np.int32); lbot = np.zeros(ptr[-1])
    for i, p in enumerate(P):
        for k, (r, top, bot) in enumerate(p['layers']):
            lrock[ptr[i] + k] = int(r); lbot[ptr[i] + k] = bot
    return dict(n=n, prov=prov, surf=surf, gran=gran, basa=basa, er=er, cycle=cycle, repeat=repeat, base=base, marble=marble, ptr=ptr,
                lrock=lrock, lbot=lbot, gid=[int(float(k)) for k, v in info['rocks'].items() if v['name'] == 'granite'][0],
                bid=[int(float(k)) for k, v in info['rocks'].items() if v['name'] == 'basalt'][0],
                lid=int(info['limestone_id']), mid=int(info['marble_id']), cover_m=cover_m, cover_ery=cover_ery)


@nb.njit(cache=True)
def _ery(h, cover, sea, prov, surf, gran, basa, er, cycle, repeat, base, marble, ptr, lrock, lbot, gid, bid, lid, mid, cover_m, cover_ery, out):
    for i in range(h.size):
        if sea[i]:
            out[i] = 1.0; continue
        y = h[i]
        if cover[i] > 0.0:                       # loose cover is not yet washed off
            out[i] = cover_ery; continue
        if y <= gran[i]:
            out[i] = er[gid]; continue
        if y <= basa[i]:
            out[i] = er[bid]; continue
        p = prov[i]
        depth = surf[i] - y
        a = ptr[p]; b = ptr[p + 1]
        if b == a:
            out[i] = er[base[p]]; continue
        if depth < 0.0:
            out[i] = er[lrock[a]]; continue
        if depth >= repeat[p]:
            out[i] = er[base[p]]; continue
        inc = depth % cycle[p]
        rock = base[p]
        for k in range(a, b):
            if inc < lbot[k]:
                rock = lrock[k]
                if rock == lid and depth > marble[p]:
                    rock = mid
                break
        out[i] = er[rock]


@nb.njit(cache=True)
def _wear(cover, delta, sea):
    # delta = height change this step apart from uplift: negative = eroded (cover wears off), positive = sediment landed (cover grows)
    for i in range(cover.size):
        if sea[i]: continue
        c = cover[i] + delta[i]
        cover[i] = 0.0 if c < 0.0 else c


def make_fn(g, start_h, sea, dx):
    start = np.asarray(start_h, np.float64)
    n = start.shape[0]
    gy, gx = np.gradient(start, dx)
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))
    cover = (g['cover_m'] * np.clip(1.0 - slope / 42.0, 0.0, 1.0)).ravel().copy()   # as the baker: none on slopes of 42 degrees or more
    out = np.ones(cover.size)
    def fn(h):
        _ery(h, cover, sea, g['prov'], g['surf'], g['gran'], g['basa'], g['er'], g['cycle'], g['repeat'], g['base'], g['marble'], g['ptr'],
             g['lrock'], g['lbot'], g['gid'], g['bid'], g['lid'], g['mid'], g['cover_m'], g['cover_ery'], out)
        return out
    fn.update = lambda delta: _wear(cover, delta, sea)
    return fn
