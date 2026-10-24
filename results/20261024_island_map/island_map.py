import sys, json, struct, numpy as np, zstandard
from scipy import ndimage as ndi
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch, Rectangle
from matplotlib.lines import Line2D

world, out_png, label, apply_delta = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
TILE = 15360.0; S = 1921; STEP = 1920
dctx = zstandard.ZstdDecompressor()

def read_tile(path, names):
    f = open(path, "rb").read()
    _, _, _, hl, tl = struct.unpack("<4sHHII", f[:16])
    table = json.loads(f[16 + hl:16 + hl + tl])
    table = table if isinstance(table, list) else table["sections"]
    res = {}
    for s in table:
        if s["name"] not in names: continue
        raw = f[s["offset"]:s["offset"] + s["size"]]
        raw = dctx.decompress(raw, max_output_size=s["raw_size"]) if s["compression"] == "zstd" else raw
        if s["type"] == "uint16":
            n = len(raw) // 2; a = np.frombuffer(raw, np.uint8)
            v = a[:n].astype(np.uint16) | (a[n:].astype(np.uint16) << 8)
            res[s["name"]] = (v.astype(np.float32) * 0.1 - 4000.0).reshape(S, S)
        else:
            res[s["name"]] = np.frombuffer(raw, np.uint8).reshape(S, S)
    return res

TX0, TZ0, N = 2, 3, 3
W = N * STEP + 1
H = np.zeros((W, W), np.float32); WC = np.zeros((W, W), np.uint8); FL = np.zeros((W, W), np.uint8)
for tz in range(N):
    for tx in range(N):
        t = read_tile(f"{world}/tiles/tile_{TX0+tx}_{TZ0+tz}.tile", {"height", "water_class", "flow"})
        H[tz*STEP:tz*STEP+S, tx*STEP:tx*STEP+S] = t["height"]
        WC[tz*STEP:tz*STEP+S, tx*STEP:tx*STEP+S] = t["water_class"]
ORX, ORZ = TX0 * TILE, TZ0 * TILE
sp = 8.0
if apply_delta:
    f = open(f"{world}/erosion_delta_v1.bin", "rb")
    _, dw, dh, cell, ox, oz, _, _, _ = struct.unpack("<4s2i4f2i", f.read(36))
    D = np.frombuffer(f.read(dw*dh*4), np.float32).reshape(dh, dw)
    jj, ii = np.mgrid[0:W, 0:W]
    u = (ii*sp + ORX - ox) / cell; v = (jj*sp + ORZ - oz) / cell
    dl = ndi.map_coordinates(D, [v, u], order=3, mode="constant", cval=0.0).astype(np.float32)
    H = np.where(H <= 0, H, np.maximum(H + dl, np.minimum(H, 0.3)))

# 16 m output grid
H16 = H[::2, ::2]; WC16 = WC[::2, ::2]; M = H16.shape[0]
land = H16 > 0
# water: tile class 1 ocean; 2 lake; 3 river; 4 marsh
lake = WC16 == 2; river = ndi.binary_dilation(WC16 == 3, iterations=1); marsh = WC16 == 4

# farmland on 32 m grid like island_checks
H32 = H[::4, ::4]; WC32 = WC[::4, ::4]
dx = (H32[1:-1, 2:] - H32[1:-1, :-2]) / 64.0; dz = (H32[2:, 1:-1] - H32[:-2, 1:-1]) / 64.0
slope = np.zeros_like(H32); slope[1:-1, 1:-1] = np.degrees(np.arctan(np.hypot(dx, dz)))
dry = (WC32 == 0) | (WC32 == 4)
BELT = 16.7
farm32 = (H32 > 10.0) & dry & (slope <= BELT)
lab, n = ndi.label(farm32); sizes = ndi.sum(farm32, lab, range(1, n+1))
farm32 = np.isin(lab, np.nonzero(sizes >= 40)[0] + 1)
farm_km2 = farm32.sum() * 32*32 / 1e6
land_km2 = (H32 > 0).sum() * 32*32 / 1e6
lake_km2 = (WC32 == 2).sum() * 32*32 / 1e6
farm16 = np.kron(farm32, np.ones((2, 2), bool))[:M, :M]
farm16 = ndi.binary_closing(farm16, iterations=1) & land & ~lake & ~river
nl = ndi.label(lake)[1]

# hillshade
Hs = ndi.gaussian_filter(np.where(land, H16, H16*0.3), 0.8)
gz, gx = np.gradient(Hs, 16.0)
ex = 2.2
az, alt = np.radians(315), np.radians(40)
sl = np.arctan(ex*np.hypot(gx, gz)); asp = np.arctan2(-gx, gz)  # z down = south
shade = np.sin(alt)*np.cos(sl) + np.cos(alt)*np.sin(sl)*np.cos(az - asp)
shade = np.clip(shade, 0, 1)

def lerp(stops, h):
    xs = [s[0] for s in stops]; out = np.zeros(h.shape + (3,), np.float32)
    for c in range(3): out[..., c] = np.interp(h, xs, [s[1][c] for s in stops])
    return out
landc = lerp([(0, (200, 205, 160)), (10, (95, 150, 80)), (120, (60, 115, 65)), (250, (90, 100, 70)),
              (400, (125, 110, 95)), (600, (170, 160, 150)), (1000, (245, 245, 245))], H16)
