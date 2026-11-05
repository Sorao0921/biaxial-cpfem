import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from src.theme2.dq_origins import event_counts, predict_dq, track_dq
from src.dashboard.dq_origins import history_figure
from tests.helpers import onset_inputs, surface_mesh as mesh


def test_cumulative_events_exclude_repeat_and_keep_zero_states():
    origins=pd.DataFrame([
        dict(state=2,is_event=True,captured=True),
        dict(state=2,is_event=True,captured=False),
        dict(state=3,is_event=False,captured=True),
        dict(state=3,is_event=True,captured=True),
        dict(state=4,is_event=False,captured=False)])
    counts=event_counts(origins,[2,3,4])
    assert counts.total.tolist()==[2,1,0]
    assert counts.captured.tolist()==[1,1,0]
    np.testing.assert_allclose(counts.cumulative_capture_rate,[.5,2/3,2/3])
    assert np.isnan(counts.new_cumulative_capture_rate.iloc[0])
    counts['eps_eq']=[.009,.018,.02]
    fig=history_figure(counts,'test',cumulative=False)
    np.testing.assert_allclose(fig.axes[1].lines[0].get_xdata(),[.009,.018,.02])
    np.testing.assert_allclose([p.get_x()+p.get_width()/2 for p in fig.axes[0].patches[:3]],[.009,.018,.02])
    assert [p.get_y() for p in fig.axes[0].patches[3:]]==[1,1,0]
    np.testing.assert_allclose(fig.axes[1].lines[0].get_ydata(),[50,200/3,200/3])
    plt.close(fig)


def test_no_origins_is_undefined_not_zero_capture():
    rows=pd.DataFrame(columns=['state','is_event','captured']).astype({'is_event':bool,'captured':bool})
    counts=event_counts(rows,[2,3])
    assert counts.cumulative_capture_rate.isna().all()
    assert counts.total.eq(0).all()


def test_unchanged_reference_has_no_new_origins_and_fixed_prediction(tmp_path):
    orientation=onset_inputs(tmp_path)
    prediction=predict_dq(orientation,tmp_path,-.5)
    height=prediction['coordinates'].copy()
    original=height.copy()
    result=track_dq(prediction,{2:height,3:height.copy()},tmp_path)
    assert result['counts'].total.iloc[1]==0
    pd.testing.assert_frame_equal(original,prediction['coordinates'])
    assert prediction['metadata']['prescribed_strain']==.00901
    import pytest
    with pytest.raises(ValueError,match='連続'):
        track_dq(prediction,{2:height,4:height},tmp_path)
    with pytest.raises(ValueError,match='評価範囲'):
        track_dq(prediction,{2:height,3:height.iloc[1:]},tmp_path)


def test_disappeared_origins_remain_in_cumulative_bars_and_rate():
    # Neither initial origin is observed at state03; only an uncaptured new one appears at 04.
    origins=pd.DataFrame([
        dict(state=2,is_event=True,captured=True),
        dict(state=2,is_event=True,captured=False),
        dict(state=4,is_event=True,captured=False)])
    counts=event_counts(origins,[2,3,4])
    assert counts.cumulative_captured.tolist()==[1,1,1]
    assert counts.cumulative_missed.tolist()==[1,1,2]
    np.testing.assert_allclose(counts.cumulative_capture_rate,[.5,.5,1/3])
    counts['eps_eq']=[.009,.018,.02]
    fig=history_figure(counts,'test')
    assert [p.get_height() for p in fig.axes[0].patches]==[1,1,1,1,1,2]
    plt.close(fig)


def test_projection_uses_node_ids_and_only_first_events_and_state02_lines():
    from src.theme2.dq_origins import project_reference_to_prediction
    prediction=pd.DataFrame(dict(node_id=[30,10,20],x=[3.,1.,2.],y=[6.,4.,5.],z=[9.,7.,8.]))
    lines=pd.DataFrame(dict(state=[2,3],node_a=[10,20],node_b=[30,30]))
    origins=pd.DataFrame(dict(state=[2,3,4],node_id=[20,30,10],is_event=[True,True,False],x=[100.,200.,300.]))
    mapped_lines,mapped_origins=project_reference_to_prediction(prediction,lines,origins)
    assert mapped_lines.predicted_x_a.tolist()==[1.]
    assert mapped_lines.predicted_x_b.tolist()==[3.]
    assert mapped_origins.predicted_x.tolist()==[2.,3.]
    assert mapped_origins.predicted_z.tolist()==[8.,9.]
    assert mapped_origins.state.tolist()==[2,3]
    import pytest
    with pytest.raises(ValueError,match='ありません'):
        project_reference_to_prediction(prediction.iloc[1:],lines,origins)


