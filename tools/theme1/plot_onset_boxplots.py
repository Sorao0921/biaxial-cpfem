"""All state02 cases, five initial-only ablations, valley detection boxplots."""
import argparse
import json
from pathlib import Path
import zipfile
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import numpy as np
import pandas as pd
from src.config.pipeline_paths import PROJECT_ROOT,OUTPUTS_DIR,SPATIAL_MODELS_DIR,THEME1_DIR
from src.dashboard.catalog import scan_outputs,filter_records
from src.theme1.valley_onset import MODEL_NAMES,LABELS,predict_onset_models,evaluate_onset,property_table
from src.theme1.contribution import _read_height
from src.theme1.valley_evaluation import valley_tables

TEXTURES=('brass','copper','s','cube','goss')
NAMES={name:LABELS[name] for name in MODEL_NAMES}
COLORS={'origin_recall':'#377ca8','precision':'#d99730','recall':'#d99730','f1':'#a35e89'}
METRICS={'origin_recall':'Origin recall','precision':'Grain precision (aux.)','f1':'Grain F1 (aux.)'}


def draw_plots(data,root):
    summaries=[]
    book=PdfPages(root/'overview_boxplots.pdf')
    for (rho,feature),frame in data.groupby(['rho','feature'],sort=True):
        fig,axes=plt.subplots(2,3,figsize=(17,11))
        axes=axes.ravel()
        fig.subplots_adjust(left=.055,right=.985,bottom=.13,top=.91,wspace=.25,hspace=.38)
        fig.suptitle(f'{feature.capitalize()} grain detection at state02 | strain ratio rho = {rho:g}',fontsize=16)
        for ax,model in zip(axes,MODEL_NAMES):
            ax.set_title(NAMES[model],fontsize=13)
            for j,(metric,label) in enumerate(METRICS.items()):
                for i,texture in enumerate(TEXTURES):
                    rows=frame[(frame.model==model)&(frame.texture==texture)]
                    values=rows[metric].dropna().to_numpy(float);position=i+(j-1)*.24
                    if len(values):
                        box=ax.boxplot([values],positions=[position],widths=.20,patch_artist=True,manage_ticks=False,
                            whis=1.5,showfliers=False,medianprops={'color':'#222222','linewidth':1.4},
                            boxprops={'facecolor':COLORS[metric],'alpha':.55,'edgecolor':'#444444'},
                            whiskerprops={'color':'#666666'},capprops={'color':'#666666'})
                        # Every case is visible, including points beyond the whiskers.
                        offsets=np.linspace(-.06,.06,len(values)) if len(values)>1 else np.zeros(1)
                        ax.scatter(position+offsets,values,s=12,color=COLORS[metric],edgecolor='white',linewidth=.3,zorder=3)
                    summaries.append(dict(rho=rho,feature=feature,texture=texture,model=model,metric=metric,
                        n_cases=len(rows),n_valid=len(values),n_undefined=len(rows)-len(values),
                        median=float(np.median(values)) if len(values) else np.nan,
                        q1=float(np.quantile(values,.25)) if len(values) else np.nan,
                        q3=float(np.quantile(values,.75)) if len(values) else np.nan,
                        minimum=float(values.min()) if len(values) else np.nan,maximum=float(values.max()) if len(values) else np.nan))
            ax.set(xticks=range(5),xticklabels=[(x.capitalize() if x!='s' else 'S')+f'\nn={frame[frame.texture==x].case_id.nunique() if "case_id" in frame else len(frame[(frame.texture==x)&(frame.model==MODEL_NAMES[0])])}' for x in TEXTURES],
                ylabel='Score',ylim=(-.025,1.025),xlim=(-.6,4.6))
            ax.grid(axis='y',color='#dddddd',linewidth=.6);ax.set_axisbelow(True)
            ax.spines[['top','right']].set_visible(False)
        for ax in axes[len(MODEL_NAMES):]:ax.set_visible(False)
        handles=[plt.Line2D([],[],marker='s',linestyle='',color=COLORS[m],label=label) for m,label in METRICS.items()]
        fig.legend(handles=handles,loc='lower center',bbox_to_anchor=(.5,.045),ncol=3,frameon=False)
        fig.supxlabel('Texture | one point = one case (seed, orientation spread); whiskers = 1.5 IQR; undefined omitted',fontsize=10,y=.025)
        stem=root/f'rho_{rho:g}_{feature}_precision_recall_f1'
        fig.savefig(Path(str(stem)+'.png'),dpi=200,facecolor='white')
        fig.savefig(Path(str(stem)+'.pdf'),facecolor='white');book.savefig(fig,facecolor='white');plt.close(fig)
        frame.to_csv(root/f'rho_{rho:g}_{feature}_case_metrics.csv',index=False,encoding='utf-8-sig')
        for model in MODEL_NAMES:
            frame[frame.model==model].to_csv(root/f'{model}_rho_{rho:g}_{feature}_case_metrics.csv',index=False,encoding='utf-8-sig')
    book.close()
    return pd.DataFrame(summaries)


