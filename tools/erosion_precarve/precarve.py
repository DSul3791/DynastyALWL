"""Whole-island pre-carve on real heights. Usage:
  python3 precarve.py RAW_DIR OUT_DIR [json params]
RAW_DIR has raw_X_Z.f32 (1921x1921 float32, shared edges) for tiles 2..4 x 3..5 (or raw_manifest.json lists them).
Writes OUT_DIR/erosion_delta_v2.bin (ERD1), before_after.png, stats.json."""
import sys, json, os, time, numpy as np, struct
import numba as nb
import lem
from scipy.ndimage import label, distance_transform_edt, zoom
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import LightSource

raw_dir, out_dir = sys.argv[1], sys.argv[2]
P = dict(U=1.2e-3, K=4e-6, D=0.25, dep=0.03, off=0.6, sub=1.5, coast_pow=2.2, basins=14, years=1e6, dt=4000.0,
         X0=2, Z0=3, X1=4, Z1=5, edge_fade_m=1500.0, fill_max=12.0, dslope=0.25, S=4, ramp_m=12000.0, balance=1.0, bal_smooth=3.0, lowboost=8.0, tarn=True)
if len(sys.argv) > 3: P.update(json.loads(sys.argv[3]))
os.makedirs(out_dir, exist_ok=True)
T = 1920
nx, nz = P['X1']-P['X0']+1, P['Z1']-P['Z0']+1
fine = np.zeros((nz*T+1, nx*T+1), np.float32)
for z in range(P['Z0'], P['Z1']+1):
    for x in range(P['X0'], P['X1']+1):
        a = np.fromfile(f'{raw_dir}/raw_{x}_{z}.f32', '<f4').reshape(T+1, T+1)
        fine[(z-P['Z0'])*T:(z-P['Z0'])*T+T+1, (x-P['X0'])*T:(x-P['X0'])*T+T+1] = a
assert np.isfinite(fine).all()
S = int(P.get('S', 4))
n = (fine.shape[0]-1)//S+1
pad = np.pad(fine, 2, mode='edge')
c = np.zeros((n, n), np.float64)
for dj in range(5):
    for di in range(5):
        c += pad[dj:dj+(n-1)*S+1:S, di:di+(n-1)*S+1:S]
c /= 25.0
dx = 8.0*S
start = c.copy()
t0 = time.time()
lem.RAMP_M = P['ramp_m']
ery_factory = None
if P.get('geology_dir'):
    import rock
    _g = rock.load(P['geology_dir'], P.get('cover_m', 4.0), P.get('cover_ery', 5.0))
    assert _g['n'] == n, (_g['n'], n)
    ery_factory = lambda h0, sea0: rock.make_fn(_g, c, sea0, dx)
uplift_map = None
if P.get('design_uplift'):
    # Uplift told from the design: high where the designed land is high, small at the low coast, none at sea. balance stays 0.
    from scipy.ndimage import gaussian_filter
    smooth = gaussian_filter(np.maximum(c, 0.0), P['design_smooth_cells'])
    uplift_map = P['design_U'] * np.clip(smooth / P['design_ref_m'], 0.0, 1.0) ** P['design_pow']
    uplift_map = np.maximum(uplift_map, P['design_U'] * P['design_floor'])
    uplift_map[c <= 0] = 0.0
st, h, sea, fill, area, secs = lem.run_from(c, dx, years=P['years'], dt=P['dt'], K=P['K'], U=P['U'], D=P['D'], dep=P['dep'],
                                           off=P['off'], coast_pow=P['coast_pow'], basins=P['basins'], sub=P['sub'], ramp_m=P['ramp_m'], balance=P['balance'], bal_smooth=P['bal_smooth'], lowboost=P['lowboost'], tarn=P['tarn'], uplift_map=uplift_map, ery_fn_factory=ery_factory)
delta = (h-start)
delta[start <= 0] = 0.0
# Sonny 25 Oct: a +65 m fill at a hill foot is too much. Soft-cap fill, then smooth the delta where its own slope is above dslope.
fm = P['fill_max']
orig_delta = delta.copy()
delta = np.where(delta > 0, fm*np.tanh(delta/fm), delta)
from scipy.ndimage import gaussian_filter as _gf
for _ in range(6):
    gy_, gx_ = np.gradient(delta, dx)
    wgt = np.clip((np.hypot(gx_, gy_)-0.6*P['dslope'])/(0.6*P['dslope']), 0, 1)
    wgt = _gf(wgt, 2.0)
    delta = delta*(1-wgt)+_gf(delta, 3.0)*wgt
