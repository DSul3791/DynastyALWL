"""Stage B2 of the watershed rebuild (docs/water/watershed_rebuild_design.md, step R2b): the glacial history, then the
post-glacial era. It starts from the final ground of the long river era (stage B1, evolve.py), so the ice works on mature
valleys, and it can be rerun with other ice settings without rerunning B1.

Usage (on Dave's PC, never in the cloud):
  python tools/watershed/glacial.py INPUTS_DIR GEOLOGY_DIR B1_DIR OUT_DIR [params.json] [--start SNAPSHOT.npz]
B1_DIR holds evolve.py's ground.npz. Writes OUT_DIR/glacial.npz, glacial.png and glacial_manifest.json. --start begins the
history from a saved cycle (glacial_cycle_NN.npz) instead of B1's ground: a probe that runs a few cycles with other settings
(the params file's glacial.history), not a record run.
  python tools/watershed/glacial.py report GEOLOGY_DIR OUT_DIR [params.json]
reads a saved OUT_DIR/glacial.npz and writes OUT_DIR/glacial_report.json (where the ice cut most, where the ground is steepest;
see report), in seconds. The same report is in the manifest's summary under 'where'.

The model is the glacial stream-power law of Hergarten (2021, Earth Surface Dynamics 9:937), benchmarked against the
process-based ice model iSOSIA by Liebl et al. (2023, Geoscientific Model Development 16:1315). Each cold-stage step:
  1. the ice surface is the ground plus the ice thickness of the previous step; it is routed with its hollows filled (his
     section 4: the flow must follow the ice surface, not the bed), by the same D8-LTD as B1 (evolve.route);
  2. mass balance (his eq. 23): the share of each cell's precipitation that becomes ice rises linearly from 0 at the snowline
     (equilibrium-line altitude, H_e) to 1 at H_f; below the snowline it is negative (melt), at the same rate per metre;
  3. ice flux A_i as an equivalent catchment area at the reference precipitation (eqs. 17, 20, 21), accumulated down the ice
     surface; ice that has all melted passes nothing on, so each glacier ends where its flux reaches zero;
  4. the swath (his section 3): a glacier is wider than one cell, w = w0 (A_i / a0)^0.3 (eq. 13, the exponent from Prasicek
     et al.); the flux of each ice cell is given to the cells within w/2 of it that drain into it (its own valley floor and
     sides, never across a ridge), the largest flux winning where swaths overlap. Erosion uses A_eff = A^0.25 A_i^0.75
     (eq. 22, eps = 0.25), so the floor stays slightly parabolic and the ice does not run in parallel lines;
  5. thickness h = delta w, from A_eff (so it thins toward the swath margins);
  6. erosion and deposition with the same implicit solve as B1 (evolve._solve) on the ice surface: the erosion coefficient
     is K_g e A_eff^m (glacial, eq. 19) plus K e share Q_w^m (the meltwater and rain not held as ice, eq. 24), and the
     carrying flow of the deposition term is Q_w + tau A_eff (ice carries sediment far better than water, his section 5), so
     the load drops where the ice thins and ends: moraines, till and outwash come from the sediment budget, not from a rule;
  7. creep on ice-free ground only. The threshold-slope cap of B1 holds the ground under the ice as well (measured ground to
     ground, not on the ice surface), so rock walls stand no steeper under a glacier than beside a river.
Frozen ground: through the cold stage the ground is taken as permafrost, so all runoff is quick, even on chalk and limestone
(the classic explanation of chalk dry valleys: permafrost made the permeable rock impervious; Goudie 1990, The Landforms of
England and Wales, p. 176). Evaporation uses the cold-stage PET.

Then the post-glacial era: about 11,700 years of today's rivers and creep (evolve.river_step), too short to fill the new
rock basins, as in nature. Every closed hollow left is listed with what made it (ice-scoured floor, a sill of glacial
deposits, or neither) for R3, which gives each lake its cause.

The glacial history (design A1 rule 6, docs/water/rule6_build_plan.md, 8 Nov 2026). With glacial.history set, the one cold
stage becomes cycles, era by era (the 41 kyr world from 2.6 Ma, then the 100 kyr world since about 1 Ma): each cycle is a
cold phase of active_years with the snowline ela_offset_m higher than glacial.ela_m, then an interglacial of
interglacial_years of today's rivers (the last one is the Holocene, so the run ends today); the rest of the period passes
with uplift only (full-glacial ice sheets are not modelled; cirques do not grow under them). The snowline lies aspect_ela_m
lower on steep ground facing the shady lee quarter (shady_bearing_deg) and as much higher facing the sunny one. After every
cycle the peak shapes (peaks.shapes) go into the manifest's summary.cycles, and the rule 6 checks (peaks.check_glacial,
lines 4 to 10) into summary.peaks; snapshot_after_cycles saves glacial_cycle_NN.npz. ice_cut_m is the ice's own cut (the
cold phases only), which the hollow causes and the report use; glacial_cut_m also holds the interglacial rivers' work.
With no history the run is the one cold stage and post-glacial era above.
"""
import sys, os, json, time
import numpy as np
import numba as nb

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'erosion_precarve'))
import rock     # noqa: E402
import runoff   # noqa: E402
import evolve   # noqa: E402  (the B1 solver, creep, river step, hollows)
import world    # noqa: E402  (the island's latitude from its tile row)


