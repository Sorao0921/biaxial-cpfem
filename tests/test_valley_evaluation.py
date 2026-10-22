import numpy as np
import pandas as pd
import pytest
from src.theme1.valley_evaluation import fit_plane_distances,distance_mask,binary_metrics,average_precision,valley_tables,fft_bands
from tests.test_initial_mismatch import mesh_frames


def test_plane_fit_signed_normal_distance_and_translation():
    x,y=np.meshgrid(np.arange(5.),np.arange(5.))
    residual=(x-2)**2-2
    xyz=np.column_stack([x.ravel(),y.ravel(),(2*x+3*y+4+residual).ravel()])
    distance,plane=fit_plane_distances(xyz)
    assert plane['a']==pytest.approx(2.) and plane['b']==pytest.approx(3.)
    assert plane['c']==pytest.approx(4.)
    np.testing.assert_allclose(distance,residual.ravel()/np.sqrt(14),atol=1.e-13)
    xyz[:,2]+=100
    np.testing.assert_allclose(fit_plane_distances(xyz)[0],distance,atol=1.e-13)


def test_absolute_distance_cutoff_does_not_force_counts_or_ignore_amplitude():
    d=np.array([-3.,-1.,0.,1.,3.])
    np.testing.assert_array_equal(distance_mask(d,2,'valley'),[True,False,False,False,False])
    np.testing.assert_array_equal(distance_mask(d,2,'peak'),[False,False,False,False,True])
    assert not distance_mask(d*.1,2,'valley').any()
    assert not distance_mask(d,3,'peak').any()
    stats=binary_metrics(distance_mask(d,2,'valley'),distance_mask(-d,2,'valley'))
    assert stats['false_positive']==stats['false_negative']==1 and stats['recall']==0


def test_flat_tilted_plane_has_no_artificial_features():
    x,y=np.meshgrid(np.arange(5.),np.arange(4.))
    xyz=np.column_stack([x.ravel(),y.ravel(),(2*x+3*y+10).ravel()])
    d,_=fit_plane_distances(xyz)
    assert not d.any()
    assert not distance_mask(d,1.e-8,'valley').any()
    assert not distance_mask(d,1.e-8,'peak').any()
    with pytest.raises(ValueError):fit_plane_distances([[0,0,0],[1,1,0],[2,2,0]])
    with pytest.raises(ValueError):distance_mask(d,0,'valley')


def test_missing_reference_targets_have_undefined_detection_metrics():
    stats=binary_metrics(np.zeros(100,bool),np.arange(100)<10)
    assert np.isnan(stats['recall']) and np.isnan(stats['f1']) and np.isnan(stats['iou'])
    assert np.isnan(average_precision(np.zeros(100,bool),np.arange(100)))
    truth=np.arange(100)<10
    assert average_precision(truth,np.ones(100))==pytest.approx(.1)


def test_grain_and_region_evaluation_are_separate_and_do_not_mutate_predictions(tmp_path):
    nodes,elements=mesh_frames(4,3,1);nodes.to_csv(tmp_path/'nodes.csv',index=False);elements.to_csv(tmp_path/'elements.csv',index=False)
    top=nodes[nodes.z.eq(nodes.z.max())].copy();top.node_id=np.arange(1,len(top)+1)
    top.z=top.x+.1*top.y+np.cos(top.x*2)*.1
    selected={'cpfem':top.copy(),'k_only':top.copy(),'d_q':top.copy(),'equilibrium':top.copy()}
    before=selected['k_only'].copy(deep=True)
    result=valley_tables(selected,tmp_path,threshold=.001)
    assert set(result['metrics'].level)=={'grain','node_region'}
    assert set(result['metrics'].feature)=={'valley','peak'}
    np.testing.assert_allclose(result['metrics'].recall.dropna(),1.)
    np.testing.assert_allclose(result['metrics'].precision.dropna(),1.)
    assert result['metrics'].target_count.max()>0
    assert len(result['planes'])==4
    assert set(result['metrics'].distance_threshold)=={.0005,.001,.002}
    pd.testing.assert_frame_equal(before,selected['k_only'])
    assert len(result['grain_heights'])==2


def test_fft_band_reconstruction_conserves_detrended_signal_and_energy():
    ny=40;nx=48;dx=.01;dy=.012
    x,y=np.meshgrid(np.arange(nx)*dx,np.arange(ny)*dy)
    field=.03*x+.02*y+np.cos(2*np.pi*x/.24)+.2*np.cos(2*np.pi*y/.048)
    result=fft_bands(field,dx,dy,.06)
    reconstructed=sum(result['fields'].values())
    np.testing.assert_allclose(reconstructed,result['detrended'],atol=1.e-12)
    assert sum(result['energy'].values())==pytest.approx(np.sum(result['detrended']**2),rel=1.e-12)
    assert result['energy']['low']>0 and result['energy']['high']>0


def test_automatic_centroid_thresholds_are_independent_and_scale_with_amplitude(tmp_path):
    nodes,elements=mesh_frames(4,3,1)
    nodes.to_csv(tmp_path/'nodes.csv',index=False);elements.to_csv(tmp_path/'elements.csv',index=False)
    top=nodes[nodes.z.eq(nodes.z.max())].copy();top.node_id=np.arange(1,len(top)+1)
    top.z=.01+.001*np.cos(top.x*2)
    scaled=top.copy();scaled.z=.02+3*(top.z-.01)
    selected={'cpfem':top,'k_only':scaled,'d_q':top.copy(),'equilibrium':top.copy()}
    result=valley_tables(selected,tmp_path)
    thresholds=result['thresholds'].query("level=='grain'").set_index('model').automatic_threshold
    assert thresholds.k_only>thresholds.cpfem*2
    assert thresholds.d_q==pytest.approx(thresholds.cpfem)
    centers=result['centroids']
    planes=result['planes'].set_index('model')
    for name,group in centers.groupby('model'):
        p=planes.loc[name]
        d=(group.z-p.a*group.x-p.b*group.y-p.c)/np.sqrt(1+p.a**2+p.b**2)
        np.testing.assert_allclose(d,group.distance,atol=1.e-14)
        assert thresholds[name]==pytest.approx(np.sqrt(np.mean(group.distance**2)))
    changed={**selected,'cpfem':scaled}
    again=valley_tables(changed,tmp_path)
    pd.testing.assert_frame_equal(result['centroids'].query("model=='d_q'").reset_index(drop=True),
        again['centroids'].query("model=='d_q'").reset_index(drop=True))
    a=result['flags'].query("model=='d_q'").predicted_feature.to_numpy()
    b=again['flags'].query("model=='d_q'").predicted_feature.to_numpy()
    np.testing.assert_array_equal(a,b)
