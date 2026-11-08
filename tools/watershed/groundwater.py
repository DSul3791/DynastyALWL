"""Stages C3, C4 and C6 of the watershed rebuild (docs/water/watershed_rebuild_design.md, step R4): the water table, the
heads of the streams by what feeds them, and the wetlands by what wets them.

Usage (on Dave's PC, never in the cloud):
  python tools/watershed/groundwater.py INPUTS_DIR GEOLOGY_DIR B2_DIR R3_DIR OUT_DIR [params.json]
B2_DIR holds glacial.py's glacial.npz (channels, till, outwash, sediment); R3_DIR holds lakes.py's lakes.npz (the final
ground, lakes and their levels). Writes OUT_DIR/groundwater.npz, groundwater.png and groundwater_manifest.json.

The method is the design's R4 method (section 3, stage C):
  1. steady unconfined flow under the Dupuit assumption on a 64 m grid, div(T grad H) + R = 0, T = K b (Fan, Li and
     Miguez-Macho 2013 use the same balance of recharge against lateral flow, with the land as a ceiling);
  2. the sea holds H = 0, R3's lakes hold their levels, and the ground is a ceiling: a seepage-face iteration fixes H to the
     ground where the table would rise above it, and releases any fixed cell that would take water in. The fixed cells that
     stay are groundwater discharge: springs, seeps and gaining reaches. Whether the table follows the ground or the recharge
     comes out of the solve (Haitjema and Mitchell-Bruker 2005);
  3. conductivity by rock class from Gleeson et al. (2011), loose cover from Stage B over it, and a karst factor on
     cave-forming rock (conduits);
  4. recharge from the one water budget (A5).
Then at 16 m: depth to the table, discharge, baseflow down the routing and a first regime; heads labelled by supply; wetlands
typed by what wets them. Nothing is placed by chance.
"""
import sys, os, json, time
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'erosion_precarve'))
import rock     # noqa: E402
import runoff   # noqa: E402
import evolve   # noqa: E402

YEAR_S = 3.15576e7
HEAD_KINDS = ('spring', 'seep or damp hollow', 'lake outlet', 'wetland outlet', 'seasonal rill')
WET_CODES = dict(marsh=4, swamp=5, fen=6, bog=7, salt_marsh=10)    # the record's water class codes (design D)