@nb.njit(cache=True)
def _ice_flux(order, rec, sea, ice_src, all_src, N):
    """Ice flux A_i and total flux A as equivalent areas (m2 at the reference precipitation), accumulated downstream
    (Hergarten 2021 eqs. 20 and 21). ice_src: cell * p_i / p0, negative below the snowline (melt). A donor whose ice has all
    melted passes nothing on, so a glacier ends where its flux reaches zero and no negative ice flows on."""
    Ai = np.zeros(N)
    A = np.zeros(N)
    for q in range(order.size):
        i = order[q]
        Ai[i] = ice_src[i]
        A[i] = all_src[i]
    for q in range(order.size - 1, -1, -1):              # upstream first: every donor is final before it passes on
        i = order[q]
        d = rec[i]
        if d >= 0 and not sea[d]:
            A[d] += A[i]
            if Ai[i] > 0.0:
                Ai[d] += Ai[i]
    for i in range(N):
        if Ai[i] < 0.0:
            Ai[i] = 0.0
    return Ai, A


@nb.njit(cache=True)
def _donors(rec, order, N):
    """Donor lists in compressed form: the donors of cell i are don[ptr[i]:ptr[i + 1]]."""
    ptr = np.zeros(N + 1, np.int64)
    for q in range(order.size):
        d = rec[order[q]]
        if d >= 0:
            ptr[d + 1] += 1
    for i in range(N):
        ptr[i + 1] += ptr[i]
    fill = ptr[:N].copy()
    don = np.empty(ptr[N], np.int64)
    for q in range(order.size):
        i = order[q]
        d = rec[i]
        if d >= 0:
            don[fill[d]] = i
            fill[d] += 1
    return ptr, don


