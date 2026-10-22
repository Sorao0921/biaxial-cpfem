"""Evaluate initial Taylor activity against state13, with no fitted height law."""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from tqdm.auto import tqdm

from src.config.pipeline_paths import PROJECT_ROOT, OUTPUTS_DIR, SPATIAL_MODELS_DIR, THEME1_DIR
from src.dashboard.catalog import scan_outputs, filter_records
from src.theme1.initial_taylor_prediction import optimal_activity, surface_geometry, grain_response, spearman, add_valley_prediction, measured_activity_response, surface_boundary_weights, add_neighbor_activity, pearson


def build_parser():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--outputs',type=Path,default=OUTPUTS_DIR)
    p.add_argument('--spatial-models',type=Path,default=SPATIAL_MODELS_DIR)
    p.add_argument('--orientations',type=Path,default=PROJECT_ROOT/'inputs/orientation')
    p.add_argument('--output-dir',type=Path,default=THEME1_DIR/'initial_taylor_state13')
    p.add_argument('--rho',type=float)
    p.add_argument('--seed',type=int)
    p.add_argument('--texture')
    p.add_argument('--sd',type=int)
    p.add_argument('--raw-height',action='store_true',help='Use full raw surface instead of preferred edge-dropped region')
    p.add_argument('--height-node-ids',choices=['surface_rows','global'],default='surface_rows')
    p.add_argument('--calculate-measured-az',action='store_true',help='Calculate missing state13 measured Az for diagnosis; reads simulated slip/orientation')
    p.add_argument('--plots',action='store_true',help='Save prediction/response maps and rank scatter per case')
    return p


def plot_case(joined,elements,path):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fields=['relief_from_az_min','relief_from_az_max','height_mean']
    fig,axes=plt.subplots(1,3,figsize=(15,4),layout='constrained')
    field=elements[['part_id','x','y']].merge(joined[['part_id',*fields]],on='part_id',validate='many_to_one')
    for ax,key,title in zip(axes,fields,['Predicted high/low: Az minimum model','Predicted high/low: Az maximum model','State13 signed grain mean height']):
        limit=max(abs(joined[key].min()),abs(joined[key].max()),1e-12)
        limits={'vmin':-limit,'vmax':limit}
        pts=ax.scatter(field.x,field.y,c=field[key],s=3,cmap='coolwarm',**limits)
        ax.set_aspect('equal'); ax.set_title(title);ax.set_xlabel('Initial x');ax.set_ylabel('Initial y')
        fig.colorbar(pts,ax=ax,label='dimensionless activity' if key.startswith('relief') else 'height (coordinate units)')
    fig.savefig(path/'comparison.png',dpi=180);plt.close(fig)
    fig,ax=plt.subplots(figsize=(5,4),layout='constrained')
    ax.scatter(joined.relief_from_az_midpoint.rank(pct=True),joined.height_mean.rank(pct=True),s=12)
    ax.set(xlabel='Predicted high/low percentile rank (-Az midpoint)',ylabel='State13 signed height percentile rank',title='One point per retained surface grain')
    fig.savefig(path/'rank_scatter.png',dpi=180);plt.close(fig)


