#!/usr/bin/env python3
# Offline check of the ground-sit pose (BUG-020): forward kinematics of Dynasty_Base_Male.glb, frame 0 of Chair_Sit_Idle_M, with the same
# changes as dynasty_body.gd _ground_sit, printing joint positions in metres (model faces +Z, left is +X, y up, hips at the origin in x/z).
#   python3 tools/sit_pose_sim.py [thigh_deg fold_deg pelvis_back_deg]   (no Godot needed; numpy only)
import json,struct,numpy as np,sys
f=open(__import__('os').path.join(__import__('os').path.dirname(__file__), '..', 'assets', 'character', 'Humanoid', 'Dynasty_Base_Male.glb'), 'rb').read()
ln=struct.unpack('<I',f[12:16])[0]; js=json.loads(f[20:20+ln]); binoff=20+ln+8
def acc(i):
    a=js['accessors'][i]; bv=js['bufferViews'][a['bufferView']]
    n={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]
    o=binoff+bv.get('byteOffset',0)+a.get('byteOffset',0)
    return np.frombuffer(f[o:o+4*n*a['count']],dtype='<f4').reshape(a['count'],n) if n>1 else np.frombuffer(f[o:o+4*a['count']],dtype='<f4')
nodes=js['nodes']; names=[n.get('name','') for n in nodes]
parent={c:i for i,n in enumerate(nodes) for c in n.get('children',[])}
def qmul(a,b):
    x1,y1,z1,w1=a; x2,y2,z2,w2=b
    return np.array([w1*x2+x1*w2+y1*z2-z1*y2, w1*y2-x1*z2+y1*w2+z1*x2, w1*z2+x1*y2-y1*x2+z1*w2, w1*w2-x1*x2-y1*y2-z1*z2])
def qrot(q,v):
    u=q[:3]; w=q[3]; return 2*np.dot(u,v)*u+(w*w-np.dot(u,u))*v+2*w*np.cross(u,v)
def qaxis(ax,deg):
    ax=np.array(ax,float); r=np.radians(deg)/2; return np.array([*(ax*np.sin(r)),np.cos(r)])
def pose(animname,t=0.0):
    an=[a for a in js['animations'] if a['name']==animname][0]
    P={}
    for ch in an['channels']:
        s=an['samplers'][ch['sampler']]; times=acc(s['input']); vals=acc(s['output'])
        k=0
        P[(ch['target']['node'],ch['target']['path'])]=vals[k]
    return P
def local(i,P):
    n=nodes[i]
    t=np.array(P.get((i,'translation'),n.get('translation',[0,0,0])),float)
    r=np.array(P.get((i,'rotation'),n.get('rotation',[0,0,0,1])),float)
    s=np.array(n.get('scale',[1,1,1]),float)
    return t,r,s
def glob(i,P):
    chain=[]
    j=i
    while j is not None:
        chain.append(j); j=parent.get(j)
    pos=np.zeros(3); rot=np.array([0,0,0,1.]); sc=np.ones(3)
    for j in reversed(chain):
        t,r,s=local(j,P)
        pos=pos+qrot(rot,t*sc); rot=qmul(rot,r); sc=sc*s
    return pos,rot
idx={n:i for i,n in enumerate(names)}
def sit(thigh=55,fold=135,pelvisd=28,spine=3,hipy=14.0,mode='orig'):
    P=dict(pose('Chair_Sit_Idle_M'))
    h=idx['mixamorig:Hips']
    t=np.array(P[(h,'translation')],float); P[(h,'translation')]=np.array([0,hipy,0.])
    pel=qaxis([1,0,0],-pelvisd)
    P[(h,'rotation')]=qmul(np.array(P[(h,'rotation')]),pel)
    for b in ['Spine','Spine1','Spine2']:
        i=idx['mixamorig:'+b]; P[(i,'rotation')]=qmul(np.array(P[(i,'rotation')]),qaxis([1,0,0],-spine))
    for side in ['Left','Right']:
        u=idx['mixamorig:'+side+'UpLeg']; l=idx['mixamorig:'+side+'Leg']
        right= side=='Right'
        ex=qaxis([0,1,0],-thigh if right else thigh)
        P[(u,'rotation')]=qmul(qmul(np.array([-pel[0],-pel[1],-pel[2],pel[3]]),ex),np.array(P[(u,'rotation')]))
        P[(l,'rotation')]=qmul(np.array(P[(l,'rotation')]),qaxis([1,0,0],fold))
    return P
