"""Initial Taylor / equal-stress indicators on state1, alongside state13 height."""
import io
import json
import hashlib
import zipfile
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.collections import PolyCollection
from matplotlib.colors import Normalize

from src.config.pipeline_paths import PROJECT_ROOT, OUTPUTS_DIR, build_spatial_model_dir
from src.dashboard.catalog import scan_outputs, filter_records
from src.theme1.initial_taylor_prediction import optimal_activity
from src.crystal_plasticity.stress_response import initial_stress_response, initial_grain_volumes
from functools import lru_cache
from src.dashboard.plots import deformed_surface, height_figure, read_height, _draw_boundaries, surface_topology
from src.theme1.initial_height import normalized_height_coordinates
from src.theme1.neighbor_height import predict_from_initial, evaluate_coordinates, DEFAULT_BLEND
from src.theme1.sachs_equilibrium import predict_equilibrium_from_initial
from src.theme1.contribution import _read_height

import matplotlib.tri as mtri
from src.mapping.plot_style import HEIGHT_SCALE
from src.dashboard.style import apply_figure_style

LABELS = {
    'relief_from_neighbor_az': 'Neighbor activity contrast\n(positive: predicted high)',
    'az_midpoint': 'Initial Taylor Az midpoint',
    'pabs_midpoint': 'Initial Taylor P_abs',
    'az_min': 'Initial Taylor Az minimum',
    'az_max': 'Initial Taylor Az maximum',
    'm_initial': 'Initial Taylor factor M',
    'pminus_midpoint': 'Initial Taylor P-',
    'chi': 'Initial χ\n(stress response)',
    'k': 'Initial K\n(stress response)',
    'az_range': 'Initial Taylor Az solution range',
    'surface_z_mean': 'State13 grain mean surface z',
    'relief_from_az_midpoint': 'Predicted high / low from initial Az midpoint',
    'relief_from_az_min': 'Predicted high / low from initial Az minimum',
    'relief_from_az_max': 'Predicted high / low from initial Az maximum',
    'relief_from_m_initial': 'Predicted high / low from initial M',
    'relief_from_measured_az_state13': 'Measured Az: high activity implies valley',
    'relief_from_measured_bz_state13': 'Integrated measured Az: valley hypothesis',
    'height_abs_mean': 'State13 mean absolute height residual',
    'height_std': 'State13 within-grain height standard deviation',
    'height_mean': 'State13 signed mean height residual',
}


def indicator_color_limits(values, *, robust=False):
    """Display-only limits: equal weight per visible grain, never per element."""
    values=np.asarray(values,dtype=float)
    if not len(values) or not np.isfinite(values).all():
        raise ValueError('Expected finite visible grain values')
    low,high=np.quantile(values,[.02,.98]) if robust else (values.min(),values.max())
    if low==high:
        padding=1e-12*max(1.,abs(low))
        low,high=low-padding,high+padding
    return float(low),float(high)


