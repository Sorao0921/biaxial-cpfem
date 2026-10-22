"""Deep-valley detection diagnostics, independent of prediction generation."""
import io
import json
import zipfile
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection,LineCollection
from matplotlib.colors import ListedColormap,BoundaryNorm
from matplotlib.patches import Patch
from src.theme1.valley_evaluation import valley_tables,fft_scale_table,_surface
from src.theme1.initial_fourway import MODEL_NAMES,LABELS
from src.dashboard.export import combine_map_pngs
from src.dashboard.plots import surface_topology

COLORS=['#f0f2f4','#23965f','#e79d19','#397dcc','#999999']
CODES={'TN':0,'TP':1,'FP':2,'FN':3,'EXCLUDED':4}


def valley_figures(result,model_dir,*,level='grain',feature='valley',threshold_factor=1.,model_names=None,labels=None):
    model_names=MODEL_NAMES if model_names is None else tuple(model_names)
    labels=LABELS if labels is None else labels
    top,geometry,faces=_surface(model_dir)
    ids=result['node_heights'].node_id.to_numpy(int)
    keep=np.all(np.isin(faces,ids),axis=1)
    xy=top[['x','y']].to_numpy(float);polygons=xy[faces[keep]-1]
    visible=set(ids);boundaries=surface_topology(model_dir)[3]
    segments=[xy[[a-1,b-1]] for a,b in boundaries if a in visible and b in visible]
    flags=result['flags'];flags=flags[(flags.level==level)&(flags.feature==feature)&np.isclose(flags.threshold_factor,threshold_factor)]
    metrics=result['metrics'];metrics=metrics[(metrics.level==level)&(metrics.feature==feature)&np.isclose(metrics.threshold_factor,threshold_factor)].set_index('model')
    cmap=ListedColormap(COLORS);norm=BoundaryNorm(np.arange(-.5,5.5),cmap.N)
    figures=[]
    for name in (*model_names,'cpfem'):
        f=flags[flags.model==(name if name!='cpfem' else model_names[0])].set_index('item_id')
        codes=f.outcome.map(CODES) if name!='cpfem' else f.reference_feature.astype(int)*3
        fig,ax=plt.subplots(figsize=(5.2,4.5),layout='constrained')
        if level=='grain':
            values=codes.loc[geometry.loc[keep].part_id].to_numpy(int)
            ax.add_collection(PolyCollection(polygons,array=values,cmap=cmap,norm=norm,edgecolors='none'))
            ax.add_collection(LineCollection(segments,colors='#555555',linewidths=.25))
            ax.autoscale_view()
        else:
            values=codes.loc[ids].to_numpy(int)
            ax.scatter(xy[ids-1,0],xy[ids-1,1],c=values,cmap=cmap,norm=norm,s=3,marker='s',linewidths=0)
        title=labels[name].split(' (')[0]+(f'\n{feature.capitalize()} | origin support | ' if result['metadata'].get('method_version') in ('bottom_line_supported_grains_v1','blue_bottom_line_supported_grains_v2','strict_blue_bottom_line_supported_grains_v3','local_valley_origins_v4') else f'\n{feature.capitalize()} | own automatic cutoff | ')+('grains' if level=='grain' else 'surface nodes')
        if name!='cpfem':
            row=metrics.loc[name]
            title+=(f'\nOrigin recall={row.origin_recall:.2f}' if 'origin_recall' in row.index else f'\nRecall={row.recall:.2f}, Precision={row.precision:.2f}')
        else:title+=('\nObserved local origins' if result['metadata'].get('method_version')=='local_valley_origins_v4' else f'\nCPFEM target {feature}s')
        ax.set(title=title,xlabel='Initial x',ylabel='Initial y',aspect='equal');ax.margins(0)
        ax.title.set_fontsize(12);ax.tick_params(labelsize=9)
        handles=[Patch(facecolor=COLORS[k],label=label) for k,label in [(1,'Hit (TP)'),(2,'No bottom support (FP)' if result['metadata'].get('method_version') in ('bottom_line_supported_grains_v1','blue_bottom_line_supported_grains_v2','strict_blue_bottom_line_supported_grains_v3','local_valley_origins_v4') else 'False alarm (FP)'),(3,'Miss / target (FN)')]]
        ax.legend(handles=handles,loc='upper center',bbox_to_anchor=(.5,-.13),ncol=3,fontsize=8,frameon=False)
        figures.append(fig)
    return figures


def valley_png(figures,*,columns=4):
    images=[]
    for figure in figures:
        stream=io.BytesIO();figure.savefig(stream,format='png',dpi=150,facecolor='white');images.append(stream.getvalue())
    return combine_map_pngs(images,columns=columns,dpi=150)


