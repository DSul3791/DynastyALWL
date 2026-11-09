"""The glacial history's snowline through time from the LR04 benthic d18O stack (data/lr04_stack.csv; Lisiecki and Raymo 2005),
in place of rule 6's two stand-in worlds (all active ice at one stadial line). The line is scaled linearly between today's line
(glacial.today_ela_m, at the Holocene mean d18O, 0 to 10 ka) and the stadial line (glacial.ela_m, at the LGM mean, 18 to 24 ka),
so colder-than-LGM stages (MIS 12, 16) go below it and the milder early-Pleistocene cycles stay above it. The time-mean line while
the starter summit holds ice comes out about 555 m below today's in the last 1 Myr, the 500 m Porter (1989) gives for average
Quaternary glacial conditions.

The output is a glacial.history list in glacial.py's format, oldest first: the time is cut into steps of glacial.dt, and runs of
steps whose line stays within band_m of the run's first step are one entry (its mean line, as ela_offset_m over ela_m). Steps with
the line at or above today's are interglacial time (rivers). Within an entry the ice time comes first, then any river time.

  python tools/watershed/lr04_history.py PARAMS.json OUT.json [--from-ka 2600] [--to-ka 0] [--band-m 100]

OUT.json is PARAMS.json with glacial.history replaced (and snapshot_after_cycles cleared). Read-only on the inputs; no model run.
"""
import argparse, csv, json, os
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))


def load_stack(path=os.path.join(HERE, 'data', 'lr04_stack.csv')):
    t, d = [], []
    with open(path) as f:
        for row in csv.reader(line for line in f if not line.startswith('#')):
            try:
                t.append(float(row[0])); d.append(float(row[1]))
            except (ValueError, IndexError):
                continue
    return np.array(t), np.array(d)


def snowline(t_ka, today_m, stadial_m, stack=None):
    t, d = stack if stack is not None else load_stack()
    g = np.arange(0.0, 30.0, 1.0)
    dg = np.interp(g, t, d)
    hol, lgm = dg[g <= 10].mean(), dg[(g >= 18) & (g <= 24)].mean()
    return today_m - (np.interp(t_ka, t, d) - hol) / (lgm - hol) * (today_m - stadial_m)


def history(GL, from_ka, to_ka, band_m):
    dt = float(GL['dt'])
    today, stadial = float(GL['today_ela_m']), float(GL['ela_m'])
    edges = np.arange(from_ka * 1000.0, to_ka * 1000.0 + dt - 1e-6, -dt)   # step starts, years before present, oldest first (each covers start to start - dt)
    mid_ka = (edges - dt / 2.0) / 1000.0
    line = snowline(mid_ka, today, stadial)
    out, run = [], None
    for ela in line:
        warm = ela >= today
        # A warm step closes the run's ice time (its rivers follow); a cold step joins only a run still in its ice time and in band.
        if run is not None and (warm or (not run['warm_tail'] and abs(ela - run['first']) <= band_m)):
            run['years'] += dt
            if warm:
                run['warm_tail'] = True
            else:
                run['ice'].append(ela)
            continue
        if run is not None:
            out.append(run)
        run = dict(first=ela, warm_tail=warm, years=dt, ice=[] if warm else [ela])
    out.append(run)
    hist = []
    for r in out:
        ice_years = dt * len(r['ice'])
        hist.append(dict(era=f"LR04 {len(hist) + 1}", cycles=1, period_years=r['years'], active_years=ice_years,
                         interglacial_years=r['years'] - ice_years,
                         ela_offset_m=round(float(np.mean(r['ice'])) - stadial, 1) if r['ice'] else round(today - stadial, 1)))
    return hist


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('params'); ap.add_argument('out')
    ap.add_argument('--from-ka', type=float, default=2600.0); ap.add_argument('--to-ka', type=float, default=0.0)
    ap.add_argument('--band-m', type=float, default=100.0)
    a = ap.parse_args()
    P = json.load(open(a.params))
    GL = P['glacial']
    GL['history'] = history(GL, a.from_ka, a.to_ka, a.band_m)
    GL['snapshot_after_cycles'] = []
    GL['_history_note'] = (f"From the LR04 stack (lr04_history.py), {a.from_ka:.0f} to {a.to_ka:.0f} ka, band {a.band_m:.0f} m, "
                           f"today's line {GL['today_ela_m']} m, stadial line {GL['ela_m']} m.")
    json.dump(P, open(a.out, 'w'), indent=1)
    h = GL['history']
    act = sum(e['active_years'] for e in h)
    mean = sum(e['active_years'] * (GL['ela_m'] + e['ela_offset_m']) for e in h) / max(act, 1.0)
    print(f"{len(h)} entries, {sum(e['period_years'] for e in h) / 1e3:.0f} kyr, {act / 1e3:.0f} kyr of ice, mean line while iced {mean:.0f} m, "
          f"{sum(e['active_years'] for e in h if GL['ela_m'] + e['ela_offset_m'] <= 550) / 1e3:.0f} kyr at or below 550 m")


if __name__ == '__main__':
    main()
