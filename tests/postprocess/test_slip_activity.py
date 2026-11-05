import numpy as np
import pytest
from src.crystal_plasticity.slip_activity import z_slip_activity, LEGACY_FCC_DIRECTIONS


def test_projection_increment_and_rate():
    previous = np.ones((2, 12)) * 10
    current = previous.copy()
    current[:, 0] += 2
    az, rz = z_slip_activity(previous, current, np.zeros((2, 3)), delta_epsilon=2)
    np.testing.assert_allclose(az, 1 / np.sqrt(2))
    np.testing.assert_allclose(rz, 1 / np.sqrt(2))
    flipped, _ = z_slip_activity(previous, current, np.zeros((2, 3)), delta_epsilon=2,
                                directions=-LEGACY_FCC_DIRECTIONS)
    np.testing.assert_allclose(flipped, az)


def test_orientation_and_no_activity():
    previous = np.zeros((1, 12))
    current = previous.copy()
    current[0, 2] = 1  # crystal [110], z projection zero at identity
    az, _ = z_slip_activity(previous, current, [[0, 0, 0]], delta_epsilon=1)
    np.testing.assert_allclose(az, 0)
    az, _ = z_slip_activity(previous, current, [[0, np.pi/2, 0]], delta_epsilon=1)
    np.testing.assert_allclose(az, 1/np.sqrt(2))
    az, rz = z_slip_activity(current, current, [[0, 0, 0]], delta_epsilon=1)
    np.testing.assert_allclose([az, rz], 0)


def test_bad_interval_rejected():
    with pytest.raises(ValueError, match="decreased"):
        z_slip_activity(np.ones((1, 12)), np.zeros((1, 12)), [[0,0,0]], delta_epsilon=1)
    with pytest.raises(ValueError, match="positive"):
        z_slip_activity(np.zeros((1, 12)), np.zeros((1, 12)), [[0,0,0]], delta_epsilon=0)


def test_map_preserves_element_values_within_same_grain(tmp_path, monkeypatch):
    import pandas as pd
    import matplotlib.pyplot as plt
    from src.dashboard import plots
    monkeypatch.setattr(plots, "deformed_surface", lambda *args:
        (np.array([11, 12]), np.array([7, 7]),
         [[[0,0],[1,0],[1,1],[0,1]], [[1,0],[2,0],[2,1],[1,1]]], []))
    def shear(path, ids, activity):
        data = {"element_id": ids, plots.TOTAL_SHEAR_COLUMN: activity}
        for index, column in enumerate(plots.SLIP_COLUMNS):
            data[column] = activity if index == 0 else [0,0]
        pd.DataFrame(data).to_csv(path, index=False)
    shear(tmp_path/'previous.csv', [11,12], [0,0])
    shear(tmp_path/'current.csv', [12,11], [4,2])
    pd.DataFrame({"element_id":[12,11], "phi1":[0,0], "Phi":[0,0], "phi2":[0,0]}).to_csv(tmp_path/'angles.csv', index=False)
    from src.crystal_plasticity.slip_activity_pipeline import calculate_frame
    result = calculate_frame(tmp_path/'previous.csv', tmp_path/'current.csv',
        tmp_path/'angles.csv', delta_epsilon=2)
    result.to_csv(tmp_path/'activity.csv', index=False)
    figure = plots.slip_activity_figure(tmp_path/'activity.csv', tmp_path,
                                       coordinates_path='unused')
    np.testing.assert_allclose(figure.axes[0].collections[0].get_array(), np.array([1., 2.])/np.sqrt(2))
    plt.close(figure)


def test_pipeline_reads_raw_states_and_macro_strain_without_mapping(tmp_path):
    import pandas as pd
    from src.dashboard.catalog import OutputRecord
    from src.crystal_plasticity.slip_activity_pipeline import ensure_activity, SLIP_COLUMNS
    case = "cube_sd2_seed1"
    base = tmp_path/'outputs/rho_0/rho_0_seed1'
    slips = base/'shear_strains/rawdata'/case
    angles = base/'angles/id_set'/f'id_set_bunge_euler_{case}'
    slips.mkdir(parents=True)
    angles.mkdir(parents=True)
    for state, ids, amounts in ((1,[11,12],[5,5]), (2,[12,11],[5.4,5.2])):
        data = {'element_id':ids}
        for index, column in enumerate(SLIP_COLUMNS):
            data[column] = amounts if index == 0 else [0,0]
        pd.DataFrame(data).to_csv(slips/f'state{state}.csv', index=False)
    pd.DataFrame({'element_id':[12,11], 'phi1':[0,0], 'Phi':[0,0], 'phi2':[0,0]}).to_csv(
        angles/f'bunge_euler_{case}_state01.csv', index=False)
    pd.DataFrame({'eps_eq':[0,.1]}).to_csv(base/'eps_equivalent.csv', index=False)
    record = OutputRecord('shear',0,1,'cube',2,2,slips/'state2.csv','rawdata')
    output = ensure_activity(record, tmp_path/'outputs')
    saved = pd.read_csv(output)
    np.testing.assert_allclose(saved.z_slip_activity, [2/np.sqrt(2),4/np.sqrt(2)])
    stamp = output.stat().st_mtime_ns
    assert ensure_activity(record, tmp_path/'outputs').stat().st_mtime_ns == stamp
    pd.DataFrame({'eps_eq':[0,.2]}).to_csv(base/'eps_equivalent.csv', index=False)
    np.testing.assert_allclose(pd.read_csv(ensure_activity(record,tmp_path/'outputs')).z_slip_activity,
                               saved.z_slip_activity/2)


def test_macro_interval_and_id_mismatch(tmp_path):
    import pandas as pd
    from src.crystal_plasticity.slip_activity_pipeline import macro_interval, calculate_frame, SLIP_COLUMNS
    path = tmp_path/'eps.csv'
    pd.DataFrame({'eps_eq':[0,.02,.05]}).to_csv(path,index=False)
    assert macro_interval(path,3) == (.02,.05)
    with pytest.raises(ValueError, match='preceding'):
        macro_interval(path,1)
    pd.DataFrame({'eps_eq':[0,0]}).to_csv(path,index=False)
    with pytest.raises(ValueError, match='increase'):
        macro_interval(path,2)
    for name, ids in (('previous',[1]),('current',[2])):
        pd.DataFrame({'element_id':ids, **{c:[0.] for c in SLIP_COLUMNS}}).to_csv(tmp_path/f'{name}.csv',index=False)
    pd.DataFrame({'element_id':[2],'phi1':[0],'Phi':[0],'phi2':[0]}).to_csv(tmp_path/'angles.csv',index=False)
    with pytest.raises(ValueError,match='do not match'):
        calculate_frame(tmp_path/'previous.csv',tmp_path/'current.csv',tmp_path/'angles.csv',delta_epsilon=.02)
