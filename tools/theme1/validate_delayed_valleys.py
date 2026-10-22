"""Follow frozen state02 candidates into later CPFEM reference states."""
import argparse,json
from pathlib import Path
import pandas as pd
from src.config.pipeline_paths import PROJECT_ROOT,OUTPUTS_DIR,SPATIAL_MODELS_DIR
from src.dashboard.catalog import scan_outputs,filter_records
from src.theme1.contribution import _read_height
from src.theme1.valley_onset import predict_onset_models,evaluate_onset
from src.theme1.delayed_valley import validate_delayed_candidates


def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rho',type=float,required=True);p.add_argument('--seed',type=int,required=True)
    p.add_argument('--texture',required=True);p.add_argument('--sd',type=int,required=True)
    p.add_argument('--output-dir',type=Path,default=PROJECT_ROOT/'output/reports/delayed_valleys')
    args=p.parse_args(argv)
    records=filter_records(scan_outputs(OUTPUTS_DIR),kind='height',rho=args.rho,seed=args.seed,texture=args.texture,sd=args.sd)
    records=[r for r in records if r.state>=2]
    if not any(r.state==2 for r in records):raise SystemExit('No state02 baseline')
    mesh=SPATIAL_MODELS_DIR/f'seed{args.seed}'
    orientation=PROJECT_ROOT/'inputs/orientation'/f'texture_seed{args.seed}'/f'{args.texture}_sigma{args.sd}_seed{args.seed}.csv'
    prediction=predict_onset_models(orientation,mesh,rho=args.rho)
    # All initial predictions and Delta M exist before any reference is opened.
    heights={r.state:_read_height(r.path) for r in records}
    baseline=evaluate_onset(prediction,heights[2],mesh)
    result=validate_delayed_candidates(baseline,heights,mesh)
    root=args.output_dir/f'rho_{args.rho:g}_{args.texture}_sd{args.sd}_seed{args.seed}'/prediction['config_id'];root.mkdir(parents=True,exist_ok=True)
    for key,value in result.items():
        if isinstance(value,pd.DataFrame):value.to_csv(root/(key+'.csv'),index=False,encoding='utf-8-sig')
    result['metadata'].update(prediction_configuration=prediction['configuration'],
        reference_sources={r.state:str(r.path) for r in records},baseline_evaluation=baseline['metadata'])
    (root/'method.json').write_text(json.dumps(result['metadata'],ensure_ascii=False,indent=2)+'\n')
    print(result['summary'].to_string(index=False));print(root)
    return 0


if __name__=='__main__':raise SystemExit(main())