def draw_individual(data,root):
    """One separate chart per model/rho, three metrics on the same panel."""
    output=root/'individual_models';output.mkdir(exist_ok=True)
    book=PdfPages(root/'all_boxplots.pdf')
    for (rho,feature),frame in data.groupby(['rho','feature'],sort=True):
        for model in MODEL_NAMES:
            fig,ax=plt.subplots(figsize=(8,5.8))
            fig.subplots_adjust(left=.11,right=.98,bottom=.26,top=.84)
            fig.suptitle(f'{NAMES[model]} | rho = {rho:g} | state02 valley detection',fontsize=13)
            rows=frame[frame.model==model]
            for j,(metric,label) in enumerate(METRICS.items()):
                for i,texture in enumerate(TEXTURES):
                    values=rows[rows.texture==texture][metric].dropna().to_numpy(float)
                    if not len(values):continue
                    position=i+(j-1)*.24
                    ax.boxplot([values],positions=[position],widths=.20,manage_ticks=False,patch_artist=True,
                        whis=1.5,showfliers=False,medianprops={'color':'#222222'},
                        boxprops={'facecolor':COLORS[metric],'alpha':.55,'edgecolor':'#444444'},
                        whiskerprops={'color':'#666666'},capprops={'color':'#666666'})
                    ax.scatter(position+np.linspace(-.06,.06,len(values)),values,s=16,color=COLORS[metric],edgecolors='white',linewidth=.3,zorder=3)
            labels=[(x.capitalize() if x!='s' else 'S')+f'\nn={rows[rows.texture==x].case_id.nunique()}' for x in TEXTURES]
            ax.set(xticks=range(5),xticklabels=labels,ylabel='Score',ylim=(-.025,1.025),xlim=(-.6,4.6))
            ax.grid(axis='y',color='#dddddd',linewidth=.6);ax.set_axisbelow(True);ax.spines[['top','right']].set_visible(False)
            handles=[plt.Line2D([],[],marker='s',linestyle='',color=COLORS[m],label=label) for m,label in METRICS.items()]
            fig.legend(handles=handles,loc='lower center',bbox_to_anchor=(.5,.08),ncol=3,frameon=False)
            fig.supxlabel('Texture | one point = one case; whiskers = 1.5 IQR; undefined omitted',fontsize=10,y=.03)
            stem=output/f'{model}_rho_{rho:g}_{feature}'
            fig.savefig(Path(str(stem)+'.png'),dpi=180,facecolor='white');fig.savefig(Path(str(stem)+'.pdf'),facecolor='white')
            book.savefig(fig,facecolor='white');plt.close(fig)
    book.close()


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir',type=Path,default=PROJECT_ROOT/'output/reports/valley_origins_state02_five_models')
    parser.add_argument('--plots-only',action='store_true')
    parser.add_argument('--reuse-predictions',type=Path,help='Previous case_data directory; validate initial inputs/conditions before reusing coordinates')
    args=parser.parse_args(argv);root=args.output_dir;root.mkdir(parents=True,exist_ok=True)
    cache=root/'case_data';cache.mkdir(exist_ok=True)
    property_table().to_csv(root/'properties.csv',index=False,encoding='utf-8-sig')
    records=filter_records(scan_outputs(OUTPUTS_DIR),kind='height',state=2)
    records=sorted(records,key=lambda r:(r.seed,r.rho,r.texture,r.sd))
    pd.DataFrame([dict(case_id=f'rho_{r.rho:g}_{r.texture}_sd{r.sd}_seed{r.seed}_state02',rho=r.rho,seed=r.seed,texture=r.texture,sd=r.sd,reference_height_source=str(r.path)) for r in records]).to_csv(root/'case_manifest.csv',index=False)
    allrows=[];failures=[]
    if not args.plots_only:
        for i,r in enumerate(records):
            case=f'rho_{r.rho:g}_{r.texture}_sd{r.sd}_seed{r.seed}_state02';target=cache/case;target.mkdir(exist_ok=True)
            try:
                metrics_path=target/'metrics.csv'
                if metrics_path.exists() and (target/'method.json').exists() and json.loads((target/'method.json').read_text()).get('method_version')=='local_valley_origins_v4' and json.loads((target/'configuration.json').read_text()).get('version')=='valley_onset_v2_five_conditions' and (target/'union_metrics.csv').exists():
                    rows=pd.read_csv(metrics_path)
                else:
                    mesh=SPATIAL_MODELS_DIR/f'seed{r.seed}'
                    orientation=PROJECT_ROOT/'inputs/orientation'/f'texture_seed{r.seed}'/f'{r.texture}_sigma{r.sd}_seed{r.seed}.csv'
                    # Prediction is complete before opening the reference height.
                    prediction=None
                    source=args.reuse_predictions/case if args.reuse_predictions else None
                    if source and (source/'configuration.json').exists():
                        cfg=json.loads((source/'configuration.json').read_text())
                        versions={'orientation':orientation.stat().st_mtime_ns,'nodes':(mesh/'nodes.csv').stat().st_mtime_ns,'elements':(mesh/'elements.csv').stat().st_mtime_ns}
                        expected=dict(rho=r.rho,m=.05,strain=.01,heterogeneity=.75,surface_coupling=0.,q_coupling=1.,poisson=.3)
                        if cfg.get('version')=='valley_onset_v2_five_conditions' and cfg.get('input_versions')==versions and all(cfg.get(k)==v for k,v in expected.items()):
                            import hashlib
                            models={name:dict(coordinates=pd.read_csv(source/f'{name}_coordinates.csv'),metadata=json.loads((source/f'{name}_model.json').read_text())) for name in MODEL_NAMES}
                            prediction=dict(models=models,configuration=cfg,config_id=hashlib.sha256(json.dumps(cfg,sort_keys=True).encode()).hexdigest()[:12])
                    if prediction is None:prediction=predict_onset_models(orientation,mesh,rho=r.rho)
                    configuration=prediction['configuration']
                    (target/'configuration.json').write_text(json.dumps(configuration,indent=2)+'\n')
                    for name in MODEL_NAMES:
                        prediction['models'][name]['coordinates'].to_csv(target/f'{name}_coordinates.csv',index=False)
                        (target/f'{name}_model.json').write_text(json.dumps(prediction['models'][name]['metadata'],indent=2)+'\n')
                    result=evaluate_onset(prediction,_read_height(r.path),mesh)
                    for key in ['transitions','transition_grains','transition_origins','bottom_lines','bottom_line_support','reference_bottom_grains','local_lowness','origins','origin_nodes','origin_support','origin_flags','taylor_factors','taylor_boundary_segments','taylor_boundaries','taylor_origin_boundary','taylor_boundary_metrics','union_metrics','union_origin_flags']:result[key].to_csv(target/(key+'.csv'),index=False)
                    result['centroids'].to_csv(target/'centroids.csv',index=False)
                    result['thresholds'].to_csv(target/'thresholds.csv',index=False)
                    result['planes'].to_csv(target/'planes.csv',index=False)
                    (target/'method.json').write_text(json.dumps(result['metadata'],indent=2)+'\n')
                    rows=result['metrics'].assign(case_id=case,config_id=prediction['config_id'],rho=r.rho,texture=r.texture,seed=r.seed,sd=r.sd)
                    meta=prediction['models']['equilibrium']['metadata']
                    rows['equilibrium_geometry_valid']=meta['finite_geometry_valid']
                    rows['equilibrium_inverted_elements']=meta['inverted_deformed_elements']
                    diag=prediction['models']['equilibrium_diagonal']['metadata']
                    rows['diagonal_geometry_valid']=diag['finite_geometry_valid']
                    rows['diagonal_inverted_elements']=diag['inverted_deformed_elements']
                    rows.to_csv(metrics_path,index=False)
                allrows.append(rows)
                print(f'[{i+1}/{len(records)}] {case}',flush=True)
            except (ValueError,KeyError,OSError) as error:
                failures.append(dict(case_id=case,error=str(error)));print(f'FAILED {case}: {error}',flush=True)
        if not allrows:raise RuntimeError('No evaluation rows')
        allmetrics=pd.concat(allrows,ignore_index=True)
        allmetrics.to_csv(root/'all_threshold_metrics.csv',index=False,encoding='utf-8-sig')
        pd.DataFrame(failures,columns=['case_id','error']).to_csv(root/'failures.csv',index=False)
    else:allmetrics=pd.read_csv(root/'all_threshold_metrics.csv')
    data=allmetrics[(allmetrics.level=='grain')&np.isclose(allmetrics.threshold_factor,1.)&(allmetrics.feature=='valley')].copy()
    if set(data.model)!=set(MODEL_NAMES):raise ValueError('Saved evaluation model set differs from the current five-condition design; recompute evaluations')
    data['state']=2
    if data.duplicated(['case_id','model','feature']).any():raise ValueError('Duplicate case metrics')
    data.to_csv(root/'case_metrics.csv',index=False,encoding='utf-8-sig')
    scores=data[['case_id','state','rho','texture','seed','sd','model','origin_count','hit_origin_count','origin_recall','precision','recall','f1']].copy()
    scores.to_csv(root/'scores.csv',index=False,encoding='utf-8-sig')
    for model in MODEL_NAMES:
        scores[scores.model==model].to_csv(root/f'{model}_scores.csv',index=False,encoding='utf-8-sig')
    for model in MODEL_NAMES:
        data[data.model==model].to_csv(root/f'{model}_case_metrics.csv',index=False,encoding='utf-8-sig')
    summary=draw_plots(data,root);draw_individual(data,root); summary.to_csv(root/'boxplot_statistics.csv',index=False,encoding='utf-8-sig')
    for model in MODEL_NAMES:
        wide=summary[summary.model==model].pivot(index=['rho','feature','texture'],columns='metric',values=['n_cases','n_valid','n_undefined','median','q1','q3','minimum','maximum'])
        wide.columns=[f'{metric}_{statistic}' for statistic,metric in wide.columns]
        wide.reset_index().to_csv(root/f'{model}_boxplot_statistics.csv',index=False,encoding='utf-8-sig')
    union_rows=[]
    for directory in sorted(cache.iterdir()):
        path=directory/'union_metrics.csv'
        if path.exists():union_rows.append(pd.read_csv(path).assign(case_id=directory.name))
    if union_rows:pd.concat(union_rows,ignore_index=True).to_csv(root/'union_metrics.csv',index=False,encoding='utf-8-sig')
    coverage=data[['rho','texture','case_id']].drop_duplicates().groupby(['rho','texture']).size().rename('cases').reset_index()
    coverage.to_csv(root/'coverage.csv',index=False,encoding='utf-8-sig')
    (root/'README.md').write_text(f'''# state02の谷粒検出精度：texture別箱ひげ図

対象：state02の{data.case_id.nunique()}ケース。5条件（自粒ND、周囲との差、D＋Q、3D対角、3D全成分）。
主対象は谷。各モデル・ひずみ比ごとに1パネルの個別PNG/PDFを出力し、起点捕捉率と補助の粒Precision・粒F1を同じパネル内にまとめる（単位の違いを凡例で明記）。overviewは5条件を2行3列で表示。
各標本は1ケース（seed・方位ばらつきsdの組合せ）。閾値倍率の違いは標本に混ぜない。
実測は局所谷底線を正の長さで含む粒、予測は隣接粒の局所平面より低い粒を検出。主評価の低さ下限は局所低さRMSの0.5倍で、0.5・1・2倍も保存する。実測の線抽出条件はモデル間で固定。
予測値・検出閾値はCPFEMに合わせて調整しない。

箱：25–75百分位、線：中央値、ひげ：1.5IQR以内の端の観測値。点：全ケース（外れ値も表示）。横軸のnはモデル共通の対象ケース数（未定義を含む）。
未定義値は0に置換せず箱ひげから除く。件数と未定義数はboxplot_statistics.csvに記載。
seedとsdは制御された条件であり、点を独立な無作為標本とみなす検定や信頼区間は作成していない。
全ケースを同じ規則で収録し、小変形適用範囲外のモデルも除外していない。幾何妥当性フラグをcase_metrics.csvに保存。
モデル条件：m=.05、指定ひずみ=.01（state02から取得しない）、ばらつき保持率=.75、Poisson=.3。縮約3条件すべて表面伝達結合λ=0。D＋QだけQ拘束γ=1。3D対角と全成分は同じ境界・初期応答で固有せん断成分のみを切り替える。
無作為比較は行わない。後続stateの成長・合体は対象外。
scores.csvとモデル別の *_scores.csv はケース条件と起点数・捕捉数・起点捕捉率と補助の粒スコアを含む表。
モデル別の *_case_metrics.csv は検出数・閾値なども含む詳細表。
case_metrics.csv：描画元のケース別精度。boxplot_statistics.csv：箱の統計。all_threshold_metrics.csv：閾値感度を含む全評価。
case_data/：各ケースの予測座標・平面・重心・自動閾値・モデル条件・因子別の粒ID変化を保存。
ZIPには図・集計CSVを収録。全ケースの予測座標など大容量のcase_data/は出力フォルダ内に別途保存する。
''')
    archive=root.parent/(root.name+'.zip')
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for path in sorted(root.rglob('*')):
            if path.is_file() and 'case_data' not in path.relative_to(root).parts:z.write(path,path.relative_to(root))
    print(f'Completed: {len(data)} rows; {root}; {archive}',flush=True)
    return int(bool(failures))


if __name__=='__main__':raise SystemExit(main())
