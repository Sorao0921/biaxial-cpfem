"""Initial-only three-model centroid detection: all cases and texture boxplots."""
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
from src.theme1.initial_fourway import MODEL_NAMES,predict_three_models,evaluate_three_models
from src.theme1.contribution import _read_height
from src.theme1.valley_evaluation import valley_tables

TEXTURES=('brass','copper','s','cube','goss')
NAMES={'k_only':'A: K only','d_q':'B: D + Q','equilibrium':'C: 3D equilibrium'}
COLORS={'precision':'#377ca8','recall':'#d99730','f1':'#a35e89'}
METRICS={'precision':'Precision','recall':'Recall','f1':'F1 score'}


def draw_plots(data,root):
    summaries=[]
    book=PdfPages(root/'all_boxplots.pdf')
    for (rho,feature),frame in data.groupby(['rho','feature'],sort=True):
        fig,axes=plt.subplots(1,3,figsize=(17,5.8))
        fig.subplots_adjust(left=.055,right=.985,bottom=.24,top=.86,wspace=.25)
        fig.suptitle(f'{feature.capitalize()} grain detection | strain ratio rho = {rho:g}',fontsize=16)
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
        handles=[plt.Line2D([],[],marker='s',linestyle='',color=COLORS[m],label=label) for m,label in METRICS.items()]
        fig.legend(handles=handles,loc='lower center',bbox_to_anchor=(.5,.07),ncol=3,frameon=False)
        fig.supxlabel('Texture | one point = one case (seed, orientation spread); whiskers = 1.5 IQR',fontsize=10,y=.025)
        stem=root/f'rho_{rho:g}_{feature}_precision_recall_f1'
        fig.savefig(Path(str(stem)+'.png'),dpi=200,facecolor='white')
        fig.savefig(Path(str(stem)+'.pdf'),facecolor='white');book.savefig(fig,facecolor='white');plt.close(fig)
        frame.to_csv(root/f'rho_{rho:g}_{feature}_case_metrics.csv',index=False,encoding='utf-8-sig')
        for model in MODEL_NAMES:
            frame[frame.model==model].to_csv(root/f'{model}_rho_{rho:g}_{feature}_case_metrics.csv',index=False,encoding='utf-8-sig')
    book.close()
    return pd.DataFrame(summaries)


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir',type=Path,default=PROJECT_ROOT/'output/reports/centroid_detection_boxplots')
    parser.add_argument('--plots-only',action='store_true')
    args=parser.parse_args(argv);root=args.output_dir;root.mkdir(parents=True,exist_ok=True)
    cache=root/'case_data';cache.mkdir(exist_ok=True)
    records=filter_records(scan_outputs(OUTPUTS_DIR),kind='height',state=13)
    records=sorted(records,key=lambda r:(r.seed,r.rho,r.texture,r.sd))
    allrows=[];failures=[]
    if not args.plots_only:
        for i,r in enumerate(records):
            case=f'rho_{r.rho:g}_{r.texture}_sd{r.sd}_seed{r.seed}_state13';target=cache/case;target.mkdir(exist_ok=True)
            try:
                metrics_path=target/'metrics.csv'
                if metrics_path.exists():
                    rows=pd.read_csv(metrics_path)
                else:
                    mesh=SPATIAL_MODELS_DIR/f'seed{r.seed}'
                    orientation=PROJECT_ROOT/'inputs/orientation'/f'texture_seed{r.seed}'/f'{r.texture}_sigma{r.sd}_seed{r.seed}.csv'
                    # Prediction is complete before opening the reference height.
                    prediction=predict_three_models(orientation,mesh,rho=r.rho)
                    configuration=prediction['configuration']
                    (target/'configuration.json').write_text(json.dumps(configuration,indent=2)+'\n')
                    for name in MODEL_NAMES:
                        prediction['models'][name]['coordinates'].to_csv(target/f'{name}_coordinates.csv',index=False)
                    evaluation=evaluate_three_models(prediction,_read_height(r.path))
                    result=valley_tables(evaluation['selected'],mesh,threshold_factors=(.5,1.,2.))
                    result['centroids'].to_csv(target/'centroids.csv',index=False)
                    result['thresholds'].to_csv(target/'thresholds.csv',index=False)
                    result['planes'].to_csv(target/'planes.csv',index=False)
                    (target/'method.json').write_text(json.dumps(result['metadata'],indent=2)+'\n')
                    rows=result['metrics'].assign(case_id=case,config_id=prediction['config_id'],rho=r.rho,texture=r.texture,seed=r.seed,sd=r.sd)
                    meta=prediction['models']['equilibrium']['metadata']
                    rows['equilibrium_geometry_valid']=meta['finite_geometry_valid']
                    rows['equilibrium_inverted_elements']=meta['inverted_deformed_elements']
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
    data=allmetrics[(allmetrics.level=='grain')&np.isclose(allmetrics.threshold_factor,1.)].copy()
    if data.duplicated(['case_id','model','feature']).any():raise ValueError('Duplicate case metrics')
    data.to_csv(root/'case_metrics.csv',index=False,encoding='utf-8-sig')
    for model in MODEL_NAMES:
        data[data.model==model].to_csv(root/f'{model}_case_metrics.csv',index=False,encoding='utf-8-sig')
    summary=draw_plots(data,root);summary.to_csv(root/'boxplot_statistics.csv',index=False,encoding='utf-8-sig')
    for model in MODEL_NAMES:
        wide=summary[summary.model==model].pivot(index=['rho','feature','texture'],columns='metric',values=['n_cases','n_valid','n_undefined','median','q1','q3','minimum','maximum'])
        wide.columns=[f'{metric}_{statistic}' for statistic,metric in wide.columns]
        wide.reset_index().to_csv(root/f'{model}_boxplot_statistics.csv',index=False,encoding='utf-8-sig')
    coverage=data[['rho','texture','case_id']].drop_duplicates().groupby(['rho','texture']).size().rename('cases').reset_index()
    coverage.to_csv(root/'coverage.csv',index=False,encoding='utf-8-sig')
    (root/'README.md').write_text(f'''# 山・谷の粒検出精度：texture別箱ひげ図

対象：state13の{data.case_id.nunique()}ケース。モデルはKのみ、D/Q、3D平衡。
山と谷を別々に、ひずみ比ごとにK・D/Q・3Dを3パネルで表示し、各パネル内でPrecision・Recall・F1を色分けする。
各標本は1ケース（seed・方位ばらつきsdの組合せ）。閾値倍率の違いは標本に混ぜない。
独立な最小二乗平面と現在の粒表面面積重心から符号付き距離を求め、各場の粒距離RMSの1倍を閾値とする。
予測値・検出閾値はCPFEMに合わせて調整しない。

箱：25–75百分位、線：中央値、ひげ：1.5IQR以内の端の観測値。点：全ケース（外れ値も表示）。横軸のnはモデル共通の対象ケース数（未定義を含む）。
未定義値は0に置換せず箱ひげから除く。件数と未定義数はboxplot_statistics.csvに記載。
seedとsdは制御された条件であり、点を独立な無作為標本とみなす検定や信頼区間は作成していない。
全ケースを同じ規則で収録し、小変形適用範囲外のモデルも除外していない。幾何妥当性フラグをcase_metrics.csvに保存。
モデル条件：m=.05、指定ひずみ=.1、ばらつき保持率=.75、表面結合=1、Q結合=1、Poisson=.3。
モデル別の *_case_metrics.csv はPrecision・Recall・F1を同じ表の列にまとめる。
case_metrics.csv：描画元のケース別精度。boxplot_statistics.csv：箱の統計。all_threshold_metrics.csv：閾値感度を含む全評価。
case_data/：各ケースの予測座標・平面・重心・自動閾値・モデル条件を保存。
''')
    archive=root.parent/(root.name+'.zip')
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for path in sorted(root.iterdir()):
            if path.is_file():z.write(path,path.name)
    print(f'Completed: {len(data)} rows; {root}; {archive}',flush=True)
    return int(bool(failures))


if __name__=='__main__':raise SystemExit(main())