delta = np.where(orig_delta > 0, np.maximum(delta, 0.0), orig_delta)   # cuts stay bit-identical: only fill cells take the smoothed value
delta[start <= 0] = 0.0
# fade to zero toward the grid edge so outside frames see no step
yy, xx = np.mgrid[0:n, 0:n]
edge = np.minimum(np.minimum(yy, xx), np.minimum(n-1-yy, n-1-xx)).astype(float)
f = np.clip(edge*dx/P['edge_fade_m'], 0, 1); f = f*f*(3-2*f)
delta = (delta*f).astype(np.float32)
# land stays land
newh = np.where(start > 0, np.maximum(start+delta, np.minimum(start, 0.05)), start)
delta = (newh-start).astype(np.float32)
with open(f'{out_dir}/erosion_delta_v2.bin', 'wb') as fh:
    import zlib
    ph = zlib.crc32(json.dumps(P, sort_keys=True).encode()) & 0x7fffffff
    fh.write(b'ERD1'); fh.write(struct.pack('<iiffffii', n, n, dx, P['X0']*T*8.0, P['Z0']*T*8.0, 0.0, 0, ph))
    fh.write(delta.astype('<f4').tobytes())

import hashlib, platform, numba, scipy
man = dict(params=P, python=platform.python_version(), numpy=np.__version__, numba=numba.__version__, scipy=scipy.__version__,
           input_sha256={f: hashlib.sha256(open(f'{raw_dir}/{f}', 'rb').read()).hexdigest() for f in sorted(os.listdir(raw_dir)) if f.endswith('.f32')},
           delta_sha256=hashlib.sha256(open(f'{out_dir}/erosion_delta_v2.bin', 'rb').read()).hexdigest())
json.dump(man, open(f'{out_dir}/erosion_delta_manifest.json', 'w'), indent=1)
# stats at 8 m: bilinear delta on the fine map
dz = zoom(delta, S, order=3)[:fine.shape[0], :fine.shape[1]]
fin_after = np.where(fine > 0, np.maximum(fine+dz, np.minimum(fine, 0.05)), fine)
def sl(z):
    gy, gx = np.gradient(z, 8.0); return np.degrees(np.arctan(np.hypot(gx, gy)))
def st8(z):
    land = z > 0; s = sl(z); farm = land & (z < 250)
    return dict(summit=float(z.max()), land_km2=float(land.sum()*64/1e6), farm_km2=float(farm.sum()*64/1e6),
                farm_lt10=float((s[farm] < 10).mean()), farm_lt8=float((s[farm] < 8).mean()), median_slope=float(np.median(s[land])))
def st32(z):
    land = z > 0; g = np.gradient(z, dx); s = np.degrees(np.arctan(np.hypot(g[0], g[1]))); farm = land & (z < 250)
    return dict(farm_lt10=float((s[farm] < 10).mean()), farm_lt8=float((s[farm] < 8).mean()), median_slope=float(np.median(s[land])))
res = dict(before_32m=st32(start), after_32m=st32(newh), before_8m=st8(fine), after_8m=st8(fin_after), runtime_s=secs, grid=n, max_cut_m=float(-delta.min()), max_fill_m=float(delta.max()))
sea_m = (start <= 0)
riv = (area > P.get('river_km2', 2.0)*1e6) & ~sea_m
np.save(f'{out_dir}/area.npy', area.astype(np.float32)); np.save(f'{out_dir}/after.npy', newh.astype(np.float32))
nbm = np.zeros_like(riv)
for a in (-1, 0, 1):
    for b in (-1, 0, 1): nbm |= np.roll(np.roll(sea_m, a, 0), b, 1)
res['river_mouths'] = int(label(riv & nbm, structure=np.ones((3, 3)))[1])
bl, nbas = label((fill > 2) & ~sea_m)
sz = np.bincount(bl.ravel())[1:] if nbas else np.array([])
res['basins_gt1ha'] = int((sz*dx*dx > 1e4).sum())
json.dump(res, open(f'{out_dir}/stats.json', 'w'), indent=1); print(json.dumps(res, indent=1))
ls = LightSource(315, 40)
fig, ax = plt.subplots(1, 2, figsize=(16, 8))
for a, z, t in ((ax[0], start, 'before (real heights)'), (ax[1], newh, 'after 1 million years')):
    a.imshow(ls.shade(np.where(z > 0, z, -30), cmap=plt.cm.terrain, vert_exag=4, blend_mode='soft', dx=dx, dy=dx), origin='upper'); a.set_title(t); a.axis('off')
ax[1].imshow(np.where(riv, 1, np.nan), cmap='winter', origin='upper'); ax[1].imshow(np.where((fill > 2) & ~sea_m, 1, np.nan), cmap='autumn', origin='upper')
plt.tight_layout(); plt.savefig(f'{out_dir}/before_after.png', dpi=90)
