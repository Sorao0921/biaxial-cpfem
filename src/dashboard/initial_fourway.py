"""Four panels: scalar K, signed D/unsigned Q, 3D equilibrium, CPFEM reference."""
import io
import json
import zipfile
from pathlib import Path
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from src.config.pipeline_paths import PROJECT_ROOT,OUTPUTS_DIR,build_spatial_model_dir
from src.dashboard.catalog import scan_outputs,filter_records
from src.dashboard.initial_prediction import coordinate_height_figure,indicator_color_limits
from src.dashboard.export import combine_map_pngs
from src.theme1.contribution import _read_height
from src.theme1.initial_fourway import predict_three_models,evaluate_three_models,MODEL_NAMES,LABELS


def comparison_figures(prediction,evaluation,model_dir):
    selected=evaluation['selected'];metrics=evaluation['metrics'].set_index('model')
    figures=[]
    for name in (*MODEL_NAMES,'cpfem'):
        # Per-panel display limits: CPFEM amplitudes never set prediction colors.
        limits=indicator_color_limits(selected[name].z.to_numpy()*1000,robust=True)
        title=LABELS[name]+'\nOwn color range (2-98%)'
        if name!='cpfem':
            row=metrics.loc[name];r=row.nodal_pearson
            title+=f'\nr={r:.3f}, RMSE={row.raw_height_rmse:.3g}' if np.isfinite(r) else f'\nr=undefined, RMSE={row.raw_height_rmse:.3g}'
        if name=='equilibrium' and not prediction['models'][name]['metadata']['finite_geometry_valid']:
            title+='\nOutside small-strain range'
        figure=coordinate_height_figure(selected[name],model_dir,title=title,value_range=limits)
        figure.axes[0].title.set_fontsize(12)
        figures.append(figure)
    return figures


def figures_png(figures):
    panels=[]
    for fig in figures:
        stream=io.BytesIO();fig.savefig(stream,format='png',dpi=160,facecolor='white');panels.append(stream.getvalue())
    return combine_map_pngs(panels,columns=4,dpi=160)


def archive_comparison(prediction,evaluation):
    stream=io.BytesIO()
    with zipfile.ZipFile(stream,'w',compression=zipfile.ZIP_DEFLATED) as z:
        z.writestr('configuration.json',json.dumps(prediction['configuration'],ensure_ascii=False,indent=2))
        for key in ['indicators','interfaces','surface_edges']:z.writestr(key+'.csv',prediction[key].to_csv(index=False))
        for name in MODEL_NAMES:
            model=prediction['models'][name]
            for key in ['coordinates','grains','displacements','initial_tensors']:
                if key in model:z.writestr(name+'/'+key+'.csv',model[key].to_csv(index=False))
            z.writestr(name+'/model.json',json.dumps(model['metadata'],ensure_ascii=False,indent=2))
            z.writestr(name+'/height_comparison.csv',evaluation['pairs'][name].to_csv(index=False))
        z.writestr('cpfem_state13.csv',evaluation['selected']['cpfem'].to_csv(index=False))
        z.writestr('evaluation.csv',evaluation['metrics'].to_csv(index=False))
    return stream.getvalue()


