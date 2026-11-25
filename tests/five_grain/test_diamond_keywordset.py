"""Verify mapping of supplied face BCs and exact-match material reuse."""
import sys
from pathlib import Path
import numpy as np
import pytest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from src.make_model_process.diamond_keywordset import prepare_boundary,blocks,data,nodes_from_text
from tools.preprocess.make_partsmat_diamond import generate_materials


def test_rebuild_face_members_preserves_motion_and_fixed_width_header(tmp_path):
    partset=tmp_path/'partset.k'
    partset.write_text('*NODE\n'+''.join(f'{i+1},{x},{y},{z}\n' for i,(x,y,z) in enumerate(( (x,y,z) for x in [0,.03] for y in [0,.03] for z in [0,.0075]))))
    source=tmp_path/'boundary.k';output=tmp_path/'prepared.k'
    header=f'{3:10d}'+f'{0:10.1f}'*4
    motion='*BOUNDARY_PRESCRIBED_MOTION_SET\n3,1,0,1,1,0,1e28,0\n'
    original='*SET_NODE_LIST_TITLE\nx1\n'+header+'\n114005\n'+motion
    source.write_text(original)
    prepare_boundary(source,partset,output)
    result=output.read_text()
    assert source.read_text()==original
    assert header in result and result.endswith(motion)
    values=data(blocks(result)[0][1]);members={int(n) for row in values[2:] for n in row.split()}
    nodes=nodes_from_text(partset.read_text())
    assert members=={nid for nid,pos in nodes.items() if pos[0]==.03}
    before=output.stat().st_mtime_ns
    prepare_boundary(source,partset,output)
    assert output.stat().st_mtime_ns==before


def test_material_reuse_checks_entire_batch_before_writing(tmp_path):
    first=tmp_path/'a.csv';second=tmp_path/'b.csv'
    np.savetxt(first,np.zeros((5,3)),delimiter=',');np.savetxt(second,np.ones((5,3)),delimiter=',')
    out=tmp_path/'a.k';other=tmp_path/'b.k'
    assert generate_materials([(first,out)])==(1,0)
    before=out.stat().st_mtime_ns
    assert generate_materials([(first,out)],reuse_existing=True)==(0,1)
    assert out.stat().st_mtime_ns==before
    out.write_text('unrelated existing card')
    with pytest.raises(FileExistsError):generate_materials([(second,other),(first,out)],reuse_existing=True)
    assert not other.exists() and out.read_text()=='unrelated existing card'


def test_diamond_set_has_macro_field_widths_and_explicit_options():
    from io import StringIO
    from src.make_model_process.diamond_five_grain import write_diamond_node_set
    deck=StringIO();write_diamond_node_set(deck,101,'XMIN',np.arange(1,11))
    lines=deck.getvalue().splitlines()
    assert lines[2].startswith('$#     sid') and lines[4].startswith('$#    nid1')
    fields=[lines[3][i:i+10] for i in range(0,80,10)]
    assert int(fields[0])==101
    assert [float(v) for v in fields[1:5]]==[0,0,0,0]
    assert fields[5].strip()=='MECH' and int(fields[6])==1
    assert len(lines[5])==80 and len(lines[6])==20
    assert [int(lines[5][i:i+10]) for i in range(0,80,10)]==list(range(1,9))
    assert lines[6]=='         9        10'
