from pathlib import Path
import matplotlib.pyplot as plt
import numpy as np
import pytest
from src.dashboard.catalog import OutputRecord, initial_record_for, scan_outputs
from src.dashboard.plots import initial_figure


def test_initial_lookup_ignores_selected_state_but_matches_case(tmp_path):
    p=tmp_path/'outputs/rho_0/rho_0_seed1/angles/taylor_factor/cube_sd2_seed1/taylor_factor_cube_sd2_seed1_state01.csv'
    p.parent.mkdir(parents=True); p.write_text('part_id,state,taylor_factor\n1,1,2.5\n')
    records=scan_outputs(tmp_path/'outputs')
    assert len(records)==1
    for state in [1,5,13]:
        current=OutputRecord('height',0,1,'cube',2,state,Path('unused'),'test')
        assert initial_record_for(records,current).path==p
    wrong=OutputRecord('height',1,1,'cube',2,13,Path('unused'),'test')
    assert initial_record_for(records,wrong) is None


def test_initial_plot_uses_reference_geometry_and_degrees(tmp_path):
    (tmp_path/'nodes.csv').write_text('node_id,x,y,z\n101,0,0,1\n102,1,0,1\n103,1,1,1\n104,0,1,1\n')
    (tmp_path/'elements.csv').write_text('element_id,part_id,center_x,center_y,center_z,n1,n2,n3,n4\n1,7,.5,.5,1,101,102,103,104\n')
    metrics=tmp_path/'initial.csv'
    metrics.write_text('part_id,state,taylor_factor,phi1_rad,Phi_rad,phi2_rad\n7,1,2.5,1.5707963267948966,0,0\n')
    for metric,value,unit in [('taylor',2.5,'M'),('phi1',90,'deg')]:
        fig=initial_figure(metrics,tmp_path,metric=metric)
        np.testing.assert_allclose(fig.axes[0].collections[0].get_array(),[value])
        np.testing.assert_allclose(fig.axes[0].collections[0].get_paths()[0].vertices[:4],[[0,0],[1,0],[1,1],[0,1]])
        assert fig.axes[1].get_ylabel()==unit
        plt.close(fig)
    metrics.write_text(metrics.read_text().replace('7,1,','7,13,'))
    with pytest.raises(ValueError,match='state01'):
        initial_figure(metrics,tmp_path)


def test_initial_crop_uses_same_elements_but_reference_positions(tmp_path):
    from src.dashboard.plots import deformed_surface
    (tmp_path/'nodes.csv').write_text('node_id,x,y,z\n101,0,0,1\n102,1,0,1\n103,2,0,1\n104,0,1,1\n105,1,1,1\n106,2,1,1\n')
    (tmp_path/'elements.csv').write_text('element_id,part_id,center_x,center_y,center_z,n1,n2,n3,n4\n11,7,.5,.5,1,101,102,105,104\n12,8,1.5,.5,1,102,103,106,105\n')
    coords=tmp_path/'cropped.csv'
    coords.write_text('node_id,x,y,z\n6,15,23,1\n2,12,20,1\n3,14,20,1\n5,13,23,1\n')
    metrics=tmp_path/'initial.csv';metrics.write_text('part_id,state,taylor_factor\n7,1,2.5\n8,1,3.5\n')
    now=deformed_surface(tmp_path,coords)
    initial=deformed_surface(tmp_path,coords,reference_geometry=True)
    np.testing.assert_array_equal(now[0],initial[0]);assert initial[0].tolist()==[12]
    np.testing.assert_allclose(initial[2][0],[[1,0],[2,0],[2,1],[1,1]])
    fig=initial_figure(metrics,tmp_path,selection_coordinates_path=coords)
    assert len(fig.axes[0].collections[0].get_paths())==1
    np.testing.assert_allclose(fig.axes[0].collections[0].get_array(),[3.5])
    np.testing.assert_allclose(fig.axes[0].collections[-1].get_segments(),initial[3])
    plt.close(fig)
