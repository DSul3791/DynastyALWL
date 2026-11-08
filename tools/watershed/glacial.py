"""Stage B2 of the watershed rebuild (docs/water/watershed_rebuild_design.md, step R2b): the glacial history, then the
post-glacial era. It starts from the final ground of the long river era (stage B1, evolve.py), so the ice works on mature
valleys, and it can be rerun with other ice settings without rerunning B1.

Usage (on Dave's PC, never in the cloud):
  python tools/watershed/glacial.py INPUTS_DIR GEOLOGY_DIR B1_DIR OUT_DIR [params.json]
B1_DIR holds evolve.py's ground.npz. Writes OUT_DIR/glacial.npz, glacial.png and glacial_manifest.json.

The model is the glacial stream-power law of Hergarten (2021, Earth Surface Dynamics 9:937), benchmarked against the
process-based ice model iSOSIA by Liebl et al. (2023, Geoscientific Model Development 16:1315). Each cold-stage step:
  1. the ice surface is the ground plus the ice thickness of the previous step; it is routed with its hollows filled (his
     section 4: the flow must follow the ice surface, not the bed);
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
  7. creep on ice-free ground only.
Frozen ground: through the cold stage the ground is taken as permafrost, so all runoff is quick, even on chalk and limestone
(the classic explanation of chalk dry valleys: permafrost made the permeable rock impervious; Goudie 1990, The Landforms of
England and Wales, p. 176). Evaporation uses the cold-stage PET.

Then the post-glacial era: about 11,700 years of today's rivers and creep (evolve.river_step), too short to fill the new
rock basins, as in nature. Every closed hollow left is listed with what made it (ice-scoured floor, a sill of glacial
deposits, or neither) for R3, which gives each lake its cause.
"""
import sys, os, json, time
import numpy as np
import numba as nb

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'erosion_precarve'))
import lem      # noqa: E402
import rock     # noqa: E402
import runoff   # noqa: E402
import evolve   # noqa: E402  (the B1 solver, creep, river step, hollows)


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
def _swath(Ai, ptr, don, order, n, dx, w0, a0, alpha):
    """Spread each ice cell's flux over its swath: the cells within half the glacier's width of it that drain into it,
    found by walking up its donor tree (so the swath stays in its own valley). Where swaths overlap the largest flux wins.
    Hergarten (2021, section 3) measures the half-width from the nearest upstream path point; here it is measured from the
    cell itself, and the cells further up the valley are covered by the swaths of the path cells there, which carry almost
    the same flux. Glaciers no wider than two cells keep their flux in their own cell."""
    N = n * n
    out = Ai.copy()
    stack = np.empty(N, np.int64)
    mark = np.full(N, -1, np.int64)
    for q in range(order.size):
        c = order[q]
        if Ai[c] <= 0.0:
            continue
        half = 0.5 * w0 * (Ai[c] / a0) ** alpha
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
                mark[j] = c
                if out[j] < Ai[c]:
                    out[j] = Ai[c]
                stack[top] = j
                top += 1
    return out


