import numpy as np
import pandas as pd
from src.theme1.valley_onset import predict_onset_models,evaluate_onset,MODEL_NAMES,reference_followup
from tests.test_initial_mismatch import mesh_frames


def inputs(tmp_path):
    nodes,elements=mesh_frames(6,6,2)
    nodes.to_csv(tmp_path/'nodes.csv',index=False);elements.to_csv(tmp_path/'elements.csv',index=False)
    angle=tmp_path/'orientation.csv';np.savetxt(angle,[[.2,.4,.8],[1.1,.9,.3]],delimiter=',')
    return angle


def test_matched_ablations_and_initial_only_prediction(tmp_path):
    angle=inputs(tmp_path)
    p=predict_onset_models(angle,tmp_path,rho=-.5)
    assert tuple(p['models'])==MODEL_NAMES
    models=p['models']
    diag=models['equilibrium_diagonal']['initial_tensors'];full=models['equilibrium']['initial_tensors']
    for name in ['xx','yy','zz']:np.testing.assert_allclose(diag['plastic_strain_'+name],full['plastic_strain_'+name])
    for name in ['xy','yz','xz']:np.testing.assert_allclose(diag['plastic_strain_'+name],0)
    assert models['self_nd']['metadata']['surface_coupling']==0
    assert models['nd_contrast']['metadata']['surface_coupling']==0
    assert 'k_only' not in models
    assert models['d_q']['metadata']['surface_coupling']==0
    assert models['d_q']['metadata']['q_coupling']==1
    assert p['configuration']['evaluation_state']==2
    # A reference is created after prediction; changing it cannot change stored predictions.
    actual=models['equilibrium']['coordinates'].copy()
    before=actual.copy(deep=True)
    result=evaluate_onset(p,actual,tmp_path)
    assert not {'chance_recall','recall_lift','ap_chance'}&set(result['metrics'])
    assert len(result['transitions'])==9
    assert set(result['transition_grains'].transition)<= {'unchanged','new_hit','lost_hit','new_false_alarm','removed_false_alarm'}
    pd.testing.assert_frame_equal(before,models['equilibrium']['coordinates'])
    following=reference_followup(result,{2:actual,3:actual},tmp_path)
    if following.onset_valleys.iloc[0]>0:np.testing.assert_allclose(following.onset_retention,1)


def test_q_zero_and_zero_surface_coupling_recover_matched_baselines(tmp_path):
    angle=inputs(tmp_path)
    p=predict_onset_models(angle,tmp_path,rho=0.,coupling=0.,q_coupling=0.)
    for name in ['d_q']:
        pd.testing.assert_frame_equal(p['models'][name]['coordinates'],p['models']['nd_contrast']['coordinates'])


def test_property_table_and_nonzero_transmission_rejected(tmp_path):
    import pytest
    from src.theme1.valley_onset import property_table
    table=property_table()
    assert len(table)==5
    assert table['Q拘束'].tolist()==['×','×','○','×','×']
    angle=inputs(tmp_path)
    with pytest.raises(ValueError,match='coupling'):
        predict_onset_models(angle,tmp_path,rho=0.,coupling=1.)