def show(P,label):
    print(label)
    for b in ['Hips','LeftUpLeg','LeftLeg','LeftFoot','LeftToeBase','RightUpLeg','RightLeg','RightFoot','Head']:
        if 'mixamorig:'+b in idx:
            p,_=glob(idx['mixamorig:'+b],P); print('  %-11s'%b,np.round(p,2))



# --ik: the 5 Nov aim (dynasty_body.gd _sit_aim): thighs forward and out, shins crossed, spine 8 degrees forward, hands on the knees by two-bone IK.
def qinv(q): return np.array([-q[0],-q[1],-q[2],q[3]])
def arc(a,b):
    a=a/np.linalg.norm(a); b=b/np.linalg.norm(b); c=np.cross(a,b); d=np.dot(a,b)
    q=np.array([*c,1+d]); return q/np.linalg.norm(q)
def unit(v): return v/np.linalg.norm(v)
def _b(n): return idx['mixamorig:'+n]
def _rot(P,n): return np.array(P[(_b(n),'rotation')],float)
def _off(P,n):
    k=(_b(n),'translation'); return np.array(P[k] if k in P else nodes[_b(n)]['translation'],float)*0.01
def _chain(P,chain):
    q=np.array([0,0,0,1.])
    for n in chain: q=qmul(q,_rot(P,n))
    return q
def _pos(P,n): return glob(_b(n),P)[0]
def aim(P,chain,child,target_dir):
    bone=chain[-1]; par=_chain(P,chain[:-1]); g=qmul(par,_rot(P,bone)); d=qrot(g,_off(P,child))
    P[(_b(bone),'rotation')]=qmul(qinv(par),qmul(arc(d,target_dir),g))
def two_bone(P,chain,lower,end,target,pole):
    a=_pos(P,chain[-1]); L1=np.linalg.norm(_off(P,lower)); L2=np.linalg.norm(_off(P,end))
    t=target-a; dist=min(np.linalg.norm(t),L1+L2-1e-4); tn=unit(t)
    ang=np.arccos(np.clip((L1*L1+dist*dist-L2*L2)/(2*L1*dist),-1,1))
    side=unit(pole-np.dot(pole,tn)*tn); elbow_dir=tn*np.cos(ang)+side*np.sin(ang)
    aim(P,chain,lower,elbow_dir); elbow=a+elbow_dir*L1
    aim(P,chain+[lower],end,unit(a+tn*dist-elbow))
def sit_ik(lean=8.0):
    P=sit(85,85,3)
    for b in ['Spine','Spine1','Spine2']:
        P[(_b(b),'rotation')]=qmul(_rot(P,b),qaxis([1,0,0],lean/3))
    for s,side in [(1,'Left'),(-1,'Right')]:
        aim(P,['Hips',side+'UpLeg'],side+'Leg',unit(np.array([s*0.62,0.0,0.78])))
        aim(P,['Hips',side+'UpLeg',side+'Leg'],side+'Foot',unit(np.array([-s*0.95,-0.04,-0.08 if s>0 else 0.12])))
    for s,side in [(1,'Left'),(-1,'Right')]:
        knee=_pos(P,side+'Leg')
        two_bone(P,['Hips','Spine','Spine1','Spine2',side+'Shoulder',side+'Arm'],side+'ForeArm',side+'Hand',knee+np.array([-s*0.03,0.06,-0.03]),np.array([s*1.0,0,-0.6]))
    return P


if __name__ == "__main__":
    if "--ik" in sys.argv:
        P = sit_ik()
        show(P, "ik (dynasty_body.gd _sit_aim)")
        for b in ['LeftHand', 'RightHand']:
            print('  %-11s' % b, np.round(_pos(P, b), 2))
        sys.exit(0)
    a = [float(x) for x in sys.argv[1:4]]
    thigh, fold, pelvis_back = a if len(a) == 3 else (85.0, 85.0, 3.0)   # arms are not modelled here: render with tools/body_pose_shot.gd
    show(sit(thigh=thigh, fold=fold, pelvisd=pelvis_back), "thigh %g, fold %g, pelvis back %g" % (thigh, fold, pelvis_back))