def main():
    inputs_dir, geology_dir, b1_dir, out_dir = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
    P = json.load(open(sys.argv[5] if len(sys.argv) > 5 else os.path.join(HERE, 'params.json')))
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
    g = rock.load(geology_dir, E['cover_m'], E['cover_erodibility'])
    bfi = runoff.bfi_by_rock_id(g['names'], W['bfi_by_rock'])
    # Rock erodibility with the loose cover B1 left: make_fn starts its cover from the slope of the ground it is given, so it
    # is then set to B1's sediment thickness (update adds the difference).
    ery_fn = rock.make_fn(g, b1['ground'].astype(np.float64), sea, dx)
    gy, gx = np.gradient(b1['ground'].astype(np.float64), dx)
    cover0 = (E['cover_m'] * np.clip(1.0 - np.degrees(np.arctan(np.hypot(gx, gy))) / 42.0, 0.0, 1.0)).ravel()
    ery_fn.update(np.where(land, deposit - cover0, 0.0))
    CH = E['channel_head']
    theta = float(CH['slope_exponent'])
    c_ch = float(CH['area_m2_at_ref_slope']) * float(CH['ref_slope']) ** theta
    Sc, sc_rock = evolve.slope_limits(g, E)        # threshold slopes by rock, as in B1
    frame = np.zeros((n, n), bool); frame[0, :] = frame[-1, :] = frame[:, 0] = frame[:, -1] = True
    fixed = (sea == 1) | frame.ravel()

    # ---- the cold stage ----
    He, Hf = float(GL['ela_m']), float(GL['ela_m']) + float(GL['full_ice_above_ela_m'])
    Kg = float(GL['glacial_K_ratio']) * float(E['K'])
    m = float(E['m'])
    w0, a0, alpha = float(GL['width_m_at_ref_flux']), float(GL['ref_flux_m2']), float(GL['width_exponent'])
    delta, eps, tau = float(GL['thickness_to_width']), float(GL['swath_eps']), float(GL['ice_carry_ratio'])
    Wc = dict(W, pet_mm_yr=float(GL['cold_pet_mm_yr']))
    et_cold = runoff.evaporation(rain_mm, Wc['pet_mm_yr'], Wc['fu_omega'])
    dt = float(GL['dt'])
    steps = int(round(float(GL['years']) / dt))
    ice = np.zeros(N)                                  # thickness from the last step
    ice_max = np.zeros(N)
    flux_max = np.zeros(N)
    t0 = time.time()
    track = []
    for s in range(steps):
        surf = h + ice
        filled, rec, order = lem.route(surf, sea, n)
        frac = np.minimum((surf - He) / (Hf - He), 1.0)
        p_ice = rain_mm * frac                         # mm/yr of ice made (negative: melted)
        Ai, A = _ice_flux(order, rec, sea, cell * p_ice / p0, cell * rain_mm / p0, N)
        ptr, don = _donors(rec, order, N)
        Asw = _swath(Ai, ptr, don, order, n, dx, w0, a0, alpha)
        Aeff = np.where(Asw > 0.0, np.maximum(A, cell) ** eps * Asw ** (1.0 - eps), 0.0)
        # Water: the rain that does not become ice, plus melt, less the cold-stage evaporation; all of it quick (frozen ground).
        water = np.maximum(rain_mm - et_cold - np.maximum(p_ice, 0.0), 0.0)
        water = water + np.maximum(-p_ice, 0.0) * (Ai > 0.0)   # melt reaches the rivers only where there is ice to melt
        Qw = evolve._discharge(order, rec, sea, water / q_ref, cell, N)
        share = evolve._channel_share(Qw, surf, rec, order, sea, n, dx, c_ch, theta)
        ery = ery_fn(h)                                # the top layer, cover where there is any: creep moves it
        ery_rock, ery_cov, cov = ery_fn.parts(h)       # ice and water strip the loose cover first, then cut the rock (evolve._solve)
        Qwi = np.where(Qw > 0.0, Qw, cell)
        kq = Kg * ery_rock * Aeff ** m + E['K'] * ery_rock * share * Qwi ** m
        kq_c = Kg * ery_cov * Aeff ** m + E['K'] * ery_cov * share * Qwi ** m
        Qd = Qwi + tau * Aeff
        thick = np.where(Aeff > 0.0, delta * w0 * (Aeff / a0) ** alpha, 0.0)
        thick[sea == 1] = 0.0
        x = h + thick                                  # solve on the ice surface (his section 4: add h, erode, subtract h)
        x0 = x.copy()
        # The slope limit is for ground, not ice: none on ice cells (a glacier's front is steep ice, not a hillslope), while
        # ice-free walls are measured against the ice surface beside them (the ice holds them up; after it melts, the
        # post-glacial era lets the oversteepened walls fail, as paraglacial rock slope failures do).
        sc = np.where(thick > 0.0, 0.0, evolve.cell_limits(Sc, sc_rock, rock.rock_ids(g, h), deposit))
        # The incision threshold is for flowing water on bedrock; ice cuts whatever its flux (none under the ice).
        kc = np.where(thick > 0.0, 0.0, E['K'] * ery_rock * share * evolve.bedrock_threshold(E))
        flux = evolve._solve(x, x0, sea, order, rec, n, dx, dt, kq, kc, kq_c, cov.copy(), E['G'], U, Qd, cell, E['sweeps'], E['tol_m'], sc)
        h0 = h.copy()
        h = x - thick
        h[land] = np.maximum(h[land], 0.05)
        evolve._diffuse(h, fixed | (thick > 0.0), dx, dt, E['D'], ery)
        change = h - (h0 + U * dt)
        deposit = np.maximum(deposit + change, 0.0)
        ery_fn.update(change)
        ice = thick
        ice_max = np.maximum(ice_max, thick)
        flux_max = np.maximum(flux_max, Ai)
        track.append((s, float((thick[land] > 0.0).sum() * cell / 1e6), float(thick.max()), float(h.max())))
        if s % 5 == 0:
            print(f'cold step {s}/{steps} t {time.time() - t0:.0f} s, ice {track[-1][1]:.1f} km2, thickest {track[-1][2]:.0f} m, '
                  f'max ground {track[-1][3]:.0f} m', flush=True)
        bound = float(b1_ground.max()) + float(U.max()) * float(GL['years']) + 100.0
        if not np.isfinite(h).all() or h.max() > bound:
            raise SystemExit(f'glacial: unstable at cold step {s}: max ground {h.max():.3g} m is above the bound {bound:.0f} m')
    cold_ground = h.copy()
    cold_deposit = deposit.copy()
    glacial_cut = b1_ground + U * float(GL['years']) - cold_ground     # rock and soil the cold stage removed (uplift aside)
    laid = np.maximum(cold_deposit - b1['sediment_m'].astype(np.float64).ravel(), 0.0)
    till = np.where(ice_max > 0.0, laid, 0.0)          # laid under or at the ice: till and moraine
    outwash = np.where(ice_max > 0.0, 0.0, laid)       # laid beyond it: outwash and other cold-stage fill

    # ---- the post-glacial era: today's climate ----
    dtp = float(GL['post_glacial_dt'])
    psteps = max(int(round(float(GL['post_glacial_years']) / dtp)), 1)
    for s in range(psteps):
        change, flux, _ = evolve.river_step(h, sea, n, dx, dtp, E, U, rain_mm, g, bfi, W, q_ref, ery_fn, c_ch, theta, Sc, sc_rock, deposit,
                                         fixed)
        deposit = np.maximum(deposit + change, 0.0)
    print(f'post-glacial {psteps} steps done, t {time.time() - t0:.0f} s', flush=True)

    # ---- outputs ----
    filled, rec, order = lem.route(h, sea, n)
    rid = rock.rock_ids(g, h)
    wb = runoff.budget(rain_mm, rid, bfi, W)
    Q = evolve._discharge(order, rec, sea, wb['quick'] / q_ref, cell, N)
    share = evolve._channel_share(Q, h, rec, order, sea, n, dx, c_ch, theta)
    area = evolve._discharge(order, rec, sea, np.ones(N), cell, N)
    pit = filled - h
    # Hollows with what made them (R3 names the lake causes from these): a floor the ice cut by more than scour_m (a
    # glacial rock basin, or a cirque when it lies high), a sill on glacial deposits more than 1 m thick (a moraine or till
    # dam), a sill on other sediment (a fan or floodplain dam), or none of these.
    lab, deep, size, outlet = evolve._hollows(pit, rec, sea, n, 0.1)
    scour_m = float(GL['scour_m'])
    o = np.maximum(outlet, 0)
    floor_cut = glacial_cut[deep] if deep.size else np.zeros(0)
    sill_glacial = np.where(outlet >= 0, till[o] + outwash[o], 0.0)
    sill_sed = np.where(outlet >= 0, deposit[o], 0.0)
    kind = np.where(floor_cut > scour_m, 'ice-scoured floor',
                    np.where(sill_glacial > 1.0, 'glacial deposit sill', np.where(sill_sed > 1.0, 'other sediment sill', 'none')))
    causes = ('ice-scoured floor', 'glacial deposit sill', 'other sediment sill', 'none')
    code = np.array([causes.index(str(k)) for k in kind], np.int64)
    hollow_cause = np.where(lab >= 0, code[np.maximum(lab, 0)] if code.size else -1, -1)   # -1 where there is no hollow
    R = lambda a, t=np.float32: a.reshape(n, n).astype(t)
    np.savez_compressed(f'{out_dir}/glacial.npz', ground=R(h), b1_ground=R(b1_ground), cold_ground=R(cold_ground),
                        ice_max_m=R(ice_max), ice_flux_max_m2=R(flux_max), glacial_cut_m=R(glacial_cut),
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
    summary = dict(seconds=time.time() - t0, cold_steps=steps, post_glacial_steps=psteps, ela_m=He,
                   ice_max_km2=float((iced & land).sum() * cell / 1e6), ice_thickest_m=float(ice_max.max()),
                   ice_at_coast_cells=int((iced & land & _coast(sea, n)).sum()),
                   lowest_ice_m=float(b1_ground[iced & land].min()) if (iced & land).any() else None,
                   glacial_cut_max_m=float(glacial_cut[land].max()),
                   glacial_cut_mean_under_ice_m=float(glacial_cut[iced & land].mean()) if (iced & land).any() else 0.0,
                   till_km2_over_1m=float((till > 1.0).sum() * cell / 1e6), outwash_km2_over_1m=float((outwash > 1.0).sum() * cell / 1e6),
                   summit_m=float(hh[landg].max()), b1_summit_m=float(b1_ground.max()), mean_land_m=float(hh[landg].mean()),
                   hollows=hollows, max_slope_deg=float(slope[landg].max()),
                   share_of_land_steeper_than_deg={str(a): float((slope[landg] > a).mean()) for a in (25, 30, 35, 40)},
                   track_every_5=[t for t in track if t[0] % 5 == 0])
    json.dump(dict(params=P, inputs={'inputs.npz': evolve.sha(f'{inputs_dir}/inputs.npz'), 'ground.npz': evolve.sha(f'{b1_dir}/ground.npz')},
                   summary=summary), open(f'{out_dir}/glacial_manifest.json', 'w'), indent=1)
    print(json.dumps(summary, indent=1))
    import plots
    plots.glacial_picture(f'{out_dir}/glacial.npz', f'{out_dir}/glacial.png')


def _coast(sea, n):
    """Land cells next to the sea (8 neighbours): a glacier there reaches the coast."""
    s = sea.reshape(n, n).astype(bool)
    near = np.zeros_like(s)
    for dr in (-1, 0, 1):
        for dc in (-1, 0, 1):
            near |= np.roll(np.roll(s, dr, 0), dc, 1)
    return (near & ~s).ravel()


if __name__ == '__main__':
    main()
