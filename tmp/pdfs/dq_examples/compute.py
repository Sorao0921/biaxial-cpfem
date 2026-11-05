import os
os.environ['MPLBACKEND']='Agg'
os.environ['MPLCONFIGDIR']='/tmp/codex_dq_mpl'
os.environ['OPENBLAS_NUM_THREADS']='1'
os.environ['OMP_NUM_THREADS']='1'
import sys,time,pickle,json,traceback
from pathlib import Path
sys.path.insert(0,str(Path.cwd()))
import pandas as pd
from concurrent.futures import ProcessPoolExecutor,as_completed
from src.dashboard.catalog import scan_outputs
from src.config.pipeline_paths import OUTPUTS_DIR,PROJECT_ROOT,build_spatial_model_dir,build_post_directories
ROOT=Path('tmp/pdfs/dq_examples');ROOT.mkdir(parents=True,exist_ok=True)
OUT=Path('output/pdf/dq_examples_state02')

def work(r):
    from src.theme1.dq_origins import predict_dq,track_dq,track_dq_peaks,VERSION
    from src.theme1.contribution import _read_height
    key=f'rho{r.rho:g}_{r.texture}_sd{r.sd}_seed{r.seed}'
    path=ROOT/(key+'.pkl')
    if path.exists():return pickle.loads(path.read_bytes())['rows']
    model=build_spatial_model_dir(r.seed)
    orientation=PROJECT_ROOT/'inputs/orientation'/f'texture_seed{r.seed}'/f'{r.texture}_sigma{r.sd}_seed{r.seed}.csv'
    prediction=predict_dq(orientation,model,r.rho)
    ref=_read_height(r.path)
    eps=pd.read_csv(build_post_directories(r.rho,r.seed).equivalent_strain_csv).eps_eq.iloc[1]
    bundle={'reference':ref,'rows':[],'model_dir':str(model),'key':key}
    for feature,func in [('valley',track_dq),('peak',track_dq_peaks)]:
        result=func(prediction,{2:ref},model)
        metric=result['detection']['metrics'].query('threshold_factor==1').iloc[0]
        row=dict(case=key,rho=r.rho,texture=r.texture,sd=r.sd,seed=r.seed,feature=feature,state=2,eps_eq=eps,
            origin_count=int(metric.origin_count),captured=int(metric.hit_origin_count),capture_rate=float(metric.origin_recall),
            predicted_count=int(metric.predicted_count),area_fraction=float(metric.predicted_area_fraction),
            efficiency=float(metric.capture_per_area),source=str(r.path),version=VERSION)
        bundle['rows'].append(row)
        bundle[feature]={'prediction':result['prediction'],'origins':result['origins'],'lines':result['lines'],'flags':result['flags'],
            'metrics':row,'metadata':result['metadata']}
    path.write_bytes(pickle.dumps(bundle,protocol=5))
    return bundle['rows']

if __name__=='__main__':
    records=[r for r in scan_outputs(OUTPUTS_DIR) if r.kind=='height' and r.state==2]
    records=sorted(records,key=lambda r:(r.seed,r.rho,r.texture,r.sd))
    rows=[];failed=[];start=time.time()
    with ProcessPoolExecutor(max_workers=3) as pool:
        jobs={pool.submit(work,r):r for r in records}
        for n,f in enumerate(as_completed(jobs),1):
            try:rows.extend(f.result())
            except Exception as e:
                failed.append({'case':str(jobs[f]),'error':str(e)});print(traceback.format_exc(),flush=True)
            if n%10==0 or n==1:
                print(f'{n}/{len(records)} complete; {time.time()-start:.0f}s; failures={len(failed)}',flush=True)
                pd.DataFrame(rows).to_csv(OUT/'all_case_metrics.csv',index=False)
    pd.DataFrame(rows).sort_values(['feature','texture','rho','seed','sd']).to_csv(OUT/'all_case_metrics.csv',index=False)
    (OUT/'failures.json').write_text(json.dumps(failed,ensure_ascii=False,indent=2))
    print('DONE',len(rows),'metric rows',flush=True)
