import numpy as np
import pandas as pd
from src.theme1.delayed_valley import classify_reference


def detected(a,b,origin=None):
    lines=pd.DataFrame([dict(segment_id=0,node_a=a,node_b=b,material_x_a=a-1,material_y_a=0,material_x_b=b-1,material_y_b=0)])
    origins=pd.DataFrame(dict(origin_id=[0],node_id=[origin])) if origin is not None else pd.DataFrame(columns=['origin_id','node_id'])
    return dict(segments=lines,origins=origins)


def test_new_valley_is_distinct_from_extension_and_new_minimum_on_old_valley():
    top=pd.DataFrame(dict(x=np.arange(21.),y=np.zeros(21)))
    prior=np.array([[[0.,0.],[2.,0.]]]);old_origins=np.array([[0.,0.]])
    lines,origins,_,_=classify_reference(detected(1,3,3),top,prior,old_origins,line_tolerance=.1,origin_tolerance=.5)
    assert not lines.new_disconnected_valley.any()
    assert origins.appearance.iloc[0]=='new_origin_on_existing_or_expanding_valley'
    _,origins,_,_=classify_reference(detected(10,12,10),top,prior,old_origins,line_tolerance=.1,origin_tolerance=.5)
    assert origins.appearance.iloc[0]=='new_origin_in_new_valley'
    _,origins,_,_=classify_reference(detected(0,2,1),top,prior,old_origins,line_tolerance=.1,origin_tolerance=.5)
    assert origins.appearance.iloc[0]=='continued_or_returned_origin'


def test_return_to_any_historical_origin_is_not_novel():
    top=pd.DataFrame(dict(x=np.arange(21.),y=np.zeros(21)))
    history=np.array([[[0.,0.],[2.,0.]],[[9.,0.],[11.,0.]]])
    _,origins,_,_=classify_reference(detected(10,12,10),top,history,np.array([[0.,0.],[9.,0.]]),line_tolerance=.1,origin_tolerance=.5)
    assert not origins.novel_origin.iloc[0]
    assert origins.appearance.iloc[0]=='continued_or_returned_origin'


def test_connected_extension_is_not_a_new_disconnected_valley():
    top=pd.DataFrame(dict(x=np.arange(21.),y=np.zeros(21)))
    detection=detected(1,3,12)
    extra=detected(3,12)['segments'];extra['segment_id']=1
    detection['segments']=pd.concat([detection['segments'],extra],ignore_index=True)
    lines,origins,_,_=classify_reference(detection,top,np.array([[[0.,0.],[2.,0.]]]),np.array([[0.,0.]]),line_tolerance=.1,origin_tolerance=.5)
    assert not lines.new_disconnected_valley.any()
    assert origins.novel_origin.iloc[0]
    assert origins.appearance.iloc[0]=='new_origin_on_existing_or_expanding_valley'
