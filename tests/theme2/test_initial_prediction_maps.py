import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import pytest
from src.dashboard import initial_prediction as maps


def test_contour_maps_grains_and_ranks(tmp_path,monkeypatch):
    p=tmp_path/'pred.csv'
    pd.DataFrame({'part_id':[2,1],'az_midpoint':[4.,2.]}).to_csv(p,index=False)
    polygon=np.array([[0,0],[1,0],[1,1],[0,1]])
    monkeypatch.setattr(maps,'deformed_surface',lambda *a,**kw:(np.array([1,2,3]),np.array([1,2,1]),[polygon]*3,[]))
    fig=maps.prediction_figure(p,tmp_path,p,rank=True)
    np.testing.assert_allclose(fig.axes[0].collections[0].get_array(),[.5,1.,.5])
    assert fig.axes[0].collections[0].get_clim()==(0.,1.)
    plt.close(fig)
    pd.DataFrame({'part_id':[1],'az_midpoint':[2.]}).to_csv(p,index=False)
    with pytest.raises(ValueError,match='surface region'):
        maps.prediction_figure(p,tmp_path,p)


def test_actual_height_uses_shared_display(tmp_path,monkeypatch):
    captured={}
    sentinel=object()
    def common(path,**kwargs):
        captured.update(path=path,**kwargs)
        return sentinel
    monkeypatch.setattr(maps,'height_figure',common)
    path=tmp_path/'height.csv'
    heights=np.r_[np.linspace(.009,.01,100),1.e6]
    monkeypatch.setattr(maps,'read_height',lambda p:(np.zeros(101),np.zeros(101),heights))
    assert maps.actual_height_figure(path,tmp_path) is sentinel
    assert captured['path']==path
    assert captured['spatial_model_dir']==tmp_path
    np.testing.assert_allclose(captured['value_range'],np.quantile(heights*maps.HEIGHT_SCALE,[.02,.98]))
    assert heights[-1]==1.e6
    assert captured['value_range'][1]<11.


def test_normalized_contour_preserves_mesh_and_shared_scale(tmp_path,monkeypatch):
    path=tmp_path/'height.csv'
    frame=pd.DataFrame({'node_id':[1,2,3,4], 'x':[0.,1.,1.,0.], 'y':[0.,0.,1.,1.], 'z':[0.,1.,0.,1.]})
    frame.to_csv(path,index=False)
    monkeypatch.setattr(maps,'surface_topology',lambda *a:(None,None,[np.array([1,2,3,4]),np.array([4,5,6])],[],6))
    monkeypatch.setattr(maps,'deformed_surface',lambda *a:(None,None,None,[]))
    fig=maps.normalized_height_figure(path,tmp_path,title='Normalized',extent=2.)
    assert fig.axes[0].collections[0].get_clim()==(-2.,2.)
    assert fig.axes[1].get_ylabel()=='Signed height / own RMS'
    plt.close(fig)


@pytest.mark.parametrize('metric',['m_initial','pabs_midpoint','pminus_midpoint','chi','k'])
def test_all_indicator_color_ranges_use_visible_grain_quantiles_and_retain_outliers(tmp_path,monkeypatch,metric):
    # First grain has 1000 elements, but quantiles must give one vote per grain.
    parts=np.r_[np.ones(1000,dtype=int),np.arange(2,102)]
    values=np.r_[np.arange(100.),1e6]
    frame=pd.DataFrame({'part_id':np.arange(1,102),metric:values})
    polygon=np.array([[0,0],[1,0],[1,1],[0,1]])
    monkeypatch.setattr(maps,'deformed_surface',lambda *a,**kw:(None,parts,[polygon]*len(parts),[]))
    fig=maps.prediction_figure(frame,tmp_path,tmp_path/'unused.csv',metric=metric)
    plotted=fig.axes[0].collections[0]
    np.testing.assert_allclose(plotted.get_clim(),np.quantile(values,[.02,.98]))
    assert plotted.get_array()[-1]==1e6
    assert plotted.cmap.name==('viridis_r' if metric=='m_initial' else 'viridis')
    plt.close(fig)


def test_constant_robust_color_limits_remain_valid():
    low,high=maps.indicator_color_limits(np.ones(100),robust=True)
    assert low<1<high
