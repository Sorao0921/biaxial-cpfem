import os
os.environ['MPLBACKEND']='Agg';os.environ['MPLCONFIGDIR']='/tmp/codex_dq_mpl'
import sys,pickle,json
from pathlib import Path
sys.path.insert(0,str(Path.cwd()))
import numpy as np,pandas as pd
import matplotlib.pyplot as plt
import matplotlib.tri as mtri
from matplotlib.collections import LineCollection,PolyCollection
from matplotlib.lines import Line2D
from matplotlib.patches import Patch
from src.theme1.valley_evaluation import _surface
ROOT=Path('tmp/pdfs/dq_examples');OUT=Path('output/pdf/dq_examples_state02');(OUT/'maps').mkdir(exist_ok=True)
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.titlesize':13,'axes.labelsize':10,'savefig.facecolor':'white'})

def plot(row,preview=False):
    d=pickle.loads((ROOT/(row['case']+'.pkl')).read_bytes());f=row['feature'];hist=d[f]
    top,geom,faces=_surface(d['model_dir'])
    ref=d['reference'];pred=hist['prediction'];ids=ref.node_id.to_numpy(int)
    lookup={v:i for i,v in enumerate(ids)};xy=top.iloc[ids-1][['x','y']].to_numpy()
    keep=np.isin(faces,ids).all(axis=1);fs=faces[keep];pids=geom.loc[keep,'part_id'].to_numpy(int)
    ind=np.array([[lookup[v] for v in face] for face in fs]);polys=xy[ind]
    triangles=np.concatenate([ind[:,[0,1,2]],ind[:,[0,2,3]]]);tri=mtri.Triangulation(*xy.T,triangles)
    edges={}
    for face,pid in zip(fs,pids):
        for a,b in zip(face,np.roll(face,-1)):
            edges.setdefault(tuple(sorted((a,b))),[]).append(pid)
    boundaries=np.array([xy[[lookup[a],lookup[b]]] for (a,b),owners in edges.items() if len(owners)==1 or len(set(owners))>1])
    fig,axes=plt.subplots(1,3,figsize=(15.6,5.15),gridspec_kw={'width_ratios':[1,1,1]},layout='constrained')
    for ax,frame,title in zip(axes[:2],[pred,ref],['D + Q prediction','CPFEM reference | state02']):
        z=frame.set_index('node_id').loc[ids,'z'].to_numpy()*1000
        low,high=np.quantile(z,[.02,.98]); levels=np.linspace(low,high,31)
        pc=ax.tricontourf(tri,z,levels=levels,cmap='coolwarm',extend='both')
        cb=fig.colorbar(pc,ax=ax,shrink=.88,pad=.015,fraction=.045)
        cb.set_label(r'Surface height $z$ ($\times 10^{-3}$)',fontsize=9);cb.ax.tick_params(labelsize=8)
        ax.set_title(title+'\nIndependent 2-98% color range')
    candidates=set(hist['flags'].loc[hist['flags'].predicted_feature,'item_id'].astype(int))
    mask=np.isin(pids,list(candidates));fill='#b8d4ea' if f=='valley' else '#f3c7ac'
    axes[2].add_collection(PolyCollection(polys,facecolors=np.where(mask[:,None],np.array([plt.matplotlib.colors.to_rgba(fill)]),np.array([plt.matplotlib.colors.to_rgba('#f4f4f4')])).reshape(-1,4),edgecolors='none',rasterized=True))
    axes[2].set_title('Predicted '+('valley' if f=='valley' else 'peak')+' regions\nCPFEM initiation sites overlaid')
    origins=hist['origins']; marker='*' if f=='valley' else '^'
    for captured in (True,False):
        points=origins[origins.captured.eq(captured)]
        for ax in axes[1:]:
            ax.scatter(points.material_x,points.material_y,s=30 if captured else 27,
                marker=marker if captured else 'x',c='#006d4f' if captured else '#b30076',
                linewidths=.65 if captured else 1.05,edgecolors='white' if captured else None,zorder=8)
    for ax in axes:
        ax.add_collection(LineCollection(boundaries,colors='#333333',linewidths=.32,alpha=.7,zorder=5))
        ax.set(xlim=(xy[:,0].min(),xy[:,0].max()),ylim=(xy[:,1].min(),xy[:,1].max()),xlabel='Initial x',ylabel='Initial y');ax.set_aspect('equal')
    fig.legend(handles=[Patch(facecolor=fill,edgecolor='#777777',label='Predicted '+f+' region'),
        Line2D([],[],color='#006d4f',marker=marker,linestyle='None',markersize=9,label='Captured CPFEM origin'),
        Line2D([],[],color='#b30076',marker='x',linestyle='None',markersize=7,label='Missed CPFEM origin')],
        loc='outside lower center',ncol=3,frameon=False,fontsize=10)
    name=('preview' if preview else row['example_id'])+'_'+f+'_'+row['case']+'.png'
    fig.savefig(OUT/'maps'/name,dpi=190);plt.close(fig)
    prominence=origins.nlargest(min(10,len(origins)),'prominence')
    row.update(map_file='maps/'+name,top10_count=len(prominence),top10_captured=int(prominence.captured.sum()),
        top10_rate=float(prominence.captured.mean()),missed=int((~origins.captured).sum()))
    return row

if __name__=='__main__':
    if '--preview' in sys.argv:
        d=pickle.loads(next(ROOT.glob('*.pkl')).read_bytes());plot(d['rows'][0],True)
    else:
        selected=pd.read_csv(OUT/'selected_cases.csv').to_dict('records')
        rows=[]
        for r in selected:
            rows.append(plot(r));print(r['example_id'],r['case'],flush=True)
        pd.DataFrame(rows).to_csv(OUT/'selected_cases.csv',index=False)