def _blocks(a, f, how):
    """Block statistic over f x f cells; the grid is padded with its edge values to a multiple of f."""
    n = a.shape[0]
    m = -(-n // f) * f
    p = np.pad(a, ((0, m - n), (0, m - n)), mode='edge').reshape(m // f, f, m // f, f)
    if how == 'mean':
        return p.mean(axis=(1, 3))
    if how == 'min':
        return p.min(axis=(1, 3))
    if how == 'logmean':
        return np.exp(np.log(p).mean(axis=(1, 3)))
    raise ValueError(how)


def _argmin_blocks(a, f):
    """Index (in the fine grid, flat) of the lowest cell of each f x f block."""
    n = a.shape[0]
    m = -(-n // f) * f
    p = np.pad(a, ((0, m - n), (0, m - n)), mode='constant', constant_values=np.inf).reshape(m // f, f, m // f, f)
    q = p.transpose(0, 2, 1, 3).reshape(m // f, m // f, f * f)
    k = q.argmin(axis=2)
    bi, bj = np.meshgrid(np.arange(m // f), np.arange(m // f), indexing='ij')
    r = bi * f + k // f
    c = bj * f + k % f
    return np.where((r < n) & (c < n), r * n + c, -1)


def conductivity_by_rock(names, classes, table):
    """K (m/s) per rock id from its class (Gleeson et al. 2011 geometric mean permeability, k in m2). An unlisted rock stops
    the run rather than getting a made-up value."""
    top = max(names) + 1
    out = np.full(top, np.nan)
    missing = []
    for k, name in names.items():
        if name == 'air':
            continue
        if name not in classes:
            missing.append(name)
            continue
        out[k] = 10.0 ** (-float(table[classes[name]])) * 7.5e6     # k rho g / mu for water near 10 C
    if missing:
        raise SystemExit(f'groundwater: no permeability class for rock(s) {sorted(set(missing))}; add them to params.json groundwater.rock_class')
    return out


def solve_table(z, T, R, fixed_h, fixed, dx, iters):
    """Steady Dupuit flow with the ground z as a ceiling. T: transmissivity (m2/s), R: recharge (m/s), fixed: cells with a
    held head fixed_h (sea, lakes). Returns head, the seepage mask, the discharge out of each cell to the surface (m3/s,
    seepage cells), and the iterations used."""
    import scipy.sparse as sp
    import scipy.sparse.linalg as spl
    nc = z.shape[0]
    N = nc * nc
    A = dx * dx
    Tf = T.ravel()
    idx = np.arange(N).reshape(nc, nc)
    rows, cols, vals = [], [], []
    for a_, b_ in ((idx[:, :-1], idx[:, 1:]), (idx[:-1, :], idx[1:, :])):
        a_ = a_.ravel(); b_ = b_.ravel()
        c = 2.0 * Tf[a_] * Tf[b_] / np.maximum(Tf[a_] + Tf[b_], 1e-30)   # harmonic mean across the face; square cells
        rows += [a_, b_]; cols += [b_, a_]; vals += [c, c]
    rows = np.concatenate(rows); cols = np.concatenate(cols); vals = np.concatenate(vals)
    C = sp.csr_matrix((vals, (rows, cols)), shape=(N, N))
    diag = np.asarray(C.sum(axis=1)).ravel()
    L = sp.diags(diag) - C                                   # L H = net outflow by lateral flow
    zf = z.ravel(); Rf = R.ravel() * A
    seep = np.zeros(N, bool)
    held = fixed.ravel()
    hh = np.where(held, fixed_h.ravel(), 0.0)
    H = np.zeros(N)
    for it in range(iters):
        fx = held | seep
        val = np.where(held, hh, zf)
        free = ~fx
        Lff = L[free][:, free]
        rhs = Rf[free] - L[free][:, fx] @ val[fx]
        H = val.copy()
        H[free] = spl.spsolve(Lff.tocsc(), rhs)
        out = Rf - L @ H                                   # at a fixed cell: recharge less lateral outflow, given up to the surface
        new_seep = (seep & (out >= 0.0)) | (free & (H > zf))
        new_seep &= ~held
        if (new_seep == seep).all():
            break
        seep = new_seep
    out = Rf - L @ H                                       # > 0: discharge to the surface, the sea or a lake; < 0: it takes water in
    return H.reshape(nc, nc), seep.reshape(nc, nc), np.where(seep, np.maximum(out, 0.0), 0.0).reshape(nc, nc), it + 1, \
        out.reshape(nc, nc)


def main():
    from scipy.ndimage import distance_transform_edt, uniform_filter, map_coordinates
    inputs_dir, geology_dir, b2_dir, r3_dir, out_dir = sys.argv[1:6]
    P = json.load(open(sys.argv[6] if len(sys.argv) > 6 else os.path.join(HERE, 'params.json')))
    E, W, G = P['evolve'], P['water_budget'], P['groundwater']
    os.makedirs(out_dir, exist_ok=True)
    t0 = time.time()
    data = np.load(f'{inputs_dir}/inputs.npz')
    b2 = np.load(f'{b2_dir}/glacial.npz')
    r3 = np.load(f'{r3_dir}/lakes.npz')
    h = r3['ground'].astype(np.float64)
    n = h.shape[0]
    N = n * n
    dx = float(r3['cell_m'])
    cell = dx * dx
    sea = r3['sea'].astype(bool)
    land = ~sea
    wl = r3['water_level'].astype(np.float64)
    lake = r3['lake_id'].astype(np.int64) >= 0
    rain = data['rain'].astype(np.float64)
    cave = data['cave_forming'].astype(bool) if 'cave_forming' in data.files else np.zeros_like(sea)
    g = rock.load(geology_dir, E['cover_m'], E['cover_erodibility'])
    rid = rock.rock_ids(g, h).reshape(n, n)
    bfi = runoff.bfi_by_rock_id(g['names'], W['bfi_by_rock'])
    wb = runoff.budget(rain.ravel(), rid.ravel(), bfi, W)
    recharge = np.where(land, wb['recharge'].reshape(n, n), 0.0) / 1000.0 / YEAR_S      # m/s

    # Conductivity: rock, with loose cover over it (transmissivities add), and conduits in cave-forming rock.
    Krock = conductivity_by_rock(g['names'], G['rock_class'], G['log10_k_m2_negated'])[rid]
    Krock = np.where(cave, Krock * G['karst_factor'], Krock)
    sed = b2['sediment_m'].astype(np.float64)
    till = b2['till_m'].astype(np.float64)
    tab = G['log10_k_m2_negated']
    Kc = np.where(till >= 0.5 * np.maximum(sed, 1e-9), 10.0 ** -tab['fine unconsolidated'], 10.0 ** -tab['coarse unconsolidated']) * 7.5e6
    b = float(G['thickness_m'])
    dcov = np.minimum(sed, b)
    T16 = Kc * dcov + Krock * (b - dcov)
    T16 = np.where(np.isfinite(T16) & (T16 > 0.0), T16, float(np.nanmedian(T16[land])))   # under the sea the rock does not matter

    # The 64 m grid
    f = int(round(G['cell_m'] / dx))
    zc = _blocks(np.where(land, h, 0.0), f, 'min')            # the lowest ground in a block: where its water comes out
    seac = _blocks(sea.astype(np.float64), f, 'mean') >= 0.5
    lakec = _blocks(lake.astype(np.float64), f, 'mean') >= 0.5
    lakelev = _blocks(np.where(lake, wl, 0.0), f, 'mean') / np.maximum(_blocks(lake.astype(np.float64), f, 'mean'), 1e-9)
    Tc = _blocks(np.maximum(T16, 1e-12), f, 'logmean')       # geometric mean: the usual upscaling of a mixed medium
    Rc = _blocks(recharge, f, 'mean')
    fixed = seac | lakec
    fixed_h = np.where(seac, 0.0, np.where(lakec, lakelev, 0.0))
    dxc = dx * f
    H, seep, dis, iters, net = solve_table(zc, Tc, Rc, fixed_h, fixed, dxc, int(G['seepage_iterations']))
    rech_total = float((Rc * dxc * dxc).sum())
    to_land = float(dis.sum())
    to_lakes = float(net[lakec].sum())
    to_sea = float(net[seac].sum())

    # Back to 16 m
    rr, cc = np.meshgrid(np.arange(n), np.arange(n), indexing='ij')
    Hf = map_coordinates(H, [(rr + 0.5) / f - 0.5, (cc + 0.5) / f - 0.5], order=1, mode='nearest')
    table = np.where(land, np.minimum(Hf, h), 0.0)
    depth = np.where(land, h - table, 0.0)
    gw = np.zeros(N)                                          # m3/s out of the ground, at the lowest cell of each block
    low = _argmin_blocks(np.where(land, h, np.inf), f).ravel()
    ok = (low >= 0) & (dis.ravel() > 0.0)
    np.add.at(gw, low[ok], dis.ravel()[ok])
    gw = gw.reshape(n, n)

    # Baseflow and a first regime along the final routing
    filled, rec, order = evolve.route(h.ravel(), sea.ravel().astype(np.uint8), n, dx, evolve.flow_memory(E))
    base = evolve._discharge(order, rec, sea.ravel().astype(np.uint8), gw.ravel() / cell, cell, N).reshape(n, n)  # m3/s
    share = b2['channel'].astype(np.float64)
    q = r3['quick_area_m2'].astype(np.float64)
    channel = land & ~lake & (share > 0.5)
    regime = np.zeros((n, n), np.int8)
    regime[channel & (base >= G['perennial_baseflow_m3_s'])] = 1
    regime[channel & (base < G['perennial_baseflow_m3_s']) & (q >= G['intermittent_quick_area_m2'])] = 2
    regime[channel & (regime == 0)] = 3

    # Heads (C4): channel cells with no channel donor, labelled by what feeds them
    recf = rec.ravel()
    chf = channel.ravel()
    has_donor = np.zeros(N, bool)
    src = np.flatnonzero(chf & (recf >= 0))
    has_donor[recf[src]] = True
    heads = chf & ~has_donor
    # wetlands first, since a head inside one is a wetland outlet
    gy, gx = np.gradient(h, dx)
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))
    lap = (np.roll(h, 1, 0) + np.roll(h, -1, 0) + np.roll(h, 1, 1) + np.roll(h, -1, 1) - 4.0 * h)
    near_sea = distance_transform_edt(land) * dx
    wetn = (land & ~lake & ~channel & (depth <= G['wetland_depth_m']) & (slope <= G['wetland_slope_deg'])
            & ((lap >= 0.0) | (slope <= 1.0)))
    gw_win = uniform_filter(gw, size=5, mode='constant') * 25.0      # discharge within two cells
    perennial = regime == 1
    near_water = distance_transform_edt(~(perennial | lake)) * dx
    wet = np.zeros((n, n), np.int8)
    salt = land & (h <= G['tidal_band_m']) & (near_sea <= G['salt_marsh_max_from_sea_m']) & (slope <= G['wetland_slope_deg']) & (sed >= 0.5) & ~lake & ~channel
    wet[salt] = WET_CODES['salt_marsh']
    seep16 = np.kron(seep, np.ones((f, f), bool))[:n, :n]       # the 64 m blocks where groundwater comes out
    fen = wetn & (wet == 0) & (seep16 | (gw_win > 0.0))
    wet[fen] = WET_CODES['fen']
    flood = wetn & (wet == 0) & (sed >= 1.0) & (near_water <= G['floodplain_reach_m'])
    swamp = flood & (h < G['treeline_m']) & (depth > G['swamp_min_depth_m'])
    wet[flood & ~swamp] = WET_CODES['marsh']
    wet[swamp] = WET_CODES['swamp']
    bog = wetn & (wet == 0) & (rain >= G['bog_rain_mm_yr'])
    wet[bog] = WET_CODES['bog']
    wet[wetn & (wet == 0)] = WET_CODES['marsh']                 # wet ground with none of the above: herbaceous wet meadow

    kind = np.full(N, -1, np.int8)
    lake_near = uniform_filter(lake.astype(np.float64), size=3, mode='constant').ravel() > 0.0
    wet_near = uniform_filter((wet > 0).astype(np.float64), size=3, mode='constant').ravel() > 0.0
    gwv = gw_win.ravel()
    for code, sel in ((2, heads & lake_near), (0, heads & (gwv >= G['spring_m3_s'])), (3, heads & wet_near),
                      (1, heads & (gwv > 0.0)), (4, heads)):
        kind[sel & (kind < 0)] = code
    kind = kind.reshape(n, n)

    # Springs (heads or not) with the most water; cave-spring candidates are those on or beside cave-forming rock (C7)
    cave_near = uniform_filter(cave.astype(np.float64), size=5, mode='constant') > 0.0
    top = np.argsort(-gw.ravel())[:30]
    ox, oz = float(r3['origin_x']), float(r3['origin_z'])
    springs = [dict(x=ox + float(i % n) * dx, z=oz + float(i // n) * dx, m3_s=float(gw.ravel()[i]),
                    on_cave_forming_rock=bool(cave_near.ravel()[i])) for i in top if gw.ravel()[i] > 0.0]
    R = lambda a, t=np.float32: np.asarray(a).reshape(n, n).astype(t)
    np.savez_compressed(f'{out_dir}/groundwater.npz', water_table_m=R(table), depth_to_table_m=R(depth), gw_discharge_m3_s=R(gw),
                        baseflow_m3_s=R(base), regime=R(regime, np.int8), head_kind=R(kind, np.int8), wetland=R(wet, np.int8),
                        transmissivity_m2_s=R(T16), ground=R(h), sea=R(sea, bool), lake=R(lake, bool), cell_m=dx,
                        origin_x=ox, origin_z=oz, head_64m=H.astype(np.float32), seepage_64m=seep)
    km = lambda m: float(m.sum() * cell / 1e6)
    summary = dict(seconds=time.time() - t0, seepage_iterations=iters,
                   balance_m3_s=dict(recharge=rech_total, to_land_surface=to_land, to_lakes=to_lakes, to_sea=to_sea,
                                     closure=rech_total - to_land - to_lakes - to_sea),
                   land_km2=km(land), table_within_1m_km2=km(land & (depth <= 1.0)), table_deeper_than_20m_km2=km(land & (depth > 20.0)),
                   channel_km=float(channel.sum() * dx / 1e3),
                   regime_km={k: float((regime == v).sum() * dx / 1e3) for k, v in (('perennial', 1), ('intermittent', 2), ('ephemeral', 3))},
                   heads={HEAD_KINDS[k]: int((kind == k).sum()) for k in range(len(HEAD_KINDS))},
                   wetland_km2={k: km(wet == v) for k, v in WET_CODES.items()},
                   wetland_on_steep_ground_cells=int(((wet > 0) & (wet != WET_CODES['salt_marsh']) & (slope > G['wetland_slope_deg'])).sum()),
                   springs_largest=springs[:15])
    json.dump(dict(params=P, inputs={'inputs.npz': evolve.sha(f'{inputs_dir}/inputs.npz'), 'lakes.npz': evolve.sha(f'{r3_dir}/lakes.npz'),
                                     'glacial.npz': evolve.sha(f'{b2_dir}/glacial.npz')}, summary=summary),
              open(f'{out_dir}/groundwater_manifest.json', 'w'), indent=1)
    print(json.dumps(summary, indent=1))
    import plots
    plots.groundwater_picture(f'{out_dir}/groundwater.npz', f'{out_dir}/groundwater.png')


if __name__ == '__main__':
    main()
