"""The peak checks of design A1 rule 6 (peaks that are pyramids, not domes): sign-off lines 1 to 10 of
docs/water/rule6_build_plan.md. Lines 11 and 12 are Dino's zoom pictures.

Usage (on Dave's PC or David4, never in the cloud):
  python tools/watershed/peaks.py landform INPUTS_DIR [BASELINE_INPUTS_DIR] [params.json]
    lines 1 to 3 on inputs.npz's landform: the valley heads round each summit, no new closed hollows near the summits, and
    the summit heights unchanged, both against a baseline run's inputs (ws580g). Writes INPUTS_DIR/peaks_landform.json and .md.
  python tools/watershed/peaks.py glacial INPUTS_DIR GLACIAL_DIR [params.json]
    lines 4 to 10 on glacial.npz's final ground against the landform. The headwall retreat is read from the cycles: the
    manifest's summary.cycles when glacial.py ran a history, else the glacial_cycle_NN.npz snapshots; a run of one cold stage
    has no cycles, so lines 8 to 10 read N/A. Writes GLACIAL_DIR/peaks_glacial.json and .md.
glacial.py calls shapes() after every cycle (rule 6 build plan, change 2).

The summits checked are the landform's peaks (the highest point within 1 km, as evolve.py finds them) at least
peaks.above_snowline_m above the stadial snowline (glacial.ela_m plus the last era's offset): lower tops hold no cirque glacier.
Each line reads PASS, FAIL or N/A (no data for it), with the numbers; a FAIL is relayed word for word, never rerun with
other settings.

Conventions: rows run +z (south) and columns +x (east), x = origin_x + column * cell_m, as in every watershed tool. Bearings
are compass degrees, 0 north (-z) and 90 east (+x). A head's bearing points from the top out along its valley, so a head on a
summit's north-east side, opening north-east, has a bearing between 0 and 90.
"""
import sys, os, json, glob
import numpy as np
from scipy.ndimage import map_coordinates, maximum_filter, label

HERE = os.path.dirname(os.path.abspath(__file__))
EIGHT = np.ones((3, 3), bool)


def _odd(m, dx):
    return int(round(m / dx)) | 1


def snowline(P):
    """The stadial snowline the cirques worked at: glacial.ela_m plus the lowest era offset with ice time (0 for rule 6's
    history, whose 100 kyr world sits at ela_m). 8 Nov 2026: this was the last era's offset, which for an LR04 history
    (lr04_history.py) is the Holocene's, about 980 m: probe L found no summit above it and checked none."""
    GL = P['glacial']
    hist = [e for e in (GL.get('history') or []) if float(e.get('active_years', 1.0)) > 0.0] or [{}]
    return float(GL['ela_m']) + min(float(e.get('ela_offset_m', 0.0)) for e in hist)


def summits(landform, sea, dx, min_m, window_m=1000.0):
    """(row, col) of the landform's peaks: the highest point within window_m, above min_m, highest first; of a flat top's
    equal cells only the first is kept."""
    h = landform
    top = (h == maximum_filter(h, _odd(window_m, dx))) & ~sea & (h > min_m)
    rows, cols = np.nonzero(top)
    kept = []
    for q in np.argsort(-h[rows, cols], kind='stable'):
        r, c = int(rows[q]), int(cols[q])
        if all((r - a) ** 2 + (c - b) ** 2 > (0.5 * window_m / dx) ** 2 for a, b in kept):
            kept.append((r, c))
    return kept


def _sample(z, rows, cols):
    return map_coordinates(z, [np.asarray(rows, float), np.asarray(cols, float)], order=1, mode='nearest')


def _ring(z, r0, c0, radius_m, dx, step_deg):
    b = np.arange(0.0, 360.0, step_deg)
    t = np.radians(b)
    return b, _sample(z, r0 - radius_m * np.cos(t) / dx, c0 + radius_m * np.sin(t) / dx)


