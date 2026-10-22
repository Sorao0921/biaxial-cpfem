import numpy as np
import pandas as pd
from tools.theme1.plot_onset_boxplots import MODEL_NAMES,draw_plots,draw_individual


def test_five_model_statistics_and_individual_three_metric_charts(tmp_path):
    data=pd.DataFrame([dict(rho=-.5,feature='valley',texture='brass',model=model,case_id=f'case{k}',
        precision=value,recall=value,f1=value,origin_recall=value) for model in MODEL_NAMES for k,value in enumerate([.2,.8,np.nan])])
    summary=draw_plots(data,tmp_path)
    draw_individual(data,tmp_path)
    rows=summary.query("texture=='brass'")
    assert set(rows.model)==set(MODEL_NAMES)
    assert rows.n_valid.eq(2).all() and rows.n_undefined.eq(1).all()
    np.testing.assert_allclose(rows['median'],.5)
    assert len(list((tmp_path/'individual_models').glob('*.png')))==5
    assert len(list((tmp_path/'individual_models').glob('*.pdf')))==5
    assert (tmp_path/'all_boxplots.pdf').exists()
    assert (tmp_path/'overview_boxplots.pdf').exists()
