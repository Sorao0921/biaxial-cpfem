"""Evaluate saved initial-only predictions for deep valleys; never rerun/fits models."""
import argparse
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd
from tqdm import tqdm
from src.config.pipeline_paths import THEME1_DIR,SPATIAL_MODELS_DIR
from src.theme1.initial_fourway import MODEL_NAMES
from src.theme1.valley_evaluation import valley_tables,fft_scale_table,save_valley_evaluation
from src.dashboard.valley_evaluation import valley_figures,valley_png


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prediction-root',type=Path,default=THEME1_DIR/'initial_fourway_state13')
    parser.add_argument('--spatial-models',type=Path,default=SPATIAL_MODELS_DIR)
    parser.add_argument('--case',help='Exact saved case directory name')
    parser.add_argument('--distance-threshold',type=float,default=None,help='Optional legacy common absolute cutoff; default independent automatic RMS centroid cutoffs')
    parser.add_argument('--fft',action='store_true',help='Also report geometry-defined FFT scales')
    parser.add_argument('--skip-maps',action='store_true')
    args=parser.parse_args(argv)
    paths=sorted(args.prediction_root.glob('*/'+ '*/configuration.json'))
    if args.case:paths=[p for p in paths if p.parent.parent.name==args.case]
    if not paths:raise SystemExit('No saved four-model predictions found')
    rows=[];failures=[]
    for path in tqdm(paths,desc='Deep-valley detection',unit='case'):
        case=path.parent.parent.name;directory=path.parent
        try:
            configuration=json.loads(path.read_text());model=args.spatial_models/f'seed{case.split("_seed")[-1].split("_")[0]}'
            actual=pd.read_csv(directory/'cpfem_state13.csv');selected={'cpfem':actual}
            validity={}
            for name in MODEL_NAMES:
                selected[name]=pd.read_csv(directory/name/'coordinates.csv')
                metadata=json.loads((directory/name/'model.json').read_text())
                validity[name]={key:metadata[key] for key in ['finite_geometry_valid','inverted_deformed_elements','maximum_eigenstrain_norm'] if key in metadata}
            result=valley_tables(selected,model,threshold=args.distance_threshold)
            result['metadata'].update(source_configuration=configuration,source_prediction_directory=str(directory.resolve()),model_validity=validity)
            fft=fft_scale_table(selected,model) if args.fft else None
            output=directory/'centroid_detection_evaluation';save_valley_evaluation(result,output,fft)
            if not args.skip_maps:
                for feature in ('valley','peak'):
                    figures=valley_figures(result,model,level='grain',feature=feature)
                    (output/f'{feature}_grain_plane_distance.png').write_bytes(valley_png(figures))
                    for figure in figures:plt.close(figure)
            rows.append(result['metrics'].assign(case_id=case,config_id=directory.name))
        except (ValueError,KeyError,OSError) as error:failures.append({'case_id':case,'config_id':directory.name,'error':str(error)})
    if rows:pd.concat(rows,ignore_index=True).to_csv(args.prediction_root/'centroid_detection_summary.csv',index=False)
    pd.DataFrame(failures,columns=['case_id','config_id','error']).to_csv(args.prediction_root/'centroid_detection_failures.csv',index=False)
    print(f'Completed {len(rows)}/{len(paths)} evaluations')
    return int(bool(failures))


if __name__=='__main__':raise SystemExit(main())
