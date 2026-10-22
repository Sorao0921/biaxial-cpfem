import numpy as np
import pandas as pd
from tools.theme1.plot_detection_boxplots import draw_plots


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
