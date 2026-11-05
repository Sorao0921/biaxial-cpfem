"""Compare K-only, D/Q, 3D equilibrium and CPFEM state13 with shared inputs."""
import argparse
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd
from tqdm import tqdm
from src.config.pipeline_paths import PROJECT_ROOT,OUTPUTS_DIR,SPATIAL_MODELS_DIR,THEME1_DIR
from src.dashboard.catalog import scan_outputs,filter_records
from src.dashboard.initial_fourway import comparison_figures,figures_png
from src.theme1.contribution import _read_height
from src.theme1.initial_fourway import predict_three_models,evaluate_three_models,save_initial_prediction


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--outputs',type=Path,default=OUTPUTS_DIR)
    parser.add_argument('--orientations',type=Path,default=PROJECT_ROOT/'inputs/orientation')
    parser.add_argument('--spatial-models',type=Path,default=SPATIAL_MODELS_DIR)
    parser.add_argument('--output-dir',type=Path,default=THEME1_DIR/'initial_fourway_state13')
    parser.add_argument('--rho',type=float);parser.add_argument('--seed',type=int);parser.add_argument('--texture');parser.add_argument('--sd',type=int)
    parser.add_argument('--m',type=float,default=.05);parser.add_argument('--strain',type=float,default=.1)
    parser.add_argument('--heterogeneity',type=float,default=.75);parser.add_argument('--coupling',type=float,default=1.)
    parser.add_argument('--q-coupling',type=float,default=1.);parser.add_argument('--poisson',type=float,default=.3)
    args=parser.parse_args(argv)
    records=filter_records(scan_outputs(args.outputs),kind='height',state=13,rho=args.rho,seed=args.seed,texture=args.texture,sd=args.sd)
    if not records:raise SystemExit('No matching state13 cases')
    args.output_dir.mkdir(parents=True,exist_ok=True);rows=[];failures=[]
    for record in tqdm(records,desc='K / D,Q / 3D / CPFEM',unit='case'):
        case=f'rho_{record.rho:g}_{record.texture}_sd{record.sd}_seed{record.seed}_state13'
        try:
            orientation=args.orientations/f'texture_seed{record.seed}'/f'{record.texture}_sigma{record.sd}_seed{record.seed}.csv'
            mesh=args.spatial_models/f'seed{record.seed}'
            prediction=predict_three_models(orientation,mesh,rho=record.rho,m=args.m,strain=args.strain,heterogeneity=args.heterogeneity,
                coupling=args.coupling,q_coupling=args.q_coupling,poisson=args.poisson)
            directory=args.output_dir/case/prediction['config_id']
            save_initial_prediction(prediction,directory)
            # No actual-state values have been opened before all models are saved.
            actual=_read_height(record.path)
            evaluation=evaluate_three_models(prediction,actual)
            actual.to_csv(directory/'cpfem_state13.csv',index=False)
            for name,pair in evaluation['pairs'].items():pair.to_csv(directory/name/'height_comparison.csv',index=False)
            figures=comparison_figures(prediction,evaluation,mesh)
            (directory/'comparison.png').write_bytes(figures_png(figures))
            for figure in figures:plt.close(figure)
            metrics=evaluation['metrics'].assign(case_id=case,config_id=prediction['config_id'],rho=record.rho,seed=record.seed,
                texture=record.texture,sd=record.sd,m=args.m,prescribed_strain=args.strain,heterogeneity=args.heterogeneity,
                coupling=args.coupling,q_coupling=args.q_coupling,poisson=args.poisson,beta=prediction['configuration']['beta'],directory=str(directory.resolve()))
            metrics.to_csv(directory/'evaluation.csv',index=False);rows.append(metrics)
        except (ValueError,KeyError,OSError) as error:
            failures.append({'case_id':case,'error':str(error)})
    if rows:
        table=args.output_dir/'evaluation.csv';previous=pd.read_csv(table) if table.exists() else pd.DataFrame()
        pd.concat([previous,*rows],ignore_index=True).drop_duplicates(['case_id','config_id','model'],keep='last').to_csv(table,index=False)
    pd.DataFrame(failures,columns=['case_id','error']).to_csv(args.output_dir/'failed_cases.csv',index=False)
    print(f'Completed {len(rows)}/{len(records)}; {args.output_dir}')
    return int(bool(failures))


if __name__=='__main__':raise SystemExit(main())
