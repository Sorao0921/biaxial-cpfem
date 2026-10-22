"""Initial-only neighbor height reconstruction; save full prediction BEFORE evaluation."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import pandas as pd
from tqdm.auto import tqdm
from src.config.pipeline_paths import PROJECT_ROOT,OUTPUTS_DIR,SPATIAL_MODELS_DIR,THEME1_DIR
from src.dashboard.catalog import scan_outputs,filter_records
from src.theme1.neighbor_height import predict_from_initial,evaluate_coordinates,DEFAULT_BLEND
from src.theme1.contribution import _read_height


def save_prediction(prediction,directory):
    """No observed values accepted; the full prediction is written first."""
    directory.mkdir(parents=True,exist_ok=True)
    for name in ('grains','edges','components','coordinates','initial_properties'):
        prediction[name].to_csv(directory/f'{name}.csv',index=False)
    (directory/'model.json').write_text(json.dumps(prediction['metadata'],ensure_ascii=False,indent=2)+'\n')


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--outputs',type=Path,default=OUTPUTS_DIR)
    parser.add_argument('--orientations',type=Path,default=PROJECT_ROOT/'inputs/orientation')
    parser.add_argument('--spatial-models',type=Path,default=SPATIAL_MODELS_DIR)
    parser.add_argument('--output-dir',type=Path,default=THEME1_DIR/'neighbor_height_state13')
    parser.add_argument('--rho',type=float);parser.add_argument('--seed',type=int)
    parser.add_argument('--texture');parser.add_argument('--sd',type=int)
    parser.add_argument('--source',choices=['k','chi','pminus','pabs','m','blend'],default='k')
    parser.add_argument('--weights',type=json.loads,help='Explicit nonnegative blend weights as JSON; never fitted')
    parser.add_argument('--beta',type=float,default=None,help='Manual override; default matches initial volume-mean strain ratio to rho')
    parser.add_argument('--m',type=float,default=.05)
    parser.add_argument('--strain',type=float,default=.1,help='Prescribed equivalent logarithmic strain, not extracted from results')
    parser.add_argument('--coupling',type=float,default=1.)
    parser.add_argument('--inplane-weight',type=float,default=.5)
    parser.add_argument('--low-k-resistance',action=argparse.BooleanOptionalAction,default=True)
    parser.add_argument('--standardize',action=argparse.BooleanOptionalAction,default=None)
    args=parser.parse_args(argv)
    weights=args.weights if args.weights is not None else (DEFAULT_BLEND if args.source=='blend' else {args.source:1.})
    standardize=args.standardize if args.standardize is not None else args.source=='blend' or args.weights is not None
    records=filter_records(scan_outputs(args.outputs),kind='height',state=13,rho=args.rho,seed=args.seed,texture=args.texture,sd=args.sd)
    if not records:raise SystemExit('No matching state13 evaluation cases')
    args.output_dir.mkdir(parents=True,exist_ok=True);rows=[];failures=[]
    for record in tqdm(records,desc='Initial neighbor height',unit='case'):
        case=f'rho_{record.rho:g}_{record.texture}_sd{record.sd}_seed{record.seed}_state13'
        try:
            orientation=args.orientations/f'texture_seed{record.seed}'/f'{record.texture}_sigma{record.sd}_seed{record.seed}.csv'
            prediction=predict_from_initial(orientation,args.spatial_models/f'seed{record.seed}',rho=record.rho,beta=args.beta,m=args.m,
                strain=args.strain,feature_weights=weights,coupling=args.coupling,standardize=standardize,inplane_weight=args.inplane_weight,low_k_resistance=args.low_k_resistance)
            config=hashlib.sha256(json.dumps(prediction['metadata'],sort_keys=True).encode()).hexdigest()[:12]
            directory=args.output_dir/case/config
            save_prediction(prediction,directory)
            # Only now is the observed height opened, exclusively for evaluation.
            actual=_read_height(record.path)
            selected,pair,metrics=evaluate_coordinates(prediction['coordinates'],actual)
            selected.to_csv(directory/'evaluation_predicted_coordinates.csv',index=False)
            pair.to_csv(directory/'height_comparison.csv',index=False)
            evaluation={'case_id':case,'config_id':config,'source':args.source,'beta':prediction['metadata'].get('beta',args.beta),'m':args.m,
                        'rho':record.rho,'seed':record.seed,'texture':record.texture,'sd':record.sd,
                        'coupling':args.coupling,'prescribed_strain':args.strain,'standardize_initial_inputs':standardize,
                        'inplane_weight':args.inplane_weight,'low_k_resistance':args.low_k_resistance,
                        'feature_weights':json.dumps(prediction['metadata']['feature_weights'],sort_keys=True),
                        'directory':str(directory.resolve()),'height_source':str(record.path.resolve()),**metrics}
            (directory/'evaluation.json').write_text(json.dumps({key:(None if isinstance(value,float) and not np.isfinite(value) else value) for key,value in evaluation.items()},ensure_ascii=False,indent=2)+'\n')
            rows.append(evaluation)
        except (ValueError,KeyError,OSError) as error:
            failures.append({'case_id':case,'error':str(error)})
    table=args.output_dir/'evaluation.csv'
    previous=pd.read_csv(table) if table.exists() else pd.DataFrame()
    if rows:
        pd.concat([previous,pd.DataFrame(rows)],ignore_index=True).drop_duplicates(['case_id','config_id'],keep='last').to_csv(table,index=False)
    pd.DataFrame(failures,columns=['case_id','error']).to_csv(args.output_dir/'failed_cases.csv',index=False)
    print(f'Completed {len(rows)}/{len(records)}; {args.output_dir}')
    return int(bool(failures))


if __name__=='__main__':raise SystemExit(main())
