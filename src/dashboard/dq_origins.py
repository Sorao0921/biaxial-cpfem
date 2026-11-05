"""Per-case D+Q origin history and seed-wise final capture comparisons."""
import io
import json
import zipfile
from pathlib import Path
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
from matplotlib.ticker import MaxNLocator
import numpy as np
import pandas as pd
import streamlit as st
from src.config.case_selection import CATALOG_SD_LEVELS
from src.config.pipeline_paths import OUTPUTS_DIR, PROJECT_ROOT, build_spatial_model_dir, build_post_directories
from src.dashboard.catalog import scan_outputs, filter_records
from src.dashboard.theme1_bands import attach_equivalent_strain
from src.dashboard.initial_prediction import coordinate_height_figure, indicator_color_limits
from src.theme1.contribution import _read_height
from src.theme1.dq_origins import VERSION, predict_dq, track_dq, track_dq_peaks, project_reference_to_prediction

CAPTURED='#3575AB'
MISSED='#a9cbe3'
FEATURE_STYLES={'valley':dict(label='Valley',line='#00cdd4',linestyle='solid',marker='*',captured='#2166ac',missed='#a9cbe3',cmap='Blues'),
                'peak':dict(label='Peak',line='#ff941f',linestyle='dashed',marker='^',captured='#b2182b',missed='#f4b9b3',cmap='Reds')}
END_STATE=12
TEXTURES=('brass','copper','cube','goss','s')


def history_figure(counts, title, *, cumulative=True,feature='valley'):
    fig,ax=plt.subplots(figsize=(11,4.8),layout='constrained')
    style=FEATURE_STYLES[feature]
    displayed=counts.copy()
    if cumulative:
        for name in ('captured','missed','total'):
            displayed[name]=counts['cumulative_'+name]
    x=counts.eps_eq.to_numpy(float)
    if not np.isfinite(x).all() or (np.diff(x)<=0).any():
        raise ValueError("相当塑性ひずみは有限かつstate順に増加する値が必要です。")
    gaps=np.diff(x)
    widths=.7*np.minimum(np.r_[gaps[0],gaps],np.r_[gaps,gaps[-1]]) if len(x)>1 else np.array([.005])
    ax.bar(x,displayed.captured,color=style['captured'],label='Captured',width=widths)
    ax.bar(x,displayed.missed,bottom=displayed.captured,color=style['missed'],hatch='//',label='Missed',width=widths)
    label_floor=max(1,displayed.total.max())*.08
    for r in displayed.itertuples():
        if r.captured>=label_floor:ax.text(r.eps_eq,r.captured/2,str(int(r.captured)),ha='center',va='center',color='white')
        if r.missed>=label_floor:ax.text(r.eps_eq,r.captured+r.missed/2,str(int(r.missed)),ha='center',va='center')
        if 0<r.total<label_floor*2:ax.annotate(str(int(r.total)),(r.eps_eq,r.total),xytext=(0,4),textcoords='offset points',ha='center',va='bottom')
    ax.set(xlabel=r'Equivalent plastic strain $\varepsilon_{eq}^{p}$ (–)',
           ylabel='Cumulative origin count' if cumulative else 'New origin count',title=title)
    ax.ticklabel_format(axis='x',style='plain',useOffset=False)
    ax.set_ylim(0,max(1,displayed.total.max())*1.18)
    ax.yaxis.set_major_locator(MaxNLocator(integer=True));ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True)
    right=ax.twinx()
    right.plot(x,counts.cumulative_capture_rate*100,color=style['captured'],marker='o' if feature=='valley' else '^',linestyle='-' if feature=='valley' else '--',label='Cumulative capture rate')
    right.set(ylabel='Cumulative capture rate (%)',ylim=(0,105))
    handles,labels=ax.get_legend_handles_labels();h,l=right.get_legend_handles_labels()
    fig.legend(handles+h,labels+l,loc='outside lower center',ncol=3,frameon=False)
    return fig


