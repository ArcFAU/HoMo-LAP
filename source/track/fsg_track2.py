import scipy.io as sio, numpy as np, json
import os
HERE = os.path.dirname(os.path.abspath(__file__))
VD = r'D:\VD'   # HoMo-LTS / vehicle-dynamics repo
A=sio.loadmat(os.path.join(VD, 'laptimesimulation', 'data', 'tracks', 'A_FSGend_3.mat'))['A']
s=A[:,0]-A[0,0]; k=A[:,1]
ds=0.5; Ltot=1103.4082136873235; N=int(round(Ltot/ds)); ds=Ltot/N
su=np.arange(N)*ds; ku=np.interp(su,s,k)
def circ_smooth(x,w):
    n=int(w/ds)|1; ker=np.ones(n)/n; xp=np.concatenate([x[-n:],x,x[:n]]); return np.convolve(xp,ker,'same')[n:-n]
ks=circ_smooth(ku,3.0)
def integ(kk):
    th=np.concatenate([[0],np.cumsum(kk*ds)])          # N+1 headings
    thm=th[:-1]+kk*ds/2
    x=np.concatenate([[0],np.cumsum(np.cos(thm)*ds)]); y=np.concatenate([[0],np.cumsum(np.sin(thm)*ds)])
    return x,y,th   # N+1 points, last is end
kk=ks.copy()
for it in range(8):
    x,y,th=integ(kk)
    target=2*np.pi*round(th[-1]/(2*np.pi))
    r=np.array([th[-1]-target, x[-1]-x[0], y[-1]-y[0]])
    xs,ys=x[:-1],y[:-1]
    J=np.vstack([np.ones(N)*ds, -(y[-1]-ys)*ds, (x[-1]-xs)*ds])
    lam=np.linalg.solve(J@J.T, -r)
    kk=kk+J.T@lam
    print(it, r)
x,y,th=integ(kk); x=x[:-1]; y=y[:-1]
print('max |dk|', np.abs(kk-ks).max(), 'rms', np.sqrt(np.mean((kk-ks)**2)))
P=np.c_[x,y]; best=1e9;pair=None
idx=np.arange(N)
for i in range(0,N,2):
    d=np.hypot(P[:,0]-P[i,0],P[:,1]-P[i,1]); gap=np.minimum(abs(idx-i),N-abs(idx-i))*ds
    d[gap<25]=1e9; j=d.argmin()
    if d[j]<best: best=d[j];pair=(i*ds,j*ds)
print('min separation',best,pair,'minR',1/np.abs(kk).max())
print('bbox',x.min(),x.max(),y.min(),y.max())
np.savez(os.path.join(HERE, 'fsg.npz'),x=x,y=y,k=kk,ds=ds)
import PIL.Image as Im, PIL.ImageDraw as D
sc=4; W=int((x.max()-x.min())*sc)+80; H=int((y.max()-y.min())*sc)+80
im=Im.new('RGB',(W,H),'#333'); dr=D.Draw(im)
pts=[((xx-x.min())*sc+40,(y.max()-yy)*sc+40) for xx,yy in zip(x,y)]
dr.line(pts+[pts[0]],fill='#aaa',width=int(4.5*sc)); dr.ellipse([pts[0][0]-5,pts[0][1]-5,pts[0][0]+5,pts[0][1]+5],fill='red')
q=pts[40]; dr.ellipse([q[0]-4,q[1]-4,q[0]+4,q[1]+4],fill='yellow')
im.save(os.path.join(HERE, 'fsg.png'))
