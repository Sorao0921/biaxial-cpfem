"""Compute state13 hypothesis heights from INITIAL inputs; evaluate afterward."""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from tqdm.auto import tqdm
from src.config.pipeline_paths import PROJECT_ROOT, OUTPUTS_DIR, SPATIAL_MODELS_DIR, THEME1_DIR
from src.dashboard.catalog import scan_outputs,filter_records
from src.theme1.initial_taylor_prediction import (
    optimal_activity,surface_geometry,surface_boundary_weights,grain_response,pearson,spearman)
from src.theme1.initial_height import predict_grain_height,reconstruct_nodes,normalized_height_coordinates


def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--outputs',type=Path,default=OUTPUTS_DIR)
    p.add_argument('--orientations',type=Path,default=PROJECT_ROOT/'inputs/orientation')
    p.add_argument('--spatial-models',type=Path,default=SPATIAL_MODELS_DIR)
    p.add_argument('--output-dir',type=Path,default=THEME1_DIR/'initial_height_state13')
    p.add_argument('--strain',type=float,default=.1,help='PRESCRIBED equivalent logarithmic strain; not read from simulated results')
    p.add_argument('--az-scale',type=float,default=1.)
    p.add_argument('--slope-scale',type=float,default=1.,help='Prescribed signed M-contrast slope strength (not fitted)')
    p.add_argument('--coupling',type=float,default=1.)
    p.add_argument('--rho',type=float);p.add_argument('--seed',type=int)
    p.add_argument('--texture');p.add_argument('--sd',type=int)
    p.add_argument('--activity',choices=['az','pplus','pminus'],default='az')
    args=p.parse_args(argv)
    if args.activity!='az':
        args.output_dir=args.output_dir/args.activity
    records=filter_records(scan_outputs(args.outputs),kind='height',state=13,rho=args.rho,seed=args.seed,texture=args.texture,sd=args.sd)
    if not records: raise SystemExit('No matching state13 evaluation cases')
    args.output_dir.mkdir(parents=True,exist_ok=True)
    geometry_cache={};rows=[];failures=[]
    for r in tqdm(records,desc='Initial-only surface height',unit='case'):
        case=f'rho_{r.rho:g}_{r.texture}_sd{r.sd}_seed{r.seed}_state13'
        try:
            if r.seed not in geometry_cache:
                model=args.spatial_models/f'seed{r.seed}'
                geometry,top_ids=surface_geometry(model)
                nodes=pd.read_csv(model/'nodes.csv')
                top=nodes[np.isclose(nodes.z,nodes.z.max())].sort_values('node_id')
                edges=surface_boundary_weights(geometry,model)
                weighted=geometry.assign(wx=geometry.x*geometry.area,wy=geometry.y*geometry.area)
                properties=weighted.groupby('part_id').agg(initial_area=('area','sum'),wx=('wx','sum'),wy=('wy','sum')).reset_index()
                properties['center_x']=properties.wx/properties.initial_area
                properties['center_y']=properties.wy/properties.initial_area
                properties=properties.drop(columns=['wx','wy'])
                geometry_cache[r.seed]=(geometry,top_ids,nodes,top,edges,properties)
            geometry,top_ids,nodes,top,edges,properties=geometry_cache[r.seed]
            angles_path=args.orientations/f'texture_seed{r.seed}'/f'{r.texture}_sigma{r.sd}_seed{r.seed}.csv'
            angles=np.loadtxt(angles_path,delimiter=',',ndmin=2)
            initial=[]
            for pid in properties.part_id:
                if pid<1 or pid>len(angles): raise ValueError('Initial part orientation missing')
                t=optimal_activity(angles[int(pid)-1],r.rho)
                initial.append({'part_id':pid,'m_initial':t['m_initial'],'az_midpoint':t['az_midpoint'],
                                'az_min':t['az_min'],'az_max':t['az_max'],
                                **{key:t[key] for key in ('pplus_min','pplus_max','pplus_midpoint','pminus_min','pminus_max','pminus_midpoint')}})
            initial=properties.merge(pd.DataFrame(initial),on='part_id',validate='one_to_one')
            # Prediction is complete BEFORE any simulation height is read.
            prediction,edge_prediction=predict_grain_height(initial,edges,thickness=nodes.z.max()-nodes.z.min(),
                strain=args.strain,rho=r.rho,az_scale=args.az_scale,slope_scale=args.slope_scale,coupling=args.coupling,activity=args.activity)
            predicted_nodes=reconstruct_nodes(prediction,geometry,top,bottom_z=nodes.z.min(),strain=args.strain,rho=r.rho)
            out=args.output_dir/case;out.mkdir(parents=True,exist_ok=True)
            prediction.to_csv(out/'initial_grain_height.csv',index=False)
            edge_prediction.to_csv(out/'initial_edge_slopes.csv',index=False)
            predicted_nodes.to_csv(out/'predicted_coordinates.csv',index=False)
            metadata={'activity':args.activity,'activity_sign':1 if args.activity=='pplus' else -1,'state':13,'rho':r.rho,'seed':r.seed,'texture':r.texture,'sd':r.sd,
                      'height_source':str(r.path.resolve()),'orientation_source':str(angles_path.resolve()),
                      'prescribed_strain':args.strain,'az_scale':args.az_scale,'slope_scale':args.slope_scale,'coupling':args.coupling,
                      'model':'Teacher-free graph slope closure v2; not mechanical equilibrium',
                      'assumptions':['Az / Pminus high -> valley; Pplus high -> hill; scale H0*prescribed strain',
                                     'Preferred boundary slope = prescribed strain * slope_scale * (Mi-Mj)/meanM; height difference = centroid distance * slope',
                                     'Geometric weights shared boundary length / centroid distance',
                                     'Prescribed incompressible proportional logarithmic strain path; affine xy',
                                     'Shared nodal z interpolated by reference-area averaging'],
                      'fit_to_simulation':False}
            (out/'model.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
            # Same observed mask for both fields; used ONLY during evaluation.
            observed,_=grain_response(r.path,geometry,top_ids)
            predicted_selected=predicted_nodes
            from src.theme1.contribution import _read_height
            mask=_read_height(r.path).node_id
            predicted_selected=predicted_selected[predicted_selected.node_id.isin(mask)]
            evaluation_path=out/'evaluation_predicted_coordinates.csv'
            predicted_selected.to_csv(evaluation_path,index=False)
            predicted_response,_=grain_response(evaluation_path,geometry,top_ids)
            comparison=observed.merge(predicted_response[['part_id','height_mean','surface_z_mean']],on='part_id',suffixes=('_actual','_predicted'),validate='one_to_one')
            comparison.to_csv(out/'height_comparison.csv',index=False)
            residual=comparison.height_mean_predicted-comparison.height_mean_actual
            raw_error=comparison.surface_z_mean_predicted-comparison.surface_z_mean_actual
            weights=comparison.retained_area
            row={'activity':args.activity,'case_id':case,'rho':r.rho,'seed':r.seed,'texture':r.texture,'sd':r.sd,'state':13,'grains':len(comparison),
                 'pearson':pearson(comparison.height_mean_predicted,comparison.height_mean_actual),
                 'spearman':spearman(comparison.height_mean_predicted,comparison.height_mean_actual),
                 'residual_rmse':np.sqrt(np.average(residual**2,weights=weights)),
                 'raw_height_rmse':np.sqrt(np.average(raw_error**2,weights=weights)),
                 'height_source':str(r.path.resolve())}
            by_part=comparison.set_index('part_id')
            positions=initial.set_index('part_id')[['center_x','center_y']]
            selected=edges[edges.part_id_i.isin(by_part.index)&edges.part_id_j.isin(by_part.index)]
            ai=selected.part_id_i.to_numpy();bi=selected.part_id_j.to_numpy()
            distance=np.linalg.norm(positions.loc[ai].to_numpy()-positions.loc[bi].to_numpy(),axis=1)
            error=by_part.height_mean_predicted-by_part.height_mean_actual
            slope_errors=(error.loc[ai].to_numpy()-error.loc[bi].to_numpy())/distance
            row['boundary_slope_rmse']=np.sqrt(np.average(slope_errors**2,weights=selected.weight)) if len(selected) else np.nan
            pred_norm,pred_rms=normalized_height_coordinates(evaluation_path)
            actual_norm,actual_rms=normalized_height_coordinates(r.path)
            pair=pred_norm[['node_id','z']].merge(actual_norm[['node_id','z']],on='node_id',suffixes=('_predicted','_actual'),validate='one_to_one')
            if len(pair)!=len(pred_norm) or len(pair)!=len(actual_norm):
                raise ValueError('Normalized comparison node selection mismatch')
            row['normalized_rmse']=np.sqrt(np.mean((pair.z_predicted-pair.z_actual)**2))
            row['normalized_pearson']=pearson(pair.z_predicted,pair.z_actual)
            row['predicted_nodal_rms']=pred_rms;row['actual_nodal_rms']=actual_rms
            row['normalization_status']='ok' if pred_rms>0 and actual_rms>0 else 'flat_field'
            rows.append(row)
        except (ValueError,OSError,KeyError) as exc:
            failures.append({'case_id':case,'error':str(exc)})
    table=args.output_dir/'evaluation.csv'
    previous=pd.read_csv(table) if table.exists() else pd.DataFrame()
    requested={f'rho_{r.rho:g}_{r.texture}_sd{r.sd}_seed{r.seed}_state13' for r in records}
    if len(previous):previous=previous[~previous.case_id.isin(requested)]
    pd.concat([previous,pd.DataFrame(rows)],ignore_index=True).to_csv(table,index=False)
    pd.DataFrame(failures,columns=['case_id','error']).to_csv(args.output_dir/'failed_cases.csv',index=False)
    print(f'Completed {len(rows)}/{len(records)}; {args.output_dir}')
    return int(bool(failures))


if __name__=='__main__':raise SystemExit(main())