def add_prediction_reference_overlay(figure, lines, origins, counts, *, feature='valley', legend=True):
    """Reference features mapped by node ID; feature shape and strain color are explicit."""
    ax=figure.axes[0];style=FEATURE_STYLES[feature]
    strains=counts.set_index('state').eps_eq
    if len(lines):
        ax.add_collection(LineCollection(lines[['predicted_x_a','predicted_y_a','predicted_x_b','predicted_y_b']].to_numpy().reshape(-1,2,2),
            colors=style['line'],linestyles=style['linestyle'],linewidths=1.1,zorder=7,label=style['label']+' line (initial)'))
    palette=plt.get_cmap(style['cmap'])
    for state,points in origins.groupby('state',sort=True):
        ax.scatter(points.predicted_x,points.predicted_y,c=[palette(.35+.6*(int(state)-2)/(END_STATE-2))],
            s=42,marker=style['marker'],edgecolors='black',linewidths=.4,zorder=9,
            label=f"{style['label']} {strains.loc[state]:.4f} ({len(points)})")
    if legend:
        handles,labels=ax.get_legend_handles_labels()
        if handles:figure.legend(handles,labels,loc='outside lower center',ncol=4,fontsize=6,frameon=False,
                                 title=r'First appearance: $\varepsilon_{eq}^{p}$ (origin count)',title_fontsize=8)


def add_observed_features(figure, history, state, feature):
    ax=figure.axes[0];style=FEATURE_STYLES[feature]
    lines=history['lines'].query('state==@state')
    if len(lines):ax.add_collection(LineCollection(lines[['x_a','y_a','x_b','y_b']].to_numpy().reshape(-1,2,2),
        colors=style['line'],linestyles=style['linestyle'],linewidths=1,label=style['label']+' line'))
    points=history['origins'].query('state==@state');old=points[~points.is_event]
    ax.scatter(old.x,old.y,facecolors='none',edgecolors=style['captured'],s=18,marker=style['marker'],linewidths=.7,zorder=8,label=style['label']+' existing')
    for captured in (True,False):
        part=points[points.is_event & points.captured.eq(captured)]
        ax.scatter(part.x,part.y,c=style['captured'] if captured else style['missed'],s=45,marker=style['marker'],
            edgecolors='black',linewidths=.4,zorder=9,label=style['label']+(' captured' if captured else ' missed'))


def initial_capture_summary(counts):
    row=counts.loc[counts.state.eq(2)].iloc[0]
    return dict(state=2,eps_eq=float(row.eps_eq),initial_origin_count=int(row.total),
        initial_captured=int(row.captured),initial_missed=int(row.missed),
        initial_capture_rate=float(row.captured/row.total) if row.total else np.nan)


def initial_score_summary(result):
    row=result['detection']['metrics'].query("model=='d_q' and threshold_factor==1").iloc[0]
    keys=('predicted_count',
          'excluded_no_neighbors','predicted_area_fraction','capture_per_area')
    return {**initial_capture_summary(result['counts']),**{k:row[k] for k in keys}}


def initial_figure(table,metric='initial_capture_rate',metric_label='Initial capture'):
    seeds=sorted(table.seed.unique());sds=sorted(table.sd.unique());rhos=sorted(table.rho.unique())
    colors=plt.get_cmap('tab10');markers=('o','s','^','D','v','P','X','<','>')
    fig,axes=plt.subplots(len(seeds),len(TEXTURES),squeeze=False,
        figsize=(20,3.8*len(seeds)+.5),layout='constrained',sharex=True,sharey=True)
    for row,seed in enumerate(seeds):
        for column,texture in enumerate(TEXTURES):
            ax=axes[row,column]
            for j,rho in enumerate(rhos):
                rows=table[(table.seed==seed)&(table.texture==texture)&(table.rho==rho)].sort_values('sd')
                ax.scatter(rows.sd,rows[metric]*(1 if metric=='capture_per_area' else 100),label=f'rho={rho:g}',
                    color=colors(j%10),marker=markers[j%len(markers)],s=65,alpha=.8,
                    edgecolors='white',linewidths=.6)
            ax.set(title=f'{texture.capitalize()} | seed {seed}',xlabel='sd')
            if metric!='capture_per_area':ax.set_ylim(-3,103)
            else:ax.set_ylim(bottom=0)
            if column==0:ax.set_ylabel(metric_label+(' (ratio)' if metric=='capture_per_area' else ' (%)'))
            ax.set_xticks(sds);ax.grid(axis='y',alpha=.2)
    handles,labels=axes[0,0].get_legend_handles_labels()
    fig.legend(handles,labels,loc='outside lower center',ncol=min(5,len(rhos)),frameon=False)
    fig.suptitle('D + Q | '+metric_label+' (state02)')
    return fig


