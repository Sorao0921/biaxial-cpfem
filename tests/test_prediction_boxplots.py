import numpy as np
import pandas as pd
from tools.theme2.plot_detection_boxplots import draw_plots
from tools.theme2.plot_onset_boxplots import MODEL_NAMES,draw_plots as draw_onset_plots,draw_individual


def test_statistics_keep_undefined_separate_and_do_not_mix_models_or_features(tmp_path):
    data=pd.DataFrame([dict(rho=-.5,feature=feature,texture='brass',model=model,
        precision=value,recall=value,f1=value) for feature in ['valley','peak']
        for model in ['k_only','d_q','equilibrium'] for value in [.2,.8,np.nan]])
    statistics=draw_plots(data,tmp_path)
    brass=statistics.query("texture=='brass'")
    assert (brass.n_cases==3).all() and (brass.n_valid==2).all() and (brass.n_undefined==1).all()
    np.testing.assert_allclose(brass['median'],.5)
    assert set(statistics.feature)=={'valley','peak'}
    assert len(list(tmp_path.glob('*.png')))==2
    assert len(list(tmp_path.glob('*.pdf')))==3
    assert statistics.query("texture=='cube'").n_valid.eq(0).all()


def test_onset_capture_and_area_statistics_and_individual_charts(tmp_path):
    data=pd.DataFrame([dict(rho=-.5,feature='valley',texture='brass',model=model,case_id=f'case{k}',
        origin_recall=value,predicted_area_fraction=value) for model in MODEL_NAMES for k,value in enumerate([.2,.8,np.nan])])
    summary=draw_onset_plots(data,tmp_path)
    draw_individual(data,tmp_path)
    rows=summary.query("texture=='brass'")
    assert set(rows.model)==set(MODEL_NAMES)
    assert set(rows.metric)=={'origin_recall','predicted_area_fraction'}
    assert rows.n_valid.eq(2).all() and rows.n_undefined.eq(1).all()
    np.testing.assert_allclose(rows['median'],.5)
    assert len(list((tmp_path/'individual_models').glob('*.png')))==5
    assert len(list((tmp_path/'individual_models').glob('*.pdf')))==5
    assert (tmp_path/'all_boxplots.pdf').exists()
    assert (tmp_path/'overview_boxplots.pdf').exists()