def prediction_figure(prediction_path, spatial_model_dir, coordinates_path, *, metric='az_midpoint', rank=False, reference_geometry=True):
    """Render grain-constant top-face polygons without invented interpolation."""
    if metric not in LABELS:
        raise ValueError('Unknown prediction metric')
    frame=prediction_path.copy() if isinstance(prediction_path,pd.DataFrame) else pd.read_csv(prediction_path)
    if not {'part_id',metric}.issubset(frame) or frame.part_id.duplicated().any():
        raise ValueError('Expected unique part IDs and prediction values')
    _,parts,polygons,segments=deformed_surface(spatial_model_dir,coordinates_path,reference_geometry=reference_geometry)
    values=frame.set_index('part_id')[metric]
    if not np.isfinite(values).all():
        raise ValueError('Nonfinite prediction values')
    if set(map(int,parts))-set(values.index):
        raise ValueError('Prediction and selected surface region do not match; recalculate this case')
    if rank:
        values=values.rank(method='average',pct=True)
    mapped=values.loc[parts].to_numpy()
    robust=not rank
    visible=values.loc[np.unique(parts)].to_numpy()
    limits=(0.,1.) if rank else indicator_color_limits(visible,robust=robust)
    if limits[0]==limits[1]:
        limits=(limits[0]-1e-12,limits[1]+1e-12)
    fig,ax=plt.subplots(figsize=(5.2,4.8),constrained_layout=True)
    collection=PolyCollection(polygons,array=mapped,cmap='coolwarm' if metric.startswith('relief_from_') or metric in ['height_mean','surface_z_mean'] else ('viridis_r' if metric == 'm_initial' else 'viridis'),norm=Normalize(*limits),edgecolors='none',antialiaseds=False)
    ax.add_collection(collection)
    _draw_boundaries(ax,segments)
    ax.autoscale_view();ax.margins(0);ax.set_aspect('equal')
    ax.set(xlabel='Initial x' if reference_geometry else 'x',ylabel='Initial y' if reference_geometry else 'y',title=LABELS[metric].replace('State13 ', 'State13\n').replace('Initial Taylor ', 'Initial Taylor\n')+('\nPercentile rank' if rank else ''))
    unit='low -> high percentile rank' if rank else ('coordinate units' if metric.startswith('height') or metric=='surface_z_mean' else 'dimensionless')
    extend='both' if robust and visible.min()<limits[0] and visible.max()>limits[1] else ('min' if robust and visible.min()<limits[0] else ('max' if robust and visible.max()>limits[1] else 'neither'))
    fig.colorbar(collection,ax=ax,label=unit,extend=extend)
    apply_figure_style(fig)
    ax.title.set_fontsize(14)
    return fig


def actual_height_figure(coordinates_path, spatial_model_dir):
    """Raw z with display-only 2--98 percentile limits in renderer units."""
    _,_,z=read_height(coordinates_path)
    limits=indicator_color_limits(np.asarray(z)*HEIGHT_SCALE,robust=True)
    return height_figure(coordinates_path, spatial_model_dir=spatial_model_dir,
                         title='State13 surface height', value_range=limits)


def normalized_height_figure(coordinates_path, spatial_model_dir, *, title, extent):
    coordinates,_=normalized_height_coordinates(coordinates_path)
    lookup={int(n):i for i,n in enumerate(coordinates.node_id)}
    _,_,faces,_,_=surface_topology(spatial_model_dir)
    triangles=[]
    for face in faces:
        if all(int(n) in lookup for n in face):
            indices=[lookup[int(n)] for n in face]
            triangles.extend((indices[0],indices[k],indices[k+1]) for k in range(1,len(indices)-1))
    if not triangles:
        raise ValueError('No complete surface faces for comparison')
    mesh=mtri.Triangulation(coordinates.x,coordinates.y,np.asarray(triangles))
    fig,ax=plt.subplots(figsize=(5.2,4.8),constrained_layout=True)
    contour=ax.tricontourf(mesh,coordinates.z,levels=np.linspace(-extent,extent,31),cmap='coolwarm',extend='both')
    _,_,_,segments=deformed_surface(spatial_model_dir,coordinates_path)
    _draw_boundaries(ax,segments)
    ax.set(xlabel='x',ylabel='y',title=title);ax.set_aspect('equal');ax.margins(0)
    fig.colorbar(contour,ax=ax,label='Signed height / own RMS')
    apply_figure_style(fig);ax.title.set_fontsize(14)
    return fig