seac = lerp([(-3000, (10, 25, 70)), (-300, (25, 60, 120)), (-50, (50, 110, 170)), (0, (110, 175, 205))], H16)
rgb = np.where(land[..., None], landc, seac)
rgb = rgb * (0.55 + 0.6*shade[..., None]) 
rgb = np.clip(rgb, 0, 255)
fa = 0.62
farmcol = np.array([250, 190, 20], np.float32)
rgb = np.where(farm16[..., None], rgb*(1-fa) + farmcol*fa, rgb)
rgb = np.where(marsh[..., None] & land[..., None], rgb*0.5 + np.array([60,150,140])*0.5, rgb)
rgb = np.where(lake[..., None], np.array([30, 120, 230], np.float32), rgb)
rgb = np.where((river & ~lake)[..., None], np.array([20, 70, 220], np.float32), rgb)
img = np.clip(rgb, 0, 255).astype(np.uint8)

# figure 3840x2880
fig = plt.figure(figsize=(38.4, 28.8), dpi=100, facecolor="#1b1f27")
ax = fig.add_axes([0, 0, 0.75, 1]); ax.set_axis_off()
ext = [ORX, ORX + (M-1)*16.0, ORZ + (M-1)*16.0, ORZ]
ax.imshow(img, extent=ext, interpolation="lanczos"); ax.set_xlim(ext[0], ext[1]); ax.set_ylim(ext[2], ext[3])
for k in range(1, N):
    ax.axvline(ORX + k*TILE, color="white", lw=0.8, alpha=0.35, ls="--"); ax.axhline(ORZ + k*TILE, color="white", lw=0.8, alpha=0.35, ls="--")
for tz in range(N):
    for tx in range(N):
        ax.text(ORX + tx*TILE + 250, ORZ + tz*TILE + 500, f"tile {TX0+tx},{TZ0+tz}", color="white", fontsize=17, alpha=0.65, va="top")
sx, sz = 53316, 68476
ax.plot([sx], [sz], marker="*", ms=44, mfc="#ff2d2d", mec="white", mew=3)
ax.annotate("SPAWN\nx53316 z68476", (sx, sz), xytext=(sx+1400, sz-1900), color="white", fontsize=26, weight="bold",
            arrowprops=dict(color="white", lw=3), bbox=dict(fc="#00000099", ec="none", pad=6))
# scale bar 5 km
bx, bz = ORX + 1500, ORZ + (M-1)*16 - 1200
ax.add_patch(Rectangle((bx, bz), 5000, 140, fc="white", ec="black", lw=2))
ax.add_patch(Rectangle((bx, bz), 2500, 140, fc="black", ec="black", lw=2))
ax.text(bx+2500, bz-180, "5 km", color="white", fontsize=28, ha="center", weight="bold", bbox=dict(fc="#00000099", ec="none"))
ax.annotate("N", (ORX+1500, ORZ+1400), xytext=(ORX+1500, ORZ+3200), color="white", fontsize=40, weight="bold", ha="center",
            arrowprops=dict(color="white", lw=4, arrowstyle="-|>", mutation_scale=40))

pa = fig.add_axes([0.76, 0, 0.24, 1]); pa.set_axis_off(); pa.set_xlim(0, 1); pa.set_ylim(0, 1)
pa.text(0.04, 0.95, "Island map", color="white", fontsize=52, weight="bold")
pa.text(0.04, 0.92, "nine starter tiles, top-down", color="#b8c0cc", fontsize=26)
items = [("#ff2d2d", "Spawn"), ("#1e78e6", f"Lakes ({nl} patches, {lake_km2:.1f} km2)"), ("#1446dc", "Rivers"),
         ("#3c9688", "Marsh"), ("#e8b814", f"Farmland ({farm_km2:.0f} km2)"), ("#3c7341", "Other land, shaded by height"),
         ("#f5f5f5", "High ground"), ("#2d5f9d", "Sea, darker = deeper")]
y = 0.86
for c, t in items:
    pa.add_patch(Rectangle((0.04, y-0.012), 0.06, 0.022, fc=c, ec="white", lw=1.5)); pa.text(0.12, y-0.001, t, color="white", fontsize=26, va="center"); y -= 0.045
txt = ("Farmland rule (Dave, 24 Oct):\nvalley up to where the evergreen belt\nends uphill, anywhere the player can\nwalk. Here: dry land above 10 m with\nground slope up to 16.7 deg, on the\n32 m grid, small specks removed.\n\n"
       f"Land {land_km2:.0f} km2, farmland {farm_km2:.0f} km2\n({100*farm_km2/land_km2:.0f}% of land).\n\nData: {label}\n\n8 m heights, 32 m slope.\nNorth is up. Dashed lines = tile edges.")
import textwrap
txt="\n".join("\n".join(textwrap.wrap(l,38)) for l in txt.split("\n"))
pa.text(0.04, y-0.02, txt, color="#d5dbe5", fontsize=23, va="top", linespacing=1.5)
fig.savefig(out_png, dpi=100, facecolor=fig.get_facecolor())
print(label, "land km2", land_km2, "farm km2", farm_km2, "lake patches", nl, "lake km2", lake_km2, "range", float(H.min()), float(H.max()))
