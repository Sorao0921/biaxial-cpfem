from types import SimpleNamespace
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from src.theme1.initial_fourway import predict_three_models,evaluate_three_models,MODEL_NAMES
from tests.test_initial_mismatch import mesh_frames


def test_three_models_share_initial_load_and_reference_never_modifies_predictions(tmp_path):
    nodes,elements=mesh_frames();nodes.to_csv(tmp_path/'nodes.csv',index=False);elements.to_csv(tmp_path/'elements.csv',index=False)
    angles=tmp_path/'angles.csv';np.savetxt(angles,[[.2,.4,.8],[1.1,.9,.3]],delimiter=',')
    prediction=predict_three_models(angles,tmp_path,rho=-.5,strain=.02,q_coupling=0.)
    assert set(prediction['models'])==set(MODEL_NAMES)
    a=prediction['models']['k_only']['coordinates'];b=prediction['models']['d_q']['coordinates']
    pd.testing.assert_frame_equal(a,b)
    before={name:value['coordinates'].copy(deep=True) for name,value in prediction['models'].items()}
    reference=a.copy();reference.z+=np.linspace(-.002,.002,len(reference))
    first=evaluate_three_models(prediction,reference)
    reference.z+=1.
    second=evaluate_three_models(prediction,reference)
    for name,value in before.items():pd.testing.assert_frame_equal(prediction['models'][name]['coordinates'],value)
    assert len(first['metrics'])==3
    np.testing.assert_allclose(second['metrics'].mean_height_bias,first['metrics'].mean_height_bias-1.)
    assert prediction['models']['k_only']['metadata']['beta']==prediction['models']['equilibrium']['metadata']['beta']


def test_cli_saves_three_predictions_before_reading_cpfem(tmp_path,monkeypatch):
    import tools.theme1.compare_initial_models as cli
    events=[]
    coordinates=pd.DataFrame({'node_id':[1,2,3],'x':[0.,1.,0.],'y':[0.,0.,1.],'z':[.1,.2,.3]})
    eq_meta={'finite_geometry_valid':True,'relative_free_force_residual':1.e-10,'iterations':2,
        'inverted_deformed_elements':0,'maximum_eigenstrain_norm':.03}
    models={name:{'coordinates':coordinates,'metadata':eq_meta if name=='equilibrium' else {},
        'grains':pd.DataFrame({'linear_height_positive':[True]})} for name in MODEL_NAMES}
    prediction={'models':models,'configuration':{'beta':0.},'config_id':'example'}
    def predict(*a,**kw):events.append('three_predictions');return prediction
    def save(value,path):
        events.append('save_all_three')
        for name in MODEL_NAMES:(path/name).mkdir(parents=True)
    def actual(path):
        assert events==['three_predictions','save_all_three']
        events.append('cpfem_read');return coordinates
    monkeypatch.setattr(cli,'scan_outputs',lambda p:[])
    monkeypatch.setattr(cli,'filter_records',lambda *a,**kw:[SimpleNamespace(rho=-.5,seed=1,texture='brass',sd=8,path=tmp_path/'never.csv')])
    monkeypatch.setattr(cli,'predict_three_models',predict);monkeypatch.setattr(cli,'save_initial_prediction',save)
    monkeypatch.setattr(cli,'_read_height',actual)
    monkeypatch.setattr(cli,'comparison_figures',lambda *a:[plt.figure() for _ in range(4)])
    assert cli.main(['--output-dir',str(tmp_path/'out')])==0
    assert events[-1]=='cpfem_read'