def ring_heads(v, bearings, drop_m):
    """The valley heads on a ring of heights: each low that stands drop_m or more below the ridges on both sides of it. The
    ring's lows and highs alternate; the pair (one low, one high next to each other) with the smallest difference is a bump
    or a dip in a slope, not a valley, and is dropped, until every pair left differs by drop_m or more. Dropping the smallest
    pair always keeps the higher of the two ridges round a low and the lower of the two lows round a ridge (1-D persistence,
    on a circle). A ring of one low and one high (a tilted ring) has one head at most."""
    v = np.asarray(v, float)
    m = v.size
    runs = [i for i in range(m) if v[i] != v[i - 1]]
    ext = []
    for a in range(len(runs)):
        i, p, q = runs[a], runs[a - 1], runs[(a + 1) % len(runs)]
        if v[i] < v[p] and v[i] < v[q]:
            ext.append(i)
        elif v[i] > v[p] and v[i] > v[q]:
            ext.append(i)
    while len(ext) > 2:
        k = len(ext)
        diffs = np.array([abs(v[ext[a]] - v[ext[(a + 1) % k]]) for a in range(k)])
        a = int(np.argmin(diffs))
        if diffs[a] >= drop_m:
            break
        for t in sorted((a, (a + 1) % k), reverse=True):
            del ext[t]
    heads = []
    k = len(ext)
    for a in range(k):
        i = ext[a]
        left, right = ext[a - 1], ext[(a + 1) % k]
        if k < 2 or v[i] > v[left] or v[i] > v[right]:
            continue                                       # a ridge, or nothing left round it
        depth = min(v[left], v[right]) - v[i]
        if depth >= drop_m:
            heads.append(dict(bearing_deg=float(bearings[i]), depth_m=float(depth), floor_m=float(v[i])))
    return heads


def facing(bearing, shady_deg=45.0):
    """'shady' within 45 degrees of the shady lee bearing (the island's, from its latitude, world.py: 45 NE north of the
    equator, 135 SE south of it), 'sunny' within 45 degrees of the opposite bearing, else 'other'."""
    d = (float(bearing) - float(shady_deg)) % 360.0
    return 'shady' if d <= 45.0 or d >= 315.0 else ('sunny' if 135.0 <= d <= 225.0 else 'other')


