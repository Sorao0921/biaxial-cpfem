"""Initial-only K graph / frozen-tensor 3D equilibrium / state13 comparison."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from tqdm import tqdm

from src.config.pipeline_paths import PROJECT_ROOT,OUTPUTS_DIR,SPATIAL_MODELS_DIR,THEME1_DIR
from src.dashboard.catalog import scan_outputs,filter_records
from src.dashboard.initial_prediction import coordinate_height_figure,indicator_color_limits
from src.dashboard.export import combine_map_pngs
from src.theme1.contribution import _read_height
from src.theme1.neighbor_height import predict_from_initial,evaluate_coordinates
from src.theme1.sachs_equilibrium import predict_equilibrium_from_initial
from tools.theme1.predict_neighbor_height import save_prediction


def save_equilibrium(prediction,directory):
    directory.mkdir(parents=True,exist_ok=True)
    for key in ('coordinates','displacements','initial_tensors'):
        prediction[key].to_csv(directory/(key+'.csv'),index=False)
    (directory/'model.json').write_text(json.dumps(prediction['metadata'],indent=2)+'\n')


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--outputs',type=Path,default=OUTPUTS_DIR)
    parser.add_argument('--orientations',type=Path,default=PROJECT_ROOT/'inputs/orientation')
    parser.add_argument('--spatial-models',type=Path,default=SPATIAL_MODELS_DIR)
    parser.add_argument('--output-dir',type=Path,default=THEME1_DIR/'sachs_equilibrium_state13')
    parser.add_argument('--rho',type=float);parser.add_argument('--seed',type=int)
    parser.add_argument('--texture');parser.add_argument('--sd',type=int)
    parser.add_argument('--m',type=float,default=.05);parser.add_argument('--strain',type=float,default=.1)
    parser.add_argument('--heterogeneity',type=float,default=.75,help='Initial tensor contrast retained: 1=unrelaxed Sachs, 0=uniform volume-mean tensor')
    parser.add_argument('--poisson',type=float,default=.3)
    parser.add_argument('--coupling',type=float,default=1.);parser.add_argument('--inplane-weight',type=float,default=.5)
    parser.add_argument('--low-k-resistance',action=argparse.BooleanOptionalAction,default=True)
    args=parser.parse_args(argv)
    records=filter_records(scan_outputs(args.outputs),kind='height',state=13,rho=args.rho,seed=args.seed,texture=args.texture,sd=args.sd)
    if not records:raise SystemExit('No matching state13 cases')
    args.output_dir.mkdir(parents=True,exist_ok=True);rows=[];failures=[]
    for record in tqdm(records,desc='Initial 3D equilibrium',unit='case'):
        case=f'rho_{record.rho:g}_{record.texture}_sd{record.sd}_seed{record.seed}_state13'
        try:
            orientation=args.orientations/f'texture_seed{record.seed}'/f'{record.texture}_sigma{record.sd}_seed{record.seed}.csv'
            mesh=args.spatial_models/f'seed{record.seed}'
            graph=predict_from_initial(orientation,mesh,rho=record.rho,beta=None,m=args.m,strain=args.strain,
                feature_weights={'k':1.},coupling=args.coupling,inplane_weight=args.inplane_weight,low_k_resistance=args.low_k_resistance)
            equilibrium=predict_equilibrium_from_initial(orientation,mesh,rho=record.rho,m=args.m,strain=args.strain,poisson=args.poisson,heterogeneity=args.heterogeneity)
            # Compute and save BOTH complete predictions before opening actual heights.
            conditions={'graph':graph['metadata'],'equilibrium':{key:equilibrium['metadata'].get(key) for key in ('model','rho','beta','m','prescribed_strain','poisson','young_modulus','eigenstrain_heterogeneity','heterogeneity_rule','elasticity','boundary','kinematics','eigenstrain_scale','orientation_source','initial_model_source','input_versions')}}
            config=hashlib.sha256(json.dumps(conditions,sort_keys=True).encode()).hexdigest()[:12]
            directory=args.output_dir/case/config
            save_prediction(graph,directory/'k_graph');save_equilibrium(equilibrium,directory/'equilibrium')
            actual=_read_height(record.path)
            graph_selected,graph_pair,graph_metrics=evaluate_coordinates(graph['coordinates'],actual)
            eq_selected,eq_pair,eq_metrics=evaluate_coordinates(equilibrium['coordinates'],actual)
            actual.to_csv(directory/'actual_coordinates_state13.csv',index=False)
            graph_pair.to_csv(directory/'k_graph/height_comparison.csv',index=False)
            eq_pair.to_csv(directory/'equilibrium/height_comparison.csv',index=False)
            limits=indicator_color_limits(np.concatenate([graph_selected.z,eq_selected.z,actual.z])*1000,robust=True)
            panels=[]
            for name,frame,metrics in [('K graph',graph_selected,graph_metrics),('3D equilibrium',eq_selected,eq_metrics),('Simulation state13',actual,None)]:
                title=name+(f"\nr={metrics['nodal_pearson']:.3f}, RMSE={metrics['raw_height_rmse']:.3g}" if metrics else '')
                if name=='3D equilibrium' and not equilibrium['metadata']['finite_geometry_valid']:
                    title+='\nOutside small-strain range'
                fig=coordinate_height_figure(frame,mesh,title=title,value_range=limits)
                stream=io.BytesIO();fig.savefig(stream,format='png',dpi=160,facecolor='white');plt.close(fig)
                panels.append(stream.getvalue())
            (directory/'comparison.png').write_bytes(combine_map_pngs(panels,columns=3,dpi=160))
            for name,metrics in [('k_graph',graph_metrics),('equilibrium',eq_metrics)]:
                row={'case_id':case,'config_id':config,'model':name,'rho':record.rho,'seed':record.seed,'texture':record.texture,'sd':record.sd,
                    'm':args.m,'prescribed_strain':args.strain,'beta':equilibrium['metadata']['beta'],
                    'poisson':args.poisson if name=='equilibrium' else None,'eigenstrain_heterogeneity':args.heterogeneity if name=='equilibrium' else None,'directory':str(directory.resolve()),**metrics}
                if name=='equilibrium':
                    row.update({key:equilibrium['metadata'][key] for key in ['relative_free_force_residual','iterations','finite_geometry_valid','inverted_deformed_elements','maximum_eigenstrain_norm']})
                rows.append(row)
            (directory/'evaluation.json').write_text(json.dumps([{key:(None if isinstance(value,float) and not np.isfinite(value) else value) for key,value in item.items()} for item in rows[-2:]],indent=2,allow_nan=False)+'\n')
        except (ValueError,KeyError,OSError) as error:
            failures.append({'case_id':case,'error':str(error)})
    if rows:
        table=args.output_dir/'evaluation.csv';previous=pd.read_csv(table) if table.exists() else pd.DataFrame()
        pd.concat([previous,pd.DataFrame(rows)],ignore_index=True).drop_duplicates(['case_id','config_id','model'],keep='last').to_csv(table,index=False)
    pd.DataFrame(failures,columns=['case_id','error']).to_csv(args.output_dir/'failed_cases.csv',index=False)
    print(f'Completed {len(rows)//2}/{len(records)}; {args.output_dir}')
    return int(bool(failures))


if __name__=='__main__':raise SystemExit(main())