@nb.njit(cache=True)
def _swath(Ai, ptr, don, order, n, dx, w0, a0, alpha, ground, delta, below_surface):
    """Spread each ice cell's flux over its swath: the cells within half the glacier's width of it that drain into it,
    found by walking up its donor tree (so the swath stays in its own valley). Where swaths overlap the largest flux wins.
    Hergarten (2021, section 3) measures the half-width from the nearest upstream path point; here it is measured from the
    cell itself, and the cells further up the valley are covered by the swaths of the path cells there, which carry almost
    the same flux. Glaciers no wider than two cells keep their flux in their own cell.
    below_surface (glacial.swath_below_ice_surface): a cell joins the swath only if its ground lies below the ice surface of
    the cell the swath starts from (that cell's ground plus its thickness delta x width), and the walk does not go on past
    it. A glacier covers its valley floor and the lower valley sides up to its own surface; it does not cover the rock wall
    above it (the bergschrund and the headwall above it stand bare). Without the rule the half-width alone decides, so at a
    valley head the trough's flux and 100 m of ice were laid on 57-degree walls within half a width of the floor (ws580h).
    Returns the swath flux and, per cell, the ice surface of the swath it takes its flux from (its own ground where none)."""
    N = n * n
    out = Ai.copy()
    surf = ground.copy()
    stack = np.empty(N, np.int64)
    mark = np.full(N, -1, np.int64)
    for q in range(order.size):
        c = order[q]
        if Ai[c] <= 0.0:
            continue
        half = 0.5 * w0 * (Ai[c] / a0) ** alpha
        top_c = ground[c] + delta * 2.0 * half       # the ice surface over the start cell: ground plus delta x width
        if surf[c] < top_c and out[c] <= Ai[c]:
            surf[c] = top_c
        if half <= dx:
            continue
        lim2 = half * half
        rc = c // n
        cc = c % n
        mark[c] = c
        stack[0] = c
        top = 1
        while top > 0:
            top -= 1
            i = stack[top]
            for k in range(ptr[i], ptr[i + 1]):
                j = don[k]
                if mark[j] == c:
                    continue
                dr = float(j // n - rc) * dx
                dc = float(j % n - cc) * dx
                if dr * dr + dc * dc > lim2:
                    continue
                if below_surface and ground[j] >= top_c:
                    continue
                mark[j] = c
                if out[j] < Ai[c]:
                    out[j] = Ai[c]
                    surf[j] = top_c
                stack[top] = j
                top += 1
    return out, surf


def _aspect_shift(h, GL, n, dx):
    """Metres the snowline lies lower on each cell (design A1 rule 6): aspect_ela_m on steep ground facing the shady lee
    quarter (GL['shady_bearing_deg'], set by main() from the island's latitude, world.py: 45, NE, north of the equator; 135,
    SE, south of it), as much higher facing the
    sunny one, scaled by the slope up to aspect_full_slope_deg. The aspect is that of the ground smoothed over
    aspect_smoothing_m: a valley head's, not one cell's. 0 everywhere when aspect_ela_m is 0 or missing."""
    a = float(GL.get('aspect_ela_m', 0.0))
    if a == 0.0:
        return 0.0
    from scipy.ndimage import gaussian_filter
    sm = gaussian_filter(h.reshape(n, n), float(GL['aspect_smoothing_m']) / dx)
    gz, gx = np.gradient(sm, dx)                       # rows run +z (south), columns +x (east); north is -z
    g = np.maximum(np.hypot(gx, gz), 1e-9)
    b = np.radians(float(GL['shady_bearing_deg']))
    shady = (-gx * np.sin(b) + gz * np.cos(b)) / g     # +1 where the slope faces the shady lee quarter, -1 the sunny one
    steep = np.clip(np.degrees(np.arctan(g)) / float(GL['aspect_full_slope_deg']), 0.0, 1.0)
    return (a * shady * steep).ravel()


def main():
    args = sys.argv[1:]
    start = None
    if '--start' in args:                              # --start SNAPSHOT.npz: begin from a saved cycle (a probe, not a record run)
        k_ = args.index('--start')
        start = args[k_ + 1]
        del args[k_:k_ + 2]
    inputs_dir, geology_dir, b1_dir, out_dir = args[0], args[1], args[2], args[3]
    P = json.load(open(args[4] if len(args) > 4 else os.path.join(HERE, 'params.json')))
    E, GL, W = P['evolve'], P['glacial'], P['water_budget']
    os.makedirs(out_dir, exist_ok=True)
    data = np.load(f'{inputs_dir}/inputs.npz')
    b1 = np.load(f'{b1_dir}/ground.npz')
    n = b1['ground'].shape[0]
    dx = float(b1['cell_m'])
    cell = dx * dx
    N = n * n
    if abs(dx - float(data['cell_m'])) > 1e-6 or data['landform'].shape[0] != n:
        raise SystemExit('glacial: the B1 ground and the inputs are on different grids')
    # One sky (design A4): the shady lee quarter follows the island's latitude from its tile row on the world grid.
    sky = world.sky(P, float(data['origin_z']), n * dx)
    GL = dict(GL, shady_bearing_deg=sky['shady_bearing_deg'])
    sea = b1['sea'].ravel().astype(np.uint8)
    land = sea == 0
    # The uplift B1 used (zero when B1 dissects the landform as it stands, uplift_share 0); the inputs' A2 uplift for older runs.
    U = (b1['uplift'] if 'uplift' in b1.files else data['uplift']).astype(np.float64).ravel()
    rain_mm = data['rain'].astype(np.float64).ravel()
    p0 = float(P['rain']['background_mm_yr'])
    q_ref = runoff.reference_quick_mm(p0, W)
    h = b1['ground'].astype(np.float64).ravel().copy()
    b1_ground = h.copy()
    deposit = b1['sediment_m'].astype(np.float64).ravel().copy()
    ground0 = b1['ground'].astype(np.float64)
    if start:
        # A probe from a saved cycle (glacial_cycle_NN.npz): its ground, and its loose cover where the snapshot kept it
        # (snapshots before this change did not: B1's cover is used, the same for every probe from that snapshot).
        snap = np.load(start)
        if snap['ground'].shape != b1['ground'].shape:
            raise SystemExit('glacial: the start snapshot and the B1 ground are on different grids')
        ground0 = snap['ground'].astype(np.float64)
        h = ground0.ravel().copy()
        if 'sediment_m' in snap.files:
            deposit = snap['sediment_m'].astype(np.float64).ravel().copy()
        print(f'glacial: starting from {start} (max ground {h.max():.0f} m)', flush=True)
    g = rock.load(geology_dir, E['cover_m'], E['cover_erodibility'])
    bfi = runoff.bfi_by_rock_id(g['names'], W['bfi_by_rock'])
    # Rock erodibility with the loose cover B1 left: make_fn starts its cover from the slope of the ground it is given, so it
    # is then set to B1's sediment thickness (update adds the difference).
    ery_fn = rock.make_fn(g, ground0, sea, dx)
    gy, gx = np.gradient(ground0, dx)
    cover0 = (E['cover_m'] * np.clip(1.0 - np.degrees(np.arctan(np.hypot(gx, gy))) / 42.0, 0.0, 1.0)).ravel()
    ery_fn.update(np.where(land, deposit - cover0, 0.0))
    CH = E['channel_head']
    theta = float(CH['slope_exponent'])
    c_ch = float(CH['area_m2_at_ref_slope']) * float(CH['ref_slope']) ** theta
    a_min = float(CH.get('min_area_m2', 0.0))
    ones = np.ones(N)
    Sc, sc_rock = evolve.slope_limits(g, E)        # threshold slopes by rock, as in B1
    frame = np.zeros((n, n), bool); frame[0, :] = frame[-1, :] = frame[:, 0] = frame[:, -1] = True
    fixed = (sea == 1) | frame.ravel()

    # ---- the glacial history (design A1 rule 6, docs/water/rule6_build_plan.md change 2) ----
    # Cycles of a cold phase (the cirque glaciers at work) and an interglacial (today's rivers and creep), era by era:
    # glacial.history, the 41 kyr world and then the 100 kyr world. With no history it is one cold stage of glacial.years
    # and the post-glacial era, as before. The rest of each cycle (full-glacial ice-sheet cover and frozen dry time) passes
    # with uplift only: cirques do not grow under ice sheets, and that ice is not modelled.
    He, Hf = float(GL['ela_m']), float(GL['ela_m']) + float(GL['full_ice_above_ela_m'])
    Kg = float(GL['glacial_K_ratio']) * float(E['K'])
    m = float(E['m'])
    w0, a0, alpha = float(GL['width_m_at_ref_flux']), float(GL['ref_flux_m2']), float(GL['width_exponent'])
    delta, eps, tau = float(GL['thickness_to_width']), float(GL['swath_eps']), float(GL['ice_carry_ratio'])
    # Two settings from ws580h's line 4 (docs/water/glacial_summit_fix.md), both off by default so older runs reproduce:
    # balance_ratio, the melt per metre below the snowline over the gain per metre above it (1: Hergarten's eq. 23 as he
    # wrote it; measured glaciers 1.56, Oien et al. 2022), and swath_below_ice_surface (see _swath).
    BR = float(GL.get('balance_ratio', 1.0))
    below = bool(GL.get('swath_below_ice_surface', False))
    Wc = dict(W, pet_mm_yr=float(GL['cold_pet_mm_yr']))
    et_cold = runoff.evaporation(rain_mm, Wc['pet_mm_yr'], Wc['fu_omega'])
    history = GL.get('history') or [dict(era='one cold stage', cycles=1, active_years=float(GL['years']),
                                         interglacial_years=float(GL['post_glacial_years']), ela_offset_m=0.0,
                                         period_years=float(GL['years']) + float(GL['post_glacial_years']))]
    total_years = sum(int(e['cycles']) * float(e['period_years']) for e in history)
    bound = float(b1_ground.max()) + float(U.max()) * total_years + 100.0
    st = dict(h=h, deposit=deposit, ice_max=np.zeros(N), flux_max=np.zeros(N), ice_cycle_max=np.zeros(N), ice_cut=np.zeros(N), ice_carry=np.zeros(N),
              flux=np.zeros(N), steps=0, psteps=0)
    t0 = time.time()
    track = []

    def _cold_phase(years, ela_local, k):
        """One cold phase of `years`: the old cold stage's step, with the snowline ela_local (per cell). It starts from no ice
        after an interglacial, or from the last cold phase's ice when none came between (an LR04 history, lr04_history.py,
        cuts one glaciation into several phases at different snowlines). A phase of no years does nothing (8 Nov 2026: probe L
        crashed on a zero-year river phase, a division by its dt in evolve._solve)."""
        st['ice_cycle_max'] = np.zeros(N)
        if years <= 0.0:
            return
        steps = max(int(round(years / float(GL['dt']))), 1)
        dt = years / steps
        h, deposit = st['h'], st['deposit']
        ice = st['ice_carry']                          # thickness from the last step
        for s in range(steps):
            surf = h + ice
            filled, rec, order = evolve.route(surf, sea, n, dx, evolve.flow_memory(E))
            frac = np.minimum((surf - ela_local) / (Hf - He), 1.0)
            frac = np.where(frac < 0.0, frac * BR, frac)   # melt below the snowline at balance_ratio times the gain above it
            p_ice = rain_mm * frac                     # mm/yr of ice made (negative: melted)
            Ai, A = _ice_flux(order, rec, sea, cell * p_ice / p0, cell * rain_mm / p0, N)
            ptr, don = _donors(rec, order, N)
            Asw, ice_top = _swath(Ai, ptr, don, order, n, dx, w0, a0, alpha, h, delta, below)
            Aeff = np.where(Asw > 0.0, np.maximum(A, cell) ** eps * Asw ** (1.0 - eps), 0.0)
            # Water: the rain that does not become ice, plus melt, less the cold-stage evaporation; all of it quick (frozen ground).
            water = np.maximum(rain_mm - et_cold - np.maximum(p_ice, 0.0), 0.0)
            water = water + np.maximum(-p_ice, 0.0) * (Ai > 0.0)   # melt reaches the rivers only where there is ice to melt
            Qw = evolve._discharge(order, rec, sea, water / q_ref, cell, N)
            share = evolve._channel_share(Qw, evolve._discharge(order, rec, sea, ones, cell, N), surf, rec, order, sea, n, dx, c_ch, theta, a_min)
            ery = ery_fn(h)                            # the top layer, cover where there is any: creep moves it
            ery_rock, ery_cov, cov = ery_fn.parts(h)   # ice and water strip the loose cover first, then cut the rock (evolve._solve)
            Qwi = np.where(Qw > 0.0, Qw, cell)
            kq = Kg * ery_rock * Aeff ** m + E['K'] * ery_rock * share * Qwi ** m
            kq_c = Kg * ery_cov * Aeff ** m + E['K'] * ery_cov * share * Qwi ** m
            Qd = Qwi + tau * Aeff
            thick = np.where(Aeff > 0.0, delta * w0 * (Aeff / a0) ** alpha, 0.0)
            if below:                                  # a cell in another cell's swath holds ice only up to that glacier's surface
                thick = np.where(Asw > Ai, np.minimum(thick, np.maximum(ice_top - h, 0.0)), thick)
            thick[sea == 1] = 0.0
            x = h + thick                              # solve on the ice surface (his section 4: add h, erode, subtract h)
            x0 = x.copy()
            # The slope limit is for the ground, under the ice too, measured ground to ground (lift = the ice thickness, so a
            # glacier's steep front or surface is not capped, only the rock under it). Run 7b0dfbff had no limit under the
            # ice: on the smooth flanks each one-cell flow line was cut on its own (the swath spreads a glacier's flux only
            # over the cells that drain into it, and parallel lines do not), leaving slots with walls up to 87 degrees and
            # 300 m high, more than the 11,700 post-glacial years could bring down. A rock wall fails past its threshold
            # whether or not ice lies beside it; the debris joins the ice's load (rockfall onto glaciers). The limit holds
            # against every neighbour, not only the receiver (evolve._slope_ceiling): with the receiver alone, run a3ffca14
            # still left 86-degree walls, lowered one cell a step.
            sc = evolve.cell_limits(Sc, sc_rock, rock.rock_ids(g, h), deposit)
            # The incision threshold is for flowing water on bedrock; ice cuts whatever its flux (none under the ice).
            kc = np.where(thick > 0.0, 0.0, E['K'] * ery_rock * share * evolve.bedrock_threshold(E))
            st['flux'] = evolve._solve(x, x0, sea, order, rec, n, dx, dt, kq, kc, kq_c, cov.copy(), E['G'], U, Qd, cell, E['sweeps'], E['tol_m'], sc, thick)
            h0 = h.copy()
            h = x - thick
            h[land] = np.maximum(h[land], 0.05)
            evolve._diffuse(h, fixed | (thick > 0.0), dx, dt, E['D'], ery)
            change = h - (h0 + U * dt)
            deposit = np.maximum(deposit + change, 0.0)
            ery_fn.update(change)
            st['ice_cut'] -= change                    # the ice's own cut: the net lowering in the cold phases, uplift aside
            ice = thick
            st['ice_carry'] = thick
            st['ice_max'] = np.maximum(st['ice_max'], thick)
            st['ice_cycle_max'] = np.maximum(st['ice_cycle_max'], thick)
            st['flux_max'] = np.maximum(st['flux_max'], Ai)
            q = st['steps']
            st['steps'] += 1
            track.append((q, float((thick[land] > 0.0).sum() * cell / 1e6), float(thick.max()), float(h.max())))
            if q % 5 == 0:
                print(f'cycle {k} cold step {s}/{steps} (all {q}) t {time.time() - t0:.0f} s, ice {track[-1][1]:.1f} km2, '
                      f'thickest {track[-1][2]:.0f} m, max ground {track[-1][3]:.0f} m', flush=True)
            if not np.isfinite(h).all() or h.max() > bound:
                raise SystemExit(f'glacial: unstable in cycle {k} at cold step {s}: max ground {h.max():.3g} m is above the bound {bound:.0f} m')
        st['h'], st['deposit'] = h, deposit

    def _river_phase(years):
        """An interglacial of `years`: today's rivers and creep (evolve.river_step), as the old post-glacial era. The ice is
        gone after it. A phase of no years does nothing."""
        if years <= 0.0:
            return
        st['ice_carry'] = np.zeros(N)
        steps = max(int(round(years / float(GL['post_glacial_dt']))), 1)
        dtp = years / steps
        for s in range(steps):
            change, st['flux'], _ = evolve.river_step(st['h'], sea, n, dx, dtp, E, U, rain_mm, g, bfi, W, q_ref, ery_fn, c_ch, theta, a_min, Sc,
                                                     sc_rock, st['deposit'], fixed)
            st['deposit'] = np.maximum(st['deposit'] + change, 0.0)
        st['psteps'] += steps

    # The peak shapes after every cycle (peaks.py, the rule 6 checks), on the landform's own peaks and valley-head bearings.
    import peaks
    Q = peaks._checks(P, sky)
    lf, sea2, _, lox, loz = peaks._load_inputs(inputs_dir)
    tops = peaks.summits(lf, sea2, dx, peaks.snowline(P) + float(Q['above_snowline_m']), float(Q['summit_window_m']))
    axes = peaks.axes(lf, sea2, dx, tops, Q)
    snap_at = set(int(c) for c in GL.get('snapshot_after_cycles', []))
    R = lambda a, t=np.float32: a.reshape(n, n).astype(t)
    cycles = []
    k = 0
    last_interglacial = 0.0
    for e, era in enumerate(history):
        for c in range(int(era['cycles'])):
            k += 1
            idle = float(era['period_years']) - float(era['active_years']) - float(era['interglacial_years'])
            st['h'] = st['h'] + U * idle               # the rest of the cycle: uplift only (ice-sheet cover not modelled)
            ela_local = He + float(era['ela_offset_m']) - _aspect_shift(st['h'], GL, n, dx)
            _cold_phase(float(era['active_years']), ela_local, k)
            if e == len(history) - 1 and c == int(era['cycles']) - 1:
                cold_ground, cold_deposit = st['h'].copy(), st['deposit'].copy()
                last_interglacial = float(era['interglacial_years'])
            _river_phase(float(era['interglacial_years']))
            cycles.append(dict(cycle=k, era=str(era['era']), shape=peaks.shapes(st['h'].reshape(n, n), lf, sea2, dx, lox, loz, tops, axes, Q)))
            if k in snap_at:
                np.savez_compressed(f'{out_dir}/glacial_cycle_{k:02d}.npz', ground=R(st['h']), ice_max_m=R(st['ice_cycle_max']),
                                    sediment_m=R(st['deposit']), b1_ground=R(b1_ground), sea=R(sea, bool), cell_m=dx, origin_x=float(b1['origin_x']),
                                    origin_z=float(b1['origin_z']))     # plots.py zoom draws it beside the river-era ground
            print(f'cycle {k} ({era["era"]}) done, t {time.time() - t0:.0f} s, max ground {st["h"].max():.0f} m', flush=True)
    h, deposit, flux, ice_max, flux_max = st['h'], st['deposit'], st['flux'], st['ice_max'], st['flux_max']
    steps, psteps = st['steps'], st['psteps']
    # Rock and soil the glacial history removed up to the end of the last cold phase (uplift aside): the ice and the
    # interglacial rivers between. ice_cut is the ice's own share (the cold phases only).
    glacial_cut = b1_ground + U * (total_years - last_interglacial) - cold_ground
    laid = np.maximum(cold_deposit - b1['sediment_m'].astype(np.float64).ravel(), 0.0)
    till = np.where(ice_max > 0.0, laid, 0.0)          # laid under or at the ice: till and moraine
    outwash = np.where(ice_max > 0.0, 0.0, laid)       # laid beyond it: outwash and other cold-stage fill
    print(f'glacial history done: {k} cycles, {steps} cold and {psteps} interglacial steps, t {time.time() - t0:.0f} s', flush=True)

    # ---- outputs ----
    filled, rec, order = evolve.route(h, sea, n, dx, evolve.flow_memory(E))
    rid = rock.rock_ids(g, h)
    wb = runoff.budget(rain_mm, rid, bfi, W)
    Q = evolve._discharge(order, rec, sea, wb['quick'] / q_ref, cell, N)
    share = evolve._channel_share(Q, evolve._discharge(order, rec, sea, ones, cell, N), h, rec, order, sea, n, dx, c_ch, theta, a_min)
    area = evolve._discharge(order, rec, sea, np.ones(N), cell, N)
    pit = filled - h
    # Hollows with what made them (R3 names the lake causes from these): a floor the ice cut by more than scour_m (a
    # glacial rock basin, or a cirque when it lies high), a sill on glacial deposits more than 1 m thick (a moraine or till
    # dam), a sill on other sediment (a fan or floodplain dam), or none of these.
    lab, deep, size, outlet = evolve._hollows(pit, rec, sea, n, 0.1)
    scour_m = float(GL['scour_m'])
    o = np.maximum(outlet, 0)
    floor_cut = st['ice_cut'][deep] if deep.size else np.zeros(0)       # the ice's own cut (the interglacial rivers aside)
    sill_glacial = np.where(outlet >= 0, till[o] + outwash[o], 0.0)
    sill_sed = np.where(outlet >= 0, deposit[o], 0.0)
    kind = np.where(floor_cut > scour_m, 'ice-scoured floor',
                    np.where(sill_glacial > 1.0, 'glacial deposit sill', np.where(sill_sed > 1.0, 'other sediment sill', 'none')))
    causes = ('ice-scoured floor', 'glacial deposit sill', 'other sediment sill', 'none')
    code = np.array([causes.index(str(k)) for k in kind], np.int64)
    hollow_cause = np.where(lab >= 0, code[np.maximum(lab, 0)] if code.size else -1, -1)   # -1 where there is no hollow
    np.savez_compressed(f'{out_dir}/glacial.npz', ground=R(h), b1_ground=R(b1_ground), cold_ground=R(cold_ground),
                        ice_max_m=R(ice_max), ice_flux_max_m2=R(flux_max), glacial_cut_m=R(glacial_cut), ice_cut_m=R(st['ice_cut']),
                        till_m=R(till), outwash_m=R(outwash), sediment_m=R(deposit),
                        quick_area_m2=R(Q), area_m2=R(area), channel=R(share), rock=R(rid, np.int16),
                        et_mm=R(wb['et']), quick_mm=R(wb['quick']), recharge_mm=R(wb['recharge']),
                        receiver=R(rec, np.int32), pit_m=R(pit), sea=R(sea, bool),
                        sediment_flux_m3_yr=R(flux), hollow_cause=R(hollow_cause, np.int8), cell_m=dx, origin_x=float(b1['origin_x']), origin_z=float(b1['origin_z']))

    ox, oz = float(b1['origin_x']), float(b1['origin_z'])

    def _group(sel):
        return dict(count=int(sel.sum()), km2=float(size[sel].sum() * cell / 1e6),
                    deepest_m=float(pit[deep[sel]].max()) if sel.any() else 0.0)
    hollows = dict(min_depth_m=0.1, scour_m=scour_m, all=_group(np.ones(deep.size, bool)),
                   by_cause={k: _group(kind == k) for k in causes},
                   deepest_ten=[dict(x=ox + float(deep[q] % n) * dx, z=oz + float(deep[q] // n) * dx, depth_m=float(pit[deep[q]]),
                                     km2=float(size[q] * cell / 1e6), cause=str(kind[q]), floor_cut_m=float(floor_cut[q]),
                                     floor_height_m=float(h[deep[q]]))
                                for q in np.argsort(-pit[deep])[:10]])
    hh = h.reshape(n, n)
    landg = land.reshape(n, n)
    gy, gx = np.gradient(hh, dx)
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))
    iced = ice_max > 0.0
    summary = dict(seconds=time.time() - t0, cold_steps=steps, post_glacial_steps=psteps, ela_m=He, sky=sky,
                   ice_max_km2=float((iced & land).sum() * cell / 1e6), ice_thickest_m=float(ice_max.max()),
                   ice_at_coast_cells=int((iced & land & _coast(sea, n)).sum()),
                   lowest_ice_m=float(b1_ground[iced & land].min()) if (iced & land).any() else None,
                   glacial_cut_max_m=float(glacial_cut[land].max()),
                   glacial_cut_mean_under_ice_m=float(glacial_cut[iced & land].mean()) if (iced & land).any() else 0.0,
                   till_km2_over_1m=float((till > 1.0).sum() * cell / 1e6), outwash_km2_over_1m=float((outwash > 1.0).sum() * cell / 1e6),
                   summit_m=float(hh[landg].max()), b1_summit_m=float(b1_ground.max()), mean_land_m=float(hh[landg].mean()),
                   hollows=hollows, max_slope_deg=float(slope[landg].max()),
                   share_of_land_steeper_than_deg={str(a): float((slope[landg] > a).mean()) for a in (25, 30, 35, 40)},
                   track_every_5=[t for t in track if t[0] % 5 == 0],
                   history=history, years=total_years,
                   active_ice_years=sum(int(e['cycles']) * float(e['active_years']) for e in history),
                   ice_cut_max_m=float(st['ice_cut'][land].max()), cycles=cycles)
    # Lowering over the run (uplift aside), to set beside measured 10Be rates (Portenga and Bierman 2011, GSA Today 21(8):4: bare
    # outcrops 12 m/Myr mean; drainage basins 182 m/Myr mean where seismically inactive, 54 m/Myr median over all). 8 Nov 2026.
    low = (ground0.ravel() + U * total_years - h) * 1000.0 / max(total_years, 1.0)
    g0 = ground0.ravel()
    summary['lowering_mm_yr'] = {name: float(low[land & m].mean()) if (land & m).any() else None
                                 for name, m in (('land', g0 > -1e9), ('above_300m', g0 > 300.0), ('above_600m', g0 > 600.0),
                                                 ('above_900m', g0 > 900.0))}
    summary['where'] = report(f'{out_dir}/glacial.npz', geology_dir, E)
    man = dict(params=P, inputs={'inputs.npz': evolve.sha(f'{inputs_dir}/inputs.npz'), 'ground.npz': evolve.sha(f'{b1_dir}/ground.npz')},
               summary=summary)
    json.dump(man, open(f'{out_dir}/glacial_manifest.json', 'w'), indent=1)
    # The rule 6 checks, lines 4 to 10 (peaks.py glacial), read back from the files just written; the manifest is
    # written again with them. peaks.py glacial INPUTS_DIR OUT_DIR gives the same lines with the full detail.
    summary['peaks'] = peaks.check_glacial(inputs_dir, out_dir, P)['lines']
    json.dump(man, open(f'{out_dir}/glacial_manifest.json', 'w'), indent=1)
    print(json.dumps({k_: v for k_, v in summary.items() if k_ != 'cycles'}, indent=1))
    import plots
    plots.glacial_picture(f'{out_dir}/glacial.npz', f'{out_dir}/glacial.png')