def _compass(bearing):
    return ('N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW')[int(((float(bearing) % 360.0) + 22.5) // 45.0) % 8]


def _checks(P, sky=None):
    """The peaks settings, with the island's latitude and shady lee bearing when its sky is given (world.sky, from its tile
    row on the world grid: one source, design A4 one sky). Without a sky only the checks that need no bearing may use them."""
    Q = dict(P['peaks'])
    if sky is not None:
        Q.update(latitude_deg=float(sky['latitude_deg']), shady_bearing_deg=float(sky['shady_bearing_deg']))
    return Q


def island_sky(P, origin_z, n, dx):
    """The island's sky from its grid: origin_z and n cells of dx (world.sky)."""
    sys.path.insert(0, HERE)
    import world      # noqa: E402
    return world.sky(P, origin_z, n * dx)


def _slope_deg(h, dx):
    gz, gx = np.gradient(h, dx)
    return np.degrees(np.arctan(np.hypot(gx, gz)))


def plateau_m(h, slope, land, r0, c0, within_m, max_deg, dx):
    """The widest flat cap: of the ground within within_m of the top and joined to it, the largest group of cells under
    max_deg, as the diameter of a circle of the same area. A pyramid's top gives about one cell; a dome gives kilometres."""
    cap = (h >= h[r0, c0] - within_m) & land
    lab, _ = label(cap, structure=EIGHT)
    if lab[r0, c0] == 0:
        return 0.0
    flat = (lab == lab[r0, c0]) & (slope < max_deg)
    lab2, nf = label(flat, structure=EIGHT)
    if nf == 0:
        return 0.0
    cells = int(np.bincount(lab2.ravel())[1:].max())
    return float(2.0 * np.sqrt(cells * dx * dx / np.pi))


def headwalls(h, slope, r0, c0, bearings, dx, Q):
    """Along each valley-head bearing, walking out from the top: the headwall's upper edge (the first point steeper than
    headwall_deg), the cirque floor (the lowest ground within floor_beyond_m beyond it) and the depth between them. A
    horn's faces are steep from the top, so its headwalls read about 0 m from it."""
    step = 0.5 * dx
    r = np.arange(0.0, float(Q['profile_m']) + step, step)
    out = []
    for b in bearings:
        t = np.radians(b)
        rows, cols = r0 - r * np.cos(t) / dx, c0 + r * np.sin(t) / dx
        hp, sp = _sample(h, rows, cols), _sample(slope, rows, cols)
        item = dict(bearing_deg=float(b), facing=facing(b, Q.get('shady_bearing_deg', 45.0)), headwall_m=None, depth_m=None, floor_m=None)
        steep = np.flatnonzero(sp > float(Q['headwall_deg']))
        if steep.size:
            k = int(steep[0])
            beyond = (r >= r[k]) & (r <= r[k] + float(Q['floor_beyond_m']))
            floor = float(hp[beyond].min())
            item.update(headwall_m=float(r[k]), depth_m=float(hp[k] - floor), floor_m=floor)
        out.append(item)
    return out


def _window(n, r, c, half):
    return max(r - half, 0), min(r + half + 1, n), max(c - half, 0), min(c + half + 1, n)


def _all_heads(h, r0, c0, dx, Q):
    out = {}
    for R in Q['rings_m']:
        b, v = _ring(h, r0, c0, float(R), dx, float(Q['ring_step_deg']))
        out[str(int(R))] = ring_heads(v, b, float(Q['head_drop_m']))
    return out


def axes(landform, sea, dx, tops, Q):
    """The valley-head bearings of each summit, from the landform: the heads on whichever ring shows the most (the nearest
    ring on a tie); if no ring shows one, the lows of the 500 m ring."""
    n = landform.shape[0]
    half = int(round(float(Q['window_m']) / dx))
    out = []
    for r, c in tops:
        a0, a1, b0, b1 = _window(n, r, c, half)
        w = landform[a0:a1, b0:b1].astype(np.float64)
        heads = _all_heads(w, r - a0, c - b0, dx, Q)
        best = max(heads.items(), key=lambda kv: (len(kv[1]), -float(kv[0])))[1]
        if not best:
            b, v = _ring(w, r - a0, c - b0, 500.0, dx, float(Q['ring_step_deg']))
            best = [dict(bearing_deg=float(x)) for x in b[(v < np.roll(v, 1)) & (v <= np.roll(v, -1))]]
        out.append([hd['bearing_deg'] for hd in best])
    return out


def shapes(ground, landform, sea, dx, ox, oz, tops, ax, Q):
    """The shape of each summit on this ground: its top (the highest ground within top_search_m of the landform's top) and
    the change from the landform, the valley heads on each ring, the widest flat cap, the mean slope near the top, and the
    headwalls along the landform's valley-head bearings."""
    n = ground.shape[0]
    half = int(round(float(Q['window_m']) / dx))
    out = []
    for (r, c), bearings in zip(tops, ax):
        a0, a1, b0, b1 = _window(n, r, c, half)
        w = ground[a0:a1, b0:b1].astype(np.float64)
        land = ~sea[a0:a1, b0:b1]
        rr, cc = np.mgrid[0:w.shape[0], 0:w.shape[1]]
        near = np.hypot(rr - (r - a0), cc - (c - b0)) * dx <= float(Q['top_search_m'])
        k = int(np.argmax(np.where(near, w, -np.inf)))
        tr, tc = divmod(k, w.shape[1])
        slope = _slope_deg(w, dx)
        heads = _all_heads(w, tr, tc, dx, Q)
        disc = (np.hypot(rr - tr, cc - tc) * dx <= float(Q['slope_disc_m'])) & land
        out.append(dict(x=ox + c * dx, z=oz + r * dx, top_x=ox + (b0 + tc) * dx, top_z=oz + (a0 + tr) * dx,
                        landform_m=float(landform[r, c]), top_m=float(w[tr, tc]), top_change_m=float(w[tr, tc] - landform[r, c]),
                        heads=heads,
                        heads_within_m=max([len(v) for R, v in heads.items() if float(R) <= float(Q['heads_within_m'])] or [0]),
                        plateau_m=plateau_m(w, slope, land, tr, tc, float(Q['plateau_within_m']), float(Q['plateau_max_deg']), dx),
                        slope_near_top_deg=float(slope[disc].mean()) if disc.any() else 0.0,
                        headwalls=headwalls(w, slope, tr, tc, bearings, dx, Q)))
    return out


def retreat(series, Q):
    """series: [(cycle, active ice years so far, shapes)], from the landform (cycle 0, 0 years) on. For each summit and
    valley-head bearing: the headwall's distance from the top and the cirque's depth through the cycles; its retreat in mm per
    active year from the first cycle it stands to the last; and its deepening rate up to cycle early_cycles and after it."""
    out = []
    for s in range(len(series[0][2])):
        heads = []
        for a in range(len(series[0][2][s]['headwalls'])):
            pts = [(int(cy), float(A), sh[s]['headwalls'][a]) for cy, A, sh in series]
            stand = [p for p in pts if p[2]['headwall_m'] is not None]
            hw0 = series[0][2][s]['headwalls'][a]
            item = dict(bearing_deg=hw0['bearing_deg'], facing=hw0['facing'],
                        headwall_m=[[p[0], p[2]['headwall_m']] for p in pts], depth_m=[[p[0], p[2]['depth_m']] for p in pts],
                        floor_m=stand[-1][2]['floor_m'] if stand else None, rate_mm_yr=None,
                        depth_rate_early_mm_yr=None, depth_rate_late_mm_yr=None)
            if len(stand) >= 2 and stand[-1][1] > stand[0][1]:
                item['rate_mm_yr'] = 1000.0 * (stand[0][2]['headwall_m'] - stand[-1][2]['headwall_m']) / (stand[-1][1] - stand[0][1])
            early = [p for p in stand if 0 < p[0] <= int(Q['early_cycles'])]
            if early and early[-1][1] > 0.0 and stand[-1][0] > early[-1][0] and stand[-1][1] > early[-1][1]:
                e, last = early[-1], stand[-1]
                item['depth_rate_early_mm_yr'] = 1000.0 * e[2]['depth_m'] / e[1]
                item['depth_rate_late_mm_yr'] = 1000.0 * (last[2]['depth_m'] - e[2]['depth_m']) / (last[1] - e[1])
            heads.append(item)
        out.append(dict(x=series[0][2][s]['x'], z=series[0][2][s]['z'], heads=heads))
    return out


def _line(k, ok, text):
    return dict(line=k, result='N/A' if ok is None else ('PASS' if ok else 'FAIL'), text=text)


def _where(s):
    return f"summit at x {s['x']:.0f} z {s['z']:.0f}"


def _hollows_near(h, sea, dx, tops, P):
    """Closed hollows of the landform (8-connected groups of land lying more than hollow_min_depth_m below the filled
    surface) with a cell within hollow_radius_m of a checked summit."""
    sys.path.insert(0, HERE)
    sys.path.insert(0, os.path.join(HERE, '..', 'erosion_precarve'))
    import evolve     # noqa: E402  (the B1 routing)
    Q = _checks(P)
    n = h.shape[0]
    filled, _, _ = evolve.route(h.astype(np.float64).ravel(), sea.ravel().astype(np.uint8), n, dx, evolve.flow_memory(P['evolve']))
    pit = (filled.reshape(n, n) - h > float(Q['hollow_min_depth_m'])) & ~sea
    rr, cc = np.mgrid[0:n, 0:n]
    near = np.zeros((n, n), bool)
    for r, c in tops:
        near |= np.hypot(rr - r, cc - c) * dx <= float(Q['hollow_radius_m'])
    lab, _ = label(pit, structure=EIGHT)
    return int(np.unique(lab[near & pit]).size)


def _load_inputs(d):
    x = np.load(f'{d}/inputs.npz')
    return x['landform'].astype(np.float64), x['sea'].astype(bool), float(x['cell_m']), float(x['origin_x']), float(x['origin_z'])


def check_landform(inputs_dir, baseline_dir, P):
    h, sea, dx, ox, oz = _load_inputs(inputs_dir)
    Q = _checks(P, island_sky(P, oz, h.shape[0], dx))
    tops = summits(h, sea, dx, snowline(P) + float(Q['above_snowline_m']), float(Q['summit_window_m']))
    ax = axes(h, sea, dx, tops, Q)
    now = shapes(h, h, sea, dx, ox, oz, tops, ax, Q)
    need = int(Q['heads_needed'])
    lines = [_line(1, bool(now) and all(s['heads_within_m'] >= need for s in now),
                   '; '.join(f"{_where(s)} ({s['top_m']:.1f} m): {s['heads_within_m']} valley heads within {Q['heads_within_m']} m, each "
                             f"{Q['head_drop_m']} m or more below the ridges either side (need {need})" for s in now) or 'no summit checked')]
    base = None
    if baseline_dir:
        bh, bsea, bdx, box, boz = _load_inputs(baseline_dir)
        if bh.shape != h.shape or abs(bdx - dx) > 1e-6 or (box, boz) != (ox, oz):
            raise SystemExit('peaks: the baseline inputs are on another grid')
        btops = summits(bh, bsea, dx, snowline(P) + float(Q['above_snowline_m']), float(Q['summit_window_m']))
        base = dict(hollows=_hollows_near(bh, bsea, dx, btops, P), tops=btops, h=bh)
    hollows = _hollows_near(h, sea, dx, tops, P)
    if base is None:
        lines.append(_line(2, None, f'{hollows} closed hollows within {Q["hollow_radius_m"]} m of the checked summits; no baseline given'))
        lines.append(_line(3, None, 'no baseline given'))
    else:
        lines.append(_line(2, hollows <= base['hollows'],
                           f'{hollows} closed hollows within {Q["hollow_radius_m"]} m of the checked summits, baseline {base["hollows"]}'))
        texts, ok = [], True
        reach = float(Q['top_search_m']) / dx
        for (r, c), s in zip(tops, now):
            match = [(a, b) for a, b in base['tops'] if (a - r) ** 2 + (b - c) ** 2 <= reach ** 2]
            if not match:
                ok = False
                texts.append(f'{_where(s)}: no baseline summit within {Q["top_search_m"]} m')
                continue
            bt = float(base['h'][match[0]])
            ok &= abs(s['top_m'] - bt) <= float(Q['unchanged_m'])
            texts.append(f"{_where(s)}: {s['top_m']:.1f} m, baseline {bt:.1f} m")
        lines.append(_line(3, ok and bool(now), '; '.join(texts) or 'no summit checked'))
    return dict(snowline_m=snowline(P), summits=now, lines=lines)


def _history_years(P):
    """Active ice years after each cycle, from glacial.history (one stage of glacial.years when there is no history)."""
    GL = P['glacial']
    hist = GL.get('history') or [dict(cycles=1, active_years=GL['years'])]
    years, total = [], 0.0
    for era in hist:
        for _ in range(int(era['cycles'])):
            total += float(era['active_years'])
            years.append(total)
    return years


def check_glacial(inputs_dir, glacial_dir, P):
    lf, sea, dx, ox, oz = _load_inputs(inputs_dir)
    Q = _checks(P, island_sky(P, oz, lf.shape[0], dx))
    g = np.load(f'{glacial_dir}/glacial.npz')
    if g['ground'].shape != lf.shape:
        raise SystemExit('peaks: glacial.npz and inputs.npz are on different grids')
    ground = g['ground'].astype(np.float64)
    man = json.load(open(f'{glacial_dir}/glacial_manifest.json'))
    Pm = dict(P, glacial=man['params']['glacial']) if 'params' in man else P   # the snowline and history the run used
    tops = summits(lf, sea, dx, snowline(Pm) + float(Q['above_snowline_m']), float(Q['summit_window_m']))
    ax = axes(lf, sea, dx, tops, Q)
    before = shapes(lf, lf, sea, dx, ox, oz, tops, ax, Q)
    after = shapes(ground, lf, sea, dx, ox, oz, tops, ax, Q)
    years = _history_years(Pm)
    series = [(0, 0.0, before)]
    cyc = man.get('summary', {}).get('cycles')
    source = 'none: one cold stage'
    if cyc:
        series += [(int(e['cycle']), years[int(e['cycle']) - 1], e['shape']) for e in cyc]
        source = 'manifest summary.cycles'
    else:
        snaps = sorted(glob.glob(f'{glacial_dir}/glacial_cycle_*.npz'))
        for f in snaps:
            k = int(os.path.basename(f)[len('glacial_cycle_'):-4])
            series.append((k, years[k - 1], shapes(np.load(f)['ground'].astype(np.float64), lf, sea, dx, ox, oz, tops, ax, Q)))
        if not snaps or series[-1][0] != len(years):
            series.append((len(years), years[-1], after))       # the final ground ends the last cycle
        source = f'{len(snaps)} snapshots and the final ground' if snaps else source
    rt = retreat(series, Q)
    lines = []
    tol = float(Q['top_tolerance_m'])
    texts, ok = [], bool(after)
    for s in after:
        good = s['top_change_m'] >= -tol
        ok &= good
        t = f"{_where(s)}: landform {s['landform_m']:.1f} m, now {s['top_m']:.1f} m ({s['top_change_m']:+.1f} m)"
        if not good:
            met = [hw for hw in s['headwalls'] if hw['headwall_m'] is not None and hw['headwall_m'] <= float(Q['met_at_top_m'])]
            t += '; headwalls met at the top: ' + (', '.join(f"bearing {hw['bearing_deg']:.0f} floor {hw['floor_m']:.0f} m" for hw in met) or 'none')
        texts.append(t)
    lines.append(_line(4, ok, '; '.join(texts) or 'no summit checked'))
    need = int(Q['heads_needed'])
    lines.append(_line(5, bool(after) and all(s['heads_within_m'] >= need for s in after),
                       '; '.join(f"{_where(s)}: {s['heads_within_m']} valley heads (need {need})" for s in after) or 'no summit checked'))
    lines.append(_line(6, bool(after) and all(a['slope_near_top_deg'] > b['slope_near_top_deg'] for a, b in zip(after, before)),
                       '; '.join(f"{_where(a)}: mean slope within {Q['slope_disc_m']} m {b['slope_near_top_deg']:.1f} -> {a['slope_near_top_deg']:.1f} degrees"
                                 for a, b in zip(after, before)) or 'no summit checked'))
    lines.append(_line(7, bool(after) and all(s['plateau_m'] < float(Q['plateau_max_m']) for s in after),
                       '; '.join(f"{_where(s)}: widest flat cap {s['plateau_m']:.0f} m (under {Q['plateau_max_deg']} degrees within "
                                 f"{Q['plateau_within_m']} m of the top; limit {Q['plateau_max_m']} m)" for s in after) or 'no summit checked'))
    heads = [hd for s in (rt or []) for hd in s['heads']]
    rates = [hd['rate_mm_yr'] for hd in heads if hd['rate_mm_yr'] is not None]
    if not rates:
        lines.append(_line(8, None, f'no headwall stood in two cycles (cycles: {source})'))
    else:
        lo, hi = Q['retreat_mm_yr']
        mlo, mhi = Q['retreat_middle_mm_yr']
        med = float(np.median(rates))
        note = '' if mlo <= med <= mhi else f'; outside the middle {mlo} to {mhi} (noted)'
        lines.append(_line(8, lo <= med <= hi, f'median headwall retreat {med:.2f} mm per active ice year over {len(rates)} heads '
                                               f'(measured {lo} to {hi}){note}; each: ' +
                           ', '.join(f"{hd['facing']} {hd['bearing_deg']:.0f}: {hd['rate_mm_yr']:.2f}" for hd in heads if hd['rate_mm_yr'] is not None)))
    sb = float(Q.get('shady_bearing_deg', 45.0))
    lat = Q.get('latitude_deg')
    names = f"shady {_compass(sb)}, sunny {_compass(sb + 180.0)}" + ('' if lat is None else f" at {abs(lat):.1f} {'N' if lat >= 0 else 'S'}")
    ne = [hd['rate_mm_yr'] for hd in heads if hd['rate_mm_yr'] is not None and hd['facing'] == 'shady']
    sw = [hd['rate_mm_yr'] for hd in heads if hd['rate_mm_yr'] is not None and hd['facing'] == 'sunny']
    if not ne or not sw:
        lines.append(_line(9, None, f'{len(ne)} shady and {len(sw)} sunny heads with a rate ({names}); need one of each'))
    else:
        rne, rsw = float(np.mean(ne)), float(np.mean(sw))
        ratio = rne / rsw if rsw > 0.0 else float('inf')
        flo, fhi = Q['shady_sunny_fail_outside']
        nlo, nhi = Q['shady_sunny_ratio']
        fne = [hd['floor_m'] for hd in heads if hd['facing'] == 'shady' and hd['floor_m'] is not None]
        fsw = [hd['floor_m'] for hd in heads if hd['facing'] == 'sunny' and hd['floor_m'] is not None]
        floors = f'; shady cirque floors {np.mean(fsw) - np.mean(fne):.0f} m below sunny ones (measured 100 to 200, noted)' if fne and fsw else ''
        note = '' if nlo <= ratio <= nhi else f' (outside the measured {nlo} to {nhi}, noted)'
        lines.append(_line(9, flo <= ratio <= fhi, f'shady/sunny retreat ratio {ratio:.2f} ({names}){note}: shady {rne:.2f}, sunny {rsw:.2f} mm/yr{floors}'))
    pairs = [(hd['depth_rate_early_mm_yr'], hd['depth_rate_late_mm_yr']) for hd in heads if hd['depth_rate_early_mm_yr'] is not None]
    if not pairs:
        lines.append(_line(10, None, f'no cirque stood by cycle {Q["early_cycles"]} and again later (cycles: {source})'))
    else:
        e, la = float(np.median([p[0] for p in pairs])), float(np.median([p[1] for p in pairs]))
        lines.append(_line(10, la <= e / float(Q['depth_slowdown']),
                           f'median cirque deepening {e:.2f} mm/yr up to cycle {Q["early_cycles"]}, {la:.2f} after '
                           f'(must fall {Q["depth_slowdown"]} times or more; {len(pairs)} heads)'))
    return dict(snowline_m=snowline(Pm), cycles_from=source, landform=before, after=after, retreat=rt, lines=lines)


def _write(out, path):
    json.dump(out, open(f'{path}.json', 'w'), indent=1)
    with open(f'{path}.md', 'w') as f:
        f.write(f"# Peak checks (rule 6), snowline {out['snowline_m']:.0f} m\n\n")
        for ln in out['lines']:
            f.write(f"- Line {ln['line']} {ln['result']}: {ln['text']}\n")
    for ln in out['lines']:
        print(f"Line {ln['line']} {ln['result']}: {ln['text']}")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ''
    args = sys.argv[2:]
    pfile = args.pop() if args and args[-1].endswith('.json') else os.path.join(HERE, 'params.json')
    P = json.load(open(pfile))
    if mode == 'landform' and len(args) in (1, 2):
        _write(check_landform(args[0], args[1] if len(args) > 1 else None, P), f'{args[0]}/peaks_landform')
    elif mode == 'glacial' and len(args) == 2:
        _write(check_glacial(args[0], args[1], P), f'{args[1]}/peaks_glacial')
    else:
        raise SystemExit(__doc__)


if __name__ == '__main__':
    main()