def main():
    args=build_parser().parse_args()
    records=filter_records(scan_outputs(args.outputs,prefer_raw_height=args.raw_height),kind='height',state=13,
                           rho=args.rho,seed=args.seed,texture=args.texture,sd=args.sd)
    if not records:
        raise SystemExit('No state13 height cases matched.')
    summaries=[];failures=[];geometries={};activity_status=[];completed=0;boundaries={}
    args.output_dir.mkdir(parents=True,exist_ok=True)
    for record in tqdm(records,desc='Initial Taylor -> state13',unit='case'):
        case=f'rho_{record.rho:g}_{record.texture}_sd{record.sd}_seed{record.seed}_state13'
        try:
            if record.seed not in geometries:
                geometries[record.seed]=surface_geometry(args.spatial_models/f'seed{record.seed}')
                boundaries[record.seed]=surface_boundary_weights(geometries[record.seed][0],args.spatial_models/f'seed{record.seed}')
            geometry,top_ids=geometries[record.seed]
            observed,elements=grain_response(record.path,geometry,top_ids,node_ids=args.height_node_ids)
            orientation=args.orientations/f'texture_seed{record.seed}'/f'{record.texture}_sigma{record.sd}_seed{record.seed}.csv'
            angles=np.loadtxt(orientation,delimiter=',',ndmin=2)
            if angles.shape[1]!=3 or not np.isfinite(angles).all():
                raise ValueError('Expected finite initial Euler radians')
            prediction=[];vertices=[]
            for pid in sorted(geometry.part_id.unique()):
                if pid<1 or pid>len(angles):
                    raise ValueError(f'No initial orientation for part {pid}')
                result=optimal_activity(angles[pid-1],record.rho)
                prediction.append({'part_id':pid,**{k:v for k,v in result.items() if k not in ['gamma','vertex_az','projection']}})
                for vertex,(gamma,az) in enumerate(zip(result['gamma'],result['vertex_az'])):
                    vertices.append({'part_id':pid,'vertex':vertex,'az':az,**{f'taylor_gamma_{i+1}':v for i,v in enumerate(gamma)}})
            prediction=add_neighbor_activity(pd.DataFrame(prediction),boundaries[record.seed])
            joined=observed.merge(prediction,on='part_id',validate='one_to_one')
            joined['rz_midpoint']=joined.az_midpoint/joined.m_initial
            joined['az_range']=joined.az_max-joined.az_min
            try:
                measured,status=measured_activity_response(record,elements,args.outputs,calculate=args.calculate_measured_az)
                for column,values in measured.items():
                    joined[column]=joined.part_id.map(values)
                activity_status.append({'case_id':case,**status})
            except (ValueError,OSError,KeyError) as exc:
                activity_status.append({'case_id':case,'measured_error':str(exc)})
            joined=add_valley_prediction(joined)
            out=args.output_dir/case;out.mkdir(parents=True,exist_ok=True)
            joined.to_csv(out/'grain_predictions.csv',index=False)
            pd.DataFrame(vertices).to_csv(out/'optimal_vertices.csv',index=False)
            if args.plots:
                plot_case(joined,elements,out)
            completed+=1
            predictors=['m_initial','az_min','az_max','az_midpoint','rz_midpoint']+[c for c in joined if c.startswith('relief_from_')]+[c for c in ['measured_az_state13','measured_bz_state13'] if c in joined]
            for predictor in predictors:
                for target in ['height_mean','surface_z_mean','height_abs_mean','height_std']:
                    corr=spearman(joined[predictor],joined[target])
                    summaries.append({'case_id':case,'rho':record.rho,'seed':record.seed,'texture':record.texture,
                                      'sd':record.sd,'state':13,'grains':len(joined),'predictor':predictor,'target':target,
                                      'spearman':corr,'pearson':pearson(joined[predictor],joined[target]),'status':'ok' if np.isfinite(corr) else 'undefined_constant_or_too_few',
                                      'height_source':str(record.path),'orientation_source':str(orientation)})
        except (ValueError, OSError, KeyError) as exc:
            failures.append({'case_id':case,'error':str(exc)})
    requested={f'rho_{r.rho:g}_{r.texture}_sd{r.sd}_seed{r.seed}_state13' for r in records}
    summary_path=args.output_dir/'spearman_by_case.csv'
    previous=pd.read_csv(summary_path) if summary_path.exists() else pd.DataFrame()
    if len(previous):
        previous=previous[~previous.case_id.isin(requested)]
    combined=pd.concat([previous,pd.DataFrame(summaries)],ignore_index=True)
    combined.to_csv(summary_path,index=False)
    combined.to_csv(args.output_dir/'correlations_by_case.csv',index=False)
    if len(combined):
        combined[combined.predictor.str.startswith('relief_from_') & combined.target.eq('height_mean')].to_csv(
            args.output_dir/'valley_spearman_by_case.csv',index=False)
    failed_path=args.output_dir/'failed_cases.csv'
    previous_failed=pd.read_csv(failed_path) if failed_path.exists() else pd.DataFrame(columns=['case_id','error'])
    previous_failed=previous_failed[~previous_failed.case_id.isin(requested)]
    pd.concat([previous_failed,pd.DataFrame(failures,columns=['case_id','error'])],ignore_index=True).to_csv(failed_path,index=False)
    diagnostics={'state':13,'cases_requested':len(records),'cases_completed':completed,'failures':failures,
                 'prediction':'Fixed hypothesis: high activity -> valley. relief = -(Az - retained-area weighted mean); predicts high/low ordering, not height amplitude',
                 'solutions':'All distinct optimal basic vertices within relative tolerance 1e-9; continuum summarized by exact vertex activity extrema',
                 'midpoint':'Midpoint of activity extrema, fixed before observing height; NOT bounds on Spearman correlation',
                 'response':'Reference-area-weighted top-face corner moments after detrending selected state13 nodes',
                 'height_node_ids':args.height_node_ids,'significance':'No iid p-values: grains share spatial constraints',
                 'gamma_order':'Internal Taylor order; not UMAT numbering','plots':args.plots,'measured_activity_status':activity_status,'neighbor_model':'-(Az_g - boundary-length weighted neighboring Az); full initial surface neighbors, including cropped-out grains','primary_target':'Signed grain mean plane residual height_mean','secondary_target':'Raw grain mean surface_z_mean'}
    (args.output_dir/'diagnostics.json').write_text(json.dumps(diagnostics,ensure_ascii=False,indent=2)+'\n')
    print(f"Completed {diagnostics['cases_completed']}/{len(records)} cases: {args.output_dir}")
    return 1 if failures else 0


if __name__=='__main__':
    raise SystemExit(main())