def coordinate_height_figure(coordinates,spatial_model_dir,*,title,value_range):
    """Raw-z contour on complete initial mesh faces, without gap bridging."""
    lookup={int(node):i for i,node in enumerate(coordinates.node_id)}
    _,_,faces,boundaries,_=surface_topology(spatial_model_dir)
    triangles=[]
    for face in faces:
        if all(int(node) in lookup for node in face):
            indices=[lookup[int(node)] for node in face]
            triangles.extend((indices[0],indices[k],indices[k+1]) for k in range(1,len(indices)-1))
    if not triangles:raise ValueError('No complete predicted surface faces')
    mesh=mtri.Triangulation(coordinates.x,coordinates.y,np.asarray(triangles))
    fig,ax=plt.subplots(figsize=(5.2,4.8),constrained_layout=True)
    contour=ax.tricontourf(mesh,coordinates.z.to_numpy()*HEIGHT_SCALE,levels=np.linspace(*value_range,31),cmap='coolwarm',extend='both')
    xy=coordinates[['x','y']].to_numpy()
    segments=[xy[[lookup[a],lookup[b]]] for a,b in boundaries if a in lookup and b in lookup]
    _draw_boundaries(ax,segments)
    ax.set(xlabel='x',ylabel='y',title=title);ax.set_aspect('equal');ax.margins(0)
    fig.colorbar(contour,ax=ax,label=r'Surface height $z$ ($\times 10^{-3}$)')
    apply_figure_style(fig);ax.title.set_fontsize(14)
    return fig


def prediction_archive(prediction,pair,metrics):
    stream=io.BytesIO()
    with zipfile.ZipFile(stream,'w',compression=zipfile.ZIP_DEFLATED) as archive:
        for name in ('grains','edges','components','coordinates','initial_properties'):
            archive.writestr(name+'.csv',prediction[name].to_csv(index=False))
        archive.writestr('model.json',json.dumps(prediction['metadata'],ensure_ascii=False,indent=2))
        archive.writestr('height_comparison.csv',pair.to_csv(index=False))
        archive.writestr('evaluation.json',json.dumps({key:(None if isinstance(value,float) and not np.isfinite(value) else value) for key,value in metrics.items()},ensure_ascii=False,indent=2))
    return stream.getvalue()


def equilibrium_archive(prediction,pair,metrics):
    stream=io.BytesIO()
    with zipfile.ZipFile(stream,'w',compression=zipfile.ZIP_DEFLATED) as archive:
        for name in ('coordinates','displacements','initial_tensors'):
            archive.writestr(name+'.csv',prediction[name].to_csv(index=False))
        archive.writestr('model.json',json.dumps(prediction['metadata'],ensure_ascii=False,indent=2))
        archive.writestr('height_comparison.csv',pair.to_csv(index=False))
        archive.writestr('evaluation.json',json.dumps({key:(None if isinstance(value,float) and not np.isfinite(value) else value) for key,value in metrics.items()},ensure_ascii=False,indent=2))
    return stream.getvalue()


@lru_cache(maxsize=32)
def initial_metric_frame(orientation_path, rho, modified_ns):
    """Initial inputs only; mtime invalidates cache when orientations change."""
    angles=np.loadtxt(orientation_path,delimiter=',',ndmin=2)
    rows=[]
    for part_id,euler in enumerate(angles,start=1):
        response=optimal_activity(euler,rho)
        rows.append({'part_id':part_id,**{key:response[key] for key in ('m_initial','pabs_midpoint','pminus_midpoint')}})
    return pd.DataFrame(rows)


@lru_cache(maxsize=8)
def _initial_volume_frame(model_dir, nodes_modified_ns, elements_modified_ns):
    return initial_grain_volumes(model_dir)


@lru_cache(maxsize=32)
def initial_stress_frame(orientation_path, beta, m, orientation_modified_ns,
                         model_dir, nodes_modified_ns, elements_modified_ns):
    angles=np.loadtxt(orientation_path,delimiter=',',ndmin=2)
    volumes=_initial_volume_frame(model_dir,nodes_modified_ns,elements_modified_ns)
    ids=volumes.part_id.to_numpy(int)
    if (ids<1).any() or (ids>len(angles)).any():
        raise ValueError('Initial grain orientation missing')
    response=initial_stress_response(angles[ids-1],beta,m,volumes.initial_volume.to_numpy())
    return volumes.assign(chi=response['chi'],k=response['k'])