def valley_archive(result,fft=None):
    stream=io.BytesIO()
    with zipfile.ZipFile(stream,'w',compression=zipfile.ZIP_DEFLATED) as z:
        for name in ['metrics','flags','grain_heights','node_heights','grain_distances','node_distances','planes','centroids','thresholds']:z.writestr(name+'.csv',result[name].to_csv(index=False))
        z.writestr('method.json',json.dumps(result['metadata'],ensure_ascii=False,indent=2))
        for name in ['bottom_lines','bottom_line_support','reference_bottom_grains','local_lowness','origins','origin_nodes','origin_support','origin_flags','taylor_factors','taylor_boundary_segments','taylor_boundaries','taylor_origin_boundary','taylor_boundary_metrics','union_metrics','union_origin_flags']:
            if name in result:z.writestr(name+'.csv',result[name].to_csv(index=False))
        if fft is not None:
            z.writestr('fft_scales.csv',fft['metrics'].to_csv(index=False))
            z.writestr('fft_method.json',json.dumps(fft['metadata'],ensure_ascii=False,indent=2))
    return stream.getvalue()


def render_valley_evaluation(evaluation,model_dir,case):
    import streamlit as st
    with st.expander('最小二乗平面からの距離で山・谷を比較'):
        st.caption('予測とCPFEMは重ね合わせません。各高さ場自身に最小二乗平面を当て、表面に露出した各粒の面積重心とその平面との符号付き垂直距離dを計算します。各場で独立に δ=√平均(d²) を自動計算し、d<−δを谷、d>δを山として、検出した粒IDの一致を調べます。')
        feature_label=st.radio('比較する形状',['谷','山'],horizontal=True,key='plane-feature')
        level='grain';feature='valley' if feature_label=='谷' else 'peak'
        st.caption('閾値は粒重心距離のRMSの1倍。振幅が異なるモデルにも同じ定義を適用し、対象割合は固定しません。平面や閾値をCPFEMに合わせて予測を補正する処理はありません。')
        try:result=valley_tables(evaluation['selected'],model_dir)
        except (ValueError,OSError,KeyError) as error:
            st.info(f'山・谷評価を実行できません：{error}');return
        result['metadata']['source_case']=case
        table=result['metrics'];subset=table[(table.level==level)&(table.feature==feature)]
        chosen=subset[np.isclose(subset.threshold_factor,1.)]
        st.dataframe(chosen[['model','reference_threshold','distance_threshold','target_count','predicted_count','recall','precision','f1','iou']].rename(columns={
            'model':'モデル','reference_threshold':'CPFEM自動閾値','distance_threshold':'予測自動閾値','target_count':'CPFEMの対象数','predicted_count':'予測の対象数','recall':'捕捉率','precision':'的中率','f1':'F1','iou':'重なり率 IoU'}),hide_index=True,width='stretch')
        st.caption('捕捉率：CPFEMの対象を何割拾ったか。的中率：予測候補の何割がCPFEMでも対象か。灰色は双方で対象外、緑は一致、橙は誤検出、青は見逃しです。')
        st.caption('ここでの重心は3D粒全体ではなく、表示領域に露出した粒表面の現在面積重心です。山・谷を粒単位で等重みに比較します。')
        if (chosen.target_count==0).all():st.info('この閾値を超えるCPFEMの対象がないため、捕捉率・F1・IoUは未定義です。')
        if st.checkbox('一致・見逃し・誤検出マップを表示',value=True,key='valley-show-maps'):
            figures=valley_figures(result,model_dir,level=level,feature=feature)
            for column,figure in zip(st.columns(4),figures):
                with column:st.pyplot(figure,width='stretch')
            st.download_button('一致マップを保存（PNG）',valley_png(figures),file_name=case+f'_{feature}_{level}_plane_distance.png',mime='image/png',key='valley-png')
            for figure in figures:plt.close(figure)
        sensitivity=subset.pivot(index='threshold_factor',columns='model',values='recall')
        sensitivity.index.name='各場の自動閾値に対する倍率'
        st.caption('各場の自動閾値を0.5倍・1倍・2倍にした場合の捕捉率')
        st.dataframe(sensitivity,width='stretch')
        fft=None
        if st.checkbox('補助：FFTで空間スケール別の一致度も確認',value=False,key='valley-fft'):
            try:
                fft=fft_scale_table(evaluation['selected'],model_dir)
                st.dataframe(fft['metrics'],hide_index=True,width='stretch')
                st.caption('FFTは補助評価です。山・谷の判定には周波数による除外を行いません。スペクトルエネルギーは振幅二乗で、力学的エネルギーではありません。')
            except (ValueError,OSError,KeyError) as error:st.info(f'FFT補助評価は利用できません：{error}')
        st.download_button('山・谷の精度・距離・平面係数・評価条件を保存（ZIP）',valley_archive(result,fft),file_name=case+'_plane_distance_evaluation.zip',mime='application/zip',key='valley-archive')
