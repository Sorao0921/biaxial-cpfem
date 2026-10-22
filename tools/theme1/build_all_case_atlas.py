"""Render the completed initial-K batch with fixed raw-height comparison rules.

Run using the project Python after predict_neighbor_height. PDF assembly uses
build_all_case_pdf.py with the bundled document runtime.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.tri as mtri
from matplotlib.collections import LineCollection
import numpy as np
import pandas as pd
from tqdm import tqdm

from src.config.pipeline_paths import PROJECT_ROOT,OUTPUTS_DIR,build_spatial_model_dir
from src.dashboard.catalog import scan_outputs,filter_records
from src.dashboard.plots import surface_topology
from src.theme1.contribution import _read_height


def plot_pair(predicted,actual,model,output,title,subtitle):
    _,_,faces,boundaries,_=surface_topology(model)
    limits=np.quantile(np.r_[predicted.z,actual.z]*1000,[.02,.98])
    if limits[0]==limits[1]:limits+=np.array([-1,1])*1.e-9
    fig,axes=plt.subplots(1,2,figsize=(11,3.7),layout='constrained')
    fig.suptitle(title+'\n'+subtitle,fontsize=10)
    for ax,frame,name in zip(axes,[predicted,actual],['Prediction - initial K + neighbors','Simulation - state13']):
        lookup={int(n):i for i,n in enumerate(frame.node_id)}
        triangles=[]
        for face in faces:
            if all(int(n) in lookup for n in face):
                indices=[lookup[int(n)] for n in face]
                triangles.extend((indices[0],indices[k],indices[k+1]) for k in range(1,len(indices)-1))
        if not triangles:raise ValueError('No complete surface faces')
        mesh=mtri.Triangulation(frame.x,frame.y,np.array(triangles))
        contour=ax.tricontourf(mesh,frame.z.to_numpy()*1000,levels=np.linspace(*limits,31),cmap='coolwarm',extend='both')
        xy=frame[['x','y']].to_numpy()
        segments=[xy[[lookup[a],lookup[b]]] for a,b in boundaries if a in lookup and b in lookup]
        ax.add_collection(LineCollection(segments,colors='black',linewidths=.22,alpha=.65))
        ax.set(xlabel='x',ylabel='y',title=name,aspect='equal');ax.margins(0)
        ax.tick_params(labelsize=8);ax.title.set_fontsize(10)
        bar=fig.colorbar(contour,ax=ax,format='%.3f',shrink=.95)
        bar.ax.tick_params(labelsize=8);bar.set_label(r'Surface height z ($\times 10^{-3}$)',fontsize=9)
    fig.savefig(output,dpi=160,facecolor='white');plt.close(fig)
    return tuple(map(float,limits))


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,default=Path('output/pdf/all_cases_20261015'))
    args=parser.parse_args();root=args.root.resolve();data=root/'data'
    evaluation=pd.read_csv(data/'evaluation.csv').sort_values(['rho','seed','texture','sd'])
    expected=filter_records(scan_outputs(OUTPUTS_DIR),kind='height',state=13)
    assert len(evaluation)==len(expected)==240, 'Scope mismatch; inspect catalog before changing expected scope'
    assert not evaluation.case_id.duplicated().any()
    assert set(evaluation.source)=={'k'}
    failures=pd.read_csv(data/'failed_cases.csv');assert len(failures)==0
    maps=root/'individual_maps';maps.mkdir(exist_ok=True)
    inputs=root/'initial_inputs';inputs.mkdir(exist_ok=True)
    rows=[];manifest=[]
    for record in tqdm(list(evaluation.itertuples(index=False)),desc='Comparison maps'):
        directory=Path(record.directory);meta=json.loads((directory/'model.json').read_text())
        assert meta['feature_weights']=={'k':1.} and meta['fit_to_simulation'] is False
        assert meta['stress_ratio_mode']=='initial_volume_mean_strain_match'
        assert abs(meta['stress_model_mean_strain_ratio']-record.rho)<1.e-7
        for key,value in [('m',.05),('coupling',1.),('inplane_weight',.5),('prescribed_strain',.1)]:assert meta[key]==value
        assert meta['low_k_resistance'] is True and meta['standardize_initial_inputs'] is False
        pair=pd.read_csv(directory/'height_comparison.csv')
        predicted=pd.read_csv(directory/'evaluation_predicted_coordinates.csv')
        actual=_read_height(Path(record.height_source))
        assert np.array_equal(predicted.node_id,actual.node_id)
        np.testing.assert_allclose(pair.z_predicted,predicted.z)
        np.testing.assert_allclose(pair.z_actual,actual.z)
        error=predicted.z.to_numpy()-actual.z.to_numpy()
        rmse=float(np.sqrt(np.mean(error**2)));bias=float(np.mean(error))
        predstd=float(np.std(predicted.z));actualstd=float(np.std(actual.z))
        corr=float(np.corrcoef(predicted.z,actual.z)[0,1]) if predstd>1.e-15 and actualstd>1.e-15 else np.nan
        np.testing.assert_allclose(rmse,record.raw_height_rmse,atol=1.e-14)
        np.testing.assert_allclose(corr,record.nodal_pearson,atol=1.e-10,equal_nan=True)
        image=maps/f'{record.case_id}.png'
        title=f'{record.texture.capitalize()} | rho={record.rho:g} | seed={record.seed} | sd={record.sd} | state13'
        subtitle=f'Pearson r={corr:.3f}   RMSE={rmse:.3g}   bias={bias:.3g}   std(pred/actual)={predstd/actualstd:.3f}   beta={record.beta:.5f}'
        limits=plot_pair(predicted,actual,build_spatial_model_dir(record.seed),image,title,subtitle)
        # Actual coordinates are archived only after the initial-only prediction exists.
        actual.to_csv(directory/'actual_coordinates_state13.csv',index=False)
        orientation=Path(meta['orientation_source']);relative=orientation.relative_to(PROJECT_ROOT)
        target=inputs/relative;target.parent.mkdir(parents=True,exist_ok=True)
        if not target.exists():shutil.copy2(orientation,target)
        for filename in ['nodes.csv','elements.csv']:
            source=build_spatial_model_dir(record.seed)/filename
            target=inputs/'spatial_model'/f'seed{record.seed}'/filename
            target.parent.mkdir(parents=True,exist_ok=True)
            if not target.exists():shutil.copy2(source,target)
        rows.append(dict(case_id=record.case_id,texture=record.texture,rho=record.rho,seed=record.seed,sd=record.sd,state=13,
            nodes=len(pair),beta=record.beta,m=record.m,mean_strain_ratio=meta['stress_model_mean_strain_ratio'],
            nodal_pearson=corr,raw_height_rmse=rmse,mean_height_bias=bias,
            centered_height_rmse=float(np.sqrt(np.mean((error-bias)**2))),
            predicted_height_std=predstd,actual_height_std=actualstd,std_ratio=predstd/actualstd,
            display_low_x1e3=limits[0],display_high_x1e3=limits[1],
            map_file=str(image.relative_to(root)),data_directory=str(directory.relative_to(root)),config_id=record.config_id))
        manifest.append(dict(case_id=record.case_id,actual_source=str(Path(record.height_source).relative_to(PROJECT_ROOT)),
            actual_sha256=hashlib.sha256(Path(record.height_source).read_bytes()).hexdigest(),
            orientation_source=str(relative),orientation_sha256=hashlib.sha256(orientation.read_bytes()).hexdigest()))
    metrics=pd.DataFrame(rows);metrics.to_csv(root/'accuracy_all_cases.csv',index=False,encoding='utf-8-sig')
    group=metrics.groupby(['rho','texture'],as_index=False).agg(cases=('case_id','size'),pearson_median=('nodal_pearson','median'),
        pearson_min=('nodal_pearson','min'),pearson_max=('nodal_pearson','max'),rmse_median=('raw_height_rmse','median'),std_ratio_median=('std_ratio','median'))
    group.to_csv(root/'accuracy_by_texture_rho.csv',index=False,encoding='utf-8-sig')
    pd.DataFrame(manifest).to_csv(root/'source_manifest.csv',index=False,encoding='utf-8-sig')
    (root/'conditions.json').write_text(json.dumps(dict(source='k',m=.05,prescribed_equivalent_log_strain=.1,coupling=1.,inplane_weight=.5,
        low_k_resistance=True,standardize=False,beta='matched to initial volume-mean D_TD/D_RD = prescribed rho',state=13,
        color_rule='pooled predicted/actual nodal z, 2-98 percentiles within each case; no value clipping in metrics',
        scope_count=len(metrics),catalog='all currently available state13 height cases',date='2026-10-15'),indent=2)+'\n')
    snapshot=root/'reproduce';snapshot.mkdir(exist_ok=True)
    for folder in ['src','tools/theme1','docs']:
        for source in (PROJECT_ROOT/folder).rglob('*'):
            if source.is_file() and source.suffix in ('.py','.md'):
                target=snapshot/source.relative_to(PROJECT_ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    for filename in ['pyproject.toml','requirements.txt']:
        if (PROJECT_ROOT/filename).exists():shutil.copy2(PROJECT_ROOT/filename,snapshot/filename)
    print(group.to_string(index=False))
    print('Validated and rendered',len(metrics),'cases')


if __name__=='__main__':main()
