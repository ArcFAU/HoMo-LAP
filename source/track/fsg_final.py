import numpy as np, json
import os
HERE = os.path.dirname(os.path.abspath(__file__))
VD = r'D:\VD'   # HoMo-LTS / vehicle-dynamics repo
d=np.load(os.path.join(HERE, 'fsg.npz')); x=d['x'].copy(); y=d['y'].copy(); ds=float(d['ds']); N=len(x); idx=np.arange(N)
s=idx*ds
# local push of the end section away from the start straight around the pinch
start_sel=(s>0)&(s<110)
win=(s>990)&(s<1090)
w=np.zeros(N); w[win]=0.5*(1-np.cos(2*np.pi*(s[win]-990)/100))  # Hann, peak at 1040
A=2.4
nx=np.zeros(N); ny=np.zeros(N)
for i in np.where(win)[0]:
    j=np.where(start_sel)[0][np.argmin(np.hypot(x[start_sel]-x[i],y[start_sel]-y[i]))]
    dd=np.hypot(x[i]-x[j],y[i]-y[j]); nx[i]=(x[i]-x[j])/dd; ny[i]=(y[i]-y[j])/dd
x=x+A*w*nx; y=y+A*w*ny
# resample to uniform 1 m along the new polyline
seg=np.hypot(np.diff(np.r_[x,x[0]]),np.diff(np.r_[y,y[0]])); cum=np.r_[0,np.cumsum(seg)]; L=cum[-1]
M=int(round(L)); su=np.linspace(0,L,M,endpoint=False)
xx=np.interp(su,cum,np.r_[x,x[0]]); yy=np.interp(su,cum,np.r_[y,y[0]])
def curv(x,y,h=3):
    xm,ym=np.roll(x,h),np.roll(y,h); xp,yp=np.roll(x,-h),np.roll(y,-h)
    a=np.hypot(x-xm,y-ym);b=np.hypot(xp-x,yp-y);c=np.hypot(xp-xm,yp-ym)
    return 2*((x-xm)*(yp-ym)-(y-ym)*(xp-xm))/(a*b*c)
k=curv(xx,yy)
# separation
best=1e9
for i in range(M):
    dd=np.hypot(xx-xx[i],yy-yy[i]); g=np.minimum(abs(np.arange(M)-i),M-abs(np.arange(M)-i)); dd[g<30]=1e9
    best=min(best,dd.min())
print('L',L,'M',M,'minR',1/np.abs(k).max(),'min sep',best)
# to screen coords: y down, origin at bbox min - margin
gx=xx-xx.min()+40; gy=-(yy)-(-yy).min()+40
lap=json.load(open(os.path.join(VD, 'laptimesimulation', 'results', 'viewerSamples', 'singleTrack_endurance.json')))
lp=lap['lap']; ls=np.array(lp['distance_m']); lt=np.array(lp['time_s']); lv=np.array(lp['speed_mps'])
Llts=lap['track']['length_m']; Tl=lap['summary']['lapTime_s']
grid=np.arange(0,Llts,2.0); tg=np.interp(grid,ls,lt); vg=np.interp(grid,ls,lv)
# sector times for thirds of distance
sec=[float(np.interp(Llts*f,ls,lt)) for f in (1/3,2/3)]
out={'x':[round(v,2) for v in gx],'y':[round(v,2) for v in gy],
     'lts':{'s':[round(v,1) for v in grid],'t':[round(v,3) for v in tg],'v':[round(v,2) for v in vg],
            'length':round(Llts,2),'lapTime':round(Tl,3),'splits':[round(v,3) for v in sec],
            'model':lap['model'],'vehicle':lap['vehicleName'],'created':lap['created'],'vmax':lap['summary']['maximumSpeed_mps']}}
json.dump(out,open(os.path.join(HERE, '..', 'fsg_track.json'),'w'),separators=(',',':'))
print('splits',sec,'lap',Tl, 'json bytes', len(json.dumps(out,separators=(',',':'))))
import PIL.Image as Im, PIL.ImageDraw as D
sc=4; W=int(gx.max()*sc)+160; H=int(gy.max()*sc)+160
im=Im.new('RGB',(W,H),'#333'); dr=D.Draw(im)
pts=[(a*sc,b*sc) for a,b in zip(gx,gy)]
dr.line(pts+[pts[0]],fill='#aaa',width=int(4*sc)); dr.ellipse([pts[0][0]-5,pts[0][1]-5,pts[0][0]+5,pts[0][1]+5],fill='red')
dr.ellipse([pts[20][0]-4,pts[20][1]-4,pts[20][0]+4,pts[20][1]+4],fill='yellow')
im.save(os.path.join(HERE, 'fsg3.png'))
