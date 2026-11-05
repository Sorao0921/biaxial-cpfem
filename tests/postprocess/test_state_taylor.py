from pathlib import Path
import numpy as np
import pandas as pd
import pytest
from src.crystal_plasticity.taylor_pipeline import calculate_state_frame,TARGET_COLUMNS
from src.dashboard.catalog import scan_outputs


def frame(state,angles):
    data=pd.DataFrame([angles],columns=TARGET_COLUMNS)
    data['part_id']=7;data['element_count']=20;data['target_state']=state
    # Reference angles must not be used for a target-state calculation.
    data['mean_phi1_reference_deg']=0
    return data


def test_target_state_rotation_changes_factor():
    a=calculate_state_frame(frame(2,[0,0,0]),-.5,2)
    b=calculate_state_frame(frame(13,[45,0,0]),-.5,13)
    assert a.state.iloc[0]==2 and b.state.iloc[0]==13
    np.testing.assert_allclose(a.taylor_factor,np.sqrt(6),atol=1e-10)
    assert not np.isclose(a.taylor_factor.iloc[0],b.taylor_factor.iloc[0])
    with pytest.raises(ValueError,match='state'):
        calculate_state_frame(frame(2,[0,0,0]),-.5,13)


def test_state_catalog_has_exact_state_and_excludes_initial(tmp_path):
    root=tmp_path/'outputs/rho_0/rho_0_seed1/angles/taylor_factor/cube_sd2_seed1'
    root.mkdir(parents=True)
    for state in [1,2,13]:
        (root/f'taylor_factor_cube_sd2_seed1_state{state:02d}.csv').write_text('part_id,taylor_factor\n7,2.5\n')
    data=scan_outputs(tmp_path/'outputs')
    assert [(r.kind,r.state) for r in data if r.kind=='taylor']==[('taylor',2),('taylor',13)]


def test_missing_and_changed_state_are_recomputed(tmp_path):
    from src.dashboard.catalog import OutputRecord
    from src.crystal_plasticity.taylor_pipeline import ensure_record
    source=tmp_path/'mean_state02.csv'
    frame(2,[0,0,0]).to_csv(source,index=False)
    record=OutputRecord('orientation',-.5,1,'cube',2,2,source,'test')
    generated=ensure_record(record,tmp_path/'results')
    assert generated.state==2 and generated.path.exists()
    first=pd.read_csv(generated.path).taylor_factor.iloc[0]
    unchanged=generated.path.stat().st_mtime_ns
    ensure_record(record,tmp_path/'results')
    assert generated.path.stat().st_mtime_ns==unchanged
    frame(2,[45,0,0]).to_csv(source,index=False)
    ensure_record(record,tmp_path/'results')
    updated=pd.read_csv(generated.path).taylor_factor.iloc[0]
    assert not np.isclose(first,updated)
    # Corrupted output is detected even when source is unchanged.
    generated.path.write_text('broken')
    ensure_record(record,tmp_path/'results')
    assert np.isclose(pd.read_csv(generated.path).taylor_factor.iloc[0],updated)


def test_initial_and_state_share_calculation_and_folder(tmp_path):
    from src.crystal_plasticity.taylor_pipeline import calculate_initial_frame, output_path
    from src.dashboard.catalog import OutputRecord
    initial=calculate_initial_frame(np.deg2rad([[45,0,0]]),{1:20},-.5)
    later=calculate_state_frame(frame(2,[45,0,0]),-.5,2)
    np.testing.assert_allclose(initial.taylor_factor,later.taylor_factor)
    for state in [1,2]:
        record=OutputRecord('initial' if state==1 else 'orientation',-.5,1,'cube',2,state,Path('source'),'test')
        path=output_path(record,tmp_path)
        assert path.parent==tmp_path/'rho_-0.5/rho_-0.5_seed1/angles/taylor_factor/cube_sd2_seed1'
        assert path.name.endswith(f'state{state:02d}.csv')


def test_one_manifest_covers_multiple_states_without_json(tmp_path):
    from src.crystal_plasticity.taylor_pipeline import ensure_record
    from src.dashboard.catalog import OutputRecord
    for state in [2,13]:
        source=tmp_path/f'source{state}.csv'
        frame(state,[0,0,0]).to_csv(source,index=False)
        record=OutputRecord('orientation',0.,1,'cube',2,state,source,'test')
        ensure_record(record,tmp_path/'outputs')
    folder=tmp_path/'outputs/rho_0/rho_0_seed1/angles/taylor_factor'
    assert len(pd.read_csv(folder/'manifest.csv'))==2
    assert not list(folder.glob('*.json'))
