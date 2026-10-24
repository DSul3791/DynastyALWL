"""Whole-island pre-carve on real heights. Usage:
  python3 precarve.py RAW_DIR OUT_DIR [json params]
RAW_DIR has raw_X_Z.f32 (1921x1921 float32, shared edges) for tiles 2..4 x 3..5 (or raw_manifest.json lists them).
Writes OUT_DIR/erosion_delta_v1.bin (ERD1), before_after.png, stats.json."""
import sys, json, os, time, numpy as np, struct
import numba as nb
import lem
from scipy.ndimage import label, distance_transform_edt, zoom
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import LightSource

raw_dir, out_dir = sys.argv[1], sys.argv[2]
P = dict(U=1.2e-3, K=4e-6, D=0.25, dep=0.03, off=0.6, sub=1.5, coast_pow=2.2, basins=14, years=1e6, dt=4000.0,
         X0=2, Z0=3, X1=4, Z1=5, edge_fade_m=1500.0, ramp_m=12000.0)
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
S = 4                                    # 8 m -> 32 m, box average +-2 like TileErosion
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
st, h, sea, fill, area, secs = lem.run_from(c, dx, years=P['years'], dt=P['dt'], K=P['K'], U=P['U'], D=P['D'], dep=P['dep'],
                                           off=P['off'], coast_pow=P['coast_pow'], basins=P['basins'], sub=P['sub'], ramp_m=P['ramp_m'])
delta = (h-start)
delta[start <= 0] = 0.0
# fade to zero toward the grid edge so outside frames see no step
yy, xx = np.mgrid[0:n, 0:n]
edge = np.minimum(np.minimum(yy, xx), np.minimum(n-1-yy, n-1-xx)).astype(float)
f = np.clip(edge*dx/P['edge_fade_m'], 0, 1); f = f*f*(3-2*f)
delta = (delta*f).astype(np.float32)
# land stays land
newh = np.where(start > 0, np.maximum(start+delta, np.minimum(start, 0.05)), start)
delta = (newh-start).astype(np.float32)
with open(f'{out_dir}/erosion_delta_v1.bin', 'wb') as fh:
    fh.write(b'ERD1'); fh.write(struct.pack('<iiffffii', n, n, dx, P['X0']*T*8.0, P['Z0']*T*8.0, 0.0, 0, 0))
    fh.write(delta.astype('<f4').tobytes())

# stats at 8 m: bilinear delta on the fine map
dz = zoom(delta, S, order=1)[:fine.shape[0], :fine.shape[1]]
fin_after = np.where(fine > 0, np.maximum(fine+dz, np.minimum(fine, 0.05)), fine)
def sl(z):
    gy, gx = np.gradient(z, 8.0); return np.degrees(np.arctan(np.hypot(gx, gy)))
def st8(z):
    land = z > 0; s = sl(z); farm = land & (z < 250)
    return dict(summit=float(z.max()), land_km2=float(land.sum()*64/1e6), farm_km2=float(farm.sum()*64/1e6),
                farm_lt10=float((s[farm] < 10).mean()), farm_lt8=float((s[farm] < 8).mean()), median_slope=float(np.median(s[land])))
res = dict(before_8m=st8(fine), after_8m=st8(fin_after), runtime_s=secs, grid=n, max_cut_m=float(-delta.min()), max_fill_m=float(delta.max()))
sea_m = (start <= 0)
riv = (area > 2e6) & ~sea_m
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