def case_sources(records):
    result={}
    for r in records:
        if r.state>=2:result.setdefault((r.seed,r.texture,r.sd),{})[r.state]=r.path
    return {k:v for k,v in result.items() if 2 in v}


def signature(paths, orientation, mesh):
    return tuple((str(p),p.stat().st_mtime_ns,p.stat().st_size) for p in
                 [orientation,mesh/'nodes.csv',mesh/'elements.csv',*paths.values()])


@st.cache_data(show_spinner=False,max_entries=256)
def calculate_case(rho,seed,texture,sd,sources,stamp,version=VERSION):
    mesh=build_spatial_model_dir(int(seed))
    orientation=PROJECT_ROOT/'inputs/orientation'/f'texture_seed{seed}'/f'{texture}_sigma{sd}_seed{seed}.csv'
    prediction=predict_dq(orientation,mesh,rho)
    heights={state:_read_height(Path(path)) for state,path in sources}
    result=track_dq(prediction,heights,mesh)
    result['peak']=track_dq_peaks(prediction,heights,mesh)
    result['metadata']['sources']=stamp
    result['peak']['metadata']['sources']=stamp
    return result


def run_case(rho,key,paths,end):
    seed,texture,sd=key;mesh=build_spatial_model_dir(int(seed))
    orientation=PROJECT_ROOT/'inputs/orientation'/f'texture_seed{seed}'/f'{texture}_sigma{sd}_seed{seed}.csv'
    if end>END_STATE:raise ValueError('評価終了はstate12です。')
    missing=[s for s in range(2,end+1) if s not in paths]
    if missing:raise ValueError(f'state02〜{end:02d}のデータが不足しています: {missing}')
    selected={s:paths[s] for s in range(2,end+1)}
    result=calculate_case(float(rho),int(seed),texture,int(sd),tuple((s,str(p)) for s,p in selected.items()),signature(selected,orientation,mesh))
    result['counts']=attach_equivalent_strain(result['counts'].assign(rho=float(rho),seed=int(seed)))
    result['peak']['counts']=attach_equivalent_strain(result['peak']['counts'].assign(rho=float(rho),seed=int(seed)))
    strain_path=build_post_directories(float(rho),int(seed)).equivalent_strain_csv
    result['metadata']['strain_axis']={'source':str(strain_path),'column':'eps_eq','first_data_row_state':1,
                                     'mtime_ns':strain_path.stat().st_mtime_ns}
    result['peak']['metadata']['strain_axis']=result['metadata']['strain_axis']
    return result


def show_plot(fig,name):
    st.pyplot(fig,width='stretch')
    stream=io.BytesIO();fig.savefig(stream,format='png',dpi=160,bbox_inches='tight');plt.close(fig)
    st.download_button('PNGを保存',stream.getvalue(),file_name=name+'.png',mime='image/png',key=name)


