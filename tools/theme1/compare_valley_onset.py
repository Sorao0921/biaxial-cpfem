"""Predict valley initiation from initial inputs and evaluate against state02."""
import argparse
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd
from src.config.pipeline_paths import PROJECT_ROOT,OUTPUTS_DIR,SPATIAL_MODELS_DIR,THEME1_DIR
from src.dashboard.catalog import scan_outputs,filter_records
from src.theme1.contribution import _read_height
from src.theme1.valley_onset import predict_onset_models,evaluate_onset,MODEL_NAMES,LABELS,property_table
from src.dashboard.valley_onset import onset_archive
from src.dashboard.valley_evaluation import valley_figures,valley_png


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rho',type=float);parser.add_argument('--seed',type=int)
    parser.add_argument('--texture');parser.add_argument('--sd',type=int)
    parser.add_argument('--strain',type=float,default=.01);parser.add_argument('--m',type=float,default=.05)
    parser.add_argument('--output-dir',type=Path,default=THEME1_DIR/'valley_origins_state02_five_models')
    parser.add_argument('--skip-maps',action='store_true')
    args=parser.parse_args(argv)
    records=filter_records(scan_outputs(OUTPUTS_DIR),kind='height',state=2,rho=args.rho,seed=args.seed,texture=args.texture,sd=args.sd)
    if not records:raise SystemExit('No matching state02 reference heights')
    args.output_dir.mkdir(parents=True,exist_ok=True);rows=[];union_rows=[];failures=[]
    for i,r in enumerate(records):
        case=f'rho_{r.rho:g}_{r.texture}_sd{r.sd}_seed{r.seed}_state02'
        try:
            mesh=SPATIAL_MODELS_DIR/f'seed{r.seed}'
            orientation=PROJECT_ROOT/'inputs/orientation'/f'texture_seed{r.seed}'/f'{r.texture}_sigma{r.sd}_seed{r.seed}.csv'
            prediction=predict_onset_models(orientation,mesh,rho=r.rho,m=args.m,strain=args.strain)
            target=args.output_dir/case/prediction['config_id'];target.mkdir(parents=True,exist_ok=True)
            property_table().to_csv(target/'properties.csv',index=False,encoding='utf-8-sig')
            # Save predictions and conditions before opening a current-state reference.
            (target/'configuration.json').write_text(json.dumps(prediction['configuration'],indent=2)+'\n')
            for name,model in prediction['models'].items():
                directory=target/name;directory.mkdir(exist_ok=True)
                for key in ['coordinates','grains','displacements','initial_tensors']:
                    if key in model:model[key].to_csv(directory/(key+'.csv'),index=False)
                (directory/'model.json').write_text(json.dumps(model['metadata'],indent=2)+'\n')
            reference=_read_height(r.path)
            result=evaluate_onset(prediction,reference,mesh)
            result['metadata'].update(source_case=case,reference_height_source=str(r.path))
            (target/'onset_evaluation.zip').write_bytes(onset_archive(prediction,result))
            for key in ['metrics','transitions','transition_grains','centroids','thresholds','bottom_lines','bottom_line_support','reference_bottom_grains','local_lowness','origins','origin_nodes','origin_support','origin_flags','taylor_factors','taylor_boundary_segments','taylor_boundaries','taylor_origin_boundary','taylor_boundary_metrics','union_metrics','union_origin_flags']:
                result[key].to_csv(target/(key+'.csv'),index=False)
            if not args.skip_maps:
                figures=valley_figures(result,mesh,model_names=MODEL_NAMES,labels=LABELS)
                (target/'valley_initiation.png').write_bytes(valley_png(figures,columns=len(figures)))
                for figure in figures:plt.close(figure)
            union_rows.append(result['union_metrics'].assign(case_id=case,config_id=prediction['config_id'],rho=r.rho,seed=r.seed,texture=r.texture,sd=r.sd))
            rows.append(result['metrics'].assign(case_id=case,config_id=prediction['config_id'],rho=r.rho,seed=r.seed,texture=r.texture,sd=r.sd))
            print(f'[{i+1}/{len(records)}] {case}',flush=True)
        except (ValueError,KeyError,OSError) as error:
            failures.append(dict(case_id=case,error=str(error)));print(f'FAILED {case}: {error}',flush=True)
    if rows:
        file=args.output_dir/'metrics.csv';previous=pd.read_csv(file) if file.exists() else pd.DataFrame()
        pd.concat([previous,*rows],ignore_index=True).drop_duplicates(['case_id','config_id','model','level','feature','threshold_factor'],keep='last').to_csv(file,index=False)
    if union_rows:
        file=args.output_dir/'union_metrics.csv';previous=pd.read_csv(file) if file.exists() else pd.DataFrame()
        pd.concat([previous,*union_rows],ignore_index=True).drop_duplicates(['case_id','config_id','model','threshold_factor','threshold_rms_multiplier'],keep='last').to_csv(file,index=False)
    pd.DataFrame(failures,columns=['case_id','error']).to_csv(args.output_dir/'failures.csv',index=False)
    return int(bool(failures))


if __name__=='__main__':raise SystemExit(main())