def render_initial_prediction():
    import streamlit as st
    catalog=scan_outputs(OUTPUTS_DIR)
    records=filter_records(catalog,kind='height',state=13)
    if not records:
        st.info('state13の表面高さデータがありません。');return
    cases=pd.DataFrame([{'rho':r.rho,'seed':r.seed,'texture':r.texture,'sd':r.sd,'path':r.path} for r in records])
    for column,key in zip(st.columns(4),['rho','seed','texture','sd']):
        with column:
            choice=st.selectbox(key,sorted(cases[key].unique()),key=f'initial-prediction-{key}')
        cases=cases[cases[key].eq(choice)]
    row=cases.iloc[0]
    case=f'rho_{row.rho:g}_{row.texture}_sd{row.sd}_seed{row.seed}_state13'
    sensitivity=st.number_input('速度感受性 m',min_value=.005,max_value=1.,value=.05,step=.005,format='%.3f',key='initial-stress-m')
    choices={'K（Sachs・正味ND収縮）':'k'}
    choice=st.selectbox('高さ予測に使う初期指標',list(choices),key='neighbor-height-source')
    source=choices[choice]
    weights=DEFAULT_BLEND.copy() if source=='blend' else {source:1.}
    include_equilibrium=st.checkbox('初期全テンソルによる3次元平衡予測も比較する',value=True,key='initial-equilibrium-enabled')
    with st.expander('予測モデルの固定条件・組合せ'):
        strain=st.number_input('指定相当対数ひずみ（結果から取得しません）',min_value=0.,max_value=1.,value=.1,step=.01,key='neighbor-height-strain')
        coupling=st.number_input('隣接粒の引き込み λ（0で伝達なし）',min_value=0.,max_value=100.,value=1.,step=.25,key='neighbor-height-coupling')
        inplane_weight=st.slider('面内伸長差の配合（0：ND差、1：RD・TD伸長差）',0.,1.,.5,.1,key='neighbor-height-inplane')
        heterogeneity=st.slider('Sachs変形の粒ごとのばらつき（1で従来どおり）',0.,1.,.75,.05,key='initial-equilibrium-heterogeneity')
        st.caption('体積平均の全テンソルを保ち、平均からの差だけを抑えます。粒間拘束を表す近似パラメータであり、解析高さから自動調整しません。')
        poisson=st.number_input('3次元平衡モデルのポアソン比',min_value=0.,max_value=.45,value=.3,step=.01,key='initial-equilibrium-poisson')
        low_k_resistance=st.checkbox('低K粒は周囲に引き込まれにくくする',value=True,key='neighbor-height-low-k')
        standardize=st.checkbox('入力を初期表面積加重RMSで標準化する',value=source=='blend',key=f'neighbor-height-standardize-{source}')
        if source=='blend':
            weights={}
            for col,(key,label) in zip(st.columns(5),[('k','K'),('chi','χ'),('pminus','P−'),('pabs','P_abs'),('m','低M')]):
                weights[key]=col.number_input(label+'の重み',min_value=0.,max_value=1.,value=DEFAULT_BLEND.get(key,0.),step=.1,key='neighbor-height-weight-'+key)
        st.caption('周囲より大きいK・χ・P、または小さいMを谷の駆動源とします。RD・TD伸長差は粒間方向を考慮し、ND差と配合します。組合せは重みを合計1へ規格化。実測高さから指標・符号・重みを選ぶ自動処理はありません。')
        st.caption('従来Kモデルは活動差で谷の駆動源を作り、共有粒界長／初期粒重心間距離による結合で周囲へ沈み込みを伝えます。低K抵抗を有効にすると、初期の正K面積平均に比べKが小さい粒ほど伝達を弱めます。Kを剛性と同一視するものではありません。平均板厚は指定ひずみから固定し、振幅合わせはしません。これは力学平衡を解くCPモデルではありません。')
    st.caption('予測入力は初期方位・初期メッシュ・指定負荷だけです。応力比βは、初期Sachsモデルの体積平均ひずみ比が指定rhoと一致するよう自動計算します。変形中の応力・すべり・方位履歴は使いません。')
    try:
        orientation=PROJECT_ROOT/'inputs/orientation'/f'texture_seed{row.seed}'/f'{row.texture}_sigma{row.sd}_seed{row.seed}.csv'
        model=build_spatial_model_dir(int(row.seed))
        # Full prediction is complete before observed coordinates are read.
        prediction=predict_from_initial(orientation,model,rho=float(row.rho),beta=None,m=float(sensitivity),
            strain=float(strain),feature_weights=weights,coupling=float(coupling),standardize=bool(standardize),inplane_weight=float(inplane_weight),low_k_resistance=bool(low_k_resistance))
        equilibrium=None
        if include_equilibrium:
            with st.spinner('初期3次元メッシュの力学平衡を計算しています（初回は時間がかかります）…'):
                equilibrium=predict_equilibrium_from_initial(orientation,model,rho=float(row.rho),m=float(sensitivity),strain=float(strain),poisson=float(poisson),heterogeneity=float(heterogeneity))
        beta=prediction['metadata']['beta']
        config_id=hashlib.sha256(json.dumps({'k':prediction['metadata'],'equilibrium':{'enabled':include_equilibrium,'poisson':float(poisson),'heterogeneity':float(heterogeneity),'version':2}},sort_keys=True).encode()).hexdigest()[:12]
        # Both complete predictions exist before actual coordinates are opened.
        actual=_read_height(Path(row.path))
        selected,pair,metrics=evaluate_coordinates(prediction['coordinates'],actual)
        eq_selected=eq_pair=eq_metrics=None
        if equilibrium is not None:
            eq_selected,eq_pair,eq_metrics=evaluate_coordinates(equilibrium['coordinates'],actual)
        values=[selected.z.to_numpy(),actual.z.to_numpy()]
        if eq_selected is not None:values.append(eq_selected.z.to_numpy())
        limits=indicator_color_limits(np.concatenate(values)*HEIGHT_SCALE,robust=True)
        figures=[coordinate_height_figure(selected,model,title='K-based prediction\n(initial + neighbors)',value_range=limits),
                 coordinate_height_figure(actual,model,title='Simulation surface height\n(state13)',value_range=limits)]
    except (ValueError,OSError,KeyError) as error:
        st.error(str(error));return
    names=['predicted','actual']
    if equilibrium is not None:
        figures.insert(1,coordinate_height_figure(eq_selected,model,title='3D equilibrium prediction\n(frozen initial Sachs tensor)',value_range=limits))
        names.insert(1,'equilibrium')
    for col,fig,name in zip(st.columns(len(figures)),figures,names):
        with col:
            st.pyplot(fig,width='stretch')
            stream=io.BytesIO();fig.savefig(stream,format='png',dpi=200,bbox_inches='tight')
            st.download_button('PNGを保存',stream.getvalue(),file_name=f'{case}_{name}_{source}_beta{beta:g}_m{sensitivity:g}_cfg{config_id}.png',mime='image/png',key='neighbor-height-png-'+name)
        plt.close(fig)
    if equilibrium is not None:
        stats=[]
        for name,values in [('従来K',metrics),('3次元平衡',eq_metrics)]:
            stats.append({'予測':name,'節点高さ相関':values['nodal_pearson'],'高さRMSE':values['raw_height_rmse'],
                '予測高さの標準偏差':values['predicted_height_std'],'解析高さの標準偏差':values['actual_height_std']})
        st.dataframe(pd.DataFrame(stats),hide_index=True,width='stretch')
        meta=equilibrium['metadata']
        st.caption(f"3次元平衡：{meta['initial_elements']:,}要素、自由節点力の相対残差 {meta['relative_free_force_residual']:.2g}、{meta['iterations']}反復。初期全テンソルを固定した線形弾性固有ひずみモデルです。応力の再分配に応じたすべり・方位・硬化の更新はしません。")
        st.caption('平衡モデルは小変形の変位解、従来Kは指数式による板厚変換です。平均板厚の差もRMSEに含みます。平衡図のxyは指定面内変形で投影し、zは解いたuzを使用します。')
        if not meta['finite_geometry_valid']:
            st.warning(f"3次元平衡は線形方程式として収束していますが、変位を有限変形とみなすと{meta['inverted_deformed_elements']:,}要素が反転します。指定ひずみでの小変形近似は適用範囲外です。予測値のクリップや振幅調整は行っていません。")
        elif meta['maximum_eigenstrain_norm']>.1:
            st.warning('初期固有ひずみが大きい粒があります。収束は小変形近似の妥当性を保証しません。')
        st.download_button('3次元平衡の予測・変位・計算条件を保存（ZIP）',equilibrium_archive(equilibrium,eq_pair,eq_metrics),file_name=f'{case}_equilibrium_cfg{config_id}_prediction.zip',mime='application/zip',key='initial-equilibrium-archive')
    correlation_label=f"{metrics['nodal_pearson']:.3f}" if np.isfinite(metrics['nodal_pearson']) else "未定義"
    st.caption(f"同じ節点IDの高さ相関: {correlation_label} ／ 高さRMSE: {metrics['raw_height_rmse']:.3g}（座標単位）。共通色範囲は全表示場の2〜98百分位。高さの正規化・振幅合わせは行っていません。")
    response_rho=prediction['metadata']['stress_model_mean_strain_ratio']
    if response_rho is not None:
        st.caption(f'指定βに対する初期Sachs平均ひずみ比: {response_rho:.3f} ／ 比較する解析のrho: {row.rho:g}。自動計算した応力比β: {beta:.6g}。')
    if np.ptp(prediction['grains'].predicted_height_from_bottom)<1e-12:
        st.info('この条件の予測は平坦です。初期指標のばらつき・組合せによる相殺・指定ひずみを確認してください。')
    st.download_button('予測データと計算条件を保存（ZIP）',prediction_archive(prediction,pair,metrics),file_name=f'{case}_{source}_beta{beta:g}_m{sensitivity:g}_cfg{config_id}_prediction.zip',mime='application/zip',key='neighbor-height-archive')
    with st.expander('初期指標とstate13高さの比較マップ'):
        st.caption('M・P_abs・P−・χ・Kはstate1の座標で表示。全マップに2〜98百分位の色範囲を適用し、計算値は変更しません。')
        try:
            initial_records=filter_records(catalog,kind='height',state=1,rho=float(row.rho),seed=int(row.seed),texture=row.texture,sd=int(row.sd))
            if len(initial_records)!=1:raise ValueError('対応するstate1表面座標がありません。')
            initial_path=initial_records[0].path
            frame=prediction['initial_properties']
            figures=[prediction_figure(frame,model,initial_path,metric=metric,reference_geometry=False) for metric in ('m_initial','pabs_midpoint','pminus_midpoint','chi','k')]
            for fig in figures:fig.axes[0].set_title(fig.axes[0].get_title()+'\n(state1)',fontsize=14)
            figures.append(actual_height_figure(row.path,model))
            names=['initial_M','initial_Taylor_Pabs','initial_Pminus','initial_chi','initial_K','simulation_height']
            for start in (0,3):
                for column,name,fig in zip(st.columns(3),names[start:start+3],figures[start:start+3]):
                    with column:
                        st.pyplot(fig,width='stretch')
                        stream=io.BytesIO();fig.savefig(stream,format='png',dpi=200,bbox_inches='tight')
                        st.download_button('PNGを保存',stream.getvalue(),file_name=f'{case.removesuffix("_state13")}_{name}{f"_beta{beta:g}_m{sensitivity:g}" if name in ("initial_chi","initial_K") else ""}_{"state13" if name=="simulation_height" else "state01"}.png',mime='image/png',key=f'prediction-download-{name}')
                    plt.close(fig)
        except (ValueError,OSError,KeyError) as error:
            st.error(str(error))