def render_fourway_prediction():
    import streamlit as st
    records=filter_records(scan_outputs(OUTPUTS_DIR),kind='height',state=13)
    if not records:st.info('state13のCPFEM高さデータがありません。');return
    cases=pd.DataFrame([{'rho':r.rho,'seed':r.seed,'texture':r.texture,'sd':r.sd,'path':r.path} for r in records])
    for column,key in zip(st.columns(4),['rho','seed','texture','sd']):
        with column:value=st.selectbox(key,sorted(cases[key].unique()),key=f'initial-prediction-{key}')
        cases=cases[cases[key].eq(value)]
    row=cases.iloc[0]
    m=st.number_input('速度感受性 m',min_value=.005,max_value=1.,value=.05,step=.005,format='%.3f',key='initial-stress-m')
    with st.expander('共通負荷・モデルの仮定'):
        strain=st.number_input('指定相当ひずみ（CPFEM結果から取得しません）',min_value=0.,max_value=1.,value=.1,step=.01,key='neighbor-height-strain')
        eta=st.slider('初期変形テンソルのばらつき保持率（全モデル共通）',0.,1.,.75,.05,key='initial-equilibrium-heterogeneity')
        coupling=st.number_input('A・B共通の表面粒間結合 λ',min_value=0.,max_value=100.,value=1.,step=.25,key='fourway-coupling')
        gamma=st.number_input('BのQ拘束効果 γ（0でAと完全一致）',min_value=0.,max_value=20.,value=1.,step=.25,key='fourway-q-coupling')
        poisson=st.number_input('Cのポアソン比',min_value=0.,max_value=.45,value=.3,step=.01,key='initial-equilibrium-poisson')
        st.caption('D=自粒K−近傍平均K。Q=初期の実粒界面に投影した全テンソル差の二乗和。Qは非負で、単独で山谷の符号を決めません。BではQが大きいほど基準変形へ戻す拘束が強いという仮説を使います。γ=0でQの効果だけを除外できます。')
        st.caption('AはNDのK差のみで、以前のRD/TD伸長差や低Kゲートは混ぜません。A・B・Cで同じ初期Sachs、平均ひずみ比、自動応力比、ばらつき保持率を使用します。A・Bは同じ小変形の平均板厚と同じ表面結合を使い、Qの有無だけを変えます。')
        st.caption('係数は未同定の近似条件です。0.75の保持率はこれまでの結果を見て設定したため、現在の比較は探索的な検証として扱います。CPFEMに合わせた自動最適化・振幅合わせは行いません。')
    st.caption('左から：A Kのみ／B D・Q指標／C 3D平衡／CPFEM参照。3予測が完了した後にだけstate13高さを読み込みます。CPFEMは実験実測ではなく比較用の解析結果です。')
    model=build_spatial_model_dir(int(row.seed))
    orientation=PROJECT_ROOT/'inputs/orientation'/f'texture_seed{row.seed}'/f'{row.texture}_sigma{row.sd}_seed{row.seed}.csv'
    try:
        with st.spinner('初期組織から3モデルを計算しています（初回は3Dメッシュを組み立てます）…'):
            prediction=predict_three_models(orientation,model,rho=float(row.rho),m=float(m),strain=float(strain),heterogeneity=float(eta),coupling=float(coupling),q_coupling=float(gamma),poisson=float(poisson))
        # All three predictions above are complete and independent of this read.
        cpfem=_read_height(Path(row.path))
        evaluation=evaluate_three_models(prediction,cpfem)
        figures=comparison_figures(prediction,evaluation,model)
    except (ValueError,OSError,KeyError) as error:
        st.error(str(error));return
    for column,figure in zip(st.columns(4),figures):
        with column:st.pyplot(figure,width='stretch')
    case=f'rho_{row.rho:g}_{row.texture}_sd{row.sd}_seed{row.seed}_state13_cfg{prediction["config_id"]}'
    st.download_button('4枚の比較マップを保存（PNG）',figures_png(figures),file_name=case+'_fourway.png',mime='image/png',key='fourway-png')
    for figure in figures:plt.close(figure)
    metrics=evaluation['metrics']
    table=metrics[['model','nodal_pearson','raw_height_rmse','mean_height_bias','std_ratio']].rename(columns={
        'model':'モデル','nodal_pearson':'節点高さ相関','raw_height_rmse':'高さRMSE','mean_height_bias':'平均高さ誤差','std_ratio':'高さ振幅比（予測/CPFEM）'})
    st.dataframe(table,hide_index=True,width='stretch')
    st.caption(f'自動応力比 β={prediction["configuration"]["beta"]:.6g}。高さは正規化せず、各マップ自身の2〜98百分位で色範囲を個別調整します。色の濃さによるモデル間の振幅比較はできません。誤差計算は全値を使用します。')
    meta=prediction['models']['equilibrium']['metadata']
    st.caption(f'3D平衡：{meta["initial_elements"]:,}要素、力の相対残差 {meta["relative_free_force_residual"]:.2g}。固定初期固有ひずみの線形解であり、すべり・回転・硬化の増分更新はしません。')
    if not meta['finite_geometry_valid']:
        st.warning(f'Cは線形解として収束しましたが、有限変形として扱うと{meta["inverted_deformed_elements"]:,}要素が反転します。小変形近似の適用範囲外です。')
    elif meta['maximum_eigenstrain_norm']>.1:
        st.warning('Cには大きな固有ひずみを持つ粒があります。収束や反転なしだけでは小変形近似の妥当性を保証しません。')
    for name in ('k_only','d_q'):
        if not prediction['models'][name]['grains'].linear_height_positive.all():st.warning(f'{name}に非正の予測板厚があります。値はクリップしていません。')
    st.download_button('精度一覧を保存（CSV）',metrics.to_csv(index=False).encode('utf-8-sig'),file_name=case+'_evaluation.csv',mime='text/csv',key='fourway-csv')
    st.download_button('全予測・D/Q・粒界法線・変位・条件を保存（ZIP）',archive_comparison(prediction,evaluation),file_name=case+'_fourway.zip',mime='application/zip',key='fourway-archive')
    from src.dashboard.valley_evaluation import render_valley_evaluation
    render_valley_evaluation(evaluation,model,case)

