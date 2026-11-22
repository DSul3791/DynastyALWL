# Bald head reference renders and head measurements for assets/character/Humanoid/Dynasty_Base_Male.glb (20 Nov 2026).
# Reads the glb only, in its bind (rest) pose, which is the default character (creator genome "average": every slider 0, no width or face shapes, no skin tint).
# Never writes to the glb. Not game code; Godot ignores this folder (.gdignore).
# Run from anywhere: python3 art/references/hair_bald_head_2026-11-20/make_reference.py   (numpy and Pillow; about 30 s)
import json, struct, io, sys, math, os
import numpy as np
from PIL import Image
CT={5126:np.float32,5123:np.uint16,5125:np.uint32,5121:np.uint8}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def load(path):
    f=open(path,'rb').read()
    L=struct.unpack('<I',f[12:16])[0]; j=json.loads(f[20:20+L])
    o=20+L; BL=struct.unpack('<I',f[o:o+4])[0]; b=f[o+8:o+8+BL]
    def acc(i):
        a=j['accessors'][i]; v=j['bufferViews'][a['bufferView']]
        n=NC[a['type']]; dt=CT[a['componentType']]
        st=v.get('byteStride',0); off=v.get('byteOffset',0)+a.get('byteOffset',0)
        isz=np.dtype(dt).itemsize*n
        if st and st!=isz:
            raw=np.frombuffer(b,np.uint8,count=st*(a['count']-1)+isz,offset=off)
            arr=np.lib.stride_tricks.as_strided(raw,(a['count'],isz),(st,1)).copy().view(dt).reshape(a['count'],n)
        else: arr=np.frombuffer(b,dt,count=a['count']*n,offset=off).reshape(a['count'],n)
        return arr
    def img(i):
        im=j['images'][i]; v=j['bufferViews'][im['bufferView']]
        return Image.open(io.BytesIO(b[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]))
    return j,acc,img

HERE = os.path.dirname(os.path.abspath(__file__))
glb = os.path.join(HERE, '../../../assets/character/Humanoid/Dynasty_Base_Male.glb')
out = HERE
OUT = 2048
SS = 2; N = OUT*SS
j,acc,img = load(glb); p = j['meshes'][0]['primitives'][0]
P = acc(p['attributes']['POSITION']).astype(np.float64)
NR = acc(p['attributes']['NORMAL']).astype(np.float64)
UV = acc(p['attributes']['TEXCOORD_0']).astype(np.float64)
I = acc(p['indices']).reshape(-1,3).astype(np.int64)
tex = np.asarray(img(0).convert('RGB')).astype(np.float64)/255.0
TH,TW = tex.shape[:2]
# frame (metres, model space): same for every view
CY, HALF = 1.585, 0.30          # centre height and half size -> y 1.285..1.885
CXZ = (0.0037, 0.0116)          # head bone x,z: horizontal centre of the turn
BG = np.array([0.83,0.83,0.83])
VIEWS = {  # name: camera direction (from model toward camera), model faces +Z, its left is +X
 'front': (0.0,1.0), 'left': (1.0,0.0), 'back': (0.0,-1.0), 'front_three_quarter_left': (math.sqrt(.5),math.sqrt(.5))}
for name,(dx,dz) in VIEWS.items():
    d = np.array([dx,0,dz]); right = np.array([dz,0,-dx])  # screen right
    rel = P - np.array([CXZ[0],0,CXZ[1]])
    sx = rel@right; sy = P[:,1]; sz = rel@d     # sz: larger = nearer camera
    px = (sx/HALF*0.5+0.5)*N; py = (0.5-(sy-CY)/HALF*0.5)*N
    zb = np.full((N,N),-1e9); col = np.zeros((N,N,3)); col[:] = BG
    tri = I
    keep = ((py[tri].min(1)<N)&(py[tri].max(1)>=0)&(px[tri].min(1)<N)&(px[tri].max(1)>=0))
    for a,b,c in tri[keep]:
        x0,y0,x1,y1,x2,y2 = px[a],py[a],px[b],py[b],px[c],py[c]
        den = (y1-y2)*(x0-x2)+(x2-x1)*(y0-y2)
        if abs(den)<1e-12: continue
        xa,xb = max(int(math.floor(min(x0,x1,x2))),0), min(int(math.ceil(max(x0,x1,x2))),N-1)
        ya,yb = max(int(math.floor(min(y0,y1,y2))),0), min(int(math.ceil(max(y0,y1,y2))),N-1)
        if xb<xa or yb<ya: continue
        gx,gy = np.meshgrid(np.arange(xa,xb+1)+0.5, np.arange(ya,yb+1)+0.5)
        w0 = ((y1-y2)*(gx-x2)+(x2-x1)*(gy-y2))/den; w1 = ((y2-y0)*(gx-x2)+(x0-x2)*(gy-y2))/den; w2 = 1-w0-w1
        m = (w0>=0)&(w1>=0)&(w2>=0)
        if not m.any(): continue
        z = w0*sz[a]+w1*sz[b]+w2*sz[c]
        sub = zb[ya:yb+1,xa:xb+1]; m &= z>sub
        if not m.any(): continue
        sub[m] = z[m]
        u = (w0*UV[a,0]+w1*UV[b,0]+w2*UV[c,0])[m]; v = (w0*UV[a,1]+w1*UV[b,1]+w2*UV[c,1])[m]
        t = tex[np.clip((v%1)*TH,0,TH-1).astype(int), np.clip((u%1)*TW,0,TW-1).astype(int)]
        n = (w0[...,None]*NR[a]+w1[...,None]*NR[b]+w2[...,None]*NR[c])[m]
        n /= np.linalg.norm(n,axis=1,keepdims=True)+1e-12
        lam = np.abs(n@d)          # even, camera-aligned soft light; abs: the material is double sided
        shade = 0.72+0.28*lam
        col[ya:yb+1,xa:xb+1][m] = np.clip(t*shade[:,None],0,1)
    im = Image.fromarray((col*255+0.5).astype(np.uint8)).resize((OUT,OUT),Image.LANCZOS)
    im.save(f'{out}/head_{name}.png', optimize=True); print('wrote', f'head_{name}.png')

# ---- measurements (metres, model space: +Y up, faces +Z, character's left is +X)
P = P[P[:,1] > 1.45]                                   # head and neck only (drops hands and body)
mid = P[(np.abs(P[:,0]-CXZ[0]) < 0.012) & (P[:,2] > 0.07)]
chin = mid[:,1].min()                                  # lowest front midline point = chin (menton)
H = P[P[:,1] >= chin]
print('crown y %.4f  chin y %.4f  height %.4f' % (P[:,1].max(), chin, P[:,1].max()-chin))
print('width incl. ears %.4f (x %.4f..%.4f)' % (np.ptp(H[:,0]), H[:,0].min(), H[:,0].max()))
print('skull width above ears (y>=1.615) %.4f' % np.ptp(P[P[:,1] >= 1.615][:,0]))
print('depth incl. nose %.4f (z %.4f..%.4f)' % (np.ptp(H[:,2]), H[:,2].min(), H[:,2].max()))
print('skull depth above nose (y>=1.60) %.4f' % np.ptp(P[P[:,1] >= 1.60][:,2]))