def report(npz_path, geology_dir, E):
    """Where the cold stage cut most and where the ground is steepest, read from a saved glacial.npz in seconds, so a run can be
    judged without rerunning it (python glacial.py report GEOLOGY_DIR OUT_DIR).
    Cut: under the largest ice extent, its spread (p50, p90, p99), by the rock the ice met (the river-era surface), and the five
    deepest cells with their rock, heights and ice.
    Slope three ways. The plain gradient over the grid (the summary's max_slope_deg) also spans the sea floor, so a coast cell
    beside deep water reads as a cliff the walker never meets. With the sea at sea level (0 m) it is the slope at the shore. The
    steepest drop to any one of the 8 neighbours (sea counted at 0 m) is what the threshold-slope cap holds (each cell stands at
    most its rock's threshold slope above its receiver, the steepest neighbour on the hollow-filled ground), so the report gives
    the share of land whose drop passes its own rock's threshold (by the rock of the final ground, 0.5 degrees of slack), and the
    share over the highest threshold of any rock (granite's 57). Two cases may pass the threshold honestly: a shore cell whose
    receiver is a diagonal sea cell (the drop to the sea beside it is then up to the threshold's tangent times 1.41: about 57
    degrees for 48, 65 for 57), and a cell beside a closed hollow, whose floor the fill hides from the receiver choice. Anywhere
    else it is a fault to find; the five steepest are listed with their rock, the ice there, and whether they lie on the coast,
    on the grid's frame or beside a hollow. The share over 48 degrees stays for comparison with the runs before granite's 57."""
    d = np.load(npz_path)
    n = d['ground'].shape[0]
    dx = float(d['cell_m'])
    ox, oz = float(d['origin_x']), float(d['origin_z'])
    sea = d['sea'].astype(bool)
    land = ~sea
    h = d['ground'].astype(np.float64)
    b1 = d['b1_ground'].astype(np.float64)
    cold = d['cold_ground'].astype(np.float64)
    cut = (d['ice_cut_m'] if 'ice_cut_m' in d.files else d['glacial_cut_m']).astype(np.float64)   # the ice's own cut (older runs: the cold stage's)
    ice = d['ice_max_m'].astype(np.float64)
    g = rock.load(geology_dir, E['cover_m'], E['cover_erodibility'])
    names = g['names']
    rid_b1 = rock.rock_ids(g, b1).reshape(n, n)
    rid = rock.rock_ids(g, h).reshape(n, n)
    coast = _coast(sea.ravel().astype(np.uint8), n).reshape(n, n)
    frame = np.zeros((n, n), bool)
    frame[0, :] = frame[-1, :] = frame[:, 0] = frame[:, -1] = True
    hollow = d['pit_m'].astype(np.float64) > 0.1
    near_hollow = hollow.copy()
    for dr in (-1, 0, 1):
        for dc in (-1, 0, 1):
            near_hollow |= np.roll(np.roll(hollow, dr, 0), dc, 1)
    hs = np.where(land, h, 0.0)
    drop = np.zeros((n, n))                            # steepest drop to a neighbour, as a tangent
    for dr in (-1, 0, 1):
        for dc in (-1, 0, 1):
            if dr == 0 and dc == 0:
                continue
            nb_ = np.full((n, n), np.inf)              # off the grid: no neighbour
            nb_[max(-dr, 0):n - max(dr, 0), max(-dc, 0):n - max(dc, 0)] = hs[max(dr, 0):n - max(-dr, 0), max(dc, 0):n - max(-dc, 0)]
            drop = np.maximum(drop, (hs - nb_) / (dx * (1.4142135623730951 if dr and dc else 1.0)))
    drop = np.where(land, np.degrees(np.arctan(np.maximum(drop, 0.0))), 0.0)
    _, sc_rock = evolve.slope_limits(g, E)
    own_deg = np.degrees(np.arctan(sc_rock[rid]))      # each cell's rock threshold (the plain value under unlisted rocks)
    top_deg = float(np.degrees(np.arctan(sc_rock.max())))
    gy, gx = np.gradient(h, dx)
    s_grid = np.where(land, np.degrees(np.arctan(np.hypot(gx, gy))), 0.0)
    gy, gx = np.gradient(hs, dx)
    s_shore = np.where(land, np.degrees(np.arctan(np.hypot(gx, gy))), 0.0)

    def cell(k, r=None):
        j, i = divmod(int(k), n)
        out = dict(x=ox + i * dx, z=oz + j * dx, rock=names.get(int((r if r is not None else rid)[j, i]), '?'), ground_m=round(float(h[j, i]), 1),
                   b1_m=round(float(b1[j, i]), 1), cold_m=round(float(cold[j, i]), 1), ice_max_m=round(float(ice[j, i]), 1),
                   cut_m=round(float(cut[j, i]), 1), coast=bool(coast[j, i]), frame=bool(frame[j, i]), beside_hollow=bool(near_hollow[j, i]))
        lo = [float(hs[j + a, i + b]) for a in (-1, 0, 1) for b in (-1, 0, 1) if 0 <= j + a < n and 0 <= i + b < n and (a or b)]
        out['lowest_neighbour_m'] = round(min(lo), 1)
        return out

    def top(a, k=5, r=None):
        return [dict(cell(q, r), value=round(float(a.ravel()[q]), 2)) for q in np.argsort(-a.ravel())[:k]]
    iced = (ice > 0.0) & land
    cu = cut[iced]
    by_rock = {}
    for k in np.unique(rid_b1[iced]):
        sel = iced & (rid_b1 == k)
        by_rock[names.get(int(k), str(k))] = dict(km2=round(float(sel.sum() * dx * dx / 1e6), 3), mean=round(float(cut[sel].mean()), 1),
                                                  p90=round(float(np.percentile(cut[sel], 90)), 1), p99=round(float(np.percentile(cut[sel], 99)), 1))
    shares = lambda s: {str(a): round(float((s[land] > a).mean()), 4) for a in (25, 30, 35, 40, 48, 57)}
    return dict(cut_under_ice_m=dict(p50=round(float(np.percentile(cu, 50)), 1), p90=round(float(np.percentile(cu, 90)), 1),
                                     p99=round(float(np.percentile(cu, 99)), 1), max=round(float(cu.max()), 1)) if cu.size else None,
                cut_under_ice_by_rock_met=by_rock,
                deepest_cut=top(np.where(land, cut, -np.inf), r=rid_b1),
                slope_grid_max_deg=round(float(s_grid.max()), 1), slope_grid_steepest=top(s_grid, 3),
                slope_shore_max_deg=round(float(s_shore.max()), 1), slope_shore_share_steeper_than_deg=shares(s_shore),
                neighbour_drop_max_deg=round(float(drop.max()), 1), neighbour_drop_share_over_48_deg=round(float((drop[land] > 48.0).mean()), 5),
                neighbour_drop_share_over_own_rock_threshold=round(float((drop[land] > own_deg[land] + 0.5).mean()), 5),
                neighbour_drop_share_over_highest_threshold=dict(deg=round(top_deg, 1), share=round(float((drop[land] > top_deg + 0.5).mean()), 5)),
                neighbour_drop_steepest=top(drop))


def _coast(sea, n):
    """Land cells next to the sea (8 neighbours): a glacier there reaches the coast."""
    s = sea.reshape(n, n).astype(bool)
    near = np.zeros_like(s)
    for dr in (-1, 0, 1):
        for dc in (-1, 0, 1):
            near |= np.roll(np.roll(s, dr, 0), dc, 1)
    return (near & ~s).ravel()


if __name__ == '__main__':
    if len(sys.argv) >= 4 and sys.argv[1] == 'report':
        # python glacial.py report GEOLOGY_DIR OUT_DIR [params.json]: reads OUT_DIR/glacial.npz, writes OUT_DIR/glacial_report.json
        P_ = json.load(open(sys.argv[4] if len(sys.argv) > 4 else os.path.join(HERE, 'params.json')))
        rep = report(f'{sys.argv[3]}/glacial.npz', sys.argv[2], P_['evolve'])
        json.dump(rep, open(f'{sys.argv[3]}/glacial_report.json', 'w'), indent=1)
        print(json.dumps(rep, indent=1))
    else:
        main()