def test_initial_summary_uses_state02_even_when_later_rate_differs():
    from src.dashboard.dq_origins import initial_capture_summary, initial_figure
    counts=pd.DataFrame(dict(state=[2,3],eps_eq=[.009,.018],total=[10,10],captured=[8,1],missed=[2,9]))
    initial=initial_capture_summary(counts)
    assert initial['initial_capture_rate']==.8
    assert initial['initial_origin_count']==10
    assert initial['state']==2
    figure=initial_figure(pd.DataFrame([dict(rho=-.5,seed=1,texture='brass',sd=2,**initial)]))
    assert figure.axes[0].collections[0].get_offsets()[0,1]==80
    plt.close(figure)


def test_peak_evaluation_is_sign_symmetric_and_does_not_change_prediction(tmp_path):
    from src.theme2.dq_origins import evaluate_peak_origins
    from src.theme2.valley_evaluation import valley_tables
    from src.theme2.valley_bottom import bottom_supported_tables
    top=mesh(tmp_path,20,individual=True)
    top.z=.01+.002*np.exp(-((top.x-.5)**2+(top.y-.5)**2)/.02)
    before=top.copy(deep=True)
    peaks=evaluate_peak_origins(top,top,tmp_path)
    inverted=top.assign(z=-top.z)
    valleys=bottom_supported_tables(valley_tables({'d_q':inverted,'cpfem':inverted},tmp_path),inverted,tmp_path)
    pd.testing.assert_frame_equal(peaks['metrics'],valleys['metrics'])
    pd.testing.assert_frame_equal(top,before)
    assert len(peaks['origins'])==1 and peaks['origins'].z.iloc[0]>.011
    # An isolated round summit need not contain a finite-length ridge.
    ridge=top.assign(z=.01-.002*(top.x-.5)**2-.003*top.y)
    ridges=evaluate_peak_origins(ridge,ridge,tmp_path)['predicted_ridges']
    assert len(ridges)>0 and (ridges.z_a>0).all()
    assert not {'precision','recall','f1'}&set(peaks['metrics'])


def test_peak_history_is_symmetric_with_original_coordinates(tmp_path):
    from src.theme2.dq_origins import track_dq_peaks,track_dq
    top=mesh(tmp_path,16,individual=True)
    top.z=.01+.002*np.exp(-((top.x-.5)**2+(top.y-.5)**2)/.02)
    prediction={'coordinates':top.copy(),'metadata':{}}
    heights={2:top.copy(),3:top.copy()}
    peaks=track_dq_peaks(prediction,heights,tmp_path)
    mirrored=track_dq({'coordinates':top.assign(z=-top.z),'metadata':{}},{s:h.assign(z=-h.z) for s,h in heights.items()},tmp_path)
    pd.testing.assert_frame_equal(peaks['counts'],mirrored['counts'])
    np.testing.assert_allclose(peaks['origins'].z,-mirrored['origins'].z)
    np.testing.assert_allclose(peaks['prediction'].z,top.z)
    np.testing.assert_allclose(prediction['coordinates'].z,top.z)
    assert peaks['counts'].query('state==3').total.iloc[0]==0


def test_history_styles_distinguish_valleys_and_peaks():
    from src.dashboard.dq_origins import history_figure
    counts=pd.DataFrame(dict(eps_eq=[.01,.02],captured=[2,1],missed=[1,1],total=[3,2],
        cumulative_captured=[2,3],cumulative_missed=[1,2],cumulative_total=[3,5],cumulative_capture_rate=[2/3,3/5]))
    a=history_figure(counts,'Valley',feature='valley')
    b=history_figure(counts,'Peak',feature='peak')
    assert a.axes[0].patches[0].get_facecolor()!=b.axes[0].patches[0].get_facecolor()
    assert a.axes[1].lines[0].get_marker()!=b.axes[1].lines[0].get_marker()
    plt.close(a);plt.close(b)


def test_ui_history_rejects_missing_states_and_state13():
    import pytest
    from src.dashboard.dq_origins import run_case
    with pytest.raises(ValueError,match='state12'):
        run_case(-.5,(1,'cube',2),{},13)
    with pytest.raises(ValueError,match='不足'):
        run_case(-.5,(1,'cube',2),{},12)