def render_dq_origins():
    st.header('D＋Q：起点の追加捕捉')
    records=filter_records(scan_outputs(OUTPUTS_DIR),kind='height')
    if not records:st.info('高さデータがありません。');return
    rho=st.selectbox('rho',sorted({r.rho for r in records}),key='dq-rho')
    cases=case_sources([r for r in records if r.rho==rho])
    if not cases:st.info('state02のデータがありません。');return
    keys=list(cases)
    for column,index,label in zip(st.columns(3),range(3),('seed','texture','sd')):
        with column:value=st.selectbox(label,sorted({k[index] for k in keys}),key='dq-'+label)
        keys=[k for k in keys if k[index]==value]
    key=keys[0];paths=cases[key]
    end=END_STATE
    st.caption('評価範囲：state02〜state12（固定）')
    st.caption('state02の初期起点と、各stateで初めて検出された起点を数えます。累積捕捉率＝捕捉した初期・新規起点の累計／初期・新規起点の総数。D＋Qの予測粒は固定です。')
    try:
        with st.spinner('D＋Qの予測と各stateの新規起点を照合しています…'):result=run_case(rho,key,paths,end)
    except (ValueError,OSError,KeyError) as exc:st.error(str(exc));return
    initial_rows=[]
    for feature,history in [('valley',result),('peak',result['peak'])]:
        initial_rows.append({'feature':feature,**initial_score_summary(history)})
    st.dataframe(pd.DataFrame(initial_rows),hide_index=True,width='stretch')
    st.caption('谷・山とも初期の予測領域を固定。面積当たり捕捉効率＝起点捕捉率÷予測面積率。統計的な信頼確率ではありません。')
    case=f'rho{rho:g}_{key[1]}_sd{key[2]}_seed{key[0]}'
    bar_mode=st.radio('棒グラフの表示', ['累積起点数', 'stateごとの追加起点数'], horizontal=True, key='dq-count-mode')
    cumulative=bar_mode=='累積起点数'
    for column,(feature,history) in zip(st.columns(2),[('valley',result),('peak',result['peak'])]):
        with column:
            show_plot(history_figure(history['counts'],FEATURE_STYLES[feature]['label']+' origins | '+case,cumulative=cumulative,feature=feature),case+'_'+feature+('_cumulative' if cumulative else '_new_origins'))
    st.caption('横軸は相当塑性ひずみ。谷は青系、山は赤系。下側＝捕捉、上側の薄色・斜線＝未捕捉、折れ線＝累積捕捉率。消失した起点も初出時の判定を保持し、新規起点のみ追加します。')
    st.dataframe(pd.concat([result['counts'].assign(feature='valley'),result['peak']['counts'].assign(feature='peak')],ignore_index=True),hide_index=True,width='stretch')
    st.subheader('D＋Q予測と各state：谷・山別に表示')
    mesh=build_spatial_model_dir(key[0])
    histories={'valley':result,'peak':result['peak']}
    projected={feature:project_reference_to_prediction(result['prediction'],h['lines'],h['origins']) for feature,h in histories.items()}
    maps=[('D + Q + reference features',result['prediction'],None)]+[(f'CPFEM state{s:02d}',_read_height(paths[s]),s) for s in range(2,end+1)]
    for feature,h in histories.items():
        st.subheader('谷：谷底線・谷起点' if feature=='valley' else '山：稜線・山起点')
        for start in range(0,len(maps),4):
            columns=st.columns(4)
            for column,(title,height,state) in zip(columns,maps[start:start+4]):
                fig=coordinate_height_figure(height,mesh,title=title+' / '+FEATURE_STYLES[feature]['label'],value_range=indicator_color_limits(height.z.to_numpy()*1000,robust=True))
                fig.axes[0].title.set_fontsize(12)
                if state is None:
                    lines,origins=projected[feature]
                    add_prediction_reference_overlay(fig,lines,origins,h['counts'],feature=feature)
                else:
                    add_observed_features(fig,h,state,feature)
                    handles,labels=fig.axes[0].get_legend_handles_labels()
                    fig.legend(handles,labels,loc='outside lower center',ncol=2,fontsize=7,frameon=False)
                column.pyplot(fig,width='stretch')
                png=io.BytesIO();fig.savefig(png,format='png',dpi=180,bbox_inches='tight')
                column.download_button('谷マップPNG' if feature=='valley' else '山マップPNG',png.getvalue(),file_name=case+('_prediction' if state is None else f'_state{state:02d}')+'_'+feature+'.png',mime='image/png',key=f'dq-overlay-{feature}-{state}')
                plt.close(fig)
    st.caption('谷底線＝水色実線、谷起点＝星。稜線＝橙破線、山起点＝三角。実測図は濃色＝新規捕捉、薄色＝新規未捕捉、白抜き＝既存起点。予測図の起点色は初出の相当塑性ひずみを示します。')
    st.caption('D＋Q図上の線はstate02実測の谷底線・稜線を同じ節点IDで転写したものです。起点も実測の初出座標を節点IDで写しています。予測高さ場から独立に抽出した線ではありません。')
    stream=io.BytesIO()
    with zipfile.ZipFile(stream,'w',zipfile.ZIP_DEFLATED) as z:
        z.writestr('prediction.csv',result['prediction'].to_csv(index=False))
        for feature,h in histories.items():
            for name in ('counts','origins','lines','flags'):
                z.writestr(feature+'/'+name+'.csv',h[name].to_csv(index=False))
            for name in ('boundary_origins','reference_bottom_grains','metrics'):
                z.writestr(feature+'/state02_'+name+'.csv',h['detection'][name].to_csv(index=False))
            z.writestr(feature+'/projected_state02_lines.csv',projected[feature][0].to_csv(index=False))
            z.writestr(feature+'/projected_origin_events.csv',projected[feature][1].to_csv(index=False))
            z.writestr(feature+'/method.json',json.dumps(h['metadata'],ensure_ascii=False,indent=2))
    st.download_button('谷・山の集計・座標CSVを保存',stream.getvalue(),file_name=case+'_valley_peak_state02-12.zip',mime='application/zip')
    st.subheader('全ケース：起点捕捉率・予測面積率・捕捉効率')
    st.caption('初期捕捉率＝state02で捕捉した起点数／state02の全起点数。横軸はsd、色・記号はrho、各点は1ケースです。')
    if st.button('全rho・texture・sd・seedを集計',key='dq-batch'):
        all_cases=[(r,k,p) for r in sorted({record.rho for record in records})
                   for k,p in sorted(case_sources([record for record in records if record.rho==r]).items())]
        rows=[];errors=[];progress=st.progress(0.)
        for i,(case_rho,k,p) in enumerate(all_cases):
            try:
                r=run_case(case_rho,k,p,2)
                for feature,h in [('valley',r),('peak',r['peak'])]:
                    rows.append({**initial_score_summary(h),'feature':feature,'rho':case_rho,'seed':k[0],'texture':k[1],'sd':k[2]})
            except (ValueError,OSError,KeyError) as exc:errors.append(f'rho={case_rho:g}, {k}: {exc}')
            progress.progress((i+1)/len(all_cases),text=f'{i+1}/{len(all_cases)} ケース')
        st.session_state['dq-initial-all-rho-v8-dual']=(pd.DataFrame(rows),errors)
    saved=st.session_state.get('dq-initial-all-rho-v8-dual')
    if saved is not None:
        table,errors=saved
        if len(table):table=table[table.sd.isin(CATALOG_SD_LEVELS)].copy()
        if errors:st.warning(f'{len(errors)}ケースは欠損等で除外しました。');st.write(errors)
        if len(table):
            choices={'起点捕捉率（起点数）':('initial_capture_rate','Initial origin capture')}
            choices.update({'予測面積率':('predicted_area_fraction','Predicted area fraction'),
                            '面積当たり捕捉効率':('capture_per_area','Capture per area')})
            selected=st.selectbox('全ケース散布図の評価指標',list(choices),key='dq-batch-score')
            metric,label=choices[selected]
            for feature in ('valley','peak'):
                show_plot(initial_figure(table[table.feature.eq(feature)],metric,FEATURE_STYLES[feature]['label']+' / '+label),'dq_initial_all_rho_state02_'+feature+'_'+metric)
            st.dataframe(table,hide_index=True,width='stretch')
            st.download_button('起点捕捉率・予測面積率・捕捉効率CSVを保存',table.to_csv(index=False).encode('utf-8-sig'),file_name='dq_initial_all_rho_state02.csv',mime='text/csv')
            if table.initial_capture_rate.isna().any():st.info('起点総数が0のケースは捕捉率未定義のため、散布図に点を表示しません。')
