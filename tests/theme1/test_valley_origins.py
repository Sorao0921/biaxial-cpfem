import numpy as np
import pandas as pd
from src.theme1.valley_origins import local_origins


def line(z):
    return pd.DataFrame([dict(segment_id=i,node_a=i,node_b=i+1,x_a=i,y_a=0,z_a=z[i],x_b=i+1,y_b=0,z_b=z[i+1],length=1.) for i in range(len(z)-1)])


def test_multiple_prominent_minima_on_one_connected_valley():
    origins,_=local_origins(line([4,0,2,1,4]),height_span=4,grain_diameter=1)
    assert set(origins.node_id)=={1,3}
    assert origins.component_id.nunique()==1
    assert len(origins)==2


def test_small_ripple_is_not_a_separate_origin_and_tilt_offset_does_not_matter():
    a,_=local_origins(line([4,0,2,1.99,4]),height_span=4,grain_diameter=1)
    assert a.node_id.tolist()==[1]
    b,_=local_origins(line(np.array([4,0,2,1.99,4])+10),height_span=4,grain_diameter=1)
    assert a.node_id.tolist()==b.node_id.tolist()


def test_flat_minimum_plateau_counts_once_and_line_end_is_not_an_origin():
    origins,members=local_origins(line([4,0,0,3,2]),height_span=4,grain_diameter=1)
    assert len(origins)==1 and origins.plateau_nodes.iloc[0]==2
    assert set(members.node_id)=={1,2}


